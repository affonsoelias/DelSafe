# Chapter 01: Getting Started with DelSafe

Welcome to your first step into DelSafe development! In this chapter, you will understand the architecture of a DelSafe source file, how to scaffold structured projects with `delsafec new`, how library Units (`interface` / `implementation`) work, and how to use the compiler CLI for multi-target native builds.

---

## 1. Anatomy of a DelSafe Source File

Every DelSafe file begins with a **module declaration** (`module <Name>;`) that strictly matches the file name (case-insensitive canonical match, ignoring leading digits or underscores; mismatch raises Error `E0005`).

Create a file named `hello.dels`:

```delsafe
module hello;

program Main;
begin
    PrintLn("Hello, World! Welcome to DelSafe.");
end hello.
```

### Key Rules:

1. **Module Header:** `module <Name>;` must be the first active statement.
2. **Program Entry Point (`program Main;`):** Executable modules must name the entry block `program Main;` (other names like `program HelloDelSafe;` are rejected with Error `E0002`).
3. **Named Module Closing (`end <ModuleName>.`):** An executable module closes with `end <ModuleName>.` (matching the `module <ModuleName>;` header, followed by a trailing dot `.`).
4. **Semicolons:** Like Pascal, statements terminate with semicolons `;`.

---

## 2. Checking Your Environment, Compiling, and Running

First, verify that Free Pascal (`fpc`), GCC/Clang, `pkg-config`, and optional Pas2JS are detected:

```bash
delsafec --doctor
```

Now compile and run `hello.dels` using the native compiler:

```bash
# Compile and output binary to bin/
delsafec hello.dels -o bin/hello.exe

# Run immediately
./bin/hello.exe
```

### Multi-Backend Support Out of the Box:

DelSafe supports native transpilation to **Object Pascal (Free Pascal)**, **C99 (GCC/Clang)**, **WebAssembly (Clang)**, and **JavaScript (Pas2JS)**:

```bash
# Target Free Pascal (Default)
delsafec hello.dels --target=pascal -o bin/hello_pas.exe

# Target C99 via GCC (or --cc=clang)
delsafec hello.dels --target=c -o bin/hello_c.exe

# Target WebAssembly (.wasm) via Clang
delsafec hello.dels --target=wasm -o bin/hello.wasm
```

---

## 3. Creating a Structured Project (`delsafec new`)

For real-world applications with multiple modules, tests, and external dependencies, scaffold a complete project using `delsafec new` (or its alias `delsafec init`):

```bash
# Create a new project in a new folder
delsafec new my_app
cd my_app

# Or initialize inside the current empty directory
delsafec new .
```

This generates the canonical DelSafe project layout:

```text
my_app/
├── delsafe.json           <- Manifest (entry, backend, paths, outputs, dependencies)
├── src/
│   └── my_app.dels        <- Executable entry point (module My_app; program Main;)
├── tests/
│   └── my_app_test.dels   <- Automated test suite
├── bin/                   <- Compiled binaries
├── .gitignore
└── README.md
```

Inside the project directory, run:

```bash
delsafec build             # Compile the project defined in delsafe.json
delsafec run               # Compile and execute immediately
delsafec test              # Run tests in tests/ (or --target=all for FPC + C99)
```

---

## 4. The Compiler Toolchain Suite

The `delsafec` compiler comes equipped with built-in developer tools:

| Command                                | Purpose                                                                                               |
|:-------------------------------------- |:----------------------------------------------------------------------------------------------------- |
| `delsafec --doctor`                    | Diagnoses installed toolchains (`fpc`, `gcc`, `clang`, MSYS2, `pkg-config`, and `pas2js`).            |
| `delsafec new [name \| .]`             | Scaffolds a new project with `delsafe.json`, `src/`, and `tests/`.                                    |
| `delsafec build` / `delsafec run`      | Compiles (or compiles and executes) the project configured in `delsafe.json`.                         |
| `delsafec <file.dels> --check-only`    | Runs parsing, semantic analysis, and borrow checking without emitting binaries (fast validation).     |
| `delsafec test [filter]`               | Automatically discovers and executes unit tests in `tests/` (`--target=pascal\|c\|all`).              |
| `delsafec lint [path] [--fix]`         | Runs static code quality analysis and optionally cleans unused imports.                               |
| `delsafec fmt [path]`                  | Canonical code formatter according to official style guidelines.                                      |
| `delsafec doc [path]`                  | Generates HTML and Markdown documentation (`--test` runs embedded doctests).                          |
| `delsafec profile <file.dels>`         | Compiles with heap instrumentation, profiling execution and certifying zero memory leaks.             |
| `delsafec emit-header <file.dels>`     | Generates ANSI C/C++ header files (`.h`) for exported libraries.                                      |
| `delsafec channel [stable \| nightly]` | Views or switches the persistent default release channel.                                             |
| `delsafec upgrade`                     | Self-updates the DelSafe compiler toolchain (`--check`, `--binary`, `--from-source`, `--rollback`).   |

---

## 5. Hands-on Exercise: A Two-Module Program (Unit + Application)

Any library module **without** `program Main;` is a **Unit** in the Object Pascal tradition and **must** declare explicit `interface` and `implementation` sections, Ada-style `return <Type> is`, and named `end <Routine>;` / `end <Module>.` closers.

Create `math_utils.dels`:

```delsafe
module math_utils;

interface

function DoubleValue(x: Int32) return Int32;

implementation

function DoubleValue(x: Int32) return Int32 is
begin
    return x * 2;
end DoubleValue;

end math_utils.
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
end app.
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
