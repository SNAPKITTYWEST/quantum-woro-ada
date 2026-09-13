------------------------------------------------------------------------------
-- QUANTUM_WORO.ADB
-- Implementation of Write-Once / Read-Once Quantum Primitives
------------------------------------------------------------------------------

with Ada.Text_IO;
with Ada.Numerics.Elementary_Functions;
with Ada.Strings.Unbounded;
with Interfaces;

package body Quantum_WORO is

   use Ada.Strings.Unbounded;
   use Ada.Numerics.Elementary_Functions;

   ------------------------------------------------------------
   -- Complex arithmetic
   ------------------------------------------------------------

   function "+" (Left, Right : Complex) return Complex is
   begin
      return (Left.Re + Right.Re, Left.Im + Right.Im);
   end "+";

   function "-" (Left, Right : Complex) return Complex is
   begin
      return (Left.Re - Right.Re, Left.Im - Right.Im);
   end "-";

   function "*" (Left, Right : Complex) return Complex is
   begin
      return (Left.Re * Right.Re - Left.Im * Right.Im,
              Left.Re * Right.Im + Left.Im * Right.Re);
   end "*";

   function Conjugate (C : Complex) return Complex is
   begin
      return (C.Re, -C.Im);
   end Conjugate;

   function Norm_Squared (C : Complex) return Probability is
      N : constant Amplitude := C.Re * C.Re + C.Im * C.Im;
   begin
      if N < 0.0 then return 0.0;
      elsif N > 1.0 then return 1.0;
      else return Probability (N);
      end if;
   end Norm_Squared;

   function Magnitude (C : Complex) return Amplitude is
   begin
      return Sqrt (C.Re * C.Re + C.Im * C.Im);
   end Magnitude;

   ------------------------------------------------------------
   -- Internal helpers
   ------------------------------------------------------------

   function Approx_Equal (A, B : Amplitude; Eps : Amplitude := 1.0E-6)
                          return Boolean is
   begin
      return abs (A - B) < Eps;
   end Approx_Equal;
   pragma Unreferenced (Approx_Equal);

   procedure Normalize (Alpha, Beta : in out Complex) is
      N2 : constant Amplitude :=
        Alpha.Re * Alpha.Re + Alpha.Im * Alpha.Im +
        Beta.Re  * Beta.Re  + Beta.Im  * Beta.Im;
      N : Amplitude;
   begin
      if N2 <= 0.0 then
         Alpha := One_Complex;
         Beta  := Zero_Complex;
         return;
      end if;
      N := Sqrt (N2);
      Alpha.Re := Alpha.Re / N;  Alpha.Im := Alpha.Im / N;
      Beta.Re  := Beta.Re  / N;  Beta.Im  := Beta.Im  / N;
   end Normalize;

   function Pseudo_Random (Seed : Interfaces.Unsigned_64) return Probability is
      use Interfaces;
      X : Unsigned_64 := Seed * 6364136223846793005 + 1;
   begin
      X := Shift_Right (X, 33);
      return Probability (Float (X and 16#FFFF_FFFF#)
                          / Float (16#1_0000_0000#));
   end Pseudo_Random;

   function Hash_String (S : String) return Interfaces.Unsigned_64 is
      use Interfaces;
      H : Unsigned_64 := 14695981039346656037;
   begin
      for C of S loop
         H := H xor Unsigned_64 (Character'Pos (C));
         H := H * 1099511628211;
      end loop;
      return H;
   end Hash_String;

   function Toy_Encrypt (Plain : String; Key : String) return String is
      Result : String (Plain'Range);
      K      : Interfaces.Unsigned_64 := Hash_String (Key);
   begin
      for I in Plain'Range loop
         K := K * 6364136223846793005 + 1;
         Result (I) := Character'Val
           ((Character'Pos (Plain (I)) + Natural (K and 16#FF#)) mod 256);
      end loop;
      return Result;
   end Toy_Encrypt;

   function Toy_Decrypt (Cipher : String; Key : String) return String is
      Result : String (Cipher'Range);
      K      : Interfaces.Unsigned_64 := Hash_String (Key);
   begin
      for I in Cipher'Range loop
         K := K * 6364136223846793005 + 1;
         declare
            Plain_Byte : constant Integer :=
              Character'Pos (Cipher (I)) - Integer (K and 16#FF#);
         begin
            Result (I) := Character'Val (((Plain_Byte mod 256) + 256) mod 256);
         end;
      end loop;
      return Result;
   end Toy_Decrypt;

   ------------------------------------------------------------
   -- Qubit lifecycle
   ------------------------------------------------------------

   overriding procedure Initialize (Q : in out Qubit) is
   begin
      Q.Kind      := Invalid;
      Q.Alpha     := One_Complex;
      Q.Beta      := Zero_Complex;
      Q.Classical := Zero;
      Q.Seed      := 0;
   end Initialize;

   overriding procedure Finalize (Q : in out Qubit) is
   begin
      Q.Kind  := Invalid;
      Q.Alpha := Zero_Complex;
      Q.Beta  := Zero_Complex;
   end Finalize;

   procedure Prepare_Zero (Q : in out Qubit) is
   begin
      Q.Kind  := Superposition;
      Q.Alpha := One_Complex;
      Q.Beta  := Zero_Complex;
      Q.Seed  := Q.Seed + 1;
   end Prepare_Zero;

   procedure Prepare_One (Q : in out Qubit) is
   begin
      Q.Kind  := Superposition;
      Q.Alpha := Zero_Complex;
      Q.Beta  := One_Complex;
      Q.Seed  := Q.Seed + 1;
   end Prepare_One;

   procedure Prepare_Plus (Q : in out Qubit) is
      Inv_Sqrt2 : constant Amplitude := 0.70710678118654752;
   begin
      Q.Kind  := Superposition;
      Q.Alpha := (Inv_Sqrt2, 0.0);
      Q.Beta  := (Inv_Sqrt2, 0.0);
      Q.Seed  := Q.Seed + 1;
   end Prepare_Plus;

   procedure Prepare_Minus (Q : in out Qubit) is
      Inv_Sqrt2 : constant Amplitude := 0.70710678118654752;
   begin
      Q.Kind  := Superposition;
      Q.Alpha := ( Inv_Sqrt2, 0.0);
      Q.Beta  := (-Inv_Sqrt2, 0.0);
      Q.Seed  := Q.Seed + 1;
   end Prepare_Minus;

   procedure Prepare_Custom (Q     : in out Qubit;
                              Alpha : Complex;
                              Beta  : Complex) is
      A_Mut : Complex := Alpha;
      B_Mut : Complex := Beta;
   begin
      Normalize (A_Mut, B_Mut);
      Q.Kind  := Superposition;
      Q.Alpha := A_Mut;
      Q.Beta  := B_Mut;
      Q.Seed  := Q.Seed + 1;
   end Prepare_Custom;

   function Measure (Q : in out Qubit) return Measurement_Outcome is
      P0 : constant Probability := Norm_Squared (Q.Alpha);
      R  : constant Probability := Pseudo_Random (Q.Seed xor 16#DEAD_BEEF#);
   begin
      if Q.Kind = Collapsed then
         return Measurement_Outcome (Q.Classical);
      end if;
      if R < P0 then
         Q.Classical := Zero;
         Q.Alpha     := One_Complex;
         Q.Beta      := Zero_Complex;
      else
         Q.Classical := One;
         Q.Alpha     := Zero_Complex;
         Q.Beta      := One_Complex;
      end if;
      Q.Kind := Collapsed;
      Q.Seed := Q.Seed + 1;
      return Measurement_Outcome (Q.Classical);
   end Measure;

   function Is_Collapsed (Q : Qubit) return Boolean is
   begin
      return Q.Kind = Collapsed;
   end Is_Collapsed;

   function Is_Valid (Q : Qubit) return Boolean is
   begin
      return Q.Kind /= Invalid;
   end Is_Valid;

   procedure Reset (Q : in out Qubit) is
   begin
      Q.Kind  := Invalid;
      Q.Alpha := Zero_Complex;
      Q.Beta  := Zero_Complex;
   end Reset;

   procedure Dump_Qubit (Q : Qubit; Label : String := "") is
      use Ada.Text_IO;
   begin
      if Label /= "" then Put (Label & ": "); end if;
      case Q.Kind is
         when Superposition =>
            Put_Line ("Qubit[SUPER alpha=(" &
                      Amplitude'Image (Q.Alpha.Re) & "+" &
                      Amplitude'Image (Q.Alpha.Im) & "i) beta=(" &
                      Amplitude'Image (Q.Beta.Re) & "+" &
                      Amplitude'Image (Q.Beta.Im) & "i)]");
         when Collapsed =>
            Put_Line ("Qubit[COLLAPSED classical=" & Bit'Image (Q.Classical) & "]");
         when Invalid =>
            Put_Line ("Qubit[INVALID]");
      end case;
   end Dump_Qubit;

   ------------------------------------------------------------
   -- Quantum State Vector
   ------------------------------------------------------------

   overriding procedure Initialize (S : in out Quantum_State) is
   begin
      S.Amplitudes := (others => Zero_Complex);
      S.Amplitudes (0) := One_Complex;
      S.Collapsed := False;
   end Initialize;

   procedure Initialize_State (S          : in out Quantum_State;
                                Num_Qubits : Qubit_Index) is
      pragma Unreferenced (Num_Qubits);
   begin
      S.Amplitudes := (others => Zero_Complex);
      S.Amplitudes (0) := One_Complex;
      S.Collapsed := False;
      S.Seed := 42;
   end Initialize_State;

   -- Apply a 2x2 unitary to the qubit at Target within state S
   procedure Apply_Single (S       : in out Quantum_State;
                            Target  : Qubit_Index;
                            U00, U01, U10, U11 : Complex) is
      N : constant Natural := S.Dim;
   begin
      for I in 0 .. N - 1 loop
         if (I / (2 ** Natural (Target))) mod 2 = 0 then
            declare
               J    : constant Natural := I + 2 ** Natural (Target);
               A    : constant Complex := S.Amplitudes (I);
               B    : constant Complex := S.Amplitudes (J);
            begin
               S.Amplitudes (I) := U00 * A + U01 * B;
               S.Amplitudes (J) := U10 * A + U11 * B;
            end;
         end if;
      end loop;
   end Apply_Single;

   procedure Apply_Hadamard (S : in out Quantum_State; Target : Qubit_Index) is
      Inv_Sqrt2 : constant Amplitude := 0.70710678118654752;
   begin
      Apply_Single (S, Target,
                    (Inv_Sqrt2, 0.0), ( Inv_Sqrt2, 0.0),
                    (Inv_Sqrt2, 0.0), (-Inv_Sqrt2, 0.0));
   end Apply_Hadamard;

   procedure Apply_X (S : in out Quantum_State; Target : Qubit_Index) is
   begin
      Apply_Single (S, Target,
                    Zero_Complex, One_Complex,
                    One_Complex,  Zero_Complex);
   end Apply_X;

   procedure Apply_CNOT (S       : in out Quantum_State;
                          Control : Qubit_Index;
                          Target  : Qubit_Index) is
      N : constant Natural := S.Dim;
   begin
      for I in 0 .. N - 1 loop
         if (I / (2 ** Natural (Control))) mod 2 = 1
           and then (I / (2 ** Natural (Target))) mod 2 = 0
         then
            declare
               J : constant Natural := I + 2 ** Natural (Target);
               Tmp : constant Complex := S.Amplitudes (I);
            begin
               S.Amplitudes (I) := S.Amplitudes (J);
               S.Amplitudes (J) := Tmp;
            end;
         end if;
      end loop;
   end Apply_CNOT;

   procedure Apply_CCX (S        : in out Quantum_State;
                         Control1 : Qubit_Index;
                         Control2 : Qubit_Index;
                         Target   : Qubit_Index) is
      N : constant Natural := S.Dim;
   begin
      for I in 0 .. N - 1 loop
         if (I / (2 ** Natural (Control1))) mod 2 = 1
           and then (I / (2 ** Natural (Control2))) mod 2 = 1
           and then (I / (2 ** Natural (Target))) mod 2 = 0
         then
            declare
               J   : constant Natural := I + 2 ** Natural (Target);
               Tmp : constant Complex := S.Amplitudes (I);
            begin
               S.Amplitudes (I) := S.Amplitudes (J);
               S.Amplitudes (J) := Tmp;
            end;
         end if;
      end loop;
   end Apply_CCX;

   function Measure_All (S : in out Quantum_State) return String is
      N      : constant Natural := S.Dim;
      Result : String (1 .. Natural (S.Num_Qubits));
      R      : constant Probability := Pseudo_Random (S.Seed xor 16#FEED#);
      Acc    : Probability := 0.0;
      Chosen : Natural := 0;
   begin
      for I in 0 .. N - 1 loop
         Acc := Acc + Norm_Squared (S.Amplitudes (I));
         if Acc >= R and then Chosen = 0 then
            Chosen := I;
         end if;
      end loop;
      S.Amplitudes := (others => Zero_Complex);
      S.Amplitudes (Chosen) := One_Complex;
      S.Collapsed := True;
      S.Seed := S.Seed + 1;
      for K in 0 .. Natural (S.Num_Qubits) - 1 loop
         if (Chosen / (2 ** K)) mod 2 = 1 then
            Result (Natural (S.Num_Qubits) - K) := '1';
         else
            Result (Natural (S.Num_Qubits) - K) := '0';
         end if;
      end loop;
      return Result;
   end Measure_All;

   function Measure_Single (S     : in out Quantum_State;
                              Index : Qubit_Index) return Measurement_Outcome is
      N   : constant Natural := S.Dim;
      P1  : Probability := 0.0;
      R   : constant Probability := Pseudo_Random (S.Seed xor
              Interfaces.Unsigned_64 (Index) * 16#BABE#);
      Got_One : Boolean;
   begin
      for I in 0 .. N - 1 loop
         if (I / (2 ** Natural (Index))) mod 2 = 1 then
            P1 := P1 + Norm_Squared (S.Amplitudes (I));
         end if;
      end loop;
      Got_One := R < P1;
      for I in 0 .. N - 1 loop
         if (I / (2 ** Natural (Index))) mod 2 = (if Got_One then 0 else 1) then
            S.Amplitudes (I) := Zero_Complex;
         end if;
      end loop;
      S.Seed := S.Seed + 1;
      return (if Got_One then One else Zero);
   end Measure_Single;

   procedure Dump_State (S : Quantum_State; Label : String := "") is
      use Ada.Text_IO;
   begin
      if Label /= "" then Put_Line (Label); end if;
      for I in 0 .. S.Dim - 1 loop
         declare
            Amp : constant Complex := S.Amplitudes (I);
            Pr  : constant Probability := Norm_Squared (Amp);
         begin
            if Float (Pr) > 1.0E-6 then
               Put_Line ("|" & Natural'Image (I) & "> : (" &
                         Amplitude'Image (Amp.Re) & "+" &
                         Amplitude'Image (Amp.Im) & "i) p=" &
                         Probability'Image (Pr));
            end if;
         end;
      end loop;
   end Dump_State;

   ------------------------------------------------------------
   -- One-Time Memory
   ------------------------------------------------------------

   overriding procedure Initialize (OTM : in out One_Time_Memory) is
   begin
      OTM.Status  := Active;
      OTM.Secret0 := Null_Unbounded_String;
      OTM.Secret1 := Null_Unbounded_String;
   end Initialize;

   overriding procedure Finalize (OTM : in out One_Time_Memory) is
   begin
      OTM.Status  := Consumed;
      OTM.Secret0 := Null_Unbounded_String;
      OTM.Secret1 := Null_Unbounded_String;
   end Finalize;

   procedure Create_OTM (OTM     : in out One_Time_Memory;
                          Secret0 : String;
                          Secret1 : String) is
   begin
      OTM.Status  := Active;
      OTM.Secret0 := To_Unbounded_String (Secret0);
      OTM.Secret1 := To_Unbounded_String (Secret1);
   end Create_OTM;

   function Read_OTM (OTM    : in out One_Time_Memory;
                       Choice : OTM_Choice) return String is
   begin
      if OTM.Status = Consumed then
         raise OTM_Already_Consumed;
      end if;
      declare
         Result : constant String :=
           (if Choice = Choose_Zero
            then To_String (OTM.Secret0)
            else To_String (OTM.Secret1));
      begin
         OTM.Status  := Consumed;
         OTM.Secret0 := Null_Unbounded_String;
         OTM.Secret1 := Null_Unbounded_String;
         return Result;
      end;
   end Read_OTM;

   function Describe_OTM (OTM : One_Time_Memory) return String is
   begin
      return "OTM[" & OTM_Status'Image (OTM.Status) & "]";
   end Describe_OTM;

   ------------------------------------------------------------
   -- Encrypted Clone Bundle
   ------------------------------------------------------------

   overriding procedure Initialize (B : in out Encrypted_Clone_Bundle) is
   begin
      B.Key_Consumed := False;
      B.Total        := 0;
      B.Master_Key   := Null_Unbounded_String;
      B.Clones       := (others => (Data => (others => ASCII.NUL),
                                    Len  => 0,
                                    Used => False));
   end Initialize;

   procedure Create_Encrypted_Clones
     (Bundle       : in out Encrypted_Clone_Bundle;
      Payload      : String;
      Num_Clones   : Clone_Index;
      Key_Material : String) is
   begin
      Bundle.Key_Consumed := False;
      Bundle.Master_Key   := To_Unbounded_String (Key_Material);
      Bundle.Total        := Num_Clones;
      for I in 0 .. Num_Clones - 1 loop
         declare
            Per_Key : constant String :=
              Key_Material & "#" & Clone_Index'Image (I);
            Cipher  : constant String := Toy_Encrypt (Payload, Per_Key);
            Len     : constant Natural :=
              Natural'Min (Cipher'Length, Max_Payload);
         begin
            Bundle.Clones (I).Len := Len;
            Bundle.Clones (I).Data (1 .. Len) := Cipher (Cipher'First ..
                                                           Cipher'First + Len - 1);
            Bundle.Clones (I).Used := False;
         end;
      end loop;
   end Create_Encrypted_Clones;

   function Decrypt_One_Clone (Bundle : in out Encrypted_Clone_Bundle;
                                Index  : Clone_Index) return String is
   begin
      if Bundle.Key_Consumed then
         raise Clone_Already_Used;
      end if;
      if Bundle.Clones (Index).Used then
         raise Clone_Already_Used;
      end if;
      declare
         Master  : constant String := To_String (Bundle.Master_Key);
         Per_Key : constant String := Master & "#" & Clone_Index'Image (Index);
         Cipher  : constant String :=
           Bundle.Clones (Index).Data (1 .. Bundle.Clones (Index).Len);
         Plain   : constant String := Toy_Decrypt (Cipher, Per_Key);
      begin
         Bundle.Clones (Index).Used := True;
         Bundle.Key_Consumed        := True;
         Bundle.Master_Key          := Null_Unbounded_String;
         return Plain;
      end;
   end Decrypt_One_Clone;

   function Clones_Remaining (Bundle : Encrypted_Clone_Bundle) return Natural is
      Count : Natural := 0;
   begin
      for I in 0 .. Bundle.Total - 1 loop
         if not Bundle.Clones (I).Used then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Clones_Remaining;

   ------------------------------------------------------------
   -- WORO Resource
   ------------------------------------------------------------

   overriding procedure Initialize (R : in out WORO_Resource) is
   begin
      R.Status := Empty;
      R.Buffer := Null_Unbounded_String;
   end Initialize;

   overriding procedure Finalize (R : in out WORO_Resource) is
   begin
      R.Status := Exhausted;
      R.Buffer := Null_Unbounded_String;
   end Finalize;

   procedure Write_Resource (R    : in out WORO_Resource;
                              Data : String) is
   begin
      if R.Status /= Empty then
         raise WORO_Write_Violation with
           "WORO_Resource already written (status=" &
           Resource_State'Image (R.Status) & ")";
      end if;
      R.Buffer := To_Unbounded_String (Data);
      R.Status := Readable;
   end Write_Resource;

   function Read_Resource (R : in out WORO_Resource) return String is
   begin
      if R.Status /= Readable then
         raise WORO_Read_Violation with
           "WORO_Resource not readable (status=" &
           Resource_State'Image (R.Status) & ")";
      end if;
      declare
         Result : constant String := To_String (R.Buffer);
      begin
         R.Buffer := Null_Unbounded_String;
         R.Status := Exhausted;
         return Result;
      end;
   end Read_Resource;

   function Resource_Status (R : WORO_Resource) return Resource_State is
   begin
      return R.Status;
   end Resource_Status;

end Quantum_WORO;
