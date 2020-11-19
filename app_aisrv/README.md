
app_aisrv
=========

Required Dependancies
---------------------

python
~~~~~~
- pyusb
- cv2
- matplotlib

other 
-----

- brew install libusb

(slightly messy) build instructions
-----------------------------------

- ensure XMOS tools are setup
- clone the aisrv repo with submodules (git clone --resursive git@github0.xmos.com:xmos-int/aisrv.git)
- set XMOS_AIOT_SDK_PATH to point to aiot_sdk
- set XMOS_LIB_XUD_PATH to point to lib_xud (should have be cloned into aisrv/submodules)
- mkdir build
- cd build
- cmake ../
- xmake

Running
-------

- Run xcore program: 
    - xrun --io --xscope aisrv_usb.xe
- Run python script to send model and input tensor:
    - $ python ./send_image.py image.jpg 



