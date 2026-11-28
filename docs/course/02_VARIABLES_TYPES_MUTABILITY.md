# Chapter 02: Variables, Types & Mutability

DelSafe is a statically, strongly typed language designed to eliminate subtle bugs, integer sign errors, and unintended state mutations.

---

## 1. Immutability by Default vs. Explicit Mutation

DelSafe enforces discipline around mutable state:

- **`let`:** Declares an **immutable** binding. Once bound, it can never be reassigned.
- **`var`:** Declares an **explicitly mutable** variable.

```delsafe
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
end variables_demo.
```

### 1.1 Module-Level Constants (`const`)

For defining compile-time, globally accessible constants, DelSafe provides the canonical `const` section at module scope:

```delsafe
module config;

interface

const
    MAX_USERS = 1000;
    PI: Float64 = 3.1415926535;
    APP_NAME = "DelSafeCore";
    TIMEOUT_MS: Int32 = 5000;

implementation

end config.
```

Constants can be untyped (with automatic type inference) or explicitly typed (`NAME: Type = Value;`). Attempting to reassign a constant produces compile-time error `E0384`.

---

## 2. Primitive Types & Hierarchy

DelSafe provides fixed-width scalar types with unambiguous bit sizes:

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

To prevent silent precision loss and overflow vulnerabilities, DelSafe **disallows implicit widening or narrowing conversions between different integer types**:

```delsafe
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
end conversions_demo.
```

---

## 4. Compile-Time Expressions (`comptime`)

DelSafe evaluates constant expressions at compile-time directly in the semantic analysis pipeline:

```delsafe
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
end comptime_demo.
```

---

## 5. Multidimensional Arrays, Sets & Subranges

DelSafe incorporates the rich, mathematically disciplined data types from the classical Pascal tradition:

### 5.1 Multidimensional Arrays (1D, 2D, 3D, and N-D)

Arrays have a fixed size known at compile-time and are laid out contiguously in memory for zero-overhead performance:

```delsafe
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
end arrays_demo.
```

The compiler enforces strict bounds checking at compile-time for constant indices (e.g. `vec[5]` produces `E0309`).

### 5.2 Sets (`set of`) and Membership (`in`)

Sets represent collections of discrete elements (such as enums or subranges) backed by high-performance native bitmasks:

```delsafe
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
    end if;

    // Set operations: union (+), intersection (*), difference (-)
    combined := userPerms + adminPerms;
    if Execute in combined then
        PrintLn("Combined set has Execute permission.");
    end if;
end sets_demo.
```

### 5.3 Subrange Types

Subrange types constrain a scalar variable to an exact closed interval `Low..High`:

```delsafe
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
end subrange_demo.
```

### 5.4 Dynamic Arrays (`array of T`)

When the number of elements is only known at runtime, use resizable dynamic arrays (`array of T`) with `SetLength`, `Length()`, and `Push()`:

```delsafe
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
end dyn_arrays_demo.
```

### 5.5 String Interpolation (`$"..."`)

Rather than manually chaining `+ IntToStr(...)` calls, prefix a string literal with `$` and embed expressions inside `{...}` braces (use `{{` and `}}` to emit literal braces):

```delsafe
module interp_demo;

program Main;
var
    user: String;
    level: Int32;
    active: Bool;
begin
    user := "DelSafeDev";
    level := 5;
    active := true;

    // Desugared at compile-time with zero runtime format-parsing overhead
    PrintLn($"User {user} is at level {level + 1} (active: {active})");
end interp_demo.
```

### 5.6 Raw Pointers (`^T`, `@var`, `nil`) and `unsafe` Blocks

Safe DelSafe code forbids null dereferences and dangling pointers at compile time. When writing low-level hardware drivers or C FFI code that requires raw pointers, pointers are declared with `^T`, addresses are obtained with `@var`, and pointer dereferencing (`ptr^`) is explicitly gated behind an `unsafe ... end unsafe;` block:

```delsafe
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
    end unsafe;

    PrintLn($"Updated value: {value}"); // 99
end unsafe_pointers_demo.
```

### 5.7 Multi-Variable Declarations & Type Inference (`var` / `let`)

Related variables of the same type can share a declaration line, and variables initialized inline can omit the type annotation to infer their concrete type (`Int32`, `Float64`, `String`, `Bool`, etc.):

```delsafe
var
    a, b, c: Int32;
    total := 100;       // Inferred as Int32
    ratio := 2.5;       // Inferred as Float64
let
    appName := "DelSafe"; // Immutable, inferred as String
    enabled := true;     // Immutable, inferred as Bool
```

### 5.8 Associative Maps (`map[K]V`)

DelSafe includes first-class associative dictionaries using `map[KeyType]ValueType`, declared either as a named `type` alias or inline in `var` sections. Supported operations use bracket indexing and UFCS methods:

```delsafe
module maps_demo;

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
    end if;

    scores.Remove("Bob");
    PrintLn(scores.Count()); // 1 (scores.Length() is also supported)
    labels[1] := "Primary";
end maps_demo.
```

### 5.9 Bitwise Operators & Hex/Binary Literals

Integer types support both Pascal (`$FF`, `%1010`) and C-style (`0xFF`, `0b1010`) hexadecimal and binary literals alongside bitwise operators `shl`, `shr`, `xor`, `and`, `or`, and `not`:

```delsafe
module BitwiseDemo;

program Main;
var
    flags, mask, nibble: UInt32;
begin
    flags := $A5;
    mask := 0x0F;
    nibble := (flags shr 4) and mask; // 10
    flags := ((1 shl 3) or 0b0001) xor %0101;
end BitwiseDemo.
```

