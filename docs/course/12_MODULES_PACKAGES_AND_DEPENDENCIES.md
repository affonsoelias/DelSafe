# Chapter 12: Modules, Multi-File Projects & Package Management

As applications grow beyond single scripts, organizing code into clean, cohesive modules and managing third-party dependencies becomes critical for maintainability and security.

DelSafe provides **a modern, decentralized, cryptographically verified package manager** built directly into the `delsafec` compiler CLI (`delsafec pkg`).

---

## 1. The Module System

In DelSafe, **every file is a module**. The module system is designed around three strict principles:

1. **1:1 Mapping Rule:** The declared module name `module <Name>;` must strictly match the file name (`<Name>.dels`).
2. **Deterministic Imports:** A module imports another module using `import <ModuleName>;`.
3. **No Circular Dependency Spaghetti:** The compiler builds an explicit Directed Acyclic Graph (DAG) of dependencies during parsing.

### Example: Multi-Module Setup

```text
my_project/
├── src/
│   ├── auth.dels         <- module auth;
│   ├── database.dels     <- module database;
│   └── main.dels         <- module main;
```

`database.dels` (an Object Pascal-style Unit with `interface` and `implementation`):
```delsafe
module database;

interface

type
    DbConnection = record
        host: String;
        port: Int32;
    end record;

function Connect(host: String; port: Int32) return DbConnection;

implementation

function Connect(host: String; port: Int32) return DbConnection is
begin
    return DbConnection(host, port);
end Connect;

end database.
```

`auth.dels` (a Unit with optional `initialization` / `finalization`):
```delsafe
module auth;

import database;

interface

function Authenticate(borrow db: DbConnection; token: String) return Bool;

implementation

function Authenticate(borrow db: DbConnection; token: String) return Bool is
begin
    // Validating against database
    return Length(token) >= 8;
end Authenticate;

end auth.
```

`main.dels`:
```delsafe
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
    end if;
end main.
```

### Structured Units & Visibility (`interface` / `implementation` / `pub` / `priv`)
- Modules without `program Main;` are **Units** and require Object Pascal sections: `interface` (exported public declarations, routine signatures, contracts, and public module variables) followed by `implementation` (routine bodies and module-private state), plus optional `initialization` and `finalization` sections, closed with `end <ModuleName>.`.
- Use `import module_path as alias;` to bind a short qualifier and reference symbols cleanly (`alias.Func()`, `alias.CONST`, `alias.Enum.Variant`, `alias.Record.Method()`).
- Prefix declarations (`const`, `type`, `trait`, `function`, `procedure`, record fields, or `impl` methods) with `pub` or `priv` inside `interface`/`impl` to fine-tune access (`[E0603]` if a private item is accessed externally).

---

## 2. Standard Project Structure

When you initialize a new project with `delsafec new <project_name>`:

```bash
delsafec new my_service
```

DelSafe generates the canonical directory hierarchy:

```text
my_service/
├── delsafe.json              <- Project manifest and dependency declarations
├── delsafe.lock              <- Cryptographic lockfile (exact commit hashes)
├── src/
│   └── my_service.dels      <- Application entry point (module my_service; program Main;)
├── tests/
│   └── my_service_test.dels <- Automated test suite (run with 'delsafec test')
├── .delsafe/
│   └── deps/             <- Installed dependencies (gitignored)
├── bin/                  <- Output native binaries (gitignored)
├── generated/            <- Intermediate transpiled code (gitignored)
│   ├── pascal/           <- Object Pascal outputs
│   └── c/                <- C99 outputs
├── .gitignore            <- Standard gitignore for binary hygiene
└── README.md
```

---

## 3. The Project Manifest: `delsafe.json`

The `delsafe.json` file is the declarative manifest for your project:

