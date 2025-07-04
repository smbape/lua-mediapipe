#!/usr/bin/env bash

if [ "$workspaceHash" != "12ef9f65-2ade-423d-9b89-793fb036a03a" ]; then
export PATH="${PATH//\/mnt\/*:/}"

workspaceHash=12ef9f65-2ade-423d-9b89-793fb036a03a
projectDir="$(wslpath -w "$PWD" | sed -e "s#\(.*\)#/mnt/\L\1#" -e "s#\\\\#/#g" -e "s#:##")" # If docker is installed, PWD will starts with /mnt/wsl/docker-desktop-bind-mounts/
projectDirName=$(basename "$projectDir")
sources="$HOME/.vs/${projectDirName}/${workspaceHash}/src"

source "${projectDir}/scripts/tasks.sh" && open_git_project "file://${projectDir}" "${sources}" || exit $?

rsync -t --delete -v -r \
    --exclude=.git \
    --exclude=.idea \
    --exclude=.venv \
    --exclude=.vs \
    --exclude="*.rock" \
    --exclude="*.rockspec" \
    --exclude="*.sublime-workspace" \
    --exclude="~$*" \
    --exclude=build.luarocks \
    --exclude=.luarocks \
    --exclude=luarocks/lua.bat \
    --exclude=luarocks/lua \
    --exclude=luarocks/luarocks.bat \
    --exclude=luarocks/luarocks \
    --exclude=luarocks/lua_modules \
    --exclude=luarocks/.luarocks \
    --exclude=generated \
    --exclude=node_modules \
    --exclude=out \
    --exclude=patches/001-mediapipe-src.patch \
    --exclude=samples/testdata \
    --exclude=scripts/configure_bazel.js \
    --exclude=test/solutions/testdata \
    "${projectDir}/" "${sources}" || exit $?

export PATH="/snap/bin:$PATH"
export workspaceHash projectDir sources
else
source "${projectDir}/scripts/tasks.sh" && open_git_project "file://${projectDir}" "${sources}" || exit $?
fi
