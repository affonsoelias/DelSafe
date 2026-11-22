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

### ✅ Fase 16: Expansão do Compilador Auto-Hospedado (`compiler/aeth/`) para Paridade Total (Concluído)
- [x] **Type Checker Nativo em Aether (`compiler/aeth/typechecker.aeth`)**:
  - Implementação da validação semântica com tabela de símbolos nativa em Aether (`SymbolTable`), checagem de tipos em atribuições, controle de fluxo (`if`, `while`) e detecção de erros `E0001` (variável não declarada), `E0002` (incompatibilidade de tipos) e `E0003` (declaração duplicada).
- [x] **Borrow Checker Nativo em Aether (`compiler/aeth/borrowchecker.aeth`)**:
  - Rastreamento dos estados de posse (`osAvailable`, `osMoved`, `osBorrowed`, `osMutBorrowed`) e validação estática das regras de posse e empréstimo com detecção de `E0382` (uso após movimentação) e `E0502` (empréstimo conflitante).
- [x] **Expansão de AST, Parser e Emissor C99 (`ast.aeth`, `parser.aeth`, `emitter.aeth`)**:
  - Suporte a declaração de variáveis (`var`), controle de fluxo (`if/then/else`, `while/do`), expressões compostas, comparações mapeadas para C99 (`==`, `!=`) e concatenação de blocos de statements (`ParseBlock`, `AppendStmt`).
- [x] **Pipeline Completo Auto-Hospedado de 4 Fases (`compiler/aeth/main.aeth`)**:
  - Execução das 4 etapas (`[1/4] Lexer/Parser`, `[2/4] Type Checker`, `[3/4] Borrow Checker`, `[4/4] Emissor C99`) escritas 100% nativamente em código Aether.
- [x] **Validação Prática Dual-Backend**:
  - Compilador auto-hospedado compilado e executado com 100% de sucesso nos backends **Free Pascal** e **GCC (MSYS2)**, processando o novo exemplo de demonstração `examples/13_self_hosted_compiler_demo.aeth` e gerando binário nativo funcional.

### ✅ Fase 17: Expansão da Biblioteca Padrão (`std/`) e Concorrência Ultraleve (Concluído)
- [x] **Serialização e Parser JSON (`std/json.aeth`)**:
  - `JsonBuilder` com formatação e serialização estruturada (`AddString`, `AddInt`, `AddBool`, `Build`).
  - Extratores tipados zero-alocação com empréstimo mutável (`ExtractString`, `ExtractInt`, `ExtractBool`) e validação estrutural (`Validate`, `HasKey`, `FindSubstr`).
- [x] **Concorrência Ultraleve e Primitivas de Sincronização (`std/sync.aeth`)**:
  - `AtomicInt32` com operações atômicas seguras (`NewAtomic`, `AtomicLoad`, `AtomicStore`, `AtomicAdd`).
  - `Mutex` com controle de posse e reentrância de threads (`NewMutex`, `Lock`, `Unlock`, `IsLocked`).
  - `Channel` CSP com fila circular (ring buffer) de capacidade delimitada (`NewChannel`, `Send`, `Recv`, `IsChannelEmpty`, `IsChannelFull`, `CloseChannel`).
- [x] **Networking e Protocolos (`std/net.aeth`)**:
  - Abstração de sockets TCP (`Socket`, `NewSocket`, `Connect`, `SendData`, `CloseSocket`).
  - Construção e parsing de requisições e respostas HTTP (`BuildHttpRequest`, `ParseHttpResponse`, `HttpResponse`).
- [x] **Validação Prática Dual-Backend**:
  - Suíte de demonstração em `examples/14_stdlib_and_concurrency.aeth` compilada e executada com 100% de paridade nos backends **Free Pascal** e **GCC C99**, integrando typecastings primitivos e operadores `mod`/`div`.

### ✅ Fase 18: Polimento de Ferramentas de Desenvolvimento (LSP & Extensão VS Code) (Concluído)
- [x] **Aprimoramento do LSP (`compiler/src/uAetherLSP.pas`)**:
  - Autocompletion completo de palavras-chave (`trait`, `impl`, `for`, `own`, `borrow`, `mut`), tipos e mônades.
  - Exibição de assinaturas de funções com lista completa de parâmetros e modificadores de posse (`FormatFunctionSignature`).
  - Suporte a métodos de traits e extensões UFCS no autocompletion e go-to-definition.
  - Hover rico com formatação Markdown para funções, contratos (`require`/`ensure`), records com campos, enums com variantes, traits com métodos e variáveis locais/parâmetros.
  - Navegação Go-To-Definition para funções, records, enums, traits e métodos de impls.
  - Suporte ao subcomando direto `aetherc lsp` além de `aetherc --lsp`.
- [x] **Extensão Oficial para VS Code (`ide/vscode/`)**:
  - Destaque sintático completo (`syntaxes/aether.tmLanguage.json`) para keywords de posse, tipos, mônades, operadores e literais.
  - Configuração de linguagem (`language-configuration.json`) com pares de fechamento e regras de indentação inteligente (`begin..end`, `case`, `contract`, etc.).
  - Snippets de código (`snippets/aether.json`) para criação rápida de módulos, funções com contratos, records, enums, traits, impls e testes.
  - Código da extensão (`src/extension.ts` e `out/extension.js`) com integração ao Language Client via stdio e comandos de compilação (`Pascal` / `C99`), execução de testes e reinicialização do LSP.
  - Documentação de uso e instalação local (`ide/vscode/README.md`).

### ✅ Fase 19: Suporte a Dependências Git no `aether add` (Concluído)
- [x] **Download e Cache Automático via Git**:
  - `aetherc add <url-git> [--branch=... / --tag=... / --version=...]` com extração automática do nome do pacote da URL (`ExtractPackageNameFromGitUrl`).
  - Clonagem e sincronização automática via Git (`SyncGitPackage`) com armazenamento seguro no cache global (`~/.aether/cache/<pkg>`) e replicação para `.aether/deps/<pkg>`.
  - Resolução recursiva de dependências aninhadas a partir de `aether.json` de subpacotes com proteção contra dependências circulares.
  - Restauração automática de dependências (`RestoreProjectDependencies`) nos comandos `aetherc build`, `aetherc run` e `aetherc test`.
  - Validação completa com repositório Git real testado em ambos os backends (**Free Pascal** e **GCC C99**).

