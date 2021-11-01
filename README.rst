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
  python3 send_model.py usb ext ../model/model_quant.tflite
  python3 send_picture_float.py usb ostrich.png 
  python3 send_picture_float.py usb goldfish.png 

Development
-----------

- Use git flow: https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow
- i.e. PR feature branches to develop branch
