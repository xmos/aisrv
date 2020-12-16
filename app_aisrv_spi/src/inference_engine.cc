// Copyright (c) 2020, XMOS Ltd, All rights reserved

#include "inference_engine.h"

#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <iostream>

#include "tensorflow/lite/micro/kernels/xcore/xcore_interpreter.h"
#include "tensorflow/lite/micro/kernels/xcore/xcore_ops.h"
#include "tensorflow/lite/micro/kernels/xcore/xcore_profiler.h"
#include "tensorflow/lite/micro/micro_error_reporter.h"
#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "tensorflow/lite/version.h"
#include "xcore_device_memory.h"

tflite::ErrorReporter *reporter = nullptr;
tflite::Profiler *profiler = nullptr;
const tflite::Model *model = nullptr;
tflite::micro::xcore::XCoreInterpreter *interpreter = nullptr;
constexpr int kTensorArenaSize = 286000;
uint8_t tensor_arena[kTensorArenaSize];

#ifdef USE_SWMEM
__attribute__((section(".SwMem_data")))
#elif USE_EXTMEM
__attribute__((section(".ExtMem_data")))
#endif
unsigned char model_data[MAX_MODEL_SIZE_BYTES] __attribute__((aligned(4)));

aisrv_status_t interp_invoke() 
{
    // Run inference, and report any error
    TfLiteStatus invoke_status = interpreter->Invoke();

    if (invoke_status != kTfLiteOk) 
    {
        TF_LITE_REPORT_ERROR(reporter, "Invoke failed\n");
        return STATUS_ERROR_INFER;
    }

    return STATUS_OKAY;
}

void inference_engine_initialize(inference_engine *ie)
{
    ie->model_data = model_data;    
}

int interp_initialize(inference_engine *ie) 
{
    // Set up logging
    static tflite::MicroErrorReporter error_reporter;
    reporter = &error_reporter;

    // Set up profiling.
    static tflite::micro::xcore::XCoreProfiler xcore_profiler;
    profiler = &xcore_profiler;

    // Map the model into a usable data structure. This doesn't involve any
    // copying or parsing, it's a very lightweight operation.
    model = tflite::GetModel(model_data);
    if (model->version() != TFLITE_SCHEMA_VERSION)
    {
        printf("Model provided is schema version %u not equal "
               "to supported version %d.",
               model->version(), TFLITE_SCHEMA_VERSION);
        return 1;
    }

    // This pulls in all the operation implementations we need.
    static tflite::MicroMutableOpResolver<17> resolver;
    resolver.AddSoftmax();
    resolver.AddPad();
    resolver.AddMean();
    resolver.AddConcatenation();
    resolver.AddCustom(tflite::ops::micro::xcore::Add_8_OpCode,
                     tflite::ops::micro::xcore::Register_Add_8());
    resolver.AddCustom(tflite::ops::micro::xcore::MaxPool2D_OpCode,
                     tflite::ops::micro::xcore::Register_MaxPool2D());
    resolver.AddCustom(tflite::ops::micro::xcore::Conv2D_Shallow_OpCode,
                     tflite::ops::micro::xcore::Register_Conv2D_Shallow());
    resolver.AddCustom(tflite::ops::micro::xcore::Conv2D_Shallow_OpCode,
                     tflite::ops::micro::xcore::Register_Conv2D_Shallow());
    resolver.AddCustom(tflite::ops::micro::xcore::Conv2D_Depthwise_OpCode,
                     tflite::ops::micro::xcore::Register_Conv2D_Depthwise());
    resolver.AddCustom(tflite::ops::micro::xcore::Conv2D_1x1_OpCode,
                     tflite::ops::micro::xcore::Register_Conv2D_1x1());
    resolver.AddCustom(tflite::ops::micro::xcore::AvgPool2D_Global_OpCode,
                     tflite::ops::micro::xcore::Register_AvgPool2D_Global());
    resolver.AddCustom(tflite::ops::micro::xcore::FullyConnected_8_OpCode,
                     tflite::ops::micro::xcore::Register_FullyConnected_8());

    resolver.AddCustom(tflite::ops::micro::xcore::Conv2D_Shallow_OpCode,
                     tflite::ops::micro::xcore::Register_Conv2D_Shallow());
    resolver.AddCustom(tflite::ops::micro::xcore::Conv2D_Depthwise_OpCode,
                     tflite::ops::micro::xcore::Register_Conv2D_Depthwise());
    resolver.AddCustom(tflite::ops::micro::xcore::Conv2D_1x1_OpCode,
                     tflite::ops::micro::xcore::Register_Conv2D_1x1());
    resolver.AddCustom(tflite::ops::micro::xcore::AvgPool2D_Global_OpCode,
                     tflite::ops::micro::xcore::Register_AvgPool2D_Global());
    resolver.AddCustom(tflite::ops::micro::xcore::FullyConnected_8_OpCode,
                     tflite::ops::micro::xcore::Register_FullyConnected_8());

    // Build an interpreter to run the model with
    static tflite::micro::xcore::XCoreInterpreter static_interpreter(
      model, resolver, tensor_arena, kTensorArenaSize, reporter, true,
      profiler);
    interpreter = &static_interpreter;

    // Allocate memory from the tensor_arena for the model's tensors.
    TfLiteStatus allocate_tensors_status = interpreter->AllocateTensors();
    if (allocate_tensors_status != kTfLiteOk)
    {
        TF_LITE_REPORT_ERROR(reporter, "AllocateTensors() failed");
        return 2;
    }

    // Obtain pointers to the model's input and output tensors.
    ie->input_buffer = (unsigned char *)(interpreter->input(0)->data.raw);
    ie->input_size = interpreter->input(0)->bytes;
    ie->output_buffer = (unsigned char *)(interpreter->output(0)->data.raw);
    ie->output_size = interpreter->output(0)->bytes;
#if defined(XCORE_PROFILER_MAX_LEVELS)
    ie->output_times = (unsigned int *) xcore_profiler.GetTimes();
    ie->output_times_size = interpreter->operators_size();
#else
    ie->output_times = NULL;
    ie->output_times_size = 0;
#endif
    
    return 0;
}
