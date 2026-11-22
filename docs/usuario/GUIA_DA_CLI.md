# Guia Completo da CLI do Aether (`aetherc`)

O compilador oficial do Aether (`aetherc`) é uma ferramenta multifuncional e completa para compilação nativa, gerenciamento de projetos, auditoria de pacotes e ferramentas de integração com o ecossistema.

---

## 1. Visão Geral da Sintaxe

```bash
aetherc <comando | arquivo.aeth> [opcoes]
```

---

## 2. Comandos de Construção e Execução

### `aetherc build`
Compila o projeto baseado no manifesto `aether.json` presente no diretório atual ou pastas superiores.
- Restaura automaticamente dependências ausentes de `.aether/deps/`.
- Executa a análise sintática, verificação de tipos e o *Borrow Checker*.
- Transpila para a pasta `generated/pascal/` ou `generated/c/`.
- Invoca o compilador nativo (FPC ou GCC) e gera o binário final na pasta `bin/`.

```bash
aetherc build
aetherc build --target=c
aetherc build --target=c --cc=clang
aetherc build --target=wasm --html -o public/modulo.wasm
aetherc build --target=js --html -o public/modulo.js
```

### Targets de Compilação (`--target`):
- `--target=pascal`: Compila para binário nativo via Object Pascal e Free Pascal (padrão).
- `--target=c`: Compila para binário nativo via C99 (usando GCC ou Clang).
- `--target=wasm`: Compila diretamente para módulo WebAssembly autônomo (`.wasm`) via **Clang** (`clang --target=wasm32 -nostdlib -Wl,--no-entry -Wl,--export-all`).
- `--target=js`: Compila diretamente para JavaScript modular (`.js`) via **Pas2JS** (`pas2js -Jc`).

### Seleção de Compilador C (`--cc` / `--c-compiler`):
- `--cc=gcc`: Utiliza o GCC (ex: MinGW-w64 UCRT64 no Windows).
- `--cc=clang`: Utiliza o Clang / LLVM (suporte nativo e cross-compilação WebAssembly).

### Runner HTML para Navegador (`--html`):
Quando `--html` é informado junto a `--target=wasm` ou `--target=js`, o compilador gera automaticamente um arquivo `.html` completo e estilizado com runner embutido:
- Para `.wasm`: instancia o WebAssembly com `WebAssembly.instantiateStreaming` e disponibiliza os exports em `window.aetherWasm`.
- Para `.js`: copia a runtime `rtl.js` do Pas2JS e inicializa os módulos disponíveis em `window.pas`.

### `aetherc run`
Compila a aplicação e a executa imediatamente no terminal:
```bash
aetherc run
aetherc run --target=c
```

### `aetherc test [filtro | caminho] [opcoes]`
Executa a suíte de testes unitários automatizados da pasta `tests/` ou executa um arquivo de teste específico diretamente:
```bash
# Executa todos os testes (*.aeth em tests/)
aetherc test

# Executa testes com o backend C99 nativo
aetherc test --target=c

# Executa apenas testes que contenham "matematica" no nome do arquivo
aetherc test matematica

# Executa um arquivo de teste diretamente (com ou sem aether.json)
aetherc test tests/01_suite_matematica_test.aeth
```
Os testes utilizam a instrução nativa de asserção:
```aether
Assert(condicao, "Mensagem descritiva de falha");
```

### `aetherc clean`
Remove com segurança todos os artefatos de compilação do projeto atual (`bin/`, `generated/` e `.aether/cache/build/`), preservando o código-fonte e o compilador:
```bash
aetherc clean
```

---

## 2.1 Compilação Incremental e Sistema de Cache (`--incremental`)

O Aether possui um sistema de compilação incremental de alta performance baseado em **SHA-256**, que rastreia criptograficamente cada arquivo fonte e todas as suas dependências transitivas (`import std.fs;`, `import std.http;`, etc.).

### Flags de Compilação Incremental:
- `--incremental`: Ativa o rastreamento de cache. Se o executável de saída já existir e nenhum arquivo fonte ou dependência transitiva tiver sido modificado, a compilação retorna **imediatamente** (0 ms) reutilizando o binário existente.
- `--force`: Ignora qualquer cache existente e força a recompilação completa de ponta a ponta.
- `--no-incremental`: Desativa a verificação de cache incremental para a compilação atual.