### 5.10 Array Literals (`[...]`), `.Pop()`, `.Clear()`, & `String[i]`

Fixed and dynamic arrays can be initialized directly using `[e1, e2, ...]`, and dynamic arrays infer their element type when initialized with `:=`. Dynamic arrays support `.Push(v)`, `.Pop()`, and `.Clear()`, while `String` supports 0-based character indexing (`s[i]` returning `Char`) alongside `Ord`, `Chr`, `SizeOf`, and explicit numeric/pointer casts:

```delsafe
module ArrayLiteralsDemo;

program Main;
var
    nums := [10, 20, 30]; // Inferred as array of Int32
    last: Int32;
    ch: Char;
begin
    last := nums.Pop();   // 30 (nums now has 2 elements)
    nums.Clear();
    ch := "DelSafe"[0];    // 'D' (Ord(ch) = 68, Chr(66) = 'B')
end ArrayLiteralsDemo.
```

### 5.11 Simple Type Aliases & Value `Option<T>` / Typed `Result<T, E>`

You can define aliases for primitives and pointers inside `type` (`type UserId = Int64;`, `type IntPtr = ^Int32;`), and use `Option<T>` for value types (`Option<Int32>`, `Option<String>`, `Option<Bool>`) as well as typed `Result<T, E>` with `.is_some`, `.is_none`, `.is_ok`, `.is_err`, `.value`, and `.error`.

### 5.12 Built-in String & Math Functions (`Trim`, `Replace`, `Abs`, `Clamp`, etc.)

Strings include rich standard operations callable either in UFCS (`s.Trim()`) or standalone form:
- **Text helpers:** `Trim`, `UpperCase`, `LowerCase`, `StartsWith`, `EndsWith`, `Contains`, `IndexOf` (0-based, `-1` if absent), and `Replace`.
- **Numeric helpers:** `Abs`, `Min`, `Max`, and `Clamp(val, low, high)` for signed/unsigned integers and floating-point values.

```delsafe
var
    cleaned := "  DelSafe Lang  ".Trim(); // "DelSafe Lang"
    idx := cleaned.IndexOf("Lang");        // 7
    ok := cleaned.StartsWith("DelSafe") and cleaned.Contains("Lang");
    bounded := Clamp(150, 0, 100);         // 100
```

### 5.13 Dynamic Array `.Slice()`, `.Insert()`, `.Delete()`, Named Constructors & `Default(T)`

Dynamic arrays support inserting elements at any index (`.Insert(idx, val)`), deleting by index (`.Delete(idx)`), and non-mutating range extraction (`.Slice(start, len)`). Records also support reordered **named field constructors** (`Ponto(y: 20, x: 10)`), and any value/record/enum type can be zero-initialized using **`Default(TypeName)`**:

```delsafe
module SliceAndDefaultDemo;

type
    Point = record
        x: Int32;
        y: Int32;
    end record;

program Main;
var
    nums := [10, 20, 30, 40];
    sub: array of Int32;
    pt, zeroPt: Point;
begin
    nums.Delete(1);       // [10, 30, 40]
    nums.Insert(1, 99);   // [10, 99, 30, 40]
    sub := nums.Slice(1, 2); // [99, 30]

    pt := Point(y: 20, x: 10);
    zeroPt := Default(Point); // { x = 0, y = 0 }
end SliceAndDefaultDemo.
```

### 5.14 Anonymous Tuples (`(T1, T2)`) & Destructuring

DelSafe supports fixed-arity anonymous tuples `(T1, T2, ...)` and named tuple aliases (`type Coord = (Int32, Int32);`), with 0-based positional field access (`.0`, `.1`) and destructuring in `let` / `var` bindings (with `_` wildcards):

```delsafe
type
    Coord = (Int32, Int32);

var
    pair: (Int32, String) := (10, "delsafe");
    pt: Coord := (15, 27);
begin
    PrintLn(pair.1);               // "delsafe"
    let (num, name) := pair;       // Destructuring
    var (firstCoord, _) := pt;     // Wildcard discards pt.1
end
```

Tuples also compose seamlessly inside `Option<(Int32, String)>`, `Result<(Int32, Int32), String>`, dynamic arrays, and generic functions.

---

## 6. Summary
1. Prefer immutable bindings (`let`) where possible; use `var` only for variables that must mutate, and omit redundant types via `:=` inference when initialized.
2. Integers and floats support explicit casts (`Int32(x)`), `Ord`, `Chr`, `SizeOf`, `$`/`0x` hex, `%`/`0b` binary literals, bitwise operators, and `Abs`/`Min`/`Max`/`Clamp`.
3. Strings are UTF-8, support 0-based `s[i]` (`Char`) indexing, zero-overhead `$"..."` interpolation, and `Trim`, `UpperCase`, `LowerCase`, `StartsWith`, `EndsWith`, `Contains`, `IndexOf`, `Replace`.
4. Dynamic arrays support `[...]` literals, `.Push()`, `.Pop()`, `.Clear()`, `.Insert()`, `.Delete()`, and `.Slice()`, while `map[K]V` provides `Contains`, `Remove`, `Clear`, `Count`/`Length`, and `for k, v in map` iteration.
5. Value `Option<T>`, `Result<T, E>`, sets (`set of`), subranges (`1..31`), simple type aliases, named record constructors, and `Default(T)` express rich domain invariants statically.
6. Raw pointers (`^T`, `@var`, `nil`) require an explicit `unsafe ... end unsafe;` block for dereferencing (`ptr^`).

➡️ **Next:** **[Chapter 03: Control Flow & Pattern Matching](03_CONTROL_FLOW_AND_MATCH.md)**
