XCORE.IE datasheet
==================

Features
--------

  * Programmable in TensorFlow

    * Up to 38 GMACCS/s (byte) or 200 MMAC/s (bit)

  * Optional data preprocessing pipeline

  * QPI and SPI compatible bus interfaces

    * up to 50 MHz clock rate

    * 1-bit or 4-bit wide data transfer

  * 60-pin QFP package


Pin functions
-------------

The pin signals are listed in the table below

===========  ======== ======================== ============
Name         SIGNAL   Function                 Connected?
===========  ======== ======================== ============
X0D00        CS_N     Chip select active low   Always
X0D01        MISO     SPI Master In Slave Out  SPI only
X0D10        CLK      Clock                    Always
X0D11        MOSI     SPI Master Out Slave In  SPI only
X0D04        Q0       QPI Data-pin 0           QPI only
X0D05        Q1       QPI Data-pin 1           QPI only
X0D06        Q2       QPI Data-pin 2           QPI only
X0D07        Q3       QPI Data-pin 3           QPI only
VDD          VDD      Core voltage (0.9V)      Always
VDDIO        VDDIO    IO voltage (1.8V)        Always
VSS          VSS      Ground (Core and IO)     Always
XIN/XOUT     XIN/XOUT Crystal oscillator       At least XIN
===========  ======== ======================== ============

By default the device comes up as a SPI interface. If you want to use it
with the QPI interface, then you should tie the MISO pin to ground. Either
the SPI or the QPI interface should be used.

* For the SPI interface you need to wire up CS_N (X0D00), MISO (X0D01), CLK
  (X0D10) and MOSI (X0D11), and X0D04..7 should not be connected.

* For the QPI interface you need to wire up CS_N (X0D00), CLK
  (X0D10) and Q0..4 (X0D04..7). MOSI should not be connected, and MISO
  should be tied to ground.

VDD, VDDIO, VSS must always be wired up, and either a 24 MHz clock should
be provided on XIN (1.8V), or a 24 MHz crystal should be connected between
XIN and XOUT as per the parts hardware datasheet.
  
Description
-----------

The xcore.ai inference engine is a low cost AI accelerator that is
programmable in using TensorFlow. It is connected to an applications
processor using a standard QPI interface, and programmed through this
interface. The QPI interface comprises six signals: a chip-select, a clock,
and four data lines. Data rates of up to 200 MBits/second are supported.
The xcore.ai inference engine is packaged in a low-cost 60-pin QFN (7x7
mm).

Electrical integration
----------------------

Please see the XU316-1024 datasheets for a full description on how to
integrate the device on your board. There are several package variants
avaible, from a very small QFN package to a large BGA. The former only
supports 1.8V, the latter supports both 1.8 and 3.3V IO. Some devices
support large external memories, others do not.

Device Timings
--------------

When integrating the xcore.ai-inference-engine you should adhere to the
timings shown in the table below. The timings are visualised in
:ref:`blah`.

====== ============================= ===== ===== ====== =============
Symbol Timing                        Min   Max   Unit   Notes
====== ============================= ===== ===== ====== =============
Tclk   Clock cycle                   20          ns
Tcse   CS_N enable time              100         ns
Tcsd   CS_N disable time             100         ns
Tcsi   CS_N idle time                200         ns
Tds    DATA setup time               3           ns
Tdh    DATA hold time                3           ns
Tch    CLK high time                 8           ns
Tcl    CLK low time                  8           ns
Tcq    Clock to data-valid           4     8     ns
====== ============================= ===== ===== ====== =============

.. figure:: timing-diagram.pdf
   :width: 100%
           
   Timing diagram

Functional description
----------------------

Usage model
+++++++++++

The xcore.ai-inference-engine comprises three areas of memory:

  * The model memory holds the coefficients and structure of the neural
    network. It is loaded by taking a model from a standard machine
    learning framework, quantising the model on the host computer, and then
    loading the model into the device

  * The tensor memory holds the input data and output data to the network.
    The tensor memory is typically set before inferencing, then after the
    inference cycle it is read out to reveal the output of the network.
    The tensor memory can alternatively be set by a sensor connected to
    the xcore.ai-inference-engine.
    
  * The server memory holds the code of the server. The server code is
    available as a binary file that can be downloaded onto the
    xcore.ai-inference-engine part. The default server can run most neural
    networks, but smaller and more efficient servers can be compiled on a
    host machine and downloaded instead.

When the memory is loaded, you can command the device to perform an
inference. A typical usage sequence for the device is as follows:

  #. Write the model. This stores the model in the model memory

  #. Write the input tensor. This stores data in the tensor memory

  #. Inference. This takes the data from the tensor memory, runs it through
     the neural network, and stores output in the tensor memory.

  #. Read the output tensor from the tensor memory. Repeat steps 2-4 as
     often as inferences are required

Alternatively, if a sensor is connected to the device, the following
sequence can be executed:

  #. Write the model. This stores the model in the model memory

  #. Acquire data from the sensor. This stores data in the tensor memory.

  #. Inference. This takes the data from the tensor memory, runs it through
     the neural network, and stores output in the tensor memory.

  #. Read the output tensor from the tensor memory. Repeat steps 2-4 as
     often as inferences are required
     
