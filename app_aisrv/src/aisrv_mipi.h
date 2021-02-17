
#ifndef _AISRV_MIPI_H_
#define _AISRV_MIPI_H_

#include "i2c.h"

//void mipi_main(client interface i2c_master_if i2c, chanend c);
void mipi_main(client interface i2c_master_if i2c, chanend c_led0, chanend c_led1, chanend c_led2, chanend c_led3, chanend c_to_network);

#endif
