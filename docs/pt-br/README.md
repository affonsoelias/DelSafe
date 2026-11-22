# Linguagem de Programação Aether (Documentação em Português)

> **Uma linguagem de sistemas moderna com a clareza estruturada de Object Pascal e Ada, a segurança estática de memória do Rust, interoperabilidade bilateral nativa com C e Pascal, e concebida especialmente como a linguagem de alta performance para o framework BlaiseVue e para colaboração perfeita com Inteligências Artificiais.**

---

## 🧭 Visão Geral

O **Aether** nasceu da busca pelo equilíbrio perfeito no desenvolvimento de software de alta confiabilidade:

1. **Mais segura que Object Pascal**: Elimina *Access Violations*, vazamentos de memória (*memory leaks*) e acessos após liberação (*use-after-free*) em tempo de compilação sem custos ocultos de runtime ou GC.
2. **Sem a complexidade intimidadora do Rust**: Implementa as garantias de posse, empréstimo (`borrow`) e movimentação (`take`) com uma semântica limpa, amigável e acessível.
3. **Concebida para IAs (AI-Native)**: Gramática estruturada, blocos delimitados explícitos e diagnósticos estruturados em JSON (`--emit-json-diag`) com sugestões diretas de correção (*auto-fix*).
4. **Interoperabilidade Total**: Compilação nativa para **Free Pascal** e **C99 (GCC)**, além de alvos WebAssembly (`.wasm`) e JavaScript (`.js`).
5. **Zephyr para o BlaiseVue**: Motor de backend de alto desempenho alocado em `vendor/zephyr`, combinando a simplicidade de APIs modernas com a performance de sockets de kernel.

---

## 🚀 Sintaxe Rápida

```aether
module Exemplo;

[derive(Debug, JSON, Clone, Equals)]
type
    Usuario = record
        id: Int32;
        nome: String;
        ativo: Bool;
    end;

function AtualizarNome(mut borrow u: Usuario; novo_nome: String)
begin
    u.nome := novo_nome;
end;

program Main;
var
    user: Usuario;
    clone: Usuario;
begin
    user := Usuario(1, "Alice", true);
    PrintLn("Debug: %s", user.ToString());
    PrintLn("JSON:  %s", user.ToJSON());

    AtualizarNome(mut borrow user, "Bob");
    clone := user.Clone();

    if user.Equals(borrow clone) then
        PrintLn("Usuario atualizado e clonado com sucesso!");
end.
```

---

## 🛠️ Compilação e Uso

```bash
# Compilar e rodar
./bin/aetherc run main.aeth

# Compilar com o backend C99 otimizado
./bin/aetherc run main.aeth --target=c

# Executar testes da suíte
./bin/aetherc test
```
