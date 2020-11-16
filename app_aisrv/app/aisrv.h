
#define MAX_PACKET_SIZE (512)

void aisrv_usb(chanend c_ep_out[], chanend c_ep_in[]);

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

#if 0
typedef enum aisrv_state
{
    STATE_IDLE,
    STATE_SET_INPUT,
    STATE_INFER,
    STATE_INFER_DONE,
    STATE_END_MARKER

} aisrv_state_t;
#endif
