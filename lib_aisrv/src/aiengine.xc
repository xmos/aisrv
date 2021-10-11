#include <xs1.h>
#include <stdio.h>
#include <stdint.h>
#include <print.h>
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
size_t receive_array_(chanend c, uint32_t * unsafe array, unsigned ignore)
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

static size_t SetModel(inference_engine_t &ie, chanend c,
                       uint32_t * unsafe model_data,
                       chanend ?c_flash,
                       int read_from_flash)
{
    size_t modelSize;

    inference_engine_unload_model(&ie);

    if (read_from_flash) {
        receive_array_(c, model_data, 1);                // receive empty array
        c_flash <: READ_FLASH_MODEL;
        slave {
            c_flash :> modelSize;
            for(int i = 0; i < modelSize; i++) {
                c_flash :> ((uint8_t *)model_data)[i];
            }
        }
    } else {
        modelSize = receive_array_(c, model_data, 0);
    }

    printstr("Model received: "); printintln(modelSize);
    int error = inference_engine_load_model(&ie, modelSize, model_data, c_flash);
    ie.haveModel = !error;

    if(ie.haveModel)
    {
        outuint(c, AISRV_STATUS_OKAY);
        printstr("Model written sucessfully\n");
    }
    else
    {
        outuint(c, AISRV_STATUS_ERROR_MODEL_ERR);
        printstr("Model update failed ");
        printintln(error);
    }

    outct(c, XS1_CT_END);

    return modelSize;
}

static void HandleGpio(inference_engine_t &ie, chanend (&?c_led)[AISRV_GPIO_LENGTH])
{
    uint8_t * unsafe outputTensor = (uint8_t *) ie.output_buffers[0];
    uint32_t length = ie.output_sizes[0];
    
    if(ie.outputGpioMode == AISRV_GPIO_OUTPUT_MODE_MAX)
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
            outuchar(c_led[maxi], (uint8_t) (((int8_t) outputTensor[maxi]) > ie.outputGpioThresh[maxi]));
            outct(c_led[maxi], XS1_CT_END);
        }
    }
    else
    {
        for(size_t i = 0; i < length; i++)
        {
            if(i == AISRV_GPIO_LENGTH)
                break;
        
            outuchar(c_led[i], (uint8_t) (((int8_t) outputTensor[i]) > ie.outputGpioThresh[i]));
            outct(c_led[i], XS1_CT_END);
        }
    }
}

