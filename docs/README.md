# Documentação Oficial da Linguagem Aether (AetherLang)

> **"A clareza, estrutura e disciplina do Object Pascal com a segurança estrita de memória do Rust e arquitetura projetada para humanos e IAs."**

Bem-vindo à documentação oficial do **Aether**. A documentação está estruturada em seções para atender desde iniciantes até desenvolvedores de compiladores, engenheiros de ferramentas e criadores de aplicações no ecossistema Pascal e BlaiseVue.

---

## 📚 Mapa da Documentação

### 🎓 0. [Curso Oficial Aether do Zero](file:///c:/Users/Pichau/Documents/aether/docs/curso/README.md)
Trilha didática completa em 9 lições práticas para aprender Aether do início ao primeiro projeto real:
- **[Ementa e Índice do Curso](file:///c:/Users/Pichau/Documents/aether/docs/curso/README.md):** Da sintaxe básica a contratos, ownership, records, enums algébricos e projeto final.

---

### 👤 1. [Documentação do Usuário](file:///c:/Users/Pichau/Documents/aether/docs/usuario/)
Manuais práticos para quem deseja programar e criar aplicações em Aether:
- **[Guia do Iniciante](file:///c:/Users/Pichau/Documents/aether/docs/usuario/GUIA_DO_INICIANTE.md):** Requisitos de ambiente (Free Pascal e MSYS2 GCC), instalação, diagnóstico com `aetherc --doctor`, primeiro programa nativo e criação de projetos com `aetherc new`.
- **[Guia Completo da CLI](file:///c:/Users/Pichau/Documents/aether/docs/usuario/GUIA_DA_CLI.md):** Referência de todos os comandos do compilador `aetherc` (`build`, `run`, `test`, `clean`, `emit`, `pkg`, `--watch`, etc.).
- **[Gerenciamento de Pacotes (`aetherc pkg`)](file:///c:/Users/Pichau/Documents/aether/docs/usuario/GERENCIAMENTO_DE_PACOTES.md):** Gerenciador nativo de dependências Git e locais, lockfile criptográfico `aether.lock` e auditoria de segurança `aetherc pkg audit`.
- **[Conceitos de Posse e Empréstimo](file:///c:/Users/Pichau/Documents/aether/docs/usuario/CONCEITOS_POSSE_E_BORROW.md):** Entenda `take`, `borrow` e `mut borrow` de forma intuitiva, sem complicação matemática.

---

### ⚙️ 2. [Documentação Técnica](file:///c:/Users/Pichau/Documents/aether/docs/tecnica/)
Especificações formais e detalhes de engenharia de software do Aether:
- **[Integração com BlaiseVue](file:///c:/Users/Pichau/Documents/aether/docs/tecnica/INTEGRACAO_BLAISEVUE_E_PASCAL.md):** Como usar o Aether no BlaiseVue, emissão em formato Unit (`--unit`), customização de diretório (`--out-dir`) e hot-reload (`--watch`).
- **[Especificação Formal da Linguagem](file:///c:/Users/Pichau/Documents/aether/docs/tecnica/ESPECIFICACAO_LINGUAGEM.md):** Gramática EBNF completa, regras léxicas, sistema de tipos, UFCS, interoperabilidade zero-boilerplate (`import pascal` / `import c`), Traits e Sockets.
- **[Segurança de Memória Estática](file:///c:/Users/Pichau/Documents/aether/docs/tecnica/SEGURANCA_DE_MEMORIA.md):** Prova formal de eliminação de *Use-After-Free*, *Double-Free*, *Data Races* e *Null Pointers*.
- **[Arquitetura do Compilador](file:///c:/Users/Pichau/Documents/aether/docs/tecnica/ARQUITETURA_DO_COMPILADOR.md):** Funcionamento interno do `aetherc` (Lexer, Parser recursivo, Type Checker, Borrow Checker e Emissores Pascal/C).
- **[Modo IA & Diagnósticos em JSON](file:///c:/Users/Pichau/Documents/aether/docs/tecnica/MODO_IA_DIAGNOSTICO_JSON.md):** Schema estruturado para ferramentas, IDEs e cooperação com agentes inteligentes.

---

### 🗺️ 3. [Planejamento e Roadmap](file:///c:/Users/Pichau/Documents/aether/docs/planejamento/)
Acompanhamento da evolução do projeto:
- **[Roadmap de Desenvolvimento](file:///c:/Users/Pichau/Documents/aether/docs/planejamento/ROADMAP_DE_DESENVOLVIMENTO.md):** Histórico completo de todas as fases implementadas (Fases 1 a 21.1) e planejamento da Fase 22 (Bootstrapping do Compilador Auto-Hospedado).
