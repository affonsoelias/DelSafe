unit uAetherAST;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

type
  TOwnershipKind = (owNone, owTake, owBorrow, owMutBorrow);

  // Classe Base de todos os Nós da AST
  TASTNode = class
  public
    Line: Integer;
    Col: Integer;
    constructor Create(ALine, ACol: Integer);
    function Dump(Indent: Integer = 0): string; virtual; abstract;
  end;

  // Lista tipada de nós com gerenciamento de memória automático no Free
  TASTNodeList = class
  private
    FItems: TFPList;
    function GetCount: Integer;
    function GetItem(Index: Integer): TASTNode;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(Node: TASTNode);
    procedure Insert(Index: Integer; Node: TASTNode);
    function Extract(Node: TASTNode): TASTNode;
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TASTNode read GetItem; default;
  end;

  // --- Expressões ---
  TASTExpr = class(TASTNode);

  TASTLiteralKind = (lkInt, lkFloat, lkString, lkChar, lkBool);

  TASTLiteralExpr = class(TASTExpr)
  public
    Kind: TASTLiteralKind;
    Value: string;
    constructor Create(ALine, ACol: Integer; AKind: TASTLiteralKind; const AVal: string);
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTIdentifierExpr = class(TASTExpr)
  public
    Name: string;
    constructor Create(ALine, ACol: Integer; const AName: string);
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTMemberAccessExpr = class(TASTExpr)
  public
    Target: TASTExpr;
    Member: string;
    constructor Create(ALine, ACol: Integer; ATarget: TASTExpr; const AMember: string);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTBinaryExpr = class(TASTExpr)
  public
    Left: TASTExpr;
    Op: string;
    Right: TASTExpr;
    constructor Create(ALine, ACol: Integer; ALeft: TASTExpr; const AOp: string; ARight: TASTExpr);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTUnaryExpr = class(TASTExpr)
  public
    Op: string;
    Expr: TASTExpr;
    constructor Create(ALine, ACol: Integer; const AOp: string; AExpr: TASTExpr);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTCallArg = class(TASTNode)
  public
    Ownership: TOwnershipKind;
    Expr: TASTExpr;
    constructor Create(ALine, ACol: Integer; AOwnership: TOwnershipKind; AExpr: TASTExpr);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTCallExpr = class(TASTExpr)
  public
    Callee: string;
    Args: TASTNodeList; // lista de TASTCallArg
    constructor Create(ALine, ACol: Integer; const ACallee: string);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
  end;

  // --- Instruções (Statements) ---
  TASTStmt = class(TASTNode);

  TASTAssignStmt = class(TASTStmt)
  public
    Target: TASTExpr;
    Expr: TASTExpr;
    constructor Create(ALine, ACol: Integer; ATarget, AExpr: TASTExpr);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTCallStmt = class(TASTStmt)
  public
    CallExpr: TASTCallExpr;
    constructor Create(ALine, ACol: Integer; ACall: TASTCallExpr);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTIfStmt = class(TASTStmt)
  public
    Condition: TASTExpr;
    ThenBranch: TASTNodeList; // TASTStmt
    ElseBranch: TASTNodeList; // TASTStmt
    constructor Create(ALine, ACol: Integer; ACond: TASTExpr);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTWhileStmt = class(TASTStmt)
  public
    Condition: TASTExpr;
    Body: TASTNodeList;
    constructor Create(ALine, ACol: Integer; ACond: TASTExpr);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTPattern = class(TASTNode)
  public
    Value: string;
    SubPattern: string;
    IsLet: Boolean;
    constructor Create(ALine, ACol: Integer; const AValue: string; const ASub: string = ''; AIsLet: Boolean = False);
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTMatchCase = class(TASTNode)
  public
    Pattern: TASTPattern;
    Body: TASTNodeList; // TASTStmt
    constructor Create(ALine, ACol: Integer; APattern: TASTPattern);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTMatchStmt = class(TASTStmt)
  public
    Expr: TASTExpr;
    Cases: TASTNodeList; // TASTMatchCase
    constructor Create(ALine, ACol: Integer; AExpr: TASTExpr);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTReturnStmt = class(TASTStmt)
  public
    Expr: TASTExpr;
    constructor Create(ALine, ACol: Integer; AExpr: TASTExpr = nil);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
  end;

  // --- Declarações de Variáveis e Tipos ---
  TASTVarDecl = class(TASTNode)
  public
    Name: string;
    TypeName: string;
    InitialExpr: TASTExpr;
    IsMutable: Boolean;
    constructor Create(ALine, ACol: Integer; const AName, ATypeName: string; AInit: TASTExpr = nil; AMut: Boolean = True);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTRecordField = class(TASTNode)
  public
    Name: string;
    TypeName: string;
    constructor Create(ALine, ACol: Integer; const AName, AType: string);
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTRecordDecl = class(TASTNode)
  public
    Name: string;
    Fields: TASTNodeList; // TASTRecordField
    constructor Create(ALine, ACol: Integer; const AName: string);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTEnumVariant = class(TASTNode)
  public
    Name: string;
    Fields: TASTNodeList; // TASTRecordField (payload opcional)
    constructor Create(ALine, ACol: Integer; const AName: string);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTEnumDecl = class(TASTNode)
  public
    Name: string;
    Variants: TASTNodeList; // TASTEnumVariant
    constructor Create(ALine, ACol: Integer; const AName: string);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTParam = class(TASTNode)
  public
    Name: string;
    TypeName: string;
    Ownership: TOwnershipKind;
    constructor Create(ALine, ACol: Integer; const AName, AType: string; AOwnership: TOwnershipKind);
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTFunction = class(TASTNode)
  public
    Name: string;
    GenericParam: string;      // Parametro generico (ex: 'T')
    TraitBound: string;        // Trait bound (ex: 'Printable')
    OriginalName: string;      // Nome original do metodo (ex: 'ToString')
    Params: TASTNodeList;      // TASTParam
    ReturnType: string;
    Requires: TASTNodeList;    // TASTExpr
    Ensures: TASTNodeList;     // TASTExpr
    LocalVars: TASTNodeList;   // TASTVarDecl
    Body: TASTNodeList;        // TASTStmt
    IsExtern: Boolean;
    ExternAbi: string;
    ExternLib: string;
    constructor Create(ALine, ACol: Integer; const AName, AReturnType: string);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTTraitDecl = class(TASTNode)
  public
    Name: string;
    Methods: TASTNodeList;      // TASTFunction (assinaturas)
    constructor Create(ALine, ACol: Integer; const AName: string);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTImplDecl = class(TASTNode)
  public
    TraitName: string;
    TargetTypeName: string;
    Methods: TASTNodeList;      // TASTFunction (implementacoes concretas)
    constructor Create(ALine, ACol: Integer; const ATraitName, ATargetTypeName: string);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTProgramBlock = class(TASTNode)
  public
    Name: string;
    LocalVars: TASTNodeList;   // TASTVarDecl
    Body: TASTNodeList;        // TASTStmt
    constructor Create(ALine, ACol: Integer; const AName: string);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
  end;

  TASTModule = class(TASTNode)
  public
    Name: string;
    Imports: TStringList;
    PascalImports: TStringList;
    CImports: TStringList;
    LinkDirectives: TStringList;
    Types: TASTNodeList;       // TASTRecordDecl, TASTEnumDecl
    Traits: TASTNodeList;      // TASTTraitDecl
    Impls: TASTNodeList;       // TASTImplDecl
    Functions: TASTNodeList;   // TASTFunction
    ProgramBlock: TASTProgramBlock;
    constructor Create(ALine, ACol: Integer; const AName: string);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
  end;

