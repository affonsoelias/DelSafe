# Chapter 11: Foreign Function Interface (FFI) & Zero-Boilerplate Interoperability

> **"Aether is not an isolated island. It is a modern bridge."**

One of the greatest pitfalls of new systems programming languages is the **"Rewrite Trap"** — forcing teams to rewrite millions of lines of proven C libraries, operating system APIs, and Pascal components from scratch.

Aether takes the opposite approach. Interoperability is the **crown jewel of the language**. Aether provides **seamless, bidirectional, zero-cost integration** with both the vast C99/C++ ecosystem and the rich Free Pascal / Delphi landscape.

---

## 🗺️ The Dual-Bridge Architecture

Aether features a unified compilation architecture that allows simultaneous communication with C and Pascal:

```
                  ┌──────────────────────────────────────────────┐
                  │           Aether Source Code (.aeth)         │
                  │   (Type-safe, Borrow-checked, Contracts)     │
                  └──────────────────────┬───────────────────────┘
                                         │
                    ┌────────────────────┴───────────────────┐
                    ▼                                        ▼
   ┌────────────────────────────────┐       ┌────────────────────────────────┐
   │     C99 / C++ Native Bridge    │       │   Object Pascal (FPC) Bridge   │
   │  • import c "<header.h>"       │       │  • import pascal UnitName      │
   │  • extern c "lib" function     │       │  • extern pascal function      │
   │  • export cdecl (emit-header)  │       │  • emit pascal --unit          │
   └────────────────────────────────┘       └────────────────────────────────┘
                    │                                        │
                    ▼                                        ▼
   ┌────────────────────────────────┐       ┌────────────────────────────────┐
   │   GCC / Clang Native Binary    │       │    Free Pascal Native Binary   │
   │   (Linux / macOS / Windows)    │       │     (GUI, Lazarus, Services)   │
   └────────────────────────────────┘       └────────────────────────────────┘
```

In this chapter, you will learn the 5 levels of Aether interoperability, step-by-step.

---

## 🌟 Level 1: Zero-Boilerplate Auto-Import (No `extern` Required!)

In most systems languages, calling an external function requires manually copying C signatures, creating tedious header bindings, and maintaining fragile binding wrappers.

In Aether, **standard libraries are auto-imported with zero boilerplate**.

### How it Works:
1. You write `import c "<header.h>";` for C standard library headers.
2. You write `import pascal UnitName;` for Free Pascal / Delphi standard units.
3. The Aether compiler **automatically resolves the symbol names, arguments, return types, and linkage** — with **ZERO manual `extern` declarations**!

### Step-by-Step Practical Example:

Create `interop_auto.aeth`:

```aether
module interop_auto;

// 1. Auto-import Free Pascal standard units
import pascal SysUtils;
import pascal DateUtils;

// 2. Auto-import C99 standard library headers
import c "<math.h>";
import c "<stdio.h>";

program Main;
var
    start_ticks: UInt64;
    angle: Float64;
    sin_result: Float64;
    hypotenuse: Float64;
begin
    PrintLn("=== ZERO-BOILERPLATE INTEROP DEMO ===");

    // Step 1: Call Free Pascal's SysUtils.GetTickCount64() directly:
    start_ticks := GetTickCount64();
    PrintLn("System uptime ticks: " + IntToStr(Int32(start_ticks)));

    // Step 2: Call C99 <math.h> trigonometry directly:
    angle := 0.785398; // ~45 degrees
    sin_result := sin(angle);
    PrintLn("C sin(45 deg) = " + FloatToStr(sin_result));

    // Step 3: Call C99 <math.h> sqrt directly:
    hypotenuse := sqrt(9.0 + 16.0); // sqrt(25) = 5.0
    PrintLn("C sqrt(3^2 + 4^2) = " + FloatToStr(hypotenuse));

    PrintLn("\nSuccess: C and Pascal called with zero manual binding lines!");
end.
```

### Compiling and Running:
```bash
# Compile and run with Free Pascal backend:
aetherc interop_auto.aeth -o bin/interop_pas.exe
./bin/interop_pas.exe

# Compile and run with GCC C99 backend:
aetherc interop_auto.aeth --target=c -o bin/interop_c.exe
./bin/interop_c.exe
```

