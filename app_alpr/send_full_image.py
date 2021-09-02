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


def dequantize(arr, scale, zero_point):
    return np.float32((arr.astype(np.int32) - np.int32(zero_point)) * scale)

ie = xcore_ai_ie_usb()
ie.connect()

input_length = ie.input_length
print("READING INPUT TENSOR LENGTH FROM DEVICE: " + str(input_length))

output_length = ie.output_length
print("READING OUTPUT TENSOR LENGTH FROM DEVICE: " + str(output_length))

INPUT_SHAPE = (160,160,3)

print("Input shape: " + str(INPUT_SHAPE))

raw_img = None

# Send image to device
for arg in sys.argv[2:]:
        print("SETTING INPUT TENSOR VIA " + sys.argv[1] + "\n")
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
        
        ie.write_input_tensor(raw_img)

        print("Sending start inference command")
        ie.start_inference()

        print("Waiting for inference")
        classes_int = ie.read_output_tensor(tensor_num = 0)
        boxes_int = ie.read_output_tensor(tensor_num = 1)

        classes_int = np.reshape(classes_int, (460, 2))
        boxes_int = np.reshape(boxes_int, (460, 4))
        
        max_index = np.argmax(np.reshape(classes_int[:,1], (460)))
        max_box = boxes_int[max_index]
        print (max_index, classes_int[max_index], max_box)

        times = ie.read_times()
        
        print("Time per layer: "+ str(times))
