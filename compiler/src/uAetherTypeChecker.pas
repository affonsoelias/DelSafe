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
    FCurrentSourceModule: string;
    FModule: TASTModule;
    FTraitImpls: TFPList;
    FLoopDepth: Integer;
    FUnsafeDepth: Integer;
    FLambdaCounter: Integer;
    FSpawnCounter: Integer;

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
    function SplitGenericType(const AType: string; out BaseName: string; Args: TStringList): Boolean;
    function SplitTupleTypes(const AType: string; Elems: TStringList): Boolean;
    function SplitFnType(const AType: string; ParamTypes: TStringList; out RetType: string): Boolean;
    function EnsureTupleRecord(ElemTypes: TStringList; ALine, ACol: Integer): string;
    function BuildFuncSignatureType(Func: TASTFunction): string;
    function MangleTypeName(const AType: string): string;
    function SubstituteGenericType(const AType: string; GenericParams, ConcreteArgs: TStringList): string;
    function NormalizeTypeName(const AType: string): string;
    function InstantiateGenericRecord(RecDecl: TASTRecordDecl; TypeArgs: TStringList; ALine, ACol: Integer): string;
    function UnifyGenericTypes(const FormalType, ActualType: string; GenericParams, Inferred: TStringList): Boolean;
    procedure AnnotateMonadExpr(Expr: TASTExpr; const ExpectedType: string);
    function MergeInferredMonadTypes(const T1, T2: string): string;
    procedure ReorderAndCheckFields(const KindLabel, TargetName: string; Fields: TASTNodeList; Call: TASTCallExpr);
    function TypesAreCompatible(const TargetType, SourceType: string): Boolean;

    function CheckExpr(Expr: TASTExpr): string;
    function CheckLiteral(Lit: TASTLiteralExpr): string;
    function CheckIdentifier(Id: TASTIdentifierExpr): string;
    function CheckMemberAccess(Acc: TASTMemberAccessExpr): string;
    function CheckBinary(Bin: TASTBinaryExpr): string;
    function CheckUnary(Un: TASTUnaryExpr): string;
    function CheckAwait(AwaitExpr: TASTAwaitExpr): string;
    function CheckSpawn(SpawnExpr: TASTSpawnExpr): string;
    procedure CollectSpawnCaptures(SpawnExpr: TASTSpawnExpr);
    function CheckCall(Call: TASTCallExpr): string;
    function CheckIndexExpr(Idx: TASTIndexExpr): string;
    function CheckSetLiteral(SetLit: TASTSetLiteralExpr): string;
    function CheckMapLiteral(MapLit: TASTMapLiteralExpr): string;
    function CheckTupleLiteral(Tup: TASTTupleLiteralExpr): string;
    function CheckLambda(Lambda: TASTLambdaExpr): string;
    procedure CollectLambdaCaptures(Lambda: TASTLambdaExpr; OuterScope: TScope);
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
    procedure NormalizeModuleSignatures(AModule: TASTModule);
    function TypeImplementsTrait(const ATypeName, ATraitName: string): Boolean;
    function FindTraitMethod(const ATypeName, AMethodName: string): string;
    function MonomorphizeFunction(OriginalFunc: TASTFunction; ConcreteArgs: TStringList): TASTFunction;
    procedure SubstituteGenericInExpr(Expr: TASTExpr; GenericParams, ConcreteArgs: TStringList);
    procedure SubstituteGenericInStmts(Stmts: TASTNodeList; GenericParams, ConcreteArgs: TStringList);
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

function StmtListAlwaysReturns(Stmts: TASTNodeList): Boolean; forward;

constructor EAetherTypeError.Create(const ACode, AMsg: string; ALine, ACol: Integer);
begin
  inherited Create(Format('[Semantic Error %s at %d:%d]: %s', [ACode, ALine, ACol, AMsg]));
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
  FLambdaCounter := 0;
  FSpawnCounter := 0;
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
      Error('E0308', Format('Array literal element %d (%s) is incompatible with type "%s"', [I + 1, ET, Result]), SetLit.Line, SetLit.Col);
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

function TAetherTypeChecker.SplitGenericType(const AType: string; out BaseName: string; Args: TStringList): Boolean;
var
  T, Inner, Cur: string;
  PStart, PEnd, I, DepthAngle, DepthParen, DepthBracket: Integer;
begin
  Result := False;
  BaseName := '';
  Args.Clear;
  T := Trim(AType);
  PStart := Pos('<', T);
  if (PStart <= 1) or (T[Length(T)] <> '>') then Exit;
  PEnd := Length(T);
  BaseName := Trim(Copy(T, 1, PStart - 1));
  Inner := Copy(T, PStart + 1, PEnd - PStart - 1);
  if Trim(Inner) = '' then Exit;

  DepthAngle := 0;
  DepthParen := 0;
  DepthBracket := 0;
  Cur := '';
  for I := 1 to Length(Inner) do
  begin
    case Inner[I] of
      '<': Inc(DepthAngle);
      '>': Dec(DepthAngle);
      '(': Inc(DepthParen);
      ')': Dec(DepthParen);
      '[': Inc(DepthBracket);
      ']': Dec(DepthBracket);
    end;
    if (Inner[I] = ',') and (DepthAngle = 0) and (DepthParen = 0) and (DepthBracket = 0) then
    begin
      Args.Add(Trim(Cur));
      Cur := '';
    end
    else
      Cur := Cur + Inner[I];
  end;
  if Trim(Cur) <> '' then
    Args.Add(Trim(Cur));
  Result := (BaseName <> '') and (Args.Count > 0);
end;

function TAetherTypeChecker.SplitTupleTypes(const AType: string; Elems: TStringList): Boolean;
var
  T, Inner, Cur: string;
  I, DepthAngle, DepthParen, DepthBracket: Integer;
begin
  Result := False;
  Elems.Clear;
  T := Trim(AType);
  if (Length(T) < 5) or (T[1] <> '(') or (T[Length(T)] <> ')') then Exit;
  Inner := Copy(T, 2, Length(T) - 2);
  DepthAngle := 0;
  DepthParen := 0;
  DepthBracket := 0;
  Cur := '';
  for I := 1 to Length(Inner) do
  begin
    case Inner[I] of
      '<': Inc(DepthAngle);
      '>': Dec(DepthAngle);
      '(': Inc(DepthParen);
      ')': Dec(DepthParen);
      '[': Inc(DepthBracket);
      ']': Dec(DepthBracket);
    end;
    if (Inner[I] = ',') and (DepthAngle = 0) and (DepthParen = 0) and (DepthBracket = 0) then
    begin
      Elems.Add(Trim(Cur));
      Cur := '';
    end
    else
      Cur := Cur + Inner[I];
  end;
  if Trim(Cur) <> '' then
    Elems.Add(Trim(Cur));
  Result := (DepthAngle = 0) and (DepthParen = 0) and (DepthBracket = 0) and (Elems.Count >= 2);
end;

function TAetherTypeChecker.SplitFnType(const AType: string; ParamTypes: TStringList; out RetType: string): Boolean;
var
  T, Inner, Cur, AfterParen: string;
  I, DepthParen, DepthAngle, DepthBracket, ClosePos, ArrowPos: Integer;
begin
  Result := False;
  ParamTypes.Clear;
  RetType := 'Void';
  T := Trim(AType);
  if Pos('fn(', T) <> 1 then Exit;

  DepthParen := 0;
  DepthAngle := 0;
  DepthBracket := 0;
  ClosePos := 0;
  for I := 3 to Length(T) do
  begin
    case T[I] of
      '(': Inc(DepthParen);
      ')':
        begin
          Dec(DepthParen);
          if DepthParen = 0 then
          begin
            ClosePos := I;
            Break;
          end;
        end;
    end;
  end;
  if ClosePos = 0 then Exit;

  AfterParen := Trim(Copy(T, ClosePos + 1, Length(T)));
  ArrowPos := Pos('->', AfterParen);
  if ArrowPos <> 1 then Exit;
  RetType := Trim(Copy(AfterParen, 3, Length(AfterParen)));

  Inner := Trim(Copy(T, 4, ClosePos - 4));
  if Inner <> '' then
  begin
    DepthParen := 0;
    DepthAngle := 0;
    DepthBracket := 0;
    Cur := '';
    for I := 1 to Length(Inner) do
    begin
      case Inner[I] of
        '<': Inc(DepthAngle);
        '>': Dec(DepthAngle);
        '(': Inc(DepthParen);
        ')': Dec(DepthParen);
        '[': Inc(DepthBracket);
        ']': Dec(DepthBracket);
      end;
      if (Inner[I] = ',') and (DepthAngle = 0) and (DepthParen = 0) and (DepthBracket = 0) then
      begin
        ParamTypes.Add(Trim(Cur));
        Cur := '';
      end
      else
        Cur := Cur + Inner[I];
    end;
    if Trim(Cur) <> '' then
      ParamTypes.Add(Trim(Cur));
  end;
  Result := RetType <> '';
end;

function TAetherTypeChecker.EnsureTupleRecord(ElemTypes: TStringList; ALine, ACol: Integer): string;
var
  I: Integer;
  NormT, RecName: string;
  ExistingSym, NewSym: TSymbol;
  RecDecl: TASTRecordDecl;
  FieldNode: TASTRecordField;
begin
  RecName := 'Tuple' + IntToStr(ElemTypes.Count);
  for I := 0 to ElemTypes.Count - 1 do
  begin
    NormT := NormalizeTypeName(ElemTypes[I]);
    ElemTypes[I] := NormT;
    if not FSymbols.ResolveType(NormT) then
      Error('E0412', Format('Unknown type "%s" in tuple type', [NormT]), ALine, ACol);
    RecName := RecName + '__' + MangleTypeName(NormT);
  end;

  ExistingSym := FSymbols.GlobalScope.ResolveType(RecName);
  if not Assigned(ExistingSym) then
    ExistingSym := FSymbols.ResolveTypeSymbol(RecName);
  if Assigned(ExistingSym) then
    Exit(RecName);

  RecDecl := TASTRecordDecl.Create(ALine, ACol, RecName);
  RecDecl.IsPublic := True;
  for I := 0 to ElemTypes.Count - 1 do
  begin
    FieldNode := TASTRecordField.Create(ALine, ACol, 'item' + IntToStr(I), ElemTypes[I]);
    FieldNode.IsPublic := True;
    RecDecl.Fields.Add(FieldNode);
  end;

  NewSym := TSymbol.Create(RecName, skType, RecName, ALine, ACol, True, owNone, RecDecl);
  NewSym.IsPublic := True;
  FSymbols.GlobalScope.Define(NewSym);
  if Assigned(FModule) then
    FModule.Types.Add(RecDecl);
  Result := RecName;
end;

function TAetherTypeChecker.BuildFuncSignatureType(Func: TASTFunction): string;
var
  I: Integer;
  PList, RetT: string;
begin
  PList := '';
  for I := 0 to Func.Params.Count - 1 do
  begin
    if I > 0 then PList := PList + ', ';
    PList := PList + NormalizeTypeName(TASTParam(Func.Params[I]).TypeName);
  end;
  if Func.IsProcedure then
    RetT := 'Void'
  else
    RetT := NormalizeTypeName(Func.ReturnType);
  Result := 'fn(' + PList + ') -> ' + RetT;
end;

function TAetherTypeChecker.MangleTypeName(const AType: string): string;
var
  T, BaseName, Res, RetT: string;
  Args: TStringList;
  I: Integer;
  Ch: Char;
begin
  T := Trim(AType);
  if T = '' then Exit('');
  if Pos('^', T) = 1 then
    Exit('ptr_' + MangleTypeName(Copy(T, 2, Length(T))));
  if Pos('array of ', T) = 1 then
    Exit('arr_' + MangleTypeName(Copy(T, 10, Length(T))));

  Args := TStringList.Create;
  try
    if SplitFnType(T, Args, RetT) then
    begin
      if Args.Count = 0 then
        Res := 'Fn__void'
      else
      begin
        Res := 'Fn';
        for I := 0 to Args.Count - 1 do
          Res := Res + '__' + MangleTypeName(Args[I]);
      end;
      Exit(Res + '__ret__' + MangleTypeName(RetT));
    end;
    if SplitTupleTypes(T, Args) then
    begin
      Res := 'Tuple' + IntToStr(Args.Count);
      for I := 0 to Args.Count - 1 do
        Res := Res + '__' + MangleTypeName(Args[I]);
      Exit(Res);
    end;
    if SplitGenericType(T, BaseName, Args) then
    begin
      Res := BaseName;
      for I := 0 to Args.Count - 1 do
        Res := Res + '__' + MangleTypeName(Args[I]);
      Exit(Res);
    end;
  finally
    Args.Free;
  end;

  Res := '';
  for I := 1 to Length(T) do
  begin
    Ch := T[I];
    if Ch in ['A'..'Z', 'a'..'z', '0'..'9', '_'] then
      Res := Res + Ch
    else if (Res = '') or (Res[Length(Res)] <> '_') then
      Res := Res + '_';
  end;
  Result := Res;
end;

function TAetherTypeChecker.SubstituteGenericType(const AType: string; GenericParams, ConcreteArgs: TStringList): string;
var
  T, BaseName, ElemType, Prefix, KeyT, ValT, RetT: string;
  Args: TStringList;
  I, POf, PClose: Integer;
begin
  T := Trim(AType);
  if T = '' then Exit('');
  for I := 0 to GenericParams.Count - 1 do
  begin
    if (I < ConcreteArgs.Count) and SameText(T, GenericParams[I]) then
      Exit(ConcreteArgs[I]);
  end;

  if Pos('^', T) = 1 then
    Exit('^' + SubstituteGenericType(Copy(T, 2, Length(T)), GenericParams, ConcreteArgs));

  if Pos('array of ', T) = 1 then
    Exit('array of ' + SubstituteGenericType(Trim(Copy(T, 10, Length(T))), GenericParams, ConcreteArgs));

  if Pos('array[', T) = 1 then
  begin
    POf := Pos(' of ', T);
    if POf > 0 then
    begin
      Prefix := Copy(T, 1, POf + 3);
      ElemType := Trim(Copy(T, POf + 4, Length(T)));
      Exit(Prefix + SubstituteGenericType(ElemType, GenericParams, ConcreteArgs));
    end;
  end;

  if Pos('map[', T) = 1 then
  begin
    PClose := Pos(']', T);
    if PClose > 4 then
    begin
      KeyT := Trim(Copy(T, 5, PClose - 5));
      ValT := Trim(Copy(T, PClose + 1, Length(T)));
      Exit('map[' + SubstituteGenericType(KeyT, GenericParams, ConcreteArgs) + '] ' +
        SubstituteGenericType(ValT, GenericParams, ConcreteArgs));
    end;
  end;

  Args := TStringList.Create;
  try
    if SplitFnType(T, Args, RetT) then
    begin
      Result := 'fn(';
      for I := 0 to Args.Count - 1 do
      begin
        if I > 0 then Result := Result + ', ';
        Result := Result + SubstituteGenericType(Args[I], GenericParams, ConcreteArgs);
      end;
      Result := Result + ') -> ' + SubstituteGenericType(RetT, GenericParams, ConcreteArgs);
      Exit;
    end;
    if SplitTupleTypes(T, Args) then
    begin
      Result := '(';
      for I := 0 to Args.Count - 1 do
      begin
        if I > 0 then Result := Result + ', ';
        Result := Result + SubstituteGenericType(Args[I], GenericParams, ConcreteArgs);
      end;
      Result := Result + ')';
      Exit;
    end;
    if SplitGenericType(T, BaseName, Args) then
    begin
      Result := BaseName + '<';
      for I := 0 to Args.Count - 1 do
      begin
        if I > 0 then Result := Result + ', ';
        Result := Result + SubstituteGenericType(Args[I], GenericParams, ConcreteArgs);
      end;
      Result := Result + '>';
      Exit;
    end;
  finally
    Args.Free;
  end;

  Result := T;
end;

function TAetherTypeChecker.InstantiateGenericRecord(RecDecl: TASTRecordDecl; TypeArgs: TStringList; ALine, ACol: Integer): string;
var
  I: Integer;
  NormArgs: TStringList;
  Mangled, FieldType: string;
  ExistingSym, NewSym: TSymbol;
  MonoRec: TASTRecordDecl;
  SrcField, NewField: TASTRecordField;
begin
  if RecDecl.GenericParams.Count <> TypeArgs.Count then
    Error('E0061', Format('Generic record "%s" expects %d type argument(s), but got %d',
      [RecDecl.Name, RecDecl.GenericParams.Count, TypeArgs.Count]), ALine, ACol);

  NormArgs := TStringList.Create;
  try
    Mangled := RecDecl.Name;
    for I := 0 to TypeArgs.Count - 1 do
    begin
      NormArgs.Add(NormalizeTypeName(TypeArgs[I]));
      Mangled := Mangled + '__' + MangleTypeName(NormArgs[I]);
    end;

    ExistingSym := FSymbols.GlobalScope.ResolveType(Mangled);
    if not Assigned(ExistingSym) then
      ExistingSym := FSymbols.ResolveTypeSymbol(Mangled);
    if Assigned(ExistingSym) then
      Exit(Mangled);

    MonoRec := TASTRecordDecl.Create(RecDecl.Line, RecDecl.Col, Mangled);
    MonoRec.TemplateName := RecDecl.Name;
    MonoRec.ConcreteGenericArgs.AddStrings(NormArgs);
    MonoRec.IsPublic := RecDecl.IsPublic;
    MonoRec.SourceModule := RecDecl.SourceModule;

    // Define symbol in global scope before field normalization to break pointer self-cycles
    NewSym := TSymbol.Create(Mangled, skType, Mangled, RecDecl.Line, RecDecl.Col, True, owNone, MonoRec);
    NewSym.IsPublic := RecDecl.IsPublic;
    NewSym.SourceModule := RecDecl.SourceModule;
    FSymbols.GlobalScope.Define(NewSym);

    for I := 0 to RecDecl.Fields.Count - 1 do
    begin
      SrcField := TASTRecordField(RecDecl.Fields[I]);
      FieldType := NormalizeTypeName(SubstituteGenericType(SrcField.TypeName, RecDecl.GenericParams, NormArgs));
      if not FSymbols.ResolveType(FieldType) then
        Error('E0412', Format('Unknown type "%s" while instantiating "%s"', [FieldType, Mangled]), ALine, ACol);
      NewField := TASTRecordField.Create(SrcField.Line, SrcField.Col, SrcField.Name, FieldType);
      NewField.IsPublic := SrcField.IsPublic;
      NewField.HasExplicitVis := SrcField.HasExplicitVis;
      NewField.SourceModule := SrcField.SourceModule;
      MonoRec.Fields.Add(NewField);
    end;

    if Assigned(FModule) then
      FModule.Types.Add(MonoRec);
    Result := Mangled;
  finally
    NormArgs.Free;
  end;
end;

function TAetherTypeChecker.NormalizeTypeName(const AType: string): string;
var
  T, BaseName, Prefix, ElemType, KeyT, ValT, Joined, RetT: string;
  Args: TStringList;
  I, POf, PClose: Integer;
  Sym: TSymbol;
  RecDecl: TASTRecordDecl;
  AllResolved: Boolean;
begin
  T := Trim(AType);
  if T = '' then Exit('');

  if Pos('^', T) = 1 then
    Exit('^' + NormalizeTypeName(Copy(T, 2, Length(T))));

  if Pos('array of ', T) = 1 then
    Exit('array of ' + NormalizeTypeName(Trim(Copy(T, 10, Length(T)))));

  if Pos('array[', T) = 1 then
  begin
    POf := Pos(' of ', T);
    if POf > 0 then
    begin
      Prefix := Copy(T, 1, POf + 3);
      ElemType := Trim(Copy(T, POf + 4, Length(T)));
      Exit(Prefix + NormalizeTypeName(ElemType));
    end;
  end;

  if Pos('map[', T) = 1 then
  begin
    PClose := Pos(']', T);
    if PClose > 4 then
    begin
      KeyT := Trim(Copy(T, 5, PClose - 5));
      ValT := Trim(Copy(T, PClose + 1, Length(T)));
      Exit('map[' + NormalizeTypeName(KeyT) + '] ' + NormalizeTypeName(ValT));
    end;
  end;

  Args := TStringList.Create;
  try
    if SplitFnType(T, Args, RetT) then
    begin
      Joined := 'fn(';
      for I := 0 to Args.Count - 1 do
      begin
        Args[I] := NormalizeTypeName(Args[I]);
        if I > 0 then Joined := Joined + ', ';
        Joined := Joined + Args[I];
      end;
      RetT := NormalizeTypeName(RetT);
      Exit(Joined + ') -> ' + RetT);
    end;

    if SplitTupleTypes(T, Args) then
    begin
      AllResolved := Assigned(FSymbols);
      for I := 0 to Args.Count - 1 do
      begin
        Args[I] := NormalizeTypeName(Args[I]);
        if AllResolved and (not FSymbols.ResolveType(Args[I])) then
          AllResolved := False;
      end;
      if AllResolved then
        Exit(EnsureTupleRecord(Args, 0, 0));
      Joined := '(';
      for I := 0 to Args.Count - 1 do
      begin
        if I > 0 then Joined := Joined + ', ';
        Joined := Joined + Args[I];
      end;
      Exit(Joined + ')');
    end;

    if SplitGenericType(T, BaseName, Args) then
    begin
      for I := 0 to Args.Count - 1 do
        Args[I] := NormalizeTypeName(Args[I]);

      Joined := BaseName + '<';
      for I := 0 to Args.Count - 1 do
      begin
        if I > 0 then Joined := Joined + ', ';
        Joined := Joined + Args[I];
      end;
      Joined := Joined + '>';

      if SameText(BaseName, 'Option') or SameText(BaseName, 'Result') or
         SameText(BaseName, 'Box') or SameText(BaseName, 'Task') then
        Exit(Joined);

      if Assigned(FSymbols) then
      begin
        Sym := FSymbols.ResolveTypeSymbol(BaseName);
        if Assigned(Sym) and (Sym.Node is TASTRecordDecl) and (TASTRecordDecl(Sym.Node).GenericParams.Count > 0) then
        begin
          RecDecl := TASTRecordDecl(Sym.Node);
          for I := 0 to Args.Count - 1 do
            if not FSymbols.ResolveType(Args[I]) then
              Exit(Joined);
          Exit(InstantiateGenericRecord(RecDecl, Args, RecDecl.Line, RecDecl.Col));
        end;
      end;
      Exit(Joined);
    end;
  finally
    Args.Free;
  end;

  Result := T;
end;

function TAetherTypeChecker.UnifyGenericTypes(const FormalType, ActualType: string; GenericParams, Inferred: TStringList): Boolean;
var
  F, A, FormalBase, ActualBase, FormalElem, ActualElem, FormalKey, FormalVal, ActualKey, ActualVal: string;
  FormalRet, ActualRet: string;
  FArgs, AArgs: TStringList;
  I: Integer;
  Sym: TSymbol;
  RecDecl: TASTRecordDecl;
