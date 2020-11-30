#ifndef _AISRV_H_
#define _AISRV_H_

typedef enum aisrv_cmd
{
    CMD_GET_STATUS        = 0x01,
    CMD_GET_ID            = 0x03,
    CMD_GET_SPEC          = 0x05,
    CMD_GET_TENSOR        = 0x07,
    CMD_GET_TIMINGS       = 0x09,

    CMD_SET_MODEL         = 0x02,
    CMD_SET_SERVER        = 0x04,
    CMD_SET_TENSOR        = 0x06,
    
    CMD_START_INFER       = 0x08,
    CMD_START_ACQUIRE     = 0x0A,
    CMD_HELLO             = 0x55,
} aisrv_cmd_t;
    
#define STATUS_BYTE_STATUS        0
#define STATUS_BUSY            0x01
#define STATUS_NORMAL          0x80
#define STATUS_BYTE_ERROR         1
#define STATUS_ERROR           0x01

#define INFERENCE_ENGINE_ID          0x12345678//0x633


#define DUMMY_CLOCKS                  16

typedef enum aisrv_status
{
    STATUS_OKAY = 0,
    STATUS_BUFFER_FULL,
    STATUS_ERROR_NO_MODEL,
    STATUS_ERROR_INFER,
} aisrv_status_t;

#endif
