// plugin.hpp

#pragma once
#include <rack.hpp>
#include <array>
#include "util.hpp"

using namespace rack;

// Declare the Plugin, defined in plugin.cpp
extern Plugin *pluginInstance;

// Declare each Model, defined in each module source file
extern Model *modelLuaBox;
// extern Model *modelLuaEditor;