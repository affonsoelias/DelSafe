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

    procedure Emit(const Line: string = '');
    procedure IncIndent;
    procedure DecIndent;
    function IndentStr: string;
    procedure EmitActiveDefers(DownToIndex: Integer = 0);
    procedure EmitStmtList(List: TASTNodeList; IsLoopBody: Boolean = False);

    function IsEnumName(const AName: string): Boolean;
    function IsMapType(const AType: string; out KeyType, ValType: string): Boolean;
    function MapTag(const K, V: string): string;
    function NormalizeIntLit(const Val: string): string;
    function GetCollectionElemType(Expr: TASTExpr): string;
    function IsBuiltinMapSideType(const AType: string): Boolean;
    procedure CollectAutoVarsFromStmts(Stmts: TASTNodeList; VarNames, VarTypes: TStrings; const SkipNames: TStrings);
    procedure CollectMapsFromType(const AType: string; Tags, Keys, Vals: TStrings);
    procedure CollectMapsFromModule(AModule: TASTModule; Tags, Keys, Vals: TStrings);
    procedure EmitMapRuntimeDecls(Tags, Keys, Vals: TStrings; BuiltinOnly: Boolean);
    procedure EmitMapRuntimeHelpers(Tags, Keys, Vals: TStrings; DeclOnly: Boolean);
    function EscapePascalString(const S: string): string;
    function GetExprTypeName(Expr: TASTExpr): string;
    function IsPointerTarget(Expr: TASTExpr): Boolean;

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

function IsIntegerType(const AType: string): Boolean;
begin
  Result := (AType = 'Int8') or (AType = 'Int16') or (AType = 'Int32') or (AType = 'Int64') or
            (AType = 'UInt8') or (AType = 'UInt16') or (AType = 'UInt32') or (AType = 'UInt64') or
            (AType = 'IntLiteral');
end;

function TAetherEmitterPascal.IsMapType(const AType: string; out KeyType, ValType: string): Boolean;
var
  PClose, I: Integer;
  MapD: TASTMapDecl;
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
  if Assigned(FModule) then
  begin
    for I := 0 to FModule.Types.Count - 1 do
      if (FModule.Types[I] is TASTMapDecl) and SameText(TASTMapDecl(FModule.Types[I]).Name, AType) then
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

