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

    procedure Emit(const Line: string = '');
    procedure IncIndent;
    procedure DecIndent;
    function IndentStr: string;

    function IsEnumName(const AName: string): Boolean;
    function EscapePascalString(const S: string): string;
    function GetExprTypeName(Expr: TASTExpr): string;
    function IsPointerTarget(Expr: TASTExpr): Boolean;

    function EmitTypeRef(const AType: string): string;
    function EmitExpr(Expr: TASTExpr): string;
    procedure EmitStmt(Stmt: TASTStmt);
    procedure EmitRecordType(Rec: TASTRecordDecl);
    procedure EmitRecordConstructor(Rec: TASTRecordDecl);
    procedure EmitEnumDecl(Enm: TASTEnumDecl);
    procedure EmitFunction(Func: TASTFunction);
    procedure EmitProgramBlock(Prog: TASTProgramBlock);
  public
    constructor Create;
    destructor Destroy; override;
    function Generate(AModule: TASTModule): string;
  end;

implementation

constructor TAetherEmitterPascal.Create;
begin
  inherited Create;
  FOutput := TStringList.Create;
  FIndent := 0;
end;

destructor TAetherEmitterPascal.Destroy;
begin
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

function TAetherEmitterPascal.GetExprTypeName(Expr: TASTExpr): string;
var
  Id: TASTIdentifierExpr;
  Acc: TASTMemberAccessExpr;
  Call: TASTCallExpr;
  Bin: TASTBinaryExpr;
  TargetType, CleanTarget: string;
  I, J, P1, P2: Integer;
  Rec: TASTRecordDecl;
  V: TASTVarDecl;
  P: TASTParam;
begin
  Result := '';
  if not Assigned(Expr) then Exit;

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
  end
  else if Expr is TASTCallExpr then
  begin
    Call := TASTCallExpr(Expr);
    if Call.Callee = 'Box' then Exit('Box');
    if Call.Callee = 'Some' then Exit('Option');
    if (Call.Callee = 'ReadFile') or (Call.Callee = 'CharAt') or (Call.Callee = 'Substring') or (Call.Callee = 'ToString') then Exit('String');
    if (Call.Callee = 'Length') then Exit('UInt32');
    if (Call.Callee = 'FileExists') or (Call.Callee = 'WriteFile') then Exit('Bool');
  end;
end;

function TAetherEmitterPascal.IsPointerTarget(Expr: TASTExpr): Boolean;
var
  T: string;
begin
  T := GetExprTypeName(Expr);
  Result := (Pos('Box<', T) > 0) or (Pos('Pointer', T) > 0) or (T = 'Box');
end;

function TAetherEmitterPascal.EmitTypeRef(const AType: string): string;
var
  Inner: string;
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
  else if Pos('Result', AType) = 1 then
    Result := 'TResultDoubleError'
  else if Pos('Box<', AType) > 0 then
  begin
    P1 := Pos('Box<', AType);
    Inner := Copy(AType, P1 + 4, Length(AType));
    P2 := Pos('>', Inner);
    if P2 > 0 then Inner := Copy(Inner, 1, P2 - 1);
    Result := 'P' + EmitTypeRef(Inner);
  end
  else if Pos('Option<', AType) = 1 then
  begin
    Inner := Copy(AType, 8, Length(AType) - 8);
    Result := EmitTypeRef(Inner);
  end
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
  ArgsStr: string;
  I: Integer;
  TargetStr: string;
