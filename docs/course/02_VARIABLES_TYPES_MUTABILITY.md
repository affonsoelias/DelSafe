# Chapter 02: Variables, Types & Mutability

Aether is a statically, strongly typed language designed to eliminate subtle bugs, integer sign errors, and unintended state mutations.

---

## 1. Immutability by Default vs. Explicit Mutation

Aether enforces discipline around mutable state:

- **`let`:** Declares an **immutable** binding. Once bound, it can never be reassigned.
- **`var`:** Declares an **explicitly mutable** variable.

```aether
module variables_demo;

program Main;
var
    counter: Int32;
    greeting: String;
begin
    // Explicit mutation
    counter := 10;
    counter := counter + 1; // OK

    greeting := "Hello";
    // Type safety prevents assigning numbers to strings:
    // greeting := 42; // Compile error: E0308 (Type mismatch)

    PrintLn(greeting + "! Counter = " + IntToStr(counter));
end.
```

### 1.1 Module-Level Constants (`const`)

For defining compile-time, globally accessible constants, Aether provides the canonical `const` section at module scope:

```aether
module config;

const
    MAX_USERS = 1000;
    PI: Float64 = 3.1415926535;
    APP_NAME = "AetherCore";
    TIMEOUT_MS: Int32 = 5000;
```

Constants can be untyped (with automatic type inference) or explicitly typed (`NAME: Type = Value;`). Attempting to reassign a constant produces compile-time error `E0384`.

---

## 2. Primitive Types & Hierarchy

Aether provides fixed-width scalar types with unambiguous bit sizes:

### Signed Integers
- `Int8`: -128 to 127
- `Int16`: -32,768 to 32,767
- `Int32`: -2,147,483,648 to 2,147,483,647 (Standard signed integer)
- `Int64`: -9,223,372,036,854,775,808 to 9,223,372,036,854,775,807

### Unsigned Integers
- `UInt8` (or `Byte`): 0 to 255
- `UInt16` (or `Word`): 0 to 65,535
- `UInt32`: 0 to 4,294,967,295
- `UInt64`: 0 to 18,446,744,073,709,551,615

### Floating Point
- `Float32`: 32-bit IEEE 754 single-precision float
- `Float64`: 64-bit IEEE 754 double-precision float (Standard float)

### Boolean
- `Bool`: `true` or `false`

### Text
- `String`: UTF-8 native dynamically managed string with copy-on-write optimizations.

---

## 3. Explicit Type Conversions

To prevent silent precision loss and overflow vulnerabilities, Aether **disallows implicit widening or narrowing conversions between different integer types**:

```aether
module conversions_demo;

program Main;
var
    small: Int16;
    large: Int32;
    pi_val: Float64;
    rounded: Int32;
begin
    small := 100;
    
    // Explicit conversion required:
    large := Int32(small);

    pi_val := 3.14159;
    rounded := Int32(pi_val); // Explicit truncation to 3

    PrintLn("Converted large: " + IntToStr(large));
    PrintLn("Truncated float: " + IntToStr(rounded));
end.
```

---

## 4. Compile-Time Expressions (`comptime`)

Aether evaluates constant expressions at compile-time directly in the semantic analysis pipeline:

```aether
module comptime_demo;

program Main;
var
    buffer_size: Int32;
begin
    // Folded at compile time into literal 10240:
    buffer_size := (10 * 1024);

    // The compiler will reject illegal math at compile time:
    // let bad := 10 / 0; // Compile Error E0301: Division by zero detected at compile-time

    PrintLn("Buffer size: " + IntToStr(buffer_size) + " bytes");
end.
```

---

## 5. Multidimensional Arrays, Sets & Subranges

Aether incorporates the rich, mathematically disciplined data types from the classical Pascal tradition:

### 5.1 Multidimensional Arrays (1D, 2D, 3D, and N-D)

Arrays have a fixed size known at compile-time and are laid out contiguously in memory for zero-overhead performance:

