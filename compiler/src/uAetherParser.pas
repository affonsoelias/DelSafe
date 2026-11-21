unit uAetherParser;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  uAetherTokens,
  uAetherLexer,
  uAetherAST;

type
  EAetherParserError = class(Exception)
  public
    Line: Integer;
    Col: Integer;
    constructor Create(const Msg: string; ALine, ACol: Integer);
  end;

  TAetherParser = class
  private
    FLexer: TAetherLexer;
    FCurTok: TToken;
    FPeekTok: TToken;

    procedure Advance;
    function Check(Kind: TTokenKind): Boolean;
    function Match(Kind: TTokenKind): Boolean;
    function Expect(Kind: TTokenKind; const Msg: string = ''): TToken;

    function ParseTypeRef: string;
    procedure ParseImport(AModule: TASTModule);
    procedure ParseTypeSection(AModule: TASTModule);
    function ParseRecordDecl(const AName: string; ALine, ACol: Integer): TASTRecordDecl;
    function ParseEnumDecl(const AName: string; ALine, ACol: Integer): TASTEnumDecl;
    function ParseFunction: TASTFunction;
    function ParseProgramBlock: TASTProgramBlock;
    procedure ParseVarSection(ALocalVars: TASTNodeList);

    function ParseStatement: TASTStmt;
    function ParseIfStmt: TASTIfStmt;
    function ParseWhileStmt: TASTWhileStmt;
    function ParseMatchStmt: TASTMatchStmt;
    function ParseReturnStmt: TASTReturnStmt;
    function ParseAssignOrCallStmt: TASTStmt;

    function ParseExpr: TASTExpr;
    function ParseLogicalExpr: TASTExpr;
    function ParseRelationalExpr: TASTExpr;
    function ParseAdditiveExpr: TASTExpr;
    function ParseMultiplicativeExpr: TASTExpr;
    function ParseUnaryExpr: TASTExpr;
    function ParsePrimaryExpr: TASTExpr;
  public
    constructor Create(ALexer: TAetherLexer);
    function ParseModule: TASTModule;
  end;

implementation

constructor EAetherParserError.Create(const Msg: string; ALine, ACol: Integer);
begin
  inherited Create(Format('[Erro Sintatico em %d:%d]: %s', [ALine, ACol, Msg]));
  Line := ALine;
  Col := ACol;
end;

constructor TAetherParser.Create(ALexer: TAetherLexer);
begin
  inherited Create;
  FLexer := ALexer;
  Advance;
  Advance;
end;

procedure TAetherParser.Advance;
begin
  FCurTok := FPeekTok;
  FPeekTok := FLexer.NextToken;
end;

function TAetherParser.Check(Kind: TTokenKind): Boolean;
begin
  Result := FCurTok.Kind = Kind;
end;

function TAetherParser.Match(Kind: TTokenKind): Boolean;
begin
  if Check(Kind) then
  begin
    Advance;
    Result := True;
  end
  else
    Result := False;
end;

function TAetherParser.Expect(Kind: TTokenKind; const Msg: string): TToken;
begin
  if Check(Kind) then
  begin
    Result := FCurTok;
    Advance;
  end
  else
  begin
    if Msg <> '' then
      raise EAetherParserError.Create(Msg, FCurTok.Line, FCurTok.Col)
    else
      raise EAetherParserError.Create(
        Format('Esperado token "%s", mas encontrado "%s" ("%s")',
          [TokenKindToString(Kind), TokenKindToString(FCurTok.Kind), FCurTok.Value]),
        FCurTok.Line, FCurTok.Col);
  end;
end;

function TAetherParser.ParseTypeRef: string;
var
  BaseType: string;
begin
  BaseType := Expect(tokIdentifier, 'Esperado identificador de tipo').Value;
  if Match(tokLess) then
  begin
    BaseType := BaseType + '<' + ParseTypeRef();
    while Match(tokComma) do
      BaseType := BaseType + ', ' + ParseTypeRef();
    Expect(tokGreater, 'Esperado ">" no fechamento do tipo generico');
    BaseType := BaseType + '>';
  end;
  Result := BaseType;
