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
    FGuardBindName: string;
    FGuardBindExpr: string;
    FMatchBindName: string;
    FMatchBindType: string;

    procedure Emit(const Line: string = '');
    procedure IncIndent;
    procedure DecIndent;
    function IndentStr: string;
    procedure EmitActiveDefers(DownToIndex: Integer = 0);
    procedure EmitStmtList(List: TASTNodeList; IsLoopBody: Boolean = False);

    function IsEnumName(const AName: string): Boolean;
    function IsRecordName(const AName: string): Boolean;
    function IsModulePrefixName(const AName: string): Boolean;
    function ResolveAliasType(const AType: string): string;
    function IsSetType(const AName: string): Boolean;
    function IsDynamicArrayType(const AType: string): Boolean;
    function IsValueOptionType(const AType: string): Boolean;
    function SplitResultTypes(const AType: string; out ValType, ErrType: string): Boolean;
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
    procedure EmitRuntimeHelpersInterface;
    procedure EmitRuntimeHelpersImplementation;
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
end;

destructor TAetherEmitterPascal.Destroy;
begin
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
var
  I: Integer;
begin
  Result := False;
  if Assigned(FModule) then
    for I := 0 to FModule.Types.Count - 1 do
      if (TASTNode(FModule.Types[I]) is TASTEnumDecl) and
         (TASTEnumDecl(FModule.Types[I]).Name = AName) then
        Exit(True);
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
  I, K: Integer;
  CaseNode: TASTMatchCase;
  MT, DeclType, KeyT, ValT, ErrT: string;

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
    for I := 0 to TASTCallExpr(Expr).Args.Count - 1 do
      CollectAutoVarsFromExpr(TASTCallArg(TASTCallExpr(Expr).Args[I]).Expr, VarNames, VarTypes, SkipNames);
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
    for K := 0 to TASTMatchExpr(Expr).Cases.Count - 1 do
    begin
      CaseNode := TASTMatchCase(TASTMatchExpr(Expr).Cases[K]);
      if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
      begin
        if Pos('Err', CaseNode.Pattern.Value) = 1 then
        begin
          SplitResultTypes(MT, ValT, ErrT);
          DeclType := EmitTypeRef(ErrT);
          if DeclType = '' then DeclType := 'LongInt';
        end
        else if Pos('Ok', CaseNode.Pattern.Value) = 1 then
        begin
          SplitResultTypes(MT, ValT, ErrT);
          DeclType := EmitTypeRef(ValT);
          if DeclType = '' then DeclType := 'Double';
        end
        else if CaseNode.Pattern.Value = 'Some' then
        begin
          if Pos('Option<', MT) = 1 then
            DeclType := EmitTypeRef(Trim(Copy(MT, 8, Length(MT) - 8)))
          else
            DeclType := 'Pointer';
        end
        else
        begin
          DeclType := EmitTypeRef(MT);
          if DeclType = '' then DeclType := 'Int32';
        end;
        AddAutoVarLocal(CaseNode.Pattern.SubPattern, DeclType);
      end;
      CollectAutoVarsFromExpr(CaseNode.Guard, VarNames, VarTypes, SkipNames);
      CollectAutoVarsFromExpr(CaseNode.ValueExpr, VarNames, VarTypes, SkipNames);
    end;
  end;
end;