static void HandleCommand(inference_engine_t &ie, chanend c,
                          chanend ?c_chain,
                          aisrv_cmd_t cmd,
                          uint32_t tensor_num,
                          chanend ?c_acquire, chanend (&?c_leds)[AISRV_GPIO_LENGTH],
                          chanend ?c_flash)
{
    uint32_t data[MAX_PACKET_SIZE_WORDS];
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

        case CMD_SET_MODEL_ARENA:
            ie.modelSize = SetModel(ie, c, ie.model_data_tensor_arena, c_flash, 0);
            break;

        case CMD_SET_MODEL_EXT:
            ie.modelSize = SetModel(ie, c, ie.model_data_ext, c_flash, 0);
            break;

        case CMD_SET_MODEL_ARENA_FLASH:
            ie.modelSize = SetModel(ie, c, ie.model_data_tensor_arena, c_flash, 1);
            break;

        case CMD_SET_MODEL_EXT_FLASH:
            ie.modelSize = SetModel(ie, c, ie.model_data_ext, c_flash, 1);
            break;

        case CMD_SET_INPUT_TENSOR:

             // TODO check size vs input_sizes[tensor_num]
            size_t size = receive_array_(c, ie.input_buffers[tensor_num], !ie.haveModel);
        
            if(ie.haveModel)
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
                
            if(ie.haveModel)
            {
                printstr("Inferencing...\n");
                trans_status = interp_invoke(&ie);
                printstr("Done...\n");
                if (trans_status == AISRV_STATUS_OKAY && ie.chainToNext)
                {
                    for(int i = 0; i < ie.outputs; i++) {
                        c_chain <: CMD_SET_INPUT_TENSOR;
                        c_chain <: i;
                        printstr("Outp "); printintln(ie.output_sizes[i]);
                        send_array(c_chain, ie.output_buffers[i], ie.output_sizes[i]);
                        trans_status = inuint(c_chain);
                        chkct(c_chain, XS1_CT_END);
                    }
                    if (trans_status == AISRV_STATUS_OKAY) {
                        c_chain <: CMD_START_INFER;
                        c_chain <: 0;
                        send_array(c_chain, ie.output_buffers[0], 0); // null data
                        trans_status = inuint(c_chain);
                        chkct(c_chain, XS1_CT_END);
                    }
                }
                //print_output();
#ifdef PRINT_PROFILER_SUMMARY
                print_profiler_summary(&ie);
#endif

                if(ie.outputGpioEn)
                {
                    HandleGpio(ie, c_leds);
                }
            }
            else
            {
#if !defined(TFLM_DISABLED)
                trans_status = AISRV_STATUS_ERROR_NO_MODEL;
#endif
            }

            outuint(c, trans_status);
            outct(c, XS1_CT_END);
            break;
#if 0
        case CMD_GET_OUTPUT_TENSOR_LENGTH:

            // TODO use a send array function 
            if(ie.haveModel)
            {
                c <: (unsigned) AISRV_STATUS_OKAY;
                send_array(c, &ie.output_sizes, sizeof(ie.output_sizes));
            }
            else
            {
                c <: AISRV_STATUS_ERROR_NO_MODEL;
            }

            break;

         case CMD_GET_INPUT_TENSOR_LENGTH:
            
            // TODO use a send array function 
            if(ie.haveModel)
            {
                c <: (unsigned) AISRV_STATUS_OKAY;
                send_array(c, &ie.input_sizes, sizeof(ie.input_sizes));
            }
            else
            {
                c <: AISRV_STATUS_ERROR_NO_MODEL;
            }

            break;
#endif

        case CMD_GET_OUTPUT_TENSOR:
            if (ie.output_sizes[tensor_num] != 0) {
                c <: (unsigned) AISRV_STATUS_OKAY;
                send_array(c, ie.output_buffers[tensor_num], ie.output_sizes[tensor_num]);
            } else {
                c <: (unsigned) AISRV_STATUS_ERROR_NO_MODEL;
            }
            break;
        
        case CMD_GET_INPUT_TENSOR:
            c <: (unsigned) AISRV_STATUS_OKAY;
            send_array(c, ie.input_buffers[tensor_num], ie.input_sizes[tensor_num]);
            break;
            
        case CMD_GET_TIMINGS: 
            c <: (unsigned) AISRV_STATUS_OKAY;
            send_array(c, ie.output_times, ie.output_times_size * sizeof(uint32_t));
            break;

        case CMD_GET_DEBUG_LOG:
            c <: (unsigned) AISRV_STATUS_OKAY;
            send_array(c, (uint32_t * unsafe) ie.debug_log_buffer,  MAX_DEBUG_LOG_LENGTH);
            break; 

        /* TODO do we need to separate AQUIRE_MODE from INFERENCE_MODE? */
        /* TODO only accept mode if MIPI enabled */
        case CMD_START_ACQUIRE_STREAM:

            size_t size = receive_array_(c, data, 0);
            //ie.acquireMode = (data, unsigned[])[0];
            ie.acquireMode = AISRV_ACQUIRE_MODE_STREAM;
            
            aisrv_status_t trans_status = AISRV_STATUS_OKAY;
            outuint(c, trans_status);
            outct(c, XS1_CT_END);
            
            break;

        case CMD_GET_ACQUIRE_MODE:
            c <: (unsigned) AISRV_STATUS_OKAY;
            send_array(c, &ie.acquireMode, sizeof(ie.acquireMode));
            break;

        case CMD_START_ACQUIRE_SET_I2C:

            /* Note currently receive extra 0 length */
            /* TODO remove the need for this */
            size_t size = receive_array_(c, data, 0);
            c_acquire <: (unsigned) CMD_START_ACQUIRE_SET_I2C;
            for(int i = 0; i < 3; i++) {
                c_acquire <: (unsigned) ((data, uint8_t[])[i]);
            }
            
            aisrv_status_t trans_status = AISRV_STATUS_OKAY;
            outuint(c, trans_status);
            outct(c, XS1_CT_END);
            break;
            
        case CMD_START_ACQUIRE_SINGLE:

            /* Note currently receive extra 0 length */
            /* TODO remove the need for this */
            size_t size = receive_array_(c, data, 0);

            aisrv_status_t status = AISRV_STATUS_OKAY;
            if(ie.haveModel
#if defined(TFLM_DISABLED)
               || 1
#endif
                )
            {
                c_acquire <: (unsigned) CMD_START_ACQUIRE_SINGLE;
                c_acquire <: (unsigned) ie.input_buffers[0];

                for(int i = 0; i < 6; i += 1) {
                    c_acquire <: (unsigned) ((data, uint16_t[])[i]);
                }

                /* TODO check we dont overrun input_buffer */
                size = receive_array_(c_acquire, ie.input_buffers[0], 0);
            }
            else
            {
                status = AISRV_STATUS_ERROR_NO_MODEL;
            }

            outuint(c, status);
            outct(c, XS1_CT_END);
            break;

        case CMD_GET_OUTPUT_GPIO_EN:
                c <: (unsigned) AISRV_STATUS_OKAY;
                send_array(c, &ie.output_sizes[0], sizeof(ie.outputGpioEn));
            break;
        
        case CMD_SET_OUTPUT_GPIO_EN:

            aisrv_status_t trans_status = AISRV_STATUS_OKAY;
            size_t size = receive_array_(c, data, 0);

            ie.outputGpioEn = data[0];

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
                if(index < AISRV_GPIO_LENGTH)
                {
                    ie.outputGpioThresh[index] = thresh;                
                }
                outuint(c, AISRV_STATUS_OKAY);
                outct(c, XS1_CT_END);
            }

            break;
        
        case CMD_GET_OUTPUT_GPIO_THRESH:
            c <: (unsigned) AISRV_STATUS_OKAY;
            send_array(c, &ie.outputGpioThresh, sizeof(ie.outputGpioThresh));
            break;

        case CMD_SET_OUTPUT_GPIO_MODE:

            size_t size = receive_array_(c, data, 0);
            
            ie.outputGpioMode = data[0];
             
            outuint(c, AISRV_STATUS_OKAY);
            outct(c, XS1_CT_END);

            break;

        default:
            c <: (unsigned) AISRV_STATUS_ERROR_BAD_CMD;
            printstr("Unknown command (aiengine): "); printintln(cmd);
            break;
    }
}

