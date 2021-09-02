#include <math.h>
#include <stdio.h>
#include <stdint.h>

#define MAX_BOXES 460

float anchors[MAX_BOXES][4] = {
#include "anchors.h"
};



void single_box(uint32_t outputs[4], int8_t be[4], float anchor[4]) {
    float box_encoding[4];
    for(int i = 0; i < 4; i++) {    
        box_encoding[i] = 0.047391898930072784 * (be[i] + 4);
    }

    float y_scale = 10.0;
    float x_scale = 10.0;
    float h_scale = 5.0;
    float w_scale = 5.0;

    float ycenter = box_encoding[0] / y_scale * anchor[2] + anchor[0];
    float xcenter = box_encoding[1] / x_scale * anchor[3] + anchor[1];
    float half_h = 0.5 * exp((box_encoding[2] / h_scale)) * anchor[2];
    float half_w = 0.5 * exp((box_encoding[3] / w_scale)) * anchor[3];

    float ymin = (ycenter - half_h);
    float xmin = (xcenter - half_w);
    float ymax = (ycenter + half_h);
    float xmax = (xcenter + half_w);
    
    int o_width = 300;
    int o_height = 300;

    outputs[0] = xmin * o_width;
    outputs[1] = xmax * o_width;
    outputs[2] = ymin * o_height;
    outputs[3] = ymax * o_height;
}

void box_calculation(uint32_t outputs[4],
                     int8_t classes[MAX_BOXES*2],
                     int8_t boxes[MAX_BOXES*4]) {
    int max_index = 1;
    int max_val = classes[max_index];
    for(int i = 3; i < MAX_BOXES*2; i+= 2) {
        if (classes[i] > max_val) {
            max_index = i;
            max_val = classes[max_index];
        }
    }
    max_index >>= 1;
    single_box(outputs, boxes + 4 * max_index, anchors[max_index]);
}

void test_box_calc(void) {
    int box_idx = 256;
    int8_t box_encoding[4] = {-67, -6, -47, 4}; // box_encodings[box_idx]
    uint32_t outputs[4];
    
    single_box(outputs, box_encoding, anchors[box_idx]);
    for(int i = 0; i< 4; i++) {
        printf("%d ", outputs[i]);
    }
    printf("\n");
}

//int main(void) { test_box_calc();  return 0; }
