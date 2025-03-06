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

function _assert.assertMatAlmostEqual(first, second, delta, similarity, msg)
    _assert.assertEqual(first.rows, second.rows, "expecting both matrices to have the same number of rows")
    _assert.assertEqual(first.cols, second.cols, "expecting both matrices to have the same number of columns")
    _assert.assertEqual(first:channels(), second:channels(),
        "expecting both matrices to have the same number of channels")
    _assert.assertEqual(first:depth(), second:depth(), "expecting both matrices to have the same number of depth")

    if msg == nil then
        msg = "expecting both matrices to be almost equals"
    end

    if delta == nil then
        delta = 10 ^ -7
    end

    if similarity == nil then
        similarity = 1
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
