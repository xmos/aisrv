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

project(aisrv_usb VERSION 1.0.0)

enable_language(CXX C ASM)

#**********************
# Paths
#**********************

set(AI_TOOLS_DIR "$ENV{XMOS_AISRV_PATH}/submodules/ai_tools")

set(LIB_XUD_DIR "$ENV{XMOS_LIB_XUD_PATH}")

set(LIB_XUD_SRC_DIR "${LIB_XUD_DIR}/lib_xud/src/")

#**********************
# Build flags
#**********************

add_executable(aisrv_usb)
add_library(inference_engine STATIC)

# Optimization
# -DNDEBUG                        # define this to remove debug and profiling
# -DTF_LITE_STRIP_ERROR_STRINGS   # define this to remove logging

set(BUILD_FLAGS
  "-target=XCORE-AI-EXPLORER"
  "-fxscope"
  "${CMAKE_CURRENT_SOURCE_DIR}/config.xscope"
  "-mcmodel=large"
  "-Wno-xcore-fptrgroup"
  "-Wno-unknown-pragmas"
  "-report"
  "-DTF_LITE_STATIC_MEMORY"
  "-DXCORE"
  "-DUSE_EXTMEM"
  "-DUSB_TILE=tile[0]"
  "-Os"
)

target_compile_options(inference_engine PRIVATE ${BUILD_FLAGS})
target_compile_options(aisrv_usb PRIVATE ${BUILD_FLAGS})

target_link_options(aisrv_usb PRIVATE ${BUILD_FLAGS} -lquadspi -w)
set_target_properties(aisrv_usb PROPERTIES OUTPUT_NAME aisrv_usb.xe)

target_link_libraries(aisrv_usb PUBLIC inference_engine)

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

#**********************
# LIB sources
#**********************

include("${AI_TOOLS_DIR}/utils/cmake/xcore_interpreter.cmake")

set(INFERENCE_ENGINE_SOURCE_DIR
  "${PROJECT_SOURCE_DIR}/inference_engine/src"
)

set(INFERENCE_ENGINE_SOURCES
  ${XCORE_INTERPRETER_SOURCES}
  "$ENV{XMOS_AISRV_PATH}/submodules/tensorflow_support/qspi_flash/xcore_device_memory.c"
  "${INFERENCE_ENGINE_SOURCE_DIR}/inference_engine.cc"
  "${INFERENCE_ENGINE_SOURCE_DIR}/mobilenet_v1.c"
)

set(INFERENCE_ENGINE_INCLUDE_DIRS
  ${XCORE_INTERPRETER_INCLUDE_DIRS}
  "$ENV{XMOS_AISRV_PATH}/submodules/tensorflow_support/qspi_flash"
  ${INFERENCE_ENGINE_SOURCE_DIR}
)
set(LIB_XUD_INCLUDE_DIRS
    "${LIB_XUD_DIR}/lib_xud/api"
    "${LIB_XUD_SRC_DIR}/core"
    "${LIB_XUD_SRC_DIR}/user"
)


target_sources(inference_engine PRIVATE ${INFERENCE_ENGINE_SOURCES})
target_include_directories(inference_engine PRIVATE ${INFERENCE_ENGINE_INCLUDE_DIRS})

#**********************
# APP sources
#**********************

set(APP_SOURCES
  "${PROJECT_SOURCE_DIR}/app/main.xc"
  "${PROJECT_SOURCE_DIR}/app/main_c.c"
  "${PROJECT_SOURCE_DIR}/app/aisrv_usb.xc"
)

set_source_files_properties("${PROJECT_SOURCE_DIR}/app/main.xc" PROPERTIES LANGUAGE C)
set_source_files_properties("${PROJECT_SOURCE_DIR}/app/aisrv_usb.xc" PROPERTIES LANGUAGE C)

#**********************
# targets
#**********************
target_sources(aisrv_usb
  PRIVATE ${APP_SOURCES}
  PRIVATE ${LIB_XUD_SOURCES}
)

target_include_directories(aisrv_usb
  PRIVATE ${INFERENCE_ENGINE_INCLUDE_DIRS}
  PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/app/src"
  PRIVATE ${LIB_XUD_INCLUDE_DIRS}


)

#**********************
# install
#**********************
set(INSTALL_LIB_DIR "${PROJECT_SOURCE_DIR}/lib")
set(INSTALL_BIN_DIR "${PROJECT_SOURCE_DIR}/bin")
install(TARGETS aisrv_usb DESTINATION ${INSTALL_BIN_DIR})
install(TARGETS inference_engine DESTINATION ${INSTALL_LIB_DIR})
