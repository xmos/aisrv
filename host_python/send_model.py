#!/usr/bin/env python
# Copyright (c) 2020, XMOS Ltd, All rights reserved

import sys
from xcore_ai_ie import xcore_ai_ie_usb, xcore_ai_ie_spi

if sys.argv[1] == 'usb':
    ie = xcore_ai_ie_usb()
elif sys.argv[1] == 'spi':
    ie = xcore_ai_ie_spi()
else:
    print("only usb or spi supported")
    exit(1)

ie.connect()

ie.download_model_file(sys.argv[2])





