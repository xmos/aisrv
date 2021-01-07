# Copyright (c) 2020, XMOS Ltd, All rights reserved
from abc import ABC, abstractmethod

import sys
import struct
import array

from xcore_ai_ie import aisrv_cmd

XCORE_IE_MAX_BLOCK_SIZE = 512 

class xcore_ai_ie(ABC):
    
    def __init__(self):
        self._output_length = None
        self._input_length = None
        self._model_length = None
        self._max_block_size = XCORE_IE_MAX_BLOCK_SIZE # TODO read from (usb) device?
        self._spec_length = 20 # TODO fix magic number
        super().__init__()
   
    @abstractmethod
    def connect(self):
        pass

    @abstractmethod
    def download_model(self, model):
        pass

    @abstractmethod
    def upload_model(self, model):
        pass

    @property
    def input_length(self):

        if self._input_length == None:
            self._input_length = self._read_input_length()

        return self._input_length

    @property
    def output_length(self):
        
        if self._output_length == None:
            self._output_length = self._read_output_length()
        
        return self._output_length

    @abstractmethod
    def write_input_tensor(self, input_tensor):
        pass

    @abstractmethod
    def read_output_tensor(self):
        pass

    # Internal method to read input tensor length
    @abstractmethod
    def _read_input_length(self):
        pass
    
    # Internal method to read output tensor length
    @abstractmethod
    def _read_output_length(self):
        pass

    @abstractmethod
    def start_inference(self):
        pass

    @abstractmethod
    def read_times(self):
        pass

    def download_model_file(self, model_file):
        with open(model_file, "rb") as input_fd:
            model_data = input_fd.read()
            self.download_model(bytearray(model_data))

    def bytes_to_ints(self, data_bytes, bpi=1):

        output_data_int = []

        # TODO better way of doing this?
        for i in range(0, len(data_bytes), bpi):
            x = data_bytes[i:i+bpi]
            y =  int.from_bytes(x, byteorder = "little", signed=True)
            output_data_int.append(y)

        return output_data_int
    
class xcore_ai_ie_spi(xcore_ai_ie):

    def __init__(self, bus=0, device=0, speed=7800000):
        self._dev = None
        self._bus = bus
        self._device = device
        self._speed = speed
        self._dummy_bytes = [0,0,0] # cmd + 2 dummy
        self._dummy_byte_count = len(self._dummy_bytes)
        super().__init__()

    def _construct_packet(self, cmd, length):

        def round_to_word(x):
            return 4 * round(x/4)

        return [cmd] + self._dummy_bytes + (round_to_word(length) * [0])

    def connect(self):
        import spidev
        self._dev = spidev.SpiDev()
        self._dev.open(self._bus, self._device)
        self._dev.max_speed_hz = self._speed

    def _read_status(self):

        to_send = [aisrv_cmd.CMD_READ_STATUS] + self._dummy_bytes + (4 * [0])
        r =  self._dev.xfer(to_send)
        return r

    def _wait_for_device(self):
        
        while True:
            status = self._read_status()
            if (status[self._dummy_byte_count] & 0xf) == 0:
                break;

    def _download_data(self, cmd, data_bytes):
        
        data_len = len(data_bytes)
        
        data_index = 0

        data_ints = self.bytes_to_ints(data_bytes)
        
        while data_len >= self._max_block_size:
            
            self._wait_for_device()

            to_send = [cmd]
            to_send.extend(data_ints[data_index:data_index+self._max_block_size])

            data_len = data_len - self._max_block_size
            data_index = data_index  + self._max_block_size

            self._dev.xfer(to_send)
        
        # Note, send a 0 length if size % XCORE_IE_MAX_BLOCK_SIZE == 0
        self._wait_for_device()
        to_send = [cmd]
        to_send.extend(data_ints[data_index:data_index+data_len])
        self._dev.xfer(to_send)

    def _upload_data(self, cmd, length):

        self._wait_for_device()

        to_send = self._construct_packet(cmd, length)
    
        r =  self._dev.xfer(to_send)
        r = [x-256 if x > 127 else x for x in r]

        return r[self._dummy_byte_count:]

    def download_model(self, model_bytes):
        
        # Download model to device
        self._download_data(aisrv_cmd.CMD_SET_MODEL, model_bytes)

        # Update lengths
        self._input_size, self._output_size = self._read_spec()
        
        print("input_size: " + str(self._input_size))
        print("output_size: " + str(self._output_size))

    def _read_spec(self):

        self._wait_for_device()

        to_send = self._construct_packet(aisrv_cmd.CMD_READ_SPEC, self._spec_length)
        
        r = self._dev.xfer2(to_send)
        
        r = bytearray(r[self._dummy_byte_count:])
        
        input_size = int.from_bytes(r[8:12], byteorder = 'little')
        output_size = int.from_bytes(r[12:16], byteorder = 'little')

        # TODO: add sensor tensor size
        return input_size, output_size

    def _read_output_length(self):
        # TODO this is quite inefficient since we we read the whole spec
        input_length, output_length = self._read_spec()
        return output_length

    def _read_input_length(self):
        # TODO this is quite inefficient since we we read the whole spec
        input_length, output_length = self._read_spec()
        return input_length

    def write_input_tensor(self, raw_img):
        
        self._download_data(aisrv_cmd.CMD_SET_INPUT_TENSOR, raw_img)
    
    def start_inference(self):

        to_send = self._construct_packet(aisrv_cmd.CMD_START_INFER, 0)
        r =  self._dev.xfer(to_send)
    
    def read_output_tensor(self):

        output_tensor = self._upload_data(aisrv_cmd.CMD_GET_OUTPUT_TENSOR, self.output_length)
        output_tensor = output_tensor[:self.output_length+1]
        return output_tensor

    def upload_model(self):
        # TODO
        pass

    def read_times(seld):
        # TODO
        pass

