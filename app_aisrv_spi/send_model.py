#!/usr/bin/env python
# Copyright (c) 2020, XMOS Ltd, All rights reserved

import sys
from xcore_ai_ie import xcore_ai_ie_spi

ie = xcore_ai_ie_spi()

ie.connect()

ie.download_model_file(sys.argv[1])





