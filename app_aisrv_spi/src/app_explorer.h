
#ifndef _APP_EXPLORER_H_
#define _APP_EXPLORER_H_

#define NETWORK_ARENA_SIZE (209 * 1024)
#define NETWORK_HEAP_SIZE (5 * 1024)
#define NETWORK_NUM_THREADS 1

#ifndef EMBEDDING_SIZE 
#define EMBEDDING_SIZE 77
#endif

#ifndef NETWORK_INPUT_HEIGHT
#define NETWORK_INPUT_HEIGHT 112
#endif


#ifndef NETWORK_INPUT_WIDTH
#define NETWORK_INPUT_WIDTH 112
#endif

#ifndef NETWORK_INPUT_DEPTH
#define NETWORK_INPUT_DEPTH 4
#endif

#ifndef NETWORK_DISTANCE_THRESHOLD 
#define NETWORK_DISTANCE_THRESHOLD 100
#endif

#define NETWORK_INPUT_SIZE (NETWORK_INPUT_HEIGHT * NETWORK_INPUT_WIDTH * NETWORK_INPUT_DEPTH)

#define RAW_IMAGE_HEIGHT 320
#define RAW_IMAGE_WIDTH  320

/* Input network data from xcope (or camera) */
#ifndef INPUT_XSCOPE 
#define INPUT_XSCOPE 0
#endif

#warning Disabling printf..
#define printf(...) 
#define fflush(x)

#endif
