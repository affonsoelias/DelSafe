unit uAetherEmitterC;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  uAetherAST;

type
  TAetherEmitterC = class
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
    FTryDepth: Integer;
    FLoopCounter: Integer;
    FGuardBindNames: TStringList;
    FGuardBindExprs: TStringList;
    FMatchBindNames: TStringList;
    FMatchBindTypes: TStringList;
    FNeedCliArgs: Boolean;
    FFnTags: TStringList;
    FFnSigs: TStringList;
    FThunkFuncs: TStringList;
    FLambdas: TList;

    procedure Emit(const Line: string = '');
    procedure IncIndent;
    procedure DecIndent;
    function IndentStr: string;
    procedure EmitActiveDefers(DownToIndex: Integer = 0);
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
    function IsDynamicArrayType(const AName: string): Boolean;
    function IsFixedArrayType(const AName: string): Boolean;
    function IsValueOptionType(const AType: string): Boolean;
    function SplitResultTypes(const AType: string; out ValType, ErrType: string): Boolean;
    function SplitFnType(const AType: string; ParamTypes: TStrings; out RetType: string): Boolean;
    function FnTypeTag(const AType: string): string;
    function RegisterFnType(const AType: string): string;
    procedure RegisterLambda(L: TASTLambdaExpr);
    procedure RegisterThunkFunc(const AFuncName: string);
    function SafeUnwrapGeneric(const AType, Prefix: string): string;
    function MangleTypeTag(const AType: string): string;
    function IsCompoundMonadType(const AType: string): Boolean;
    function IsTypedValueOption(const AType: string; out InnerT: string): Boolean;
    function IsTypedResult(const AType: string; out ValT, ErrT: string): Boolean;
    function GetMatchArmBindingCount(CaseNode: TASTMatchCase): Integer;
    procedure GetMatchArmBindingInfo(CaseNode: TASTMatchCase; Idx: Integer; const MatchedType: string;
      out BindName, BindType: string);
    procedure PushMatchBindings(CaseNode: TASTMatchCase; const MatchedType: string);
    procedure PopMatchBindings(Count: Integer);
    procedure CollectTypedMonadsFromType(const AType: string; OptTags, OptInners, ResTags, ResVals, ResErrs: TStrings);
    procedure CollectTypedMonadsFromExpr(Expr: TASTExpr; OptTags, OptInners, ResTags, ResVals, ResErrs: TStrings);
    procedure CollectTypedMonadsFromStmts(Stmts: TASTNodeList; OptTags, OptInners, ResTags, ResVals, ResErrs: TStrings);
    procedure CollectTypedMonadsFromModule(AModule: TASTModule; OptTags, OptInners, ResTags, ResVals, ResErrs: TStrings);
    procedure EmitTypedOptionDecl(const Tag, InnerT: string);
    procedure EmitTypedResultDecl(const Tag, ValT, ErrT: string);
    procedure EmitTypedMonadHelpers(OptTags, OptInners, ResTags, ResVals, ResErrs: TStrings);
    procedure EmitTopologicalTypesAndMonads(const TypeUsed: array of Boolean;
      OptTags, OptInners: TStrings; const OptUsed: array of Boolean;
      ResTags, ResVals, ResErrs: TStrings; const ResUsed: array of Boolean);
    procedure EmitFnRuntimeHelpers;
    procedure EmitLambdaAndThunkDecls(ForwardOnly: Boolean);
    function IsTypeIdentifier(const AName: string): Boolean;
    function EmitMonadFieldExtract(const ExprStr, FieldType, NumField, StrField: string): string;
    procedure EmitArrayLiteralAssign(const TargetStr, TargetType: string; SetLit: TASTSetLiteralExpr);
    procedure EmitMapLiteralAssign(const TargetStr, TargetType: string; MapLit: TASTMapLiteralExpr);
    function IsMapType(const AType: string; out KeyType, ValType: string): Boolean;
    function MapTag(const K, V: string): string;
    function NormalizeIntLit(const Val: string): string;
    function IsIntCType(const AType: string): Boolean;
    function GetCollectionElemType(Expr: TASTExpr): string;
    function IsBuiltinMapSideType(const AType: string): Boolean;
    function FindInlineVarType(Stmts: TASTNodeList; const AName: string): string;
    procedure CollectAutoForVars(Stmts: TASTNodeList; VarNames, VarTypes: TStrings; const SkipNames: TStrings);
    procedure CollectMapsFromType(const AType: string; Tags, Keys, Vals: TStrings);
    procedure CollectMapsFromExpr(Expr: TASTExpr; Tags, Keys, Vals: TStrings);
    procedure CollectMapsFromStmts(Stmts: TASTNodeList; Tags, Keys, Vals: TStrings);
    procedure CollectMapsFromModule(AModule: TASTModule; Tags, Keys, Vals: TStrings);
    procedure EmitMapRuntimeDecls(Tags, Keys, Vals: TStrings; BuiltinOnly: Boolean);
    procedure EmitMapRuntimeHelpers(Tags, Keys, Vals: TStrings);
    function IsVarModifiedInTry(const AVarName: string; Nodes: TASTNodeList; InTry: Boolean = False): Boolean;
    function IsMutBorrowParam(const AName: string): Boolean;
    function FindFunction(const AName: string): TASTFunction;
    function EscapeCString(const S: string): string;
    function EscapeCChar(const S: string): string;
    function GetExprTypeName(Expr: TASTExpr): string;
    function IsPointerTarget(Expr: TASTExpr): Boolean;
    function FormatCArrayVar(const AType, AName: string): string;
    procedure BuildMatchCaseCond(CaseNode: TASTMatchCase; const ExprStr, MatchedType: string;
      out CondStr, BindStmt, BindVarType: string; out IsWildcardArm: Boolean);
    procedure EmitLocalVarDecl(VarDecl: TASTVarDecl; InTryBody: TASTNodeList);

    function EmitTypeRef(const AType: string): string;
    function EmitExpr(Expr: TASTExpr): string;
    procedure EmitStmt(Stmt: TASTStmt);
    procedure EmitRecordDecl(Rec: TASTRecordDecl);
    procedure EmitEnumDecl(Enm: TASTEnumDecl);
    procedure EmitArrayDecl(Arr: TASTArrayDecl);
    procedure EmitSetDecl(SetD: TASTSetDecl);
    procedure EmitSubrangeDecl(SubR: TASTSubrangeDecl);
    procedure EmitMapDecl(MapD: TASTMapDecl);
    procedure EmitTypeAliasDecl(AliasD: TASTTypeAliasDecl);
    procedure EmitFunction(Func: TASTFunction);
    procedure EmitProgramBlock(Prog: TASTProgramBlock);
  public
    constructor Create;
    destructor Destroy; override;
    function Generate(AModule: TASTModule): string;
  end;

implementation

constructor TAetherEmitterC.Create;
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
  FTryDepth := 0;
  FLoopCounter := 0;
  FGuardBindNames := TStringList.Create;
  FGuardBindExprs := TStringList.Create;
  FMatchBindNames := TStringList.Create;
  FMatchBindTypes := TStringList.Create;
  FFnTags := TStringList.Create;
  FFnSigs := TStringList.Create;
  FThunkFuncs := TStringList.Create;
  FLambdas := TList.Create;
end;

destructor TAetherEmitterC.Destroy;
begin
  FLambdas.Free;
  FThunkFuncs.Free;
  FFnSigs.Free;
  FFnTags.Free;
  FMatchBindTypes.Free;
  FMatchBindNames.Free;
  FGuardBindExprs.Free;
  FGuardBindNames.Free;
  FRaiiNames.Free;
  FRaiiTypes.Free;
  FActiveDefers.Free;
  FOutput.Free;
  inherited Destroy;
end;

function TAetherEmitterC.IndentStr: string;
begin
  Result := StringOfChar(' ', FIndent * 4);
end;

procedure TAetherEmitterC.Emit(const Line: string);
begin
  if Line = '' then
    FOutput.Add('')
  else
    FOutput.Add(IndentStr + Line);
end;

procedure TAetherEmitterC.IncIndent;
begin
  Inc(FIndent);
end;

procedure TAetherEmitterC.DecIndent;
begin
  if FIndent > 0 then
    Dec(FIndent);
end;

function TAetherEmitterC.IsEnumName(const AName: string): Boolean;
begin
  Result := Assigned(FindEnumDecl(AName));
end;

function TAetherEmitterC.FindEnumDecl(const AName: string): TASTEnumDecl;
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

function TAetherEmitterC.FindEnumVariantUnqualified(const AName: string; out Enm: TASTEnumDecl; out VarN: TASTEnumVariant): Boolean;
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

function TAetherEmitterC.IsRecordName(const AName: string): Boolean;
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

function TAetherEmitterC.IsModulePrefixName(const AName: string): Boolean;
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

function TAetherEmitterC.ResolveAliasType(const AType: string): string;
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

function TAetherEmitterC.IsSetType(const AName: string): Boolean;
var
  I: Integer;
  T: string;
begin
  T := ResolveAliasType(AName);
  if (Pos('set of', T) > 0) or (T = 'SetLiteral') then
    Exit(True);
  Result := False;
  if Assigned(FModule) then
    for I := 0 to FModule.Types.Count - 1 do
      if (TASTNode(FModule.Types[I]) is TASTSetDecl) and
         SameText(TASTSetDecl(FModule.Types[I]).Name, T) then
        Exit(True);
end;

function TAetherEmitterC.IsDynamicArrayType(const AName: string): Boolean;
var
  I: Integer;
  T: string;
begin
  T := ResolveAliasType(AName);
  if Pos('array of ', T) = 1 then
    Exit(True);
  Result := False;
  if Assigned(FModule) then
    for I := 0 to FModule.Types.Count - 1 do
      if (TASTNode(FModule.Types[I]) is TASTArrayDecl) and
         SameText(TASTArrayDecl(FModule.Types[I]).Name, T) and
         (TASTArrayDecl(FModule.Types[I]).Dims.Count = 0) then
        Exit(True);
end;

function TAetherEmitterC.IsFixedArrayType(const AName: string): Boolean;
var
  I: Integer;
  T: string;
begin
  T := ResolveAliasType(AName);
  if Pos('array[', LowerCase(T)) = 1 then
    Exit(True);
  Result := False;
  if Assigned(FModule) then
    for I := 0 to FModule.Types.Count - 1 do
      if (TASTNode(FModule.Types[I]) is TASTArrayDecl) and
         SameText(TASTArrayDecl(FModule.Types[I]).Name, T) and
         (TASTArrayDecl(FModule.Types[I]).Dims.Count > 0) then
        Exit(True);
end;

function TAetherEmitterC.IsValueOptionType(const AType: string): Boolean;
var
  T, Inner: string;
begin
  T := ResolveAliasType(AType);
  if Pos('Option<', T) <> 1 then Exit(False);
  Inner := ResolveAliasType(Trim(Copy(T, 8, Length(T) - 8)));
  Result := (Inner <> '') and (Pos('Box<', Inner) <> 1) and (Pos('^', Inner) <> 1) and (Inner <> 'Pointer');
end;

function TAetherEmitterC.SplitResultTypes(const AType: string; out ValType, ErrType: string): Boolean;
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

function TAetherEmitterC.SafeUnwrapGeneric(const AType, Prefix: string): string;
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

function TAetherEmitterC.SplitFnType(const AType: string; ParamTypes: TStrings; out RetType: string): Boolean;
var
  T, ParamStr, Cur: string;
  P, PArrow, Depth, I: Integer;
begin
  Result := False;
  if Assigned(ParamTypes) then ParamTypes.Clear;
  RetType := '';
  T := ResolveAliasType(Trim(AType));
  if Pos('fn(', T) <> 1 then Exit;
  Depth := 0;
  PArrow := 0;
  P := 3;
  for I := P to Length(T) do
  begin
    if (T[I] = '(') or (T[I] = '<') or (T[I] = '[') then Inc(Depth)
    else if (T[I] = ')') or (T[I] = '>') or (T[I] = ']') then
    begin
      Dec(Depth);
      if Depth = 0 then
      begin
        ParamStr := Trim(Copy(T, P + 1, I - P - 1));
        if Copy(T, I + 1, 4) = ' -> ' then
          PArrow := I + 5
        else if Copy(T, I + 1, 2) = '->' then
          PArrow := I + 3;
        Break;
      end;
    end;
  end;
  if PArrow = 0 then Exit;
  RetType := Trim(Copy(T, PArrow, Length(T)));
  if RetType = '' then RetType := 'Void';
  if Assigned(ParamTypes) and (ParamStr <> '') then
  begin
    Cur := '';
    Depth := 0;
    for I := 1 to Length(ParamStr) do
    begin
      if (ParamStr[I] = '(') or (ParamStr[I] = '<') or (ParamStr[I] = '[') then
      begin
        Inc(Depth);
        Cur := Cur + ParamStr[I];
      end
      else if (ParamStr[I] = ')') or (ParamStr[I] = '>') or (ParamStr[I] = ']') then
      begin
        Dec(Depth);
        Cur := Cur + ParamStr[I];
      end
      else if (ParamStr[I] = ',') and (Depth = 0) then
      begin
        if Trim(Cur) <> '' then ParamTypes.Add(Trim(Cur));
        Cur := '';
      end
      else
        Cur := Cur + ParamStr[I];
    end;
    if Trim(Cur) <> '' then ParamTypes.Add(Trim(Cur));
  end;
  Result := True;
end;

function TAetherEmitterC.FnTypeTag(const AType: string): string;
var
  Params: TStringList;
  RetT, S: string;
  I: Integer;
begin
  Params := TStringList.Create;
  try
    if not SplitFnType(AType, Params, RetT) then
    begin
      S := '';
      for I := 1 to Length(AType) do
        if AType[I] in ['a'..'z', 'A'..'Z', '0'..'9', '_'] then
          S := S + AType[I]
        else
          S := S + '_';
      Exit(S);
    end;
    S := 'P' + IntToStr(Params.Count);
    for I := 0 to Params.Count - 1 do
      S := S + '_' + MangleTypeTag(Params[I]);
    S := S + '_R_' + MangleTypeTag(RetT);
    Result := S;
  finally
    Params.Free;
  end;
end;

function TAetherEmitterC.RegisterFnType(const AType: string): string;
var
  T, Tag: string;
begin
  T := ResolveAliasType(Trim(AType));
  if Pos('fn(', T) <> 1 then Exit('');
  Tag := FnTypeTag(T);
  if FFnTags.IndexOf(Tag) = -1 then
  begin
    FFnTags.Add(Tag);
    FFnSigs.Add(T);
  end;
  Result := Tag;
end;

procedure TAetherEmitterC.RegisterLambda(L: TASTLambdaExpr);
begin
  if Assigned(L) and (FLambdas.IndexOf(L) = -1) then
    FLambdas.Add(L);
end;

procedure TAetherEmitterC.RegisterThunkFunc(const AFuncName: string);
begin
  if (AFuncName <> '') and (FThunkFuncs.IndexOf(AFuncName) = -1) then
    FThunkFuncs.Add(AFuncName);
end;

function TAetherEmitterC.MangleTypeTag(const AType: string): string;
var
  T, ValT, ErrT, InnerT, Res: string;
  I: Integer;
  Ch: Char;
begin
  T := ResolveAliasType(Trim(AType));
  if T = '' then Exit('Void');
  if Pos('fn(', T) = 1 then
    Exit('Fn_' + FnTypeTag(T));
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

function TAetherEmitterC.IsCompoundMonadType(const AType: string): Boolean;
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

  if (Pos('array of ', T) = 1) or (Pos('array[', T) = 1) or
     (Pos('Option<', T) = 1) or (Pos('Result<', T) = 1) or (Pos('fn(', T) = 1) or IsMapType(T, K, V) then
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

function TAetherEmitterC.IsTypedValueOption(const AType: string; out InnerT: string): Boolean;
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

function TAetherEmitterC.IsTypedResult(const AType: string; out ValT, ErrT: string): Boolean;
begin
  if not SplitResultTypes(AType, ValT, ErrT) then Exit(False);
  ValT := ResolveAliasType(ValT);
  ErrT := ResolveAliasType(ErrT);
  if (ValT = 'GenericValue') or (ErrT = 'GenericError') or (ValT = 'IntLiteral') or (ValT = 'FloatLiteral') then
    Exit(False);
  Result := IsCompoundMonadType(ValT) or IsCompoundMonadType(ErrT);
end;

function TAetherEmitterC.GetMatchArmBindingCount(CaseNode: TASTMatchCase): Integer;
begin
  if CaseNode.Pattern.Bindings.Count > 0 then
    Result := CaseNode.Pattern.Bindings.Count
  else if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') then
    Result := 1
  else
    Result := 0;
end;

procedure TAetherEmitterC.GetMatchArmBindingInfo(CaseNode: TASTMatchCase; Idx: Integer; const MatchedType: string;
  out BindName, BindType: string);
var
  PatStr, ValF, ErrF, EnmName, VarName: string;
  PDot, J: Integer;
  Enm: TASTEnumDecl;
  VarN: TASTEnumVariant;
begin
  if CaseNode.Pattern.Bindings.Count > 0 then
    BindName := CaseNode.Pattern.Bindings[Idx]
  else
    BindName := CaseNode.Pattern.SubPattern;

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

procedure TAetherEmitterC.PushMatchBindings(CaseNode: TASTMatchCase; const MatchedType: string);
var
  I, Cnt: Integer;
  BName, BType: string;
begin
  Cnt := GetMatchArmBindingCount(CaseNode);
  for I := 0 to Cnt - 1 do
  begin
    GetMatchArmBindingInfo(CaseNode, I, MatchedType, BName, BType);
    if (BName <> '') and (BName <> '_') then
    begin
      FMatchBindNames.Add(BName);
      FMatchBindTypes.Add(BType);
    end;
  end;
end;

procedure TAetherEmitterC.PopMatchBindings(Count: Integer);
var
  I: Integer;
begin
  for I := 1 to Count do
  begin
    if FMatchBindNames.Count > 0 then
    begin
      FMatchBindNames.Delete(FMatchBindNames.Count - 1);
      FMatchBindTypes.Delete(FMatchBindTypes.Count - 1);
    end;
  end;
end;

procedure TAetherEmitterC.CollectTypedMonadsFromType(const AType: string; OptTags, OptInners, ResTags, ResVals, ResErrs: TStrings);
var
  T, InnerT, ValT, ErrT, Tag, KeyT, ValM, RetT: string;
  FnParams: TStringList;
  I: Integer;
begin
  T := ResolveAliasType(Trim(AType));
  if T = '' then Exit;
  if Pos('fn(', T) = 1 then
  begin
    RegisterFnType(T);
    FnParams := TStringList.Create;
    try
      if SplitFnType(T, FnParams, RetT) then
      begin
        for I := 0 to FnParams.Count - 1 do
          CollectTypedMonadsFromType(FnParams[I], OptTags, OptInners, ResTags, ResVals, ResErrs);
        CollectTypedMonadsFromType(RetT, OptTags, OptInners, ResTags, ResVals, ResErrs);
      end;
    finally
      FnParams.Free;
    end;
    Exit;
  end;
  if Pos('^', T) = 1 then
  begin
    CollectTypedMonadsFromType(Copy(T, 2, Length(T)), OptTags, OptInners, ResTags, ResVals, ResErrs);
    Exit;
  end;
  if Pos('array of ', T) = 1 then
  begin
    CollectTypedMonadsFromType(Copy(T, 10, Length(T)), OptTags, OptInners, ResTags, ResVals, ResErrs);
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

procedure TAetherEmitterC.CollectTypedMonadsFromExpr(Expr: TASTExpr; OptTags, OptInners, ResTags, ResVals, ResErrs: TStrings);
var
  I, Cnt, AddedB: Integer;
  Call: TASTCallExpr;
  ME: TASTMatchExpr;
  CaseN: TASTMatchCase;
  MT, BName, BType: string;
begin
  if not Assigned(Expr) then Exit;
  if Expr is TASTIdentifierExpr then
  begin
    if TASTIdentifierExpr(Expr).ResolvedMonadType <> '' then
      CollectTypedMonadsFromType(TASTIdentifierExpr(Expr).ResolvedMonadType, OptTags, OptInners, ResTags, ResVals, ResErrs);
    if TASTIdentifierExpr(Expr).IsFnValueRef and (TASTIdentifierExpr(Expr).ResolvedFnType <> '') then
    begin
      CollectTypedMonadsFromType(TASTIdentifierExpr(Expr).ResolvedFnType, OptTags, OptInners, ResTags, ResVals, ResErrs);
      RegisterThunkFunc(TASTIdentifierExpr(Expr).Name);
    end;
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
        GetMatchArmBindingInfo(CaseN, AddedB, MT, BName, BType);
        if (BName <> '') and (BName <> '_') then
        begin
          FMatchBindNames.Add(BName);
          FMatchBindTypes.Add(BType);
        end;
      end;
      try
        CollectTypedMonadsFromExpr(CaseN.Guard, OptTags, OptInners, ResTags, ResVals, ResErrs);
        CollectTypedMonadsFromExpr(CaseN.ValueExpr, OptTags, OptInners, ResTags, ResVals, ResErrs);
      finally
        for AddedB := 0 to Cnt - 1 do
        begin
          GetMatchArmBindingInfo(CaseN, AddedB, MT, BName, BType);
          if (BName <> '') and (BName <> '_') then PopMatchBindings(1);
        end;
      end;
    end;
  end
  else if Expr is TASTTupleLiteralExpr then
  begin
    if TASTTupleLiteralExpr(Expr).ResolvedType <> '' then
      CollectTypedMonadsFromType(TASTTupleLiteralExpr(Expr).ResolvedType, OptTags, OptInners, ResTags, ResVals, ResErrs);
    for I := 0 to TASTTupleLiteralExpr(Expr).Elements.Count - 1 do
      CollectTypedMonadsFromExpr(TASTExpr(TASTTupleLiteralExpr(Expr).Elements[I]), OptTags, OptInners, ResTags, ResVals, ResErrs);
  end
  else if Expr is TASTLambdaExpr then
  begin
    RegisterLambda(TASTLambdaExpr(Expr));
    if TASTLambdaExpr(Expr).ResolvedFnType <> '' then
      CollectTypedMonadsFromType(TASTLambdaExpr(Expr).ResolvedFnType, OptTags, OptInners, ResTags, ResVals, ResErrs);
    for I := 0 to TASTLambdaExpr(Expr).Params.Count - 1 do
      CollectTypedMonadsFromType(TASTParam(TASTLambdaExpr(Expr).Params[I]).TypeName, OptTags, OptInners, ResTags, ResVals, ResErrs);
    if TASTLambdaExpr(Expr).ReturnType <> '' then
      CollectTypedMonadsFromType(TASTLambdaExpr(Expr).ReturnType, OptTags, OptInners, ResTags, ResVals, ResErrs);
    for I := 0 to TASTLambdaExpr(Expr).CaptureTypes.Count - 1 do
      CollectTypedMonadsFromType(TASTLambdaExpr(Expr).CaptureTypes[I], OptTags, OptInners, ResTags, ResVals, ResErrs);
    CollectTypedMonadsFromExpr(TASTLambdaExpr(Expr).BodyExpr, OptTags, OptInners, ResTags, ResVals, ResErrs);
    CollectTypedMonadsFromStmts(TASTLambdaExpr(Expr).BodyStmts, OptTags, OptInners, ResTags, ResVals, ResErrs);
  end;
end;

procedure TAetherEmitterC.CollectTypedMonadsFromStmts(Stmts: TASTNodeList; OptTags, OptInners, ResTags, ResVals, ResErrs: TStrings);
var
  I, J, K, Cnt: Integer;
  S: TASTStmt;
  VD: TASTVarDecl;
  ForS: TASTForStmt;
  MS: TASTMatchStmt;
  CN: TASTMatchCase;
  MT, BName, BType: string;
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
          GetMatchArmBindingInfo(CN, J, MT, BName, BType);
          if (BName <> '') and (BName <> '_') then
          begin
            FMatchBindNames.Add(BName);
            FMatchBindTypes.Add(BType);
          end;
        end;
        try
          CollectTypedMonadsFromExpr(CN.Guard, OptTags, OptInners, ResTags, ResVals, ResErrs);
          CollectTypedMonadsFromStmts(CN.Body, OptTags, OptInners, ResTags, ResVals, ResErrs);
        finally
          for J := 0 to Cnt - 1 do
          begin
            GetMatchArmBindingInfo(CN, J, MT, BName, BType);
            if (BName <> '') and (BName <> '_') then PopMatchBindings(1);
          end;
        end;
      end;
    end;
  end;
end;

procedure TAetherEmitterC.CollectTypedMonadsFromModule(AModule: TASTModule; OptTags, OptInners, ResTags, ResVals, ResErrs: TStrings);
var
  I, J, K: Integer;
  Node: TASTNode;
  Rec: TASTRecordDecl;
  Enm: TASTEnumDecl;
  VarN: TASTEnumVariant;
  Func, OldFunc: TASTFunction;
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

procedure TAetherEmitterC.EmitTypedOptionDecl(const Tag, InnerT: string);
begin
  Emit(Format('typedef struct { bool is_some; bool is_none; %s value; } AetherOpt_%s;', [EmitTypeRef(InnerT), Tag]));
end;

procedure TAetherEmitterC.EmitTypedResultDecl(const Tag, ValT, ErrT: string);
begin
  Emit(Format('typedef struct { bool is_ok; bool is_err; %s value; %s error; } AetherRes_%s;',
    [EmitTypeRef(ValT), EmitTypeRef(ErrT), Tag]));
end;

procedure TAetherEmitterC.EmitTypedMonadHelpers(OptTags, OptInners, ResTags, ResVals, ResErrs: TStrings);
var
  I: Integer;
  T, InnerC, ValC, ErrC: string;
begin
  for I := 0 to OptTags.Count - 1 do
  begin
    T := OptTags[I];
    InnerC := EmitTypeRef(OptInners[I]);
    Emit(Format('static inline AetherOpt_%s AetherSome_%s(%s v) { AetherOpt_%s r; memset(&r, 0, sizeof(r)); r.is_some = true; r.value = v; return r; }',
      [T, T, InnerC, T]));
    Emit(Format('static inline AetherOpt_%s AetherNone_%s(void) { AetherOpt_%s r; memset(&r, 0, sizeof(r)); r.is_none = true; return r; }',
      [T, T, T]));
  end;

  for I := 0 to ResTags.Count - 1 do
  begin
    T := ResTags[I];
    ValC := EmitTypeRef(ResVals[I]);
    ErrC := EmitTypeRef(ResErrs[I]);
    Emit(Format('static inline AetherRes_%s AetherOk_%s(%s v) { AetherRes_%s r; memset(&r, 0, sizeof(r)); r.is_ok = true; r.value = v; return r; }',
      [T, T, ValC, T]));
    Emit(Format('static inline AetherRes_%s AetherErr_%s(%s e) { AetherRes_%s r; memset(&r, 0, sizeof(r)); r.is_err = true; r.error = e; return r; }',
      [T, T, ErrC, T]));
  end;
  if (OptTags.Count > 0) or (ResTags.Count > 0) then Emit('');
end;

