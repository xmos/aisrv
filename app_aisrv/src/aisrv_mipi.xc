
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
#include "imx219.h"
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
                if (ourWordCount != 824 && tailSize != 0) 
                {
                    pixelCountError++;
                }
            }
        }
    }
}

// START_Y and START_X must be even, otherwise debayering will fail unceremoniously.
#define START_Y  200
#define END_Y    (START_Y + RAW_IMAGE_HEIGHT*2)
#define START_X  ((3000/4) - RAW_IMAGE_WIDTH)
#define END_X    ((3000/4) + RAW_IMAGE_WIDTH)

uint32_t frame_time = 0, line_time = 0;

struct decoupler_buffer 
{
    uint8_t data[2 * RAW_IMAGE_WIDTH * RAW_IMAGE_DEPTH];
    int serial;
} decoupler[4];

int8_t bayeredBuffer[4][RAW_IMAGE_WIDTH*2];

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
    //int fc = 0;
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
                        if (lineCount != 2480) 
                        {
                            lineCountError++;
                        }
                        pixelCounter += (2480 * 3296);
                    } 
                    else if (header == 0x2A) // RAW8
                    { 
                        if (lineCount >= START_Y && lineCount < END_Y) 
                        {
                            memcpy(bayeredBuffer[linesSaved], pt + START_X, END_X - START_X);
                            linesSaved++;
                            if (linesSaved == 4) 
                            {
                                debayer_four_lines_rgb((bayeredBuffer, int8_t[]), 2* RAW_IMAGE_WIDTH, (decoupler[decoupleCount].data, int8_t[]));

                                decoupler[decoupleCount].serial = lineCount-START_Y;
                               
                                if (grabbing) 
                                {
                                    outuchar(c_decoupler, decoupleCount);
                                }
                                
                                decoupleCount = (decoupleCount+1) & 3;
                                linesSaved = 0;
                            }
                        } 
                        else 
                        {
                            uint32_t * unsafe lt = &line_time;
                            asm volatile("gettime %0" : "=r" (now));
                            *lt = now - last_line;
                            last_line = now;
                        }
                        lineCount++;
                        if(pt[3298] != 0) 
                        {
                            statusError++;
                        }
                    } 
                    else if (header == 0x12)  // Embedded data - ignore
                    { 
                        if(pt[3298] != 0) 
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


int8_t rgbImage[RAW_IMAGE_WIDTH * RAW_IMAGE_HEIGHT * RAW_IMAGE_DEPTH];

#pragma unsafe arrays
void ImagerUser(chanend c_debayerer, client interface i2c_master_if i2c, chanend c_acquire)
{
#if 0
    int gain = GAIN_DEFAULT_DB;
    int partial = 0;
    
    imx219_set_gain_dB(i2c, gain);
#endif

    int index = 0;
    int lineCount = 0;
    
    outuchar(c_debayerer, IMAGER_SAMPLE);
    
    while(1) 
    {
        int decoupleCount = inuchar(c_debayerer);
        unsafe 
        {
            if (lineCount+3 != decoupler_r[decoupleCount].serial) 
            {
                printf("%d .. %d\n", lineCount, decoupler_r[decoupleCount].serial);
                continue;
            }
        }
        lineCount += 4;
        
        unsafe 
        {
            memcpy(rgbImage+index, decoupler_r[decoupleCount].data, 2 * RAW_IMAGE_WIDTH * RAW_IMAGE_DEPTH);
        }
        
        index += 2*RAW_IMAGE_WIDTH*RAW_IMAGE_DEPTH;
        
        if(index >= RAW_IMAGE_WIDTH * RAW_IMAGE_HEIGHT * RAW_IMAGE_DEPTH)
        {
            outuchar(c_debayerer, IMAGER_DONTSAMPLE);
            lineCount = 0;
            index = 0;
           
#if 0
            int max = -200;
            int min = 200;
            for(int y = 3*RAW_IMAGE_HEIGHT/8; y < 5*RAW_IMAGE_HEIGHT/8; y++) 
            {
                for(int x = RAW_IMAGE_WIDTH*3/8; x < RAW_IMAGE_WIDTH * 5/8; x++) 
                {
                    int index = y * RAW_IMAGE_WIDTH+x;
                    int avgVal = (saveY[index] + saveY[index+1] + saveY[index+2])/3;

                    if(avgVal < min) 
                    {
                        min = avgVal;
                    }
                    
                    if(avgVal > max) 
                    {
                        max = avgVal;
                    } 
                }
            }
            if (max >= 100 && gain > 0) 
            {
                partial = 0;
                gain -= 1;
                if (gain < 0) {
                    gain = 0;
                }
                imx219_set_gain_dB(i2c, gain);
            } 
            else if(max < 80 && gain < GAIN_MAX_DB) 
            {
                partial++;
                if (partial == 2) 
                {
                    gain++;
                    imx219_set_gain_dB(i2c, gain);
                    partial = 0;
                }
            }
#endif
            unsigned cmd;

            select
            {
                case c_acquire :> cmd:

                    send_array(c_acquire, (rgbImage, uint32_t[]), RAW_IMAGE_WIDTH * RAW_IMAGE_HEIGHT * RAW_IMAGE_DEPTH);

                    break;

                default:
                    break;
            } 
            outuchar(c_debayerer, IMAGER_SAMPLE);
        }
    }
}

#define TEST_DEMUX_DATATYPE (0)
#define TEST_DEMUX_MODE     (0x80)     // bias
#define TEST_DEMUX_EN       (0)
#define DELAY_MIPI_CLK      (1)

void mipi_main(client interface i2c_master_if i2c, chanend c_acquire)
{
    chan c;
    chan c_kill, c_img, c_ctrl;

#define MIPI_CLK_DIV 1
#define MIPI_CFG_CLK_DIV 3

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
    write_node_config_reg(tile[MIPI_TILE], XS1_SSWITCH_MIPI_DPHY_CFG3_NUM , 0x7E42);
    
    if (imx219_stream_start(i2c) != 0) 
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
