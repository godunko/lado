--
--  Copyright (C) 2024, Vadim Godunko <vgodunko@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

with A0B.ARMv7M.SysTick;

with LADO.Acquisition;
with LADO.Display;
with LADO.System_Clocks;
with LADO.Touch;
with LADO.UI;

procedure LADO.Main is
begin
   LADO.System_Clocks.Initialize;

   A0B.ARMv7M.SysTick.Initialize (True, 520_000_000);

   LADO.Acquisition.Initialize;
   LADO.Display.Initialize;
   LADO.Touch.Initialize;
   LADO.UI.Initialize;

   LADO.UI.Run;
end LADO.Main;
