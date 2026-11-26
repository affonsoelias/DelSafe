# Chapter 01: Getting Started with DelSafe

Welcome to your first step into DelSafe development! In this chapter, you will understand the architecture of an DelSafe source file, how the compilation pipeline works, and how to harness the compiler CLI for multi-target native builds.

---

## 1. Anatomy of an DelSafe Source File

Every DelSafe program begins with a **module declaration** that strictly matches the file name (case-insensitive canonical match).

Create a file named `hello.dels`:

```delsafe
module hello;

program HelloDelSafe;
begin
    PrintLn("Hello, World! Welcome to DelSafe.");
end.
```

### Key Rules:

1. **Module Header:** `module <Name>;` must be the first active statement.
2. **Program Block:** The entry point is enclosed in `program <Name>; begin ... end.` (with a trailing dot `.` marking the end of the program).
3. **Semicolons:** Like Pascal, statements terminate with semicolons `;`.

---

## 2. Compiling and Running

Compile and run `hello.dels` using the native compiler:

```bash
# Compile and output binary to bin/
delsafec hello.dels -o bin/hello.exe

# Run immediately
./bin/hello.exe
```

### Multi-Backend Support Out of the Box:

DelSafe supports native transpilation to both **Object Pascal (Free Pascal)** and **C99 (GCC/Clang)**:

```bash
# Target Free Pascal (Default)
delsafec hello.dels --target=pascal -o bin/hello_pas.exe

# Target C99 via GCC
delsafec hello.dels --target=c -o bin/hello_c.exe

# Target WebAssembly (.wasm) via Clang
delsafec hello.dels --target=wasm -o bin/hello.wasm
```

---

## 3. The Compiler Toolchain Suite

The `delsafec` compiler comes equipped with built-in developer tools:

| Command                           | Purpose                                                                                               |
|:--------------------------------- |:----------------------------------------------------------------------------------------------------- |
| `delsafec check <file.dels>`       | Runs parsing, semantic analysis, and borrow checking without emitting binaries (sub-10ms validation). |
| `delsafec test`                    | Automatically discovers and executes unit tests in `tests/`.                                          |
| `delsafec lint [path] --fix`       | Runs static analysis and automatically cleans unused imports.                                         |
| `delsafec fmt [path]`              | Canonical code formatter according to official style guidelines.                                      |
| `delsafec profile <file.dels>`     | Compiles with heap instrumentation, profiling memory allocations and certifying zero leaks.           |
| `delsafec emit-header <file.dels>` | Generates ANSI C/C++ header files (`.h`) for libraries.                                               |
| `delsafec upgrade`                 | Self-updates the DelSafe compiler toolchain with SHA-256 verification and atomic rollback.             |

---

## 4. Hands-on Exercise: A Two-Module Program

Let's split code into a reusable module and an application program.

Create ``:

```delsafe
module math_utils;

function DoubleValue(x: Int32): Int32
begin
    return x * 2;
end;
```

Now create `app.dels` in the same directory:

```delsafe
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
delsafec app.dels -o bin/app.exe
./bin/app.exe
```

Output:

```text
Double of 21 is: 42
```

In the next chapter, we dive into DelSafe's strong static type system, immutability, and numerical hierarchies.

➡️ **Next:** **[Chapter 02: Variables, Types & Mutability](02_VARIABLES_TYPES_MUTABILITY.md)**
