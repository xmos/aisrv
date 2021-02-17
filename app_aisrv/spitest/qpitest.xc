#include <xs1.h>
#include <stdint.h>
#include <stdio.h>
#include <platform.h>
#include "qpi.h"
#include "spi.h"
#include "inference_engine.h"

#define EIGHT_CLOCKS   0xCCCCCCCC

on tile[0]:  port q_cs_m = XS1_PORT_1A;
on tile[0]:  out buffered port:32 q_clk_m = XS1_PORT_1B;
on tile[0]:  buffered port:32 q_data_m = XS1_PORT_4A;
on tile[0]:  clock q_clkblk_m = XS1_CLKBLK_1;

on tile[0]:  in port q_cs_s = XS1_PORT_1C;
on tile[0]:  in port q_clk_s = XS1_PORT_1D;
on tile[0]:  buffered port:32 q_data_s = XS1_PORT_4B;
on tile[0]:  clock q_clkblk_s = XS1_CLKBLK_2;

void qpi_read_command(port q_cs, out buffered port:32 q_clk,
                      buffered port:32 q_data, clock clkblk,
                      int command, uint32_t data[], int len) {
    q_cs <: 0;

    partout(q_data, 8, command);
    partout(q_clk, 8, EIGHT_CLOCKS);
    sync(q_clk);

    qpi_reset_port(q_data, clkblk);
    for(int i = 0; i < DUMMY_CLOCKS; i+=8) {
        q_clk <: EIGHT_CLOCKS;
    }
    sync(q_clk);
    clearbuf(q_data);
    q_clk <: EIGHT_CLOCKS;
    for(int i = 0; i < len - 1; i++) {
        q_clk <: EIGHT_CLOCKS;
        q_data :> data[i];
    }
    q_data :> data[len-1];
    
    int clk;
    q_cs <: 1 @ clk;
    q_cs @ (clk+40) <: 1;
}

void qpi_write_command(port q_cs, out buffered port:32 q_clk,
                      buffered port:32 q_data, clock clkblk,
                      int command, uint32_t data[], int len) {
    q_cs <: 0;
    partout(q_data, 8, command);
    partout(q_clk, 8, EIGHT_CLOCKS);

    if (len != 0) {
        for(int i = 0; i < len; i++) {
            q_data <: data[i];
            q_clk <: EIGHT_CLOCKS;
        }
    }
    sync(q_clk);
    
    int clk;
    q_cs <: 1 @ clk;
    q_cs @ (clk+40) <: 1;
}

void qpi_master_test( port q_cs, out buffered port:32 q_clk, buffered port:32 q_data, clock clkblk) {
    uint32_t data[1];
    uint32_t id[1];
    uint32_t tensor[13] = {1,2,3,4,5,6,7,8,9,100,11,12,13};
    uint32_t itensor[13] = {0};
    int tick;
    q_clk <: ~0;
    q_cs <: 1 @ tick;
    q_cs @ (tick + 100) <: 1;
    configure_clock_src(clkblk, q_clk);
    start_clock(clkblk);
    set_port_clock(q_data, clkblk);
    qpi_read_command(q_cs, q_clk, q_data, clkblk, INFERENCE_ENGINE_READ_ID, id, 1);
    qpi_write_command(q_cs, q_clk, q_data, clkblk, INFERENCE_ENGINE_WRITE_TENSOR, tensor, 13);
    qpi_read_command(q_cs, q_clk, q_data, clkblk, INFERENCE_ENGINE_READ_TENSOR, itensor, 13);
    for(int i = 0; i < 13; i++) {
        if(tensor[i] != itensor[i]) {
            printf("%d %08x %08x\n", i, tensor[i], itensor[i]);
        }
    }
    qpi_write_command(q_cs, q_clk, q_data, clkblk, INFERENCE_ENGINE_ACQUIRE, data, 0);
    qpi_write_command(q_cs, q_clk, q_data, clkblk, INFERENCE_ENGINE_EXIT, data, 0);
    printf("QPI: %08x\n", id[0]);
}

void qpi_main(chanend c_led) {
#if 0
    par {
        qpi_master_test(q_cs_m, q_clk_m, q_data_m, q_clkblk_m);
        qpi_xcore_ai_slave(q_cs_s, q_clk_s, q_data_s, q_clkblk_s);
    }
#endif
    par {
        qpi_master_test(q_cs_m, q_clk_m, q_data_m, q_clkblk_m);
        spi_xcore_ai_slave(q_cs_s, q_clk_s, null, q_data_s, q_clkblk_s, c_led);
    }
}