function OwnershipToString(O: TOwnershipKind): string;
function MakeIndent(Level: Integer): string;
function CloneASTNode(Node: TASTNode): TASTNode;

implementation

function OwnershipToString(O: TOwnershipKind): string;
begin
  case O of
    owTake: Result := 'take ';
    owBorrow: Result := 'borrow ';
    owMutBorrow: Result := 'mut borrow ';
  else
    Result := '';
  end;
end;

function MakeIndent(Level: Integer): string;
begin
  Result := StringOfChar(' ', Level * 2);
end;

{ TASTNode }

constructor TASTNode.Create(ALine, ACol: Integer);
begin
  inherited Create;
  Line := ALine;
  Col := ACol;
end;

{ TASTNodeList }

constructor TASTNodeList.Create;
begin
  inherited Create;
  FItems := TFPList.Create;
end;

destructor TASTNodeList.Destroy;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
    TASTNode(FItems[I]).Free;
  FItems.Free;
  inherited Destroy;
end;

procedure TASTNodeList.Add(Node: TASTNode);
begin
  FItems.Add(Node);
end;

procedure TASTNodeList.Insert(Index: Integer; Node: TASTNode);
begin
  FItems.Insert(Index, Node);
end;

function TASTNodeList.Extract(Node: TASTNode): TASTNode;
begin
  Result := TASTNode(FItems.Extract(Node));
end;

function TASTNodeList.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TASTNodeList.GetItem(Index: Integer): TASTNode;
begin
  Result := TASTNode(FItems[Index]);
end;

{ TASTLiteralExpr }

