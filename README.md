# quantum-woro-ada

Write-Once / Read-Once quantum primitives in pure Ada 2012.

The Ada type system enforces the No-Cloning Theorem structurally. `Qubit` and `Quantum_State` are `limited` types derived from `Limited_Controlled` — the compiler rejects any attempt to copy or assign them. Measurement is destructive: `Measure` collapses the qubit and there is no way to recover the superposition.

## Components

| File | Purpose |
|---|---|
| `quantum_woro.ads` | Package spec — public API |
| `quantum_woro.adb` | Implementation — complex arithmetic, state vector, OTM, encrypted clones, WORO resource |
| `quantum_woro_theory.ads` | Ghost contracts documenting no-cloning, destructive-measurement, and OTM invariants |
| `woro_demo.adb` | Demo driver — all six primitives exercised, double-read violations caught |

## Build

Requires GNAT (GCC Ada) or GNAT Community.

```
gprbuild -P quantum_woro.gpr
./bin/woro_demo
```

Or compile manually:

```
gnatmake -gnat2012 src/woro_demo.adb -I src/ -o woro_demo
./woro_demo
```

## Primitives

### Qubit — single linear quantum resource

```ada
Q : Qubit;
Prepare_Plus (Q);              -- write
M := Measure (Q);              -- destructive read, Q is now Collapsed
```

After `Measure`, the superposition is gone. Re-measurement returns the same classical value (idempotent on eigenstate), but the original amplitudes cannot be recovered.

### Quantum_State — multi-qubit state vector

```ada
S : Quantum_State (1);  -- 2-qubit register (Num_Qubits = 1 means index 0..1)
Initialize_State (S, 1);
Apply_Hadamard (S, 0);
Apply_CNOT (S, 0, 1);   -- Bell pair
Bits := Measure_All (S);
```

### One-Time Memory

```ada
Create_OTM (OTM, Secret0 => "alpha", Secret1 => "beta");
S := Read_OTM (OTM, Choose_Zero);   -- retrieves "alpha", erases "beta"
S := Read_OTM (OTM, Choose_One);    -- raises OTM_Already_Consumed
```

### Encrypted Clone Bundle

```ada
Create_Encrypted_Clones (Bundle, Payload => "...", Num_Clones => 4, Key_Material => "k");
P := Decrypt_One_Clone (Bundle, 2);  -- single-use decrypt
P := Decrypt_One_Clone (Bundle, 1);  -- raises Clone_Already_Used
```

### WORO_Resource — abstract linear state machine

```ada
Write_Resource (R, "data");          -- Empty -> Readable
D := Read_Resource (R);              -- Readable -> Exhausted
D := Read_Resource (R);              -- raises WORO_Read_Violation
```

## Theory

The No-Cloning Theorem (Wootters–Zurek 1982) states there is no unitary U such that U(|φ⟩⊗|e⟩) = |φ⟩⊗|φ⟩ for all |φ⟩. Ada `limited` types model this at the language level: the compiler enforces linearity so that attempting to copy a `Qubit` is a compile-time error, not a runtime surprise.

Destructive measurement is the native quantum WORO primitive — `Measure` extracts classical information and irreversibly collapses the superposition. This maps exactly to the Tier 2 ancilla interface in the ENKI two-tier WORO/QEC architecture: ancilla qubits are entangled briefly with the Tier 1 logical core to extract syndromes, then destructively read and discarded.
