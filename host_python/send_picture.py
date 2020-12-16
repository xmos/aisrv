#!/usr/bin/env python

# Copyright (c) 2020, XMOS Ltd, All rights reserved
import sys
import os
import time
import struct
import ctypes
from math import sqrt

import numpy as np
from matplotlib import pyplot

import usb.core
import usb.util

from xcore_ai_ie import xcore_ai_ie_usb, xcore_ai_ie_spi


DRAW = False

INPUT_SCALE = 0.007843137718737125
INPUT_ZERO_POINT = -1
NORM_SCALE = 127.5
NORM_SHIFT = 1

OUTPUT_SCALE = 1/255.0
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

# TODO use quantize/dequantize from ai_tools
#from tflite2xcore.utils import quantize, dequantize   
def quantize(arr, scale, zero_point, dtype=np.int8):
    t = np.round(arr / scale + zero_point)
    return dtype(np.round(np.clip(t, np.iinfo(dtype).min, np.iinfo(dtype).max)))


def dequantize(arr, scale, zero_point):
    return np.float32((arr.astype(np.int32) - np.int32(zero_point)) * scale)

if sys.argv[1] == 'usb':
    ie = xcore_ai_ie_usb()
elif sys.argv[1] == 'spi':
    ie = xcore_ai_ie_spi()
else:
    print("Only spi or usb supported")

ie.connect()

input_length = ie.input_length
print("READING INPUT TENSOR LENGTH FROM DEVICE: " + str(input_length))

output_length = ie.output_length
print("READING OUTPUT TENSOR LENGTH FROM DEVICE: " + str(output_length))

input_shape_channels = 3
input_shape_spacial =  int(sqrt(input_length/input_shape_channels))
INPUT_SHAPE = (input_shape_spacial, input_shape_spacial, input_shape_channels)

print("Inferred input shape: " + str(INPUT_SHAPE))

raw_img = None

# Send image to device
for arg in sys.argv[2:]:
        print("SETTING INPUT TENSOR VIA USB\n")
        try:
            if not arg.endswith('.raw'):
                import cv2
                img = cv2.imread(arg)
                img = cv2.resize(img, (INPUT_SHAPE[0], INPUT_SHAPE[1]))
            
                # Channel swapping due to mismatch between open CV and XMOS
                img = img[:, :, ::-1]  # or image = image[:, :, (2, 1, 0)]

                img = (img / NORM_SCALE) - NORM_SHIFT
                img = np.round(quantize(img, INPUT_SCALE, INPUT_ZERO_POINT))

                raw_img = bytes(img)
            
            else:
                raw_file = open(arg, 'rb')
                raw_img = raw_file.read()
                raw_file.close()
            
            #newFile = open("raw_img.raw", "wb")
            #newFile.write(raw_img)
            ie.write_input_tensor(raw_img)
                
        except KeyboardInterrupt:
            pass

        print("Sending start inference command")
        ie.start_inference()

        print("Waiting for inference")
        output_data_int = ie.read_output_tensor()

        max_value = max(output_data_int)
        max_value_index = output_data_int.index(max_value)

        prob = (max_value - OUTPUT_ZERO_POINT) * OUTPUT_SCALE * 100.0
        print("Output tensor read as ", str(output_data_int),", this is a " + OBJECT_CLASSES[max_value_index], f"{prob:0.2f}%")

        if DRAW: 

            np_img = np.frombuffer(raw_img, dtype=np.int8).reshape(INPUT_SHAPE)
            np_img = np.round(
                (dequantize(np_img, INPUT_SCALE, INPUT_ZERO_POINT) + NORM_SHIFT) * NORM_SCALE
            ).astype(np.uint8)

            pyplot.imshow(np_img)
            pyplot.show()


        times = ie.read_times()
        
        print("Time per layer: "+ str(times))
