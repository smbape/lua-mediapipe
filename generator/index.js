/* eslint-disable no-magic-numbers */

const fs = require("node:fs");
const fsPromises = require("node:fs/promises");
const sysPath = require("node:path");
const { spawn } = require("node:child_process");
const os = require("node:os");

const { mkdirp } = require("mkdirp");
const waterfall = require("async/waterfall");
const { explore } = require("fs-explorer");
const Parser = require("./protobuf/Parser");

const Python3_EXECUTABLE = process.env.Python3_EXECUTABLE ? process.env.Python3_EXECUTABLE : "python";

const getOptions = output => {
    const language = "lua";

    const options = {
        APP_NAME: "Mediapipe",
        language,
        namespace: "mediapipe",
        shared_ptr: "std::shared_ptr",
        make_shared: "std::make_shared",
        Any: "::LUA_MODULE_NAME::Object",
        AnyObject: "::LUA_MODULE_NAME::Object",
        cname: "new",
        cnames: new Set([
            "create",
            "new",
        ]),

        isCaseSensitive: true,
        hasIsInstanceSupport: true, // do not generate reflection methods and properties
        hasInheritanceSupport: true, // do not duplicate parent methods

        // used to lookup classes
        namespaces: new Set([]),

        other_namespaces: new Set(),

        // used to reduce class name length
        remove_namespaces: new Set([
            "cv",
            "google::protobuf",
            "mediapipe",
            `mediapipe::${ language }`,
            `mediapipe::${ language }::solution_base`,
            `mediapipe::${ language }::solutions`,
            "std",
        ]),

        self: "*self",
        self_get: (name = null) => {
            return name ? `self->${ name }` : "self";
        },

        maxFilenameLength: os.platform() === "win32" ? 120 : 0,

        meta_methods: new Map([
            ["__eq__", "::mediapipe::lua::__eq__"],
            ["__type__", null /* use default __type__ method */],
        ]),

        is_meta_methods: new Map([
            ["__eq__", ([fname]) => fname === "__eq" || fname === "sol::meta_function::equal_to" || fname === "operator=="],
        ]),

        meta_methods_name: new Map([
            ["__eq__", "operator=="],
            ["__type__", "__type"],
        ]),

        build: new Set(),
        notest: new Set(),
        skip: new Set(),

        output: sysPath.join(output, "generated"),

        onClass: (processor, coclass, opts) => {
            // Nothing to do
        },

        onCoClass: (processor, coclass, opts) => {
            const {fqn} = coclass;

            if (fqn === `mediapipe::${ language }::solutions::objectron::ObjectronOutputs`) {
                processor.add_vector(`std::vector<${ fqn }>`, coclass, opts);
            }

            // import mediapipe.python.solutions as solutions
            if (fqn.startsWith(`mediapipe::${ language }::`)) {
                const parts = fqn.split("::");

                for (let i = 2; i < Math.min(3, parts.length); i++) {
                    processor.add_func([`${ [parts[0]].concat(parts.slice(2, i)).join(".") }.`, "", ["/Properties"], [
                        [parts.slice(0, i + 1).join("::"), parts[i], "", ["/R", "=this", "/S"]],
                    ], "", ""]);
                }
            }
        },

        progids: new Map([
            ["google.protobuf.TextFormat", "google.protobuf.text_format"],
        ]),
    };

    const argv = process.argv.slice(2);
    const flags_true = ["hdr", "impl", "save"];
    const flags_false = ["test"];

    for (const opt of flags_true) {
        options[opt] = !argv.includes(`--no-${ opt }`);
    }

    for (const opt of flags_false) {
        options[opt] = argv.includes(`--${ opt }`);
    }

    for (let i = 0; i < argv.length; i++) {
        const opt = argv[i];

        if (opt.startsWith("--no-") && flags_true.includes(opt.slice("--no-".length))) {
            continue;
        }

        if (opt.startsWith("--") && flags_false.includes(opt.slice("--".length))) {
            continue;
        }

        if (opt.startsWith("--no-test=")) {
            for (const fqn of opt.slice("--no-test=".length).split(/[ ,]/)) {
                options.notest.add(fqn);
            }
            continue;
        }

        if (opt.startsWith("--build=")) {
            for (const fqn of opt.slice("--build=".length).split(/[ ,]/)) {
                options.build.add(fqn);
            }
            continue;
        }

        if (opt.startsWith("--skip=")) {
            for (const fqn of opt.slice("--skip=".length).split(/[ ,]/)) {
                options.skip.add(fqn);
            }
            continue;
        }

        if (opt.startsWith("-D")) {
            const [key, value] = opt.slice("-D".length).split("=");
            options[key] = typeof value === "undefined" ? true : value;
            continue;
        }

        throw new Error(`Unknown option ${ opt }`);
    }

    return options;
};

const {
    CUSTOM_CLASSES,
} = require("./constants");
const {findFile} = require("./FileUtils");
const custom_declarations = require("./custom_declarations");
const DeclProcessor = require("./DeclProcessor");
const LuaGenerator = require("./LuaGenerator");

const PROJECT_DIR = sysPath.dirname(__dirname);
const SRC_DIR = sysPath.join(PROJECT_DIR, "src");

const findSourceDir = name => {
    const platform = os.platform() === "win32" ? (/cygwin/.test(process.env.HOME) ? "Cygwin" : "x64") : "*-GCC";

    const hints = [
        `out/build/${ platform }-*`,
        "build.luarocks",
    ];

    if (process.env.CMAKE_BINARY_DIR) {
        hints.unshift(process.env.CMAKE_BINARY_DIR);
    }

    for (const hint of hints) {
        const file = findFile(`${ hint }/${ name }`, PROJECT_DIR);
        if (file) {
            return file;
        }
    }

    return null;
};

