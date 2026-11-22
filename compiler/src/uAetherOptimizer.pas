unit uAetherOptimizer;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, uAetherAST;

type
  TOptimizerStats = record
    FoldedConstants: Integer;
    SimplifiedIdentities: Integer;
    EliminatedDeadBranches: Integer;
    EliminatedUnreachableStmts: Integer;
  end;

  { TAetherOptimizer }
  TAetherOptimizer = class
  private
    FStats: TOptimizerStats;
    function IsPureExpr(Expr: TASTExpr): Boolean;
    function OptimizeExpr(var Expr: TASTExpr): Boolean;
    function OptimizeUnaryExpr(Unary: TASTUnaryExpr; var NewExpr: TASTExpr): Boolean;
    function OptimizeBinaryExpr(Bin: TASTBinaryExpr; var NewExpr: TASTExpr): Boolean;
    function OptimizeStmt(var Stmt: TASTStmt): Boolean;
    procedure OptimizeBlock(Statements: TASTNodeList);
    procedure OptimizeFunction(Func: TASTFunction);
    procedure OptimizeProgramBlock(Prog: TASTProgramBlock);
  public
    constructor Create;
    function OptimizeModule(ModuleNode: TASTModule): Boolean;
    property Stats: TOptimizerStats read FStats;
  end;

implementation

{ TAetherOptimizer }

constructor TAetherOptimizer.Create;
begin
  inherited Create;
  FillChar(FStats, SizeOf(FStats), 0);
end;

function TAetherOptimizer.IsPureExpr(Expr: TASTExpr): Boolean;
begin
  if Expr = nil then Exit(True);
  if Expr is TASTLiteralExpr then Exit(True);
  if Expr is TASTIdentifierExpr then Exit(True);
  if Expr is TASTMemberAccessExpr then
    Exit(IsPureExpr(TASTMemberAccessExpr(Expr).Target));
  if Expr is TASTUnaryExpr then
    Exit(IsPureExpr(TASTUnaryExpr(Expr).Expr));
  if Expr is TASTBinaryExpr then
    Exit(IsPureExpr(TASTBinaryExpr(Expr).Left) and IsPureExpr(TASTBinaryExpr(Expr).Right));
  Result := False; // Chamadas de funções ou outras expressões podem ter efeitos colaterais
end;

function TAetherOptimizer.OptimizeUnaryExpr(Unary: TASTUnaryExpr; var NewExpr: TASTExpr): Boolean;
var
  Child: TASTExpr;
  Lit: TASTLiteralExpr;
  V: Int64;
  F: Double;
  SubUnary: TASTUnaryExpr;
begin
  Result := False;
  NewExpr := nil;
  if Unary = nil then Exit;

  // Primeiro otimiza o filho recursivamente
  OptimizeExpr(Unary.Expr);
  Child := Unary.Expr;

  // 1. Simplificação de dupla negação: not (not X) -> X
  if ((Unary.Op = 'not') or (Unary.Op = '!')) and (Child is TASTUnaryExpr) then
  begin
    SubUnary := TASTUnaryExpr(Child);
    if (SubUnary.Op = 'not') or (SubUnary.Op = '!') then
    begin
      NewExpr := SubUnary.Expr;
      SubUnary.Expr := nil; // Desconecta para não liberar na destruição
      Inc(FStats.SimplifiedIdentities);
      Exit(True);
    end;
  end;

  // 2. Dobra de constantes com literais
  if Child is TASTLiteralExpr then
  begin
    Lit := TASTLiteralExpr(Child);
    if ((Unary.Op = 'not') or (Unary.Op = '!')) and (Lit.Kind = lkBool) then
    begin
      if SameText(Lit.Value, 'true') then
        NewExpr := TASTLiteralExpr.Create(Unary.Line, Unary.Col, lkBool, 'false')
      else
        NewExpr := TASTLiteralExpr.Create(Unary.Line, Unary.Col, lkBool, 'true');
      Inc(FStats.FoldedConstants);
      Exit(True);
    end;

    if (Unary.Op = '-') and (Lit.Kind = lkInt) then
    begin
      V := StrToInt64Def(Lit.Value, 0);
      NewExpr := TASTLiteralExpr.Create(Unary.Line, Unary.Col, lkInt, IntToStr(-V));
      Inc(FStats.FoldedConstants);
      Exit(True);
    end;

    if (Unary.Op = '-') and (Lit.Kind = lkFloat) then
    begin
      F := StrToFloatDef(Lit.Value, 0.0);
      NewExpr := TASTLiteralExpr.Create(Unary.Line, Unary.Col, lkFloat, FloatToStr(-F));
      Inc(FStats.FoldedConstants);
      Exit(True);
    end;

    if (Unary.Op = '+') and ((Lit.Kind = lkInt) or (Lit.Kind = lkFloat)) then
    begin
      NewExpr := TASTLiteralExpr.Create(Unary.Line, Unary.Col, Lit.Kind, Lit.Value);
      Inc(FStats.SimplifiedIdentities);
      Exit(True);
    end;
  end;
