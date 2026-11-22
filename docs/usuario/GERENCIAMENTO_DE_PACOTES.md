# Gerenciador de Pacotes e Dependências do Aether (`aetherc pkg`)

O **Aether** possui um gerenciador de pacotes moderno, descentralizado e criptograficamente seguro integrado diretamente no compilador `aetherc`.

Ele gerencia dependências locais, repositórios Git remotos, versões semânticas e lockfiles com verificação de integridade SHA e TLS.

---

## 1. Visão Geral da Arquitetura

1. **Manifesto Declarativo (`aether.json`):** Define metadados do projeto, ponto de entrada (`entry`), backend padrão (`pascal` ou `c`) e a lista de dependências.
2. **Lockfile Criptográfico (`aether.lock`):** Trava com precisão matemática os hashes de commit Git exatos instalados, garantindo compilações 100% reproduzíveis (*Reproducible Builds*).
3. **Auditoria de Integridade (`aetherc pkg audit`):** Detecta adulterações (*tampering*) em arquivos baixados e valida conexões TLS seguras (`https://`).
4. **Cache Global e Dependências Locais:**
   - Pacotes remotos são armazenados em cache global (`~/.aether/cache/<pacote>`).
   - Cópias ativas são replicadas para a pasta `.aether/deps/<pacote>` do projeto atual.
   - Restauração automática de dependências em `aetherc build`, `run` e `test`.

---

## 2. Estrutura Padrão de um Projeto Aether

Ao criar um novo projeto com `aetherc new meu_app`:

```text
meu_app/
├── aether.json           <- Manifesto de configuração e dependências
├── aether.lock           <- Travamento estrito de versões e commits
├── src/
│   └── main.aeth         <- Ponto de entrada da aplicação
├── tests/
│   └── main_test.aeth    <- Suíte de testes automatizados
├── .aether/
│   └── deps/             <- Dependências instaladas prontas para importação
├── bin/                  <- Executáveis nativos compilados
├── generated/            <- Códigos transpilados organizados
│   ├── pascal/           <- Units e programas Object Pascal
│   └── c/                <- Código-fonte C99 nativo
├── .gitignore            <- Ignora bin/, generated/ e .aether/deps/
└── README.md
```

---

## 3. O Manifesto `aether.json`

Exemplo de manifesto completo:

```json
{
  "name": "meu_app",
  "version": "1.0.0",
  "description": "Aplicacao de alta performance escrita em Aether",
  "backend": "pascal",
  "entry": "src/main.aeth",
  "output": "bin/meu_app.exe",
  "dependencies": [
    {
      "name": "logger_lib",
      "path": "libs/logger_lib"
    },
    {
      "name": "aether_http",
      "git": "https://github.com/aetherlang/aether-http.git",
      "version": "v1.2.0"
    }
  ]
}
```

---

## 4. Subcomandos do Gerenciador de Pacotes (`aetherc pkg`)

### 4.1 Adicionar Dependências (`aetherc pkg add`)

Você pode adicionar pacotes de três formas diferentes:

```bash
# 1. Via URL Git com tag/versao ou branch especifica:
aetherc pkg add https://github.com/aetherlang/aether-http.git --version=v1.2.0
aetherc pkg add https://github.com/aetherlang/aether-json.git --branch=main

# 2. Sintaxe abreviada no formato pacote@versao:
aetherc pkg add aether-sync@v2.0.0
aetherc pkg add https://github.com/aetherlang/aether-db.git#v1.0.0

# 3. Dependencia local de outra pasta do monorepo:
aetherc pkg add math_extra --path=libs/math_extra
```

O comando baixa o repositório, extrai o commit SHA, sincroniza dependências aninhadas recursivamente e grava no `aether.lock`.

### 4.2 Listar Dependências (`aetherc pkg list` ou `ls`)

Exibe um relatório limpo de todas as dependências declaradas e suas origens:

```bash
aetherc pkg list
```

Saída:
```text
========================================================
  Dependencias do Projeto: "meu_app" (v1.0.0)
========================================================
  • logger_lib         -> Local: libs/logger_lib
  • aether_http        -> Git: https://github.com/aetherlang/aether-http.git (v1.2.0)
========================================================
```

### 4.3 Auditoria de Segurança e Integridade (`aetherc pkg audit`)

Verifica se os pacotes locais correspondem exatamente aos hashes travados no `aether.lock` e valida políticas de segurança de rede:

```bash
aetherc pkg audit
```

Saída:
```text
========================================================
  Aether Security & Integrity Auditor (aetherc pkg audit)
========================================================
Auditoria de dependencias em: C:\Users\...\meu_app
  [OK] aether_http: Commit e89b147a23 verificado e integro (TLS Seguro: Sim)
  [OK] logger_lib: Dependencia local em "libs/logger_lib" (Origem interna confiavel)

--------------------------------------------------------
 Resultados: 2 pacotes auditados | 0 adulteracoes | 0 alertas
 Status: AMBIENTE SEGURO (BlaiseVue Verified)
========================================================
```

### 4.4 Atualizar Dependências (`aetherc pkg update` ou `upgrade`)

Busca novas versões ou commits nos remotos Git e atualiza o manifesto e o lockfile:

```bash
# Atualiza todas as dependencias
aetherc pkg update

# Atualiza apenas uma dependencia especifica
aetherc pkg update aether_http
```

### 4.5 Remover Dependências (`aetherc pkg remove` ou `rm`)

Remove a dependência do manifesto `aether.json`, atualiza o `aether.lock` e remove os arquivos de `.aether/deps/`:

```bash
aetherc pkg remove aether_http
# ou de forma abreviada:
aetherc pkg rm aether_http
```

### 4.6 Limpar Cache Global (`aetherc pkg clean`)

Remove o cache compartilhado em `~/.aether/cache/`, forçando novos downloads limpos se necessário:

```bash
aetherc pkg clean
```
