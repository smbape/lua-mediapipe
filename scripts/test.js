const process = require("node:process");
const fs = require("node:fs");
const os = require("node:os");
const { spawn, spawnSync } = require("node:child_process");
const sysPath = require("node:path");
const eachOfLimit = require("async/eachOfLimit");
const waterfall = require("async/waterfall");
const { explore } = require("fs-explorer");

const batchSuffix = os.platform() === "win32" ? ".bat" : "";
const exeSuffix = os.platform() === "win32" ? ".exe" : "";
const WORKSPACE_ROOT = process.env.WORKSPACE_ROOT ? sysPath.resolve(process.env.WORKSPACE_ROOT) : sysPath.resolve(__dirname, "..");
const LUAROCKS_BINDIR = process.env.LUAROCKS_BINDIR ? sysPath.resolve(process.env.LUAROCKS_BINDIR) : sysPath.join(WORKSPACE_ROOT, "luarocks");
const luarocks = sysPath.join(LUAROCKS_BINDIR, `luarocks${ batchSuffix }`);

const spawnShellSync = (cmd, args, options = {}) => {
    // https://nodejs.org/docs/latest-v18.x/api/child_process.html#spawning-bat-and-cmd-files-on-windows
    if (os.platform() === "win32" && (cmd.endsWith(".bat") || cmd.endsWith(".cmd"))) {
        if (cmd.includes(" ")) {
            cmd = `"${ cmd }"`;
        }
        options.shell = true;
    }

    return spawnSync(cmd, args, options);
};

const lua_interpreter = spawnShellSync(luarocks, ["config", "lua_interpreter"]).stdout.toString().trim();
const LUA_BINDIR = spawnShellSync(luarocks, ["config", "variables.LUA_BINDIR"]).stdout.toString().trim();
const LUA_BINDIR_DEBUG = LUA_BINDIR.replace("Release", "Debug");
const ABIVER = spawnShellSync(luarocks, ["config", "lua_version"]).stdout.toString().trim();
const LUA_MODULES = sysPath.join(LUAROCKS_BINDIR, "lua_modules");

const SAMPLES_PATH = sysPath.join(WORKSPACE_ROOT, "samples");
const PYTHON_VENV_PATH = process.env.PYTHON_VENV_PATH ? sysPath.resolve(process.env.PYTHON_VENV_PATH) : sysPath.join(SAMPLES_PATH, ".venv");
const PYTHON = sysPath.join(PYTHON_VENV_PATH, os.platform() === "win32" ? "Scripts" : "bin", `python${ exeSuffix }`);

const config = {
    Debug: {
        exe: sysPath.join(LUA_BINDIR_DEBUG, lua_interpreter),
        argv: ["-l", "setup"],
        env: {},
    },
    Release: {
        exe: sysPath.join(LUAROCKS_BINDIR, `lua${ batchSuffix }`),
        argv: ["-l", "setup"],
        env: {},
    },
};

if (os.platform() !== "win32" && fs.existsSync(config.Debug.exe)) {
    const LD_LIBRARY_PATH = [];

    const { OpenCVLua_DIR } = process.env;
    if (fs.existsSync(OpenCVLua_DIR)) {
        const OpenCVLua_LIBDIR = sysPath.resolve(OpenCVLua_DIR, "lib");
        if (fs.existsSync(OpenCVLua_LIBDIR)) {
            LD_LIBRARY_PATH.push(OpenCVLua_LIBDIR);
        }
    }

    if (process.env.LD_LIBRARY_PATH) {
        LD_LIBRARY_PATH.push(process.env.LD_LIBRARY_PATH);
    }

    config.Debug.env.LD_LIBRARY_PATH = LD_LIBRARY_PATH.join(":");
}

const unixPath = path => {
    return path.replaceAll("\\", "/").replace(/^(\w+):/, (match, drive) => {
        return `/${ drive.toLowerCase() }`;
    });
};

const unixEscape = (arg, verbatim = true) => {
    if (verbatim && os.platform() === "win32" && arg[0] === "/" && arg[1] !== "/") {
        arg = `/${ arg }`;
    }

    if (/[^\w/=.-]/.test(arg)) {
        arg = `'${ arg.replaceAll("'", "'\\''") }'`;
    }

    return arg;
};

