#!/usr/bin/env python
# Copyright (c) 2020, XMOS Ltd, All rights reserved

import sys
from xcore_ai_ie import xcore_ai_ie_usb, xcore_ai_ie_spi, AISRVError

ie = xcore_ai_ie_usb()
ie.connect()

try:
    ie.load_model_from_flash(     0, 345112, ext_mem = False, engine_num = 0)
    ie.load_model_from_flash(345112, 144776, ext_mem = False, engine_num = 1)
except AISRVError:
    print("Device reported an error : ")
    debug_string = ie.read_debug_log()
    print(str(debug_string))

