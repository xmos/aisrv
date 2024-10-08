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

#include "xud.h"

#define EP_COUNT_OUT 2
#define EP_COUNT_IN 2

XUD_EpType epTypeTableOut[EP_COUNT_OUT] = {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};
XUD_EpType epTypeTableIn[EP_COUNT_IN] =   {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};

#if defined(PSOC_INTEGRATION)
on tile[1]: in port p_cs_s = XS1_PORT_1A;//DAC_DATA
on tile[1]: in port p_clk_s = XS1_PORT_1B;//LRCLK
on tile[1]: buffered port:32  p_mosi_s = XS1_PORT_1C; //BCLK
on tile[1]: buffered port:32 p_miso_s = XS1_PORT_1P;
on tile[1]: out port reset1 = XS1_PORT_4A;
on tile[1]: clock clkblk_s = XS1_CLKBLK_4;
#endif


#define FL_QUADDEVICE_MACRONIX_MX25R6435FM2IH0 \
{ \
    16,                     /* MX25R6435FM2IH0 */ \
    256,                    /* page size */ \
    32768,                  /* num pages */ \
    3,                      /* address size */ \
    3,                      /* log2 clock divider */ \
    0x9F,                   /* QSPI_RDID */ \
    0,                      /* id dummy bytes */ \
    3,                      /* id size in bytes */ \
    0xC22817,               /* device id */ \
    0x20,                   /* QSPI_SE */ \
    4096,                   /* Sector erase is always 4KB */ \
    0x06,                   /* QSPI_WREN */ \
    0x04,                   /* QSPI_WRDI */ \
    PROT_TYPE_NONE,         /* no protection */ \
    {{0,0},{0x00,0x00}},    /* QSPI_SP, QSPI_SU */ \
    0x02,                   /* QSPI_PP */ \
    0xEB,                   /* QSPI_READ_FAST */ \
    1,                      /* 1 read dummy byte */ \
    SECTOR_LAYOUT_REGULAR,  /* mad sectors */ \
    {4096,{0,{0}}},         /* regular sector sizes */ \
    0x05,                   /* QSPI_RDSR */ \
    0x01,                   /* QSPI_WRSR */ \
    0x01,                   /* QSPI_WIP_BIT_MASK */ \
}

#define FL_QUADDEVICE_MACRONIX_MX25R3235FM1IH0 \
{ \
    15,                     /* MX25R3235FM1IH0 */ \
    256,                    /* page size */ \
    32768,                  /* num pages */ \
    3,                      /* address size */ \
    3,                      /* log2 clock divider */ \
    0x9F,                   /* QSPI_RDID */ \
    0,                      /* id dummy bytes */ \
    3,                      /* id size in bytes */ \
    0xC22816,               /* device id */ \
    0x20,                   /* QSPI_SE */ \
    4096,                   /* Sector erase is always 4KB */ \
    0x06,                   /* QSPI_WREN */ \
    0x04,                   /* QSPI_WRDI */ \
    PROT_TYPE_NONE,         /* no protection */ \
    {{0,0},{0x00,0x00}},    /* QSPI_SP, QSPI_SU */ \
    0x02,                   /* QSPI_PP */ \
    0xEB,                   /* QSPI_READ_FAST */ \
    1,                      /* 1 read dummy byte */ \
    SECTOR_LAYOUT_REGULAR,  /* mad sectors */ \
    {4096,{0,{0}}},         /* regular sector sizes */ \
    0x05,                   /* QSPI_RDSR */ \
    0x01,                   /* QSPI_WRSR */ \
    0x01,                   /* QSPI_WIP_BIT_MASK */ \
}

fl_QuadDeviceSpec flash_spec[] = {
    FL_QUADDEVICE_MACRONIX_MX25R6435FM2IH0,
    FL_QUADDEVICE_MACRONIX_MX25R3235FM1IH0
};

on tile[0]: fl_QSPIPorts qspi = {
    PORT_SQI_CS,
    PORT_SQI_SCLK,
    PORT_SQI_SIO,
    XS1_CLKBLK_2
};

int main(void) 
{
    chan c_usb_to_engine[2];
    chan c_usb_ep0_dat;
    chan c_flash[2];
    chan c_ep_out[EP_COUNT_OUT], c_ep_in[EP_COUNT_IN];

    par 
    {

        on tile[0]: {
            inference_engine_t ie;
            unsafe { inference_engine_initialize_with_memory_1(&ie); }
            aiengine(ie, c_usb_to_engine[0], null, null,
                     null, null, c_flash[1]
                );
        } 

        on tile[1]: {
            // inference_engine_t ie;
            // unsafe { inference_engine_initialize_with_memory_0(&ie); }
            // aiengine(ie, c_usb_to_engine[0], null, null,
            //          null, null, c_flash[0]
            //     );
        }

        on tile[0]: {
            //flash_t headers[2];
            //flash_server(c_flash, headers, 2, qspi, flash_spec, sizeof(flash_spec) / sizeof(flash_spec[0]));
        }

#if defined(PSOC_INTEGRATION)
        on tile[1]: {
            unsafe {
                struct memory memory;
                struct memory * unsafe mem = & memory;
                mem->status[0] = 0x00000080;
                mem->input_tensor_index = 0;
                mem->input_tensor_length = 0;
                mem->output_tensor_index = 0;
                mem->output_tensor_length = 0;
                mem->timings_index = 10;  // TODO FIXME this hardcored value needs to relate to model 
                mem->timings_length = 31; // TODO FIXME as above
                mem->model_index = 0;
                mem->debug_log_index = 134; // TODO FIXME
                mem->debug_log_length = (MAX_DEBUG_LOG_LENGTH * MAX_DEBUG_LOG_ENTRIES);
                mem->ai_server_id[0] = INFERENCE_ENGINE_ID;
                reset1 <: 0;
                par {
                    spi_xcore_ai_slave(p_cs_s, p_clk_s,
                                       p_miso_s, p_mosi_s,
                                       clkblk_s, c_led, c_spi_to_buffer,
                                       mem);
                    spi_buffer(c_spi_to_buffer, c_spi_to_engine,
                               c_acquire_to_buffer, mem);
                }
            }
        }
#endif

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
