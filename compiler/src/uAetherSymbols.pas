unit uAetherSymbols;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, uAetherAST;

type
  TSymbolKind = (skVariable, skFunction, skType, skEnumVariant, skTrait);

  TSymbol = class
  public
    Name: string;
    Kind: TSymbolKind;
    TypeName: string;
    Line: Integer;
    Col: Integer;
    IsMutable: Boolean;
    Ownership: TOwnershipKind;
    Node: TASTNode; // Referencia opcional ao no da AST (ex: TASTFunction, TASTEnumDecl)
    constructor Create(const AName: string; AKind: TSymbolKind; const AType: string;
      ALine, ACol: Integer; AMut: Boolean = True; AOwn: TOwnershipKind = owNone; ANode: TASTNode = nil);
  end;

  TScope = class
  private
    FParent: TScope;
    FSymbols: TFPList;
    function FindSymbolIndex(const AName: string): Integer;
  public
    constructor Create(AParent: TScope = nil);
    destructor Destroy; override;

    procedure Define(Sym: TSymbol);
    function Resolve(const AName: string): TSymbol;
    function ResolveLocal(const AName: string): TSymbol;
    function ResolveType(const AName: string): TSymbol;
    property Parent: TScope read FParent;
  end;

  TSymbolTable = class
  private
    FGlobalScope: TScope;
    FCurrentScope: TScope;
    procedure InitBuiltinTypes;
  public
    constructor Create;
    destructor Destroy; override;

    procedure EnterScope;
    procedure LeaveScope;
    procedure Define(Sym: TSymbol);
    function Resolve(const AName: string): TSymbol;
    function ResolveType(const ATypeName: string): Boolean;
    function ResolveTypeSymbol(const ATypeName: string): TSymbol;

    property CurrentScope: TScope read FCurrentScope;
    property GlobalScope: TScope read FGlobalScope;
  end;

implementation

{ TSymbol }

constructor TSymbol.Create(const AName: string; AKind: TSymbolKind; const AType: string;
  ALine, ACol: Integer; AMut: Boolean; AOwn: TOwnershipKind; ANode: TASTNode);
begin
  inherited Create;
  Name := AName;
  Kind := AKind;
  TypeName := AType;
  Line := ALine;
  Col := ACol;
  IsMutable := AMut;
  Ownership := AOwn;
  Node := ANode;
end;

{ TScope }

constructor TScope.Create(AParent: TScope);
begin
  inherited Create;
  FParent := AParent;
  FSymbols := TFPList.Create;
end;

destructor TScope.Destroy;
var
  I: Integer;
begin
  for I := 0 to FSymbols.Count - 1 do
    TSymbol(FSymbols[I]).Free;
  FSymbols.Free;
  inherited Destroy;
end;

function TScope.FindSymbolIndex(const AName: string): Integer;
var
  I: Integer;
  Sym: TSymbol;
begin
  for I := 0 to FSymbols.Count - 1 do
  begin
    Sym := TSymbol(FSymbols[I]);
    if SameText(Sym.Name, AName) then
      Exit(I);
  end;
  Result := -1;
end;

procedure TScope.Define(Sym: TSymbol);
var
  Idx: Integer;
begin
  Idx := FindSymbolIndex(Sym.Name);
  if Idx <> -1 then
    raise Exception.CreateFmt('Simbolo "%s" ja definido neste escopo na linha %d', [Sym.Name, TSymbol(FSymbols[Idx]).Line]);
  FSymbols.Add(Sym);
end;

function TScope.ResolveLocal(const AName: string): TSymbol;
var
  Idx: Integer;
begin
  Idx := FindSymbolIndex(AName);
  if Idx <> -1 then
    Result := TSymbol(FSymbols[Idx])
  else
    Result := nil;
end;

function TScope.Resolve(const AName: string): TSymbol;
var
  Current: TScope;
  Sym: TSymbol;
begin
  Current := Self;
  while Assigned(Current) do
  begin
    Sym := Current.ResolveLocal(AName);
    if Assigned(Sym) then
      Exit(Sym);
    Current := Current.Parent;
  end;
  Result := nil;
end;

function TScope.ResolveType(const AName: string): TSymbol;
var
  Current: TScope;
  Sym: TSymbol;
  I: Integer;
begin
  Current := Self;
  while Assigned(Current) do
  begin
    for I := 0 to Current.FSymbols.Count - 1 do
    begin
      Sym := TSymbol(Current.FSymbols[I]);
      if (Sym.Kind = skType) and SameText(Sym.Name, AName) then
        Exit(Sym);
    end;
    Current := Current.Parent;
  end;
  Result := nil;
end;

{ TSymbolTable }

constructor TSymbolTable.Create;
begin
  inherited Create;
  FGlobalScope := TScope.Create(nil);
  FCurrentScope := FGlobalScope;
  InitBuiltinTypes;
end;

destructor TSymbolTable.Destroy;
begin
  // Como os escopos sao encadeados, desalocamos a partir do global ou atual
  while FCurrentScope <> FGlobalScope do
    LeaveScope;
  FGlobalScope.Free;
  inherited Destroy;
end;

procedure TSymbolTable.InitBuiltinTypes;
  procedure AddType(const TypeName: string);
  begin
    FGlobalScope.Define(TSymbol.Create(TypeName, skType, TypeName, 0, 0));
  end;
