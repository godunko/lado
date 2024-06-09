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

package body LADO.UI is

   procedure PendSV_Handler is null
     with Export, Convention => C, External_Name => "PendSV_Handler";

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
            for Current of LADO.Acquisition.Buffer loop
               --  exit Acquisition when Previous /= Current;
               Previous := Current;
            end loop;
         end;
      end loop Acquisition;

      raise Program_Error;
      --  loop
      --     null;
      --  end loop;
   end Run;

end LADO.UI;
