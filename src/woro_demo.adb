------------------------------------------------------------------------------
-- WORO_DEMO.ADB
-- Demonstration driver for the Quantum Write-Once / Read-Once library
--
-- Exercises:
--   1. Single-qubit preparation & destructive measurement
--   2. Multi-qubit circuit + full collapse
--   3. One-Time Memory (OTM) protocol
--   4. Encrypted cloning with single-use decryption
--   5. High-level WORO_Resource linear usage
--   6. Attempted double-read (must raise)
------------------------------------------------------------------------------

with Ada.Text_IO;
with Ada.Exceptions;
with Quantum_WORO;

procedure WORO_Demo is

   use Ada.Text_IO;
   use Quantum_WORO;

   procedure Separator (Title : String) is
   begin
      New_Line;
      Put_Line ("------------------------------------------------------------");
      Put_Line (" " & Title);
      Put_Line ("------------------------------------------------------------");
   end Separator;

   -- 1. Single qubit
   procedure Demo_Single_Qubit is
      Q : Qubit;
      M : Measurement_Outcome;
   begin
      Separator ("1. Single Qubit -- Prepare Plus, Destructive Measure");
      Prepare_Plus (Q);
      Dump_Qubit (Q, "after Prepare_Plus");
      M := Measure (Q);
      Put_Line ("Measurement outcome : " & Measurement_Outcome'Image (M));
      Dump_Qubit (Q, "after Measure (collapsed)");
      M := Measure (Q);
      Put_Line ("Re-measure collapsed : " & Measurement_Outcome'Image (M));
   end Demo_Single_Qubit;

   -- 2. Multi-qubit Bell state
   procedure Demo_Multi_Qubit is
      S    : Quantum_State (1);
      Bits : String (1 .. 2);
   begin
      Separator ("2. Two-Qubit Bell-like Circuit + Full Collapse");
      Initialize_State (S, 1);
      Dump_State (S, "initial |00>");
      Apply_Hadamard (S, 0);
      Dump_State (S, "after H on qubit 0");
      Apply_CNOT (S, 0, 1);
      Dump_State (S, "after CNOT (Bell state)");
      Bits := Measure_All (S);
      Put_Line ("Measured bit string : " & Bits);
      Dump_State (S, "after full measurement (collapsed)");
   end Demo_Multi_Qubit;

   -- 3. One-Time Memory
   procedure Demo_OTM is
      OTM    : One_Time_Memory;
      Secret : String (1 .. 32) := (others => ' ');
   begin
      Separator ("3. One-Time Memory Protocol");
      Create_OTM (OTM,
                  Secret0 => "TOP-SECRET-ALPHA-KEY-42",
                  Secret1 => "TOP-SECRET-BETA-KEY-99");
      Put_Line (Describe_OTM (OTM));
      declare
         R : constant String := Read_OTM (OTM, Choose_Zero);
      begin
         Secret (Secret'First .. Secret'First + R'Length - 1) := R;
         Put_Line ("Retrieved secret : " & Secret);
      end;
      Put_Line (Describe_OTM (OTM));
      begin
         declare
            R2 : constant String := Read_OTM (OTM, Choose_One);
            pragma Unreferenced (R2);
         begin
            Put_Line ("ERROR: second read should have raised");
         end;
      exception
         when OTM_Already_Consumed =>
            Put_Line ("Correctly raised OTM_Already_Consumed on second read");
         when E : others =>
            Put_Line ("Unexpected: " & Ada.Exceptions.Exception_Message (E));
      end;
   end Demo_OTM;

   -- 4. Encrypted clones
   procedure Demo_Encrypted_Clones is
      Bundle : Encrypted_Clone_Bundle;
   begin
      Separator ("4. Encrypted Cloning with Single-Use Key");
      Create_Encrypted_Clones
        (Bundle       => Bundle,
         Payload      => "Quantum payload that may be recovered only once",
         Num_Clones   => 4,
         Key_Material => "single-use-master-token-xyz");
      Put_Line ("Clones created : " & Natural'Image (Clones_Remaining (Bundle)));
      declare
         Plain : constant String := Decrypt_One_Clone (Bundle, 2);
      begin
         Put_Line ("Decrypted clone #2 : " & Plain);
      end;
      Put_Line ("Clones remaining : " & Natural'Image (Clones_Remaining (Bundle)));
      begin
         declare
            Plain2 : constant String := Decrypt_One_Clone (Bundle, 1);
            pragma Unreferenced (Plain2);
         begin
            Put_Line ("ERROR: second decryption should have raised");
         end;
      exception
         when Clone_Already_Used =>
            Put_Line ("Correctly raised Clone_Already_Used on second decrypt");
         when E : others =>
            Put_Line ("Unexpected: " & Ada.Exceptions.Exception_Message (E));
      end;
   end Demo_Encrypted_Clones;

   -- 5. WORO_Resource linear lifecycle
   procedure Demo_Resource is
      R : WORO_Resource;
   begin
      Separator ("5. WORO_Resource -- Write Once, Read Once");
      Put_Line ("Status: " & Resource_State'Image (Resource_Status (R)));
      Write_Resource (R, "sovereign-truth-packet-v1");
      Put_Line ("Status: " & Resource_State'Image (Resource_Status (R)));
      declare
         Data : constant String := Read_Resource (R);
      begin
         Put_Line ("Read: " & Data);
      end;
      Put_Line ("Status: " & Resource_State'Image (Resource_Status (R)));
   end Demo_Resource;

   -- 6. Double-read violation
   procedure Demo_Double_Read is
      R : WORO_Resource;
   begin
      Separator ("6. Double-Read Violation (must raise)");
      Write_Resource (R, "once-only-data");
      declare
         D1 : constant String := Read_Resource (R);
         pragma Unreferenced (D1);
      begin
         null;
      end;
      begin
         declare
            D2 : constant String := Read_Resource (R);
            pragma Unreferenced (D2);
         begin
            Put_Line ("ERROR: double-read should have raised");
         end;
      exception
         when WORO_Read_Violation =>
            Put_Line ("Correctly raised WORO_Read_Violation on double-read");
         when E : others =>
            Put_Line ("Unexpected: " & Ada.Exceptions.Exception_Message (E));
      end;
   end Demo_Double_Read;

begin
   Demo_Single_Qubit;
   Demo_Multi_Qubit;
   Demo_OTM;
   Demo_Encrypted_Clones;
   Demo_Resource;
   Demo_Double_Read;
   New_Line;
   Put_Line ("All WORO demonstrations complete.");
end WORO_Demo;
