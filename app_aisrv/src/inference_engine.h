// Copyright (c) 2020, XMOS Ltd, All rights reserved
#ifndef INFERENCE_ENGINE_H_
#define INFERENCE_ENGINE_H_

#include "../../app_aisrv_spi/src/aisrv.h"

#ifdef __cplusplus
#define UNSAFE /**/
#else
#define UNSAFE unsafe
#endif

typedef struct inference_engine {
    unsigned char * UNSAFE model_data;
    unsigned char * UNSAFE output_buffer;
    unsigned char * UNSAFE input_buffer;
    unsigned int input_size;
    unsigned int output_size;
    unsigned int output_times_size;
    unsigned int * UNSAFE output_times;
} inference_engine_t;

#define MAX_MODEL_SIZE_BYTES (1060000)

#ifdef __cplusplus
extern "C" {
#endif
    void inference_engine_initialize(inference_engine_t * UNSAFE ie);
    int interp_initialize(inference_engine_t * UNSAFE ie);
    aisrv_status_t interp_invoke();
#ifdef __cplusplus
};
#endif

#endif  // INFERENCE_ENGINE_H_
