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

### ✅ Fase 13: Validação Canônica de Módulos e Namespaces Hierárquicos (Concluído)
- [x] **Validação Estrita de Módulo 1:1 (Pascal/Java-style)**: O nome declarado em `module <Nome>;` DEVE coincidir obrigatoriamente com o nome do arquivo `<Nome>.aeth` no disco (Erro `E0005` caso haja divergência, com validação de arquivos fonte e módulos importados).
- [x] **Namespaces Hierárquicos**: Suporte a módulos em subdiretórios com notação de ponto (ex: `import Compiler.Aeth.Tokens;` buscando automaticamente `compiler/aeth/tokens.aeth` no projeto ou em `std/`).
- [x] **Alinhamento Canônico Oficial**: Todos os arquivos de exemplo (`examples/01` a `10`) e módulos do compilador auto-hospedado (`compiler/aeth/`) atualizados para a nomenclatura canônica 1:1.
- [x] **Validação Dual-Backend**: Exemplo `examples/10_hierarchical_modules.aeth` compilado e executado com 100% de paridade em Free Pascal e GCC.

### ✅ Fase 14: Traits e Polimorfismo Estático (Contratos de Tipos) (Concluído)
- [x] **Declaração de `trait`**: Suporte à definição de contratos comportamentais via `trait Nome ... end;` no nível do módulo ou na seção `type` (ex: `trait Printable`, `trait Shape`).
- [x] **Implementação de Traits (`impl Trait for Type`)**: Implementação de blocos de métodos para records (ex: `impl Printable for Circle ... end;`), com inferência automática de tipo para o parâmetro `borrow self`.
- [x] **Verificação Semântica Rigorosa (Type-Level Contracts)**:
  - Validação de completude: emite `[Erro Semantico E0046]` caso o tipo não implemente todos os métodos exigidos pela trait.
  - Validação de assinaturas: emite `[Erro Semantico E0053]` se a quantidade de parâmetros, tipos ou retorno divergirem da definição da trait.
  - Verificação de Trait Bound: emite `[Erro Semantico E0277]` se uma função genérica com bound (ex: `<T: Printable>`) receber um tipo que não implementa a trait exigida.
- [x] **Despacho Estático (*Zero-Cost Abstractions*)**:
  - Resolução direta de chamadas estilo método via UFCS (`c.ToString()`, `c.Area()`) mapeadas estaticamente para `<Type>_<Method>` em tempo de compilação sem tabelas virtuais (vtable) nem overhead em runtime.
- [x] **Monomorfização Estática de Funções Genéricas com Trait Bounds**:
  - Funções genéricas parametrizadas (ex: `function ExibirElemento<T: Printable>(borrow item: T)`) são monomorfizadas e especializadas estaticamente para cada tipo concreto invocado (ex: `ExibirElemento_Circle`), garantindo máxima otimização e performance de código nativo.
- [x] **Validação Dual-Backend e Testes**: Exemplo completo `examples/11_traits_and_polymorphism.aeth` compilado e validado com 100% de paridade e sucesso nos backends Free Pascal e GCC (MSYS2).

### ✅ Fase 15: Gerenciador de Pacotes e Dependências (`aether add` / `aether test`) (Concluído)
- [x] **Suporte a Dependências no Manifesto `aether.json`**:
  - Seção `"dependencies"` para pacotes locais via `path` (ex: `"math_extra": { "path": "libs/math_extra" }`), git (`"git": "https://..."`) e versões semânticas.
- [x] **Comando CLI `aetherc add <pacote>`**:
  - Adição automática de dependências no manifesto `aether.json` com suporte a `--path=...`, `--git=...` e `--version=...`.
  - Preparação e sincronização com cache global (`~/.aether/cache/<pkg>`) e dependências do projeto.
- [x] **Resolução Inteligente de Módulos de Dependências**:
  - `FindModuleFile` estendido para resolver módulos de dependências declaradas no manifesto em múltiplos níveis (`<dep>/`, `<dep>/src/`, busca em camelCase/snake_case e cache global).
- [x] **Test Runner Nativo Integrado (`aetherc test`)**:
  - Execução automatizada de testes unitários na pasta `tests/` com suporte a filtros (ex: `aetherc test math`), medição de latência em milissegundos e status detalhado (`PASS` / `FAIL`).
  - Suporte completo a ambos os backends (`--target=pascal` e `--target=c`).
