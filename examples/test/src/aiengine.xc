void aiegine(chanend x) {
    while(1) {
        int cmd;
        x :> cmd;
        x :> N;
        switch(x) {
        case INFERENCE_ENGINE_READ_TENSOR:
            slave {
                for(int i = 0; i < N; i++) {
                    x <: tensor_arena[i];
                }
            }
            break;
        case INFERENCE_ENGINE_WRITE_MODEL:
            slave {
                for(int i = 0; i < N; i++) {
                    x :> model[i];
                }
            }
            break;
        case INFERENCE_ENGINE_WRITE_TENSOR:
            slave {
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
            case
        }
    }
}
