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
#include "aisrv.h"
#include "inference_engine.h"

#ifdef ENABLE_USB
#include "xud.h"

#define EP_COUNT_OUT 2
#define EP_COUNT_IN 2

XUD_EpType epTypeTableOut[EP_COUNT_OUT] = {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};
XUD_EpType epTypeTableIn[EP_COUNT_IN] =   {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};
#endif

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

#if defined(PSOC_INTEGRATION)
on tile[1]: in port p_cs_s = XS1_PORT_1A;//DAC_DATA
on tile[1]: in port p_clk_s = XS1_PORT_1B;//LRCLK
on tile[1]: buffered port:32  p_mosi_s = XS1_PORT_1C; //BCLK
on tile[1]: buffered port:32 p_miso_s = XS1_PORT_1N;
on tile[1]: out port reset1 = XS1_PORT_4A;
on tile[1]: clock clkblk_s = XS1_CLKBLK_4;
#endif

#if defined(I2C_REQUIRED)
on tile[0]: port p_scl = XS1_PORT_1N;
on tile[0]: port p_sda = XS1_PORT_1O;
#endif

int main(void) 
{
    chan c_led, c_spi_to_buffer, c_spi_to_engine, c_usb_to_engine, c_acquire_to_buffer;
    chan c_acquire_to_sensor;
#if defined(I2C_INTEGRATION)
    i2c_master_if i2c[1];
#endif

#ifdef ENABLE_USB
    chan c_ep_out[EP_COUNT_OUT], c_ep_in[EP_COUNT_IN];
#endif

    par 
    {
#if defined(I2C_INTEGRATION)
        on tile[0]: i2c_master(i2c, 1, p_scl, p_sda, 400);
#endif
#if defined(MIPI_INTEGRATION)
        on tile[1]: mipi_main(i2c[0], c_acquire_to_sensor);
#endif
        on tile[0]: aiengine(c_spi_to_engine, c_usb_to_engine);
#if defined(PSOC_INTEGRATION)
        on tile[0]: {
            leds(c_led);
        }
        on tile[1]: {
            unsafe {
                struct memory memory;
                struct memory * unsafe mem = & memory;
                mem->status[0] = 0x00000080;
                mem->input_tensor_index = 0;
                mem->input_tensor_length = 0;
                mem->output_tensor_index = 0;
                mem->output_tensor_length = 0;
                mem->timings_index = 10;
                mem->timings_length = 31;
                mem->model_index = 0;
                mem->ai_server_id[0] = INFERENCE_ENGINE_ID;
                reset1 <: 0;
                par {
                    spi_xcore_ai_slave(p_cs_s, p_clk_s,
                                       p_miso_s, p_mosi_s,
                                       clkblk_s, c_led, c_spi_to_buffer,
                                       mem);
                    spi_buffer(c_spi_to_buffer, c_spi_to_engine,
                               c_acquire_to_buffer, mem);
                    acquire(c_acquire_to_buffer, c_acquire_to_sensor, mem);
                }
            }
        }
#endif

#ifdef ENABLE_USB
         on tile[1] : 
        {
          
            par
            {
                aisrv_usb_data(c_ep_out[1], c_ep_in[1], c_usb_to_engine);
                aisrv_usb_ep0(c_ep_out[0], c_ep_in[0]);
                XUD_Main(c_ep_out, EP_COUNT_OUT, c_ep_in, EP_COUNT_IN, null, epTypeTableOut, epTypeTableIn, XUD_SPEED_HS, XUD_PWR_BUS);
            
            }
        }
#endif
    }
    return 0;
}
