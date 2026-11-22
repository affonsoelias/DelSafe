# Chapter 10: Conditional Compilation & Optimization Directives

When writing high-performance systems and cross-platform applications, you often need fine-grained control over target platforms, function inlining, and compiler optimization hints.

Aether provides this through **`@cfg`**, **`@inline`**, **`@cold`**, and **`comptime`**.

---

## 1. Multiplatform Conditional Compilation (`@cfg`)

The `@cfg(...)` attribute controls whether a declaration (function, type, or constant) is compiled based on the target OS, backend, or build profile:

### Platform-Specific Implementations:
```aether
module platform_demo;

@cfg(target_os = "windows")
function GetOSName(): String
begin
    return "Microsoft Windows";
end;

@cfg(target_os = "linux")
function GetOSName(): String
begin
    return "GNU/Linux";
end;

@cfg(target_os = "darwin")
function GetOSName(): String
begin
    return "Apple macOS";
end;
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

```aether
module inline_demo;

@inline(always)
function VectorDotProduct(x1: Float64, y1: Float64, x2: Float64, y2: Float64): Float64
begin
    return (x1 * x2) + (y1 * y2);
end;

@inline(never)
function SlowLogOperation(msg: String): Void
begin
    PrintLn("[AUDIT LOG] " + msg);
end;
```

### Backend Code Generation:
- **Free Pascal:** Emits native `inline;` directives.
- **C99 / GCC:** Emits `static inline __attribute__((always_inline))` or `__attribute__((noinline))`.

---

## 3. Optimizing Branch Prediction: `@cold`

Error handling routines or panic handlers are rarely executed. Annotating them with `@cold` instructs the CPU branch predictor to favor the happy path:

```aether
@cold
function OnCriticalStorageFailure(errorCode: Int32): Void
begin
    PrintLn("CRITICAL ERROR: Disk write failed with code: " + IntToStr(errorCode));
    // Rare failure recovery
end;
```

On GCC/Clang, this emits `__attribute__((cold))`, moving the cold code to a separate memory section and keeping the CPU L1 instruction cache hot for high-throughput loops.

---

## 4. Summary
1. Use `@cfg` for clean cross-platform code without `#ifdef` spaghetti.
2. Use `@inline(always)` on small, frequently called computational kernels.
3. Use `@cold` on error branches to maximize hardware cache efficiency.

➡️ **Next:** **[Chapter 11: FFI & Zero-Boilerplate Interoperability](11_FFI_AND_INTEROPERABILITY.md)**