void aiengine(inference_engine_t &ie, chanend ?c_usb, chanend ?c_spi,
              chanend ?c_push, chanend ?c_acquire, chanend (&?c_leds)[4],
              chanend ?c_flash
#if defined(TFLM_DISABLED)
              , uint32_t tflite_disabled_image[], uint32_t sizeof_tflite_disabled_image
#endif
    )
{
    aisrv_cmd_t cmd = CMD_NONE;
    uint32_t tensor_num = 0;

#if defined(TFLM_DISABLED)
    ie.input_sizes[0]  = sizeof_tflite_disabled_image;
    ie.output_sizes[0] = sizeof_tflite_disabled_image;
    ie.input_size  = sizeof_tflite_disabled_image;
    ie.output_size = sizeof_tflite_disabled_image;
    ie.output_times_size = 40;
    unsafe {
        ie.input_buffers[0] = tflite_disabled_image;
        ie.output_buffers[0] = tflite_disabled_image;
        ie.output_times = tflite_disabled_image;
    }
#endif
    
    ie.haveModel = 0;
    ie.acquireMode = AISRV_ACQUIRE_MODE_SINGLE;

    printstr("Ready\n");
    for(size_t i = 0; i< AISRV_GPIO_LENGTH; i++)
    {
        ie.outputGpioThresh[i] = -128;
    }

    ie.outputGpioMode = AISRV_GPIO_OUTPUT_MODE_NONE;

    while(1)
    {
        select
        {
            case (!isnull(c_usb)) => c_usb :> cmd:
                c_usb :> tensor_num;
                HandleCommand(ie, c_usb, c_push, cmd, tensor_num, c_acquire, c_leds, c_flash);
                break;
            
            case (!isnull(c_spi)) => c_spi :> cmd:
                c_spi :> tensor_num;
                HandleCommand(ie, c_spi, c_push, cmd, tensor_num, c_acquire, c_leds, c_flash);
                break;

            (ie.acquireMode == AISRV_ACQUIRE_MODE_STREAM) => default:
            {  
                size_t size;

                /* Run an acquire and a inference */ 
                c_acquire <: (unsigned) CMD_START_ACQUIRE_SINGLE;

                /* TODO check we dont overrun input_buffer */
                size = receive_array_(c_acquire, ie.input_buffers[0], 0);

                // TODO check model status and interp status
                interp_invoke(&ie);

                if(ie.outputGpioEn)
                {
                    HandleGpio(ie, c_leds);
                }

                break;
            }
        }
    }
}
} // unsafe


extern size_t receive_array_(chanend c, uint32_t * unsafe array, unsigned ignore);

int aisrv_local_get_output_tensor(chanend to, int tensor_num, uint32_t *data) {
    int status;
    to <: CMD_GET_OUTPUT_TENSOR;
    to <: tensor_num;
    to :> status;
    if (status != AISRV_STATUS_OKAY) {
        printstr("** err ");
        printintln(status);
        return 1;
    }
    unsafe {
        receive_array_(to, (uint32_t * unsafe) data, 0);
    }
    return 0;
}

int aisrv_local_acquire_single(chanend to, int sx, int ex, int sy, int ey, int rw, int rh) {
    uint16_t data[6] = {sx, ex, sy, ey, rw, rh};
    int status;
    to <: CMD_START_ACQUIRE_SINGLE;
    to <: 0;
    send_array(to, (data, uint32_t[]), 12);
    status = inuint(to); chkct(to, 1);
    if (status != AISRV_STATUS_OKAY) {
        printstr("** err ");
        printintln(status);
        return 1;
    }
    return 0;
}

int aisrv_local_start_inference(chanend to) {
    uint32_t data[1];
    int status;
    to <: CMD_START_INFER;
    to <: 0;
    send_array(to, (data, uint32_t[]), 0);
    status = inuint(to); chkct(to, 1);
    if (status != AISRV_STATUS_OKAY) {
        printstr("** err ");
        printintln(status);
        return 1;
    }
    return 0;
}
