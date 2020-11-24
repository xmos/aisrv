# Copyright (c) 2020, XMOS Ltd, All rights reserved
from abc import ABC, abstractmethod

import sys

import usb.core
import usb.util

# Commands - TODO properly share with app code
CMD_LENGTH_BYTES = 1

CMD_NONE = 0
CMD_GET_INPUT_LENGTH = 1
CMD_GET_OUTPUT_LENGTH = 2
CMD_SET_INPUT_TENSOR = 3
CMD_START_INFER = 4
CMD_GET_OUTPUT_TENSOR = 5
CMD_SET_MODEL = 6
CMD_GET_MODEL = 7
###


class xcore_ai_ie(ABC):
    
    def __init__(self):
        self._output_length = None
        self._input_length = None
        self._model_length = None
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

    def download_model_file(self, model_file):
        with open(model_file, "rb") as input_fd:
            model_data = input_fd.read()
            self.download_model(bytearray(model_data))

    def bytes_to_int(self, data_bytes):

        output_data_int = []

        # TODO better way of doing this?
        for i in data_bytes:
            x =  int.from_bytes([i], byteorder = "little", signed=True)
            output_data_int.append(x)

        return output_data_int
    

class xcore_ai_ie_usb(xcore_ai_ie):

    def __init__(self, timeout = 50000):
        self.__out_ep = None
        self.__in_ep = None
        self._dev = None
        self._timeout = timeout
        super().__init__()

    def _read_int_from_device(self):
        return int.from_bytes(self._dev.read(self._in_ep, 4, 10000), byteorder = "little", signed=True)

    def _write_int_to_device(self, i):
        self._out_ep.write(bytes([i]))

    def connect(self):

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

        print("WRITING MODEL VIA USB..\n")

        #TODO assert type(model_bytes) == bytes
        
        # Send model to device 
        self._out_ep.write(bytes([CMD_SET_MODEL]))

        # Send model size
        len_bytes = int.to_bytes(len(model_bytes), byteorder = "little", signed=True, length=4)

        print("Model length (bytes): " + str(len(model_bytes)))
        self._out_ep.write(len_bytes, 1000)

        self._out_ep.write(model_bytes, 1000)
        print("FINISHED WRITING MODEL")

        # Update input/output tensor lengths
        self._output_length = self._read_output_length() 
        self._input_length = self._read_input_length() 
        self._model_length = len(model_bytes)

    def _read_output_length(self):

        # Get output tensor length from device
        self._out_ep.write(bytes([CMD_GET_OUTPUT_LENGTH]), 50000)
    
        try:
            return int.from_bytes(self._dev.read(self._in_ep, 4, 10000), byteorder = "little", signed=True)
        except usb.core.USBError as e:
            if e.backend_error_code == usb.backend.libusb1.LIBUSB_ERROR_PIPE:
                print("Device error, IN pipe halted (issue with model?)")
                sys.exit(1)

    def _read_input_length(self):
    
        # Get input tensor length from device
        self._out_ep.write(bytes([CMD_GET_INPUT_LENGTH]), self._timeout)
    
        try:
            return int.from_bytes(self._dev.read(self._in_ep, 4, 10000), byteorder = "little", signed=True)
        except usb.core.USBError as e:
            if e.backend_error_code == usb.backend.libusb1.LIBUSB_ERROR_PIPE:
                print("Device error, IN pipe halted (issue with model?)")
                sys.exit(1)

    def write_input_tensor(self, raw_img):

        self._out_ep.write(bytes([CMD_SET_INPUT_TENSOR]))

        MAX_PACKET_SIZE = 512 # TODO, required?

        sentcount = 0
        for i in range(0, len(raw_img), MAX_PACKET_SIZE):
            self._out_ep.write(raw_img[i : i + MAX_PACKET_SIZE])
            sentcount = sentcount + MAX_PACKET_SIZE
            size_str = "sent: " + str(sentcount)
            sys.stdout.write('%s\r' % size_str)
            sys.stdout.flush()
        sys.stdout.write('%s.. Done\n'  % size_str)

    def start_inference(self):

        self._out_ep.write(bytes([CMD_START_INFER]), 1000)

    def read_output_tensor(self, timeout = 50000):

        if self._output_length == None:
            self._output_length = self._read_output_length()
            
        # Retrieve result from device
        self._out_ep.write(bytes([CMD_GET_OUTPUT_TENSOR]), timeout)
        output_data = self._dev.read(self._in_ep, self.output_length, 10000)
        return self.bytes_to_int(output_data)

    def upload_model(self):

        print("READING MODEL VIA USB..\n")
        
        self._write_int_to_device(CMD_GET_MODEL)

        length = self._read_int_from_device()

        assert length == self._model_length

        try:
            return self._dev.read(self._in_ep, self._model_length, self._timeout)
        except usb.core.USBError as e:
            if e.backend_error_code == usb.backend.libusb1.LIBUSB_ERROR_PIPE:
                print("Device error, IN pipe halted (issue with model?)")
                sys.exit(1)


