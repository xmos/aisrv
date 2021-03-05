CMD_NONE                        = int(0x00)
CMD_GET_STATUS                  = int(0x01)

CMD_GET_INPUT_TENSOR            = int(0x03)
CMD_SET_INPUT_TENSOR            = int(0x83)

CMD_SET_SERVER                  = int(0x04)
CMD_START_INFER                 = int(0x84)

CMD_GET_OUTPUT_TENSOR           = int(0x05)

CMD_GET_MODEL_INT               = int(0x06)    
CMD_SET_MODEL_INT               = int(0x86)
CMD_GET_MODEL_EXT               = int(0x07)    
CMD_SET_MODEL_EXT               = int(0x87)

CMD_GET_SPEC                    = int(0x08)

CMD_GET_TIMINGS                 = int(0x09)

CMD_GET_INPUT_TENSOR_LENGTH     = int(0x0A)     

CMD_GET_OUTPUT_TENSOR_LENGTH    = int(0x0B)   

CMD_START_ACQUIRE_SINGLE        = int(0x8C)

CMD_START_ACQUIRE_STREAM        = int(0x8E)

CMD_GET_SENSOR_TENSOR           = int(0x0D)
CMD_SET_SENSOR_TENSOR           = int(0x8D)

CMD_GET_DEBUG_LOG               = int(0x0F)

CMD_GET_ID                      = int(0x10)

CMD_HELLO                       = int(0x55)

