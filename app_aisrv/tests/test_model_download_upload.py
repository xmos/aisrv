#!/usr/bin/env python
# Copyright (c) 2020, XMOS Ltd, All rights reserved

# TODO remove this
import sys
sys.path.append('../')

from xcore_ai_ie import xcore_ai_ie_usb

ie = xcore_ai_ie_usb()

ie.connect()

model_file = "../model/model_quant_xcore.tflite"

# Read model file
with open(model_file, "rb") as input_fd:
    model_data = input_fd.read()

# Send to device
ie.download_model(bytearray(model_data))

# Read back model and check
model_read = ie.upload_model()
assert model_read == bytearray(model_data)

# Re-download
ie.download_model_file(model_file)

# Re-read and check
model_read = ie.upload_model()
assert model_read == bytearray(model_data)




