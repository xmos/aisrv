#include <stdio.h>
#include <stdint.h>
#include "aiengine.h"
#include "inference_engine.h"

uint32_t tensor_arena[100];
uint32_t model[100];

static void call_engine(void) {
}

void aiegine(chanend x) {
    int running = 1;
    while(running) {
        int cmd, N;
        x :> cmd;
        switch(cmd) {
        case INFERENCE_ENGINE_READ_TENSOR:
            slave {
                x :> N;
                for(int i = 0; i < N; i++) {
                    x <: tensor_arena[i];
                }
            }
            break;
        case INFERENCE_ENGINE_WRITE_MODEL:
            slave {
                x :> N;
                for(int i = 0; i < N; i++) {
                    x :> model[i];
                }
            }
            break;
        case INFERENCE_ENGINE_WRITE_TENSOR:
            slave {
                x :> N;
                for(int i = 0; i < N; i++) {
                    x :> tensor_arena[i];
                }
            }
            break;
        case INFERENCE_ENGINE_INFERENCE:
            call_engine();
            break;
        case INFERENCE_ENGINE_EXIT:
            running = 0;
            break;
        }
    }
}
