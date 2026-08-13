#!/usr/bin/env bash

if [ "$workspaceHash" != "12ef9f65-2ade-423d-9b89-793fb036a03a" ]; then
export PATH="${PATH//\/mnt\/*:/}"

workspaceHash=12ef9f65-2ade-423d-9b89-793fb036a03a
projectDir="$(wslpath -w "$PWD" | sed -e "s#\(.*\)#/mnt/\L\1#" -e "s#\\\\#/#g" -e "s#:##")" # If docker is installed, PWD will starts with /mnt/wsl/docker-desktop-bind-mounts/
projectDirName=$(basename "$projectDir")
sourceDir="$HOME/.vs/${projectDirName}"

source "${projectDir}/scripts/tasks.sh" && open_git_project "file://${projectDir}" "${sourceDir}" || exit $?

rsync -t -v -r --include='**/.gitignore' --exclude='/.git' --filter=':- .gitignore' --delete-after \
    "${projectDir}/" "${sourceDir}" || exit $?

for ifile in $(git --git-dir "${projectDir}/.git" ls-files 2>&1); do
    touch -c -r "${projectDir}/${ifile}" "${sourceDir}/${ifile}"
done

export PATH="/snap/bin:$PATH"
export workspaceHash projectDir sourceDir
else
source "${projectDir}/scripts/tasks.sh" && open_git_project "file://${projectDir}" "${sourceDir}" || exit $?
fi
