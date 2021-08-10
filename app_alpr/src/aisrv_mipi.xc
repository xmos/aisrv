#if (MIPI_INTEGRATION == 1)

#include <xs1.h>
#include <print.h>
#include <stdio.h>
#include <stdint.h>
#include <platform.h>
#include <string.h>
#include <math.h>
#include "assert.h"
#include "i2c.h"
#include "gc0310.h"
#include "mipi.h"
#include "debayer.h"
#include "usleep.h"
#include "yuv_to_rgb.h"
#include "get_time.h"
#include "aisrv.h"

typedef enum {
    IMAGER_SAMPLE = 1,
    IMAGER_DONTSAMPLE = 0,
} imager_t;


void send_array(chanend c, uint32_t * unsafe array, unsigned size);

#ifndef MIPI_BUFFER_SIZE_BYTES
#define MIPI_BUFFER_SIZE_BYTES (3300)
#endif

#define MIPI_LINES 8
uint8_t mipiBuffer[MIPI_LINES][MIPI_BUFFER_SIZE_BYTES];

on tile[MIPI_TILE]:buffered in port:32 p_mipi_clk = XS1_PORT_1O;
on tile[MIPI_TILE]:in port p_mipi_rxa = XS1_PORT_1E;
on tile[MIPI_TILE]:in port p_mipi_rxv = XS1_PORT_1I;
on tile[MIPI_TILE]:buffered in port:32 p_mipi_rxd = XS1_PORT_8A;
on tile[MIPI_TILE]:in port p_mipi_rxs = XS1_PORT_1J;

on tile[MIPI_TILE]:clock clk_mipi = XS1_CLKBLK_1;

void exit(int);

uint32_t statusError = 0, headerError = 0, lineCountError = 0, pixelCountError = 0;
uint64_t pixelCounter = 0;
#pragma unsafe arrays
void MipiDecoupler(chanend c, chanend c_kill, chanend c_line) 
{
    unsigned tailSize, ourWordCount, mipiHeader;
    int line = 0;
    
    unsafe 
    {
        while(1) 
        {
            // Send out a buffer pointer to receiver thread 
            uint8_t * unsafe pt = mipiBuffer[line];
            outuint(c, (unsigned) pt);
            /* Packet receive notification - header */
            mipiHeader = inuint(c);
            outuchar(c_line, mipiHeader);
            
            line = (line + 1) & (MIPI_LINES-1);
            /* Long packet */
            if(mipiHeader & 0x30) {
                ourWordCount = inuint(c);
                tailSize = inuint(c);
                if (ourWordCount != 320 && tailSize != 0) 
                {
                    printintln(ourWordCount);
                    printintln(tailSize);
                    pixelCountError++;
                }
            }
        }
    }
}


uint32_t frame_time = 0, line_time = 0;

struct decoupler_buffer 
{
    uint8_t full_image[480][300*2];
    int serial;
} decoupler[1];

unsafe
{
    struct decoupler_buffer * unsafe decoupler_r = decoupler;
}

#pragma unsafe arrays


void MipiImager(chanend c_line, chanend c_decoupler, chanend ?c_decoupler2 /*chanend c_l0*/) 
{
    int line = 0;
    int lineCount = 0;
    int last_sof = 0, last_line = 0, now = 0;
    int linesSaved = 0;
    int decoupleCount = 0;
    int errors = 0;
    int grabbing = 0;
    uint8_t new_grabbing = 0;
    int fc = 0;
    unsafe 
    {
        while(1) 
        {
            uint8_t * unsafe pt = mipiBuffer[line];
            uint8_t header_byte;
            select {
                case inuchar_byref(c_line, header_byte):
                    int header = header_byte & 0x3f;
                    line = (line + 1) & 7;
                    if (header == 0)      // Start of frame
                    {
                        lineCount = 0;
                        grabbing = new_grabbing;
                        //outuchar(c_l0, fc);
                        //outct(c_l0, 1);
                        //fc = ~fc;
                    } 
                    else if (header == 1) // End of frame
                    {   
                        asm volatile("gettime %0" : "=r" (now));
                        uint32_t * unsafe ft = &frame_time;
                        *ft = now - last_sof;
                        last_sof = now;
                        if (lineCount != 480) 
                        {
                            lineCountError++;
                        }
                        pixelCounter += (640*480);
                    } 
                    else if (header == 0x1E) // YUV422
                    {
                        if (grabbing) {
                            memcpy(decoupler_r->full_image[linesSaved], pt+340, 300*2);
                        }
                        linesSaved++;
                        if (linesSaved == 480) 
                        {
                            if (grabbing) 
                            {
                                outuchar(c_decoupler, 0);
                            }
                            linesSaved = 0;
                        }
                        lineCount++;
                        if(pt[640*2] != 0) 
                        {
                            statusError++;
                        }
                    } 
                    else if (header == 0x12)  // Embedded data - ignore
                    { 
                        if(pt[640*2] != 0) 
                        {
                            statusError++;
                        }
                    } 
                    else 
                    {                     
                        printf("# ******** %02x\n", header);
                        errors++;
                        if (errors > 10) {
                            exit(1);
                        }
                    }
                    int error = header_byte & 0xc0;
                    if (error) 
                    {
                        headerError++;
                    }
                    break;
                case inuchar_byref(c_decoupler, new_grabbing):
                    if (new_grabbing == 0) {
                        grabbing = 0;
                    }
                    break;
            }
        }
    }
}


