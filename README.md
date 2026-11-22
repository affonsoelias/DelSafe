# Aether Programming Language

> **Uma linguagem de sistemas moderna com a clareza estruturada de Object Pascal e Ada, a segurança estática de memória do Rust, interoperabilidade bilateral nativa com C e Pascal, e concebida especialmente como a linguagem de alta performance para o framework BlaiseVue e para colaboração perfeita com Inteligências Artificiais.**

---

## 🧭 Por que o Aether foi criado?

O **Aether** nasceu de uma necessidade real de engenharia e da busca pelo equilíbrio perfeito no desenvolvimento de software de alta confiabilidade:

### 1. Mais segura que Object Pascal sem perder sua essência
O Object Pascal (Delphi / Free Pascal) é uma das linguagens mais elegantes, legíveis e produtivas já criadas. No entanto, em sistemas modernos, a gestão manual de memória tradicional pode levar a armadilhas silenciosas: *Access Violations* (ponteiros nulos), vazamentos de memória (*memory leaks*) e acessos após liberação (*use-after-free*). O Aether traz a segurança necessária para eliminar essas classes de bugs **em tempo de compilação**, preservando a clareza e legibilidade que tornam a família Pascal memorável.

### 2. Sem a complexidade intimidadora do Rust
O Rust provou que o sistema de posse (*Ownership & Borrowing*) é o padrão ouro da segurança de memória moderna sem coletor de lixo (*garbage collector*). Porém, essa segurança veio acompanhada de uma barreira de aprendizado extremamente íngreme: anotações complexas de ciclo de vida (`'a`), sintaxe árida carregada de símbolos e regras que tornam o desenvolvimento inicial lento e frustrante. O Aether implementa as garantias de posse, empréstimo (`borrow`) e movimentação (`take`) com uma semântica limpa, amigável e acessível — você ganha a segurança do Rust sem precisar lutar contra o compilador.

### 3. Concebida para IAs: Sem Alucinações, Sem Ambiguidade (AI-Native)
Ao programar com Inteligências Artificiais e LLMs em linguagens cheias de regras implícitas e chaves soltas (como C, C++ ou JavaScript), é comum a IA alucinar tipos, esquecer fechamentos de escopo ou introduzir efeitos colaterais imperceptíveis. 
O Aether foi projetado como uma linguagem **AI-Native**:
* **Gramática Estruturada e Explícita:** Seções claras e bem delimitadas (`type`, `var`, `contract`, `begin ... end`).
* **Sintaxe Não Ambígua:** Blocos expressivos inspirados em **Pascal** e **Ada** reduzem a incerteza do modelo de linguagem.
* **Previsibilidade:** Sem inferências mágicas que confundem o contexto da IA; o que está escrito é exatamente o que é executado.
* **Diagnósticos em JSON para Agentes:** O compilador emite diagnósticos estruturados via `--emit-json-diag` com sugestões diretas de correção (*auto-fix*), permitindo que agentes de IA e IDEs consertem erros com precisão cirúrgica.

### 4. Fácil Aprendizado: Próxima de Object Pascal e Ada
A sintaxe do Aether se lê como pseudocódigo executável de alto nível. Qualquer desenvolvedor com conhecimento prévio de Pascal, Delphi, Ada ou linguagens estruturadas se sente em casa em poucos minutos, sem curvas misteriosas ou conceitos crípticos.

### 5. Interoperabilidade Bilateral Total com C e Pascal
O Aether não cria um ecossistema isolado:
* **Consome C e Pascal nativamente:** Você pode importar e usar qualquer biblioteca em C (`extern function`, `import c`) e qualquer unit do Free Pascal (`import pascal`) diretamente no código.
* **Consumido por C e Pascal:** O compilador do Aether possui emissores nativos de alta performance para **C99** e **Object Pascal**. As bibliotecas que você escreve em Aether podem ser compiladas e consumidas de maneira transparente por bases de código existentes em C ou Delphi/FPC.

### 6. Alta Concorrência Moderna sem o Custo do Garbage Collector (Superando os Limites de Horse e mORMot)
No desenvolvimento de servidores e microsserviços modernos, os frameworks tradicionais em Pascal muitas vezes esbarram no modelo clássico "1 thread por conexão" (que esgota a memória sob milhares de conexões simultâneas) ou na complexidade de gerenciar locks manuais com risco de *Access Violations* silenciosas. 
O Aether traz a revolução da **Concorrência Segura (*Fearless Concurrency*)**:
* **I/O Multiplexado e Micro-tarefas:** Arquitetura orientada a eventos (IOCP no Windows / epoll no Linux) capaz de segurar dezenas de milhares de conexões simultâneas consumindo poucos megabytes de RAM.
* **Segurança contra Data Races no Compilador:** O Borrow Checker (`take`, `borrow`, `mut borrow`) impede acessos concorrentes desprotegidos em tempo de compilação. Se o código compilar, ele não corrompe a memória entre threads.

