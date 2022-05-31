#!/usr/bin/env python

# Copyright (c) 2020, XMOS Ltd, All rights reserved
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

from xcore_lvt import xcore_lvt_usb

ie = xcore_lvt_usb()
ie.connect()

ie.write_tensor([1,2,3,4,5,6,7,8,9,10])
x = ie.read_array()
print(x)
