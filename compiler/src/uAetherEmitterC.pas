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

    procedure Emit(const Line: string = '');
    procedure IncIndent;
    procedure DecIndent;
    function IndentStr: string;

    function IsEnumName(const AName: string): Boolean;
    function IsMutBorrowParam(const AName: string): Boolean;
    function FindFunction(const AName: string): TASTFunction;
    function EscapeCString(const S: string): string;
    function GetExprTypeName(Expr: TASTExpr): string;
    function IsPointerTarget(Expr: TASTExpr): Boolean;

    function EmitTypeRef(const AType: string): string;
    function EmitExpr(Expr: TASTExpr): string;
    procedure EmitStmt(Stmt: TASTStmt);
    procedure EmitRecordDecl(Rec: TASTRecordDecl);
    procedure EmitEnumDecl(Enm: TASTEnumDecl);
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
end;

destructor TAetherEmitterC.Destroy;
begin
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

function TAetherEmitterC.GetExprTypeName(Expr: TASTExpr): string;
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
  end
  else if Expr is TASTCallExpr then
  begin
    Call := TASTCallExpr(Expr);
    if Call.Callee = 'Box' then Exit('Box');
    if Call.Callee = 'Some' then Exit('Option');
    if (Call.Callee = 'ReadFile') or (Call.Callee = 'CharAt') or (Call.Callee = 'Substring') or (Call.Callee = 'ToString') or (Call.Callee = 'IntToStr') then Exit('String');
    if (Call.Callee = 'Length') or (Call.Callee = 'StrToInt') then Exit('UInt32');
    if (Call.Callee = 'FileExists') or (Call.Callee = 'WriteFile') then Exit('Bool');
    if Assigned(FModule) then
    begin
      for I := 0 to FModule.Functions.Count - 1 do
        if SameText(TASTFunction(FModule.Functions[I]).Name, Call.Callee) then
          Exit(TASTFunction(FModule.Functions[I]).ReturnType);
    end;
  end;
end;

function TAetherEmitterC.IsPointerTarget(Expr: TASTExpr): Boolean;
var
  T: string;
begin
  T := GetExprTypeName(Expr);
  Result := (Pos('Box<', T) > 0) or (Pos('Pointer', T) > 0) or (T = 'Box');
end;

function TAetherEmitterC.EmitTypeRef(const AType: string): string;
var
  Inner: string;
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
  else if AType = 'String' then Result := 'const char*'
  else if AType = 'Void' then Result := 'void'
  else if Pos('Result', AType) = 1 then Result := 'AetherResult'
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
  FuncDecl: TASTFunction;
  CalleeName: string;
  ArgsStr: string;
  ArgVal: string;
  I: Integer;
  OpStr: string;
  TargetStr: string;
begin
  if not Assigned(Expr) then Exit('');

  if Expr is TASTLiteralExpr then
  begin
    Lit := TASTLiteralExpr(Expr);
    case Lit.Kind of
      lkString: Result := EscapeCString(Lit.Value);
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
    if (Acc.Target is TASTIdentifierExpr) and IsEnumName(TASTIdentifierExpr(Acc.Target).Name) then
      Result := TASTIdentifierExpr(Acc.Target).Name + '_' + Acc.Member
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
    else if OpStr = 'and' then OpStr := '&&'
    else if OpStr = 'or' then OpStr := '||'
    else if OpStr = 'mod' then OpStr := '%'
    else if OpStr = 'div' then OpStr := '/'
    else if OpStr = 'implies' then
      Exit(Format('(!(%s) || (%s))', [EmitExpr(Bin.Left), EmitExpr(Bin.Right)]));

    Result := Format('(%s %s %s)', [EmitExpr(Bin.Left), OpStr, EmitExpr(Bin.Right)]);
    Exit;
  end;

  if Expr is TASTUnaryExpr then
  begin
    Un := TASTUnaryExpr(Expr);
    OpStr := Un.Op;
    if OpStr = 'not' then OpStr := '!';
    Result := Format('(%s%s)', [OpStr, EmitExpr(Un.Expr)]);
    Exit;
  end;

  if Expr is TASTCallExpr then
  begin
    Call := TASTCallExpr(Expr);

    if Call.Callee = 'PrintLn' then
    begin
      if Call.Args.Count = 1 then
        Result := 'printf("%s\n", ' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')'
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
      Result := '(AetherResult){ .is_ok = true, .is_err = false, .value = ' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ' }';
      Exit;
    end;

    if Call.Callee = 'Err' then
    begin
      Result := '(AetherResult){ .is_ok = false, .is_err = true, .error = ' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ' }';
      Exit;
    end;

    if Call.Callee = 'Some' then
    begin
      Result := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
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

    if Call.Callee = 'Length' then
    begin
      Result := '(uint32_t)strlen(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
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

    if Call.Callee = 'IntToStr' then
    begin
      Result := 'AetherIntToStr(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
      Exit;
    end;

    if Call.Callee = 'StrToInt' then
    begin
      Result := 'AetherStrToInt(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
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
  end;

  Result := '';
