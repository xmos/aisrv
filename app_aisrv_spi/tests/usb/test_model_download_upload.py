#!/usr/bin/env python
# Copyright (c) 2020, XMOS Ltd, All rights reserved

from xcore_ai_ie import xcore_ai_ie_usb

ie = xcore_ai_ie_usb()

ie.connect()

model_file1 = "../../../model/model_quant_xcore.tflite"

# Read model file
with open(model_file1, "rb") as input_fd:
    model_data1 = input_fd.read()

CYCLE_COUNT = 5

for x in range(CYCLE_COUNT):

    # Send to device
    ie.download_model(bytearray(model_data1))

    # Read back model and check
    model_read = ie.upload_model()
    assert model_read == bytearray(model_data1)





