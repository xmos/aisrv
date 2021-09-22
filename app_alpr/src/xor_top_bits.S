// Copyright 2020-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#if defined(__XS3A__)

#define FUNCTION_NAME xor_top_bits

    .cc_top FUNCTION_NAME.function,FUNCTION_NAME
    .text

    .issue_mode  dual


#define NSTACKWORDS  0

    // r0: in-out array
    // r1: number of pixels (half word)
    // r2: start pixel (half word)
    // r3: tmp
    // r11: tmp
        
    .globl FUNCTION_NAME
    .align 16
    .type FUNCTION_NAME,@function

FUNCTION_NAME:
    {dualentsp NSTACKWORDS ; ldc r3, 7}
    { not r3, r3           ; shl r2, r2, 1 }
    { shr r1, r1, 2        ; add r0, r0, r2 }
    ldc r2, 0x8080
    { and r0, r0, r3       ;  shl r3, r2, 16} // pixels to double words, div 4.
    { or r2, r2, r3        ; sub r1, r1, 1}
xorloop:    
    ldd r11, r3, r0[r1]
    xor r11, r11, r2
    xor r3, r3, r2
    std r11, r3, r0[r1]
    { bt r1, xorloop              ; sub r1, r1, 1 }
    ldd r11, r3, r0[r1]
    xor r11, r11, r2
    xor r3, r3, r2
    std r11, r3, r0[r1]
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
    .cc_bottom FUNCTION_NAME.function

#endif


