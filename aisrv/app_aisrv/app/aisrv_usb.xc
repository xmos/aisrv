#include <xs1.h>


void aisrv_ep0(c_out, c_in)
{

}



void aiarv_usb(chanend c_ep_out[], chanend c_ep_in[])
{
    par
    {
        aisrv_ep0(c_ep_out[0], c_ep_in[0]);
    }
}
