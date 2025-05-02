// LuaBox.cpp

#include "plugin.hpp"
// #include <lua.hpp>
#include <array>

extern "C"
{
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
}

using namespace rack;

#define NUM_ROWS 8
#define NUM_COLOR 3

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
    std::string errorMessage = "";

    dsp::BooleanTrigger reloadTrigger;
    dsp::BooleanTrigger runTrigger;
    dsp::BooleanTrigger buttonTrigger[8];

    LuaBox()
    {
        config(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS, NUM_LIGHTS);
        configButton(RELOAD_PARAM, "Reload script");
        configButton(RUN_PARAM, "Toggle engine");
        configLight(OK_LIGHT, "Lua status");
        for (int i = 0; i < NUM_ROWS; i++)
        {
            configInput(i, string::f("Lua %d", i + 1));
            configParam(LUA_KNOBS + i, -1.f, 1.f, 0.f, string::f("Knob %d", i + 1));
            configButton(LUA_BUTTONS + i, string::f("Button %d", i + 1));
            configOutput(i, string::f("Lua %d", i + 1));
        }
        onReset();
    }

    ~LuaBox()
    {
        if (L)
            unloadScript();
    }

    // Custom print that outputs to log.txt
    static int lua_sandboxPrint(lua_State *L)
    {
        int n = std::min(lua_gettop(L), 10);
        for (int i = 1; i <= n; i++)
        {
            if (lua_isstring(L, i) || lua_isnumber(L, i))
                DEBUG(lua_tostring(L, i));
            else if (lua_isboolean(L, i))
                DEBUG(lua_toboolean(L, i) ? "true" : "false");
            else if (lua_istable(L, i))
                DEBUG("table");
            else if (lua_isfunction(L, i))
                DEBUG("function");
            else if (lua_isnil(L, i))
                DEBUG("nil");
            else
                DEBUG("Lua error: print() only accepts strings, numbers, booleans or nil!");
        }
        return 0;
    }

    bool createLuaState()
    {
        if (!(L = luaL_newstate()))
        {
            setStatus(STATUS_ERROR, "Lua error: Failed to initialize Lua state");
            return false;
        }

        // Push and call each library loader for the required libraries in the global environment
        // clang-format off
        const std::initializer_list<luaL_Reg> lib_load = {
            {"", luaopen_base},
            {LUA_LOADLIBNAME, luaopen_package},
            {LUA_TABLIBNAME, luaopen_table},
            {LUA_STRLIBNAME, luaopen_string},
            {LUA_MATHLIBNAME, luaopen_math},
            {LUA_BITLIBNAME, luaopen_bit},
            {LUA_JITLIBNAME, luaopen_jit},
            {LUA_OSLIBNAME, luaopen_os},
            {LUA_FFILIBNAME, luaopen_ffi}
        };
        // clang-format on
        for (const auto &lib : lib_load)
        {
            lua_pushcfunction(L, lib.func);
            lua_pushstring(L, lib.name);
            lua_call(L, 1, 0);
        }

        // Create empty sandbox table
        lua_newtable(L);

        // Add custom functions to the sandbox environment
        lua_pushcfunction(L, lua_sandboxPrint);
        lua_setfield(L, -2, "print");

        // Save `time()` before disabling `os` so that it can be used for `math.randomseed()`
        lua_getglobal(L, "os");
        lua_getfield(L, -1, "time");
        lua_setfield(L, -3, "time");
        lua_pop(L, 1); // Pop os

        // Add allowed standard library tables to the sandbox
        static constexpr std::array<const char *, 4> allowedLibs = {"math", "string", "table", "bit"};
        for (const auto &table : allowedLibs)
        {
            lua_getglobal(L, table);
            if (!lua_istable(L, -1))
            {
                lua_pop(L, 1); // Pop nil
                WARN("Lua error: Not a function table: %s", table);
                continue;
            }
            lua_setfield(L, -2, table);
        }

        // Add allowed functions to the sandbox
        static constexpr std::array<const char *, 12> allowedFuncs = {"pairs",    "ipairs",       "unpack", "next",  "type",   "tostring",
                                                                      "tonumber", "setmetatable", "assert", "pcall", "xpcall", "error"};
        for (const auto &func : allowedFuncs)
        {
            lua_getglobal(L, func);
            if (lua_isnil(L, -1))
            {
                lua_pop(L, 1); // Pop nil
                WARN("Lua function not found: %s", func);
                continue;
            }
            lua_setfield(L, -2, func);
        }

        // Load the utility library
        std::string libPath = asset::plugin(pluginInstance, "res/lua/util.lua");
        if (luaL_dofile(L, libPath.c_str()))
        {

            setStatus(STATUS_ERROR, std::string("Lua error loading utility library:\n") + lua_tostring(L, -1));
            lua_pop(L, 1); // Pop error
            return false;
        }

        // Store the sandbox table globally as _SANDBOX for later use
        lua_pushvalue(L, -1);
        lua_setglobal(L, "_SANDBOX");

        // Load FFI setup script
        std::string ffiPath = asset::plugin(pluginInstance, "res/lua/ffi.lua");
        if (luaL_dofile(L, ffiPath.c_str()))
        {
            setStatus(STATUS_ERROR, std::string("Lua error loading FFI script:\n") + lua_tostring(L, -1));
            lua_pop(L, 1); // Pop error
            return false;
        }

        // Disable unsafe functions and modules in the global environment for added safety
        // clang-format off
        const std::initializer_list<const char *> unsafeFuncs = {
            "collectgarbage", "dofile", "getfenv", "getmetatable", "load", "loadfile", "loadstring", "module",
            "rawequal", "rawget", "rawset", "require", "setfenv", "ffi", "io", "os", "package", "debug", "_G"
        };
        // clang-format on
        lua_getglobal(L, "_G");
        for (const auto &func : unsafeFuncs)
        {
            lua_pushnil(L);
            lua_setfield(L, -2, func);
        }
        lua_pop(L, 2); // Pop _G (or nil) and sandbox table

        return true;
    }

    void loadScript()
    {
        INFO("Loading Lua script %s", scriptPath.c_str());

        if (scriptPath.empty())
            return;

        unloadScript();

        if (!createLuaState())
            return;

        // Initialize the Lua block parameters with engine values
        luaBlock.frame = APP->engine->getFrame();
        luaBlock.samplerate = APP->engine->getSampleRate();
        luaBlock.sampletime = APP->engine->getSampleTime();
        luaBlock.channels = NUM_ROWS;

        // Initialize inputs and outputs
        for (int i = 0; i < NUM_ROWS; i++)
        {
            if (inputs[LUA_INPUTS + i].isConnected())
                luaBlock.input[i] = inputs[LUA_INPUTS + i].getVoltage();
            else
                luaBlock.input[i] = 0.f;

            for (int c = 0; c < 3; c++)
                luaBlock.light[i][c] = 0.f;

            luaBlock.knob[i] = params[LUA_KNOBS + i].getValue();
            luaBlock.button[i] = false;
            luaBlock.output[i] = 0.f;
        }

        // Retrieve the sandbox environment table and get its index
        lua_getglobal(L, "_SANDBOX");
        int sandbox_idx = lua_gettop(L);

        // Create the Lua block object by casting the C struct into Lua cdata
        lua_getglobal(L, "_castBlock");
        lua_pushlightuserdata(L, (void *)&luaBlock);
        if (lua_pcall(L, 1, 1, 0))
        {
            setStatus(STATUS_ERROR, std::string("Lua error: Could not cast block:\n") + lua_tostring(L, -1));
            lua_pop(L, 2); // Pop error and sandbox
            return;
        }
        lua_setfield(L, sandbox_idx, "block"); // sandbox.block = block_cdata

        // Load script
        if (luaL_loadfile(L, scriptPath.c_str()))
        {
            setStatus(STATUS_ERROR, std::string("Lua script error:\n") + lua_tostring(L, -1));
            lua_pop(L, 2); // Pop error and sandbox
            return;
        }

        // Set the sandbox environment table for the loaded Lua script
        lua_pushvalue(L, sandbox_idx);
        if (!lua_setfenv(L, -2))
        {
            setStatus(STATUS_ERROR, "Lua error:\nFailed to set function environment");
            lua_pop(L, 2); // Pop function and sandbox
            return;
        }

        // Execute script
        if (lua_pcall(L, 0, 0, 0))
        {
            setStatus(STATUS_ERROR, std::string("Lua script error:\n") + lua_tostring(L, -1));
            lua_pop(L, 2); // Pop error and sandbox
            return;
        }

        // Get and validate process function
        lua_getfield(L, sandbox_idx, "process");
        if (!lua_isfunction(L, -1))
        {
            setStatus(STATUS_ERROR, "Lua script error:\nRequired `process()` function not found");
            lua_pop(L, 2); // Pop nil and sandbox
            return;
        }

        // Save the process function globally for access later
        lua_setglobal(L, "_process");
        lua_pop(L, 1); // Pop sandbox

        scriptLoaded = true;
        scriptRunning = true;
        setStatus(STATUS_OK, "");

        INFO("Lua script %s loaded and `process` function set", scriptPath.c_str());
    }

    void runScript()
    {
        lua_getglobal(L, "_process");
        if (lua_pcall(L, 0, 0, 0))
        {
            setStatus(STATUS_ERROR, std::string("Lua runtime error in `process()` function:\n") + lua_tostring(L, -1));
            lua_pop(L, 1); // Pop error
            unloadScript();
            return;
        }
    }

    void unloadScript()
    {
        scriptLoaded = false;
        if (L)
        {
            lua_close(L);
            L = nullptr;
        }
    }

    void reloadScript()
    {
        if (!scriptPath.empty())
        {
            unloadScript();
            loadScript();
        }
    }

    void newScriptDialog()
    {
        std::string defaultFolder = asset::plugin(pluginInstance, "script");
        std::string defaultFilename = "untitled.lua";
        std::string newPath = openFileDialog(OSDIALOG_SAVE, defaultFolder, defaultFilename, nullptr);

        if (!newPath.empty())
        {
            // Add extension if user didn't specify one
            if (system::getExtension(newPath).empty())
                newPath += ".lua";

            // Copy script template to new file
            std::string templatePath = asset::plugin(pluginInstance, "res/lua/newscript.lua");
            if (copyFile(templatePath, newPath))
            {
                scriptPath = newPath;
                loadScript();
            }
        }
    }

    void loadScriptDialog()
    {
        std::string defaultFolder = asset::plugin(pluginInstance, "script");
        std::string loadPath = openFileDialog(OSDIALOG_OPEN, defaultFolder, "", nullptr);

        if (!loadPath.empty())
        {
            scriptPath = loadPath;
            loadScript();
        }
    }

    void saveScriptDialog()
    {
        if (scriptPath == "")
            return;

        std::string defaultFolder = asset::plugin(pluginInstance, "script");
        std::string defaultFilename = "untitled.lua";

        std::string savePath = openFileDialog(OSDIALOG_SAVE, defaultFolder, defaultFilename, nullptr);

        if (!savePath.empty())
        {
            // Add file extension if user didn't specify one
            if (system::getExtension(savePath).empty())
                savePath += ".lua";

            // Write file then reload it
            if (copyFile(scriptPath, savePath))
            {
                scriptPath = savePath;
                loadScript();
            }
        }
    }

    void setStatus(ScriptStatus scriptStatus, const std::string &message)
    {
        errorMessage = message;

        lights[OK_LIGHT].setBrightness(0.f);
        lights[ERROR_LIGHT].setBrightness(0.f);

        if (scriptStatus == STATUS_ERROR)
        {
            WARN(errorMessage.c_str());
            lights[ERROR_LIGHT].setBrightness(1.f);
            lightInfos[OK_LIGHT]->description = errorMessage;
        }
        else if (scriptStatus == STATUS_OK)
        {
            lights[OK_LIGHT].setBrightness(1.f);
            lightInfos[OK_LIGHT]->description = "Lua OK!";
        }
        else
        {
            lightInfos[OK_LIGHT]->description = "";
        }
    }

    void onReset() override
    {
        scriptPath = "";
        unloadScript();
    }

    void process(const ProcessArgs &args) override
    {
        float reloadLight = 0.f;
        if (reloadTrigger.process(params[RELOAD_PARAM].getValue()))
        {
            reloadLight = 1.f;
            loadScript();
        }
        lights[RELOAD_LIGHT].setBrightnessSmooth(reloadLight, args.sampleTime);

        if (runTrigger.process(params[RUN_PARAM].getValue()))
        {
            if (scriptLoaded)
                scriptRunning = !scriptRunning;
        }
        lights[RUN_LIGHT].setBrightnessSmooth(scriptRunning, args.sampleTime);

        if (!scriptLoaded || !L || !scriptRunning)
            return;

        // Update parameters
        luaBlock.frame = args.frame;
        luaBlock.samplerate = args.sampleRate;
        luaBlock.sampletime = args.sampleTime;

        for (int i = 0; i < NUM_ROWS; i++)
        {
            luaBlock.knob[i] = params[LUA_KNOBS + i].getValue();
            luaBlock.input[i] = inputs[LUA_INPUTS + i].getVoltage();

            bool press = params[LUA_BUTTONS + i].getValue() > 0.f;
            luaBlock.button[i] = press;
            lights[LUA_BUTTONLIGHTS + i].setBrightness(press);
        }

        // Run the Lua script's process() function
        runScript();

        // Set outputs
        for (int i = 0; i < NUM_ROWS; i++)
        {
            outputs[LUA_OUTPUTS + i].setVoltage(luaBlock.output[i]);

            for (int c = 0; c < 3; c++)
                lights[LUA_LIGHTS + (i * 3) + c].setBrightness(luaBlock.light[i][c]);
        }
    }
}; // LuaBox

