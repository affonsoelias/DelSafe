# DelSafe (`delsafec`) Development Roadmap & Engineering Plan

This document tracks the official development status of the compiler toolchain and engineering milestones for the **DelSafe** programming language.

---

## 📌 Consolidated Phase Status

### ✅ Phase 1: Core Architecture & Lexer / Parser (Completed)
- [x] Official token definitions in `uDelSafeTokens.pas`.
- [x] Lexical analyzer (Tokenizer with line, column, literals, and comment tracking) in `uDelSafeLexer.pas`.
- [x] Abstract Syntax Tree (declaration, statement, and expression nodes) in `uDelSafeAST.pas`.
- [x] Recursive-descent parser with support for generics and contracts in `uDelSafeParser.pas`.
- [x] Visual AST dumper (`--dump-ast` CLI flag).

### ✅ Phase 2: Symbol Table & Type System (Completed)
- [x] Hierarchical lexical scope resolution in `uDelSafeSymbols.pas`.
- [x] Static typing for primitives, records, algebraic enums, and generics (`Result`/`Option`) in `uDelSafeTypeChecker.pas`.
- [x] Immutability enforcement for variables declared with `let` (Error `E0384`).
- [x] Exhaustiveness checking in `match` expressions/statements (Error `E0004` with missing variant suggestion).

### ✅ Phase 3: Ownership Analyzer / Borrow Checker (Completed)
- [x] Lifecycle tracking for every resource in `uDelSafeBorrowChecker.pas`.
- [x] Strict `take` semantics blocking *Use-After-Move* and *Double-Move* (Error `E0382`).
- [x] Shared read borrowing (`borrow`) and exclusive mutable borrowing (`mut borrow`, Error `E0502`).
- [x] Exact source line and column tracking for ownership transfer locations.

### ✅ Phase 4: Code Emitters & Native Executables (Completed)
- [x] Automatic host toolchain diagnostics (`delsafec --doctor`) with cross-platform conditional compilation in `uDelSafeToolchain.pas`.
- [x] Object Pascal emitter (`uDelSafeEmitterPascal.pas`) + automatic `fpc` invocation.
- [x] C99 emitter (`uDelSafeEmitterC.pas`) + automatic GCC invocation (MSYS2 on Windows / native on Linux/macOS).
- [x] Modern UFCS ergonomics (`my_buffer.Inspect()`).

### ✅ Phase 5: AI Mode (JSON Diagnostics & Auto-Fix) (Completed)
- [x] Implementation of `--emit-json-diagnostics` (`uDelSafeJSONDiag.pas`).
- [x] Standardized diagnostic schema with line/column spans.
- [x] Enriched move context (`moved_at`) and machine-applicable `suggested_fix` metadata.

### ✅ Phase 6: External Interoperability (`extern` & `import pascal`) (Completed)
- [x] `extern function` keyword for declaring native C functions (`puts`, `sqrt`, etc.).
- [x] `import pascal <UnitName>` for direct inclusion of Free Pascal / Lazarus units and Boss packages.
- [x] C calling convention (`cdecl`) support with dynamic/static linking (`msvcrt`/`libc`).
- [x] Contract (`contract require / ensure`) support on `extern` functions.

### ✅ Phase 7: Official VS Code Extension for DelSafe (`.dels`) (Completed)
- [x] Extension package created in `editors/vscode/` with TextMate syntax highlighting.
- [x] Complete snippets for `module`, `contract`, `record`, `enum`, `match`, `extern`, `if`, etc.
- [x] JSON diagnostic integration (`--emit-json-diagnostics`) surfaced in the VS Code *Problems* panel with suggested fixes.
- [x] Integrated commands for compiling via Pascal and C99 backends directly from the editor.

### ✅ Phase 8: Standard Library (`std/`) & Module Resolution (Completed)
- [x] Automatic recursive resolution of `import <Module>` in `delsafec` (local directories and `std/`).
- [x] `std/math.dels`: Constants and core mathematical routines (`Abs`, `Max`, `Min`, `Clamp`, `Pow`, `SqrtSafe`).
- [x] `std/strings.dels`: String manipulation and validation utilities.
- [x] `std/io.dels`: Safe I/O types and routines.
- [x] `std/collections.dels`: Ownership-aware data structures and UFCS methods.

### ✅ Phase 9: LSP (Language Server Protocol) & Real-Time IDE Support (Completed)
- [x] Official DelSafe LSP server in `compiler/src/uDelSafeLSP.pas` under `delsafec --lsp`.
- [x] JSON-RPC protocol with HTTP-style framing (`Content-Length: ...\r\n\r\n{...}`) in pure UTF-8 via `fpjson`.
- [x] Real-time diagnostics (`textDocument/publishDiagnostics`) wired to Lexer, Parser, TypeChecker, and Borrow Checker.
- [x] Smart autocomplete (`textDocument/completion`) for ownership keywords (`borrow`, `take`, `mut`), primitive types, monads, and local AST symbols.
- [x] Hover tooltips (`textDocument/hover`) documenting borrow/ownership semantics, signatures, and contracts.
- [x] Go-to-Definition (`textDocument/definition`) resolving functions, records, and enums across source files.
- [x] VS Code / Antigravity IDE client integration (`editors/vscode/extension.js` v0.9.0).

