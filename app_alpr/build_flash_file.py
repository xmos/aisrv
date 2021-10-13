#!/usr/bin/env python
# Copyright (c) 2020, XMOS Ltd, All rights reserved

import sys
from xcore_ai_ie import xcore_ai_ie_usb, xcore_ai_ie_spi, AISRVError
import flexbuffers


with open('test.flash', 'rb') as fd:
    buf = fd.read()
print(buf)
r = flexbuffers.Loads(buf)
print(r)
sys.exit(0)

engines = (len(sys.argv)-2) // 2
    
if len(sys.argv) - 2 * engines != 2 or len(sys.argv) < 4:
    print("Usage: python3 " + sys.argv[0] + " flash.bin [modelX.tflite modelX.parameter] (X times)")
    sys.exit(1)
    
class header:
    def __init__(self, model, parameters, operators, start):
        self.model_length = len(model)
        self.model_start = start
        self.parameters_start = start + len(model)
        self.operators_start = start + len(model) + len(parameters)
        self.length = len(model) + len(parameters) + len(operators)
        self.model = model
        self.parameters = parameters
        self.operators = operators

def read_whole_file(filename):
    if filename == '-':
        return bytes([])
    with open(filename, "rb") as input_fd:
        contents = input_fd.read()
    return contents

def tobytes(integr):
    data = []
    for i in range(4):
        data.append((integr >> (8*i)) & 0xff)
    return bytes(data)

headers = [None] * engines
start = 16 * engines
for i in range(engines):
    model_data = read_whole_file(sys.argv[2*i+2])
    parameter_data = read_whole_file(sys.argv[2*i+3])
    headers[i] = header(model_data, parameter_data, bytes([]), start)
    start += headers[i].length

output = bytes([])
for i in range(engines):
    output += tobytes(headers[i].model_length)
    output += tobytes(headers[i].model_start)
    output += tobytes(headers[i].parameters_start)
    output += tobytes(headers[i].operators_start)

for i in range(engines):
    output += headers[i].model
    output += headers[i].parameters
    output += headers[i].operators

print("Flash image size ", len(output))

with open(sys.argv[1], "wb") as output_fd:
    output_fd.write(output)

