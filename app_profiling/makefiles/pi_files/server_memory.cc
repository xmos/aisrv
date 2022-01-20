// Copyright (c) 2021, XMOS Ltd, All rights reserved
#include "aisrv.h"
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>

#include "inference_engine.h"
#include "server_memory.h"

#define TENSOR_ARENA_BYTES_0        (20224000)
#define TENSOR_ARENA_BYTES_1          (354000)

// Because of bug in xgdb we make this array tiny, knowing we own external memory
// otherwise xgdb spends hours loading this array
// TODO - fix when bug is fixed.
__attribute__((section(".ExtMem_data")))
uint32_t data_ext[16 + 0 * TENSOR_ARENA_BYTES_0/sizeof(int)];  // engine 0, tile 1
uint32_t data_int[         TENSOR_ARENA_BYTES_1/sizeof(int)];  // engine 1, tile 0

void inference_engine_initialize_with_memory_0(inference_engine_t *ie) {
    static struct tflite_micro_objects s0;
    memset(data_ext, 0, TENSOR_ARENA_BYTES_0);
    auto *resolver = inference_engine_initialize(ie,
                                                 data_int, TENSOR_ARENA_BYTES_1,
                                                 data_ext, TENSOR_ARENA_BYTES_0,
                                                 &s0);
    resolver->AddDequantize();
    resolver->AddSoftmax();
    resolver->AddMean();
    resolver->AddPad();
    resolver->AddPack();
    resolver->AddMul();
    resolver->AddSub();
    resolver->AddShape();
    resolver->AddStridedSlice();
    resolver->AddReshape();
    resolver->AddConcatenation();
    resolver->AddAdd();
    resolver->AddLogistic();
    resolver->AddConv2D();
    resolver->AddQuantize();
    resolver->AddDepthwiseConv2D();
    resolver->AddCustom(tflite::ops::micro::xcore::Conv2D_V2_OpCode,
               tflite::ops::micro::xcore::Register_Conv2D_V2());
    resolver->AddCustom(tflite::ops::micro::xcore::Load_Flash_OpCode,
               tflite::ops::micro::xcore::Register_LoadFromFlash());

}


void inference_engine_initialize_with_memory_1(inference_engine_t *ie) {
    static struct tflite_micro_objects s1;
    auto *resolver = inference_engine_initialize(ie,
                                                 data_int, TENSOR_ARENA_BYTES_1,
                                                 nullptr,  0,
                                                 &s1);
    resolver->AddDequantize();
    resolver->AddSoftmax();
    resolver->AddMean();
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
    resolver->AddCustom(tflite::ops::micro::xcore::Load_Flash_OpCode,
               tflite::ops::micro::xcore::Register_LoadFromFlash());

}