begin
  if not Assigned(Expr) then Exit('');

  if Expr is TASTLiteralExpr then
  begin
    Lit := TASTLiteralExpr(Expr);
    case Lit.Kind of
      lkString: Result := EscapePascalString(Lit.Value);
      lkChar:   Result := '''' + Lit.Value + '''';
      lkBool:   Result := LowerCase(Lit.Value);
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
      Result := TargetStr + '.' + Acc.Member;
    Exit;
  end;

  if Expr is TASTBinaryExpr then
  begin
    Bin := TASTBinaryExpr(Expr);
    if Bin.Op = 'implies' then
      Result := Format('((not (%s)) or (%s))', [EmitExpr(Bin.Left), EmitExpr(Bin.Right)])
    else
      Result := Format('(%s %s %s)', [EmitExpr(Bin.Left), Bin.Op, EmitExpr(Bin.Right)]);
    Exit;
  end;

  if Expr is TASTUnaryExpr then
  begin
    Un := TASTUnaryExpr(Expr);
    Result := Format('(%s %s)', [Un.Op, EmitExpr(Un.Expr)]);
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

    if Call.Callee = 'Length' then
    begin
      Result := 'UInt32(Length(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))';
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

procedure TAetherEmitterPascal.EmitStmt(Stmt: TASTStmt);
var
  Assign: TASTAssignStmt;
  CallStmt: TASTCallStmt;
  IfStmt: TASTIfStmt;
  WhileStmt: TASTWhileStmt;
  MatchStmt: TASTMatchStmt;
  CaseNode: TASTMatchCase;
  Ret: TASTReturnStmt;
  I, J: Integer;
  PatStr: string;
begin
  if Stmt is TASTAssignStmt then
  begin
    Assign := TASTAssignStmt(Stmt);
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
    for I := 0 to IfStmt.ThenBranch.Count - 1 do
      EmitStmt(TASTStmt(IfStmt.ThenBranch[I]));
    DecIndent;
    if IfStmt.ElseBranch.Count > 0 then
    begin
      Emit('end');
      Emit('else');
      Emit('begin');
      IncIndent;
      for I := 0 to IfStmt.ElseBranch.Count - 1 do
        EmitStmt(TASTStmt(IfStmt.ElseBranch[I]));
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
    for I := 0 to WhileStmt.Body.Count - 1 do
      EmitStmt(TASTStmt(WhileStmt.Body[I]));
    DecIndent;
    Emit('end;');
  end
  else if Stmt is TASTReturnStmt then
  begin
    Ret := TASTReturnStmt(Stmt);
    if Assigned(Ret.Expr) then
      Emit(Format('Exit(%s);', [EmitExpr(Ret.Expr)]))
    else
      Emit('Exit;');
  end
  else if Stmt is TASTMatchStmt then
  begin
    MatchStmt := TASTMatchStmt(Stmt);
    // Emissao de Match para Pascal (seja Result ou Enum)
    Emit('// Match gerado pelo compilador Aether');
    for I := 0 to MatchStmt.Cases.Count - 1 do
    begin
      CaseNode := TASTMatchCase(MatchStmt.Cases[I]);
      PatStr := CaseNode.Pattern.Value;

      if Pos('Ok', PatStr) = 1 then
      begin
        Emit(Format('if %s.is_ok then', [EmitExpr(MatchStmt.Expr)]));
        Emit('begin');
        IncIndent;
        if CaseNode.Pattern.SubPattern <> '' then
          Emit(Format('%s := %s.value;', [CaseNode.Pattern.SubPattern, EmitExpr(MatchStmt.Expr)]));
        for J := 0 to CaseNode.Body.Count - 1 do
          EmitStmt(TASTStmt(CaseNode.Body[J]));
        DecIndent;
        Emit('end;');
      end
      else if Pos('Err', PatStr) = 1 then
      begin
        if CaseNode.Pattern.SubPattern <> '' then
          Emit(Format('if (%s.is_err) and (%s.error = Integer(%s)) then',
            [EmitExpr(MatchStmt.Expr), EmitExpr(MatchStmt.Expr), StringReplace(CaseNode.Pattern.SubPattern, '.', '_', [rfReplaceAll])]))
        else
          Emit(Format('if %s.is_err then', [EmitExpr(MatchStmt.Expr)]));

        Emit('begin');
        IncIndent;
        for J := 0 to CaseNode.Body.Count - 1 do
          EmitStmt(TASTStmt(CaseNode.Body[J]));
        DecIndent;
        Emit('end;');
      end;
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
  Emit('');
