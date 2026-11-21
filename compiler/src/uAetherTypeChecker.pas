unit uAetherTypeChecker;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  uAetherAST,
  uAetherSymbols;

type
  PTraitImplInfo = ^TTraitImplInfo;
  TTraitImplInfo = record
    TargetType: string;
    TraitName: string;
    OriginalMethod: string;
    MangledMethod: string;
  end;

  EAetherTypeError = class(Exception)
  public
    Line: Integer;
    Col: Integer;
    Code: string;
    constructor Create(const ACode, AMsg: string; ALine, ACol: Integer);
  end;

  TAetherTypeChecker = class
  private
    FSymbols: TSymbolTable;
    FCurrentFunction: TASTFunction;
    FModule: TASTModule;
    FTraitImpls: TFPList;

    procedure Error(const ACode, AMsg: string; ALine, ACol: Integer);
    function IsNumericType(const AType: string): Boolean;
    function IsIntegerType(const AType: string): Boolean;
    function TypesAreCompatible(const TargetType, SourceType: string): Boolean;

    function CheckExpr(Expr: TASTExpr): string;
    function CheckLiteral(Lit: TASTLiteralExpr): string;
    function CheckIdentifier(Id: TASTIdentifierExpr): string;
    function CheckMemberAccess(Acc: TASTMemberAccessExpr): string;
    function CheckBinary(Bin: TASTBinaryExpr): string;
    function CheckUnary(Un: TASTUnaryExpr): string;
    function CheckCall(Call: TASTCallExpr): string;

    procedure CheckStmt(Stmt: TASTStmt);
    procedure CheckAssign(Assign: TASTAssignStmt);
    procedure CheckIf(IfStmt: TASTIfStmt);
    procedure CheckWhile(WhileStmt: TASTWhileStmt);
    procedure CheckReturn(Ret: TASTReturnStmt);
    procedure CheckMatch(MatchStmt: TASTMatchStmt);

    procedure RegisterTypes(AModule: TASTModule);
    procedure RegisterTraits(AModule: TASTModule);
    procedure RegisterImpls(AModule: TASTModule);
    procedure RegisterFunctions(AModule: TASTModule);
    function TypeImplementsTrait(const ATypeName, ATraitName: string): Boolean;
    function FindTraitMethod(const ATypeName, AMethodName: string): string;
    function MonomorphizeFunction(OriginalFunc: TASTFunction; const ConcreteType: string): TASTFunction;
    procedure CheckFunction(Func: TASTFunction);
    procedure CheckProgramBlock(Prog: TASTProgramBlock);
  public
    constructor Create;
    destructor Destroy; override;
    procedure CheckModule(AModule: TASTModule);
    property Symbols: TSymbolTable read FSymbols;
  end;

implementation

constructor EAetherTypeError.Create(const ACode, AMsg: string; ALine, ACol: Integer);
begin
  inherited Create(Format('[Erro Semantico %s em %d:%d]: %s', [ACode, ALine, ACol, AMsg]));
  Code := ACode;
  Line := ALine;
  Col := ACol;
end;

constructor TAetherTypeChecker.Create;
begin
  inherited Create;
  FSymbols := TSymbolTable.Create;
  FCurrentFunction := nil;
  FModule := nil;
  FTraitImpls := TFPList.Create;
end;

destructor TAetherTypeChecker.Destroy;
var
  I: Integer;
begin
  for I := 0 to FTraitImpls.Count - 1 do
    Dispose(PTraitImplInfo(FTraitImpls[I]));
  FTraitImpls.Free;
  FSymbols.Free;
  inherited Destroy;
end;

procedure TAetherTypeChecker.Error(const ACode, AMsg: string; ALine, ACol: Integer);
begin
  raise EAetherTypeError.Create(ACode, AMsg, ALine, ACol);
end;

function TAetherTypeChecker.IsNumericType(const AType: string): Boolean;
begin
  Result := (AType = 'Int8') or (AType = 'Int16') or (AType = 'Int32') or (AType = 'Int64') or
            (AType = 'UInt8') or (AType = 'UInt16') or (AType = 'UInt32') or (AType = 'UInt64') or
            (AType = 'Float32') or (AType = 'Float64');
end;

function TAetherTypeChecker.IsIntegerType(const AType: string): Boolean;
begin
  Result := (AType = 'Int8') or (AType = 'Int16') or (AType = 'Int32') or (AType = 'Int64') or
            (AType = 'UInt8') or (AType = 'UInt16') or (AType = 'UInt32') or (AType = 'UInt64') or
            (AType = 'IntLiteral');
end;

function TAetherTypeChecker.TypesAreCompatible(const TargetType, SourceType: string): Boolean;
begin
  if TargetType = SourceType then Exit(True);
  // Literais inteiros genericos sao compativeis com qualquer tipo inteiro
  if (SourceType = 'IntLiteral') and (Pos('Int', TargetType) > 0) then Exit(True);
  // Literais float genericos sao compativeis com Float32 ou Float64
  if (SourceType = 'FloatLiteral') and (Pos('Float', TargetType) > 0) then Exit(True);
  // Genericos Result / Option / Box
  if (Pos('Result', TargetType) = 1) and (Pos('Result', SourceType) = 1) then Exit(True);
  if (Pos('Option', TargetType) = 1) and ((Pos('Option', SourceType) = 1) or (SourceType = 'Option<GenericNone>')) then Exit(True);
  if (Pos('Box', TargetType) = 1) and (Pos('Box', SourceType) = 1) then Exit(True);
  if (Pos('Option<Box<', TargetType) = 1) and ((Pos('Box<', SourceType) = 1) or (SourceType = 'Option<GenericNone>')) then Exit(True);
  Result := False;
end;

function TAetherTypeChecker.CheckLiteral(Lit: TASTLiteralExpr): string;
begin
  case Lit.Kind of
    lkInt:    Result := 'IntLiteral';
    lkFloat:  Result := 'FloatLiteral';
    lkString: Result := 'String';
    lkChar:   Result := 'Char';
    lkBool:   Result := 'Bool';
  else
    Result := 'Unknown';
  end;
