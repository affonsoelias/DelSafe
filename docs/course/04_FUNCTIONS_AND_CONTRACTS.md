# Chapter 04: Functions & Contracts

Functions in Aether are first-class constructs. Furthermore, Aether natively incorporates **Design by Contract (DbC)** — a formal software verification method pioneered by Bertrand Meyer — directly into function syntax.

---

## 1. Routine Syntax (`procedure` and `function`)

Aether distinguishes between routines that do not return a value (**`procedure`**) and routines that return a value (**`function ... return <Type>`**), with Ada-style `is` headers and explicit named `end <Name>;` closings:

```aether
module functions_demo;

function AddNumbers(a, b: Int32) return Int32 is
begin
    return a + b;
end AddNumbers;

procedure GreetUser(name: String) is
begin
    PrintLn("Hello, " + name + "!");
end GreetUser;
```

---

## 2. Design by Contract (DbC): `require` and `ensure`

Contracts turn documentation into executable specifications verified by the compiler:

- **`require` (Pre-condition):** What the caller **must guarantee** before invoking the routine.
- **`ensure` (Post-condition):** What the routine **guarantees** to deliver before returning. Within `ensure` clauses on functions, Aether automatically provides the special read-only identifier `result` bound to the function's return value (in both the Free Pascal and GCC C99 backends). Post-conditions are verified automatically at **every** `return` statement—including early returns—as well as at the end of `procedure` routines. Contracts declared on generic functions (such as `function IdentityPositive<T>(val: T) return T is`) are also preserved across monomorphization.

```aether
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

Aether allows attaching contracts even to external C functions! For example:

```aether
extern c function sqrt(x: Float64) return Float64
contract
    require
        x >= 0.0;
```

This ensures your Aether code protects against passing bad data to foreign C routines before the foreign call even occurs.

---

## 5. Summary
1. Procedures use `procedure Name[(params)] is ... begin ... end Name;`, and functions use `function Name[(params)] return Type is ... begin ... end Name;`.
2. Contracts use `contract require <expr>; ensure <expr>;` placed after `is` (or on `interface` / `extern` signatures).
3. Pre-conditions defend your routines against invalid caller input at zero architectural cost.

➡️ **Next:** **[Chapter 05: The Borrow Checker (Memory Safety)](05_THE_BORROW_CHECKER.md)**
