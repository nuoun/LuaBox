#include "plugin.hpp"
#include "LuaBox.hpp"

struct LuaBoxEditor : Module
{
    enum ParamId
    {
        PARAMS_LEN
    };
    enum InputId
    {
        INPUTS_LEN
    };
    enum OutputId
    {
        OUTPUTS_LEN
    };
    enum LightId
    {
        LIGHTS_LEN
    };

    LuaBox *luabox = nullptr;

    LuaBoxEditor() { config(PARAMS_LEN, INPUTS_LEN, OUTPUTS_LEN, LIGHTS_LEN); }

    void process(const ProcessArgs &args) override
    {
        // Check for connected LuaBox module
        if (leftExpander.module && leftExpander.module->model == modelLuaBox)
        {
            if (!luabox)
            {
                luabox = reinterpret_cast<LuaBox *>(leftExpander.module);
            }
        }
        else
        {
            luabox = nullptr;
        }
    }
}; // LuaBoxEditor

struct LuaBoxEditorWidget : ModuleWidget
{
    struct ScriptEditor : ui::TextField
    {
        LuaBoxEditor *module;

        ScriptEditor()
        {
            // box.pos = Vec(0.f, 0.f); // Position relative to the container
            multiline = true;
        }

        void step() override
        {
            // Update text from the connected LuaBox module
            if (module && module->luabox && !module->luabox->scriptPath.empty())
                text = module->luabox->scriptString;

            NVGcontext *vg = APP->window->vg;

            if (vg)
            {
                auto font = APP->window->uiFont;
                auto fontSize = 13.0f;

                nvgFontSize(vg, fontSize);
                nvgFontFaceId(vg, font->handle);

                // Calculate height based on line count
                int numLines = std::count(text.begin(), text.end(), '\n') + 1;
                float lineHeight = fontSize * 1.f;
                float height = lineHeight * numLines;

                // Calculate maximum line width
                float maxWidth = 0.f;
                std::istringstream stream(text);
                std::string line;
                while (std::getline(stream, line))
                {
                    float bounds[4];
                    nvgTextBounds(vg, 0.f, 0.f, line.c_str(), NULL, bounds);
                    float lineWidth = bounds[2] - bounds[0];
                    if (lineWidth > maxWidth)
                        maxWidth = lineWidth;
                }

                float padding = 25.f;
                float minWidth = 370.f;
                float minHeight = 335.f;

                // Set box size with minimum dimensions
                float newWidth = std::max(maxWidth + padding, minWidth);
                float newHeight = std::max(height + padding, minHeight);
                box.size = Vec(newWidth, newHeight);
            }

            ui::TextField::step();
        }

        void draw(const DrawArgs &args) override
        {
            nvgScissor(args.vg, RECT_ARGS(args.clipBox));

            BNDwidgetState state;
            if (this == APP->event->selectedWidget)
                state = BND_ACTIVE;
            else if (this == APP->event->hoveredWidget)
                state = BND_HOVER;
            else
                state = BND_DEFAULT;

            int begin = std::min(cursor, selection);
            int end = std::max(cursor, selection);

            std::string drawText;
            drawText = text;

            // Draw text field
            bndTextField(args.vg, 0.0, 0.0, box.size.x, box.size.y, BND_CORNER_ALL, state, -1, text.c_str(), begin, end);

            nvgResetScissor(args.vg);
        }

        void onChange(const ChangeEvent &e) override
        {
            if (module && module->luabox)
            {
                module->luabox->scriptString = text;
            }
        }
    }; // ScriptEditor

    struct ScriptEditorContainer : ui::ScrollWidget
    {
        LuaBoxEditor *module;
        ScriptEditor *editor;

        ScriptEditorContainer()
        {
            box.size = Vec(370.f, 335.f);
            box.pos = Vec(10.f, 25.f);

            editor = new ScriptEditor();
            container->addChild(editor);

            // Set initial container box size
            containerBox = editor->box;
        }

        void step() override
        {
            if (editor)
            {
                editor->module = module;
            }

            // Update container box to match editor size
            containerBox = editor->box;

            ui::ScrollWidget::step();
        }
    }; // ScriptEditorContainer

    LuaBoxEditorWidget(LuaBoxEditor *module)
    {
        setModule(module);
        setPanel(createPanel(asset::plugin(pluginInstance, "res/LuaBoxEditor.svg")));

        // Screws
        addChild(createWidget<ScrewBlack>(Vec(RACK_GRID_WIDTH, 0.f)));
        addChild(createWidget<ScrewBlack>(Vec(box.size.x - 2 * RACK_GRID_WIDTH, 0.f)));
        addChild(createWidget<ScrewBlack>(Vec(RACK_GRID_WIDTH, RACK_GRID_HEIGHT - RACK_GRID_WIDTH)));
        addChild(createWidget<ScrewBlack>(Vec(box.size.x - 2 * RACK_GRID_WIDTH, RACK_GRID_HEIGHT - RACK_GRID_WIDTH)));

        // Add script editor
        ScriptEditorContainer *scriptContainer = new ScriptEditorContainer();
        scriptContainer->module = module;
        scriptContainer->editor->multiline = true;
        addChild(scriptContainer);
    }
};

Model *modelLuaBoxEditor = createModel<LuaBoxEditor, LuaBoxEditorWidget>("LuaBoxEditor");