# Aether Official Documentation

> **"The structure and discipline of Object Pascal, the uncompromising memory safety of an affine Borrow Checker, and a developer experience designed for both humans and AI agents."**

Welcome to the official documentation for the **Aether Programming Language (AetherLang)**. The documentation is organized into dedicated sections for beginners, systems engineers, and toolchain developers.

---

## 📚 Documentation Map

### 🎓 1. [The Aether Masterclass Course](course/README.md)
A comprehensive, hands-on 13-chapter curriculum that takes you from complete beginner to master:
- **[Curriculum Index](course/README.md):** From basic syntax, module anatomy, and algebraic types to compile-time contracts, the Borrow Checker, traits, async/await, and the final capstone service.

---

### 👤 2. [User Guides](user-guide/)
Practical manuals for writing, building, and maintaining applications in Aether:
- **[Beginner's Guide](user-guide/GUIA_DO_INICIANTE.md):** Environment requirements (Free Pascal and GCC), quickstart, diagnostic validation with `aetherc --doctor`, and creating new projects.
- **[CLI Reference Manual](user-guide/GUIA_DA_CLI.md):** Complete reference of all `aetherc` compiler commands (`build`, `run`, `test`, `bench`, `profile`, `lint`, `fmt`, `doc`, `emit-header`).
- **[Package Manager](user-guide/GERENCIAMENTO_DE_PACOTES.md):** Managing Git and local dependencies (`aetherc pkg`), cryptographic lockfiles (`aether.lock`), and TLS security audits.
- **[Ownership & Borrowing Concepts](user-guide/CONCEITOS_POSSE_E_BORROW.md):** Intuitive explanation of `take`, `borrow`, and `mut borrow` with practical visual examples.

---

### ⚙️ 3. [Technical Documentation](technical/)
Formal specifications and compiler architecture:
- **[Language Specification](technical/ESPECIFICACAO_LINGUAGEM.md):** Grammar, type hierarchy, UFCS, traits, and zero-boilerplate FFI (`import c`, `import pascal`).
- **[BlaiseVue & Zephyr Integration](technical/INTEGRACAO_BLAISEVUE_E_PASCAL.md):** Zephyr backend architecture (`vendor/zephyr`), high-performance FPC/C backend execution, and tooling integration.
- **[Static Memory Safety](technical/SEGURANCA_DE_MEMORIA.md):** Formal proof of how Aether guarantees zero Use-After-Free, Double-Free, Data Races, and Null-Pointer exceptions.
- **[Compiler Architecture](technical/ARQUITETURA_DO_COMPILADOR.md):** Internal subsystems of `aetherc` (Lexer, Recursive-Descent Parser, Type Checker, Borrow Checker, AST Optimizer, and Emitters).
- **[AI Diagnostic Mode (JSON)](technical/MODO_IA_DIAGNOSTICO_JSON.md):** Structured JSON schema for compiler diagnostics and IDE/AI agent integration.

---

### 🗺️ 4. [Roadmap & Planning](planning/)
Project evolution, milestones, and design records:
- **[Development Roadmap](planning/ROADMAP_DE_DESENVOLVIMENTO.md):** Complete history of all 40 completed development phases and future ecosystem milestones.