### 7. Criada para o Framework BlaiseVue: Fullstack Nativo de Ponta a Ponta
O **Aether** foi concebido e arquitetado sob medida para ser a linguagem oficial de alta performance do ecossistema **BlaiseVue**. Ao invés de forçar o desenvolvedor a fragmentar seu ecossistema utilizando uma linguagem no backend e outra no frontend (o que gera validações duplicadas, APIs frágeis e atritos de tipagem), o Aether entrega uma experiência Fullstack verdadeiramente integrada:
* **A Linguagem Oficial do BlaiseVue:** Criada para que tanto a camada de microsserviços e APIs do backend quanto os componentes e regras de negócio do frontend compartilhem a mesma elegância, segurança estática de memória e velocidade nativa bare-metal.
* **Tipos Compartilhados de Ponta a Ponta:** Registros, Enums e DTOs definidos uma única vez em Aether são consumidos diretamente pelo BlaiseVue, eliminando discrepâncias de dados entre cliente e servidor.
* **Zero Duplicação e Refatoração Confiável:** Se um modelo ou regra de negócio for alterado no backend, o compilador alerta instantaneamente as incompatibilidades no frontend antes mesmo do código ser implantado.

### 8. Autonomia e Compilador Auto-Hospedado (Self-Hosting)
O Aether não depende eternamente de harnesses externos: seu núcleo (`compiler/aeth/`) é escrito na própria linguagem Aether, fechando o ciclo de bootstrapping e garantindo a maturidade e independência a longo prazo da plataforma.

---

## 🌟 Principais Recursos

- 🛡️ **Segurança de Memória Estática (*Ownership & Borrowing*):** Sem garbage collector, sem ponteiros soltos. Uso exclusivo de `own`, `borrow`, `mut borrow` e `take` checados em tempo de compilação.
- 📜 **Contratos Nativos no Código (Ada / Eiffel style):** Pré-condições (`require`) e pós-condições (`ensure`) integradas diretamente na assinatura das funções.
- 🧩 **Traits e Polimorfismo Estático (*Zero-Cost Abstractions*):** Defina contratos comportamentais com `trait` e implemente para seus tipos com `impl`. Despacho monomorfizado estático em tempo de compilação, sem tabelas virtuais (vtable) nem overhead em runtime.
- 🎯 **Pattern Matching Algébrico:** `match` exaustivo e tipos algébricos com dados associados (`enum Payload`), eliminando a necessidade de `nil`/`null` com as mónadas nativas `Result<T, E>` e `Option<T>`.
- ⚡ **Sintaxe de Métodos via UFCS:** Invocação intuitiva estilo objeto (`registro.Metodo()`) combinada com funções puras e modulares.
- 🌐 **Biblioteca Padrão Moderna (`std/`):** Módulos nativos para `JSON` (parser zero-alocação), `Sync` (atômicos, mutex e canais CSP), `Net` (sockets e HTTP), `Strings`, `Math` e `IO`.
- 📦 **Gerenciador de Pacotes e Test Runner Integrados:** Ferramental nativo completo (`aether add` com suporte a Git e dependências transitivas, `aether test`, `aether init`, `aether build`, `aether run`).
- 🔌 **LSP e Extensão VS Code Oficiais:** Language Server integrado (`aetherc lsp`) com autocompletion, hover tipado, go-to-definition, diagnósticos em tempo real e extensão VS Code (`ide/vscode/`).

---

## 🚀 Sintaxe em 60 Segundos

```pascal
module ExemploSimples;

type
    Usuario = record
        nome: String;
        pontos: Int32;
    end;

// Funcao com emprestimo mutavel verificado em tempo de compilacao:
function GanharPontos(mut borrow u: Usuario; borrow qtd: Int32): Int32
begin
    u.pontos := u.pontos + qtd;
    return u.pontos;
end;

program Main;
var
    jogador: Usuario;
begin
    jogador := Usuario("Alice", 100);

    PrintLn("Jogador: %s | Pontos iniciais: %d", jogador.nome, jogador.pontos);

    // O compilador garante posse exclusiva durante o emprestimo mutavel:
    GanharPontos(mut borrow jogador, 50);

    PrintLn("Pontos atualizados: %d", jogador.pontos);
end.
```

