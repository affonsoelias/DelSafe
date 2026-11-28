# Chapter 06: Object-Oriented Programming (OOP): Records, UFCS & Composition

DelSafe provides a modern, high-performance approach to **Object-Oriented Programming (OOP)**. Instead of relying on heavyweight classes and fragile inheritance trees, DelSafe follows the proven architectural paradigm of modern systems languages (such as Rust, Go, and Ada 2012): **Composition over Inheritance**, **Value-Type Records**, and **Uniform Function Call Syntax (UFCS)**.

---

## 1. The Object-Oriented Philosophy of DelSafe

In classic object-oriented languages (like Java, C++, or pre-2000 Delphi), OOP is built around classes with inheritance (`class Car extends Vehicle`):

### Why DelSafe Rejects Classic Class Inheritance:
1. **The Fragile Base Class Problem:** Modifying a base class silently breaks assumptions in derived subclasses throughout the codebase.
2. **Virtual Method Indirection (vtable penalties):** Every virtual call requires pointer chasing, destroying CPU instruction caches and branch prediction.
3. **Forced Heap Allocation & Garbage Collection:** Classic objects live in the heap, causing memory fragmentation and GC pauses.
4. **State Bloat:** Subclasses inherit every internal field of their ancestors, creating tightly coupled, bloated data structures.

### The DelSafe Solution:
DelSafe satisfies all fundamental pillars of OOP with **Zero-Cost Abstractions**:

| OOP Pillar | Classic OOP (Java / Delphi) | Modern DelSafe OOP |
| :--- | :--- | :--- |
| **Encapsulation & State** | Heap-allocated `class` | Stack-allocated **`record`** (contiguous, predictable, 0 GC) |
| **Methods & Behavior** | Methods inside class body | **UFCS** (`instance.Method()`) with explicit ownership |
| **Polymorphism** | `virtual` / `override` vtables | **`trait`** contracts & Generics with Trait Bounds |
| **Code Reuse** | Subclassing (`class B : A`) | **Composition** (nesting records) & `[derive(...)]` |
| **Visibility** | `private` / `protected` / `public` | Unit `interface`/`implementation` sections and `pub`/`priv` modifiers |

---

## 2. Encapsulation: Declaring Records & Constructors

A `record` represents the object's encapsulated state. Fields are laid out contiguously in memory:

```delsafe
module geometry;

type
    Point = record
        x: Float64;
        y: Float64;
    end record;

    // Composition: Rectangle encapsulates a Point for its origin
    Rectangle = record
        origin: Point;
        width: Float64;
        height: Float64;
    end record;
```

### Positional & Named Constructors, and `Default(T)`
Every record automatically provides both positional and named-field constructors, plus zero-initialization via `Default(T)`:

```delsafe
program Main;
var
    pt, origin: Point;
    rect: Rectangle;
begin
    pt := Point(10.0, 20.0);
    origin := Default(Point);
    rect := Rectangle(width: 100.0, height: 50.0, origin: pt);

    PrintLn("Origin: (" + FloatToStr(rect.origin.x) + ", " + FloatToStr(rect.origin.y) + ")");
    PrintLn("Width: " + FloatToStr(rect.width));
end geometry.
```

---

## 3. Methods & Uniform Function Call Syntax (UFCS)

In traditional languages, there is a rigid divide between procedural functions (`CalculateArea(rect)`) and methods (`rect.CalculateArea()`).

In DelSafe, **UFCS unifies both worlds**: any function whose first parameter receives the record (either by `borrow`, `mut borrow`, or `take`) can be called using standard object-oriented dot-syntax:

$$\text{Function}(x, y) \iff x.\text{Function}(y)$$

### Defining Read-Only and Mutating Methods:

