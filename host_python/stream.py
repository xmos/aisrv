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