```bash
# Compilação incremental rápida (detecta e reutiliza cache se inalterado)
aetherc build src/main.aeth --incremental

# Execução incremental
aetherc run src/main.aeth --incremental

# Força recompilação completa ignorando cache
aetherc build src/main.aeth --incremental --force
```

Os manifestos de compilação incremental são salvos automaticamente no diretório `.aether/cache/build/` em formato JSON legível e determinístico.

---

## 2.2 Otimizações de AST & Modo Release (`--release`, `--opt`)

O Aether possui um otimizador de AST integrado (`uAetherOptimizer.pas`) com análise estática de alto nível e reescrita de código para máxima performance de execução e tamanho reduzido de binários:

### Otimizações na AST:
1. **Constant Folding (Dobra de Constantes)**:
   - Expressões inteiras: `24 * 60 * 60` -> `86400`
   - Expressões booleanas: `(100 > 50) and (20 = 20)` -> `true`
   - Concatenação de literais: `"Aether " + "Engine " + "Release"` -> `"Aether Engine Release"`
2. **Simplificações Algébricas**:
   - `x + 0` -> `x`, `x - 0` -> `x`, `x * 1` -> `x`, `x / 1` -> `x`, `not (not x)` -> `x`
3. **Dead Code Elimination (DCE)**:
   - `if false then ... else ... end;`: o ramo `then` inalcançável é descartado em tempo de compilação e o `else` é promovido.
   - `while false do ... end;`: loops com condição estática falsa são eliminados da AST.
   - Código inalcançável após `return` incondicional é automaticamente expurgado da árvore sintática.

### Flags do Otimizador e Release:
- `--release`: Ativa o otimizador de AST e passa diretivas agressivas aos compiladores nativos:
  - **Free Pascal (`fpc`)**: `-O3 -XX -Xs` (otimização agressiva nível 3, eliminação de funções/unidades não usadas e strip total de símbolos de debug). Binários em torno de ~110 KB.
  - **GCC C99 (`gcc`)**: `-O3 -flto -s` (otimização nível 3, link-time optimization entre módulos e strip de símbolos). Binários ultra compactos de ~13 KB.
- `--opt` ou `-O`: Ativa o otimizador de AST mantendo o modo normal de compilação.

```bash
# Compilação em modo release para produção
aetherc build src/main.aeth --release

# Compilação release direcionada para C99
aetherc build src/main.aeth --target=c --release -o bin/app.exe

# Execução com otimizações de AST
aetherc run src/main.aeth --opt
```

---

## 3. Comandos de Emissão e Transpilação (`aetherc emit`)

O comando `emit` gera o código-fonte transpilado sem necessariamente invocar o FPC ou GCC, permitindo inspeção, depuração, integração com CI/CD e integração direta com o **BlaiseVue**:

```bash
aetherc emit <pascal | c> [arquivo.aeth] [opcoes]
```

### Opções do `emit`:
- `--unit`: Emite no formato **Unit Free Pascal** (`unit ...; interface ... implementation ... end.`), permitindo consumo direto pelo BlaiseVue com `uses MinhaUnit;`.
- `--out-dir=<caminho>` ou `-d <caminho>`: Grava o código gerado no diretório especificado (ex: `.blaisevue/generated/` ou `src/generated/`).
- `--stdout`: Imprime o código gerado diretamente na saída padrão do terminal, ideal para pipes e redirecionamentos (`| gcc -x c -`, `> codigo.c`).
- `--silent` ou `-s`: Modo silencioso para pipelines de ferramentas externas, retornando ExitCode 0 em sucesso e erros em `stderr`.
- `--watch` ou `-w`: Observa o arquivo fonte e regera a unit/código automaticamente sempre que o arquivo for salvo (Hot-Reload reativo).
- `-o <arquivo>`: Especifica o nome exato do arquivo de destino.

