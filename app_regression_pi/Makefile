TARGET = XCORE-AI-EXPLORER-700.xn

<<<<<<< HEAD
APP_NAME = app_regression_pi
=======
APP_NAME = app_regression_si
>>>>>>> afc5772e6802e18094824bd98e208b04c294fffa

APP_SHARED_FLAGS  = -report \
			-fcmdline-buffer-bytes=32 \
			-O3 -fcomment-asm -fxscope -mcmodel=large  -Wno-xcore-fptrgroup -save-temps \
			-Wno-unknown-pragmas \
			-Wno-bidirectional-buffered-port \
			-DTF_LITE_STATIC_MEMORY \
			-DXCORE \
			-DPRINT_PROFILER_SUMMARY \
			-lquadflash \
			-DENABLE_USB -DXUD_CORE_CLOCK=700 -DTF_LITE_STRIP_ERROR_STRINGS
			SOURCE_DIRS = src

# The USED_MODULES variable lists other module used by the application. 
USED_MODULES = lib_aisrv lib_xud lib_tflite_micro

XCC_FLAGS = $(APP_SHARED_FLAGS) -DI2C_INTEGRATION=1 -DUSB_TILE=tile[0]
XCC_CPP_FLAGS = $(APP_SHARED_FLAGS) -std=c++11 -DI2C_INTEGRATION=1 
XCC_ASM_FLAGS = $(APP_SHARED_FLAGS) -DUSE_DDR_FIX=1

#=============================================================================
# The following part of the Makefile includes the common build infrastructure
# for compiling XMOS applications. You should not need to edit below here.

XMOS_MAKE_PATH ?= ../..
include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common

