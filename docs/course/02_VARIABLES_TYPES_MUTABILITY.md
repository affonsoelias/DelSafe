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

## 5. Summary
1. Prefer immutable bindings where possible; use `var` only for variables that must mutate.
2. Integers and floats require explicit casts (`Int32(x)`) to avoid accidental precision truncation.
3. Strings are UTF-8, type-safe, and concatenate using `+`.

➡️ **Next:** **[Chapter 03: Control Flow & Pattern Matching](03_CONTROL_FLOW_AND_MATCH.md)**
