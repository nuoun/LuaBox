--[[
xorvco.lua - Bitwise XOR modulation using detuned sine wave oscillators

Input and knob 1: V/Oct
Input and knob 2: Detune
]]

-- Constants
local TWO_PI = 2 * math.pi
local MID_C = 261.6256
local phase1, phase2 = 0, 0

function process()
    -- Read inputs
    local VOct = block.input[1] + block.knob[1]
    local detune = block.input[2] + block.knob[2]
    -- Calculate frequency based on 1V/octave scaling
    local freq1 = MID_C * (2 ^ VOct)
    local freq2 = MID_C * (2 ^ VOct + detune)
    -- Update phase increment
    local inc1 = freq1 * block.sampletime
    local inc2 = freq2 * block.sampletime
    -- Generate sine waves
    local sine = math.sin(TWO_PI * phase1)
    local cos = math.cos(TWO_PI * phase2)   
    -- Perform bitwise operation and set output
    block.output[1] = bit.bxor(sine, cos)
    -- Increment and wrap phase
    phase1 = (phase1 + inc1) % 1
    phase2 = (phase2 + inc2) % 1
end