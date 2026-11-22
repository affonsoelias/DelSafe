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

---

## 6. Summary
1. Prefer immutable bindings where possible; use `var` only for variables that must mutate.
2. Integers and floats require explicit casts (`Int32(x)`) to avoid accidental precision truncation.
3. Strings are UTF-8, type-safe, and concatenate using `+`.
4. Arrays can have arbitrary dimensions ($N$-D: 1D, 2D, 3D, etc.) with compile-time boundary safety.
5. Sets (`set of`) provide type-safe bitmask collections with `in`, `+`, `*`, and `-`.
6. Subranges (`1..31`) enforce strict numerical bounds.

➡️ **Next:** **[Chapter 03: Control Flow & Pattern Matching](03_CONTROL_FLOW_AND_MATCH.md)**
