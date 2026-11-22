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
```

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
Verifica a presença e versões do Free Pascal Compiler (`fpc`) e do compilador GCC (MSYS2 UCRT64 no Windows ou nativo no Linux/macOS).

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
