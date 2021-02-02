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

if sys.argv[1] == 'usb':
    ie = xcore_ai_ie_usb()
elif sys.argv[1] == 'spi':
    ie = xcore_ai_ie_spi()
else:
    print("Only spi or usb supported")

ie.connect()

input_length = ie.input_length
print("READING INPUT TENSOR LENGTH FROM DEVICE: " + str(input_length))

input_shape_channels = 3
input_shape_spacial =  int(sqrt(input_length/input_shape_channels))
INPUT_SHAPE = (input_shape_spacial, input_shape_spacial, input_shape_channels)

print("Inferred input shape: " + str(INPUT_SHAPE))

raw_img = None


ie.start_acquire_single()

sensor_tensor = ie.read_sensor_tensor()

SENSOR_SHAPE=[128,128]

r = sensor_tensor
#r = [x-256 if x > 127 else x for x in r]

r = [x + 128 for x in sensor_tensor]

np_img = np.array(r).reshape(SENSOR_SHAPE)#astype(np.uint8)
            #np_img = np.round(
            #    (dequantize(np_img, INPUT_SCALE, INPUT_ZERO_POINT) + NORM_SHIFT) * NORM_SCALE
            #).astype(np.uint8)

np_img = np.repeat(np_img[:, :, np.newaxis], 3, axis=2)

print(str(np_img[0]))
print(str(np_img[1]))

pyplot.imshow(np_img)
pyplot.show()
