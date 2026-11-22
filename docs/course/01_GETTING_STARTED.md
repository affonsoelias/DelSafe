# Chapter 01: Getting Started with Aether

Welcome to your first step into Aether development! In this chapter, you will understand the architecture of an Aether source file, how the compilation pipeline works, and how to harness the compiler CLI for multi-target native builds.

---

## 1. Anatomy of an Aether Source File

Every Aether program begins with a **module declaration** that strictly matches the file name (case-insensitive canonical match).

Create a file named `hello.aeth`:

```aether
module hello;

program HelloAether;
begin
    PrintLn("Hello, World! Welcome to Aether.");
end.
```

### Key Rules:
1. **Module Header:** `module <Name>;` must be the first active statement.
2. **Program Block:** The entry point is enclosed in `program <Name>; begin ... end.` (with a trailing dot `.` marking the end of the program).
3. **Semicolons:** Like Pascal, statements terminate with semicolons `;`.

---

## 2. Compiling and Running

Compile and run `hello.aeth` using the native compiler:

```bash
# Compile and output binary to bin/
aetherc hello.aeth -o bin/hello.exe

# Run immediately
./bin/hello.exe
```

### Multi-Backend Support Out of the Box:
Aether supports native transpilation to both **Object Pascal (Free Pascal)** and **C99 (GCC/Clang)**:

```bash
# Target Free Pascal (Default)
aetherc hello.aeth --target=pascal -o bin/hello_pas.exe

# Target C99 via GCC
aetherc hello.aeth --target=c -o bin/hello_c.exe

# Target WebAssembly (.wasm) via Clang
aetherc hello.aeth --target=wasm -o bin/hello.wasm
```

---

## 3. The Compiler Toolchain Suite

The `aetherc` compiler comes equipped with built-in developer tools:

| Command | Purpose |
| :--- | :--- |
| `aetherc check <file.aeth>` | Runs parsing, semantic analysis, and borrow checking without emitting binaries (sub-10ms validation). |
| `aetherc test` | Automatically discovers and executes unit tests in `tests/`. |
| `aetherc lint [path] --fix` | Runs static analysis and automatically cleans unused imports. |
| `aetherc fmt [path]` | Canonical code formatter according to official style guidelines. |
| `aetherc profile <file.aeth>` | Compiles with heap instrumentation, profiling memory allocations and certifying zero leaks. |
| `aetherc emit-header <file.aeth>` | Generates ANSI C/C++ header files (`.h`) for libraries. |
| `aetherc upgrade` | Self-updates the Aether compiler toolchain with SHA-256 verification and atomic rollback. |

---

## 4. Hands-on Exercise: A Two-Module Program

Let's split code into a reusable module and an application program.

Create `math_utils.aeth`:

```aether
module math_utils;

function DoubleValue(x: Int32): Int32
begin
    return x * 2;
end;
```

Now create `app.aeth` in the same directory:

```aether
module app;

import math_utils;

program Main;
var
    val: Int32;
    res: Int32;
begin
    val := 21;
    res := DoubleValue(val);
    PrintLn("Double of 21 is: " + IntToStr(res));
end.
```

Compile and run:
```bash
aetherc app.aeth -o bin/app.exe
./bin/app.exe
```

Output:
```text
Double of 21 is: 42
```

In the next chapter, we dive into Aether's strong static type system, immutability, and numerical hierarchies.

➡️ **Next:** **[Chapter 02: Variables, Types & Mutability](02_VARIABLES_TYPES_MUTABILITY.md)**
