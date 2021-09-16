#include <stdio.h>
#include <stdint.h>
#include <string.h>

void transform_line(int8_t outp[3][160], uint8_t line[]) {
    for(int ox = 0; ox < 160; ox ++) {
        int x = ox;
        int Y = line[2*x];
        int UV0 = line[x == 159 ? 2*x - 3 : 2*x+1];
        int UV1 = line[x == 0 ? 2*x + 3 : 2*x-1];
        int U, V;
        if ((x & 1) == 1) {
            U = UV0; V = UV1;
        } else {
            U = UV1; V = UV0;
        }
        Y -= 128;
        U -= 128;
        V -= 128;
        int R = Y + ((          292 * V) >> 8);
        int G = Y - ((100 * U + 148 * V) >> 8);
        int B = Y + ((520 * U          ) >> 8);
        if (R < -128) R = -128; if (R > 127) R = 127;
        if (G < -128) G = -128; if (G > 127) G = 127;
        if (B < -128) B = -128; if (B > 127) B = 127;
        outp[0][x] = R;
        outp[1][x] = G;
        outp[2][x] = B;
    }
}

int16_t shift_8[16] = {
    6, 6, 6, 6, 6, 6, 6, 6,
    6, 6, 6, 6, 6, 6, 6, 6,
};

void p(int8_t x[32]) {
    for(int i = 0; i < 32; i++) {
        printf("%02x ", x[i]&0xff);
    }
    printf("\n");
}

#pragma unsafe arrays

extern void transform_part_line_vpu_asm(int8_t outp[3][160], uint8_t line[], int8_t coefficients[], uint32_t strides[], int ox, int indexc);
void transform_part_line_vpu(int8_t outp[3][160], uint8_t line[], int8_t coefficients[], uint32_t strides[], int ox, int indexc) {
#pragma loop unroll(3)
    for(int rgb = 0; rgb < 3; rgb++) {
        asm volatile("vclrdr");
#pragma loop unroll(16)
        for(int j = 0; j < 16; j++) {
            asm volatile("vldc %0[0]" :: "r" (&coefficients[indexc]));
            indexc+=32;
            asm volatile("vlmaccr %0[0]" :: "r" (&line[strides[ox+j]]));
        }
        asm volatile("vlsat %0[0]" :: "r" (shift_8));
        asm volatile("vdepth8");
        asm volatile("vstrpv %0[0], %1" :: "r" (&outp[rgb][ox]), "r" (0xFFFF));
    }
}

void transform_line_vpu(int8_t outp[3][160], uint8_t line[], int8_t coefficients[], uint32_t strides[], int nox) {
    int8_t outp2[3][160];
    int t0, t1;
    memset(outp2, 0xff, 3*160);
    asm("gettime %0" : "=r" (t0));
    for(int ox = 0; ox < 80; ox ++) {
        (line, uint32_t[])[ox] ^= 0x80808080;
    }
    int indexc = 0;
    for(int ox = 0; ox < nox; ox +=16) {
//        transform_part_line_vpu(outp2, line, coefficients, strides, ox, indexc);
        transform_part_line_vpu_asm(outp, line, coefficients, strides, ox, indexc);
        indexc += 16 * 3 * 32;
    }
    asm("gettime %0" : "=r" (t1));
//    printf("%d\n", t1 - t0);
#if 0
    for(int i = 0; i < nox; i++) {
        for(int rgb = 0; rgb < 3; rgb++) {
            if (outp[rgb][i] != outp2[rgb][i]) {
                printf("Bad %d %d  %d %d\n", i, rgb, outp[rgb][i], outp2[rgb][i]);
            }
        }
    }
#endif   
}

uint8_t morph(uint8_t x) {
    int z = x;
    z = z - 128;
    if (z < 0) {
        z += 256;
    }
    return z;
}

uint8_t inputs[38400] = {
    #include "yuv.h"
};

uint8_t gaussian[65] = {
  0,  0,  0,  0,  1,  1,  1,  2,  3,  4,  6,  8, 11, 15, 20, 27,
  35, 44, 55, 68, 83, 99,117,136,155,175,193,211,226,239,248,254,
  255,
  254,248,239,226,211,193,175,155,136,117, 99, 83, 68, 55, 44, 35,
  27, 20, 15, 11,  8,  6,  4,  3,  2,  1,  1,  1,  0,  0,  0,  0,
};

#define MAX_OUTPUT_WIDTH   160

int round_down(int multiplier) {
    int v = (multiplier + 256) >> 9;
    if (v >  127) return  127;
    if (v < -128) return -128;
    return v;
}

static void calculate_ratios(int &ratio, int &ratio_inverse, int in_points, int out_points) {
    ratio = 65536 * (in_points - 1) / (out_points - 1); // in Q.16 format
    ratio_inverse = 65536 * (out_points - 1) / (in_points - 1); // in Q.16 format
}

static int mkgaussian(int window_val[], int i, int start_x, int &pos_centre, int &int_pos_centre, int ratio, int ratio_inverse) {
    int window_width = (ratio >> 16) + 1;
    int sum = 0;
    pos_centre = i * ratio + (start_x << 16);
    int_pos_centre = pos_centre & 0xFFFF0000;
    for(int window_index = - window_width; window_index <= window_width; window_index++) {
        int pos = pos_centre - (window_index << 16);
        int64_t l = ((int64_t)(pos - int_pos_centre)) * ratio_inverse;
        int location_in_window = (l + (1<<27)) >> 28;
        int gauss = 0;
        if (location_in_window >= -32 && location_in_window <= 32) {
            gauss = gaussian[location_in_window + 32];
        }
        window_val[window_index + window_width] = gauss;
        sum += gauss;
    }
    int normalisation = 0x2000000 / sum;
    for(int k = 0; k < 2 * window_width + 1; k++) {
        window_val[k] = (window_val[k] * normalisation) >> 16;
    }
    return window_width;
}

