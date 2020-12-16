app_aisrv
=========

Env/Dependancies etc
---------------------

- clone the aisrv repo with submodules (git clone --recursive git@github0.xmos.com:xmos-int/aisrv.git)
- cd aisrv
- pip install --upgrade pip
- pyenv install 3.7.7
- virtualenv -p /Users/<username>/.pyenv/versions/3.7.7/bin/python3.7 venv
- source venv/bin/activate
- pip install -r requirements.txt

other deps: USB

- brew install libusb

(slightly messy) build instructions
-----------------------------------
- ensure XMOS tools are setup
   - This should also clone ai_tools
- cd aisrv/app_aissrv_spi
- source Setenv.sh
   - sets XMOS_AITOOLS_PATH to point to ai_tools
- mkdir build
- cd build
- cmake ../
- xmake

Running - SPI from PSOC
-----------------------

- Run xcore program: 
    - xrun --io --xscope aisrv_spi.xe
- Run master on PSOC
    - To be documented.



Running - USB from Mac
----------------------

- Run xcore program:
    - xrun --io --xscope aisrv_usb.xe
- Run python script to send model and input tensor:
    - $ python ./send_model.py model/model_quant_xcore.tflite
    - $ python ./send_picture.py image.jpg
    - $ python ./send_picture.py image.jpg



