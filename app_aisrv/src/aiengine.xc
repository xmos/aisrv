#include <xs1.h>
#include <stdio.h>
#include <stdint.h>
#include "aiengine.h"
#include "aisrv.h"
#include "inference_engine.h"

unsafe
{

void send_array(chanend c, uint32_t * unsafe array, unsigned size)
{
    size_t i;

    for(i = 0; i < size / sizeof(uint32_t); i++)
        outuint(c, array[i]);

    outct(c, XS1_CT_END);

    uint8_t * unsafe arrayc = (uint8_t * unsafe) array;
   
    i *= sizeof(uint32_t); 
    for(; i < size; i++)
        outuchar(c, arrayc[i]);
    
    outct(c, XS1_CT_END);
}

/* TODO add bounds checking */
static inline size_t receive_array_(chanend c, unsigned * unsafe array, unsigned ignore)
{
    size_t i = 0;
    
    while(!testct(c))
    {
        uint32_t x = inuint(c);
        if(!ignore) // TODO check hoisted
            array[i++] = x;
    }
    
    chkct(c, XS1_CT_END);

    i *= sizeof(uint32_t);
    uint8_t * unsafe arrayc = (uint8_t * unsafe) array;

    while(!testct(c))
    {
        uint8_t x = inuchar(c);
        if(!ignore) // TODO check hoisted
            arrayc[i++] = x;
    }
    chkct(c, XS1_CT_END);

    return i;
}
static inference_engine_t ie;
extern char debug_log_buffer[MAX_DEBUG_LOG_LENGTH];
extern size_t debug_log_length;

struct aiengine_status
{
    unsigned haveModel;
    unsigned acquireMode;
    unsigned outputGpioEn;
    int8_t outputGpioThresh[AISRV_GPIO_LENGTH]; 
    uint8_t outputGpioMax;
} status;

size_t SetModel(chanend c, uint8_t * unsafe model_data)
{
    size_t modelSize;
#if 0
    if(model_size > MAX_MODEL_SIZE_BYTES)
        printf("Warning not enough space allocated for model %d %d\n", model_size, MAX_MODEL_SIZE_BYTES);
    else
        printf("Model size: %d\n", model_size);
#endif

    modelSize = receive_array_(c, model_data, 0);

    printf("Model received: %d bytes\n", modelSize); 
    status.haveModel = !interp_initialize(&ie, modelSize, model_data);

    if(status.haveModel)
    {
        outuint(c, AISRV_STATUS_OKAY);
        printf("Model written sucessfully\n");
    }
    else
    {
        outuint(c, AISRV_STATUS_ERROR_MODEL_ERR);
        printf("Model update failed\n");
    }

    outct(c, XS1_CT_END);

    return modelSize;
}

void HandleGpio(uint8_t * unsafe outputTensor, size_t length, chanend c_led[AISRV_GPIO_LENGTH])
{

    if(status.outputGpioMax)
    {
        int8_t max = 0;
        size_t maxi = 0;

        /* Find the maximum value in the whole output tensor */
        for(size_t i = 0; i < length; i++)
        {
            int8_t x = (int8_t) outputTensor[i];
            if (x > max)
            {
                max = (int8_t) outputTensor[i];
                maxi = i;
            } 

            if(i < AISRV_GPIO_LENGTH)
            {
                /* All GPIO low */
                outuchar(c_led[i], 0);
                outct(c_led[i], XS1_CT_END);
            }
        }
        
        /* Note, we do not raise an IO for output tensor values outside the GPIO range */
        if(maxi < AISRV_GPIO_LENGTH)
        {
            //printf("%d: %d %d\n", maxi, max, status.outputGpioThresh[maxi]);
            outuchar(c_led[maxi], (uint8_t) (outputTensor[maxi] > status.outputGpioThresh[maxi]));
            outct(c_led[maxi], XS1_CT_END);
        }
    }
    else
    {
        for(size_t i = 0; i < length; i++)
        {
            if(i > (AISRV_GPIO_LENGTH-1))
                break;
        
            outuchar(c_led[i], (uint8_t) (outputTensor[i] > status.outputGpioThresh[i]));
            outct(c_led[i], XS1_CT_END);
        }
    }
}

void HandleCommand(chanend c, aisrv_cmd_t cmd, chanend c_acquire, chanend c_leds[AISRV_GPIO_LENGTH])
{
    unsigned data[MAX_PACKET_SIZE_WORDS]; 

    static size_t modelSize = 0;
    
    switch(cmd)
    {
        case CMD_GET_SPEC:
            uint32_t spec[SPEC_MODEL_TOTAL];
            spec[SPEC_WORD_0] = 0;
            spec[SPEC_WORD_1] = 0;
            spec[SPEC_INPUT_TENSOR_LENGTH] = ie.input_size;
            spec[SPEC_OUTPUT_TENSOR_LENGTH] = ie.output_size;
            spec[SPEC_TIMINGS_LENGTH] = ie.output_times_size;

            /* TODO bad status if no model */
            c <: (unsigned) AISRV_STATUS_OKAY;
            send_array(c, spec, SPEC_MODEL_TOTAL*sizeof(uint32_t));
            break;

        case CMD_SET_MODEL_INT:
            modelSize = SetModel(c, ie.model_data_int);
            break;

        case CMD_SET_MODEL_EXT:
            modelSize = SetModel(c, ie.model_data_ext);
            break;

        /* TODO debug only = remove for production */
        case CMD_GET_MODEL_INT:
           
            printf("Sending model length: %d\n", modelSize); 
            /* TODO bad status if no model */
            c <: (unsigned) AISRV_STATUS_OKAY;
            send_array(c, ie.model_data_int, modelSize);
            break;

        /* TODO debug only = remove for production */
        case CMD_GET_MODEL_EXT:
           
            printf("Sending model length: %d\n", modelSize); 
            /* TODO bad status if no model */
            c <: (unsigned) AISRV_STATUS_OKAY;
            send_array(c, ie.model_data_ext, modelSize);
            break;

        case CMD_SET_INPUT_TENSOR:

             // TODO check size vs input_size
            size_t size = receive_array_(c, ie.input_buffer, !status.haveModel);
        
            if(status.haveModel)
            {
                outuint(c, AISRV_STATUS_OKAY);
                outct(c, XS1_CT_END);
            }
            else
            {
                outuint(c, AISRV_STATUS_ERROR_NO_MODEL);
                outct(c, XS1_CT_END);
            }
            break;

        case CMD_START_INFER:

            aisrv_status_t trans_status = AISRV_STATUS_OKAY;

            /* Note currently receive extra 0 length */
            /* TODO remove the need for this */
            size_t size = receive_array_(c, data, 0);
                
            if(status.haveModel)
            {
                trans_status = interp_invoke();
                //print_output();
                print_profiler_summary();

                if(status.outputGpioEn)
                {
                    HandleGpio(ie.output_buffer, ie. output_size, c_leds);
                }
            }
            else
            {
                trans_status = AISRV_STATUS_ERROR_NO_MODEL;
            }

            outuint(c, trans_status);
            outct(c, XS1_CT_END);
            break;
        
        case CMD_GET_OUTPUT_TENSOR_LENGTH:

            // TODO use a send array function 
            if(status.haveModel)
            {
                c <: (unsigned) AISRV_STATUS_OKAY;
                send_array(c, &ie.output_size, sizeof(ie.output_size));
            }
            else
            {
                c <: AISRV_STATUS_ERROR_NO_MODEL;
            }

            break;

         case CMD_GET_INPUT_TENSOR_LENGTH:
            
            // TODO use a send array function 
            if(status.haveModel)
            {
                c <: (unsigned) AISRV_STATUS_OKAY;
                send_array(c, &ie.input_size, sizeof(ie.input_size));
            }
            else
            {
                c <: AISRV_STATUS_ERROR_NO_MODEL;
            }

            break;

        case CMD_GET_OUTPUT_TENSOR:
            c <: (unsigned) AISRV_STATUS_OKAY;
            send_array(c, ie.output_buffer, ie.output_size);
            break;
        
        case CMD_GET_INPUT_TENSOR:
            c <: (unsigned) AISRV_STATUS_OKAY;
            send_array(c, ie.input_buffer, ie.input_size);
            break;
            
        case CMD_GET_TIMINGS: 
            c <: (unsigned) AISRV_STATUS_OKAY;
            send_array(c, ie.output_times, ie.output_times_size * sizeof(uint32_t));
            break;

        case CMD_GET_DEBUG_LOG:
            c <: (unsigned) AISRV_STATUS_OKAY;
            send_array(c, (unsigned * unsafe) debug_log_buffer,  MAX_DEBUG_LOG_LENGTH * MAX_DEBUG_LOG_ENTRIES);
            break; 

        /* TODO do we need to separate AQUIRE_MODE from INFERENCE_MODE? */
        /* TODO only accept mode if MIPI enabled */
        case CMD_START_ACQUIRE_STREAM:

            size_t size = receive_array_(c, data, 0);
            //status.acquireMode = (data, unsigned[])[0];
            status.acquireMode = AISRV_ACQUIRE_MODE_STREAM;
            
            printf("Aquire mode: %d\n", status.acquireMode);
            aisrv_status_t trans_status = AISRV_STATUS_OKAY;
            outuint(c, trans_status);
            outct(c, XS1_CT_END);
            
            break;

        case CMD_GET_ACQUIRE_MODE:
            c <: (unsigned) AISRV_STATUS_OKAY;
            send_array(c, &status.acquireMode, sizeof(status.acquireMode));
            break;

        case CMD_START_ACQUIRE_SINGLE:

            /* Note currently receive extra 0 length */
            /* TODO remove the need for this */
            size_t size = receive_array_(c, data, 0);

            aisrv_status_t status = AISRV_STATUS_OKAY;
            c_acquire <: (unsigned) CMD_START_ACQUIRE_SINGLE;

            /* Currently we Receive sensor data into sensor_tensor buffer */
            /* TODO check we dont overrun input_buffer */
            size = receive_array_(c_acquire, (uint32_t * unsafe)ie.input_buffer, 0);

            outuint(c, status);
            outct(c, XS1_CT_END);
            break;

        case CMD_GET_OUTPUT_GPIO_EN:
                c <: (unsigned) AISRV_STATUS_OKAY;
                send_array(c, &ie.output_size, sizeof(status.outputGpioEn));
            break;
        
        case CMD_SET_OUTPUT_GPIO_EN:

            aisrv_status_t trans_status = AISRV_STATUS_OKAY;
            size_t size = receive_array_(c, data, 0);

            status.outputGpioEn = data[0];

            outuint(c, AISRV_STATUS_OKAY);
            outct(c, XS1_CT_END);
            break;

        case CMD_SET_OUTPUT_GPIO_THRESH:
            
            size_t size = receive_array_(c, data, 0);

            size_t index = (data, uint8_t[])[0];
            int8_t thresh = (data, uint8_t[])[1];

            if (size != 2)
            {
                outuint(c, AISRV_STATUS_ERROR_BAD_CMD);
                outct(c, XS1_CT_END);
            }
            else
            {
                status.outputGpioThresh[index] = thresh;                
                outuint(c, AISRV_STATUS_OKAY);
                outct(c, XS1_CT_END);
            }

            break;
        
        case CMD_GET_OUTPUT_GPIO_THRESH:
            c <: (unsigned) AISRV_STATUS_OKAY;
            send_array(c, &status.outputGpioThresh, sizeof(status.outputGpioThresh));
            break;


        default:
            c <: (unsigned) AISRV_STATUS_ERROR_BAD_CMD;
            printf("Unknown command (aiengine): %d\n", cmd);
            break;
    }
}


void aiengine(chanend c_usb, chanend c_spi, chanend c_acquire, chanend c_leds[4])
{
    aisrv_cmd_t cmd = CMD_NONE;
    size_t length = 0;

    unsafe { inference_engine_initialize(&ie); }

    status.haveModel = 0;
    status.acquireMode = AISRV_ACQUIRE_MODE_SINGLE;

    for(size_t i = 0; i< AISRV_GPIO_LENGTH; i++)
    {
        status.outputGpioThresh[i] = -128;
    }

    status.outputGpioMax = 1;

    while(1)
    {
        select
        {
            case c_usb :> cmd:
                HandleCommand(c_usb, cmd, c_acquire, c_leds);
                break;
            
            case c_spi :> cmd:
                HandleCommand(c_spi, cmd, c_acquire, c_leds);
                break;

            (status.acquireMode == AISRV_ACQUIRE_MODE_STREAM) => default:
            {  
                size_t size;

                /* Run an acquire and a inference */ 
                c_acquire <: (unsigned) CMD_START_ACQUIRE_SINGLE;

                /* TODO check we dont overrun input_buffer */
                size = receive_array_(c_acquire, (uint32_t * unsafe)ie.input_buffer, 0);

                // TODO check model status and interp status
                interp_invoke();

                if(status.outputGpioEn)
                {
                    HandleGpio(ie.output_buffer, ie.output_size, c_leds);
                }

                break;
            }
        }
    }
}
} // unsafe