- [x] **Validação Prática**: Projeto modelo e testes criados e validados em `examples/12_package_manager_and_tests/` com execução bem-sucedida de `run` e `test` em Free Pascal e GCC.

---

### ⏳ Fase 16: Expansão do Compilador Auto-Hospedado (`compiler/aeth/`) para Paridade Total
- [ ] **Type Checker Nativo em Aether (`compiler/aeth/typechecker.aeth`)**:
  - Implementação da validação de tipos, verificação de compatibilidade, checagem de tipos estáticos e UFCS escrita diretamente em código Aether.
- [ ] **Borrow Checker Nativo em Aether (`compiler/aeth/borrowchecker.aeth`)**:
  - Algoritmo de análise de fluxo e verificação de posse (`own`, `borrow`, `mut borrow`) para validação de segurança de memória em código Aether.
- [ ] **Emissão de Código Completa para C99 (`compiler/aeth/emitter.aeth`)**:
  - Suporte completo no emissor auto-hospedado para records, enums com payload, pattern matching (`match`), traits/impl e funções monomorfizadas.
- [ ] **Self-Hosting Completo (Bootstrap Total)**:
  - Capacidade do compilador `compiler/aeth/main.aeth` de compilar a si mesmo através do backend C99/GCC gerando um executável nativo autônomo sem dependência do compilador bootstrap em Pascal.

### ⏳ Fase 17: Expansão da Biblioteca Padrão (`std/`) e Concorrência Ultraleve
- [ ] **Networking (`std/net.aeth`)**:
  - Sockets TCP/UDP e cliente HTTP básico com tratamento idiomático de erros usando `Result<T, E>`.
- [ ] **Serialização e Parser JSON (`std/json.aeth`)**:
  - Parser e gerador JSON rápido e tipado nativamente em Aether com segurança de memória.
- [ ] **Concorrência Ultraleve e Primitivas de Sincronização (`std/sync.aeth` / `std/threads.aeth`)**:
  - **Arquitetura de Alto Desempenho sem Garbage Collector**:
    - **Thread Pool com Work-Stealing (estilo Rayon do Rust)**: Pool de threads fixo dimensionado pelo número de núcleos da CPU (`N`), permitindo o disparo de milhões de micro-tarefas (`Task.Run`, `Parallel.For`) armazenadas em fila de memória RAM ultraleve, sem o custo de criar threads de SO para cada operação.
    - **Sincronização Zero-Cost**: `Mutex<T>` tipado e canais assíncronos (`Channel<T>` / MPSC) com mapeamento direto para primitivas rápidas do sistema operacional (`SRWLock` no Windows, `futex` no Linux) sem overhead de runtime.
    - **Segurança Estática contra Data Races**: Aplicação rigorosa das regras de posse (`take`) e empréstimo (`Aliasing XOR Mutability`) impedindo acesso concorrente não sincronizado em tempo de compilação.
    - **Concorrência Assíncrona para I/O**: Base para tarefas cooperativas e event loop (IOCP no Windows / epoll no Linux) para suporte a dezenas de milhares de conexões de rede simultâneas com consumo mínimo de memória.

### ⏳ Fase 18: Polimento de Ferramentas de Desenvolvimento (LSP & Extensão VS Code)
- [ ] **Aprimoramento do LSP (`compiler/src/uAetherLSP.pas`)**:
  - Suporte a autocompletion de métodos estáticos e dinâmicos via UFCS e traits implementadas.
  - Hover de documentação e tipos inferidos em tempo real.
- [ ] **Extensão Oficial para VS Code (`ide/vscode/`)**:
  - Destaque sintático completo para as novas palavras-chave (`trait`, `impl`, `own`, `borrow`, `mut`).
  - Integração do explorador de testes do VS Code com o comando `aetherc test`.

### ⏳ Fase 19: Suporte a Dependências Git no `aether add`
- [ ] **Download e Cache Automático via Git**:
  - `aetherc add <url-git> [--branch=... / --tag=...]` executando clone ou checkout automático para o cache global (`~/.aether/cache/<pkg>`).
  - Resolução transparente de dependências aninhadas e versionamento semântico de pacotes remotos.