### ✅ Fase 20: Sockets Reais do Sistema Operacional & Servidor HTTP Nativo (Concluído)
- [x] **Integração Nativa com a Camada de Rede do SO (`std/net.aeth`)**:
  - Implementação de chamadas de rede reais nos emissores C e Pascal com paridade estrita:
    - No backend Object Pascal (FPC): Uso nativo e multiplataforma da unit `Sockets` (`fpsocket`, `fpbind`, `fplisten`, `fpaccept`, `fpconnect`, `fpsend`, `fprecv`, `CloseSocket`).
    - No backend C99 (GCC): Suporte a `WinSock2` (`<winsock2.h>`, `<ws2tcpip.h>`, inicialização transparente `WSAStartup`) com linkagem automática da flag `-lws2_32` no Windows e `<sys/socket.h>` no POSIX.
  - Primitivas embutidas no compilador e na tabela de símbolos: `SocketCreate`, `SocketListen`, `SocketAccept`, `SocketConnect`, `SocketSend`, `SocketRecv`, `SocketClose`.
  - Abstrações de alto nível em `std/net.aeth`: `SocketListenServer`, `SocketAcceptClient`, `SocketConnectClient`, `SocketSendString`, `SocketRecvString`, `SocketCloseHandle`.
- [x] **Servidor HTTP & REST de Altíssimo Desempenho**:
  - Servidor HTTP nativo em código Aether puro, sem dependências externas nem garbage collector (*Zero-Cost Abstractions*).
  - Parser de requisições HTTP (`ParseHttpRequest`) e montador de respostas estruturadas (`BuildHttpRequest`, `BuildHttpResponse`).
  - Serialização e resposta de payloads JSON estruturados integrando perfeitamente com `std/json.aeth` (`JsonBuilder`).
- [x] **Validação Prática Dual-Backend**:
  - Exemplo completo criado em `examples/15_http_server_and_sockets.aeth`, simulando servidor escutando em loopback e cliente conectando, trocando requisição/resposta HTTP com payload JSON.
  - Compilado e executado com 100% de sucesso e paridade idêntica nos backends **Free Pascal** e **GCC (MSYS2)**.
  - Suíte completa de testes de regressão (`examples/12_package_manager_and_tests` e `examples/14_stdlib_and_concurrency.aeth`) 100% aprovada em ambos os backends.

### ✅ Fase 21: Interoperabilidade Avançada de Primeira Classe (Free Pascal Units & C Headers / FFI) (Concluído)
- [x] **Auto-Import Transparente & Zero-Boilerplate (Sem `extern` manual!)**:
  - Invocação direta de funções de units Pascal (`import pascal SysUtils;`) e headers C (`import c "<math.h>";`) no código, sem necessidade de declarações manuais de `extern`.
  - O analisador de tipos (*Type Checker*) resolve dinamicamente os símbolos de units/headers importados, inferindo os tipos de retorno e argumentos com zero atrito de desenvolvimento.
- [x] **Interoperabilidade Fluida com Units do Free Pascal (`import pascal`)**:
  - Inclusão transparente de units FPC (`SysUtils`, `DateUtils`, `Classes`, `Horse`, `mORMot`) na cláusula `uses` do Object Pascal sem duplicação de identificadores.
  - No backend Free Pascal: omissão automática de diretivas de linkagem DLL, consumindo a unit nativamente com máxima otimização inline do compilador FPC.
- [x] **Interoperabilidade Avançada com Cabeçalhos e Bibliotecas C (`import c`)**:
  - Inclusão direta de headers C com suporte a delimitadores angulares e aspas (`import c "<math.h>";`, `import c "minha_lib.h";`).
  - Suporte a diretivas de linkagem nativa no compilador e toolchain (`-lm`, `-lws2_32`).
  - Prevenção automática de conflitos de redeclaração no GCC para funções padrão de `<math.h>` (`sin`, `cos`, `sqrt`, etc.).
- [x] **Validação Prática Dual-Backend**:
  - Exemplo modelo criado em `examples/16_pascal_and_c_interop.aeth`, consumindo simultaneamente `SysUtils.GetTickCount64` do Free Pascal e `sin`, `cos`, `sqrt` de `<math.h>` do C99 com **zero declarações `extern` manuais**.
  - Compilado e executado com 100% de paridade e sucesso nos backends **Free Pascal** e **GCC C99**.
  - Suíte completa de testes de regressão (exemplos 12, 14 e 15) 100% aprovada em ambos os backends.

### ✅ Fase 21.1: Integração de Primeira Classe com BlaiseVue & Pipeline de Tooling Pascal (Concluído)
- [x] **1. Emissão de Units Free Pascal Reutilizáveis (`unit` em vez de apenas `program`)**:
  - Suporte à flag `--unit` em `aetherc emit pascal` com nomeação canônica obrigatória do FPC (`<ModuleName>.pas`).
  - Geração estruturada com separação idiomática rigorosa de seções Pascal:
    - **`interface`**: Exportação pública de todas as `structs`, mônades (`generic TAetherResult<TVal, TErr>`), tipos, ponteiros antecipados, construtores e protótipos de funções/métodos.
    - **`implementation`**: Implementação dos corpos das funções, construtores de records, `AetherBox` e runtime helpers zero-cost do Aether.
  - Compatibilidade nativa validada com Free Pascal: consumida diretamente via cláusula `uses BlaisevueComponentStore;` em 0.1s.
- [x] **2. Customização Completa de Diretório de Saída (`--out-dir`)**:
  - Suporte à flag `--out-dir=<caminho>` (e `-d <caminho>`) para direcionar a saída transpilada diretamente para as pastas gerenciadas pelo BlaiseVue (ex: `.blaisevue/generated/`, `src/generated/` ou `server/generated/`).
- [x] **3. Execução Silenciosa & Headless para Ferramentas (`--silent` & JSON Diag)**:
  - Suporte à flag `--silent` (`-s`) para toolings e orquestradores externos (CLI do BlaiseVue, scripts de build).
  - Códigos de saída estritos (exit codes 0 e 1) e integração com `--emit-json-diag` para permitir que o BlaiseVue capture e renderize erros de compilação e borrow checker diretamente na sua UI/terminal.
- [x] **4. Modo Observador / Hot-Reload Reativo (`--watch`)**:
  - Comando `aetherc emit pascal <arquivo> --watch` (`-w`) com monitoramento contínuo de timestamps de alterações no arquivo `.aeth`.
  - Regeneração instantânea e atômica da unit `.pas` correspondente com tolerância a falhas transitórias durante digitação.
