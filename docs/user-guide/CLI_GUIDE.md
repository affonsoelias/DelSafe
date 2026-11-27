# Complete DelSafe CLI Guide (`delsafec`)

The official DelSafe compiler (`delsafec`) is an all-in-one toolchain for native compilation, project scaffolding, package management, security auditing, formatting, testing, benchmarking, and IDE integration.

---

## 1. Command Syntax Overview

```bash
delsafec <command | file.dels> [options]
```

---

## 2. Build and Execution Commands

### `delsafec build`
Compiles the project defined by the `delsafe.json` manifest in the current directory or parent folders.
- Automatically restores missing dependencies from `.delsafe/deps/`.
- Runs parsing, type checking, and the *Borrow Checker*.
- Transpiles output into `generated/pascal/` or `generated/c/`.
- Invokes the native compiler (FPC, GCC, or Clang) and places the binary inside `bin/`.

```bash
delsafec build
delsafec build --target=c
delsafec build --target=c --cc=clang
delsafec build --target=wasm --html -o public/module.wasm
delsafec build --target=js --html -o public/module.js
```

### Compilation Targets (`--target`):
- `--target=pascal`: Compiles to a native binary via Object Pascal and Free Pascal (default).
- `--target=c`: Compiles to a native binary via C99 (using GCC or Clang).
- `--target=wasm`: Compiles directly to a standalone WebAssembly module (`.wasm`) via **Clang** (`clang --target=wasm32 -nostdlib -Wl,--no-entry -Wl,--export-all`).
- `--target=js`: Compiles directly to modular JavaScript (`.js`) via **Pas2JS** (`pas2js -Jc`).

### C Compiler Selection (`--cc` / `--c-compiler`):
- `--cc=gcc`: Uses GCC (e.g., MinGW-w64 UCRT64 on Windows).
- `--cc=clang`: Uses Clang / LLVM (native C99 and WebAssembly cross-compilation).

### Browser HTML Runner (`--html`):
When `--html` is passed together with `--target=wasm` or `--target=js`, the compiler automatically generates a styled `.html` file with an embedded browser runner:
- For `.wasm`: instantiates WebAssembly with `WebAssembly.instantiateStreaming` and exposes exports on `window.delsafeWasm`.
- For `.js`: copies Pas2JS's `rtl.js` runtime and initializes modules under `window.pas`.

### `delsafec run`
Compiles the project application and runs it immediately in the terminal:
```bash
delsafec run
delsafec run --target=c
```

### `delsafec test [filter | path] [options]`
Runs the automated unit test suite under `tests/` or executes a specific test file directly:
```bash
# Run all tests (*.dels in tests/)
delsafec test

# Run tests with the native C99 backend
delsafec test --target=c

# Run only tests whose filename contains "math"
delsafec test math

# Run a single test file directly (with or without delsafe.json)
delsafec test tests/01_suite_matematica_test.dels
```
Tests use the built-in assertion statement:
```delsafe
Assert(condition, "Descriptive failure message");
```

### `delsafec bench [filter] [function_filter] [options]`
Runs the project's canonical benchmark suite (`benches/*_bench.dels` or explicitly specified `.dels` files):

```bash
# Run all benchmarks in benches/ on the default backend (Free Pascal)
delsafec bench

# Compare Free Pascal vs GCC C99 side by side
delsafec bench --compare

# Filter by file and/or benchmark procedure name
delsafec bench math Fib
delsafec bench benches/math_bench.dels --iters=500

# Output structured JSON for CI/CD pipelines
delsafec bench --compare --json
```

**Benchmark Syntax (`@bench`):**
```delsafe
module math_bench;

function Fibonacci(n: Int32) return Int32;
...

/// @bench
procedure BenchFibonacci is
var
    res: Int32;
begin
    res := Fibonacci(30);
end BenchFibonacci;
```

Benchmark options:
- `--compare`, `--all-targets`: Compiles and runs benchmarks on both backends (`Free Pascal` and `GCC C99`), reporting execution speed and highlighting the winner (`[FASTEST - X% faster]`).
- `--json`, `--format=json`: Machine-readable JSON output (no banners) with iterations, `avg_ms`, `std_dev_ms`, and `ops_per_sec`.
- `--iters=<N>`: Configures iteration count per benchmark (default: 100).
- `--target=<pascal|c>`: Selects a single backend target.

