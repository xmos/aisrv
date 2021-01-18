#include <xs1.h>
#include <stdio.h>
#include <stdint.h>
#include "aisrv.h"
#include "shared_memory.h"
#include "spibuffer.h"

static void read_spec(chanend to_engine, struct memory * unsafe mem) 
{
    int status;

    to_engine <: CMD_GET_SPEC;

    to_engine :> status; 

    unsafe 
    {
        for(int i = 0; i < SPEC_MODEL_TOTAL; i++)
            mem->spec[i] = inuint(to_engine);
        inct(to_engine); inct(to_engine);

        mem->input_tensor_length = (mem->spec[SPEC_INPUT_TENSOR_LENGTH]+3) / 4;
        mem->output_tensor_length = (mem->spec[SPEC_OUTPUT_TENSOR_LENGTH]+3) / 4;
        mem->timings_length = mem->spec[SPEC_TIMINGS_LENGTH];
        mem->sensor_tensor_length = (mem->spec[SPEC_SENSOR_TENSOR_LENGTH]+3) / 4;
    }
}

static inline void set_mem_status(uint32_t status[1], uint32_t byte, uint32_t val) {
    asm volatile("st8 %0, %1[%2]" :: "r" (val), "r" (status), "r" (byte));
}
//         = STATUS_NORMAL;

void spi_buffer(chanend from_spi, chanend to_engine, chanend to_sensor, struct memory * unsafe mem) 
{
    unsigned cmd_in_flight = 0;
    
    aisrv_status_t status = STATUS_OKAY;
    
    unsafe
    {
    set_mem_status(mem->status, STATUS_BYTE_STATUS, status);
   
    
    while(1) 
    {
        int cmd;
        int N;
        
        status = (mem->status, uint8_t[])[STATUS_BYTE_STATUS];
        set_mem_status(mem->status, STATUS_BYTE_STATUS, status & ~STATUS_BUSY);
        
        from_spi :> cmd;
        
        status = (mem->status, uint8_t[])[STATUS_BYTE_STATUS];
        set_mem_status(mem->status, STATUS_BYTE_STATUS, status | STATUS_BUSY);

        switch(cmd) 
        {
        case CMD_SET_MODEL:
       
            from_spi :> N;
            
            if(!cmd_in_flight)
            {
                to_engine <: cmd;
                cmd_in_flight = 1;
            }
            
            for(int i = 0; i < N/4; i++) {
                outuint(to_engine, mem->memory[i]);
            }
            
            if (N != MAX_PACKET_SIZE)
            {
                cmd_in_flight = 0;
                outct(to_engine, XS1_CT_END); outct(to_engine,XS1_CT_END);
              
                status = inuint(to_engine);
                chkct(to_engine, XS1_CT_END);

                if(status == STATUS_OKAY)
                {
                    read_spec(to_engine, mem);
                }
                else
                {
                    status = (mem->status, uint8_t[])[STATUS_BYTE_STATUS]; 
                    set_mem_status(mem->status, STATUS_BYTE_STATUS, status | STATUS_ERROR_MODEL_ERR);
                }
            }

            break;
        case CMD_SET_INPUT_TENSOR:
            from_spi :> N;
            
            if(!cmd_in_flight)
            {
                to_engine <: cmd;
                cmd_in_flight = 1;
            }

            for(int i = 0; i < N/4; i++)
                outuint(to_engine, mem->memory[mem->input_tensor_index + i]);
            
            if(N != MAX_PACKET_SIZE)
            {
                cmd_in_flight = 0;
                outct(to_engine, XS1_CT_END); outct(to_engine,XS1_CT_END);
            
                /* TODO check or pass on status */ 
                aisrv_status_t status;
                status = inuint(to_engine);
                chkct(to_engine, XS1_CT_END);
            }
            break;

        case CMD_START_INFER:
            
            /* TODO check or pass on status */   
            aisrv_status_t status;
            
            to_engine <: CMD_START_INFER;
            outct(to_engine, XS1_CT_END);
            outct(to_engine, XS1_CT_END);
            status = inuint(to_engine);
            chkct(to_engine, XS1_CT_END);

            to_engine <: CMD_GET_OUTPUT_TENSOR;
            to_engine :> status;

            /* Get output tensor - TODO use receive_array func */
            size_t i = 0;
            while(!testct(to_engine))
            {
                mem->memory[mem->output_tensor_index + i] = inuint(to_engine);
                i++;
            }
            chkct(to_engine, XS1_CT_END);
            i *= 4;
            while(!testct(to_engine))
            {
                (mem->memory, uint8_t[])[mem->output_tensor_index + i] = inuchar(to_engine);
                i++;
            }
            chkct(to_engine, XS1_CT_END);
           
            #if 0 
            // TODO
            to_engine <: CMD_GET_TIMINGS;
            master {
                to_engine <: mem->timings_length;
                for(int i = 0; i < mem->timings_length; i++) {
                    unsafe {
                    to_engine :> mem->memory[mem->timings_index + i];
                    }
                }
            }
            #endif 
            mem->tensor_is_sensor_output = 0;
            break;
        case CMD_SET_SERVER:
            // DFU
            break;
        case CMD_START_ACQUIRE:
            set_mem_status(mem->status, STATUS_BYTE_STATUS, STATUS_OKAY | STATUS_SENSING | STATUS_BUSY);
            to_sensor <: cmd;
            to_sensor :> int _;
            set_mem_status(mem->status, STATUS_BYTE_STATUS, STATUS_OKAY | STATUS_BUSY);
            // watch out: <= not < to force a zero block at the end
            for(int block = 0; block <= mem->input_tensor_length; block += MAX_PACKET_SIZE_WORDS) {
                to_engine <: CMD_SET_INPUT_TENSOR;
                master {
                    int len = mem->input_tensor_length - block;
                    if (len > MAX_PACKET_SIZE_WORDS) {
                        len = MAX_PACKET_SIZE_WORDS;
                    }
                    to_engine <: len;
                    for(int i = 0; i < len; i++) {
                        to_engine <: mem->memory[block+i];
                    }
                }
                mem->tensor_is_sensor_output = 1;
            }
            break;
        }
    }
}
}
