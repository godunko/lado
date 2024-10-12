# Connections

DevEBox STM32H7XX_M board uses SDMMC1 and QUADSPI. It limits number of input
channels to 8.

A19 is lowerest supported and available FMC address line, while 800x480 screen
requires to use A20 (16bit color)/A21 (24bit color) for full screen DMA
transfer.

H743: Maximum DCMI clock is 80 MHz. Maximum timer external clock is 120 MHz.
So, looks good, while a bit slower than H723.

| STM32H7xx             |       |
| :-------------------: | :---: |
| FMC_NE1               | D7    |
| FMC_A19^              | E3    |
| FMC_NWE               | D5    |
| FMC_NOE               | D4    |
| FMC_D0                | D14   |
| FMC_D1                | D15   |
| FMC_D2                | D0    |
| FMC_D3                | D1    |
| FMC_D4                | E7    |
| FMC_D5                | E8    |
| FMC_D6                | E9    |
| FMC_D7                | E10   |
| FMC_D8                | E11   |
| FMC_D9                | E12   |
| FMC_D10               | E13   |
| FMC_D11               | E14   |
| FMC_D12               | E15   |
| FMC_D13               | D8    |
| FMC_D14               | D9    |
| FMC_D15               | D10   |
|                       |       |
| PSSI_PDCK/DCMI_PIXCLK | A6    |
| PSSI_DE/DCMI_HSYNC    | A4    |
| PSSI_RDY/DCMI_VSYNC   | B7    |
| PSSI_D0/DCMI_D0       | C6    |
| PSSI_D1/DCMI_D1       | C7    |
| PSSI_D2/DCMI_D2       | E0    |
| PSSI_D3/DCMI_D3       | E1    |
| PSSI_D4/DCMI_D4       | E4    |
| PSSI_D5/DCMI_D5       | D3    |
| PSSI_D6/DCMI_D6       | E5    |
| PSSI_D7/DCMI_D7       | E6    |
| PSSI_D8/DCMI_D8       | C10   |
| PSSI_D9/DCMI_D9       | C12   |
| PSSI_D10/DCMI_D10     | D6    |
| PSSI_D11/DCMI_D11     | D2    |
| PSSI_D12              | F11   |
| PSSI_D13              | D13   |
| PSSI_D14              | A5    |
| PSSI_D15              | C5    |
