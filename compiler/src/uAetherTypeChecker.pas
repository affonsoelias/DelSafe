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
    function ResolveAliasType(const AType: string): string;
    function IsNumericType(const AType: string): Boolean;
    function IsIntegerType(const AType: string): Boolean;
    function IsSetType(const AType: string): Boolean;
    function IsDynamicArrayType(const AType: string; out ElemType: string): Boolean;
    function IsArrayType(const AType: string; out ElemType: string; out IsFixed: Boolean; out FirstDim: Integer): Boolean;
    function InferArrayLiteralElemType(SetLit: TASTSetLiteralExpr): string;
    function IsValueOptionType(const AType: string): Boolean;
    function SplitResultTypes(const AType: string; out ValType, ErrType: string): Boolean;
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
    function CheckMapLiteral(MapLit: TASTMapLiteralExpr): string;
    function CheckMatchExpr(MatchExpr: TASTMatchExpr): string;
    function CheckMatchInternal(MatchTarget: TASTExpr; Cases: TASTNodeList; IsExpr: Boolean; MLine, MCol: Integer): string;

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
    procedure CheckVisibility(AIsPublic: Boolean; const ASrcMod, ASymName: string; ALine, ACol: Integer);
    function IsModulePrefix(const APrefix: string; out AModName: string): Boolean;
    function MatchesModuleName(const AImpName, ASrcMod: string): Boolean;
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

function TAetherTypeChecker.ResolveAliasType(const AType: string): string;
var
  Cur: string;
  Sym: TSymbol;
  Hops: Integer;
begin
  Cur := Trim(AType);
  Hops := 0;
  while (Hops < 8) and Assigned(FSymbols) do
  begin
    Sym := FSymbols.ResolveTypeSymbol(Cur);
    if Assigned(Sym) and (Sym.Kind = skType) and (Sym.Node is TASTTypeAliasDecl) then
    begin
      Cur := Trim(TASTTypeAliasDecl(Sym.Node).TargetType);
      Inc(Hops);
    end
    else
      Break;
  end;
  Result := Cur;
end;

function TAetherTypeChecker.IsNumericType(const AType: string): Boolean;
var
  T: string;
begin
  T := ResolveAliasType(AType);
  Result := (T = 'Int8') or (T = 'Int16') or (T = 'Int32') or (T = 'Int64') or
            (T = 'UInt8') or (T = 'UInt16') or (T = 'UInt32') or (T = 'UInt64') or
            (T = 'Float32') or (T = 'Float64');
end;

function TAetherTypeChecker.IsIntegerType(const AType: string): Boolean;
var
  T: string;
begin
  T := ResolveAliasType(AType);
  Result := (T = 'Int8') or (T = 'Int16') or (T = 'Int32') or (T = 'Int64') or
            (T = 'UInt8') or (T = 'UInt16') or (T = 'UInt32') or (T = 'UInt64') or
            (T = 'IntLiteral');
end;

function TAetherTypeChecker.IsSetType(const AType: string): Boolean;
var
  Sym: TSymbol;
  T: string;
begin
  T := ResolveAliasType(AType);
  if (Pos('set of', T) > 0) or (T = 'SetLiteral') then
    Exit(True);
  if Assigned(FSymbols) then
  begin
    Sym := FSymbols.Resolve(T);
    if (Sym <> nil) and (Sym.Kind = skType) and (Sym.Node is TASTSetDecl) then
      Exit(True);
  end;
  Result := False;
end;

function TAetherTypeChecker.IsDynamicArrayType(const AType: string; out ElemType: string): Boolean;
var
  Sym: TSymbol;
  ArrDecl: TASTArrayDecl;
  T: string;
begin
  ElemType := '';
  T := ResolveAliasType(AType);
  if Pos('array of ', T) = 1 then
  begin
    ElemType := Trim(Copy(T, 10, Length(T)));
    Exit(True);
  end;
  if Assigned(FSymbols) then
  begin
    Sym := FSymbols.Resolve(T);
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

function TAetherTypeChecker.IsArrayType(const AType: string; out ElemType: string; out IsFixed: Boolean; out FirstDim: Integer): Boolean;
var
  T, DimsPart: string;
  P1, P2: Integer;
  Sym: TSymbol;
  ArrDecl: TASTArrayDecl;
begin
  ElemType := '';
  IsFixed := False;
  FirstDim := 0;
  T := ResolveAliasType(AType);
  if IsDynamicArrayType(T, ElemType) then
    Exit(True);
  if Pos('array[', T) = 1 then
  begin
    P1 := Pos('[', T);
    P2 := Pos('] of ', T);
    if P2 > P1 then
    begin
      DimsPart := Trim(Copy(T, P1 + 1, P2 - P1 - 1));
      ElemType := Trim(Copy(T, P2 + 5, Length(T)));
      IsFixed := True;
      FirstDim := StrToIntDef(DimsPart, 0);
      Exit(True);
    end;
  end;
  if Assigned(FSymbols) then
  begin
    Sym := FSymbols.Resolve(T);
    if Assigned(Sym) and (Sym.Kind = skType) and (Sym.Node is TASTArrayDecl) then
    begin
      ArrDecl := TASTArrayDecl(Sym.Node);
      ElemType := ArrDecl.ElemType;
      IsFixed := ArrDecl.Dims.Count > 0;
      if IsFixed then
        FirstDim := StrToIntDef(ArrDecl.Dims[0], 0);
      Exit(True);
    end;
  end;
  Result := False;
end;

function TAetherTypeChecker.InferArrayLiteralElemType(SetLit: TASTSetLiteralExpr): string;
var
  I: Integer;
  ET: string;
begin
  if (not Assigned(SetLit)) or (SetLit.Elements.Count = 0) then
    Exit('Int32');
  Result := '';
  for I := 0 to SetLit.Elements.Count - 1 do
  begin
    ET := CheckExpr(TASTExpr(SetLit.Elements[I]));
    if ET = 'IntLiteral' then ET := 'Int32'
    else if ET = 'FloatLiteral' then ET := 'Float64';
    if Result = '' then
      Result := ET
    else if not TypesAreCompatible(Result, ET) then
      Error('E0308', Format('Elemento %d do literal de array (%s) incompativel com tipo "%s"', [I + 1, ET, Result]), SetLit.Line, SetLit.Col);
  end;
  if Result = '' then Result := 'Int32';
end;

function TAetherTypeChecker.IsValueOptionType(const AType: string): Boolean;
var
  T, Inner: string;
begin
  T := ResolveAliasType(AType);
  if Pos('Option<', T) <> 1 then Exit(False);
  Inner := ResolveAliasType(Trim(Copy(T, 8, Length(T) - 8)));
  Result := (Inner <> '') and (Pos('Box<', Inner) <> 1) and (Pos('^', Inner) <> 1) and (Inner <> 'Pointer');
end;

function TAetherTypeChecker.SplitResultTypes(const AType: string; out ValType, ErrType: string): Boolean;
var
  T, Inner: string;
  I, Depth, CommaPos: Integer;
begin
  ValType := 'Float64';
  ErrType := 'Int32';
  T := ResolveAliasType(AType);
  if Pos('Result<', T) <> 1 then Exit(False);
  Inner := Copy(T, 8, Length(T) - 8);
  Depth := 0;
  CommaPos := 0;
  for I := 1 to Length(Inner) do
  begin
    if Inner[I] = '<' then Inc(Depth)
    else if Inner[I] = '>' then Dec(Depth)
    else if (Inner[I] = ',') and (Depth = 0) then
    begin
      CommaPos := I;
      Break;
    end;
  end;
  if CommaPos > 0 then
  begin
    ValType := Trim(Copy(Inner, 1, CommaPos - 1));
    ErrType := Trim(Copy(Inner, CommaPos + 1, Length(Inner)));
    Exit(True);
  end;
  Result := False;
end;

function TAetherTypeChecker.IsMapType(const AType: string; out KeyType, ValType: string): Boolean;
var
  Sym: TSymbol;
  MapDecl: TASTMapDecl;
  PClose: Integer;
  T: string;
begin
  KeyType := '';
  ValType := '';
  T := ResolveAliasType(AType);
  if Pos('map[', T) = 1 then
  begin
    PClose := Pos(']', T);
    if PClose > 4 then
    begin
      KeyType := Trim(Copy(T, 5, PClose - 5));
      ValType := Trim(Copy(T, PClose + 1, Length(T)));
      Exit(True);
    end;
  end;
  if Assigned(FSymbols) then
  begin
    Sym := FSymbols.Resolve(T);
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
  TargetElem, SourceElem, TargetKey, TargetVal, SourceKey, SourceVal, T, S: string;
  IsFix: Boolean;
  DimN: Integer;
