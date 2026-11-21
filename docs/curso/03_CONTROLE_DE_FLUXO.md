# Lição 3: Controle de Fluxo sem Ambiguidade

No Pascal tradicional, uma das maiores fontes de confusão visual era a regra de ponto e vírgula antes do `else` e a necessidade de encher o código de `begin...end`.

No Aether, modernizamos isso com a sintaxe limpa inspirada no Ada: **todo bloco de controle fecha com `end;`**.

---

## 1. Condicional `if...then...else...end;`

No Aether:
- Não precisa de `begin...end` dentro do `if`;
- Pode colocar ponto e vírgula antes do `else` sem erro;
- Elimina para sempre o clássico problema do *dangling else*.

```pascal
module CondicionalDemo;

program Main;
var
    pontuacao: Int32;
begin
    pontuacao := 85;

    if pontuacao >= 90 then
        PrintLn("Conceito A: Excelente!");
    else
        if pontuacao >= 70 then
            PrintLn("Conceito B: Aprovado!");
        else
            PrintLn("Conceito C: Precisa de recuperacao.");
        end;
    end;
end.
```

---

## 2. Operadores Relacionais e Lógicos

O Aether usa palavras legíveis em vez de símbolos criptográficos:

| Operador | Significado | Exemplo |
|:---|:---|:---|
| `=` | Igual | `if x = 10 then` |
| `<>` | Diferente | `if x <> 0 then` |
| `<`, `<=`, `>`, `>=` | Menor, Menor ou Igual, Maior, Maior ou Igual | `if idade >= 18 then` |
| `and` | E lógico | `if (x > 0) and (x < 100) then` |
| `or` | OU lógico | `if (x = 0) or (y = 0) then` |
| `not` | NÃO lógico (Negação) | `if not ativo then` |

---

## 3. Estruturas de Repetição (`while`)

O loop `while` repete um conjunto de instruções enquanto uma condição for verdadeira:

```pascal
module LoopDemo;

program Main;
var
    i: Int32;
begin
    i := 1;

    while i <= 5 do
        PrintLn("Contagem: %d", i);
        i := i + 1;
    end;

    PrintLn("Loop finalizado com sucesso!");
end.
```

---

## 4. Exercício Prático
1. Escreva um programa que declare uma variável `saldo: Float64`.
2. Se o saldo for maior que zero, imprima "Saldo Positivo". Se for igual a zero, imprima "Conta Zerada". Caso contrário, imprima "Saldo Devedor".

Quando concluir, avance para a **[Lição 4: Funções e Contratos Nativos](file:///c:/Users/Pichau/Documents/aether/docs/curso/04_FUNCOES_E_CONTRATOS.md)**!
