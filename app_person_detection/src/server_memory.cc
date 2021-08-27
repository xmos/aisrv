// Copyright (c) 2021, XMOS Ltd, All rights reserved
#include "aisrv.h"
#include <cstddef>
#include <cstdint>
#include <cstdio>

#include "inference_engine.h"
#include "server_memory.h"

#if !defined(TFLM_DISABLED)
static struct tflite_micro_objects s0;
static struct tflite_micro_objects s1;

#define TENSOR_ARENA_0_BYTES          (396000)
#define TENSOR_ARENA_1_BYTES          (379000)
uint32_t data_0[TENSOR_ARENA_0_BYTES/sizeof(int)];
uint32_t data_1[TENSOR_ARENA_1_BYTES/sizeof(int)];
#endif

void inference_engine_0_initialize_with_memory(inference_engine_t *ie) {
#if !defined(TFLM_DISABLED)
    inference_engine_initialize(ie,
                                data_0, TENSOR_0_ARENA_BYTES,
                                nullptr,  0,
                                &s0);
    
#endif
}

void inference_engine_1_initialize_with_memory(inference_engine_t *ie) {
#if !defined(TFLM_DISABLED)
    inference_engine_initialize(ie,
                                data_1, TENSOR_1_ARENA_BYTES,
                                nullptr,  0,
                                &s1);
    
#endif
}
