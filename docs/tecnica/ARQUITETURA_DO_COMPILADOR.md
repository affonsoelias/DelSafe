# Arquitetura Interna do Compilador Aether (`aetherc`)

O compilador oficial do Aether (`aetherc`) foi implementado em **Free Pascal** como um compilador em pipeline de múltiplos estágios modulares.

---

## 1. Pipeline de Compilação

```text
  [ Código Fonte .aeth ]
           │
           ▼
  [ 1. Analisador Léxico (uAetherLexer) ] ────────► Emite Stream de Tokens (uAetherTokens)
           │
           ▼
  [ 2. Parser Descendente (uAetherParser) ] ─────► Constrói AST Tipada (uAetherAST)
           │
           ▼
  [ 3. Tabela de Símbolos & Type Checker ] ──────► Valida Escopos e Tipos (uAetherTypeChecker)
           │
           ▼
  [ 4. O Analisador de Posse (Borrow Checker) ] ─► Valida Regras de Posse (uAetherBorrowChecker)
           │
           ▼
  [ 5. Emissor de Código & Toolchain ]
           ├── Opção A (Padrão): Emissor Object Pascal (uAetherEmitterPascal) ──► Invoca FPC (.exe)
           └── Opção B (--target=c): Emissor C99 (uAetherEmitterC) ─────────────► Invoca GCC (.exe)
```

---

## 2. Visão dos Módulos Principais

### `uAetherTokens.pas`
Define a enumeração de tokens (`TTokenKind`), incluindo palavras-chave estruturais (`tokModule`, `tokContract`, `tokRecord`), de posse (`tokTake`, `tokBorrow`, `tokMut`), e operadores. Armazena rastreamento com precisão de linha e coluna.

### `uAetherLexer.pas`
Scanner com suporte a:
- Literais de texto (escapes `\n`, `\t`, `\"`);
- Literais numéricos (decimais, floats, hexadecimais `$FF`/`0x`, binários `%1010`/`0b`);
- Comentários de linha (`//`) e bloco (`{ ... }` e `/* ... */`).

### `uAetherAST.pas`
Hierarquia de nós da Árvore Sintática Abstrata:
- Declarações (`TASTModule`, `TASTRecordDecl`, `TASTEnumDecl`, `TASTFunction`, `TASTProgramBlock`);
- Instruções (`TASTAssignStmt`, `TASTIfStmt`, `TASTWhileStmt`, `TASTMatchStmt`, `TASTReturnStmt`);
- Expressões (`TASTLiteralExpr`, `TASTIdentifierExpr`, `TASTMemberAccessExpr`, `TASTBinaryExpr`, `TASTCallExpr`).

### `uAetherParser.pas`
Parser descendente recursivo (*hand-written recursive descent parser*) com suporte a tipos genéricos (`Result<T, E>`), casamento exaustivo de padrões (`match...do...case`), contratos nativos (`require` / `ensure`) e desaçucaramento de chamadas de método (*UFCS*).

### `uAetherSymbols.pas` & `uAetherTypeChecker.pas`
Gerencia tabela de símbolos em escopo léxico hierárquico, valida compatibilidade estrita de tipos, garante imutabilidade de variáveis declaradas com `let` e verifica exaustividade de variantes em `match`.

### `uAetherBorrowChecker.pas`
O analisador estático de ciclo de vida. Mantém o estado de cada variável (`vsOwned`, `vsMoved`, `vsBorrowedShared`, `vsBorrowedMut`), rastreia onde valores foram movidos via `take` e impede *Use-After-Move* e *Double-Move* com diagnósticos enriquecidos (`E0382`).

### `uAetherToolchain.pas`
Detecta o ambiente operacional com diretivas condicionais multiplataforma:
- **No Windows:** Detecta `fpc.exe` e GCC do MSYS2 UCRT64 (`C:\msys64\ucrt64\bin\gcc.exe`), ajustando o PATH automaticamente.
- **No Linux/macOS:** Detecta `fpc` e `gcc`/`clang` nativos do sistema.
- Executa a compilação e linkagem do binário final.