const opencv_SOURCE_DIR = findSourceDir("opencv/opencv-src");

const src2 = sysPath.resolve(opencv_SOURCE_DIR, "modules/python/src2");

const hdr_parser = fs.readFileSync(sysPath.join(src2, "hdr_parser.py")).toString();
const hdr_parser_start = hdr_parser.indexOf("class CppHeaderParser");
const hdr_parser_end = hdr_parser.indexOf("if __name__ == '__main__':");

const options = getOptions(PROJECT_DIR);
options.proto = LuaGenerator.proto;

waterfall([
    next => {
        mkdirp(options.output).then(performed => {
            next();
        }, next);
    },

    next => {
        const srcfiles = [];
        const protofiles = new Set();
        const matcher = /#include "([^"]+)\.pb\.h"/g;

        explore(SRC_DIR, async (path, stats, next) => {
            const relpath = path.slice(SRC_DIR.length + 1);
            const parts = relpath.split(".");
            const extname = parts.length === 0 ? "" : `.${ parts[parts.length - 1] }`;
            const extnames = parts.length === 0 ? "" : `.${ parts.slice(-2).join(".") }`;
            const isheader = [".h", ".hpp", ".hxx"].includes(extname);

            const content = await fsPromises.readFile(path);

            let match;
            matcher.lastIndex = 0;
            while ((match = matcher.exec(content))) {
                protofiles.add(`${ match[1] }.proto`);
            }

            if (isheader && ![".impl.h", ".impl.hpp", ".impl.hxx"].includes(extnames) && (content.includes("CV_EXPORTS") || /^binding[\\/]/.test(relpath))) {
                srcfiles.push(path);
            }

            next();
        }, {followSymlink: true}, err => {
            const generated_include = srcfiles.map(path => `#include "${ path.slice(SRC_DIR.length + 1).replace("\\", "/") }"`);
            next(err, srcfiles, protofiles, generated_include);
        });
    },

    (srcfiles, protofiles, generated_include, next) => {
        const mediapipe_SOURCE_DIR = findSourceDir("mediapipe/mediapipe-src");
        const protobuf_SOURCE_DIR = fs.realpathSync(`${ mediapipe_SOURCE_DIR }/bazel-mediapipe-src/external/com_google_protobuf/src`);

        const outputs = Parser.createOutputs();
        const cache = new Map();
        const opts = {
            proto_path: [
                mediapipe_SOURCE_DIR,
                protobuf_SOURCE_DIR,
            ],
            language: options.language,
            self: options.self,
            self_get: options.self_get,
            Any: options.Any,
            AnyObject: options.AnyObject,
        };

        for (const filename of protofiles) {
            opts.filename = filename;
            const abspath = opts.proto_path
                .map(dirname => sysPath.join(dirname, filename))
                .filter(candidate => fs.existsSync(candidate))[0];
            const parser = new Parser();
            parser.parseFile(fs.realpathSync(abspath), opts, outputs, cache);
        }

        custom_declarations.push(...outputs.decls);
        generated_include.push(...outputs.generated_include);
        options.typedefs = outputs.typedefs;

        next(null, srcfiles, generated_include);
    },

    (srcfiles, generated_include, next) => {
        const buffers = [];
        let nlen = 0;
        const child = spawn(Python3_EXECUTABLE, []);

        child.stderr.on("data", chunk => {
            process.stderr.write(chunk);
        });

        child.on("close", code => {
            if (code !== 0) {
                console.log(`python process exited with code ${ code }`);
                process.exit(code);
            }

            const buffer = Buffer.concat(buffers, nlen);

            const configuration = JSON.parse(buffer.toString());
            configuration.decls.push(...custom_declarations.load(options));
            configuration.generated_include = generated_include;

            for (const [name, modifiers] of CUSTOM_CLASSES) {
                configuration.decls.push([`class ${ name }`, "", modifiers, [], "", ""]);
            }

            configuration.namespaces.push(...options.namespaces);
            configuration.namespaces.push(...options.other_namespaces);

            const processor = new DeclProcessor(options);
            processor.process(configuration, options);

            next(null, processor, configuration);
        });

        child.stderr.on("data", chunk => {
            process.stderr.write(chunk);
        });

        child.stdout.on("data", chunk => {
            buffers.push(chunk);
            nlen += chunk.length;
        });

        const code = `
            import io, json, os, re, string, sys

            ${ hdr_parser
                .slice(hdr_parser_start, hdr_parser_end)
                .split("\n")
                .join(`\n${ " ".repeat(12) }`) }

            srcfiles = []
            ${ srcfiles.map(file => `srcfiles.append(${ JSON.stringify(file) })`).join(`\n${ " ".repeat(12) }`) }

            parser = CppHeaderParser(generate_umat_decls=True, generate_gpumat_decls=True)
            all_decls = []
            for hdr in srcfiles:
                decls = parser.parse(hdr)
                if len(decls) == 0 or hdr.find('/python/') != -1:
                    continue

                all_decls += decls

            # parser.print_decls(all_decls)
            print(json.dumps({"decls": all_decls, "namespaces": sorted(parser.namespaces)}, indent=4))
        `.trim().replace(/^ {12}/mg, "");

        child.stdin.write(code);
        child.stdin.end();

        // fs.writeFileSync(sysPath.join(PROJECT_DIR, "gen.py"), code.replace("# parser.print_decls", "parser.print_decls").replace("print(json.dumps", "# print(json.dumps"));
    },

    (processor, configuration, next) => {
        const generator = new LuaGenerator();
        generator.generate(processor, configuration, options, next);
    },
], err => {
    if (err) {
        throw err;
    }
    console.log(`Build files have been written to: ${ options.output }`);
});
