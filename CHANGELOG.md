# Changelog

All notable changes to the **DelSafe Programming Language** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Added a smart GitHub Actions `check` gate to skip scheduled `nightly` builds when `main` has no new commits since the last nightly build.

## [0.5.3] - 2026-11-27

### Added
- Persistent `delsafec channel` command (`stable` | `nightly`) for managing release channels.
- Multiplatform CI workflow (`ci.yml`) covering Windows, Linux, and macOS builds and tests.

### Changed
- Aligned the Masterclass course, user guides, and technical specifications with `v0.5.3`.

### Fixed
- Handled missing external executables cleanly in `RunCommandCapture`.
- Installed MSYS2 `sqlite3` on Windows CI runners, fixed Linux/macOS CI dependencies, and reset `LASTEXITCODE` after expected-fail channel checks on Windows.

## [0.5.2] - 2026-11-26

### Fixed
- Switched `RunCommandCapture` to `TProcess.Parameters` on Linux and synchronized libc `getenv`.

## [0.5.1] - 2026-11-26

### Changed
- Completed the rebrand from Aether to **DelSafe** (`delsafec` CLI and `.dels` source files).

## [0.5.0] - 2026-11-25

### Added
- Native MSYS2, `pkg-config`, and `fppkg` toolchain discovery alongside self-upgrade (`delsafec upgrade`) and GitHub Actions binary release packaging.
- Binary-safe `SocketSendFile` and complete send-all loops for C99 and Pascal targets (`std/net`).
- Real OS thread primitives (`spawn`/`await`/`yield`), atomic/mutex support in `std/sync`, and generic `Channel<T>`.
- Tagged ADTs with payloads, generics, value monads, tuples, closures, and structured Ada + Object Pascal syntax.

[Unreleased]: https://github.com/affonsoelias/delsafe/compare/v0.5.3...HEAD
[0.5.3]: https://github.com/affonsoelias/delsafe/compare/v0.5.2...v0.5.3
[0.5.2]: https://github.com/affonsoelias/delsafe/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/affonsoelias/delsafe/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/affonsoelias/delsafe/releases/tag/v0.5.0
