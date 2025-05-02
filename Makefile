# If running on macOS, set deployment target
ifeq ($(shell uname), Darwin)
	export MACOSX_DEPLOYMENT_TARGET=10.9
endif

# If RACK_DIR is not defined when calling the Makefile, default to two directories above
RACK_DIR ?= ../..

# LuaJIT build
LUAJIT_DIR := lib/luajit
LUAJIT_SRC := $(LUAJIT_DIR)/src
LUAJIT_LIB := $(LUAJIT_SRC)/libluajit.a

FLAGS += -I$(LUAJIT_SRC)
LDFLAGS += $(LUAJIT_LIB)

DEPS += $(LUAJIT_LIB)
OBJECTS += $(LUAJIT_LIB)

SOURCES += $(wildcard src/*.cpp)

DISTRIBUTABLES += res script
DISTRIBUTABLES += $(wildcard LICENSE*)

# Build LuaJIT
$(LUAJIT_LIB):
	cd $(LUAJIT_DIR) && $(MAKE) BUILDMODE=static

# Hook into default target to ensure LuaJIT builds
dep: $(LUAJIT_BUILD)

clean-luajit:
	$(RM) $(LUAJIT_OBJ) $(LUAJIT_BUILD)
	$(MAKE) -C $(LUAJIT_DIR) clean

# clean: clean-luajit

# Include the VCV Rack plugin Makefile framework
include $(RACK_DIR)/plugin.mk