unit uAetherParser;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  uAetherTokens,
  uAetherLexer,
  uAetherAST,
  uAetherDerives;

type
  TParsedAttributes = record
    Derives: TStringList;
    CfgCondition: string;
    InlineMode: string;
    IsCold: Boolean;
  end;

procedure InitAttributes(out Attrs: TParsedAttributes);
procedure ClearAttributes(var Attrs: TParsedAttributes);
procedure FreeAttributes(var Attrs: TParsedAttributes);
procedure CopyAttributes(const Src: TParsedAttributes; var Dst: TParsedAttributes);

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
    procedure ParseAttribute(var Attrs: TParsedAttributes);
    procedure ParseImport(AModule: TASTModule);
    procedure ParseConstSection(AModule: TASTModule; var SectionAttrs: TParsedAttributes); overload;
    procedure ParseConstSection(AModule: TASTModule); overload;
    procedure ParseTypeSection(AModule: TASTModule; var SectionAttrs: TParsedAttributes); overload;
    procedure ParseTypeSection(AModule: TASTModule); overload;
    function ParseRecordDecl(const AName: string; ALine, ACol: Integer): TASTRecordDecl;
    function ParseEnumDecl(const AName: string; ALine, ACol: Integer): TASTEnumDecl;
    function ParseTraitDecl(const AName: string; ALine, ACol: Integer): TASTTraitDecl;
    function ParseImplDecl: TASTImplDecl;
    function ParseFunction(IsSignatureOnly: Boolean; const Attrs: TParsedAttributes): TASTFunction; overload;
    function ParseFunction(IsSignatureOnly: Boolean = False): TASTFunction; overload;
    function ParseProgramBlock: TASTProgramBlock;
    procedure ParseVarSection(ALocalVars: TASTNodeList);

    function ParseStatement: TASTStmt;
    function ParseIfStmt: TASTIfStmt;
    function ParseWhileStmt: TASTWhileStmt;
    function ParseForStmt: TASTForStmt;
    function ParseRepeatStmt: TASTRepeatStmt;
    function ParseMatchStmt: TASTMatchStmt;
    function ParseReturnStmt: TASTReturnStmt;
    function ParseAsmStmt: TASTStmt;
    function ParseDeferStmt: TASTDeferStmt;
    function ParseTryStmt: TASTTryStmt;
    function ParseRaiseStmt: TASTRaiseStmt;
    function ParseUnsafeStmt: TASTUnsafeStmt;
    function ParseAssignOrCallStmt: TASTStmt;

    function ParseExpr: TASTExpr;
    function ParseLogicalExpr: TASTExpr;
    function ParseRelationalExpr: TASTExpr;
    function ParseAdditiveExpr: TASTExpr;
    function ParseMultiplicativeExpr: TASTExpr;
    function ParseUnaryExpr: TASTExpr;
    function ParsePrimaryExpr: TASTExpr;
    function ParseInterpolatedString(const RawStr: string; ALine, ACol: Integer): TASTExpr;
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
  if Match(tokCaret) then
  begin
    Result := '^' + ParseTypeRef();
    Exit;
  end;
  if Match(tokArray) then
  begin
    if Match(tokOf) then
    begin
      Result := 'array of ' + ParseTypeRef();
      Exit;
    end;
    Expect(tokLBracket, 'Esperado "[" na especificacao de dimensoes do array');
    BaseType := 'array[';
    BaseType := BaseType + Expect(tokIntLiteral, 'Esperada dimensao inteira do array').Value;
    while Match(tokComma) do
      BaseType := BaseType + ', ' + Expect(tokIntLiteral, 'Esperada dimensao inteira do array').Value;
    Expect(tokRBracket, 'Esperado "]" ao fechar dimensoes do array');
    Expect(tokOf, 'Esperado "of" apos dimensoes do array');
    BaseType := BaseType + '] of ' + ParseTypeRef();
    Result := BaseType;
    Exit;
  end;
  if Match(tokSet) then
  begin
    Expect(tokOf, 'Esperado "of" apos "set"');
    Result := 'set of ' + ParseTypeRef();
    Exit;
  end;
  if Match(tokMap) then
  begin
    Expect(tokLBracket, 'Esperado "[" apos "map"');
    BaseType := 'map[' + ParseTypeRef() + ']';
    Expect(tokRBracket, 'Esperado "]" apos tipo da chave do mapa');
    Result := BaseType + ParseTypeRef();
    Exit;
  end;

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
  IsPascal, IsC, IsLink: Boolean;
begin
  Expect(tokImport);
  IsPascal := False;
  IsC := False;
  IsLink := False;

  if Match(tokPascal) then
    IsPascal := True
  else if Check(tokIdentifier) and SameText(FCurTok.Value, 'c') then
  begin
    Advance;
    IsC := True;
  end
  else if Check(tokIdentifier) and SameText(FCurTok.Value, 'link') then
  begin
    Advance;
    IsLink := True;
  end;

  if IsC or IsLink or IsPascal then
  begin
    if Check(tokStringLiteral) then
      ImportName := Expect(tokStringLiteral).Value
    else
      ImportName := Expect(tokIdentifier).Value;
  end
  else
  begin
    ImportName := Expect(tokIdentifier, 'Esperado nome do modulo importado').Value;
    while Match(tokDot) do
      ImportName := ImportName + '.' + Expect(tokIdentifier, 'Esperado identificador apos "." no nome do modulo importado').Value;
    Match(tokAs);
  end;
  Expect(tokSemicolon);

  if IsPascal then
    AModule.PascalImports.Add(ImportName)
  else if IsC then
    AModule.CImports.Add(ImportName)
  else if IsLink then
    AModule.LinkDirectives.Add(ImportName)
  else
    AModule.Imports.Add(ImportName);
end;

function TAetherParser.ParseRecordDecl(const AName: string; ALine, ACol: Integer): TASTRecordDecl;
var
  FieldName, FieldType, FDoc: string;
  FLine, FCol: Integer;
  FieldNode: TASTRecordField;
begin
  Expect(tokRecord);
  Result := TASTRecordDecl.Create(ALine, ACol, AName);
  try
    while not Check(tokEnd) and not Check(tokEOF) do
    begin
      FLine := FCurTok.Line;
      FCol := FCurTok.Col;
      FDoc := FCurTok.DocComment;
      FieldName := Expect(tokIdentifier, 'Esperado nome do campo do record').Value;
      Expect(tokColon, 'Esperado ":" apos nome do campo');
      FieldType := ParseTypeRef;
      Expect(tokSemicolon, 'Esperado ";" apos definicao do campo');
      FieldNode := TASTRecordField.Create(FLine, FCol, FieldName, FieldType);
      FieldNode.DocComment := FDoc;
      Result.Fields.Add(FieldNode);
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
  VName, FName, FType, VDoc: string;
  VLine, VCol: Integer;
