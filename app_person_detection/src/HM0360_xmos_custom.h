// These are the settings we need to change from default initial reg setup to support our application.
// Things we change:
// Output bit width from 8bit to 1bit.
// Clocks - we have to run sensor core at input clock / 8 now as using serial output.
// Pixel clock gating.
// Remember the default Himax setup is using context switch A regs for setup so we must use those too.
static hm0360_settings_t xmos_custom[] = {

    // Comment next line out for int clock mode.
    //{ 0x3500, 0x07 }, /* Context Switch A - PLL1CFG - For serial data output we need PCLKO = 8x Sensor_core freq. So Set PCLKO = /1 (Fastest) and Sensor_core = /8. */

    { 0x3511, 0x00 }, /* Context Switch A - EMBEDDED_LINE_EN - Turning off embedded line enable. */

    // { 0x0601, 0x01 }, /* TEST_PATTERN_MODE - test pattern enabled - colour bar */
    // { 0x0602, 0x00 }, /* TEST_DATA_BLUE_H */
    // { 0x0603, 0xD0 }, /* TEST_DATA_BLUE_L */
    // { 0x0604, 0x00 }, /* TEST_DATA_GB_H */
    // { 0x0605, 0xD0 }, /* TEST_DATA_GB_L */
    // { 0x0606, 0x00 }, /* TEST_DATA_GR_H */
    // { 0x0607, 0xD0 }, /* TEST_DATA_GR_L */
    // { 0x0608, 0x00 }, /* TEST_DATA_RED_H */
    // { 0x0609, 0xD0 }, /* TEST_DATA_RED_L */

    // VSYNC/HSYNC/Pixel shift and PCLKO gated mode
    { 0x1014, 0x08 }, /* OPFM_CTRL - Sets PCLKO to be gated, VSYNC and HSYNC shifts disabled. */
    
    // Adjustment for PCLKO gating signal. We want clock to be aligned with FVLD and LVLD so set all these to 0.
    // { 0x3094, 0x00 },
    // { 0x3095, 0x00 },
    // { 0x3096, 0x00 },
    // { 0x3097, 0x00 },
    // { 0x3098, 0x00 },
    // { 0x3099, 0x00 },
    
    // { 0x309F, 0x00 },
    // { 0x30A0, 0x00 },
    // { 0x30A1, 0x00 },
    // { 0x30A2, 0x00 },
    // { 0x30A3, 0x00 },
    // { 0x30A4, 0x00 },

    // IO and clock control regs
    { 0x309E, 0x02 }, /* PCLKO_GATED_EN - Sets PCLKO gated by line. */
    { 0x3110, 0xC4 }, /* Sets output pins to drive mode (low) when in standby or frame blanking rather than hi-Z */
    { 0x310E, 0x00 }, /* Sets output pins to drive mode (low) when in standby or frame blanking rather than hi-Z */
    { 0x310F, 0x80 }, /* This sets 1-bit interface bit width. */

    // Command Update
    { 0x0104, 0x01 }, /* This write causes frame sensitive registers to be updated. */

};