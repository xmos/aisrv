#include <xs1.h>
#include <platform.h>
#include <stdio.h>
#include <print.h>
#include <xscope.h>
#include <stdint.h>
#include "debayer.h"
#include "i2c.h"
#include "xs1.h"
#include "aisrv_mipi.h"

on tile[0]:          out port   p_reset    = XS1_PORT_4F; // XSLEEP on bit 3. XSHUTDOWN on bit 2. WIFI_CS_N on bit 1. bit 0 not bonded out.

// Tile 1 Ports: Camera Interface
on tile[1]: buffered in  port:8 p_cam_pdat = XS1_PORT_1A; // Pixel data from camera
on tile[1]:          in  port   p_cam_pclk = XS1_PORT_1B; // Pixel clock from camera
on tile[1]:          in  port   p_cam_lvld = XS1_PORT_1C; // Line valid from camera (shouldn't need this)
on tile[1]:          in  port   p_cam_fvld = XS1_PORT_4A; // Frame valid from camera (In bit 3)

// Clock blocks
on tile[1]: clock clk_cam_pclk = XS1_CLKBLK_1; // Pixel clock in

// Global defs
#define IMAGE_WIDTH  640
#define IMAGE_HEIGHT 480

// Sensor is Himax HM0360 640x480 1/6" CMOS Image Sensor
// HM0360 I2C slave address
#define HM0360_I2C_SLAVE_ADDR   0x24

// HM0360 useful register addresses
#define HM0360_MODEL_ID_H_ADDR      0x0000
#define HM0360_MODEL_ID_L_ADDR      0x0001
#define HM0360_SILICON_REV_ADDR     0x0002
#define HM0360_MODE_SELECT_ADDR     0x0100
#define HM0360_SW_RESET_ADDR        0x0103
#define HM0360_COMMAND_UPDATE_ADDR  0x0104

// HM0360 useful defines
#define HM0360_MODEL_ID_H         0x03
#define HM0360_MODEL_ID_L         0x60
#define HM0360_SILICON_REV        0x01

// HM0360 modes (Software Triggered)
#define HM0360_MODE_SLEEP1        0x00 // Device in sleep - no pixel data output.
#define HM0360_MODE_SW_CONT       0x01 // Continuous streaming (Software I2C triggered).
#define HM0360_MODE_SW_SNAPSHOT   0x03 // Snapshot of N frames (Software I2C triggered).

// App PLL setup
#define APP_PLL_CTL_BYPASS    0   // 1 = bypass.
#define APP_PLL_CTL_INPUT_SEL 0   // 0 - XTAL, 1 - sysPLL
#define APP_PLL_CTL_ENABLE    1   // 1 = enabled.
#define APP_PLL_CTL_OD        0   // Output divider = (OD+1)
#define APP_PLL_CTL_F         59  // FB divider = (F+1)/2
#define APP_PLL_CTL_R         0   // Ref divider = (R+1)

#define APP_PLL_DIV_INPUT_SEL   1   // 0 - sysPLL, 1 - app_PLL
#define APP_PLL_DIV_DISABLE     0   // 1 - disabled (pin connected to X1D11), 0 - enabled divider output to pin.
#define APP_PLL_DIV_VALUE       14  // Divide by N+1 - remember there's a /2 also for 50/50 duty cycle.

#define APP_PLL_CTL  ((APP_PLL_CTL_BYPASS << 29) | (APP_PLL_CTL_INPUT_SEL << 28) | (APP_PLL_CTL_ENABLE << 27) | (APP_PLL_CTL_OD << 23) | (APP_PLL_CTL_F << 8) | APP_PLL_CTL_R)
#define APP_PLL_DIV  ((APP_PLL_DIV_INPUT_SEL << 31) | (APP_PLL_DIV_DISABLE << 16) | APP_PLLq_DIV_VALUE)

typedef struct {
    uint16_t addr;
    uint8_t val;
} hm0360_settings_t;

#include "HM0360_1BIT_BAYER_JEG_15fps_intOSC_MODE.h"
#include "HM0360_xmos_custom.h"

static hm0360_settings_t start[] = {
    // Mode Select
    { HM0360_MODE_SELECT_ADDR, HM0360_MODE_SW_CONT }, /* MODE_SELECT - This sets mode: Continuous streaming (
after this software I2C write as trigger). */
};