### `delsafec clean`
Safely removes all build artifacts from the current project (`bin/`, `generated/`, and `.delsafe/cache/build/`), preserving source code and the compiler:
```bash
delsafec clean
```

### `delsafec upgrade [options]`
Updates the DelSafe compiler toolchain to the latest version from the official release repository or local Git source:
```bash
# Check whether a new version is available without downloading
delsafec upgrade --check

# Update toolchain automatically (detects git repo or downloads official binary)
delsafec upgrade

# Force update from official prebuilt binary release
delsafec upgrade --binary

# Rebuild from local Git repository source
delsafec upgrade --from-source

# Update to a specific version tag
delsafec upgrade --version=v0.6.0

# Simulate the upgrade without modifying files on disk
delsafec upgrade --dry-run

# Roll back immediately to the previous compiler binary
delsafec upgrade --rollback
```

**Upgrader Highlights:**
- **Zero External Dependencies**: Uses native `curl` and `tar` (`bsdtar`) available on Windows 10/11, Linux, and macOS.
- **Atomic Replacement on Windows**: Moves the running executable to `delsafec.exe.bak`, installs the new version in place, verifies integrity, and automatically rolls back on failure.
- **SHA-256 Cryptographic Verification**: Validates the downloaded archive hash against the official release signature before extraction (Error `E9991` on mismatch).
- **Instant Rollback**: `--rollback` restores the previous working binary immediately.

### `delsafec channel [stable | nightly]`
View or switch the persistent default release channel saved in `~/.delsafe/config.json` (used by `delsafec upgrade` and shown in `delsafec --version`):
```bash
# Display the currently active release channel
delsafec channel

# Switch default updates to weekly nightly pre-releases
delsafec channel nightly

# Switch default updates back to official SemVer releases
delsafec channel stable

# Explicit set syntax
delsafec channel set nightly

# One-off override via environment variable
DELSAFE_CHANNEL=nightly delsafec upgrade --check
```

Channel precedence: `--nightly` / `--channel=<name>` CLI flags > `DELSAFE_CHANNEL` environment variable > `~/.delsafe/config.json` > `stable` (default).

---

## 2.1 Incremental Compilation & Cache System (`--incremental`)

DelSafe features a high-performance **SHA-256** incremental compilation engine that tracks every source file and all of its transitive imports (`import std.fs;`, `import std.http;`, etc.).

### Incremental Flags:
- `--incremental`: Enables cache tracking. If the output executable already exists and neither the entry file nor any transitive dependency changed, compilation returns **immediately** (`0 ms`), reusing the cached binary.
- `--force`: Ignores cached manifests and forces a full end-to-end rebuild.
- `--no-incremental`: Disables incremental cache checks for the current invocation.

```bash
# Fast incremental build
delsafec build src/main.dels --incremental

# Incremental run
delsafec run src/main.dels --incremental

# Force full rebuild ignoring cache
delsafec build src/main.dels --incremental --force
```

Incremental build manifests are saved inside `.delsafe/cache/build/` in deterministic JSON format.

---

## 2.2 AST Optimizations & Release Mode (`--release`, `--opt`)

DelSafe includes a built-in AST optimizer (`uDelSafeOptimizer.pas`) for maximum runtime performance and compact executables:

### AST Optimizations:
1. **Constant Folding**:
   - Integer expressions: `24 * 60 * 60` -> `86400`
   - Boolean expressions: `(100 > 50) and (20 = 20)` -> `true`
   - String literal concatenation: `"DelSafe " + "Engine " + "Release"` -> `"DelSafe Engine Release"`
2. **Algebraic Simplifications**:
   - `x + 0` -> `x`, `x - 0` -> `x`, `x * 1` -> `x`, `x / 1` -> `x`, `not (not x)` -> `x`
3. **Dead Code Elimination (DCE)**:
   - `if false then ... else ... end if;`: unreachable `then` branch is discarded at compile time and `else` is promoted.
   - `while false do ... end while;`: statically false loops are removed from the AST.
   - Unreachable statements following an unconditional `return` are pruned from the AST.

