# Chapter 12: Modules, Multi-File Projects & Package Management

As applications grow beyond single scripts, organizing code into clean, cohesive modules and managing third-party dependencies becomes critical for maintainability and security.

Aether provides **a modern, decentralized, cryptographically verified package manager** built directly into the `aetherc` compiler CLI (`aetherc pkg`).

---

## 1. The Module System

In Aether, **every file is a module**. The module system is designed around three strict principles:

1. **1:1 Mapping Rule:** The declared module name `module <Name>;` must strictly match the file name (`<Name>.aeth`).
2. **Deterministic Imports:** A module imports another module using `import <ModuleName>;`.
3. **No Circular Dependency Spaghetti:** The compiler builds an explicit Directed Acyclic Graph (DAG) of dependencies during parsing.

### Example: Multi-Module Setup

```text
my_project/
├── src/
│   ├── auth.aeth         <- module auth;
│   ├── database.aeth     <- module database;
│   └── main.aeth         <- module main;
```

`database.aeth`:
```aether
module database;

type
    DbConnection = record
        host: String;
        port: Int32;
    end;

function Connect(host: String, port: Int32): DbConnection
begin
    return DbConnection(host, port);
end;
```

`auth.aeth`:
```aether
module auth;

import database;

function Authenticate(borrow db: DbConnection, token: String): Bool
begin
    // Validating against database
    return Length(token) >= 8;
end;
```

`main.aeth`:
```aether
module main;

import database as db_mod;
import auth;

program Main;
var
    conn: db_mod.DbConnection;
    is_ok: Bool;
begin
    conn := db_mod.Connect("127.0.0.1", 5432);
    is_ok := Authenticate(borrow conn, "secure_session_token");

    if is_ok then
        PrintLn("Authentication granted!");
    end;
end.
```

### Visibility (`pub` / `priv`) and Import Aliases (`as`)
- Use `import module_path as alias;` to bind a short qualifier and reference symbols cleanly (`alias.Func()`, `alias.CONST`, `alias.Enum.Variant`, `alias.Record.Method()`).
- Prefix declarations (`const`, `type`, `trait`, `function`, record fields, or `impl` methods) with `pub` or `priv`. Once a module uses `pub` or `priv` at top level, unqualified top-level declarations become module-private (`[E0603]` if accessed externally), while existing modules without explicit `pub` modifiers keep backwards-compatible exports.

---

## 2. Standard Project Structure

When you initialize a new project with `aetherc new <project_name>`:

```bash
aetherc new my_service
```

Aether generates the canonical directory hierarchy:

```text
my_service/
├── aether.json           <- Project manifest and dependency declarations
├── aether.lock           <- Cryptographic lockfile (exact commit hashes)
├── src/
│   └── main.aeth         <- Application entry point
├── tests/
│   └── main_test.aeth    <- Automated test suite (run with 'aetherc test')
├── .aether/
│   └── deps/             <- Installed dependencies (gitignored)
├── bin/                  <- Output native binaries (gitignored)
├── generated/            <- Intermediate transpiled code (gitignored)
│   ├── pascal/           <- Object Pascal outputs
│   └── c/                <- C99 outputs
├── .gitignore            <- Standard gitignore for binary hygiene
└── README.md
```

---

## 3. The Project Manifest: `aether.json`

The `aether.json` file is the declarative manifest for your project:

```json
{
  "name": "my_service",
  "version": "1.0.0",
  "description": "High-throughput microservice built with Aether and Zephyr",
  "backend": "pascal",
  "entry": "src/main.aeth",
  "output": "bin/my_service.exe",
  "dependencies": [
    {
      "name": "aether_json",
      "git": "https://github.com/aetherlang/aether-json.git",
      "version": "v1.2.0"
    },
    {
      "name": "local_utils",
      "path": "libs/local_utils"
    }
  ]
}
```

### Manifest Fields:
- `backend`: Default target backend (`"pascal"` or `"c"`).
- `entry`: Relative path to the application's main entry file.
- `output`: Destination binary path.
- `dependencies`: List of external Git packages or local mono-repo path dependencies.