---

### ✅ Phase 10: Developer Experience & Project Management (`init`, `build`, `run`) (Completed)
- [x] `delsafec init [name]` / `delsafec new`: Structured project scaffolding with `delsafe.json`, `src/main.dels`, `tests/`, `.gitignore`, and `README.md`.
- [x] Project Manifest (`delsafe.json`): Name, version, `entry`, default backend (`pascal` or `c`), and `output`.
- [x] Automated `delsafec build` and `delsafec run` commands with backend override (`--target=c`).
- [x] VS Code / Antigravity IDE command palette integration for init, build, and run.
- [x] Native project module in Pascal (`compiler/src/uDelSafeProject.pas`).

---

### ✅ Phase 11: Language Maturity for Self-Hosting (Completed)
- [x] Support for `Box<T>` and `Option<Box<T>>`: heap pointers with strict ownership for recursive structures (AST nodes, trees, linked lists).
- [x] Smart auto-dereferencing in Pascal (`^.` / `^`) and C99 (`->` / `*`) emitters.
- [x] Native string operations: concatenation (`+`), equality (`=`, `<>`), `Length(s)`, `CharAt(s, idx)`, `Substring(s, start, len)`.
- [x] File I/O in `std/io.dels`: `FileExists`, `ReadFile`, and `WriteFile` with FPC and GCC backends.
- [x] Collections and `StringBuilder` (`NewStringBuilder`, `Append`, `ToString`) + dynamic buffers in `std/collections.dels`.
- [x] Recursive AST & I/O validation via `08_box_and_recursion.dels` and `09_std_io_and_collections.dels`.

---

### ✅ Phase 12: Self-Hosted DelSafe Compiler (`delsafec-core`) (Completed)
- [x] Token definitions in `compiler/dels/tokens.dels`.
- [x] 100% native DelSafe lexer in `compiler/dels/lexer.dels`.
- [x] Recursive AST nodes via `Box` in `compiler/dels/ast.dels`.
- [x] Native recursive-descent parser in `compiler/dels/parser.dels`.
- [x] Native C99 emitter in `compiler/dels/emitter.dels`.
- [x] Self-hosted compiler driver in `compiler/dels/main.dels`.
- [x] Full bootstrapping: DelSafe compiler built by bootstrap `delsafec`, transpiling `.dels` programs into native executables via GCC.

---

### ✅ Phase 13: Canonical Module Validation & Hierarchical Namespaces (Completed)
- [x] **Strict 1:1 Module Name Validation (Pascal/Java-style)**: Declared `module <Name>;` must match `<Name>.dels` on disk (`E0005` on mismatch).
- [x] **Hierarchical Namespaces**: Dotted imports (e.g., `import Compiler.Dels.Tokens;` -> `compiler/dels/tokens.dels` in project or `std/`).
- [x] **Canonical Alignment**: Examples and `compiler/dels/` modules aligned to 1:1 naming.
- [x] **Dual-Backend Validation**: `examples/10_hierarchical_modules.dels` verified with 100% parity on Free Pascal and GCC.

### ✅ Phase 14: Traits & Static Polymorphism (Type-Level Contracts) (Completed)
- [x] **`trait` Declarations**: Behavioral contracts via `trait Name ... end trait;` at module or `type` level.
- [x] **Trait Implementations (`impl Trait for Type`)**: Method blocks for records with automatic `borrow self` typing.
- [x] **Strict Semantic Checking**:
  - Completeness validation (`E0046`) if a type omits required trait methods.
  - Signature matching (`E0053`) for parameters and return types.
  - Trait bound validation (`E0277`) on generic calls (e.g., `<T: Printable>`).
- [x] **Static Dispatch (*Zero-Cost Abstractions*)**: Compile-time UFCS method resolution mapped statically to `<Type>_<Method>` with zero vtables or runtime overhead.
- [x] **Static Monomorphization of Bounded Generics**: Specialized native code emitted per concrete type argument.
- [x] **Dual-Backend Validation**: Verified on Free Pascal and GCC in `examples/11_traits_and_polymorphism.dels`.

### ✅ Phase 15: Package Manager & Integrated Test Runner (`delsafec add` / `delsafec test`) (Completed)
- [x] **`"dependencies"` in `delsafe.json`**: Local `path`, `git`, and SemVer version constraints.
- [x] **`delsafec add <package>` CLI**: `--path=...`, `--git=...`, `--version=...`, synced with global cache (`~/.delsafe/cache/<pkg>`).
- [x] **Multi-Level Dependency Module Resolution**: Resolves `<dep>/`, `<dep>/src/`, and global cache cleanly.
- [x] **Integrated Native Test Runner (`delsafec test`)**: Runs tests with name filtering, millisecond latency measurement, `PASS`/`FAIL` status, and `--target=pascal|c|all`.
- [x] **Validated Sample**: `examples/12_package_manager_and_tests/` passing on Free Pascal and GCC.

---

