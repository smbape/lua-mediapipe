const fs = require("node:fs");
const sysPath = require("node:path");
const process = require("node:process");
const cpus = require("node:os").cpus().length;
const { mkdirp } = require("mkdirp");
const eachOfLimit = require("async/eachOfLimit");
const parallel = require("async/parallel");
const waterfall = require("async/waterfall");

const [source, destination, ...files] = process.argv.slice(2);

if (!source || !fs.existsSync(source)) {
    throw new Error(`'${ source }' doest not exists`);
}

const basename = sysPath.basename(destination);

eachOfLimit(files, cpus, (file, i, next) => {
    const src = sysPath.resolve(source, file);
    const dst = sysPath.resolve(destination, file);

    mkdirp(sysPath.dirname(dst)).then(performed => {
        waterfall([
            next => {
                parallel([
                    next => {
                        fs.readFile(src, next);
                    },
                    next => {
                        fs.readFile(dst, (err, buffer) => {
                            if (err && err.code === "ENOENT") {
                                err = null;
                                buffer = Buffer.from([]);
                            }
                            next(err, buffer);
                        });
                    },
                ], next);
            },

            ([srcBuffer, dstBuffer], next) => {
                const dstContent = srcBuffer.toString().replace(/#include "([^"]+)"/mg, (match, include) => {
                    if (files.includes(`lib/${ include }`)) {
                        return `#include <${ basename }/lib/${ include }>`;
                    }

                    if (files.includes(`src/${ include }`)) {
                        return `#include <${ basename }/src/${ include }>`;
                    }

                    return match;
                }).replace(/int (w?main\(int )/g, "int tool_$1");

                if (dstContent === dstBuffer.toString()) {
                    next();
                    return;
                }

                fs.writeFile(dst, dstContent, next);
            },
        ], err => next(err));
    }, next);
});