static hm0360_settings_t stop[] = {
    // Mode Select
    { HM0360_MODE_SELECT_ADDR, HM0360_MODE_SLEEP1 }, /* MODE_SELECT - This sets mode to SLEEP1 (Standby). */
};

static hm0360_settings_t aec_retarget[] = {
    // Mode Select
    { 0x2034, 0x30 },  /* reduce AEC target */
};

static int i2c_read(client interface i2c_master_if i2c, int reg) {
    i2c_regop_res_t result;
    char read_data;

    read_data = i2c.read_reg8_addr16(HM0360_I2C_SLAVE_ADDR, reg, result);
    if (result != I2C_REGOP_SUCCESS) {
        printf("I2C reg read failed on address %04x\n", reg);
    }
    return result != I2C_REGOP_SUCCESS ? -1 : read_data;
}

static int i2c_write(client interface i2c_master_if i2c, int reg, int value) {
    i2c_regop_res_t result;  
    result = i2c.write_reg8_addr16(HM0360_I2C_SLAVE_ADDR, reg, value);
    if (result != I2C_REGOP_SUCCESS) {
        printf("I2C reg write failed on address %04x value %02x\n", reg, value);
    }
    return result != I2C_REGOP_SUCCESS ? -1 : 0;
}

static int i2c_write_table(client interface i2c_master_if i2c, hm0360_settings_t table[], int N) {
    int ret;
    for(int i = 0; i < N; i++) {
        uint32_t address = table[i].addr;
        uint32_t value   = table[i].val;
        ret = i2c_write(i2c, address, value);
        if (ret < 0) {
            return ret;
        }
    }
    return 0;
}

// Check I2C Comms with the sensor
int hm0360_check_comms(client interface i2c_master_if i2c) {
    if (i2c_read(i2c, HM0360_MODEL_ID_H_ADDR) == HM0360_MODEL_ID_H) {
        if (i2c_read(i2c, HM0360_MODEL_ID_L_ADDR) == HM0360_MODEL_ID_L) {
            if (i2c_read(i2c, HM0360_SILICON_REV_ADDR) == HM0360_SILICON_REV) {
              //printf("HM0360 comms check ok\n");
              return 0;
            }
        }
    }
    return -1;
}

int hm0360_stream_stop(client interface i2c_master_if i2c) {
    return i2c_write_table(i2c, stop, sizeof(stop) / sizeof(stop[0]));
}

int hm0360_stream_restart(client interface i2c_master_if i2c) {
    return i2c_write_table(i2c, start, sizeof(start) / sizeof(start[0]));
}

int hm0360_stream_start(client interface i2c_master_if i2c) {
    int ret;
    
    // Check I2C comms with HM0360
    ret = hm0360_check_comms(i2c);
    if (ret < 0) {
        return ret;
    }
    // Write the initial reg settings from Himax
    ret = i2c_write_table(i2c, chip_set_up, sizeof(chip_set_up) / sizeof(chip_set_up[0]));
    if (ret < 0) {
        return ret;
    }
    // Write the custom reg settings for xmos application
    ret = i2c_write_table(i2c, xmos_custom, sizeof(xmos_custom) / sizeof(xmos_custom[0]));
    if (ret < 0) {
        return ret;
    }
    ret = i2c_write_table(i2c, xmos_custom, sizeof(aec_retarget) / sizeof(aec_retarget[0]));
    if (ret < 0) {
        return ret;
    }
    // Start streaming
    return i2c_write_table(i2c, start, sizeof(start) / sizeof(start[0]));
}

void hm0360_reset() {
    // This setup is for when using image sensor internal oscillator - CLK_SEL low:
    // Probably not required, device should do its own POR.
    p_reset <: 0x2; // XSHUTDOWN and XSLEEP both low. Full hardware shutdown "Power Off".
    delay_milliseconds(1);
    p_reset <: 0x6; // XSHUTDOWN high XSLEEP low. Device does a POR and goes into deep sleep (SLEEP2).
    delay_milliseconds(1);
    p_reset <: 0xE; // XSHUTDOWN and XSLEEP both high. Device goes into software sleep (SLEEP1). Can now accept I2C transactions.
    delay_milliseconds(1);
}


void hm0360_monolith_init() {
    // Set up ports
    configure_clock_src(clk_cam_pclk, p_cam_pclk);
    configure_in_port_strobed_slave(p_cam_pdat, p_cam_lvld, clk_cam_pclk);
    start_clock(clk_cam_pclk);
    
    set_port_pull_up(p_cam_fvld);

    delay_milliseconds(1000); // Wait a while for Auto exposure to sort things out - needs a few frames of negative feedback.
}

