# Aether Package Manager and Dependencies (`aetherc pkg`)

**Aether** ships with a modern, decentralized, cryptographically verified package manager built directly into the `aetherc` compiler.

It manages local dependencies, remote Git repositories, semantic versions, and lockfiles with SHA integrity and TLS verification.

---

## 1. Architecture Overview

1. **Declarative Manifest (`aether.json`):** Defines project metadata, entry point (`entry`), default backend (`pascal` or `c`), and dependency declarations.
2. **Cryptographic Lockfile (`aether.lock`):** Pins the exact Git commit hashes installed, guaranteeing 100% *Reproducible Builds*.
3. **Integrity Audit (`aetherc pkg audit`):** Detects tampering in downloaded files and enforces secure TLS connections (`https://`).
4. **Global Cache and Local Dependencies:**
   - Remote packages are stored in the global cache (`~/.aether/cache/<package>`).
   - Active copies are synchronized into the current project's `.aether/deps/<package>` directory.
   - Dependencies are automatically restored during `aetherc build`, `run`, and `test`.

---

## 2. Standard Aether Project Layout

When you create a new project with `aetherc new my_app`:

```text
my_app/
├── aether.json           <- Configuration and dependency manifest
├── aether.lock           <- Exact version and commit lockfile
├── src/
│   └── main.aeth         <- Application entry point
├── tests/
│   └── main_test.aeth    <- Automated unit test suite
├── .aether/
│   └── deps/             <- Installed dependencies ready for import
├── bin/                  <- Compiled native executables
├── generated/            <- Organized transpiled output
│   ├── pascal/           <- Object Pascal units and programs
│   └── c/                <- Native C99 source code
├── .gitignore            <- Ignores bin/, generated/, and .aether/deps/
└── README.md
```

---

## 3. The `aether.json` Manifest

Complete manifest example:

```json
{
  "name": "my_app",
  "version": "1.0.0",
  "description": "High-performance application written in Aether",
  "backend": "pascal",
  "entry": "src/main.aeth",
  "output": "bin/my_app.exe",
  "dependencies": [
    {
      "name": "logger_lib",
      "path": "libs/logger_lib"
    },
    {
      "name": "aether_http",
      "git": "https://github.com/aetherlang/aether-http.git",
      "version": "v1.2.0"
    }
  ]
}
```

---

## 4. Package Manager Subcommands (`aetherc pkg`)

### 4.1 Add Dependencies (`aetherc pkg add`)

You can add packages in three ways:

```bash
# 1. Via Git URL with a specific tag/version or branch:
aetherc pkg add https://github.com/aetherlang/aether-http.git --version=v1.2.0
aetherc pkg add https://github.com/aetherlang/aether-json.git --branch=main

# 2. Shorthand package@version syntax:
aetherc pkg add aether-sync@v2.0.0
aetherc pkg add https://github.com/aetherlang/aether-db.git#v1.0.0

# 3. Local dependency from another folder in a monorepo:
aetherc pkg add math_extra --path=libs/math_extra
```

The command fetches the repository, resolves the commit SHA, recursively syncs nested dependencies, and records everything in `aether.lock`.

### 4.2 List Dependencies (`aetherc pkg list` or `ls`)

Displays a clean summary of all declared dependencies and their sources:

```bash
aetherc pkg list
```

Output:
```text
========================================================
  Project Dependencies: "my_app" (v1.0.0)
========================================================
  * logger_lib         -> Local: libs/logger_lib
  * aether_http        -> Git: https://github.com/aetherlang/aether-http.git (v1.2.0)
========================================================
```

### 4.3 Security & Integrity Audit (`aetherc pkg audit`)

Verifies that local packages match the exact commit hashes pinned in `aether.lock` and validates network security policies:

```bash
aetherc pkg audit
```

Output:
```text
========================================================
  Aether Security & Integrity Auditor (aetherc pkg audit)
========================================================
Auditing dependencies in: C:\Users\...\my_app
  [OK] aether_http: Commit e89b147a23 verified intact (Secure TLS: Yes)
  [OK] logger_lib: Local dependency at "libs/logger_lib" (Trusted local source)

--------------------------------------------------------
 Results: 2 packages audited | 0 tampered | 0 warnings
 Status: SECURE ENVIRONMENT (BlaiseVue Verified)
========================================================
```

### 4.4 Update Dependencies (`aetherc pkg update` or `upgrade`)

Fetches newer versions or commits from Git remotes and updates both the manifest and lockfile:

```bash
# Update all dependencies
aetherc pkg update

# Update a single dependency
aetherc pkg update aether_http
```

### 4.5 Remove Dependencies (`aetherc pkg remove` or `rm`)

Removes the dependency from `aether.json`, updates `aether.lock`, and cleans its files from `.aether/deps/`:

```bash
aetherc pkg remove aether_http
# or shorthand:
aetherc pkg rm aether_http
```

### 4.6 Clean Global Cache (`aetherc pkg clean`)

Clears the shared cache at `~/.aether/cache/`, forcing fresh downloads when needed:

```bash
aetherc pkg clean
```