end;

function TAetherOptimizer.OptimizeBinaryExpr(Bin: TASTBinaryExpr; var NewExpr: TASTExpr): Boolean;
var
  LeftLit, RightLit: TASTLiteralExpr;
  LVal, RVal: Int64;
  LFloat, RFloat: Double;
  LBool, RBool, ResBool: Boolean;
  Op: string;
begin
  Result := False;
  NewExpr := nil;
  if Bin = nil then Exit;

  // Otimiza ambos os lados recursivamente
  OptimizeExpr(Bin.Left);
  OptimizeExpr(Bin.Right);

  Op := LowerCase(Trim(Bin.Op));

  // --- CASO 1: AMBOS OS LADOS SÃO LITERAIS (Constant Folding Completo) ---
  if (Bin.Left is TASTLiteralExpr) and (Bin.Right is TASTLiteralExpr) then
  begin
    LeftLit := TASTLiteralExpr(Bin.Left);
    RightLit := TASTLiteralExpr(Bin.Right);

    // Inteiros
    if (LeftLit.Kind = lkInt) and (RightLit.Kind = lkInt) then
    begin
      LVal := StrToInt64Def(LeftLit.Value, 0);
      RVal := StrToInt64Def(RightLit.Value, 0);

      if Op = '+' then
      begin
        NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkInt, IntToStr(LVal + RVal));
        Inc(FStats.FoldedConstants);
        Exit(True);
      end
      else if Op = '-' then
      begin
        NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkInt, IntToStr(LVal - RVal));
        Inc(FStats.FoldedConstants);
        Exit(True);
      end
      else if Op = '*' then
      begin
        NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkInt, IntToStr(LVal * RVal));
        Inc(FStats.FoldedConstants);
        Exit(True);
      end
      else if ((Op = '/') or (Op = 'div')) and (RVal <> 0) then
      begin
        NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkInt, IntToStr(LVal div RVal));
        Inc(FStats.FoldedConstants);
        Exit(True);
      end
      else if (Op = '%') and (RVal <> 0) then
      begin
        NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkInt, IntToStr(LVal mod RVal));
        Inc(FStats.FoldedConstants);
        Exit(True);
      end
      else if (Op = '==') or (Op = '=') then
      begin
        ResBool := (LVal = RVal);
        if ResBool then NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkBool, 'true')
        else NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkBool, 'false');
        Inc(FStats.FoldedConstants);
        Exit(True);
      end
      else if (Op = '!=') or (Op = '<>') then
      begin
        ResBool := (LVal <> RVal);
        if ResBool then NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkBool, 'true')
        else NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkBool, 'false');
        Inc(FStats.FoldedConstants);
        Exit(True);
      end
      else if Op = '<' then
      begin
        ResBool := (LVal < RVal);
        if ResBool then NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkBool, 'true')
        else NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkBool, 'false');
        Inc(FStats.FoldedConstants);
        Exit(True);
      end
      else if Op = '<=' then
      begin
        ResBool := (LVal <= RVal);
        if ResBool then NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkBool, 'true')
        else NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkBool, 'false');
        Inc(FStats.FoldedConstants);
        Exit(True);
      end
      else if Op = '>' then
      begin
        ResBool := (LVal > RVal);
        if ResBool then NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkBool, 'true')
        else NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkBool, 'false');
        Inc(FStats.FoldedConstants);
        Exit(True);
      end
      else if Op = '>=' then
      begin
        ResBool := (LVal >= RVal);
        if ResBool then NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkBool, 'true')
        else NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkBool, 'false');
        Inc(FStats.FoldedConstants);
        Exit(True);
      end;
    end;

    // Floats
    if (LeftLit.Kind = lkFloat) and (RightLit.Kind = lkFloat) then
    begin
      LFloat := StrToFloatDef(LeftLit.Value, 0.0);
      RFloat := StrToFloatDef(RightLit.Value, 0.0);

      if Op = '+' then
      begin
        NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkFloat, FloatToStr(LFloat + RFloat));
        Inc(FStats.FoldedConstants);
        Exit(True);
      end
      else if Op = '-' then
      begin
        NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkFloat, FloatToStr(LFloat - RFloat));
        Inc(FStats.FoldedConstants);
        Exit(True);
      end
      else if Op = '*' then
      begin
        NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkFloat, FloatToStr(LFloat * RFloat));
        Inc(FStats.FoldedConstants);
        Exit(True);
      end
      else if (Op = '/') and (RFloat <> 0.0) then
      begin
        NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkFloat, FloatToStr(LFloat / RFloat));
        Inc(FStats.FoldedConstants);
        Exit(True);
      end;
    end;

    // Booleanos
    if (LeftLit.Kind = lkBool) and (RightLit.Kind = lkBool) then
    begin
      LBool := SameText(LeftLit.Value, 'true');
      RBool := SameText(RightLit.Value, 'true');

      if Op = 'and' then
      begin
        ResBool := LBool and RBool;
        if ResBool then NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkBool, 'true')
        else NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkBool, 'false');
        Inc(FStats.FoldedConstants);
        Exit(True);
      end
      else if Op = 'or' then
      begin
        ResBool := LBool or RBool;
        if ResBool then NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkBool, 'true')
        else NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkBool, 'false');
        Inc(FStats.FoldedConstants);
        Exit(True);
      end
      else if (Op = '==') or (Op = '=') then
      begin
        ResBool := (LBool = RBool);
        if ResBool then NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkBool, 'true')
        else NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkBool, 'false');
        Inc(FStats.FoldedConstants);
        Exit(True);
      end
      else if (Op = '!=') or (Op = '<>') then
      begin
        ResBool := (LBool <> RBool);
        if ResBool then NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkBool, 'true')
        else NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkBool, 'false');
        Inc(FStats.FoldedConstants);
        Exit(True);
      end;
    end;

    // Concatenação de Strings
    if (LeftLit.Kind = lkString) and (RightLit.Kind = lkString) and (Op = '+') then
    begin
      NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkString, LeftLit.Value + RightLit.Value);
      Inc(FStats.FoldedConstants);
      Exit(True);
    end;
  end;

  // --- CASO 2: IDENTIDADES ALGÉBRICAS E CURTO-CIRCUITO ---
  // Identidades com Inteiro 0 e 1
  if Op = '+' then
  begin
    // 0 + X -> X
    if (Bin.Left is TASTLiteralExpr) and (TASTLiteralExpr(Bin.Left).Kind = lkInt) and (TASTLiteralExpr(Bin.Left).Value = '0') then
    begin
      NewExpr := Bin.Right;
      Bin.Right := nil;
      Inc(FStats.SimplifiedIdentities);
      Exit(True);
    end;
    // X + 0 -> X
    if (Bin.Right is TASTLiteralExpr) and (TASTLiteralExpr(Bin.Right).Kind = lkInt) and (TASTLiteralExpr(Bin.Right).Value = '0') then
    begin
      NewExpr := Bin.Left;
      Bin.Left := nil;
      Inc(FStats.SimplifiedIdentities);
      Exit(True);
    end;
  end
  else if Op = '-' then
  begin
    // X - 0 -> X
    if (Bin.Right is TASTLiteralExpr) and (TASTLiteralExpr(Bin.Right).Kind = lkInt) and (TASTLiteralExpr(Bin.Right).Value = '0') then
    begin
      NewExpr := Bin.Left;
      Bin.Left := nil;
      Inc(FStats.SimplifiedIdentities);
      Exit(True);
    end;
  end
  else if Op = '*' then
  begin
    // 1 * X -> X
    if (Bin.Left is TASTLiteralExpr) and (TASTLiteralExpr(Bin.Left).Kind = lkInt) and (TASTLiteralExpr(Bin.Left).Value = '1') then
    begin
      NewExpr := Bin.Right;
      Bin.Right := nil;
      Inc(FStats.SimplifiedIdentities);
      Exit(True);
    end;
    // X * 1 -> X
    if (Bin.Right is TASTLiteralExpr) and (TASTLiteralExpr(Bin.Right).Kind = lkInt) and (TASTLiteralExpr(Bin.Right).Value = '1') then
    begin
      NewExpr := Bin.Left;
      Bin.Left := nil;
      Inc(FStats.SimplifiedIdentities);
      Exit(True);
    end;
    // 0 * X -> 0 (se X for puro)
    if (Bin.Left is TASTLiteralExpr) and (TASTLiteralExpr(Bin.Left).Kind = lkInt) and (TASTLiteralExpr(Bin.Left).Value = '0') and IsPureExpr(Bin.Right) then
    begin
      NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkInt, '0');
      Inc(FStats.SimplifiedIdentities);
      Exit(True);
    end;
    // X * 0 -> 0 (se X for puro)
    if (Bin.Right is TASTLiteralExpr) and (TASTLiteralExpr(Bin.Right).Kind = lkInt) and (TASTLiteralExpr(Bin.Right).Value = '0') and IsPureExpr(Bin.Left) then
    begin
      NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkInt, '0');
      Inc(FStats.SimplifiedIdentities);
      Exit(True);
    end;
  end
  else if (Op = '/') or (Op = 'div') then
  begin
    // X / 1 -> X
    if (Bin.Right is TASTLiteralExpr) and (TASTLiteralExpr(Bin.Right).Kind = lkInt) and (TASTLiteralExpr(Bin.Right).Value = '1') then
    begin
      NewExpr := Bin.Left;
      Bin.Left := nil;
      Inc(FStats.SimplifiedIdentities);
      Exit(True);
    end;
  end
  else if Op = 'and' then
  begin
    // false and X -> false (curto-circuito puro)
    if (Bin.Left is TASTLiteralExpr) and (TASTLiteralExpr(Bin.Left).Kind = lkBool) and (SameText(TASTLiteralExpr(Bin.Left).Value, 'false')) then
    begin
      NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkBool, 'false');
      Inc(FStats.SimplifiedIdentities);
      Exit(True);
    end;
    // true and X -> X
    if (Bin.Left is TASTLiteralExpr) and (TASTLiteralExpr(Bin.Left).Kind = lkBool) and (SameText(TASTLiteralExpr(Bin.Left).Value, 'true')) then
    begin
      NewExpr := Bin.Right;
      Bin.Right := nil;
      Inc(FStats.SimplifiedIdentities);
      Exit(True);
    end;
    // X and true -> X
    if (Bin.Right is TASTLiteralExpr) and (TASTLiteralExpr(Bin.Right).Kind = lkBool) and (SameText(TASTLiteralExpr(Bin.Right).Value, 'true')) then
    begin
      NewExpr := Bin.Left;
      Bin.Left := nil;
      Inc(FStats.SimplifiedIdentities);
      Exit(True);
    end;
  end
  else if Op = 'or' then
  begin
    // true or X -> true (curto-circuito)
    if (Bin.Left is TASTLiteralExpr) and (TASTLiteralExpr(Bin.Left).Kind = lkBool) and (SameText(TASTLiteralExpr(Bin.Left).Value, 'true')) then
    begin
      NewExpr := TASTLiteralExpr.Create(Bin.Line, Bin.Col, lkBool, 'true');
      Inc(FStats.SimplifiedIdentities);
      Exit(True);
    end;
    // false or X -> X
    if (Bin.Left is TASTLiteralExpr) and (TASTLiteralExpr(Bin.Left).Kind = lkBool) and (SameText(TASTLiteralExpr(Bin.Left).Value, 'false')) then
    begin
      NewExpr := Bin.Right;
      Bin.Right := nil;
      Inc(FStats.SimplifiedIdentities);
      Exit(True);
    end;
    // X or false -> X
    if (Bin.Right is TASTLiteralExpr) and (TASTLiteralExpr(Bin.Right).Kind = lkBool) and (SameText(TASTLiteralExpr(Bin.Right).Value, 'false')) then
    begin
      NewExpr := Bin.Left;
      Bin.Left := nil;
      Inc(FStats.SimplifiedIdentities);
      Exit(True);
    end;
  end;
