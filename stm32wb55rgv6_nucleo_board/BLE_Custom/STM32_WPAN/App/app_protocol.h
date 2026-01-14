#pragma once

#include <stdint.h>

void AppProtocol_Init(void);
void AppProtocol_HandleRx(uint8_t *data, uint16_t len);
