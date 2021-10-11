#ifndef _AIENGINE_H_
#define _AIENGINE_H_

#include <stdint.h>
#include "inference_engine.h"
#include "flash.h"

void aiengine(inference_engine_t &ie, chanend ?c_usb, chanend ?c_spi,
              chanend ?c_push, chanend ?c_acquire, chanend (&?c_leds)[4],
              chanend ?c_flash
#if defined(TFLM_DISABLED)
              , uint32_t tflite_disabled_image[], uint32_t sizeof_tflite_disabled_image
#endif
              );

extern size_t receive_array_(chanend c, uint32_t * unsafe array, unsigned ignore);

extern int aisrv_local_get_output_tensor(chanend to, int tensor_num, uint32_t *data);
extern int aisrv_local_acquire_single(chanend to, int sx, int ex, int sy, int ey, int rw, int rh);
extern int aisrv_local_start_inference(chanend to);
#endif
