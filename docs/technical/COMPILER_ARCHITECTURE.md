# Internal Architecture of the DelSafe Compiler (`delsafec`)

The official DelSafe compiler (`delsafec`) is implemented in **Free Pascal** as a modular, multi-stage pipeline compiler.

---

## 1. Compilation Pipeline

```text
  [ Source Code .dels ]
           |
           v
  [ 1. Lexical Analyzer (uDelSafeLexer) ] --------> Emits Token Stream (uDelSafeTokens)
           |
           v
  [ 2. Recursive Parser (uDelSafeParser) ] -------> Builds Typed AST (uDelSafeAST)
           |
           v
  [ 3. Symbol Table & Type Checker ] ------------> Validates Scopes & Types (uDelSafeTypeChecker)
           |
           v
  [ 4. Ownership Analyzer (Borrow Checker) ] ----> Enforces Ownership Rules (uDelSafeBorrowChecker)
           |
           v
  [ 5. Code Emitter & Toolchain ]
           |-- Option A (Default): Object Pascal Emitter (uDelSafeEmitterPascal) -> Invokes FPC
           '-- Option B (--target=c): C99 Emitter (uDelSafeEmitterC) ---------------> Invokes GCC/Clang
```

---

## 2. Core Compiler Modules

### `uDelSafeTokens.pas`
Defines the token enumeration (`TTokenKind`), including structural keywords (`tokModule`, `tokContract`, `tokRecord`), ownership modifiers (`tokTake`, `tokBorrow`, `tokMut`), and operators, tracking line and column positions accurately.

### `uDelSafeLexer.pas`
Scanner supporting:
- String and character literals (with `\n`, `\t`, `\"`, `\\`, `\0` escapes);
- Numeric literals (decimals, floats, hex `$FF`/`0xFF`, binary `%1010`/`0b1010`);
- Line comments (`//`, `///`) and block comments (`{ ... }` and `/* ... */`).

### `uDelSafeAST.pas`
Abstract Syntax Tree node hierarchy:
- Declarations (`TASTModule`, `TASTRecordDecl`, `TASTEnumDecl`, `TASTFunction`, `TASTProgramBlock`);
- Statements (`TASTAssignStmt`, `TASTIfStmt`, `TASTWhileStmt`, `TASTForStmt`, `TASTMatchStmt`, `TASTReturnStmt`);
- Expressions (`TASTLiteralExpr`, `TASTIdentifierExpr`, `TASTMemberAccessExpr`, `TASTBinaryExpr`, `TASTCallExpr`).

### `uDelSafeParser.pas`
Hand-written recursive-descent parser supporting generic types (`Result<T, E>`, `Option<T>`, `Task<T>`), exhaustive pattern matching (`match...do...case...end match`), native contracts (`require` / `ensure`), typed block endings (`end if;`, `end while;`, `end record;`, `end trait;`), and UFCS method-call desugaring.

### `uDelSafeSymbols.pas` & `uDelSafeTypeChecker.pas`
Manages hierarchical lexical symbol tables, validates strict type compatibility, enforces immutability for `let` bindings, resolves polymorphic built-ins (`Abs`, `Min`, `Max`, `Clamp`), and verifies `match` exhaustiveness.

### `uDelSafeBorrowChecker.pas`
Static lifetime and ownership analyzer. Tracks each variable's state (`vsOwned`, `vsMoved`, `vsBorrowedShared`, `vsBorrowedMut`), records moves via `take`, enforces disjoint field borrows, emits automatic RAII `Drop` calls, and prevents *Use-After-Move* and *Double-Move* with structured diagnostics (`E0382`, `E0502`).

### `uDelSafeToolchain.pas`
Detects the host toolchain across platforms:
- **On Windows:** Locates `fpc.exe`, MSYS2 UCRT64 `gcc.exe` (`C:\msys64\ucrt64\bin\gcc.exe`), `clang.exe`, and `pas2js.exe`, adjusting `PATH` automatically.
- **On Linux/macOS:** Detects system-installed `fpc`, `gcc`, `clang`, and `pas2js`.
- Compiles and links final native binaries, shared libraries, WebAssembly modules, and JavaScript bundles.
