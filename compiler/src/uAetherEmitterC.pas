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

    procedure Emit(const Line: string = '');
    procedure IncIndent;
    procedure DecIndent;
    function IndentStr: string;

    function IsEnumName(const AName: string): Boolean;
    function IsMutBorrowParam(const AName: string): Boolean;
    function FindFunction(const AName: string): TASTFunction;
    function EscapeCString(const S: string): string;

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
         (TASTEnumDecl(FModule.Types[I]).Name = AName) then
        Exit(True);
end;

function TAetherEmitterC.IsMutBorrowParam(const AName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Assigned(FCurrentFunc) then
    for I := 0 to FCurrentFunc.Params.Count - 1 do
      if (TASTParam(FCurrentFunc.Params[I]).Name = AName) and
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
      if TASTFunction(FModule.Functions[I]).Name = AName then
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

function TAetherEmitterC.EmitTypeRef(const AType: string): string;
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
  ArgsStr: string;
  ArgVal: string;
  I: Integer;
  OpStr: string;
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
    Result := Id.Name;
    Exit;
  end;

  if Expr is TASTMemberAccessExpr then
  begin
    Acc := TASTMemberAccessExpr(Expr);
    if (Acc.Target is TASTIdentifierExpr) and IsEnumName(TASTIdentifierExpr(Acc.Target).Name) then
      Result := TASTIdentifierExpr(Acc.Target).Name + '_' + Acc.Member
    else
    begin
      if (Acc.Target is TASTIdentifierExpr) and IsMutBorrowParam(TASTIdentifierExpr(Acc.Target).Name) then
        Result := EmitExpr(Acc.Target) + '->' + Acc.Member
      else
        Result := EmitExpr(Acc.Target) + '.' + Acc.Member;
    end;
    Exit;
  end;

  if Expr is TASTBinaryExpr then
  begin
    Bin := TASTBinaryExpr(Expr);
    OpStr := Bin.Op;
    if OpStr = '=' then OpStr := '=='
    else if OpStr = '<>' then OpStr := '!='
    else if OpStr = 'and' then OpStr := '&&'
    else if OpStr = 'or' then OpStr := '||'
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

    // Construtor ou chamada normal
    FuncDecl := FindFunction(Call.Callee);
    ArgsStr := '';
    for I := 0 to Call.Args.Count - 1 do
    begin
      ArgVal := EmitExpr(TASTCallArg(Call.Args[I]).Expr);
      if Assigned(FuncDecl) and (I < FuncDecl.Params.Count) and
         (TASTParam(FuncDecl.Params[I]).Ownership = owMutBorrow) then
      begin
        if not ((TASTCallArg(Call.Args[I]).Expr is TASTIdentifierExpr) and
                IsMutBorrowParam(TASTIdentifierExpr(TASTCallArg(Call.Args[I]).Expr).Name)) then
          ArgVal := '&' + ArgVal;
      end;
      ArgsStr := ArgsStr + ArgVal;
      if I < Call.Args.Count - 1 then
        ArgsStr := ArgsStr + ', ';
    end;
    Result := Call.Callee + '(' + ArgsStr + ')';
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
  Emit(Format('typedef struct {', []));
  IncIndent;
  for I := 0 to Rec.Fields.Count - 1 do
  begin
    Field := TASTRecordField(Rec.Fields[I]);
    Emit(Format('%s %s;', [EmitTypeRef(Field.TypeName), Field.Name]));
  end;
  DecIndent;
  Emit(Format('} T%s;', [Rec.Name]));
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
  I: Integer;
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
  Emit('#include <assert.h>');
  Emit('#include <math.h>');
  Emit('');

  // Estrutura Result para C
  Emit('typedef struct {');
  Emit('    bool is_ok;');
  Emit('    bool is_err;');
  Emit('    double value;');
  Emit('    int error;');
  Emit('} AetherResult;');
  Emit('');

  // Tipos
  for I := 0 to AModule.Types.Count - 1 do
  begin
    if AModule.Types[I] is TASTRecordDecl then
      EmitRecordDecl(TASTRecordDecl(AModule.Types[I]))
    else if AModule.Types[I] is TASTEnumDecl then
      EmitEnumDecl(TASTEnumDecl(AModule.Types[I]));
  end;

  // Funções
  for I := 0 to AModule.Functions.Count - 1 do
    EmitFunction(TASTFunction(AModule.Functions[I]));

  // Bloco do Programa
  if Assigned(AModule.ProgramBlock) then
    EmitProgramBlock(AModule.ProgramBlock);

  Result := FOutput.Text;
end;

end.
