Deploying AI trained models on XCORE.AI devices
===============================================

In this document we show how to deploy trained models on XMOS.AI devices.


Getting started: "Hello World!"
-------------------------------

As a first example we show how to download Mobilenet onto an XCORE.AI
device. This just serves as a first example; you can run all sorts of
machine learning models on XCORE.AI devices. During development you need to
connect your XCORE.AI device to a host (laptop or PC) on which you can
develop models.

The example model is available on the XMOS website on
<http://www.xmos.ai/...> Download this model onto your machine and perform
the following steps:

Setting your host computer up for XCORE.AI server
+++++++++++++++++++++++++++++++++++++++++++++++++

Depending on the OS of your host computer, you will need to execute a few
commands once that make USB devices available to Python programs. We use
command line tools on all platforms, so you will need to use a Terminal
window (Mac/Linux) or run an XXX (windows) 

* On a MAC execute the following two commands::

    brew install libusb
    pip install usb
    pip install xmos-aitools

* If your host is a linux machine execute the following commands::

    sudo echo '' >> /etc/rc....
    pip install usb
    pip install xmos-aitools

* If your host is a windows machine please execute the following commands::

    blah
    pip install usb
    pip install xmos-aitools

Your machine is now ready to connect over USB to the XCORE.AI device. You
will have to perform the steps above only once.

Executing your first model on XCORE.AI server
+++++++++++++++++++++++++++++++++++++++++++++

Now execute the following commands on your host::

  % xformer.py mobilenet.tflite -o mobilenet_xcore.tflite

  % xmos_send_model.py mobilenet_xcore.tflite
  Connected to AISRV via USB
  Model length (bytes): 1643888
  Downloading model to primary memory
  input_size: 49152
  output_size: 40
  
  % xmos_classify_mobilenet.py goldfish.png
  Connected to AISRV via USB
  Inferred input shape: (128, 128, 3)
  Output tensor read as  [0.0, 0.99609375, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], this is an GOLDFISH 99.61%
  milliseconds taken 1251 per layer timings:
  [37  8  9 74 79 96 16 26 51 86 74  8 14 39 44 63  4  7 31 21 55 21 55 21
  55 21 55 21 55  2  3 28 10 53  8  0  1  0  0  0]
  
  % xmos_classify_mobilenet.py ostrich.png
  Connected to AISRV via USB
  Inferred input shape: (128, 128, 3)
  Output tensor read as  [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.99609375], this is an OSTRICH 99.61%
  milliseconds taken 1251 per layer timings:
  [37  8  9 74 79 96 16 26 51 86 74  8 14 39 44 63  4  7 31 21 55 21 55 21
  55 21 55 21 55  2  3 28 10 53  8  0  1  0  0  0]
  
  %

The first command (``xformer.py``) transforms a quantized TensorFlow lite
model into a model optimized for xcore.
The second command (``xmos_send_model.py``) sends the model to the XCORE.AI
device, and initialises the device. The third command
(``xmos_classify_mobilenet.py``) takes a square image, sends it to the
XCORE.AI device, and reads and interprets the output back from the XCORE.AI
device. 

Running your own model on XCORE.AI
----------------------------------

Deploying your own model on an XMOS.AI device involves the following steps:

#. Quantize the model

#. Optimize the model for XCORE

#. Optionally program part of the model into flash

#. Deploying the model onto XCORE.AI

#. Optionally integrate the inference operations with other tasks.

Quantizing the model
++++++++++++++++++++

We assume that you have trained a model.
There are a few requirements on the model:

* At present the model has to be represented as a TensorFlow Lite
  flatbuffer (a ``.tflite`` file). If your model is trained using a
  different framework you will for the time being need to convert it using
  ONNX.

* For efficient execution the model has to be quantised. That is, rather
  than storing coefficients and values as floating point numbers they are
  stored as small integers. Currently the software supports two precisions
  natively: 8-bit signed numbers, and 1-bit signed numbers (binarized
  networks).

Examples of the quantisation process are the tensorflow website on
https://www.tensorflow.org/lite/convert and
https://www.tensorflow.org/lite/convert

