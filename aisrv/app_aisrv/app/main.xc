// Copyright (c) 2020, XMOS Ltd, All rights reserved

#include <platform.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <xscope.h>

#include "aisrv.h"

#include "xud_device.h"

#define EP_COUNT_OUT 2
#define EP_COUNT_IN 2

extern "C" {
void app_main();
void app_data(void *data, size_t size);
}

unsafe {
  void process_xscope(chanend xscope_data_in) {
    int bytes_read = 0;
    unsigned char buffer[256];

    xscope_connect_data_from_host(xscope_data_in);
    xscope_mode_lossless();
    while (1) {
      select {
        case xscope_data_from_host(xscope_data_in, buffer, bytes_read):
          app_data(buffer, bytes_read);
          break;
      }
    }
  }
}


XUD_EpType epTypeTableOut[EP_COUNT_OUT] = {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE};
XUD_EpType epTypeTableIn[EP_COUNT_IN] =   {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};


int main(void) {
  chan xscope_data_in;
  
  chan c_ep_out[EP_COUNT_OUT], c_ep_in[EP_COUNT_IN];



  par {
    xscope_host_data(xscope_data_in);
    on tile[0] : {
      app_main();
      process_xscope(xscope_data_in);
    }
    
    on tile[1]: XUD_Main(c_ep_out, EP_COUNT_OUT, c_ep_in, EP_COUNT_IN,
                      null, epTypeTableOut, epTypeTableIn, XUD_SPEED_HS, XUD_PWR_BUS);

     on tile[1]:aisrv_usb(c_ep_out, c_ep_in);

   
  }

  return 0;
}