### Exemplos Práticos do `emit`:
```bash
# 1. Gera Unit Pascal para consumo no BlaiseVue
aetherc emit pascal src/Store.aeth --unit

# 2. Gera Unit Pascal diretamente dentro da pasta gerenciada pelo BlaiseVue
aetherc emit pascal src/Store.aeth --unit --out-dir=./generated/blaisevue

# 3. Observa alterações e regera em tempo real (Hot-Reload)
aetherc emit pascal src/Store.aeth --unit --watch

# 4. Inspeciona o código C99 gerado direto no console via pipe
aetherc emit c src/main.aeth --stdout | head -n 30
```

---

## 4. Gerenciamento de Projetos e Pacotes

### `aetherc new [nome | .]`
Inicializa um novo projeto Aether estruturado com `aether.json`, `src/main.aeth`, `tests/main_test.aeth`, `.gitignore` e `README.md`:
```bash
# Cria um novo projeto em uma nova pasta:
aetherc new meu_projeto

# Cria um novo projeto dentro do diretorio atual:
aetherc new .
```

### Configuração de Caminhos e Interop (`paths` no `aether.json`)
No manifesto `aether.json`, a seção `"paths"` permite organizar módulos, subpastas, código C (`.c`/`.h`), units Free Pascal (`.pas`) e cópia automática de bibliotecas compartilhadas (`.dll`/`.so`):

```json
{
  "name": "meu_projeto",
  "version": "0.1.0",
  "backend": "pascal",
  "entry": "src/main.aeth",
  "output": "bin/meu_projeto.exe",
  "paths": {
    "aether": [
      "src",
      "libs/minha_lib_aether"
    ],
    "c_includes": [
      "include"
    ],
    "c_sources": [
      "c_src/auxiliar.c"
    ],
    "pascal_units": [
      "pascal_src"
    ],
    "lib_dirs": [
      "lib"
    ],
    "libs": [
      "raylib"
    ],
    "shared_libs": [
      "lib/raylib.dll"
    ]
  }
}
```

- **`aether`**: Diretórios extras para resolução de módulos `.aeth` importados (`import arvores.carvalho;`).
- **`c_includes`**: Pastas com headers C (`.h`), repassadas automaticamente como `-I"caminho"` ao GCC.
- **`c_sources`**: Arquivos `.c` adicionais compilados e linkados diretamente no executável final.
- **`pascal_units`**: Pastas com units Free Pascal (`.pas`/`.ppu`), repassadas como `-Fu"caminho"` ao FPC (ideal para integração com BlaiseVue).
- **`lib_dirs`**: Pastas com bibliotecas estáticas ou dinâmicas, repassadas como `-L` ao GCC e `-Fl` ao FPC.
- **`libs`**: Nomes de bibliotecas para linkagem final (ex: `-lraylib`, `-lsqlite3`).
- **`shared_libs`**: Bibliotecas dinâmicas (`.dll` no Windows ou `.so` no Linux) que são **automaticamente copiadas para a pasta do binário** (`bin/`) durante o build ou run.

---

### Configuração de Diretórios de Saída e Integração BlaiseVue (`outputs`)

Para integrar perfeitamente o Aether ao ecossistema **BlaiseVue** e controlar com precisão onde ficam os arquivos fontes e compilados, o manifesto `aether.json` suporta a seção `"outputs"`:

```json
{
  "name": "meu_modulo_blaise",
  "version": "0.1.0",
  "entry": "src/meu_modulo.aeth",
  "backend": "pascal",
  "outputs": {
    "bin_dir": "bin",
    "pascal_src_dir": ".blaisevue/generated",
    "pascal_unit_dir": "build/units",
    "c_src_dir": "build/c",
    "as_unit": true
  }
}
```

- **`bin_dir`**: Diretório onde o executável final será gerado (padrão: `bin`).
- **`pascal_src_dir`**: Diretório onde o código Object Pascal gerado (`.pas`) será salvo (ex: `.blaisevue/generated` ou `generated/pascal`).
- **`pascal_unit_dir`**: Diretório onde o Free Pascal Compiler grava as units compiladas (`.ppu` e `.o`), repassado automaticamente como `-FU"<dir>"`. Isso impede que arquivos objeto se misturem com seus fontes.
- **`c_src_dir`**: Diretório onde os fontes C (`.c`) transpilados são gravados.
- **`as_unit`**: Quando `true`, emite e compila o código Aether como uma **Unit Object Pascal** (`unit ... interface ... implementation ... end.`) pronta para ser importada via `uses` em projetos BlaiseVue e Lazarus.