end;

procedure TAetherParser.ParseImport(AModule: TASTModule);
var
  ImportName: string;
begin
  Expect(tokImport);
  ImportName := Expect(tokIdentifier, 'Esperado nome do modulo importado').Value;
  if Match(tokAs) then
    ImportName := ImportName + ' as ' + Expect(tokIdentifier).Value;
  Expect(tokSemicolon);
  AModule.Imports.Add(ImportName);
end;

function TAetherParser.ParseRecordDecl(const AName: string; ALine, ACol: Integer): TASTRecordDecl;
var
  FieldName, FieldType: string;
  FLine, FCol: Integer;
begin
  Expect(tokRecord);
  Result := TASTRecordDecl.Create(ALine, ACol, AName);
  try
    while not Check(tokEnd) and not Check(tokEOF) do
    begin
      FLine := FCurTok.Line;
      FCol := FCurTok.Col;
      FieldName := Expect(tokIdentifier, 'Esperado nome do campo do record').Value;
      Expect(tokColon, 'Esperado ":" apos nome do campo');
      FieldType := ParseTypeRef;
      Expect(tokSemicolon, 'Esperado ";" apos definicao do campo');
      Result.Fields.Add(TASTRecordField.Create(FLine, FCol, FieldName, FieldType));
    end;
    Expect(tokEnd, 'Esperado "end" no fechamento do record');
  except
    Result.Free;
    raise;
  end;
end;

function TAetherParser.ParseEnumDecl(const AName: string; ALine, ACol: Integer): TASTEnumDecl;
var
  VariantNode: TASTEnumVariant;
  VName, FName, FType: string;
  VLine, VCol: Integer;
begin
  Expect(tokEnum);
  Result := TASTEnumDecl.Create(ALine, ACol, AName);
  try
    while not Check(tokEnd) and not Check(tokEOF) do
    begin
      VLine := FCurTok.Line;
      VCol := FCurTok.Col;
      VName := Expect(tokIdentifier, 'Esperado nome da variante do enum').Value;
      VariantNode := TASTEnumVariant.Create(VLine, VCol, VName);
      Result.Variants.Add(VariantNode);

      // Payload opcional: Variante(campo: Tipo, ...)
      if Match(tokLParen) then
      begin
        while not Check(tokRParen) and not Check(tokEOF) do
        begin
          FName := Expect(tokIdentifier, 'Esperado nome do campo do enum').Value;
          Expect(tokColon);
          FType := ParseTypeRef;
          VariantNode.Fields.Add(TASTRecordField.Create(VLine, VCol, FName, FType));
          if not Match(tokComma) then
            Break;
        end;
        Expect(tokRParen, 'Esperado ")" apos campos do enum');
      end;

      if not Match(tokComma) then
        Break;
    end;
    Expect(tokEnd, 'Esperado "end" no fechamento do enum');
  except
    Result.Free;
    raise;
  end;
end;

procedure TAetherParser.ParseTypeSection(AModule: TASTModule);
var
  TypeName: string;
  TLine, TCol: Integer;
begin
  Expect(tokType);
  while Check(tokIdentifier) do
  begin
    TLine := FCurTok.Line;
    TCol := FCurTok.Col;
    TypeName := Expect(tokIdentifier).Value;
    Expect(tokEqual, 'Esperado "=" na declaracao de tipo');

    if Check(tokRecord) then
      AModule.Types.Add(ParseRecordDecl(TypeName, TLine, TCol))
    else if Check(tokEnum) then
      AModule.Types.Add(ParseEnumDecl(TypeName, TLine, TCol))
    else
      raise EAetherParserError.Create('Esperado "record" ou "enum" na declaracao de tipo', TLine, TCol);

    Expect(tokSemicolon, 'Esperado ";" apos declaracao de tipo');
  end;