constructor TASTLiteralExpr.Create(ALine, ACol: Integer; AKind: TASTLiteralKind; const AVal: string);
begin
  inherited Create(ALine, ACol);
  Kind := AKind;
  Value := AVal;
end;

function TASTLiteralExpr.Dump(Indent: Integer): string;
begin
  case Kind of
    lkString: Result := MakeIndent(Indent) + Format('Literal String: "%s"', [Value]);
    lkChar:   Result := MakeIndent(Indent) + Format('Literal Char: ''%s''', [Value]);
    lkInt:    Result := MakeIndent(Indent) + Format('Literal Int: %s', [Value]);
    lkFloat:  Result := MakeIndent(Indent) + Format('Literal Float: %s', [Value]);
    lkBool:   Result := MakeIndent(Indent) + Format('Literal Bool: %s', [Value]);
  end;
end;

{ TASTIdentifierExpr }

constructor TASTIdentifierExpr.Create(ALine, ACol: Integer; const AName: string);
begin
  inherited Create(ALine, ACol);
  Name := AName;
end;

function TASTIdentifierExpr.Dump(Indent: Integer): string;
begin
  Result := MakeIndent(Indent) + Format('Identificador: %s', [Name]);
end;

{ TASTMemberAccessExpr }

constructor TASTMemberAccessExpr.Create(ALine, ACol: Integer; ATarget: TASTExpr; const AMember: string);
begin
  inherited Create(ALine, ACol);
  Target := ATarget;
  Member := AMember;
end;

destructor TASTMemberAccessExpr.Destroy;
begin
  Target.Free;
  inherited Destroy;
end;

function TASTMemberAccessExpr.Dump(Indent: Integer): string;
begin
  Result := MakeIndent(Indent) + Format('Acesso a Membro: .%s' + LineEnding, [Member]) +
            Target.Dump(Indent + 1);
end;

{ TASTBinaryExpr }

constructor TASTBinaryExpr.Create(ALine, ACol: Integer; ALeft: TASTExpr; const AOp: string; ARight: TASTExpr);
begin
  inherited Create(ALine, ACol);
  Left := ALeft;
  Op := AOp;
  Right := ARight;
end;

destructor TASTBinaryExpr.Destroy;
begin
  Left.Free;
  Right.Free;
  inherited Destroy;
end;

function TASTBinaryExpr.Dump(Indent: Integer): string;
begin
  Result := MakeIndent(Indent) + Format('Operacao Binaria (%s):' + LineEnding, [Op]) +
            Left.Dump(Indent + 1) + LineEnding +
            Right.Dump(Indent + 1);
end;

{ TASTUnaryExpr }

constructor TASTUnaryExpr.Create(ALine, ACol: Integer; const AOp: string; AExpr: TASTExpr);
begin
  inherited Create(ALine, ACol);
  Op := AOp;
  Expr := AExpr;
end;

destructor TASTUnaryExpr.Destroy;
begin
  Expr.Free;
  inherited Destroy;
end;

function TASTUnaryExpr.Dump(Indent: Integer): string;
begin
  Result := MakeIndent(Indent) + Format('Operacao Unaria (%s):' + LineEnding, [Op]) +
            Expr.Dump(Indent + 1);
end;

{ TASTCallArg }

constructor TASTCallArg.Create(ALine, ACol: Integer; AOwnership: TOwnershipKind; AExpr: TASTExpr);
begin
  inherited Create(ALine, ACol);
  Ownership := AOwnership;
  Expr := AExpr;
end;

destructor TASTCallArg.Destroy;
begin
  Expr.Free;
  inherited Destroy;
end;

function TASTCallArg.Dump(Indent: Integer): string;
begin
  Result := MakeIndent(Indent) + Format('Argumento [%s]:' + LineEnding, [Trim(OwnershipToString(Ownership))]) +
            Expr.Dump(Indent + 1);
end;

{ TASTCallExpr }

constructor TASTCallExpr.Create(ALine, ACol: Integer; const ACallee: string);
begin
  inherited Create(ALine, ACol);
  Callee := ACallee;
  Args := TASTNodeList.Create;
end;

destructor TASTCallExpr.Destroy;
begin
  Args.Free;
  inherited Destroy;
end;

function TASTCallExpr.Dump(Indent: Integer): string;
var
  I: Integer;
begin
  Result := MakeIndent(Indent) + Format('Chamada de Funcao: %s()', [Callee]);
  if Args.Count > 0 then
  begin
    Result := Result + LineEnding;
    for I := 0 to Args.Count - 1 do
    begin
      Result := Result + Args[I].Dump(Indent + 1);
      if I < Args.Count - 1 then
        Result := Result + LineEnding;
    end;
  end;
end;

{ TASTAssignStmt }