begin
  T := ResolveAliasType(TargetType);
  S := ResolveAliasType(SourceType);
  if T = S then Exit(True);
  // Mapas associativos
  if IsMapType(T, TargetKey, TargetVal) and IsMapType(S, SourceKey, SourceVal) then
    Exit(TypesAreCompatible(TargetKey, SourceKey) and TypesAreCompatible(TargetVal, SourceVal));
  // Ponteiros e nil
  if (S = 'NilLiteral') and ((Pos('^', T) = 1) or (T = 'Pointer')) then Exit(True);
  if (T = 'NilLiteral') and ((Pos('^', S) = 1) or (S = 'Pointer')) then Exit(True);
  if ((T = 'Pointer') and (Pos('^', S) = 1)) or ((S = 'Pointer') and (Pos('^', T) = 1)) then Exit(True);
  if (Pos('^', T) = 1) and (Pos('^', S) = 1) then
    Exit(TypesAreCompatible(Copy(T, 2, Length(T)), Copy(S, 2, Length(S))));
  // Arrays dinamicos
  if IsDynamicArrayType(T, TargetElem) and IsDynamicArrayType(S, SourceElem) then
    Exit(TypesAreCompatible(TargetElem, SourceElem));
  // Literais inteiros genericos sao compativeis com qualquer tipo inteiro
  if (S = 'IntLiteral') and (Pos('Int', T) > 0) then Exit(True);
  // Compatibilidade entre tipos inteiros (Int32, UInt32, etc.)
  if IsIntegerType(T) and IsIntegerType(S) then Exit(True);
  // Literais float genericos sao compativeis com Float32 ou Float64
  if (S = 'FloatLiteral') and (Pos('Float', T) > 0) then Exit(True);
  // Genericos Result / Option / Box
  if (Pos('Result', T) = 1) and (Pos('Result', S) = 1) then Exit(True);
  if (Pos('Option', T) = 1) and ((Pos('Option', S) = 1) or (S = 'Option<GenericNone>')) then Exit(True);
  if (Pos('Box', T) = 1) and (Pos('Box', S) = 1) then Exit(True);
  if (Pos('Task', T) = 1) and (Pos('Task', S) = 1) then Exit(True);
  if (Pos('Option<Box<', T) = 1) and ((Pos('Box<', S) = 1) or (S = 'Option<GenericNone>')) then Exit(True);
  // Literais de conjunto, literais de array e literais de mapa
  if (S = 'MapLiteral') and IsMapType(T, TargetKey, TargetVal) then Exit(True);
  if (S = 'SetLiteral') and (IsSetType(T) or IsArrayType(T, TargetElem, IsFix, DimN)) then Exit(True);
  if (T = 'SetLiteral') and IsSetType(S) then Exit(True);
  if IsSetType(T) and IsSetType(S) then Exit(True);
  // Compatibilidade com subfaixas e tipos definidos pelo usuario
  if Assigned(FSymbols) then
  begin
    if Assigned(FSymbols.Resolve(T)) and (FSymbols.Resolve(T).Node is TASTSubrangeDecl) then
    begin
      if TypesAreCompatible(TASTSubrangeDecl(FSymbols.Resolve(T).Node).BaseType, S) then Exit(True);
    end;
    if Assigned(FSymbols.Resolve(S)) and (FSymbols.Resolve(S).Node is TASTSubrangeDecl) then
    begin
      if TypesAreCompatible(T, TASTSubrangeDecl(FSymbols.Resolve(S).Node).BaseType) then Exit(True);
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

  CheckVisibility(Sym.IsPublic, Sym.SourceModule, Sym.Name, Id.Line, Id.Col);
  Result := Sym.TypeName;
end;

function TAetherTypeChecker.CheckMemberAccess(Acc: TASTMemberAccessExpr): string;
var
  TargetType, ModName: string;
  Sym: TSymbol;
  I, P1, P2: Integer;
  RecDecl: TASTRecordDecl;
  EnumDecl: TASTEnumDecl;
  Field: TASTRecordField;
  InnerRecName, ResVal, ResErr: string;
begin
  // Se o alvo for um Identificador ou Modulo.Enum, pode ser um Modulo/Alias, Enum ou uma variavel
  if (Acc.Target is TASTMemberAccessExpr) and
     (TASTMemberAccessExpr(Acc.Target).Target is TASTIdentifierExpr) and
     IsModulePrefix(TASTIdentifierExpr(TASTMemberAccessExpr(Acc.Target).Target).Name, ModName) then
  begin
    Sym := FSymbols.Resolve(TASTMemberAccessExpr(Acc.Target).Member);
    if Assigned(Sym) and (Sym.Kind = skType) and (Sym.Node is TASTEnumDecl) and
       ((Sym.SourceModule = '') or MatchesModuleName(ModName, Sym.SourceModule)) then
    begin
      CheckVisibility(Sym.IsPublic, Sym.SourceModule, Sym.Name, Acc.Line, Acc.Col);
      EnumDecl := TASTEnumDecl(Sym.Node);
      for I := 0 to EnumDecl.Variants.Count - 1 do
      begin
        if SameText(TASTEnumVariant(EnumDecl.Variants[I]).Name, Acc.Member) then
          Exit(EnumDecl.Name);
      end;
      Error('E0599', Format('Variante "%s" nao pertence ao enum "%s"', [Acc.Member, EnumDecl.Name]), Acc.Line, Acc.Col);
    end;
  end;

  if Acc.Target is TASTIdentifierExpr then
  begin
    if IsModulePrefix(TASTIdentifierExpr(Acc.Target).Name, ModName) then
    begin
      Sym := FSymbols.Resolve(Acc.Member);
      if (not Assigned(Sym)) or ((Sym.SourceModule <> '') and (not MatchesModuleName(ModName, Sym.SourceModule))) then
        Error('E0425', Format('Simbolo "%s" nao encontrado no modulo "%s"', [Acc.Member, TASTIdentifierExpr(Acc.Target).Name]), Acc.Line, Acc.Col);
      CheckVisibility(Sym.IsPublic, Sym.SourceModule, Sym.Name, Acc.Line, Acc.Col);
      Exit(Sym.TypeName);
    end;

    Sym := FSymbols.Resolve(TASTIdentifierExpr(Acc.Target).Name);
    if Assigned(Sym) then
    begin
      // Caso Enum.Variante (ex: MathError.DivisaoPorZero)
      if (Sym.Kind = skType) and (Sym.Node is TASTEnumDecl) then
      begin
        CheckVisibility(Sym.IsPublic, Sym.SourceModule, Sym.Name, Acc.Line, Acc.Col);
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

  TargetType := ResolveAliasType(CheckExpr(Acc.Target));

  // Propriedades intrinsecas de Result (ex: result.is_ok, result.value, result.error)
  if Pos('Result', TargetType) = 1 then
  begin
    if SameText(Acc.Member, 'is_ok') or SameText(Acc.Member, 'is_err') then
      Exit('Bool');
    if SameText(Acc.Member, 'value') then
    begin
      SplitResultTypes(TargetType, ResVal, ResErr);
      Exit(ResVal);
    end;
    if SameText(Acc.Member, 'error') then
    begin
      SplitResultTypes(TargetType, ResVal, ResErr);
      Exit(ResErr);
    end;
  end;

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
      begin
        CheckVisibility(Field.IsPublic, Field.SourceModule, RecDecl.Name + '.' + Field.Name, Acc.Line, Acc.Col);
        Exit(Field.TypeName);
      end;
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

    if SameText(Bin.Op, 'div') or SameText(Bin.Op, 'mod') then
    begin
      if not IsIntegerType(LeftType) or not IsIntegerType(RightType) then
        Error('E0369', Format('Operador "%s" exige operandos inteiros, encontrado: "%s" e "%s"', [Bin.Op, LeftType, RightType]), Bin.Line, Bin.Col);
      if LeftType = 'IntLiteral' then Exit('Int32')
      else Exit(LeftType);
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
  OperandType, FuncRet, ValType, ErrType, FuncValType, FuncErrType: string;
begin
  if Un.Op = '?' then
  begin
    if not Assigned(FCurrentFunction) then
      Error('E0572', 'Operador de propagacao "?" / "try" so pode ser usado dentro de uma funcao', Un.Line, Un.Col);
    OperandType := ResolveAliasType(CheckExpr(Un.Expr));
    FuncRet := ResolveAliasType(FCurrentFunction.ReturnType);
    if Pos('Result', OperandType) = 1 then
    begin
      SplitResultTypes(OperandType, ValType, ErrType);
      if Pos('Result', FuncRet) <> 1 then
        Error('E0308', Format('Operador "?" em "%s" exige que a funcao "%s" retorne Result, mas retorna "%s"',
          [OperandType, FCurrentFunction.Name, FCurrentFunction.ReturnType]), Un.Line, Un.Col);
      SplitResultTypes(FuncRet, FuncValType, FuncErrType);
      if not TypesAreCompatible(FuncErrType, ErrType) then
        Error('E0308', Format('Tipo de erro "%s" em "?" incompativel com erro "%s" do retorno da funcao "%s"',
          [ErrType, FuncErrType, FCurrentFunction.Name]), Un.Line, Un.Col);
      Exit(ValType);
    end
    else if Pos('Option<', OperandType) = 1 then
    begin
      ValType := Trim(Copy(OperandType, 8, Length(OperandType) - 8));
      if Pos('Option<', FuncRet) <> 1 then
        Error('E0308', Format('Operador "?" em "%s" exige que a funcao "%s" retorne Option, mas retorna "%s"',
          [OperandType, FCurrentFunction.Name, FCurrentFunction.ReturnType]), Un.Line, Un.Col);
      Exit(ValType);
    end
    else
      Error('E0308', Format('Operador "?" / "try" exige expressao Result<T, E> ou Option<T>, recebeu "%s"', [OperandType]), Un.Line, Un.Col);
  end;

  if Un.Op = '@' then
  begin
    OperandType := CheckExpr(Un.Expr);
    Exit('^' + OperandType);
  end
  else if Un.Op = '^' then
  begin
    if FUnsafeDepth <= 0 then
      Error('E0312', 'Desreferencia de ponteiro bruto ("^") exige um bloco "unsafe ... end;"', Un.Line, Un.Col);
    OperandType := ResolveAliasType(CheckExpr(Un.Expr));
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

