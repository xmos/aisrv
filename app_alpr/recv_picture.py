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

#INPUT_SHAPE = (32, 128, 3)
INPUT_SHAPE = (320, 320, 3)
#INPUT_SHAPE = (16, 66, 1)

print("Input shape: " + str(INPUT_SHAPE))

# Get image from device
#ie.acquire_set_i2c(0x3C, 0xfe, 0x00)
#ie.acquire_set_i2c(0x3C, 0x84, 0x01)
ie.start_acquire_single(160, 480, 80, 400, 320, 320)
#ythoraw_img = ie.read_input_tensor(engine_num = 1)
raw_img = ie.read_input_tensor(engine_num = 0)
print(len(raw_img))
raw_img = raw_img[:INPUT_SHAPE[0]*INPUT_SHAPE[1]*INPUT_SHAPE[2]]
print(len(raw_img))
np_img = np.asarray(raw_img).reshape(INPUT_SHAPE)
rgb = np_img + np.asarray([128,128,128])
pyplot.imshow(rgb)
pyplot.show()
    
            
