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
    FTryDepth: Integer;
    FLoopCounter: Integer;

    procedure Emit(const Line: string = '');
    procedure IncIndent;
    procedure DecIndent;
    function IndentStr: string;
    procedure EmitActiveDefers(DownToIndex: Integer = 0);
    procedure EmitStmtList(List: TASTNodeList; IsLoopBody: Boolean = False);

    function IsEnumName(const AName: string): Boolean;
    function ResolveAliasType(const AType: string): string;
    function IsSetType(const AName: string): Boolean;
    function IsDynamicArrayType(const AName: string): Boolean;
    function IsValueOptionType(const AType: string): Boolean;
    function SplitResultTypes(const AType: string; out ValType, ErrType: string): Boolean;
    function IsTypeIdentifier(const AName: string): Boolean;
    function EmitMonadFieldExtract(const ExprStr, FieldType, NumField, StrField: string): string;
    procedure EmitArrayLiteralAssign(const TargetStr, TargetType: string; SetLit: TASTSetLiteralExpr);
    function IsMapType(const AType: string; out KeyType, ValType: string): Boolean;
    function MapTag(const K, V: string): string;
    function NormalizeIntLit(const Val: string): string;
    function IsIntCType(const AType: string): Boolean;
    function GetCollectionElemType(Expr: TASTExpr): string;
    function IsBuiltinMapSideType(const AType: string): Boolean;
    procedure CollectAutoForVars(Stmts: TASTNodeList; VarNames, VarTypes: TStrings; const SkipNames: TStrings);
    procedure CollectMapsFromType(const AType: string; Tags, Keys, Vals: TStrings);
    procedure CollectMapsFromModule(AModule: TASTModule; Tags, Keys, Vals: TStrings);
    procedure EmitMapRuntimeDecls(Tags, Keys, Vals: TStrings; BuiltinOnly: Boolean);
    procedure EmitMapRuntimeHelpers(Tags, Keys, Vals: TStrings);
    function IsVarModifiedInTry(const AVarName: string; Nodes: TASTNodeList; InTry: Boolean = False): Boolean;
    function IsMutBorrowParam(const AName: string): Boolean;
    function FindFunction(const AName: string): TASTFunction;
    function EscapeCString(const S: string): string;
    function GetExprTypeName(Expr: TASTExpr): string;
    function IsPointerTarget(Expr: TASTExpr): Boolean;
    function FormatCArrayVar(const AType, AName: string): string;

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
  FTryDepth := 0;
  FLoopCounter := 0;
end;

destructor TAetherEmitterC.Destroy;
begin
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
var
  I: Integer;
