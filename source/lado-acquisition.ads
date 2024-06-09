--
--  Copyright (C) 2024, Vadim Godunko <vgodunko@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

with System.Storage_Elements;

with A0B.Types;

package LADO.Acquisition
  with Preelaborate
is

   procedure Initialize;

   procedure Run;

   type Unsigned_16_Array is
     array (A0B.Types.Unsigned_32 range <>) of A0B.Types.Unsigned_16
       with Pack;

   Buffer : Unsigned_16_Array (0 .. 8191)
     with Address => System.Storage_Elements.To_Address (16#3000_0000#),
          Volatile;

end LADO.Acquisition;
