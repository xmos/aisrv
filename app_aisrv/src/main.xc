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

extern "C" 
{
    int interp_init();
    void print_output(); 
    extern unsigned char model_data[MAX_MODEL_SIZE_BYTES];
    extern unsigned char * unsafe output_buffer;
    extern unsigned char * unsafe input_buffer;
    extern int input_size;
    extern int output_size;
}

XUD_EpType epTypeTableOut[EP_COUNT_OUT] = {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};
XUD_EpType epTypeTableIn[EP_COUNT_IN] =   {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};

unsafe{
static inline transaction send_int(chanend c, unsigned x)
{
    c <: (unsigned) 4;
    for(int i = 0; i < 4; i++)
        c <: (unsigned char) (x, unsigned char[])[i]; 
}

static inline transaction send_array(chanend c, unsigned char * unsafe array, unsigned size)
{
    c <: (unsigned)size;
    for(int i = 0; i < size; i++)
        c <: array[i];
}

static inline transaction receive_array(chanend c, unsigned char * unsafe array, unsigned size)
{
    for(int i = 0; i < size; i++)
        c :> array[i];
}

void interp_runner(chanend c)
{
    aisrv_cmd_t cmd = CMD_NONE;
    unsigned length = 0;
    unsigned char data[512];

    unsigned haveModel = 0;
    unsigned model_size;

    while(1)
    {
        c :> cmd;

        switch(cmd)
        {
            case CMD_SET_MODEL:
                
                slave 
                {
                    c :> model_size;
            
                    if(model_size > MAX_MODEL_SIZE_BYTES)
                        printf("Warning not enough space allocated for model %d %d\n", model_size, MAX_MODEL_SIZE_BYTES);
                    else
                        printf("Model size: %d\n", model_size);

                    receive_array(c, model_data, model_size);

                    haveModel = !interp_init();
                    c <: haveModel;

                    printf("Model written\n");
                }

                break;

            case CMD_GET_MODEL:
                
                slave
                {
                    /* TODO bad status if no model */
                    c <: (unsigned) STATUS_OKAY;
                    send_array(c, model_data, model_size);
                }
                break;

            case CMD_SET_INPUT_TENSOR:

                slave
                {
                    unsigned size;
                    c :> size;

                    // TODO check size vs input_size
                
                    for(int i = 0; i < size; i++)
                    {
                        unsigned char x;
                        c :> x;

                        /* If no valid model throw away data */
                        if(haveModel)
                            input_buffer[i] = x;
                    }
                
                    if(haveModel)
                        c <: (unsigned) STATUS_OKAY;
                    else
                        c <: (unsigned) STATUS_ERROR_NO_MODEL;
                }  

                break;

            case CMD_START_INFER:

                aisrv_status_t status = STATUS_OKAY;
                
                slave
                {
                    c :> int dummy_size;
                    c :> unsigned char dummy_byte;

                    if(haveModel)
                    {
                        status = interp_invoke();
                        //print_output();
                    }
                    else
                    {
                        status = STATUS_ERROR_NO_MODEL;
                    }
                    c <: status;
                }

                break;
            
            case CMD_GET_OUTPUT_TENSOR_LENGTH:

                // TODO use a send array function 
                slave
                {
                    if(haveModel)
                    {
                        c <: (unsigned) STATUS_OKAY;
                        send_int(c, output_size);
                    }
                    else
                    {
                        c <: STATUS_ERROR_NO_MODEL;
                    }
                }

                break;

             case CMD_GET_INPUT_TENSOR_LENGTH:
                
                // TODO use a send array function 
                slave
                {
                    if(haveModel)
                    {
                        c <: (unsigned) STATUS_OKAY;
                        send_int(c, input_size);
                    }
                    else
                    {
                        c <: STATUS_ERROR_NO_MODEL;
                    }
                }

                break;

            case CMD_GET_OUTPUT_TENSOR:
                slave
                {
                    c <: (unsigned) STATUS_OKAY;
                    send_array(c, output_buffer, output_size);
                }
                break;

            default:
                break;
        }
    }
}

void aisrv_usb_data(chanend c_ep_out, chanend c_ep_in, chanend c)
{
    unsigned char data[512];

    XUD_ep ep_out = XUD_InitEp(c_ep_out);
    XUD_ep ep_in  = XUD_InitEp(c_ep_in);

    aisrv_cmd_t cmd = CMD_NONE;

    int result_requested = 0;

    int output_size = 0;
    int input_size = 0;

    while(1)
    {
        unsigned length = 0;
        
        /* Get command */
        XUD_GetBuffer(ep_out, data, length);
                
        cmd = data[0];

        if(length != CMD_LENGTH_BYTES)
        {
            printf("Bad cmd length: %d\n", length);
            continue;
        }
        if((cmd & 0x7f) > CMD_END_MARKER)
        {
            printf("Bad cmd: %d\n", cmd);
        }
             
      

        /* Pass on command */
        c <: cmd;
       
        /* Check cmd write bit */
        if(cmd & 0x80)
        {
            unsigned pktLength;
            /* First packet contains size only */
            XUD_GetBuffer(ep_out, data, pktLength);

            int size = (data, unsigned[])[0];
            
            master
            {
                c <: size;

                while(size > 0)
                {
                    XUD_GetBuffer(ep_out, data, pktLength);
    
                    for(int i = 0; i < pktLength; i++)
                    {
                        c <: data[i];
                    }

                    size = size - pktLength;
                }

                /* TODO handle any error */
                aisrv_status_t status;
                c :> status;
            }
        }
        else
        {
            /* Read command */
            master
            {
                aisrv_status_t status = STATUS_OKAY;
               
                c :> status;

                if(status == STATUS_OKAY)
                {
                    unsigned size;
                    c :> size;
                
                    XUD_SetBuffer(ep_in, (size, unsigned char[]), 4);

                    while(size >= MAX_PACKET_SIZE)
                    {
                        for(int i = 0; i < MAX_PACKET_SIZE; i++)
                        {
                            c :> data[i];
                        }
                       
                        XUD_SetBuffer(ep_in, data, MAX_PACKET_SIZE);

                        size = size - MAX_PACKET_SIZE;
                    }

                    // Send tail packet 
                    if(size)
                    {
                        for(int i = 0; i < size; i++)
                        {
                            c :> data[i];
                        }
                        XUD_SetBuffer(ep_in, data, size);
                    }
                }
                else
                {
                    XUD_SetStall(ep_in);
                    XUD_SetStall(ep_out);
                }
            }
        }
    } // while(1)
}
} // unsafe

void aisrv_usb_ep0(chanend c_ep0_out, chanend c_ep0_in);


int main(void)
{
    chan xscope_data_in;
    chan c_ep_out[EP_COUNT_OUT], c_ep_in[EP_COUNT_IN];
    chan c;

    par 
    {
        on tile[1]: 
        {
            interp_runner(c);
        }

        on tile[0] : 
        {
          
            par
            {
                aisrv_usb_data(c_ep_out[1], c_ep_in[1], c);
                aisrv_usb_ep0(c_ep_out[0], c_ep_in[0]);
                XUD_Main(c_ep_out, EP_COUNT_OUT, c_ep_in, EP_COUNT_IN, null, epTypeTableOut, epTypeTableIn, XUD_SPEED_HS, XUD_PWR_BUS);
            
            }
        }
    } 

    return 0;
}
