# Chapter 04: Functions & Contracts

Functions in DelSafe are first-class constructs. Furthermore, DelSafe natively incorporates **Design by Contract (DbC)** — a formal software verification method pioneered by Bertrand Meyer — directly into function syntax.

---

## 1. Routine Syntax (`procedure` and `function`)

DelSafe distinguishes between routines that do not return a value (**`procedure`**) and routines that return a value (**`function ... return <Type>`**), with Ada-style `is` headers and explicit named `end <Name>;` closings. Parentheses `()` are optional on parameterless procedures:

```delsafe
module functions_demo;

interface

function AddNumbers(a, b: Int32) return Int32;
procedure GreetUser(name: String);
procedure PrintBanner;

implementation

function AddNumbers(a, b: Int32) return Int32 is
begin
    return a + b;
end AddNumbers;

procedure GreetUser(name: String) is
begin
    PrintLn("Hello, " + name + "!");
end GreetUser;

procedure PrintBanner is
begin
    PrintLn("=== DelSafe ===");
end PrintBanner;

end functions_demo.
```

> **Unit Contract Rule:** When a routine is declared inside a Unit's `interface` section, any `contract require` / `ensure` clause belongs on the `interface` signature (without repeating it in `implementation`).

---

## 2. Design by Contract (DbC): `require` and `ensure`

Contracts turn documentation into executable specifications verified by the compiler:

- **`require` (Pre-condition):** What the caller **must guarantee** before invoking the routine.
- **`ensure` (Post-condition):** What the routine **guarantees** to deliver before returning. Within `ensure` clauses on functions, DelSafe automatically provides the special read-only identifier `result` bound to the function's return value (in both the Free Pascal and GCC C99 backends). Post-conditions are verified automatically at **every** `return` statement—including early returns—as well as at the end of `procedure` routines. Contracts declared on generic functions (such as `function IdentityPositive<T>(val: T) return T is`) are also preserved across monomorphization.

```delsafe
module contracts_demo;

function Divide(numerator, denominator: Int32) return Int32 is
contract
    require
        denominator <> 0;
begin
    return numerator / denominator;
end Divide;

function SafeStep(x: Int32) return Int32 is
contract
    require
        x >= -100;
    ensure
        result >= 0;
begin
    if x < 0 then
        return 0; // `ensure` still checks `result >= 0` before returning
    end if;
    return x;
end SafeStep;

function IdentityPositive<T>(val: T) return T is
contract
    require
        val > 0;
    ensure
        result > 0;
begin
    return val;
end IdentityPositive;

function CalculateSquareRoot(x: Float64) return Float64 is
contract
    require
        x >= 0.0;
    ensure
        result >= 0.0;
begin
    return sqrt(x);
end CalculateSquareRoot;

program Main;
var
    ans: Int32;
    step: Int32;
    r: Float64;
begin
    ans := Divide(100, 5);
    PrintLn("Division result: " + IntToStr(ans));

    step := SafeStep(-5);
    PrintLn("Safe step: " + IntToStr(step));

    r := CalculateSquareRoot(64.0);
    PrintLn("Square root of 64.0: " + FloatToStr(r));

    // Calling with denominator 0 triggers an immediate contract violation assert:
    // Divide(10, 0); // Contract violation: Pre-condition failed!
end contracts_demo.
```

---

## 3. How Contracts Work in Compilation

1. **Development & Testing:** Both `require` pre-conditions (at function entry) and `ensure` post-conditions (captured before every `return` using the `result` binding or at function exit) are compiled into native runtime assertions (`Assert(...)` in Free Pascal, `assert(...)` in GCC C99) that immediately pinpoint logic or invariant bugs.
2. **Release Mode (`--release`):** Pre- and post-conditions establish formal invariants around function boundaries and work uniformly across non-generic and monomorphized generic functions.

---

## 4. Contracts on FFI and External Functions

DelSafe allows attaching contracts even to external C functions! For example:

```delsafe
extern c function sqrt(x: Float64) return Float64
contract
    require
        x >= 0.0;
```

This ensures your DelSafe code protects against passing bad data to foreign C routines before the foreign call even occurs.

---

## 5. Function Types, Lambdas & Closures (`fn`)

Routines are first-class values in DelSafe. You can declare named function/procedure callback types, pass named routines, or write inline **expression lambdas** (`fn(...) => expr`) and **block lambdas** (`fn(...) begin ... end fn`) that capture outer variables:

```delsafe
type
    IntTransform = function(Int32) return Int32;
    IntSink = procedure(Int32);

function ApplyTransform(x: Int32; op: IntTransform) return Int32 is
begin
    return op(x);
end ApplyTransform;

function MakeAdder(base: Int32) return IntTransform is
begin
    // Closure capturing `base`
    return fn(delta: Int32) return Int32 => base + delta;
end MakeAdder;
```

At call sites, parameter and return types can also be inferred (`ApplyTransform(5, fn(x) => x + 7)`), and multi-statement lambdas use `begin ... end fn`.

---

## 6. Summary
1. Procedures use `procedure Name[(params)] is ... begin ... end Name;`, and functions use `function Name[(params)] return Type is ... begin ... end Name;`.
2. Contracts use `contract require <expr>; ensure <expr>;` placed after `is` (or on `interface` / `extern` signatures, without repeating them in `implementation`).
3. Function types and `fn(...)` lambdas/closures support callbacks, type inference, and outer-scope captures across both backends.
4. Pre-conditions defend your routines against invalid caller input at zero architectural cost.

➡️ **Next:** **[Chapter 05: The Borrow Checker (Memory Safety)](05_THE_BORROW_CHECKER.md)**
