# Extensão Oficial da Linguagem Aether para VS Code

Suporte inteligente completo para o ecossistema da linguagem de programação **Aether** (`aetherc`).

---

## 🚀 Funcionalidades

1. **Destaque Sintático Avançado**:
   - Palavras-chave de controle de fluxo e contratos: `module`, `import`, `function`, `contract`, `require`, `ensure`, `type`, `record`, `enum`, `trait`, `impl`, `for`, `match`, `case`.
   - Semântica de posse e concorrência: `borrow`, `take`, `mut borrow`, `mut`, `own`.
   - Tipos nativos e mônades: `Int8`..`Int64`, `UInt8`..`UInt64`, `Float32`, `Float64`, `Bool`, `String`, `Void`, `Result<T, E>`, `Option<T>`, `Box<T>`.

2. **Language Server Protocol (LSP Integrado)**:
   - Conexão nativa com `aetherc lsp`.
   - **Autocompletion**: Palavras-chave, tipos primitivos, mônades, funções com assinaturas e métodos de traits/UFCS.
   - **Hover**: Tipagem deduzida, exibição de contratos e documentação de semântica de memória.
   - **Go-to-Definition**: Navegação rápida para declarações de funções, records, enums e traits.
   - **Diagnósticos em Tempo Real**: Erros de sintaxe e violações do Borrow Checker publicados instantaneamente.

3. **Snippets Úteis**:
   - `module`: Estrutura de módulo executável.
   - `fn`: Função com cláusulas contratuais (`require` / `ensure`).
   - `trait`: Interface trait.
   - `impl`: Implementação de trait para tipo.
   - `record`: Declaração de struct record.
   - `enum`: Tipo algébrico enum.
   - `match`: Casamento de padrão em Result.
   - `test`: Função de teste unitário.

4. **Comandos de Build e Testes**:
   - `Aether: Compilar Arquivo Atual (Backend Pascal)`
   - `Aether: Compilar Arquivo Atual (Backend C99 / GCC)`
   - `Aether: Executar Testes Unitarios (aetherc test)`
   - `Aether: Reiniciar Servidor de Linguagem (LSP)`

---

## 🛠️ Instalação Local

Para testar e usar no VS Code local:

1. Copie a pasta `ide/vscode` para a pasta de extensões do seu VS Code:
   - No Windows: `%USERPROFILE%\.vscode\extensions\aether-lang`
2. Reinicie ou recarregue o Visual Studio Code (`Ctrl+Shift+P` -> `Developer: Reload Window`).
3. Abra qualquer arquivo com extensão `.aeth`.
