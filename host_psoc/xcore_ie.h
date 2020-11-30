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
 * @param xIE      pointer to the inferencing engine structure
 */
int xcore_ie_inference(xcore_ie_t *xIE);

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
 *
 * @param xIE      pointer to the inferencing engine structure
 * @param ilength  pointer to where to store the input tensor length (in bytes)
 * @param olength  pointer to where to store the output tensor length (in bytes)
 * @param tlength  pointer to where to store the timing vector length (in words[!])
 */
int xcore_ie_read_spec(xcore_ie_t *xIE, uint32_t *ilength, uint32_t *olength, uint32_t *tlength);

/**
 * Function that reads the ID of the device: 0x12345678.
 *
 * NOTE: at the moment the array should be 3 bytes too large, and the first three bytes are garbage
 *
 * @param xIE      pointer to the inferencing engine structure
 * @param data     pointer to where to store the data, this contains a word after the first three bytes
 */
int xcore_ie_read_ID(xcore_ie_t *xIE, uint8_t *data);


#endif /* XCORE_IE_H_ */
