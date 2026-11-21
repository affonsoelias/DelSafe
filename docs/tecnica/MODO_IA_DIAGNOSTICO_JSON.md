# Modo IA & Diagnósticos em JSON (`--emit-json-diagnostics`)

O compilador oficial do Aether foi projetado desde o primeiro dia para cooperação contínua entre **Humanos** e **Agentes Inteligentes de IA**.

Quando acionado com a flag `--emit-json-diag` (ou `--emit-json-diagnostics`), o compilador suprime banners visuais e gera um payload JSON padronizado em `stdout`.

---

## 1. Schema do Diagnóstico JSON

```json
{
  "schema_version": "1.0",
  "diagnostics": [
    {
      "severity": "Error",
      "code": "E0382",
      "file": "caminho/do/arquivo.aeth",
      "range": {
        "start": { "line": 25, "col": 12 },
        "end": { "line": 25, "col": 17 }
      },
      "message": "Uso de variavel movida: \"meu_buffer\"",
      "context": {
        "moved_at": {
          "line": 24,
          "col": 19,
          "note": "Valor movido anteriormente via \"take\""
        }
      },
      "suggested_fix": {
        "strategy": "borrow_instead_of_move",
        "description": "Altere a chamada para \"borrow\" se a transferencia de posse nao for necessaria.",
        "replacement": "borrow"
      }
    }
  ]
}
```

---

## 2. Propriedades do Payload

| Campo | Tipo | Descrição |
|:---|:---|:---|
| `schema_version` | String | Versão do schema de comunicação (atualmente `"1.0"`). |
| `severity` | String | Gravidade: `"Error"`, `"Warning"` ou `"Info"`. |
| `code` | String | Código padronizado do erro (ex: `E0382` para posse, `E0308` para tipo incompatível, `E0004` para match não-exaustivo). |
| `file` | String | Caminho absoluto ou relativo do arquivo analisado. |
| `range` | Objeto | Posição exata do erro (`start` e `end` com `line` e `col`). |
| `message` | String | Mensagem de erro descritiva em linguagem natural. |
| `context` | Objeto (Opcional) | Informações de contexto adicional (ex: onde o valor foi movido). |
| `suggested_fix` | Objeto (Opcional) | Estratégia de autocorreção com texto de substituição pronto para ser aplicado pela IA ou IDE. |

---

## 3. Tabela de Códigos de Erro Padronizados

- **`E0000`:** Erro Léxico (literal não finalizado, caractere inválido).
- **`E0001`:** Erro Sintático (token inesperado, fechamento de bloco ausente).
- **`E0004`:** Match não-exaustivo (falta cobrir uma variante de `enum` ou `Result`).
- **`E0061`:** Quantidade incorreta de argumentos em chamada de função ou construtor.
- **`E0308`:** Incompatibilidade de tipos em atribuição, comparação ou retorno.
- **`E0369`:** Operação binária ou unária inválida para o tipo de dado.
- **`E0382`:** Uso de variável já movida (*Use-After-Move*).
- **`E0384`:** Tentativa de modificar variável imutável declarada com `let`.
- **`E0412`:** Identificador de tipo não reconhecido.
- **`E0425`:** Identificador de variável ou função não encontrado no escopo.
- **`E0502`:** Tentativa de empréstimo mutável concorrente com empréstimos de leitura ativos.
