# If RACK_DIR is not defined when calling the Makefile, default to two directories above
RACK_DIR ?= ../..

include $(RACK_DIR)/arch.mk

ifdef ARCH_MAC
	export MACOSX_DEPLOYMENT_TARGET=10.7
endif

# Detect MSYS2 environment
ifdef MSYSTEM
	MSYS2_BUILD := 1
endif

# LuaJIT build configuration
LUAJIT_DIR := lib/LuaJIT
LUAJIT_SRC := $(LUAJIT_DIR)/src
LUAJIT_LIB := $(LUAJIT_SRC)/libluajit.a
FLAGS += -I$(LUAJIT_SRC)
LDFLAGS += $(LUAJIT_LIB)

# Source files
SOURCES += $(wildcard src/*.cpp)

# Distributable files
DISTRIBUTABLES += res script
DISTRIBUTABLES += $(wildcard LICENSE*)

# Dependencies
DEPS += $(LUAJIT_LIB)

# Build LuaJIT
ifdef MSYSTEM
	LUAJIT_BUILD_CMD = cd $(LUAJIT_DIR) && $(MAKE) BUILDMODE=static
else ifdef ARCH_WIN
	LUAJIT_BUILD_CMD = cd $(LUAJIT_DIR) && $(MAKE) BUILDMODE=static TARGET_SYS=Windows CROSS=x86_64-w64-mingw32- TARGET_FLAGS="-DLUAJIT_OS=LUAJIT_OS_WINDOWS" 
else
	LUAJIT_BUILD_CMD = cd $(LUAJIT_DIR) && $(MAKE) BUILDMODE=static
endif

$(LUAJIT_LIB):
	$(LUAJIT_BUILD_CMD)

# Hook into default dependency rule to build LuaJIT first
dep: $(LUAJIT_LIB)

clean-luajit:
	$(MAKE) -C $(LUAJIT_DIR) clean

# clean: clean-luajit

# Include the VCV Rack plugin Makefile framework
include $(RACK_DIR)/plugin.mk