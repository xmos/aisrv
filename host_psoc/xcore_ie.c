/*
 * xcore_ie.c
 *
 *  Created on: 26 Nov 2020
 *      Author: henk
 */

#include "xcore_ie.h"
#include "app_config.h"
#include <stdio.h>

#define XCORE_IE_MAX_BLOCK_SIZE    (512)
#define DUMMY_BYTES                (2)
#define STATUS_READ_BYTES          (DUMMY_BYTES + 1 + 4)

typedef enum aisrv_cmd
{
    CMD_GET_STATUS        = 0x01,
    CMD_GET_ID            = 0x03,
    CMD_GET_SPEC          = 0x07,
    CMD_GET_TENSOR        = 0x05,
    CMD_GET_TIMINGS       = 0x09,

    CMD_SET_MODEL         = 0x86,
    CMD_SET_SERVER        = 0x04,
    CMD_SET_TENSOR        = 0x83,

    CMD_START_INFER       = 0x84,
    CMD_START_ACQUISITION = 0x0C,
    CMD_HELLO             = 0x55,
} aisrv_cmd_t;

int xcore_ie_wait_ready_timeout(xcore_ie_t *xIE, int timeout) {
    cy_rslt_t result;
	const uint8_t txdata[STATUS_READ_BYTES] = {CMD_GET_STATUS};      // READ STATUS
	uint8_t rxdata[STATUS_READ_BYTES];
	do {
	    result = cyhal_spi_transfer(&xIE->mSPI, txdata, STATUS_READ_BYTES, rxdata, STATUS_READ_BYTES, 0);
	    if (CY_RSLT_SUCCESS != result) {
	        return -1;
	    }
	    timeout--;
	    if (timeout < 0) {
	    	printf("Timeout...\r\n");
	    	return -2;
	    }
	} while((rxdata[3] & 0xF) != 0);
	return 0;
}

int xcore_ie_wait_ready(xcore_ie_t *xIE) {
	return xcore_ie_wait_ready_timeout(xIE, 10000);
}

static int xcore_ie_send_read_command(xcore_ie_t *xIE, uint8_t command, uint8_t *data, uint32_t size) {
    cy_rslt_t result;
	uint8_t txdata[1];      // READ STATUS
	int len = ((size + 3) & ~3) + DUMMY_BYTES + 1;  // Round to words, add one for the command
	txdata[0] = command;
	xcore_ie_wait_ready(xIE);
	result = cyhal_spi_transfer(&xIE->mSPI, txdata, 1, data, len, 0x0F);
    if (CY_RSLT_SUCCESS != result) {
        return -1;
    }
    return 0;
}

static int xcore_ie_send_write_command(xcore_ie_t *xIE, uint8_t command, uint8_t *model, uint32_t size) {
    cy_rslt_t result;
	uint8_t txdata[XCORE_IE_MAX_BLOCK_SIZE+1];
	// Note, <= in the for loop is intentional as you need to send a final
	// 0 length data if model is a integer number of blocks.
	for(int i = 0; i <= size; i+=XCORE_IE_MAX_BLOCK_SIZE) {
		int len = size - i;
		if (len > XCORE_IE_MAX_BLOCK_SIZE) {
			len = XCORE_IE_MAX_BLOCK_SIZE;
		}
		if (len != 0) {
			memcpy(txdata+1, model, len);
			model += len;
		}
		txdata[0] = command;
		xcore_ie_wait_ready(xIE);
	    result = cyhal_spi_transfer(&xIE->mSPI, txdata, len+1, NULL, 0, 0);
        if (CY_RSLT_SUCCESS != result) {
            return -1;
        }
	}
	return 0;
}

int xcore_ie_send_model(xcore_ie_t *xIE, uint8_t *model, uint32_t size) {
	return xcore_ie_send_write_command(xIE, CMD_SET_MODEL, model, size);
}

int xcore_ie_say_hello(xcore_ie_t *xIE) {
	uint8_t txdata[1] = {CMD_HELLO};
	cy_rslt_t result = cyhal_spi_transfer(&xIE->mSPI, txdata, 1, NULL, 0, 0);
    if (CY_RSLT_SUCCESS != result) {
        return -1;
    }
	return 0;
}

int xcore_ie_send_data(xcore_ie_t *xIE, uint8_t *model, uint32_t size) {
	return xcore_ie_send_write_command(xIE, CMD_SET_TENSOR, model, size);
}

int xcore_ie_start_inference(xcore_ie_t *xIE) {
	return xcore_ie_send_write_command(xIE, CMD_START_INFER, NULL, 0);
}

int xcore_ie_start_acquisition(xcore_ie_t *xIE) {
	return xcore_ie_send_write_command(xIE, CMD_START_ACQUISITION, NULL, 0);
}

int xcore_ie_read_data(xcore_ie_t *xIE, uint8_t *model, uint32_t size) {
	return xcore_ie_send_read_command(xIE, CMD_GET_TENSOR, model, size);
}

int xcore_ie_read_timings(xcore_ie_t *xIE, uint8_t *model, uint32_t size) {
	return xcore_ie_send_read_command(xIE, CMD_GET_TIMINGS, model, size);
}

int xcore_ie_read_spec(xcore_ie_t *xIE) {
	uint32_t tmp[7];
	int retval = xcore_ie_send_read_command(xIE, CMD_GET_SPEC, (((uint8_t *)&tmp[1])-3), 24);
	xIE->input_tensor_length = tmp[3];
	xIE->output_tensor_length = tmp[4];
	xIE->timings_length = tmp[5];
	xIE->sensor_tensor_length = tmp[6];
	return retval;
}

int xcore_ie_read_ID(xcore_ie_t *xIE, uint32_t *ID) {
	uint32_t tmp[2];
	return xcore_ie_send_read_command(xIE, CMD_GET_ID, (((uint8_t *)&tmp[1])-3), 4);
	*ID = tmp[1];
}

int xcore_ie_init(xcore_ie_t *xIE, int frequency) {
	cy_rslt_t result;
	result = cyhal_spi_init(&xIE->mSPI,
    						mSPI_MOSI, mSPI_MISO, mSPI_SCLK, mSPI_SS,
							NULL, 8, CYHAL_SPI_MODE_00_MSB, false);
    if (result != CY_RSLT_SUCCESS) {
    	return -1;
    }
#if 0
    Cy_GPIO_SetDrivemode(P9_0_PORT, P9_1_NUM, CY_GPIO_DM_HIGHZ);
    Cy_GPIO_SetDrivemode(P9_0_PORT, P9_0_NUM, CY_GPIO_DM_STRONG_IN_OFF);
    Cy_GPIO_SetDrivemode(P9_0_PORT, P9_2_NUM, CY_GPIO_DM_STRONG_IN_OFF);
    Cy_GPIO_SetDrivemode(P9_0_PORT, P9_3_NUM, CY_GPIO_DM_STRONG_IN_OFF);
#endif
    result = cyhal_spi_set_frequency(&xIE->mSPI, frequency == 0 ? 25000000 : frequency);
    if (result != CY_RSLT_SUCCESS) {
    	return -1;
    }
    /* Enable interrupts */
    __enable_irq();
    for(int i = 0; i < 5; i++) {
    	xcore_ie_say_hello(xIE);
    }

    return 0;
}