begin
  Result := False;
  if Assigned(FModule) then
    for I := 0 to FModule.Types.Count - 1 do
      if (TASTNode(FModule.Types[I]) is TASTEnumDecl) and
         SameText(TASTEnumDecl(FModule.Types[I]).Name, AName) then
        Exit(True);
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
  end;
  if Assigned(FProgramBlock) then
    for I := 0 to FProgramBlock.LocalVars.Count - 1 do
      if SameText(TASTVarDecl(FProgramBlock.LocalVars[I]).Name, AName) then Exit(False);
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
      #10: Result := Result + '\n';
      #13: Result := Result + '\r';
      #9:  Result := Result + '\t';
    else
      Result := Result + S[I];
    end;
  end;
  Result := Result + '"';
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
    CollectMapsFromType(Func.ReturnType, Tags, Keys, Vals);
    for J := 0 to Func.Params.Count - 1 do
      CollectMapsFromType(TASTParam(Func.Params[J]).TypeName, Tags, Keys, Vals);
    for J := 0 to Func.LocalVars.Count - 1 do
      CollectMapsFromType(TASTVarDecl(Func.LocalVars[J]).TypeName, Tags, Keys, Vals);
  end;
  if Assigned(AModule.ProgramBlock) then
    for I := 0 to AModule.ProgramBlock.LocalVars.Count - 1 do
      CollectMapsFromType(TASTVarDecl(AModule.ProgramBlock.LocalVars[I]).TypeName, Tags, Keys, Vals);
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
    end;
    if Assigned(FProgramBlock) then
    begin
      for I := 0 to FProgramBlock.LocalVars.Count - 1 do
      begin
        V := TASTVarDecl(FProgramBlock.LocalVars[I]);
        if SameText(V.Name, Id.Name) then Exit(V.TypeName);
      end;
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
        CleanTarget := Copy(CleanTarget, 5, Length(CleanTarget) - 5);
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
    if TASTUnaryExpr(Expr).Op = '@' then
      Exit('^' + TargetType)
    else if (TASTUnaryExpr(Expr).Op = '^') and (Pos('^', TargetType) = 1) then
      Exit(Copy(TargetType, 2, Length(TargetType)))
    else if SameText(TASTUnaryExpr(Expr).Op, 'not') or (TASTUnaryExpr(Expr).Op = '-') then
      Exit(TargetType);
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
    if Call.Callee = 'Some' then Exit('Option');
    if SameText(Call.Callee, 'Default') and (Call.Args.Count = 1) and (TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr) then
      Exit(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name);
    if (Call.Callee = 'ReadFile') or (Call.Callee = 'CharAt') or (Call.Callee = 'Substring') or (Call.Callee = 'ToString') or
       (Call.Callee = 'IntToStr') or (Call.Callee = 'FloatToStr') or (Call.Callee = 'BoolToStr') or (Call.Callee = 'CharToStr') or
       (Call.Callee = '__InterpToStr') or (Call.Callee = 'SocketRecv') or (Call.Callee = 'ParamStr') or
       SameText(Call.Callee, 'Trim') or SameText(Call.Callee, 'UpperCase') or SameText(Call.Callee, 'LowerCase') or SameText(Call.Callee, 'Replace') then Exit('String');
    if SameText(Call.Callee, 'Chr') or SameText(Call.Callee, 'Char') then Exit('Char');
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
  end
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
  Inner, Inner2: string;
  P1, P2: Integer;
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
  else if Pos('Result', AType) = 1 then Result := 'AetherResult'
  else if Pos('set of', AType) = 1 then Result := 'uint32_t'
  else if Pos('Box<', AType) > 0 then
  begin
    P1 := Pos('Box<', AType);
    Inner := Copy(AType, P1 + 4, Length(AType));
    P2 := Pos('>', Inner);
    if P2 > 0 then Inner := Copy(Inner, 1, P2 - 1);
    Result := 'P' + EmitTypeRef(Inner);
  end
  else if (Copy(AType, 1, 5) = 'Task<') and (AType[Length(AType)] = '>') then Result := 'AetherTask'
  else if Pos('Option<', AType) = 1 then
  begin
    if IsValueOptionType(AType) then
      Result := 'AetherOption'
    else
    begin
      Inner := Copy(AType, 8, Length(AType) - 8);
      Result := EmitTypeRef(Inner);
    end;
  end
  else if IsMapType(AType, Inner, Inner2) then
    Result := 'TAetherMap_' + MapTag(Inner, Inner2)
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
  I, J: Integer;
  OpStr, LType, RType, KeyT, ValT, TargetT, ValF, ErrF, ArgStr: string;
  TargetStr: string;
  ArgType: string;
  TName: string;
  Rec: TASTRecordDecl;
