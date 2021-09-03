#include <math.h>
#include <stdio.h>
#include <stdint.h>
#include "box_calculation.h"

float anchors[MAX_BOXES][4] = {
#include "anchors.h"
};

void single_box(uint32_t outputs[4], int8_t be[4], float anchor[4], uint32_t o_width, uint32_t o_height) {
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
    
    outputs[0] = xmin * o_width;
    outputs[1] = xmax * o_width;
    outputs[2] = ymin * o_height;
    outputs[3] = ymax * o_height;
}

int box_calculation(uint32_t outputs[4],
                    int8_t classes[MAX_BOXES*2],
                    int8_t boxes[MAX_BOXES*4],
                    uint32_t o_width,
                    uint32_t o_height) {
    int max_index = 1;
    int max_val = classes[max_index];
    for(int i = 3; i < MAX_BOXES*2; i+= 2) {
        if (classes[i] > max_val) {
            max_index = i;
            max_val = classes[max_index];
        }
    }
    max_index >>= 1;
    single_box(outputs, boxes + 4 * max_index, anchors[max_index], o_width, o_height);
    return max_val;
}

char ocr_lookup[66] = "0123456789abcdefghijklmnopqrstuvwxyz[]{}@ABCDEFGHJKLMNPQRSTUVWXYZ_";

int ocr_calculation(char outputs[17],
                    int8_t classes[16][66]) {
    int no_character_code = 65;
    int prev_char = -1;
    int outs = 0;
    for(int i = 0; i < 16; i++) {
        int char_code = 0;
        int max_val = classes[i][char_code];
        for(int j = 1; j < 66; j++) {
            if (classes[i][j] > max_val) {
                char_code = j;
                max_val = classes[i][char_code];
            }
        }
        if (char_code == no_character_code || char_code == prev_char) {
            prev_char = char_code;
            continue;
        }
        prev_char = char_code;
        outputs[outs] = ocr_lookup[char_code];
        outs++;
    }
    outputs[outs] = '\0';
    return outs;
}

