# Guia do Iniciante no Aether

Bem-vindo ao **Aether**! Este guia foi feito para você configurar o seu ambiente de desenvolvimento e compilar o seu primeiro programa em poucos minutos.

---

## 1. Requisitos do Sistema

O compilador oficial do Aether (`aetherc`) gera código nativo através de dois backends altamente otimizados:

### No Windows:
1. **Free Pascal (ou Lazarus):**
   - Baixe e instale o Lazarus ou Free Pascal em: [https://www.lazarus-ide.org/](https://www.lazarus-ide.org/)
   - Garanta que o comando `fpc` esteja no seu PATH ou na pasta padrão `C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe`.
2. **MSYS2 com GCC (Opcional, para compilar via C99):**
   - Baixe o MSYS2 em: [https://www.msys2.org/](https://www.msys2.org/)
   - No terminal do MSYS2, instale o compilador C UCRT64:
     ```bash
     pacman -S mingw-w64-ucrt-x86_64-gcc
     ```

### No Linux e macOS:
- Instale o Free Pascal e o GCC padrão do seu sistema:
  - **Debian / Ubuntu:** `sudo apt install fpc build-essential`
  - **Fedora:** `sudo dnf install fpc gcc`
  - **Arch Linux:** `sudo pacman -S fpc gcc`
  - **macOS:** `brew install fpc` e ferramentas Xcode (`xcode-select --install`).

---

## 2. Verificando o Ambiente com `aetherc --doctor`

Para ter certeza de que o seu ambiente está 100% pronto, execute no terminal do projeto:

```bash
./bin/aetherc --doctor
```

O compilador fará uma varredura automática e exibirá o relatório:
```text
--------------------------------------------------------
   Diagnostico do Ambiente Aether (aetherc --doctor)    
--------------------------------------------------------
[OK] Free Pascal (FPC) Encontrado:
     Caminho : fpc.exe
     Versao  : 3.2.2

[OK] Compilador C (GCC / MSYS2) Encontrado:
     Caminho : C:\msys64\ucrt64\bin\gcc.exe
     Versao  : gcc.exe (Rev3, Built by MSYS2 project) 16.2.0
     Ambiente: MSYS2 UCRT64 Ativo (C:\msys64\ucrt64\bin)
--------------------------------------------------------
Status Geral: Perfeito! Ambos os backends (Pascal e C) estao operacionais.
--------------------------------------------------------
```

---

## 3. Seu Primeiro Programa ("Hello World")

Crie um arquivo chamado `meu_primeiro_app.aeth`:

```pascal
module MeuPrimeiroApp;

program Main;
begin
    PrintLn("Ola, Mundo do Aether!");
    PrintLn("Seguranca do Rust com a elegancia do Pascal.");
end.
```

### Compilando para Executável Nativo:

Para compilar usando o **Backend Object Pascal** (Padrão):
```bash
./bin/aetherc meu_primeiro_app.aeth
```
O compilador analisará a sintaxe, verificará os tipos e a posse da memória, gerará o código intermediário em `bin/generated/meu_primeiro_app.pas` e chamará o Free Pascal para gerar `meu_primeiro_app.exe`.

Para executar:
```bash
./meu_primeiro_app.exe
```

Para compilar usando o **Backend C99** (via GCC):
```bash
./bin/aetherc meu_primeiro_app.aeth --target=c
```

---

## 4. Próximos Passos
Agora que você já tem o compilador rodando, confira:
- [Conceitos de Posse e Empréstimo](file:///c:/Users/Pichau/Documents/aether/docs/usuario/CONCEITOS_POSSE_E_BORROW.md) para entender como o Aether gerencia memória sem Garbage Collector.
- [Exemplos Oficiais](file:///c:/Users/Pichau/Documents/aether/examples/) com código pronto para testes.