Interfacing to the device
+++++++++++++++++++++++++

The xcore.ai-inference engine is designed to interface directly with the
Serial Peripheral Interface (SPI) or Quad Peripheral Interface (QPI) port
of many microcontrollers. The devicecontains an 8-bit instruction register.
Communication between the device and the host micro controller is through
transactions, where each transaction starts with an 8-bit command, followed
by data to be sent to the device, after which the device can send data to
the micro controller. The table below contains a list of the possible
instructions, showing the format for each operation. All instructions and
data are transferred LSB (least-significant-bit, SPI) or LSN
(least-significant-nibble, QPI) first.

========= ==== ======= ==================================================
Name      Cmd  Count   Meaning
========= ==== ======= ==================================================
RStatus   0x01 0,16,4  Read status word from xcore.ai server
RID       0x03 0,16,4  Read ID from xcore.ai server
RSpec     0x05 0,16,16 Read system spec from xcore.ai server
RTensor   0x07 0,16,N  Read output tensor(s) from xcore.ai server
RTimings  0x09 0,16,N  Read timings of last inference
WModel    0x02 N,0,0   Write model to xcore.ai server
Wserver   0x04 N,0,0   Write server to xcore.ai server
Wtensor   0x06 N,0,0   Write input tensor(s) to xcore.ai server
Inference 0x08 0,0,0   Start an inference cycle
Acquire   0x0A 0,0,0   Acquire sensor data
========= ==== ======= ==================================================

The three numbers in the Count column refer to the number of bytes sent to
the device, the number of dummy *clock cycles*, and then the number of bytes
received from the device. Apart from the single-byte command, the number of
bytes written to the device and read from the device
should always be a multiple of four. A number of bytes of *N* stands for an
application dependent number of bytes.

The sequence for a SPI/QPI transaction is always as follows:

 * CS_N is pulled low by the host micro-controller

 * The command byte is clocked out over the data pin(s); data should be
   clocked out by the micro controller on the rising edge of the clock, and
   they will be sampled by the device on the falling edge.

 * If output data is present (the W* commands), then the output data is
   clocked out LSB/LSN immediately following the command byte.

 * If dummy clock cycles are required (the R* commands), then there shall
   be that many clocks, but no output is driven. In the case of QPI - the
   host microcontroller shall release the Q0..3 wires in this period.

 * If input data is present (the R* commands), then the input data will be
   clocked out on the rising edges of subsequent clocks, LSB/LSN first, one
   byte at a time.

 * CS_N is pulled up by the host micro-controller.

The number of clocks should always be the number expected by the device. In
some cases (Wmodel, Wtensor), the device will expect a variable number of
clocks, and respond accordingly. In other cases (Rtensor, RTimings,
Wtensor), the nuber of words should match the value that is intrinsic in
the model.

The figures below graphically shows writes to the device and reads from the
device.


.. figure:: qpi-protocol.pdf
   :width: 100%
           
   Timing diagram

.. figure:: spi-protocol.pdf
   :width: 100%
           
   Timing diagram



Detailed command description
----------------------------

Read status byte from xcore.ai server
+++++++++++++++++++++++++++++++++++++

This command reads four bytes from the xcore.ai server that contains
32 status bits:

  * bits 31..9: reserved
  * bit 8: last command had an error
  * bits 7..3: reserved
  * bit 2: Data not ready, waiting for acquisition
  * bit 1: Data not ready, waiting for inferencing
  * bit 0: Device not ready, busy with writing data

All other commands shall only be issued if the lowest three bits are 0.
All errors are self clearing, ie, reading this word will clear all error
bits.

Read ID word from xcore.ai server
+++++++++++++++++++++++++++++++++

This command reads four bytes from the xcore.ai server that identify the
chip. This returns 0x00000633

Read system spec from xcore.ai server
+++++++++++++++++++++++++++++++++++++

This returns 16 bytes:

  * byte 0 the type of xcore.ai server hardware
  * byte 1 the number of tiles in the system
  * bytes 2 & 3: kBytes internal memory on each tile (for tensor arena and
    model if not stored elsewhere)
  * bytes 4 & 5: kBytes flash memory on each tile (for model)
  * bytes 6 & 7: kBytes external memory on each tile (for model)
  * bytes 8-11: input tensor size in bytes
  * bytes 12-15: output tensor size in bytes

Read output tensor
++++++++++++++++++

This reads the output tensor from the last inference. The number of bytes
read should match the number of bytes that the model produces. Reads should
always be for a multiple of 4 bytes.

Read timings from last inference
++++++++++++++++++++++++++++++++

This reads the time taken for each layer in the model. Each time is
reported in 4 bytes in microseconds.

Write model to xcore.ai server
++++++++++++++++++++++++++++++