end;

procedure TAetherEmitterPascal.EmitFunction(Func: TASTFunction);
var
  ParamListStr: string;
  I: Integer;
  Param: TASTParam;
  ModStr: string;
  VarDecl: TASTVarDecl;
  LibClause: string;
  ParamType: string;
begin
  FCurrentFunc := Func;
  if Func.IsExtern then
  begin
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
    else
      ModStr := 'const ';
    end;
    ParamListStr := ParamListStr + Format('%s%s: %s', [ModStr, Param.Name, EmitTypeRef(Param.TypeName)]);
    if I < Func.Params.Count - 1 then
      ParamListStr := ParamListStr + '; ';
  end;

  if (Func.ReturnType = 'Void') or (Func.ReturnType = '') then
    Emit(Format('procedure %s(%s);', [Func.Name, ParamListStr]))
  else
    Emit(Format('function %s(%s): %s;', [Func.Name, ParamListStr, EmitTypeRef(Func.ReturnType)]));

  // Variaveis Locais
  if Func.LocalVars.Count > 0 then
  begin
    Emit('var');
    IncIndent;
    for I := 0 to Func.LocalVars.Count - 1 do
    begin
      VarDecl := TASTVarDecl(Func.LocalVars[I]);
      Emit(Format('%s: %s;', [VarDecl.Name, EmitTypeRef(VarDecl.TypeName)]));
    end;
    DecIndent;
  end;

  Emit('begin');
  IncIndent;

  // Verificacao de Contratos require em tempo de execucao (Asserts)
  for I := 0 to Func.Requires.Count - 1 do
  begin
    Emit(Format('Assert(%s, ''Violacao de pre-condicao (require) na funcao %s'');', [EmitExpr(TASTExpr(Func.Requires[I])), Func.Name]));
  end;

  // Corpo
  for I := 0 to Func.Body.Count - 1 do
    EmitStmt(TASTStmt(Func.Body[I]));

  DecIndent;
  Emit('end;');
  Emit('');
end;

procedure TAetherEmitterPascal.EmitProgramBlock(Prog: TASTProgramBlock);
var
  I, K: Integer;
  VarDecl: TASTVarDecl;
  MatchNode: TASTMatchStmt;
  CaseNode: TASTMatchCase;
  HasVars: Boolean;
begin
  FCurrentFunc := nil;
  FProgramBlock := Prog;
  HasVars := Prog.LocalVars.Count > 0;
  if not HasVars then
  begin
    for I := 0 to Prog.Body.Count - 1 do
    begin
      if Prog.Body[I] is TASTMatchStmt then
      begin
        MatchNode := TASTMatchStmt(Prog.Body[I]);
        for K := 0 to MatchNode.Cases.Count - 1 do
        begin
          CaseNode := TASTMatchCase(MatchNode.Cases[K]);
          if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') then
          begin
            HasVars := True;
            Break;
          end;
        end;
      end;
      if HasVars then Break;
    end;
  end;

  if HasVars then
  begin
    Emit('var');
    IncIndent;
    for I := 0 to Prog.LocalVars.Count - 1 do
    begin
      VarDecl := TASTVarDecl(Prog.LocalVars[I]);
      Emit(Format('%s: %s;', [VarDecl.Name, EmitTypeRef(VarDecl.TypeName)]));
    end;

    // Variaveis de padrao do match (ex: let valor)
    for I := 0 to Prog.Body.Count - 1 do
    begin
      if Prog.Body[I] is TASTMatchStmt then
      begin
        MatchNode := TASTMatchStmt(Prog.Body[I]);
        for K := 0 to MatchNode.Cases.Count - 1 do
        begin
          CaseNode := TASTMatchCase(MatchNode.Cases[K]);
          if CaseNode.Pattern.IsLet and (CaseNode.Pattern.SubPattern <> '') then
            Emit(Format('%s: Double;', [CaseNode.Pattern.SubPattern]));
        end;
      end;
    end;

    DecIndent;
  end;

  Emit('begin');
  IncIndent;
  for I := 0 to Prog.Body.Count - 1 do
    EmitStmt(TASTStmt(Prog.Body[I]));
  DecIndent;
  Emit('end.');
