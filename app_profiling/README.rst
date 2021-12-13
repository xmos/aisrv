app_testing: app for testing AISRV
==================================

Env/Dependencies etc
--------------------

Instructions:

  * clone the aisrv repo::

       git clone  git@github.com:xmos/aisrv.git

  * Switch this to the ``experimental/all-default-operators`` branch, now
    get the prerequisites::
      
       git clone  git@github.com:xmos/lib_nn.git
       git clone --recurse-submodules git@github.com:xmos/lib_tflite_micro.git
       git clone git@github.com:xmos/lib_xud.git

After this, set up python:

  * pip install --upgrade pip
  * pyenv install 3.7.7
  * virtualenv -p /Users/<username>/.pyenv/versions/3.7.7/bin/python3.7 venv
  * source venv/bin/activate
  * pip install -r requirements.txt

other deps: USB

  * brew install libusb

Build instructions
------------------

  * ensure XMOS tools are setup
  * cd aisrv/app_alpr
  * xmake

Running - USB from Mac
----------------------

  * Run xcore program:
    - xrun --io --xscope bin/app_alpr.xe
  * Run python script to recv image seen by the camera
    - $ python ./recv_picture.py image.png

When we're all done:

  * Run python script to load model
    - $ python ./send_model.py model...tflite
      
We'll need to hack recv_picture to make sure it sets off an inference cycle



