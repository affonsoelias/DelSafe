# DelSafe Masterclass: The Complete Course 🚀

Welcome to the official, in-depth **DelSafe Programming Language Course**!

DelSafe combines the structural elegance and readability of Pascal with modern systems programming guarantees: **compile-time memory safety via an affine Borrow Checker**, **Design-by-Contract (DbC)**, **algebraic types with pattern matching**, and **seamless zero-boilerplate C & Pascal interoperability** — all with zero garbage collection overhead.

---

## 🎯 Target Audience
- **Systems & Backend Engineers:** Seeking native performance, predictable sub-millisecond latency, zero garbage collector pauses, and fearless memory safety without obscure syntax.
- **Pascal / Delphi Developers:** Transitioning to a modern, type-safe, open-source language with modern tooling (LSP, package manager, profiler, linter, test runner).
- **C / C++ / Rust Developers:** Looking for ultra-fast compilation speeds, clean readable code, and modern compile-time ownership guarantees without cognitive overload.

---

## 📚 Curriculum

| Chapter | Title | Focus & Core Concepts |
| :--- | :--- | :--- |
| **[01. Getting Started](01_GETTING_STARTED.md)** | Toolchain & Workflow | `program Main;`, `end <Module>.`, Units (`interface`/`implementation`), `delsafec new`, CLI targets (`pascal`, `c`, `wasm`). |
| **[02. Variables, Types & Mutability](02_VARIABLES_TYPES_MUTABILITY.md)** | Type Foundations | `let` vs `var`, integers/floats, tuples `(T1, T2)`, `map[K]V`, arrays, sets, subranges, immutability by default. |
| **[03. Control Flow & Pattern Matching](03_CONTROL_FLOW_AND_MATCH.md)** | Deterministic Execution | `if...then...else if...end if;`, loops, algebraic enums, `match` statements/expressions & guards. |
| **[04. Functions & Contracts](04_FUNCTIONS_AND_CONTRACTS.md)** | Design by Contract (DbC) | `procedure`/`function ... return T is`, `require`/`ensure`, function types, and `fn` lambdas/closures. |
| **[05. The Borrow Checker](05_THE_BORROW_CHECKER.md)** | Memory Safety | Ownership (`take`, `borrow`, `mut borrow`), disjoint field borrows, `Box<T>`, and deterministic RAII (`impl Drop`). |
| **[06. Object-Oriented Programming (Records & UFCS)](06_RECORDS_AND_UFCS.md)** | Modern OOP Architecture | Records, named constructors, `Default(T)`, UFCS (`val.method()`), composition, and `[derive(...)]`. |
| **[07. Traits, Generics & Derives](07_TRAITS_GENERICS_AND_DERIVES.md)** | Modern Abstractions | Traits, inherent `impl Type`, generic records/bounds, compiler derivations (`Debug`, `JSON`/`FromJSON`, `Clone`, `Equals`). |
| **[08. Error Handling (Result & Option)](08_ERROR_HANDLING_RESULT_OPTION.md)** | Safe Error Handling | Monadic handling, `Option<T>`, `Result<T, E>`, and `?` / `try` error propagation. |
| **[09. Async/Await & Concurrency](09_ASYNC_AWAIT_AND_CONCURRENCY.md)** | Concurrent Systems | `async`, `spawn`, `await`, `yield`, OS threads (`Task<T>`), `Sync` (`AtomicInt32`, `Mutex`), and `Channel<T>`. |
| **[10. Conditional Compilation & Optimizations](10_CONDITIONAL_COMPILATION_AND_OPTIMIZATIONS.md)** | Target & Low-Level Tuning | `@cfg`, `@inline`, `@cold`, Intel inline assembly (`asm ... end asm;`), and `comptime` / `--release`. |
| **[11. FFI & Zero-Boilerplate Interop](11_FFI_AND_INTEROPERABILITY.md)** | Universal Bridges | `import c`, `import pascal`, `extern c`, `emit-header`, MSYS2/`pkg-config` (`--sys-lib`), and `fppkg`/`OPM` (`--fpc-pkg`). |
| **[12. Modules, Projects & Packages](12_MODULES_PACKAGES_AND_DEPENDENCIES.md)** | Code Organization | Units, `pub`/`priv`, `delsafec new`, `delsafe.json`, `delsafec pkg` (`add`, `add-sys`, `add-fpc`), and `delsafe.lock`. |
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

Proceed to **[Chapter 01: Getting Started](01_GETTING_STARTED.md)** to write and run your first DelSafe program!
