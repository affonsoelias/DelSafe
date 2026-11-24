# Aether Examples

Curated examples and multi-file projects demonstrating the Aether programming language, organized by track.

## Directory Structure

### `basics/` — Core Language & Safety
| Example | Description | Run Command |
| :--- | :--- | :--- |
| `01_hello_world.aeth` | Minimal Aether program structure | `aetherc run examples/basics/01_hello_world.aeth` |
| `02_ownership_and_borrow.aeth` | Ownership transfer (`take`) and borrowing (`borrow` / `mut borrow`) | `aetherc run examples/basics/02_ownership_and_borrow.aeth` |
| `03_result_and_match.aeth` | `Result<T, E>` error handling and exhaustive `match` | `aetherc run examples/basics/03_result_and_match.aeth` |
| `04_method_syntax_ufcs.aeth` | Uniform Function Call Syntax (UFCS) method calls | `aetherc run examples/basics/04_method_syntax_ufcs.aeth` |
| `05_traits_and_polymorphism.aeth` | Traits and static polymorphism | `aetherc run examples/basics/05_traits_and_polymorphism.aeth` |
| `06_box_and_recursion.aeth` | Heap-allocated `Box<T>` and recursive structures | `aetherc run examples/basics/06_box_and_recursion.aeth` |
| `07_course_final_project.aeth` | End-of-course bank account manager capstone | `aetherc run examples/basics/07_course_final_project.aeth` |

### `stdlib_and_systems/` — Standard Library, Systems & Compiler Internals
| Example | Description |
| :--- | :--- |
| `standard_library_basics.aeth` | Core standard library modules (`std.math`, `std.strings`, `std.io`) |
| `io_and_collections.aeth` | File/console I/O, strings, and dynamic collections |
| `stdlib_expanded.aeth` | Expanded stdlib (`std.fs`, `std.env`, `std.json`, assertions) |
| `hierarchical_modules.aeth` | Dotted module imports (`Compiler.Aeth.Tokens`) |
| `concurrency_async.aeth` | Structured concurrency, JSON, sync, and network primitives |
| `http_server_sockets.aeth` | Native sockets and minimal HTTP server demo |
| `inline_assembly_intel.aeth` | Inline Intel-syntax `asm` blocks |
| `optimizer_and_release.aeth` | Constant folding, dead code elimination, and `--release` optimization |
| `self_hosted_compiler_demo.aeth` | Self-hosted compiler expressions demo |
| `self_hosted_functions_and_structs.aeth` | Self-hosted functions and `record` definitions demo |

### `interop/` — C & Free Pascal Interoperability
| Example | Description |
| :--- | :--- |
| `extern_c_basics.aeth` | Importing Pascal units and calling `extern c` functions |
| `pascal_and_c_interop.aeth` | Bidirectional C (`libc`/`headers`) and Object Pascal interoperability |

### `projects/` — Full Multi-File `aether.json` Projects
| Project | Description | Usage |
| :--- | :--- | :--- |
| `package_manager_demo/` | Multi-package project with local dependencies and unit tests | `cd examples/projects/package_manager_demo && aetherc test` |
| `multi_path_ffi/` | Custom `aether.json` paths (`c_sources`, `pascal_units`, `shared_libs`) | `cd examples/projects/multi_path_ffi && aetherc run` |
| `shared_cdylib_c_python/` | Compiling Aether to a shared library (`.dll`) consumed by C and Python | `cd examples/projects/shared_cdylib_c_python && aetherc build --emit-header` |
| `web_pas2js_wasm/` | Multi-target builds (`wasm` via Clang, `js` via Pas2JS, native C) | `cd examples/projects/web_pas2js_wasm && aetherc build` |
| `blaisevue_store/` | Transpiling Aether modules as Object Pascal units (`--unit`) for BlaiseVue | `cd examples/projects/blaisevue_store && aetherc build` |
| `async_runtime_demo/` | `async function`, `spawn`, and `await` runtime showcase | `aetherc run examples/projects/async_runtime_demo/async_demo.aeth` |
| `registry_demo/` | Local publisher (`my_module`) and consumer (`consumer`) package workflow | Inspect `consumer/` and `my_module/` |
| `profiler_demo/` | Target project for `aetherc profile` performance/memory auditing | `aetherc profile examples/projects/profiler_demo/app_profile.aeth` |
