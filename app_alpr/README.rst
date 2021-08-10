app_alpr: license plate app
===========================

Env/Dependencies etc
--------------------

  * clone the aisrv repo::

       git clone  git@github.com:xmos/aisrv.git

  * Switch this to the ``experimental/all-default-operators`` branch, now
    get the prerequisites::
      
       git clone  git@github.com:xmos/lib_i2c.git
       git clone  git@github.com:xmos/lib_logging.git
       git clone  git@github.com:xmos/lib_mipi.git
       git clone  git@github.com:xmos/lib_nn.git
       git clone --recurse-submodules git@github.com:xmos/lib_tflite_micro.git
       git clone git@github.com:xmos/lib_xassert.git
       git clone git@github.com:xmos/lib_xud.git

       (cd lib_nn && git checkout 384396b6331d4df2768b2f1617afb9eb34b518c7)

  * Strictly speaking you don't need lib_logging, lib_xassert, and lib_i2c
    as they will be loaded automatically on xmake
    
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



