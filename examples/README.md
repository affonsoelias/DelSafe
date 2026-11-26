# DelSafe Examples

Curated examples and multi-file projects demonstrating the DelSafe programming language, organized by track.

## Directory Structure

### `basics/` — Core Language & Safety
| Example | Description | Run Command |
| :--- | :--- | :--- |
| `01_hello_world.dels` | Minimal DelSafe program structure | `delsafec run examples/basics/01_hello_world.dels` |
| `02_ownership_and_borrow.dels` | Ownership transfer (`take`) and borrowing (`borrow` / `mut borrow`) | `delsafec run examples/basics/02_ownership_and_borrow.dels` |
| `03_result_and_match.dels` | `Result<T, E>` error handling and exhaustive `match` | `delsafec run examples/basics/03_result_and_match.dels` |
| `04_method_syntax_ufcs.dels` | Uniform Function Call Syntax (UFCS) method calls | `delsafec run examples/basics/04_method_syntax_ufcs.dels` |
| `05_traits_and_polymorphism.dels` | Traits and static polymorphism | `delsafec run examples/basics/05_traits_and_polymorphism.dels` |
| `06_box_and_recursion.dels` | Heap-allocated `Box<T>` and recursive structures | `delsafec run examples/basics/06_box_and_recursion.dels` |
| `07_course_final_project.dels` | End-of-course bank account manager capstone | `delsafec run examples/basics/07_course_final_project.dels` |

### `stdlib_and_systems/` — Standard Library, Systems & Compiler Internals
| Example | Description |
| :--- | :--- |
| `standard_library_basics.dels` | Core standard library modules (`std.math`, `std.strings`, `std.io`) |
| `io_and_collections.dels` | File/console I/O, strings, and dynamic collections |
| `stdlib_expanded.dels` | Expanded stdlib (`std.fs`, `std.env`, `std.json`, assertions) |
| `hierarchical_modules.dels` | Dotted module imports (`Compiler.Dels.Tokens`) |
| `concurrency_async.dels` | Structured concurrency, JSON, sync, and network primitives |
| `http_server_sockets.dels` | Native sockets and minimal HTTP server demo |
| `inline_assembly_intel.dels` | Inline Intel-syntax `asm` blocks |
| `optimizer_and_release.dels` | Constant folding, dead code elimination, and `--release` optimization |
| `self_hosted_compiler_demo.dels` | Self-hosted compiler expressions demo |
| `self_hosted_functions_and_structs.dels` | Self-hosted functions and `record` definitions demo |

### `interop/` — C & Free Pascal Interoperability
| Example | Description |
| :--- | :--- |
| `extern_c_basics.dels` | Importing Pascal units and calling `extern c` functions |
| `pascal_and_c_interop.dels` | Bidirectional C (`libc`/`headers`) and Object Pascal interoperability |

### `projects/` — Full Multi-File `delsafe.json` Projects
| Project | Description | Usage |
| :--- | :--- | :--- |
| `package_manager_demo/` | Multi-package project with local dependencies and unit tests | `cd examples/projects/package_manager_demo && delsafec test` |
| `multi_path_ffi/` | Custom `delsafe.json` paths (`c_sources`, `pascal_units`, `shared_libs`) | `cd examples/projects/multi_path_ffi && delsafec run` |
| `shared_cdylib_c_python/` | Compiling DelSafe to a shared library (`.dll`) consumed by C and Python | `cd examples/projects/shared_cdylib_c_python && delsafec build --emit-header` |
| `web_pas2js_wasm/` | Multi-target builds (`wasm` via Clang, `js` via Pas2JS, native C) | `cd examples/projects/web_pas2js_wasm && delsafec build` |
| `blaisevue_store/` | Transpiling DelSafe modules as Object Pascal units (`--unit`) for BlaiseVue | `cd examples/projects/blaisevue_store && delsafec build` |
| `async_runtime_demo/` | `async function`, `spawn`, and `await` runtime showcase | `delsafec run examples/projects/async_runtime_demo/async_demo.dels` |
| `registry_demo/` | Local publisher (`my_module`) and consumer (`consumer`) package workflow | Inspect `consumer/` and `my_module/` |
| `profiler_demo/` | Target project for `delsafec profile` performance/memory auditing | `delsafec profile examples/projects/profiler_demo/app_profile.dels` |
