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

### ✅ Fase 6: Interoperabilidade Externa (`extern` e `import pascal`) (Concluído)
- [x] Implementação da palavra-chave `extern function` para declarar funções C nativas (`puts`, `sqrt`, etc.).
- [x] Implementação de `import pascal <UnitName>` para inclusão direta de units do Free Pascal / Lazarus e pacotes do Boss na compilação.
- [x] Suporte à convenção de chamada C (`cdecl`) com vinculação dinâmica/estática (`msvcrt`/`libc`).
- [x] Suporte a contratos (`contract require / ensure`) em funções `extern`.

### ✅ Fase 7: Extensão Oficial do VS Code para Aether (`.aeth`) (Concluído)
- [x] Criação do pacote de extensão em `editors/vscode/` com realce de sintaxe (*Syntax Highlighting* TextMate).
- [x] Snippets completos para `module`, `contract`, `record`, `enum`, `match`, `extern`, `if`, etc.
- [x] Integração do diagnósticos JSON (`--emit-json-diagnostics`) com a aba *Problems* do VS Code e sugestões (*suggested fixes*).
- [x] Comandos integrados para compilar via backend Pascal e via backend C99 diretamente pelo editor.

### ✅ Fase 8: Biblioteca Padrão (`std/`) e Resolução de Módulos (Concluído)
- [x] Resolução automática e recursiva de `import <Modulo>` no compilador `aetherc` (busca local e em `std/`).
- [x] `std/math.aeth`: Constantes e funções matemáticas fundamentais (`Abs`, `Max`, `Min`, `Clamp`, `Pow`, `SqrtSafe`).
- [x] `std/strings.aeth`: Manipulação e validação de texto (`IsEmpty`, `Equals`, `PrintMessage`).
- [x] `std/io.aeth`: Tipos e rotinas seguras de entrada/saída (`IOError`, `Informar`).
- [x] `std/collections.aeth`: Estrutura de dados com semântica de posse e métodos UFCS (`FixedBuffer`, `NewBuffer`, `IsFull`, `Available`, `PushItem`).

### ✅ Fase 9: LSP (Language Server Protocol) e IDE em Tempo Real (Concluído)
- [x] Implementação do servidor LSP oficial do Aether em `compiler/src/uAetherLSP.pas` sob a flag `aetherc --lsp`.
- [x] Protocolo JSON-RPC com cabeçalhos HTTP-like (`Content-Length: ...\r\n\r\n{...}`) em UTF-8 puro via `fpjson`.
- [x] Diagnósticos em tempo real (`textDocument/publishDiagnostics`) integrados com o Lexer, Parser, TypeChecker e Borrow Checker.
- [x] Autocompletar inteligente (`textDocument/completion`) com palavras-chave de posse (`borrow`, `take`, `mut`), tipos primitivos, mônades e símbolos locais da AST.
- [x] Dicas ao passar o cursor (`textDocument/hover`) documentando a semântica de empréstimo/posse e assinaturas de funções com contratos.
- [x] Ir para a Definição (`textDocument/definition`) localizando declarações de funções, records e enums no código fonte.
- [x] Integração cliente na extensão do VS Code / Antigravity IDE (`editors/vscode/extension.js`) atualizada para versão `0.9.0`.

---

### ✅ Fase 10: Developer Experience & Gerenciamento de Projetos (`init`, `build`, `run`) (Concluído)
- [x] Comando `aetherc init [nome]` / `aetherc new`: Criação de projetos estruturados com `aether.json`, `src/main.aeth`, `tests/`, `.gitignore` e `README.md`.
- [x] Manifesto de Projeto (`aether.json`): Configuração de nome, versão, ponto de entrada (`entry`), backend padrão (`pascal` ou `c`) e saída (`output`).
- [x] Comandos automáticos de compilação e execução: `aetherc build` e `aetherc run` com suporte a sobrescrita de backend (`--target=c`).
- [x] Integração com a extensão oficial do VS Code / Antigravity IDE (comandos na paleta para iniciar, compilar e rodar projetos).
- [x] Módulo nativo do projeto em Pascal (`compiler/src/uAetherProject.pas`).

---

## 🚀 Próximas Fases e Metas

