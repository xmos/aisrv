// Copyright (c) 2021, XMOS Ltd, All rights reserved
#include "aisrv.h"
#include "inference_engine.h"
#include <cstddef>
#include <cstdint>
#include <cstdio>

#if !defined(TFLM_DISABLED)


/* This needs moving to somewhere, preferably an error reporter */

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

void inference_engine_initialize(inference_engine *ie,
                                 uint8_t data_tensor_arena[], uint32_t n_tensor_arena,
                                 uint8_t data_ext[], uint32_t n_ext,
                                 struct tflite_micro_objects *tflmo)
{
    // First initialise the structure with the three memory objects
    // internal memory, external memory, and TFLM objects.
    ie->tflm = tflmo;
    ie->model_data_tensor_arena = data_tensor_arena;
    ie->model_data_ext          = data_ext;
    ie->model_data_tensor_arena_bytes = n_tensor_arena;
    ie->model_data_ext_bytes          = n_ext;

    // Now add all the operators that we need
    auto *resolver = &ie->tflm->resolver;
    TFLM_RESOLVER;
}

int inference_engine_load_model(inference_engine *ie, uint32_t model_bytes, uint8_t *model_data) 
{
   
    // Map the model into a usable data structure. This doesn't involve any
    // copying or parsing, it's a very lightweight operation.
    ie->tflm->model = tflite::GetModel(model_data);
    uint model_version = ie->tflm->model->version();
    if (model_version != TFLITE_SCHEMA_VERSION)
    {
        printf("Model provided is schema version %u not equal "
               "to supported version %d.",
               model_version, TFLITE_SCHEMA_VERSION);
        return 1;
    }

    // Now work out where the tensor arena goes
    uint8_t *kTensorArena = ie->model_data_tensor_arena;
    int kTensorArenaSize = ie->model_data_tensor_arena_bytes;
    
    if(model_data != ie->model_data_ext)
    {
        uint32_t model_ints = (model_bytes + 3) & ~0x03; // Align 4
        kTensorArena     += model_ints; 
        kTensorArenaSize -= model_ints;
    }
    
   
    if (ie->tflm->interpreter) 
    {
        // Delete existing interpreter
        delete ie->tflm->interpreter;  // NOTE: interpreter must be deleted before resolver and reporter
        
        // Need to memset the arena to 0 otherwise assertion in xcore_planning.cc 
        memset(kTensorArena, 0, kTensorArenaSize);
    }

    // Build an interpreter to run the model with
     ie->tflm->interpreter = new (ie->tflm->interpreter_buffer)
      tflite::micro::xcore::XCoreInterpreter(ie->tflm->model,
                                             ie->tflm->resolver,
                                             kTensorArena, kTensorArenaSize,
                                             &ie->tflm->error_reporter,
                                             true,
                                             &ie->tflm->xcore_profiler);

    // Allocate memory from the kTensorArena for the model's tensors.
    TfLiteStatus allocate_tensors_status = ie->tflm->interpreter->AllocateTensors();
    if (allocate_tensors_status != kTfLiteOk)
    {
        TF_LITE_REPORT_ERROR(&ie->tflm->error_reporter, "AllocateTensors() failed");
        return 2;
    }
    ie->operators_size = ie->tflm->model->subgraphs()->Get(0)->operators()->size();

    // Obtain pointers to the model's input and output tensors.
    ie->input_buffer = (unsigned char *)(ie->tflm->interpreter->input(0)->data.raw);
    ie->input_size = ie->tflm->interpreter->input(0)->bytes;
    ie->output_buffer = (unsigned char *)(ie->tflm->interpreter->output(0)->data.raw);
    ie->output_size = ie->tflm->interpreter->output(0)->bytes;
    ie->output_times = (unsigned int *) ie->tflm->xcore_profiler.GetEventDurations();
    ie->output_times_size = ie->operators_size;
    
    return 0;
}

aisrv_status_t interp_invoke(inference_engine *ie)
{
    // Run inference, and report any error
    TfLiteStatus invoke_status = ie->tflm->interpreter->Invoke();

    if (invoke_status != kTfLiteOk) 
    {
        TF_LITE_REPORT_ERROR(&ie->tflm->error_reporter, "Invoke failed\n");
        return AISRV_STATUS_ERROR_INFER_ERR;
    }

    return AISRV_STATUS_OKAY;
}

static const char *index_to_name(inference_engine *ie, int index) {
    auto* opcodes = ie->tflm->model->operator_codes();
    if (index >= opcodes->size()) {
        return "Missing registration";
    }
    auto* opcode = (*opcodes)[index];
    auto builtin_code = std::max(opcode->builtin_code(),
                                 static_cast<tflite::BuiltinOperator>(opcode->deprecated_builtin_code()));
    if (builtin_code == tflite::BuiltinOperator_CUSTOM) {
        return opcode->custom_code()->c_str();
    } else {
        return tflite::EnumNameBuiltinOperator(
            tflite::BuiltinOperator(builtin_code));
    }
}

void print_profiler_summary(inference_engine *ie)
{
    auto* opcodes = ie->tflm->model->operator_codes();
    uint64_t total = 0;
    const char *op_name;

    uint32_t count = ie->tflm->xcore_profiler.GetNumEvents();
    uint32_t const *times = ie->tflm->xcore_profiler.GetEventDurations();
    auto* subgraphs = ie->tflm->model->subgraphs();

    for (size_t i = 0; i < ie->operators_size; ++i)
    {
        if (i < count) 
        {
            const auto* op = (*subgraphs)[0]->operators()->Get(i);
            const size_t index = op->opcode_index();
            op_name = index_to_name(ie, index);

            total += times[i];
            printf("Operator %3d %-20s took %5lu ms\n", i, op_name, times[i]/100000);
        }
    }
    printf("TOTAL %llu microseconds\n", total);

    for (size_t index = 0; index < opcodes->size(); index++) {
        uint64_t time = 0;
        for (size_t i = 0; i < ie->operators_size; ++i)
        {
            if (i < count) 
            {
                const auto* op = (*subgraphs)[0]->operators()->Get(i);
                if (index == op->opcode_index()) {
                    time += times[i];
                }
            }
        }
        op_name = index_to_name(ie, index);

        printf("Operator-class %-20s took %5llu ms %3d%%\n",
               op_name, time/100000, (int)(100*(uint64_t)time/total));
    }
}

#else

// STUBS for when TFLM is disabled.

size_t debug_log_index = 0;
char debug_log_buffer[MAX_DEBUG_LOG_LENGTH * MAX_DEBUG_LOG_ENTRIES] __attribute__((aligned(4)));

void print_profiler_summary(inference_engine *ie) {}
extern "C" void DebugLog(const char* s) {}

void inference_engine_initialize(inference_engine *ie, uint8_t data_tensor_arena[], uint32_t n_int, uint8_t data_ext[], uint32_t n_ext, struct tflite_micro_object *tflmo) {}

int inference_engine_load_model(inference_engine *ie, uint32_t modelSize, uint8_t *model_data) {
    printf("Inference engine disabled, model not loaded\n");
    return AISRV_STATUS_OKAY;
}

aisrv_status_t interp_invoke(inference_engine *ie) {
    printf("Inference engine disabled, model not executed\n");
    return AISRV_STATUS_OKAY;
}

#endif
