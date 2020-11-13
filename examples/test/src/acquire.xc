#include <stdio.h>
#include <stdint.h>
#include "acquire.h"
#include "inference_engine.h"

static void acquire_data(uint32_t buffer[]) {
}

void acquire(chanend from_buffer) {
    int running = 1;
    uint32_t frame[];
    while(running) {
        int cmd;
        from_spi :> cmd;
        switch(x) {
        case INFERENCE_ENGINE_ACQUIRE:
            acquire_data(frame);
            from_buffer <: cmd;
            from_buffer <: INFERENCE_ENGINE_WRITE_TENSOR;
            slave {
                from_buffer :> N;
                for(int i = 0; i < N; i++) {
                    from_buffer <: frame[i];
                }
            }
            break;
        case INFERENCE_ENGINE_EXIT:
            running = 0;
            break;
        default:
            printf("Error in acquire: cmd = 0x%02x\n", cmd);
            break;
        }
    }
}
