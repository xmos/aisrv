#include <stdio.h>
#include <stdint.h>
#include "aiengine.h"
#include "inference_commands.h"
#include "inference_engine.h"


extern int output_size;

extern "C" 
{
    int interp_init();
    int buffer_input_data(void *data, int offset, size_t size);
    void print_output(); 
    extern unsigned char * unsafe output_buffer;
    void write_model_data(int i, unsigned char x);
    extern int input_size;
}

void aiengine(chanend x) {
    int running = 1;
    uint32_t status = 0;
    while(running) {
        int cmd, N;
        x :> cmd;
        switch(cmd) {
        case INFERENCE_ENGINE_READ_TENSOR:
            slave {
                x :> N;
                for(int i = 0; i < 4*N; i++) {
                    unsafe {
                        x <: output_buffer[i];
                    }
                }
            }
            break;
        case INFERENCE_ENGINE_WRITE_MODEL:
            slave {
                x :> N;
            
                if(N*4 > MAX_MODEL_SIZE_BYTES) {
                    printf("Warning not enough space allocated for model %d %d\n", N, MAX_MODEL_SIZE_BYTES);
                } else {
                    printf("Model size: %d\n", N);
                }
                for(int i = 0; i < N; i++) {
                    uint32_t data;
                    x :> data;
                    // TODO: remove this wrapper
                    write_model_data(4*i+0,(data >>  0) & 0xff); 
                    write_model_data(4*i+1,(data >>  8) & 0xff); 
                    write_model_data(4*i+2,(data >> 16) & 0xff); 
                    write_model_data(4*i+3,(data >> 24) & 0xff); 
                }
            }
            status = interp_init();
            // TODO: signal success/error to other side.
//            c <: status;

            printf("Wrote model %d\n", status);
            break;
        case INFERENCE_ENGINE_WRITE_TENSOR:
            slave {
                x :> N;
                for(int i = 0; i < N; i++) {
                    uint32_t data;
                    x :> data;
                    buffer_input_data(&data, i*4, 4);
                }
            }
            break;
        case INFERENCE_ENGINE_INFERENCE:
            uint32_t status = interp_invoke();
            break;
        case INFERENCE_ENGINE_EXIT:
            running = 0;
            break;
        }
    }
}


#if 0
unsafe{
void interp_runner(chanend c)
{
    aisrv_cmd_t cmd = CMD_NONE;
    unsigned length = 0;
    unsigned char data[512];

    unsigned haveModel = 0;

    while(1)
    {
        c :> cmd;

        switch(cmd)
        {
            case CMD_SET_INPUT_TENSOR:

                aisrv_status_t status = STATUS_OKAY;

                if(haveModel)
                {
                    c <: STATUS_OKAY;
                    c <: input_size;

                    slave
                    {
                        /* TODO improve efficiency of comms */
                    }
                }
                else
                {
                    c <: STATUS_ERROR_NO_MODEL;
                }

                break;

            case CMD_START_INFER:

                aisrv_status_t status = STATUS_OKAY;

                if(haveModel)
                {
                    status = interp_invoke();
                    //print_output();
                }
                else
                {
                    status = STATUS_ERROR_NO_MODEL;
                }

                c <: status;
                break;
            
            case CMD_GET_OUTPUT_TENSOR_LENGTH:

                if(haveModel)
                {
                    c <: STATUS_OKAY;
                    c <: output_size; 
                }
                else
                {
                    c <: STATUS_ERROR_NO_MODEL;
                }

                break;

            case CMD_GET_OUTPUT_TENSOR:
                slave
                {
                    for(int i = 0; i < output_size; i++)
                    {
                        c <: output_buffer[i];
                    }
                }
                break;

            default:
                break;
        }
    }
}
}

void aisrv_usb_data( chanend c)
{
    unsigned char data[512];
    unsigned length = 0;


    aisrv_cmd_t cmd = CMD_NONE;

    int infer_in_progress = 0;
    int result_requested = 0;

    int output_size = 0;

    while(1)
    {
        /* Get command */
//        XUD_GetBuffer(ep_out, data, length);
                
        cmd = data[0];

        if(length != CMD_LENGTH_BYTES)
        {
            printf("Bad cmd length: %d\n", length);
            continue;
        }
        if(cmd > CMD_END_MARKER)
        {
            printf("Bad cmd: %d\n", cmd);
        }
                       
        switch(cmd)
        {
            case CMD_SET_MODEL: 

                c <: cmd;

                /* First packet contains size only */
//                XUD_GetBuffer(ep_out, data, length);
    
                int model_size = (data, unsigned[])[0];

                printf("model size: %d\n", model_size);

                master
                {
                    c <: model_size;

                    while(model_size > 0)
                    {
//                        XUD_GetBuffer(ep_out, data, length);
        
                        for(int i = 0; i < length; i++)
                        {
                            c <: data[i];
                        }

                        model_size = model_size - length;
                    }
                }
    
                /* TODO handle any error */
                c :> int status;
                printf("model written commed\n");
                break; 

            case CMD_SET_INPUT_TENSOR:
                
                aisrv_status_t status;

                c <: cmd;

                c :> status;

                if(status == STATUS_OKAY)
                {
                    unsigned pktLength, tensorLength;
                    
                    c :> tensorLength;

                    master
                    {
                        while(tensorLength > 0)
                        {
//                            XUD_GetBuffer(ep_out, data, pktLength);
                            
                            printf("Got %d bytes\n", pktLength);
                   
                            c <: pktLength;
                            for(int i = 0; i < pktLength; i++)
                                c <: data[i];

                            tensorLength = tensorLength - pktLength;
                        }
                    }
                }

                break;

            case CMD_GET_OUTPUT_TENSOR_LENGTH:

                aisrv_status_t status = STATUS_OKAY;
            
                c <: cmd;
                c :> status;

                if(status == STATUS_OKAY)
                {
                    c :> output_size;
//                    XUD_SetBuffer(ep_in, (output_size, unsigned char[]), 4);
                }
                else
                {
//                    XUD_SetStall(ep_in);
//                    XUD_SetStall(ep_out);
                }

                break;

            case CMD_START_INFER:

                c <: CMD_START_INFER;
                /* Block this thread until done - we have no way of responding to commands while one is in progress */

                aisrv_status_t status;
                c :> status;

                if(status != STATUS_OKAY)
                {
//                    XUD_SetStall(ep_in);
//                    XUD_SetStall(ep_out);
                }

                break;

            case CMD_GET_OUTPUT_TENSOR:
               
                /* TODO handle len(output_buffer) > MAX_PACKET_SIZE */
                unsigned char buffer[MAX_PACKET_SIZE];
   
                c <: cmd;

                master 
                {
                    for(int i = 0; i < output_size; i++)
                        c :> buffer[i] ;
                }
//                XUD_SetBuffer(ep_in, buffer, output_size);

             default:
                break;


        }
    } // while(1)
}
} // unsafe
#endif
