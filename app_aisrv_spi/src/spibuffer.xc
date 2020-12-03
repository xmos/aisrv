#include <xs1.h>
#include <stdio.h>
#include <stdint.h>
#include "aisrv.h"
#include "shared_memory.h"
#include "spibuffer.h"

static void read_spec(chanend to_engine, struct memory * unsafe mem) {
    to_engine <: CMD_GET_SPEC;
    unsafe {
        master {
            for(int i = 0; i < SPEC_MODEL_TOTAL; i++) {
                to_engine :> mem->spec[i];
            }
        }
        mem->input_tensor_length = (mem->spec[SPEC_INPUT_TENSOR_LENGTH]+3) / 4;
        mem->output_tensor_length = (mem->spec[SPEC_OUTPUT_TENSOR_LENGTH]+3) / 4;
        mem->timings_length = mem->spec[SPEC_TIMINGS_LENGTH];
        mem->sensor_tensor_length = (mem->spec[SPEC_SENSOR_TENSOR_LENGTH]+3) / 4;
    }
}

static inline void set_mem_status(uint32_t status[1], uint32_t byte, uint32_t val) {
    asm volatile("st8 %0, %1[%2]" :: "r" (val), "r" (status), "r" (byte));
}
//         = STATUS_NORMAL;

void spi_buffer(chanend from_spi, chanend to_engine, chanend to_sensor, struct memory * unsafe mem) {
    unsafe {
    while(1) {
        int cmd;
        int N;
        set_mem_status(mem->status, STATUS_BYTE_STATUS, STATUS_NORMAL);
        from_spi :> cmd;
        set_mem_status(mem->status, STATUS_BYTE_STATUS, STATUS_NORMAL | STATUS_BUSY);
        switch(cmd) {
        case CMD_SET_MODEL:
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
        case CMD_SET_TENSOR:
            from_spi :> N;
            to_engine <: cmd;
            master {
                to_engine <: N/4;
                for(int i = 0; i < N/4; i++) {
                    to_engine <: mem->memory[mem->input_tensor_index + i];
                }
            }
            break;
        case CMD_START_INFER:
            to_engine <: CMD_START_INFER;
            to_engine <: CMD_GET_TENSOR;
            master {
                to_engine <: mem->output_tensor_length;
                for(int i = 0; i < 4*mem->output_tensor_length; i++) {
                to_engine :> (mem->memory, uint8_t[])[mem->output_tensor_index + i];
                }
            }
            to_engine <: CMD_GET_TIMINGS;
            master {
                to_engine <: mem->timings_length;
                for(int i = 0; i < mem->timings_length; i++) {
                    unsafe {
                    to_engine :> mem->memory[mem->timings_index + i];
                    }
                }
            }
            mem->tensor_is_sensor_output = 0;
            break;
        case CMD_SET_SERVER:
            // DFU
            break;
        case CMD_START_ACQUIRE:
            set_mem_status(mem->status, STATUS_BYTE_STATUS, STATUS_NORMAL | STATUS_SENSING | STATUS_BUSY);
            to_sensor <: cmd;
            to_sensor :> int _;
            set_mem_status(mem->status, STATUS_BYTE_STATUS, STATUS_NORMAL | STATUS_BUSY);
            // watch out: <= not < to force a zero block at the end
            for(int block = 0; block <= mem->input_tensor_length; block += 64) {
                to_engine <: CMD_SET_TENSOR;
                master {
                    int len = mem->input_tensor_length - block;
                    if (len > 64) {
                        len = 64;
                    }
                    to_engine <: len;
                    for(int i = 0; i < len; i++) {
                        to_engine <: mem->memory[block+i];
                    }
                }
                mem->tensor_is_sensor_output = 1;
            }
            break;
        }
    }
}
}
