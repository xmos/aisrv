// Copyright (c) 2020, XMOS Ltd, All rights reserved



#include <platform.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <xscope.h>
#include <xclib.h>
#include <stdint.h>
#include "acquire.h"
#include "spi.h"
#include "spibuffer.h"
#include "aiengine.h"

on tile[0]: port p_led = XS1_PORT_4C;

void leds(chanend led) {
    while(1) {
        int x;
        led :> x;
        if (x == -1) {
            break;
        }
        p_led <: x;
    }
}

#define PSOC_INTEGRATION

#if defined(PSOC_INTEGRATION)
on tile[1]: in port p_cs_s = XS1_PORT_1A;
on tile[1]: in port p_clk_s = XS1_PORT_1B;
on tile[1]: buffered port:32  p_mosi_s = XS1_PORT_1C;
on tile[1]: buffered port:32 p_miso_s = XS1_PORT_1N;
on tile[1]: out port reset1 = XS1_PORT_4A;
on tile[1]: clock clkblk_s = XS1_CLKBLK_4;
#endif

int main(void) {
    chan c_led, c_spi_to_buffer, c_buffer_to_engine, c_acquire_to_buffer;
    par {
#if defined(PSOC_INTEGRATION)
        on tile[0]: {
            aiengine(c_buffer_to_engine);
        }
        on tile[0]: {
            leds(c_led);
        }
        on tile[1]: {
            unsafe {
                struct memory memory;
                struct memory * unsafe mem = & memory;
                par {
                    spi_xcore_ai_slave(p_cs_s, p_clk_s,
                                       p_miso_s, p_mosi_s,
                                       clkblk_s, c_led, c_spi_to_buffer,
                                       mem);
                    spi_buffer(c_spi_to_buffer, c_buffer_to_engine,
                               c_acquire_to_buffer, mem);
                    acquire(c_acquire_to_buffer, mem);
                }
            }
        }
#else
        {
            spi_main(c_led);
            qpi_main(c_led);
            c_led <: -1;
        }
        leds(c_led);
#endif
    }
    return 0;
}