- [x] **5. Validação Prática com Exemplo Real**:
  - Criado `examples/17_blaisevue_component_store.aeth` demonstrando Store reativo com records e empréstimo mutável (`mut borrow`).
  - Unit `generated/pascal/BlaisevueComponentStore.pas` compilada e testada com FPC nativo sendo consumida por aplicação Pascal com 100% de sucesso.

### 🎯 Fase 22: Bootstrapping 100% Autônomo do Compilador Auto-Hospedado (`compiler/aeth/`)
- [x] **Argumentos de Linha de Comando Nativos (`ParamCount` e `ParamStr`)**:
  - Implementado suporte embutido a `ParamCount(): Int32` e `ParamStr(Index: Int32): String` com paridade idêntica tanto no backend Pascal (RTL nativa) quanto no C99 (`g_aether_argc`, `g_aether_argv`).
  - Validação de tipos no `uAetherTypeChecker.pas` garantindo compatibilidade com literais e expressões inteiras.
- [x] **CLI Autônoma do Compilador Auto-Hospedado (`compiler/aeth/main.aeth`)**:
  - `compiler/aeth/main.aeth` atualizado para processar argumentos dinâmicos de linha de comando (`aetherc-core <arquivo.aeth> [-o saida.c]`), com exibição de uso, flags de saída e modo de demonstração.
- [x] **Geração do Binário Final Auto-Gerado (`bin/aetherc-core.exe`)**:
  - Compilação completa de todo o pipeline do compilador auto-hospedado (`compiler/aeth/`) gerando `bin/aetherc-core.exe`.
- [x] **Testes de Ciclo Completo de Auto-Hospedagem (*Self-Hosting Verification*)**:
  - Execução de `bin\aetherc-core.exe examples/13_self_hosted_compiler_demo.aeth -o bin/self_hosted_output.c`.
  - Análise léxica, sintática, verificação de tipos nativa e borrow checking nativo executados com 0 erros.
  - Compilação do código C99 gerado via GCC e execução bem-sucedida, fechando com êxito o ciclo de bootstrapping e auto-hospedagem!

### 🎯 Fase 23: Auto-Hospedagem Recursiva Suprema (O `aetherc-core` Compilar a Si Mesmo)
- [x] **Expansão do Parser e AST Nativa em Aether (`compiler/aeth/`)**:
  - Implementados nós `ASTParamNode`, `ASTFunctionNode`, `ASTFieldNode` e `ASTStructNode` em `compiler/aeth/ast.aeth`.
  - Novos tokens `tkType`, `tkRecord` e `tkStruct` em `tokens.aeth` e `lexer.aeth`.
  - Parser de declaração de tipos compostos: `type Nome = record ... end;`.
  - Parser de funções de topo: `function Nome(params): Tipo var ... begin ... end;`.
  - Suporte a chamadas de funções livres e instruções com múltiplos argumentos separados por vírgula (`ParseArgs`).
- [x] **Type Checking Nativo de Funções e Chamadas com Múltiplos Parâmetros**:
  - `compiler/aeth/typechecker.aeth` atualizado com registro automático de assinaturas e tipos de retorno de funções de topo (`RegisterFunctions` e `TypeCheckProgram`).
  - Resolução dinâmica do tipo de retorno de expressões `ekCall` no TypeChecker nativo.
- [x] **Emissor C99 Nativo Avançado**:
  - Emissão de definições de `typedef struct { ... } Nome;` em C para structs Aether.
  - Emissão de protótipos e implementações de funções C de topo separadas do bloco `int main(void)`.
  - Emissão limpa de listas de argumentos e parâmetros em C99.
- [x] **Validação Prática & Ciclo de Auto-Hospedagem**:
  - Criado `examples/18_self_hosted_functions_and_structs.aeth` demonstrando structs, funções com múltiplos parâmetros, chamadas aninhadas e controle de fluxo.
  - Compilado via `bin\aetherc-core.exe` emitindo código C99, compilado com GCC (MSYS2) e executado com 100% de sucesso.
  - Testes de regressão do `examples/13_self_hosted_compiler_demo.aeth` aprovados com 100% de paridade.

### ✅ Fase 24: Tooling Nativo & Developer Experience (`aetherc fmt` e `aetherc test`) (Concluído)
- [x] **Formatador Canônico Oficial (`aetherc fmt`)**:
  - Implementada a unit dedicada `compiler/src/uAetherFormatter.pas`.
  - Padronização automática de indentação com 4 espaços por nível de escopo.
  - Normalização de espaçamento de operadores (`:=`, `:`, `,`, `;`, `=`, `<`, `>`, `+`, `-`).
  - Preservação estrita e transparente de literais de texto, comentários de linha (`//`) e de bloco (`/* ... */`).
  - Suporte ao modo `--check` para pipelines de CI/CD (retorna exit code 1 se algum arquivo precisar de formatação).
  - Suporte a formatação de arquivos individuais ou diretórios inteiros recursivamente.
- [x] **Primitivas de Asserção Nativas (`Assert`)**:
  - Implementada função intrínseca `Assert(cond: Bool [, msg: String])` em `uAetherSymbols.pas` e `uAetherTypeChecker.pas`.
  - Suporte dual-backend completo: `Assert` em Free Pascal e `assert(...)` (com `<assert.h>`) em C99 GCC.
  - Parser flexibilizado para aceitar tanto `;` quanto `,` na separação de parâmetros e argumentos de funções.
- [x] **Test Runner Embutido e Flexível (`aetherc test`)**:
  - Comando `aetherc test [arquivo | filtro] [--target=pascal|c]`.
  - Suporte à execução de arquivos de teste individuais diretamente (`aetherc test tests/01_suite_matematica_test.aeth`) mesmo fora da raiz de projetos `aether.json`.
  - Relatório no terminal com status `[ PASS ]` / `[ FAIL ]`, tempos de compilação/execução em milissegundos e código de saída refletindo o sucesso ou falha da asserção.
  - Suíte modelo `tests/01_suite_matematica_test.aeth` criada e aprovada nos backends Free Pascal e GCC C99.

### ✅ Fase 25: Biblioteca Padrão Canônica Expandida (`std/`) (Concluído)
- [x] **`std.fs` (Sistema de Arquivos & Diretórios)**:
  - Adicionadas funções nativas embutidas: `CreateDir`, `RemoveDir`, `DeleteFile`, `DirExists` e `FileSize` com paridade dual-backend Free Pascal (`SysUtils`) e GCC C99 (`sys/stat.h`, `direct.h`).
  - Módulo canônico `std/fs.aeth` com struct `FileInfo`, `CriarDiretorio`, `RemoverDiretorio`, `ApagarArquivo`, `ExisteDiretorio`, `TamanhoArquivo` e `ObterInfo`.
