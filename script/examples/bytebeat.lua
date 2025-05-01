--[[
bytebeat.lua - Optimized Bytebeat generator with ternary operator support

Buttons - Sample mapping mode:
    1. Signed byte interpretation
    2. Clamped division
    3. Mapped modulo
    4. Sinusoidal shaping
    5. tanh soft clipping
Outputs
    Output 1: Bytebeat sample output
]]

-- Config
local expression = [[
(t^4)%(4*(t>>6&(t>>3))^2)
]]

local freq = 8000
local step = 1
local start = 1

--[[
((t^14)+(t % 128))%(2*((t>>5)^2))
(t^4)%(4*(t>>6&(t>>3))^2)
(t^14)%(2*((t>>5))^2)
(t>>9&(t>>5))^2
(t&(t>>8))+((t>1000)?64:0)
((t>>8&t)-(t>>3&t>>8|t>>16))&128
t*(t>>12&((t>>14)+1))^2
(t&(t>>12))*(t&(t>>8))
(t&(t>>8))+(t&64)
]]

-- Cache global functions for faster access
local band = bit.band
local bor = bit.bor
local bxor = bit.bxor
local lshift = bit.lshift
local rshift = bit.rshift
local floor = math.floor
local sin = math.sin
local tanh = math.tanh
local pi = math.pi
local clamp = math.clamp

-- Operator precedence lookup table
local precedence = {
    ["*"] = 3, ["/"] = 3, ["%"] = 3,
    ["+"] = 4, ["-"] = 4,
    ["<<"] = 5, [">>"] = 5,
    ["<"] = 6, [">"] = 6, ["<="] = 6, [">="] = 6, 
    ["=="] = 7, ["!="] = 7,
    ["&"] = 8,
    ["^"] = 9,
    ["|"] = 10,
    ["?"] = 11
}

-- Simple recursive descent parser for bytebeat expressions
local function build(expr)
    local pos = 1
    local len = #expr

    -- Skip whitespace
    local function skip_whitespace()
        while pos <= len and expr:sub(pos, pos):match("%s") do
            pos = pos + 1
        end
    end

    -- Parse a number
    local function parse_number()
        local start = pos
        while pos <= len and expr:sub(pos, pos):match("%d") do
            pos = pos + 1
        end
        return tonumber(expr:sub(start, pos - 1))
    end

    -- Parse primary expressions (numbers, variables, parenthesized expressions)
    function parse_primary()
        skip_whitespace()

        local char = expr:sub(pos, pos)

        if char:match("%d") then
            -- It's a number
            return {type = "number", value = parse_number()}
        elseif char == "t" then
            -- It's the variable t
            pos = pos + 1
            return {type = "variable", name = "t"}
        elseif char == "(" then
            -- It's a parenthesized expression
            pos = pos + 1
            local result = parse_expression()

            skip_whitespace()
            if pos > len or expr:sub(pos, pos) ~= ")" then
                error("Expected closing parenthesis")
            end
            pos = pos + 1

            return result
        else
            error("Unexpected character: " .. char .. " at position " .. pos)
        end
    end

    -- Parse binary expressions with precedence climbing
    function parse_expression(min_precedence)
        min_precedence = min_precedence or 0

        local left = parse_primary()

        while true do
            skip_whitespace()

            if pos > len then break end

            local op = nil
            local current_pos = pos

            -- Try to match two-character operators first
            if pos < len then
                local two_char = expr:sub(pos, pos + 1)
                if two_char == "<<" or two_char == ">>" or 
                    two_char == "<=" or two_char == ">=" or
                    two_char == "==" or two_char == "!=" then
                    op = two_char
                    pos = pos + 2
                end
            end

            -- If no two-character operator, try one-character operators
            if not op then
                local char = expr:sub(pos, pos)
                if char:match("[%+%-%*/&|%^%%<>%?:]") then
                    op = char
                    pos = pos + 1
                end
            end

            -- Special handling for ternary operator
            if op == "?" and precedence[op] >= min_precedence then
                -- Parse the "true" expression
                local true_expr = parse_expression(0)

                -- Expect a colon
                skip_whitespace()
                if pos > len or expr:sub(pos, pos) ~= ":" then
                    error("Expected ':' in ternary operator at position " .. pos)
                end
                pos = pos + 1

                -- Parse the "false" expression
                local false_expr = parse_expression(precedence[op])

                left = {
                    type = "ternary",
                    condition = left,
                    true_expr = true_expr,
                    false_expr = false_expr
                }

            -- Normal binary operators
            elseif op and precedence[op] and precedence[op] >= min_precedence then
                -- If this operator has high enough precedence, create a binary node
                local right = parse_expression(precedence[op] + 1)

                left = {
                    type = "binary",
                    operator = op,
                    left = left,
                    right = right
                }
            else
                -- Either no operator or precedence too low
                if op then
                    pos = current_pos  -- Restore position for other parser functions
                end
                break
            end
        end

        return left
    end

    -- Start parsing the whole expression
    local ast = parse_expression()

    -- Make sure we consumed the whole expression
    skip_whitespace()
    if pos <= len then
        error("Unexpected characters at end of expression at position " .. pos)
    end

    return ast