### Optimizer & Release Flags:
- `--release`: Enables the AST optimizer and passes aggressive optimization flags to the native backends:
  - **Free Pascal (`fpc`)**: `-O3 -XX -Xs` (level 3 optimizations, smartlinking unused units, symbol stripping). Typical binaries ~110 KB.
  - **GCC C99 (`gcc`)**: `-O3 -flto -s` (level 3 optimizations, Link-Time Optimization, stripped symbols). Ultra-compact binaries ~13 KB.
- `--opt` or `-O`: Enables AST optimization without full release stripping.

```bash
# Production release build
delsafec build src/main.dels --release

# C99 release build
delsafec build src/main.dels --target=c --release -o bin/app.exe

# Run with AST optimizations enabled
delsafec run src/main.dels --opt
```

---

## 3. Code Emission & Transpilation (`delsafec emit`)

The `emit` command generates transpiled source code without requiring immediate native compilation—ideal for inspection, debugging, CI/CD, and **BlaiseVue** integration:

```bash
delsafec emit <pascal | c> [file.dels] [options]
```

### `emit` Options:
- `--unit`: Emits a **Free Pascal Unit** (`unit ...; interface ... implementation ... end.`) for direct consumption in BlaiseVue via `uses MyUnit;`.
- `--out-dir=<path>` or `-d <path>`: Writes generated files into the specified directory (e.g., `.blaisevue/generated/`).
- `--stdout`: Prints generated code directly to stdout for pipes and inspection (`| gcc -x c -`, `> out.c`).
- `--silent` or `-s`: Quiet mode for external build tools (exit code 0 on success, errors on stderr).
- `--watch` or `-w`: Watches the source file and regenerates automatically on save (reactive hot-reload).
- `-o <file>`: Sets the exact output filename.

### Practical `emit` Examples:
```bash
# 1. Emit a Pascal unit for BlaiseVue
delsafec emit pascal src/Store.dels --unit

# 2. Emit directly into a BlaiseVue managed folder
delsafec emit pascal src/Store.dels --unit --out-dir=./generated/blaisevue

# 3. Watch for changes and regenerate on save
delsafec emit pascal src/Store.dels --unit --watch

# 4. Inspect generated C99 output in stdout
delsafec emit c src/main.dels --stdout | head -n 30

# 5. Generate a C header (.h) for exported FFI types and functions
delsafec emit-header src/math_lib.dels -o include/math_lib.h
```

---

### `delsafec emit-header <file.dels> [-o <output.h>]`
Generates an **ANSI C99 / C++ compatible** header (`.h`) with `extern "C"` linkage containing:
- Include guards (`#ifndef DELSAFE_<MODULE>_H`);
- Cross-platform export macro (`DELSAFE_API` / `__declspec(dllexport)`);
- Exported `struct` definitions with C types (`int32_t`, `double`, `bool`, etc.);
- Prototypes for all functions marked `export cdecl function ...`, preserving original doc comments (`///`).

---

## 4. Project & Package Management

### `delsafec new [name | .]`
Scaffolds a new DelSafe project with `delsafe.json`, `src/main.dels`, `tests/main_test.dels`, `.gitignore`, and `README.md`:
```bash
# Create a new project in a new folder:
delsafec new my_project

# Initialize inside the current directory:
delsafec new .
```

### Custom Paths & Native Interop (`paths` in `delsafe.json`)
In `delsafe.json`, the `"paths"` block configures custom `.dels` search directories, C sources/headers, Free Pascal units, native libraries, and automatic DLL/SO copying:

```json
{
  "name": "my_project",
  "version": "0.1.0",
  "backend": "pascal",
  "entry": "src/main.dels",
  "output": "bin/my_project.exe",
  "paths": {
    "delsafe": [
      "src",
      "libs/my_delsafe_lib"
    ],
    "c_includes": [
      "include"
    ],
    "c_sources": [
      "c_src/helper.c"
    ],
    "pascal_units": [
      "pascal_src"
    ],
    "lib_dirs": [
      "lib"
    ],
    "libs": [
      "raylib"
    ],
    "shared_libs": [
      "lib/raylib.dll"
    ]
  }
}
```