---

### Configuração Multi-Target e Compiladores C (`targets` e `c_compiler`)

Para projetos com múltiplos alvos simultâneos (por exemplo, gerar um módulo WebAssembly para a web, um script JavaScript, e binários nativos compilados com GCC ou Clang), configure o array `"targets"` no `aether.json`:

```json
{
  "name": "meu_projeto_multitarget",
  "version": "0.1.0",
  "c_compiler": "clang",
  "targets": [
    {
      "name": "modulo_web",
      "entry": "src/calculadora.aeth",
      "target": "wasm",
      "backend": "clang",
      "output": "public/calculadora.wasm"
    },
    {
      "name": "script_js",
      "entry": "src/calculadora.aeth",
      "target": "js",
      "backend": "pas2js",
      "output": "public/calculadora.js"
    },
    {
      "name": "binario_nativo_clang",
      "entry": "src/main.aeth",
      "target": "c",
      "backend": "clang",
      "output": "bin/app_clang.exe"
    },
    {
      "name": "binario_nativo_gcc",
      "entry": "src/main.aeth",
      "target": "c",
      "backend": "gcc",
      "output": "bin/app_gcc.exe"
    }
  ]
}
```

Ao executar `aetherc build`, cada target é compilado em ordem com sua respectiva toolchain e diretório de saída definidos.

### Flags de Caminhos, Saídas e Interop na Linha de Comando (CLI)
Você também pode passar essas configurações diretamente na linha de comando:
- `-FE <dir>`: Define o diretório de saída dos executáveis finais.
- `-FU <dir>`: Define o diretório de saída das units compiladas FPC (`.ppu` e `.o`).
- `--out-pascal <dir>`: Define o diretório onde os fontes `.pas` gerados são gravados.
- `--out-c <dir>`: Define o diretório onde os fontes `.c` gerados são gravados.
- `--unit`: Emite/compila código no formato Unit Pascal (unit/interface/implementation).
- `-I <dir>`: Adiciona diretório de busca para módulos Aether e headers C.
- `-Fu <dir>`: Adiciona diretório de busca para units do Free Pascal (`.pas`/`.ppu`).
- `-L <dir>`: Adiciona diretório de bibliotecas nativas (`-L` GCC e `-Fl` FPC).
- `-l <lib>`: Linka com biblioteca do sistema (ex: `-lraylib`, `-lws2_32`).
- `--c-source <arquivo.c>`: Compila arquivo C adicional junto ao executável final.
- `--shared-lib <arquivo.dll/.so>`: Copia biblioteca compartilhada para a pasta do executável gerado.

### `aetherc pkg <subcomando>`
Gerenciador nativo de pacotes do Aether:
- `aetherc pkg add <pacote>`: Adiciona dependência Git ou local ao `aether.json` e `aether.lock`.
- `aetherc pkg remove <pacote>` (ou `rm`): Remove dependência e limpa caches locais.
- `aetherc pkg update [pacote]` (ou `upgrade`): Atualiza dependências Git e sincroniza o lockfile.
- `aetherc pkg audit`: Inspeciona a integridade criptográfica SHA e validação TLS.
- `aetherc pkg list` (ou `ls`): Exibe a árvore de dependências declaradas no projeto.
- `aetherc pkg clean`: Limpa o cache global compartilhado em `~/.aether/cache`.

---

## 5. Ferramentas de Linguagem e Diagnósticos

### `aetherc --doctor`
Verifica a presença, caminhos e versões dos 4 compiladores da toolchain Aether:
1. **Free Pascal (`fpc`)**: Compilador Object Pascal nativo.
2. **GCC (`gcc`)**: Compilador C nativo (MSYS2 UCRT64 no Windows ou nativo no Linux/macOS).
3. **Clang / LLVM (`clang`)**: Compilador C nativo e cross-compilador WebAssembly (`wasm32`).
4. **Pas2JS (`pas2js`)**: Compilador Free Pascal para JavaScript modular (Web/NodeJS).

