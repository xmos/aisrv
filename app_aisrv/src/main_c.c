// Copyright (c) 2020, XMOS Ltd, All rights reserved
#include <stdio.h>
#include <string.h>
#include <stdio.h>

#include "inference_engine.h"
#include "aisrv.h"

static int input_bytes = 0;
int input_size;
static unsigned char *input_buffer;
int output_size;
unsigned char *output_buffer;

// TODO rm me
void print_output() 
{
    for (int i = 0; i < output_size; i++) 
    {
        printf("Output index=%u, value=%i\n", i, (signed char)output_buffer[i]);
    }
    printf("DONE!\n");
}

// TODO rm this wrapper
int interp_init() 
{
    int error = interp_initialize(&input_buffer, &input_size, &output_buffer, &output_size);
    
    return error;
}

// TODO rm this wrapper
int buffer_input_data(void *data, int offset, size_t size) 
{
    memcpy(input_buffer + offset, data, size);
    return 0;
}