begin
  Expect(tokEnum);
  Result := TASTEnumDecl.Create(ALine, ACol, AName);
  try
    while not Check(tokEnd) and not Check(tokEOF) do
    begin
      VLine := FCurTok.Line;
      VCol := FCurTok.Col;
      VDoc := FCurTok.DocComment;
      VName := Expect(tokIdentifier, 'Esperado nome da variante do enum').Value;
      VariantNode := TASTEnumVariant.Create(VLine, VCol, VName);
      VariantNode.DocComment := VDoc;
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

procedure InitAttributes(out Attrs: TParsedAttributes);
begin
  Attrs.Derives := TStringList.Create;
  Attrs.CfgCondition := '';
  Attrs.InlineMode := '';
  Attrs.IsCold := False;
end;

procedure ClearAttributes(var Attrs: TParsedAttributes);
begin
  if Assigned(Attrs.Derives) then
    Attrs.Derives.Clear;
  Attrs.CfgCondition := '';
  Attrs.InlineMode := '';
  Attrs.IsCold := False;
end;

procedure FreeAttributes(var Attrs: TParsedAttributes);
begin
  if Assigned(Attrs.Derives) then
  begin
    Attrs.Derives.Free;
    Attrs.Derives := nil;
  end;
end;

procedure CopyAttributes(const Src: TParsedAttributes; var Dst: TParsedAttributes);
begin
  if Assigned(Src.Derives) and Assigned(Dst.Derives) then
    Dst.Derives.AddStrings(Src.Derives);
  if Src.CfgCondition <> '' then
    Dst.CfgCondition := Src.CfgCondition;
  if Src.InlineMode <> '' then
    Dst.InlineMode := Src.InlineMode;
  if Src.IsCold then
    Dst.IsCold := True;
end;

procedure TAetherParser.ParseAttribute(var Attrs: TParsedAttributes);
var
  AttrId, DeriveItem, CondStr, InlineVal: string;
  IsBracket: Boolean;
  ParenDepth: Integer;
begin
  IsBracket := Check(tokLBracket);
  if IsBracket then
    Advance
  else if Check(tokAt) then
    Advance
  else
    Exit;

  AttrId := Expect(tokIdentifier, 'Esperado identificador do atributo (ex: derive, cfg, inline, cold)').Value;

  if SameText(AttrId, 'derive') then
  begin
    Expect(tokLParen, 'Esperado "(" apos derive');
    repeat
      DeriveItem := Expect(tokIdentifier, 'Esperado nome da trait a derivar (ex: Debug, JSON, Clone, Equals)').Value;
      if Assigned(Attrs.Derives) and (Attrs.Derives.IndexOf(DeriveItem) < 0) then
        Attrs.Derives.Add(DeriveItem);
    until not Match(tokComma);
    Expect(tokRParen, 'Esperado ")" ao fechar derive');
  end
  else if SameText(AttrId, 'cfg') then
  begin
    Expect(tokLParen, 'Esperado "(" apos cfg');
    CondStr := '';
    ParenDepth := 1;
    while (ParenDepth > 0) and not Check(tokEOF) do
    begin
      if Check(tokLParen) then
      begin
        Inc(ParenDepth);
        CondStr := CondStr + '(';
        Advance;
      end
      else if Check(tokRParen) then
      begin
        Dec(ParenDepth);
        if ParenDepth > 0 then
        begin
          CondStr := CondStr + ')';
          Advance;
        end;
      end
      else
      begin
        if FCurTok.Kind = tokStringLiteral then
          CondStr := CondStr + '"' + FCurTok.Value + '"'
        else
          CondStr := CondStr + FCurTok.Value;
        Advance;
      end;
    end;
    Expect(tokRParen, 'Esperado ")" ao fechar cfg');
    Attrs.CfgCondition := Trim(CondStr);
  end
  else if SameText(AttrId, 'inline') then
  begin
    if Match(tokLParen) then
    begin
      InlineVal := Expect(tokIdentifier, 'Esperado "always" ou "never" em inline(...)').Value;
      Attrs.InlineMode := LowerCase(InlineVal);
      Expect(tokRParen, 'Esperado ")" ao fechar inline');
    end
    else
      Attrs.InlineMode := 'always';
  end
  else if SameText(AttrId, 'cold') then
  begin
    Attrs.IsCold := True;
    if Match(tokLParen) then
    begin
      while not Check(tokRParen) and not Check(tokEOF) do
        Advance;
      Expect(tokRParen, 'Esperado ")" ao fechar cold');
    end;
  end
  else
  begin
    // Atributo desconhecido / futuro
    if Check(tokLParen) then
    begin
      Advance;
      ParenDepth := 1;
      while (ParenDepth > 0) and not Check(tokEOF) do
      begin
        if Check(tokLParen) then Inc(ParenDepth)
        else if Check(tokRParen) then Dec(ParenDepth);
        if ParenDepth > 0 then Advance;
      end;
      if Check(tokRParen) then Advance;
    end;
  end;

  if IsBracket then
    Expect(tokRBracket, 'Esperado "]" ao fechar atributo');
end;

procedure TAetherParser.ParseConstSection(AModule: TASTModule; var SectionAttrs: TParsedAttributes);
var
  ConstName, ConstType, ConstDoc, EffectiveCfg: string;
  CLine, CCol: Integer;
  ValExpr: TASTExpr;
  ConstNode: TASTConstDecl;
  CurrentAttrs: TParsedAttributes;
begin
  Expect(tokConst);
  InitAttributes(CurrentAttrs);
  try
    while not Check(tokEOF) do
    begin
      while Check(tokLBracket) or Check(tokAt) do
        ParseAttribute(CurrentAttrs);

      if Check(tokIdentifier) then
      begin
        CLine := FCurTok.Line;
        CCol := FCurTok.Col;
        ConstDoc := FCurTok.DocComment;
        ConstName := Expect(tokIdentifier, 'Esperado nome da constante').Value;
        ConstType := '';
        if Match(tokColon) then
          ConstType := ParseTypeRef;
        Expect(tokEqual, 'Esperado "=" na definicao de constante');
        ValExpr := ParseExpr;
        Expect(tokSemicolon, 'Esperado ";" apos definicao de constante');

        EffectiveCfg := CurrentAttrs.CfgCondition;
        if EffectiveCfg = '' then
          EffectiveCfg := SectionAttrs.CfgCondition;

        ConstNode := TASTConstDecl.Create(CLine, CCol, ConstName, ConstType, ValExpr);
        ConstNode.DocComment := ConstDoc;
        ConstNode.CfgCondition := EffectiveCfg;
        AModule.Constants.Add(ConstNode);
        ClearAttributes(SectionAttrs);
      end
      else
        Break;
    end;
  finally
    FreeAttributes(CurrentAttrs);
  end;