- [x] **`std.time` (Tempo de Alta Resolução & Benchmarking)**:
  - Adicionada função intrínseca de alta resolução `GetNanoseconds(): UInt64` (Windows QPC / POSIX `clock_gettime`) e `SleepMs(ms: UInt32)` em ambos os backends.
  - Módulo canônico `std/time.aeth` com struct `Timer`, `AgoraNanosegundos`, `Dormir`, `NovoTimer`, `Iniciar`, `Parar`, `DecorridoNs` e `DecorridoMs`.
- [x] **`std.json` (Manipulação Rápida de JSON)**:
  - Parser e builder nativo em Aether (`std/json.aeth`): `JsonBuilder`, `AddString`, `AddInt`, `AddBool`, `Build`, `ExtractString`, `ExtractInt`, `ExtractBool`, `HasKey` e `Validate`.
- [x] **`std.http` (Cliente e Servidor HTTP Canônico)**:
  - Módulo canônico `std/http.aeth` construído sobre `std/net.aeth` e `std/json.aeth`.
  - Abstrações de alto nível `Client` e `Server` com `NewClient`, `Get`, `Post`, `NewServer`, `AcceptRequest`, `SendResponse` e `StopServer`.
- [x] **Resolução Unificada de Módulos & Desambiguação de Tipos**:
  - `FindModuleFile` atualizado para aceitar tanto `import std.modulo;` quanto `import modulo;` com desduplicação canônica de caminhos visitados.
  - Implementado `ResolveTypeSymbol` no `TSymbolTable` e `TScope` garantindo que parâmetros de funções com o mesmo nome de seus tipos (ex: `client: Client`) não ofusquem a resolução do tipo nem o acesso a campos de records (`E0609`).
  - Emissor Pascal atualizado para mapear divisão inteira com `div` prevenindo conversões espúrias para `Double`.
- [x] **Validação Prática Dual-Backend**:
  - Exemplo integrado criado em `examples/20_stdlib_expanded.aeth`, testado e validado com 100% de sucesso e paridade idêntica nos backends Free Pascal e GCC C99.

### ✅ Fase 26: Compilação Incremental e Sistema de Cache de Objetos (`aetherc build --incremental`) (Concluído)
- [x] **Hash e Detecção de Mudanças (SHA-256 Autônomo)**:
  - Implementado algoritmo criptográfico SHA-256 autônomo e de alta performance na unit `compiler/src/uAetherIncremental.pas` (`SHA256File`, `SHA256String`), sem dependência de bibliotecas externas.
  - Rastreamento criptográfico completo do arquivo fonte `.aeth`, do hash do executável final e de todas as dependências transitivas resolvidas (`import`).
  - Armazenamento em manifesto estruturado e determinístico em `.aether/cache/build/<modulo>_<target>.cache.json`.
- [x] **Reutilização Inteligente de Artefatos & Fast-Path Instantâneo**:
  - Checagem antecipada de cache: quando ativado `--incremental` e nenhuma alteração de hash for detectada em nenhum nó do grafo de dependências, o compilador pula todas as etapas de parsing, semântica, transpilação e invocação do backend externo, retornando instantaneamente (0 ms).
  - Paridade total garantida nos backends **Free Pascal** (`fpc`) e **GCC C99** (`gcc`).
- [x] **Integração na CLI & Limpeza de Cache**:
  - Flags de linha de comando `--incremental`, `--no-incremental` e `--force` adicionadas a `aetherc`, com suporte em comandos diretos, `build` e `run`.
  - Atualizado `aetherc clean` para limpar também o diretório de cache `.aether/cache/build/`.
  - Validação completa com suíte padrão (`examples/20_stdlib_expanded.aeth`), test runner (`aetherc test`) e cenários com e sem modificação.

### ✅ Fase 27: Otimizações de AST & Modo Release (`aetherc build --release`) (Concluído)
- [x] **Constant Folding & Otimizações na AST**:
  - Implementada a unit dedicada `compiler/src/uAetherOptimizer.pas` (`TAetherOptimizer`).
  - Avaliação estática em tempo de compilação de expressões numéricas inteiras (`+`, `-`, `*`, `/`, `%`), de ponto flutuante, booleanas (`and`, `or`, comparações) e concatenação de strings literais.
  - Simplificação de identidades algébricas (`x + 0` -> `x`, `x * 1` -> `x`, `not (not x)` -> `x`, curto-circuito em booleanos).
- [x] **Dead Code Elimination (DCE)**:
  - Eliminação estática de ramos inalcançáveis (`if false then ... else ...`, `while false do ...`).
  - Eliminação de instruções subsequentes inalcançáveis após `return` incondicional em blocos e funções.
- [x] **Pipeline de Release de Alta Performance**:
  - Flags `--release`, `--opt` e `-O` implementadas na CLI `aetherc`.
  - Passagem de diretivas agressivas aos backends nativos:
    - Free Pascal: `-O3 -XX -Xs` gerando binários stripped compactos de ~116 KB.
    - GCC C99: `-O3 -flto -s` com Link-Time Optimization (LTO) gerando binários ultra compactos de apenas ~13.8 KB.
  - Exemplo integrado criado e validado em `examples/21_optimizer_and_release.aeth` com 100% de paridade em ambos os backends.

### ✅ Fase 28: Expansão do LSP & IDE Developer Experience (VS Code Extension v1.0.0) (Concluído)
- [x] **Formatação Integrada via LSP (`textDocument/formatting`)**:
  - Implementado o endpoint `textDocument/formatting` no servidor LSP chamando o motor canônico `uAetherFormatter.pas`.
  - Suporte total ao atalho padrão do VS Code (`Shift + Alt + F` / "Format Document") e formatação automática ao salvar (`formatOnSave`).
- [x] **Refatoração Segura (`textDocument/rename`)**:
  - Implementado o endpoint `textDocument/rename` com varredura léxica atômica em tokens de identificadores preservando literais de texto e comentários.
  - Suporte ao comando Rename Symbol (`F2`) no VS Code.
- [x] **Ações Rápidas de Correção (`textDocument/codeAction`)**:
  - Implementado o endpoint `textDocument/codeAction` com sugestões inteligentes de Quick-Fix (`Ctrl + .`):
    - Sugestão automática de `borrow` ou `mut borrow` para violações de posse do Borrow Checker (`E0401`, `E0402`).
    - Sugestão automática de inserção de imports ausentes da biblioteca padrão (`std.fs`, `std.time`, `std.http`, `std.json`).
