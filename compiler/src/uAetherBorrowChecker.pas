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
    TypeName: string;
    State: TVariableState;
    IsPrimitive: Boolean;
    SharedBorrowCount: Integer;
    SharedBorrowFields: TStringList;
    MutBorrowFields: TStringList;
    MovedFields: TStringList;
    MovedLine: Integer;
    MovedCol: Integer;
    DeclLine: Integer;
    DeclCol: Integer;
    constructor Create(const AName, ATypeName: string; AState: TVariableState; ALine, ACol: Integer; AIsPrim: Boolean);
    destructor Destroy; override;
  end;

  TBorrowOp = record
    VarInfo: TBorrowVarInfo;
    Access: TAccessKind;
    FieldPath: string;
  end;

  TBorrowScope = class
  private
    FParent: TBorrowScope;
    FVars: TFPList;
    function FindIndex(const AName: string): Integer;
  public
    constructor Create(AParent: TBorrowScope = nil);
    destructor Destroy; override;

    procedure AddVar(const AName, ATypeName: string; AState: TVariableState; ALine, ACol: Integer; AIsPrim: Boolean);
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
    FModule: TASTModule;
    FCurrentGenericParam: string;
    FBorrowOps: array of TBorrowOp;

    procedure EnterScope;
    procedure LeaveScope;
    function ResolveAliasType(const AType: string): string;
    function IsPrimitiveType(const AType: string): Boolean;
    function ExtractFieldRoot(Expr: TASTExpr; out RootId: TASTIdentifierExpr; out FieldPath: string): Boolean;
    function GetFieldType(const RecType, FieldPath: string): string;
    function FieldsConflict(const A, B: string): Boolean;
    function HasFieldConflict(List: TStringList; const FieldPath: string): Boolean;
    procedure ClearSubFields(List: TStringList; const FieldPath: string);
    procedure PushBorrowOp(VarInfo: TBorrowVarInfo; Access: TAccessKind; const FieldPath: string);
    procedure ReleaseBorrowsTo(TargetLen: Integer);
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

constructor TBorrowVarInfo.Create(const AName, ATypeName: string; AState: TVariableState; ALine, ACol: Integer; AIsPrim: Boolean);
begin
  inherited Create;
  Name := AName;
  TypeName := ATypeName;
  State := AState;
  IsPrimitive := AIsPrim;
  SharedBorrowCount := 0;
  SharedBorrowFields := TStringList.Create;
  MutBorrowFields := TStringList.Create;
  MovedFields := TStringList.Create;
  MovedLine := 0;
  MovedCol := 0;
  DeclLine := ALine;
  DeclCol := ACol;
end;

destructor TBorrowVarInfo.Destroy;
begin
  SharedBorrowFields.Free;
  MutBorrowFields.Free;
  MovedFields.Free;
  inherited Destroy;
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

procedure TBorrowScope.AddVar(const AName, ATypeName: string; AState: TVariableState; ALine, ACol: Integer; AIsPrim: Boolean);
begin
  FVars.Add(TBorrowVarInfo.Create(AName, ATypeName, AState, ALine, ACol, AIsPrim));
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
  V: TBorrowVarInfo;
begin
  for I := 0 to FVars.Count - 1 do
  begin
    V := TBorrowVarInfo(FVars[I]);
    V.SharedBorrowCount := 0;
    V.SharedBorrowFields.Clear;
    V.MutBorrowFields.Clear;
    if V.State = vsBorrowedMut then
      V.State := vsOwned;
  end;
  if Assigned(FParent) then
    FParent.ReleaseTemporaryBorrows;
end;

{ TAetherBorrowChecker }

constructor TAetherBorrowChecker.Create(ASymbols: TSymbolTable);
begin
  inherited Create;
  FSymbols := ASymbols;
  FModule := nil;
  FCurrentGenericParam := '';
  SetLength(FBorrowOps, 0);
  FCurrentScope := TBorrowScope.Create(nil);
end;

destructor TAetherBorrowChecker.Destroy;
begin
  SetLength(FBorrowOps, 0);
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
  I: Integer;
  NewLen: Integer;
begin
  if Assigned(FCurrentScope) then
  begin
    Old := FCurrentScope;
    // Remove quaisquer borrows pendentes pertencentes a variaveis deste escopo
    NewLen := 0;
    for I := 0 to High(FBorrowOps) do
    begin
      if Old.FVars.IndexOf(FBorrowOps[I].VarInfo) < 0 then
      begin
        if NewLen <> I then
          FBorrowOps[NewLen] := FBorrowOps[I];
        Inc(NewLen);
      end;
    end;
    SetLength(FBorrowOps, NewLen);
    FCurrentScope := FCurrentScope.Parent;
    Old.Free;
  end;
