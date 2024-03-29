#!/usr/bin/env python

# Copyright (c) 2020, XMOS Ltd, All rights reserved
import sys
import os
import time
import struct
import ctypes
from math import sqrt
from io import BytesIO

import numpy as np
from matplotlib import pyplot
import matplotlib.pyplot as plt
import usb.core
import usb.util

from xcore_ai_ie import xcore_ai_ie_usb, xcore_ai_ie_spi


DRAW = False

INPUT_SCALE = 0.007843137718737125
INPUT_ZERO_POINT = -1
NORM_SCALE = 127.5
NORM_SHIFT = 1

OUTPUT_SCALE = 1/255.0
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
#from tflite2xcore.utils import quantize, dequantize   
def quantize(arr, scale, zero_point, dtype=np.int8):
    t = np.round(arr / scale + zero_point)
    return dtype(np.round(np.clip(t, np.iinfo(dtype).min, np.iinfo(dtype).max)))


def dequantize(arr, scale, zero_point):
    return np.float32((arr.astype(np.int32) - np.int32(zero_point)) * scale)

ie = xcore_ai_ie_usb()

ie.connect()


#intermediate = ie.read_input_tensor(tensor_num = 0, engine_num=1)
#intermediate = np.asarray(intermediate)
##intermediate *= 0
#intermediate = intermediate[:2000]
#print(len(intermediate))
#ie.write_input_tensor(bytes(intermediate), tensor_num = 0, engine_num=1)
ie.start_inference(engine_num=1)


input_length = ie.input_length
print("READING INPUT TENSOR LENGTH FROM DEVICE: " + str(input_length))

output_length = ie.output_length
print("READING OUTPUT TENSOR LENGTH FROM DEVICE: " + str(output_length))

input_shape_channels = 4
INPUT_SHAPE = (192, 256, input_shape_channels)

print("Inferred input shape: " + str(INPUT_SHAPE))

raw_img = None

def to_float(bs):
        out = []
        for i in range(0, len(bs), 4):
                a0 = bs[i] % 256
                a1 = bs[i+1] % 256
                a2 = bs[i+2] % 256
                a3 = bs[i+3] % 256
                [f] = struct.unpack('f', bytes([a0,a1,a2,a3]))
                out.append(f)
        return out

# Send image to device
while True:
        print("Sending acquire command")
        ie.start_acquire_single(0)
        raw_img = ie.read_input_tensor()
        img = np.reshape(raw_img, (INPUT_SHAPE[0], INPUT_SHAPE[1], 4))
        img = img[:,:,:-1]
        img = img + 128

        print("Sending start inference command")
        ie.start_inference()

        print("Waiting for inference")
#        intermediate = ie.read_output_tensor(tensor_num = 0, engine_num=0)
#        intermediate = np.asarray(intermediate)
#        intermediate += 128
#        intermediate = intermediate[:24000]
#        print(len(intermediate))
#        ie.write_input_tensor(bytes(intermediate), tensor_num = 0, engine_num=1)
#        ie.start_inference(engine_num=1)
        
        output_data=[0,0,0]
        for on in range(0, 3, 2):
                output_data[on] = ie.read_output_tensor(tensor_num = on, engine_num=1)
                output_data[on] = to_float(output_data[on])
                print("Output tensor ", on, " read as ", str(output_data[on]))



        times = ie.read_times()
        
        print("Time per layer (engine 0): ", sum(times), str(times))

        times = ie.read_times(engine_num=1)
        
        print("Time per layer (engine 1): ", sum(times), str(times))

        for i in range(len(output_data[2])):
                if output_data[2][i] > 0.0:
                        t = int(output_data[0][4*i] * INPUT_SHAPE[0])
                        l = int(output_data[0][4*i+1] * INPUT_SHAPE[1])
                        b = int(output_data[0][4*i+2] * INPUT_SHAPE[0])
                        r = int(output_data[0][4*i+3] * INPUT_SHAPE[1])
                        print(t, l, b, r)
                        t = min(max(t, 0), INPUT_SHAPE[0]-1)
                        b = min(max(b, 0), INPUT_SHAPE[0]-1)
                        l = min(max(l, 0), INPUT_SHAPE[1]-1)
                        r = min(max(r, 0), INPUT_SHAPE[1]-1)
                        print(t, l, b, r)
                        print(img.shape)
                        for y in range(t, b):
                                img[y,l] = [255,0,0]
                                img[y,r] = [255,0,0]
                        for x in range(l, r):
                                img[t,x] = [255,0,0]
                                img[b,x] = [255,0,0]

        plt.imshow(img)
        plt.draw()
        plt.pause(0.01)
        