procedure TAetherEmitterC.EmitTopologicalTypesAndMonads(const TypeUsed: array of Boolean;
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
  FnParams: TStringList;
  FnRet, CRet, ParamList: string;

  procedure AddDepToList(Deps: TStrings; const TStr: string);
  var
    T, InnerT, VT, ET, M: string;
    POf: Integer;
  begin
    T := ResolveAliasType(Trim(TStr));
    if (T = '') or (Pos('^', T) = 1) or (Pos('Box<', T) = 1) or
       (T = 'Int8') or (T = 'Int16') or (T = 'Int32') or (T = 'Int64') or
       (T = 'UInt8') or (T = 'UInt16') or (T = 'UInt32') or (T = 'UInt64') or
       (T = 'Float32') or (T = 'Float64') or (T = 'Bool') or (T = 'Char') or
       (T = 'String') or (T = 'Pointer') then
      Exit;
    if Pos('fn(', T) = 1 then
    begin
      Deps.Add('__FN_' + UpperCase(FnTypeTag(T)));
      Exit;
    end;
    if Pos('array of ', T) = 1 then
    begin
      AddDepToList(Deps, Copy(T, 10, Length(T)));
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
    if (I <= High(OptUsed)) and OptUsed[I] then
    begin
      AppendItem(1, I, '__OPT_' + UpperCase(OptTags[I]));
      AddDepToList(ItemDeps[Count - 1], OptInners[I]);
    end;

  for I := 0 to ResTags.Count - 1 do
    if (I <= High(ResUsed)) and ResUsed[I] then
    begin
      AppendItem(2, I, '__RES_' + UpperCase(ResTags[I]));
      AddDepToList(ItemDeps[Count - 1], ResVals[I]);
      AddDepToList(ItemDeps[Count - 1], ResErrs[I]);
    end;

  FnParams := TStringList.Create;
  try
    for I := 0 to FFnTags.Count - 1 do
    begin
      AppendItem(4, I, '__FN_' + UpperCase(FFnTags[I]));
      if SplitFnType(FFnSigs[I], FnParams, FnRet) then
      begin
        for J := 0 to FnParams.Count - 1 do
          AddDepToList(ItemDeps[Count - 1], FnParams[J]);
        AddDepToList(ItemDeps[Count - 1], FnRet);
      end;
    end;
  finally
    FnParams.Free;
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
        if Node is TASTRecordDecl then EmitRecordDecl(TASTRecordDecl(Node))
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
      else if ItemKind[ReadyIdx] = 4 then
      begin
        FnParams := TStringList.Create;
        try
          if SplitFnType(FFnSigs[ItemIdx[ReadyIdx]], FnParams, FnRet) then
          begin
            if (FnRet = '') or (FnRet = 'Void') then CRet := 'void'
            else CRet := EmitTypeRef(FnRet);
            ParamList := 'void* _env';
            for J := 0 to FnParams.Count - 1 do
              ParamList := ParamList + ', ' + EmitTypeRef(FnParams[J]);
            Emit(Format('typedef struct { %s (*fn)(%s); void* env; } AetherFn_%s;',
              [CRet, ParamList, FFnTags[ItemIdx[ReadyIdx]]]));
          end;
        finally
          FnParams.Free;
        end;
      end;
    end;
  finally
    for I := 0 to Count - 1 do
      ItemDeps[I].Free;
  end;
end;

procedure TAetherEmitterC.EmitFnRuntimeHelpers;
var
  I, J: Integer;
  FnParams: TStringList;
  FnRet, CRet, DeclParams, CallArgs: string;
  IsVoid: Boolean;
  L: TASTLambdaExpr;
begin
  FnParams := TStringList.Create;
  try
    for I := 0 to FFnTags.Count - 1 do
    begin
      if SplitFnType(FFnSigs[I], FnParams, FnRet) then
      begin
        IsVoid := (FnRet = '') or (FnRet = 'Void');
        if IsVoid then CRet := 'void' else CRet := EmitTypeRef(FnRet);
        DeclParams := Format('AetherFn_%s _fn', [FFnTags[I]]);
        CallArgs := '_fn.env';
        for J := 0 to FnParams.Count - 1 do
        begin
          DeclParams := DeclParams + Format(', %s _p%d', [EmitTypeRef(FnParams[J]), J]);
          CallArgs := CallArgs + Format(', _p%d', [J]);
        end;
        if IsVoid then
          Emit(Format('static inline void AetherCallFn_%s(%s) { _fn.fn(%s); }',
            [FFnTags[I], DeclParams, CallArgs]))
        else
          Emit(Format('static inline %s AetherCallFn_%s(%s) { return _fn.fn(%s); }',
            [CRet, FFnTags[I], DeclParams, CallArgs]));
      end;
    end;
  finally
    FnParams.Free;
  end;

  for I := 0 to FLambdas.Count - 1 do
  begin
    L := TASTLambdaExpr(FLambdas[I]);
    if L.CaptureNames.Count > 0 then
    begin
      Emit('typedef struct {');
      IncIndent;
      for J := 0 to L.CaptureNames.Count - 1 do
        Emit(Format('%s %s;', [EmitTypeRef(L.CaptureTypes[J]), L.CaptureNames[J]]));
      DecIndent;
      Emit(Format('} AetherEnv_lambda_%d;', [L.LambdaId]));
    end;
  end;
  if (FFnTags.Count > 0) or (FLambdas.Count > 0) then Emit('');
end;

procedure TAetherEmitterC.EmitLambdaAndThunkDecls(ForwardOnly: Boolean);
var
  I, J: Integer;
  Func, TempFunc, OldFunc: TASTFunction;
  OldProg: TASTProgramBlock;
  OldScope, OldBody: TASTNodeList;
  L: TASTLambdaExpr;
  P, NewP: TASTParam;
  NewV: TASTVarDecl;
  FnParams, SkipNames, AutoNames, AutoTypes: TStringList;
  RetType, CRet, ParamDecls, CallArgs, CapDecls, FnTag: string;
  IsVoid: Boolean;
begin
  for I := 0 to FThunkFuncs.Count - 1 do
  begin
    Func := FindFunction(FThunkFuncs[I]);
    if not Assigned(Func) then Continue;
    IsVoid := (Func.ReturnType = '') or (Func.ReturnType = 'Void');
    if IsVoid then CRet := 'void' else CRet := EmitTypeRef(Func.ReturnType);
    ParamDecls := 'void* _env';
    CallArgs := '';
    for J := 0 to Func.Params.Count - 1 do
    begin
      P := TASTParam(Func.Params[J]);
      ParamDecls := ParamDecls + Format(', %s %s', [EmitTypeRef(P.TypeName), P.Name]);
      if J > 0 then CallArgs := CallArgs + ', ';
      if P.Ownership = owMutBorrow then
        CallArgs := CallArgs + '&' + P.Name
      else
        CallArgs := CallArgs + P.Name;
    end;
    if ForwardOnly then
      Emit(Format('static %s __aether_thunk_%s(%s);', [CRet, Func.Name, ParamDecls]))
    else
    begin
      Emit(Format('static %s __aether_thunk_%s(%s) {', [CRet, Func.Name, ParamDecls]));
      IncIndent;
      Emit('(void)_env;');
      if IsVoid then
        Emit(Format('%s(%s);', [Func.Name, CallArgs]))
      else
        Emit(Format('return %s(%s);', [Func.Name, CallArgs]));
      DecIndent;
      Emit('}');
      Emit('');
    end;
  end;

  FnParams := TStringList.Create;
  try
    for I := 0 to FLambdas.Count - 1 do
    begin
      L := TASTLambdaExpr(FLambdas[I]);
      RetType := L.ReturnType;
      if (L.ResolvedFnType <> '') and SplitFnType(L.ResolvedFnType, FnParams, RetType) then
      begin
        if RetType = '' then RetType := L.ReturnType;
      end;
      IsVoid := (RetType = '') or (RetType = 'Void');
      if IsVoid then CRet := 'void' else CRet := EmitTypeRef(RetType);

      ParamDecls := 'void* _env';
      for J := 0 to L.Params.Count - 1 do
      begin
        P := TASTParam(L.Params[J]);
        ParamDecls := ParamDecls + Format(', %s %s', [EmitTypeRef(P.TypeName), P.Name]);
      end;

      FnTag := '';
      CapDecls := '';
      if L.CaptureNames.Count > 0 then
      begin
        FnTag := RegisterFnType(L.ResolvedFnType);
        for J := 0 to L.CaptureNames.Count - 1 do
        begin
          if J > 0 then CapDecls := CapDecls + ', ';
          CapDecls := CapDecls + Format('%s %s', [EmitTypeRef(L.CaptureTypes[J]), L.CaptureNames[J]]);
        end;
      end;

      if ForwardOnly then
      begin
        Emit(Format('static %s __aether_lambda_%d(%s);', [CRet, L.LambdaId, ParamDecls]));
        if L.CaptureNames.Count > 0 then
          Emit(Format('static AetherFn_%s __aether_make_lambda_%d(%s);', [FnTag, L.LambdaId, CapDecls]));
      end
      else
      begin
        Emit(Format('static %s __aether_lambda_%d(%s) {', [CRet, L.LambdaId, ParamDecls]));
        IncIndent;
        OldFunc := FCurrentFunc;
        OldProg := FProgramBlock;
        OldScope := FCurrentScopeList;
        TempFunc := TASTFunction.Create(L.Line, L.Col, '__aether_lambda_' + IntToStr(L.LambdaId), RetType);
        OldBody := TempFunc.Body;
        try
          for J := 0 to L.Params.Count - 1 do
          begin
            P := TASTParam(L.Params[J]);
            NewP := TASTParam.Create(P.Line, P.Col, P.Name, P.TypeName, owNone);
            TempFunc.Params.Add(NewP);
          end;
          for J := 0 to L.CaptureNames.Count - 1 do
          begin
            NewV := TASTVarDecl.Create(L.Line, L.Col, L.CaptureNames[J], L.CaptureTypes[J]);
            TempFunc.LocalVars.Add(NewV);
          end;
          if Assigned(L.BodyStmts) then
            TempFunc.Body := L.BodyStmts;

          FCurrentFunc := TempFunc;
          FProgramBlock := nil;
          FActiveDefers.Clear;
          FLoopDeferBase := 0;
          FRaiiNames.Clear;
          FRaiiTypes.Clear;
          FLoopRaiiBase := 0;
          FTryDepth := 0;

          if L.CaptureNames.Count > 0 then
          begin
            Emit(Format('AetherEnv_lambda_%d* _e = (AetherEnv_lambda_%d*)_env;', [L.LambdaId, L.LambdaId]));
            for J := 0 to L.CaptureNames.Count - 1 do
              Emit(Format('%s %s = _e->%s;', [EmitTypeRef(L.CaptureTypes[J]), L.CaptureNames[J], L.CaptureNames[J]]));
          end
          else
            Emit('(void)_env;');

          if Assigned(L.BodyExpr) then
          begin
            if IsVoid then
              Emit(EmitExpr(L.BodyExpr) + ';')
            else
              Emit('return ' + EmitExpr(L.BodyExpr) + ';');
          end
          else if Assigned(L.BodyStmts) then
          begin
            if not IsVoid then
            begin
              Emit(Format('%s result;', [CRet]));
              Emit('memset(&result, 0, sizeof(result));');
            end;
            SkipNames := TStringList.Create;
            AutoNames := TStringList.Create;
            AutoTypes := TStringList.Create;
            try
              for J := 0 to TempFunc.Params.Count - 1 do
                SkipNames.Add(TASTParam(TempFunc.Params[J]).Name);
              for J := 0 to TempFunc.LocalVars.Count - 1 do
                SkipNames.Add(TASTVarDecl(TempFunc.LocalVars[J]).Name);
              CollectAutoForVars(L.BodyStmts, AutoNames, AutoTypes, SkipNames);
              for J := 0 to AutoNames.Count - 1 do
                Emit(Format('%s %s;', [AutoTypes[J], AutoNames[J]]));
            finally
              SkipNames.Free;
              AutoNames.Free;
              AutoTypes.Free;
            end;
            FCurrentScopeList := L.BodyStmts;
            EmitStmtList(L.BodyStmts);
            if (L.BodyStmts.Count = 0) or not (L.BodyStmts[L.BodyStmts.Count - 1] is TASTReturnStmt) then
            begin
              if FRaiiNames.Count > 0 then
                EmitActiveRaii(0);
              if not IsVoid then
                Emit('return result;');
            end;
          end;
        finally
          TempFunc.Body := OldBody;
          TempFunc.Free;
          FCurrentFunc := OldFunc;
          FProgramBlock := OldProg;
          FCurrentScopeList := OldScope;
          FActiveDefers.Clear;
          FRaiiNames.Clear;
          FRaiiTypes.Clear;
        end;
        DecIndent;
        Emit('}');
        Emit('');

        if L.CaptureNames.Count > 0 then
        begin
          Emit(Format('static AetherFn_%s __aether_make_lambda_%d(%s) {', [FnTag, L.LambdaId, CapDecls]));
          IncIndent;
          Emit(Format('AetherEnv_lambda_%d* _env = (AetherEnv_lambda_%d*)malloc(sizeof(AetherEnv_lambda_%d));',
            [L.LambdaId, L.LambdaId, L.LambdaId]));
          Emit('memset(_env, 0, sizeof(*_env));');
          for J := 0 to L.CaptureNames.Count - 1 do
            Emit(Format('_env->%s = %s;', [L.CaptureNames[J], L.CaptureNames[J]]));
          Emit(Format('return (AetherFn_%s){ __aether_lambda_%d, _env };', [FnTag, L.LambdaId]));
          DecIndent;
          Emit('}');
          Emit('');
        end;
      end;
    end;
  finally
    FnParams.Free;
  end;
  if ForwardOnly and ((FThunkFuncs.Count > 0) or (FLambdas.Count > 0)) then Emit('');
end;

function TAetherEmitterC.IsTypeIdentifier(const AName: string): Boolean;
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

function TAetherEmitterC.EmitMonadFieldExtract(const ExprStr, FieldType, NumField, StrField: string): string;
var
  R: string;
begin
  R := ResolveAliasType(FieldType);
  if R = 'String' then
    Result := ExprStr + '.' + StrField
  else if R = 'Bool' then
    Result := Format('(%s.%s != 0)', [ExprStr, NumField])
  else if R = 'Char' then
    Result := Format('((char)(int)(%s.%s))', [ExprStr, NumField])
  else if IsIntCType(R) or IsEnumName(R) then
    Result := Format('((%s)(%s.%s))', [EmitTypeRef(FieldType), ExprStr, NumField])
  else
    Result := ExprStr + '.' + NumField;
end;

procedure TAetherEmitterC.EmitArrayLiteralAssign(const TargetStr, TargetType: string; SetLit: TASTSetLiteralExpr);
var
  I: Integer;
begin
  if IsDynamicArrayType(TargetType) then
    Emit(Format('%s = (__typeof__(%s))AetherDynSetLength(%s, sizeof(*(%s)), %d);',
      [TargetStr, TargetStr, TargetStr, TargetStr, SetLit.Elements.Count]));
  for I := 0 to SetLit.Elements.Count - 1 do
    Emit(Format('(%s)[%d] = %s;', [TargetStr, I, EmitExpr(TASTExpr(SetLit.Elements[I]))]));
end;

procedure TAetherEmitterC.EmitMapLiteralAssign(const TargetStr, TargetType: string; MapLit: TASTMapLiteralExpr);
var
  I: Integer;
  K, V, Tag: string;
begin
  if IsMapType(TargetType, K, V) then
  begin
    Tag := MapTag(K, V);
    Emit(Format('memset(&(%s), 0, sizeof(%s));', [TargetStr, TargetStr]));
    for I := 0 to MapLit.Keys.Count - 1 do
      Emit(Format('AetherMapSet_%s(&(%s), %s, %s);',
        [Tag, TargetStr, EmitExpr(TASTExpr(MapLit.Keys[I])), EmitExpr(TASTExpr(MapLit.Values[I]))]));
  end;
end;

function TAetherEmitterC.IsVarModifiedInTry(const AVarName: string; Nodes: TASTNodeList; InTry: Boolean): Boolean;
var
  I, J: Integer;
  S: TASTStmt;
begin
  Result := False;
  if not Assigned(Nodes) then Exit;
  for I := 0 to Nodes.Count - 1 do
  begin
    if not (Nodes[I] is TASTStmt) then Continue;
    S := TASTStmt(Nodes[I]);
    if S is TASTTryStmt then
    begin
      if IsVarModifiedInTry(AVarName, TASTTryStmt(S).TryBody, True) or
         IsVarModifiedInTry(AVarName, TASTTryStmt(S).ExceptBody, InTry) then
        Exit(True);
    end
    else if InTry and (S is TASTAssignStmt) and (TASTAssignStmt(S).Target is TASTIdentifierExpr) and
            SameText(TASTIdentifierExpr(TASTAssignStmt(S).Target).Name, AVarName) then
      Exit(True)
    else if S is TASTIfStmt then
    begin
      if IsVarModifiedInTry(AVarName, TASTIfStmt(S).ThenBranch, InTry) or
         IsVarModifiedInTry(AVarName, TASTIfStmt(S).ElseBranch, InTry) then
        Exit(True);
    end
    else if S is TASTWhileStmt then
    begin
      if IsVarModifiedInTry(AVarName, TASTWhileStmt(S).Body, InTry) then Exit(True);
    end
    else if S is TASTForStmt then
    begin
      if InTry and SameText(TASTForStmt(S).VarName, AVarName) then Exit(True);
      if IsVarModifiedInTry(AVarName, TASTForStmt(S).Body, InTry) then Exit(True);
    end
    else if S is TASTRepeatStmt then
    begin
      if IsVarModifiedInTry(AVarName, TASTRepeatStmt(S).Body, InTry) then Exit(True);
    end
    else if S is TASTUnsafeStmt then
    begin
      if IsVarModifiedInTry(AVarName, TASTUnsafeStmt(S).Body, InTry) then Exit(True);
    end
    else if S is TASTMatchStmt then
    begin
      for J := 0 to TASTMatchStmt(S).Cases.Count - 1 do
        if IsVarModifiedInTry(AVarName, TASTMatchCase(TASTMatchStmt(S).Cases[J]).Body, InTry) then
          Exit(True);
    end;
  end;
end;

function TAetherEmitterC.IsMutBorrowParam(const AName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Assigned(FCurrentFunc) then
    for I := 0 to FCurrentFunc.Params.Count - 1 do
      if SameText(TASTParam(FCurrentFunc.Params[I]).Name, AName) and
         (TASTParam(FCurrentFunc.Params[I]).Ownership = owMutBorrow) then
        Exit(True);
end;

function TAetherEmitterC.FindFunction(const AName: string): TASTFunction;
var
  I: Integer;
begin
  Result := nil;
  if Assigned(FModule) then
    for I := 0 to FModule.Functions.Count - 1 do
      if SameText(TASTFunction(FModule.Functions[I]).Name, AName) then
        Exit(TASTFunction(FModule.Functions[I]));
end;

function TAetherEmitterC.EscapeCString(const S: string): string;
var
  I: Integer;
begin
  Result := '"';
  for I := 1 to Length(S) do
  begin
    case S[I] of
      '\': Result := Result + '\\';
      '"': Result := Result + '\"';
      #0:  Result := Result + '\0';
      #10: Result := Result + '\n';
      #13: Result := Result + '\r';
      #9:  Result := Result + '\t';
    else
      Result := Result + S[I];
    end;
  end;
  Result := Result + '"';
end;

function TAetherEmitterC.EscapeCChar(const S: string): string;
begin
  if Length(S) = 0 then Exit('''\0''');
  case S[1] of
    #0:  Result := '''\0''';
    #9:  Result := '''\t''';
    #10: Result := '''\n''';
    #13: Result := '''\r''';
    '\': Result := '''\\''';
    '''': Result := '''\''''';
  else
    if S[1] in [#1..#31, #127] then
      Result := Format('''\x%.2x''', [Ord(S[1])])
    else
      Result := '''' + S[1] + '''';
  end;
end;

function TAetherEmitterC.IsMapType(const AType: string; out KeyType, ValType: string): Boolean;
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

function SanitizeCTagPart(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    if S[I] in ['a'..'z', 'A'..'Z', '0'..'9', '_'] then
      Result := Result + S[I]
    else if S[I] = '^' then
      Result := Result + 'Ptr_'
    else
      Result := Result + '_';
end;

function TAetherEmitterC.MapTag(const K, V: string): string;
begin
  Result := SanitizeCTagPart(K) + '_' + SanitizeCTagPart(V);
end;

function TAetherEmitterC.NormalizeIntLit(const Val: string): string;
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
  if (Length(Rest) >= 1) and (Rest[1] = '$') then
    Result := Prefix + '0x' + Copy(Rest, 2, Length(Rest))
  else if (Length(Rest) >= 1) and (Rest[1] = '%') then
    Result := Prefix + '0b' + Copy(Rest, 2, Length(Rest))
  else
    Result := Val;
end;

function TAetherEmitterC.IsIntCType(const AType: string): Boolean;
var
  I: Integer;
  T: string;
begin
  T := ResolveAliasType(AType);
  Result := (T = 'Int8') or (T = 'Int16') or (T = 'Int32') or (T = 'Int64') or
            (T = 'UInt8') or (T = 'UInt16') or (T = 'UInt32') or (T = 'UInt64') or
            (T = 'IntLiteral');
  if (not Result) and Assigned(FModule) then
  begin
    for I := 0 to FModule.Types.Count - 1 do
      if (FModule.Types[I] is TASTSubrangeDecl) and SameText(TASTSubrangeDecl(FModule.Types[I]).Name, T) then
        Exit(TASTSubrangeDecl(FModule.Types[I]).BaseType <> 'Char');
  end;
end;

function TAetherEmitterC.IsBuiltinMapSideType(const AType: string): Boolean;
begin
  Result := (AType = 'Int8') or (AType = 'Int16') or (AType = 'Int32') or (AType = 'Int64') or
            (AType = 'UInt8') or (AType = 'UInt16') or (AType = 'UInt32') or (AType = 'UInt64') or
            (AType = 'Float32') or (AType = 'Float64') or (AType = 'Bool') or (AType = 'Char') or
            (AType = 'String') or (AType = 'Pointer');
end;

function TAetherEmitterC.GetCollectionElemType(Expr: TASTExpr): string;
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

function TAetherEmitterC.FindInlineVarType(Stmts: TASTNodeList; const AName: string): string;
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

procedure TAetherEmitterC.CollectAutoForVars(Stmts: TASTNodeList; VarNames, VarTypes: TStrings; const SkipNames: TStrings);
var
  I, K: Integer;
  S: TASTStmt;
  ForStmt: TASTForStmt;
  ElemT, KeyT, ValT, ColT: string;

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
    if S is TASTForStmt then
    begin
      ForStmt := TASTForStmt(S);
      if Assigned(ForStmt.CollectionExpr) then
      begin
        ColT := GetExprTypeName(ForStmt.CollectionExpr);
        if IsMapType(ColT, KeyT, ValT) then
        begin
          AddAutoVar(ForStmt.VarName, EmitTypeRef(KeyT));
          if ForStmt.ValVarName <> '' then
            AddAutoVar(ForStmt.ValVarName, EmitTypeRef(ValT));
        end
        else
        begin
          ElemT := GetCollectionElemType(ForStmt.CollectionExpr);
          if ElemT <> '' then
            AddAutoVar(ForStmt.VarName, EmitTypeRef(ElemT))
          else
            AddAutoVar(ForStmt.VarName, 'int32_t');
        end;
      end
      else
        AddAutoVar(ForStmt.VarName, 'int32_t');
      CollectAutoForVars(ForStmt.Body, VarNames, VarTypes, SkipNames);
    end
    else if S is TASTIfStmt then
    begin
      CollectAutoForVars(TASTIfStmt(S).ThenBranch, VarNames, VarTypes, SkipNames);
      CollectAutoForVars(TASTIfStmt(S).ElseBranch, VarNames, VarTypes, SkipNames);
    end
    else if S is TASTWhileStmt then
      CollectAutoForVars(TASTWhileStmt(S).Body, VarNames, VarTypes, SkipNames)
    else if S is TASTRepeatStmt then
      CollectAutoForVars(TASTRepeatStmt(S).Body, VarNames, VarTypes, SkipNames)
    else if S is TASTUnsafeStmt then
      CollectAutoForVars(TASTUnsafeStmt(S).Body, VarNames, VarTypes, SkipNames)
    else if S is TASTTryStmt then
    begin
      CollectAutoForVars(TASTTryStmt(S).TryBody, VarNames, VarTypes, SkipNames);
      CollectAutoForVars(TASTTryStmt(S).ExceptBody, VarNames, VarTypes, SkipNames);
    end
    else if S is TASTMatchStmt then
    begin
      for K := 0 to TASTMatchStmt(S).Cases.Count - 1 do
        CollectAutoForVars(TASTMatchCase(TASTMatchStmt(S).Cases[K]).Body, VarNames, VarTypes, SkipNames);
    end;
  end;
end;

procedure TAetherEmitterC.CollectMapsFromType(const AType: string; Tags, Keys, Vals: TStrings);
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

procedure TAetherEmitterC.CollectMapsFromExpr(Expr: TASTExpr; Tags, Keys, Vals: TStrings);
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

procedure TAetherEmitterC.CollectMapsFromStmts(Stmts: TASTNodeList; Tags, Keys, Vals: TStrings);
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

procedure TAetherEmitterC.CollectMapsFromModule(AModule: TASTModule; Tags, Keys, Vals: TStrings);
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

procedure TAetherEmitterC.EmitMapRuntimeDecls(Tags, Keys, Vals: TStrings; BuiltinOnly: Boolean);
var
  I: Integer;
  IsBuiltin: Boolean;
begin
  for I := 0 to Tags.Count - 1 do
  begin
    IsBuiltin := IsBuiltinMapSideType(Keys[I]) and IsBuiltinMapSideType(Vals[I]);
    if IsBuiltin = BuiltinOnly then
    begin
      Emit(Format('typedef struct { %s key; %s val; } TAetherMapEntry_%s;', [EmitTypeRef(Keys[I]), EmitTypeRef(Vals[I]), Tags[I]]));
      Emit(Format('typedef struct { TAetherMapEntry_%s* entries; int32_t count; int32_t capacity; } TAetherMap_%s;', [Tags[I], Tags[I]]));
    end;
  end;
  if Tags.Count > 0 then Emit('');
end;

procedure TAetherEmitterC.EmitMapRuntimeHelpers(Tags, Keys, Vals: TStrings);
var
  I: Integer;
  Tag, CK, CV, KeyEq, DefRet: string;
begin
  for I := 0 to Tags.Count - 1 do
  begin
    Tag := Tags[I];
    CK := EmitTypeRef(Keys[I]);
    CV := EmitTypeRef(Vals[I]);
    if Keys[I] = 'String' then
      KeyEq := '(m->entries[i].key == k || (m->entries[i].key && k && strcmp(m->entries[i].key, k) == 0))'
    else
      KeyEq := '(m->entries[i].key == k)';

    if Vals[I] = 'String' then DefRet := 'return "";'
    else if Vals[I] = 'Bool' then DefRet := 'return false;'
    else if Vals[I] = 'Char' then DefRet := 'return ''\0'';'
    else if (Vals[I] = 'Float32') or (Vals[I] = 'Float64') then DefRet := 'return 0.0;'
    else if IsIntCType(Vals[I]) then DefRet := 'return 0;'
    else if (Pos('^', Vals[I]) = 1) or (Vals[I] = 'Pointer') or (Pos('Box<', Vals[I]) > 0) then DefRet := 'return NULL;'
    else DefRet := Format('%s zero; memset(&zero, 0, sizeof(zero)); return zero;', [CV]);

    Emit(Format('static inline void AetherMapSet_%s(TAetherMap_%s* m, %s k, %s v) {', [Tag, Tag, CK, CV]));
    Emit('    for (int32_t i = 0; i < m->count; i++) {');
    Emit(Format('        if %s { m->entries[i].val = v; return; }', [KeyEq]));
    Emit('    }');
    Emit('    if (m->count >= m->capacity) {');
    Emit('        int32_t nc = (m->capacity == 0) ? 8 : m->capacity * 2;');
    Emit(Format('        m->entries = (TAetherMapEntry_%s*)realloc(m->entries, (size_t)nc * sizeof(TAetherMapEntry_%s));', [Tag, Tag]));
    Emit('        m->capacity = nc;');
    Emit('    }');
    Emit('    m->entries[m->count].key = k;');
    Emit('    m->entries[m->count].val = v;');
    Emit('    m->count++;');
    Emit('}');

    Emit(Format('static inline %s AetherMapGet_%s(const TAetherMap_%s* m, %s k) {', [CV, Tag, Tag, CK]));
    Emit('    for (int32_t i = 0; i < m->count; i++) {');
    Emit(Format('        if %s return m->entries[i].val;', [KeyEq]));
    Emit('    }');
    Emit('    ' + DefRet);
    Emit('}');

    Emit(Format('static inline bool AetherMapContains_%s(const TAetherMap_%s* m, %s k) {', [Tag, Tag, CK]));
    Emit('    for (int32_t i = 0; i < m->count; i++) {');
    Emit(Format('        if %s return true;', [KeyEq]));
    Emit('    }');
    Emit('    return false;');
    Emit('}');

    Emit(Format('static inline void AetherMapRemove_%s(TAetherMap_%s* m, %s k) {', [Tag, Tag, CK]));
    Emit('    for (int32_t i = 0; i < m->count; i++) {');
    Emit(Format('        if %s { m->count--; m->entries[i] = m->entries[m->count]; return; }', [KeyEq]));
    Emit('    }');
    Emit('}');
    Emit('');
  end;
end;

function TAetherEmitterC.GetExprTypeName(Expr: TASTExpr): string;
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
  FnRet: string;
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
    if IsSetType(GetExprTypeName(Bin.Left)) then Exit(GetExprTypeName(Bin.Left));
    if IsSetType(GetExprTypeName(Bin.Right)) then Exit(GetExprTypeName(Bin.Right));
    if (Bin.Op = '=') or (Bin.Op = '<>') or (Bin.Op = '<') or (Bin.Op = '<=') or
       (Bin.Op = '>') or (Bin.Op = '>=') or SameText(Bin.Op, 'implies') or SameText(Bin.Op, 'in') then
      Exit('Bool');
    if SameText(Bin.Op, 'and') or SameText(Bin.Op, 'or') then
    begin
      LeftType := GetExprTypeName(Bin.Left);
      if LeftType = 'Bool' then Exit('Bool');
      if IsIntCType(LeftType) then Exit(LeftType);
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
  else if Expr is TASTCallExpr then
  begin
    Call := TASTCallExpr(Expr);
    if Call.IsIndirectCall and (Call.IndirectFnType <> '') then
    begin
      FnParams := TStringList.Create;
      try
        if SplitFnType(Call.IndirectFnType, FnParams, FnRet) then
          Exit(FnRet);
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
  end
  else if Expr is TASTTupleLiteralExpr then
    Exit(TASTTupleLiteralExpr(Expr).ResolvedType)
  else if Expr is TASTLambdaExpr then
    Exit(TASTLambdaExpr(Expr).ResolvedFnType)
  else if Expr is TASTAwaitExpr then
  begin
    TargetType := GetExprTypeName(TASTAwaitExpr(Expr).Expr);
    if (Copy(TargetType, 1, 5) = 'Task<') and (TargetType[Length(TargetType)] = '>') then
      Exit(Copy(TargetType, 6, Length(TargetType) - 6))
    else
      Exit(TargetType);
  end
  else if Expr is TASTSpawnExpr then
  begin
    TargetType := GetExprTypeName(TASTSpawnExpr(Expr).CallExpr);
    Exit('Task<' + TargetType + '>');
  end;
end;

function TAetherEmitterC.IsPointerTarget(Expr: TASTExpr): Boolean;
var
  T: string;
begin
  T := ResolveAliasType(GetExprTypeName(Expr));
  Result := (Pos('Box<', T) > 0) or (Pos('Pointer', T) > 0) or (T = 'Box') or (Pos('^', T) = 1);
end;

function TAetherEmitterC.FormatCArrayVar(const AType, AName: string): string;
var
  P1, P2, I: Integer;
  DimsPart, ElemPart, DimsStr: string;
  DimsList: TStringList;
begin
  P1 := Pos('[', AType);
  P2 := Pos('] of ', AType);
  if (P1 > 0) and (P2 > P1) then
  begin
    DimsPart := Copy(AType, P1 + 1, P2 - P1 - 1);
    ElemPart := Copy(AType, P2 + 5, Length(AType));
    DimsList := TStringList.Create;
    try
      DimsList.CommaText := DimsPart;
      DimsStr := '';
      for I := 0 to DimsList.Count - 1 do
        DimsStr := DimsStr + Format('[%s]', [Trim(DimsList[I])]);
      Result := Format('%s %s%s;', [EmitTypeRef(Trim(ElemPart)), AName, DimsStr]);
    finally
      DimsList.Free;
    end;
  end
  else
    Result := Format('%s %s;', [EmitTypeRef(AType), AName]);
end;

function TAetherEmitterC.EmitTypeRef(const AType: string): string;
var
  Inner, Inner2, ValT, ErrT: string;
begin
  if AType = 'Bool' then Result := 'bool'
  else if AType = 'Int8' then Result := 'int8_t'
  else if AType = 'Int16' then Result := 'int16_t'
  else if AType = 'Int32' then Result := 'int32_t'
  else if AType = 'Int64' then Result := 'int64_t'
  else if AType = 'UInt8' then Result := 'uint8_t'
  else if AType = 'UInt16' then Result := 'uint16_t'
  else if AType = 'UInt32' then Result := 'uint32_t'
  else if AType = 'UInt64' then Result := 'uint64_t'
  else if AType = 'Float32' then Result := 'float'
  else if AType = 'Float64' then Result := 'double'
  else if AType = 'Char' then Result := 'char'
  else if AType = 'String' then Result := 'const char*'
  else if AType = 'Void' then Result := 'void'
  else if AType = 'Pointer' then Result := 'void*'
  else if Pos('^', AType) = 1 then Result := EmitTypeRef(Copy(AType, 2, Length(AType))) + '*'
  else if Pos('array of ', AType) = 1 then Result := EmitTypeRef(Trim(Copy(AType, 10, Length(AType)))) + '*'
  else if IsTypedResult(AType, ValT, ErrT) then
    Result := 'AetherRes_' + MangleTypeTag(ValT) + '__' + MangleTypeTag(ErrT)
  else if Pos('Result', AType) = 1 then Result := 'AetherResult'
  else if Pos('set of', AType) = 1 then Result := 'uint32_t'
  else if Pos('Box<', AType) > 0 then
  begin
    Inner := AType;
    if Pos('Option<', Inner) = 1 then Inner := SafeUnwrapGeneric(Inner, 'Option');
    if Pos('Box<', Inner) = 1 then Inner := SafeUnwrapGeneric(Inner, 'Box');
    Result := 'P' + EmitTypeRef(Inner);
  end
  else if (Copy(AType, 1, 5) = 'Task<') and (AType[Length(AType)] = '>') then Result := 'AetherTask'
  else if IsTypedValueOption(AType, Inner) then
    Result := 'AetherOpt_' + MangleTypeTag(Inner)
  else if Pos('Option<', AType) = 1 then
  begin
    if IsValueOptionType(AType) then
      Result := 'AetherOption'
    else
    begin
      Inner := SafeUnwrapGeneric(AType, 'Option');
      Result := EmitTypeRef(Inner);
    end;
  end
  else if IsMapType(AType, Inner, Inner2) then
    Result := 'TAetherMap_' + MapTag(Inner, Inner2)
  else if Pos('fn(', AType) = 1 then
    Result := 'AetherFn_' + FnTypeTag(AType)
  else Result := 'T' + AType;
end;

function TAetherEmitterC.EmitExpr(Expr: TASTExpr): string;
var
  Lit: TASTLiteralExpr;
  Id: TASTIdentifierExpr;
  Acc: TASTMemberAccessExpr;
  Bin: TASTBinaryExpr;
  Un: TASTUnaryExpr;
  Call: TASTCallExpr;
  Idx: TASTIndexExpr;
  SetLit: TASTSetLiteralExpr;
  FuncDecl: TASTFunction;
  CalleeName: string;
  ArgsStr: string;
  ArgVal: string;
  I, J, BindCount, BIdx: Integer;
  OpStr, LType, RType, KeyT, ValT, TargetT, ValF, ErrF, ArgStr: string;
  TargetStr, RetT, RetValF, RetErrF, MTag, RetMTag, ErrValExpr, BName, BType: string;
  ArgType: string;
  TName: string;
  Rec: TASTRecordDecl;
  MExpr: TASTMatchExpr;
  CaseNode: TASTMatchCase;
  SavedOut, K: Integer;
  IsWild, OpTyped, RetTyped: Boolean;
  DeferStr, TmpName, CType, ExprStr, MatchedType, CondStr, BindStmt, BindVarType, SRet, SRes: string;
  Enm: TASTEnumDecl;
  VarN: TASTEnumVariant;
  TupLit: TASTTupleLiteralExpr;
  Lam: TASTLambdaExpr;
  FnTag: string;
begin
  if not Assigned(Expr) then Exit('');

  if Expr is TASTLiteralExpr then
  begin
    Lit := TASTLiteralExpr(Expr);
    case Lit.Kind of
      lkInt:    Result := NormalizeIntLit(Lit.Value);
      lkString: Result := EscapeCString(Lit.Value);
      lkChar:   Result := EscapeCChar(Lit.Value);
      lkBool:   Result := LowerCase(Lit.Value);
      lkNil:    Result := 'NULL';
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
    if Assigned(FCurrentFunc) and SameText(Id.Name, 'result') then
      Result := 'result'
    else if Id.Name = '__ValueNone' then
    begin
      if (Id.ResolvedMonadType <> '') and IsTypedValueOption(Id.ResolvedMonadType, ValF) then
        Result := 'AetherNone_' + MangleTypeTag(ValF) + '()'
      else
        Result := '((AetherOption){ .is_some = false, .is_none = true, .num_val = 0, .str_val = "" })';
    end
    else if Id.Name = 'None' then
      Result := 'NULL'
    else if IsMutBorrowParam(Id.Name) then
      Result := '(*' + Id.Name + ')'
    else if FindEnumVariantUnqualified(Id.Name, Enm, VarN) and Enm.HasPayload then
      Result := Enm.Name + '_' + VarN.Name + '()'
    else if Id.IsFnValueRef and (Id.ResolvedFnType <> '') then
    begin
      RegisterThunkFunc(Id.Name);
      Result := Format('((AetherFn_%s){ __aether_thunk_%s, NULL })', [RegisterFnType(Id.ResolvedFnType), Id.Name]);
    end
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
    if (Acc.Target is TASTIdentifierExpr) and IsEnumName(TASTIdentifierExpr(Acc.Target).Name) then
    begin
      Enm := FindEnumDecl(TASTIdentifierExpr(Acc.Target).Name);
      if Assigned(Enm) and Enm.HasPayload then
        Result := Enm.Name + '_' + Acc.Member + '()'
      else
        Result := TASTIdentifierExpr(Acc.Target).Name + '_' + Acc.Member;
    end
    else if (Acc.Target is TASTMemberAccessExpr) and IsEnumName(TargetStr) then
    begin
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
          Result := Format('((%s)(%s.error))', [EmitTypeRef(ErrF), TargetStr]);
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
      Result := '(' + TargetStr + ' != NULL)'
    else if Acc.Member = 'is_none' then
      Result := '(' + TargetStr + ' == NULL)'
    else if (Acc.Target is TASTIdentifierExpr) and IsMutBorrowParam(TASTIdentifierExpr(Acc.Target).Name) then
    begin
      if Acc.Member = 'value' then
        Result := '(*' + TASTIdentifierExpr(Acc.Target).Name + ')'
      else
        Result := TASTIdentifierExpr(Acc.Target).Name + '->' + Acc.Member;
    end
    else if IsPointerTarget(Acc.Target) then
    begin
      if Acc.Member = 'value' then
        Result := '(*' + TargetStr + ')'
      else
        Result := TargetStr + '->' + Acc.Member;
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
    OpStr := Bin.Op;
    if OpStr = '=' then
    begin
      if (GetExprTypeName(Bin.Left) = 'String') or (GetExprTypeName(Bin.Right) = 'String') then
        Exit(Format('(strcmp(%s, %s) == 0)', [EmitExpr(Bin.Left), EmitExpr(Bin.Right)]))
      else
        OpStr := '==';
    end
    else if OpStr = '<>' then
    begin
      if (GetExprTypeName(Bin.Left) = 'String') or (GetExprTypeName(Bin.Right) = 'String') then
        Exit(Format('(strcmp(%s, %s) != 0)', [EmitExpr(Bin.Left), EmitExpr(Bin.Right)]))
      else
        OpStr := '!=';
    end
    else if OpStr = '<' then
    begin
      if (GetExprTypeName(Bin.Left) = 'String') or (GetExprTypeName(Bin.Right) = 'String') then
        Exit(Format('(strcmp(%s, %s) < 0)', [EmitExpr(Bin.Left), EmitExpr(Bin.Right)]));
    end
    else if OpStr = '<=' then
    begin
      if (GetExprTypeName(Bin.Left) = 'String') or (GetExprTypeName(Bin.Right) = 'String') then
        Exit(Format('(strcmp(%s, %s) <= 0)', [EmitExpr(Bin.Left), EmitExpr(Bin.Right)]));
    end
    else if OpStr = '>' then
    begin
      if (GetExprTypeName(Bin.Left) = 'String') or (GetExprTypeName(Bin.Right) = 'String') then
        Exit(Format('(strcmp(%s, %s) > 0)', [EmitExpr(Bin.Left), EmitExpr(Bin.Right)]));
    end
    else if OpStr = '>=' then
    begin
      if (GetExprTypeName(Bin.Left) = 'String') or (GetExprTypeName(Bin.Right) = 'String') then
        Exit(Format('(strcmp(%s, %s) >= 0)', [EmitExpr(Bin.Left), EmitExpr(Bin.Right)]));
    end
    else if OpStr = '+' then
    begin
      if (GetExprTypeName(Bin.Left) = 'String') or (GetExprTypeName(Bin.Right) = 'String') then
        Exit(Format('AetherStringConcat(%s, %s)', [EmitExpr(Bin.Left), EmitExpr(Bin.Right)]));
    end
    else if SameText(OpStr, 'shl') then OpStr := '<<'
    else if SameText(OpStr, 'shr') then OpStr := '>>'
    else if SameText(OpStr, 'xor') then
    begin
      LType := GetExprTypeName(Bin.Left);
      RType := GetExprTypeName(Bin.Right);
      if IsIntCType(LType) or IsIntCType(RType) then
        OpStr := '^'
      else
        OpStr := '!=';
    end
    else if SameText(OpStr, 'and') then
    begin
      LType := GetExprTypeName(Bin.Left);
      RType := GetExprTypeName(Bin.Right);
      if IsIntCType(LType) and IsIntCType(RType) then
        OpStr := '&'
      else
        OpStr := '&&';
    end
    else if SameText(OpStr, 'or') then
    begin
      LType := GetExprTypeName(Bin.Left);
      RType := GetExprTypeName(Bin.Right);
      if IsIntCType(LType) and IsIntCType(RType) then
        OpStr := '|'
      else
        OpStr := '||';
    end
    else if OpStr = 'mod' then OpStr := '%'
    else if OpStr = 'div' then OpStr := '/'
    else if OpStr = 'implies' then
      Exit(Format('(!(%s) || (%s))', [EmitExpr(Bin.Left), EmitExpr(Bin.Right)]))
    else if OpStr = 'in' then
      Exit(Format('(((%s) & (1U << (%s))) != 0)', [EmitExpr(Bin.Right), EmitExpr(Bin.Left)]));

    if IsSetType(GetExprTypeName(Bin.Left)) or IsSetType(GetExprTypeName(Bin.Right)) then
    begin
      if OpStr = '+' then Exit(Format('((%s) | (%s))', [EmitExpr(Bin.Left), EmitExpr(Bin.Right)]))
      else if OpStr = '*' then Exit(Format('((%s) & (%s))', [EmitExpr(Bin.Left), EmitExpr(Bin.Right)]))
      else if OpStr = '-' then Exit(Format('((%s) & ~(%s))', [EmitExpr(Bin.Left), EmitExpr(Bin.Right)]));
    end;

    Result := Format('(%s %s %s)', [EmitExpr(Bin.Left), OpStr, EmitExpr(Bin.Right)]);
    Exit;
  end;

  if Expr is TASTUnaryExpr then
  begin
    Un := TASTUnaryExpr(Expr);
    OpStr := Un.Op;
    if OpStr = '?' then
    begin
      TargetT := ResolveAliasType(GetExprTypeName(Un.Expr));
      TargetStr := Format('_at_%d_%d', [Un.Line, Un.Col]);
      DeferStr := '';
      if FActiveDefers.Count > 0 then
      begin
        SavedOut := FOutput.Count;
        EmitActiveDefers(0);
        for K := SavedOut to FOutput.Count - 1 do
          DeferStr := DeferStr + Trim(FOutput[K]) + ' ';
        while FOutput.Count > SavedOut do
          FOutput.Delete(FOutput.Count - 1);
      end;
      if FTryDepth > 0 then
        DeferStr := DeferStr + Format('g_aether_jmp_top -= %d; ', [FTryDepth]);
      RetT := '';
      if Assigned(FCurrentFunc) then RetT := ResolveAliasType(FCurrentFunc.ReturnType);
      if Pos('Result', TargetT) = 1 then
      begin
        SplitResultTypes(TargetT, ValF, ErrF);
        OpTyped := IsTypedResult(TargetT, ValF, ErrF);
        RetTyped := (RetT <> '') and IsTypedResult(RetT, RetValF, RetErrF);
        if not OpTyped and not RetTyped then
          Result := Format('({ AetherResult %s = %s; if (%s.is_err) { %sreturn %s; } %s; })',
            [TargetStr, EmitExpr(Un.Expr), TargetStr, DeferStr, TargetStr,
             EmitMonadFieldExtract(TargetStr, ValF, 'value', 'str_val')])
        else if OpTyped and RetTyped then
        begin
          MTag := MangleTypeTag(ValF) + '__' + MangleTypeTag(ErrF);
          RetMTag := MangleTypeTag(RetValF) + '__' + MangleTypeTag(RetErrF);
          if MTag = RetMTag then
            Result := Format('({ AetherRes_%s %s = %s; if (%s.is_err) { %sreturn %s; } %s.value; })',
              [MTag, TargetStr, EmitExpr(Un.Expr), TargetStr, DeferStr, TargetStr, TargetStr])
          else
            Result := Format('({ AetherRes_%s %s = %s; if (%s.is_err) { %sreturn AetherErr_%s(%s.error); } %s.value; })',
              [MTag, TargetStr, EmitExpr(Un.Expr), TargetStr, DeferStr, RetMTag, TargetStr, TargetStr]);
        end
        else if (not OpTyped) and RetTyped then
        begin
          RetMTag := MangleTypeTag(RetValF) + '__' + MangleTypeTag(RetErrF);
          if ResolveAliasType(ErrF) = 'String' then
            ErrValExpr := TargetStr + '.err_str'
          else
            ErrValExpr := Format('((%s)(%s.error))', [EmitTypeRef(ErrF), TargetStr]);
          Result := Format('({ AetherResult %s = %s; if (%s.is_err) { %sreturn AetherErr_%s(%s); } %s; })',
            [TargetStr, EmitExpr(Un.Expr), TargetStr, DeferStr, RetMTag, ErrValExpr,
             EmitMonadFieldExtract(TargetStr, ValF, 'value', 'str_val')]);
        end
        else
        begin
          MTag := MangleTypeTag(ValF) + '__' + MangleTypeTag(ErrF);
          if ResolveAliasType(ErrF) = 'String' then
            ErrValExpr := Format('((AetherResult){ .is_ok = false, .is_err = true, .err_str = %s.error })', [TargetStr])
          else
            ErrValExpr := Format('((AetherResult){ .is_ok = false, .is_err = true, .error = (int)(%s.error) })', [TargetStr]);
          Result := Format('({ AetherRes_%s %s = %s; if (%s.is_err) { %sreturn %s; } %s.value; })',
            [MTag, TargetStr, EmitExpr(Un.Expr), TargetStr, DeferStr, ErrValExpr, TargetStr]);
        end;
      end
      else if IsValueOptionType(TargetT) then
      begin
        OpTyped := IsTypedValueOption(TargetT, ValF);
        if not OpTyped then ValF := SafeUnwrapGeneric(TargetT, 'Option');
        RetTyped := (RetT <> '') and IsTypedValueOption(RetT, RetValF);
        if RetTyped then
          ErrValExpr := Format('AetherNone_%s()', [MangleTypeTag(RetValF)])
        else if (RetT = '') or IsValueOptionType(RetT) then
          ErrValExpr := '((AetherOption){ .is_some = false, .is_none = true, .num_val = 0, .str_val = "" })'
        else
          ErrValExpr := 'NULL';
        if OpTyped then
        begin
          MTag := MangleTypeTag(ValF);
          Result := Format('({ AetherOpt_%s %s = %s; if (%s.is_none) { %sreturn %s; } %s.value; })',
            [MTag, TargetStr, EmitExpr(Un.Expr), TargetStr, DeferStr, ErrValExpr, TargetStr]);
        end
        else
        begin
          if not RetTyped and IsValueOptionType(RetT) then ErrValExpr := TargetStr;
          Result := Format('({ AetherOption %s = %s; if (%s.is_none) { %sreturn %s; } %s; })',
            [TargetStr, EmitExpr(Un.Expr), TargetStr, DeferStr, ErrValExpr,
             EmitMonadFieldExtract(TargetStr, ValF, 'num_val', 'str_val')]);
        end;
      end
      else
      begin
        ValF := SafeUnwrapGeneric(TargetT, 'Option');
        RetTyped := (RetT <> '') and IsTypedValueOption(RetT, RetValF);
        if RetTyped then
          ErrValExpr := Format('AetherNone_%s()', [MangleTypeTag(RetValF)])
        else
          ErrValExpr := 'NULL';
        Result := Format('({ %s %s = %s; if (%s == NULL) { %sreturn %s; } %s; })',
          [EmitTypeRef(ValF), TargetStr, EmitExpr(Un.Expr), TargetStr, DeferStr, ErrValExpr, TargetStr]);
      end;
      Exit;
    end
    else if OpStr = '@' then
    begin
      Result := '(&(' + EmitExpr(Un.Expr) + '))';
      Exit;
    end
    else if OpStr = '^' then
    begin
      Result := '(*(' + EmitExpr(Un.Expr) + '))';
      Exit;
    end;
    if SameText(OpStr, 'not') then
    begin
      if IsIntCType(GetExprTypeName(Un.Expr)) then
        OpStr := '~'
      else
        OpStr := '!';
    end;
    Result := Format('(%s%s)', [OpStr, EmitExpr(Un.Expr)]);
    Exit;
  end;

  if Expr is TASTAwaitExpr then
  begin
    TName := GetExprTypeName(TASTAwaitExpr(Expr).Expr);
    if (TName = 'Float') or (TName = 'Float32') or (TName = 'Float64') or (TName = 'Double') or
       (TName = 'Task<Float>') or (TName = 'Task<Float32>') or (TName = 'Task<Float64>') or (TName = 'Task<Double>') then
      Result := Format('(%s).float_val', [EmitExpr(TASTAwaitExpr(Expr).Expr)])
    else if (TName = 'String') or (TName = 'Task<String>') then
      Result := Format('(%s).str_val', [EmitExpr(TASTAwaitExpr(Expr).Expr)])
    else
      Result := Format('(%s).int_val', [EmitExpr(TASTAwaitExpr(Expr).Expr)]);
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
      Result := Format('(((%s[]){ %s })[%s])', [EmitTypeRef(ValF), ArgsStr, EmitExpr(TASTExpr(Idx.Indices[0]))]);
      Exit;
    end;
    TargetT := ResolveAliasType(GetExprTypeName(Idx.Target));
    if TargetT = 'String' then
    begin
      Result := Format('(%s)[%s]', [EmitExpr(Idx.Target), EmitExpr(TASTExpr(Idx.Indices[0]))]);
      Exit;
    end;
    if IsMapType(TargetT, KeyT, ValT) then
    begin
      if Idx.Target is TASTMapLiteralExpr then
        Result := Format('({ TAetherMap_%s _am_tmp = %s; AetherMapGet_%s(&_am_tmp, %s); })',
          [MapTag(KeyT, ValT), EmitExpr(Idx.Target), MapTag(KeyT, ValT), EmitExpr(TASTExpr(Idx.Indices[0]))])
      else
        Result := Format('AetherMapGet_%s(&(%s), %s)', [MapTag(KeyT, ValT), EmitExpr(Idx.Target), EmitExpr(TASTExpr(Idx.Indices[0]))]);
      Exit;
    end;
    TargetStr := EmitExpr(Idx.Target);
    ArgsStr := '';
    for I := 0 to Idx.Indices.Count - 1 do
      ArgsStr := ArgsStr + Format('[%s]', [EmitExpr(TASTExpr(Idx.Indices[I]))]);
    Result := Format('%s%s', [TargetStr, ArgsStr]);
    Exit;
  end;

  if Expr is TASTSetLiteralExpr then
  begin
    SetLit := TASTSetLiteralExpr(Expr);
    if SetLit.Elements.Count = 0 then
      Result := '0U'
    else
    begin
      Result := '';
      for I := 0 to SetLit.Elements.Count - 1 do
      begin
        if I > 0 then Result := Result + ' | ';
        Result := Result + Format('(1U << (%s))', [EmitExpr(TASTExpr(SetLit.Elements[I]))]);
      end;
      Result := '(' + Result + ')';
    end;
    Exit;
  end;

  if Expr is TASTMapLiteralExpr then
  begin
    TargetT := GetExprTypeName(Expr);
    if not IsMapType(TargetT, KeyT, ValT) then
      Exit('((void*)0)');
    ValF := MapTag(KeyT, ValT);
    TmpName := Format('_aml_%d_%d', [Expr.Line, Expr.Col]);
    SRes := Format('({ TAetherMap_%s %s; memset(&%s, 0, sizeof(%s)); ', [ValF, TmpName, TmpName, TmpName]);
    for I := 0 to TASTMapLiteralExpr(Expr).Keys.Count - 1 do
      SRes := SRes + Format('AetherMapSet_%s(&%s, %s, %s); ',
        [ValF, TmpName, EmitExpr(TASTExpr(TASTMapLiteralExpr(Expr).Keys[I])), EmitExpr(TASTExpr(TASTMapLiteralExpr(Expr).Values[I]))]);
    SRes := SRes + TmpName + '; })';
    Result := SRes;
    Exit;
  end;

  if Expr is TASTCallExpr then
  begin
    Call := TASTCallExpr(Expr);
    if Call.IsIndirectCall then
    begin
      if Assigned(Call.CalleeExpr) then
        TargetStr := EmitExpr(Call.CalleeExpr)
      else if IsMutBorrowParam(Call.Callee) then
        TargetStr := '(*' + Call.Callee + ')'
      else
        TargetStr := Call.Callee;
      ArgsStr := '';
      for I := 0 to Call.Args.Count - 1 do
      begin
        if I > 0 then ArgsStr := ArgsStr + ', ';
        ArgsStr := ArgsStr + EmitExpr(TASTCallArg(Call.Args[I]).Expr);
      end;
      FnTag := RegisterFnType(Call.IndirectFnType);
      if ArgsStr <> '' then
        Result := Format('AetherCallFn_%s(%s, %s)', [FnTag, TargetStr, ArgsStr])
      else
        Result := Format('AetherCallFn_%s(%s)', [FnTag, TargetStr]);
      Exit;
    end;

    if (Call.Callee = 'PrintLn') or (Call.Callee = 'WriteLn') or (Call.Callee = 'Print') then
    begin
      if Call.Callee = 'Print' then ValF := '' else ValF := '\n';
      if Call.Args.Count = 1 then
      begin
        ArgType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
        if (ArgType = 'Int32') or (ArgType = 'Int16') or (ArgType = 'Int8') or (ArgType = 'UInt16') or (ArgType = 'UInt8') then
          Result := 'printf("%d' + ValF + '", ' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')'
        else if (ArgType = 'Int64') or (ArgType = 'UInt64') or (ArgType = 'UInt32') then
          Result := 'printf("%lld' + ValF + '", (long long)(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))'
        else if (ArgType = 'Float64') or (ArgType = 'Float32') then
          Result := 'printf("%f' + ValF + '", ' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')'
        else if (ArgType = 'Bool') then
          Result := 'printf("%s' + ValF + '", (' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ') ? "true" : "false")'
        else if (ArgType = 'Char') then
          Result := 'printf("%c' + ValF + '", ' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')'
        else
          Result := 'printf("%s' + ValF + '", ' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      end
      else
      begin
        ArgsStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
        if (ValF <> '') and (Length(ArgsStr) >= 2) and (ArgsStr[Length(ArgsStr)] = '"') then
          ArgsStr := Copy(ArgsStr, 1, Length(ArgsStr) - 1) + '\n"';
        for I := 1 to Call.Args.Count - 1 do
        begin
          ArgsStr := ArgsStr + ', ' + EmitExpr(TASTCallArg(Call.Args[I]).Expr);
        end;
        Result := 'printf(' + ArgsStr + ')';
      end;
      Exit;
    end;

    if Call.Callee = 'Ok' then
    begin
      ArgStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
      if (Call.ResolvedMonadType <> '') and IsTypedResult(Call.ResolvedMonadType, ValF, ErrF) then
      begin
        MTag := MangleTypeTag(ValF) + '__' + MangleTypeTag(ErrF);
        Result := Format('AetherOk_%s(%s)', [MTag, ArgStr]);
      end
      else
      begin
        ArgType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
        if ArgType = 'String' then
          Result := '((AetherResult){ .is_ok = true, .is_err = false, .str_val = ' + ArgStr + ' })'
        else
          Result := '((AetherResult){ .is_ok = true, .is_err = false, .value = (double)(' + ArgStr + ') })';
      end;
      Exit;
    end;

    if Call.Callee = 'Err' then
    begin
      ArgStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
      if (Call.ResolvedMonadType <> '') and IsTypedResult(Call.ResolvedMonadType, ValF, ErrF) then
      begin
        MTag := MangleTypeTag(ValF) + '__' + MangleTypeTag(ErrF);
        Result := Format('AetherErr_%s(%s)', [MTag, ArgStr]);
      end
      else
      begin
        ArgType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
        if ArgType = 'String' then
          Result := '((AetherResult){ .is_ok = false, .is_err = true, .err_str = ' + ArgStr + ' })'
        else
          Result := '((AetherResult){ .is_ok = false, .is_err = true, .error = (int)(' + ArgStr + ') })';
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
        ArgStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
        if IsTypedValueOption(MTag, ValF) then
          Result := Format('AetherSome_%s(%s)', [MangleTypeTag(ValF), ArgStr])
        else
        begin
          ArgType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
          if ArgType = 'String' then
            Result := '((AetherOption){ .is_some = true, .is_none = false, .str_val = ' + ArgStr + ' })'
          else
            Result := '((AetherOption){ .is_some = true, .is_none = false, .num_val = (double)(' + ArgStr + ') })';
        end;
      end;
      Exit;
    end;

    if Call.Callee = 'Box' then
    begin
      CalleeName := GetExprTypeName(TASTCallArg(Call.Args[0]).Expr);
      if (CalleeName = '') and (TASTCallArg(Call.Args[0]).Expr is TASTCallExpr) then
        CalleeName := TASTCallExpr(TASTCallArg(Call.Args[0]).Expr).Callee;
      Result := 'AetherBox_T' + CalleeName + '(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = '__InterpToStr' then
    begin
      Result := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
      Exit;
    end;

    if Call.Callee = 'CharToStr' then
    begin
      Result := 'AetherCharToStr(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if SameText(Call.Callee, 'SetLength') then
    begin
      TargetStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
      Result := Format('%s = (__typeof__(%s))AetherDynSetLength(%s, sizeof(*(%s)), (size_t)(%s))',
        [TargetStr, TargetStr, TargetStr, TargetStr, EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Push') then
    begin
      TargetStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
      Result := Format('do { %s = (__typeof__(%s))AetherDynSetLength(%s, sizeof(*(%s)), AetherDynLen(%s) + 1); (%s)[AetherDynLen(%s) - 1] = %s; } while (0)',
        [TargetStr, TargetStr, TargetStr, TargetStr, TargetStr, TargetStr, TargetStr, EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Pop') then
    begin
      TargetStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
      Result := Format('({ __typeof__(*(%s)) _apop = (%s)[AetherDynLen(%s) - 1]; %s = (__typeof__(%s))AetherDynSetLength(%s, sizeof(*(%s)), AetherDynLen(%s) - 1); _apop; })',
        [TargetStr, TargetStr, TargetStr, TargetStr, TargetStr, TargetStr, TargetStr, TargetStr]);
      Exit;
    end;

    if SameText(Call.Callee, 'Clear') then
    begin
      TargetStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
      if IsMapType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr), KeyT, ValT) then
        Result := Format('(%s).count = 0', [TargetStr])
      else
        Result := Format('%s = (__typeof__(%s))AetherDynSetLength(%s, sizeof(*(%s)), 0)',
          [TargetStr, TargetStr, TargetStr, TargetStr]);
      Exit;
    end;

    if SameText(Call.Callee, 'Inc') then
    begin
      if Call.Args.Count = 2 then
        Result := Format('(%s) += (%s)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)])
      else
        Result := Format('(%s) += 1', [EmitExpr(TASTCallArg(Call.Args[0]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Dec') then
    begin
      if Call.Args.Count = 2 then
        Result := Format('(%s) -= (%s)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)])
      else
        Result := Format('(%s) -= 1', [EmitExpr(TASTCallArg(Call.Args[0]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Ord') then
    begin
      Result := '((int32_t)(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if SameText(Call.Callee, 'Chr') then
    begin
      Result := '((char)(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if SameText(Call.Callee, 'SizeOf') then
    begin
      if (TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr) and IsTypeIdentifier(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name) then
        Result := '((int32_t)sizeof(' + EmitTypeRef(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name) + '))'
      else
        Result := '((int32_t)sizeof(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if (Call.Args.Count = 1) and IsTypeIdentifier(Call.Callee) and not IsEnumName(Call.Callee) and not IsRecordName(Call.Callee) then
    begin
      Result := Format('((%s)(%s))', [EmitTypeRef(Call.Callee), EmitExpr(TASTCallArg(Call.Args[0]).Expr)]);
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

    if SameText(Call.Callee, 'Length') or SameText(Call.Callee, 'Count') then
    begin
      ArgType := GetExprTypeName(TASTCallArg(Call.Args[0]).Expr);
      TargetStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
      if IsMapType(ArgType, KeyT, ValT) then
        Result := Format('(%s).count', [TargetStr])
      else if IsDynamicArrayType(ArgType) then
        Result := '(int32_t)AetherDynLen(' + TargetStr + ')'
      else if (ArgType = 'String') or (ArgType = '') then
        Result := '(int32_t)strlen(' + TargetStr + ')'
      else
        Result := Format('(int32_t)(sizeof(%s) / sizeof((%s)[0]))', [TargetStr, TargetStr]);
      Exit;
    end;

    if SameText(Call.Callee, 'Default') then
    begin
      TargetStr := Trim(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name);
      TargetT := ResolveAliasType(TargetStr);
      if TargetT = 'String' then
        Result := '((const char*)"")'
      else if TargetT = 'Bool' then
        Result := 'false'
      else if (TargetT = 'Pointer') or (Pos('^', TargetT) = 1) or IsDynamicArrayType(TargetT) then
        Result := Format('((%s)NULL)', [EmitTypeRef(TargetStr)])
      else if (Pos('Result', TargetT) = 1) or (Pos('Option', TargetT) = 1) or IsFixedArrayType(TargetT) then
        Result := Format('((%s){0})', [EmitTypeRef(TargetStr)])
      else if (TargetT = 'Int8') or (TargetT = 'Int16') or (TargetT = 'Int32') or (TargetT = 'Int64') or
              (TargetT = 'UInt8') or (TargetT = 'UInt16') or (TargetT = 'UInt32') or (TargetT = 'UInt64') or
              (TargetT = 'Float32') or (TargetT = 'Float64') or (TargetT = 'Char') then
        Result := Format('((%s)0)', [EmitTypeRef(TargetStr)])
      else
      begin
        Rec := nil;
        if Assigned(FModule) then
          for I := 0 to FModule.Types.Count - 1 do
            if (FModule.Types[I] is TASTRecordDecl) and SameText(TASTRecordDecl(FModule.Types[I]).Name, TargetT) then
            begin
              Rec := TASTRecordDecl(FModule.Types[I]);
              Break;
            end;
        if Assigned(Rec) then
        begin
          ArgsStr := '';
          for J := 0 to Rec.Fields.Count - 1 do
            if ResolveAliasType(TASTRecordField(Rec.Fields[J]).TypeName) = 'String' then
            begin
              if ArgsStr <> '' then ArgsStr := ArgsStr + ', ';
              ArgsStr := ArgsStr + Format('.%s = ""', [TASTRecordField(Rec.Fields[J]).Name]);
            end;
          if ArgsStr <> '' then
            Result := Format('((%s){ %s })', [EmitTypeRef(TargetStr), ArgsStr])
          else
            Result := Format('((%s){0})', [EmitTypeRef(TargetStr)]);
        end
        else
          Result := Format('((%s)0)', [EmitTypeRef(TargetStr)]);
      end;
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
        Result := Format('AetherMapContains_%s(&(%s), %s)', [MapTag(KeyT, ValT), EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
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
      Result := Format('AetherStrIndexOf(%s, %s)', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
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
        TargetStr := '" "'
      else
      begin
        TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[2]).Expr));
        if TargetT = 'Char' then
          TargetStr := 'AetherCharToStr(' + EmitExpr(TASTCallArg(Call.Args[2]).Expr) + ')'
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
      Result := 'sqrt((double)(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if SameText(Call.Callee, 'Floor') then
    begin
      Result := 'floor((double)(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if SameText(Call.Callee, 'Ceil') then
    begin
      Result := 'ceil((double)(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if SameText(Call.Callee, 'Round') then
    begin
      Result := 'round((double)(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if SameText(Call.Callee, 'Pow') then
    begin
      Result := Format('pow((double)(%s), (double)(%s))', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Exp') then
    begin
      Result := 'exp((double)(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if SameText(Call.Callee, 'Log') then
    begin
      Result := 'log((double)(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if SameText(Call.Callee, 'Sin') then
    begin
      Result := 'sin((double)(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if SameText(Call.Callee, 'Cos') then
    begin
      Result := 'cos((double)(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if SameText(Call.Callee, 'Tan') then
    begin
      Result := 'tan((double)(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if SameText(Call.Callee, 'Atan2') then
    begin
      Result := Format('atan2((double)(%s), (double)(%s))', [EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
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
      TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
      if TargetT = '' then TargetT := 'Int32';
      ValF := EmitTypeRef(TargetT);
      if Pos('UInt', TargetT) = 1 then
        Result := Format('((%s)(%s))', [ValF, EmitExpr(TASTCallArg(Call.Args[0]).Expr)])
      else
        Result := Format('({ %s _ax = (%s); _ax < 0 ? (%s)(-_ax) : _ax; })', [ValF, EmitExpr(TASTCallArg(Call.Args[0]).Expr), ValF]);
      Exit;
    end;

    if SameText(Call.Callee, 'Min') then
    begin
      TargetT := ResolveAliasType(GetExprTypeName(Call));
      if TargetT = '' then TargetT := 'Int32';
      ValF := EmitTypeRef(TargetT);
      Result := Format('({ %s _ma = (%s); %s _mb = (%s); _ma < _mb ? _ma : _mb; })',
        [ValF, EmitExpr(TASTCallArg(Call.Args[0]).Expr), ValF, EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Max') then
    begin
      TargetT := ResolveAliasType(GetExprTypeName(Call));
      if TargetT = '' then TargetT := 'Int32';
      ValF := EmitTypeRef(TargetT);
      Result := Format('({ %s _ma = (%s); %s _mb = (%s); _ma > _mb ? _ma : _mb; })',
        [ValF, EmitExpr(TASTCallArg(Call.Args[0]).Expr), ValF, EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Clamp') then
    begin
      TargetT := ResolveAliasType(GetExprTypeName(Call));
      if TargetT = '' then TargetT := 'Int32';
      ValF := EmitTypeRef(TargetT);
      Result := Format('({ %s _cx = (%s); %s _clo = (%s); %s _chi = (%s); _cx < _clo ? _clo : (_cx > _chi ? _chi : _cx); })',
        [ValF, EmitExpr(TASTCallArg(Call.Args[0]).Expr), ValF, EmitExpr(TASTCallArg(Call.Args[1]).Expr), ValF, EmitExpr(TASTCallArg(Call.Args[2]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Delete') then
    begin
      TargetStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
      Result := Format('%s = (__typeof__(%s))AetherDynDelete(%s, sizeof(*(%s)), (int64_t)(%s))',
        [TargetStr, TargetStr, TargetStr, TargetStr, EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Insert') then
    begin
      TargetStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
      Result := Format('do { size_t _len = AetherDynLen(%s); int64_t _idx = (int64_t)(%s); __typeof__(*(%s)) _iv = (%s); if (_idx < 0) _idx = 0; if ((size_t)_idx > _len) _idx = (int64_t)_len; %s = (__typeof__(%s))AetherDynSetLength(%s, sizeof(*(%s)), _len + 1); for (size_t _k = _len; _k > (size_t)_idx; _k--) (%s)[_k] = (%s)[_k - 1]; (%s)[_idx] = _iv; } while (0)',
        [TargetStr, EmitExpr(TASTCallArg(Call.Args[1]).Expr), TargetStr, EmitExpr(TASTCallArg(Call.Args[2]).Expr),
         TargetStr, TargetStr, TargetStr, TargetStr, TargetStr, TargetStr, TargetStr]);
      Exit;
    end;

    if SameText(Call.Callee, 'Slice') then
    begin
      TargetStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
      Result := Format('((__typeof__(%s))AetherDynSlice(%s, sizeof(*(%s)), (int64_t)(%s), (int64_t)(%s)))',
        [TargetStr, TargetStr, TargetStr, EmitExpr(TASTCallArg(Call.Args[1]).Expr), EmitExpr(TASTCallArg(Call.Args[2]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Remove') then
    begin
      IsMapType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr), KeyT, ValT);
      Result := Format('AetherMapRemove_%s(&(%s), %s)', [MapTag(KeyT, ValT), EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
      Exit;
    end;

    if SameText(Call.Callee, 'Free') or SameText(Call.Callee, 'Dispose') then
    begin
      TargetStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
      TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
      IsWild := (TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr) or
                (TASTCallArg(Call.Args[0]).Expr is TASTMemberAccessExpr);
      if IsDynamicArrayType(TargetT) then
      begin
        if IsWild then
          Result := Format('do { if (%s) { AetherDynFree(%s); %s = NULL; } } while (0)', [TargetStr, TargetStr, TargetStr])
        else
          Result := Format('AetherDynFree(%s)', [TargetStr]);
      end
      else if IsMapType(TargetT, KeyT, ValT) then
      begin
        if IsWild then
          Result := Format('do { if ((%s).entries) { free((%s).entries); (%s).entries = NULL; } (%s).count = 0; (%s).capacity = 0; } while (0)',
            [TargetStr, TargetStr, TargetStr, TargetStr, TargetStr])
        else
          Result := Format('free((%s).entries)', [TargetStr]);
      end
      else
      begin
        ArgsStr := '';
        if Pos('Box<', TargetT) = 1 then
        begin
          ValF := Trim(Copy(TargetT, 5, Length(TargetT) - 5));
          if FindDropFunc(ValF) <> nil then
          begin
            if (FindDropFunc(ValF).Params.Count > 0) and (TASTParam(FindDropFunc(ValF).Params[0]).Ownership = owMutBorrow) then
              ArgsStr := Format('%s(%s); ', [FindDropFunc(ValF).Name, TargetStr])
            else
              ArgsStr := Format('%s(*(%s)); ', [FindDropFunc(ValF).Name, TargetStr]);
          end;
        end;
        if IsWild then
          Result := Format('do { if (%s) { %sfree((void*)(%s)); %s = NULL; } } while (0)', [TargetStr, ArgsStr, TargetStr, TargetStr])
        else
          Result := Format('free((void*)(%s))', [TargetStr]);
      end;
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
      Result := 'AetherIntToStr(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
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
      Result := 'AetherStrToInt(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
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
      Result := 'AetherParamCount()';
      Exit;
    end;

    if Call.Callee = 'ParamStr' then
    begin
      Result := 'AetherParamStr(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'Assert' then
    begin
      Result := 'assert(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
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

    // Primitive typecast (e.g., Int32(x), UInt32(x))
    if (Call.Callee = 'Int8') or (Call.Callee = 'Int16') or (Call.Callee = 'Int32') or (Call.Callee = 'Int64') or
       (Call.Callee = 'UInt8') or (Call.Callee = 'UInt16') or (Call.Callee = 'UInt32') or (Call.Callee = 'UInt64') or
       (Call.Callee = 'Float32') or (Call.Callee = 'Float64') or (Call.Callee = 'Bool') then
    begin
      if Call.Args.Count = 1 then
      begin
        Result := '((' + EmitTypeRef(Call.Callee) + ')(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
        Exit;
      end;
    end;

    // Constructor or normal call
    FuncDecl := FindFunction(Call.Callee);
    if Assigned(FuncDecl) then
      CalleeName := FuncDecl.Name
    else
      CalleeName := Call.Callee;

    ArgsStr := '';
    for I := 0 to Call.Args.Count - 1 do
    begin
      if Assigned(FuncDecl) and (I < FuncDecl.Params.Count) then
      begin
        if TASTParam(FuncDecl.Params[I]).Ownership = owMutBorrow then
        begin
          if (TASTCallArg(Call.Args[I]).Expr is TASTIdentifierExpr) and
             IsMutBorrowParam(TASTIdentifierExpr(TASTCallArg(Call.Args[I]).Expr).Name) then
            ArgVal := TASTIdentifierExpr(TASTCallArg(Call.Args[I]).Expr).Name
          else
            ArgVal := '&' + EmitExpr(TASTCallArg(Call.Args[I]).Expr);
        end
        else
          ArgVal := EmitExpr(TASTCallArg(Call.Args[I]).Expr);
      end
      else
        ArgVal := EmitExpr(TASTCallArg(Call.Args[I]).Expr);
      ArgsStr := ArgsStr + ArgVal;
      if I < Call.Args.Count - 1 then
        ArgsStr := ArgsStr + ', ';
    end;
    if Pos('.', Call.Callee) > 0 then
    begin
      ValF := Copy(Call.Callee, 1, Pos('.', Call.Callee) - 1);
      if IsEnumName(ValF) then
        CalleeName := StringReplace(Call.Callee, '.', '_', [rfReplaceAll]);
    end;
    Result := CalleeName + '(' + ArgsStr + ')';
    Exit;
  end
  else if Expr is TASTIfExpr then
  begin
    Result := Format('((%s) ? (%s) : (%s))',
      [EmitExpr(TASTIfExpr(Expr).Condition), EmitExpr(TASTIfExpr(Expr).ThenExpr), EmitExpr(TASTIfExpr(Expr).ElseExpr)]);
    Exit;
  end
  else if Expr is TASTMatchExpr then
  begin
    MExpr := TASTMatchExpr(Expr);
    SRet := ResolveAliasType(GetExprTypeName(Expr));
    if SRet = '' then SRet := 'Int32';
    CType := EmitTypeRef(SRet);
    TmpName := Format('_am_%d_%d', [MExpr.Line, MExpr.Col]);
    MatchedType := ResolveAliasType(GetExprTypeName(MExpr.Expr));
    if MatchedType = '' then MatchedType := 'Int32';
    ExprStr := Format('_amv_%d_%d', [MExpr.Line, MExpr.Col]);
    SRes := Format('({ %s %s = %s; %s %s; memset(&%s, 0, sizeof(%s)); ',
      [EmitTypeRef(MatchedType), ExprStr, EmitExpr(MExpr.Expr), CType, TmpName, TmpName, TmpName]);
    for I := 0 to MExpr.Cases.Count - 1 do
    begin
      CaseNode := TASTMatchCase(MExpr.Cases[I]);
      BuildMatchCaseCond(CaseNode, ExprStr, MatchedType, CondStr, BindStmt, BindVarType, IsWild);
      if IsWild then
      begin
        if I > 0 then SRes := SRes + 'else { ' else SRes := SRes + '{ ';
      end
      else
      begin
        if CondStr = '' then CondStr := 'true';
        if I = 0 then SRes := SRes + 'if (' + CondStr + ') { '
        else SRes := SRes + 'else if (' + CondStr + ') { ';
      end;
      if BindStmt <> '' then SRes := SRes + BindStmt + ' ';
      BindCount := GetMatchArmBindingCount(CaseNode);
      PushMatchBindings(CaseNode, MatchedType);
      try
        SRes := SRes + TmpName + ' = ' + EmitExpr(CaseNode.ValueExpr) + '; } ';
      finally
        for BIdx := 0 to BindCount - 1 do
        begin
          GetMatchArmBindingInfo(CaseNode, BIdx, MatchedType, BName, BType);
          if (BName <> '') and (BName <> '_') then PopMatchBindings(1);
        end;
      end;
    end;
    SRes := SRes + TmpName + '; })';
    Result := SRes;
    Exit;
  end
  else if Expr is TASTTupleLiteralExpr then
  begin
    TupLit := TASTTupleLiteralExpr(Expr);
    ArgsStr := '';
    for I := 0 to TupLit.Elements.Count - 1 do
    begin
      if I > 0 then ArgsStr := ArgsStr + ', ';
      ArgsStr := ArgsStr + EmitExpr(TASTExpr(TupLit.Elements[I]));
    end;
    Result := Format('%s(%s)', [TupLit.ResolvedType, ArgsStr]);
    Exit;
  end
  else if Expr is TASTLambdaExpr then
  begin
    Lam := TASTLambdaExpr(Expr);
    RegisterLambda(Lam);
    FnTag := RegisterFnType(Lam.ResolvedFnType);
    if Lam.CaptureNames.Count = 0 then
      Result := Format('((AetherFn_%s){ __aether_lambda_%d, NULL })', [FnTag, Lam.LambdaId])
    else
    begin
      ArgsStr := '';
      for I := 0 to Lam.CaptureNames.Count - 1 do
      begin
        if I > 0 then ArgsStr := ArgsStr + ', ';
        if IsMutBorrowParam(Lam.CaptureNames[I]) then
          ArgsStr := ArgsStr + '(*' + Lam.CaptureNames[I] + ')'
        else
          ArgsStr := ArgsStr + Lam.CaptureNames[I];
      end;
      Result := Format('__aether_make_lambda_%d(%s)', [Lam.LambdaId, ArgsStr]);
    end;
    Exit;
  end;

  Result := '';
end;

procedure TAetherEmitterC.EmitActiveDefers(DownToIndex: Integer);
var
  I: Integer;
begin
  for I := FActiveDefers.Count - 1 downto DownToIndex do
    EmitStmt(TASTStmt(FActiveDefers[I]));
end;

function TAetherEmitterC.FindDropFunc(const ATypeName: string): TASTFunction;
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

function TAetherEmitterC.RaiiExprUsesVar(Expr: TASTExpr; const AVarName: string): Boolean;
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
    if RaiiExprUsesVar(TASTLambdaExpr(Expr).BodyExpr, AVarName) then Exit(True);
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

function TAetherEmitterC.IsNonBorrowArgCapture(Call: TASTCallExpr; ArgIdx: Integer): Boolean;
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

function TAetherEmitterC.IsVarEscapedInStmts(const AVarName: string; Stmts: TASTNodeList): Boolean;
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

procedure TAetherEmitterC.RegisterRaiiVar(const AVarName, ATypeName: string; ScopeStmts: TASTNodeList);
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

procedure TAetherEmitterC.EmitRaiiCleanupFor(const AVarName, ATypeName: string);
var
  BaseT, InnerT, KeyT, ValT, DropCall: string;
  DropFn: TASTFunction;
begin
  BaseT := ResolveAliasType(ATypeName);
  DropFn := FindDropFunc(BaseT);
  if Assigned(DropFn) then
  begin
    if (DropFn.Params.Count > 0) and (TASTParam(DropFn.Params[0]).Ownership = owMutBorrow) then
      Emit(Format('%s(&%s);', [DropFn.Name, AVarName]))
    else
      Emit(Format('%s(%s);', [DropFn.Name, AVarName]));
    Exit;
  end;
  if Pos('Box<', BaseT) = 1 then
  begin
    InnerT := Trim(Copy(BaseT, 5, Length(BaseT) - 5));
    DropFn := FindDropFunc(InnerT);
    DropCall := '';
    if Assigned(DropFn) then
    begin
      if (DropFn.Params.Count > 0) and (TASTParam(DropFn.Params[0]).Ownership = owMutBorrow) then
        DropCall := Format('%s(%s); ', [DropFn.Name, AVarName])
      else
        DropCall := Format('%s(*%s); ', [DropFn.Name, AVarName]);
    end;
    Emit(Format('if (%s) { %sfree((void*)%s); %s = NULL; }', [AVarName, DropCall, AVarName, AVarName]));
  end
  else if IsDynamicArrayType(BaseT) then
  begin
    Emit(Format('if (%s) { AetherDynFree(%s); %s = NULL; }', [AVarName, AVarName, AVarName]));
  end
  else if IsMapType(BaseT, KeyT, ValT) then
  begin
    Emit(Format('if (%s.entries) { free(%s.entries); %s.entries = NULL; %s.count = 0; %s.capacity = 0; }',
      [AVarName, AVarName, AVarName, AVarName, AVarName]));
  end;
end;

procedure TAetherEmitterC.EmitActiveRaii(DownToIndex: Integer);
var
  I: Integer;
begin
  for I := FRaiiNames.Count - 1 downto DownToIndex do
    EmitRaiiCleanupFor(FRaiiNames[I], FRaiiTypes[I]);
end;

procedure TAetherEmitterC.EmitStmtList(List: TASTNodeList; IsLoopBody: Boolean);
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

procedure TAetherEmitterC.BuildMatchCaseCond(CaseNode: TASTMatchCase; const ExprStr, MatchedType: string;
  out CondStr, BindStmt, BindVarType: string; out IsWildcardArm: Boolean);
var
  PatStr, ValF, ErrF, PatItem, LoStr, HiStr, LoExpr, HiExpr, ItemCond, BindExprStr, GuardStr: string;
  K, P2, BIdx, BCount, GuardAdded, PDot, J: Integer;
  Enm: TASTEnumDecl;
  VarN: TASTEnumVariant;
  VarName, BName, BType: string;

  function FormatMatchAtom(const S, MT: string): string;
  begin
    if (Length(S) >= 2) and (S[1] = '''') then
      Result := EscapeCChar(Copy(S, 2, Length(S) - 2))
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
      BindStmt := Format('%s %s = %s;', [EmitTypeRef(MatchedType), CaseNode.Pattern.SubPattern, ExprStr]);
      FGuardBindNames.Add(CaseNode.Pattern.SubPattern);
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
      if IsTypedResult(MatchedType, ValF, ErrF) then
        BindExprStr := ExprStr + '.value'
      else
        BindExprStr := EmitMonadFieldExtract(ExprStr, ValF, 'value', 'str_val');
      BindStmt := Format('%s %s = %s;', [EmitTypeRef(ValF), CaseNode.Pattern.SubPattern, BindExprStr]);
      FGuardBindNames.Add(CaseNode.Pattern.SubPattern);
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
        if IsTypedResult(MatchedType, ValF, ErrF) then
          BindExprStr := ExprStr + '.error'
        else if ResolveAliasType(ErrF) = 'String' then
          BindExprStr := ExprStr + '.err_str'
        else
          BindExprStr := Format('((%s)(%s.error))', [EmitTypeRef(ErrF), ExprStr]);
        BindStmt := Format('%s %s = %s;', [EmitTypeRef(ErrF), CaseNode.Pattern.SubPattern, BindExprStr]);
        FGuardBindNames.Add(CaseNode.Pattern.SubPattern);
        FGuardBindExprs.Add(BindExprStr);
        Inc(GuardAdded);
      end
      else if IsTypedResult(MatchedType, ValF, ErrF) then
      begin
        if (Length(CaseNode.Pattern.SubPattern) >= 2) and (CaseNode.Pattern.SubPattern[1] = '"') then
          CondStr := Format('%s.is_err && strcmp(%s.error, %s) == 0',
            [ExprStr, ExprStr, EscapeCString(Copy(CaseNode.Pattern.SubPattern, 2, Length(CaseNode.Pattern.SubPattern) - 2))])
        else
          CondStr := Format('%s.is_err && %s.error == %s',
            [ExprStr, ExprStr, StringReplace(CaseNode.Pattern.SubPattern, '.', '_', [rfReplaceAll])]);
      end
      else if (Length(CaseNode.Pattern.SubPattern) >= 2) and (CaseNode.Pattern.SubPattern[1] = '"') then
        CondStr := Format('%s.is_err && strcmp(%s.err_str, %s) == 0',
          [ExprStr, ExprStr, EscapeCString(Copy(CaseNode.Pattern.SubPattern, 2, Length(CaseNode.Pattern.SubPattern) - 2))])
      else
        CondStr := Format('%s.is_err && %s.error == %s',
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
        BindExprStr := ExprStr + '.value';
        BindStmt := Format('%s %s = %s;', [EmitTypeRef(ValF), CaseNode.Pattern.SubPattern, BindExprStr]);
        FGuardBindNames.Add(CaseNode.Pattern.SubPattern);
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
        BindExprStr := EmitMonadFieldExtract(ExprStr, ValF, 'num_val', 'str_val');
        BindStmt := Format('%s %s = %s;', [EmitTypeRef(ValF), CaseNode.Pattern.SubPattern, BindExprStr]);
        FGuardBindNames.Add(CaseNode.Pattern.SubPattern);
        FGuardBindExprs.Add(BindExprStr);
        Inc(GuardAdded);
      end;
    end
    else
    begin
      CondStr := Format('%s != NULL', [ExprStr]);
      if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
      begin
        if Pos('Option<', MatchedType) = 1 then
        begin
          BindVarType := SafeUnwrapGeneric(MatchedType, 'Option');
          BindStmt := Format('%s %s = %s;', [EmitTypeRef(BindVarType), CaseNode.Pattern.SubPattern, ExprStr]);
        end
        else
          BindStmt := Format('void* %s = %s;', [CaseNode.Pattern.SubPattern, ExprStr]);
        FGuardBindNames.Add(CaseNode.Pattern.SubPattern);
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
      CondStr := Format('%s == NULL', [ExprStr]);
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
      ItemCond := Format('%s.tag == %s_Tag_%s', [ExprStr, Enm.Name, VarName]);
      if K > 0 then CondStr := CondStr + ' || ';
      CondStr := CondStr + ItemCond;
    end;
    if CaseNode.Pattern.Items.Count > 1 then
      CondStr := '(' + CondStr + ')';

    BCount := GetMatchArmBindingCount(CaseNode);
    if Assigned(VarN) and (BCount > 0) then
    begin
      for BIdx := 0 to BCount - 1 do
      begin
        GetMatchArmBindingInfo(CaseNode, BIdx, MatchedType, BName, BType);
        if (BIdx < VarN.Fields.Count) then
        begin
          BindExprStr := Format('%s.data.%s.%s', [ExprStr, VarN.Name, TASTRecordField(VarN.Fields[BIdx]).Name]);
          if (BName <> '') and (BName <> '_') then
          begin
            BindStmt := BindStmt + Format('%s %s = %s; ', [EmitTypeRef(BType), BName, BindExprStr]);
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
        ItemCond := Format('(%s >= %s && %s <= %s)', [ExprStr, LoExpr, ExprStr, HiExpr]);
      end
      else if (Length(PatItem) >= 2) and (PatItem[1] = '"') then
        ItemCond := Format('strcmp(%s, %s) == 0', [ExprStr, EscapeCString(Copy(PatItem, 2, Length(PatItem) - 2))])
      else
        ItemCond := Format('%s == %s', [ExprStr, FormatMatchAtom(PatItem, MatchedType)]);
      if K > 0 then CondStr := CondStr + ' || ';
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
      CondStr := Format('((%s) && (%s))', [CondStr, GuardStr]);
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

procedure TAetherEmitterC.EmitLocalVarDecl(VarDecl: TASTVarDecl; InTryBody: TASTNodeList);
var
  VolQual, KeyT, ValT: string;
begin
  if IsMapType(VarDecl.TypeName, KeyT, ValT) then
  begin
    Emit(Format('%s %s;', [EmitTypeRef(VarDecl.TypeName), VarDecl.Name]));
    Emit(Format('memset(&%s, 0, sizeof(%s));', [VarDecl.Name, VarDecl.Name]));
    if Assigned(VarDecl.InitialExpr) then
    begin
      if VarDecl.InitialExpr is TASTMapLiteralExpr then
        EmitMapLiteralAssign(VarDecl.Name, VarDecl.TypeName, TASTMapLiteralExpr(VarDecl.InitialExpr))
      else
        Emit(Format('%s = %s;', [VarDecl.Name, EmitExpr(VarDecl.InitialExpr)]));
    end;
  end
  else if Pos('array[', VarDecl.TypeName) = 1 then
  begin
    Emit(FormatCArrayVar(VarDecl.TypeName, VarDecl.Name));
    Emit(Format('memset(&%s, 0, sizeof(%s));', [VarDecl.Name, VarDecl.Name]));
    if Assigned(VarDecl.InitialExpr) then
    begin
      if (VarDecl.InitialExpr is TASTSetLiteralExpr) and (not IsSetType(VarDecl.TypeName)) then
        EmitArrayLiteralAssign(VarDecl.Name, VarDecl.TypeName, TASTSetLiteralExpr(VarDecl.InitialExpr))
      else
        Emit(Format('%s = %s;', [VarDecl.Name, EmitExpr(VarDecl.InitialExpr)]));
    end;
  end
  else
  begin
    VolQual := '';
    if Assigned(InTryBody) and IsVarModifiedInTry(VarDecl.Name, InTryBody) then
      VolQual := 'volatile ';
    if (IsDynamicArrayType(VarDecl.TypeName) or (Pos('Box<', ResolveAliasType(VarDecl.TypeName)) = 1) or
        (Pos('^', VarDecl.TypeName) = 1) or (VarDecl.TypeName = 'Pointer')) and
       ((not Assigned(VarDecl.InitialExpr)) or (VarDecl.InitialExpr is TASTSetLiteralExpr)) then
      Emit(Format('%s %s%s = NULL;', [EmitTypeRef(VarDecl.TypeName), VolQual, VarDecl.Name]))
    else
      Emit(Format('%s %s%s;', [EmitTypeRef(VarDecl.TypeName), VolQual, VarDecl.Name]));
    if Assigned(VarDecl.InitialExpr) then
    begin
      if VarDecl.InitialExpr is TASTMapLiteralExpr then
        EmitMapLiteralAssign(VarDecl.Name, VarDecl.TypeName, TASTMapLiteralExpr(VarDecl.InitialExpr))
      else if (VarDecl.InitialExpr is TASTSetLiteralExpr) and (not IsSetType(VarDecl.TypeName)) then
        EmitArrayLiteralAssign(VarDecl.Name, VarDecl.TypeName, TASTSetLiteralExpr(VarDecl.InitialExpr))
      else
        Emit(Format('%s = %s;', [VarDecl.Name, EmitExpr(VarDecl.InitialExpr)]));
    end;
  end;
end;

procedure TAetherEmitterC.EmitStmt(Stmt: TASTStmt);
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
  LineStr: string;
  I, J, BIdx, BCount: Integer;
  TName, KeyT, ValT, ColStr, ColType, ElemT, LoopId, MatchedType, ExprStr, Prefix, CondStr, BindStmt, BindVarType, BName, BType, TargetT: string;
  IsWild: Boolean;
begin
  if Stmt is TASTVarDeclStmt then
  begin
    for I := 0 to TASTVarDeclStmt(Stmt).Decls.Count - 1 do
    begin
      VD := TASTVarDecl(TASTVarDeclStmt(Stmt).Decls[I]);
      if Assigned(FCurrentFunc) then
        EmitLocalVarDecl(VD, FCurrentFunc.Body)
      else if Assigned(FProgramBlock) then
        EmitLocalVarDecl(VD, FProgramBlock.Body)
      else
        EmitLocalVarDecl(VD, nil);
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
      Emit(Format('AetherMapSet_%s(&(%s), %s, %s);', [
        MapTag(KeyT, ValT),
        EmitExpr(TASTIndexExpr(Assign.Target).Target),
        EmitExpr(TASTExpr(TASTIndexExpr(Assign.Target).Indices[0])),
        EmitExpr(Assign.Expr)]))
    else if (Assign.Target is TASTIdentifierExpr) and IsMutBorrowParam(TASTIdentifierExpr(Assign.Target).Name) then
      Emit(Format('*%s = %s;', [TASTIdentifierExpr(Assign.Target).Name, EmitExpr(Assign.Expr)]))
    else
      Emit(Format('%s = %s;', [EmitExpr(Assign.Target), EmitExpr(Assign.Expr)]));
  end
  else if Stmt is TASTCallStmt then
  begin
    CallStmt := TASTCallStmt(Stmt);
    Emit(EmitExpr(CallStmt.CallExpr) + ';');
  end
  else if Stmt is TASTIfStmt then
  begin
    IfStmt := TASTIfStmt(Stmt);
    Emit(Format('if (%s) {', [EmitExpr(IfStmt.Condition)]));
    IncIndent;
    EmitStmtList(IfStmt.ThenBranch);
    DecIndent;
    if IfStmt.ElseBranch.Count > 0 then
    begin
      Emit('} else {');
      IncIndent;
      EmitStmtList(IfStmt.ElseBranch);
      DecIndent;
    end;
    Emit('}');
  end
  else if Stmt is TASTWhileStmt then
  begin
    WhileStmt := TASTWhileStmt(Stmt);
    Emit(Format('while (%s) {', [EmitExpr(WhileStmt.Condition)]));
    IncIndent;
    EmitStmtList(WhileStmt.Body, True);
    DecIndent;
    Emit('}');
  end
  else if Stmt is TASTForStmt then
  begin
    ForStmt := TASTForStmt(Stmt);
    if Assigned(ForStmt.CollectionExpr) then
    begin
      Inc(FLoopCounter);
      LoopId := IntToStr(FLoopCounter);
      ColStr := EmitExpr(ForStmt.CollectionExpr);
      ColType := ResolveAliasType(GetExprTypeName(ForStmt.CollectionExpr));
      if IsMapType(ColType, KeyT, ValT) then
      begin
        Emit('{');
        IncIndent;
        Emit(Format('for (int32_t _aether_i_%s = 0; _aether_i_%s < (%s).count; _aether_i_%s++) {', [LoopId, LoopId, ColStr, LoopId]));
        IncIndent;
        Emit(Format('%s = (%s).entries[_aether_i_%s].key;', [ForStmt.VarName, ColStr, LoopId]));
        if ForStmt.ValVarName <> '' then
          Emit(Format('%s = (%s).entries[_aether_i_%s].val;', [ForStmt.ValVarName, ColStr, LoopId]));
        EmitStmtList(ForStmt.Body, True);
        DecIndent;
        Emit('}');
        DecIndent;
        Emit('}');
      end
      else if ColType = 'String' then
      begin
        Emit('{');
        IncIndent;
        Emit(Format('const char* _aether_col_%s = %s;', [LoopId, ColStr]));
        Emit(Format('size_t _aether_len_%s = _aether_col_%s ? strlen(_aether_col_%s) : 0;', [LoopId, LoopId, LoopId]));
        Emit(Format('for (size_t _aether_i_%s = 0; _aether_i_%s < _aether_len_%s; _aether_i_%s++) {', [LoopId, LoopId, LoopId, LoopId]));
        IncIndent;
        Emit(Format('%s = _aether_col_%s[_aether_i_%s];', [ForStmt.VarName, LoopId, LoopId]));
        EmitStmtList(ForStmt.Body, True);
        DecIndent;
        Emit('}');
        DecIndent;
        Emit('}');
      end
      else if IsDynamicArrayType(ColType) then
      begin
        ElemT := GetCollectionElemType(ForStmt.CollectionExpr);
        Emit('{');
        IncIndent;
        Emit(Format('%s* _aether_col_%s = %s;', [EmitTypeRef(ElemT), LoopId, ColStr]));
        Emit(Format('size_t _aether_len_%s = AetherDynLen(_aether_col_%s);', [LoopId, LoopId]));
        Emit(Format('for (size_t _aether_i_%s = 0; _aether_i_%s < _aether_len_%s; _aether_i_%s++) {', [LoopId, LoopId, LoopId, LoopId]));
        IncIndent;
        Emit(Format('%s = _aether_col_%s[_aether_i_%s];', [ForStmt.VarName, LoopId, LoopId]));
        EmitStmtList(ForStmt.Body, True);
        DecIndent;
        Emit('}');
        DecIndent;
        Emit('}');
      end
      else
      begin
        Emit(Format('for (size_t _aether_i_%s = 0; _aether_i_%s < (sizeof(%s) / sizeof((%s)[0])); _aether_i_%s++) {', [LoopId, LoopId, ColStr, ColStr, LoopId]));
        IncIndent;
        Emit(Format('%s = (%s)[_aether_i_%s];', [ForStmt.VarName, ColStr, LoopId]));
        EmitStmtList(ForStmt.Body, True);
        DecIndent;
        Emit('}');
      end;
    end
    else
    begin
      if ForStmt.IsDownTo then
        Emit(Format('for (%s = %s; %s >= %s; %s--) {', [ForStmt.VarName, EmitExpr(ForStmt.StartExpr), ForStmt.VarName, EmitExpr(ForStmt.EndExpr), ForStmt.VarName]))
      else
        Emit(Format('for (%s = %s; %s <= %s; %s++) {', [ForStmt.VarName, EmitExpr(ForStmt.StartExpr), ForStmt.VarName, EmitExpr(ForStmt.EndExpr), ForStmt.VarName]));
      IncIndent;
      EmitStmtList(ForStmt.Body, True);
      DecIndent;
      Emit('}');
    end;
  end
  else if Stmt is TASTRepeatStmt then
  begin
    RepeatStmt := TASTRepeatStmt(Stmt);
    Emit('do {');
    IncIndent;
    EmitStmtList(RepeatStmt.Body, True);
    DecIndent;
    Emit(Format('} while (!(%s));', [EmitExpr(RepeatStmt.Condition)]));
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
    Emit('g_aether_jmp_top++;');
    Emit('if (setjmp(g_aether_jmp_stack[g_aether_jmp_top - 1]) == 0) {');
    IncIndent;
    Inc(FTryDepth);
    EmitStmtList(TASTTryStmt(Stmt).TryBody);
    Dec(FTryDepth);
    Emit('g_aether_jmp_top--;');
    DecIndent;
    Emit('} else {');
    IncIndent;
    EmitStmtList(TASTTryStmt(Stmt).ExceptBody);
    DecIndent;
    Emit('}');
  end
  else if Stmt is TASTRaiseStmt then
  begin
    Emit(Format('AetherRaise(%s);', [EmitExpr(TASTRaiseStmt(Stmt).Expr)]));
  end
  else if Stmt is TASTUnsafeStmt then
  begin
    Emit('// unsafe block');
    Emit('{');
    IncIndent;
    EmitStmtList(TASTUnsafeStmt(Stmt).Body);
    DecIndent;
    Emit('}');
  end
  else if Stmt is TASTReturnStmt then
  begin
    Ret := TASTReturnStmt(Stmt);
    if (FActiveDefers.Count > 0) or (FRaiiNames.Count > 0) or (Assigned(FCurrentFunc) and (FCurrentFunc.Ensures.Count > 0)) then
    begin
      if Assigned(Ret.Expr) then
      begin
        if Assigned(FCurrentFunc) and FCurrentFunc.IsAsync then
        begin
          TName := GetExprTypeName(Ret.Expr);
          if (TName = 'Float') or (TName = 'Float32') or (TName = 'Float64') or (TName = 'Double') then
            Emit(Format('AetherTask __ret_task = (AetherTask){ .is_completed = true, .float_val = %s };', [EmitExpr(Ret.Expr)]))
          else if TName = 'String' then
            Emit(Format('AetherTask __ret_task = (AetherTask){ .is_completed = true, .str_val = %s };', [EmitExpr(Ret.Expr)]))
          else
            Emit(Format('AetherTask __ret_task = (AetherTask){ .is_completed = true, .int_val = (int64_t)(%s) };', [EmitExpr(Ret.Expr)]));
          if FActiveDefers.Count > 0 then
            EmitActiveDefers(0);
          if Assigned(FCurrentFunc) then
            for J := 0 to FCurrentFunc.Ensures.Count - 1 do
              Emit(Format('assert(%s);', [EmitExpr(TASTExpr(FCurrentFunc.Ensures[J]))]));
          if FRaiiNames.Count > 0 then
            EmitActiveRaii(0);
          if FTryDepth > 0 then
            Emit(Format('g_aether_jmp_top -= %d;', [FTryDepth]));
          Emit('return __ret_task;');
        end
        else
        begin
          Emit(Format('result = %s;', [EmitExpr(Ret.Expr)]));
          if FActiveDefers.Count > 0 then
            EmitActiveDefers(0);
          if Assigned(FCurrentFunc) then
            for J := 0 to FCurrentFunc.Ensures.Count - 1 do
              Emit(Format('assert(%s);', [EmitExpr(TASTExpr(FCurrentFunc.Ensures[J]))]));
          if FRaiiNames.Count > 0 then
            EmitActiveRaii(0);
          if FTryDepth > 0 then
            Emit(Format('g_aether_jmp_top -= %d;', [FTryDepth]));
          Emit('return result;');
        end;
      end
      else
      begin
        if FActiveDefers.Count > 0 then
          EmitActiveDefers(0);
        if Assigned(FCurrentFunc) then
          for J := 0 to FCurrentFunc.Ensures.Count - 1 do
            Emit(Format('assert(%s);', [EmitExpr(TASTExpr(FCurrentFunc.Ensures[J]))]));
        if FRaiiNames.Count > 0 then
          EmitActiveRaii(0);
        if FTryDepth > 0 then
          Emit(Format('g_aether_jmp_top -= %d;', [FTryDepth]));
        Emit('return;');
      end;
    end
    else
    begin
      if FTryDepth > 0 then
        Emit(Format('g_aether_jmp_top -= %d;', [FTryDepth]));
      if Assigned(Ret.Expr) then
      begin
        if Assigned(FCurrentFunc) and FCurrentFunc.IsAsync then
        begin
          TName := GetExprTypeName(Ret.Expr);
          if (TName = 'Float') or (TName = 'Float32') or (TName = 'Float64') or (TName = 'Double') then
            Emit(Format('return (AetherTask){ .is_completed = true, .float_val = %s };', [EmitExpr(Ret.Expr)]))
          else if TName = 'String' then
            Emit(Format('return (AetherTask){ .is_completed = true, .str_val = %s };', [EmitExpr(Ret.Expr)]))
          else
            Emit(Format('return (AetherTask){ .is_completed = true, .int_val = (int64_t)(%s) };', [EmitExpr(Ret.Expr)]));
        end
        else
          Emit(Format('return %s;', [EmitExpr(Ret.Expr)]));
      end
      else
        Emit('return;');
    end;
  end
  else if Stmt is TASTAsmStmt then
  begin
    Emit('__asm__ volatile (');
    IncIndent;
    Emit('".intel_syntax noprefix\n\t"');
    Lines := TStringList.Create;
    try
      Lines.Text := TASTAsmStmt(Stmt).AsmCode;
      for J := 0 to Lines.Count - 1 do
      begin
        LineStr := Trim(Lines[J]);
        if LineStr <> '' then
          Emit('"' + LineStr + '\n\t"');
      end;
    finally
      Lines.Free;
    end;
    Emit('".att_syntax prefix"');
    DecIndent;
    Emit(');');
  end
  else if Stmt is TASTMatchStmt then
  begin
    MatchStmt := TASTMatchStmt(Stmt);
    MatchedType := ResolveAliasType(GetExprTypeName(MatchStmt.Expr));
    if MatchedType = '' then MatchedType := 'Int32';
    ExprStr := Format('_amv_%d_%d', [MatchStmt.Line, MatchStmt.Col]);
    Emit('// Match generated by the Aether compiler');
    Emit(Format('{ %s %s = %s;', [EmitTypeRef(MatchedType), ExprStr, EmitExpr(MatchStmt.Expr)]));
    for I := 0 to MatchStmt.Cases.Count - 1 do
    begin
      CaseNode := TASTMatchCase(MatchStmt.Cases[I]);
      BuildMatchCaseCond(CaseNode, ExprStr, MatchedType, CondStr, BindStmt, BindVarType, IsWild);
      if IsWild then
      begin
        if I > 0 then
          Emit('} else {')
        else
          Emit('{');
      end
      else
      begin
        if I = 0 then Prefix := 'if (' else Prefix := '} else if (';
        if CondStr = '' then CondStr := 'true';
        Emit(Prefix + CondStr + ') {');
      end;
      IncIndent;
      if BindStmt <> '' then Emit(BindStmt);
      BCount := GetMatchArmBindingCount(CaseNode);
      PushMatchBindings(CaseNode, MatchedType);
      try
        for J := 0 to CaseNode.Body.Count - 1 do
          EmitStmt(TASTStmt(CaseNode.Body[J]));
      finally
        for BIdx := 0 to BCount - 1 do
        begin
          GetMatchArmBindingInfo(CaseNode, BIdx, MatchedType, BName, BType);
          if (BName <> '') and (BName <> '_') then PopMatchBindings(1);
        end;
      end;
      DecIndent;
    end;
    if MatchStmt.Cases.Count > 0 then
      Emit('}');
    Emit('}');
  end;
end;

procedure TAetherEmitterC.EmitRecordDecl(Rec: TASTRecordDecl);
var
  I: Integer;
  Field: TASTRecordField;
  CtorParams, CtorInit: string;
  HasFixedArr: Boolean;
begin
  Emit(Format('struct T%s {', [Rec.Name]));
  IncIndent;
  for I := 0 to Rec.Fields.Count - 1 do
  begin
    Field := TASTRecordField(Rec.Fields[I]);
    Emit(Format('%s %s;', [EmitTypeRef(Field.TypeName), Field.Name]));
  end;
  DecIndent;
  Emit('};');
  Emit('');

  // DataBuffer(id, size)-style constructor
  CtorParams := '';
  CtorInit := '';
  HasFixedArr := False;
  for I := 0 to Rec.Fields.Count - 1 do
  begin
    Field := TASTRecordField(Rec.Fields[I]);
    if IsFixedArrayType(Field.TypeName) then
      HasFixedArr := True;
    CtorParams := CtorParams + Format('%s a_%s', [EmitTypeRef(Field.TypeName), Field.Name]);
    CtorInit := CtorInit + Format('.%s = a_%s', [Field.Name, Field.Name]);
    if I < Rec.Fields.Count - 1 then
    begin
      CtorParams := CtorParams + ', ';
      CtorInit := CtorInit + ', ';
    end;
  end;
  if not HasFixedArr then
    Emit(Format('static inline T%s %s(%s) { return (T%s){ %s }; }', [Rec.Name, Rec.Name, CtorParams, Rec.Name, CtorInit]))
  else
  begin
    Emit(Format('static inline T%s %s(%s) {', [Rec.Name, Rec.Name, CtorParams]));
    Emit(Format('    T%s _r;', [Rec.Name]));
    Emit('    memset(&_r, 0, sizeof(_r));');
    for I := 0 to Rec.Fields.Count - 1 do
    begin
      Field := TASTRecordField(Rec.Fields[I]);
      if IsFixedArrayType(Field.TypeName) then
        Emit(Format('    if (a_%s) memcpy(_r.%s, a_%s, sizeof(_r.%s));', [Field.Name, Field.Name, Field.Name, Field.Name]))
      else
        Emit(Format('    _r.%s = a_%s;', [Field.Name, Field.Name]));
    end;
    Emit('    return _r;');
    Emit('}');
  end;
  Emit('');
end;

procedure TAetherEmitterC.EmitEnumDecl(Enm: TASTEnumDecl);
var
  I, J: Integer;
  V: TASTEnumVariant;
  F: TASTRecordField;
  VariantName, ParamsStr, AssignStr: string;
  HasAnyFields: Boolean;
begin
  if Enm.HasPayload then
  begin
    Emit('typedef enum {');
    IncIndent;
    for I := 0 to Enm.Variants.Count - 1 do
    begin
      VariantName := Enm.Name + '_Tag_' + TASTEnumVariant(Enm.Variants[I]).Name;
      if I < Enm.Variants.Count - 1 then Emit(VariantName + ',')
      else Emit(VariantName);
    end;
    DecIndent;
    Emit(Format('} T%s_Tag;', [Enm.Name]));
    Emit(Format('struct T%s {', [Enm.Name]));
    IncIndent;
    Emit(Format('T%s_Tag tag;', [Enm.Name]));
    HasAnyFields := False;
    for I := 0 to Enm.Variants.Count - 1 do
      if TASTEnumVariant(Enm.Variants[I]).Fields.Count > 0 then
      begin
        HasAnyFields := True;
        Break;
      end;
    if HasAnyFields then
    begin
      Emit('union {');
      IncIndent;
      for I := 0 to Enm.Variants.Count - 1 do
      begin
        V := TASTEnumVariant(Enm.Variants[I]);
        if V.Fields.Count = 0 then Continue;
        Emit('struct {');
        IncIndent;
        for J := 0 to V.Fields.Count - 1 do
        begin
          F := TASTRecordField(V.Fields[J]);
          Emit(Format('%s %s;', [EmitTypeRef(F.TypeName), F.Name]));
        end;
        DecIndent;
        Emit(Format('} %s;', [V.Name]));
      end;
      DecIndent;
      Emit('} data;');
    end;
    DecIndent;
    Emit('};');
    Emit(Format('typedef T%s %s;', [Enm.Name, Enm.Name]));
    for I := 0 to Enm.Variants.Count - 1 do
    begin
      V := TASTEnumVariant(Enm.Variants[I]);
      ParamsStr := '';
      AssignStr := Format('_r.tag = %s_Tag_%s; ', [Enm.Name, V.Name]);
      if V.Fields.Count = 0 then
        ParamsStr := 'void'
      else
        for J := 0 to V.Fields.Count - 1 do
        begin
          F := TASTRecordField(V.Fields[J]);
          if J > 0 then ParamsStr := ParamsStr + ', ';
          ParamsStr := ParamsStr + Format('%s a_%s', [EmitTypeRef(F.TypeName), F.Name]);
          AssignStr := AssignStr + Format('_r.data.%s.%s = a_%s; ', [V.Name, F.Name, F.Name]);
        end;
      Emit(Format('static inline T%s %s_%s(%s) { T%s _r; memset(&_r, 0, sizeof(_r)); %sreturn _r; }',
        [Enm.Name, Enm.Name, V.Name, ParamsStr, Enm.Name, AssignStr]));
    end;
    Emit('');
    Exit;
  end;

  Emit('typedef enum {');
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
  Emit(Format('} T%s;', [Enm.Name]));
  Emit(Format('typedef T%s %s;', [Enm.Name, Enm.Name]));
  for I := 0 to Enm.Variants.Count - 1 do
    Emit(Format('#define %s %s_%s', [TASTEnumVariant(Enm.Variants[I]).Name, Enm.Name, TASTEnumVariant(Enm.Variants[I]).Name]));
  Emit('');
end;

procedure TAetherEmitterC.EmitArrayDecl(Arr: TASTArrayDecl);
var
  I: Integer;
  DimsStr: string;
begin
  if Arr.Dims.Count = 0 then
  begin
    Emit(Format('typedef %s* T%s;', [EmitTypeRef(Arr.ElemType), Arr.Name]));
    Emit(Format('typedef T%s %s;', [Arr.Name, Arr.Name]));
    Emit('');
    Exit;
  end;
  DimsStr := '';
  for I := 0 to Arr.Dims.Count - 1 do
    DimsStr := DimsStr + Format('[%s]', [Arr.Dims[I]]);
  Emit(Format('typedef %s T%s%s;', [EmitTypeRef(Arr.ElemType), Arr.Name, DimsStr]));
  Emit(Format('typedef T%s %s;', [Arr.Name, Arr.Name]));
  Emit('');
end;

procedure TAetherEmitterC.EmitSetDecl(SetD: TASTSetDecl);
var
  I: Integer;
  VName: string;
begin
  if SetD.Variants.Count > 0 then
  begin
    Emit('typedef enum {');
    IncIndent;
    for I := 0 to SetD.Variants.Count - 1 do
    begin
      VName := TASTEnumVariant(SetD.Variants[I]).Name;
      if I < SetD.Variants.Count - 1 then
        Emit(Format('AETHER_SET_%s_%s = %d,', [SetD.Name, VName, I]))
      else
        Emit(Format('AETHER_SET_%s_%s = %d', [SetD.Name, VName, I]));
    end;
    DecIndent;
    Emit(Format('} T%s_Enum;', [SetD.Name]));
    for I := 0 to SetD.Variants.Count - 1 do
    begin
      VName := TASTEnumVariant(SetD.Variants[I]).Name;
      Emit(Format('#define %s %d', [VName, I]));
    end;
  end;
  Emit(Format('typedef uint32_t T%s;', [SetD.Name]));
  Emit(Format('typedef T%s %s;', [SetD.Name, SetD.Name]));
  Emit('');
end;

procedure TAetherEmitterC.EmitSubrangeDecl(SubR: TASTSubrangeDecl);
begin
  if SubR.BaseType = 'Char' then
  begin
    Emit(Format('typedef char T%s;', [SubR.Name]));
    Emit(Format('typedef T%s %s;', [SubR.Name, SubR.Name]));
  end
  else
  begin
    Emit(Format('typedef int32_t T%s;', [SubR.Name]));
    Emit(Format('typedef T%s %s;', [SubR.Name, SubR.Name]));
  end;
  Emit('');
end;

procedure TAetherEmitterC.EmitMapDecl(MapD: TASTMapDecl);
begin
  Emit(Format('typedef TAetherMap_%s T%s;', [MapTag(MapD.KeyType, MapD.ValType), MapD.Name]));
  Emit(Format('typedef T%s %s;', [MapD.Name, MapD.Name]));
  Emit('');
end;

procedure TAetherEmitterC.EmitTypeAliasDecl(AliasD: TASTTypeAliasDecl);
begin
  Emit(Format('typedef %s T%s;', [EmitTypeRef(AliasD.TargetType), AliasD.Name]));
  Emit(Format('typedef T%s %s;', [AliasD.Name, AliasD.Name]));
  Emit('');
end;

procedure TAetherEmitterC.EmitFunction(Func: TASTFunction);
var
  ParamListStr, ExportPrefix: string;
  I: Integer;
  Param: TASTParam;
  ModStr, VolQual, KeyT, ValT: string;
  VarDecl: TASTVarDecl;
  SkipNames, AutoNames, AutoTypes: TStringList;
begin
  if (Func.GenericParams.Count > 0) or (Func.GenericParam <> '') then Exit; // Generic template does not emit code directly
  if SameText(Func.Name, 'Abs') or SameText(Func.Name, 'Min') or SameText(Func.Name, 'Max') or SameText(Func.Name, 'Clamp') then Exit;
  if Func.IsExtern then
  begin
    if Func.ExternAbi = 'pascal' then
    begin
      if Func.Name = 'Now' then
      begin
        Emit('static inline double Now(void) { return AetherPascalNow(); }');
        Emit('');
        Exit;
      end
      else if Func.Name = 'GetTickCount64' then
      begin
        Emit('#ifndef _WIN32');
        Emit('static inline uint64_t GetTickCount64(void) { return AetherPascalGetTickCount64(); }');
        Emit('#endif');
        Emit('');
        Exit;
      end;
    end;

    // Functions from math.h must not be redeclared with plain extern to avoid conflicting with GCC attributes
    if (Func.ExternAbi = 'c') and ((Func.Name = 'sin') or (Func.Name = 'cos') or (Func.Name = 'sqrt') or
       (Func.Name = 'tan') or (Func.Name = 'abs') or (Func.Name = 'floor') or (Func.Name = 'ceil')) then
    begin
      Emit(Format('// Extern C Math: %s (provided by <math.h>)', [Func.Name]));
      Emit('');
      Exit;
    end;

    ParamListStr := '';
    for I := 0 to Func.Params.Count - 1 do
    begin
      Param := TASTParam(Func.Params[I]);
      ModStr := '';
      if Param.Ownership = owMutBorrow then
        ModStr := '*'
      else if Param.Ownership = owBorrow then
        ModStr := '';
      ParamListStr := ParamListStr + Format('%s %s%s', [EmitTypeRef(Param.TypeName), ModStr, Param.Name]);
      if I < Func.Params.Count - 1 then
        ParamListStr := ParamListStr + ', ';
    end;
    if ParamListStr = '' then ParamListStr := 'void';
    Emit(Format('extern %s %s(%s);', [EmitTypeRef(Func.ReturnType), Func.Name, ParamListStr]));
    Emit('');
    Exit;
  end;

  FCurrentFunc := Func;
  ParamListStr := '';
  for I := 0 to Func.Params.Count - 1 do
  begin
    Param := TASTParam(Func.Params[I]);
    ModStr := '';
    if Param.Ownership = owMutBorrow then
      ModStr := '*'
    else if Param.Ownership = owBorrow then
      ModStr := ''; // Passed by value or const pointer if record

    ParamListStr := ParamListStr + Format('%s %s%s', [EmitTypeRef(Param.TypeName), ModStr, Param.Name]);
    if I < Func.Params.Count - 1 then
      ParamListStr := ParamListStr + ', ';
  end;

  if ParamListStr = '' then ParamListStr := 'void';

  ExportPrefix := '';
  if Func.InlineMode = 'always' then
    ExportPrefix := 'static inline __attribute__((always_inline)) '
  else if Func.InlineMode = 'never' then
    ExportPrefix := '__attribute__((noinline)) ';

  if Func.IsCold then
    ExportPrefix := ExportPrefix + '__attribute__((cold)) ';

  if Func.IsExport then
    ExportPrefix := ExportPrefix + 'AETHER_EXPORT ';

  if Func.IsAsync then
    Emit(Format('%sAetherTask %s(%s) {', [ExportPrefix, Func.Name, ParamListStr]))
  else if (Func.ReturnType = 'Void') or (Func.ReturnType = '') then
    Emit(Format('%svoid %s(%s) {', [ExportPrefix, Func.Name, ParamListStr]))
  else
    Emit(Format('%s%s %s(%s) {', [ExportPrefix, EmitTypeRef(Func.ReturnType), Func.Name, ParamListStr]));
  IncIndent;

  // Pre-condition Asserts
  for I := 0 to Func.Requires.Count - 1 do
    Emit(Format('assert(%s);', [EmitExpr(TASTExpr(Func.Requires[I]))]));

  // Local Variables
  if (Func.ReturnType <> 'Void') and (Func.ReturnType <> '') and (not Func.IsAsync) then
  begin
    Emit(Format('%s result;', [EmitTypeRef(Func.ReturnType)]));
    Emit('memset(&result, 0, sizeof(result));');
  end;

  for I := 0 to Func.LocalVars.Count - 1 do
    EmitLocalVarDecl(TASTVarDecl(Func.LocalVars[I]), Func.Body);

  SkipNames := TStringList.Create;
  AutoNames := TStringList.Create;
  AutoTypes := TStringList.Create;
  try
    for I := 0 to Func.Params.Count - 1 do
      SkipNames.Add(TASTParam(Func.Params[I]).Name);
    for I := 0 to Func.LocalVars.Count - 1 do
      SkipNames.Add(TASTVarDecl(Func.LocalVars[I]).Name);
    CollectAutoForVars(Func.Body, AutoNames, AutoTypes, SkipNames);
    for I := 0 to AutoNames.Count - 1 do
      Emit(Format('%s %s;', [AutoTypes[I], AutoNames[I]]));
  finally
    SkipNames.Free;
    AutoNames.Free;
    AutoTypes.Free;
  end;

  // Body
  FActiveDefers.Clear;
  FLoopDeferBase := 0;
  FRaiiNames.Clear;
  FRaiiTypes.Clear;
  FLoopRaiiBase := 0;
  FCurrentScopeList := Func.Body;
  FTryDepth := 0;
  for I := 0 to Func.LocalVars.Count - 1 do
    RegisterRaiiVar(TASTVarDecl(Func.LocalVars[I]).Name, TASTVarDecl(Func.LocalVars[I]).TypeName, Func.Body);
  EmitStmtList(Func.Body);
  FActiveDefers.Clear;

  if (Func.Body.Count = 0) or not (Func.Body[Func.Body.Count - 1] is TASTReturnStmt) then
  begin
    for I := 0 to Func.Ensures.Count - 1 do
      Emit(Format('assert(%s);', [EmitExpr(TASTExpr(Func.Ensures[I]))]));
    if FRaiiNames.Count > 0 then
      EmitActiveRaii(0);
  end;
  FRaiiNames.Clear;
  FRaiiTypes.Clear;
  FCurrentScopeList := nil;

  if (Func.ReturnType <> 'Void') and (Func.ReturnType <> '') and (not Func.IsAsync) then
  begin
    Emit('return result;');
  end;

  DecIndent;
  Emit('}');
  Emit('');
  FCurrentFunc := nil;
end;

procedure TAetherEmitterC.EmitProgramBlock(Prog: TASTProgramBlock);
var
  I: Integer;
  VarDecl: TASTVarDecl;
  VolQual, KeyT, ValT: string;
  SkipNames, AutoNames, AutoTypes: TStringList;
begin
  FCurrentFunc := nil;
  FProgramBlock := Prog;
  Emit('int main(int argc, char* argv[]) {');
  IncIndent;
  if FNeedCliArgs then
  begin
    Emit('g_aether_argc = argc;');
    Emit('g_aether_argv = argv;');
  end
  else
  begin
    Emit('(void)argc; (void)argv;');
  end;
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
          Emit(Format('%s = %s;', [VarDecl.Name, EmitExpr(VarDecl.InitialExpr)]));
      end;
    end;
    for I := 0 to FModule.InitProcs.Count - 1 do
      Emit(Format('%s();', [FModule.InitProcs[I]]));
    if FModule.FiniProcs.Count > 0 then
    begin
      Emit('#ifndef __wasm__');
      for I := 0 to FModule.FiniProcs.Count - 1 do
        Emit(Format('atexit(%s);', [FModule.FiniProcs[I]]));
      Emit('#endif');
    end;
  end;

  for I := 0 to Prog.LocalVars.Count - 1 do
    EmitLocalVarDecl(TASTVarDecl(Prog.LocalVars[I]), Prog.Body);

  SkipNames := TStringList.Create;
  AutoNames := TStringList.Create;
  AutoTypes := TStringList.Create;
  try
    for I := 0 to Prog.LocalVars.Count - 1 do
      SkipNames.Add(TASTVarDecl(Prog.LocalVars[I]).Name);
    CollectAutoForVars(Prog.Body, AutoNames, AutoTypes, SkipNames);
    for I := 0 to AutoNames.Count - 1 do
      Emit(Format('%s %s;', [AutoTypes[I], AutoNames[I]]));
  finally
    SkipNames.Free;
    AutoNames.Free;
    AutoTypes.Free;
  end;

  FActiveDefers.Clear;
  FLoopDeferBase := 0;
  FRaiiNames.Clear;
  FRaiiTypes.Clear;
  FLoopRaiiBase := 0;
  FCurrentScopeList := Prog.Body;
  FTryDepth := 0;
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
    Emit('#ifdef __wasm__');
    for I := FModule.FiniProcs.Count - 1 downto 0 do
      Emit(Format('%s();', [FModule.FiniProcs[I]]));
    Emit('#endif');
  end;

  Emit('return 0;');
  DecIndent;
  Emit('}');
end;

function TAetherEmitterC.Generate(AModule: TASTModule): string;
var
  I, J, UsedConstCount, UsedTypeCount, UsedOptCount, UsedResCount: Integer;
  Func: TASTFunction;
  Rec: TASTRecordDecl;
  Param: TASTParam;
  ConstDecl: TASTConstDecl;
  ParamListStr, ModStr, ExportPrefix, ReachText, ProgText, MapText, FnHelperText: string;
  HasExports, KeepAll, Changed: Boolean;
  NeedSockets, NeedFileIO, NeedJson, NeedDyn, NeedRaise, NeedTime, NeedResult, NeedOption, NeedTask: Boolean;
  MapTags, MapKeys, MapVals: TStringList;
  OptTags, OptInners, ResTags, ResVals, ResErrs: TStringList;
  UOptTags, UOptInners, UResTags, UResVals, UResErrs: TStringList;
  ConstUsed, TypeUsed, FuncUsed, OptUsed, ResUsed: array of Boolean;
  ConstBodies, TypeBodies, TypeNames, FuncBodies, FuncProtos: array of string;
begin
  FModule := AModule;
  FOutput.Clear;
  FIndent := 0;
  FLoopCounter := 0;
  FNeedCliArgs := False;
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
  FFnTags.Clear;
  FFnSigs.Clear;
  FThunkFuncs.Clear;
  FLambdas.Clear;
  CollectMapsFromModule(AModule, MapTags, MapKeys, MapVals);
  CollectTypedMonadsFromModule(AModule, OptTags, OptInners, ResTags, ResVals, ResErrs);

  HasExports := False;
  for I := 0 to AModule.Functions.Count - 1 do
    if TASTFunction(AModule.Functions[I]).IsExport then
    begin
      HasExports := True;
      Break;
    end;

  KeepAll := HasExports or AModule.IsUnit;

  // 1. Pre-render declarations for reachability analysis (Tree-Shaking)
  SetLength(ConstUsed, AModule.Constants.Count);
  SetLength(ConstBodies, AModule.Constants.Count);
  for I := 0 to AModule.Constants.Count - 1 do
  begin
    ConstDecl := TASTConstDecl(AModule.Constants[I]);
    if (ConstDecl.TypeName = 'String') or (GetExprTypeName(ConstDecl.ValueExpr) = 'String') then
      ConstBodies[I] := Format('static const char* const %s = %s;', [ConstDecl.Name, EmitExpr(ConstDecl.ValueExpr)])
    else
      ConstBodies[I] := Format('static const %s %s = %s;', [EmitTypeRef(ConstDecl.TypeName), ConstDecl.Name, EmitExpr(ConstDecl.ValueExpr)]);
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
        EmitRecordDecl(Rec);
      end;
    end
    else if AModule.Types[I] is TASTEnumDecl then
    begin
      TypeNames[I] := TASTEnumDecl(AModule.Types[I]).Name;
      EmitEnumDecl(TASTEnumDecl(AModule.Types[I]));
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
  SetLength(FuncProtos, AModule.Functions.Count);
  for I := 0 to AModule.Functions.Count - 1 do
  begin
    Func := TASTFunction(AModule.Functions[I]);
    FuncProtos[I] := '';
    if not (SameText(Func.Name, 'Abs') or SameText(Func.Name, 'Min') or SameText(Func.Name, 'Max') or SameText(Func.Name, 'Clamp')) and
       (not Func.IsExtern) and (Func.GenericParams.Count = 0) and (Func.GenericParam = '') then
    begin
      ParamListStr := '';
      for J := 0 to Func.Params.Count - 1 do
      begin
        Param := TASTParam(Func.Params[J]);
        ModStr := '';
        if Param.Ownership = owMutBorrow then ModStr := '*';
        ParamListStr := ParamListStr + Format('%s %s%s', [EmitTypeRef(Param.TypeName), ModStr, Param.Name]);
        if J < Func.Params.Count - 1 then ParamListStr := ParamListStr + ', ';
      end;
      ExportPrefix := '';
      if Func.InlineMode = 'always' then ExportPrefix := 'static inline __attribute__((always_inline)) '
      else if Func.InlineMode = 'never' then ExportPrefix := '__attribute__((noinline)) ';
      if Func.IsCold then ExportPrefix := ExportPrefix + '__attribute__((cold)) ';
      if Func.IsExport then ExportPrefix := ExportPrefix + 'AETHER_EXPORT ';
      if Func.IsAsync then
        FuncProtos[I] := Format('%sAetherTask %s(%s);', [ExportPrefix, Func.Name, ParamListStr])
      else if (Func.ReturnType = 'Void') or (Func.ReturnType = '') then
        FuncProtos[I] := Format('%svoid %s(%s);', [ExportPrefix, Func.Name, ParamListStr])
      else
        FuncProtos[I] := Format('%s%s %s(%s);', [ExportPrefix, EmitTypeRef(Func.ReturnType), Func.Name, ParamListStr]);
    end;
    FOutput.Clear;
    FIndent := 0;
    EmitFunction(Func);
    FuncBodies[I] := FOutput.Text;
    FuncUsed[I] := KeepAll or (Func.SourceModule = '') or Func.IsExport;
  end;

  FOutput.Clear;
  FIndent := 0;
  EmitMapRuntimeDecls(MapTags, MapKeys, MapVals, False);
  EmitMapRuntimeHelpers(MapTags, MapKeys, MapVals);
  MapText := FOutput.Text;

  FOutput.Clear;
  FIndent := 0;
  EmitFnRuntimeHelpers;
  EmitLambdaAndThunkDecls(False);
  FnHelperText := FOutput.Text;

  FOutput.Clear;
  FIndent := 0;
  if Assigned(AModule.ProgramBlock) then
    EmitProgramBlock(AModule.ProgramBlock)
  else
  begin
    if AModule.ModuleVars.Count > 0 then
    begin
      for I := 0 to AModule.ModuleVars.Count - 1 do
        if Assigned(TASTVarDecl(AModule.ModuleVars[I]).InitialExpr) then
          Emit(EmitExpr(TASTVarDecl(AModule.ModuleVars[I]).InitialExpr) + ';');
    end;
    if AModule.InitBody.Count > 0 then
      EmitStmtList(AModule.InitBody);
    if AModule.FiniBody.Count > 0 then
      EmitStmtList(AModule.FiniBody);
  end;
  ProgText := FOutput.Text;

  ReachText := ProgText + #10 + MapText + #10 + FnHelperText;
  for I := 0 to AModule.Constants.Count - 1 do
    if ConstUsed[I] then ReachText := ReachText + #10 + ConstBodies[I];
  for I := 0 to AModule.ModuleVars.Count - 1 do
    ReachText := ReachText + #10 + EmitTypeRef(TASTVarDecl(AModule.ModuleVars[I]).TypeName) + ' ' + TASTVarDecl(AModule.ModuleVars[I]).Name;
  for I := 0 to AModule.Types.Count - 1 do
    if (TypeBodies[I] <> '') and TypeUsed[I] then ReachText := ReachText + #10 + TypeBodies[I];
  for I := 0 to AModule.Functions.Count - 1 do
    if FuncUsed[I] then ReachText := ReachText + #10 + FuncProtos[I] + #10 + FuncBodies[I];

  SetLength(OptUsed, OptTags.Count);
  for I := 0 to OptTags.Count - 1 do
    OptUsed[I] := KeepAll or (Pos('AetherOpt_' + OptTags[I], ReachText) > 0) or
      (Pos('AetherSome_' + OptTags[I], ReachText) > 0) or (Pos('AetherNone_' + OptTags[I], ReachText) > 0);

  SetLength(ResUsed, ResTags.Count);
  for I := 0 to ResTags.Count - 1 do
    ResUsed[I] := KeepAll or (Pos('AetherRes_' + ResTags[I], ReachText) > 0) or
      (Pos('AetherOk_' + ResTags[I], ReachText) > 0) or (Pos('AetherErr_' + ResTags[I], ReachText) > 0);

  if not KeepAll then
  begin
    repeat
      Changed := False;
      for I := 0 to AModule.Functions.Count - 1 do
      begin
        Func := TASTFunction(AModule.Functions[I]);
        if (not FuncUsed[I]) and ((FuncBodies[I] <> '') or (FuncProtos[I] <> '')) and
           (Pos(Func.Name, ReachText) > 0) then
        begin
          FuncUsed[I] := True;
          ReachText := ReachText + #10 + FuncProtos[I] + #10 + FuncBodies[I];
          Changed := True;
        end;
      end;
      for I := 0 to OptTags.Count - 1 do
      begin
        if (not OptUsed[I]) and ((Pos('AetherOpt_' + OptTags[I], ReachText) > 0) or
           (Pos('AetherSome_' + OptTags[I], ReachText) > 0) or (Pos('AetherNone_' + OptTags[I], ReachText) > 0)) then
        begin
          OptUsed[I] := True;
          ReachText := ReachText + #10 + EmitTypeRef(OptInners[I]);
          Changed := True;
        end;
      end;
      for I := 0 to ResTags.Count - 1 do
      begin
        if (not ResUsed[I]) and ((Pos('AetherRes_' + ResTags[I], ReachText) > 0) or
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

  NeedSockets := (Pos('AetherSocket', ReachText) > 0);
  NeedFileIO := (Pos('AetherFileExists', ReachText) > 0) or (Pos('AetherReadFile', ReachText) > 0) or
                (Pos('AetherWriteFile', ReachText) > 0) or (Pos('AetherCreateDir', ReachText) > 0) or
                (Pos('AetherRemoveDir', ReachText) > 0) or (Pos('AetherDeleteFile', ReachText) > 0) or
                (Pos('AetherDirExists', ReachText) > 0) or (Pos('AetherFileSize', ReachText) > 0) or
                (Pos('AetherListDir', ReachText) > 0) or (Pos('AetherCopyFile', ReachText) > 0) or
                (Pos('AetherRenameFile', ReachText) > 0);
  NeedJson := (Pos('AetherJson', ReachText) > 0);
  NeedDyn := (Pos('AetherDyn', ReachText) > 0) or (Pos('AetherStrSplit', ReachText) > 0) or
             (Pos('AetherStrJoin', ReachText) > 0) or (Pos('AetherListDir', ReachText) > 0);
  NeedRaise := (Pos('AetherRaise', ReachText) > 0) or (Pos('g_aether_jmp_', ReachText) > 0);
  NeedTime := (Pos('AetherGetNanoseconds', ReachText) > 0) or (Pos('AetherSleepMs', ReachText) > 0) or
              (Pos('AetherPascalNow', ReachText) > 0) or (Pos('AetherPascalGetTickCount64', ReachText) > 0) or
              (Pos('AetherRandomInt', ReachText) > 0) or (Pos('AetherRandomFloat', ReachText) > 0);
  NeedResult := (Pos('AetherResult', ReachText) > 0);
  NeedOption := (Pos('AetherOption', ReachText) > 0) or (Pos('AetherTryStrToInt', ReachText) > 0) or
                (Pos('AetherTryStrToFloat', ReachText) > 0);
  NeedTask := (Pos('AetherTask', ReachText) > 0);
  FNeedCliArgs := (Pos('AetherParamCount', ReachText) > 0) or (Pos('AetherParamStr', ReachText) > 0);

  FOutput.Clear;
  FIndent := 0;
  FLoopCounter := 0;

  Emit('// Code automatically generated by the Aether Compiler (aetherc)');
  Emit('// Target: C99 / GCC (MSYS2)');
  Emit('#if defined(__wasm__)');
  Emit('// WebAssembly Standalone Environment');
  Emit('typedef unsigned long size_t;');
  Emit('typedef signed char int8_t;');
  Emit('typedef unsigned char uint8_t;');
  Emit('typedef signed short int16_t;');
  Emit('typedef unsigned short uint16_t;');
  Emit('typedef signed int int32_t;');
  Emit('typedef unsigned int uint32_t;');
  Emit('typedef signed long long int64_t;');
  Emit('typedef unsigned long long uint64_t;');
  Emit('#define NULL ((void*)0)');
  Emit('#define true 1');
  Emit('#define false 0');
  Emit('typedef _Bool bool;');
  Emit('static unsigned char __wasm_heap[65536];');
  Emit('static unsigned long __wasm_heap_ptr = 0;');
  Emit('static inline void* malloc(size_t sz) {');
  Emit('    void* p = (void*)&__wasm_heap[__wasm_heap_ptr];');
  Emit('    __wasm_heap_ptr += (sz + 7) & ~7;');
  Emit('    return p;');
  Emit('}');
  Emit('static inline void free(void* p) { (void)p; }');
  Emit('static inline size_t strlen(const char* s) {');
  Emit('    size_t l = 0; if (!s) return 0; while (s[l]) l++; return l;');
  Emit('}');
  Emit('static inline void* memcpy(void* dst, const void* src, size_t n) {');
  Emit('    char* d = (char*)dst; const char* s = (const char*)src;');
  Emit('    for (size_t i = 0; i < n; i++) d[i] = s[i]; return dst;');
  Emit('}');
  Emit('static inline int printf(const char* fmt, ...) { (void)fmt; return 0; }');
  Emit('int puts(const char* s) { (void)s; return 0; }');
  Emit('#define assert(x) ((void)0)');
  Emit('#else');
  Emit('#include <stdio.h>');
  Emit('#include <stdlib.h>');
  Emit('#include <stdint.h>');
  Emit('#include <stdbool.h>');
  Emit('#include <string.h>');
  Emit('#include <assert.h>');
  Emit('#include <math.h>');
  if NeedTime then Emit('#include <time.h>');
  if NeedFileIO then Emit('#include <sys/stat.h>');
  if NeedRaise then Emit('#include <setjmp.h>');
  if NeedSockets or NeedFileIO or NeedTime then
  begin
    Emit('#ifdef _WIN32');
    Emit('#define WIN32_LEAN_AND_MEAN');
    Emit('#define NOGDI');
    if NeedSockets then
    begin
      Emit('#include <winsock2.h>');
      Emit('#include <ws2tcpip.h>');
    end;
    Emit('#include <windows.h>');
    if NeedFileIO then
    begin
      Emit('#include <direct.h>');
      Emit('#include <io.h>');
    end;
    Emit('#undef Rectangle');
    if NeedSockets then Emit('typedef int socklen_t;');
    Emit('#else');
    if NeedSockets then
    begin
      Emit('#include <sys/socket.h>');
      Emit('#include <netinet/in.h>');
      Emit('#include <arpa/inet.h>');
    end;
    if NeedFileIO then
      Emit('#include <dirent.h>');
    Emit('#include <unistd.h>');
    Emit('#endif');
  end;
  Emit('#endif');
  Emit('');

  if NeedTask then
  begin
    Emit('// Concurrency and Async Task Runtime (AetherTask)');
    Emit('typedef struct {');
    Emit('    bool is_completed;');
    Emit('    int64_t int_val;');
    Emit('    double float_val;');
    Emit('    const char* str_val;');
    Emit('    void* ptr_val;');
    Emit('} AetherTask;');
    Emit('');
  end;

  if HasExports or (Pos('AETHER_EXPORT', ReachText) > 0) then
  begin
    Emit('#if defined(_WIN32) || defined(__CYGWIN__)');
    Emit('  #define AETHER_EXPORT __declspec(dllexport)');
    Emit('#else');
    Emit('  #define AETHER_EXPORT __attribute__((visibility("default")))');
    Emit('#endif');
    Emit('');
  end;

  // Additional C headers (import c)
  if Assigned(AModule.CImports) then
  begin
    for I := 0 to AModule.CImports.Count - 1 do
    begin
      if (Pos('<', AModule.CImports[I]) = 1) or (Pos('"', AModule.CImports[I]) = 1) then
        Emit('#include ' + AModule.CImports[I])
      else
        Emit('#include "' + AModule.CImports[I] + '"');
    end;
    if AModule.CImports.Count > 0 then
      Emit('');
  end;

  // Pascal compatibility helpers in the C backend (on demand)
  if Pos('AetherPascalNow', ReachText) > 0 then
  begin
    Emit('static inline double AetherPascalNow(void) {');
    Emit('#if defined(__wasm__)');
    Emit('    return 0.0;');
    Emit('#else');
    Emit('    return (double)time(NULL);');
    Emit('#endif');
    Emit('}');
    Emit('');
  end;
  if Pos('AetherPascalGetTickCount64', ReachText) > 0 then
  begin
    Emit('static inline uint64_t AetherPascalGetTickCount64(void) {');
    Emit('#if defined(__wasm__)');
    Emit('    return 0;');
    Emit('#elif defined(_WIN32)');
    Emit('    return (uint64_t)GetTickCount64();');
    Emit('#else');
    Emit('    struct timespec ts;');
    Emit('    clock_gettime(CLOCK_MONOTONIC, &ts);');
    Emit('    return (uint64_t)(ts.tv_sec * 1000 + ts.tv_nsec / 1000000);');
    Emit('#endif');
    Emit('}');
    Emit('');
  end;

  // Aether Runtime Helpers (on demand)
  if Pos('AetherStringConcat', ReachText) > 0 then
  begin
    Emit('static inline char* AetherStringConcat(const char* a, const char* b) {');
    Emit('    size_t la = a ? strlen(a) : 0;');
    Emit('    size_t lb = b ? strlen(b) : 0;');
    Emit('    char* res = (char*)malloc(la + lb + 1);');
    Emit('    if (la) memcpy(res, a, la);');
    Emit('    if (lb) memcpy(res + la, b, lb);');
    Emit('    res[la + lb] = ''\0'';');
    Emit('    return res;');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherCharAt', ReachText) > 0 then
  begin
    Emit('static inline char* AetherCharAt(const char* s, uint32_t index) {');
    Emit('    uint32_t slen = s ? (uint32_t)strlen(s) : 0;');
    Emit('    char* res = (char*)malloc(2);');
    Emit('    if (index < slen) { res[0] = s[index]; res[1] = ''\0''; }');
    Emit('    else { res[0] = ''\0''; }');
    Emit('    return res;');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherSubstring', ReachText) > 0 then
  begin
    Emit('static inline char* AetherSubstring(const char* s, uint32_t start, uint32_t len) {');
    Emit('    uint32_t slen = s ? (uint32_t)strlen(s) : 0;');
    Emit('    if (start >= slen) {');
    Emit('        char* empty = (char*)malloc(1);');
    Emit('        empty[0] = ''\0'';');
    Emit('        return empty;');
    Emit('    }');
    Emit('    if (start + len > slen) len = slen - start;');
    Emit('    char* res = (char*)malloc(len + 1);');
    Emit('    memcpy(res, s + start, len);');
    Emit('    res[len] = ''\0'';');
    Emit('    return res;');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherStrTrim', ReachText) > 0 then
  begin
    Emit('static inline char* AetherStrTrim(const char* s) {');
    Emit('    if (!s) { char* e = (char*)malloc(1); e[0] = ''\0''; return e; }');
    Emit('    size_t start = 0; size_t len = strlen(s);');
    Emit('    while (start < len && (s[start] == '' '' || s[start] == ''\t'' || s[start] == ''\n'' || s[start] == ''\r'')) start++;');
    Emit('    while (len > start && (s[len - 1] == '' '' || s[len - 1] == ''\t'' || s[len - 1] == ''\n'' || s[len - 1] == ''\r'')) len--;');
    Emit('    size_t out_len = len - start;');
    Emit('    char* res = (char*)malloc(out_len + 1);');
    Emit('    if (out_len > 0) memcpy(res, s + start, out_len);');
    Emit('    res[out_len] = ''\0'';');
    Emit('    return res;');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherUpperCase', ReachText) > 0 then
  begin
    Emit('static inline char* AetherUpperCase(const char* s) {');
    Emit('    if (!s) { char* e = (char*)malloc(1); e[0] = ''\0''; return e; }');
    Emit('    size_t len = strlen(s);');
    Emit('    char* res = (char*)malloc(len + 1);');
    Emit('    for (size_t i = 0; i < len; i++) {');
    Emit('        char c = s[i];');
    Emit('        res[i] = (c >= ''a'' && c <= ''z'') ? (char)(c - 32) : c;');
    Emit('    }');
    Emit('    res[len] = ''\0'';');
    Emit('    return res;');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherLowerCase', ReachText) > 0 then
  begin
    Emit('static inline char* AetherLowerCase(const char* s) {');
    Emit('    if (!s) { char* e = (char*)malloc(1); e[0] = ''\0''; return e; }');
    Emit('    size_t len = strlen(s);');
    Emit('    char* res = (char*)malloc(len + 1);');
    Emit('    for (size_t i = 0; i < len; i++) {');
    Emit('        char c = s[i];');
    Emit('        res[i] = (c >= ''A'' && c <= ''Z'') ? (char)(c + 32) : c;');
    Emit('    }');
    Emit('    res[len] = ''\0'';');
    Emit('    return res;');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherStartsWith', ReachText) > 0 then
  begin
    Emit('static inline bool AetherStartsWith(const char* s, const char* prefix) {');
    Emit('    if (!s || !prefix) return false;');
    Emit('    size_t sl = strlen(s), pl = strlen(prefix);');
    Emit('    if (pl > sl) return false;');
    Emit('    for (size_t i = 0; i < pl; i++) if (s[i] != prefix[i]) return false;');
    Emit('    return true;');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherEndsWith', ReachText) > 0 then
  begin
    Emit('static inline bool AetherEndsWith(const char* s, const char* suffix) {');
    Emit('    if (!s || !suffix) return false;');
    Emit('    size_t sl = strlen(s), sufl = strlen(suffix);');
    Emit('    if (sufl > sl) return false;');
    Emit('    for (size_t i = 0; i < sufl; i++) if (s[sl - sufl + i] != suffix[i]) return false;');
    Emit('    return true;');
    Emit('}');
    Emit('');
  end;

  if (Pos('AetherStrIndexOf', ReachText) > 0) or (Pos('AetherStrContains', ReachText) > 0) then
  begin
    Emit('static inline int32_t AetherStrIndexOf(const char* s, const char* sub) {');
    Emit('    if (!s || !sub) return -1;');
    Emit('    size_t sl = strlen(s), subl = strlen(sub);');
    Emit('    if (subl == 0) return 0;');
    Emit('    if (subl > sl) return -1;');
    Emit('    for (size_t i = 0; i <= sl - subl; i++) {');
    Emit('        bool ok = true;');
    Emit('        for (size_t j = 0; j < subl; j++) {');
    Emit('            if (s[i + j] != sub[j]) { ok = false; break; }');
    Emit('        }');
    Emit('        if (ok) return (int32_t)i;');
    Emit('    }');
    Emit('    return -1;');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherStrContains', ReachText) > 0 then
  begin
    Emit('static inline bool AetherStrContains(const char* s, const char* sub) {');
    Emit('    return AetherStrIndexOf(s, sub) >= 0;');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherStrReplace', ReachText) > 0 then
  begin
    Emit('static inline char* AetherStrReplace(const char* s, const char* old_s, const char* new_s) {');
    Emit('    if (!s) { char* e = (char*)malloc(1); e[0] = ''\0''; return e; }');
    Emit('    size_t sl = strlen(s);');
    Emit('    if (!old_s || old_s[0] == ''\0'') {');
    Emit('        char* cp = (char*)malloc(sl + 1); memcpy(cp, s, sl + 1); return cp;');
    Emit('    }');
    Emit('    const char* rep = new_s ? new_s : "";');
    Emit('    size_t oldl = strlen(old_s), repl = strlen(rep), count = 0;');
    Emit('    for (size_t i = 0; i + oldl <= sl; ) {');
    Emit('        bool m = true;');
    Emit('        for (size_t j = 0; j < oldl; j++) if (s[i + j] != old_s[j]) { m = false; break; }');
    Emit('        if (m) { count++; i += oldl; } else i++;');
    Emit('    }');
    Emit('    size_t out_len = sl + count * repl - count * oldl;');
    Emit('    char* res = (char*)malloc(out_len + 1);');
    Emit('    size_t pos = 0;');
    Emit('    for (size_t i = 0; i < sl; ) {');
    Emit('        bool m = (i + oldl <= sl);');
    Emit('        if (m) for (size_t j = 0; j < oldl; j++) if (s[i + j] != old_s[j]) { m = false; break; }');
    Emit('        if (m) { if (repl > 0) { memcpy(res + pos, rep, repl); pos += repl; } i += oldl; }');
    Emit('        else { res[pos++] = s[i++]; }');
    Emit('    }');
    Emit('    res[pos] = ''\0'';');
    Emit('    return res;');
    Emit('}');
    Emit('');
  end;

  if NeedFileIO then
  begin
    Emit('#if defined(__wasm__)');
    Emit('static inline bool AetherFileExists(const char* path) { (void)path; return false; }');
    Emit('static inline char* AetherReadFile(const char* path) { (void)path; char* empty = (char*)malloc(1); if (empty) empty[0] = ''\0''; return empty; }');
    Emit('static inline bool AetherWriteFile(const char* path, const char* content) { (void)path; (void)content; return false; }');
    Emit('static inline bool AetherCreateDir(const char* path) { (void)path; return false; }');
    Emit('static inline bool AetherRemoveDir(const char* path) { (void)path; return false; }');
    Emit('static inline bool AetherDeleteFile(const char* path) { (void)path; return false; }');
    Emit('static inline bool AetherDirExists(const char* path) { (void)path; return false; }');
    Emit('static inline int64_t AetherFileSize(const char* path) { (void)path; return -1; }');
    Emit('#else');
    Emit('static inline bool AetherFileExists(const char* path) {');
    Emit('    FILE* f = fopen(path, "rb");');
    Emit('    if (f) { fclose(f); return true; }');
    Emit('    return false;');
    Emit('}');
    Emit('');
    Emit('static inline char* AetherReadFile(const char* path) {');
    Emit('    FILE* f = fopen(path, "rb");');
    Emit('    if (!f) { char* empty = (char*)malloc(1); empty[0] = ''\0''; return empty; }');
    Emit('    fseek(f, 0, SEEK_END);');
    Emit('    long sz = ftell(f);');
    Emit('    fseek(f, 0, SEEK_SET);');
    Emit('    char* buf = (char*)malloc(sz + 1);');
    Emit('    size_t read_bytes = fread(buf, 1, sz, f);');
    Emit('    buf[read_bytes] = ''\0'';');
    Emit('    fclose(f);');
    Emit('    return buf;');
    Emit('}');
    Emit('');
    Emit('static inline bool AetherWriteFile(const char* path, const char* content) {');
    Emit('    FILE* f = fopen(path, "wb");');
    Emit('    if (!f) return false;');
    Emit('    if (content) fputs(content, f);');
    Emit('    fclose(f);');
    Emit('    return true;');
    Emit('}');
    Emit('');
    Emit('static inline bool AetherCreateDir(const char* path) {');
    Emit('#ifdef _WIN32');
    Emit('    return _mkdir(path) == 0;');
    Emit('#else');
    Emit('    return mkdir(path, 0755) == 0;');
    Emit('#endif');
    Emit('}');
    Emit('');
    Emit('static inline bool AetherRemoveDir(const char* path) {');
    Emit('#ifdef _WIN32');
    Emit('    return _rmdir(path) == 0;');
    Emit('#else');
    Emit('    return rmdir(path) == 0;');
    Emit('#endif');
    Emit('}');
    Emit('');
    Emit('static inline bool AetherDeleteFile(const char* path) {');
    Emit('    return remove(path) == 0;');
    Emit('}');
    Emit('');
    Emit('static inline bool AetherDirExists(const char* path) {');
    Emit('#ifdef _WIN32');
    Emit('    DWORD attr = GetFileAttributesA(path);');
    Emit('    return (attr != INVALID_FILE_ATTRIBUTES) && ((attr & FILE_ATTRIBUTE_DIRECTORY) != 0);');
    Emit('#else');
    Emit('    struct stat st;');
    Emit('    if (stat(path, &st) == 0 && S_ISDIR(st.st_mode)) return true;');
    Emit('    return false;');
    Emit('#endif');
    Emit('}');
    Emit('');
    Emit('static inline int64_t AetherFileSize(const char* path) {');
    Emit('#ifdef _WIN32');
    Emit('    struct _stat64 st;');
    Emit('    if (_stat64(path, &st) == 0) return (int64_t)st.st_size;');
    Emit('    return -1;');
    Emit('#else');
    Emit('    struct stat st;');
    Emit('    if (stat(path, &st) == 0) return (int64_t)st.st_size;');
    Emit('    return -1;');
    Emit('#endif');
    Emit('}');
    Emit('#endif');
    Emit('');
  end;

  if Pos('AetherGetNanoseconds', ReachText) > 0 then
  begin
    Emit('static inline uint64_t AetherGetNanoseconds(void) {');
    Emit('#if defined(__wasm__)');
    Emit('    return 0;');
    Emit('#elif defined(_WIN32)');
    Emit('    LARGE_INTEGER freq, count;');
    Emit('    QueryPerformanceFrequency(&freq);');
    Emit('    QueryPerformanceCounter(&count);');
    Emit('    if (freq.QuadPart > 0) {');
    Emit('        return (uint64_t)((count.QuadPart * 1000000000ULL) / freq.QuadPart);');
    Emit('    }');
    Emit('    return (uint64_t)GetTickCount64() * 1000000ULL;');
    Emit('#else');
    Emit('    struct timespec ts;');
    Emit('    clock_gettime(CLOCK_MONOTONIC, &ts);');
    Emit('    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;');
    Emit('#endif');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherSleepMs', ReachText) > 0 then
  begin
    Emit('static inline void AetherSleepMs(uint32_t ms) {');
    Emit('#if defined(__wasm__)');
    Emit('    (void)ms;');
    Emit('#elif defined(_WIN32)');
    Emit('    Sleep(ms);');
    Emit('#else');
    Emit('    usleep((useconds_t)ms * 1000);');
    Emit('#endif');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherIntToStr', ReachText) > 0 then
  begin
    Emit('static inline char* AetherIntToStr(int64_t val) {');
    Emit('#if defined(__wasm__)');
    Emit('    char* buf = (char*)malloc(32);');
    Emit('    if (!buf) return (char*)"";');
    Emit('    int idx = 0;');
    Emit('    uint64_t uval;');
    Emit('    if (val < 0) { buf[idx++] = ''-''; uval = (uint64_t)(-val); } else uval = (uint64_t)val;');
    Emit('    char tmp[32]; int t = 0;');
    Emit('    do { tmp[t++] = ''0'' + (uval % 10); uval /= 10; } while (uval > 0);');
    Emit('    while (t > 0) buf[idx++] = tmp[--t];');
    Emit('    buf[idx] = ''\0'';');
    Emit('    return buf;');
    Emit('#else');
    Emit('    char* buf = (char*)malloc(32);');
    Emit('    snprintf(buf, 32, "%lld", (long long)val);');
    Emit('    return buf;');
    Emit('#endif');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherCharToStr', ReachText) > 0 then
  begin
    Emit('static inline char* AetherCharToStr(char c) {');
    Emit('    char* buf = (char*)malloc(2);');
    Emit('    buf[0] = c; buf[1] = ''\0'';');
    Emit('    return buf;');
    Emit('}');
    Emit('');
  end;

  if NeedDyn then
  begin
    Emit('typedef struct {');
    Emit('    size_t len;');
    Emit('    size_t cap;');
    Emit('} AetherDynHeader;');
    Emit('');
    Emit('static inline size_t AetherDynLen(const void* arr) {');
    Emit('    if (!arr) return 0;');
    Emit('    return ((const AetherDynHeader*)arr - 1)->len;');
    Emit('}');
    Emit('');
    Emit('static inline void* AetherDynSetLength(void* arr, size_t elem_size, size_t new_len) {');
    Emit('    AetherDynHeader* hdr = arr ? ((AetherDynHeader*)arr - 1) : NULL;');
    Emit('    size_t old_cap = hdr ? hdr->cap : 0;');
    Emit('    size_t old_len = hdr ? hdr->len : 0;');
    Emit('    if (new_len > old_cap || !hdr) {');
    Emit('        size_t new_cap = old_cap == 0 ? 8 : old_cap;');
    Emit('        while (new_cap < new_len) new_cap *= 2;');
    Emit('        AetherDynHeader* new_hdr = (AetherDynHeader*)realloc(hdr, sizeof(AetherDynHeader) + new_cap * elem_size);');
    Emit('        new_hdr->cap = new_cap;');
    Emit('        hdr = new_hdr;');
    Emit('    }');
    Emit('    if (new_len > old_len) {');
    Emit('        memset((char*)(hdr + 1) + old_len * elem_size, 0, (new_len - old_len) * elem_size);');
    Emit('    }');
    Emit('    hdr->len = new_len;');
    Emit('    return (void*)(hdr + 1);');
    Emit('}');
    Emit('');
    Emit('static inline void AetherDynFree(void* arr) {');
    Emit('    if (!arr) return;');
    Emit('    free((AetherDynHeader*)arr - 1);');
    Emit('}');
    Emit('');
    if Pos('AetherDynDelete', ReachText) > 0 then
    begin
      Emit('static inline void* AetherDynDelete(void* arr, size_t elem_size, int64_t idx) {');
      Emit('    size_t n = AetherDynLen(arr);');
      Emit('    if (!arr || idx < 0 || (size_t)idx >= n) return arr;');
      Emit('    char* p = (char*)arr;');
      Emit('    size_t tail = (n - 1 - (size_t)idx) * elem_size;');
      Emit('    char* dst = p + (size_t)idx * elem_size;');
      Emit('    char* src = dst + elem_size;');
      Emit('    for (size_t i = 0; i < tail; i++) dst[i] = src[i];');
      Emit('    return AetherDynSetLength(arr, elem_size, n - 1);');
      Emit('}');
      Emit('');
    end;
    if Pos('AetherDynSlice', ReachText) > 0 then
    begin
      Emit('static inline void* AetherDynSlice(const void* arr, size_t elem_size, int64_t start, int64_t count) {');
      Emit('    size_t n = AetherDynLen(arr);');
      Emit('    if (!arr || count <= 0 || start >= (int64_t)n) {');
      Emit('        return AetherDynSetLength(NULL, elem_size, 0);');
      Emit('    }');
      Emit('    if (start < 0) { count += start; start = 0; }');
      Emit('    if (count <= 0) return AetherDynSetLength(NULL, elem_size, 0);');
      Emit('    size_t actual = (size_t)count;');
      Emit('    if ((size_t)start + actual > n) actual = n - (size_t)start;');
      Emit('    void* res = AetherDynSetLength(NULL, elem_size, actual);');
      Emit('    memcpy(res, (const char*)arr + (size_t)start * elem_size, actual * elem_size);');
      Emit('    return res;');
      Emit('}');
      Emit('');
    end;
  end;

  if NeedRaise then
  begin
    Emit('#if defined(__wasm__)');
    Emit('static inline void AetherRaise(const char* msg) { (void)msg; }');
    Emit('#else');
    Emit('static jmp_buf g_aether_jmp_stack[32];');
    Emit('static int g_aether_jmp_top = 0;');
    Emit('static const char* g_aether_last_exception = "";');
    Emit('static __attribute__((noinline, noreturn)) void AetherRaise(const char* msg) {');
    Emit('    g_aether_last_exception = msg ? msg : "Exception";');
    Emit('    if (g_aether_jmp_top > 0) {');
    Emit('        longjmp(g_aether_jmp_stack[--g_aether_jmp_top], 1);');
    Emit('    } else {');
    Emit('        fprintf(stderr, "Unhandled Exception: %s\n", g_aether_last_exception);');
    Emit('        exit(1);');
    Emit('    }');
    Emit('}');
    Emit('#endif');
    Emit('');
  end;

  if Pos('AetherFloatToStr', ReachText) > 0 then
  begin
    Emit('static inline char* AetherFloatToStr(double val) {');
    Emit('    char* buf = (char*)malloc(32);');
    Emit('    snprintf(buf, 32, "%g", val);');
    Emit('    return buf;');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherBoolToStr', ReachText) > 0 then
  begin
    Emit('static inline char* AetherBoolToStr(bool val) {');
    Emit('    return val ? (char*)"true" : (char*)"false";');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherStrToInt', ReachText) > 0 then
  begin
    Emit('static inline int32_t AetherStrToInt(const char* s) {');
    Emit('#if defined(__wasm__)');
    Emit('    if (!s) return 0;');
    Emit('    int32_t res = 0; int sign = 1; size_t i = 0;');
    Emit('    if (s[0] == ''-'') { sign = -1; i = 1; }');
    Emit('    for (; s[i] >= ''0'' && s[i] <= ''9''; i++) { res = res * 10 + (s[i] - ''0''); }');
    Emit('    return res * sign;');
    Emit('#else');
    Emit('    if (!s) return 0;');
    Emit('    return (int32_t)atoi(s);');
    Emit('#endif');
    Emit('}');
    Emit('');
  end;

  if NeedJson then
  begin
    Emit('static inline char* AetherJsonExtractRaw(const char* json, const char* key) {');
    Emit('    if (!json || !key) { char* e = (char*)malloc(1); e[0] = ''\0''; return e; }');
    Emit('    size_t klen = strlen(key);');
    Emit('    size_t jlen = strlen(json);');
    Emit('    for (size_t i = 0; i + klen + 2 <= jlen; i++) {');
    Emit('        if (json[i] == ''"'' && strncmp(json + i + 1, key, klen) == 0 && json[i + 1 + klen] == ''"'') {');
    Emit('            size_t p = i + 2 + klen;');
    Emit('            while (p < jlen && (json[p] == '' '' || json[p] == ''\t'' || json[p] == ''\n'' || json[p] == ''\r'')) p++;');
    Emit('            if (p < jlen && json[p] == '':'') {');
    Emit('                p++;');
    Emit('                while (p < jlen && (json[p] == '' '' || json[p] == ''\t'' || json[p] == ''\n'' || json[p] == ''\r'')) p++;');
    Emit('                size_t start = p;');
    Emit('                if (p < jlen && json[p] == ''"'') {');
    Emit('                    p++;');
    Emit('                    while (p < jlen) {');
    Emit('                        if (json[p] == ''"'' && json[p - 1] != ''\\'') { p++; break; }');
    Emit('                        p++;');
    Emit('                    }');
    Emit('                } else if (p < jlen && json[p] == ''{'') {');
    Emit('                    int depth = 0;');
    Emit('                    bool in_str = false;');
    Emit('                    while (p < jlen) {');
    Emit('                        if (json[p] == ''"'' && (p == 0 || json[p - 1] != ''\\'')) in_str = !in_str;');
    Emit('                        else if (!in_str) {');
    Emit('                            if (json[p] == ''{'') depth++;');
    Emit('                            else if (json[p] == ''}'') { depth--; if (depth == 0) { p++; break; } }');
    Emit('                        }');
    Emit('                        p++;');
    Emit('                    }');
    Emit('                } else {');
    Emit('                    while (p < jlen && json[p] != '','' && json[p] != ''}'' && json[p] != '']'' &&');
    Emit('                           json[p] != '' '' && json[p] != ''\t'' && json[p] != ''\n'' && json[p] != ''\r'') p++;');
    Emit('                }');
    Emit('                size_t rlen = p - start;');
    Emit('                char* res = (char*)malloc(rlen + 1);');
    Emit('                if (rlen > 0) memcpy(res, json + start, rlen);');
    Emit('                res[rlen] = ''\0'';');
    Emit('                return res;');
    Emit('            }');
    Emit('        }');
    Emit('    }');
    Emit('    char* empty = (char*)malloc(1);');
    Emit('    empty[0] = ''\0'';');
    Emit('    return empty;');
    Emit('}');
    Emit('');
    Emit('static inline char* AetherJsonGetStr(const char* json, const char* key) {');
    Emit('    char* raw = AetherJsonExtractRaw(json, key);');
    Emit('    size_t len = strlen(raw);');
    Emit('    if (len >= 2 && raw[0] == ''"'' && raw[len - 1] == ''"'') {');
    Emit('        memmove(raw, raw + 1, len - 2);');
    Emit('        raw[len - 2] = ''\0'';');
    Emit('    }');
    Emit('    return raw;');
    Emit('}');
    Emit('');
    Emit('static inline int32_t AetherJsonGetInt(const char* json, const char* key) {');
    Emit('    char* raw = AetherJsonExtractRaw(json, key);');
    Emit('    int32_t val = raw[0] ? (int32_t)strtoll(raw, NULL, 10) : 0;');
    Emit('    free(raw);');
    Emit('    return val;');
    Emit('}');
    Emit('');
    Emit('static inline double AetherJsonGetFloat(const char* json, const char* key) {');
    Emit('    char* raw = AetherJsonExtractRaw(json, key);');
    Emit('    double val = raw[0] ? strtod(raw, NULL) : 0.0;');
    Emit('    free(raw);');
    Emit('    return val;');
    Emit('}');
    Emit('');
    Emit('static inline bool AetherJsonGetBool(const char* json, const char* key) {');
    Emit('    char* raw = AetherJsonExtractRaw(json, key);');
    Emit('    bool val = (strcmp(raw, "true") == 0);');
    Emit('    free(raw);');
    Emit('    return val;');
    Emit('}');
    Emit('');
    Emit('static inline char AetherJsonGetChar(const char* json, const char* key) {');
    Emit('    char* raw = AetherJsonGetStr(json, key);');
    Emit('    char c = raw[0];');
    Emit('    free(raw);');
    Emit('    return c;');
    Emit('}');
    Emit('');
    Emit('static inline bool AetherJsonHasValue(const char* json, const char* key) {');
    Emit('    char* raw = AetherJsonExtractRaw(json, key);');
    Emit('    bool ok = (raw[0] != ''\0'') && (strcmp(raw, "null") != 0);');
    Emit('    free(raw);');
    Emit('    return ok;');
    Emit('}');
    Emit('');
    Emit('static inline char* AetherJsonGetObj(const char* json, const char* key) {');
    Emit('    return AetherJsonExtractRaw(json, key);');
    Emit('}');
    Emit('');
  end;

  if FNeedCliArgs then
  begin
    Emit('// Command-Line Helpers');
    Emit('static int g_aether_argc = 0;');
    Emit('static char** g_aether_argv = NULL;');
    Emit('');
    Emit('static inline int32_t AetherParamCount(void) {');
    Emit('    return g_aether_argc > 0 ? (int32_t)(g_aether_argc - 1) : 0;');
    Emit('}');
    Emit('');
    Emit('static inline char* AetherParamStr(int32_t idx) {');
    Emit('    if (idx < 0 || idx >= g_aether_argc || !g_aether_argv) {');
    Emit('        char* empty = (char*)malloc(1);');
    Emit('        empty[0] = ''\0'';');
    Emit('        return empty;');
    Emit('    }');
    Emit('    size_t len = strlen(g_aether_argv[idx]);');
    Emit('    char* copy = (char*)malloc(len + 1);');
    Emit('    memcpy(copy, g_aether_argv[idx], len);');
    Emit('    copy[len] = ''\0'';');
    Emit('    return copy;');
    Emit('}');
    Emit('');
  end;

  if NeedSockets then
  begin
    Emit('// Aether Socket Helpers');
    Emit('#if defined(__wasm__)');
    Emit('static inline int32_t AetherSocketCreate(void) { return -1; }');
    Emit('static inline int32_t AetherSocketListen(uint16_t port, int32_t backlog) { (void)port; (void)backlog; return -1; }');
    Emit('static inline int32_t AetherSocketAccept(int32_t listen_fd) { (void)listen_fd; return -1; }');
    Emit('static inline int32_t AetherSocketConnect(const char* host, uint16_t port) { (void)host; (void)port; return -1; }');
    Emit('static inline int32_t AetherSocketSend(int32_t fd, const char* data) { (void)fd; (void)data; return 0; }');
    Emit('static inline char* AetherSocketRecv(int32_t fd, int32_t max_len) { (void)fd; (void)max_len; char* b = (char*)malloc(1); if (b) b[0] = ''\0''; return b; }');
    Emit('static inline void AetherSocketClose(int32_t fd) { (void)fd; }');
    Emit('#else');
    Emit('#ifdef _WIN32');
    Emit('static inline void AetherSocketInit(void) {');
    Emit('    static int wsa_init = 0;');
    Emit('    if (!wsa_init) {');
    Emit('        WSADATA wsa;');
    Emit('        WSAStartup(MAKEWORD(2, 2), &wsa);');
    Emit('        wsa_init = 1;');
    Emit('    }');
    Emit('}');
    Emit('#endif');
    Emit('');
    Emit('static inline int32_t AetherSocketCreate(void) {');
    Emit('#ifdef _WIN32');
    Emit('    AetherSocketInit();');
    Emit('#endif');
    Emit('    return (int32_t)socket(AF_INET, SOCK_STREAM, 0);');
    Emit('}');
    Emit('');
    Emit('static inline int32_t AetherSocketListen(uint16_t port, int32_t backlog) {');
    Emit('#ifdef _WIN32');
    Emit('    AetherSocketInit();');
    Emit('#endif');
    Emit('    int fd = socket(AF_INET, SOCK_STREAM, 0);');
    Emit('    if (fd < 0) return -1;');
    Emit('    int opt = 1;');
    Emit('    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, (const char*)&opt, sizeof(opt));');
    Emit('    struct sockaddr_in addr;');
    Emit('    memset(&addr, 0, sizeof(addr));');
    Emit('    addr.sin_family = AF_INET;');
    Emit('    addr.sin_port = htons(port);');
    Emit('    addr.sin_addr.s_addr = INADDR_ANY;');
    Emit('    if (bind(fd, (struct sockaddr*)&addr, sizeof(addr)) != 0) {');
    Emit('#ifdef _WIN32');
    Emit('        closesocket(fd);');
    Emit('#else');
    Emit('        close(fd);');
    Emit('#endif');
    Emit('        return -1;');
    Emit('    }');
    Emit('    if (listen(fd, backlog) != 0) {');
    Emit('#ifdef _WIN32');
    Emit('        closesocket(fd);');
    Emit('#else');
    Emit('        close(fd);');
    Emit('#endif');
    Emit('        return -1;');
    Emit('    }');
    Emit('    return (int32_t)fd;');
    Emit('}');
    Emit('');
    Emit('static inline int32_t AetherSocketAccept(int32_t listen_fd) {');
    Emit('    struct sockaddr_in addr;');
    Emit('    socklen_t len = sizeof(addr);');
    Emit('    int client_fd = accept(listen_fd, (struct sockaddr*)&addr, &len);');
    Emit('    return (int32_t)client_fd;');
    Emit('}');
    Emit('');
    Emit('static inline int32_t AetherSocketConnect(const char* host, uint16_t port) {');
    Emit('#ifdef _WIN32');
    Emit('    AetherSocketInit();');
    Emit('#endif');
    Emit('    int fd = socket(AF_INET, SOCK_STREAM, 0);');
    Emit('    if (fd < 0) return -1;');
    Emit('    struct sockaddr_in addr;');
    Emit('    memset(&addr, 0, sizeof(addr));');
    Emit('    addr.sin_family = AF_INET;');
    Emit('    addr.sin_port = htons(port);');
    Emit('    addr.sin_addr.s_addr = inet_addr(host ? host : "127.0.0.1");');
    Emit('    if (connect(fd, (struct sockaddr*)&addr, sizeof(addr)) != 0) {');
    Emit('#ifdef _WIN32');
    Emit('        closesocket(fd);');
    Emit('#else');
    Emit('        close(fd);');
    Emit('#endif');
    Emit('        return -1;');
    Emit('    }');
    Emit('    return (int32_t)fd;');
    Emit('}');
    Emit('');
    Emit('static inline int32_t AetherSocketSend(int32_t fd, const char* data) {');
    Emit('    if (!data) return 0;');
    Emit('    size_t len = strlen(data);');
    Emit('    if (len == 0) return 0;');
    Emit('    return (int32_t)send(fd, data, (int)len, 0);');
    Emit('}');
    Emit('');
    Emit('static inline char* AetherSocketRecv(int32_t fd, int32_t max_len) {');
    Emit('    if (max_len <= 0) max_len = 4096;');
    Emit('    char* buf = (char*)malloc(max_len + 1);');
    Emit('    int bytes = recv(fd, buf, max_len, 0);');
    Emit('    if (bytes > 0) {');
    Emit('        buf[bytes] = ''\0'';');
    Emit('        return buf;');
    Emit('    } else {');
    Emit('        buf[0] = ''\0'';');
    Emit('        return buf;');
    Emit('    }');
    Emit('}');
    Emit('');
    Emit('static inline void AetherSocketClose(int32_t fd) {');
    Emit('    if (fd >= 0) {');
    Emit('#ifdef _WIN32');
    Emit('        closesocket(fd);');
    Emit('#else');
    Emit('        close(fd);');
    Emit('#endif');
    Emit('    }');
    Emit('}');
    Emit('#endif // !__wasm__');
    Emit('');
  end;

  if NeedResult then
  begin
    Emit('typedef struct {');
    Emit('    bool is_ok;');
    Emit('    bool is_err;');
    Emit('    double value;');
    Emit('    int error;');
    Emit('    const char* str_val;');
    Emit('    const char* err_str;');
    Emit('} AetherResult;');
    Emit('');
  end;

  if Pos('AetherOption', ReachText) > 0 then begin end; // keep anchor
  if NeedOption then
  begin
    Emit('typedef struct {');
    Emit('    bool is_some;');
    Emit('    bool is_none;');
    Emit('    double num_val;');
    Emit('    const char* str_val;');
    Emit('} AetherOption;');
    Emit('');
  end;

  if Pos('AetherPadLeft', ReachText) > 0 then
  begin
    Emit('static inline char* AetherPadLeft(const char* s, int32_t width, const char* pad) {');
    Emit('    const char* src = s ? s : "";');
    Emit('    size_t sl = strlen(src);');
    Emit('    if ((int32_t)sl >= width) { char* c = (char*)malloc(sl + 1); memcpy(c, src, sl + 1); return c; }');
    Emit('    const char* p = (pad && pad[0]) ? pad : " ";');
    Emit('    size_t pl = strlen(p);');
    Emit('    size_t need = (size_t)width - sl;');
    Emit('    char* res = (char*)malloc((size_t)width + 1);');
    Emit('    for (size_t i = 0; i < need; i++) res[i] = p[i % pl];');
    Emit('    memcpy(res + need, src, sl + 1);');
    Emit('    return res;');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherPadRight', ReachText) > 0 then
  begin
    Emit('static inline char* AetherPadRight(const char* s, int32_t width, const char* pad) {');
    Emit('    const char* src = s ? s : "";');
    Emit('    size_t sl = strlen(src);');
    Emit('    if ((int32_t)sl >= width) { char* c = (char*)malloc(sl + 1); memcpy(c, src, sl + 1); return c; }');
    Emit('    const char* p = (pad && pad[0]) ? pad : " ";');
    Emit('    size_t pl = strlen(p);');
    Emit('    size_t need = (size_t)width - sl;');
    Emit('    char* res = (char*)malloc((size_t)width + 1);');
    Emit('    memcpy(res, src, sl);');
    Emit('    for (size_t i = 0; i < need; i++) res[sl + i] = p[i % pl];');
    Emit('    res[sl + need] = ''\0'';');
    Emit('    return res;');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherRepeatStr', ReachText) > 0 then
  begin
    Emit('static inline char* AetherRepeatStr(const char* s, int32_t count) {');
    Emit('    if (!s || s[0] == ''\0'' || count <= 0) { char* e = (char*)malloc(1); e[0] = ''\0''; return e; }');
    Emit('    size_t sl = strlen(s);');
    Emit('    size_t total = sl * (size_t)count;');
    Emit('    char* res = (char*)malloc(total + 1);');
    Emit('    for (int32_t i = 0; i < count; i++) memcpy(res + (size_t)i * sl, s, sl);');
    Emit('    res[total] = ''\0'';');
    Emit('    return res;');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherStrToFloat', ReachText) > 0 then
  begin
    Emit('static inline double AetherStrToFloat(const char* s) {');
    Emit('    if (!s) return 0.0;');
    Emit('    while (*s == '' '' || *s == ''\t'' || *s == ''\n'' || *s == ''\r'') s++;');
    Emit('    if (*s == ''\0'') return 0.0;');
    Emit('    char* endp = NULL;');
    Emit('    double v = strtod(s, &endp);');
    Emit('    if (endp == s) return 0.0;');
    Emit('    return v;');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherTryStrToInt', ReachText) > 0 then
  begin
    Emit('static inline AetherOption AetherTryStrToInt(const char* s) {');
    Emit('    if (!s) return ((AetherOption){ .is_some = false, .is_none = true, .num_val = 0, .str_val = "" });');
    Emit('    while (*s == '' '' || *s == ''\t'' || *s == ''\n'' || *s == ''\r'') s++;');
    Emit('    if (*s == ''\0'') return ((AetherOption){ .is_some = false, .is_none = true, .num_val = 0, .str_val = "" });');
    Emit('    char* endp = NULL;');
    Emit('    long long v = strtoll(s, &endp, 10);');
    Emit('    if (endp == s) return ((AetherOption){ .is_some = false, .is_none = true, .num_val = 0, .str_val = "" });');
    Emit('    while (*endp == '' '' || *endp == ''\t'' || *endp == ''\n'' || *endp == ''\r'') endp++;');
    Emit('    if (*endp != ''\0'' || v < (-2147483647LL - 1LL) || v > 2147483647LL)');
    Emit('        return ((AetherOption){ .is_some = false, .is_none = true, .num_val = 0, .str_val = "" });');
    Emit('    return ((AetherOption){ .is_some = true, .is_none = false, .num_val = (double)(int32_t)v, .str_val = "" });');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherTryStrToFloat', ReachText) > 0 then
  begin
    Emit('static inline AetherOption AetherTryStrToFloat(const char* s) {');
    Emit('    if (!s) return ((AetherOption){ .is_some = false, .is_none = true, .num_val = 0, .str_val = "" });');
    Emit('    while (*s == '' '' || *s == ''\t'' || *s == ''\n'' || *s == ''\r'') s++;');
    Emit('    if (*s == ''\0'') return ((AetherOption){ .is_some = false, .is_none = true, .num_val = 0, .str_val = "" });');
    Emit('    char* endp = NULL;');
    Emit('    double v = strtod(s, &endp);');
    Emit('    if (endp == s) return ((AetherOption){ .is_some = false, .is_none = true, .num_val = 0, .str_val = "" });');
    Emit('    while (*endp == '' '' || *endp == ''\t'' || *endp == ''\n'' || *endp == ''\r'') endp++;');
    Emit('    if (*endp != ''\0'') return ((AetherOption){ .is_some = false, .is_none = true, .num_val = 0, .str_val = "" });');
    Emit('    return ((AetherOption){ .is_some = true, .is_none = false, .num_val = v, .str_val = "" });');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherStrSplit', ReachText) > 0 then
  begin
    Emit('static inline const char** AetherStrSplit(const char* s, const char* sep) {');
    Emit('    const char* src = s ? s : "";');
    Emit('    const char* sp = sep ? sep : "";');
    Emit('    const char** res = (const char**)AetherDynSetLength(NULL, sizeof(const char*), 0);');
    Emit('    size_t sl = strlen(src), spl = strlen(sp);');
    Emit('    if (spl == 0) {');
    Emit('        res = (const char**)AetherDynSetLength((void*)res, sizeof(const char*), sl);');
    Emit('        for (size_t i = 0; i < sl; i++) {');
    Emit('            char* c = (char*)malloc(2); c[0] = src[i]; c[1] = ''\0''; res[i] = c;');
    Emit('        }');
    Emit('        return res;');
    Emit('    }');
    Emit('    const char* cur = src;');
    Emit('    while (1) {');
    Emit('        const char* found = strstr(cur, sp);');
    Emit('        size_t part_len = found ? (size_t)(found - cur) : strlen(cur);');
    Emit('        char* part = (char*)malloc(part_len + 1);');
    Emit('        if (part_len > 0) memcpy(part, cur, part_len);');
    Emit('        part[part_len] = ''\0'';');
    Emit('        size_t n = AetherDynLen(res);');
    Emit('        res = (const char**)AetherDynSetLength((void*)res, sizeof(const char*), n + 1);');
    Emit('        res[n] = part;');
    Emit('        if (!found) break;');
    Emit('        cur = found + spl;');
    Emit('    }');
    Emit('    return res;');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherStrJoin', ReachText) > 0 then
  begin
    Emit('static inline char* AetherStrJoin(const char** parts, const char* sep) {');
    Emit('    size_t n = AetherDynLen(parts);');
    Emit('    if (n == 0) { char* e = (char*)malloc(1); e[0] = ''\0''; return e; }');
    Emit('    const char* sp = sep ? sep : "";');
    Emit('    size_t spl = strlen(sp);');
    Emit('    size_t total = (n - 1) * spl;');
    Emit('    for (size_t i = 0; i < n; i++) total += strlen(parts[i] ? parts[i] : "");');
    Emit('    char* res = (char*)malloc(total + 1);');
    Emit('    size_t pos = 0;');
    Emit('    for (size_t i = 0; i < n; i++) {');
    Emit('        if (i > 0 && spl > 0) { memcpy(res + pos, sp, spl); pos += spl; }');
    Emit('        const char* p = parts[i] ? parts[i] : "";');
    Emit('        size_t pl = strlen(p);');
    Emit('        if (pl > 0) { memcpy(res + pos, p, pl); pos += pl; }');
    Emit('    }');
    Emit('    res[pos] = ''\0'';');
    Emit('    return res;');
    Emit('}');
    Emit('');
  end;

  if (Pos('AetherRandomInt', ReachText) > 0) or (Pos('AetherRandomFloat', ReachText) > 0) then
  begin
    Emit('static bool g_aether_rand_seeded = false;');
    Emit('static inline void AetherEnsureRandSeed(void) {');
    Emit('    if (!g_aether_rand_seeded) { srand((unsigned int)time(NULL)); g_aether_rand_seeded = true; }');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherRandomInt', ReachText) > 0 then
  begin
    Emit('static inline int32_t AetherRandomInt(int32_t min_v, int32_t max_v) {');
    Emit('    AetherEnsureRandSeed();');
    Emit('    int32_t lo = min_v <= max_v ? min_v : max_v;');
    Emit('    int32_t hi = min_v <= max_v ? max_v : min_v;');
    Emit('    if (lo == hi) return lo;');
    Emit('    uint64_t span = (uint64_t)((int64_t)hi - (int64_t)lo + 1);');
    Emit('    uint64_t r = ((uint64_t)rand() << 15) ^ (uint64_t)rand();');
    Emit('    return lo + (int32_t)(r % span);');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherRandomFloat', ReachText) > 0 then
  begin
    Emit('static inline double AetherRandomFloat(void) {');
    Emit('    AetherEnsureRandSeed();');
    Emit('    return (double)rand() / ((double)RAND_MAX + 1.0);');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherReadLn', ReachText) > 0 then
  begin
    Emit('static inline char* AetherReadLn(void) {');
    Emit('#if defined(__wasm__)');
    Emit('    char* e = (char*)malloc(1); e[0] = ''\0''; return e;');
    Emit('#else');
    Emit('    char buf[4096];');
    Emit('    if (!fgets(buf, sizeof(buf), stdin)) { char* e = (char*)malloc(1); e[0] = ''\0''; return e; }');
    Emit('    size_t l = strlen(buf);');
    Emit('    while (l > 0 && (buf[l - 1] == ''\n'' || buf[l - 1] == ''\r'')) l--;');
    Emit('    char* out = (char*)malloc(l + 1);');
    Emit('    if (l > 0) memcpy(out, buf, l);');
    Emit('    out[l] = ''\0'';');
    Emit('    return out;');
    Emit('#endif');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherGetEnv', ReachText) > 0 then
  begin
    Emit('static inline char* AetherGetEnv(const char* name) {');
    Emit('#if defined(__wasm__)');
    Emit('    (void)name; char* e = (char*)malloc(1); e[0] = ''\0''; return e;');
    Emit('#else');
    Emit('    const char* v = name ? getenv(name) : NULL;');
    Emit('    if (!v) { char* e = (char*)malloc(1); e[0] = ''\0''; return e; }');
    Emit('    size_t l = strlen(v); char* copy = (char*)malloc(l + 1); memcpy(copy, v, l + 1); return copy;');
    Emit('#endif');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherSetEnv', ReachText) > 0 then
  begin
    Emit('static inline bool AetherSetEnv(const char* name, const char* val) {');
    Emit('#if defined(__wasm__)');
    Emit('    (void)name; (void)val; return false;');
    Emit('#elif defined(_WIN32)');
    Emit('    return (name && val) ? (_putenv_s(name, val) == 0) : false;');
    Emit('#else');
    Emit('    return (name && val) ? (setenv(name, val, 1) == 0) : false;');
    Emit('#endif');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherListDir', ReachText) > 0 then
  begin
    Emit('static inline const char** AetherListDir(const char* path) {');
    Emit('    const char** res = (const char**)AetherDynSetLength(NULL, sizeof(const char*), 0);');
    Emit('#if defined(__wasm__)');
    Emit('    (void)path; return res;');
    Emit('#elif defined(_WIN32)');
    Emit('    const char* p = (path && path[0]) ? path : ".";');
    Emit('    size_t pl = strlen(p);');
    Emit('    bool has_sep = (p[pl - 1] == ''\\'' || p[pl - 1] == ''/'');');
    Emit('    char* pat = (char*)malloc(pl + 3);');
    Emit('    memcpy(pat, p, pl);');
    Emit('    if (!has_sep) pat[pl++] = ''\\'';');
    Emit('    pat[pl++] = ''*''; pat[pl] = ''\0'';');
    Emit('    WIN32_FIND_DATAA ffd;');
    Emit('    HANDLE h = FindFirstFileA(pat, &ffd);');
    Emit('    free(pat);');
    Emit('    if (h != INVALID_HANDLE_VALUE) {');
    Emit('        do {');
    Emit('            if (strcmp(ffd.cFileName, ".") != 0 && strcmp(ffd.cFileName, "..") != 0) {');
    Emit('                size_t nl = strlen(ffd.cFileName);');
    Emit('                char* item = (char*)malloc(nl + 1);');
    Emit('                memcpy(item, ffd.cFileName, nl + 1);');
    Emit('                size_t n = AetherDynLen(res);');
    Emit('                res = (const char**)AetherDynSetLength((void*)res, sizeof(const char*), n + 1);');
    Emit('                res[n] = item;');
    Emit('            }');
    Emit('        } while (FindNextFileA(h, &ffd));');
    Emit('        FindClose(h);');
    Emit('    }');
    Emit('    return res;');
    Emit('#else');
    Emit('    DIR* d = opendir((path && path[0]) ? path : ".");');
    Emit('    if (d) {');
    Emit('        struct dirent* ent;');
    Emit('        while ((ent = readdir(d)) != NULL) {');
    Emit('            if (strcmp(ent->d_name, ".") != 0 && strcmp(ent->d_name, "..") != 0) {');
    Emit('                size_t nl = strlen(ent->d_name);');
    Emit('                char* item = (char*)malloc(nl + 1);');
    Emit('                memcpy(item, ent->d_name, nl + 1);');
    Emit('                size_t n = AetherDynLen(res);');
    Emit('                res = (const char**)AetherDynSetLength((void*)res, sizeof(const char*), n + 1);');
    Emit('                res[n] = item;');
    Emit('            }');
    Emit('        }');
    Emit('        closedir(d);');
    Emit('    }');
    Emit('    return res;');
    Emit('#endif');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherCopyFile', ReachText) > 0 then
  begin
    Emit('static inline bool AetherCopyFile(const char* src, const char* dst) {');
    Emit('#if defined(__wasm__)');
    Emit('    (void)src; (void)dst; return false;');
    Emit('#else');
    Emit('    FILE* fs = fopen(src, "rb");');
    Emit('    if (!fs) return false;');
    Emit('    FILE* fd = fopen(dst, "wb");');
    Emit('    if (!fd) { fclose(fs); return false; }');
    Emit('    char buf[4096]; size_t r; bool ok = true;');
    Emit('    while ((r = fread(buf, 1, sizeof(buf), fs)) > 0) {');
    Emit('        if (fwrite(buf, 1, r, fd) != r) { ok = false; break; }');
    Emit('    }');
    Emit('    if (ferror(fs) || ferror(fd)) ok = false;');
    Emit('    fclose(fd); fclose(fs);');
    Emit('    return ok;');
    Emit('#endif');
    Emit('}');
    Emit('');
  end;

  if Pos('AetherRenameFile', ReachText) > 0 then
  begin
    Emit('static inline bool AetherRenameFile(const char* oldp, const char* newp) {');
    Emit('#if defined(__wasm__)');
    Emit('    (void)oldp; (void)newp; return false;');
    Emit('#else');
    Emit('    return (oldp && newp) ? (rename(oldp, newp) == 0) : false;');
    Emit('#endif');
    Emit('}');
    Emit('');
  end;

  EmitMapRuntimeDecls(MapTags, MapKeys, MapVals, True);

  // Constants
  for I := 0 to AModule.Constants.Count - 1 do
    if ConstUsed[I] then
      Emit(ConstBodies[I]);
  if UsedConstCount > 0 then Emit('');

  // Forward typedefs to allow recursive records and payload enums
  if UsedTypeCount > 0 then
  begin
    for I := 0 to AModule.Types.Count - 1 do
    begin
      if TypeUsed[I] and (AModule.Types[I] is TASTRecordDecl) and (TASTRecordDecl(AModule.Types[I]).GenericParams.Count = 0) then
      begin
        Emit(Format('typedef struct T%s T%s;', [TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name]));
        Emit(Format('typedef T%s* PT%s;', [TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name]));
      end
      else if TypeUsed[I] and (AModule.Types[I] is TASTEnumDecl) and TASTEnumDecl(AModule.Types[I]).HasPayload then
      begin
        Emit(Format('typedef struct T%s T%s;', [TASTEnumDecl(AModule.Types[I]).Name, TASTEnumDecl(AModule.Types[I]).Name]));
        Emit(Format('typedef T%s* PT%s;', [TASTEnumDecl(AModule.Types[I]).Name, TASTEnumDecl(AModule.Types[I]).Name]));
      end;
    end;
    Emit('');
  end;

  // Types and typed monad structs in topological order
  EmitTopologicalTypesAndMonads(TypeUsed, OptTags, OptInners, OptUsed, ResTags, ResVals, ResErrs, ResUsed);
  EmitMapRuntimeDecls(MapTags, MapKeys, MapVals, False);
  for I := 0 to AModule.Types.Count - 1 do
    if TypeUsed[I] and (AModule.Types[I] is TASTMapDecl) then
      EmitMapDecl(TASTMapDecl(AModule.Types[I]));
  EmitFnRuntimeHelpers;
  if (UsedTypeCount > 0) or (UsedOptCount > 0) or (UsedResCount > 0) or (MapTags.Count > 0) or (FFnTags.Count > 0) then Emit('');

  // AetherBox constructors for Records (on demand)
  for I := 0 to AModule.Types.Count - 1 do
  begin
    if TypeUsed[I] and (AModule.Types[I] is TASTRecordDecl) and (TASTRecordDecl(AModule.Types[I]).GenericParams.Count = 0) and
       (Pos('AetherBox_T' + TASTRecordDecl(AModule.Types[I]).Name, ReachText) > 0) then
    begin
      Emit(Format('static inline PT%s AetherBox_T%s(T%s V) {', [TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name]));
      Emit(Format('    PT%s p = (PT%s)malloc(sizeof(T%s));', [TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name]));
      Emit('    *p = V;');
      Emit('    return p;');
      Emit('}');
      Emit('');
    end;
  end;

  EmitTypedMonadHelpers(UOptTags, UOptInners, UResTags, UResVals, UResErrs);
  EmitMapRuntimeHelpers(MapTags, MapKeys, MapVals);

  // Module / Unit Variables
  for I := 0 to AModule.ModuleVars.Count - 1 do
  begin
    if KeepAll or (TASTVarDecl(AModule.ModuleVars[I]).SourceModule = '') or
       (Pos(TASTVarDecl(AModule.ModuleVars[I]).Name, ReachText) > 0) then
    begin
      if Pos('array[', TASTVarDecl(AModule.ModuleVars[I]).TypeName) = 1 then
        Emit(FormatCArrayVar(TASTVarDecl(AModule.ModuleVars[I]).TypeName, TASTVarDecl(AModule.ModuleVars[I]).Name))
      else
        Emit(Format('%s %s;', [EmitTypeRef(TASTVarDecl(AModule.ModuleVars[I]).TypeName), TASTVarDecl(AModule.ModuleVars[I]).Name]));
    end;
  end;
  if AModule.ModuleVars.Count > 0 then Emit('');

  // Forward prototypes of all used functions
  for I := 0 to AModule.Functions.Count - 1 do
    if FuncUsed[I] and (FuncProtos[I] <> '') then
      Emit(FuncProtos[I]);
  EmitLambdaAndThunkDecls(True);
  Emit('');

  // Functions
  for I := 0 to AModule.Functions.Count - 1 do
    if FuncUsed[I] then
      EmitFunction(TASTFunction(AModule.Functions[I]));
  EmitLambdaAndThunkDecls(False);

  if (not Assigned(AModule.ProgramBlock)) and (AModule.InitBody.Count > 0) then
  begin
    Emit(Format('void _aether_init_%s(void) {', [AModule.Name]));
    IncIndent;
    FActiveDefers.Clear;
    FLoopDeferBase := 0;
    FRaiiNames.Clear;
    FRaiiTypes.Clear;
    FLoopRaiiBase := 0;
    EmitStmtList(AModule.InitBody);
    DecIndent;
    Emit('}');
    Emit('');
  end;
  if (not Assigned(AModule.ProgramBlock)) and (AModule.FiniBody.Count > 0) then
  begin
    Emit(Format('void _aether_fini_%s(void) {', [AModule.Name]));
    IncIndent;
    FActiveDefers.Clear;
    FLoopDeferBase := 0;
    FRaiiNames.Clear;
    FRaiiTypes.Clear;
    FLoopRaiiBase := 0;
    EmitStmtList(AModule.FiniBody);
    DecIndent;
    Emit('}');
    Emit('');
  end;

  // Program Block
  if Assigned(AModule.ProgramBlock) then
    EmitProgramBlock(AModule.ProgramBlock)
  else if not HasExports then
  begin
    Emit('#ifndef __wasm__');
    Emit('int main(int argc, char** argv) {');
    Emit('    (void)argc; (void)argv;');
    Emit('    return 0;');
    Emit('}');
    Emit('#endif');
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
