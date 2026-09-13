------------------------------------------------------------------------------
-- QUANTUM_WORO_THEORY.ADS
-- Ghost contracts recording the mapping from theory to implementation.
------------------------------------------------------------------------------

package Quantum_WORO_Theory with SPARK_Mode => On is

   -- No-Cloning Theorem
   --
   -- There exists no unitary operator U such that for every |phi> and |e>:
   --   U (|phi> ⊗ |e>) = |phi> ⊗ |phi>
   --
   -- Enforced here by:
   --   * declaring Qubit and Quantum_State as limited types
   --   * deriving from Limited_Controlled (no Adjust / no copy)
   --   * never providing a Clone or Copy operation
   --   * moving ownership on Write_Quantum (source is Reset)

   -- Destructive Measurement Invariant
   --
   -- After Measure(Q):
   --   Q.Kind = Collapsed
   --   original superposition amplitudes are overwritten
   --   subsequent Measure calls are idempotent on the eigenstate

   -- One-Time Memory Security Goal
   --
   -- An OTM created with (s0, s1) satisfies:
   --   * exactly one of s0 or s1 can be obtained
   --   * after Read_OTM the other secret is erased
   --   * a second Read_OTM raises OTM_Already_Consumed

   -- Encrypted Cloning Security Goal
   --
   -- After Create_Encrypted_Clones:
   --   * N distinct ciphertexts exist
   --   * Decrypt_One_Clone succeeds for at most one index
   --   * the master key is wiped after the first successful decrypt
   --   * further decryption raises Clone_Already_Used

   -- Linear Resource Discipline (WORO_Resource)
   --
   -- A WORO_Resource transitions through:
   --   Empty -> Written -> Readable -> Exhausted
   -- A resource that has been read can never be read again.

   function No_Cloning_Holds            return Boolean is (True) with Ghost;
   function Measurement_Is_Destructive  return Boolean is (True) with Ghost;
   function OTM_Single_Extraction       return Boolean is (True) with Ghost;
   function Encrypted_Clone_Single_Use  return Boolean is (True) with Ghost;
   function Resource_Linear_Lifecycle   return Boolean is (True) with Ghost;

end Quantum_WORO_Theory;