begin
  F := Trim(FormalType);
  A := NormalizeTypeName(ResolveAliasType(Trim(ActualType)));

  for I := 0 to GenericParams.Count - 1 do
  begin
    if SameText(F, GenericParams[I]) then
    begin
      if (Inferred[I] = '') or (Inferred[I] = 'IntLiteral') or (Inferred[I] = 'FloatLiteral') then
        Inferred[I] := A;
      Exit(True);
    end;
  end;

  if (Pos('^', F) = 1) and (Pos('^', A) = 1) then
    Exit(UnifyGenericTypes(Copy(F, 2, Length(F)), Copy(A, 2, Length(A)), GenericParams, Inferred));

  if IsDynamicArrayType(F, FormalElem) and IsDynamicArrayType(A, ActualElem) then
    Exit(UnifyGenericTypes(FormalElem, ActualElem, GenericParams, Inferred));

  if IsMapType(F, FormalKey, FormalVal) and IsMapType(A, ActualKey, ActualVal) then
    Exit(UnifyGenericTypes(FormalKey, ActualKey, GenericParams, Inferred) and
         UnifyGenericTypes(FormalVal, ActualVal, GenericParams, Inferred));

  FArgs := TStringList.Create;
  AArgs := TStringList.Create;
  try
    if SplitFnType(F, FArgs, FormalRet) and SplitFnType(A, AArgs, ActualRet) and (FArgs.Count = AArgs.Count) then
    begin
      Result := True;
      for I := 0 to FArgs.Count - 1 do
        if not UnifyGenericTypes(FArgs[I], AArgs[I], GenericParams, Inferred) then
          Result := False;
      if not UnifyGenericTypes(FormalRet, ActualRet, GenericParams, Inferred) then
        Result := False;
      Exit;
    end;

    if SplitTupleTypes(F, FArgs) then
    begin
      if SplitTupleTypes(A, AArgs) and (FArgs.Count = AArgs.Count) then
      begin
        Result := True;
        for I := 0 to FArgs.Count - 1 do
          if not UnifyGenericTypes(FArgs[I], AArgs[I], GenericParams, Inferred) then
            Result := False;
        Exit;
      end;
      if Assigned(FSymbols) then
      begin
        Sym := FSymbols.ResolveTypeSymbol(A);
        if Assigned(Sym) and (Sym.Node is TASTRecordDecl) and (Pos('Tuple', TASTRecordDecl(Sym.Node).Name) = 1) and
           (TASTRecordDecl(Sym.Node).Fields.Count = FArgs.Count) then
        begin
          RecDecl := TASTRecordDecl(Sym.Node);
          Result := True;
          for I := 0 to FArgs.Count - 1 do
            if not UnifyGenericTypes(FArgs[I], TASTRecordField(RecDecl.Fields[I]).TypeName, GenericParams, Inferred) then
              Result := False;
          Exit;
        end;
      end;
    end;

    if SplitGenericType(F, FormalBase, FArgs) then
    begin
      if SplitGenericType(A, ActualBase, AArgs) and SameText(FormalBase, ActualBase) and (FArgs.Count = AArgs.Count) then
      begin
        Result := True;
        for I := 0 to FArgs.Count - 1 do
          if not UnifyGenericTypes(FArgs[I], AArgs[I], GenericParams, Inferred) then
            Result := False;
        Exit;
      end;
      if Assigned(FSymbols) then
      begin
        Sym := FSymbols.ResolveTypeSymbol(A);
        if Assigned(Sym) and (Sym.Node is TASTRecordDecl) then
        begin
          RecDecl := TASTRecordDecl(Sym.Node);
          if (RecDecl.TemplateName <> '') and SameText(RecDecl.TemplateName, FormalBase) and
             (RecDecl.ConcreteGenericArgs.Count = FArgs.Count) then
          begin
            Result := True;
            for I := 0 to FArgs.Count - 1 do
              if not UnifyGenericTypes(FArgs[I], RecDecl.ConcreteGenericArgs[I], GenericParams, Inferred) then
                Result := False;
            Exit;
          end;
        end;
      end;
    end;
  finally
    FArgs.Free;
    AArgs.Free;
  end;

  Result := True;
end;

procedure TAetherTypeChecker.AnnotateMonadExpr(Expr: TASTExpr; const ExpectedType: string);
var
  T, ExpRet: string;
  Call: TASTCallExpr;
  IfE: TASTIfExpr;
  ME: TASTMatchExpr;
  Tup: TASTTupleLiteralExpr;
  Lam: TASTLambdaExpr;
  RecDecl: TASTRecordDecl;
  Sym: TSymbol;
  ExpParams: TStringList;
  I: Integer;
begin
  if not Assigned(Expr) then Exit;
  T := NormalizeTypeName(ResolveAliasType(ExpectedType));
  if T = '' then Exit;

  if Expr is TASTIdentifierExpr then
  begin
    if (SameText(TASTIdentifierExpr(Expr).Name, 'None') or (TASTIdentifierExpr(Expr).Name = '__ValueNone')) and
       IsValueOptionType(T) then
    begin
      TASTIdentifierExpr(Expr).Name := '__ValueNone';
      TASTIdentifierExpr(Expr).ResolvedMonadType := T;
    end;
  end
  else if Expr is TASTTupleLiteralExpr then
  begin
    Tup := TASTTupleLiteralExpr(Expr);
    if Assigned(FSymbols) then
    begin
      Sym := FSymbols.ResolveTypeSymbol(T);
      if Assigned(Sym) and (Sym.Node is TASTRecordDecl) and (Pos('Tuple', TASTRecordDecl(Sym.Node).Name) = 1) then
      begin
        RecDecl := TASTRecordDecl(Sym.Node);
        if RecDecl.Fields.Count = Tup.Elements.Count then
        begin
          Tup.ResolvedType := RecDecl.Name;
          for I := 0 to Tup.Elements.Count - 1 do
            AnnotateMonadExpr(TASTExpr(Tup.Elements[I]), TASTRecordField(RecDecl.Fields[I]).TypeName);
        end;
      end;
    end;
  end
  else if Expr is TASTLambdaExpr then
  begin
    Lam := TASTLambdaExpr(Expr);
    ExpParams := TStringList.Create;
    try
      if SplitFnType(T, ExpParams, ExpRet) then
      begin
        for I := 0 to Lam.Params.Count - 1 do
          if (TASTParam(Lam.Params[I]).TypeName = '') and (I < ExpParams.Count) then
            TASTParam(Lam.Params[I]).TypeName := ExpParams[I];
        if Lam.ReturnType = '' then
          Lam.ReturnType := ExpRet;
        if Assigned(Lam.BodyExpr) then
          AnnotateMonadExpr(Lam.BodyExpr, ExpRet);
      end;
    finally
      ExpParams.Free;
    end;
  end
  else if Expr is TASTCallExpr then
  begin
    Call := TASTCallExpr(Expr);
    if ((Call.Callee = 'Some') and (Pos('Option<', T) = 1)) or
       (((Call.Callee = 'Ok') or (Call.Callee = 'Err')) and (Pos('Result<', T) = 1)) then
      Call.ResolvedMonadType := T;
  end
  else if Expr is TASTIfExpr then
  begin
    IfE := TASTIfExpr(Expr);
    AnnotateMonadExpr(IfE.ThenExpr, T);
    AnnotateMonadExpr(IfE.ElseExpr, T);
  end
  else if Expr is TASTMatchExpr then
  begin
    ME := TASTMatchExpr(Expr);
    for I := 0 to ME.Cases.Count - 1 do
      AnnotateMonadExpr(TASTMatchCase(ME.Cases[I]).ValueExpr, T);
  end;
end;

function TAetherTypeChecker.MergeInferredMonadTypes(const T1, T2: string): string;
var
  A1, A2, V1, E1, V2, E2, V, E: string;
  B1, B2: string;
  Args1, Args2: TStringList;
begin
  A1 := ResolveAliasType(T1);
  A2 := ResolveAliasType(T2);
  if A1 = '' then Exit(A2);
  if A2 = '' then Exit(A1);

  if (Pos('Option<', A1) = 1) and (Pos('Option<', A2) = 1) then
  begin
    if A1 = 'Option<GenericNone>' then Exit(A2);
    if A2 = 'Option<GenericNone>' then Exit(A1);
    Args1 := TStringList.Create;
    Args2 := TStringList.Create;
    try
      if SplitGenericType(A1, B1, Args1) and SplitGenericType(A2, B2, Args2) then
      begin
        V := Args1[0];
        if (V = 'IntLiteral') and (Args2[0] <> 'IntLiteral') then V := Args2[0]
        else if (V = 'FloatLiteral') and (Args2[0] <> 'FloatLiteral') then V := Args2[0];
        if V = 'IntLiteral' then V := 'Int32'
        else if V = 'FloatLiteral' then V := 'Float64';
        Exit('Option<' + NormalizeTypeName(V) + '>');
      end;
    finally
      Args1.Free;
      Args2.Free;
    end;
  end;

  if (Pos('Result<', A1) = 1) and (Pos('Result<', A2) = 1) then
  begin
    SplitResultTypes(A1, V1, E1);
    SplitResultTypes(A2, V2, E2);
    if (V1 = 'GenericValue') or (V1 = 'IntLiteral') or (V1 = 'FloatLiteral') then
    begin
      if V2 <> 'GenericValue' then V := V2 else V := V1;
    end
    else
      V := V1;
    if (E1 = 'GenericError') or (E1 = 'IntLiteral') or (E1 = 'FloatLiteral') then
    begin
      if E2 <> 'GenericError' then E := E2 else E := E1;
    end
    else
      E := E1;
    if V = 'IntLiteral' then V := 'Int32' else if V = 'FloatLiteral' then V := 'Float64';
    if E = 'IntLiteral' then E := 'Int32' else if E = 'FloatLiteral' then E := 'Float64';
    Exit('Result<' + NormalizeTypeName(V) + ', ' + NormalizeTypeName(E) + '>');
  end;

  if A1 = 'Option<GenericNone>' then Exit(A2);
  if A2 = 'Option<GenericNone>' then Exit(A1);
  if A1 = 'IntLiteral' then Exit(A2);
  if A2 = 'IntLiteral' then Exit(A1);
  if A1 = 'FloatLiteral' then Exit(A2);
  if A2 = 'FloatLiteral' then Exit(A1);
  Result := A1;
end;

procedure TAetherTypeChecker.ReorderAndCheckFields(const KindLabel, TargetName: string; Fields: TASTNodeList; Call: TASTCallExpr);
var
  I, K: Integer;
  Arg: TASTCallArg;
  HasNamed, HasPositional, FoundField: Boolean;
  ReorderedArgs: array of TASTCallArg;
  ArgType, ExpectedType: string;
begin
  HasNamed := False;
  HasPositional := False;
  for I := 0 to Call.Args.Count - 1 do
    if TASTCallArg(Call.Args[I]).FieldName <> '' then
      HasNamed := True
    else
      HasPositional := True;

  if HasNamed and HasPositional then
    Error('E0061', Format('%s "%s" constructor cannot mix positional and named arguments',
      [KindLabel, TargetName]), Call.Line, Call.Col);

  if Call.Args.Count <> Fields.Count then
    Error('E0061', Format('%s "%s" constructor expects %d fields, but got %d',
      [KindLabel, TargetName, Fields.Count, Call.Args.Count]), Call.Line, Call.Col);

  if HasNamed and (Fields.Count > 0) then
  begin
    SetLength(ReorderedArgs, Fields.Count);
    for K := 0 to High(ReorderedArgs) do
      ReorderedArgs[K] := nil;
    for I := 0 to Call.Args.Count - 1 do
    begin
      Arg := TASTCallArg(Call.Args[I]);
      FoundField := False;
      for K := 0 to Fields.Count - 1 do
      begin
        if SameText(TASTRecordField(Fields[K]).Name, Arg.FieldName) then
        begin
          FoundField := True;
          if ReorderedArgs[K] <> nil then
            Error('E0061', Format('Duplicate field "%s" in constructor for %s "%s"',
              [Arg.FieldName, LowerCase(KindLabel), TargetName]), Arg.Line, Arg.Col);
          ReorderedArgs[K] := Arg;
          Break;
        end;
      end;
      if not FoundField then
        Error('E0609', Format('%s "%s" has no field named "%s"',
          [KindLabel, TargetName, Arg.FieldName]), Arg.Line, Arg.Col);
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
    ExpectedType := NormalizeTypeName(TASTRecordField(Fields[I]).TypeName);
    AnnotateMonadExpr(Arg.Expr, ExpectedType);
    if not TypesAreCompatible(ExpectedType, ArgType) then
      Error('E0308', Format('Field "%s" of %s "%s" expects "%s", but got "%s"',
        [TASTRecordField(Fields[I]).Name, LowerCase(KindLabel), TargetName, ExpectedType, ArgType]), Arg.Line, Arg.Col);
  end;
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
  TBase, SBase, TV, TE, SV, SE, TRet, SRet: string;
  TArgs, SArgs: TStringList;
  IsFix: Boolean;
  DimN, I: Integer;
  SymT, SymS: TSymbol;
begin
  T := NormalizeTypeName(ResolveAliasType(TargetType));
  S := NormalizeTypeName(ResolveAliasType(SourceType));
  if T = S then Exit(True);
  // Function types
  TArgs := TStringList.Create;
  SArgs := TStringList.Create;
  try
    if SplitFnType(T, TArgs, TRet) and SplitFnType(S, SArgs, SRet) then
    begin
      if TArgs.Count <> SArgs.Count then Exit(False);
      for I := 0 to TArgs.Count - 1 do
        if not TypesAreCompatible(TArgs[I], SArgs[I]) then Exit(False);
      if SameText(TRet, 'Void') or SameText(SRet, 'Void') then
        Exit(SameText(TRet, SRet));
      Exit(TypesAreCompatible(TRet, SRet));
    end;
  finally
    TArgs.Free;
    SArgs.Free;
  end;
  // Anonymous tuple records (element-wise compatibility, e.g. IntLiteral promoted in literal)
  if (Pos('Tuple', T) = 1) and (Pos('Tuple', S) = 1) and Assigned(FSymbols) then
  begin
    SymT := FSymbols.ResolveTypeSymbol(T);
    SymS := FSymbols.ResolveTypeSymbol(S);
    if Assigned(SymT) and Assigned(SymS) and (SymT.Node is TASTRecordDecl) and (SymS.Node is TASTRecordDecl) and
       (TASTRecordDecl(SymT.Node).Fields.Count = TASTRecordDecl(SymS.Node).Fields.Count) then
    begin
      Result := True;
      for I := 0 to TASTRecordDecl(SymT.Node).Fields.Count - 1 do
        if not TypesAreCompatible(TASTRecordField(TASTRecordDecl(SymT.Node).Fields[I]).TypeName,
                                  TASTRecordField(TASTRecordDecl(SymS.Node).Fields[I]).TypeName) then
        begin
          Result := False;
          Break;
        end;
      if Result then Exit(True);
    end;
  end;
  // Associative maps
  if IsMapType(T, TargetKey, TargetVal) and IsMapType(S, SourceKey, SourceVal) then
    Exit(TypesAreCompatible(TargetKey, SourceKey) and TypesAreCompatible(TargetVal, SourceVal));
  // Pointers and nil
  if (S = 'NilLiteral') and ((Pos('^', T) = 1) or (T = 'Pointer')) then Exit(True);
  if (T = 'NilLiteral') and ((Pos('^', S) = 1) or (S = 'Pointer')) then Exit(True);
  if ((T = 'Pointer') and (Pos('^', S) = 1)) or ((S = 'Pointer') and (Pos('^', T) = 1)) then Exit(True);
  if (Pos('^', T) = 1) and (Pos('^', S) = 1) then
    Exit(TypesAreCompatible(Copy(T, 2, Length(T)), Copy(S, 2, Length(S))));
  // Dynamic arrays
  if IsDynamicArrayType(T, TargetElem) and IsDynamicArrayType(S, SourceElem) then
    Exit(TypesAreCompatible(TargetElem, SourceElem));
  // Generic integer literals are compatible with any integer type
  if (S = 'IntLiteral') and (Pos('Int', T) > 0) then Exit(True);
  // Compatibility between integer types (Int32, UInt32, etc.)
  if IsIntegerType(T) and IsIntegerType(S) then Exit(True);
  // Generic float literals are compatible with Float32 or Float64
  if (S = 'FloatLiteral') and (Pos('Float', T) > 0) then Exit(True);
  // Generic Result / Option / Box / Task
  if (Pos('Result<', T) = 1) and (Pos('Result<', S) = 1) then
  begin
    if SplitResultTypes(T, TV, TE) and SplitResultTypes(S, SV, SE) then
      Exit(((TV = 'GenericValue') or (SV = 'GenericValue') or TypesAreCompatible(TV, SV)) and
           ((TE = 'GenericError') or (SE = 'GenericError') or TypesAreCompatible(TE, SE)));
    Exit(True);
  end;
  if (Pos('Option<', T) = 1) and (Pos('Option<', S) = 1) then
  begin
    if (S = 'Option<GenericNone>') or (T = 'Option<GenericNone>') then Exit(True);
    TArgs := TStringList.Create;
    SArgs := TStringList.Create;
    try
      if SplitGenericType(T, TBase, TArgs) and SplitGenericType(S, SBase, SArgs) then
        Exit(TypesAreCompatible(TArgs[0], SArgs[0]));
    finally
      TArgs.Free;
      SArgs.Free;
    end;
    Exit(True);
  end;
  if (Pos('Option<Box<', T) = 1) and ((Pos('Box<', S) = 1) or (S = 'Option<GenericNone>')) then Exit(True);
  if (Pos('Box<', T) = 1) and (Pos('Box<', S) = 1) then
  begin
    TArgs := TStringList.Create;
    SArgs := TStringList.Create;
    try
      if SplitGenericType(T, TBase, TArgs) and SplitGenericType(S, SBase, SArgs) then
        Exit(TypesAreCompatible(TArgs[0], SArgs[0]));
    finally
      TArgs.Free;
      SArgs.Free;
    end;
    Exit(True);
  end;
  if ((Pos('Task<', T) = 1) and (Pos('Task<', S) = 1)) or
     ((Pos('Channel<', T) = 1) and (Pos('Channel<', S) = 1)) then
  begin
    TArgs := TStringList.Create;
    SArgs := TStringList.Create;
    try
      if SplitGenericType(T, TBase, TArgs) and SplitGenericType(S, SBase, SArgs) then
        Exit(TypesAreCompatible(TArgs[0], SArgs[0]));
    finally
      TArgs.Free;
      SArgs.Free;
    end;
    Exit(True);
  end;
  // Set literals, array literals, and map literals
  if (S = 'MapLiteral') and IsMapType(T, TargetKey, TargetVal) then Exit(True);
  if (S = 'SetLiteral') and (IsSetType(T) or IsArrayType(T, TargetElem, IsFix, DimN)) then Exit(True);
  if (T = 'SetLiteral') and IsSetType(S) then Exit(True);
  if IsSetType(T) and IsSetType(S) then Exit(True);
  // Compatibility with subranges and user-defined types
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
  // Special case: 'None' (empty Option)
  if SameText(Id.Name, 'None') then
    Exit('Option<GenericNone>');
  if Id.Name = '__ValueNone' then
  begin
    if Id.ResolvedMonadType <> '' then
      Exit(Id.ResolvedMonadType)
    else
      Exit('Option<GenericNone>');
  end;

  // Special case: 'result' inside contracts
  if SameText(Id.Name, 'result') and Assigned(FCurrentFunction) then
    Exit(FCurrentFunction.ReturnType);

  Sym := FSymbols.Resolve(Id.Name);
  if not Assigned(Sym) then
    Error('E0425', Format('Identifier not found: "%s"', [Id.Name]), Id.Line, Id.Col);

  CheckVisibility(Sym.IsPublic, Sym.SourceModule, Sym.Name, Id.Line, Id.Col);
  if (Sym.Kind = skFunction) and (Sym.Node is TASTFunction) then
  begin
    Id.IsFnValueRef := True;
    Id.ResolvedFnType := BuildFuncSignatureType(TASTFunction(Sym.Node));
    Exit(Id.ResolvedFnType);
  end;
  if (Sym.Kind = skEnumVariant) and (Sym.Node is TASTEnumVariant) and
     (TASTEnumVariant(Sym.Node).Fields.Count > 0) then
    Error('E0061', Format('Enum variant "%s" expects %d field argument(s)',
      [Sym.Name, TASTEnumVariant(Sym.Node).Fields.Count]), Id.Line, Id.Col);
  Result := NormalizeTypeName(Sym.TypeName);
end;

function TAetherTypeChecker.CheckMemberAccess(Acc: TASTMemberAccessExpr): string;
var
  TargetType, ModName: string;
  Sym: TSymbol;
  I: Integer;
  RecDecl: TASTRecordDecl;
  EnumDecl: TASTEnumDecl;
  Field: TASTRecordField;
  InnerRecName, ResVal, ResErr, BaseG: string;
  GArgs: TStringList;
begin
  // If target is an Identifier or Module.Enum, it may be a Module/Alias, Enum, or variable
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
        begin
          if TASTEnumVariant(EnumDecl.Variants[I]).Fields.Count > 0 then
            Error('E0061', Format('Enum variant "%s.%s" expects %d field argument(s)',
              [EnumDecl.Name, TASTEnumVariant(EnumDecl.Variants[I]).Name, TASTEnumVariant(EnumDecl.Variants[I]).Fields.Count]),
              Acc.Line, Acc.Col);
          Exit(EnumDecl.Name);
        end;
      end;
      Error('E0599', Format('Variant "%s" does not belong to enum "%s"', [Acc.Member, EnumDecl.Name]), Acc.Line, Acc.Col);
    end;
  end;

  if Acc.Target is TASTIdentifierExpr then
  begin
    if IsModulePrefix(TASTIdentifierExpr(Acc.Target).Name, ModName) then
    begin
      Sym := FSymbols.Resolve(Acc.Member);
      if (not Assigned(Sym)) or ((Sym.SourceModule <> '') and (not MatchesModuleName(ModName, Sym.SourceModule))) then
        Error('E0425', Format('Symbol "%s" not found in module "%s"', [Acc.Member, TASTIdentifierExpr(Acc.Target).Name]), Acc.Line, Acc.Col);
      CheckVisibility(Sym.IsPublic, Sym.SourceModule, Sym.Name, Acc.Line, Acc.Col);
      Exit(NormalizeTypeName(Sym.TypeName));
    end;

    Sym := FSymbols.Resolve(TASTIdentifierExpr(Acc.Target).Name);
    if Assigned(Sym) then
    begin
      // Case Enum.Variant (e.g., MathError.DivisionByZero)
      if (Sym.Kind = skType) and (Sym.Node is TASTEnumDecl) then
      begin
        CheckVisibility(Sym.IsPublic, Sym.SourceModule, Sym.Name, Acc.Line, Acc.Col);
        EnumDecl := TASTEnumDecl(Sym.Node);
        for I := 0 to EnumDecl.Variants.Count - 1 do
        begin
          if SameText(TASTEnumVariant(EnumDecl.Variants[I]).Name, Acc.Member) then
          begin
            if TASTEnumVariant(EnumDecl.Variants[I]).Fields.Count > 0 then
              Error('E0061', Format('Enum variant "%s.%s" expects %d field argument(s)',
                [EnumDecl.Name, TASTEnumVariant(EnumDecl.Variants[I]).Name, TASTEnumVariant(EnumDecl.Variants[I]).Fields.Count]),
                Acc.Line, Acc.Col);
            Exit(EnumDecl.Name);
          end;
        end;
        Error('E0599', Format('Variant "%s" does not belong to enum "%s"', [Acc.Member, EnumDecl.Name]), Acc.Line, Acc.Col);
      end;
    end;
  end;

  TargetType := NormalizeTypeName(ResolveAliasType(CheckExpr(Acc.Target)));

  // Intrinsic Result properties (e.g., result.is_ok, result.value, result.error)
  if Pos('Result<', TargetType) = 1 then
  begin
    if SameText(Acc.Member, 'is_ok') or SameText(Acc.Member, 'is_err') then
      Exit('Bool');
    if SameText(Acc.Member, 'value') then
    begin
      SplitResultTypes(TargetType, ResVal, ResErr);
      Exit(NormalizeTypeName(ResVal));
    end;
    if SameText(Acc.Member, 'error') then
    begin
      SplitResultTypes(TargetType, ResVal, ResErr);
      Exit(NormalizeTypeName(ResErr));
    end;
  end;

  // Intrinsic Option properties (e.g., opt.is_some, opt.is_none, opt.value)
  if Pos('Option<', TargetType) = 1 then
  begin
    if SameText(Acc.Member, 'is_some') or SameText(Acc.Member, 'is_none') then
      Exit('Bool');

    if SameText(Acc.Member, 'value') then
    begin
      GArgs := TStringList.Create;
      try
        if SplitGenericType(TargetType, BaseG, GArgs) then
          InnerRecName := GArgs[0]
        else
          InnerRecName := Trim(Copy(TargetType, 8, Length(TargetType) - 8));
        if Pos('Box<', InnerRecName) = 1 then
        begin
          GArgs.Clear;
          if SplitGenericType(InnerRecName, BaseG, GArgs) then
            InnerRecName := GArgs[0];
        end;
      finally
        GArgs.Free;
      end;
      Exit(NormalizeTypeName(InnerRecName));
    end;
  end;

  // Auto-deref of Box<Record> or Option<Box<Record>>
  if Pos('Box<', TargetType) > 0 then
  begin
    InnerRecName := TargetType;
    GArgs := TStringList.Create;
    try
      if Pos('Option<', InnerRecName) = 1 then
      begin
        if SplitGenericType(InnerRecName, BaseG, GArgs) then
          InnerRecName := GArgs[0];
      end;
      GArgs.Clear;
      if SplitGenericType(InnerRecName, BaseG, GArgs) and SameText(BaseG, 'Box') then
        InnerRecName := NormalizeTypeName(GArgs[0]);
    finally
      GArgs.Free;
    end;

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
          Exit(NormalizeTypeName(Field.TypeName));
      end;
    end;
  end;

  // Record member
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
    Error('E0609', Format('Field "%s" does not exist on record "%s"', [Acc.Member, TargetType]), Acc.Line, Acc.Col);
  end;

  Error('E0609', Format('Cannot access member "%s" on type "%s"', [Acc.Member, TargetType]), Acc.Line, Acc.Col);
  Result := 'Unknown';