end;

procedure TAetherParser.ParseVarSection(ALocalVars: TASTNodeList);
var
  VarName, VarType: string;
  InitExpr: TASTExpr;
  VLine, VCol: Integer;
  IsMut: Boolean;
begin
  IsMut := Check(tokVar);
  Advance; // consome 'var' ou 'let'

  while Check(tokIdentifier) do
  begin
    VLine := FCurTok.Line;
    VCol := FCurTok.Col;
    VarName := Expect(tokIdentifier).Value;
    Expect(tokColon, 'Esperado ":" apos nome da variavel');
    VarType := ParseTypeRef;

    InitExpr := nil;
    if Match(tokAssign) then
      InitExpr := ParseExpr;

    Expect(tokSemicolon, 'Esperado ";" apos declaracao de variavel');
    ALocalVars.Add(TASTVarDecl.Create(VLine, VCol, VarName, VarType, InitExpr, IsMut));
  end;
end;

function TAetherParser.ParseFunction: TASTFunction;
var
  FuncName, ReturnType, ParamName, ParamType: string;
  FLine, FCol: Integer;
  Ownership: TOwnershipKind;
begin
  FLine := FCurTok.Line;
  FCol := FCurTok.Col;
  Expect(tokFunction);
  FuncName := Expect(tokIdentifier, 'Esperado nome da funcao').Value;

  Result := TASTFunction.Create(FLine, FCol, FuncName, '');
  try
    Expect(tokLParen, 'Esperado "(" apos nome da funcao');
    if not Check(tokRParen) then
    begin
      repeat
        Ownership := owNone;
        if Match(tokTake) then
          Ownership := owTake
        else if Match(tokBorrow) then
          Ownership := owBorrow
        else if Match(tokMut) then
        begin
          Expect(tokBorrow, 'Esperado "borrow" apos "mut"');
          Ownership := owMutBorrow;
        end;

        ParamName := Expect(tokIdentifier, 'Esperado nome do parametro').Value;
        Expect(tokColon, 'Esperado ":" apos nome do parametro');
        ParamType := ParseTypeRef;

        Result.Params.Add(TASTParam.Create(FCurTok.Line, FCurTok.Col, ParamName, ParamType, Ownership));
      until not Match(tokSemicolon);
    end;
    Expect(tokRParen, 'Esperado ")" no fechamento dos parametros');

    Expect(tokColon, 'Esperado ":" apos parametros da funcao');
    ReturnType := ParseTypeRef;
    Result.ReturnType := ReturnType;

    // Bloco de Contratos Opcional
    if Match(tokContract) then
    begin
      if Match(tokRequire) then
      begin
        while not Check(tokEnsure) and not Check(tokVar) and not Check(tokLet) and not Check(tokBegin) and not Check(tokEOF) do
        begin
          Result.Requires.Add(ParseExpr);
          Expect(tokSemicolon, 'Esperado ";" apos expressao de require');
        end;
      end;

      if Match(tokEnsure) then
      begin
        while not Check(tokVar) and not Check(tokLet) and not Check(tokBegin) and not Check(tokEOF) do
        begin
          Result.Ensures.Add(ParseExpr);
          Expect(tokSemicolon, 'Esperado ";" apos expressao de ensure');
        end;
      end;
    end;

    // Variaveis Locais
    if Check(tokVar) or Check(tokLet) then
      ParseVarSection(Result.LocalVars);

    // Corpo begin...end;
    Expect(tokBegin, 'Esperado "begin" para iniciar o corpo da funcao');
    while not Check(tokEnd) and not Check(tokEOF) do
    begin
      Result.Body.Add(ParseStatement);
      Expect(tokSemicolon, 'Esperado ";" apos instrucao');
    end;
    Expect(tokEnd, 'Esperado "end" para fechar a funcao');
    Expect(tokSemicolon, 'Esperado ";" apos "end" da funcao');
  except
    Result.Free;
    raise;
  end;
