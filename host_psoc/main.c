/******************************************************************************
* File Name: main.c
*
* Related Document: See Readme.md
*
* Description: This example project demonstrates the basic operation of SPI
* resource as Master using HAL. The SPI master sends command packets
* to the SPI slave to control an user LED.
*
*******************************************************************************
* (c) 2019-2020, Cypress Semiconductor Corporation. All rights reserved.
*******************************************************************************
* This software, including source code, documentation and related materials
* ("Software"), is owned by Cypress Semiconductor Corporation or one of its
* subsidiaries ("Cypress") and is protected by and subject to worldwide patent
* protection (United States and foreign), United States copyright laws and
* international treaty provisions. Therefore, you may use this Software only
* as provided in the license agreement accompanying the software package from
* which you obtained this Software ("EULA").
*
* If no EULA applies, Cypress hereby grants you a personal, non-exclusive,
* non-transferable license to copy, modify, and compile the Software source
* code solely for use in connection with Cypress's integrated circuit products.
* Any reproduction, modification, translation, compilation, or representation
* of this Software except as specified above is prohibited without the express
* written permission of Cypress.
*
* Disclaimer: THIS SOFTWARE IS PROVIDED AS-IS, WITH NO WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, NONINFRINGEMENT, IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. Cypress
* reserves the right to make changes to the Software without notice. Cypress
* does not assume any liability arising out of the application or use of the
* Software or any product or circuit described in the Software. Cypress does
* not authorize its products for use in any products where a malfunction or
* failure of the Cypress product may reasonably be expected to result in
* significant property damage, injury or death ("High Risk Product"). By
* including Cypress's product in a High Risk Product, the manufacturer of such
* system or application assumes all risk of such use and in doing so agrees to
* indemnify Cypress against all liability.
*******************************************************************************/

#include "cy_pdl.h"
#include "cyhal.h"
#include "cybsp.h"
#include "cy_retarget_io.h"
#include "app_config.h"
#include "mobilenet_v1.h"
#include "xcore_ie.h"

/***************************************
*            Constants
****************************************/
#define SPI_FREQ_HZ                (100000UL)//(1000000UL)
#define CMD_TO_CMD_DELAY_MS        (100UL)

/*******************************************************************************
* Function Name: handle_error
********************************************************************************
* Summary:
* User defined error handling function
*
* Parameters:
*  void
*
* Return:
*  void
*
*******************************************************************************/
void handle_error(void)
{
     /* Disable all interrupts. */
    __disable_irq();

    CY_ASSERT(0);
}


int main(void)
{
    cy_rslt_t result;
    unsigned char const *model = get_mobile_net();
    unsigned char const *data = get_mobile_data();

    /* Initialize the device and board peripherals */
    result = cybsp_init();

    if (result != CY_RSLT_SUCCESS)
    {
        handle_error();
    }

    result = cy_retarget_io_init( CYBSP_DEBUG_UART_TX, CYBSP_DEBUG_UART_RX, 
                                  CY_RETARGET_IO_BAUDRATE);
    
    if (result != CY_RSLT_SUCCESS)
    {
        handle_error();
    }


    printf("***************************\r\n");
    printf("* PSoC 6 XCORE.AI IE demo *\r\n");
    printf("***************************\r\n\n");
    

    xcore_ie_t xIE;

    xcore_ie_init(&xIE, 10000000);

    uint8_t rxdata[128];
    uint32_t input_length, output_length, timing_length;
    xcore_ie_read_ID(&xIE, rxdata);
    for(int i = 0; i < 7; i++) {
    	printf(" %02x", rxdata[i]);
    }
	xcore_ie_read_timings(&xIE, rxdata, 31*4);

    printf("\r\n");
    xcore_ie_send_model(&xIE, (uint8_t *)model,  909368);
    xcore_ie_read_spec(&xIE, &input_length, &output_length, &timing_length);
    printf("%d %d %d\r\n", (int)input_length, (int)output_length, (int)timing_length);
    for(int i = 0; i < 10; i++) {
    	printf("Sending data\r\n");
    	xcore_ie_send_data(&xIE, (uint8_t *)data, input_length);
    	xcore_ie_inference(&xIE);
    	xcore_ie_wait_ready_timeout(&xIE, 1000000);

    	printf("Inference finished\r\n");

    	xcore_ie_read_data(&xIE, rxdata, output_length);
    	for(int i = 3; i < output_length + 3; i++) {
    		printf(" %4d", ((int8_t *)rxdata)[i]);
    	}
    	printf("\r\n");

    	xcore_ie_read_timings(&xIE, rxdata, 31*4);
    	int max = 0, maxlevel = 0;
    	for(int i = 0; i < 31; i++) {
    		int t = ((int *)(rxdata+3))[i]/100;
    		if (t > max) {
    			max = t;
    			maxlevel = i;
    		}
    	}
    	printf("Max time of %d us at layer %d\r\n", max, maxlevel);
    }

    while(1);
}
