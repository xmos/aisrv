#ifndef _AIENGINE_H_
#define _AIENGINE_H_

#include <stdint.h>
#include "inference_engine.h"
#include "flash.h"

/** Function that runs one AI engine. An AI engine is a task that can load a model,
 * load input values, run an inference, and produce output values. The AI engine is
 * controlled over one or more channel ends. The AI engine uses
 * the underlying inference_engine object as its means to run inferencing algorithms.
 * In other words, the AI engine provides a channel interface on top of an inferencing
 * engine.
 * 
 * \param ie         The inference engine to be used for running inferences
 *                   The caller is responsible for allocating and initialising
 *                   this object.
 * \param c_usb c_spi Array of control channels (TODO: make array). Each control channel
 *                   can be used to send the AI engine requests, for example, load a model
 *                   get a tensor, etc. Multiple control channels can be used, but each request
 *                   is answered in turn.
 *                   There are four types of clients to connect to these channels:
 *                   USB clients (aisrv_usb), SPI clients (spi), local clients (see the
 *                   aisrv_local_* functions below), and other AI engines enabling one or
 *                   more AI engines to be chained together.
 * \param c_push     output channel of an AI engine. Typically not connected, but this can be
 *                   wired up to another AI engine to chain two models together.
 *                   On a successful inference, the AI engine will automatically push
 *                   the output tensors out over this channel and request an inference.
 * \param c_acquire  Input channel to connect to a sensor. This channel enables the AI engine
 *                   to request data from a sensor/
 * \param c_leds     Channel array to four leds - should probably be deprecated.
 * \param c_flash    Channel to the flash server. This channel is used for two purposes at
 *                   present: (1) when the AI engine receives a SET_MODEL_*_FLASH command it will
 *                   use c_flash to retrieve a model from flash, (2) when, during inferencing,
 *                   the model encounters an XC_load_from_flash operator, it will use the c_flash
 *                   channel to obtain the parameters from flash
 *
 * Two optional parameters, tflite_disabled_image and sizeof_tflite_disabled_image,
 * only need to be supplied if 
 * tensor-flow-lite-for-micro is disabled. When disabled, none of the TFLM code
 * need to be compiled in, and the supplied array (and its size in bytes) are used
 * as a surrogate space to hold input and output tensors. This enables the 
 * sensor interface to be debugged quickly
 */
void aiengine(inference_engine_t &ie, chanend ?c_usb, chanend ?c_spi,
              chanend ?c_push, chanend ?c_acquire, chanend (&?c_leds)[4],
              chanend ?c_flash
#if defined(TFLM_DISABLED)
              , uint32_t tflite_disabled_image[], uint32_t sizeof_tflite_disabled_image
#endif
              );

extern size_t receive_array_(chanend c, uint32_t * unsafe array, unsigned ignore);

/** Function that sends a command to an AI engine to obtain one of the output tensors.
 *
 * \param  to          channel end to the AI engine
 * \param  tensor_num  index of output tensor to retrieve. Use 0 for the first output tensor
 *                     do not ask for output tensors that do not exist.
 * \param  data        pointer where to store the retrieved output tensor
 * \returns            non-zero value indicates an error
 */
extern int aisrv_local_get_output_tensor(chanend to, int tensor_num, uint32_t *data);

/** Function that sends a command to an AI engine to acquire a frame of data from the sensor.
 * This particular function assumes that the sensor is an image sensor, and should therefore
 * be renamed to acquire_single_image or something like that.
 *
 * On calling this function, specify the rectangle that is of interest on the sensor, and the
 * width and height that this rectangle should be resized to.
 *
 * Note - this implicitly writes to inptu tensor 0 at the moment. Should be an argument
 *
 * \param  to          channel end to the AI engine
 * \param  sx          start-x coordinate (this assumes the sensor is an image sensor)
 * \param  ex          end-x coordinate (this assumes the sensor is an image sensor)
 * \param  sy          start-y coordinate (this assumes the sensor is an image sensor)
 * \param  ey          end-y coordinate (this assumes the sensor is an image sensor)
 * \param  rw          required width of the image, this is the number of columns that will
 *                     be delivered into the input tensor
 * \param  rh          required height of the image, this is the number of rows that will
 *                     be delivered into the input tensor
 * \returns            non-zero value indicates an error
 */
extern int aisrv_local_acquire_single(chanend to, int sx, int ex, int sy, int ey, int rw, int rh);

/** Function that sends a command to an AI engine to run one inference cycle.
 *
 * \param  to          channel end to the AI engine
 * \returns            non-zero value indicates an error
 */
extern int aisrv_local_start_inference(chanend to);

#endif
