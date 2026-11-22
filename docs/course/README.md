# Aether Masterclass: The Complete Course 🚀

Welcome to the official, in-depth **Aether Programming Language Course**!

Aether combines the structural elegance and readability of Pascal with modern systems programming guarantees: **compile-time memory safety via an affine Borrow Checker**, **Design-by-Contract (DbC)**, **algebraic types with pattern matching**, and **seamless zero-boilerplate C & Pascal interoperability** — all with zero garbage collection overhead.

---

## 🎯 Target Audience
- **Systems & Backend Engineers:** Seeking native performance, predictable sub-millisecond latency, zero garbage collector pauses, and fearless memory safety without obscure syntax.
- **Pascal / Delphi Developers:** Transitioning to a modern, type-safe, open-source language with modern tooling (LSP, package manager, profiler, linter, test runner).
- **C / C++ / Rust Developers:** Looking for ultra-fast compilation speeds, clean readable code, and modern compile-time ownership guarantees without cognitive overload.

---

## 📚 Curriculum

| Chapter | Title | Focus & Core Concepts |
| :--- | :--- | :--- |
| **[01. Getting Started](01_GETTING_STARTED.md)** | Toolchain & Workflow | Hello World, module hierarchy, 1-click build scripts, CLI targets (`fpc`, `gcc`, `wasm`). |
| **[02. Variables, Types & Mutability](02_VARIABLES_TYPES_MUTABILITY.md)** | Type Foundations | `let` vs `var`, integer/float hierarchies, string semantics, type inference, immutability by default. |
| **[03. Control Flow & Pattern Matching](03_CONTROL_FLOW_AND_MATCH.md)** | Deterministic Execution | Unambiguous `if...then...else...end;`, loops, algebraic enums, and compile-time exhaustive `match`. |
| **[04. Functions & Contracts](04_FUNCTIONS_AND_CONTRACTS.md)** | Design by Contract (DbC) | Signatures, pre-conditions (`require`), post-conditions (`ensure`), debug vs release assertion modes. |
| **[05. The Borrow Checker](05_THE_BORROW_CHECKER.md)** | Memory Safety | Ownership semantics, move semantics (`take`), immutable borrows (`borrow`), mutable borrows (`mut borrow`), aliasing XOR mutability. |
| **[06. Records & UFCS](06_RECORDS_AND_UFCS.md)** | Data Modeling | Value-type records, fast constructors, memory layout, Uniform Function Call Syntax (`val.method()`). |
| **[07. Traits, Generics & Derives](07_TRAITS_GENERICS_AND_DERIVES.md)** | Modern Abstractions | Interfaces without inheritance, trait bounds (`<T: Bound>`), compiler derivations (`Debug`, `JSON`, `Clone`, `Equals`). |
| **[08. Error Handling (Result & Option)](08_ERROR_HANDLING_RESULT_OPTION.md)** | Safe Error Handling | Monadic handling, eliminating null-pointer crashes, `Option<T>` and `Result<T, E>`. |
| **[09. Async/Await & Concurrency](09_ASYNC_AWAIT_AND_CONCURRENCY.md)** | Non-blocking Systems | `async function`, `AetherTask`, cooperative event loops, worker threads, and structured concurrency. |
| **[10. Conditional Compilation & Optimizations](10_CONDITIONAL_COMPILATION_AND_OPTIMIZATIONS.md)** | Target Tuning | `@cfg(target_os)`, `@inline(always)`, `@cold` branch prediction, and `comptime` constant folding. |
| **[11. FFI & Zero-Boilerplate Interop](11_FFI_AND_INTEROPERABILITY.md)** | Universal Bridges | Direct consumption of C headers (`<math.h>`) and Pascal units (`SysUtils`), explicit `extern c`, C header generation. |
| **[12. Modules, Projects & Packages](12_MODULES_PACKAGES_AND_DEPENDENCIES.md)** | Code Organization | Multi-file projects, 1:1 module mapping, `aether.json` manifest, `aetherc pkg` manager, and lockfile security. |
| **[13. Capstone Project](13_CAPSTONE_PROJECT.md)** | End-to-End System | Building an in-memory secure cache service with JSON serialization, contracts, and zero memory leaks. |

---

## 🛠 Prerequisites & Quick Setup
You can build the native compiler and run tests immediately using the provided root scripts:

```powershell
# Windows (PowerShell)
.\build.ps1

# Windows (Command Prompt)
build.bat

# Linux / macOS
chmod +x build.sh && ./build.sh
```

Proceed to **[Chapter 01: Getting Started](01_GETTING_STARTED.md)** to write and run your first Aether program!
