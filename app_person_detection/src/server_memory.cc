// Copyright (c) 2021, XMOS Ltd, All rights reserved
#include "aisrv.h"
#include <cstddef>
#include <cstdint>
#include <cstdio>

#include "inference_engine.h"
#include "server_memory.h"

#if !defined(TFLM_DISABLED)

#define TENSOR_ARENA_0_BYTES          (396000) // should be 396000
#define TENSOR_ARENA_1_BYTES          (396000) // should be 379000
uint32_t data_0[TENSOR_ARENA_0_BYTES/sizeof(int)];
uint32_t data_1[TENSOR_ARENA_1_BYTES/sizeof(int)];
#endif

void inference_engine_0_initialize_with_memory(inference_engine_t *ie) {
#if !defined(TFLM_DISABLED)
    static struct tflite_micro_objects s0;
    auto *resolver = inference_engine_initialize(ie,
                                                 data_0, TENSOR_ARENA_0_BYTES,
                                                 nullptr,  0,
                                                 &s0);
    resolver->AddCustom(tflite::ops::micro::xcore::Add_8_OpCode, // Both halves
                        tflite::ops::micro::xcore::Register_Add_8()); 

    resolver->AddCustom(tflite::ops::micro::xcore::MaxPool2D_OpCode, // Both halves
                        tflite::ops::micro::xcore::Register_MaxPool2D());

    resolver->AddCustom(tflite::ops::micro::xcore::Conv2D_Shallow_OpCode, // First half
                        tflite::ops::micro::xcore::Register_Conv2D_Shallow());

    resolver->AddCustom(tflite::ops::micro::xcore::Conv2D_Depthwise_OpCode, // Both halves
                        tflite::ops::micro::xcore::Register_Conv2D_Depthwise());

    resolver->AddCustom(tflite::ops::micro::xcore::Conv2D_1x1_OpCode, // Both halves
                        tflite::ops::micro::xcore::Register_Conv2D_1x1());

    resolver->AddCustom(tflite::ops::micro::xcore::Pad_OpCode, // Both halves
                        tflite::ops::micro::xcore::Register_Pad());

    resolver->AddCustom(tflite::ops::micro::xcore::BConv2d_Int8_OpCode, // Both halves
                        tflite::ops::micro::xcore::Register_BConv2D_Int8());

    resolver->AddCustom(tflite::ops::micro::xcore::Bsign_8_OpCode, // Both halves
                        tflite::ops::micro::xcore::Register_BSign_8());

#endif
}

void inference_engine_1_initialize_with_memory(inference_engine_t *ie) {
#if !defined(TFLM_DISABLED)
    static struct tflite_micro_objects s1;
    auto *resolver = inference_engine_initialize(ie,
                                                 data_1, TENSOR_ARENA_1_BYTES,
                                                 nullptr,  0,
                                                 &s1);

    resolver->AddConcatenation(); // Second half
    resolver->AddResizeNearestNeighbor(); // Second half
    resolver->AddDequantize(); // Second half
    resolver->AddReshape(); // Second half
    resolver->AddDetectionPostprocess(); // Second half

    resolver->AddCustom(tflite::ops::micro::xcore::Add_8_OpCode, // Both halves
                        tflite::ops::micro::xcore::Register_Add_8()); 

    resolver->AddCustom(tflite::ops::micro::xcore::MaxPool2D_OpCode, // Both halves
                        tflite::ops::micro::xcore::Register_MaxPool2D());

    resolver->AddCustom(tflite::ops::micro::xcore::Conv2D_Deep_OpCode, // Second half
                        tflite::ops::micro::xcore::Register_Conv2D_Deep());

    resolver->AddCustom(tflite::ops::micro::xcore::Conv2D_Depthwise_OpCode, // Both halves
                        tflite::ops::micro::xcore::Register_Conv2D_Depthwise());

    resolver->AddCustom(tflite::ops::micro::xcore::Conv2D_1x1_OpCode, // Both halves
                        tflite::ops::micro::xcore::Register_Conv2D_1x1());

    resolver->AddCustom(tflite::ops::micro::xcore::Pad_OpCode, // Both halves
                        tflite::ops::micro::xcore::Register_Pad());

    resolver->AddCustom(tflite::ops::micro::xcore::BConv2d_Int8_OpCode, // Both halves
                        tflite::ops::micro::xcore::Register_BConv2D_Int8());

    resolver->AddCustom(tflite::ops::micro::xcore::Bsign_8_OpCode, // Both halves
                        tflite::ops::micro::xcore::Register_BSign_8());

#endif
}
