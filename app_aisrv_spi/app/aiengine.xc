#include <stdio.h>
#include <stdint.h>
#include "aiengine.h"
#include "inference_commands.h"
#include "inference_engine.h"


extern int output_size;

extern "C" 
{
    int interp_init();
    void print_output(); 
    extern unsigned char model_data[MAX_MODEL_SIZE_BYTES];
    extern unsigned char * unsafe output_buffer;
    extern unsigned char * unsafe input_buffer;
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
                    (model_data, uint32_t[])[model_offset] = data;
                    model_offset ++;
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
                    unsafe {((uint32_t *)input_buffer)[input_tensor_offset] = data;}
                    input_tensor_offset ++;
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