- [x] **Lançamento da Extensão VS Code v1.0.0**:
  - Atualizado manifesto `package.json` para a versão estável `1.0.0`.
  - Provedores integrados registrados em `extension.js`.
  - Pacote oficial gerado com sucesso: `editors/vscode/aether-lang-1.0.0.vsix`.

### ✅ Fase 29: Auto-Hospedagem Completa de Ciclo Fechado (Stage 3 Bootstrapping)
- [x] **Ciclo Completo de Auto-Compilação (*Stage 1, 2 e 3*)**:
  - Comando canônico `aetherc bootstrap` integrado nativamente ao compilador e CLI.
  - Stage 1: Compilador de bootstrap (Pascal) compila o compilador em Aether (`compiler/aeth/main.aeth`) gerando `bin/bootstrap/aetherc-stage1.exe` otimizado via GCC C99 Release.
  - Stage 2: `aetherc-stage1.exe` compila o próprio compilador para C (`stage2_compiler.c`) e a suíte completa de structs e funções (`stage2_suite.c`), compilando o executável via GCC.
  - Stage 3: `aetherc-stage1.exe` executa o terceiro estágio em ambiente isolado, emitindo `stage3_compiler.c` e `stage3_suite.c` e compilando o executável.
- [x] **Verificação de Determinismo Bit-a-Bit e Ponto Fixo (Fixed Point)**:
  - Validação de paridade estrita em runtime: executáveis da suíte gerados no Stage 2 e Stage 3 produzem saídas idênticas.
  - Validação estrita de determinismo bit-a-bit:
    - `stage2_compiler.c` e `stage3_compiler.c`: 5604 bytes, SHA-256 idêntico (`e42a45a571a3ff6bfda554411b67727bd4f93885fd2946e67f9971fa5a4052ec`), 0 bytes de diferença.
    - `stage2_suite.c` e `stage3_suite.c`: 828 bytes, SHA-256 idêntico (`d6c7f2f6135cb09275953e546b59212c94baafe42b91a8f4b7dae5e3808ab767`), 0 bytes de diferença.
  - Status certificado: **CONVERGÊNCIA TOTAL (Ponto Fixo / Fixed Point!)** com **100% BIT-A-BIT IDENTICO**.

### ✅ Fase 30: Backend WebAssembly (`.wasm`) & JavaScript via `pas2js` (`--target=js` / `--target=wasm`)
- [x] **Alvo JavaScript via Free Pascal (`--target=js` / `pas2js`)**:
  - Integração nativa com o compilador oficial `pas2js` da suíte Free Pascal / Lazarus.
  - O Aether transpila para Object Pascal e invoca `pas2js` para gerar um arquivo `.js` (ECMAScript) puro, leve e direto.
  - Cópia automática da biblioteca de runtime `rtl.js` para distribuição autônoma.
  - Zero dependência de TypeScript, sem necessidade de Node.js/npm e sem bundlers complexos.
  - Execução imediata em qualquer navegador via tag `<script src="saida.js"></script>`.
- [x] **Alvo WebAssembly Puro (`--target=wasm`) via Clang**:
  - Compilação direta do código C gerado pelo Aether para binário WebAssembly (`.wasm`) de baixo nível utilizando Clang/LLVM (`clang --target=wasm32 -nostdlib -Wl,--no-entry -Wl,--export-all`).
  - Geração opcional de um arquivo `.html` mínimo de teste (`--html`) apenas com `<script>` JavaScript vanilla nativo (`WebAssembly.instantiateStreaming`) para carga e testes imediatos no browser.
- [x] **Seleção Flexível de Compiladores C & Multi-Target (`aether.json`)**:
  - Escolha transparente entre **GCC** e **Clang** (`--cc=gcc` ou `--cc=clang`, e `"c_compiler"` no manifesto).
  - Suporte ao array `"targets"` no `aether.json`, permitindo compilar múltiplos alvos (Wasm, JS, C Clang, C GCC, Pascal) num único `aetherc build`.
- [x] **Diagnóstico de Toolchain Web (`aetherc --doctor`)**:
  - Detecção no `aetherc --doctor` dos 4 compiladores: Free Pascal (`fpc`), GCC, Clang (LLVM / wasm32) e Pas2JS.

### ✅ Fase 31: Concorrência Estruturada & Async/Await com Corrotinas (Concluído)
- [x] **Corrotinas Zero-Cost e Tarefas Cooperativas (`Task<T>`)**:
  - Primitivas de linguagem `async function`, `await <expr>`, `spawn <expr>` e tipo container genérico `Task<T>` nativos no compilador.
  - Modelo de corrotinas cooperativas leves sem sobrecarga de alocação de threads pesadas de sistema operacional.
  - Estrutura de estado de tarefa (`is_completed`, `value`) com retorno estruturado assíncrono.
- [x] **Concorrência Segura Garantida pelo Borrow Checker**:
  - Integração de `TASTAwaitExpr` e `TASTSpawnExpr` com o motor de análise de posse e empréstimos (*Borrow Checker*).
  - Verificação de tipos garantindo que `await` desembala `Task<T>` para `T` e `spawn` encapsula em `Task<T>`.
- [x] **Emissão e Execução Multi-Backend Completa**:
  - Backend **Free Pascal**: Mapeamento para registros genéricos `generic TAetherTask<TVal>`.
  - Backend **C99 (GCC & Clang)**: Mapeamento para união/registro `AetherTask` compatível com C99.
  - Backend **WebAssembly (`.wasm`)**: Compilação via Clang freestanding (`-nostdlib`) com suporte a execução assíncrona.
  - Backend **JavaScript (`.js`)**: Compilação e execução via Pas2JS com runner HTML integrado.
- [x] **Validação Prática Multi-Backend**:
  - Demonstração canônica `examples/test_fase31_async/async_demo.aeth` compilada e validada com sucesso em Free Pascal, GCC, Clang, Wasm e Pas2JS.

### ✅ Fase 32: Gerador Canônico de Documentação (`aetherc doc`) (Concluído)
- [x] **Docstrings Estruturados e Metadados de Módulos**:
  - Parser de comentários de documentação estruturados (`///`) integrado diretamente ao Lexer (`uAetherLexer.pas`) e AST (`uAetherAST.pas`).
  - Suporte a tags semânticas `@param <nome> <desc>` e `@return <desc>`.
  - Extração automática de contratos formais de funções (`require` e `ensure`) formatados de volta para código canônico legível.
  - Extração de semântica de posse dos parâmetros com badges específicos (`borrow`, `mut borrow`, `take`).
