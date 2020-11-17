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

DRAW = False
SEND_MODEL = True
MODEL_PATH = "./model/model_quant_xcore.tflite"

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
INPUT_SHAPE = (128, 128, 3)
INPUT_SCALE = 0.007843137718737125
INPUT_ZERO_POINT = -1
NORM_SCALE = 127.5
NORM_SHIFT = 1

OUTPUT_SCALE = 0.00390625
OUTPUT_ZERO_POINT = -128

OBJECT_CLASSES = [
    "tench",
    "goldfish",
    "great_white_shark",
    "tiger_shark",
    "hammerhead",
    "electric_ray",
    "stingray",
    "cock",
    "hen",
    "ostrich",
]

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

if SEND_MODEL:

    with open(MODEL_PATH, "rb") as input_fd:
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


# Get output size from device
out_ep.write(bytes([CMD_GET_OUTPUT_LENGTH]), 50000)

try:
    output_length = int.from_bytes(dev.read(in_ep, 4, 10000), byteorder = "little", signed=True)
    print("OUTPUT TENSOR LENGTH: " + str(output_length))
except usb.core.USBError as e:

    if e.backend_error_code == usb.backend.libusb1.LIBUSB_ERROR_PIPE:
        print("Device error, IN pipe halted (no model uploaded?)")
        
    sys.exit(1)


raw_img = None

# Send image to device

try:
    img = cv2.imread(sys.argv[1])
    img = cv2.resize(img, (INPUT_SHAPE[0], INPUT_SHAPE[1]))
    
    # Channel swapping due to mismatch between open CV and XMOS
    img = img[:, :, ::-1]  # or image = image[:, :, (2, 1, 0)]

    img = (img / NORM_SCALE) - NORM_SHIFT
    img = np.round(quantize(img, INPUT_SCALE, INPUT_ZERO_POINT))

    raw_img = bytes(img)

    out_ep.write(bytes([CMD_SET_INPUT_TENSOR]))

    sentcount = 0
    for i in range(0, len(raw_img), MAX_PACKET_SIZE):
        out_ep.write(raw_img[i : i + MAX_PACKET_SIZE])
        sentcount = sentcount + MAX_PACKET_SIZE
        size_str = "sent: " + str(sentcount)
        sys.stdout.write('%s\r' % size_str)
        sys.stdout.flush()
   
    
    sys.stdout.write('%s.. Done\n'  % size_str)
        
except KeyboardInterrupt:
    pass

print("STARTING INFERENCE\n")
out_ep.write(bytes([CMD_START_INFER]), 1000)

print("WAITING FOR INFERENCE\n")
out_ep.write(bytes([CMD_GET_OUTPUT_TENSOR]), 50000)

# Retrieve result from device
# TODO deal with len(output_data > MAX_PACKET_SIZE)
#output_data = dev.read(in_ep, output_length, 1000)
output_data = dev.read(in_ep, output_length, 10000)

output_data_int = []

# TODO better way of doing this?
for i in output_data:
    x =  int.from_bytes([i], byteorder = "little", signed=True)
    output_data_int.append(x)

print("OUTPUT_TENSOR: " + str(output_data_int))

max_value = max(output_data_int)
max_value_index = output_data_int.index(max_value)

prob = (max_value - OUTPUT_ZERO_POINT) * OUTPUT_SCALE * 100.0
print(OBJECT_CLASSES[max_value_index], f"{prob:0.2f}%")

if DRAW: 

    np_img = np.frombuffer(raw_img, dtype=np.int8).reshape(INPUT_SHAPE)
    np_img = np.round(
        (dequantize(np_img, INPUT_SCALE, INPUT_ZERO_POINT) + NORM_SHIFT) * NORM_SCALE
    ).astype(np.uint8)

    pyplot.imshow(np_img)
    pyplot.show()