struct LuaBoxWidget : ModuleWidget
{
    struct FileDisplay : TransparentWidget
    {
        LuaBox *module;
        std::shared_ptr<Font> font;
        void draw(const DrawArgs &args) override
        {
            nvgSave(args.vg);
            std::string text;
            if (module)
            {
                if (!module->scriptPath.empty())
                    text = system::getFilename(module->scriptPath);
                else
                    text = "No script";
            }

            // std::shared_ptr<Font> font = APP->window->loadFont(asset::plugin(pluginInstance, "res/ShareTechMono-Regular.ttf"));

            // nvgFontFaceId(args.vg, font->handle);
            // nvgFontSize(args.vg, 12);
            // nvgTextLetterSpacing(args.vg, 0);
            nvgFillColor(args.vg, nvgRGBA(215, 225, 240, 0xff));
            nvgTextBox(args.vg, 5.f, 20.f, 400.f, text.c_str(), NULL);
            nvgRestore(args.vg);
        }
    };

    LuaBoxWidget(LuaBox *module)
    {
        setModule(module);
        setPanel(createPanel(asset::plugin(pluginInstance, "res/Lua.svg")));

        // Screws
        addChild(createWidget<ScrewBlack>(Vec(RACK_GRID_WIDTH, 0.f)));
        addChild(createWidget<ScrewBlack>(Vec(box.size.x - 2 * RACK_GRID_WIDTH, 0.f)));
        addChild(createWidget<ScrewBlack>(Vec(RACK_GRID_WIDTH, RACK_GRID_HEIGHT - RACK_GRID_WIDTH)));
        addChild(createWidget<ScrewBlack>(Vec(box.size.x - 2 * RACK_GRID_WIDTH, RACK_GRID_HEIGHT - RACK_GRID_WIDTH)));

        // Display
        FileDisplay *fileDisplay = new FileDisplay();
        fileDisplay->box.pos = Vec(0.f, 25.f);
        fileDisplay->box.size = Vec(195.f, 30.f);
        fileDisplay->module = module;
        addChild(fileDisplay);

        float inputX = 24.f, knobX = 62.f, lightX = 98.f, buttonX = 134.f, outputX = 171.f, startY = 130.f, spacing = 30.f;

        // Main buttons
        addParam(createLightParamCentered<LEDLightBezel<>>(Vec(43.f, 90.f), module, LuaBox::RELOAD_PARAM, LuaBox::RELOAD_LIGHT));
        addParam(createLightParamCentered<LEDLightBezel<>>(Vec(152.f, 90.f), module, LuaBox::RUN_PARAM, LuaBox::RUN_LIGHT));

        // Status light
        addChild(createLightCentered<MediumLight<GreenRedLight>>(Vec(lightX, 90.f), module, LuaBox::OK_LIGHT));

        // Loop through inputs, knobs, lights, buttons and outputs
        for (int i = 0; i < NUM_ROWS; i++)
        {
            float rowY = startY + i * spacing;
            addInput(createInputCentered<ThemedPJ301MPort>(Vec(inputX, rowY), module, LuaBox::LUA_INPUTS + i));
            addParam(createParamCentered<Trimpot>(Vec(knobX, rowY), module, LuaBox::LUA_KNOBS + i));
            addChild(createLightCentered<MediumLight<RedGreenBlueLight>>(Vec(lightX, rowY), module, LuaBox::LUA_LIGHTS + 3 * i));
            addParam(createLightParamCentered<LEDLightBezel<>>(Vec(buttonX, rowY), module, LuaBox::LUA_BUTTONS + i,
                                                               LuaBox::LUA_BUTTONLIGHTS + i));
            addOutput(createOutputCentered<ThemedPJ301MPort>(Vec(outputX, rowY), module, LuaBox::LUA_OUTPUTS + i));
        }
    }

