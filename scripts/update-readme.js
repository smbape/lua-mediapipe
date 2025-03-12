const process = require("node:process");
const sysPath = require("node:path");
const fs = require("node:fs");
const { explore } = require("fs-explorer");

const examples = [];
const basenames = [];
const output = process.argv[2];
const LF = "\n";
const NOT_SPACE_REG = /\S/g;

explore(sysPath.resolve(__dirname, "../samples/googlesamples/examples"), (path, stats, next) => {
    const basename = sysPath.basename(path);

    if (!path.endsWith(".lua")) {
        next();
        return;
    }

    const content = fs.readFileSync(path).toString().replace(/\r?\n|\r/g, LF);

    examples.push(content);
    basenames.push(basename);

    if (output) {
        fs.writeFileSync(sysPath.join(output, `${ String(examples.length).padStart(2, "0") }-${ basename }`), content);
    }

    next();
}, (path, stats, files, state, next) => {
    const basename = sysPath.basename(path);
    const skip = state === "begin" && (basename[0] === "." || basename === "BackUp");
    next(null, skip);
}, err => {
    if (err) {
        throw err;
    }

    const readmeFile = sysPath.resolve(__dirname, "../README.md");
    const readme = fs.readFileSync(readmeFile).toString().replace(/\r\n|\r/g, LF);
    const exampleStart = readme.indexOf(LF, readme.indexOf("<!-- EXAMPLES_START") + "<!-- EXAMPLES_START".length) + LF.length;
    const exampleEnd = readme.indexOf("<!-- EXAMPLES_END", exampleStart);
    const texts = ["<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN node scripts/update-readme.js TO UPDATE -->", ""];
    let i = 0;

    for (const content of examples) {
        const titleStart = content.indexOf("Title: ") + "Title: ".length;
        const titleEnd = content.indexOf(LF, titleStart + 1);
        const title = titleStart === -1 || titleEnd === -1 ? basenames[i++] : content.slice(titleStart, titleEnd).trim();

        NOT_SPACE_REG.lastIndex = content.indexOf("#!/usr/bin/env lua") + "#!/usr/bin/env lua".length;
        const start = NOT_SPACE_REG.exec(content).index;

        texts.push(...[
            `### ${ title }`,
            "",
            "```lua",
            content.slice(start),
            "```",
            "",
        ]);
    }

    texts.push("");

    fs.writeFileSync(readmeFile, readme.slice(0, exampleStart) + texts.join(LF) + readme.slice(exampleEnd));
});
