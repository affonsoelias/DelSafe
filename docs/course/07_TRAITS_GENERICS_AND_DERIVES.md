# Chapter 07: Traits, Generics & Compiler Derivations

Aether achieves safe code reuse and polymorphism through **Traits** (interfaces without class inheritance) and **Generics with Trait Bounds**.

---

## 1. Defining Traits

A `trait` defines a contract of method signatures:

```aether
module traits_demo;

trait Printable
    function PrintInfo(): Void;
end;

trait AreaCalculable
    function GetArea(): Float64;
end;
```

---

## 2. Implementing Traits (`impl`)

Types explicitly implement traits using the `impl` block:

```aether
type
    Circle = record
        radius: Float64;
    end;

    Square = record
        side: Float64;
    end;

impl AreaCalculable for Circle
    function GetArea(): Float64
    begin
        return 3.14159 * self.radius * self.radius;
    end;
end;

impl AreaCalculable for Square
    function GetArea(): Float64
    begin
        return self.side * self.side;
    end;
end;
```

---

## 3. Generics & Trait Bounds

You can write generic functions constrained by traits using `<T: Trait>` bounds:

```aether
function DisplayArea<T: AreaCalculable>(shape: T): Void
begin
    PrintLn("Calculated area: " + FloatToStr(shape.GetArea()));
end;
```

---

## 4. Automatic Compiler Derivations (`[derive(...)]`)

Writing boilerplate for serializing, cloning, or printing structures is error-prone. Aether includes a compile-time derivation engine:

```aether
[derive(Debug, JSON, Clone, Equals)]
type
    Player = record
        id: Int32;
        nickname: String;
        score: Int32;
    end;
```

When annotated with `[derive(...)]`, the compiler automatically generates:

1. **`Debug` (`ToString()`):**
   ```aether
   p.ToString() // "Player { id: 1, nickname: Alice, score: 9500 }"
   ```
2. **`JSON` (`ToJSON()`):**
   ```aether
   p.ToJSON() // '{"id": 1, "nickname": "Alice", "score": 9500}'
   ```
3. **`Clone` (`Clone()`):**
   Deep copy of the record with independent ownership.
4. **`Equals` (`Equals(borrow other)`):**
   Field-by-field equality comparison returning a `Bool`.

### Working Example:

```aether
module derives_example;

[derive(Debug, JSON, Clone, Equals)]
type
    Item = record
        code: String;
        price: Float64;
    end;

program Main;
var
    it1: Item;
    it2: Item;
    it_clone: Item;
    json_repr: String;
begin
    it1 := Item("SKU-994", 49.90);
    it2 := Item("SKU-994", 49.90);
    it_clone := it1.Clone();

    // Debug output:
    PrintLn("Debug repr: " + it1.ToString());

    // JSON serialization:
    json_repr := it1.ToJSON();
    PrintLn("JSON format: " + json_repr);

    // Equality:
    if it1.Equals(borrow it2) then
        PrintLn("it1 and it2 are structurally identical!");
    end;
end.
```

---

## 5. Summary
1. Traits decouple interface definitions from data representations.
2. Trait bounds `<T: Bound>` enable zero-cost generic dispatch (monomorphization).
3. The `[derive(...)]` attribute eliminates boilerplate for debugging, JSON serialization, cloning, and comparisons.

➡️ **Next:** **[Chapter 08: Error Handling (Result & Option)](08_ERROR_HANDLING_RESULT_OPTION.md)**