    // Helper template for adding to the menu
    template <typename T> T *addMenuItem(Menu *menu, const std::string &label, LuaBox *module)
    {
        T *item = createMenuItem<T>(label);
        item->module = module;
        menu->addChild(item);
        return item;
    }

    void appendContextMenu(Menu *menu) override
    {
        LuaBox *luaBox = dynamic_cast<LuaBox *>(module);
        if (!luaBox)
            return;

        menu->addChild(new MenuSeparator);

        struct MenuItem_Script : MenuItem
        {
            LuaBox *module;
        };

        struct NewScriptItem : MenuItem_Script
        {
            void onAction(const event::Action &e) override { module->newScriptDialog(); }
        };
        addMenuItem<NewScriptItem>(menu, "New script", luaBox);

        struct LoadScriptItem : MenuItem_Script
        {
            void onAction(const event::Action &e) override { module->loadScriptDialog(); }
        };
        addMenuItem<LoadScriptItem>(menu, "Load script", luaBox);

        struct SaveScriptItem : MenuItem_Script
        {
            void onAction(const event::Action &e) override { module->saveScriptDialog(); }
        };
        addMenuItem<SaveScriptItem>(menu, "Save script as", luaBox);

        struct ReloadScriptItem : MenuItem_Script
        {
            void onAction(const event::Action &e) override { module->reloadScript(); }
        };
        addMenuItem<ReloadScriptItem>(menu, "Reload script", luaBox);

        // Show error details if an error message exists
        if (!luaBox->errorMessage.empty())
        {
            menu->addChild(new MenuSeparator);
            struct ShowErrorItem : MenuItem_Script
            {
                void onAction(const event::Action &e) override
                {
                    osdialog_message(OSDIALOG_ERROR, OSDIALOG_OK, module->errorMessage.c_str());
                }
            };
            addMenuItem<ShowErrorItem>(menu, "Show error details", luaBox);
        }
    }
}; // LuaBoxWidget

Model *modelLuaBox = createModel<LuaBox, LuaBoxWidget>("LuaBox");