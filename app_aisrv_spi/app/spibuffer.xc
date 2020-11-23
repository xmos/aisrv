#include <stdio.h>
#include <stdint.h>
#include "inference_commands.h"
#include "shared_memory.h"
#include "spibuffer.h"

void spi_buffer(chanend from_spi, chanend to_engine, chanend to_sensor, struct memory * unsafe mem) {
    int running = 1;
    unsafe {
    while(running) {
        int cmd;
        from_spi :> cmd;
        mem->status[0] |= STATUS_BUSY;
        switch(cmd) {
        case INFERENCE_ENGINE_READ_TENSOR:
            to_engine <: cmd;
            master {
                to_engine <: mem->output_tensor_length;
                for(int i = 0; i < mem->output_tensor_length; i++) {
                    unsafe {
                    to_engine :> mem->memory[mem->output_tensor_index + i];
                    }
                }
            }
            break;
        case INFERENCE_ENGINE_WRITE_MODEL:
            to_engine <: cmd;
            master {
                int N;
                to_engine :> N;
                for(int i = 0; i < N; i++) {
                    to_engine <: mem->memory[i];
                }
            }
            break;
        case INFERENCE_ENGINE_WRITE_TENSOR:
            to_engine <: cmd;
            master {
                to_engine <: mem->input_tensor_length;
                for(int i = 0; i < mem->output_tensor_length; i++) {
                    to_engine <: mem->memory[mem->input_tensor_index + i];
                }
            }
            break;
        case INFERENCE_ENGINE_INFERENCE:
            to_engine <: INFERENCE_ENGINE_INFERENCE;
            to_engine <: INFERENCE_ENGINE_READ_TENSOR;
            master {
                to_engine <: mem->output_tensor_length;
                for(int i = 0; i < 4*mem->output_tensor_length; i++) {
                to_engine :> (mem->memory, uint8_t[])[mem->output_tensor_index + i];
                }
            }
            to_engine <: INFERENCE_ENGINE_READ_TIMINGS;
            master {
                to_engine <: mem->timings_length;
                for(int i = 0; i < mem->timings_length; i++) {
                    unsafe {
                    to_engine :> mem->memory[mem->timings_index + i];
                    }
                }
            }
            break;
        case INFERENCE_ENGINE_WRITE_SERVER:
            // DFU
            break;
        case INFERENCE_ENGINE_ACQUIRE:
            to_sensor <: cmd;
            to_engine <: INFERENCE_ENGINE_WRITE_TENSOR;
            master {
                to_sensor <: mem->input_tensor_length;
                for(int i = 0; i < mem->input_tensor_length; i++) {
                    to_sensor :> mem->memory[i];
                }
            }
            master {
                to_engine <: mem->input_tensor_length;
                for(int i = 0; i < mem->input_tensor_length; i++) {
                    to_engine <: mem->memory[i];
                }
            }
            break;
        case INFERENCE_ENGINE_EXIT:
            running = 0;
            break;
        }
            mem->status[0] &= ~STATUS_BUSY;
    }
}
}
