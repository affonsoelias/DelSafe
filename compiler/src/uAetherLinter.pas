unit uAetherLinter;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  SysUtils, Classes,
  uAetherTokens, uAetherLexer, uAetherAST, uAetherParser;

type
  TLintSeverity = (lsHint, lsWarning, lsError);

  TLintIssue = record
    RuleId: string;
    RuleCode: string;
    Message: string;
    FileName: string;
    Line: Integer;
    Col: Integer;
    Severity: TLintSeverity;
    Fixable: Boolean;
    ExtraInfo: string;
  end;

  TLintResult = record
    FileName: string;
    Issues: array of TLintIssue;
    IssueCount: Integer;
    HasErrors: Boolean;
    HasWarnings: Boolean;
    FixedCount: Integer;
  end;

  TLintArrayResult = array of TLintResult;

  { TAetherLinter: Analisador Estático Oficial de Qualidade de Código do Aether }
  TAetherLinter = class
  private
    class procedure CollectIdentifiersInExpr(Expr: TASTExpr; IdentList: TStringList);
    class procedure CollectIdentifiersInStmt(Stmt: TASTStmt; IdentList: TStringList);
    class procedure CollectIdentifiersInNodeList(Nodes: TASTNodeList; IdentList: TStringList);
    class function IsPascalCase(const S: string): Boolean;
    class function FixUnusedImports(const FilePath: string; UnusedImports: TStringList): Integer;
  public
    class function AddIssue(var Res: TLintResult; const ARuleId, ARuleCode, AMessage, AFileName: string;
      ALine, ACol: Integer; ASeverity: TLintSeverity; AFixable: Boolean = False; const AExtra: string = ''): Integer;
    class function LintModule(const FilePath: string; AModule: TASTModule; Fix: Boolean = False): TLintResult;
    class function LintSource(const Source: string; const FileName: string = 'input.aeth'; Fix: Boolean = False): TLintResult;
    class function LintFile(const FilePath: string; Fix: Boolean = False): TLintResult;
    class procedure LintDirectory(const DirPath: string; Fix: Boolean; var TotalFiles, CleanFiles, IssueFiles, TotalIssues, TotalFixed: Integer; var Results: TLintArrayResult);
    class function FormatIssue(const Issue: TLintIssue): string;
    class function FormatJSON(const Results: array of TLintResult): string;
  end;

implementation

{ TAetherLinter }

class function TAetherLinter.AddIssue(var Res: TLintResult; const ARuleId, ARuleCode, AMessage, AFileName: string;
  ALine, ACol: Integer; ASeverity: TLintSeverity; AFixable: Boolean; const AExtra: string): Integer;
var
  Idx: Integer;
begin
  Idx := Length(Res.Issues);
  SetLength(Res.Issues, Idx + 1);
  Res.Issues[Idx].RuleId := ARuleId;
  Res.Issues[Idx].RuleCode := ARuleCode;
  Res.Issues[Idx].Message := AMessage;
  Res.Issues[Idx].FileName := AFileName;
  Res.Issues[Idx].Line := ALine;
  Res.Issues[Idx].Col := ACol;
  Res.Issues[Idx].Severity := ASeverity;
  Res.Issues[Idx].Fixable := AFixable;
  Res.Issues[Idx].ExtraInfo := AExtra;

  Inc(Res.IssueCount);
  if ASeverity = lsError then
    Res.HasErrors := True
  else
    Res.HasWarnings := True;

  Result := Idx;
end;

class function TAetherLinter.IsPascalCase(const S: string): Boolean;
begin
  if Length(S) = 0 then Exit(False);
  Result := S[1] in ['A'..'Z'];
end;

class procedure TAetherLinter.CollectIdentifiersInExpr(Expr: TASTExpr; IdentList: TStringList);
var
  I: Integer;
  CallExpr: TASTCallExpr;
  BinExpr: TASTBinaryExpr;
  UnExpr: TASTUnaryExpr;
  MemExpr: TASTMemberAccessExpr;
