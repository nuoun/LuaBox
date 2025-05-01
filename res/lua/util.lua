--[[
util.lua - Preloaded utility library

Adds general math and DSP focussed utility function to the math table
Most of these functions are based on Surge XT's Prelude, VCV Rack SDK and matlab functions
]]--

--- MATH FUNCTIONS ---

-- Clamp function limits input value between a and b
function math.clamp(x, a, b)
    return math.max(math.min(x, b), a)
end

-- Parity function returns 0 for even numbers and 1 for odd numbers
function math.parity(x)
    return (x % 2 == 1 and 1) or 0
end

-- Signum function returns -1 for negative numbers, 0 for zero, 1 for positive numbers
function math.sgn(x)
    return (x > 0 and 1) or (x < 0 and -1) or 0
end

-- Sign function returns -1 for negative numbers and 1 for positive numbers or zero
function math.sign(x)
    return (x < 0 and -1) or 1
end

-- Linearly interpolates value from in range to out range
function math.rescale(value, in_min, in_max, out_min, out_max)
    return (((value - in_min) * (out_max - out_min)) / (in_max - in_min)) + out_min
end

-- Returns the norm of the two components (hypotenuse)
function math.norm(a, b)
    return math.sqrt(a ^ 2 + b ^ 2)
end

-- Returns the absolute range between the two numbers
function math.range(a, b)
    return math.abs(a - b)
end

-- Returns greatest common denominator between a and b
-- Use with integers only!
function math.gcd(a, b)
    local x = a
    local y = b
    local t

    while y ~= 0 do
        t = y
        y = x % y
        x = t
    end

    return x
end

-- Returns least common multiple between a and b
-- Use with integers only!
function math.lcm(a, b)
    local t = a

    while t % b ~= 0 do
        t = t + a
    end

    return t
end

-- Returns a table with the cumulative product of the elements in the input table
function math.cumprod(t)
    local o = {}
    o[1] = t[1]
    for i = 2, #t do
        o[i] = o[i - 1] * t[i]
    end
    return o
end

-- Returns a table with the cumulative sum of the elements in the input table
function math.cumsum(t)
    local o = {}
    o[1] = t[1]
    for i = 2, #t do
        o[i] = o[i - 1] + t[i]
    end
    return o
end

-- Returns a table containing num_points linearly spaced numbers from start_point to end_point
function math.linspace(start_point, end_point, num_points)
    if num_points < 2 then
        return {start_point}
    end
    local t = {}
    local step = (end_point - start_point) / (num_points - 1)
    for i = 1, num_points do
        t[i] = start_point + (i - 1) * step
    end
    return t
end

-- Returns a table containing num_points logarithmically spaced numbers from 10^start_point to 10^end_point
function math.logspace(start_point, end_point, num_points)
    if num_points < 2 then
        return {start_point}
    end
    local t = {}
    local step = (end_point - start_point) / (num_points - 1)
    for i = 1, num_points do
        local exponent = start_point + (i - 1) * step
        t[i] = 10 ^ exponent
    end
    return t
end

-- Returns a table of length n, or a multidimensional table with {n, n, ..} dimensions all initialized with zeros
function math.zeros(dimensions)
    if type(dimensions) == "number" then
        dimensions = {dimensions}
    elseif type(dimensions) ~= "table" or #dimensions == 0 then
        return {0}
    end
    local function create_array(dimensions, depth)
        local size = dimensions[depth]
        local t = {}
        for i = 1, size do
            if depth < #dimensions then
                t[i] = create_array(dimensions, depth + 1)
            else
                t[i] = 0
            end
        end
        return t
    end
    return create_array(dimensions, 1)
end

-- Returns a table or multidimensional table with every numerical value in the input table offset by x
function math.offset(t, x)
    local o = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            o[k] = math.offset(v, x)
        elseif type(v) == "number" then
            o[k] = v + x
        else
            o[k] = v
        end
    end
    return o
end

-- Returns the maximum absolute value found in the input table
function math.max_abs(t)
    local o = 0
    for i = 1, #t do
            local a = math.abs(t[i])
            if a > o then o = a end
    end
    return o
end

-- Returns the normalized sinc function for a table of input values
function math.sinc(t)
    local o = {}
    for i, x in ipairs(t) do
        if x == 0 then
            o[i] = 1
        else
            o[i] = math.sin(math.pi * x) / (math.pi * x)
        end
    end
    return o
end