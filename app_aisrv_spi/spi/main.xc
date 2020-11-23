#include <platform.h>
#include <stdio.h>
#include <xclib.h>
#include <stdint.h>
#include "qpitest.h"
#include "spitest.h"

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
    
int main(void) {
    chan c_led;
    par {
#if defined(PSOC_INTEGRATION)
        on tile[0]: leds(c_led);
        on tile[1]: spi_remote_test(c_led);
#else
        {
            spi_main(c_led);
            qpi_main(c_led);
            c_led <: -1;
        }
        leds(c_led);
#endif
    }
    return 0;
}
