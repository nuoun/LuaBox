--[[
8sines.lua - 8 sine wave VCOs

Inputs[1-8]:  V/Oct pitch control
Knobs[1-8:    Pitch offset (V/Oct)
Outputs[1-8]: Individual sine oscillators
]]

-- Init
local TWO_PI = 2 * math.pi
local MID_C = 261.6256

local phase, inc = {}, {}
for i = 1, block.channels do
    phase[i], inc[i] = 0, 0
end

function process()
    -- For each output
    for i = 1, block.channels do
        -- Inputs
        local VOct = block.input[i] + block.knob[i]
        -- Calculate frequency based on 1V/octave scaling
        local freq = MID_C * (2 ^ VOct)
        -- Update phase increment
        inc[i] = freq * block.sampletime
        -- Generate sine wave and set output
        block.output[i] = math.sin(TWO_PI * phase[i]) * 5
        -- Increment and wrap phase
        phase[i] = (phase[i] + inc[i]) % 1
    end
end