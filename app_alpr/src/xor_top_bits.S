// Copyright 2020-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#if defined(__XS3A__)

#define FUNCTION_NAME xor_top_bits

    .cc_top xor_top_bits.function,xor_top_bits
    .text

    .issue_mode  dual


#define NSTACKWORDS  0

    // r0: outp
    // r1: line
    // r2: coefficients
    // r3: strides
    // r4: ox
    // r5: indexc
        
    .globl FUNCTION_NAME
    .align 16
    .type FUNCTION_NAME,@function

FUNCTION_NAME:
    {dualentsp NSTACKWORDS; nop}
    { ldc r3, 3             ; shl r2, r2, 1 }
    not r3, r3
    and r2, r2, r3
    add r0, r0, r2
    ldc r3, 0x8080
    shl r2, r3, 16
    xor r2, r2, r3

xorloop:    
    ldw r11, r0[0]
    xor r11, r11, r2
    { stw r11, r0[0]              ; add r0, r0, 4 }
    { bt r1, xorloop              ; sub r1, r1, 1 }
    retsp NSTACKWORDS

    .set FUNCTION_NAME.nstackwords,NSTACKWORDS
    .globl FUNCTION_NAME.nstackwords
    .set FUNCTION_NAME.maxcores,1
    .globl FUNCTION_NAME.maxcores
    .set FUNCTION_NAME.maxtimers,0
    .globl FUNCTION_NAME.maxtimers
    .set FUNCTION_NAME.maxchanends,0
    .globl FUNCTION_NAME.maxchanends
.Ltmp0:
    .size FUNCTION_NAME, .Ltmp0-FUNCTION_NAME
    .cc_bottom xor_top_bits.function

#endif