```json
{
  "name": "my_service",
  "version": "1.0.0",
  "description": "High-throughput microservice built with DelSafe and Zephyr",
  "backend": "pascal",
  "entry": "src/main.dels",
  "output": "bin/my_service.exe",
  "dependencies": [
    {
      "name": "delsafe_json",
      "git": "https://github.com/delsafe/delsafe-json.git",
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

## 4. Using the Package Manager (`delsafec pkg`)

DelSafe's package manager handles downloading, updating, and locking dependencies without external package managers like npm or cargo.

### 4.1 Adding Dependencies (`delsafec pkg add`)

You can add dependencies via Git URL, semantic tag, branch, or local folder:

```bash
# 1. Add remote Git repository with a semantic version tag:
delsafec pkg add https://github.com/delsafe/delsafe-http.git --version=v1.2.0

# 2. Add remote Git repository pinned to a specific branch:
delsafec pkg add https://github.com/delsafe/delsafe-json.git --branch=main

# 3. Add shorthand package@version from the official Registry:
delsafec pkg add delsafe-crypto@v2.1.0

# 4. Add a local mono-repo dependency:
delsafec pkg add common_types --path=libs/common_types
```

When you run `pkg add`, the compiler:
1. Clones or fetches the repository into the global cache (`~/.delsafe/cache`).
2. Extracts the exact Git commit SHA.
3. Resolves and links nested dependencies recursively.
4. Updates `delsafe.json` and writes the exact cryptographic state to `delsafe.lock`.

### 4.2 Listing Dependencies (`delsafec pkg list` or `ls`)

Inspect all active dependencies in the current project:

```bash
delsafec pkg list
```

Output:
```text
========================================================
  DelSafe Package Manager - Active Dependencies
========================================================
  * delsafe_http   v1.2.0  [Git: https://github.com/delsafe/delsafe-http.git]
  * delsafe_json   v1.0.4  [Git: https://github.com/delsafe/delsafe-json.git]
  * local_utils   (local) [Path: libs/local_utils]
--------------------------------------------------------
  Total: 3 dependencies registered.
========================================================
```

### 4.3 Updating Dependencies (`delsafec pkg update`)

To update dependencies to their latest upstream tags/commits:

```bash
delsafec pkg update
```

### 4.4 Removing Dependencies (`delsafec pkg remove <name>`)

```bash
delsafec pkg remove delsafe_http
```

---

## 5. The Cryptographic Lockfile: `delsafe.lock`

To achieve **100% Reproducible Builds**, DelSafe records the exact commit hash and tree state of every dependency in `delsafe.lock`:

```json
{
  "lockfile_version": 1,
  "generated_at": "2026-11-22T14:00:00Z",
  "packages": {
    "delsafe_http": {
      "git": "https://github.com/delsafe/delsafe-http.git",
      "version": "v1.2.0",
      "commit": "8f3b21a4d9e0345b172a8c7e9a8f2c3104e8b91a"
    }
  }
}
```

Always commit `delsafe.lock` to your Git version control! This guarantees that any developer or CI/CD runner compiles the exact same bit-for-bit code.

---

## 6. Supply Chain Security: `delsafec pkg audit`

DelSafe includes a built-in security auditor to defend against supply chain attacks, man-in-the-middle tampering, and insecure network transports:

```bash
delsafec pkg audit
```

The auditor validates:
1. **TLS Transport Enforcement:** Flags any insecure HTTP dependency URLs (`http://`).
2. **Cryptographic Integrity:** Verifies that downloaded dependencies in `.delsafe/deps/` match the commit SHAs recorded in `delsafe.lock`.
3. **Circular Reference Analysis:** Detects cyclic dependency loops before compilation.

---

## 7. Global Cache & Offline Compilation

All downloaded packages are stored in the global DelSafe cache:
- Windows: `C:\Users\<User>\.delsafe\cache\`
- Linux / macOS: `~/.delsafe/cache/`

Once a package version is cached, DelSafe can compile your projects **100% offline** without network access.

---

## 8. Summary
1. Every file is a module: `module Name;` matches `Name.dels`.
2. Projects use `delsafe.json` for metadata and dependencies.
3. Manage packages easily with `delsafec pkg add`, `list`, `update`, and `remove`.
4. Ensure 100% reproducible builds with `delsafe.lock` and audit security with `delsafec pkg audit`.

➡️ **Next:** **[Chapter 13: Capstone Project (Building a Real-World Service)](13_CAPSTONE_PROJECT.md)**
