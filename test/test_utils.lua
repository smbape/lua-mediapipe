local lfs = require("lfs")
local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

local download_utils = mediapipe.lua.solutions.download_utils
local fs_utils = mediapipe_lua.fs_utils
local resource_util = mediapipe.lua._framework_bindings.resource_util

local module = {}

local function ends_with(str, ending)
    return ending == "" or str:sub(- #ending) == ending
end

---@return string
function module.get_resource_dir()
    return resource_util.get_resource_dir()
end

---@return string
local function find_testdata_srcdir()
    return mediapipe_lua.fs_utils.findFile("mediapipe/mediapipe-src/mediapipe/tasks/testdata", mediapipe_lua.kwargs({
        hints = {
            "build.luarocks",
            "out/build/Linux-GCC-Debug",
            "out/build/Linux-GCC-Release",
            "out/build/x64-Debug",
            "out/build/x64-Release",
            "out/prepublish/build/mediapipe_lua/build.luarocks",
        }
    }))
end

---@param file_or_dirname_path string
---@return string|nil
function module.get_test_data_path(file_or_dirname_path)
    if fs_utils.exists(file_or_dirname_path) then
        return fs_utils.absolute(file_or_dirname_path)
    end

    local parents = {}

    local test_srcdir = os.getenv("TEST_SRCDIR")
    if test_srcdir and fs_utils.exists(test_srcdir) then
        parents[#parents + 1] = fs_utils.absolute(test_srcdir)
    end

    local testdata_srcdir = find_testdata_srcdir()
    if testdata_srcdir and fs_utils.exists(testdata_srcdir) then
        parents[#parents + 1] = testdata_srcdir
    end

    local resource_root_dir = module.get_resource_dir()
    if resource_root_dir and fs_utils.exists(resource_root_dir .. "/mediapipe/tasks/testdata") then
        parents[#parents + 1] = fs_utils.absolute(resource_root_dir .. "/mediapipe/tasks/testdata")
    end

    file_or_dirname_path = file_or_dirname_path:gsub("\\", "/")

    for _, parent in ipairs(parents) do
        parent = parent:gsub("\\", "/")

        for file, _ in lfs.dir(parent) do
            if file ~= "." and file ~= ".." then
                file = parent .. "/" .. file
                if fs_utils.exists(file .. "/" .. file_or_dirname_path) then
                    return file .. "/" .. file_or_dirname_path
                end

                if ends_with(file, "/" .. file_or_dirname_path) then
                    return file
                end
            end
        end
    end

    return nil
end

local sha = require("sha2")

---@param file string
function module.sha256(file)
    local f = io.open(file, "rb")
    if f == nil then
        error(file)
        return
    end

    local sha256 = sha.sha256()  -- create calculation instance #1
    for message_part in function() return f:read(4096) end do  -- "f:lines(4096)" is shorter but incompatible with Lua 5.1
       sha256(message_part)
    end
    f:close()
    print(sha256(), file)
end

---@param _TEST_DATA_DIR string
---@param test_files (string|table)[]
function module.download_test_files(_TEST_DATA_DIR, test_files)
    for _, kwargs in ipairs(test_files) do
        if type(kwargs) == "string" then
            kwargs = {
                url = "https://storage.googleapis.com/mediapipe-assets/" .. kwargs,
                output = kwargs,
            }
        elseif kwargs.url == nil then
            kwargs.url = "https://storage.googleapis.com/mediapipe-assets/" .. kwargs.output
        end

        kwargs = mediapipe_lua.kwargs(kwargs)

        if type(kwargs.output) == "string" then
            kwargs.output = _TEST_DATA_DIR .. "/" .. kwargs.output
        end

        download_utils.download(kwargs)
        -- module.sha256(kwargs.output)
    end
end

return module