constructor TASTAssignStmt.Create(ALine, ACol: Integer; ATarget, AExpr: TASTExpr);
begin
  inherited Create(ALine, ACol);
  Target := ATarget;
  Expr := AExpr;
end;

destructor TASTAssignStmt.Destroy;
begin
  Target.Free;
  Expr.Free;
  inherited Destroy;
end;

function TASTAssignStmt.Dump(Indent: Integer): string;
begin
  Result := MakeIndent(Indent) + 'Atribuicao :=' + LineEnding +
            Target.Dump(Indent + 1) + LineEnding +
            Expr.Dump(Indent + 1);
end;

{ TASTCallStmt }

constructor TASTCallStmt.Create(ALine, ACol: Integer; ACall: TASTCallExpr);
begin
  inherited Create(ALine, ACol);
  CallExpr := ACall;
end;

destructor TASTCallStmt.Destroy;
begin
  CallExpr.Free;
  inherited Destroy;
end;

function TASTCallStmt.Dump(Indent: Integer): string;
begin
  Result := CallExpr.Dump(Indent);
end;

{ TASTIfStmt }

constructor TASTIfStmt.Create(ALine, ACol: Integer; ACond: TASTExpr);
begin
  inherited Create(ALine, ACol);
  Condition := ACond;
  ThenBranch := TASTNodeList.Create;
  ElseBranch := TASTNodeList.Create;
end;

destructor TASTIfStmt.Destroy;
begin
  Condition.Free;
  ThenBranch.Free;
  ElseBranch.Free;
  inherited Destroy;
end;

function TASTIfStmt.Dump(Indent: Integer): string;
var
  I: Integer;
begin
  Result := MakeIndent(Indent) + 'Se (If):' + LineEnding +
            Condition.Dump(Indent + 1) + LineEnding +
            MakeIndent(Indent) + 'Entao (Then):';
  for I := 0 to ThenBranch.Count - 1 do
    Result := Result + LineEnding + ThenBranch[I].Dump(Indent + 1);

  if ElseBranch.Count > 0 then
  begin
    Result := Result + LineEnding + MakeIndent(Indent) + 'Senao (Else):';
    for I := 0 to ElseBranch.Count - 1 do
      Result := Result + LineEnding + ElseBranch[I].Dump(Indent + 1);
  end;
end;

{ TASTWhileStmt }

constructor TASTWhileStmt.Create(ALine, ACol: Integer; ACond: TASTExpr);
begin
  inherited Create(ALine, ACol);
  Condition := ACond;
  Body := TASTNodeList.Create;
end;

destructor TASTWhileStmt.Destroy;
begin
  Condition.Free;
  Body.Free;
  inherited Destroy;
end;

function TASTWhileStmt.Dump(Indent: Integer): string;
var
  I: Integer;
begin
  Result := MakeIndent(Indent) + 'Enquanto (While):' + LineEnding +
            Condition.Dump(Indent + 1) + LineEnding +
            MakeIndent(Indent) + 'Faca (Do):';
  for I := 0 to Body.Count - 1 do
    Result := Result + LineEnding + Body[I].Dump(Indent + 1);
end;

{ TASTPattern }

constructor TASTPattern.Create(ALine, ACol: Integer; const AValue: string; const ASub: string; AIsLet: Boolean);
begin
  inherited Create(ALine, ACol);
  Value := AValue;
  SubPattern := ASub;
  IsLet := AIsLet;
end;

function TASTPattern.Dump(Indent: Integer): string;
begin
  if SubPattern <> '' then
  begin
    if IsLet then
      Result := MakeIndent(Indent) + Format('Padrao: %s(let %s)', [Value, SubPattern])
    else
      Result := MakeIndent(Indent) + Format('Padrao: %s(%s)', [Value, SubPattern]);
  end
  else
    Result := MakeIndent(Indent) + Format('Padrao: %s', [Value]);
end;

{ TASTMatchCase }

constructor TASTMatchCase.Create(ALine, ACol: Integer; APattern: TASTPattern);
begin
  inherited Create(ALine, ACol);
  Pattern := APattern;
  Body := TASTNodeList.Create;
end;

destructor TASTMatchCase.Destroy;
begin
  Pattern.Free;
  Body.Free;
  inherited Destroy;
end;

function TASTMatchCase.Dump(Indent: Integer): string;
var
  I: Integer;
begin
  Result := MakeIndent(Indent) + 'Caso:' + LineEnding +
            Pattern.Dump(Indent + 1);
  for I := 0 to Body.Count - 1 do
    Result := Result + LineEnding + Body[I].Dump(Indent + 1);
end;

{ TASTMatchStmt }

