#define INFERENCE_ENGINE_READ_STATUS  0x01
#define INFERENCE_ENGINE_READ_ID      0x03
#define INFERENCE_ENGINE_READ_SPEC    0x07 // Tmp change to match USB mode
#define INFERENCE_ENGINE_READ_TENSOR  0x05 // Tmp change to match USB mode
#define INFERENCE_ENGINE_READ_TIMINGS 0x09
#define INFERENCE_ENGINE_WRITE_MODEL  0x02
#define INFERENCE_ENGINE_WRITE_SERVER 0x04
#define INFERENCE_ENGINE_WRITE_TENSOR 0x83 // Tmp change to match USB mode
#define INFERENCE_ENGINE_INFERENCE    0x84 // Tmp change to match USB mode
#define INFERENCE_ENGINE_ACQUIRE      0x0A
#define INFERENCE_ENGINE_HELLO        0x55
#define INFERENCE_ENGINE_EXIT         0xFF

#define STATUS_BYTE_STATUS        0
#define STATUS_BUSY            0x01
#define STATUS_NORMAL          0x80
#define STATUS_BYTE_ERROR         1
#define STATUS_ERROR           0x01

#define INFERENCE_ENGINE_ID          0x12345678//0x633
#define INFERENCE_ENGINE_SPEC        0x000


#define DUMMY_CLOCKS                  16
