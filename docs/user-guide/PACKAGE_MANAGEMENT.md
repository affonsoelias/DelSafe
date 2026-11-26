# DelSafe Package Manager and Dependencies (`delsafec pkg`)

**DelSafe** ships with a modern, decentralized, cryptographically verified package manager built directly into the `delsafec` compiler.

It manages local dependencies, remote Git repositories, semantic versions, and lockfiles with SHA integrity and TLS verification.

---

## 1. Architecture Overview

1. **Declarative Manifest (`delsafe.json`):** Defines project metadata, entry point (`entry`), default backend (`pascal` or `c`), and dependency declarations.
2. **Cryptographic Lockfile (`delsafe.lock`):** Pins the exact Git commit hashes installed, guaranteeing 100% *Reproducible Builds*.
3. **Integrity Audit (`delsafec pkg audit`):** Detects tampering in downloaded files and enforces secure TLS connections (`https://`).
4. **Global Cache and Local Dependencies:**
   - Remote packages are stored in the global cache (`~/.delsafe/cache/<package>`).
   - Active copies are synchronized into the current project's `.delsafe/deps/<package>` directory.
   - Dependencies are automatically restored during `delsafec build`, `run`, and `test`.

---

## 2. Standard DelSafe Project Layout

When you create a new project with `delsafec new my_app`:

```text
my_app/
├── delsafe.json           <- Configuration and dependency manifest
├── delsafe.lock           <- Exact version and commit lockfile
├── src/
│   └── main.dels         <- Application entry point
├── tests/
│   └── main_test.dels    <- Automated unit test suite
├── .delsafe/
│   └── deps/             <- Installed dependencies ready for import
├── bin/                  <- Compiled native executables
├── generated/            <- Organized transpiled output
│   ├── pascal/           <- Object Pascal units and programs
│   └── c/                <- Native C99 source code
├── .gitignore            <- Ignores bin/, generated/, and .delsafe/deps/
└── README.md
```

---

## 3. The `delsafe.json` Manifest

Complete manifest example:

```json
{
  "name": "my_app",
  "version": "1.0.0",
  "description": "High-performance application written in DelSafe",
  "backend": "pascal",
  "entry": "src/main.dels",
  "output": "bin/my_app.exe",
  "dependencies": [
    {
      "name": "logger_lib",
      "path": "libs/logger_lib"
    },
    {
      "name": "delsafe_http",
      "git": "https://github.com/delsafe/delsafe-http.git",
      "version": "v1.2.0"
    }
  ]
}
```

---

## 4. Package Manager Subcommands (`delsafec pkg`)

### 4.1 Add Dependencies (`delsafec pkg add`)

You can add packages in three ways:

```bash
# 1. Via Git URL with a specific tag/version or branch:
delsafec pkg add https://github.com/delsafe/delsafe-http.git --version=v1.2.0
delsafec pkg add https://github.com/delsafe/delsafe-json.git --branch=main

# 2. Shorthand package@version syntax:
delsafec pkg add delsafe-sync@v2.0.0
delsafec pkg add https://github.com/delsafe/delsafe-db.git#v1.0.0

# 3. Local dependency from another folder in a monorepo:
delsafec pkg add math_extra --path=libs/math_extra
```

The command fetches the repository, resolves the commit SHA, recursively syncs nested dependencies, and records everything in `delsafe.lock`.

### 4.2 List Dependencies (`delsafec pkg list` or `ls`)

Displays a clean summary of all declared dependencies and their sources:

```bash
delsafec pkg list
```

Output:
```text
========================================================
  Project Dependencies: "my_app" (v1.0.0)
========================================================
  * logger_lib         -> Local: libs/logger_lib
  * delsafe_http        -> Git: https://github.com/delsafe/delsafe-http.git (v1.2.0)
========================================================
```

### 4.3 Security & Integrity Audit (`delsafec pkg audit`)

Verifies that local packages match the exact commit hashes pinned in `delsafe.lock` and validates network security policies:

```bash
delsafec pkg audit
```

Output:
```text
========================================================
  DelSafe Security & Integrity Auditor (delsafec pkg audit)
========================================================
Auditing dependencies in: C:\Users\...\my_app
  [OK] delsafe_http: Commit e89b147a23 verified intact (Secure TLS: Yes)
  [OK] logger_lib: Local dependency at "libs/logger_lib" (Trusted local source)

--------------------------------------------------------
 Results: 2 packages audited | 0 tampered | 0 warnings
 Status: SECURE ENVIRONMENT (BlaiseVue Verified)
========================================================
```

### 4.4 Update Dependencies (`delsafec pkg update` or `upgrade`)

Fetches newer versions or commits from Git remotes and updates both the manifest and lockfile:

```bash
# Update all dependencies
delsafec pkg update

# Update a single dependency
delsafec pkg update delsafe_http
```

### 4.5 Remove Dependencies (`delsafec pkg remove` or `rm`)

Removes the dependency from `delsafe.json`, updates `delsafe.lock`, and cleans its files from `.delsafe/deps/`:

```bash
delsafec pkg remove delsafe_http
# or shorthand:
delsafec pkg rm delsafe_http
```

### 4.6 Clean Global Cache (`delsafec pkg clean`)

Clears the shared cache at `~/.delsafe/cache/`, forcing fresh downloads when needed:

```bash
delsafec pkg clean
```