class xcore_ai_ie_usb(xcore_ai_ie):

    def __init__(self, timeout = 50000):
        self.__out_ep = None
        self.__in_ep = None
        self._dev = None
        self._timeout = timeout
        super().__init__()

    def _download_data(self, cmd, data_bytes):

        # TODO rm this extra CMD packet
        self._out_ep.write(bytes([cmd]))
       
        #data_bytes = bytes([cmd]) + data_bytes

        self._out_ep.write(data_bytes, 1000)

        if (len(data_bytes) % self._max_block_size) == 0:
            self._out_ep.write(bytearray([]), 1000)
   
    def _upload_data(self, cmd):
        
        import usb
        read_data = []

        try:  
            self._out_ep.write(bytes([cmd]), self._timeout)
            buff = usb.util.create_buffer(self._max_block_size)
           
            while True:

                read_len = self._dev.read(self._in_ep, buff, 10000)

                read_data.extend(buff[:read_len])

                if read_len != self._max_block_size:
                    break;

            return read_data
        
        except usb.core.USBError as e:
            if e.backend_error_code == usb.backend.libusb1.LIBUSB_ERROR_PIPE:
                print("Device error, IN pipe halted (issue with model?)")
                sys.exit(1)

    def _read_int_from_device(self, cmd):
            
        read_data = self._upload_data(cmd)
        assert len(read_data) == 4    
        
        return int.from_bytes(read_data, byteorder = "little", signed=True)

    def connect(self):

        import usb
        self._dev = None
        while self._dev is None:

            # TODO - more checks that we have the right device..
            self._dev = usb.core.find(idVendor=0x20b1) #, idProduct=0xa15e)

            # set the active configuration. With no arguments, the first
            # configuration will be the active one
            self._dev.set_configuration()

            # get an endpoint instance
            cfg = self._dev.get_active_configuration()

            #print("found device: \n" + str(cfg))
            intf = cfg[(0,0)]

            self._out_ep = usb.util.find_descriptor(
                intf,
                # match the first OUT endpoint
                custom_match = \
                lambda e: \
                    usb.util.endpoint_direction(e.bEndpointAddress) == \
                    usb.util.ENDPOINT_OUT)

            self._in_ep = usb.util.find_descriptor(
                intf,
                # match the first IN endpoint
                custom_match = \
                lambda e: \
                    usb.util.endpoint_direction(e.bEndpointAddress) == \
                    usb.util.ENDPOINT_IN)

            assert self._out_ep is not None
            assert self._in_ep is not None

            print("Connected")

    
    def download_model(self, model_bytes):

        assert type(model_bytes) == bytearray
        
        print("Model length (bytes): " + str(len(model_bytes)))
        
        # Send model to device 
        self._download_data(aisrv_cmd.CMD_SET_MODEL, model_bytes) 

        # Update input/output tensor lengths
        self._output_length = self._read_output_length() 
        print("output_length: " + str(self._output_length))
        self._input_length = self._read_input_length() 
        print("input_length: " + str(self._input_length))
        self._model_length = len(model_bytes)
        print("model_length: " + str(self._model_length))

        self._read_spec()

    # TODO decide if want to keep read spec or not
    def _read_spec(self):
        
        spec = self._upload_data(aisrv_cmd.CMD_GET_SPEC)
      
        assert len(spec) == self._spec_length

        # TODO ideally remove magic indexing numbers
        input_length = int.from_bytes(spec[8:12], byteorder = 'little')
        output_length = int.from_bytes(spec[12:16], byteorder = 'little')
        timings_length = int.from_bytes(spec[16:20], byteorder = 'little')
        
        assert(input_length == self._input_length)
        assert(output_length == self._output_length)

    def _read_output_length(self):

        # Get output tensor length from device
        return self._read_int_from_device(aisrv_cmd.CMD_GET_OUTPUT_TENSOR_LENGTH)

    def _read_input_length(self):
    
        # Get input tensor length from device
        return self._read_int_from_device(aisrv_cmd.CMD_GET_INPUT_TENSOR_LENGTH)

    def write_input_tensor(self, raw_img):
        
        self._download_data(aisrv_cmd.CMD_SET_INPUT_TENSOR, raw_img)

    def start_inference(self):

        # Send cmd
        self._out_ep.write(bytes([aisrv_cmd.CMD_START_INFER]), 1000)

        # Send out a 0 length packet 
        self._out_ep.write(bytes([]), 1000)

    def read_output_tensor(self, timeout = 50000):

        if self._output_length == None:
            self._output_length = self._read_output_length()
            
        # Retrieve result from device
        data_read = self._upload_data(aisrv_cmd.CMD_GET_OUTPUT_TENSOR)

        return self.bytes_to_ints(data_read)

    def upload_model(self):

        read_data = self._upload_data(aisrv_cmd.CMD_GET_MODEL)

        assert len(read_data) == self._model_length

        return read_data

    def read_times(self):
       
        times_bytes  = self._upload_data(aisrv_cmd.CMD_GET_TIMINGS)
        times_ints = self.bytes_to_ints(times_bytes, bpi=4)
        return times_ints
