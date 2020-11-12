
#define MAX_PACKET_SIZE (512)

void aisrv_usb(chanend c_ep_out[], chanend c_ep_in[]);

#define CMD_LENGTH_BYTES (1)

typedef enum aisrv_cmd
{
    CMD_NONE = 0,
    CMD_GET_OUTPUT_LENGTH = 1,
    CMD_SET_INPUT = 2,
    CMD_START_INFER = 3,
    CMD_GET_RESULT = 4,
    CMD_END_MARKER = 5,
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
