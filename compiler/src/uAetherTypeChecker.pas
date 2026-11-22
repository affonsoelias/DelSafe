unit uAetherTypeChecker;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  uAetherAST,
  uAetherSymbols;

type
  PTraitImplInfo = ^TTraitImplInfo;
  TTraitImplInfo = record
    TargetType: string;
    TraitName: string;
    OriginalMethod: string;
    MangledMethod: string;
  end;

  EAetherTypeError = class(Exception)
  public
    Line: Integer;
    Col: Integer;
    Code: string;
    constructor Create(const ACode, AMsg: string; ALine, ACol: Integer);
  end;

  TAetherTypeChecker = class
  private
    FSymbols: TSymbolTable;
    FCurrentFunction: TASTFunction;
    FModule: TASTModule;
    FTraitImpls: TFPList;
    FLoopDepth: Integer;
    FUnsafeDepth: Integer;

    procedure Error(const ACode, AMsg: string; ALine, ACol: Integer);
    function IsNumericType(const AType: string): Boolean;
    function IsIntegerType(const AType: string): Boolean;
    function IsSetType(const AType: string): Boolean;
    function IsDynamicArrayType(const AType: string; out ElemType: string): Boolean;
    function IsMapType(const AType: string; out KeyType, ValType: string): Boolean;
    function TypesAreCompatible(const TargetType, SourceType: string): Boolean;

    function CheckExpr(Expr: TASTExpr): string;
    function CheckLiteral(Lit: TASTLiteralExpr): string;
    function CheckIdentifier(Id: TASTIdentifierExpr): string;
    function CheckMemberAccess(Acc: TASTMemberAccessExpr): string;
    function CheckBinary(Bin: TASTBinaryExpr): string;
    function CheckUnary(Un: TASTUnaryExpr): string;
    function CheckAwait(AwaitExpr: TASTAwaitExpr): string;
    function CheckSpawn(SpawnExpr: TASTSpawnExpr): string;
    function CheckCall(Call: TASTCallExpr): string;
    function CheckIndexExpr(Idx: TASTIndexExpr): string;
    function CheckSetLiteral(SetLit: TASTSetLiteralExpr): string;

    procedure CheckStmt(Stmt: TASTStmt);
    procedure CheckAssign(Assign: TASTAssignStmt);
    procedure CheckIf(IfStmt: TASTIfStmt);
    procedure CheckWhile(WhileStmt: TASTWhileStmt);
    procedure CheckFor(ForStmt: TASTForStmt);
    procedure CheckRepeat(RepeatStmt: TASTRepeatStmt);
    procedure CheckBreak(BreakStmt: TASTBreakStmt);
    procedure CheckContinue(ContStmt: TASTContinueStmt);
    procedure CheckReturn(Ret: TASTReturnStmt);
    procedure CheckMatch(MatchStmt: TASTMatchStmt);

    procedure RegisterConstants(AModule: TASTModule);
    procedure RegisterTypes(AModule: TASTModule);
    procedure RegisterTraits(AModule: TASTModule);
    procedure RegisterImpls(AModule: TASTModule);
    procedure RegisterFunctions(AModule: TASTModule);
    function TypeImplementsTrait(const ATypeName, ATraitName: string): Boolean;
    function FindTraitMethod(const ATypeName, AMethodName: string): string;
    function MonomorphizeFunction(OriginalFunc: TASTFunction; const ConcreteType: string): TASTFunction;
    function HasForeignImports: Boolean;
    function InferForeignFunctionReturnType(const FuncName: string): string;
    procedure CheckFunction(Func: TASTFunction);
    procedure CheckProgramBlock(Prog: TASTProgramBlock);
    procedure CheckVarDecl(VarDecl: TASTVarDecl);
  public
    constructor Create;
    destructor Destroy; override;
    procedure CheckModule(AModule: TASTModule);
    property Symbols: TSymbolTable read FSymbols;
  end;

implementation

constructor EAetherTypeError.Create(const ACode, AMsg: string; ALine, ACol: Integer);
begin
  inherited Create(Format('[Erro Semantico %s em %d:%d]: %s', [ACode, ALine, ACol, AMsg]));
  Code := ACode;
  Line := ALine;
  Col := ACol;
end;

constructor TAetherTypeChecker.Create;
begin
  inherited Create;
  FSymbols := TSymbolTable.Create;
  FCurrentFunction := nil;
  FModule := nil;
  FTraitImpls := TFPList.Create;
  FLoopDepth := 0;
  FUnsafeDepth := 0;
end;

destructor TAetherTypeChecker.Destroy;
var
  I: Integer;
begin
  for I := 0 to FTraitImpls.Count - 1 do
    Dispose(PTraitImplInfo(FTraitImpls[I]));
  FTraitImpls.Free;
  FSymbols.Free;
  inherited Destroy;
end;

procedure TAetherTypeChecker.Error(const ACode, AMsg: string; ALine, ACol: Integer);
begin
  raise EAetherTypeError.Create(ACode, AMsg, ALine, ACol);
end;

function TAetherTypeChecker.IsNumericType(const AType: string): Boolean;
begin
  Result := (AType = 'Int8') or (AType = 'Int16') or (AType = 'Int32') or (AType = 'Int64') or
            (AType = 'UInt8') or (AType = 'UInt16') or (AType = 'UInt32') or (AType = 'UInt64') or
            (AType = 'Float32') or (AType = 'Float64');
end;

function TAetherTypeChecker.IsIntegerType(const AType: string): Boolean;
begin
  Result := (AType = 'Int8') or (AType = 'Int16') or (AType = 'Int32') or (AType = 'Int64') or
            (AType = 'UInt8') or (AType = 'UInt16') or (AType = 'UInt32') or (AType = 'UInt64') or
            (AType = 'IntLiteral');
end;

function TAetherTypeChecker.IsSetType(const AType: string): Boolean;
var
  Sym: TSymbol;
begin
  if (Pos('set of', AType) > 0) or (AType = 'SetLiteral') then
    Exit(True);
  if Assigned(FSymbols) then
  begin
    Sym := FSymbols.Resolve(AType);
    if (Sym <> nil) and (Sym.Kind = skType) and (Sym.Node is TASTSetDecl) then
      Exit(True);
  end;
  Result := False;
end;

function TAetherTypeChecker.IsDynamicArrayType(const AType: string; out ElemType: string): Boolean;
var
  Sym: TSymbol;
  ArrDecl: TASTArrayDecl;
begin
  ElemType := '';
  if Pos('array of ', AType) = 1 then
  begin
    ElemType := Trim(Copy(AType, 10, Length(AType)));
    Exit(True);
  end;
  if Assigned(FSymbols) then
  begin
    Sym := FSymbols.Resolve(AType);
    if (Sym <> nil) and (Sym.Kind = skType) and (Sym.Node is TASTArrayDecl) then
    begin
      ArrDecl := TASTArrayDecl(Sym.Node);
      if ArrDecl.Dims.Count = 0 then
      begin
        ElemType := ArrDecl.ElemType;
        Exit(True);
      end;
    end;
  end;
  Result := False;
end;

function TAetherTypeChecker.IsMapType(const AType: string; out KeyType, ValType: string): Boolean;
var
  Sym: TSymbol;
  MapDecl: TASTMapDecl;
  PClose: Integer;
begin
  KeyType := '';
  ValType := '';
  if Pos('map[', AType) = 1 then
  begin
    PClose := Pos(']', AType);
    if PClose > 4 then
    begin
      KeyType := Trim(Copy(AType, 5, PClose - 5));
      ValType := Trim(Copy(AType, PClose + 1, Length(AType)));
      Exit(True);
    end;
  end;
  if Assigned(FSymbols) then
  begin
    Sym := FSymbols.Resolve(AType);
    if (Sym <> nil) and (Sym.Kind = skType) and (Sym.Node is TASTMapDecl) then
    begin
      MapDecl := TASTMapDecl(Sym.Node);
      KeyType := MapDecl.KeyType;
      ValType := MapDecl.ValType;
      Exit(True);
    end;
  end;
  Result := False;
end;

function TAetherTypeChecker.TypesAreCompatible(const TargetType, SourceType: string): Boolean;
var
  TargetElem, SourceElem, TargetKey, TargetVal, SourceKey, SourceVal: string;
begin
  if TargetType = SourceType then Exit(True);
  // Mapas associativos
  if IsMapType(TargetType, TargetKey, TargetVal) and IsMapType(SourceType, SourceKey, SourceVal) then
    Exit(TypesAreCompatible(TargetKey, SourceKey) and TypesAreCompatible(TargetVal, SourceVal));
  // Ponteiros e nil
  if (SourceType = 'NilLiteral') and ((Pos('^', TargetType) = 1) or (TargetType = 'Pointer')) then Exit(True);
  if (TargetType = 'NilLiteral') and ((Pos('^', SourceType) = 1) or (SourceType = 'Pointer')) then Exit(True);
  if ((TargetType = 'Pointer') and (Pos('^', SourceType) = 1)) or ((SourceType = 'Pointer') and (Pos('^', TargetType) = 1)) then Exit(True);
  if (Pos('^', TargetType) = 1) and (Pos('^', SourceType) = 1) then
    Exit(TypesAreCompatible(Copy(TargetType, 2, Length(TargetType)), Copy(SourceType, 2, Length(SourceType))));
  // Arrays dinamicos
  if IsDynamicArrayType(TargetType, TargetElem) and IsDynamicArrayType(SourceType, SourceElem) then
    Exit(TypesAreCompatible(TargetElem, SourceElem));
  // Literais inteiros genericos sao compativeis com qualquer tipo inteiro
  if (SourceType = 'IntLiteral') and (Pos('Int', TargetType) > 0) then Exit(True);
  // Compatibilidade entre tipos inteiros (Int32, UInt32, etc.)
  if IsIntegerType(TargetType) and IsIntegerType(SourceType) then Exit(True);
  // Literais float genericos sao compativeis com Float32 ou Float64
  if (SourceType = 'FloatLiteral') and (Pos('Float', TargetType) > 0) then Exit(True);
  // Genericos Result / Option / Box
  if (Pos('Result', TargetType) = 1) and (Pos('Result', SourceType) = 1) then Exit(True);
  if (Pos('Option', TargetType) = 1) and ((Pos('Option', SourceType) = 1) or (SourceType = 'Option<GenericNone>')) then Exit(True);
  if (Pos('Box', TargetType) = 1) and (Pos('Box', SourceType) = 1) then Exit(True);
  if (Pos('Task', TargetType) = 1) and (Pos('Task', SourceType) = 1) then Exit(True);
  if (Pos('Option<Box<', TargetType) = 1) and ((Pos('Box<', SourceType) = 1) or (SourceType = 'Option<GenericNone>')) then Exit(True);
  // Literais de conjunto e tipos set
  if (SourceType = 'SetLiteral') and IsSetType(TargetType) then Exit(True);
  if (TargetType = 'SetLiteral') and IsSetType(SourceType) then Exit(True);
  if IsSetType(TargetType) and IsSetType(SourceType) then Exit(True);
  // Compatibilidade com subfaixas e tipos definidos pelo usuario
  if Assigned(FSymbols) then
  begin
    if Assigned(FSymbols.Resolve(TargetType)) and (FSymbols.Resolve(TargetType).Node is TASTSubrangeDecl) then
    begin
      if TypesAreCompatible(TASTSubrangeDecl(FSymbols.Resolve(TargetType).Node).BaseType, SourceType) then Exit(True);
    end;
    if Assigned(FSymbols.Resolve(SourceType)) and (FSymbols.Resolve(SourceType).Node is TASTSubrangeDecl) then
    begin
      if TypesAreCompatible(TargetType, TASTSubrangeDecl(FSymbols.Resolve(SourceType).Node).BaseType) then Exit(True);
    end;
  end;
  Result := False;
