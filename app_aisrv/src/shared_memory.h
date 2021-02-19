#ifndef SHARED_MEMORY_H
#define SHARED_MEMORY_H

#include <stdint.h>
#include "aisrv.h"

struct memory {
    uint32_t status[1];
    uint32_t ai_server_id[1];
    uint32_t spec[SPEC_ALL_TOTAL];
    uint32_t memory[128*128*3+1024];

    uint32_t timings_index;
    uint32_t input_tensor_index;
    uint32_t output_tensor_index;
    uint32_t debug_log_index;
    uint32_t timings_length;         // in words
    uint32_t input_tensor_length;    // in words
    uint32_t output_tensor_length;   // in words
    uint32_t sensor_tensor_length;   // in words
    uint32_t debug_log_length;       // in words
    uint32_t model_index;
    uint32_t model_length;
    uint32_t tensor_is_sensor_output;//If true, the tensor stored is the sensor frame
};

#endif
