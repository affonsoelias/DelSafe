# Official VS Code Extension for Aether (AetherLang)

This extension adds full first-class support for the **Aether** programming language (`.aeth`) in Visual Studio Code and derivatives (Cursor, VSCodium, Windsurf).

---

## Features

1. **High-Performance Native LSP (`aetherc --lsp`):**
   - **Canonical Formatting (`Shift + Alt + F` / `formatOnSave`)**: Direct integration with `textDocument/formatting` powered by `uAetherFormatter.pas` (4-space indentation, normalized operators).
   - **Safe Refactoring (`F2` / Rename Symbol)**: Atomic workspace-wide rename via `textDocument/rename` without altering literals or comments.
   - **Quick-Fix Code Actions (`Ctrl + .`)**: Instant suggestions to resolve ownership conflicts (`borrow` or `mut borrow`) and auto-import standard library modules (`std.fs`, `std.time`, `std.http`, `std.json`).
   - **Smart Autocompletion (`Ctrl + Space`)**: Keywords, ownership modifiers, primitive types, monads, and local symbols.
   - **Hover Documentation**: Function signatures, inferred types, and ownership semantics tooltips.
   - **Go to Definition (`F12`)**: Instant navigation to functions, record types, traits, and enums.
2. **Full Syntax Highlighting (TextMate Grammar):**
   - Semantic colors for modules, records, algebraic enums, contracts (`require`/`ensure`), operators, and literals.
   - Dedicated highlighting for ownership modifiers (`borrow`, `take`, `mut`).
   - Built-in highlighting for monads (`Result`, `Option`, `Ok`, `Err`, `Some`, `None`).
3. **Smart Snippets:**
   - Generate modules, functions with contracts, records, algebraic enums, and exhaustive `match` blocks cleanly with `Tab`.
4. **Built-In Commands:**
   - `Aether: Format Document (Shift+Alt+F)`.
   - `Aether: Compile Current File (Pascal Backend)`.
   - `Aether: Compile Current File (C99 / GCC Backend)`.
   - `Aether: Build Project (Build)`.
   - `Aether: Run Project (Run)`.

---

## Local Installation in VS Code

You can install the extension in **under 30 seconds** using either method below:

### Method 1: Direct Copy to Extensions Folder (Recommended)

Open a terminal (PowerShell on Windows) and run:

```powershell
# Create local VS Code extension directory
New-Item -ItemType Directory -Path "$HOME/.vscode/extensions/aether-lang" -Force

# Copy extension files
Copy-Item -Path "editors/vscode/*" -Destination "$HOME/.vscode/extensions/aether-lang" -Recurse -Force
```

Then restart or reload VS Code (`Ctrl + Shift + P` -> `Developer: Reload Window`). Any `.aeth` file will open with full syntax highlighting and tooling enabled!

### Method 2: VSIX Packaging (via `vsce`)

If you have npm's `vsce` tool installed:

```bash
cd editors/vscode
npx @vscode/vsce package
code --install-extension aether-lang-1.0.0.vsix
```

---

## Optional Settings

In your VS Code `settings.json`:

```json
{
  "aether.compilerPath": "c:/Users/Pichau/Documents/aether/bin/aetherc.exe"
}
```
*(If omitted, the extension automatically searches for `bin/aetherc.exe` inside the active workspace).*
