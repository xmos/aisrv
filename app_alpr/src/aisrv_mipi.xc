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
#include "yuv_to_rgb.h"
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
    uint32_t full_image[RAW_IMAGE_WIDTH * RAW_IMAGE_HEIGHT * RAW_IMAGE_DEPTH / sizeof(uint32_t)];
    int serial;
} decoupler[1];

unsafe
{
    struct decoupler_buffer * unsafe decoupler_r = decoupler;
}

#define START_X       ((SENSOR_IMAGE_WIDTH  - RAW_IMAGE_WIDTH)  / 2)
#define START_Y       ((SENSOR_IMAGE_HEIGHT - RAW_IMAGE_HEIGHT) / 2)
#define END_Y          (SENSOR_IMAGE_HEIGHT - START_Y)

#pragma unsafe arrays


void MipiImager(chanend c_line, chanend c_decoupler, chanend ?c_decoupler2 /*chanend c_l0*/)
{
    int line = 0;
    int lineCount = 0;
    int last_sof = 0, now = 0;
    int linesSaved = 0;
    int errors = 0;
    int grabbing = 0;
    uint8_t new_grabbing = 0;
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
                        new_grabbing = 0;
                    } 
                    else if (header == 1) // End of frame
                    {   
                        asm volatile("gettime %0" : "=r" (now));
                        uint32_t * unsafe ft = &frame_time;
                        *ft = now - last_sof;
                        last_sof = now;
                        if (lineCount != SENSOR_IMAGE_HEIGHT)
                        {
                            lineCountError++;
                        }
                        pixelCounter += (SENSOR_IMAGE_WIDTH*SENSOR_IMAGE_HEIGHT);
                    } 
                    else if (header == 0x1E) // YUV422
                    {
                        if (grabbing &&
                            lineCount >= START_Y &&
                            lineCount < END_Y) {
                            memcpy((decoupler_r->full_image, uint8_t[RAW_IMAGE_HEIGHT][2*RAW_IMAGE_WIDTH])[linesSaved], pt+START_X*2, RAW_IMAGE_WIDTH*2);
                            linesSaved++;
                            if (linesSaved == RAW_IMAGE_HEIGHT)
                            {
                                outuchar(c_decoupler, 0);
                                linesSaved = 0;
                                grabbing = 0;
                            }
                        }
                        lineCount++;
                        if(pt[SENSOR_IMAGE_HEIGHT*SENSOR_IMAGE_DEPTH] != 0)
                        {
                            statusError++;
                        }
                    } 
                    else if (header == 0x12)  // Embedded data - ignore
                    { 
                        if(pt[SENSOR_IMAGE_HEIGHT*SENSOR_IMAGE_DEPTH] != 0)
                        {
                            statusError++;
                        }
                    } 
                    else 
                    {                     
                        printstr("# ********"); printhexln(header);
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
                    new_grabbing = 1;
                    break;
            }
        }
    }
}


#pragma unsafe arrays
void ImagerUser(chanend c_debayerer, client interface i2c_master_if i2c, chanend c_acquire)
{

    int fc = 0;
    unsigned cmd;
    
    while(1)
    {
        c_acquire :> cmd;                            // Please grab image
        outuchar(c_debayerer, IMAGER_SAMPLE);        // Tell collector to grab image
        int decoupleCount = inuchar(c_debayerer);    // Image collector ready
        unsafe 
        {
            fc++;
            printint(fc); printchar(' '); printintln(frame_time);

            for(int y = RAW_IMAGE_HEIGHT-1; y >= 0; y --) {   // TODO: Use vector unit
                for(int x = RAW_IMAGE_WIDTH-1; x >= 0; x --) {
                    int Y = (decoupler_r -> full_image, uint8_t[RAW_IMAGE_HEIGHT][2*RAW_IMAGE_WIDTH])[y][x*2];
                    int UV0 = (decoupler_r -> full_image, uint8_t[RAW_IMAGE_HEIGHT][2*RAW_IMAGE_WIDTH])[y][(x == 0 ? y == 0 ? 5 : 3 : x*2 - 1)]; // 2 is correct but has been overwritten - 5 is the next V value.
                    int UV1 = (decoupler_r -> full_image, uint8_t[RAW_IMAGE_HEIGHT][2*RAW_IMAGE_WIDTH])[y][x*2+1];
                    int U, V;
                    if (x & 1) {
                        U = UV0; V = UV1;
                    } else {
                        U = UV1; V = UV0;
                    }
                    Y -= 128;
                    U -= 128;
                    V -= 128;
                    int R = Y + ((          292 * V) >> 8);
                    int G = Y - ((100 * U + 148 * V) >> 8);
                    int B = Y + ((520 * U          ) >> 8);
                    if (R < -128) R = -128; if (R > 127) R = 127;
                    if (G < -128) G = -128; if (G > 127) G = 127;
                    if (B < -128) B = -128; if (B > 127) B = 127;
                    (decoupler_r -> full_image, int8_t[RAW_IMAGE_HEIGHT][3*RAW_IMAGE_WIDTH])[y][x*3+0] = R;
                    (decoupler_r -> full_image, int8_t[RAW_IMAGE_HEIGHT][3*RAW_IMAGE_WIDTH])[y][x*3+1] = G;
                    (decoupler_r -> full_image, int8_t[RAW_IMAGE_HEIGHT][3*RAW_IMAGE_WIDTH])[y][x*3+2] = B;
                }
            }

            send_array(c_acquire, decoupler_r -> full_image, RAW_IMAGE_WIDTH * RAW_IMAGE_HEIGHT * RAW_IMAGE_DEPTH);

        }
    }
}

#define TEST_DEMUX_DATATYPE (0)
#define TEST_DEMUX_MODE     (0) // (0x80)     // bias
#define TEST_DEMUX_EN       (0)
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
        printstr("Stream start failed\n");
    }
    
    par 
    {
        MipiReceive(tile[MIPI_TILE], 1, c, p_mipi_rxd, p_mipi_rxa, c_kill,
                    TEST_DEMUX_EN, TEST_DEMUX_DATATYPE, TEST_DEMUX_MODE,
                    MIPI_CLK_DIV, MIPI_CFG_CLK_DIV);
        MipiDecoupler(c, c_kill, c_img);

        MipiImager(c_img, c_ctrl, null);
        ImagerUser(c_ctrl, i2c, c_acquire);
    }
    i2c.shutdown();
}

#endif