```aether
module arrays_demo;

type
    Vector5 = array[5] of Int32;
    Matrix3x3 = array[3, 3] of Float64;
    VoxelGrid = array[4, 4, 4] of Int32;

program Main;
var
    vec: Vector5;
    mat: Matrix3x3;
begin
    // 1D array indexing (0-based)
    vec[0] := 10;
    vec[4] := 50;

    // 2D matrix indexing: comma syntax or chained brackets
    mat[0, 0] := 1.0;
    mat[1, 2] := 3.14;

    PrintLn("vec[0] = " + IntToStr(vec[0]));
    PrintLn("mat[1, 2] = " + FloatToStr(mat[1, 2]));
end.
```

The compiler enforces strict bounds checking at compile-time for constant indices (e.g. `vec[5]` produces `E0309`).

### 5.2 Sets (`set of`) and Membership (`in`)

Sets represent collections of discrete elements (such as enums or subranges) backed by high-performance native bitmasks:

```aether
module sets_demo;

type
    Permission = set of (Read, Write, Execute);

program Main;
var
    userPerms: Permission;
    adminPerms: Permission;
    combined: Permission;
begin
    // Set literals
    userPerms := [Read];
    adminPerms := [Read, Write, Execute];

    // Membership test with `in`
    if Read in userPerms then
        PrintLn("User has Read access.");
    end;

    // Set operations: union (+), intersection (*), difference (-)
    combined := userPerms + adminPerms;
    if Execute in combined then
        PrintLn("Combined set has Execute permission.");
    end;
end.
```

### 5.3 Subrange Types

Subrange types constrain a scalar variable to an exact closed interval `Low..High`:

```aether
module subrange_demo;

type
    DayOfMonth = 1..31;
    ByteRange = 0..255;

program Main;
var
    day: DayOfMonth;
begin
    day := 22; // OK: Within 1..31
    PrintLn("Day: " + IntToStr(day));
end.
```

### 5.4 Dynamic Arrays (`array of T`)

When the number of elements is only known at runtime, use resizable dynamic arrays (`array of T`) with `SetLength`, `Length()`, and `Push()`:

```aether
module dyn_arrays_demo;

type
    ScoreList = array of Int32;

program Main;
var
    scores: ScoreList;
    names: array of String;
begin
    SetLength(scores, 2);
    scores[0] := 95;
    scores[1] := 88;
    scores.Push(100);

    names.Push("Alice");
    PrintLn($"Scores count: {scores.Length()}, First user: {names[0]}");
end.
```

### 5.5 String Interpolation (`$"..."`)

Rather than manually chaining `+ IntToStr(...)` calls, prefix a string literal with `$` and embed expressions inside `{...}` braces (use `{{` and `}}` to emit literal braces):

```aether
module interp_demo;

program Main;
var
    user: String;
    level: Int32;
    active: Bool;
begin
    user := "AetherDev";
    level := 5;
    active := true;

    // Desugared at compile-time with zero runtime format-parsing overhead
    PrintLn($"User {user} is at level {level + 1} (active: {active})");
end.
```

### 5.6 Raw Pointers (`^T`, `@var`, `nil`) and `unsafe` Blocks

Safe Aether code forbids null dereferences and dangling pointers at compile time. When writing low-level hardware drivers or C FFI code that requires raw pointers, pointers are declared with `^T`, addresses are obtained with `@var`, and pointer dereferencing (`ptr^`) is explicitly gated behind an `unsafe ... end;` block:

```aether
module unsafe_pointers_demo;

program Main;
var
    value: Int32;
    ptr: ^Int32;
begin
    ptr := nil;
    value := 10;
    ptr := @value;

    // ptr^ := 99; // Compile Error E0312: Raw pointer dereference requires an 'unsafe' block!

    unsafe
        ptr^ := 99; // Explicitly demarcated low-level boundary
    end;

    PrintLn($"Updated value: {value}"); // 99
end.
```

### 5.7 Multi-Variable Declarations & Type Inference (`var` / `let`)

Related variables of the same type can share a declaration line, and variables initialized inline can omit the type annotation to infer their concrete type (`Int32`, `Float64`, `String`, `Bool`, etc.):

