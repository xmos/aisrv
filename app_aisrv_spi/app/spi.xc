#include <platform.h>
#include <stdio.h>
#include <xclib.h>
#include <stdint.h>
#include "spi.h"
#include "inference_commands.h"
#include "shared_memory.h"

static void reset_port(buffered port:32 p_data, clock clkblk) {
    asm volatile ("setc res[%0], 0" :: "r" (p_data));
    asm volatile ("setc res[%0], 8" :: "r" (p_data));
    asm volatile ("setc res[%0], 0x200f" :: "r" (p_data));
    asm volatile ("settw res[%0], %1" :: "r" (p_data), "r" (32));
    asm volatile ("setclk res[%0], %1" :: "r" (p_data), "r" (clkblk));
}

static void data_words_out(out buffered port:32 p_data, int cycle,
                           uint32_t words[], uint32_t index, uint32_t n) {
    uint32_t word = words[index++];
    p_data @ (cycle+1) <: word;
    while (--n > 0) {
        word = words[index++];
        p_data <: word;
    }
}

static uint32_t data_word_in(in buffered port:32 p_data, in port p_cs,
                             uint32_t words[], uint32_t index) {
    int cs_low = 1;
    int oindex = index;
    while(cs_low) {
        select {
        case p_cs when pinseq(1) :> void:
            cs_low = 0;
            break;
        case p_data :> words[index]:
            index++;
            break;
        }
    }
    return index - oindex;
}

void spi_xcore_ai_slave(in port p_cs, in port p_clk,
                        buffered port:32 ?p_miso,
                        buffered port:32 p_data,
                        clock clkblk,
                        chanend led,
                        chanend to_buffer,
                        struct memory * unsafe mem) {
    uint32_t running = 1;
    int cycle;
    p_cs when pinseq(1) :> void;
    configure_clock_src(clkblk, p_clk);
    if (!isnull(p_miso)) {
        set_port_clock(p_miso, clkblk);
    }
    set_port_clock(p_data, clkblk);
    start_clock(clkblk);
    clearbuf(p_data);
    unsafe {
    while (running) {
        uint32_t cmd;
        int data, bytes;
        clearbuf(p_data);
        asm("setpsc res[%0], %1" :: "r" (p_data) , "r" (8));
        p_cs when pinsneq(1) :> void;
        p_data :> cmd @ cycle;
        switch(cmd >> 24) {
        case INFERENCE_ENGINE_READ_STATUS:
            data_words_out(isnull(p_miso) ? p_data : p_miso,
                           cycle + DUMMY_CLOCKS,
                           mem->status, 0, 1);
            mem->status[0] &= ~STATUS_ERROR;
            break;
        case INFERENCE_ENGINE_READ_ID:
            data_words_out(isnull(p_miso) ? p_data : p_miso,
                           cycle + DUMMY_CLOCKS,
                           mem->ai_server_id, 0, 1);
            break;
        case INFERENCE_ENGINE_READ_SPEC:
            data_words_out(isnull(p_miso) ? p_data : p_miso,
                           cycle + DUMMY_CLOCKS,
                           mem->ai_server_spec, 0, 1);
            break;
        case INFERENCE_ENGINE_READ_TIMINGS:
            data_words_out(isnull(p_miso) ? p_data : p_miso,
                           cycle + DUMMY_CLOCKS,
                           mem->memory, mem->timings_index, mem->timings_length);
            break;
        case INFERENCE_ENGINE_READ_TENSOR:
            data_words_out(isnull(p_miso) ? p_data : p_miso,
                           cycle + DUMMY_CLOCKS,
                           mem->memory, mem->output_tensor_index, mem->output_tensor_length);
            break;
        case INFERENCE_ENGINE_WRITE_MODEL:
            bytes = data_word_in(p_data, p_cs, mem->memory, mem->model_index);
            break;
        case INFERENCE_ENGINE_WRITE_SERVER:
            bytes = data_word_in(p_data, p_cs, mem->memory, 0);
            break;
        case INFERENCE_ENGINE_WRITE_TENSOR:
            bytes = data_word_in(p_data, p_cs, mem->memory, mem->input_tensor_index);
            if (bytes != mem->input_tensor_length) {
                mem->status[0] |= STATUS_ERROR;
            }
            break;
        case INFERENCE_ENGINE_INFERENCE:
            break;
        case INFERENCE_ENGINE_ACQUIRE:
            break;
        case INFERENCE_ENGINE_EXIT:
            running = 0;
            break;
        default:
            mem->status[0] |= STATUS_ERROR;
            printf("ERR %08x\n", cmd);
            break;
        }
        led <: cmd;
        p_cs when pinsneq(0) :> void;
        if (isnull(p_miso)) {
            reset_port(p_data, clkblk);
        }
    }
    }
}