end

-- Evaluate an AST with a given value for t
local function evaluate(ast, t_value)
    if ast.type == "number" then
        return ast.value
    elseif ast.type == "variable" and ast.name == "t" then
        return t_value
    elseif ast.type == "binary" then
        local left = evaluate(ast.left, t_value)
        local right = evaluate(ast.right, t_value)

        local op = ast.operator

        if op == "+" then
            return left + right
        elseif op == "-" then
            return left - right
        elseif op == "*" then
            return left * right
        elseif op == "/" then
            return left / (right == 0 and 1 or right)
        elseif op == "%" then
            return left % (right == 0 and 1 or right)
        elseif op == "&" then
            return band(left, right)
        elseif op == "|" then
            return bor(left, right)
        elseif op == ">>" then
            return rshift(left, right)
        elseif op == "<<" then
            return lshift(left, right)
        elseif op == "^" then
            return bxor(left, right)
        elseif op == ">" then
            return left > right and 1 or 0
        elseif op == "<" then
            return left < right and 1 or 0
        elseif op == ">=" then
            return left >= right and 1 or 0
        elseif op == "<=" then
            return left <= right and 1 or 0
        elseif op == "==" then
            return left == right and 1 or 0
        elseif op == "!=" then
            return left ~= right and 1 or 0
        else
            error("Unknown operator: " .. op)
        end
    elseif ast.type == "ternary" then
        -- Evaluate the condition first
        local condition = evaluate(ast.condition, t_value)

        -- In C, any non-zero value is considered true
        if condition ~= 0 then
            return evaluate(ast.true_expr, t_value)
        else
            return evaluate(ast.false_expr, t_value)
        end
    else
        error("Unknown type: " .. ast.type)
    end
end

local ast = build(expression)
local counter = 0
local type = 1

-- Function called by the audio system
function process()
    -- Type select button
    for i = 1, 5 do
        if block.button[i] then 
            type = i
            for j = 1, block.channels do block.blue[j] = 0 end
            break;
        end
    end
    block.blue[type] = 1

    counter = counter + step

    local t = floor((counter / block.samplerate) * freq)
    local t_value = start + t

    -- Evaluate the expression using our AST
    local sample = evaluate(ast, t_value)

    -- Mapping
    if type == 1 then -- Signed byte interpretation
        sample = ((sample % 256) < 128 and (sample % 256) or (sample % 256 - 256)) / 128 
    elseif type == 2 then -- Clamped division
        sample = clamp(sample / 255, -1, 1) 
    elseif type == 3 then -- Mapped modulo
        sample = (sample % 256) / 127 - 1 
    elseif type == 4 then -- Sinusoidal shaping
        sample = sin(((sample % 256) / 256) * pi * 2) 
    else -- (type == 5) tanh soft clipping
        sample = tanh(sample / 128) 
    end

    block.output[1] = sample
end