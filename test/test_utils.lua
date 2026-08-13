local lfs = require("lfs")
local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe
local resource_util = mediapipe_lua.resource_util
local std = mediapipe_lua.std
local download_utils = mediapipe.tasks.lua.core.download_utils
local fs_utils = mediapipe_lua.fs_utils

local exports = {}

local function ends_with(str, ending)
    return ending == "" or str:sub(- #ending) == ending
end

---@return string
function exports.get_resource_dir()
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
function exports.get_test_data_path(file_or_dirname_path)
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

    local resource_root_dir = exports.get_resource_dir()
    if resource_root_dir and fs_utils.exists(resource_root_dir .. "/mediapipe/tasks/testdata") then
        parents[#parents + 1] = fs_utils.absolute(resource_root_dir .. "/mediapipe/tasks/testdata")
    end

    file_or_dirname_path = file_or_dirname_path:gsub("\\", "/")

    for _, parent in ipairs(parents) do
        parent = parent:gsub("\\", "/")

        for file, _ in lfs.dir(parent) do
            if file ~= "." and file ~= ".." then
                local _file = parent .. "/" .. file

                if fs_utils.exists(_file .. "/" .. file_or_dirname_path) then
                    return _file .. "/" .. file_or_dirname_path
                end

                if ends_with(_file, "/" .. file_or_dirname_path) then
                    return _file
                end
            end
        end
    end

    return nil
end

local sha = require("sha2")

---@param file string
function exports.sha256(file)
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
function exports.download_test_files(_TEST_DATA_DIR, test_files)
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


-- look up for `k' in list of tables `parents'
local function metatables__index(parents, k)
    for i = 1, #parents do
        local v = parents[i][k] -- try `i'-th superclass
        if v then return v end
    end
end

local function __instanceof(self, constructor)
    local stack = { getmetatable(self) }
    while #stack ~= 0 do
        local mt = table.remove(stack)
        if mt == constructor then return true end
        if mt and mt.____parents__ then
            local classes = mt.____parents__
            for i = #classes, 1, -1 do
                stack[#stack + 1] = classes[i]
            end
        end
    end
    return false
end

local function default_destroy(self)
    -- nothing to do
end

local function default__tostring(self)
    local mt = getmetatable(self)
    setmetatable(self, nil)
    local str = tostring(self)
    setmetatable(self, mt)

    -- if type(self) == "table" then
    --     str = inspect(self)
    -- end

    local name = self.__name
    if name then
        str = string.format("class<%s>: %s", name, str)
    end

    return str
end

local function default__call(cls, ...)
    return cls.new(...)
end

-- http://lua-users.org/wiki/ObjectOrientationTutorial
-- https://www.lua.org/pil/16.3.html
function exports.class(cls, ...)
    local argc = select("#", ...)
    local parents = { ... }

    -- failed table lookups on the instances should fallback to the class table
    if not cls.__index then
        cls.__index = cls
    end

    cls.new = function(...)
        local self = setmetatable({}, cls)

        local __init__ = cls.__init__
        if __init__ then __init__(self, ...) end

        local __name = cls.__name
        if type(__name) == "string" and cls[__name] then cls[__name](self, ...) end

        return self
    end

    cls.__instanceof = __instanceof

    if not cls.__destroy then
        cls.__destroy = default_destroy
    end

    if not cls.__tostring then
        cls.__tostring = default__tostring
    end

    local metatable = {
        __call = default__call,
    }

    -- this is what makes the inheritance work
    -- class will search for each method in the list of its
    -- parents (`arg' is the list of parents)
    if argc > 0 then
        cls.__super__ = setmetatable({}, {
            __index = function(self, k)
                return metatables__index(parents, k)
            end
        })
        cls.__parents__ = parents
        metatable.__index = function(self, k)
            return metatables__index(parents, k)
        end
    end

    setmetatable(cls, metatable)

    return cls
end

---@class Event
---@field private cv std.condition_variable
---@overload fun(): Event
local Event = exports.class({
    __name = "Event",
})

exports.threading = {
    Event = Event
}

---@param self Event
function Event.__init__(self)
    self.cv = std.condition_variable()
end

---@param self Event
function Event.set(self)
    self.cv:notify_all()
end

---@param self Event
---@param timeout integer the maximum duration in milliseconds to wait
function Event.wait(self, timeout)
    local status = self.cv:wait_for(std.chrono.milliseconds(timeout))
    if status == std.cv_status.timeout then
        error(string.format("wait_for %d ms timeout", timeout))
    end
end

return exports
