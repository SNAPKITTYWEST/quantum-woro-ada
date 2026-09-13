------------------------------------------------------------------------------
-- QUANTUM_WORO.ADS
-- Write-Once / Read-Once Quantum Primitives in Pure Ada
--
-- Hand-rolled implementation of theoretical constructs surrounding:
--   * No-Cloning Theorem enforcement via limited & controlled types
--   * Destructive measurement (collapse)
--   * Quantum One-Time Memories (OTMs)
--   * Encrypted Cloning with single-use decryption keys
--   * Linear resource semantics for qubits and quantum states
--
-- This is a pedagogical / architectural model, not a full quantum simulator.
-- Complex amplitudes are represented with fixed-point or Float for clarity.
-- The type system itself prevents illicit cloning.
--
-- Compatible with Ada 2012 / Ada 2022. SPARK-friendly annotations included
-- where practical.
------------------------------------------------------------------------------

pragma Ada_2012;

with Ada.Finalization;
with Ada.Strings.Unbounded;
with Interfaces;

package Quantum_WORO is

   ------------------------------------------------------------
   -- Basic numeric & utility types
   ------------------------------------------------------------

   type Amplitude    is digits 12;
   type Probability  is digits 8 range 0.0 .. 1.0;

   type Complex is record
      Re : Amplitude := 0.0;
      Im : Amplitude := 0.0;
   end record;

   function "+"         (Left, Right : Complex) return Complex;
   function "-"         (Left, Right : Complex) return Complex;
   function "*"         (Left, Right : Complex) return Complex;
   function Conjugate   (C : Complex) return Complex;
   function Norm_Squared(C : Complex) return Probability;
   function Magnitude   (C : Complex) return Amplitude;

   Zero_Complex : constant Complex := (0.0, 0.0);
   One_Complex  : constant Complex := (1.0, 0.0);
   I_Complex    : constant Complex := (0.0, 1.0);

   ------------------------------------------------------------
   -- Classical bit & measurement outcome
   ------------------------------------------------------------

   type Bit                is (Zero, One);
   type Measurement_Outcome is new Bit;

   ------------------------------------------------------------
   -- Qubit -- limited private type (no cloning by construction)
   --
   -- The limited nature + controlled finalization ensure that a
   -- qubit cannot be bitwise copied. Assignment moves ownership.
   ------------------------------------------------------------

   type Qubit is limited private;

   -- Preparation (the single "Write")
   procedure Prepare_Zero   (Q : in out Qubit);
   procedure Prepare_One    (Q : in out Qubit);
   procedure Prepare_Plus   (Q : in out Qubit);  -- |+> = (|0>+|1>)/sqrt(2)
   procedure Prepare_Minus  (Q : in out Qubit);  -- |->
   procedure Prepare_Custom (Q     : in out Qubit;
                              Alpha : Complex;
                              Beta  : Complex);

   -- Destructive measurement (the single "Read")
   -- After this call the qubit is in a classical eigenstate and
   -- the original superposition is irreversibly lost.
   function Measure (Q : in out Qubit) return Measurement_Outcome;

   -- Non-destructive status queries (do not collapse)
   function Is_Collapsed (Q : Qubit) return Boolean;
   function Is_Valid      (Q : Qubit) return Boolean;

   -- Explicit reset (destroys any remaining quantum information)
   procedure Reset (Q : in out Qubit);

   -- Debug dump
   procedure Dump_Qubit (Q : Qubit; Label : String := "");

   ------------------------------------------------------------
   -- Quantum State Vector (multi-qubit, still limited)
   ------------------------------------------------------------

   Max_Qubits      : constant := 8;
   type Qubit_Index    is range 0 .. Max_Qubits - 1;
   type State_Dimension is range 1 .. 2 ** Max_Qubits;

   subtype Bit_String is String;  -- "0101..." length = Num_Qubits

   type Quantum_State (Num_Qubits : Qubit_Index) is limited private;

   procedure Initialize_State (S          : in out Quantum_State;
                                Num_Qubits : Qubit_Index);
   procedure Apply_Hadamard   (S : in out Quantum_State; Target : Qubit_Index);
   procedure Apply_X          (S : in out Quantum_State; Target : Qubit_Index);
   procedure Apply_CNOT       (S      : in out Quantum_State;
                                Control : Qubit_Index;
                                Target  : Qubit_Index);
   procedure Apply_CCX        (S       : in out Quantum_State;
                                Control1 : Qubit_Index;
                                Control2 : Qubit_Index;
                                Target   : Qubit_Index);

   -- Measure all qubits destructively; returns classical bit string
   function Measure_All (S : in out Quantum_State) return String;

   -- Measure a single qubit; state collapses on that index
   function Measure_Single (S     : in out Quantum_State;
                             Index : Qubit_Index) return Measurement_Outcome;

   procedure Dump_State (S : Quantum_State; Label : String := "");

   ------------------------------------------------------------
   -- One-Time Memory
   ------------------------------------------------------------

   type OTM_Choice is (Choose_Zero, Choose_One);
   type One_Time_Memory is limited private;

   OTM_Already_Consumed : exception;

   procedure Create_OTM  (OTM     : in out One_Time_Memory;
                           Secret0 : String;
                           Secret1 : String);

   -- Destructive read: returns one secret and annihilates the other
   function Read_OTM    (OTM    : in out One_Time_Memory;
                          Choice : OTM_Choice) return String;

   function Describe_OTM (OTM : One_Time_Memory) return String;

   ------------------------------------------------------------
   -- Encrypted Clone Bundle
   ------------------------------------------------------------

   Max_Clones : constant := 16;
   type Clone_Index is range 0 .. Max_Clones - 1;

   type Encrypted_Clone_Bundle is limited private;

   Clone_Already_Used : exception;

   procedure Create_Encrypted_Clones
     (Bundle       : in out Encrypted_Clone_Bundle;
      Payload      : String;
      Num_Clones   : Clone_Index;
      Key_Material : String);

   -- Single-use decryption; master key is wiped after first success
   function Decrypt_One_Clone (Bundle : in out Encrypted_Clone_Bundle;
                                Index  : Clone_Index) return String;

   function Clones_Remaining (Bundle : Encrypted_Clone_Bundle) return Natural;

   ------------------------------------------------------------
   -- Linear WORO Resource (abstract state machine)
   ------------------------------------------------------------

   type Resource_State is (Empty, Written, Readable, Exhausted);

   type WORO_Resource is limited private;

   WORO_Write_Violation : exception;
   WORO_Read_Violation  : exception;

   procedure Write_Resource  (R    : in out WORO_Resource;
                               Data : String);
   function  Read_Resource   (R    : in out WORO_Resource) return String;
   function  Resource_Status (R    : WORO_Resource) return Resource_State;