end;

function TAetherTypeChecker.CheckLiteral(Lit: TASTLiteralExpr): string;
begin
  case Lit.Kind of
    lkInt:    Result := 'IntLiteral';
    lkFloat:  Result := 'FloatLiteral';
    lkString: Result := 'String';
    lkChar:   Result := 'Char';
    lkBool:   Result := 'Bool';
    lkNil:    Result := 'NilLiteral';
  else
    Result := 'Unknown';
  end;
end;

function TAetherTypeChecker.CheckIdentifier(Id: TASTIdentifierExpr): string;
var
  Sym: TSymbol;
begin
  // Caso especial: 'None' (Option vazio)
  if SameText(Id.Name, 'None') then
    Exit('Option<GenericNone>');

  // Caso especial: 'result' dentro de contratos
  if SameText(Id.Name, 'result') and Assigned(FCurrentFunction) then
    Exit(FCurrentFunction.ReturnType);

  Sym := FSymbols.Resolve(Id.Name);
  if not Assigned(Sym) then
    Error('E0425', Format('Identificador nao encontrado: "%s"', [Id.Name]), Id.Line, Id.Col);

  Result := Sym.TypeName;
end;

function TAetherTypeChecker.CheckMemberAccess(Acc: TASTMemberAccessExpr): string;
var
  TargetType: string;
  Sym: TSymbol;
  I, P1, P2: Integer;
  RecDecl: TASTRecordDecl;
  EnumDecl: TASTEnumDecl;
  Field: TASTRecordField;
  InnerRecName: string;
begin
  // Se o alvo for um Identificador, pode ser um tipo (Enum) ou uma variavel
  if Acc.Target is TASTIdentifierExpr then
  begin
    Sym := FSymbols.Resolve(TASTIdentifierExpr(Acc.Target).Name);
    if Assigned(Sym) then
    begin
      // Caso Enum.Variante (ex: MathError.DivisaoPorZero)
      if (Sym.Kind = skType) and (Sym.Node is TASTEnumDecl) then
      begin
        EnumDecl := TASTEnumDecl(Sym.Node);
        for I := 0 to EnumDecl.Variants.Count - 1 do
        begin
          if SameText(TASTEnumVariant(EnumDecl.Variants[I]).Name, Acc.Member) then
            Exit(EnumDecl.Name);
        end;
        Error('E0599', Format('Variante "%s" nao pertence ao enum "%s"', [Acc.Member, EnumDecl.Name]), Acc.Line, Acc.Col);
      end;
    end;
  end;

  TargetType := CheckExpr(Acc.Target);

  // Propriedades intrinsecas de Result (ex: result.is_ok)
  if (Pos('Result', TargetType) = 1) and (SameText(Acc.Member, 'is_ok') or SameText(Acc.Member, 'is_err')) then
    Exit('Bool');

  // Propriedades intrinsecas de Option (ex: opt.is_some, opt.is_none, opt.value)
  if (Pos('Option', TargetType) = 1) then
  begin
    if SameText(Acc.Member, 'is_some') or SameText(Acc.Member, 'is_none') then
      Exit('Bool');

    if SameText(Acc.Member, 'value') then
    begin
      P1 := Pos('<', TargetType);
      InnerRecName := Copy(TargetType, P1 + 1, Length(TargetType));
      P2 := Pos('>', InnerRecName);
      if P2 > 0 then InnerRecName := Copy(InnerRecName, 1, P2 - 1);
      if Pos('Box<', InnerRecName) = 1 then
      begin
        P1 := Pos('<', InnerRecName);
        InnerRecName := Copy(InnerRecName, P1 + 1, Length(InnerRecName));
        P2 := Pos('>', InnerRecName);
        if P2 > 0 then InnerRecName := Copy(InnerRecName, 1, P2 - 1);
      end;
      Exit(InnerRecName);
    end;
  end;

  // Auto-deref de Box<Record> ou Option<Box<Record>>
  if Pos('Box<', TargetType) > 0 then
  begin
    P1 := Pos('Box<', TargetType);
    InnerRecName := Copy(TargetType, P1 + 4, Length(TargetType));
    P2 := Pos('>', InnerRecName);
    if P2 > 0 then InnerRecName := Copy(InnerRecName, 1, P2 - 1);

    if SameText(Acc.Member, 'value') then
      Exit(InnerRecName);

    Sym := FSymbols.ResolveTypeSymbol(InnerRecName);
    if Assigned(Sym) and (Sym.Node is TASTRecordDecl) then
    begin
      RecDecl := TASTRecordDecl(Sym.Node);
      for I := 0 to RecDecl.Fields.Count - 1 do
      begin
        Field := TASTRecordField(RecDecl.Fields[I]);
        if SameText(Field.Name, Acc.Member) then
          Exit(Field.TypeName);
      end;
    end;
  end;

  // Membro de Record
  Sym := FSymbols.ResolveTypeSymbol(TargetType);
  if Assigned(Sym) and (Sym.Node is TASTRecordDecl) then
  begin
    RecDecl := TASTRecordDecl(Sym.Node);
    for I := 0 to RecDecl.Fields.Count - 1 do
    begin
      Field := TASTRecordField(RecDecl.Fields[I]);
      if SameText(Field.Name, Acc.Member) then
        Exit(Field.TypeName);
    end;
    Error('E0609', Format('Campo "%s" nao existe no record "%s"', [Acc.Member, TargetType]), Acc.Line, Acc.Col);
  end;

  Error('E0609', Format('Nao e possivel acessar membro "%s" no tipo "%s"', [Acc.Member, TargetType]), Acc.Line, Acc.Col);
  Result := 'Unknown';
end;

function TAetherTypeChecker.CheckBinary(Bin: TASTBinaryExpr): string;
var
  LeftType, RightType: string;
begin
  LeftType := CheckExpr(Bin.Left);
  RightType := CheckExpr(Bin.Right);

  // Operacoes Aritmeticas: +, -, *, /, mod, div, %
  if (Bin.Op = '+') or (Bin.Op = '-') or (Bin.Op = '*') or (Bin.Op = '/') or (Bin.Op = 'mod') or (Bin.Op = 'div') or (Bin.Op = '%') then
  begin
    // Operacoes de conjunto: uniao (+), intersecao (*), diferenca (-)
    if (Bin.Op = '+') or (Bin.Op = '-') or (Bin.Op = '*') then
    begin
      if IsSetType(LeftType) or IsSetType(RightType) then
      begin
        if LeftType <> 'SetLiteral' then Exit(LeftType)
        else Exit(RightType);
      end;
    end;

    // Concatenacao de strings com +
    if (Bin.Op = '+') and ((LeftType = 'String') or (RightType = 'String')) then
      Exit('String');

    if not IsNumericType(LeftType) and (LeftType <> 'IntLiteral') and (LeftType <> 'FloatLiteral') then
      Error('E0369', Format('Operando esquerdo de "%s" deve ser numerico, encontrado: "%s"', [Bin.Op, LeftType]), Bin.Line, Bin.Col);

    if not IsNumericType(RightType) and (RightType <> 'IntLiteral') and (RightType <> 'FloatLiteral') then
      Error('E0369', Format('Operando direito de "%s" deve ser numerico, encontrado: "%s"', [Bin.Op, RightType]), Bin.Line, Bin.Col);

    // Deteccao de divisao por zero em tempo de compilacao (comptime / const eval)
    if (Bin.Op = '/') or (Bin.Op = 'mod') or (Bin.Op = 'div') or (Bin.Op = '%') then
    begin
      if (Bin.Right is TASTLiteralExpr) and
         (((TASTLiteralExpr(Bin.Right).Kind = lkInt) and (TASTLiteralExpr(Bin.Right).Value = '0')) or
          ((TASTLiteralExpr(Bin.Right).Kind = lkFloat) and (StrToFloatDef(TASTLiteralExpr(Bin.Right).Value, 1.0) = 0.0))) then
      begin
        Error('E0301', 'Divisao por zero detectada em tempo de compilacao (comptime)', Bin.Line, Bin.Col);
      end;
    end;

    if (LeftType = 'Float64') or (RightType = 'Float64') or (LeftType = 'FloatLiteral') or (RightType = 'FloatLiteral') then
      Exit('Float64')
    else
      Exit(LeftType);
  end;

  // Operacoes Relacionais: =, <>, <, <=, >, >=
  if (Bin.Op = '=') or (Bin.Op = '<>') or (Bin.Op = '<') or (Bin.Op = '<=') or (Bin.Op = '>') or (Bin.Op = '>=') then
  begin
    if not TypesAreCompatible(LeftType, RightType) and not TypesAreCompatible(RightType, LeftType) then
      Error('E0308', Format('Comparacao entre tipos incompativeis: "%s" e "%s"', [LeftType, RightType]), Bin.Line, Bin.Col);
    Exit('Bool');
  end;

  // Operacoes de deslocamento de bits: shl, shr
  if SameText(Bin.Op, 'shl') or SameText(Bin.Op, 'shr') then
  begin
    if not IsIntegerType(LeftType) then
      Error('E0369', Format('Operando esquerdo de "%s" deve ser inteiro, encontrado: "%s"', [Bin.Op, LeftType]), Bin.Line, Bin.Col);
    if not IsIntegerType(RightType) then
      Error('E0369', Format('Operando direito de "%s" deve ser inteiro, encontrado: "%s"', [Bin.Op, RightType]), Bin.Line, Bin.Col);
    if LeftType = 'IntLiteral' then Exit('Int32')
    else Exit(LeftType);
  end;

  // Operacoes Logicas e Bitwise: and, or, xor, implies
  if SameText(Bin.Op, 'and') or SameText(Bin.Op, 'or') or SameText(Bin.Op, 'xor') or SameText(Bin.Op, 'implies') then
  begin
    if (not SameText(Bin.Op, 'implies')) and IsIntegerType(LeftType) and IsIntegerType(RightType) then
    begin
      if LeftType = 'IntLiteral' then
      begin
        if RightType = 'IntLiteral' then Exit('Int32')
        else Exit(RightType);
      end;
      Exit(LeftType);
    end;
    if (LeftType <> 'Bool') then
      Error('E0308', Format('Operando de "%s" deve ser Bool, encontrado: "%s"', [Bin.Op, LeftType]), Bin.Line, Bin.Col);
    if (RightType <> 'Bool') then
      Error('E0308', Format('Operando de "%s" deve ser Bool, encontrado: "%s"', [Bin.Op, RightType]), Bin.Line, Bin.Col);
    Exit('Bool');
  end;

  // Operador de Pertinência de Conjunto: in
  if Bin.Op = 'in' then
  begin
    Exit('Bool');
  end;

  Result := 'Unknown';
