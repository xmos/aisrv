#include <xs1.h>
#include <print.h>
#include <stdio.h>
#include <stdint.h>
#include <platform.h>
#include "assert.h"
#include <string.h>
#include <math.h>
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
#define IWIDTH (828)

#define IDENT(x) x
#define IDENT_H(x) x.h
#define XSTR(x) x
#define STR(x) XSTR(x)
#define PATH(x,y) STR(IDENT(x)IDENT_H(y))

// TODO these need to be derived from the model
#define NETWORK_INPUT_HEIGHT 112
#define NETWORK_INPUT_WIDTH 112
#define NETWORK_INPUT_DEPTH 4

#define NETWORK_INPUT_SIZE (NETWORK_INPUT_HEIGHT * NETWORK_INPUT_WIDTH * NETWORK_INPUT_DEPTH)

#ifndef MIPI_TILE
#define MIPI_TILE 1
#endif

#define TEST_PACKETS 300

#define MIPI_LINES 8
uint32_t mipiHeaders[TEST_PACKETS];
uint8_t mipiBuffer[MIPI_LINES][MIPI_BUFFER_SIZE_BYTES];

uint32_t ourWordCount[TEST_PACKETS];
uint32_t tailSize[TEST_PACKETS];

on tile[MIPI_TILE]:buffered in port:32 p_mipi_clk = XS1_PORT_1O;
on tile[MIPI_TILE]:in port p_mipi_rxa = XS1_PORT_1E;
on tile[MIPI_TILE]:in port p_mipi_rxv = XS1_PORT_1I;
on tile[MIPI_TILE]:buffered in port:32 p_mipi_rxd = XS1_PORT_8A;
on tile[MIPI_TILE]:in port p_mipi_rxs = XS1_PORT_1J;

on tile[MIPI_TILE]:clock clk_mipi = XS1_CLKBLK_1;

void exit(int);

void TerminateFail(int x) {
    printf("ERROR %08x\n", x);
}

#define I(counter)    unsafe { uint32_t * unsafe pt = &counter; (*pt)++;}
#define I2(counter,n) unsafe { uint64_t * unsafe pt = &counter; (*pt)+=n;}
uint32_t statusError = 0, headerError = 0, lineCountError = 0, pixelCountError = 0;
uint64_t pixelCounter = 0;
#pragma unsafe arrays
void MipiDecoupler(chanend c, chanend c_kill, chanend c_line) {
    unsigned tailSize, ourWordCount, mipiHeader;
    int line = 0;
    
    unsafe {
        while(1) {
            // Send out a buffer pointer to receiver thread 
            uint8_t * unsafe pt = mipiBuffer[line];
            outuint(c, (unsigned) pt);
            
            /* Packet receive notification - header */
            mipiHeader = inuint(c);
            outuchar(c_line, mipiHeader);
            
            //for (int i = 0; i< 100; i++)
            //    pt[i] = i;

            line = (line + 1) & (MIPI_LINES-1);
            
            /* Long packet */
            if(mipiHeader & 0x30) {
                ourWordCount = inuint(c);
                tailSize = inuint(c);
                if (ourWordCount != 824 && tailSize != 0) {
                    I(pixelCountError);
                }
            }
        }
    }
}

// start_y and start_x must be even, otherwise debayering will fail unceremoniously.
#define start_y  200
#define end_y    (start_y + RAW_IMAGE_HEIGHT*2)
#define start_x  ((3000/4) - RAW_IMAGE_WIDTH)
#define end_x    ((3000/4) + RAW_IMAGE_WIDTH)

uint8_t saveImage[end_y - start_y][end_x - start_x];

uint32_t frame_time = 0, line_time = 0;

struct decoupler_buffer {
    uint8_t y[2 * RAW_IMAGE_WIDTH * 3];
   //uint8_t u[RAW_IMAGE_WIDTH / 2];
    //uint8_t v[RAW_IMAGE_WIDTH / 2];
    int serial;
} decoupler[4];

int8_t bayeredBuffer[4][RAW_IMAGE_WIDTH*2];

unsafe
{
int8_t rgbBuffer[4][RAW_IMAGE_WIDTH*2*3];
}
extern void set_decoupler_r(struct decoupler_buffer x[]);

