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

extern "C" 
{
    int interp_init();
    int buffer_input_data(void *data, int offset, size_t size);
    void print_output(); 
    extern unsigned char * unsafe output_buffer;
    void write_model_data(int i, unsigned char x);
    extern int input_size;
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
                
                slave 
                {
                    c :> model_size;
            
                    if(model_size > MAX_MODEL_SIZE_BYTES)
                        printf("Warning not enough space allocated for model %d %d\n", model_size, MAX_MODEL_SIZE_BYTES);
                    else
                        printf("Model size: %d\n", model_size);

                    for(int i = 0; i < model_size; i++)
                    {
                        unsigned char x;
                        c :> x;

                        /* TODO remove this wrapper*/
                        write_model_data(i,x); 
                    }
                }

                haveModel = !interp_init();
                c <: haveModel;

                printf("Wrote model %d\n", haveModel);

                break;

            case CMD_SET_INPUT_TENSOR:

                aisrv_status_t status = STATUS_OKAY;

                if(haveModel)
                {
                    c <: STATUS_OKAY;
                    c <: input_size;

                    slave
                    {
                        /* TODO improve efficiency of comms */
                        int offset = 0;
                        while(offset < input_size)
                        {
                            c :> length;

                            for(int i = 0; i < length; i++)
                                c :> data[i];
                        
                            buffer_input_data(data, offset, length);
                            offset += length; 
                        }
                    }
                }
                else
                {
                    c <: STATUS_ERROR_NO_MODEL;
                }

                break;

            case CMD_START_INFER:

                aisrv_status_t status = STATUS_OKAY;

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
                break;
            
            case CMD_GET_OUTPUT_TENSOR_LENGTH:

                if(haveModel)
                {
                    c <: STATUS_OKAY;
                    c <: output_size; 
                }
                else
                {
                    c <: STATUS_ERROR_NO_MODEL;
                }

                break;

            case CMD_GET_OUTPUT_TENSOR:
                slave
                {
                    for(int i = 0; i < output_size; i++)
                    {
                        c <: output_buffer[i];
                    }
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

                master
                {
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
                }
    
                /* TODO handle any error */
                c :> int status;
                printf("model written commed\n");
                break; 

            case CMD_SET_INPUT_TENSOR:
                
                aisrv_status_t status;

                c <: cmd;

                c :> status;

                if(status == STATUS_OKAY)
                {
                    unsigned pktLength, tensorLength;
                    
                    c :> tensorLength;

                    master
                    {
                        while(tensorLength > 0)
                        {
                            XUD_GetBuffer(ep_out, data, pktLength);
                            
                            printf("Got %d bytes\n", pktLength);
                   
                            c <: pktLength;
                            for(int i = 0; i < pktLength; i++)
                                c <: data[i];

                            tensorLength = tensorLength - pktLength;
                        }
                    }
                }

                break;

            case CMD_GET_OUTPUT_TENSOR_LENGTH:

                aisrv_status_t status = STATUS_OKAY;
            
                c <: cmd;
                c :> status;

                if(status == STATUS_OKAY)
                {
                    c :> output_size;
                    XUD_SetBuffer(ep_in, (output_size, unsigned char[]), 4);
                }
                else
                {
                    XUD_SetStall(ep_in);
                    XUD_SetStall(ep_out);
                }

                break;

            case CMD_START_INFER:

                c <: CMD_START_INFER;
                /* Block this thread until done - we have no way of responding to commands while one is in progress */

                aisrv_status_t status;
                c :> status;

                if(status != STATUS_OKAY)
                {
                    XUD_SetStall(ep_in);
                    XUD_SetStall(ep_out);
                }

                break;

            case CMD_GET_OUTPUT_TENSOR:
               
                /* TODO handle len(output_buffer) > MAX_PACKET_SIZE */
                unsigned char buffer[MAX_PACKET_SIZE];
   
                c <: cmd;

                master 
                {
                    for(int i = 0; i < output_size; i++)
                        c :> buffer[i] ;
                }
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
