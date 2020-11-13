void spi_buffer(chanend from_spi, chanend to_engine, chanend to_sensor) {
    while(1) {
        int cmd;
        from_spi :> cmd;
        shared.mode |= BUSY;
        switch(x) {
        case INFERENCE_ENGINE_READ_TENSOR:
            to_engine <: cmd;
            master {
                to_engine <: N;
                for(int i = 0; i < N; i++) {
                    to_engine :> shared.memory[i];
                }
            }
            break;
        case INFERENCE_ENGINE_WRITE_MODEL:
            to_engine <: cmd;
            master {
                to_engine <: N;
                for(int i = 0; i < N; i++) {
                    to_engine <: shared.memory[i];
                }
            }
            break;
        case INFERENCE_ENGINE_WRITE_TENSOR:
            to_engine <: cmd;
            master {
                to_engine <: N;
                for(int i = 0; i < N; i++) {
                    to_engine <: shared.memory[i];
                }
            }
            break;
        case INFERENCE_ENGINE_INFERENCE:
            to_engine <: cmd;
            to_engine <: INFERENCE_ENGINE_READ_TENSOR;
            master {
                to_engine <: N;
                for(int i = 0; i < N; i++) {
                    to_engine :> shared.memory[i];
                }
            }
            break;
        case INFERENCE_ENGINE_WRITE_SERVER:
            // DFU
            break;
        case INFERENCE_ENGINE_ACQUIRE:
            to_sensor <: cmd;
            to_engine <: INFERENCE_ENGINE_WRITE_TENSOR;
            master {
                to_sensor <: N;
                to_engine <: N;
                for(int i = 0; i < N; i++) {
                    to_sensor :> shared.memory[i];
                    to_engine <: shared.memory[i];
                }
            }
            break;
        case INFERENCE_ENGINE_EXIT:
            running = 0;
            break;
        }
    }
}
