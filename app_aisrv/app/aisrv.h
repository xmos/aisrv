void aisrv_usb(chanend c_ep_out[], chanend c_ep_in[]);

#define CMD_LENGTH_BYTES (1)

typedef enum aisrv_cmd
{
    CMD_NONE = 0,
    CMD_GET_OUTPUT_LENGTH = 1,
    CMD_SET_INPUT = 2,
    CMD_END_MARKER = 3,
} aisrv_cmd_t;


typedef enum aisrv_state
{
    STATE_IDLE,
    STATE_SET_INPUT,
    STATE_INFER,
    STATE_INFER_DONE,
    STATE_END_MARKER

} aisrv_state_t;
