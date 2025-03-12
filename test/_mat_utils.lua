local mediapipe_lua = require("mediapipe_lua")
local opencv_lua = require("opencv_lua")
local cv = opencv_lua.cv
local _assert = require("_assert")

math.randomseed(cv.getTickCount()) -- Make the starting point unpredictable

local module = {}

function module.randomImage(width, height, type, low, high)
    local image = cv.Mat(height, width, type)
    cv.randu(image, 0.0 + low, 0.0 + high)
    return image
end

function module.sliceLastDim(mat, start, end_)
    local sizes = mat.sizes
    local channels = mat:channels()
    if mat.dims == 2 and channels ~= 1 then
        sizes[#sizes + 1] = channels
    end

    local ranges = {}
    for i = 1, #sizes - 1 do
        ranges[#ranges + 1] = cv.Range.all()
    end
    ranges[#ranges + 1] = { start, end_ }

    return cv.Mat(mat:reshape(1, sizes), ranges)
end

local function matSizesToString(mat)
    local sizes = mat.sizes
    local size = "["

    for i = 1, #sizes do
        if i ~= 1 then
            size = size .. " x "
        end
        size = size .. sizes[i]
    end

    if mat.dims == 2 then
        size = size.. " x " .. mat:channels()
    end

    size = size .. "]"

    return size
end

function _assert.assertMatEqual(first, second, msg)
    _assert.assertEqual(first.rows, second.rows, "expecting both matrices to have the same number of rows")
    _assert.assertEqual(first.cols, second.cols, "expecting both matrices to have the same number of columns")
    _assert.assertEqual(first:channels(), second:channels(),
        "expecting both matrices to have the same number of channels")
    _assert.assertEqual(first:depth(), second:depth(), "expecting both matrices to have the same number of depth")

    if msg == nil then
        msg = "expecting both matrices to be equals"
    end

    local absdiff = cv.absdiff(first, second):reshape(1)
    _assert.assertEqual(cv.countNonZero(absdiff), 0, msg)
end

-- node scripts/func_kwargs.js _assert assertMatAlmostEqual first second '["delta",,1e-7]' '["similarity",,1]' '["msg",,"nil"]' | clip
function _assert.assertMatAlmostEqual ( ... )
    local args={n=select("#", ...), ...}
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

    -- get argument delta
    local delta = 1e-7
    local has_delta = false
    if (not has_kwarg) or args.n > 3 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("delta") then
            error("delta was both specified as a Positional and NamedParameter")
        end
        has_delta = args.n >= 3
        if has_delta then
            delta = args[3]
        end
    elseif kwargs:has("delta") then
        -- named parameter
        has_delta = true
        delta = kwargs:get("delta")
        usedkw = usedkw + 1
    end

    -- get argument similarity
    local similarity = 1
    local has_similarity = false
    if (not has_kwarg) or args.n > 4 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("similarity") then
            error("similarity was both specified as a Positional and NamedParameter")
        end
        has_similarity = args.n >= 4
        if has_similarity then
            similarity = args[4]
        end
    elseif kwargs:has("similarity") then
        -- named parameter
        has_similarity = true
        similarity = kwargs:get("similarity")
        usedkw = usedkw + 1
    end

    -- get argument msg
    local msg = nil
    local has_msg = false
    if (not has_kwarg) or args.n > 5 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("msg") then
            error("msg was both specified as a Positional and NamedParameter")
        end
        has_msg = args.n >= 5
        if has_msg then
            msg = args[5]
        end
    elseif kwargs:has("msg") then
        -- named parameter
        has_msg = true
        msg = kwargs:get("msg")
        usedkw = usedkw + 1
    end

    if usedkw ~= kwargs:size() then
        error("there are " .. (kwargs:size() - usedkw) .. " unknown named parameters")
    end

    --- ====================== ---
    --- CODE LOGIC STARTS HERE ---
    --- ====================== ---

    _assert.assertEqual(first.rows, second.rows, "expecting both matrices to have the same number of rows")
    _assert.assertEqual(first.cols, second.cols, "expecting both matrices to have the same number of columns")
    _assert.assertEqual(first:channels(), second:channels(),
        "expecting both matrices to have the same number of channels")
    _assert.assertEqual(first:depth(), second:depth(), "expecting both matrices to have the same number of depth")

    if msg == nil then
        msg = "expecting both matrices to be almost equals"
    end

    local absdiff = cv.compare(cv.absdiff(first, second):reshape(1), delta, cv.CMP_GE)
    local num_pixels = first:total()
    local consistent_pixels = num_pixels - cv.countNonZero(absdiff)
    _assert.assertGreaterEqual(consistent_pixels / num_pixels, similarity, msg)
end

function _assert.assertMatDim(first, second, msg)
    first = matSizesToString(first)
    second = matSizesToString(second)

    if msg == nil then
        msg = "expecting both matrices to have the same size and the same number of channels : " ..
        first .. " ~= " .. second
    end

    _assert.assertEqual(first, second, msg)
end

function _assert.assertMatLess(first, second, msg)
    if cv.Mat.isinstance(first) and cv.Mat.isinstance(second) and first:depth() ~= second:depth() then
        first = first:convertTo(second:depth())
    end

    if cv.Mat.isinstance(first) and type(second) == "number" then
        first = first:reshape(1)
    end

    if type(first) == "number" and cv.Mat.isinstance(second) then
        second = second:reshape(1)
    end

    if cv.Mat.isinstance(first) and cv.Mat.isinstance(second) then
        _assert.assertMatDim(first, second, msg)
    end

    if msg == nil then
        msg = "Matrices are not less-ordered"
    end

    local diff = cv.compare(first, second, cv.CMP_GE)
    _assert.assertEqual(cv.countNonZero(diff), 0, msg)
end

function _assert.assertMatDiffLess(first, second, threshold, msg)
    if type(first) == "table" then
        first = cv.Mat.createFromArray(first, cv.CV_64F)
    end

    if type(second) == "table" then
        second = cv.Mat.createFromArray(second, cv.CV_64F)
    end

    if cv.Mat.isinstance(first) and cv.Mat.isinstance(second) then
        if first:depth() ~= second:depth() then
            first = first:convertTo(cv.CV_64F)
            second = second:convertTo(cv.CV_64F)
        end
        _assert.assertMatDim(first, second, msg)
    end

    if msg == nil then
        msg = "Diff between matrices is not less than " .. threshold
    end

    local prediction_error = cv.absdiff(first, second)
    _assert.assertMatLess(prediction_error, threshold, msg)
end

-- node scripts/func_kwargs.js _assert assertMatAllClose actual desired '["rtol",,1e-07]' '["atol",,0.0]' '["msg",,"nil"]' | clip
function _assert.assertMatAllClose ( ... )
    local args={n=select("#", ...), ...}
    local has_kwarg = mediapipe_lua.kwargs.isinstance(args[args.n])
    local kwargs = has_kwarg and args[args.n] or mediapipe_lua.kwargs()
    local usedkw = 0

    -- get argument actual
    local actual
    local has_actual = false
    if (not has_kwarg) or args.n > 1 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("actual") then
            error("actual was both specified as a Positional and NamedParameter")
        end
        has_actual = args.n >= 1
        if has_actual then
            actual = args[1]
        end
    elseif kwargs:has("actual") then
        -- named parameter
        has_actual = true
        actual = kwargs:get("actual")
        usedkw = usedkw + 1
    else
        error("actual is mandatory")
    end

    -- get argument desired
    local desired
    local has_desired = false
    if (not has_kwarg) or args.n > 2 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("desired") then
            error("desired was both specified as a Positional and NamedParameter")
        end
        has_desired = args.n >= 2
        if has_desired then
            desired = args[2]
        end
    elseif kwargs:has("desired") then
        -- named parameter
        has_desired = true
        desired = kwargs:get("desired")
        usedkw = usedkw + 1
    else
        error("desired is mandatory")
    end

    -- get argument rtol
    local rtol = 1e-7
    local has_rtol = false
    if (not has_kwarg) or args.n > 3 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("rtol") then
            error("rtol was both specified as a Positional and NamedParameter")
        end
        has_rtol = args.n >= 3
        if has_rtol then
            rtol = args[3]
        end
    elseif kwargs:has("rtol") then
        -- named parameter
        has_rtol = true
        rtol = kwargs:get("rtol")
        usedkw = usedkw + 1
    end

    -- get argument atol
    local atol = 0.0
    local has_atol = false
    if (not has_kwarg) or args.n > 4 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("atol") then
            error("atol was both specified as a Positional and NamedParameter")
        end
        has_atol = args.n >= 4
        if has_atol then
            atol = args[4]
        end
    elseif kwargs:has("atol") then
        -- named parameter
        has_atol = true
        atol = kwargs:get("atol")
        usedkw = usedkw + 1
    end

    -- get argument msg
    local msg = nil
    local has_msg = false
    if (not has_kwarg) or args.n > 5 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("msg") then
            error("msg was both specified as a Positional and NamedParameter")
        end
        has_msg = args.n >= 5
        if has_msg then
            msg = args[5]
        end
    elseif kwargs:has("msg") then
        -- named parameter
        has_msg = true
        msg = kwargs:get("msg")
        usedkw = usedkw + 1
    end

    if usedkw ~= kwargs:size() then
        error("there are " .. (kwargs:size() - usedkw) .. " unknown named parameters")
    end

    --- ====================== ---
    --- CODE LOGIC STARTS HERE ---
    --- ====================== ---

    if type(actual) == "table" then
        actual = cv.Mat.createFromArray(actual, cv.CV_64F)
    end

    if type(desired) == "table" then
        desired = cv.Mat.createFromArray(desired, cv.CV_64F)
    end

    if cv.Mat.isinstance(actual) and cv.Mat.isinstance(desired) then
        if actual:depth() ~= desired:depth() then
            actual = actual:convertTo(cv.CV_64F)
            desired = desired:convertTo(cv.CV_64F)
        end
        _assert.assertMatDim(actual, desired, msg)
    end

    if msg == nil then
        msg = "Not equal to tolerance rtol=" .. rtol .. ", atol=" .. atol
    end

    local a = cv.absdiff(actual, desired)
    local b = atol + rtol * cv.absdiff(desired, 0.0)

    _assert.assertMatLess(a, b, msg)
end

function _assert.assertMatGreaterEqual(first, second, msg)
    if cv.Mat.isinstance(first) and cv.Mat.isinstance(second) and first:depth() ~= second:depth() then
        first = first:convertTo(second:depth())
    end

    if cv.Mat.isinstance(first) and type(second) == "number" then
        first = first:reshape(1)
    end

    if type(first) == "number" and cv.Mat.isinstance(second) then
        second = second:reshape(1)
    end

    if msg == nil then
        msg = "Matrices are not greater or equal ordered"
    end

    local diff = cv.compare(first, second, cv.CMP_LT)
    _assert.assertEqual(cv.countNonZero(diff), 0, msg)
end

return module
