// Copyright (c) 2020, XMOS Ltd, All rights reserved
#include <stdio.h>
#include <string.h>
#include <stdio.h>

#include "inference_engine.h"

static int input_bytes = 0;
static int input_size;
static unsigned char *input_buffer;
static int output_size;
static unsigned char *output_buffer;

// TODO rm me
void print_output() {
  for (int i = 0; i < output_size; i++) {
    printf("Output index=%u, value=%i\n", i, (signed char)output_buffer[i]);
  }
  printf("DONE!\n");
}

// TODO rm this wrapper
void interp_init() 
{
  interp_initialize(&input_buffer, &input_size, &output_buffer, &output_size);

  printf("input size: %d\n", input_size);
}

int buffer_input_data(void *data, size_t size) 
{
    int full = 0;
    
    memcpy(input_buffer + input_bytes, data, size /*- 1*/);
    input_bytes += size;// - 1;
    

    printf("input bytes: %d of %d\n", input_bytes, input_size);
    if (input_bytes == input_size) 
    {
        
        input_bytes = 0;
        full = 1;
    }

    return full;
}
