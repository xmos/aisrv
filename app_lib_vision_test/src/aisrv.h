#ifndef _AISRV_H_
#define _AISRV_H_

#include <stdint.h>

#define AISRV_CMD_WRITE_BIT_MASK    (0x80) // Note, usage of this is not automatic - manually change commands if this is modified
#define CMD_LENGTH_BYTES            (3)    // CMD, Tile, Tensor
#define MAX_PACKET_SIZE             (512)
#define MAX_PACKET_SIZE_WORDS       (MAX_PACKET_SIZE / 4)
#define INFERENCE_ENGINE_ID         (0x12345678)//0x633
#define DUMMY_CLOCKS                (16)


// Including all commands that are being used, shared with... Python!
typedef enum aisrv_cmd
{
    CMD_NONE = 0x00,
    CMD_SET_ARRAY = 0x83,
    CMD_GET_ARRAY = 0x03,
} aisrv_cmd_t;
   

typedef enum aisrv_status
{
    AISRV_STATUS_OKAY               = 0x00,
    AISRV_STATUS_BUSY               = 0x01,
    AISRV_STATUS_SENSING            = 0x02,
    AISRV_STATUS_ERROR_NO_MODEL     = 0x04,
    AISRV_STATUS_ERROR_MODEL_ERR    = 0x08,
    AISRV_STATUS_ERROR_INFER_ERR    = 0x10,
    AISRV_STATUS_ERROR_BAD_CMD      = 0x20
} aisrv_status_t;

typedef enum aisrv_acquire_mode
{
    AISRV_ACQUIRE_MODE_SINGLE       = 0x00,
    AISRV_ACQUIRE_MODE_STREAM       = 0x01,
} aisrv_acquire_mode_t;

#ifdef __XC__
void aisrv_usb_data(chanend c_ep_out, chanend c_ep_in, chanend c_engine[], chanend c_ep0);
void aisrv_usb_ep0(chanend c_ep0_out, chanend c_ep0_in, chanend c_dat);
void exit(int);
#endif

#endif
