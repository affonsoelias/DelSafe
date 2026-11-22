# Aether Application - Documentação da API

Documentação canônica de módulos e APIs da linguagem Aether.

---

## Módulo `geometria`

Módulo de cálculos geométricos e estatísticos de alta precisão.

### Funções

#### `CriarPonto`

Cria um novo ponto no plano cartesiano.

```aether
function CriarPonto(x: Float64, y: Float64): Ponto;
```

**Contratos:**
- `require: x >= 0.0`
- `require: y >= 0.0`
- `ensure: x >= 0.0`

#### `DeslocarPonto`

Desloca as coordenadas de um ponto diretamente na memória.

```aether
function DeslocarPonto(mut borrow p: Ponto, dx: Float64, dy: Float64): Void;
```

#### `CalcularAreaAsync`

Computa a área assíncrona de um retângulo delimitador.

```aether
async function CalcularAreaAsync(largura: Float64, altura: Float64): Float64;
```

**Contratos:**
- `require: largura > 0.0`
- `require: altura > 0.0`

