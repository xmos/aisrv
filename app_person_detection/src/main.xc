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

#ifdef ENABLE_USB
#include "xud.h"

#define EP_COUNT_OUT 2
#define EP_COUNT_IN 2

XUD_EpType epTypeTableOut[EP_COUNT_OUT] = {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};
XUD_EpType epTypeTableIn[EP_COUNT_IN] =   {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};
#endif

#if defined(I2C_INTEGRATION)
on tile[0]: port p_scl = XS1_PORT_1A;
on tile[0]: port p_sda = XS1_PORT_1D;
#endif

on tile[0]: port p_rst_wifi = XS1_PORT_8D;

int main(void) 
{
    chan c_leds[4], c_spi_to_buffer, c_spi_to_engine, c_usb_to_engine[2], c_acquire_to_buffer;
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
        on tile[1]: {
            inference_engine_t ie;
            unsafe { inference_engine_0_initialize_with_memory(&ie); }
            aiengine(ie, c_usb_to_engine[0], c_spi_to_engine, c_acquire, c_leds);   // Needs camera
        }
        on tile[0]: {
            p_rst_wifi <: 0;
            inference_engine_t ie;
            unsafe { inference_engine_1_initialize_with_memory(&ie); }
            aiengine(ie, c_usb_to_engine[1], c_spi_to_engine, c_acquire, c_leds);
        }
        
        on tile[0]: led_driver(c_leds);

#if defined(I2C_INTEGRATION)
        on tile[0]: i2c_master(i2c, 1, p_scl, p_sda, 400);
#endif
#if defined(MIPI_INTEGRATION)
        on tile[1]: mipi_main(i2c[0], c_acquire);
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
