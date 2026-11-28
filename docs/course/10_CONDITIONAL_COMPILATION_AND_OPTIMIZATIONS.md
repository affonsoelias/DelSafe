# Chapter 10: Conditional Compilation & Optimization Directives

When writing high-performance systems and cross-platform applications, you often need fine-grained control over target platforms, function inlining, and compiler optimization hints.

DelSafe provides this through **`@cfg`**, **`@inline`**, **`@cold`**, and **`comptime`**.

---

## 1. Multiplatform Conditional Compilation (`@cfg`)

The `@cfg(...)` attribute controls whether a declaration (function, type, or constant) is compiled based on the target OS, backend, or build profile:

### Platform-Specific Implementations:
```delsafe
module platform_demo;

interface

function GetOSName() return String;

implementation

@cfg(target_os = "windows")
function GetOSName() return String is
begin
    return "Microsoft Windows";
end GetOSName;

@cfg(target_os = "linux")
function GetOSName() return String is
begin
    return "GNU/Linux";
end GetOSName;

@cfg(target_os = "darwin")
function GetOSName() return String is
begin
    return "Apple macOS";
end GetOSName;

end platform_demo.
```

### Supported `@cfg` Queries:
- `@cfg(target_os = "windows" | "linux" | "darwin")` or `@cfg(windows)` / `@cfg(linux)`
- `@cfg(not(windows))`
- `@cfg(target = "pascal" | "c" | "wasm" | "js")`
- `@cfg(debug)` and `@cfg(release)`

### Inactive Branch AST Pruning:
Inactive `@cfg` blocks are **pruned from the AST before type-checking**. This means:
- No collision errors for functions with the same name across different platforms.
- Types not supported on a platform are completely omitted from the emitted binary.

---

## 2. Inlining Control: `@inline(always)` & `@inline(never)`

In performance-critical hot loops, function call overhead (stack frame push/pop) can be eliminated by inlining:

```delsafe
module inline_demo;

interface

@inline(always)
function VectorDotProduct(x1, y1, x2, y2: Float64) return Float64;

@inline(never)
procedure SlowLogOperation(msg: String);

implementation

@inline(always)
function VectorDotProduct(x1, y1, x2, y2: Float64) return Float64 is
begin
    return (x1 * x2) + (y1 * y2);
end VectorDotProduct;

@inline(never)
procedure SlowLogOperation(msg: String) is
begin
    PrintLn("[AUDIT LOG] " + msg);
end SlowLogOperation;

end inline_demo.
```

### Backend Code Generation:
- **Free Pascal:** Emits native `inline;` directives.
- **C99 / GCC:** Emits `static inline __attribute__((always_inline))` or `__attribute__((noinline))`.

---

## 3. Optimizing Branch Prediction: `@cold`

Error handling routines or panic handlers are rarely executed. Annotating them with `@cold` instructs the CPU branch predictor to favor the happy path:

```delsafe
@cold
procedure OnCriticalStorageFailure(errorCode: Int32) is
begin
    PrintLn("CRITICAL ERROR: Disk write failed with code: " + IntToStr(errorCode));
    // Rare failure recovery
end OnCriticalStorageFailure;
```

On GCC/Clang, this emits `__attribute__((cold))`, moving the cold code to a separate memory section and keeping the CPU L1 instruction cache hot for high-throughput loops.

---

## 4. Low-Level Intel Inline Assembly (`asm ... end asm;`)

For kernel hooks, hardware instructions (`rdtsc`, `nop`, CPU fences), or tight low-level sequences, DelSafe supports **Intel-syntax inline assembly** blocks enclosed in `asm ... end asm;`:

```delsafe
module asm_demo;

@cfg(target_arch = "x86_64")
procedure ExecuteLowLevelProbe is
begin
    asm
        nop
        rdtsc
        mov eax, 42
        add eax, 8
    end asm;
end ExecuteLowLevelProbe;

program Main;
begin
    asm
        nop
        nop
    end asm;

    ExecuteLowLevelProbe();
    PrintLn("Inline assembly executed cleanly!");
end asm_demo.
```

See also the full runnable example at [examples/stdlib_and_systems/inline_assembly_intel.dels](../../examples/stdlib_and_systems/inline_assembly_intel.dels).

### How `asm ... end asm;` Targets Both Backends:
- **Free Pascal Backend:** Emits `{$ASMMODE INTEL}` followed by `asm ... end;`.
- **C99 (GCC / Clang) Backend:** Wraps each instruction inside `__asm__ volatile (".intel_syntax noprefix\n\t" ... ".att_syntax prefix");`, restoring AT&T syntax afterward so surrounding C code is unaffected.

### Safety & Best Practices:
1. **Explicit Closing:** Every `asm` block must terminate with `end asm;` (bare `end;` is rejected by the parser).
2. **Portability with `@cfg`:** Guard architecture-specific instructions (like `rdtsc` or `eax`) with `@cfg` when targeting ARM64 or WebAssembly.
3. **Register & Memory Discipline:** Inline assembly bypasses high-level type and borrow checks inside the block; pair raw pointer operations outside `asm` with `unsafe ... end unsafe;` and preserve callee-saved registers.

---

## 5. Compile-Time Folding (`comptime`) & `--release` / `--opt` Builds

DelSafe's AST optimizer evaluates constant arithmetic, boolean expressions, and string literal concatenations at compile time, eliminates dead branches (`if false then ...`), and passes native optimization flags when building with `--release` (`-O3 -XX -Xs` for FPC, `-O3 -flto -s` for GCC/Clang) or `--opt` (`-O`).

---

## 6. Summary
1. Use `@cfg` for clean cross-platform code without `#ifdef` spaghetti.
2. Use `@inline(always)` on small, frequently called computational kernels and `@cold` on rare error branches.
3. Use `asm ... end asm;` when direct Intel-syntax CPU instructions are required across both Pascal and C99 backends.
4. Build production binaries with `--release` (or `--opt`) to enable AST constant folding and dead-code elimination.

➡️ **Next:** **[Chapter 11: FFI & Zero-Boilerplate Interoperability](11_FFI_AND_INTEROPERABILITY.md)**