- **`delsafe`**: Extra search paths for imported `.dels` modules (`import trees.oak;`).
- **`c_includes`**: C header directories (`.h`), passed as `-I"<path>"`.
- **`c_sources`**: Extra `.c` files compiled and linked into the final binary.
- **`pascal_units`**: Free Pascal unit directories (`.pas`/`.ppu`), passed as `-Fu"<path>"` to FPC (ideal for BlaiseVue).
- **`lib_dirs`**: Static/dynamic library search folders (`-L` for GCC, `-Fl` for FPC).
- **`libs`**: System/library names to link against (e.g., `-lraylib`, `-lsqlite3`).
- **`shared_libs`**: Dynamic libraries (`.dll` on Windows, `.so` on Linux) **automatically copied alongside the binary** (`bin/`) on build/run.

---

### Output Directories & BlaiseVue Integration (`outputs`)

To integrate cleanly with **BlaiseVue** and control generated artifacts, `delsafe.json` supports an `"outputs"` block:

```json
{
  "name": "my_blaise_module",
  "version": "0.1.0",
  "entry": "src/my_module.dels",
  "backend": "pascal",
  "outputs": {
    "bin_dir": "bin",
    "pascal_src_dir": ".blaisevue/generated",
    "pascal_unit_dir": "build/units",
    "c_src_dir": "build/c",
    "as_unit": true
  }
}
```

- **`bin_dir`**: Directory for compiled binaries (default: `bin`).
- **`pascal_src_dir`**: Directory for generated Object Pascal `.pas` files (e.g., `.blaisevue/generated`).
- **`pascal_unit_dir`**: Output directory for compiled FPC `.ppu`/`.o` files (`-FU"<dir>"`).
- **`c_src_dir`**: Directory for generated `.c` files.
- **`as_unit`**: When `true`, emits and compiles DelSafe code as an **Object Pascal Unit** (`unit ... interface ... implementation ... end.`) ready for `uses` in BlaiseVue and Lazarus.

---

### Multi-Target Configuration & C Compilers (`targets` and `c_compiler`)

Projects targeting multiple outputs at once (e.g., WebAssembly, JavaScript, Clang native, and GCC native) can define a `"targets"` array in `delsafe.json`:

```json
{
  "name": "my_multitarget_project",
  "version": "0.1.0",
  "c_compiler": "clang",
  "targets": [
    {
      "name": "web_module",
      "entry": "src/calculator.dels",
      "target": "wasm",
      "backend": "clang",
      "output": "public/calculator.wasm"
    },
    {
      "name": "js_script",
      "entry": "src/calculator.dels",
      "target": "js",
      "backend": "pas2js",
      "output": "public/calculator.js"
    },
    {
      "name": "native_clang_bin",
      "entry": "src/main.dels",
      "target": "c",
      "backend": "clang",
      "output": "bin/app_clang.exe"
    },
    {
      "name": "native_gcc_bin",
      "entry": "src/main.dels",
      "target": "c",
      "backend": "gcc",
      "output": "bin/app_gcc.exe"
    }
  ]
}
```

Running `delsafec build` builds each configured target in sequence.

### Command-Line Path, Output & Interop Flags
You can also specify these flags directly on the CLI:
- `-FE <dir>`: Output directory for compiled executables.
- `-FU <dir>`: Output directory for compiled FPC units (`.ppu` and `.o`).
- `--out-pascal <dir>`: Output directory for generated `.pas` sources.
- `--out-c <dir>`: Output directory for generated `.c` sources.
- `--unit`: Emit/compile as a Pascal Unit (`unit/interface/implementation`).
- `-I <dir>`: Add search path for DelSafe modules and C headers.
- `-Fu <dir>`: Add search path for Free Pascal units (`.pas`/`.ppu`).
- `-L <dir>`: Add native library search folder (`-L` GCC, `-Fl` FPC).
- `-l <lib>`: Link with a system/external library (e.g., `-lraylib`, `-lws2_32`).
- `--c-source <file.c>`: Compile an extra C source file into the executable.
- `--shared-lib <file.dll/.so>`: Copy a shared library to the output directory.
- `--lib` or `--shared`: Build as a **shared dynamic library** (`.dll` on Windows, `.so` on Linux/macOS) exporting `cdecl` symbols.
- `--emit-header`: Automatically generate the matching C header (`.h`) next to the built library.