begin
  if not Assigned(Expr) then Exit;

  if Expr is TASTIdentifierExpr then
  begin
    IdentList.Add(TASTIdentifierExpr(Expr).Name);
  end
  else if Expr is TASTCallExpr then
  begin
    CallExpr := TASTCallExpr(Expr);
    IdentList.Add(CallExpr.Callee);
    for I := 0 to CallExpr.Args.Count - 1 do
      CollectIdentifiersInExpr(TASTCallArg(CallExpr.Args[I]).Expr, IdentList);
  end
  else if Expr is TASTBinaryExpr then
  begin
    BinExpr := TASTBinaryExpr(Expr);
    CollectIdentifiersInExpr(BinExpr.Left, IdentList);
    CollectIdentifiersInExpr(BinExpr.Right, IdentList);
  end
  else if Expr is TASTUnaryExpr then
  begin
    UnExpr := TASTUnaryExpr(Expr);
    CollectIdentifiersInExpr(UnExpr.Expr, IdentList);
  end
  else if Expr is TASTMemberAccessExpr then
  begin
    MemExpr := TASTMemberAccessExpr(Expr);
    CollectIdentifiersInExpr(MemExpr.Target, IdentList);
    IdentList.Add(MemExpr.Member);
  end
  else if Expr is TASTAwaitExpr then
  begin
    CollectIdentifiersInExpr(TASTAwaitExpr(Expr).Expr, IdentList);
  end
  else if Expr is TASTSpawnExpr then
  begin
    CollectIdentifiersInExpr(TASTSpawnExpr(Expr).CallExpr, IdentList);
  end
  else if Expr is TASTIndexExpr then
  begin
    CollectIdentifiersInExpr(TASTIndexExpr(Expr).Target, IdentList);
    for I := 0 to TASTIndexExpr(Expr).Indices.Count - 1 do
      CollectIdentifiersInExpr(TASTExpr(TASTIndexExpr(Expr).Indices[I]), IdentList);
  end
  else if Expr is TASTSetLiteralExpr then
  begin
    for I := 0 to TASTSetLiteralExpr(Expr).Elements.Count - 1 do
      CollectIdentifiersInExpr(TASTExpr(TASTSetLiteralExpr(Expr).Elements[I]), IdentList);
  end
  else if Expr is TASTMapLiteralExpr then
  begin
    for I := 0 to TASTMapLiteralExpr(Expr).Keys.Count - 1 do
    begin
      CollectIdentifiersInExpr(TASTExpr(TASTMapLiteralExpr(Expr).Keys[I]), IdentList);
      CollectIdentifiersInExpr(TASTExpr(TASTMapLiteralExpr(Expr).Values[I]), IdentList);
    end;
  end
  else if Expr is TASTIfExpr then
  begin
    CollectIdentifiersInExpr(TASTIfExpr(Expr).Condition, IdentList);
    CollectIdentifiersInExpr(TASTIfExpr(Expr).ThenExpr, IdentList);
    CollectIdentifiersInExpr(TASTIfExpr(Expr).ElseExpr, IdentList);
  end
  else if Expr is TASTMatchExpr then
  begin
    CollectIdentifiersInExpr(TASTMatchExpr(Expr).Expr, IdentList);
    for I := 0 to TASTMatchExpr(Expr).Cases.Count - 1 do
    begin
      if TASTMatchCase(TASTMatchExpr(Expr).Cases[I]).Pattern.SubPattern <> '' then
        IdentList.Add(TASTMatchCase(TASTMatchExpr(Expr).Cases[I]).Pattern.SubPattern);
      if Assigned(TASTMatchCase(TASTMatchExpr(Expr).Cases[I]).Guard) then
        CollectIdentifiersInExpr(TASTMatchCase(TASTMatchExpr(Expr).Cases[I]).Guard, IdentList);
      CollectIdentifiersInExpr(TASTMatchCase(TASTMatchExpr(Expr).Cases[I]).ValueExpr, IdentList);
    end;
  end;
end;

class procedure TAetherLinter.CollectIdentifiersInStmt(Stmt: TASTStmt; IdentList: TStringList);
var
  AssignStmt: TASTAssignStmt;
  CallStmt: TASTCallStmt;
  IfStmt: TASTIfStmt;
  WhileStmt: TASTWhileStmt;
  ForStmt: TASTForStmt;
  RepeatStmt: TASTRepeatStmt;
  MatchStmt: TASTMatchStmt;
  ReturnStmt: TASTReturnStmt;
  CaseNode: TASTMatchCase;
  I: Integer;
