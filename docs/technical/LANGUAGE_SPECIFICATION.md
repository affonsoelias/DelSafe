# Formal Specification of the Aether Language (AetherLang)

> **"The clarity, structure, and discipline of Object Pascal with the strict memory safety and modern expressiveness of Rust."**

---

## 1. Overview and Core Principles

**Aether** is a compiled, statically and strongly typed systems programming language with deterministic memory management and no garbage collector. Its core pillars are:

1. **Modern Object Orientation (UFCS - Uniform Function Call Syntax):**
   - Pure data modeled via `record` types and algebraic `enum` variants (ADTs).
   - No fragile deep class inheritance or implicit vtables.
   - Any function or procedure whose first parameter is `borrow T`, `mut borrow T`, or `take T` can be called either procedurally (`Inspect(borrow buf)`) or in method style (`buf.Inspect()`).
2. **Syntactic Determinism:** An unambiguous, explicit grammar ideal for human readability, maintenance, and reliable AI code generation and analysis.
3. **Static Memory Safety (Ownership & Borrowing):** Compile-time lifetime and ownership checking eliminates null dereferences, use-after-free bugs, double frees, and data races.
4. **Native Contracts:** Preconditions (`require`) and postconditions (`ensure`) integrated directly into routine signatures (Ada/Eiffel style).
5. **Monadic & Exhaustive Error Handling:** Built-in `Result<T, E>` and `Option<T>` types paired with exhaustive `match` expressions and statements.
6. **Disciplined Structure:** Explicit keywords (`module`, `contract`, `begin ... end`, `if ... then ... else ... end if`, `type`, `record ... end record`, `enum ... end enum`) instead of cryptic symbol soup.

---

## 2. Lexical Elements (Lexer)

### 2.1 Identifiers and Keywords
- **Identifiers:** Begin with an ASCII letter (`a-z`, `A-Z`) or underscore (`_`), followed by letters, digits (`0-9`), or underscores. Case-sensitive (`PascalCase` for types/modules, `camelCase` or `snake_case` for variables and routines).
- **Reserved Keywords:**
  ```text
  and, as, asm, async, await, begin, borrow, break, case, contract,
  continue, default, defer, div, do, downto, else, end, ensure, enum,
  except, export, extern, false, finalization, for, function, if, impl,
  implies, import, in, initialization, interface, implementation, is,
  let, match, mod, module, mut, nil, not, of, or, priv, procedure,
  program, pub, raise, record, repeat, require, return, set, shl, shr,
  spawn, struct, take, then, to, trait, true, try, type, unsafe, until,
  var, when, while, with, xor
  ```

### 2.2 Literals
- **Integers:** Decimal (`42`, `100_000`), Hexadecimal (`$FF` or `0xFF`), Binary (`%1010` or `0b1010`).
- **Floating-Point:** `3.14159`, `1.0e-5`.
- **Boolean:** `true`, `false`.
- **Character (`Char`):** Single-quoted: `'a'`, `'\n'`, `'\t'`, `'\\'`, `'\''`, `'\0'`.
- **String (`String`):** Double-quoted: `"Hello, World!"` (with escapes `\n`, `\t`, `\"`, `\\`, `\r`) and interpolated strings `$"Score: {score}"`.

### 2.3 Operators and Punctuation
- **Assignment:** `:=` and compound `+=`, `-=`, `*=`, `/=`, `%=`, `mod=`, `&=`, `|=`, `^=`, `<<=`, `>>=`
- **Relational Operators:** `=` (equal), `<>` (not equal), `<`, `<=`, `>`, `>=`
- **Arithmetic Operators:** `+`, `-`, `*`, `/`, `div`, `mod`
- **Logical & Bitwise Operators:** `and`, `or`, `xor`, `not`, `shl`, `shr`, `implies`, `in`
- **Punctuation:** `;`, `:`, `,`, `.`, `..`, `(`, `)`, `[`, `]`, `<`, `>`, `@`, `^`, `?`
- **Wildcard / Discard:** `_`

### 2.4 Comments
- Single-line: `// Comment until end of line` (and `///` for doc comments)
- Multi-line block: `{ Pascal block comment }` or `/* C-style comment */`

