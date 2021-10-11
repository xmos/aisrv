#ifndef _flash_h_
#define _flash_h_

typedef struct {
    int model_length;
    int model_start;
    int parameters_start;
    int operators_start;
} flash_t;

typedef enum {
    READ_FLASH_PARAMETERS = 0,           // TODO: share with lib_tflite_micro
    READ_FLASH_MODEL = 1,
    READ_FLASH_OPERATORS = 2,
} flash_command_t;

void flash_access(chanend c_flash[], flash_t headers[], int n_flash);

#endif
