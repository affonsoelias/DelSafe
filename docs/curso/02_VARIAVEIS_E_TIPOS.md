# Lição 2: Variáveis e Sistema de Tipos

Uma das maiores inovações de linguagens modernas como Rust é a **imutabilidade por padrão**. No Aether, unimos esse princípio com a sintaxe explícita do Pascal.

---

## 1. `let` (Imutável) vs `var` (Mutável)

No Aether, você escolhe conscientemente se um dado pode mudar ou não:

- **`let` (Imutável - Recomendado):** Uma vez definido o valor, ele **nunca mais pode ser alterado**. Evita 90% dos bugs em sistemas complexos.
- **`var` (Mutável):** Uma variável tradicional que pode ter seu conteúdo modificado ao longo do tempo.

### Exemplo:
```pascal
module VariaveisDemo;

program Main;
var
    contador: Int32;
let
    taxa_fixa: Float64 := 0.15;
begin
    contador := 10;
    contador := contador + 1; // PERFEITO: 'contador' foi declarado com 'var'

    // ERRO DE COMPILAÇÃO!
    // taxa_fixa := 0.20; // O compilador barra imediatamente: Erro E0384!

    PrintLn("Contador: %d, Taxa: %f", contador, taxa_fixa);
end.
```

---

## 2. Tipos Primitivos Nativos

O Aether possui tipos numéricos com tamanho explícito e sem ambiguidades de plataforma:

| Tipo | Descrição | Exemplo |
|:---|:---|:---|
| **`Int8` .. `Int64`** | Inteiros com sinal (8, 16, 32 ou 64 bits) | `-42`, `1000` |
| **`UInt8` .. `UInt64`** | Inteiros sem sinal (apenas positivos) | `0`, `65535` |
| **`Float32` / `Float64`** | Ponto flutuante IEEE (precisão simples e dupla) | `3.14159`, `0.001` |
| **`Bool`** | Booleano | `true`, `false` |
| **`Char`** | Caractere Unicode (aspas simples) | `'A'`, `'\n'` |
| **`String`** | Texto UTF-8 gerenciado (aspas duplas) | `"Ola, Aether!"` |

---

## 3. Atribuição e Operadores Aritméticos

Seguindo a clareza do Pascal, o Aether utiliza **`:=`** para atribuição (para não confundir com o operador de igualdade `=`):

```pascal
module MatematicaSimples;

program Main;
var
    a: Int32;
    b: Int32;
    soma: Int32;
    divisao: Float64;
begin
    a := 25;
    b := 4;

    soma := a + b;           // 29
    let subtracao := a - b;  // 21 (let imutavel)
    let produto := a * b;    // 100
    let resto := a mod b;    // 1

    PrintLn("Soma: %d, Produto: %d, Resto: %d", soma, produto, resto);
end.
```

---

## 4. Exercício Prático
1. Crie um programa que declare a sua idade em `var` e o seu ano de nascimento em `let`.
2. Tente alterar o valor do ano de nascimento e observe a mensagem de erro que o compilador `aetherc` emite informando a violação de imutabilidade.

Quando terminar, avance para a **[Lição 3: Controle de Fluxo sem Ambiguidade](file:///c:/Users/Pichau/Documents/aether/docs/curso/03_CONTROLE_DE_FLUXO.md)**!
