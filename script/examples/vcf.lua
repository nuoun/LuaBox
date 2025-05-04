--[[
vcf.lua - Voltage Controlled Filter (3 types of cascaded biquads plus a single stage all-pass filter)
Based on "Cookbook formulae for audio EQ biquad filter coefficients" by Robert Bristow-Johnso
https://webaudio.github.io/Audio-EQ-Cookbook/Audio-EQ-Cookbook.txt

Inputs
    Input 1: Signal in
    Input 2: Cutoff frequency 
    Input 3: Q factor
Knobs
    Knob 1: Input gain (-6 to 6  dB)
    Knob 2: Cutoff frequency (V/Oct)
    Knob 3: Q factor

Output 1: Signal out

Buttons - Type select:
    1. Low-pass filter  
    2. High-pass filter
    3. Band-pass filter
    4. All-pass filter
]]

local samplerate = block.samplerate
local state1 = {x1 = 0, x2 = 0, y1 = 0, y2 = 0}
local state2 = {x1 = 0, x2 = 0, y1 = 0, y2 = 0}
local MID_C = 261.6256
local type = 1
local min_dB, max_dB = -6, 6

local function lpf(input, state, cutoff, Q)
    local w0 = 2 * math.pi * cutoff / samplerate
    local alpha = math.sin(w0) / (2 * Q)
    local b0 = (1 - math.cos(w0)) / 2
    local b1 = 1 - math.cos(w0)
    local b2 = (1 - math.cos(w0)) / 2
    local a0 = 1 + alpha
    local a1 = -2 * math.cos(w0)
    local a2 = 1 - alpha

    -- Normalize coefficients
    b0 = b0 / a0
    b1 = b1 / a0
    b2 = b2 / a0
    a1 = a1 / a0
    a2 = a2 / a0

    local output = b0 * input + b1 * state.x1 + b2 * state.x2 - a1 * state.y1 - a2 * state.y2
    
    state.x2, state.x1 = state.x1, input
    state.y2, state.y1 = state.y1, output

    return output
end

local function hpf(input, state, cutoff, Q)
    local w0 = 2 * math.pi * cutoff / samplerate
    local alpha = math.sin(w0) / (2 * Q)
    local cos_w0 = math.cos(w0)

    local b0 =  (1 + cos_w0) / 2
    local b1 = -(1 + cos_w0)
    local b2 =  (1 + cos_w0) / 2
    local a0 =   1 + alpha
    local a1 =  -2 * cos_w0
    local a2 =   1 - alpha

    -- Normalize coefficients
    b0 = b0 / a0
    b1 = b1 / a0
    b2 = b2 / a0
    a1 = a1 / a0
    a2 = a2 / a0

    local output = b0 * input + b1 * state.x1 + b2 * state.x2 - a1 * state.y1 - a2 * state.y2

    state.x2, state.x1 = state.x1, input
    state.y2, state.y1 = state.y1, output

    return output
end

local function bpf(input, state, cutoff, Q)
    local w0 = 2 * math.pi * cutoff / samplerate
    local alpha = math.sin(w0) / (2 * Q)
    local sin_w0 = math.sin(w0)
    local cos_w0 = math.cos(w0)

    local b0 = sin_w0 / 2
    local b1 = 0
    local b2 = -sin_w0 / 2
    local a0 = 1 + alpha
    local a1 = -2 * cos_w0
    local a2 = 1 - alpha

    -- Normalize coefficients
    b0 = b0 / a0
    b1 = b1 / a0
    b2 = b2 / a0
    a1 = a1 / a0
    a2 = a2 / a0

    local output = b0 * input + b1 * state.x1 + b2 * state.x2 - a1 * state.y1 - a2 * state.y2

    state.x2, state.x1 = state.x1, input
    state.y2, state.y1 = state.y1, output

    return output
end

local function apf(input, state, cutoff, Q)

    local w0 = 2 * math.pi * cutoff / samplerate
    local alpha = math.sin(w0) / (2 * Q)
    local cos_w0 = math.cos(w0)

    local b0 = 1 - alpha
    local b1 = -2 * cos_w0
    local b2 = 1 + alpha
    local a0 = 1 + alpha
    local a1 = -2 * cos_w0
    local a2 = 1 - alpha

    -- Normalize coefficients
    b0 = b0 / a0
    b1 = b1 / a0
    b2 = b2 / a0
    a1 = a1 / a0
    a2 = a2 / a0

    local output = b0 * input + b1 * state.x1 + b2 * state.x2 - a1 * state.y1 - a2 * state.y2

    state.x2, state.x1 = state.x1, input
    state.y2, state.y1 = state.y1, output

    return output
end

function process()
    -- Type select button
    for i = 1, block.channels do
        if block.button[i] then 
            type = i
            for j = 1, block.channels do block.blue[j] = 0 end
            break;
        end
    end
    block.blue[type] = 1

    -- Signal in and gain
    local dB = ((block.knob[1] + 1) / 2) * (max_dB - min_dB) + min_dB
    local gain = 10 ^ (dB / 20)
    local input = block.input[1] * gain

    -- Read control parameters
    local VOct = block.input[2] + (block.knob[2] * 5) + 1
    local cutoff = MID_C * (2 ^ VOct)
    -- Limit cutoff to between 10Hz and Nyquist
    cutoff = math.max(10, math.min(cutoff, samplerate/2 - 1))

    local Q = block.input[3] + (block.knob[3] * 10) -- resonance or Q from knob[2]
    -- Limit Q to [0.01 .. 10]
    Q = math.max(0.01, math.min(Q, 10))

    local output
    if type == 1 then -- LPF
        Q = math.sqrt(Q) -- Adjust Q for cascaded stages
        local stage = lpf(input, state1, cutoff, Q)
        output = lpf(stage, state2, cutoff, Q)
    elseif type == 2 then -- HPF
        Q = math.sqrt(Q) -- Adjust Q for cascaded stages
        local stage = hpf(input, state1, cutoff, Q)
        output = hpf(stage, state2, cutoff, Q)
    elseif type == 3 then -- BPF
        Q = math.sqrt(Q) -- Adjust Q for cascaded stages
        local stage = bpf(input, state1, cutoff, Q)
        output = bpf(stage, state2, cutoff, Q)
    else -- APF
        output = apf(input, state2, cutoff, Q)
    end
    block.output[1] = output
end