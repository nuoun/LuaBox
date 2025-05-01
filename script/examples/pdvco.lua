--[[
pdvco.lua - CZ-style phase distortion VCO with feedback

Inputs:
    Input 1:  V/Oct pitch control
    Input 2:  Fine tune CV input (-5V to +5V, scaled to ±1 semitone)
    Input 3:  Phase distortion modulation (-5V to +5V)
    Input 4:  Feedback modulation (-5V to +5V)
Knobs:
    Knob 1:   Pitch offset (V/Oct, scaled to ±1 octave)
    Knob 2:   Fine tune offset (scaled to ±1 semitone)
    Knob 3:   Phase distortion offset
    Knob 4:   Feedback offset
Output:
    Output 1: Audio output
]]

local TWO_PI = 2 * math.pi
local MID_C = 261.6256
local phase, inc, feedback = 0, 0, 0

function phase_distortion(phase, distort)
    local d = math.max(0.01, math.min(distort, 0.99))
    if phase < d then
        return (0.5 / d) * phase
    else
        return 0.5 + (0.5 / (1 - d)) * (phase - d)
    end
end

function process()
    local VOct = block.input[1] + block.knob[1]
    local tune = (block.input[2] * 0.016666666666) + (block.knob[2] * 0.08333333333)
    local distort = (block.input[3] * 0.2) + ((block.knob[3] + 1) * 0.5)
    local feedback_mix = ((block.input[4] * 0.2) + block.knob[4]) * 0.9

    local freq = MID_C * (2 ^ VOct + tune)
    inc = freq * block.sampletime

    local pd_phase = phase_distortion(phase, distort)
    local output = math.sin(TWO_PI * (pd_phase + feedback * feedback_mix))

    phase = (phase + inc) % 1
    feedback = output * 0.25

    block.output[1] = output * 5
end