#!/usr/bin/env python
# Copyright (c) 2020, XMOS Ltd, All rights reserved

import sys
from xcore_ai_ie import xcore_ai_ie_usb, xcore_ai_ie_spi, AISRVError

if sys.argv[1] == 'usb':
    ie = xcore_ai_ie_usb()
elif sys.argv[1] == 'spi':
    ie = xcore_ai_ie_spi()
else:
    print("only usb or spi supported")
    exit(1)

if sys.argv[2] == 'ext':
    ext_mem = True
elif sys.argv[2] == 'int':
    ext_mem = False
else:
    print("only ext or int (external or internal memory) supported")
    exit(1)

ie.connect()

try:
    ie.download_model_file(sys.argv[3], ext_mem = ext_mem)
except AISRVError:
    print("Device reported an error")
    debug_string = ie.read_debug_log()
    print("Debug log from device: " +  str(debug_string))



