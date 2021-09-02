#ifndef HM0360_H
#define HM0360_H

#include <i2c.h>

/* This module interaces a himax 0360 module to an xcore.
 * this module produces 640x480 images at 13-14 fps.
 */

/** Function that initialises the hm0360 module
 * It needs to have an I2C interface to communicate with the camera */

void hm0360_reset();

/** Function that reads data from the camera module; this function
 * makes the hm0360 looks like a MIPI camera.
 * the c_frames and c_kill parameters fullfill the same purposes
 *
 * TODO: make everything else (ports) parameters
 * TODO: implement c_kill
 *
 * \param c_frames    Channel to communicate line buffers with the camera
 * \param c_kill      Channel to kill the receiver
 */
void hm0360_rx(chanend c_frames, chanend c_kill);

void hm0360_monolith_rgb(client interface i2c_master_if i2c, uint8_t * unsafe pt);
int hm0360_stream_start(client interface i2c_master_if i2c);
void hm0360_monolith_init();
void hm0360_monolith_single(client interface i2c_master_if i2c, uint8_t * unsafe pt);

#endif
