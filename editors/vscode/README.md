# Extensão Oficial do VS Code para Aether (AetherLang) 🚀

Esta extensão adiciona suporte completo de primeira classe para a linguagem de programação **Aether** (`.aeth`) no Visual Studio Code e derivados (Cursor, VSCodium, Windsurf).

---

## 🌟 Recursos

1. **LSP Nativo de Alta Performance (`aetherc --lsp`):**
   - **Formatação Canônica (`Shift + Alt + F` / `formatOnSave`)**: Integração direta com `textDocument/formatting` chamando o motor canônico `uAetherFormatter.pas` (indentação de 4 espaços, operadores normalizados).
   - **Refatoração Segura (`F2` / Rename Symbol)**: Renomeação atômica e consistente via `textDocument/rename` sem afetar literais ou comentários.
   - **Ações Rápidas de Correção (`Ctrl + .` / Quick-Fix)**: Sugestões instantâneas para resolução de transferências indevidas de posse (`borrow` ou `mut borrow`) e adição automática de imports da biblioteca padrão (`std.fs`, `std.time`, `std.http`, `std.json`).
   - **Autocompletar Inteligente (`Ctrl + Espaço`)**: Palavras-chave, modificadores de posse, tipos primitivos, mônades e símbolos locais.
   - **Informações ao Passar o Cursor (Hover)**: Assinaturas de funções, tipos e documentação explicativa da semântica de posse.
   - **Ir para a Definição (`F12`)**: Navegação instantânea para funções, tipos records, traits e enums.
2. **Realce de Sintaxe Completo (TextMate Grammar):**
   - Cores semânticas para módulos, records, enums algébricos, contratos (`require`/`ensure`), operadores e literais.
   - Destaque especial para palavras de sistema de posse (`borrow`, `take`, `mut`).
   - Cores nativas para mônades embutidas (`Result`, `Option`, `Ok`, `Err`, `Some`, `None`).
3. **Snippets Inteligentes:**
   - Crie módulos, funções com contratos, records, enums com dados e blocos de casamento exaustivo (`match`) instantaneamente teclando `Tab`.
4. **Comandos Integrados:**
   - `Aether: Formatar Documento (Shift+Alt+F)`.
   - `Aether: Compilar Arquivo Atual (Backend Pascal)`.
   - `Aether: Compilar Arquivo Atual (Backend C99 / GCC)`.
   - `Aether: Compilar Projeto (Build)`.
   - `Aether: Executar Projeto (Run)`.

---

## 📦 Como Instalar Localmente no seu VS Code

Você pode instalar a extensão em **menos de 30 segundos** usando qualquer um dos métodos abaixo:

### Método 1: Cópia Direta para a Pasta de Extensões (Recomendado)

Abra o terminal (PowerShell no Windows) e execute:

```powershell
# Cria o diretório de extensão local do VS Code
New-Item -ItemType Directory -Path "$HOME/.vscode/extensions/aether-lang" -Force

# Copia os arquivos da extensão
Copy-Item -Path "editors/vscode/*" -Destination "$HOME/.vscode/extensions/aether-lang" -Recurse -Force
```

Em seguida, basta reiniciar ou recarregar o VS Code (`Ctrl + Shift + P` -> `Developer: Reload Window`). Qualquer arquivo `.aeth` já será aberto com realce completo e ferramentas ativas!

### Método 2: Empacotamento VSIX (via `vsce`)

Se tiver o utilitário `vsce` do npm instalado:

```bash
cd editors/vscode
npx @vscode/vsce package
code --install-extension aether-lang-1.0.0.vsix
```

---

## ⚙️ Configurações Opcionais

No seu `settings.json` do VS Code:

```json
{
  "aether.compilerPath": "c:/Users/Pichau/Documents/aether/bin/aetherc.exe"
}
```
*(Se omitido, a extensão busca automaticamente o executável `bin/aetherc.exe` dentro do workspace ativo).*