end;

function TAetherBorrowChecker.ResolveAliasType(const AType: string): string;
var
  Cur: string;
  Hops, I: Integer;
  Sym: TSymbol;
begin
  Cur := Trim(AType);
  Hops := 0;
  while Hops < 8 do
  begin
    if Assigned(FSymbols) then
    begin
      Sym := FSymbols.ResolveTypeSymbol(Cur);
      if Assigned(Sym) and (Sym.Kind = skType) and (Sym.Node is TASTTypeAliasDecl) then
      begin
        Cur := Trim(TASTTypeAliasDecl(Sym.Node).TargetType);
        Inc(Hops);
        Continue;
      end;
    end;
    if Assigned(FModule) then
    begin
      I := 0;
      while I < FModule.Types.Count do
      begin
        if (TASTNode(FModule.Types[I]) is TASTTypeAliasDecl) and
           SameText(TASTTypeAliasDecl(FModule.Types[I]).Name, Cur) then
        begin
          Cur := Trim(TASTTypeAliasDecl(FModule.Types[I]).TargetType);
          Inc(Hops);
          Break;
        end;
        Inc(I);
      end;
      if I < FModule.Types.Count then Continue;
    end;
    Break;
  end;
  Result := Cur;
end;

function TAetherBorrowChecker.IsPrimitiveType(const AType: string): Boolean;
var
  T: string;
  Sym: TSymbol;
  I: Integer;
begin
  T := ResolveAliasType(AType);
  if (FCurrentGenericParam <> '') and SameText(T, FCurrentGenericParam) then
    Exit(False);
  if (T = 'Int8') or (T = 'Int16') or (T = 'Int32') or (T = 'Int64') or
     (T = 'UInt8') or (T = 'UInt16') or (T = 'UInt32') or (T = 'UInt64') or
     (T = 'Float32') or (T = 'Float64') or (T = 'Bool') or (T = 'Char') or
     (T = 'Pointer') or (Pos('^', T) = 1) or
     (T = 'IntLiteral') or (T = 'FloatLiteral') then
    Exit(True);

  if (Pos('Box<', T) = 1) or (Pos('array of ', T) = 1) or (Pos('map[', T) = 1) or (T = 'String') then
    Exit(False);

  if Assigned(FSymbols) then
  begin
    Sym := FSymbols.ResolveTypeSymbol(T);
    if Assigned(Sym) and (Sym.Kind = skType) and Assigned(Sym.Node) then
    begin
      if (Sym.Node is TASTEnumDecl) or (Sym.Node is TASTSubrangeDecl) or (Sym.Node is TASTSetDecl) then
        Exit(True);
      if (Sym.Node is TASTRecordDecl) or (Sym.Node is TASTMapDecl) then
        Exit(False);
      if (Sym.Node is TASTArrayDecl) then
        Exit(TASTArrayDecl(Sym.Node).Dims.Count > 0);
    end;
  end;

  if Assigned(FModule) then
  begin
    for I := 0 to FModule.Types.Count - 1 do
    begin
      if (TASTNode(FModule.Types[I]) is TASTEnumDecl) and SameText(TASTEnumDecl(FModule.Types[I]).Name, T) then
        Exit(True);
      if (TASTNode(FModule.Types[I]) is TASTSubrangeDecl) and SameText(TASTSubrangeDecl(FModule.Types[I]).Name, T) then
        Exit(True);
      if (TASTNode(FModule.Types[I]) is TASTSetDecl) and SameText(TASTSetDecl(FModule.Types[I]).Name, T) then
        Exit(True);
    end;
  end;

  Result := False;
end;

function TAetherBorrowChecker.ExtractFieldRoot(Expr: TASTExpr; out RootId: TASTIdentifierExpr; out FieldPath: string): Boolean;
var
  Cur: TASTExpr;
  Acc: TASTMemberAccessExpr;
begin
  Result := False;
  RootId := nil;
  FieldPath := '';
  if not (Expr is TASTMemberAccessExpr) then Exit;

  Cur := Expr;
  while Cur is TASTMemberAccessExpr do
  begin
    Acc := TASTMemberAccessExpr(Cur);
    if FieldPath = '' then
      FieldPath := Acc.Member
    else
      FieldPath := Acc.Member + '.' + FieldPath;
    Cur := Acc.Target;
  end;

  if Cur is TASTIdentifierExpr then
  begin
    RootId := TASTIdentifierExpr(Cur);
    Result := True;
  end;
end;

function TAetherBorrowChecker.GetFieldType(const RecType, FieldPath: string): string;
var
  CurType, Seg, Rest: string;
  P, I: Integer;
  Sym: TSymbol;
  RecDecl: TASTRecordDecl;
