--
--  Copyright (C) 2024, Vadim Godunko <vgodunko@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

with A0B.SVD.STM32H723.DMA;    use A0B.SVD.STM32H723.DMA;
with A0B.SVD.STM32H723.DMAMUX; use A0B.SVD.STM32H723.DMAMUX;
with A0B.SVD.STM32H723.GPIO;   use A0B.SVD.STM32H723.GPIO;
with A0B.SVD.STM32H723.LPTIM;  use A0B.SVD.STM32H723.LPTIM;
with A0B.SVD.STM32H723.PSSI;   use A0B.SVD.STM32H723.PSSI;
with A0B.SVD.STM32H723.RCC;    use A0B.SVD.STM32H723.RCC;

--  with A0B.Delays;
--  with A0B.Time;

package body LADO.Acquisition is

   --  3000_0000 .. 3FFF  SRAM1
   --  3000_4000 .. 7FFF  SRAM2
   --  3800_0000 .. 3FFF  SRAM4

   procedure Configure_PSSI;

   procedure Configure_LPTIM4;

   procedure Configure_DMA;

   procedure Configure_GPIO_PSSI;

   procedure Configure_GPIO_LPTIM4;

   package GPIO_Utilities is

      subtype Low_Line is Integer range 0 .. 7;
      subtype High_Line is Integer range 8 .. 15;

      procedure Configure_L
        (Peripheral  : in out GPIO_Peripheral;
         Line        : Low_Line;
         Alternative : AFRH_AFSEL_Element);

      procedure Configure_H
        (Peripheral  : in out GPIO_Peripheral;
         Line        : High_Line;
         Alternative : AFRH_AFSEL_Element);

   end GPIO_Utilities;

   -------------------
   -- Configure_DMA --
   -------------------

   procedure Configure_DMA is
   begin
      RCC_Periph.AHB1ENR.DMA1EN := True;
   end Configure_DMA;

   ---------------------------
   -- Configure_GPIO_LPTIM4 --
   ---------------------------

   procedure Configure_GPIO_LPTIM4 is
   begin
      --  PA2 -> LPTIM4_OUT
      GPIO_Utilities.Configure_L (GPIOA_Periph, 2, 3);
   end Configure_GPIO_LPTIM4;

   -------------------------
   -- Configure_GPIO_PSSI --
   -------------------------

   procedure Configure_GPIO_PSSI is
   begin
      --  Enable clocks

      RCC_Periph.AHB4ENR.GPIOAEN := True;
      RCC_Periph.AHB4ENR.GPIOBEN := True;
      RCC_Periph.AHB4ENR.GPIOCEN := True;
      RCC_Periph.AHB4ENR.GPIODEN := True;
      RCC_Periph.AHB4ENR.GPIOEEN := True;
      RCC_Periph.AHB4ENR.GPIOFEN := True;
      RCC_Periph.AHB4ENR.GPIOGEN := True;

      GPIO_Utilities.Configure_L (GPIOA_Periph, 4, 13);
      --  PA4  -> PSSI_DE
      GPIO_Utilities.Configure_L (GPIOA_Periph, 5, 13);
      --  PA5  -> PSSI_D14
      GPIO_Utilities.Configure_L (GPIOA_Periph, 6, 13);
      --  PA6  -> PSSI_PDCK

      GPIO_Utilities.Configure_L (GPIOB_Periph, 7, 13);
      --  PB7  -> PSSI_RDY

      GPIO_Utilities.Configure_L (GPIOC_Periph, 5, 4);
      --  PC5  -> PSSI_D15
      GPIO_Utilities.Configure_L (GPIOC_Periph, 6, 13);
      --  PC6  -> PSSI_D0
      GPIO_Utilities.Configure_L (GPIOC_Periph, 7, 13);
      --  PC7  -> PSSI_D1
      GPIO_Utilities.Configure_H (GPIOC_Periph, 8, 13);
      --  PC8  -> PSSI_D2
      GPIO_Utilities.Configure_H (GPIOC_Periph, 9, 13);
      --  PC9  -> PSSI_D3
      GPIO_Utilities.Configure_H (GPIOC_Periph, 10, 13);
      --  PC10 -> PSSI_D8
      GPIO_Utilities.Configure_H (GPIOC_Periph, 12, 13);
      --  PC12 -> PSSI_D9

      GPIO_Utilities.Configure_L (GPIOD_Periph, 2, 13);
      --  PD2  -> PSSI_D11
      GPIO_Utilities.Configure_L (GPIOD_Periph, 3, 13);
      --  PD3  -> PSSI_D5
      GPIO_Utilities.Configure_L (GPIOD_Periph, 6, 13);
      --  PD6  -> PSSI_D10
      GPIO_Utilities.Configure_H (GPIOD_Periph, 13, 13);
      --  PD13 -> PSSI_D13

      GPIO_Utilities.Configure_L (GPIOE_Periph, 4, 13);
      --  PE4  -> PSSI_D4
      GPIO_Utilities.Configure_L (GPIOE_Periph, 5, 13);
      --  PE5  -> PSSI_D6
      GPIO_Utilities.Configure_L (GPIOE_Periph, 6, 13);
      --  PE6  -> PSSI_D7

      GPIO_Utilities.Configure_H (GPIOF_Periph, 11, 13);
      --  PF11 -> PSSI_D12
   end Configure_GPIO_PSSI;

   ----------------------
   -- Configure_LPTIM4 --
   ----------------------

   procedure Configure_LPTIM4 is
   begin
      RCC_Periph.D3CCIPR.LPTIM345SEL := 2#001#;
      --  pll2_p_ck clock selected as kernel peripheral clock

      RCC_Periph.APB4ENR.LPTIM4EN := True;

      LPTIM4_Periph.CR.ENABLE := False;
      --  Disable timer periperal to be able to modify CFGR register.

      LPTIM4_Periph.CFGR :=
        (CKSEL     => False,
         --  LPTIM is clocked by internal clock source (APB clock or any of
         --  the embedded oscillators)
         CKPOL     => 2#00#,
         --  The rising edge is the active edge used for counting.
         CKFLT     => <>,      --  if external clock
         TRGFLT    => <>,      --  if hardware trigger
         PRESC     => 2#000#,  --  /1
         TRIGSEL   => <>,      --  if external trigger
         TRIGEN    => 2#00#,
         --  Software trigger (counting start is initiated by software)
         TIMOUT    => False,
         --  A trigger event arriving when the timer is already started will
         --  be ignored.
         WAVE      => False,   --  Deactivate Set-once mode
         WAVPOL    => False,
         --  The LPTIM output reflects the compare results between LPTIM_CNT
         --  and LPTIM_CMP registers.
         PRELOAD   => False,
         --  Registers are updated after each APB bus write access
         COUNTMODE => False,
         --  The counter is incremented following each internal clock pulse
         ENC       => False,   --  Encoder mode disabled
         others    => <>);

      LPTIM4_Periph.CR.ENABLE := True;
      --  Enable timer to be able to continue configuration.

   end Configure_LPTIM4;

   --------------------
   -- Configure_PSSI --
   --------------------

   procedure Configure_PSSI is
   begin
      RCC_Periph.AHB2ENR.DCMI_PSSIEN := True;

      PSSI_Periph.PSSI_CR.ENABLE := B_0x0;
      --  Disable PSSI to be able to configure it.

      PSSI_Periph.PSSI_CR :=
        (CKPOL    => B_0x0,
         --  Falling edge active for inputs or rising edge active for outputs
         DEPOL    => B_0x0,
         --  PSSI_DE active low (0 indicates that data is valid)
         RDYPOL   => B_0x0,
         --  PSSI_RDY active low (0 indicates that the receiver is ready to
         --  receive)
         EDM      => B_0x3,
         --  The interface captures 16-bit data on every parallel data clock
         ENABLE   => B_0x0,  --  PSSI disabled
         DERDYCFG => B_0x0,  --  PSSI_DE and PSSI_RDY both disabled
         DMAEN    => B_0x1,  --  DMA transfers are enabled.
         OUTEN    => B_0x0,
         --  Receive mode: data is input synchronously with PSSI_PDCK
         others   => <>);
   end Configure_PSSI;

   --------------------
   -- GPIO_Utilities --
   --------------------

   package body GPIO_Utilities is

      -----------------
      -- Configure_H --
      -----------------

      procedure Configure_H
        (Peripheral  : in out GPIO_Peripheral;
         Line        : High_Line;
         Alternative : AFRH_AFSEL_Element) is
      begin
         Peripheral.OSPEEDR.Arr (Line) := 2#11#;      --  Very high speed
         Peripheral.OTYPER.OT.Arr (Line) := False;    --  Output push-pull
         Peripheral.PUPDR.Arr (Line) := 2#01#;        --  Pullup
         Peripheral.AFRH.Arr (Line) := Alternative;   --  Alternate function
         Peripheral.MODER.Arr (Line) := 2#10#;        --  Alternate function
      end Configure_H;

      -----------------
      -- Configure_L --
      -----------------

      procedure Configure_L
        (Peripheral  : in out GPIO_Peripheral;
         Line        : Low_Line;
         Alternative : AFRH_AFSEL_Element) is
      begin
         Peripheral.OSPEEDR.Arr (Line) := 2#11#;      --  Very high speed
         Peripheral.OTYPER.OT.Arr (Line) := False;    --  Output push-pull
         Peripheral.PUPDR.Arr (Line) := 2#01#;        --  Pullup
         Peripheral.AFRL.Arr (Line) := Alternative;   --  Alternate function
         Peripheral.MODER.Arr (Line) := 2#10#;        --  Alternate function
      end Configure_L;

   end GPIO_Utilities;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize is
   begin
      Configure_GPIO_PSSI;
      Configure_GPIO_LPTIM4;
      Configure_DMA;
      Configure_PSSI;
      Configure_LPTIM4;
   end Initialize;

   ---------
   -- Run --
   ---------

   procedure Run is
   begin
      --  LPTIM4_Periph.ARR.ARR := 100;  --  1 MHz
      --  LPTIM4_Periph.CMP.CMP := 50;   --  50/50
      LPTIM4_Periph.ARR.ARR := 20;  --  5 MHz
      LPTIM4_Periph.CMP.CMP := 10;   --  50/50

      DMA1_Periph.S0CR.EN := False;

      DMA1_Periph.S0CR :=
        (DMEIE          => False,  --  DME interrupt disabled
         TEIE           => False,  --  TE interrupt disabled
         HTIE           => False,  --  HT interrupt disabled
         TCIE           => False,  --  TC interrupt disabled
         PFCTRL         => True,   --  The peripheral is the flow controller.
         DIR            => 2#00#,  --  peripheral-to-memory
         CIRC           => False,  --  circular mode disabled
         PINC           => False,  --  peripheral address pointer fixed
         MINC           => True,
         --  memory address pointer is incremented after each data transfer
         --  (increment is done according to MSIZE)
         PSIZE          => 2#10#,  --  word (32-bit)
         MSIZE          => 2#10#,  --  word (32-bit)
         PINCOS         => <>,     --  if PINC
         PL             => 2#10#,  --  high
         DBM            => False,
         --  No buffer switching at the end of transfer
         CT             => False,
         --  Current target memory is Memory 0 (addressed by the DMA_SxM0AR
         --  pointer)
         Reserved_20_20 => 0,  --  bufferable transfers not enabled
         PBURST         => 0,  --  single transfer
         MBURST         => 0,  --  single transfer
         others         => <>);
      DMA1_Periph.S0NDTR := (NDT => 4_096, others => <>);
      DMA1_Periph.S0PAR  := 16#4802_0428#;
      DMA1_Periph.S0M0AR := 16#3000_0000#;
      DMA1_Periph.S0M1AR := 16#3000_4000#;

      DMAMUX1_Periph.DMAMUX_C0CR :=
        (DMAREQ_ID => 75,     --  dcmi_dma
         SOIE      => B_0x0,  --  Interrupt disabled
         EGE       => B_0x0,  --  Event generation disabled
         SE        => B_0x0,  --  Synchronization disabled
         SPOL      => B_0x0,
         --  No event, i.e. no synchronization nor detection.
         NBREQ     => 0,
         SYNC_ID   => 0,
         others    => <>);

      DMA1_Periph.S0CR.EN := True;

      PSSI_Periph.PSSI_CR.ENABLE := B_0x1;

      --  A0B.Delays.Delay_For (A0B.Time.Milliseconds (1));
      LPTIM4_Periph.CR.ENABLE := True;
      --  A0B.Delays.Delay_For (A0B.Time.Milliseconds (1));
      LPTIM4_Periph.CR.CNTSTRT := True;
   end Run;

end LADO.Acquisition;
