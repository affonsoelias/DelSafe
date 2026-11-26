# Ownership and Borrowing Concepts

In DelSafe, you write high-performance systems code **without worrying about memory leaks and without Garbage Collector pauses**.

This is powered by DelSafe's **Borrow Checker**, which analyzes the ownership of every variable at compile time.

---

## 1. The 3 Memory Modifiers

When defining a function or passing arguments in DelSafe, there are three explicit modifiers:

| Modifier | Meaning | Practical Behavior | Traditional Pascal Equivalent |
|:---|:---|:---|:---|
| **`borrow x: T`** | **Immutable Borrow** | The function only **reads** the data. The variable stays yours and you can keep using it afterward. | `const x: T` |
| **`mut borrow x: T`** | **Mutable Borrow** | The function can **read and modify** the data. Nobody else can read or mutate it at the same time. | `var x: T` |
| **`take x: T`** | **Move / Transfer Ownership** | Ownership is **permanently transferred** to the function. You can no longer use the original variable. | Pass with move/release |

---

## 2. Practical Example: `borrow` vs `take`

Consider a simple record managing a data buffer:

```pascal
module OwnershipExample;

type
    DataBuffer = record
        id: UInt32;
        size: UInt64;
    end record;

// 'borrow' only borrows for read-only inspection:
procedure Inspect(borrow buf: DataBuffer) is
begin
    PrintLn("Reading buffer ID: %d, Size: %d", buf.id, buf.size);
end Inspect;

// 'take' takes ownership and consumes the resource:
procedure Finalize(take buf: DataBuffer) is
begin
    PrintLn("Buffer %d finalized and memory freed!", buf.id);
end Finalize;

program Main;
var
    my_buffer: DataBuffer;
begin
    my_buffer := DataBuffer(id: 101, size: 2048);

    // 1. Allowed: Borrows only for reading
    Inspect(borrow my_buffer);

    // 2. You still own the variable, so you can read it again!
    Inspect(borrow my_buffer);

    // 3. Now transfer ownership permanently to Finalize:
    Finalize(take my_buffer);

    // 4. COMPILE ERROR!
    // Trying to read 'my_buffer' here triggers Error E0382:
    // Inspect(borrow my_buffer); // <-- 'my_buffer' was already moved!
end OwnershipExample.
```

---

## 3. Friendly Compiler Diagnostics

If you make a *Use-After-Move* mistake (using a variable after it was consumed with `take`), `delsafec` tells you exactly what happened:

```text
Compilation Error: [Ownership Error E0382 at 32:24]: Use of moved value: "my_buffer"
  --> Note: Value was moved previously at line 28:15 via "take".
```

---

## 4. Modern Object-Oriented Style via UFCS

Thanks to **UFCS (*Uniform Function Call Syntax*)**, any function or procedure whose first parameter is `borrow` or `mut borrow` can be called as if it were a method on that value:

```pascal
// Traditional procedural style:
Inspect(borrow my_buffer);

// Method-call style (safe syntactic sugar):
my_buffer.Inspect();
```

Both forms compile to the exact same high-speed native machine code and go through the exact same strict safety checks!
