// LuaEditor.hpp
#pragma once
#include <rack.hpp>
#include "plugin.hpp"
#include "Lua.hpp" // Include Lua.hpp which has LuaExpander defined

using namespace rack;

struct LuaEditor : Module
{
    enum ParamIds
    {
        NUM_PARAMS
    };
    enum InputIds
    {
        NUM_INPUTS
    };
    enum OutputIds
    {
        NUM_OUTPUTS
    };
    enum LightIds
    {
        NUM_LIGHTS
    };

    Lua *mainModule = nullptr;
    LuaExpander *expander = nullptr;
    std::string editorContent;
    bool dirty = false;

    LuaEditor() { config(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS, NUM_LIGHTS); }

    void process(const ProcessArgs &args) override
    {
        // Check for connected module on the left
        Module *left = leftExpander.module;
        if (left && left->model == modelLua)
        {
            // Connected to Lua module
            if (!mainModule)
            {
                mainModule = reinterpret_cast<Lua *>(left);
                expander = reinterpret_cast<LuaExpander *>(&mainModule->rightExpander);
                if (expander && expander->scriptContent)
                {
                    editorContent = *expander->scriptContent;
                }
            }
        }
        else
        {
            mainModule = nullptr;
            expander = nullptr;
        }
    }

    void saveScript()
    {
        if (expander && expander->scriptContent)
        {
            *expander->scriptContent = editorContent;
            if (expander->reloadScript)
            {
                expander->reloadScript();
            }
            dirty = false;
        }
    }
};