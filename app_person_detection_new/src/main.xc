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

#include "aisrv_mipi.h"
#include "hm0360.h"

#ifdef ENABLE_USB
#include "xud.h"

#define EP_COUNT_OUT 2
#define EP_COUNT_IN 2

XUD_EpType epTypeTableOut[EP_COUNT_OUT] = {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};
XUD_EpType epTypeTableIn[EP_COUNT_IN] =   {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};
#endif

on tile[0]: port p_scl = XS1_PORT_1A;
on tile[0]: port p_sda = XS1_PORT_1D;

on tile[0]: port p_rst_wifi = XS1_PORT_8D;

int main(void) 
{
    chan c_usb_to_engine[2], c_engine_0_to_1;
    chan c_usb_ep0_dat;
    chan c_acquire;

    i2c_master_if i2c[1];

#ifdef ENABLE_USB
    chan c_ep_out[EP_COUNT_OUT], c_ep_in[EP_COUNT_IN];
#endif

    par 
    {
        on tile[1]: {
            inference_engine_t ie;
            unsafe { inference_engine_0_initialize_with_memory(&ie); }
            ie.chainToNext = 1;
            aiengine(ie, c_usb_to_engine[0], null, c_engine_0_to_1, c_acquire, null, null);   // Needs camera
        }
        on tile[0]: {
            p_rst_wifi <: 0;
            inference_engine_t ie;
            unsafe { inference_engine_1_initialize_with_memory(&ie); }
            aiengine(ie, c_usb_to_engine[1], c_engine_0_to_1, null, null, null, null);
        }
        

        on tile[0]: i2c_master(i2c, 1, p_scl, p_sda, 400);
        on tile[0]: {
            hm0360_reset();
        }
        on tile[1]: {
            timer tmr; int t;
            tmr :> t;
            tmr when timerafter(t + 500000) :> void;
            hm0360_monolith_init();
            hm0360_stream_start(i2c[0]);
            hm0360_main(i2c[0], c_acquire);
        }


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
