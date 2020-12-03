/*
 * xcore_ie.h
 *
 *  Created on: 26 Nov 2020
 *      Author: henk
 */

#ifndef XCORE_IE_H_
#define XCORE_IE_H_

#include "cyhal.h"

typedef struct xcore_ie {
    cyhal_spi_t mSPI;
    int input_tensor_length;
    int output_tensor_length;
    int timings_length;
    int sensor_tensor_length;
} xcore_ie_t;

/**
 * Function that initialises an XCORE.AI IE structure
 *
 * @param xIE       pointer to the inferencing engine structure
 * @param frequency SPI frequency to use. Set to 0 to get the default.
 */
int xcore_ie_init(xcore_ie_t *xIE, int frequency);

/**
 * Function that waits for the xcore.ai inferencing engine to be ready
 * Times out after a given number of attempts
 *
 * @param xIE      pointer to the inferencing engine structure
 * @param timeout  number of times to try
 */
int xcore_ie_wait_ready_timeout(xcore_ie_t *xIE, int timeout);

/**
 * Function that waits for the xcore.ai inferencing engine to be ready
 * Has a default short time-out, enough for most uses except for
 * DFU and inferencing
 *
 * @param xIE      pointer to the inferencing engine structure
 */
int xcore_ie_wait_ready(xcore_ie_t *xIE);


/**
 * Function that sends a model to xcore.ai inferencing engine
 * Call this only on an initialised xcore_ie_t
 * The model should be quantised (using for example TensorFlowLite)
 * before sending it to xcore.ai
 *
 * @param xIE      pointer to the inferencing engine structure
 * @param data     pointer to the model
 * @param size     size of the model in bytes
 */
int xcore_ie_send_model(xcore_ie_t *xIE, uint8_t *data, uint32_t size);

/**
 * Function that sends an input tensor to the xcore.ai inferencing engine
 * Call this function only if the IE has a model on it
 * The size of the data should match the expected size.
 * The data type should match the expected data type.
 *
 * @param xIE      pointer to the inferencing engine structure
 * @param data     pointer to the data
 * @param size     size of the data in bytes
 */
int xcore_ie_send_data(xcore_ie_t *xIE, uint8_t *data, uint32_t size);

/**
 * Function that starts an inferencing cycle on the inferencing engine
 * Call this once a model and data have been send to the device
 * After this function, call xcore_ie_wait_ready_timeout with an appropriate
 * time-out.
 *
 * When completed, the output tensor can be read using xcore_ie_read_data()
 *
 * @param xIE      pointer to the inferencing engine structure
 */
int xcore_ie_start_inference(xcore_ie_t *xIE);

/**
 * Function that starts an acquisition cycle on the sensor. After completion
 * (call xcore_ie_wait_ready_timeout with an appropriate time-out)
 * frame of data will be stored in the data tensor. You can either use
 * xcore_ie_start_inference() to run the inference engine over this frame, or
 * xcore_ie_read_data() to read the frame of data out. The nature of the sensor
 * is implementation dependent, and you must ensure that the sensor frame shape
 * matches the expectations of the neural network.
 *
 * When completed, the output tensor can be read using xcore_ie_read_data()
 *
 * @param xIE      pointer to the inferencing engine structure
 */
int xcore_ie_start_acquisition(xcore_ie_t *xIE);

/**
 * Function that reads the output tensor from the inferencing engine. This is
 * either the output of the neural network, or the data that was set aside
 * by the sensor acquisition pipeline.
 *
 * NOTE: at the moment the array should be 3 bytes too large, and the first three bytes are garbage
 *
 * @param xIE      pointer to the inferencing engine structure
 * @param data     pointer to where to store the data
 * @param size     size of the data in bytes
 */
int xcore_ie_read_data(xcore_ie_t *xIE, uint8_t *data, uint32_t size);

/**
 * Function that reads the timings from the last inferencing step.
 *
 * NOTE: at the moment the array should be 3 bytes too large, and the first three bytes are garbage
 *
 * @param xIE      pointer to the inferencing engine structure
 * @param data     pointer to where to store the data, this contains words after the first three bytes
 * @param size     size of the data in bytes
 */
int xcore_ie_read_timings(xcore_ie_t *xIE, uint8_t *data, uint32_t size);

/**
 * Function that reads metadata from the device. When the device does
 * not have a model, it will report 0 for the various sizes.
 * The
 *
 * @param xIE      pointer to the inferencing engine structure
 */
int xcore_ie_read_spec(xcore_ie_t *xIE);

/**
 * Function that reads the ID of the device: 0x12345678.
 *
 * @param xIE      pointer to the inferencing engine structure
 * @param id       pointer to where to store the identifier, a single word.
 */
int xcore_ie_read_ID(xcore_ie_t *xIE, uint32_t *id);


#endif /* XCORE_IE_H_ */
