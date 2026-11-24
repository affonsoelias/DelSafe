unit uAetherEmitterPascal;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  uAetherAST;

type
  TAetherEmitterPascal = class
  private
    FOutput: TStringList;
    FIndent: Integer;
    FModule: TASTModule;
    FCurrentFunc: TASTFunction;
    FProgramBlock: TASTProgramBlock;
    FActiveDefers: TFPList;
    FLoopDeferBase: Integer;
    FRaiiNames: TStringList;
    FRaiiTypes: TStringList;
    FLoopRaiiBase: Integer;
    FCurrentScopeList: TASTNodeList;
    FGuardBindNames: TStringList;
    FGuardBindExprs: TStringList;
    FMatchBindNames: TStringList;
    FMatchBindTargets: TStringList;
    FMatchBindTypes: TStringList;
    FDynTags: TStringList;
    FDynElems: TStringList;
    FFnTags: TStringList;
    FFnSigs: TStringList;
    FThunkFuncs: TStringList;
    FLambdas: TFPList;

    procedure Emit(const Line: string = '');
    procedure IncIndent;
    procedure DecIndent;
    function IndentStr: string;
    procedure EmitActiveDefers(DownToIndex: Integer = 0);
    function FindFunction(const AName: string): TASTFunction;
    function FindDropFunc(const ATypeName: string): TASTFunction;
    function RaiiExprUsesVar(Expr: TASTExpr; const AVarName: string): Boolean;
    function IsNonBorrowArgCapture(Call: TASTCallExpr; ArgIdx: Integer): Boolean;
    function IsVarEscapedInStmts(const AVarName: string; Stmts: TASTNodeList): Boolean;
    procedure RegisterRaiiVar(const AVarName, ATypeName: string; ScopeStmts: TASTNodeList);
    procedure EmitRaiiCleanupFor(const AVarName, ATypeName: string);
    procedure EmitActiveRaii(DownToIndex: Integer = 0);
    procedure EmitStmtList(List: TASTNodeList; IsLoopBody: Boolean = False);

    function IsEnumName(const AName: string): Boolean;
    function FindEnumDecl(const AName: string): TASTEnumDecl;
    function FindEnumVariantUnqualified(const AName: string; out Enm: TASTEnumDecl; out VarN: TASTEnumVariant): Boolean;
    function IsRecordName(const AName: string): Boolean;
    function IsModulePrefixName(const AName: string): Boolean;
    function ResolveAliasType(const AType: string): string;
    function IsSetType(const AName: string): Boolean;
    function IsDynamicArrayType(const AType: string): Boolean;
    function IsValueOptionType(const AType: string): Boolean;
    function SplitResultTypes(const AType: string; out ValType, ErrType: string): Boolean;
    function SplitFnType(const AType: string; ParamTypes: TStringList; out RetType: string): Boolean;
    function FnTypeTag(const AType: string): string;
    procedure RegisterFnType(const AType: string);
    procedure RegisterLambda(Lambda: TASTLambdaExpr);
    procedure RegisterThunkFunc(const FuncName: string);
    procedure EmitFnRuntimeHelpers(DeclOnly: Boolean);
    procedure EmitLambdaAndThunkDecls(ForwardOnly: Boolean);
    function MangleTypeTag(const AType: string): string;
    function IsCompoundMonadType(const AType: string): Boolean;
    function IsTypedValueOption(const AType: string; out InnerT: string): Boolean;
    function IsTypedResult(const AType: string; out ValT, ErrT: string): Boolean;
    function SafeUnwrapGeneric(const AType, Prefix: string): string;
    procedure PushMatchBindings(CaseNode: TASTMatchCase; const MatchedType: string);
    procedure PopMatchBindings(Count: Integer);
    function GetMatchArmBindingCount(CaseNode: TASTMatchCase): Integer;
    procedure GetMatchArmBindingInfo(CaseNode: TASTMatchCase; Idx: Integer; const MatchedType: string;
      out BindName, TargetVar, BindType: string);
    procedure CollectTypedMonadsFromType(const AType: string; OptTags, OptInners, ResTags, ResVals, ResErrs: TStrings);
    procedure CollectTypedMonadsFromExpr(Expr: TASTExpr; OptTags, OptInners, ResTags, ResVals, ResErrs: TStrings);
    procedure CollectTypedMonadsFromStmts(Stmts: TASTNodeList; OptTags, OptInners, ResTags, ResVals, ResErrs: TStrings);
    procedure CollectTypedMonadsFromModule(AModule: TASTModule; OptTags, OptInners, ResTags, ResVals, ResErrs: TStrings);
    procedure EmitTypedOptionDecl(const Tag, InnerT: string);
    procedure EmitTypedResultDecl(const Tag, ValT, ErrT: string);
    procedure EmitTypedMonadHelpers(OptTags, OptInners, ResTags, ResVals, ResErrs: TStrings; DeclOnly: Boolean);
    procedure EmitPayloadEnumConstructors(Enm: TASTEnumDecl; DeclOnly: Boolean);
    procedure EmitTopologicalTypesAndMonads(const TypeUsed: array of Boolean;
      OptTags, OptInners: TStrings; const OptUsed: array of Boolean;
      ResTags, ResVals, ResErrs: TStrings; const ResUsed: array of Boolean);
    function IsTypeIdentifier(const AName: string): Boolean;
    function EmitMonadFieldExtract(const ExprStr, FieldType, NumField, StrField: string): string;
    procedure EmitArrayLiteralAssign(const TargetStr, TargetType: string; SetLit: TASTSetLiteralExpr);
    procedure EmitMapLiteralAssign(const TargetStr, TargetType: string; MapLit: TASTMapLiteralExpr);
    function IsMapType(const AType: string; out KeyType, ValType: string): Boolean;
    function MapTag(const K, V: string): string;
    function NormalizeIntLit(const Val: string): string;
    function GetCollectionElemType(Expr: TASTExpr): string;
    function IsBuiltinMapSideType(const AType: string): Boolean;
    function FindInlineVarType(Stmts: TASTNodeList; const AName: string): string;
    procedure CollectAutoVarsFromExpr(Expr: TASTExpr; VarNames, VarTypes: TStrings; const SkipNames: TStrings);
    procedure CollectAutoVarsFromStmts(Stmts: TASTNodeList; VarNames, VarTypes: TStrings; const SkipNames: TStrings);
    procedure CollectMapsFromType(const AType: string; Tags, Keys, Vals: TStrings);
    procedure CollectMapsFromExpr(Expr: TASTExpr; Tags, Keys, Vals: TStrings);
    procedure CollectMapsFromStmts(Stmts: TASTNodeList; Tags, Keys, Vals: TStrings);
    procedure CollectMapsFromModule(AModule: TASTModule; Tags, Keys, Vals: TStrings);
    procedure EmitMapRuntimeDecls(Tags, Keys, Vals: TStrings; BuiltinOnly: Boolean);
    procedure EmitMapRuntimeHelpers(Tags, Keys, Vals: TStrings; DeclOnly: Boolean);
    function EscapePascalString(const S: string): string;
    function EscapePascalChar(const S: string): string;
    function GetExprTypeName(Expr: TASTExpr): string;
    function IsPointerTarget(Expr: TASTExpr): Boolean;
    procedure BuildMatchCaseCond(CaseNode: TASTMatchCase; const ExprStr, MatchedType: string;
      out CondStr, BindStmt, BindVarType: string; out IsWildcardArm: Boolean);

    function EmitTypeRef(const AType: string): string;
    function EmitExpr(Expr: TASTExpr): string;
    procedure EmitStmt(Stmt: TASTStmt);
    procedure EmitRecordType(Rec: TASTRecordDecl);
    procedure EmitRecordConstructor(Rec: TASTRecordDecl);
    procedure EmitEnumDecl(Enm: TASTEnumDecl);
    procedure EmitArrayDecl(Arr: TASTArrayDecl);
    procedure EmitSetDecl(SetD: TASTSetDecl);
    procedure EmitSubrangeDecl(SubR: TASTSubrangeDecl);
    procedure EmitMapDecl(MapD: TASTMapDecl);
    procedure EmitTypeAliasDecl(AliasD: TASTTypeAliasDecl);
    procedure EmitFunction(Func: TASTFunction);
    procedure EmitProgramBlock(Prog: TASTProgramBlock);

    function BuildFuncSig(Func: TASTFunction): string;
    function BuildRecordConstructorSig(Rec: TASTRecordDecl): string;
    procedure EmitRuntimeTypeDecls(const RefText: string; MapTags, MapKeys, MapVals: TStringList; AsUnit: Boolean);
    procedure EmitRuntimeHelpersInterface(const RefText: string);
    procedure EmitRuntimeHelpersImplementation(const RefText: string);
  public
    constructor Create;
    destructor Destroy; override;
    function Generate(AModule: TASTModule; AsUnit: Boolean = False; AsLibrary: Boolean = False): string;
  end;

implementation

constructor TAetherEmitterPascal.Create;
begin
  inherited Create;
  FOutput := TStringList.Create;
  FIndent := 0;
  FActiveDefers := TFPList.Create;
  FLoopDeferBase := 0;
  FRaiiNames := TStringList.Create;
  FRaiiTypes := TStringList.Create;
  FLoopRaiiBase := 0;
  FCurrentScopeList := nil;
  FGuardBindNames := TStringList.Create;
  FGuardBindExprs := TStringList.Create;
  FMatchBindNames := TStringList.Create;
  FMatchBindTargets := TStringList.Create;
  FMatchBindTypes := TStringList.Create;
  FDynTags := TStringList.Create;
  FDynElems := TStringList.Create;
  FFnTags := TStringList.Create;
  FFnSigs := TStringList.Create;
  FThunkFuncs := TStringList.Create;
  FLambdas := TFPList.Create;
end;

destructor TAetherEmitterPascal.Destroy;
begin
  FLambdas.Free;
  FThunkFuncs.Free;
  FFnSigs.Free;
  FFnTags.Free;
  FDynElems.Free;
  FDynTags.Free;
  FMatchBindTypes.Free;
  FMatchBindTargets.Free;
  FMatchBindNames.Free;
  FGuardBindExprs.Free;
  FGuardBindNames.Free;
  FRaiiNames.Free;
  FRaiiTypes.Free;
  FActiveDefers.Free;
  FOutput.Free;
  inherited Destroy;
end;

function TAetherEmitterPascal.IndentStr: string;
begin
  Result := StringOfChar(' ', FIndent * 2);
end;

procedure TAetherEmitterPascal.Emit(const Line: string);
begin
  if Line = '' then
    FOutput.Add('')
  else
    FOutput.Add(IndentStr + Line);
end;

procedure TAetherEmitterPascal.IncIndent;
begin
  Inc(FIndent);
end;

procedure TAetherEmitterPascal.DecIndent;
begin
  if FIndent > 0 then
    Dec(FIndent);
end;

function TAetherEmitterPascal.IsEnumName(const AName: string): Boolean;
begin
  Result := Assigned(FindEnumDecl(AName));
end;

function TAetherEmitterPascal.FindEnumDecl(const AName: string): TASTEnumDecl;
var
  I: Integer;
begin
  Result := nil;
  if Assigned(FModule) then
    for I := 0 to FModule.Types.Count - 1 do
      if (TASTNode(FModule.Types[I]) is TASTEnumDecl) and
         SameText(TASTEnumDecl(FModule.Types[I]).Name, AName) then
        Exit(TASTEnumDecl(FModule.Types[I]));
end;

function TAetherEmitterPascal.FindEnumVariantUnqualified(const AName: string; out Enm: TASTEnumDecl; out VarN: TASTEnumVariant): Boolean;
var
  I, J: Integer;
  E: TASTEnumDecl;
begin
  Result := False;
  Enm := nil;
  VarN := nil;
  if not Assigned(FModule) then Exit;
  for I := 0 to FModule.Types.Count - 1 do
  begin
    if TASTNode(FModule.Types[I]) is TASTEnumDecl then
    begin
      E := TASTEnumDecl(FModule.Types[I]);
      for J := 0 to E.Variants.Count - 1 do
        if SameText(TASTEnumVariant(E.Variants[J]).Name, AName) then
        begin
          Enm := E;
          VarN := TASTEnumVariant(E.Variants[J]);
          Exit(True);
        end;
    end;
  end;
end;

function TAetherEmitterPascal.IsRecordName(const AName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Assigned(FModule) then
    for I := 0 to FModule.Types.Count - 1 do
      if (TASTNode(FModule.Types[I]) is TASTRecordDecl) and
         SameText(TASTRecordDecl(FModule.Types[I]).Name, AName) then
        Exit(True);
end;

function TAetherEmitterPascal.IsModulePrefixName(const AName: string): Boolean;
var
  I: Integer;
  Imp, LastSeg: string;
begin
  Result := False;
  if Assigned(FCurrentFunc) then
  begin
    for I := 0 to FCurrentFunc.LocalVars.Count - 1 do
      if SameText(TASTVarDecl(FCurrentFunc.LocalVars[I]).Name, AName) then Exit(False);
    for I := 0 to FCurrentFunc.Params.Count - 1 do
      if SameText(TASTParam(FCurrentFunc.Params[I]).Name, AName) then Exit(False);
    if FindInlineVarType(FCurrentFunc.Body, AName) <> '' then Exit(False);
  end;
  if Assigned(FProgramBlock) then
  begin
    for I := 0 to FProgramBlock.LocalVars.Count - 1 do
      if SameText(TASTVarDecl(FProgramBlock.LocalVars[I]).Name, AName) then Exit(False);
    if FindInlineVarType(FProgramBlock.Body, AName) <> '' then Exit(False);
  end;
  if IsTypeIdentifier(AName) then Exit(False);

  if Assigned(FModule) and Assigned(FModule.ImportAliases) and (FModule.ImportAliases.Values[AName] <> '') then
    Exit(True);

  if Assigned(FModule) and Assigned(FModule.Imports) then
  begin
    for I := 0 to FModule.Imports.Count - 1 do
    begin
      Imp := FModule.Imports[I];
      LastSeg := Imp;
      if Pos('.', LastSeg) > 0 then
        LastSeg := Copy(LastSeg, LastDelimiter('.', LastSeg) + 1, Length(LastSeg));
      if SameText(AName, Imp) or SameText(AName, LastSeg) then
        Exit(True);
    end;
  end;
end;

function TAetherEmitterPascal.EscapePascalString(const S: string): string;
var
  I: Integer;
  InQuotes: Boolean;
begin
  Result := '';
  InQuotes := False;
  for I := 1 to Length(S) do
  begin
    if S[I] in [#0..#31, #127] then
    begin
      if InQuotes then
      begin
        Result := Result + '''';
        InQuotes := False;
      end;
      Result := Result + '#' + IntToStr(Ord(S[I]));
    end
    else
    begin
      if not InQuotes then
      begin
        Result := Result + '''';
        InQuotes := True;
      end;
      if S[I] = '''' then
        Result := Result + ''''''
      else
        Result := Result + S[I];
    end;
  end;
  if InQuotes then
    Result := Result + '''';
  if Result = '' then
    Result := '''''';
end;

function TAetherEmitterPascal.EscapePascalChar(const S: string): string;
begin
  if Length(S) = 0 then Exit('#0');
  if S[1] in [#0..#31, #127] then
    Result := '#' + IntToStr(Ord(S[1]))
  else if S[1] = '''' then
    Result := ''''''''''
  else
    Result := '''' + S[1] + '''';
end;

function IsIntegerType(const AType: string): Boolean;
begin
  Result := (AType = 'Int8') or (AType = 'Int16') or (AType = 'Int32') or (AType = 'Int64') or
            (AType = 'UInt8') or (AType = 'UInt16') or (AType = 'UInt32') or (AType = 'UInt64') or
            (AType = 'IntLiteral');
end;

function TAetherEmitterPascal.ResolveAliasType(const AType: string): string;
var
  Cur: string;
  Hops, I: Integer;
begin
  Cur := Trim(AType);
  Hops := 0;
  while (Hops < 8) and Assigned(FModule) do
  begin
    I := 0;
    while I < FModule.Types.Count do
    begin
      if (FModule.Types[I] is TASTTypeAliasDecl) and SameText(TASTTypeAliasDecl(FModule.Types[I]).Name, Cur) then
      begin
        Cur := Trim(TASTTypeAliasDecl(FModule.Types[I]).TargetType);
        Inc(Hops);
        Break;
      end;
      Inc(I);
    end;
    if I >= FModule.Types.Count then Break;
  end;
  Result := Cur;
end;

function TAetherEmitterPascal.IsSetType(const AName: string): Boolean;
var
  I: Integer;
  T: string;
begin
  T := ResolveAliasType(AName);
  if Pos('set of', T) > 0 then Exit(True);
  if Assigned(FModule) then
    for I := 0 to FModule.Types.Count - 1 do
      if (FModule.Types[I] is TASTSetDecl) and SameText(TASTSetDecl(FModule.Types[I]).Name, T) then
        Exit(True);
  Result := False;
end;

function TAetherEmitterPascal.IsDynamicArrayType(const AType: string): Boolean;
var
  I: Integer;
  T: string;
begin
  T := ResolveAliasType(AType);
  if Pos('array of ', T) = 1 then Exit(True);
  if Assigned(FModule) then
    for I := 0 to FModule.Types.Count - 1 do
      if (FModule.Types[I] is TASTArrayDecl) and SameText(TASTArrayDecl(FModule.Types[I]).Name, T) and
         (TASTArrayDecl(FModule.Types[I]).Dims.Count = 0) then
        Exit(True);
  Result := False;
end;

function TAetherEmitterPascal.IsValueOptionType(const AType: string): Boolean;
var
  T, Inner: string;
begin
  T := ResolveAliasType(AType);
  if Pos('Option<', T) <> 1 then Exit(False);
  Inner := ResolveAliasType(Trim(Copy(T, 8, Length(T) - 8)));
  Result := (Inner <> '') and (Pos('Box<', Inner) <> 1) and (Pos('^', Inner) <> 1) and (Inner <> 'Pointer');
end;

function TAetherEmitterPascal.SplitResultTypes(const AType: string; out ValType, ErrType: string): Boolean;
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

function TAetherEmitterPascal.SafeUnwrapGeneric(const AType, Prefix: string): string;
var
  T, Pre: string;
begin
  T := Trim(AType);
  Pre := Prefix + '<';
  if (Pos(Pre, T) = 1) and (Length(T) > Length(Pre)) and (T[Length(T)] = '>') then
    Result := Trim(Copy(T, Length(Pre) + 1, Length(T) - Length(Pre) - 1))
  else
    Result := '';
end;

function TAetherEmitterPascal.SplitFnType(const AType: string; ParamTypes: TStringList; out RetType: string): Boolean;
var
  T, Inner, Cur, AfterParen: string;
  I, DepthParen, DepthAngle, DepthBracket, ClosePos: Integer;
begin
  Result := False;
  ParamTypes.Clear;
  RetType := 'Void';
  T := Trim(AType);
  if Pos('fn(', T) <> 1 then Exit;
  DepthParen := 0;
  ClosePos := 0;
  for I := 3 to Length(T) do
  begin
    if T[I] = '(' then Inc(DepthParen)
    else if T[I] = ')' then
    begin
      Dec(DepthParen);
      if DepthParen = 0 then
      begin
        ClosePos := I;
        Break;
      end;
    end;
  end;
  if ClosePos = 0 then Exit;
  AfterParen := Trim(Copy(T, ClosePos + 1, Length(T)));
  if Pos('->', AfterParen) <> 1 then Exit;
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
    if Trim(Cur) <> '' then ParamTypes.Add(Trim(Cur));
  end;
  Result := RetType <> '';
end;

function TAetherEmitterPascal.FnTypeTag(const AType: string): string;
var
  Params: TStringList;
  RetT: string;
  I: Integer;
begin
  Params := TStringList.Create;
  try
    if SplitFnType(AType, Params, RetT) then
    begin
      if Params.Count = 0 then
        Result := 'void'
      else
      begin
        Result := '';
        for I := 0 to Params.Count - 1 do
        begin
          if I > 0 then Result := Result + '_';
          Result := Result + MangleTypeTag(Params[I]);
        end;
      end;
      Result := Result + '__ret__' + MangleTypeTag(RetT);
    end
    else
      Result := 'unknown';
  finally
    Params.Free;
  end;
end;

procedure TAetherEmitterPascal.RegisterFnType(const AType: string);
var
  T, Tag: string;
begin
  T := ResolveAliasType(Trim(AType));
  if Pos('fn(', T) <> 1 then Exit;
  Tag := FnTypeTag(T);
  if FFnTags.IndexOf(Tag) < 0 then
  begin
    FFnTags.Add(Tag);
    FFnSigs.Add(T);
  end;
end;

procedure TAetherEmitterPascal.RegisterLambda(Lambda: TASTLambdaExpr);
begin
  if Assigned(Lambda) and (FLambdas.IndexOf(Lambda) < 0) then
    FLambdas.Add(Lambda);
end;

procedure TAetherEmitterPascal.RegisterThunkFunc(const FuncName: string);
begin
  if (FuncName <> '') and (FThunkFuncs.IndexOf(FuncName) < 0) then
    FThunkFuncs.Add(FuncName);
end;

function TAetherEmitterPascal.MangleTypeTag(const AType: string): string;
var
  T, ValT, ErrT, InnerT, Res: string;
  I: Integer;
  Ch: Char;
begin
  T := ResolveAliasType(Trim(AType));
  if T = '' then Exit('Void');
  if Pos('fn(', T) = 1 then
    Exit('Fn__' + FnTypeTag(T));
  if Pos('^', T) = 1 then
    Exit('ptr_' + MangleTypeTag(Copy(T, 2, Length(T))));
  if Pos('array of ', T) = 1 then
    Exit('arr_' + MangleTypeTag(Copy(T, 10, Length(T))));
  if SplitResultTypes(T, ValT, ErrT) then
    Exit('Result__' + MangleTypeTag(ValT) + '__' + MangleTypeTag(ErrT));
  if Pos('Option<', T) = 1 then
  begin
    InnerT := SafeUnwrapGeneric(T, 'Option');
    if InnerT <> '' then
      Exit('Option__' + MangleTypeTag(InnerT));
  end;
  if Pos('Box<', T) = 1 then
  begin
    InnerT := SafeUnwrapGeneric(T, 'Box');
    if InnerT <> '' then
      Exit('Box__' + MangleTypeTag(InnerT));
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

function TAetherEmitterPascal.IsCompoundMonadType(const AType: string): Boolean;
var
  T, K, V: string;
  I: Integer;
  Enm: TASTEnumDecl;
begin
  T := ResolveAliasType(Trim(AType));
  if (T = '') or (T = 'IntLiteral') or (T = 'FloatLiteral') or
     (T = 'GenericValue') or (T = 'GenericError') or (T = 'GenericNone') or
     (T = 'Int8') or (T = 'Int16') or (T = 'Int32') or (T = 'Int64') or
     (T = 'UInt8') or (T = 'UInt16') or (T = 'UInt32') or (T = 'UInt64') or
     (T = 'Float32') or (T = 'Float64') or (T = 'Bool') or (T = 'Char') or
     (T = 'String') or (T = 'Pointer') or (Pos('^', T) = 1) or (Pos('Box<', T) = 1) then
    Exit(False);

  if (Pos('array of ', T) = 1) or (Pos('array[', T) = 1) or (Pos('fn(', T) = 1) or
     (Pos('Option<', T) = 1) or (Pos('Result<', T) = 1) or IsMapType(T, K, V) then
    Exit(True);

  Enm := FindEnumDecl(T);
  if Assigned(Enm) then
    Exit(Enm.HasPayload);

  if Assigned(FModule) then
  begin
    for I := 0 to FModule.Types.Count - 1 do
    begin
      if (TASTNode(FModule.Types[I]) is TASTRecordDecl) and SameText(TASTRecordDecl(FModule.Types[I]).Name, T) then
        Exit(True);
      if (TASTNode(FModule.Types[I]) is TASTArrayDecl) and SameText(TASTArrayDecl(FModule.Types[I]).Name, T) then
        Exit(True);
    end;
  end;
  Result := False;
end;

function TAetherEmitterPascal.IsTypedValueOption(const AType: string; out InnerT: string): Boolean;
var
  T: string;
begin
  InnerT := '';
  if not IsValueOptionType(AType) then Exit(False);
  T := ResolveAliasType(AType);
  InnerT := ResolveAliasType(SafeUnwrapGeneric(T, 'Option'));
  if (InnerT = '') or (InnerT = 'GenericNone') or (InnerT = 'IntLiteral') or (InnerT = 'FloatLiteral') then
    Exit(False);
  Result := IsCompoundMonadType(InnerT) or IsEnumName(InnerT);
end;

function TAetherEmitterPascal.IsTypedResult(const AType: string; out ValT, ErrT: string): Boolean;
begin
  if not SplitResultTypes(AType, ValT, ErrT) then Exit(False);
  ValT := ResolveAliasType(ValT);
  ErrT := ResolveAliasType(ErrT);
  if (ValT = 'GenericValue') or (ErrT = 'GenericError') or (ValT = 'IntLiteral') or (ValT = 'FloatLiteral') then
    Exit(False);
  Result := IsCompoundMonadType(ValT) or IsCompoundMonadType(ErrT);
end;

function TAetherEmitterPascal.GetMatchArmBindingCount(CaseNode: TASTMatchCase): Integer;
begin
  if CaseNode.Pattern.Bindings.Count > 0 then
    Result := CaseNode.Pattern.Bindings.Count
  else if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') then
    Result := 1
  else
    Result := 0;
end;

procedure TAetherEmitterPascal.GetMatchArmBindingInfo(CaseNode: TASTMatchCase; Idx: Integer; const MatchedType: string;
  out BindName, TargetVar, BindType: string);
var
  PatStr, ValF, ErrF, EnmName, VarName: string;
  PDot: Integer;
  Enm: TASTEnumDecl;
  VarN: TASTEnumVariant;
  J: Integer;
begin
  if CaseNode.Pattern.Bindings.Count > 0 then
    BindName := CaseNode.Pattern.Bindings[Idx]
  else
    BindName := CaseNode.Pattern.SubPattern;

  TargetVar := Format('_mb_%d_%d_%s', [CaseNode.Line, CaseNode.Col, BindName]);
  BindType := MatchedType;
  PatStr := CaseNode.Pattern.Value;

  if PatStr = '_' then
    BindType := MatchedType
  else if Pos('Ok', PatStr) = 1 then
  begin
    SplitResultTypes(MatchedType, ValF, ErrF);
    BindType := ValF;
  end
  else if Pos('Err', PatStr) = 1 then
  begin
    SplitResultTypes(MatchedType, ValF, ErrF);
    BindType := ErrF;
  end
  else if PatStr = 'Some' then
  begin
    BindType := SafeUnwrapGeneric(MatchedType, 'Option');
    if BindType = '' then BindType := 'Int32';
  end
  else
  begin
    Enm := FindEnumDecl(MatchedType);
    if Assigned(Enm) and Enm.HasPayload then
    begin
      EnmName := PatStr;
      PDot := Pos('.', EnmName);
      if PDot > 0 then VarName := Copy(EnmName, PDot + 1, Length(EnmName))
      else VarName := EnmName;
      for J := 0 to Enm.Variants.Count - 1 do
      begin
        VarN := TASTEnumVariant(Enm.Variants[J]);
        if SameText(VarN.Name, VarName) and (Idx < VarN.Fields.Count) then
        begin
          BindType := TASTRecordField(VarN.Fields[Idx]).TypeName;
          Break;
        end;
      end;
    end;
  end;
end;

procedure TAetherEmitterPascal.PushMatchBindings(CaseNode: TASTMatchCase; const MatchedType: string);
var
  I, Cnt: Integer;
  BName, TVar, BType: string;
begin
  Cnt := GetMatchArmBindingCount(CaseNode);
  for I := 0 to Cnt - 1 do
  begin
    GetMatchArmBindingInfo(CaseNode, I, MatchedType, BName, TVar, BType);
    if (BName <> '') and (BName <> '_') then
    begin
      FMatchBindNames.Add(BName);
      FMatchBindTargets.Add(TVar);
      FMatchBindTypes.Add(BType);
    end;
  end;
end;

procedure TAetherEmitterPascal.PopMatchBindings(Count: Integer);
var
  I: Integer;
begin
  for I := 1 to Count do
  begin
    if FMatchBindNames.Count > 0 then
    begin
      FMatchBindNames.Delete(FMatchBindNames.Count - 1);
      FMatchBindTargets.Delete(FMatchBindTargets.Count - 1);
      FMatchBindTypes.Delete(FMatchBindTypes.Count - 1);
    end;
  end;
end;

procedure TAetherEmitterPascal.CollectTypedMonadsFromType(const AType: string; OptTags, OptInners, ResTags, ResVals, ResErrs: TStrings);
var
  T, InnerT, ValT, ErrT, Tag, KeyT, ValM, RetT: string;
  FnParams: TStringList;
  K: Integer;
begin
  T := ResolveAliasType(Trim(AType));
  if T = '' then Exit;
  FnParams := TStringList.Create;
  try
    if SplitFnType(T, FnParams, RetT) then
    begin
      for K := 0 to FnParams.Count - 1 do
        CollectTypedMonadsFromType(FnParams[K], OptTags, OptInners, ResTags, ResVals, ResErrs);
      if (RetT <> '') and (not SameText(RetT, 'Void')) then
        CollectTypedMonadsFromType(RetT, OptTags, OptInners, ResTags, ResVals, ResErrs);
      RegisterFnType(T);
      Exit;
    end;
  finally
    FnParams.Free;
  end;
  if Pos('^', T) = 1 then
  begin
    CollectTypedMonadsFromType(Copy(T, 2, Length(T)), OptTags, OptInners, ResTags, ResVals, ResErrs);
    Exit;
  end;
  if Pos('array of ', T) = 1 then
  begin
    InnerT := Trim(Copy(T, 10, Length(T)));
    CollectTypedMonadsFromType(InnerT, OptTags, OptInners, ResTags, ResVals, ResErrs);
    if not ((InnerT = 'Int8') or (InnerT = 'Int16') or (InnerT = 'Int32') or (InnerT = 'Int64') or
            (InnerT = 'UInt8') or (InnerT = 'UInt16') or (InnerT = 'UInt32') or (InnerT = 'UInt64') or
            (InnerT = 'Float32') or (InnerT = 'Float64') or (InnerT = 'Bool') or (InnerT = 'Char') or
            (InnerT = 'String') or (InnerT = 'Pointer')) then
    begin
      Tag := MangleTypeTag(InnerT);
      if Assigned(FDynTags) and (FDynTags.IndexOf(Tag) = -1) then
      begin
        FDynTags.Add(Tag);
        FDynElems.Add(InnerT);
      end;
    end;
    Exit;
  end;
  if IsMapType(T, KeyT, ValM) then
  begin
    CollectTypedMonadsFromType(KeyT, OptTags, OptInners, ResTags, ResVals, ResErrs);
    CollectTypedMonadsFromType(ValM, OptTags, OptInners, ResTags, ResVals, ResErrs);
    Exit;
  end;
  if IsTypedValueOption(T, InnerT) then
  begin
    CollectTypedMonadsFromType(InnerT, OptTags, OptInners, ResTags, ResVals, ResErrs);
    Tag := MangleTypeTag(InnerT);
    if OptTags.IndexOf(Tag) = -1 then
    begin
      OptTags.Add(Tag);
      OptInners.Add(InnerT);
    end;
  end
  else if IsTypedResult(T, ValT, ErrT) then
  begin
    CollectTypedMonadsFromType(ValT, OptTags, OptInners, ResTags, ResVals, ResErrs);
    CollectTypedMonadsFromType(ErrT, OptTags, OptInners, ResTags, ResVals, ResErrs);
    Tag := MangleTypeTag(ValT) + '__' + MangleTypeTag(ErrT);
    if ResTags.IndexOf(Tag) = -1 then
    begin
      ResTags.Add(Tag);
      ResVals.Add(ValT);
      ResErrs.Add(ErrT);
    end;
  end;
end;

procedure TAetherEmitterPascal.CollectTypedMonadsFromExpr(Expr: TASTExpr; OptTags, OptInners, ResTags, ResVals, ResErrs: TStrings);
var
  I, Cnt, AddedB: Integer;
  Call: TASTCallExpr;
  ME: TASTMatchExpr;
  CaseN: TASTMatchCase;
  MT, BName, TVar, BType: string;
begin
  if not Assigned(Expr) then Exit;
  if Expr is TASTIdentifierExpr then
  begin
    if TASTIdentifierExpr(Expr).IsFnValueRef then
    begin
      CollectTypedMonadsFromType(TASTIdentifierExpr(Expr).ResolvedFnType, OptTags, OptInners, ResTags, ResVals, ResErrs);
      RegisterThunkFunc(TASTIdentifierExpr(Expr).Name);
    end;
    if TASTIdentifierExpr(Expr).ResolvedMonadType <> '' then
      CollectTypedMonadsFromType(TASTIdentifierExpr(Expr).ResolvedMonadType, OptTags, OptInners, ResTags, ResVals, ResErrs);
  end
  else if Expr is TASTTupleLiteralExpr then
  begin
    CollectTypedMonadsFromType(TASTTupleLiteralExpr(Expr).ResolvedType, OptTags, OptInners, ResTags, ResVals, ResErrs);
    for I := 0 to TASTTupleLiteralExpr(Expr).Elements.Count - 1 do
      CollectTypedMonadsFromExpr(TASTExpr(TASTTupleLiteralExpr(Expr).Elements[I]), OptTags, OptInners, ResTags, ResVals, ResErrs);
  end
  else if Expr is TASTLambdaExpr then
  begin
    CollectTypedMonadsFromType(TASTLambdaExpr(Expr).ResolvedFnType, OptTags, OptInners, ResTags, ResVals, ResErrs);
    RegisterLambda(TASTLambdaExpr(Expr));
    for I := 0 to TASTLambdaExpr(Expr).CaptureTypes.Count - 1 do
      CollectTypedMonadsFromType(TASTLambdaExpr(Expr).CaptureTypes[I], OptTags, OptInners, ResTags, ResVals, ResErrs);
    if Assigned(TASTLambdaExpr(Expr).BodyExpr) then
      CollectTypedMonadsFromExpr(TASTLambdaExpr(Expr).BodyExpr, OptTags, OptInners, ResTags, ResVals, ResErrs)
    else
      CollectTypedMonadsFromStmts(TASTLambdaExpr(Expr).BodyStmts, OptTags, OptInners, ResTags, ResVals, ResErrs);
  end
  else if Expr is TASTMemberAccessExpr then
    CollectTypedMonadsFromExpr(TASTMemberAccessExpr(Expr).Target, OptTags, OptInners, ResTags, ResVals, ResErrs)
  else if Expr is TASTBinaryExpr then
  begin
    CollectTypedMonadsFromExpr(TASTBinaryExpr(Expr).Left, OptTags, OptInners, ResTags, ResVals, ResErrs);
    CollectTypedMonadsFromExpr(TASTBinaryExpr(Expr).Right, OptTags, OptInners, ResTags, ResVals, ResErrs);
  end
  else if Expr is TASTUnaryExpr then
  begin
    if TASTUnaryExpr(Expr).Op = '?' then
      CollectTypedMonadsFromType(GetExprTypeName(TASTUnaryExpr(Expr).Expr), OptTags, OptInners, ResTags, ResVals, ResErrs);
    CollectTypedMonadsFromExpr(TASTUnaryExpr(Expr).Expr, OptTags, OptInners, ResTags, ResVals, ResErrs);
  end
  else if Expr is TASTAwaitExpr then
    CollectTypedMonadsFromExpr(TASTAwaitExpr(Expr).Expr, OptTags, OptInners, ResTags, ResVals, ResErrs)
  else if Expr is TASTSpawnExpr then
    CollectTypedMonadsFromExpr(TASTSpawnExpr(Expr).CallExpr, OptTags, OptInners, ResTags, ResVals, ResErrs)
  else if Expr is TASTCallExpr then
  begin
    Call := TASTCallExpr(Expr);
    if Assigned(Call.CalleeExpr) then
      CollectTypedMonadsFromExpr(Call.CalleeExpr, OptTags, OptInners, ResTags, ResVals, ResErrs);
    if Call.IsIndirectCall and (Call.IndirectFnType <> '') then
      CollectTypedMonadsFromType(Call.IndirectFnType, OptTags, OptInners, ResTags, ResVals, ResErrs);
    if Call.ResolvedMonadType <> '' then
      CollectTypedMonadsFromType(Call.ResolvedMonadType, OptTags, OptInners, ResTags, ResVals, ResErrs)
    else if (Call.Callee = 'Some') and (Call.Args.Count >= 1) then
      CollectTypedMonadsFromType('Option<' + GetExprTypeName(TASTCallArg(Call.Args[0]).Expr) + '>', OptTags, OptInners, ResTags, ResVals, ResErrs);
    for I := 0 to Call.Args.Count - 1 do
      CollectTypedMonadsFromExpr(TASTCallArg(Call.Args[I]).Expr, OptTags, OptInners, ResTags, ResVals, ResErrs);
  end
  else if Expr is TASTIndexExpr then
  begin
    CollectTypedMonadsFromExpr(TASTIndexExpr(Expr).Target, OptTags, OptInners, ResTags, ResVals, ResErrs);
    for I := 0 to TASTIndexExpr(Expr).Indices.Count - 1 do
      CollectTypedMonadsFromExpr(TASTExpr(TASTIndexExpr(Expr).Indices[I]), OptTags, OptInners, ResTags, ResVals, ResErrs);
  end
  else if Expr is TASTSetLiteralExpr then
  begin
    for I := 0 to TASTSetLiteralExpr(Expr).Elements.Count - 1 do
      CollectTypedMonadsFromExpr(TASTExpr(TASTSetLiteralExpr(Expr).Elements[I]), OptTags, OptInners, ResTags, ResVals, ResErrs);
  end
  else if Expr is TASTMapLiteralExpr then
  begin
    for I := 0 to TASTMapLiteralExpr(Expr).Keys.Count - 1 do
    begin
      CollectTypedMonadsFromExpr(TASTExpr(TASTMapLiteralExpr(Expr).Keys[I]), OptTags, OptInners, ResTags, ResVals, ResErrs);
      CollectTypedMonadsFromExpr(TASTExpr(TASTMapLiteralExpr(Expr).Values[I]), OptTags, OptInners, ResTags, ResVals, ResErrs);
    end;
  end
  else if Expr is TASTIfExpr then
  begin
    CollectTypedMonadsFromExpr(TASTIfExpr(Expr).Condition, OptTags, OptInners, ResTags, ResVals, ResErrs);
    CollectTypedMonadsFromExpr(TASTIfExpr(Expr).ThenExpr, OptTags, OptInners, ResTags, ResVals, ResErrs);
    CollectTypedMonadsFromExpr(TASTIfExpr(Expr).ElseExpr, OptTags, OptInners, ResTags, ResVals, ResErrs);
  end
  else if Expr is TASTMatchExpr then
  begin
    ME := TASTMatchExpr(Expr);
    CollectTypedMonadsFromExpr(ME.Expr, OptTags, OptInners, ResTags, ResVals, ResErrs);
    MT := ResolveAliasType(GetExprTypeName(ME.Expr));
    CollectTypedMonadsFromType(MT, OptTags, OptInners, ResTags, ResVals, ResErrs);
    for I := 0 to ME.Cases.Count - 1 do
    begin
      CaseN := TASTMatchCase(ME.Cases[I]);
      Cnt := GetMatchArmBindingCount(CaseN);
      for AddedB := 0 to Cnt - 1 do
      begin
        GetMatchArmBindingInfo(CaseN, AddedB, MT, BName, TVar, BType);
        if (BName <> '') and (BName <> '_') then
        begin
          FMatchBindNames.Add(BName);
          FMatchBindTargets.Add(TVar);
          FMatchBindTypes.Add(BType);
        end;
      end;
      try
        CollectTypedMonadsFromExpr(CaseN.Guard, OptTags, OptInners, ResTags, ResVals, ResErrs);
        CollectTypedMonadsFromExpr(CaseN.ValueExpr, OptTags, OptInners, ResTags, ResVals, ResErrs);
      finally
        for AddedB := 0 to Cnt - 1 do
        begin
          GetMatchArmBindingInfo(CaseN, AddedB, MT, BName, TVar, BType);
          if (BName <> '') and (BName <> '_') then PopMatchBindings(1);
        end;
      end;
    end;
  end;
end;

procedure TAetherEmitterPascal.CollectTypedMonadsFromStmts(Stmts: TASTNodeList; OptTags, OptInners, ResTags, ResVals, ResErrs: TStrings);
var
  I, J, K, Cnt: Integer;
  S: TASTStmt;
  VD: TASTVarDecl;
  ForS: TASTForStmt;
  MS: TASTMatchStmt;
  CN: TASTMatchCase;
  MT, BName, TVar, BType: string;
begin
  if not Assigned(Stmts) then Exit;
  for I := 0 to Stmts.Count - 1 do
  begin
    S := TASTStmt(Stmts[I]);
    if S is TASTVarDeclStmt then
    begin
      for K := 0 to TASTVarDeclStmt(S).Decls.Count - 1 do
      begin
        VD := TASTVarDecl(TASTVarDeclStmt(S).Decls[K]);
        CollectTypedMonadsFromType(VD.TypeName, OptTags, OptInners, ResTags, ResVals, ResErrs);
        CollectTypedMonadsFromExpr(VD.InitialExpr, OptTags, OptInners, ResTags, ResVals, ResErrs);
      end;
    end
    else if S is TASTAssignStmt then
    begin
      CollectTypedMonadsFromExpr(TASTAssignStmt(S).Target, OptTags, OptInners, ResTags, ResVals, ResErrs);
      CollectTypedMonadsFromExpr(TASTAssignStmt(S).Expr, OptTags, OptInners, ResTags, ResVals, ResErrs);
    end
    else if S is TASTCallStmt then
      CollectTypedMonadsFromExpr(TASTCallStmt(S).CallExpr, OptTags, OptInners, ResTags, ResVals, ResErrs)
    else if S is TASTReturnStmt then
      CollectTypedMonadsFromExpr(TASTReturnStmt(S).Expr, OptTags, OptInners, ResTags, ResVals, ResErrs)
    else if S is TASTIfStmt then
    begin
      CollectTypedMonadsFromExpr(TASTIfStmt(S).Condition, OptTags, OptInners, ResTags, ResVals, ResErrs);
      CollectTypedMonadsFromStmts(TASTIfStmt(S).ThenBranch, OptTags, OptInners, ResTags, ResVals, ResErrs);
      CollectTypedMonadsFromStmts(TASTIfStmt(S).ElseBranch, OptTags, OptInners, ResTags, ResVals, ResErrs);
    end
    else if S is TASTWhileStmt then
    begin
      CollectTypedMonadsFromExpr(TASTWhileStmt(S).Condition, OptTags, OptInners, ResTags, ResVals, ResErrs);
      CollectTypedMonadsFromStmts(TASTWhileStmt(S).Body, OptTags, OptInners, ResTags, ResVals, ResErrs);
    end
    else if S is TASTForStmt then
    begin
      ForS := TASTForStmt(S);
      CollectTypedMonadsFromExpr(ForS.StartExpr, OptTags, OptInners, ResTags, ResVals, ResErrs);
      CollectTypedMonadsFromExpr(ForS.EndExpr, OptTags, OptInners, ResTags, ResVals, ResErrs);
      CollectTypedMonadsFromExpr(ForS.CollectionExpr, OptTags, OptInners, ResTags, ResVals, ResErrs);
      CollectTypedMonadsFromStmts(ForS.Body, OptTags, OptInners, ResTags, ResVals, ResErrs);
    end
    else if S is TASTRepeatStmt then
    begin
      CollectTypedMonadsFromStmts(TASTRepeatStmt(S).Body, OptTags, OptInners, ResTags, ResVals, ResErrs);
      CollectTypedMonadsFromExpr(TASTRepeatStmt(S).Condition, OptTags, OptInners, ResTags, ResVals, ResErrs);
    end
    else if S is TASTUnsafeStmt then
      CollectTypedMonadsFromStmts(TASTUnsafeStmt(S).Body, OptTags, OptInners, ResTags, ResVals, ResErrs)
    else if S is TASTTryStmt then
    begin
      CollectTypedMonadsFromStmts(TASTTryStmt(S).TryBody, OptTags, OptInners, ResTags, ResVals, ResErrs);
      CollectTypedMonadsFromStmts(TASTTryStmt(S).ExceptBody, OptTags, OptInners, ResTags, ResVals, ResErrs);
    end
    else if S is TASTMatchStmt then
    begin
      MS := TASTMatchStmt(S);
      CollectTypedMonadsFromExpr(MS.Expr, OptTags, OptInners, ResTags, ResVals, ResErrs);
      MT := ResolveAliasType(GetExprTypeName(MS.Expr));
      CollectTypedMonadsFromType(MT, OptTags, OptInners, ResTags, ResVals, ResErrs);
      for K := 0 to MS.Cases.Count - 1 do
      begin
        CN := TASTMatchCase(MS.Cases[K]);
        Cnt := GetMatchArmBindingCount(CN);
        for J := 0 to Cnt - 1 do
        begin
          GetMatchArmBindingInfo(CN, J, MT, BName, TVar, BType);
          if (BName <> '') and (BName <> '_') then
          begin
            FMatchBindNames.Add(BName);
            FMatchBindTargets.Add(TVar);
            FMatchBindTypes.Add(BType);
          end;
        end;
        try
          CollectTypedMonadsFromExpr(CN.Guard, OptTags, OptInners, ResTags, ResVals, ResErrs);
          CollectTypedMonadsFromStmts(CN.Body, OptTags, OptInners, ResTags, ResVals, ResErrs);
        finally
          for J := 0 to Cnt - 1 do
          begin
            GetMatchArmBindingInfo(CN, J, MT, BName, TVar, BType);
            if (BName <> '') and (BName <> '_') then PopMatchBindings(1);
          end;
        end;
      end;
    end;
  end;
end;

procedure TAetherEmitterPascal.CollectTypedMonadsFromModule(AModule: TASTModule; OptTags, OptInners, ResTags, ResVals, ResErrs: TStrings);
var
  I, J, K: Integer;
  Node: TASTNode;
  Rec: TASTRecordDecl;
  Enm: TASTEnumDecl;
  VarN: TASTEnumVariant;
  Func: TASTFunction;
  OldFunc: TASTFunction;
  OldProg: TASTProgramBlock;
begin
  for I := 0 to AModule.Types.Count - 1 do
  begin
    Node := AModule.Types[I];
    if Node is TASTRecordDecl then
    begin
      Rec := TASTRecordDecl(Node);
      if Rec.GenericParams.Count = 0 then
        for J := 0 to Rec.Fields.Count - 1 do
          CollectTypedMonadsFromType(TASTRecordField(Rec.Fields[J]).TypeName, OptTags, OptInners, ResTags, ResVals, ResErrs);
    end
    else if Node is TASTEnumDecl then
    begin
      Enm := TASTEnumDecl(Node);
      for J := 0 to Enm.Variants.Count - 1 do
      begin
        VarN := TASTEnumVariant(Enm.Variants[J]);
        for K := 0 to VarN.Fields.Count - 1 do
          CollectTypedMonadsFromType(TASTRecordField(VarN.Fields[K]).TypeName, OptTags, OptInners, ResTags, ResVals, ResErrs);
      end;
    end
    else if Node is TASTArrayDecl then
      CollectTypedMonadsFromType(TASTArrayDecl(Node).ElemType, OptTags, OptInners, ResTags, ResVals, ResErrs)
    else if Node is TASTMapDecl then
    begin
      CollectTypedMonadsFromType(TASTMapDecl(Node).KeyType, OptTags, OptInners, ResTags, ResVals, ResErrs);
      CollectTypedMonadsFromType(TASTMapDecl(Node).ValType, OptTags, OptInners, ResTags, ResVals, ResErrs);
    end
    else if Node is TASTTypeAliasDecl then
      CollectTypedMonadsFromType(TASTTypeAliasDecl(Node).TargetType, OptTags, OptInners, ResTags, ResVals, ResErrs);
  end;

  for I := 0 to AModule.ModuleVars.Count - 1 do
  begin
    CollectTypedMonadsFromType(TASTVarDecl(AModule.ModuleVars[I]).TypeName, OptTags, OptInners, ResTags, ResVals, ResErrs);
    CollectTypedMonadsFromExpr(TASTVarDecl(AModule.ModuleVars[I]).InitialExpr, OptTags, OptInners, ResTags, ResVals, ResErrs);
  end;

  OldFunc := FCurrentFunc;
  OldProg := FProgramBlock;
  try
    for I := 0 to AModule.Functions.Count - 1 do
    begin
      Func := TASTFunction(AModule.Functions[I]);
      if (Func.GenericParams.Count > 0) or (Func.GenericParam <> '') then Continue;
      FCurrentFunc := Func;
      FProgramBlock := nil;
      if not Func.IsProcedure then
        CollectTypedMonadsFromType(Func.ReturnType, OptTags, OptInners, ResTags, ResVals, ResErrs);
      for J := 0 to Func.Params.Count - 1 do
        CollectTypedMonadsFromType(TASTParam(Func.Params[J]).TypeName, OptTags, OptInners, ResTags, ResVals, ResErrs);
      for J := 0 to Func.LocalVars.Count - 1 do
      begin
        CollectTypedMonadsFromType(TASTVarDecl(Func.LocalVars[J]).TypeName, OptTags, OptInners, ResTags, ResVals, ResErrs);
        CollectTypedMonadsFromExpr(TASTVarDecl(Func.LocalVars[J]).InitialExpr, OptTags, OptInners, ResTags, ResVals, ResErrs);
      end;
      CollectTypedMonadsFromStmts(Func.Body, OptTags, OptInners, ResTags, ResVals, ResErrs);
    end;

    CollectTypedMonadsFromStmts(AModule.InitBody, OptTags, OptInners, ResTags, ResVals, ResErrs);
    CollectTypedMonadsFromStmts(AModule.FiniBody, OptTags, OptInners, ResTags, ResVals, ResErrs);

    if Assigned(AModule.ProgramBlock) then
    begin
      FCurrentFunc := nil;
      FProgramBlock := AModule.ProgramBlock;
      for J := 0 to AModule.ProgramBlock.LocalVars.Count - 1 do
      begin
        CollectTypedMonadsFromType(TASTVarDecl(AModule.ProgramBlock.LocalVars[J]).TypeName, OptTags, OptInners, ResTags, ResVals, ResErrs);
        CollectTypedMonadsFromExpr(TASTVarDecl(AModule.ProgramBlock.LocalVars[J]).InitialExpr, OptTags, OptInners, ResTags, ResVals, ResErrs);
      end;
      CollectTypedMonadsFromStmts(AModule.ProgramBlock.Body, OptTags, OptInners, ResTags, ResVals, ResErrs);
    end;
  finally
    FCurrentFunc := OldFunc;
    FProgramBlock := OldProg;
  end;
end;

procedure TAetherEmitterPascal.EmitTypedOptionDecl(const Tag, InnerT: string);
begin
  Emit(Format('TAetherOpt_%s = record', [Tag]));
  IncIndent;
  Emit('is_some: Boolean;');
  Emit('is_none: Boolean;');
  Emit(Format('value: %s;', [EmitTypeRef(InnerT)]));
  DecIndent;
  Emit('end;');
  Emit('');
end;

procedure TAetherEmitterPascal.EmitTypedResultDecl(const Tag, ValT, ErrT: string);
begin
  Emit(Format('TAetherRes_%s = record', [Tag]));
  IncIndent;
  Emit('is_ok: Boolean;');
  Emit('is_err: Boolean;');
  Emit(Format('value: %s;', [EmitTypeRef(ValT)]));
  Emit(Format('error: %s;', [EmitTypeRef(ErrT)]));
  DecIndent;
  Emit('end;');
  Emit('');
end;

procedure TAetherEmitterPascal.EmitTypedMonadHelpers(OptTags, OptInners, ResTags, ResVals, ResErrs: TStrings; DeclOnly: Boolean);
var
  I: Integer;
  T, InnerPas, ValPas, ErrPas: string;
begin
  for I := 0 to OptTags.Count - 1 do
  begin
    T := OptTags[I];
    InnerPas := EmitTypeRef(OptInners[I]);
    Emit(Format('function AetherSome_%s(const V: %s): TAetherOpt_%s;', [T, InnerPas, T]));
    if not DeclOnly then
    begin
      Emit('begin');
      Emit(Format('  Result := Default(TAetherOpt_%s);', [T]));
      Emit('  Result.is_some := True;');
      Emit('  Result.is_none := False;');
      Emit('  Result.value := V;');
      Emit('end;');
      Emit('');
    end;
    Emit(Format('function AetherNone_%s(): TAetherOpt_%s;', [T, T]));
    if not DeclOnly then
    begin
      Emit('begin');
      Emit(Format('  Result := Default(TAetherOpt_%s);', [T]));
      Emit('  Result.is_some := False;');
      Emit('  Result.is_none := True;');
      Emit('end;');
      Emit('');
    end;
  end;

  for I := 0 to ResTags.Count - 1 do
  begin
    T := ResTags[I];
    ValPas := EmitTypeRef(ResVals[I]);
    ErrPas := EmitTypeRef(ResErrs[I]);
    Emit(Format('function AetherOk_%s(const V: %s): TAetherRes_%s;', [T, ValPas, T]));
    if not DeclOnly then
    begin
      Emit('begin');
      Emit(Format('  Result := Default(TAetherRes_%s);', [T]));
      Emit('  Result.is_ok := True;');
      Emit('  Result.is_err := False;');
      Emit('  Result.value := V;');
      Emit('end;');
      Emit('');
    end;
    Emit(Format('function AetherErr_%s(const E: %s): TAetherRes_%s;', [T, ErrPas, T]));
    if not DeclOnly then
    begin
      Emit('begin');
      Emit(Format('  Result := Default(TAetherRes_%s);', [T]));
      Emit('  Result.is_ok := False;');
      Emit('  Result.is_err := True;');
      Emit('  Result.error := E;');
      Emit('end;');
      Emit('');
    end;
  end;
end;

procedure TAetherEmitterPascal.EmitPayloadEnumConstructors(Enm: TASTEnumDecl; DeclOnly: Boolean);
var
  I, J: Integer;
  V: TASTEnumVariant;
  F: TASTRecordField;
  ParamsStr, FnName: string;
begin
  if not Enm.HasPayload then Exit;
  for I := 0 to Enm.Variants.Count - 1 do
  begin
    V := TASTEnumVariant(Enm.Variants[I]);
    FnName := Enm.Name + '_' + V.Name;
    ParamsStr := '';
    for J := 0 to V.Fields.Count - 1 do
    begin
      F := TASTRecordField(V.Fields[J]);
      if J > 0 then ParamsStr := ParamsStr + '; ';
      ParamsStr := ParamsStr + Format('const A_%s: %s', [F.Name, EmitTypeRef(F.TypeName)]);
    end;
    Emit(Format('function %s(%s): T%s;', [FnName, ParamsStr, Enm.Name]));
    if not DeclOnly then
    begin
      Emit('begin');
      IncIndent;
      Emit(Format('Result := Default(T%s);', [Enm.Name]));
      Emit(Format('Result.tag := %s_Tag_%s;', [Enm.Name, V.Name]));
      for J := 0 to V.Fields.Count - 1 do
      begin
        F := TASTRecordField(V.Fields[J]);
        Emit(Format('Result._v_%s_%s := A_%s;', [V.Name, F.Name, F.Name]));
      end;
      DecIndent;
      Emit('end;');
      Emit('');
    end;
  end;
end;

function TAetherEmitterPascal.IsTypeIdentifier(const AName: string): Boolean;
var
  I: Integer;
begin
  if Assigned(FCurrentFunc) then
  begin
    for I := 0 to FCurrentFunc.LocalVars.Count - 1 do
      if SameText(TASTVarDecl(FCurrentFunc.LocalVars[I]).Name, AName) then Exit(False);
    for I := 0 to FCurrentFunc.Params.Count - 1 do
      if SameText(TASTParam(FCurrentFunc.Params[I]).Name, AName) then Exit(False);
    if FindInlineVarType(FCurrentFunc.Body, AName) <> '' then Exit(False);
  end;
  if Assigned(FProgramBlock) then
  begin
    for I := 0 to FProgramBlock.LocalVars.Count - 1 do
      if SameText(TASTVarDecl(FProgramBlock.LocalVars[I]).Name, AName) then Exit(False);
    if FindInlineVarType(FProgramBlock.Body, AName) <> '' then Exit(False);
  end;
  if (AName = 'Int8') or (AName = 'Int16') or (AName = 'Int32') or (AName = 'Int64') or
     (AName = 'UInt8') or (AName = 'UInt16') or (AName = 'UInt32') or (AName = 'UInt64') or
     (AName = 'Float32') or (AName = 'Float64') or (AName = 'Bool') or (AName = 'Char') or
     (AName = 'String') or (AName = 'Pointer') then
    Exit(True);
  if Assigned(FModule) then
  begin
    for I := 0 to FModule.Types.Count - 1 do
    begin
      if ((FModule.Types[I] is TASTRecordDecl) and SameText(TASTRecordDecl(FModule.Types[I]).Name, AName)) or
         ((FModule.Types[I] is TASTEnumDecl) and SameText(TASTEnumDecl(FModule.Types[I]).Name, AName)) or
         ((FModule.Types[I] is TASTArrayDecl) and SameText(TASTArrayDecl(FModule.Types[I]).Name, AName)) or
         ((FModule.Types[I] is TASTSetDecl) and SameText(TASTSetDecl(FModule.Types[I]).Name, AName)) or
         ((FModule.Types[I] is TASTSubrangeDecl) and SameText(TASTSubrangeDecl(FModule.Types[I]).Name, AName)) or
         ((FModule.Types[I] is TASTMapDecl) and SameText(TASTMapDecl(FModule.Types[I]).Name, AName)) or
         ((FModule.Types[I] is TASTTypeAliasDecl) and SameText(TASTTypeAliasDecl(FModule.Types[I]).Name, AName)) then
        Exit(True);
    end;
  end;
  Result := False;
end;

function TAetherEmitterPascal.EmitMonadFieldExtract(const ExprStr, FieldType, NumField, StrField: string): string;
var
  R: string;
begin
  R := ResolveAliasType(FieldType);
  if R = 'String' then
    Result := ExprStr + '.' + StrField
  else if R = 'Bool' then
    Result := Format('(%s.%s <> 0)', [ExprStr, NumField])
  else if R = 'Char' then
    Result := Format('Chr(Round(%s.%s))', [ExprStr, NumField])
  else if IsIntegerType(R) or IsEnumName(R) then
    Result := Format('%s(Round(%s.%s))', [EmitTypeRef(FieldType), ExprStr, NumField])
  else
    Result := ExprStr + '.' + NumField;
end;

procedure TAetherEmitterPascal.EmitArrayLiteralAssign(const TargetStr, TargetType: string; SetLit: TASTSetLiteralExpr);
var
  I: Integer;
begin
  if IsDynamicArrayType(TargetType) then
    Emit(Format('SetLength(%s, %d);', [TargetStr, SetLit.Elements.Count]));
  for I := 0 to SetLit.Elements.Count - 1 do
    Emit(Format('%s[%d] := %s;', [TargetStr, I, EmitExpr(TASTExpr(SetLit.Elements[I]))]));
end;

procedure TAetherEmitterPascal.EmitMapLiteralAssign(const TargetStr, TargetType: string; MapLit: TASTMapLiteralExpr);
var
  I: Integer;
  K, V, Tag: string;
begin
  if IsMapType(TargetType, K, V) then
  begin
    Tag := MapTag(K, V);
    Emit(Format('%s.count := 0; SetLength(%s.entries, 0);', [TargetStr, TargetStr]));
    for I := 0 to MapLit.Keys.Count - 1 do
      Emit(Format('AetherMapSet_%s(%s, %s, %s);',
        [Tag, TargetStr, EmitExpr(TASTExpr(MapLit.Keys[I])), EmitExpr(TASTExpr(MapLit.Values[I]))]));
  end;
end;

function TAetherEmitterPascal.IsMapType(const AType: string; out KeyType, ValType: string): Boolean;
var
  PClose, I: Integer;
  MapD: TASTMapDecl;
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
  if Assigned(FModule) then
  begin
    for I := 0 to FModule.Types.Count - 1 do
      if (FModule.Types[I] is TASTMapDecl) and SameText(TASTMapDecl(FModule.Types[I]).Name, T) then
      begin
        MapD := TASTMapDecl(FModule.Types[I]);
        KeyType := MapD.KeyType;
        ValType := MapD.ValType;
        Exit(True);
      end;
  end;
  Result := False;
end;

function SanitizeTagPart(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    if S[I] in ['a'..'z', 'A'..'Z', '0'..'9', '_'] then
      Result := Result + S[I]
    else if (S[I] = '^') then
      Result := Result + 'Ptr_'
    else
      Result := Result + '_';
end;

function TAetherEmitterPascal.MapTag(const K, V: string): string;
begin
  Result := SanitizeTagPart(K) + '_' + SanitizeTagPart(V);
end;

function TAetherEmitterPascal.NormalizeIntLit(const Val: string): string;
var
  Prefix, Rest: string;
begin
  Prefix := '';
  Rest := Val;
  if (Length(Rest) > 1) and (Rest[1] = '-') then
  begin
    Prefix := '-';
    Rest := Copy(Rest, 2, Length(Rest));
  end;
  if (Copy(Rest, 1, 2) = '0x') or (Copy(Rest, 1, 2) = '0X') then
    Result := Prefix + '$' + Copy(Rest, 3, Length(Rest))
  else if (Copy(Rest, 1, 2) = '0b') or (Copy(Rest, 1, 2) = '0B') then
    Result := Prefix + '%' + Copy(Rest, 3, Length(Rest))
  else
    Result := Val;
end;

function TAetherEmitterPascal.IsBuiltinMapSideType(const AType: string): Boolean;
begin
  Result := (AType = 'Int8') or (AType = 'Int16') or (AType = 'Int32') or (AType = 'Int64') or
            (AType = 'UInt8') or (AType = 'UInt16') or (AType = 'UInt32') or (AType = 'UInt64') or
            (AType = 'Float32') or (AType = 'Float64') or (AType = 'Bool') or (AType = 'Char') or
            (AType = 'String') or (AType = 'Pointer');
end;

function TAetherEmitterPascal.GetCollectionElemType(Expr: TASTExpr): string;
var
  ColType: string;
  P1, I: Integer;
begin
  Result := '';
  ColType := GetExprTypeName(Expr);
  if ColType = 'String' then
    Exit('Char')
  else if Pos('array of ', ColType) = 1 then
    Exit(Trim(Copy(ColType, 10, Length(ColType))))
  else if Pos('] of ', ColType) > 0 then
  begin
    P1 := Pos('] of ', ColType);
    Exit(Trim(Copy(ColType, P1 + 5, Length(ColType))));
  end
  else if Assigned(FModule) then
  begin
    for I := 0 to FModule.Types.Count - 1 do
      if (FModule.Types[I] is TASTArrayDecl) and SameText(TASTArrayDecl(FModule.Types[I]).Name, ColType) then
        Exit(TASTArrayDecl(FModule.Types[I]).ElemType);
  end;
end;

function TAetherEmitterPascal.FindInlineVarType(Stmts: TASTNodeList; const AName: string): string;
var
  I, K: Integer;
  S: TASTStmt;
  VD: TASTVarDecl;
  MatchNode: TASTMatchStmt;
  CaseNode: TASTMatchCase;
begin
  Result := '';
  if not Assigned(Stmts) then Exit;
  for I := 0 to Stmts.Count - 1 do
  begin
    S := TASTStmt(Stmts[I]);
    if S is TASTVarDeclStmt then
    begin
      for K := 0 to TASTVarDeclStmt(S).Decls.Count - 1 do
      begin
        VD := TASTVarDecl(TASTVarDeclStmt(S).Decls[K]);
        if SameText(VD.Name, AName) then
          Exit(VD.TypeName);
      end;
    end
    else if S is TASTIfStmt then
    begin
      Result := FindInlineVarType(TASTIfStmt(S).ThenBranch, AName);
      if Result <> '' then Exit;
      Result := FindInlineVarType(TASTIfStmt(S).ElseBranch, AName);
      if Result <> '' then Exit;
    end
    else if S is TASTWhileStmt then
    begin
      Result := FindInlineVarType(TASTWhileStmt(S).Body, AName);
      if Result <> '' then Exit;
    end
    else if S is TASTForStmt then
    begin
      Result := FindInlineVarType(TASTForStmt(S).Body, AName);
      if Result <> '' then Exit;
    end
    else if S is TASTRepeatStmt then
    begin
      Result := FindInlineVarType(TASTRepeatStmt(S).Body, AName);
      if Result <> '' then Exit;
    end
    else if S is TASTUnsafeStmt then
    begin
      Result := FindInlineVarType(TASTUnsafeStmt(S).Body, AName);
      if Result <> '' then Exit;
    end
    else if S is TASTTryStmt then
    begin
      Result := FindInlineVarType(TASTTryStmt(S).TryBody, AName);
      if Result <> '' then Exit;
      Result := FindInlineVarType(TASTTryStmt(S).ExceptBody, AName);
      if Result <> '' then Exit;
    end
    else if S is TASTMatchStmt then
    begin
      MatchNode := TASTMatchStmt(S);
      for K := 0 to MatchNode.Cases.Count - 1 do
      begin
        CaseNode := TASTMatchCase(MatchNode.Cases[K]);
        Result := FindInlineVarType(CaseNode.Body, AName);
        if Result <> '' then Exit;
      end;
    end;
  end;
end;

procedure TAetherEmitterPascal.CollectAutoVarsFromExpr(Expr: TASTExpr; VarNames, VarTypes: TStrings; const SkipNames: TStrings);
var
  I, K, BIdx: Integer;
  CaseNode: TASTMatchCase;
  MT, DeclType, KeyT, ValT, BName, TVar, BType: string;

  procedure AddAutoVarLocal(const AName, AType: string);
  var
    J: Integer;
  begin
    for J := 0 to SkipNames.Count - 1 do
      if SameText(SkipNames[J], AName) then Exit;
    for J := 0 to VarNames.Count - 1 do
      if SameText(VarNames[J], AName) then Exit;
    VarNames.Add(AName);
    VarTypes.Add(AType);
  end;
begin
  if not Assigned(Expr) then Exit;
  if Expr is TASTMemberAccessExpr then
    CollectAutoVarsFromExpr(TASTMemberAccessExpr(Expr).Target, VarNames, VarTypes, SkipNames)
  else if Expr is TASTBinaryExpr then
  begin
    CollectAutoVarsFromExpr(TASTBinaryExpr(Expr).Left, VarNames, VarTypes, SkipNames);
    CollectAutoVarsFromExpr(TASTBinaryExpr(Expr).Right, VarNames, VarTypes, SkipNames);
  end
  else if Expr is TASTUnaryExpr then
  begin
    if TASTUnaryExpr(Expr).Op = '?' then
    begin
      MT := EmitTypeRef(ResolveAliasType(GetExprTypeName(TASTUnaryExpr(Expr).Expr)));
      if MT = '' then MT := 'TResultDoubleError';
      AddAutoVarLocal(Format('_aether_try_%d_%d', [Expr.Line, Expr.Col]), MT);
    end;
    CollectAutoVarsFromExpr(TASTUnaryExpr(Expr).Expr, VarNames, VarTypes, SkipNames);
  end
  else if Expr is TASTAwaitExpr then
    CollectAutoVarsFromExpr(TASTAwaitExpr(Expr).Expr, VarNames, VarTypes, SkipNames)
  else if Expr is TASTSpawnExpr then
    CollectAutoVarsFromExpr(TASTSpawnExpr(Expr).CallExpr, VarNames, VarTypes, SkipNames)
  else if Expr is TASTCallExpr then
  begin
    if Assigned(TASTCallExpr(Expr).CalleeExpr) then
      CollectAutoVarsFromExpr(TASTCallExpr(Expr).CalleeExpr, VarNames, VarTypes, SkipNames);
    for I := 0 to TASTCallExpr(Expr).Args.Count - 1 do
      CollectAutoVarsFromExpr(TASTCallArg(TASTCallExpr(Expr).Args[I]).Expr, VarNames, VarTypes, SkipNames);
  end
  else if Expr is TASTTupleLiteralExpr then
  begin
    for I := 0 to TASTTupleLiteralExpr(Expr).Elements.Count - 1 do
      CollectAutoVarsFromExpr(TASTExpr(TASTTupleLiteralExpr(Expr).Elements[I]), VarNames, VarTypes, SkipNames);
  end
  else if Expr is TASTIndexExpr then
  begin
    CollectAutoVarsFromExpr(TASTIndexExpr(Expr).Target, VarNames, VarTypes, SkipNames);
    for I := 0 to TASTIndexExpr(Expr).Indices.Count - 1 do
      CollectAutoVarsFromExpr(TASTExpr(TASTIndexExpr(Expr).Indices[I]), VarNames, VarTypes, SkipNames);
  end
  else if Expr is TASTSetLiteralExpr then
  begin
    for I := 0 to TASTSetLiteralExpr(Expr).Elements.Count - 1 do
      CollectAutoVarsFromExpr(TASTExpr(TASTSetLiteralExpr(Expr).Elements[I]), VarNames, VarTypes, SkipNames);
  end
  else if Expr is TASTMapLiteralExpr then
  begin
    MT := GetExprTypeName(Expr);
    if IsMapType(MT, KeyT, ValT) then
      AddAutoVarLocal(Format('_aether_mlit_%d_%d', [Expr.Line, Expr.Col]), EmitTypeRef(MT));
    for I := 0 to TASTMapLiteralExpr(Expr).Keys.Count - 1 do
    begin
      CollectAutoVarsFromExpr(TASTExpr(TASTMapLiteralExpr(Expr).Keys[I]), VarNames, VarTypes, SkipNames);
      CollectAutoVarsFromExpr(TASTExpr(TASTMapLiteralExpr(Expr).Values[I]), VarNames, VarTypes, SkipNames);
    end;
  end
  else if Expr is TASTIfExpr then
  begin
    CollectAutoVarsFromExpr(TASTIfExpr(Expr).Condition, VarNames, VarTypes, SkipNames);
    CollectAutoVarsFromExpr(TASTIfExpr(Expr).ThenExpr, VarNames, VarTypes, SkipNames);
    CollectAutoVarsFromExpr(TASTIfExpr(Expr).ElseExpr, VarNames, VarTypes, SkipNames);
  end
  else if Expr is TASTMatchExpr then
  begin
    DeclType := EmitTypeRef(ResolveAliasType(GetExprTypeName(Expr)));
    if DeclType = '' then DeclType := 'Int32';
    AddAutoVarLocal(Format('_aether_mexpr_%d_%d', [Expr.Line, Expr.Col]), DeclType);
    CollectAutoVarsFromExpr(TASTMatchExpr(Expr).Expr, VarNames, VarTypes, SkipNames);
    MT := ResolveAliasType(GetExprTypeName(TASTMatchExpr(Expr).Expr));
    DeclType := EmitTypeRef(MT);
    if DeclType = '' then DeclType := 'Int32';
    AddAutoVarLocal(Format('_aether_mval_%d_%d', [Expr.Line, Expr.Col]), DeclType);
    for K := 0 to TASTMatchExpr(Expr).Cases.Count - 1 do
    begin
      CaseNode := TASTMatchCase(TASTMatchExpr(Expr).Cases[K]);
      I := GetMatchArmBindingCount(CaseNode);
      for BIdx := 0 to I - 1 do
      begin
        GetMatchArmBindingInfo(CaseNode, BIdx, MT, BName, TVar, BType);
        if (BName <> '') and (BName <> '_') then
        begin
          DeclType := EmitTypeRef(BType);
          if DeclType = '' then DeclType := 'Int32';
          AddAutoVarLocal(TVar, DeclType);
        end;
      end;
      PushMatchBindings(CaseNode, MT);
      try
        CollectAutoVarsFromExpr(CaseNode.Guard, VarNames, VarTypes, SkipNames);
        CollectAutoVarsFromExpr(CaseNode.ValueExpr, VarNames, VarTypes, SkipNames);
      finally
        for BIdx := 0 to I - 1 do
        begin
          GetMatchArmBindingInfo(CaseNode, BIdx, MT, BName, TVar, BType);
          if (BName <> '') and (BName <> '_') then PopMatchBindings(1);
        end;
      end;
    end;
  end;
end;

procedure TAetherEmitterPascal.CollectAutoVarsFromStmts(Stmts: TASTNodeList; VarNames, VarTypes: TStrings; const SkipNames: TStrings);
var
  I, K, BIdx, BCount: Integer;
  S: TASTStmt;
  ForStmt: TASTForStmt;
  MatchNode: TASTMatchStmt;
  CaseNode: TASTMatchCase;
  VD: TASTVarDecl;
  ElemT, MT, DeclType, KeyT, ValT, BName, TVar, BType: string;

  procedure AddAutoVar(const AName, AType: string);
  var
    J: Integer;
  begin
    for J := 0 to SkipNames.Count - 1 do
      if SameText(SkipNames[J], AName) then Exit;
    for J := 0 to VarNames.Count - 1 do
      if SameText(VarNames[J], AName) then Exit;
    VarNames.Add(AName);
    VarTypes.Add(AType);
  end;
begin
  if not Assigned(Stmts) then Exit;
  for I := 0 to Stmts.Count - 1 do
  begin
    S := TASTStmt(Stmts[I]);
    if S is TASTVarDeclStmt then
    begin
      for K := 0 to TASTVarDeclStmt(S).Decls.Count - 1 do
      begin
        VD := TASTVarDecl(TASTVarDeclStmt(S).Decls[K]);
        AddAutoVar(VD.Name, EmitTypeRef(VD.TypeName));
        if Assigned(VD.InitialExpr) and not (VD.InitialExpr is TASTMapLiteralExpr) then
          CollectAutoVarsFromExpr(VD.InitialExpr, VarNames, VarTypes, SkipNames);
      end;
    end
    else if S is TASTAssignStmt then
    begin
      CollectAutoVarsFromExpr(TASTAssignStmt(S).Target, VarNames, VarTypes, SkipNames);
      if not (TASTAssignStmt(S).Expr is TASTMapLiteralExpr) then
        CollectAutoVarsFromExpr(TASTAssignStmt(S).Expr, VarNames, VarTypes, SkipNames);
    end
    else if S is TASTCallStmt then
      CollectAutoVarsFromExpr(TASTCallStmt(S).CallExpr, VarNames, VarTypes, SkipNames)
    else if S is TASTReturnStmt then
      CollectAutoVarsFromExpr(TASTReturnStmt(S).Expr, VarNames, VarTypes, SkipNames)
    else if S is TASTDeferStmt then
    begin
      if Assigned(TASTDeferStmt(S).Stmt) then
      begin
        if TASTDeferStmt(S).Stmt is TASTCallStmt then
          CollectAutoVarsFromExpr(TASTCallStmt(TASTDeferStmt(S).Stmt).CallExpr, VarNames, VarTypes, SkipNames)
        else if TASTDeferStmt(S).Stmt is TASTAssignStmt then
          CollectAutoVarsFromExpr(TASTAssignStmt(TASTDeferStmt(S).Stmt).Expr, VarNames, VarTypes, SkipNames);
      end;
    end
    else if S is TASTForStmt then
    begin
      ForStmt := TASTForStmt(S);
      if Assigned(ForStmt.CollectionExpr) then
      begin
        CollectAutoVarsFromExpr(ForStmt.CollectionExpr, VarNames, VarTypes, SkipNames);
        MT := GetExprTypeName(ForStmt.CollectionExpr);
        if IsMapType(MT, KeyT, ValT) then
        begin
          AddAutoVar(ForStmt.VarName, EmitTypeRef(KeyT));
          if ForStmt.ValVarName <> '' then
            AddAutoVar(ForStmt.ValVarName, EmitTypeRef(ValT));
          AddAutoVar(Format('_aether_mi_%d_%d', [ForStmt.Line, ForStmt.Col]), 'Int32');
        end
        else
        begin
          ElemT := GetCollectionElemType(ForStmt.CollectionExpr);
          if ElemT <> '' then
            AddAutoVar(ForStmt.VarName, EmitTypeRef(ElemT))
          else
            AddAutoVar(ForStmt.VarName, 'LongInt');
        end;
      end
      else
      begin
        CollectAutoVarsFromExpr(ForStmt.StartExpr, VarNames, VarTypes, SkipNames);
        CollectAutoVarsFromExpr(ForStmt.EndExpr, VarNames, VarTypes, SkipNames);
        AddAutoVar(ForStmt.VarName, 'LongInt');
      end;
      CollectAutoVarsFromStmts(ForStmt.Body, VarNames, VarTypes, SkipNames);
    end
    else if S is TASTIfStmt then
    begin
      CollectAutoVarsFromExpr(TASTIfStmt(S).Condition, VarNames, VarTypes, SkipNames);
      CollectAutoVarsFromStmts(TASTIfStmt(S).ThenBranch, VarNames, VarTypes, SkipNames);
      CollectAutoVarsFromStmts(TASTIfStmt(S).ElseBranch, VarNames, VarTypes, SkipNames);
    end
    else if S is TASTWhileStmt then
    begin
      CollectAutoVarsFromExpr(TASTWhileStmt(S).Condition, VarNames, VarTypes, SkipNames);
      CollectAutoVarsFromStmts(TASTWhileStmt(S).Body, VarNames, VarTypes, SkipNames);
    end
    else if S is TASTRepeatStmt then
    begin
      CollectAutoVarsFromStmts(TASTRepeatStmt(S).Body, VarNames, VarTypes, SkipNames);
      CollectAutoVarsFromExpr(TASTRepeatStmt(S).Condition, VarNames, VarTypes, SkipNames);
    end
    else if S is TASTUnsafeStmt then
      CollectAutoVarsFromStmts(TASTUnsafeStmt(S).Body, VarNames, VarTypes, SkipNames)
    else if S is TASTTryStmt then
    begin
      CollectAutoVarsFromStmts(TASTTryStmt(S).TryBody, VarNames, VarTypes, SkipNames);
      CollectAutoVarsFromStmts(TASTTryStmt(S).ExceptBody, VarNames, VarTypes, SkipNames);
    end
    else if S is TASTMatchStmt then
    begin
      MatchNode := TASTMatchStmt(S);
      CollectAutoVarsFromExpr(MatchNode.Expr, VarNames, VarTypes, SkipNames);
      MT := ResolveAliasType(GetExprTypeName(MatchNode.Expr));
      DeclType := EmitTypeRef(MT);
      if DeclType = '' then DeclType := 'Int32';
      AddAutoVar(Format('_aether_mval_%d_%d', [MatchNode.Line, MatchNode.Col]), DeclType);
      for K := 0 to MatchNode.Cases.Count - 1 do
      begin
        CaseNode := TASTMatchCase(MatchNode.Cases[K]);
        BCount := GetMatchArmBindingCount(CaseNode);
        for BIdx := 0 to BCount - 1 do
        begin
          GetMatchArmBindingInfo(CaseNode, BIdx, MT, BName, TVar, BType);
          if (BName <> '') and (BName <> '_') then
          begin
            DeclType := EmitTypeRef(BType);
            if DeclType = '' then DeclType := 'Int32';
            AddAutoVar(TVar, DeclType);
          end;
        end;
        PushMatchBindings(CaseNode, MT);
        try
          CollectAutoVarsFromExpr(CaseNode.Guard, VarNames, VarTypes, SkipNames);
          CollectAutoVarsFromStmts(CaseNode.Body, VarNames, VarTypes, SkipNames);
        finally
          for BIdx := 0 to BCount - 1 do
          begin
            GetMatchArmBindingInfo(CaseNode, BIdx, MT, BName, TVar, BType);
            if (BName <> '') and (BName <> '_') then PopMatchBindings(1);
          end;
        end;
      end;
    end;
  end;
end;

procedure TAetherEmitterPascal.CollectMapsFromType(const AType: string; Tags, Keys, Vals: TStrings);
var
  K, V, Tag: string;
begin
  if IsMapType(AType, K, V) then
  begin
    Tag := MapTag(K, V);
    if Tags.IndexOf(Tag) = -1 then
    begin
      Tags.Add(Tag);
      Keys.Add(K);
      Vals.Add(V);
    end;
  end;
end;

procedure TAetherEmitterPascal.CollectMapsFromExpr(Expr: TASTExpr; Tags, Keys, Vals: TStrings);
var
  I: Integer;
begin
  if not Assigned(Expr) then Exit;
  if Expr is TASTMapLiteralExpr then
  begin
    CollectMapsFromType(GetExprTypeName(Expr), Tags, Keys, Vals);
    for I := 0 to TASTMapLiteralExpr(Expr).Keys.Count - 1 do
    begin
      CollectMapsFromExpr(TASTExpr(TASTMapLiteralExpr(Expr).Keys[I]), Tags, Keys, Vals);
      CollectMapsFromExpr(TASTExpr(TASTMapLiteralExpr(Expr).Values[I]), Tags, Keys, Vals);
    end;
  end
  else if Expr is TASTBinaryExpr then
  begin
    CollectMapsFromExpr(TASTBinaryExpr(Expr).Left, Tags, Keys, Vals);
    CollectMapsFromExpr(TASTBinaryExpr(Expr).Right, Tags, Keys, Vals);
  end
  else if Expr is TASTUnaryExpr then
    CollectMapsFromExpr(TASTUnaryExpr(Expr).Expr, Tags, Keys, Vals)
  else if Expr is TASTMemberAccessExpr then
    CollectMapsFromExpr(TASTMemberAccessExpr(Expr).Target, Tags, Keys, Vals)
  else if Expr is TASTCallExpr then
  begin
    for I := 0 to TASTCallExpr(Expr).Args.Count - 1 do
      CollectMapsFromExpr(TASTCallArg(TASTCallExpr(Expr).Args[I]).Expr, Tags, Keys, Vals);
  end
  else if Expr is TASTIndexExpr then
  begin
    CollectMapsFromExpr(TASTIndexExpr(Expr).Target, Tags, Keys, Vals);
    for I := 0 to TASTIndexExpr(Expr).Indices.Count - 1 do
      CollectMapsFromExpr(TASTExpr(TASTIndexExpr(Expr).Indices[I]), Tags, Keys, Vals);
  end
  else if Expr is TASTIfExpr then
  begin
    CollectMapsFromExpr(TASTIfExpr(Expr).Condition, Tags, Keys, Vals);
    CollectMapsFromExpr(TASTIfExpr(Expr).ThenExpr, Tags, Keys, Vals);
    CollectMapsFromExpr(TASTIfExpr(Expr).ElseExpr, Tags, Keys, Vals);
  end
  else if Expr is TASTMatchExpr then
  begin
    CollectMapsFromExpr(TASTMatchExpr(Expr).Expr, Tags, Keys, Vals);
    for I := 0 to TASTMatchExpr(Expr).Cases.Count - 1 do
    begin
      CollectMapsFromExpr(TASTMatchCase(TASTMatchExpr(Expr).Cases[I]).Guard, Tags, Keys, Vals);
      CollectMapsFromExpr(TASTMatchCase(TASTMatchExpr(Expr).Cases[I]).ValueExpr, Tags, Keys, Vals);
    end;
  end;
end;

procedure TAetherEmitterPascal.CollectMapsFromStmts(Stmts: TASTNodeList; Tags, Keys, Vals: TStrings);
var
  I, K: Integer;
  S: TASTStmt;
begin
  if not Assigned(Stmts) then Exit;
  for I := 0 to Stmts.Count - 1 do
  begin
    S := TASTStmt(Stmts[I]);
    if S is TASTVarDeclStmt then
    begin
      for K := 0 to TASTVarDeclStmt(S).Decls.Count - 1 do
      begin
        CollectMapsFromType(TASTVarDecl(TASTVarDeclStmt(S).Decls[K]).TypeName, Tags, Keys, Vals);
        CollectMapsFromExpr(TASTVarDecl(TASTVarDeclStmt(S).Decls[K]).InitialExpr, Tags, Keys, Vals);
      end;
    end
    else if S is TASTAssignStmt then
    begin
      CollectMapsFromExpr(TASTAssignStmt(S).Target, Tags, Keys, Vals);
      CollectMapsFromExpr(TASTAssignStmt(S).Expr, Tags, Keys, Vals);
    end
    else if S is TASTCallStmt then
      CollectMapsFromExpr(TASTCallStmt(S).CallExpr, Tags, Keys, Vals)
    else if S is TASTReturnStmt then
      CollectMapsFromExpr(TASTReturnStmt(S).Expr, Tags, Keys, Vals)
    else if S is TASTIfStmt then
    begin
      CollectMapsFromExpr(TASTIfStmt(S).Condition, Tags, Keys, Vals);
      CollectMapsFromStmts(TASTIfStmt(S).ThenBranch, Tags, Keys, Vals);
      CollectMapsFromStmts(TASTIfStmt(S).ElseBranch, Tags, Keys, Vals);
    end
    else if S is TASTWhileStmt then
    begin
      CollectMapsFromExpr(TASTWhileStmt(S).Condition, Tags, Keys, Vals);
      CollectMapsFromStmts(TASTWhileStmt(S).Body, Tags, Keys, Vals);
    end
    else if S is TASTForStmt then
    begin
      CollectMapsFromExpr(TASTForStmt(S).CollectionExpr, Tags, Keys, Vals);
      CollectMapsFromStmts(TASTForStmt(S).Body, Tags, Keys, Vals);
    end
    else if S is TASTRepeatStmt then
    begin
      CollectMapsFromStmts(TASTRepeatStmt(S).Body, Tags, Keys, Vals);
      CollectMapsFromExpr(TASTRepeatStmt(S).Condition, Tags, Keys, Vals);
    end
    else if S is TASTUnsafeStmt then
      CollectMapsFromStmts(TASTUnsafeStmt(S).Body, Tags, Keys, Vals)
    else if S is TASTTryStmt then
    begin
      CollectMapsFromStmts(TASTTryStmt(S).TryBody, Tags, Keys, Vals);
      CollectMapsFromStmts(TASTTryStmt(S).ExceptBody, Tags, Keys, Vals);
    end
    else if S is TASTMatchStmt then
    begin
      CollectMapsFromExpr(TASTMatchStmt(S).Expr, Tags, Keys, Vals);
      for K := 0 to TASTMatchStmt(S).Cases.Count - 1 do
      begin
        CollectMapsFromExpr(TASTMatchCase(TASTMatchStmt(S).Cases[K]).Guard, Tags, Keys, Vals);
        CollectMapsFromStmts(TASTMatchCase(TASTMatchStmt(S).Cases[K]).Body, Tags, Keys, Vals);
      end;
    end;
  end;
end;

procedure TAetherEmitterPascal.CollectMapsFromModule(AModule: TASTModule; Tags, Keys, Vals: TStrings);
var
  I, J: Integer;
  Rec: TASTRecordDecl;
  Func: TASTFunction;
begin
  for I := 0 to AModule.Types.Count - 1 do
  begin
    if AModule.Types[I] is TASTMapDecl then
      CollectMapsFromType(TASTMapDecl(AModule.Types[I]).Name, Tags, Keys, Vals)
    else if AModule.Types[I] is TASTRecordDecl then
    begin
      Rec := TASTRecordDecl(AModule.Types[I]);
      for J := 0 to Rec.Fields.Count - 1 do
        CollectMapsFromType(TASTRecordField(Rec.Fields[J]).TypeName, Tags, Keys, Vals);
    end
    else if AModule.Types[I] is TASTArrayDecl then
      CollectMapsFromType(TASTArrayDecl(AModule.Types[I]).ElemType, Tags, Keys, Vals);
  end;
  for I := 0 to AModule.Functions.Count - 1 do
  begin
    Func := TASTFunction(AModule.Functions[I]);
    FCurrentFunc := Func;
    CollectMapsFromType(Func.ReturnType, Tags, Keys, Vals);
    for J := 0 to Func.Params.Count - 1 do
      CollectMapsFromType(TASTParam(Func.Params[J]).TypeName, Tags, Keys, Vals);
    for J := 0 to Func.LocalVars.Count - 1 do
    begin
      CollectMapsFromType(TASTVarDecl(Func.LocalVars[J]).TypeName, Tags, Keys, Vals);
      CollectMapsFromExpr(TASTVarDecl(Func.LocalVars[J]).InitialExpr, Tags, Keys, Vals);
    end;
    CollectMapsFromStmts(Func.Body, Tags, Keys, Vals);
    FCurrentFunc := nil;
  end;
  for I := 0 to AModule.ModuleVars.Count - 1 do
  begin
    CollectMapsFromType(TASTVarDecl(AModule.ModuleVars[I]).TypeName, Tags, Keys, Vals);
    CollectMapsFromExpr(TASTVarDecl(AModule.ModuleVars[I]).InitialExpr, Tags, Keys, Vals);
  end;
  CollectMapsFromStmts(AModule.InitBody, Tags, Keys, Vals);
  CollectMapsFromStmts(AModule.FiniBody, Tags, Keys, Vals);
  if Assigned(AModule.ProgramBlock) then
  begin
    FProgramBlock := AModule.ProgramBlock;
    for I := 0 to AModule.ProgramBlock.LocalVars.Count - 1 do
    begin
      CollectMapsFromType(TASTVarDecl(AModule.ProgramBlock.LocalVars[I]).TypeName, Tags, Keys, Vals);
      CollectMapsFromExpr(TASTVarDecl(AModule.ProgramBlock.LocalVars[I]).InitialExpr, Tags, Keys, Vals);
    end;
    CollectMapsFromStmts(AModule.ProgramBlock.Body, Tags, Keys, Vals);
    FProgramBlock := nil;
  end;
end;

procedure TAetherEmitterPascal.EmitMapRuntimeDecls(Tags, Keys, Vals: TStrings; BuiltinOnly: Boolean);
var
  I: Integer;
  IsBuiltin: Boolean;
begin
  for I := 0 to Tags.Count - 1 do
  begin
    IsBuiltin := IsBuiltinMapSideType(Keys[I]) and IsBuiltinMapSideType(Vals[I]);
    if IsBuiltin = BuiltinOnly then
    begin
      Emit(Format('  TAetherMapEntry_%s = record', [Tags[I]]));
      Emit(Format('    key: %s;', [EmitTypeRef(Keys[I])]));
      Emit(Format('    val: %s;', [EmitTypeRef(Vals[I])]));
      Emit('  end;');
      Emit(Format('  TAetherMap_%s = record', [Tags[I]]));
      Emit(Format('    entries: array of TAetherMapEntry_%s;', [Tags[I]]));
      Emit('    count: Int32;');
      Emit('  end;');
    end;
  end;
end;

procedure TAetherEmitterPascal.EmitMapRuntimeHelpers(Tags, Keys, Vals: TStrings; DeclOnly: Boolean);
var
  I: Integer;
  Tag, PK, PV, DefStmt: string;
begin
  for I := 0 to Tags.Count - 1 do
  begin
    Tag := Tags[I];
    PK := EmitTypeRef(Keys[I]);
    PV := EmitTypeRef(Vals[I]);

    if DeclOnly then
    begin
      Emit(Format('procedure AetherMapSet_%s(var m: TAetherMap_%s; const k: %s; const v: %s);', [Tag, Tag, PK, PV]));
      Emit(Format('function AetherMapGet_%s(const m: TAetherMap_%s; const k: %s): %s;', [Tag, Tag, PK, PV]));
      Emit(Format('function AetherMapContains_%s(const m: TAetherMap_%s; const k: %s): Boolean;', [Tag, Tag, PK]));
      Emit(Format('procedure AetherMapRemove_%s(var m: TAetherMap_%s; const k: %s);', [Tag, Tag, PK]));
    end
    else
    begin
      Emit(Format('procedure AetherMapSet_%s(var m: TAetherMap_%s; const k: %s; const v: %s);', [Tag, Tag, PK, PV]));
      Emit('var i: Int32;');
      Emit('begin');
      Emit('  for i := 0 to m.count - 1 do');
      Emit('    if m.entries[i].key = k then begin m.entries[i].val := v; Exit; end;');
      Emit('  if m.count >= Length(m.entries) then');
      Emit('  begin');
      Emit('    if Length(m.entries) = 0 then SetLength(m.entries, 8)');
      Emit('    else SetLength(m.entries, Length(m.entries) * 2);');
      Emit('  end;');
      Emit('  m.entries[m.count].key := k;');
      Emit('  m.entries[m.count].val := v;');
      Emit('  Inc(m.count);');
      Emit('end;');
      Emit('');

      if Vals[I] = 'String' then DefStmt := '  Result := '''';'
      else if Vals[I] = 'Bool' then DefStmt := '  Result := False;'
      else if Vals[I] = 'Char' then DefStmt := '  Result := #0;'
      else if (Vals[I] = 'Float32') or (Vals[I] = 'Float64') then DefStmt := '  Result := 0.0;'
      else if IsIntegerType(Vals[I]) then DefStmt := '  Result := 0;'
      else if (Pos('^', Vals[I]) = 1) or (Vals[I] = 'Pointer') or (Pos('Box<', Vals[I]) > 0) then DefStmt := '  Result := nil;'
      else DefStmt := '  FillChar(Result, SizeOf(Result), 0);';

      Emit(Format('function AetherMapGet_%s(const m: TAetherMap_%s; const k: %s): %s;', [Tag, Tag, PK, PV]));
      Emit('var i: Int32;');
      Emit('begin');
      Emit('  for i := 0 to m.count - 1 do');
      Emit('    if m.entries[i].key = k then Exit(m.entries[i].val);');
      Emit(DefStmt);
      Emit('end;');
      Emit('');

      Emit(Format('function AetherMapContains_%s(const m: TAetherMap_%s; const k: %s): Boolean;', [Tag, Tag, PK]));
      Emit('var i: Int32;');
      Emit('begin');
      Emit('  for i := 0 to m.count - 1 do');
      Emit('    if m.entries[i].key = k then Exit(True);');
      Emit('  Result := False;');
      Emit('end;');
      Emit('');

      Emit(Format('procedure AetherMapRemove_%s(var m: TAetherMap_%s; const k: %s);', [Tag, Tag, PK]));
      Emit('var i: Int32;');
      Emit('begin');
      Emit('  for i := 0 to m.count - 1 do');
      Emit('    if m.entries[i].key = k then');
      Emit('    begin');
      Emit('      Dec(m.count);');
      Emit('      m.entries[i] := m.entries[m.count];');
      Emit('      Exit;');
      Emit('    end;');
      Emit('end;');
      Emit('');
    end;
  end;
end;

function TAetherEmitterPascal.GetExprTypeName(Expr: TASTExpr): string;
var
  Id: TASTIdentifierExpr;
  Acc: TASTMemberAccessExpr;
  Call: TASTCallExpr;
  Bin: TASTBinaryExpr;
  TargetType, CleanTarget, KeyType, ValType, LeftType: string;
  I, J, P1, P2: Integer;
  Rec: TASTRecordDecl;
  V: TASTVarDecl;
  P: TASTParam;
  FnParams: TStringList;
begin
  Result := '';
  if not Assigned(Expr) then Exit;

  if Expr is TASTLiteralExpr then
  begin
    case TASTLiteralExpr(Expr).Kind of
      lkInt: Exit('Int32');
      lkFloat: Exit('Float64');
      lkBool: Exit('Bool');
      lkString: Exit('String');
      lkChar: Exit('Char');
    end;
  end;

  if Expr is TASTIdentifierExpr then
  begin
    Id := TASTIdentifierExpr(Expr);
    if Id.IsFnValueRef and (Id.ResolvedFnType <> '') then
      Exit(Id.ResolvedFnType);
    if Id.ResolvedMonadType <> '' then
      Exit(Id.ResolvedMonadType);
    for I := FMatchBindNames.Count - 1 downto 0 do
      if SameText(FMatchBindNames[I], Id.Name) then
        Exit(FMatchBindTypes[I]);
    if Assigned(FCurrentFunc) and SameText(Id.Name, 'result') then
      Exit(FCurrentFunc.ReturnType);
    if Assigned(FCurrentFunc) then
    begin
      for I := 0 to FCurrentFunc.LocalVars.Count - 1 do
      begin
        V := TASTVarDecl(FCurrentFunc.LocalVars[I]);
        if SameText(V.Name, Id.Name) then Exit(V.TypeName);
      end;
      for I := 0 to FCurrentFunc.Params.Count - 1 do
      begin
        P := TASTParam(FCurrentFunc.Params[I]);
        if SameText(P.Name, Id.Name) then Exit(P.TypeName);
      end;
      LeftType := FindInlineVarType(FCurrentFunc.Body, Id.Name);
      if LeftType <> '' then Exit(LeftType);
    end;
    if Assigned(FProgramBlock) then
    begin
      for I := 0 to FProgramBlock.LocalVars.Count - 1 do
      begin
        V := TASTVarDecl(FProgramBlock.LocalVars[I]);
        if SameText(V.Name, Id.Name) then Exit(V.TypeName);
      end;
      LeftType := FindInlineVarType(FProgramBlock.Body, Id.Name);
      if LeftType <> '' then Exit(LeftType);
    end;
    if Assigned(FModule) then
    begin
      for I := 0 to FModule.Constants.Count - 1 do
        if SameText(TASTConstDecl(FModule.Constants[I]).Name, Id.Name) then
          Exit(TASTConstDecl(FModule.Constants[I]).TypeName);
      for I := 0 to FModule.Types.Count - 1 do
        if FModule.Types[I] is TASTEnumDecl then
          for J := 0 to TASTEnumDecl(FModule.Types[I]).Variants.Count - 1 do
            if SameText(TASTEnumVariant(TASTEnumDecl(FModule.Types[I]).Variants[J]).Name, Id.Name) then
              Exit(TASTEnumDecl(FModule.Types[I]).Name);
    end;
  end
  else if Expr is TASTMemberAccessExpr then
  begin
    Acc := TASTMemberAccessExpr(Expr);
    if (Acc.Target is TASTIdentifierExpr) and IsEnumName(TASTIdentifierExpr(Acc.Target).Name) then
      Exit(TASTIdentifierExpr(Acc.Target).Name);
    TargetType := ResolveAliasType(GetExprTypeName(Acc.Target));
    if (Pos('Result', TargetType) = 1) then
    begin
      if SameText(Acc.Member, 'is_ok') or SameText(Acc.Member, 'is_err') then Exit('Bool');
      SplitResultTypes(TargetType, KeyType, ValType);
      if SameText(Acc.Member, 'value') then Exit(KeyType);
      if SameText(Acc.Member, 'error') then Exit(ValType);
    end;
    if (Pos('Option<', TargetType) = 1) then
    begin
      if SameText(Acc.Member, 'is_some') or SameText(Acc.Member, 'is_none') then Exit('Bool');
      if SameText(Acc.Member, 'value') then
      begin
        CleanTarget := SafeUnwrapGeneric(TargetType, 'Option');
        if Pos('Box<', CleanTarget) = 1 then
          CleanTarget := SafeUnwrapGeneric(CleanTarget, 'Box');
        Exit(CleanTarget);
      end;
    end;
    if Pos('Box<', TargetType) > 0 then
    begin
      CleanTarget := TargetType;
      if Pos('Option<', CleanTarget) = 1 then
        CleanTarget := SafeUnwrapGeneric(CleanTarget, 'Option');
      if Pos('Box<', CleanTarget) = 1 then
        CleanTarget := SafeUnwrapGeneric(CleanTarget, 'Box');
    end
    else if Pos('Option<', TargetType) = 1 then
    begin
      CleanTarget := SafeUnwrapGeneric(TargetType, 'Option');
      if Pos('Box<', CleanTarget) = 1 then
        CleanTarget := SafeUnwrapGeneric(CleanTarget, 'Box');
    end
    else
      CleanTarget := TargetType;

    if Assigned(FModule) then
    begin
      for I := 0 to FModule.Types.Count - 1 do
      begin
        if (FModule.Types[I] is TASTRecordDecl) and SameText(TASTRecordDecl(FModule.Types[I]).Name, CleanTarget) then
        begin
          Rec := TASTRecordDecl(FModule.Types[I]);
          for J := 0 to Rec.Fields.Count - 1 do
          begin
            if SameText(TASTRecordField(Rec.Fields[J]).Name, Acc.Member) then
              Exit(TASTRecordField(Rec.Fields[J]).TypeName);
          end;
        end;
      end;
    end;
  end
  else if Expr is TASTBinaryExpr then
  begin
    Bin := TASTBinaryExpr(Expr);
    if (Bin.Op = '+') and ((GetExprTypeName(Bin.Left) = 'String') or (GetExprTypeName(Bin.Right) = 'String')) then
      Exit('String');
    if (Bin.Op = '=') or (Bin.Op = '<>') or (Bin.Op = '<') or (Bin.Op = '<=') or
       (Bin.Op = '>') or (Bin.Op = '>=') or SameText(Bin.Op, 'implies') or SameText(Bin.Op, 'in') then
      Exit('Bool');
    if SameText(Bin.Op, 'and') or SameText(Bin.Op, 'or') then
    begin
      LeftType := GetExprTypeName(Bin.Left);
      if LeftType = 'Bool' then Exit('Bool');
      if IsIntegerType(LeftType) then Exit(LeftType);
    end;
    if SameText(Bin.Op, 'shl') or SameText(Bin.Op, 'shr') or SameText(Bin.Op, 'xor') or
       SameText(Bin.Op, 'div') or SameText(Bin.Op, 'mod') or
       (Bin.Op = '+') or (Bin.Op = '-') or (Bin.Op = '*') or (Bin.Op = '/') then
    begin
      LeftType := GetExprTypeName(Bin.Left);
      if LeftType <> '' then Exit(LeftType);
      Exit(GetExprTypeName(Bin.Right));
    end;
  end
  else if Expr is TASTIndexExpr then
  begin
    if TASTIndexExpr(Expr).Target is TASTSetLiteralExpr then
    begin
      if TASTSetLiteralExpr(TASTIndexExpr(Expr).Target).Elements.Count > 0 then
        Exit(GetExprTypeName(TASTExpr(TASTSetLiteralExpr(TASTIndexExpr(Expr).Target).Elements[0])));
    end;
    TargetType := ResolveAliasType(GetExprTypeName(TASTIndexExpr(Expr).Target));
    if TargetType = 'String' then
      Exit('Char')
    else if IsMapType(TargetType, KeyType, ValType) then
      Exit(ValType)
    else if Pos('array of ', TargetType) = 1 then
      Exit(Trim(Copy(TargetType, 10, Length(TargetType))))
    else if Pos('] of ', TargetType) > 0 then
      Exit(Trim(Copy(TargetType, Pos('] of ', TargetType) + 5, Length(TargetType))))
    else if Assigned(FModule) then
    begin
      for I := 0 to FModule.Types.Count - 1 do
        if (FModule.Types[I] is TASTArrayDecl) and SameText(TASTArrayDecl(FModule.Types[I]).Name, TargetType) then
          Exit(TASTArrayDecl(FModule.Types[I]).ElemType);
    end;
  end
  else if Expr is TASTUnaryExpr then
  begin
    TargetType := ResolveAliasType(GetExprTypeName(TASTUnaryExpr(Expr).Expr));
    if TASTUnaryExpr(Expr).Op = '?' then
    begin
      if Pos('Result', TargetType) = 1 then
      begin
        SplitResultTypes(TargetType, KeyType, ValType);
        Exit(KeyType);
      end
      else if Pos('Option<', TargetType) = 1 then
        Exit(Trim(Copy(TargetType, 8, Length(TargetType) - 8)));
    end
    else if TASTUnaryExpr(Expr).Op = '@' then
      Exit('^' + TargetType)
    else if (TASTUnaryExpr(Expr).Op = '^') and (Pos('^', TargetType) = 1) then
      Exit(Copy(TargetType, 2, Length(TargetType)))
    else if SameText(TASTUnaryExpr(Expr).Op, 'not') or (TASTUnaryExpr(Expr).Op = '-') then
      Exit(TargetType);
  end
  else if Expr is TASTMapLiteralExpr then
  begin
    if TASTMapLiteralExpr(Expr).Keys.Count > 0 then
    begin
      KeyType := GetExprTypeName(TASTExpr(TASTMapLiteralExpr(Expr).Keys[0]));
      ValType := GetExprTypeName(TASTExpr(TASTMapLiteralExpr(Expr).Values[0]));
      if (KeyType <> '') and (ValType <> '') then
        Exit(Format('map[%s]%s', [KeyType, ValType]));
    end;
  end
  else if Expr is TASTMatchExpr then
  begin
    for I := 0 to TASTMatchExpr(Expr).Cases.Count - 1 do
    begin
      LeftType := ResolveAliasType(GetExprTypeName(TASTMatchCase(TASTMatchExpr(Expr).Cases[I]).ValueExpr));
      if LeftType <> '' then Exit(LeftType);
    end;
  end
  else if Expr is TASTIfExpr then
  begin
    LeftType := ResolveAliasType(GetExprTypeName(TASTIfExpr(Expr).ThenExpr));
    CleanTarget := ResolveAliasType(GetExprTypeName(TASTIfExpr(Expr).ElseExpr));
    if (LeftType = 'Float64') or (CleanTarget = 'Float64') then Exit('Float64');
    if (LeftType = 'Float32') or (CleanTarget = 'Float32') then Exit('Float32');
    if (LeftType = 'Int64') or (CleanTarget = 'Int64') then Exit('Int64');
    if (LeftType = 'UInt64') or (CleanTarget = 'UInt64') then Exit('UInt64');
    if LeftType <> '' then Exit(LeftType);
    Exit(CleanTarget);
  end
  else if Expr is TASTTupleLiteralExpr then
    Exit(TASTTupleLiteralExpr(Expr).ResolvedType)
  else if Expr is TASTLambdaExpr then
    Exit(TASTLambdaExpr(Expr).ResolvedFnType)
  else if Expr is TASTCallExpr then
  begin
    Call := TASTCallExpr(Expr);
    if Call.IsIndirectCall and (Call.IndirectFnType <> '') then
    begin
      FnParams := TStringList.Create;
      try
        if SplitFnType(Call.IndirectFnType, FnParams, TargetType) then
          Exit(TargetType);
      finally
        FnParams.Free;
      end;
    end;
    if Call.ResolvedMonadType <> '' then Exit(Call.ResolvedMonadType);
    if Call.Callee = 'Box' then Exit('Box');
    if (Call.Callee = 'Ok') and (Call.Args.Count >= 1) then
    begin
      TargetType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
      if TargetType = '' then TargetType := 'Int32';
      Exit('Result<' + TargetType + ', Int32>');
    end;
    if Call.Callee = 'Err' then
    begin
      if Call.Args.Count >= 1 then
        TargetType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr))
      else
        TargetType := 'Int32';
      if TargetType = '' then TargetType := 'Int32';
      Exit('Result<Int32, ' + TargetType + '>');
    end;
    if Call.Callee = 'Some' then
    begin
      if Call.Args.Count >= 1 then
        TargetType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr))
      else
        TargetType := '';
      if (TargetType <> '') and (TargetType <> 'Box') and (Pos('Box<', TargetType) <> 1) and
         (Pos('^', TargetType) <> 1) and (TargetType <> 'Pointer') then
        Exit('Option<' + TargetType + '>')
      else
        Exit('Option');
    end;
    if Pos('.', Call.Callee) > 0 then
    begin
      LeftType := Copy(Call.Callee, 1, Pos('.', Call.Callee) - 1);
      if IsEnumName(LeftType) then
        Exit(LeftType);
    end;
    if SameText(Call.Callee, 'Default') and (Call.Args.Count = 1) and (TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr) then
      Exit(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name);
    if (Call.Callee = 'ReadFile') or (Call.Callee = 'CharAt') or (Call.Callee = 'Substring') or (Call.Callee = 'ToString') or
       (Call.Callee = 'IntToStr') or (Call.Callee = 'FloatToStr') or (Call.Callee = 'BoolToStr') or (Call.Callee = 'CharToStr') or
       (Call.Callee = '__InterpToStr') or (Call.Callee = '__JsonGetStr') or (Call.Callee = '__JsonGetObj') or
       (Call.Callee = 'SocketRecv') or (Call.Callee = 'ParamStr') or
       SameText(Call.Callee, 'Trim') or SameText(Call.Callee, 'UpperCase') or SameText(Call.Callee, 'LowerCase') or SameText(Call.Callee, 'Replace') or
       SameText(Call.Callee, 'Join') or SameText(Call.Callee, 'PadLeft') or SameText(Call.Callee, 'PadRight') or
       SameText(Call.Callee, 'RepeatStr') or SameText(Call.Callee, 'ReadLn') or SameText(Call.Callee, 'GetEnv') then Exit('String');
    if SameText(Call.Callee, 'Split') or SameText(Call.Callee, 'ListDir') then Exit('array of String');
    if SameText(Call.Callee, 'TryStrToInt') then Exit('Option<Int32>');
    if SameText(Call.Callee, 'TryStrToFloat') then Exit('Option<Float64>');
    if (Call.Callee = '__JsonGetInt') then Exit('Int32');
    if (Call.Callee = '__JsonGetFloat') then Exit('Float64');
    if (Call.Callee = '__JsonGetBool') or (Call.Callee = '__JsonHasValue') then Exit('Bool');
    if (Call.Callee = '__JsonGetChar') or SameText(Call.Callee, 'Chr') or SameText(Call.Callee, 'Char') then Exit('Char');
    if SameText(Call.Callee, 'Slice') and (Call.Args.Count >= 1) then
    begin
      TargetType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
      Exit(TargetType);
    end;
    if SameText(Call.Callee, 'Abs') and (Call.Args.Count = 1) then
    begin
      TargetType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
      if TargetType = '' then Exit('Int32');
      Exit(TargetType);
    end;
    if (SameText(Call.Callee, 'Min') or SameText(Call.Callee, 'Max') or SameText(Call.Callee, 'Clamp')) and (Call.Args.Count >= 2) then
    begin
      LeftType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
      CleanTarget := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[1]).Expr));
      if (LeftType = 'Float64') or (CleanTarget = 'Float64') then Exit('Float64');
      if (LeftType = 'Float32') or (CleanTarget = 'Float32') then Exit('Float32');
      if (LeftType = 'Int64') or (CleanTarget = 'Int64') then Exit('Int64');
      if (LeftType = 'UInt64') or (CleanTarget = 'UInt64') then Exit('UInt64');
      if LeftType <> '' then Exit(LeftType);
      Exit(CleanTarget);
    end;
    if SameText(Call.Callee, 'Pop') and (Call.Args.Count = 1) then
    begin
      TargetType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
      if Pos('array of ', TargetType) = 1 then
        Exit(Trim(Copy(TargetType, 10, Length(TargetType))));
      if Assigned(FModule) then
        for I := 0 to FModule.Types.Count - 1 do
          if (FModule.Types[I] is TASTArrayDecl) and SameText(TASTArrayDecl(FModule.Types[I]).Name, TargetType) then
            Exit(TASTArrayDecl(FModule.Types[I]).ElemType);
    end;
    if SameText(Call.Callee, 'Length') or SameText(Call.Callee, 'Count') or SameText(Call.Callee, 'Ord') or SameText(Call.Callee, 'SizeOf') or
       SameText(Call.Callee, 'IndexOf') or (Call.Callee = 'StrToInt') or SameText(Call.Callee, 'RandomInt') or (Call.Callee = 'SocketCreate') or
       (Call.Callee = 'SocketListen') or (Call.Callee = 'SocketAccept') or (Call.Callee = 'SocketConnect') or
       (Call.Callee = 'SocketSend') or (Call.Callee = 'ParamCount') then Exit('Int32');
    if SameText(Call.Callee, 'sin') or SameText(Call.Callee, 'cos') or SameText(Call.Callee, 'tan') or
       SameText(Call.Callee, 'sqrt') or SameText(Call.Callee, 'floor') or SameText(Call.Callee, 'ceil') or
       SameText(Call.Callee, 'round') or SameText(Call.Callee, 'pow') or SameText(Call.Callee, 'exp') or
       SameText(Call.Callee, 'log') or SameText(Call.Callee, 'atan2') or SameText(Call.Callee, 'RandomFloat') or
       SameText(Call.Callee, 'StrToFloat') or (Call.Callee = 'Now') then Exit('Float64');
    if (Call.Callee = 'GetTickCount64') or (Call.Callee = 'GetNanoseconds') then Exit('UInt64');
    if (Call.Callee = 'FileSize') then Exit('Int64');
    if SameText(Call.Callee, 'Contains') or SameText(Call.Callee, 'StartsWith') or SameText(Call.Callee, 'EndsWith') or
       (Call.Callee = 'FileExists') or (Call.Callee = 'WriteFile') or (Call.Callee = 'CreateDir') or (Call.Callee = 'RemoveDir') or
       (Call.Callee = 'DeleteFile') or (Call.Callee = 'DirExists') or
       SameText(Call.Callee, 'SetEnv') or SameText(Call.Callee, 'CopyFile') or SameText(Call.Callee, 'RenameFile') then Exit('Bool');
    if SameText(Call.Callee, 'Clear') or SameText(Call.Callee, 'Delete') or SameText(Call.Callee, 'Insert') or
       SameText(Call.Callee, 'Inc') or SameText(Call.Callee, 'Dec') or SameText(Call.Callee, 'Remove') or
       SameText(Call.Callee, 'Print') or (Call.Callee = 'SocketClose') or (Call.Callee = 'Assert') or (Call.Callee = 'SleepMs') then Exit('Void');
    if IsTypeIdentifier(Call.Callee) then Exit(Call.Callee);
    if Assigned(FModule) then
    begin
      for I := 0 to FModule.Functions.Count - 1 do
        if SameText(TASTFunction(FModule.Functions[I]).Name, Call.Callee) then
          Exit(TASTFunction(FModule.Functions[I]).ReturnType);
    end;
  end;
end;

function TAetherEmitterPascal.IsPointerTarget(Expr: TASTExpr): Boolean;
var
  T: string;
begin
  T := ResolveAliasType(GetExprTypeName(Expr));
  Result := (Pos('Box<', T) > 0) or (Pos('Pointer', T) > 0) or (T = 'Box') or (Pos('^', T) = 1);
end;

function FormatPascalArrayType(const S: string): string;
var
  P1, P2, I, DimVal: Integer;
  DimsPart, ElemPart, ResultDims: string;
  DimsList: TStringList;
begin
  P1 := Pos('[', S);
  P2 := Pos('] of ', S);
  if (P1 > 0) and (P2 > P1) then
  begin
    DimsPart := Copy(S, P1 + 1, P2 - P1 - 1);
    ElemPart := Copy(S, P2 + 5, Length(S));
    DimsList := TStringList.Create;
    try
      DimsList.CommaText := DimsPart;
      ResultDims := '';
      for I := 0 to DimsList.Count - 1 do
      begin
        DimVal := StrToIntDef(Trim(DimsList[I]), 1);
        if I > 0 then ResultDims := ResultDims + ', ';
        ResultDims := ResultDims + Format('0..%d', [DimVal - 1]);
      end;
      Result := Format('array[%s] of %s', [ResultDims, Trim(ElemPart)]);
    finally
      DimsList.Free;
    end;
  end
  else
    Result := S;
end;

function TAetherEmitterPascal.EmitTypeRef(const AType: string): string;
var
  Inner, Inner2, ValT, ErrT: string;
begin
  if AType = 'Bool' then Result := 'Boolean'
  else if AType = 'Float32' then Result := 'Single'
  else if AType = 'Float64' then Result := 'Double'
  else if AType = 'Void' then Result := ''
  else if (AType = 'Int8') or (AType = 'Int16') or (AType = 'Int32') or (AType = 'Int64') or
          (AType = 'UInt8') or (AType = 'UInt16') or (AType = 'UInt32') or (AType = 'UInt64') or
          (AType = 'Char') or (AType = 'String') or (AType = 'Pointer') then
    Result := AType
  else if Pos('^', AType) = 1 then
  begin
    Inner := Trim(Copy(AType, 2, Length(AType)));
    if (Inner = 'Int8') or (Inner = 'Int16') or (Inner = 'Int32') or (Inner = 'Int64') or
       (Inner = 'UInt8') or (Inner = 'UInt16') or (Inner = 'UInt32') or (Inner = 'UInt64') or
       (Inner = 'Float32') or (Inner = 'Float64') or (Inner = 'Bool') or (Inner = 'Char') or
       (Inner = 'String') then
      Result := 'PAetherPtr_' + Inner
    else if IsRecordName(Inner) or (Assigned(FindEnumDecl(Inner)) and FindEnumDecl(Inner).HasPayload) then
      Result := 'PT' + Inner
    else
      Result := '^' + EmitTypeRef(Inner);
  end
  else if Pos('array of ', AType) = 1 then
  begin
    Inner := Trim(Copy(AType, 10, Length(AType)));
    if (Inner = 'Int8') or (Inner = 'Int16') or (Inner = 'Int32') or (Inner = 'Int64') or
       (Inner = 'UInt8') or (Inner = 'UInt16') or (Inner = 'UInt32') or (Inner = 'UInt64') or
       (Inner = 'Float32') or (Inner = 'Float64') or (Inner = 'Bool') or (Inner = 'Char') or
       (Inner = 'String') or (Inner = 'Pointer') then
      Result := 'TAetherDyn_' + Inner
    else
      Result := 'TAetherDyn_' + MangleTypeTag(Inner);
  end
  else if IsTypedResult(AType, ValT, ErrT) then
    Result := 'TAetherRes_' + MangleTypeTag(ValT) + '__' + MangleTypeTag(ErrT)
  else if Pos('Result', AType) = 1 then
    Result := 'TResultDoubleError'
  else if Pos('array[', AType) = 1 then
    Result := FormatPascalArrayType(AType)
  else if Pos('set of ', AType) = 1 then
    Result := 'set of ' + EmitTypeRef(Trim(Copy(AType, 8, Length(AType))))
  else if Pos('Box<', AType) > 0 then
  begin
    Inner := AType;
    if Pos('Option<', Inner) = 1 then
      Inner := SafeUnwrapGeneric(Inner, 'Option');
    if Pos('Box<', Inner) = 1 then
      Inner := SafeUnwrapGeneric(Inner, 'Box');
    Result := 'P' + EmitTypeRef(Inner);
  end
  else if (Copy(AType, 1, 5) = 'Task<') and (AType[Length(AType)] = '>') then
  begin
    Inner := Copy(AType, 6, Length(AType) - 6);
    Result := 'specialize TAetherTask<' + EmitTypeRef(Inner) + '>';
  end
  else if IsTypedValueOption(AType, Inner) then
    Result := 'TAetherOpt_' + MangleTypeTag(Inner)
  else if Pos('Option<', AType) = 1 then
  begin
    if IsValueOptionType(AType) then
      Result := 'TAetherOption'
    else
    begin
      Inner := SafeUnwrapGeneric(AType, 'Option');
      Result := EmitTypeRef(Inner);
    end;
  end
  else if IsMapType(AType, Inner, Inner2) then
    Result := 'TAetherMap_' + MapTag(Inner, Inner2)
  else if Pos('fn(', AType) = 1 then
    Result := 'TAetherFn_' + FnTypeTag(AType)
  else
    Result := 'T' + AType;
end;

function TAetherEmitterPascal.EmitExpr(Expr: TASTExpr): string;
var
  Lit: TASTLiteralExpr;
  Id: TASTIdentifierExpr;
  Acc: TASTMemberAccessExpr;
  Bin: TASTBinaryExpr;
  Un: TASTUnaryExpr;
  Call: TASTCallExpr;
  Idx: TASTIndexExpr;
  SetLit: TASTSetLiteralExpr;
  ArgsStr, KeyT, ValT, TargetT, ValF, ErrF, RetT, RetValF, RetErrF, MTag, RetMTag, ErrValExpr: string;
  I, BindCount, BIdx: Integer;
  TargetStr, ScruVar, BName, TVar, BType: string;
  IsWild, OpTyped, RetTyped: Boolean;
  BindVarT: string;
  Enm: TASTEnumDecl;
  VarN: TASTEnumVariant;
  MC: TASTMatchCase;
begin
  if not Assigned(Expr) then Exit('');

  if Expr is TASTLiteralExpr then
  begin
    Lit := TASTLiteralExpr(Expr);
    case Lit.Kind of
      lkInt:    Result := NormalizeIntLit(Lit.Value);
      lkString: Result := EscapePascalString(Lit.Value);
      lkChar:   Result := EscapePascalChar(Lit.Value);
      lkBool:   Result := LowerCase(Lit.Value);
      lkNil:    Result := 'nil';
    else
      Result := Lit.Value;
    end;
    Exit;
  end;

  if Expr is TASTIdentifierExpr then
  begin
    Id := TASTIdentifierExpr(Expr);
    for I := FGuardBindNames.Count - 1 downto 0 do
      if SameText(FGuardBindNames[I], Id.Name) then
        Exit('(' + FGuardBindExprs[I] + ')');
    for I := FMatchBindNames.Count - 1 downto 0 do
      if SameText(FMatchBindNames[I], Id.Name) then
        Exit(FMatchBindTargets[I]);
    if Id.Name = '__ValueNone' then
    begin
      if (Id.ResolvedMonadType <> '') and IsTypedValueOption(Id.ResolvedMonadType, ValF) then
        Result := 'AetherNone_' + MangleTypeTag(ValF) + '()'
      else
        Result := 'AetherNone()';
    end
    else if Id.Name = 'None' then
      Result := 'nil'
    else if FindEnumVariantUnqualified(Id.Name, Enm, VarN) then
    begin
      if Enm.HasPayload then
        Result := Enm.Name + '_' + VarN.Name + '()'
      else
        Result := Enm.Name + '_' + VarN.Name;
    end
    else if Id.IsFnValueRef and (Id.ResolvedFnType <> '') then
      Result := Format('AetherMakeFn_%s(@__aether_thunk_%s, nil)', [FnTypeTag(Id.ResolvedFnType), Id.Name])
    else
      Result := Id.Name;
    Exit;
  end;

  if Expr is TASTMemberAccessExpr then
  begin
    Acc := TASTMemberAccessExpr(Expr);
    if (Acc.Target is TASTIdentifierExpr) and IsModulePrefixName(TASTIdentifierExpr(Acc.Target).Name) then
      Exit(Acc.Member);
    TargetStr := EmitExpr(Acc.Target);
    TargetT := ResolveAliasType(GetExprTypeName(Acc.Target));
    // Case Enum.Variant or Alias.Enum.Variant
    if ((Acc.Target is TASTIdentifierExpr) and IsEnumName(TASTIdentifierExpr(Acc.Target).Name)) or
       ((Acc.Target is TASTMemberAccessExpr) and IsEnumName(TargetStr)) then
    begin
      if Acc.Target is TASTIdentifierExpr then
        Enm := FindEnumDecl(TASTIdentifierExpr(Acc.Target).Name)
      else
        Enm := FindEnumDecl(TargetStr);
      if Assigned(Enm) and Enm.HasPayload then
        Result := TargetStr + '_' + Acc.Member + '()'
      else
        Result := TargetStr + '_' + Acc.Member;
    end
    else if IsTypedResult(TargetT, ValF, ErrF) then
      Result := TargetStr + '.' + Acc.Member
    else if Pos('Result', TargetT) = 1 then
    begin
      if Acc.Member = 'value' then
      begin
        SplitResultTypes(TargetT, ValF, ErrF);
        Result := EmitMonadFieldExtract(TargetStr, ValF, 'value', 'str_val');
      end
      else if Acc.Member = 'error' then
      begin
        SplitResultTypes(TargetT, ValF, ErrF);
        if ResolveAliasType(ErrF) = 'String' then
          Result := TargetStr + '.err_str'
        else
          Result := Format('%s(%s.error)', [EmitTypeRef(ErrF), TargetStr]);
      end
      else
        Result := TargetStr + '.' + Acc.Member;
    end
    else if IsTypedValueOption(TargetT, ValF) then
      Result := TargetStr + '.' + Acc.Member
    else if IsValueOptionType(TargetT) then
    begin
      if Acc.Member = 'is_some' then
        Result := TargetStr + '.is_some'
      else if Acc.Member = 'is_none' then
        Result := TargetStr + '.is_none'
      else if Acc.Member = 'value' then
      begin
        ValF := SafeUnwrapGeneric(TargetT, 'Option');
        Result := EmitMonadFieldExtract(TargetStr, ValF, 'num_val', 'str_val');
      end
      else
        Result := TargetStr + '.' + Acc.Member;
    end
    else if Acc.Member = 'is_some' then
      Result := '(' + TargetStr + ' <> nil)'
    else if Acc.Member = 'is_none' then
      Result := '(' + TargetStr + ' = nil)'
    else if IsPointerTarget(Acc.Target) then
    begin
      if Acc.Member = 'value' then
        Result := TargetStr + '^'
      else
        Result := TargetStr + '^.' + Acc.Member;
    end
    else
    begin
      if Acc.Member = 'value' then
        Result := TargetStr
      else
        Result := TargetStr + '.' + Acc.Member;
    end;
    Exit;
  end;

  if Expr is TASTBinaryExpr then
  begin
    Bin := TASTBinaryExpr(Expr);
    if Bin.Op = 'implies' then
      Result := Format('((not (%s)) or (%s))', [EmitExpr(Bin.Left), EmitExpr(Bin.Right)])
    else if Bin.Op = '/' then
    begin
      if (Bin.Right is TASTLiteralExpr) and (Pos('.', TASTLiteralExpr(Bin.Right).Value) > 0) then
        Result := Format('(%s / %s)', [EmitExpr(Bin.Left), EmitExpr(Bin.Right)])
      else if (Bin.Left is TASTLiteralExpr) and (Pos('.', TASTLiteralExpr(Bin.Left).Value) > 0) then
        Result := Format('(%s / %s)', [EmitExpr(Bin.Left), EmitExpr(Bin.Right)])
      else if IsIntegerType(GetExprTypeName(Bin.Left)) and IsIntegerType(GetExprTypeName(Bin.Right)) then
        Result := Format('(%s div %s)', [EmitExpr(Bin.Left), EmitExpr(Bin.Right)])
      else
        Result := Format('(%s / %s)', [EmitExpr(Bin.Left), EmitExpr(Bin.Right)]);
    end
    else
      Result := Format('(%s %s %s)', [EmitExpr(Bin.Left), Bin.Op, EmitExpr(Bin.Right)]);
    Exit;
  end;

  if Expr is TASTUnaryExpr then
  begin
    Un := TASTUnaryExpr(Expr);
    if Un.Op = '?' then
    begin
      TargetT := ResolveAliasType(GetExprTypeName(Un.Expr));
      TargetStr := Format('_aether_try_%d_%d', [Un.Line, Un.Col]);
      Emit(Format('%s := %s;', [TargetStr, EmitExpr(Un.Expr)]));
      RetT := '';
      if Assigned(FCurrentFunc) then RetT := ResolveAliasType(FCurrentFunc.ReturnType);

      if Pos('Result', TargetT) = 1 then
      begin
        SplitResultTypes(TargetT, ValF, ErrF);
        OpTyped := IsTypedResult(TargetT, ValF, ErrF);
        RetTyped := (RetT <> '') and IsTypedResult(RetT, RetValF, RetErrF);
        Emit(Format('if %s.is_err then', [TargetStr]));
        Emit('begin');
        IncIndent;
        if FActiveDefers.Count > 0 then EmitActiveDefers(0);
        if not OpTyped and not RetTyped then
          Emit(Format('Exit(%s);', [TargetStr]))
        else if OpTyped and RetTyped then
        begin
          MTag := MangleTypeTag(ValF) + '__' + MangleTypeTag(ErrF);
          RetMTag := MangleTypeTag(RetValF) + '__' + MangleTypeTag(RetErrF);
          if MTag = RetMTag then
            Emit(Format('Exit(%s);', [TargetStr]))
          else
            Emit(Format('Exit(AetherErr_%s(%s.error));', [RetMTag, TargetStr]));
        end
        else if (not OpTyped) and RetTyped then
        begin
          RetMTag := MangleTypeTag(RetValF) + '__' + MangleTypeTag(RetErrF);
          if ResolveAliasType(ErrF) = 'String' then
            ErrValExpr := TargetStr + '.err_str'
          else
            ErrValExpr := Format('%s(%s.error)', [EmitTypeRef(ErrF), TargetStr]);
          Emit(Format('Exit(AetherErr_%s(%s));', [RetMTag, ErrValExpr]));
        end
        else
        begin
          if ResolveAliasType(ErrF) = 'String' then
            Emit(Format('Exit(AetherErr(%s.error));', [TargetStr]))
          else
            Emit(Format('Exit(AetherErr(Integer(%s.error)));', [TargetStr]));
        end;
        DecIndent;
        Emit('end;');
        if OpTyped then
          Result := TargetStr + '.value'
        else
          Result := EmitMonadFieldExtract(TargetStr, ValF, 'value', 'str_val');
      end
      else if IsValueOptionType(TargetT) then
      begin
        OpTyped := IsTypedValueOption(TargetT, ValF);
        if not OpTyped then ValF := SafeUnwrapGeneric(TargetT, 'Option');
        RetTyped := (RetT <> '') and IsTypedValueOption(RetT, RetValF);
        Emit(Format('if %s.is_none then', [TargetStr]));
        Emit('begin');
        IncIndent;
        if FActiveDefers.Count > 0 then EmitActiveDefers(0);
        if RetTyped then
          Emit(Format('Exit(AetherNone_%s());', [MangleTypeTag(RetValF)]))
        else if (RetT = '') or IsValueOptionType(RetT) then
          Emit('Exit(AetherNone());')
        else
          Emit('Exit(nil);');
        DecIndent;
        Emit('end;');
        if OpTyped then
          Result := TargetStr + '.value'
        else
          Result := EmitMonadFieldExtract(TargetStr, ValF, 'num_val', 'str_val');
      end
      else
      begin
        RetTyped := (RetT <> '') and IsTypedValueOption(RetT, RetValF);
        Emit(Format('if %s = nil then', [TargetStr]));
        Emit('begin');
        IncIndent;
        if FActiveDefers.Count > 0 then EmitActiveDefers(0);
        if RetTyped then
          Emit(Format('Exit(AetherNone_%s());', [MangleTypeTag(RetValF)]))
        else
          Emit('Exit(nil);');
        DecIndent;
        Emit('end;');
        Result := TargetStr;
      end;
      Exit;
    end;
    if Un.Op = '@' then
      Result := '(@' + EmitExpr(Un.Expr) + ')'
    else if Un.Op = '^' then
      Result := EmitExpr(Un.Expr) + '^'
    else
      Result := Format('(%s %s)', [Un.Op, EmitExpr(Un.Expr)]);
    Exit;
  end;

  if Expr is TASTAwaitExpr then
  begin
    Result := Format('(%s).value', [EmitExpr(TASTAwaitExpr(Expr).Expr)]);
    Exit;
  end;

  if Expr is TASTSpawnExpr then
  begin
    Result := EmitExpr(TASTSpawnExpr(Expr).CallExpr);
    Exit;
  end;

  if Expr is TASTIndexExpr then
  begin
    Idx := TASTIndexExpr(Expr);
    if Idx.Target is TASTSetLiteralExpr then
    begin
      ValF := ResolveAliasType(GetExprTypeName(Idx));
      if ValF = '' then ValF := 'Int32';
      ArgsStr := '';
      for I := 0 to TASTSetLiteralExpr(Idx.Target).Elements.Count - 1 do
      begin
        if I > 0 then ArgsStr := ArgsStr + ', ';
        ArgsStr := ArgsStr + EmitExpr(TASTExpr(TASTSetLiteralExpr(Idx.Target).Elements[I]));
      end;
      TargetStr := EmitTypeRef('array of ' + ValF);
      Result := Format('%s.Create(%s)[%s]', [TargetStr, ArgsStr, EmitExpr(TASTExpr(Idx.Indices[0]))]);
      Exit;
    end;
    TargetT := ResolveAliasType(GetExprTypeName(Idx.Target));
    if TargetT = 'String' then
    begin
      Result := Format('%s[(%s) + 1]', [EmitExpr(Idx.Target), EmitExpr(TASTExpr(Idx.Indices[0]))]);
      Exit;
    end;
    if IsMapType(TargetT, KeyT, ValT) then
    begin
      Result := Format('AetherMapGet_%s(%s, %s)', [MapTag(KeyT, ValT), EmitExpr(Idx.Target), EmitExpr(TASTExpr(Idx.Indices[0]))]);
      Exit;
    end;
    TargetStr := EmitExpr(Idx.Target);
    ArgsStr := '';
    for I := 0 to Idx.Indices.Count - 1 do
    begin
      if I > 0 then ArgsStr := ArgsStr + ', ';
      ArgsStr := ArgsStr + EmitExpr(TASTExpr(Idx.Indices[I]));
    end;
    Result := Format('%s[%s]', [TargetStr, ArgsStr]);
    Exit;
  end;

  if Expr is TASTSetLiteralExpr then
  begin
    SetLit := TASTSetLiteralExpr(Expr);
    ArgsStr := '';
    for I := 0 to SetLit.Elements.Count - 1 do
    begin
      if I > 0 then ArgsStr := ArgsStr + ', ';
      ArgsStr := ArgsStr + EmitExpr(TASTExpr(SetLit.Elements[I]));
    end;
    Result := Format('[%s]', [ArgsStr]);
    Exit;
  end;

  if Expr is TASTMapLiteralExpr then
  begin
    TargetStr := Format('_aether_mlit_%d_%d', [Expr.Line, Expr.Col]);
    EmitMapLiteralAssign(TargetStr, GetExprTypeName(Expr), TASTMapLiteralExpr(Expr));
    Result := TargetStr;
    Exit;
  end;

  if Expr is TASTCallExpr then
  begin
    Call := TASTCallExpr(Expr);
    if Call.IsIndirectCall then
    begin
      if Assigned(Call.CalleeExpr) then
        TargetStr := EmitExpr(Call.CalleeExpr)
      else
        TargetStr := Call.Callee;
      ArgsStr := '';
      for I := 0 to Call.Args.Count - 1 do
      begin
        if I > 0 then ArgsStr := ArgsStr + ', ';
        ArgsStr := ArgsStr + EmitExpr(TASTCallArg(Call.Args[I]).Expr);
      end;
      if ArgsStr <> '' then
        Result := Format('AetherCallFn_%s(%s, %s)', [FnTypeTag(Call.IndirectFnType), TargetStr, ArgsStr])
      else
        Result := Format('AetherCallFn_%s(%s)', [FnTypeTag(Call.IndirectFnType), TargetStr]);
      Exit;
    end;

    // PrintLn / Print translates to WriteLn / Write or Format(...)
    if (Call.Callee = 'PrintLn') or (Call.Callee = 'Print') then
    begin
      if Call.Args.Count = 1 then
      begin
        if Call.Callee = 'PrintLn' then
          Result := 'WriteLn(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')'
        else
          Result := 'Write(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      end
      else
      begin
        ArgsStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ', [';
        for I := 1 to Call.Args.Count - 1 do
        begin
          ArgsStr := ArgsStr + EmitExpr(TASTCallArg(Call.Args[I]).Expr);
          if I < Call.Args.Count - 1 then
            ArgsStr := ArgsStr + ', ';
        end;
        ArgsStr := ArgsStr + ']';
        if Call.Callee = 'PrintLn' then
          Result := 'WriteLn(Format(' + ArgsStr + '))'
        else
          Result := 'Write(Format(' + ArgsStr + '))';
      end;
      Exit;
    end;

    if (Call.Callee = 'Float64') and (Call.Args.Count = 1) then
    begin
      Result := 'Double(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if (Call.Callee = 'Float32') and (Call.Args.Count = 1) then
    begin
      Result := 'Single(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    // Ok, Err, and Some constructors
    if Call.Callee = 'Ok' then
    begin
      if (Call.ResolvedMonadType <> '') and IsTypedResult(Call.ResolvedMonadType, ValF, ErrF) then
      begin
        MTag := MangleTypeTag(ValF) + '__' + MangleTypeTag(ErrF);
        Result := Format('AetherOk_%s(%s)', [MTag, EmitExpr(TASTCallArg(Call.Args[0]).Expr)]);
      end
      else
      begin
        TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
        if TargetT = 'Char' then
          Result := 'AetherOk(Ord(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))'
        else
          Result := 'AetherOk(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      end;
      Exit;
    end;

    if Call.Callee = 'Err' then
    begin
      if (Call.ResolvedMonadType <> '') and IsTypedResult(Call.ResolvedMonadType, ValF, ErrF) then
      begin
        MTag := MangleTypeTag(ValF) + '__' + MangleTypeTag(ErrF);
        Result := Format('AetherErr_%s(%s)', [MTag, EmitExpr(TASTCallArg(Call.Args[0]).Expr)]);
      end
      else
      begin
        TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
        if TargetT = 'String' then
          Result := 'AetherErr(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')'
        else
          Result := 'AetherErr(Integer(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      end;
      Exit;
    end;

    if Call.Callee = 'Some' then
    begin
      if IsPointerTarget(TASTCallArg(Call.Args[0]).Expr) then
        Result := EmitExpr(TASTCallArg(Call.Args[0]).Expr)
      else
      begin
        MTag := Call.ResolvedMonadType;
        if MTag = '' then
          MTag := 'Option<' + ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr)) + '>';
        if IsTypedValueOption(MTag, ValF) then
          Result := Format('AetherSome_%s(%s)', [MangleTypeTag(ValF), EmitExpr(TASTCallArg(Call.Args[0]).Expr)])
        else
        begin
          TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
          if TargetT = 'Char' then
            Result := 'AetherSome(Ord(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))'
          else
            Result := 'AetherSome(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
        end;
      end;
      Exit;
    end;

    if Call.Callee = 'Box' then
    begin
      Result := 'AetherBox(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = '__InterpToStr' then
    begin
      Result := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
      Exit;
    end;

    if Call.Callee = 'CharToStr' then
    begin
      Result := 'String(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if SameText(Call.Callee, 'Length') or SameText(Call.Callee, 'Count') then
    begin
      if IsMapType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr), KeyT, ValT) then
        Result := EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '.count'
      else
      begin
        TargetStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
        Result := 'Int32(Length(' + TargetStr + '))';
      end;
      Exit;
    end;

    if SameText(Call.Callee, 'Default') then
    begin
      TargetT := TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name;
      Result := 'Default(' + EmitTypeRef(TargetT) + ')';
      Exit;
    end;

    if SameText(Call.Callee, 'Contains') then
    begin
      TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
      if TargetT = 'String' then
        Result := Format('AetherStrContains(%s, %s)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)])
      else
      begin
        IsMapType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr), KeyT, ValT);
        Result := Format('AetherMapContains_%s(%s, %s)', [MapTag(KeyT, ValT), EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      end;
      Exit;
    end;

    if SameText(Call.Callee, 'Trim') then
    begin
      Result := Format('AetherStrTrim(%s)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'UpperCase') then
    begin
      Result := Format('AetherUpperCase(%s)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'LowerCase') then
    begin
      Result := Format('AetherLowerCase(%s)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'StartsWith') then
    begin
      Result := Format('AetherStartsWith(%s, %s)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'EndsWith') then
    begin
      Result := Format('AetherEndsWith(%s, %s)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'IndexOf') then
    begin
      Result := Format('AetherIndexOf(%s, %s)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Replace') then
    begin
      Result := Format('AetherStrReplace(%s, %s, %s)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr), EmitExpr(TASTCallArg(Call.Args[2]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Split') then
    begin
      Result := Format('AetherStrSplit(%s, %s)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Join') then
    begin
      Result := Format('AetherStrJoin(%s, %s)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'PadLeft') or SameText(Call.Callee, 'PadRight') then
    begin
      if Call.Args.Count = 2 then
        TargetStr := ''' '''
      else
      begin
        TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[2]).Expr));
        if TargetT = 'Char' then
          TargetStr := 'String(' + EmitExpr(TASTCallArg(Call.Args[2]).Expr) + ')'
        else
          TargetStr := EmitExpr(TASTCallArg(Call.Args[2]).Expr);
      end;
      if SameText(Call.Callee, 'PadLeft') then
        Result := Format('AetherPadLeft(%s, %s, %s)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr), TargetStr])
      else
        Result := Format('AetherPadRight(%s, %s, %s)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr), TargetStr]);
      Exit;
    end;

    if SameText(Call.Callee, 'RepeatStr') then
    begin
      Result := Format('AetherRepeatStr(%s, %s)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Sqrt') then
    begin
      Result := 'System.Sqrt(Double(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if SameText(Call.Callee, 'Floor') then
    begin
      Result := 'Double(Math.Floor(Double(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')))';
      Exit;
    end;

    if SameText(Call.Callee, 'Ceil') then
    begin
      Result := 'Double(Math.Ceil(Double(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')))';
      Exit;
    end;

    if SameText(Call.Callee, 'Round') then
    begin
      Result := 'AetherRound(Double(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if SameText(Call.Callee, 'Pow') then
    begin
      Result := Format('Math.Power(Double(%s), Double(%s))', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Exp') then
    begin
      Result := 'System.Exp(Double(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if SameText(Call.Callee, 'Log') then
    begin
      Result := 'System.Ln(Double(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if SameText(Call.Callee, 'Sin') then
    begin
      Result := 'System.Sin(Double(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if SameText(Call.Callee, 'Cos') then
    begin
      Result := 'System.Cos(Double(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if SameText(Call.Callee, 'Tan') then
    begin
      Result := 'Math.Tan(Double(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if SameText(Call.Callee, 'Atan2') then
    begin
      Result := Format('Math.ArcTan2(Double(%s), Double(%s))', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'RandomInt') then
    begin
      Result := Format('AetherRandomInt(%s, %s)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'RandomFloat') then
    begin
      Result := 'AetherRandomFloat()';
      Exit;
    end;

    if SameText(Call.Callee, 'Abs') then
    begin
      Result := 'System.Abs(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if SameText(Call.Callee, 'Min') then
    begin
      TargetT := ResolveAliasType(GetExprTypeName(Call));
      if TargetT = '' then TargetT := 'Int32';
      Result := Format('specialize AetherMin<%s>(%s, %s)', [EmitTypeRef(TargetT), EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Max') then
    begin
      TargetT := ResolveAliasType(GetExprTypeName(Call));
      if TargetT = '' then TargetT := 'Int32';
      Result := Format('specialize AetherMax<%s>(%s, %s)', [EmitTypeRef(TargetT), EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Clamp') then
    begin
      TargetT := ResolveAliasType(GetExprTypeName(Call));
      if TargetT = '' then TargetT := 'Int32';
      Result := Format('specialize AetherClamp<%s>(%s, %s, %s)', [EmitTypeRef(TargetT), EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr), EmitExpr(TASTCallArg(Call.Args[2]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Remove') then
    begin
      IsMapType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr), KeyT, ValT);
      Result := Format('AetherMapRemove_%s(%s, %s)', [MapTag(KeyT, ValT), EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'SetLength') then
    begin
      Result := Format('SetLength(%s, %s)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Push') then
    begin
      TargetStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
      Result := Format('begin SetLength(%s, Length(%s) + 1); %s[High(%s)] := %s; end',
        [TargetStr, TargetStr, TargetStr, TargetStr, EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Pop') then
    begin
      TargetStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
      TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
      ValF := 'Int32';
      if Pos('array of ', TargetT) = 1 then
        ValF := ResolveAliasType(Trim(Copy(TargetT, 10, Length(TargetT))))
      else if Assigned(FModule) then
        for I := 0 to FModule.Types.Count - 1 do
          if (FModule.Types[I] is TASTArrayDecl) and SameText(TASTArrayDecl(FModule.Types[I]).Name, TargetT) then
            ValF := ResolveAliasType(TASTArrayDecl(FModule.Types[I]).ElemType);
      Result := Format('AetherDynPop_%s(%s)', [ValF, TargetStr]);
      Exit;
    end;

    if SameText(Call.Callee, 'Delete') then
    begin
      Result := Format('System.Delete(%s, %s, 1)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Insert') then
    begin
      Result := Format('System.Insert(%s, %s, %s)', [EmitExpr(TASTCallArg(Call.Args[2]).Expr), EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Slice') then
    begin
      Result := Format('System.Copy(%s, %s, %s)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr), EmitExpr(TASTCallArg(Call.Args[2]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Clear') then
    begin
      TargetStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
      if IsMapType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr), KeyT, ValT) then
        Result := Format('%s.count := 0', [TargetStr])
      else
        Result := Format('SetLength(%s, 0)', [TargetStr]);
      Exit;
    end;

    if SameText(Call.Callee, 'Free') or SameText(Call.Callee, 'Dispose') then
    begin
      TargetStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
      TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
      IsWild := (TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr) or
                (TASTCallArg(Call.Args[0]).Expr is TASTMemberAccessExpr);
      if IsDynamicArrayType(TargetT) then
        Result := Format('SetLength(%s, 0)', [TargetStr])
      else if IsMapType(TargetT, KeyT, ValT) then
        Result := Format('begin SetLength(%s.entries, 0); %s.count := 0; end', [TargetStr, TargetStr])
      else if SameText(TargetT, 'Pointer') then
      begin
        if IsWild then
          Result := Format('begin if %s <> nil then begin FreeMem(%s); %s := nil; end; end', [TargetStr, TargetStr, TargetStr])
        else
          Result := Format('FreeMem(%s)', [TargetStr]);
      end
      else
      begin
        ArgsStr := '';
        if Pos('Box<', TargetT) = 1 then
        begin
          ValF := Trim(Copy(TargetT, 5, Length(TargetT) - 5));
          if FindDropFunc(ValF) <> nil then
            ArgsStr := Format('%s(%s^); ', [FindDropFunc(ValF).Name, TargetStr]);
        end;
        if IsWild then
          Result := Format('begin if %s <> nil then begin %sDispose(%s); %s := nil; end; end', [TargetStr, ArgsStr, TargetStr, TargetStr])
        else
          Result := Format('Dispose(%s)', [TargetStr]);
      end;
      Exit;
    end;

    if SameText(Call.Callee, 'Inc') or SameText(Call.Callee, 'Dec') then
    begin
      if Call.Args.Count = 2 then
        Result := Format('%s(%s, %s)', [Call.Callee, EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)])
      else
        Result := Format('%s(%s)', [Call.Callee, EmitExpr(TASTCallArg(Call.Args[0]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Ord') then
    begin
      Result := 'Int32(Ord(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if SameText(Call.Callee, 'Chr') then
    begin
      Result := 'Chr(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if SameText(Call.Callee, 'SizeOf') then
    begin
      if (TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr) and IsTypeIdentifier(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name) then
        Result := 'Int32(SizeOf(' + EmitTypeRef(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name) + '))'
      else
        Result := 'Int32(SizeOf(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if (Call.Args.Count = 1) and IsTypeIdentifier(Call.Callee) and not IsEnumName(Call.Callee) and not IsRecordName(Call.Callee) then
    begin
      ValF := ResolveAliasType(Call.Callee);
      TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
      if IsIntegerType(ValF) and ((TargetT = 'Float32') or (TargetT = 'Float64') or (TargetT = 'FloatLiteral')) then
        Result := EmitTypeRef(Call.Callee) + '(Trunc(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))'
      else
        Result := EmitTypeRef(Call.Callee) + '(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = '__JsonGetStr' then
    begin
      Result := 'AetherJsonGetStr(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = '__JsonGetInt' then
    begin
      Result := 'AetherJsonGetInt(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = '__JsonGetFloat' then
    begin
      Result := 'AetherJsonGetFloat(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = '__JsonGetBool' then
    begin
      Result := 'AetherJsonGetBool(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = '__JsonGetChar' then
    begin
      Result := 'AetherJsonGetChar(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = '__JsonHasValue' then
    begin
      Result := 'AetherJsonHasValue(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = '__JsonGetObj' then
    begin
      Result := 'AetherJsonGetObj(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'CharAt' then
    begin
      Result := 'AetherCharAt(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'Substring' then
    begin
      Result := 'AetherSubstring(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[2]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'FileExists' then
    begin
      Result := 'AetherFileExists(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'ReadFile' then
    begin
      Result := 'AetherReadFile(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'WriteFile' then
    begin
      Result := 'AetherWriteFile(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'CreateDir' then
    begin
      Result := 'AetherCreateDir(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'RemoveDir' then
    begin
      Result := 'AetherRemoveDir(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'DeleteFile' then
    begin
      Result := 'AetherDeleteFile(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'DirExists' then
    begin
      Result := 'AetherDirExists(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'FileSize' then
    begin
      Result := 'AetherFileSize(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if SameText(Call.Callee, 'ListDir') then
    begin
      Result := 'AetherListDir(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if SameText(Call.Callee, 'CopyFile') then
    begin
      Result := Format('AetherCopyFile(%s, %s)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'RenameFile') then
    begin
      Result := Format('AetherRenameFile(%s, %s)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'ReadLn') then
    begin
      Result := 'AetherReadLn()';
      Exit;
    end;

    if SameText(Call.Callee, 'GetEnv') then
    begin
      Result := 'AetherGetEnv(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if SameText(Call.Callee, 'SetEnv') then
    begin
      Result := Format('AetherSetEnv(%s, %s)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if Call.Callee = 'GetNanoseconds' then
    begin
      Result := 'AetherGetNanoseconds()';
      Exit;
    end;

    if Call.Callee = 'SleepMs' then
    begin
      Result := 'AetherSleepMs(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'IntToStr' then
    begin
      Result := 'IntToStr(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'FloatToStr' then
    begin
      Result := 'AetherFloatToStr(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'BoolToStr' then
    begin
      Result := 'AetherBoolToStr(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'StrToInt' then
    begin
      Result := 'StrToIntDef(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ', 0)';
      Exit;
    end;

    if SameText(Call.Callee, 'StrToFloat') then
    begin
      Result := 'AetherStrToFloat(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if SameText(Call.Callee, 'TryStrToInt') then
    begin
      Result := 'AetherTryStrToInt(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if SameText(Call.Callee, 'TryStrToFloat') then
    begin
      Result := 'AetherTryStrToFloat(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'ParamCount' then
    begin
      Result := 'ParamCount';
      Exit;
    end;

    if Call.Callee = 'ParamStr' then
    begin
      Result := 'ParamStr(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'Assert' then
    begin
      if Call.Args.Count = 1 then
        Result := 'Assert(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')'
      else
        Result := 'Assert(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'SocketCreate' then
    begin
      Result := 'AetherSocketCreate()';
      Exit;
    end;

    if Call.Callee = 'SocketListen' then
    begin
      Result := 'AetherSocketListen(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'SocketAccept' then
    begin
      Result := 'AetherSocketAccept(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'SocketConnect' then
    begin
      Result := 'AetherSocketConnect(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'SocketSend' then
    begin
      Result := 'AetherSocketSend(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'SocketRecv' then
    begin
      Result := 'AetherSocketRecv(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'SocketClose' then
    begin
      Result := 'AetherSocketClose(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    // Normal call, enum variant constructor, or record constructor
    ArgsStr := '';
    for I := 0 to Call.Args.Count - 1 do
    begin
      ArgsStr := ArgsStr + EmitExpr(TASTCallArg(Call.Args[I]).Expr);
      if I < Call.Args.Count - 1 then
        ArgsStr := ArgsStr + ', ';
    end;
    if Pos('.', Call.Callee) > 0 then
    begin
      ValF := Copy(Call.Callee, 1, Pos('.', Call.Callee) - 1);
      if IsEnumName(ValF) then
        Exit(StringReplace(Call.Callee, '.', '_', [rfReplaceAll]) + '(' + ArgsStr + ')');
    end;
    Result := Call.Callee + '(' + ArgsStr + ')';
    Exit;
  end
  else if Expr is TASTIfExpr then
  begin
    TargetT := ResolveAliasType(GetExprTypeName(Expr));
    if TargetT = '' then TargetT := 'Int32';
    Result := Format('specialize AetherIfThen<%s>(%s, %s, %s)',
      [EmitTypeRef(TargetT), EmitExpr(TASTIfExpr(Expr).Condition), EmitExpr(TASTIfExpr(Expr).ThenExpr), EmitExpr(TASTIfExpr(Expr).ElseExpr)]);
    Exit;
  end
  else if Expr is TASTMatchExpr then
  begin
    TargetStr := Format('_aether_mexpr_%d_%d', [Expr.Line, Expr.Col]);
    ScruVar := Format('_aether_mval_%d_%d', [Expr.Line, Expr.Col]);
    Emit(Format('%s := %s;', [ScruVar, EmitExpr(TASTMatchExpr(Expr).Expr)]));
    ErrF := ResolveAliasType(GetExprTypeName(TASTMatchExpr(Expr).Expr));
    for I := 0 to TASTMatchExpr(Expr).Cases.Count - 1 do
    begin
      MC := TASTMatchCase(TASTMatchExpr(Expr).Cases[I]);
      BuildMatchCaseCond(MC, ScruVar, ErrF, KeyT, ValT, BindVarT, IsWild);
      if IsWild then
      begin
        if I > 0 then Emit('else');
      end
      else
      begin
        if KeyT = '' then KeyT := 'True';
        if I = 0 then Emit('if ' + KeyT + ' then')
        else Emit('else if ' + KeyT + ' then');
      end;
      Emit('begin');
      IncIndent;
      if ValT <> '' then Emit(ValT);
      BindCount := GetMatchArmBindingCount(MC);
      PushMatchBindings(MC, ErrF);
      try
        Emit(Format('%s := %s;', [TargetStr, EmitExpr(MC.ValueExpr)]));
      finally
        for BIdx := 0 to BindCount - 1 do
        begin
          GetMatchArmBindingInfo(MC, BIdx, ErrF, BName, TVar, BType);
          if (BName <> '') and (BName <> '_') then PopMatchBindings(1);
        end;
      end;
      DecIndent;
      if I < TASTMatchExpr(Expr).Cases.Count - 1 then Emit('end') else Emit('end;');
    end;
    Result := TargetStr;
    Exit;
  end
  else if Expr is TASTTupleLiteralExpr then
  begin
    ArgsStr := '';
    for I := 0 to TASTTupleLiteralExpr(Expr).Elements.Count - 1 do
    begin
      if I > 0 then ArgsStr := ArgsStr + ', ';
      ArgsStr := ArgsStr + EmitExpr(TASTExpr(TASTTupleLiteralExpr(Expr).Elements[I]));
    end;
    Result := Format('%s(%s)', [TASTTupleLiteralExpr(Expr).ResolvedType, ArgsStr]);
    Exit;
  end
  else if Expr is TASTLambdaExpr then
  begin
    with TASTLambdaExpr(Expr) do
    begin
      if CaptureNames.Count = 0 then
        Result := Format('AetherMakeFn_%s(@__aether_lambda_%d, nil)', [FnTypeTag(ResolvedFnType), LambdaId])
      else
      begin
        ArgsStr := '';
        for I := 0 to CaptureNames.Count - 1 do
        begin
          if I > 0 then ArgsStr := ArgsStr + ', ';
          ArgsStr := ArgsStr + CaptureNames[I];
        end;
        Result := Format('__aether_make_lambda_%d(%s)', [LambdaId, ArgsStr]);
      end;
    end;
    Exit;
  end;

  Result := '';
end;

procedure TAetherEmitterPascal.EmitActiveDefers(DownToIndex: Integer);
var
  I: Integer;
begin
  for I := FActiveDefers.Count - 1 downto DownToIndex do
    EmitStmt(TASTStmt(FActiveDefers[I]));
end;

function TAetherEmitterPascal.FindFunction(const AName: string): TASTFunction;
var
  I: Integer;
begin
  Result := nil;
  if Assigned(FModule) then
    for I := 0 to FModule.Functions.Count - 1 do
      if SameText(TASTFunction(FModule.Functions[I]).Name, AName) then
        Exit(TASTFunction(FModule.Functions[I]));
end;

function TAetherEmitterPascal.FindDropFunc(const ATypeName: string): TASTFunction;
var
  BaseT: string;
  Fn: TASTFunction;
begin
  Result := nil;
  BaseT := ResolveAliasType(ATypeName);
  if BaseT = '' then Exit;
  Fn := FindFunction(BaseT + '_Drop');
  if Assigned(Fn) and (not Fn.IsExtern) and (Fn.GenericParams.Count = 0) and (Fn.GenericParam = '') and (Fn.Params.Count = 1) then
    Result := Fn;
end;

function TAetherEmitterPascal.RaiiExprUsesVar(Expr: TASTExpr; const AVarName: string): Boolean;
var
  I: Integer;
  C: TASTCallExpr;
begin
  Result := False;
  if not Assigned(Expr) then Exit;
  if Expr is TASTIdentifierExpr then
    Exit(SameText(TASTIdentifierExpr(Expr).Name, AVarName));
  if Expr is TASTUnaryExpr then
    Exit(RaiiExprUsesVar(TASTUnaryExpr(Expr).Expr, AVarName));
  if Expr is TASTBinaryExpr then
    Exit(RaiiExprUsesVar(TASTBinaryExpr(Expr).Left, AVarName) or RaiiExprUsesVar(TASTBinaryExpr(Expr).Right, AVarName));
  if Expr is TASTMemberAccessExpr then
    Exit(RaiiExprUsesVar(TASTMemberAccessExpr(Expr).Target, AVarName));
  if Expr is TASTIndexExpr then
  begin
    if RaiiExprUsesVar(TASTIndexExpr(Expr).Target, AVarName) then Exit(True);
    for I := 0 to TASTIndexExpr(Expr).Indices.Count - 1 do
      if RaiiExprUsesVar(TASTExpr(TASTIndexExpr(Expr).Indices[I]), AVarName) then Exit(True);
  end;
  if Expr is TASTAwaitExpr then
    Exit(RaiiExprUsesVar(TASTAwaitExpr(Expr).Expr, AVarName));
  if Expr is TASTSpawnExpr then
    Exit(RaiiExprUsesVar(TASTSpawnExpr(Expr).CallExpr, AVarName));
  if Expr is TASTCallExpr then
  begin
    C := TASTCallExpr(Expr);
    if Assigned(C.CalleeExpr) and RaiiExprUsesVar(C.CalleeExpr, AVarName) then Exit(True);
    for I := 0 to C.Args.Count - 1 do
      if RaiiExprUsesVar(TASTCallArg(C.Args[I]).Expr, AVarName) then Exit(True);
  end;
  if Expr is TASTTupleLiteralExpr then
  begin
    for I := 0 to TASTTupleLiteralExpr(Expr).Elements.Count - 1 do
      if RaiiExprUsesVar(TASTExpr(TASTTupleLiteralExpr(Expr).Elements[I]), AVarName) then Exit(True);
  end;
  if Expr is TASTLambdaExpr then
  begin
    for I := 0 to TASTLambdaExpr(Expr).CaptureNames.Count - 1 do
      if SameText(TASTLambdaExpr(Expr).CaptureNames[I], AVarName) then Exit(True);
  end;
  if Expr is TASTSetLiteralExpr then
  begin
    for I := 0 to TASTSetLiteralExpr(Expr).Elements.Count - 1 do
      if RaiiExprUsesVar(TASTExpr(TASTSetLiteralExpr(Expr).Elements[I]), AVarName) then Exit(True);
  end;
  if Expr is TASTMapLiteralExpr then
  begin
    for I := 0 to TASTMapLiteralExpr(Expr).Keys.Count - 1 do
      if RaiiExprUsesVar(TASTExpr(TASTMapLiteralExpr(Expr).Keys[I]), AVarName) or
         RaiiExprUsesVar(TASTExpr(TASTMapLiteralExpr(Expr).Values[I]), AVarName) then Exit(True);
  end;
  if Expr is TASTIfExpr then
    Exit(RaiiExprUsesVar(TASTIfExpr(Expr).Condition, AVarName) or
         RaiiExprUsesVar(TASTIfExpr(Expr).ThenExpr, AVarName) or
         RaiiExprUsesVar(TASTIfExpr(Expr).ElseExpr, AVarName));
  if Expr is TASTMatchExpr then
  begin
    if RaiiExprUsesVar(TASTMatchExpr(Expr).Expr, AVarName) then Exit(True);
    for I := 0 to TASTMatchExpr(Expr).Cases.Count - 1 do
      if RaiiExprUsesVar(TASTMatchCase(TASTMatchExpr(Expr).Cases[I]).ValueExpr, AVarName) then Exit(True);
  end;
end;

function TAetherEmitterPascal.IsNonBorrowArgCapture(Call: TASTCallExpr; ArgIdx: Integer): Boolean;
var
  Fn: TASTFunction;
begin
  if SameText(Call.Callee, 'PrintLn') or SameText(Call.Callee, 'Print') or SameText(Call.Callee, 'WriteLn') or SameText(Call.Callee, 'Assert') or
     SameText(Call.Callee, 'Length') or SameText(Call.Callee, 'Count') or SameText(Call.Callee, 'Contains') or
     SameText(Call.Callee, 'High') or SameText(Call.Callee, 'Low') or SameText(Call.Callee, 'Pop') or
     SameText(Call.Callee, 'Clear') or SameText(Call.Callee, 'Remove') or SameText(Call.Callee, 'Delete') or
     SameText(Call.Callee, 'Slice') or SameText(Call.Callee, 'SetLength') or SameText(Call.Callee, 'Free') or
     SameText(Call.Callee, 'Dispose') or SameText(Call.Callee, 'Addr') or
     SameText(Call.Callee, 'Split') or SameText(Call.Callee, 'Join') or SameText(Call.Callee, 'PadLeft') or
     SameText(Call.Callee, 'PadRight') or SameText(Call.Callee, 'RepeatStr') or SameText(Call.Callee, 'StrToFloat') or
     SameText(Call.Callee, 'TryStrToInt') or SameText(Call.Callee, 'TryStrToFloat') or SameText(Call.Callee, 'GetEnv') or
     SameText(Call.Callee, 'SetEnv') or SameText(Call.Callee, 'ListDir') or SameText(Call.Callee, 'CopyFile') or
     SameText(Call.Callee, 'RenameFile') then
    Exit(False);
  if SameText(Call.Callee, 'Push') then
    Exit(ArgIdx = 1);
  if SameText(Call.Callee, 'Insert') then
    Exit(ArgIdx = 2);
  if SameText(Call.Callee, 'Some') or SameText(Call.Callee, 'Ok') or SameText(Call.Callee, 'Err') or
     SameText(Call.Callee, 'Box') then
    Exit(True);
  Fn := FindFunction(Call.Callee);
  if Assigned(Fn) and (ArgIdx < Fn.Params.Count) then
    Exit(not (TASTParam(Fn.Params[ArgIdx]).Ownership in [owBorrow, owMutBorrow]));
  Result := True;
end;

function TAetherEmitterPascal.IsVarEscapedInStmts(const AVarName: string; Stmts: TASTNodeList): Boolean;
  function ExprCapturesDirectVar(Expr: TASTExpr): Boolean;
  var
    I: Integer;
  begin
    Result := False;
    if not Assigned(Expr) then Exit;
    if Expr is TASTIdentifierExpr then
      Exit(SameText(TASTIdentifierExpr(Expr).Name, AVarName));
    if Expr is TASTIfExpr then
      Exit(ExprCapturesDirectVar(TASTIfExpr(Expr).ThenExpr) or
           ExprCapturesDirectVar(TASTIfExpr(Expr).ElseExpr));
    if Expr is TASTMatchExpr then
      for I := 0 to TASTMatchExpr(Expr).Cases.Count - 1 do
        if ExprCapturesDirectVar(TASTMatchCase(TASTMatchExpr(Expr).Cases[I]).ValueExpr) then Exit(True);
  end;

  function CheckExprEscape(Expr: TASTExpr): Boolean;
  var
    I: Integer;
    C: TASTCallExpr;
    U: TASTUnaryExpr;
    Arg: TASTCallArg;
  begin
    Result := False;
    if not Assigned(Expr) then Exit;
    if Expr is TASTUnaryExpr then
    begin
      U := TASTUnaryExpr(Expr);
      if (U.Op = '@') and RaiiExprUsesVar(U.Expr, AVarName) then Exit(True);
      Exit(CheckExprEscape(U.Expr));
    end;
    if Expr is TASTBinaryExpr then
      Exit(CheckExprEscape(TASTBinaryExpr(Expr).Left) or CheckExprEscape(TASTBinaryExpr(Expr).Right));
    if Expr is TASTMemberAccessExpr then
      Exit(CheckExprEscape(TASTMemberAccessExpr(Expr).Target));
    if Expr is TASTIndexExpr then
    begin
      if CheckExprEscape(TASTIndexExpr(Expr).Target) then Exit(True);
      for I := 0 to TASTIndexExpr(Expr).Indices.Count - 1 do
        if CheckExprEscape(TASTExpr(TASTIndexExpr(Expr).Indices[I])) then Exit(True);
    end;
    if Expr is TASTCallExpr then
    begin
      C := TASTCallExpr(Expr);
      for I := 0 to C.Args.Count - 1 do
      begin
        Arg := TASTCallArg(C.Args[I]);
        if (Arg.Ownership = owTake) and ExprCapturesDirectVar(Arg.Expr) then Exit(True);
        if (Arg.Expr is TASTIdentifierExpr) and SameText(TASTIdentifierExpr(Arg.Expr).Name, AVarName) then
        begin
          if IsNonBorrowArgCapture(C, I) then Exit(True);
        end
        else if CheckExprEscape(Arg.Expr) then
          Exit(True);
      end;
    end;
    if Expr is TASTSetLiteralExpr then
    begin
      for I := 0 to TASTSetLiteralExpr(Expr).Elements.Count - 1 do
        if ExprCapturesDirectVar(TASTExpr(TASTSetLiteralExpr(Expr).Elements[I])) or
           CheckExprEscape(TASTExpr(TASTSetLiteralExpr(Expr).Elements[I])) then Exit(True);
    end;
    if Expr is TASTMapLiteralExpr then
    begin
      for I := 0 to TASTMapLiteralExpr(Expr).Keys.Count - 1 do
        if ExprCapturesDirectVar(TASTExpr(TASTMapLiteralExpr(Expr).Keys[I])) or
           ExprCapturesDirectVar(TASTExpr(TASTMapLiteralExpr(Expr).Values[I])) or
           CheckExprEscape(TASTExpr(TASTMapLiteralExpr(Expr).Keys[I])) or
           CheckExprEscape(TASTExpr(TASTMapLiteralExpr(Expr).Values[I])) then Exit(True);
    end;
    if Expr is TASTIfExpr then
      Exit(CheckExprEscape(TASTIfExpr(Expr).Condition) or
           CheckExprEscape(TASTIfExpr(Expr).ThenExpr) or
           CheckExprEscape(TASTIfExpr(Expr).ElseExpr));
    if Expr is TASTMatchExpr then
    begin
      if CheckExprEscape(TASTMatchExpr(Expr).Expr) then Exit(True);
      for I := 0 to TASTMatchExpr(Expr).Cases.Count - 1 do
        if CheckExprEscape(TASTMatchCase(TASTMatchExpr(Expr).Cases[I]).ValueExpr) then Exit(True);
    end;
  end;
var
  I, J: Integer;
  S: TASTStmt;
  VD: TASTVarDecl;
begin
  Result := False;
  if not Assigned(Stmts) then Exit;
  for I := 0 to Stmts.Count - 1 do
  begin
    S := TASTStmt(Stmts[I]);
    if S is TASTReturnStmt then
    begin
      if ExprCapturesDirectVar(TASTReturnStmt(S).Expr) or CheckExprEscape(TASTReturnStmt(S).Expr) then Exit(True);
    end
    else if S is TASTVarDeclStmt then
    begin
      for J := 0 to TASTVarDeclStmt(S).Decls.Count - 1 do
      begin
        VD := TASTVarDecl(TASTVarDeclStmt(S).Decls[J]);
        if Assigned(VD.InitialExpr) and
           (ExprCapturesDirectVar(VD.InitialExpr) or CheckExprEscape(VD.InitialExpr)) then Exit(True);
      end;
    end
    else if S is TASTAssignStmt then
    begin
      if not ((TASTAssignStmt(S).Target is TASTIdentifierExpr) and
              SameText(TASTIdentifierExpr(TASTAssignStmt(S).Target).Name, AVarName)) then
      begin
        if ExprCapturesDirectVar(TASTAssignStmt(S).Expr) or CheckExprEscape(TASTAssignStmt(S).Expr) then Exit(True);
      end
      else if CheckExprEscape(TASTAssignStmt(S).Expr) then
        Exit(True);
    end
    else if S is TASTCallStmt then
    begin
      if CheckExprEscape(TASTCallStmt(S).CallExpr) then Exit(True);
    end
    else if S is TASTIfStmt then
    begin
      if CheckExprEscape(TASTIfStmt(S).Condition) or
         IsVarEscapedInStmts(AVarName, TASTIfStmt(S).ThenBranch) or
         IsVarEscapedInStmts(AVarName, TASTIfStmt(S).ElseBranch) then Exit(True);
    end
    else if S is TASTWhileStmt then
    begin
      if CheckExprEscape(TASTWhileStmt(S).Condition) or
         IsVarEscapedInStmts(AVarName, TASTWhileStmt(S).Body) then Exit(True);
    end
    else if S is TASTForStmt then
    begin
      if CheckExprEscape(TASTForStmt(S).CollectionExpr) or
         IsVarEscapedInStmts(AVarName, TASTForStmt(S).Body) then Exit(True);
    end
    else if S is TASTRepeatStmt then
    begin
      if IsVarEscapedInStmts(AVarName, TASTRepeatStmt(S).Body) or
         CheckExprEscape(TASTRepeatStmt(S).Condition) then Exit(True);
    end
    else if S is TASTUnsafeStmt then
    begin
      if IsVarEscapedInStmts(AVarName, TASTUnsafeStmt(S).Body) then Exit(True);
    end
    else if S is TASTTryStmt then
    begin
      if IsVarEscapedInStmts(AVarName, TASTTryStmt(S).TryBody) or
         IsVarEscapedInStmts(AVarName, TASTTryStmt(S).ExceptBody) then Exit(True);
    end
    else if S is TASTMatchStmt then
    begin
      if CheckExprEscape(TASTMatchStmt(S).Expr) then Exit(True);
      for J := 0 to TASTMatchStmt(S).Cases.Count - 1 do
        if IsVarEscapedInStmts(AVarName, TASTMatchCase(TASTMatchStmt(S).Cases[J]).Body) then Exit(True);
    end;
  end;
end;

procedure TAetherEmitterPascal.RegisterRaiiVar(const AVarName, ATypeName: string; ScopeStmts: TASTNodeList);
var
  BaseT, KeyT, ValT: string;
begin
  BaseT := ResolveAliasType(ATypeName);
  if (FindDropFunc(BaseT) = nil) and (Pos('Box<', BaseT) <> 1) and
     (not IsDynamicArrayType(BaseT)) and (not IsMapType(BaseT, KeyT, ValT)) then
    Exit;
  if IsVarEscapedInStmts(AVarName, ScopeStmts) then
    Exit;
  FRaiiNames.Add(AVarName);
  FRaiiTypes.Add(BaseT);
end;

procedure TAetherEmitterPascal.EmitRaiiCleanupFor(const AVarName, ATypeName: string);
var
  BaseT, InnerT, KeyT, ValT, DropCall: string;
  DropFn: TASTFunction;
begin
  BaseT := ResolveAliasType(ATypeName);
  DropFn := FindDropFunc(BaseT);
  if Assigned(DropFn) then
  begin
    Emit(Format('%s(%s);', [DropFn.Name, AVarName]));
    Exit;
  end;
  if Pos('Box<', BaseT) = 1 then
  begin
    InnerT := Trim(Copy(BaseT, 5, Length(BaseT) - 5));
    DropFn := FindDropFunc(InnerT);
    DropCall := '';
    if Assigned(DropFn) then
      DropCall := Format('%s(%s^); ', [DropFn.Name, AVarName]);
    Emit(Format('if %s <> nil then begin %sDispose(%s); %s := nil; end;', [AVarName, DropCall, AVarName, AVarName]));
  end
  else if IsDynamicArrayType(BaseT) then
  begin
    Emit(Format('SetLength(%s, 0);', [AVarName]));
  end
  else if IsMapType(BaseT, KeyT, ValT) then
  begin
    Emit(Format('SetLength(%s.entries, 0); %s.count := 0;', [AVarName, AVarName]));
  end;
end;

procedure TAetherEmitterPascal.EmitActiveRaii(DownToIndex: Integer);
var
  I: Integer;
begin
  for I := FRaiiNames.Count - 1 downto DownToIndex do
    EmitRaiiCleanupFor(FRaiiNames[I], FRaiiTypes[I]);
end;

procedure TAetherEmitterPascal.EmitStmtList(List: TASTNodeList; IsLoopBody: Boolean);
var
  I, SavedBase, OldLoopBase, SavedRaiiBase, OldLoopRaiiBase: Integer;
  OldScopeList: TASTNodeList;
begin
  SavedBase := FActiveDefers.Count;
  OldLoopBase := FLoopDeferBase;
  SavedRaiiBase := FRaiiNames.Count;
  OldLoopRaiiBase := FLoopRaiiBase;
  OldScopeList := FCurrentScopeList;
  FCurrentScopeList := List;
  if IsLoopBody then
  begin
    FLoopDeferBase := SavedBase;
    FLoopRaiiBase := SavedRaiiBase;
  end;
  try
    for I := 0 to List.Count - 1 do
      EmitStmt(TASTStmt(List[I]));
    if (List.Count = 0) or not (List[List.Count - 1] is TASTReturnStmt) then
    begin
      EmitActiveDefers(SavedBase);
      EmitActiveRaii(SavedRaiiBase);
    end;
  finally
    FCurrentScopeList := OldScopeList;
    FLoopDeferBase := OldLoopBase;
    FLoopRaiiBase := OldLoopRaiiBase;
    while FActiveDefers.Count > SavedBase do
      FActiveDefers.Delete(FActiveDefers.Count - 1);
    while FRaiiNames.Count > SavedRaiiBase do
    begin
      FRaiiNames.Delete(FRaiiNames.Count - 1);
      FRaiiTypes.Delete(FRaiiTypes.Count - 1);
    end;
  end;
end;

procedure TAetherEmitterPascal.BuildMatchCaseCond(CaseNode: TASTMatchCase; const ExprStr, MatchedType: string;
  out CondStr, BindStmt, BindVarType: string; out IsWildcardArm: Boolean);
var
  PatStr, ValF, ErrF, PatItem, LoStr, HiStr, LoExpr, HiExpr, ItemCond, BindExprStr, GuardStr: string;
  K, P2, BIdx, BCount, GuardAdded, PDot, J: Integer;
  Enm: TASTEnumDecl;
  VarN: TASTEnumVariant;
  VarName, BName, TVar, BType: string;

  function FormatMatchAtom(const S, MT: string): string;
  begin
    if (Length(S) >= 2) and (S[1] = '''') then
      Result := EscapePascalChar(Copy(S, 2, Length(S) - 2))
    else if (S = 'true') or (S = 'false') then
      Result := S
    else if (S <> '') and ((S[1] in ['0'..'9', '$', '%']) or ((S[1] = '-') and (Length(S) > 1))) then
      Result := NormalizeIntLit(S)
    else if Pos('.', S) > 0 then
      Result := StringReplace(S, '.', '_', [rfReplaceAll])
    else if IsEnumName(MT) then
      Result := MT + '_' + S
    else
      Result := S;
  end;
begin
  PatStr := CaseNode.Pattern.Value;
  CondStr := '';
  BindStmt := '';
  BindVarType := MatchedType;
  BindExprStr := ExprStr;
  IsWildcardArm := (PatStr = '_') and (not Assigned(CaseNode.Guard));
  GuardAdded := 0;

  Enm := FindEnumDecl(MatchedType);

  if PatStr = '_' then
  begin
    if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
    begin
      GetMatchArmBindingInfo(CaseNode, 0, MatchedType, BName, TVar, BType);
      BindStmt := Format('%s := %s;', [TVar, ExprStr]);
      FGuardBindNames.Add(BName);
      FGuardBindExprs.Add(ExprStr);
      Inc(GuardAdded);
    end;
  end
  else if Pos('Ok', PatStr) = 1 then
  begin
    CondStr := Format('%s.is_ok', [ExprStr]);
    if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
    begin
      SplitResultTypes(MatchedType, ValF, ErrF);
      BindVarType := ValF;
      GetMatchArmBindingInfo(CaseNode, 0, MatchedType, BName, TVar, BType);
      if IsTypedResult(MatchedType, ValF, ErrF) then
        BindExprStr := ExprStr + '.value'
      else
        BindExprStr := EmitMonadFieldExtract(ExprStr, ValF, 'value', 'str_val');
      BindStmt := Format('%s := %s;', [TVar, BindExprStr]);
      FGuardBindNames.Add(BName);
      FGuardBindExprs.Add(BindExprStr);
      Inc(GuardAdded);
    end;
  end
  else if Pos('Err', PatStr) = 1 then
  begin
    if (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
    begin
      SplitResultTypes(MatchedType, ValF, ErrF);
      if CaseNode.Pattern.IsLet then
      begin
        CondStr := Format('%s.is_err', [ExprStr]);
        BindVarType := ErrF;
        GetMatchArmBindingInfo(CaseNode, 0, MatchedType, BName, TVar, BType);
        if IsTypedResult(MatchedType, ValF, ErrF) then
          BindExprStr := ExprStr + '.error'
        else if ResolveAliasType(ErrF) = 'String' then
          BindExprStr := ExprStr + '.err_str'
        else
          BindExprStr := Format('%s(%s.error)', [EmitTypeRef(ErrF), ExprStr]);
        BindStmt := Format('%s := %s;', [TVar, BindExprStr]);
        FGuardBindNames.Add(BName);
        FGuardBindExprs.Add(BindExprStr);
        Inc(GuardAdded);
      end
      else if IsTypedResult(MatchedType, ValF, ErrF) then
      begin
        if (Length(CaseNode.Pattern.SubPattern) >= 2) and (CaseNode.Pattern.SubPattern[1] = '"') then
          CondStr := Format('(%s.is_err) and (%s.error = %s)',
            [ExprStr, ExprStr, EscapePascalString(Copy(CaseNode.Pattern.SubPattern, 2, Length(CaseNode.Pattern.SubPattern) - 2))])
        else
          CondStr := Format('(%s.is_err) and (%s.error = %s)',
            [ExprStr, ExprStr, StringReplace(CaseNode.Pattern.SubPattern, '.', '_', [rfReplaceAll])]);
      end
      else if (Length(CaseNode.Pattern.SubPattern) >= 2) and (CaseNode.Pattern.SubPattern[1] = '"') then
        CondStr := Format('(%s.is_err) and (%s.err_str = %s)',
          [ExprStr, ExprStr, EscapePascalString(Copy(CaseNode.Pattern.SubPattern, 2, Length(CaseNode.Pattern.SubPattern) - 2))])
      else
        CondStr := Format('(%s.is_err) and (%s.error = Integer(%s))',
          [ExprStr, ExprStr, StringReplace(CaseNode.Pattern.SubPattern, '.', '_', [rfReplaceAll])]);
    end
    else
      CondStr := Format('%s.is_err', [ExprStr]);
  end
  else if PatStr = 'Some' then
  begin
    if IsTypedValueOption(MatchedType, ValF) then
    begin
      CondStr := Format('%s.is_some', [ExprStr]);
      if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
      begin
        BindVarType := ValF;
        GetMatchArmBindingInfo(CaseNode, 0, MatchedType, BName, TVar, BType);
        BindExprStr := ExprStr + '.value';
        BindStmt := Format('%s := %s;', [TVar, BindExprStr]);
        FGuardBindNames.Add(BName);
        FGuardBindExprs.Add(BindExprStr);
        Inc(GuardAdded);
      end;
    end
    else if IsValueOptionType(MatchedType) then
    begin
      CondStr := Format('%s.is_some', [ExprStr]);
      if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
      begin
        ValF := SafeUnwrapGeneric(MatchedType, 'Option');
        BindVarType := ValF;
        GetMatchArmBindingInfo(CaseNode, 0, MatchedType, BName, TVar, BType);
        BindExprStr := EmitMonadFieldExtract(ExprStr, ValF, 'num_val', 'str_val');
        BindStmt := Format('%s := %s;', [TVar, BindExprStr]);
        FGuardBindNames.Add(BName);
        FGuardBindExprs.Add(BindExprStr);
        Inc(GuardAdded);
      end;
    end
    else
    begin
      CondStr := Format('(%s <> nil)', [ExprStr]);
      if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
      begin
        if Pos('Option<', MatchedType) = 1 then
          BindVarType := SafeUnwrapGeneric(MatchedType, 'Option');
        GetMatchArmBindingInfo(CaseNode, 0, MatchedType, BName, TVar, BType);
        BindStmt := Format('%s := %s;', [TVar, ExprStr]);
        FGuardBindNames.Add(BName);
        FGuardBindExprs.Add(ExprStr);
        Inc(GuardAdded);
      end;
    end;
  end
  else if (CaseNode.Pattern.Items.Count <= 1) and (PatStr = 'None') and (not Assigned(Enm)) then
  begin
    if IsValueOptionType(MatchedType) then
      CondStr := Format('%s.is_none', [ExprStr])
    else
      CondStr := Format('(%s = nil)', [ExprStr]);
  end
  else if Assigned(Enm) and Enm.HasPayload then
  begin
    VarN := nil;
    for K := 0 to CaseNode.Pattern.Items.Count - 1 do
    begin
      PatItem := Trim(CaseNode.Pattern.Items[K]);
      PDot := Pos('.', PatItem);
      if PDot > 0 then VarName := Copy(PatItem, PDot + 1, Length(PatItem))
      else VarName := PatItem;
      for J := 0 to Enm.Variants.Count - 1 do
        if SameText(TASTEnumVariant(Enm.Variants[J]).Name, VarName) then
        begin
          VarN := TASTEnumVariant(Enm.Variants[J]);
          VarName := VarN.Name;
          Break;
        end;
      ItemCond := Format('(%s.tag = %s_Tag_%s)', [ExprStr, Enm.Name, VarName]);
      if K > 0 then CondStr := CondStr + ' or ';
      CondStr := CondStr + ItemCond;
    end;
    if CaseNode.Pattern.Items.Count > 1 then
      CondStr := '(' + CondStr + ')';

    BCount := GetMatchArmBindingCount(CaseNode);
    if Assigned(VarN) and (BCount > 0) then
    begin
      for BIdx := 0 to BCount - 1 do
      begin
        GetMatchArmBindingInfo(CaseNode, BIdx, MatchedType, BName, TVar, BType);
        if (BIdx < VarN.Fields.Count) then
        begin
          BindExprStr := Format('%s._v_%s_%s', [ExprStr, VarN.Name, TASTRecordField(VarN.Fields[BIdx]).Name]);
          if (BName <> '') and (BName <> '_') then
          begin
            BindStmt := BindStmt + Format('%s := %s; ', [TVar, BindExprStr]);
            FGuardBindNames.Add(BName);
            FGuardBindExprs.Add(BindExprStr);
            Inc(GuardAdded);
          end;
        end;
      end;
    end;
  end
  else
  begin
    for K := 0 to CaseNode.Pattern.Items.Count - 1 do
    begin
      PatItem := Trim(CaseNode.Pattern.Items[K]);
      if (Pos('..', PatItem) > 0) and (Length(PatItem) > 0) and (PatItem[1] <> '"') then
      begin
        P2 := Pos('..', PatItem);
        LoStr := Trim(Copy(PatItem, 1, P2 - 1));
        HiStr := Trim(Copy(PatItem, P2 + 2, Length(PatItem)));
        LoExpr := FormatMatchAtom(LoStr, MatchedType);
        HiExpr := FormatMatchAtom(HiStr, MatchedType);
        ItemCond := Format('((%s >= %s) and (%s <= %s))', [ExprStr, LoExpr, ExprStr, HiExpr]);
      end
      else if (Length(PatItem) >= 2) and (PatItem[1] = '"') then
        ItemCond := Format('(%s = %s)', [ExprStr, EscapePascalString(Copy(PatItem, 2, Length(PatItem) - 2))])
      else
        ItemCond := Format('(%s = %s)', [ExprStr, FormatMatchAtom(PatItem, MatchedType)]);
      if K > 0 then CondStr := CondStr + ' or ';
      CondStr := CondStr + ItemCond;
    end;
    if CaseNode.Pattern.Items.Count > 1 then
      CondStr := '(' + CondStr + ')';
  end;

  if Assigned(CaseNode.Guard) then
  begin
    try
      GuardStr := EmitExpr(CaseNode.Guard);
    finally
      for BIdx := 1 to GuardAdded do
        if FGuardBindNames.Count > 0 then
        begin
          FGuardBindNames.Delete(FGuardBindNames.Count - 1);
          FGuardBindExprs.Delete(FGuardBindExprs.Count - 1);
        end;
    end;
    if CondStr = '' then
      CondStr := GuardStr
    else
      CondStr := Format('((%s) and (%s))', [CondStr, GuardStr]);
  end
  else
  begin
    for BIdx := 1 to GuardAdded do
      if FGuardBindNames.Count > 0 then
      begin
        FGuardBindNames.Delete(FGuardBindNames.Count - 1);
        FGuardBindExprs.Delete(FGuardBindExprs.Count - 1);
      end;
  end;
end;

procedure TAetherEmitterPascal.EmitStmt(Stmt: TASTStmt);
var
  Assign: TASTAssignStmt;
  CallStmt: TASTCallStmt;
  IfStmt: TASTIfStmt;
  WhileStmt: TASTWhileStmt;
  ForStmt: TASTForStmt;
  RepeatStmt: TASTRepeatStmt;
  MatchStmt: TASTMatchStmt;
  CaseNode: TASTMatchCase;
  Ret: TASTReturnStmt;
  VD: TASTVarDecl;
  Lines: TStringList;
  LineStr, ExprStr, MatchedType, Prefix, CondStr, BindStmt, BindVarT, OldBindName, OldBindType, KeyT, ValT, TargetT, IdxVar: string;
  IsWild: Boolean;
  I, J, Idx: Integer;
begin
  if Stmt is TASTVarDeclStmt then
  begin
    for I := 0 to TASTVarDeclStmt(Stmt).Decls.Count - 1 do
    begin
      VD := TASTVarDecl(TASTVarDeclStmt(Stmt).Decls[I]);
      if Assigned(VD.InitialExpr) then
      begin
        if VD.InitialExpr is TASTMapLiteralExpr then
          EmitMapLiteralAssign(VD.Name, VD.TypeName, TASTMapLiteralExpr(VD.InitialExpr))
        else if (VD.InitialExpr is TASTSetLiteralExpr) and (not IsSetType(VD.TypeName)) then
          EmitArrayLiteralAssign(VD.Name, VD.TypeName, TASTSetLiteralExpr(VD.InitialExpr))
        else
          Emit(Format('%s := %s;', [VD.Name, EmitExpr(VD.InitialExpr)]));
      end
      else if (Pos('Box<', ResolveAliasType(VD.TypeName)) = 1) or (Pos('^', VD.TypeName) = 1) or SameText(VD.TypeName, 'Pointer') then
        Emit(Format('%s := nil;', [VD.Name]))
      else if IsMapType(VD.TypeName, KeyT, ValT) then
        Emit(Format('%s.count := 0; SetLength(%s.entries, 0);', [VD.Name, VD.Name]));
      RegisterRaiiVar(VD.Name, VD.TypeName, FCurrentScopeList);
    end;
  end
  else if Stmt is TASTAssignStmt then
  begin
    Assign := TASTAssignStmt(Stmt);
    TargetT := GetExprTypeName(Assign.Target);
    if Assign.Expr is TASTMapLiteralExpr then
      EmitMapLiteralAssign(EmitExpr(Assign.Target), TargetT, TASTMapLiteralExpr(Assign.Expr))
    else if (Assign.Expr is TASTSetLiteralExpr) and (not IsSetType(TargetT)) then
      EmitArrayLiteralAssign(EmitExpr(Assign.Target), TargetT, TASTSetLiteralExpr(Assign.Expr))
    else if (Assign.Target is TASTIndexExpr) and IsMapType(GetExprTypeName(TASTIndexExpr(Assign.Target).Target), KeyT, ValT) then
      Emit(Format('AetherMapSet_%s(%s, %s, %s);', [
        MapTag(KeyT, ValT),
        EmitExpr(TASTIndexExpr(Assign.Target).Target),
        EmitExpr(TASTExpr(TASTIndexExpr(Assign.Target).Indices[0])),
        EmitExpr(Assign.Expr)]))
    else
      Emit(Format('%s := %s;', [EmitExpr(Assign.Target), EmitExpr(Assign.Expr)]));
  end
  else if Stmt is TASTCallStmt then
  begin
    CallStmt := TASTCallStmt(Stmt);
    Emit(EmitExpr(CallStmt.CallExpr) + ';');
  end
  else if Stmt is TASTIfStmt then
  begin
    IfStmt := TASTIfStmt(Stmt);
    Emit(Format('if %s then', [EmitExpr(IfStmt.Condition)]));
    Emit('begin');
    IncIndent;
    EmitStmtList(IfStmt.ThenBranch);
    DecIndent;
    if IfStmt.ElseBranch.Count > 0 then
    begin
      Emit('end');
      Emit('else');
      Emit('begin');
      IncIndent;
      EmitStmtList(IfStmt.ElseBranch);
      DecIndent;
    end;
    Emit('end;');
  end
  else if Stmt is TASTWhileStmt then
  begin
    WhileStmt := TASTWhileStmt(Stmt);
    Emit(Format('while %s do', [EmitExpr(WhileStmt.Condition)]));
    Emit('begin');
    IncIndent;
    EmitStmtList(WhileStmt.Body, True);
    DecIndent;
    Emit('end;');
  end
  else if Stmt is TASTForStmt then
  begin
    ForStmt := TASTForStmt(Stmt);
    if Assigned(ForStmt.CollectionExpr) and IsMapType(GetExprTypeName(ForStmt.CollectionExpr), KeyT, ValT) then
    begin
      IdxVar := Format('_aether_mi_%d_%d', [ForStmt.Line, ForStmt.Col]);
      ExprStr := EmitExpr(ForStmt.CollectionExpr);
      Emit(Format('for %s := 0 to %s.count - 1 do', [IdxVar, ExprStr]));
      Emit('begin');
      IncIndent;
      Emit(Format('%s := %s.entries[%s].key;', [ForStmt.VarName, ExprStr, IdxVar]));
      if ForStmt.ValVarName <> '' then
        Emit(Format('%s := %s.entries[%s].val;', [ForStmt.ValVarName, ExprStr, IdxVar]));
      EmitStmtList(ForStmt.Body, True);
      DecIndent;
      Emit('end;');
    end
    else
    begin
      if Assigned(ForStmt.CollectionExpr) then
        Emit(Format('for %s in %s do', [ForStmt.VarName, EmitExpr(ForStmt.CollectionExpr)]))
      else if ForStmt.IsDownTo then
        Emit(Format('for %s := %s downto %s do', [ForStmt.VarName, EmitExpr(ForStmt.StartExpr), EmitExpr(ForStmt.EndExpr)]))
      else
        Emit(Format('for %s := %s to %s do', [ForStmt.VarName, EmitExpr(ForStmt.StartExpr), EmitExpr(ForStmt.EndExpr)]));
      Emit('begin');
      IncIndent;
      EmitStmtList(ForStmt.Body, True);
      DecIndent;
      Emit('end;');
    end;
  end
  else if Stmt is TASTRepeatStmt then
  begin
    RepeatStmt := TASTRepeatStmt(Stmt);
    Emit('repeat');
    IncIndent;
    EmitStmtList(RepeatStmt.Body, True);
    DecIndent;
    Emit(Format('until %s;', [EmitExpr(RepeatStmt.Condition)]));
  end
  else if Stmt is TASTBreakStmt then
  begin
    if FActiveDefers.Count > FLoopDeferBase then
      EmitActiveDefers(FLoopDeferBase);
    if FRaiiNames.Count > FLoopRaiiBase then
      EmitActiveRaii(FLoopRaiiBase);
    Emit('break;');
  end
  else if Stmt is TASTContinueStmt then
  begin
    if FActiveDefers.Count > FLoopDeferBase then
      EmitActiveDefers(FLoopDeferBase);
    if FRaiiNames.Count > FLoopRaiiBase then
      EmitActiveRaii(FLoopRaiiBase);
    Emit('continue;');
  end
  else if Stmt is TASTDeferStmt then
  begin
    if Assigned(TASTDeferStmt(Stmt).Stmt) then
      FActiveDefers.Add(TASTDeferStmt(Stmt).Stmt);
  end
  else if Stmt is TASTTryStmt then
  begin
    Emit('try');
    IncIndent;
    EmitStmtList(TASTTryStmt(Stmt).TryBody);
    DecIndent;
    Emit('except');
    IncIndent;
    EmitStmtList(TASTTryStmt(Stmt).ExceptBody);
    DecIndent;
    Emit('end;');
  end
  else if Stmt is TASTRaiseStmt then
  begin
    Emit(Format('raise Exception.Create(%s);', [EmitExpr(TASTRaiseStmt(Stmt).Expr)]));
  end
  else if Stmt is TASTUnsafeStmt then
  begin
    Emit('// unsafe block');
    Emit('begin');
    IncIndent;
    EmitStmtList(TASTUnsafeStmt(Stmt).Body);
    DecIndent;
    Emit('end;');
  end
  else if Stmt is TASTReturnStmt then
  begin
    Ret := TASTReturnStmt(Stmt);
    if (FActiveDefers.Count > 0) or (FRaiiNames.Count > 0) or (Assigned(FCurrentFunc) and (FCurrentFunc.Ensures.Count > 0)) then
    begin
      if Assigned(Ret.Expr) then
      begin
        if Assigned(FCurrentFunc) and FCurrentFunc.IsAsync then
          Emit(Format('Result.is_completed := True; Result.value := %s;', [EmitExpr(Ret.Expr)]))
        else
          Emit(Format('Result := %s;', [EmitExpr(Ret.Expr)]));
        if FActiveDefers.Count > 0 then
          EmitActiveDefers(0);
        if Assigned(FCurrentFunc) then
          for J := 0 to FCurrentFunc.Ensures.Count - 1 do
            Emit(Format('Assert(%s, ''Post-condition (ensure) violation in function %s'');',
              [EmitExpr(TASTExpr(FCurrentFunc.Ensures[J])), FCurrentFunc.Name]));
        if FRaiiNames.Count > 0 then
          EmitActiveRaii(0);
        Emit('Exit(Result);');
      end
      else
      begin
        if FActiveDefers.Count > 0 then
          EmitActiveDefers(0);
        if Assigned(FCurrentFunc) then
          for J := 0 to FCurrentFunc.Ensures.Count - 1 do
            Emit(Format('Assert(%s, ''Post-condition (ensure) violation in function %s'');',
              [EmitExpr(TASTExpr(FCurrentFunc.Ensures[J])), FCurrentFunc.Name]));
        if FRaiiNames.Count > 0 then
          EmitActiveRaii(0);
        Emit('Exit;');
      end;
    end
    else
    begin
      if Assigned(Ret.Expr) then
      begin
        if Assigned(FCurrentFunc) and FCurrentFunc.IsAsync then
          Emit(Format('begin Result.is_completed := True; Result.value := %s; Exit(Result); end;', [EmitExpr(Ret.Expr)]))
        else
          Emit(Format('Exit(%s);', [EmitExpr(Ret.Expr)]));
      end
      else
        Emit('Exit;');
    end;
  end
  else if Stmt is TASTAsmStmt then
  begin
    Emit('{$ASMMODE INTEL}');
    Emit('asm');
    IncIndent;
    Lines := TStringList.Create;
    try
      Lines.Text := TASTAsmStmt(Stmt).AsmCode;
      for J := 0 to Lines.Count - 1 do
      begin
        LineStr := Trim(Lines[J]);
        if LineStr <> '' then
          Emit(LineStr);
      end;
    finally
      Lines.Free;
    end;
    DecIndent;
    Emit('end;');
  end
  else if Stmt is TASTMatchStmt then
  begin
    MatchStmt := TASTMatchStmt(Stmt);
    TargetT := Format('_aether_mval_%d_%d', [MatchStmt.Line, MatchStmt.Col]);
    Emit(Format('%s := %s;', [TargetT, EmitExpr(MatchStmt.Expr)]));
    MatchedType := ResolveAliasType(GetExprTypeName(MatchStmt.Expr));
    Emit('// Match generated by the Aether compiler');
    for I := 0 to MatchStmt.Cases.Count - 1 do
    begin
      CaseNode := TASTMatchCase(MatchStmt.Cases[I]);
      BuildMatchCaseCond(CaseNode, TargetT, MatchedType, CondStr, BindStmt, BindVarT, IsWild);
      if IsWild then
      begin
        if I > 0 then Emit('else');
        Emit('begin');
        IncIndent;
      end
      else
      begin
        if I = 0 then Prefix := 'if ' else Prefix := 'else if ';
        if CondStr = '' then CondStr := 'True';
        Emit(Prefix + CondStr + ' then');
        Emit('begin');
        IncIndent;
      end;
      if BindStmt <> '' then Emit(BindStmt);
      J := GetMatchArmBindingCount(CaseNode);
      PushMatchBindings(CaseNode, MatchedType);
      try
        for Idx := 0 to CaseNode.Body.Count - 1 do
          EmitStmt(TASTStmt(CaseNode.Body[Idx]));
      finally
        for Idx := 0 to J - 1 do
        begin
          GetMatchArmBindingInfo(CaseNode, Idx, MatchedType, KeyT, ValT, LineStr);
          if (KeyT <> '') and (KeyT <> '_') then PopMatchBindings(1);
        end;
      end;
      DecIndent;

      if I < MatchStmt.Cases.Count - 1 then
        Emit('end')
      else
        Emit('end;');
    end;
  end;
end;

procedure TAetherEmitterPascal.EmitRecordType(Rec: TASTRecordDecl);
var
  I: Integer;
  Field: TASTRecordField;
begin
  Emit(Format('T%s = record', [Rec.Name]));
  IncIndent;
  for I := 0 to Rec.Fields.Count - 1 do
  begin
    Field := TASTRecordField(Rec.Fields[I]);
    Emit(Format('%s: %s;', [Field.Name, EmitTypeRef(Field.TypeName)]));
  end;
  DecIndent;
  Emit('end;');
  Emit('');
end;

procedure TAetherEmitterPascal.EmitRecordConstructor(Rec: TASTRecordDecl);
var
  I: Integer;
  Field: TASTRecordField;
  CtorParams: string;
begin
  CtorParams := '';
  for I := 0 to Rec.Fields.Count - 1 do
  begin
    Field := TASTRecordField(Rec.Fields[I]);
    CtorParams := CtorParams + Format('const A_%s: %s', [Field.Name, EmitTypeRef(Field.TypeName)]);
    if I < Rec.Fields.Count - 1 then
      CtorParams := CtorParams + '; ';
  end;

  Emit(Format('function %s(%s): T%s;', [Rec.Name, CtorParams, Rec.Name]));
  Emit('begin');
  IncIndent;
  for I := 0 to Rec.Fields.Count - 1 do
  begin
    Field := TASTRecordField(Rec.Fields[I]);
    Emit(Format('Result.%s := A_%s;', [Field.Name, Field.Name]));
  end;
  DecIndent;
  Emit('end;');
  Emit('');
end;

procedure TAetherEmitterPascal.EmitEnumDecl(Enm: TASTEnumDecl);
var
  I, J: Integer;
  VariantName: string;
  V: TASTEnumVariant;
  F: TASTRecordField;
begin
  if Enm.HasPayload then
  begin
    Emit(Format('T%s_Tag = (', [Enm.Name]));
    IncIndent;
    for I := 0 to Enm.Variants.Count - 1 do
    begin
      VariantName := Enm.Name + '_Tag_' + TASTEnumVariant(Enm.Variants[I]).Name;
      if I < Enm.Variants.Count - 1 then
        Emit(VariantName + ',')
      else
        Emit(VariantName);
    end;
    DecIndent;
    Emit(');');
    Emit(Format('T%s = record', [Enm.Name]));
    IncIndent;
    Emit(Format('tag: T%s_Tag;', [Enm.Name]));
    for I := 0 to Enm.Variants.Count - 1 do
    begin
      V := TASTEnumVariant(Enm.Variants[I]);
      for J := 0 to V.Fields.Count - 1 do
      begin
        F := TASTRecordField(V.Fields[J]);
        Emit(Format('_v_%s_%s: %s;', [V.Name, F.Name, EmitTypeRef(F.TypeName)]));
      end;
    end;
    DecIndent;
    Emit('end;');
    Emit(Format('%s = T%s;', [Enm.Name, Enm.Name]));
    Emit('');
    Exit;
  end;

  Emit(Format('T%s = (', [Enm.Name]));
  IncIndent;
  for I := 0 to Enm.Variants.Count - 1 do
  begin
    VariantName := Enm.Name + '_' + TASTEnumVariant(Enm.Variants[I]).Name;
    if I < Enm.Variants.Count - 1 then
      Emit(VariantName + ',')
    else
      Emit(VariantName);
  end;
  DecIndent;
  Emit(');');
  Emit(Format('%s = T%s;', [Enm.Name, Enm.Name]));
  Emit('');
end;

procedure TAetherEmitterPascal.EmitArrayDecl(Arr: TASTArrayDecl);
var
  I, DimVal: Integer;
  DimsStr: string;
begin
  if Arr.Dims.Count = 0 then
  begin
    Emit(Format('T%s = array of %s;', [Arr.Name, EmitTypeRef(Arr.ElemType)]));
    Emit(Format('%s = T%s;', [Arr.Name, Arr.Name]));
    Emit('');
    Exit;
  end;
  DimsStr := '';
  for I := 0 to Arr.Dims.Count - 1 do
  begin
    DimVal := StrToIntDef(Arr.Dims[I], 1);
    if I > 0 then DimsStr := DimsStr + ', ';
    DimsStr := DimsStr + Format('0..%d', [DimVal - 1]);
  end;
  Emit(Format('T%s = array[%s] of %s;', [Arr.Name, DimsStr, EmitTypeRef(Arr.ElemType)]));
  Emit(Format('%s = T%s;', [Arr.Name, Arr.Name]));
  Emit('');
end;

procedure TAetherEmitterPascal.EmitSetDecl(SetD: TASTSetDecl);
var
  I: Integer;
  VarsStr: string;
begin
  if SetD.Variants.Count > 0 then
  begin
    VarsStr := '';
    for I := 0 to SetD.Variants.Count - 1 do
    begin
      if I > 0 then VarsStr := VarsStr + ', ';
      VarsStr := VarsStr + TASTEnumVariant(SetD.Variants[I]).Name;
    end;
    Emit(Format('T%s_Enum = (%s);', [SetD.Name, VarsStr]));
    Emit(Format('T%s = set of T%s_Enum;', [SetD.Name, SetD.Name]));
    Emit(Format('%s = T%s;', [SetD.Name, SetD.Name]));
  end
  else
  begin
    Emit(Format('T%s = set of %s;', [SetD.Name, EmitTypeRef(SetD.ElemType)]));
    Emit(Format('%s = T%s;', [SetD.Name, SetD.Name]));
  end;
  Emit('');
end;

procedure TAetherEmitterPascal.EmitSubrangeDecl(SubR: TASTSubrangeDecl);
begin
  Emit(Format('T%s = %s..%s;', [SubR.Name, SubR.LowBound, SubR.HighBound]));
  Emit(Format('%s = T%s;', [SubR.Name, SubR.Name]));
  Emit('');
end;

procedure TAetherEmitterPascal.EmitMapDecl(MapD: TASTMapDecl);
begin
  Emit(Format('T%s = TAetherMap_%s;', [MapD.Name, MapTag(MapD.KeyType, MapD.ValType)]));
  Emit(Format('%s = T%s;', [MapD.Name, MapD.Name]));
  Emit('');
end;

procedure TAetherEmitterPascal.EmitTypeAliasDecl(AliasD: TASTTypeAliasDecl);
begin
  Emit(Format('T%s = %s;', [AliasD.Name, EmitTypeRef(AliasD.TargetType)]));
  Emit(Format('%s = T%s;', [AliasD.Name, AliasD.Name]));
  Emit('');
end;

procedure TAetherEmitterPascal.EmitFunction(Func: TASTFunction);
var
  ParamListStr: string;
  I: Integer;
  Param: TASTParam;
  ModStr, ExportClause: string;
  VarDecl: TASTVarDecl;
  LibClause: string;
  ParamType, KeyT, ValT: string;
  SkipNames, AutoNames, AutoTypes: TStringList;
begin
  if (Func.GenericParams.Count > 0) or (Func.GenericParam <> '') then Exit; // Generic template does not emit code directly
  if SameText(Func.Name, 'Abs') or SameText(Func.Name, 'Min') or SameText(Func.Name, 'Max') or SameText(Func.Name, 'Clamp') then Exit;
  FCurrentFunc := Func;
  if Func.IsExtern then
  begin
    if Func.ExternAbi = 'pascal' then
    begin
      Emit(Format('// Extern Pascal: %s (provided by FPC unit)', [Func.Name]));
      Emit('');
      Exit;
    end;

    // Standard C math functions mapped directly to FPC Math
    if (Func.ExternAbi = 'c') and ((Func.Name = 'sin') or (Func.Name = 'cos') or (Func.Name = 'sqrt') or
       (Func.Name = 'tan') or (Func.Name = 'abs') or (Func.Name = 'floor') or (Func.Name = 'ceil')) then
    begin
      Emit(Format('// Extern C Math: %s (natively provided by FPC System/Math)', [Func.Name]));
      Emit('');
      Exit;
    end;

    if Func.ExternLib <> '' then
      LibClause := Format(' external ''%s'';', [Func.ExternLib])
    else
      LibClause := ' external ''msvcrt'';'; // Standard C runtime on Windows/FPC

    ParamListStr := '';
    for I := 0 to Func.Params.Count - 1 do
    begin
      Param := TASTParam(Func.Params[I]);
      case Param.Ownership of
        owMutBorrow: ModStr := 'var ';
        owBorrow:    ModStr := 'const ';
      else
        ModStr := 'const ';
      end;
      ParamType := EmitTypeRef(Param.TypeName);
      if Param.TypeName = 'String' then ParamType := 'PChar';
      ParamListStr := ParamListStr + Format('%s%s: %s', [ModStr, Param.Name, ParamType]);
      if I < Func.Params.Count - 1 then
        ParamListStr := ParamListStr + '; ';
    end;

    if (Func.ReturnType = 'Void') or (Func.ReturnType = '') then
      Emit(Format('procedure %s(%s); cdecl;%s', [Func.Name, ParamListStr, LibClause]))
    else
      Emit(Format('function %s(%s): %s; cdecl;%s', [Func.Name, ParamListStr, EmitTypeRef(Func.ReturnType), LibClause]));
    Emit('');
    Exit;
  end;

  ParamListStr := '';
  for I := 0 to Func.Params.Count - 1 do
  begin
    Param := TASTParam(Func.Params[I]);
    case Param.Ownership of
      owMutBorrow: ModStr := 'var ';
      owBorrow:    ModStr := 'const ';
      owTake:      ModStr := '';
    else
      ModStr := 'const ';
    end;
    ParamListStr := ParamListStr + Format('%s%s: %s', [ModStr, Param.Name, EmitTypeRef(Param.TypeName)]);
    if I < Func.Params.Count - 1 then
      ParamListStr := ParamListStr + '; ';
  end;

  ExportClause := '';
  if Func.IsExport then
    ExportClause := ' cdecl;';
  if Func.InlineMode = 'always' then
    ExportClause := ExportClause + ' inline;';

  if Func.IsAsync then
    Emit(Format('function %s(%s): specialize TAetherTask<%s>;%s', [Func.Name, ParamListStr, EmitTypeRef(Func.ReturnType), ExportClause]))
  else if (Func.ReturnType = 'Void') or (Func.ReturnType = '') then
    Emit(Format('procedure %s(%s);%s', [Func.Name, ParamListStr, ExportClause]))
  else
    Emit(Format('function %s(%s): %s;%s', [Func.Name, ParamListStr, EmitTypeRef(Func.ReturnType), ExportClause]));

  // Local Variables
  SkipNames := TStringList.Create;
  AutoNames := TStringList.Create;
  AutoTypes := TStringList.Create;
  try
    for I := 0 to Func.Params.Count - 1 do
      SkipNames.Add(TASTParam(Func.Params[I]).Name);
    for I := 0 to Func.LocalVars.Count - 1 do
    begin
      SkipNames.Add(TASTVarDecl(Func.LocalVars[I]).Name);
      if Assigned(TASTVarDecl(Func.LocalVars[I]).InitialExpr) and
         not (TASTVarDecl(Func.LocalVars[I]).InitialExpr is TASTMapLiteralExpr) then
        CollectAutoVarsFromExpr(TASTVarDecl(Func.LocalVars[I]).InitialExpr, AutoNames, AutoTypes, SkipNames);
    end;
    CollectAutoVarsFromStmts(Func.Body, AutoNames, AutoTypes, SkipNames);

    if (Func.LocalVars.Count > 0) or (AutoNames.Count > 0) then
    begin
      Emit('var');
      IncIndent;
      for I := 0 to Func.LocalVars.Count - 1 do
      begin
        VarDecl := TASTVarDecl(Func.LocalVars[I]);
        Emit(Format('%s: %s;', [VarDecl.Name, EmitTypeRef(VarDecl.TypeName)]));
      end;
      for I := 0 to AutoNames.Count - 1 do
        Emit(Format('%s: %s;', [AutoNames[I], AutoTypes[I]]));
      DecIndent;
    end;
  finally
    SkipNames.Free;
    AutoNames.Free;
    AutoTypes.Free;
  end;

  Emit('begin');
  IncIndent;

  for I := 0 to Func.LocalVars.Count - 1 do
  begin
    VarDecl := TASTVarDecl(Func.LocalVars[I]);
    if Assigned(VarDecl.InitialExpr) then
    begin
      if VarDecl.InitialExpr is TASTMapLiteralExpr then
        EmitMapLiteralAssign(VarDecl.Name, VarDecl.TypeName, TASTMapLiteralExpr(VarDecl.InitialExpr))
      else if (VarDecl.InitialExpr is TASTSetLiteralExpr) and (not IsSetType(VarDecl.TypeName)) then
        EmitArrayLiteralAssign(VarDecl.Name, VarDecl.TypeName, TASTSetLiteralExpr(VarDecl.InitialExpr))
      else
        Emit(Format('%s := %s;', [VarDecl.Name, EmitExpr(VarDecl.InitialExpr)]));
    end
    else if (Pos('Box<', ResolveAliasType(VarDecl.TypeName)) = 1) or (Pos('^', VarDecl.TypeName) = 1) or SameText(VarDecl.TypeName, 'Pointer') then
      Emit(Format('%s := nil;', [VarDecl.Name]))
    else if IsMapType(VarDecl.TypeName, KeyT, ValT) then
      Emit(Format('%s.count := 0; SetLength(%s.entries, 0);', [VarDecl.Name, VarDecl.Name]));
  end;

  // Runtime require contract checks (Asserts)
  for I := 0 to Func.Requires.Count - 1 do
  begin
    Emit(Format('Assert(%s, ''Pre-condition (require) violation in function %s'');', [EmitExpr(TASTExpr(Func.Requires[I])), Func.Name]));
  end;

  // Body
  FActiveDefers.Clear;
  FLoopDeferBase := 0;
  FRaiiNames.Clear;
  FRaiiTypes.Clear;
  FLoopRaiiBase := 0;
  FCurrentScopeList := Func.Body;
  for I := 0 to Func.LocalVars.Count - 1 do
    RegisterRaiiVar(TASTVarDecl(Func.LocalVars[I]).Name, TASTVarDecl(Func.LocalVars[I]).TypeName, Func.Body);
  EmitStmtList(Func.Body);
  FActiveDefers.Clear;

  if (Func.Body.Count = 0) or not (Func.Body[Func.Body.Count - 1] is TASTReturnStmt) then
  begin
    for I := 0 to Func.Ensures.Count - 1 do
      Emit(Format('Assert(%s, ''Post-condition (ensure) violation in function %s'');',
        [EmitExpr(TASTExpr(Func.Ensures[I])), Func.Name]));
    if FRaiiNames.Count > 0 then
      EmitActiveRaii(0);
  end;
  FRaiiNames.Clear;
  FRaiiTypes.Clear;
  FCurrentScopeList := nil;

  DecIndent;
  Emit('end;');
  Emit('');
end;

procedure TAetherEmitterPascal.EmitProgramBlock(Prog: TASTProgramBlock);
var
  I: Integer;
  VarDecl: TASTVarDecl;
  KeyT, ValT: string;
  SkipNames, AutoNames, AutoTypes: TStringList;
begin
  FCurrentFunc := nil;
  FProgramBlock := Prog;
  SkipNames := TStringList.Create;
  AutoNames := TStringList.Create;
  AutoTypes := TStringList.Create;
  try
    for I := 0 to Prog.LocalVars.Count - 1 do
    begin
      SkipNames.Add(TASTVarDecl(Prog.LocalVars[I]).Name);
      if Assigned(TASTVarDecl(Prog.LocalVars[I]).InitialExpr) and
         not (TASTVarDecl(Prog.LocalVars[I]).InitialExpr is TASTMapLiteralExpr) then
        CollectAutoVarsFromExpr(TASTVarDecl(Prog.LocalVars[I]).InitialExpr, AutoNames, AutoTypes, SkipNames);
    end;
    CollectAutoVarsFromStmts(Prog.Body, AutoNames, AutoTypes, SkipNames);

    if (Prog.LocalVars.Count > 0) or (AutoNames.Count > 0) then
    begin
      Emit('var');
      IncIndent;
      for I := 0 to Prog.LocalVars.Count - 1 do
      begin
        VarDecl := TASTVarDecl(Prog.LocalVars[I]);
        Emit(Format('%s: %s;', [VarDecl.Name, EmitTypeRef(VarDecl.TypeName)]));
      end;
      for I := 0 to AutoNames.Count - 1 do
        Emit(Format('%s: %s;', [AutoNames[I], AutoTypes[I]]));
      DecIndent;
    end;
  finally
    SkipNames.Free;
    AutoNames.Free;
    AutoTypes.Free;
  end;

  Emit('begin');
  IncIndent;
  if Assigned(FModule) then
  begin
    for I := 0 to FModule.ModuleVars.Count - 1 do
    begin
      VarDecl := TASTVarDecl(FModule.ModuleVars[I]);
      if Assigned(VarDecl.InitialExpr) then
      begin
        if VarDecl.InitialExpr is TASTMapLiteralExpr then
          EmitMapLiteralAssign(VarDecl.Name, VarDecl.TypeName, TASTMapLiteralExpr(VarDecl.InitialExpr))
        else if (VarDecl.InitialExpr is TASTSetLiteralExpr) and (not IsSetType(VarDecl.TypeName)) then
          EmitArrayLiteralAssign(VarDecl.Name, VarDecl.TypeName, TASTSetLiteralExpr(VarDecl.InitialExpr))
        else
          Emit(Format('%s := %s;', [VarDecl.Name, EmitExpr(VarDecl.InitialExpr)]));
      end
      else if (Pos('Box<', ResolveAliasType(VarDecl.TypeName)) = 1) or (Pos('^', VarDecl.TypeName) = 1) or SameText(VarDecl.TypeName, 'Pointer') then
        Emit(Format('%s := nil;', [VarDecl.Name]))
      else if IsMapType(VarDecl.TypeName, KeyT, ValT) then
        Emit(Format('%s.count := 0; SetLength(%s.entries, 0);', [VarDecl.Name, VarDecl.Name]));
    end;
    for I := 0 to FModule.InitProcs.Count - 1 do
      Emit(Format('%s;', [FModule.InitProcs[I]]));
  end;

  for I := 0 to Prog.LocalVars.Count - 1 do
  begin
    VarDecl := TASTVarDecl(Prog.LocalVars[I]);
    if Assigned(VarDecl.InitialExpr) then
    begin
      if VarDecl.InitialExpr is TASTMapLiteralExpr then
        EmitMapLiteralAssign(VarDecl.Name, VarDecl.TypeName, TASTMapLiteralExpr(VarDecl.InitialExpr))
      else if (VarDecl.InitialExpr is TASTSetLiteralExpr) and (not IsSetType(VarDecl.TypeName)) then
        EmitArrayLiteralAssign(VarDecl.Name, VarDecl.TypeName, TASTSetLiteralExpr(VarDecl.InitialExpr))
      else
        Emit(Format('%s := %s;', [VarDecl.Name, EmitExpr(VarDecl.InitialExpr)]));
    end
    else if (Pos('Box<', ResolveAliasType(VarDecl.TypeName)) = 1) or (Pos('^', VarDecl.TypeName) = 1) or SameText(VarDecl.TypeName, 'Pointer') then
      Emit(Format('%s := nil;', [VarDecl.Name]))
    else if IsMapType(VarDecl.TypeName, KeyT, ValT) then
      Emit(Format('%s.count := 0; SetLength(%s.entries, 0);', [VarDecl.Name, VarDecl.Name]));
  end;

  if Assigned(FModule) and (FModule.FiniProcs.Count > 0) then
  begin
    Emit('try');
    IncIndent;
  end;

  FActiveDefers.Clear;
  FLoopDeferBase := 0;
  FRaiiNames.Clear;
  FRaiiTypes.Clear;
  FLoopRaiiBase := 0;
  FCurrentScopeList := Prog.Body;
  for I := 0 to Prog.LocalVars.Count - 1 do
    RegisterRaiiVar(TASTVarDecl(Prog.LocalVars[I]).Name, TASTVarDecl(Prog.LocalVars[I]).TypeName, Prog.Body);
  EmitStmtList(Prog.Body);
  FActiveDefers.Clear;
  if (Prog.Body.Count = 0) or not (Prog.Body[Prog.Body.Count - 1] is TASTReturnStmt) then
  begin
    if FRaiiNames.Count > 0 then
      EmitActiveRaii(0);
  end;
  FRaiiNames.Clear;
  FRaiiTypes.Clear;
  FCurrentScopeList := nil;

  if Assigned(FModule) and (FModule.FiniProcs.Count > 0) then
  begin
    DecIndent;
    Emit('finally');
    IncIndent;
    for I := FModule.FiniProcs.Count - 1 downto 0 do
      Emit(Format('%s;', [FModule.FiniProcs[I]]));
    DecIndent;
    Emit('end;');
  end;

  DecIndent;
  Emit('end.');
end;

function TAetherEmitterPascal.BuildFuncSig(Func: TASTFunction): string;
var
  J: Integer;
  Param: TASTParam;
  ParamListStr, ModStr, LibClause, ParamType, ExportClause: string;
begin
  if SameText(Func.Name, 'Abs') or SameText(Func.Name, 'Min') or SameText(Func.Name, 'Max') or SameText(Func.Name, 'Clamp') then
    Exit('');
  if Func.IsExtern then
  begin
    if (Func.ExternAbi = 'pascal') or (Func.ExternLib = 'pascal') or (LowerCase(Func.ExternLib) = 'unit') then
      Exit('');

    if (Func.ExternLib = '') and ((Func.Name = 'sin') or (Func.Name = 'cos') or (Func.Name = 'sqrt')) then
      Exit('');

    if Func.ExternLib <> '' then
      LibClause := Format(' external ''%s'';', [Func.ExternLib])
    else
      LibClause := ' external ''msvcrt'';';

    ParamListStr := '';
    for J := 0 to Func.Params.Count - 1 do
    begin
      Param := TASTParam(Func.Params[J]);
      case Param.Ownership of
        owMutBorrow: ModStr := 'var ';
        owBorrow:    ModStr := 'const ';
      else
        ModStr := 'const ';
      end;
      ParamType := EmitTypeRef(Param.TypeName);
      if Param.TypeName = 'String' then ParamType := 'PChar';
      ParamListStr := ParamListStr + Format('%s%s: %s', [ModStr, Param.Name, ParamType]);
      if J < Func.Params.Count - 1 then
        ParamListStr := ParamListStr + '; ';
    end;

    if (Func.ReturnType = 'Void') or (Func.ReturnType = '') then
      Result := Format('procedure %s(%s); cdecl;%s', [Func.Name, ParamListStr, LibClause])
    else
      Result := Format('function %s(%s): %s; cdecl;%s', [Func.Name, ParamListStr, EmitTypeRef(Func.ReturnType), LibClause]);
    Exit;
  end;

  ParamListStr := '';
  for J := 0 to Func.Params.Count - 1 do
  begin
    Param := TASTParam(Func.Params[J]);
    case Param.Ownership of
      owMutBorrow: ModStr := 'var ';
      owBorrow:    ModStr := 'const ';
      owTake:      ModStr := '';
    else
      ModStr := 'const ';
    end;
    ParamListStr := ParamListStr + Format('%s%s: %s', [ModStr, Param.Name, EmitTypeRef(Param.TypeName)]);
    if J < Func.Params.Count - 1 then
      ParamListStr := ParamListStr + '; ';
  end;

  ExportClause := '';
  if Func.IsExport then
    ExportClause := ' cdecl;';

  if Func.IsAsync then
    Result := Format('function %s(%s): specialize TAetherTask<%s>;%s', [Func.Name, ParamListStr, EmitTypeRef(Func.ReturnType), ExportClause])
  else if (Func.ReturnType = 'Void') or (Func.ReturnType = '') then
    Result := Format('procedure %s(%s);%s', [Func.Name, ParamListStr, ExportClause])
  else
    Result := Format('function %s(%s): %s;%s', [Func.Name, ParamListStr, EmitTypeRef(Func.ReturnType), ExportClause]);
end;

function TAetherEmitterPascal.BuildRecordConstructorSig(Rec: TASTRecordDecl): string;
var
  I: Integer;
  Field: TASTRecordField;
  CtorParams: string;
begin
  CtorParams := '';
  for I := 0 to Rec.Fields.Count - 1 do
  begin
    Field := TASTRecordField(Rec.Fields[I]);
    CtorParams := CtorParams + Format('const A_%s: %s', [Field.Name, EmitTypeRef(Field.TypeName)]);
    if I < Rec.Fields.Count - 1 then
      CtorParams := CtorParams + '; ';
  end;
  Result := Format('function %s(%s): T%s;', [Rec.Name, CtorParams, Rec.Name]);
end;

procedure TAetherEmitterPascal.EmitRuntimeTypeDecls(const RefText: string; MapTags, MapKeys, MapVals: TStringList; AsUnit: Boolean);
var
  I: Integer;
  NeedFloat64, NeedFloat32, NeedPtr, NeedDyn, NeedResult, NeedTask, NeedOption, HasBuiltinMap, HasAnyType: Boolean;
begin
  NeedFloat64 := (Pos('Float64', RefText) > 0);
  NeedFloat32 := (Pos('Float32', RefText) > 0);
  NeedPtr := (Pos('PAetherPtr_', RefText) > 0);
  NeedDyn := (Pos('TAetherDyn_', RefText) > 0) or (Pos('AetherDynPop_', RefText) > 0) or
             (Pos('AetherStrSplit', RefText) > 0) or (Pos('AetherStrJoin', RefText) > 0) or
             (Pos('AetherListDir', RefText) > 0);
  NeedResult := (Pos('TAetherResult', RefText) > 0) or (Pos('TResultDoubleError', RefText) > 0) or
                (Pos('AetherOk(', RefText) > 0) or (Pos('AetherErr(', RefText) > 0);
  NeedTask := (Pos('TAetherTask', RefText) > 0);
  NeedOption := (Pos('TAetherOption', RefText) > 0) or (Pos('AetherSome(', RefText) > 0) or
                (Pos('AetherNone(', RefText) > 0) or (Pos('AetherTryStrToInt', RefText) > 0) or
                (Pos('AetherTryStrToFloat', RefText) > 0);
  HasBuiltinMap := False;
  for I := 0 to MapTags.Count - 1 do
    if IsBuiltinMapSideType(MapKeys[I]) and IsBuiltinMapSideType(MapVals[I]) then
    begin
      HasBuiltinMap := True;
      Break;
    end;
  HasAnyType := NeedFloat64 or NeedFloat32 or NeedPtr or NeedDyn or NeedResult or NeedTask or NeedOption or HasBuiltinMap;
  if not HasAnyType then Exit;

  if AsUnit then
    Emit('// --- Aether Runtime Helpers & Monads ---')
  else
    Emit('// --- Aether Runtime Helpers ---');

  if NeedFloat64 or NeedFloat32 or NeedPtr or NeedDyn or NeedResult then
  begin
    Emit('type');
    if NeedFloat64 then Emit('  Float64 = Double;');
    if NeedFloat32 then Emit('  Float32 = Single;');
    if NeedPtr then
    begin
      Emit('  PAetherPtr_Int8 = ^Int8; PAetherPtr_Int16 = ^Int16; PAetherPtr_Int32 = ^Int32; PAetherPtr_Int64 = ^Int64;');
      Emit('  PAetherPtr_UInt8 = ^UInt8; PAetherPtr_UInt16 = ^UInt16; PAetherPtr_UInt32 = ^UInt32; PAetherPtr_UInt64 = ^UInt64;');
      Emit('  PAetherPtr_Float32 = ^Single; PAetherPtr_Float64 = ^Double; PAetherPtr_Bool = ^Boolean; PAetherPtr_Char = ^Char; PAetherPtr_String = ^String;');
    end;
    if NeedDyn then
    begin
      Emit('  TAetherDyn_Int8 = array of Int8; TAetherDyn_Int16 = array of Int16; TAetherDyn_Int32 = array of Int32; TAetherDyn_Int64 = array of Int64;');
      Emit('  TAetherDyn_UInt8 = array of UInt8; TAetherDyn_UInt16 = array of UInt16; TAetherDyn_UInt32 = array of UInt32; TAetherDyn_UInt64 = array of UInt64;');
      Emit('  TAetherDyn_Float32 = array of Single; TAetherDyn_Float64 = array of Double; TAetherDyn_Bool = array of Boolean; TAetherDyn_Char = array of Char;');
      Emit('  TAetherDyn_String = array of String; TAetherDyn_Pointer = array of Pointer;');
    end;
    if NeedResult then
    begin
      Emit('  generic TAetherResult<TVal, TErr> = record');
      Emit('    is_ok: Boolean;');
      Emit('    is_err: Boolean;');
      Emit('    value: TVal;');
      Emit('    error: TErr;');
      Emit('    str_val: String;');
      Emit('    err_str: String;');
      Emit('  end;');
      Emit('  TResultDoubleError = specialize TAetherResult<Double, Integer>;');
    end;
    Emit('');
  end;

  if NeedTask then
  begin
    Emit('type');
    Emit('  generic TAetherTask<TVal> = record');
    Emit('    is_completed: Boolean;');
    Emit('    value: TVal;');
    Emit('  end;');
    Emit('');
  end;

  if NeedOption then
  begin
    Emit('type');
    Emit('  TAetherOption = record');
    Emit('    is_some: Boolean;');
    Emit('    is_none: Boolean;');
    Emit('    num_val: Double;');
    Emit('    str_val: String;');
    Emit('  end;');
    Emit('');
  end;

  if HasBuiltinMap then
  begin
    Emit('type');
    EmitMapRuntimeDecls(MapTags, MapKeys, MapVals, True);
    Emit('');
  end;
end;

procedure TAetherEmitterPascal.EmitRuntimeHelpersInterface(const RefText: string);
var
  NeedResult, NeedOption, NeedFileIO, NeedJson, NeedSockets, EmittedAny: Boolean;
begin
  EmittedAny := False;
  NeedResult := (Pos('AetherOk(', RefText) > 0) or (Pos('AetherErr(', RefText) > 0);
  NeedOption := (Pos('AetherSome(', RefText) > 0) or (Pos('AetherNone(', RefText) > 0) or
                (Pos('AetherTryStrToInt', RefText) > 0) or (Pos('AetherTryStrToFloat', RefText) > 0);
  NeedFileIO := (Pos('AetherFileExists', RefText) > 0) or (Pos('AetherReadFile', RefText) > 0) or
                (Pos('AetherWriteFile', RefText) > 0) or (Pos('AetherCreateDir', RefText) > 0) or
                (Pos('AetherRemoveDir', RefText) > 0) or (Pos('AetherDeleteFile', RefText) > 0) or
                (Pos('AetherDirExists', RefText) > 0) or (Pos('AetherFileSize', RefText) > 0) or
                (Pos('AetherListDir', RefText) > 0) or (Pos('AetherCopyFile', RefText) > 0) or
                (Pos('AetherRenameFile', RefText) > 0);
  NeedJson := (Pos('AetherJson', RefText) > 0);
  NeedSockets := (Pos('AetherSocket', RefText) > 0);

  if NeedResult then
  begin
    Emit('function AetherOk(const V: Double): TResultDoubleError; overload;');
    Emit('function AetherOk(const V: String): TResultDoubleError; overload;');
    Emit('function AetherOk(const V: Boolean): TResultDoubleError; overload;');
    Emit('function AetherErr(const E: Integer): TResultDoubleError; overload;');
    Emit('function AetherErr(const E: String): TResultDoubleError; overload;');
    EmittedAny := True;
  end;
  if NeedOption then
  begin
    Emit('function AetherSome(const V: Double): TAetherOption; overload;');
    Emit('function AetherSome(const V: String): TAetherOption; overload;');
    Emit('function AetherSome(const V: Boolean): TAetherOption; overload;');
    Emit('function AetherNone(): TAetherOption;');
    EmittedAny := True;
  end;
  if Pos('AetherDynPop_Int8', RefText) > 0 then begin Emit('function AetherDynPop_Int8(var A: TAetherDyn_Int8): Int8;'); EmittedAny := True; end;
  if Pos('AetherDynPop_Int16', RefText) > 0 then begin Emit('function AetherDynPop_Int16(var A: TAetherDyn_Int16): Int16;'); EmittedAny := True; end;
  if Pos('AetherDynPop_Int32', RefText) > 0 then begin Emit('function AetherDynPop_Int32(var A: TAetherDyn_Int32): Int32;'); EmittedAny := True; end;
  if Pos('AetherDynPop_Int64', RefText) > 0 then begin Emit('function AetherDynPop_Int64(var A: TAetherDyn_Int64): Int64;'); EmittedAny := True; end;
  if Pos('AetherDynPop_UInt8', RefText) > 0 then begin Emit('function AetherDynPop_UInt8(var A: TAetherDyn_UInt8): UInt8;'); EmittedAny := True; end;
  if Pos('AetherDynPop_UInt16', RefText) > 0 then begin Emit('function AetherDynPop_UInt16(var A: TAetherDyn_UInt16): UInt16;'); EmittedAny := True; end;
  if Pos('AetherDynPop_UInt32', RefText) > 0 then begin Emit('function AetherDynPop_UInt32(var A: TAetherDyn_UInt32): UInt32;'); EmittedAny := True; end;
  if Pos('AetherDynPop_UInt64', RefText) > 0 then begin Emit('function AetherDynPop_UInt64(var A: TAetherDyn_UInt64): UInt64;'); EmittedAny := True; end;
  if Pos('AetherDynPop_Float32', RefText) > 0 then begin Emit('function AetherDynPop_Float32(var A: TAetherDyn_Float32): Single;'); EmittedAny := True; end;
  if Pos('AetherDynPop_Float64', RefText) > 0 then begin Emit('function AetherDynPop_Float64(var A: TAetherDyn_Float64): Double;'); EmittedAny := True; end;
  if Pos('AetherDynPop_Bool', RefText) > 0 then begin Emit('function AetherDynPop_Bool(var A: TAetherDyn_Bool): Boolean;'); EmittedAny := True; end;
  if Pos('AetherDynPop_Char', RefText) > 0 then begin Emit('function AetherDynPop_Char(var A: TAetherDyn_Char): Char;'); EmittedAny := True; end;
  if Pos('AetherDynPop_String', RefText) > 0 then begin Emit('function AetherDynPop_String(var A: TAetherDyn_String): String;'); EmittedAny := True; end;
  if Pos('AetherDynPop_Pointer', RefText) > 0 then begin Emit('function AetherDynPop_Pointer(var A: TAetherDyn_Pointer): Pointer;'); EmittedAny := True; end;
  if Pos('AetherCharAt', RefText) > 0 then begin Emit('function AetherCharAt(const S: string; Index: Cardinal): string;'); EmittedAny := True; end;
  if Pos('AetherSubstring', RefText) > 0 then begin Emit('function AetherSubstring(const S: string; Start, Len: Cardinal): string;'); EmittedAny := True; end;
  if Pos('AetherIfThen', RefText) > 0 then begin Emit('generic function AetherIfThen<T>(Cond: Boolean; const A, B: T): T;'); EmittedAny := True; end;
  if Pos('AetherMin', RefText) > 0 then begin Emit('generic function AetherMin<T>(const A, B: T): T;'); EmittedAny := True; end;
  if Pos('AetherMax', RefText) > 0 then begin Emit('generic function AetherMax<T>(const A, B: T): T;'); EmittedAny := True; end;
  if Pos('AetherClamp', RefText) > 0 then begin Emit('generic function AetherClamp<T>(const V, Lo, Hi: T): T;'); EmittedAny := True; end;
  if Pos('AetherStrTrim', RefText) > 0 then begin Emit('function AetherStrTrim(const S: string): string;'); EmittedAny := True; end;
  if Pos('AetherUpperCase', RefText) > 0 then begin Emit('function AetherUpperCase(const S: string): string;'); EmittedAny := True; end;
  if Pos('AetherLowerCase', RefText) > 0 then begin Emit('function AetherLowerCase(const S: string): string;'); EmittedAny := True; end;
  if Pos('AetherStartsWith', RefText) > 0 then begin Emit('function AetherStartsWith(const S, Prefix: string): Boolean;'); EmittedAny := True; end;
  if Pos('AetherEndsWith', RefText) > 0 then begin Emit('function AetherEndsWith(const S, Suffix: string): Boolean;'); EmittedAny := True; end;
  if Pos('AetherStrContains', RefText) > 0 then begin Emit('function AetherStrContains(const S, Sub: string): Boolean;'); EmittedAny := True; end;
  if Pos('AetherIndexOf', RefText) > 0 then begin Emit('function AetherIndexOf(const S, Sub: string): Int32;'); EmittedAny := True; end;
  if Pos('AetherStrReplace', RefText) > 0 then begin Emit('function AetherStrReplace(const S, OldStr, NewStr: string): string;'); EmittedAny := True; end;
  if Pos('AetherStrSplit', RefText) > 0 then begin Emit('function AetherStrSplit(const S, Sep: string): TAetherDyn_String;'); EmittedAny := True; end;
  if Pos('AetherStrJoin', RefText) > 0 then begin Emit('function AetherStrJoin(const Parts: TAetherDyn_String; const Sep: string): string;'); EmittedAny := True; end;
  if Pos('AetherPadLeft', RefText) > 0 then begin Emit('function AetherPadLeft(const S: string; Width: Int32; const Pad: string): string;'); EmittedAny := True; end;
  if Pos('AetherPadRight', RefText) > 0 then begin Emit('function AetherPadRight(const S: string; Width: Int32; const Pad: string): string;'); EmittedAny := True; end;
  if Pos('AetherRepeatStr', RefText) > 0 then begin Emit('function AetherRepeatStr(const S: string; Count: Int32): string;'); EmittedAny := True; end;
  if Pos('AetherStrToFloat', RefText) > 0 then begin Emit('function AetherStrToFloat(const S: string): Double;'); EmittedAny := True; end;
  if Pos('AetherTryStrToInt', RefText) > 0 then begin Emit('function AetherTryStrToInt(const S: string): TAetherOption;'); EmittedAny := True; end;
  if Pos('AetherTryStrToFloat', RefText) > 0 then begin Emit('function AetherTryStrToFloat(const S: string): TAetherOption;'); EmittedAny := True; end;
  if Pos('AetherRound', RefText) > 0 then begin Emit('function AetherRound(V: Double): Double;'); EmittedAny := True; end;
  if Pos('AetherRandomInt', RefText) > 0 then begin Emit('function AetherRandomInt(MinV, MaxV: Int32): Int32;'); EmittedAny := True; end;
  if Pos('AetherRandomFloat', RefText) > 0 then begin Emit('function AetherRandomFloat(): Double;'); EmittedAny := True; end;
  if Pos('AetherReadLn', RefText) > 0 then begin Emit('function AetherReadLn(): string;'); EmittedAny := True; end;
  if Pos('AetherGetEnv', RefText) > 0 then begin Emit('function AetherGetEnv(const AName: string): string;'); EmittedAny := True; end;
  if Pos('AetherSetEnv', RefText) > 0 then begin Emit('function AetherSetEnv(const AName, AVal: string): Boolean;'); EmittedAny := True; end;
  if NeedFileIO then
  begin
    Emit('function AetherFileExists(const APath: string): Boolean;');
    Emit('function AetherReadFile(const APath: string): string;');
    Emit('function AetherWriteFile(const APath: string; const AContent: string): Boolean;');
    Emit('function AetherCreateDir(const APath: string): Boolean;');
    Emit('function AetherRemoveDir(const APath: string): Boolean;');
    Emit('function AetherDeleteFile(const APath: string): Boolean;');
    Emit('function AetherDirExists(const APath: string): Boolean;');
    Emit('function AetherFileSize(const APath: string): {$IFDEF PAS2JS}NativeInt{$ELSE}Int64{$ENDIF};');
    if Pos('AetherListDir', RefText) > 0 then Emit('function AetherListDir(const APath: string): TAetherDyn_String;');
    if Pos('AetherCopyFile', RefText) > 0 then Emit('function AetherCopyFile(const ASrc, ADst: string): Boolean;');
    if Pos('AetherRenameFile', RefText) > 0 then Emit('function AetherRenameFile(const AOld, ANew: string): Boolean;');
    EmittedAny := True;
  end;
  if Pos('AetherBoolToStr', RefText) > 0 then begin Emit('function AetherBoolToStr(B: Boolean): string;'); EmittedAny := True; end;
  if Pos('AetherFloatToStr', RefText) > 0 then begin Emit('function AetherFloatToStr(AVal: Double): string;'); EmittedAny := True; end;
  if NeedJson then
  begin
    Emit('function AetherJsonExtractRaw(const Json, Key: string): string;');
    Emit('function AetherJsonGetStr(const Json, Key: string): string;');
    Emit('function AetherJsonGetInt(const Json, Key: string): Int32;');
    Emit('function AetherJsonGetFloat(const Json, Key: string): Double;');
    Emit('function AetherJsonGetBool(const Json, Key: string): Boolean;');
    Emit('function AetherJsonGetChar(const Json, Key: string): Char;');
    Emit('function AetherJsonHasValue(const Json, Key: string): Boolean;');
    Emit('function AetherJsonGetObj(const Json, Key: string): string;');
    EmittedAny := True;
  end;
  if Pos('AetherGetNanoseconds', RefText) > 0 then begin Emit('function AetherGetNanoseconds: {$IFDEF PAS2JS}Double{$ELSE}QWord{$ENDIF};'); EmittedAny := True; end;
  if Pos('AetherSleepMs', RefText) > 0 then begin Emit('procedure AetherSleepMs(AMs: Cardinal);'); EmittedAny := True; end;
  if NeedSockets then
  begin
    Emit('function AetherSocketCreate(): LongInt;');
    Emit('function AetherSocketListen(Port: Word; Backlog: LongInt): LongInt;');
    Emit('function AetherSocketAccept(ListenFd: LongInt): LongInt;');
    Emit('function AetherSocketConnect(const Host: String; Port: Word): LongInt;');
    Emit('function AetherSocketSend(Fd: LongInt; const Data: String): LongInt;');
    Emit('function AetherSocketRecv(Fd: LongInt; MaxLen: LongInt): String;');
    Emit('procedure AetherSocketClose(Fd: LongInt);');
    EmittedAny := True;
  end;
  if EmittedAny then Emit('');
end;

procedure TAetherEmitterPascal.EmitRuntimeHelpersImplementation(const RefText: string);
var
  NeedResult, NeedOption, NeedFileIO, NeedJson, NeedSockets, HadPop: Boolean;
begin
  NeedResult := (Pos('AetherOk(', RefText) > 0) or (Pos('AetherErr(', RefText) > 0);
  NeedOption := (Pos('AetherSome(', RefText) > 0) or (Pos('AetherNone(', RefText) > 0) or
                (Pos('AetherTryStrToInt', RefText) > 0) or (Pos('AetherTryStrToFloat', RefText) > 0);
  NeedFileIO := (Pos('AetherFileExists', RefText) > 0) or (Pos('AetherReadFile', RefText) > 0) or
                (Pos('AetherWriteFile', RefText) > 0) or (Pos('AetherCreateDir', RefText) > 0) or
                (Pos('AetherRemoveDir', RefText) > 0) or (Pos('AetherDeleteFile', RefText) > 0) or
                (Pos('AetherDirExists', RefText) > 0) or (Pos('AetherFileSize', RefText) > 0) or
                (Pos('AetherListDir', RefText) > 0) or (Pos('AetherCopyFile', RefText) > 0) or
                (Pos('AetherRenameFile', RefText) > 0);
  NeedJson := (Pos('AetherJson', RefText) > 0);
  NeedSockets := (Pos('AetherSocket', RefText) > 0);

  if NeedResult then
  begin
    Emit('function AetherOk(const V: Double): TResultDoubleError; overload;');
    Emit('begin Result := Default(TResultDoubleError); Result.is_ok := True; Result.is_err := False; Result.value := V; end;');
    Emit('');
    Emit('function AetherOk(const V: String): TResultDoubleError; overload;');
    Emit('begin Result := Default(TResultDoubleError); Result.is_ok := True; Result.is_err := False; Result.str_val := V; end;');
    Emit('');
    Emit('function AetherOk(const V: Boolean): TResultDoubleError; overload;');
    Emit('begin Result := Default(TResultDoubleError); Result.is_ok := True; Result.is_err := False; if V then Result.value := 1 else Result.value := 0; end;');
    Emit('');
    Emit('function AetherErr(const E: Integer): TResultDoubleError; overload;');
    Emit('begin Result := Default(TResultDoubleError); Result.is_ok := False; Result.is_err := True; Result.error := E; end;');
    Emit('');
    Emit('function AetherErr(const E: String): TResultDoubleError; overload;');
    Emit('begin Result := Default(TResultDoubleError); Result.is_ok := False; Result.is_err := True; Result.err_str := E; end;');
    Emit('');
  end;

  if NeedOption then
  begin
    Emit('function AetherSome(const V: Double): TAetherOption; overload;');
    Emit('begin Result.is_some := True; Result.is_none := False; Result.num_val := V; Result.str_val := ''''; end;');
    Emit('');
    Emit('function AetherSome(const V: String): TAetherOption; overload;');
    Emit('begin Result.is_some := True; Result.is_none := False; Result.num_val := 0; Result.str_val := V; end;');
    Emit('');
    Emit('function AetherSome(const V: Boolean): TAetherOption; overload;');
    Emit('begin Result.is_some := True; Result.is_none := False; if V then Result.num_val := 1 else Result.num_val := 0; Result.str_val := ''''; end;');
    Emit('');
    Emit('function AetherNone(): TAetherOption;');
    Emit('begin Result.is_some := False; Result.is_none := True; Result.num_val := 0; Result.str_val := ''''; end;');
    Emit('');
  end;

  HadPop := False;
  if Pos('AetherDynPop_Int8', RefText) > 0 then begin Emit('function AetherDynPop_Int8(var A: TAetherDyn_Int8): Int8; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'); HadPop := True; end;
  if Pos('AetherDynPop_Int16', RefText) > 0 then begin Emit('function AetherDynPop_Int16(var A: TAetherDyn_Int16): Int16; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'); HadPop := True; end;
  if Pos('AetherDynPop_Int32', RefText) > 0 then begin Emit('function AetherDynPop_Int32(var A: TAetherDyn_Int32): Int32; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'); HadPop := True; end;
  if Pos('AetherDynPop_Int64', RefText) > 0 then begin Emit('function AetherDynPop_Int64(var A: TAetherDyn_Int64): Int64; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'); HadPop := True; end;
  if Pos('AetherDynPop_UInt8', RefText) > 0 then begin Emit('function AetherDynPop_UInt8(var A: TAetherDyn_UInt8): UInt8; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'); HadPop := True; end;
  if Pos('AetherDynPop_UInt16', RefText) > 0 then begin Emit('function AetherDynPop_UInt16(var A: TAetherDyn_UInt16): UInt16; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'); HadPop := True; end;
  if Pos('AetherDynPop_UInt32', RefText) > 0 then begin Emit('function AetherDynPop_UInt32(var A: TAetherDyn_UInt32): UInt32; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'); HadPop := True; end;
  if Pos('AetherDynPop_UInt64', RefText) > 0 then begin Emit('function AetherDynPop_UInt64(var A: TAetherDyn_UInt64): UInt64; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'); HadPop := True; end;
  if Pos('AetherDynPop_Float32', RefText) > 0 then begin Emit('function AetherDynPop_Float32(var A: TAetherDyn_Float32): Single; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'); HadPop := True; end;
  if Pos('AetherDynPop_Float64', RefText) > 0 then begin Emit('function AetherDynPop_Float64(var A: TAetherDyn_Float64): Double; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'); HadPop := True; end;
  if Pos('AetherDynPop_Bool', RefText) > 0 then begin Emit('function AetherDynPop_Bool(var A: TAetherDyn_Bool): Boolean; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'); HadPop := True; end;
  if Pos('AetherDynPop_Char', RefText) > 0 then begin Emit('function AetherDynPop_Char(var A: TAetherDyn_Char): Char; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'); HadPop := True; end;
  if Pos('AetherDynPop_String', RefText) > 0 then begin Emit('function AetherDynPop_String(var A: TAetherDyn_String): String; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'); HadPop := True; end;
  if Pos('AetherDynPop_Pointer', RefText) > 0 then begin Emit('function AetherDynPop_Pointer(var A: TAetherDyn_Pointer): Pointer; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'); HadPop := True; end;
  if HadPop then Emit('');

  if Pos('AetherIfThen', RefText) > 0 then
  begin
    Emit('generic function AetherIfThen<T>(Cond: Boolean; const A, B: T): T;');
    Emit('begin');
    Emit('  if Cond then Result := A else Result := B;');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherMin', RefText) > 0 then
  begin
    Emit('generic function AetherMin<T>(const A, B: T): T;');
    Emit('begin');
    Emit('  if A < B then Result := A else Result := B;');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherMax', RefText) > 0 then
  begin
    Emit('generic function AetherMax<T>(const A, B: T): T;');
    Emit('begin');
    Emit('  if A > B then Result := A else Result := B;');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherClamp', RefText) > 0 then
  begin
    Emit('generic function AetherClamp<T>(const V, Lo, Hi: T): T;');
    Emit('begin');
    Emit('  if V < Lo then Result := Lo else if V > Hi then Result := Hi else Result := V;');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherStrTrim', RefText) > 0 then
  begin
    Emit('function AetherStrTrim(const S: string): string;');
    Emit('begin');
    Emit('  Result := SysUtils.Trim(S);');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherUpperCase', RefText) > 0 then
  begin
    Emit('function AetherUpperCase(const S: string): string;');
    Emit('begin');
    Emit('  Result := SysUtils.UpperCase(S);');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherLowerCase', RefText) > 0 then
  begin
    Emit('function AetherLowerCase(const S: string): string;');
    Emit('begin');
    Emit('  Result := SysUtils.LowerCase(S);');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherStartsWith', RefText) > 0 then
  begin
    Emit('function AetherStartsWith(const S, Prefix: string): Boolean;');
    Emit('begin');
    Emit('  Result := (Length(Prefix) <= Length(S)) and (Copy(S, 1, Length(Prefix)) = Prefix);');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherEndsWith', RefText) > 0 then
  begin
    Emit('function AetherEndsWith(const S, Suffix: string): Boolean;');
    Emit('begin');
    Emit('  Result := (Length(Suffix) <= Length(S)) and (Copy(S, Length(S) - Length(Suffix) + 1, Length(Suffix)) = Suffix);');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherStrContains', RefText) > 0 then
  begin
    Emit('function AetherStrContains(const S, Sub: string): Boolean;');
    Emit('begin');
    Emit('  if Sub = '''' then Exit(True);');
    Emit('  Result := Pos(Sub, S) > 0;');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherIndexOf', RefText) > 0 then
  begin
    Emit('function AetherIndexOf(const S, Sub: string): Int32;');
    Emit('begin');
    Emit('  if Sub = '''' then Exit(0);');
    Emit('  Result := Int32(Pos(Sub, S)) - 1;');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherStrReplace', RefText) > 0 then
  begin
    Emit('function AetherStrReplace(const S, OldStr, NewStr: string): string;');
    Emit('begin');
    Emit('  if OldStr = '''' then Exit(S);');
    Emit('  Result := SysUtils.StringReplace(S, OldStr, NewStr, [rfReplaceAll]);');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherStrSplit', RefText) > 0 then
  begin
    Emit('function AetherStrSplit(const S, Sep: string): TAetherDyn_String;');
    Emit('var I, StartPos, SepLen, P, CurLen: Integer;');
    Emit('begin');
    Emit('  SetLength(Result, 0);');
    Emit('  if Sep = '''' then');
    Emit('  begin');
    Emit('    SetLength(Result, Length(S));');
    Emit('    for I := 1 to Length(S) do Result[I - 1] := S[I];');
    Emit('    Exit;');
    Emit('  end;');
    Emit('  SepLen := Length(Sep);');
    Emit('  StartPos := 1;');
    Emit('  while True do');
    Emit('  begin');
    Emit('    P := Pos(Sep, Copy(S, StartPos, Length(S) - StartPos + 1));');
    Emit('    CurLen := Length(Result);');
    Emit('    SetLength(Result, CurLen + 1);');
    Emit('    if P = 0 then');
    Emit('    begin');
    Emit('      Result[CurLen] := Copy(S, StartPos, Length(S) - StartPos + 1);');
    Emit('      Break;');
    Emit('    end;');
    Emit('    Result[CurLen] := Copy(S, StartPos, P - 1);');
    Emit('    StartPos := StartPos + P - 1 + SepLen;');
    Emit('  end;');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherStrJoin', RefText) > 0 then
  begin
    Emit('function AetherStrJoin(const Parts: TAetherDyn_String; const Sep: string): string;');
    Emit('var I: Integer;');
    Emit('begin');
    Emit('  Result := '''';');
    Emit('  for I := 0 to High(Parts) do');
    Emit('  begin');
    Emit('    if I > 0 then Result := Result + Sep;');
    Emit('    Result := Result + Parts[I];');
    Emit('  end;');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherPadLeft', RefText) > 0 then
  begin
    Emit('function AetherPadLeft(const S: string; Width: Int32; const Pad: string): string;');
    Emit('var P, Prefix: string; NeedLen: Integer;');
    Emit('begin');
    Emit('  if Length(S) >= Width then Exit(S);');
    Emit('  if Pad = '''' then P := '' '' else P := Pad;');
    Emit('  NeedLen := Width - Length(S);');
    Emit('  Prefix := '''';');
    Emit('  while Length(Prefix) < NeedLen do Prefix := Prefix + P;');
    Emit('  if Length(Prefix) > NeedLen then Prefix := Copy(Prefix, 1, NeedLen);');
    Emit('  Result := Prefix + S;');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherPadRight', RefText) > 0 then
  begin
    Emit('function AetherPadRight(const S: string; Width: Int32; const Pad: string): string;');
    Emit('var P, Suffix: string; NeedLen: Integer;');
    Emit('begin');
    Emit('  if Length(S) >= Width then Exit(S);');
    Emit('  if Pad = '''' then P := '' '' else P := Pad;');
    Emit('  NeedLen := Width - Length(S);');
    Emit('  Suffix := '''';');
    Emit('  while Length(Suffix) < NeedLen do Suffix := Suffix + P;');
    Emit('  if Length(Suffix) > NeedLen then Suffix := Copy(Suffix, 1, NeedLen);');
    Emit('  Result := S + Suffix;');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherRepeatStr', RefText) > 0 then
  begin
    Emit('function AetherRepeatStr(const S: string; Count: Int32): string;');
    Emit('var I: Integer;');
    Emit('begin');
    Emit('  Result := '''';');
    Emit('  if (Count <= 0) or (S = '''') then Exit;');
    Emit('  for I := 1 to Count do Result := Result + S;');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherStrToFloat', RefText) > 0 then
  begin
    Emit('function AetherStrToFloat(const S: string): Double;');
    Emit('var FS: TFormatSettings;');
    Emit('begin');
    Emit('  FS := DefaultFormatSettings;');
    Emit('  FS.DecimalSeparator := ''.'';');
    Emit('  Result := SysUtils.StrToFloatDef(SysUtils.Trim(S), 0.0, FS);');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherTryStrToInt', RefText) > 0 then
  begin
    Emit('function AetherTryStrToInt(const S: string): TAetherOption;');
    Emit('var V: LongInt; T: string;');
    Emit('begin');
    Emit('  T := SysUtils.Trim(S);');
    Emit('  if (T <> '''') and SysUtils.TryStrToInt(T, V) then Result := AetherSome(Double(V))');
    Emit('  else Result := AetherNone();');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherTryStrToFloat', RefText) > 0 then
  begin
    Emit('function AetherTryStrToFloat(const S: string): TAetherOption;');
    Emit('var V: Double; T: string; FS: TFormatSettings;');
    Emit('begin');
    Emit('  T := SysUtils.Trim(S);');
    Emit('  FS := DefaultFormatSettings;');
    Emit('  FS.DecimalSeparator := ''.'';');
    Emit('  if (T <> '''') and SysUtils.TryStrToFloat(T, V, FS) then Result := AetherSome(V)');
    Emit('  else Result := AetherNone();');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherRound', RefText) > 0 then
  begin
    Emit('function AetherRound(V: Double): Double;');
    Emit('begin');
    Emit('  if V >= 0.0 then Result := Int(V + 0.5) else Result := -Int(-V + 0.5);');
    Emit('end;');
    Emit('');
  end;

  if (Pos('AetherRandomInt', RefText) > 0) or (Pos('AetherRandomFloat', RefText) > 0) then
  begin
    Emit('var GAetherRandSeeded: Boolean = False;');
    Emit('');
  end;

  if Pos('AetherRandomInt', RefText) > 0 then
  begin
    Emit('function AetherRandomInt(MinV, MaxV: Int32): Int32;');
    Emit('var Lo, Hi: Int32; Span: Int64;');
    Emit('begin');
    Emit('  if not GAetherRandSeeded then begin System.Randomize; GAetherRandSeeded := True; end;');
    Emit('  if MinV <= MaxV then begin Lo := MinV; Hi := MaxV; end else begin Lo := MaxV; Hi := MinV; end;');
    Emit('  if Lo = Hi then Exit(Lo);');
    Emit('  Span := Int64(Hi) - Int64(Lo) + 1;');
    Emit('  Result := Lo + Int32(System.Random(Span));');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherRandomFloat', RefText) > 0 then
  begin
    Emit('function AetherRandomFloat(): Double;');
    Emit('begin');
    Emit('  if not GAetherRandSeeded then begin System.Randomize; GAetherRandSeeded := True; end;');
    Emit('  Result := System.Random;');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherReadLn', RefText) > 0 then
  begin
    Emit('function AetherReadLn(): string;');
    Emit('begin');
    Emit('  {$IFNDEF PAS2JS}System.ReadLn(Result);{$ELSE}Result := '''';{$ENDIF}');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherGetEnv', RefText) > 0 then
  begin
    Emit('function AetherGetEnv(const AName: string): string;');
    Emit('begin');
    Emit('  {$IFNDEF PAS2JS}Result := SysUtils.GetEnvironmentVariable(AName);{$ELSE}Result := '''';{$ENDIF}');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherSetEnv', RefText) > 0 then
  begin
    Emit('{$IFNDEF PAS2JS}{$IFNDEF WINDOWS}');
    Emit('function aether_c_setenv(name, val: PAnsiChar; overwrite: LongInt): LongInt; cdecl; external ''c'' name ''setenv'';');
    Emit('{$ENDIF}{$ENDIF}');
    Emit('function AetherSetEnv(const AName, AVal: string): Boolean;');
    Emit('begin');
    Emit('  {$IFDEF PAS2JS}Result := False;');
    Emit('  {$ELSE}{$IFDEF WINDOWS}');
    Emit('  Result := Windows.SetEnvironmentVariableA(PAnsiChar(AnsiString(AName)), PAnsiChar(AnsiString(AVal)));');
    Emit('  {$ELSE}');
    Emit('  Result := aether_c_setenv(PAnsiChar(AnsiString(AName)), PAnsiChar(AnsiString(AVal)), 1) = 0;');
    Emit('  {$ENDIF}{$ENDIF}');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherCharAt', RefText) > 0 then
  begin
    Emit('function AetherCharAt(const S: string; Index: Cardinal): string;');
    Emit('begin');
    Emit('  if (Index + 1 <= Cardinal(Length(S))) then Result := S[Index + 1] else Result := '''';');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherSubstring', RefText) > 0 then
  begin
    Emit('function AetherSubstring(const S: string; Start, Len: Cardinal): string;');
    Emit('begin');
    Emit('  Result := Copy(S, Start + 1, Len);');
    Emit('end;');
    Emit('');
  end;

  if NeedFileIO then
  begin
    Emit('{$IFNDEF PAS2JS}');
    Emit('function AetherFileExists(const APath: string): Boolean;');
    Emit('begin');
    Emit('  Result := SysUtils.FileExists(APath);');
    Emit('end;');
    Emit('');
    Emit('function AetherReadFile(const APath: string): string;');
    Emit('var');
    Emit('  F: TextFile;');
    Emit('  Line, Content: string;');
    Emit('begin');
    Emit('  Content := '''';');
    Emit('  if not SysUtils.FileExists(APath) then Exit('''');');
    Emit('  AssignFile(F, APath);');
    Emit('  {$I-} Reset(F); {$I+}');
    Emit('  if IOResult <> 0 then Exit('''');');
    Emit('  while not Eof(F) do begin ReadLn(F, Line); Content := Content + Line + LineEnding; end;');
    Emit('  CloseFile(F);');
    Emit('  Result := Content;');
    Emit('end;');
    Emit('');
    Emit('function AetherWriteFile(const APath: string; const AContent: string): Boolean;');
    Emit('var');
    Emit('  F: TextFile;');
    Emit('begin');
    Emit('  AssignFile(F, APath);');
    Emit('  {$I-} Rewrite(F); {$I+}');
    Emit('  if IOResult <> 0 then Exit(False);');
    Emit('  Write(F, AContent);');
    Emit('  CloseFile(F);');
    Emit('  Result := True;');
    Emit('end;');
    Emit('');
    Emit('function AetherCreateDir(const APath: string): Boolean;');
    Emit('begin Result := SysUtils.CreateDir(APath); end;');
    Emit('');
    Emit('function AetherRemoveDir(const APath: string): Boolean;');
    Emit('begin Result := SysUtils.RemoveDir(APath); end;');
    Emit('');
    Emit('function AetherDeleteFile(const APath: string): Boolean;');
    Emit('begin Result := SysUtils.DeleteFile(APath); end;');
    Emit('');
    Emit('function AetherDirExists(const APath: string): Boolean;');
    Emit('begin Result := SysUtils.DirectoryExists(APath); end;');
    Emit('');
    Emit('function AetherFileSize(const APath: string): Int64;');
    Emit('var H: THandle;');
    Emit('begin');
    Emit('  Result := -1;');
    Emit('  H := FileOpen(APath, fmOpenRead or fmShareDenyNone);');
    Emit('  if H <> feInvalidHandle then begin Result := FileSeek(H, Int64(0), 2); FileClose(H); end;');
    Emit('end;');
    if Pos('AetherListDir', RefText) > 0 then
    begin
      Emit('');
      Emit('function AetherListDir(const APath: string): TAetherDyn_String;');
      Emit('var SR: TSearchRec; Pattern: string; N: Integer;');
      Emit('begin');
      Emit('  SetLength(Result, 0);');
      Emit('  if APath = '''' then Pattern := ''*'' else Pattern := SysUtils.IncludeTrailingPathDelimiter(APath) + ''*'';');
      Emit('  if SysUtils.FindFirst(Pattern, faAnyFile, SR) = 0 then');
      Emit('  begin');
      Emit('    repeat');
      Emit('      if (SR.Name <> ''.'') and (SR.Name <> ''..'') then');
      Emit('      begin');
      Emit('        N := Length(Result);');
      Emit('        SetLength(Result, N + 1);');
      Emit('        Result[N] := SR.Name;');
      Emit('      end;');
      Emit('    until SysUtils.FindNext(SR) <> 0;');
      Emit('    SysUtils.FindClose(SR);');
      Emit('  end;');
      Emit('end;');
    end;
    if Pos('AetherCopyFile', RefText) > 0 then
    begin
      Emit('');
      Emit('function AetherCopyFile(const ASrc, ADst: string): Boolean;');
      Emit('var HS, HD: THandle; Buf: array[0..4095] of Byte; R, W: LongInt;');
      Emit('begin');
      Emit('  Result := False;');
      Emit('  HS := FileOpen(ASrc, fmOpenRead or fmShareDenyNone);');
      Emit('  if HS = feInvalidHandle then Exit;');
      Emit('  HD := FileCreate(ADst);');
      Emit('  if HD = feInvalidHandle then begin FileClose(HS); Exit; end;');
      Emit('  Result := True;');
      Emit('  repeat');
      Emit('    R := FileRead(HS, Buf[0], SizeOf(Buf));');
      Emit('    if R > 0 then');
      Emit('    begin');
      Emit('      W := FileWrite(HD, Buf[0], R);');
      Emit('      if W <> R then begin Result := False; Break; end;');
      Emit('    end;');
      Emit('  until R <= 0;');
      Emit('  FileClose(HD);');
      Emit('  FileClose(HS);');
      Emit('end;');
    end;
    if Pos('AetherRenameFile', RefText) > 0 then
    begin
      Emit('');
      Emit('function AetherRenameFile(const AOld, ANew: string): Boolean;');
      Emit('begin Result := SysUtils.RenameFile(AOld, ANew); end;');
    end;
    Emit('{$ELSE}');
    Emit('function AetherFileExists(const APath: string): Boolean; begin Result := False; end;');
    Emit('function AetherReadFile(const APath: string): string; begin Result := ''''; end;');
    Emit('function AetherWriteFile(const APath: string; const AContent: string): Boolean; begin Result := False; end;');
    Emit('function AetherCreateDir(const APath: string): Boolean; begin Result := False; end;');
    Emit('function AetherRemoveDir(const APath: string): Boolean; begin Result := False; end;');
    Emit('function AetherDeleteFile(const APath: string): Boolean; begin Result := False; end;');
    Emit('function AetherDirExists(const APath: string): Boolean; begin Result := False; end;');
    Emit('function AetherFileSize(const APath: string): {$IFDEF PAS2JS}NativeInt{$ELSE}Int64{$ENDIF}; begin Result := -1; end;');
    if Pos('AetherListDir', RefText) > 0 then Emit('function AetherListDir(const APath: string): TAetherDyn_String; begin SetLength(Result, 0); end;');
    if Pos('AetherCopyFile', RefText) > 0 then Emit('function AetherCopyFile(const ASrc, ADst: string): Boolean; begin Result := False; end;');
    if Pos('AetherRenameFile', RefText) > 0 then Emit('function AetherRenameFile(const AOld, ANew: string): Boolean; begin Result := False; end;');
    Emit('{$ENDIF}');
    Emit('');
  end;

  if Pos('AetherBoolToStr', RefText) > 0 then
  begin
    Emit('function AetherBoolToStr(B: Boolean): string;');
    Emit('begin if B then Result := ''true'' else Result := ''false''; end;');
    Emit('');
  end;

  if Pos('AetherFloatToStr', RefText) > 0 then
  begin
    Emit('function AetherFloatToStr(AVal: Double): string;');
    Emit('var FS: TFormatSettings;');
    Emit('begin');
    Emit('  FS := DefaultFormatSettings;');
    Emit('  FS.DecimalSeparator := ''.'';');
    Emit('  Result := FloatToStr(AVal, FS);');
    Emit('end;');
    Emit('');
  end;

  if NeedJson then
  begin
    Emit('function AetherJsonExtractRaw(const Json, Key: string): string;');
    Emit('var');
    Emit('  Pattern: string;');
    Emit('  P, SearchPos, JLen, Depth, StartPos: Integer;');
    Emit('  InStr: Boolean;');
    Emit('begin');
    Emit('  Pattern := ''"'' + Key + ''"'';');
    Emit('  SearchPos := 1;');
    Emit('  JLen := Length(Json);');
    Emit('  while SearchPos <= JLen do');
    Emit('  begin');
    Emit('    P := Pos(Pattern, Copy(Json, SearchPos, JLen - SearchPos + 1));');
    Emit('    if P = 0 then Exit('''');');
    Emit('    P := SearchPos + P - 1 + Length(Pattern);');
    Emit('    while (P <= JLen) and (Json[P] in ['' '', #9, #10, #13]) do Inc(P);');
    Emit('    if (P <= JLen) and (Json[P] = '':'') then');
    Emit('    begin');
    Emit('      Inc(P);');
    Emit('      while (P <= JLen) and (Json[P] in ['' '', #9, #10, #13]) do Inc(P);');
    Emit('      if P > JLen then Exit('''');');
    Emit('      if Json[P] = ''"'' then');
    Emit('      begin');
    Emit('        StartPos := P; Inc(P);');
    Emit('        while P <= JLen do');
    Emit('        begin');
    Emit('          if (Json[P] = ''"'') and ((P = StartPos + 1) or (Json[P - 1] <> ''\'')) then');
    Emit('            Exit(Copy(Json, StartPos, P - StartPos + 1));');
    Emit('          Inc(P);');
    Emit('        end;');
    Emit('        Exit(Copy(Json, StartPos, JLen - StartPos + 1));');
    Emit('      end');
    Emit('      else if Json[P] = ''{'' then');
    Emit('      begin');
    Emit('        StartPos := P; Depth := 0; InStr := False;');
    Emit('        while P <= JLen do');
    Emit('        begin');
    Emit('          if (Json[P] = ''"'') and ((P = 1) or (Json[P - 1] <> ''\'')) then InStr := not InStr');
    Emit('          else if not InStr then');
    Emit('          begin');
    Emit('            if Json[P] = ''{'' then Inc(Depth)');
    Emit('            else if Json[P] = ''}'' then begin Dec(Depth); if Depth = 0 then Exit(Copy(Json, StartPos, P - StartPos + 1)); end;');
    Emit('          end;');
    Emit('          Inc(P);');
    Emit('        end;');
    Emit('        Exit(Copy(Json, StartPos, JLen - StartPos + 1));');
    Emit('      end');
    Emit('      else');
    Emit('      begin');
    Emit('        StartPos := P;');
    Emit('        while (P <= JLen) and not (Json[P] in ['','', ''}'', '']'', '' '', #9, #10, #13]) do Inc(P);');
    Emit('        Exit(Copy(Json, StartPos, P - StartPos));');
    Emit('      end;');
    Emit('    end;');
    Emit('    SearchPos := P;');
    Emit('  end;');
    Emit('  Result := '''';');
    Emit('end;');
    Emit('');
    Emit('function AetherJsonGetStr(const Json, Key: string): string;');
    Emit('begin');
    Emit('  Result := AetherJsonExtractRaw(Json, Key);');
    Emit('  if (Length(Result) >= 2) and (Result[1] = ''"'') and (Result[Length(Result)] = ''"'') then');
    Emit('    Result := Copy(Result, 2, Length(Result) - 2);');
    Emit('end;');
    Emit('');
    Emit('function AetherJsonGetInt(const Json, Key: string): Int32;');
    Emit('begin');
    Emit('  Result := StrToIntDef(AetherJsonExtractRaw(Json, Key), 0);');
    Emit('end;');
    Emit('');
    Emit('function AetherJsonGetFloat(const Json, Key: string): Double;');
    Emit('var FS: TFormatSettings;');
    Emit('begin');
    Emit('  FS := DefaultFormatSettings;');
    Emit('  FS.DecimalSeparator := ''.'';');
    Emit('  Result := StrToFloatDef(AetherJsonExtractRaw(Json, Key), 0.0, FS);');
    Emit('end;');
    Emit('');
    Emit('function AetherJsonGetBool(const Json, Key: string): Boolean;');
    Emit('begin');
    Emit('  Result := SameText(AetherJsonExtractRaw(Json, Key), ''true'');');
    Emit('end;');
    Emit('');
    Emit('function AetherJsonGetChar(const Json, Key: string): Char;');
    Emit('var S: string;');
    Emit('begin');
    Emit('  S := AetherJsonGetStr(Json, Key);');
    Emit('  if Length(S) > 0 then Result := S[1] else Result := #0;');
    Emit('end;');
    Emit('');
    Emit('function AetherJsonHasValue(const Json, Key: string): Boolean;');
    Emit('var Raw: string;');
    Emit('begin');
    Emit('  Raw := AetherJsonExtractRaw(Json, Key);');
    Emit('  Result := (Raw <> '''') and (not SameText(Raw, ''null''));');
    Emit('end;');
    Emit('');
    Emit('function AetherJsonGetObj(const Json, Key: string): string;');
    Emit('begin');
    Emit('  Result := AetherJsonExtractRaw(Json, Key);');
    Emit('end;');
    Emit('');
  end;

  if Pos('AetherGetNanoseconds', RefText) > 0 then
  begin
    Emit('function AetherGetNanoseconds: {$IFDEF PAS2JS}Double{$ELSE}QWord{$ENDIF};');
    Emit('{$IFDEF PAS2JS}');
    Emit('begin Result := 0; end;');
    Emit('{$ELSE}');
    Emit('{$IFDEF WINDOWS}');
    Emit('var Freq, Count: Int64;');
    Emit('begin');
    Emit('  Freq := 0; Count := 0;');
    Emit('  Windows.QueryPerformanceFrequency(Freq);');
    Emit('  Windows.QueryPerformanceCounter(Count);');
    Emit('  if Freq > 0 then Result := QWord((Count * 1000000000) div Freq)');
    Emit('  else Result := QWord(GetTickCount64 * 1000000);');
    Emit('end;');
    Emit('{$ELSE}');
    Emit('begin Result := QWord(GetTickCount64 * 1000000); end;');
    Emit('{$ENDIF}');
    Emit('{$ENDIF}');
    Emit('');
  end;

  if Pos('AetherSleepMs', RefText) > 0 then
  begin
    Emit('procedure AetherSleepMs(AMs: Cardinal);');
    Emit('{$IFDEF PAS2JS}');
    Emit('begin end;');
    Emit('{$ELSE}');
    Emit('begin SysUtils.Sleep(AMs); end;');
    Emit('{$ENDIF}');
    Emit('');
  end;

  if NeedSockets then
  begin
    Emit('{$IFNDEF PAS2JS}');
    Emit('// Native Sockets via FPC Sockets');
    Emit('function AetherSocketCreate(): LongInt;');
    Emit('begin');
    Emit('  Result := Sockets.fpsocket(AF_INET, SOCK_STREAM, 0);');
    Emit('end;');
    Emit('');
    Emit('function AetherSocketListen(Port: Word; Backlog: LongInt): LongInt;');
    Emit('var');
    Emit('  Addr: TInetSockAddr;');
    Emit('  Opt: LongInt;');
    Emit('begin');
    Emit('  Result := Sockets.fpsocket(AF_INET, SOCK_STREAM, 0);');
    Emit('  if Result < 0 then Exit(-1);');
    Emit('  Opt := 1;');
    Emit('  Sockets.fpsetsockopt(Result, SOL_SOCKET, SO_REUSEADDR, @Opt, SizeOf(Opt));');
    Emit('  FillChar(Addr, SizeOf(Addr), 0);');
    Emit('  Addr.sin_family := AF_INET;');
    Emit('  Addr.sin_port := Sockets.htons(Port);');
    Emit('  Addr.sin_addr.s_addr := 0; // INADDR_ANY');
    Emit('  if Sockets.fpbind(Result, @Addr, SizeOf(Addr)) <> 0 then');
    Emit('  begin');
    Emit('    Sockets.CloseSocket(Result);');
    Emit('    Exit(-1);');
    Emit('  end;');
    Emit('  if Sockets.fplisten(Result, Backlog) <> 0 then');
    Emit('  begin');
    Emit('    Sockets.CloseSocket(Result);');
    Emit('    Exit(-1);');
    Emit('  end;');
    Emit('end;');
    Emit('');
    Emit('function AetherSocketAccept(ListenFd: LongInt): LongInt;');
    Emit('var');
    Emit('  Addr: TInetSockAddr;');
    Emit('  AddrLen: LongInt;');
    Emit('begin');
    Emit('  AddrLen := SizeOf(Addr);');
    Emit('  Result := Sockets.fpaccept(ListenFd, @Addr, @AddrLen);');
    Emit('end;');
    Emit('');
    Emit('function AetherSocketConnect(const Host: String; Port: Word): LongInt;');
    Emit('var');
    Emit('  Addr: TInetSockAddr;');
    Emit('begin');
    Emit('  Result := Sockets.fpsocket(AF_INET, SOCK_STREAM, 0);');
    Emit('  if Result < 0 then Exit(-1);');
    Emit('  FillChar(Addr, SizeOf(Addr), 0);');
    Emit('  Addr.sin_family := AF_INET;');
    Emit('  Addr.sin_port := Sockets.htons(Port);');
    Emit('  Addr.sin_addr := Sockets.StrToNetAddr(Host);');
    Emit('  if Sockets.fpconnect(Result, @Addr, SizeOf(Addr)) <> 0 then');
    Emit('  begin');
    Emit('    Sockets.CloseSocket(Result);');
    Emit('    Exit(-1);');
    Emit('  end;');
    Emit('end;');
    Emit('');
    Emit('function AetherSocketSend(Fd: LongInt; const Data: String): LongInt;');
    Emit('begin');
    Emit('  if Length(Data) = 0 then Exit(0);');
    Emit('  Result := Sockets.fpsend(Fd, @Data[1], Length(Data), 0);');
    Emit('end;');
    Emit('');
    Emit('function AetherSocketRecv(Fd: LongInt; MaxLen: LongInt): String;');
    Emit('var');
    Emit('  Buf: array of Char;');
    Emit('  Bytes: LongInt;');
    Emit('begin');
    Emit('  SetLength(Buf, MaxLen);');
    Emit('  Bytes := Sockets.fprecv(Fd, @Buf[0], MaxLen, 0);');
    Emit('  if Bytes > 0 then');
    Emit('    SetString(Result, PChar(@Buf[0]), Bytes)');
    Emit('  else');
    Emit('    Result := '''';');
    Emit('end;');
    Emit('');
    Emit('procedure AetherSocketClose(Fd: LongInt);');
    Emit('begin');
    Emit('  if Fd >= 0 then Sockets.CloseSocket(Fd);');
    Emit('end;');
    Emit('{$ELSE}');
    Emit('function AetherSocketCreate(): LongInt; begin Result := -1; end;');
    Emit('function AetherSocketListen(Port: Word; Backlog: LongInt): LongInt; begin Result := -1; end;');
    Emit('function AetherSocketAccept(ListenFd: LongInt): LongInt; begin Result := -1; end;');
    Emit('function AetherSocketConnect(const Host: String; Port: Word): LongInt; begin Result := -1; end;');
    Emit('function AetherSocketSend(Fd: LongInt; const Data: String): LongInt; begin Result := 0; end;');
    Emit('function AetherSocketRecv(Fd: LongInt; MaxLen: LongInt): String; begin Result := ''''; end;');
    Emit('procedure AetherSocketClose(Fd: LongInt); begin end;');
    Emit('{$ENDIF}');
    Emit('');
  end;
end;

procedure TAetherEmitterPascal.EmitTopologicalTypesAndMonads(const TypeUsed: array of Boolean;
  OptTags, OptInners: TStrings; const OptUsed: array of Boolean;
  ResTags, ResVals, ResErrs: TStrings; const ResUsed: array of Boolean);
var
  ItemKind, ItemIdx: array of Integer;
  ItemKey: array of string;
  ItemDeps: array of TStringList;
  ItemEmitted: array of Boolean;
  Count, I, J, K, Rem, ReadyIdx: Integer;
  Node: TASTNode;
  Rec: TASTRecordDecl;
  Enm: TASTEnumDecl;
  VarN: TASTEnumVariant;
  FnParams2: TStringList;
  FnRet2, FnPSig: string;
  FIdx: Integer;

  procedure AddDepToList(Deps: TStrings; const TStr: string);
  var
    T, InnerT, VT, ET, M, RetT: string;
    POf: Integer;
    FnP: TStringList;
  begin
    T := ResolveAliasType(Trim(TStr));
    if (T = '') or (Pos('^', T) = 1) or (Pos('Box<', T) = 1) or
       (T = 'Int8') or (T = 'Int16') or (T = 'Int32') or (T = 'Int64') or
       (T = 'UInt8') or (T = 'UInt16') or (T = 'UInt32') or (T = 'UInt64') or
       (T = 'Float32') or (T = 'Float64') or (T = 'Bool') or (T = 'Char') or
       (T = 'String') or (T = 'Pointer') then
      Exit;
    FnP := TStringList.Create;
    try
      if SplitFnType(T, FnP, RetT) then
      begin
        Deps.Add('__FN_' + UpperCase(FnTypeTag(T)));
        Exit;
      end;
    finally
      FnP.Free;
    end;
    if Pos('array of ', T) = 1 then
    begin
      InnerT := Trim(Copy(T, 10, Length(T)));
      if not ((InnerT = 'Int8') or (InnerT = 'Int16') or (InnerT = 'Int32') or (InnerT = 'Int64') or
              (InnerT = 'UInt8') or (InnerT = 'UInt16') or (InnerT = 'UInt32') or (InnerT = 'UInt64') or
              (InnerT = 'Float32') or (InnerT = 'Float64') or (InnerT = 'Bool') or (InnerT = 'Char') or
              (InnerT = 'String') or (InnerT = 'Pointer')) then
        Deps.Add('__DYN_' + UpperCase(MangleTypeTag(InnerT)))
      else
        AddDepToList(Deps, InnerT);
      Exit;
    end;
    if Pos('array[', T) = 1 then
    begin
      POf := Pos(' of ', T);
      if POf > 0 then AddDepToList(Deps, Copy(T, POf + 4, Length(T)));
      Exit;
    end;
    if IsMapType(T, VT, ET) then Exit;
    if IsTypedValueOption(T, InnerT) then
    begin
      Deps.Add('__OPT_' + UpperCase(MangleTypeTag(InnerT)));
      Exit;
    end;
    if IsTypedResult(T, VT, ET) then
    begin
      M := MangleTypeTag(VT) + '__' + MangleTypeTag(ET);
      Deps.Add('__RES_' + UpperCase(M));
      Exit;
    end;
    Deps.Add(UpperCase(T));
  end;

  function AllDepsEmitted(Idx: Integer): Boolean;
  var
    D, M: Integer;
    DepKey: string;
  begin
    Result := True;
    for D := 0 to ItemDeps[Idx].Count - 1 do
    begin
      DepKey := ItemDeps[Idx][D];
      if DepKey = ItemKey[Idx] then Continue;
      for M := 0 to Count - 1 do
        if (not ItemEmitted[M]) and (ItemKey[M] = DepKey) then
          Exit(False);
    end;
  end;

  procedure AppendItem(Kind, Idx: Integer; const Key: string);
  begin
    SetLength(ItemKind, Count + 1);
    SetLength(ItemIdx, Count + 1);
    SetLength(ItemKey, Count + 1);
    SetLength(ItemDeps, Count + 1);
    SetLength(ItemEmitted, Count + 1);
    ItemKind[Count] := Kind;
    ItemIdx[Count] := Idx;
    ItemKey[Count] := Key;
    ItemDeps[Count] := TStringList.Create;
    ItemEmitted[Count] := False;
    Inc(Count);
  end;

begin
  Count := 0;
  for I := 0 to FModule.Types.Count - 1 do
  begin
    if not TypeUsed[I] then Continue;
    Node := TASTNode(FModule.Types[I]);
    if (Node is TASTRecordDecl) and (TASTRecordDecl(Node).GenericParams.Count > 0) then Continue;
    if Node is TASTMapDecl then Continue;
    if Node is TASTRecordDecl then
    begin
      Rec := TASTRecordDecl(Node);
      AppendItem(0, I, UpperCase(Rec.Name));
      for J := 0 to Rec.Fields.Count - 1 do
        AddDepToList(ItemDeps[Count - 1], TASTRecordField(Rec.Fields[J]).TypeName);
    end
    else if Node is TASTEnumDecl then
    begin
      Enm := TASTEnumDecl(Node);
      AppendItem(0, I, UpperCase(Enm.Name));
      if Enm.HasPayload then
        for J := 0 to Enm.Variants.Count - 1 do
        begin
          VarN := TASTEnumVariant(Enm.Variants[J]);
          for K := 0 to VarN.Fields.Count - 1 do
            AddDepToList(ItemDeps[Count - 1], TASTRecordField(VarN.Fields[K]).TypeName);
        end;
    end
    else if Node is TASTArrayDecl then
    begin
      AppendItem(0, I, UpperCase(TASTArrayDecl(Node).Name));
      AddDepToList(ItemDeps[Count - 1], TASTArrayDecl(Node).ElemType);
    end
    else if Node is TASTSetDecl then
      AppendItem(0, I, UpperCase(TASTSetDecl(Node).Name))
    else if Node is TASTSubrangeDecl then
      AppendItem(0, I, UpperCase(TASTSubrangeDecl(Node).Name))
    else if Node is TASTTypeAliasDecl then
    begin
      AppendItem(0, I, UpperCase(TASTTypeAliasDecl(Node).Name));
      AddDepToList(ItemDeps[Count - 1], TASTTypeAliasDecl(Node).TargetType);
    end;
  end;

  for I := 0 to OptTags.Count - 1 do
  begin
    if (I <= High(OptUsed)) and OptUsed[I] then
    begin
      AppendItem(1, I, '__OPT_' + UpperCase(OptTags[I]));
      AddDepToList(ItemDeps[Count - 1], OptInners[I]);
    end;
  end;

  for I := 0 to ResTags.Count - 1 do
  begin
    if (I <= High(ResUsed)) and ResUsed[I] then
    begin
      AppendItem(2, I, '__RES_' + UpperCase(ResTags[I]));
      AddDepToList(ItemDeps[Count - 1], ResVals[I]);
      AddDepToList(ItemDeps[Count - 1], ResErrs[I]);
    end;
  end;

  if Assigned(FDynTags) then
    for I := 0 to FDynTags.Count - 1 do
    begin
      AppendItem(3, I, '__DYN_' + UpperCase(FDynTags[I]));
      AddDepToList(ItemDeps[Count - 1], FDynElems[I]);
    end;

  if Assigned(FFnTags) then
    for I := 0 to FFnTags.Count - 1 do
    begin
      AppendItem(4, I, '__FN_' + UpperCase(FFnTags[I]));
      FnParams2 := TStringList.Create;
      try
        if SplitFnType(FFnSigs[I], FnParams2, FnRet2) then
        begin
          for J := 0 to FnParams2.Count - 1 do
            AddDepToList(ItemDeps[Count - 1], FnParams2[J]);
          if (FnRet2 <> '') and (not SameText(FnRet2, 'Void')) then
            AddDepToList(ItemDeps[Count - 1], FnRet2);
        end;
      finally
        FnParams2.Free;
      end;
    end;

  try
    Rem := Count;
    while Rem > 0 do
    begin
      ReadyIdx := -1;
      for I := 0 to Count - 1 do
        if (not ItemEmitted[I]) and AllDepsEmitted(I) then
        begin
          ReadyIdx := I;
          Break;
        end;
      if ReadyIdx = -1 then
        for I := 0 to Count - 1 do
          if not ItemEmitted[I] then
          begin
            ReadyIdx := I;
            Break;
          end;
      if ReadyIdx = -1 then Break;
      ItemEmitted[ReadyIdx] := True;
      Dec(Rem);

      if ItemKind[ReadyIdx] = 0 then
      begin
        Node := TASTNode(FModule.Types[ItemIdx[ReadyIdx]]);
        if Node is TASTRecordDecl then EmitRecordType(TASTRecordDecl(Node))
        else if Node is TASTEnumDecl then EmitEnumDecl(TASTEnumDecl(Node))
        else if Node is TASTArrayDecl then EmitArrayDecl(TASTArrayDecl(Node))
        else if Node is TASTSetDecl then EmitSetDecl(TASTSetDecl(Node))
        else if Node is TASTSubrangeDecl then EmitSubrangeDecl(TASTSubrangeDecl(Node))
        else if Node is TASTTypeAliasDecl then EmitTypeAliasDecl(TASTTypeAliasDecl(Node));
      end
      else if ItemKind[ReadyIdx] = 1 then
        EmitTypedOptionDecl(OptTags[ItemIdx[ReadyIdx]], OptInners[ItemIdx[ReadyIdx]])
      else if ItemKind[ReadyIdx] = 2 then
        EmitTypedResultDecl(ResTags[ItemIdx[ReadyIdx]], ResVals[ItemIdx[ReadyIdx]], ResErrs[ItemIdx[ReadyIdx]])
      else if ItemKind[ReadyIdx] = 3 then
      begin
        Emit(Format('TAetherDyn_%s = array of %s;', [FDynTags[ItemIdx[ReadyIdx]], EmitTypeRef(FDynElems[ItemIdx[ReadyIdx]])]));
        Emit('');
      end
      else if ItemKind[ReadyIdx] = 4 then
      begin
        FIdx := ItemIdx[ReadyIdx];
        FnParams2 := TStringList.Create;
        try
          if SplitFnType(FFnSigs[FIdx], FnParams2, FnRet2) then
          begin
            FnPSig := 'AEnv: Pointer';
            for J := 0 to FnParams2.Count - 1 do
              FnPSig := FnPSig + Format('; const _p%d: %s', [J, EmitTypeRef(FnParams2[J])]);
            if (FnRet2 = '') or SameText(FnRet2, 'Void') then
              Emit(Format('TAetherFn_%s_Call = procedure(%s);', [FFnTags[FIdx], FnPSig]))
            else
              Emit(Format('TAetherFn_%s_Call = function(%s): %s;', [FFnTags[FIdx], FnPSig, EmitTypeRef(FnRet2)]));
            Emit(Format('TAetherFn_%s = record', [FFnTags[FIdx]]));
            IncIndent;
            Emit(Format('fn_ptr: TAetherFn_%s_Call;', [FFnTags[FIdx]]));
            Emit('env: Pointer;');
            DecIndent;
            Emit('end;');
            Emit('');
          end;
        finally
          FnParams2.Free;
        end;
      end;
    end;
  finally
    for I := 0 to Count - 1 do
      ItemDeps[I].Free;
  end;
end;

procedure TAetherEmitterPascal.EmitFnRuntimeHelpers(DeclOnly: Boolean);
var
  I, J: Integer;
  Params: TStringList;
  RetT, ParamDecls, CallArgs, Tag: string;
  IsProc: Boolean;
begin
  Params := TStringList.Create;
  try
    for I := 0 to FFnTags.Count - 1 do
    begin
      Tag := FFnTags[I];
      if not SplitFnType(FFnSigs[I], Params, RetT) then Continue;
      IsProc := (RetT = '') or SameText(RetT, 'Void');

      Emit(Format('function AetherMakeFn_%s(AFn: TAetherFn_%s_Call; AEnv: Pointer): TAetherFn_%s;', [Tag, Tag, Tag]));
      if not DeclOnly then
      begin
        Emit('begin');
        IncIndent;
        Emit('Result.fn_ptr := AFn;');
        Emit('Result.env := AEnv;');
        DecIndent;
        Emit('end;');
        Emit('');
      end;

      ParamDecls := Format('const AFn: TAetherFn_%s', [Tag]);
      CallArgs := 'AFn.env';
      for J := 0 to Params.Count - 1 do
      begin
        ParamDecls := ParamDecls + Format('; const _p%d: %s', [J, EmitTypeRef(Params[J])]);
        CallArgs := CallArgs + Format(', _p%d', [J]);
      end;
      if IsProc then
        Emit(Format('procedure AetherCallFn_%s(%s);', [Tag, ParamDecls]))
      else
        Emit(Format('function AetherCallFn_%s(%s): %s;', [Tag, ParamDecls, EmitTypeRef(RetT)]));

      if not DeclOnly then
      begin
        Emit('begin');
        IncIndent;
        if IsProc then
          Emit(Format('AFn.fn_ptr(%s);', [CallArgs]))
        else
          Emit(Format('Result := AFn.fn_ptr(%s);', [CallArgs]));
        DecIndent;
        Emit('end;');
        Emit('');
      end;
    end;
  finally
    Params.Free;
  end;
end;

procedure TAetherEmitterPascal.EmitLambdaAndThunkDecls(ForwardOnly: Boolean);
var
  I, J: Integer;
  Fn, TempFunc, OldFunc: TASTFunction;
  L: TASTLambdaExpr;
  ParamDecls, CallArgs, Sig, FwdSuffix, Tag, MakeParams: string;
  SkipNames, AutoNames, AutoTypes: TStringList;
  OldProg: TASTProgramBlock;
  OldScopeList: TASTNodeList;
  IsProc: Boolean;
begin
  if ForwardOnly then FwdSuffix := ' forward;' else FwdSuffix := '';

  // 1. Named function thunks
  for I := 0 to FThunkFuncs.Count - 1 do
  begin
    Fn := FindFunction(FThunkFuncs[I]);
    if not Assigned(Fn) then Continue;
    ParamDecls := 'AEnv: Pointer';
    CallArgs := '';
    for J := 0 to Fn.Params.Count - 1 do
    begin
      if TASTParam(Fn.Params[J]).Ownership = owMutBorrow then
        ParamDecls := ParamDecls + Format('; var _p%d: %s', [J, EmitTypeRef(TASTParam(Fn.Params[J]).TypeName)])
      else
        ParamDecls := ParamDecls + Format('; const _p%d: %s', [J, EmitTypeRef(TASTParam(Fn.Params[J]).TypeName)]);
      if J > 0 then CallArgs := CallArgs + ', ';
      CallArgs := CallArgs + Format('_p%d', [J]);
    end;
    IsProc := Fn.IsProcedure or (Fn.ReturnType = '') or SameText(Fn.ReturnType, 'Void');
    if IsProc then
      Sig := Format('procedure __aether_thunk_%s(%s);%s', [Fn.Name, ParamDecls, FwdSuffix])
    else
      Sig := Format('function __aether_thunk_%s(%s): %s;%s', [Fn.Name, ParamDecls, EmitTypeRef(Fn.ReturnType), FwdSuffix]);
    Emit(Sig);
    if not ForwardOnly then
    begin
      Emit('begin');
      IncIndent;
      Emit('if AEnv <> nil then ;');
      if IsProc then
        Emit(Format('%s(%s);', [Fn.Name, CallArgs]))
      else
        Emit(Format('Result := %s(%s);', [Fn.Name, CallArgs]));
      DecIndent;
      Emit('end;');
      Emit('');
    end;
  end;

  // 2. Lifted lambdas and env constructors
  for I := 0 to FLambdas.Count - 1 do
  begin
    L := TASTLambdaExpr(FLambdas[I]);
    Tag := FnTypeTag(L.ResolvedFnType);
    ParamDecls := 'AEnv: Pointer';
    for J := 0 to L.Params.Count - 1 do
    begin
      if TASTParam(L.Params[J]).Ownership = owMutBorrow then
        ParamDecls := ParamDecls + Format('; var %s: %s', [TASTParam(L.Params[J]).Name, EmitTypeRef(TASTParam(L.Params[J]).TypeName)])
      else
        ParamDecls := ParamDecls + Format('; const %s: %s', [TASTParam(L.Params[J]).Name, EmitTypeRef(TASTParam(L.Params[J]).TypeName)]);
    end;
    IsProc := (L.ReturnType = '') or SameText(L.ReturnType, 'Void');
    if IsProc then
      Sig := Format('procedure __aether_lambda_%d(%s);%s', [L.LambdaId, ParamDecls, FwdSuffix])
    else
      Sig := Format('function __aether_lambda_%d(%s): %s;%s', [L.LambdaId, ParamDecls, EmitTypeRef(L.ReturnType), FwdSuffix]);
    Emit(Sig);

    if not ForwardOnly then
    begin
      OldFunc := FCurrentFunc;
      OldProg := FProgramBlock;
      OldScopeList := FCurrentScopeList;
      TempFunc := TASTFunction.Create(L.Line, L.Col, '__aether_lambda_' + IntToStr(L.LambdaId), L.ReturnType);
      TempFunc.IsProcedure := IsProc;
      for J := 0 to L.Params.Count - 1 do
        TempFunc.Params.Add(CloneASTNode(TASTParam(L.Params[J])));
      for J := 0 to L.CaptureNames.Count - 1 do
        TempFunc.LocalVars.Add(TASTVarDecl.Create(L.Line, L.Col, L.CaptureNames[J], L.CaptureTypes[J], nil, True));

      FCurrentFunc := TempFunc;
      FProgramBlock := nil;
      SkipNames := TStringList.Create;
      AutoNames := TStringList.Create;
      AutoTypes := TStringList.Create;
      try
        for J := 0 to TempFunc.Params.Count - 1 do
          SkipNames.Add(TASTParam(TempFunc.Params[J]).Name);
        for J := 0 to TempFunc.LocalVars.Count - 1 do
          SkipNames.Add(TASTVarDecl(TempFunc.LocalVars[J]).Name);
        if Assigned(L.BodyExpr) then
          CollectAutoVarsFromExpr(L.BodyExpr, AutoNames, AutoTypes, SkipNames)
        else
          CollectAutoVarsFromStmts(L.BodyStmts, AutoNames, AutoTypes, SkipNames);

        if (TempFunc.LocalVars.Count > 0) or (AutoNames.Count > 0) then
        begin
          Emit('var');
          IncIndent;
          for J := 0 to TempFunc.LocalVars.Count - 1 do
            Emit(Format('%s: %s;', [TASTVarDecl(TempFunc.LocalVars[J]).Name, EmitTypeRef(TASTVarDecl(TempFunc.LocalVars[J]).TypeName)]));
          for J := 0 to AutoNames.Count - 1 do
            Emit(Format('%s: %s;', [AutoNames[J], AutoTypes[J]]));
          DecIndent;
        end;

        Emit('begin');
        IncIndent;
        if L.CaptureNames.Count = 0 then
          Emit('if AEnv <> nil then ;')
        else
          for J := 0 to L.CaptureNames.Count - 1 do
            Emit(Format('%s := PAetherEnv_lambda_%d(AEnv)^.%s;', [L.CaptureNames[J], L.LambdaId, L.CaptureNames[J]]));

        if Assigned(L.BodyExpr) then
        begin
          if IsProc then
            Emit(EmitExpr(L.BodyExpr) + ';')
          else
            Emit('Result := ' + EmitExpr(L.BodyExpr) + ';');
        end
        else
        begin
          FActiveDefers.Clear;
          FLoopDeferBase := 0;
          FRaiiNames.Clear;
          FRaiiTypes.Clear;
          FLoopRaiiBase := 0;
          FCurrentScopeList := L.BodyStmts;
          EmitStmtList(L.BodyStmts);
          if FRaiiNames.Count > 0 then
            EmitActiveRaii(0);
          FActiveDefers.Clear;
          FRaiiNames.Clear;
          FRaiiTypes.Clear;
        end;
        DecIndent;
        Emit('end;');
        Emit('');
      finally
        SkipNames.Free;
        AutoNames.Free;
        AutoTypes.Free;
        FCurrentFunc := OldFunc;
        FProgramBlock := OldProg;
        FCurrentScopeList := OldScopeList;
        TempFunc.Free;
      end;
    end;

    if L.CaptureNames.Count > 0 then
    begin
      MakeParams := '';
      for J := 0 to L.CaptureNames.Count - 1 do
      begin
        if J > 0 then MakeParams := MakeParams + '; ';
        MakeParams := MakeParams + Format('const A_%s: %s', [L.CaptureNames[J], EmitTypeRef(L.CaptureTypes[J])]);
      end;
      Emit(Format('function __aether_make_lambda_%d(%s): TAetherFn_%s;%s', [L.LambdaId, MakeParams, Tag, FwdSuffix]));
      if not ForwardOnly then
      begin
        Emit('var');
        IncIndent;
        Emit(Format('_env: PAetherEnv_lambda_%d;', [L.LambdaId]));
        DecIndent;
        Emit('begin');
        IncIndent;
        Emit('New(_env);');
        for J := 0 to L.CaptureNames.Count - 1 do
          Emit(Format('_env^.%s := A_%s;', [L.CaptureNames[J], L.CaptureNames[J]]));
        Emit(Format('Result := AetherMakeFn_%s(@__aether_lambda_%d, _env);', [Tag, L.LambdaId]));
        DecIndent;
        Emit('end;');
        Emit('');
      end;
    end;
  end;
end;

function TAetherEmitterPascal.Generate(AModule: TASTModule; AsUnit: Boolean = False; AsLibrary: Boolean = False): string;
var
  I, ExportCount, CurExp, UsedConstCount, UsedTypeCount, UsedOptCount, UsedResCount: Integer;
  UsesClause, Sig, ReachText, ProgText, MapText, FnHelperText: string;
  Func: TASTFunction;
  Rec: TASTRecordDecl;
  ConstDecl: TASTConstDecl;
  VarDecl: TASTVarDecl;
  EffectiveLibrary, KeepAll, Changed, NeedBox, HasCustomMap, HasVarsBlock, HasEnvTypes: Boolean;
  MapTags, MapKeys, MapVals: TStringList;
  OptTags, OptInners, ResTags, ResVals, ResErrs: TStringList;
  UOptTags, UOptInners, UResTags, UResVals, UResErrs: TStringList;
  ConstUsed, TypeUsed, FuncUsed, OptUsed, ResUsed: array of Boolean;
  ConstBodies, TypeBodies, TypeNames, FuncBodies, FuncSigs: array of string;
begin
  FModule := AModule;
  FOutput.Clear;
  FIndent := 0;
  MapTags := TStringList.Create;
  MapKeys := TStringList.Create;
  MapVals := TStringList.Create;
  OptTags := TStringList.Create;
  OptInners := TStringList.Create;
  ResTags := TStringList.Create;
  ResVals := TStringList.Create;
  ResErrs := TStringList.Create;
  UOptTags := TStringList.Create;
  UOptInners := TStringList.Create;
  UResTags := TStringList.Create;
  UResVals := TStringList.Create;
  UResErrs := TStringList.Create;
  try
  FDynTags.Clear;
  FDynElems.Clear;
  FFnTags.Clear;
  FFnSigs.Clear;
  FThunkFuncs.Clear;
  FLambdas.Clear;
  CollectMapsFromModule(AModule, MapTags, MapKeys, MapVals);
  CollectTypedMonadsFromModule(AModule, OptTags, OptInners, ResTags, ResVals, ResErrs);
  HasEnvTypes := False;
  for I := 0 to FLambdas.Count - 1 do
    if TASTLambdaExpr(FLambdas[I]).CaptureNames.Count > 0 then
    begin
      HasEnvTypes := True;
      Break;
    end;

  EffectiveLibrary := AsLibrary;
  if (not EffectiveLibrary) and (not Assigned(AModule.ProgramBlock)) then
  begin
    for I := 0 to AModule.Functions.Count - 1 do
    begin
      if TASTFunction(AModule.Functions[I]).IsExport then
      begin
        EffectiveLibrary := True;
        Break;
      end;
    end;
  end;

  KeepAll := AsUnit or EffectiveLibrary or AModule.IsUnit;

  // 1. Pre-render declarations for reachability analysis (Tree-Shaking)
  SetLength(ConstUsed, AModule.Constants.Count);
  SetLength(ConstBodies, AModule.Constants.Count);
  for I := 0 to AModule.Constants.Count - 1 do
  begin
    ConstDecl := TASTConstDecl(AModule.Constants[I]);
    if ConstDecl.DeclaredType <> '' then
      ConstBodies[I] := Format('%s: %s = %s;', [ConstDecl.Name, EmitTypeRef(ConstDecl.DeclaredType), EmitExpr(ConstDecl.ValueExpr)])
    else
      ConstBodies[I] := Format('%s = %s;', [ConstDecl.Name, EmitExpr(ConstDecl.ValueExpr)]);
    ConstUsed[I] := KeepAll or (ConstDecl.SourceModule = '');
  end;

  SetLength(TypeUsed, AModule.Types.Count);
  SetLength(TypeBodies, AModule.Types.Count);
  SetLength(TypeNames, AModule.Types.Count);
  for I := 0 to AModule.Types.Count - 1 do
  begin
    FOutput.Clear;
    FIndent := 0;
    TypeNames[I] := '';
    if AModule.Types[I] is TASTRecordDecl then
    begin
      Rec := TASTRecordDecl(AModule.Types[I]);
      if Rec.GenericParams.Count = 0 then
      begin
        TypeNames[I] := Rec.Name;
        EmitRecordType(Rec);
        EmitRecordConstructor(Rec);
      end;
    end
    else if AModule.Types[I] is TASTEnumDecl then
    begin
      TypeNames[I] := TASTEnumDecl(AModule.Types[I]).Name;
      EmitEnumDecl(TASTEnumDecl(AModule.Types[I]));
      EmitPayloadEnumConstructors(TASTEnumDecl(AModule.Types[I]), False);
    end
    else if AModule.Types[I] is TASTArrayDecl then
    begin
      TypeNames[I] := TASTArrayDecl(AModule.Types[I]).Name;
      EmitArrayDecl(TASTArrayDecl(AModule.Types[I]));
    end
    else if AModule.Types[I] is TASTSetDecl then
    begin
      TypeNames[I] := TASTSetDecl(AModule.Types[I]).Name;
      EmitSetDecl(TASTSetDecl(AModule.Types[I]));
    end
    else if AModule.Types[I] is TASTSubrangeDecl then
    begin
      TypeNames[I] := TASTSubrangeDecl(AModule.Types[I]).Name;
      EmitSubrangeDecl(TASTSubrangeDecl(AModule.Types[I]));
    end
    else if AModule.Types[I] is TASTTypeAliasDecl then
    begin
      TypeNames[I] := TASTTypeAliasDecl(AModule.Types[I]).Name;
      EmitTypeAliasDecl(TASTTypeAliasDecl(AModule.Types[I]));
    end
    else if AModule.Types[I] is TASTMapDecl then
    begin
      TypeNames[I] := TASTMapDecl(AModule.Types[I]).Name;
      EmitMapDecl(TASTMapDecl(AModule.Types[I]));
    end;
    TypeBodies[I] := FOutput.Text;
    TypeUsed[I] := KeepAll or (TASTNode(AModule.Types[I]).SourceModule = '');
  end;

  SetLength(FuncUsed, AModule.Functions.Count);
  SetLength(FuncBodies, AModule.Functions.Count);
  SetLength(FuncSigs, AModule.Functions.Count);
  for I := 0 to AModule.Functions.Count - 1 do
  begin
    Func := TASTFunction(AModule.Functions[I]);
    FOutput.Clear;
    FIndent := 0;
    FuncSigs[I] := BuildFuncSig(Func);
    EmitFunction(Func);
    FuncBodies[I] := FOutput.Text;
    FuncUsed[I] := KeepAll or (Func.SourceModule = '') or Func.IsExport;
  end;

  FOutput.Clear;
  FIndent := 0;
  EmitMapRuntimeDecls(MapTags, MapKeys, MapVals, False);
  EmitMapRuntimeHelpers(MapTags, MapKeys, MapVals, False);
  MapText := FOutput.Text;

  FOutput.Clear;
  FIndent := 0;
  if Assigned(AModule.ProgramBlock) then
  begin
    if AsUnit then
    begin
      for I := 0 to AModule.ProgramBlock.Body.Count - 1 do
        EmitStmt(TASTStmt(AModule.ProgramBlock.Body[I]));
    end
    else if not EffectiveLibrary then
      EmitProgramBlock(AModule.ProgramBlock);
  end;
  if AsUnit or (not Assigned(AModule.ProgramBlock)) then
  begin
    for I := 0 to AModule.InitBody.Count - 1 do
      EmitStmt(TASTStmt(AModule.InitBody[I]));
    for I := 0 to AModule.FiniBody.Count - 1 do
      EmitStmt(TASTStmt(AModule.FiniBody[I]));
  end;
  for I := 0 to AModule.ModuleVars.Count - 1 do
    if Assigned(TASTVarDecl(AModule.ModuleVars[I]).InitialExpr) then
      Emit(EmitExpr(TASTVarDecl(AModule.ModuleVars[I]).InitialExpr) + ';');
  ProgText := FOutput.Text;

  FOutput.Clear;
  FIndent := 0;
  EmitFnRuntimeHelpers(False);
  EmitLambdaAndThunkDecls(False);
  FnHelperText := FOutput.Text;

  ReachText := ProgText + #10 + MapText + #10 + FnHelperText;
  for I := 0 to AModule.Constants.Count - 1 do
    if ConstUsed[I] then ReachText := ReachText + #10 + ConstBodies[I];
  for I := 0 to AModule.ModuleVars.Count - 1 do
    ReachText := ReachText + #10 + TASTVarDecl(AModule.ModuleVars[I]).Name + ': ' + EmitTypeRef(TASTVarDecl(AModule.ModuleVars[I]).TypeName);
  for I := 0 to AModule.Types.Count - 1 do
    if (TypeBodies[I] <> '') and TypeUsed[I] then ReachText := ReachText + #10 + TypeBodies[I];
  for I := 0 to AModule.Functions.Count - 1 do
    if FuncUsed[I] then ReachText := ReachText + #10 + FuncSigs[I] + #10 + FuncBodies[I];

  SetLength(OptUsed, OptTags.Count);
  for I := 0 to OptTags.Count - 1 do
    OptUsed[I] := KeepAll or (Pos('TAetherOpt_' + OptTags[I], ReachText) > 0) or
      (Pos('AetherSome_' + OptTags[I], ReachText) > 0) or (Pos('AetherNone_' + OptTags[I], ReachText) > 0);

  SetLength(ResUsed, ResTags.Count);
  for I := 0 to ResTags.Count - 1 do
    ResUsed[I] := KeepAll or (Pos('TAetherRes_' + ResTags[I], ReachText) > 0) or
      (Pos('AetherOk_' + ResTags[I], ReachText) > 0) or (Pos('AetherErr_' + ResTags[I], ReachText) > 0);

  if not KeepAll then
  begin
    repeat
      Changed := False;
      for I := 0 to AModule.Functions.Count - 1 do
      begin
        Func := TASTFunction(AModule.Functions[I]);
        if (not FuncUsed[I]) and ((FuncBodies[I] <> '') or (FuncSigs[I] <> '')) and
           (Pos(Func.Name, ReachText) > 0) then
        begin
          FuncUsed[I] := True;
          ReachText := ReachText + #10 + FuncSigs[I] + #10 + FuncBodies[I];
          Changed := True;
        end;
      end;
      for I := 0 to OptTags.Count - 1 do
      begin
        if (not OptUsed[I]) and ((Pos('TAetherOpt_' + OptTags[I], ReachText) > 0) or
           (Pos('AetherSome_' + OptTags[I], ReachText) > 0) or (Pos('AetherNone_' + OptTags[I], ReachText) > 0)) then
        begin
          OptUsed[I] := True;
          ReachText := ReachText + #10 + EmitTypeRef(OptInners[I]);
          Changed := True;
        end;
      end;
      for I := 0 to ResTags.Count - 1 do
      begin
        if (not ResUsed[I]) and ((Pos('TAetherRes_' + ResTags[I], ReachText) > 0) or
           (Pos('AetherOk_' + ResTags[I], ReachText) > 0) or (Pos('AetherErr_' + ResTags[I], ReachText) > 0)) then
        begin
          ResUsed[I] := True;
          ReachText := ReachText + #10 + EmitTypeRef(ResVals[I]) + ' ' + EmitTypeRef(ResErrs[I]);
          Changed := True;
        end;
      end;
      for I := 0 to AModule.Types.Count - 1 do
      begin
        if (not TypeUsed[I]) and (TypeNames[I] <> '') and
           (Pos(TypeNames[I], ReachText) > 0) then
        begin
          TypeUsed[I] := True;
          ReachText := ReachText + #10 + TypeBodies[I];
          Changed := True;
        end;
      end;
      for I := 0 to AModule.Constants.Count - 1 do
      begin
        ConstDecl := TASTConstDecl(AModule.Constants[I]);
        if (not ConstUsed[I]) and (Pos(ConstDecl.Name, ReachText) > 0) then
        begin
          ConstUsed[I] := True;
          ReachText := ReachText + #10 + ConstBodies[I];
          Changed := True;
        end;
      end;
    until not Changed;
  end;

  UsedOptCount := 0;
  for I := 0 to OptTags.Count - 1 do
    if OptUsed[I] then
    begin
      Inc(UsedOptCount);
      UOptTags.Add(OptTags[I]);
      UOptInners.Add(OptInners[I]);
    end;

  UsedResCount := 0;
  for I := 0 to ResTags.Count - 1 do
    if ResUsed[I] then
    begin
      Inc(UsedResCount);
      UResTags.Add(ResTags[I]);
      UResVals.Add(ResVals[I]);
      UResErrs.Add(ResErrs[I]);
    end;

  UsedConstCount := 0;
  for I := 0 to AModule.Constants.Count - 1 do
    if ConstUsed[I] then Inc(UsedConstCount);

  UsedTypeCount := 0;
  for I := 0 to AModule.Types.Count - 1 do
    if TypeUsed[I] and (TypeNames[I] <> '') then Inc(UsedTypeCount);

  HasCustomMap := False;
  for I := 0 to MapTags.Count - 1 do
    if not (IsBuiltinMapSideType(MapKeys[I]) and IsBuiltinMapSideType(MapVals[I])) then
    begin
      HasCustomMap := True;
      Break;
    end;

  NeedBox := AsUnit or (Pos('AetherBox', ReachText) > 0);

  FOutput.Clear;
  FIndent := 0;

  UsesClause := '  SysUtils, Math';
  if Pos('AetherSocket', ReachText) > 0 then
    UsesClause := UsesClause + '{$IFNDEF PAS2JS}, Sockets{$ENDIF}';
  if (Pos('AetherGetNanoseconds', ReachText) > 0) or (Pos('AetherSetEnv', ReachText) > 0) then
    UsesClause := UsesClause + '{$IFNDEF PAS2JS}{$IFDEF WINDOWS}, Windows{$ENDIF}{$ENDIF}';
  for I := 0 to AModule.PascalImports.Count - 1 do
  begin
    if Pos(LowerCase(AModule.PascalImports[I]), LowerCase(UsesClause)) = 0 then
      UsesClause := UsesClause + ', ' + AModule.PascalImports[I];
  end;
  UsesClause := UsesClause + ';';

  if AsUnit then
  begin
    Emit('// Code automatically generated by the Aether Compiler (aetherc)');
    Emit('// Target: Object Pascal Unit (Free Pascal / BlaiseVue)');
    Emit('unit ' + AModule.Name + ';');
    Emit('');
    Emit('{$mode objfpc}{$H+}{$assertions on}');
    Emit('');
    Emit('interface');
    Emit('');
    Emit('uses');
    Emit(UsesClause);
    Emit('');

    EmitRuntimeTypeDecls(ReachText, MapTags, MapKeys, MapVals, True);

    if UsedConstCount > 0 then
    begin
      Emit('const');
      IncIndent;
      for I := 0 to AModule.Constants.Count - 1 do
        if ConstUsed[I] then Emit(ConstBodies[I]);
      DecIndent;
      Emit('');
    end;

    if (UsedTypeCount > 0) or (UsedOptCount > 0) or (UsedResCount > 0) or (FDynTags.Count > 0) or HasCustomMap or (FFnTags.Count > 0) then
    begin
      Emit('type');
      IncIndent;
      for I := 0 to AModule.Types.Count - 1 do
      begin
        if TypeUsed[I] and (AModule.Types[I] is TASTRecordDecl) and (TASTRecordDecl(AModule.Types[I]).GenericParams.Count = 0) then
        begin
          Emit(Format('P%s = ^T%s;', [TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name]));
          Emit(Format('PT%s = ^T%s;', [TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name]));
        end
        else if TypeUsed[I] and (AModule.Types[I] is TASTEnumDecl) and TASTEnumDecl(AModule.Types[I]).HasPayload then
        begin
          Emit(Format('P%s = ^T%s;', [TASTEnumDecl(AModule.Types[I]).Name, TASTEnumDecl(AModule.Types[I]).Name]));
          Emit(Format('PT%s = ^T%s;', [TASTEnumDecl(AModule.Types[I]).Name, TASTEnumDecl(AModule.Types[I]).Name]));
        end;
      end;

      EmitTopologicalTypesAndMonads(TypeUsed, OptTags, OptInners, OptUsed, ResTags, ResVals, ResErrs, ResUsed);
      EmitMapRuntimeDecls(MapTags, MapKeys, MapVals, False);
      for I := 0 to AModule.Types.Count - 1 do
        if TypeUsed[I] and (AModule.Types[I] is TASTMapDecl) then
          EmitMapDecl(TASTMapDecl(AModule.Types[I]));
      DecIndent;
      Emit('');

      for I := 0 to AModule.Types.Count - 1 do
      begin
        if TypeUsed[I] and (AModule.Types[I] is TASTRecordDecl) and (TASTRecordDecl(AModule.Types[I]).GenericParams.Count = 0) then
        begin
          Rec := TASTRecordDecl(AModule.Types[I]);
          Emit(BuildRecordConstructorSig(Rec));
          if NeedBox then
            Emit(Format('function AetherBox(const V: T%s): P%s;', [Rec.Name, Rec.Name]));
        end
        else if TypeUsed[I] and (AModule.Types[I] is TASTEnumDecl) then
          EmitPayloadEnumConstructors(TASTEnumDecl(AModule.Types[I]), True);
      end;
      Emit('');
    end;

    EmitRuntimeHelpersInterface(ReachText);
    EmitTypedMonadHelpers(UOptTags, UOptInners, UResTags, UResVals, UResErrs, True);
    EmitMapRuntimeHelpers(MapTags, MapKeys, MapVals, True);
    EmitFnRuntimeHelpers(True);

    HasVarsBlock := False;
    for I := 0 to AModule.ModuleVars.Count - 1 do
      if TASTVarDecl(AModule.ModuleVars[I]).IsPublic then
      begin
        HasVarsBlock := True;
        Break;
      end;
    if HasVarsBlock then
    begin
      Emit('var');
      IncIndent;
      for I := 0 to AModule.ModuleVars.Count - 1 do
      begin
        VarDecl := TASTVarDecl(AModule.ModuleVars[I]);
        if VarDecl.IsPublic then
          Emit(Format('%s: %s;', [VarDecl.Name, EmitTypeRef(VarDecl.TypeName)]));
      end;
      DecIndent;
      Emit('');
    end;

    for I := 0 to AModule.Functions.Count - 1 do
    begin
      if not FuncUsed[I] then Continue;
      Func := TASTFunction(AModule.Functions[I]);
      if (not Func.IsExtern) and (Func.GenericParams.Count = 0) and (Func.GenericParam = '') then
      begin
        Sig := FuncSigs[I];
        if Sig <> '' then
          Emit(Sig);
      end;
    end;
    Emit('');

    Emit('implementation');
    Emit('');

    if HasEnvTypes then
    begin
      Emit('type');
      IncIndent;
      for I := 0 to FLambdas.Count - 1 do
      begin
        if TASTLambdaExpr(FLambdas[I]).CaptureNames.Count > 0 then
        begin
          Emit(Format('PAetherEnv_lambda_%d = ^TAetherEnv_lambda_%d;', [TASTLambdaExpr(FLambdas[I]).LambdaId, TASTLambdaExpr(FLambdas[I]).LambdaId]));
          Emit(Format('TAetherEnv_lambda_%d = record', [TASTLambdaExpr(FLambdas[I]).LambdaId]));
          IncIndent;
          for CurExp := 0 to TASTLambdaExpr(FLambdas[I]).CaptureNames.Count - 1 do
            Emit(Format('%s: %s;', [TASTLambdaExpr(FLambdas[I]).CaptureNames[CurExp], EmitTypeRef(TASTLambdaExpr(FLambdas[I]).CaptureTypes[CurExp])]));
          DecIndent;
          Emit('end;');
          Emit('');
        end;
      end;
      DecIndent;
    end;

    HasVarsBlock := False;
    for I := 0 to AModule.ModuleVars.Count - 1 do
      if not TASTVarDecl(AModule.ModuleVars[I]).IsPublic then
      begin
        HasVarsBlock := True;
        Break;
      end;
    if HasVarsBlock then
    begin
      Emit('var');
      IncIndent;
      for I := 0 to AModule.ModuleVars.Count - 1 do
      begin
        VarDecl := TASTVarDecl(AModule.ModuleVars[I]);
        if not VarDecl.IsPublic then
          Emit(Format('%s: %s;', [VarDecl.Name, EmitTypeRef(VarDecl.TypeName)]));
      end;
      DecIndent;
      Emit('');
    end;

    if UsedTypeCount > 0 then
    begin
      for I := 0 to AModule.Types.Count - 1 do
      begin
        if TypeUsed[I] and (AModule.Types[I] is TASTRecordDecl) and (TASTRecordDecl(AModule.Types[I]).GenericParams.Count = 0) then
        begin
          EmitRecordConstructor(TASTRecordDecl(AModule.Types[I]));
          if NeedBox then
          begin
            Emit(Format('function AetherBox(const V: T%s): P%s;', [TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name]));
            Emit('begin');
            Emit('  New(Result);');
            Emit('  Result^ := V;');
            Emit('end;');
            Emit('');
          end;
        end
        else if TypeUsed[I] and (AModule.Types[I] is TASTEnumDecl) then
          EmitPayloadEnumConstructors(TASTEnumDecl(AModule.Types[I]), False);
      end;
    end;

    EmitRuntimeHelpersImplementation(ReachText);
    EmitTypedMonadHelpers(UOptTags, UOptInners, UResTags, UResVals, UResErrs, False);
    EmitMapRuntimeHelpers(MapTags, MapKeys, MapVals, False);
    EmitFnRuntimeHelpers(False);
    EmitLambdaAndThunkDecls(True);

    for I := 0 to AModule.Functions.Count - 1 do
      if FuncUsed[I] then
        EmitFunction(TASTFunction(AModule.Functions[I]));

    EmitLambdaAndThunkDecls(False);

    HasVarsBlock := False;
    for I := 0 to AModule.ModuleVars.Count - 1 do
      if Assigned(TASTVarDecl(AModule.ModuleVars[I]).InitialExpr) then
      begin
        HasVarsBlock := True;
        Break;
      end;
    if Assigned(AModule.ProgramBlock) or (AModule.InitBody.Count > 0) or HasVarsBlock then
    begin
      Emit('');
      Emit('initialization');
      IncIndent;
      for I := 0 to AModule.ModuleVars.Count - 1 do
      begin
        VarDecl := TASTVarDecl(AModule.ModuleVars[I]);
        if Assigned(VarDecl.InitialExpr) then
        begin
          if VarDecl.InitialExpr is TASTMapLiteralExpr then
            EmitMapLiteralAssign(VarDecl.Name, VarDecl.TypeName, TASTMapLiteralExpr(VarDecl.InitialExpr))
          else if (VarDecl.InitialExpr is TASTSetLiteralExpr) and (not IsSetType(VarDecl.TypeName)) then
            EmitArrayLiteralAssign(VarDecl.Name, VarDecl.TypeName, TASTSetLiteralExpr(VarDecl.InitialExpr))
          else
            Emit(Format('%s := %s;', [VarDecl.Name, EmitExpr(VarDecl.InitialExpr)]));
        end;
      end;
      for I := 0 to AModule.InitBody.Count - 1 do
        EmitStmt(TASTStmt(AModule.InitBody[I]));
      if Assigned(AModule.ProgramBlock) then
        for I := 0 to AModule.ProgramBlock.Body.Count - 1 do
          EmitStmt(TASTStmt(AModule.ProgramBlock.Body[I]));
      DecIndent;
    end;

    if AModule.FiniBody.Count > 0 then
    begin
      Emit('');
      Emit('finalization');
      IncIndent;
      for I := 0 to AModule.FiniBody.Count - 1 do
        EmitStmt(TASTStmt(AModule.FiniBody[I]));
      DecIndent;
    end;

    Emit('end.');
  end
  else
  begin
    Emit('// Code automatically generated by the Aether Compiler (aetherc)');
    Emit('// Target: Object Pascal (Free Pascal)');
    if EffectiveLibrary then
      Emit('library ' + AModule.Name + ';')
    else
      Emit('program ' + AModule.Name + ';');
    Emit('');
    Emit('{$mode objfpc}{$H+}{$assertions on}');
    Emit('');
    Emit('uses');
    Emit(UsesClause);
    Emit('');

    EmitRuntimeTypeDecls(ReachText, MapTags, MapKeys, MapVals, False);

    if UsedConstCount > 0 then
    begin
      Emit('const');
      IncIndent;
      for I := 0 to AModule.Constants.Count - 1 do
        if ConstUsed[I] then Emit(ConstBodies[I]);
      DecIndent;
      Emit('');
    end;

    if (UsedTypeCount > 0) or (UsedOptCount > 0) or (UsedResCount > 0) or (FDynTags.Count > 0) or HasCustomMap or (FFnTags.Count > 0) or HasEnvTypes then
    begin
      Emit('type');
      IncIndent;
      for I := 0 to AModule.Types.Count - 1 do
      begin
        if TypeUsed[I] and (AModule.Types[I] is TASTRecordDecl) and (TASTRecordDecl(AModule.Types[I]).GenericParams.Count = 0) then
        begin
          Emit(Format('P%s = ^T%s;', [TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name]));
          Emit(Format('PT%s = ^T%s;', [TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name]));
        end
        else if TypeUsed[I] and (AModule.Types[I] is TASTEnumDecl) and TASTEnumDecl(AModule.Types[I]).HasPayload then
        begin
          Emit(Format('P%s = ^T%s;', [TASTEnumDecl(AModule.Types[I]).Name, TASTEnumDecl(AModule.Types[I]).Name]));
          Emit(Format('PT%s = ^T%s;', [TASTEnumDecl(AModule.Types[I]).Name, TASTEnumDecl(AModule.Types[I]).Name]));
        end;
      end;

      EmitTopologicalTypesAndMonads(TypeUsed, OptTags, OptInners, OptUsed, ResTags, ResVals, ResErrs, ResUsed);
      EmitMapRuntimeDecls(MapTags, MapKeys, MapVals, False);
      for I := 0 to AModule.Types.Count - 1 do
        if TypeUsed[I] and (AModule.Types[I] is TASTMapDecl) then
          EmitMapDecl(TASTMapDecl(AModule.Types[I]));
      for I := 0 to FLambdas.Count - 1 do
      begin
        if TASTLambdaExpr(FLambdas[I]).CaptureNames.Count > 0 then
        begin
          Emit(Format('PAetherEnv_lambda_%d = ^TAetherEnv_lambda_%d;', [TASTLambdaExpr(FLambdas[I]).LambdaId, TASTLambdaExpr(FLambdas[I]).LambdaId]));
          Emit(Format('TAetherEnv_lambda_%d = record', [TASTLambdaExpr(FLambdas[I]).LambdaId]));
          IncIndent;
          for CurExp := 0 to TASTLambdaExpr(FLambdas[I]).CaptureNames.Count - 1 do
            Emit(Format('%s: %s;', [TASTLambdaExpr(FLambdas[I]).CaptureNames[CurExp], EmitTypeRef(TASTLambdaExpr(FLambdas[I]).CaptureTypes[CurExp])]));
          DecIndent;
          Emit('end;');
          Emit('');
        end;
      end;
      DecIndent;
      Emit('');

      for I := 0 to AModule.Types.Count - 1 do
      begin
        if TypeUsed[I] and (AModule.Types[I] is TASTRecordDecl) and (TASTRecordDecl(AModule.Types[I]).GenericParams.Count = 0) then
        begin
          EmitRecordConstructor(TASTRecordDecl(AModule.Types[I]));
          if NeedBox then
          begin
            Emit(Format('function AetherBox(const V: T%s): P%s; overload;', [TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name]));
            Emit('begin');
            Emit('  New(Result);');
            Emit('  Result^ := V;');
            Emit('end;');
            Emit('');
          end;
        end
        else if TypeUsed[I] and (AModule.Types[I] is TASTEnumDecl) then
          EmitPayloadEnumConstructors(TASTEnumDecl(AModule.Types[I]), False);
      end;
    end;

    EmitRuntimeHelpersImplementation(ReachText);
    EmitTypedMonadHelpers(UOptTags, UOptInners, UResTags, UResVals, UResErrs, False);
    EmitMapRuntimeHelpers(MapTags, MapKeys, MapVals, False);
    EmitFnRuntimeHelpers(False);

    HasVarsBlock := False;
    for I := 0 to AModule.ModuleVars.Count - 1 do
      if KeepAll or (TASTVarDecl(AModule.ModuleVars[I]).SourceModule = '') or
         (Pos(TASTVarDecl(AModule.ModuleVars[I]).Name, ReachText) > 0) then
      begin
        HasVarsBlock := True;
        Break;
      end;
    if HasVarsBlock then
    begin
      Emit('var');
      IncIndent;
      for I := 0 to AModule.ModuleVars.Count - 1 do
      begin
        VarDecl := TASTVarDecl(AModule.ModuleVars[I]);
        if KeepAll or (VarDecl.SourceModule = '') or (Pos(VarDecl.Name, ReachText) > 0) then
          Emit(Format('%s: %s;', [VarDecl.Name, EmitTypeRef(VarDecl.TypeName)]));
      end;
      DecIndent;
      Emit('');
    end;

    for I := 0 to AModule.Functions.Count - 1 do
    begin
      if not FuncUsed[I] then Continue;
      Func := TASTFunction(AModule.Functions[I]);
      if (not Func.IsExtern) and (Func.GenericParams.Count = 0) and (Func.GenericParam = '') and (Func.InlineMode <> 'always') then
      begin
        Sig := FuncSigs[I];
        if Sig <> '' then
          Emit(Copy(Sig, 1, Length(Sig) - 1) + ' forward;');
      end;
    end;
    EmitLambdaAndThunkDecls(True);
    Emit('');

    for I := 0 to AModule.Functions.Count - 1 do
      if FuncUsed[I] then
        EmitFunction(TASTFunction(AModule.Functions[I]));

    EmitLambdaAndThunkDecls(False);

    if EffectiveLibrary then
    begin
      ExportCount := 0;
      for I := 0 to AModule.Functions.Count - 1 do
        if FuncUsed[I] and TASTFunction(AModule.Functions[I]).IsExport then Inc(ExportCount);

      if ExportCount > 0 then
      begin
        Emit('');
        Emit('exports');
        IncIndent;
        CurExp := 0;
        for I := 0 to AModule.Functions.Count - 1 do
        begin
          if not FuncUsed[I] then Continue;
          Func := TASTFunction(AModule.Functions[I]);
          if Func.IsExport then
          begin
            Inc(CurExp);
            if CurExp = ExportCount then
              Emit(Format('%s name ''%s'';', [Func.Name, Func.Name]))
            else
              Emit(Format('%s name ''%s'',', [Func.Name, Func.Name]));
          end;
        end;
        DecIndent;
      end;
      Emit('');
      Emit('begin');
      Emit('end.');
    end
    else if Assigned(AModule.ProgramBlock) then
      EmitProgramBlock(AModule.ProgramBlock)
    else
    begin
      Emit('begin');
      Emit('end.');
    end;
  end;

  Result := FOutput.Text;
  finally
    UResErrs.Free;
    UResVals.Free;
    UResTags.Free;
    UOptInners.Free;
    UOptTags.Free;
    ResErrs.Free;
    ResVals.Free;
    ResTags.Free;
    OptInners.Free;
    OptTags.Free;
    MapTags.Free;
    MapKeys.Free;
    MapVals.Free;
  end;
end;

end.