end;

function TAetherTypeChecker.CheckIdentifier(Id: TASTIdentifierExpr): string;
var
  Sym: TSymbol;
begin
  // Caso especial: 'None' (Option vazio)
  if SameText(Id.Name, 'None') then
    Exit('Option<GenericNone>');

  // Caso especial: 'result' dentro de contratos
  if SameText(Id.Name, 'result') and Assigned(FCurrentFunction) then
    Exit(FCurrentFunction.ReturnType);

  Sym := FSymbols.Resolve(Id.Name);
  if not Assigned(Sym) then
    Error('E0425', Format('Identificador nao encontrado: "%s"', [Id.Name]), Id.Line, Id.Col);

  Result := Sym.TypeName;
end;

function TAetherTypeChecker.CheckMemberAccess(Acc: TASTMemberAccessExpr): string;
var
  TargetType: string;
  Sym: TSymbol;
  I, P1, P2: Integer;
  RecDecl: TASTRecordDecl;
  EnumDecl: TASTEnumDecl;
  Field: TASTRecordField;
  InnerRecName: string;
begin
  // Se o alvo for um Identificador, pode ser um tipo (Enum) ou uma variavel
  if Acc.Target is TASTIdentifierExpr then
  begin
    Sym := FSymbols.Resolve(TASTIdentifierExpr(Acc.Target).Name);
    if Assigned(Sym) then
    begin
      // Caso Enum.Variante (ex: MathError.DivisaoPorZero)
      if (Sym.Kind = skType) and (Sym.Node is TASTEnumDecl) then
      begin
        EnumDecl := TASTEnumDecl(Sym.Node);
        for I := 0 to EnumDecl.Variants.Count - 1 do
        begin
          if SameText(TASTEnumVariant(EnumDecl.Variants[I]).Name, Acc.Member) then
            Exit(EnumDecl.Name);
        end;
        Error('E0599', Format('Variante "%s" nao pertence ao enum "%s"', [Acc.Member, EnumDecl.Name]), Acc.Line, Acc.Col);
      end;
    end;
  end;

  TargetType := CheckExpr(Acc.Target);

  // Propriedades intrinsecas de Result (ex: result.is_ok)
  if (Pos('Result', TargetType) = 1) and (SameText(Acc.Member, 'is_ok') or SameText(Acc.Member, 'is_err')) then
    Exit('Bool');

  // Propriedades intrinsecas de Option (ex: opt.is_some, opt.is_none, opt.value)
  if (Pos('Option', TargetType) = 1) then
  begin
    if SameText(Acc.Member, 'is_some') or SameText(Acc.Member, 'is_none') then
      Exit('Bool');

    if SameText(Acc.Member, 'value') then
    begin
      P1 := Pos('<', TargetType);
      InnerRecName := Copy(TargetType, P1 + 1, Length(TargetType));
      P2 := Pos('>', InnerRecName);
      if P2 > 0 then InnerRecName := Copy(InnerRecName, 1, P2 - 1);
      if Pos('Box<', InnerRecName) = 1 then
      begin
        P1 := Pos('<', InnerRecName);
        InnerRecName := Copy(InnerRecName, P1 + 1, Length(InnerRecName));
        P2 := Pos('>', InnerRecName);
        if P2 > 0 then InnerRecName := Copy(InnerRecName, 1, P2 - 1);
      end;
      Exit(InnerRecName);
    end;
  end;

  // Auto-deref de Box<Record> ou Option<Box<Record>>
  if Pos('Box<', TargetType) > 0 then
  begin
    P1 := Pos('Box<', TargetType);
    InnerRecName := Copy(TargetType, P1 + 4, Length(TargetType));
    P2 := Pos('>', InnerRecName);
    if P2 > 0 then InnerRecName := Copy(InnerRecName, 1, P2 - 1);

    if SameText(Acc.Member, 'value') then
      Exit(InnerRecName);

    Sym := FSymbols.Resolve(InnerRecName);
    if Assigned(Sym) and (Sym.Node is TASTRecordDecl) then
    begin
      RecDecl := TASTRecordDecl(Sym.Node);
      for I := 0 to RecDecl.Fields.Count - 1 do
      begin
        Field := TASTRecordField(RecDecl.Fields[I]);
        if SameText(Field.Name, Acc.Member) then
          Exit(Field.TypeName);
      end;
    end;
  end;

  // Membro de Record
  Sym := FSymbols.Resolve(TargetType);
  if Assigned(Sym) and (Sym.Node is TASTRecordDecl) then
  begin
    RecDecl := TASTRecordDecl(Sym.Node);
    for I := 0 to RecDecl.Fields.Count - 1 do
    begin
      Field := TASTRecordField(RecDecl.Fields[I]);
      if SameText(Field.Name, Acc.Member) then
        Exit(Field.TypeName);
    end;
    Error('E0609', Format('Campo "%s" nao existe no record "%s"', [Acc.Member, TargetType]), Acc.Line, Acc.Col);
  end;

  Error('E0609', Format('Nao e possivel acessar membro "%s" no tipo "%s"', [Acc.Member, TargetType]), Acc.Line, Acc.Col);
  Result := 'Unknown';
end;

function TAetherTypeChecker.CheckBinary(Bin: TASTBinaryExpr): string;
var
  LeftType, RightType: string;