end;

function TAetherOptimizer.OptimizeExpr(var Expr: TASTExpr): Boolean;
var
  NewExpr: TASTExpr;
  CallExpr: TASTCallExpr;
  CallArg: TASTCallArg;
  I: Integer;
begin
  Result := False;
  if Expr = nil then Exit;

  if Expr is TASTUnaryExpr then
  begin
    if OptimizeUnaryExpr(TASTUnaryExpr(Expr), NewExpr) then
    begin
      Expr.Free;
      Expr := NewExpr;
      Result := True;
      // Tenta otimizar a nova expressao resultante
      OptimizeExpr(Expr);
    end;
  end
  else if Expr is TASTBinaryExpr then
  begin
    if OptimizeBinaryExpr(TASTBinaryExpr(Expr), NewExpr) then
    begin
      Expr.Free;
      Expr := NewExpr;
      Result := True;
      // Tenta otimizar a nova expressao resultante
      OptimizeExpr(Expr);
    end;
  end
  else if Expr is TASTMemberAccessExpr then
  begin
    OptimizeExpr(TASTMemberAccessExpr(Expr).Target);
  end
  else if Expr is TASTCallExpr then
  begin
    CallExpr := TASTCallExpr(Expr);
    if Assigned(CallExpr.Args) then
    begin
      for I := 0 to CallExpr.Args.Count - 1 do
      begin
        CallArg := TASTCallArg(CallExpr.Args[I]);
        if Assigned(CallArg.Expr) then
          OptimizeExpr(CallArg.Expr);
      end;
    end;
  end
  else if Expr is TASTIndexExpr then
  begin
    OptimizeExpr(TASTIndexExpr(Expr).Target);
    if Assigned(TASTIndexExpr(Expr).Indices) then
    begin
      for I := 0 to TASTIndexExpr(Expr).Indices.Count - 1 do
      begin
        NewExpr := TASTExpr(TASTIndexExpr(Expr).Indices[I]);
        OptimizeExpr(NewExpr);
        TASTIndexExpr(Expr).Indices[I] := NewExpr;
      end;
    end;
  end
  else if Expr is TASTSetLiteralExpr then
  begin
    if Assigned(TASTSetLiteralExpr(Expr).Elements) then
    begin
      for I := 0 to TASTSetLiteralExpr(Expr).Elements.Count - 1 do
      begin
        NewExpr := TASTExpr(TASTSetLiteralExpr(Expr).Elements[I]);
        OptimizeExpr(NewExpr);
        TASTSetLiteralExpr(Expr).Elements[I] := NewExpr;
      end;
    end;
  end;
