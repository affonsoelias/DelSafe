# Chapter 06: Records & Uniform Function Call Syntax (UFCS)

Aether avoids complex, deep inheritance hierarchies. Instead, it provides **Data Records** coupled with **Uniform Function Call Syntax (UFCS)** for elegant, object-oriented method syntax with value-type performance.

---

## 1. Declaring Records

A record is a composite data structure laid out contiguously in memory:

```aether
module records_demo;

type
    Point = record
        x: Float64;
        y: Float64;
    end;

    Rectangle = record
        origin: Point;
        width: Float64;
        height: Float64;
    end;
```

---

## 2. Fast Construction

Every record in Aether automatically receives a positional constructor:

```aether
program Main;
var
    p1: Point;
    rect: Rectangle;
begin
    p1 := Point(10.0, 20.0);
    rect := Rectangle(p1, 100.0, 50.0);

    PrintLn("Point coordinates: (" + FloatToStr(p1.x) + ", " + FloatToStr(p1.y) + ")");
    PrintLn("Rectangle width: " + FloatToStr(rect.width));
end.
```

---

## 3. Uniform Function Call Syntax (UFCS)

In traditional languages, there is a strict divide between free functions (`ComputeArea(rect)`) and methods (`rect.ComputeArea()`).

In Aether, **UFCS unifies both**: any function whose first parameter is a record can be invoked using method syntax `instance.Function(...)`!

```aether
module ufcs_demo;

type
    Circle = record
        radius: Float64;
    end;

function Area(borrow c: Circle): Float64
begin
    return 3.1415926535 * c.radius * c.radius;
end;

function Scale(mut borrow c: Circle, factor: Float64): Void
begin
    c.radius := c.radius * factor;
end;

program Main;
var
    c: Circle;
    a: Float64;
begin
    c := Circle(10.0);

    // Call as an object method:
    a := c.Area();
    PrintLn("Initial area: " + FloatToStr(a));

    // Mutating method:
    c.Scale(2.0);
    PrintLn("Scaled area: " + FloatToStr(c.Area()));

    // Both calling syntaxes are 100% equivalent:
    // Area(c) == c.Area()
end.
```

### Advantages of UFCS:
1. **Zero Runtime Overhead:** No vtables, no virtual dispatch pointers, and no dynamic heap allocation.
2. **Extensibility:** You can add new "methods" to any record in any module without modifying the original record definition!
3. **IDE Autocomplete:** IDEs and the Aether LSP can discover all available functions for any record type when you type `.`.

---

## 4. Automatic Derivations on Records

Records can automatically derive core behaviors with compile-time attributes:

```aether
[derive(Debug, JSON, Clone, Equals)]
type
    User = record
        id: Int32;
        username: String;
        is_active: Bool;
    end;
```

In the next chapter, we will explore traits, generics, and how derived traits work under the hood.

➡️ **Next:** **[Chapter 07: Traits, Generics & Derives](07_TRAITS_GENERICS_AND_DERIVES.md)**
