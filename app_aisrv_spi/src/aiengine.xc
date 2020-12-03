#include <stdio.h>
#include <stdint.h>
#include "aiengine.h"
#include "aisrv.h"
#include "inference_engine.h"


#if 0
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
#endif

static inference_engine_t ie;

void aiengine(chanend x) {
    int model_offset = 0;
    int input_tensor_offset = 0;
    uint32_t status = 0;
    unsafe { inference_engine_initialize(&ie); }
    while(1) {
        int cmd, N;
        x :> cmd;
        switch(cmd) {
        case CMD_GET_SPEC:
            slave {
                uint32_t spec[SPEC_MODEL_TOTAL];
                spec[SPEC_WORD_0] = 0;
                spec[SPEC_WORD_1] = 0;
                spec[SPEC_INPUT_TENSOR_LENGTH] = ie.input_size;
                spec[SPEC_OUTPUT_TENSOR_LENGTH] = ie.output_size;
                spec[SPEC_TIMINGS_LENGTH] = ie.output_times_size;
                for(int i = 0; i < SPEC_MODEL_TOTAL; i++) {
                    x <: spec[i];
                }
            }
            break;
        case CMD_GET_TENSOR:
            slave {
                x :> N;
                for(int i = 0; i < 4*N; i++) {
                    unsafe {
                        x <: ie.output_buffer[i];
                    }
                }
            }
            break;
        case CMD_GET_TIMINGS:
            slave {
                x :> N;
                for(int i = 0; i < N; i++) {
                    unsafe {
                        x <: ie.output_times[i];
                    }
                }
            }
            break;
        case CMD_SET_MODEL:
            slave {
                x :> N;
                for(int i = 0; i < N; i++) {
                    uint32_t data;
                    x :> data;
                    ((uint32_t *)ie.model_data)[model_offset] = data;
                    model_offset ++;
                }
            }
            if (N != 64) {
                unsafe {
                    status = interp_initialize(&ie);
                }
                printf("Model inited\n");
                model_offset = 0;
            }
            // TODO: signal success/error to other side.
//            c <: status;

            break;
        case CMD_SET_TENSOR:
            slave {
                x :> N;
                for(int i = 0; i < N; i++) {
                    uint32_t data;
                    x :> data;
                    unsafe {((uint32_t *)ie.input_buffer)[input_tensor_offset] = data;}
                    input_tensor_offset ++;
                }
            }
            if (N != 256/4) {
                input_tensor_offset = 0;
            }
            break;
        case CMD_START_INFER:
            uint32_t status = interp_invoke();
            break;
        }
    }
}


