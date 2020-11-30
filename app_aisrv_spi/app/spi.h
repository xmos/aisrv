#ifndef _SPI_H_
#define _SPI_H_

#include <xs1.h>
#include "shared_memory.h"

void spi_xcore_ai_slave(in port p_cs, in port p_clk,
                        buffered port:32 ?p_miso,
                        buffered port:32 p_mosi,
                        clock clkblk, chanend led,
                        chanend to_buffer,
                        struct memory * unsafe mem);
    
#endif
