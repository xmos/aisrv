#!/usr/bin/env python
# Copyright (c) 2020, XMOS Ltd, All rights reserved

import sys
import numpy as np
from matplotlib import pyplot
import cv2
import usb.core
import usb.util
from xcore_ai_ie import xcore_ai_ie_usb, xcore_ai_ie_spi

ie = xcore_ai_ie_usb()
ie.connect()
INPUT_SHAPE = (480,300,2)

# Get image from device
for arg in sys.argv[1:]:
    print("GETTING INPUT TENSOR INTO " + sys.argv[1] + "\n")
    ie.start_acquire_single()
    raw_img = ie.read_input_tensor()
    
    np_img = np.asarray(raw_img).reshape(INPUT_SHAPE)
    np_img = np_img[:, :, 0]  # Get rid of U/V
    np_img = np_img + 128

    pyplot.imshow(np_img)
    pyplot.show()

    cv2.imwrite(arg, np_img)

            