end;

function TAetherOptimizer.OptimizeStmt(var Stmt: TASTStmt): Boolean;
var
  IfStmt: TASTIfStmt;
  WhileStmt: TASTWhileStmt;
  ForStmt: TASTForStmt;
  RepeatStmt: TASTRepeatStmt;
  AssignStmt: TASTAssignStmt;
  ReturnStmt: TASTReturnStmt;
  CallStmt: TASTCallStmt;
begin
  Result := False;
  if Stmt = nil then Exit;

  if Stmt is TASTAssignStmt then
  begin
    AssignStmt := TASTAssignStmt(Stmt);
    OptimizeExpr(AssignStmt.Target);
    OptimizeExpr(AssignStmt.Expr);
  end
  else if Stmt is TASTReturnStmt then
  begin
    ReturnStmt := TASTReturnStmt(Stmt);
    if Assigned(ReturnStmt.Expr) then
      OptimizeExpr(ReturnStmt.Expr);
  end
  else if Stmt is TASTCallStmt then
  begin
    CallStmt := TASTCallStmt(Stmt);
    if Assigned(CallStmt.CallExpr) then
    begin
      // Otimiza o TASTCallExpr
      OptimizeExpr(TASTExpr(CallStmt.CallExpr));
    end;
  end
  else if Stmt is TASTIfStmt then
  begin
    IfStmt := TASTIfStmt(Stmt);
    OptimizeExpr(IfStmt.Condition);
    if Assigned(IfStmt.ThenBranch) then
      OptimizeBlock(IfStmt.ThenBranch);
    if Assigned(IfStmt.ElseBranch) then
      OptimizeBlock(IfStmt.ElseBranch);
  end
  else if Stmt is TASTWhileStmt then
  begin
    WhileStmt := TASTWhileStmt(Stmt);
    OptimizeExpr(WhileStmt.Condition);
    if Assigned(WhileStmt.Body) then
      OptimizeBlock(WhileStmt.Body);
  end
  else if Stmt is TASTForStmt then
  begin
    ForStmt := TASTForStmt(Stmt);
    OptimizeExpr(ForStmt.StartExpr);
    OptimizeExpr(ForStmt.EndExpr);
    if Assigned(ForStmt.Body) then
      OptimizeBlock(ForStmt.Body);
  end
  else if Stmt is TASTRepeatStmt then
  begin
    RepeatStmt := TASTRepeatStmt(Stmt);
    if Assigned(RepeatStmt.Body) then
      OptimizeBlock(RepeatStmt.Body);
    if Assigned(RepeatStmt.Condition) then
      OptimizeExpr(RepeatStmt.Condition);
  end;