```aether
var
    a, b, c: Int32;
    total := 100;       // Inferred as Int32
    ratio := 2.5;       // Inferred as Float64
let
    appName := "Aether"; // Immutable, inferred as String
    enabled := true;     // Immutable, inferred as Bool
```

### 5.8 Associative Maps (`map[K]V`)

Aether includes first-class associative dictionaries using `map[KeyType]ValueType`, declared either as a named `type` alias or inline in `var` sections. Supported operations use bracket indexing and UFCS methods:

```aether
type
    ScoreBoard = map[String]Int32;

program Main;
var
    scores: ScoreBoard;
    labels: map[Int32]String;
begin
    scores["Alice"] := 10;
    scores["Bob"] := 25;

    if scores.Contains("Alice") then
        PrintLn(scores["Alice"]); // 10
    end;

    scores.Remove("Bob");
    PrintLn(scores.Count()); // 1 (scores.Length() is also supported)
    labels[1] := "Primary";
end.
```

### 5.9 Bitwise Operators & Hex/Binary Literals

Integer types support both Pascal (`$FF`, `%1010`) and C-style (`0xFF`, `0b1010`) hexadecimal and binary literals alongside bitwise operators `shl`, `shr`, `xor`, `and`, `or`, and `not`:

```aether
var
    flags, mask, nibble: UInt32;
begin
    flags := $A5;
    mask := 0x0F;
    nibble := (flags shr 4) and mask; // 10
    flags := ((1 shl 3) or 0b0001) xor %0101;
end.
```

### 5.10 Array Literals (`[...]`), `.Pop()`, `.Clear()`, & `String[i]`

Fixed and dynamic arrays can be initialized directly using `[e1, e2, ...]`, and dynamic arrays infer their element type when initialized with `:=`. Dynamic arrays support `.Push(v)`, `.Pop()`, and `.Clear()`, while `String` supports 0-based character indexing (`s[i]` returning `Char`) alongside `Ord`, `Chr`, `SizeOf`, and explicit numeric/pointer casts:

```aether
var
    nums := [10, 20, 30]; // Inferred as array of Int32
    last: Int32;
    ch: Char;
begin
    last := nums.Pop();   // 30 (nums now has 2 elements)
    nums.Clear();
    ch := "Aether"[0];    // 'A' (Ord(ch) = 65, Chr(66) = 'B')
end.
```

### 5.11 Simple Type Aliases & Value `Option<T>` / Typed `Result<T, E>`

You can define aliases for primitives and pointers inside `type` (`type UserId = Int64;`, `type IntPtr = ^Int32;`), and use `Option<T>` for value types (`Option<Int32>`, `Option<String>`, `Option<Bool>`) as well as typed `Result<T, E>` with `.is_some`, `.is_none`, `.is_ok`, `.is_err`, `.value`, and `.error`.

---

## 6. Summary
1. Prefer immutable bindings (`let`) where possible; use `var` only for variables that must mutate, and omit redundant types via `:=` inference when initialized.
2. Integers and floats support explicit casts (`Int32(x)`), `Ord`, `Chr`, `SizeOf`, `$`/`0x` hex, `%`/`0b` binary literals, and bitwise operators (`shl`, `shr`, `xor`, `and`, `or`, `not`).
3. Strings are UTF-8, support 0-based `s[i]` (`Char`) indexing, and provide zero-overhead compile-time interpolation via `$"..."`.
4. Arrays support `[...]` literals, `.Pop()`/`.Clear()`, `SetLength`/`Push`, while `map[K]V` provides `Contains`, `Remove`, `Clear`, `Count`/`Length`, and `for k, v in map` iteration.
5. Value `Option<T>`, `Result<T, E>`, sets (`set of`), subranges (`1..31`), and simple type aliases (`type UserId = Int64;`) express rich domain invariants statically.
6. Raw pointers (`^T`, `@var`, `nil`) require an explicit `unsafe ... end;` block for dereferencing (`ptr^`).

➡️ **Next:** **[Chapter 03: Control Flow & Pattern Matching](03_CONTROL_FLOW_AND_MATCH.md)**
