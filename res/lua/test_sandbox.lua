--[[
sandboxtest.lua -- Sandbox environment test
--]]

local unsafe = {
    collectgarbage,
    dofile,
    getfenv,
    getmetatable,
    load,
    loadfile,
    loadstring,
    module,
    rawequal,
    rawget,
    rawset,
    require,
    setfenv,
    ffi,
    io,
    os,
    package,
    debug,
    _G,
    true
}

print("Checking unsafe functions and modules")
for i = 1, #unsafe - 1 do
    print(unsafe[i])
end

local tables = {
    math,
    string,
    table,
    bit,
    true
}

print("Checking allowed function tables")
for i = 1, #tables - 1 do
    print(tables[i])
end

local safe = {
    pairs,
    ipairs, 
    unpack,
    next, 
    type, 
    tostring, 
    tonumber, 
    setmetatable, 
    assert, 
    pcall, 
    xpcall, 
    error,
    true
}

print("Checking allowed functions")
for i = 1, #safe - 1 do
    print(safe[i])
end

function process() end