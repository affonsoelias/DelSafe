# Lição 7: Enums Algébricos e o Poder do Match

Em linguagens antigas, um `enum` serve apenas para dar nomes a números inteiros. No Aether, os `enums` são **Tipos Algébricos de Dados (ADTs)**, capazes de carregar dados diferentes em cada variante!

---

## 1. Enums com Dados (Variantes Ricas)

Imagine um sistema de pagamento:

```pascal
module PagamentoDemo;

type
    FormaPagamento = enum
        Dinheiro,
        CartaoCredito(parcelas: UInt8),
        Pix(chave: String)
    end;
```

Cada variante carrega exatamente a informação necessária:
- `Dinheiro`: Não precisa de dados extras;
- `CartaoCredito`: Carrega o número de parcelas;
- `Pix`: Carrega a chave PIX em texto.

---

## 2. Casamento de Padrões Exaustivo (`match`)

Para inspecionar um `enum`, usamos a instrução **`match`**:

```pascal
module MatchDemo;

type
    StatusPedido = enum
        Pendente,
        Enviado,
        Entregue,
        Cancelado
    end;

program Main;
var
    status: StatusPedido;
begin
    status := StatusPedido.Enviado;

    match status do
        case StatusPedido.Pendente:
            PrintLn("Aguardando aprovacao do pagamento.");
        case StatusPedido.Enviado:
            PrintLn("O produto esta a caminho da sua residencia!");
        case StatusPedido.Entregue:
            PrintLn("Pacote entregue com sucesso.");
        case StatusPedido.Cancelado:
            PrintLn("Pedido cancelado pelo cliente.");
    end;
end.
```

---

## 3. A Checagem de Exaustividade do Compilador

E se você esquecer de tratar uma das variantes (por exemplo, `Cancelado`)?

No C ou Pascal antigo, o compilador não avisa nada e seu programa gera um bug silencioso em produção.

No Aether, **o compilador se recusa a gerar o binário** e avisa exatamente qual caso você esqueceu:
```text
Erro de Compilacao: [Erro Semantico E0004 em 16:5]: Match nao-exaustivo no enum "StatusPedido". 
  Falta cobrir a variante "Cancelado" (ou adicionar caso "_:")
```

Se você não quiser listar todas as variantes, pode usar o coringa **`_:`** para cobrir o caso padrão:
```pascal
    match status do
        case StatusPedido.Entregue:
            PrintLn("Entregue!");
        case _:
            PrintLn("Outro status qualquer.");
    end;
```

---

## 4. Exercício Prático
1. Crie um enum `Conexao` com variantes `Conectado`, `Desconectado` e `Falha`.
2. Escreva um `match` para esse enum e tente remover uma das variantes propositalmente para ver o compilador exigir a cobertura exaustiva.

Avance para a **[Lição 8: Adeus Ponteiros Nulos com Result e Option](file:///c:/Users/Pichau/Documents/aether/docs/curso/08_TRATAMENTO_DE_ERROS_RESULT_E_OPTION.md)**!
