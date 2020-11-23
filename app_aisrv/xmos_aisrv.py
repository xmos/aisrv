# Copyright (c) 2020, XMOS Ltd, All rights reserved
from abc import ABC, abstractmethod

import sys

import usb.core
import usb.util

# Commands - TODO properly share with app code
CMD_LENGTH_BYTES = 1

CMD_NONE = 0
CMD_GET_OUTPUT_LENGTH = 1
CMD_SET_INPUT_TENSOR = 2
CMD_START_INFER = 3
CMD_GET_OUTPUT_TENSOR = 4
CMD_SET_MODEL = 5
###


class airsv(ABC):
    
    def __init__(self):
        self._output_length = None
        super().__init__()
   
    @property
    def output_length(self):
        return self._output_length

    @abstractmethod
    def connect(self):
        pass

    @abstractmethod
    def send_model(self, model):
        pass

    @abstractmethod
    def set_input_tensor(self):
        pass
    
    @abstractmethod
    def start_inference(self):
        pass
    
    @abstractmethod
    def get_output_tensor(self):
        pass

    @abstractmethod
    def request_output_length(self):
        pass

    def send_model_file(self, model_file):
        with open(model_file, "rb") as input_fd:
            model_data = input_fd.read()
            self.send_model(bytearray(model_data))

    def bytes_to_int(self, data_bytes):

        output_data_int = []

        # TODO better way of doing this?
        for i in data_bytes:
            x =  int.from_bytes([i], byteorder = "little", signed=True)
            output_data_int.append(x)

        return output_data_int

    

class aisrv_usb(airsv):

    def __init__(self):
        self.out_ep = None
        self.in_ep = None
        self.dev = None
        super().__init__()

    def connect(self):

        self.dev = None
        while self.dev is None:

            # TODO - more checks that we have the right device..
            self.dev = usb.core.find(idVendor=0x20b1) #, idProduct=0xa15e)

            # set the active configuration. With no arguments, the first
            # configuration will be the active one
            self.dev.set_configuration()

            # get an endpoint instance
            cfg = self.dev.get_active_configuration()

            #print("found device: \n" + str(cfg))
            intf = cfg[(0,0)]

            self.out_ep = usb.util.find_descriptor(
                intf,
                # match the first OUT endpoint
                custom_match = \
                lambda e: \
                    usb.util.endpoint_direction(e.bEndpointAddress) == \
                    usb.util.ENDPOINT_OUT)

            self.in_ep = usb.util.find_descriptor(
                intf,
                # match the first IN endpoint
                custom_match = \
                lambda e: \
                    usb.util.endpoint_direction(e.bEndpointAddress) == \
                    usb.util.ENDPOINT_IN)

            assert self.out_ep is not None
            assert self.in_ep is not None

            print("Connected")

    
    def send_model(self, model_bytes):

        print("WRITING MODEL VIA USB..\n")
        
        # Send model to device 
        self.out_ep.write(bytes([CMD_SET_MODEL]))

        # Send model size
        len_bytes = int.to_bytes(len(model_bytes), byteorder = "little", signed=True, length=4)

        print("Model length (bytes): " + str(len(model_bytes)))
        self.out_ep.write(len_bytes, 1000)

        self.out_ep.write(model_bytes, 1000)
        print("FINISHED WRITING MODEL")

        self._output_length = self.request_output_length() 

    def request_output_length(self):

        # Get output size from device
        self.out_ep.write(bytes([CMD_GET_OUTPUT_LENGTH]), 50000)
    
        try:
            return int.from_bytes(self.dev.read(self.in_ep, 4, 10000), byteorder = "little", signed=True)
        except usb.core.USBError as e:
            if e.backend_error_code == usb.backend.libusb1.LIBUSB_ERROR_PIPE:
                print("Device error, IN pipe halted (no model uploaded?)")
                sys.exit(1)


    def set_input_tensor(self, raw_img):

        self.out_ep.write(bytes([CMD_SET_INPUT_TENSOR]))

        MAX_PACKET_SIZE = 512 # TODO, required?

        sentcount = 0
        for i in range(0, len(raw_img), MAX_PACKET_SIZE):
            self.out_ep.write(raw_img[i : i + MAX_PACKET_SIZE])
            sentcount = sentcount + MAX_PACKET_SIZE
            size_str = "sent: " + str(sentcount)
            sys.stdout.write('%s\r' % size_str)
            sys.stdout.flush()


        sys.stdout.write('%s.. Done\n'  % size_str)


    def start_inference(self):

        self.out_ep.write(bytes([CMD_START_INFER]), 1000)


    def get_output_tensor(self, timeout = 50000):

        if self._output_length == None:
            self._output_length = self.request_output_length()
            
        # Retrieve result from device
        self.out_ep.write(bytes([CMD_GET_OUTPUT_TENSOR]), timeout)
        output_data = self.dev.read(self.in_ep, self.output_length, 10000)
        return self.bytes_to_int(output_data)