---

## 3. Formal Grammar (EBNF)

### 3.1 File & Module Structure
```ebnf
SourceFile    ::= ModuleDecl ( ProgramDecl | UnitDecl | LibraryBody )
ModuleDecl    ::= "module" Identifier ";" { ImportDecl }
ImportDecl    ::= "import" [ "c" | "pascal" | "link" ] ModulePath [ "as" Identifier ] ";"

UnitDecl      ::= "interface" { TopLevelDecl }
                  "implementation" { TopLevelDecl }
                  [ "initialization" { Statement ";" } ]
                  [ "finalization" { Statement ";" } ]
                  "end" Identifier "."

LibraryBody   ::= { TopLevelDecl }
ProgramDecl   ::= "program" Identifier ";" { TopLevelDecl } Block Identifier "."

TopLevelDecl  ::= ConstDecl | TypeDecl | VarSection | FuncDecl | ProcDecl | TraitDecl | ImplDecl
```

### 3.2 Type Declarations
```ebnf
TypeDecl      ::= "type" { [ DeriveAttr ] Identifier "=" TypeDef ";" }
TypeDef       ::= RecordDef | EnumDef | ArrayDef | SetDef | SubrangeDef | PointerDef | AliasDef

RecordDef     ::= "record" { [ "pub" | "priv" ] Identifier ":" TypeRef ";" } "end" "record"
EnumDef       ::= "enum" EnumVariant { "," EnumVariant } "end" "enum"
                | "(" EnumVariant { "," EnumVariant } ")"
EnumVariant   ::= Identifier [ "(" FieldList ")" ]
FieldList     ::= FieldDef { "," FieldDef }
FieldDef      ::= Identifier ":" TypeRef

AliasDef      ::= TypeRef
TypeRef       ::= Identifier [ "<" TypeRefList ">" ]
TypeRefList   ::= TypeRef { "," TypeRef }
```

### 3.3 Functions, Procedures, Signatures & Contracts
```ebnf
FuncDecl      ::= "function" Identifier "(" [ ParamList ] ")" "return" TypeRef "is"
                  [ ContractBlock ]
                  [ VarSection ]
                  Block Identifier ";"

ProcDecl      ::= "procedure" Identifier [ "(" [ ParamList ] ")" ] "is"
                  [ ContractBlock ]
                  [ VarSection ]
                  Block Identifier ";"

ParamList     ::= ParamDef { ";" ParamDef }
ParamDef      ::= [ "take" | "borrow" | "mut borrow" ] Identifier { "," Identifier } ":" TypeRef

ContractBlock ::= "contract" [ RequireClause ] [ EnsureClause ]
RequireClause ::= "require" { Expr ";" }
EnsureClause  ::= "ensure"  { Expr ";" }

VarSection    ::= ( "var" | "let" ) { VarDecl ";" }
VarDecl       ::= Identifier { "," Identifier } [ ":" TypeRef ] [ ":=" Expr ]
```

### 3.4 Blocks and Control-Flow Statements
```ebnf
Block         ::= "begin" { Statement ";" } "end"

Statement     ::= Assignment
                | LocalDecl
                | IfStmt
                | WhileStmt
                | RepeatStmt
                | ForStmt
                | MatchStmt
                | TryStmt
                | UnsafeStmt
                | AsmStmt
                | DeferStmt
                | ReturnStmt
                | FuncCall

Assignment    ::= LValue ":=" Expr
LocalDecl     ::= ( "let" | "var" ) Identifier [ ":" TypeRef ] ":=" Expr
ReturnStmt    ::= "return" [ Expr ]

IfStmt        ::= "if" Expr "then" { Statement ";" }
                  { "else" "if" Expr "then" { Statement ";" } }
                  [ "else" { Statement ";" } ]
                  "end" "if"

WhileStmt     ::= "while" Expr "do" { Statement ";" } "end" "while"
RepeatStmt    ::= "repeat" { Statement ";" } "until" Expr
ForStmt       ::= "for" Identifier ":=" Expr ( "to" | "downto" ) Expr "do" { Statement ";" } "end" "for"
                | "for" Identifier "in" Expr "do" { Statement ";" } "end" "for"

MatchStmt     ::= "match" Expr ( "do" | "with" )
                      { [ "case" ] PatternList ( "=>" | ":" ) { Statement ";" } }
                  "end" "match"

TryStmt       ::= "try" { Statement ";" } "except" { Statement ";" } "end" "try"
UnsafeStmt    ::= "unsafe" { Statement ";" } "end" "unsafe"
```

