#!/usr/bin/env python
# Copyright (c) 2020, XMOS Ltd, All rights reserved

import sys
from xcore_ai_ie import xcore_ai_ie_usb, xcore_ai_ie_spi, AISRVError

if len(sys.argv) != 3:
    print("Usage: python3 " + sys.argv[0] + " model0.tflite model1.tflite")

ie = xcore_ai_ie_usb()
ie.connect()

try:
    ie.download_model_file(sys.argv[1], secondary_memory = True, engine_num = 0)
    ie.download_model_file(sys.argv[2], secondary_memory = False, engine_num = 1)
except AISRVError:
    print("Device reported an error : ")
    debug_string = ie.read_debug_log()
    print(str(debug_string))


