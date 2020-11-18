#include <stdint.h>
#include <stdio.h>
#include <platform.h>
#include "spitest.h"
#include "spi.h"
#include "inference_engine.h"

#define SIXTEEN_CLOCKS   0xAAAAAAAA

on tile[0]:  out port p_cs_m = XS1_PORT_1E;
on tile[0]:  out buffered port:32 p_clk_m = XS1_PORT_1F;
on tile[0]:  out buffered port:32 p_mosi_m = XS1_PORT_1G;
on tile[0]:  in buffered port:32 p_miso_m = XS1_PORT_1H;
on tile[0]:  clock p_clkblk_m = XS1_CLKBLK_3;

on tile[0]:  in port p_cs_s = XS1_PORT_1I;
on tile[0]:  in port p_clk_s = XS1_PORT_1J;
on tile[0]:  buffered port:32 p_mosi_s = XS1_PORT_1K;
on tile[0]:  buffered port:32 p_miso_s = XS1_PORT_1L;
on tile[0]:  clock p_clkblk_s = XS1_CLKBLK_4;

#if defined(PSOC_INTEGRATION)
on tile[1]: in port p1_cs_s = XS1_PORT_1A;
on tile[1]: in port p1_clk_s = XS1_PORT_1B;
on tile[1]: buffered port:32  p1_mosi_s = XS1_PORT_1C;
on tile[1]: buffered port:32 p1_miso_s = XS1_PORT_1N;
on tile[1]: out port reset1 = XS1_PORT_4A;
on tile[1]: clock p1_clkblk_s = XS1_CLKBLK_4;
#endif

static void spi_read_command(out port p_cs, out buffered port:32 p_clk,
                      in buffered port:32 p_miso,
                      out buffered port:32 p_mosi,
                      clock clkblk,
                      int command, uint32_t data[], int len) {
    p_cs <: 0;

    partout(p_mosi, 8, command);
    partout(p_clk, 16, SIXTEEN_CLOCKS);

    for(int i = 0; i < DUMMY_CLOCKS; i+=16) {
        p_clk <: SIXTEEN_CLOCKS;
    }
    p_clk <: (SIXTEEN_CLOCKS & 3) | 0xFFFFFFFC;
    sync(p_clk);
    clearbuf(p_miso);
    p_clk <: SIXTEEN_CLOCKS;
    for(int i = 0; i < len - 1; i++) {
        p_clk <: SIXTEEN_CLOCKS;
        p_clk <: SIXTEEN_CLOCKS;
        p_miso :> data[i];
    }
    p_clk <: SIXTEEN_CLOCKS;
    p_miso :> data[len-1];

    int clk;
    p_cs <: 1 @ clk;
    p_cs @ (clk+40) <: 1;
}

static void spi_write_command(out port p_cs, out buffered port:32 p_clk,
                      out buffered port:32 p_data, clock clkblk,
                      int command, uint32_t data[], int len) {
    p_cs <: 0;
    partout(p_data, 8, command);
    partout(p_clk, 16, SIXTEEN_CLOCKS);

    if (len != 0) {
        for(int i = 0; i < len; i++) {
            p_data <: data[i];
            p_clk <: SIXTEEN_CLOCKS;
            p_clk <: SIXTEEN_CLOCKS;
        }
    }
    sync(p_clk);
    
    int clk;
    p_cs <: 1 @ clk;
    p_cs @ (clk+40) <: 1;
}

static void spi_master_test(out port p_cs, out buffered port:32 p_clk,
                      in buffered port:32 p_miso,
                      out buffered port:32 p_mosi,
                      clock clkblk) {
    uint32_t id[1];
    uint32_t data[1];
    uint32_t tensor[13] = {1,2,3,4,5,6,7,8,9,100,11,12,13};
    uint32_t itensor[13] = {0};
    int tick;
    p_clk <: ~0;
    p_cs <: 1 @ tick;
    p_cs @ (tick + 100) <: 1;
    configure_clock_src(clkblk, p_clk);
    start_clock(clkblk);
    set_port_clock(p_miso, clkblk);
    set_port_clock(p_mosi, clkblk);
    spi_read_command(p_cs, p_clk, p_miso, p_mosi, clkblk, INFERENCE_ENGINE_READ_ID, id, 1);
    spi_write_command(p_cs, p_clk, p_mosi, clkblk, INFERENCE_ENGINE_WRITE_TENSOR, tensor, 13);
    spi_read_command(p_cs, p_clk, p_miso, p_mosi, clkblk, INFERENCE_ENGINE_READ_TENSOR, itensor, 13);
    for(int i = 0; i < 13; i++) {
        if(tensor[i] != itensor[i]) {
            printf("%d %08x %08x\n", i, tensor[i], itensor[i]);
        }
    }
    spi_write_command(p_cs, p_clk, p_mosi, clkblk, INFERENCE_ENGINE_ACQUIRE, data, 0);
    spi_write_command(p_cs, p_clk, p_mosi, clkblk, INFERENCE_ENGINE_EXIT, data, 0);
    printf("SPI: %08x\n", id[0]);
}

void spi_main(chanend led) {
    par {
        spi_master_test(p_cs_m, p_clk_m, p_miso_m, p_mosi_m, p_clkblk_m);
        spi_xcore_ai_slave(p_cs_s, p_clk_s, p_miso_s, p_mosi_s, p_clkblk_s, led);
    }
}

void spi_remote_test(chanend led) {
#if defined(PSOC_INTEGRATION)
    reset1 <: 0;
    spi_xcore_ai_slave(p1_cs_s, p1_clk_s, p1_miso_s, p1_mosi_s, p1_clkblk_s, led);
#endif
}
