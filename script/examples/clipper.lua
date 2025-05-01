--[[
clipper.lua - Various soft clipping functions

Inputs 
    Input 1 and 2: Signal in
    Knob 1:        Drive (-30 to 30 dB)
    Knob 2:        Bias (DC Offset, -1 to 1)
Buttons - Type select:
    1. tanh         5. Logarithmic
    2. atan         6. Cubic
    3. Fast sigmoid 7. Diode
    4. Exponential  8. tanh Padé
Outputs
    Output 1 and 2: Signal out
]]

local type = 1
local min_dB = -30
local max_dB = 30

function process()

    -- Dry signal
    local dB = ((block.knob[1] + 1) / 2) * (max_dB - min_dB) + min_dB
    local gain = 10 ^ (dB / 20)
    local bias = block.knob[2]
    local signalL = (block.input[1] * gain) + bias
    local signalR = (block.input[2] * gain) + bias
    local outL, outR

    -- Type select button
    for i = 1, block.channels do
        if block.button[i] then 
            type = i
            for j = 1, block.channels do block.blue[j] = 0 end
            break;
        end
    end
    block.blue[type] = 1

    -- Clipping based on selected type
    if type == 1 then -- Hyperbolic tangent (tanh)
        outL = math.tanh(signalL)
        outR = math.tanh(signalR)
    end
    if type == 2 then -- Arc tangent (atan)
        outL = math.atan(signalL) * 0.7
        outR = math.atan(signalR) * 0.7
    end
    if type == 3 then -- Fast sigmoid
        outL = signalL / (math.abs(signalL) + 1)
        outR = signalR / (math.abs(signalR) + 1)
    end
    if type == 4 then -- Exponential clipping
        if signalL < 0 then outL = -1 + math.exp(signalL)
        elseif signalL > 0 then outL = 1 - math.exp(-signalL)
        else outL = 0 end

        if signalR < 0 then outR = -1 + math.exp(signalR)
        elseif signalR > 0 then outR = 1 - math.exp(-signalR)
        else outR = 0 end
    end
    if type == 5 then -- Logarithmic clipping
        local max_abs = 1
        local log_max = math.log(1 + max_abs)
    
        if signalL > max_abs then outL = max_abs
        elseif signalL < -max_abs then outL = -max_abs
        elseif signalL == 0 then outL = 0
        else outL = (math.log(1 + math.abs(signalL)) / log_max) * (signalL / math.abs(signalL)) end
    
        if signalR > max_abs then outR = max_abs
        elseif signalR < -max_abs then outR = -max_abs
        elseif signalR == 0 then outR = 0
        else outR = (math.log(1 + math.abs(signalR)) / log_max) * (signalR / math.abs(signalR)) end
    end
    if type == 6 then -- Cubic clipping
        if signalL < -1 then outL = -0.6667
        elseif signalL > 1 then outL = 0.6667
        else outL = signalL - (signalL ^ 3) * 0.3333 end

        if signalR < -1 then outR = -0.6667
        elseif signalR > 1 then outR = 0.6667
        else outR = signalR - (signalR ^ 3) * 0.3333 end
    end
    if type == 7 then -- Diode clipping
        local absSignalL = math.abs(signalL)
        local absSignalR = math.abs(signalR)

        if absSignalL <= 0.3333 then  outL = 2 * absSignalL
        elseif absSignalL <= 0.6667 then  outL = -3 * (absSignalL^2) + (absSignalL * 4) - 0.3333
        else outL = 1 end

        if absSignalR <= 0.3333 then  outR = 2 * absSignalR
        elseif absSignalR <= 0.6667 then outR = -3 * (absSignalR^2) + (absSignalR * 4) - 0.3333
        else outR = 1 end
        
        outL = outL * (signalL < 0 and -1 or 1)
        outR = outR * (signalR < 0 and -1 or 1)
    else -- (type == 8) tanh Padé approximation
        if signalL < -3 then outL = -1
        elseif signalL > 3 then outL = 1
        else outL = signalL * (27 + (signalL^2)) / (27 + 9 * (signalL^2)) end

        if signalR < -3 then outR = -1
        elseif signalR > 3 then outR = 1
        else outR = signalR * (27 + (signalR^2)) / (27 + 9 * (signalR^2)) end
    end
    block.output[1],  block.output[2] = outL, outR
end