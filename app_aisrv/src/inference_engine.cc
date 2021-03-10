// Copyright (c) 2021, XMOS Ltd, All rights reserved

#include "aisrv.h"
#include "inference_engine.h"

#include <cstddef>
#include <cstdint>
#include <cstdio>

#include "tensorflow/lite/micro/kernels/xcore/xcore_interpreter.h"
#include "tensorflow/lite/micro/kernels/xcore/xcore_ops.h"
#include "tensorflow/lite/micro/kernels/xcore/xcore_profiler.h"
#include "tensorflow/lite/micro/micro_error_reporter.h"
#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "tensorflow/lite/version.h"
#include "xcore_device_memory.h"

// shorthand typedefs
typedef tflite::MicroAllocator micro_allocator_t;
typedef tflite::MicroErrorReporter error_reporter_t;
typedef tflite::micro::xcore::XCoreInterpreter interpreter_t;
typedef tflite::micro::xcore::XCoreProfiler profiler_t;
typedef tflite::MicroMutableOpResolver<18> resolver_t;
typedef tflite::Model model_t;

// static buffer for interpreter_t class allocation
uint8_t interpreter_buffer[sizeof(interpreter_t)];

// static variables
static error_reporter_t error_reporter_s;
static error_reporter_t *reporter = nullptr;

static resolver_t resolver_s;
static resolver_t *resolver = nullptr;
static profiler_t profiler_s;
static profiler_t *profiler = nullptr;
static interpreter_t *interpreter = nullptr;
static const model_t *model = nullptr;

int kTensorArenaSize = INT_MEM_SIZE_BYTES ;

__attribute__((section(".ExtMem_data")))
uint8_t model_data_ext[MAX_MODEL_SIZE_EXT_BYTES] __attribute__((aligned(4)));

uint8_t inferenceMem[INT_MEM_SIZE_BYTES]; __attribute__((aligned(4)));
uint8_t *model_data_int = inferenceMem;
uint8_t *kTensorArena = inferenceMem;

size_t debug_log_index = 0;
char debug_log_buffer[MAX_DEBUG_LOG_LENGTH * MAX_DEBUG_LOG_ENTRIES] __attribute__((aligned(4)));

extern "C" void DebugLog(const char* s) 
{ 
    strcpy(&debug_log_buffer[debug_log_index*MAX_DEBUG_LOG_LENGTH], s);
    printf("%s", &debug_log_buffer[debug_log_index*MAX_DEBUG_LOG_LENGTH]);
    debug_log_index++; 
    if(debug_log_index == MAX_DEBUG_LOG_ENTRIES) 
        debug_log_index = 0;
}

aisrv_status_t interp_invoke() 
{
    // Run inference, and report any error
    TfLiteStatus invoke_status = interpreter->Invoke();

    if (invoke_status != kTfLiteOk) 
    {
        TF_LITE_REPORT_ERROR(reporter, "Invoke failed\n");
        return AISRV_STATUS_ERROR_INFER_ERR;
    }

    return AISRV_STATUS_OKAY;
}

void inference_engine_initialize(inference_engine *ie)
{
    ie->model_data_int = model_data_int;    
    ie->model_data_ext = model_data_ext;    
}
int count = 0;