begin
  if not Assigned(Stmt) then Exit;

  if Stmt is TASTAssignStmt then
  begin
    AssignStmt := TASTAssignStmt(Stmt);
    CollectIdentifiersInExpr(AssignStmt.Target, IdentList);
    CollectIdentifiersInExpr(AssignStmt.Expr, IdentList);
  end
  else if Stmt is TASTCallStmt then
  begin
    CallStmt := TASTCallStmt(Stmt);
    CollectIdentifiersInExpr(CallStmt.CallExpr, IdentList);
  end
  else if Stmt is TASTIfStmt then
  begin
    IfStmt := TASTIfStmt(Stmt);
    CollectIdentifiersInExpr(IfStmt.Condition, IdentList);
    CollectIdentifiersInNodeList(IfStmt.ThenBranch, IdentList);
    CollectIdentifiersInNodeList(IfStmt.ElseBranch, IdentList);
  end
  else if Stmt is TASTWhileStmt then
  begin
    WhileStmt := TASTWhileStmt(Stmt);
    CollectIdentifiersInExpr(WhileStmt.Condition, IdentList);
    CollectIdentifiersInNodeList(WhileStmt.Body, IdentList);
  end
  else if Stmt is TASTForStmt then
  begin
    ForStmt := TASTForStmt(Stmt);
    IdentList.Add(ForStmt.VarName);
    if ForStmt.ValVarName <> '' then
      IdentList.Add(ForStmt.ValVarName);
    if Assigned(ForStmt.CollectionExpr) then
      CollectIdentifiersInExpr(ForStmt.CollectionExpr, IdentList)
    else
    begin
      CollectIdentifiersInExpr(ForStmt.StartExpr, IdentList);
      CollectIdentifiersInExpr(ForStmt.EndExpr, IdentList);
    end;
    CollectIdentifiersInNodeList(ForStmt.Body, IdentList);
  end
  else if Stmt is TASTRepeatStmt then
  begin
    RepeatStmt := TASTRepeatStmt(Stmt);
    CollectIdentifiersInNodeList(RepeatStmt.Body, IdentList);
    if Assigned(RepeatStmt.Condition) then
      CollectIdentifiersInExpr(RepeatStmt.Condition, IdentList);
  end
  else if Stmt is TASTMatchStmt then
  begin
    MatchStmt := TASTMatchStmt(Stmt);
    CollectIdentifiersInExpr(MatchStmt.Expr, IdentList);
    for I := 0 to MatchStmt.Cases.Count - 1 do
    begin
      CaseNode := TASTMatchCase(MatchStmt.Cases[I]);
      if CaseNode.Pattern.SubPattern <> '' then
        IdentList.Add(CaseNode.Pattern.SubPattern);
      if Assigned(CaseNode.Guard) then
        CollectIdentifiersInExpr(CaseNode.Guard, IdentList);
      CollectIdentifiersInNodeList(CaseNode.Body, IdentList);
    end;
  end
  else if Stmt is TASTReturnStmt then
  begin
    ReturnStmt := TASTReturnStmt(Stmt);
    CollectIdentifiersInExpr(ReturnStmt.Expr, IdentList);
  end
  else if Stmt is TASTDeferStmt then
  begin
    CollectIdentifiersInStmt(TASTDeferStmt(Stmt).Stmt, IdentList);
  end
  else if Stmt is TASTTryStmt then
  begin
    CollectIdentifiersInNodeList(TASTTryStmt(Stmt).TryBody, IdentList);
    CollectIdentifiersInNodeList(TASTTryStmt(Stmt).ExceptBody, IdentList);
  end
  else if Stmt is TASTRaiseStmt then
  begin
    CollectIdentifiersInExpr(TASTRaiseStmt(Stmt).Expr, IdentList);
  end
  else if Stmt is TASTVarDeclStmt then
  begin
    for I := 0 to TASTVarDeclStmt(Stmt).Decls.Count - 1 do
      CollectIdentifiersInExpr(TASTVarDecl(TASTVarDeclStmt(Stmt).Decls[I]).InitialExpr, IdentList);
  end
  else if Stmt is TASTUnsafeStmt then
  begin
    CollectIdentifiersInNodeList(TASTUnsafeStmt(Stmt).Body, IdentList);
  end;
end;