begin
  LeftType := CheckExpr(Bin.Left);
  RightType := CheckExpr(Bin.Right);

  // Operacoes Aritmeticas: +, -, *, /, mod
  if (Bin.Op = '+') or (Bin.Op = '-') or (Bin.Op = '*') or (Bin.Op = '/') or (Bin.Op = 'mod') then
  begin
    // Concatenacao de strings com +
    if (Bin.Op = '+') and ((LeftType = 'String') or (RightType = 'String')) then
      Exit('String');

    if not IsNumericType(LeftType) and (LeftType <> 'IntLiteral') and (LeftType <> 'FloatLiteral') then
      Error('E0369', Format('Operando esquerdo de "%s" deve ser numerico, encontrado: "%s"', [Bin.Op, LeftType]), Bin.Line, Bin.Col);

    if not IsNumericType(RightType) and (RightType <> 'IntLiteral') and (RightType <> 'FloatLiteral') then
      Error('E0369', Format('Operando direito de "%s" deve ser numerico, encontrado: "%s"', [Bin.Op, RightType]), Bin.Line, Bin.Col);

    if (LeftType = 'Float64') or (RightType = 'Float64') or (LeftType = 'FloatLiteral') or (RightType = 'FloatLiteral') then
      Exit('Float64')
    else
      Exit(LeftType);
  end;

  // Operacoes Relacionais: =, <>, <, <=, >, >=
  if (Bin.Op = '=') or (Bin.Op = '<>') or (Bin.Op = '<') or (Bin.Op = '<=') or (Bin.Op = '>') or (Bin.Op = '>=') then
  begin
    if not TypesAreCompatible(LeftType, RightType) and not TypesAreCompatible(RightType, LeftType) then
      Error('E0308', Format('Comparacao entre tipos incompativeis: "%s" e "%s"', [LeftType, RightType]), Bin.Line, Bin.Col);
    Exit('Bool');
  end;

  // Operacoes Logicas: and, or, implies
  if (Bin.Op = 'and') or (Bin.Op = 'or') or (Bin.Op = 'implies') then
  begin
    if (LeftType <> 'Bool') then
      Error('E0308', Format('Operando de "%s" deve ser Bool, encontrado: "%s"', [Bin.Op, LeftType]), Bin.Line, Bin.Col);
    if (RightType <> 'Bool') then
      Error('E0308', Format('Operando de "%s" deve ser Bool, encontrado: "%s"', [Bin.Op, RightType]), Bin.Line, Bin.Col);
    Exit('Bool');
  end;

  Result := 'Unknown';
end;

function TAetherTypeChecker.CheckUnary(Un: TASTUnaryExpr): string;
var
  OperandType: string;
begin
  OperandType := CheckExpr(Un.Expr);
  if Un.Op = '-' then
  begin
    if not IsNumericType(OperandType) and (OperandType <> 'IntLiteral') and (OperandType <> 'FloatLiteral') then
      Error('E0369', Format('Operador unario "-" exige tipo numerico, encontrado: "%s"', [OperandType]), Un.Line, Un.Col);
    Exit(OperandType);
  end
  else if Un.Op = 'not' then
  begin
    if OperandType <> 'Bool' then
      Error('E0308', Format('Operador "not" exige tipo Bool, encontrado: "%s"', [OperandType]), Un.Line, Un.Col);
    Exit('Bool');
  end;
  Result := OperandType;
end;

function TAetherTypeChecker.CheckCall(Call: TASTCallExpr): string;
var
  Sym, SymMono: TSymbol;
  FuncNode, MonoFunc: TASTFunction;
  RecDecl: TASTRecordDecl;
  I: Integer;
  Arg: TASTCallArg;
  ArgType, ExpectedType, Mangled, MonomorphedName: string;
