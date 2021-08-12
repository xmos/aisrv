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

#include "tensorflow/lite/micro/micro_error_reporter.h"
#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "xcore_ops.h"
#include "xcore_interpreter.h"
#include "xcore_profiler.h"
#include "xcore_device_memory.h"

struct tflite_micro_objects {
    tflite::MicroErrorReporter error_reporter;
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
    unsigned char * UNSAFE model_data_int;
    unsigned char * UNSAFE model_data_ext;
    unsigned char * UNSAFE output_buffer;
    unsigned char * UNSAFE input_buffer;
    unsigned int input_size;
    unsigned int output_size;
    unsigned int output_times_size;
    unsigned int operators_size;
    unsigned int * UNSAFE output_times;
    struct tflite_micro_objects * UNSAFE tflm;
} inference_engine_t;


#ifdef __cplusplus
extern "C" {
#endif
    void inference_engine_initialize(inference_engine_t * UNSAFE ie,
                                     uint8_t data_int[], uint32_t n_int,
                                     uint8_t data_ext[], uint32_t n_ext,
                                     struct tflite_micro_objects * UNSAFE tflmo);
    int inference_engine_load_model(inference_engine_t * UNSAFE ie, uint32_t modelSize, uint8_t * UNSAFE model_data);
    aisrv_status_t interp_invoke(inference_engine_t * UNSAFE ie);
    void print_profiler_summary(inference_engine_t * UNSAFE ie);
#ifdef __cplusplus
};
#endif


#endif  // INFERENCE_ENGINE_H_