Optimizing the model for XCORE
++++++++++++++++++++++++++++++

During this step our tools transform the model into one with the same
functionality but that executes more efficiently. It is up to you to decide
what efficiency criteria to use. For example, you may be looking for a very
cheap solution that uses little memory, or you may be looking for a fast
solution and you are less concerned about cost of the solution.

There are two ways to drive the xformer: from Python or from the
command-line. From python run the following command::

  from xmos_ai_xformer import xformer

  optimised_model = xformer(model, options ...)
  
Alternatively, from the command-line, execute the following::

  xformer.py [options...] model.tflite -o model_xcore.tflite

By default, the xformer will optimise all convolutional and dense layers
in the network and optimize them to XCORE, and parallelise the network to
use all available compute on a single XCORE tile.

Trial the model on XCORE
++++++++++++++++++++++++

During development, you may want to load models and data onto XCORE.AI
using python programs. You can use the programs ``xmos_load_model.py`` and
``xmos_mobilenet_classify.py`` as example programs on how to use a Python
library that communicates with the XCORE.AI chip::

  from xmos_ai_ie import xcore_ai_ie

  ie = xcore_ai_ie_usb()
  ie.connect()

  ie.download_model_file(sys.argv[1])    # TODO: allow model_contents
  ie.write_input_tensor(input_data)
  ie.start_inference()
  output_data = ie.read_output_tensor()
  times = ie.read_times()

More example programs are available (xmos_send_picture.py,
xmos_recv_picture.py), and the library documentation is on-line on XXXXX.

Deploy the model on XCORE
+++++++++++++++++++++++++

In order to deploy the model in a system, you need to perform one of two
tasks.

* Write a set of functions on XCORE.AI that acquire, pre-process, and
  post-process data; and/or

* Connect XCORE.AI to an applications processor in your system over, say, a
  SPI interface, and implement functions on the AP that communicate with
  XCORE.

For the latter, we have a set of example C functions available that enable
you to interact with XCORE.AI. For the former, we have a set of example
programs showing how to obtain data from a variety of sensors.

Optimising memory usage
+++++++++++++++++++++++

There are many ways to map the required storage (model architecture,
scratch-space, and learned parameters) onto physical memories:

* Map all three into external memory.

  This is the default strategy for models that are too large to fit in
  internal memory. This relies on the presence of an external memory, and
  results in relatively slow execution, limited by the speed of the
  external memory.

* Map all three into internal memory.

  This is the default strategy for small models that fit in internal
  memory. This can execute at maximum speed at minimum cost.

* Map the learned parameters onto Flash memory, and store the model and
  scratch space in internal memory.

  This is a cheap and fast solution. The ``xformer`` will, at your
  direction, separate all the learned parameters from the model and store
  them in a separate structure. This structure can then be programmed into
  flash memory and will be loaded on demand. Loading parameters to
  convolutional layers does not typically increase execution time; dense
  layers will slow down significantly.

  Pass the XXXX parameter to ``xformer`` for it to emit two files.

* Custom mappings.

  You are in charge of the mappings. For example, you may have a problem
  with a tensor arena that is too large to fit in internal memory, but the
  model including the learned parameters do fit in internal memory. In that
  case you can decide to store the model in internal SRAM and the tensor
  arena in LPDDR. This will run very efficiently.

  TODO: not needed if we have a load_from_lpddr operator.

* Multi-tile mappings.
  
  Blah

Understanding the possibilities and limitations of XCORE.AI devices
-------------------------------------------------------------------

XCORE.AI devices can run a wide variety of models, with a wide variety of
sizes.

Operators (layers) supported
++++++++++++++++++++++++++++

The XCORE.AI execution engine is built on TensorFlow Lite for Micro, and as
such it supports the long list of operators that are supported by
TensorFlow Lite for Micro. Example operators supported are 2D convolution,
fully connected, depthwise convolution, relu, softmax, add, logistics,
quantization, dequantization, minpool, maxpool, averaging, mean, and another 200
operators.