end;

function TAetherTypeChecker.CheckUnary(Un: TASTUnaryExpr): string;
var
  OperandType: string;
begin
  if Un.Op = '@' then
  begin
    OperandType := CheckExpr(Un.Expr);
    Exit('^' + OperandType);
  end
  else if Un.Op = '^' then
  begin
    if FUnsafeDepth <= 0 then
      Error('E0312', 'Desreferencia de ponteiro bruto ("^") exige um bloco "unsafe ... end;"', Un.Line, Un.Col);
    OperandType := CheckExpr(Un.Expr);
    if Pos('^', OperandType) = 1 then
      Exit(Copy(OperandType, 2, Length(OperandType)));
    Error('E0308', Format('Nao e possivel desreferenciar tipo nao-ponteiro: "%s"', [OperandType]), Un.Line, Un.Col);
  end;

  OperandType := CheckExpr(Un.Expr);
  if Un.Op = '-' then
  begin
    if not IsNumericType(OperandType) and (OperandType <> 'IntLiteral') and (OperandType <> 'FloatLiteral') then
      Error('E0369', Format('Operador unario "-" exige tipo numerico, encontrado: "%s"', [OperandType]), Un.Line, Un.Col);
    Exit(OperandType);
  end
  else if SameText(Un.Op, 'not') then
  begin
    if IsIntegerType(OperandType) then
    begin
      if OperandType = 'IntLiteral' then Exit('Int32')
      else Exit(OperandType);
    end;
    if OperandType <> 'Bool' then
      Error('E0308', Format('Operador "not" exige tipo Bool ou Inteiro, encontrado: "%s"', [OperandType]), Un.Line, Un.Col);
    Exit('Bool');
  end;
  Result := OperandType;
end;

function TAetherTypeChecker.CheckAwait(AwaitExpr: TASTAwaitExpr): string;
var
  InnerType: string;
begin
  InnerType := CheckExpr(AwaitExpr.Expr);
  if (Copy(InnerType, 1, 5) = 'Task<') and (InnerType[Length(InnerType)] = '>') then
    Result := Copy(InnerType, 6, Length(InnerType) - 6)
  else
    Result := InnerType;
end;

function TAetherTypeChecker.CheckSpawn(SpawnExpr: TASTSpawnExpr): string;
var
  CallType: string;
begin
  CallType := CheckExpr(SpawnExpr.CallExpr);
  if (Copy(CallType, 1, 5) = 'Task<') and (CallType[Length(CallType)] = '>') then
    Result := CallType
  else
    Result := 'Task<' + CallType + '>';
end;

function TAetherTypeChecker.HasForeignImports: Boolean;
begin
  Result := Assigned(FModule) and
            (((FModule.PascalImports <> nil) and (FModule.PascalImports.Count > 0)) or
             ((FModule.CImports <> nil) and (FModule.CImports.Count > 0)));
end;

function TAetherTypeChecker.InferForeignFunctionReturnType(const FuncName: string): string;
var
  LowName: string;
begin
  LowName := LowerCase(FuncName);
  if (LowName = 'sin') or (LowName = 'cos') or (LowName = 'tan') or
     (LowName = 'sqrt') or (LowName = 'asin') or (LowName = 'acos') or
     (LowName = 'atan') or (LowName = 'exp') or (LowName = 'ln') or
     (LowName = 'log10') or (LowName = 'pow') or (LowName = 'floor') or
     (LowName = 'ceil') or (LowName = 'now') then
    Exit('Float64');

  if (LowName = 'gettickcount64') or (LowName = 'gettickcount') then
    Exit('UInt64');

  if (LowName = 'inttostr') or (LowName = 'floattostr') or (LowName = 'booltostr') or
     (LowName = 'timetostr') or (LowName = 'datetostr') or
     (LowName = 'formatdatetime') then
    Exit('String');

  if (LowName = 'strtoint') or (LowName = 'strtointdef') or
     (LowName = 'length') or (LowName = 'puts') or (LowName = 'printf') then
    Exit('Int32');

  Result := 'Float64';
end;

function TAetherTypeChecker.CheckCall(Call: TASTCallExpr): string;
var
  Sym, SymMono, TypeSym: TSymbol;
  FuncNode, MonoFunc: TASTFunction;
  RecDecl: TASTRecordDecl;
  SubSym: TSymbol;
  I: Integer;
  Arg: TASTCallArg;
  ArgType, ExpectedType, Mangled, MonomorphedName, ElemType, KeyType, ValType: string;
