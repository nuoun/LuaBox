--[[
template.lua - New file template

Parameters
    block.samplerate:  Sample rate in Hz (Fs)
    block.sampletime:  Time per sample in seconds (1 / Fs)
    block.channels:    Number of input and output channels: 8
    block.frame:       Number of sample frames since engine started
Inputs and controls
    block.input[1-8]:  Input ports
    block.knob[1-8]:   Knob values (ranges from -1 to 1)
    block.button[1-8]: Button states (true or false)
Outputs
    block.output[1-8]: Output ports
    block.red[1-8]:    Red LED values (ranges from 0 to 1)
    block.green[1-8]:  Green LED values (ranges from 0 to 1)
    block.blue[1-8]:   Blue LED values (ranges from 0 to 1)
]]



function process()



end