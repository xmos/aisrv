// Copyright (c) 2020, XMOS Ltd, All rights reserved

#include <platform.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <xscope.h>
#include <xclib.h>
#include <stdint.h>

#include "xud.h"
#include "aisrv.h"

#define EP_COUNT_OUT 2
#define EP_COUNT_IN 2

XUD_EpType epTypeTableOut[EP_COUNT_OUT] = {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};
XUD_EpType epTypeTableIn[EP_COUNT_IN] =   {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};

void send_recv_engine(chanend ?c_usb);

int main(void) 
{
    chan c_usb_to_engine[2];
    chan c_usb_ep0_dat;

    chan c_ep_out[EP_COUNT_OUT], c_ep_in[EP_COUNT_IN];

    par 
    {
        on tile[0]: send_recv_engine(c_usb_to_engine[0]);
//        on tile[1]: send_recv_engine(c_usb_to_engine[1]);
        
        on USB_TILE : 
        {
            par
            {
                aisrv_usb_data(c_ep_out[1], c_ep_in[1], c_usb_to_engine, c_usb_ep0_dat);
                aisrv_usb_ep0(c_ep_out[0], c_ep_in[0], c_usb_ep0_dat);
                XUD_Main(c_ep_out, EP_COUNT_OUT, c_ep_in, EP_COUNT_IN, null, epTypeTableOut, epTypeTableIn, XUD_SPEED_HS, XUD_PWR_BUS);
            
            }
        }

    }
    return 0;
}