Output on both targets:
```text
=== ZERO-BOILERPLATE INTEROP DEMO ===
System uptime ticks: 48920114
C sin(45 deg) = 0.707107
C sqrt(3^2 + 4^2) = 5
Success: C and Pascal called with zero manual binding lines!
```

---

## ⚡ Level 2: Explicit C FFI (`extern c`) & Dynamic Libraries

When consuming **custom C libraries, third-party DLLs (`.dll`, `.so`, `.dylib`), operating system APIs, or graphics libraries (Raylib, SQLite3, SDL2)**, you declare them explicitly using `extern c`.

### 1. Anatomy of an `extern c` Declaration

```aether
// Format:
// extern c ["optional_library_name"] function Name(param: Type): ReturnType;

// Case A: Standard C runtime (libc / msvcrt)
extern c function puts(s: String): Int32;

// Case B: Dynamic shared library (.dll / .so)
extern c "sqlite3" function sqlite3_libversion(): String;
extern c "raylib" function InitWindow(width: Int32, height: Int32, title: String): Void;
```

### 2. Calling Conventions: `cdecl` vs `stdcall`

By default, `extern c` uses the standard **`cdecl`** calling convention. For Windows Win32 APIs, specify `stdcall`:

```aether
extern c "kernel32" stdcall function GetCurrentProcessId(): UInt32;
```

---

## 📊 Type Mapping Reference: Aether to C99

When interfacing with C, types map directly according to the C ABI without conversion overhead:

| Aether Type | C99 Native Type | Notes |
| :--- | :--- | :--- |
| `Int8` | `int8_t` / `signed char` | Exact 8-bit signed integer |
| `Int16` | `int16_t` / `short` | Exact 16-bit signed integer |
| `Int32` | `int32_t` / `int` | Standard 32-bit integer |
| `Int64` | `int64_t` / `long long` | Exact 64-bit signed integer |
| `UInt8` (`Byte`) | `uint8_t` / `unsigned char` | Raw byte / unsigned 8-bit |
| `UInt16` | `uint16_t` / `unsigned short` | Unsigned 16-bit |
| `UInt32` | `uint32_t` / `unsigned int` | Unsigned 32-bit |
| `UInt64` | `uint64_t` / `unsigned long long` | Unsigned 64-bit |
| `Float32` | `float` | 32-bit single precision |
| `Float64` | `double` | 64-bit double precision |
| `Bool` | `bool` / `int` | Boolean (`1` or `0`) |
| `String` | `const char*` / `PChar` | Null-terminated UTF-8 string pointer |
| `Ptr` | `void*` | Raw memory address pointer |

---

## 🛡️ Superpower: Attaching Contracts to Foreign C Functions!

One of the most dangerous aspects of C libraries is that passing invalid arguments (e.g. negative numbers, out-of-bounds indices, null pointers) leads to crashes or memory corruption.

In Aether, **you can attach Design-by-Contract (`require`) to foreign C functions**! The Aether compiler verifies the pre-condition *before* execution ever enters the C runtime:

```aether
module safe_c_contracts;

// Foreign C function wrapped in a contract:
extern c function sqrt(x: Float64): Float64
contract
    require
        x >= 0.0; // The C function will NEVER receive a negative number!
;

extern c function puts(s: String): Int32
contract
    require
        Length(s) > 0; // Guard against empty or null strings
;

program Main;
var
    val: Float64;
begin
    val := sqrt(144.0); // OK!
    PrintLn("Square root: " + FloatToStr(val));

    // This contract violation will be caught by Aether BEFORE touching C:
    // val := sqrt(-25.0); // Contract Violation: Pre-condition 'x >= 0.0' failed!
end.
```

---

## 🏛️ Level 3: Interoperating with Object Pascal Units (`extern pascal`)

If you have legacy Pascal code or specialized Free Pascal units without auto-import headers, declare them with `extern pascal`:

```aether
module custom_pascal;

// Consuming Pascal functions with native Pascal ABI
extern pascal function FormatDateTime(fmt: String; dt: Float64): String;

program Main;
var
    formatted: String;
begin
    formatted := FormatDateTime("YYYY-MM-DD", 45000.0);
    PrintLn("Formatted date: " + formatted);
end.
```

