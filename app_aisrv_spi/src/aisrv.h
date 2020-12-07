#ifndef _AISRV_H_
#define _AISRV_H_

#define CMD_LENGTH_BYTES             (1)
#define MAX_PACKET_SIZE              (512)
#define MAX_PACKET_SIZE_WORDS        (MAX_PACKET_SIZE / 4)
#define INFERENCE_ENGINE_ID           0x12345678//0x633
#define DUMMY_CLOCKS                  16

typedef enum aisrv_cmd
{   
    CMD_NONE                        = 0x00,
    CMD_GET_STATUS                  = 0x01,
    CMD_GET_ID                      = 0x03,
    CMD_GET_OUTPUT_TENSOR           = 0x05,

    CMD_GET_TIMINGS                 = 0x09,

    CMD_GET_MODEL                   = 0x06,     // TODO remove for production
    CMD_SET_MODEL                   = 0x86,
    CMD_SET_SERVER                  = 0x04,
    CMD_SET_INPUT_TENSOR            = 0x83,
    
    CMD_GET_SPEC                    = 0x07,
    CMD_GET_INPUT_TENSOR_LENGTH     = 0x0A,     // Note, currently unsed by SPI mode (used GET_SPEC)
    CMD_GET_OUTPUT_TENSOR_LENGTH    = 0x0B,     // Note, currently unsed by SPI mode (used GET_SPEC)

    CMD_START_INFER                 = 0x84,
    CMD_START_ACQUIRE               = 0x0C,   
    CMD_HELLO                       = 0x55,
} aisrv_cmd_t;
    
#define STATUS_BYTE_STATUS        0
#define STATUS_BUSY            0x01
#define STATUS_SENSING         0x02
#define STATUS_FLASHING        0x04
#define STATUS_NORMAL          0x80
#define STATUS_BYTE_ERROR         1
#define STATUS_ERROR           0x01

typedef enum aisrv_spec {
    SPEC_WORD_0                   = 0x00,
    SPEC_WORD_1                   = 0x01,
    SPEC_INPUT_TENSOR_LENGTH      = 0x02,
    SPEC_OUTPUT_TENSOR_LENGTH     = 0x03,
    SPEC_TIMINGS_LENGTH           = 0x04,
    SPEC_MODEL_TOTAL         = 0x05,      // Up to this one it is the model
    SPEC_SENSOR_TENSOR_LENGTH     = 0x05, // From here it is acquistion
    SPEC_ALL_TOTAL           = 0x06       // All data words.
} aisrv_spec_t;

typedef enum aisrv_status
{
    STATUS_OKAY = 0,
    STATUS_BUFFER_FULL,
    STATUS_ERROR_NO_MODEL,
    STATUS_ERROR_INFER,
} aisrv_status_t;


#endif
