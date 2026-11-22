# Especificação Formal da Linguagem Aether (AetherLang)

> **"A clareza, estrutura e disciplina do Object Pascal com a segurança estrita de memória e expressividade moderna do Rust."**

---

## 1. Visão Geral e Princípios Fundamentais

**Aether** é uma linguagem de programação compilada para sistemas, fortemente e estaticamente tipada, com gerenciamento determinístico de memória sem coletor de lixo (*garbage collector*). Os pilares da linguagem são:

1. **Orientação a Objetos Moderna (UFCS - Uniform Function Call Syntax):**
   - Dados puros em `record` e variantes em `enum` (ADTs).
   - Sem herança frágil de classes nem tabelas virtuais pesadas.
   - Qualquer função cujo primeiro parâmetro seja `borrow T`, `mut borrow T` ou `take T` pode ser chamada tanto no estilo funcional (`Inspecionar(borrow buf)`) quanto no estilo orientado a objeto (`buf.Inspecionar()`).
2. **Determinismo Sintático:** Gramática sem ambiguidades, ideal para leitura humana, manutenção e geração/análise precisa por Inteligências Artificiais.
3. **Segurança de Memória Estática (Ownership & Borrowing):** Verificação de ciclo de vida e posse em tempo de compilação. Eliminação garantida de ponteiros nulos (*null dereference*), uso após liberação (*use-after-free*) e concorrência insegura (*data races*).
4. **Contratos Nativos:** Pré-condições (`require`) e pós-condições (`ensure`) integradas diretamente na sintaxe da função (estilo Ada/Eiffel), verificadas em tempo de compilação e/ou execução.
5. **Tratamento de Erros Monádico e Exaustivo:** Tipos algébricos nativos `Result<T, E>` e `Option<T>` com correspondência exaustiva de padrões (`match`).
6. **Estrutura Disciplinada:** Palavras-chave explícitas (`module`, `contract`, `begin...end`, `if...then...else...end`, `type`, `record`, `enum`) em vez de chaves ou símbolos crípticos.

---

## 2. Elementos Léxicos (Lexer)

### 2.1 Identificadores e Palavras-chave
- **Identificadores:** Iniciam com letra (`a-z`, `A-Z`) ou sublinhado (`_`), seguidos por letras, dígitos (`0-9`) ou sublinhados. Sensível a maiúsculas/minúsculas (*case-sensitive*), adotando `PascalCase` para tipos e módulos, `camelCase` ou `snake_case` para variáveis/funções.
- **Palavras-chave Reservadas:**
  ```text
  and, as, asm, begin, borrow, case, contract, do, else, end, ensure,
  enum, false, for, function, if, implies, import, in, let, match,
  module, mut, not, or, program, record, require, return,
  take, then, true, type, var, while
  ```

### 2.2 Literais
- **Inteiros:** Decimais (`42`, `100_000`), Hexadecimais (`$FF` ou `0xFF`), Binários (`%1010` ou `0b1010`).
- **Ponto Flutuante:** `3.14159`, `1.0e-5`.
- **Booleano:** `true`, `false`.
- **Caractere (`Char`):** Entre aspas simples: `'a'`, `'\n'`, `'\t'`, `'\\'`, `'\''`.
- **String (`String`):** Entre aspas duplas: `"Olá, Mundo!"`, com escapes padrão (`\n`, `\t`, `\"`, `\\`).

### 2.3 Operadores e Pontuação
- **Atribuição:** `:=`
- **Operadores Relacionais:** `=` (igual), `<>` (diferente), `<`, `<=`, `>`, `>=`
- **Operadores Aritméticos:** `+`, `-`, `*`, `/`, `mod`
- **Operadores Lógicos:** `and`, `or`, `not`, `implies`
- **Pontuação:** `;`, `:`, `,`, `.`, `(`, `)`, `[`, `]`, `<` e `>` (para tipos genéricos)
- **Coringa / Descarte:** `_`

### 2.4 Comentários
- Linha única: `// Comentário até o final da linha`
- Bloco multilinha: `{ Comentário em bloco Pascal }` ou `/* Comentário estilo C */`

---

## 3. Gramática Formal (EBNF)

### 3.1 Estrutura do Arquivo e Módulos
```ebnf
SourceFile    ::= ModuleDecl ( ProgramDecl | LibraryBody )
ModuleDecl    ::= "module" Identifier ";" { ImportDecl }
ImportDecl    ::= "import" Identifier [ "as" Identifier ] ";"

LibraryBody   ::= { TopLevelDecl }
ProgramDecl   ::= "program" Identifier ";" { TopLevelDecl } Block "."

TopLevelDecl  ::= TypeDecl | FuncDecl
```