end;

procedure TAetherOptimizer.OptimizeBlock(Statements: TASTNodeList);
var
  I, J: Integer;
  Stmt: TASTStmt;
  IfStmt: TASTIfStmt;
  WhileStmt: TASTWhileStmt;
  ForStmt: TASTForStmt;
  CondLit: TASTLiteralExpr;
  HasReturn: Boolean;
begin
  if Statements = nil then Exit;

  // 1. Otimiza cada instrução individualmente (expressões e sub-blocos)
  for I := 0 to Statements.Count - 1 do
  begin
    Stmt := TASTStmt(Statements[I]);
    OptimizeStmt(Stmt);
  end;

  // 2. Dead Code Elimination (DCE) em nível de bloco
  I := 0;
  HasReturn := False;
  while I < Statements.Count do
  begin
    Stmt := TASTStmt(Statements[I]);

    // A. Instruções inalcançáveis após return incondicional
    if HasReturn then
    begin
      Statements.Delete(I);
      Inc(FStats.EliminatedUnreachableStmts);
      Continue;
    end;

    if Stmt is TASTReturnStmt then
    begin
      HasReturn := True;
      Inc(I);
      Continue;
    end;

    // B. IfStmt com condição constante dobrada (true/false)
    if Stmt is TASTIfStmt then
    begin
      IfStmt := TASTIfStmt(Stmt);
      if (IfStmt.Condition is TASTLiteralExpr) and (TASTLiteralExpr(IfStmt.Condition).Kind = lkBool) then
      begin
        CondLit := TASTLiteralExpr(IfStmt.Condition);
        if SameText(CondLit.Value, 'true') then
        begin
          // O ramo then sempre executa! Promove o ThenBranch e descarta o ElseBranch
          Statements.ExtractIndex(I); // Remove o IfStmt da lista sem desalocar seus ramos ainda
          if Assigned(IfStmt.ThenBranch) then
          begin
            for J := 0 to IfStmt.ThenBranch.Count - 1 do
            begin
              Statements.Insert(I + J, IfStmt.ThenBranch.ExtractIndex(0));
            end;
          end;
          IfStmt.Free;
          Inc(FStats.EliminatedDeadBranches);
          Continue;
        end
        else if SameText(CondLit.Value, 'false') then
        begin
          // O ramo then nunca executa! Promove o ElseBranch se existir, ou apenas remove
          Statements.ExtractIndex(I);
          if Assigned(IfStmt.ElseBranch) then
          begin
            for J := 0 to IfStmt.ElseBranch.Count - 1 do
            begin
              Statements.Insert(I + J, IfStmt.ElseBranch.ExtractIndex(0));
            end;
          end;
          IfStmt.Free;
          Inc(FStats.EliminatedDeadBranches);
          Continue;
        end;
      end;
    end;

    // C. WhileStmt com condição false (loop inalcançável)
    if Stmt is TASTWhileStmt then
    begin
      WhileStmt := TASTWhileStmt(Stmt);
      if (WhileStmt.Condition is TASTLiteralExpr) and (TASTLiteralExpr(WhileStmt.Condition).Kind = lkBool) then
      begin
        CondLit := TASTLiteralExpr(WhileStmt.Condition);
        if SameText(CondLit.Value, 'false') then
        begin
          Statements.Delete(I);
          Inc(FStats.EliminatedDeadBranches);
          Continue;
        end;
      end;
    end;

    Inc(I);
  end;
