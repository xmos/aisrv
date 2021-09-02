#!/usr/bin/env python
# Copyright (c) 2020, XMOS Ltd, All rights reserved

import sys
from xcore_ai_ie import xcore_ai_ie_usb, xcore_ai_ie_spi, AISRVError

if len(sys.argv) < 3:
    print("Usage: python3 " + sys.argv[0] + " (usb|spi) (ext|arena) model.tflit")
    exit(1)
if sys.argv[1] == 'usb':
    ie = xcore_ai_ie_usb()
elif sys.argv[1] == 'spi':
    ie = xcore_ai_ie_spi()
else:
    print("Only usb or spi supported")
    exit(1)

if sys.argv[2] == 'ext':
    ext_mem = True
elif sys.argv[2] == 'arena':
    ext_mem = False
else:
    print("Only ext or arena (external memory or tensor arena) supported")
    exit(1)

ie.connect()

engine_num = 0
for model in sys.argv[3:]:
    try:
        ie.download_model_file(model, ext_mem = ext_mem, engine_num = engine_num)
    except AISRVError:
        print("Device reported an error : ")
        debug_string = ie.read_debug_log()
        print(str(debug_string))
    engine_num += 1

