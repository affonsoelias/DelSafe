# Chapter 05: The Borrow Checker & Ownership

The Borrow Checker is the core engine of DelSafe's memory safety. It guarantees **100% memory safety (no use-after-free, no double-free, no dangling pointers, and no data races)** at compile time without requiring a garbage collector.

---

## 1. The Core Ownership Rules

Every piece of heap-allocated or non-trivial data in DelSafe adheres to three fundamental rules:

1. **Each resource has exactly one Owner.**
2. **When the Owner goes out of scope, the resource is automatically freed (Deterministic RAII).**
3. **At any given moment, you can have either:**
   - Multiple immutable references (`borrow`) to a resource, **OR**
   - Exactly one mutable reference (`mut borrow`) to a resource,
   - **Never both simultaneously (Aliasing XOR Mutability).**

---

## 2. Move Semantics: Transferring Ownership (`take`)

When a variable is passed with `take`, its ownership is transferred to the receiving function. The original variable becomes invalid and cannot be read again:

```delsafe
module ownership_move;

type
    Buffer = record
        capacity: Int32;
        data: String;
    end record;

procedure ConsumeBuffer(take buf: Buffer) is
begin
    PrintLn("Buffer consumed: " + buf.data);
    // 'buf' is destroyed when this procedure exits!
end ConsumeBuffer;

program Main;
var
    my_buf: Buffer;
begin
    my_buf := Buffer(1024, "Raw Network Packet");

    ConsumeBuffer(take my_buf);

    // ERROR: my_buf was moved!
    // PrintLn(my_buf.data); // Compile Error: Use of moved variable 'my_buf'
end ownership_move.
```

---

## 3. Read-Only Borrowing (`borrow`)

Often, a function only needs to inspect or read data without taking ownership or making a costly copy. Use `borrow`:

```delsafe
module borrow_read;

type
    Document = record
        title: String;
        word_count: Int32;
    end record;

procedure PrintSummary(borrow doc: Document) is
begin
    PrintLn("Title: " + doc.title + " (" + IntToStr(doc.word_count) + " words)");
end PrintSummary;

program Main;
var
    doc: Document;
begin
    doc := Document("DelSafe Language Spec", 5400);

    // We can borrow 'doc' multiple times safely:
    PrintSummary(borrow doc);
    PrintSummary(borrow doc);

    // 'doc' is still valid and owned here!
    PrintLn("Document is still accessible: " + doc.title);
end borrow_read.
```

---

## 4. Mutable Borrowing (`mut borrow`)

When a function needs to modify an existing resource in place, use `mut borrow`:

```delsafe
module borrow_mut;

type
    Account = record
        holder: String;
        balance: Float64;
    end record;

procedure Deposit(mut borrow acc: Account; amount: Float64) is
begin
    acc.balance := acc.balance + amount;
end Deposit;

program Main;
var
    my_acc: Account;
begin
    my_acc := Account("Alice", 1000.0);

    Deposit(mut borrow my_acc, 250.0);
    Deposit(mut borrow my_acc, 500.0);

    PrintLn("Final Balance for " + my_acc.holder + ": $" + FloatToStr(my_acc.balance));
end borrow_mut.
```

---

## 5. Preventing Data Races and Aliasing Conflicts

The DelSafe compiler prevents aliasing bugs at compile time. For instance, you cannot pass a resource as mutable while another reference is reading it:

```delsafe
// This pattern is rejected by the Borrow Checker:
// UpdateBuffer(mut borrow buf, borrow buf.data);
// Error: Cannot borrow 'buf' as mutable more than once or concurrently with immutable borrows!
```

---

## 6. Disjoint Field Borrows & Partial Moves

DelSafe's Borrow Checker tracks ownership at **field granularity** inside records:

- **Disjoint mutable field borrows:** Two different fields of the same record can be mutably borrowed at the same time (`SwapFields(mut borrow pair.a, mut borrow pair.b);`), while borrowing the same field twice simultaneously is rejected (`E0502`).
- **Partial moves:** Moving a single field with `take mb.name` invalidates only that field—remaining fields like `mb.num` stay accessible, and the moved field can be restored by reassigning it (`mb.name := "World";`).

---

## 7. Heap Ownership (`Box<T>`), `Free`/`Dispose`, and Deterministic RAII (`impl Drop for T`)

For recursive structures or explicit heap allocation, wrap values in `Box<T>`. Memory is released deterministically at scope exit (or early via `Free(x)` / `Dispose(x)`), and custom cleanup logic can be attached to any record using `impl Drop for <Type>`:

```delsafe
impl Drop for Resource
    procedure Drop(mut borrow self) is
    begin
        PrintLn($"Releasing resource #{self.id}");
    end Drop;
end impl;
```

`Drop` runs automatically in **LIFO (Last-In, First-Out)** order at block boundaries, early `return` paths, and loop `break` statements across both Free Pascal and C99 backends.

---

## 8. Summary: Ownership Cheat Sheet

| Parameter Mode | Keyword | Can Read? | Can Write? | Caller Retains Ownership? |
| :--- | :--- | :--- | :--- | :--- |
| **Move** | `take` | Yes | Yes (owns it) | No (moved to callee) |
| **Shared Read** | `borrow` | Yes | No | Yes (borrow returned upon exit) |
| **Exclusive Write** | `mut borrow` | Yes | Yes | Yes (borrow returned upon exit) |

➡️ **Next:** **[Chapter 06: Records & Uniform Function Call Syntax](06_RECORDS_AND_UFCS.md)**