end;

procedure TAetherOptimizer.OptimizeFunction(Func: TASTFunction);
var
  I: Integer;
  VarDecl: TASTVarDecl;
begin
  if Func = nil then Exit;

  // Otimiza expressões iniciais de variáveis locais
  if Assigned(Func.LocalVars) then
  begin
    for I := 0 to Func.LocalVars.Count - 1 do
    begin
      VarDecl := TASTVarDecl(Func.LocalVars[I]);
      if Assigned(VarDecl.InitialExpr) then
        OptimizeExpr(VarDecl.InitialExpr);
    end;
  end;

  // Otimiza o corpo da função
  if Assigned(Func.Body) then
    OptimizeBlock(Func.Body);
end;

procedure TAetherOptimizer.OptimizeProgramBlock(Prog: TASTProgramBlock);
var
  I: Integer;
  VarDecl: TASTVarDecl;
begin
  if Prog = nil then Exit;

  if Assigned(Prog.LocalVars) then
  begin
    for I := 0 to Prog.LocalVars.Count - 1 do
    begin
      VarDecl := TASTVarDecl(Prog.LocalVars[I]);
      if Assigned(VarDecl.InitialExpr) then
        OptimizeExpr(VarDecl.InitialExpr);
    end;
  end;

  if Assigned(Prog.Body) then
    OptimizeBlock(Prog.Body);
