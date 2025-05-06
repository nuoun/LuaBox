// LuaBox.hpp

#pragma once

#include "plugin.hpp"
#include "lua.hpp"
#include <array>
#include <string>
#include <fstream>  // For std::ifstream
#include <iterator> // For std::istreambuf_iterator

using namespace rack;

#define NUM_ROWS 8
#define NUM_COLOR 3

extern Model *modelLuaBox;

struct LuaBox : Module
{
    enum ParamIds
    {
        ENUMS(LUA_KNOBS, NUM_ROWS),
        ENUMS(LUA_BUTTONS, NUM_ROWS),
        RELOAD_PARAM,
        RUN_PARAM,
        NUM_PARAMS
    };

    enum InputIds
    {
        ENUMS(LUA_INPUTS, NUM_ROWS),
        NUM_INPUTS
    };

    enum OutputIds
    {
        ENUMS(LUA_OUTPUTS, NUM_ROWS),
        NUM_OUTPUTS
    };

    enum LightIds
    {
        OK_LIGHT,
        ERROR_LIGHT,
        ENUMS(LUA_LIGHTS, NUM_ROWS * 3),
        ENUMS(LUA_BUTTONLIGHTS, NUM_ROWS),
        RELOAD_LIGHT,
        RUN_LIGHT,
        NUM_LIGHTS
    };

    struct LuaProcessBlock
    {
        int64_t frame;
        float samplerate;
        float sampletime;
        int channels;
        float input[NUM_ROWS];
        float knob[NUM_ROWS];
        float light[NUM_ROWS][NUM_COLOR];
        bool button[NUM_ROWS];
        float output[NUM_ROWS];
    };

    enum ScriptStatus
    {
        STATUS_NONE,
        STATUS_OK,
        STATUS_ERROR
    };

    lua_State *L = nullptr;
    LuaProcessBlock luaBlock;

    bool scriptLoaded = false;
    bool scriptRunning = false;

    std::string scriptPath = "";
    std::string scriptString = "";
    std::string errorMessage = "";

    dsp::BooleanTrigger reloadTrigger;
    dsp::BooleanTrigger runTrigger;
    dsp::BooleanTrigger buttonTrigger[8];

    LuaBox();
    ~LuaBox();

    // Script management methods
    void loadScript();
    void unloadScript();
    void reloadScript();
    void loadString();
    void runScript();
    bool createLuaState();
    static int lua_sandboxPrint(lua_State *L);

    // File dialog methods
    void newScriptDialog();
    void loadScriptDialog();
    void saveScriptDialog();

    // Status management
    void setStatus(ScriptStatus scriptStatus, const std::string &message);

    // Module methods
    void onReset() override;
    void process(const ProcessArgs &args) override;
}; // LuaBox