class procedure TAetherLinter.CollectIdentifiersInNodeList(Nodes: TASTNodeList; IdentList: TStringList);
var
  I: Integer;
begin
  if not Assigned(Nodes) then Exit;
  for I := 0 to Nodes.Count - 1 do
  begin
    if Nodes[I] is TASTStmt then
      CollectIdentifiersInStmt(TASTStmt(Nodes[I]), IdentList)
    else if Nodes[I] is TASTExpr then
      CollectIdentifiersInExpr(TASTExpr(Nodes[I]), IdentList);
  end;
end;

class function TAetherLinter.FixUnusedImports(const FilePath: string; UnusedImports: TStringList): Integer;
var
  Lines, NewLines: TStringList;
  I, J: Integer;
  LineTrimmed: string;
  ShouldRemove: Boolean;
  TargetImport: string;
begin
  Result := 0;
  if not FileExists(FilePath) or (UnusedImports.Count = 0) then Exit;

  Lines := TStringList.Create;
  NewLines := TStringList.Create;
  try
    Lines.LoadFromFile(FilePath);
    for I := 0 to Lines.Count - 1 do
    begin
      LineTrimmed := Trim(Lines[I]);
      ShouldRemove := False;

      for J := 0 to UnusedImports.Count - 1 do
      begin
        TargetImport := UnusedImports[J];
        if (Pos('import ' + TargetImport + ';', LineTrimmed) = 1) or
           (Pos('import pascal ' + TargetImport + ';', LineTrimmed) = 1) or
           (Pos('import c ' + TargetImport + ';', LineTrimmed) = 1) or
           (LineTrimmed = 'import ' + TargetImport) then
        begin
          ShouldRemove := True;
          Inc(Result);
          Break;
        end;
      end;

      if not ShouldRemove then
        NewLines.Add(Lines[I]);
    end;

    if Result > 0 then
      NewLines.SaveToFile(FilePath);
  finally
    Lines.Free;
    NewLines.Free;
  end;
end;

