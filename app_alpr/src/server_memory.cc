// Copyright (c) 2021, XMOS Ltd, All rights reserved
#include "aisrv.h"
#include <cstddef>
#include <cstdint>
#include <cstdio>

#include "inference_engine.h"
#include "server_memory.h"

#if !defined(TFLM_DISABLED)
static struct tflite_micro_objects s0;

__attribute__((section(".ExtMem_data")))
uint8_t data_ext[MAX_MODEL_SIZE_EXT_BYTES] __attribute__((aligned(4)));

__attribute__((section(".ExtMem_data")))
uint8_t data_int[INT_MEM_SIZE_BYTES] __attribute__((aligned(4)));
#endif

void inference_engine_initialize_with_memory(inference_engine_t *ie) {
#if !defined(TFLM_DISABLED)
    inference_engine_initialize(ie, data_int, INT_MEM_SIZE_BYTES,
                                data_ext, MAX_MODEL_SIZE_EXT_BYTES,
                                &s0);
    
#endif
}
