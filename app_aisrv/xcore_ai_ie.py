# Copyright (c) 2020, XMOS Ltd, All rights reserved
from abc import ABC, abstractmethod

import sys

import usb.core
import usb.util
import array
import spidev

# Commands - TODO properly share with app code
CMD_LENGTH_BYTES = 1

CMD_NONE = 0
CMD_GET_INPUT_LENGTH = 1
CMD_GET_OUTPUT_LENGTH = 2
CMD_SET_INPUT_TENSOR = 0x83
CMD_START_INFER = 0x84
CMD_GET_OUTPUT_TENSOR = 5

# TODO Unify
CMD_SET_MODEL = 0x86 
CMD_SET_MODEL_SPI = 0x2

CMD_GET_MODEL = 0x06

CMD_READ_STATUS = 0x01
CMD_READ_SPEC = 0x07
###

#TODO rm me and read from device
MAX_PACKET_SIZE = 512 # USB
XCORE_IE_MAX_BLOCK_SIZE = 256 # SPI

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
    
class xcore_ai_ie_spi(xcore_ai_ie):

    def __init__(self, bus=0, device=0, speed=7800000):
        self._dev = None
        self._bus = bus
        self._device = device
        self._speed = speed
        self._dummy_bytes = [0,0,0] # cmd + 2 dummy
        self._dummy_byte_count = 3
        super().__init__()

    def _construct_packet(self, cmd, length):

        def round_to_word(x):
            return 4 * round(x/4)

        return [cmd] + self._dummy_bytes + (round_to_word(length) * [0])

    def connect(self):
        self._dev = spidev.SpiDev()
        self._dev.open(self._bus, self._device)
        self._dev.max_speed_hz = self._speed

    def _read_status(self):

        to_send = [CMD_READ_STATUS] + self._dummy_bytes + (4 * [0])
        r =  self._dev.xfer(to_send)
        return r

    def _wait_for_device(self):
        
        # TODO fix magic numbers
        while True:
            status = self._read_status()
            if (status[self._dummy_byte_count] & 0xf) == 0:
                break;

    def _download_data(self, cmd, data_bytes):
        
        data_len = len(data_bytes)
        
        data_index = 0

        data_ints = self.bytes_to_int(data_bytes)
        
        while data_len > XCORE_IE_MAX_BLOCK_SIZE:
            
            print(str(data_len))
            
            self._wait_for_device()

            to_send = [cmd]
            to_send.extend(data_ints[data_index:data_index+XCORE_IE_MAX_BLOCK_SIZE])

            data_len = data_len - XCORE_IE_MAX_BLOCK_SIZE
            data_index = data_index  + XCORE_IE_MAX_BLOCK_SIZE

            self._dev.xfer(to_send)

        if data_len > 0:
            self._wait_for_device()
            to_send = [cmd]
            to_send.extend(data_ints[data_index:data_index+data_len])
            self._dev.xfer(to_send)

    def _upload_data(self, cmd, length):

        self._wait_for_device()

        to_send = self._construct_packet(cmd, length)
    
        r =  self._dev.xfer(to_send)

        for i in range(len(r)): 
            if r[i] > 127:
                r[i] = r[i] - 256

        return r[self._dummy_byte_count:]

    def download_model(self, model_bytes):
        
        # Download model to device
        self._download_data(CMD_SET_MODEL_SPI, model_bytes)

        # Update lengths
        self._input_size, self._output_size = self._read_spec()
        
        print("input_size: " + str(self._input_size))
        print("output_size: " + str(self._output_size))

    def _read_spec(self):

        self._wait_for_device()
        # TODO fix magic number
        to_send = [CMD_READ_SPEC] + self._dummy_bytes + ([0] * 20)

        r = self._dev.xfer2(to_send)
        r = r[self._dummy_byte_count:]
        # TODO tidy this
        input_size = r[8] + (r[9]<<8) + (r[10] << 16) + (r[11] << 24)
        output_size = r[12] + (r[13]<<8) + (r[14] << 16) + (r[15] << 24)
        return input_size, output_size

    def _read_output_length(self):
        # TODO this is quite inefficient..
        input_length, output_length = self._read_spec()
        return output_length

    def _read_input_length(self):
        # TODO this is quite inefficient..
        input_length, output_length = self._read_spec()
        return input_length

    def write_input_tensor(self, raw_img):
        
        self._download_data(CMD_SET_INPUT_TENSOR, raw_img)
    
    def start_inference(self):

        to_send = self._construct_packet(CMD_START_INFER, 0)
        r =  self._dev.xfer(to_send)
    
    def read_output_tensor(self):

        output_tensor = self._upload_data(CMD_GET_OUTPUT_TENSOR, self.output_length)
        output_tensor = output_tensor[:self.output_length]
        return output_tensor

    def upload_model(self):
        # TODO
        pass

