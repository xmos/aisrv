#!/usr/bin/env python

# Copyright (c) 2020, XMOS Ltd, All rights reserved
import sys
import os
import time
import struct
import ctypes
import cv2

import numpy as np
from matplotlib import pyplot

import usb.core
import usb.util

# Commands - TODO properly share with app code
CMD_LENGTH_BYTES = 1

CMD_NONE = 0
CMD_GET_OUTPUT_LENGTH = 1
CMD_SET_INPUT_TENSOR = 2
CMD_START_INFER = 3
CMD_GET_OUTPUT_TENSOR = 4
CMD_SET_MODEL = 5
###


MAX_PACKET_SIZE = 512 # TODO read from device

PRINT_CALLBACK = ctypes.CFUNCTYPE(
    None, ctypes.c_ulonglong, ctypes.c_uint, ctypes.c_char_p
)


def quantize(arr, scale, zero_point, dtype=np.int8):
    t = np.round(arr / scale + zero_point)
    return dtype(np.round(np.clip(t, np.iinfo(dtype).min, np.iinfo(dtype).max)))


def dequantize(arr, scale, zero_point):
    return np.float32((arr.astype(np.int32) - np.int32(zero_point)) * scale)

# find our device
dev = None
while dev is None:
    dev = usb.core.find(idVendor=0x20b1) #, idProduct=0xa15e)

# was it found?
if dev is None:
    raise ValueError('Device not found')

# set the active configuration. With no arguments, the first
# configuration will be the active one
dev.set_configuration()

# get an endpoint instance
cfg = dev.get_active_configuration()

#print("found device: \n" + str(cfg))
intf = cfg[(0,0)]

out_ep = usb.util.find_descriptor(
    intf,
    # match the first OUT endpoint
    custom_match = \
    lambda e: \
        usb.util.endpoint_direction(e.bEndpointAddress) == \
        usb.util.ENDPOINT_OUT)

in_ep = usb.util.find_descriptor(
    intf,
    # match the first OUT endpoint
    custom_match = \
    lambda e: \
        usb.util.endpoint_direction(e.bEndpointAddress) == \
        usb.util.ENDPOINT_IN)

assert out_ep is not None
assert in_ep is not None

print("Connected")

print("WRITING MODEL VIA USB..\n")

with open(sys.argv[1], "rb") as input_fd:
    input_model = input_fd.read()

model_bytes = bytearray(input_model)

print("Model length (bytes): " + str(len(model_bytes)))

#Send model to device 
out_ep.write(bytes([CMD_SET_MODEL]))

# Send model size
len_bytes = int.to_bytes(len(model_bytes), byteorder = "little", signed=True, length=4)
out_ep.write(len_bytes, 1000)

out_ep.write(model_bytes, 1000)

print("FINISHED WRITING MODEL")

