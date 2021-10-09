// Copyright (c) 2020, XMOS Ltd, All rights reserved
#ifndef INFERENCE_ENGINE_H_
#define INFERENCE_ENGINE_H_

#include "aisrv.h"

#ifdef __cplusplus
#define UNSAFE /**/
#else
#define UNSAFE unsafe
#endif

#ifdef __cplusplus

#if !defined(TFLM_DISABLED)


#if defined( __tflm_conf_h_exists__)
#include "tflm_conf.h"
#else

#define TFLM_OPERATORS 10
#define TFLM_RESOLVER       \
    resolver->AddFullyConnected(); \
    resolver->AddConv2D(); \
    resolver->AddDepthwiseConv2D(); \
    resolver->AddCustom(tflite::ops::micro::xcore::Conv2D_Shallow_OpCode, \
            tflite::ops::micro::xcore::Register_Conv2D_Shallow()); \
    resolver->AddCustom(tflite::ops::micro::xcore::Conv2D_Deep_OpCode, \
            tflite::ops::micro::xcore::Register_Conv2D_Deep()); \
    resolver->AddCustom(tflite::ops::micro::xcore::Conv2D_Depthwise_OpCode, \
            tflite::ops::micro::xcore::Register_Conv2D_Depthwise()); \
    resolver->AddCustom(tflite::ops::micro::xcore::FullyConnected_8_OpCode, \
            tflite::ops::micro::xcore::Register_FullyConnected_8()); \
    resolver->AddCustom(tflite::ops::micro::xcore::Conv2D_1x1_OpCode, \
            tflite::ops::micro::xcore::Register_Conv2D_1x1()); \
    resolver->AddCustom(tflite::ops::micro::xcore::Pad_OpCode, \
            tflite::ops::micro::xcore::Register_Pad()); \
    resolver->AddCustom(tflite::ops::micro::xcore::Lookup_8_OpCode, \
            tflite::ops::micro::xcore::Register_Lookup_8());

#endif

#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "xcore_ops.h"
#include "xcore_interpreter.h"
#include "xcore_error_reporter.h"
#include "xcore_profiler.h"
#include "xcore_device_memory.h"

struct tflite_micro_objects {
    tflite::micro::xcore::XCoreErrorReporter error_reporter;
    tflite::micro::xcore::XCoreProfiler xcore_profiler;
    uint8_t interpreter_buffer[sizeof(tflite::micro::xcore::XCoreInterpreter)];
    tflite::MicroMutableOpResolver<TFLM_OPERATORS> resolver;
    
    tflite::micro::xcore::XCoreInterpreter *interpreter;
    const tflite::Model *model;
};
#endif

#endif

struct tflite_micro_objects;

typedef struct inference_engine {
    uint32_t * UNSAFE model_data_tensor_arena;  // Tensor arena always goes here
    uint32_t * UNSAFE model_data_ext;           // Model goes in tensor_arena or in ext.
    uint32_t outputs;                            // Number of output tensors
    uint32_t inputs;                             // Number of input tensors
    uint32_t * UNSAFE output_buffers[NUM_OUTPUT_TENSORS];
    uint32_t * UNSAFE input_buffers[NUM_INPUT_TENSORS];
    uint32_t output_sizes[NUM_OUTPUT_TENSORS];
    uint32_t input_sizes[NUM_INPUT_TENSORS];
    uint32_t output_size;
    uint32_t input_size;
    uint32_t model_data_tensor_arena_bytes;
    uint32_t model_data_ext_bytes;
    uint32_t output_times_size;
    uint32_t operators_size;
    uint32_t * UNSAFE output_times;
    struct tflite_micro_objects * UNSAFE tflm;
// status for the engine to maintain
    uint32_t haveModel;
    uint32_t chainToNext;
    uint32_t acquireMode;
    uint32_t outputGpioEn;
    int8_t outputGpioThresh[AISRV_GPIO_LENGTH]; 
    uint8_t outputGpioMode;
    uint32_t debug_log_buffer[MAX_DEBUG_LOG_LENGTH / sizeof(uint32_t)]; // aligned
    uint32_t modelSize;
} inference_engine_t;


#ifdef __cplusplus
#ifndef TFLM_DISABLED
tflite::MicroMutableOpResolver<TFLM_OPERATORS> *
     inference_engine_initialize(inference_engine_t * UNSAFE ie,
                                 uint32_t data_tensor_arena[], uint32_t n_int,
                                 uint32_t data_ext[], uint32_t n_ext,
                                 struct tflite_micro_objects * UNSAFE tflmo);
#endif
extern "C" {
#endif
#ifdef __XC__
    int inference_engine_load_model(inference_engine_t * UNSAFE ie, uint32_t modelSize, uint32_t * UNSAFE model_data, chanend ?c_flash);
#else
    int inference_engine_load_model(inference_engine_t * UNSAFE ie, uint32_t modelSize, uint32_t * UNSAFE model_data, unsigned c_flash);
#endif
    void inference_engine_unload_model(inference_engine_t * UNSAFE ie);
    aisrv_status_t interp_invoke(inference_engine_t * UNSAFE ie);
    void print_profiler_summary(inference_engine_t * UNSAFE ie);
#ifdef __cplusplus
};
#endif


#endif  // INFERENCE_ENGINE_H_
