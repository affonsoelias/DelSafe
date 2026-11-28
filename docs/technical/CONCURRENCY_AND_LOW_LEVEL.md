# Concurrency, Inline Assembly & Native Ecosystem Architecture

This technical note explains how DelSafe lowers OS concurrency primitives, raw pointers, Intel inline assembly, and native C/Pascal ecosystem dependencies uniformly across Free Pascal and C99 backends.

---

## 1. OS Threading & `Task<T>` Lowering (`async` / `spawn` / `await` / `yield`)

An `async` routine compiles to a task-returning wrapper (`specialize TDelSafeTask<T>` in Pascal, `DelSafeTask` in C99). Invoking `spawn Routine(...)` launches execution on an OS worker thread:
- **Free Pascal Backend:** Uses `BeginThread` / `WaitForThreadTerminate` with `ThreadSwitch` on `yield;`.
- **C99 Backend:** Uses Win32 `CreateThread` / `WaitForSingleObject` (`SwitchToThread` on `yield;`) on Windows and POSIX `pthread_create` / `pthread_join` (`-pthread`, `sched_yield`) on Linux/macOS.

---

## 2. Synchronization (`std/sync.dels`) & Bounded `Channel<T>`

- **Hardware Atomics (`AtomicInt32`):** Lowers to FPC `Interlocked*` intrinsics and GCC/Clang `__atomic_*` built-ins (`NewAtomic`, `AtomicLoad`, `AtomicStore`, `AtomicFetchAdd`, `AtomicCompareExchange`, `AtomicDestroy`).
- **OS Mutexes (`Mutex`):** Backed by critical sections (`TCriticalSection` / `CRITICAL_SECTION`) on Windows and `pthread_mutex_t` on POSIX (`NewMutex`, `MutexLock`, `MutexTryLock`, `MutexUnlock`, `MutexDestroy`).
- **Bounded Ring-Buffer `Channel<T>`:** Thread-safe fixed-capacity queue returning `Option<T>` from `Recv(ch)` / `TryRecv(ch)` (`NewChannel<T>(cap)`, `Send`, `TrySend`, `CloseChannel`, `IsChannelEmpty`, `IsChannelClosed`, `ChannelLen`, `DestroyChannel`).

---

## 3. Raw Pointers (`^T`) & Explicit `unsafe` Blocks

- Pointer types (`^T`), address-of (`@var`), and `nil` are available for systems programming and FFI.
- Dereferencing (`ptr^`) or calling `Free`/`Dispose` on a raw pointer outside `unsafe ... end unsafe;` is rejected at compile time with Error `E0312`.

---

## 4. Intel-Syntax Inline Assembly (`asm ... end asm;`)

The lexer captures raw assembly lines inside `asm ... end asm;` via `ScanAsmBlock` (`uDelSafeLexer.pas`) and the parser emits a `TASTAsmStmt`:

- **Free Pascal Emitter (`uDelSafeEmitterPascal.pas`):**
  ```pascal
  {$ASMMODE INTEL}
  asm
    nop
    mov eax, 42
  end;
  ```
- **C99 Emitter (`uDelSafeEmitterC.pas`):**
  ```c
  __asm__ volatile (
      ".intel_syntax noprefix\n\t"
      "nop\n\t"
      "mov eax, 42\n\t"
      ".att_syntax prefix"
  );
  ```

Guard architecture-specific instructions (e.g., `rdtsc`, x86 registers) with `@cfg(target_arch = "x86_64")` when targeting ARM64 or WebAssembly.

---

## 5. Native Ecosystem Integration (`pkg-config`, MSYS2 & `fppkg`)

1. **`pkg-config` & `extern c "<lib>"`:** When `extern c "sqlite3"` or `--sys-lib=sqlite3` (or `"system_libs"` in `delsafe.json`) is present, `uDelSafeToolchain.pas` queries `pkg-config --cflags --libs` and injects include/library flags for both C99 and FPC backends.
2. **Transitive Windows MSYS2 DLL Bundling:** By default (`--bundle-dlls`, `"bundle_dlls": true`), `BundleMSYS2Dlls` inspects linked DLL imports and copies required runtime DLLs (e.g. `libsqlite3-0.dll`) alongside the output executable. Pass `--no-bundle-dlls` to disable.
3. **Free Pascal Packages (`--fpc-pkg` / `delsafec pkg add-fpc`):** Discovers unit paths from `fppkg` and Lazarus Online Package Manager (OPM) and registers them in `"pascal_packages"`.