private

   type Qubit_Kind is (Superposition, Collapsed, Invalid);

   type Qubit is new Ada.Finalization.Limited_Controlled with record
      Kind        : Qubit_Kind := Invalid;
      Alpha       : Complex    := One_Complex;
      Beta        : Complex    := Zero_Complex;
      Classical   : Bit        := Zero;
      Seed        : Interfaces.Unsigned_64 := 0;
   end record;

   overriding procedure Initialize (Q : in out Qubit);
   overriding procedure Finalize   (Q : in out Qubit);

   Max_Dim : constant := 2 ** Max_Qubits;

   type Amplitude_Array is array (Natural range <>) of Complex;

   type Quantum_State (Num_Qubits : Qubit_Index) is
      new Ada.Finalization.Limited_Controlled with record
         Dim        : Natural := 2 ** Natural (Num_Qubits);
         Amplitudes : Amplitude_Array (0 .. Max_Dim - 1);
         Collapsed  : Boolean := False;
         Seed       : Interfaces.Unsigned_64 := 42;
      end record;

   overriding procedure Initialize (S : in out Quantum_State);

   type OTM_Status is (Active, Consumed);

   type One_Time_Memory is new Ada.Finalization.Limited_Controlled with record
      Status  : OTM_Status := Active;
      Secret0 : Ada.Strings.Unbounded.Unbounded_String;
      Secret1 : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   overriding procedure Initialize (OTM : in out One_Time_Memory);
   overriding procedure Finalize   (OTM : in out One_Time_Memory);

   Max_Payload : constant := 256;

   type Cipher_Slot is record
      Data : String (1 .. Max_Payload) := (others => ASCII.NUL);
      Len  : Natural := 0;
      Used : Boolean := False;
   end record;

   type Clone_Array is array (Clone_Index) of Cipher_Slot;

   type Encrypted_Clone_Bundle is new Ada.Finalization.Limited_Controlled with record
      Clones        : Clone_Array;
      Total         : Clone_Index := 0;
      Key_Consumed  : Boolean := False;
      Master_Key    : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   overriding procedure Initialize (B : in out Encrypted_Clone_Bundle);

   type WORO_Resource is new Ada.Finalization.Limited_Controlled with record
      Status : Resource_State := Empty;
      Buffer : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   overriding procedure Initialize (R : in out WORO_Resource);
   overriding procedure Finalize   (R : in out WORO_Resource);

end Quantum_WORO;
