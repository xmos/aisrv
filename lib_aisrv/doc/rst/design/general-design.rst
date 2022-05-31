XCORE-AI server general design
==============================

The XCORE AI server comprises three layers:

  * A physical layer that interfaces the AI server to other bits of
    hardware and software. Three physical layers are supported:

     - USB

     - SPI

     - Local channel end

    The physical layer connects through a channel to the AI Engine. No
    interfaces are used because the physical layer may be unaware of the
    precise command structure and simply pass messages on from the physical
    layer to the AI engine below.

  * The AI engine is a layer that interprets commands that come in over one
    of more channel ends, and executes those commands. Example commands
    include loading a model, setting an input tensor up, executing an
    inference cycle, or reading an output tensor.

    The AI engine invokes the next layer down, the inference engine,
    through an API that has four functions: initialise, load_model,
    invoke, and print_profiler_summary.

  * The bottom layer is the inference engine. This layer encapsulates
    TensorFlow Lite for Micro, and may in future encapsulate other
    interepreters such as TVM or the TAM.

The above three layers are encapsulated inside lib_aisrv, together with a
fourth module that deals with flash. We describe the layers above from the
middle outwards, starting with the AI Engine

|newpage|

AI Engine
---------

The AI Engine takes an array of channel ends for control; in the simplest
case there is just one channel end to control the AI Engine, for example a
channel end connected to a USB end point, SPI end point, or a local end
point. For development and generic deployment a multitude of channel ends
can be useful.

Communication of the channel(s) is as follows:

 * The AI Engine expects a command - an integer with one of the values
   specified below

 * The AI Engine expects an integer - typically the tensor number to which
   the command applies

 * The AI Engine expects an array of data, starting with an integer
   specifying the length

 * The AI Engine will then send a result value, indicating success or
   failure.

 * If the command was a GET command, the AI engine will send an array of
   data, otherwise an end control token is sent (TODO: make the status a normal
   output transaction)

The commands that can be sent are specified in
``host_python/xcore_ai_ie/aisrv_cmd.py``. The GET commands are:

=============================== ============================================
Command                         Meaning
=============================== ============================================
CMD_NONE                        No operation
CMD_GET_STATUS                  Get status of the interpreter
CMD_GET_INPUT_TENSOR            Get one of the input tensors
CMD_GET_OUTPUT_TENSOR           Get one of the output tensors
CMD_GET_SPEC                    Get the specification of the device
CMD_GET_TIMINGS                 Get the timings of the last run
CMD_GET_INPUT_TENSOR_LENGTH     Get the length of one of the input tensors
CMD_GET_OUTPUT_TENSOR_LENGTH    Get the length of one of the output tensors
CMD_GET_ACQUIRE_MODE            Get the acquire mode
CMD_GET_DEBUG_LOG               Get the last few lines of the error log
CMD_GET_ID                      Get an ID of the server.
=============================== ============================================

The SET commands are:

=============================== ============================================
Command                         Meaning
=============================== ============================================
CMD_SET_INPUT_TENSOR            Set one of the input tensors
CMD_START_INFER                 Start an inference cycle
CMD_SET_MODEL_ARENA             Set the model, put it in the ARENA memory
CMD_SET_MODEL_EXT               Set the model, put it in the MODEL memory
CMD_SET_MODEL_ARENA_FLASH       Set the model from flash into the ARENA
CMD_SET_MODEL_EXT_FLASH         Set the model from flash into the MODEL
CMD_START_ACQUIRE_SINGLE        Acquire a single frame
CMD_START_ACQUIRE_STREAM        Continuously acquire frames
CMD_START_ACQUIRE_SET_I2C       Set I2C register in the sensor
=============================== ============================================

And a few miscellaneous commands

=============================== ============================================
Command                         Meaning
=============================== ============================================
CMD_SET_OUTPUT_GPIO_EN          Enable use of GPIO for output tensor
CMD_SET_OUTPUT_GPIO_THRESH      Set threshold on output tensor
CMD_SET_OUTPUT_GPIO_MODE        Set GPIO mode
CMD_GET_OUTPUT_GPIO_EN          Get enable status TODO: delete
CMD_GET_OUTPUT_GPIO_THRESH      Get threshold TODO: delete
CMD_GET_OUTPUT_GPIO_MODE        Get mode TODO: delete
CMD_HELLO                       Used to first connect over SPI.
=============================== ============================================

API
+++

The API of the AI engine comprises a single function

.. doxygenfunction:: aiengine


|newpage|
   
Physcial layer
--------------

