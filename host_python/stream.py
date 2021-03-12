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

if sys.argv[1] == 'usb':
    ie = xcore_ai_ie_usb()
elif sys.argv[1] == 'spi':
    ie = xcore_ai_ie_spi()
else:
    print("Only spi or usb supported")

ie.connect()

ie.start_acquire_stream()

while True:
    #print("Waiting for inference")
    output_data_int = ie.read_output_tensor()
    print(output_data_int)

    max_value = max(output_data_int)
    max_value_index = output_data_int.index(max_value)

    prob = (max_value - OUTPUT_ZERO_POINT) * OUTPUT_SCALE * 100.0
    print("Output tensor read as ", str(output_data_int),", this is a " + OBJECT_CLASSES[max_value_index], f"{prob:0.2f}%")

