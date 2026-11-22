# Chapter 05: The Borrow Checker & Ownership

The Borrow Checker is the core engine of Aether's memory safety. It guarantees **100% memory safety (no use-after-free, no double-free, no dangling pointers, and no data races)** at compile time without requiring a garbage collector.

---

## 1. The Core Ownership Rules

Every piece of heap-allocated or non-trivial data in Aether adheres to three fundamental rules:

1. **Each resource has exactly one Owner.**
2. **When the Owner goes out of scope, the resource is automatically freed (Deterministic RAII).**
3. **At any given moment, you can have either:**
   - Multiple immutable references (`borrow`) to a resource, **OR**
   - Exactly one mutable reference (`mut borrow`) to a resource,
   - **Never both simultaneously (Aliasing XOR Mutability).**

---

## 2. Move Semantics: Transferring Ownership (`take`)

When a variable is passed with `take`, its ownership is transferred to the receiving function. The original variable becomes invalid and cannot be read again:

```aether
module ownership_move;

type
    Buffer = record
        capacity: Int32;
        data: String;
    end;

function ConsumeBuffer(take buf: Buffer): Void
begin
    PrintLn("Buffer consumed: " + buf.data);
    // 'buf' is destroyed when this function exits!
end;

program Main;
var
    my_buf: Buffer;
begin
    my_buf := Buffer(1024, "Raw Network Packet");

    ConsumeBuffer(take my_buf);

    // ERROR: my_buf was moved!
    // PrintLn(my_buf.data); // Compile Error: Use of moved variable 'my_buf'
end.
```

---

## 3. Read-Only Borrowing (`borrow`)

Often, a function only needs to inspect or read data without taking ownership or making a costly copy. Use `borrow`:

```aether
module borrow_read;

type
    Document = record
        title: String;
        word_count: Int32;
    end;

function PrintSummary(borrow doc: Document): Void
begin
    PrintLn("Title: " + doc.title + " (" + IntToStr(doc.word_count) + " words)");
end;

program Main;
var
    doc: Document;
begin
    doc := Document("Aether Language Spec", 5400);

    // We can borrow 'doc' multiple times safely:
    PrintSummary(borrow doc);
    PrintSummary(borrow doc);

    // 'doc' is still valid and owned here!
    PrintLn("Document is still accessible: " + doc.title);
end.
```

---

## 4. Mutable Borrowing (`mut borrow`)

When a function needs to modify an existing resource in place, use `mut borrow`:

```aether
module borrow_mut;

type
    Account = record
        holder: String;
        balance: Float64;
    end;

function Deposit(mut borrow acc: Account, amount: Float64): Void
begin
    acc.balance := acc.balance + amount;
end;

program Main;
var
    my_acc: Account;
begin
    my_acc := Account("Alice", 1000.0);

    Deposit(mut borrow my_acc, 250.0);
    Deposit(mut borrow my_acc, 500.0);

    PrintLn("Final Balance for " + my_acc.holder + ": $" + FloatToStr(my_acc.balance));
end.
```

---

## 5. Preventing Data Races and Aliasing Conflicts

The Aether compiler prevents aliasing bugs at compile time. For instance, you cannot pass a resource as mutable while another reference is reading it:

```aether
// This pattern is rejected by the Borrow Checker:
// UpdateBuffer(mut borrow buf, borrow buf.data);
// Error: Cannot borrow 'buf' as mutable more than once or concurrently with immutable borrows!
```

---

## 6. Summary: Ownership Cheat Sheet

| Parameter Mode | Keyword | Can Read? | Can Write? | Caller Retains Ownership? |
| :--- | :--- | :--- | :--- | :--- |
| **Move** | `take` | Yes | Yes (owns it) | No (moved to callee) |
| **Shared Read** | `borrow` | Yes | No | Yes (borrow returned upon exit) |
| **Exclusive Write** | `mut borrow` | Yes | Yes | Yes (borrow returned upon exit) |

➡️ **Next:** **[Chapter 06: Records & Uniform Function Call Syntax](06_RECORDS_AND_UFCS.md)**