Having said that, we cannot store all operators simultaneously in the
binary, so you may have to built a bespoke XCORE.AI server in order to make
use of less common operators. The operators explicitly listed above are
supported by default.

Most operators are only supported on 8-bit signed integer values; XCORE.AI
expects neural networks to have been *quantized* from floating point values
to 8-bit signed integers. Floating point to 8-bit quantize- and
dequantize-operators are supported on the device, but it is better for
memory consumption and efficiency to just work in the 8-bit domain.

16-bit integers are natively supported by XCORE.AI, but at present there is
no seamless support. Please contact you local XMOS sales department if you
have requirements for 16-bit vector arithmetic. The architecture also
natively supports 32-bit signed integer and 32-bit complex arithmetic,
these are mostly used for pre-processing signals

Sizes supported
+++++++++++++++

Depending on the model size, the model may be able to execute entirely
inside an XCORE.AI device, or you may need an external memory or an
additional XCORE.AI device. Two or more XCORE.AI devices can be combined to
form a single larger system; as such, you can scale compute and memory to
fit your model as long as this is economical. Alternatively, you can choose
to scale down your model to fit an XCORE.AI device. Below we give a couple
of example configurations with their memory size and compute speeds:

  ========================== ================== ================
  Configuration              Peak memory        Peak MIPS
  ========================== ================== ================
  single XCORE.AI            2 x 512 kB         51.2 GMacc/s
  dual XCORE.AI              4 x 512 kB         102.4 GMacc/s
  single XCORE.AI + LPDDR    64 Mbyte           51.2 GMacc/s
  N XCORE.AI                 2 x N x 512 kB     N x 51.2 GMacc/s
  ========================== ================== ================

There is no trivial mapping from a model to how much memory is needed.
Memory is typically needed for three aspects of inferencing:

* The model architecture needs to be stored. Model architectures are
  typically small, and measure 10s of kByte.

* Scratch space (also known as the Tensor Arena) is needed to hold input
  values, intermediate values, and output values. The size of the scratch
  space is often related to the size of the input data, and in many
  networks the largest size needed is a few times larger than the size of
  the input image. The XMOS tools have built-in methods that optimize the
  size of the scratch-space required.

  If the required scratch space is more than is
  available on the device, then you should either aim to use
  lower-resolution images (if that still achieves the desired performance),
  or add memory to the device.

* The model parameters need to be stored. Model parameters are the values
  that have been learned during training. Assuming that each parameter is
  quantized to a byte, the number of parameters directly translates to the
  number of bytes needed to store model parameters. In the case of
  binarized networks, eight parameters are stored in every byte.

  If the parameters don't fit in memory, then you can choose to store them
  in the boot-flash. Depending on the model architecture, storing
  parameters in flash may slow down model execution. Models with a large
  number of fully connected layers are for example slower when parameters
  need to be read from flash.

For small models, all three above are typically stored in internal memory.
For larger models, the first two are held in internal memory, and the
learned parameters in a cheap external flash memory. For very large models,
external LPDDR memory may be required to hold the scratch space, or two
XCORE.AI chips can be placed side-by-side and the model can be distributed
over them by the XMOS AI tools.

[Economics? relative price of flash / LPDDR?]

Performance
+++++++++++

The performance very much depends on the operators used. The XMOS AI graph
transformer (``xformer``) optimises the graph and replaces operators such
as ``Conv2D`` and ``FullyConnected`` by bespoke operators that have been
optimised for XCORE.AI. As a rule of thumb:

* Conv2D with a large number of inputs and outputs can run at a rate of 75%
  of the peak rate.

* FullyConnected with moderate numbers of inputs and outputs can run at a
  rate of 40% of the peak-rate; when the product of inputs and outputs is
  so large that the learned parameters have to be stored in LPDDR or Flash
  memory, then performance will be limited by the bandwidth of the memory.
  External LPDDR is typically limited to 800 MMacs/s, external flash is
  limited to 25-50 MMacs/s.

* All other operators typically only require a fraction of the time
  required by the operators above.

