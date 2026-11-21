# Roteiro e Planejamento de Desenvolvimento do Aether (`aetherc`)

Este documento traça o status oficial de desenvolvimento do compilador e as próximas metas de engenharia da linguagem **Aether**.

---

## 📌 Status Consolidado das Fases

### ✅ Fase 1: Arquitetura Base e Analisador Léxico/Sintático (Concluído)
- [x] Definição de Tokens oficiais em `uAetherTokens.pas`.
- [x] Analisador Léxico (Tokenizer com linhas, colunas, literais e comentários) em `uAetherLexer.pas`.
- [x] Árvore Sintática Abstrata (Nós de declarações, instruções e expressões) em `uAetherAST.pas`.
- [x] Parser Descendente Recursivo com suporte a genéricos e contratos em `uAetherParser.pas`.
- [x] Formatador visual de AST (`--dump-ast` no CLI).

### ✅ Fase 2: Tabela de Símbolos e Sistema de Tipos (Concluído)
- [x] Resolução de escopo léxico hierárquico em `uAetherSymbols.pas`.
- [x] Tipagem estática de primitivos, registros, enums algébricos e genéricos (`Result`/`Option`) em `uAetherTypeChecker.pas`.
- [x] Garantia de imutabilidade para variáveis declaradas com `let` (Erro `E0384`).
- [x] Verificação de exaustividade no `match` (Erro `E0004` com sugestão de variante ausente).

### ✅ Fase 3: O Analisador de Posse / Borrow Checker (Concluído)
- [x] Rastreamento de ciclo de vida de cada recurso em `uAetherBorrowChecker.pas`.
- [x] Semântica estrita de `take` com bloqueio de *Use-After-Move* e *Double-Move* (Erro `E0382`).
- [x] Semântica de empréstimo de leitura (`borrow`) e exclusividade mutável (`mut borrow` com Erro `E0502`).
- [x] Registro exato da linha e coluna onde a posse foi transferida.

### ✅ Fase 4: Emissores de Código e Executáveis Nativos (Concluído)
- [x] Diagnóstico automático de ferramentas no sistema (`aetherc --doctor`) com compilação condicional multiplataforma em `uAetherToolchain.pas`.
- [x] Emissor Object Pascal (`uAetherEmitterPascal.pas`) + Invocação automática do `fpc`.
- [x] Emissor C99 (`uAetherEmitterC.pas`) + Invocação automática do GCC (MSYS2 no Windows / nativo no Linux/macOS).
- [x] Orientação a objetos moderna via UFCS (`meu_buffer.Inspecionar()`).

### ✅ Fase 5: O Modo IA (JSON Diagnostics & Auto-Fix) (Concluído)
- [x] Implementação da flag `--emit-json-diagnostics` (`uAetherJSONDiag.pas`).
- [x] Schema padronizado de erro com intervalo de linha/coluna.
- [x] Contexto enriquecido (`moved_at`) e bloco de sugestão de autocorreção (`suggested_fix`).

---

## 🚀 Próximas Fases e Metas Futuras

### 🎯 Fase 6: Interoperabilidade Externa (`extern` e `import pascal`)
- [ ] Implementar a palavra-chave `extern function` para declarar funções de bibliotecas C (ex: `extern function sqrt(borrow x: Float64): Float64;`).
- [ ] Implementar `import pascal "UnitName"` para inclusão direta de units do Free Pascal / Lazarus e pacotes do Boss na compilação.
- [ ] Suporte a convenções de chamada (`cdecl`, `stdcall`).

### 🎯 Fase 7: Extensão Oficial do VS Code para Aether (`.aeth`)
- [ ] Criação do pacote de extensão com realce de sintaxe (*Syntax Highlighting* TextMate).
- [ ] Snippets para `module`, `contract`, `record`, `enum` e `match`.
- [ ] Integração do diagnósticos JSON com a aba *Problems* do VS Code.

### 🎯 Fase 8: Biblioteca Padrão (`std/`)
- [ ] `std/math.aeth`: Funções matemáticas fundamentais.
- [ ] `std/io.aeth`: Leitura e escrita de arquivos, buffers e streams.
- [ ] `std/strings.aeth`: Manipulação avançada de texto UTF-8.
- [ ] `std/collections.aeth`: Listas dinâmicas seguras (`List<T>`) e dicionários com semântica de posse.

### 🎯 Fase 9: LSP (Language Server Protocol)
- [ ] Servidor de linguagem básico para autocompletar, go-to-definition e diagnósticos em tempo real durante a digitação.
