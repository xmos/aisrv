#include <xs1.h>

void spi_xcore_ai_slave(in port p_cs, in port p_clk,
                        buffered port:32 ?p_miso,
                        buffered port:32 p_mosi,
                        clock clkblk, chanend led);
    
