// Copyright (c) 2020, XMOS Ltd, All rights reserved



#include <platform.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <xscope.h>
#include <xclib.h>
#include <stdint.h>
#include "acquire.h"
#include "spi.h"
#include "spibuffer.h"
#include "aiengine.h"
#include "aisrv.h"
#include "inference_engine.h"

#ifdef ENABLE_USB
#include "xud.h"

#define EP_COUNT_OUT 2
#define EP_COUNT_IN 2

XUD_EpType epTypeTableOut[EP_COUNT_OUT] = {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};
XUD_EpType epTypeTableIn[EP_COUNT_IN] =   {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};
#endif

on tile[0]: port p_led = XS1_PORT_4C;

void leds(chanend led) {
    while(1) {
        int x;
        led :> x;
        if (x == -1) {
            break;
        }
        p_led <: x;
    }
}

#ifdef ENABLE_USB
unsafe
{
// TODO Move to USB file
void aisrv_usb_data(chanend c_ep_out, chanend c_ep_in, chanend c)
{
    int32_t data[MAX_PACKET_SIZE_WORDS];

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
        XUD_GetBuffer(ep_out, (data, uint8_t[]), length);
                
        cmd = (uint8_t) data[0];

        if(length != CMD_LENGTH_BYTES)
        {
            printf("Bad cmd length: %d\n", length);
            continue;
        }

        /* Pass on command */
        c <: cmd;
       
        /* Check cmd write bit */
        if(cmd & 0x80)
        {
            while(1)
            {
                unsigned pktLength;
                XUD_GetBuffer(ep_out, (data, uint8_t[]), pktLength);
       
                printf("Received: %d bytes\n", pktLength);
                
                size_t i = 0;
                for(i = 0; i < (pktLength/4); i++)
                {
                    outuint(c, data[i]);
                }
              
                if(pktLength != MAX_PACKET_SIZE)
                {
                    i *= 4;
                    outct(c, XS1_CT_END);
                    while(i < pktLength)
                    {
                        outuchar(c, (data, uint8_t[])[i++]);
                    }
                    outct(c, XS1_CT_END);
                    break;
                }
            }

            aisrv_status_t status;
            status = inuint(c);
            chkct(c, XS1_CT_END);
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
                
                    while(size >= MAX_PACKET_SIZE)
                    {
                        for(int i = 0; i < MAX_PACKET_SIZE; i++)
                        {
                            c :> data[i];
                        }
                       
                        XUD_SetBuffer(ep_in, (data, uint8_t[]), MAX_PACKET_SIZE);

                        size = size - MAX_PACKET_SIZE;
                    }

                    // Send tail packet 
                    if(size)
                    {
                        for(int i = 0; i < size; i++)
                        {
                            c :> (data, uint8_t[])[i];
                        }
                        XUD_SetBuffer(ep_in, (data, uint8_t[]), size);
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

static inline size_t receive_array_(chanend c, unsigned * unsafe array, unsigned size, unsigned ignore)
{
    unsigned i = 0;
    
    while(1)
    {
        if(!testct(c))
        {
            uint32_t x = inuint(c);
            if(!ignore)
                array[i++] = x;
        }
        else
        {
            chkct(c, XS1_CT_END);
            break;
        }
    }

    i *= sizeof(uint32_t);
    uint8_t * unsafe arrayc = (uint8_t * unsafe) array;

    while(1)
    {
        if(!testct(c))
        {
            uint8_t x = inuchar(c);

            if(!ignore)
                arrayc[i++] = x;
        }
        else
        {
            chkct(c, XS1_CT_END);
            break;
        }
    }

    return i;
}

static inference_engine_t ie;

void interp_runner(chanend c)
{
    aisrv_cmd_t cmd = CMD_NONE;
    unsigned length = 0;
    unsigned char data[512];

    unsigned haveModel = 0;
    unsigned model_size;

    unsafe { inference_engine_initialize(&ie); }

    while(1)
    {
        c :> cmd;

        switch(cmd)
        {
            case CMD_SET_MODEL:
                
                #if 0
                     if(model_size > MAX_MODEL_SIZE_BYTES)
                        printf("Warning not enough space allocated for model %d %d\n", model_size, MAX_MODEL_SIZE_BYTES);
                    else
                        printf("Model size: %d\n", model_size);
                #endif
                
                // TODO reinstate checks for witing out of bounds
                receive_array_(c, ie.model_data, model_size, 0);
                
                haveModel = !interp_initialize(&ie);
                outuint(c, haveModel);
                outct(c, XS1_CT_END);

                printf("Model written %d\n", haveModel);

                break;

            case CMD_GET_MODEL:
                
                slave
                {
                    /* TODO bad status if no model */
                    c <: (unsigned) STATUS_OKAY;
                    send_array(c, ie.model_data, model_size);
                }
                break;

            case CMD_SET_INPUT_TENSOR:

                 // TODO check size vs input_size
                size_t size = receive_array_(c, ie.input_buffer, model_size, !haveModel);
            
                if(haveModel)
                {
                    outuint(c, STATUS_OKAY);
                    outct(c, XS1_CT_END);
                }
                else
                {
                    outuint(c, STATUS_ERROR_NO_MODEL);
                    outct(c, XS1_CT_END);
                }
                break;

            case CMD_START_INFER:

                aisrv_status_t status = STATUS_OKAY;

                // TODO use receive_array()
                inct(c);
                inuchar(c); // dummy byte
                inct(c);
                    
                if(haveModel)
                {
                    status = interp_invoke();
                    //print_output();
                }
                else
                {
                    status = STATUS_ERROR_NO_MODEL;
                }

                outuint(c, status);
                outct(c, XS1_CT_END);
                break;
            
            case CMD_GET_OUTPUT_TENSOR_LENGTH:
    
                // TODO use a send array function 
                slave
                {
                    if(haveModel)
                    {
                        c <: (unsigned) STATUS_OKAY;
                        send_int(c, ie.output_size);
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
                        send_int(c, ie.input_size);
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
                    send_array(c, ie.output_buffer, ie.output_size);
                }
                break;

            default:
                break;
        }
    }
}
} // unsafe
#endif

#define PSOC_INTEGRATION

#if defined(PSOC_INTEGRATION)
on tile[1]: in port p_cs_s = XS1_PORT_1A;//DAC_DATA
on tile[1]: in port p_clk_s = XS1_PORT_1B;//LRCLK
on tile[1]: buffered port:32  p_mosi_s = XS1_PORT_1C; //BCLK
on tile[1]: buffered port:32 p_miso_s = XS1_PORT_1P; // 39
on tile[1]: out port reset1 = XS1_PORT_4A;
on tile[1]: clock clkblk_s = XS1_CLKBLK_4;
#endif

#if defined(I2C_REQUIRED)
on tile[0]: port p_scl = XS1_PORT_1N;
on tile[0]: port p_sda = XS1_PORT_1O;
#endif

int main(void) 
{
    chan c_led, c_spi_to_buffer, c_buffer_to_engine, c_acquire_to_buffer;
    chan c_acquire_to_sensor;
#if defined(I2C_INTEGRATION)
    i2c_master_if i2c[1];
#endif

#ifdef ENABLE_USB
    chan c_ep_out[EP_COUNT_OUT], c_ep_in[EP_COUNT_IN];
    chan c;
#endif

    par 
    {
#if defined(I2C_INTEGRATION)
        on tile[0]: i2c_master(i2c, 1, p_scl, p_sda, 400);
#endif
#if defined(MIPI_INTEGRATION)
        on tile[1]: mipi_main(i2c[0], c_acquire_to_sensor);
#endif
#if defined(PSOC_INTEGRATION)
        on tile[0]: {
            par{
                //aiengine(c_buffer_to_engine);
                interp_runner(c);
            }
        }
        on tile[0]: {
            leds(c_led);
        }
        on tile[1]: {
            unsafe {
                struct memory memory;
                struct memory * unsafe mem = & memory;
                mem->status[0] = 0x00000080;
                mem->input_tensor_index = 0;
                mem->input_tensor_length = 0;
                mem->output_tensor_index = 0;
                mem->output_tensor_length = 0;
                mem->timings_index = 10;
                mem->timings_length = 31;
                mem->model_index = 0;
                mem->ai_server_id[0] = INFERENCE_ENGINE_ID;
                reset1 <: 0;
                par {
                    spi_xcore_ai_slave(p_cs_s, p_clk_s,
                                       p_miso_s, p_mosi_s,
                                       clkblk_s, c_led, c_spi_to_buffer,
                                       mem);
                    spi_buffer(c_spi_to_buffer, c_buffer_to_engine,
                               c_acquire_to_buffer, mem);
                    acquire(c_acquire_to_buffer, c_acquire_to_sensor, mem);
                }
            }
        }
#else
        {
            spi_main(c_led);
            qpi_main(c_led);
            c_led <: -1;
        }
        leds(c_led);
#endif

#ifdef ENABLE_USB
        on tile[0]: 
        {
            //interp_runner(c);
        }
         on tile[1] : 
        {
          
            par
            {
                aisrv_usb_data(c_ep_out[1], c_ep_in[1], c);
                aisrv_usb_ep0(c_ep_out[0], c_ep_in[0]);
                XUD_Main(c_ep_out, EP_COUNT_OUT, c_ep_in, EP_COUNT_IN, null, epTypeTableOut, epTypeTableIn, XUD_SPEED_HS, XUD_PWR_BUS);
            
            }
        }
#endif
    }
    return 0;
}
