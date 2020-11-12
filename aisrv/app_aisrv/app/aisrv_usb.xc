#include <xs1.h>
#include <print.h>
#include <stdio.h>
#include <stdlib.h>
#include "xud_device.h"

#define BCD_DEVICE   0x1000
#define VENDOR_ID    0x20B1
#define PRODUCT_ID   0xa15e

extern "C" {
void app_data(void *data, size_t size);
}

/* Device Descriptor */
static unsigned char devDesc[] =
{
    0x12,                  /* 0  bLength */
    USB_DESCTYPE_DEVICE,   /* 1  bdescriptorType */
    0x00,                  /* 2  bcdUSB */
    0x02,                  /* 3  bcdUSB */
    0xff,                  /* 4  bDeviceClass */
    0xff,                  /* 5  bDeviceSubClass */
    0xff,                  /* 6  bDeviceProtocol */
    0x40,                  /* 7  bMaxPacketSize */
    (VENDOR_ID & 0xFF),    /* 8  idVendor */
    (VENDOR_ID >> 8),      /* 9  idVendor */
    (PRODUCT_ID & 0xFF),   /* 10 idProduct */
    (PRODUCT_ID >> 8),     /* 11 idProduct */
    (BCD_DEVICE & 0xFF),   /* 12 bcdDevice */
    (BCD_DEVICE >> 8),     /* 13 bcdDevice */
    0x01,                  /* 14 iManufacturer */
    0x02,                  /* 15 iProduct */
    0x00,                  /* 16 iSerialNumber */
    0x01                   /* 17 bNumConfigurations */
};

static unsigned char cfgDesc[] =
{
    /* Configuration descriptor: */ 
    0x09,                               /* 0  bLength */ 
    0x02,                               /* 1  bDescriptorType */ 
    0x20, 0x00,                         /* 2  wTotalLength */ 
    0x01,                               /* 4  bNumInterface: Number of interfaces*/ 
    0x01,                               /* 5  bConfigurationValue */ 
    0x00,                               /* 6  iConfiguration */ 
    0x80,                               /* 7  bmAttributes */ 
    0xFA,                               /* 8  bMaxPower */  

    /*  Interface Descriptor (Note: Must be first with lowest interface number)r */
    0x09,                               /* 0  bLength: 9 */
    0x04,                               /* 1  bDescriptorType: INTERFACE */
    0x00,                               /* 2  bInterfaceNumber */
    0x00,                               /* 3  bAlternateSetting: Must be 0 */
    0x02,                               /* 4  bNumEndpoints (0 or 1 if optional interupt endpoint is present */
    0xff,                               /* 5  bInterfaceClass: AUDIO */
    0xff,                               /* 6  bInterfaceSubClass: AUDIOCONTROL*/
    0xff,                               /* 7  bInterfaceProtocol: IP_VERSION_02_00 */
    0x03,                               /* 8  iInterface */ 

/* Standard Endpoint Descriptor (INPUT): */
    0x07, 			                    /* 0  bLength: 7 */
    0x05, 			                    /* 1  bDescriptorType: ENDPOINT */
    0x01,                               /* 2  bEndpointAddress (D7: 0:out, 1:in) */
    0x02,
    0x00, 0x02,                         /* 4  wMaxPacketSize */
    0x01,                               /* 6  bInterval */

/* Standard Endpoint Descriptor (OUTPUT): */
    0x07, 			                    /* 0  bLength: 7 */
    0x05, 			                    /* 1  bDescriptorType: ENDPOINT */
    0x82,                               /* 2  bEndpointAddress (D7: 0:out, 1:in) */
    0x02,
    0x00, 0x02,                         /* 4  wMaxPacketSize */
    0x01,                               /* 6  bInterval */
};




unsafe{
/* String table */
static char * unsafe stringDescriptors[]=
{
    "\x09\x04",             // Language ID string (US English)
    "XMOS",                 // iManufacturer
    "xAISRV",               // iProduct
    "Config",               // iConfiguration
};
}




void aisrv_usb_ep0(chanend c_ep0_out, chanend c_ep0_in)
{

    USB_SetupPacket_t sp;

    unsigned bmRequestType;
    XUD_BusSpeed_t usbBusSpeed;

    XUD_ep ep0_out = XUD_InitEp(c_ep0_out);
    XUD_ep ep0_in  = XUD_InitEp(c_ep0_in);

    while(1)
    {
        /* Returns XUD_RES_OKAY on success */
        XUD_Result_t result = USB_GetSetupPacket(ep0_out, ep0_in, sp);

        if(result == XUD_RES_OKAY)
        {
            /* Set result to ERR, we expect it to get set to OKAY if a request is handled */
            result = XUD_RES_ERR;


            //result = AisrvClassRequests(ep0_out, ep0_in, sp);
        }

        /* If we haven't handled the request about then do standard enumeration requests */
        if(result == XUD_RES_ERR )
        {
            /* Returns  XUD_RES_OKAY if handled okay,
             *          XUD_RES_ERR if request was not handled (STALLed),
             *          XUD_RES_RST for USB Reset */
             unsafe{
            result = USB_StandardRequests(ep0_out, ep0_in, devDesc,
                        sizeof(devDesc), cfgDesc, sizeof(cfgDesc),
                        null, 0, null, 0, stringDescriptors, sizeof(stringDescriptors)/sizeof(stringDescriptors[0]),
                        sp, usbBusSpeed);
             }
        }

        /* USB bus reset detected, reset EP and get new bus speed */
        if(result == XUD_RES_RST)
        {
            usbBusSpeed = XUD_ResetEndpoint(ep0_out, ep0_in);
        }
    }
}





