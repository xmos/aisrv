# The TARGET variable determines what target system the application is 
# compiled for. It either refers to an XN file in the source directories
# or a valid argument for the --target option when compiling.

# In this case, the target depends on the build configuration.
TARGET = XCORE-AI-EXPLORER-800.xn

# The APP_NAME variable determines the name of the final .xe file. It should
# not include the .xe postfix. If left blank the name will default to 
# the project name
APP_NAME = app_aisrv

# The flags passed to xcc when building the application
# You can also set the following to override flags for a particular language:
#
#    XCC_XC_FLAGS, XCC_C_FLAGS, XCC_ASM_FLAGS, XCC_CPP_FLAGS
#
# If the variable XCC_MAP_FLAGS is set it overrides the flags passed to 
# xcc for the final link (mapping) stage.

SHARED_FLAGS  = -report \
-O3 -fcomment-asm -fxscope -mcmodel=large  -Wno-xcore-fptrgroup -save-temps \
-Wno-unknown-pragmas \
-Wno-bidirectional-buffered-port \
-g \
-DTF_LITE_STATIC_MEMORY \
-DXCORE \
-DENABLE_USB 


SOURCE_DIRS = src

# The USED_MODULES variable lists other module used by the application. 
USED_MODULES = lib_i2c lib_xud lib_tensorflow lib_mipi

XCC_FLAGS_usb = $(SHARED_FLAGS) -DUSB_TILE=tile[1] 
XCC_CPP_FLAGS_usb = $(SHARED_FLAGS) -std=c++11 

XCC_FLAGS_usb_mipi = $(SHARED_FLAGS) -DMIPI_INTEGRATION=1 -DI2C_INTEGRATION=1 -DUSB_TILE=tile[0]
XCC_CPP_FLAGS_usb_mipi = $(SHARED_FLAGS) -std=c++11 -DMIPI_INTEGRATION=1 -DI2C_INTEGRATION=1 

#=============================================================================
# The following part of the Makefile includes the common build infrastructure
# for compiling XMOS applications. You should not need to edit below here.

XMOS_MAKE_PATH ?= ../..
include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common

