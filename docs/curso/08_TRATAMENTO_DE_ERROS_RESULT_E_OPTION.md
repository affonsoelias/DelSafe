# Lição 8: Tratamento Robusto de Erros (Result e Option)

Em muitas linguagens tradicionais, erros e ausência de valores são tratados com duas abordagens perigosas:
1. **O Ponteiro Nulo (`nil` / `null`):** Chamado pelo próprio inventor Tony Hoare de seu *"erro de um bilhão de dólares"*, pois tentar acessar algo nulo gera travamentos inesperados em tempo de execução (*Null Pointer Exceptions* ou *Segmentation Faults*).
2. **Exceções Ocultas (`try..catch`):** Qualquer função pode lançar uma exceção sem avisar na assinatura, tornando o fluxo do programa imprevisível.

No **Aether**, **não existem ponteiros nulos** nem exceções silenciosas. Todo erro ou ausência de valor é explícito no sistema de tipos através de **`Option<T>`** e **`Result<T, E>`**.

---

## 1. O Tipo `Option<T>`: Adeus ao `nil`

Quando uma operação pode ou não retornar um valor (por exemplo, buscar um item em uma lista por ID), usamos `Option<T>`.

Um `Option<T>` tem apenas duas possibilidades:
- `Some(valor)`: O dado foi encontrado e está presente;
- `None`: O dado não existe.

```pascal
module OptionDemo;

function BuscarPorId(borrow id: UInt32): Option<String>
begin
    if id = 42 then
        return Some("Guia do Mochileiro");
    else
        return None;
    end;
end;

program Main;
var
    item: Option<String>;
begin
    item := BuscarPorId(borrow 42);

    match item do
        case Some(let nome):
            PrintLn("Item encontrado: %s", nome);
        case None:
            PrintLn("Nenhum item com esse ID.");
    end;
end.
```

> **Por que isso é seguro?** Você **não pode** usar o valor dentro de um `Option` sem antes desembalá-lo com `match`. É impossível acontecer um *Null Pointer Exception* por esquecimento!

---

## 2. O Tipo `Result<T, E>`: Sucesso ou Erro Explícito

Quando uma função pode falhar e precisamos explicar **o motivo** da falha, usamos `Result<T, E>`:
- `T`: O tipo do valor retornado em caso de **sucesso** (`Ok`);
- `E`: O tipo do erro em caso de **falha** (`Err`), geralmente um `enum`.

### Exemplo Prático: Divisão Segura

```pascal
module ErroDemo;

type
    ErroMatematico = enum
        DivisaoPorZero,
        Overflow
    end;

function Dividir(borrow a: Float64; borrow b: Float64): Result<Float64, ErroMatematico>
contract
    require
        true;
    ensure
        result.is_ok implies b <> 0.0;
begin
    if b = 0.0 then
        return Err(ErroMatematico.DivisaoPorZero);
    else
        return Ok(a / b);
    end;
end;

program Main;
var
    res: Result<Float64, ErroMatematico>;
begin
    res := Dividir(borrow 50.0, borrow 0.0);

    match res do
        case Ok(let valor):
            PrintLn("Resultado do calculo: %f", valor);
        case Err(ErroMatematico.DivisaoPorZero):
            PrintLn("Erro: Nao e permitido dividir por zero!");
        case Err(ErroMatematico.Overflow):
            PrintLn("Erro: O valor excedeu a precisao.");
    end;
end.
```

---

## 3. A Assinatura Diz Toda a Verdade

Em linguagens antigas:
```pascal
// Função misteriosa: pode travar o programa? Lança exceção? Retorna nil? Ninguém sabe.
function CarregarArquivo(caminho: String): Conteudo;
```

No Aether:
```pascal
// Transparente e à prova de falhas:
function CarregarArquivo(borrow caminho: String): Result<Conteudo, ErroArquivo>
```

Olhando apenas a assinatura, qualquer programador ou inteligência artificial sabe:
1. O caminho é emprestado de forma somente leitura (`borrow`);
2. A função não trava o processo;
3. Se der certo, entrega um `Conteudo`;
4. Se der errado, entrega um `ErroArquivo` específico que **deve** ser tratado.

---

## 4. Resumo da Lição

| Situação | Abordagem Antiga | Abordagem Aether |
| :--- | :--- | :--- |
| Ausência de dado | `nil` / `null` | `Option<T>` (`Some` ou `None`) |
| Operação com risco de falha | `try..catch` ou código de erro global | `Result<T, E>` (`Ok` ou `Err`) |
| Obrigatoriedade de tratar | Opcional (fácil de esquecer) | Obrigatória (compilador exige `match`) |

---

Na próxima lição, vamos consolidar tudo o que você aprendeu até aqui construindo nosso **Projeto Prático Final: Um Sistema de Carteira Digital Segura**!

➡️ **Próxima Lição:** [Lição 9: Projeto Prático Final](file:///c:/Users/Pichau/Documents/aether/docs/curso/09_PROJETO_PRATICO_FINAL.md)
