# Chapter 03: Control Flow & Pattern Matching

Control flow in DelSafe is designed to eliminate the classic "dangling else" ambiguity of C-family languages and avoid verbose `begin...end` boilerplate inside conditional blocks.

---

## 1. Clean Conditionals: `if...then...else...end if;`

In DelSafe, an `if` statement opens with `if <condition> then`, contains statements directly (with optional flat `else if <condition> then` chains), and closes with a single `end if;`:

```delsafe
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
    end if;

    PrintLn("Final grade: " + grade);
end conditionals_demo.
```

Notice:
- No parentheses `(...)` required around conditions.
- No `begin` keyword required after `then`.
- Clean closing `end if;` (closing the entire `if / else if / else` chain).

### 1.1 Inline Conditional Expressions (`if ... then ... else ...`)

DelSafe also supports single-expression `if <cond> then <exprA> else <exprB>` directly inside assignments, initializers, arithmetic, and function calls (without `end if;`), requiring compatible types on both branches:

```delsafe
let limit := if score >= 90 then 100 else 50;
let badge := if limit = 100 then "GOLD" else "STANDARD";
let adjusted := (if score > 0 then score else 0) + 10;
```

---

## 2. Iteration: `while` Loops

The `while` loop evaluates a condition before each iteration and executes until false:

```delsafe
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
    end while;

    PrintLn("Sum of 1 to 10 is: " + IntToStr(total));
end loop_demo.
```

---

## 2.1 Counting Loops: `for...to` and `for...downto`

For deterministic iteration across numeric ranges, DelSafe provides canonical `for` loops in the Pascal tradition:

- **Ascending (`to`):** `for i := start to end do ... end for;`
- **Descending (`downto`):** `for i := start downto end do ... end for;`

```delsafe
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
    end for;
    PrintLn("Ascending sum (1..10): " + IntToStr(sum)); // 55

    // Descending countdown loop: 5 down to 1
    PrintLn("Countdown:");
    for k := 5 downto 1 do
        PrintLn("  T-minus: " + IntToStr(k));
    end for;
    PrintLn("Blast off!");
end for_demo.
```

You can also iterate directly over fixed arrays, dynamic arrays (`array of T`), and `String` values (`Char` elements) using `for item in collection do ... end for;`:

```delsafe
for n in numbers do
    total := total + n;
end for;

for ch in "DelSafe" do
    if ch = 'D' then
        PrintLn("Found D!");
    end if;
end for;

// Iterating keys or key-value pairs in associative maps
for keyOnly in scores do
    PrintLn(keyOnly);
end for;

for key, val in scores do
    total += val;
end for;
```

You can also update numeric targets using `div` (integer division) and compound assignment operators (`+=`, `-=`, `*=`, `/=`, `mod=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=`) or `Inc(x)` / `Dec(x)` on variables, record fields, array elements, and maps. You can also declare local `var` / `let` variables inline anywhere inside `begin...end`, `if`, `while`, or `for` blocks, and initialize associative maps with literals such as `var scores := ["alice": 100, "bob": 85];` or empty `[:]` alongside escaped `Char`/`String` literals (`'\n'`, `'\t'`, `'\0'`, `'\r'`, `'\\'`, `'\"'`, `'\''`).

---

## 2.2 Post-Test Loops: `repeat ... until <condition>;`

The `repeat ... until` construct guarantees that the loop body executes **at least once**. It continues iterating until the trailing boolean condition evaluates to `true`:

```delsafe
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
        end if;
    until success;

    PrintLn("Finished with " + IntToStr(attempts) + " attempts.");
end repeat_demo.
```