- [x] **Geração de Site Estático de Documentação (`aetherc doc`)**:
  - Comando canônico `aetherc doc [arquivo | pasta] [opcoes]`.
  - Geração de site estático moderno, limpo e responsivo (`index.html`, `<Modulo>.html`, `style.css`) com suporte a temas dark/light e layout inspirado no Rustdoc/VitePress.
  - Índice de busca instantânea no cliente (`search.js`) permitindo pesquisar módulos, funções, structs e traits em tempo real.
  - Exportação opcional para Markdown (`API.md`) via `--format=md` ou `--format=all`.
  - Suporte à flag `--open` para abertura automática da documentação no navegador padrão do sistema operacional.
- [x] **Suíte de Doctests Integrada (`--test`)**:
  - Extração automática de blocos de exemplos de código testáveis (`/// ```aether ... ``` `).
  - Execução e compilação automatizada com harness dinâmico via `aetherc doc --test`, reportando status `PASS` ou `FAIL` para cada asserção contida na documentação.
- [x] **Validação Prática**:
  - Módulo completo de demonstração `examples/test_fase32_doc/geometria.aeth` criado com docstrings, contratos, types, traits, async functions e doctests aprovados com 100% de sucesso.

### ✅ Fase 33: Registry Central de Pacotes Comunitários (`aetherc pkg publish`)
- [x] **Infraestrutura do Registro Central**:
  - Especificação e cliente de API para o repositório público de pacotes do Aether (`~/.aether/registry/index.json` e storage de versões).
  - Auditoria criptográfica de integridade com SHA-256 e assinaturas digitais por pacote publicado.
- [x] **Comandos de Publicação e Descoberta**:
  - Subcomandos na CLI: `aetherc pkg publish [--dry-run]` e `aetherc pkg search <termo>` (também via `aetherc publish` e `aetherc search`).
  - Sincronização automatizada de dependências e resolução de compatibilidade semântica (SemVer `^`, `~`, `*` e exata).
  - Integração transparente com `aetherc add <pacote>` e `RestoreProjectDependencies` gravando integridade no `aether.lock`.

### ⏳ Fase 34: Integração de Primeira Classe com BlaiseVue (SFC `<script lang="aether">`, Wasm & Backend Nativo Zephyr em `vendor/zephyr`)
- [ ] **Módulo Backend Nativo Zephyr Embutido em `vendor/zephyr`**:
  - Implementação do servidor backend **Zephyr** escrito em Aether como módulo nativo do BlaiseVue dentro do diretório `vendor/zephyr`, eliminando a necessidade de repositório externo ou submódulos adicionais.
  - **Simples como Express/FastAPI, Poderoso como mORMot**:
    - Roteamento declarativo limpo (`server.Get("/api/endpoint", handler)`), tipagem estática e serialização instantânea via `[derive(JSON)]`.
    - Performance de ponta equiparável ou superior ao mORMot via sockets de kernel (`std/net.aeth`), buffers zero-copy garantidos pelo Borrow Checker e corrotinas cooperativas assíncronas (`Task<T>`).
  - **Alvo de Compilação Duplo (Binário C ou Pascal)**:
    - **Binário C via GCC (Modo Padrão de Produção & Máxima Performance)**: O Aether compila o Zephyr para C99 e o GCC gera um binário executável nativo ultra-compacto com otimizações LTO (`-O3 -flto -s`), alcançando o mais alto throughput de requisições por segundo e baixíssimo footprint de RAM.
    - **Binário Pascal via FPC (Modo Desenvolvimento & Debug)**: O Aether compila para Object Pascal puro e o Free Pascal gera o binário nativo com integração e stack traces familiares do ecossistema FPC.
  - **Segurança Nativa e Blindagem de Produção (Security-First Engine)**:
    - **Memory Safety Absoluta**: Imunidade matemática contra *buffer overflows*, vazamentos (*memory leaks*), *use-after-free* e corrupção de memória garantida em tempo de compilação pelo Borrow Checker do Aether, sem garbage collector.
    - **Proteção contra Ataques DoS & Slowloris**: Timeouts estritos de conexões inativas (`ReadTimeout`, `WriteTimeout`, `IdleTimeout`) e limites rígidos de tamanho de requisição (`MaxHeaderBytes`, `MaxBodyBytes`).
    - **Sanitização e Validação Tipada**: Desserialização estrita através de `[derive(JSON)]`, blindando os endpoints contra injeções (SQLi, NoSQLi, Command Injection) e payloads malformados.
    - **Proteções HTTP e Rate Limiting**: Middlewares nativos para CORS configurável, Security Headers (HSTS, CSP, X-Frame-Options, X-Content-Type-Options) e controle de taxa de requisições (*Rate Limiting*) por IP/Token.
    - **Transporte Seguro (TLS/HTTPS)**: Suporte nativo a conexões seguras criptografadas de ponta a ponta.
- [ ] **Arquitetura Modular Não-Invasiva**:
  - Preservação do core do BlaiseVue (`core/*.pas` e `bin/bv.pas`) em Object Pascal puro, garantindo estabilidade operacional, sem dependências circulares e sem necessidade de dois compiladores para desenvolver o framework.
  - O Aether atua como linguagem de desenvolvimento de primeira classe para o desenvolvedor de aplicações.
- [ ] **Frontend Reativo com Aether em Componentes `.bv` (`<script lang="aether">`)**:
  - Detecção no parser de SFC do `bv` de blocos `<script lang="aether">`.
  - Pipeline de pré-processador: extração do script para arquivo `.aeth` temporário e invocação transparente de `aetherc emit pascal --unit` na pasta `generated/`.
  - Validação estática de posse (Borrow Checker) e checagem de tipos em tempo de compilação antes de entregar a unit Pascal para o `pas2js`.
  - Compatibilidade retroativa total: blocos `<script>` sem atributo continuam rodando Object Pascal puro.
- [ ] **WebAssembly de Alta Performance por Convenção 1:1 (Abordagem A)**:
  - Suporte a `<script lang="aether" target="wasm">` em componentes de computação pesada (gráficos, física, IA local, processamento de dados).
  - O `bv` invoca `aetherc --target=wasm` gerando `dist/wasm/<NomeComponente>.wasm` via Clang wasm32.
  - Resolução automática em runtime: o `bv` gera o código de carregamento inicial automático no ciclo `mounted` via `TBVWasm.LoadFromUrl('<NomeComponente>', '/wasm/<NomeComponente>.wasm')` utilizando o motor `core/BVWasm.pas` já existente no BlaiseVue.
  - Despacho direto de métodos exportados do Wasm no template (`@click="executar"`) sem necessidade de bindings manuais.

