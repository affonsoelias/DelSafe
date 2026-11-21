# Aether Programming Language

> **Uma linguagem de sistemas com a clareza e estrutura do Object Pascal, a segurança de memória do Rust e um compilador projetado para cooperação perfeita entre Humanos e Inteligências Artificiais.**

---

## 🌟 O Conceito

**Aether** nasceu da união de duas filosofias de software extraordinárias:
1. **A disciplina e legibilidade clássica do Pascal:** Blocos delimitados por palavras legíveis (`begin/end`, `module`, `contract`), separação rígida de seções (`var`, `type`), ausência de ambiguidades em chaves aninhadas e facilidade de leitura visual.
2. **A blindagem de sistemas moderna do Rust:** Sistema de posse (*Ownership & Borrowing*), tipos de dados algébricos (`enum` com tuplas e records associados), monads de tratamento de falha explícitas (`Result<T, E>` / `Option<T>`) e zero vazamentos de memória sem a necessidade de coletor de lixo (*garbage collector*).

Além disso, o Aether inclui:
- **Contratos Nativos (estilo Ada / Eiffel):** Blocos `contract require / ensure` integrados diretamente na assinatura das funções.
- **Compilador Amigável à IA:** Diagnósticos em JSON com sugestões estruturadas de correção (*auto-fix*) prontas para serem aplicadas por agentes inteligentes e IDEs modernas.

---

## 📂 Estrutura do Projeto

- **[`docs/`](file:///c:/Users/Pichau/Documents/aether/docs/README.md):** Documentação oficial completa:
  - **[Curso Oficial Aether](file:///c:/Users/Pichau/Documents/aether/docs/curso/README.md):** Trilha didática em 9 lições práticas (do Hello World a contratos, posse e projeto final).
  - **[Guia do Usuário](file:///c:/Users/Pichau/Documents/aether/docs/usuario/GUIA_DO_INICIANTE.md):** Primeiros passos, instalação e conceitos de posse.
  - **[Documentação Técnica](file:///c:/Users/Pichau/Documents/aether/docs/tecnica/ESPECIFICACAO_LINGUAGEM.md):** Gramática formal EBNF, segurança de memória e arquitetura do compilador.
  - **[Roadmap de Desenvolvimento](file:///c:/Users/Pichau/Documents/aether/docs/planejamento/ROADMAP_DE_DESENVOLVIMENTO.md):** Fases concluídas e metas futuras.
- **`examples/`:** Exemplos conceituais e programas de teste para validar o compilador:
  - [`01_hello_world.aeth`](file:///c:/Users/Pichau/Documents/aether/examples/01_hello_world.aeth): Estrutura básica e saída formatada.
  - [`02_ownership_and_borrow.aeth`](file:///c:/Users/Pichau/Documents/aether/examples/02_ownership_and_borrow.aeth): Posse, empréstimo (`borrow`) e movimentação (`take`).
  - [`03_result_and_match.aeth`](file:///c:/Users/Pichau/Documents/aether/examples/03_result_and_match.aeth): Contratos, enum algébrico e casamento de padrões exaustivo.
  - [`04_method_syntax_ufcs.aeth`](file:///c:/Users/Pichau/Documents/aether/examples/04_method_syntax_ufcs.aeth): Orientação a objetos moderna via UFCS (`meu_buffer.Inspecionar()`).
  - [`05_curso_projeto_final.aeth`](file:///c:/Users/Pichau/Documents/aether/examples/05_curso_projeto_final.aeth): Sistema bancário seguro unindo UFCS, `mut borrow`, `Result` e contratos.
  - [`06_interop_extern.aeth`](file:///c:/Users/Pichau/Documents/aether/examples/06_interop_extern.aeth): Interoperabilidade com bibliotecas C (`extern function`) e inclusão de units Pascal (`import pascal`).

---

## 🚀 Sintaxe em 60 Segundos

```pascal
module Exemplo;

type
    Status = enum
        Ok(code: UInt32),
        Falha(motivo: String)
    end;

function Validar(take s: Status): Result<UInt32, String>
contract
    require
        true;
begin
    match s do
        case Status.Ok(let codigo):
            return Ok(codigo);
        case Status.Falha(let erro):
            return Err("Operacao falhou: " + erro);
    end;
end;
```

---

## 🛠️ Usando o Compilador `aetherc`

O compilador oficial está implementado em Free Pascal na pasta `compiler/` e disponível em `bin/aetherc.exe`.

### 1. Diagnóstico do Ambiente
```bash
./bin/aetherc --doctor
```
Verifica automaticamente se o **Free Pascal (`fpc`)** e o **compilador C (`gcc`)** (via MSYS2 no Windows ou nativo no Linux/macOS) estão instalados e operacionais.

### 2. Compilar para Binário Nativo (Backend Pascal - Padrão)
```bash
./bin/aetherc examples/01_hello_world.aeth
./bin/01_hello_world.exe
```

### 3. Compilar para Binário Nativo via C99 (MSYS2 GCC)
```bash
./bin/aetherc examples/01_hello_world.aeth --target=c
```

### 4. Modo Diagnóstico para IA (JSON Diagnostics)
```bash
./bin/aetherc examples/02_ownership_and_borrow.aeth --emit-json-diag
```
Retorna diagnósticos em formato JSON estruturado com localização exata e sugestões de correção pronta para modelos de linguagem.
