--
--  Copyright (C) 2024, Vadim Godunko <vgodunko@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

pragma Ada_2022;

with System.Storage_Elements;

with A0B.ARMv7M.Cache_Utilities;
--  with A0B.Delays;
--  with A0B.Time;
with A0B.Types;

with LADO.Acquisition;
with LADO.Painter;

package body LADO.UI is

   procedure PendSV_Handler is null
     with Export, Convention => C, External_Name => "PendSV_Handler";

   procedure Draw_Line
     (Y     : A0B.Types.Integer_32;
      Mask  : A0B.Types.Unsigned_16;
      First : A0B.Types.Unsigned_32);

   ---------------
   -- Draw_Line --
   ---------------

   procedure Draw_Line
     (Y     : A0B.Types.Integer_32;
      Mask  : A0B.Types.Unsigned_16;
      First : A0B.Types.Unsigned_32)
   is
      use type A0B.Types.Integer_32;
      use type A0B.Types.Unsigned_16;
      use type A0B.Types.Unsigned_32;

      Y_Current : A0B.Types.Integer_32  := Y;
      Current   : A0B.Types.Unsigned_32 := First;

   begin
      Painter.Set_Color (16#03C0#);

      for X in A0B.Types.Integer_32 (0) .. A0B.Types.Integer_32 (799) loop
         Y_Current :=
           Y
             + (if (LADO.Acquisition.Buffer (Current) and Mask) = 0
                  then 20 else 0);

         Painter.Fill_Rect (X, Y_Current, 1, 1);

         Current := @ + 1;
      end loop;
   end Draw_Line;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize is
   begin
      null;
   end Initialize;

   ---------
   -- Run --
   ---------

   Cycles : Natural := 0 with Volatile;

   procedure Run is
      use type System.Storage_Elements.Storage_Count;
      use type A0B.Types.Unsigned_32;

      First : A0B.Types.Unsigned_32;

   begin
      Acquisition :
      loop
         LADO.Acquisition.Buffer := [others => 16#0001#];
         A0B.ARMv7M.Cache_Utilities.Clean_Invalidate_DCache
           (LADO.Acquisition.Buffer'Address,
            LADO.Acquisition.Buffer'Length * 2);

         LADO.Acquisition.Run;
         Cycles := @ + 1;

         while not LADO.Acquisition.Done loop
            null;
         end loop;
         --  A0B.Delays.Delay_For (A0B.Time.Milliseconds (1000));

         A0B.ARMv7M.Cache_Utilities.Invalidate_DCache
           (LADO.Acquisition.Buffer'Address,
            LADO.Acquisition.Buffer'Length * 2);

         declare
            use type A0B.Types.Unsigned_16;

            Previous : A0B.Types.Unsigned_16 := LADO.Acquisition.Buffer (0);

         begin
            for Index in LADO.Acquisition.Buffer'Range loop
               First := Index;

               exit Acquisition
                 when Previous /= LADO.Acquisition.Buffer (Index);

               Previous := LADO.Acquisition.Buffer (Index);
            end loop;
         end;
      end loop Acquisition;

      First := A0B.Types.Unsigned_32'Max (@, 10);
      First := @ - 10;

      Draw_Line (40, 2#0000_0001#, First);
      Draw_Line (80, 2#0000_0010#, First);
      Draw_Line (120, 2#0000_0100#, First);
      Draw_Line (160, 2#0000_1000#, First);
      Draw_Line (200, 2#0001_0000#, First);
      Draw_Line (240, 2#0010_0000#, First);

      raise Program_Error;
      --  loop
      --     null;
      --  end loop;
   end Run;

end LADO.UI;
