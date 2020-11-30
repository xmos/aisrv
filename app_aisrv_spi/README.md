
app_aisrv
=========

Required Dependancies
---------------------

python:
- pyusb
- cv2
- matplotlib

other: 

- brew install libusb

(slightly messy) build instructions
-----------------------------------

- ensure XMOS tools are setup
- clone the aisrv repo with submodules (git clone --recursive git@github0.xmos.com:xmos-int/aisrv.git)
   - This should also clone lib_xud and aiot_sdk (and its submodules, including ai_tools)
- cd aisrv
- source Setenv.sh
   - sets XMOS_AITOOLS_PATH to point to ai_tools
   - sets XMOS_LIB_XUD_PATH to point to lib_xud (fix in CMakelists.txt)
- cd app_aisrv
- mkdir build
- cd build
- cmake ../
- xmake

Running
-------

- Run xcore program: 
    - xrun --io --xscope aisrv_usb.xe
- Run python script to send model and input tensor:
    - $ python ./send_model.py model/model_quant_xcore.tflite
    - $ python ./send_picture.py image.jpg 
    - $ python ./send_picture.py image.jpg 