procedure TAetherEmitterPascal.CollectAutoVarsFromStmts(Stmts: TASTNodeList; VarNames, VarTypes: TStrings; const SkipNames: TStrings);
var
  I, K: Integer;
  S: TASTStmt;
  ForStmt: TASTForStmt;
  MatchNode: TASTMatchStmt;
  CaseNode: TASTMatchCase;
  ElemT, MT, DeclType: string;

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
        ElemT := GetCollectionElemType(ForStmt.CollectionExpr);
        if ElemT <> '' then
          AddAutoVar(ForStmt.VarName, EmitTypeRef(ElemT))
        else
          AddAutoVar(ForStmt.VarName, 'LongInt');
      end
      else
        AddAutoVar(ForStmt.VarName, 'LongInt');
      CollectAutoVarsFromStmts(ForStmt.Body, VarNames, VarTypes, SkipNames);
    end
    else if S is TASTIfStmt then
    begin
      CollectAutoVarsFromStmts(TASTIfStmt(S).ThenBranch, VarNames, VarTypes, SkipNames);
      CollectAutoVarsFromStmts(TASTIfStmt(S).ElseBranch, VarNames, VarTypes, SkipNames);
    end
    else if S is TASTWhileStmt then
      CollectAutoVarsFromStmts(TASTWhileStmt(S).Body, VarNames, VarTypes, SkipNames)
    else if S is TASTRepeatStmt then
      CollectAutoVarsFromStmts(TASTRepeatStmt(S).Body, VarNames, VarTypes, SkipNames)
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
      MT := GetExprTypeName(MatchNode.Expr);
      for K := 0 to MatchNode.Cases.Count - 1 do
      begin
        CaseNode := TASTMatchCase(MatchNode.Cases[K]);
        if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
        begin
          if Pos('Err', CaseNode.Pattern.Value) = 1 then
            DeclType := 'LongInt'
          else if CaseNode.Pattern.Value = 'Some' then
          begin
            if Pos('Option<', MT) = 1 then
              DeclType := EmitTypeRef(Copy(MT, 8, Length(MT) - 8))
            else
              DeclType := 'Pointer';
          end
          else
            DeclType := 'Double';
          AddAutoVar(CaseNode.Pattern.SubPattern, DeclType);
        end;
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
    TargetType := GetExprTypeName(Acc.Target);
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
    TargetType := GetExprTypeName(TASTIndexExpr(Expr).Target);
    if IsMapType(TargetType, KeyType, ValType) then
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
    TargetType := GetExprTypeName(TASTUnaryExpr(Expr).Expr);
    if TASTUnaryExpr(Expr).Op = '@' then
      Exit('^' + TargetType)
    else if (TASTUnaryExpr(Expr).Op = '^') and (Pos('^', TargetType) = 1) then
      Exit(Copy(TargetType, 2, Length(TargetType)))
    else if SameText(TASTUnaryExpr(Expr).Op, 'not') or (TASTUnaryExpr(Expr).Op = '-') then
      Exit(TargetType);
  end
  else if Expr is TASTCallExpr then
  begin
    Call := TASTCallExpr(Expr);
    if Call.Callee = 'Box' then Exit('Box');
    if Call.Callee = 'Some' then Exit('Option');
    if (Call.Callee = 'ReadFile') or (Call.Callee = 'CharAt') or (Call.Callee = 'Substring') or (Call.Callee = 'ToString') or (Call.Callee = 'IntToStr') or (Call.Callee = 'FloatToStr') or (Call.Callee = 'BoolToStr') or (Call.Callee = 'CharToStr') or (Call.Callee = '__InterpToStr') or (Call.Callee = 'SocketRecv') or (Call.Callee = 'ParamStr') then Exit('String');
    if SameText(Call.Callee, 'Length') or SameText(Call.Callee, 'Count') or (Call.Callee = 'StrToInt') or (Call.Callee = 'SocketCreate') or (Call.Callee = 'SocketListen') or (Call.Callee = 'SocketAccept') or (Call.Callee = 'SocketConnect') or (Call.Callee = 'SocketSend') or (Call.Callee = 'ParamCount') then Exit('Int32');
    if (Call.Callee = 'sin') or (Call.Callee = 'cos') or (Call.Callee = 'tan') or (Call.Callee = 'sqrt') or (Call.Callee = 'Now') then Exit('Float64');
    if (Call.Callee = 'GetTickCount64') or (Call.Callee = 'GetNanoseconds') then Exit('UInt64');
    if (Call.Callee = 'FileSize') then Exit('Int64');
    if SameText(Call.Callee, 'Contains') or (Call.Callee = 'FileExists') or (Call.Callee = 'WriteFile') or (Call.Callee = 'CreateDir') or (Call.Callee = 'RemoveDir') or (Call.Callee = 'DeleteFile') or (Call.Callee = 'DirExists') then Exit('Bool');
    if SameText(Call.Callee, 'Remove') or (Call.Callee = 'SocketClose') or (Call.Callee = 'Assert') or (Call.Callee = 'SleepMs') then Exit('Void');
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
  T := GetExprTypeName(Expr);
  Result := (Pos('Box<', T) > 0) or (Pos('Pointer', T) > 0) or (T = 'Box');
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
    Inner := Copy(AType, 8, Length(AType) - 8);
    Result := EmitTypeRef(Inner);
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
  ArgsStr, KeyT, ValT: string;
  I: Integer;
  TargetStr: string;