### ✅ Phase 16: Self-Hosted Compiler Expansion (`compiler/dels/`) to Full Parity (Completed)
- [x] **Native Type Checker (`compiler/dels/typechecker.dels`)**: Native `SymbolTable`, assignment/control-flow checking, `E0001`, `E0002`, and `E0003`.
- [x] **Native Borrow Checker (`compiler/dels/borrowchecker.dels`)**: Ownership tracking (`osAvailable`, `osMoved`, `osBorrowed`, `osMutBorrowed`) detecting `E0382` and `E0502`.
- [x] **Expanded AST, Parser & C99 Emitter**: Local `var`, control flow, compound expressions, C99 comparisons, and statement blocks.
- [x] **4-Stage Self-Hosted Pipeline (`compiler/dels/main.dels`)**: `[1/4] Lexer/Parser`, `[2/4] Type Checker`, `[3/4] Borrow Checker`, `[4/4] C99 Emitter` in pure DelSafe.
- [x] **Dual-Backend Validation**: Verified on Free Pascal and GCC processing `examples/13_self_hosted_compiler_demo.dels`.

### ✅ Phase 17: Standard Library (`std/`) & Lightweight Concurrency Primitives (Completed)
- [x] **JSON Parser & Builder (`std/json.dels`)**: `JsonBuilder` and zero-allocation extractors (`ExtractString`, `ExtractInt`, `ExtractBool`, `Validate`, `HasKey`).
- [x] **Concurrency & Synchronization Primitives (`std/sync.dels`)**: `AtomicInt32`, `Mutex`, and bounded ring-buffer `Channel`.
- [x] **Networking & HTTP Protocols (`std/net.dels`)**: TCP `Socket` abstractions and HTTP request/response builders & parsers.
- [x] **Dual-Backend Validation**: Verified on Free Pascal and GCC C99 in `examples/14_stdlib_and_concurrency.dels`.

### ✅ Phase 18: Developer Tooling Polish (LSP & VS Code Extension) (Completed)
- [x] **LSP Enhancements (`compiler/src/uDelSafeLSP.pas`)**: Completion for keywords/types/traits/UFCS, full `FormatFunctionSignature`, Markdown hover for contracts/records/enums/traits, go-to-definition, and `delsafec lsp` subcommand.
- [x] **VS Code Extension (`ide/vscode/`)**: TextMate grammar, smart indentation configuration, snippets, stdio LSP client, and C99/Pascal build commands.

### ✅ Phase 19: Git Dependency Support in `delsafec add` (Completed)
- [x] **Automatic Git Clone & Cache**: `delsafec add <git-url> [--branch=...|--tag=...|--version=...]` stored in `~/.delsafe/cache/<pkg>` and replicated into `.delsafe/deps/<pkg>`.
- [x] **Recursive Transitive Dependency Resolution** with circular dependency protection and automatic restore on `build`, `run`, and `test`.

### ✅ Phase 20: Real OS Sockets & Native HTTP Server (Completed)
- [x] **Native OS Networking (`std/net.dels`)**:
  - Free Pascal backend using native `Sockets` unit (`fpsocket`, `fpbind`, `fplisten`, `fpaccept`, `fpconnect`, `fpsend`, `fprecv`, `CloseSocket`).
  - C99 backend using `WinSock2` (`-lws2_32` on Windows) and POSIX `<sys/socket.h>`.
  - Built-in primitives `SocketCreate`, `SocketListen`, `SocketAccept`, `SocketConnect`, `SocketSend`, `SocketRecv`, `SocketClose`.
- [x] **High-Performance Native HTTP & REST Server**: Zero external dependencies, request parser, structured response builders, and `std/json.dels` integration verified in `examples/15_http_server_and_sockets.dels` on Free Pascal and GCC.

### ✅ Phase 21: First-Class Interoperability (Free Pascal Units & C Headers / FFI) (Completed)
- [x] **Zero-Boilerplate Transparent Auto-Import**: Direct invocation of Pascal units (`import pascal SysUtils;`) and C headers (`import c "<math.h>";`) without manual `extern` wrappers.
- [x] **Free Pascal & C Header Support**: Automatic `uses` injection, native linking (`-lm`, `-lws2_32`), and math header redeclaration conflict prevention verified in `examples/16_pascal_and_c_interop.dels`.

### ✅ Phase 21.1: First-Class BlaiseVue Integration & Pascal Tooling Pipeline (Completed)
- [x] **Reusable Free Pascal Unit Emission (`--unit`)**: Canonical `<ModuleName>.pas` emission with clean `interface`/`implementation` sections (`uses` compatibility in 0.1s).
- [x] **Custom Output Directory (`--out-dir` / `-d`)**: Direct emission to framework directories (e.g., `.blaisevue/generated/`).
- [x] **Headless Execution (`--silent` + `--emit-json-diag`)**: Strict exit codes and structured error diagnostics for IDE/CLI tooling.
- [x] **Reactive Watch Mode (`--watch` / `-w`)**: Timestamp monitoring with atomic unit regeneration validated via `examples/17_blaisevue_component_store.dels`.

### ✅ Phase 22: Autonomous Self-Hosted Compiler Bootstrapping (`compiler/dels/`) (Completed)
- [x] **Native CLI Arguments (`ParamCount`, `ParamStr`)** with Pascal/C99 parity (`g_delsafe_argc`, `g_delsafe_argv`).
- [x] **Autonomous Driver (`compiler/dels/main.dels`)**: Parses `<file.dels> [-o output.c]`, compiled to `bin/delsafec-core.exe` and verified compiling `examples/13_self_hosted_compiler_demo.dels`.

