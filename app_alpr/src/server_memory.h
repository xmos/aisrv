#ifndef SERVER_MEMORY_H_
#define SERVER_MEMORY_H_

#include "inference_engine.h"

#ifdef __XC__
    void inference_engine_initialize_with_memory_0(inference_engine_t * UNSAFE ie,
                                                   chanend c_flash);
    void inference_engine_initialize_with_memory_1(inference_engine_t * UNSAFE ie);
#else
#ifdef __cplusplus
extern "C" {
#endif
    void inference_engine_initialize_with_memory_0(inference_engine_t * UNSAFE ie,
                                                   unsigned c_flash);
    void inference_engine_initialize_with_memory_1(inference_engine_t * UNSAFE ie);
#ifdef __cplusplus
};
#endif
#endif


#endif