end;

function TAetherOptimizer.OptimizeModule(ModuleNode: TASTModule): Boolean;
var
  I, K: Integer;
  Item: TASTNode;
  ImplDecl: TASTImplDecl;
begin
  Result := False;
  if ModuleNode = nil then Exit;

  // 1. Otimiza funções e blocos no módulo
  if Assigned(ModuleNode.Functions) then
  begin
    for I := 0 to ModuleNode.Functions.Count - 1 do
    begin
      Item := ModuleNode.Functions[I];
      if Item is TASTFunction then
        OptimizeFunction(TASTFunction(Item))
      else if Item is TASTImplDecl then
      begin
        ImplDecl := TASTImplDecl(Item);
        if Assigned(ImplDecl.Methods) then
        begin
          for K := 0 to ImplDecl.Methods.Count - 1 do
          begin
            if ImplDecl.Methods[K] is TASTFunction then
              OptimizeFunction(TASTFunction(ImplDecl.Methods[K]));
          end;
        end;
      end;
    end;
  end;

  // 2. Otimiza o bloco principal do programa
  if Assigned(ModuleNode.ProgramBlock) then
    OptimizeProgramBlock(ModuleNode.ProgramBlock);

  Result := (FStats.FoldedConstants > 0) or
            (FStats.SimplifiedIdentities > 0) or
            (FStats.EliminatedDeadBranches > 0) or
            (FStats.EliminatedUnreachableStmts > 0);
end;

end.
