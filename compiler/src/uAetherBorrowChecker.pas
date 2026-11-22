unit uAetherBorrowChecker;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  uAetherAST,
  uAetherSymbols;

type
  TVariableState = (vsUninitialized, vsOwned, vsMoved, vsBorrowedShared, vsBorrowedMut);
  TAccessKind = (accRead, accMove, accBorrowShared, accBorrowMut);

  EAetherBorrowError = class(Exception)
  public
    Code: string;
    Line: Integer;
    Col: Integer;
    MovedLine: Integer;
    MovedCol: Integer;
    constructor Create(const ACode, AMsg: string; ALine, ACol: Integer; AMovedLine: Integer = 0; AMovedCol: Integer = 0);
  end;

  TBorrowVarInfo = class
  public
    Name: string;
    State: TVariableState;
    IsPrimitive: Boolean;
    SharedBorrowCount: Integer;
    MovedLine: Integer;
    MovedCol: Integer;
    DeclLine: Integer;
    DeclCol: Integer;
    constructor Create(const AName: string; AState: TVariableState; ALine, ACol: Integer; AIsPrim: Boolean);
  end;

  TBorrowScope = class
  private
    FParent: TBorrowScope;
    FVars: TFPList;
    function FindIndex(const AName: string): Integer;
  public
    constructor Create(AParent: TBorrowScope = nil);
    destructor Destroy; override;

    procedure AddVar(const AName: string; AState: TVariableState; ALine, ACol: Integer; AIsPrim: Boolean);
    function Resolve(const AName: string): TBorrowVarInfo;
    function ResolveLocal(const AName: string): TBorrowVarInfo;
    procedure ReleaseTemporaryBorrows;
    property Parent: TBorrowScope read FParent;
    property Vars: TFPList read FVars;
  end;

  TAetherBorrowChecker = class
  private
    FCurrentScope: TBorrowScope;
    FSymbols: TSymbolTable;

    procedure EnterScope;
    procedure LeaveScope;
    function IsPrimitiveType(const AType: string): Boolean;
    procedure Error(const ACode, AMsg: string; ALine, ACol: Integer; AMovedLine: Integer = 0; AMovedCol: Integer = 0);

    procedure CheckExpr(Expr: TASTExpr; Access: TAccessKind);
    procedure CheckCallArg(Arg: TASTCallArg);
    procedure CheckStmt(Stmt: TASTStmt);
    procedure CheckFunction(Func: TASTFunction);
    procedure CheckProgramBlock(Prog: TASTProgramBlock);
  public
    constructor Create(ASymbols: TSymbolTable);
    destructor Destroy; override;
    procedure CheckModule(AModule: TASTModule);
  end;

implementation

{ EAetherBorrowError }

constructor EAetherBorrowError.Create(const ACode, AMsg: string; ALine, ACol: Integer; AMovedLine, AMovedCol: Integer);
var
  FullMsg: string;
begin
  FullMsg := Format('[Erro de Posse %s em %d:%d]: %s', [ACode, ALine, ACol, AMsg]);
  if AMovedLine > 0 then
    FullMsg := FullMsg + LineEnding + Format('  --> Nota: O valor foi movido anteriormente na linha %d:%d atraves de "take".', [AMovedLine, AMovedCol]);
  inherited Create(FullMsg);
  Code := ACode;
  Line := ALine;
  Col := ACol;
  MovedLine := AMovedLine;
  MovedCol := AMovedCol;
end;

{ TBorrowVarInfo }

constructor TBorrowVarInfo.Create(const AName: string; AState: TVariableState; ALine, ACol: Integer; AIsPrim: Boolean);
begin
  inherited Create;
  Name := AName;
  State := AState;
  IsPrimitive := AIsPrim;
  SharedBorrowCount := 0;
  MovedLine := 0;
  MovedCol := 0;
  DeclLine := ALine;
  DeclCol := ACol;
end;

{ TBorrowScope }

constructor TBorrowScope.Create(AParent: TBorrowScope);
begin
  inherited Create;
  FParent := AParent;
  FVars := TFPList.Create;
end;

destructor TBorrowScope.Destroy;
var
  I: Integer;
begin
  for I := 0 to FVars.Count - 1 do
    TBorrowVarInfo(FVars[I]).Free;
  FVars.Free;
  inherited Destroy;
end;

