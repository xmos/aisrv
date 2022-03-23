app_person_detection: person detection app
===========================

Env/Dependencies etc
--------------------

The short instructions:

  * clone the aisrv_installers repo::

       git clone git@github0.xmos.com:xmos-int/aisrv_installers.git

  * You will find ``aisrv`` inside it.

The long instructions:

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

  * Strictly speaking you don't need lib_logging, lib_xassert, and lib_i2c
    as they will be loaded automatically on xmake

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
  * cd aisrv/app_person_detection
  * xmake

Running - USB from Mac
----------------------

  * Run xcore program:
    - xrun --xscope bin/app_alpr.xe
  * Run python script to recv image seen by the camera
    - $ python3 ./run_demo.py