constructor TASTMatchStmt.Create(ALine, ACol: Integer; AExpr: TASTExpr);
begin
  inherited Create(ALine, ACol);
  Expr := AExpr;
  Cases := TASTNodeList.Create;
end;

destructor TASTMatchStmt.Destroy;
begin
  Expr.Free;
  Cases.Free;
  inherited Destroy;
end;

function TASTMatchStmt.Dump(Indent: Integer): string;
var
  I: Integer;
begin
  Result := MakeIndent(Indent) + 'Match:' + LineEnding +
            Expr.Dump(Indent + 1);
  for I := 0 to Cases.Count - 1 do
    Result := Result + LineEnding + Cases[I].Dump(Indent + 1);
end;

{ TASTReturnStmt }

constructor TASTReturnStmt.Create(ALine, ACol: Integer; AExpr: TASTExpr);
begin
  inherited Create(ALine, ACol);
  Expr := AExpr;
end;

destructor TASTReturnStmt.Destroy;
begin
  Expr.Free;
  inherited Destroy;
end;

function TASTReturnStmt.Dump(Indent: Integer): string;
begin
  if Assigned(Expr) then
    Result := MakeIndent(Indent) + 'Return:' + LineEnding + Expr.Dump(Indent + 1)
  else
    Result := MakeIndent(Indent) + 'Return (Void)';
end;

{ TASTVarDecl }

constructor TASTVarDecl.Create(ALine, ACol: Integer; const AName, ATypeName: string; AInit: TASTExpr; AMut: Boolean);
begin
  inherited Create(ALine, ACol);
  Name := AName;
  TypeName := ATypeName;
  InitialExpr := AInit;
  IsMutable := AMut;
end;

destructor TASTVarDecl.Destroy;
begin
  InitialExpr.Free;
  inherited Destroy;
end;

function TASTVarDecl.Dump(Indent: Integer): string;
var
  KindStr: string;
begin
  if IsMutable then KindStr := 'var' else KindStr := 'let';
  Result := MakeIndent(Indent) + Format('Declaracao Local (%s): %s: %s', [KindStr, Name, TypeName]);
  if Assigned(InitialExpr) then
    Result := Result + ' :=' + LineEnding + InitialExpr.Dump(Indent + 1);
end;

{ TASTRecordField }

constructor TASTRecordField.Create(ALine, ACol: Integer; const AName, AType: string);
begin
  inherited Create(ALine, ACol);
  Name := AName;
  TypeName := AType;
end;

function TASTRecordField.Dump(Indent: Integer): string;
begin
  Result := MakeIndent(Indent) + Format('Campo: %s : %s', [Name, TypeName]);
end;

{ TASTRecordDecl }

constructor TASTRecordDecl.Create(ALine, ACol: Integer; const AName: string);
begin
  inherited Create(ALine, ACol);
  Name := AName;
  Fields := TASTNodeList.Create;
end;

destructor TASTRecordDecl.Destroy;
begin
  Fields.Free;
  inherited Destroy;
end;

function TASTRecordDecl.Dump(Indent: Integer): string;
var
  I: Integer;
begin
  Result := MakeIndent(Indent) + Format('Tipo Record: %s', [Name]);
  for I := 0 to Fields.Count - 1 do
    Result := Result + LineEnding + Fields[I].Dump(Indent + 1);
end;

{ TASTEnumVariant }

constructor TASTEnumVariant.Create(ALine, ACol: Integer; const AName: string);
begin
  inherited Create(ALine, ACol);
  Name := AName;
  Fields := TASTNodeList.Create;
end;

destructor TASTEnumVariant.Destroy;
begin
  Fields.Free;
  inherited Destroy;
end;

function TASTEnumVariant.Dump(Indent: Integer): string;
var
  I: Integer;
begin
  Result := MakeIndent(Indent) + Format('Variante: %s', [Name]);
  for I := 0 to Fields.Count - 1 do
    Result := Result + LineEnding + Fields[I].Dump(Indent + 1);
end;

{ TASTEnumDecl }

constructor TASTEnumDecl.Create(ALine, ACol: Integer; const AName: string);
begin
  inherited Create(ALine, ACol);
  Name := AName;
  Variants := TASTNodeList.Create;
end;

destructor TASTEnumDecl.Destroy;
begin
  Variants.Free;
  inherited Destroy;
end;

function TASTEnumDecl.Dump(Indent: Integer): string;
var
  I: Integer;
begin
  Result := MakeIndent(Indent) + Format('Tipo Enum: %s', [Name]);
  for I := 0 to Variants.Count - 1 do
    Result := Result + LineEnding + Variants[I].Dump(Indent + 1);
end;

{ TASTParam }

