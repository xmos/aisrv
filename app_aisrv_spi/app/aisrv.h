
#ifndef _AISRV_H_
#define _AISRV_H_
#define MAX_PACKET_SIZE (512)

#ifdef __XC__
void aisrv_usb(chanend c_ep_out[], chanend c_ep_in[]);
#endif

#define CMD_LENGTH_BYTES (1)

typedef enum aisrv_cmd
{
    CMD_NONE = 0,
    CMD_GET_OUTPUT_TENSOR_LENGTH = 1,
    CMD_SET_INPUT_TENSOR = 2,
    CMD_START_INFER = 3,
    CMD_GET_OUTPUT_TENSOR = 4,
    CMD_SET_MODEL = 5, 
    CMD_END_MARKER = 6,
} aisrv_cmd_t;

typedef enum aisrv_status
{
    STATUS_OKAY = 0,
    STATUS_BUFFER_FULL,
    STATUS_ERROR_NO_MODEL,
    STATUS_ERROR_INFER,
} aisrv_status_t;

#endif
