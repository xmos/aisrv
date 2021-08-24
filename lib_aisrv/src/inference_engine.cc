// Copyright (c) 2021, XMOS Ltd, All rights reserved
#include "aisrv.h"
#include "print.h"
#include "inference_engine.h"
#include <cstddef>
#include <cstdint>
#include <cstdio>

#if !defined(TFLM_DISABLED)

extern "C" void DebugLog(const char* s) { while (*s) { printchar(*s); s++; }}  // Not sure why we need this

void inference_engine_initialize(inference_engine *ie,
                                 uint32_t data_tensor_arena[], uint32_t n_tensor_arena,
                                 uint32_t data_ext[], uint32_t n_ext,
                                 struct tflite_micro_objects *tflmo)
{
    // First initialise the structure with the three memory objects
    // internal memory, external memory, and TFLM objects.
    ie->tflm = tflmo;
    ie->model_data_tensor_arena = data_tensor_arena;
    ie->model_data_ext          = data_ext;
    ie->model_data_tensor_arena_bytes = n_tensor_arena;
    ie->model_data_ext_bytes          = n_ext;
    ie->tflm->error_reporter.Init((char *)ie->debug_log_buffer, MAX_DEBUG_LOG_LENGTH);
    // Now add all the operators that we need
    auto *resolver = &ie->tflm->resolver;
    TFLM_RESOLVER;
}

int inference_engine_load_model(inference_engine *ie, uint32_t model_bytes, uint32_t *model_data) 
{
   
    // Map the model into a usable data structure. This doesn't involve any
    // copying or parsing, it's a very lightweight operation.
    ie->tflm->model = tflite::GetModel((uint8_t *)model_data);
    uint model_version = ie->tflm->model->version();
    if (model_version != TFLITE_SCHEMA_VERSION)
    {
        TF_LITE_REPORT_ERROR(&ie->tflm->error_reporter, "Model provided is schema version %u not equal to supported version %d.", model_version, TFLITE_SCHEMA_VERSION);
        return 1;
    }

    // Now work out where the tensor arena goes
    uint8_t *kTensorArena = (uint8_t *) ie->model_data_tensor_arena;
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
    ie->inputs = ie->tflm->interpreter->inputs_size();
    ie->input_size = 0;
    if (ie->inputs > NUM_INPUT_TENSORS) {
        TF_LITE_REPORT_ERROR(&ie->tflm->error_reporter, "Too many input tensors");
        return 3;
    }
    for(int i = 0; i < ie->inputs; i++) {
        ie->input_buffers[i] = (uint32_t *)(ie->tflm->interpreter->input(i)->data.raw);
        ie->input_sizes[i] = ie->tflm->interpreter->input(i)->bytes;
        ie->input_size += ie->input_sizes[i];
    }
    ie->outputs = ie->tflm->interpreter->outputs_size();
    ie->output_size = 0;
    if (ie->outputs > NUM_OUTPUT_TENSORS) {
        TF_LITE_REPORT_ERROR(&ie->tflm->error_reporter, "Too many output tensors %d", ie->outputs);
        return 4;
    }
    for(int i = 0; i < ie->outputs; i++) {
        ie->output_buffers[i] = (uint32_t *)(ie->tflm->interpreter->output(i)->data.raw);
        ie->output_sizes[i] = ie->tflm->interpreter->output(i)->bytes;
        ie->output_size += ie->output_sizes[i];
    }
    ie->output_times = (uint32_t *)ie->tflm->xcore_profiler.GetEventDurations();
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

int inference_engine_load_model(inference_engine *ie, uint32_t modelSize, uint32_t *model_data) {
    printf("Inference engine disabled, model not loaded\n");
    return AISRV_STATUS_OKAY;
}

aisrv_status_t interp_invoke(inference_engine *ie) {
    printf("Inference engine disabled, model not executed\n");
    return AISRV_STATUS_OKAY;
}

#endif