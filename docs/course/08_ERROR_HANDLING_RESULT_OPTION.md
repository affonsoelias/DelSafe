# Chapter 08: Safe Error Handling with Result & Option

Tony Hoare, the inventor of the null pointer reference in 1965, famously referred to it as his *"billion-dollar mistake"*.

In safe DelSafe code, **regular variables and records cannot be null** (raw pointers `^T` and `nil` are strictly isolated inside `unsafe ... end unsafe;` blocks). Instead, optional values and recoverable errors are modeled explicitly using **`Option<T>`** and **`Result<T, E>`**.

---

## 1. Optional Values: `Option<T>`

An `Option` represents a value that may or may not be present:

```delsafe
module option_demo;

type
    IntOption = enum
        None,
        Some(Int32)
    end enum;

function FindUserIndex(name: String) return IntOption is
begin
    if name = "Alice" then
        return IntOption.Some(0);
    else if name = "Bob" then
        return IntOption.Some(1);
    else
        return IntOption.None;
    end if;
end FindUserIndex;

program Main;
var
    search: IntOption;
begin
    search := FindUserIndex("Charlie");

    match search with
        IntOption.Some(idx) =>
            PrintLn("User found at index: " + IntToStr(idx));
        IntOption.None =>
            PrintLn("User does not exist in registry.");
    end match;
end option_demo.
```

Because `Option` must be unpacked with `match`, it is **impossible** to forget to check for absence and crash at runtime.

---

## 2. Recoverable Errors: `Result<T, E>`

When an operation can fail with an error cause, use `Result`:

- **`Ok(value)`:** Success with the returned computation.
- **`Err(error_code)`:** Failure with an error message or error type.

```delsafe
module result_demo;

type
    MathResult = enum
        Ok(Int32),
        Err(String)
    end enum;

function SafeDivide(a, b: Int32) return MathResult is
begin
    if b = 0 then
        return MathResult.Err("Division by zero error!");
    end if;
    return MathResult.Ok(a / b);
end SafeDivide;

program Main;
var
    res: MathResult;
begin
    res := SafeDivide(100, 4);
    match res with
        MathResult.Ok(val) =>
            PrintLn("Division succeeded: " + IntToStr(val));
        MathResult.Err(msg) =>
            PrintLn("Operation failed: " + msg);
    end match;

    res := SafeDivide(100, 0);
    match res with
        MathResult.Ok(val) =>
            PrintLn("Division succeeded: " + IntToStr(val));
        MathResult.Err(msg) =>
            PrintLn("Handled gracefully: " + msg);
    end match;
end result_demo.
```

---

## 3. Built-In Generic `Option<T>`, `Result<T, E>`, and Error Propagation (`?` / `try`)

In addition to custom payload enums, DelSafe includes built-in generic `Option<T>` and `Result<T, E>` types with `Some(v)` / `None`, `Ok(v)` / `Err(e)`, field accessors (`.is_some`, `.is_none`, `.is_ok`, `.is_err`, `.value`, `.error`), and `?` / `try <expr>` early-return propagation:

```delsafe
function ParsePositive(x: Int32) return Result<Int32, String> is
begin
    if x <= 0 then
        return Err("value must be positive");
    end if;
    return Ok(x);
end ParsePositive;

function SumPositives(a, b: Int32) return Result<Int32, String> is
begin
    let va := ParsePositive(a)?;
    let vb := try ParsePositive(b);
    return Ok(va + vb);
end SumPositives;
```

You can inspect `Option<T>` and `Result<T, E>` either via exhaustive `match` (`case Some(let v):`, `case Ok(let v):`, `case Err(let msg):`) or via `.is_some` / `.is_ok` checks.

---

## 4. Advantages Over Traditional Exceptions

1. **Zero Hidden Control Flow:** Functions declare their failure possibilities in their return type signatures. Callers can never be surprised by uncaught exceptions crashing the process.
2. **Deterministic RAII Cleanup:** Stack frames unwind safely through regular return values; destructors (`Drop` and `defer`) run deterministically without exception table lookups.
3. **Compiler Verification:** The exhaustive `match` ensures that every error path is accounted for.

---

## 5. Summary
1. `Option<T>` eliminates null-pointer crashes in safe code.
2. `Result<T, E>` makes error states an explicit, verifiable part of function signatures, and `?` / `try` propagate failures ergonomically.
3. Combine both with `match` for rock-solid fault tolerance.

➡️ **Next:** **[Chapter 09: Async/Await & Concurrency](09_ASYNC_AWAIT_AND_CONCURRENCY.md)**
