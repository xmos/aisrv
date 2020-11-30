#include <xs1.h>
#include <stdio.h>
#include <stdint.h>
#include "inference_commands.h"
#include "shared_memory.h"
#include "spibuffer.h"

static void read_spec(chanend to_engine, struct memory * unsafe mem) {
    to_engine <: INFERENCE_ENGINE_READ_SPEC;
    unsafe {
        master {
            to_engine :> mem->spec[0];
            to_engine :> mem->spec[1];
            to_engine :> mem->spec[2];
            to_engine :> mem->spec[3];
            to_engine :> mem->spec[4];
        }
        mem->input_tensor_length = (mem->spec[2]+3) / 4;
        mem->output_tensor_length = (mem->spec[3]+3) / 4;
        mem->timings_length = mem->spec[4];
    }
}

static inline void set_mem_status(uint32_t status[1], uint32_t byte, uint32_t val) {
    asm volatile("st8 %0, %1[%2]" :: "r" (val), "r" (status), "r" (byte));
}
//         = STATUS_NORMAL;

void spi_buffer(chanend from_spi, chanend to_engine, chanend to_sensor, struct memory * unsafe mem) {
    int running = 1;
    unsafe {
    while(running) {
        int cmd;
        int N;
        set_mem_status(mem->status, STATUS_BYTE_STATUS, STATUS_NORMAL);
        from_spi :> cmd;
        set_mem_status(mem->status, STATUS_BYTE_STATUS, STATUS_NORMAL | STATUS_BUSY);
        switch(cmd) {
        case INFERENCE_ENGINE_WRITE_MODEL:
            from_spi :> N;
            to_engine <: cmd;
            master {
                to_engine <: N/4;
                for(int i = 0; i < N/4; i++) {
                    to_engine <: mem->memory[i];
                }
            }
            if (N != 256) {
                read_spec(to_engine, mem);
            }
            break;
        case INFERENCE_ENGINE_WRITE_TENSOR:
            from_spi :> N;
            to_engine <: cmd;
            master {
                to_engine <: N/4;
                for(int i = 0; i < N/4; i++) {
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
    }
}
}