begin
  if not Assigned(Expr) then Exit('');

  if Expr is TASTLiteralExpr then
  begin
    Lit := TASTLiteralExpr(Expr);
    case Lit.Kind of
      lkInt:    Result := NormalizeIntLit(Lit.Value);
      lkString: Result := EscapePascalString(Lit.Value);
      lkChar:   Result := '''' + Lit.Value + '''';
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
    if Id.Name = 'None' then
      Result := 'nil'
    else
      Result := Id.Name;
    Exit;
  end;

  if Expr is TASTMemberAccessExpr then
  begin
    Acc := TASTMemberAccessExpr(Expr);
    TargetStr := EmitExpr(Acc.Target);
    // Caso Enum.Variante
    if (Acc.Target is TASTIdentifierExpr) and IsEnumName(TASTIdentifierExpr(Acc.Target).Name) then
      Result := TargetStr + '_' + Acc.Member
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
    if IsMapType(GetExprTypeName(Idx.Target), KeyT, ValT) then
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

    // Construtores Ok e Err
    if Call.Callee = 'Ok' then
    begin
      Result := 'AetherOk(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'Err' then
    begin
      Result := 'AetherErr(Integer(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
      Exit;
    end;

    if Call.Callee = 'Some' then
    begin
      Result := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
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

    if SameText(Call.Callee, 'Contains') then
    begin
      IsMapType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr), KeyT, ValT);
      Result := Format('AetherMapContains_%s(%s, %s)', [MapTag(KeyT, ValT), EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
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
  Lines: TStringList;
  LineStr, PatStr, ExprStr, MatchedType, Prefix, CondStr, BindStmt, KeyT, ValT: string;
  I, J: Integer;
begin
  if Stmt is TASTAssignStmt then
  begin
    Assign := TASTAssignStmt(Stmt);
    if (Assign.Target is TASTIndexExpr) and IsMapType(GetExprTypeName(TASTIndexExpr(Assign.Target).Target), KeyT, ValT) then
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
    if FActiveDefers.Count > 0 then
    begin
      if Assigned(Ret.Expr) then
      begin
        if Assigned(FCurrentFunc) and FCurrentFunc.IsAsync then
          Emit(Format('Result.is_completed := True; Result.value := %s;', [EmitExpr(Ret.Expr)]))
        else
          Emit(Format('Result := %s;', [EmitExpr(Ret.Expr)]));
        EmitActiveDefers(0);
        Emit('Exit(Result);');
      end
      else
      begin
        EmitActiveDefers(0);
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
    MatchedType := GetExprTypeName(MatchStmt.Expr);
    Emit('// Match gerado pelo compilador Aether');
    for I := 0 to MatchStmt.Cases.Count - 1 do
    begin
      CaseNode := TASTMatchCase(MatchStmt.Cases[I]);
      PatStr := CaseNode.Pattern.Value;
      if I = 0 then Prefix := 'if '
      else if PatStr = '_' then Prefix := 'else'
      else Prefix := 'else if ';

      if PatStr = '_' then
      begin
        if I > 0 then Emit('else');
        Emit('begin');
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
            BindStmt := Format('%s := %s.value;', [CaseNode.Pattern.SubPattern, ExprStr]);
        end
        else if Pos('Err', PatStr) = 1 then
        begin
          if (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
          begin
            if CaseNode.Pattern.IsLet then
            begin
              CondStr := Format('%s.is_err', [ExprStr]);
              BindStmt := Format('%s := %s.error;', [CaseNode.Pattern.SubPattern, ExprStr]);
            end
            else
              CondStr := Format('(%s.is_err) and (%s.error = Integer(%s))',
                [ExprStr, ExprStr, StringReplace(CaseNode.Pattern.SubPattern, '.', '_', [rfReplaceAll])]);
          end
          else
            CondStr := Format('%s.is_err', [ExprStr]);
        end
        else if PatStr = 'Some' then
        begin
          CondStr := Format('(%s <> nil)', [ExprStr]);
          if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') and (CaseNode.Pattern.SubPattern <> '_') then
            BindStmt := Format('%s := %s;', [CaseNode.Pattern.SubPattern, ExprStr]);
        end
        else if PatStr = 'None' then
          CondStr := Format('(%s = nil)', [ExprStr])
        else if (Length(PatStr) >= 2) and (PatStr[1] = '"') then
          CondStr := Format('(%s = %s)', [ExprStr, EscapePascalString(Copy(PatStr, 2, Length(PatStr) - 2))])
        else if (Length(PatStr) >= 2) and (PatStr[1] = '''') then
          CondStr := Format('(%s = %s)', [ExprStr, PatStr])
        else if (PatStr = 'true') or (PatStr = 'false') then
          CondStr := Format('(%s = %s)', [ExprStr, PatStr])
        else if (PatStr <> '') and ((PatStr[1] in ['0'..'9', '$', '%']) or ((PatStr[1] = '-') and (Length(PatStr) > 1))) then
          CondStr := Format('(%s = %s)', [ExprStr, NormalizeIntLit(PatStr)])
        else if Pos('.', PatStr) > 0 then
          CondStr := Format('(%s = %s)', [ExprStr, StringReplace(PatStr, '.', '_', [rfReplaceAll])])
        else if IsEnumName(MatchedType) then
          CondStr := Format('(%s = %s_%s)', [ExprStr, MatchedType, PatStr])
        else
          CondStr := Format('(%s = %s)', [ExprStr, PatStr]);

        Emit(Prefix + CondStr + ' then');
        Emit('begin');
        IncIndent;
        if BindStmt <> '' then Emit(BindStmt);
        for J := 0 to CaseNode.Body.Count - 1 do
          EmitStmt(TASTStmt(CaseNode.Body[J]));
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
      SkipNames.Add(TASTVarDecl(Func.LocalVars[I]).Name);
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
      Emit(Format('%s := %s;', [VarDecl.Name, EmitExpr(VarDecl.InitialExpr)]));
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
      SkipNames.Add(TASTVarDecl(Prog.LocalVars[I]).Name);
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
      Emit(Format('%s := %s;', [VarDecl.Name, EmitExpr(VarDecl.InitialExpr)]));
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
  Emit('function AetherOk(const V: Double): TResultDoubleError;');
  Emit('function AetherErr(const E: Integer): TResultDoubleError;');
  Emit('function AetherCharAt(const S: string; Index: Cardinal): string;');
  Emit('function AetherSubstring(const S: string; Start, Len: Cardinal): string;');
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
  Emit('function AetherOk(const V: Double): TResultDoubleError;');
  Emit('begin Result.is_ok := True; Result.is_err := False; Result.value := V; end;');
  Emit('');
  Emit('function AetherErr(const E: Integer): TResultDoubleError;');
  Emit('begin Result.is_ok := False; Result.is_err := True; Result.error := E; end;');
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
  if not EffectiveLibrary then
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
          EmitSubrangeDecl(TASTSubrangeDecl(AModule.Types[I]));
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
          EmitSubrangeDecl(TASTSubrangeDecl(AModule.Types[I]));
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