### ✅ Phase 23: Recursive Self-Hosting (`delsafec-core` Compiling Itself) (Completed)
- [x] **Expanded Native Parser, AST, TypeChecker & C99 Emitter**: Composite `type ... = record ... end;`, top-level functions with multiple parameters, nested calls, `typedef struct`, and C prototypes validated on `examples/18_self_hosted_functions_and_structs.dels`.

### ✅ Phase 24: Native Tooling & Developer Experience (`delsafec fmt` & `delsafec test`) (Completed)
- [x] **Canonical Formatter (`delsafec fmt`)**: `uDelSafeFormatter.pas` with 4-space indentation, operator spacing normalization, literal/comment preservation, recursive directory formatting, and CI `--check` mode.
- [x] **Native Assertions (`Assert`)**: Dual-backend support (`Assert` in Pascal, `<assert.h>` in C99).
- [x] **Flexible Test Runner (`delsafec test`)**: Standalone file or filter execution with `[ PASS ]`/`[ FAIL ]` status and millisecond timings.

### ✅ Phase 25: Expanded Canonical Standard Library (`std/`) (Completed)
- [x] **`std.fs`**: `CreateDir`, `RemoveDir`, `DeleteFile`, `DirExists`, `FileSize`, and `FileInfo` with Pascal/C99 parity.
- [x] **`std.time`**: High-resolution `GetNanoseconds(): UInt64` (Windows QPC / POSIX `clock_gettime`) and `SleepMs(ms: UInt32)` plus `Timer` helpers.
- [x] **`std.json` & `std.http`**: Fast JSON builders/extractors and HTTP `Client`/`Server` abstractions validated via `examples/20_stdlib_expanded.dels`.

### ✅ Phase 26: Incremental Compilation & Object Cache (`delsafec build --incremental`) (Completed)
- [x] **Autonomous SHA-256 Change Detection (`uDelSafeIncremental.pas`)**: Tracks source files, transitive imports, and output binaries in `.delsafe/cache/build/`.
- [x] **Instant Fast-Path**: Skips parsing, type checking, emission, and native compilation (0 ms) when hashes match across both Free Pascal and GCC C99 backends; cleaned by `delsafec clean`.

### ✅ Phase 27: AST Optimizations & Release Mode (`delsafec build --release`) (Completed)
- [x] **Constant Folding & Algebraic Simplification (`uDelSafeOptimizer.pas`)**: Compile-time arithmetic, boolean short-circuiting, string literal concatenation, and identity reduction.
- [x] **Dead Code Elimination (DCE)**: Removes unreachable `if false`/`while false` branches and statements after unconditional `return`.
- [x] **Release Pipeline (`--release` / `--opt` / `-O`)**: Passes `-O3 -XX -Xs` to FPC and `-O3 -flto -s` to GCC (~13.8 KB binaries) validated via `examples/21_optimizer_and_release.dels`.

### ✅ Phase 28: LSP Expansion & VS Code Extension v1.0.0 (Completed)
- [x] **Integrated LSP Formatting (`textDocument/formatting`)**, **Safe Rename (`textDocument/rename`)**, and **Quick-Fix Code Actions (`textDocument/codeAction`)** for `borrow`/`mut borrow` and missing `std` imports.
- [x] **VS Code Extension v1.0.0**: Published manifest & `.vsix` package in `editors/vscode/`.

### ✅ Phase 29: Closed-Loop Stage 3 Self-Hosting Bootstrapping (Completed)
- [x] **`delsafec bootstrap` Command**: Stage 1 (Pascal -> `delsafec-stage1`) -> Stage 2 (`stage2_compiler.c` + `stage2_suite.c`) -> Stage 3 (`stage3_compiler.c` + `stage3_suite.c`).
- [x] **Bit-for-Bit Fixed-Point Convergence Verified**: 0 byte difference and identical SHA-256 checksums across Stage 2 and Stage 3 outputs.

### ✅ Phase 30: WebAssembly (`.wasm`) & JavaScript via `pas2js` (`--target=js` / `--target=wasm`) (Completed)
- [x] **JavaScript Target (`--target=js` / `pas2js`)**: Transpiles to Object Pascal -> clean ECMAScript + `rtl.js` with zero Node.js/bundler requirement.
- [x] **Pure WebAssembly Target (`--target=wasm`)**: Direct compilation via Clang `wasm32 -nostdlib` with optional HTML runner (`--html`).
- [x] **Flexible C Compiler Selection (`--cc=gcc|clang`)**, multi-target `"targets"` in `delsafe.json`, and 4-toolchain `delsafec --doctor`.

### ✅ Phase 31: Structured Concurrency & Async/Await Coroutines (Completed)
- [x] **`async function`, `await`, `spawn`, and `Task<T>`** with borrow-checker validation and emission across Free Pascal, C99, WebAssembly, and JavaScript (`examples/test_fase31_async/async_demo.dels`).

