cmake_minimum_required(VERSION 3.14)

#**********************
# Setup XMOS toolchain
#**********************

set(XMOS_TOOLS_PATH "$ENV{XMOS_TOOL_PATH}/bin")
include("$ENV{XMOS_AISRV_PATH}/tools/cmake_utils/xmos_toolchain.cmake")

#**********************
# Project
#**********************

# Disable in-source build.
if("${CMAKE_SOURCE_DIR}" STREQUAL "${CMAKE_BINARY_DIR}")
    message(FATAL_ERROR "In-source build is not allowed! Please specify a build folder.\n\tex:cmake -B build")
endif()

project(aisrv_spi VERSION 1.0.0)

enable_language(CXX C ASM)

#**********************
# Paths
#**********************

set(AI_TOOLS_DIR "$ENV{XMOS_AISRV_PATH}/submodules/ai_tools")

set(LIB_XUD_DIR "$ENV{XMOS_LIB_XUD_PATH}")
set(LIB_I2C_DIR "$ENV{XMOS_LIB_I2C_PATH}")
set(LIB_XASSERT_DIR "$ENV{XMOS_LIB_XASSERT_PATH}")
set(LIB_MIPI_DIR "$ENV{XMOS_LIB_MIPI_PATH}")

set(LIB_XUD_SRC_DIR "${LIB_XUD_DIR}/lib_xud/src/")
set(LIB_I2C_SRC_DIR "${LIB_I2C_DIR}/lib_i2c/src/")
set(LIB_XASSERT_SRC_DIR "${LIB_XASSERT_DIR}/lib_xassert/src/")
set(LIB_MIPI_SRC_DIR "${LIB_MIPI_DIR}/lib_mipi/src/")

#**********************
# Build flags
#**********************

#add_executable(aisrv_usb_spi)
add_executable(aisrv_usb)

# Optimization
# -DNDEBUG                        # define this to remove debug and profiling
# -DTF_LITE_STRIP_ERROR_STRINGS   # define this to remove logging

set(BUILD_FLAGS
  "${PROJECT_SOURCE_DIR}/src/XCORE-AI-EXPLORER-800.xn"
  "-fxscope"
  "${CMAKE_CURRENT_SOURCE_DIR}/config.xscope"
  "-mcmodel=large"
  "-Wno-xcore-fptrgroup"
  "-Wno-unknown-pragmas"
  "-Wno-bidirectional-buffered-port"
  "-report"
  "-DTF_LITE_STATIC_MEMORY"
  "-DXCORE"
  "-DUSE_EXTMEM"
  "-g"
  "-O2"
  "-DENABLE_USB"
  "-DUSB_TILE=tile[0]"
  "-DMIPI_INTEGRATION"
  "-DI2C_INTEGRATION"
)

#target_compile_options(aisrv_usb_spi PRIVATE ${BUILD_FLAGS} -DPSOC_INTEGRATION)
#target_link_options(aisrv_usb_spi PRIVATE ${BUILD_FLAGS} -lquadspi -w)
#set_target_properties(aisrv_usb_spi PROPERTIES OUTPUT_NAME aisrv_usb_spi.xe)

target_compile_options(aisrv_usb PRIVATE ${BUILD_FLAGS})
target_link_options(aisrv_usb PRIVATE ${BUILD_FLAGS} -lquadspi -w)
set_target_properties(aisrv_usb PROPERTIES OUTPUT_NAME aisrv_usb.xe)

#***
#lib_xud sources
#***
set(LIB_XUD_SOURCES
    "${LIB_XUD_SRC_DIR}/core/XUD_Main.xc"
    "${LIB_XUD_SRC_DIR}/core/XUD_HAL.xc"
    "${LIB_XUD_SRC_DIR}/core/XUD_IoLoop.S"
    "${LIB_XUD_SRC_DIR}/core/XUD_IOLoopCall.xc"
    "${LIB_XUD_SRC_DIR}/core/XUD_PowerSig.xc"
    "${LIB_XUD_SRC_DIR}/core/XUD_User.xc"
    "${LIB_XUD_SRC_DIR}/core/XUD_TestMode.xc"
    "${LIB_XUD_SRC_DIR}/core/XUD_TestMode.S"
    "${LIB_XUD_SRC_DIR}/core/XUD_UserResume.xc"
    "${LIB_XUD_SRC_DIR}/core/XUD_DeviceAttach.xc"
    "${LIB_XUD_SRC_DIR}/core/XUD_USBTIle_Support.S"
    "${LIB_XUD_SRC_DIR}/core/XUD_CRC5_Table.S"
    "${LIB_XUD_SRC_DIR}/core/XUD_SetCrcTableAddr.c"
    "${LIB_XUD_SRC_DIR}/user/client/XUD_SetDevAddr.xc"
    "${LIB_XUD_SRC_DIR}/user/client/XUD_EpFunctions.xc"
    "${LIB_XUD_SRC_DIR}/user/client/XUD_EpFuncs.S"
    "${LIB_XUD_SRC_DIR}/user/control/xud_device.xc"
    "${LIB_XUD_SRC_DIR}/user/control/xud_std_requests.xc"
)

