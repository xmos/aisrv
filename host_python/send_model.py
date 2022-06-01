#!/usr/bin/env python
# Copyright (c) 2020, XMOS Ltd, All rights reserved

<<<<<<< HEAD
import sys, os
=======
import sys
>>>>>>> develop
from xcore_ai_ie import xcore_ai_ie_usb, xcore_ai_ie_spi, AISRVError

if len(sys.argv) < 3:
    print("Usage: python3 " + sys.argv[0] + " (usb|spi) (single|split) model.tflite")
    exit(1)
if sys.argv[1] == 'usb':
    ie = xcore_ai_ie_usb()
elif sys.argv[1] == 'spi':
    ie = xcore_ai_ie_spi()
else:
    print("Only usb or spi supported")
    exit(1)

<<<<<<< HEAD
if sys.argv[2] == 'split':
    secondary = True
elif sys.argv[2] == 'single':
    secondary = False
else:
    print("Only single or split (single or split memory space for arena and model) supported")
    exit(1)
=======
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
>>>>>>> develop

ie.connect()

engine_num = 0
for model in sys.argv[3:]:
    try:
        ie.download_model_file(model, secondary_memory = secondary, engine_num = engine_num)
        ie.set_model_path(model, engine_num)
    except AISRVError:
        print("Device reported an error : ")
        debug_string = ie.read_debug_log()
        print(str(debug_string))
        if os.path.exists("current_model.txt"):
            os.remove("current_model.txt")

    engine_num += 1

