#include "app_protocol.h"
#include "shci.h"
#include "ble.h"
#include "custom_stm.h"
#include "stm32wbxx_nucleo.h"

#define FRAME_RX_PREAMBLE   0xAA
#define FRAME_TX_PREAMBLE   0xBB

#define CMD_GET_RSSI        0x01
#define CMD_GET_FW_BUILD    0x02
#define CMD_LED_TEST  		0x03
#define CMD_GET_LINK_STATUS 0x04

static uint8_t tx_buf[8];

void AppProtocol_Init(void)
{
}

void AppProtocol_HandleRx(uint8_t *data, uint16_t len)
{
    if (len < 2) return;
    if (data[0] != FRAME_RX_PREAMBLE) return;

    switch (data[1])
    {
        case CMD_GET_RSSI:
        {
            int8_t rssi = 0;

            if (aci_hal_read_rssi((uint8_t *)&rssi) != BLE_STATUS_SUCCESS)
                return;

            tx_buf[0] = FRAME_TX_PREAMBLE;
            tx_buf[1] = CMD_GET_RSSI;
            tx_buf[2] = (uint8_t)rssi;

            Custom_STM_App_Update_Char_Variable_Length(
                CUSTOM_STM_LONG_C,
                tx_buf,
                3
            );
        }
        break;

        case CMD_GET_FW_BUILD:
        {
            WirelessFwInfo_t fw;
            tBleStatus st;

            st = SHCI_GetWirelessFwInfo(&fw);

            tx_buf[0] = FRAME_TX_PREAMBLE;
            tx_buf[1] = CMD_GET_FW_BUILD;
            tx_buf[2] = fw.VersionMajor;
            tx_buf[3] = fw.VersionMinor;
            tx_buf[4] = fw.VersionSub;
            tx_buf[5] = (uint8_t)st;

            Custom_STM_App_Update_Char_Variable_Length(
                CUSTOM_STM_LONG_C,
                tx_buf,
                6
            );
        }
        break;

        case CMD_LED_TEST:
        {
            uint8_t ok = 1;

            for (int i = 0; i < 3; i++)
            {
                BSP_LED_Toggle(LED_BLUE);
                HAL_Delay(150);
                BSP_LED_Toggle(LED_BLUE);
                HAL_Delay(150);
            }

            tx_buf[0] = FRAME_TX_PREAMBLE;  // BB
            tx_buf[1] = CMD_LED_TEST;       // 03
            tx_buf[2] = ok;                 // 1 = success

            Custom_STM_App_Update_Char_Variable_Length(
                CUSTOM_STM_LONG_C,
                tx_buf,
                3
            );
        }
        break;

        case CMD_GET_LINK_STATUS:
        {
            uint8_t  link_status[8] = {0};
            uint16_t link_handle[8] = {0};

            if (aci_hal_get_link_status(link_status, link_handle) != BLE_STATUS_SUCCESS)
                return;

            tx_buf[0] = FRAME_TX_PREAMBLE;      // BB
            tx_buf[1] = CMD_GET_LINK_STATUS;    // 04
            tx_buf[2] = link_status[0];

            Custom_STM_App_Update_Char_Variable_Length(
                CUSTOM_STM_LONG_C,
                tx_buf,
                3
            );
        }
        break;


        default:
        break;
    }
}

