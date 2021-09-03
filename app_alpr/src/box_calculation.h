#include <stdint.h>

#define MAX_BOXES 460

extern int box_calculation(uint32_t outputs[4],
                           int8_t classes[MAX_BOXES*2],
                           int8_t boxes[MAX_BOXES*4],
                           uint32_t o_width,
                           uint32_t o_height);

extern int ocr_calculation(char outputs[17],
                           int8_t classes[16][66]);
