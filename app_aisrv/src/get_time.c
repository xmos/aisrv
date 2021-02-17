#include "get_time.h"
#include <stdio.h>

#ifdef _TEST_MAIN_
int get_time() {
    return 0;
}

void print_time(char msg[], int time) {
}

#else

int get_time() {
    int a;
    asm volatile ("gettime %0" : "=r" (a));
    return a;
}

void print_time(char msg[], int time) {
    int a;
    asm volatile ("gettime %0" : "=r" (a));
    printf("# TIMING   %s    %f ms\n", msg, (a-time) / 100000.0);
}
#endif
