#include <platform.h>
#include <stdio.h>
#include <xclib.h>
#include <stdint.h>
#include <stdlib.h>
#include <print.h>
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
                           uint32_t words[], uint32_t index, int32_t n) {
    uint32_t word = words[index++];
    word = byterev(bitrev(word));
    p_data @ (cycle+1) <: word;
    while (--n > 0) {
        word = words[index];
        word = byterev(bitrev(word));
        p_data <: word;
        index++;
    }
    sync(p_data);      // Wait for final clock of data to go.
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
            words[index] = byterev(bitrev(words[index]));
            index++;
            break;
        }
        if (cs_low == 0) { // todo: this should not be necessary
            for(int i = 0; i < 10; i++) {
                int yy;
                p_cs :> yy;
                if (yy == 0) {
                    cs_low = 1;
                    break;
                }
            }
        }
    }
    return index - oindex;
}

void spi_xcore_ai_slave(in port p_cs, in port p_clk,
                        buffered port:32 ?p_miso,
                        buffered port:32 p_data,
                        clock clkblk,
                        chanend led,
                        chanend c_to_buffer,
                        struct memory * unsafe mem) {
    uint32_t running = 1;
    int cycle;
    int cnt = 0;
    printf("Ready\n");
    set_port_pull_up(p_cs);
    set_port_pull_down(p_clk);
    p_cs when pinseq(1) :> void;
//    p_cs :> int _;
    p_clk when pinseq(0) :> void;
    p_miso <: 0x0FF00FF0;
    sync(p_miso);
    configure_clock_src(clkblk, p_clk);
    if (!isnull(p_miso)) {
        set_port_clock(p_miso, clkblk);
    }
    set_port_clock(p_data, clkblk);
    start_clock(clkblk);
    clearbuf(p_data);
    unsafe {
        uint32_t lastcmd;
    while (running) {
        uint32_t cmd;
        int data, bytes;
        clearbuf(p_data);
        asm("setpsc res[%0], %1" :: "r" (p_data) , "r" (8));
        p_cs when pinsneq(1) :> void;
//        p_cs :> int _;
        p_data :> cmd @ cycle;
        //cmd >>= 24;
        cmd = bitrev(cmd) & 0xff;

        switch(cmd) {
        case INFERENCE_ENGINE_READ_STATUS:
            data_words_out(isnull(p_miso) ? p_data : p_miso,
                           cycle + DUMMY_CLOCKS,
                           mem->status, 0, 1);
            (mem->status, uint8_t[])[STATUS_BYTE_ERROR] = 0;
            break;
        case INFERENCE_ENGINE_READ_ID:
            data_words_out(isnull(p_miso) ? p_data : p_miso,
                           cycle + DUMMY_CLOCKS,
                           mem->ai_server_id, 0, 1);
            break;
        case INFERENCE_ENGINE_READ_SPEC:
            data_words_out(isnull(p_miso) ? p_data : p_miso,
                           cycle + DUMMY_CLOCKS,
                           mem->spec, 0, 5);
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
            bytes = 4*data_word_in(p_data, p_cs, mem->memory, mem->model_index);
            c_to_buffer <: cmd;
            c_to_buffer <: bytes;
            break;
        case INFERENCE_ENGINE_WRITE_SERVER:
            bytes = data_word_in(p_data, p_cs, mem->memory, 0);
            break;
        case INFERENCE_ENGINE_WRITE_TENSOR:
            bytes = 4*data_word_in(p_data, p_cs, mem->memory, mem->input_tensor_index);
            c_to_buffer <: cmd;
            c_to_buffer <: bytes;
            break;
        case INFERENCE_ENGINE_INFERENCE:
            c_to_buffer <: cmd;
            break;
        case INFERENCE_ENGINE_ACQUIRE:
            c_to_buffer <: cmd;
            break;
        case INFERENCE_ENGINE_EXIT:
            c_to_buffer <: cmd;
            running = 0;
            break;
        case INFERENCE_ENGINE_HELLO:
        case INFERENCE_ENGINE_HELLO*2:
        case INFERENCE_ENGINE_HELLO*2+1:
            break;
        default:
            (mem->status, uint8_t[])[STATUS_BYTE_ERROR] = STATUS_ERROR;
            printf("ERR %02x last proper comand %02x [%d]\n", cmd, lastcmd, mem->output_tensor_length);
            break;
        }
        lastcmd = cmd;
//        printintln(cmd);
//        printf("Dispatched: %08x\n", cmd);
//        led <: cmd;
        p_cs when pinsneq(0) :> void;
        if (isnull(p_miso)) {
            reset_port(p_data, clkblk);
        }
    }
    }
}
