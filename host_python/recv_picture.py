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

input_length = ie.input_length
input_shape_channels = 3
input_shape_spatial =  int(np.sqrt(input_length/input_shape_channels))
INPUT_SHAPE = (input_shape_spatial, input_shape_spatial, input_shape_channels)

print("Input shape: " + str(INPUT_SHAPE) + " inferred from length " + str(input_length) + " and depth " + str(input_shape_channels))

# Get image from device
for arg in sys.argv[1:]:
    print("Reading input tensor into " + sys.argv[1])
    ie.start_acquire_single()
    raw_img = ie.read_input_tensor()
    ie.start_inference()
    np_img = np.asarray(raw_img).reshape(INPUT_SHAPE)
    np_img = np_img + np.asarray([128,0,0])
    print(np_img[:,:,0])
    print(np_img[:,:,1])
    print(np_img[:,:,2])
    conversion = np.asarray([[1.0, 0.0, 1.14],[1.0, -0.39, -0.58], [1.0, 2.03, 0.0]])
    conversion = conversion.T
    rgb = np.dot(np_img, conversion)
    rgb = rgb / 255.0
    rgb = np.clip(rgb, 0.0, 1.0)
#    print(rgb)
    pyplot.imshow(rgb)
    pyplot.show()
    
    cv2.imwrite(arg + 'Y.png', np_img[:, :, 0])      # Just Y
    cv2.imwrite(arg + 'U.png', np_img[:, :, 1]+128)  # Just U
    cv2.imwrite(arg + 'V.png', np_img[:, :, 2]+128)  # Just V
    cv2.imwrite(arg + 'RGB.png', cv2.cvtColor((rgb*255).astype(np.uint8), cv2.COLOR_RGB2BGR))  # RGB version
    x = ie.read_output_tensor()
    print('Got output tensor of length', len(x))
    times = ie.read_times()
        
    print("Time per layer: "+ str(times))

            
