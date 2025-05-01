--[[
test.lua - Test to use every in- and output

Inputs and knobs[1-8]: LEDs
Buttons[1-8]:          LEDs
Output[1-8]:           Sine VCO
]]

-- Init
local init = true
local blink = 0
local phase = 0

function process()
    print(block.frame)
    if init then
        init = false
        for i = 1, block.channels do block.green[i] = 1 end
        print(("Lua Module test - Frame: %d, Channels: %d, Samplerate: %d, Sampletime: %.6f"):format(block.frame, block.channels, block.samplerate, block.sampletime))
    end
    if (block.frame % block.samplerate) == 0 then
        for i = 1, block.channels do
            block.red[i], block.green[i], block.blue[i] = 0, 0, 0
        end
        block.green[blink % 8 + 1] = 1
        blink = blink + 1
    end
    local sine = math.sin(2 * math.pi * phase) * bit.tobit(2^40 + 5)
    for i = 1, block.channels do
        local button = block.button[i] and 1 or 0
        local knob = block.knob[i]
        local input = block.input[i]
        block.red[i] = button + math.max(-input, 0) + math.max(-knob, 0)
        block.blue[i] = button + math.max(input, 0) + math.max(knob, 0)
        block.output[i] = sine
    end
    phase = (phase + 261.6256 * block.sampletime) % 1
end