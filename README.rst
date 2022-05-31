AI Server Project
================

About
-----

Project to run inference on xCORE with input data/model supplied via control interface

Note, this project is currently pre-release quality, the following is required to build/use.

- ``lib_xud`` on branch master
- ``lib_nn`` on branch develop
- ``lib_tflite_micro`` on branch main (to be changed)
- ``lib_mipi`` on branch master
- ``lib_i2c`` on branch develop
- ``lib_xassert`` on branch develop
- ``lib_xlogging`` on branch develop
- ``lib_uart`` on branch master (to be changed). Only needed to compile app_alpr.
- ``lib_gpio`` on branch master (to be changed). Only needed to compile app_alpr.

Note, dependencies should be cloned to the same level as the aisrv repo.
``lib_tflite_micro`` shold be cloned with ``--recursive``

When running some models, a small modification need to be made to the gemmlowp submodule
in lib_tflite_micro. In lib_tflite_micro/lib_tflite_micro/submodules/gemmlowp/fixedpoint/fixedpoint.h
Line 370 should be changed to::
  
  if(exponent > 31) return 0;

Adding operators
----------------

Edit app_aisrv/src/inference_engine.cc and add operators to the resolver as
appropriate. Don't forget to extend the resolver vector length, in the
declaration of ``resolver_s``.

Compiling
---------

Execute the following commands::

  cd app_aisrv
  xmake CONFIG=usb
  xmake CONFIG=usb_mipi

Then::

  xrun --io --xscope bin/usb/app_aisrv_usb.xe

And in another window::

  cd host_python
  pip install -e xcore_ai_ie
  python3 send_model.py usb single ../model/model_quant.tflite
  python3 send_picture_float.py usb ostrich.png 
  python3 send_picture_float.py usb goldfish.png 

Profiling
---------
The profiling app will allow you to automate testing a list of models in a specified configuration on an xcore.ai explorer board, and to collect the associated timings. This can be used to compare timings when parts of the codebase are updated.

First setting up a virtual environment is reccomended

  
Adjust ``profiling/config.yaml`` to add the model configuration you want to test.
For each model added you must add the .tflite file to the models directory.
If you want to flash a model, a .out file of the same name must be added to the models directory, along with a .tflite model of the same name produced when making the .out file. (This model then includes flash load operations)

Run the profiling script and setup environment::
  xmake profile

Development
-----------

- Use git flow: https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow
- i.e. PR feature branches to develop branch