```delsafe
module shapes;

type
    Circle = record
        radius: Float64;
    end record;

// Read-Only Method: Takes an immutable borrow of self
function Area(borrow self: Circle) return Float64 is
begin
    return 3.1415926535 * self.radius * self.radius;
end Area;

// Read-Only Method: Computes perimeter
function Perimeter(borrow self: Circle) return Float64 is
begin
    return 2.0 * 3.1415926535 * self.radius;
end Perimeter;

// Mutating Method: Takes an exclusive mutable borrow of self
procedure Scale(mut borrow self: Circle; factor: Float64) is
begin
    self.radius := self.radius * factor;
end Scale;

program Main;
var
    c: Circle;
    a: Float64;
begin
    c := Circle(10.0);

    // Calling methods with natural OO dot-notation:
    a := c.Area();
    PrintLn("Initial area: " + FloatToStr(a));
    PrintLn("Perimeter: " + FloatToStr(c.Perimeter()));

    // Mutating method call (guaranteed safe by the Borrow Checker):
    c.Scale(2.0);
    PrintLn("Scaled area: " + FloatToStr(c.Area()));

    // Both syntax forms are identical under the hood:
    // c.Area() <===> Area(c)
end shapes.
```

### The Architectural Benefits of UFCS:
1. **Zero Runtime Overhead:** Direct function calls without vtables or pointer overhead.
2. **Open Extensibility:** You can add new methods to *any* record type (even types from third-party libraries) without altering the original record definition!
3. **First-Class Tooling & IDE Autocomplete:** The DelSafe LSP and IDEs discover all available functions for any record type when you type `.`.

---

## 4. Composition Over Inheritance

Rather than creating fragile inheritance hierarchies like `Vehicle -> MotorVehicle -> Car`, DelSafe models domains by composing independent, reusable components:

```delsafe
module vehicle_system;

type
    Engine = record
        horsepower: Int32;
        is_running: Bool;
    end record;

    GPS = record
        latitude: Float64;
        longitude: Float64;
    end record;

    // Car is composed of an Engine and a GPS unit
    Car = record
        model: String;
        engine: Engine;
        navigation: GPS;
    end record;

procedure Start(mut borrow self: Engine) is
begin
    self.is_running := true;
end Start;

procedure Drive(mut borrow self: Car) is
begin
    self.engine.Start();
    PrintLn(self.model + " is driving smoothly!");
end Drive;

program Main;
var
    my_car: Car;
begin
    my_car := Car("DelSafe GT", Engine(450, false), GPS(-23.5505, -46.6333));
    my_car.Drive();
end vehicle_system.
```

---

## 5. Automatic Derivations on Objects (`[derive(...)]`)

To eliminate tedious boilerplate, records can automatically derive fundamental object behaviors at compile time:

```delsafe
[derive(Debug, JSON, Clone, Equals)]
type
    Account = record
        id: Int64;
        owner: String;
        balance: Float64;
    end record;
```

The compiler synthesizes:
- **`Debug` (`acc.ToString()`):** Formats the object into a readable debug representation.
- **`JSON` (`acc.ToJSON()` / `Account.FromJSON(raw)`):** Serializes and deserializes records using valid JSON strings.
- **`Clone` (`acc.Clone()`):** Deep-copies the object with independent memory ownership.
- **`Equals` (`acc.Equals(borrow other)`):** Compares all fields for equality.

> **Tip:** You can also group associated constructors and methods directly inside `impl Type ... end impl;` blocks, covered in the next chapter.

---

## 6. Summary

1. **DelSafe is fully object-oriented**, but ditches legacy class inheritance in favor of **Composition, Records, and UFCS**.
2. **Records** provide contiguous, cache-friendly value semantics with zero garbage collection overhead.
3. **UFCS** enables clean `instance.Method()` dot-syntax while retaining the simplicity and speed of pure functions.
4. **Borrow Checker integration** ensures that methods taking `mut borrow self` can never suffer from data races or concurrent aliasing bugs.
5. In the next chapter, we will see how **Traits** provide the final pillar of OOP: **Polymorphism and Interface Contracts**.

➡️ **Next:** **[Chapter 07: Traits, Generics & Compiler Derivations](07_TRAITS_GENERICS_AND_DERIVES.md)**
