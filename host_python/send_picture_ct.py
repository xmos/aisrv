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

# TODO use quantize/dequantize from ai_tools
#from tflite2xcore.utils import quantize, dequantize   
def quantize(arr, scale, zero_point, dtype=np.int8):
    t = np.round(arr / scale + zero_point)
    return dtype(np.round(np.clip(t, np.iinfo(dtype).min, np.iinfo(dtype).max)))

ie = xcore_ai_ie_usb()

ie.connect()

input_length = ie.input_length
print("READING INPUT TENSOR LENGTH FROM DEVICE: " + str(input_length))

output_length = ie.output_length
print("READING OUTPUT TENSOR LENGTH FROM DEVICE: " + str(output_length))

input_shape_channels = 3
input_shape_spacial =  int(sqrt(input_length/input_shape_channels))
INPUT_SHAPE = (input_shape_spacial, input_shape_spacial, input_shape_channels)

print("Inferred input shape: " + str(INPUT_SHAPE))

# Send image to device
for arg in sys.argv[1:]:
    print("Setting input tensor via " + arg + "\n")
    import cv2
    img = cv2.imread(arg)
    img = cv2.resize(img, (INPUT_SHAPE[0], INPUT_SHAPE[1]))
    
    # Channel swapping due to mismatch between open CV and XMOS
    img = img[:, :, ::-1]  # or image = image[:, :, (2, 1, 0)]

    img = (img / NORM_SCALE) - NORM_SHIFT
    img = np.round(quantize(img, INPUT_SCALE, INPUT_ZERO_POINT))

    raw_img = bytes(img)
        
    ie.write_input_tensor(raw_img)

    print("Sending start inference command")
    ie.start_inference()

    print("Waiting for inference")
    output_data_int = ie.read_output_tensor()

    x0 = ie.read_output_tensor(tensor_num = 0)
#    x1 = ie.read_output_tensor(tensor_num = 1)
#    print('Got output tensors of lengths ', len(x0), len(x1))
    print(x0)
#    print(x1)
    times = ie.read_times()
       
    print("Time per layer: "+ str(times))

            
