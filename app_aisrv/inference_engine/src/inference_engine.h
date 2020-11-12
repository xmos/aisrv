// Copyright (c) 2019, XMOS Ltd, All rights reserved
#ifndef INFERENCE_ENGINE_H_
#define INFERENCE_ENGINE_H_

#ifdef __cplusplus
extern "C" {
#endif

void initialize(unsigned char **input, int *input_size, unsigned char **output,
                int *output_size);
void invoke();

#ifdef __cplusplus
};
#endif

#endif  // INFERENCE_ENGINE_H_
