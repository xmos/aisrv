#ifndef _AIENGINE_H_
#define _AIENGINE_H_

#include "inference_engine.h"

void aiengine(inference_engine_t &ie, chanend c_spi, chanend c_usb, chanend c_acquire, chanend c_leds[4]);

#endif
