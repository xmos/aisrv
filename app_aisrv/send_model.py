#!/usr/bin/env python
# Copyright (c) 2020, XMOS Ltd, All rights reserved

import sys
from xmos_aisrv import aisrv_usb

aisrv = aisrv_usb()

aisrv.connect()

aisrv.send_model_file(sys.argv[1])



