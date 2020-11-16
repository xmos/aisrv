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

extern int output_size;

#define EP_COUNT_OUT 2
#define EP_COUNT_IN 2

extern "C" {
void interp_init();
int buffer_input_data(void *data, size_t size);
void print_output(); 
extern unsigned char * unsafe output_buffer;
//extern unsigned char * unsafe model_data;
void write_model_data(int i, unsigned char x);

}

XUD_EpType epTypeTableOut[EP_COUNT_OUT] = {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};
XUD_EpType epTypeTableIn[EP_COUNT_IN] =   {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};

unsafe{
void interp_runner(chanend c)
{
    aisrv_cmd_t cmd = CMD_NONE;
    unsigned length = 0;
    unsigned char data[512];

    unsigned haveModel = 0;

    while(1)
    {
        c :> cmd;

        switch(cmd)
        {
            case CMD_SET_MODEL:
                
                unsigned model_size;
                c :> model_size;
            
                if(model_size > MAX_MODEL_SIZE_BYTES)
                    printf("Warning not enough space allocated for model %d %d\n", model_size, MAX_MODEL_SIZE_BYTES);
                else
                    printf("Model size: %d\n", model_size);

                for(int i = 0; i < model_size; i++)
                {
                    unsigned char x;
                    c :> x;
                    write_model_data(i,x); 
                }


                /* TODO check return */
                interp_init();
    
                haveModel = 1;

                printf("Model updated\n");

                break;

            case CMD_SET_INPUT_TENSOR:
               
                int full = 0;
                while(!full)
                {
                    /* TODO improve comms */
                    c :> length;

                    for(int i = 0; i < length; i++)
                    {
                        c :> data[i];
                    }

                    full = buffer_input_data(data, length);

                    c <: full;
                }

                break;

            case CMD_START_INFER:
           
                if(haveModel)
                {
                    interp_invoke();
                    print_output();
                }

                c <: haveModel;
                break;
            
            case CMD_GET_OUTPUT_TENSOR_LENGTH:
                c <: output_size; 
                break;

            case CMD_GET_OUTPUT_TENSOR:
                for(int i = 0; i < output_size; i++)
                {
                    c <: output_buffer[i];
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
    unsigned length = 0;

    XUD_ep ep_out = XUD_InitEp(c_ep_out);
    XUD_ep ep_in  = XUD_InitEp(c_ep_in);

    aisrv_cmd_t cmd = CMD_NONE;

    int infer_in_progress = 0;
    int result_requested = 0;

    int output_size = 0;

    c <: CMD_GET_OUTPUT_TENSOR_LENGTH;
    c :> output_size;

    while(1)
    {
        /* Get command */
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
            case CMD_SET_MODEL: 

                c <: cmd;

                /* First packet contains size only */
                XUD_GetBuffer(ep_out, data, length);
    
                int model_size = (data, unsigned[])[0];

                printf("model size: %d\n", model_size);

                c <: model_size;

                while(model_size > 0)
                {
                    XUD_GetBuffer(ep_out, data, length);
        
                    for(int i = 0; i < length; i++)
                    {
                        c <: data[i];
                    }

                    model_size = model_size - length;
                }
                break; 

            case CMD_SET_INPUT_TENSOR:
                
                c <: cmd;

                int full = 0;

                while(!full)
                {
                    XUD_GetBuffer(ep_out, data, length);
                    
                    printf("Got %d bytes\n", length);
           
                    /* TODO improve comms, tranactions, words etc */
                    c <: length;
                    for(int i = 0; i < length; i++)
                    {
                        c <: data[i];
                    }

                    c :> full;
                }

                break;

            case CMD_GET_OUTPUT_TENSOR_LENGTH:

                c <: cmd;
                c :> output_size;

                XUD_SetBuffer(ep_in, (output_size, unsigned char[]), 4);
                break;

            case CMD_START_INFER:

                c <: CMD_START_INFER;
                /* Block this thread until done - we have no way of responding to commands while one is in progress */

                int haveModel = 0
                c :> haveModel;

                /* TODO communicated no model? */

                break;

            case CMD_GET_OUTPUT_TENSOR:
               
                /* TODO Stall EP if not enough data in input? */ 
                /* TODO handle len(output_buffer) > MAX_PACKET_SIZE */
                /* TODO rm copy */
                unsigned char buffer[MAX_PACKET_SIZE];
   
                c <: cmd;

                for(int i = 0; i < output_size; i++)
                    c :> buffer[i] ;

                XUD_SetBuffer(ep_in, buffer, output_size);

             default:
                break;


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
