#ifndef SHARED_MEMORY_H
#define SHARED_MEMORY_H

#include <stdint.h>

struct memory {
    uint32_t status[1];
    uint32_t ai_server_id[1];
    uint32_t spec[5];
    uint32_t memory[600];

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
