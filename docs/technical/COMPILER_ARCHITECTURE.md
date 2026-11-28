# Internal Architecture of the DelSafe Compiler (`delsafec`)

The official DelSafe compiler (`delsafec`) is implemented in **Free Pascal** as a modular, multi-stage pipeline compiler (with a self-hosting DelSafe frontend/emitter in `compiler/dels/`).

---

## 1. Compilation Pipeline

```text
  [ Source Code .dels ]
           |
           v
  [ 1. Lexical Analyzer (uDelSafeLexer) ] --------> Emits Token Stream (uDelSafeTokens)
           |
           v
  [ 2. Recursive Parser (uDelSafeParser) ] -------> Builds AST (uDelSafeAST)
           |                                        + @cfg Pruning (uDelSafeCfg)
           |                                        + [derive(...)] Expansion (uDelSafeDerives)
           v
  [ 3. Symbol Table & Type Checker ] ------------> Validates Scopes, Types & Exhaustiveness
           |                                        (uDelSafeSymbols, uDelSafeTypeChecker)
           v
  [ 4. Ownership Analyzer (Borrow Checker) ] ----> Enforces Ownership, Disjoint Fields & RAII Drop
           |                                        (uDelSafeBorrowChecker)
           v
  [ 5. AST Optimizer & Incremental Cache ] ------> Constant Folding / DCE (uDelSafeOptimizer)
           |                                        + SHA-256 Graph Cache (uDelSafeIncremental)
           v
  [ 6. Code Emitters & Toolchain (uDelSafeToolchain) ]
           |-- Option A (Default): Object Pascal Emitter (uDelSafeEmitterPascal) -> FPC / Pas2JS
           '-- Option B (--target=c/wasm): C99 Emitter (uDelSafeEmitterC) -------> GCC / Clang
```

---

## 2. Core Compiler Modules (`compiler/src/`)

### Frontend, Typing & Memory Safety
- **`uDelSafeTokens.pas`**: Token enumeration (`TTokenKind`), structural keywords, ownership modifiers, and line/column tracking.
- **`uDelSafeLexer.pas`**: Scanner supporting UTF-8 strings/escapes, `$FF`/`0xFF` hex, `%1010`/`0b1010` binary, raw `asm ... end asm;` blocks, and `//`, `///`, `{ }`, `/* */` comments.
- **`uDelSafeAST.pas`**: AST node hierarchy (`TASTModule`, `TASTRecordDecl`, `TASTEnumDecl`, `TASTFunction`, `TASTProgramBlock`, statements, and expressions).
- **`uDelSafeParser.pas`**: Hand-written recursive-descent parser for Units (`interface`/`implementation`), generics, tuples, lambdas, `match` guards, contracts, and mandatory typed `end <construct>;` closers.
- **`uDelSafeCfg.pas`** & **`uDelSafeDerives.pas`**: `@cfg(...)` inactive AST branch pruning and automatic `[derive(Debug, JSON, Clone, Equals)]` code synthesis.
- **`uDelSafeSymbols.pas`** & **`uDelSafeTypeChecker.pas`**: Lexical symbol tables, strict typing, `let` immutability, monomorphization, UFCS resolution, and `match` exhaustiveness checking.
- **`uDelSafeBorrowChecker.pas`**: Static ownership analyzer tracking `vsOwned`, `vsMoved`, `vsBorrowedShared`, `vsBorrowedMut`, disjoint field borrows, partial moves, and LIFO RAII `Drop` emission (`E0382`, `E0502`).

### Optimization, Caching & Code Generation
- **`uDelSafeOptimizer.pas`**: AST constant folding, algebraic simplifications, and dead-code elimination (`--opt` / `--release`).
- **`uDelSafeIncremental.pas`**: SHA-256 transitive dependency graph caching under `.delsafe/cache/build/` (`--incremental`).
- **`uDelSafeEmitterPascal.pas`**: Emits idiomatic Object Pascal programs and `--unit` files (plus shared `uDelSafeRuntime.pas`), targeting FPC and Pas2JS (`--target=js`).
- **`uDelSafeEmitterC.pas`**: Emits portable C99 (plus `wasm32` target via Clang), Win32/POSIX threads, atomics, channels, and Intel inline assembly wrappers.
- **`uDelSafeToolchain.pas`**: Cross-platform host detection for `fpc`, GCC/MSYS2 UCRT64, `clang`, `lld`, `pkg-config`, `pas2js`, and transitive Windows DLL bundling.

### Developer Tooling & Ecosystem Subsystems
- **`uDelSafeProject.pas`** & **`uDelSafeRegistry.pas`**: `delsafe.json` manifest, `delsafe.lock` lockfiles, `delsafec new`, `pkg` commands (`add`, `add-sys`, `add-fpc`, `audit`, `search`, `publish`).
- **`uDelSafeLSP.pas`** & **`uDelSafeJSONDiag.pas`**: Language Server Protocol engine (`delsafec lsp`) and `--emit-json-diag` schema output.
- **`uDelSafeFormatter.pas`**, **`uDelSafeLinter.pas`**, & **`uDelSafeDoc.pas`**: Canonical formatter (`fmt`), static linter (`lint`), and HTML/Markdown/doctest generator (`doc`).
- **`uDelSafeBenchmark.pas`**, **`uDelSafeProfiler.pas`**, & **`uDelSafeHeaderGen.pas`**: Multi-backend benchmark harness (`bench`), heap leak profiler (`profile`), and C/C++ header emitter (`emit-header`).
- **`uDelSafeUpgrade.pas`** & **`uDelSafeBootstrap.pas`**: Self-updater with SHA-256 verification and atomic rollback (`upgrade` / `channel`), plus Stage 1–3 self-hosting bootstrapper (`bootstrap`).