USB
+++

The USB layer connects a USB pipe to the channel end that communicates
with the AI Engine. The USB protocol is as follows

  * A packet is sent to the device containing 12 bytes:

    - A command (4 bytes, LSB)

    - The engine number that this command is addressed to. The AI server
      can run a multitude of engines (for example one per tile) and this
      enables one to address each engine individually. Set to 0 if only one
      engine is used.

    - An integer that normally denotes the tensor number to operate on. Set
      to 0 if only one input and output tensor are used.

  * For a SET command, N packets are sent to the device with the last
    packet containing less than 512 bytes. Each of these packets contains
    data to be sent with the command. These packets may for example contain
    a model or the value for an input tensor.

    Note that if there is no value a zero length packet must be sent, and
    that if the data to be sent is a multiple of 512 bytes, then a zero
    packet terminates the packet stream.

    After that, the status word is input. // TODO: at the moment it is an outuint.

  * For a GET command, the status word is input, then N packets are sent to
    the host, with the last packet containing less than 512 bytes.

Error behaviour to be documented.

SPI
+++

To be fixed and documented

Local channel ends
++++++++++++++++++

Code local to the xcore can control the device using a channel end over
which they transfer commands, tensor numbers, and data as above. Three
functions encapsulate the most frequent uses: setting the input from a
sensor, loading a model, and getting the output. More functions can be
added for, for example, setting the input tensor directly.

Note that the local channel end point directly to an engine, so unlike the
SPI and USB physical layers there is no need to specify the engine number;
it is implicit in the channel used. The API comprises the following
functions:

.. doxygenfunction:: aisrv_local_get_output_tensor

.. doxygenfunction:: aisrv_local_acquire_single

.. doxygenfunction:: aisrv_local_start_inference

|newpage|

Inference Engine
----------------

The inference engine is the layer that interfaces the particular mechanism
used for inferencing with the rest of the software.

At the moment we use TensorFlow Lite for Micro for inferencing (also known
as TFLM) and the inference engine API makes TFLM useful to the AI engine.
The API could be implemented for other platforms, such as TVM or TAM.

The API comprises four calls: 

.. doxygenfunction:: inference_engine_load_model
                     
.. doxygenfunction:: inference_engine_unload_model
                     
.. doxygenfunction:: interp_invoke

.. doxygenfunction:: print_profiler_summary

It uses two structures to store the inference engine:

.. doxygenstruct:: inference_engine

.. doxygenstruct:: tflite_micro_objects

|newpage|

Flash
-----

The flash server makes a local flash chip available to one or more inference
engines (or other software, eg, execute in place). To this end, the data
partition of the flash contains the following:

  * For each client the following are stored in integers (LSB first):

      - The offset in the data partition where the model starts, 0 otherwise

      - The offset in the data partition where the parameters start, if
        any. Zero otherwise.

      - The offset in the data partition where the binaries of the
        operators start, if any. Zero otherwise

      - The offset in the data partition where the execute in place
        segment starts, if any. Zero otherwise.

    The model start with four bytes length, then the actual model data. No
    length information is stored with parameters. Operators and XIP are TBD.
    So for two clients, there is a 32 byte header
    [model-start, par-start, op-start, xip-start, model-start, par-start,
    op-start, xip-start].

  * In any order, models, parameters, operators, and execute-in-place
    segments.

Data is currently stored with nibbles swapped (following normal QSPI
order), we need to change this to unswap the nibbles (following XCORE
order). This will need an optimised QuadFlash library that will also use a
more appropriate clocking scheme that will go up to 50 MHz that outputs
directly to a channel end.

Protocol
++++++++

The protocol to obtain data from flash is to send a command, and then in
one transaction obtain the data as follows:

 * FLASH_READ_MODEL:

     #. Output the integer FLASH_READ_MODEL

     #. Input the length of the model

     #. Input the bytes
   
 * FLASH_READ_PARAMETERS:

     #. Output the integer FLASH_READ_PARAMETERS

     #. Output the offset of the desired parameter block

     #. Output the size of the desired parameter block

     #. Input the bytes
   
 * FLASH_READ_OPERATORS

   TBD
   
 * FLASH_READ_XIP

   TBD, probably the same as FLASH_READ_PARAMETERS
   

API
+++

.. doxygenfunction:: flash_server

The FLASH commands are enumerated as follows:

.. doxygenenum:: flash_command

In order to speed up the flash server, the main program is responsible for
allocating a header structure. This contains the meta information about the
flash:

.. doxygenstruct:: flash