#pragma unsafe arrays
void ImagerUser(chanend c_debayerer, client interface i2c_master_if i2c, chanend c_acquire)
{

    int index = 0;
    int lineCount = 0;
    int fc = 0;
    outuchar(c_debayerer, IMAGER_SAMPLE);
    
    while(1)
    {
        int decoupleCount = inuchar(c_debayerer);
        unsafe 
        {
            fc++;
            if (fc % 24 == 0) printintln(fc);
#if 0
            if (fc > 20 && (fc %100) == 0 ) {
                for(int y = 0; y < 480; y ++) {
                    for(int x = 0; x < 300; x ++) {
                        timer tmr;
                        int t0;
                        printf("%d ", (((int8_t)(decoupler_r -> full_image)[y][x*2])^0x00)+128);
                        tmr :> t0;
                        tmr when timerafter(t0+100) :> void;
                    }
                    printf("\n");
                }
                printf("\n");
            }
#endif
        
            lineCount = 0;
            index = 0;
            unsigned cmd;

            select
            {
                case c_acquire :> cmd:

                    send_array(c_acquire, (decoupler_r -> full_image, uint32_t[]), RAW_IMAGE_WIDTH * RAW_IMAGE_HEIGHT * RAW_IMAGE_DEPTH);

                    break;

                default:
                    break;
            } 
            outuchar(c_debayerer, IMAGER_SAMPLE);
        }
    }
}

#define TEST_DEMUX_DATATYPE (0x1E)
#define TEST_DEMUX_MODE     (0x00)     // bias
#define TEST_DEMUX_EN       (1)
#define DELAY_MIPI_CLK      (1)

on tile[1]: port p_reset_camera = XS1_PORT_1P;

void mipi_main(client interface i2c_master_if i2c, chanend c_acquire)
{
    chan c;
    chan c_kill, c_img, c_ctrl;

#define MIPI_CLK_DIV 1
#define MIPI_CFG_CLK_DIV 3

    p_reset_camera @ 0 <: 0;
    p_reset_camera @ 1000 <: ~0;
    p_reset_camera @ 2000 <: 0;
    
    configure_in_port_strobed_slave(p_mipi_rxd, p_mipi_rxv, clk_mipi);
    set_clock_src(clk_mipi, p_mipi_clk);

    /* Sample on falling edge - shim outputting on rising */
#ifdef DELAY_MIPI_CLK
    set_clock_rise_delay(clk_mipi, DELAY_MIPI_CLK);
#else
    set_clock_rise_delay(clk_mipi, 0);
#endif
    set_pad_delay(p_mipi_rxa, 1);
    start_clock(clk_mipi);
    write_node_config_reg(tile[MIPI_TILE], XS1_SSWITCH_MIPI_DPHY_CFG3_NUM ,
                          0x3E42);
    if (gc0310_stream_start(i2c) != 0) 
    {
        printf("Stream start failed\n");
    }
    
    par 
    {
        MipiReceive(tile[MIPI_TILE], 1, c, p_mipi_rxd, p_mipi_rxa, c_kill, TEST_DEMUX_EN, TEST_DEMUX_DATATYPE, TEST_DEMUX_MODE, MIPI_CLK_DIV, MIPI_CFG_CLK_DIV);
        MipiDecoupler(c, c_kill, c_img);

        MipiImager(c_img, c_ctrl, null);
        ImagerUser(c_ctrl, i2c, c_acquire);
    }
    i2c.shutdown();
}

#endif
