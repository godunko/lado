--
--  Copyright (C) 2024, Vadim Godunko <vgodunko@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

--  XPT2046 touch screen sensor support

with A0B.Types;

package LADO.Touch
  with Preelaborate
is

   procedure Initialize;

   type Touch_State is record
      X          : A0B.Types.Integer_32;
      Y          : A0B.Types.Integer_32;
      Is_Touched : Boolean;
   end record;

   procedure Get (State : out Touch_State);

end LADO.Touch;
