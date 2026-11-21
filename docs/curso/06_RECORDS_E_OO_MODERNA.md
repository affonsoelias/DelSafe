# Lição 6: Records e Orientação a Objetos Moderna (UFCS)

No Aether, não usamos a Orientação a Objetos antiga baseada em herança profunda de classes (`class A extends B`), pois ela é uma das maiores causas de vazamentos e ponteiros nulos da computação.

Em vez disso, usamos a **Orientação a Objetos Moderna baseada em Dados e Comportamento**:
- Estrutura clara via `record`;
- Construtores com campos nomeados;
- Sintaxe de método via **UFCS (*Uniform Function Call Syntax*)**.

---

## 1. Declarando e Instanciando Records

Um `record` agrupa campos de dados:

```pascal
module RecordDemo;

type
    Pessoa = record
        id: UInt32;
        nome: String;
        idade: UInt8;
    end;

program Main;
var
    p: Pessoa;
begin
    // Construtor com campos nomeados (claro e autodocumentado):
    p := Pessoa(id: 1, nome: "Carlos", idade: 30);

    PrintLn("Pessoa ID: %d, Nome: %s, Idade: %d", p.id, p.nome, p.idade);
end.
```

---

## 2. Métodos e UFCS (*Uniform Function Call Syntax*)

Como associar métodos a um `record` sem a complexidade de classes tradicionais?

Basta criar uma função cujo primeiro parâmetro receba o `record` por `borrow`! O compilador Aether automaticamente permite que ela seja chamada no estilo método:

```pascal
module MetodosDemo;

type
    Retangulo = record
        largura: Float64;
        altura: Float64;
    end;

// Funcao pura recebendo o record por emprestimo (borrow):
function CalcularArea(borrow r: Retangulo): Float64
begin
    return r.largura * r.altura;
end;

function Exibir(borrow r: Retangulo): Void
begin
    PrintLn("Retangulo [%f x %f] -> Area: %f", r.largura, r.altura, r.CalcularArea());
end;

program Main;
var
    box: Retangulo;
begin
    box := Retangulo(largura: 10.0, altura: 5.0);

    // Chamada no estilo Orientado a Objetos:
    let area := box.CalcularArea();
    PrintLn("Area calculada: %f", area);

    // Encadeamento limpo:
    box.Exibir();
end.
```

### O que acontece por baixo dos panos?
`box.CalcularArea()` é traduzido diretamente para `CalcularArea(borrow box)`. Você ganha toda a elegância visual da OO, com a velocidade e segurança de uma função pura!

---

## 3. Exercício Prático
1. Crie um record `ContaBancaria` com `titular: String` e `saldo: Float64`.
2. Crie uma função `ExibirSaldo(borrow c: ContaBancaria): Void`.
3. Instancie uma conta e chame o método usando a sintaxe fluente `minha_conta.ExibirSaldo()`.

Avance para a **[Lição 7: Enums Algébricos e o Poder do Match](file:///c:/Users/Pichau/Documents/aether/docs/curso/07_ENUMS_E_MATCH_EXAUSTIVO.md)**!
