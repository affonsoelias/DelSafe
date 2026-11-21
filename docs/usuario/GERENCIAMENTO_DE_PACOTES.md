# Gerenciamento de Pacotes e Dependências no Aether

O **Aether** utiliza o gerenciador de pacotes descentralizado **Boss / Boss4Delphi** para controlar bibliotecas e módulos externos.

---

## 1. Por que usar o Boss?

1. **Descentralizado e Pronto:** O Boss resolve downloads direto do GitHub/GitLab, controla versões semânticas (SemVer) e trava integridade de pacotes com `boss.lock`.
2. **Totalmente Agnóstico:** O Boss apenas baixa os pacotes para a pasta local `modules/` do seu projeto.
3. **Ecossistema Pascal Amplo:** Você ganha acesso imediato a centenas de bibliotecas existentes na comunidade Free Pascal e Delphi.

---

## 2. Estrutura Padrão de um Projeto Aether

Ao iniciar um novo projeto:

```bash
mkdir MeuApp
cd MeuApp
boss init
```

Estrutura resultante no disco:
```text
MeuApp/
├── boss.json            <- Manifesto de dependências do projeto
├── boss.lock            <- Hash de travamento de versões
├── modules/             <- Onde o Boss baixa as dependências
│   ├── aether-http/
│   │   ├── boss.json
│   │   └── src/
│   │       └── HttpServer.aeth
│   └── aether-sqlite/
│       ├── boss.json
│       └── src/
│           ├── sqlite3.c
│           └── SQLite.aeth
└── src/
    └── main.aeth        <- Ponto de entrada da aplicação
```

---

## 3. O Manifesto `boss.json`

Exemplo de configuração de um projeto ou pacote Aether:

```json
{
  "name": "meu-app-aether",
  "description": "Aplicacao de alta performance escrita em Aether",
  "version": "1.0.0",
  "homepage": "https://github.com/usuario/meu-app-aether",
  "mainSrc": "src/main.aeth",
  "dependencies": {
    "github.com/aetherlang/aether-http": "^1.2.0",
    "github.com/aetherlang/aether-sqlite": "^3.45.0"
  }
}
```

---

## 4. Instalando e Atualizando Dependências

Para instalar uma nova dependência:
```bash
boss install github.com/aetherlang/aether-http
```

Para atualizar todas as dependências:
```bash
boss update
```