function TBorrowScope.FindIndex(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FVars.Count - 1 do
  begin
    if SameText(TBorrowVarInfo(FVars[I]).Name, AName) then
      Exit(I);
  end;
  Result := -1;
end;

procedure TBorrowScope.AddVar(const AName: string; AState: TVariableState; ALine, ACol: Integer; AIsPrim: Boolean);
begin
  FVars.Add(TBorrowVarInfo.Create(AName, AState, ALine, ACol, AIsPrim));
end;

function TBorrowScope.ResolveLocal(const AName: string): TBorrowVarInfo;
var
  Idx: Integer;
begin
  Idx := FindIndex(AName);
  if Idx <> -1 then
    Result := TBorrowVarInfo(FVars[Idx])
  else
    Result := nil;
end;

function TBorrowScope.Resolve(const AName: string): TBorrowVarInfo;
var
  Curr: TBorrowScope;
  V: TBorrowVarInfo;
begin
  Curr := Self;
  while Assigned(Curr) do
  begin
    V := Curr.ResolveLocal(AName);
    if Assigned(V) then
      Exit(V);
    Curr := Curr.Parent;
  end;
  Result := nil;
end;

procedure TBorrowScope.ReleaseTemporaryBorrows;
var
  I: Integer;
begin
  for I := 0 to FVars.Count - 1 do
    TBorrowVarInfo(FVars[I]).SharedBorrowCount := 0;
  if Assigned(FParent) then
    FParent.ReleaseTemporaryBorrows;
end;

{ TAetherBorrowChecker }

constructor TAetherBorrowChecker.Create(ASymbols: TSymbolTable);
begin
  inherited Create;
  FSymbols := ASymbols;
  FCurrentScope := TBorrowScope.Create(nil);
end;

destructor TAetherBorrowChecker.Destroy;
begin
  while Assigned(FCurrentScope) do
    LeaveScope;
  inherited Destroy;
end;

procedure TAetherBorrowChecker.EnterScope;
begin
  FCurrentScope := TBorrowScope.Create(FCurrentScope);
end;

procedure TAetherBorrowChecker.LeaveScope;
var
  Old: TBorrowScope;
begin
  if Assigned(FCurrentScope) then
  begin
    Old := FCurrentScope;
    FCurrentScope := FCurrentScope.Parent;
    Old.Free;
  end;
end;

function TAetherBorrowChecker.IsPrimitiveType(const AType: string): Boolean;
begin
  Result := (AType = 'Int8') or (AType = 'Int16') or (AType = 'Int32') or (AType = 'Int64') or
            (AType = 'UInt8') or (AType = 'UInt16') or (AType = 'UInt32') or (AType = 'UInt64') or
            (AType = 'Float32') or (AType = 'Float64') or (AType = 'Bool') or (AType = 'Char');
end;

procedure TAetherBorrowChecker.Error(const ACode, AMsg: string; ALine, ACol: Integer; AMovedLine, AMovedCol: Integer);
begin
  raise EAetherBorrowError.Create(ACode, AMsg, ALine, ACol, AMovedLine, AMovedCol);
end;

procedure TAetherBorrowChecker.CheckExpr(Expr: TASTExpr; Access: TAccessKind);
var
  Id: TASTIdentifierExpr;
  VarInfo: TBorrowVarInfo;
  MemAcc: TASTMemberAccessExpr;
  Bin: TASTBinaryExpr;
  Un: TASTUnaryExpr;
  Call: TASTCallExpr;
  I: Integer;
begin
  if not Assigned(Expr) then Exit;

  // Identificador simples (variavel)
  if Expr is TASTIdentifierExpr then
  begin
    Id := TASTIdentifierExpr(Expr);
    VarInfo := FCurrentScope.Resolve(Id.Name);

    if Assigned(VarInfo) then
    begin
      // Se for primitivo (Int32, Bool, etc.), tem semantica de copia (Copy trait)
      if VarInfo.IsPrimitive then
        Exit;

      // Se a variavel ja foi MOVIDA, acusar erro E0382!
      if VarInfo.State = vsMoved then
      begin
        Error('E0382', Format('Uso de variavel movida: "%s"', [VarInfo.Name]),
          Id.Line, Id.Col, VarInfo.MovedLine, VarInfo.MovedCol);
      end;

      // Executa a transicao de estado conforme o acesso
      case Access of
        accMove:
          begin
            VarInfo.State := vsMoved;
            VarInfo.MovedLine := Id.Line;
            VarInfo.MovedCol := Id.Col;
          end;
        accBorrowShared:
          begin
            // Emprestimo compartilhado permitido
            Inc(VarInfo.SharedBorrowCount);
          end;
        accBorrowMut:
          begin
            if VarInfo.SharedBorrowCount > 0 then
              Error('E0502', Format('Nao e possivel emprestar "%s" como mutavel pois ja existem emprestimos de leitura ativos', [VarInfo.Name]), Id.Line, Id.Col);
            VarInfo.State := vsBorrowedMut;
          end;
        accRead:
          begin
            // Leitura normal
          end;
      end;
    end;
    Exit;
  end;

  // Acesso a membro: obj.campo
  if Expr is TASTMemberAccessExpr then
  begin
    MemAcc := TASTMemberAccessExpr(Expr);
    CheckExpr(MemAcc.Target, accRead);
    Exit;
  end;

  // Chamada de Funcao
  if Expr is TASTCallExpr then
  begin
    Call := TASTCallExpr(Expr);
    for I := 0 to Call.Args.Count - 1 do
      CheckCallArg(TASTCallArg(Call.Args[I]));
    Exit;
  end;

  // Operacao Binaria
  if Expr is TASTBinaryExpr then
  begin
    Bin := TASTBinaryExpr(Expr);
    CheckExpr(Bin.Left, accRead);
    CheckExpr(Bin.Right, accRead);
    Exit;
  end;

  // Operacao Unaria
  if Expr is TASTUnaryExpr then
  begin
    Un := TASTUnaryExpr(Expr);
    CheckExpr(Un.Expr, accRead);
    Exit;
  end;

  // Await e Spawn
  if Expr is TASTAwaitExpr then
  begin
    CheckExpr(TASTAwaitExpr(Expr).Expr, accRead);
    Exit;
  end;
  if Expr is TASTSpawnExpr then
  begin
    CheckExpr(TASTSpawnExpr(Expr).CallExpr, accRead);
    Exit;
  end;
end;

procedure TAetherBorrowChecker.CheckCallArg(Arg: TASTCallArg);
var
  Access: TAccessKind;
begin
  case Arg.Ownership of
    owTake: Access := accMove;
    owBorrow: Access := accBorrowShared;
    owMutBorrow: Access := accBorrowMut;
  else
    Access := accRead;
  end;

  CheckExpr(Arg.Expr, Access);
end;

procedure TAetherBorrowChecker.CheckStmt(Stmt: TASTStmt);
var
  Assign: TASTAssignStmt;
  IfStmt: TASTIfStmt;
  WhileStmt: TASTWhileStmt;
  MatchStmt: TASTMatchStmt;
  CaseNode: TASTMatchCase;
  Ret: TASTReturnStmt;
  CallStmt: TASTCallStmt;
  VarInfo, V: TBorrowVarInfo;
  I, J: Integer;
  SavedStates, ThenStates: TFPList;
  Scope: TBorrowScope;
  ThenSt: TVariableState;
begin
  if Stmt is TASTAssignStmt then
  begin
    Assign := TASTAssignStmt(Stmt);
    CheckExpr(Assign.Expr, accRead);
    // Atribuicao a uma variavel reinicializa a posse se antes estava movida
    if Assign.Target is TASTIdentifierExpr then
    begin
      VarInfo := FCurrentScope.Resolve(TASTIdentifierExpr(Assign.Target).Name);
      if Assigned(VarInfo) then
        VarInfo.State := vsOwned;
    end
    else
      CheckExpr(Assign.Target, accRead);
  end
  else if Stmt is TASTCallStmt then
  begin
    CallStmt := TASTCallStmt(Stmt);
    CheckExpr(CallStmt.CallExpr, accRead);
  end
  else if Stmt is TASTIfStmt then
  begin
    IfStmt := TASTIfStmt(Stmt);
    CheckExpr(IfStmt.Condition, accRead);
    if Assigned(FCurrentScope) then
      FCurrentScope.ReleaseTemporaryBorrows;

    SavedStates := TFPList.Create;
    try
      Scope := FCurrentScope;
      while Assigned(Scope) do
      begin
        for I := 0 to Scope.Vars.Count - 1 do
        begin
          V := TBorrowVarInfo(Scope.Vars[I]);
          SavedStates.Add(V);
          SavedStates.Add(Pointer(PtrUInt(V.State)));
        end;
        Scope := Scope.Parent;
      end;

      for I := 0 to IfStmt.ThenBranch.Count - 1 do
        CheckStmt(TASTStmt(IfStmt.ThenBranch[I]));

      if IfStmt.ElseBranch.Count > 0 then
      begin
        ThenStates := TFPList.Create;
        try
          I := 0;
          while I < SavedStates.Count do
          begin
            V := TBorrowVarInfo(SavedStates[I]);
            ThenStates.Add(Pointer(PtrUInt(V.State)));
            V.State := TVariableState(PtrUInt(SavedStates[I + 1]));
            Inc(I, 2);
          end;

          for I := 0 to IfStmt.ElseBranch.Count - 1 do
            CheckStmt(TASTStmt(IfStmt.ElseBranch[I]));

          I := 0;
          while I < SavedStates.Count do
          begin
            V := TBorrowVarInfo(SavedStates[I]);
            ThenSt := TVariableState(PtrUInt(ThenStates[I div 2]));
            if (ThenSt = vsMoved) or (V.State = vsMoved) then
              V.State := vsMoved;
            Inc(I, 2);
          end;
        finally
          ThenStates.Free;
        end;
      end;
    finally
      SavedStates.Free;
    end;
  end
  else if Stmt is TASTWhileStmt then
  begin
    WhileStmt := TASTWhileStmt(Stmt);
    CheckExpr(WhileStmt.Condition, accRead);
    if Assigned(FCurrentScope) then
      FCurrentScope.ReleaseTemporaryBorrows;
    for I := 0 to WhileStmt.Body.Count - 1 do
      CheckStmt(TASTStmt(WhileStmt.Body[I]));
  end
  else if Stmt is TASTReturnStmt then
  begin
    Ret := TASTReturnStmt(Stmt);
    if Assigned(Ret.Expr) then
      CheckExpr(Ret.Expr, accMove);
  end
  else if Stmt is TASTAsmStmt then
  begin
    // Bloco assembly: instrucoes de baixo nivel aceitas sem violacao de borrow
  end
  else if Stmt is TASTMatchStmt then
  begin
    MatchStmt := TASTMatchStmt(Stmt);
    CheckExpr(MatchStmt.Expr, accBorrowShared);
    for I := 0 to MatchStmt.Cases.Count - 1 do
    begin
      CaseNode := TASTMatchCase(MatchStmt.Cases[I]);
      EnterScope;
      try
        if CaseNode.Pattern.SubPattern <> '' then
          FCurrentScope.AddVar(CaseNode.Pattern.SubPattern, vsOwned, CaseNode.Line, CaseNode.Col, False);
        for J := 0 to CaseNode.Body.Count - 1 do
          CheckStmt(TASTStmt(CaseNode.Body[J]));
      finally
        LeaveScope;
      end;
    end;
  end;

  if Assigned(FCurrentScope) then
    FCurrentScope.ReleaseTemporaryBorrows;
end;

procedure TAetherBorrowChecker.CheckFunction(Func: TASTFunction);
var
  I: Integer;
  Param: TASTParam;
  VarDecl: TASTVarDecl;
begin
  EnterScope;
  try
    // Parametros da funcao
    for I := 0 to Func.Params.Count - 1 do
    begin
      Param := TASTParam(Func.Params[I]);
      FCurrentScope.AddVar(Param.Name, vsOwned, Param.Line, Param.Col, IsPrimitiveType(Param.TypeName));
    end;

    // Se for extern, nao possui corpo de instrucoes
    if Func.IsExtern then
      Exit;

    // Variaveis locais
    for I := 0 to Func.LocalVars.Count - 1 do
    begin
      VarDecl := TASTVarDecl(Func.LocalVars[I]);
      if Assigned(VarDecl.InitialExpr) then
        CheckExpr(VarDecl.InitialExpr, accRead);
      FCurrentScope.AddVar(VarDecl.Name, vsOwned, VarDecl.Line, VarDecl.Col, IsPrimitiveType(VarDecl.TypeName));
    end;

    // Instrucoes do corpo
    for I := 0 to Func.Body.Count - 1 do
      CheckStmt(TASTStmt(Func.Body[I]));
  finally
    LeaveScope;
  end;
end;

procedure TAetherBorrowChecker.CheckProgramBlock(Prog: TASTProgramBlock);
var
  I: Integer;
  VarDecl: TASTVarDecl;
begin
  EnterScope;
  try
    for I := 0 to Prog.LocalVars.Count - 1 do
    begin
      VarDecl := TASTVarDecl(Prog.LocalVars[I]);
      if Assigned(VarDecl.InitialExpr) then
        CheckExpr(VarDecl.InitialExpr, accRead);
      FCurrentScope.AddVar(VarDecl.Name, vsOwned, VarDecl.Line, VarDecl.Col, IsPrimitiveType(VarDecl.TypeName));
    end;

    for I := 0 to Prog.Body.Count - 1 do
      CheckStmt(TASTStmt(Prog.Body[I]));
  finally
    LeaveScope;
  end;
end;

procedure TAetherBorrowChecker.CheckModule(AModule: TASTModule);
var
  I: Integer;
  Func: TASTFunction;
begin
  for I := 0 to AModule.Functions.Count - 1 do
  begin
    Func := TASTFunction(AModule.Functions[I]);
    if Func.GenericParam = '' then
      CheckFunction(Func);
  end;

  if Assigned(AModule.ProgramBlock) then
    CheckProgramBlock(AModule.ProgramBlock);
end;

end.