constructor TASTParam.Create(ALine, ACol: Integer; const AName, AType: string; AOwnership: TOwnershipKind);
begin
  inherited Create(ALine, ACol);
  Name := AName;
  TypeName := AType;
  Ownership := AOwnership;
end;

function TASTParam.Dump(Indent: Integer): string;
begin
  Result := MakeIndent(Indent) + Format('Parametro [%s%s: %s]', [OwnershipToString(Ownership), Name, TypeName]);
end;

{ TASTFunction }

constructor TASTFunction.Create(ALine, ACol: Integer; const AName, AReturnType: string);
begin
  inherited Create(ALine, ACol);
  Name := AName;
  ReturnType := AReturnType;
  GenericParam := '';
  TraitBound := '';
  OriginalName := '';
  Params := TASTNodeList.Create;
  Requires := TASTNodeList.Create;
  Ensures := TASTNodeList.Create;
  LocalVars := TASTNodeList.Create;
  Body := TASTNodeList.Create;
  IsExtern := False;
  ExternAbi := 'c';
  ExternLib := '';
end;

destructor TASTFunction.Destroy;
begin
  Params.Free;
  Requires.Free;
  Ensures.Free;
  LocalVars.Free;
  Body.Free;
  inherited Destroy;
end;

function TASTFunction.Dump(Indent: Integer): string;
var
  I: Integer;
begin
  Result := MakeIndent(Indent) + Format('Funcao: %s(): %s', [Name, ReturnType]);
  if Params.Count > 0 then
  begin
    Result := Result + LineEnding + MakeIndent(Indent + 1) + 'Parametros:';
    for I := 0 to Params.Count - 1 do
      Result := Result + LineEnding + Params[I].Dump(Indent + 2);
  end;

  if Requires.Count > 0 then
  begin
    Result := Result + LineEnding + MakeIndent(Indent + 1) + 'Contrato (Require):';
    for I := 0 to Requires.Count - 1 do
      Result := Result + LineEnding + Requires[I].Dump(Indent + 2);
  end;

  if Ensures.Count > 0 then
  begin
    Result := Result + LineEnding + MakeIndent(Indent + 1) + 'Contrato (Ensure):';
    for I := 0 to Ensures.Count - 1 do
      Result := Result + LineEnding + Ensures[I].Dump(Indent + 2);
  end;

  if LocalVars.Count > 0 then
  begin
    Result := Result + LineEnding + MakeIndent(Indent + 1) + 'Variaveis Locais:';
    for I := 0 to LocalVars.Count - 1 do
      Result := Result + LineEnding + LocalVars[I].Dump(Indent + 2);
  end;

  if Body.Count > 0 then
  begin
    Result := Result + LineEnding + MakeIndent(Indent + 1) + 'Corpo:';
    for I := 0 to Body.Count - 1 do
      Result := Result + LineEnding + Body[I].Dump(Indent + 2);
  end;
end;

{ TASTProgramBlock }

constructor TASTProgramBlock.Create(ALine, ACol: Integer; const AName: string);
begin
  inherited Create(ALine, ACol);
  Name := AName;
  LocalVars := TASTNodeList.Create;
  Body := TASTNodeList.Create;
end;

destructor TASTProgramBlock.Destroy;
begin
  LocalVars.Free;
  Body.Free;
  inherited Destroy;
end;

function TASTProgramBlock.Dump(Indent: Integer): string;
var
  I: Integer;
begin
  Result := MakeIndent(Indent) + Format('Programa Principal: %s', [Name]);
  if LocalVars.Count > 0 then
  begin
    Result := Result + LineEnding + MakeIndent(Indent + 1) + 'Variaveis Locais:';
    for I := 0 to LocalVars.Count - 1 do
      Result := Result + LineEnding + LocalVars[I].Dump(Indent + 2);
  end;

  if Body.Count > 0 then
  begin
    Result := Result + LineEnding + MakeIndent(Indent + 1) + 'Corpo:';
    for I := 0 to Body.Count - 1 do
      Result := Result + LineEnding + Body[I].Dump(Indent + 2);
  end;
end;

{ TASTTraitDecl }

constructor TASTTraitDecl.Create(ALine, ACol: Integer; const AName: string);
begin
  inherited Create(ALine, ACol);
  Name := AName;
  Methods := TASTNodeList.Create;
end;

destructor TASTTraitDecl.Destroy;
begin
  Methods.Free;
  inherited Destroy;
end;

function TASTTraitDecl.Dump(Indent: Integer): string;
var
  I: Integer;
begin
  Result := MakeIndent(Indent) + Format('Trait: %s', [Name]);
  if Methods.Count > 0 then
  begin
    Result := Result + LineEnding + MakeIndent(Indent + 1) + 'Metodos:';
    for I := 0 to Methods.Count - 1 do
      Result := Result + LineEnding + Methods[I].Dump(Indent + 2);
  end;