procedure TAetherTypeChecker.CheckVisibility(AIsPublic: Boolean; const ASrcMod, ASymName: string; ALine, ACol: Integer);
var
  CurMod: string;
begin
  if AIsPublic or (ASrcMod = '') then Exit;
  CurMod := '';
  if Assigned(FCurrentFunction) and (FCurrentFunction.SourceModule <> '') then
    CurMod := FCurrentFunction.SourceModule
  else if Assigned(FModule) then
    CurMod := FModule.Name;

  if (CurMod <> '') and (not MatchesModuleName(CurMod, ASrcMod)) then
    Error('E0603', Format('Simbolo privado "%s" do modulo "%s" nao e acessivel fora dele (marque com "pub")',
      [ASymName, ASrcMod]), ALine, ACol);
end;

function TAetherTypeChecker.MatchesModuleName(const AImpName, ASrcMod: string): Boolean;
var
  LastSeg, CleanA, CleanB: string;
begin
  if SameText(AImpName, ASrcMod) then Exit(True);
  LastSeg := AImpName;
  if Pos('.', LastSeg) > 0 then
    LastSeg := Copy(LastSeg, LastDelimiter('.', LastSeg) + 1, Length(LastSeg));
  if SameText(LastSeg, ASrcMod) then Exit(True);
  CleanA := StringReplace(LastSeg, '_', '', [rfReplaceAll]);
  CleanB := StringReplace(ASrcMod, '_', '', [rfReplaceAll]);
  Result := SameText(CleanA, CleanB);
end;

function TAetherTypeChecker.IsModulePrefix(const APrefix: string; out AModName: string): Boolean;
var
  I: Integer;
  Imp, LastSeg: string;
begin
  AModName := '';
  Result := False;
  if Assigned(FSymbols) and Assigned(FSymbols.Resolve(APrefix)) then
    Exit(False);

  if Assigned(FModule) and Assigned(FModule.ImportAliases) then
  begin
    AModName := FModule.ImportAliases.Values[APrefix];
    if AModName <> '' then
      Exit(True);
  end;

  if Assigned(FModule) and Assigned(FModule.Imports) then
  begin
    for I := 0 to FModule.Imports.Count - 1 do
    begin
      Imp := FModule.Imports[I];
      LastSeg := Imp;
      if Pos('.', LastSeg) > 0 then
        LastSeg := Copy(LastSeg, LastDelimiter('.', LastSeg) + 1, Length(LastSeg));
      if SameText(APrefix, Imp) or SameText(APrefix, LastSeg) then
      begin
        AModName := Imp;
        Exit(True);
      end;
    end;
  end;
end;

