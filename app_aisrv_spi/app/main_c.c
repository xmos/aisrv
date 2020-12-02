// Copyright (c) 2020, XMOS Ltd, All rights reserved
#include <stdio.h>
#include <string.h>
#include <stdio.h>

#include "inference_engine.h"
#include "aisrv.h"

int input_size;
unsigned char *input_buffer;
int output_size;
unsigned char *output_buffer;
unsigned int *output_times;
unsigned int output_times_size;

// TODO rm this wrapper
int interp_init() 
{
    int error = interp_initialize(&input_buffer, &input_size, &output_buffer, &output_size, &output_times, &output_times_size);
    
    return error;
}
