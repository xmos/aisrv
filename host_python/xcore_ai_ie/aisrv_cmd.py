# unused at present
# could be included from C with a #define int(x) x,

CMD_GET_STATUS        = int(0x01)
CMD_GET_ID            = int(0x03)
CMD_GET_SPEC          = int(0x05)
CMD_GET_TENSOR        = int(0x07)
CMD_GET_TIMINGS       = int(0x09)

CMD_SET_MODEL         = int(0x02)
CMD_SET_SERVER        = int(0x04)
CMD_SET_TENSOR        = int(0x06)

CMD_START_INFER       = int(0x08)
CMD_START_ACQUIRE     = int(0x0A)
CMD_HELLO             = int(0x55)
