#ifndef _AISRV_CONF_H_
#define _AISRV_CONF_H_

#define INT_MEM_SIZE_BYTES          (2300000)
#define MAX_MODEL_SIZE_EXT_BYTES    (10224000)

#define NETWORK_NUM_THREADS         (1)

#define AISRV_GPIO_LENGTH           (4)

#define RAW_IMAGE_HEIGHT (300)
#define RAW_IMAGE_WIDTH  (300)
#define RAW_IMAGE_DEPTH  (3)

#define SENSOR_IMAGE_HEIGHT (480)
#define SENSOR_IMAGE_WIDTH  (640)
#define SENSOR_IMAGE_DEPTH  (2)          // YUV: YU  YV  YU  YV  ...

#endif
