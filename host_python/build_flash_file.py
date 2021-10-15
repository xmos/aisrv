#!/usr/bin/env python
# Copyright (c) 2020, XMOS Ltd, All rights reserved

import sys
from xcore_ai_ie import xcore_ai_ie_usb, xcore_ai_ie_spi, AISRVError
import flexbuffers

import argparse
    
class header:
    """
    Class that stores a header for a flash file system
    The header comprises the addresses of the model, parameters, and operators
    relative to the start address
    """
    def __init__(self, model, parameters, operators, start):
        self.model_length = len(model)
        self.model_start = start
        self.parameters_start = start + len(model)
        self.operators_start = start + len(model) + len(parameters)
        self.length = len(model) + len(parameters) + len(operators)
        self.model = model
        self.parameters = parameters
        self.operators = operators

def read_whole_binary_file(filename):
    """
    Reads a whole binary file in and returns bytes(). If the file to be read is called '-'
    then an empty bytes is returned.
    """
    if filename == '-':
        return bytes([])
    with open(filename, "rb") as input_fd:
        contents = input_fd.read()
    return contents

def read_whole_parameter_file(filename):
    """
    Reads a parameter binary file in and returns bytes(). If the file to be read is called '-'
    then an empty bytes is returned. The parameter file is assumed to be a flexbuffer, and the
    first blob is returned. This is easily changed to glue all blobs together. An error is
    produced if this does not look like a flexbuffer file.
    """
    if filename == '-':
        return bytes([])
    try:
        with open(filename, 'rb') as fd:
            buf = fd.read()
        r = flexbuffers.Loads(buf)
        return r['params'][0]                   # Glue them all together?
    except:
        print('File "%s" is not a flexbuffer with a "params" field' % (filename))
        sys.exit(1)
        
def tobytes(integr):
    """ Converts an int to a LSB first quad of bytes """
    data = []
    for i in range(4):
        data.append((integr >> (8*i)) & 0xff)
    return bytes(data)

def build_flash_image(files):
    """
    Builds a flash image out of a collection of models and parameter blobs.
    This function returns a bytes comprising the header, models, parameters, etc.
    The whole thing should be written as is to flash
    """
    engines = len(files) // 2
    headers = [None] * engines
    start = 16 * engines
    for i in range(engines):
        model_data = read_whole_binary_file(files[2*i])
        parameter_data = read_whole_parameter_file(files[2*i+1])
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
    return output


def build_parameter_file(par_file):
    """
    Builds a file for the host system that comprises a single parameter blob.
    """
    output = read_whole_parameter_file(par_file)
    return output


parser = argparse.ArgumentParser(description='Build parameter/flash images')
parser.add_argument('--output', default='image.bin',  help='output file')
parser.add_argument('--target', default='host',       help='"flash" or "host" (default)')
parser.add_argument('files',    nargs='+', help='Model and parameter files, - indicates a missing one, must be an even number of files for "flash", or a single file for "host"')

args = parser.parse_args()

if args.target == 'flash':
    if len(args.files) %2 != 0:
        parser.print_usage()
        sys.exit(1)
    output = build_flash_image(args.files)
    print("Flash image size is", len(output))

elif args.target == 'host':
    if len(args.files) != 1:
        parser.print_usage()
        sys.exit(1)
    output = build_parameter_file(args.files[0])
    print("Parameter image size is", len(output))

else:
    parser.print_usage()
    sys.exit(1)
    
with open(args.output, "wb") as output_fd:
    output_fd.write(output)

