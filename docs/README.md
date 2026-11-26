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
- **[Beginner's Guide](user-guide/BEGINNERS_GUIDE.md):** Environment requirements (Free Pascal and GCC), quickstart, diagnostic validation with `delsafec --doctor`, and creating new projects.
- **[CLI Reference Manual](user-guide/CLI_GUIDE.md):** Complete reference of all `delsafec` compiler commands (`build`, `run`, `test`, `bench`, `profile`, `lint`, `fmt`, `doc`, `emit-header`).
- **[Package Manager](user-guide/PACKAGE_MANAGEMENT.md):** Managing Git and local dependencies (`delsafec pkg`), cryptographic lockfiles (`delsafe.lock`), and TLS security audits.
- **[Ownership & Borrowing Concepts](user-guide/OWNERSHIP_AND_BORROWING.md):** Intuitive explanation of `take`, `borrow`, and `mut borrow` with practical visual examples.

---

### 3. [Technical Documentation](technical/)
Formal specifications and compiler architecture:
- **[Language Specification](technical/LANGUAGE_SPECIFICATION.md):** Grammar, type hierarchy, UFCS, traits, and zero-boilerplate FFI (`import c`, `import pascal`).
- **[BlaiseVue & Zephyr Integration](technical/BLAISEVUE_AND_PASCAL_INTEGRATION.md):** Zephyr backend architecture (`vendor/zephyr`), high-performance FPC/C backend execution, and tooling integration.
- **[Static Memory Safety](technical/MEMORY_SAFETY.md):** Formal proof of how DelSafe guarantees zero Use-After-Free, Double-Free, Data Races, and Null-Pointer exceptions.
- **[Compiler Architecture](technical/COMPILER_ARCHITECTURE.md):** Internal subsystems of `delsafec` (Lexer, Recursive-Descent Parser, Type Checker, Borrow Checker, AST Optimizer, and Emitters).
- **[AI Diagnostic Mode (JSON)](technical/AI_DIAGNOSTIC_MODE_JSON.md):** Structured JSON schema for compiler diagnostics and IDE/AI agent integration.

---

### 4. [Roadmap & Planning](planning/)
Project evolution, milestones, and design records:
- **[Development Roadmap](planning/DEVELOPMENT_ROADMAP.md):** Complete project phase history and future ecosystem milestones.