### 3.5 Expressions, Calls, and UFCS
```ebnf
Expr          ::= LogicalExpr
LogicalExpr   ::= RelationalExpr { ( "and" | "or" | "xor" | "implies" ) RelationalExpr }
RelationalExpr::= AdditiveExpr [ ( "=" | "<>" | "<" | "<=" | ">" | ">=" | "in" ) AdditiveExpr ]
AdditiveExpr  ::= MultiplicativeExpr { ( "+" | "-" ) MultiplicativeExpr }
MultiplicativeExpr ::= UnaryExpr { ( "*" | "/" | "div" | "mod" | "shl" | "shr" ) UnaryExpr }
UnaryExpr     ::= [ "-" | "not" | "@" ] PrimaryExpr [ "^" | "?" ]

PrimaryExpr   ::= Literal
                | Identifier [ "." Identifier [ "(" [ CallArgList ] ")" ] ]
                | RecordInstantiation
                | FuncCall
                | "if" Expr "then" Expr "else" Expr
                | "(" Expr ")"

RecordInstantiation ::= Identifier "(" [ ArgList ] ")"
FuncCall      ::= Identifier "(" [ CallArgList ] ")"
CallArgList   ::= CallArg { "," CallArg }
CallArg       ::= [ "take" | "borrow" | "mut borrow" ] Expr
```

---

## 4. Type System and Memory Semantics

### 4.1 Primitive Types
- Signed Integers: `Int8`, `Int16`, `Int32`, `Int64`
- Unsigned Integers: `UInt8`, `UInt16`, `UInt32`, `UInt64`
- Floating-Point: `Float32`, `Float64`
- Boolean: `Bool` (`true` or `false`)
- Text: `Char` and `String` (managed/deterministic memory)
- Empty / Unit: `Void`

### 4.2 Built-In Monadic Types
- `Option<T>`:
  - `Some(val: T)`
  - `None`
- `Result<T, E>`:
  - `Ok(val: T)`
  - `Err(err: E)`

### 4.3 Ownership & Borrowing Rules

1. **Single Ownership:** Each heap-managed or linear value belongs to one owner variable in scope.
2. **Move (`take`):** Passing a value with `take` transfers ownership to the callee; further use in the caller triggers compile error `E0382`.
3. **Immutable Borrow (`borrow`):** Multiple concurrent shared read-only borrows are permitted.
4. **Mutable Borrow (`mut borrow`):** Exclusive mutable borrow; no other read or write borrow may overlap.
5. **Call-Site Annotations:** When a signature uses explicit `take` or `mut borrow`, callers explicitly annotate ownership transfer or mutation (`take var_name`, `mut borrow var_name`).

---

## 5. First-Class Interoperability (Pascal & C FFI)

Aether integrates natively with Free Pascal units and C99 headers with **Zero-Boilerplate** auto-import:

### 5.1 Importing Free Pascal Units (`import pascal`)
Consume any unit from the Free Pascal or Lazarus ecosystem (`SysUtils`, `Classes`, `DateUtils`, `Math`, etc.):

```pascal
module PascalExample;

import pascal SysUtils;
import pascal DateUtils;

program Main;
var
    t: UInt64;
begin
    // Direct call without manual extern declarations:
    t := GetTickCount64();
    PrintLn("System tick: %d", t);
end PascalExample.
```

### 5.2 Importing C Headers and Libraries (`import c`)
Include standard C library headers or third-party C libraries directly:

```pascal
module CExample;

import c "<math.h>";
import link "-lm";

program Main;
var
    root_val: Float64;
begin
    root_val := sqrt(25.0);
    PrintLn("Square root of 25.0 = %f", root_val);
end CExample.
```

