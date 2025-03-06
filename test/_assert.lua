-- Mimic some functions of https://docs.python.org/3/library/unittest.html

local assert = require("luassert")
local mediapipe_lua = require("mediapipe_lua")
local opencv_lua = require("opencv_lua")
local round = opencv_lua.math.round

local module = {}

-- http://lua-users.org/wiki/StringRecipes
local function starts_with(str, start)
    return str:sub(1, #start) == start
end

function module.assertTrue(expr, msg)
    if msg == nil then
        msg = "expecting " .. tostring(expr) .. " to be true"
    end
    assert.is_true(expr, msg)
end

function module.assertFalse(expr, msg)
    if msg == nil then
        msg = "expecting " .. tostring(expr) .. " to be false"
    end
    assert.is_false(expr, msg)
end

function module.assertEqual(first, second, msg)
    if msg == nil then
        msg = "expecting " .. tostring(first) .. " to be equal to " .. tostring(second)
    end
    assert.are.equal(second, first, msg)
end

function module.assertNotEqual(first, second, msg)
    if msg == nil then
        msg = "expecting " .. tostring(first) .. " not to be equal to " .. tostring(second)
    end
    assert.are_not.equal(second, first, msg)
end

function module.assertGreater(first, second, msg)
    if msg == nil then
        msg = "expecting " .. tostring(first) .. " to be greater than " .. tostring(second)
    end
    assert.is_true(first > second, msg)
end

function module.assertGreaterEqual(first, second, msg)
    if msg == nil then
        msg = "expecting " .. tostring(first) .. " to be greater than or equal to " .. tostring(second)
    end
    assert.is_true(first >= second, msg)
end

function module.assertLess(first, second, msg)
    if msg == nil then
        msg = "expecting " .. tostring(first) .. " to be less than " .. tostring(second)
    end
    assert.is_true(first < second, msg)
end

function module.assertLessEqual(first, second, msg)
    if msg == nil then
        msg = "expecting " .. tostring(first) .. " to be less than or equal to " .. tostring(second)
    end
    assert.is_true(first <= second, msg)
end

function module.assertIsInstance(obj, cls, msg)
    if msg == nil then
        msg = "expecting [" .. tostring(obj) .. "] to be an instance of [" .. tostring(cls) .. "]"
    end

    if type(cls) == "table" and type(cls.isinstance) == "function" then
        assert.is_true(cls.isinstance(obj), msg)
        return
    end

    if type(cls) == "string" then
        if type(obj) == cls then
            return
        end
        assert.are.equal(obj.__type(), cls, msg)
        return
    end

    assert.is_true(false, "unexpected: " .. msg)
end

-- node scripts/func_kwargs.js module assertAlmostEqual first second '["places",,7]' '["msg",,"nil"]' '["delta",,"nil"]' | clip
function module.assertAlmostEqual(...)
    local args = { n = select("#", ...), ... }
    local has_kwarg = mediapipe_lua.kwargs.isinstance(args[args.n])
    local kwargs = has_kwarg and args[args.n] or mediapipe_lua.kwargs()
    local usedkw = 0

    -- get argument first
    local first
    local has_first = false
    if (not has_kwarg) or args.n > 1 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("first") then
            error("first was both specified as a Positional and NamedParameter")
        end
        has_first = args.n >= 1
        if has_first then
            first = args[1]
        end
    elseif kwargs:has("first") then
        -- named parameter
        has_first = true
        first = kwargs:get("first")
        usedkw = usedkw + 1
    else
        error("first is mandatory")
    end

    -- get argument second
    local second
    local has_second = false
    if (not has_kwarg) or args.n > 2 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("second") then
            error("second was both specified as a Positional and NamedParameter")
        end
        has_second = args.n >= 2
        if has_second then
            second = args[2]
        end
    elseif kwargs:has("second") then
        -- named parameter
        has_second = true
        second = kwargs:get("second")
        usedkw = usedkw + 1
    else
        error("second is mandatory")
    end

    -- get argument places
    local places = 7
    local has_places = false
    if (not has_kwarg) or args.n > 3 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("places") then
            error("places was both specified as a Positional and NamedParameter")
        end
        has_places = args.n >= 3
        if has_places then
            places = args[3]
        end
    elseif kwargs:has("places") then
        -- named parameter
        has_places = true
        places = kwargs:get("places")
        usedkw = usedkw + 1
    end

    -- get argument msg
    local msg = nil
    local has_msg = false
    if (not has_kwarg) or args.n > 4 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("msg") then
            error("msg was both specified as a Positional and NamedParameter")
        end
        has_msg = args.n >= 4
        if has_msg then
            msg = args[4]
        end
    elseif kwargs:has("msg") then
        -- named parameter
        has_msg = true
        msg = kwargs:get("msg")
        usedkw = usedkw + 1
    end

    -- get argument delta
    local delta = nil
    local has_delta = false
    if (not has_kwarg) or args.n > 5 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("delta") then
            error("delta was both specified as a Positional and NamedParameter")
        end
        has_delta = args.n >= 5
        if has_delta then
            delta = args[5]
        end
    elseif kwargs:has("delta") then
        -- named parameter
        has_delta = true
        delta = kwargs:get("delta")
        usedkw = usedkw + 1
    end

    if usedkw ~= kwargs:size() then
        error("there are " .. (kwargs:size() - usedkw) .. " unknown named parameters")
    end

    --- ====================== ---
    --- CODE LOGIC STARTS HERE ---
    --- ====================== ---

    if msg == nil then
        msg = "expecting " ..
        tostring(first) ..
        " to be almost equal to " ..
        tostring(second) .. " with decimal places of " .. tostring(places) .. " with a delta of " .. tostring(delta)
    end

    first = round(first, places)
    second = round(second, places)

    if delta == nil then
        assert.are.equal(second, first, msg)
    else
        assert.is_true(math.abs(first - second) < delta, msg)
    end
end

-- node scripts/func_kwargs.js module assertAlmostIn member container '["places",,7]' '["msg",,"nil"]' '["delta",,"nil"]' | clip
function module.assertAlmostIn ( ... )
    local args={n=select("#", ...), ...}
    local has_kwarg = mediapipe_lua.kwargs.isinstance(args[args.n])
    local kwargs = has_kwarg and args[args.n] or mediapipe_lua.kwargs()
    local usedkw = 0

    -- get argument member
    local member
    local has_member = false
    if (not has_kwarg) or args.n > 1 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("member") then
            error("member was both specified as a Positional and NamedParameter")
        end
        has_member = args.n >= 1
        if has_member then
            member = args[1]
        end
    elseif kwargs:has("member") then
        -- named parameter
        has_member = true
        member = kwargs:get("member")
        usedkw = usedkw + 1
    else
        error("member is mandatory")
    end

    -- get argument container
    local container
    local has_container = false
    if (not has_kwarg) or args.n > 2 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("container") then
            error("container was both specified as a Positional and NamedParameter")
        end
        has_container = args.n >= 2
        if has_container then
            container = args[2]
        end
    elseif kwargs:has("container") then
        -- named parameter
        has_container = true
        container = kwargs:get("container")
        usedkw = usedkw + 1
    else
        error("container is mandatory")
    end

    -- get argument places
    local places = 7
    local has_places = false
    if (not has_kwarg) or args.n > 3 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("places") then
            error("places was both specified as a Positional and NamedParameter")
        end
        has_places = args.n >= 3
        if has_places then
            places = args[3]
        end
    elseif kwargs:has("places") then
        -- named parameter
        has_places = true
        places = kwargs:get("places")
        usedkw = usedkw + 1
    end

    -- get argument msg
    local msg = nil
    local has_msg = false
    if (not has_kwarg) or args.n > 4 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("msg") then
            error("msg was both specified as a Positional and NamedParameter")
        end
        has_msg = args.n >= 4
        if has_msg then
            msg = args[4]
        end
    elseif kwargs:has("msg") then
        -- named parameter
        has_msg = true
        msg = kwargs:get("msg")
        usedkw = usedkw + 1
    end

    -- get argument delta
    local delta = nil
    local has_delta = false
    if (not has_kwarg) or args.n > 5 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("delta") then
            error("delta was both specified as a Positional and NamedParameter")
        end
        has_delta = args.n >= 5
        if has_delta then
            delta = args[5]
        end
    elseif kwargs:has("delta") then
        -- named parameter
        has_delta = true
        delta = kwargs:get("delta")
        usedkw = usedkw + 1
    end

    if usedkw ~= kwargs:size() then
        error("there are " .. (kwargs:size() - usedkw) .. " unknown named parameters")
    end

    --- ====================== ---
    --- CODE LOGIC STARTS HERE ---
    --- ====================== ---

    if type(container) ~= "table" then
        container = { container }
    end

    local first = round(member, places)

    for i, second in ipairs(container) do
        second = round(second, places)

        if delta == nil then
            if first == second then
                return
            end
        elseif math.abs(first - second) < delta then
            return
        end
    end

    if msg == nil then
        msg = "expecting " .. tostring(member) .. " to be in the collection"
    end
    assert.is_true(false, msg)
end

function module.assertLen(container, len, msg)
    if msg == nil then
        msg = "expecting length of " .. tostring(container) .. " to be equal to " .. tostring(len)
    end
    assert.are.equal(len, #container, msg)
end

function module.assertEmpty(container, msg)
    if msg == nil then
        msg = "expecting length of " .. tostring(container) .. " to be empty"
    end
    assert.are.equal(0, #container, msg)
end

function module.assertNotEmpty(container, msg)
    if msg == nil then
        msg = "expecting length of " .. tostring(container) .. " to be not empty"
    end
    assert.are_not.equal(0, #container, msg)
end

function module.assertIsNone(expr, msg)
    if type(expr) == "table" then
        if msg == nil then
            msg = "expecting table to be empty"
        end
        assert.are.equal(0, #expr, msg)
    elseif type(expr) == "userdata" then
        if msg == nil then
            msg = "expecting userdata to be an empty vector"
        end
        assert.is_true(starts_with(expr.__type(), "std::vector<"), msg)
        assert.are.equal(0, #expr, msg)
    else
        if msg == nil then
            msg = "expecting value to be none"
        end
        assert.are.equal(nil, expr, msg)
    end
end

function module.assertIn(member, container, msg)
    for i = 1, #container do
        if container[i] == member then
            return
        end
    end
    if msg == nil then
        msg = "expecting " .. tostring(member) .. " to be in the collection"
    end
    assert.is_true(false, msg)
end

function module.assertNotIn(member, container, msg)
    for i = 1, #container do
        if container[i] == member then
            if msg == nil then
                msg = "expecting " .. tostring(member) .. " to be in the collection"
            end
            assert.is_true(false, msg)
        end
    end
end

function module.assertListEqual(first, second, msg)
    module.assertEqual(#first, #second)

    for i = 1, #first do
        local imsg = msg
        local ifirst = first[i]
        local isecond = second[i]
        if imsg == nil then
            imsg = "at index " .. i .. ": expecting " .. tostring(ifirst) .. " to be equal to " .. tostring(isecond)
        end

        if type(ifirst) == type(isecond) and type(ifirst) == "table" then
            module.assertListEqual(ifirst, isecond, imsg)
        else
            module.assertEqual(ifirst, isecond, imsg)
        end
    end
end

return module
