// Copyright (c) 2021, XMOS Ltd, All rights reserved
#include "aisrv.h"
#include <cstddef>
#include <cstdint>
#include <cstdio>

#include "inference_engine.h"
#include "server_memory.h"

#if !defined(TFLM_DISABLED)
static struct tflite_micro_objects s0;


#define TENSOR_ARENA_BYTES          (20224000)

// Because of bug in xgdb we make this array tiny, knowing we own external memory
// otherwise xgdb spends hours loading this array
// TODO - fix when bug is fixed.
__attribute__((section(".ExtMem_data")))
uint32_t data_ext[16 + 0 * TENSOR_ARENA_BYTES/sizeof(int)];
#endif

void inference_engine_initialize_with_memory(inference_engine_t *ie) {
#if !defined(TFLM_DISABLED)
    inference_engine_initialize(ie,
                                data_ext, TENSOR_ARENA_BYTES,
                                nullptr,  0,
                                &s0);
    
#endif
}
