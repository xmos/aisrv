# Copyright 2020-2021 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
from hardware_test_tools import prepare_firmware, prepare_host, get_firmware_version, reset_target, erase_flash
from time import sleep
from io import StringIO
import pytest
from pathlib import Path
import os
from xcore_ai_ie import xcore_ai_ie_usb, xcore_ai_ie_spi, AISRVError
import cv2
import numpy as np
import struct

APP_NAME = "app_testing"
XMOS_ROOT = Path('/Users/henk/gitAISERV_default')
sw_xvf3610 = XMOS_ROOT / "aisrv"
APP_PATH = sw_xvf3610 / APP_NAME
XN_PATH = APP_PATH / "config"

def initialise(host):
    return xcore_ai_ie_usb()

@pytest.fixture(scope='session')
def session_utils():
    adapter_id = ''
    host = prepare_host()
    firmware = prepare_firmware(host, adapter_id=adapter_id)
    ie = initialise(host)
    ie.connect()

    yield ie, firmware, host, adapter_id
    
    xn_file = XN_PATH / "XVF3610_AI_EXPLORER.xn"

def load_model(ie, model):
    try:
        ie.download_model_file(model, ext_mem = False, engine_num = 0)
    except AISRVError:
        result = "Device reported an error : " +  ie.read_debug_log()
        assert result != ""

def load_float_image(image, w, h):
    img = cv2.imread(image)
    img = cv2.resize(img, (w, h))

    # Channel swapping due to mismatch between open CV and XMOS
    img = img[:, :, ::-1]  # or image = image[:, :, (2, 1, 0)]

    img = np.asarray(img, dtype=np.float32)
    img = img / 256.0
    img = np.ndarray.flatten(img)
    raw_img = struct.pack('%sf' % len(img), *img)
    return raw_img

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
    
def test_load_external(session_utils):
    ie, firmware, host, adapter_id = session_utils
    load_model(ie, 'models/mobilenet_fc_xcore.tflite')

@pytest.mark.parametrize("mod,inp,outp", [
    ('models/mobilenet_fc_xcore.tflite', 'images/goldfish.png', 1),
    ('models/mobilenet_fc_xcore.tflite', 'images/ostrich.png',  9)])
    
def test_mobile_net(session_utils, mod, inp, outp):
    ie, firmware, host, adapter_id = session_utils
    load_model(ie, mod)
    
    raw_img = load_float_image(inp, 128, 128)
    
    ie.write_input_tensor(raw_img)
    ie.start_inference()
    output_data_int = ie.read_output_tensor()
    output_data_int = to_float(output_data_int)
    max_value = max(output_data_int)
    max_value_index = output_data_int.index(max_value)
    time = sum(np.asarray(ie.read_times()) // 100000)
    
    assert max_value > 0.98
    assert max_value_index == outp
    assert time < 1300