### 3.2 Declaração de Tipos
```ebnf
TypeDecl      ::= "type" { Identifier "=" TypeDef ";" }
TypeDef       ::= RecordDef | EnumDef | AliasDef

RecordDef     ::= "record" { Identifier ":" TypeRef ";" } "end"
EnumDef       ::= "enum" EnumVariant { "," EnumVariant } "end"
EnumVariant   ::= Identifier [ "(" FieldList ")" ]
FieldList     ::= FieldDef { "," FieldDef }
FieldDef      ::= Identifier ":" TypeRef

AliasDef      ::= TypeRef
TypeRef       ::= Identifier [ "<" TypeRefList ">" ]
TypeRefList   ::= TypeRef { "," TypeRef }
```

### 3.3 Funções, Assinaturas e Contratos
```ebnf
FuncDecl      ::= "function" Identifier "(" [ ParamList ] ")" ":" TypeRef
                  [ ContractBlock ]
                  [ VarSection ]
                  Block ";"

ParamList     ::= ParamDef { ";" ParamDef }
ParamDef      ::= OwnershipModifier Identifier ":" TypeRef
OwnershipModifier ::= "take" | "borrow" | "mut borrow"

ContractBlock ::= "contract" [ RequireClause ] [ EnsureClause ]
RequireClause ::= "require" { Expr ";" }
EnsureClause  ::= "ensure"  { Expr ";" }

VarSection    ::= ( "var" | "let" ) { VarDecl ";" }
VarDecl       ::= Identifier ":" TypeRef [ ":=" Expr ]
```

### 3.4 Blocos e Instruções de Controle
```ebnf
Block         ::= "begin" { Statement ";" } "end"

Statement     ::= Assignment
                | LocalDecl
                | IfStmt
                | WhileStmt
                | ForStmt
                | MatchStmt
                | ReturnStmt
                | FuncCall

Assignment    ::= Identifier [ "." Identifier ] ":=" Expr
LocalDecl     ::= ( "let" | "var" ) Identifier [ ":" TypeRef ] ":=" Expr
ReturnStmt    ::= "return" [ Expr ]

IfStmt        ::= "if" Expr "then"
                      { Statement ";" }
                  [ "else"
                      { Statement ";" } ]
                  "end"

WhileStmt     ::= "while" Expr "do"
                      { Statement ";" }
                  "end"

ForStmt       ::= "for" Identifier "in" Expr "do"
                      { Statement ";" }
                  "end"

MatchStmt     ::= "match" Expr "do"
                      { "case" Pattern ":" { Statement ";" } }
                  "end"

Pattern       ::= Literal
                | Identifier [ "." Identifier ] [ "(" PatternArgs ")" ]
                | "_"
PatternArgs   ::= PatternArg { "," PatternArg }
PatternArg    ::= [ "let" ] Identifier | "_"
```

### 3.5 Expressões, Chamadas e UFCS
```ebnf
Expr          ::= LogicalExpr
LogicalExpr   ::= RelationalExpr { ( "and" | "or" | "implies" ) RelationalExpr }
RelationalExpr::= AdditiveExpr [ ( "=" | "<>" | "<" | "<=" | ">" | ">=" ) AdditiveExpr ]
AdditiveExpr  ::= MultiplicativeExpr { ( "+" | "-" ) MultiplicativeExpr }
MultiplicativeExpr ::= UnaryExpr { ( "*" | "/" | "mod" ) UnaryExpr }
UnaryExpr     ::= [ "-" | "not" ] PrimaryExpr

PrimaryExpr   ::= Literal
                | Identifier [ "." Identifier [ "(" [ CallArgList ] ")" ] ]
                | RecordInstantiation
                | FuncCall
                | "(" Expr ")"

RecordInstantiation ::= Identifier "(" [ ArgList ] ")"
FuncCall      ::= Identifier "(" [ CallArgList ] ")"
CallArgList   ::= CallArg { "," CallArg }
CallArg       ::= [ "take" | "borrow" | "mut borrow" ] Expr
```

---

## 4. Sistema de Tipos e Semântica de Memória

### 4.1 Tipos Primitivos
- Inteiros com sinal: `Int8`, `Int16`, `Int32`, `Int64`
- Inteiros sem sinal: `UInt8`, `UInt16`, `UInt32`, `UInt64`
- Ponto Flutuante: `Float32`, `Float64`
- Booleano: `Bool` (`true` ou `false`)
- Texto: `Char` (caractere Unicode UTF-8) e `String` (string imutável ou buffer dinâmico gerenciado)
- Vazio / Ausente: `Void`

### 4.2 Tipos Monádicos Padronizados
- `Option<T>`:
  - `Option.Some(val: T)`
  - `Option.None`
- `Result<T, E>`:
  - `Result.Ok(val: T)` (ou atalho `Ok(val)`)
  - `Result.Err(err: E)` (ou atalho `Err(err)`)

### 4.3 Regras de Posse (*Ownership & Borrowing*)

