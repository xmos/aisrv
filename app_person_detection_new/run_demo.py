#!/usr/bin/env python
# Copyright (c) 2020, XMOS Ltd, All rights reserved

import sys
import struct
import ctypes

import numpy as np
from matplotlib import pyplot
import matplotlib.pyplot as plt

from xcore_ai_ie import xcore_ai_ie_usb, xcore_ai_ie_spi, AISRVError

model0 = 'models/QuickNetTinyBB_192x256_inference_first_half_4_threads_xcore.tflite'
model1 = 'models/QuickNetTinyBB_192x256_inference_second_half_1_thread_xcore.tflite'

ie = xcore_ai_ie_usb()

ext_mem = False

ie.connect()

try:
    ie.download_model_file(model0, ext_mem = False, engine_num = 0)
    ie.download_model_file(model1, ext_mem = False, engine_num = 1)
except AISRVError:
    print("Device reported an error : ")
    debug_string = ie.read_debug_log()
    print(str(debug_string))



INPUT_SHAPE = (192, 256, 4)

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
        ie.start_acquire_single(0, 256, 0, 192, 256, 192)
        raw_img = ie.read_input_tensor()
        img = np.reshape(raw_img, (INPUT_SHAPE[0], INPUT_SHAPE[1], 4))
        img = img[:,:,:-1]
        img = img + 128
        
        print("Sending start inference command")
        ie.start_inference()

        print("Waiting for inference")
        
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
        
