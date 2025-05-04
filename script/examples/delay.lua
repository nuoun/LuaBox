--[[
combdelay.lua - Delay with added feedback combfilter

Input 1: Signal in

Knobs:
    Knob 1: Delay time
    Knob 2: Feedback
    Knob 3: Dry / wet mix

Outputs
    Output 1: Delay out
    Output 2: Comb filter out

]]

local samplerate, bufferlength = block.samplerate, block.samplerate
local index = 1

-- Initialize delay buffer
local delaybuffer = {}
for i = 1, bufferlength do
    delaybuffer[i] = 0
end

-- Helper function to wrap buffer index
local function wrap(i)
    return ((i - 1) % bufferlength) + 1
end

function process()
    -- Inputs
    local input = block.input[1]
    local delaytime = math.max(0.01, math.abs(block.knob[1]))
    local feedback = block.knob[2] * 0.7
    local mix = (block.knob[3] + 1) * 0.5 -- Negative mix acts like a combfilter, not a bug but a feature
    
    -- Delay length in samples
    local delaysamples = math.floor(delaytime * bufferlength)
    if delaysamples < 1 then delaysamples = 1 end  -- Prevent zero delay
    
    -- Calculate read index
    local readindex = wrap(index - delaysamples)
    
    -- Integer part and fractional part for interpolation
    local i1 = math.floor(readindex)
    local i2 = wrap(i1 + 1)
    local frac = readindex - i1
    
    -- Linear interpolation
    local delayed = (1 - frac) * delaybuffer[i1] + frac * delaybuffer[i2]
    
    -- Delay out with mix control
    block.output[1] = input * (1 - mix) + delayed * mix
    
    -- Inverted output for combfilter effect
    block.output[2] = input * (1 - mix) + -delayed * mix
    
    -- Write input + feedback into buffer
    delaybuffer[index] = input + delayed * feedback
    
    -- Increment and wrap index
    index = wrap(index + 1)
end