end;

procedure TAetherEmitterC.EmitStmt(Stmt: TASTStmt);
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
    if (Assign.Target is TASTIdentifierExpr) and IsMutBorrowParam(TASTIdentifierExpr(Assign.Target).Name) then
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
    for I := 0 to IfStmt.ThenBranch.Count - 1 do
      EmitStmt(TASTStmt(IfStmt.ThenBranch[I]));
    DecIndent;
    if IfStmt.ElseBranch.Count > 0 then
    begin
      Emit('} else {');
      IncIndent;
      for I := 0 to IfStmt.ElseBranch.Count - 1 do
        EmitStmt(TASTStmt(IfStmt.ElseBranch[I]));
      DecIndent;
    end;
    Emit('}');
  end
  else if Stmt is TASTWhileStmt then
  begin
    WhileStmt := TASTWhileStmt(Stmt);
    Emit(Format('while (%s) {', [EmitExpr(WhileStmt.Condition)]));
    IncIndent;
    for I := 0 to WhileStmt.Body.Count - 1 do
      EmitStmt(TASTStmt(WhileStmt.Body[I]));
    DecIndent;
    Emit('}');
  end
  else if Stmt is TASTReturnStmt then
  begin
    Ret := TASTReturnStmt(Stmt);
    if Assigned(Ret.Expr) then
      Emit(Format('return %s;', [EmitExpr(Ret.Expr)]))
    else
      Emit('return;');
  end
  else if Stmt is TASTMatchStmt then
  begin
    MatchStmt := TASTMatchStmt(Stmt);
    Emit('// Match gerado pelo compilador Aether');
    for I := 0 to MatchStmt.Cases.Count - 1 do
    begin
      CaseNode := TASTMatchCase(MatchStmt.Cases[I]);
      PatStr := CaseNode.Pattern.Value;

      if Pos('Ok', PatStr) = 1 then
      begin
        Emit(Format('if (%s.is_ok) {', [EmitExpr(MatchStmt.Expr)]));
        IncIndent;
        if CaseNode.Pattern.SubPattern <> '' then
          Emit(Format('double %s = %s.value;', [CaseNode.Pattern.SubPattern, EmitExpr(MatchStmt.Expr)]));
        for J := 0 to CaseNode.Body.Count - 1 do
          EmitStmt(TASTStmt(CaseNode.Body[J]));
        DecIndent;
        Emit('}');
      end
      else if Pos('Err', PatStr) = 1 then
      begin
        if CaseNode.Pattern.SubPattern <> '' then
          Emit(Format('if (%s.is_err && %s.error == %s) {',
            [EmitExpr(MatchStmt.Expr), EmitExpr(MatchStmt.Expr), StringReplace(CaseNode.Pattern.SubPattern, '.', '_', [rfReplaceAll])]))
        else
          Emit(Format('if (%s.is_err) {', [EmitExpr(MatchStmt.Expr)]));

        IncIndent;
        for J := 0 to CaseNode.Body.Count - 1 do
          EmitStmt(TASTStmt(CaseNode.Body[J]));
        DecIndent;
        Emit('}');
      end;
    end;
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
  Emit('');