begin
  // Tipos Primitivos Inteiros
  AddType('Int8');
  AddType('Int16');
  AddType('Int32');
  AddType('Int64');
  AddType('UInt8');
  AddType('UInt16');
  AddType('UInt32');
  AddType('UInt64');

  // Ponto Flutuante
  AddType('Float32');
  AddType('Float64');

  // Booleano, Caractere, String e Ponteiro
  AddType('Bool');
  AddType('Char');
  AddType('String');
  AddType('Void');
  AddType('Pointer');

  // Funcoes nativas embutidas
  FGlobalScope.Define(TSymbol.Create('PrintLn', skFunction, 'Void', 0, 0));
  FGlobalScope.Define(TSymbol.Create('Print', skFunction, 'Void', 0, 0));
  FGlobalScope.Define(TSymbol.Create('Ok', skFunction, 'Result', 0, 0));
  FGlobalScope.Define(TSymbol.Create('Err', skFunction, 'Result', 0, 0));
  FGlobalScope.Define(TSymbol.Create('Some', skFunction, 'Option', 0, 0));
  FGlobalScope.Define(TSymbol.Create('None', skFunction, 'Option', 0, 0));
  FGlobalScope.Define(TSymbol.Create('Length', skFunction, 'UInt32', 0, 0));
  FGlobalScope.Define(TSymbol.Create('CharAt', skFunction, 'String', 0, 0));
  FGlobalScope.Define(TSymbol.Create('Substring', skFunction, 'String', 0, 0));
  FGlobalScope.Define(TSymbol.Create('FileExists', skFunction, 'Bool', 0, 0));
  FGlobalScope.Define(TSymbol.Create('ReadFile', skFunction, 'String', 0, 0));
  FGlobalScope.Define(TSymbol.Create('WriteFile', skFunction, 'Bool', 0, 0));
  FGlobalScope.Define(TSymbol.Create('CreateDir', skFunction, 'Bool', 0, 0));
  FGlobalScope.Define(TSymbol.Create('RemoveDir', skFunction, 'Bool', 0, 0));
  FGlobalScope.Define(TSymbol.Create('DeleteFile', skFunction, 'Bool', 0, 0));
  FGlobalScope.Define(TSymbol.Create('DirExists', skFunction, 'Bool', 0, 0));
  FGlobalScope.Define(TSymbol.Create('FileSize', skFunction, 'Int64', 0, 0));
  FGlobalScope.Define(TSymbol.Create('GetNanoseconds', skFunction, 'UInt64', 0, 0));
  FGlobalScope.Define(TSymbol.Create('SleepMs', skFunction, 'Void', 0, 0));
  FGlobalScope.Define(TSymbol.Create('IntToStr', skFunction, 'String', 0, 0));
  FGlobalScope.Define(TSymbol.Create('FloatToStr', skFunction, 'String', 0, 0));
  FGlobalScope.Define(TSymbol.Create('BoolToStr', skFunction, 'String', 0, 0));
  FGlobalScope.Define(TSymbol.Create('StrToInt', skFunction, 'Int32', 0, 0));
  FGlobalScope.Define(TSymbol.Create('ParamCount', skFunction, 'Int32', 0, 0));
  FGlobalScope.Define(TSymbol.Create('ParamStr', skFunction, 'String', 0, 0));
  FGlobalScope.Define(TSymbol.Create('Assert', skFunction, 'Void', 0, 0));

  // Funcoes nativas de Sockets (SO / Rede)
  FGlobalScope.Define(TSymbol.Create('SocketCreate', skFunction, 'Int32', 0, 0));
  FGlobalScope.Define(TSymbol.Create('SocketListen', skFunction, 'Int32', 0, 0));
  FGlobalScope.Define(TSymbol.Create('SocketAccept', skFunction, 'Int32', 0, 0));
  FGlobalScope.Define(TSymbol.Create('SocketConnect', skFunction, 'Int32', 0, 0));
  FGlobalScope.Define(TSymbol.Create('SocketSend', skFunction, 'Int32', 0, 0));
  FGlobalScope.Define(TSymbol.Create('SocketRecv', skFunction, 'String', 0, 0));
  FGlobalScope.Define(TSymbol.Create('SocketClose', skFunction, 'Void', 0, 0));
end;

procedure TSymbolTable.EnterScope;
begin
  FCurrentScope := TScope.Create(FCurrentScope);
end;

procedure TSymbolTable.LeaveScope;
var
  OldScope: TScope;
begin
  if FCurrentScope <> FGlobalScope then
  begin
    OldScope := FCurrentScope;
    FCurrentScope := FCurrentScope.Parent;
    OldScope.Free;
  end;
end;

procedure TSymbolTable.Define(Sym: TSymbol);
begin
  FCurrentScope.Define(Sym);
end;

function TSymbolTable.Resolve(const AName: string): TSymbol;
begin
  Result := FCurrentScope.Resolve(AName);
end;

function TSymbolTable.ResolveTypeSymbol(const ATypeName: string): TSymbol;
var
  CleanName: string;
  P: Integer;
begin
  CleanName := ATypeName;
  P := Pos('<', CleanName);
  if P > 0 then
    CleanName := Copy(CleanName, 1, P - 1);
  Result := FCurrentScope.ResolveType(CleanName);
end;

function TSymbolTable.ResolveType(const ATypeName: string): Boolean;
var
  CleanName: string;
  P: Integer;
  Sym: TSymbol;
begin
  CleanName := ATypeName;
  P := Pos('<', CleanName);
  if P > 0 then
    CleanName := Copy(CleanName, 1, P - 1);

  if (CleanName = 'Result') or (CleanName = 'Option') or (CleanName = 'Box') or (CleanName = 'Task') or
     (Pos('array[', CleanName) = 1) or (Pos('set of', CleanName) = 1) then
    Exit(True);

  Sym := ResolveTypeSymbol(CleanName);
  Result := Assigned(Sym) and (Sym.Kind = skType);
end;

end.
