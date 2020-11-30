#include <stdio.h>
#include <stdint.h>
#include "acquire.h"
#include "aisrv.h"

static void acquire_data(uint32_t buffer[], int length) {
}

void acquire(chanend from_buffer, struct memory * unsafe mem) {
    while(1) {
        int cmd;
        from_buffer :> cmd;
        switch(cmd) {
        case CMD_START_ACQUIRE:
            unsafe {
                acquire_data(&mem->memory[mem->input_tensor_index], mem->input_tensor_length);
            }
            from_buffer <: 0;
            break;
        default:
            printf("Error in acquire: cmd = 0x%02x\n", cmd);
            break;
        }
    }
}