### `delsafec pkg <subcommand>`
Built-in DelSafe package manager:
- `delsafec pkg add <package>`: Add a Registry, Git (`--git=...`), or local (`--path=...`) dependency to `delsafe.json` and `delsafe.lock`.
- `delsafec pkg remove <package>` (`rm`): Remove dependency and clean local caches.
- `delsafec pkg update [package]` (`upgrade`): Update Git/Registry dependencies and refresh the lockfile.
- `delsafec pkg publish [--registry=<url>] [--dry-run]`: Publish package to the Registry with manifest validation, SemVer, SHA-256 checksum, and signature.
- `delsafec pkg search <term>` (`find`): Search packages in the Registry catalog.
- `delsafec pkg audit`: Verify SHA integrity hashes and TLS policy compliance.
- `delsafec pkg list` (`ls`): Display the declared dependency tree.
- `delsafec pkg clean`: Clear shared cache at `~/.delsafe/cache`.

> **Tip**: `publish` and `search` can also be invoked at root level: `delsafec publish` and `delsafec search <term>`.

---

## 5. Language Tooling & Diagnostics

### `delsafec --doctor`
Verifies installation, paths, and versions of all 4 DelSafe toolchain backends:
1. **Free Pascal (`fpc`)**: Native Object Pascal compiler.
2. **GCC (`gcc`)**: Native C compiler (MSYS2 UCRT64 on Windows, system GCC on Linux/macOS).
3. **Clang / LLVM (`clang`)**: Native C compiler and WebAssembly (`wasm32`) cross-compiler.
4. **Pas2JS (`pas2js`)**: Free Pascal to modular JavaScript compiler.

### `delsafec lsp` (or `--lsp`)
Starts the built-in **Language Server Protocol (LSP)** server, providing completions, hover docs, go-to-definition, and real-time diagnostics for VS Code and compatible editors.

### `delsafec --emit-json-diag`
Runs the compiler emitting structured JSON diagnostics designed for AI agents and IDE tooling:
```bash
delsafec build --emit-json-diag
```

### `delsafec --check-only`
Runs syntax analysis, type checking, and the Borrow Checker without emitting code or binaries (fast validation for CI/linters).

### `delsafec fmt [file | folder] [--check]`
Official canonical code formatter enforcing DelSafe style:
- Canonical 4-space indentation per scope level.
- Standardized spacing around operators (`:=`, `:`, `,`, `;`, `=`, `<`, `>`, `+`, `-`).
- Lossless preservation of string literals, line comments (`//`), and block comments (`/* ... */`).
- Consistent alignment across `module`, `type`, `var`, and `begin ... end` blocks.
- Supports `--check` mode for CI/CD (exits with code 1 on formatting drift).

```bash
# Format a specific file
delsafec fmt src/main.dels

# Format all .dels files recursively
delsafec fmt src/

# Check formatting without writing (CI/CD)
delsafec fmt src/ --check
```

### `delsafec --dump-tokens` and `delsafec --dump-ast`
Prints the lexer token stream or Abstract Syntax Tree (AST) for debugging and compiler study.

---

## 6. Self-Hosting & Closed-Loop Bootstrapping (`delsafec bootstrap`)

The `bootstrap` command executes full *Stage 3 Bootstrapping* to verify self-hosting independence and deterministic output:

```bash
delsafec bootstrap
```

### What it executes:
1. **Stage 1 (Compile the DelSafe Compiler)**: The Pascal bootstrap compiler compiles `compiler/dels/main.dels` using GCC C99 in optimized release mode into `bin/bootstrap/delsafec-stage1.exe`.
2. **Stage 2 (Stage-1 Self-Compilation)**: `delsafec-stage1.exe` emits C99 (`stage2_compiler.c` and `stage2_suite.c`) and builds the Stage 2 binary with GCC.
3. **Stage 3 (Fixed-Point Verification)**: Repeats the cycle in isolation (`stage3_compiler.c`, `stage3_suite.c`).
4. **Runtime & Bit-for-Bit Determinism Check**:
   - Stage 2 and Stage 3 binaries execute and produce identical outputs.
   - SHA-256 digests and byte sizes of Stage 2 and Stage 3 artifacts are compared.
   - Zero-byte diff confirms **FULL CONVERGENCE (Fixed Point)** and **100% BIT-FOR-BIT DETERMINISM**.