begin
  Result := '';
  CurType := ResolveAliasType(RecType);
  Rest := FieldPath;
  while (Rest <> '') and (CurType <> '') do
  begin
    P := Pos('.', Rest);
    if P > 0 then
    begin
      Seg := Copy(Rest, 1, P - 1);
      Rest := Copy(Rest, P + 1, Length(Rest));
    end
    else
    begin
      Seg := Rest;
      Rest := '';
    end;

    RecDecl := nil;
    if Assigned(FSymbols) then
    begin
      Sym := FSymbols.ResolveTypeSymbol(CurType);
      if Assigned(Sym) and (Sym.Node is TASTRecordDecl) then
        RecDecl := TASTRecordDecl(Sym.Node);
    end;
    if (not Assigned(RecDecl)) and Assigned(FModule) then
    begin
      for I := 0 to FModule.Types.Count - 1 do
        if (TASTNode(FModule.Types[I]) is TASTRecordDecl) and
           SameText(TASTRecordDecl(FModule.Types[I]).Name, CurType) then
        begin
          RecDecl := TASTRecordDecl(FModule.Types[I]);
          Break;
        end;
    end;

    if not Assigned(RecDecl) then Exit('');
    CurType := '';
    for I := 0 to RecDecl.Fields.Count - 1 do
    begin
      if SameText(TASTRecordField(RecDecl.Fields[I]).Name, Seg) then
      begin
        CurType := ResolveAliasType(TASTRecordField(RecDecl.Fields[I]).TypeName);
        Break;
      end;
    end;
  end;
  Result := CurType;
end;

function TAetherBorrowChecker.FieldsConflict(const A, B: string): Boolean;
var
  LA, LB: string;
begin
  if (A = '') or (B = '') then Exit(True);
  LA := LowerCase(A);
  LB := LowerCase(B);
  if LA = LB then Exit(True);
  Result := (Pos(LA + '.', LB) = 1) or (Pos(LB + '.', LA) = 1);
end;