The time taken by each layer is reported and can be used to understand
performance. If you have layers that take an extraordinary amount of time,
please contact your local XMOS sales representative.

Other tasks
+++++++++++

XCORE.AI is a general purpose processor. It can preprocess sensor data
(imaging, audio, radar, ...), deal with a wide variety of IO protocols
(SPI, USB, MIPI, I2S, PDM, S/PDIF, ...), all whilst inferencing data.

The default set-up that you get to run your models on does not use any of
those features - it just performs AI inferencing. But you can download the
source code for the system and extend it with all pre-processing operations
required.

You can also run multiple networks on the device; either in sequence on one
tile or in parallel on multiple tiles. For example, a total solution may be
a system that uses a MIPI camera to obtain image data, a first network to
identify where a license plate is in the image, a second network to decode
the license plate and to output the license plate over some interface.

Using flash memory to store models
----------------------------------

You may choose to trade-off (some) execution speed for fitting larger
models in the chip. As stated earlier, a TensorFlow trained model really
comprises two parts: a model architecture and learned parameters. The
learned parameters can be an order of magnitude larger than the model
architecture.

The XMOS AI tools can take advantage of this by storing the model
architecture in internal memory, and storing the learned parameters in a
cheap external flash memory (the boot flash). In order to do this we need
to perform three steps

* The xformer needs to be executed with a flag that splits the learned
  parameters into a separate file

* A tool needs to be ran that creates a flash image

* The flash image needs to be stored on the hardware

These three steps are all separate because each of these steps has a series
of options. In particular, the second step can combined *multiple networks*
onto a single flash image, and depending on whether you are developing or
deploying, there are different ways to execute the third step.

Instructing XFORMER to split off the learned parameters
+++++++++++++++++++++++++++++++++++++++++++++++++++++++

The first step is to get the xformer to extract the learned parameters from
the model and store them in a params file. This step involves the
following::

  xformer.py model.tflite -o model_xcore.tflite --xcore-flash-image-file=detection_int8_xcore.params --xcore-load-externally-if-larger=8
  xformer.py -o model_xcore.tflite -params model_xcore.params model.tflite

The ``-o model_xcore.tflite`` option defines the output file for the model
architecture, the ``-params model_xcore.params`` option defines the output
file for the learned parameters. Looking at those files, you may see that
one is significantly larger than the other::

  ls -l model_xcore.tflite model_xcore.params

    57048 model_xcore.tflite
   276324 model_xcore.params
   303372 total

By default it makes every block of learned parameters large than 100 bytes
into a flash object. You can modify that by adding a
``--xcore-load-externally-if-larger=700`` option, where ``700`` is the
threshold on the size of the object in bytes::

  xformer.py model.tflite -o model_xcore.tflite --xcore-flash-image-file=detection_int8_xcore.params --xcore-load-externally-if-larger=700

You will notice that there is an optimal value for this number (around
100), making it larger will cause too few objects to be stored in flash,
making it larger will cause too much overhead in the model architecture.

Building a flash image
++++++++++++++++++++++

A flash image is a sequence of bytes that will be stored in the flash
memory. The flash image has a structure, akin to a small file system but
optimised for fast execution. In order to build the flash image you need to
execute the following command::

  build_flash_file.py --output flash.out model_xcore.tflite  model_xcore.params

This command has two parts to it:

* The ``--output flash.out`` is the file name where the flash-image should
  be stored.

* The ``model_xcore.tflite model_xcore.params`` is a pair of files (a model
  and parameters) that you wish to store in flash.
  
This particular example creates a flash image for just a single model, but
multiple models can be stored in flash, in which case you simply pass it a
second pair of files. You can replace any of the files with a ``-`` if
there is no parameter or model file to be stored.

Programming the flash image
+++++++++++++++++++++++++++

In order to program a flash image you need to use an XTAG and the XMOS
tools (TODO: support through xcore_ai_ie)::
  
  xflash --boot-partition-size 524288 --target-file src/XCORE-AI-EXPLORER-700.xn --data flash.out bin/app_alpr.xe

