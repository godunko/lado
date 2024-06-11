--
--  Copyright (C) 2024, Vadim Godunko <vgodunko@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

pragma Ada_2022;

with A0B.STM32H723.SVD.GPIO; use A0B.STM32H723.SVD.GPIO;
with A0B.STM32H723.SVD.SPI;  use A0B.STM32H723.SVD.SPI;

package body LADO.Touch is

   type Unsigned_8_Array is
     array (A0B.Types.Unsigned_32 range <>) of A0B.Types.Unsigned_8;

   Measure_CMD : constant Unsigned_8_Array (0 .. 5) :=
     [16#D3#, 16#00#, 16#00#,   --  Differential X
      16#93#, 16#00#, 16#00#];  --  Differential Y

   Done_CMD    : constant Unsigned_8_Array (0 .. 2) :=
     [16#D0#, 16#00#, 16#00#];  --  Dummy differential X and shutdown

--     CMD : constant Unsigned_8_Array (0 .. 11) :=
--       --  (16#B5#, 16#00#, 16#00#,
--       --   16#C5#, 16#00#, 16#00#,
--       --   16#D5#, 16#00#, 16#00#,
--       --   16#94#, 16#00#, 16#00#);
--       (16#B3#, 16#00#, 16#00#,
--        16#C3#, 16#00#, 16#00#,
   Measure_DAT : Unsigned_8_Array (0 .. 5) with Volatile;

   Debonce_Counter : Natural := 0;

   --------------------
   -- Configure_GPIO --
   --------------------

   procedure Configure_GPIO is

      subtype Low_Line is Integer range 0 .. 7;
      subtype High_Line is Integer range 8 .. 15;

      -----------------
      -- Configure_H --
      -----------------

      procedure Configure_H
        (Peripheral  : in out GPIO_Peripheral;
         Line        : High_Line;
         Alternative : AFRH_AFSEL_Element) is
      begin
         Peripheral.OSPEEDR.Arr (Line) := 2#00#;      --  Low high speed
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
         Peripheral.OSPEEDR.Arr (Line) := 2#00#;      --  Low high speed
         Peripheral.OTYPER.OT.Arr (Line) := False;    --  Output push-pull
         Peripheral.PUPDR.Arr (Line) := 2#01#;        --  Pullup
         Peripheral.AFRL.Arr (Line) := Alternative;   --  Alternate function
         Peripheral.MODER.Arr (Line) := 2#10#;        --  Alternate function
      end Configure_L;

   begin
      --  PG12 -> SPI6_MISO
      Configure_H (GPIOG_Periph, 12, 5);
      --  PA7  -> SPI6_MOSI
      Configure_L (GPIOA_Periph, 7, 8);
      --  PG13 -> SPI6_SCK
      Configure_H (GPIOG_Periph, 13, 5);
      --  PA0  -> SPI6_NSS
      Configure_L (GPIOC_Periph, 0, 5);

      --  PENIRQ/A12

      --  GPIOA_Periph.OSPEEDR.Arr (12) := 2#00#;      --  Low high speed
      --  GPIOA_Periph.OTYPER.OT.Arr (Line) := False;    --  Output push-pull
      --  GPIOA_Periph.AFRH.Arr (Line) := Alternative;   --  Alternate function
      GPIOA_Periph.MODER.Arr (12) := 2#00#;        --  Input mode
      GPIOA_Periph.PUPDR.Arr (12) := 2#01#;        --  Pullup
   end Configure_GPIO;

   -------------------
   -- Configure_SPI --
   -------------------

   procedure Configure_SPI is
   begin
      --  SPI6 peripheral clock is set to PCLK4 and enabled in System_Clocks.

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
         MBR     => 2#101#,  --  SPI master clock/64
         others  => <>);
      SPI6_Periph.CFG2 :=
        (MSSI    => 0,       --  (+1)
         MIDI    => 15,
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

      --------------
      -- Is_Valid --
      --------------

      function Is_Valid (B1, B2, B3 : A0B.Types.Unsigned_8) return Boolean is
         use type A0B.Types.Unsigned_8;

      begin
         return
           B1 = 2#0000_0000#
           and (B2 and 2#1000_0000#) = 2#0000_0000#
           and (B3 and 2#1111_1000#) = 2#0000_0000#;
      end Is_Valid;

      TXDR : A0B.Types.Unsigned_8
        with Import, Address => SPI6_Periph.TXDR'Address;
      RXDR : A0B.Types.Unsigned_8
        with Import, Address => SPI6_Periph.RXDR'Address;

      X_Previous : A0B.Types.Unsigned_12 := 0;
      X_Current  : A0B.Types.Unsigned_12;
      Y_Previous : A0B.Types.Unsigned_12 := 0;
      Y_Current  : A0B.Types.Unsigned_12;

   begin
      State.Is_Touched := False;
      --  State.Is_Touched := not GPIOA_Periph.IDR.ID.Arr (12);
      State.X          := 0;
      State.Y          := 0;

      if not GPIOA_Periph.IDR.ID.Arr (12) then
         Debonce_Counter := @ + 1;

      else
         Debonce_Counter := 0;
      end if;

      if Debonce_Counter > 2 then
         State.Is_Touched := True;

      --  if State.Is_Touched then
         SPI6_Periph.CR1.SPE := True;
         SPI6_Periph.CR1.CSTART := True;

         --  Read sensor till two consequentive measures are equal.

         loop
            loop
               for J in Measure_CMD'Range loop
                  TXDR := Measure_CMD (J);

                  while not SPI6_Periph.SR.RXP loop
                     null;
                  end loop;

                  Measure_DAT (J) := RXDR;
               end loop;

               exit when
                 Is_Valid (Measure_DAT (0), Measure_DAT (1), Measure_DAT (2))
                   and Is_Valid (Measure_DAT (3), Measure_DAT (4), Measure_DAT (5));
            end loop;

            X_Current := Convert (Measure_DAT (1), Measure_DAT (2));
            Y_Current := Convert (Measure_DAT (4), Measure_DAT (5));

            exit when X_Current = X_Previous and Y_Current = Y_Previous
              and X_Current /= 0 and Y_Current /= 0;
            exit when not State.Is_Touched
              and X_Current /= 0 and Y_Current /= 0;

            X_Previous := X_Current;
            Y_Previous := Y_Current;
         end loop;

         --  Send "shutdown" command and enable interrupt

         loop
            for J in Done_CMD'Range loop
               TXDR := Done_CMD (J);

               while not SPI6_Periph.SR.RXP loop
                  null;
               end loop;

               Measure_DAT (J) := RXDR;
            end loop;

            exit when
              Is_Valid (Measure_DAT (0), Measure_DAT (1), Measure_DAT (2));
         end loop;

         SPI6_Periph.CR1.SPE := False;

         if GPIOA_Periph.IDR.ID.Arr (12) then
            State.Is_Touched := False;
            X_Current := 0;
            Y_Current := 0;
         end if;

         --  Convert result

         State.X := (4095 - A0B.Types.Integer_32 (Y_Current)) * 800 / 4096;
         State.Y := (4095 - A0B.Types.Integer_32 (X_Current)) * 480 / 4096;

   --        if DAT (0) = 16#00#
   --          and DAT (3) = 16#00#
   --          and DAT (6) = 16#00#
   --          and DAT (9) = 16#00#
   --        then
   --           VAL.Z1 := Convert (DAT (1), DAT (2));
   --           VAL.Z2 := Convert (DAT (4), DAT (5));
   --           VAL.X  := Convert (DAT (7), DAT (8));
   --           VAL.Y  := Convert (DAT (10), DAT (11));
   --        end if;
      end if;
   end Get;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize is
      TXDR : A0B.Types.Unsigned_8
        with Import, Address => SPI6_Periph.TXDR'Address;
      RXDR : A0B.Types.Unsigned_8
        with Import, Address => SPI6_Periph.RXDR'Address;

   begin
      Configure_SPI;
      Configure_GPIO;

      SPI6_Periph.CR1.SPE := True;
      SPI6_Periph.CR1.CSTART := True;

      --  Send "shutdown" command and enable interrupt

      for J in Done_CMD'Range loop
         TXDR := Done_CMD (J);

         while not SPI6_Periph.SR.RXP loop
            null;
         end loop;

         Measure_DAT (J) := RXDR;
      end loop;

      SPI6_Periph.CR1.SPE := False;

   end Initialize;

   --  ---------------
   --  -- Get_Touch --
   --  ---------------
   --
   --  procedure Get_Touch is
   --
   --     use type A0B.Types.Unsigned_8;
   --
   --  begin
   --  end Get_Touch;
   --
   --  ----------------
   --  -- Initialize --
   --  ----------------
   --
   --  procedure Initialize is
   --  begin
   --
   --     Get_Touch;
   --  end Initialize;
   --
   --  ----------------
   --  -- Is_Touched --
   --  ----------------
   --
   --  function Is_Touched return Boolean is
   --  begin
   --     return not GPIOA_Periph.IDR.ID.Arr (12);
   --  end Is_Touched;
   --

end LADO.Touch;