begin
  if Call.Callee = '__InterpToStr' then
  begin
    if Call.Args.Count <> 1 then
      Error('E0061', 'Interpolacao espera 1 expressao por bloco "{...}"', Call.Line, Call.Col);
    ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
    SubSym := FSymbols.Resolve(ArgType);
    if IsIntegerType(ArgType) or
       (Assigned(SubSym) and (SubSym.Node is TASTSubrangeDecl) and (TASTSubrangeDecl(SubSym.Node).BaseType <> 'Char')) then
      Call.Callee := 'IntToStr'
    else if (ArgType = 'Float32') or (ArgType = 'Float64') or (ArgType = 'FloatLiteral') then
      Call.Callee := 'FloatToStr'
    else if ArgType = 'Bool' then
      Call.Callee := 'BoolToStr'
    else if (ArgType = 'Char') or
            (Assigned(SubSym) and (SubSym.Node is TASTSubrangeDecl) and (TASTSubrangeDecl(SubSym.Node).BaseType = 'Char')) then
      Call.Callee := 'CharToStr';
    Exit('String');
  end;

  if Call.Callee = 'CharToStr' then
  begin
    if Call.Args.Count <> 1 then
      Error('E0061', 'Funcao "CharToStr" espera 1 argumento (Char)', Call.Line, Call.Col);
    CheckExpr(TASTCallArg(Call.Args[0]).Expr);
    Exit('String');
  end;

  // Atalhos embutidos Ok() e Err()
  if Call.Callee = 'Ok' then
  begin
    if Call.Args.Count <> 1 then
      Error('E0061', 'Ok() exige exatamente 1 argumento', Call.Line, Call.Col);
    ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
    Exit('Result<' + ArgType + ', GenericError>');
  end;

  if Call.Callee = 'Err' then
  begin
    if Call.Args.Count <> 1 then
      Error('E0061', 'Err() exige exatamente 1 argumento', Call.Line, Call.Col);
    ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
    Exit('Result<GenericValue, ' + ArgType + '>');
  end;

  if Call.Callee = 'Some' then
  begin
    if Call.Args.Count <> 1 then
      Error('E0061', 'Some() exige exatamente 1 argumento', Call.Line, Call.Col);
    ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
    Exit('Option<' + ArgType + '>');
  end;

  if Call.Callee = 'Box' then
  begin
    if Call.Args.Count <> 1 then
      Error('E0061', 'Box() exige exatamente 1 argumento', Call.Line, Call.Col);
    ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
    Exit('Box<' + ArgType + '>');
  end;

  Sym := FSymbols.Resolve(Call.Callee);
  if (not Assigned(Sym)) or (Sym.Kind = skVariable) or (Sym.Kind = skTrait) then
  begin
    TypeSym := FSymbols.ResolveTypeSymbol(Call.Callee);
    if Assigned(TypeSym) and (TypeSym.Kind <> skTrait) then
      Sym := TypeSym
    else
      Sym := nil;
  end;

  if not Assigned(Sym) then
  begin
    // Resolução de método de Trait via primeiro argumento (UFCS)
    if Call.Args.Count > 0 then
    begin
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if Pos('Box<', ArgType) = 1 then
      begin
        ArgType := Copy(ArgType, 5, Length(ArgType) - 5);
        if (Length(ArgType) > 0) and (ArgType[Length(ArgType)] = '>') then
          ArgType := Copy(ArgType, 1, Length(ArgType) - 1);
      end;

      Mangled := FindTraitMethod(ArgType, Call.Callee);
      if Mangled <> '' then
      begin
        Call.Callee := Mangled;
        Sym := FSymbols.Resolve(Call.Callee);
      end;
    end;

    if not Assigned(Sym) then
    begin
      // Interoperabilidade Transparente:
      // Se houver imports de units Pascal (import pascal) ou headers C (import c),
      // e a funcao nao for local, permitimos a invocacao direta sem necessidade de extern!
      if HasForeignImports then
      begin
        for I := 0 to Call.Args.Count - 1 do
          CheckExpr(TASTCallArg(Call.Args[I]).Expr);
        Exit(InferForeignFunctionReturnType(Call.Callee));
      end;

      Error('E0425', Format('Funcao ou tipo nao encontrado: "%s"', [Call.Callee]), Call.Line, Call.Col);
    end;
  end;

  // Construtor de Record: DataBuffer(id: 101, size: 2048)
  if (Sym.Kind = skType) and (Sym.Node is TASTRecordDecl) then
  begin
    RecDecl := TASTRecordDecl(Sym.Node);
    if Call.Args.Count <> RecDecl.Fields.Count then
      Error('E0061', Format('Construtor do record "%s" espera %d campos, mas recebeu %d',
        [RecDecl.Name, RecDecl.Fields.Count, Call.Args.Count]), Call.Line, Call.Col);

    for I := 0 to Call.Args.Count - 1 do
    begin
      Arg := TASTCallArg(Call.Args[I]);
      ArgType := CheckExpr(Arg.Expr);
      ExpectedType := TASTRecordField(RecDecl.Fields[I]).TypeName;
      if not TypesAreCompatible(ExpectedType, ArgType) then
        Error('E0308', Format('Campo "%s" do record "%s" espera "%s", mas recebeu "%s"',
          [TASTRecordField(RecDecl.Fields[I]).Name, RecDecl.Name, ExpectedType, ArgType]), Arg.Line, Arg.Col);
    end;
    Exit(RecDecl.Name);
  end;

  // Conversao explicita de tipo primitivo (Typecast: Int32(x), UInt32(x), Float64(x), etc.)
  if (Sym.Kind = skType) and (not Assigned(Sym.Node) or not (Sym.Node is TASTRecordDecl)) then
  begin
    if Call.Args.Count <> 1 then
      Error('E0061', Format('Conversao de tipo "%s" espera exatamente 1 argumento', [Call.Callee]), Call.Line, Call.Col);
    if Call.Args.Count > 0 then
      CheckExpr(TASTCallArg(Call.Args[0]).Expr);
    Exit(Call.Callee);
  end;

  // Chamada de Funcao Normal ou Generica
  if Sym.Kind = skFunction then
  begin
    FuncNode := TASTFunction(Sym.Node);

    // Se for funcao generica com Trait Bound, monomorfiza para o tipo concreto
    if Assigned(FuncNode) and (FuncNode.GenericParam <> '') then
    begin
      if Call.Args.Count = 0 then
        Error('E0061', Format('Funcao generica "%s" requer pelo menos 1 argumento para deducao de tipo', [FuncNode.Name]), Call.Line, Call.Col);

      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if Pos('Box<', ArgType) = 1 then
      begin
        ArgType := Copy(ArgType, 5, Length(ArgType) - 5);
        if (Length(ArgType) > 0) and (ArgType[Length(ArgType)] = '>') then
          ArgType := Copy(ArgType, 1, Length(ArgType) - 1);
      end;

      if FuncNode.TraitBound <> '' then
      begin
        if not TypeImplementsTrait(ArgType, FuncNode.TraitBound) then
          Error('E0277', Format('O tipo "%s" nao implementa a trait "%s"', [ArgType, FuncNode.TraitBound]), Call.Line, Call.Col);
      end;

      MonomorphedName := FuncNode.Name + '_' + ArgType;
      SymMono := FSymbols.Resolve(MonomorphedName);
      if not Assigned(SymMono) then
      begin
        MonoFunc := MonomorphizeFunction(FuncNode, ArgType);
        FModule.Functions.Add(MonoFunc);
        FSymbols.Define(TSymbol.Create(MonoFunc.Name, skFunction, MonoFunc.ReturnType, MonoFunc.Line, MonoFunc.Col, False, owNone, MonoFunc));
        CheckFunction(MonoFunc);
        SymMono := FSymbols.Resolve(MonomorphedName);
      end;

      Call.Callee := MonomorphedName;
      Sym := SymMono;
      FuncNode := TASTFunction(Sym.Node);
    end;

    // PrintLn embutido com parametros variaveis
    if (Call.Callee = 'PrintLn') or (Call.Callee = 'Print') then
    begin
      for I := 0 to Call.Args.Count - 1 do
        CheckExpr(TASTCallArg(Call.Args[I]).Expr);
      Exit('Void');
    end;

    if SameText(Call.Callee, 'Length') or SameText(Call.Callee, 'Count') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', Format('Funcao "%s" espera 1 argumento (String, Array ou Mapa)', [Call.Callee]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if (ArgType = 'String') and SameText(Call.Callee, 'Length') then
        Exit('UInt32')
      else if IsDynamicArrayType(ArgType, ElemType) or IsMapType(ArgType, KeyType, ValType) or (Pos('array[', ArgType) = 1) or
              (Assigned(FSymbols.Resolve(ArgType)) and (FSymbols.Resolve(ArgType).Node is TASTArrayDecl)) then
        Exit('Int32')
      else
        Error('E0308', Format('Funcao "%s" espera String, Array ou Mapa, recebeu: "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
    end;

    if SameText(Call.Callee, 'Contains') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Funcao "Contains" espera 2 argumentos (Mapa, Chave)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsMapType(ArgType, KeyType, ValType) then
        Error('E0308', Format('Primeiro argumento de "Contains" deve ser Mapa, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if not TypesAreCompatible(KeyType, ArgType) then
        Error('E0308', Format('Chave de "Contains" incompativel: esperado "%s", recebeu "%s"', [KeyType, ArgType]), Call.Line, Call.Col);
      Exit('Bool');
    end;

    if SameText(Call.Callee, 'Remove') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Funcao "Remove" espera 2 argumentos (Mapa, Chave)', Call.Line, Call.Col);
      if TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr then
      begin
        SubSym := FSymbols.Resolve(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name);
        if Assigned(SubSym) and (not SubSym.IsMutable) then
          Error('E0384', Format('Nao e possivel remover chave de mapa imutavel (declarado com "let"): "%s"', [SubSym.Name]), Call.Line, Call.Col);
      end;
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsMapType(ArgType, KeyType, ValType) then
        Error('E0308', Format('Primeiro argumento de "Remove" deve ser Mapa, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if not TypesAreCompatible(KeyType, ArgType) then
        Error('E0308', Format('Chave de "Remove" incompativel: esperado "%s", recebeu "%s"', [KeyType, ArgType]), Call.Line, Call.Col);
      Exit('Void');
    end;

    if SameText(Call.Callee, 'SetLength') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Funcao "SetLength" espera 2 argumentos (ArrayDinamico, Tamanho)', Call.Line, Call.Col);
      if TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr then
      begin
        SubSym := FSymbols.Resolve(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name);
        if Assigned(SubSym) and (not SubSym.IsMutable) then
          Error('E0384', Format('Nao e possivel redimensionar array imutavel (declarado com "let"): "%s"', [SubSym.Name]), Call.Line, Call.Col);
      end;
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsDynamicArrayType(ArgType, ElemType) and (ArgType <> 'String') then
        Error('E0308', Format('Primeiro argumento de "SetLength" deve ser Array Dinamico, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if not IsIntegerType(ArgType) then
        Error('E0308', Format('Segundo argumento de "SetLength" deve ser inteiro, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Void');
    end;

    if SameText(Call.Callee, 'Push') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Funcao "Push" espera 2 argumentos (ArrayDinamico, Elemento)', Call.Line, Call.Col);
      if TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr then
      begin
        SubSym := FSymbols.Resolve(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name);
        if Assigned(SubSym) and (not SubSym.IsMutable) then
          Error('E0384', Format('Nao e possivel adicionar elemento em array imutavel (declarado com "let"): "%s"', [SubSym.Name]), Call.Line, Call.Col);
      end;
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsDynamicArrayType(ArgType, ElemType) then
        Error('E0308', Format('Primeiro argumento de "Push" deve ser Array Dinamico, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if not TypesAreCompatible(ElemType, ArgType) then
        Error('E0308', Format('Tipo do elemento em "Push" incompativel: esperado "%s", recebeu "%s"', [ElemType, ArgType]), Call.Line, Call.Col);
      Exit('Void');
    end;

    if Call.Callee = 'CharAt' then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Funcao "CharAt" espera 2 argumentos (String, UInt32)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('Primeiro argumento de "CharAt" deve ser String, recebido: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if not IsIntegerType(ArgType) and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('Segundo argumento de "CharAt" deve ser inteiro, recebido: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('String');
    end;

    if Call.Callee = 'Substring' then
    begin
      if Call.Args.Count <> 3 then
        Error('E0061', 'Funcao "Substring" espera 3 argumentos (String, UInt32, UInt32)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('Primeiro argumento de "Substring" deve ser String, recebido: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if not IsIntegerType(ArgType) and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('Segundo argumento (start) de "Substring" deve ser inteiro, recebido: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[2]).Expr);
      if not IsIntegerType(ArgType) and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('Terceiro argumento (len) de "Substring" deve ser inteiro, recebido: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('String');
    end;

    if Call.Callee = 'FileExists' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Funcao "FileExists" espera 1 argumento (String)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('Funcao "FileExists" espera String, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Bool');
    end;

    if Call.Callee = 'ReadFile' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Funcao "ReadFile" espera 1 argumento (String)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('Funcao "ReadFile" espera String, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('String');
    end;

    if Call.Callee = 'WriteFile' then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Funcao "WriteFile" espera 2 argumentos (String, String)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('Primeiro argumento de "WriteFile" deve ser String, recebido: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('Segundo argumento de "WriteFile" deve ser String, recebido: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Bool');
    end;

    if (Call.Callee = 'CreateDir') or (Call.Callee = 'RemoveDir') or (Call.Callee = 'DeleteFile') or (Call.Callee = 'DirExists') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', Format('Funcao "%s" espera 1 argumento (String)', [Call.Callee]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('Funcao "%s" espera String, recebeu: "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      Exit('Bool');
    end;

    if Call.Callee = 'FileSize' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Funcao "FileSize" espera 1 argumento (String)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('Funcao "FileSize" espera String, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Int64');
    end;

    if Call.Callee = 'GetNanoseconds' then
    begin
      if Call.Args.Count <> 0 then
        Error('E0061', 'Funcao "GetNanoseconds" nao espera argumentos', Call.Line, Call.Col);
      Exit('UInt64');
    end;

    if Call.Callee = 'SleepMs' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Funcao "SleepMs" espera 1 argumento (UInt32)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsIntegerType(ArgType) and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('Funcao "SleepMs" espera tipo inteiro, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Void');
    end;

    if Call.Callee = 'IntToStr' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Funcao "IntToStr" espera 1 argumento (Int32)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsIntegerType(ArgType) and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('Funcao "IntToStr" espera tipo inteiro, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('String');
    end;

    if Call.Callee = 'FloatToStr' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Funcao "FloatToStr" espera 1 argumento (Float64)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsNumericType(ArgType) and (ArgType <> 'FloatLiteral') and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('Funcao "FloatToStr" espera tipo numerico, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('String');
    end;

    if Call.Callee = 'BoolToStr' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Funcao "BoolToStr" espera 1 argumento (Bool)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if (ArgType <> 'Bool') then
        Error('E0308', Format('Funcao "BoolToStr" espera Bool, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('String');
    end;

    if Call.Callee = 'StrToInt' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Funcao "StrToInt" espera 1 argumento (String)', Call.Line, Call.Col);
      Exit('Int32');
    end;

    if Call.Callee = 'ParamCount' then
    begin
      if Call.Args.Count <> 0 then
        Error('E0061', 'Funcao "ParamCount" nao espera argumentos', Call.Line, Call.Col);
      Exit('Int32');
    end;

    if Call.Callee = 'ParamStr' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Funcao "ParamStr" espera 1 argumento (Int32)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsIntegerType(ArgType) and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('Funcao "ParamStr" espera Int32, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('String');
    end;

    if Call.Callee = 'Assert' then
    begin
      if (Call.Args.Count < 1) or (Call.Args.Count > 2) then
        Error('E0061', 'Funcao "Assert" espera 1 ou 2 argumentos (Condicao: Bool [, Mensagem: String])', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'Bool' then
        Error('E0308', Format('Primeiro argumento de "Assert" deve ser Bool, recebido: "%s"', [ArgType]), Call.Line, Call.Col);
      if Call.Args.Count = 2 then
      begin
        ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
        if ArgType <> 'String' then
          Error('E0308', Format('Segundo argumento de "Assert" deve ser String, recebido: "%s"', [ArgType]), Call.Line, Call.Col);
      end;
      Exit('Void');
    end;

    if Call.Callee = 'SocketCreate' then
    begin
      if Call.Args.Count <> 0 then
        Error('E0061', 'Funcao "SocketCreate" nao espera argumentos', Call.Line, Call.Col);
      Exit('Int32');
    end;

    if Call.Callee = 'SocketListen' then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Funcao "SocketListen" espera 2 argumentos (Port: UInt32, Backlog: Int32)', Call.Line, Call.Col);
      Exit('Int32');
    end;

    if Call.Callee = 'SocketAccept' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Funcao "SocketAccept" espera 1 argumento (ListenFd: Int32)', Call.Line, Call.Col);
      Exit('Int32');
    end;

    if Call.Callee = 'SocketConnect' then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Funcao "SocketConnect" espera 2 argumentos (Host: String, Port: UInt32)', Call.Line, Call.Col);
      Exit('Int32');
    end;

    if Call.Callee = 'SocketSend' then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Funcao "SocketSend" espera 2 argumentos (Fd: Int32, Data: String)', Call.Line, Call.Col);
      Exit('Int32');
    end;

    if Call.Callee = 'SocketRecv' then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Funcao "SocketRecv" espera 2 argumentos (Fd: Int32, MaxLen: Int32)', Call.Line, Call.Col);
      Exit('String');
    end;

    if Call.Callee = 'SocketClose' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Funcao "SocketClose" espera 1 argumento (Fd: Int32)', Call.Line, Call.Col);
      Exit('Void');
    end;

    if Assigned(Sym.Node) and (Sym.Node is TASTFunction) then
    begin
      FuncNode := TASTFunction(Sym.Node);
      if Call.Args.Count <> FuncNode.Params.Count then
        Error('E0061', Format('Funcao "%s" espera %d argumentos, mas recebeu %d',
          [FuncNode.Name, FuncNode.Params.Count, Call.Args.Count]), Call.Line, Call.Col);

      for I := 0 to Call.Args.Count - 1 do
      begin
        Arg := TASTCallArg(Call.Args[I]);
        ArgType := CheckExpr(Arg.Expr);
        ExpectedType := TASTParam(FuncNode.Params[I]).TypeName;
        if not TypesAreCompatible(ExpectedType, ArgType) then
          Error('E0308', Format('Argumento %d da funcao "%s" espera "%s", mas recebeu "%s"',
            [I + 1, FuncNode.Name, ExpectedType, ArgType]), Arg.Line, Arg.Col);
      end;
    end;
    Exit(Sym.TypeName);
  end;

  Error('E0618', Format('"%s" nao e uma funcao nem um construtor', [Call.Callee]), Call.Line, Call.Col);
  Result := 'Unknown';
end;

function TAetherTypeChecker.CheckExpr(Expr: TASTExpr): string;
begin
  if Expr is TASTLiteralExpr then
    Result := CheckLiteral(TASTLiteralExpr(Expr))
  else if Expr is TASTIdentifierExpr then
    Result := CheckIdentifier(TASTIdentifierExpr(Expr))
  else if Expr is TASTMemberAccessExpr then
    Result := CheckMemberAccess(TASTMemberAccessExpr(Expr))
  else if Expr is TASTBinaryExpr then
    Result := CheckBinary(TASTBinaryExpr(Expr))
  else if Expr is TASTUnaryExpr then
    Result := CheckUnary(TASTUnaryExpr(Expr))
  else if Expr is TASTAwaitExpr then
    Result := CheckAwait(TASTAwaitExpr(Expr))
  else if Expr is TASTSpawnExpr then
    Result := CheckSpawn(TASTSpawnExpr(Expr))
  else if Expr is TASTCallExpr then
    Result := CheckCall(TASTCallExpr(Expr))
  else if Expr is TASTIndexExpr then
    Result := CheckIndexExpr(TASTIndexExpr(Expr))
  else if Expr is TASTSetLiteralExpr then
    Result := CheckSetLiteral(TASTSetLiteralExpr(Expr))
  else
    Result := 'Unknown';
end;

function TAetherTypeChecker.CheckIndexExpr(Idx: TASTIndexExpr): string;
var
  TargetType, IdxType, ElemType, KeyType, ValType: string;
  I, DimSize, ValInt: Integer;
  Sym: TSymbol;
  ArrDecl: TASTArrayDecl;
  P1: Integer;
begin
  TargetType := CheckExpr(Idx.Target);
  ElemType := 'Int32';

  if IsMapType(TargetType, KeyType, ValType) then
  begin
    if Idx.Indices.Count <> 1 then
      Error('E0061', Format('Acesso ao mapa espera exatamente 1 chave, encontrado %d', [Idx.Indices.Count]), Idx.Line, Idx.Col);
    IdxType := CheckExpr(TASTExpr(Idx.Indices[0]));
    if not TypesAreCompatible(KeyType, IdxType) then
      Error('E0308', Format('Chave do mapa espera tipo "%s", mas recebeu "%s"', [KeyType, IdxType]), Idx.Line, Idx.Col);
    Exit(ValType);
  end;

  ArrDecl := nil;
  Sym := FSymbols.Resolve(TargetType);
  if Assigned(Sym) and (Sym.Kind = skType) and (Sym.Node is TASTArrayDecl) then
    ArrDecl := TASTArrayDecl(Sym.Node);

  if Assigned(ArrDecl) then
    ElemType := ArrDecl.ElemType
  else if Pos('array of ', TargetType) = 1 then
    ElemType := Trim(Copy(TargetType, 10, Length(TargetType)))
  else if Pos('array[', TargetType) = 1 then
  begin
    P1 := Pos('] of ', TargetType);
    if P1 > 0 then
      ElemType := Copy(TargetType, P1 + 5, Length(TargetType))
    else
      ElemType := 'Int32';
  end;

  for I := 0 to Idx.Indices.Count - 1 do
  begin
    IdxType := CheckExpr(TASTExpr(Idx.Indices[I]));
    if not IsIntegerType(IdxType) and (IdxType <> 'IntLiteral') then
      Error('E0308', Format('Indice do array deve ser inteiro, encontrado: "%s"', [IdxType]), Idx.Line, Idx.Col);

    if Assigned(ArrDecl) and (I < ArrDecl.Dims.Count) then
    begin
      DimSize := StrToIntDef(ArrDecl.Dims[I], 0);
      if (Idx.Indices[I] is TASTLiteralExpr) and (TASTLiteralExpr(Idx.Indices[I]).Kind = lkInt) then
      begin
        ValInt := StrToIntDef(TASTLiteralExpr(Idx.Indices[I]).Value, 0);
        if (ValInt < 0) or ((DimSize > 0) and (ValInt >= DimSize)) then
          Error('E0309', Format('Indice de array fora dos limites: %d (dimensao declarada: %d)', [ValInt, DimSize]), Idx.Line, Idx.Col);
      end;
    end;
  end;

  Result := ElemType;
end;

function TAetherTypeChecker.CheckSetLiteral(SetLit: TASTSetLiteralExpr): string;
var
  I: Integer;
begin
  for I := 0 to SetLit.Elements.Count - 1 do
    CheckExpr(TASTExpr(SetLit.Elements[I]));
  Result := 'SetLiteral';
end;

procedure TAetherTypeChecker.CheckAssign(Assign: TASTAssignStmt);
var
  TargetType, ValueType: string;
  Sym: TSymbol;
begin
  TargetType := CheckExpr(Assign.Target);
  ValueType := CheckExpr(Assign.Expr);

  if not TypesAreCompatible(TargetType, ValueType) then
    Error('E0308', Format('Nao e possivel atribuir "%s" a variavel do tipo "%s"', [ValueType, TargetType]), Assign.Line, Assign.Col);

  if Assign.Target is TASTIdentifierExpr then
  begin
    Sym := FSymbols.Resolve(TASTIdentifierExpr(Assign.Target).Name);
    if Assigned(Sym) then
    begin
      if Sym.Kind = skConstant then
        Error('E0384', Format('Nao e possivel atribuir valor a constante: "%s"', [Sym.Name]), Assign.Line, Assign.Col)
      else if not Sym.IsMutable then
        Error('E0384', Format('Nao e possivel modificar variavel imutavel (declarada com "let"): "%s"', [Sym.Name]), Assign.Line, Assign.Col);
    end;
  end;
end;

procedure TAetherTypeChecker.CheckIf(IfStmt: TASTIfStmt);
var
  CondType: string;
  I: Integer;
begin
  CondType := CheckExpr(IfStmt.Condition);
  if CondType <> 'Bool' then
    Error('E0308', Format('Condicao do "if" deve ser Bool, encontrado: "%s"', [CondType]), IfStmt.Line, IfStmt.Col);

  for I := 0 to IfStmt.ThenBranch.Count - 1 do
    CheckStmt(TASTStmt(IfStmt.ThenBranch[I]));

  for I := 0 to IfStmt.ElseBranch.Count - 1 do
    CheckStmt(TASTStmt(IfStmt.ElseBranch[I]));
end;

procedure TAetherTypeChecker.CheckWhile(WhileStmt: TASTWhileStmt);
var
  CondType: string;
  I: Integer;
begin
  CondType := CheckExpr(WhileStmt.Condition);
  if CondType <> 'Bool' then
    Error('E0308', Format('Condicao do "while" deve ser Bool, encontrado: "%s"', [CondType]), WhileStmt.Line, WhileStmt.Col);

  Inc(FLoopDepth);
  try
    for I := 0 to WhileStmt.Body.Count - 1 do
      CheckStmt(TASTStmt(WhileStmt.Body[I]));
  finally
    Dec(FLoopDepth);
  end;
end;

procedure TAetherTypeChecker.CheckFor(ForStmt: TASTForStmt);
var
  VarSym, ColSym: TSymbol;
  StartType, EndType, ColType, ElemType: string;
  ArrDecl: TASTArrayDecl;
  P1, I: Integer;
begin
  if Assigned(ForStmt.CollectionExpr) then
  begin
    ColType := CheckExpr(ForStmt.CollectionExpr);
    ElemType := '';
    if IsDynamicArrayType(ColType, ElemType) then
    begin
      // ElemType preenchido
    end
    else if ColType = 'String' then
      ElemType := 'Char'
    else if Pos('array[', ColType) = 1 then
    begin
      P1 := Pos('] of ', ColType);
      if P1 > 0 then
        ElemType := Trim(Copy(ColType, P1 + 5, Length(ColType)));
    end
    else
    begin
      ColSym := FSymbols.Resolve(ColType);
      if Assigned(ColSym) and (ColSym.Kind = skType) and (ColSym.Node is TASTArrayDecl) then
      begin
        ArrDecl := TASTArrayDecl(ColSym.Node);
        ElemType := ArrDecl.ElemType;
      end;
    end;

    if ElemType = '' then
      Error('E0308', Format('Tipo "%s" nao e iteravel em laco "for..in"', [ColType]), ForStmt.Line, ForStmt.Col);

    VarSym := FSymbols.Resolve(ForStmt.VarName);
    if not Assigned(VarSym) then
      FSymbols.Define(TSymbol.Create(ForStmt.VarName, skVariable, ElemType, ForStmt.Line, ForStmt.Col, True))
    else if not TypesAreCompatible(VarSym.TypeName, ElemType) then
      Error('E0308', Format('Variavel "%s" do laco "for..in" tem tipo "%s", incompativel com "%s"',
        [ForStmt.VarName, VarSym.TypeName, ElemType]), ForStmt.Line, ForStmt.Col);
  end
  else
  begin
    VarSym := FSymbols.Resolve(ForStmt.VarName);
    if not Assigned(VarSym) then
    begin
      FSymbols.Define(TSymbol.Create(ForStmt.VarName, skVariable, 'Int32', ForStmt.Line, ForStmt.Col, True));
    end;

    StartType := CheckExpr(ForStmt.StartExpr);
    EndType := CheckExpr(ForStmt.EndExpr);

    if not IsIntegerType(StartType) and (StartType <> 'IntLiteral') then
      Error('E0308', Format('Limite inicial do laco "for" deve ser inteiro, encontrado: "%s"', [StartType]), ForStmt.Line, ForStmt.Col);

    if not IsIntegerType(EndType) and (EndType <> 'IntLiteral') then
      Error('E0308', Format('Limite final do laco "for" deve ser inteiro, encontrado: "%s"', [EndType]), ForStmt.Line, ForStmt.Col);
  end;

  Inc(FLoopDepth);
  try
    for I := 0 to ForStmt.Body.Count - 1 do
      CheckStmt(TASTStmt(ForStmt.Body[I]));
  finally
    Dec(FLoopDepth);
  end;
end;

procedure TAetherTypeChecker.CheckReturn(Ret: TASTReturnStmt);
var
  RetType: string;
begin
  if not Assigned(FCurrentFunction) then
    Error('E0572', 'Instrucao "return" fora do corpo de uma funcao', Ret.Line, Ret.Col);

  if Assigned(Ret.Expr) then
    RetType := CheckExpr(Ret.Expr)
  else
    RetType := 'Void';

  if not TypesAreCompatible(FCurrentFunction.ReturnType, RetType) then
    Error('E0308', Format('Funcao "%s" espera retorno "%s", mas instrucao retornou "%s"',
      [FCurrentFunction.Name, FCurrentFunction.ReturnType, RetType]), Ret.Line, Ret.Col);
end;

procedure TAetherTypeChecker.CheckMatch(MatchStmt: TASTMatchStmt);
var
  MatchedType: string;
  Sym: TSymbol;
  EnumDecl: TASTEnumDecl;
  I, J, PDot, PComma: Integer;
  CaseNode: TASTMatchCase;
  PatternVal, Prefix, InnerType, PatType: string;
  HasWildcard, FoundVariant: Boolean;
  CoveredVariants: TStringList;
  VariantName, MissingVariant: string;
  HasOk, HasErr, HasSome, HasNone: Boolean;
begin
  MatchedType := CheckExpr(MatchStmt.Expr);
  HasWildcard := False;

  // Verificacao Exaustiva para Enum
  Sym := FSymbols.Resolve(MatchedType);
  if Assigned(Sym) and (Sym.Node is TASTEnumDecl) then
  begin
    EnumDecl := TASTEnumDecl(Sym.Node);
    CoveredVariants := TStringList.Create;
    try
      for I := 0 to MatchStmt.Cases.Count - 1 do
      begin
        CaseNode := TASTMatchCase(MatchStmt.Cases[I]);
        PatternVal := CaseNode.Pattern.Value;

        if PatternVal = '_' then
          HasWildcard := True
        else
        begin
          PDot := Pos('.', PatternVal);
          if PDot > 0 then
          begin
            Prefix := Copy(PatternVal, 1, PDot - 1);
            if not SameText(Prefix, EnumDecl.Name) then
              Error('E0308', Format('Padrao "%s" nao pertence ao enum "%s"', [PatternVal, EnumDecl.Name]), CaseNode.Line, CaseNode.Col);
            PatternVal := Copy(PatternVal, PDot + 1, Length(PatternVal));
          end;
          FoundVariant := False;
          for J := 0 to EnumDecl.Variants.Count - 1 do
            if SameText(TASTEnumVariant(EnumDecl.Variants[J]).Name, PatternVal) then
            begin
              FoundVariant := True;
              Break;
            end;
          if not FoundVariant then
            Error('E0425', Format('Variante "%s" nao existe no enum "%s"', [PatternVal, EnumDecl.Name]), CaseNode.Line, CaseNode.Col);
          CoveredVariants.Add(UpperCase(PatternVal));
        end;

        FSymbols.EnterScope;
        try
          if (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
            FSymbols.Define(TSymbol.Create(CaseNode.Pattern.SubPattern, skVariable, 'Any', CaseNode.Line, CaseNode.Col, False));
          for J := 0 to CaseNode.Body.Count - 1 do
            CheckStmt(TASTStmt(CaseNode.Body[J]));
        finally
          FSymbols.LeaveScope;
        end;
      end;

      if not HasWildcard then
      begin
        for I := 0 to EnumDecl.Variants.Count - 1 do
        begin
          VariantName := TASTEnumVariant(EnumDecl.Variants[I]).Name;
          if CoveredVariants.IndexOf(UpperCase(VariantName)) = -1 then
          begin
            MissingVariant := VariantName;
            Error('E0004', Format('Match nao-exaustivo no enum "%s". Falta cobrir a variante "%s" (ou adicionar caso "_:")',
              [EnumDecl.Name, MissingVariant]), MatchStmt.Line, MatchStmt.Col);
          end;
        end;
      end;
    finally
      CoveredVariants.Free;
    end;
    Exit;
  end;

  // Verificacao Exaustiva para Result<T, E>
  if Pos('Result', MatchedType) = 1 then
  begin
    InnerType := 'Float64';
    PDot := Pos('<', MatchedType);
    PComma := Pos(',', MatchedType);
    if (PDot > 0) and (PComma > PDot) then
      InnerType := Trim(Copy(MatchedType, PDot + 1, PComma - PDot - 1));
    HasOk := False;
    HasErr := False;
    for I := 0 to MatchStmt.Cases.Count - 1 do
    begin
      CaseNode := TASTMatchCase(MatchStmt.Cases[I]);
      PatternVal := CaseNode.Pattern.Value;
      if (PatternVal = 'Ok') or (Pos('Ok', PatternVal) = 1) then HasOk := True;
      if (PatternVal = 'Err') or (Pos('Err', PatternVal) = 1) then HasErr := True;
      if PatternVal = '_' then HasWildcard := True;

      FSymbols.EnterScope;
      try
        if (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
        begin
          if (PatternVal = 'Ok') or (Pos('Ok', PatternVal) = 1) then
            FSymbols.Define(TSymbol.Create(CaseNode.Pattern.SubPattern, skVariable, InnerType, CaseNode.Line, CaseNode.Col, False))
          else
            FSymbols.Define(TSymbol.Create(CaseNode.Pattern.SubPattern, skVariable, 'Int32', CaseNode.Line, CaseNode.Col, False));
        end;
        for J := 0 to CaseNode.Body.Count - 1 do
          CheckStmt(TASTStmt(CaseNode.Body[J]));
      finally
        FSymbols.LeaveScope;
      end;
    end;

    if not HasWildcard and (not HasOk or not HasErr) then
      Error('E0004', 'Match nao-exaustivo em Result. E obrigatorio cobrir tanto "Ok" quanto "Err" (ou adicionar "_:")',
        MatchStmt.Line, MatchStmt.Col);
    Exit;
  end;

  // Verificacao Exaustiva para Option<T>
  if Pos('Option<', MatchedType) = 1 then
  begin
    InnerType := Trim(Copy(MatchedType, 8, Length(MatchedType) - 8));
    HasSome := False;
    HasNone := False;
    for I := 0 to MatchStmt.Cases.Count - 1 do
    begin
      CaseNode := TASTMatchCase(MatchStmt.Cases[I]);
      PatternVal := CaseNode.Pattern.Value;
      if PatternVal = 'Some' then HasSome := True
      else if PatternVal = 'None' then HasNone := True
      else if PatternVal = '_' then HasWildcard := True
      else
        Error('E0308', Format('Padrao invalido "%s" para tipo "%s"; esperado Some, None ou _', [PatternVal, MatchedType]), CaseNode.Line, CaseNode.Col);

      FSymbols.EnterScope;
      try
        if (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
          FSymbols.Define(TSymbol.Create(CaseNode.Pattern.SubPattern, skVariable, InnerType, CaseNode.Line, CaseNode.Col, False));
        for J := 0 to CaseNode.Body.Count - 1 do
          CheckStmt(TASTStmt(CaseNode.Body[J]));
      finally
        FSymbols.LeaveScope;
      end;
    end;

    if not HasWildcard and (not HasSome or not HasNone) then
      Error('E0004', Format('Match nao-exaustivo em "%s". Cubra "Some" e "None" (ou adicione "_:")', [MatchedType]),
        MatchStmt.Line, MatchStmt.Col);
    Exit;
  end;

  // Para tipos simples (Int, String, Char, Bool), valida compatibilidade de padroes literais e corpos
  for I := 0 to MatchStmt.Cases.Count - 1 do
  begin
    CaseNode := TASTMatchCase(MatchStmt.Cases[I]);
    PatternVal := CaseNode.Pattern.Value;
    if PatternVal <> '_' then
    begin
      if (Length(PatternVal) >= 2) and (PatternVal[1] = '"') then
        PatType := 'String'
      else if (Length(PatternVal) >= 2) and (PatternVal[1] = '''') then
        PatType := 'Char'
      else if (PatternVal = 'true') or (PatternVal = 'false') then
        PatType := 'Bool'
      else if (PatternVal <> '') and ((PatternVal[1] in ['0'..'9', '$', '%']) or ((PatternVal[1] = '-') and (Length(PatternVal) > 1))) then
        PatType := 'IntLiteral'
      else
        PatType := CheckIdentifier(TASTIdentifierExpr.Create(CaseNode.Line, CaseNode.Col, PatternVal));

      if not TypesAreCompatible(MatchedType, PatType) then
        Error('E0308', Format('Padrao "%s" (%s) incompativel com expressao do tipo "%s"', [PatternVal, PatType, MatchedType]), CaseNode.Line, CaseNode.Col);
    end;

    FSymbols.EnterScope;
    try
      for J := 0 to CaseNode.Body.Count - 1 do
        CheckStmt(TASTStmt(CaseNode.Body[J]));
    finally
      FSymbols.LeaveScope;
    end;
  end;
end;

procedure TAetherTypeChecker.CheckStmt(Stmt: TASTStmt);
var
  I: Integer;
begin
  if Stmt is TASTAssignStmt then
    CheckAssign(TASTAssignStmt(Stmt))
  else if Stmt is TASTCallStmt then
    CheckExpr(TASTCallStmt(Stmt).CallExpr)
  else if Stmt is TASTIfStmt then
    CheckIf(TASTIfStmt(Stmt))
  else if Stmt is TASTWhileStmt then
    CheckWhile(TASTWhileStmt(Stmt))
  else if Stmt is TASTForStmt then
    CheckFor(TASTForStmt(Stmt))
  else if Stmt is TASTRepeatStmt then
    CheckRepeat(TASTRepeatStmt(Stmt))
  else if Stmt is TASTBreakStmt then
    CheckBreak(TASTBreakStmt(Stmt))
  else if Stmt is TASTContinueStmt then
    CheckContinue(TASTContinueStmt(Stmt))
  else if Stmt is TASTReturnStmt then
    CheckReturn(TASTReturnStmt(Stmt))
  else if Stmt is TASTMatchStmt then
    CheckMatch(TASTMatchStmt(Stmt))
  else if Stmt is TASTAsmStmt then
    // Bloco assembly de baixo nivel: aceito sem verificacao semantica de tipos
  else if Stmt is TASTDeferStmt then
  begin
    if Assigned(TASTDeferStmt(Stmt).Stmt) then
      CheckStmt(TASTDeferStmt(Stmt).Stmt);
  end
  else if Stmt is TASTTryStmt then
  begin
    for I := 0 to TASTTryStmt(Stmt).TryBody.Count - 1 do
      CheckStmt(TASTStmt(TASTTryStmt(Stmt).TryBody[I]));
    for I := 0 to TASTTryStmt(Stmt).ExceptBody.Count - 1 do
      CheckStmt(TASTStmt(TASTTryStmt(Stmt).ExceptBody[I]));
  end
  else if Stmt is TASTRaiseStmt then
  begin
    if Assigned(TASTRaiseStmt(Stmt).Expr) then
    begin
      if CheckExpr(TASTRaiseStmt(Stmt).Expr) <> 'String' then
        Error('E0308', 'Instrucao "raise" espera mensagem do tipo String', Stmt.Line, Stmt.Col);
    end;
  end
  else if Stmt is TASTUnsafeStmt then
  begin
    Inc(FUnsafeDepth);
    try
      for I := 0 to TASTUnsafeStmt(Stmt).Body.Count - 1 do
        CheckStmt(TASTStmt(TASTUnsafeStmt(Stmt).Body[I]));
    finally
      Dec(FUnsafeDepth);
    end;
  end;
end;

procedure TAetherTypeChecker.CheckRepeat(RepeatStmt: TASTRepeatStmt);
var
  I: Integer;
  CondType: string;
begin
  Inc(FLoopDepth);
  try
    for I := 0 to RepeatStmt.Body.Count - 1 do
      CheckStmt(TASTStmt(RepeatStmt.Body[I]));
  finally
    Dec(FLoopDepth);
  end;
  if Assigned(RepeatStmt.Condition) then
  begin
    CondType := CheckExpr(RepeatStmt.Condition);
    if CondType <> 'Bool' then
      Error('E0308', Format('Condicao do "repeat...until" deve ser do tipo Bool, encontrado: "%s"', [CondType]), RepeatStmt.Line, RepeatStmt.Col);
  end;
end;

procedure TAetherTypeChecker.CheckBreak(BreakStmt: TASTBreakStmt);
begin
  if FLoopDepth <= 0 then
    Error('E0310', '"break" so pode ser utilizado dentro de um laco (for, while, repeat)', BreakStmt.Line, BreakStmt.Col);
end;

procedure TAetherTypeChecker.CheckContinue(ContStmt: TASTContinueStmt);
begin
  if FLoopDepth <= 0 then
    Error('E0310', '"continue" so pode ser utilizado dentro de um laco (for, while, repeat)', ContStmt.Line, ContStmt.Col);
end;

procedure TAetherTypeChecker.RegisterConstants(AModule: TASTModule);
var
  I: Integer;
  ConstDecl: TASTConstDecl;
  ValType: string;
begin
  for I := 0 to AModule.Constants.Count - 1 do
  begin
    ConstDecl := TASTConstDecl(AModule.Constants[I]);
    ValType := CheckExpr(ConstDecl.ValueExpr);
    if ConstDecl.DeclaredType <> '' then
    begin
      if not TypesAreCompatible(ConstDecl.DeclaredType, ValType) then
        Error('E0308', Format('Tipo da constante "%s" declarado como "%s", mas o valor e "%s"',
          [ConstDecl.Name, ConstDecl.DeclaredType, ValType]), ConstDecl.Line, ConstDecl.Col);
      ConstDecl.TypeName := ConstDecl.DeclaredType;
    end
    else
    begin
      if (ValType = 'IntLiteral') then ConstDecl.TypeName := 'Int32'
      else if (ValType = 'FloatLiteral') then ConstDecl.TypeName := 'Float64'
      else ConstDecl.TypeName := ValType;
    end;

    FSymbols.Define(TSymbol.Create(ConstDecl.Name, skConstant, ConstDecl.TypeName, ConstDecl.Line, ConstDecl.Col, False, owNone, ConstDecl));
  end;
end;

procedure TAetherTypeChecker.RegisterTypes(AModule: TASTModule);
var
  I, J: Integer;
  Node: TASTNode;
  Rec: TASTRecordDecl;
  Enm: TASTEnumDecl;
  Arr: TASTArrayDecl;
  SetD: TASTSetDecl;
  SubR: TASTSubrangeDecl;
  MapD: TASTMapDecl;
  VariantNode: TASTEnumVariant;
begin
  for I := 0 to AModule.Types.Count - 1 do
  begin
    Node := AModule.Types[I];
    if Node is TASTRecordDecl then
    begin
      Rec := TASTRecordDecl(Node);
      FSymbols.Define(TSymbol.Create(Rec.Name, skType, Rec.Name, Rec.Line, Rec.Col, True, owNone, Rec));
    end
    else if Node is TASTEnumDecl then
    begin
      Enm := TASTEnumDecl(Node);
      FSymbols.Define(TSymbol.Create(Enm.Name, skType, Enm.Name, Enm.Line, Enm.Col, True, owNone, Enm));
      for J := 0 to Enm.Variants.Count - 1 do
      begin
        VariantNode := TASTEnumVariant(Enm.Variants[J]);
        FSymbols.Define(TSymbol.Create(VariantNode.Name, skEnumVariant, Enm.Name, VariantNode.Line, VariantNode.Col, False, owNone, VariantNode));
      end;
    end
    else if Node is TASTArrayDecl then
    begin
      Arr := TASTArrayDecl(Node);
      FSymbols.Define(TSymbol.Create(Arr.Name, skType, Arr.Name, Arr.Line, Arr.Col, True, owNone, Arr));
    end
    else if Node is TASTSetDecl then
    begin
      SetD := TASTSetDecl(Node);
      FSymbols.Define(TSymbol.Create(SetD.Name, skType, SetD.Name, SetD.Line, SetD.Col, True, owNone, SetD));
      for J := 0 to SetD.Variants.Count - 1 do
      begin
        VariantNode := TASTEnumVariant(SetD.Variants[J]);
        FSymbols.Define(TSymbol.Create(VariantNode.Name, skEnumVariant, SetD.Name, VariantNode.Line, VariantNode.Col, False, owNone, VariantNode));
      end;
    end
    else if Node is TASTSubrangeDecl then
    begin
      SubR := TASTSubrangeDecl(Node);
      FSymbols.Define(TSymbol.Create(SubR.Name, skType, SubR.Name, SubR.Line, SubR.Col, True, owNone, SubR));
    end
    else if Node is TASTMapDecl then
    begin
      MapD := TASTMapDecl(Node);
      FSymbols.Define(TSymbol.Create(MapD.Name, skType, MapD.Name, MapD.Line, MapD.Col, True, owNone, MapD));
    end;
  end;
end;

procedure TAetherTypeChecker.RegisterFunctions(AModule: TASTModule);
var
  I: Integer;
  Func: TASTFunction;
begin
  for I := 0 to AModule.Functions.Count - 1 do
  begin
    Func := TASTFunction(AModule.Functions[I]);
    FSymbols.Define(TSymbol.Create(Func.Name, skFunction, Func.ReturnType, Func.Line, Func.Col, False, owNone, Func));
  end;
end;

procedure TAetherTypeChecker.CheckVarDecl(VarDecl: TASTVarDecl);
var
  VarInitType: string;
begin
  if VarDecl.TypeName = '' then
  begin
    if not Assigned(VarDecl.InitialExpr) then
      Error('E0282', Format('Variavel "%s" precisa de tipo explicito ou expressao inicializadora', [VarDecl.Name]), VarDecl.Line, VarDecl.Col);
    VarInitType := CheckExpr(VarDecl.InitialExpr);
    if VarInitType = 'IntLiteral' then
      VarDecl.TypeName := 'Int32'
    else if VarInitType = 'FloatLiteral' then
      VarDecl.TypeName := 'Float64'
    else if VarInitType = 'NilLiteral' then
      Error('E0282', Format('Nao e possivel inferir o tipo de "%s" apenas a partir de "nil"; declare o tipo explicitamente', [VarDecl.Name]), VarDecl.Line, VarDecl.Col)
    else
      VarDecl.TypeName := VarInitType;
  end
  else
    VarInitType := '';

  if not FSymbols.ResolveType(VarDecl.TypeName) then
    Error('E0412', Format('Tipo "%s" da variavel "%s" nao encontrado', [VarDecl.TypeName, VarDecl.Name]), VarDecl.Line, VarDecl.Col);

  if Assigned(VarDecl.InitialExpr) then
  begin
    if VarInitType = '' then
      VarInitType := CheckExpr(VarDecl.InitialExpr);
    if not TypesAreCompatible(VarDecl.TypeName, VarInitType) then
      Error('E0308', Format('Inicializacao de "%s" espera "%s", mas recebeu "%s"',
        [VarDecl.Name, VarDecl.TypeName, VarInitType]), VarDecl.Line, VarDecl.Col);
  end;

  FSymbols.Define(TSymbol.Create(VarDecl.Name, skVariable, VarDecl.TypeName, VarDecl.Line, VarDecl.Col, VarDecl.IsMutable));
end;

procedure TAetherTypeChecker.CheckFunction(Func: TASTFunction);
var
  I: Integer;
  Param: TASTParam;
begin
  FCurrentFunction := Func;
  FSymbols.EnterScope;
  try
    // Registra parametros no escopo da funcao
    for I := 0 to Func.Params.Count - 1 do
    begin
      Param := TASTParam(Func.Params[I]);
      if not FSymbols.ResolveType(Param.TypeName) then
        Error('E0412', Format('Tipo "%s" do parametro "%s" nao encontrado', [Param.TypeName, Param.Name]), Param.Line, Param.Col);
      FSymbols.Define(TSymbol.Create(Param.Name, skVariable, Param.TypeName, Param.Line, Param.Col, Param.Ownership = owMutBorrow, Param.Ownership));
    end;

    // Contratos require
    for I := 0 to Func.Requires.Count - 1 do
    begin
      if CheckExpr(TASTExpr(Func.Requires[I])) <> 'Bool' then
        Error('E0308', 'Expressao em "require" deve ser do tipo Bool', Func.Line, Func.Col);
    end;

    // Contratos ensure
    for I := 0 to Func.Ensures.Count - 1 do
    begin
      if CheckExpr(TASTExpr(Func.Ensures[I])) <> 'Bool' then
        Error('E0308', 'Expressao em "ensure" deve ser do tipo Bool', Func.Line, Func.Col);
    end;

    // Se for extern, nao possui corpo nem variaveis locais
    if Func.IsExtern then
      Exit;

    // Registra variaveis locais
    for I := 0 to Func.LocalVars.Count - 1 do
      CheckVarDecl(TASTVarDecl(Func.LocalVars[I]));

    // Verifica corpo da funcao
    for I := 0 to Func.Body.Count - 1 do
      CheckStmt(TASTStmt(Func.Body[I]));
  finally
    FSymbols.LeaveScope;
    FCurrentFunction := nil;
  end;
end;

procedure TAetherTypeChecker.CheckProgramBlock(Prog: TASTProgramBlock);
var
  I: Integer;
begin
  FSymbols.EnterScope;
  try
    for I := 0 to Prog.LocalVars.Count - 1 do
      CheckVarDecl(TASTVarDecl(Prog.LocalVars[I]));

    for I := 0 to Prog.Body.Count - 1 do
      CheckStmt(TASTStmt(Prog.Body[I]));
  finally
    FSymbols.LeaveScope;
  end;
end;

procedure TAetherTypeChecker.RegisterTraits(AModule: TASTModule);
var
  I: Integer;
  Trait: TASTTraitDecl;
begin
  for I := 0 to AModule.Traits.Count - 1 do
  begin
    Trait := TASTTraitDecl(AModule.Traits[I]);
    FSymbols.Define(TSymbol.Create(Trait.Name, skTrait, Trait.Name, Trait.Line, Trait.Col, False, owNone, Trait));
  end;
end;

procedure TAetherTypeChecker.RegisterImpls(AModule: TASTModule);
var
  I, TM, IM, P: Integer;
  Impl: TASTImplDecl;
  SymTrait, SymType: TSymbol;
  TraitDecl: TASTTraitDecl;
  TraitMethod, ImplMethod: TASTFunction;
  Found: Boolean;
  ExpectedParamType, ExpectedRetType: string;
  MangledName: string;
  Info: PTraitImplInfo;
begin
  for I := 0 to AModule.Impls.Count - 1 do
  begin
    Impl := TASTImplDecl(AModule.Impls[I]);

    SymTrait := FSymbols.Resolve(Impl.TraitName);
    if (not Assigned(SymTrait)) or (SymTrait.Kind <> skTrait) then
      Error('E0425', Format('Trait "%s" nao encontrada', [Impl.TraitName]), Impl.Line, Impl.Col);

    SymType := FSymbols.Resolve(Impl.TargetTypeName);
    if (not Assigned(SymType)) or (SymType.Kind <> skType) then
      Error('E0425', Format('Tipo "%s" nao encontrado', [Impl.TargetTypeName]), Impl.Line, Impl.Col);

    TraitDecl := TASTTraitDecl(SymTrait.Node);

    // Validação de completude: todos os métodos da trait foram implementados?
    for TM := 0 to TraitDecl.Methods.Count - 1 do
    begin
      TraitMethod := TASTFunction(TraitDecl.Methods[TM]);
      Found := False;
      for IM := 0 to Impl.Methods.Count - 1 do
      begin
        if SameText(TASTFunction(Impl.Methods[IM]).Name, TraitMethod.Name) then
        begin
          Found := True;
          Break;
        end;
      end;
      if not Found then
        Error('E0046', Format('O tipo "%s" nao implementou o metodo obrigatorio "%s" da trait "%s"',
          [Impl.TargetTypeName, TraitMethod.Name, Impl.TraitName]), Impl.Line, Impl.Col);
    end;

    // Validação das assinaturas e registro dos métodos
    for IM := 0 to Impl.Methods.Count - 1 do
    begin
      ImplMethod := TASTFunction(Impl.Methods[IM]);
      TraitMethod := nil;
      for TM := 0 to TraitDecl.Methods.Count - 1 do
      begin
        if SameText(TASTFunction(TraitDecl.Methods[TM]).Name, ImplMethod.Name) then
        begin
          TraitMethod := TASTFunction(TraitDecl.Methods[TM]);
          Break;
        end;
      end;

      if Assigned(TraitMethod) then
      begin
        // Verifica parâmetros
        if ImplMethod.Params.Count <> TraitMethod.Params.Count then
          Error('E0053', Format('A assinatura do metodo "%s" em "%s" diverge da definicao da trait "%s" (quantidade de parametros incompativel: esperado %d, recebido %d)',
            [ImplMethod.Name, Impl.TargetTypeName, Impl.TraitName, TraitMethod.Params.Count, ImplMethod.Params.Count]), ImplMethod.Line, ImplMethod.Col);

        // Verifica tipo de retorno
        ExpectedRetType := TraitMethod.ReturnType;
        if SameText(ExpectedRetType, 'Self') then
          ExpectedRetType := Impl.TargetTypeName;

        if not SameText(ImplMethod.ReturnType, ExpectedRetType) then
          Error('E0053', Format('A assinatura do metodo "%s" em "%s" diverge da definicao da trait "%s" (tipo de retorno incompativel: esperado "%s", recebido "%s")',
            [ImplMethod.Name, Impl.TargetTypeName, Impl.TraitName, ExpectedRetType, ImplMethod.ReturnType]), ImplMethod.Line, ImplMethod.Col);

        for P := 0 to TraitMethod.Params.Count - 1 do
        begin
          ExpectedParamType := TASTParam(TraitMethod.Params[P]).TypeName;
          if SameText(ExpectedParamType, 'Self') then
            ExpectedParamType := Impl.TargetTypeName;

          if not SameText(ExpectedParamType, TASTParam(ImplMethod.Params[P]).TypeName) then
            Error('E0053', Format('A assinatura do metodo "%s" em "%s" diverge da definicao da trait "%s" no parametro "%s" (esperado "%s", recebido "%s")',
              [ImplMethod.Name, Impl.TargetTypeName, Impl.TraitName, TASTParam(ImplMethod.Params[P]).Name, ExpectedParamType, TASTParam(ImplMethod.Params[P]).TypeName]), ImplMethod.Line, ImplMethod.Col);
        end;
      end;

      // Mangling canônico do método para despacho estático
      MangledName := Impl.TargetTypeName + '_' + ImplMethod.Name;
      ImplMethod.OriginalName := ImplMethod.Name;
      ImplMethod.Name := MangledName;

      // Registra a implementação da trait para lookup
      New(Info);
      Info^.TargetType := Impl.TargetTypeName;
      Info^.TraitName := Impl.TraitName;
      Info^.OriginalMethod := ImplMethod.OriginalName;
      Info^.MangledMethod := MangledName;
      FTraitImpls.Add(Info);

      // Adiciona o método em AModule.Functions para checagem e emissão (sera registrado por RegisterFunctions)
      AModule.Functions.Add(ImplMethod);
    end;

    // Desvincula os nós de Impl.Methods para não causar double-free ao destruir o módulo
    while Impl.Methods.Count > 0 do
      Impl.Methods.Extract(Impl.Methods[0]);
  end;
end;

function TAetherTypeChecker.TypeImplementsTrait(const ATypeName, ATraitName: string): Boolean;
var
  I: Integer;
  Info: PTraitImplInfo;
begin
  for I := 0 to FTraitImpls.Count - 1 do
  begin
    Info := PTraitImplInfo(FTraitImpls[I]);
    if SameText(Info^.TargetType, ATypeName) and SameText(Info^.TraitName, ATraitName) then
      Exit(True);
  end;
  Result := False;
end;

function TAetherTypeChecker.FindTraitMethod(const ATypeName, AMethodName: string): string;
var
  I: Integer;
  Info: PTraitImplInfo;
begin
  for I := 0 to FTraitImpls.Count - 1 do
  begin
    Info := PTraitImplInfo(FTraitImpls[I]);
    if SameText(Info^.TargetType, ATypeName) and SameText(Info^.OriginalMethod, AMethodName) then
      Exit(Info^.MangledMethod);
  end;
  Result := '';
end;

function TAetherTypeChecker.MonomorphizeFunction(OriginalFunc: TASTFunction; const ConcreteType: string): TASTFunction;
var
  I: Integer;
  Param: TASTParam;
  PType: string;
  VarDecl: TASTVarDecl;
  VType: string;
begin
  Result := TASTFunction.Create(OriginalFunc.Line, OriginalFunc.Col, OriginalFunc.Name + '_' + ConcreteType, OriginalFunc.ReturnType);
  if SameText(Result.ReturnType, OriginalFunc.GenericParam) then
    Result.ReturnType := ConcreteType;

  for I := 0 to OriginalFunc.Params.Count - 1 do
  begin
    Param := TASTParam(OriginalFunc.Params[I]);
    PType := Param.TypeName;
    if SameText(PType, OriginalFunc.GenericParam) then
      PType := ConcreteType;
    Result.Params.Add(TASTParam.Create(Param.Line, Param.Col, Param.Name, PType, Param.Ownership));
  end;

  for I := 0 to OriginalFunc.LocalVars.Count - 1 do
  begin
    VarDecl := TASTVarDecl(OriginalFunc.LocalVars[I]);
    VType := VarDecl.TypeName;
    if SameText(VType, OriginalFunc.GenericParam) then
      VType := ConcreteType;
    Result.LocalVars.Add(TASTVarDecl.Create(VarDecl.Line, VarDecl.Col, VarDecl.Name, VType, TASTExpr(CloneASTNode(VarDecl.InitialExpr)), VarDecl.IsMutable));
  end;

  for I := 0 to OriginalFunc.Body.Count - 1 do
    Result.Body.Add(CloneASTNode(TASTStmt(OriginalFunc.Body[I])));
end;

procedure TAetherTypeChecker.CheckModule(AModule: TASTModule);
var
  I: Integer;
  Func: TASTFunction;
begin
  FModule := AModule;
  RegisterConstants(AModule);
  RegisterTypes(AModule);
  RegisterTraits(AModule);
  RegisterImpls(AModule);
  RegisterFunctions(AModule);

  I := 0;
  while I < AModule.Functions.Count do
  begin
    Func := TASTFunction(AModule.Functions[I]);
    if Func.GenericParam = '' then
      CheckFunction(Func);
    Inc(I);
  end;

  if Assigned(AModule.ProgramBlock) then
    CheckProgramBlock(AModule.ProgramBlock);
end;

end.
