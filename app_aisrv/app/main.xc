// Copyright (c) 2020, XMOS Ltd, All rights reserved

#include <platform.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <xscope.h>
#include <stdio.h>

#include "aisrv.h"

#include "xud_device.h"

#define EP_COUNT_OUT 2
#define EP_COUNT_IN 2

extern "C" {
void app_main();
void app_data(void *data, size_t size);
}

XUD_EpType epTypeTableOut[EP_COUNT_OUT] = {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};
XUD_EpType epTypeTableIn[EP_COUNT_IN] =   {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};

//void aisrv_usb_data(chanend c_ep_out, chanend c_ep_in);
//void aisrv_usb_ep0(chanend c_ep0_out, chanend c_ep0_in);

unsafe{
void aisrv_usb_data(chanend c_ep_out, chanend c_ep_in)
{
    unsigned char data[256];
    unsigned length = 0;

    XUD_ep ep_out = XUD_InitEp(c_ep_out);
    XUD_ep ep_in  = XUD_InitEp(c_ep_in);

    while(1)
    {
        XUD_GetBuffer(ep_out, data, length);
        printf("Got %d bytes\n", length);
        app_data(data, length);
    }
}
}

void aisrv_usb_ep0(chanend c_ep0_out, chanend c_ep0_in);


int main(void)
{
    chan xscope_data_in;
  
    chan c_ep_out[EP_COUNT_OUT], c_ep_in[EP_COUNT_IN];

  par {

    on tile[0] : {
      app_main();
      
      par
      {
            aisrv_usb_data(c_ep_out[1], c_ep_in[1]);
            aisrv_usb_ep0(c_ep_out[0], c_ep_in[0]);
            XUD_Main(c_ep_out, EP_COUNT_OUT, c_ep_in, EP_COUNT_IN, null, epTypeTableOut, epTypeTableIn, XUD_SPEED_HS, XUD_PWR_BUS);
        
        }
    }
  }



    return 0;
}
