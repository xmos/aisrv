#ifndef _AISRV_H_
#define _AISRV_H_

#include <stdint.h>

//#ifdef ENABLE_MIPI
//#define USB_TILE tile[0]
//#else
//#define USB_TILE tile[1]
//#endif

#define AISRV_CMD_WRITE_BIT_MASK    (0x80) // Note, usage of this is not automatic - manually change commands if this is modified
#define CMD_LENGTH_BYTES            (1)
#define MAX_PACKET_SIZE             (512)
#define MAX_PACKET_SIZE_WORDS       (MAX_PACKET_SIZE / 4)
#define INFERENCE_ENGINE_ID         (0x12345678)//0x633
#define DUMMY_CLOCKS                (16)
#define MAX_DEBUG_LOG_LENGTH        (100)
#define MAX_DEBUG_LOG_ENTRIES       (3)

#define RAW_IMAGE_HEIGHT (320/2)
#define RAW_IMAGE_WIDTH  (320/2)

typedef enum aisrv_cmd
{
    #define int(x) x,
    #include "../../host_python/xcore_ai_ie/aisrv_cmd.py"
    #undef int
} aisrv_cmd_t;
    
#define STATUS_BYTE_STATUS        (0)
//#define STATUS_BYTE_ERROR         (1)

typedef enum aisrv_spec {
    SPEC_WORD_0                   = 0x00,
    SPEC_WORD_1                   = 0x01,
    SPEC_INPUT_TENSOR_LENGTH      = 0x02,
    SPEC_OUTPUT_TENSOR_LENGTH     = 0x03,
    SPEC_TIMINGS_LENGTH           = 0x04,
    SPEC_MODEL_TOTAL              = 0x05,      // Up to this one it is the model
    SPEC_SENSOR_TENSOR_LENGTH     = 0x05,      // From here it is acquistion
    SPEC_ALL_TOTAL                = 0x06       // All data words.
} aisrv_spec_t;

typedef enum aisrv_status
{
    AISRV_STATUS_OKAY                 = 0x00,
    AISRV_STATUS_BUSY                 = 0x01,
    AISRV_STATUS_SENSING              = 0x02,
    AISRV_STATUS_ERROR_NO_MODEL       = 0x04,
    AISRV_STATUS_ERROR_MODEL_ERR      = 0x08,
    AISRV_STATUS_ERROR_INFER_ERR      = 0x10,
    AISRV_STATUS_ERROR_BAD_CMD        = 0x20
} aisrv_status_t;

#ifdef __XC__
void aisrv_usb_data(chanend c_ep_out, chanend c_ep_in, chanend c, chanend c_ep0);
void aisrv_usb_ep0(chanend c_ep0_out, chanend c_ep0_in, chanend c_dat);
#endif

#endif
