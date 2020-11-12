// Copyright (c) 2020, XMOS Ltd, All rights reserved

#include <platform.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <xscope.h>
#include <stdio.h>

#include "aisrv.h"

#include "xud_device.h"

#include "inference_engine.h"

#define EP_COUNT_OUT 2
#define EP_COUNT_IN 2

extern "C" {
void interp_init();
int buffer_input_data(void *data, size_t size);
void print_output(); 
}

XUD_EpType epTypeTableOut[EP_COUNT_OUT] = {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};
XUD_EpType epTypeTableIn[EP_COUNT_IN] =   {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};


void printstate(int state)
{
    printf("STATE: ");

    switch(state)
    {
        case STATE_IDLE:
            printf("STATE_IDLE\n");
            break;
        case STATE_SET_INPUT:
            printf("STATE_SET_INPUT\n");
            break;
        case STATE_INFER:
            printf("STATE_INFER\n");
            break;
        case STATE_INFER_DONE:
            printf("STATE_INFER_DONE\n");
            break;
    }
}


unsafe{
void aisrv_usb_data(chanend c_ep_out, chanend c_ep_in)
{
    unsigned char data[256];
    unsigned length = 0;

    XUD_ep ep_out = XUD_InitEp(c_ep_out);
    XUD_ep ep_in  = XUD_InitEp(c_ep_in);

    aisrv_cmd_t cmd = CMD_NONE;
    aisrv_state_t state = STATE_IDLE;
    aisrv_state_t nextState = STATE_IDLE;
    
    while(1)
    {

        printstate(state);

        switch(state)
        {
            case STATE_IDLE:

                XUD_GetBuffer(ep_out, data, length);
                
                cmd = data[0];

                if(length != CMD_LENGTH_BYTES)
                {
                    printf("Bad cmd length: %d\n", length);
                    continue;
                }
                if(cmd > CMD_END_MARKER)
                {
                    printf("Bad cmd: %d\n", cmd);
                }
            
                switch(cmd)
                {
                    case CMD_NONE: 
                        break;

                    case CMD_SET_INPUT:
                        nextState = STATE_SET_INPUT;
                        break;
                }

                break;

            case STATE_SET_INPUT:
        
                XUD_GetBuffer(ep_out, data, length);
                printf("Got %d bytes\n", length);
               
                /* TODO currently this doesnt return until infer done */ 
                int full = buffer_input_data(data, length);

                if(full)
                    nextState = STATE_INFER;
    
                break;

            case STATE_INFER:

                interp_invoke();
                print_output();
                nextState = STATE_INFER_DONE;
                break;

            case STATE_INFER_DONE:

                data[0] = 0xff;
                XUD_SetBuffer(ep_in, data, 1);

                nextState = STATE_IDLE;
                break;
        }

        state = nextState;
    }
}
} // unsafe

void aisrv_usb_ep0(chanend c_ep0_out, chanend c_ep0_in);


int main(void)
{
    chan xscope_data_in;
  
    chan c_ep_out[EP_COUNT_OUT], c_ep_in[EP_COUNT_IN];

    par 
    {
        on tile[0] : 
        {
            interp_init();
          
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