end;

procedure TAetherEmitterC.EmitFunction(Func: TASTFunction);
var
  ParamListStr: string;
  I: Integer;
  Param: TASTParam;
  ModStr: string;
  VarDecl: TASTVarDecl;
begin
  if Func.GenericParam <> '' then Exit; // Molde generico nao emite codigo diretamente
  if Func.IsExtern then
  begin
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

  Emit(Format('%s %s(%s) {', [EmitTypeRef(Func.ReturnType), Func.Name, ParamListStr]));
  IncIndent;

  // Asserts de Pre-condicao
  for I := 0 to Func.Requires.Count - 1 do
    Emit(Format('assert(%s);', [EmitExpr(TASTExpr(Func.Requires[I]))]));

  // Variaveis Locais
  for I := 0 to Func.LocalVars.Count - 1 do
  begin
    VarDecl := TASTVarDecl(Func.LocalVars[I]);
    Emit(Format('%s %s;', [EmitTypeRef(VarDecl.TypeName), VarDecl.Name]));
  end;

  // Corpo
  for I := 0 to Func.Body.Count - 1 do
    EmitStmt(TASTStmt(Func.Body[I]));

  DecIndent;
  Emit('}');
  Emit('');
  FCurrentFunc := nil;
end;

procedure TAetherEmitterC.EmitProgramBlock(Prog: TASTProgramBlock);
var
  I: Integer;
  VarDecl: TASTVarDecl;
begin
  FCurrentFunc := nil;
  FProgramBlock := Prog;
  Emit('int main(int argc, char* argv[]) {');
  IncIndent;
  for I := 0 to Prog.LocalVars.Count - 1 do
  begin
    VarDecl := TASTVarDecl(Prog.LocalVars[I]);
    Emit(Format('%s %s;', [EmitTypeRef(VarDecl.TypeName), VarDecl.Name]));
  end;

  for I := 0 to Prog.Body.Count - 1 do
    EmitStmt(TASTStmt(Prog.Body[I]));

  Emit('return 0;');
  DecIndent;
  Emit('}');
end;

function TAetherEmitterC.Generate(AModule: TASTModule): string;
var
  I, J: Integer;
  Func: TASTFunction;
  Param: TASTParam;
  ParamListStr, ModStr: string;
begin
  FModule := AModule;
  FOutput.Clear;
  FIndent := 0;

  Emit('// Codigo gerado automaticamente pelo Compilador Aether (aetherc)');
  Emit('// Alvo: C99 / GCC (MSYS2)');
  Emit('#include <stdio.h>');
  Emit('#include <stdlib.h>');
  Emit('#include <stdint.h>');
  Emit('#include <stdbool.h>');
  Emit('#include <string.h>');
  Emit('#include <assert.h>');
  Emit('#include <math.h>');
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
  Emit('static inline char* AetherIntToStr(int32_t val) {');
  Emit('    char* buf = (char*)malloc(32);');
  Emit('    snprintf(buf, 32, "%d", val);');
  Emit('    return buf;');
  Emit('}');
  Emit('');
  Emit('static inline int32_t AetherStrToInt(const char* s) {');
  Emit('    if (!s) return 0;');
  Emit('    return (int32_t)atoi(s);');
  Emit('}');
  Emit('');

  // Estrutura Result para C
  Emit('typedef struct {');
  Emit('    bool is_ok;');
  Emit('    bool is_err;');
  Emit('    double value;');
  Emit('    int error;');
  Emit('} AetherResult;');
  Emit('');

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
      EmitEnumDecl(TASTEnumDecl(AModule.Types[I]));
  end;
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
      Emit(Format('%s %s(%s);', [EmitTypeRef(Func.ReturnType), Func.Name, ParamListStr]));
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