### ✅ Phase 32: Canonical Documentation Generator (`delsafec doc`) (Completed)
- [x] **Structured Docstrings (`///`, `@param`, `@return`)** extracting ownership modifiers and `require`/`ensure` contracts.
- [x] **Static Docs Site & Doctests (`--test`)**: Generates HTML/CSS/client search (`index.html`, `search.js`) plus Markdown (`--format=md`) and executes embedded ```delsafe code blocks (`examples/test_fase32_doc/geometria.dels`).

### ✅ Phase 33: Community Package Registry (`delsafec pkg publish` / `search`) (Completed)
- [x] **Registry Index Client & Publisher**: SHA-256 integrity hashing, SemVer compatibility (`^`, `~`, `*`, exact), `~/.delsafe/registry/index.json`, and `delsafe.lock` cryptographic lockfile integration.

### ✅ Phase 34: First-Class BlaiseVue Integration (SFC `<script lang="delsafe">`, Wasm & Zephyr Backend) (Completed)
- [x] **Subphase 34.1 — SFC `<script lang="delsafe">`, Unit Emission & Full-Stack Sharing**:
  - `delsafec emit pascal --unit --shared-runtime --out-dir=.blaisevue/generated --silent` emits clean Pascal units and shared `uDelSafeRuntime.pas` for BlaiseVue's `pas2js` pipeline, with `--source-file` / `--line-offset` / `--emit-json-diag` diagnostics and typed `TComponentThis`.
- [x] **Subphase 34.2 — Zephyr Native DelSafe Backend (`BlaiseVue/vendor/zephyr`)**:
  - Built-in HTTP/1.1 Keep-Alive + WebSocket (RFC 6455) + static SPA server with DoS timeouts, path traversal guard (`IsSafePath`), rate limiter, CORS, and OWASP security headers.
- [x] **Subphase 34.3 — WebAssembly Components (`<script lang="delsafe" target="wasm">`)**:
  - `delsafec emit wasm --manifest` compiling to freestanding `wasm32` with linear heap and `.wasm.json` export manifest.

### ✅ Phase 35: Native Shared Libraries (`.dll` / `.so` / `.dylib`) & C Header Generator (`.h`) (Completed)
- [x] **`cdylib` / `--lib` Builds** with `export function` across Free Pascal (`library ... exports`) and C99 (`__declspec(dllexport)` / `visibility("default")`).
- [x] **`delsafec emit-header`**: Generates C99/C++-compatible `.h` headers validated with Python `ctypes` and C hosts.

### ✅ Phase 36: Canonical Benchmarking Suite (`delsafec bench`) (Completed)
- [x] **Integrated Benchmark Harness**: Warm-up runs, nanosecond resolution, mean/std-dev/median/ops-per-sec statistics, multi-backend comparison tables, and `--json` export.

### ✅ Phase 37: Automatic Derive Metaprogramming (`[derive(Debug, JSON, Clone, Equals)]`) (Completed)
- [x] **Compile-Time Method Generation (`uDelSafeDerives.pas`)**: `ToString`, `ToJSON`, `Clone`, and `Equals` on `record` and `enum` types across Free Pascal and GCC C99 (`tests/02_derives_test.dels`).

### ✅ Phase 38: Canonical Static Linter (`delsafec lint`) (Completed)
- [x] **Code Smells & Style Checks**: `L001` unused variables, `L002` unused imports, `L003` dead code, `L004` unused params, `L005` redundant booleans, `L006` PascalCase naming, plus `--fix` and `--json`.

### ✅ Phase 39: Execution Profiler & Memory Leak Detector (`delsafec profile`) (Completed)
- [x] **Latency & Memory Auditing**: Compiles Pascal targets with `-gh -gl` (`heaptrc`) to catch leaks with callstacks, runs bare-metal C99 checks, and exports `--json` telemetry.

### ✅ Phase 40: Conditional Compilation, Compile-Time Eval & Optimization Attributes (`@cfg`, `comptime`, `@inline`) (Completed)
- [x] **`@cfg(...)` / `[cfg(...)]` AST Pruning (`ApplyCfgToModule`)**, compile-time division-by-zero/overflow checking (`E0301`), and `@inline(always|never)` / `@cold` hints.

---

### ✅ Open-Source Milestone: 1-Click Build & Full English Standardization (Completed)
- [x] **1-Click Bootstrap Scripts**: `build.bat`, `build.ps1`, `build.sh` compiling and verifying `delsafec`.
- [x] **English Standard Documentation & Repo Hygiene**: Root English `README.md`, canonical technical docs under `docs/`, `.gitignore` filtering build artifacts, `LICENSE`, and contribution guidelines.

---

### ✅ Phase 41: Compiler Toolchain Self-Upgrade (`delsafec upgrade`) (Completed)
- [x] **Hybrid Upgrade Architecture (GitHub Releases Binary & `--from-source`)**: `--check`, `--binary`, `--from-source`, `--version=<tag>`, `--nightly`, SHA-256 verification (`E9991`), atomic replacement with auto-rollback on Windows/POSIX, `--rollback`, and `--dry-run`.

---

### ✅ Phase 42: Canonical Counting Loops (`for ... to` / `for ... downto`) (Completed)
- [x] **Full Pipeline Support**: `to` / `downto` tokens, `TASTForStmt`, loop variable inference, BorrowChecker/Linter integration, Pascal & C99 emission, and `tests/04_for_loop_test.dels`.

---

### ✅ Phase 43: Classic Pascal Data & Control Constructs (Fixed N-D Arrays, `repeat...until`, `set of`, Subranges) (Completed)
- [x] **1D/2D/3D/N-D Fixed Arrays** with multi-index access and literal bounds checks (`E0309`).
- [x] **Post-Test Loop (`repeat ... until <cond>;`)** mapped to Pascal `repeat` and C99 `do ... while`.
- [x] **Classic Sets (`set of T`, `in`, `+`, `*`, `-`)** mapped to Pascal sets / C99 bitmasks, plus **Subrange Types** (`1..31`, `'A'..'Z'`) validated in `tests/05_fase43_arrays_repeat_set_subrange_test.dels`.

---

### ✅ Phase 44: Fine-Grained Loop Control (`break`, `continue`) & Canonical `const` Blocks (Completed)
- [x] **`break` / `continue`** validated inside loops (`E0310` outside loops) across `for`, `while`, and `repeat...until`.
- [x] **Module-Level `const` Declarations** (`skConstant` immutability, `E0384` on reassignment) validated in `tests/06_fase44_break_continue_const_test.dels`.

---

### ✅ Phase 45: Dynamic Structures, Scope Safety, Ergonomics & Systems (`array of T`, `defer`, `$"..."`, `try...except`, `unsafe`, Raw Pointers) (Completed)
- [x] **Resizable Dynamic Arrays (`array of T`)** with `SetLength`, `Length`, and `.Push`.
- [x] **Deterministic Scope Cleanup (`defer`)** in LIFO order before any exit path.
- [x] **Compile-Time String Interpolation (`$"..."`)** and **`try ... except` / `raise`**.
- [x] **Unsafe Boundary Blocks (`unsafe ... end;`) & Raw Pointers (`^T`, `@var`, `ptr^`, `nil`)** enforced via `E0312` (`tests/07_fase45_dynarray_defer_interp_try_ptr_test.dels`).

---

### ✅ Phase 46: Bitwise Operators, `for..in` Iteration, Universal `match`, `var`/`let` Ergonomics & Maps (`map[K]V`) (Completed)
- [x] **Bitwise Operators (`shl`, `shr`, `xor`, `and`/`or`/`not`)** + hex (`$FF` / `0xFF`) and binary (`%1010` / `0b1010`) literals.
- [x] **`for item in collection`**, full **Pattern Matching (`match`)**, multi-var declarations + type inference, and associative **Maps (`map[K]V`)** (`tests/08_fase46_bitwise_forin_match_var_map_test.dels`).

---

### ✅ Phase 47: Array Literals, Map Iteration, System Casts & `String[i]`, Compound Assignments & Full `Option<T>` / `Result<T, E>` (Completed)
- [x] **Array Literals (`[10, 20, 30]`) + `.Pop()` / `.Clear()`**, **`for k, v in map`**, explicit numeric/system casts (`Ord`, `Chr`, `SizeOf`, `s[i]`), `+=`/`-=`/`*=`/`Inc`/`Dec`, value `Option<T>`/`Result<T, E>`, and simple type aliases (`tests/09_fase47_arrlit_mapfor_casts_compassign_option_alias_test.dels`).

---

### ✅ Phase 48: Multi-Value/Range `match`, Inline `if..then..else` Expressions, String/Math Intrinsics, Slices & Named Constructors / `Default(T)` (Completed)
- [x] **Comma Lists & Inclusive Ranges in `match`**, inline ternary **`if cond then a else b`**, String/Math UFCS intrinsics, dynamic array `.Delete`/`.Insert`/`.Slice`, named record constructors, and `Default(T)` (`tests/10_fase48_matchrange_ifexpr_strmath_arrslice_default_test.dels`).

---

## 🔎 Complete Language Gap Audit & Execution (Phases 49–56)

### ✅ Phase 49: 1. Type System, Generics & Algebraic Data Types (ADTs) (Completed)
- [x] **1.1 Tagged-Union Enums with Payloads (Real ADTs)** with positional/named constructors and pattern destructuring (`case Shape.Rect(let w, let h) =>`).
- [x] **1.2 Multi-Parameter Generic `Record<T, U>` & Compound Monomorphization**.
- [x] **1.3 Value-Based `Option<T>` & `Result<T, E>`** for records and ADTs (`tests/language/types/adt_generics_monads_test.dels`, 25/25 PASS).
- [x] **1.4 Anonymous Tuples (`(Int32, String)`) & Destructuring (`let (a, b) := ...`)** with static arity checks (`E0308`).
- [x] **1.5 Function Types (Callbacks) & Closures/Lambdas** (`fn(x: Int32) => ...`, captured closures, curried calls `MakeAdder(50)(7)` in `tests/language/types/tuples_and_closures_test.dels`, FPC 25/25 | C99 25/25 PASS).

### ✅ Phase 50: 2. Design-by-Contract (`contract` / `require` / `ensure`) (Completed)
- [x] **2.1 Runtime Enforcement of `ensure` Postconditions** before every return path on both backends.
- [x] **2.2 Special `result` Identifier in `ensure` & Generic Contracts** (`tests/11_fase50_56_contracts_ensure_ufcs_lit_fmt_header_test.dels`).

### ✅ Phase 51: 3. Expressions, Operators & Control Flow (Completed)
- [x] **3.1 Fast Error Propagation (`?` / `try expr`)** for compatible `Result` and `Option` returns.
- [x] **3.2 Expression `match` & Pattern Guards (`if` / `when`)**.
- [x] **3.3 Inline `let` / `var` Anywhere Inside `begin..end` and Nested Blocks**.
- [x] **3.4 `div`, `/=`, `mod=`, `&=`, `|=`, `^=`, `<<=`, `>>=` Operators**.
- [x] **3.5 Map Literals (`["a": 1, "b": 2]`, `[:]`) & Full Char/String Escapes** (`tests/12_fase51_tryop_matchexpr_inlinevar_divcomp_maplit_test.dels`, 12/12 PASS).

### ✅ Phase 52: 4. Borrow Checker & Memory Lifecycle (Completed)
- [x] **4.1 Post-Inference Borrow Checker Integration & Monomorphized Generic Validation**.
- [x] **4.2 Restoring `vsBorrowedMut` & Disjoint Field Borrows** (`obj.a` vs `obj.b`).
- [x] **4.3 Heap Cleanup in C99 (`Free`/`Dispose` & RAII/`Drop`)** for `Box<T>`, dynamic arrays, maps, and temporary strings.

### ✅ Phase 53: 5. Concurrency (`async` / `await` / `spawn` / `yield`) & `std/sync.dels` (Completed)
- [x] **5.1 Real OS Threads for `spawn`/`await` & `yield`**: `BeginThread`/`WaitForThreadTerminate` in FPC; `CreateThread`/`pthread_create` (`-pthread`) in C99; typed `Task<T>`/`Task<Void>` handles and cooperative `yield;`.
- [x] **5.2 Real Synchronization & Bounded Generic `Channel<T>`**: Hardware `AtomicInt32` (`Interlocked*` / `__atomic_*`), OS `Mutex`, and thread-safe ring-buffer `Channel<T>` validated in `tests/language/concurrency/threads_sync_channels_test.dels` (`FPC 27/27 | C99 27/27 PASS`).

### ✅ Phase 54: 6. Module System, Visibility, Inherent Methods & Derive `FromJSON` (Completed)
- [x] **6.1 Import Aliases (`import X as Y;`), Visibility (`pub` / `priv` with `E0603`), & Qualified Access**.
- [x] **6.2 Direct Inherent `impl Type` Blocks** (`Self`, UFCS calls, and static associated methods like `Vector2D.New(3, 4)`).
- [x] **6.3 Expanded `[derive(Debug, JSON, Clone, Equals)]` & Auto-Generated `FromJSON`** (`tests/13_fase54_modules_pub_inherent_impl_derives_fromjson_test.dels`, 13/13 PASS).

### ✅ Phase 55: 7. Standard Library (`std/*.dels`) & System Intrinsics (Completed)
- [x] **7.1 Advanced Strings & Conversions** (`Split`, `Join`, `PadLeft`, `PadRight`, `RepeatStr`, `StrToFloat`, `TryStrToInt`, `TryStrToFloat`).
- [x] **7.2 Complete Math Intrinsics** (`Sqrt`, `Floor`, `Ceil`, `Round`, `Pow`, `Exp`, `Log`, `Sin`, `Cos`, `Tan`, `Atan2`, `RandomInt`, `RandomFloat`).
- [x] **7.3 Console, Environment Variables & File System** (`Print`, `ReadLn`, `GetEnv`, `SetEnv`, `ListDir`, `CopyFile`, `RenameFile`).
- [x] **7.4 Structured JSON Parser in `std/json.dels`** (`ExtractObject`, `ExtractArray`, `ArrayLength`, `ArrayGet*`, `Float64`, verified in `tests/16_fase55_stdlib_intrinsics_json_test.dels`, 16/16 PASS).
- [x] **7.5 On-Demand Embedded Runtime / Tree-Shaking** shrinking minimal templates to ~32 lines (Pascal) / ~64 lines (C99).
- [x] **7.6 Framework-Agnostic `delsafec new` / `init` Build Directories** (`build/pascal`, `build/c`, `build/units`).
- [x] **7.7 Project-Named Entrypoint in `delsafec new`** (`src/<project>.dels` + `tests/<project>_test.dels`).

### ✅ Phase 56: 8. Compiler Tooling Hardening (`fmt`, `emit-header`, `lexer`) (Completed)
- [x] **8.1 Canonical Formatter Fix (`delsafec fmt`)** for compound operators, generic brackets, unary `-`, and nested structured blocks.
- [x] **8.2 Complete C Header Export (`delsafec emit-header`)** including `enum`, type aliases, subranges, and fixed arrays.
- [x] **8.3 Direct Postfix/UFCS on Literals & Parenthesized Expressions** (`55.Clamp(0, 40)`, `"  delsafe  ".Trim()`, `"DelSafe"[0]`, validated in `tests/11_fase50_56_contracts_ensure_ufcs_lit_fmt_header_test.dels`, 11/11 PASS).

---

### ✅ Phase 57: Ada + Object Pascal Syntax Evolution (`procedure`, `return T is`, `end Name;`, Structured `interface`/`implementation` Units — Clean Cutover) (Completed)

> **Design Decisions (No Legacy Backward Compatibility)**:
> - **Rust-Style Ownership Parameters Preserved**: Explicit ownership modifiers (`borrow`, `mut borrow`, `take`) remain required and support grouped declarations (`function Distance(borrow a, b: Point) return Float64;`).
> - **Hard Syntax Cutover**: Legacy syntax (`function ...: Type`, `function ...: Void`, anonymous `end;` on routines/modules, units without `interface`/`implementation`) is rejected cleanly.

- [x] **57.1 Strict Tokens, AST & Parser (`procedure`, `return T is`, `end Name;`, `end Module.`)**.
- [x] **57.2 Structured Object Pascal Unit Layout (`interface`, `implementation`, `initialization`, `finalization`) & Semantics**.
- [x] **57.3 Tooling Updates (`fmt`, `lint`, `doc`, `derives`, `delsafec new`)**.
- [x] **57.4 Full Repository Cutover & Test Suite (`tests/15_fase57_ada_syntax_units_test.dels`, 15/15 PASS on FPC and C99)**.

---

### ✅ Phase 58: Typed Block/Declaration Endings (`end if;`, `end while;`, `end record;`, ...) & Flattened `else if` (Completed)

> **Design Decisions (Clean Cutover, No `elsif`)**:
> - **Flattened `else if`**: Conditional chains use `else if <cond> then ...` and close with a single `end if;` at the end of the entire chain.
> - **Mandatory Typed Endings**: `end if;`, `end while;`, `end for;`, `end match;`, `end try;`, `end unsafe;`, `end asm;`, `end record;`, `end enum;`, `end trait;`, `end impl;` (`repeat ... until` continues closing with `until`; bare `end;` is rejected).

- [x] **58.1 Lexer & Parser (`uDelSafeLexer.pas`, `uDelSafeParser.pas`)**.
- [x] **58.2 Tooling (`uDelSafeFormatter.pas`, `uDelSafeProject.pas`, `uDelSafeLSP.pas`, VS Code Snippets)**.
- [x] **58.3 Full Repository Migration (`std/`, `tests/`, `examples/`, `docs/course/`)**.
- [x] **58.4 Test Suite & Dual-Backend Verification (`tests/17_fase58_typed_end_and_elseif_test.dels`, 17/17 PASS on FPC and C99)**.

---

### ✅ Phase 59: Native Ecosystem Integration — MSYS2 / `pkg-config`, Auto DLL Bundling & `fppkg`/Lazarus OPM (Completed)

> **Goal**: Leverage native C/C++ packages (via MSYS2/`pacman` + `pkg-config` on Windows and system managers + `pkg-config` on Linux/macOS) and Pascal packages from `fppkg`/Lazarus OPM seamlessly.

- [x] **59.1 Universal C Library Resolution via `pkg-config`** (`"system_libs"` in `delsafe.json`, `--sys-lib=<lib>`).
- [x] **59.2 MSYS2 `pacman` Integration (`delsafec pkg add-sys <lib>`) & Automatic Windows DLL Bundling (`BundleMSYS2Dlls`)**.
- [x] **59.3 Free Pascal `fppkg` & Lazarus OPM Discovery** (`"pascal_packages"`, `--fpc-pkg=<pkg>`, `delsafec pkg add-fpc <pkg>`).
- [x] **59.4 `extern c "<lib>"` Auto-Linking & Transitive Native Dependency Propagation** (`tests/language/ffi/msys2_sqlite3_autolink_test.dels`, FPC 28/28 | C99 28/28 PASS).

---

### ✅ Phase 60: Complete Self-Upgrade System (`delsafec upgrade`), Multiplatform Releases & Official Installers (Completed)

- [x] **60.1 `delsafec upgrade` Hardening & Full Atomic Update (`uDelSafeUpgrade.pas`, `delsafec.lpr`)**:
  - Atomic update of both executable (`bin/delsafec`) and standard library (`std/*.dels`) with `.bak` / `std.bak` backup and full `--rollback`.
  - Safe Windows binary lock handling during `--from-source`, `nightly` channel (`--nightly` / `--channel=nightly`), mandatory SHA-256 verification by default (`E9991`, `E9992`, `--allow-unsigned`), offline `--url=file:///...`, POSIX `chmod +x`, local `~/.delsafe/update_check.json` cache, and unified `-V` / `--version`.
- [x] **60.2 Multiplatform Release Packaging & CI/CD (`scripts/package_release.*`, `.github/workflows/release.yml`)**:
  - Cross-platform `.zip`/`.tar.gz` + `.sha256` + `SHA256SUMS.txt` builders and automated GitHub Releases on `v*.*.*` tags, weekly `nightly` schedule, and `workflow_dispatch`.
- [x] **60.3 Official Multiplatform Installers (`scripts/install.ps1`, `scripts/install.sh`)**:
  - Installs into `~/.delsafe/bin` + `~/.delsafe/std` with SHA-256 validation, `--nightly`/`--version`, and `PATH` configuration, verified offline across check, nightly, invalid/missing checksum errors, full upgrade, and rollback.