end;

function TAetherTypeChecker.CheckBinary(Bin: TASTBinaryExpr): string;
var
  LeftType, RightType: string;
begin
  LeftType := CheckExpr(Bin.Left);
  RightType := CheckExpr(Bin.Right);

  // Arithmetic operations: +, -, *, /, mod, div, %
  if (Bin.Op = '+') or (Bin.Op = '-') or (Bin.Op = '*') or (Bin.Op = '/') or (Bin.Op = 'mod') or (Bin.Op = 'div') or (Bin.Op = '%') then
  begin
    // Set operations: union (+), intersection (*), difference (-)
    if (Bin.Op = '+') or (Bin.Op = '-') or (Bin.Op = '*') then
    begin
      if IsSetType(LeftType) or IsSetType(RightType) then
      begin
        if LeftType <> 'SetLiteral' then Exit(LeftType)
        else Exit(RightType);
      end;
    end;

    // String concatenation with +
    if (Bin.Op = '+') and ((LeftType = 'String') or (RightType = 'String')) then
      Exit('String');

    if not IsNumericType(LeftType) and (LeftType <> 'IntLiteral') and (LeftType <> 'FloatLiteral') then
      Error('E0369', Format('Left operand of "%s" must be numeric, found: "%s"', [Bin.Op, LeftType]), Bin.Line, Bin.Col);

    if not IsNumericType(RightType) and (RightType <> 'IntLiteral') and (RightType <> 'FloatLiteral') then
      Error('E0369', Format('Right operand of "%s" must be numeric, found: "%s"', [Bin.Op, RightType]), Bin.Line, Bin.Col);

    // Compile-time division-by-zero detection (comptime / const eval)
    if (Bin.Op = '/') or (Bin.Op = 'mod') or (Bin.Op = 'div') or (Bin.Op = '%') then
    begin
      if (Bin.Right is TASTLiteralExpr) and
         (((TASTLiteralExpr(Bin.Right).Kind = lkInt) and (TASTLiteralExpr(Bin.Right).Value = '0')) or
          ((TASTLiteralExpr(Bin.Right).Kind = lkFloat) and (StrToFloatDef(TASTLiteralExpr(Bin.Right).Value, 1.0) = 0.0))) then
      begin
        Error('E0301', 'Division by zero detected at compile time (comptime)', Bin.Line, Bin.Col);
      end;
    end;

    if SameText(Bin.Op, 'div') or SameText(Bin.Op, 'mod') then
    begin
      if not IsIntegerType(LeftType) or not IsIntegerType(RightType) then
        Error('E0369', Format('Operator "%s" requires integer operands, found: "%s" and "%s"', [Bin.Op, LeftType, RightType]), Bin.Line, Bin.Col);
      if LeftType = 'IntLiteral' then Exit('Int32')
      else Exit(LeftType);
    end;

    if (LeftType = 'Float64') or (RightType = 'Float64') or (LeftType = 'FloatLiteral') or (RightType = 'FloatLiteral') then
      Exit('Float64')
    else
      Exit(LeftType);
  end;

  // Relational operations: =, <>, <, <=, >, >=
  if (Bin.Op = '=') or (Bin.Op = '<>') or (Bin.Op = '<') or (Bin.Op = '<=') or (Bin.Op = '>') or (Bin.Op = '>=') then
  begin
    if not TypesAreCompatible(LeftType, RightType) and not TypesAreCompatible(RightType, LeftType) then
      Error('E0308', Format('Comparison between incompatible types: "%s" and "%s"', [LeftType, RightType]), Bin.Line, Bin.Col);
    Exit('Bool');
  end;

  // Bit-shift operations: shl, shr
  if SameText(Bin.Op, 'shl') or SameText(Bin.Op, 'shr') then
  begin
    if not IsIntegerType(LeftType) then
      Error('E0369', Format('Left operand of "%s" must be integer, found: "%s"', [Bin.Op, LeftType]), Bin.Line, Bin.Col);
    if not IsIntegerType(RightType) then
      Error('E0369', Format('Right operand of "%s" must be integer, found: "%s"', [Bin.Op, RightType]), Bin.Line, Bin.Col);
    if LeftType = 'IntLiteral' then Exit('Int32')
    else Exit(LeftType);
  end;

  // Logical and bitwise operations: and, or, xor, implies
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
      Error('E0308', Format('Operand of "%s" must be Bool, found: "%s"', [Bin.Op, LeftType]), Bin.Line, Bin.Col);
    if (RightType <> 'Bool') then
      Error('E0308', Format('Operand of "%s" must be Bool, found: "%s"', [Bin.Op, RightType]), Bin.Line, Bin.Col);
    Exit('Bool');
  end;

  // Set membership operator: in
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
      Error('E0572', 'Propagation operator "?" / "try" can only be used inside a function', Un.Line, Un.Col);
    OperandType := NormalizeTypeName(ResolveAliasType(CheckExpr(Un.Expr)));
    FuncRet := NormalizeTypeName(ResolveAliasType(FCurrentFunction.ReturnType));
    if Pos('Result<', OperandType) = 1 then
    begin
      SplitResultTypes(OperandType, ValType, ErrType);
      if Pos('Result<', FuncRet) <> 1 then
        Error('E0308', Format('Operator "?" on "%s" requires function "%s" to return Result, but it returns "%s"',
          [OperandType, FCurrentFunction.Name, FCurrentFunction.ReturnType]), Un.Line, Un.Col);
      SplitResultTypes(FuncRet, FuncValType, FuncErrType);
      if not TypesAreCompatible(FuncErrType, ErrType) then
        Error('E0308', Format('Error type "%s" in "?" is incompatible with error "%s" in return type of "%s"',
          [ErrType, FuncErrType, FCurrentFunction.Name]), Un.Line, Un.Col);
      Exit(NormalizeTypeName(ValType));
    end
    else if Pos('Option<', OperandType) = 1 then
    begin
      ValType := Trim(Copy(OperandType, 8, Length(OperandType) - 8));
      if Pos('Option<', FuncRet) <> 1 then
        Error('E0308', Format('Operator "?" on "%s" requires function "%s" to return Option, but it returns "%s"',
          [OperandType, FCurrentFunction.Name, FCurrentFunction.ReturnType]), Un.Line, Un.Col);
      Exit(NormalizeTypeName(ValType));
    end
    else
      Error('E0308', Format('Operator "?" / "try" requires a Result<T, E> or Option<T> expression, got "%s"', [OperandType]), Un.Line, Un.Col);
  end;

  if Un.Op = '@' then
  begin
    OperandType := CheckExpr(Un.Expr);
    Exit('^' + OperandType);
  end
  else if Un.Op = '^' then
  begin
    if FUnsafeDepth <= 0 then
      Error('E0312', 'Raw pointer dereference ("^") requires an "unsafe ... end unsafe;" block', Un.Line, Un.Col);
    OperandType := ResolveAliasType(CheckExpr(Un.Expr));
    if Pos('^', OperandType) = 1 then
      Exit(Copy(OperandType, 2, Length(OperandType)));
    Error('E0308', Format('Cannot dereference non-pointer type: "%s"', [OperandType]), Un.Line, Un.Col);
  end;

  OperandType := CheckExpr(Un.Expr);
  if Un.Op = '-' then
  begin
    if not IsNumericType(OperandType) and (OperandType <> 'IntLiteral') and (OperandType <> 'FloatLiteral') then
      Error('E0369', Format('Unary "-" operator requires numeric type, found: "%s"', [OperandType]), Un.Line, Un.Col);
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
      Error('E0308', Format('Operator "not" requires Bool or integer type, found: "%s"', [OperandType]), Un.Line, Un.Col);
    Exit('Bool');
  end;
  Result := OperandType;
end;

function TAetherTypeChecker.CheckAwait(AwaitExpr: TASTAwaitExpr): string;
var
  InnerType: string;
begin
  InnerType := ResolveAliasType(CheckExpr(AwaitExpr.Expr));
  if (Copy(InnerType, 1, 5) <> 'Task<') or (InnerType[Length(InnerType)] <> '>') then
    Error('E0308', Format('Cannot await non-Task type "%s"', [InnerType]), AwaitExpr.Line, AwaitExpr.Col);
  Result := NormalizeTypeName(Copy(InnerType, 6, Length(InnerType) - 6));
  if Result = '' then Result := 'Void';
  AwaitExpr.ResolvedInnerType := Result;
end;

procedure TAetherTypeChecker.CollectSpawnCaptures(SpawnExpr: TASTSpawnExpr);
  procedure TryCapture(const IdName: string; IsRef: Boolean);
  var
    Sym: TSymbol;
    CType: string;
    Idx: Integer;
  begin
    if (IdName = '') or SameText(IdName, 'None') or SameText(IdName, 'result') then Exit;
    if not Assigned(FSymbols) then Exit;
    Sym := FSymbols.Resolve(IdName);
    if Assigned(Sym) and (Sym.Kind = skVariable) then
    begin
      if Assigned(FSymbols.GlobalScope.ResolveLocal(Sym.Name)) then
        Exit; // module variable is globally accessible
      Idx := SpawnExpr.CaptureNames.IndexOf(Sym.Name);
      if Idx < 0 then
      begin
        CType := NormalizeTypeName(Sym.TypeName);
        SpawnExpr.CaptureNames.Add(Sym.Name);
        SpawnExpr.CaptureTypes.Add(CType);
        if IsRef then
          SpawnExpr.CaptureByRef.Add('1')
        else
          SpawnExpr.CaptureByRef.Add('0');
      end
      else if IsRef then
        SpawnExpr.CaptureByRef[Idx] := '1';
    end;
  end;

  procedure WalkExpr(E: TASTExpr);
  var
    I: Integer;
    C: TASTCallExpr;
    Arg: TASTCallArg;
    FuncSym: TSymbol;
    ArgIsMut: Boolean;
    ME: TASTMatchExpr;
  begin
    if not Assigned(E) then Exit;
    if E is TASTIdentifierExpr then
      TryCapture(TASTIdentifierExpr(E).Name, False)
    else if E is TASTMemberAccessExpr then
      WalkExpr(TASTMemberAccessExpr(E).Target)
    else if E is TASTBinaryExpr then
    begin
      WalkExpr(TASTBinaryExpr(E).Left);
      WalkExpr(TASTBinaryExpr(E).Right);
    end
    else if E is TASTUnaryExpr then
      WalkExpr(TASTUnaryExpr(E).Expr)
    else if E is TASTAwaitExpr then
      WalkExpr(TASTAwaitExpr(E).Expr)
    else if E is TASTSpawnExpr then
      WalkExpr(TASTSpawnExpr(E).CallExpr)
    else if E is TASTCallExpr then
    begin
      C := TASTCallExpr(E);
      if Assigned(C.CalleeExpr) then
        WalkExpr(C.CalleeExpr)
      else if C.IsIndirectCall and (C.Callee <> '') then
        TryCapture(C.Callee, False);
      FuncSym := nil;
      if (C.Callee <> '') and Assigned(FSymbols) then
        FuncSym := FSymbols.Resolve(C.Callee);
      for I := 0 to C.Args.Count - 1 do
      begin
        Arg := TASTCallArg(C.Args[I]);
        ArgIsMut := (Arg.Ownership = owMutBorrow);
        if (not ArgIsMut) and Assigned(FuncSym) and (FuncSym.Kind = skFunction) and
           Assigned(FuncSym.Node) and (FuncSym.Node is TASTFunction) and
           (I < TASTFunction(FuncSym.Node).Params.Count) and
           (TASTParam(TASTFunction(FuncSym.Node).Params[I]).Ownership = owMutBorrow) then
          ArgIsMut := True;
        if ArgIsMut and (Arg.Expr is TASTIdentifierExpr) then
          TryCapture(TASTIdentifierExpr(Arg.Expr).Name, True)
        else
          WalkExpr(Arg.Expr);
      end;
    end
    else if E is TASTIndexExpr then
    begin
      WalkExpr(TASTIndexExpr(E).Target);
      for I := 0 to TASTIndexExpr(E).Indices.Count - 1 do
        WalkExpr(TASTExpr(TASTIndexExpr(E).Indices[I]));
    end
    else if E is TASTSetLiteralExpr then
      for I := 0 to TASTSetLiteralExpr(E).Elements.Count - 1 do
        WalkExpr(TASTExpr(TASTSetLiteralExpr(E).Elements[I]))
    else if E is TASTMapLiteralExpr then
      for I := 0 to TASTMapLiteralExpr(E).Keys.Count - 1 do
      begin
        WalkExpr(TASTExpr(TASTMapLiteralExpr(E).Keys[I]));
        WalkExpr(TASTExpr(TASTMapLiteralExpr(E).Values[I]));
      end
    else if E is TASTTupleLiteralExpr then
      for I := 0 to TASTTupleLiteralExpr(E).Elements.Count - 1 do
        WalkExpr(TASTExpr(TASTTupleLiteralExpr(E).Elements[I]))
    else if E is TASTLambdaExpr then
    begin
      for I := 0 to TASTLambdaExpr(E).CaptureNames.Count - 1 do
        TryCapture(TASTLambdaExpr(E).CaptureNames[I], False);
    end
    else if E is TASTIfExpr then
    begin
      WalkExpr(TASTIfExpr(E).Condition);
      WalkExpr(TASTIfExpr(E).ThenExpr);
      WalkExpr(TASTIfExpr(E).ElseExpr);
    end
    else if E is TASTMatchExpr then
    begin
      ME := TASTMatchExpr(E);
      WalkExpr(ME.Expr);
      for I := 0 to ME.Cases.Count - 1 do
      begin
        WalkExpr(TASTMatchCase(ME.Cases[I]).Guard);
        WalkExpr(TASTMatchCase(ME.Cases[I]).ValueExpr);
      end;
    end;
  end;
begin
  SpawnExpr.CaptureNames.Clear;
  SpawnExpr.CaptureTypes.Clear;
  SpawnExpr.CaptureByRef.Clear;
  WalkExpr(SpawnExpr.CallExpr);
end;

function TAetherTypeChecker.CheckSpawn(SpawnExpr: TASTSpawnExpr): string;
var
  CallType, InnerT: string;
