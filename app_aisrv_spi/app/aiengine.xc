#include <stdio.h>
#include <stdint.h>
#include "aiengine.h"
#include "inference_commands.h"
#include "inference_engine.h"


extern int output_size;

extern "C" 
{
    int interp_init();
    int buffer_input_data(void *data, int offset, size_t size);
    void print_output(); 
    extern unsigned char * unsafe output_buffer;
    void write_model_data(int i, unsigned char x);
    extern int input_size;
    extern int output_size;
    extern unsigned int output_times_size;
    extern unsigned int *output_times;
}

void aiengine(chanend x) {
    int running = 1;
    int model_offset = 0;
    int input_tensor_offset = 0;
    uint32_t status = 0;
    while(running) {
        int cmd, N;
        x :> cmd;
        switch(cmd) {
        case INFERENCE_ENGINE_READ_SPEC:
            slave {
                x <: 0x0;
                x <: 0x0;
                x <: input_size;
                x <: output_size;
                x <: output_times_size;
            }
            break;
        case INFERENCE_ENGINE_READ_TENSOR:
            slave {
                x :> N;
                for(int i = 0; i < 4*N; i++) {
                    unsafe {
                        x <: output_buffer[i];
                    }
                }
            }
            break;
        case INFERENCE_ENGINE_READ_TIMINGS:
            slave {
                x :> N;
                for(int i = 0; i < N; i++) {
                    unsafe {
                        x <: output_times[i];
                    }
                }
            }
            break;
        case INFERENCE_ENGINE_WRITE_MODEL:
            slave {
                x :> N;
                for(int i = 0; i < N; i++) {
                    uint32_t data;
                    x :> data;
                    // TODO: remove this wrapper, and just dump words!
                    write_model_data(model_offset,  (data >>  0) & 0xff); 
                    write_model_data(model_offset+1,(data >>  8) & 0xff); 
                    write_model_data(model_offset+2,(data >> 16) & 0xff); 
                    write_model_data(model_offset+3,(data >> 24) & 0xff);
                    model_offset += 4;
                }
            }
            if (N != 64) {
                status = interp_init();
                printf("Model inited\n");
                model_offset = 0;
            }
            // TODO: signal success/error to other side.
//            c <: status;

            break;
        case INFERENCE_ENGINE_WRITE_TENSOR:
            slave {
                x :> N;
                for(int i = 0; i < N; i++) {
                    uint32_t data;
                    x :> data;
                    buffer_input_data(&data, input_tensor_offset, 4);
                    input_tensor_offset += 4;
                }
            }
            if (N != 256/4) {
                input_tensor_offset = 0;
            }
            break;
        case INFERENCE_ENGINE_INFERENCE:
            uint32_t status = interp_invoke();
            break;
        case INFERENCE_ENGINE_EXIT:
            running = 0;
            break;
        }
    }
}