---

## 4. Using the Package Manager (`aetherc pkg`)

Aether's package manager handles downloading, updating, and locking dependencies without external package managers like npm or cargo.

### 4.1 Adding Dependencies (`aetherc pkg add`)

You can add dependencies via Git URL, semantic tag, branch, or local folder:

```bash
# 1. Add remote Git repository with a semantic version tag:
aetherc pkg add https://github.com/aetherlang/aether-http.git --version=v1.2.0

# 2. Add remote Git repository pinned to a specific branch:
aetherc pkg add https://github.com/aetherlang/aether-json.git --branch=main

# 3. Add shorthand package@version from the official Registry:
aetherc pkg add aether-crypto@v2.1.0

# 4. Add a local mono-repo dependency:
aetherc pkg add common_types --path=libs/common_types
```

When you run `pkg add`, the compiler:
1. Clones or fetches the repository into the global cache (`~/.aether/cache`).
2. Extracts the exact Git commit SHA.
3. Resolves and links nested dependencies recursively.
4. Updates `aether.json` and writes the exact cryptographic state to `aether.lock`.

### 4.2 Listing Dependencies (`aetherc pkg list` or `ls`)

Inspect all active dependencies in the current project:

```bash
aetherc pkg list
```

Output:
```text
========================================================
  Aether Package Manager - Active Dependencies
========================================================
  * aether_http   v1.2.0  [Git: https://github.com/aetherlang/aether-http.git]
  * aether_json   v1.0.4  [Git: https://github.com/aetherlang/aether-json.git]
  * local_utils   (local) [Path: libs/local_utils]
--------------------------------------------------------
  Total: 3 dependencies registered.
========================================================
```

### 4.3 Updating Dependencies (`aetherc pkg update`)

To update dependencies to their latest upstream tags/commits:

```bash
aetherc pkg update
```

### 4.4 Removing Dependencies (`aetherc pkg remove <name>`)

```bash
aetherc pkg remove aether_http
```

---

## 5. The Cryptographic Lockfile: `aether.lock`

To achieve **100% Reproducible Builds**, Aether records the exact commit hash and tree state of every dependency in `aether.lock`:

```json
{
  "lockfile_version": 1,
  "generated_at": "2026-11-22T14:00:00Z",
  "packages": {
    "aether_http": {
      "git": "https://github.com/aetherlang/aether-http.git",
      "version": "v1.2.0",
      "commit": "8f3b21a4d9e0345b172a8c7e9a8f2c3104e8b91a"
    }
  }
}
```

Always commit `aether.lock` to your Git version control! This guarantees that any developer or CI/CD runner compiles the exact same bit-for-bit code.

---

## 6. Supply Chain Security: `aetherc pkg audit`

Aether includes a built-in security auditor to defend against supply chain attacks, man-in-the-middle tampering, and insecure network transports:

```bash
aetherc pkg audit
```

The auditor validates:
1. **TLS Transport Enforcement:** Flags any insecure HTTP dependency URLs (`http://`).
2. **Cryptographic Integrity:** Verifies that downloaded dependencies in `.aether/deps/` match the commit SHAs recorded in `aether.lock`.
3. **Circular Reference Analysis:** Detects cyclic dependency loops before compilation.

---

## 7. Global Cache & Offline Compilation

All downloaded packages are stored in the global Aether cache:
- Windows: `C:\Users\<User>\.aether\cache\`
- Linux / macOS: `~/.aether/cache/`

Once a package version is cached, Aether can compile your projects **100% offline** without network access.

---

## 8. Summary
1. Every file is a module: `module Name;` matches `Name.aeth`.
2. Projects use `aether.json` for metadata and dependencies.
3. Manage packages easily with `aetherc pkg add`, `list`, `update`, and `remove`.
4. Ensure 100% reproducible builds with `aether.lock` and audit security with `aetherc pkg audit`.

➡️ **Next:** **[Chapter 13: Capstone Project (Building a Real-World Service)](13_CAPSTONE_PROJECT.md)**