void hm0360_monolith_single(client interface i2c_master_if i2c, uint8_t * unsafe pt) {
//    hm0360_stream_restart(i2c);
    // Wait for a falling edge on frame valid (bit 3).
    p_cam_fvld when pinseq(0xF) :> void;    // not needed?
    p_cam_fvld when pinseq(0x7) :> void;
    // Make sure port buffer is clear before capturing new frame (there may have been toggles of clock during startup)
    clearbuf(p_cam_pdat);
    // Capture the image
    int k = 0;
    for(int i = 0; i < IMAGE_HEIGHT; i++) {
        for(int j = 0; j < IMAGE_WIDTH; j++) {
            int x;
            p_cam_pdat :> x;
            unsafe {
                if(i<460)
                pt[k++] = x ^ 0x80;
            }
        }
    }
//    hm0360_stream_stop(i2c);
}


#define BAYER_WIDTH   640
#define BAYER_HEIGHT  480
#define RGB_WIDTH   (BAYER_WIDTH/2)
#define RGB_HEIGHT  (BAYER_HEIGHT/2)
#define RGB4_WIDTH  256
#define RGB4_HEIGHT 192

#define SCALE   (RGB_HEIGHT/(float)RGB4_HEIGHT)
#define YOFFSET 0
#define XOFFSET ((RGB_WIDTH - RGB4_WIDTH*SCALE) *0.5)

void hm0360_monolith_rgb(client interface i2c_master_if i2c, uint8_t * unsafe pt) {
    unsafe {
    int8_t * unsafe rgb4 = (int8_t * unsafe ) pt;
    int8_t * unsafe rgb = rgb4 + RGB_WIDTH * 3 * 2;
    int8_t * unsafe input_image = rgb + BAYER_WIDTH * 2;
    unsigned t0, t1, t2, t3;
    asm volatile ("gettime %0" : "=r" (t0));
    hm0360_monolith_single(i2c, input_image);
    asm volatile ("gettime %0" : "=r" (t1));
    for(int y = 0; y < BAYER_HEIGHT; y += 4) {
        debayer_four_lines_rgb(input_image + y * BAYER_WIDTH, BAYER_WIDTH, rgb + y/2 * 3 * RGB_WIDTH);
    }
    asm volatile ("gettime %0" : "=r" (t2));
    int8_t * unsafe rgb4_p = rgb4;
    for(int y = 0; y < RGB4_HEIGHT; y ++) {
        float fy = y * SCALE + YOFFSET;
        int iy = fy;
        float fracy1 = fy - iy;
        for(int x = 0; x < RGB4_WIDTH; x ++) {
            float fx = x * SCALE + XOFFSET;
            int ix = fx;
            float fracx1 = fy - iy;
            int8_t * unsafe rgb_p = rgb + ( iy * RGB_WIDTH + ix ) * 3;
            for(int k = 0; k < 3; k++) {
                rgb4_p[k] = ((rgb_p[k]               * (1-fracx1) +
                              rgb_p[k+3]             * fracx1) * (1-fracy1) +
                             (rgb_p[k+  3*RGB_WIDTH] * (1-fracx1) +
                              rgb_p[k+3+3*RGB_WIDTH] * fracx1) * fracy1);
            }
            rgb4_p[3] = 0;
            rgb4_p += 4;
        }
    }
    asm volatile ("gettime %0" : "=r" (t3));
    printint((t1-t0)/100); printchar(' ');
    printint((t2-t1)/100); printchar(' ');
    printintln((t3-t2)/100);
    }
}

extern void send_array(chanend c, uint32_t * unsafe array, unsigned size);

void hm0360_main(client interface i2c_master_if i2c, chanend c_acquire) {
    uint8_t * unsafe pt;
    uint32_t empty_array[1];
    uint32_t cmd;
    while(1) {
        c_acquire :> cmd;
        if (cmd != 0x8c) {
            printint(cmd);
            printstr(" unknown command\n");
            continue;
        }
        unsafe {
            c_acquire :> pt;
//            printhexln(pt);
            for(int i = 0; i < 6; i += 1) {
                c_acquire :> int _;
            }
            hm0360_monolith_rgb(i2c, pt);
            send_array(c_acquire, empty_array, 0);
        }
    }
}