begin
  CallType := NormalizeTypeName(CheckExpr(SpawnExpr.CallExpr));
  if (Copy(CallType, 1, 5) = 'Task<') and (CallType[Length(CallType)] = '>') then
    InnerT := NormalizeTypeName(Copy(CallType, 6, Length(CallType) - 6))
  else
    InnerT := CallType;
  if InnerT = 'IntLiteral' then InnerT := 'Int32'
  else if InnerT = 'FloatLiteral' then InnerT := 'Float64'
  else if InnerT = '' then InnerT := 'Void';

  if SpawnExpr.SpawnId = 0 then
  begin
    Inc(FSpawnCounter);
    SpawnExpr.SpawnId := FSpawnCounter;
  end;
  SpawnExpr.InnerReturnType := InnerT;
  SpawnExpr.ResolvedTaskType := 'Task<' + InnerT + '>';
  CollectSpawnCaptures(SpawnExpr);
  Result := SpawnExpr.ResolvedTaskType;
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
  else if FCurrentSourceModule <> '' then
    CurMod := FCurrentSourceModule
  else if Assigned(FModule) then
    CurMod := FModule.Name;

  if (CurMod <> '') and (not MatchesModuleName(CurMod, ASrcMod)) then
    Error('E0603', Format('Private symbol "%s" from module "%s" is not accessible outside it (mark as "pub")',
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
  FuncNode, MonoFunc, SavedCurFunc: TASTFunction;
  RecDecl: TASTRecordDecl;
  EnumDecl: TASTEnumDecl;
  VariantNode: TASTEnumVariant;
  SubSym: TSymbol;
  I, K, G: Integer;
  Arg: TASTCallArg;
  HasNamed, HasPositional, FoundField: Boolean;
  ArgType, ExpectedType, Mangled, MonomorphedName, ElemType, KeyType, ValType: string;
  T1, T2, T3, NormArg, FieldNameTarget, FnRet, CalleeT, ChanBase, ChanElem: string;
  ConcreteArgs, Inferred, FnParams, ChanArgs: TStringList;
  RecExpr: TASTExpr;
begin
  if Assigned(Call.CalleeExpr) then
  begin
    CalleeT := NormalizeTypeName(ResolveAliasType(CheckExpr(Call.CalleeExpr)));
    FnParams := TStringList.Create;
    try
      if not SplitFnType(CalleeT, FnParams, FnRet) then
        Error('E0618', Format('Expression of type "%s" is not callable', [CalleeT]), Call.Line, Call.Col);
      if Call.Args.Count <> FnParams.Count then
        Error('E0061', Format('Callable of type "%s" expects %d arguments, but got %d',
          [CalleeT, FnParams.Count, Call.Args.Count]), Call.Line, Call.Col);
      for I := 0 to Call.Args.Count - 1 do
      begin
        Arg := TASTCallArg(Call.Args[I]);
        ExpectedType := NormalizeTypeName(FnParams[I]);
        AnnotateMonadExpr(Arg.Expr, ExpectedType);
        ArgType := CheckExpr(Arg.Expr);
        if not TypesAreCompatible(ExpectedType, ArgType) then
          Error('E0308', Format('Argument %d expects "%s", but got "%s"',
            [I + 1, ExpectedType, ArgType]), Arg.Line, Arg.Col);
      end;
      Call.IsIndirectCall := True;
      Call.IndirectFnType := CalleeT;
      Exit(FnRet);
    finally
      FnParams.Free;
    end;
  end;
  if Call.Callee = '__InterpToStr' then
  begin
    if Call.Args.Count <> 1 then
      Error('E0061', 'String interpolation expects 1 expression per "{...}" block', Call.Line, Call.Col);
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
      Error('E0061', 'Function "CharToStr" expects 1 argument (Char)', Call.Line, Call.Col);
    CheckExpr(TASTCallArg(Call.Args[0]).Expr);
    Exit('String');
  end;

  // Built-in Ok() and Err() shortcuts
  if Call.Callee = 'Ok' then
  begin
    if Call.Args.Count <> 1 then
      Error('E0061', 'Ok() requires exactly 1 argument', Call.Line, Call.Col);
    ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
    Exit('Result<' + ArgType + ', GenericError>');
  end;

  if Call.Callee = 'Err' then
  begin
    if Call.Args.Count <> 1 then
      Error('E0061', 'Err() requires exactly 1 argument', Call.Line, Call.Col);
    ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
    Exit('Result<GenericValue, ' + ArgType + '>');
  end;

  if Call.Callee = 'Some' then
  begin
    if Call.Args.Count <> 1 then
      Error('E0061', 'Some() requires exactly 1 argument', Call.Line, Call.Col);
    ArgType := NormalizeTypeName(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
    NormArg := ArgType;
    if NormArg = 'IntLiteral' then NormArg := 'Int32'
    else if NormArg = 'FloatLiteral' then NormArg := 'Float64';
    Call.ResolvedMonadType := 'Option<' + NormArg + '>';
    Exit('Option<' + ArgType + '>');
  end;

  if Call.Callee = 'Box' then
  begin
    if Call.Args.Count <> 1 then
      Error('E0061', 'Box() requires exactly 1 argument', Call.Line, Call.Col);
    ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
    Exit('Box<' + ArgType + '>');
  end;

  if (Call.Callee = '__JsonGetStr') or (Call.Callee = '__JsonGetInt') or
     (Call.Callee = '__JsonGetFloat') or (Call.Callee = '__JsonGetBool') or
     (Call.Callee = '__JsonGetChar') or (Call.Callee = '__JsonHasValue') or
     (Call.Callee = '__JsonGetObj') then
  begin
    if Call.Args.Count <> 2 then
      Error('E0061', Format('Function "%s" expects 2 arguments (json, key)', [Call.Callee]), Call.Line, Call.Col);
    CheckExpr(TASTCallArg(Call.Args[0]).Expr);
    CheckExpr(TASTCallArg(Call.Args[1]).Expr);
    if Call.Callee = '__JsonGetInt' then Exit('Int32')
    else if Call.Callee = '__JsonGetFloat' then Exit('Float64')
    else if (Call.Callee = '__JsonGetBool') or (Call.Callee = '__JsonHasValue') then Exit('Bool')
    else if Call.Callee = '__JsonGetChar' then Exit('Char')
    else Exit('String');
  end;

  if (Pos('.', Call.Callee) > 0) then
  begin
    T1 := Copy(Call.Callee, 1, Pos('.', Call.Callee) - 1);
    T2 := Copy(Call.Callee, Pos('.', Call.Callee) + 1, Length(Call.Callee));
    TypeSym := FSymbols.ResolveTypeSymbol(T1);
    if Assigned(TypeSym) and (TypeSym.Kind = skType) and (TypeSym.Node is TASTEnumDecl) then
    begin
      EnumDecl := TASTEnumDecl(TypeSym.Node);
      VariantNode := nil;
      for I := 0 to EnumDecl.Variants.Count - 1 do
        if SameText(TASTEnumVariant(EnumDecl.Variants[I]).Name, T2) then
        begin
          VariantNode := TASTEnumVariant(EnumDecl.Variants[I]);
          Break;
        end;
      if Assigned(VariantNode) then
      begin
        ReorderAndCheckFields('Enum variant', Call.Callee, VariantNode.Fields, Call);
        Exit(EnumDecl.Name);
      end;
    end;
  end;

  // Qualified resolution via Alias/Module (e.g., math.Sin(x), hmod.Type.New(x)) or Associated Method (e.g., Point.New(x, y))
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
          Error('E0425', Format('Function or type "%s" not found in module "%s"', [Call.Callee, T1]), Call.Line, Call.Col);
        CheckVisibility(Sym.IsPublic, Sym.SourceModule, Sym.Name, Call.Line, Call.Col);
      end
      else
      begin
        TypeSym := FSymbols.Resolve(T1);
        if Assigned(TypeSym) and (TypeSym.Kind = skType) then
        begin
          CheckVisibility(TypeSym.IsPublic, TypeSym.SourceModule, TypeSym.Name, Call.Line, Call.Col);
          if TypeSym.Node is TASTEnumDecl then
          begin
            EnumDecl := TASTEnumDecl(TypeSym.Node);
            VariantNode := nil;
            for I := 0 to EnumDecl.Variants.Count - 1 do
              if SameText(TASTEnumVariant(EnumDecl.Variants[I]).Name, Call.Callee) then
              begin
                VariantNode := TASTEnumVariant(EnumDecl.Variants[I]);
                Break;
              end;
            if not Assigned(VariantNode) then
              Error('E0599', Format('Variant "%s" does not belong to enum "%s"', [Call.Callee, EnumDecl.Name]), Call.Line, Call.Col);
            Call.Args.Delete(0);
            Call.IsQualified := False;
            Call.Callee := EnumDecl.Name + '.' + VariantNode.Name;
            ReorderAndCheckFields('Enum variant', Call.Callee, VariantNode.Fields, Call);
            Exit(EnumDecl.Name);
          end;
          Mangled := FindTraitMethod(T1, Call.Callee);
          if Mangled <> '' then
          begin
            Call.Args.Delete(0);
            Call.Callee := Mangled;
          end
          else
            Error('E0425', Format('Associated method "%s" not found for type "%s"', [Call.Callee, T1]), Call.Line, Call.Col);
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
        Error('E0425', Format('Type "%s" not found in module "%s"',
          [T1, TASTIdentifierExpr(TASTMemberAccessExpr(TASTCallArg(Call.Args[0]).Expr).Target).Name]), Call.Line, Call.Col);
      CheckVisibility(TypeSym.IsPublic, TypeSym.SourceModule, TypeSym.Name, Call.Line, Call.Col);
      if TypeSym.Node is TASTEnumDecl then
      begin
        EnumDecl := TASTEnumDecl(TypeSym.Node);
        VariantNode := nil;
        for I := 0 to EnumDecl.Variants.Count - 1 do
          if SameText(TASTEnumVariant(EnumDecl.Variants[I]).Name, Call.Callee) then
          begin
            VariantNode := TASTEnumVariant(EnumDecl.Variants[I]);
            Break;
          end;
        if not Assigned(VariantNode) then
          Error('E0599', Format('Variant "%s" does not belong to enum "%s"', [Call.Callee, EnumDecl.Name]), Call.Line, Call.Col);
        Call.Args.Delete(0);
        Call.IsQualified := False;
        Call.Callee := EnumDecl.Name + '.' + VariantNode.Name;
        ReorderAndCheckFields('Enum variant', Call.Callee, VariantNode.Fields, Call);
        Exit(EnumDecl.Name);
      end;
      Mangled := FindTraitMethod(T1, Call.Callee);
      if Mangled <> '' then
      begin
        Call.Args.Delete(0);
        Call.Callee := Mangled;
      end
      else
        Error('E0425', Format('Associated method "%s" not found for type "%s"', [Call.Callee, T1]), Call.Line, Call.Col);
    end;
  end;

  // Record field callback via UFCS syntax: obj.cb(arg)
  if Call.IsQualified and (Call.Args.Count >= 1) then
  begin
    RecExpr := TASTCallArg(Call.Args[0]).Expr;
    if not ((RecExpr is TASTIdentifierExpr) and
            Assigned(FSymbols.Resolve(TASTIdentifierExpr(RecExpr).Name)) and
            (FSymbols.Resolve(TASTIdentifierExpr(RecExpr).Name).Kind = skType)) then
    begin
      ArgType := NormalizeTypeName(ResolveAliasType(CheckExpr(RecExpr)));
      TypeSym := FSymbols.ResolveTypeSymbol(ArgType);
      if Assigned(TypeSym) and (TypeSym.Node is TASTRecordDecl) then
      begin
        RecDecl := TASTRecordDecl(TypeSym.Node);
        for I := 0 to RecDecl.Fields.Count - 1 do
        begin
          if SameText(TASTRecordField(RecDecl.Fields[I]).Name, Call.Callee) then
          begin
            CalleeT := NormalizeTypeName(ResolveAliasType(TASTRecordField(RecDecl.Fields[I]).TypeName));
            FnParams := TStringList.Create;
            try
              if SplitFnType(CalleeT, FnParams, FnRet) then
              begin
                CheckVisibility(TASTRecordField(RecDecl.Fields[I]).IsPublic, RecDecl.SourceModule, RecDecl.Name + '.' + Call.Callee, Call.Line, Call.Col);
                TASTCallArg(Call.Args[0]).Expr := nil;
                Call.Args.Delete(0);
                Call.IsQualified := False;
                Call.CalleeExpr := TASTMemberAccessExpr.Create(Call.Line, Call.Col, RecExpr, Call.Callee);
                Call.Callee := '';
                if Call.Args.Count <> FnParams.Count then
                  Error('E0061', Format('Callback "%s" expects %d arguments, but got %d',
                    [TASTRecordField(RecDecl.Fields[I]).Name, FnParams.Count, Call.Args.Count]), Call.Line, Call.Col);
                for K := 0 to Call.Args.Count - 1 do
                begin
                  Arg := TASTCallArg(Call.Args[K]);
                  ExpectedType := NormalizeTypeName(FnParams[K]);
                  AnnotateMonadExpr(Arg.Expr, ExpectedType);
                  T3 := CheckExpr(Arg.Expr);
                  if not TypesAreCompatible(ExpectedType, T3) then
                    Error('E0308', Format('Argument %d expects "%s", but got "%s"',
                      [K + 1, ExpectedType, T3]), Arg.Line, Arg.Col);
                end;
                Call.IsIndirectCall := True;
                Call.IndirectFnType := CalleeT;
                Exit(FnRet);
              end;
            finally
              FnParams.Free;
            end;
          end;
        end;
      end;
    end;
  end;

  Sym := FSymbols.Resolve(Call.Callee);
  if Assigned(Sym) and (Sym.Kind = skVariable) then
  begin
    CalleeT := NormalizeTypeName(ResolveAliasType(Sym.TypeName));
    FnParams := TStringList.Create;
    try
      if SplitFnType(CalleeT, FnParams, FnRet) then
      begin
        if Call.Args.Count <> FnParams.Count then
          Error('E0061', Format('Callable "%s" expects %d arguments, but got %d',
            [Call.Callee, FnParams.Count, Call.Args.Count]), Call.Line, Call.Col);
        for I := 0 to Call.Args.Count - 1 do
        begin
          Arg := TASTCallArg(Call.Args[I]);
          ExpectedType := NormalizeTypeName(FnParams[I]);
          AnnotateMonadExpr(Arg.Expr, ExpectedType);
          ArgType := CheckExpr(Arg.Expr);
          if not TypesAreCompatible(ExpectedType, ArgType) then
            Error('E0308', Format('Argument %d of callable "%s" expects "%s", but got "%s"',
              [I + 1, Call.Callee, ExpectedType, ArgType]), Arg.Line, Arg.Col);
        end;
        Call.IsIndirectCall := True;
        Call.IndirectFnType := CalleeT;
        Exit(FnRet);
      end;
    finally
      FnParams.Free;
    end;
  end;

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
    // Trait method resolution via first argument (UFCS)
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
      // Transparent Interoperability:
      // If Pascal units (import pascal) or C headers (import c) are imported,
      // and the function is not local, allow direct invocation without manual extern!
      if HasForeignImports then
      begin
        for I := 0 to Call.Args.Count - 1 do
          CheckExpr(TASTCallArg(Call.Args[I]).Expr);
        Exit(InferForeignFunctionReturnType(Call.Callee));
      end;

      Error('E0425', Format('Function or type not found: "%s"', [Call.Callee]), Call.Line, Call.Col);
    end;
  end;

  CheckVisibility(Sym.IsPublic, Sym.SourceModule, Sym.Name, Call.Line, Call.Col);

  // Unqualified Enum Variant Constructor: Circle(5.0), Rect(width: 3.0, height: 4.0)
  if (Sym.Kind = skEnumVariant) and (Sym.Node is TASTEnumVariant) then
  begin
    VariantNode := TASTEnumVariant(Sym.Node);
    Call.Callee := Sym.TypeName + '.' + VariantNode.Name;
    ReorderAndCheckFields('Enum variant', Call.Callee, VariantNode.Fields, Call);
    Exit(Sym.TypeName);
  end;

  // Record Constructor: DataBuffer(id: 101, size: 2048), Pair<Int32, String>(1, "a"), or Pair(1, "a")
  if (Sym.Kind = skType) and (Sym.Node is TASTRecordDecl) then
  begin
    RecDecl := TASTRecordDecl(Sym.Node);
    if Call.GenericArgs.Count > 0 then
    begin
      if RecDecl.GenericParams.Count = 0 then
        Error('E0107', Format('Record "%s" does not take generic type arguments', [RecDecl.Name]), Call.Line, Call.Col);
      Mangled := InstantiateGenericRecord(RecDecl, Call.GenericArgs, Call.Line, Call.Col);
      TypeSym := FSymbols.ResolveTypeSymbol(Mangled);
      RecDecl := TASTRecordDecl(TypeSym.Node);
      Call.Callee := Mangled;
    end
    else if RecDecl.GenericParams.Count > 0 then
    begin
      HasNamed := False;
      HasPositional := False;
      for I := 0 to Call.Args.Count - 1 do
        if TASTCallArg(Call.Args[I]).FieldName <> '' then HasNamed := True
        else HasPositional := True;
      if HasNamed and HasPositional then
        Error('E0061', Format('Record "%s" constructor cannot mix positional and named arguments', [RecDecl.Name]), Call.Line, Call.Col);
      if Call.Args.Count <> RecDecl.Fields.Count then
        Error('E0061', Format('Record "%s" constructor expects %d fields, but got %d',
          [RecDecl.Name, RecDecl.Fields.Count, Call.Args.Count]), Call.Line, Call.Col);

      Inferred := TStringList.Create;
      try
        for G := 0 to RecDecl.GenericParams.Count - 1 do
          Inferred.Add('');
        for I := 0 to Call.Args.Count - 1 do
        begin
          Arg := TASTCallArg(Call.Args[I]);
          ArgType := CheckExpr(Arg.Expr);
          if HasNamed then
          begin
            FieldNameTarget := Arg.FieldName;
            FoundField := False;
            for K := 0 to RecDecl.Fields.Count - 1 do
              if SameText(TASTRecordField(RecDecl.Fields[K]).Name, FieldNameTarget) then
              begin
                UnifyGenericTypes(TASTRecordField(RecDecl.Fields[K]).TypeName, ArgType, RecDecl.GenericParams, Inferred);
                FoundField := True;
                Break;
              end;
            if not FoundField then
              Error('E0609', Format('Record "%s" has no field named "%s"', [RecDecl.Name, FieldNameTarget]), Arg.Line, Arg.Col);
          end
          else
            UnifyGenericTypes(TASTRecordField(RecDecl.Fields[I]).TypeName, ArgType, RecDecl.GenericParams, Inferred);
        end;
        for G := 0 to RecDecl.GenericParams.Count - 1 do
        begin
          if Inferred[G] = '' then
            Error('E0282', Format('Cannot infer generic type parameter "%s" for record "%s"; specify "<...>" explicitly',
              [RecDecl.GenericParams[G], RecDecl.Name]), Call.Line, Call.Col);
          if Inferred[G] = 'IntLiteral' then Inferred[G] := 'Int32'
          else if Inferred[G] = 'FloatLiteral' then Inferred[G] := 'Float64'
          else Inferred[G] := NormalizeTypeName(Inferred[G]);
        end;
        Mangled := InstantiateGenericRecord(RecDecl, Inferred, Call.Line, Call.Col);
        TypeSym := FSymbols.ResolveTypeSymbol(Mangled);
        RecDecl := TASTRecordDecl(TypeSym.Node);
        Call.Callee := Mangled;
      finally
        Inferred.Free;
      end;
    end;

    ReorderAndCheckFields('Record', RecDecl.Name, RecDecl.Fields, Call);
    Exit(RecDecl.Name);
  end;

  // Explicit primitive type cast (Int32(x), UInt32(x), Float64(x), etc.)
  if (Sym.Kind = skType) and (not Assigned(Sym.Node) or not (Sym.Node is TASTRecordDecl)) then
  begin
    if Call.Args.Count <> 1 then
      Error('E0061', Format('Type cast "%s" expects exactly 1 argument', [Call.Callee]), Call.Line, Call.Col);
    if Call.Args.Count > 0 then
      CheckExpr(TASTCallArg(Call.Args[0]).Expr);
    Exit(Call.Callee);
  end;

  // Normal or Generic Function Call
  if Sym.Kind = skFunction then
  begin
    FuncNode := TASTFunction(Sym.Node);

    // If generic function (<T> or <T, U: Trait>), resolve/infer arguments and monomorphize
    if Assigned(FuncNode) and ((FuncNode.GenericParams.Count > 0) or (FuncNode.GenericParam <> '')) then
    begin
      if FuncNode.GenericParams.Count = 0 then
      begin
        FuncNode.GenericParams.Add(FuncNode.GenericParam);
        FuncNode.TraitBounds.Add(FuncNode.TraitBound);
      end;

      ConcreteArgs := TStringList.Create;
      try
        if Call.GenericArgs.Count > 0 then
        begin
          if Call.GenericArgs.Count <> FuncNode.GenericParams.Count then
            Error('E0061', Format('Generic function "%s" expects %d type argument(s), but got %d',
              [FuncNode.Name, FuncNode.GenericParams.Count, Call.GenericArgs.Count]), Call.Line, Call.Col);
          for G := 0 to Call.GenericArgs.Count - 1 do
            ConcreteArgs.Add(NormalizeTypeName(Call.GenericArgs[G]));
        end
        else
        begin
          if Call.Args.Count <> FuncNode.Params.Count then
            Error('E0061', Format('Generic function "%s" expects %d arguments, but got %d',
              [FuncNode.Name, FuncNode.Params.Count, Call.Args.Count]), Call.Line, Call.Col);
          for G := 0 to FuncNode.GenericParams.Count - 1 do
            ConcreteArgs.Add('');
          for I := 0 to Call.Args.Count - 1 do
          begin
            ArgType := CheckExpr(TASTCallArg(Call.Args[I]).Expr);
            ExpectedType := TASTParam(FuncNode.Params[I]).TypeName;
            // Preserve Box<Record> unwrapping for single-param trait-bounded generics
            if (FuncNode.GenericParams.Count = 1) and (FuncNode.TraitBounds.Count > 0) and
               (FuncNode.TraitBounds[0] <> '') and SameText(ExpectedType, FuncNode.GenericParams[0]) and
               (Pos('Box<', ArgType) = 1) then
              ArgType := Trim(Copy(ArgType, 5, Length(ArgType) - 5));
            UnifyGenericTypes(ExpectedType, ArgType, FuncNode.GenericParams, ConcreteArgs);
          end;
          for G := 0 to FuncNode.GenericParams.Count - 1 do
          begin
            if ConcreteArgs[G] = '' then
              Error('E0282', Format('Cannot infer type parameter "%s" for generic function "%s"',
                [FuncNode.GenericParams[G], FuncNode.Name]), Call.Line, Call.Col);
            if ConcreteArgs[G] = 'IntLiteral' then ConcreteArgs[G] := 'Int32'
            else if ConcreteArgs[G] = 'FloatLiteral' then ConcreteArgs[G] := 'Float64'
            else ConcreteArgs[G] := NormalizeTypeName(ConcreteArgs[G]);
          end;
        end;

        for G := 0 to FuncNode.GenericParams.Count - 1 do
        begin
          if (G < FuncNode.TraitBounds.Count) and (FuncNode.TraitBounds[G] <> '') then
          begin
            if not TypeImplementsTrait(ConcreteArgs[G], FuncNode.TraitBounds[G]) then
              Error('E0277', Format('Type "%s" does not implement trait "%s"',
                [ConcreteArgs[G], FuncNode.TraitBounds[G]]), Call.Line, Call.Col);
          end;
        end;

        if ConcreteArgs.Count = 1 then
          MonomorphedName := FuncNode.Name + '_' + MangleTypeName(ConcreteArgs[0])
        else
        begin
          MonomorphedName := FuncNode.Name;
          for G := 0 to ConcreteArgs.Count - 1 do
            MonomorphedName := MonomorphedName + '__' + MangleTypeName(ConcreteArgs[G]);
        end;

        SymMono := FSymbols.GlobalScope.Resolve(MonomorphedName);
        if not Assigned(SymMono) then
          SymMono := FSymbols.Resolve(MonomorphedName);
        if not Assigned(SymMono) then
        begin
          MonoFunc := MonomorphizeFunction(FuncNode, ConcreteArgs);
          MonoFunc.Name := MonomorphedName;
          FModule.Functions.Add(MonoFunc);
          SymMono := TSymbol.Create(MonoFunc.Name, skFunction, MonoFunc.ReturnType, MonoFunc.Line, MonoFunc.Col, False, owNone, MonoFunc);
          SymMono.IsPublic := MonoFunc.IsPublic;
          SymMono.SourceModule := MonoFunc.SourceModule;
          FSymbols.GlobalScope.Define(SymMono);
          SavedCurFunc := FCurrentFunction;
          try
            CheckFunction(MonoFunc);
          finally
            FCurrentFunction := SavedCurFunc;
          end;
        end;

        Call.Callee := MonomorphedName;
        Sym := SymMono;
        FuncNode := TASTFunction(Sym.Node);
      finally
        ConcreteArgs.Free;
      end;
    end;

    // Built-in PrintLn with variadic parameters
    if (Call.Callee = 'PrintLn') or (Call.Callee = 'Print') then
    begin
      for I := 0 to Call.Args.Count - 1 do
        CheckExpr(TASTCallArg(Call.Args[I]).Expr);
      Exit('Void');
    end;

    if SameText(Call.Callee, 'Length') or SameText(Call.Callee, 'Count') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', Format('Function "%s" expects 1 argument (String, Array, or Map)', [Call.Callee]), Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if (ArgType = 'String') and SameText(Call.Callee, 'Length') then
        Exit('UInt32')
      else if IsDynamicArrayType(ArgType, ElemType) or IsMapType(ArgType, KeyType, ValType) or (Pos('array[', ArgType) = 1) or
              (Assigned(FSymbols.Resolve(ArgType)) and (FSymbols.Resolve(ArgType).Node is TASTArrayDecl)) then
        Exit('Int32')
      else
        Error('E0308', Format('Function "%s" expects String, Array, or Map, got: "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
    end;

    if SameText(Call.Callee, 'Default') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "Default" expects 1 argument (TypeName)', Call.Line, Call.Col);
      if not (TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr) then
        Error('E0308', 'Argument to "Default" must be a valid type name', Call.Line, Call.Col);
      ExpectedType := TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name;
      if not FSymbols.ResolveType(ExpectedType) then
        Error('E0412', Format('Unknown type in "Default": "%s"', [ExpectedType]), Call.Line, Call.Col);
      Exit(ExpectedType);
    end;

    if SameText(Call.Callee, 'Trim') or SameText(Call.Callee, 'UpperCase') or SameText(Call.Callee, 'LowerCase') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', Format('Function "%s" expects 1 argument (String)', [Call.Callee]), Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if ArgType <> 'String' then
        Error('E0308', Format('Argument to "%s" must be String, got: "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      Exit('String');
    end;

    if SameText(Call.Callee, 'StartsWith') or SameText(Call.Callee, 'EndsWith') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', Format('Function "%s" expects 2 arguments (String, String)', [Call.Callee]), Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if ArgType <> 'String' then
        Error('E0308', Format('First argument to "%s" must be String, got: "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[1]).Expr));
      if ArgType <> 'String' then
        Error('E0308', Format('Second argument to "%s" must be String, got: "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      Exit('Bool');
    end;

    if SameText(Call.Callee, 'IndexOf') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Function "IndexOf" expects 2 arguments (String, Substring)', Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if ArgType <> 'String' then
        Error('E0308', Format('First argument to "IndexOf" must be String, got: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[1]).Expr));
      if ArgType <> 'String' then
        Error('E0308', Format('Second argument to "IndexOf" must be String, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Int32');
    end;

    if SameText(Call.Callee, 'Replace') then
    begin
      if Call.Args.Count <> 3 then
        Error('E0061', 'Function "Replace" expects 3 arguments (String, Old, New)', Call.Line, Call.Col);
      for K := 0 to 2 do
      begin
        ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[K]).Expr));
        if ArgType <> 'String' then
          Error('E0308', Format('Argument %d to "Replace" must be String, got: "%s"', [K + 1, ArgType]), Call.Line, Call.Col);
      end;
      Exit('String');
    end;

    if SameText(Call.Callee, 'Split') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Function "Split" expects 2 arguments (String, Separator)', Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if ArgType <> 'String' then
        Error('E0308', Format('First argument to "Split" must be String, got: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[1]).Expr));
      if ArgType <> 'String' then
        Error('E0308', Format('Second argument to "Split" must be String, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('array of String');
    end;

    if SameText(Call.Callee, 'Join') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Function "Join" expects 2 arguments (String Array, Separator)', Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if (not IsDynamicArrayType(ArgType, ElemType)) or (ResolveAliasType(ElemType) <> 'String') then
        Error('E0308', Format('First argument to "Join" must be array of String, got: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[1]).Expr));
      if ArgType <> 'String' then
        Error('E0308', Format('Second argument to "Join" must be String, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('String');
    end;

    if SameText(Call.Callee, 'PadLeft') or SameText(Call.Callee, 'PadRight') then
    begin
      if (Call.Args.Count < 2) or (Call.Args.Count > 3) then
        Error('E0061', Format('Function "%s" expects 2 or 3 arguments (String, Width [, Fill])', [Call.Callee]), Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if ArgType <> 'String' then
        Error('E0308', Format('First argument to "%s" must be String, got: "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[1]).Expr));
      if (not IsIntegerType(ArgType)) and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('Second argument to "%s" must be integer, got: "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      if Call.Args.Count = 3 then
      begin
        ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[2]).Expr));
        if (ArgType <> 'String') and (ArgType <> 'Char') then
          Error('E0308', Format('Third argument to "%s" must be Char or String, got: "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      end;
      Exit('String');
    end;

    if SameText(Call.Callee, 'RepeatStr') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Function "RepeatStr" expects 2 arguments (String, Count)', Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if ArgType <> 'String' then
        Error('E0308', Format('First argument to "RepeatStr" must be String, got: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[1]).Expr));
      if (not IsIntegerType(ArgType)) and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('Second argument to "RepeatStr" must be integer, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('String');
    end;

    if SameText(Call.Callee, 'StrToFloat') or SameText(Call.Callee, 'TryStrToInt') or SameText(Call.Callee, 'TryStrToFloat') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', Format('Function "%s" expects 1 argument (String)', [Call.Callee]), Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if ArgType <> 'String' then
        Error('E0308', Format('Argument to "%s" must be String, got: "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      if SameText(Call.Callee, 'StrToFloat') then Exit('Float64')
      else if SameText(Call.Callee, 'TryStrToInt') then Exit('Option<Int32>')
      else Exit('Option<Float64>');
    end;

    if SameText(Call.Callee, 'Abs') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "Abs" expects 1 numeric argument', Call.Line, Call.Col);
      T1 := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if (not IsNumericType(T1)) and (T1 <> 'IntLiteral') and (T1 <> 'FloatLiteral') then
        Error('E0308', Format('Argument to "Abs" must be numeric, got: "%s"', [T1]), Call.Line, Call.Col);
      if T1 = 'IntLiteral' then Exit('Int32')
      else if T1 = 'FloatLiteral' then Exit('Float64')
      else Exit(T1);
    end;

    if SameText(Call.Callee, 'Min') or SameText(Call.Callee, 'Max') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', Format('Function "%s" expects 2 numeric arguments', [Call.Callee]), Call.Line, Call.Col);
      T1 := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      T2 := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[1]).Expr));
      if (not IsNumericType(T1)) and (T1 <> 'IntLiteral') and (T1 <> 'FloatLiteral') then
        Error('E0308', Format('First argument to "%s" must be numeric, got: "%s"', [Call.Callee, T1]), Call.Line, Call.Col);
      if (not IsNumericType(T2)) and (T2 <> 'IntLiteral') and (T2 <> 'FloatLiteral') then
        Error('E0308', Format('Second argument to "%s" must be numeric, got: "%s"', [Call.Callee, T2]), Call.Line, Call.Col);
      if (not TypesAreCompatible(T1, T2)) and (not TypesAreCompatible(T2, T1)) then
        Error('E0308', Format('Incompatible arguments in "%s": "%s" and "%s"', [Call.Callee, T1, T2]), Call.Line, Call.Col);
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
        Error('E0061', 'Function "Clamp" expects 3 numeric arguments (Value, Min, Max)', Call.Line, Call.Col);
      T1 := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      T2 := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[1]).Expr));
      T3 := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[2]).Expr));
      if ((not IsNumericType(T1)) and (T1 <> 'IntLiteral') and (T1 <> 'FloatLiteral')) or
         ((not IsNumericType(T2)) and (T2 <> 'IntLiteral') and (T2 <> 'FloatLiteral')) or
         ((not IsNumericType(T3)) and (T3 <> 'IntLiteral') and (T3 <> 'FloatLiteral')) then
        Error('E0308', 'All arguments to "Clamp" must be numeric', Call.Line, Call.Col);
      if ((not TypesAreCompatible(T1, T2)) and (not TypesAreCompatible(T2, T1))) or
         ((not TypesAreCompatible(T1, T3)) and (not TypesAreCompatible(T3, T1))) then
        Error('E0308', Format('Incompatible types in "Clamp": "%s", "%s", "%s"', [T1, T2, T3]), Call.Line, Call.Col);
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

    if SameText(Call.Callee, 'Sqrt') or SameText(Call.Callee, 'Floor') or SameText(Call.Callee, 'Ceil') or
       SameText(Call.Callee, 'Round') or SameText(Call.Callee, 'Exp') or SameText(Call.Callee, 'Log') or
       SameText(Call.Callee, 'Sin') or SameText(Call.Callee, 'Cos') or SameText(Call.Callee, 'Tan') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', Format('Function "%s" expects 1 numeric argument', [Call.Callee]), Call.Line, Call.Col);
      T1 := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if (not IsNumericType(T1)) and (T1 <> 'IntLiteral') and (T1 <> 'FloatLiteral') then
        Error('E0308', Format('Argument to "%s" must be numeric, got: "%s"', [Call.Callee, T1]), Call.Line, Call.Col);
      Exit('Float64');
    end;

    if SameText(Call.Callee, 'Pow') or SameText(Call.Callee, 'Atan2') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', Format('Function "%s" expects 2 numeric arguments', [Call.Callee]), Call.Line, Call.Col);
      T1 := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      T2 := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[1]).Expr));
      if ((not IsNumericType(T1)) and (T1 <> 'IntLiteral') and (T1 <> 'FloatLiteral')) or
         ((not IsNumericType(T2)) and (T2 <> 'IntLiteral') and (T2 <> 'FloatLiteral')) then
        Error('E0308', Format('Arguments to "%s" must be numeric, got: "%s", "%s"', [Call.Callee, T1, T2]), Call.Line, Call.Col);
      Exit('Float64');
    end;

    if SameText(Call.Callee, 'RandomInt') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Function "RandomInt" expects 2 integer arguments (Min, Max)', Call.Line, Call.Col);
      T1 := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      T2 := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[1]).Expr));
      if ((not IsIntegerType(T1)) and (T1 <> 'IntLiteral')) or ((not IsIntegerType(T2)) and (T2 <> 'IntLiteral')) then
        Error('E0308', Format('Arguments to "RandomInt" must be integers, got: "%s", "%s"', [T1, T2]), Call.Line, Call.Col);
      Exit('Int32');
    end;

    if SameText(Call.Callee, 'RandomFloat') then
    begin
      if Call.Args.Count <> 0 then
        Error('E0061', 'Function "RandomFloat" expects no arguments', Call.Line, Call.Col);
      Exit('Float64');
    end;

    if SameText(Call.Callee, 'Delete') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Function "Delete" expects 2 arguments (DynamicArray, Index)', Call.Line, Call.Col);
      if TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr then
      begin
        SubSym := FSymbols.Resolve(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name);
        if Assigned(SubSym) and (not SubSym.IsMutable) then
          Error('E0384', Format('Cannot pop element from immutable array (declared with "let"): "%s"', [SubSym.Name]), Call.Line, Call.Col);
      end;
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsDynamicArrayType(ArgType, ElemType) then
        Error('E0308', Format('First argument to "Delete" must be a Dynamic Array, got: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if not IsIntegerType(ArgType) then
        Error('E0308', Format('Second argument to "Delete" (index) must be integer, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Void');
    end;

    if SameText(Call.Callee, 'Insert') then
    begin
      if Call.Args.Count <> 3 then
        Error('E0061', 'Function "Insert" expects 3 arguments (DynamicArray, Index, Value)', Call.Line, Call.Col);
      if TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr then
      begin
        SubSym := FSymbols.Resolve(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name);
        if Assigned(SubSym) and (not SubSym.IsMutable) then
          Error('E0384', Format('Cannot insert element into immutable array (declared with "let"): "%s"', [SubSym.Name]), Call.Line, Call.Col);
      end;
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsDynamicArrayType(ArgType, ElemType) then
        Error('E0308', Format('First argument to "Insert" must be a Dynamic Array, got: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if not IsIntegerType(ArgType) then
        Error('E0308', Format('Second argument to "Insert" (index) must be integer, got: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[2]).Expr);
      if not TypesAreCompatible(ElemType, ArgType) then
        Error('E0308', Format('Element type mismatch in "Insert": expected "%s", got "%s"', [ElemType, ArgType]), Call.Line, Call.Col);
      Exit('Void');
    end;

    if SameText(Call.Callee, 'Slice') then
    begin
      if Call.Args.Count <> 3 then
        Error('E0061', 'Function "Slice" expects 3 arguments (DynamicArray, Start, Length)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsDynamicArrayType(ArgType, ElemType) then
        Error('E0308', Format('First argument to "Slice" must be a Dynamic Array, got: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if not IsIntegerType(ArgType) then
        Error('E0308', Format('Second argument to "Slice" (start) must be integer, got: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[2]).Expr);
      if not IsIntegerType(ArgType) then
        Error('E0308', Format('Third argument to "Slice" (length) must be integer, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('array of ' + ElemType);
    end;

    if SameText(Call.Callee, 'Contains') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Function "Contains" expects 2 arguments', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ResolveAliasType(ArgType) = 'String' then
      begin
        ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
        if ResolveAliasType(ArgType) <> 'String' then
          Error('E0308', Format('Second argument to "Contains" on String must be String, got: "%s"', [ArgType]), Call.Line, Call.Col);
        Exit('Bool');
      end;
      if not IsMapType(ArgType, KeyType, ValType) then
        Error('E0308', Format('First argument to "Contains" must be Map or String, got: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if not TypesAreCompatible(KeyType, ArgType) then
        Error('E0308', Format('Key type mismatch in "Contains": expected "%s", got "%s"', [KeyType, ArgType]), Call.Line, Call.Col);
      Exit('Bool');
    end;

    if SameText(Call.Callee, 'Remove') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Function "Remove" expects 2 arguments (Map, Key)', Call.Line, Call.Col);
      if TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr then
      begin
        SubSym := FSymbols.Resolve(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name);
        if Assigned(SubSym) and (not SubSym.IsMutable) then
          Error('E0384', Format('Cannot remove key from immutable map (declared with "let"): "%s"', [SubSym.Name]), Call.Line, Call.Col);
      end;
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsMapType(ArgType, KeyType, ValType) then
        Error('E0308', Format('First argument to "Remove" must be Map, got: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if not TypesAreCompatible(KeyType, ArgType) then
        Error('E0308', Format('Key type mismatch in "Remove": expected "%s", got "%s"', [KeyType, ArgType]), Call.Line, Call.Col);
      Exit('Void');
    end;

    if SameText(Call.Callee, 'SetLength') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Function "SetLength" expects 2 arguments (DynamicArray, Length)', Call.Line, Call.Col);
      if TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr then
      begin
        SubSym := FSymbols.Resolve(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name);
        if Assigned(SubSym) and (not SubSym.IsMutable) then
          Error('E0384', Format('Cannot resize immutable array (declared with "let"): "%s"', [SubSym.Name]), Call.Line, Call.Col);
      end;
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsDynamicArrayType(ArgType, ElemType) and (ArgType <> 'String') then
        Error('E0308', Format('First argument to "SetLength" must be a Dynamic Array, got: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if not IsIntegerType(ArgType) then
        Error('E0308', Format('Second argument to "SetLength" must be integer, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Void');
    end;

    if SameText(Call.Callee, 'Push') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Function "Push" expects 2 arguments (DynamicArray, Element)', Call.Line, Call.Col);
      if TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr then
      begin
        SubSym := FSymbols.Resolve(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name);
        if Assigned(SubSym) and (not SubSym.IsMutable) then
          Error('E0384', Format('Cannot push element to immutable array (declared with "let"): "%s"', [SubSym.Name]), Call.Line, Call.Col);
      end;
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsDynamicArrayType(ArgType, ElemType) then
        Error('E0308', Format('First argument to "Push" must be a Dynamic Array, got: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if not TypesAreCompatible(ElemType, ArgType) then
        Error('E0308', Format('Element type mismatch in "Push": expected "%s", got "%s"', [ElemType, ArgType]), Call.Line, Call.Col);
      Exit('Void');
    end;

    if SameText(Call.Callee, 'Pop') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "Pop" expects 1 argument (DynamicArray)', Call.Line, Call.Col);
      if TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr then
      begin
        SubSym := FSymbols.Resolve(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name);
        if Assigned(SubSym) and (not SubSym.IsMutable) then
          Error('E0384', Format('Cannot pop element from immutable array (declared with "let"): "%s"', [SubSym.Name]), Call.Line, Call.Col);
      end;
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsDynamicArrayType(ArgType, ElemType) then
        Error('E0308', Format('Argument to "Pop" must be a Dynamic Array, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit(ElemType);
    end;

    if SameText(Call.Callee, 'Clear') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "Clear" expects 1 argument (DynamicArray or Map)', Call.Line, Call.Col);
      if TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr then
      begin
        SubSym := FSymbols.Resolve(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name);
        if Assigned(SubSym) and (not SubSym.IsMutable) then
          Error('E0384', Format('Cannot clear immutable collection (declared with "let"): "%s"', [SubSym.Name]), Call.Line, Call.Col);
      end;
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if (not IsDynamicArrayType(ArgType, ElemType)) and (not IsMapType(ArgType, KeyType, ValType)) then
        Error('E0308', Format('Argument to "Clear" must be a Dynamic Array or Map, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Void');
    end;

    if SameText(Call.Callee, 'Inc') or SameText(Call.Callee, 'Dec') then
    begin
      if (Call.Args.Count < 1) or (Call.Args.Count > 2) then
        Error('E0061', Format('Function "%s" expects 1 or 2 arguments (integer variable[, delta])', [Call.Callee]), Call.Line, Call.Col);
      if TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr then
      begin
        SubSym := FSymbols.Resolve(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name);
        if Assigned(SubSym) and (not SubSym.IsMutable) then
          Error('E0384', Format('Cannot modify immutable variable with "%s": "%s"', [Call.Callee, SubSym.Name]), Call.Line, Call.Col);
      end;
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsIntegerType(ArgType) then
        Error('E0308', Format('First argument to "%s" must be integer, got: "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      if Call.Args.Count = 2 then
      begin
        ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
        if not IsIntegerType(ArgType) then
          Error('E0308', Format('Increment/decrement delta for "%s" must be integer, got: "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      end;
      Exit('Void');
    end;

    if SameText(Call.Callee, 'Ord') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "Ord" expects 1 argument (Char, Bool, Integer, or Enum)', Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      SubSym := FSymbols.Resolve(ArgType);
      if (ArgType <> 'Char') and (ArgType <> 'Bool') and (not IsIntegerType(ArgType)) and
         not (Assigned(SubSym) and (SubSym.Node is TASTEnumDecl)) then
        Error('E0308', Format('Invalid argument to "Ord": "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Int32');
    end;

    if SameText(Call.Callee, 'Chr') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "Chr" expects 1 integer argument', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsIntegerType(ArgType) then
        Error('E0308', Format('Argument to "Chr" must be integer, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Char');
    end;

    if SameText(Call.Callee, 'SizeOf') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "SizeOf" expects 1 argument (Type or Expression)', Call.Line, Call.Col);
      if (TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr) and
         FSymbols.ResolveType(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name) then
        Exit('Int32');
      CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      Exit('Int32');
    end;

    if Call.Callee = 'CharAt' then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Function "CharAt" expects 2 arguments (String, UInt32)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('First argument to "CharAt" must be String, got: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if not IsIntegerType(ArgType) and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('Second argument to "CharAt" must be integer, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('String');
    end;

    if Call.Callee = 'ByteAt' then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Function "ByteAt" expects 2 arguments (String, Int32)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('First argument to "ByteAt" must be String, got: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if not IsIntegerType(ArgType) and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('Second argument to "ByteAt" must be integer, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Int32');
    end;

    if Call.Callee = 'CharFromByte' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "CharFromByte" expects 1 argument (Int32)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsIntegerType(ArgType) and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('Argument to "CharFromByte" must be integer, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('String');
    end;

    if Call.Callee = 'Substring' then
    begin
      if Call.Args.Count <> 3 then
        Error('E0061', 'Function "Substring" expects 3 arguments (String, UInt32, UInt32)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('First argument to "Substring" must be String, got: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if not IsIntegerType(ArgType) and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('Second argument (start) to "Substring" must be integer, got: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[2]).Expr);
      if not IsIntegerType(ArgType) and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('Third argument (len) to "Substring" must be integer, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('String');
    end;

    if Call.Callee = 'FileExists' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "FileExists" expects 1 argument (String)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('Function "FileExists" expects String, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Bool');
    end;

    if Call.Callee = 'ReadFile' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "ReadFile" expects 1 argument (String)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('Function "ReadFile" expects String, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('String');
    end;

    if Call.Callee = 'WriteFile' then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Function "WriteFile" expects 2 arguments (String, String)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('First argument to "WriteFile" must be String, got: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('Second argument to "WriteFile" must be String, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Bool');
    end;

    if (Call.Callee = 'CreateDir') or (Call.Callee = 'RemoveDir') or (Call.Callee = 'DeleteFile') or (Call.Callee = 'DirExists') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', Format('Function "%s" expects 1 argument (String)', [Call.Callee]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('Function "%s" expects String, got: "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      Exit('Bool');
    end;

    if Call.Callee = 'FileSize' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "FileSize" expects 1 argument (String)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('Function "FileSize" expects String, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Int64');
    end;

    if SameText(Call.Callee, 'ReadLn') then
    begin
      if Call.Args.Count <> 0 then
        Error('E0061', 'Function "ReadLn" expects no arguments', Call.Line, Call.Col);
      Exit('String');
    end;

    if SameText(Call.Callee, 'GetEnv') or SameText(Call.Callee, 'ListDir') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', Format('Function "%s" expects 1 argument (String)', [Call.Callee]), Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if ArgType <> 'String' then
        Error('E0308', Format('Argument to "%s" must be String, got: "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      if SameText(Call.Callee, 'ListDir') then Exit('array of String')
      else Exit('String');
    end;

    if SameText(Call.Callee, 'SetEnv') or SameText(Call.Callee, 'CopyFile') or SameText(Call.Callee, 'RenameFile') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', Format('Function "%s" expects 2 arguments (String, String)', [Call.Callee]), Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if ArgType <> 'String' then
        Error('E0308', Format('First argument to "%s" must be String, got: "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[1]).Expr));
      if ArgType <> 'String' then
        Error('E0308', Format('Second argument to "%s" must be String, got: "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      Exit('Bool');
    end;

    if Call.Callee = 'GetNanoseconds' then
    begin
      if Call.Args.Count <> 0 then
        Error('E0061', 'Function "GetNanoseconds" expects no arguments', Call.Line, Call.Col);
      Exit('UInt64');
    end;

    if Call.Callee = 'SleepMs' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "SleepMs" expects 1 argument (UInt32)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsIntegerType(ArgType) and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('Function "SleepMs" expects integer type, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Void');
    end;

    if Call.Callee = 'IntToStr' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "IntToStr" expects 1 argument (Int32)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsIntegerType(ArgType) and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('Function "IntToStr" expects integer type, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('String');
    end;

    if Call.Callee = 'FloatToStr' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "FloatToStr" expects 1 argument (Float64)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsNumericType(ArgType) and (ArgType <> 'FloatLiteral') and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('Function "FloatToStr" expects numeric type, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('String');
    end;

    if Call.Callee = 'BoolToStr' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "BoolToStr" expects 1 argument (Bool)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if (ArgType <> 'Bool') then
        Error('E0308', Format('Function "BoolToStr" expects Bool, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('String');
    end;

    if Call.Callee = 'StrToInt' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "StrToInt" expects 1 argument (String)', Call.Line, Call.Col);
      Exit('Int32');
    end;

    if Call.Callee = 'ParamCount' then
    begin
      if Call.Args.Count <> 0 then
        Error('E0061', 'Function "ParamCount" expects no arguments', Call.Line, Call.Col);
      Exit('Int32');
    end;

    if Call.Callee = 'ParamStr' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "ParamStr" expects 1 argument (Int32)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsIntegerType(ArgType) and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('Function "ParamStr" expects Int32, got: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('String');
    end;

    if Call.Callee = 'Assert' then
    begin
      if (Call.Args.Count < 1) or (Call.Args.Count > 2) then
        Error('E0061', 'Function "Assert" expects 1 or 2 arguments (Condition: Bool [, Message: String])', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'Bool' then
        Error('E0308', Format('First argument to "Assert" must be Bool, got: "%s"', [ArgType]), Call.Line, Call.Col);
      if Call.Args.Count = 2 then
      begin
        ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
        if ArgType <> 'String' then
          Error('E0308', Format('Second argument to "Assert" must be String, got: "%s"', [ArgType]), Call.Line, Call.Col);
      end;
      Exit('Void');
    end;

    if Call.Callee = 'SocketCreate' then
    begin
      if Call.Args.Count <> 0 then
        Error('E0061', 'Function "SocketCreate" expects no arguments', Call.Line, Call.Col);
      Exit('Int32');
    end;

    if Call.Callee = 'SocketListen' then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Function "SocketListen" expects 2 arguments (Port: UInt32, Backlog: Int32)', Call.Line, Call.Col);
      Exit('Int32');
    end;

    if Call.Callee = 'SocketAccept' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "SocketAccept" expects 1 argument (ListenFd: Int32)', Call.Line, Call.Col);
      Exit('Int32');
    end;

    if Call.Callee = 'SocketConnect' then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Function "SocketConnect" expects 2 arguments (Host: String, Port: UInt32)', Call.Line, Call.Col);
      Exit('Int32');
    end;

    if Call.Callee = 'SocketSend' then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Function "SocketSend" expects 2 arguments (Fd: Int32, Data: String)', Call.Line, Call.Col);
      Exit('Int32');
    end;

    if Call.Callee = 'SocketRecv' then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Function "SocketRecv" expects 2 arguments (Fd: Int32, MaxLen: Int32)', Call.Line, Call.Col);
      Exit('String');
    end;

    if Call.Callee = 'SocketClose' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "SocketClose" expects 1 argument (Fd: Int32)', Call.Line, Call.Col);
      Exit('Void');
    end;

    if Call.Callee = 'SocketSetTimeout' then
    begin
      if Call.Args.Count <> 3 then
        Error('E0061', 'Function "SocketSetTimeout" expects 3 arguments (Fd: Int32, ReadMs: Int32, WriteMs: Int32)', Call.Line, Call.Col);
      CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      CheckExpr(TASTCallArg(Call.Args[2]).Expr);
      Exit('Bool');
    end;

    if Call.Callee = 'SocketPeerIP' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "SocketPeerIP" expects 1 argument (Fd: Int32)', Call.Line, Call.Col);
      CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      Exit('String');
    end;

    if Call.Callee = 'SocketSendHex' then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Function "SocketSendHex" expects 2 arguments (Fd: Int32, HexData: String)', Call.Line, Call.Col);
      CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      Exit('Int32');
    end;

    if Call.Callee = 'SocketRecvHex' then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Function "SocketRecvHex" expects 2 arguments (Fd: Int32, MaxLen: Int32)', Call.Line, Call.Col);
      CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      Exit('String');
    end;

    if SameText(Call.Callee, 'Free') or SameText(Call.Callee, 'Dispose') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', Format('Function "%s" expects 1 argument', [Call.Callee]), Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if (Pos('^', ArgType) = 1) or SameText(ArgType, 'Pointer') then
      begin
        if FUnsafeDepth <= 0 then
          Error('E0133', Format('Calling "%s" on raw pointer ("%s") requires an unsafe block', [Call.Callee, ArgType]), Call.Line, Call.Col);
      end
      else if (Pos('Box<', ArgType) = 1) or IsDynamicArrayType(ArgType, ElemType) or IsMapType(ArgType, KeyType, ValType) then
      begin
        // Safe management for Box<T>, dynamic array, and map
      end
      else
        Error('E0308', Format('"%s" expects Box<T>, dynamic array, map, or raw pointer, got "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      Exit('Void');
    end;

    // Phase 53: Low-level OS Sync Intrinsics & Generic Channels
    if Call.Callee = '__SyncAtomicNew' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "__SyncAtomicNew" expects 1 argument (initial: Int32)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsIntegerType(ArgType) and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('"__SyncAtomicNew" expects Int32, got "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Pointer');
    end;
    if Call.Callee = '__SyncAtomicLoad' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "__SyncAtomicLoad" expects 1 argument (handle: Pointer)', Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if ArgType <> 'Pointer' then
        Error('E0308', Format('"__SyncAtomicLoad" expects Pointer, got "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Int32');
    end;
    if (Call.Callee = '__SyncAtomicStore') or (Call.Callee = '__SyncAtomicAdd') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', Format('Function "%s" expects 2 arguments (handle: Pointer, val: Int32)', [Call.Callee]), Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if ArgType <> 'Pointer' then
        Error('E0308', Format('"%s" first arg must be Pointer, got "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if not IsIntegerType(ArgType) and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('"%s" second arg must be Int32, got "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      if Call.Callee = '__SyncAtomicAdd' then Exit('Int32') else Exit('Void');
    end;
    if Call.Callee = '__SyncAtomicCas' then
    begin
      if Call.Args.Count <> 3 then
        Error('E0061', 'Function "__SyncAtomicCas" expects 3 arguments (handle, expected, desired)', Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if ArgType <> 'Pointer' then
        Error('E0308', Format('"__SyncAtomicCas" first arg must be Pointer, got "%s"', [ArgType]), Call.Line, Call.Col);
      for K := 1 to 2 do
      begin
        ArgType := CheckExpr(TASTCallArg(Call.Args[K]).Expr);
        if not IsIntegerType(ArgType) and (ArgType <> 'IntLiteral') then
          Error('E0308', Format('"__SyncAtomicCas" argument %d must be Int32, got "%s"', [K + 1, ArgType]), Call.Line, Call.Col);
      end;
      Exit('Bool');
    end;
    if (Call.Callee = '__SyncAtomicFree') or (Call.Callee = '__SyncMutexLock') or
       (Call.Callee = '__SyncMutexTryLock') or (Call.Callee = '__SyncMutexUnlock') or
       (Call.Callee = '__SyncMutexFree') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', Format('Function "%s" expects 1 argument (handle: Pointer)', [Call.Callee]), Call.Line, Call.Col);
      ArgType := ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr));
      if ArgType <> 'Pointer' then
        Error('E0308', Format('"%s" expects Pointer, got "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      if Call.Callee = '__SyncMutexTryLock' then Exit('Bool') else Exit('Void');
    end;
    if Call.Callee = '__SyncMutexNew' then
    begin
      if Call.Args.Count <> 0 then
        Error('E0061', 'Function "__SyncMutexNew" expects 0 arguments', Call.Line, Call.Col);
      Exit('Pointer');
    end;

    if SameText(Call.Callee, 'NewChannel') then
    begin
      if Call.GenericArgs.Count <> 1 then
        Error('E0061', 'Function "NewChannel" requires 1 generic type argument, e.g. NewChannel<Int32>(cap)', Call.Line, Call.Col);
      if Call.Args.Count <> 1 then
        Error('E0061', 'Function "NewChannel" expects 1 argument (capacity: Int32)', Call.Line, Call.Col);
      ChanElem := NormalizeTypeName(Call.GenericArgs[0]);
      if not FSymbols.ResolveType(ChanElem) then
        Error('E0412', Format('Channel element type "%s" not found', [ChanElem]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if not IsIntegerType(ArgType) and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('"NewChannel" capacity must be integer, got "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Channel<' + ChanElem + '>');
    end;

    if SameText(Call.Callee, 'Send') or SameText(Call.Callee, 'TrySend') then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', Format('Function "%s" expects 2 arguments (channel, value)', [Call.Callee]), Call.Line, Call.Col);
      ArgType := NormalizeTypeName(ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr)));
      ChanArgs := TStringList.Create;
      try
        if (not SplitGenericType(ArgType, ChanBase, ChanArgs)) or (ChanBase <> 'Channel') or (ChanArgs.Count <> 1) then
          Error('E0308', Format('"%s" first argument must be Channel<T>, got "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
        ChanElem := NormalizeTypeName(ChanArgs[0]);
      finally
        ChanArgs.Free;
      end;
      Arg := TASTCallArg(Call.Args[1]);
      AnnotateMonadExpr(Arg.Expr, ChanElem);
      ArgType := CheckExpr(Arg.Expr);
      AnnotateMonadExpr(Arg.Expr, ChanElem);
      if not TypesAreCompatible(ChanElem, ArgType) then
        Error('E0308', Format('"%s" value expects "%s", but got "%s"', [Call.Callee, ChanElem, ArgType]), Arg.Line, Arg.Col);
      Exit('Bool');
    end;

    if SameText(Call.Callee, 'Recv') or SameText(Call.Callee, 'TryRecv') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', Format('Function "%s" expects 1 argument (channel)', [Call.Callee]), Call.Line, Call.Col);
      ArgType := NormalizeTypeName(ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr)));
      ChanArgs := TStringList.Create;
      try
        if (not SplitGenericType(ArgType, ChanBase, ChanArgs)) or (ChanBase <> 'Channel') or (ChanArgs.Count <> 1) then
          Error('E0308', Format('"%s" argument must be Channel<T>, got "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
        ChanElem := NormalizeTypeName(ChanArgs[0]);
      finally
        ChanArgs.Free;
      end;
      Call.ResolvedMonadType := 'Option<' + ChanElem + '>';
      Exit(Call.ResolvedMonadType);
    end;

    if SameText(Call.Callee, 'CloseChannel') or SameText(Call.Callee, 'DestroyChannel') or
       SameText(Call.Callee, 'ChannelLen') or SameText(Call.Callee, 'IsChannelEmpty') or
       SameText(Call.Callee, 'IsChannelFull') or SameText(Call.Callee, 'IsChannelClosed') then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', Format('Function "%s" expects 1 argument (channel)', [Call.Callee]), Call.Line, Call.Col);
      ArgType := NormalizeTypeName(ResolveAliasType(CheckExpr(TASTCallArg(Call.Args[0]).Expr)));
      ChanArgs := TStringList.Create;
      try
        if (not SplitGenericType(ArgType, ChanBase, ChanArgs)) or (ChanBase <> 'Channel') or (ChanArgs.Count <> 1) then
          Error('E0308', Format('"%s" argument must be Channel<T>, got "%s"', [Call.Callee, ArgType]), Call.Line, Call.Col);
      finally
        ChanArgs.Free;
      end;
      if SameText(Call.Callee, 'CloseChannel') or SameText(Call.Callee, 'DestroyChannel') then
        Exit('Void')
      else if SameText(Call.Callee, 'ChannelLen') then
        Exit('Int32')
      else
        Exit('Bool');
    end;

    if Assigned(Sym.Node) and (Sym.Node is TASTFunction) then
    begin
      FuncNode := TASTFunction(Sym.Node);
      if Call.Args.Count <> FuncNode.Params.Count then
        Error('E0061', Format('Function "%s" expects %d arguments, but got %d',
          [FuncNode.Name, FuncNode.Params.Count, Call.Args.Count]), Call.Line, Call.Col);

      for I := 0 to Call.Args.Count - 1 do
      begin
        Arg := TASTCallArg(Call.Args[I]);
        ExpectedType := NormalizeTypeName(TASTParam(FuncNode.Params[I]).TypeName);
        AnnotateMonadExpr(Arg.Expr, ExpectedType);
        ArgType := CheckExpr(Arg.Expr);
        AnnotateMonadExpr(Arg.Expr, ExpectedType);
        if not TypesAreCompatible(ExpectedType, ArgType) then
          Error('E0308', Format('Argument %d of function "%s" expects "%s", but got "%s"',
            [I + 1, FuncNode.Name, ExpectedType, ArgType]), Arg.Line, Arg.Col);
      end;
      if FuncNode.IsAsync then
        Exit('Task<' + NormalizeTypeName(FuncNode.ReturnType) + '>');
    end;
    Exit(NormalizeTypeName(Sym.TypeName));
  end;

  Error('E0618', Format('"%s" is neither a function nor a constructor', [Call.Callee]), Call.Line, Call.Col);
  Result := 'Unknown';
end;

function TAetherTypeChecker.CheckTupleLiteral(Tup: TASTTupleLiteralExpr): string;
var
  I: Integer;
  ET, ExistingType: string;
  ElemTypes: TStringList;
  Sym: TSymbol;
  RecDecl: TASTRecordDecl;
begin
  ExistingType := ResolveAliasType(Tup.ResolvedType);
  ElemTypes := TStringList.Create;
  try
    for I := 0 to Tup.Elements.Count - 1 do
    begin
      ET := NormalizeTypeName(CheckExpr(TASTExpr(Tup.Elements[I])));
      if ET = 'IntLiteral' then ET := 'Int32'
      else if ET = 'FloatLiteral' then ET := 'Float64';
      ElemTypes.Add(ET);
    end;

    if (ExistingType <> '') and Assigned(FSymbols) then
    begin
      Sym := FSymbols.ResolveTypeSymbol(ExistingType);
      if Assigned(Sym) and (Sym.Node is TASTRecordDecl) and (Pos('Tuple', TASTRecordDecl(Sym.Node).Name) = 1) and
         (TASTRecordDecl(Sym.Node).Fields.Count = Tup.Elements.Count) then
      begin
        RecDecl := TASTRecordDecl(Sym.Node);
        Result := RecDecl.Name;
        for I := 0 to RecDecl.Fields.Count - 1 do
          if not TypesAreCompatible(TASTRecordField(RecDecl.Fields[I]).TypeName, ElemTypes[I]) then
          begin
            Result := '';
            Break;
          end;
        if Result <> '' then
        begin
          Tup.ResolvedType := Result;
          Exit;
        end;
      end;
    end;

    Result := EnsureTupleRecord(ElemTypes, Tup.Line, Tup.Col);
    Tup.ResolvedType := Result;
  finally
    ElemTypes.Free;
  end;
end;

procedure TAetherTypeChecker.CollectLambdaCaptures(Lambda: TASTLambdaExpr; OuterScope: TScope);
var
  Bound: TStringList;

  procedure AddBound(const S: string);
  begin
    if (S <> '') and (S <> '_') and (Bound.IndexOf(S) < 0) then
      Bound.Add(S);
  end;

  procedure TryCapture(const IdName: string);
  var
    Sym: TSymbol;
    CType: string;
  begin
    if (IdName = '') or SameText(IdName, 'None') or SameText(IdName, 'result') or
       (Bound.IndexOf(IdName) >= 0) then
      Exit;
    if not Assigned(OuterScope) then Exit;
    Sym := OuterScope.Resolve(IdName);
    if Assigned(Sym) and (Sym.Kind = skVariable) then
    begin
      if Assigned(FSymbols) and Assigned(FSymbols.GlobalScope.ResolveLocal(Sym.Name)) then
        Exit; // module variable is globally visible
      if Lambda.CaptureNames.IndexOf(Sym.Name) < 0 then
      begin
        CType := NormalizeTypeName(Sym.TypeName);
        Lambda.CaptureNames.Add(Sym.Name);
        Lambda.CaptureTypes.Add(CType);
      end;
    end;
  end;

  procedure WalkExpr(E: TASTExpr);
  var
    I, K: Integer;
    C: TASTCallExpr;
    ME: TASTMatchExpr;
    CaseN: TASTMatchCase;
    NestedL: TASTLambdaExpr;
  begin
    if not Assigned(E) then Exit;
    if E is TASTIdentifierExpr then
      TryCapture(TASTIdentifierExpr(E).Name)
    else if E is TASTMemberAccessExpr then
      WalkExpr(TASTMemberAccessExpr(E).Target)
    else if E is TASTBinaryExpr then
    begin
      WalkExpr(TASTBinaryExpr(E).Left);
      WalkExpr(TASTBinaryExpr(E).Right);
    end
    else if E is TASTUnaryExpr then
      WalkExpr(TASTUnaryExpr(E).Expr)
    else if E is TASTAwaitExpr then
      WalkExpr(TASTAwaitExpr(E).Expr)
    else if E is TASTSpawnExpr then
      WalkExpr(TASTSpawnExpr(E).CallExpr)
    else if E is TASTCallExpr then
    begin
      C := TASTCallExpr(E);
      if Assigned(C.CalleeExpr) then
        WalkExpr(C.CalleeExpr)
      else if C.IsIndirectCall and (C.Callee <> '') then
        TryCapture(C.Callee);
      for I := 0 to C.Args.Count - 1 do
        WalkExpr(TASTCallArg(C.Args[I]).Expr);
    end
    else if E is TASTIndexExpr then
    begin
      WalkExpr(TASTIndexExpr(E).Target);
      for I := 0 to TASTIndexExpr(E).Indices.Count - 1 do
        WalkExpr(TASTExpr(TASTIndexExpr(E).Indices[I]));
    end
    else if E is TASTSetLiteralExpr then
      for I := 0 to TASTSetLiteralExpr(E).Elements.Count - 1 do
        WalkExpr(TASTExpr(TASTSetLiteralExpr(E).Elements[I]))
    else if E is TASTMapLiteralExpr then
      for I := 0 to TASTMapLiteralExpr(E).Keys.Count - 1 do
      begin
        WalkExpr(TASTExpr(TASTMapLiteralExpr(E).Keys[I]));
        WalkExpr(TASTExpr(TASTMapLiteralExpr(E).Values[I]));
      end
    else if E is TASTTupleLiteralExpr then
      for I := 0 to TASTTupleLiteralExpr(E).Elements.Count - 1 do
        WalkExpr(TASTExpr(TASTTupleLiteralExpr(E).Elements[I]))
    else if E is TASTIfExpr then
    begin
      WalkExpr(TASTIfExpr(E).Condition);
      WalkExpr(TASTIfExpr(E).ThenExpr);
      WalkExpr(TASTIfExpr(E).ElseExpr);
    end
    else if E is TASTMatchExpr then
    begin
      ME := TASTMatchExpr(E);
      WalkExpr(ME.Expr);
      for I := 0 to ME.Cases.Count - 1 do
      begin
        CaseN := TASTMatchCase(ME.Cases[I]);
        if Assigned(CaseN.Pattern.Bindings) then
          for K := 0 to CaseN.Pattern.Bindings.Count - 1 do
            AddBound(CaseN.Pattern.Bindings[K]);
        if CaseN.Pattern.SubPattern <> '' then
          AddBound(CaseN.Pattern.SubPattern);
        WalkExpr(CaseN.Guard);
        WalkExpr(CaseN.ValueExpr);
      end;
    end
    else if E is TASTLambdaExpr then
    begin
      NestedL := TASTLambdaExpr(E);
      for I := 0 to NestedL.CaptureNames.Count - 1 do
        TryCapture(NestedL.CaptureNames[I]);
    end;
  end;

  procedure WalkStmts(Stmts: TASTNodeList);
  var
    I, J, K: Integer;
    S: TASTStmt;
    VD: TASTVarDecl;
    MS: TASTMatchStmt;
    CN: TASTMatchCase;
  begin
    if not Assigned(Stmts) then Exit;
    for I := 0 to Stmts.Count - 1 do
    begin
      S := TASTStmt(Stmts[I]);
      if S is TASTVarDeclStmt then
      begin
        for J := 0 to TASTVarDeclStmt(S).Decls.Count - 1 do
        begin
          VD := TASTVarDecl(TASTVarDeclStmt(S).Decls[J]);
          WalkExpr(VD.InitialExpr);
          AddBound(VD.Name);
        end;
      end
      else if S is TASTAssignStmt then
      begin
        WalkExpr(TASTAssignStmt(S).Target);
        WalkExpr(TASTAssignStmt(S).Expr);
      end
      else if S is TASTCallStmt then
        WalkExpr(TASTCallStmt(S).CallExpr)
      else if S is TASTReturnStmt then
        WalkExpr(TASTReturnStmt(S).Expr)
      else if S is TASTIfStmt then
      begin
        WalkExpr(TASTIfStmt(S).Condition);
        WalkStmts(TASTIfStmt(S).ThenBranch);
        WalkStmts(TASTIfStmt(S).ElseBranch);
      end
      else if S is TASTWhileStmt then
      begin
        WalkExpr(TASTWhileStmt(S).Condition);
        WalkStmts(TASTWhileStmt(S).Body);
      end
      else if S is TASTForStmt then
      begin
        WalkExpr(TASTForStmt(S).StartExpr);
        WalkExpr(TASTForStmt(S).EndExpr);
        WalkExpr(TASTForStmt(S).CollectionExpr);
        AddBound(TASTForStmt(S).VarName);
        if TASTForStmt(S).ValVarName <> '' then
          AddBound(TASTForStmt(S).ValVarName);
        WalkStmts(TASTForStmt(S).Body);
      end
      else if S is TASTRepeatStmt then
      begin
        WalkStmts(TASTRepeatStmt(S).Body);
        WalkExpr(TASTRepeatStmt(S).Condition);
      end
      else if S is TASTMatchStmt then
      begin
        MS := TASTMatchStmt(S);
        WalkExpr(MS.Expr);
        for J := 0 to MS.Cases.Count - 1 do
        begin
          CN := TASTMatchCase(MS.Cases[J]);
          if Assigned(CN.Pattern.Bindings) then
            for K := 0 to CN.Pattern.Bindings.Count - 1 do
              AddBound(CN.Pattern.Bindings[K]);
          if CN.Pattern.SubPattern <> '' then
            AddBound(CN.Pattern.SubPattern);
          WalkExpr(CN.Guard);
          WalkStmts(CN.Body);
        end;
      end
      else if S is TASTUnsafeStmt then
        WalkStmts(TASTUnsafeStmt(S).Body)
      else if S is TASTTryStmt then
      begin
        WalkStmts(TASTTryStmt(S).TryBody);
        WalkStmts(TASTTryStmt(S).ExceptBody);
      end
      else if S is TASTRaiseStmt then
        WalkExpr(TASTRaiseStmt(S).Expr)
      else if S is TASTDeferStmt then
      begin
        if TASTDeferStmt(S).Stmt is TASTCallStmt then
          WalkExpr(TASTCallStmt(TASTDeferStmt(S).Stmt).CallExpr);
      end;
    end;
  end;

var
  I: Integer;
begin
  Lambda.CaptureNames.Clear;
  Lambda.CaptureTypes.Clear;
  Bound := TStringList.Create;
  Bound.CaseSensitive := False;
  try
    for I := 0 to Lambda.Params.Count - 1 do
      AddBound(TASTParam(Lambda.Params[I]).Name);
    if Assigned(Lambda.BodyExpr) then
      WalkExpr(Lambda.BodyExpr)
    else
      WalkStmts(Lambda.BodyStmts);
  finally
    Bound.Free;
  end;
end;

function TAetherTypeChecker.CheckLambda(Lambda: TASTLambdaExpr): string;
var
  OuterScope: TScope;
  SavedCurFunc, TempFunc: TASTFunction;
  I: Integer;
  Param: TASTParam;
  BodyT, PList, DeclRetT: string;
begin
  OuterScope := FSymbols.CurrentScope;
  SavedCurFunc := FCurrentFunction;
  FSymbols.EnterScope;
  TempFunc := nil;
  try
    for I := 0 to Lambda.Params.Count - 1 do
    begin
      Param := TASTParam(Lambda.Params[I]);
      if Param.TypeName = '' then
        Error('E0282', Format('Cannot infer type for lambda parameter "%s"; add explicit type annotation', [Param.Name]), Param.Line, Param.Col);
      Param.TypeName := NormalizeTypeName(Param.TypeName);
      if not FSymbols.ResolveType(Param.TypeName) then
        Error('E0412', Format('Type "%s" of lambda parameter "%s" not found', [Param.TypeName, Param.Name]), Param.Line, Param.Col);
      FSymbols.Define(TSymbol.Create(Param.Name, skVariable, Param.TypeName, Param.Line, Param.Col, Param.Ownership = owMutBorrow, Param.Ownership));
    end;

    DeclRetT := '';
    if Lambda.ReturnType <> '' then
      DeclRetT := NormalizeTypeName(Lambda.ReturnType);

    if Assigned(Lambda.BodyExpr) then
    begin
      if DeclRetT <> '' then
        AnnotateMonadExpr(Lambda.BodyExpr, DeclRetT);
      BodyT := NormalizeTypeName(CheckExpr(Lambda.BodyExpr));
      if BodyT = 'IntLiteral' then BodyT := 'Int32'
      else if BodyT = 'FloatLiteral' then BodyT := 'Float64';
      if DeclRetT = '' then
        Lambda.ReturnType := BodyT
      else
      begin
        if not TypesAreCompatible(DeclRetT, BodyT) then
          Error('E0308', Format('Lambda return type expects "%s", but body returned "%s"', [DeclRetT, BodyT]), Lambda.Line, Lambda.Col);
        Lambda.ReturnType := DeclRetT;
      end;
    end
    else
    begin
      TempFunc := TASTFunction.Create(Lambda.Line, Lambda.Col, '__lambda', DeclRetT);
      TempFunc.IsProcedure := SameText(DeclRetT, 'Void');
      FCurrentFunction := TempFunc;
      for I := 0 to Lambda.BodyStmts.Count - 1 do
        CheckStmt(TASTStmt(Lambda.BodyStmts[I]));
      if TempFunc.ReturnType = '' then
        Lambda.ReturnType := 'Void'
      else
      begin
        Lambda.ReturnType := NormalizeTypeName(TempFunc.ReturnType);
        if (not TempFunc.IsProcedure) and (not StmtListAlwaysReturns(Lambda.BodyStmts)) then
          Error('E0308', Format('Not all code paths in lambda return a value of type "%s"', [Lambda.ReturnType]), Lambda.Line, Lambda.Col);
      end;
    end;
  finally
    FCurrentFunction := SavedCurFunc;
    TempFunc.Free;
    FSymbols.LeaveScope;
  end;

  CollectLambdaCaptures(Lambda, OuterScope);
  if Lambda.LambdaId = 0 then
  begin
    Inc(FLambdaCounter);
    Lambda.LambdaId := FLambdaCounter;
  end;

  PList := '';
  for I := 0 to Lambda.Params.Count - 1 do
  begin
    if I > 0 then PList := PList + ', ';
    PList := PList + TASTParam(Lambda.Params[I]).TypeName;
  end;
  Lambda.ResolvedFnType := 'fn(' + PList + ') -> ' + Lambda.ReturnType;
  Result := Lambda.ResolvedFnType;
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
  else if Expr is TASTTupleLiteralExpr then
    Result := CheckTupleLiteral(TASTTupleLiteralExpr(Expr))
  else if Expr is TASTLambdaExpr then
    Result := CheckLambda(TASTLambdaExpr(Expr))
  else if Expr is TASTMatchExpr then
    Result := CheckMatchExpr(TASTMatchExpr(Expr))
  else if Expr is TASTIfExpr then
  begin
    IfExpr := TASTIfExpr(Expr);
    CondT := ResolveAliasType(CheckExpr(IfExpr.Condition));
    if CondT <> 'Bool' then
      Error('E0308', Format('Condition of "if..then..else" expression must be Bool, got: "%s"', [CondT]),
        IfExpr.Line, IfExpr.Col);
    T1 := ResolveAliasType(CheckExpr(IfExpr.ThenExpr));
    T2 := ResolveAliasType(CheckExpr(IfExpr.ElseExpr));
    if (not TypesAreCompatible(T1, T2)) and (not TypesAreCompatible(T2, T1)) then
      Error('E0308', Format('Branches of "if..then..else" have incompatible types: "%s" and "%s"', [T1, T2]),
        IfExpr.Line, IfExpr.Col);
    CondT := MergeInferredMonadTypes(T1, T2);
    AnnotateMonadExpr(IfExpr.ThenExpr, CondT);
    AnnotateMonadExpr(IfExpr.ElseExpr, CondT);
    if T1 = 'NilLiteral' then Exit(T2);
    if T2 = 'NilLiteral' then Exit(T1);
    if T1 = 'Option<GenericNone>' then Exit(T2);
    if T2 = 'Option<GenericNone>' then Exit(T1);
    if (Pos('Result<', CondT) = 1) or (Pos('Option<', CondT) = 1) then Exit(CondT);
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
      Error('E0061', Format('String indexing expects exactly 1 index, found %d', [Idx.Indices.Count]), Idx.Line, Idx.Col);
    IdxType := CheckExpr(TASTExpr(Idx.Indices[0]));
    if not IsIntegerType(IdxType) then
      Error('E0308', Format('String index must be integer, found: "%s"', [IdxType]), Idx.Line, Idx.Col);
    Exit('Char');
  end;

  if IsMapType(TargetType, KeyType, ValType) then
  begin
    if Idx.Indices.Count <> 1 then
      Error('E0061', Format('Map lookup expects exactly 1 key, found %d', [Idx.Indices.Count]), Idx.Line, Idx.Col);
    IdxType := CheckExpr(TASTExpr(Idx.Indices[0]));
    if not TypesAreCompatible(KeyType, IdxType) then
      Error('E0308', Format('Map key expects type "%s", but got "%s"', [KeyType, IdxType]), Idx.Line, Idx.Col);
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
      Error('E0308', Format('Array index must be integer, found: "%s"', [IdxType]), Idx.Line, Idx.Col);

    if Assigned(ArrDecl) and (I < ArrDecl.Dims.Count) then
    begin
      DimSize := StrToIntDef(ArrDecl.Dims[I], 0);
      if (Idx.Indices[I] is TASTLiteralExpr) and (TASTLiteralExpr(Idx.Indices[I]).Kind = lkInt) then
      begin
        ValInt := StrToIntDef(TASTLiteralExpr(Idx.Indices[I]).Value, 0);
        if (ValInt < 0) or ((DimSize > 0) and (ValInt >= DimSize)) then
          Error('E0309', Format('Array index out of bounds: %d (declared size: %d)', [ValInt, DimSize]), Idx.Line, Idx.Col);
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
      Error('E0308', Format('Map literal key %d (%s) is incompatible with type "%s"', [I + 1, NextK, KeyT]), MapLit.Line, MapLit.Col);
    if not TypesAreCompatible(ValT, NextV) then
      Error('E0308', Format('Map literal value %d (%s) is incompatible with type "%s"', [I + 1, NextV, ValT]), MapLit.Line, MapLit.Col);
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
  TargetType := NormalizeTypeName(CheckExpr(Assign.Target));
  AnnotateMonadExpr(Assign.Expr, TargetType);
  ValueType := CheckExpr(Assign.Expr);
  AnnotateMonadExpr(Assign.Expr, TargetType);

  if (Assign.Expr is TASTSetLiteralExpr) and (not IsSetType(TargetType)) and IsArrayType(TargetType, ElemType, IsFixed, DimN) then
  begin
    for I := 0 to TASTSetLiteralExpr(Assign.Expr).Elements.Count - 1 do
      if not TypesAreCompatible(ElemType, CheckExpr(TASTExpr(TASTSetLiteralExpr(Assign.Expr).Elements[I]))) then
        Error('E0308', Format('Array literal element %d is incompatible with "%s"', [I + 1, ElemType]), Assign.Line, Assign.Col);
  end
  else if not TypesAreCompatible(TargetType, ValueType) then
    Error('E0308', Format('Cannot assign "%s" to variable of type "%s"', [ValueType, TargetType]), Assign.Line, Assign.Col);

  if Assign.Target is TASTIdentifierExpr then
  begin
    Sym := FSymbols.Resolve(TASTIdentifierExpr(Assign.Target).Name);
    if Assigned(Sym) then
    begin
      if Sym.Kind = skConstant then
        Error('E0384', Format('Cannot assign a value to constant: "%s"', [Sym.Name]), Assign.Line, Assign.Col)
      else if not Sym.IsMutable then
        Error('E0384', Format('Cannot mutate immutable variable (declared with "let"): "%s"', [Sym.Name]), Assign.Line, Assign.Col);
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
    Error('E0308', Format('Condition of "if" statement must be Bool, found: "%s"', [CondType]), IfStmt.Line, IfStmt.Col);

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
    Error('E0308', Format('Condition of "while" loop must be Bool, found: "%s"', [CondType]), WhileStmt.Line, WhileStmt.Col);

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
        Error('E0308', Format('Key variable "%s" in "for..in" loop has type "%s", incompatible with "%s"',
          [ForStmt.VarName, VarSym.TypeName, KeyType]), ForStmt.Line, ForStmt.Col);

      if ForStmt.ValVarName <> '' then
      begin
        ValSym := FSymbols.Resolve(ForStmt.ValVarName);
        if not Assigned(ValSym) then
          FSymbols.Define(TSymbol.Create(ForStmt.ValVarName, skVariable, ValType, ForStmt.Line, ForStmt.Col, True))
        else if not TypesAreCompatible(ValSym.TypeName, ValType) then
          Error('E0308', Format('Value variable "%s" in "for..in" loop has type "%s", incompatible with "%s"',
            [ForStmt.ValVarName, ValSym.TypeName, ValType]), ForStmt.Line, ForStmt.Col);
      end;
    end
    else
    begin
      if ForStmt.ValVarName <> '' then
        Error('E0308', Format('Key-value iteration ("for k, v in ...") is only supported on maps, got: "%s"', [ColType]), ForStmt.Line, ForStmt.Col);

      ElemType := '';
      if IsDynamicArrayType(ColType, ElemType) then
      begin
        // ElemType populated
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
        Error('E0308', Format('Type "%s" is not iterable in a "for..in" loop', [ColType]), ForStmt.Line, ForStmt.Col);

      VarSym := FSymbols.Resolve(ForStmt.VarName);
      if not Assigned(VarSym) then
        FSymbols.Define(TSymbol.Create(ForStmt.VarName, skVariable, ElemType, ForStmt.Line, ForStmt.Col, True))
      else if not TypesAreCompatible(VarSym.TypeName, ElemType) then
        Error('E0308', Format('Loop variable "%s" in "for..in" has type "%s", incompatible with "%s"',
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
      Error('E0308', Format('Start bound of "for" loop must be integer, found: "%s"', [StartType]), ForStmt.Line, ForStmt.Col);

    if not IsIntegerType(EndType) and (EndType <> 'IntLiteral') then
      Error('E0308', Format('End bound of "for" loop must be integer, found: "%s"', [EndType]), ForStmt.Line, ForStmt.Col);
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
    Error('E0572', '"return" statement outside of a function body', Ret.Line, Ret.Col);

  if FCurrentFunction.IsProcedure then
  begin
    if Assigned(Ret.Expr) then
      Error('E0308', Format('Procedure "%s" cannot return a value; use bare "return;"', [FCurrentFunction.Name]), Ret.Line, Ret.Col);
    Exit;
  end;

  if not Assigned(Ret.Expr) then
    Error('E0308', Format('Function "%s" expects return type "%s", but found empty "return;"',
      [FCurrentFunction.Name, FCurrentFunction.ReturnType]), Ret.Line, Ret.Col);

  if FCurrentFunction.ReturnType <> '' then
    AnnotateMonadExpr(Ret.Expr, FCurrentFunction.ReturnType);
  RetType := CheckExpr(Ret.Expr);
  if (FCurrentFunction.Name = '__lambda') and (FCurrentFunction.ReturnType = '') then
  begin
    RetType := NormalizeTypeName(RetType);
    if RetType = 'IntLiteral' then RetType := 'Int32'
    else if RetType = 'FloatLiteral' then RetType := 'Float64';
    FCurrentFunction.ReturnType := RetType;
  end;
  AnnotateMonadExpr(Ret.Expr, FCurrentFunction.ReturnType);

  if not TypesAreCompatible(FCurrentFunction.ReturnType, RetType) then
    Error('E0308', Format('Function "%s" expects return type "%s", but statement returned "%s"',
      [FCurrentFunction.Name, FCurrentFunction.ReturnType, RetType]), Ret.Line, Ret.Col);
end;

function TAetherTypeChecker.CheckMatchInternal(MatchTarget: TASTExpr; Cases: TASTNodeList; IsExpr: Boolean; MLine, MCol: Integer): string;
var
  MatchedType: string;
  Sym: TSymbol;
  EnumDecl: TASTEnumDecl;
  MatchedVariant: TASTEnumVariant;
  I, J, K, B, PDot, P2: Integer;
  CaseNode: TASTMatchCase;
  PatternVal, Prefix, InnerType, ErrType, PatType, PatItem, LoStr, HiStr, LoT, HiT, BindType: string;
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
        Error('E0308', 'Match case guard condition must be of type Bool', ACase.Line, ACase.Col);
    end;

    if IsExpr then
    begin
      if not Assigned(ACase.ValueExpr) then
        Error('E0308', 'Arm of "match" expression must return an expression', ACase.Line, ACase.Col);
      ArmT := ResolveAliasType(CheckExpr(ACase.ValueExpr));
      if ArmT = 'IntLiteral' then ArmT := 'Int32'
      else if ArmT = 'FloatLiteral' then ArmT := 'Float64';
      if Result = '' then
        Result := ArmT
      else if TypesAreCompatible(Result, ArmT) or TypesAreCompatible(ArmT, Result) then
        Result := MergeInferredMonadTypes(Result, ArmT)
      else
        Error('E0308', Format('Arms of "match" expression have incompatible types: "%s" and "%s"', [Result, ArmT]), ACase.Line, ACase.Col);
    end
    else
    begin
      for SIdx := 0 to ACase.Body.Count - 1 do
        CheckStmt(TASTStmt(ACase.Body[SIdx]));
    end;
  end;

begin
  Result := '';
  MatchedType := NormalizeTypeName(ResolveAliasType(CheckExpr(MatchTarget)));
  if MatchedType = 'IntLiteral' then MatchedType := 'Int32'
  else if MatchedType = 'FloatLiteral' then MatchedType := 'Float64';
  HasWildcard := False;

  if IsExpr and (Cases.Count = 0) then
    Error('E0004', '"match" expression must have at least one arm', MLine, MCol);

  // Exhaustiveness Check for Enum (simple and payload ADTs)
  Sym := FSymbols.ResolveTypeSymbol(MatchedType);
  if not Assigned(Sym) then
    Sym := FSymbols.Resolve(MatchedType);
  if Assigned(Sym) and (Sym.Node is TASTEnumDecl) then
  begin
    EnumDecl := TASTEnumDecl(Sym.Node);
    CoveredVariants := TStringList.Create;
    try
      for I := 0 to Cases.Count - 1 do
      begin
        CaseNode := TASTMatchCase(Cases[I]);
        MatchedVariant := nil;
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
                Error('E0308', Format('Pattern "%s" does not belong to enum "%s"', [PatternVal, EnumDecl.Name]), CaseNode.Line, CaseNode.Col);
              PatternVal := Copy(PatternVal, PDot + 1, Length(PatternVal));
            end;
            FoundVariant := False;
            for J := 0 to EnumDecl.Variants.Count - 1 do
              if SameText(TASTEnumVariant(EnumDecl.Variants[J]).Name, PatternVal) then
              begin
                FoundVariant := True;
                MatchedVariant := TASTEnumVariant(EnumDecl.Variants[J]);
                Break;
              end;
            if not FoundVariant then
              Error('E0425', Format('Variant "%s" does not exist in enum "%s"', [PatternVal, EnumDecl.Name]), CaseNode.Line, CaseNode.Col);
            if not Assigned(CaseNode.Guard) then
              CoveredVariants.Add(UpperCase(PatternVal));
          end;
        end;

        FSymbols.EnterScope;
        try
          if CaseNode.Pattern.Bindings.Count > 0 then
          begin
            if Assigned(MatchedVariant) and (CaseNode.Pattern.Items.Count = 1) then
            begin
              if CaseNode.Pattern.Bindings.Count <> MatchedVariant.Fields.Count then
                Error('E0061', Format('Pattern "%s.%s" binds %d variable(s), but variant has %d field(s)',
                  [EnumDecl.Name, MatchedVariant.Name, CaseNode.Pattern.Bindings.Count, MatchedVariant.Fields.Count]),
                  CaseNode.Line, CaseNode.Col);
              for B := 0 to CaseNode.Pattern.Bindings.Count - 1 do
              begin
                if CaseNode.Pattern.Bindings[B] <> '_' then
                begin
                  BindType := NormalizeTypeName(TASTRecordField(MatchedVariant.Fields[B]).TypeName);
                  FSymbols.Define(TSymbol.Create(CaseNode.Pattern.Bindings[B], skVariable, BindType, CaseNode.Line, CaseNode.Col, False));
                end;
              end;
            end
            else if CaseNode.Pattern.Value = '_' then
            begin
              for B := 0 to CaseNode.Pattern.Bindings.Count - 1 do
                if CaseNode.Pattern.Bindings[B] <> '_' then
                  FSymbols.Define(TSymbol.Create(CaseNode.Pattern.Bindings[B], skVariable, EnumDecl.Name, CaseNode.Line, CaseNode.Col, False));
            end
            else
              Error('E0308', 'Cannot destructure payload fields inside multi-variant "|" pattern', CaseNode.Line, CaseNode.Col);
          end
          else if (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
          begin
            if CaseNode.Pattern.Value = '_' then
              FSymbols.Define(TSymbol.Create(CaseNode.Pattern.SubPattern, skVariable, EnumDecl.Name, CaseNode.Line, CaseNode.Col, False))
            else if Assigned(MatchedVariant) and (MatchedVariant.Fields.Count = 1) then
            begin
              BindType := NormalizeTypeName(TASTRecordField(MatchedVariant.Fields[0]).TypeName);
              FSymbols.Define(TSymbol.Create(CaseNode.Pattern.SubPattern, skVariable, BindType, CaseNode.Line, CaseNode.Col, False));
            end
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
            Error('E0004', Format('Non-exhaustive match on enum "%s". Missing variant "%s" (or add wildcard "_:")',
              [EnumDecl.Name, MissingVariant]), MLine, MCol);
          end;
        end;
      end;

      if IsExpr then
        for I := 0 to Cases.Count - 1 do
          AnnotateMonadExpr(TASTMatchCase(Cases[I]).ValueExpr, Result);
    finally
      CoveredVariants.Free;
    end;
    Exit;
  end;

  // Exhaustiveness Check for Result<T, E>
  if Pos('Result<', MatchedType) = 1 then
  begin
    SplitResultTypes(MatchedType, InnerType, ErrType);
    InnerType := NormalizeTypeName(InnerType);
    ErrType := NormalizeTypeName(ErrType);
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
      Error('E0004', 'Non-exhaustive match on Result. Both "Ok" and "Err" must be covered (or add "_:")',
        MLine, MCol);
    if IsExpr then
      for I := 0 to Cases.Count - 1 do
        AnnotateMonadExpr(TASTMatchCase(Cases[I]).ValueExpr, Result);
    Exit;
  end;

  // Exhaustiveness Check for Option<T>
  if Pos('Option<', MatchedType) = 1 then
  begin
    InnerType := NormalizeTypeName(Trim(Copy(MatchedType, 8, Length(MatchedType) - 8)));
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
        Error('E0308', Format('Invalid pattern "%s" for type "%s"; expected Some, None, or _', [PatternVal, MatchedType]), CaseNode.Line, CaseNode.Col);

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
      Error('E0004', Format('Non-exhaustive match on "%s". Cover both "Some" and "None" (or add "_:")', [MatchedType]),
        MLine, MCol);
    if IsExpr then
      for I := 0 to Cases.Count - 1 do
        AnnotateMonadExpr(TASTMatchCase(Cases[I]).ValueExpr, Result);
    Exit;
  end;

  // For scalar types (Int, String, Char, Bool), validate multi-patterns, ranges, guards, and bodies
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
            Error('E0308', Format('Range pattern "%s" requires integer or Char expression, got "%s"', [PatItem, MatchedType]), CaseNode.Line, CaseNode.Col);
          LoT := ClassifyMatchAtomType(LoStr, CaseNode.Line, CaseNode.Col);
          HiT := ClassifyMatchAtomType(HiStr, CaseNode.Line, CaseNode.Col);
          if (not TypesAreCompatible(MatchedType, LoT)) or (not TypesAreCompatible(MatchedType, HiT)) then
            Error('E0308', Format('Range bounds "%s" (%s..%s) are incompatible with type "%s"', [PatItem, LoT, HiT, MatchedType]), CaseNode.Line, CaseNode.Col);
        end
        else
        begin
          PatType := ClassifyMatchAtomType(PatItem, CaseNode.Line, CaseNode.Col);
          if not TypesAreCompatible(MatchedType, PatType) then
            Error('E0308', Format('Pattern "%s" (%s) is incompatible with expression of type "%s"', [PatItem, PatType, MatchedType]), CaseNode.Line, CaseNode.Col);
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
  else if Stmt is TASTExprStmt then
    CheckExpr(TASTExprStmt(Stmt).Expr)
  else if Stmt is TASTYieldStmt then
    // Thread scheduler yield
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
    // Low-level assembly block: accepted without semantic type checking
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
        Error('E0308', '"raise" statement expects a String message', Stmt.Line, Stmt.Col);
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
      Error('E0308', Format('"repeat...until" condition must be of type Bool, found: "%s"', [CondType]), RepeatStmt.Line, RepeatStmt.Col);
  end;
end;

procedure TAetherTypeChecker.CheckBreak(BreakStmt: TASTBreakStmt);
begin
  if FLoopDepth <= 0 then
    Error('E0310', '"break" can only be used inside a loop (for, while, repeat)', BreakStmt.Line, BreakStmt.Col);
end;

procedure TAetherTypeChecker.CheckContinue(ContStmt: TASTContinueStmt);
begin
  if FLoopDepth <= 0 then
    Error('E0310', '"continue" can only be used inside a loop (for, while, repeat)', ContStmt.Line, ContStmt.Col);
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
        Error('E0308', Format('Constant "%s" is declared as "%s", but its value has type "%s"',
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
  Sym, ExistingSym: TSymbol;
begin
  for I := 0 to AModule.Functions.Count - 1 do
  begin
    Func := TASTFunction(AModule.Functions[I]);
    ExistingSym := FSymbols.Resolve(Func.Name);
    // Preserve polymorphic built-in intrinsics in SymbolTable (Line = 0, Node = nil)
    if Assigned(ExistingSym) and (ExistingSym.Kind = skFunction) and (ExistingSym.Line = 0) and (ExistingSym.Node = nil) then
      Continue;
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
  Sym: TSymbol;
  RecDecl: TASTRecordDecl;
begin
  if VarDecl.TypeName = '' then
  begin
    if not Assigned(VarDecl.InitialExpr) then
      Error('E0282', Format('Variable "%s" requires an explicit type or an initializer expression', [VarDecl.Name]), VarDecl.Line, VarDecl.Col);
    VarInitType := CheckExpr(VarDecl.InitialExpr);
    if VarDecl.InitialExpr is TASTSetLiteralExpr then
      VarDecl.TypeName := 'array of ' + InferArrayLiteralElemType(TASTSetLiteralExpr(VarDecl.InitialExpr))
    else if VarDecl.InitialExpr is TASTMapLiteralExpr then
    begin
      if VarInitType = 'MapLiteral' then
        Error('E0282', Format('Cannot infer types for empty map "[:]" on "%s"; declare "map[K]V" explicitly', [VarDecl.Name]), VarDecl.Line, VarDecl.Col);
      VarDecl.TypeName := VarInitType;
    end
    else if VarInitType = 'IntLiteral' then
      VarDecl.TypeName := 'Int32'
    else if VarInitType = 'FloatLiteral' then
      VarDecl.TypeName := 'Float64'
    else if VarInitType = 'Option<IntLiteral>' then
      VarDecl.TypeName := 'Option<Int32>'
    else if VarInitType = 'Option<FloatLiteral>' then
      VarDecl.TypeName := 'Option<Float64>'
    else if VarInitType = 'NilLiteral' then
      Error('E0282', Format('Cannot infer type of "%s" from "nil" alone; declare the type explicitly', [VarDecl.Name]), VarDecl.Line, VarDecl.Col)
    else
      VarDecl.TypeName := VarInitType;
  end
  else
    VarInitType := '';

  VarDecl.TypeName := NormalizeTypeName(VarDecl.TypeName);

  if not FSymbols.ResolveType(VarDecl.TypeName) then
    Error('E0412', Format('Type "%s" of variable "%s" not found', [VarDecl.TypeName, VarDecl.Name]), VarDecl.Line, VarDecl.Col);

  if VarDecl.ExpectedTupleArity > 0 then
  begin
    Sym := FSymbols.ResolveTypeSymbol(ResolveAliasType(VarDecl.TypeName));
    if (not Assigned(Sym)) or (not (Sym.Node is TASTRecordDecl)) or (Pos('Tuple', TASTRecordDecl(Sym.Node).Name) <> 1) then
      Error('E0308', Format('Cannot destructure non-tuple type "%s"', [VarDecl.TypeName]), VarDecl.Line, VarDecl.Col);
    RecDecl := TASTRecordDecl(Sym.Node);
    if RecDecl.Fields.Count <> VarDecl.ExpectedTupleArity then
      Error('E0308', Format('Tuple destructuring expects %d element(s), but tuple has %d',
        [VarDecl.ExpectedTupleArity, RecDecl.Fields.Count]), VarDecl.Line, VarDecl.Col);
  end;

  if Assigned(VarDecl.InitialExpr) then
  begin
    AnnotateMonadExpr(VarDecl.InitialExpr, VarDecl.TypeName);
    if VarInitType = '' then
      VarInitType := CheckExpr(VarDecl.InitialExpr);
    AnnotateMonadExpr(VarDecl.InitialExpr, VarDecl.TypeName);
    if (VarDecl.InitialExpr is TASTSetLiteralExpr) and (not IsSetType(VarDecl.TypeName)) and
       IsArrayType(VarDecl.TypeName, ElemType, IsFixed, DimN) then
    begin
      for I := 0 to TASTSetLiteralExpr(VarDecl.InitialExpr).Elements.Count - 1 do
        if not TypesAreCompatible(ElemType, CheckExpr(TASTExpr(TASTSetLiteralExpr(VarDecl.InitialExpr).Elements[I]))) then
          Error('E0308', Format('Array literal element %d is incompatible with "%s"', [I + 1, ElemType]), VarDecl.Line, VarDecl.Col);
    end
    else if not TypesAreCompatible(VarDecl.TypeName, VarInitType) then
      Error('E0308', Format('Initializer for "%s" expects "%s", but got "%s"',
        [VarDecl.Name, VarDecl.TypeName, VarInitType]), VarDecl.Line, VarDecl.Col);
  end;

  Sym := TSymbol.Create(VarDecl.Name, skVariable, VarDecl.TypeName, VarDecl.Line, VarDecl.Col, VarDecl.IsMutable);
  Sym.IsPublic := VarDecl.IsPublic;
  Sym.SourceModule := VarDecl.SourceModule;
  FSymbols.Define(Sym);
end;

function StmtListAlwaysReturns(Stmts: TASTNodeList): Boolean;
var
  I, K: Integer;
  S: TASTStmt;
  IfS: TASTIfStmt;
  MS: TASTMatchStmt;
  AllCasesRet: Boolean;
begin
  Result := False;
  if not Assigned(Stmts) then Exit;
  for I := 0 to Stmts.Count - 1 do
  begin
    S := TASTStmt(Stmts[I]);
    if (S is TASTReturnStmt) or (S is TASTRaiseStmt) then
      Exit(True)
    else if S is TASTIfStmt then
    begin
      IfS := TASTIfStmt(S);
      if (IfS.ElseBranch.Count > 0) and
         StmtListAlwaysReturns(IfS.ThenBranch) and
         StmtListAlwaysReturns(IfS.ElseBranch) then
        Exit(True);
    end
    else if S is TASTMatchStmt then
    begin
      MS := TASTMatchStmt(S);
      if MS.Cases.Count > 0 then
      begin
        AllCasesRet := True;
        for K := 0 to MS.Cases.Count - 1 do
        begin
          if not StmtListAlwaysReturns(TASTMatchCase(MS.Cases[K]).Body) then
          begin
            AllCasesRet := False;
            Break;
          end;
        end;
        if AllCasesRet then Exit(True);
      end;
    end
    else if S is TASTUnsafeStmt then
    begin
      if StmtListAlwaysReturns(TASTUnsafeStmt(S).Body) then Exit(True);
    end
    else if S is TASTTryStmt then
    begin
      if StmtListAlwaysReturns(TASTTryStmt(S).TryBody) and
         ((TASTTryStmt(S).ExceptBody.Count = 0) or StmtListAlwaysReturns(TASTTryStmt(S).ExceptBody)) then
        Exit(True);
    end;
  end;
end;

procedure TAetherTypeChecker.CheckFunction(Func: TASTFunction);
var
  I: Integer;
  Param: TASTParam;
begin
  FCurrentFunction := Func;
  FSymbols.EnterScope;
  try
    if (Func.GenericParams.Count = 0) and (Func.GenericParam = '') then
      Func.ReturnType := NormalizeTypeName(Func.ReturnType);

    if (not Func.IsProcedure) and ((Func.ReturnType = '') or SameText(Func.ReturnType, 'Void')) then
      Error('E0308', Format('Function "%s" must declare a non-Void return type (use "procedure" instead)', [Func.Name]), Func.Line, Func.Col);

    // Register parameters in function scope
    for I := 0 to Func.Params.Count - 1 do
    begin
      Param := TASTParam(Func.Params[I]);
      if (Func.GenericParams.Count = 0) and (Func.GenericParam = '') then
        Param.TypeName := NormalizeTypeName(Param.TypeName);
      if not FSymbols.ResolveType(Param.TypeName) then
        Error('E0412', Format('Type "%s" of parameter "%s" not found', [Param.TypeName, Param.Name]), Param.Line, Param.Col);
      FSymbols.Define(TSymbol.Create(Param.Name, skVariable, Param.TypeName, Param.Line, Param.Col, Param.Ownership = owMutBorrow, Param.Ownership));
    end;

    // Require contracts
    for I := 0 to Func.Requires.Count - 1 do
    begin
      if CheckExpr(TASTExpr(Func.Requires[I])) <> 'Bool' then
        Error('E0308', '"require" contract expression must be of type Bool', Func.Line, Func.Col);
    end;

    // Ensure contracts (with access to special "result" variable when non-Void)
    if Func.Ensures.Count > 0 then
    begin
      FSymbols.EnterScope;
      try
        if (not Func.IsProcedure) and (Func.ReturnType <> '') and (not SameText(Func.ReturnType, 'Void')) then
          FSymbols.Define(TSymbol.Create('result', skVariable, Func.ReturnType, Func.Line, Func.Col, False));
        for I := 0 to Func.Ensures.Count - 1 do
        begin
          if CheckExpr(TASTExpr(Func.Ensures[I])) <> 'Bool' then
            Error('E0308', '"ensure" contract expression must be of type Bool', Func.Line, Func.Col);
        end;
      finally
        FSymbols.LeaveScope;
      end;
    end;

    // Extern functions have no body or local variables
    if Func.IsExtern then
      Exit;

    // Register local variables
    for I := 0 to Func.LocalVars.Count - 1 do
      CheckVarDecl(TASTVarDecl(Func.LocalVars[I]));

    // Type-check function body
    for I := 0 to Func.Body.Count - 1 do
      CheckStmt(TASTStmt(Func.Body[I]));

    // Verify guaranteed return on all paths for functions (not procedures / templates)
    if (not Func.IsProcedure) and (Func.GenericParams.Count = 0) and (Func.GenericParam = '') and (not StmtListAlwaysReturns(Func.Body)) then
      Error('E0308', Format('Not all code paths in function "%s" return a value of type "%s"',
        [Func.Name, Func.ReturnType]), Func.Line, Func.Col);
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
      Error('E0425', Format('Type "%s" not found', [Impl.TargetTypeName]), Impl.Line, Impl.Col);

    TraitDecl := nil;
    if Impl.TraitName <> '' then
    begin
      SymTrait := FSymbols.Resolve(Impl.TraitName);
      if (not Assigned(SymTrait)) or (SymTrait.Kind <> skTrait) then
      begin
        if SameText(Impl.TraitName, 'Drop') then
        begin
          Found := False;
          for IM := 0 to Impl.Methods.Count - 1 do
          begin
            ImplMethod := TASTFunction(Impl.Methods[IM]);
            if SameText(ImplMethod.Name, 'Drop') then
            begin
              Found := True;
              if ImplMethod.Params.Count <> 1 then
                Error('E0053', Format('Method "Drop" on "%s" must take exactly 1 parameter (self)', [Impl.TargetTypeName]), ImplMethod.Line, ImplMethod.Col);
              if (ImplMethod.ReturnType <> '') and (not SameText(ImplMethod.ReturnType, 'Void')) then
                Error('E0053', Format('Method "Drop" on "%s" must not return a value', [Impl.TargetTypeName]), ImplMethod.Line, ImplMethod.Col);
            end;
          end;
          if not Found then
            Error('E0046', Format('Type "%s" does not implement required method "Drop" of trait "Drop"', [Impl.TargetTypeName]), Impl.Line, Impl.Col);
        end
        else
          Error('E0425', Format('Trait "%s" not found', [Impl.TraitName]), Impl.Line, Impl.Col);
      end
      else
      begin
        TraitDecl := TASTTraitDecl(SymTrait.Node);

        // Completeness check: were all trait methods implemented?
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
            Error('E0046', Format('Type "%s" does not implement required method "%s" of trait "%s"',
              [Impl.TargetTypeName, TraitMethod.Name, Impl.TraitName]), Impl.Line, Impl.Col);
        end;
      end;
    end;

    // Signature validation and method registration
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
          // Check parameters
          if ImplMethod.Params.Count <> TraitMethod.Params.Count then
            Error('E0053', Format('Method "%s" signature on "%s" mismatches trait "%s" definition (parameter count mismatch: expected %d, got %d)',
              [ImplMethod.Name, Impl.TargetTypeName, Impl.TraitName, TraitMethod.Params.Count, ImplMethod.Params.Count]), ImplMethod.Line, ImplMethod.Col);

          // Check return type
          ExpectedRetType := TraitMethod.ReturnType;
          if SameText(ExpectedRetType, 'Self') then
            ExpectedRetType := Impl.TargetTypeName;

          if not SameText(ImplMethod.ReturnType, ExpectedRetType) then
            Error('E0053', Format('Method "%s" signature on "%s" mismatches trait "%s" definition (return type mismatch: expected "%s", got "%s")',
              [ImplMethod.Name, Impl.TargetTypeName, Impl.TraitName, ExpectedRetType, ImplMethod.ReturnType]), ImplMethod.Line, ImplMethod.Col);

          for P := 0 to TraitMethod.Params.Count - 1 do
          begin
            ExpectedParamType := TASTParam(TraitMethod.Params[P]).TypeName;
            if SameText(ExpectedParamType, 'Self') then
              ExpectedParamType := Impl.TargetTypeName;

            if not SameText(ExpectedParamType, TASTParam(ImplMethod.Params[P]).TypeName) then
              Error('E0053', Format('Method "%s" signature on "%s" mismatches trait "%s" definition for parameter "%s" (expected "%s", got "%s")',
                [ImplMethod.Name, Impl.TargetTypeName, Impl.TraitName, TASTParam(ImplMethod.Params[P]).Name, ExpectedParamType, TASTParam(ImplMethod.Params[P]).TypeName]), ImplMethod.Line, ImplMethod.Col);
          end;
        end;
      end;

      // Canonical method name mangling for static dispatch
      MangledName := Impl.TargetTypeName + '_' + ImplMethod.Name;
      ImplMethod.OriginalName := ImplMethod.Name;
      ImplMethod.Name := MangledName;

      // Register trait (or inherent impl) implementation for lookup
      New(Info);
      Info^.TargetType := Impl.TargetTypeName;
      Info^.TraitName := Impl.TraitName;
      Info^.OriginalMethod := ImplMethod.OriginalName;
      Info^.MangledMethod := MangledName;
      FTraitImpls.Add(Info);

      // Add method to AModule.Functions for checking and emission (registered by RegisterFunctions)
      AModule.Functions.Add(ImplMethod);
    end;

    // Detach nodes from Impl.Methods to avoid double-free when freeing the module
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

procedure TAetherTypeChecker.SubstituteGenericInExpr(Expr: TASTExpr; GenericParams, ConcreteArgs: TStringList);
var
  I: Integer;
  CallE: TASTCallExpr;
  ME: TASTMatchExpr;
  CaseN: TASTMatchCase;
begin
  if not Assigned(Expr) then Exit;
  if Expr is TASTMemberAccessExpr then
    SubstituteGenericInExpr(TASTMemberAccessExpr(Expr).Target, GenericParams, ConcreteArgs)
  else if Expr is TASTBinaryExpr then
  begin
    SubstituteGenericInExpr(TASTBinaryExpr(Expr).Left, GenericParams, ConcreteArgs);
    SubstituteGenericInExpr(TASTBinaryExpr(Expr).Right, GenericParams, ConcreteArgs);
  end
  else if Expr is TASTUnaryExpr then
    SubstituteGenericInExpr(TASTUnaryExpr(Expr).Expr, GenericParams, ConcreteArgs)
  else if Expr is TASTAwaitExpr then
    SubstituteGenericInExpr(TASTAwaitExpr(Expr).Expr, GenericParams, ConcreteArgs)
  else if Expr is TASTSpawnExpr then
    SubstituteGenericInExpr(TASTSpawnExpr(Expr).CallExpr, GenericParams, ConcreteArgs)
  else if Expr is TASTCallExpr then
  begin
    CallE := TASTCallExpr(Expr);
    if Assigned(CallE.CalleeExpr) then
      SubstituteGenericInExpr(CallE.CalleeExpr, GenericParams, ConcreteArgs);
    for I := 0 to CallE.GenericArgs.Count - 1 do
      CallE.GenericArgs[I] := NormalizeTypeName(SubstituteGenericType(CallE.GenericArgs[I], GenericParams, ConcreteArgs));
    if (SameText(CallE.Callee, 'Default') or SameText(CallE.Callee, 'SizeOf')) and
       (CallE.Args.Count > 0) and (TASTCallArg(CallE.Args[0]).Expr is TASTIdentifierExpr) then
    begin
      TASTIdentifierExpr(TASTCallArg(CallE.Args[0]).Expr).Name :=
        NormalizeTypeName(SubstituteGenericType(TASTIdentifierExpr(TASTCallArg(CallE.Args[0]).Expr).Name, GenericParams, ConcreteArgs));
    end;
    for I := 0 to CallE.Args.Count - 1 do
      SubstituteGenericInExpr(TASTCallArg(CallE.Args[I]).Expr, GenericParams, ConcreteArgs);
  end
  else if Expr is TASTIndexExpr then
  begin
    SubstituteGenericInExpr(TASTIndexExpr(Expr).Target, GenericParams, ConcreteArgs);
    for I := 0 to TASTIndexExpr(Expr).Indices.Count - 1 do
      SubstituteGenericInExpr(TASTExpr(TASTIndexExpr(Expr).Indices[I]), GenericParams, ConcreteArgs);
  end
  else if Expr is TASTSetLiteralExpr then
  begin
    for I := 0 to TASTSetLiteralExpr(Expr).Elements.Count - 1 do
      SubstituteGenericInExpr(TASTExpr(TASTSetLiteralExpr(Expr).Elements[I]), GenericParams, ConcreteArgs);
  end
  else if Expr is TASTMapLiteralExpr then
  begin
    for I := 0 to TASTMapLiteralExpr(Expr).Keys.Count - 1 do
    begin
      SubstituteGenericInExpr(TASTExpr(TASTMapLiteralExpr(Expr).Keys[I]), GenericParams, ConcreteArgs);
      SubstituteGenericInExpr(TASTExpr(TASTMapLiteralExpr(Expr).Values[I]), GenericParams, ConcreteArgs);
    end;
  end
  else if Expr is TASTIfExpr then
  begin
    SubstituteGenericInExpr(TASTIfExpr(Expr).Condition, GenericParams, ConcreteArgs);
    SubstituteGenericInExpr(TASTIfExpr(Expr).ThenExpr, GenericParams, ConcreteArgs);
    SubstituteGenericInExpr(TASTIfExpr(Expr).ElseExpr, GenericParams, ConcreteArgs);
  end
  else if Expr is TASTMatchExpr then
  begin
    ME := TASTMatchExpr(Expr);
    SubstituteGenericInExpr(ME.Expr, GenericParams, ConcreteArgs);
    for I := 0 to ME.Cases.Count - 1 do
    begin
      CaseN := TASTMatchCase(ME.Cases[I]);
      SubstituteGenericInExpr(CaseN.Guard, GenericParams, ConcreteArgs);
      SubstituteGenericInExpr(CaseN.ValueExpr, GenericParams, ConcreteArgs);
    end;
  end
  else if Expr is TASTTupleLiteralExpr then
  begin
    for I := 0 to TASTTupleLiteralExpr(Expr).Elements.Count - 1 do
      SubstituteGenericInExpr(TASTExpr(TASTTupleLiteralExpr(Expr).Elements[I]), GenericParams, ConcreteArgs);
  end
  else if Expr is TASTLambdaExpr then
  begin
    with TASTLambdaExpr(Expr) do
    begin
      for I := 0 to Params.Count - 1 do
        if TASTParam(Params[I]).TypeName <> '' then
          TASTParam(Params[I]).TypeName := NormalizeTypeName(SubstituteGenericType(TASTParam(Params[I]).TypeName, GenericParams, ConcreteArgs));
      if ReturnType <> '' then
        ReturnType := NormalizeTypeName(SubstituteGenericType(ReturnType, GenericParams, ConcreteArgs));
      if Assigned(BodyExpr) then
        SubstituteGenericInExpr(BodyExpr, GenericParams, ConcreteArgs)
      else
        SubstituteGenericInStmts(BodyStmts, GenericParams, ConcreteArgs);
    end;
  end;
end;

procedure TAetherTypeChecker.SubstituteGenericInStmts(Stmts: TASTNodeList; GenericParams, ConcreteArgs: TStringList);
var
  I, J: Integer;
  S: TASTStmt;
  VD: TASTVarDecl;
  IfS: TASTIfStmt;
  MS: TASTMatchStmt;
  CN: TASTMatchCase;
begin
  if not Assigned(Stmts) then Exit;
  for I := 0 to Stmts.Count - 1 do
  begin
    S := TASTStmt(Stmts[I]);
    if S is TASTVarDeclStmt then
    begin
      for J := 0 to TASTVarDeclStmt(S).Decls.Count - 1 do
      begin
        VD := TASTVarDecl(TASTVarDeclStmt(S).Decls[J]);
        if VD.TypeName <> '' then
          VD.TypeName := NormalizeTypeName(SubstituteGenericType(VD.TypeName, GenericParams, ConcreteArgs));
        SubstituteGenericInExpr(VD.InitialExpr, GenericParams, ConcreteArgs);
      end;
    end
    else if S is TASTAssignStmt then
    begin
      SubstituteGenericInExpr(TASTAssignStmt(S).Target, GenericParams, ConcreteArgs);
      SubstituteGenericInExpr(TASTAssignStmt(S).Expr, GenericParams, ConcreteArgs);
    end
    else if S is TASTCallStmt then
      SubstituteGenericInExpr(TASTCallStmt(S).CallExpr, GenericParams, ConcreteArgs)
    else if S is TASTExprStmt then
      SubstituteGenericInExpr(TASTExprStmt(S).Expr, GenericParams, ConcreteArgs)
    else if S is TASTReturnStmt then
      SubstituteGenericInExpr(TASTReturnStmt(S).Expr, GenericParams, ConcreteArgs)
    else if S is TASTIfStmt then
    begin
      IfS := TASTIfStmt(S);
      SubstituteGenericInExpr(IfS.Condition, GenericParams, ConcreteArgs);
      SubstituteGenericInStmts(IfS.ThenBranch, GenericParams, ConcreteArgs);
      SubstituteGenericInStmts(IfS.ElseBranch, GenericParams, ConcreteArgs);
    end
    else if S is TASTWhileStmt then
    begin
      SubstituteGenericInExpr(TASTWhileStmt(S).Condition, GenericParams, ConcreteArgs);
      SubstituteGenericInStmts(TASTWhileStmt(S).Body, GenericParams, ConcreteArgs);
    end
    else if S is TASTForStmt then
    begin
      SubstituteGenericInExpr(TASTForStmt(S).StartExpr, GenericParams, ConcreteArgs);
      SubstituteGenericInExpr(TASTForStmt(S).EndExpr, GenericParams, ConcreteArgs);
      SubstituteGenericInExpr(TASTForStmt(S).CollectionExpr, GenericParams, ConcreteArgs);
      SubstituteGenericInStmts(TASTForStmt(S).Body, GenericParams, ConcreteArgs);
    end
    else if S is TASTRepeatStmt then
    begin
      SubstituteGenericInStmts(TASTRepeatStmt(S).Body, GenericParams, ConcreteArgs);
      SubstituteGenericInExpr(TASTRepeatStmt(S).Condition, GenericParams, ConcreteArgs);
    end
    else if S is TASTMatchStmt then
    begin
      MS := TASTMatchStmt(S);
      SubstituteGenericInExpr(MS.Expr, GenericParams, ConcreteArgs);
      for J := 0 to MS.Cases.Count - 1 do
      begin
        CN := TASTMatchCase(MS.Cases[J]);
        SubstituteGenericInExpr(CN.Guard, GenericParams, ConcreteArgs);
        SubstituteGenericInStmts(CN.Body, GenericParams, ConcreteArgs);
      end;
    end
    else if S is TASTUnsafeStmt then
      SubstituteGenericInStmts(TASTUnsafeStmt(S).Body, GenericParams, ConcreteArgs)
    else if S is TASTDeferStmt then
    begin
      if Assigned(TASTDeferStmt(S).Stmt) then
      begin
        // Defer holds a single stmt; wrap check cleanly via local handling
        if TASTDeferStmt(S).Stmt is TASTCallStmt then
          SubstituteGenericInExpr(TASTCallStmt(TASTDeferStmt(S).Stmt).CallExpr, GenericParams, ConcreteArgs)
        else if TASTDeferStmt(S).Stmt is TASTAssignStmt then
        begin
          SubstituteGenericInExpr(TASTAssignStmt(TASTDeferStmt(S).Stmt).Target, GenericParams, ConcreteArgs);
          SubstituteGenericInExpr(TASTAssignStmt(TASTDeferStmt(S).Stmt).Expr, GenericParams, ConcreteArgs);
        end;
      end;
    end
    else if S is TASTTryStmt then
    begin
      SubstituteGenericInStmts(TASTTryStmt(S).TryBody, GenericParams, ConcreteArgs);
      SubstituteGenericInStmts(TASTTryStmt(S).ExceptBody, GenericParams, ConcreteArgs);
    end
    else if S is TASTRaiseStmt then
      SubstituteGenericInExpr(TASTRaiseStmt(S).Expr, GenericParams, ConcreteArgs);
  end;
end;

function TAetherTypeChecker.MonomorphizeFunction(OriginalFunc: TASTFunction; ConcreteArgs: TStringList): TASTFunction;
var
  I: Integer;
  Param: TASTParam;
  PType, MangledName: string;
  VarDecl: TASTVarDecl;
  VType: string;
  ReqExpr, EnsExpr: TASTExpr;
begin
  if ConcreteArgs.Count = 1 then
    MangledName := OriginalFunc.Name + '_' + MangleTypeName(ConcreteArgs[0])
  else
  begin
    MangledName := OriginalFunc.Name;
    for I := 0 to ConcreteArgs.Count - 1 do
      MangledName := MangledName + '__' + MangleTypeName(ConcreteArgs[I]);
  end;

  Result := TASTFunction.Create(OriginalFunc.Line, OriginalFunc.Col, MangledName, OriginalFunc.ReturnType);
  Result.IsProcedure := OriginalFunc.IsProcedure;
  Result.IsAsync := OriginalFunc.IsAsync;
  Result.IsPublic := OriginalFunc.IsPublic;
  Result.SourceModule := OriginalFunc.SourceModule;
  if not Result.IsProcedure then
    Result.ReturnType := NormalizeTypeName(SubstituteGenericType(Result.ReturnType, OriginalFunc.GenericParams, ConcreteArgs));

  for I := 0 to OriginalFunc.Params.Count - 1 do
  begin
    Param := TASTParam(OriginalFunc.Params[I]);
    PType := NormalizeTypeName(SubstituteGenericType(Param.TypeName, OriginalFunc.GenericParams, ConcreteArgs));
    Result.Params.Add(TASTParam.Create(Param.Line, Param.Col, Param.Name, PType, Param.Ownership));
  end;

  for I := 0 to OriginalFunc.LocalVars.Count - 1 do
  begin
    VarDecl := TASTVarDecl(OriginalFunc.LocalVars[I]);
    VType := '';
    if VarDecl.TypeName <> '' then
      VType := NormalizeTypeName(SubstituteGenericType(VarDecl.TypeName, OriginalFunc.GenericParams, ConcreteArgs));
    Result.LocalVars.Add(TASTVarDecl.Create(VarDecl.Line, VarDecl.Col, VarDecl.Name, VType, TASTExpr(CloneASTNode(VarDecl.InitialExpr)), VarDecl.IsMutable));
    SubstituteGenericInExpr(TASTVarDecl(Result.LocalVars[Result.LocalVars.Count - 1]).InitialExpr, OriginalFunc.GenericParams, ConcreteArgs);
  end;

  for I := 0 to OriginalFunc.Requires.Count - 1 do
  begin
    ReqExpr := TASTExpr(CloneASTNode(TASTExpr(OriginalFunc.Requires[I])));
    SubstituteGenericInExpr(ReqExpr, OriginalFunc.GenericParams, ConcreteArgs);
    Result.Requires.Add(ReqExpr);
  end;

  for I := 0 to OriginalFunc.Ensures.Count - 1 do
  begin
    EnsExpr := TASTExpr(CloneASTNode(TASTExpr(OriginalFunc.Ensures[I])));
    SubstituteGenericInExpr(EnsExpr, OriginalFunc.GenericParams, ConcreteArgs);
    Result.Ensures.Add(EnsExpr);
  end;

  for I := 0 to OriginalFunc.Body.Count - 1 do
    Result.Body.Add(CloneASTNode(TASTStmt(OriginalFunc.Body[I])));
  SubstituteGenericInStmts(Result.Body, OriginalFunc.GenericParams, ConcreteArgs);
end;

procedure TAetherTypeChecker.NormalizeModuleSignatures(AModule: TASTModule);
var
  I, J, K: Integer;
  Node: TASTNode;
  Rec: TASTRecordDecl;
  Enm: TASTEnumDecl;
  VarNode: TASTEnumVariant;
  Func: TASTFunction;
  TraitD: TASTTraitDecl;
  ImplD: TASTImplDecl;
begin
  for I := 0 to AModule.Types.Count - 1 do
  begin
    Node := AModule.Types[I];
    if Node is TASTRecordDecl then
    begin
      Rec := TASTRecordDecl(Node);
      if Rec.GenericParams.Count = 0 then
        for J := 0 to Rec.Fields.Count - 1 do
          TASTRecordField(Rec.Fields[J]).TypeName := NormalizeTypeName(TASTRecordField(Rec.Fields[J]).TypeName);
    end
    else if Node is TASTEnumDecl then
    begin
      Enm := TASTEnumDecl(Node);
      for J := 0 to Enm.Variants.Count - 1 do
      begin
        VarNode := TASTEnumVariant(Enm.Variants[J]);
        for K := 0 to VarNode.Fields.Count - 1 do
          TASTRecordField(VarNode.Fields[K]).TypeName := NormalizeTypeName(TASTRecordField(VarNode.Fields[K]).TypeName);
      end;
    end
    else if Node is TASTArrayDecl then
      TASTArrayDecl(Node).ElemType := NormalizeTypeName(TASTArrayDecl(Node).ElemType)
    else if Node is TASTMapDecl then
    begin
      TASTMapDecl(Node).KeyType := NormalizeTypeName(TASTMapDecl(Node).KeyType);
      TASTMapDecl(Node).ValType := NormalizeTypeName(TASTMapDecl(Node).ValType);
    end
    else if Node is TASTTypeAliasDecl then
      TASTTypeAliasDecl(Node).TargetType := NormalizeTypeName(TASTTypeAliasDecl(Node).TargetType);
  end;

  for I := 0 to AModule.Traits.Count - 1 do
  begin
    TraitD := TASTTraitDecl(AModule.Traits[I]);
    for J := 0 to TraitD.Methods.Count - 1 do
    begin
      Func := TASTFunction(TraitD.Methods[J]);
      if not Func.IsProcedure then
        Func.ReturnType := NormalizeTypeName(Func.ReturnType);
      for K := 0 to Func.Params.Count - 1 do
        TASTParam(Func.Params[K]).TypeName := NormalizeTypeName(TASTParam(Func.Params[K]).TypeName);
    end;
  end;

  for I := 0 to AModule.Impls.Count - 1 do
  begin
    ImplD := TASTImplDecl(AModule.Impls[I]);
    ImplD.TargetTypeName := NormalizeTypeName(ImplD.TargetTypeName);
    for J := 0 to ImplD.Methods.Count - 1 do
    begin
      Func := TASTFunction(ImplD.Methods[J]);
      if not Func.IsProcedure then
        Func.ReturnType := NormalizeTypeName(Func.ReturnType);
      for K := 0 to Func.Params.Count - 1 do
        TASTParam(Func.Params[K]).TypeName := NormalizeTypeName(TASTParam(Func.Params[K]).TypeName);
    end;
  end;

  for I := 0 to AModule.Functions.Count - 1 do
  begin
    Func := TASTFunction(AModule.Functions[I]);
    if (Func.GenericParams.Count = 0) and (Func.GenericParam = '') then
    begin
      if not Func.IsProcedure then
        Func.ReturnType := NormalizeTypeName(Func.ReturnType);
      for K := 0 to Func.Params.Count - 1 do
        TASTParam(Func.Params[K]).TypeName := NormalizeTypeName(TASTParam(Func.Params[K]).TypeName);
    end;
  end;
end;

procedure TAetherTypeChecker.CheckModule(AModule: TASTModule);
var
  I: Integer;
  Func: TASTFunction;
  VD: TASTVarDecl;
begin
  FModule := AModule;
  FCurrentSourceModule := '';
  RegisterConstants(AModule);
  RegisterTypes(AModule);
  NormalizeModuleSignatures(AModule);
  RegisterTraits(AModule);
  RegisterImpls(AModule);
  RegisterFunctions(AModule);

  for I := 0 to AModule.ModuleVars.Count - 1 do
  begin
    VD := TASTVarDecl(AModule.ModuleVars[I]);
    FCurrentSourceModule := VD.SourceModule;
    CheckVarDecl(VD);
  end;
  FCurrentSourceModule := '';

  I := 0;
  while I < AModule.Functions.Count do
  begin
    Func := TASTFunction(AModule.Functions[I]);
    if (Func.GenericParams.Count = 0) and (Func.GenericParam = '') and (not Func.IsInterfaceDecl) then
      CheckFunction(Func);
    Inc(I);
  end;

  if (AModule.InitBody.Count > 0) or (AModule.FiniBody.Count > 0) then
  begin
    FCurrentSourceModule := AModule.Name;
    FSymbols.EnterScope;
    try
      for I := 0 to AModule.InitBody.Count - 1 do
        CheckStmt(TASTStmt(AModule.InitBody[I]));
      for I := 0 to AModule.FiniBody.Count - 1 do
        CheckStmt(TASTStmt(AModule.FiniBody[I]));
    finally
      FSymbols.LeaveScope;
      FCurrentSourceModule := '';
    end;
  end;

  if Assigned(AModule.ProgramBlock) then
    CheckProgramBlock(AModule.ProgramBlock);
end;

end.