end;

procedure TAetherParser.ParseConstSection(AModule: TASTModule);
var
  EmptyAttrs: TParsedAttributes;
begin
  InitAttributes(EmptyAttrs);
  try
    ParseConstSection(AModule, EmptyAttrs);
  finally
    FreeAttributes(EmptyAttrs);
  end;
end;

procedure TAetherParser.ParseTypeSection(AModule: TASTModule; var SectionAttrs: TParsedAttributes);
var
  TypeName, TypeDoc, EffectiveCfg, LowBound, HighBound, BaseType, KeyType, ValType: string;
  TLine, TCol: Integer;
  RecDecl: TASTRecordDecl;
  EnumDecl: TASTEnumDecl;
  TraitDecl: TASTTraitDecl;
  ArrDecl: TASTArrayDecl;
  SetDecl: TASTSetDecl;
  SubDecl: TASTSubrangeDecl;
  MapDecl: TASTMapDecl;
  CurrentAttrs: TParsedAttributes;
begin
  Expect(tokType);
  InitAttributes(CurrentAttrs);
  try
    while not Check(tokEOF) do
    begin
      ClearAttributes(CurrentAttrs);
      while Check(tokLBracket) or Check(tokAt) do
        ParseAttribute(CurrentAttrs);

      if Check(tokIdentifier) and (FPeekTok.Kind = tokEqual) then
      begin
        TLine := FCurTok.Line;
        TCol := FCurTok.Col;
        TypeDoc := FCurTok.DocComment;
        TypeName := Expect(tokIdentifier).Value;
        Expect(tokEqual, 'Esperado "=" na declaracao de tipo');

        EffectiveCfg := CurrentAttrs.CfgCondition;
        if EffectiveCfg = '' then
          EffectiveCfg := SectionAttrs.CfgCondition;

        if Check(tokRecord) then
        begin
          RecDecl := ParseRecordDecl(TypeName, TLine, TCol);
          RecDecl.DocComment := TypeDoc;
          RecDecl.Derives.AddStrings(CurrentAttrs.Derives);
          RecDecl.Derives.AddStrings(SectionAttrs.Derives);
          RecDecl.CfgCondition := EffectiveCfg;
          AModule.Types.Add(RecDecl);
        end
        else if Check(tokEnum) then
        begin
          EnumDecl := ParseEnumDecl(TypeName, TLine, TCol);
          EnumDecl.DocComment := TypeDoc;
          EnumDecl.Derives.AddStrings(CurrentAttrs.Derives);
          EnumDecl.Derives.AddStrings(SectionAttrs.Derives);
          EnumDecl.CfgCondition := EffectiveCfg;
          AModule.Types.Add(EnumDecl);
        end
        else if Check(tokTrait) then
        begin
          TraitDecl := ParseTraitDecl(TypeName, TLine, TCol);
          TraitDecl.DocComment := TypeDoc;
          AModule.Traits.Add(TraitDecl);
        end
        else if Check(tokArray) then
        begin
          Advance; // consome 'array'
          if Match(tokOf) then
          begin
            ArrDecl := TASTArrayDecl.Create(TLine, TCol, TypeName, ParseTypeRef);
            ArrDecl.DocComment := TypeDoc;
            ArrDecl.CfgCondition := EffectiveCfg;
            AModule.Types.Add(ArrDecl);
          end
          else
          begin
            Expect(tokLBracket, 'Esperado "[" na declaracao de dimensoes do array');
            ArrDecl := TASTArrayDecl.Create(TLine, TCol, TypeName, '');
            ArrDecl.Dims.Add(Expect(tokIntLiteral, 'Esperada dimensao inteira do array').Value);
            while Match(tokComma) do
              ArrDecl.Dims.Add(Expect(tokIntLiteral, 'Esperada dimensao inteira do array').Value);
            Expect(tokRBracket, 'Esperado "]" apos dimensoes do array');
            Expect(tokOf, 'Esperado "of" apos dimensoes do array');
            ArrDecl.ElemType := ParseTypeRef;
            ArrDecl.DocComment := TypeDoc;
            ArrDecl.CfgCondition := EffectiveCfg;
            AModule.Types.Add(ArrDecl);
          end;
        end
        else if Check(tokSet) then
        begin
          Advance; // consome 'set'
          Expect(tokOf, 'Esperado "of" apos "set"');
          SetDecl := TASTSetDecl.Create(TLine, TCol, TypeName);
          if Match(tokLParen) then
          begin
            while not Check(tokRParen) and not Check(tokEOF) do
            begin
              SetDecl.Variants.Add(TASTEnumVariant.Create(FCurTok.Line, FCurTok.Col, Expect(tokIdentifier, 'Esperado identificador de variante de conjunto').Value));
              if not Match(tokComma) then Break;
            end;
            Expect(tokRParen, 'Esperado ")" ao fechar variantes de conjunto');
          end
          else
            SetDecl.ElemType := ParseTypeRef;
          SetDecl.DocComment := TypeDoc;
          SetDecl.CfgCondition := EffectiveCfg;
          AModule.Types.Add(SetDecl);
        end
        else if Check(tokMap) then
        begin
          Advance; // consome 'map'
          Expect(tokLBracket, 'Esperado "[" apos "map"');
          KeyType := ParseTypeRef();
          Expect(tokRBracket, 'Esperado "]" apos tipo da chave do mapa');
          ValType := ParseTypeRef();
          MapDecl := TASTMapDecl.Create(TLine, TCol, TypeName, KeyType, ValType);
          MapDecl.DocComment := TypeDoc;
          MapDecl.CfgCondition := EffectiveCfg;
          AModule.Types.Add(MapDecl);
        end
        else if (Check(tokIntLiteral) or Check(tokCharLiteral)) and (FPeekTok.Kind = tokDotDot) then
        begin
          LowBound := FCurTok.Value;
          Advance;
          Expect(tokDotDot, 'Esperado ".." no intervalo da subfaixa');
          HighBound := FCurTok.Value;
          Advance;
          if (Length(LowBound) > 0) and (LowBound[1] = '''') then
            BaseType := 'Char'
          else
            BaseType := 'Int32';
          SubDecl := TASTSubrangeDecl.Create(TLine, TCol, TypeName, LowBound, HighBound, BaseType);
          SubDecl.DocComment := TypeDoc;
          SubDecl.CfgCondition := EffectiveCfg;
          AModule.Types.Add(SubDecl);
        end
        else if Check(tokLParen) then
        begin
          Advance; // consome '('
          EnumDecl := TASTEnumDecl.Create(TLine, TCol, TypeName);
          while not Check(tokRParen) and not Check(tokEOF) do
          begin
            EnumDecl.Variants.Add(TASTEnumVariant.Create(FCurTok.Line, FCurTok.Col, Expect(tokIdentifier, 'Esperado nome da variante do enum').Value));
            if not Match(tokComma) then Break;
          end;
          Expect(tokRParen, 'Esperado ")" ao fechar variantes do enum');
          EnumDecl.DocComment := TypeDoc;
          EnumDecl.Derives.AddStrings(CurrentAttrs.Derives);
          EnumDecl.Derives.AddStrings(SectionAttrs.Derives);
          EnumDecl.CfgCondition := EffectiveCfg;
          AModule.Types.Add(EnumDecl);
        end
        else
          raise EAetherParserError.Create('Esperado "record", "enum", "trait", "array", "set" ou subfaixa na declaracao de tipo', TLine, TCol);

        ClearAttributes(SectionAttrs);
        Expect(tokSemicolon, 'Esperado ";" apos declaracao de tipo');
      end
      else
      begin
        CopyAttributes(CurrentAttrs, SectionAttrs);
        Break;
      end;
    end;
  finally
    FreeAttributes(CurrentAttrs);
  end;
end;

procedure TAetherParser.ParseTypeSection(AModule: TASTModule);
var
  EmptyAttrs: TParsedAttributes;
begin
  InitAttributes(EmptyAttrs);
  try
    ParseTypeSection(AModule, EmptyAttrs);
  finally
    FreeAttributes(EmptyAttrs);
  end;
end;

function TAetherParser.ParseTraitDecl(const AName: string; ALine, ACol: Integer): TASTTraitDecl;
var
  TraitName, TraitDoc: string;
begin
  TraitDoc := FCurTok.DocComment;
  Expect(tokTrait);
  if AName <> '' then
    TraitName := AName
  else
    TraitName := Expect(tokIdentifier, 'Esperado identificador com nome da trait').Value;

  Result := TASTTraitDecl.Create(ALine, ACol, TraitName);
  Result.DocComment := TraitDoc;
  try
    while not Check(tokEnd) and not Check(tokEOF) do
    begin
      if Check(tokFunction) or Check(tokAsync) then
        Result.Methods.Add(ParseFunction(True))
      else
        raise EAetherParserError.Create('Esperado "function" na declaracao da trait', FCurTok.Line, FCurTok.Col);
    end;
    Expect(tokEnd, 'Esperado "end" no fechamento da trait');
    if AName = '' then
      Expect(tokSemicolon, 'Esperado ";" apos "end" da trait');
  except
    Result.Free;
    raise;
  end;
end;

function TAetherParser.ParseImplDecl: TASTImplDecl;
var
  TraitName, TargetName: string;
  ILine, ICol, J: Integer;
  FuncNode: TASTFunction;
begin
  ILine := FCurTok.Line;
  ICol := FCurTok.Col;
  Expect(tokImpl);
  TraitName := Expect(tokIdentifier, 'Esperado nome da trait apos "impl"').Value;
  Expect(tokFor, 'Esperado "for" apos nome da trait');
  TargetName := Expect(tokIdentifier, 'Esperado nome do tipo apos "for"').Value;

  Result := TASTImplDecl.Create(ILine, ICol, TraitName, TargetName);
  try
    while not Check(tokEnd) and not Check(tokEOF) do
    begin
      if Check(tokFunction) or Check(tokAsync) then
      begin
        FuncNode := ParseFunction(False);
        for J := 0 to FuncNode.Params.Count - 1 do
        begin
          if SameText(TASTParam(FuncNode.Params[J]).TypeName, 'Self') then
            TASTParam(FuncNode.Params[J]).TypeName := TargetName;
        end;
        Result.Methods.Add(FuncNode);
      end
      else
        raise EAetherParserError.Create('Esperado "function" na implementacao da trait', FCurTok.Line, FCurTok.Col);
    end;
    Expect(tokEnd, 'Esperado "end" no fechamento do bloco impl');
    Expect(tokSemicolon, 'Esperado ";" apos "end" do bloco impl');
  except
    Result.Free;
    raise;
  end;
end;

procedure TAetherParser.ParseVarSection(ALocalVars: TASTNodeList);
var
  VarNames: TStringList;
  VarType: string;
  InitExpr, ClonedInit: TASTExpr;
  VLine, VCol, I: Integer;
  IsMut: Boolean;
begin
  IsMut := Check(tokVar);
  Advance; // consome 'var' ou 'let'

  VarNames := TStringList.Create;
  try
    while Check(tokIdentifier) do
    begin
      VarNames.Clear;
      VLine := FCurTok.Line;
      VCol := FCurTok.Col;
      VarNames.Add(Expect(tokIdentifier).Value);
      while Match(tokComma) do
        VarNames.Add(Expect(tokIdentifier, 'Esperado identificador apos "," na declaracao de variaveis').Value);

      VarType := '';
      if Match(tokColon) then
        VarType := ParseTypeRef();

      InitExpr := nil;
      if Match(tokAssign) or Match(tokEqual) then
        InitExpr := ParseExpr;

      if (VarType = '') and not Assigned(InitExpr) then
        raise EAetherParserError.Create('Esperado ": <Tipo>" ou ":= <Valor>" na declaracao de variavel', FCurTok.Line, FCurTok.Col);

      Expect(tokSemicolon, 'Esperado ";" apos declaracao de variavel');
      for I := 0 to VarNames.Count - 1 do
      begin
        if I = 0 then
          ClonedInit := InitExpr
        else if Assigned(InitExpr) then
          ClonedInit := TASTExpr(CloneASTNode(InitExpr))
        else
          ClonedInit := nil;
        ALocalVars.Add(TASTVarDecl.Create(VLine, VCol, VarNames[I], VarType, ClonedInit, IsMut));
      end;
    end;
  finally
    VarNames.Free;
  end;
end;

function TAetherParser.ParseFunction(IsSignatureOnly: Boolean; const Attrs: TParsedAttributes): TASTFunction;
var
  FuncName, ReturnType, ParamName, ParamType, FDoc: string;
  FLine, FCol: Integer;
  Ownership: TOwnershipKind;
  IsExt, IsAsyncFunc, IsExportFunc: Boolean;
  ExtLib, ExtAbi, ExportAbi: string;
begin
  FLine := FCurTok.Line;
  FCol := FCurTok.Col;
  FDoc := FCurTok.DocComment;
  IsExt := False;
  IsAsyncFunc := False;
  IsExportFunc := False;
  ExtLib := '';
  ExtAbi := 'c';
  ExportAbi := 'cdecl';

  while Check(tokAsync) or Check(tokExtern) or Check(tokExport) do
  begin
    if Match(tokAsync) then
    begin
      IsAsyncFunc := True;
      if (FDoc = '') and (FCurTok.DocComment <> '') then
        FDoc := FCurTok.DocComment;
    end
    else if Match(tokExport) then
    begin
      IsExportFunc := True;
      if (FDoc = '') and (FCurTok.DocComment <> '') then
        FDoc := FCurTok.DocComment;
      if Match(tokCdecl) or (Check(tokIdentifier) and SameText(FCurTok.Value, 'cdecl')) then
      begin
        if Check(tokIdentifier) then Advance;
        ExportAbi := 'cdecl';
      end
      else if Check(tokIdentifier) and SameText(FCurTok.Value, 'stdcall') then
      begin
        Advance;
        ExportAbi := 'stdcall';
      end;
    end
    else if Match(tokExtern) then
    begin
      IsExt := True;
      if (FDoc = '') and (FCurTok.DocComment <> '') then
        FDoc := FCurTok.DocComment;
      if Match(tokPascal) then
        ExtAbi := 'pascal'
      else if Check(tokIdentifier) and SameText(FCurTok.Value, 'c') then
      begin
        Advance;
        ExtAbi := 'c';
      end;

      if Check(tokStringLiteral) then
        ExtLib := Expect(tokStringLiteral).Value;
    end;
  end;

  if (FDoc = '') and (FCurTok.DocComment <> '') then
    FDoc := FCurTok.DocComment;

  Expect(tokFunction);
  FuncName := Expect(tokIdentifier, 'Esperado nome da funcao').Value;

  Result := TASTFunction.Create(FLine, FCol, FuncName, '');
  Result.DocComment := FDoc;
  Result.IsAsync := IsAsyncFunc;
  Result.IsExtern := IsExt;
  Result.IsExport := IsExportFunc;
  Result.ExternLib := ExtLib;
  Result.ExternAbi := ExtAbi;
  Result.ExportAbi := ExportAbi;
  Result.InlineMode := Attrs.InlineMode;
  Result.IsCold := Attrs.IsCold;
  Result.CfgCondition := Attrs.CfgCondition;
  try
    // Parametro generico com bound opcional: function Imprimir<T: Printable>(...)
    if Match(tokLess) then
    begin
      Result.GenericParam := Expect(tokIdentifier, 'Esperado nome do parametro generico').Value;
      if Match(tokColon) then
        Result.TraitBound := Expect(tokIdentifier, 'Esperado nome da trait no bound').Value;
      Expect(tokGreater, 'Esperado ">" no fechamento do parametro generico');
    end;

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
        if Match(tokColon) then
          ParamType := ParseTypeRef
        else if SameText(ParamName, 'self') then
          ParamType := 'Self'
        else
          raise EAetherParserError.Create('Esperado ":" apos nome do parametro', FCurTok.Line, FCurTok.Col);

        Result.Params.Add(TASTParam.Create(FCurTok.Line, FCurTok.Col, ParamName, ParamType, Ownership));
      until (not Match(tokSemicolon)) and (not Match(tokComma));
    end;
    Expect(tokRParen, 'Esperado ")" no fechamento dos parametros');

    Expect(tokColon, 'Esperado ":" apos parametros da funcao');
    ReturnType := ParseTypeRef;
    Result.ReturnType := ReturnType;

    // Modificadores opcionais apos retorno: export; cdecl; stdcall;
    while Check(tokSemicolon) or Check(tokExport) or Check(tokCdecl) or (Check(tokIdentifier) and (SameText(FCurTok.Value, 'export') or SameText(FCurTok.Value, 'cdecl') or SameText(FCurTok.Value, 'stdcall'))) do
    begin
      if Match(tokSemicolon) then
      begin
        if not (Check(tokExport) or Check(tokCdecl) or (Check(tokIdentifier) and (SameText(FCurTok.Value, 'export') or SameText(FCurTok.Value, 'cdecl') or SameText(FCurTok.Value, 'stdcall')))) then
          Break;
      end
      else if Match(tokExport) or (Check(tokIdentifier) and SameText(FCurTok.Value, 'export')) then
      begin
        if not Match(tokExport) then Advance;
        Result.IsExport := True;
      end
      else if Match(tokCdecl) or (Check(tokIdentifier) and SameText(FCurTok.Value, 'cdecl')) then
      begin
        if not Match(tokCdecl) then Advance;
        Result.ExportAbi := 'cdecl';
      end
      else if Check(tokIdentifier) and SameText(FCurTok.Value, 'stdcall') then
      begin
        Advance;
        Result.ExportAbi := 'stdcall';
      end;
    end;

    // Se for assinatura de trait, nao possui contratos nem corpo
    if IsSignatureOnly then
    begin
      Expect(tokSemicolon, 'Esperado ";" apos assinatura do metodo da trait');
      Exit;
    end;

    // Bloco de Contratos Opcional (com ou sem a palavra-chave "contract")
    if Match(tokContract) or Check(tokRequire) or Check(tokEnsure) then
    begin
      if Match(tokRequire) then
      begin
        while not Check(tokEnsure) and not Check(tokVar) and not Check(tokLet) and not Check(tokBegin) and not Check(tokSemicolon) and not Check(tokEOF) do
        begin
          Result.Requires.Add(ParseExpr);
          Expect(tokSemicolon, 'Esperado ";" apos expressao de require');
        end;
      end;

      if Match(tokEnsure) then
      begin
        while not Check(tokVar) and not Check(tokLet) and not Check(tokBegin) and not Check(tokSemicolon) and not Check(tokEOF) do
        begin
          Result.Ensures.Add(ParseExpr);
          Expect(tokSemicolon, 'Esperado ";" apos expressao de ensure');
        end;
      end;
    end;

    // Se for extern, nao possui corpo begin..end
    if IsExt then
    begin
      if Check(tokSemicolon) then
        Match(tokSemicolon);
      Exit;
    end;

    // Variaveis Locais
    while Check(tokVar) or Check(tokLet) do
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

function TAetherParser.ParseFunction(IsSignatureOnly: Boolean): TASTFunction;
var
  EmptyAttrs: TParsedAttributes;
begin
  InitAttributes(EmptyAttrs);
  try
    Result := ParseFunction(IsSignatureOnly, EmptyAttrs);
  finally
    FreeAttributes(EmptyAttrs);
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
  ProgName := Expect(tokIdentifier, 'Esperado "Main" apos a palavra-chave "program"').Value;
  if not SameText(ProgName, 'Main') then
    raise EAetherParserError.CreateFmt('Erro E0002: O bloco executavel deve ser obrigatoriamente "program Main;", mas foi encontrado "program %s;" na linha %d, coluna %d', [ProgName, PLine, PCol]);
  Expect(tokSemicolon, 'Esperado ";" apos declaracao "program Main"');

  Result := TASTProgramBlock.Create(PLine, PCol, ProgName);
  try
    while Check(tokVar) or Check(tokLet) do
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

function TAetherParser.ParseForStmt: TASTForStmt;
var
  VarName: string;
  StartExpr, EndExpr, ColExpr: TASTExpr;
  FLine, FCol: Integer;
  IsDownTo: Boolean;
begin
  FLine := FCurTok.Line;
  FCol := FCurTok.Col;
  Expect(tokFor);
  VarName := Expect(tokIdentifier, 'Esperado nome da variavel contadora do for').Value;

  if Match(tokIn) then
  begin
    ColExpr := ParseExpr;
    Expect(tokDo, 'Esperado "do" apos colecao do laco for..in');
    Result := TASTForStmt.Create(FLine, FCol, VarName, nil, nil, False);
    Result.CollectionExpr := ColExpr;
    try
      while not Check(tokEnd) and not Check(tokEOF) do
      begin
        Result.Body.Add(ParseStatement);
        Expect(tokSemicolon, 'Esperado ";" apos instrucao do for');
      end;
      Expect(tokEnd, 'Esperado "end" no fechamento do for');
    except
      Result.Free;
      raise;
    end;
    Exit;
  end;

  Expect(tokAssign, 'Esperado ":=" ou "in" apos nome da variavel no for');
  StartExpr := ParseExpr;
  IsDownTo := False;
  if Match(tokTo) then
    IsDownTo := False
  else if Match(tokDownto) then
    IsDownTo := True
  else
    raise EAetherParserError.CreateFmt('Esperado "to" ou "downto" no laco for na linha %d, coluna %d', [FCurTok.Line, FCurTok.Col]);

  EndExpr := ParseExpr;
  Expect(tokDo, 'Esperado "do" apos limites do laco for');

  Result := TASTForStmt.Create(FLine, FCol, VarName, StartExpr, EndExpr, IsDownTo);
  try
    while not Check(tokEnd) and not Check(tokEOF) do
    begin
      Result.Body.Add(ParseStatement);
      Expect(tokSemicolon, 'Esperado ";" apos instrucao do for');
    end;
    Expect(tokEnd, 'Esperado "end" no fechamento do for');
  except
    Result.Free;
    raise;
  end;
end;

function TAetherParser.ParseRepeatStmt: TASTRepeatStmt;
var
  RLine, RCol: Integer;
  Cond: TASTExpr;
begin
  RLine := FCurTok.Line;
  RCol := FCurTok.Col;
  Expect(tokRepeat);
  Result := TASTRepeatStmt.Create(RLine, RCol, nil);
  try
    while not Check(tokUntil) and not Check(tokEOF) do
    begin
      Result.Body.Add(ParseStatement);
      Expect(tokSemicolon, 'Esperado ";" apos instrucao no bloco repeat');
    end;
    Expect(tokUntil, 'Esperado "until" para fechar o bloco repeat');
    Cond := ParseExpr;
    Result.Condition := Cond;
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
  IsLet, UseCaseKeyword: Boolean;
  MLine, MCol, PLine, PCol: Integer;

  function IsShorthandCaseStart: Boolean;
  begin
    if Check(tokCase) then Exit(True);
    if Check(tokEnd) or Check(tokEOF) then Exit(False);
    if (Check(tokUnderscore) or Check(tokIntLiteral) or Check(tokStringLiteral) or
        Check(tokCharLiteral) or Check(tokTrue) or Check(tokFalse) or Check(tokIdentifier)) and
       ((FPeekTok.Kind = tokColon) or (FPeekTok.Kind = tokFatArrow)) then
      Exit(True);
    if Check(tokMinus) and (FPeekTok.Kind = tokIntLiteral) then
      Exit(True);
    Result := False;
  end;
begin
  MLine := FCurTok.Line;
  MCol := FCurTok.Col;
  Expect(tokMatch);
  MatchExpr := ParseExpr;
  if not Match(tokDo) and not Match(tokWith) then
    Expect(tokDo, 'Esperado "do" ou "with" apos expressao do match');

  Result := TASTMatchStmt.Create(MLine, MCol, MatchExpr);
  try
    UseCaseKeyword := Check(tokCase);
    while (UseCaseKeyword and Match(tokCase)) or ((not UseCaseKeyword) and IsShorthandCaseStart) do
    begin
      PLine := FCurTok.Line;
      PCol := FCurTok.Col;

      if Match(tokUnderscore) then
        PatVal := '_'
      else if Check(tokIntLiteral) then
      begin
        PatVal := FCurTok.Value;
        Advance;
      end
      else if Match(tokMinus) then
      begin
        PatVal := '-' + Expect(tokIntLiteral, 'Esperado literal inteiro apos "-" no case').Value;
      end
      else if Check(tokStringLiteral) then
      begin
        PatVal := '"' + FCurTok.Value + '"';
        Advance;
      end
      else if Check(tokCharLiteral) then
      begin
        PatVal := '''' + FCurTok.Value + '''';
        Advance;
      end
      else if Match(tokTrue) then
        PatVal := 'true'
      else if Match(tokFalse) then
        PatVal := 'false'
      else
      begin
        PatVal := Expect(tokIdentifier, 'Esperado padrao no case').Value;
        // Suporte a Enum.Variante
        if Match(tokDot) then
          PatVal := PatVal + '.' + Expect(tokIdentifier).Value;
      end;

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
        begin
          SubVal := FCurTok.Value;
          Advance;
        end;

        if Match(tokDot) then
          SubVal := SubVal + '.' + Expect(tokIdentifier).Value;

        Expect(tokRParen, 'Esperado ")" apos argumento do padrao');
      end;

      PatternNode := TASTPattern.Create(PLine, PCol, PatVal, SubVal, IsLet);
      CaseNode := TASTMatchCase.Create(PLine, PCol, PatternNode);
      Result.Cases.Add(CaseNode);

      if not Match(tokColon) and not Match(tokFatArrow) then
        Expect(tokColon, 'Esperado ":" ou "=>" apos padrao do case');

      while ((UseCaseKeyword and not Check(tokCase)) or ((not UseCaseKeyword) and not IsShorthandCaseStart)) and
            not Check(tokEnd) and not Check(tokEOF) do
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

function TAetherParser.ParseAsmStmt: TASTStmt;
var
  AsmTok: TToken;
begin
  AsmTok := Expect(tokAsm);
  Result := TASTAsmStmt.Create(AsmTok.Line, AsmTok.Col, AsmTok.Value);
  Expect(tokEnd, 'Esperado "end" no fechamento do bloco asm');
end;

function TAetherParser.ParseDeferStmt: TASTDeferStmt;
var
  DLine, DCol: Integer;
begin
  DLine := FCurTok.Line;
  DCol := FCurTok.Col;
  Expect(tokDefer);
  Result := TASTDeferStmt.Create(DLine, DCol, ParseStatement);
end;

function TAetherParser.ParseTryStmt: TASTTryStmt;
var
  TLine, TCol: Integer;
begin
  TLine := FCurTok.Line;
  TCol := FCurTok.Col;
  Expect(tokTry);
  Result := TASTTryStmt.Create(TLine, TCol);
  try
    while not Check(tokExcept) and not Check(tokEnd) and not Check(tokEOF) do
    begin
      Result.TryBody.Add(ParseStatement);
      Expect(tokSemicolon, 'Esperado ";" apos instrucao no bloco try');
    end;
    Expect(tokExcept, 'Esperado "except" no bloco try..except');
    while not Check(tokEnd) and not Check(tokEOF) do
    begin
      Result.ExceptBody.Add(ParseStatement);
      Expect(tokSemicolon, 'Esperado ";" apos instrucao no bloco except');
    end;
    Expect(tokEnd, 'Esperado "end" no fechamento do bloco try..except');
  except
    Result.Free;
    raise;
  end;
end;

function TAetherParser.ParseRaiseStmt: TASTRaiseStmt;
var
  RLine, RCol: Integer;
begin
  RLine := FCurTok.Line;
  RCol := FCurTok.Col;
  Expect(tokRaise);
  Result := TASTRaiseStmt.Create(RLine, RCol, ParseExpr);
end;

function TAetherParser.ParseUnsafeStmt: TASTUnsafeStmt;
var
  ULine, UCol: Integer;
begin
  ULine := FCurTok.Line;
  UCol := FCurTok.Col;
  Expect(tokUnsafe);
  Result := TASTUnsafeStmt.Create(ULine, UCol);
  try
    while not Check(tokEnd) and not Check(tokEOF) do
    begin
      Result.Body.Add(ParseStatement);
      Expect(tokSemicolon, 'Esperado ";" apos instrucao no bloco unsafe');
    end;
    Expect(tokEnd, 'Esperado "end" no fechamento do bloco unsafe');
  except
    Result.Free;
    raise;
  end;
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
  else if Check(tokFor) then
    Result := ParseForStmt
  else if Check(tokRepeat) then
    Result := ParseRepeatStmt
  else if Check(tokBreak) then
  begin
    Result := TASTBreakStmt.Create(FCurTok.Line, FCurTok.Col);
    Advance;
  end
  else if Check(tokContinue) then
  begin
    Result := TASTContinueStmt.Create(FCurTok.Line, FCurTok.Col);
    Advance;
  end
  else if Check(tokMatch) then
    Result := ParseMatchStmt
  else if Check(tokReturn) then
    Result := ParseReturnStmt
  else if Check(tokAsm) then
    Result := ParseAsmStmt
  else if Check(tokDefer) then
    Result := ParseDeferStmt
  else if Check(tokTry) then
    Result := ParseTryStmt
  else if Check(tokRaise) then
    Result := ParseRaiseStmt
  else if Check(tokUnsafe) then
    Result := ParseUnsafeStmt
  else
    Result := ParseAssignOrCallStmt;
end;

function TAetherParser.ParseInterpolatedString(const RawStr: string; ALine, ACol: Integer): TASTExpr;
var
  I, Len, BraceDepth, StartPos: Integer;
  LiteralBuf, InnerCode: string;
  InnerExpr: TASTExpr;
  SubLexer: TAetherLexer;
  SubParser: TAetherParser;
  CallExpr: TASTCallExpr;

  procedure AppendPart(Part: TASTExpr);
  begin
    if not Assigned(Result) then
      Result := Part
    else
      Result := TASTBinaryExpr.Create(ALine, ACol, Result, '+', Part);
  end;
begin
  Result := nil;
  LiteralBuf := '';
  I := 1;
  Len := Length(RawStr);
  while I <= Len do
  begin
    if (RawStr[I] = '{') and (I + 1 <= Len) and (RawStr[I + 1] = '{') then
    begin
      LiteralBuf := LiteralBuf + '{';
      Inc(I, 2);
    end
    else if (RawStr[I] = '}') and (I + 1 <= Len) and (RawStr[I + 1] = '}') then
    begin
      LiteralBuf := LiteralBuf + '}';
      Inc(I, 2);
    end
    else if RawStr[I] = '{' then
    begin
      if LiteralBuf <> '' then
      begin
        AppendPart(TASTLiteralExpr.Create(ALine, ACol, lkString, LiteralBuf));
        LiteralBuf := '';
      end;
      Inc(I);
      StartPos := I;
      BraceDepth := 1;
      while (I <= Len) and (BraceDepth > 0) do
      begin
        if RawStr[I] = '{' then Inc(BraceDepth)
        else if RawStr[I] = '}' then Dec(BraceDepth);
        if BraceDepth > 0 then Inc(I);
      end;
      if BraceDepth > 0 then
        raise EAetherParserError.Create('Chave "{" nao fechada em string interpolada', ALine, ACol);
      InnerCode := Trim(Copy(RawStr, StartPos, I - StartPos));
      Inc(I);
      if InnerCode = '' then
        raise EAetherParserError.Create('Expressao vazia dentro de interpolacao "{}"', ALine, ACol);

      SubLexer := TAetherLexer.Create(InnerCode);
      try
        SubParser := TAetherParser.Create(SubLexer);
        try
          InnerExpr := SubParser.ParseExpr;
          InnerExpr.Line := ALine;
          InnerExpr.Col := ACol;
        finally
          SubParser.Free;
        end;
      finally
        SubLexer.Free;
      end;

      CallExpr := TASTCallExpr.Create(ALine, ACol, '__InterpToStr');
      CallExpr.Args.Add(TASTCallArg.Create(ALine, ACol, owNone, InnerExpr));
      AppendPart(CallExpr);
    end
    else
    begin
      LiteralBuf := LiteralBuf + RawStr[I];
      Inc(I);
    end;
  end;

  if LiteralBuf <> '' then
    AppendPart(TASTLiteralExpr.Create(ALine, ACol, lkString, LiteralBuf));

  if not Assigned(Result) then
    Result := TASTLiteralExpr.Create(ALine, ACol, lkString, '');
end;

function TAetherParser.ParsePrimaryExpr: TASTExpr;
var
  Id: string;
  Line, Col: Integer;
  CallExpr: TASTCallExpr;
  ArgExpr: TASTExpr;
  ArgOwn: TOwnershipKind;
  IdxExpr: TASTIndexExpr;
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

  if Check(tokInterpStringLiteral) then
  begin
    Result := ParseInterpolatedString(FCurTok.Value, Line, Col);
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

  if Match(tokNil) then
    Exit(TASTLiteralExpr.Create(Line, Col, lkNil, 'nil'));

  // Literal de Conjunto [elem1, elem2, ...] ou []
  if Match(tokLBracket) then
  begin
    Result := TASTSetLiteralExpr.Create(Line, Col);
    if not Check(tokRBracket) then
    begin
      repeat
        TASTSetLiteralExpr(Result).Elements.Add(ParseExpr);
      until not Match(tokComma);
    end;
    Expect(tokRBracket, 'Esperado "]" ao fechar literal de conjunto');
    Exit;
  end;

  // Parenteses (Expr)
  if Match(tokLParen) then
  begin
    Result := ParseExpr;
    Expect(tokRParen, 'Esperado ")" para fechar expressao');
    Exit;
  end;

  // Identificador ou Chamada de Funcao ou Acesso a Membro / Indexacao / Desreferencia
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

    // Acesso sequencial: membro (obj.campo / UFCS), indexacao (arr[i]) ou desreferencia (ptr^)
    while Check(tokDot) or Check(tokLBracket) or Check(tokCaret) do
    begin
      if Match(tokCaret) then
      begin
        Result := TASTUnaryExpr.Create(Line, Col, '^', Result);
      end
      else if Match(tokDot) then
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
      end
      else if Match(tokLBracket) then
      begin
        IdxExpr := TASTIndexExpr.Create(Line, Col, Result);
        if not Check(tokRBracket) then
        begin
          repeat
            IdxExpr.Indices.Add(ParseExpr);
          until not Match(tokComma);
        end;
        Expect(tokRBracket, 'Esperado "]" ao fechar indexador de array');
        Result := IdxExpr;
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
  else if Match(tokAt) then
    Result := TASTUnaryExpr.Create(Line, Col, '@', ParseUnaryExpr())
  else if Match(tokAwait) then
    Result := TASTAwaitExpr.Create(Line, Col, ParseUnaryExpr())
  else if Match(tokSpawn) then
    Result := TASTSpawnExpr.Create(Line, Col, ParseUnaryExpr())
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
  while Check(tokStar) or Check(tokSlash) or Check(tokMod) or Check(tokShl) or Check(tokShr) do
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
        Check(tokLessEqual) or Check(tokGreater) or Check(tokGreaterEqual) or Check(tokIn) do
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
  while Check(tokAnd) or Check(tokOr) or Check(tokXor) or Check(tokImplies) do
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
  ModName, ModDoc: string;
  MLine, MCol: Integer;
  PendingAttrs: TParsedAttributes;
begin
  MLine := FCurTok.Line;
  MCol := FCurTok.Col;
  ModDoc := FCurTok.DocComment;
  Expect(tokModule, 'Todo arquivo Aether deve iniciar com "module <Nome>;"');
  ModName := Expect(tokIdentifier, 'Esperado nome do modulo').Value;
  Expect(tokSemicolon, 'Esperado ";" apos nome do modulo');

  Result := TASTModule.Create(MLine, MCol, ModName);
  Result.DocComment := ModDoc;
  InitAttributes(PendingAttrs);
  try
    // Imports
    while Check(tokImport) do
      ParseImport(Result);

    // Tipos, Traits, Impls, Funcoes e Programa Principal
    while not Check(tokEOF) do
    begin
      while Check(tokLBracket) or Check(tokAt) do
        ParseAttribute(PendingAttrs);

      if Check(tokConst) then
      begin
        ParseConstSection(Result, PendingAttrs);
      end
      else if Check(tokType) then
      begin
        ParseTypeSection(Result, PendingAttrs);
      end
      else if Check(tokTrait) then
      begin
        Result.Traits.Add(ParseTraitDecl('', FCurTok.Line, FCurTok.Col));
        ClearAttributes(PendingAttrs);
      end
      else if Check(tokImpl) then
      begin
        Result.Impls.Add(ParseImplDecl);
        ClearAttributes(PendingAttrs);
      end
      else if Check(tokFunction) or Check(tokExtern) or Check(tokAsync) or Check(tokExport) then
      begin
        Result.Functions.Add(ParseFunction(False, PendingAttrs));
        ClearAttributes(PendingAttrs);
      end
      else if Check(tokProgram) then
      begin
        Result.ProgramBlock := ParseProgramBlock;
        Break;
      end
      else
        raise EAetherParserError.Create(Format('Declaracao inesperada no modulo: "%s"', [FCurTok.Value]), FCurTok.Line, FCurTok.Col);
    end;

    // Expande derivacoes automaticas (Debug, JSON, Clone, Equals)
    ExpandDerives(Result);
  except
    FreeAttributes(PendingAttrs);
    Result.Free;
    raise;
  end;
  FreeAttributes(PendingAttrs);
end;

end.