Notice:
- No `begin ... end` wrapper is needed around the body because `repeat` and `until` naturally delimit the block.
- Terminates when the condition evaluates to `true` (unlike C's `do...while` which continues while true).

---

## 2.3 Loop Flow Control: `break` and `continue`

DelSafe provides fine-grained loop control statements applicable across all loop types (`for`, `while`, and `repeat ... until`):

- **`break;`**: Exits the innermost loop immediately.
- **`continue;`**: Skips the remainder of the current iteration and advances to the next step.

```delsafe
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
        end if;
    end for;

    // 2. Continue: skip even numbers, summing only odd numbers (1..10)
    sum := 0;
    for i := 1 to 10 do
        if (i mod 2) = 0 then
            continue; // Skip even numbers
        end if;
        sum := sum + i;
    end for;

    PrintLn("Sum of odd numbers: " + IntToStr(sum)); // 25
end loop_control_demo.
```

The compiler strictly verifies that `break` and `continue` only occur inside active loop bodies (rejecting top-level or standalone uses with error `E0310`).

---

## 2.4 Scoped Resource Cleanup (`defer`)

The `defer` statement schedules a statement to execute deterministically in **LIFO (Last-In, First-Out)** order whenever the enclosing block or function exits — including on early `return` paths:

```delsafe
module defer_demo;

interface

function ProcessData(mut borrow log: array of Int32; exitEarly: Bool) return Int32;

implementation

function ProcessData(mut borrow log: array of Int32; exitEarly: Bool) return Int32 is
begin
    defer log.Push(1); // Runs 2nd
    defer log.Push(2); // Runs 1st

    if exitEarly then
        return 0; // Automatically runs log.Push(2), then log.Push(1) before returning
    end if;

    return 1;
end ProcessData;

end defer_demo.
```

---

## 2.5 System Exception Handling (`try ... except` & `raise`)

While DelSafe uses `Result<T, E>` and `Option<T>` for expected domain errors, low-level runtime faults and unrecoverable panics can be raised with `raise` and caught cleanly with `try ... except ... end try;`:

```delsafe
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
    end try;
    assert(recovered = true);
end exceptions_demo.
```

---

## 2.6 Fast Error Propagation (`?` and `try expr`)

When writing functions returning `Result<T, E>` or `Option<T>`, you can unwrap the inner value or propagate an early error/empty return cleanly with either the postfix `?` operator or prefix `try <expr>`:

```delsafe
function SumPositivesWithTry(a, b: Int32) return Result<Int32, String> is
begin
    let va := ParsePositive(a)?;
    let vb := try ParsePositive(b);
    return Ok(va + vb);
end SumPositivesWithTry;
```

If `ParsePositive(b)` returns `Err("non-positive")`, `SumPositivesWithTry` immediately executes any active `defer` statements and returns `Err("non-positive")` without extra boilerplate.

---

## 3. Algebraic Enums

Enums in DelSafe are not just lists of numbers; they are **Algebraic Data Types (ADTs)** that can carry payload data with variants:

```delsafe
module enums_demo;

interface

type
    Status = enum
        Idle,
        Pending,
        Success,
        Failed
    end enum;

    WebEvent = enum
        Click,
        KeyPress,
        Submit
    end enum;

implementation

end enums_demo.
```

---

## 4. Exhaustive Pattern Matching (`match`)

Unlike traditional switch statements that fall through or allow unhandled cases, DelSafe's `match` statement enforces **exhaustiveness checking at compile time**:

```delsafe
module match_demo;

type
    OrderStatus = enum
        Draft,
        Paid,
        Shipped,
        Delivered,
        Cancelled
    end enum;

function GetStatusDescription(st: OrderStatus) return String is
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
    end match;
end GetStatusDescription;

program Main;
var
    status: OrderStatus;
begin
    status := OrderStatus.Shipped;
    PrintLn("Order state: " + GetStatusDescription(status));
end match_demo.
```

If you omit any variant (e.g., forget `Cancelled`), the DelSafe compiler will refuse to compile with an exhaustive-check error:

```text
Error: Non-exhaustive match pattern! Missing variant: OrderStatus.Cancelled
```

### 4.1 Matching Primitives, `Result`, `Option`, and Wildcards (`_`)

In addition to `Enum` variants with `with` or `do`, `match` supports integers (including negative values), strings, characters, booleans, `Option<T>` (`Some`/`None`), `Result<T, E>` (`Ok`/`Err`), optional `case` labels, `:` or `=>` arm separators, and `_` catch-all arms across both Free Pascal and GCC C99 backends:

```delsafe
match statusCode do
    200 =>
        PrintLn("OK");
    -1 =>
        PrintLn("Error");
    _ =>
        PrintLn("Other");
end match;

match command with
    "start":
        BeginWork();
    "stop":
        HaltWork();
    _:
        PrintLn("Unknown command");
end match;

match optVal with
    case Some(let v):
        total += v;
    case None:
        total += 0;
end match;
```

### 4.2 Multi-Value & Inclusive Range Patterns (`a, b, c` and `low..high`)

`match` arms also accept comma-separated pattern lists (including `Enum` variants, which participate in exhaustiveness checking) as well as inclusive `low..high` ranges for integers and characters:

```delsafe
match httpCode do
    1, 3, 5 =>
        category := "odd-small";
    200..299 =>
        category := "success";
    -10..-1, 0 =>
        category := "non-positive";
    _ =>
        category := "other";
end match;

match ch do
    'a'..'z' =>
        kind := "lowercase";
    'A'..'Z' =>
        kind := "uppercase";
    '0', '1', '2' =>
        kind := "small-digit";
    _ =>
        kind := "symbol";
end match;

match st with
    case OrderStatus.Draft, OrderStatus.Paid:
        group := 1;
    case OrderStatus.Shipped, OrderStatus.Delivered, OrderStatus.Cancelled:
        group := 2;
end match;
```

### 4.3 `match` Expressions & Conditional Pattern Guards (`if` / `when`)

`match` can also be used directly as an expression returning a unified value type, and individual arms can bind variables and attach conditional guards using `if` or `when`:

```delsafe
let statusLabel := match code do
    case 200, 201 => "OK";
    case let c if c >= 500 => "SERVER_ERR";
    case let c when c >= 400 => "CLIENT_ERR";
    case _ => "OTHER";
end match;

function ScoreResultExpr(res: Result<Int32, String>) return Int32 is
begin
    return match res do
        case Ok(let v) if v > 50 => v * 2;
        case Ok(let v) => v + 1;
        case Err(let _msg) => -1;
    end match;
end ScoreResultExpr;
```

Guarded patterns do not act as unconditional wildcards during exhaustiveness checking, preserving full compile-time safety.

---

## 5. Summary
1. `if...then...else...end if;` provides unambiguous nesting without `begin` (including flat `else if` chains), and inline `if <cond> then <exprA> else <exprB>` evaluates conditional expressions cleanly inside initializers and arguments.
2. Loops use `while <cond> do ... end while;`, `for` (`to` / `downto` / `in` over arrays, `String`, and `map[K]V`) closing with `end for;`, and `repeat ... until` with `break` and `continue`, plus `div`, `+=`/`-=`/`*=`/`/=`/`mod=`/`&=`/`|=`/`^=`/`<<=`/`>>=`, inline `var`/`let` blocks, and `Inc`/`Dec`.
3. `defer` ensures deterministic LIFO cleanup, `try ... except` and `raise` handle system faults, and `?` / `try` propagates `Result<T, E>` and `Option<T>` errors ergonomically.
4. Enums are algebraic types, and `match` (statement or expression) handles `Enum`, value `Option<T>`, typed `Result<T, E>`, primitives, multi-value comma lists, inclusive `low..high` ranges, `if`/`when` guards, and `_` wildcards with compile-time exhaustiveness checking.

➡️ **Next:** **[Chapter 04: Functions & Contracts](04_FUNCTIONS_AND_CONTRACTS.md)**