set_source_files_properties("${LIB_XUD_SRC_DIR}/core/XUD_Main.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${LIB_XUD_SRC_DIR}/core/XUD_User.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${LIB_XUD_SRC_DIR}/core/XUD_UserResume.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${LIB_XUD_SRC_DIR}/core/XUD_PowerSig.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${LIB_XUD_SRC_DIR}/core/XUD_IOLoopCall.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${LIB_XUD_SRC_DIR}/core/XUD_HAL.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${LIB_XUD_SRC_DIR}/core/XUD_TestMode.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${LIB_XUD_SRC_DIR}/core/XUD_DeviceAttach.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${LIB_XUD_SRC_DIR}/user/client/XUD_SetDevAddr.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${LIB_XUD_SRC_DIR}/user/client/XUD_EpFunctions.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${LIB_XUD_SRC_DIR}/user/control/xud_device.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${LIB_XUD_SRC_DIR}/user/control/xud_std_requests.xc" PROPERTIES LANGUAGE C)

#***
#lib_i2c sources
#***
set(LIB_I2C_SOURCES
    "${LIB_I2C_SRC_DIR}/i2c_master.xc"
)

set_source_files_properties("${LIB_I2C_SRC_DIR}/i2c_master.xc" PROPERTIES LANGUAGE C)

#***
#lib_xassert sources
#***
set(LIB_XASSERT_SOURCES
    "${LIB_XASSERT_SRC_DIR}/xassert.xc"
)

set_source_files_properties("${LIB_XASSERT_SRC_DIR}/xassert.xc" PROPERTIES LANGUAGE C)

#***
#lib_mipi sources
#***
set(LIB_MIPI_SOURCES
    "${LIB_MIPI_SRC_DIR}/MipiReceive.S"
    "${LIB_MIPI_SRC_DIR}/MipiReceive.xc"
    "${LIB_MIPI_SRC_DIR}/debayer.c"
    "${LIB_MIPI_SRC_DIR}/debayer_kernel.S"
)

set_source_files_properties("${LIB_MIPI_SRC_DIR}/MipiReceive.xc" PROPERTIES LANGUAGE C)

#**********************
# LIB sources
#**********************

include("${AI_TOOLS_DIR}/xcore_interpreters/cmake/xcore_interpreter.cmake")

set(INFERENCE_ENGINE_SOURCES
  ${XCORE_INTERPRETER_SOURCES}
  "$ENV{XMOS_AISRV_PATH}/submodules/tensorflow_support/qspi_flash/xcore_device_memory.c"
)

set(INFERENCE_ENGINE_INCLUDE_DIRS
  ${XCORE_INTERPRETER_INCLUDE_DIRS}
  "$ENV{XMOS_AISRV_PATH}/submodules/tensorflow_support/qspi_flash"
)

set(LIB_XUD_INCLUDE_DIRS
    "${LIB_XUD_DIR}/lib_xud/api"
    "${LIB_XUD_SRC_DIR}/core"
    "${LIB_XUD_SRC_DIR}/user"
)

set(LIB_I2C_INCLUDE_DIRS
    "${LIB_I2C_DIR}/lib_i2c/api"
)

set(LIB_XASSERT_INCLUDE_DIRS
    "${LIB_XASSERT_DIR}/lib_xassert/api"
)

set(LIB_MIPI_INCLUDE_DIRS
    "${LIB_MIPI_DIR}/lib_mipi/api"
)

#**********************
# APP sources
#**********************

