#include <quadflash.h>
#include <stdio.h>
#include <print.h>
#include <stdint.h>
#include <platform.h>
#include "flash.h"

// TODO: move back to main.

on tile[0]: fl_QSPIPorts qspi = {
    PORT_SQI_CS,
    PORT_SQI_SCLK,
    PORT_SQI_SIO,
    XS1_CLKBLK_2
};

#define FL_QUADDEVICE_MACRONIX_MX25R6435FM2IH0 \
{ \
    16,                     /* MX25R6435FM2IH0 */ \
    256,                    /* page size */ \
    32768,                  /* num pages */ \
    3,                      /* address size */ \
    3,                      /* log2 clock divider */ \
    0x9F,                   /* QSPI_RDID */ \
    0,                      /* id dummy bytes */ \
    3,                      /* id size in bytes */ \
    0xC22817,               /* device id */ \
    0x20,                   /* QSPI_SE */ \
    4096,                   /* Sector erase is always 4KB */ \
    0x06,                   /* QSPI_WREN */ \
    0x04,                   /* QSPI_WRDI */ \
    PROT_TYPE_NONE,         /* no protection */ \
    {{0,0},{0x00,0x00}},    /* QSPI_SP, QSPI_SU */ \
    0x02,                   /* QSPI_PP */ \
    0xEB,                   /* QSPI_READ_FAST */ \
    1,                      /* 1 read dummy byte */ \
    SECTOR_LAYOUT_REGULAR,  /* mad sectors */ \
    {4096,{0,{0}}},         /* regular sector sizes */ \
    0x05,                   /* QSPI_RDSR */ \
    0x01,                   /* QSPI_WRSR */ \
    0x01,                   /* QSPI_WIP_BIT_MASK */ \
}

fl_QuadDeviceSpec deviceSpecs[] = {
    FL_QUADDEVICE_MACRONIX_MX25R6435FM2IH0
};

#define TMP_BUF_SIZE  1024

void flash_access(chanend c_flash[], flash_t headers[], int n_flash) {
    int res;
    if ((res = fl_connectToDevice(qspi, deviceSpecs, 1)) != 0) {
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
                    if (cmd == READ_FLASH_PARAMETERS) {
                        c_flash[i] :> address;
                        c_flash[i] :> bytes;
                        address += headers[i].parameters_start;
                    } else if (cmd == READ_FLASH_MODEL) {
                        address = headers[i].model_start;
                        bytes   = headers[i].model_length;
                        c_flash[i] <: bytes;
                    } else if (cmd == READ_FLASH_OPERATORS) {
                        ; // TODO
                    }
                    printf("reading %d from %d\n", bytes, address);
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
