# DelSafe Beginner's Guide

Welcome to **DelSafe**! This guide helps you configure your development environment and compile your first program in just a few minutes.

---

## 1. System Requirements

The official DelSafe compiler (`delsafec`) generates native code through highly optimized backends:

### On Windows:
1. **Free Pascal (or Lazarus):**
   - Download and install Lazarus or Free Pascal from: [https://www.lazarus-ide.org/](https://www.lazarus-ide.org/)
   - Ensure the `fpc` command is in your `PATH` or at the default path `C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe`.
2. **MSYS2 with GCC (Optional, to compile via C99):**
   - Download MSYS2 from: [https://www.msys2.org/](https://www.msys2.org/)
   - In the MSYS2 terminal, install the UCRT64 C compiler:
     ```bash
     pacman -S mingw-w64-ucrt-x86_64-gcc
     ```

### On Linux and macOS:
- Install Free Pascal and your system's default GCC:
  - **Debian / Ubuntu:** `sudo apt install fpc build-essential`
  - **Fedora:** `sudo dnf install fpc gcc`
  - **Arch Linux:** `sudo pacman -S fpc gcc`
  - **macOS:** `brew install fpc` and Xcode Command Line Tools (`xcode-select --install`).

---

## 2. Checking Your Environment with `delsafec --doctor`

To make sure your environment is 100% ready, run in the project terminal:

```bash
./bin/delsafec --doctor
```

The compiler automatically scans your environment and prints a report:
```text
--------------------------------------------------------
   DelSafe Environment Diagnostics (delsafec --doctor)
--------------------------------------------------------
[OK] Free Pascal (FPC) Found:
     Path    : fpc.exe
     Version : 3.2.2

[OK] C Compiler (GCC / MSYS2) Found:
     Path    : C:\msys64\ucrt64\bin\gcc.exe
     Version : gcc.exe (Rev3, Built by MSYS2 project) 16.2.0
     Env     : MSYS2 UCRT64 Active (C:\msys64\ucrt64\bin)
--------------------------------------------------------
Overall Status: Perfect! Both backends (Pascal and C) are operational.
--------------------------------------------------------
```

---

## 3. Your First Program ("Hello World")

Create a file named `my_first_app.dels`:

```pascal
module MyFirstApp;

program Main;
begin
    PrintLn("Hello, DelSafe World!");
    PrintLn("Rust-grade safety with Pascal elegance.");
end MyFirstApp.
```

### Compiling to a Native Executable:

To compile using the **Object Pascal Backend** (Default):
```bash
./bin/delsafec my_first_app.dels
```
The compiler parses the syntax, checks types and memory ownership, generates intermediate code organized in `generated/pascal/my_first_app.pas`, and invokes Free Pascal to build `bin/my_first_app.exe`.

To run it:
```bash
./bin/my_first_app.exe
```

To compile using the **C99 Backend** (via GCC):
```bash
./bin/delsafec my_first_app.dels --target=c
```

---

## 4. Creating and Managing a Full Project

For real-world projects with dependencies, tests, and multiple files, use the `new` command:

```bash
# 1. Create a new structured project
delsafec new my_project
cd my_project

# 2. Compile and run immediately
delsafec run

# 3. Run unit tests
delsafec test

# 4. Emit a Free Pascal unit for BlaiseVue integration
delsafec emit pascal src/main.dels --unit

# 5. Clean binaries and intermediate build files
delsafec clean
```

---

## 5. Next Steps
Now that you have the compiler running, check out:
- [Complete CLI Guide](CLI_GUIDE.md): All `delsafec` commands, subcommands, and flags.
- [BlaiseVue & Zephyr Integration](../technical/BLAISEVUE_AND_PASCAL_INTEGRATION.md): Using DelSafe in the BlaiseVue ecosystem with `--unit` and `--watch`.
- [Package Management](PACKAGE_MANAGEMENT.md): Managing Git and local dependencies and security audits with `delsafec pkg`.
- [Ownership & Borrowing Concepts](OWNERSHIP_AND_BORROWING.md): How DelSafe guarantees memory safety without a Garbage Collector.
- [Official Examples](../../examples/): Practical examples ready for study and testing.