end;

function TAetherEmitterPascal.Generate(AModule: TASTModule): string;
var
  I, J: Integer;
  UsesClause: string;
  Func: TASTFunction;
  Param: TASTParam;
  ParamListStr, ModStr: string;
begin
  FModule := AModule;
  FOutput.Clear;
  FIndent := 0;

  Emit('// Codigo gerado automaticamente pelo Compilador Aether (aetherc)');
  Emit('// Alvo: Object Pascal (Free Pascal)');
  Emit('program ' + AModule.Name + ';');
  Emit('');
  Emit('{$mode objfpc}{$H+}{$assertions on}');
  Emit('');

  UsesClause := '  SysUtils';
  for I := 0 to AModule.PascalImports.Count - 1 do
    UsesClause := UsesClause + ', ' + AModule.PascalImports[I];
  UsesClause := UsesClause + ';';

  Emit('uses');
  Emit(UsesClause);
  Emit('');

  // Helpers nativos do Aether para Result<T, E>
  Emit('// --- Aether Runtime Helpers ---');
  Emit('type');
  Emit('  generic TAetherResult<TVal, TErr> = record');
  Emit('    is_ok: Boolean;');
  Emit('    is_err: Boolean;');
  Emit('    value: TVal;');
  Emit('    error: TErr;');
  Emit('  end;');
  Emit('');
  Emit('// Definicao de Result padrao para compatibilidade de tipos');
  Emit('type');
  Emit('  TResultDoubleError = specialize TAetherResult<Double, Integer>;');
  Emit('  function AetherOk(const V: Double): TResultDoubleError;');
  Emit('  begin Result.is_ok := True; Result.is_err := False; Result.value := V; end;');
  Emit('  function AetherErr(const E: Integer): TResultDoubleError;');
  Emit('  begin Result.is_ok := False; Result.is_err := True; Result.error := E; end;');
  Emit('');

  // Seção Type
  if AModule.Types.Count > 0 then
  begin
    Emit('type');
    IncIndent;
    // 1. Declaracao de ponteiros antecipados (PTRecord = ^TRecord) para permitir records recursivos
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
        EmitEnumDecl(TASTEnumDecl(AModule.Types[I]));
    end;
    DecIndent;
    Emit('');

    // Construtores de records e construtores de Box
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

  // Runtime Helpers para I/O e Strings
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

  // Declaracoes antecipadas (forward) de todas as funcoes
  for I := 0 to AModule.Functions.Count - 1 do
  begin
    Func := TASTFunction(AModule.Functions[I]);
    if not Func.IsExtern then
    begin
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
        ParamListStr := ParamListStr + Format('%s%s: %s', [ModStr, Param.Name, EmitTypeRef(Param.TypeName)]);
        if J < Func.Params.Count - 1 then
          ParamListStr := ParamListStr + '; ';
      end;
      if (Func.ReturnType = 'Void') or (Func.ReturnType = '') then
        Emit(Format('procedure %s(%s); forward;', [Func.Name, ParamListStr]))
      else
        Emit(Format('function %s(%s): %s; forward;', [Func.Name, ParamListStr, EmitTypeRef(Func.ReturnType)]));
    end;
  end;
  Emit('');

  // Funções
  for I := 0 to AModule.Functions.Count - 1 do
    EmitFunction(TASTFunction(AModule.Functions[I]));

  // Bloco do Programa
  if Assigned(AModule.ProgramBlock) then
    EmitProgramBlock(AModule.ProgramBlock);

  Result := FOutput.Text;
end;

end.
