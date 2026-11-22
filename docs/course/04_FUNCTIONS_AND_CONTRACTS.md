# Chapter 04: Functions & Contracts

Functions in Aether are first-class constructs. Furthermore, Aether natively incorporates **Design by Contract (DbC)** — a formal software verification method pioneered by Bertrand Meyer — directly into function syntax.

---

## 1. Function Syntax

A function defines parameters with explicit types and a return type:

```aether
module functions_demo;

function AddNumbers(a: Int32, b: Int32): Int32
begin
    return a + b;
end;

function GreetUser(name: String): Void
begin
    PrintLn("Hello, " + name + "!");
end;
```

---

## 2. Design by Contract (DbC): `require` and `ensure`

Contracts turn documentation into executable specifications verified by the compiler:

- **`require` (Pre-condition):** What the caller **must guarantee** before invoking the function.
- **`ensure` (Post-condition):** What the function **guarantees** to deliver before returning.

```aether
module contracts_demo;

function Divide(numerator: Int32, denominator: Int32): Int32
contract
    require
        denominator <> 0;
begin
    return numerator / denominator;
end;

function CalculateSquareRoot(x: Float64): Float64
contract
    require
        x >= 0.0;
    ensure
        result >= 0.0;
begin
    return sqrt(x);
end;

program Main;
var
    ans: Int32;
    r: Float64;
begin
    ans := Divide(100, 5);
    PrintLn("Division result: " + IntToStr(ans));

    r := CalculateSquareRoot(64.0);
    PrintLn("Square root of 64.0: " + FloatToStr(r));

    // Calling with denominator 0 triggers an immediate contract violation assert:
    // Divide(10, 0); // Contract violation: Pre-condition failed!
end.
```

---

## 3. How Contracts Work in Compilation

1. **Development & Testing:** When compiled in debug mode (`aetherc app.aeth`), contract expressions are compiled into high-speed assertions that immediately detect logic errors at runtime.
2. **Release Mode (`--release`):** In production release builds, pre-conditions can be preserved or compiled into optimized checks, while dead-code elimination uses contract invariants for aggressive compiler optimizations.

---

## 4. Contracts on FFI and External Functions

Aether allows attaching contracts even to external C functions! For example:

```aether
extern c function sqrt(x: Float64): Float64
contract
    require
        x >= 0.0;
;
```

This ensures your Aether code protects against passing bad data to foreign C routines before the foreign call even occurs.

---

## 5. Summary
1. Functions use `function Name(params): ReturnType begin ... end;`.
2. Contracts use `contract require <expr>; ensure <expr>;`.
3. Pre-conditions defend your functions against invalid caller input at zero architectural cost.

➡️ **Next:** **[Chapter 05: The Borrow Checker (Memory Safety)](05_THE_BORROW_CHECKER.md)**