1. **Posse Única (*Single Owner*):** Cada valor na memória pertence a uma única variável no escopo.
2. **Movimentação (`take`):** Ao passar um valor por `take`, a posse é transferida definitivamente para a função chamada. O chamador não pode mais ler nem escrever nessa variável (erro `E0382`).
3. **Empréstimo Imutável (`borrow`):** Vários empréstimos simultâneos de apenas leitura são permitidos. Nenhuma alteração é possível durante o empréstimo.
4. **Empréstimo Mutável (`mut borrow`):** Apenas um empréstimo mutável exclusivo é permitido por vez no escopo. Nenhum outro empréstimo (leitura ou escrita) pode coexistir simultaneamente.
5. **Verificação no Ponto de Chamada (*Call-Site*):**
   - O chamador deve anotar explicitamente:
     - `take variavel`
     - `borrow variavel`
     - `mut borrow variavel`

---

## 5. Interoperabilidade de Primeira Classe (Pascal & C FFI)

O Aether possui interoperabilidade nativa e transparente com bibliotecas do Free Pascal e cabeçalhos C99 com **Zero-Boilerplate** (sem necessidade de escrever declarações manuais de `extern`).

### 5.1 Importação de Units do Free Pascal (`import pascal`)
Permite consumir qualquer Unit do ecossistema Free Pascal ou Lazarus (`SysUtils`, `Classes`, `DateUtils`, `Math`, etc.):

```pascal
module ExemploPascal;

import pascal SysUtils;
import pascal DateUtils;

program Main;
var
    t: UInt64;
begin
    // Chamada direta sem nenhum 'extern' manual:
    t := GetTickCount64();
    PrintLn("Tick do sistema: %d", t);
end.
```

### 5.2 Importação de Headers e Bibliotecas C (`import c`)
Permite incluir headers da biblioteca padrão C ou bibliotecas nativas:

```pascal
module ExemploC;

import c "<math.h>";
import link "-lm";

program Main;
var
    raiz: Float64;
begin
    raiz := sqrt(25.0);
    PrintLn("Raiz quadrada de 25.0 = %f", raiz);
end.
```

---

## 6. Traits e Polimorfismo Estático

O Aether adota composição sobre herança via **Traits** e implementação desacoplada (`impl ... for ...`), com despacho estático em tempo de compilação (*Zero-Cost Abstractions*):

```pascal
module ExemploTraits;

trait Printable
    function Descrever(borrow self: Self): String;
end;

type
    Circulo = record
        raio: Int32;
    end;

impl Printable for Circulo
    function Descrever(borrow self: Circulo): String
    begin
        return "Circulo Geometrico";
    end;
end;

// Polimorfismo Estatico com Trait Bound:
function ExibirElemento<T: Printable>(borrow item: T): Void
begin
    PrintLn("Elemento: %s", item.Descrever());
end;
```

---

## 7. Camada de Rede e Sockets do Sistema Operacional (`std/net.aeth`)

Sockets nativos reais integrados no compilador com paridade total nos dois backends:
- **Backend Object Pascal:** Utiliza a unit `Sockets` nativa do FPC (`fpsocket`, `fpbind`, `fplisten`, `fpaccept`, `fpconnect`, `fpsend`, `fprecv`).
- **Backend C99:** Utiliza a API `WinSock2` (`<winsock2.h>`) no Windows e BSD sockets POSIX no Linux/macOS.
- Servidor HTTP e parser de requisições de alta performance nativos em `std/net.aeth`.

---

## 8. Emissão de Units para BlaiseVue (`aetherc emit pascal --unit`)

Quando transpilado no modo unit:
1. Gera `unit <NomeDoModulo>;` no arquivo `<NomeDoModulo>.pas`.
2. Exporta publicamente na seção `interface` todos os tipos de records, enums, assinaturas de funções e helpers monádicos.
3. Isola corpos e despachos na seção `implementation`.
4. Permite consumo imediato no Free Pascal e no ecossistema BlaiseVue via cláusula `uses <NomeDoModulo>;`.

---

## 9. Acesso a Baixo Nível e Inline Assembly Intel (`asm ... end;`)

O Aether oferece controle total de hardware através de blocos nativos de **Inline Assembly em Sintaxe Intel (`Intel Syntax`)**:

```aether
asm
    mov eax, 42
    add eax, 8
    rdtsc
    nop
end;
```

### 9.1 Paridade Total Dual-Backend
- **Backend Free Pascal:**
  Emite diretamente a diretiva nativa `{$ASMMODE INTEL}` com o bloco `asm ... end;` do FPC.
- **Backend C99 / GCC:**
  Emite instruções envelopadas na diretiva GNU `.intel_syntax noprefix` / `.att_syntax prefix`:
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
- **Zero Incompatibilidade:** O mesmo código assembly é compilado sem modificações tanto pelo FPC quanto pelo GCC.
- **Segurança e Isolamento:** Instruções assembly são aceitas dentro de blocos de funções ou programas, permitindo otimizações SIMD/AVX, leitura de contadores de ciclo de CPU (`rdtsc`) e chamadas de interrupções de baixo nível.