int interp_initialize(inference_engine *ie, uint32_t modelSize, uint8_t *model_data) 
{
    // Set up logging
    static tflite::MicroErrorReporter error_reporter;
    reporter = &error_reporter;

    if (resolver == nullptr) 
    {
        resolver = &resolver_s;
    }

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


    // This pulls in all the operation implementations we expect to need.
    resolver->AddSoftmax();
    resolver->AddPad();
    resolver->AddMean();
    resolver->AddConcatenation();
    
    resolver->AddCustom(tflite::ops::micro::xcore::Add_8_OpCode,
            tflite::ops::micro::xcore::Register_Add_8());

    resolver->AddCustom(tflite::ops::micro::xcore::MaxPool2D_OpCode,
            tflite::ops::micro::xcore::Register_MaxPool2D());

    resolver->AddCustom(tflite::ops::micro::xcore::AvgPool2D_Global_OpCode,
            tflite::ops::micro::xcore::Register_AvgPool2D_Global());

    resolver->AddCustom(tflite::ops::micro::xcore::AvgPool2D_OpCode,
            tflite::ops::micro::xcore::Register_AvgPool2D());

    resolver->AddCustom(tflite::ops::micro::xcore::Conv2D_Shallow_OpCode,
            tflite::ops::micro::xcore::Register_Conv2D_Shallow());

    resolver->AddCustom(tflite::ops::micro::xcore::Conv2D_Deep_OpCode,
            tflite::ops::micro::xcore::Register_Conv2D_Deep());

    resolver->AddCustom(tflite::ops::micro::xcore::Conv2D_Depthwise_OpCode,
            tflite::ops::micro::xcore::Register_Conv2D_Depthwise());

    resolver->AddCustom(tflite::ops::micro::xcore::FullyConnected_8_OpCode,
            tflite::ops::micro::xcore::Register_FullyConnected_8());

    resolver->AddCustom(tflite::ops::micro::xcore::Conv2D_1x1_OpCode,
            tflite::ops::micro::xcore::Register_Conv2D_1x1());

    resolver->AddCustom(tflite::ops::micro::xcore::Pad_OpCode,
            tflite::ops::micro::xcore::Register_Pad());

    resolver->AddCustom(tflite::ops::micro::xcore::Lookup_8_OpCode,
            tflite::ops::micro::xcore::Register_Lookup_8());

    resolver->AddCustom(tflite::ops::micro::xcore::BConv2d_Int8_OpCode,
            tflite::ops::micro::xcore::Register_BConv2D_Int8());

    resolver->AddCustom(tflite::ops::micro::xcore::BConv2d_Int8_DeepIn_DeepOut_OpCode,
            tflite::ops::micro::xcore::Register_BConv2D_Int8_Deepin_Deepout());

    resolver->AddCustom(tflite::ops::micro::xcore::Bsign_8_OpCode,
            tflite::ops::micro::xcore::Register_BSign_8());

    if(model_data == ie->model_data_ext)
    {
        modelSize = 0;
    }
    else
    {
        modelSize = (modelSize + 3) & ~0x03; // Align 4
    }
    
    kTensorArena = inferenceMem + modelSize; 
    kTensorArenaSize = sizeof(inferenceMem) - modelSize;
   
    if (interpreter) 
    {
        // Delete existing interpreter
        delete interpreter;  // NOTE: interpreter must be deleted before resolver and reporter
        
        // Need to memset the arena to 0 otherwise assertion in xcore_planning.cc 
        memset(kTensorArena, 0, kTensorArenaSize);
    }

    // Build an interpreter to run the model with
     interpreter = new (interpreter_buffer)
      interpreter_t(model, *resolver, kTensorArena, kTensorArenaSize, reporter,
                    true, profiler);

    // Allocate memory from the kTensorArena for the model's tensors.
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
    ie->output_times = (unsigned int *) xcore_profiler.GetEventDurations();
    ie->output_times_size = interpreter->operators_size();
    
    return 0;
}

void print_profiler_summary() 
{
    uint32_t count = 0;
    uint32_t const *times = nullptr;
    const char *op_name;
    uint32_t total = 0;

    if (profiler) 
    {
        count = profiler->GetNumEvents();
        times = profiler->GetEventDurations();
    }

    for (size_t i = 0; i < interpreter->operators_size(); ++i) 
    {
        if (i < count) 
        {
            tflite::NodeAndRegistration node_and_reg =
                interpreter->node_and_registration(static_cast<int>(i));
            const TfLiteRegistration *registration = node_and_reg.registration;
            if (registration->builtin_code == tflite::BuiltinOperator_CUSTOM) {
                op_name = registration->custom_name;
            } else {
                op_name = tflite::EnumNameBuiltinOperator(
                        tflite::BuiltinOperator(registration->builtin_code));
            }
            total += times[i];
            printf("Operator %d, %s took %lu microseconds\n", i, op_name, times[i]);
        }
    }
    printf("TOTAL %lu microseconds\n", total);
}