Writing a model to the xcore.ai server happens in chunks; each chunk is 256
bytes long. Chunks should be programmed in order in subsequent commands.
If 256 bytes are programmed in a chunk, then a subsequent programming
command is expected. So a model that is 1024 bytes long will require 5
programming commands: 4 times 256 bytes, plus 1 times 0 bytes. In between
programming commands, the host should read the status register to verify
that the server is ready to accept the next chunk of data. As an example we
write a model with 600 bytes of data::

  0x80 then 256 bytes of data
  repeat 0x01 until the bottom bit is cleared
  0x80 then 256 bytes of data
  repeat 0x01 until the bottom bit is cleared
  0x80 then 88 bytes of data
  repeat 0x01 until the bottom bit is cleared

Writes must always be a multiple of four bytes.

Write server to xcore.ai server
+++++++++++++++++++++++++++++++

Similar to writing a model, but this enables the server to be upgraded.
As an example we write a server comprising 512 bytes of data::

  0x81 then 256 bytes of data
  repeat 0x01 until the bottom bit is cleared
  0x81 then 256 bytes of data
  repeat 0x01 until the bottom bit is cleared
  0x81
  repeat 0x01 until the bottom bit is cleared

Writes must always be a multiple of four bytes.

Write input tensor(s) to the xcore.ai server
++++++++++++++++++++++++++++++++++++++++++++

This command writes the whole input tensor in one operation::

  0x90 then N bytes of data

The number of bytes should match the number of bytes expected by the model.
Data is transferred innermost dimension first, one byte at a time. N must
be a multiple of four bytes.


Start inference
+++++++++++++++

This command has no data associated with it. It starts the inference on the
input tensor that has been written, and when ready, the output tensor can
be read. Hence, a typical inference cycle is::

  0x06 then N bytes of data
  0x08
  repeat 0x01 until bit 1 is cleared
  0x07 then dummy bytes then read M bytes of data

For example, suppose the input data comprises a 320x240 RGB image, and the
output comprises a vector of 10 bytes. Suppose we use a QPI interface at 100
MHz. It would take 460,804 clocks to write
a single image data (4.6 ms), then the inference cycle will
happen, then the it would need 22 cycles (220 ns) to obtain the output.

Acquire sensor data
+++++++++++++++++++

This command has no data associated with it. It gets the device to acquire
a frame of sensor data; whatever that may entail. It has two use cases.
First, the sensor data can be obtained, enabling the host to obtain raw
sensor data. Second, the sensor data can be used as input to the inference
engine, enabling the host to obtain a classification.
The first typical use case is::

  0x0A 
  repeat 0x01 until bit 2 is cleared
  0x07 then dummy bytes then read F bytes of data

Where ``F`` is the size of the frame. The second typical use case is::

  0x0A 
  repeat 0x01 until bit 2 is cleared
  0x08 
  repeat 0x01 until bit 1 is cleared
  0x07 then dummy bytes then read M bytes of data

Where ``M`` is the size of the inference data


Bringing the device out of reset
--------------------------------

There are two variants available of the software: use with a flash chip,
and use without a flash chip

* Witout a flash chip, it is the task of the host controller to boot the
  device with appropriate software, then load a model, and then the device
  can be used for inferencing. This is the cheapest way to use it, but
  increases the boot time of the device (a few milliseconds, depending on
  the size of the model), and it limits the size of the model. All
  parameters and tensor arena must fit in memory simultaneously.
  
* With a flash chip, both the code and a model can be stored in flash. This
  means that the device will boot autonomously using code stored in flash,
  and models can be larger because coefficients can be loaded on demand
  from flash.

If the device is equipped without a flash chip, then the portmap to be used
is:

===========  ======== ======================== ==============
Name         SIGNAL   Function                 Connected?
===========  ======== ======================== ==============
X0D00        CS_N     Chip select active low   Boot, SPI, QPI
X0D01        MISO     SPI Master In Slave Out  SPI only
X0D10        CLK      Clock                    Boot, SPI, QPI
X0D11        MOSI     SPI Master Out Slave In  SPI & Boot
X0D04        Q0       QPI Data-pin 0           QPI only
X0D05        Q1       QPI Data-pin 1           QPI only
X0D06        Q2       QPI Data-pin 2           QPI only
X0D07        Q3       QPI Data-pin 3           QPI only
VDD          VDD      Core voltage (0.9V)      Always
VDDIO        VDDIO    IO voltage (1.8V)        Always
VSS          VSS      Ground (Core and IO)     Always
XIN/XOUT     XIN/XOUT Crystal oscillator       At least XIN
===========  ======== ======================== ==============


If the device is equipped without a flash chip then the portmap to be used
is:

===========  ======== ======================== ============
Name         SIGNAL   Function                 Connected?
===========  ======== ======================== ============
X0D00        CS_N     Chip select active low   Always
X0D11        CLK      Clock                    Always
X0D35        MISO     SPI Master In Slave Out  SPI only
X0D36        MOSI     SPI Master Out Slave In  SPI only
VDD          VDD      Core voltage (0.9V)      Always
VDDIO        VDDIO    IO voltage (1.8V)        Always
VSS          VSS      Ground (Core and IO)     Always
XIN/XOUT     XIN/XOUT Crystal oscillator       At least XIN
===========  ======== ======================== ============



Programming
-----------