procedure TAetherEmitterPascal.CollectAutoVarsFromStmts(Stmts: TASTNodeList; VarNames, VarTypes: TStrings; const SkipNames: TStrings);
var
  I, K: Integer;
  S: TASTStmt;
  ForStmt: TASTForStmt;
  MatchNode: TASTMatchStmt;
  CaseNode: TASTMatchCase;
  VD: TASTVarDecl;
  ElemT, MT, DeclType, KeyT, ValT, ErrT: string;

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
      for K := 0 to MatchNode.Cases.Count - 1 do
      begin
        CaseNode := TASTMatchCase(MatchNode.Cases[K]);
        if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
        begin
          if Pos('Err', CaseNode.Pattern.Value) = 1 then
          begin
            SplitResultTypes(MT, ValT, ErrT);
            DeclType := EmitTypeRef(ErrT);
            if DeclType = '' then DeclType := 'LongInt';
          end
          else if Pos('Ok', CaseNode.Pattern.Value) = 1 then
          begin
            SplitResultTypes(MT, ValT, ErrT);
            DeclType := EmitTypeRef(ValT);
            if DeclType = '' then DeclType := 'Double';
          end
          else if CaseNode.Pattern.Value = 'Some' then
          begin
            if Pos('Option<', MT) = 1 then
              DeclType := EmitTypeRef(Trim(Copy(MT, 8, Length(MT) - 8)))
            else
              DeclType := 'Pointer';
          end
          else
          begin
            DeclType := EmitTypeRef(MT);
            if DeclType = '' then DeclType := 'Int32';
          end;
          AddAutoVar(CaseNode.Pattern.SubPattern, DeclType);
        end;
        CollectAutoVarsFromExpr(CaseNode.Guard, VarNames, VarTypes, SkipNames);
        CollectAutoVarsFromStmts(CaseNode.Body, VarNames, VarTypes, SkipNames);
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
    if (FMatchBindName <> '') and SameText(Id.Name, FMatchBindName) then
      Exit(FMatchBindType);
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
    end;
  end
  else if Expr is TASTMemberAccessExpr then
  begin
    Acc := TASTMemberAccessExpr(Expr);
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
        CleanTarget := Trim(Copy(TargetType, 8, Length(TargetType) - 8));
        if Pos('Box<', CleanTarget) = 1 then
          CleanTarget := Trim(Copy(CleanTarget, 5, Length(CleanTarget) - 5));
        Exit(CleanTarget);
      end;
    end;
    if Pos('Box<', TargetType) > 0 then
    begin
      P1 := Pos('Box<', TargetType);
      CleanTarget := Copy(TargetType, P1 + 4, Length(TargetType));
      P2 := Pos('>', CleanTarget);
      if P2 > 0 then CleanTarget := Copy(CleanTarget, 1, P2 - 1);
    end
    else if Pos('Option<', TargetType) = 1 then
    begin
      P1 := Pos('<', TargetType);
      CleanTarget := Copy(TargetType, P1 + 1, Length(TargetType) - P1 - 1);
      if Pos('Box<', CleanTarget) = 1 then
      begin
        CleanTarget := Copy(CleanTarget, 5, Length(CleanTarget) - 5);
      end;
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
  else if Expr is TASTCallExpr then
  begin
    Call := TASTCallExpr(Expr);
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
    if SameText(Call.Callee, 'Default') and (Call.Args.Count = 1) and (TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr) then
      Exit(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name);
    if (Call.Callee = 'ReadFile') or (Call.Callee = 'CharAt') or (Call.Callee = 'Substring') or (Call.Callee = 'ToString') or
       (Call.Callee = 'IntToStr') or (Call.Callee = 'FloatToStr') or (Call.Callee = 'BoolToStr') or (Call.Callee = 'CharToStr') or
       (Call.Callee = '__InterpToStr') or (Call.Callee = '__JsonGetStr') or (Call.Callee = '__JsonGetObj') or
       (Call.Callee = 'SocketRecv') or (Call.Callee = 'ParamStr') or
       SameText(Call.Callee, 'Trim') or SameText(Call.Callee, 'UpperCase') or SameText(Call.Callee, 'LowerCase') or SameText(Call.Callee, 'Replace') then Exit('String');
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
       SameText(Call.Callee, 'IndexOf') or (Call.Callee = 'StrToInt') or (Call.Callee = 'SocketCreate') or
       (Call.Callee = 'SocketListen') or (Call.Callee = 'SocketAccept') or (Call.Callee = 'SocketConnect') or
       (Call.Callee = 'SocketSend') or (Call.Callee = 'ParamCount') then Exit('Int32');
    if (Call.Callee = 'sin') or (Call.Callee = 'cos') or (Call.Callee = 'tan') or (Call.Callee = 'sqrt') or (Call.Callee = 'Now') then Exit('Float64');
    if (Call.Callee = 'GetTickCount64') or (Call.Callee = 'GetNanoseconds') then Exit('UInt64');
    if (Call.Callee = 'FileSize') then Exit('Int64');
    if SameText(Call.Callee, 'Contains') or SameText(Call.Callee, 'StartsWith') or SameText(Call.Callee, 'EndsWith') or
       (Call.Callee = 'FileExists') or (Call.Callee = 'WriteFile') or (Call.Callee = 'CreateDir') or (Call.Callee = 'RemoveDir') or
       (Call.Callee = 'DeleteFile') or (Call.Callee = 'DirExists') then Exit('Bool');
    if SameText(Call.Callee, 'Clear') or SameText(Call.Callee, 'Delete') or SameText(Call.Callee, 'Insert') or
       SameText(Call.Callee, 'Inc') or SameText(Call.Callee, 'Dec') or SameText(Call.Callee, 'Remove') or
       (Call.Callee = 'SocketClose') or (Call.Callee = 'Assert') or (Call.Callee = 'SleepMs') then Exit('Void');
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
  Inner, Inner2: string;
  P1, P2: Integer;
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
      Result := 'array of ' + EmitTypeRef(Inner);
  end
  else if Pos('Result', AType) = 1 then
    Result := 'TResultDoubleError'
  else if Pos('array[', AType) = 1 then
    Result := FormatPascalArrayType(AType)
  else if Pos('set of ', AType) = 1 then
    Result := 'set of ' + EmitTypeRef(Trim(Copy(AType, 8, Length(AType))))
  else if Pos('Box<', AType) > 0 then
  begin
    P1 := Pos('Box<', AType);
    Inner := Copy(AType, P1 + 4, Length(AType));
    P2 := Pos('>', Inner);
    if P2 > 0 then Inner := Copy(Inner, 1, P2 - 1);
    Result := 'P' + EmitTypeRef(Inner);
  end
  else if (Copy(AType, 1, 5) = 'Task<') and (AType[Length(AType)] = '>') then
  begin
    Inner := Copy(AType, 6, Length(AType) - 6);
    Result := 'specialize TAetherTask<' + EmitTypeRef(Inner) + '>';
  end
  else if Pos('Option<', AType) = 1 then
  begin
    if IsValueOptionType(AType) then
      Result := 'TAetherOption'
    else
    begin
      Inner := Copy(AType, 8, Length(AType) - 8);
      Result := EmitTypeRef(Inner);
    end;
  end
  else if IsMapType(AType, Inner, Inner2) then
    Result := 'TAetherMap_' + MapTag(Inner, Inner2)
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
  ArgsStr, KeyT, ValT, TargetT, ValF, ErrF: string;
  I: Integer;
  TargetStr: string;
  IsWild: Boolean;
  BindVarT, OldBindName, OldBindType: string;
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
    if (FGuardBindName <> '') and SameText(Id.Name, FGuardBindName) then
      Result := '(' + FGuardBindExpr + ')'
    else if Id.Name = '__ValueNone' then
      Result := 'AetherNone()'
    else if Id.Name = 'None' then
      Result := 'nil'
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
    // Caso Enum.Variante ou Alias.Enum.Variante
    if ((Acc.Target is TASTIdentifierExpr) and IsEnumName(TASTIdentifierExpr(Acc.Target).Name)) or
       ((Acc.Target is TASTMemberAccessExpr) and IsEnumName(TargetStr)) then
      Result := TargetStr + '_' + Acc.Member
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
    else if IsValueOptionType(TargetT) then
    begin
      if Acc.Member = 'is_some' then
        Result := TargetStr + '.is_some'
      else if Acc.Member = 'is_none' then
        Result := TargetStr + '.is_none'
      else if Acc.Member = 'value' then
      begin
        ValF := Trim(Copy(TargetT, 8, Length(TargetT) - 8));
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
      if Pos('Result', TargetT) = 1 then
      begin
        SplitResultTypes(TargetT, ValF, ErrF);
        Emit(Format('if %s.is_err then', [TargetStr]));
        Emit('begin');
        IncIndent;
        if FActiveDefers.Count > 0 then EmitActiveDefers(0);
        Emit(Format('Exit(%s);', [TargetStr]));
        DecIndent;
        Emit('end;');
        Result := EmitMonadFieldExtract(TargetStr, ValF, 'value', 'str_val');
      end
      else if IsValueOptionType(TargetT) then
      begin
        ValF := Trim(Copy(TargetT, 8, Length(TargetT) - 8));
        Emit(Format('if %s.is_none then', [TargetStr]));
        Emit('begin');
        IncIndent;
        if FActiveDefers.Count > 0 then EmitActiveDefers(0);
        Emit(Format('Exit(%s);', [TargetStr]));
        DecIndent;
        Emit('end;');
        Result := EmitMonadFieldExtract(TargetStr, ValF, 'num_val', 'str_val');
      end
      else
      begin
        Emit(Format('if %s = nil then', [TargetStr]));
        Emit('begin');
        IncIndent;
        if FActiveDefers.Count > 0 then EmitActiveDefers(0);
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

    // PrintLn traduz para WriteLn ou WriteLn(Format(...))
    if Call.Callee = 'PrintLn' then
    begin
      if Call.Args.Count = 1 then
        Result := 'WriteLn(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')'
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
        Result := 'WriteLn(Format(' + ArgsStr + '))';
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

    // Construtores Ok, Err e Some
    if Call.Callee = 'Ok' then
    begin
      TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
      if TargetT = 'Char' then
        Result := 'AetherOk(Ord(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))'
      else
        Result := 'AetherOk(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'Err' then
    begin
      TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
      if TargetT = 'String' then
        Result := 'AetherErr(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')'
      else
        Result := 'AetherErr(Integer(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if Call.Callee = 'Some' then
    begin
      if IsPointerTarget(TASTCallArg(Call.Args[0]).Expr) then
        Result := EmitExpr(TASTCallArg(Call.Args[0]).Expr)
      else
      begin
        TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
        if TargetT = 'Char' then
          Result := 'AetherSome(Ord(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))'
        else
          Result := 'AetherSome(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
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

    // Chamada normal ou construtor de record
    ArgsStr := '';
    for I := 0 to Call.Args.Count - 1 do
    begin
      ArgsStr := ArgsStr + EmitExpr(TASTCallArg(Call.Args[I]).Expr);
      if I < Call.Args.Count - 1 then
        ArgsStr := ArgsStr + ', ';
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
    ValF := EmitExpr(TASTMatchExpr(Expr).Expr);
    ErrF := ResolveAliasType(GetExprTypeName(TASTMatchExpr(Expr).Expr));
    OldBindName := FMatchBindName;
    OldBindType := FMatchBindType;
    for I := 0 to TASTMatchExpr(Expr).Cases.Count - 1 do
    begin
      BuildMatchCaseCond(TASTMatchExpr(Expr).Cases[I] as TASTMatchCase, ValF, ErrF, KeyT, ValT, BindVarT, IsWild);
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
      if TASTMatchCase(TASTMatchExpr(Expr).Cases[I]).Pattern.IsLet and
         (TASTMatchCase(TASTMatchExpr(Expr).Cases[I]).Pattern.SubPattern <> '') and
         (TASTMatchCase(TASTMatchExpr(Expr).Cases[I]).Pattern.SubPattern <> '_') then
      begin
        FMatchBindName := TASTMatchCase(TASTMatchExpr(Expr).Cases[I]).Pattern.SubPattern;
        FMatchBindType := BindVarT;
      end;
      Emit(Format('%s := %s;', [TargetStr, EmitExpr(TASTMatchCase(TASTMatchExpr(Expr).Cases[I]).ValueExpr)]));
      FMatchBindName := OldBindName;
      FMatchBindType := OldBindType;
      DecIndent;
      if I < TASTMatchExpr(Expr).Cases.Count - 1 then Emit('end') else Emit('end;');
    end;
    Result := TargetStr;
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