class xcore_ai_ie_usb(xcore_ai_ie):

    def __init__(self, timeout = 50000):
        self.__out_ep = None
        self.__in_ep = None
        self._dev = None
        self._timeout = timeout
        super().__init__()

    def _read_int_from_device(self):

        try:
            buff = usb.util.create_buffer(MAX_PACKET_SIZE)
            read_len = self._dev.read(self._in_ep, buff, 10000)
            assert read_len == 4
            return int.from_bytes(buff, byteorder = "little", signed=True)

        except usb.core.USBError as e:
            if e.backend_error_code == usb.backend.libusb1.LIBUSB_ERROR_PIPE:
                print("Device error, IN pipe halted (issue with model?)")
                sys.exit(1)

    def _write_int_to_device(self, i):
        self._out_ep.write(bytes([i]))

    def _write_array_to_device(self, a):

        self._out_ep.write(a, 1000)

        if (len(a) % MAX_PACKET_SIZE) == 0:
            self._out_ep.write(bytearray([]), 1000)

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

        #TODO assert type(model_bytes) == bytes
        
        # Send model to device 
        self._out_ep.write(bytes([CMD_SET_MODEL]))

        print("Model length (bytes): " + str(len(model_bytes)))

        self._write_array_to_device(model_bytes) 

        # Update input/output tensor lengths
        self._output_length = self._read_output_length() 
        print("output_length: " + str(self._output_length))
        self._input_length = self._read_input_length() 
        print("input_length: " + str(self._input_length))
        self._model_length = len(model_bytes)
        print("model_length: " + str(self._model_length))

    def _read_output_length(self):

        # Get output tensor length from device
        self._out_ep.write(bytes([CMD_GET_OUTPUT_LENGTH]), 50000)
        return self._read_int_from_device()

    def _read_input_length(self):
    
        # Get input tensor length from device
        self._out_ep.write(bytes([CMD_GET_INPUT_LENGTH]), self._timeout)
        return self._read_int_from_device()

    def write_input_tensor(self, raw_img):

        self._out_ep.write(bytes([CMD_SET_INPUT_TENSOR]))
        self._write_array_to_device(raw_img)

    def start_inference(self):

        # Send cmd
        self._out_ep.write(bytes([CMD_START_INFER]), 1000)

        # TOOD rm me
        # Send out a single byte packet 
        self._out_ep.write(bytes([1]), 1000)

    def read_output_tensor(self, timeout = 50000):

        if self._output_length == None:
            self._output_length = self._read_output_length()
            
        # Retrieve result from device
        # TOOD this should be reading until a non-MAX_PACKET_LENGTH packets is received
        self._out_ep.write(bytes([CMD_GET_OUTPUT_TENSOR]), timeout)
        output_data = self._dev.read(self._in_ep, self.output_length, 10000)
        return self.bytes_to_int(output_data)

    def upload_model(self):

        print("READING MODEL VIA USB..\n")
        
        self._write_int_to_device(CMD_GET_MODEL)

        try:
            return self._dev.read(self._in_ep, self._model_length, self._timeout)
        except usb.core.USBError as e:
            if e.backend_error_code == usb.backend.libusb1.LIBUSB_ERROR_PIPE:
                print("Device error, IN pipe halted (issue with model?)")
                sys.exit(1)


