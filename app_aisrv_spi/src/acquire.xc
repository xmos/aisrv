#include <stdio.h>
#include <stdint.h>
#include "acquire.h"
#include "aisrv.h"

#define SENSOR_DATA_BYTES       20

static int cnt = 0;

static void acquire_data(chanend to_sensor, uint32_t buffer[], int length) {
    for(int i = 0; i < SENSOR_DATA_BYTES / 4; i++) {
        buffer[i] = i + cnt;
    }
    cnt += 256;
}

void acquire_init(chanend to_sensor, struct memory * unsafe mem) {
    unsafe {
        mem->spec[SPEC_SENSOR_TENSOR_LENGTH] = SENSOR_DATA_BYTES;
        mem->sensor_tensor_length = SENSOR_DATA_BYTES / 4;
    }
}

void acquire(chanend from_buffer, chanend to_sensor, struct memory * unsafe mem) {
    acquire_init(to_sensor, mem);
    while(1) {
        int cmd;
        from_buffer :> cmd;
        switch(cmd) {
        case CMD_START_ACQUIRE:
            unsafe {
                acquire_data(to_sensor,
                             &mem->memory[mem->input_tensor_index],
                             mem->sensor_tensor_length);
            }
            from_buffer <: 0;
            break;
        default:
            printf("Error in acquire: cmd = 0x%02x\n", cmd);
            break;
        }
    }
}
