# Lição 4: Funções e Contratos Nativos

No Aether, funções são cidadãs de primeira classe. Além disso, trazemos um dos recursos mais poderosos da engenharia de software formal (estilo Ada e Eiffel): **Contratos Nativos (*Design by Contract*)**.

---

## 1. Declaração Básica de Funções

Toda função possui:
- Nome e lista de parâmetros com tipos explícitos;
- Tipo de retorno explícito (ou `Void` se não retornar nada);
- Corpo delimitado por `begin...end;`.

```pascal
module FuncoesDemo;

function Somar(borrow a: Int32; borrow b: Int32): Int32
begin
    return a + b;
end;

function ExibirBoasVindas(borrow usuario: String): Void
begin
    PrintLn("Ola, %s! Seja bem-vindo ao Aether.", usuario);
end;

program Main;
var
    total: Int32;
begin
    total := Somar(borrow 10, borrow 25);
    PrintLn("Total: %d", total);

    ExibirBoasVindas(borrow "Maria");
end.
```

---

## 2. Contratos Nativos (`require` e `ensure`)

Quantas vezes um programa quebra porque recebeu um número negativo ou um divisor zero?

No Aether, você blinda a função diretamente na sua assinatura com um bloco `contract`:
- **`require` (Pré-condições):** O que **deve ser verdade antes** da função começar a rodar.
- **`ensure` (Pós-condições):** O que a função **garante que será verdade quando terminar**.

```pascal
module ContratosDemo;

function CalcularDesconto(borrow valor: Float64; borrow percentual: Float64): Float64
contract
    require
        valor >= 0.0;
        (percentual >= 0.0) and (percentual <= 100.0);
    ensure
        result <= valor;
begin
    return valor - (valor * (percentual / 100.0));
end;

program Main;
var
    final: Float64;
begin
    final := CalcularDesconto(borrow 200.0, borrow 10.0);
    PrintLn("Valor com desconto: %f", final);
end.
```

### O que acontece se o contrato for violado?
Se alguém chamar `CalcularDesconto(borrow 200.0, borrow 150.0)`, o contrato falha na hora com uma mensagem clara, impedindo corrupção de dados ou cálculos inválidos silenciosos.

---

## 3. Exercício Prático
1. Escreva uma função `CalcularMedia(borrow nota1: Float64; borrow nota2: Float64): Float64`.
2. Adicione um contrato `require` garantindo que ambas as notas estejam entre `0.0` e `10.0`.
3. Teste a função no programa principal.

Avance agora para a **[Lição 5: O Coração do Aether (Posse e Empréstimo)](file:///c:/Users/Pichau/Documents/aether/docs/curso/05_O_CORACAO_DO_AETHER_POSSE_E_BORROW.md)**!
