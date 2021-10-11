#include <xs1.h>
#include <stdio.h>
#include <stdint.h>
#include <platform.h>
#include "leds.h"

void led_driver(chanend c[4], out port p_leds) 
{
    int all = 0;
    while(1) 
    {
        uint8_t value;
        select {
            case(int i = 0; i < 4; i++) inuchar_byref(c[i], value):
                chkct(c[i], 1);
                all = (all & ~(1 << i)) | ((value&1) << i);
                p_leds <: all;
            break;
        }
    }
}
