--
--  Copyright (C) 2024, Vadim Godunko <vgodunko@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

--  Configure all components of system clock, including PLL, clock sources for
--  each peripheral, etc.

package LADO.System_Clocks
  with Preelaborate
is

   procedure Initialize;

end LADO.System_Clocks;
