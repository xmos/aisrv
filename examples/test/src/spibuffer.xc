#include <stdio.h>
#include <stdint.h>
#include "spibuffer.h"
#include "inference_engine.h"
#include "shared_memory.h"

void spi_buffer(chanend from_spi, chanend to_engine, chanend to_sensor, unsafe struct memory shared) {
    int running = 1;
    while(running) {
        int cmd;
        from_spi :> cmd;
        shared.status |= STATUS_BUSY;
        switch(x) {
        case INFERENCE_ENGINE_READ_TENSOR:
            to_engine <: cmd;
            master {
                to_engine <: shared.output_tensor_length;
                for(int i = 0; i < shared.output_tensor_length; i++) {
                    unsafe {
                    to_engine :> shared->memory[shared.output_tensor_index + i];
                    }
                }
            }
            break;
        case INFERENCE_ENGINE_WRITE_MODEL:
            to_engine <: cmd;
            master {
                to_engine <: N;
                for(int i = 0; i < N; i++) {
                    unsafe {
                    to_engine <: shared->memory[i];
                    }
                }
            }
            break;
        case INFERENCE_ENGINE_WRITE_TENSOR:
            to_engine <: cmd;
            master {
                to_engine <: shared.input_tensor_length;
                for(int i = 0; i < shared.output_tensor_length; i++) {
                    unsafe {
                    to_engine <: shared->memory[shared.input_tensor_index + i];
                    }
                }
            }
            break;
        case INFERENCE_ENGINE_INFERENCE:
            to_engine <: INFERENCE_ENGINE_INFERENCE;
            to_engine <: INFERENCE_ENGINE_READ_TENSOR;
            master {
                to_engine <: shared.output_tensor_length;
                for(int i = 0; i < shared.output_tensor_length; i++) {
                    unsafe {
                    to_engine :> shared->memory[shared.output_tensor_index + i];
                    }
                }
            }
            to_engine <: INFERENCE_ENGINE_READ_TIMINGS;
            master {
                to_engine <: shared.timings_length;
                for(int i = 0; i < shared.timings_length; i++) {
                    unsafe {
                    to_engine :> shared->memory[shared.timings_index + i];
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
                to_sensor <: N;
                to_engine <: N;
                for(int i = 0; i < N; i++) {
                    unsafe {
                    to_sensor :> shared->memory[i];
                    to_engine <: shared->memory[i];
                    }
                }
            }
            break;
        case INFERENCE_ENGINE_EXIT:
            running = 0;
            break;
        }
        shared->status &= ~STATUS_BUSY;
    }
}