function TAetherBorrowChecker.HasFieldConflict(List: TStringList; const FieldPath: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if not Assigned(List) then Exit;
  for I := 0 to List.Count - 1 do
    if FieldsConflict(List[I], FieldPath) then
      Exit(True);
end;

procedure TAetherBorrowChecker.ClearSubFields(List: TStringList; const FieldPath: string);
var
  I: Integer;
begin
  if not Assigned(List) then Exit;
  for I := List.Count - 1 downto 0 do
    if FieldsConflict(List[I], FieldPath) and
       (SameText(List[I], FieldPath) or (Pos(LowerCase(FieldPath) + '.', LowerCase(List[I])) = 1)) then
      List.Delete(I);
end;

procedure TAetherBorrowChecker.PushBorrowOp(VarInfo: TBorrowVarInfo; Access: TAccessKind; const FieldPath: string);
var
  N: Integer;
begin
  N := Length(FBorrowOps);
  SetLength(FBorrowOps, N + 1);
  FBorrowOps[N].VarInfo := VarInfo;
  FBorrowOps[N].Access := Access;
  FBorrowOps[N].FieldPath := FieldPath;
end;

procedure TAetherBorrowChecker.ReleaseBorrowsTo(TargetLen: Integer);
var
  I, Idx: Integer;
  Op: TBorrowOp;
begin
  while Length(FBorrowOps) > TargetLen do
  begin
    I := High(FBorrowOps);
    Op := FBorrowOps[I];
    SetLength(FBorrowOps, I);
    if Assigned(Op.VarInfo) then
    begin
      if Op.FieldPath = '' then
      begin
        if Op.Access = accBorrowShared then
        begin
          if Op.VarInfo.SharedBorrowCount > 0 then
            Dec(Op.VarInfo.SharedBorrowCount);
        end
        else if Op.Access = accBorrowMut then
        begin
          if Op.VarInfo.State = vsBorrowedMut then
            Op.VarInfo.State := vsOwned;
        end;
      end
      else
      begin
        if Op.Access = accBorrowShared then
        begin
          Idx := Op.VarInfo.SharedBorrowFields.IndexOf(Op.FieldPath);
          if Idx >= 0 then Op.VarInfo.SharedBorrowFields.Delete(Idx);
        end
        else if Op.Access = accBorrowMut then
        begin
          Idx := Op.VarInfo.MutBorrowFields.IndexOf(Op.FieldPath);
          if Idx >= 0 then Op.VarInfo.MutBorrowFields.Delete(Idx);
        end;
      end;
    end;
  end;
end;

procedure TAetherBorrowChecker.Error(const ACode, AMsg: string; ALine, ACol: Integer; AMovedLine, AMovedCol: Integer);
begin
  raise EAetherBorrowError.Create(ACode, AMsg, ALine, ACol, AMovedLine, AMovedCol);
end;

procedure TAetherBorrowChecker.CheckExpr(Expr: TASTExpr; Access: TAccessKind);
var
  Id, RootId: TASTIdentifierExpr;
  VarInfo: TBorrowVarInfo;
  MemAcc: TASTMemberAccessExpr;
  Bin: TASTBinaryExpr;
  Un: TASTUnaryExpr;
  Call: TASTCallExpr;
  MExpr: TASTMatchExpr;
  CaseNode: TASTMatchCase;
  FieldPath, FieldType: string;
  I, SavedBorrowTop: Integer;
begin
  if not Assigned(Expr) then Exit;

  // Identificador simples (variavel)
  if Expr is TASTIdentifierExpr then
  begin
    Id := TASTIdentifierExpr(Expr);
    VarInfo := FCurrentScope.Resolve(Id.Name);

    if Assigned(VarInfo) then
    begin
      // Se for primitivo (Copy trait), nunca e movido, mas mut/shared borrow ainda checa aliasing!
      if VarInfo.IsPrimitive then
      begin
        if Access = accBorrowMut then
        begin
          if VarInfo.State = vsBorrowedMut then
            Error('E0499', Format('Nao e possivel emprestar "%s" como mutavel mais de uma vez ao mesmo tempo', [VarInfo.Name]), Id.Line, Id.Col);
          if VarInfo.SharedBorrowCount > 0 then
            Error('E0502', Format('Nao e possivel emprestar "%s" como mutavel pois ja existem emprestimos de leitura ativos', [VarInfo.Name]), Id.Line, Id.Col);
          VarInfo.State := vsBorrowedMut;
          PushBorrowOp(VarInfo, accBorrowMut, '');
        end
        else if Access = accBorrowShared then
        begin
          if VarInfo.State = vsBorrowedMut then
            Error('E0502', Format('Nao e possivel emprestar "%s" para leitura pois ja existe um emprestimo mutavel ativo', [VarInfo.Name]), Id.Line, Id.Col);
          Inc(VarInfo.SharedBorrowCount);
          PushBorrowOp(VarInfo, accBorrowShared, '');
        end;
        Exit;
      end;

      // Se a variavel (ou algum campo nao primitivo dela) ja foi MOVIDA, acusar erro E0382!
      if (VarInfo.State = vsMoved) or (VarInfo.MovedFields.Count > 0) then
      begin
        Error('E0382', Format('Uso de variavel movida: "%s"', [VarInfo.Name]),
          Id.Line, Id.Col, VarInfo.MovedLine, VarInfo.MovedCol);
      end;

      // Executa a transicao de estado conforme o acesso
      case Access of
        accMove:
          begin
            if (VarInfo.State = vsBorrowedMut) or (VarInfo.SharedBorrowCount > 0) or
               (VarInfo.SharedBorrowFields.Count > 0) or (VarInfo.MutBorrowFields.Count > 0) then
              Error('E0505', Format('Nao e possivel mover "%s" enquanto ainda estiver emprestada', [VarInfo.Name]), Id.Line, Id.Col);
            VarInfo.State := vsMoved;
            VarInfo.MovedLine := Id.Line;
            VarInfo.MovedCol := Id.Col;
          end;
        accBorrowShared:
          begin
            if (VarInfo.State = vsBorrowedMut) or (VarInfo.MutBorrowFields.Count > 0) then
              Error('E0502', Format('Nao e possivel emprestar "%s" para leitura pois ja existe um emprestimo mutavel ativo', [VarInfo.Name]), Id.Line, Id.Col);
            Inc(VarInfo.SharedBorrowCount);
            PushBorrowOp(VarInfo, accBorrowShared, '');
          end;
        accBorrowMut:
          begin
            if (VarInfo.State = vsBorrowedMut) or (VarInfo.MutBorrowFields.Count > 0) then
              Error('E0499', Format('Nao e possivel emprestar "%s" como mutavel mais de uma vez ao mesmo tempo', [VarInfo.Name]), Id.Line, Id.Col);
            if (VarInfo.SharedBorrowCount > 0) or (VarInfo.SharedBorrowFields.Count > 0) then
              Error('E0502', Format('Nao e possivel emprestar "%s" como mutavel pois ja existem emprestimos de leitura ativos', [VarInfo.Name]), Id.Line, Id.Col);
            VarInfo.State := vsBorrowedMut;
            PushBorrowOp(VarInfo, accBorrowMut, '');
          end;
        accRead:
          begin
            // Leitura normal
          end;
      end;
    end;
    Exit;
  end;

  // Acesso a membro: obj.campo (com rastreamento disjunto de campos)
  if Expr is TASTMemberAccessExpr then
  begin
    MemAcc := TASTMemberAccessExpr(Expr);
    if ExtractFieldRoot(MemAcc, RootId, FieldPath) then
    begin
      VarInfo := FCurrentScope.Resolve(RootId.Name);
      if Assigned(VarInfo) then
      begin
        if VarInfo.State = vsMoved then
          Error('E0382', Format('Uso de campo "%s.%s" apos movimento da variavel "%s"', [VarInfo.Name, FieldPath, VarInfo.Name]),
            MemAcc.Line, MemAcc.Col, VarInfo.MovedLine, VarInfo.MovedCol);
        if HasFieldConflict(VarInfo.MovedFields, FieldPath) then
          Error('E0382', Format('Uso de campo ja movido: "%s.%s"', [VarInfo.Name, FieldPath]),
            MemAcc.Line, MemAcc.Col, VarInfo.MovedLine, VarInfo.MovedCol);

        case Access of
          accMove:
            begin
              if (VarInfo.State = vsBorrowedMut) or (VarInfo.SharedBorrowCount > 0) or
                 HasFieldConflict(VarInfo.MutBorrowFields, FieldPath) or
                 HasFieldConflict(VarInfo.SharedBorrowFields, FieldPath) then
                Error('E0505', Format('Nao e possivel mover "%s.%s" enquanto houver emprestimo ativo', [VarInfo.Name, FieldPath]), MemAcc.Line, MemAcc.Col);
              FieldType := GetFieldType(VarInfo.TypeName, FieldPath);
              if (FieldType <> '') and (not IsPrimitiveType(FieldType)) then
              begin
                VarInfo.MovedFields.Add(FieldPath);
                if VarInfo.MovedLine = 0 then
                begin
                  VarInfo.MovedLine := MemAcc.Line;
                  VarInfo.MovedCol := MemAcc.Col;
                end;
              end;
            end;
          accBorrowShared:
            begin
              if (VarInfo.State = vsBorrowedMut) or HasFieldConflict(VarInfo.MutBorrowFields, FieldPath) then
                Error('E0502', Format('Nao e possivel emprestar "%s.%s" para leitura pois conflita com emprestimo mutavel ativo', [VarInfo.Name, FieldPath]), MemAcc.Line, MemAcc.Col);
              VarInfo.SharedBorrowFields.Add(FieldPath);
              PushBorrowOp(VarInfo, accBorrowShared, FieldPath);
            end;
          accBorrowMut:
            begin
              if (VarInfo.State = vsBorrowedMut) or HasFieldConflict(VarInfo.MutBorrowFields, FieldPath) then
                Error('E0499', Format('Nao e possivel emprestar "%s.%s" como mutavel mais de uma vez ao mesmo tempo', [VarInfo.Name, FieldPath]), MemAcc.Line, MemAcc.Col);
              if (VarInfo.SharedBorrowCount > 0) or HasFieldConflict(VarInfo.SharedBorrowFields, FieldPath) then
                Error('E0502', Format('Nao e possivel emprestar "%s.%s" como mutavel pois ja existe emprestimo de leitura conflitante ativo', [VarInfo.Name, FieldPath]), MemAcc.Line, MemAcc.Col);
              VarInfo.MutBorrowFields.Add(FieldPath);
              PushBorrowOp(VarInfo, accBorrowMut, FieldPath);
            end;
          accRead:
            begin
              if (VarInfo.State = vsBorrowedMut) or HasFieldConflict(VarInfo.MutBorrowFields, FieldPath) then
                Error('E0502', Format('Nao e possivel ler "%s.%s" enquanto houver emprestimo mutavel ativo', [VarInfo.Name, FieldPath]), MemAcc.Line, MemAcc.Col);
            end;
        end;
        Exit;
      end;
    end;
    CheckExpr(MemAcc.Target, accRead);
    Exit;
  end;

  // Chamada de Funcao
  if Expr is TASTCallExpr then
  begin
    Call := TASTCallExpr(Expr);
    SavedBorrowTop := Length(FBorrowOps);
    try
      if (SameText(Call.Callee, 'Free') or SameText(Call.Callee, 'Dispose')) and (Call.Args.Count = 1) then
        CheckExpr(TASTCallArg(Call.Args[0]).Expr, accMove)
      else
        for I := 0 to Call.Args.Count - 1 do
          CheckCallArg(TASTCallArg(Call.Args[I]));
    finally
      ReleaseBorrowsTo(SavedBorrowTop);
    end;
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

  // Indexacao de Array
  if Expr is TASTIndexExpr then
  begin
    CheckExpr(TASTIndexExpr(Expr).Target, Access);
    for I := 0 to TASTIndexExpr(Expr).Indices.Count - 1 do
      CheckExpr(TASTExpr(TASTIndexExpr(Expr).Indices[I]), accRead);
    Exit;
  end;

  // Literal de Conjunto
  if Expr is TASTSetLiteralExpr then
  begin
    for I := 0 to TASTSetLiteralExpr(Expr).Elements.Count - 1 do
      CheckExpr(TASTExpr(TASTSetLiteralExpr(Expr).Elements[I]), accRead);
    Exit;
  end;

  // Literal de Mapa
  if Expr is TASTMapLiteralExpr then
  begin
    for I := 0 to TASTMapLiteralExpr(Expr).Keys.Count - 1 do
    begin
      CheckExpr(TASTExpr(TASTMapLiteralExpr(Expr).Keys[I]), accRead);
      CheckExpr(TASTExpr(TASTMapLiteralExpr(Expr).Values[I]), accRead);
    end;
    Exit;
  end;

  if Expr is TASTIfExpr then
  begin
    CheckExpr(TASTIfExpr(Expr).Condition, accRead);
    CheckExpr(TASTIfExpr(Expr).ThenExpr, accRead);
    CheckExpr(TASTIfExpr(Expr).ElseExpr, accRead);
    Exit;
  end;

  if Expr is TASTMatchExpr then
  begin
    MExpr := TASTMatchExpr(Expr);
    CheckExpr(MExpr.Expr, accBorrowShared);
    for I := 0 to MExpr.Cases.Count - 1 do
    begin
      CaseNode := TASTMatchCase(MExpr.Cases[I]);
      EnterScope;
      try
        if CaseNode.Pattern.SubPattern <> '' then
          FCurrentScope.AddVar(CaseNode.Pattern.SubPattern, '', vsOwned, CaseNode.Line, CaseNode.Col, False);
        if Assigned(CaseNode.Guard) then
          CheckExpr(CaseNode.Guard, accRead);
        if Assigned(CaseNode.ValueExpr) then
          CheckExpr(CaseNode.ValueExpr, accRead);
      finally
        LeaveScope;
      end;
    end;
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
  ForStmt: TASTForStmt;
  RepeatStmt: TASTRepeatStmt;
  MatchStmt: TASTMatchStmt;
  CaseNode: TASTMatchCase;
  Ret: TASTReturnStmt;
  CallStmt: TASTCallStmt;
  VarDecl: TASTVarDecl;
  VarInfo, V: TBorrowVarInfo;
  RootId: TASTIdentifierExpr;
  FieldPath: string;
  I, J, K: Integer;
  SavedStates, SavedMovedLists, ThenStates, ThenMovedLists: TFPList;
  Scope: TBorrowScope;
  ThenSt: TVariableState;
  MovedCopy, ThenMovedCopy: TStringList;
begin
  if Stmt is TASTAssignStmt then
  begin
    Assign := TASTAssignStmt(Stmt);
    CheckExpr(Assign.Expr, accRead);
    // Atribuicao a uma variavel ou campo reinicializa a posse se antes estava movida
    if Assign.Target is TASTIdentifierExpr then
    begin
      VarInfo := FCurrentScope.Resolve(TASTIdentifierExpr(Assign.Target).Name);
      if Assigned(VarInfo) then
      begin
        VarInfo.State := vsOwned;
        VarInfo.MovedFields.Clear;
      end;
    end
    else if ExtractFieldRoot(Assign.Target, RootId, FieldPath) then
    begin
      VarInfo := FCurrentScope.Resolve(RootId.Name);
      if Assigned(VarInfo) then
      begin
        if VarInfo.State <> vsMoved then
          ClearSubFields(VarInfo.MovedFields, FieldPath);
      end;
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
    ReleaseBorrowsTo(0);
    if Assigned(FCurrentScope) then
      FCurrentScope.ReleaseTemporaryBorrows;

    SavedStates := TFPList.Create;
    SavedMovedLists := TFPList.Create;
    try
      Scope := FCurrentScope;
      while Assigned(Scope) do
      begin
        for I := 0 to Scope.Vars.Count - 1 do
        begin
          V := TBorrowVarInfo(Scope.Vars[I]);
          SavedStates.Add(V);
          SavedStates.Add(Pointer(PtrUInt(V.State)));
          MovedCopy := TStringList.Create;
          MovedCopy.Assign(V.MovedFields);
          SavedMovedLists.Add(MovedCopy);
        end;
        Scope := Scope.Parent;
      end;

      for I := 0 to IfStmt.ThenBranch.Count - 1 do
        CheckStmt(TASTStmt(IfStmt.ThenBranch[I]));

      if IfStmt.ElseBranch.Count > 0 then
      begin
        ThenStates := TFPList.Create;
        ThenMovedLists := TFPList.Create;
        try
          I := 0;
          K := 0;
          while I < SavedStates.Count do
          begin
            V := TBorrowVarInfo(SavedStates[I]);
            ThenStates.Add(Pointer(PtrUInt(V.State)));
            ThenMovedCopy := TStringList.Create;
            ThenMovedCopy.Assign(V.MovedFields);
            ThenMovedLists.Add(ThenMovedCopy);

            V.State := TVariableState(PtrUInt(SavedStates[I + 1]));
            V.MovedFields.Assign(TStringList(SavedMovedLists[K]));
            Inc(I, 2);
            Inc(K);
          end;

          for I := 0 to IfStmt.ElseBranch.Count - 1 do
            CheckStmt(TASTStmt(IfStmt.ElseBranch[I]));

          I := 0;
          K := 0;
          while I < SavedStates.Count do
          begin
            V := TBorrowVarInfo(SavedStates[I]);
            ThenSt := TVariableState(PtrUInt(ThenStates[I div 2]));
            if (ThenSt = vsMoved) or (V.State = vsMoved) then
              V.State := vsMoved;
            ThenMovedCopy := TStringList(ThenMovedLists[K]);
            for J := 0 to ThenMovedCopy.Count - 1 do
              if V.MovedFields.IndexOf(ThenMovedCopy[J]) < 0 then
                V.MovedFields.Add(ThenMovedCopy[J]);
            Inc(I, 2);
            Inc(K);
          end;
        finally
          for I := 0 to ThenMovedLists.Count - 1 do
            TStringList(ThenMovedLists[I]).Free;
          ThenMovedLists.Free;
          ThenStates.Free;
        end;
      end;
    finally
      for I := 0 to SavedMovedLists.Count - 1 do
        TStringList(SavedMovedLists[I]).Free;
      SavedMovedLists.Free;
      SavedStates.Free;
    end;
  end
  else if Stmt is TASTWhileStmt then
  begin
    WhileStmt := TASTWhileStmt(Stmt);
    CheckExpr(WhileStmt.Condition, accRead);
    ReleaseBorrowsTo(0);
    if Assigned(FCurrentScope) then
      FCurrentScope.ReleaseTemporaryBorrows;
    for I := 0 to WhileStmt.Body.Count - 1 do
      CheckStmt(TASTStmt(WhileStmt.Body[I]));
  end
  else if Stmt is TASTForStmt then
  begin
    ForStmt := TASTForStmt(Stmt);
    if Assigned(ForStmt.CollectionExpr) then
      CheckExpr(ForStmt.CollectionExpr, accBorrowShared)
    else
    begin
      CheckExpr(ForStmt.StartExpr, accRead);
      CheckExpr(ForStmt.EndExpr, accRead);
    end;
    ReleaseBorrowsTo(0);
    if Assigned(FCurrentScope) then
      FCurrentScope.ReleaseTemporaryBorrows;
    EnterScope;
    try
      if Assigned(ForStmt.CollectionExpr) then
      begin
        FCurrentScope.AddVar(ForStmt.VarName, '', vsOwned, ForStmt.Line, ForStmt.Col, True);
        if ForStmt.ValVarName <> '' then
          FCurrentScope.AddVar(ForStmt.ValVarName, '', vsOwned, ForStmt.Line, ForStmt.Col, True);
      end;
      for I := 0 to ForStmt.Body.Count - 1 do
        CheckStmt(TASTStmt(ForStmt.Body[I]));
    finally
      LeaveScope;
    end;
  end
  else if Stmt is TASTRepeatStmt then
  begin
    RepeatStmt := TASTRepeatStmt(Stmt);
    for I := 0 to RepeatStmt.Body.Count - 1 do
      CheckStmt(TASTStmt(RepeatStmt.Body[I]));
    if Assigned(RepeatStmt.Condition) then
      CheckExpr(RepeatStmt.Condition, accRead);
    ReleaseBorrowsTo(0);
    if Assigned(FCurrentScope) then
      FCurrentScope.ReleaseTemporaryBorrows;
  end
  else if (Stmt is TASTBreakStmt) or (Stmt is TASTContinueStmt) then
  begin
    // Controle de fluxo de laco: nenhuma transicao de borrow
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
  else if Stmt is TASTDeferStmt then
  begin
    if Assigned(TASTDeferStmt(Stmt).Stmt) then
      CheckStmt(TASTDeferStmt(Stmt).Stmt);
  end
  else if Stmt is TASTTryStmt then
  begin
    for I := 0 to TASTTryStmt(Stmt).TryBody.Count - 1 do
      CheckStmt(TASTStmt(TASTTryStmt(Stmt).TryBody[I]));
    for I := 0 to TASTTryStmt(Stmt).ExceptBody.Count - 1 do
      CheckStmt(TASTStmt(TASTTryStmt(Stmt).ExceptBody[I]));
  end
  else if Stmt is TASTRaiseStmt then
  begin
    if Assigned(TASTRaiseStmt(Stmt).Expr) then
      CheckExpr(TASTRaiseStmt(Stmt).Expr, accRead);
  end
  else if Stmt is TASTVarDeclStmt then
  begin
    for I := 0 to TASTVarDeclStmt(Stmt).Decls.Count - 1 do
    begin
      VarDecl := TASTVarDecl(TASTVarDeclStmt(Stmt).Decls[I]);
      if Assigned(VarDecl.InitialExpr) then
        CheckExpr(VarDecl.InitialExpr, accRead);
      FCurrentScope.AddVar(VarDecl.Name, VarDecl.TypeName, vsOwned, VarDecl.Line, VarDecl.Col, IsPrimitiveType(VarDecl.TypeName));
    end;
  end
  else if Stmt is TASTUnsafeStmt then
  begin
    for I := 0 to TASTUnsafeStmt(Stmt).Body.Count - 1 do
      CheckStmt(TASTStmt(TASTUnsafeStmt(Stmt).Body[I]));
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
          FCurrentScope.AddVar(CaseNode.Pattern.SubPattern, '', vsOwned, CaseNode.Line, CaseNode.Col, False);
        if Assigned(CaseNode.Guard) then
          CheckExpr(CaseNode.Guard, accRead);
        for J := 0 to CaseNode.Body.Count - 1 do
          CheckStmt(TASTStmt(CaseNode.Body[J]));
      finally
        LeaveScope;
      end;
    end;
  end;

  ReleaseBorrowsTo(0);
  if Assigned(FCurrentScope) then
    FCurrentScope.ReleaseTemporaryBorrows;
end;

procedure TAetherBorrowChecker.CheckFunction(Func: TASTFunction);
var
  I: Integer;
  Param: TASTParam;
  VarDecl: TASTVarDecl;
  OldGenericParam: string;
begin
  OldGenericParam := FCurrentGenericParam;
  FCurrentGenericParam := Func.GenericParam;
  EnterScope;
  try
    // Parametros da funcao
    for I := 0 to Func.Params.Count - 1 do
    begin
      Param := TASTParam(Func.Params[I]);
      FCurrentScope.AddVar(Param.Name, Param.TypeName, vsOwned, Param.Line, Param.Col, IsPrimitiveType(Param.TypeName));
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
      FCurrentScope.AddVar(VarDecl.Name, VarDecl.TypeName, vsOwned, VarDecl.Line, VarDecl.Col, IsPrimitiveType(VarDecl.TypeName));
    end;

    // Instrucoes do corpo
    for I := 0 to Func.Body.Count - 1 do
      CheckStmt(TASTStmt(Func.Body[I]));
  finally
    LeaveScope;
    FCurrentGenericParam := OldGenericParam;
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
      FCurrentScope.AddVar(VarDecl.Name, VarDecl.TypeName, vsOwned, VarDecl.Line, VarDecl.Col, IsPrimitiveType(VarDecl.TypeName));
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
  VarDecl: TASTVarDecl;
begin
  FModule := AModule;
  EnterScope;
  try
    for I := 0 to AModule.ModuleVars.Count - 1 do
    begin
      VarDecl := TASTVarDecl(AModule.ModuleVars[I]);
      if Assigned(VarDecl.InitialExpr) then
        CheckExpr(VarDecl.InitialExpr, accRead);
      FCurrentScope.AddVar(VarDecl.Name, VarDecl.TypeName, vsOwned, VarDecl.Line, VarDecl.Col, IsPrimitiveType(VarDecl.TypeName));
    end;

    for I := 0 to AModule.Functions.Count - 1 do
    begin
      Func := TASTFunction(AModule.Functions[I]);
      CheckFunction(Func);
    end;

    for I := 0 to AModule.InitBody.Count - 1 do
      CheckStmt(TASTStmt(AModule.InitBody[I]));

    for I := 0 to AModule.FiniBody.Count - 1 do
      CheckStmt(TASTStmt(AModule.FiniBody[I]));

    if Assigned(AModule.ProgramBlock) then
      CheckProgramBlock(AModule.ProgramBlock);
  finally
    LeaveScope;
  end;
end;

end.