end;

{ TASTImplDecl }

constructor TASTImplDecl.Create(ALine, ACol: Integer; const ATraitName, ATargetTypeName: string);
begin
  inherited Create(ALine, ACol);
  TraitName := ATraitName;
  TargetTypeName := ATargetTypeName;
  Methods := TASTNodeList.Create;
end;

destructor TASTImplDecl.Destroy;
begin
  Methods.Free;
  inherited Destroy;
end;

function TASTImplDecl.Dump(Indent: Integer): string;
var
  I: Integer;
begin
  Result := MakeIndent(Indent) + Format('Impl: %s para %s', [TraitName, TargetTypeName]);
  if Methods.Count > 0 then
  begin
    Result := Result + LineEnding + MakeIndent(Indent + 1) + 'Metodos Implementados:';
    for I := 0 to Methods.Count - 1 do
      Result := Result + LineEnding + Methods[I].Dump(Indent + 2);
  end;
end;

{ TASTModule }

constructor TASTModule.Create(ALine, ACol: Integer; const AName: string);
begin
  inherited Create(ALine, ACol);
  Name := AName;
  Imports := TStringList.Create;
  PascalImports := TStringList.Create;
  CImports := TStringList.Create;
  LinkDirectives := TStringList.Create;
  Types := TASTNodeList.Create;
  Traits := TASTNodeList.Create;
  Impls := TASTNodeList.Create;
  Functions := TASTNodeList.Create;
  ProgramBlock := nil;
end;

destructor TASTModule.Destroy;
begin
  Imports.Free;
  PascalImports.Free;
  CImports.Free;
  LinkDirectives.Free;
  Types.Free;
  Traits.Free;
  Impls.Free;
  Functions.Free;
  ProgramBlock.Free;
  inherited Destroy;
end;

function TASTModule.Dump(Indent: Integer): string;
var
  I: Integer;
begin
  Result := MakeIndent(Indent) + Format('Modulo: %s', [Name]);
  if Imports.Count > 0 then
  begin
    Result := Result + LineEnding + MakeIndent(Indent + 1) + 'Imports: ' + Imports.CommaText;
  end;

  if Types.Count > 0 then
  begin
    Result := Result + LineEnding + MakeIndent(Indent + 1) + 'Tipos Declarados:';
    for I := 0 to Types.Count - 1 do
      Result := Result + LineEnding + Types[I].Dump(Indent + 2);
  end;

  if Traits.Count > 0 then
  begin
    Result := Result + LineEnding + MakeIndent(Indent + 1) + 'Traits Declaradas:';
    for I := 0 to Traits.Count - 1 do
      Result := Result + LineEnding + Traits[I].Dump(Indent + 2);
  end;

  if Impls.Count > 0 then
  begin
    Result := Result + LineEnding + MakeIndent(Indent + 1) + 'Implementacoes (Impls):';
    for I := 0 to Impls.Count - 1 do
      Result := Result + LineEnding + Impls[I].Dump(Indent + 2);
  end;

  if Functions.Count > 0 then
  begin
    Result := Result + LineEnding + MakeIndent(Indent + 1) + 'Funcoes:';
    for I := 0 to Functions.Count - 1 do
      Result := Result + LineEnding + Functions[I].Dump(Indent + 2);
  end;

  if Assigned(ProgramBlock) then
  begin
    Result := Result + LineEnding + ProgramBlock.Dump(Indent + 1);
  end;
end;

function CloneASTNode(Node: TASTNode): TASTNode;
var
  I: Integer;
  InitNode: TASTExpr;
