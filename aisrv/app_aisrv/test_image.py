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

CHUCK_SIZE = 128 # TODO read from device

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
dev = usb.core.find(idVendor=0x20b1) #, idProduct=0xa15e)

# was it found?
if dev is None:
    raise ValueError('Device not found')

# set the active configuration. With no arguments, the first
# configuration will be the active one
dev.set_configuration()

# get an endpoint instance
cfg = dev.get_active_configuration()

print("found device: \n" + str(cfg))
intf = cfg[(0,0)]

ep = usb.util.find_descriptor(
    intf,
    # match the first OUT endpoint
    custom_match = \
    lambda e: \
        usb.util.endpoint_direction(e.bEndpointAddress) == \
        usb.util.ENDPOINT_OUT)

assert ep is not None

print("Connected")

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

    sentcount = 0
    for i in range(0, len(raw_img), CHUCK_SIZE):
        ep.write(raw_img[i : i + CHUCK_SIZE])
        sentcount = sentcount + CHUCK_SIZE
        size_str = "sent: " + str(sentcount)
        sys.stdout.write('%s\r' % size_str)
        sys.stdout.flush()
   
    
    sys.stdout.write('%s.. Done\n'  % size_str)
        
except KeyboardInterrupt:
    pass

# Retrieve result from device

#if raw_img is not None:
#    max_value = -128
#    max_value_index = 0
#    for line in ep.lines:
#        if line.startswith("Output index"):
#            fields = line.split(",")
##            index = int(fields[0].split("=")[1])
#            value = int(fields[1].split("=")[1])
#            if value >= max_value:
#                max_value = value
#                max_value_index = index
#    print()
#    prob = (max_value - OUTPUT_ZERO_POINT) * OUTPUT_SCALE * 100.0
#    print(OBJECT_CLASSES[max_value_index], f"{prob:0.2f}%")
#
#    np_img = np.frombuffer(raw_img, dtype=np.int8).reshape(INPUT_SHAPE)
#    np_img = np.round(
#        (dequantize(np_img, INPUT_SCALE, INPUT_ZERO_POINT) + NORM_SHIFT) * NORM_SCALE
#    ).astype(np.uint8)
#
#    pyplot.imshow(np_img)
#    pyplot.show()
