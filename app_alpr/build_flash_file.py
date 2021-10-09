#!/usr/bin/env python
# Copyright (c) 2020, XMOS Ltd, All rights reserved

import sys
from xcore_ai_ie import xcore_ai_ie_usb, xcore_ai_ie_spi, AISRVError

if len(sys.argv) != 4:
    print("Usage: python3 " + sys.argv[0] + " model0.tflite model1.tflite flashfile")

with open(sys.argv[1], "rb") as input_fd:
    model_0_data = input_fd.read()
    
with open(sys.argv[2], "rb") as input_fd:
    model_1_data = input_fd.read()
    
print("Models are of length ", len(model_0_data), " and ", len(model_1_data))
model_out_data = model_0_data + model_1_data
print("Combined models are ", len(model_out_data))

with open(sys.argv[3], "wb") as output_fd:
    model_1_data = output_fd.write(model_out_data)

