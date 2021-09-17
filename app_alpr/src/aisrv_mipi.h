#ifndef _AISRV_MIPI_H_
#define _AISRV_MIPI_H_

#define RAW_IMAGE_HEIGHT (320)
#define RAW_IMAGE_WIDTH  (320)
#define RAW_IMAGE_DEPTH  (3)

#ifdef GC2145
#define SENSOR_IMAGE_HEIGHT (1200)
#define SENSOR_IMAGE_WIDTH  (1600)
#else
#define SENSOR_IMAGE_HEIGHT (480)
#define SENSOR_IMAGE_WIDTH  (640)
#endif

#define SENSOR_IMAGE_DEPTH  (2)          // YUV: YU  YV  YU  YV  ...

#include "i2c.h"

void mipi_main(client interface i2c_master_if i2c, chanend c_to_network[], int n_networks);

#endif
