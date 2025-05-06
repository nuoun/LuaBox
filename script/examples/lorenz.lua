--[[
Lorenz Attractor

Inputs:
    Knob[1] = Time step
Outputs:
    Port 1-3 = X, Y, Z
]]

-- Constants
local sigma = 10
local rho = 28
local beta = 8 / 3

-- Init
local x = 0.1
local y = 0
local z = 0

function process()
    -- Input
    local min_dt = 0.000001
    local dt = math.max(min_dt, 0.001 * math.abs(block.knob[1]))

    -- Lorenz equations
    local dx = sigma * (y - x)
    local dy = x * (rho - z) - y
    local dz = x * y - beta * z

    -- Integrate
    x = x + dx * dt
    y = y + dy * dt
    z = z + dz * dt

    -- Output values
    block.output[1] = x * 0.5
    block.output[2] = y * 0.5
    block.output[3] = z * 0.5
end