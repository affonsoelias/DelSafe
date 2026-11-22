# Chapter 11: Foreign Function Interface (FFI) & Zero-Boilerplate Interop

Aether is not an isolated island. It is designed to seamlessly integrate with decades of battle-tested C libraries, operating system APIs, and the rich Free Pascal ecosystem.

---

## 1. Zero-Boilerplate Auto-Import (No `extern` Required!)

For standard C headers (`<math.h>`, `<string.h>`) and Pascal units (`SysUtils`, `Math`), Aether eliminates manual `extern` declarations entirely:

```aether
module interop_auto;

import pascal SysUtils;
import c "<math.h>";

program Main;
var
    start_ticks: UInt64;
    angle: Float64;
    sine_val: Float64;
    hyp: Float64;
begin
    // Direct invocation of Free Pascal's SysUtils.GetTickCount64:
    start_ticks := GetTickCount64();

    // Direct invocation of C99 <math.h> functions:
    angle := 0.785398; // ~45 deg
    sine_val := sin(angle);
    hyp := sqrt(9.0 + 16.0); // sqrt(25) = 5.0

    PrintLn("Sine of 45 deg: " + FloatToStr(sine_val));
    PrintLn("Hypotenuse: " + FloatToStr(hyp));
    PrintLn("System tick: " + IntToStr(Int32(start_ticks)));
end.
```

The Aether compiler detects the imported units/headers and resolves the function signatures and linkages automatically!

---

## 2. Explicit FFI: Calling C Shared Libraries (`extern c`)

When consuming custom C libraries, DLLs (`.dll`), dynamic libraries (`.so` / `.dylib`), or Windows/POSIX APIs, declare them explicitly with `extern c`:

```aether
module custom_c_ffi;

// Declaring libc's puts function
extern c function puts(s: String): Int32;

// Declaring a dynamic library function (e.g. SQLite3 or Raylib)
extern c "sqlite3" function sqlite3_libversion(): String;

program Main;
var
    ret: Int32;
begin
    ret := puts("Printed directly by native C runtime puts()!");
end.
```

---

## 3. Explicit Pascal ABI: Calling Pascal Units (`extern pascal`)

If you want to interoperate with legacy Pascal units without auto-import:

```aether
module custom_pascal_ffi;

extern pascal function FormatDateTime(fmt: String; dt: Float64): String;
```

---

## 4. Exporting Aether Libraries to C / C++ (`aetherc emit-header`)

Aether is bidirectional: you can write high-performance, memory-safe libraries in Aether and export them to C, C++, Rust, or Python!

Annotate exported routines with `export cdecl`:

```aether
module crypto_lib;

export cdecl function ComputeFastChecksum(data: String): UInt32
begin
    // Fast native hash algorithm
    return 4294967295;
end;
```

Compile with header emission:

```bash
aetherc emit-header src/crypto_lib.aeth -o include/crypto_lib.h
```

Aether generates an ANSI C99 / C++ compatible header:

```c
#ifndef AETHER_CRYPTO_LIB_H
#define AETHER_CRYPTO_LIB_H

#ifdef __cplusplus
extern "C" {
#endif

uint32_t ComputeFastChecksum(const char* data);

#ifdef __cplusplus
}
#endif

#endif
```

---

## 5. Summary
1. Standard modules use **Zero-Boilerplate** `import c "<header.h>"` and `import pascal UnitName`.
2. Custom C dynamic libraries use `extern c "libname" function ...`.
3. Export your Aether code to C with `export cdecl` and `aetherc emit-header`.

➡️ **Next:** **[Chapter 12: Capstone Project (Building a Real-World Service)](12_CAPSTONE_PROJECT.md)**