int ocr_in[66*16] = { 154, 152, 148, 148, 148, 152, 150, 150, 150, 157, 171, 166, 168, 161, 161, 167, 160, 164, 164, 167, 161, 167, 161, 161, 165, 164, 165, 165, 163, 168, 163, 168, 172, 168, 160, 161, 167, 160, 164, 160, 164, 150, 151, 160, 153, 157, 162, 160, 147, 146, 148, 148, 147, 148, 153, 152, 154, 159, 158, 146, 147, 148, 145, 146, 147, 157, 157, 158, 149, 147, 143, 152, 157, 156, 149, 157, 150, 145, 146, 147, 150, 150, 147, 149, 148, 148, 146, 146, 148, 141, 147, 148, 148, 149, 147, 153, 149, 151, 152, 142, 149, 143, 144, 147, 149, 147, 144, 160, 155, 166, 157, 157, 168, 171, 159, 149, 160, 157, 165, 157, 158, 151, 159, 166, 166, 153, 154, 153, 154, 159, 146, 195, 160, 162, 152, 153, 154, 152, 157, 157, 156, 156, 149, 149, 146, 154, 150, 151, 145, 155, 158, 155, 152, 154, 157, 148, 155, 154, 152, 150, 149, 149, 152, 158, 150, 144, 156, 151, 147, 155, 155, 153, 148, 166, 158, 156, 159, 152, 154, 163, 167, 162, 164, 164, 167, 166, 156, 156, 161, 159, 157, 162, 158, 165, 158, 156, 150, 194, 148, 156, 148, 153, 158, 147, 152, 142, 149, 138, 141, 140, 137, 146, 142, 144, 147, 147, 144, 149, 146, 149, 150, 143, 143, 142, 144, 136, 139, 129, 147, 148, 152, 126, 153, 144, 143, 143, 143, 144, 139, 191, 163, 153, 160, 155, 143, 154, 169, 167, 164, 166, 155, 165, 146, 157, 156, 151, 145, 162, 150, 164, 163, 142, 150, 171, 141, 149, 150, 150, 154, 145, 146, 135, 145, 137, 135, 129, 129, 140, 142, 140, 141, 141, 137, 145, 148, 142, 141, 137, 139, 134, 143, 133, 135, 121, 136, 141, 149, 125, 149, 141, 139, 140, 139, 140, 129, 182, 157, 153, 153, 158, 136, 148, 161, 165, 159, 169, 157, 168, 142, 150, 147, 154, 138, 156, 148, 166, 164, 144, 151, 187, 155, 156, 157, 160, 176, 150, 162, 146, 155, 139, 140, 132, 125, 138, 140, 147, 138, 141, 144, 143, 149, 141, 136, 141, 145, 134, 142, 137, 133, 118, 131, 141, 143, 124, 145, 136, 136, 139, 130, 137, 127, 164, 148, 158, 144, 147, 126, 151, 151, 173, 145, 169, 144, 145, 136, 158, 135, 139, 129, 169, 144, 146, 137, 135, 162, 194, 158, 158, 153, 157, 179, 147, 160, 144, 150, 134, 129, 116, 105, 132, 130, 140, 128, 132, 144, 131, 133, 135, 129, 127, 138, 123, 130, 118, 114, 102, 117, 131, 129, 102, 135, 126, 121, 131, 122, 113, 110, 165, 138, 144, 145, 136, 113, 145, 154, 168, 144, 162, 134, 144, 134, 159, 132, 129, 124, 173, 143, 141, 129, 125, 157, 160, 147, 137, 139, 147, 151, 151, 150, 146, 179, 152, 143, 137, 128, 140, 130, 140, 134, 144, 144, 144, 142, 137, 131, 137, 152, 138, 137, 131, 127, 123, 132, 141, 133, 117, 140, 127, 125, 139, 125, 130, 122, 141, 162, 138, 131, 136, 113, 165, 140, 130, 141, 125, 139, 149, 133, 153, 160, 157, 115, 148, 134, 145, 138, 128, 128, 186, 152, 145, 141, 153, 152, 153, 156, 154, 183, 153, 142, 139, 134, 143, 137, 144, 144, 147, 144, 145, 148, 143, 138, 142, 156, 142, 139, 132, 126, 129, 138, 141, 138, 129, 150, 127, 138, 141, 129, 124, 131, 142, 164, 139, 133, 139, 115, 168, 141, 137, 148, 132, 144, 154, 136, 156, 165, 159, 124, 156, 145, 154, 146, 141, 136, 148, 152, 149, 146, 168, 166, 175, 179, 152, 160, 147, 153, 147, 140, 150, 146, 154, 155, 151, 150, 154, 150, 148, 150, 151, 152, 151, 152, 149, 147, 127, 151, 147, 144, 130, 151, 150, 137, 145, 152, 148, 147, 153, 155, 149, 137, 159, 147, 166, 161, 150, 164, 154, 150, 157, 139, 154, 154, 159, 148, 157, 148, 151, 143, 146, 144, 196, 144, 149, 146, 170, 164, 181, 192, 152, 160, 142, 139, 142, 134, 139, 136, 144, 140, 145, 139, 145, 140, 138, 142, 140, 140, 132, 140, 130, 138, 123, 138, 136, 142, 126, 144, 137, 137, 141, 146, 129, 133, 144, 155, 140, 123, 159, 147, 170, 149, 132, 159, 144, 140, 137, 133, 144, 147, 160, 144, 144, 137, 134, 128, 141, 142, 153, 161, 165, 159, 168, 167, 168, 174, 174, 159, 156, 151, 151, 147, 152, 152, 156, 156, 157, 151, 159, 156, 154, 159, 150, 154, 144, 152, 147, 158, 143, 152, 152, 155, 143, 156, 162, 150, 148, 150, 141, 146, 159, 156, 157, 153, 162, 170, 164, 156, 160, 158, 158, 160, 158, 160, 160, 161, 158, 170, 158, 152, 157, 146, 159, 164, 196, 158, 160, 147, 156, 150, 143, 155, 184, 145, 148, 145, 151, 143, 135, 134, 143, 141, 149, 140, 142, 142, 144, 147, 135, 143, 136, 142, 132, 142, 140, 144, 145, 146, 127, 151, 144, 138, 140, 141, 133, 134, 143, 148, 135, 157, 136, 155, 147, 144, 156, 146, 134, 146, 148, 159, 150, 156, 135, 176, 153, 153, 151, 133, 157, 166, 152, 161, 165, 155, 157, 155, 158, 163, 171, 159, 168, 158, 163, 157, 152, 150, 157, 156, 161, 156, 157, 153, 158, 161, 153, 162, 159, 159, 153, 154, 157, 164, 159, 160, 149, 159, 151, 155, 156, 156, 153, 152, 160, 154, 160, 159, 155, 168, 165, 162, 153, 163, 155, 159, 169, 168, 163, 169, 170, 175, 156, 166, 166, 160, 163, 159, 199, 160, 164, 151, 150, 146, 160, 156, 156, 177, 182, 148, 148, 146, 145, 145, 143, 146, 145, 143, 150, 150, 146, 152, 144, 149, 151, 147, 142, 144, 142, 144, 145, 144, 135, 153, 138, 139, 147, 152, 142, 143, 159, 166, 167, 156, 156, 163, 173, 165, 139, 150, 151, 162, 163, 173, 163, 176, 187, 157, 150, 165, 160, 158, 160, 141, 161, 163, 166, 165, 165, 159, 162, 163, 169, 170, 171, 161, 159, 160, 160, 160, 158, 162, 159, 159, 161, 158, 160, 162, 156, 162, 164, 163, 160, 158, 162, 160, 160, 161, 160, 162, 155, 158, 158, 160, 158, 158, 166, 168, 165, 165, 165, 167, 164, 173, 163, 172, 167, 173, 174, 171, 161, 172, 170, 167, 166, 168, 175, 174, 174, 166, 194, };

int xxkmain(void) {
    int8_t ocr_b[16][66];
    char outs[17];
    int num = 0;
    for(int i = 0; i < 16; i++) {
        for(int j = 0; j < 66; j++) {
            ocr_b[i][j] = ocr_in[num]-128;
            num += 1;
        }
    }
    int l = ocr_calculation(outs, ocr_b);
    printf("%d >>>%s<<<\n", l, outs);
    return 0;
}
void test_box_calc(void) {
    int box_idx = 256;
    int8_t box_encoding[4] = {-67, -6, -47, 4}; // box_encodings[box_idx]
    uint32_t outputs[4];
    
    single_box(outputs, box_encoding, anchors[box_idx], 320, 320);
    for(int i = 0; i< 4; i++) {
        printf("%d ", outputs[i]);
    }
    printf("\n");
}

//int main(void) { test_box_calc();  return 0; }
