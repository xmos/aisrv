#ifndef SHARED_MEMORY_H
#define SHARED_MEMORY_H

#include <stdint.h>

struct memory {
    uint32_t status;
    uint32_t timings[100];
    uint32_t ai_server_spec[1] = { INFERENCE_ENGINE_SPEC };
    uint32_t memory[9000];

    uint32_t timings_index;
    uint32_t input_tensor_index;
    uint32_t output_tensor_index;
    uint32_t timings_length;
    uint32_t input_tensor_length;
    uint32_t output_tensor_length;
    uint32_t model_index;
    uint32_t model_length;
};

#endif
