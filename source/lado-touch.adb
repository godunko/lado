--
--  Copyright (C) 2024, Vadim Godunko <vgodunko@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

pragma Ada_2022;

with A0B.STM32H723.GPIO;
with A0B.STM32H723.SVD.SPI;  use A0B.STM32H723.SVD.SPI;

package body LADO.Touch is

   MISO   : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PG12;
   MOSI   : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PA7;
   SCK    : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PG13;
   NSS    : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PA0;

   PENIRQ : A0B.STM32H723.GPIO.GPIO_Line renames A0B.STM32H723.GPIO.PA12;

   type Unsigned_8_Array is
     array (A0B.Types.Unsigned_32 range <>) of A0B.Types.Unsigned_8;

   Power_Up_CMD    : constant Unsigned_8_Array (0 .. 2) :=
     [2#1101_0011#, 16#00#, 16#00#];  --  Power up, PENIRQ disable
   Measure_XY_CMD  : constant Unsigned_8_Array (0 .. 5) :=
     [2#1101_0011#, 16#00#, 16#00#,   --  X, 12bit, differential
      2#1001_0011#, 16#00#, 16#00#];  --  Y, 12bit, differential
   Measure_Z12_CMD : constant Unsigned_8_Array (0 .. 5) :=
     [2#1011_0011#, 16#00#, 16#00#,   --  Z1, 12bit, differential
      2#1100_0011#, 16#00#, 16#00#];  --  Z2, 12bit, differential
   Power_Done_CMD : constant Unsigned_8_Array (0 .. 2) :=
     [2#1101_0000#, 16#00#, 16#00#];  --  Power done, PENIRQ enable

   Measure_DAT    : Unsigned_8_Array (0 .. 5) with Volatile;

   --------------------
   -- Configure_GPIO --
   --------------------

   procedure Configure_GPIO is
   begin
      MISO.Configure_Alternative_Function
        (A0B.STM32H723.SPI6_MISO, Pull => A0B.STM32H723.GPIO.Pull_Up);
      MOSI.Configure_Alternative_Function
        (A0B.STM32H723.SPI6_MOSI, Pull => A0B.STM32H723.GPIO.Pull_Up);
      SCK.Configure_Alternative_Function
        (A0B.STM32H723.SPI6_SCK, Pull => A0B.STM32H723.GPIO.Pull_Up);
      NSS.Configure_Alternative_Function
        (A0B.STM32H723.SPI6_NSS, Pull => A0B.STM32H723.GPIO.Pull_Up);

      --  PENIRQ/A12

      PENIRQ.Configure_Input (A0B.STM32H723.GPIO.Pull_Up);
   end Configure_GPIO;

   -------------------
   -- Configure_SPI --
   -------------------

   procedure Configure_SPI is
   begin
      --  SPI6 peripheral clock is set to PCLK4 and enabled in System_Clocks.
      --  It runs @130MHz, XPT2046 minimum acquisition time is 1.5
      --  microseconds and it is done during 3 clock cycles. Use of 128 as
      --  divider provides 2.954 microseconds for acquisition; use of 64
      --  as divider provides 1.477 microseconds, which is a bit less than
      --  required.

      SPI6_Periph.CR1.SPE := False;
      --  Disable to be able to configure

      SPI6_Periph.CFG1 :=
        (DSIZE   => 7,       --  8 bits in frame, for experiment only
         FTHVL   => 0,       --  FIFO threshold level: 1-data
         UDRCFG  => <>,      --  if slave
         UDRDET  => <>,      --  if slave
         RXDMAEN => False,   --  Rx-DMA disabled
         TXDMAEN => False,   --  Tx DMA disabled
         CRCSIZE => <>,      --  if CRCEN
         CRCEN   => False,   --  CRC calculation disabled
         MBR     => 2#110#,  --  SPI master clock/128
         others  => <>);
      SPI6_Periph.CFG2 :=
        (MSSI    => 0,       --  (+1)
         MIDI    => 0,
         IOSWP   => False,   --  no swap
         COMM    => 2#00#,   --  full-duplex
         SP      => 2#000#,  --  SPI Motorola
         MASTER  => True,    --  SPI Master
         LSBFRST => False,   --  MSB transmitted first
         CPHA    => False,
         --  the first clock transition is the first data capture edge
         CPOL    => False,   --  SCK signal is at 0 when idle
         SSM     => False,   --  SS input value is determined by the SS PAD
         SSIOP   => False,   --  Low level is active for SS signal
         SSOE    => True,    --  SS output is enabled.
         SSOM    => False,
         --  SS is kept at active level till data transfer is completed, it
         --  becomes inactive with EOT flag
         AFCNTR  => True,
         --  The peripheral keeps always control of all associated GPIOs
         others  => <>);
      SPI6_Periph.I2SCFGR.I2SMOD := False;

      --  SPI6_Periph.CR2 :=
      --    (TSIZE : CR2_TSIZE_Field,
      --     TSER : CR2_TSER_Field);
      SPI6_Periph.CR1 :=
        (SPE      => False,  --  serial peripheral disabled
         MASRX    => True,
         --  SPI flow is suspended temporary on RxFIFO full condition, before
         --  reaching overrun condition.
         CSTART   => False,
         CSUSP    => False,
         HDDIR    => <>,     --  if half-duplex
         SSI      => <>,     --  if SSM
         CRC33_17 => <>,     --  if CRCEN
         RCRCI    => <>,     --  if CRCEN
         TCRCI    => <>,     --  if CRCEN
         IOLOCK   => False,  --  AF configuration is not locked
         others   => <>);
   end Configure_SPI;

   --------------
   -- Transfer --
   --------------

   procedure Transfer (Command : Unsigned_8_Array) is
      TXDR : A0B.Types.Unsigned_8
        with Import, Address => SPI6_Periph.TXDR'Address;
      RXDR : A0B.Types.Unsigned_8
        with Import, Address => SPI6_Periph.RXDR'Address;

   begin
      for J in Command'Range loop
         TXDR := Command (J);

         while not SPI6_Periph.SR.RXP loop
            null;
         end loop;

         Measure_DAT (J) := RXDR;
      end loop;
   end Transfer;

   ---------
   -- Get --
   ---------

   procedure Get (State : out Touch_State) is

      use type A0B.Types.Integer_32;
      use type A0B.Types.Unsigned_12;

      -------------
      -- Convert --
      -------------

      function Convert
        (B2, B3 : A0B.Types.Unsigned_8) return A0B.Types.Unsigned_12
      is
         use type A0B.Types.Unsigned_16;

      begin
         return
           A0B.Types.Unsigned_12
             ((A0B.Types.Shift_Left (A0B.Types.Unsigned_16 (B2), 5)
              or A0B.Types.Shift_Right (A0B.Types.Unsigned_16 (B3), 3))
              and 16#FFF#);
      end Convert;

      X_Previous : A0B.Types.Unsigned_12 := 0;
      X_Current  : A0B.Types.Unsigned_12;
      Y_Previous : A0B.Types.Unsigned_12 := 0;
      Y_Current  : A0B.Types.Unsigned_12;
      Z1         : A0B.Types.Unsigned_12;
      Z2         : A0B.Types.Unsigned_12;

   begin
      State.Is_Touched := not PENIRQ.Get;
      State.X          := 0;
      State.Y          := 0;

      if State.Is_Touched then
         SPI6_Periph.CR1.SPE := True;
         SPI6_Periph.CR1.CSTART := True;

         --  Power up. It is recommended to do on high transfer speed to let
         --  power to stabilize.

         Transfer (Power_Up_CMD);

         --  Read sensor till two consequentive measures are equal.

         loop
            Transfer (Measure_XY_CMD);

            X_Current := Convert (Measure_DAT (1), Measure_DAT (2));
            Y_Current := Convert (Measure_DAT (4), Measure_DAT (5));

            exit when X_Current = X_Previous and Y_Current = Y_Previous;

            X_Previous := X_Current;
            Y_Previous := Y_Current;
         end loop;

         --  Read Z1/Z2 to check touch state. PENIRQ can't used here, it is
         --  disabled.

         Transfer (Measure_Z12_CMD);
         Z1 := Convert (Measure_DAT (1), Measure_DAT (2));
         Z2 := Convert (Measure_DAT (4), Measure_DAT (5));

         if (Z2 - Z1) > 3_000 then
            State.Is_Touched := False;
            X_Current := 4_095;
            Y_Current := 4_095;
         end if;

         --  Send power done command and enable PENIRQ

         Transfer (Power_Done_CMD);

         --  Disable SPI controller

         SPI6_Periph.CR1.SPE := False;

         --  Convert result

         State.X := (4095 - A0B.Types.Integer_32 (Y_Current)) * 800 / 4096;
         State.Y := (4095 - A0B.Types.Integer_32 (X_Current)) * 480 / 4096;
      end if;
   end Get;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize is
   begin
      Configure_SPI;
      Configure_GPIO;

      SPI6_Periph.CR1.SPE := True;
      SPI6_Periph.CR1.CSTART := True;

      --  Send "shutdown" command and enable interrupt

      Transfer (Power_Done_CMD);

      SPI6_Periph.CR1.SPE := False;
   end Initialize;

end LADO.Touch;