end;

function TAetherParser.ParseProgramBlock: TASTProgramBlock;
var
  ProgName: string;
  PLine, PCol: Integer;
begin
  PLine := FCurTok.Line;
  PCol := FCurTok.Col;
  Expect(tokProgram);
  ProgName := Expect(tokIdentifier, 'Esperado nome do programa principal').Value;
  Expect(tokSemicolon, 'Esperado ";" apos declaracao de programa');

  Result := TASTProgramBlock.Create(PLine, PCol, ProgName);
  try
    if Check(tokVar) or Check(tokLet) then
      ParseVarSection(Result.LocalVars);

    Expect(tokBegin, 'Esperado "begin" para iniciar o bloco do programa');
    while not Check(tokEnd) and not Check(tokEOF) do
    begin
      Result.Body.Add(ParseStatement);
      Expect(tokSemicolon, 'Esperado ";" apos instrucao');
    end;
    Expect(tokEnd, 'Esperado "end" para finalizar o programa');
    Expect(tokDot, 'Esperado "." apos "end" do programa principal');
  except
    Result.Free;
    raise;
  end;
end;

function TAetherParser.ParseIfStmt: TASTIfStmt;
var
  Cond: TASTExpr;
  ILine, ICol: Integer;
begin
  ILine := FCurTok.Line;
  ICol := FCurTok.Col;
  Expect(tokIf);
  Cond := ParseExpr;
  Expect(tokThen, 'Esperado "then" apos condicao do if');

  Result := TASTIfStmt.Create(ILine, ICol, Cond);
  try
    while not Check(tokElse) and not Check(tokEnd) and not Check(tokEOF) do
    begin
      Result.ThenBranch.Add(ParseStatement);
      Expect(tokSemicolon, 'Esperado ";" apos instrucao no ramo then');
    end;

    if Match(tokElse) then
    begin
      while not Check(tokEnd) and not Check(tokEOF) do
      begin
        Result.ElseBranch.Add(ParseStatement);
        Expect(tokSemicolon, 'Esperado ";" apos instrucao no ramo else');
      end;
    end;

    Expect(tokEnd, 'Esperado "end" no fechamento do if');
  except
    Result.Free;
    raise;
  end;
end;

function TAetherParser.ParseWhileStmt: TASTWhileStmt;
var
  Cond: TASTExpr;
  WLine, WCol: Integer;
begin
  WLine := FCurTok.Line;
  WCol := FCurTok.Col;
  Expect(tokWhile);
  Cond := ParseExpr;
  Expect(tokDo, 'Esperado "do" apos condicao do while');

  Result := TASTWhileStmt.Create(WLine, WCol, Cond);
  try
    while not Check(tokEnd) and not Check(tokEOF) do
    begin
      Result.Body.Add(ParseStatement);
      Expect(tokSemicolon, 'Esperado ";" apos instrucao do while');
    end;
    Expect(tokEnd, 'Esperado "end" no fechamento do while');
  except
    Result.Free;
    raise;
  end;
end;

function TAetherParser.ParseMatchStmt: TASTMatchStmt;
var
  MatchExpr: TASTExpr;
  CaseNode: TASTMatchCase;
  PatternNode: TASTPattern;
  PatVal, SubVal: string;
  IsLet: Boolean;
  MLine, MCol, PLine, PCol: Integer;