procedure TAetherEmitterPascal.EmitStmtList(List: TASTNodeList; IsLoopBody: Boolean);
var
  I, SavedBase, OldLoopBase: Integer;
begin
  SavedBase := FActiveDefers.Count;
  OldLoopBase := FLoopDeferBase;
  if IsLoopBody then
    FLoopDeferBase := SavedBase;
  try
    for I := 0 to List.Count - 1 do
      EmitStmt(TASTStmt(List[I]));
    if (List.Count = 0) or not (List[List.Count - 1] is TASTReturnStmt) then
      EmitActiveDefers(SavedBase);
  finally
    FLoopDeferBase := OldLoopBase;
    while FActiveDefers.Count > SavedBase do
      FActiveDefers.Delete(FActiveDefers.Count - 1);
  end;
end;

procedure TAetherEmitterPascal.BuildMatchCaseCond(CaseNode: TASTMatchCase; const ExprStr, MatchedType: string;
  out CondStr, BindStmt, BindVarType: string; out IsWildcardArm: Boolean);
var
  PatStr, ValF, ErrF, PatItem, LoStr, HiStr, LoExpr, HiExpr, ItemCond, BindExprStr, GuardStr: string;
  K, P2: Integer;

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

  if PatStr = '_' then
  begin
    if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
      BindStmt := Format('%s := %s;', [CaseNode.Pattern.SubPattern, ExprStr]);
  end
  else if Pos('Ok', PatStr) = 1 then
  begin
    CondStr := Format('%s.is_ok', [ExprStr]);
    if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
    begin
      SplitResultTypes(MatchedType, ValF, ErrF);
      BindVarType := ValF;
      BindExprStr := EmitMonadFieldExtract(ExprStr, ValF, 'value', 'str_val');
      BindStmt := Format('%s := %s;', [CaseNode.Pattern.SubPattern, BindExprStr]);
    end;
  end
  else if Pos('Err', PatStr) = 1 then
  begin
    if (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
    begin
      if CaseNode.Pattern.IsLet then
      begin
        CondStr := Format('%s.is_err', [ExprStr]);
        SplitResultTypes(MatchedType, ValF, ErrF);
        BindVarType := ErrF;
        if ResolveAliasType(ErrF) = 'String' then
          BindExprStr := ExprStr + '.err_str'
        else
          BindExprStr := Format('%s(%s.error)', [EmitTypeRef(ErrF), ExprStr]);
        BindStmt := Format('%s := %s;', [CaseNode.Pattern.SubPattern, BindExprStr]);
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
    if IsValueOptionType(MatchedType) then
    begin
      CondStr := Format('%s.is_some', [ExprStr]);
      if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
      begin
        ValF := Trim(Copy(MatchedType, 8, Length(MatchedType) - 8));
        BindVarType := ValF;
        BindExprStr := EmitMonadFieldExtract(ExprStr, ValF, 'num_val', 'str_val');
        BindStmt := Format('%s := %s;', [CaseNode.Pattern.SubPattern, BindExprStr]);
      end;
    end
    else
    begin
      CondStr := Format('(%s <> nil)', [ExprStr]);
      if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
      begin
        if Pos('Option<', MatchedType) = 1 then
          BindVarType := Trim(Copy(MatchedType, 8, Length(MatchedType) - 8));
        BindStmt := Format('%s := %s;', [CaseNode.Pattern.SubPattern, ExprStr]);
      end;
    end;
  end
  else if (CaseNode.Pattern.Items.Count <= 1) and (PatStr = 'None') then
  begin
    if IsValueOptionType(MatchedType) then
      CondStr := Format('%s.is_none', [ExprStr])
    else
      CondStr := Format('(%s = nil)', [ExprStr]);
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
    if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
    begin
      FGuardBindName := CaseNode.Pattern.SubPattern;
      FGuardBindExpr := BindExprStr;
    end;
    GuardStr := EmitExpr(CaseNode.Guard);
    FGuardBindName := '';
    FGuardBindExpr := '';
    if CondStr = '' then
      CondStr := GuardStr
    else
      CondStr := Format('((%s) and (%s))', [CondStr, GuardStr]);
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
  I, J: Integer;
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
      end;
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
    Emit('break;');
  end
  else if Stmt is TASTContinueStmt then
  begin
    if FActiveDefers.Count > FLoopDeferBase then
      EmitActiveDefers(FLoopDeferBase);
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
    if (FActiveDefers.Count > 0) or (Assigned(FCurrentFunc) and (FCurrentFunc.Ensures.Count > 0)) then
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
            Emit(Format('Assert(%s, ''Violacao de pos-condicao (ensure) na funcao %s'');',
              [EmitExpr(TASTExpr(FCurrentFunc.Ensures[J])), FCurrentFunc.Name]));
        Emit('Exit(Result);');
      end
      else
      begin
        if FActiveDefers.Count > 0 then
          EmitActiveDefers(0);
        if Assigned(FCurrentFunc) then
          for J := 0 to FCurrentFunc.Ensures.Count - 1 do
            Emit(Format('Assert(%s, ''Violacao de pos-condicao (ensure) na funcao %s'');',
              [EmitExpr(TASTExpr(FCurrentFunc.Ensures[J])), FCurrentFunc.Name]));
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
    ExprStr := EmitExpr(MatchStmt.Expr);
    MatchedType := ResolveAliasType(GetExprTypeName(MatchStmt.Expr));
    Emit('// Match gerado pelo compilador Aether');
    OldBindName := FMatchBindName;
    OldBindType := FMatchBindType;
    for I := 0 to MatchStmt.Cases.Count - 1 do
    begin
      CaseNode := TASTMatchCase(MatchStmt.Cases[I]);
      BuildMatchCaseCond(CaseNode, ExprStr, MatchedType, CondStr, BindStmt, BindVarT, IsWild);
      if IsWild then
      begin
        if I > 0 then Emit('else');
        Emit('begin');
        IncIndent;
        if BindStmt <> '' then Emit(BindStmt);
        if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
        begin
          FMatchBindName := CaseNode.Pattern.SubPattern;
          FMatchBindType := BindVarT;
        end;
        for J := 0 to CaseNode.Body.Count - 1 do
          EmitStmt(TASTStmt(CaseNode.Body[J]));
        FMatchBindName := OldBindName;
        FMatchBindType := OldBindType;
        DecIndent;
      end
      else
      begin
        if I = 0 then Prefix := 'if ' else Prefix := 'else if ';
        if CondStr = '' then CondStr := 'True';
        Emit(Prefix + CondStr + ' then');
        Emit('begin');
        IncIndent;
        if BindStmt <> '' then Emit(BindStmt);
        if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
        begin
          FMatchBindName := CaseNode.Pattern.SubPattern;
          FMatchBindType := BindVarT;
        end;
        for J := 0 to CaseNode.Body.Count - 1 do
          EmitStmt(TASTStmt(CaseNode.Body[J]));
        FMatchBindName := OldBindName;
        FMatchBindType := OldBindType;
        DecIndent;
      end;

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
  I: Integer;
  VariantName: string;
begin
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
    Emit(Format('T%s = %s;', [Arr.Name, EmitTypeRef('array of ' + Arr.ElemType)]));
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
  ParamType: string;
  SkipNames, AutoNames, AutoTypes: TStringList;
begin
  if Func.GenericParam <> '' then Exit; // Molde generico nao emite codigo diretamente
  FCurrentFunc := Func;
  if Func.IsExtern then
  begin
    if Func.ExternAbi = 'pascal' then
    begin
      Emit(Format('// Extern Pascal: %s (fornecido por unit FPC)', [Func.Name]));
      Emit('');
      Exit;
    end;

    // Funcoes padrao de C math mapeadas diretamente para Math do FPC
    if (Func.ExternAbi = 'c') and ((Func.Name = 'sin') or (Func.Name = 'cos') or (Func.Name = 'sqrt') or
       (Func.Name = 'tan') or (Func.Name = 'abs') or (Func.Name = 'floor') or (Func.Name = 'ceil')) then
    begin
      Emit(Format('// Extern C Math: %s (fornecido nativamente por System/Math FPC)', [Func.Name]));
      Emit('');
      Exit;
    end;

    if Func.ExternLib <> '' then
      LibClause := Format(' external ''%s'';', [Func.ExternLib])
    else
      LibClause := ' external ''msvcrt'';'; // C runtime padrao no Windows/FPC

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

  // Variaveis Locais
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
    end;
  end;

  // Verificacao de Contratos require em tempo de execucao (Asserts)
  for I := 0 to Func.Requires.Count - 1 do
  begin
    Emit(Format('Assert(%s, ''Violacao de pre-condicao (require) na funcao %s'');', [EmitExpr(TASTExpr(Func.Requires[I])), Func.Name]));
  end;

  // Corpo
  FActiveDefers.Clear;
  FLoopDeferBase := 0;
  EmitStmtList(Func.Body);
  FActiveDefers.Clear;

  if (Func.Ensures.Count > 0) and ((Func.Body.Count = 0) or not (Func.Body[Func.Body.Count - 1] is TASTReturnStmt)) then
  begin
    for I := 0 to Func.Ensures.Count - 1 do
      Emit(Format('Assert(%s, ''Violacao de pos-condicao (ensure) na funcao %s'');',
        [EmitExpr(TASTExpr(Func.Ensures[I])), Func.Name]));
  end;

  DecIndent;
  Emit('end;');
  Emit('');
end;

procedure TAetherEmitterPascal.EmitProgramBlock(Prog: TASTProgramBlock);
var
  I: Integer;
  VarDecl: TASTVarDecl;
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
    end;
  end;
  FActiveDefers.Clear;
  FLoopDeferBase := 0;
  EmitStmtList(Prog.Body);
  FActiveDefers.Clear;
  DecIndent;
  Emit('end.');
end;

function TAetherEmitterPascal.BuildFuncSig(Func: TASTFunction): string;
var
  J: Integer;
  Param: TASTParam;
  ParamListStr, ModStr, LibClause, ParamType, ExportClause: string;
begin
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

procedure TAetherEmitterPascal.EmitRuntimeHelpersInterface;
begin
  Emit('function AetherOk(const V: Double): TResultDoubleError; overload;');
  Emit('function AetherOk(const V: String): TResultDoubleError; overload;');
  Emit('function AetherOk(const V: Boolean): TResultDoubleError; overload;');
  Emit('function AetherErr(const E: Integer): TResultDoubleError; overload;');
  Emit('function AetherErr(const E: String): TResultDoubleError; overload;');
  Emit('function AetherSome(const V: Double): TAetherOption; overload;');
  Emit('function AetherSome(const V: String): TAetherOption; overload;');
  Emit('function AetherSome(const V: Boolean): TAetherOption; overload;');
  Emit('function AetherNone(): TAetherOption;');
  Emit('function AetherDynPop_Int8(var A: TAetherDyn_Int8): Int8;');
  Emit('function AetherDynPop_Int16(var A: TAetherDyn_Int16): Int16;');
  Emit('function AetherDynPop_Int32(var A: TAetherDyn_Int32): Int32;');
  Emit('function AetherDynPop_Int64(var A: TAetherDyn_Int64): Int64;');
  Emit('function AetherDynPop_UInt8(var A: TAetherDyn_UInt8): UInt8;');
  Emit('function AetherDynPop_UInt16(var A: TAetherDyn_UInt16): UInt16;');
  Emit('function AetherDynPop_UInt32(var A: TAetherDyn_UInt32): UInt32;');
  Emit('function AetherDynPop_UInt64(var A: TAetherDyn_UInt64): UInt64;');
  Emit('function AetherDynPop_Float32(var A: TAetherDyn_Float32): Single;');
  Emit('function AetherDynPop_Float64(var A: TAetherDyn_Float64): Double;');
  Emit('function AetherDynPop_Bool(var A: TAetherDyn_Bool): Boolean;');
  Emit('function AetherDynPop_Char(var A: TAetherDyn_Char): Char;');
  Emit('function AetherDynPop_String(var A: TAetherDyn_String): String;');
  Emit('function AetherDynPop_Pointer(var A: TAetherDyn_Pointer): Pointer;');
  Emit('function AetherCharAt(const S: string; Index: Cardinal): string;');
  Emit('function AetherSubstring(const S: string; Start, Len: Cardinal): string;');
  Emit('generic function AetherIfThen<T>(Cond: Boolean; const A, B: T): T;');
  Emit('generic function AetherMin<T>(const A, B: T): T;');
  Emit('generic function AetherMax<T>(const A, B: T): T;');
  Emit('generic function AetherClamp<T>(const V, Lo, Hi: T): T;');
  Emit('function AetherStrTrim(const S: string): string;');
  Emit('function AetherUpperCase(const S: string): string;');
  Emit('function AetherLowerCase(const S: string): string;');
  Emit('function AetherStartsWith(const S, Prefix: string): Boolean;');
  Emit('function AetherEndsWith(const S, Suffix: string): Boolean;');
  Emit('function AetherStrContains(const S, Sub: string): Boolean;');
  Emit('function AetherIndexOf(const S, Sub: string): Int32;');
  Emit('function AetherStrReplace(const S, OldStr, NewStr: string): string;');
  Emit('function AetherFileExists(const APath: string): Boolean;');
  Emit('function AetherReadFile(const APath: string): string;');
  Emit('function AetherWriteFile(const APath: string; const AContent: string): Boolean;');
  Emit('function AetherCreateDir(const APath: string): Boolean;');
  Emit('function AetherRemoveDir(const APath: string): Boolean;');
  Emit('function AetherDeleteFile(const APath: string): Boolean;');
  Emit('function AetherDirExists(const APath: string): Boolean;');
  Emit('function AetherFileSize(const APath: string): {$IFDEF PAS2JS}NativeInt{$ELSE}Int64{$ENDIF};');
  Emit('function AetherBoolToStr(B: Boolean): string;');
  Emit('function AetherFloatToStr(AVal: Double): string;');
  Emit('function AetherJsonExtractRaw(const Json, Key: string): string;');
  Emit('function AetherJsonGetStr(const Json, Key: string): string;');
  Emit('function AetherJsonGetInt(const Json, Key: string): Int32;');
  Emit('function AetherJsonGetFloat(const Json, Key: string): Double;');
  Emit('function AetherJsonGetBool(const Json, Key: string): Boolean;');
  Emit('function AetherJsonGetChar(const Json, Key: string): Char;');
  Emit('function AetherJsonHasValue(const Json, Key: string): Boolean;');
  Emit('function AetherJsonGetObj(const Json, Key: string): string;');
  Emit('function AetherGetNanoseconds: {$IFDEF PAS2JS}Double{$ELSE}QWord{$ENDIF};');
  Emit('procedure AetherSleepMs(AMs: Cardinal);');
  Emit('function AetherSocketCreate(): LongInt;');
  Emit('function AetherSocketListen(Port: Word; Backlog: LongInt): LongInt;');
  Emit('function AetherSocketAccept(ListenFd: LongInt): LongInt;');
  Emit('function AetherSocketConnect(const Host: String; Port: Word): LongInt;');
  Emit('function AetherSocketSend(Fd: LongInt; const Data: String): LongInt;');
  Emit('function AetherSocketRecv(Fd: LongInt; MaxLen: LongInt): String;');
  Emit('procedure AetherSocketClose(Fd: LongInt);');
  Emit('');
end;

procedure TAetherEmitterPascal.EmitRuntimeHelpersImplementation;
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
  Emit('function AetherDynPop_Int8(var A: TAetherDyn_Int8): Int8; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;');
  Emit('function AetherDynPop_Int16(var A: TAetherDyn_Int16): Int16; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;');
  Emit('function AetherDynPop_Int32(var A: TAetherDyn_Int32): Int32; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;');
  Emit('function AetherDynPop_Int64(var A: TAetherDyn_Int64): Int64; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;');
  Emit('function AetherDynPop_UInt8(var A: TAetherDyn_UInt8): UInt8; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;');
  Emit('function AetherDynPop_UInt16(var A: TAetherDyn_UInt16): UInt16; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;');
  Emit('function AetherDynPop_UInt32(var A: TAetherDyn_UInt32): UInt32; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;');
  Emit('function AetherDynPop_UInt64(var A: TAetherDyn_UInt64): UInt64; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;');
  Emit('function AetherDynPop_Float32(var A: TAetherDyn_Float32): Single; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;');
  Emit('function AetherDynPop_Float64(var A: TAetherDyn_Float64): Double; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;');
  Emit('function AetherDynPop_Bool(var A: TAetherDyn_Bool): Boolean; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;');
  Emit('function AetherDynPop_Char(var A: TAetherDyn_Char): Char; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;');
  Emit('function AetherDynPop_String(var A: TAetherDyn_String): String; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;');
  Emit('function AetherDynPop_Pointer(var A: TAetherDyn_Pointer): Pointer; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;');
  Emit('');
  Emit('generic function AetherIfThen<T>(Cond: Boolean; const A, B: T): T;');
  Emit('begin');
  Emit('  if Cond then Result := A else Result := B;');
  Emit('end;');
  Emit('');
  Emit('generic function AetherMin<T>(const A, B: T): T;');
  Emit('begin');
  Emit('  if A < B then Result := A else Result := B;');
  Emit('end;');
  Emit('');
  Emit('generic function AetherMax<T>(const A, B: T): T;');
  Emit('begin');
  Emit('  if A > B then Result := A else Result := B;');
  Emit('end;');
  Emit('');
  Emit('generic function AetherClamp<T>(const V, Lo, Hi: T): T;');
  Emit('begin');
  Emit('  if V < Lo then Result := Lo else if V > Hi then Result := Hi else Result := V;');
  Emit('end;');
  Emit('');
  Emit('function AetherStrTrim(const S: string): string;');
  Emit('begin');
  Emit('  Result := SysUtils.Trim(S);');
  Emit('end;');
  Emit('');
  Emit('function AetherUpperCase(const S: string): string;');
  Emit('begin');
  Emit('  Result := SysUtils.UpperCase(S);');
  Emit('end;');
  Emit('');
  Emit('function AetherLowerCase(const S: string): string;');
  Emit('begin');
  Emit('  Result := SysUtils.LowerCase(S);');
  Emit('end;');
  Emit('');
  Emit('function AetherStartsWith(const S, Prefix: string): Boolean;');
  Emit('begin');
  Emit('  Result := (Length(Prefix) <= Length(S)) and (Copy(S, 1, Length(Prefix)) = Prefix);');
  Emit('end;');
  Emit('');
  Emit('function AetherEndsWith(const S, Suffix: string): Boolean;');
  Emit('begin');
  Emit('  Result := (Length(Suffix) <= Length(S)) and (Copy(S, Length(S) - Length(Suffix) + 1, Length(Suffix)) = Suffix);');
  Emit('end;');
  Emit('');
  Emit('function AetherStrContains(const S, Sub: string): Boolean;');
  Emit('begin');
  Emit('  if Sub = '''' then Exit(True);');
  Emit('  Result := Pos(Sub, S) > 0;');
  Emit('end;');
  Emit('');
  Emit('function AetherIndexOf(const S, Sub: string): Int32;');
  Emit('begin');
  Emit('  if Sub = '''' then Exit(0);');
  Emit('  Result := Int32(Pos(Sub, S)) - 1;');
  Emit('end;');
  Emit('');
  Emit('function AetherStrReplace(const S, OldStr, NewStr: string): string;');
  Emit('begin');
  Emit('  if OldStr = '''' then Exit(S);');
  Emit('  Result := SysUtils.StringReplace(S, OldStr, NewStr, [rfReplaceAll]);');
  Emit('end;');
  Emit('');
  Emit('function AetherCharAt(const S: string; Index: Cardinal): string;');
  Emit('begin');
  Emit('  if (Index + 1 <= Cardinal(Length(S))) then Result := S[Index + 1] else Result := '''';');
  Emit('end;');
  Emit('');
  Emit('function AetherSubstring(const S: string; Start, Len: Cardinal): string;');
  Emit('begin');
  Emit('  Result := Copy(S, Start + 1, Len);');
  Emit('end;');
  Emit('');
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
  Emit('{$ELSE}');
  Emit('function AetherFileExists(const APath: string): Boolean; begin Result := False; end;');
  Emit('function AetherReadFile(const APath: string): string; begin Result := ''''; end;');
  Emit('function AetherWriteFile(const APath: string; const AContent: string): Boolean; begin Result := False; end;');
  Emit('function AetherCreateDir(const APath: string): Boolean; begin Result := False; end;');
  Emit('function AetherRemoveDir(const APath: string): Boolean; begin Result := False; end;');
  Emit('function AetherDeleteFile(const APath: string): Boolean; begin Result := False; end;');
  Emit('function AetherDirExists(const APath: string): Boolean; begin Result := False; end;');
  Emit('function AetherFileSize(const APath: string): {$IFDEF PAS2JS}NativeInt{$ELSE}Int64{$ENDIF}; begin Result := -1; end;');
  Emit('{$ENDIF}');
  Emit('');
  Emit('function AetherBoolToStr(B: Boolean): string;');
  Emit('begin if B then Result := ''true'' else Result := ''false''; end;');
  Emit('');
  Emit('function AetherFloatToStr(AVal: Double): string;');
  Emit('var FS: TFormatSettings;');
  Emit('begin');
  Emit('  FS := DefaultFormatSettings;');
  Emit('  FS.DecimalSeparator := ''.'';');
  Emit('  Result := FloatToStr(AVal, FS);');
  Emit('end;');
  Emit('');
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
  Emit('procedure AetherSleepMs(AMs: Cardinal);');
  Emit('{$IFDEF PAS2JS}');
  Emit('begin end;');
  Emit('{$ELSE}');
  Emit('begin SysUtils.Sleep(AMs); end;');
  Emit('{$ENDIF}');
  Emit('');
  Emit('{$IFNDEF PAS2JS}');
  Emit('// Sockets Nativos via Sockets FPC');
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

function TAetherEmitterPascal.Generate(AModule: TASTModule; AsUnit: Boolean = False; AsLibrary: Boolean = False): string;
var
  I, ExportCount, CurExp: Integer;
  UsesClause, Sig: string;
  Func: TASTFunction;
  Rec: TASTRecordDecl;
  ConstDecl: TASTConstDecl;
  EffectiveLibrary: Boolean;
  MapTags, MapKeys, MapVals: TStringList;
begin
  FModule := AModule;
  FOutput.Clear;
  FIndent := 0;
  MapTags := TStringList.Create;
  MapKeys := TStringList.Create;
  MapVals := TStringList.Create;
  try
  CollectMapsFromModule(AModule, MapTags, MapKeys, MapVals);

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

  UsesClause := '  SysUtils, Math{$IFNDEF PAS2JS}, Sockets{$IFDEF WINDOWS}, Windows{$ENDIF}{$ENDIF}';
  for I := 0 to AModule.PascalImports.Count - 1 do
  begin
    if Pos(LowerCase(AModule.PascalImports[I]), LowerCase(UsesClause)) = 0 then
      UsesClause := UsesClause + ', ' + AModule.PascalImports[I];
  end;
  UsesClause := UsesClause + ';';

  if AsUnit then
  begin
    Emit('// Codigo gerado automaticamente pelo Compilador Aether (aetherc)');
    Emit('// Alvo: Object Pascal Unit (Free Pascal / BlaiseVue)');
    Emit('unit ' + AModule.Name + ';');
    Emit('');
    Emit('{$mode objfpc}{$H+}{$assertions on}');
    Emit('');
    Emit('interface');
    Emit('');
    Emit('uses');
    Emit(UsesClause);
    Emit('');

    Emit('// --- Aether Runtime Helpers & Monads ---');
    Emit('type');
    Emit('  Float64 = Double;');
    Emit('  Float32 = Single;');
    Emit('  PAetherPtr_Int8 = ^Int8; PAetherPtr_Int16 = ^Int16; PAetherPtr_Int32 = ^Int32; PAetherPtr_Int64 = ^Int64;');
    Emit('  PAetherPtr_UInt8 = ^UInt8; PAetherPtr_UInt16 = ^UInt16; PAetherPtr_UInt32 = ^UInt32; PAetherPtr_UInt64 = ^UInt64;');
    Emit('  PAetherPtr_Float32 = ^Single; PAetherPtr_Float64 = ^Double; PAetherPtr_Bool = ^Boolean; PAetherPtr_Char = ^Char; PAetherPtr_String = ^String;');
    Emit('  TAetherDyn_Int8 = array of Int8; TAetherDyn_Int16 = array of Int16; TAetherDyn_Int32 = array of Int32; TAetherDyn_Int64 = array of Int64;');
    Emit('  TAetherDyn_UInt8 = array of UInt8; TAetherDyn_UInt16 = array of UInt16; TAetherDyn_UInt32 = array of UInt32; TAetherDyn_UInt64 = array of UInt64;');
    Emit('  TAetherDyn_Float32 = array of Single; TAetherDyn_Float64 = array of Double; TAetherDyn_Bool = array of Boolean; TAetherDyn_Char = array of Char;');
    Emit('  TAetherDyn_String = array of String; TAetherDyn_Pointer = array of Pointer;');
    Emit('  generic TAetherResult<TVal, TErr> = record');
    Emit('    is_ok: Boolean;');
    Emit('    is_err: Boolean;');
    Emit('    value: TVal;');
    Emit('    error: TErr;');
    Emit('    str_val: String;');
    Emit('    err_str: String;');
    Emit('  end;');
    Emit('');
    Emit('type');
    Emit('  generic TAetherTask<TVal> = record');
    Emit('    is_completed: Boolean;');
    Emit('    value: TVal;');
    Emit('  end;');
    Emit('');
    Emit('type');
    Emit('  TResultDoubleError = specialize TAetherResult<Double, Integer>;');
    Emit('  TAetherOption = record');
    Emit('    is_some: Boolean;');
    Emit('    is_none: Boolean;');
    Emit('    num_val: Double;');
    Emit('    str_val: String;');
    Emit('  end;');
    EmitMapRuntimeDecls(MapTags, MapKeys, MapVals, True);
    Emit('');

    if AModule.Constants.Count > 0 then
    begin
      Emit('const');
      IncIndent;
      for I := 0 to AModule.Constants.Count - 1 do
      begin
        ConstDecl := TASTConstDecl(AModule.Constants[I]);
        if ConstDecl.DeclaredType <> '' then
          Emit(Format('%s: %s = %s;', [ConstDecl.Name, EmitTypeRef(ConstDecl.DeclaredType), EmitExpr(ConstDecl.ValueExpr)]))
        else
          Emit(Format('%s = %s;', [ConstDecl.Name, EmitExpr(ConstDecl.ValueExpr)]));
      end;
      DecIndent;
      Emit('');
    end;

    if AModule.Types.Count > 0 then
    begin
      Emit('type');
      IncIndent;
      for I := 0 to AModule.Types.Count - 1 do
      begin
        if AModule.Types[I] is TASTRecordDecl then
        begin
          Emit(Format('P%s = ^T%s;', [TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name]));
          Emit(Format('PT%s = ^T%s;', [TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name]));
        end;
      end;

      for I := 0 to AModule.Types.Count - 1 do
      begin
        if AModule.Types[I] is TASTRecordDecl then
          EmitRecordType(TASTRecordDecl(AModule.Types[I]))
        else if AModule.Types[I] is TASTEnumDecl then
          EmitEnumDecl(TASTEnumDecl(AModule.Types[I]))
        else if AModule.Types[I] is TASTArrayDecl then
          EmitArrayDecl(TASTArrayDecl(AModule.Types[I]))
        else if AModule.Types[I] is TASTSetDecl then
          EmitSetDecl(TASTSetDecl(AModule.Types[I]))
        else if AModule.Types[I] is TASTSubrangeDecl then
          EmitSubrangeDecl(TASTSubrangeDecl(AModule.Types[I]))
        else if AModule.Types[I] is TASTTypeAliasDecl then
          EmitTypeAliasDecl(TASTTypeAliasDecl(AModule.Types[I]));
      end;
      EmitMapRuntimeDecls(MapTags, MapKeys, MapVals, False);
      for I := 0 to AModule.Types.Count - 1 do
        if AModule.Types[I] is TASTMapDecl then
          EmitMapDecl(TASTMapDecl(AModule.Types[I]));
      DecIndent;
      Emit('');

      for I := 0 to AModule.Types.Count - 1 do
      begin
        if AModule.Types[I] is TASTRecordDecl then
        begin
          Rec := TASTRecordDecl(AModule.Types[I]);
          Emit(BuildRecordConstructorSig(Rec));
          Emit(Format('function AetherBox(const V: T%s): P%s;', [Rec.Name, Rec.Name]));
        end;
      end;
      Emit('');
    end;

    EmitRuntimeHelpersInterface;
    EmitMapRuntimeHelpers(MapTags, MapKeys, MapVals, True);

    for I := 0 to AModule.Functions.Count - 1 do
    begin
      Func := TASTFunction(AModule.Functions[I]);
      if (not Func.IsExtern) and (Func.GenericParam = '') then
      begin
        Sig := BuildFuncSig(Func);
        if Sig <> '' then
          Emit(Sig);
      end;
    end;
    Emit('');

    Emit('implementation');
    Emit('');

    if AModule.Types.Count > 0 then
    begin
      for I := 0 to AModule.Types.Count - 1 do
      begin
        if AModule.Types[I] is TASTRecordDecl then
        begin
          EmitRecordConstructor(TASTRecordDecl(AModule.Types[I]));
          Emit(Format('function AetherBox(const V: T%s): P%s;', [TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name]));
          Emit('begin');
          Emit('  New(Result);');
          Emit('  Result^ := V;');
          Emit('end;');
          Emit('');
        end;
      end;
    end;

    EmitRuntimeHelpersImplementation;
    EmitMapRuntimeHelpers(MapTags, MapKeys, MapVals, False);

    for I := 0 to AModule.Functions.Count - 1 do
      EmitFunction(TASTFunction(AModule.Functions[I]));

    if Assigned(AModule.ProgramBlock) then
    begin
      Emit('');
      Emit('initialization');
      IncIndent;
      for I := 0 to AModule.ProgramBlock.Body.Count - 1 do
        EmitStmt(TASTStmt(AModule.ProgramBlock.Body[I]));
      DecIndent;
    end;

    Emit('end.');
  end
  else
  begin
    Emit('// Codigo gerado automaticamente pelo Compilador Aether (aetherc)');
    Emit('// Alvo: Object Pascal (Free Pascal)');
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

    Emit('// --- Aether Runtime Helpers ---');
    Emit('type');
    Emit('  Float64 = Double;');
    Emit('  Float32 = Single;');
    Emit('  PAetherPtr_Int8 = ^Int8; PAetherPtr_Int16 = ^Int16; PAetherPtr_Int32 = ^Int32; PAetherPtr_Int64 = ^Int64;');
    Emit('  PAetherPtr_UInt8 = ^UInt8; PAetherPtr_UInt16 = ^UInt16; PAetherPtr_UInt32 = ^UInt32; PAetherPtr_UInt64 = ^UInt64;');
    Emit('  PAetherPtr_Float32 = ^Single; PAetherPtr_Float64 = ^Double; PAetherPtr_Bool = ^Boolean; PAetherPtr_Char = ^Char; PAetherPtr_String = ^String;');
    Emit('  TAetherDyn_Int8 = array of Int8; TAetherDyn_Int16 = array of Int16; TAetherDyn_Int32 = array of Int32; TAetherDyn_Int64 = array of Int64;');
    Emit('  TAetherDyn_UInt8 = array of UInt8; TAetherDyn_UInt16 = array of UInt16; TAetherDyn_UInt32 = array of UInt32; TAetherDyn_UInt64 = array of UInt64;');
    Emit('  TAetherDyn_Float32 = array of Single; TAetherDyn_Float64 = array of Double; TAetherDyn_Bool = array of Boolean; TAetherDyn_Char = array of Char;');
    Emit('  TAetherDyn_String = array of String; TAetherDyn_Pointer = array of Pointer;');
    Emit('  generic TAetherResult<TVal, TErr> = record');
    Emit('    is_ok: Boolean;');
    Emit('    is_err: Boolean;');
    Emit('    value: TVal;');
    Emit('    error: TErr;');
    Emit('    str_val: String;');
    Emit('    err_str: String;');
    Emit('  end;');
    Emit('');
    Emit('type');
    Emit('  generic TAetherTask<TVal> = record');
    Emit('    is_completed: Boolean;');
    Emit('    value: TVal;');
    Emit('  end;');
    Emit('');
    Emit('type');
    Emit('  TResultDoubleError = specialize TAetherResult<Double, Integer>;');
    Emit('  TAetherOption = record');
    Emit('    is_some: Boolean;');
    Emit('    is_none: Boolean;');
    Emit('    num_val: Double;');
    Emit('    str_val: String;');
    Emit('  end;');
    EmitMapRuntimeDecls(MapTags, MapKeys, MapVals, True);
    Emit('');

    if AModule.Constants.Count > 0 then
    begin
      Emit('const');
      IncIndent;
      for I := 0 to AModule.Constants.Count - 1 do
      begin
        ConstDecl := TASTConstDecl(AModule.Constants[I]);
        if ConstDecl.DeclaredType <> '' then
          Emit(Format('%s: %s = %s;', [ConstDecl.Name, EmitTypeRef(ConstDecl.DeclaredType), EmitExpr(ConstDecl.ValueExpr)]))
        else
          Emit(Format('%s = %s;', [ConstDecl.Name, EmitExpr(ConstDecl.ValueExpr)]));
      end;
      DecIndent;
      Emit('');
    end;

    if AModule.Types.Count > 0 then
    begin
      Emit('type');
      IncIndent;
      for I := 0 to AModule.Types.Count - 1 do
      begin
        if AModule.Types[I] is TASTRecordDecl then
        begin
          Emit(Format('P%s = ^T%s;', [TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name]));
          Emit(Format('PT%s = ^T%s;', [TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name]));
        end;
      end;

      for I := 0 to AModule.Types.Count - 1 do
      begin
        if AModule.Types[I] is TASTRecordDecl then
          EmitRecordType(TASTRecordDecl(AModule.Types[I]))
        else if AModule.Types[I] is TASTEnumDecl then
          EmitEnumDecl(TASTEnumDecl(AModule.Types[I]))
        else if AModule.Types[I] is TASTArrayDecl then
          EmitArrayDecl(TASTArrayDecl(AModule.Types[I]))
        else if AModule.Types[I] is TASTSetDecl then
          EmitSetDecl(TASTSetDecl(AModule.Types[I]))
        else if AModule.Types[I] is TASTSubrangeDecl then
          EmitSubrangeDecl(TASTSubrangeDecl(AModule.Types[I]))
        else if AModule.Types[I] is TASTTypeAliasDecl then
          EmitTypeAliasDecl(TASTTypeAliasDecl(AModule.Types[I]));
      end;
      EmitMapRuntimeDecls(MapTags, MapKeys, MapVals, False);
      for I := 0 to AModule.Types.Count - 1 do
        if AModule.Types[I] is TASTMapDecl then
          EmitMapDecl(TASTMapDecl(AModule.Types[I]));
      DecIndent;
      Emit('');

      for I := 0 to AModule.Types.Count - 1 do
      begin
        if AModule.Types[I] is TASTRecordDecl then
        begin
          EmitRecordConstructor(TASTRecordDecl(AModule.Types[I]));
          Emit(Format('function AetherBox(const V: T%s): P%s; overload;', [TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name]));
          Emit('begin');
          Emit('  New(Result);');
          Emit('  Result^ := V;');
          Emit('end;');
          Emit('');
        end;
      end;
    end;

    EmitRuntimeHelpersImplementation;
    EmitMapRuntimeHelpers(MapTags, MapKeys, MapVals, False);

    for I := 0 to AModule.Functions.Count - 1 do
    begin
      Func := TASTFunction(AModule.Functions[I]);
      if (not Func.IsExtern) and (Func.GenericParam = '') and (Func.InlineMode <> 'always') then
      begin
        Sig := BuildFuncSig(Func);
        if Sig <> '' then
          Emit(Copy(Sig, 1, Length(Sig) - 1) + ' forward;');
      end;
    end;
    Emit('');

    for I := 0 to AModule.Functions.Count - 1 do
      EmitFunction(TASTFunction(AModule.Functions[I]));

    if EffectiveLibrary then
    begin
      ExportCount := 0;
      for I := 0 to AModule.Functions.Count - 1 do
        if TASTFunction(AModule.Functions[I]).IsExport then Inc(ExportCount);

      if ExportCount > 0 then
      begin
        Emit('');
        Emit('exports');
        IncIndent;
        CurExp := 0;
        for I := 0 to AModule.Functions.Count - 1 do
        begin
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
    MapTags.Free;
    MapKeys.Free;
    MapVals.Free;
  end;
end;

end.
