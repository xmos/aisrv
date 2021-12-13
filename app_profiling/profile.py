#TODO:
#Cant set tools env

import time, yaml, os, signal, runpy, pymongo, sys
import numpy as np
from pprint import pprint
from datetime import datetime
from xcore_ai_ie import xcore_ai_ie_usb, xcore_ai_ie_spi
from tflite.Model import Model


if (sys.argv[1] == 'true') or (sys.argv[1] == 'false'):
    pass 
else:
    print('Option 1 (Use Database) must be true or false')
    quit()

use_db = sys.argv[1]

def configToDict():
    with open(r'./profiling/config.yaml') as file:
        documents = yaml.full_load(file)
    return documents

def setupDB():
    client = pymongo.MongoClient("mongodb+srv://cmcc:test123@profiletest.qsr6r.mongodb.net/myFirstDatabase?retryWrites=true&w=majority")
    db = client.test
    try:
        client.server_info()
        print("DB Connected\n")
    except Exception as e:
        print(e)
    return db

def setupMemoryConfig(primary="Int", secondary="Ext"):
    with open('./src/server_memory.cc', 'r') as file:
        data = file.readlines()

    # now change the 2nd line, note that you have to add a newline
    if(primary == "Int"):
        data[24] = '                                                 data_int, TENSOR_ARENA_BYTES_1,\n'
    elif(primary == "Ext"):
        data[24] = '                                                 data_ext, TENSOR_ARENA_BYTES_0,\n'
    elif(primary == "None"):
        data[24] = '                                                 nullptr, 0,\n'

    if(secondary == "Int"):
        data[25] = '                                                 data_int, TENSOR_ARENA_BYTES_1,\n'
    elif(secondary == "Ext"):
        data[25] = '                                                 data_ext, TENSOR_ARENA_BYTES_0,\n'
    elif(secondary == "None"):
        data[25] = '                                                 nullptr, 0,\n'

    # and write everything back
    with open('./src/server_memory.cc', 'w') as file:
        file.writelines( data )

    file.close()

def build():
    import os
    os.system("xmake")

def flashModel(flashPath):
    import os
    print('Writing Model to Flash')
    os.system("xflash --boot-partition-size 524288 --target-file src/XCORE-AI-EXPLORER-700.xn --data ./profiling/models/{}out ./bin/app_testing.xe".format(flashPath[:-6]))

def run():
    import subprocess
    process = subprocess.Popen(["xrun", "./bin/app_testing.xe"])
    return process

def loadModel(extMem):
    import os 
    os.system("python3 ../host_python/load_models.py")

def sendModel(model, mem_space):
    import os 
    os.system("python3 ../host_python/send_model.py usb {} ./profiling/models/{}".format(mem_space, model))

def sendGoldfish():
    import sys
    import os
    import time
    import struct
    import ctypes
    from math import sqrt

    import numpy as np
    from matplotlib import pyplot

    import usb.core
    import usb.util


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

    input_length = ie.input_length

    output_length = ie.output_length

    input_shape_channels = 3
    input_shape_spacial =  int(sqrt(input_length/input_shape_channels))
    INPUT_SHAPE = (input_shape_spacial, input_shape_spacial, input_shape_channels)


    raw_img = None

    # Send image to device
    try:
        import cv2
        img = cv2.imread("profiling/goldfish.png")
        img = cv2.resize(img, (INPUT_SHAPE[0], INPUT_SHAPE[1]))
    
        # Channel swapping due to mismatch between open CV and XMOS
        img = img[:, :, ::-1]  # or image = image[:, :, (2, 1, 0)]

        img = (img / NORM_SCALE) - NORM_SHIFT
        img = np.round(quantize(img, INPUT_SCALE, INPUT_ZERO_POINT))

        raw_img = bytes(img)
        
        ie.write_input_tensor(raw_img)
            
    except KeyboardInterrupt:
        pass

    ie.start_inference()

    output_data_int = ie.read_output_tensor()

    max_value = max(output_data_int)
    max_value_index = output_data_int.index(max_value)

    prob = (max_value - OUTPUT_ZERO_POINT) * OUTPUT_SCALE * 100.0

    if DRAW: 

        np_img = np.frombuffer(raw_img, dtype=np.int8).reshape(INPUT_SHAPE)
        np_img = np.round(
            (dequantize(np_img, INPUT_SCALE, INPUT_ZERO_POINT) + NORM_SHIFT) * NORM_SCALE
        ).astype(np.uint8)

        pyplot.imshow(np_img)
        pyplot.show()


    times = np.asarray(ie.read_times())

    return(times)

