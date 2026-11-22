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
    if (Call.Callee = 'ReadFile') or (Call.Callee = 'CharAt') or (Call.Callee = 'Substring') or (Call.Callee = 'ToString') or (Call.Callee = 'IntToStr') or (Call.Callee = 'SocketRecv') or (Call.Callee = 'ParamStr') then Exit('String');
    if (Call.Callee = 'Length') or (Call.Callee = 'StrToInt') or (Call.Callee = 'SocketCreate') or (Call.Callee = 'SocketListen') or (Call.Callee = 'SocketAccept') or (Call.Callee = 'SocketConnect') or (Call.Callee = 'SocketSend') or (Call.Callee = 'ParamCount') then Exit('Int32');
    if (Call.Callee = 'sin') or (Call.Callee = 'cos') or (Call.Callee = 'tan') or (Call.Callee = 'sqrt') or (Call.Callee = 'Now') then Exit('Float64');
    if (Call.Callee = 'GetTickCount64') or (Call.Callee = 'GetNanoseconds') then Exit('UInt64');
    if (Call.Callee = 'FileSize') then Exit('Int64');
    if (Call.Callee = 'FileExists') or (Call.Callee = 'WriteFile') or (Call.Callee = 'CreateDir') or (Call.Callee = 'RemoveDir') or (Call.Callee = 'DeleteFile') or (Call.Callee = 'DirExists') then Exit('Bool');
    if (Call.Callee = 'SocketClose') or (Call.Callee = 'Assert') or (Call.Callee = 'SleepMs') then Exit('Void');
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
  ArgType: string;
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

    if (Call.Callee = 'PrintLn') or (Call.Callee = 'WriteLn') then
    begin
      if Call.Args.Count = 1 then
      begin
        ArgType := GetExprTypeName(TASTCallArg(Call.Args[0]).Expr);
        if (ArgType = 'Int32') or (ArgType = 'Int16') or (ArgType = 'Int8') or (ArgType = 'UInt16') or (ArgType = 'UInt8') then
          Result := 'printf("%d\n", ' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')'
        else if (ArgType = 'Int64') or (ArgType = 'UInt64') or (ArgType = 'UInt32') then
          Result := 'printf("%lld\n", (long long)(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '))'
        else if (ArgType = 'Float64') or (ArgType = 'Float32') then
          Result := 'printf("%f\n", ' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')'
        else if (ArgType = 'Bool') then
          Result := 'printf("%s\n", (' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ') ? "true" : "false")'
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
  Lines: TStringList;
  LineStr: string;
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
  Emit('g_aether_argc = argc;');
  Emit('g_aether_argv = argv;');
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
  Emit('static inline char* AetherIntToStr(int32_t val) {');
  Emit('#if defined(__wasm__)');
  Emit('    char* buf = (char*)malloc(32);');
  Emit('    if (!buf) return (char*)"";');
  Emit('    int idx = 0;');
  Emit('    uint32_t uval;');
  Emit('    if (val < 0) { buf[idx++] = ''-''; uval = (uint32_t)(-val); } else uval = (uint32_t)val;');
  Emit('    char tmp[32]; int t = 0;');
  Emit('    do { tmp[t++] = ''0'' + (uval % 10); uval /= 10; } while (uval > 0);');
  Emit('    while (t > 0) buf[idx++] = tmp[--t];');
  Emit('    buf[idx] = ''\0'';');
  Emit('    return buf;');
  Emit('#else');
  Emit('    char* buf = (char*)malloc(32);');
  Emit('    snprintf(buf, 32, "%d", val);');
  Emit('    return buf;');
  Emit('#endif');
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
    EmitProgramBlock(AModule.ProgramBlock)
  else
  begin
    Emit('#ifndef __wasm__');
    Emit('int main(int argc, char** argv) {');
    Emit('    (void)argc; (void)argv;');
    Emit('    return 0;');
    Emit('}');
    Emit('#endif');
  end;

  Result := FOutput.Text;
end;

end.
