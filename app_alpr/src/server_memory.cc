// Copyright (c) 2021, XMOS Ltd, All rights reserved
#include "aisrv.h"
#include <cstddef>
#include <cstdint>
#include <cstdio>

#include "inference_engine.h"
#include "server_memory.h"

#if !defined(TFLM_DISABLED)


#define TENSOR_ARENA_BYTES_0        (20224000)
#define TENSOR_ARENA_BYTES_1          (364000)

// Because of bug in xgdb we make this array tiny, knowing we own external memory
// otherwise xgdb spends hours loading this array
// TODO - fix when bug is fixed.
__attribute__((section(".ExtMem_data")))
uint32_t data_ext[16 + 0 * TENSOR_ARENA_BYTES_0/sizeof(int)];  // engine 0, tile 1
uint32_t data_int[         TENSOR_ARENA_BYTES_1/sizeof(int)];  // engine 1, tile 0
#endif

void inference_engine_initialize_with_memory_0(inference_engine_t *ie, unsigned c_flash) {
#if !defined(TFLM_DISABLED)
    static struct tflite_micro_objects s0;
    auto *resolver = inference_engine_initialize(ie,
                                                 data_ext, TENSOR_ARENA_BYTES_0,
                                                 nullptr,  0,
                                                 &s0,
                                                 c_flash);
    resolver->AddPad();
    resolver->AddReshape();
    resolver->AddConcatenation();
    resolver->AddAdd();
    resolver->AddLogistic();
    resolver->AddConv2D();
    resolver->AddQuantize();
    resolver->AddDepthwiseConv2D();
    resolver->AddCustom(tflite::ops::micro::xcore::Conv2D_V2_OpCode,
               tflite::ops::micro::xcore::Register_Conv2D_V2());
    resolver->AddCustom(tflite::ops::micro::xcore::Load_Flash_V2_OpCode,
               tflite::ops::micro::xcore::Register_LoadFromFlash_V2());

#endif
}


void inference_engine_initialize_with_memory_1(inference_engine_t *ie) {
#if !defined(TFLM_DISABLED)
    static struct tflite_micro_objects s1;
    auto *resolver = inference_engine_initialize(ie,
                                                 data_int, TENSOR_ARENA_BYTES_1,
                                                 nullptr,  0,
                                                 &s1,
                                                 0);
    resolver->AddPad();
    resolver->AddAdd();
    resolver->AddMaxPool2D();
    resolver->AddAveragePool2D();
    resolver->AddConv2D();
    resolver->AddDepthwiseConv2D();
    resolver->AddCustom(tflite::ops::micro::xcore::Conv2D_V2_OpCode,
               tflite::ops::micro::xcore::Register_Conv2D_V2());

#endif
}

#if defined(TFLM_DISABLED)
__attribute__((section(".ExtMem_data")))
uint32_t tflite_disabled_image[320*320*3/4];
#endif