void build_coefficients_strides(int8_t coefficients[32*MAX_OUTPUT_WIDTH*3],
                                uint32_t strides[MAX_OUTPUT_WIDTH],
                                int start_x, int end_x, int points) {
    memset(coefficients, 0, 32*MAX_OUTPUT_WIDTH*3);
    int ratio, ratio_inverse;
    calculate_ratios(ratio, ratio_inverse, end_x - start_x, points);
    int window_val[40];
            // ratio: 1  gaussian width 1
    int Y[3] = {64,  64,  64};   // Equal contributions of Y to R, G, and B
    int U[3] = { 0, -25, 127};   // R gets no contribution from U, G and B do
    int V[3] = {73, -37,   0};   // B gets no contribution from V, R and G do
    for(int i = 0; i < points; i++) {
        int pos_centre, int_pos_centre;
        int window_width = mkgaussian(window_val, i, start_x, pos_centre, int_pos_centre, ratio, ratio_inverse);
        int left_point = (int_pos_centre >> 16) - window_width;
        int stride_point = left_point;
        if (stride_point < 0) {
            stride_point = 0;
        }
        int index = (i & ~0xF) + 15 - (i & 0xF);
        strides[index] = (stride_point >> 1) * 4;
        int registered_stride_point = (strides[index] / 4)*2;
        int print = 0 && (strides[index] == 0);
        if (print) printf("pos_centre %f %d\n", pos_centre / 65536.0, int_pos_centre >> 16);
        if (print) printf("@@@@@@@@@@ %d %d\n", int_pos_centre >> 16, left_point);
        for(int rgb = 0; rgb < 3; rgb++) {
            int cindex = (i & ~0xF) *3 + 15 - (i & 0xF);
            for(int window_index = - window_width; window_index <= window_width; window_index++) {
                int gauss = window_val[window_index + window_width];
                if (print) printf("%d %d\n", window_index, gauss);
                int base_location = 2 * (left_point - registered_stride_point + window_width + window_index);
                if (base_location < 0) {
                    base_location = 0;
                } else if (base_location >= 32) {
                    base_location = 30;
                }
                int coefficient_location = base_location;
                int coefficient_base =  (cindex + rgb*16)*32;
                int coefficient_location_plus_one = coefficient_location + 1;
                int coefficient_location_minus_one = coefficient_location - 1;
                if (coefficient_location_minus_one < 0) {
                    coefficient_location_minus_one += 4;
                }
                coefficient_location_minus_one += coefficient_base;
                coefficient_location           += coefficient_base;
                coefficient_location_plus_one  += coefficient_base;
                if (print) {
                    printf("** %d %d %d", coefficient_location_minus_one, coefficient_location, coefficient_location_plus_one);
                    printf("   %d %d\n", rgb, window_index);
                }
                coefficients[coefficient_location] += round_down(gauss * Y[rgb]);
                int Vval = round_down(gauss * V[rgb]);
                int Uval = round_down(gauss * U[rgb]);
                
                if (base_location & 2) { // blue may overflow to 127+
                    coefficients[coefficient_location_plus_one] += Uval;
                    if (coefficients[coefficient_location_plus_one] < 0 && rgb == 2) {
                        coefficients[coefficient_location_plus_one] = 127;
                    }
                    coefficients[coefficient_location_minus_one] += Vval;
                } else {
                    coefficients[coefficient_location_plus_one] += Vval;
                    coefficients[coefficient_location_minus_one] += Uval;
                    if (coefficients[coefficient_location_minus_one] < 0 && rgb == 2) {
                        coefficients[coefficient_location_minus_one] = 127;
                    }
                }
            }
        }
    }
}


int main(void) {
    uint8_t line[320];
//    int8_t outp[3][160];
    int8_t outp2[3][160];
    int8_t coefficients[32*160*3];
    uint32_t strides[160];

    
    build_coefficients_strides(coefficients, strides, 3, 40, 32);
    if(0)for(int i = 13; i < 16; i++) {
        printf("**%d\n", strides[i]);
        for(int j = 0; j < 16; j++) {
            for(int rgb = 0; rgb < 3; rgb++) {
                int index = (i & ~0xF)*3 + (i & 0xF);
                printf(" %4d", coefficients[(index + rgb*16)*32 + j]);
            }
            printf("\n");
        }
        printf("\n");
    }
//    build_coefficients_strides_5x(coefficients, strides);
    printf("P3\n32 32 255\n");
    int index = 0;
    for(int j = 0; j < 32; j++) {
        for(int i = 0; i < 320; i++) {
            line[i] = morph(inputs[index]);
            index++;
        }
//        transform_line(outp, line);
        transform_line_vpu(outp2, line, coefficients, strides, 32);
        for(int i = 0; i < 32; i++) {
            printf("%d %d %d ", outp2[0][i]+128,  outp2[1][i]+128,  outp2[2][i]+128);
        }
        printf("\n");
    }
    return 0;
}
