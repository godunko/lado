--
--  Copyright (C) 2024, Vadim Godunko <vgodunko@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

with A0B.STM32H723.SVD.RCC; use A0B.STM32H723.SVD.RCC;

package body LADO.System_Clocks is

   DIVM2   : constant := 5;
   MULN2   : constant := 120 - 1;
   DIVP2   : constant := 6 - 1;
   DIVR2   : constant := 5 - 1;
   PLL2GRE : constant := 2#10#;
   --  The PLL2 input (ref2_ck) clock range frequency is between 4 and 8 MHz

   procedure Configure_PLL2;
   --  Configure PLL2R @120MHz to be used as clock of the FMC.
   --  Configure PLL2P @100MHz to be used as clock of the LPTIM5.

   --------------------
   -- Configure_PLL2 --
   --------------------

   procedure Configure_PLL2 is
      --  This configuration should be synchronized somehow with startup code.
      --  It assumes use of HSE @25MHz to drive PLLs.

   begin
      --  Disable PLL2.

      RCC_Periph.CR.PLL2ON := False;

      --  Wait till PLL is disabled.

      while RCC_Periph.CR.PLL2RDY loop
         null;
      end loop;

      --  Configure PLL2.

      declare
         Aux : PLLCKSELR_Register := RCC_Periph.PLLCKSELR;

      begin
         Aux.DIVM2 := DIVM2;

         RCC_Periph.PLLCKSELR := Aux;
      end;

      declare
         Aux : PLL2DIVR_Register := RCC_Periph.PLL2DIVR;

      begin
         Aux.DIVN1  := MULN2;
         Aux.DIVP1  := DIVP2;
         Aux.DIVQ1  := 0;
         Aux.DIVR1  := DIVR2;

         RCC_Periph.PLL2DIVR := Aux;
      end;

      declare
         Aux : PLLCFGR_Register := RCC_Periph.PLLCFGR;

      begin
         Aux.PLL2FRACEN := False;
         Aux.PLL2VCOSEL := False;
         Aux.PLL2RGE    := PLL2GRE;
         Aux.DIVP2EN    := True;
         Aux.DIVQ2EN    := False;
         Aux.DIVR2EN    := True;

         RCC_Periph.PLLCFGR := Aux;
      end;

      RCC_Periph.PLL2FRACR.FRACN2 := 0;

      --  Enable the PLL.

      RCC_Periph.CR.PLL2ON := True;

      --  Wait till PLL is enabled.

      while not RCC_Periph.CR.PLL2RDY loop
         null;
      end loop;
   end Configure_PLL2;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize is
   begin
      Configure_PLL2;

      --  Select source of clocks of peripheral controllers

      RCC_Periph.D1CCIPR.FMCSEL := 2#10#;        --  FMC:        PLL2R
      RCC_Periph.D3CCIPR.LPTIM345SEL := 2#001#;  --  LPTIM3/4/5: PLL2P
      RCC_Periph.D3CCIPR.SPI6SEL := 2#000#;      --  SPI6:       PCLK4

      --  Enable clocks of used pirepheral controllers

      RCC_Periph.AHB1ENR.DMA1EN := True;

      RCC_Periph.AHB2ENR.DCMI_PSSIEN := True;

      RCC_Periph.AHB3ENR.FMCEN := True;

      RCC_Periph.AHB4ENR.GPIOAEN := True;
      RCC_Periph.AHB4ENR.GPIOBEN := True;
      RCC_Periph.AHB4ENR.GPIOCEN := True;
      RCC_Periph.AHB4ENR.GPIODEN := True;
      RCC_Periph.AHB4ENR.GPIOEEN := True;
      RCC_Periph.AHB4ENR.GPIOFEN := True;
      RCC_Periph.AHB4ENR.GPIOGEN := True;

      RCC_Periph.APB4ENR.LPTIM4EN := True;
      RCC_Periph.APB4ENR.SPI6EN   := True;
   end Initialize;

end LADO.System_Clocks;
