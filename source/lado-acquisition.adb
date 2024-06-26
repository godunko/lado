--
--  Copyright (C) 2024, Vadim Godunko <vgodunko@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

pragma Ada_2022;

with A0B.ARMv7M.NVIC_Utilities; use A0B.ARMv7M.NVIC_Utilities;
with A0B.STM32H723.GPIO;
with A0B.STM32H723.SVD.DMA;     use A0B.STM32H723.SVD.DMA;
with A0B.STM32H723.SVD.DMAMUX;  use A0B.STM32H723.SVD.DMAMUX;
with A0B.STM32H723.SVD.LPTIM;   use A0B.STM32H723.SVD.LPTIM;
with A0B.STM32H723.SVD.PSSI;    use A0B.STM32H723.SVD.PSSI;

package body LADO.Acquisition is

   --  3000_0000 .. 3FFF  SRAM1
   --  3000_4000 .. 7FFF  SRAM2
   --  3800_0000 .. 3FFF  SRAM4

   LPTIM4_OUT : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PA2;
   PSSI_D0    : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PC6;
   PSSI_D1    : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PC7;
   PSSI_D2    : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PC8;
   PSSI_D3    : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PC9;
   PSSI_D4    : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PE4;
   PSSI_D5    : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PD3;
   PSSI_D6    : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PE5;
   PSSI_D7    : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PE6;
   PSSI_D8    : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PC10;
   PSSI_D9    : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PC12;
   PSSI_D10   : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PD6;
   PSSI_D11   : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PD2;
   PSSI_D12   : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PF11;
   PSSI_D13   : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PD13;
   PSSI_D14   : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PA5;
   PSSI_D15   : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PC5;
   PSSI_DE    : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PA4;
   PSSI_PDCK  : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PA6;
   PSSI_RDY   : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PB7;

   procedure Configure_PSSI;

   procedure Configure_LPTIM4;

   procedure Configure_DMA;

   procedure Configure_GPIO_PSSI;

   procedure Configure_GPIO_LPTIM4;

   procedure Set_Waveform
     (ARR : A0B.Types.Unsigned_16;
      CMP : A0B.Types.Unsigned_16);

   procedure DMA1_Stream0_Handler
     with Export, Convention => C, External_Name => "DMA1_Stream0_Handler";

   procedure DCMI_PSSI_Handler
     with Export, Convention => C, External_Name => "DCMI_PSSI_Handler";

   -------------------
   -- Configure_DMA --
   -------------------

   procedure Configure_DMA is
   begin
      --  "2.Set the peripheral port register address in the DMA_SxPAR
      --  register. The data is moved from/ to this address to/ from the
      --  peripheral port after the peripheral event.
      --
      --  3.Set the memory address in the DMA_SxMA0R register (and in the
      --  DMA_SxMA1R register in the case of a double-buffer mode). The data
      --  is written to or read from this memory after the peripheral event.
      --
      --  4.Configure the total number of data items to be transferred in the
      --  DMA_SxNDTR register. After each peripheral event or each beat of the
      --  burst, this value is decremented."

      DMA1_Periph.S0PAR  := 16#4802_0428#;
      DMA1_Periph.S0M0AR := 16#3000_0000#;
      --  DMA1_Periph.S0M1AR := 16#3000_4000#;
      --  DMA1_Periph.S0NDTR.NDT is configured later, before the transfer.

      --  "5.Use DMAMUX1 to route a DMA request line to the DMA channel."

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
      DMAMUX1_Periph.DMAMUX_RG0CR :=
        (others => <>);

      --  "6.If the peripheral is intended to be the flow controller and if it
      --  supports this feature, set the PFCTRL bit in the DMA_SxCR register.
      --
      --  7.Configure the stream priority using the PL[1:0] bits in the
      --  DMA_SxCR register.
      --
      --  8.Configure the FIFO usage (enable or disable, threshold in
      --  transmission and reception).
      --
      --  9. Configure the data transfer direction, peripheral and memory
      --  incremented/fixed mode, single or burst transactions, peripheral and
      --  memory data widths, circular mode, double-buffer mode and interrupts
      --  after half and/or full transfer, and/or errors in the DMA_SxCR
      --  register."

      DMA1_Periph.S0CR :=
        (EN             => False,  --  stream disabled
         DMEIE          => False,  --  DME interrupt disabled
         TEIE           => True,   --  TE interrupt enabled
         HTIE           => False,  --  HT interrupt disabled
         TCIE           => True,   --  TC interrupt enabled
         PFCTRL         => False,  --  DMA is the flow controller.
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

      DMA1_Periph.S0FCR :=
        (FTH    => 2#10#,  --  3/4 full FIFO
         DMDIS  => False,  --  direct mode disabled
         FS     => <>,     --  These bits are read-only.
         FEIE   => True,   --  FE interrupt enabled
         others => <>);

      --  "10. Activate the stream by setting the EN bit in the DMA_SxCR
      --  register."
      --
      --  DMA Stream will be enabled later, before start of the transfer.
   end Configure_DMA;

   ---------------------------
   -- Configure_GPIO_LPTIM4 --
   ---------------------------

   procedure Configure_GPIO_LPTIM4 is
   begin
      LPTIM4_OUT.Configure_Alternative_Function
        (A0B.STM32H723.LPTIM4_OUT,
         Speed => A0B.STM32H723.GPIO.Very_High,
         Pull  => A0B.STM32H723.GPIO.Pull_Up);
   end Configure_GPIO_LPTIM4;

   -------------------------
   -- Configure_GPIO_PSSI --
   -------------------------

   procedure Configure_GPIO_PSSI is
   begin
      PSSI_D0.Configure_Alternative_Function
        (A0B.STM32H723.PSSI_D0,
         Speed => A0B.STM32H723.GPIO.Very_High,
         Pull  => A0B.STM32H723.GPIO.Pull_Up);
      PSSI_D1.Configure_Alternative_Function
        (A0B.STM32H723.PSSI_D1,
         Speed => A0B.STM32H723.GPIO.Very_High,
         Pull  => A0B.STM32H723.GPIO.Pull_Up);
      PSSI_D2.Configure_Alternative_Function
        (A0B.STM32H723.PSSI_D2,
         Speed => A0B.STM32H723.GPIO.Very_High,
         Pull  => A0B.STM32H723.GPIO.Pull_Up);
      PSSI_D3.Configure_Alternative_Function
        (A0B.STM32H723.PSSI_D3,
         Speed => A0B.STM32H723.GPIO.Very_High,
         Pull  => A0B.STM32H723.GPIO.Pull_Up);
      PSSI_D4.Configure_Alternative_Function
        (A0B.STM32H723.PSSI_D4,
         Speed => A0B.STM32H723.GPIO.Very_High,
         Pull  => A0B.STM32H723.GPIO.Pull_Up);
      PSSI_D5.Configure_Alternative_Function
        (A0B.STM32H723.PSSI_D5,
         Speed => A0B.STM32H723.GPIO.Very_High,
         Pull  => A0B.STM32H723.GPIO.Pull_Up);
      PSSI_D6.Configure_Alternative_Function
        (A0B.STM32H723.PSSI_D6,
         Speed => A0B.STM32H723.GPIO.Very_High,
         Pull  => A0B.STM32H723.GPIO.Pull_Up);
      PSSI_D7.Configure_Alternative_Function
        (A0B.STM32H723.PSSI_D7,
         Speed => A0B.STM32H723.GPIO.Very_High,
         Pull  => A0B.STM32H723.GPIO.Pull_Up);
      PSSI_D8.Configure_Alternative_Function
        (A0B.STM32H723.PSSI_D8,
         Speed => A0B.STM32H723.GPIO.Very_High,
         Pull  => A0B.STM32H723.GPIO.Pull_Up);
      PSSI_D9.Configure_Alternative_Function
        (A0B.STM32H723.PSSI_D9,
         Speed => A0B.STM32H723.GPIO.Very_High,
         Pull  => A0B.STM32H723.GPIO.Pull_Up);
      PSSI_D10.Configure_Alternative_Function
        (A0B.STM32H723.PSSI_D10,
         Speed => A0B.STM32H723.GPIO.Very_High,
         Pull  => A0B.STM32H723.GPIO.Pull_Up);
      PSSI_D11.Configure_Alternative_Function
        (A0B.STM32H723.PSSI_D11,
         Speed => A0B.STM32H723.GPIO.Very_High,
         Pull  => A0B.STM32H723.GPIO.Pull_Up);
      PSSI_D12.Configure_Alternative_Function
        (A0B.STM32H723.PSSI_D12,
         Speed => A0B.STM32H723.GPIO.Very_High,
         Pull  => A0B.STM32H723.GPIO.Pull_Up);
      PSSI_D13.Configure_Alternative_Function
        (A0B.STM32H723.PSSI_D13,
         Speed => A0B.STM32H723.GPIO.Very_High,
         Pull  => A0B.STM32H723.GPIO.Pull_Up);
      PSSI_D14.Configure_Alternative_Function
        (A0B.STM32H723.PSSI_D14,
         Speed => A0B.STM32H723.GPIO.Very_High,
         Pull  => A0B.STM32H723.GPIO.Pull_Up);
      PSSI_D15.Configure_Alternative_Function
        (A0B.STM32H723.PSSI_D15,
         Speed => A0B.STM32H723.GPIO.Very_High,
         Pull  => A0B.STM32H723.GPIO.Pull_Up);
      PSSI_DE.Configure_Alternative_Function
        (A0B.STM32H723.PSSI_DE,
         Speed => A0B.STM32H723.GPIO.Very_High,
         Pull  => A0B.STM32H723.GPIO.Pull_Up);
      PSSI_PDCK.Configure_Alternative_Function
        (A0B.STM32H723.PSSI_PDCK,
         Speed => A0B.STM32H723.GPIO.Very_High,
         Pull  => A0B.STM32H723.GPIO.Pull_Up);
      PSSI_RDY.Configure_Alternative_Function
        (A0B.STM32H723.PSSI_RDY,
         Speed => A0B.STM32H723.GPIO.Very_High,
         Pull  => A0B.STM32H723.GPIO.Pull_Up);
   end Configure_GPIO_PSSI;

   ----------------------
   -- Configure_LPTIM4 --
   ----------------------

   procedure Configure_LPTIM4 is
   begin
      --  Clock selection is done in System_Clocks.

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
         --  PRESC     => 2#111#,  --  /128  ??? for debug !!!
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

      --  LPTIM4_Periph.CR.ENABLE := True;
      --  --  Enable timer to be able to continue configuration.
   end Configure_LPTIM4;

   --------------------
   -- Configure_PSSI --
   --------------------

   procedure Configure_PSSI is
   begin
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

      PSSI_Periph.PSSI_IER :=
        (OVR_IE => B_0x1,
         --  An interrupt is generated if either an overrun or an underrun
         --  error occurred.
         others => <>);
   end Configure_PSSI;

   -----------------------
   -- DCMI_PSSI_Handler --
   -----------------------

   procedure DCMI_PSSI_Handler is
   begin
      PSSI_Periph.PSSI_ICR.OVR_ISC := True;

      raise Program_Error;
   end DCMI_PSSI_Handler;

   --------------------------
   -- DMA1_Stream0_Handler --
   --------------------------

   procedure DMA1_Stream0_Handler is
      Status : constant LISR_Register := DMA1_Periph.LISR;
      --  Mask   : constant S0CR_Register := DMA1_Periph.S0CR;
      Aux    : A0B.Types.Unsigned_32 with Unreferenced;

   begin
      if Status.TCIF0 then
         --  Stream 0 transfer complete interrupt flag

         DMA1_Periph.LIFCR := (CTCIF0 => True, others => <>);

         --  Disable LPTIM to stop clock signal generation, disable DMA stream
         --  to be able to disable PSSI, disable PSSI to flush FIFO.

         LPTIM4_Periph.CR.ENABLE    := False;
         DMA1_Periph.S0CR.EN        := False;
         PSSI_Periph.PSSI_CR.ENABLE := B_0x0;

         Done := True;
      end if;

      if Status.TEIF0 then
         --  Stream 0 transfer error interrupt flag

         DMA1_Periph.LIFCR := (CTEIF0 => True, others => <>);

         raise Program_Error;
      end if;

      if Status.FEIF0 then
         --  Stream 0 FIFO error interrupt flag

         DMA1_Periph.LIFCR := (CFEIF0 => True, others => <>);

         raise Program_Error;
      end if;
   end DMA1_Stream0_Handler;

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

      A0B.ARMv7M.NVIC_Utilities.Clear_Pending (A0B.STM32H723.DMA1_STR0);
      A0B.ARMv7M.NVIC_Utilities.Enable_Interrupt (A0B.STM32H723.DMA1_STR0);

      A0B.ARMv7M.NVIC_Utilities.Clear_Pending (A0B.STM32H723.DCMI_PSSI);
      A0B.ARMv7M.NVIC_Utilities.Enable_Interrupt (A0B.STM32H723.DCMI_PSSI);
   end Initialize;

   ---------
   -- Run --
   ---------

   procedure Run is
   begin
      Done := False;

      if LPTIM4_Periph.CR.ENABLE then
         raise Program_Error;
      end if;

      if DMA1_Periph.S0CR.EN then
         raise Program_Error;
      end if;

      Set_Waveform (20, 10);
      --  10_000/5_000   10 kHz, 50/50
      --  100/50         1 MHz, 50/50
      --  20/10          5 MHz, 50/50

      --  Clear PSSI interrupt state

      PSSI_Periph.PSSI_ICR := (OVR_ISC => True, others => <>);

      --  Reset DMA stream DMAMUX channel states.

      DMA1_Periph.LIFCR :=
        (CFEIF0  => True,
         CDMEIF0 => True,
         CTEIF0  => True,
         CHTIF0  => True,
         CTCIF0  => True,
         others  => <>);
      DMAMUX1_Periph.DMAMUX_CFR :=
        (CSOF   => (As_Array => True, Arr => [0 => True, others => <>]),
         others => <>);

      --  Reconfigure DMA stream to receive data and enable it.

      DMA1_Periph.S0NDTR.NDT := 4_096;
      DMA1_Periph.S0CR.EN := True;

      --  Enable PSSI

      PSSI_Periph.PSSI_CR.ENABLE := B_0x1;

      --  Enable and start timer

      LPTIM4_Periph.CR.COUNTRST := True;
      LPTIM4_Periph.CR.CNTSTRT  := True;
   end Run;

   ------------------
   -- Set_Waveform --
   ------------------

   procedure Set_Waveform
     (ARR : A0B.Types.Unsigned_16;
      CMP : A0B.Types.Unsigned_16) is
   begin
      pragma Assert (not LPTIM4_Periph.CR.ENABLE);

      LPTIM4_Periph.CR.ENABLE := True;
      --  Enable LPTIM to ba able to set ARR and CMP registers

      LPTIM4_Periph.ICR := (ARROKCF | CMPOKCF => True, others => <>);

      LPTIM4_Periph.ARR.ARR := ARR;

      while not LPTIM4_Periph.ISR.ARROK loop
         null;
      end loop;

      LPTIM4_Periph.CMP.CMP := CMP;

      while not LPTIM4_Periph.ISR.CMPOK loop
         null;
      end loop;

      LPTIM4_Periph.ICR := (ARROKCF | CMPOKCF => True, others => <>);
      LPTIM4_Periph.ICR := (ARRMCF | CMPMCF => True, others => <>);
   end Set_Waveform;

end LADO.Acquisition;