### `aetherc lsp` (ou `--lsp`)
Inicia o servidor de linguagem oficial (**Language Server Protocol - LSP**), fornecendo autocompletion, hover documentation, go-to-definition e diagnósticos em tempo real para o VS Code e editores modernos.

### `aetherc --emit-json-diag`
Executa o compilador emitindo todos os erros e diagnósticos estruturados em formato JSON, projetado para consumo por IAs e extensões de IDE:
```bash
aetherc build --emit-json-diag
```

### `aetherc --check-only`
Valida apenas sintaxe, tipos e regras do Borrow Checker sem gerar executáveis nem código intermediário (ideal para linters e checagens ultrarrápidas).

### `aetherc fmt [arquivo | pasta] [--check]`
Formatador canônico oficial do Aether. Padroniza a formatação do código-fonte de acordo com o guia de estilo oficial da linguagem:
- Indentação canônica de 4 espaços por nível de escopo.
- Espaçamento padronizado em operadores (`:=`, `:`, `,`, `;`, `=`, `<`, `>`, `+`, `-`).
- Preservação intacta de strings literais, comentários de linha (`//`) e comentários em bloco (`/* ... */`).
- Quebras de linha e alinhamento em declarações e blocos (`module`, `type`, `var`, `begin ... end`).
- Suporte a modo verificação `--check` para pipelines de CI/CD (retorna exit code 1 se houver desvios).

```bash
# Formata um arquivo especifico
aetherc fmt src/main.aeth

# Formata recursivamente todos os arquivos .aeth do projeto ou pasta
aetherc fmt src/

# Apenas verifica se os fontes estao no padrao oficial (CI/CD)
aetherc fmt src/ --check
```

### `aetherc --dump-tokens` e `aetherc --dump-ast`
Exibe a lista de tokens do Lexer ou a árvore sintática abstrata (AST) para análise interna e estudo do compilador.

---

## 6. Auto-Hospedagem e Bootstrapping de Ciclo Fechado (`aetherc bootstrap`)

O comando `bootstrap` executa o ciclo completo de auto-hospedagem (*Stage 3 Bootstrapping*) e atesta matematicamente a independência e o determinismo do compilador da linguagem Aether:

```bash
aetherc bootstrap
```

### O que o comando realiza:
1. **Stage 1 (Compilação do Compilador em Aether)**: O compilador bootstrap em Pascal (`aetherc`) compila o código-fonte auto-hospedado (`compiler/aeth/main.aeth`) com GCC C99 em modo release otimizado, gerando `bin/bootstrap/aetherc-stage1.exe`.
2. **Stage 2 (Emissão e Compilação Nativa via Stage 1)**: O compilador gerado `aetherc-stage1.exe` compila o próprio compilador para C (`stage2_compiler.c`) e a suíte de testes de structs e funções (`stage2_suite.c`), compilando o binário executável com GCC.
3. **Stage 3 (Iteração Isolada e Ponto Fixo / Fixed Point)**: O compilador repete o processo em ambiente isolado, emitindo `stage3_compiler.c` e `stage3_suite.c`.
4. **Validação em Runtime e Determinismo Bit-a-Bit**:
   - Os binários executáveis gerados no Stage 2 e Stage 3 rodam e produzem saídas estritamente idênticas.
   - Os hashes criptográficos SHA-256 e tamanhos em bytes dos artefatos do Stage 2 e Stage 3 são comparados.
   - Havendo 0 bytes de divergência e hashes idênticos, atesta-se **CONVERGÊNCIA TOTAL (Fixed Point)** e **100% DE DETERMINISMO BIT-A-BIT**.

---

## 7. Concorrência Estruturada & Async/Await com Corrotinas (`Task<T>`)

A partir da **Fase 31**, o Aether inclui suporte nativo de primeira classe à concorrência estruturada e corrotinas cooperativas de custo zero (*zero-cost coroutines*), sem necessidade de alocar threads pesadas de sistema operacional.

