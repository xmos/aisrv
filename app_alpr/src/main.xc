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
#include "box_calculation.h"
#include "uart.h"
#include "gpio.h"

#include "aisrv_mipi.h"

#ifdef ENABLE_USB
#include "xud.h"

#define EP_COUNT_OUT 2
#define EP_COUNT_IN 2

XUD_EpType epTypeTableOut[EP_COUNT_OUT] = {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};
XUD_EpType epTypeTableIn[EP_COUNT_IN] =   {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL};
#endif

#if defined(PSOC_INTEGRATION)
on tile[1]: in port p_cs_s = XS1_PORT_1A;//DAC_DATA
on tile[1]: in port p_clk_s = XS1_PORT_1B;//LRCLK
on tile[1]: buffered port:32  p_mosi_s = XS1_PORT_1C; //BCLK
on tile[1]: buffered port:32 p_miso_s = XS1_PORT_1P;
on tile[1]: out port reset1 = XS1_PORT_4A;
on tile[1]: clock clkblk_s = XS1_CLKBLK_4;
#endif

#if defined(I2C_INTEGRATION)
on tile[0]: port p_scl = XS1_PORT_1N;
on tile[0]: port p_sda = XS1_PORT_1O;
#endif

on tile[0]: port p_uart = PORT_LEDS;

#define ORIGIN_X_INSIDE_SENSOR ((SENSOR_IMAGE_WIDTH - WIDTH_ON_SENSOR)/2)
#define ORIGIN_Y_INSIDE_SENSOR ((SENSOR_IMAGE_HEIGHT - HEIGHT_ON_SENSOR)/2)

void director(chanend to_0, chanend to_1, client interface uart_tx_if uart_tx) {
    uint32_t classes[2*MAX_BOXES / sizeof(uint32_t)];
    uint32_t boxes[4*MAX_BOXES / sizeof(uint32_t)];
    uint32_t ocr_classes[66 * 16 / sizeof(uint32_t)];
    uint32_t bbox[4];
    char ocr_outputs[17];
//    return;
    while(1) {
        int status;
        timer tmr; int t0;
        tmr :> t0;
        tmr when timerafter(t0+200000000) :> void;
        if (aisrv_local_acquire_single(to_0,
                                       ORIGIN_X_INSIDE_SENSOR,
                                       ORIGIN_X_INSIDE_SENSOR + WIDTH_ON_SENSOR,
                                       ORIGIN_Y_INSIDE_SENSOR,
                                       ORIGIN_Y_INSIDE_SENSOR + HEIGHT_ON_SENSOR,
                                       160, 160)) {
            continue;
        }
        if (aisrv_local_start_inference(to_0)) {
            continue;
        }
        if (aisrv_local_get_output_tensor(to_0, 0, classes)) {
            continue;
        }
        if (aisrv_local_get_output_tensor(to_0, 1, boxes)) {
            continue;
        }
        int val = box_calculation(bbox, (classes, int8_t[]), (boxes, int8_t[]),
                                  WIDTH_ON_SENSOR, HEIGHT_ON_SENSOR);

        for(int i = 0 ; i < 4; i++) {
            printint(bbox[i]);
            printchar(' ');
        }
        printint(val);
        printchar('\n');
        if (val < 0) {
            printstr("Value too small\n");
            continue;
        }
        if (bbox[1] - bbox[0] < 128) {
            printstr("Width too small\n");
            continue;
        }
        if (bbox[3] - bbox[2] < 32) {
            printstr("Height too small\n");
            continue;
        }
        if (aisrv_local_acquire_single(to_1,
                                       ORIGIN_X_INSIDE_SENSOR + bbox[0],
                                       ORIGIN_X_INSIDE_SENSOR + bbox[1],
                                       ORIGIN_Y_INSIDE_SENSOR + bbox[2],
                                       ORIGIN_Y_INSIDE_SENSOR + bbox[3],
                                       128, 32)) {
            continue;
        }
        if (aisrv_local_start_inference(to_1)) {
            continue;
        }
        if (aisrv_local_get_output_tensor(to_1, 0, ocr_classes)) {
            continue;
        }
        int len = ocr_calculation(ocr_outputs, (ocr_classes, int8_t [16][66]));
        printstr(">>>");
        for(int i = 0; i < len; i++) {
            uart_tx.write(ocr_outputs[i]);
            printchar(ocr_outputs[i]);
        }
        printstr("<<<\n");
        printstr("Grabbed\n");
        tmr :> t0;
        tmr when timerafter(t0+2000000000) :> void;
    }
}

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

fl_QuadDeviceSpec flash_spec[] = {
    FL_QUADDEVICE_MACRONIX_MX25R6435FM2IH0
};

on tile[0]: fl_QSPIPorts qspi = {
    PORT_SQI_CS,
    PORT_SQI_SCLK,
    PORT_SQI_SIO,
    XS1_CLKBLK_2
};

#if defined(TFLM_DISABLED)
extern uint32_t tflite_disabled_image[320*320*3/4];
uint32_t tflite_disabled_image_1[1];
#endif

int main(void) 
{
    chan c_usb_to_engine[2], c_director_to_engine_0, c_director_to_engine_1;
    chan c_usb_ep0_dat;
    chan c_acquire[2];
    chan c_flash[2];
    interface uart_tx_if i_tx;
    output_gpio_if i_gpio_tx[1];

#if defined(I2C_INTEGRATION)
    i2c_master_if i2c[1];
#endif

#ifdef ENABLE_USB
    chan c_ep_out[EP_COUNT_OUT], c_ep_in[EP_COUNT_IN];
#endif

    par 
    {

        on tile[0]: {
            inference_engine_t ie;
            unsafe { inference_engine_initialize_with_memory_1(&ie); }
            aiengine(ie, c_usb_to_engine[1], c_director_to_engine_1, null,
                     c_acquire[1], null, c_flash[1]
#if defined(TFLM_DISABLED)
                     , tflite_disabled_image_1, sizeof(tflite_disabled_image_1)
#endif
                );
        } 

        on tile[1]: {
            inference_engine_t ie;
            unsafe { inference_engine_initialize_with_memory_0(&ie); }
            aiengine(ie, c_usb_to_engine[0], c_director_to_engine_0, null,
                     c_acquire[0], null, c_flash[0]
#if defined(TFLM_DISABLED)
                     , tflite_disabled_image, sizeof(tflite_disabled_image)
#endif
                );
        }

        on tile[1]: {
            director(c_director_to_engine_0, c_director_to_engine_1, i_tx);
        }

        on tile[0]: {
            char pin_map[1] = {2};
            output_gpio(i_gpio_tx, 1, p_uart, pin_map);
        }
        on tile[0]: uart_tx(i_tx, null,
                            10, UART_PARITY_NONE, 8, 1,
                            i_gpio_tx[0]);
#if defined(I2C_INTEGRATION)
        on tile[0]: i2c_master(i2c, 1, p_scl, p_sda, 400);
#endif
#if defined(MIPI_INTEGRATION)
        on tile[1]: mipi_main(i2c[0], c_acquire, 2);
#endif
        on tile[0]: {
            flash_t headers[2];
            flash_server(c_flash, headers, 2, qspi, flash_spec, 1);
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