begin
  MLine := FCurTok.Line;
  MCol := FCurTok.Col;
  Expect(tokMatch);
  MatchExpr := ParseExpr;
  Expect(tokDo, 'Esperado "do" apos expressao do match');

  Result := TASTMatchStmt.Create(MLine, MCol, MatchExpr);
  try
    while Match(tokCase) do
    begin
      PLine := FCurTok.Line;
      PCol := FCurTok.Col;
      PatVal := Expect(tokIdentifier, 'Esperado identificador do padrao no case').Value;

      // Suporte a MathError.DivisaoPorZero
      if Match(tokDot) then
        PatVal := PatVal + '.' + Expect(tokIdentifier).Value;

      SubVal := '';
      IsLet := False;
      if Match(tokLParen) then
      begin
        if Match(tokLet) then
          IsLet := True;
        if Check(tokIdentifier) then
          SubVal := Expect(tokIdentifier).Value
        else if Match(tokUnderscore) then
          SubVal := '_'
        else if Check(tokIntLiteral) or Check(tokStringLiteral) then
          SubVal := FCurTok.Value;

        if Match(tokDot) then
          SubVal := SubVal + '.' + Expect(tokIdentifier).Value;

        Expect(tokRParen, 'Esperado ")" apos argumento do padrao');
      end;

      PatternNode := TASTPattern.Create(PLine, PCol, PatVal, SubVal, IsLet);
      CaseNode := TASTMatchCase.Create(PLine, PCol, PatternNode);
      Result.Cases.Add(CaseNode);

      Expect(tokColon, 'Esperado ":" apos padrao do case');
      while not Check(tokCase) and not Check(tokEnd) and not Check(tokEOF) do
      begin
        CaseNode.Body.Add(ParseStatement);
        Expect(tokSemicolon, 'Esperado ";" apos instrucao do case');
      end;
    end;
    Expect(tokEnd, 'Esperado "end" no fechamento do match');
  except
    Result.Free;
    raise;
  end;
end;

function TAetherParser.ParseReturnStmt: TASTReturnStmt;
var
  RetExpr: TASTExpr;
  RLine, RCol: Integer;
begin
  RLine := FCurTok.Line;
  RCol := FCurTok.Col;
  Expect(tokReturn);
  RetExpr := nil;
  if not Check(tokSemicolon) and not Check(tokEnd) then
    RetExpr := ParseExpr;
  Result := TASTReturnStmt.Create(RLine, RCol, RetExpr);
end;

function TAetherParser.ParseAssignOrCallStmt: TASTStmt;
var
  Expr: TASTExpr;
  TargetExpr: TASTExpr;
begin
  Expr := ParseExpr;
  if Match(tokAssign) then
  begin
    TargetExpr := Expr;
    Result := TASTAssignStmt.Create(TargetExpr.Line, TargetExpr.Col, TargetExpr, ParseExpr);
  end
  else if Expr is TASTCallExpr then
  begin
    Result := TASTCallStmt.Create(Expr.Line, Expr.Col, TASTCallExpr(Expr));
  end
  else
    raise EAetherParserError.Create('Instrucao invalida (esperada atribuicao ou chamada de funcao)', Expr.Line, Expr.Col);
end;

function TAetherParser.ParseStatement: TASTStmt;
begin
  if Check(tokIf) then
    Result := ParseIfStmt
  else if Check(tokWhile) then
    Result := ParseWhileStmt
  else if Check(tokMatch) then
    Result := ParseMatchStmt
  else if Check(tokReturn) then
    Result := ParseReturnStmt
  else
    Result := ParseAssignOrCallStmt;
end;

function TAetherParser.ParsePrimaryExpr: TASTExpr;
var
  Id: string;
  Line, Col: Integer;
  CallExpr: TASTCallExpr;
  ArgExpr: TASTExpr;
  ArgOwn: TOwnershipKind;