---

### ✅ Fase 35: Exportação de Bibliotecas Nativas Compartilhadas (`.dll` / `.so` / `.dylib`) & Gerador de Headers C (`.h`)
- [x] **Compilação de Shared Libraries (`cdylib` / `--lib`)**:
  - Configuração no manifesto `aether.json` (`"type": "cdylib"` ou `"type": "lib"`) e flags de linha de comando (`aetherc build --lib`, `--shared`).
  - Suporte de backend duplo:
    - **Free Pascal**: Emissão de arquivo `library <Nome>; ... exports ... end.` compilando para `.dll` (Windows), `.so` (Linux) ou `.dylib` (macOS).
    - **C99 (GCC / Clang)**: Emissão com decoradores de exportação (`__declspec(dllexport)` no Windows, `__attribute__((visibility("default")))` no Linux) e compilação com `-shared -fPIC`.
  - Anotação/palavra-chave `export function` com convenção de chamada explícita (`cdecl` / `stdcall`).
- [x] **Gerador Canônico de Cabeçalhos C (`.h`)**:
  - Subcomando `aetherc emit-header [arquivo] [opcoes]` ou flag `aetherc build --emit-header`.
  - Geração automática de arquivo `.h` compatível com C99 e C++ (`#ifdef __cplusplus extern "C" { #endif`).
  - Mapeamento estrito de tipos: inteiros (`int32_t`, `int64_t`, `uint32_t`), floats (`float`, `double`), booleanos (`bool`), records exportados (`typedef struct { ... } Nome;`) e ponteiros com checagem de posse.
- [x] **Interoperabilidade Externa Validada**:
  - Validação prática de consumo da DLL/SO compilada em Aether a partir de outras linguagens:
    - Script em Python via `ctypes` testando chamadas diretas e troca de structs (`Ponto2D`).
    - Executável C puro consumindo a DLL e o `.h` gerado.
    - Suporte bidirecional verificado em ambos os backends (Free Pascal e GCC).

---

### ✅ Fase 36: Suíte Canônica de Benchmarking (`aetherc bench`) & Relatórios de Performance (Concluído)
- [x] **Harness de Benchmark Integrado na CLI**:
  - Comando canônico `aetherc bench [filtro] [opcoes]`.
  - Suporte a declaração de benchmarks via anotação `@bench` ou diretório padronizado `benches/*_bench.aeth`.
  - Execução com repetições configuráveis (warm-up runs + medições de precisão em nanosegundos).
  - Cálculo estatístico automático: tempo médio por iteração, desvio padrão, mediana e operações por segundo (ops/sec).
- [x] **Comparação Multi-Backend & Relatórios**:
  - Execução comparativa automática entre os backends suportados (`--target=pascal`, `--target=c-gcc`).
  - Relatório no terminal com tabelas formatadas em ASCII destacando o backend mais veloz e percentuais de diferença (`[MAIS RAPIDO - X% faster]`).
  - Exportação de resultados para JSON (`--format=json` / `--json`) para integração com pipelines de CI/CD e rastreamento de regressões de performance.
- [x] **Validação Prática com Amostras Reais**:
  - Microbenchmarks validados com Fibonacci e soma iterativa em `examples/test_fase36_bench/benches/math_bench.aeth`.
  - Macrobenchmarks validados com programas executáveis autônomos em `examples/test_fase36_bench/benches/prog_bench.aeth`.

---

### ✅ Fase 37: Derivação Automática de Metaprogramação (`[derive(Debug, JSON, Clone, Equals)]`) (Concluído)
- [x] **Sintaxe de Derivação na AST e Parser**:
  - Suporte à sintaxe de atributos `[derive(Debug, JSON, Clone, Equals)]` aplicável a declarações de `record` e `enum`.
  - Parser estendido para registrar metadados de derivação na AST (`TASTRecordDecl.Derives`, `TASTEnumDecl.Derives`).
  - Módulo dedicado de expansão de metaprogramação sintática (`compiler/src/uAetherDerives.pas`).
- [x] **Geração Automática de Métodos em Tempo de Compilação**:
  - **`Debug`**: Geração do método `ToString(borrow self): String` formatando o nome do tipo e todos os campos recursivamente no formato `Tipo { campo1: valor1, campo2: valor2 }` para records e `Enum.Variante` para enums.
  - **`JSON`**: Geração de `ToJSON(borrow self): String` com serialização JSON em conformidade estrita (invariante de locale com ponto decimal em floats e suporte a records aninhados e enums).
  - **`Clone`**: Geração de `Clone(borrow self): Self` para duplicação explícita e segura de estruturas sem violar as regras de empréstimo do Borrow Checker.
  - **`Equals`**: Geração de `Equals(borrow self, other: borrow Self): Bool` comparando recursivamente todos os membros estruturais de records e variantes de enums.
- [x] **Compatibilidade Multi-Backend e Integração ao TypeChecker**:
  - Suporte completo em ambos os backends de produção: Free Pascal (`--target=pascal`) e GCC C99 (`--target=c`).
  - Funções intrínsecas de conversão com formatação invariante (`AetherFloatToStr`, `AetherBoolToStr`).
  - Resolução por método UFCS integrado com Traits padrão (`Debug`, `JSON`, `Clone`, `Equals`).
- [x] **Validação com Amostras Reais e Testes Automatizados**:
  - Exemplo integrado em `examples/test_fase37_derives/main.aeth` demonstrando records simples, records aninhados e enums.
  - Teste unitário canônico adicionado em `tests/02_derives_test.aeth` integrado ao `aetherc test`.

---

### ✅ Fase 38: Linter Estático Canônico & Análise de Qualidade de Código (`aetherc lint`) (Concluído)
- [x] **Análise Semântica de Boas Práticas e Code Smells**:
  - Detecção de variáveis declaradas e nunca utilizadas (*Unused Variables* - `L001`).
  - Detecção de imports e units externas não referenciadas (*Unused Imports* - `L002`).
  - Identificação de código inalcançável (*Unreachable / Dead Code* - `L003`) após instruções de `return` e desvios incondicionais.
  - Alerta de parâmetros de funções nunca lidos sem prefixo de descarte (`_`) (*Unused Params* - `L004`).
