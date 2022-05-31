#include <xs1.h>
#include <stdio.h>
#include <stdint.h>
#include <print.h>
#include "aisrv.h"

uint32_t in_out_array[2048];

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


static void HandleCommand(chanend c,
                          aisrv_cmd_t cmd,
                          uint32_t tensor_num)
{
    uint32_t data[MAX_PACKET_SIZE_WORDS];
    switch(cmd)
    {

        case CMD_SET_ARRAY:

            size_t size = receive_array_(c, (uint32_t *)in_out_array, 0);
            for(int i = 0; i < 10; i++) {
                printf("%08x\n", in_out_array[i]);
            }
            outuint(c, AISRV_STATUS_OKAY);
            outct(c, XS1_CT_END);
            break;


        case CMD_GET_ARRAY:
            c <: (unsigned) AISRV_STATUS_OKAY;
            for(int i = 0; i < 1000; i++) {
                in_out_array[i] = 0x01010101 * i;
            }
            send_array(c, (uint32_t *)in_out_array, 2000);
            break;
        

        default:
            c <: (unsigned) AISRV_STATUS_ERROR_BAD_CMD;
            printstr("Unknown command (aiengine): "); printintln(cmd);
            break;
    }
}

void send_recv_engine(chanend ?c_usb)
{
    aisrv_cmd_t cmd = CMD_NONE;
    uint32_t tensor_num = 0;

    printstr("Ready\n");

    while(1)
    {
        select
        {
            case (!isnull(c_usb)) => c_usb :> cmd:
                c_usb :> tensor_num;
                HandleCommand(c_usb, cmd, tensor_num);
                break;
        }
    }
}
} // unsafe


extern size_t receive_array_(chanend c, uint32_t * unsafe array, unsigned ignore);