---

## 🛠️ Instalação e Uso

O compilador oficial `aetherc` é distribuído em `bin/aetherc.exe` e suporta compilação cruzada para **Free Pascal** e **GCC (C99)**.

### 1. Verificação do Ambiente
```bash
./bin/aetherc --doctor
```
Informa se o compilador Free Pascal (`fpc`) e o GCC (`gcc` via MSYS2 no Windows ou nativo em Linux/macOS) estão configurados corretamente.

### 2. Criar e Executar um Projeto
```bash
# 1. Cria a estrutura do projeto com manifesto aether.json
aetherc new meu_app
cd meu_app

# 2. Executa a compilação e roda a aplicação imediatamente
aetherc run

# 3. Compila utilizando o backend C99 nativo
aetherc run --target=c

# 4. Limpa artefatos temporarios de build (bin/ e generated/)
aetherc clean
```

### 3. Emissão de Código e Integração com BlaiseVue
```bash
# Emite codigo Object Pascal organizado em generated/pascal/
aetherc emit pascal src/main.aeth

# Emite Unit Free Pascal (unit/interface/implementation) para o BlaiseVue
aetherc emit pascal src/main.aeth --unit

# Emite codigo C99 organizado em generated/c/
aetherc emit c src/main.aeth

# Modo Hot-Reload (observa alteracoes e regera automaticamente)
aetherc emit pascal src/main.aeth --unit --watch
```

### 4. Gerenciamento de Pacotes e Dependências
```bash
# Adiciona uma dependência local ao aether.json
aetherc pkg add math_extra --path=libs/math_extra

# Adiciona uma dependência remota diretamente via URL Git
aetherc pkg add https://github.com/exemplo/logger.git --branch=v1.0.0

# Audita a integridade criptografica e seguranca TLS
aetherc pkg audit

# Lista as dependencias do projeto
aetherc pkg list
```

### 5. Execução de Testes Automatizados
```bash
# Roda todos os testes unitários da pasta tests/
aetherc test

# Roda testes utilizando o backend C99 nativo
aetherc test --target=c

# Roda apenas testes que correspondam a um filtro
aetherc test banco --target=c
```

### 6. Compilar um Arquivo Único
```bash
# Backend Pascal (Padrão)
aetherc examples/01_hello_world.aeth

# Backend C99 (GCC)
aetherc examples/01_hello_world.aeth --target=c
```

---

## 📂 Estrutura do Repositório

- **[`compiler/`](file:///c:/Users/Pichau/Documents/aether/compiler/):** Código-fonte do compilador oficial (bootstrap em Free Pascal e versão auto-hospedada completa em `compiler/aeth/`).
- **[`std/`](file:///c:/Users/Pichau/Documents/aether/std/):** Biblioteca Padrão oficial (`json`, `sync`, `net`, `math`, `strings`, `io`).
- **[`examples/`](file:///c:/Users/Pichau/Documents/aether/examples/):** Exemplos práticos cobrindo do Hello World a Traits, Concorrência, Sockets, JSON, Pattern Matching, Ownership e Compilador Auto-Hospedado.
- **[`docs/`](file:///c:/Users/Pichau/Documents/aether/docs/):**
  - **[Curso Oficial Aether](file:///c:/Users/Pichau/Documents/aether/docs/curso/README.md):** 9 lições práticas passo a passo.
  - **[Guia do Iniciante](file:///c:/Users/Pichau/Documents/aether/docs/usuario/GUIA_DO_INICIANTE.md):** Manual completo de conceitos.
  - **[Especificação Técnica](file:///c:/Users/Pichau/Documents/aether/docs/tecnica/ESPECIFICACAO_LINGUAGEM.md):** Gramática formal EBNF e arquitetura do compilador.
  - **[Roadmap de Desenvolvimento](file:///c:/Users/Pichau/Documents/aether/docs/planejamento/ROADMAP_DE_DESENVOLVIMENTO.md):** Fases 1 a 21 concluídas, Fase 21.1 (Integração BlaiseVue & Tooling Pascal) e Fase 22 (Self-Hosting Bootstrapping).
- **[`ide/vscode/`](file:///c:/Users/Pichau/Documents/aether/ide/vscode/):** Extensão oficial para Visual Studio Code com syntax highlighting TextMate, snippets e cliente LSP.

---

## 📄 Licença

Projeto desenvolvido sob a licença aberta MIT. Consulte o arquivo [LICENSE](file:///c:/Users/Pichau/Documents/aether/LICENSE) para mais detalhes.
