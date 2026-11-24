# Memory Safety Analysis: Aether vs Rust

This document details the formal safety model and static guarantees that make **Aether as memory-safe as Rust** in compile-time memory management and concurrency.

---

## 1. Core Principle: Compile-Time Safety

Just like Rust, Aether follows the principle of **Zero-Cost Abstractions**:
- There is no Garbage Collector (*GC*).
- There are zero runtime GC pauses.
- All safety verification runs **100% at compile time** through the **Borrow Checker** and static type system.

---

## 2. Safety Guarantees Comparison

| Vulnerability Class | C / C++ | Traditional Object Pascal | Rust | AetherLang |
|:---|:---:|:---:|:---:|:---:|
| **Use-After-Free** | Critical risk | Possible | Prevented | **Prevented** (via `take`) |
| **Double-Free** | Critical risk | Possible | Prevented | **Prevented** (Single Owner) |
| **Null Pointer Dereference** | Critical risk | `Access Violation` | Prevented | **Prevented** (via `Option<T>`) |
| **Data Races** (Multithreaded) | Common | Common | Prevented | **Prevented** (Aliasing XOR Mutability) |
| **Buffer Overflow** | Critical risk | Depends on `-Cr` | Checked | **Guaranteed by Contracts / Bounds** |
| **Memory Leaks** | Frequent | Manual (`Free`) | Automatic RAII | **Automatic RAII (Drop on scope exit)** |

---

## 3. The 3 Pillars Making Aether as Safe as Rust

### Pillar 1: Single Ownership
Every allocated value or resource has **exactly one owning variable** at any given time.
- When a function takes `take x: MyStruct`, the caller's variable is invalidated after the call.
- Attempting to read or pass `x` again produces compile error `E0382: Use of moved value`.
- When the owner exits its scope (reaching `end`), any resource destructor (`impl Drop`) is invoked automatically. Zero memory leaks.

### Pillar 2: Aliasing XOR Mutability (Golden Rule of the Borrow Checker)
The Aether compiler strictly enforces:
$$\text{Simultaneous Borrows} = (\text{Multiple } \texttt{borrow}) \lor (\text{Exactly one } \texttt{mut borrow})$$

- While data is mutably borrowed (`mut borrow`), no other reference can read or mutate that data concurrently.
- This **mathematically eliminates data races** in concurrent programs.

### Pillar 3: Eliminating Null (The Billion-Dollar Mistake)
In Aether, **no regular variable can ever be null**.
- Whenever a value may be absent, the programmer explicitly uses the algebraic type `Option<T>`:
  ```pascal
  type
      Option<T> = enum
          Some(value: T),
          None
      end enum;
  ```
- The compiler enforces exhaustive destructuring via `match`, making it impossible to access an absent value unchecked.