---

## 6. Traits and Static Polymorphism

Aether favors composition over inheritance using **Traits** and decoupled implementations (`impl ... for ...`) with compile-time static dispatch (*Zero-Cost Abstractions*):

```pascal
module TraitsExample;

trait Printable
    function Describe(borrow self) return String;
end trait;

type
    Circle = record
        radius: Int32;
    end record;

impl Printable for Circle
    function Describe(borrow self) return String is
    begin
        return "Geometric Circle";
    end Describe;
end impl;

// Static polymorphism with trait bound:
procedure DisplayElement<T: Printable>(borrow item: T) is
begin
    PrintLn("Element: %s", item.Describe());
end DisplayElement;
```

---

## 7. OS Networking and Socket Layer (`std/net.aeth`)

Real OS-level sockets built into both compiler backends:
- **Object Pascal Backend:** Uses FPC's native `Sockets` unit (`fpsocket`, `fpbind`, `fplisten`, `fpaccept`, `fpconnect`, `fpsend`, `fprecv`).
- **C99 Backend:** Uses `WinSock2` (`<winsock2.h>`) on Windows and POSIX BSD sockets on Linux/macOS.
- Built-in HTTP server and zero-copy request parser in `std/net.aeth`.

---

## 8. Unit Emission for BlaiseVue (`aetherc emit pascal --unit`)

When transpiled in unit mode:
1. Emits `unit <ModuleName>;` in `<ModuleName>.pas`.
2. Publicly exports record types, enums, function signatures, and monadic helpers in `interface`.
3. Isolates implementations in `implementation`.
4. Ready for immediate import in Free Pascal and BlaiseVue via `uses <ModuleName>;`.

---

## 9. Low-Level Access & Intel Inline Assembly (`asm ... end asm;`)

Aether supports hardware-level access via **Intel-Syntax Inline Assembly** blocks:

```aether
asm
    mov eax, 42
    add eax, 8
    rdtsc
    nop
end asm;
```

### 9.1 Dual-Backend Parity
- **Free Pascal Backend:** Emits `{$ASMMODE INTEL}` with FPC's native `asm ... end;` block.
- **C99 / GCC Backend:** Emits GNU `.intel_syntax noprefix` / `.att_syntax prefix` inline assembly:
  ```c
  __asm__ volatile (
      ".intel_syntax noprefix\n\t"
      "mov eax, 42\n\t"
      "add eax, 8\n\t"
      "rdtsc\n\t"
      "nop\n\t"
      ".att_syntax prefix"
  );
  ```
- **Zero Mismatch:** The exact same assembly code compiles cleanly under both FPC and GCC.

---

## 10. Automatic Derive Metaprogramming (`[derive(...)]`)

Aether automatically synthesizes common trait methods for `record` and `enum` types via `[derive(...)]`:

```aether
type
    [derive(Debug, JSON, Clone, Equals)]
    Point = record
        x: Float64;
        y: Float64;
    end record;

    [derive(Debug, JSON, Clone, Equals)]
    Status = enum
        Pending,
        Processing,
        Completed
    end enum;
```

### 10.1 Automatically Synthesized Traits
- **`Debug`**: Generates `ToString(borrow self) return String` (`Type { field1: val1, ... }` or `Enum.Variant`).
- **`JSON`**: Generates `ToJSON(borrow self) return String` and `FromJSON(borrow json: String) return Self`.
- **`Clone`**: Generates `Clone(borrow self) return Self` for explicit duplication under borrow checking.
- **`Equals`**: Generates `Equals(borrow self, other: borrow Self) return Bool` for recursive structural equality.

Generated methods work naturally via UFCS:
```aether
var p1: Point;
var p2: Point;
p1 := Point(10.5, 20.25);
PrintLn("%s", p1.ToString()); // "Point { x: 10.5, y: 20.25 }"
PrintLn("%s", p1.ToJSON());   // "{"x": 10.5, "y": 20.25}"
p2 := p1.Clone();
if p1.Equals(borrow p2) then
    PrintLn("Equal!");
end if;
```