const unixEnv = (key, value) => {
    if (os.platform() === "win32" && key === "PATH") {
        value = value.split(sysPath.delimiter).map(unixPath).join(":");
    }
    return `${ key }=${ unixEscape(value, false) }`;
};

const unixCmd = argv => {
    return argv.map(arg => unixEscape(arg)).join(" ");
};

const run = (file, env, options, next) => {
    const { BUILD_TYPE, MEDIAPIPE_BUILD_TYPE, OPENCV_BUILD_TYPE } = options.env;
    if (
        BUILD_TYPE && BUILD_TYPE !== env.BUILD_TYPE
        || MEDIAPIPE_BUILD_TYPE && MEDIAPIPE_BUILD_TYPE !== env.MEDIAPIPE_BUILD_TYPE
        || OPENCV_BUILD_TYPE && OPENCV_BUILD_TYPE !== env.OPENCV_BUILD_TYPE
    ) {
        next(null, 0);
        return;
    }

    const keys = Array.from(new Set([...Object.keys(config[env.BUILD_TYPE].env), ...Object.keys(env)]));
    env = Object.assign({}, process.env, config[env.BUILD_TYPE].env, options.env, env);

    const extname = sysPath.extname(file);

    const args = [];

    if (extname === ".lua") {
        const argv = [...config[env.BUILD_TYPE].argv, file, ...options.argv];
        if (file.split(sysPath.sep)[0] === "test" && file.endsWith("_test.lua") && options.argv.length === 0) {
            argv.push("-v", "--output=gtest");
        }
        args.push(config[env.BUILD_TYPE].exe, argv);
    } else if (extname === ".py") {
        args.push(PYTHON, [file, ...options.argv]);
    } else {
        throw new Error(`Unsupported extenstion ${ extname } for file ${ file }`);
    }

    const cmd = [keys.map(key => unixEnv(key, env[key])).join(" "), unixCmd(args.flat())].join(" ");

    if (options.bash) {
        console.log(cmd);
        next(null, 0);
        return;
    }

    console.log(cmd);

    const opts = {
        stdio: options.stdio,
        env,
        cwd: options.cwd,
    };

    // https://nodejs.org/docs/latest-v18.x/api/child_process.html#spawning-bat-and-cmd-files-on-windows
    if (os.platform() === "win32" && (args[0].endsWith(".bat") || args[0].endsWith(".cmd"))) {
        if (args[0].includes(" ")) {
            args[0] = `"${ args[0] }"`;
        }
        opts.shell = true;
    }

    const child = spawn(...args, opts);

    child.on("error", err => {
        if (next !== null) {
            next(err);
            next = null;
        }
    });

    child.on("close", (code, signal) => {
        if (next !== null) {
            next(code, signal);
            next = null;
        }
    });

    if (typeof options.run === "function") {
        options.run(child);
    }
};

// Source - https://unix.stackexchange.com/questions/799584/bash-exception-handling-with-a-stack-trace-and-cleanup-code-how-to-implement#answer-799585
// Posted by user3207874.
// Retrieved 2026-09-12, License - CC BY-SA 4.0

const bash_init = `
#!/usr/bin/env bash

set -Eeuo pipefail

trap 'catch' ERR

catch() {
    local exit_code=$?
    local cmd="$BASH_COMMAND"
    local i

    # Check if exit was due to error
    if [ $exit_code -ne 0 ]; then
        echo ""
        echo "[-] ERROR $exit_code during command: $cmd"
        echo "Call stack:"
        for ((i=1; i<\${#FUNCNAME[@]}; i++)); do
            local func="\${FUNCNAME[$i]}"
            local src="\${BASH_SOURCE[$i]}"
            local line="\${BASH_LINENO[$((i - 1))]}"

            # Added to track nested function calls from functions
            # Extract the actual line of code (skip if file inaccessible)
            if [[ -r "$src" ]]; then
                local code_line
                code_line=$(sed -n "\${line}s/^[[:space:]]*/    /p" "$src")
                echo "  at $src:$line in function $func:"
                echo "$code_line"
            else
                echo "  at $src:$line in function $func (source not readable)"
            fi
        done

        # echo "Tip: You can put any exception handling code here"
    fi
}

`.trim();

