--
--  Copyright (C) 2024, Vadim Godunko <vgodunko@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

pragma Ada_2022;

with System.Storage_Elements;

with A0B.ARMv7M.Cache_Utilities;
with A0B.Delays;
with A0B.Tasking;
with A0B.Time;
with A0B.Types;

with LADO.Acquisition;
with LADO.Display;
with LADO.Painter;
with LADO.Touch;

package body LADO.UI is

   procedure Draw_Line
     (Y     : A0B.Types.Integer_32;
      Mask  : A0B.Types.Unsigned_16;
      First : A0B.Types.Unsigned_32);

   procedure Draw (First : A0B.Types.Unsigned_32);

   First : A0B.Types.Unsigned_32 := 0;

   procedure Run;

   UI_Control : aliased A0B.Tasking.Task_Control_Block;

   ----------
   -- Draw --
   ----------

   procedure Draw (First : A0B.Types.Unsigned_32) is
   begin
      Draw_Line (40, 2#0000_0001#, First);
      Draw_Line (80, 2#0000_0010#, First);
      Draw_Line (120, 2#0000_0100#, First);
      Draw_Line (160, 2#0000_1000#, First);
      Draw_Line (200, 2#0001_0000#, First);
      Draw_Line (240, 2#0010_0000#, First);
   end Draw;

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
      Painter.Set_Color (16#0000#);
      Painter.Fill_Rect (0, Y, 800, 21);

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

   --------------------
   -- Do_Acquisition --
   --------------------

   procedure Do_Acquisition is
      use type System.Storage_Elements.Storage_Count;
      use type A0B.Types.Unsigned_32;

   begin
      Acquisition :
      loop
         LADO.Acquisition.Buffer := [others => 16#0001#];
         A0B.ARMv7M.Cache_Utilities.Clean_Invalidate_DCache
           (LADO.Acquisition.Buffer'Address,
            LADO.Acquisition.Buffer'Length * 2);

         LADO.Acquisition.Run;
         --  Cycles := @ + 1;

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

      if First > LADO.Acquisition.Buffer'Last - 800 then
         First := LADO.Acquisition.Buffer'Last - 800;

      else
         First := A0B.Types.Unsigned_32'Max (@, 10);
         First := @ - 10;
      end if;
   end Do_Acquisition;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize is
   begin
      null;
   end Initialize;

   -------------------
   -- Register_Task --
   -------------------

   procedure Register_Task is
   begin
      A0B.Tasking.Register_Thread (UI_Control, Run'Access, 16#200#);
   end Register_Task;

   ---------
   -- Run --
   ---------

   X_Start  : A0B.Types.Integer_32 with Volatile;
   Y_Start  : A0B.Types.Integer_32 with Volatile;
   X_End    : A0B.Types.Integer_32 with Volatile;
   Y_End    : A0B.Types.Integer_32 with Volatile;
   Start    : A0B.Types.Integer_32 with Volatile;

   procedure Run is
   begin
      LADO.Display.Initialize;

      loop
         Draw (First);

         declare
            use type A0B.Types.Integer_32;

            Current : LADO.Touch.Touch_State;

            Tracking : Boolean := False;
            --  X_Start  : A0B.Types.Integer_32;
            --  Y_Start  : A0B.Types.Integer_32;
            --  X_End    : A0B.Types.Integer_32;
            --  Y_End    : A0B.Types.Integer_32;
            --  Start    : A0B.Types.Integer_32;

         begin
            loop
               A0B.Delays.Delay_For (A0B.Time.Milliseconds (10));
               LADO.Touch.Get (Current);

               if Tracking then
                  if Current.Is_Touched then
                     X_End := Current.X;
                     Y_End := Current.Y;

                     Start :=
                       A0B.Types.Integer_32 (First) - (X_End - X_Start);

                     Start :=
                       A0B.Types.Integer_32'Min
                         (@,
                          A0B.Types.Integer_32
                            (LADO.Acquisition.Buffer'Last) - 800);
                     Start := A0B.Types.Integer_32'Max (@, 0);

                     Draw (A0B.Types.Unsigned_32 (Start));
                     --  First := A0B.Types.Unsigned_32 (Start);

                  else
                     --  X_End := Current.X;
                     --  Y_End := Current.Y;
                     Tracking := False;

                     Start :=
                       A0B.Types.Integer_32 (First) - (X_End - X_Start);
                     Start :=
                       A0B.Types.Integer_32'Min
                         (@,
                          A0B.Types.Integer_32
                            (LADO.Acquisition.Buffer'Last) - 800);
                     Start := A0B.Types.Integer_32'Max (@, 0);

                     First := A0B.Types.Unsigned_32 (Start);

                     Draw (A0B.Types.Unsigned_32 (Start));

                     if abs (X_Start - X_End) < 100
                       and abs (Y_Start - Y_End) < 100
                       and X_Start > 700 and Y_Start < 100
                     then
                        Do_Acquisition;
                     end if;

                     exit;
                     --  raise Program_Error;
                  end if;

               else
                  if Current.Is_Touched then
                     Tracking := True;

                     X_Start := Current.X;
                     Y_Start := Current.Y;
                     X_End   := X_Start;
                     Y_End   := Y_Start;
                  end if;
               end if;
            end loop;
         end;
      end loop;
   end Run;

end LADO.UI;
