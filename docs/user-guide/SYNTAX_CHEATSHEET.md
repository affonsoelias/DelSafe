# DelSafe Syntax Cheatsheet (v0.5.3)

A concise, authoritative reference of DelSafe's modern syntax, mandatory typed closers, ownership rules, and low-level constructs.

---

## 1. File Kinds: Executable Program vs. Reusable Unit

Every `.dels` file begins with `module <Name>;`, where `<Name>` must match the filename (`E0005` on mismatch, ignoring leading digits/underscores and case).

### Executable Module (`program Main;`)
- Entry point **must** be named `program Main;` (`E0002` otherwise).
- Must close with `end <ModuleName>.` (matching the `module <Name>;` declaration).

```delsafe
module hello;

import Math;

program Main;
var
    x: Int32;
begin
    x := 42;
    PrintLn($"Answer: {x}");
end hello.
```

### Reusable Library Module (Unit: `interface` / `implementation`)
Any module **without** `program Main;` **must** use the Object Pascal Unit layout:

```delsafe
module math_utils;

interface

const
    SCALE = 2;

type
    Point = record
        x: Int32;
        y: Int32;
    end record;

function Add(a, b: Int32) return Int32
contract
    require
        a >= 0;
        b >= 0;
    ensure
        result >= a;

implementation

var
    PrivateCounter: Int32;

function Add(a, b: Int32) return Int32 is
begin
    return a + b;
end Add;

initialization
    PrivateCounter := 0;

finalization
    PrivateCounter := 0;

end math_utils.
```

> **Unit rules:**
> - Items in `interface` are public by default (`priv` is disallowed in `interface`).
> - Items in `implementation` are private by default (use `pub` if exporting).
> - Contracts on `interface` routines are written only in `interface` (not repeated in `implementation`).

---

## 2. Mandatory Typed Block & Declaration Closers

DelSafe rejects anonymous `end;` blocks (`E0001`). Every construct closes with its explicit keyword or name:

| Construct | Opening | Mandatory Closing |
| :--- | :--- | :--- |
| Module / Unit | `module Foo;` | `end Foo.` |
| Function / Procedure | `function F(...) return T is` / `procedure P is` | `end F;` / `end P;` |
| Conditional | `if <cond> then ... [else if ... then] [else ...]` | `end if;` |
| While Loop | `while <cond> do` | `end while;` |
| For Loop | `for i := a to\|downto b do` / `for x in xs do` | `end for;` |
| Post-test Loop | `repeat` | `until <cond>;` |
| Pattern Match | `match <expr> do\|with` | `end match;` / `end match` (expr) |
| Record | `Name = record` | `end record;` |
| Enum / ADT | `Name = enum` | `end enum;` |
| Trait | `Name = trait` (or `trait Name`) | `end trait;` |
| Impl Block | `impl Type` / `impl Trait for Type` | `end impl;` |
| Exception Guard | `try ... except ...` | `end try;` |
| Unsafe Block | `unsafe` | `end unsafe;` |
| Inline Assembly | `asm` | `end asm;` |
| Multi-line Lambda | `fn(...) [return T] begin` | `end fn` |

---

## 3. Routines, Parameters, Ownership & Contracts

```delsafe
// Procedure (no return type; parentheses optional when parameterless)
procedure Reset is
begin
    PrintLn("Reset");
end Reset;

// Function (must specify `return <Type>`)
function SumPoints(borrow a, b: Point) return Int32 is
begin
    return a.x + a.y + b.x + b.y;
end SumPoints;

// Ownership parameter modes:
//   borrow x: T     -> immutable borrow (shared read)
//   mut borrow x: T -> exclusive mutable borrow
//   take x: T       -> move ownership (use after move => E0382)
```

---

## 4. Types, Literals & Collections

- **Integers:** `Int8`, `Int16`, `Int32`, `Int64`, `UInt8` (`Byte`), `UInt16` (`Word`), `UInt32`, `UInt64`
- **Floats / Bool / Text:** `Float32`, `Float64`, `Bool`, `Char`, `String` (`s[i]` is 0-based `Char`)
- **Numeric Literals:** `42`, `100_000`, `$FF` / `0xFF`, `%1010` / `0b1010`, `3.14`
- **Arrays & Slices:** `array[5] of Int32`, `array[3, 3] of Float64`, `array of T`, `[10, 20, 30]`
- **Maps:** `map[String]Int32`, `["alice": 100, "bob": 85]`, empty `[:]`
- **Sets & Subranges:** `set of Digit`, `1..31`, `[Read, Write]`, `x in mySet`
- **Tuples & Destructuring:** `(Int32, String)`, `pair.0`, `let (id, name) := pair;`
- **Monads & Error Propagation:** `Option<T>` (`Some(v)` / `None`), `Result<T, E>` (`Ok(v)` / `Err(e)`), `expr?`, `try expr`
- **Heap & Pointers:** `Box<T>` (`Box(v)`), `^T`, `@var`, `nil` (dereference `ptr^` requires `unsafe ... end unsafe;`)
- **Inline `if` Expression:** `let tag := if x > 0 then "pos" else "neg";`
- **Operators:** `div`, `mod`, `shl`, `shr`, `and`, `or`, `xor`, `not`, `implies`, `in`, `+=`, `-=`, `*=`, `/=`, `mod=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=`, `Inc(x)`, `Dec(x)`

---

## 5. Lambdas, Concurrency & Low-Level Assembly

```delsafe
// 1. Lambdas & closures
let addOne := fn(x: Int32) return Int32 => x + 1;
let blockFn := fn(x: Int32) return Int32
begin
    return x * 2;
end fn;

// 2. OS-thread Concurrency
async function Work(n: Int32) return Int32 is
begin
    yield;
    return n * n;
end Work;
// var t: Task<Int32> := spawn Work(6);
// var res: Int32 := await t;

// 3. Intel-Syntax Inline Assembly (identical on FPC & GCC/Clang)
asm
    nop
    rdtsc
    mov eax, 42
    add eax, 8
end asm;
```
