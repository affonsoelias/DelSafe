# Chapter 03: Control Flow & Pattern Matching

Control flow in Aether is designed to eliminate the classic "dangling else" ambiguity of C-family languages and avoid verbose `begin...end` boilerplate inside conditional blocks.

---

## 1. Clean Conditionals: `if...then...else...end;`

In Aether, an `if` statement opens with `if <condition> then`, contains statements directly, and closes with `end;`:

```aether
module conditionals_demo;

program Main;
var
    score: Int32;
    grade: String;
begin
    score := 85;

    if score >= 90 then
        grade := "A";
    else if score >= 80 then
        grade := "B";
    else if score >= 70 then
        grade := "C";
    else
        grade := "F";
    end;

    PrintLn("Final grade: " + grade);
end.
```

Notice:
- No parentheses `(...)` required around conditions.
- No `begin` keyword required after `then`.
- Clean closing `end;`.

---

## 2. Iteration: `while` Loops

The `while` loop evaluates a condition before each iteration and executes until false:

```aether
module loop_demo;

program Main;
var
    i: Int32;
    total: Int32;
begin
    i := 1;
    total := 0;

    while i <= 10 do
        total := total + i;
        i := i + 1;
    end;

    PrintLn("Sum of 1 to 10 is: " + IntToStr(total));
end.
```

---

## 3. Algebraic Enums

Enums in Aether are not just lists of numbers; they are **Algebraic Data Types (ADTs)** that can carry payload data with variants:

```aether
module enums_demo;

type
    Status = enum
        Idle,
        Pending,
        Success,
        Failed
    end;

    WebEvent = enum
        Click,
        KeyPress,
        Submit
    end;
```

---

## 4. Exhaustive Pattern Matching (`match`)

Unlike traditional switch statements that fall through or allow unhandled cases, Aether's `match` statement enforces **exhaustiveness checking at compile time**:

```aether
module match_demo;

type
    OrderStatus = enum
        Draft,
        Paid,
        Shipped,
        Delivered,
        Cancelled
    end;

function GetStatusDescription(st: OrderStatus): String
begin
    match st with
        OrderStatus.Draft =>
            return "Order is being edited.";
        OrderStatus.Paid =>
            return "Payment confirmed, ready to pack.";
        OrderStatus.Shipped =>
            return "In transit to customer.";
        OrderStatus.Delivered =>
            return "Package received by customer.";
        OrderStatus.Cancelled =>
            return "Order was cancelled.";
    end;
end;

program Main;
var
    status: OrderStatus;
begin
    status := OrderStatus.Shipped;
    PrintLn("Order state: " + GetStatusDescription(status));
end.
```

If you omit any variant (e.g., forget `Cancelled`), the Aether compiler will refuse to compile with an exhaustive-check error:

```text
Error: Non-exhaustive match pattern! Missing variant: OrderStatus.Cancelled
```

---

## 5. Summary
1. `if...then...else...end;` provides unambiguous nesting without `begin`.
2. Loops use `while <cond> do ... end;`.
3. Enums are algebraic types, and `match` enforces that every single possibility is handled at compile time.

➡️ **Next:** **[Chapter 04: Functions & Contracts](04_FUNCTIONS_AND_CONTRACTS.md)**