### Sintaxe e Primitivas:
- `async function Nome(params): Tipo`: Declara uma função assíncrona. Seu retorno real é automaticamente empacotado no container genérico `Task<Tipo>`.
- `await <expr>`: Aguarda a conclusão da tarefa cooperativa e extrai seu valor resultante com segurança estática.
- `spawn <expr>`: Dispara uma tarefa assíncrona desacoplada retornando um `Task<T>`.
- `Task<T>`: Tipo genérico canônico embutido (`specialize TAetherTask<T>` em Pascal / `AetherTask` em C99).

### Exemplo em Aether:
```aether
module async_demo;

async function ComputarFatorial(n: Int32): Int32
begin
    if n <= 1 then
        return 1;
    end;
    return n * (n - 1);
end;

program async_app;
var
    t1: Task<Int32>;
    resultado: Int32;
begin
    // Dispara a execucao assincrona
    t1 := spawn ComputarFatorial(5);

    // Aguarda o resultado de forma cooperativa
    resultado := await t1;
    PrintLn("Resultado: " + IntToStr(resultado));
end.
```

### Suporte Multi-Backend Completo:
O modelo de tarefas assíncronas é 100% compatível em todos os backends do compilador:
- **Free Pascal**: Compilação nativa de alta velocidade (`--target=pascal`).
- **C99 (GCC & Clang)**: Binários nativos compactos e de alto desempenho (`--target=c`).
- **WebAssembly**: Módulos `.wasm` autônomos (`--target=wasm`).
- **JavaScript (Pas2JS)**: Execução no navegador e runtime web (`--target=js`).

---

## 8. Gerador Canônico de Documentação (`aetherc doc`)

A partir da **Fase 32**, o Aether possui um gerador de documentação oficial embutido no compilador (`aetherc doc`), capaz de inspecionar módulos `.aeth`, extrair comentários de documentação estruturados (`///`), contratos formais (`require` / `ensure`), semântica de posse (`borrow`, `mut borrow`, `take`) e compilar doctests automaticamente.

### Comandos e Opções:
```bash
# Gera documentação HTML estática para todo o projeto em docs/api/
aetherc doc

# Gera documentação para um arquivo específico
aetherc doc src/matematica.aeth

# Especifica diretório de saída customizado
aetherc doc --out-dir=public/api

# Exporta em Markdown para documentação de repositórios (GitHub/GitLab)
aetherc doc --format=md
aetherc doc --format=all

# Abre a documentação diretamente no navegador padrão
aetherc doc --open

# Executa e valida todos os exemplos de código (Doctests)
aetherc doc --test
```

### Escrevendo Comentários de Documentação (`///`):
```aether
/// Módulo de cálculo numérico e vetorial.
module matematica;

/// Cria um vetor 2D normalizado.
/// @param x Componente horizontal X
/// @param y Componente vertical Y
/// @return Novo vetor 2D
///
/// ```aether
/// var v: Vetor := CriarVetor(3.0, 4.0);
/// Assert(v.x > 0.0);
/// ```
function CriarVetor(x: Float64, y: Float64): Vetor
require
    x >= 0.0;
    y >= 0.0;
ensure
    x >= 0.0;
var
    v: Vetor;
begin
    v.x := x;
    v.y := y;
    return v;
end;
```

### Recursos Gerados:
1. **Site Estático HTML Responsivo**:
   - `index.html`: Dashboard com estatísticas do projeto, grafo de dependências e índice de módulos.
   - `<Modulo>.html`: Página detalhada de cada módulo com sidebar, seções de structs, enums, traits e funções.
   - `style.css`: Tema dark/light elegante inspirado no Rustdoc e VitePress.
   - `search.js`: Índice de busca instantânea no cliente com filtragem em tempo real (Ctrl+K).
2. **Exportação Markdown (`API.md`)**:
   - Resumos em tabelas, contratos formais e blocos de código formatados para visualização direta no GitHub/GitLab.
3. **Validação Automatizada de Doctests (`--test`)**:
   - Extrai automaticamente blocos de código com asserções (`Assert`) contidos na documentação e os compila/executa em ambiente isolado, garantindo que os exemplos de código da documentação nunca fiquem desatualizados.