begin
  if not Assigned(Node) then Exit(nil);

  // Literais e Identificadores
  if Node is TASTLiteralExpr then
    Exit(TASTLiteralExpr.Create(Node.Line, Node.Col, TASTLiteralExpr(Node).Kind, TASTLiteralExpr(Node).Value))
  else if Node is TASTIdentifierExpr then
    Exit(TASTIdentifierExpr.Create(Node.Line, Node.Col, TASTIdentifierExpr(Node).Name))
  else if Node is TASTMemberAccessExpr then
    Exit(TASTMemberAccessExpr.Create(Node.Line, Node.Col, TASTExpr(CloneASTNode(TASTMemberAccessExpr(Node).Target)), TASTMemberAccessExpr(Node).Member))
  else if Node is TASTBinaryExpr then
    Exit(TASTBinaryExpr.Create(Node.Line, Node.Col, TASTExpr(CloneASTNode(TASTBinaryExpr(Node).Left)), TASTBinaryExpr(Node).Op, TASTExpr(CloneASTNode(TASTBinaryExpr(Node).Right))))
  else if Node is TASTUnaryExpr then
    Exit(TASTUnaryExpr.Create(Node.Line, Node.Col, TASTUnaryExpr(Node).Op, TASTExpr(CloneASTNode(TASTUnaryExpr(Node).Expr))))
  else if Node is TASTCallArg then
    Exit(TASTCallArg.Create(Node.Line, Node.Col, TASTCallArg(Node).Ownership, TASTExpr(CloneASTNode(TASTCallArg(Node).Expr))))
  else if Node is TASTCallExpr then
  begin
    Result := TASTCallExpr.Create(Node.Line, Node.Col, TASTCallExpr(Node).Callee);
    for I := 0 to TASTCallExpr(Node).Args.Count - 1 do
      TASTCallExpr(Result).Args.Add(CloneASTNode(TASTCallExpr(Node).Args[I]));
    Exit;
  end

  // Instruções
  else if Node is TASTAssignStmt then
    Exit(TASTAssignStmt.Create(Node.Line, Node.Col, TASTExpr(CloneASTNode(TASTAssignStmt(Node).Target)), TASTExpr(CloneASTNode(TASTAssignStmt(Node).Expr))))
  else if Node is TASTCallStmt then
    Exit(TASTCallStmt.Create(Node.Line, Node.Col, TASTCallExpr(CloneASTNode(TASTCallStmt(Node).CallExpr))))
  else if Node is TASTIfStmt then
  begin
    Result := TASTIfStmt.Create(Node.Line, Node.Col, TASTExpr(CloneASTNode(TASTIfStmt(Node).Condition)));
    for I := 0 to TASTIfStmt(Node).ThenBranch.Count - 1 do
      TASTIfStmt(Result).ThenBranch.Add(CloneASTNode(TASTIfStmt(Node).ThenBranch[I]));
    for I := 0 to TASTIfStmt(Node).ElseBranch.Count - 1 do
      TASTIfStmt(Result).ElseBranch.Add(CloneASTNode(TASTIfStmt(Node).ElseBranch[I]));
    Exit;
  end
  else if Node is TASTWhileStmt then
  begin
    Result := TASTWhileStmt.Create(Node.Line, Node.Col, TASTExpr(CloneASTNode(TASTWhileStmt(Node).Condition)));
    for I := 0 to TASTWhileStmt(Node).Body.Count - 1 do
      TASTWhileStmt(Result).Body.Add(CloneASTNode(TASTWhileStmt(Node).Body[I]));
    Exit;
  end
  else if Node is TASTPattern then
    Exit(TASTPattern.Create(Node.Line, Node.Col, TASTPattern(Node).Value, TASTPattern(Node).SubPattern, TASTPattern(Node).IsLet))
  else if Node is TASTMatchCase then
  begin
    Result := TASTMatchCase.Create(Node.Line, Node.Col, TASTPattern(CloneASTNode(TASTMatchCase(Node).Pattern)));
    for I := 0 to TASTMatchCase(Node).Body.Count - 1 do
      TASTMatchCase(Result).Body.Add(CloneASTNode(TASTMatchCase(Node).Body[I]));
    Exit;
  end
  else if Node is TASTMatchStmt then
  begin
    Result := TASTMatchStmt.Create(Node.Line, Node.Col, TASTExpr(CloneASTNode(TASTMatchStmt(Node).Expr)));
    for I := 0 to TASTMatchStmt(Node).Cases.Count - 1 do
      TASTMatchStmt(Result).Cases.Add(CloneASTNode(TASTMatchStmt(Node).Cases[I]));
    Exit;
  end
  else if Node is TASTReturnStmt then
  begin
    if Assigned(TASTReturnStmt(Node).Expr) then
      Exit(TASTReturnStmt.Create(Node.Line, Node.Col, TASTExpr(CloneASTNode(TASTReturnStmt(Node).Expr))))
    else
      Exit(TASTReturnStmt.Create(Node.Line, Node.Col, nil));
  end
  else if Node is TASTParam then
    Exit(TASTParam.Create(Node.Line, Node.Col, TASTParam(Node).Name, TASTParam(Node).TypeName, TASTParam(Node).Ownership))
  else if Node is TASTVarDecl then
  begin
    InitNode := nil;
    if Assigned(TASTVarDecl(Node).InitialExpr) then
      InitNode := TASTExpr(CloneASTNode(TASTVarDecl(Node).InitialExpr));
    Exit(TASTVarDecl.Create(Node.Line, Node.Col, TASTVarDecl(Node).Name, TASTVarDecl(Node).TypeName, InitNode, TASTVarDecl(Node).IsMutable));
  end;

  Result := nil;
end;

end.
