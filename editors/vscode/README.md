# Extensão Oficial do VS Code para Aether (AetherLang) 🚀

Esta extensão adiciona suporte completo de primeira classe para a linguagem de programação **Aether** (`.aeth`) no Visual Studio Code e derivados (Cursor, VSCodium, Windsurf).

---

## 🌟 Recursos

1. **Realce de Sintaxe Completo (TextMate Grammar):**
   - Cores semânticas para módulos, records, enums algébricos, contratos (`require`/`ensure`), operadores e literais.
   - Destaque especial para palavras de sistema de posse (`borrow`, `take`, `mut`).
   - Cores nativas para mônades embutidas (`Result`, `Option`, `Ok`, `Err`, `Some`, `None`).
2. **Snippets Inteligentes:**
   - Crie módulos, funções com contratos, records, enums com dados e blocos de casamento exaustivo (`match`) instantaneamente teclando `Tab`.
3. **Diagnósticos Nativos e Modo IA em Tempo Real:**
   - Integração direta com a flag `--emit-json-diagnostics` do compilador `aetherc`.
   - Erros de compilação e violações de posse (*Borrow Checker*) aparecem sublinhados no código e listados na aba **Problems** do VS Code, incluindo sugestões inteligentes de correção (*suggested fixes*).
4. **Comandos Integrados:**
   - `Aether: Compilar Arquivo Atual (Backend Pascal)`: compila para executável nativo via Free Pascal.
   - `Aether: Compilar Arquivo Atual (Backend C99 / GCC)`: compila para executável nativo via GCC.
   - `Aether: Analisar e Atualizar Diagnósticos (Modo IA)`.

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
code --install-extension aether-lang-0.7.0.vsix
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
