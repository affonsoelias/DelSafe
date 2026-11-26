# Chapter 10: Conditional Compilation & Optimization Directives

When writing high-performance systems and cross-platform applications, you often need fine-grained control over target platforms, function inlining, and compiler optimization hints.

DelSafe provides this through **`@cfg`**, **`@inline`**, **`@cold`**, and **`comptime`**.

---

## 1. Multiplatform Conditional Compilation (`@cfg`)

The `@cfg(...)` attribute controls whether a declaration (function, type, or constant) is compiled based on the target OS, backend, or build profile:

### Platform-Specific Implementations:
```delsafe
module platform_demo;

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

## 4. Summary
1. Use `@cfg` for clean cross-platform code without `#ifdef` spaghetti.
2. Use `@inline(always)` on small, frequently called computational kernels.
3. Use `@cold` on error branches to maximize hardware cache efficiency.

➡️ **Next:** **[Chapter 11: FFI & Zero-Boilerplate Interoperability](11_FFI_AND_INTEROPERABILITY.md)**