function TAetherTypeChecker.CheckCall(Call: TASTCallExpr): string;
var
  Sym, SymMono, TypeSym: TSymbol;
  FuncNode, MonoFunc: TASTFunction;
  RecDecl: TASTRecordDecl;
  SubSym: TSymbol;
  I, K: Integer;
  Arg: TASTCallArg;
  HasNamed, HasPositional, FoundField: Boolean;
  ReorderedArgs: array of TASTCallArg;
  ArgType, ExpectedType, Mangled, MonomorphedName, ElemType, KeyType, ValType: string;
  T1, T2, T3: string;
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

  if (Call.Callee = '__JsonGetStr') or (Call.Callee = '__JsonGetInt') or
     (Call.Callee = '__JsonGetFloat') or (Call.Callee = '__JsonGetBool') or
     (Call.Callee = '__JsonGetChar') or (Call.Callee = '__JsonHasValue') or
     (Call.Callee = '__JsonGetObj') then
  begin
    if Call.Args.Count <> 2 then
      Error('E0061', Format('Funcao "%s" espera 2 argumentos (json, key)', [Call.Callee]), Call.Line, Call.Col);
    CheckExpr(TASTCallArg(Call.Args[0]).Expr);
    CheckExpr(TASTCallArg(Call.Args[1]).Expr);
    if Call.Callee = '__JsonGetInt' then Exit('Int32')
    else if Call.Callee = '__JsonGetFloat' then Exit('Float64')
    else if (Call.Callee = '__JsonGetBool') or (Call.Callee = '__JsonHasValue') then Exit('Bool')
    else if Call.Callee = '__JsonGetChar' then Exit('Char')
    else Exit('String');
  end;

  // Resolucao qualificada via Alias/Modulo (ex: math.Sin(x), hmod.Tipo.New(x)) ou Metodo Associado (ex: Ponto.New(x, y))
  if Call.IsQualified and (Call.Args.Count > 0) then
  begin
    if TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr then
    begin
      T1 := TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name;
      if IsModulePrefix(T1, T2) then
      begin
        Call.Args.Delete(0);
        Sym := FSymbols.Resolve(Call.Callee);
        if (not Assigned(Sym)) or ((Sym.SourceModule <> '') and (not MatchesModuleName(T2, Sym.SourceModule))) then
          Error('E0425', Format('Funcao ou tipo "%s" nao encontrado no modulo "%s"', [Call.Callee, T1]), Call.Line, Call.Col);
        CheckVisibility(Sym.IsPublic, Sym.SourceModule, Sym.Name, Call.Line, Call.Col);
      end
      else
      begin
        TypeSym := FSymbols.Resolve(T1);
        if Assigned(TypeSym) and (TypeSym.Kind = skType) then
        begin
          CheckVisibility(TypeSym.IsPublic, TypeSym.SourceModule, TypeSym.Name, Call.Line, Call.Col);
          Mangled := FindTraitMethod(T1, Call.Callee);
          if Mangled <> '' then
          begin
            Call.Args.Delete(0);
            Call.Callee := Mangled;
          end
          else
            Error('E0425', Format('Metodo associado "%s" nao encontrado para o tipo "%s"', [Call.Callee, T1]), Call.Line, Call.Col);
        end;
      end;
    end
    else if (TASTCallArg(Call.Args[0]).Expr is TASTMemberAccessExpr) and
            (TASTMemberAccessExpr(TASTCallArg(Call.Args[0]).Expr).Target is TASTIdentifierExpr) and
            IsModulePrefix(TASTIdentifierExpr(TASTMemberAccessExpr(TASTCallArg(Call.Args[0]).Expr).Target).Name, T2) then
    begin
      T1 := TASTMemberAccessExpr(TASTCallArg(Call.Args[0]).Expr).Member;
      TypeSym := FSymbols.Resolve(T1);
      if (not Assigned(TypeSym)) or (TypeSym.Kind <> skType) or
         ((TypeSym.SourceModule <> '') and (not MatchesModuleName(T2, TypeSym.SourceModule))) then
        Error('E0425', Format('Tipo "%s" nao encontrado no modulo "%s"',
          [T1, TASTIdentifierExpr(TASTMemberAccessExpr(TASTCallArg(Call.Args[0]).Expr).Target).Name]), Call.Line, Call.Col);
      CheckVisibility(TypeSym.IsPublic, TypeSym.SourceModule, TypeSym.Name, Call.Line, Call.Col);
      Mangled := FindTraitMethod(T1, Call.Callee);
      if Mangled <> '' then
      begin
        Call.Args.Delete(0);
        Call.Callee := Mangled;
      end
      else
        Error('E0425', Format('Metodo associado "%s" nao encontrado para o tipo "%s"', [Call.Callee, T1]), Call.Line, Call.Col);
    end;
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
      if ArgType = 'IntLiteral' then ArgType := 'Int32'
      else if ArgType = 'FloatLiteral' then ArgType := 'Float64';
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

  CheckVisibility(Sym.IsPublic, Sym.SourceModule, Sym.Name, Call.Line, Call.Col);

  // Construtor de Record: DataBuffer(id: 101, size: 2048) ou posicional
  if (Sym.Kind = skType) and (Sym.Node is TASTRecordDecl) then
  begin
    RecDecl := TASTRecordDecl(Sym.Node);
    HasNamed := False;
    HasPositional := False;
    for I := 0 to Call.Args.Count - 1 do
      if TASTCallArg(Call.Args[I]).FieldName <> '' then
        HasNamed := True
      else
        HasPositional := True;

    if HasNamed and HasPositional then
      Error('E0061', Format('Construtor do record "%s" nao pode misturar argumentos posicionais e nomeados',
        [RecDecl.Name]), Call.Line, Call.Col);

    if Call.Args.Count <> RecDecl.Fields.Count then
      Error('E0061', Format('Construtor do record "%s" espera %d campos, mas recebeu %d',
        [RecDecl.Name, RecDecl.Fields.Count, Call.Args.Count]), Call.Line, Call.Col);

    if HasNamed then
    begin
      SetLength(ReorderedArgs, RecDecl.Fields.Count);
      for K := 0 to High(ReorderedArgs) do
        ReorderedArgs[K] := nil;
      for I := 0 to Call.Args.Count - 1 do
      begin
        Arg := TASTCallArg(Call.Args[I]);
        FoundField := False;
        for K := 0 to RecDecl.Fields.Count - 1 do
        begin
          if SameText(TASTRecordField(RecDecl.Fields[K]).Name, Arg.FieldName) then
          begin
            FoundField := True;
            if ReorderedArgs[K] <> nil then
              Error('E0061', Format('Campo "%s" duplicado no construtor do record "%s"',
                [Arg.FieldName, RecDecl.Name]), Arg.Line, Arg.Col);
            ReorderedArgs[K] := Arg;
            Break;
          end;
        end;
        if not FoundField then
          Error('E0609', Format('Record "%s" nao possui o campo "%s"',
            [RecDecl.Name, Arg.FieldName]), Arg.Line, Arg.Col);
      end;
      FoundField := True;
      for K := 0 to High(ReorderedArgs) do
        if ReorderedArgs[K] = nil then
          FoundField := False;
      if FoundField then
      begin
        while Call.Args.Count > 0 do
          Call.Args.ExtractIndex(0);
        for K := 0 to High(ReorderedArgs) do
        begin
          ReorderedArgs[K].FieldName := '';
          Call.Args.Add(ReorderedArgs[K]);
        end;
      end;
    end;

    for I := 0 to Call.Args.Count - 1 do
    begin
      Arg := TASTCallArg(Call.Args[I]);
      ArgType := CheckExpr(Arg.Expr);
      ExpectedType := TASTRecordField(RecDecl.Fields[I]).TypeName;
      if (Arg.Expr is TASTIdentifierExpr) and SameText(TASTIdentifierExpr(Arg.Expr).Name, 'None') and
         IsValueOptionType(ExpectedType) then
        TASTIdentifierExpr(Arg.Expr).Name := '__ValueNone';
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
      if ArgType = 'IntLiteral' then ArgType := 'Int32'
      else if ArgType = 'FloatLiteral' then ArgType := 'Float64';
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
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if (ArgType = 'String') and SameText(Call.Callee, 'Length') then
        Exit('UInt32')
      else if IsDynamicArrayType(ArgType, ElemType) or IsMapType(ArgType, KeyType, ValType) or (Pos('array[', ArgType) = 1) or
              (Assigned(FSymbols.Resolve(ArgType)) and (FSymbols.Resolve(ArgType).Node is TASTArrayDecl)) then
        Exit('Int32')
      else
        Error('E0308', Format('Funcao "%s" espera String, Array ou Mapa, recebeu: "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
    end;

    if SameText(Call.Callee, 'Default') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Funcao "Default" espera 1 argumento (NomeDoTipo)', Call.Line, Call.Col);
      if not (TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr) then
        Error('E0308', 'Argumento de "Default" deve ser o nome de um tipo valido', Call.Line, Call.Col);
      ExpectedType := TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name;
      if not FSymbols.ResolveType(ExpectedType) then
        Error('E0412', Format('Tipo desconhecido em "Default": "%s"', [ExpectedType]), Call.Line, Call.Col);
      Exit(ExpectedType);
    end;

    if SameText(Call.Callee, 'Trim') or SameText(Call.Callee, 'UpperCase') or SameText(Call.Callee, 'LowerCase') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', Format('Funcao "%s" espera 1 argumento (String)', [Call.Callee]), Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if ArgType <> 'String' then
        Error('E0308', Format('Argumento de "%s" deve ser String, recebeu: "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      Exit('String');
    end;

    if SameText(Call.Callee, 'StartsWith') or SameText(Call.Callee, 'EndsWith') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', Format('Funcao "%s" espera 2 argumentos (String, String)', [Call.Callee]), Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if ArgType <> 'String' then
        Error('E0308', Format('Primeiro argumento de "%s" deve ser String, recebeu: "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[1]).Expr));
      if ArgType <> 'String' then
        Error('E0308', Format('Segundo argumento de "%s" deve ser String, recebeu: "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      Exit('Bool');
    end;

    if SameText(Call.Callee, 'IndexOf') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Funcao "IndexOf" espera 2 argumentos (String, Substring)', Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if ArgType <> 'String' then
        Error('E0308', Format('Primeiro argumento de "IndexOf" deve ser String, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[1]).Expr));
      if ArgType <> 'String' then
        Error('E0308', Format('Segundo argumento de "IndexOf" deve ser String, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Int32');
    end;

    if SameText(Call.Callee, 'Replace') then
    begin
      if Call.Args.Count <> 3 then
        Error('E0061', 'Funcao "Replace" espera 3 argumentos (String, Antigo, Novo)', Call.Line, Call.Col);
      for K := 0 to 2 do
      begin
        ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[K]).Expr));
        if ArgType <> 'String' then
          Error('E0308', Format('Argumento %d de "Replace" deve ser String, recebeu: "%s"', [K + 1, ArgType]), Call.Line, Call.Col);
      end;
      Exit('String');
    end;

    if SameText(Call.Callee, 'Abs') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Funcao "Abs" espera 1 argumento numerico', Call.Line, Call.Col);
      T1 := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if (not IsNumericType(T1)) and (T1 <> 'IntLiteral') and (T1 <> 'FloatLiteral') then
        Error('E0308', Format('Argumento de "Abs" deve ser numerico, recebeu: "%s"', [T1]), Call.Line, Call.Col);
      if T1 = 'IntLiteral' then Exit('Int32')
      else if T1 = 'FloatLiteral' then Exit('Float64')
      else Exit(T1);
    end;

    if SameText(Call.Callee, 'Min') or SameText(Call.Callee, 'Max') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', Format('Funcao "%s" espera 2 argumentos numericos', [Call.Callee]), Call.Line, Call.Col);
      T1 := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      T2 := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[1]).Expr));
      if (not IsNumericType(T1)) and (T1 <> 'IntLiteral') and (T1 <> 'FloatLiteral') then
        Error('E0308', Format('Primeiro argumento de "%s" deve ser numerico, recebeu: "%s"', [Call.Callee, T1]), Call.Line, Call.Col);
      if (not IsNumericType(T2)) and (T2 <> 'IntLiteral') and (T2 <> 'FloatLiteral') then
        Error('E0308', Format('Segundo argumento de "%s" deve ser numerico, recebeu: "%s"', [Call.Callee, T2]), Call.Line, Call.Col);
      if (not TypesAreCompatible(T1, T2)) and (not TypesAreCompatible(T2, T1)) then
        Error('E0308', Format('Argumentos incompativeis em "%s": "%s" e "%s"', [Call.Callee, T1, T2]), Call.Line, Call.Col);
      if (T1 = 'Float64') or (T2 = 'Float64') then Exit('Float64')
      else if (T1 = 'Float32') or (T2 = 'Float32') then Exit('Float32')
      else if (T1 = 'FloatLiteral') or (T2 = 'FloatLiteral') then Exit('Float64')
      else if (T1 = 'Int64') or (T2 = 'Int64') then Exit('Int64')
      else if (T1 = 'UInt64') or (T2 = 'UInt64') then Exit('UInt64')
      else if T1 = 'IntLiteral' then
      begin
        if T2 = 'IntLiteral' then Exit('Int32')
        else Exit(T2);
      end
      else Exit(T1);
    end;

    if SameText(Call.Callee, 'Clamp') then
    begin
      if Call.Args.Count <> 3 then
        Error('E0061', 'Funcao "Clamp" espera 3 argumentos numericos (Valor, Min, Max)', Call.Line, Call.Col);
      T1 := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      T2 := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[1]).Expr));
      T3 := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[2]).Expr));
      if ((not IsNumericType(T1)) and (T1 <> 'IntLiteral') and (T1 <> 'FloatLiteral')) or
         ((not IsNumericType(T2)) and (T2 <> 'IntLiteral') and (T2 <> 'FloatLiteral')) or
         ((not IsNumericType(T3)) and (T3 <> 'IntLiteral') and (T3 <> 'FloatLiteral')) then
        Error('E0308', 'Todos os argumentos de "Clamp" devem ser numericos', Call.Line, Call.Col);
      if ((not TypesAreCompatible(T1, T2)) and (not TypesAreCompatible(T2, T1))) or
         ((not TypesAreCompatible(T1, T3)) and (not TypesAreCompatible(T3, T1))) then
        Error('E0308', Format('Tipos incompativeis em "Clamp": "%s", "%s", "%s"', [T1, T2, T3]), Call.Line, Call.Col);
      if (T1 = 'Float64') or (T2 = 'Float64') or (T3 = 'Float64') then Exit('Float64')
      else if (T1 = 'Float32') or (T2 = 'Float32') or (T3 = 'Float32') then Exit('Float32')
      else if (T1 = 'FloatLiteral') or (T2 = 'FloatLiteral') or (T3 = 'FloatLiteral') then Exit('Float64')
      else if (T1 = 'Int64') or (T2 = 'Int64') or (T3 = 'Int64') then Exit('Int64')
      else if (T1 = 'UInt64') or (T2 = 'UInt64') or (T3 = 'UInt64') then Exit('UInt64')
      else if T1 <> 'IntLiteral' then Exit(T1)
      else if T2 <> 'IntLiteral' then Exit(T2)
      else if T3 <> 'IntLiteral' then Exit(T3)
      else Exit('Int32');
    end;

    if SameText(Call.Callee, 'Delete') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Funcao "Delete" espera 2 argumentos (ArrayDinamico, Indice)', Call.Line, Call.Col);
      if TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr then
      begin
        SubSym := FSymbols.Resolve(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name);
        if Assigned(SubSym) and (not SubSym.IsMutable) then
          Error('E0384', Format('Nao e possivel remover elemento de array imutavel (declarado com "let"): "%s"', [SubSym.Name]), Call.Line, Call.Col);
      end;
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsDynamicArrayType(ArgType, ElemType) then
        Error('E0308', Format('Primeiro argumento de "Delete" deve ser Array Dinamico, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if not IsIntegerType(ArgType) then
        Error('E0308', Format('Segundo argumento de "Delete" (indice) deve ser inteiro, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Void');
    end;

    if SameText(Call.Callee, 'Insert') then
    begin
      if Call.Args.Count <> 3 then
        Error('E0061', 'Funcao "Insert" espera 3 argumentos (ArrayDinamico, Indice, Valor)', Call.Line, Call.Col);
      if TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr then
      begin
        SubSym := FSymbols.Resolve(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name);
        if Assigned(SubSym) and (not SubSym.IsMutable) then
          Error('E0384', Format('Nao e possivel inserir elemento em array imutavel (declarado com "let"): "%s"', [SubSym.Name]), Call.Line, Call.Col);
      end;
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsDynamicArrayType(ArgType, ElemType) then
        Error('E0308', Format('Primeiro argumento de "Insert" deve ser Array Dinamico, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if not IsIntegerType(ArgType) then
        Error('E0308', Format('Segundo argumento de "Insert" (indice) deve ser inteiro, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[2]).Expr);
      if not TypesAreCompatible(ElemType, ArgType) then
        Error('E0308', Format('Tipo do elemento em "Insert" incompativel: esperado "%s", recebeu "%s"', [ElemType, ArgType]), Call.Line, Call.Col);
      Exit('Void');
    end;

    if SameText(Call.Callee, 'Slice') then
    begin
      if Call.Args.Count <> 3 then
        Error('E0061', 'Funcao "Slice" espera 3 argumentos (ArrayDinamico, Inicio, Comprimento)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsDynamicArrayType(ArgType, ElemType) then
        Error('E0308', Format('Primeiro argumento de "Slice" deve ser Array Dinamico, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if not IsIntegerType(ArgType) then
        Error('E0308', Format('Segundo argumento de "Slice" (inicio) deve ser inteiro, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[2]).Expr);
      if not IsIntegerType(ArgType) then
        Error('E0308', Format('Terceiro argumento de "Slice" (comprimento) deve ser inteiro, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('array of ' + ElemType);
    end;

    if SameText(Call.Callee, 'Contains') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Funcao "Contains" espera 2 argumentos', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ResolveAliasType(ArgType) = 'String' then
      begin
        ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
        if ResolveAliasType(ArgType) <> 'String' then
          Error('E0308', Format('Segundo argumento de "Contains" em String deve ser String, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
        Exit('Bool');
      end;
      if not IsMapType(ArgType, KeyType, ValType) then
        Error('E0308', Format('Primeiro argumento de "Contains" deve ser Mapa ou String, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
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

    if SameText(Call.Callee, 'Pop') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Funcao "Pop" espera 1 argumento (ArrayDinamico)', Call.Line, Call.Col);
      if TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr then
      begin
        SubSym := FSymbols.Resolve(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name);
        if Assigned(SubSym) and (not SubSym.IsMutable) then
          Error('E0384', Format('Nao e possivel remover elemento de array imutavel (declarado com "let"): "%s"', [SubSym.Name]), Call.Line, Call.Col);
      end;
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsDynamicArrayType(ArgType, ElemType) then
        Error('E0308', Format('Argumento de "Pop" deve ser Array Dinamico, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit(ElemType);
    end;

    if SameText(Call.Callee, 'Clear') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Funcao "Clear" espera 1 argumento (ArrayDinamico ou Mapa)', Call.Line, Call.Col);
      if TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr then
      begin
        SubSym := FSymbols.Resolve(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name);
        if Assigned(SubSym) and (not SubSym.IsMutable) then
          Error('E0384', Format('Nao e possivel limpar colecao imutavel (declarada com "let"): "%s"', [SubSym.Name]), Call.Line, Call.Col);
      end;
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if (not IsDynamicArrayType(ArgType, ElemType)) and (not IsMapType(ArgType, KeyType, ValType)) then
        Error('E0308', Format('Argumento de "Clear" deve ser Array Dinamico ou Mapa, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Void');
    end;

    if SameText(Call.Callee, 'Inc') or SameText(Call.Callee, 'Dec') then
    begin
      if (Call.Args.Count < 1) or (Call.Args.Count > 2) then
        Error('E0061', Format('Funcao "%s" espera 1 ou 2 argumentos (variavel inteira[, delta])', [Call.Callee]), Call.Line, Call.Col);
      if TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr then
      begin
        SubSym := FSymbols.Resolve(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name);
        if Assigned(SubSym) and (not SubSym.IsMutable) then
          Error('E0384', Format('Nao e possivel modificar variavel imutavel com "%s": "%s"', [Call.Callee, SubSym.Name]), Call.Line, Call.Col);
      end;
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsIntegerType(ArgType) then
        Error('E0308', Format('Primeiro argumento de "%s" deve ser inteiro, recebeu: "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      if Call.Args.Count = 2 then
      begin
        ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
        if not IsIntegerType(ArgType) then
          Error('E0308', Format('Incremento/decremento de "%s" deve ser inteiro, recebeu: "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      end;
      Exit('Void');
    end;

    if SameText(Call.Callee, 'Ord') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Funcao "Ord" espera 1 argumento (Char, Bool, Inteiro ou Enum)', Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      SubSym := FSymbols.Resolve(ArgType);
      if (ArgType <> 'Char') and (ArgType <> 'Bool') and (not IsIntegerType(ArgType)) and
         not (Assigned(SubSym) and (SubSym.Node is TASTEnumDecl)) then
        Error('E0308', Format('Argumento de "Ord" invalido: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Int32');
    end;

    if SameText(Call.Callee, 'Chr') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Funcao "Chr" espera 1 argumento inteiro', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsIntegerType(ArgType) then
        Error('E0308', Format('Argumento de "Chr" deve ser inteiro, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Char');
    end;

    if SameText(Call.Callee, 'SizeOf') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Funcao "SizeOf" espera 1 argumento (Tipo ou Expressao)', Call.Line, Call.Col);
      if (TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr) and
         FSymbols.ResolveType(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name) then
        Exit('Int32');
      CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      Exit('Int32');
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
        if (Arg.Expr is TASTIdentifierExpr) and SameText(TASTIdentifierExpr(Arg.Expr).Name, 'None') and
           IsValueOptionType(ExpectedType) then
          TASTIdentifierExpr(Arg.Expr).Name := '__ValueNone';
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
var
  IfExpr: TASTIfExpr;
  CondT, T1, T2: string;
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
  else if Expr is TASTMapLiteralExpr then
    Result := CheckMapLiteral(TASTMapLiteralExpr(Expr))
  else if Expr is TASTMatchExpr then
    Result := CheckMatchExpr(TASTMatchExpr(Expr))
  else if Expr is TASTIfExpr then
  begin
    IfExpr := TASTIfExpr(Expr);
    CondT := ResolveAliasType(CheckExpr(IfExpr.Condition));
    if CondT <> 'Bool' then
      Error('E0308', Format('Condicao da expressao "if..then..else" deve ser Bool, recebeu: "%s"', [CondT]),
        IfExpr.Line, IfExpr.Col);
    T1 := ResolveAliasType(CheckExpr(IfExpr.ThenExpr));
    T2 := ResolveAliasType(CheckExpr(IfExpr.ElseExpr));
    if (IfExpr.ThenExpr is TASTIdentifierExpr) and SameText(TASTIdentifierExpr(IfExpr.ThenExpr).Name, 'None') and
       IsValueOptionType(T2) then
      TASTIdentifierExpr(IfExpr.ThenExpr).Name := '__ValueNone';
    if (IfExpr.ElseExpr is TASTIdentifierExpr) and SameText(TASTIdentifierExpr(IfExpr.ElseExpr).Name, 'None') and
       IsValueOptionType(T1) then
      TASTIdentifierExpr(IfExpr.ElseExpr).Name := '__ValueNone';
    if (not TypesAreCompatible(T1, T2)) and (not TypesAreCompatible(T2, T1)) then
      Error('E0308', Format('Ramos de "if..then..else" possuem tipos incompativeis: "%s" e "%s"', [T1, T2]),
        IfExpr.Line, IfExpr.Col);
    if T1 = 'NilLiteral' then Exit(T2);
    if T2 = 'NilLiteral' then Exit(T1);
    if T1 = 'Option<GenericNone>' then Exit(T2);
    if T2 = 'Option<GenericNone>' then Exit(T1);
    if (T1 = 'Float64') or (T2 = 'Float64') then Exit('Float64')
    else if (T1 = 'Float32') or (T2 = 'Float32') then Exit('Float32')
    else if (T1 = 'FloatLiteral') and (T2 = 'FloatLiteral') then Exit('FloatLiteral')
    else if T1 = 'FloatLiteral' then Exit(T2)
    else if T2 = 'FloatLiteral' then Exit(T1)
    else if (T1 = 'Int64') or (T2 = 'Int64') then Exit('Int64')
    else if (T1 = 'UInt64') or (T2 = 'UInt64') then Exit('UInt64')
    else if (T1 = 'IntLiteral') and (T2 = 'IntLiteral') then Exit('IntLiteral')
    else if T1 = 'IntLiteral' then Exit(T2)
    else if T2 = 'IntLiteral' then Exit(T1)
    else Exit(T1);
  end
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
  TargetType := ResolveAliasType(CheckExpr(Idx.Target));
  ElemType := 'Int32';

  if TargetType = 'String' then
  begin
    if Idx.Indices.Count <> 1 then
      Error('E0061', Format('Indexacao de String espera exatamente 1 indice, encontrado %d', [Idx.Indices.Count]), Idx.Line, Idx.Col);
    IdxType := CheckExpr(TASTExpr(Idx.Indices[0]));
    if not IsIntegerType(IdxType) then
      Error('E0308', Format('Indice de String deve ser inteiro, encontrado: "%s"', [IdxType]), Idx.Line, Idx.Col);
    Exit('Char');
  end;

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
  if (TargetType = 'SetLiteral') and (Idx.Target is TASTSetLiteralExpr) then
    ElemType := InferArrayLiteralElemType(TASTSetLiteralExpr(Idx.Target))
  else
  begin
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

function TAetherTypeChecker.CheckMapLiteral(MapLit: TASTMapLiteralExpr): string;
var
  I: Integer;
  KeyT, ValT, NextK, NextV: string;
begin
  if MapLit.Keys.Count = 0 then
    Exit('MapLiteral');

  KeyT := ResolveAliasType(CheckExpr(TASTExpr(MapLit.Keys[0])));
  if KeyT = 'IntLiteral' then KeyT := 'Int32'
  else if KeyT = 'FloatLiteral' then KeyT := 'Float64';

  ValT := ResolveAliasType(CheckExpr(TASTExpr(MapLit.Values[0])));
  if ValT = 'IntLiteral' then ValT := 'Int32'
  else if ValT = 'FloatLiteral' then ValT := 'Float64';

  for I := 1 to MapLit.Keys.Count - 1 do
  begin
    NextK := ResolveAliasType(CheckExpr(TASTExpr(MapLit.Keys[I])));
    NextV := ResolveAliasType(CheckExpr(TASTExpr(MapLit.Values[I])));
    if not TypesAreCompatible(KeyT, NextK) then
      Error('E0308', Format('Chave %d do literal de mapa (%s) incompativel com tipo "%s"', [I + 1, NextK, KeyT]), MapLit.Line, MapLit.Col);
    if not TypesAreCompatible(ValT, NextV) then
      Error('E0308', Format('Valor %d do literal de mapa (%s) incompativel com tipo "%s"', [I + 1, NextV, ValT]), MapLit.Line, MapLit.Col);
  end;

  Result := Format('map[%s]%s', [KeyT, ValT]);
end;

procedure TAetherTypeChecker.CheckAssign(Assign: TASTAssignStmt);
var
  TargetType, ValueType, ElemType: string;
  Sym: TSymbol;
  IsFixed: Boolean;
  DimN, I: Integer;
begin
  TargetType := CheckExpr(Assign.Target);
  ValueType := CheckExpr(Assign.Expr);

  if (Assign.Expr is TASTIdentifierExpr) and SameText(TASTIdentifierExpr(Assign.Expr).Name, 'None') and
     IsValueOptionType(TargetType) then
    TASTIdentifierExpr(Assign.Expr).Name := '__ValueNone';

  if (Assign.Expr is TASTSetLiteralExpr) and (not IsSetType(TargetType)) and IsArrayType(TargetType, ElemType, IsFixed, DimN) then
  begin
    for I := 0 to TASTSetLiteralExpr(Assign.Expr).Elements.Count - 1 do
      if not TypesAreCompatible(ElemType, CheckExpr(TASTExpr(TASTSetLiteralExpr(Assign.Expr).Elements[I]))) then
        Error('E0308', Format('Elemento %d do literal de array incompativel com "%s"', [I + 1, ElemType]), Assign.Line, Assign.Col);
  end
  else if not TypesAreCompatible(TargetType, ValueType) then
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

  FSymbols.EnterScope;
  try
    for I := 0 to IfStmt.ThenBranch.Count - 1 do
      CheckStmt(TASTStmt(IfStmt.ThenBranch[I]));
  finally
    FSymbols.LeaveScope;
  end;

  FSymbols.EnterScope;
  try
    for I := 0 to IfStmt.ElseBranch.Count - 1 do
      CheckStmt(TASTStmt(IfStmt.ElseBranch[I]));
  finally
    FSymbols.LeaveScope;
  end;
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
  FSymbols.EnterScope;
  try
    for I := 0 to WhileStmt.Body.Count - 1 do
      CheckStmt(TASTStmt(WhileStmt.Body[I]));
  finally
    FSymbols.LeaveScope;
    Dec(FLoopDepth);
  end;
end;

procedure TAetherTypeChecker.CheckFor(ForStmt: TASTForStmt);
var
  VarSym, ValSym, ColSym: TSymbol;
  StartType, EndType, ColType, ElemType, KeyType, ValType: string;
  ArrDecl: TASTArrayDecl;
  P1, I: Integer;
begin
  if Assigned(ForStmt.CollectionExpr) then
  begin
    ColType := ResolveAliasType(CheckExpr(ForStmt.CollectionExpr));
    if IsMapType(ColType, KeyType, ValType) then
    begin
      VarSym := FSymbols.Resolve(ForStmt.VarName);
      if not Assigned(VarSym) then
        FSymbols.Define(TSymbol.Create(ForStmt.VarName, skVariable, KeyType, ForStmt.Line, ForStmt.Col, True))
      else if not TypesAreCompatible(VarSym.TypeName, KeyType) then
        Error('E0308', Format('Variavel de chave "%s" do laco "for..in" tem tipo "%s", incompativel com "%s"',
          [ForStmt.VarName, VarSym.TypeName, KeyType]), ForStmt.Line, ForStmt.Col);

      if ForStmt.ValVarName <> '' then
      begin
        ValSym := FSymbols.Resolve(ForStmt.ValVarName);
        if not Assigned(ValSym) then
          FSymbols.Define(TSymbol.Create(ForStmt.ValVarName, skVariable, ValType, ForStmt.Line, ForStmt.Col, True))
        else if not TypesAreCompatible(ValSym.TypeName, ValType) then
          Error('E0308', Format('Variavel de valor "%s" do laco "for..in" tem tipo "%s", incompativel com "%s"',
            [ForStmt.ValVarName, ValSym.TypeName, ValType]), ForStmt.Line, ForStmt.Col);
      end;
    end
    else
    begin
      if ForStmt.ValVarName <> '' then
        Error('E0308', Format('Iteracao chave, valor ("for k, v in ...") suportada apenas em mapas, recebeu: "%s"', [ColType]), ForStmt.Line, ForStmt.Col);

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
    end;
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
  begin
    RetType := CheckExpr(Ret.Expr);
    if (Ret.Expr is TASTIdentifierExpr) and SameText(TASTIdentifierExpr(Ret.Expr).Name, 'None') and
       IsValueOptionType(FCurrentFunction.ReturnType) then
      TASTIdentifierExpr(Ret.Expr).Name := '__ValueNone';
  end
  else
    RetType := 'Void';

  if not TypesAreCompatible(FCurrentFunction.ReturnType, RetType) then
    Error('E0308', Format('Funcao "%s" espera retorno "%s", mas instrucao retornou "%s"',
      [FCurrentFunction.Name, FCurrentFunction.ReturnType, RetType]), Ret.Line, Ret.Col);
end;

function TAetherTypeChecker.CheckMatchInternal(MatchTarget: TASTExpr; Cases: TASTNodeList; IsExpr: Boolean; MLine, MCol: Integer): string;
var
  MatchedType: string;
  Sym: TSymbol;
  EnumDecl: TASTEnumDecl;
  I, J, K, PDot, P2: Integer;
  CaseNode: TASTMatchCase;
  PatternVal, Prefix, InnerType, ErrType, PatType, PatItem, LoStr, HiStr, LoT, HiT: string;
  HasWildcard, FoundVariant: Boolean;
  CoveredVariants: TStringList;
  VariantName, MissingVariant: string;
  HasOk, HasErr, HasSome, HasNone: Boolean;

  function ClassifyMatchAtomType(const S: string; ALine, ACol: Integer): string;
  var
    TempId: TASTIdentifierExpr;
  begin
    if (Length(S) >= 2) and (S[1] = '"') then
      Result := 'String'
    else if (Length(S) >= 2) and (S[1] = '''') then
      Result := 'Char'
    else if (S = 'true') or (S = 'false') then
      Result := 'Bool'
    else if (S <> '') and ((S[1] in ['0'..'9', '$', '%']) or ((S[1] = '-') and (Length(S) > 1))) then
      Result := 'IntLiteral'
    else
    begin
      TempId := TASTIdentifierExpr.Create(ALine, ACol, S);
      try
        Result := CheckIdentifier(TempId);
      finally
        TempId.Free;
      end;
    end;
  end;

  procedure CheckCaseArm(ACase: TASTMatchCase);
  var
    ArmT: string;
    SIdx: Integer;
  begin
    if Assigned(ACase.Guard) then
    begin
      if ResolveAliasType(CheckExpr(ACase.Guard)) <> 'Bool' then
        Error('E0308', 'Guarda condicional do case no match deve ser do tipo Bool', ACase.Line, ACase.Col);
    end;

    if IsExpr then
    begin
      if not Assigned(ACase.ValueExpr) then
        Error('E0308', 'Ramo da expressao "match" deve retornar uma expressao', ACase.Line, ACase.Col);
      ArmT := ResolveAliasType(CheckExpr(ACase.ValueExpr));
      if ArmT = 'IntLiteral' then ArmT := 'Int32'
      else if ArmT = 'FloatLiteral' then ArmT := 'Float64';
      if Result = '' then
        Result := ArmT
      else if TypesAreCompatible(Result, ArmT) then
      begin
        // Result mantido
      end
      else if TypesAreCompatible(ArmT, Result) then
        Result := ArmT
      else
        Error('E0308', Format('Ramos da expressao "match" possuem tipos incompativeis: "%s" e "%s"', [Result, ArmT]), ACase.Line, ACase.Col);
    end
    else
    begin
      for SIdx := 0 to ACase.Body.Count - 1 do
        CheckStmt(TASTStmt(ACase.Body[SIdx]));
    end;
  end;

begin
  Result := '';
  MatchedType := ResolveAliasType(CheckExpr(MatchTarget));
  if MatchedType = 'IntLiteral' then MatchedType := 'Int32'
  else if MatchedType = 'FloatLiteral' then MatchedType := 'Float64';
  HasWildcard := False;

  if IsExpr and (Cases.Count = 0) then
    Error('E0004', 'Expressao "match" deve possuir ao menos um ramo', MLine, MCol);

  // Verificacao Exaustiva para Enum
  Sym := FSymbols.Resolve(MatchedType);
  if Assigned(Sym) and (Sym.Node is TASTEnumDecl) then
  begin
    EnumDecl := TASTEnumDecl(Sym.Node);
    CoveredVariants := TStringList.Create;
    try
      for I := 0 to Cases.Count - 1 do
      begin
        CaseNode := TASTMatchCase(Cases[I]);
        if CaseNode.Pattern.Value = '_' then
        begin
          if not Assigned(CaseNode.Guard) then
            HasWildcard := True;
        end
        else
        begin
          for K := 0 to CaseNode.Pattern.Items.Count - 1 do
          begin
            PatternVal := Trim(CaseNode.Pattern.Items[K]);
            if PatternVal = '_' then
            begin
              if not Assigned(CaseNode.Guard) then
                HasWildcard := True;
              Continue;
            end;
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
            if not Assigned(CaseNode.Guard) then
              CoveredVariants.Add(UpperCase(PatternVal));
          end;
        end;

        FSymbols.EnterScope;
        try
          if (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
          begin
            if CaseNode.Pattern.Value = '_' then
              FSymbols.Define(TSymbol.Create(CaseNode.Pattern.SubPattern, skVariable, EnumDecl.Name, CaseNode.Line, CaseNode.Col, False))
            else
              FSymbols.Define(TSymbol.Create(CaseNode.Pattern.SubPattern, skVariable, 'Any', CaseNode.Line, CaseNode.Col, False));
          end;
          CheckCaseArm(CaseNode);
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
              [EnumDecl.Name, MissingVariant]), MLine, MCol);
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
    SplitResultTypes(MatchedType, InnerType, ErrType);
    HasOk := False;
    HasErr := False;
    for I := 0 to Cases.Count - 1 do
    begin
      CaseNode := TASTMatchCase(Cases[I]);
      PatternVal := CaseNode.Pattern.Value;
      if not Assigned(CaseNode.Guard) then
      begin
        if (PatternVal = 'Ok') or (Pos('Ok', PatternVal) = 1) then HasOk := True;
        if (PatternVal = 'Err') or (Pos('Err', PatternVal) = 1) then HasErr := True;
        if PatternVal = '_' then HasWildcard := True;
      end;

      FSymbols.EnterScope;
      try
        if (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
        begin
          if (PatternVal = 'Ok') or (Pos('Ok', PatternVal) = 1) then
            FSymbols.Define(TSymbol.Create(CaseNode.Pattern.SubPattern, skVariable, InnerType, CaseNode.Line, CaseNode.Col, False))
          else if (PatternVal = 'Err') or (Pos('Err', PatternVal) = 1) then
            FSymbols.Define(TSymbol.Create(CaseNode.Pattern.SubPattern, skVariable, ErrType, CaseNode.Line, CaseNode.Col, False))
          else
            FSymbols.Define(TSymbol.Create(CaseNode.Pattern.SubPattern, skVariable, MatchedType, CaseNode.Line, CaseNode.Col, False));
        end;
        CheckCaseArm(CaseNode);
      finally
        FSymbols.LeaveScope;
      end;
    end;

    if not HasWildcard and (not HasOk or not HasErr) then
      Error('E0004', 'Match nao-exaustivo em Result. E obrigatorio cobrir tanto "Ok" quanto "Err" (ou adicionar "_:")',
        MLine, MCol);
    Exit;
  end;

  // Verificacao Exaustiva para Option<T>
  if Pos('Option<', MatchedType) = 1 then
  begin
    InnerType := Trim(Copy(MatchedType, 8, Length(MatchedType) - 8));
    HasSome := False;
    HasNone := False;
    for I := 0 to Cases.Count - 1 do
    begin
      CaseNode := TASTMatchCase(Cases[I]);
      PatternVal := CaseNode.Pattern.Value;
      if PatternVal = 'Some' then
      begin
        if not Assigned(CaseNode.Guard) then HasSome := True;
      end
      else if PatternVal = 'None' then
      begin
        if not Assigned(CaseNode.Guard) then HasNone := True;
      end
      else if PatternVal = '_' then
      begin
        if not Assigned(CaseNode.Guard) then HasWildcard := True;
      end
      else
        Error('E0308', Format('Padrao invalido "%s" para tipo "%s"; esperado Some, None ou _', [PatternVal, MatchedType]), CaseNode.Line, CaseNode.Col);

      FSymbols.EnterScope;
      try
        if (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
        begin
          if PatternVal = 'Some' then
            FSymbols.Define(TSymbol.Create(CaseNode.Pattern.SubPattern, skVariable, InnerType, CaseNode.Line, CaseNode.Col, False))
          else
            FSymbols.Define(TSymbol.Create(CaseNode.Pattern.SubPattern, skVariable, MatchedType, CaseNode.Line, CaseNode.Col, False));
        end;
        CheckCaseArm(CaseNode);
      finally
        FSymbols.LeaveScope;
      end;
    end;

    if not HasWildcard and (not HasSome or not HasNone) then
      Error('E0004', Format('Match nao-exaustivo em "%s". Cubra "Some" e "None" (ou adicione "_:")', [MatchedType]),
        MLine, MCol);
    Exit;
  end;

  // Para tipos simples (Int, String, Char, Bool), valida multiplos padroes, faixas, guardas e corpos
  for I := 0 to Cases.Count - 1 do
  begin
    CaseNode := TASTMatchCase(Cases[I]);
    if CaseNode.Pattern.Value <> '_' then
    begin
      for K := 0 to CaseNode.Pattern.Items.Count - 1 do
      begin
        PatItem := Trim(CaseNode.Pattern.Items[K]);
        if PatItem = '_' then Continue;
        if (Pos('..', PatItem) > 0) and (PatItem[1] <> '"') then
        begin
          P2 := Pos('..', PatItem);
          LoStr := Trim(Copy(PatItem, 1, P2 - 1));
          HiStr := Trim(Copy(PatItem, P2 + 2, Length(PatItem)));
          if (MatchedType <> 'Char') and (not IsIntegerType(MatchedType)) then
            Error('E0308', Format('Padrao de faixa "%s" exige expressao inteira ou Char, recebeu "%s"', [PatItem, MatchedType]), CaseNode.Line, CaseNode.Col);
          LoT := ClassifyMatchAtomType(LoStr, CaseNode.Line, CaseNode.Col);
          HiT := ClassifyMatchAtomType(HiStr, CaseNode.Line, CaseNode.Col);
          if (not TypesAreCompatible(MatchedType, LoT)) or (not TypesAreCompatible(MatchedType, HiT)) then
            Error('E0308', Format('Limites da faixa "%s" (%s..%s) incompativeis com tipo "%s"', [PatItem, LoT, HiT, MatchedType]), CaseNode.Line, CaseNode.Col);
        end
        else
        begin
          PatType := ClassifyMatchAtomType(PatItem, CaseNode.Line, CaseNode.Col);
          if not TypesAreCompatible(MatchedType, PatType) then
            Error('E0308', Format('Padrao "%s" (%s) incompativel com expressao do tipo "%s"', [PatItem, PatType, MatchedType]), CaseNode.Line, CaseNode.Col);
        end;
      end;
    end;

    FSymbols.EnterScope;
    try
      if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
        FSymbols.Define(TSymbol.Create(CaseNode.Pattern.SubPattern, skVariable, MatchedType, CaseNode.Line, CaseNode.Col, False));
      CheckCaseArm(CaseNode);
    finally
      FSymbols.LeaveScope;
    end;
  end;
end;

function TAetherTypeChecker.CheckMatchExpr(MatchExpr: TASTMatchExpr): string;
begin
  Result := CheckMatchInternal(MatchExpr.Expr, MatchExpr.Cases, True, MatchExpr.Line, MatchExpr.Col);
end;

procedure TAetherTypeChecker.CheckMatch(MatchStmt: TASTMatchStmt);
begin
  CheckMatchInternal(MatchStmt.Expr, MatchStmt.Cases, False, MatchStmt.Line, MatchStmt.Col);
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
  else if Stmt is TASTVarDeclStmt then
  begin
    for I := 0 to TASTVarDeclStmt(Stmt).Decls.Count - 1 do
      CheckVarDecl(TASTVarDecl(TASTVarDeclStmt(Stmt).Decls[I]));
  end
  else if Stmt is TASTUnsafeStmt then
  begin
    Inc(FUnsafeDepth);
    FSymbols.EnterScope;
    try
      for I := 0 to TASTUnsafeStmt(Stmt).Body.Count - 1 do
        CheckStmt(TASTStmt(TASTUnsafeStmt(Stmt).Body[I]));
    finally
      FSymbols.LeaveScope;
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
  Sym: TSymbol;
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

    Sym := TSymbol.Create(ConstDecl.Name, skConstant, ConstDecl.TypeName, ConstDecl.Line, ConstDecl.Col, False, owNone, ConstDecl);
    Sym.IsPublic := ConstDecl.IsPublic;
    Sym.SourceModule := ConstDecl.SourceModule;
    FSymbols.Define(Sym);
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
  Sym: TSymbol;
begin
  for I := 0 to AModule.Types.Count - 1 do
  begin
    Node := AModule.Types[I];
    if Node is TASTRecordDecl then
    begin
      Rec := TASTRecordDecl(Node);
      Sym := TSymbol.Create(Rec.Name, skType, Rec.Name, Rec.Line, Rec.Col, True, owNone, Rec);
      Sym.IsPublic := Rec.IsPublic;
      Sym.SourceModule := Rec.SourceModule;
      FSymbols.Define(Sym);
    end
    else if Node is TASTEnumDecl then
    begin
      Enm := TASTEnumDecl(Node);
      Sym := TSymbol.Create(Enm.Name, skType, Enm.Name, Enm.Line, Enm.Col, True, owNone, Enm);
      Sym.IsPublic := Enm.IsPublic;
      Sym.SourceModule := Enm.SourceModule;
      FSymbols.Define(Sym);
      for J := 0 to Enm.Variants.Count - 1 do
      begin
        VariantNode := TASTEnumVariant(Enm.Variants[J]);
        FSymbols.Define(TSymbol.Create(VariantNode.Name, skEnumVariant, Enm.Name, VariantNode.Line, VariantNode.Col, False, owNone, VariantNode));
      end;
    end
    else if Node is TASTArrayDecl then
    begin
      Arr := TASTArrayDecl(Node);
      Sym := TSymbol.Create(Arr.Name, skType, Arr.Name, Arr.Line, Arr.Col, True, owNone, Arr);
      Sym.IsPublic := Arr.IsPublic;
      Sym.SourceModule := Arr.SourceModule;
      FSymbols.Define(Sym);
    end
    else if Node is TASTSetDecl then
    begin
      SetD := TASTSetDecl(Node);
      Sym := TSymbol.Create(SetD.Name, skType, SetD.Name, SetD.Line, SetD.Col, True, owNone, SetD);
      Sym.IsPublic := SetD.IsPublic;
      Sym.SourceModule := SetD.SourceModule;
      FSymbols.Define(Sym);
      for J := 0 to SetD.Variants.Count - 1 do
      begin
        VariantNode := TASTEnumVariant(SetD.Variants[J]);
        FSymbols.Define(TSymbol.Create(VariantNode.Name, skEnumVariant, SetD.Name, VariantNode.Line, VariantNode.Col, False, owNone, VariantNode));
      end;
    end
    else if Node is TASTSubrangeDecl then
    begin
      SubR := TASTSubrangeDecl(Node);
      Sym := TSymbol.Create(SubR.Name, skType, SubR.Name, SubR.Line, SubR.Col, True, owNone, SubR);
      Sym.IsPublic := SubR.IsPublic;
      Sym.SourceModule := SubR.SourceModule;
      FSymbols.Define(Sym);
    end
    else if Node is TASTMapDecl then
    begin
      MapD := TASTMapDecl(Node);
      Sym := TSymbol.Create(MapD.Name, skType, MapD.Name, MapD.Line, MapD.Col, True, owNone, MapD);
      Sym.IsPublic := MapD.IsPublic;
      Sym.SourceModule := MapD.SourceModule;
      FSymbols.Define(Sym);
    end
    else if Node is TASTTypeAliasDecl then
    begin
      Sym := TSymbol.Create(TASTTypeAliasDecl(Node).Name, skType, TASTTypeAliasDecl(Node).Name, Node.Line, Node.Col, True, owNone, Node);
      Sym.IsPublic := Node.IsPublic;
      Sym.SourceModule := Node.SourceModule;
      FSymbols.Define(Sym);
    end;
  end;
end;

procedure TAetherTypeChecker.RegisterFunctions(AModule: TASTModule);
var
  I: Integer;
  Func: TASTFunction;
  Sym: TSymbol;
begin
  for I := 0 to AModule.Functions.Count - 1 do
  begin
    Func := TASTFunction(AModule.Functions[I]);
    Sym := TSymbol.Create(Func.Name, skFunction, Func.ReturnType, Func.Line, Func.Col, False, owNone, Func);
    Sym.IsPublic := Func.IsPublic;
    Sym.SourceModule := Func.SourceModule;
    FSymbols.Define(Sym);
  end;
end;

procedure TAetherTypeChecker.CheckVarDecl(VarDecl: TASTVarDecl);
var
  VarInitType, ElemType: string;
  IsFixed: Boolean;
  DimN, I: Integer;
begin
  if VarDecl.TypeName = '' then
  begin
    if not Assigned(VarDecl.InitialExpr) then
      Error('E0282', Format('Variavel "%s" precisa de tipo explicito ou expressao inicializadora', [VarDecl.Name]), VarDecl.Line, VarDecl.Col);
    VarInitType := CheckExpr(VarDecl.InitialExpr);
    if VarDecl.InitialExpr is TASTSetLiteralExpr then
      VarDecl.TypeName := 'array of ' + InferArrayLiteralElemType(TASTSetLiteralExpr(VarDecl.InitialExpr))
    else if VarDecl.InitialExpr is TASTMapLiteralExpr then
    begin
      if VarInitType = 'MapLiteral' then
        Error('E0282', Format('Nao e possivel inferir tipos de mapa vazio "[:]" para "%s"; declare "map[K]V"', [VarDecl.Name]), VarDecl.Line, VarDecl.Col);
      VarDecl.TypeName := VarInitType;
    end
    else if VarInitType = 'IntLiteral' then
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
    if (VarDecl.InitialExpr is TASTIdentifierExpr) and SameText(TASTIdentifierExpr(VarDecl.InitialExpr).Name, 'None') and
       IsValueOptionType(VarDecl.TypeName) then
      TASTIdentifierExpr(VarDecl.InitialExpr).Name := '__ValueNone';
    if (VarDecl.InitialExpr is TASTSetLiteralExpr) and (not IsSetType(VarDecl.TypeName)) and
       IsArrayType(VarDecl.TypeName, ElemType, IsFixed, DimN) then
    begin
      for I := 0 to TASTSetLiteralExpr(VarDecl.InitialExpr).Elements.Count - 1 do
        if not TypesAreCompatible(ElemType, CheckExpr(TASTExpr(TASTSetLiteralExpr(VarDecl.InitialExpr).Elements[I]))) then
          Error('E0308', Format('Elemento %d do literal de array incompativel com "%s"', [I + 1, ElemType]), VarDecl.Line, VarDecl.Col);
    end
    else if not TypesAreCompatible(VarDecl.TypeName, VarInitType) then
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

    // Contratos ensure (com acesso a variavel especial "result" quando nao for Void)
    if Func.Ensures.Count > 0 then
    begin
      FSymbols.EnterScope;
      try
        if (Func.ReturnType <> '') and (not SameText(Func.ReturnType, 'Void')) then
          FSymbols.Define(TSymbol.Create('result', skVariable, Func.ReturnType, Func.Line, Func.Col, False));
        for I := 0 to Func.Ensures.Count - 1 do
        begin
          if CheckExpr(TASTExpr(Func.Ensures[I])) <> 'Bool' then
            Error('E0308', 'Expressao em "ensure" deve ser do tipo Bool', Func.Line, Func.Col);
        end;
      finally
        FSymbols.LeaveScope;
      end;
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
  Sym, ExistingSym: TSymbol;
begin
  for I := 0 to AModule.Traits.Count - 1 do
  begin
    Trait := TASTTraitDecl(AModule.Traits[I]);
    ExistingSym := FSymbols.Resolve(Trait.Name);
    if Assigned(ExistingSym) and (ExistingSym.Kind = skTrait) then
      Continue;
    Sym := TSymbol.Create(Trait.Name, skTrait, Trait.Name, Trait.Line, Trait.Col, False, owNone, Trait);
    Sym.IsPublic := Trait.IsPublic;
    Sym.SourceModule := Trait.SourceModule;
    FSymbols.Define(Sym);
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

    SymType := FSymbols.Resolve(Impl.TargetTypeName);
    if (not Assigned(SymType)) or (SymType.Kind <> skType) then
      Error('E0425', Format('Tipo "%s" nao encontrado', [Impl.TargetTypeName]), Impl.Line, Impl.Col);

    TraitDecl := nil;
    if Impl.TraitName <> '' then
    begin
      SymTrait := FSymbols.Resolve(Impl.TraitName);
      if (not Assigned(SymTrait)) or (SymTrait.Kind <> skTrait) then
        Error('E0425', Format('Trait "%s" nao encontrada', [Impl.TraitName]), Impl.Line, Impl.Col);

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
    end;

    // Validação das assinaturas e registro dos métodos
    for IM := 0 to Impl.Methods.Count - 1 do
    begin
      ImplMethod := TASTFunction(Impl.Methods[IM]);
      if SameText(ImplMethod.ReturnType, 'Self') then
        ImplMethod.ReturnType := Impl.TargetTypeName;

      if Assigned(TraitDecl) then
      begin
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
      end;

      // Mangling canônico do método para despacho estático
      MangledName := Impl.TargetTypeName + '_' + ImplMethod.Name;
      ImplMethod.OriginalName := ImplMethod.Name;
      ImplMethod.Name := MangledName;

      // Registra a implementação da trait (ou inherent impl) para lookup
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

  for I := 0 to OriginalFunc.Requires.Count - 1 do
    Result.Requires.Add(CloneASTNode(TASTExpr(OriginalFunc.Requires[I])));

  for I := 0 to OriginalFunc.Ensures.Count - 1 do
    Result.Ensures.Add(CloneASTNode(TASTExpr(OriginalFunc.Ensures[I])));

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