begin
  if not Assigned(Expr) then Exit('');

  if Expr is TASTLiteralExpr then
  begin
    Lit := TASTLiteralExpr(Expr);
    case Lit.Kind of
      lkInt:    Result := NormalizeIntLit(Lit.Value);
      lkString: Result := EscapeCString(Lit.Value);
      lkChar:   Result := '''' + Lit.Value + '''';
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
    if Assigned(FCurrentFunc) and SameText(Id.Name, 'result') then
      Result := 'result'
    else if Id.Name = '__ValueNone' then
      Result := '((AetherOption){ .is_some = false, .is_none = true, .num_val = 0, .str_val = "" })'
    else if Id.Name = 'None' then
      Result := 'NULL'
    else if IsMutBorrowParam(Id.Name) then
      Result := '(*' + Id.Name + ')'
    else
      Result := Id.Name;
    Exit;
  end;

  if Expr is TASTMemberAccessExpr then
  begin
    Acc := TASTMemberAccessExpr(Expr);
    TargetStr := EmitExpr(Acc.Target);
    TargetT := ResolveAliasType(GetExprTypeName(Acc.Target));
    if (Acc.Target is TASTIdentifierExpr) and IsEnumName(TASTIdentifierExpr(Acc.Target).Name) then
      Result := TASTIdentifierExpr(Acc.Target).Name + '_' + Acc.Member
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
    if OpStr = '@' then
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

  if Expr is TASTCallExpr then
  begin
    Call := TASTCallExpr(Expr);

    if (Call.Callee = 'PrintLn') or (Call.Callee = 'WriteLn') then
    begin
      if Call.Args.Count = 1 then
      begin
        ArgType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
        if (ArgType = 'Int32') or (ArgType = 'Int16') or (ArgType = 'Int8') or (ArgType = 'UInt16') or (ArgType = 'UInt8') then
          Result := 'printf("%d\n", ' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')'
        else if (ArgType = 'Int64') or (ArgType = 'UInt64') or (ArgType = 'UInt32') then
          Result := 'printf("%lld\n", (long long)(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))'
        else if (ArgType = 'Float64') or (ArgType = 'Float32') then
          Result := 'printf("%f\n", ' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')'
        else if (ArgType = 'Bool') then
          Result := 'printf("%s\n", (' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ') ? "true" : "false")'
        else if (ArgType = 'Char') then
          Result := 'printf("%c\n", ' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')'
        else
          Result := 'printf("%s\n", ' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      end
      else
      begin
        ArgsStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
        if (Length(ArgsStr) >= 2) and (ArgsStr[Length(ArgsStr)] = '"') then
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
      ArgType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
      ArgStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType = 'String' then
        Result := '((AetherResult){ .is_ok = true, .is_err = false, .str_val = ' + ArgStr + ' })'
      else
        Result := '((AetherResult){ .is_ok = true, .is_err = false, .value = (double)(' + ArgStr + ') })';
      Exit;
    end;

    if Call.Callee = 'Err' then
    begin
      ArgType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
      ArgStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType = 'String' then
        Result := '((AetherResult){ .is_ok = false, .is_err = true, .err_str = ' + ArgStr + ' })'
      else
        Result := '((AetherResult){ .is_ok = false, .is_err = true, .error = (int)(' + ArgStr + ') })';
      Exit;
    end;

    if Call.Callee = 'Some' then
    begin
      if IsPointerTarget(TASTCallArg(Call.Args[0]).Expr) then
        Result := EmitExpr(TASTCallArg(Call.Args[0]).Expr)
      else
      begin
        ArgType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr));
        ArgStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
        if ArgType = 'String' then
          Result := '((AetherOption){ .is_some = true, .is_none = false, .str_val = ' + ArgStr + ' })'
        else
          Result := '((AetherOption){ .is_some = true, .is_none = false, .num_val = (double)(' + ArgStr + ') })';
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

    if (Call.Args.Count = 1) and IsTypeIdentifier(Call.Callee) and not IsEnumName(Call.Callee) then
    begin
      Result := Format('((%s)(%s))', [EmitTypeRef(Call.Callee), EmitExpr(TASTCallArg(Call.Args[0]).Expr)]);
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

    // Typecast de tipos primitivos (ex: Int32(x), UInt32(x))
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

    // Construtor ou chamada normal
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
    Result := CalleeName + '(' + ArgsStr + ')';
    Exit;
  end
  else if Expr is TASTIfExpr then
  begin
    Result := Format('((%s) ? (%s) : (%s))',
      [EmitExpr(TASTIfExpr(Expr).Condition), EmitExpr(TASTIfExpr(Expr).ThenExpr), EmitExpr(TASTIfExpr(Expr).ElseExpr)]);
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