class function TAetherLinter.LintModule(const FilePath: string; AModule: TASTModule; Fix: Boolean): TLintResult;
var
  AllModuleIdents: TStringList;
  BodyIdents: TStringList;
  UnusedImports: TStringList;
  I, J: Integer;
  ImpName, SubName: string;
  Func: TASTFunction;
  ParamNode: TASTParam;
  VarNode: TASTVarDecl;
  TypeNode: TASTNode;
  BinExpr: TASTBinaryExpr;

  procedure CheckExprForRedundancies(Expr: TASTExpr);
  var
    CallNode: TASTCallExpr;
    SubI: Integer;
  begin
    if not Assigned(Expr) then Exit;
    if Expr is TASTBinaryExpr then
    begin
      BinExpr := TASTBinaryExpr(Expr);
      // Checa comparacoes redundantes com booleano: x = true, x = false, etc.
      if (BinExpr.Op = '=') or (BinExpr.Op = '<>') then
      begin
        if (BinExpr.Left is TASTLiteralExpr) and (TASTLiteralExpr(BinExpr.Left).Kind = lkBool) then
          AddIssue(Result, 'redundant-boolean', 'L005',
            Format('Comparacao booleana redundante com literal "%s". Simplifique a condicao.', [TASTLiteralExpr(BinExpr.Left).Value]),
            FilePath, BinExpr.Line, BinExpr.Col, lsHint)
        else if (BinExpr.Right is TASTLiteralExpr) and (TASTLiteralExpr(BinExpr.Right).Kind = lkBool) then
          AddIssue(Result, 'redundant-boolean', 'L005',
            Format('Comparacao booleana redundante com literal "%s". Simplifique a condicao.', [TASTLiteralExpr(BinExpr.Right).Value]),
            FilePath, BinExpr.Line, BinExpr.Col, lsHint);
      end;
      CheckExprForRedundancies(BinExpr.Left);
      CheckExprForRedundancies(BinExpr.Right);
    end
    else if Expr is TASTUnaryExpr then
      CheckExprForRedundancies(TASTUnaryExpr(Expr).Expr)
    else if Expr is TASTCallExpr then
    begin
      CallNode := TASTCallExpr(Expr);
      for SubI := 0 to CallNode.Args.Count - 1 do
        CheckExprForRedundancies(TASTCallArg(CallNode.Args[SubI]).Expr);
    end
    else if Expr is TASTMemberAccessExpr then
      CheckExprForRedundancies(TASTMemberAccessExpr(Expr).Target)
    else if Expr is TASTIfExpr then
    begin
      CheckExprForRedundancies(TASTIfExpr(Expr).Condition);
      CheckExprForRedundancies(TASTIfExpr(Expr).ThenExpr);
      CheckExprForRedundancies(TASTIfExpr(Expr).ElseExpr);
    end
    else if Expr is TASTMapLiteralExpr then
    begin
      for SubI := 0 to TASTMapLiteralExpr(Expr).Keys.Count - 1 do
      begin
        CheckExprForRedundancies(TASTExpr(TASTMapLiteralExpr(Expr).Keys[SubI]));
        CheckExprForRedundancies(TASTExpr(TASTMapLiteralExpr(Expr).Values[SubI]));
      end;
    end
    else if Expr is TASTMatchExpr then
    begin
      CheckExprForRedundancies(TASTMatchExpr(Expr).Expr);
      for SubI := 0 to TASTMatchExpr(Expr).Cases.Count - 1 do
      begin
        if Assigned(TASTMatchCase(TASTMatchExpr(Expr).Cases[SubI]).Guard) then
          CheckExprForRedundancies(TASTMatchCase(TASTMatchExpr(Expr).Cases[SubI]).Guard);
        CheckExprForRedundancies(TASTMatchCase(TASTMatchExpr(Expr).Cases[SubI]).ValueExpr);
      end;
    end;
  end;

  procedure CheckStmtListForDeadCode(List: TASTNodeList);
  var
    SIdx, K: Integer;
    CurStmt: TASTStmt;
    LocalReturnFound: Boolean;
    LocRetLine, LocRetCol: Integer;
  begin
    if not Assigned(List) then Exit;
    LocalReturnFound := False;
    LocRetLine := 0;
    LocRetCol := 0;

    for SIdx := 0 to List.Count - 1 do
    begin
      if not (List[SIdx] is TASTStmt) then Continue;
      CurStmt := TASTStmt(List[SIdx]);

      if LocalReturnFound then
      begin
        AddIssue(Result, 'unreachable-code', 'L003',
          Format('Instrucao inalcancavel (dead code) apos comando de return na linha %d:%d.', [LocRetLine, LocRetCol]),
          FilePath, CurStmt.Line, CurStmt.Col, lsWarning);
      end
      else if CurStmt is TASTReturnStmt then
      begin
        LocalReturnFound := True;
        LocRetLine := CurStmt.Line;
        LocRetCol := CurStmt.Col;
      end;

      // Inspeciona sub-blocos
      if CurStmt is TASTIfStmt then
      begin
        CheckExprForRedundancies(TASTIfStmt(CurStmt).Condition);
        CheckStmtListForDeadCode(TASTIfStmt(CurStmt).ThenBranch);
        CheckStmtListForDeadCode(TASTIfStmt(CurStmt).ElseBranch);
      end
      else if CurStmt is TASTWhileStmt then
      begin
        CheckExprForRedundancies(TASTWhileStmt(CurStmt).Condition);
        CheckStmtListForDeadCode(TASTWhileStmt(CurStmt).Body);
      end
      else if CurStmt is TASTForStmt then
      begin
        CheckExprForRedundancies(TASTForStmt(CurStmt).StartExpr);
        CheckExprForRedundancies(TASTForStmt(CurStmt).EndExpr);
        CheckStmtListForDeadCode(TASTForStmt(CurStmt).Body);
      end
      else if CurStmt is TASTRepeatStmt then
      begin
        CheckStmtListForDeadCode(TASTRepeatStmt(CurStmt).Body);
        if Assigned(TASTRepeatStmt(CurStmt).Condition) then
          CheckExprForRedundancies(TASTRepeatStmt(CurStmt).Condition);
      end
      else if CurStmt is TASTAssignStmt then
        CheckExprForRedundancies(TASTAssignStmt(CurStmt).Expr)
      else if CurStmt is TASTCallStmt then
        CheckExprForRedundancies(TASTCallStmt(CurStmt).CallExpr)
      else if CurStmt is TASTReturnStmt then
        CheckExprForRedundancies(TASTReturnStmt(CurStmt).Expr)
      else if CurStmt is TASTTryStmt then
      begin
        CheckStmtListForDeadCode(TASTTryStmt(CurStmt).TryBody);
        CheckStmtListForDeadCode(TASTTryStmt(CurStmt).ExceptBody);
      end
      else if CurStmt is TASTUnsafeStmt then
        CheckStmtListForDeadCode(TASTUnsafeStmt(CurStmt).Body)
      else if CurStmt is TASTRaiseStmt then
        CheckExprForRedundancies(TASTRaiseStmt(CurStmt).Expr)
      else if CurStmt is TASTVarDeclStmt then
      begin
        for K := 0 to TASTVarDeclStmt(CurStmt).Decls.Count - 1 do
          CheckExprForRedundancies(TASTVarDecl(TASTVarDeclStmt(CurStmt).Decls[K]).InitialExpr);
      end
      else if CurStmt is TASTMatchStmt then
      begin
        CheckExprForRedundancies(TASTMatchStmt(CurStmt).Expr);
        for K := 0 to TASTMatchStmt(CurStmt).Cases.Count - 1 do
        begin
          if Assigned(TASTMatchCase(TASTMatchStmt(CurStmt).Cases[K]).Guard) then
            CheckExprForRedundancies(TASTMatchCase(TASTMatchStmt(CurStmt).Cases[K]).Guard);
          CheckStmtListForDeadCode(TASTMatchCase(TASTMatchStmt(CurStmt).Cases[K]).Body);
        end;
      end;
    end;
  end;

