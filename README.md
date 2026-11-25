# Aether Programming Language

> **A modern systems programming language combining the structured readability of Pascal, static memory safety with an ownership and borrow checker, and native dual compilation to Free Pascal and C99.**

---

## Key Highlights

- **Compile-Time Memory Safety**: Ownership semantics (`take`, `borrow`, `mut borrow`) without a garbage collector or runtime overhead.
- **Dual Native Toolchain**: Directly targets Free Pascal (`--target=pascal`) and GCC C99 (`--target=c`), with WebAssembly (`--target=wasm`) and JavaScript (`--target=js`) support.
- **Modern Metaprogramming**: Automatic code synthesis for `record` and `enum` types via `[derive(Debug, JSON, Clone, Equals)]`.
- **Structured Concurrency**: Native lightweight coroutines with `async function`, `await`, and `Task<T>`.
- **Native OS Sockets & HTTP**: Kernel-level socket abstractions with zero-copy request handling (`std/net.aeth`).
- **BlaiseVue Ready**: Seamless unit generation (`--unit`) and home to **Zephyr**, BlaiseVue's native high-performance backend.
- **Built-in Developer Tooling**: Embedded Language Server (`aetherc lsp`), benchmark runner (`aetherc bench`), documentation generator (`aetherc doc`), and package management via **[aether-ecosystem](https://github.com/affonsoelias/aether-ecosystem)**.

---

## Quickstart in 60 Seconds

### Prerequisites

- **[Free Pascal Compiler (FPC 3.2+)](https://www.freepascal.org/)** *(Required)* — Builds `aetherc` from source and powers the default Object Pascal backend (`--target=pascal`).
- **[MSYS2](https://www.msys2.org/) (UCRT64) with GCC, Clang & `pkg-config`** *(Recommended on Windows)* — Required on Windows for the native C99 backend (`--target=c`, `--cc=gcc` or `--cc=clang`), WebAssembly compilation (`--target=wasm` via Clang), native C FFI resolution (`--sys-lib`, `aetherc pkg add-sys`), and automatic MSYS2 DLL bundling (`--bundle-dlls`):
  ```bash
  # Inside the MSYS2 UCRT64 terminal:
  pacman -S --needed mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-clang mingw-w64-ucrt-x86_64-lld mingw-w64-ucrt-x86_64-pkgconf
  ```
  Add `C:\msys64\ucrt64\bin` to your Windows `PATH` so `gcc`, `clang`, and `pkg-config` are discovered automatically.
- **GCC / Clang & `pkg-config` on Linux / macOS** *(Recommended)* — Install via your system package manager (e.g., `sudo apt install fp-compiler gcc clang lld pkg-config` on Debian/Ubuntu, or `brew install fpc llvm pkg-config` on macOS).
- **Pas2JS** *(Optional)* — Needed only for JavaScript output (`--target=js`; pre-bundled when using [BlaiseVue](https://github.com/affonsoelias/BlaiseVue)).

After building, run `./bin/aetherc --doctor` to verify your detected toolchains (`FPC`, `GCC`, `Clang`, `MSYS2`, `pkg-config`, and `Pas2JS`).

### Building the Compiler

```bash
# Windows (PowerShell or CMD)
.\build.bat
# or
.\build.ps1

# Linux / macOS
chmod +x build.sh && ./build.sh
```

### Writing Your First Program

Save as `hello.aeth`:

```aether
module main;

[derive(Debug, JSON, Clone, Equals)]
type
    User = record
        id: Int32;
        name: String;
        active: Bool;
    end record;

procedure UpdateUser(mut borrow u: User; new_name: String) is
begin
    u.name := new_name;
end UpdateUser;

program Main;
var
    user: User;
    clone: User;
begin
    user := User(1, "Alice", true);
    PrintLn("Debug: %s", user.ToString());
    PrintLn("JSON:  %s", user.ToJSON());

    UpdateUser(mut borrow user, "Bob");
    clone := user.Clone();

    if user.Equals(borrow clone) then
        PrintLn("User successfully updated and cloned!");
    end if;
end main.
```

### Compiling and Running

```bash
# Compile and run with the Free Pascal backend (default)
./bin/aetherc run hello.aeth

# Compile and run with the GCC C99 backend (high optimization)
./bin/aetherc run hello.aeth --target=c
```

---

## Architecture: Zephyr Backend for BlaiseVue

Aether powers **Zephyr** (`vendor/zephyr`), the native backend engine for the BlaiseVue framework:

1. **Source Code**: Written in clean, expressive Aether code with zero-copy borrow checking.
2. **Production Target**: Transpiles to C99 and compiles with GCC (`-O3 -flto -s`) for minimal RAM footprint and high request throughput.
3. **Development Target**: Transpiles to Object Pascal for smooth debugging with FPC and Lazarus.

---

## CLI Reference

| Command | Description |
| :--- | :--- |
| `aetherc build` | Build the current project based on `aether.json` |
| `aetherc run [file.aeth]` | Compile and execute immediately |
| `aetherc test [filter]` | Run unit and compile-fail test suite (`--target=pascal\|c\|all`) |
| `aetherc bench [filter]` | Run benchmark harness with multi-backend comparison |
| `aetherc profile <file>` | Execution profiler and runtime memory leak audit (`--runs=N`, `--json`) |
| `aetherc lint [path]` | Static linter and code quality analysis (`--fix` to auto-repair) |
| `aetherc doc [path]` | Generate HTML and Markdown documentation |
| `aetherc emit pascal --unit` | Emit clean Free Pascal unit for external consumption |
| `aetherc emit-header <file>` | Generate C header (`.h`) for C/C++ FFI |
| `aetherc lsp` | Launch Language Server Protocol engine |
| `aetherc upgrade` | Upgrade toolchain (`--check`, `--nightly`, `--from-source`, `--rollback`) |
| `aetherc --doctor` | Diagnose compiler toolchains (FPC, GCC, Clang, Pas2JS) |

---

## Branching, Channels & Release Model

Aether uses a streamlined single-branch workflow during pre-1.0 development:

- **Primary Branch (`main`)**: Single integration branch carrying active development (short-lived feature branches are optional for large changes).
- **`stable` Channel (`aetherc upgrade`)**: Pulls the latest official GitHub Release built automatically from SemVer tags (`v*.*.*`).
- **`nightly` Channel (`aetherc upgrade --nightly`)**: Pulls the weekly pre-release built every Sunday from `main` via [`.github/workflows/release.yml`](.github/workflows/release.yml).
- **Source Sync (`aetherc upgrade --from-source`)**: Syncs directly against `origin/main` and rebuilds the toolchain locally.

---

## Documentation

- [The Aether Masterclass Course](docs/course/README.md)
- [Documentation Index](docs/README.md)
- [Roadmap & Development Plan](docs/planning/DEVELOPMENT_ROADMAP.md)
- [Language Specification](docs/technical/LANGUAGE_SPECIFICATION.md)
- [BlaiseVue & Zephyr Integration](docs/technical/BLAISEVUE_AND_PASCAL_INTEGRATION.md)

---

## Ecosystem & Related Repositories

- **[Aether Ecosystem (`affonsoelias/aether-ecosystem`)](https://github.com/affonsoelias/aether-ecosystem)** — Official package registry (`registry/index.json`) and community ecosystem index for AetherLang.
- **[BlaiseVue (`affonsoelias/BlaiseVue`)](https://github.com/affonsoelias/BlaiseVue)** — Universal Object Pascal reactive framework powered by optional Aether interop and the native **Zephyr** backend.

---

## License

This project is licensed under the MIT License.
