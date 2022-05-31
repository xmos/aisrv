TARGET = XCORE-AI-EXPLORER-700.xn
APP_NAME = app_lib_vision_test
APP_SHARED_FLAGS  = -report \
-O3 -fcomment-asm -fxscope -mcmodel=large  -Wno-xcore-fptrgroup -save-temps \
-Wno-unknown-pragmas \
-Wno-bidirectional-buffered-port \
-g \
-DENABLE_USB -DXUD_CORE_CLOCK=700
SOURCE_DIRS = src
USED_MODULES = lib_xud 

XCC_FLAGS = $(APP_SHARED_FLAGS) -DUSB_TILE=tile[0]
XCC_CPP_FLAGS = $(APP_SHARED_FLAGS) -std=c++11
XCC_ASM_FLAGS = $(APP_SHARED_FLAGS)
#=============================================================================
# The following part of the Makefile includes the common build infrastructure
# for compiling XMOS applications. You should not need to edit below here.

XMOS_MAKE_PATH ?= ../..
include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common

