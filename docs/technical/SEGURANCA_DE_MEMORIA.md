# Análise de Segurança de Memória: Aether vs Rust

Este documento detalha o modelo matemático e formal de garantias de segurança que tornam o **Aether tão seguro quanto o Rust** no gerenciamento estático de memória e concorrência.

---

## 1. O Princípio Central: Segurança em Tempo de Compilação

Assim como o Rust, o Aether adota o princípio de **Zero Custo de Abstração** (*Zero-Cost Abstractions*):
- Não existe Coletor de Lixo (*Garbage Collector*).
- Não há pausas em tempo de execução (*GC pauses*).
- A verificação de segurança ocorre **100% durante a compilação** através do **Borrow Checker** e do sistema de tipos estático.

---

## 2. Tabela Comparativa de Garantias de Segurança

| Tipo de Vulnerabilidade | C / C++ | Object Pascal Tradicional | Rust | AetherLang |
|:---|:---:|:---:|:---:|:---:|
| **Use-After-Free** (Usar ponteiro liberado) | ❌ Crítico | ❌ Possível | ✅ Impossível | ✅ **Impossível** (via `take`) |
| **Double-Free** (Liberar memória 2 vezes) | ❌ Crítico | ❌ Possível | ✅ Impossível | ✅ **Impossível** (Single Owner) |
| **Null Pointer Dereference** (Ponteiro Nulo) | ❌ Crítico | ❌ `Access Violation` | ✅ Impossível | ✅ **Impossível** (via `Option<T>`) |
| **Data Races** (Condição de corrida multithread) | ❌ Comum | ❌ Comum | ✅ Impossível | ✅ **Impossível** (Aliasing XOR Mutability) |
| **Buffer Overflow** (Estouro de array) | ❌ Crítico | ⚠️ Depende de `-Cr` | ✅ Checado | ✅ **Garantido por Contrato / Bounds** |
| **Memory Leaks** (Vazamento de memória) | ❌ Frequente | ❌ Manual (`Free`) | ✅ RAII Automático | ✅ **RAII Automático (Drop no fim do escopo)** |

---

## 3. Os 3 Pilares que Tornam o Aether Seguro como o Rust

### Pilar 1: Posse Única (Ownership)
Todo objeto ou estrutura alocada tem **exatamente uma variável proprietária** por vez.
- Quando uma função recebe `take x: MinhaEstrutura`, a variável original deixa de existir no chamador.
- Tentar ler ou passar `x` novamente resulta no erro estático `E0382: Use of moved value`.
- Quando o proprietário sai do escopo (ao atingir o `end` do bloco), o destrutor do recurso é chamado automaticamente. Zero vazamento de memória.

### Pilar 2: Aliasing XOR Mutabilidade (Regra de Ouro do Borrow Checker)
O compilador do Aether impõe estritamente a lei:
$$\text{Empréstimos Simultâneos} = (\text{Vários } \texttt{borrow}) \lor (\text{Exatamente um } \texttt{mut borrow})$$

- Se alguém estiver alterando um dado (`mut borrow`), ninguém mais pode ler nem escrever naquele dado simultaneamente.
- Isso **elimina matematicamente qualquer condição de corrida (*data race*)** em programas paralelos e multithread.

### Pilar 3: O Fim do "Null" (Billion Dollar Mistake)
Em Aether, **nenhuma variável comum pode ser nula**.
- Se um valor pode não existir, o programador é obrigado a usar o tipo algébrico `Option<T>`:
  ```pascal
  type
      Option<T> = enum
          Some(value: T),
          None
      end;
  ```
- O compilador exige a desestruturação exaustiva via `match`, tornando impossível acessar o valor sem verificar se ele existe antes.
