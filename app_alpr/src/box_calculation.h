#include <stdint.h>

#define MAX_BOXES 460

void box_calculation(uint32_t outputs[4],
                     int8_t classes[MAX_BOXES*2],
                     int8_t boxes[MAX_BOXES*4]);
