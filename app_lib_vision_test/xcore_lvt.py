# Copyright (c) 2020, XMOS Ltd, All rights reserved
from abc import ABC, abstractmethod

import sys
import struct
import array

CMD_NONE                  = int(0x00)
CMD_GET_ARRAY             = int(0x03)
CMD_SET_ARRAY             = int(0x83)

XCORE_IE_MAX_BLOCK_SIZE = 512 

class AISRVError(Exception):
    """Error from device"""
    pass

class IOError(AISRVError):
    """IO Error from device"""
    pass

class NoModelError(AISRVError):
    """No model error from device"""
    pass

class ModelError(AISRVError):
    """Model error from device"""
    pass

class InferenceError(AISRVError):
    """Inference Error from device"""
    pass

class CommandError(AISRVError):
    """Command Error from device"""
    pass

class xcore_lvt(ABC):
    
    def __init__(self):
        self._output_length = None
        self._input_length = None
        self._model_length = None
        self._timings_length = None
        self._max_block_size = XCORE_IE_MAX_BLOCK_SIZE # TODO read from (usb) device?
        self._spec_length = 20 # TODO fix magic number
        super().__init__()
   
    @abstractmethod
    def connect(self):
        pass

    @property
    def input_length(self):
        return 1000

    @property
    def output_length(self):
        return 1000

    @abstractmethod
    def start_inference(self):
        pass
    
    @abstractmethod
    def _clear_error(self):
        pass

    def bytes_to_ints(self, data_bytes, bpi=1):

        output_data_int = []

        # TODO better way of doing this?
        for i in range(0, len(data_bytes), bpi):
            x = data_bytes[i:i+bpi]
            y =  int.from_bytes(x, byteorder = "little", signed=True)
            output_data_int.append(y)

        return output_data_int


    def write_tensor(self, raw_img, tensor_num = 0, engine_num = 0):
        
        self._download_data(CMD_SET_ARRAY, raw_img, tensor_num = tensor_num, engine_num = engine_num)


    def read_array(self, tensor_num = 0, engine_num = 0):

        # Retrieve result from device
        data_read = self._upload_data(CMD_GET_ARRAY, self.input_length, tensor_num = tensor_num, engine_num = engine_num)

        assert type(data_read) == list
        assert type(data_read[0]) == int

        return self.bytes_to_ints(data_read)



class xcore_lvt_usb(xcore_lvt):

    def __init__(self, timeout = 500000):
        self.__out_ep = None
        self.__in_ep = None
        self._dev = None
        self._timeout = timeout
        super().__init__()

    def _download_data(self, cmd, data_bytes, tensor_num = 0, engine_num = 0):
    
        import usb
        
        try:
            # TODO rm this extra CMD packet
            self._out_ep.write(bytes([cmd, engine_num, tensor_num]))
       
            #data_bytes = bytes([cmd]) + data_bytes

            self._out_ep.write(data_bytes, 1000)

            if (len(data_bytes) % self._max_block_size) == 0:
                self._out_ep.write(bytearray([]), 1000)

        except usb.core.USBError as e:
            if e.backend_error_code == usb.backend.libusb1.LIBUSB_ERROR_PIPE:
                #print("USB error, IN/OUT pipe halted")
                raise IOError()
   
    def _upload_data(self, cmd, length, sign = False, tensor_num = 0, engine_num = 0):
        
        import usb
        read_data = []

        try:  
            self._out_ep.write(bytes([cmd, engine_num, tensor_num]), self._timeout)
            buff = usb.util.create_buffer(self._max_block_size)
        
            while True:

                read_len = self._dev.read(self._in_ep, buff, 10000)

                read_data.extend(buff[:read_len])

                if read_len != self._max_block_size:
                    break;

            return read_data
        
        except usb.core.USBError as e:
            if e.backend_error_code == usb.backend.libusb1.LIBUSB_ERROR_PIPE:
                #print("USB error, IN/OUT pipe halted")
                raise IOError()

    def _clear_error(self):
        self._dev.clear_halt(self._out_ep)
        self._dev.clear_halt(self._in_ep)

    def connect(self):

        import usb
        self._dev = None
        while self._dev is None:

            # TODO - more checks that we have the right device..
            self._dev = usb.core.find(idVendor=0x20b1, idProduct=0xa15e)

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

            print("Connected to AISRV via USB")

    # TODO move to super()
    def start_inference(self, engine_num = 0):

        # Send cmd
        self._out_ep.write(bytes([aisrv_cmd.CMD_START_INFER, engine_num, 0]), 1000)

        # Send out a 0 length packet 
        self._out_ep.write(bytes([]), 1000)

    # TODO move to super()
    def start_acquire_single(self, sx, ex, sy, ey, rw, rh, engine_num = 0):

        # Send cmd
        self._out_ep.write(bytes([aisrv_cmd.CMD_START_ACQUIRE_SINGLE, engine_num, 0]), 1000)
        def tobytes(l):
            o = []
            for i in l:
                o.append( i & 0xff )
                o.append( (i>>8) & 0xff )
            return bytes(o)
        # Send out packet with coordinates 
        self._out_ep.write(tobytes([sx, ex, sy, ey, rw, rh]), 1000)

    def acquire_set_i2c(self, i2c_address, reg_address, reg_value, engine_num = 0):

        # Send cmd
        self._out_ep.write(bytes([aisrv_cmd.CMD_START_ACQUIRE_SET_I2C, engine_num, 0]), 1000)
        def tobytes(l):
            o = []
            for i in l:
                o.append( i & 0xff )
            return bytes(o)
        # Send out packet with coordinates 
        self._out_ep.write(tobytes([i2c_address, reg_address, reg_value]), 1000)

    # TODO move to super()
    def start_acquire_stream(self, engine_num = 0):

        # Send cmd
        self._out_ep.write(bytes([aisrv_cmd.CMD_START_ACQUIRE_STREAM, engine_num, 0]), 1000)

        # Send out a 0 length packet 
        self._out_ep.write(bytes([]), 1000)

    #TODO move to super()
    def enable_output_gpio(self, engine_num = 0):

        self._out_ep.write(bytes([aisrv_cmd.CMD_SET_OUTPUT_GPIO_EN, engine_num, 0]), 1000)
        self._out_ep.write(bytes([1]), 1000)
    
    #TODO move to super()
    def disable_output_gpio(self, engine_num = 0):

        self._out_ep.write(bytes([aisrv_cmd.CMD_SET_OUTPUT_GPIO_EN, engine_num, 0]), 1000)
        self._out_ep.write(bytes([0]), 1000)

    def set_output_gpio_threshold(self, index, threshold):
        
        self._out_ep.write(bytes([aisrv_cmd.CMD_SET_OUTPUT_GPIO_THRESH, engine_num, 0]), 1000)
        self._out_ep.write(bytes([index, threshold]), 1000)

    def set_output_gpio_mode_max(self, engine_num = 0):
        
        self._out_ep.write(bytes([aisrv_cmd.CMD_SET_OUTPUT_GPIO_MODE, engine_num, 0]), 1000)
        self._out_ep.write(bytes([1]), 1000)

    def set_output_gpio_mode_none(self, engine_num = 0):
        
        self._out_ep.write(bytes([aisrv_cmd.CMD_SET_OUTPUT_GPIO_MODE, engine_num, 0]), 1000)
        self._out_ep.write(bytes([0]), 1000)








    



    
  