begin
  Result.FileName := FilePath;
  Result.IssueCount := 0;
  Result.HasErrors := False;
  Result.HasWarnings := False;
  Result.FixedCount := 0;
  SetLength(Result.Issues, 0);

  if not Assigned(AModule) then Exit;

  AllModuleIdents := TStringList.Create;
  BodyIdents := TStringList.Create;
  UnusedImports := TStringList.Create;
  try
    AllModuleIdents.Duplicates := dupIgnore;
    AllModuleIdents.Sorted := True;

    // 1. Coleta todos os identificadores globais referenciados no módulo
    for I := 0 to AModule.Functions.Count - 1 do
    begin
      Func := TASTFunction(AModule.Functions[I]);
      CollectIdentifiersInNodeList(Func.Body, AllModuleIdents);
      CollectIdentifiersInNodeList(Func.Requires, AllModuleIdents);
      CollectIdentifiersInNodeList(Func.Ensures, AllModuleIdents);
    end;

    if Assigned(AModule.ProgramBlock) then
      CollectIdentifiersInNodeList(AModule.ProgramBlock.Body, AllModuleIdents);

    // 2. Regra L002: Verificação de Imports Não Utilizados
    for I := 0 to AModule.Imports.Count - 1 do
    begin
      ImpName := AModule.Imports[I];
      // Para imports como 'std.math', pega o segmento final 'math'
      SubName := ImpName;
      if Pos('.', SubName) > 0 then
        SubName := Copy(SubName, LastDelimiter('.', SubName) + 1, Length(SubName));

      if (AllModuleIdents.IndexOf(ImpName) < 0) and (AllModuleIdents.IndexOf(SubName) < 0) then
      begin
        UnusedImports.Add(ImpName);
        AddIssue(Result, 'unused-import', 'L002',
          Format('Modulo importado "%s" nunca e referenciado no codigo.', [ImpName]),
          FilePath, 1, 1, lsWarning, True, ImpName);
      end;
    end;

    // 3. Regra L006: Verificação de Nomenclatura de Tipos (PascalCase)
    for I := 0 to AModule.Types.Count - 1 do
    begin
      TypeNode := AModule.Types[I];
      if TypeNode is TASTRecordDecl then
      begin
        if not IsPascalCase(TASTRecordDecl(TypeNode).Name) then
          AddIssue(Result, 'naming-convention', 'L006',
            Format('Tipo record "%s" deve seguir PascalCase (iniciar com letra maiuscula).', [TASTRecordDecl(TypeNode).Name]),
            FilePath, TypeNode.Line, TypeNode.Col, lsHint);
      end
      else if TypeNode is TASTEnumDecl then
      begin
        if not IsPascalCase(TASTEnumDecl(TypeNode).Name) then
          AddIssue(Result, 'naming-convention', 'L006',
            Format('Tipo enum "%s" deve seguir PascalCase (iniciar com letra maiuscula).', [TASTEnumDecl(TypeNode).Name]),
            FilePath, TypeNode.Line, TypeNode.Col, lsHint);
      end;
    end;

    // 4. Regras L001 (Unused Variables), L004 (Unused Params), L003 (Dead Code) em Funções
    for I := 0 to AModule.Functions.Count - 1 do
    begin
      Func := TASTFunction(AModule.Functions[I]);
      BodyIdents.Clear;
      BodyIdents.Sorted := True;
      CollectIdentifiersInNodeList(Func.Body, BodyIdents);
      CollectIdentifiersInNodeList(Func.Requires, BodyIdents);
      CollectIdentifiersInNodeList(Func.Ensures, BodyIdents);

      // L004: Parametros nunca usados
      for J := 0 to Func.Params.Count - 1 do
      begin
        ParamNode := TASTParam(Func.Params[J]);
        if (ParamNode.Name <> 'self') and (Length(ParamNode.Name) > 0) and (ParamNode.Name[1] <> '_') then
        begin
          if BodyIdents.IndexOf(ParamNode.Name) < 0 then
            AddIssue(Result, 'unused-param', 'L004',
              Format('Parametro "%s" nunca e utilizado na funcao "%s". (Dica: use prefixo "_" se descartado).', [ParamNode.Name, Func.Name]),
              FilePath, ParamNode.Line, ParamNode.Col, lsWarning);
        end;
      end;

      // L001: Variaveis locais nunca usadas
      for J := 0 to Func.LocalVars.Count - 1 do
      begin
        VarNode := TASTVarDecl(Func.LocalVars[J]);
        if (Length(VarNode.Name) > 0) and (VarNode.Name[1] <> '_') then
        begin
          if BodyIdents.IndexOf(VarNode.Name) < 0 then
            AddIssue(Result, 'unused-variable', 'L001',
              Format('Variavel local "%s" nunca e utilizada na funcao "%s". (Dica: use prefixo "_" se intencional).', [VarNode.Name, Func.Name]),
              FilePath, VarNode.Line, VarNode.Col, lsWarning);
        end;
      end;

      // L003: Dead code e Redundancias
      CheckStmtListForDeadCode(Func.Body);
    end;

    // 5. Inspeciona ProgramBlock
    if Assigned(AModule.ProgramBlock) then
    begin
      BodyIdents.Clear;
      BodyIdents.Sorted := True;
      CollectIdentifiersInNodeList(AModule.ProgramBlock.Body, BodyIdents);

      for J := 0 to AModule.ProgramBlock.LocalVars.Count - 1 do
      begin
        VarNode := TASTVarDecl(AModule.ProgramBlock.LocalVars[J]);
        if (Length(VarNode.Name) > 0) and (VarNode.Name[1] <> '_') then
        begin
          if BodyIdents.IndexOf(VarNode.Name) < 0 then
            AddIssue(Result, 'unused-variable', 'L001',
              Format('Variavel global "%s" nunca e utilizada no bloco principal. (Dica: use prefixo "_" se intencional).', [VarNode.Name]),
              FilePath, VarNode.Line, VarNode.Col, lsWarning);
        end;
      end;

      CheckStmtListForDeadCode(AModule.ProgramBlock.Body);
    end;

    // Se a flag Fix foi requisitada, aplica correcoes seguras
    if Fix and (UnusedImports.Count > 0) then
    begin
      Result.FixedCount := FixUnusedImports(FilePath, UnusedImports);
    end;

  finally
    AllModuleIdents.Free;
    BodyIdents.Free;
    UnusedImports.Free;
  end;
