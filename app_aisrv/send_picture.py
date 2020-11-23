#!/usr/bin/env python

# Copyright (c) 2020, XMOS Ltd, All rights reserved
import sys
import os
import time
import struct
import ctypes
import cv2

import numpy as np
from matplotlib import pyplot

import usb.core
import usb.util

from xmos_aisrv import aisrv_usb

DRAW = False
SEND_MODEL = False
MODEL_PATH = "./model/model_quant_xcore.tflite"

MAX_PACKET_SIZE = 512 # TODO read from device
INPUT_SHAPE = (128, 128, 3)
INPUT_SCALE = 0.007843137718737125
INPUT_ZERO_POINT = -1
NORM_SCALE = 127.5
NORM_SHIFT = 1

OUTPUT_SCALE = 0.00390625
OUTPUT_ZERO_POINT = -128

OBJECT_CLASSES = [
    "tench",
    "goldfish",
    "great_white_shark",
    "tiger_shark",
    "hammerhead",
    "electric_ray",
    "stingray",
    "cock",
    "hen",
    "ostrich",
]

PRINT_CALLBACK = ctypes.CFUNCTYPE(
    None, ctypes.c_ulonglong, ctypes.c_uint, ctypes.c_char_p
)

# TODO use quantize/dequantize from ai_tools
def quantize(arr, scale, zero_point, dtype=np.int8):
    t = np.round(arr / scale + zero_point)
    return dtype(np.round(np.clip(t, np.iinfo(dtype).min, np.iinfo(dtype).max)))


def dequantize(arr, scale, zero_point):
    return np.float32((arr.astype(np.int32) - np.int32(zero_point)) * scale)


aisrv = aisrv_usb()

aisrv.connect()

output_length = aisrv.output_length

print("READING OUTPUT TENSOR LENGTH FROM DEVICE: " + str(output_length))

raw_img = None

# Send image to device
for arg in sys.argv[1:]:
        print("SETTING INPUT TENSOR VIA USB\n")
        try:
            img = cv2.imread(arg)
            img = cv2.resize(img, (INPUT_SHAPE[0], INPUT_SHAPE[1]))
            
            # Channel swapping due to mismatch between open CV and XMOS
            img = img[:, :, ::-1]  # or image = image[:, :, (2, 1, 0)]

            img = (img / NORM_SCALE) - NORM_SHIFT
            img = np.round(quantize(img, INPUT_SCALE, INPUT_ZERO_POINT))

            raw_img = bytes(img)

            aisrv.set_input_tensor(raw_img)
            
                
        except KeyboardInterrupt:
            pass

        print("Sending start inference command")
        aisrv.start_inference()

        print("Waiting for inference")
        output_data_int = aisrv.get_output_tensor()

        max_value = max(output_data_int)
        max_value_index = output_data_int.index(max_value)

        prob = (max_value - OUTPUT_ZERO_POINT) * OUTPUT_SCALE * 100.0
        print("Output tensor read as ", str(output_data_int), ", this is a " + OBJECT_CLASSES[max_value_index], f"{prob:0.2f}%")

        if DRAW: 

            np_img = np.frombuffer(raw_img, dtype=np.int8).reshape(INPUT_SHAPE)
            np_img = np.round(
                (dequantize(np_img, INPUT_SCALE, INPUT_ZERO_POINT) + NORM_SHIFT) * NORM_SCALE
            ).astype(np.uint8)

            pyplot.imshow(np_img)
            pyplot.show()