#pragma unsafe arrays
void MipiImager(chanend c_line, chanend c_decoupler, chanend ?c_decoupler2,
                chanend c_l0) {
    int line = 0;
    int lineCount = 0;
    int last_sof = 0, last_line = 0, now = 0;
    int linesSaved = 0;
    int decoupleCount = 0;
    int errors = 0;
    int grabbing = 0;
    uint8_t new_grabbing = 0;
    int fc = 0;
    unsafe {
        while(1) {
            uint8_t * unsafe pt = mipiBuffer[line];
            uint8_t header_byte;
            select {
                case inuchar_byref(c_line, header_byte):
                    int header = header_byte & 0x3f;
                    line = (line + 1) & 7;
                    if (header == 0) {           // Start of frame
                        lineCount = 0;
                        grabbing = new_grabbing;
                        outuchar(c_l0, fc);
                        outct(c_l0, 1);
                        fc = ~fc;
                    } else if (header == 1) {    // End of frame
                        asm volatile("gettime %0" : "=r" (now));
                        uint32_t * unsafe ft = &frame_time;
                        *ft = now - last_sof;
                        last_sof = now;
                        if (lineCount != 2480) {
                            I(lineCountError);
                        }
                        I2(pixelCounter, 2480 * 3296);
                    } 
                    else if (header == 0x2A) // RAW8
                    { 
                        if (lineCount >= start_y && lineCount < end_y) 
                        {
                            memcpy(bayeredBuffer[linesSaved], pt + start_x, end_x - start_x);
                            linesSaved++;
                            if (linesSaved == 4) 
                            {
                                #if 0
                                debayer_four_lines_yuv((bayeredBuffer, int8_t[]), 2 * RAW_IMAGE_WIDTH,
                                                       (decoupler[decoupleCount].y, int8_t[]),
                                                       (decoupler[decoupleCount].u, int8_t[]),
                                                       (decoupler[decoupleCount].v, int8_t[]));
                                #else
                                // Debayer and subsample 4 lines to 2
                                debayer_four_lines_rgb((bayeredBuffer, int8_t[]), 2* RAW_IMAGE_WIDTH, (rgbBuffer[decoupleCount], int8_t[]));
                                
                                int index = 0;
                                for(int i = 0; i< RAW_IMAGE_WIDTH;i++)
                                {
                                    decoupler[decoupleCount].y[i] = rgbBuffer[decoupleCount][index];
                                    decoupler[decoupleCount].y[i+RAW_IMAGE_WIDTH] = rgbBuffer[decoupleCount][index+RAW_IMAGE_WIDTH*3];
                                    index+=3;
                                }
                                #endif

                                decoupler[decoupleCount].serial = lineCount-start_y;
                               
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
                        if(pt[3298] != 0) {
                            I(statusError);
                        }
                    } 
                    else if (header == 0x12)  // Embedded data - ignore
                    { 
                        if(pt[3298] != 0) 
                        {
                            I(statusError);
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
                    if (error) {
                        I(headerError);
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

struct decoupler_buffer * unsafe decoupler_r;

// Holds a RAW_IMAGE_WIDTH * RAW_IMAGE_HEIGHT Y image, RAW_IMAGE_WIDTH/2 * RAW_IMAGE_HEIGHT/2 U+V images
int8_t saveY[RAW_IMAGE_WIDTH*RAW_IMAGE_HEIGHT];
int8_t saveU[RAW_IMAGE_WIDTH/2 *RAW_IMAGE_HEIGHT/2];
int8_t saveV[RAW_IMAGE_WIDTH/2 *RAW_IMAGE_HEIGHT/2];

extern void set_decoupler_r2(struct decoupler_buffer * decoupler_r2);
struct decoupler_buffer * unsafe decoupler_r2;

#pragma stackfunction 4000
#pragma unsafe arrays
void ImagerUser(chanend c_debayerer, client interface i2c_master_if i2c,
                chanend c_acquire, chanend c_led0, chanend c_led1, chanend c_led2)
{
    int gain = 83 + 0 * GAIN_DEFAULT_DB;
    int partial = 0;
    int yIndex = 0;
    int uvIndex = 0;
    int lineCount = 0;
    int embedderEmpty = 1;
    
    imx219_set_gain_dB(i2c, gain);
    
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
            memcpy(saveY+yIndex, decoupler_r[decoupleCount].y, 2*RAW_IMAGE_WIDTH);
            //memcpy(saveU+uvIndex, decoupler_r[decoupleCount].u, RAW_IMAGE_WIDTH/2);
            //memcpy(saveV+uvIndex, decoupler_r[decoupleCount].v, RAW_IMAGE_WIDTH/2);
        }
        
        yIndex += 2*RAW_IMAGE_WIDTH;
        uvIndex += RAW_IMAGE_WIDTH/2;
        
        if(yIndex >= RAW_IMAGE_WIDTH * RAW_IMAGE_HEIGHT)
        {
            outuchar(c_debayerer, IMAGER_DONTSAMPLE);
            lineCount = 0;
            yIndex = 0;
            uvIndex = 0;
            
            int count1 = 0;
            int max = -200;
            int min = 200;
            for(int y = 3*RAW_IMAGE_HEIGHT/8; y < 5*RAW_IMAGE_HEIGHT/8; y++) {
                for(int x = RAW_IMAGE_WIDTH*3/8; x < RAW_IMAGE_WIDTH * 5/8; x++) {
                    int yVal = saveY[y*RAW_IMAGE_WIDTH+x];
                    if(yVal < min) {
                        min = yVal;
                    }
                    if(yVal > max) {
                        max = yVal;
                    } else if (yVal == max) {
                        count1++;
                    }
                }
            }
            if (max >= 100 && gain > 0) {
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
            
            unsigned cmd;

            select
            {
                case c_acquire :> cmd:

                    send_array(c_acquire, (saveY, uint32_t[]), RAW_IMAGE_WIDTH * RAW_IMAGE_HEIGHT);

                    break;

                default:
                    break;
            } 
            

            outuchar(c_debayerer, IMAGER_SAMPLE);
        }
    }
}

#define TEST_DEMUX_DATATYPE 0
#define TEST_DEMUX_MODE     0x80     // bias
#define TEST_DEMUX_EN       0

#define DELAY_MIPI_CLK 1

void mipi_main(client interface i2c_master_if i2c, chanend c_led0, chanend c_led1, chanend c_led2, chanend c_led3, chanend c_acquire)
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
    if (imx219_stream_start(i2c) != 0) {
        printf("Stream start failed\n");
    }
    set_decoupler_r(decoupler);
    set_decoupler_r2(decoupler);
    par 
    {
        MipiReceive(tile[MIPI_TILE], 1, c, p_mipi_rxd, p_mipi_rxa, c_kill, TEST_DEMUX_EN, TEST_DEMUX_DATATYPE, TEST_DEMUX_MODE, MIPI_CLK_DIV, MIPI_CFG_CLK_DIV);
        MipiDecoupler(c, c_kill, c_img);

        MipiImager(c_img, c_ctrl, null, c_led3);
        ImagerUser(c_ctrl, i2c, c_acquire, c_led0, c_led1, c_led2);
    }
    i2c.shutdown();
}