set(APP_SOURCES
  ${INFERENCE_ENGINE_SOURCES}
  "${PROJECT_SOURCE_DIR}/src/acquire.xc"
  "${PROJECT_SOURCE_DIR}/src/aiengine.xc"
  "${PROJECT_SOURCE_DIR}/src/main.xc"
  "${PROJECT_SOURCE_DIR}/src/spi.xc"
  "${PROJECT_SOURCE_DIR}/src/spibuffer.xc"
  "${PROJECT_SOURCE_DIR}/src/inference_engine.cc"
  "${PROJECT_SOURCE_DIR}/src/aisrv_usb.xc"
  "${PROJECT_SOURCE_DIR}/src/aisrv_mipi.xc"
  "${PROJECT_SOURCE_DIR}/src/imx219.xc"
  "${PROJECT_SOURCE_DIR}/src/haar.xc"
  "${PROJECT_SOURCE_DIR}/src/haar_features.xc"
  "${PROJECT_SOURCE_DIR}/src/haar_single_classifier.S"
  "${PROJECT_SOURCE_DIR}/src/usleep.xc"
  "${PROJECT_SOURCE_DIR}/src/get_time.c"
  "${PROJECT_SOURCE_DIR}/src/leds.xc"
  "${PROJECT_SOURCE_DIR}/src/calls.S"
)

set_source_files_properties("${PROJECT_SOURCE_DIR}/src/main.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${PROJECT_SOURCE_DIR}/src/spibuffer.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${PROJECT_SOURCE_DIR}/src/spi.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${PROJECT_SOURCE_DIR}/src/aiengine.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${PROJECT_SOURCE_DIR}/src/acquire.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${PROJECT_SOURCE_DIR}/src/aisrv_usb.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${PROJECT_SOURCE_DIR}/src/aisrv_mipi.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${PROJECT_SOURCE_DIR}/src/imx219.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${PROJECT_SOURCE_DIR}/src/haar.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${PROJECT_SOURCE_DIR}/src/haar_features.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${PROJECT_SOURCE_DIR}/src/haar_single_classifier.S" PROPERTIES LANGUAGE C)
set_source_files_properties("${PROJECT_SOURCE_DIR}/src/usleep.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${PROJECT_SOURCE_DIR}/src/leds.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${PROJECT_SOURCE_DIR}/src/calls.S" PROPERTIES LANGUAGE C)


#**********************
# targets
#**********************
#target_sources(aisrv_usb_spi
#  PRIVATE ${APP_SOURCES}
#  PRIVATE ${LIB_XUD_SOURCES}
#  PRIVATE ${LIB_I2C_SOURCES}
#  PRIVATE ${LIB_XASSERT_SOURCES}
#  PRIVATE ${LIB_MIPI_SOURCES}
#)

target_sources(aisrv_usb
  PRIVATE ${APP_SOURCES}
  PRIVATE ${LIB_XUD_SOURCES}
  PRIVATE ${LIB_I2C_SOURCES}
  PRIVATE ${LIB_XASSERT_SOURCES}
  PRIVATE ${LIB_MIPI_SOURCES}
)

#target_include_directories(aisrv_usb_spi
#  PRIVATE ${INFERENCE_ENGINE_INCLUDE_DIRS}
#  PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src"
#  PRIVATE ${LIB_XUD_INCLUDE_DIRS}
#  PRIVATE ${LIB_I2C_INCLUDE_DIRS}
#  PRIVATE ${LIB_XASSERT_INCLUDE_DIRS}
#  PRIVATE ${LIB_MIPI_INCLUDE_DIRS}
#)

target_include_directories(aisrv_usb
  PRIVATE ${INFERENCE_ENGINE_INCLUDE_DIRS}
  PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src"
  PRIVATE ${LIB_XUD_INCLUDE_DIRS}
  PRIVATE ${LIB_I2C_INCLUDE_DIRS}
  PRIVATE ${LIB_XASSERT_INCLUDE_DIRS}
  PRIVATE ${LIB_MIPI_INCLUDE_DIRS}
)

#**********************
# install
#**********************
set(INSTALL_LIB_DIR "${PROJECT_SOURCE_DIR}/lib")
set(INSTALL_BIN_DIR "${PROJECT_SOURCE_DIR}/bin")
#install(TARGETS aisrv_usb_spi DESTINATION ${INSTALL_BIN_DIR})
install(TARGETS aisrv_usb DESTINATION ${INSTALL_BIN_DIR})