begin
  Line := FCurTok.Line;
  Col := FCurTok.Col;

  // Literais
  if Check(tokIntLiteral) then
  begin
    Result := TASTLiteralExpr.Create(Line, Col, lkInt, FCurTok.Value);
    Advance;
    Exit;
  end;

  if Check(tokFloatLiteral) then
  begin
    Result := TASTLiteralExpr.Create(Line, Col, lkFloat, FCurTok.Value);
    Advance;
    Exit;
  end;

  if Check(tokStringLiteral) then
  begin
    Result := TASTLiteralExpr.Create(Line, Col, lkString, FCurTok.Value);
    Advance;
    Exit;
  end;

  if Check(tokCharLiteral) then
  begin
    Result := TASTLiteralExpr.Create(Line, Col, lkChar, FCurTok.Value);
    Advance;
    Exit;
  end;

  if Match(tokTrue) then
    Exit(TASTLiteralExpr.Create(Line, Col, lkBool, 'true'));

  if Match(tokFalse) then
    Exit(TASTLiteralExpr.Create(Line, Col, lkBool, 'false'));

  // Parenteses (Expr)
  if Match(tokLParen) then
  begin
    Result := ParseExpr;
    Expect(tokRParen, 'Esperado ")" para fechar expressao');
    Exit;
  end;

  // Identificador ou Chamada de Funcao ou Acesso a Membro
  if Check(tokIdentifier) then
  begin
    Id := Expect(tokIdentifier).Value;

    // Chamada de Funcao ou Construtor de Record
    if Match(tokLParen) then
    begin
      CallExpr := TASTCallExpr.Create(Line, Col, Id);
      if not Check(tokRParen) then
      begin
        repeat
          ArgOwn := owNone;
          if Match(tokTake) then
            ArgOwn := owTake
          else if Match(tokBorrow) then
            ArgOwn := owBorrow
          else if Match(tokMut) then
          begin
            Expect(tokBorrow);
            ArgOwn := owMutBorrow;
          end;

          // Suporte a argumentos nomeados estilo DataBuffer(id: 101, size: 2048)
          if Check(tokIdentifier) and (FPeekTok.Kind = tokColon) then
          begin
            Advance; // consome nome do campo
            Advance; // consome ':'
          end;

          ArgExpr := ParseExpr;
          CallExpr.Args.Add(TASTCallArg.Create(Line, Col, ArgOwn, ArgExpr));
        until not Match(tokComma);
      end;
      Expect(tokRParen, 'Esperado ")" no fechamento dos argumentos');
      Result := CallExpr;
    end
    else
    begin
      Result := TASTIdentifierExpr.Create(Line, Col, Id);
    end;

    // Acesso a membro sequencial: obj.campo ou chamada encadeada estilo metodo: obj.Metodo(args) [UFCS]
    while Match(tokDot) do
    begin
      Id := Expect(tokIdentifier, 'Esperado identificador apos "."').Value;
      if Match(tokLParen) then
      begin
        // UFCS: obj.Metodo(args...) e transformado transparentemente em Metodo(borrow obj, args...)
        CallExpr := TASTCallExpr.Create(Line, Col, Id);
        CallExpr.Args.Add(TASTCallArg.Create(Line, Col, owBorrow, Result));

        if not Check(tokRParen) then
        begin
          repeat
            ArgOwn := owNone;
            if Match(tokTake) then ArgOwn := owTake
            else if Match(tokBorrow) then ArgOwn := owBorrow
            else if Match(tokMut) then
            begin
              Expect(tokBorrow);
              ArgOwn := owMutBorrow;
            end;

            ArgExpr := ParseExpr;
            CallExpr.Args.Add(TASTCallArg.Create(Line, Col, ArgOwn, ArgExpr));
          until not Match(tokComma);
        end;
        Expect(tokRParen, 'Esperado ")" no fechamento dos argumentos');
        Result := CallExpr;
      end
      else
      begin
        Result := TASTMemberAccessExpr.Create(Line, Col, Result, Id);
      end;
    end;

    Exit;
  end;

  raise EAetherParserError.Create(Format('Expressao inesperada: "%s"', [FCurTok.Value]), Line, Col);
end;

function TAetherParser.ParseUnaryExpr: TASTExpr;
var
  Line, Col: Integer;