---

## 📤 Level 4: Exporting Aether to C, C++, Python & Rust (`emit-header`)

Interoperability in Aether is **bidirectional**. You can write high-performance, memory-safe algorithms in Aether and export them to external ecosystems:

### Step 1: Write your Aether library with `export cdecl`

Create `algorithms.aeth`:

```aether
module algorithms;

export cdecl function ComputeHash(data: String): UInt32
var
    hash: UInt32;
    i: Int32;
begin
    hash := 5381;
    i := 1;
    while i <= Length(data) do
        hash := ((hash * 33) + UInt32(Byte(data[i])));
        i := i + 1;
    end;
    return hash;
end;

export cdecl function FastMultiply(a: Int32, b: Int32): Int32
begin
    return a * b;
end;
```

### Step 2: Automatically Generate C Header (`.h`)

Run the Aether header generator:

```bash
aetherc emit-header algorithms.aeth -o include/algorithms.h
```

Output:
```text
Cabecalho C (C99/C++) gerado com sucesso:
  --> include/algorithms.h
```

Inspect `include/algorithms.h`:

```c
#ifndef AETHER_ALGORITHMS_H
#define AETHER_ALGORITHMS_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifdef _WIN32
  #define AETHER_EXPORT __declspec(dllexport)
#else
  #define AETHER_EXPORT __attribute__((visibility("default")))
#endif

AETHER_EXPORT uint32_t ComputeHash(const char* data);
AETHER_EXPORT int32_t FastMultiply(int32_t a, int32_t b);

#ifdef __cplusplus
}
#endif

#endif // AETHER_ALGORITHMS_H
```

### Step 3: Consuming from C or C++

Now any standard C or C++ application can include `algorithms.h` and link directly with your Aether library:

```c
// main.c (C Application consuming Aether)
#include <stdio.h>
#include "algorithms.h"

int main() {
    uint32_t hash = ComputeHash("AetherLang");
    int32_t prod = FastMultiply(6, 7);

    printf("Hash computed by Aether: %u\n", hash);
    printf("Multiplication: %d\n", prod);
    return 0;
}
```

---

## 🧰 Level 5: Compiler CLI Flags for External Linking

When linking external native libraries, `aetherc` provides familiar GNU/Clang CLI flags:

| Flag | Purpose | Example |
| :--- | :--- | :--- |
| `-l<lib>` | Link with a system or dynamic library | `aetherc app.aeth -lsqlite3 -lraylib` |
| `-L<dir>` | Add directory to the library search path | `aetherc app.aeth -L./libs -lmylib` |
| `-I<dir>` | Add directory to C header search path | `aetherc app.aeth -I./include` |
| `-Fu<dir>` | Add Free Pascal unit search path | `aetherc app.aeth -FuC:/lazarus/components` |
| `--c-source <file.c>` | Compile an extra `.c` source file into the final binary | `aetherc app.aeth --c-source helper.c` |
| `--shared-lib <file.dll>` | Automatically copy dynamic library to the executable output folder | `aetherc app.aeth --shared-lib sqlite3.dll` |

---

## 💡 FFI Best Practices & Memory Safety Checklist

When bridging between Aether and foreign code, follow these three golden rules:

1. **Strings across boundaries:** Aether `String` values passed to C `extern c` routines are passed as null-terminated UTF-8 C strings (`const char*`).
2. **Contracts on FFI:** Always attach `contract require` to foreign C functions that have constraints (e.g. non-null, valid bounds, positive numbers).
3. **Memory Ownership:** Memory allocated by C (e.g. via `malloc`) should be freed by C (via `free`); memory managed by Aether's Borrow Checker is cleaned up automatically by Aether.

---

## 🏁 Summary
- **For standard math/system functions:** Use **Zero-Boilerplate** `import c "<header.h>"` and `import pascal UnitName`.
- **For custom DLLs/libraries:** Declare explicitly with `extern c "libname" function ...`.
- **For safety:** Protect foreign C routines with Aether `contract require`.
- **For exporting:** Use `export cdecl` and generate C headers with `aetherc emit-header`.

➡️ **Next:** **[Chapter 12: Capstone Project (Building a Real-World Service)](12_CAPSTONE_PROJECT.md)**