def modelToOpList(model_path):

  # Update the path to your model
  model_path = model_path
  with open(model_path, "rb") as model_file:
    buffer = model_file.read()

  # Get Model
  model = Model.GetRootAs(buffer)

  opsList = []
  for y in range(0, model.Subgraphs(0).OperatorsLength()):
    opcode = model.OperatorCodes(model.Subgraphs(0).Operators(y).OpcodeIndex())
    if opcode.BuiltinCode() == 32:
      opsList.append(str(opcode.CustomCode()).strip("b'"))
    else:
      opsList.append(opcode.BuiltinCode())

  f = open('../host_python/schema.fbs', "r")
  lines = f.readlines()[108:238]
  for line in lines:
      if '/' in line:
        lines.remove(line)
  for line in lines:
      if '/' in line:
        lines.remove(line)
  for j in range(len(opsList)):
    for line in lines:
        split = line.split(' = ')
        if str(opsList[j]) == split[1].strip(',').strip('\n').strip(','):
            opsList[j] = split[0].strip()
            break

  return opsList

def writeResults(results, modelDict, collection):

    # Get Overall time
    times_sum = sum(results)/100000
    times = results / 100000
    old_times_sum = 1000000000

    # Link Operator List to Times List and add up for each operator
    opList = np.array(modelToOpList('./profiling/models/'+modelDict['filename']))
    layerTimings = [list(times), list(opList)]
    
    opsUnique = np.unique(opList)
    uniqueTimes = np.zeros(len(opsUnique))

    for i in range(len(opsUnique)):
        for j in range(len(opList)):
            if opList[j] == opsUnique[i]:
                uniqueTimes[i] += times[j]

    operatorTimings = [list(opsUnique), list(uniqueTimes)]

    # Write to database
    time = datetime.now().strftime("%d/%m/%Y %H:%M:%S")
    modelDict['time'] = time
    modelDict['file size (bytes)'] = os.path.getsize('./profiling/models/'+modelDict['filename'])
    modelDict['execution time (ms)'] = times_sum
    modelDict['layer timings (ms)'] = layerTimings
    modelDict['operator timings (ms)'] = operatorTimings
    
    if use_db == 'true':
        try:
            collection.insert_one(modelDict)
        except Exception as e: 
            print(e)

    with open("./profiling/results/"+modelDict['filename'][:-7]+'.txt',"w") as out:
        for attr in modelDict:
            print('\n'+attr +': ', file=out)
            pprint(modelDict[attr], stream=out)

def profileModels(dict):
    for model in dict:
        print("\n#################")
        print("Profiling model: {}".format(config[model]['filename']))
        print("#################\n")


        setupMemoryConfig(config[model]['memoryPrimary'], config[model]['memorySecondary'])
        build()

        if config[model]['flash']:
            flashModel(config[model]['filename'])

        process = run()
        time.sleep(10) #Wait for device to initialise

        #Either send model over usb, or load from flash
        if not config[model]['flash']:
            sendModel(config[model]['filename'], config[model]['loadType'])
        elif config[model]['flash']:
            loadModel(config[model]['loadToExt'])

        if use_db =='true':
            writeResults(sendGoldfish(), config[model], db[model])
        else:
            writeResults(sendGoldfish(), config[model], None)

    if os.path.exists("current_model.txt"):
        os.remove("current_model.txt")

# Read Config File
config = configToDict()

# Connect to database
if use_db == 'true':
    db = setupDB()

# Profile models in config, and write results to database
profileModels(config)