- [x] **Verificação de Convenções Estilísticas e Redundâncias**:
  - Simplificação de expressões booleanas redundantes com literais `true`/`false` (`L005`).
  - Validação de nomenclatura padronizada: tipos/records/enums em `PascalCase` (`L006`).
- [x] **Comando CLI e Modo Auto-Fix**:
  - Comando canônico `aetherc lint [arquivo | pasta] [opcoes]`.
  - Flag `--fix`: remoção automática de imports não utilizados diretamente no arquivo-fonte.
  - Flag `--json`: saída estruturada para integração com IDEs e pipelines de CI/CD.
  - Validação prática com amostras reais em `examples/test_fase38_lint/`.

---

### ✅ Fase 39: Suíte de Profiling, Auditoria de Memória & Detecção de Leaks (`aetherc profile`) (Concluído)
- [x] **Harness de Profiling Integrado**:
  - Comando canônico `aetherc profile <arquivo.aeth> [opcoes]`.
  - Medição precisa de tempos de execução (total, média, mínimo, máximo) via timers de alta resolução com suporte a repetições configuráveis (`--runs=N`).
  - Execução nos dois backends nativos (`--target=pascal` e `--target=c`).
- [x] **Auditoria de Memória e Detecção de Leaks em Tempo de Execução**:
  - **Backend Free Pascal**: Compilação automática com `-gh` (`heaptrc`) e `-gl`, auditando blocos alocados, blocos liberados e capturando qualquer bloco não liberado com callstack de vazamento.
  - **Backend C99**: Execução rastreada e segura no runtime bare-metal com verificação de integridade de saída.
  - Relatório de status de segurança da memória (`[100% LIMPO - ZERO LEAKS]`).
- [x] **Relatórios e Visualização**:
  - Tabela formatada no terminal com estatísticas de latência, blocos de memória e heap total alocado.
  - Exportação de relatório em JSON estruturado (`--json`) com invariância de separador decimal para integração com ferramentas e CI/CD.
  - Validação prática demonstrada em `examples/test_fase39_profile/app_profile.aeth`.

---

### ✅ Fase 40: Compilação Condicional, Expressões em Tempo de Compilação & Atributos de Otimização (`@cfg`, `comptime`, `@inline`) - CONCLUÍDA
- [x] **Diretivas de Compilação Condicional Multiplataforma (`@cfg`)**:
  - Suporte a atributos `@cfg(target_os = "windows" | "linux" | "darwin")` e `[cfg(...)]` em funções, constantes e tipos.
  - Suporte a `@cfg(target = "pascal" | "c" | "wasm" | "js")` e `@cfg(debug)` / `@cfg(release)`.
  - Poda automática na AST (`ApplyCfgToModule`) de ramificações, tipos e funções inativas para a plataforma ou alvo selecionado.
- [x] **Avaliação de Expressões em Tempo de Compilação (`comptime` / `const eval`)**:
  - Avaliação de expressões matemáticas constantes, concatenações de strings e reduções diretas no TypeChecker/Optimizer.
  - Bloqueio imediato de divisões por zero ou estouros em tempo de compilação com código de erro semântico `E0301`.
- [x] **Atributos de Otimização e Controle de Inlining**:
  - Atributos `@inline(always)` e `@inline(never)` mapeados para diretivas nativas nos backends (FPC `inline` / GCC `__attribute__((always_inline))` ou `__attribute__((noinline))`).
  - Atributo `@cold` para rotinas de tratamento de erro ou caminhos raros de execução (`__attribute__((cold))`), instruindo os compiladores de backend a otimizar o *branch prediction* do processador.

---

### ✅ Marco de Lançamento Open-Source: Build 1-Click & Internacionalização (Inglês) - CONCLUÍDO
- [x] **Scripts Canônicos de Bootstrap e Compilação 1-Click**:
  - `build.bat`: Script para Windows (CMD/Explorer) com compilação direta via FPC e execução de testes.
  - `build.ps1`: Script PowerShell avançado com detecção automática do toolchain (`fpc`, `gcc`), validação de PATH e execução de `aetherc --doctor`.
  - `build.sh`: Script executável para Linux e macOS (`chmod +x build.sh && ./build.sh`).
  - Facilidade absoluta: o desenvolvedor baixa o código-fonte e em um comando tem o `bin/aetherc` pronto e testado.
- [x] **Internacionalização Integral da Documentação (Inglês como Padrão Global)**:
  - Criação do `README.md` raiz internacional em inglês (com badges, quickstart, exemplos de código, garantias de memória e benchmarks).
  - Documentação canônica técnica em inglês (`docs/`): especificação de sintaxe, guia da CLI, borrow checker e guia de interoperabilidade.
- [x] **Auditoria de Higiene do Repositório**:
  - Verificação rigorosa do `.gitignore` garantindo que nenhum binário (`.exe`, `.o`, `.ppu`, `.wasm`) ou arquivo temporário seja rastreado.
  - Licença open-source padrão (`LICENSE`) e guia de contribuição (`CONTRIBUTING.md`).

---

### ✅ Fase 41: Auto-Atualização da Toolchain da Linguagem (`aetherc upgrade`) - CONCLUÍDA
- [x] **Arquitetura Híbrida de Atualização (Binary Release & Source Build)**:
  - Detecção automática de repositório Git local ou download de binários pré-compilados oficiais do GitHub Releases.
  - Suporte à flag `--check` para consulta não invasiva de novas versões e notas de lançamento (Release Notes).
  - Suporte à flag `--from-source` para sincronização Git (`fetch`, `pull`), compilação nativa via `build.ps1`/`build.sh` e execução da suíte de testes unitários.
  - Suporte à flag `--binary` para forçar download do artefato empacotado da plataforma.
  - Suporte a `--version=<tag>` e `--nightly` para transitar entre versões estáveis e experimentais.
- [x] **Segurança e Validação Criptográfica SHA-256**:
  - Download e verificação automatizada de somas de verificação SHA-256 antes da extração do arquivo.
  - Bloqueio imediato (`E9991`) e descarte em caso de divergência ou corrupção do pacote.
- [x] **Mecanismo de Substituição Atômica & Rollback Instantâneo**:
  - Contorno nativo para o bloqueio de arquivo em execução no Windows: renomeação do executável ativo para `.bak`, gravação do novo executável e auto-teste de integridade.
  - Rollback automático caso o novo binário falhe no teste de inicialização.
  - Comando `aetherc upgrade --rollback` para restauração imediata da versão anterior a qualquer momento.
  - Modo `--dry-run` para auditoria prévia completa do plano de execução sem modificações em disco.