---

## 7. Structured Concurrency & Async/Await (`Task<T>`)

Since **Phase 31**, DelSafe supports native structured concurrency and lightweight cooperative tasks (`Task<T>`):

### Syntax & Primitives:
- `async function Name(params) return Type`: Declares an asynchronous function whose return value is wrapped in `Task<Type>`.
- `await <expr>`: Awaits task completion and safely extracts its resolved value.
- `spawn <expr>`: Dispatches an async task, returning a `Task<T>` handle.
- `Task<T>`: Built-in generic task handle (`specialize TDelSafeTask<T>` in Pascal / `DelSafeTask` in C99).

### DelSafe Example:
```delsafe
module async_demo;

async function ComputeStep(n: Int32) return Int32 is
begin
    if n <= 1 then
        return 1;
    end if;
    return n * (n - 1);
end ComputeStep;

program Main;
var
    t1: Task<Int32>;
    outcome: Int32;
begin
    // Dispatch asynchronous execution
    t1 := spawn ComputeStep(5);

    // Await result cooperatively
    outcome := await t1;
    PrintLn("Result: " + IntToStr(outcome));
end async_demo.
```

### Full Multi-Backend Support:
Async tasks run across all compiler backends:
- **Free Pascal**: Native execution (`--target=pascal`).
- **C99 (GCC & Clang)**: Compact native executables (`--target=c`).
- **WebAssembly**: Standalone `.wasm` modules (`--target=wasm`).
- **JavaScript (Pas2JS)**: Browser and NodeJS execution (`--target=js`).

---

## 8. Canonical Documentation Generator (`delsafec doc`)

Since **Phase 32**, DelSafe includes a built-in documentation generator (`delsafec doc`) that parses `.dels` modules, extracts doc comments (`///`), contracts (`require` / `ensure`), ownership modes (`borrow`, `mut borrow`, `take`), and runs doctests automatically.

### Commands & Options:
```bash
# Generate static HTML documentation for the whole project in docs/api/
delsafec doc

# Generate docs for a specific file
delsafec doc src/math_lib.dels

# Custom output directory
delsafec doc --out-dir=public/api

# Export Markdown documentation for Git repositories
delsafec doc --format=md
delsafec doc --format=all

# Open generated site in the default browser
delsafec doc --open

# Extract and run all embedded code examples (Doctests)
delsafec doc --test
```

### Writing Doc Comments (`///`):
```delsafe
/// Numerical and vector computation module.
module math_lib;

/// Creates a 2D vector with non-negative coordinates.
/// @param x Horizontal X component
/// @param y Vertical Y component
/// @return New Vector2D value
///
/// ```delsafe
/// var v: Vector2D := CreateVector(3.0, 4.0);
/// Assert(v.x > 0.0);
/// ```
function CreateVector(x, y: Float64) return Vector2D is
contract
    require
        x >= 0.0;
        y >= 0.0;
    ensure
        result.x >= 0.0;
var
    v: Vector2D;
begin
    v.x := x;
    v.y := y;
    return v;
end CreateVector;
```

### Generated Features:
1. **Responsive Static HTML Site**:
   - `index.html`: Overview dashboard with module index and dependency metrics.
   - `<Module>.html`: Detailed reference page with sidebar, records, enums, traits, and functions.
   - `style.css`: Clean dark/light theme inspired by Rustdoc and VitePress.
   - `search.js`: Instant client-side search index (`Ctrl+K`).
2. **Markdown Export (`API.md`)**:
   - Summary tables, formal contracts, and formatted code blocks ready for GitHub/GitLab.
3. **Automated Doctest Runner (`--test`)**:
   - Extracts embedded code fences containing assertions (`Assert`) and compiles/executes them in isolation so doc examples never rot.
