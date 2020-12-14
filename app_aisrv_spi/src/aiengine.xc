#include <xs1.h>
#include <stdio.h>
#include <stdint.h>
#include "aiengine.h"
#include "aisrv.h"
#include "inference_engine.h"

unsafe
{

static inline void send_array(chanend c, uint32_t * unsafe array, unsigned size)
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

void interp_runner(chanend c)
{
    aisrv_cmd_t cmd = CMD_NONE;
    size_t length = 0;
    unsigned data[MAX_PACKET_SIZE_WORDS]; // TODO rm me

    unsigned haveModel = 0;
    unsigned model_size;

    unsafe { inference_engine_initialize(&ie); }

    while(1)
    {
        c :> cmd;

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
                c <: (unsigned) STATUS_OKAY;
                send_array(c, spec, SPEC_MODEL_TOTAL*sizeof(uint32_t));
                break;

            case CMD_SET_MODEL:
                
                #if 0
                     if(model_size > MAX_MODEL_SIZE_BYTES)
                        printf("Warning not enough space allocated for model %d %d\n", model_size, MAX_MODEL_SIZE_BYTES);
                    else
                        printf("Model size: %d\n", model_size);
                #endif
                
                receive_array_(c, ie.model_data, 0);
                
                haveModel = !interp_initialize(&ie);
                outuint(c, haveModel);
                outct(c, XS1_CT_END);

                printf("Model written %d\n", haveModel);

                break;
    
            /* TODO debug only = remove for production */
            case CMD_GET_MODEL:
                
                /* TODO bad status if no model */
                c <: (unsigned) STATUS_OKAY;
                send_array(c, ie.model_data, model_size);
                break;

            case CMD_SET_INPUT_TENSOR:

                 // TODO check size vs input_size
                size_t size = receive_array_(c, ie.input_buffer, !haveModel);
            
                if(haveModel)
                {
                    outuint(c, STATUS_OKAY);
                    outct(c, XS1_CT_END);
                }
                else
                {
                    outuint(c, STATUS_ERROR_NO_MODEL);
                    outct(c, XS1_CT_END);
                }
                break;

            case CMD_START_INFER:

                aisrv_status_t status = STATUS_OKAY;

                /* Note currently receive one dummy byte */
                /* TODO remove the need for this */
                size_t size = receive_array_(c, data, 0);
                    
                if(haveModel)
                {
                    status = interp_invoke();
                    //print_output();
                }
                else
                {
                    status = STATUS_ERROR_NO_MODEL;
                }

                outuint(c, status);
                outct(c, XS1_CT_END);
                break;
            
            case CMD_GET_OUTPUT_TENSOR_LENGTH:
    
                // TODO use a send array function 
                if(haveModel)
                {
                    c <: (unsigned) STATUS_OKAY;
                    send_array(c, &ie.output_size, sizeof(ie.output_size));
                }
                else
                {
                    c <: STATUS_ERROR_NO_MODEL;
                }

                break;

             case CMD_GET_INPUT_TENSOR_LENGTH:
                
                // TODO use a send array function 
                if(haveModel)
                {
                    c <: (unsigned) STATUS_OKAY;
                    send_array(c, &ie.input_size, sizeof(ie.input_size));
                }
                else
                {
                    c <: STATUS_ERROR_NO_MODEL;
                }

                break;

            case CMD_GET_OUTPUT_TENSOR:
                c <: (unsigned) STATUS_OKAY;
                send_array(c, ie.output_buffer, ie.output_size);
                break;

            default:
                printf("Uknown command: %d\n", cmd);
                break;
        }
    }
}
} // unsafe

void aiengine(chanend x) {
    int model_offset = 0;
    int input_tensor_offset = 0;
    uint32_t status = 0;
    unsafe { inference_engine_initialize(&ie); }
    while(1) {
        int cmd, N;
        x :> cmd;
        switch(cmd) {
        case CMD_GET_SPEC:
            slave {
                uint32_t spec[SPEC_MODEL_TOTAL];
                spec[SPEC_WORD_0] = 0;
                spec[SPEC_WORD_1] = 0;
                spec[SPEC_INPUT_TENSOR_LENGTH] = ie.input_size;
                spec[SPEC_OUTPUT_TENSOR_LENGTH] = ie.output_size;
                spec[SPEC_TIMINGS_LENGTH] = ie.output_times_size;
                for(int i = 0; i < SPEC_MODEL_TOTAL; i++) {
                    x <: spec[i];
                }
            }
            break;
        case CMD_GET_OUTPUT_TENSOR:
            slave {
                x :> N;
                for(int i = 0; i < 4*N; i++) {
                    unsafe {
                        x <: ie.output_buffer[i];
                    }
                }
            }
            break;
        case CMD_GET_TIMINGS:
            slave {
                x :> N;
                for(int i = 0; i < N; i++) {
                    unsafe {
                        x <: ie.output_times[i];
                    }
                }
            }
            break;
        case CMD_SET_MODEL:
            slave {
                x :> N;
                for(int i = 0; i < N; i++) {
                    uint32_t data;
                    x :> data;
                    ((uint32_t *)ie.model_data)[model_offset] = data;
                    model_offset ++;
                }
            }
            if (N != MAX_PACKET_SIZE_WORDS) {
                unsafe {
                    status = interp_initialize(&ie);
                }
                printf("Model inited\n");
                model_offset = 0;
            }
            // TODO: signal success/error to other side.
//            c <: status;

            break;
        case CMD_SET_INPUT_TENSOR:
            slave {
                x :> N;
                for(int i = 0; i < N; i++) {
                    uint32_t data;
                    x :> data;
                    unsafe {((uint32_t *)ie.input_buffer)[input_tensor_offset] = data;}
                    input_tensor_offset ++;
                }
            }
            if (N != MAX_PACKET_SIZE_WORDS) {
                input_tensor_offset = 0;
            }
            break;
        case CMD_START_INFER:
            uint32_t status = interp_invoke();
            break;
        }
    }
}


