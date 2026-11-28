# DelSafe Official Documentation

> **"The structure and discipline of Object Pascal, the uncompromising memory safety of an affine Borrow Checker, and a developer experience designed for both humans and AI agents."**

Welcome to the official documentation for the **DelSafe Programming Language (DelSafe)**. The documentation is organized into dedicated sections for beginners, systems engineers, and toolchain developers.

---

## Documentation Map

### 1. [The DelSafe Masterclass Course](course/README.md)
A comprehensive, hands-on 13-chapter curriculum that takes you from complete beginner to master:
- **[Curriculum Index](course/README.md):** From basic syntax, module anatomy, and algebraic types to compile-time contracts, the Borrow Checker, traits, async/await, and the final capstone service.

---

### 2. [User Guides](user-guide/)
Practical manuals for writing, building, and maintaining applications in DelSafe:
- **[Beginner's Guide](user-guide/BEGINNERS_GUIDE.md):** Environment requirements (Free Pascal, MSYS2/GCC, Clang, `pkg-config`), quickstart, `delsafec --doctor`, and creating projects with `delsafec new`.
- **[Syntax Cheatsheet](user-guide/SYNTAX_CHEATSHEET.md):** Concise reference for `program Main;`, `interface`/`implementation` Units, mandatory typed `end` closers, and `asm ... end asm;`.
- **[Standard Library & Intrinsics](user-guide/STANDARD_LIBRARY.md):** Complete reference of all 10 `std/*.dels` modules (`Collections`, `FS`, `HTTP`, `IO`, `JSON`, `Math`, `Net`, `Strings`, `Sync`, `Time`) and built-in intrinsics.
- **[CLI Reference Manual](user-guide/CLI_GUIDE.md):** Complete reference of all `delsafec` compiler commands (`new`, `build`, `run`, `test`, `bench`, `profile`, `lint`, `fmt`, `doc`, `emit`, `emit-header`, `upgrade`, `channel`).
- **[Package Manager](user-guide/PACKAGE_MANAGEMENT.md):** Managing Registry, Git, local, and native (`add-sys`, `add-fpc`) dependencies, `delsafe.lock`, and security audits.
- **[Ownership & Borrowing Concepts](user-guide/OWNERSHIP_AND_BORROWING.md):** Practical guide to `take`, `borrow`, `mut borrow`, disjoint field borrows, `Box<T>`, and RAII `Drop`.

---

### 3. [Technical Documentation](technical/)
Formal specifications and compiler architecture:
- **[Language Specification](technical/LANGUAGE_SPECIFICATION.md):** Formal EBNF grammar, type system, UFCS, traits, tuples/closures, `asm ... end asm;`, and zero-boilerplate FFI (`import c`, `import pascal`).
- **[Concurrency & Low-Level Architecture](technical/CONCURRENCY_AND_LOW_LEVEL.md):** OS threading (`spawn`/`await`/`Task<T>`), atomics/mutexes/channels, `unsafe` pointers, Intel inline assembly, and `pkg-config`/MSYS2/`fppkg` linking.
- **[BlaiseVue & Zephyr Integration](technical/BLAISEVUE_AND_PASCAL_INTEGRATION.md):** Zephyr backend architecture (`vendor/zephyr`), `--unit` / `--shared-runtime` emission, and tooling integration.
- **[Static Memory Safety](technical/MEMORY_SAFETY.md):** Formal guarantees against Use-After-Free, Double-Free, Data Races, and Null-Pointer exceptions, plus `Drop` and `unsafe` boundaries.
- **[Compiler Architecture](technical/COMPILER_ARCHITECTURE.md):** Internal subsystems of `delsafec` (Lexer, Parser, `@cfg`/`[derive]`, Type Checker, Borrow Checker, AST Optimizer, Emitters, and Tooling).
- **[AI Diagnostic Mode (JSON)](technical/AI_DIAGNOSTIC_MODE_JSON.md):** Structured JSON schema and full error code reference for IDE and AI agent integration.

---

### 4. [Roadmap & Planning](planning/)
Project evolution, milestones, and design records:
- **[Development Roadmap](planning/DEVELOPMENT_ROADMAP.md):** Complete project phase history and future ecosystem milestones.