### ✅ Fase 11: Maturidade de Linguagem para Auto-Hospedagem (Self-Hosting) (Concluído)
- [x] Suporte a `Box<T>` e `Option<Box<T>>`: ponteiro no heap com posse estrita para estruturas recursivas (nós de AST, árvores e listas).
- [x] Auto-dereferenciamento inteligente nos emissores Pascal (`^.` / `^`) e C99 (`->` / `*`) com detecção automática de alvos ponteiro.
- [x] Manipulação nativa de Strings: concatenação (`+`), comparação (`=`, `<>`), `Length(s)`, `CharAt(s, idx)` e `Substring(s, start, len)`.
- [x] I/O avançado na biblioteca padrão (`std/io.aeth`): `FileExists`, `ReadFile` e `WriteFile` com emissores nativos em FPC e GCC.
- [x] Coleções e construtores de strings (`std/collections.aeth`): `StringBuilder` (`NewStringBuilder`, `Append`, `ToString`) e buffers dinâmicos.
- [x] Validação completa de estruturas recursivas e I/O com os exemplos `08_box_and_recursion.aeth` e `09_std_io_and_collections.aeth`.

---

## 🚀 Próximas Fases e Metas

### ✅ Fase 12: O Compilador Aether Auto-Hospedado (`aetherc-core`) (Concluído)
- [x] Definição de Tokens oficiais nativos em `compiler/aeth/tokens.aeth`.
- [x] Analisador Léxico (Lexer) 100% nativo em Aether em `compiler/aeth/lexer.aeth`.
- [x] Árvore Sintática Abstrata (AST) nativa com nós recursivos via `Box` em `compiler/aeth/ast.aeth`.
- [x] Parser descendente recursivo nativo em Aether em `compiler/aeth/parser.aeth`.
- [x] Emissor C99 nativo em Aether em `compiler/aeth/emitter.aeth`.
- [x] Driver principal do compilador auto-hospedado em `compiler/aeth/main.aeth`.
- [x] Bootstrapping completo: Compilador Aether compilado pelo `aetherc` atual (`bin/aetherc_core.exe` e `bin/aetherc_core_c.exe`), capaz de ler, analisar e transpilar programas Aether (`01_hello_world.aeth`) para executáveis nativos via GCC.

---

## 🚀 Próximas Fases e Evolução do Ecossistema

### 🎯 Fase 13: Validação Canônica de Módulos e Namespaces Hierárquicos
- [ ] **Regra Estrita de Módulo 1:1 (Pascal/Java-style)**: Garantir que a declaração `module <Nome>;` coincida obrigatoriamente com o nome do arquivo `<Nome>.aeth` (Erro `E0005: Nome do módulo "%s" difere do nome do arquivo "%s.aeth"`).
- [ ] **Namespaces Hierárquicos**: Suporte a módulos organizados em subdiretórios com notação de ponto (ex: `import Compiler.Lexer;` mapeado automaticamente para `compiler/lexer.aeth`).
- [ ] **Controle de Visibilidade**: Palavra-chave `pub` (ou `export`) para controle granular de símbolos públicos vs. privados do módulo.

### 🎯 Fase 14: Traits, Interfaces Semânticas e Polimorfismo Estático
- [ ] Declaração de `trait` (ex: `trait Display`, `trait Clone`, `trait Printable`).
- [ ] Implementação de contratos de traits para records existentes (`impl Display for ASTExprNode`).
- [ ] Despacho estático (*zero-cost abstractions*) com monomorfização para ambos os backends (Object Pascal e C99).

### 🎯 Fase 15: Gerenciador de Pacotes e Dependências (`aether add` / `aether pkg`)
- [ ] Suporte a dependências remotas e locais no manifesto `aether.json` (estilo Cargo / Boss).
- [ ] Download, cache global (`~/.aether/cache`) e resolução de grafos de dependências de módulos.
- [ ] Comando `aetherc test` para execução automática de suítes de testes unitários.

### 🎯 Fase 16: Backend Nativo LLVM (Produção e Alta Performance)
- [ ] Geração direta de LLVM IR (`.ll`) como terceiro backend alternativo ao FPC e GCC.
- [ ] Otimizações nativas de vetorização (SIMD), inlining agressivo e eliminação de código morto (DCE).
- [ ] Geração de binários autônomos sem necessidade de toolchain externa instalada.
