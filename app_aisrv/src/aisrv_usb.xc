#include <xs1.h>
#include <print.h>
#include <stdio.h>
#include <stdlib.h>
#include "xud_device.h"
#include "aisrv.h"

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
    MAX_PACKET_SIZE & 0xff, (MAX_PACKET_SIZE >> 8) & 0xff, /* 4  wMaxPacketSize */
    0x01,                               /* 6  bInterval */

/* Standard Endpoint Descriptor (OUTPUT): */
    0x07, 			                    /* 0  bLength: 7 */
    0x05, 			                    /* 1  bDescriptorType: ENDPOINT */
    0x81,                               /* 2  bEndpointAddress (D7: 0:out, 1:in) */
    0x02,
    MAX_PACKET_SIZE & 0xff, (MAX_PACKET_SIZE >> 8) & 0xff, /* 4  wMaxPacketSize */
    0x01,                               /* 6  bInterval */
};


unsafe
{
    /* String table */
    static char * unsafe stringDescriptors[]=
    {      
        "\x09\x04",             // Language ID string (US English)
        "XMOS",                 // iManufacturer
        "xAISRV",               // iProduct
        "Config",               // iConfiguration
    };
}


void aisrv_usb_ep0(chanend c_ep0_out, chanend c_ep0_in, chanend c_data)
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
            // TODO 
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
        
        unsigned bmRequestType = (sp.bmRequestType.Direction<<7) | (sp.bmRequestType.Type<<5) | (sp.bmRequestType.Recipient);

        if((bmRequestType == USB_BMREQ_H2D_STANDARD_EP)
            && (sp.bRequest == USB_CLEAR_FEATURE)
            && (sp.wLength == 0)
            /* The only Endpoint feature selector is HALT (bit 0) see figure 9-6 */
            && (sp.wValue == USB_ENDPOINT_HALT)
            && ((sp.wIndex & 0x7F) == 1)) // EP 1 IN or OUT
        {
            c_data <: (unsigned) sp.wIndex;
        }

        /* USB bus reset detected, reset EP and get new bus speed */
        if(result == XUD_RES_RST)
        {
            usbBusSpeed = XUD_ResetEndpoint(ep0_out, ep0_in);
        }
    }
}

#ifdef ENABLE_USB
unsafe
{
// TODO Move to USB file
void aisrv_usb_data(chanend c_ep_out, chanend c_ep_in, chanend c, chanend c_ep0)
{
    int32_t data[MAX_PACKET_SIZE_WORDS];

    XUD_ep ep_out = XUD_InitEp(c_ep_out);
    XUD_ep ep_in  = XUD_InitEp(c_ep_in);

    aisrv_cmd_t cmd = CMD_NONE;

    int result_requested = 0;

    int output_size = 0;
    int input_size = 0;
    int stalled_in = 0;
    int stalled_out = 0;

    while(1)
    {
        unsigned length = 0;
       
        while(stalled_in || stalled_out)
        {
            unsigned x;
            
            /* Wait for clear on both Endpoints */
            c_ep0 :> x;
            
            if(x == 0x01)
                stalled_out = 0;
            else if(x == 0x81)
                stalled_in = 0;
        }

        /* Get command */
        XUD_GetBuffer(ep_out, (data, uint8_t[]), length);
                
        cmd = (uint8_t) data[0];

        if(length != CMD_LENGTH_BYTES)
        {
            printf("Bad cmd length: %d\n", length);
            continue;
        }

        /* Pass on command */
        c <: cmd;

        #if 0
        printf("CMD: ");
        switch(cmd)
        {
            case CMD_SET_MODEL:
                printf("SET_MODEL\n");
                break;
            
            case CMD_GET_SPEC:
                printf("GET_SPEC\n");
                break;

            case CMD_GET_DEBUG_LOG:
                printf("GET_DEBUG_LOG\n");
                break;

            default:
                printf("%x\n", cmd);
                break;
        }
        #endif
       
        /* Check cmd write bit */
        if(cmd & 0x80)
        {
            while(1)
            {
                unsigned pktLength;
                XUD_GetBuffer(ep_out, (data, uint8_t[]), pktLength);
       
                printf("Received: %d bytes\n", pktLength);
                
                size_t i = 0;
                for(i = 0; i < (pktLength/4); i++)
                {
                    outuint(c, data[i]);
                }
              
                if(pktLength != MAX_PACKET_SIZE)
                {
                    i *= 4;
                    outct(c, XS1_CT_END);
                    while(i < pktLength)
                    {
                        outuchar(c, (data, uint8_t[])[i++]);
                    }
                    outct(c, XS1_CT_END);
                    break;
                }
            }

            aisrv_status_t status;
            status = inuint(c);
            chkct(c, XS1_CT_END);

            if(status != AISRV_STATUS_OKAY)
            {
                printf("Write Error, setting stall\n");
                stalled_in = 1;
                stalled_out = 1;
                XUD_SetStall(ep_in);
                XUD_SetStall(ep_out);
            }
        }
        else
        {
            /* Read command */
            aisrv_status_t status = AISRV_STATUS_OKAY;
           
            c :> status;

            if(status == AISRV_STATUS_OKAY)
            {
                size_t i = 0;
                while(!testct(c))
                {
                    data[i++] = inuint(c); 

                    if(i == MAX_PACKET_SIZE_WORDS)
                    {
                        XUD_SetBuffer(ep_in, (data, uint8_t[]), MAX_PACKET_SIZE);
                        i = 0;
                    } 
                }

                chkct(c, XS1_CT_END);
                i *= 4;

                while(!testct(c))
                {
                    (data, uint8_t[])[i++] = inuchar(c);
                }
                
                chkct(c, XS1_CT_END);
                
                XUD_SetBuffer(ep_in, (data, uint8_t[]), i);
            }
            else
            {
                printf("Read Error, setting stall\n");
                stalled_in = 1;
                stalled_out = 1;
                XUD_SetStall(ep_in);
                XUD_SetStall(ep_out);
            }
        }
    } // while(1)
}
} // unsafe

#endif




