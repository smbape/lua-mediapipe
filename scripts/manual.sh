#!/usr/bin/env bash

# ================================
# stash for release
# ================================
bash -c 'source scripts/tasks.sh && stash_push'


# ================================
# tidy
# ================================
bash -c 'source scripts/tasks.sh && tidy'


# ================================
# bump a new version
# ================================
bash -c 'source scripts/tasks.sh && new_version'


# ================================
# build
# ================================
bash -c 'source scripts/tasks.sh && prepublish_stash_push'

bash -c 'source scripts/tasks.sh && build_full'

bash -c 'source scripts/tasks.sh && prepublish_stash_pop'


# ================================
# Windows README.md samples check
# ================================
bash -c 'source scripts/tasks.sh && test_debug_windows --bash > ./out/build/x64-Debug/test_all.sh' && \
./out/build/x64-Debug/test_all.sh && \
bash -c '
source scripts/tasks.sh && \
mkdir -p out/build/x64-Release && \
truncate -s 0 out/build/x64-Release/test_all.sh && \
test_prepublished_binary_windows --upgrade --bash \>\> $PWD/out/build/x64-Release/test_all.sh
' && \
./out/build/x64-Release/test_all.sh

# ================================
# WSL README.md samples check
# ================================
bash -c 'source scripts/tasks.sh && test_debug_wsl --bash \> ./out/build/Linux-GCC-Debug/test_all.sh' && \
bash -c 'source scripts/tasks.sh && wsl -c "source scripts/wsl_init.sh && chmod +x ./out/build/Linux-GCC-Debug/test_all.sh && ./out/build/Linux-GCC-Debug/test_all.sh"'
bash -c '
source scripts/tasks.sh && \
wsl -c "
source scripts/wsl_init.sh && \
mkdir -p out/build/Linux-GCC-Release && \
truncate -s 0 out/build/Linux-GCC-Release/test_all.sh
" && \
test_prepublished_binary_wsl --upgrade --bash \>\> \$sources/out/build/Linux-GCC-Release/test_all.sh' && \
bash -c 'source scripts/tasks.sh && wsl -c "source scripts/wsl_init.sh && chmod +x ./out/build/Linux-GCC-Release/test_all.sh && ./out/build/Linux-GCC-Release/test_all.sh"'

# ================================
# Docker images README.md samples check
# ================================
bash -c 'source scripts/tasks.sh && test_prepublished_binary_debian test-binary-ubuntu-20.04 ubuntu:20.04 -- test'
bash -c 'source scripts/tasks.sh && test_prepublished_binary_debian test-binary-ubuntu-22.04 ubuntu:22.04 -- test'
bash -c 'source scripts/tasks.sh && test_prepublished_binary_debian test-binary-ubuntu-24.04 ubuntu:24.04 -- test'
bash -c 'source scripts/tasks.sh && test_prepublished_binary_debian test-binary-debian-10 debian:10 -- test'
bash -c 'source scripts/tasks.sh && test_prepublished_binary_debian test-binary-debian-11 debian:11 -- test'
bash -c 'source scripts/tasks.sh && test_prepublished_binary_debian test-binary-debian-12 debian:12 -- test'
bash -c 'source scripts/tasks.sh && test_prepublished_binary_fedora test-binary-fedora-38 fedora:38 -- test'
bash -c 'source scripts/tasks.sh && test_prepublished_binary_fedora test-binary-fedora-39 fedora:39 -- test'
bash -c 'source scripts/tasks.sh && test_prepublished_binary_fedora test-binary-fedora-40 fedora:40 -- test'
bash -c 'source scripts/tasks.sh && test_prepublished_binary_fedora test-binary-almalinux-8 amd64/almalinux:8 -- test'
bash -c 'source scripts/tasks.sh && test_prepublished_binary_fedora test-binary-almalinux-9 amd64/almalinux:9 -- test'


# ================================
# Windows README.md install source rock
# ================================
bash -c 'source scripts/tasks.sh && test_prepublished_source_windows'

# ================================
# WSL README.md install source rock
# ================================
bash -c 'source scripts/tasks.sh && test_prepublished_source_wsl'

# ================================
# Docker images README.md install source rock
# ================================
bash -c 'source scripts/tasks.sh && test_prepublished_source_debian test-source-ubuntu-22.04 ubuntu:22.04 -- test'
bash -c 'source scripts/tasks.sh && test_prepublished_source_debian test-source-debian-11 debian:11 -- test'
bash -c 'source scripts/tasks.sh && test_prepublished_source_fedora test-source-fedora-39 fedora:39 -- test'
bash -c 'source scripts/tasks.sh && test_prepublished_source_fedora test-source-almalinux-9 amd64/almalinux:9 -- test'


# ================================
# generate doctoc
# ================================
cp -f out/prepublish/build/mediapipe_lua/docs/docs.md ./docs/ && \
cp -f out/prepublish/build/mediapipe_lua/generator/ids.json ./generator/ && \
bash -c 'node generator/index.js && source scripts/tasks.sh && doctoc'


# ================================
# add modified docs to the new_version
# ================================
bash -c 'source scripts/tasks.sh && update_new_version'


# ================================
# prepublish the new version
# ================================
bash -c 'source scripts/tasks.sh && time prepublish_windows && time prepublish_manylinux'


# ================================
# publish
# ================================
bash -c 'source scripts/tasks.sh && push_all && publish'


# ================================
# restore stash
# ================================
git stash pop