procedure TAetherEmitterC.EmitStmtList(List: TASTNodeList; IsLoopBody: Boolean);
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
  Lines: TStringList;
  LineStr: string;
  I, J, K, P2: Integer;
  PatStr, TName, KeyT, ValT, ColStr, ColType, ElemT, LoopId, MatchedType, ExprStr, Prefix, CondStr, BindStmt, TargetT, ValF, ErrF: string;
  PatItem, LoStr, HiStr, LoExpr, HiExpr, ItemCond: string;

  function FormatMatchAtom(const S, MT: string): string;
  begin
    if (Length(S) >= 2) and (S[1] = '''') then
      Result := S
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
  if Stmt is TASTAssignStmt then
  begin
    Assign := TASTAssignStmt(Stmt);
    TargetT := GetExprTypeName(Assign.Target);
    if (Assign.Expr is TASTSetLiteralExpr) and (not IsSetType(TargetT)) then
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
    if (FActiveDefers.Count > 0) or (Assigned(FCurrentFunc) and (FCurrentFunc.Ensures.Count > 0)) then
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
    ExprStr := EmitExpr(MatchStmt.Expr);
    MatchedType := ResolveAliasType(GetExprTypeName(MatchStmt.Expr));
    Emit('// Match gerado pelo compilador Aether');
    for I := 0 to MatchStmt.Cases.Count - 1 do
    begin
      CaseNode := TASTMatchCase(MatchStmt.Cases[I]);
      PatStr := CaseNode.Pattern.Value;
      if I = 0 then Prefix := 'if ('
      else Prefix := '} else if (';

      if PatStr = '_' then
      begin
        if I > 0 then
          Emit('} else {')
        else
          Emit('{');
        IncIndent;
        for J := 0 to CaseNode.Body.Count - 1 do
          EmitStmt(TASTStmt(CaseNode.Body[J]));
        DecIndent;
      end
      else
      begin
        BindStmt := '';
        if Pos('Ok', PatStr) = 1 then
        begin
          CondStr := Format('%s.is_ok', [ExprStr]);
          if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
          begin
            SplitResultTypes(MatchedType, ValF, ErrF);
            BindStmt := Format('%s %s = %s;', [EmitTypeRef(ValF), CaseNode.Pattern.SubPattern, EmitMonadFieldExtract(ExprStr, ValF, 'value', 'str_val')]);
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
              if ResolveAliasType(ErrF) = 'String' then
                BindStmt := Format('const char* %s = %s.err_str;', [CaseNode.Pattern.SubPattern, ExprStr])
              else
                BindStmt := Format('%s %s = ((%s)(%s.error));', [EmitTypeRef(ErrF), CaseNode.Pattern.SubPattern, EmitTypeRef(ErrF), ExprStr]);
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
          if IsValueOptionType(MatchedType) then
          begin
            CondStr := Format('%s.is_some', [ExprStr]);
            if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
            begin
              ValF := Trim(Copy(MatchedType, 8, Length(MatchedType) - 8));
              BindStmt := Format('%s %s = %s;', [EmitTypeRef(ValF), CaseNode.Pattern.SubPattern, EmitMonadFieldExtract(ExprStr, ValF, 'num_val', 'str_val')]);
            end;
          end
          else
          begin
            CondStr := Format('%s != NULL', [ExprStr]);
            if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
            begin
              if Pos('Option<', MatchedType) = 1 then
                BindStmt := Format('%s %s = %s;', [EmitTypeRef(Copy(MatchedType, 8, Length(MatchedType) - 8)), CaseNode.Pattern.SubPattern, ExprStr])
              else
                BindStmt := Format('void* %s = %s;', [CaseNode.Pattern.SubPattern, ExprStr]);
            end;
          end;
        end
        else if (CaseNode.Pattern.Items.Count <= 1) and (PatStr = 'None') then
        begin
          if IsValueOptionType(MatchedType) then
            CondStr := Format('%s.is_none', [ExprStr])
          else
            CondStr := Format('%s == NULL', [ExprStr]);
        end
        else
        begin
          CondStr := '';
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
        end;

        Emit(Prefix + CondStr + ') {');
        IncIndent;
        if BindStmt <> '' then Emit(BindStmt);
        for J := 0 to CaseNode.Body.Count - 1 do
          EmitStmt(TASTStmt(CaseNode.Body[J]));
        DecIndent;
      end;
    end;
    if MatchStmt.Cases.Count > 0 then
      Emit('}');
  end;
end;

procedure TAetherEmitterC.EmitRecordDecl(Rec: TASTRecordDecl);
var
  I: Integer;
  Field: TASTRecordField;
  CtorParams, CtorInit: string;
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

  // Construtor estilo DataBuffer(id, size)
  CtorParams := '';
  CtorInit := '';
  for I := 0 to Rec.Fields.Count - 1 do
  begin
    Field := TASTRecordField(Rec.Fields[I]);
    CtorParams := CtorParams + Format('%s a_%s', [EmitTypeRef(Field.TypeName), Field.Name]);
    CtorInit := CtorInit + Format('.%s = a_%s', [Field.Name, Field.Name]);
    if I < Rec.Fields.Count - 1 then
    begin
      CtorParams := CtorParams + ', ';
      CtorInit := CtorInit + ', ';
    end;
  end;
  Emit(Format('static inline T%s %s(%s) { return (T%s){ %s }; }', [Rec.Name, Rec.Name, CtorParams, Rec.Name, CtorInit]));
  Emit('');
end;

procedure TAetherEmitterC.EmitEnumDecl(Enm: TASTEnumDecl);
var
  I: Integer;
  VariantName: string;
begin
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
  if Func.GenericParam <> '' then Exit; // Molde generico nao emite codigo diretamente
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

    // Funcoes de math.h nao devem ser redeclaradas com extern simples para nao conflitar com atributos do GCC
    if (Func.ExternAbi = 'c') and ((Func.Name = 'sin') or (Func.Name = 'cos') or (Func.Name = 'sqrt') or
       (Func.Name = 'tan') or (Func.Name = 'abs') or (Func.Name = 'floor') or (Func.Name = 'ceil')) then
    begin
      Emit(Format('// Extern C Math: %s (fornecido por <math.h>)', [Func.Name]));
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
      ModStr := ''; // Passado por valor ou ponteiro const se record

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

  // Asserts de Pre-condicao
  for I := 0 to Func.Requires.Count - 1 do
    Emit(Format('assert(%s);', [EmitExpr(TASTExpr(Func.Requires[I]))]));

  // Variaveis Locais
  if (Func.ReturnType <> 'Void') and (Func.ReturnType <> '') and (not Func.IsAsync) then
  begin
    Emit(Format('%s result;', [EmitTypeRef(Func.ReturnType)]));
    Emit('memset(&result, 0, sizeof(result));');
  end;

  for I := 0 to Func.LocalVars.Count - 1 do
  begin
    VarDecl := TASTVarDecl(Func.LocalVars[I]);
    if IsMapType(VarDecl.TypeName, KeyT, ValT) then
    begin
      Emit(Format('%s %s;', [EmitTypeRef(VarDecl.TypeName), VarDecl.Name]));
      Emit(Format('memset(&%s, 0, sizeof(%s));', [VarDecl.Name, VarDecl.Name]));
      if Assigned(VarDecl.InitialExpr) then
        Emit(Format('%s = %s;', [VarDecl.Name, EmitExpr(VarDecl.InitialExpr)]));
    end
    else if Pos('array[', VarDecl.TypeName) = 1 then
    begin
      Emit(FormatCArrayVar(VarDecl.TypeName, VarDecl.Name));
      Emit(Format('memset(&%s, 0, sizeof(%s));', [VarDecl.Name, VarDecl.Name]));
    end
    else
    begin
      VolQual := '';
      if IsVarModifiedInTry(VarDecl.Name, Func.Body) then
        VolQual := 'volatile ';
      if (IsDynamicArrayType(VarDecl.TypeName) or (Pos('^', VarDecl.TypeName) = 1) or (VarDecl.TypeName = 'Pointer')) and
         ((not Assigned(VarDecl.InitialExpr)) or (VarDecl.InitialExpr is TASTSetLiteralExpr)) then
        Emit(Format('%s %s%s = NULL;', [EmitTypeRef(VarDecl.TypeName), VolQual, VarDecl.Name]))
      else
      begin
        Emit(Format('%s %s%s;', [EmitTypeRef(VarDecl.TypeName), VolQual, VarDecl.Name]));
      end;
      if Assigned(VarDecl.InitialExpr) then
      begin
        if (VarDecl.InitialExpr is TASTSetLiteralExpr) and (not IsSetType(VarDecl.TypeName)) then
          EmitArrayLiteralAssign(VarDecl.Name, VarDecl.TypeName, TASTSetLiteralExpr(VarDecl.InitialExpr))
        else if not IsMapType(VarDecl.TypeName, KeyT, ValT) then
          Emit(Format('%s = %s;', [VarDecl.Name, EmitExpr(VarDecl.InitialExpr)]));
      end;
    end;
  end;

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

  // Corpo
  FActiveDefers.Clear;
  FLoopDeferBase := 0;
  FTryDepth := 0;
  EmitStmtList(Func.Body);
  FActiveDefers.Clear;

  if (Func.Ensures.Count > 0) and ((Func.Body.Count = 0) or not (Func.Body[Func.Body.Count - 1] is TASTReturnStmt)) then
  begin
    for I := 0 to Func.Ensures.Count - 1 do
      Emit(Format('assert(%s);', [EmitExpr(TASTExpr(Func.Ensures[I]))]));
  end;

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
  Emit('g_aether_argc = argc;');
  Emit('g_aether_argv = argv;');
  for I := 0 to Prog.LocalVars.Count - 1 do
  begin
    VarDecl := TASTVarDecl(Prog.LocalVars[I]);
    if IsMapType(VarDecl.TypeName, KeyT, ValT) then
    begin
      Emit(Format('%s %s;', [EmitTypeRef(VarDecl.TypeName), VarDecl.Name]));
      Emit(Format('memset(&%s, 0, sizeof(%s));', [VarDecl.Name, VarDecl.Name]));
      if Assigned(VarDecl.InitialExpr) then
        Emit(Format('%s = %s;', [VarDecl.Name, EmitExpr(VarDecl.InitialExpr)]));
    end
    else if Pos('array[', VarDecl.TypeName) = 1 then
    begin
      Emit(FormatCArrayVar(VarDecl.TypeName, VarDecl.Name));
      Emit(Format('memset(&%s, 0, sizeof(%s));', [VarDecl.Name, VarDecl.Name]));
    end
    else
    begin
      VolQual := '';
      if IsVarModifiedInTry(VarDecl.Name, Prog.Body) then
        VolQual := 'volatile ';
      if (IsDynamicArrayType(VarDecl.TypeName) or (Pos('^', VarDecl.TypeName) = 1) or (VarDecl.TypeName = 'Pointer')) and
         ((not Assigned(VarDecl.InitialExpr)) or (VarDecl.InitialExpr is TASTSetLiteralExpr)) then
        Emit(Format('%s %s%s = NULL;', [EmitTypeRef(VarDecl.TypeName), VolQual, VarDecl.Name]))
      else
      begin
        Emit(Format('%s %s%s;', [EmitTypeRef(VarDecl.TypeName), VolQual, VarDecl.Name]));
      end;
      if Assigned(VarDecl.InitialExpr) then
      begin
        if (VarDecl.InitialExpr is TASTSetLiteralExpr) and (not IsSetType(VarDecl.TypeName)) then
          EmitArrayLiteralAssign(VarDecl.Name, VarDecl.TypeName, TASTSetLiteralExpr(VarDecl.InitialExpr))
        else if not IsMapType(VarDecl.TypeName, KeyT, ValT) then
          Emit(Format('%s = %s;', [VarDecl.Name, EmitExpr(VarDecl.InitialExpr)]));
      end;
    end;
  end;

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
  FTryDepth := 0;
  EmitStmtList(Prog.Body);
  FActiveDefers.Clear;

  Emit('return 0;');
  DecIndent;
  Emit('}');
end;

function TAetherEmitterC.Generate(AModule: TASTModule): string;
var
  I, J: Integer;
  Func: TASTFunction;
  Param: TASTParam;
  ConstDecl: TASTConstDecl;
  ParamListStr, ModStr, ExportPrefix: string;
  HasExports: Boolean;
  MapTags, MapKeys, MapVals: TStringList;
begin
  FModule := AModule;
  FOutput.Clear;
  FIndent := 0;
  FLoopCounter := 0;
  MapTags := TStringList.Create;
  MapKeys := TStringList.Create;
  MapVals := TStringList.Create;
  try
  CollectMapsFromModule(AModule, MapTags, MapKeys, MapVals);

  HasExports := False;
  for I := 0 to AModule.Functions.Count - 1 do
    if TASTFunction(AModule.Functions[I]).IsExport then
    begin
      HasExports := True;
      Break;
    end;

  Emit('// Codigo gerado automaticamente pelo Compilador Aether (aetherc)');
  Emit('// Alvo: C99 / GCC (MSYS2)');
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
  Emit('#include <time.h>');
  Emit('#include <sys/stat.h>');
  Emit('#include <setjmp.h>');
  Emit('#ifdef _WIN32');
  Emit('#define WIN32_LEAN_AND_MEAN');
  Emit('#define NOGDI');
  Emit('#include <winsock2.h>');
  Emit('#include <ws2tcpip.h>');
  Emit('#include <windows.h>');
  Emit('#include <direct.h>');
  Emit('#include <io.h>');
  Emit('#undef Rectangle');
  Emit('typedef int socklen_t;');
  Emit('#else');
  Emit('#include <sys/socket.h>');
  Emit('#include <netinet/in.h>');
  Emit('#include <arpa/inet.h>');
  Emit('#include <unistd.h>');
  Emit('#endif');
  Emit('#endif');
  Emit('');
  Emit('// Runtime de Concorrencia e Tarefas Assincronas (AetherTask)');
  Emit('typedef struct {');
  Emit('    bool is_completed;');
  Emit('    int64_t int_val;');
  Emit('    double float_val;');
  Emit('    const char* str_val;');
  Emit('    void* ptr_val;');
  Emit('} AetherTask;');
  Emit('');
  Emit('#if defined(_WIN32) || defined(__CYGWIN__)');
  Emit('  #define AETHER_EXPORT __declspec(dllexport)');
  Emit('#else');
  Emit('  #define AETHER_EXPORT __attribute__((visibility("default")))');
  Emit('#endif');
  Emit('');

  // Headers adicionais de C (import c)
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

  // Helpers de compatibilidade Pascal no backend C
  Emit('static inline double AetherPascalNow(void) {');
  Emit('#if defined(__wasm__)');
  Emit('    return 0.0;');
  Emit('#else');
  Emit('    return (double)time(NULL);');
  Emit('#endif');
  Emit('}');
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

  // Helpers de Runtime do Aether
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
  Emit('static inline char* AetherCharAt(const char* s, uint32_t index) {');
  Emit('    uint32_t slen = s ? (uint32_t)strlen(s) : 0;');
  Emit('    char* res = (char*)malloc(2);');
  Emit('    if (index < slen) { res[0] = s[index]; res[1] = ''\0''; }');
  Emit('    else { res[0] = ''\0''; }');
  Emit('    return res;');
  Emit('}');
  Emit('');
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
  Emit('static inline bool AetherStartsWith(const char* s, const char* prefix) {');
  Emit('    if (!s || !prefix) return false;');
  Emit('    size_t sl = strlen(s), pl = strlen(prefix);');
  Emit('    if (pl > sl) return false;');
  Emit('    for (size_t i = 0; i < pl; i++) if (s[i] != prefix[i]) return false;');
  Emit('    return true;');
  Emit('}');
  Emit('');
  Emit('static inline bool AetherEndsWith(const char* s, const char* suffix) {');
  Emit('    if (!s || !suffix) return false;');
  Emit('    size_t sl = strlen(s), sufl = strlen(suffix);');
  Emit('    if (sufl > sl) return false;');
  Emit('    for (size_t i = 0; i < sufl; i++) if (s[sl - sufl + i] != suffix[i]) return false;');
  Emit('    return true;');
  Emit('}');
  Emit('');
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
  Emit('static inline bool AetherStrContains(const char* s, const char* sub) {');
  Emit('    return AetherStrIndexOf(s, sub) >= 0;');
  Emit('}');
  Emit('');
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
  Emit('static inline char* AetherCharToStr(char c) {');
  Emit('    char* buf = (char*)malloc(2);');
  Emit('    buf[0] = c; buf[1] = ''\0'';');
  Emit('    return buf;');
  Emit('}');
  Emit('');
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
  Emit('static inline char* AetherFloatToStr(double val) {');
  Emit('    char* buf = (char*)malloc(32);');
  Emit('    snprintf(buf, 32, "%g", val);');
  Emit('    return buf;');
  Emit('}');
  Emit('');
  Emit('static inline char* AetherBoolToStr(bool val) {');
  Emit('    return val ? (char*)"true" : (char*)"false";');
  Emit('}');
  Emit('');
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
  Emit('// Helpers de Linha de Comando');
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
  Emit('// Helpers de Sockets Aether');
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

  // Estrutura Result e Option por Valor para C
  Emit('typedef struct {');
  Emit('    bool is_ok;');
  Emit('    bool is_err;');
  Emit('    double value;');
  Emit('    int error;');
  Emit('    const char* str_val;');
  Emit('    const char* err_str;');
  Emit('} AetherResult;');
  Emit('');
  Emit('typedef struct {');
  Emit('    bool is_some;');
  Emit('    bool is_none;');
  Emit('    double num_val;');
  Emit('    const char* str_val;');
  Emit('} AetherOption;');
  Emit('');
  EmitMapRuntimeDecls(MapTags, MapKeys, MapVals, True);

  // Constantes
  for I := 0 to AModule.Constants.Count - 1 do
  begin
    ConstDecl := TASTConstDecl(AModule.Constants[I]);
    if (ConstDecl.TypeName = 'String') or (GetExprTypeName(ConstDecl.ValueExpr) = 'String') then
      Emit(Format('static const char* const %s = %s;', [ConstDecl.Name, EmitExpr(ConstDecl.ValueExpr)]))
    else
      Emit(Format('static const %s %s = %s;', [EmitTypeRef(ConstDecl.TypeName), ConstDecl.Name, EmitExpr(ConstDecl.ValueExpr)]));
  end;
  if AModule.Constants.Count > 0 then Emit('');

  // Typedefs antecipados para permitir records recursivos
  for I := 0 to AModule.Types.Count - 1 do
  begin
    if AModule.Types[I] is TASTRecordDecl then
    begin
      Emit(Format('typedef struct T%s T%s;', [TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name]));
      Emit(Format('typedef T%s* PT%s;', [TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name]));
    end;
  end;
  Emit('');

  // Tipos
  for I := 0 to AModule.Types.Count - 1 do
  begin
    if AModule.Types[I] is TASTRecordDecl then
      EmitRecordDecl(TASTRecordDecl(AModule.Types[I]))
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
  Emit('');

  // Construtores AetherBox para Records
  for I := 0 to AModule.Types.Count - 1 do
  begin
    if AModule.Types[I] is TASTRecordDecl then
    begin
      Emit(Format('static inline PT%s AetherBox_T%s(T%s V) {', [TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name]));
      Emit(Format('    PT%s p = (PT%s)malloc(sizeof(T%s));', [TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name, TASTRecordDecl(AModule.Types[I]).Name]));
      Emit('    *p = V;');
      Emit('    return p;');
      Emit('}');
      Emit('');
    end;
  end;

  EmitMapRuntimeHelpers(MapTags, MapKeys, MapVals);

  // Prototipos antecipados de todas as funcoes
  for I := 0 to AModule.Functions.Count - 1 do
  begin
    Func := TASTFunction(AModule.Functions[I]);
    if (not Func.IsExtern) and (Func.GenericParam = '') then
    begin
      ParamListStr := '';
      for J := 0 to Func.Params.Count - 1 do
      begin
        Param := TASTParam(Func.Params[J]);
        ModStr := '';
        if Param.Ownership = owMutBorrow then
          ModStr := '*'
        else if Param.Ownership = owBorrow then
          ModStr := '';
        ParamListStr := ParamListStr + Format('%s %s%s', [EmitTypeRef(Param.TypeName), ModStr, Param.Name]);
        if J < Func.Params.Count - 1 then
          ParamListStr := ParamListStr + ', ';
      end;
      ExportPrefix := '';
      if Func.InlineMode = 'always' then
        ExportPrefix := 'static inline __attribute__((always_inline)) '
      else if Func.InlineMode = 'never' then
        ExportPrefix := '__attribute__((noinline)) ';
      if Func.IsCold then
        ExportPrefix := ExportPrefix + '__attribute__((cold)) ';
      if Func.IsExport then ExportPrefix := ExportPrefix + 'AETHER_EXPORT ';
      if Func.IsAsync then
        Emit(Format('%sAetherTask %s(%s);', [ExportPrefix, Func.Name, ParamListStr]))
      else if (Func.ReturnType = 'Void') or (Func.ReturnType = '') then
        Emit(Format('%svoid %s(%s);', [ExportPrefix, Func.Name, ParamListStr]))
      else
        Emit(Format('%s%s %s(%s);', [ExportPrefix, EmitTypeRef(Func.ReturnType), Func.Name, ParamListStr]));
    end;
  end;
  Emit('');

  // Funções
  for I := 0 to AModule.Functions.Count - 1 do
    EmitFunction(TASTFunction(AModule.Functions[I]));

  // Bloco do Programa
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
    MapTags.Free;
    MapKeys.Free;
    MapVals.Free;
  end;
end;

end.
