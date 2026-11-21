# Conceitos de Posse e Empréstimo (Ownership & Borrowing)

No Aether, você programa com alta performance de sistemas **sem precisar se preocupar com vazamento de memória (*memory leaks*) e sem sofrer com pausas de Garbage Collector**.

Isso é possível graças ao **Borrow Checker** do Aether, que analisa a posse de cada variável durante a compilação.

---

## 1. As 3 Palavras-Chave de Memória

Ao definir uma função ou passar variáveis no Aether, existem três modificadores explícitos:

| Modificador | Em Português | O que significa na prática | Equivalente Pascal Tradicional |
|:---|:---|:---|:---|
| **`borrow x: T`** | **Empréstimo de Leitura** | A função apenas **lê** o dado. A variável continua sendo sua e você pode continuar usando ela depois. | `const x: T` |
| **`mut borrow x: T`** | **Empréstimo Mutável** | A função pode **ler e alterar** o dado. Ninguém mais pode ler ou alterar ao mesmo tempo. | `var x: T` |
| **`take x: T`** | **Consumo / Transferência** | A posse do dado é **entregue definitivamente** para a função. Você não pode mais usar a variável. | Passagem com liberação |

---

## 2. Exemplo Prático: `borrow` vs `take`

Considere um registro simples que gerencia um buffer de dados:

```pascal
module ExemploPosse;

type
    DataBuffer = record
        id: UInt32;
        size: UInt64;
    end;

// 'borrow' apenas pega emprestado para leitura:
function Inspecionar(borrow buf: DataBuffer): Void
begin
    PrintLn("Lendo buffer ID: %d, Tamanho: %d", buf.id, buf.size);
end;

// 'take' toma a posse e consome o recurso:
function Finalizar(take buf: DataBuffer): Void
begin
    PrintLn("Buffer %d finalizado e memoria liberada!", buf.id);
end;

program Main;
var
    meu_buffer: DataBuffer;
begin
    meu_buffer := DataBuffer(id: 101, size: 2048);

    // 1. Permitido: Empresta apenas para leitura
    Inspecionar(borrow meu_buffer);

    // 2. Você continua dono da variavel, pode ler de novo!
    Inspecionar(borrow meu_buffer);

    // 3. Agora entregamos a posse definitiva para Finalizar:
    Finalizar(take meu_buffer);

    // 4. ERRO DE COMPILAÇÃO!
    // Se você tentar ler 'meu_buffer' aqui, o compilador barra com Erro E0382:
    // Inspecionar(borrow meu_buffer); // <-- 'meu_buffer' ja foi movido!
end.
```

---

## 3. A Mensagem Amigável do Compilador

Se você cometer um erro de *Use-After-Move* (usar uma variável após ela ter sido consumida com `take`), o `aetherc` informa exatamente o que aconteceu:

```text
Erro de Compilacao: [Erro de Posse E0382 em 32:24]: Uso de variavel movida: "meu_buffer"
  --> Nota: O valor foi movido anteriormente na linha 28:15 atraves de "take".
```

---

## 4. Orientação a Objetos Moderna via UFCS

Graças à sintaxe **UFCS (*Uniform Function Call Syntax*)**, qualquer função cujo primeiro argumento seja `borrow` pode ser chamada como se fosse um método do objeto:

```pascal
// Estilo tradicional funcional:
Inspecionar(borrow meu_buffer);

// Estilo orientado a objetos (açúcar sintático seguro):
meu_buffer.Inspecionar();
```

Ambas as formas geram o mesmo código nativo de alta velocidade e passam pelas mesmas checagens estritas de segurança!
