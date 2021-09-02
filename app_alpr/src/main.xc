// Copyright (c) 2020, XMOS Ltd, All rights reserved

#include <platform.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <xscope.h>
#include <xclib.h>
#include <stdint.h>
#include "spi.h"
#include "spibuffer.h"
#include "aiengine.h"
#include "aisrv.h"
#include "inference_engine.h"
#include "server_memory.h"
#include "leds.h"
#include "box_calculation.h"

#include "aisrv_mipi.h"

#ifdef ENABLE_USB
#include "xud.h"

#define EP_COUNT_OUT 2
#define EP_COUNT_IN 2

XUD_EpType epTypeTableOut[EP_COUNT_OUT] = {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};
XUD_EpType epTypeTableIn[EP_COUNT_IN] =   {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};
#endif

#if defined(PSOC_INTEGRATION)
on tile[1]: in port p_cs_s = XS1_PORT_1A;//DAC_DATA
on tile[1]: in port p_clk_s = XS1_PORT_1B;//LRCLK
on tile[1]: buffered port:32  p_mosi_s = XS1_PORT_1C; //BCLK
on tile[1]: buffered port:32 p_miso_s = XS1_PORT_1P;
on tile[1]: out port reset1 = XS1_PORT_4A;
on tile[1]: clock clkblk_s = XS1_CLKBLK_4;
#endif

#if defined(I2C_INTEGRATION)
on tile[0]: port p_scl = XS1_PORT_1N;
on tile[0]: port p_sda = XS1_PORT_1O;
#endif

extern size_t receive_array_(chanend c, uint32_t * unsafe array, unsigned ignore);

void director(chanend to_0, chanend to_1) {
    uint32_t classes[2*MAX_BOXES / sizeof(uint32_t)];
    uint32_t boxes[4*MAX_BOXES / sizeof(uint32_t)];
    uint32_t bbox[4];
    
    while(1) {
        int status;
        timer tmr; int t0;
        tmr :> t0;
        tmr when timerafter(t0+200000000) :> void;
        to_0 <: CMD_GET_OUTPUT_TENSOR;
        to_0 <: 0;
    to_0 :> status;
        if (status != AISRV_STATUS_OKAY) {
            printstr("** err ");
            printintln(status);
            continue;
        }
        unsafe {
            receive_array_(to_0, (uint32_t * unsafe) classes, 0);
        }

        to_0 <: CMD_GET_OUTPUT_TENSOR;
        to_0 <: 1;
    to_0 :> int _;
        unsafe {
            receive_array_(to_0, (uint32_t * unsafe) boxes, 0);
        }

        box_calculation(bbox, (classes, int8_t[]), (boxes, int8_t[]));

        for(int i = 0 ; i < 4; i++) {
            printint(bbox[i]);
            printchar(' ');
        }
        printchar('\n');
    }
}

int main(void) 
{
    chan c_usb_to_engine[2], c_director_to_engine_0, c_director_to_engine_1;
    chan c_usb_ep0_dat;
    chan c_acquire;

#if defined(I2C_INTEGRATION)
    i2c_master_if i2c[1];
#endif

#ifdef ENABLE_USB
    chan c_ep_out[EP_COUNT_OUT], c_ep_in[EP_COUNT_IN];
#endif

    par 
    {

        on tile[0]: {
            inference_engine_t ie;
            unsafe { inference_engine_initialize_with_memory_1(&ie); }
            aiengine(ie, c_usb_to_engine[1], c_director_to_engine_1, null, c_acquire, null);
        } 

        on tile[1]: {
            inference_engine_t ie;
            unsafe { inference_engine_initialize_with_memory_0(&ie); }
            aiengine(ie, c_usb_to_engine[0], c_director_to_engine_0, null, null, null);
        }

        on tile[1]: {
            director(c_director_to_engine_0, c_director_to_engine_1);
        }
#if defined(I2C_INTEGRATION)
        on tile[0]: i2c_master(i2c, 1, p_scl, p_sda, 400);
#endif
#if defined(MIPI_INTEGRATION)
        on tile[1]: mipi_main(i2c[0], c_acquire);
#endif

#if defined(PSOC_INTEGRATION)
        on tile[1]: {
            unsafe {
                struct memory memory;
                struct memory * unsafe mem = & memory;
                mem->status[0] = 0x00000080;
                mem->input_tensor_index = 0;
                mem->input_tensor_length = 0;
                mem->output_tensor_index = 0;
                mem->output_tensor_length = 0;
                mem->timings_index = 10;  // TODO FIXME this hardcored value needs to relate to model 
                mem->timings_length = 31; // TODO FIXME as above
                mem->model_index = 0;
                mem->debug_log_index = 134; // TODO FIXME
                mem->debug_log_length = (MAX_DEBUG_LOG_LENGTH * MAX_DEBUG_LOG_ENTRIES);
                mem->ai_server_id[0] = INFERENCE_ENGINE_ID;
                reset1 <: 0;
                par {
                    spi_xcore_ai_slave(p_cs_s, p_clk_s,
                                       p_miso_s, p_mosi_s,
                                       clkblk_s, c_led, c_spi_to_buffer,
                                       mem);
                    spi_buffer(c_spi_to_buffer, c_spi_to_engine,
                               c_acquire_to_buffer, mem);
                }
            }
        }
#endif

#ifdef ENABLE_USB
        on USB_TILE : 
        {
            par
            {
                aisrv_usb_data(c_ep_out[1], c_ep_in[1], c_usb_to_engine, c_usb_ep0_dat);
                aisrv_usb_ep0(c_ep_out[0], c_ep_in[0], c_usb_ep0_dat);
                XUD_Main(c_ep_out, EP_COUNT_OUT, c_ep_in, EP_COUNT_IN, null, epTypeTableOut, epTypeTableIn, XUD_SPEED_HS, XUD_PWR_BUS);
            
            }
        }
#endif

    }
    return 0;
}
