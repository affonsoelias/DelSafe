# AI Mode & JSON Diagnostics (`--emit-json-diagnostics`)

The official Aether compiler was designed from day one for seamless collaboration between **Humans** and **AI Coding Agents**.

When invoked with `--emit-json-diag` (or `--emit-json-diagnostics`), the compiler suppresses visual banners and outputs a standardized JSON payload to `stdout`.

---

## 1. JSON Diagnostic Schema

```json
{
  "schema_version": "1.0",
  "diagnostics": [
    {
      "severity": "Error",
      "code": "E0382",
      "file": "path/to/file.aeth",
      "range": {
        "start": { "line": 25, "col": 12 },
        "end": { "line": 25, "col": 17 }
      },
      "message": "Use of moved value: \"my_buffer\"",
      "context": {
        "moved_at": {
          "line": 24,
          "col": 19,
          "note": "Value was moved earlier via \"take\""
        }
      },
      "suggested_fix": {
        "strategy": "borrow_instead_of_move",
        "description": "Change call-site modifier to \"borrow\" if ownership transfer is not required.",
        "replacement": "borrow"
      }
    }
  ]
}
```

---

## 2. Payload Fields

| Field | Type | Description |
|:---|:---|:---|
| `schema_version` | String | Schema protocol version (currently `"1.0"`). |
| `severity` | String | Diagnostic level: `"Error"`, `"Warning"`, or `"Info"`. |
| `code` | String | Standardized error code (e.g., `E0382` ownership, `E0308` type mismatch, `E0004` non-exhaustive match). |
| `file` | String | Absolute or relative path of the analyzed source file. |
| `range` | Object | Exact source span (`start` and `end` with `line` and `col`). |
| `message` | String | Human-readable error message. |
| `context` | Object (Optional) | Extra trace information (e.g., where a value was previously moved). |
| `suggested_fix` | Object (Optional) | Machine-applicable fix suggestion for AI agents and IDEs. |

---

## 3. Standardized Error Code Reference

- **`E0000`:** Lexical Error (unterminated string literal, invalid character).
- **`E0001`:** Syntax Error (unexpected token, mismatched `end <construct>`).
- **`E0004`:** Non-exhaustive `match` (missing variant coverage for an `enum`, `Result`, or `Option`).
- **`E0061`:** Wrong number of arguments in function or constructor call.
- **`E0308`:** Type mismatch in assignment, comparison, or return expression.
- **`E0369`:** Invalid binary or unary operation for the operand type.
- **`E0382`:** Use of moved value (*Use-After-Move*).
- **`E0384`:** Attempt to reassign an immutable `let` variable.
- **`E0412`:** Unrecognized type identifier.
- **`E0425`:** Unresolved variable or function identifier in scope.
- **`E0502`:** Mutable borrow conflict with active shared borrows.
