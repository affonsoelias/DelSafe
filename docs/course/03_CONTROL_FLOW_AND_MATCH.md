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

## 2.1 Counting Loops: `for...to` and `for...downto`

For deterministic iteration across numeric ranges, Aether provides canonical `for` loops in the Pascal tradition:

- **Ascending (`to`):** `for i := start to end do ... end;`
- **Descending (`downto`):** `for i := start downto end do ... end;`

```aether
module for_demo;

program Main;
var
    i: Int32;
    k: Int32;
    sum: Int32;
begin
    sum := 0;

    // Ascending loop: 1 through 10
    for i := 1 to 10 do
        sum := sum + i;
    end;
    PrintLn("Ascending sum (1..10): " + IntToStr(sum)); // 55

    // Descending countdown loop: 5 down to 1
    PrintLn("Countdown:");
    for k := 5 downto 1 do
        PrintLn("  T-minus: " + IntToStr(k));
    end;
    PrintLn("Blast off!");
end.
```

---

## 2.2 Post-Test Loops: `repeat ... until <condition>;`

The `repeat ... until` construct guarantees that the loop body executes **at least once**. It continues iterating until the trailing boolean condition evaluates to `true`:

```aether
module repeat_demo;

program Main;
var
    attempts: Int32;
    success: Bool;
begin
    attempts := 0;
    success := false;

    repeat
        attempts := attempts + 1;
        PrintLn("Attempt #" + IntToStr(attempts));
        if attempts >= 3 then
            success := true;
        end;
    until success;

    PrintLn("Finished with " + IntToStr(attempts) + " attempts.");
end.
```

Notice:
- No `begin ... end` wrapper is needed around the body because `repeat` and `until` naturally delimit the block.
- Terminates when the condition evaluates to `true` (unlike C's `do...while` which continues while true).

---

## 2.3 Loop Flow Control: `break` and `continue`

Aether provides fine-grained loop control statements applicable across all loop types (`for`, `while`, and `repeat ... until`):

- **`break;`**: Exits the innermost loop immediately.
- **`continue;`**: Skips the remainder of the current iteration and advances to the next step.

```aether
module loop_control_demo;

program Main;
var
    i: Int32;
    sum: Int32;
begin
    // 1. Break: exit early when finding an element
    for i := 1 to 100 do
        if i = 5 then
            break; // Stop iterating immediately
        end;
    end;

    // 2. Continue: skip even numbers, summing only odd numbers (1..10)
    sum := 0;
    for i := 1 to 10 do
        if (i mod 2) = 0 then
            continue; // Skip even numbers
        end;
        sum := sum + i;
    end;

    PrintLn("Sum of odd numbers: " + IntToStr(sum)); // 25
end.
```

The compiler strictly verifies that `break` and `continue` only occur inside active loop bodies (rejecting top-level or standalone uses with error `E0310`).

---

## 2.4 Scoped Resource Cleanup (`defer`)

The `defer` statement schedules a statement to execute deterministically in **LIFO (Last-In, First-Out)** order whenever the enclosing block or function exits — including on early `return` paths:

```aether
module defer_demo;

function ProcessData(mut borrow log: array of Int32, exitEarly: Bool): Int32
begin
    defer log.Push(1); // Runs 2nd
    defer log.Push(2); // Runs 1st

    if exitEarly then
        return 0; // Automatically runs log.Push(2), then log.Push(1) before returning
    end;

    return 1;
end;
```

---

## 2.5 System Exception Handling (`try ... except` & `raise`)

While Aether uses `Result<T, E>` and `Option<T>` for expected domain errors, low-level runtime faults and unrecoverable panics can be raised with `raise` and caught cleanly with `try ... except ... end;`:

```aether
module exceptions_demo;

program Main;
var
    recovered: Bool;
begin
    recovered := false;
    try
        PrintLn("Executing guarded block...");
        raise "Simulated disk fault";
        PrintLn("This will not execute");
    except
        recovered := true;
        PrintLn("Fault safely intercepted!");
    end;
    assert(recovered = true);
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
2. Loops use `while <cond> do ... end;`, `for`, and `repeat ... until` with `break` and `continue`.
3. `defer` ensures deterministic LIFO cleanup, while `try ... except` and `raise` handle system faults.
4. Enums are algebraic types, and `match` enforces that every single possibility is handled at compile time.

➡️ **Next:** **[Chapter 04: Functions & Contracts](04_FUNCTIONS_AND_CONTRACTS.md)**
