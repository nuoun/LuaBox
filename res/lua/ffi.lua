-- ffi.lua

local ffi = require("ffi")

-- C struct layout for Lua FFI
ffi.cdef[[
    struct LuaProcessBlock {
        int64_t frame;
        float samplerate;
        float sampletime;
        int channels;
        float input[8];
        float knob[8];
        float light[8][3];
        bool button[8];
        float output[8];
    };
]]

-- Direct access to FFI casting
local raw_cast = ffi.cast

-- Constants for array bounds
local MAX_INDEX = 8
local MAX_COLOR = 3

-- Safely get / set an element from a 1D array
local function arr_get(arr, i, name)
    if i < 1 or i > MAX_INDEX then
        error("Array index out of bounds: " .. name .. "[" .. i .. "]")
        return
    end
    return arr[i - 1]
end

local function arr_set(arr, i, v, name)
    if i < 1 or i > MAX_INDEX then
        error("Array index out of bounds: " .. name .. "[" .. i .. "]")
        return
    end
    arr[i - 1] = v
end

-- Safely get / set an element from the 2D light array
local function light_get(arr, i, j, name)
    if i < 1 or i > MAX_INDEX or j > MAX_COLOR then
        error("Light index out of bounds: " .. name .. "[" .. i .. "]")
        return 0
    end
    return arr[i - 1][j]
end

local function light_set(arr, i, j, v, name)
    if i < 1 or i > MAX_INDEX or j > MAX_COLOR then
        error("Light index out of bounds: " .. name .. "[" .. i .. "]")
        return
    end
    arr[i - 1][j] = v
end

-- Cast a raw pointer to a safe proxy
function _castBlock(b)
    local raw = raw_cast("struct LuaProcessBlock*", b)

    -- Table with direct field and safe array access
    local block = {
        -- Basic fields
        samplerate = raw.samplerate,
        sampletime = raw.sampletime,
        channels = raw.channels,

        -- Frame accessor function (convert int64_t to Lua number)
        get_frame = function() return tonumber(raw.frame) end,

        -- Safe accessors for arrays
        get_input = function(i) return arr_get(raw.input, i, "input") end,
        set_input = function(i, v) arr_set(raw.input, i, v, "input") end,

        get_knob = function(i) return arr_get(raw.knob, i, "knob") end,
        set_knob = function(i, v) arr_set(raw.knob, i, v, "knob") end,

        get_button = function(i) return arr_get(raw.button, i, "button") end,
        set_button = function(i, v) arr_set(raw.button, i, v, "button") end,

        get_output = function(i) return arr_get(raw.output, i, "output") end,
        set_output = function(i, v) arr_set(raw.output, i, v, "output") end,

        -- Color component accessors (using correct index order)
        get_red = function(i) return light_get(raw.light, i, 0, "red") end,
        set_red = function(i, v) light_set(raw.light, i, 0, v, "red") end,

        get_green = function(i) return light_get(raw.light, i, 1, "green") end,
        set_green = function(i, v) light_set(raw.light, i, 1, v, "green") end,

        get_blue = function(i) return light_get(raw.light, i, 2, "blue") end,
        set_blue = function(i, v) light_set(raw.light, i, 2, v, "blue") end
    }

    -- Create sparse metatables for direct access to the struct
    block.input = setmetatable({}, {
        __index = function(_, i) return block.get_input(i) end,
        __newindex = function(_, i, v) block.set_input(i, v) end,
        __metatable = true
    })

    block.knob = setmetatable({}, {
        __index = function(_, i) return block.get_knob(i) end,
        __newindex = function(_, i, v) block.set_knob(i, v) end,
        __metatable = true
    })

    block.button = setmetatable({}, {
        __index = function(_, i) return block.get_button(i) end,
        __newindex = function(_, i, v) block.set_button(i, v) end,
        __metatable = true
    })

    block.output = setmetatable({}, {
        __index = function(_, i) return block.get_output(i) end,
        __newindex = function(_, i, v) block.set_output(i, v) end,
        __metatable = true
    })

    -- Metatable performance on 2D arrays is bad so use 1D lookups instead
    block.red = setmetatable({}, {
        __index = function(_, i) return block.get_red(i) end,
        __newindex = function(_, i, v) block.set_red(i, v) end,
        __metatable = true
    })

    block.green = setmetatable({}, {
        __index = function(_, i) return block.get_green(i) end,
        __newindex = function(_, i, v) block.set_green(i, v) end,
        __metatable = true
    })

    block.blue = setmetatable({}, {
        __index = function(_, i) return block.get_blue(i) end,
        __newindex = function(_, i, v) block.set_blue(i, v) end,
        __metatable = true
    })

    -- Special case: `block.frame` is int64_t so convert to number
    setmetatable(block, {
        __index = function(_, key)
            if key == "frame" then return block.get_frame() end
            return nil
        end,
        __metatable = true
    })

    return block
end