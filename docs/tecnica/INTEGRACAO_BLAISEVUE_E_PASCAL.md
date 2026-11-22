# Integração Nativa entre Aether e BlaiseVue

> **Como utilizar a segurança estrita de tipos e posse da memória do Aether como motor de lógica, estado e regras de negócios no ecossistema reativo do BlaiseVue.**

---

## 1. Visão Geral e Motivação

O **BlaiseVue** é um framework moderno, reativo e componentizado construído sobre Free Pascal. Ele permite construir aplicações de backend e front-end com máxima velocidade de execução.

Ao integrar o **Aether** ao BlaiseVue, os desenvolvedores ganham:
1. **Zero Memory Leaks:** A lógica de estado, cálculo e regras de negócios é verificada pelo *Borrow Checker* do Aether em tempo de compilação sem custos ocultos de runtime ou GC.
2. **Pattern Matching & Algebraic Data Types:** Expressividade moderna de `Result<T, E>`, `Option<T>` e `match` exaustivo para tratar fluxos assíncronos e requisições sem `try/except` desordenados.
3. **Paridade Nativa de Compilação:** O código Aether é transpilado diretamente para **Units Object Pascal puras e limpas**, que o Free Pascal compila em centésimos de segundo (0.1s) e consome sem pontes lentas de FFI ou wrappers de DLL.

---

## 2. A Mágica do `--unit`: Geração Estruturada de Units Pascal

Ao compilar um arquivo com o comando `emit pascal --unit`, o Aether não gera um `program` executável, mas sim uma **Unit Pascal canônica**:

```bash
aetherc emit pascal src/UserStore.aeth --unit
```

### O que o Aether gera:
```pascal
unit UserStore;

{$mode objfpc}{$H+}{$assertions on}

interface

uses
  SysUtils, Sockets, Math;

// 1. Tipos e Monades exportadas publicamente
type
  generic TAetherResult<TVal, TErr> = record
    is_ok: Boolean;
    is_err: Boolean;
    value: TVal;
    error: TErr;
  end;

type
  PUserSession = ^TUserSession;
  TUserSession = record
    username: String;
    counter: Int32;
    is_authenticated: Boolean;
  end;

// 2. Construtores e Assinaturas exportadas para o BlaiseVue
function UserSession(const A_username: String; const A_counter: Int32; const A_is_authenticated: Boolean): TUserSession;
function CreateUserSession(const name: String): TUserSession;
function IncrementCounter(var session: TUserSession; const delta: Int32): Int32;
function GetSessionReport(const session: TUserSession): String;

implementation

// 3. Corpos das funcoes, helpers de runtime e inicializacao limpa
...
end.
```

---

## 3. Consumindo no BlaiseVue com `uses`

No seu componente ou servidor BlaiseVue (seja um `.pas`, `.vue` compilado ou controller HTTP), basta adicionar a unit à cláusula `uses`:

```pascal
unit UserController;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  BlaiseVue.Core,
  UserStore; // <-- Unit gerada pelo Aether!

type
  TUserController = class(TBlaiseController)
  private
    FSession: TUserSession;
  public
    constructor Create; override;
    procedure HandleClick;
    function RenderView: string;
  end;

implementation

constructor TUserController.Create;
begin
  inherited Create;
  // Construtor gerado pelo Aether:
  FSession := CreateUserSession('Carlos BlaiseVue');
end;

procedure TUserController.HandleClick;
begin
  // Emprestimo mutavel sem vazamento de memoria:
  IncrementCounter(FSession, 1);
end;

function TUserController.RenderView: string;
begin
  Result := GetSessionReport(FSession);
end;

end.
```

---

## 4. Pipeline de Desenvolvimento e Tooling

Para que a experiência de desenvolvimento com o BlaiseVue seja instantânea, a CLI do Aether oferece flags dedicadas para o ecossistema BlaiseVue:

### 4.1 Customização de Destino (`--out-dir`)
Direciona a transpilação diretamente para a pasta de arquivos gerados do BlaiseVue:
```bash
aetherc emit pascal src/UserStore.aeth --unit --out-dir=./generated/blaisevue
```

### 4.2 Hot-Reload Reativo (`--watch`)
Mantém o compilador observando alterações. Toda vez que você salvar o arquivo `.aeth`, a unit `.pas` é regerada instantaneamente:
```bash
aetherc emit pascal src/UserStore.aeth --unit --watch
```
Saída do console em tempo real:
```text
========================================================
  Aether File Watcher (Hot-Reload / BlaiseVue Ready)    
========================================================
Observando alteracoes em: "src/UserStore.aeth"
Pressione Ctrl+C para interromper.

[23:13:30] [WATCH] Alteracao detectada em "UserStore.aeth"...
      [OK] Arquivo regenerado com sucesso!
```

### 4.3 Modo Silencioso para a CLI do BlaiseVue (`--silent`)
Quando a CLI do BlaiseVue invocar o compilador Aether em background, utilize `--silent` para receber apenas os códigos de retorno e erros se houverem:
```bash
aetherc emit pascal src/UserStore.aeth --unit --out-dir=.blaisevue/generated --silent
```
Se a compilação tiver sucesso, o comando finaliza silenciosamente com **código de saída 0**. Se houver erro de tipos ou borrow checker, retorna **código de saída 1** e exibe a mensagem de erro formatada.