end;

class function TAetherLinter.LintSource(const Source, FileName: string; Fix: Boolean): TLintResult;
var
  Lexer: TAetherLexer;
  Parser: TAetherParser;
  AModule: TASTModule;
begin
  Lexer := TAetherLexer.Create(Source);
  try
    Parser := TAetherParser.Create(Lexer);
    try
      AModule := Parser.ParseModule;
      try
        Result := LintModule(FileName, AModule, Fix);
      finally
        AModule.Free;
      end;
    finally
      Parser.Free;
    end;
  finally
    Lexer.Free;
  end;
end;

class function TAetherLinter.LintFile(const FilePath: string; Fix: Boolean): TLintResult;
var
  Src: string;
  Lines: TStringList;
begin
  if not FileExists(FilePath) then
  begin
    Result.FileName := FilePath;
    Result.IssueCount := 0;
    Result.HasErrors := True;
    Result.HasWarnings := False;
    Result.FixedCount := 0;
    SetLength(Result.Issues, 0);
    AddIssue(Result, 'file-not-found', 'E0001', 'Arquivo fonte nao encontrado: ' + FilePath, FilePath, 1, 1, lsError);
    Exit;
  end;

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FilePath);
    Src := Lines.Text;
  finally
    Lines.Free;
  end;

  Result := LintSource(Src, FilePath, Fix);