begin
  // Atalhos embutidos Ok() e Err()
  if Call.Callee = 'Ok' then
  begin
    if Call.Args.Count <> 1 then
      Error('E0061', 'Ok() exige exatamente 1 argumento', Call.Line, Call.Col);
    ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
    Exit('Result<' + ArgType + ', GenericError>');
  end;

  if Call.Callee = 'Err' then
  begin
    if Call.Args.Count <> 1 then
      Error('E0061', 'Err() exige exatamente 1 argumento', Call.Line, Call.Col);
    ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
    Exit('Result<GenericValue, ' + ArgType + '>');
  end;

  if Call.Callee = 'Some' then
  begin
    if Call.Args.Count <> 1 then
      Error('E0061', 'Some() exige exatamente 1 argumento', Call.Line, Call.Col);
    ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
    Exit('Option<' + ArgType + '>');
  end;

  if Call.Callee = 'Box' then
  begin
    if Call.Args.Count <> 1 then
      Error('E0061', 'Box() exige exatamente 1 argumento', Call.Line, Call.Col);
    ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
    Exit('Box<' + ArgType + '>');
  end;

  Sym := FSymbols.Resolve(Call.Callee);
  if not Assigned(Sym) then
  begin
    // Resolução de método de Trait via primeiro argumento (UFCS)
    if Call.Args.Count > 0 then
    begin
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if Pos('Box<', ArgType) = 1 then
      begin
        ArgType := Copy(ArgType, 5, Length(ArgType) - 5);
        if (Length(ArgType) > 0) and (ArgType[Length(ArgType)] = '>') then
          ArgType := Copy(ArgType, 1, Length(ArgType) - 1);
      end;

      Mangled := FindTraitMethod(ArgType, Call.Callee);
      if Mangled <> '' then
      begin
        Call.Callee := Mangled;
        Sym := FSymbols.Resolve(Call.Callee);
      end;
    end;

    if not Assigned(Sym) then
      Error('E0425', Format('Funcao ou tipo nao encontrado: "%s"', [Call.Callee]), Call.Line, Call.Col);
  end;

  // Construtor de Record: DataBuffer(id: 101, size: 2048)
  if (Sym.Kind = skType) and (Sym.Node is TASTRecordDecl) then
  begin
    RecDecl := TASTRecordDecl(Sym.Node);
    if Call.Args.Count <> RecDecl.Fields.Count then
      Error('E0061', Format('Construtor do record "%s" espera %d campos, mas recebeu %d',
        [RecDecl.Name, RecDecl.Fields.Count, Call.Args.Count]), Call.Line, Call.Col);

    for I := 0 to Call.Args.Count - 1 do
    begin
      Arg := TASTCallArg(Call.Args[I]);
      ArgType := CheckExpr(Arg.Expr);
      ExpectedType := TASTRecordField(RecDecl.Fields[I]).TypeName;
      if not TypesAreCompatible(ExpectedType, ArgType) then
        Error('E0308', Format('Campo "%s" do record "%s" espera "%s", mas recebeu "%s"',
          [TASTRecordField(RecDecl.Fields[I]).Name, RecDecl.Name, ExpectedType, ArgType]), Arg.Line, Arg.Col);
    end;
    Exit(RecDecl.Name);
  end;

  // Chamada de Funcao Normal ou Generica
  if Sym.Kind = skFunction then
  begin
    FuncNode := TASTFunction(Sym.Node);

    // Se for funcao generica com Trait Bound, monomorfiza para o tipo concreto
    if Assigned(FuncNode) and (FuncNode.GenericParam <> '') then
    begin
      if Call.Args.Count = 0 then
        Error('E0061', Format('Funcao generica "%s" requer pelo menos 1 argumento para deducao de tipo', [FuncNode.Name]), Call.Line, Call.Col);

      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if Pos('Box<', ArgType) = 1 then
      begin
        ArgType := Copy(ArgType, 5, Length(ArgType) - 5);
        if (Length(ArgType) > 0) and (ArgType[Length(ArgType)] = '>') then
          ArgType := Copy(ArgType, 1, Length(ArgType) - 1);
      end;

      if FuncNode.TraitBound <> '' then
      begin
        if not TypeImplementsTrait(ArgType, FuncNode.TraitBound) then
          Error('E0277', Format('O tipo "%s" nao implementa a trait "%s"', [ArgType, FuncNode.TraitBound]), Call.Line, Call.Col);
      end;

      MonomorphedName := FuncNode.Name + '_' + ArgType;
      SymMono := FSymbols.Resolve(MonomorphedName);
      if not Assigned(SymMono) then
      begin
        MonoFunc := MonomorphizeFunction(FuncNode, ArgType);
        FModule.Functions.Add(MonoFunc);
        FSymbols.Define(TSymbol.Create(MonoFunc.Name, skFunction, MonoFunc.ReturnType, MonoFunc.Line, MonoFunc.Col, False, owNone, MonoFunc));
        CheckFunction(MonoFunc);
        SymMono := FSymbols.Resolve(MonomorphedName);
      end;

      Call.Callee := MonomorphedName;
      Sym := SymMono;
      FuncNode := TASTFunction(Sym.Node);
    end;

    // PrintLn embutido com parametros variaveis
    if (Call.Callee = 'PrintLn') or (Call.Callee = 'Print') then
    begin
      for I := 0 to Call.Args.Count - 1 do
        CheckExpr(TASTCallArg(Call.Args[I]).Expr);
      Exit('Void');
    end;

    if Call.Callee = 'Length' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Funcao "Length" espera 1 argumento (String)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('Funcao "Length" espera String, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('UInt32');
    end;

    if Call.Callee = 'CharAt' then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Funcao "CharAt" espera 2 argumentos (String, UInt32)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('Primeiro argumento de "CharAt" deve ser String, recebido: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if not IsIntegerType(ArgType) and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('Segundo argumento de "CharAt" deve ser inteiro, recebido: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('String');
    end;

    if Call.Callee = 'Substring' then
    begin
      if Call.Args.Count <> 3 then
        Error('E0061', 'Funcao "Substring" espera 3 argumentos (String, UInt32, UInt32)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('Primeiro argumento de "Substring" deve ser String, recebido: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if not IsIntegerType(ArgType) and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('Segundo argumento (start) de "Substring" deve ser inteiro, recebido: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[2]).Expr);
      if not IsIntegerType(ArgType) and (ArgType <> 'IntLiteral') then
        Error('E0308', Format('Terceiro argumento (len) de "Substring" deve ser inteiro, recebido: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('String');
    end;

    if Call.Callee = 'FileExists' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Funcao "FileExists" espera 1 argumento (String)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('Funcao "FileExists" espera String, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Bool');
    end;

    if Call.Callee = 'ReadFile' then
    begin
      if Call.Args.Count <> 1 then
        Error('E0061', 'Funcao "ReadFile" espera 1 argumento (String)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('Funcao "ReadFile" espera String, recebeu: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('String');
    end;

    if Call.Callee = 'WriteFile' then
    begin
      if Call.Args.Count <> 2 then
        Error('E0061', 'Funcao "WriteFile" espera 2 argumentos (String, String)', Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[0]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('Primeiro argumento de "WriteFile" deve ser String, recebido: "%s"', [ArgType]), Call.Line, Call.Col);
      ArgType := CheckExpr(TASTCallArg(Call.Args[1]).Expr);
      if ArgType <> 'String' then
        Error('E0308', Format('Segundo argumento de "WriteFile" deve ser String, recebido: "%s"', [ArgType]), Call.Line, Call.Col);
      Exit('Bool');
    end;

    if Assigned(Sym.Node) and (Sym.Node is TASTFunction) then
    begin
      FuncNode := TASTFunction(Sym.Node);
      if Call.Args.Count <> FuncNode.Params.Count then
        Error('E0061', Format('Funcao "%s" espera %d argumentos, mas recebeu %d',
          [FuncNode.Name, FuncNode.Params.Count, Call.Args.Count]), Call.Line, Call.Col);

      for I := 0 to Call.Args.Count - 1 do
      begin
        Arg := TASTCallArg(Call.Args[I]);
        ArgType := CheckExpr(Arg.Expr);
        ExpectedType := TASTParam(FuncNode.Params[I]).TypeName;
        if not TypesAreCompatible(ExpectedType, ArgType) then
          Error('E0308', Format('Argumento %d da funcao "%s" espera "%s", mas recebeu "%s"',
            [I + 1, FuncNode.Name, ExpectedType, ArgType]), Arg.Line, Arg.Col);
      end;
    end;
    Exit(Sym.TypeName);
  end;

  Error('E0618', Format('"%s" nao e uma funcao nem um construtor', [Call.Callee]), Call.Line, Call.Col);
  Result := 'Unknown';
end;

function TAetherTypeChecker.CheckExpr(Expr: TASTExpr): string;
begin
  if Expr is TASTLiteralExpr then
    Result := CheckLiteral(TASTLiteralExpr(Expr))
  else if Expr is TASTIdentifierExpr then
    Result := CheckIdentifier(TASTIdentifierExpr(Expr))
  else if Expr is TASTMemberAccessExpr then
    Result := CheckMemberAccess(TASTMemberAccessExpr(Expr))
  else if Expr is TASTBinaryExpr then
    Result := CheckBinary(TASTBinaryExpr(Expr))
  else if Expr is TASTUnaryExpr then
    Result := CheckUnary(TASTUnaryExpr(Expr))
  else if Expr is TASTCallExpr then
    Result := CheckCall(TASTCallExpr(Expr))
  else
    Result := 'Unknown';
end;

procedure TAetherTypeChecker.CheckAssign(Assign: TASTAssignStmt);
var
  TargetType, ValueType: string;
  Sym: TSymbol;
begin
  TargetType := CheckExpr(Assign.Target);
  ValueType := CheckExpr(Assign.Expr);

  if not TypesAreCompatible(TargetType, ValueType) then
    Error('E0308', Format('Nao e possivel atribuir "%s" a variavel do tipo "%s"', [ValueType, TargetType]), Assign.Line, Assign.Col);

  if Assign.Target is TASTIdentifierExpr then
  begin
    Sym := FSymbols.Resolve(TASTIdentifierExpr(Assign.Target).Name);
    if Assigned(Sym) and not Sym.IsMutable then
      Error('E0384', Format('Nao e possivel modificar variavel imutavel (declarada com "let"): "%s"', [Sym.Name]), Assign.Line, Assign.Col);
  end;
end;

procedure TAetherTypeChecker.CheckIf(IfStmt: TASTIfStmt);
var
  CondType: string;
  I: Integer;
begin
  CondType := CheckExpr(IfStmt.Condition);
  if CondType <> 'Bool' then
    Error('E0308', Format('Condicao do "if" deve ser Bool, encontrado: "%s"', [CondType]), IfStmt.Line, IfStmt.Col);

  for I := 0 to IfStmt.ThenBranch.Count - 1 do
    CheckStmt(TASTStmt(IfStmt.ThenBranch[I]));

  for I := 0 to IfStmt.ElseBranch.Count - 1 do
    CheckStmt(TASTStmt(IfStmt.ElseBranch[I]));
end;

procedure TAetherTypeChecker.CheckWhile(WhileStmt: TASTWhileStmt);
var
  CondType: string;
  I: Integer;
begin
  CondType := CheckExpr(WhileStmt.Condition);
  if CondType <> 'Bool' then
    Error('E0308', Format('Condicao do "while" deve ser Bool, encontrado: "%s"', [CondType]), WhileStmt.Line, WhileStmt.Col);

  for I := 0 to WhileStmt.Body.Count - 1 do
    CheckStmt(TASTStmt(WhileStmt.Body[I]));
end;

procedure TAetherTypeChecker.CheckReturn(Ret: TASTReturnStmt);
var
  RetType: string;
begin
  if not Assigned(FCurrentFunction) then
    Error('E0572', 'Instrucao "return" fora do corpo de uma funcao', Ret.Line, Ret.Col);

  if Assigned(Ret.Expr) then
    RetType := CheckExpr(Ret.Expr)
  else
    RetType := 'Void';

  if not TypesAreCompatible(FCurrentFunction.ReturnType, RetType) then
    Error('E0308', Format('Funcao "%s" espera retorno "%s", mas instrucao retornou "%s"',
      [FCurrentFunction.Name, FCurrentFunction.ReturnType, RetType]), Ret.Line, Ret.Col);
end;

procedure TAetherTypeChecker.CheckMatch(MatchStmt: TASTMatchStmt);
var
  MatchedType: string;
  Sym: TSymbol;
  EnumDecl: TASTEnumDecl;
  I, J: Integer;
  CaseNode: TASTMatchCase;
  PatternVal: string;
  HasWildcard: Boolean;
  CoveredVariants: TStringList;
  VariantName: string;
  MissingVariant: string;
  HasOk, HasErr: Boolean;
begin
  MatchedType := CheckExpr(MatchStmt.Expr);
  HasWildcard := False;

  // Verificacao Exaustiva para Enum
  Sym := FSymbols.Resolve(MatchedType);
  if Assigned(Sym) and (Sym.Node is TASTEnumDecl) then
  begin
    EnumDecl := TASTEnumDecl(Sym.Node);
    CoveredVariants := TStringList.Create;
    try
      for I := 0 to MatchStmt.Cases.Count - 1 do
      begin
        CaseNode := TASTMatchCase(MatchStmt.Cases[I]);
        PatternVal := CaseNode.Pattern.Value;

        if PatternVal = '_' then
          HasWildcard := True
        else
        begin
          // Se for Enum.Variante
          if Pos('.', PatternVal) > 0 then
            PatternVal := Copy(PatternVal, Pos('.', PatternVal) + 1, Length(PatternVal));
          CoveredVariants.Add(UpperCase(PatternVal));
        end;

        // Verifica o corpo do caso
        FSymbols.EnterScope;
        try
          if CaseNode.Pattern.SubPattern <> '' then
          begin
            // Variavel introduzida pelo case: Ok(let v)
            FSymbols.Define(TSymbol.Create(CaseNode.Pattern.SubPattern, skVariable, 'Any', CaseNode.Line, CaseNode.Col, False));
          end;
          for J := 0 to CaseNode.Body.Count - 1 do
            CheckStmt(TASTStmt(CaseNode.Body[J]));
        finally
          FSymbols.LeaveScope;
        end;
      end;

      // Se nao tem wildcard '_', checa se todas as variantes foram cobertas
      if not HasWildcard then
      begin
        for I := 0 to EnumDecl.Variants.Count - 1 do
        begin
          VariantName := TASTEnumVariant(EnumDecl.Variants[I]).Name;
          if CoveredVariants.IndexOf(UpperCase(VariantName)) = -1 then
          begin
            MissingVariant := VariantName;
            Error('E0004', Format('Match nao-exaustivo no enum "%s". Falta cobrir a variante "%s" (ou adicionar caso "_:")',
              [EnumDecl.Name, MissingVariant]), MatchStmt.Line, MatchStmt.Col);
          end;
        end;
      end;
    finally
      CoveredVariants.Free;
    end;
    Exit;
  end;

  // Verificacao Exaustiva para Result<T, E>
  if Pos('Result', MatchedType) = 1 then
  begin
    HasOk := False;
    HasErr := False;
    for I := 0 to MatchStmt.Cases.Count - 1 do
    begin
      CaseNode := TASTMatchCase(MatchStmt.Cases[I]);
      PatternVal := CaseNode.Pattern.Value;
      if (PatternVal = 'Ok') or (Pos('Ok', PatternVal) = 1) then HasOk := True;
      if (PatternVal = 'Err') or (Pos('Err', PatternVal) = 1) then HasErr := True;
      if PatternVal = '_' then HasWildcard := True;

      FSymbols.EnterScope;
      try
        if CaseNode.Pattern.SubPattern <> '' then
        begin
          FSymbols.Define(TSymbol.Create(CaseNode.Pattern.SubPattern, skVariable, 'Any', CaseNode.Line, CaseNode.Col, False));
        end;
        for J := 0 to CaseNode.Body.Count - 1 do
          CheckStmt(TASTStmt(CaseNode.Body[J]));
      finally
        FSymbols.LeaveScope;
      end;
    end;

    if not HasWildcard and (not HasOk or not HasErr) then
      Error('E0004', 'Match nao-exaustivo em Result. E obrigatorio cobrir tanto "Ok" quanto "Err" (ou adicionar "_:")',
        MatchStmt.Line, MatchStmt.Col);
    Exit;
  end;

  // Para outros tipos simples, apenas verifica os corpos
  for I := 0 to MatchStmt.Cases.Count - 1 do
  begin
    CaseNode := TASTMatchCase(MatchStmt.Cases[I]);
    FSymbols.EnterScope;
    try
      for J := 0 to CaseNode.Body.Count - 1 do
        CheckStmt(TASTStmt(CaseNode.Body[J]));
    finally
      FSymbols.LeaveScope;
    end;
  end;
end;

procedure TAetherTypeChecker.CheckStmt(Stmt: TASTStmt);
begin
  if Stmt is TASTAssignStmt then
    CheckAssign(TASTAssignStmt(Stmt))
  else if Stmt is TASTCallStmt then
    CheckExpr(TASTCallStmt(Stmt).CallExpr)
  else if Stmt is TASTIfStmt then
    CheckIf(TASTIfStmt(Stmt))
  else if Stmt is TASTWhileStmt then
    CheckWhile(TASTWhileStmt(Stmt))
  else if Stmt is TASTReturnStmt then
    CheckReturn(TASTReturnStmt(Stmt))
  else if Stmt is TASTMatchStmt then
    CheckMatch(TASTMatchStmt(Stmt));
end;

procedure TAetherTypeChecker.RegisterTypes(AModule: TASTModule);
var
  I: Integer;
  Node: TASTNode;
  Rec: TASTRecordDecl;
  Enm: TASTEnumDecl;
begin
  for I := 0 to AModule.Types.Count - 1 do
  begin
    Node := AModule.Types[I];
    if Node is TASTRecordDecl then
    begin
      Rec := TASTRecordDecl(Node);
      FSymbols.Define(TSymbol.Create(Rec.Name, skType, Rec.Name, Rec.Line, Rec.Col, True, owNone, Rec));
    end
    else if Node is TASTEnumDecl then
    begin
      Enm := TASTEnumDecl(Node);
      FSymbols.Define(TSymbol.Create(Enm.Name, skType, Enm.Name, Enm.Line, Enm.Col, True, owNone, Enm));
    end;
  end;
end;

procedure TAetherTypeChecker.RegisterFunctions(AModule: TASTModule);
var
  I: Integer;
  Func: TASTFunction;
begin
  for I := 0 to AModule.Functions.Count - 1 do
  begin
    Func := TASTFunction(AModule.Functions[I]);
    FSymbols.Define(TSymbol.Create(Func.Name, skFunction, Func.ReturnType, Func.Line, Func.Col, False, owNone, Func));
  end;
end;

procedure TAetherTypeChecker.CheckFunction(Func: TASTFunction);
var
  I: Integer;
  Param: TASTParam;
  VarDecl: TASTVarDecl;
  VarInitType: string;
begin
  FCurrentFunction := Func;
  FSymbols.EnterScope;
  try
    // Registra parametros no escopo da funcao
    for I := 0 to Func.Params.Count - 1 do
    begin
      Param := TASTParam(Func.Params[I]);
      if not FSymbols.ResolveType(Param.TypeName) then
        Error('E0412', Format('Tipo "%s" do parametro "%s" nao encontrado', [Param.TypeName, Param.Name]), Param.Line, Param.Col);
      FSymbols.Define(TSymbol.Create(Param.Name, skVariable, Param.TypeName, Param.Line, Param.Col, Param.Ownership = owMutBorrow, Param.Ownership));
    end;

    // Contratos require
    for I := 0 to Func.Requires.Count - 1 do
    begin
      if CheckExpr(TASTExpr(Func.Requires[I])) <> 'Bool' then
        Error('E0308', 'Expressao em "require" deve ser do tipo Bool', Func.Line, Func.Col);
    end;

    // Contratos ensure
    for I := 0 to Func.Ensures.Count - 1 do
    begin
      if CheckExpr(TASTExpr(Func.Ensures[I])) <> 'Bool' then
        Error('E0308', 'Expressao em "ensure" deve ser do tipo Bool', Func.Line, Func.Col);
    end;

    // Se for extern, nao possui corpo nem variaveis locais
    if Func.IsExtern then
      Exit;

    // Registra variaveis locais
    for I := 0 to Func.LocalVars.Count - 1 do
    begin
      VarDecl := TASTVarDecl(Func.LocalVars[I]);
      if not FSymbols.ResolveType(VarDecl.TypeName) then
        Error('E0412', Format('Tipo "%s" da variavel "%s" nao encontrado', [VarDecl.TypeName, VarDecl.Name]), VarDecl.Line, VarDecl.Col);

      if Assigned(VarDecl.InitialExpr) then
      begin
        VarInitType := CheckExpr(VarDecl.InitialExpr);
        if not TypesAreCompatible(VarDecl.TypeName, VarInitType) then
          Error('E0308', Format('Inicializacao de "%s" espera "%s", mas recebeu "%s"',
            [VarDecl.Name, VarDecl.TypeName, VarInitType]), VarDecl.Line, VarDecl.Col);
      end;

      FSymbols.Define(TSymbol.Create(VarDecl.Name, skVariable, VarDecl.TypeName, VarDecl.Line, VarDecl.Col, VarDecl.IsMutable));
    end;

    // Verifica corpo da funcao
    for I := 0 to Func.Body.Count - 1 do
      CheckStmt(TASTStmt(Func.Body[I]));
  finally
    FSymbols.LeaveScope;
    FCurrentFunction := nil;
  end;
end;

procedure TAetherTypeChecker.CheckProgramBlock(Prog: TASTProgramBlock);
var
  I: Integer;
  VarDecl: TASTVarDecl;
  VarInitType: string;
begin
  FSymbols.EnterScope;
  try
    for I := 0 to Prog.LocalVars.Count - 1 do
    begin
      VarDecl := TASTVarDecl(Prog.LocalVars[I]);
      if not FSymbols.ResolveType(VarDecl.TypeName) then
        Error('E0412', Format('Tipo "%s" da variavel "%s" nao encontrado', [VarDecl.TypeName, VarDecl.Name]), VarDecl.Line, VarDecl.Col);

      if Assigned(VarDecl.InitialExpr) then
      begin
        VarInitType := CheckExpr(VarDecl.InitialExpr);
        if not TypesAreCompatible(VarDecl.TypeName, VarInitType) then
          Error('E0308', Format('Inicializacao de "%s" espera "%s", mas recebeu "%s"',
            [VarDecl.Name, VarDecl.TypeName, VarInitType]), VarDecl.Line, VarDecl.Col);
      end;

      FSymbols.Define(TSymbol.Create(VarDecl.Name, skVariable, VarDecl.TypeName, VarDecl.Line, VarDecl.Col, VarDecl.IsMutable));
    end;

    for I := 0 to Prog.Body.Count - 1 do
      CheckStmt(TASTStmt(Prog.Body[I]));
  finally
    FSymbols.LeaveScope;
  end;
end;

procedure TAetherTypeChecker.RegisterTraits(AModule: TASTModule);
var
  I: Integer;
  Trait: TASTTraitDecl;
begin
  for I := 0 to AModule.Traits.Count - 1 do
  begin
    Trait := TASTTraitDecl(AModule.Traits[I]);
    FSymbols.Define(TSymbol.Create(Trait.Name, skTrait, Trait.Name, Trait.Line, Trait.Col, False, owNone, Trait));
  end;
end;

procedure TAetherTypeChecker.RegisterImpls(AModule: TASTModule);
var
  I, TM, IM, P: Integer;
  Impl: TASTImplDecl;
  SymTrait, SymType: TSymbol;
  TraitDecl: TASTTraitDecl;
  TraitMethod, ImplMethod: TASTFunction;
  Found: Boolean;
  ExpectedParamType: string;
  MangledName: string;
  Info: PTraitImplInfo;
begin
  for I := 0 to AModule.Impls.Count - 1 do
  begin
    Impl := TASTImplDecl(AModule.Impls[I]);

    SymTrait := FSymbols.Resolve(Impl.TraitName);
    if (not Assigned(SymTrait)) or (SymTrait.Kind <> skTrait) then
      Error('E0425', Format('Trait "%s" nao encontrada', [Impl.TraitName]), Impl.Line, Impl.Col);

    SymType := FSymbols.Resolve(Impl.TargetTypeName);
    if (not Assigned(SymType)) or (SymType.Kind <> skType) then
      Error('E0425', Format('Tipo "%s" nao encontrado', [Impl.TargetTypeName]), Impl.Line, Impl.Col);

    TraitDecl := TASTTraitDecl(SymTrait.Node);

    // Validação de completude: todos os métodos da trait foram implementados?
    for TM := 0 to TraitDecl.Methods.Count - 1 do
    begin
      TraitMethod := TASTFunction(TraitDecl.Methods[TM]);
      Found := False;
      for IM := 0 to Impl.Methods.Count - 1 do
      begin
        if SameText(TASTFunction(Impl.Methods[IM]).Name, TraitMethod.Name) then
        begin
          Found := True;
          Break;
        end;
      end;
      if not Found then
        Error('E0046', Format('O tipo "%s" nao implementou o metodo obrigatorio "%s" da trait "%s"',
          [Impl.TargetTypeName, TraitMethod.Name, Impl.TraitName]), Impl.Line, Impl.Col);
    end;

    // Validação das assinaturas e registro dos métodos
    for IM := 0 to Impl.Methods.Count - 1 do
    begin
      ImplMethod := TASTFunction(Impl.Methods[IM]);
      TraitMethod := nil;
      for TM := 0 to TraitDecl.Methods.Count - 1 do
      begin
        if SameText(TASTFunction(TraitDecl.Methods[TM]).Name, ImplMethod.Name) then
        begin
          TraitMethod := TASTFunction(TraitDecl.Methods[TM]);
          Break;
        end;
      end;

      if Assigned(TraitMethod) then
      begin
        // Verifica parâmetros
        if ImplMethod.Params.Count <> TraitMethod.Params.Count then
          Error('E0053', Format('A assinatura do metodo "%s" em "%s" diverge da definicao da trait "%s" (quantidade de parametros incompativel: esperado %d, recebido %d)',
            [ImplMethod.Name, Impl.TargetTypeName, Impl.TraitName, TraitMethod.Params.Count, ImplMethod.Params.Count]), ImplMethod.Line, ImplMethod.Col);

        // Verifica tipo de retorno
        if not SameText(ImplMethod.ReturnType, TraitMethod.ReturnType) then
          Error('E0053', Format('A assinatura do metodo "%s" em "%s" diverge da definicao da trait "%s" (tipo de retorno incompativel: esperado "%s", recebido "%s")',
            [ImplMethod.Name, Impl.TargetTypeName, Impl.TraitName, TraitMethod.ReturnType, ImplMethod.ReturnType]), ImplMethod.Line, ImplMethod.Col);

        for P := 0 to TraitMethod.Params.Count - 1 do
        begin
          ExpectedParamType := TASTParam(TraitMethod.Params[P]).TypeName;
          if SameText(ExpectedParamType, 'Self') then
            ExpectedParamType := Impl.TargetTypeName;

          if not SameText(ExpectedParamType, TASTParam(ImplMethod.Params[P]).TypeName) then
            Error('E0053', Format('A assinatura do metodo "%s" em "%s" diverge da definicao da trait "%s" no parametro "%s" (esperado "%s", recebido "%s")',
              [ImplMethod.Name, Impl.TargetTypeName, Impl.TraitName, TASTParam(ImplMethod.Params[P]).Name, ExpectedParamType, TASTParam(ImplMethod.Params[P]).TypeName]), ImplMethod.Line, ImplMethod.Col);
        end;
      end;

      // Mangling canônico do método para despacho estático
      MangledName := Impl.TargetTypeName + '_' + ImplMethod.Name;
      ImplMethod.OriginalName := ImplMethod.Name;
      ImplMethod.Name := MangledName;

      // Registra a implementação da trait para lookup
      New(Info);
      Info^.TargetType := Impl.TargetTypeName;
      Info^.TraitName := Impl.TraitName;
      Info^.OriginalMethod := ImplMethod.OriginalName;
      Info^.MangledMethod := MangledName;
      FTraitImpls.Add(Info);

      // Adiciona o método em AModule.Functions para checagem e emissão (sera registrado por RegisterFunctions)
      AModule.Functions.Add(ImplMethod);
    end;

    // Desvincula os nós de Impl.Methods para não causar double-free ao destruir o módulo
    while Impl.Methods.Count > 0 do
      Impl.Methods.Extract(Impl.Methods[0]);
  end;
end;

function TAetherTypeChecker.TypeImplementsTrait(const ATypeName, ATraitName: string): Boolean;
var
  I: Integer;
  Info: PTraitImplInfo;
begin
  for I := 0 to FTraitImpls.Count - 1 do
  begin
    Info := PTraitImplInfo(FTraitImpls[I]);
    if SameText(Info^.TargetType, ATypeName) and SameText(Info^.TraitName, ATraitName) then
      Exit(True);
  end;
  Result := False;
end;

function TAetherTypeChecker.FindTraitMethod(const ATypeName, AMethodName: string): string;
var
  I: Integer;
  Info: PTraitImplInfo;
begin
  for I := 0 to FTraitImpls.Count - 1 do
  begin
    Info := PTraitImplInfo(FTraitImpls[I]);
    if SameText(Info^.TargetType, ATypeName) and SameText(Info^.OriginalMethod, AMethodName) then
      Exit(Info^.MangledMethod);
  end;
  Result := '';
end;

function TAetherTypeChecker.MonomorphizeFunction(OriginalFunc: TASTFunction; const ConcreteType: string): TASTFunction;
var
  I: Integer;
  Param: TASTParam;
  PType: string;
  VarDecl: TASTVarDecl;
  VType: string;
begin
  Result := TASTFunction.Create(OriginalFunc.Line, OriginalFunc.Col, OriginalFunc.Name + '_' + ConcreteType, OriginalFunc.ReturnType);
  if SameText(Result.ReturnType, OriginalFunc.GenericParam) then
    Result.ReturnType := ConcreteType;

  for I := 0 to OriginalFunc.Params.Count - 1 do
  begin
    Param := TASTParam(OriginalFunc.Params[I]);
    PType := Param.TypeName;
    if SameText(PType, OriginalFunc.GenericParam) then
      PType := ConcreteType;
    Result.Params.Add(TASTParam.Create(Param.Line, Param.Col, Param.Name, PType, Param.Ownership));
  end;

  for I := 0 to OriginalFunc.LocalVars.Count - 1 do
  begin
    VarDecl := TASTVarDecl(OriginalFunc.LocalVars[I]);
    VType := VarDecl.TypeName;
    if SameText(VType, OriginalFunc.GenericParam) then
      VType := ConcreteType;
    Result.LocalVars.Add(TASTVarDecl.Create(VarDecl.Line, VarDecl.Col, VarDecl.Name, VType, TASTExpr(CloneASTNode(VarDecl.InitialExpr)), VarDecl.IsMutable));
  end;

  for I := 0 to OriginalFunc.Body.Count - 1 do
    Result.Body.Add(CloneASTNode(TASTStmt(OriginalFunc.Body[I])));
end;

procedure TAetherTypeChecker.CheckModule(AModule: TASTModule);
var
  I: Integer;
  Func: TASTFunction;
begin
  FModule := AModule;
  RegisterTypes(AModule);
  RegisterTraits(AModule);
  RegisterImpls(AModule);
  RegisterFunctions(AModule);

  I := 0;
  while I < AModule.Functions.Count do
  begin
    Func := TASTFunction(AModule.Functions[I]);
    if Func.GenericParam = '' then
      CheckFunction(Func);
    Inc(I);
  end;

  if Assigned(AModule.ProgramBlock) then
    CheckProgramBlock(AModule.ProgramBlock);
end;

end.
