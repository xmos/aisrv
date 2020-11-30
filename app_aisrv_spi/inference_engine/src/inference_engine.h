// Copyright (c) 2019, XMOS Ltd, All rights reserved
#ifndef INFERENCE_ENGINE_H_
#define INFERENCE_ENGINE_H_

#include "../../app/aisrv.h"

#ifdef __cplusplus
extern "C" {
#endif


#define MAX_MODEL_SIZE_BYTES (910000)

    int interp_initialize(unsigned char **input, int *input_size, unsigned char **output, int *output_size, unsigned int **times, unsigned int *times_size);

aisrv_status_t interp_invoke();

void write_model_data(int i, unsigned char x);

#ifdef __cplusplus
};
#endif

#endif  // INFERENCE_ENGINE_H_
