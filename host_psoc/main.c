
#include "cy_pdl.h"
#include "cyhal.h"
#include "cybsp.h"
#include "cy_retarget_io.h"
#include "app_config.h"
#include "mobilenet_v1.h"
#include "xcore_ie.h"


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

char *object_classes[10] = {
    "tench",
    "goldfish",
    "great_white_shark",
    "tiger_shark",
    "hammerhead",
    "electric_ray",
    "stingray",
    "cock",
    "hen",
    "ostrich",
};


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
    uint8_t rxdata[128];

    xcore_ie_init(&xIE, 10000000);

    xcore_ie_send_model(&xIE, (uint8_t *)model,  909368);
    xcore_ie_read_spec(&xIE);

    printf("Sending data\r\n");
    xcore_ie_send_data(&xIE, (uint8_t *)data, xIE.input_tensor_length);

    printf("Starting inference on xcore.ai\r\n");
    xcore_ie_start_inference(&xIE);
    xcore_ie_wait_ready_timeout(&xIE, 1000000);
    printf("Inference finished\r\n");

    xcore_ie_read_data(&xIE, rxdata, xIE.output_tensor_length);
    int max_value = -999;
    int max_value_index = -1;
    for(int i = 3; i < xIE.output_tensor_length + 3; i++) {
    	int oval = ((int8_t *)rxdata)[i];
    	if (oval > max_value) {
    		max_value = oval;
    		max_value_index = i-3;
    	}
    }

    float prob = (max_value +128) /2.55;
    printf("Computer says this is a %s; %5.2f%%\r\n", object_classes[max_value_index], prob);

    xcore_ie_read_timings(&xIE, rxdata, 31*4);
    int max = 0, maxlevel = 0;
    for(int i = 0; i < xIE.timings_length; i++) {
    	int t = ((int *)(rxdata+3))[i]/100;
    	if (t > max) {
    		max = t;
    		maxlevel = i;
    	}
    }
    printf("Max time of %d us at layer %d\r\n", max, maxlevel);

    while(1);
}
