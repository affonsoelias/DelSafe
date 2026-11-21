# Lição 9: Projeto Prático Final — Sistema de Carteira Digital Segura

Parabéns por chegar até a última lição do curso de Aether! 🎉

Agora é hora de unir todas as peças que você aprendeu:
1. **Módulos e Estrutura Pascal** (`module`, `type`, `program`, `begin/end`);
2. **Records e Orientação a Objetos Moderna (UFCS)** (`conta.Depositar()`);
3. **Empréstimo Mutável e Proteção de Memória** (`mut borrow`, `borrow`);
4. **Contratos Formais** (`require`, `ensure`);
5. **Tipos Algébricos e Tratamento Exaustivo** (`enum`, `Result<T, E>`, `match`).

---

## 1. O Código Completo do Projeto

Salve este código no arquivo `examples/05_curso_projeto_final.aeth`:

```pascal
module BancoDigital;

type
    ContaError = enum
        SaldoInsuficiente,
        ValorInvalido
    end;

    ContaBancaria = record
        id: UInt32;
        saldo: Float64;
    end;

function ExibirSaldo(borrow c: ContaBancaria): Void
begin
    PrintLn("Conta #%d - Saldo atual: R$ %f", c.id, c.saldo);
end;

function Depositar(mut borrow c: ContaBancaria; borrow valor: Float64): Result<Float64, ContaError>
contract
    require
        valor > 0.0;
    ensure
        result.is_ok;
begin
    if valor <= 0.0 then
        return Err(ContaError.ValorInvalido);
    else
        c.saldo := c.saldo + valor;
        return Ok(c.saldo);
    end;
end;

function Sacar(mut borrow c: ContaBancaria; borrow valor: Float64): Result<Float64, ContaError>
contract
    require
        valor > 0.0;
    ensure
        true;
begin
    if valor <= 0.0 then
        return Err(ContaError.ValorInvalido);
    else
        if c.saldo < valor then
            return Err(ContaError.SaldoInsuficiente);
        else
            c.saldo := c.saldo - valor;
            return Ok(c.saldo);
        end;
    end;
end;

program Main;
var
    minha_conta: ContaBancaria;
    res_deposito: Result<Float64, ContaError>;
    res_saque: Result<Float64, ContaError>;
begin
    PrintLn("=== SISTEMA BANCARIO SEGURO AETHER ===");

    // 1. Instanciando a conta
    minha_conta := ContaBancaria(id: 1001, saldo: 250.0);
    minha_conta.ExibirSaldo();

    // 2. Realizando um depósito com validação
    PrintLn("\nDepositando R$ 150.00...");
    res_deposito := minha_conta.Depositar(borrow 150.0);
    match res_deposito do
        case Ok(let novo_saldo):
            PrintLn("Deposito concluido! Novo saldo: R$ %f", novo_saldo);
        case Err(ContaError.ValorInvalido):
            PrintLn("Erro: Valor de deposito invalido.");
        case Err(ContaError.SaldoInsuficiente):
            PrintLn("Erro: Saldo insuficiente.");
    end;

    // 3. Tentando realizar um saque que excede o saldo
    PrintLn("\nTentando sacar R$ 500.00...");
    res_saque := minha_conta.Sacar(borrow 500.0);
    match res_saque do
        case Ok(let saldo_restante):
            PrintLn("Saque autorizado! Saldo restante: R$ %f", saldo_restante);
        case Err(ContaError.SaldoInsuficiente):
            PrintLn("Saque recusado: Saldo insuficiente na conta!");
        case Err(ContaError.ValorInvalido):
            PrintLn("Saque recusado: Valor informado e invalido.");
    end;

    // 4. Exibindo o saldo final
    PrintLn("\nExtrato final:");
    minha_conta.ExibirSaldo();
end.
```

---

## 2. Compilando e Executando

Abra seu terminal na raiz do projeto `aether`:

### Via Backend Pascal (Padrão):
```bash
./bin/aetherc examples/05_curso_projeto_final.aeth
./bin/05_curso_projeto_final.exe
```

### Via Backend C99 (GCC MSYS2):
```bash
./bin/aetherc examples/05_curso_projeto_final.aeth --target=c
./bin/05_curso_projeto_final.exe
```

---

## 3. Saída Esperada no Terminal

```text
=== SISTEMA BANCARIO SEGURO AETHER ===
Conta #1001 - Saldo atual: R$ 250.000000

Depositando R$ 150.00...
Deposito concluido! Novo saldo: R$ 400.000000

Tentando sacar R$ 500.00...
Saque recusado: Saldo insuficiente na conta!

Extrato final:
Conta #1001 - Saldo atual: R$ 400.000000
```

---

## 4. O Que Tornou Este Código Especial?

1. **Zero Vazamentos de Memória:** Sem coletor de lixo (*garbage collector*), o ciclo de vida de `minha_conta` foi controlado estaticamente em tempo de compilação.
2. **Zero Null Pointer Exceptions:** Não usamos ponteiros nulos ou valores indefinidos.
3. **Erros Impossíveis de Serem Ignorados:** O compilador nos obrigou a tratar o `Result` de forma exaustiva através do `match`.
4. **Legibilidade Suprema:** O código é limpo, elegante e intuitivo para humanos e agentes de inteligência artificial.

---

## 🎓 Conclusão do Curso

Você agora domina os fundamentos essenciais da linguagem Aether!

Para continuar sua jornada:
- Consulte a [Especificação Formal da Linguagem](file:///c:/Users/Pichau/Documents/aether/docs/tecnica/ESPECIFICACAO_LINGUAGEM.md);
- Explore o [Guia de Posse e Borrow](file:///c:/Users/Pichau/Documents/aether/docs/usuario/CONCEITOS_POSSE_E_BORROW.md);
- Veja o [Roadmap de Desenvolvimento](file:///c:/Users/Pichau/Documents/aether/docs/planejamento/ROADMAP_DE_DESENVOLVIMENTO.md) para acompanhar as próximas novidades como a Biblioteca Padrão `std/` e a integração com extensões de IDE!
