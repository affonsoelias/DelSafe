# Official DelSafe Language Extension for VS Code

Full smart language support for the **DelSafe** programming language (`delsafec`).

---

## Features

1. **Rich Syntax Highlighting**:
   - Control flow and contract keywords: `module`, `import`, `function`, `procedure`, `contract`, `require`, `ensure`, `type`, `record`, `enum`, `trait`, `impl`, `for`, `match`, `case`.
   - Ownership & concurrency semantics: `borrow`, `take`, `mut borrow`, `mut`, `own`, `async`, `await`, `spawn`.
   - Built-in types and monads: `Int8`..`Int64`, `UInt8`..`UInt64`, `Float32`, `Float64`, `Bool`, `String`, `Void`, `Result<T, E>`, `Option<T>`, `Box<T>`.

2. **Language Server Protocol (Integrated LSP)**:
   - Native connection to `delsafec lsp`.
   - **Autocompletion**: Keywords, primitive types, monads, function signatures, and trait/UFCS methods.
   - **Hover**: Inferred types, contracts, and ownership documentation.
   - **Go-to-Definition**: Quick navigation to functions, records, enums, and traits.
   - **Real-Time Diagnostics**: Syntax, type, and Borrow Checker errors reported live.

3. **Useful Snippets**:
   - `module`: Executable module scaffold.
   - `fn`: Function with formal contracts (`require` / `ensure`).
   - `trait`: Trait interface definition.
   - `impl`: Trait implementation for a type.
   - `record`: Record struct declaration.
   - `enum`: Algebraic enum declaration.
   - `match`: Exhaustive `Result` pattern matching.
   - `test`: Unit test function.

4. **Build and Test Commands**:
   - `DelSafe: Compile Current File (Pascal Backend)`
   - `DelSafe: Compile Current File (C99 / GCC Backend)`
   - `DelSafe: Run Unit Tests (delsafec test)`
   - `DelSafe: Restart Language Server (LSP)`

---

## Local Installation

To test and use locally in VS Code:

1. Copy the `ide/vscode` folder into your VS Code extensions directory:
   - On Windows: `%USERPROFILE%\.vscode\extensions\delsafe-lang`
2. Restart or reload Visual Studio Code (`Ctrl+Shift+P` -> `Developer: Reload Window`).
3. Open any file with the `.dels` extension.
