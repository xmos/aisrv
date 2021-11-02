#include <stdio.h>
#include <print.h>
#include <stdint.h>
#include <platform.h>
#include "flash.h"

#define TMP_BUF_SIZE  1024

void flash_server(chanend c_flash[], flash_t headers[], int n_flash,
                  fl_QSPIPorts &qspi, fl_QuadDeviceSpec flash_spec[],
                  int n_flash_spec) {
    int res;
    if ((res = fl_connectToDevice(qspi, flash_spec, n_flash_spec)) != 0) {
        printf("ERROR %d\n", res);
    }
    if ((res = fl_dividerOverride(2)) != 0) {   // 25 MHz - sort of safe.
        printf("ERROR %d\n", res);
    }
    fl_readData(0, n_flash * sizeof(flash_t), (headers, unsigned char[]) ); // TODO, check?
    while(1) {
        int address, bytes;
        flash_command_t cmd;
        select {
            case (int i = 0; i < n_flash; i++) c_flash[i] :> cmd:
                master {
                    if (cmd == FLASH_READ_PARAMETERS) {
                        c_flash[i] :> address;
                        c_flash[i] :> bytes;
                        address = headers[i].parameters_start + address;
                    } else if (cmd == FLASH_READ_MODEL) {
                        unsigned char bytes_length[sizeof(uint32_t)];
                        address = headers[i].model_start;
                        fl_readData(address, sizeof(uint32_t), bytes_length);  // read length
                        address += sizeof(uint32_t);
                        bytes   = (bytes_length, unsigned[])[0];
                        c_flash[i] <: bytes;
                    } else if (cmd == FLASH_READ_OPERATORS) {
                        ; // TODO
                    }
                    unsigned char buf[TMP_BUF_SIZE];
                    for(int k = 0; k < bytes; k += TMP_BUF_SIZE) {
                        int buf_bytes = TMP_BUF_SIZE;
                        if (k + buf_bytes > bytes) {
                            buf_bytes = bytes - k;
                        }
                        fl_readData(address+k, buf_bytes, buf); // TODO, check?
                        for(int j = 0; j < buf_bytes; j++) {
                            c_flash[i] <: buf[j];
                        }
                    }
                }
                break;
        }
    }
}