end;

class procedure TAetherLinter.LintDirectory(const DirPath: string; Fix: Boolean;
  var TotalFiles, CleanFiles, IssueFiles, TotalIssues, TotalFixed: Integer;
  var Results: TLintArrayResult);
var
  Rec: TSearchRec;
  FullPath: string;
  CurRes: TLintResult;
  Idx: Integer;
begin
  if FindFirst(DirPath + PathDelim + '*.aeth', faAnyFile, Rec) = 0 then
  begin
    repeat
      if (Rec.Attr and faDirectory) = 0 then
      begin
        FullPath := DirPath + PathDelim + Rec.Name;
        Inc(TotalFiles);
        CurRes := LintFile(FullPath, Fix);
        Inc(TotalIssues, CurRes.IssueCount);
        Inc(TotalFixed, CurRes.FixedCount);

        if CurRes.IssueCount = 0 then
          Inc(CleanFiles)
        else
          Inc(IssueFiles);

        Idx := Length(Results);
        SetLength(Results, Idx + 1);
        Results[Idx] := CurRes;
      end;
    until FindNext(Rec) <> 0;
    FindClose(Rec);
  end;
end;

class function TAetherLinter.FormatIssue(const Issue: TLintIssue): string;
var
  SevStr: string;
begin
  case Issue.Severity of
    lsHint:    SevStr := '[HINT]';
    lsWarning: SevStr := '[WARN]';
    lsError:   SevStr := '[ERRO]';
  end;

  Result := Format('  %s %s:%d:%d (%s - %s)' + LineEnding + '         %s',
    [SevStr, Issue.FileName, Issue.Line, Issue.Col, Issue.RuleCode, Issue.RuleId, Issue.Message]);
end;

class function TAetherLinter.FormatJSON(const Results: array of TLintResult): string;
var
  I, J: Integer;
  Issue: TLintIssue;
  First: Boolean;
  SevName: string;
begin
  Result := '{' + LineEnding;
  Result := Result + '  "version": "1.0",' + LineEnding;
  Result := Result + '  "issues": [' + LineEnding;
  First := True;

  for I := 0 to High(Results) do
  begin
    for J := 0 to Results[I].IssueCount - 1 do
    begin
      Issue := Results[I].Issues[J];
      if not First then
        Result := Result + ',' + LineEnding;
      First := False;

      case Issue.Severity of
        lsHint:    SevName := 'hint';
        lsWarning: SevName := 'warning';
        lsError:   SevName := 'error';
      end;

      Result := Result + '    {' + LineEnding;
      Result := Result + Format('      "file": "%s",', [StringReplace(Issue.FileName, '\', '\\', [rfReplaceAll])]) + LineEnding;
      Result := Result + Format('      "line": %d,', [Issue.Line]) + LineEnding;
      Result := Result + Format('      "col": %d,', [Issue.Col]) + LineEnding;
      Result := Result + Format('      "code": "%s",', [Issue.RuleCode]) + LineEnding;
      Result := Result + Format('      "rule": "%s",', [Issue.RuleId]) + LineEnding;
      Result := Result + Format('      "severity": "%s",', [SevName]) + LineEnding;
      Result := Result + Format('      "message": "%s"', [StringReplace(Issue.Message, '"', '\"', [rfReplaceAll])]) + LineEnding;
      Result := Result + '    }';
    end;
  end;

  Result := Result + LineEnding + '  ]' + LineEnding;
  Result := Result + '}';
end;

end.