const runFile = (file, options, cb) => {
    waterfall([
        next => {
            run(file, {
                BUILD_TYPE: "Release",
                MEDIAPIPE_BUILD_TYPE: "Release",
                OPENCV_BUILD_TYPE: "Release",
            }, options, next);
        },

        (signal, next) => {
            run(file, {
                BUILD_TYPE: "Debug",
                MEDIAPIPE_BUILD_TYPE: "Debug",
                OPENCV_BUILD_TYPE: "Debug",
            }, options, next);
        },
    ], (code, signal) => {
        cb(code);
    });
};

const main = (options, cb) => {
    options = Object.assign({
        cwd: WORKSPACE_ROOT,
        includes: [],
        includes_ext: [".lua"],
        excludes: [],
        argv: [],
        stdio: "inherit",
    }, options);

    const { cwd, includes, includes_ext, excludes } = options;

    if (options.bash) {
        console.log([
            bash_init,
            "",
            `cd ${ unixEscape(unixPath(cwd), false) }`,
            "",
        ].join("\n"));
    }

    const runs = new Set();

    waterfall([
        next => {
            eachOfLimit(["test", "samples"], 1, (directory, i, next) => {
                explore(sysPath.join(cwd, directory), (path, stats, next) => {
                    const file = sysPath.relative(cwd, path);
                    const basename = sysPath.basename(file);
                    const extname = sysPath.extname(file);

                    if (
                        directory === "test" && !file.endsWith("_test.lua") ||
                        (includes.length === 0 || !includes.some(include => basename.startsWith(include))) && [ "_", "." ].includes(basename[0]) ||
                        !includes_ext.includes(extname) ||
                        excludes.some(exclude => basename.startsWith(exclude)) ||
                        includes.length !== 0 && !includes.some(include => basename.includes(include) || file.replaceAll("\\", "/") === include.replaceAll("\\", "/"))
                    ) {
                        next();
                        return;
                    }

                    runs.add(file.replaceAll("\\", "/"));
                    runFile(file, options, next);
                }, (path, stats, files, state, next) => {
                    const basename = sysPath.basename(path);
                    const skip = state === "begin" && (basename[0] === "." || basename === "BackUp");
                    next(null, skip);
                }, err => {
                    if (err && err.code === "ENOENT") {
                        err = null;
                    }
                    next(err);
                });
            }, next);
        },
        next => {
            eachOfLimit(includes, 1, (file, i, next) => {
                if (fs.existsSync(file) && !fs.lstatSync(file).isDirectory() && !runs.has(file.replaceAll("\\", "/"))) {
                    runFile(file, options, next);
                } else {
                    next();
                }
            }, next);
        },
    ], cb);
};

exports.main = main;

if (typeof require !== "undefined" && require.main === module) {
    const options = {
        includes: [],
        excludes: [],
        argv: [],
        env: {},
        "--": 0,
    };

    for (const arg of process.argv.slice(2)) {
        if (arg === "--") {
            options[arg]++;
        } else if (arg[0] === "!") {
            options.excludes.push(arg.slice(1));
        } else if (options["--"] === 1 && arg[0] !== "-") {
            options.includes.push(arg);
        } else if (options["--"] > 1 || options["--"] === 1 && arg[0] === "-") {
            options.argv.push(arg);
        } else if (["--Debug", "--Release"].includes(arg)) {
            options.env.BUILD_TYPE = arg.slice(2);
        } else if (arg === "--bash") {
            options[arg.slice(2)] = true;
        } else {
            options.cwd = sysPath.resolve(arg);
            options["--"] = 1;
        }
    }

    main(options, err => {
        if (err) {
            if (!Array.isArray(err)) {
                throw err;
            }

            const code = err.flat(Infinity)[0];
            if (typeof code !== "number") {
                throw code;
            }

            process.exitCode = code;
        }
    });
}