begin
  Line := FCurTok.Line;
  Col := FCurTok.Col;
  if Match(tokMinus) then
    Result := TASTUnaryExpr.Create(Line, Col, '-', ParseUnaryExpr())
  else if Match(tokNot) then
    Result := TASTUnaryExpr.Create(Line, Col, 'not', ParseUnaryExpr())
  else
    Result := ParsePrimaryExpr();
end;

function TAetherParser.ParseMultiplicativeExpr: TASTExpr;
var
  Left: TASTExpr;
  Op: string;
  Line, Col: Integer;
begin
  Left := ParseUnaryExpr;
  while Check(tokStar) or Check(tokSlash) or Check(tokMod) do
  begin
    Line := FCurTok.Line;
    Col := FCurTok.Col;
    Op := FCurTok.Value;
    Advance;
    Left := TASTBinaryExpr.Create(Line, Col, Left, Op, ParseUnaryExpr);
  end;
  Result := Left;
end;

function TAetherParser.ParseAdditiveExpr: TASTExpr;
var
  Left: TASTExpr;
  Op: string;
  Line, Col: Integer;
begin
  Left := ParseMultiplicativeExpr;
  while Check(tokPlus) or Check(tokMinus) do
  begin
    Line := FCurTok.Line;
    Col := FCurTok.Col;
    Op := FCurTok.Value;
    Advance;
    Left := TASTBinaryExpr.Create(Line, Col, Left, Op, ParseMultiplicativeExpr);
  end;
  Result := Left;
end;

function TAetherParser.ParseRelationalExpr: TASTExpr;
var
  Left: TASTExpr;
  Op: string;
  Line, Col: Integer;
begin
  Left := ParseAdditiveExpr;
  while Check(tokEqual) or Check(tokNotEqual) or Check(tokLess) or
        Check(tokLessEqual) or Check(tokGreater) or Check(tokGreaterEqual) do
  begin
    Line := FCurTok.Line;
    Col := FCurTok.Col;
    Op := FCurTok.Value;
    Advance;
    Left := TASTBinaryExpr.Create(Line, Col, Left, Op, ParseAdditiveExpr);
  end;
  Result := Left;
end;

function TAetherParser.ParseLogicalExpr: TASTExpr;
var
  Left: TASTExpr;
  Op: string;
  Line, Col: Integer;
begin
  Left := ParseRelationalExpr;
  while Check(tokAnd) or Check(tokOr) or Check(tokImplies) do
  begin
    Line := FCurTok.Line;
    Col := FCurTok.Col;
    Op := FCurTok.Value;
    Advance;
    Left := TASTBinaryExpr.Create(Line, Col, Left, Op, ParseRelationalExpr);
  end;
  Result := Left;
end;

function TAetherParser.ParseExpr: TASTExpr;
begin
  Result := ParseLogicalExpr;
end;

function TAetherParser.ParseModule: TASTModule;
var
  ModName: string;
  MLine, MCol: Integer;
begin
  MLine := FCurTok.Line;
  MCol := FCurTok.Col;
  Expect(tokModule, 'Todo arquivo Aether deve iniciar com "module <Nome>;"');
  ModName := Expect(tokIdentifier, 'Esperado nome do modulo').Value;
  Expect(tokSemicolon, 'Esperado ";" apos nome do modulo');

  Result := TASTModule.Create(MLine, MCol, ModName);
  try
    // Imports
    while Check(tokImport) do
      ParseImport(Result);

    // Tipos, Funcoes e Programa Principal
    while not Check(tokEOF) do
    begin
      if Check(tokType) then
        ParseTypeSection(Result)
      else if Check(tokFunction) then
        Result.Functions.Add(ParseFunction)
      else if Check(tokProgram) then
      begin
        Result.ProgramBlock := ParseProgramBlock;
        Break;
      end
      else
        raise EAetherParserError.Create(Format('Declaracao inesperada no modulo: "%s"', [FCurTok.Value]), FCurTok.Line, FCurTok.Col);
    end;
  except
    Result.Free;
    raise;
  end;
end;

end.
