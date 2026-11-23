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
    HasVis: Boolean;
    IsPublic: Boolean;
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
    function ParseFunction(IsSignatureOnly: Boolean; const Attrs: TParsedAttributes; AllowInterfaceContracts: Boolean = False): TASTFunction; overload;
    function ParseFunction(IsSignatureOnly: Boolean = False; AllowInterfaceContracts: Boolean = False): TASTFunction; overload;
    function ParseProgramBlock(const AModuleName: string): TASTProgramBlock;
    procedure ParseVarSection(ALocalVars: TASTNodeList; ForcePublic: Boolean = True; HasExplicitVis: Boolean = False);

    function IsShorthandMatchCaseStart(AllowBareLet: Boolean = False): Boolean;
    function ParseSingleMatchPatternItem: string;
    function ParseMatchCaseHead: TASTMatchCase;

    function ParseStatement: TASTStmt;
    function ParseInlineVarStmt: TASTVarDeclStmt;
    function ParseIfStmt: TASTIfStmt;
    function ParseWhileStmt: TASTWhileStmt;
    function ParseForStmt: TASTForStmt;
    function ParseRepeatStmt: TASTRepeatStmt;
    function ParseMatchStmt: TASTMatchStmt;
    function ParseMatchExpr: TASTMatchExpr;
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

  function ConsumeGenericClose: Boolean;
  begin
    if Match(tokGreater) then
      Exit(True);
    if Check(tokShr) then
    begin
      FCurTok := CreateToken(tokGreater, '>', FCurTok.Line, FCurTok.Col + 1);
      Exit(True);
    end;
    Result := False;
  end;
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
  while Match(tokDot) do
    BaseType := Expect(tokIdentifier, 'Esperado identificador de tipo apos "."').Value;
  if Match(tokLess) then
  begin
    BaseType := BaseType + '<' + ParseTypeRef();
    while Match(tokComma) do
      BaseType := BaseType + ', ' + ParseTypeRef();
    if not ConsumeGenericClose then
      Expect(tokGreater, 'Esperado ">" no fechamento do tipo generico');
    BaseType := BaseType + '>';
  end;
  Result := BaseType;
end;

procedure TAetherParser.ParseImport(AModule: TASTModule);
var
  ImportName, AliasName: string;
  IsPascal, IsC, IsLink: Boolean;
begin
  Expect(tokImport);
  IsPascal := False;
  IsC := False;
  IsLink := False;
  AliasName := '';

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
    if Match(tokAs) then
    begin
      AliasName := Expect(tokIdentifier, 'Esperado alias apos "as"').Value;
      AModule.ImportAliases.Values[AliasName] := ImportName;
    end;
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
  FHasVis, FIsPub: Boolean;
begin
  Expect(tokRecord);
  Result := TASTRecordDecl.Create(ALine, ACol, AName);
  try
    while not Check(tokEnd) and not Check(tokEOF) do
    begin
      FHasVis := False;
      FIsPub := True;
      if Match(tokPub) then
      begin
        FHasVis := True;
        FIsPub := True;
      end
      else if Match(tokPriv) then
      begin
        FHasVis := True;
        FIsPub := False;
      end;

      FLine := FCurTok.Line;
      FCol := FCurTok.Col;
      FDoc := FCurTok.DocComment;
      FieldName := Expect(tokIdentifier, 'Esperado nome do campo do record').Value;
      Expect(tokColon, 'Esperado ":" apos nome do campo');
      FieldType := ParseTypeRef;
      Expect(tokSemicolon, 'Esperado ";" apos definicao do campo');
      FieldNode := TASTRecordField.Create(FLine, FCol, FieldName, FieldType);
      FieldNode.DocComment := FDoc;
      FieldNode.HasExplicitVis := FHasVis;
      FieldNode.IsPublic := FIsPub;
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
  Attrs.HasVis := False;
  Attrs.IsPublic := True;
end;

procedure ClearAttributes(var Attrs: TParsedAttributes);
begin
  if Assigned(Attrs.Derives) then
    Attrs.Derives.Clear;
  Attrs.CfgCondition := '';
  Attrs.InlineMode := '';
  Attrs.IsCold := False;
  Attrs.HasVis := False;
  Attrs.IsPublic := True;
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
  if Src.HasVis then
  begin
    Dst.HasVis := True;
    Dst.IsPublic := Src.IsPublic;
  end;
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
  SecHasVis, SecIsPub, ItemHasVis, ItemIsPub: Boolean;
begin
  Expect(tokConst);
  SecHasVis := SectionAttrs.HasVis;
  SecIsPub := SectionAttrs.IsPublic;
  InitAttributes(CurrentAttrs);
  try
    while not Check(tokEOF) do
    begin
      while Check(tokLBracket) or Check(tokAt) do
        ParseAttribute(CurrentAttrs);

      ItemHasVis := SecHasVis;
      ItemIsPub := SecIsPub;
      if (Check(tokPub) or Check(tokPriv)) and (FPeekTok.Kind in [tokIdentifier, tokLBracket, tokAt]) then
      begin
        if Match(tokPub) then
        begin
          ItemHasVis := True;
          ItemIsPub := True;
          AModule.HasExplicitPub := True;
        end
        else if Match(tokPriv) then
        begin
          ItemHasVis := True;
          ItemIsPub := False;
          AModule.HasExplicitPub := True;
        end;
      end;

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
        ConstNode.HasExplicitVis := ItemHasVis;
        ConstNode.IsPublic := ItemIsPub;
        AModule.Constants.Add(ConstNode);
        ClearAttributes(SectionAttrs);
      end
      else
        Break;
    end;
    ClearAttributes(SectionAttrs);
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
  TypeName, TypeDoc, EffectiveCfg, LowBound, HighBound, BaseType, KeyType, ValType, AliasTarget: string;
  TLine, TCol: Integer;
  RecDecl: TASTRecordDecl;
  EnumDecl: TASTEnumDecl;
  TraitDecl: TASTTraitDecl;
  ArrDecl: TASTArrayDecl;
  SetDecl: TASTSetDecl;
  SubDecl: TASTSubrangeDecl;
  MapDecl: TASTMapDecl;
  AliasDecl: TASTTypeAliasDecl;
  CurrentAttrs: TParsedAttributes;
  SecHasVis, SecIsPub, ItemHasVis, ItemIsPub: Boolean;
begin
  Expect(tokType);
  SecHasVis := SectionAttrs.HasVis;
  SecIsPub := SectionAttrs.IsPublic;
  InitAttributes(CurrentAttrs);
  try
    while not Check(tokEOF) do
    begin
      ClearAttributes(CurrentAttrs);
      while Check(tokLBracket) or Check(tokAt) do
        ParseAttribute(CurrentAttrs);

      ItemHasVis := SecHasVis;
      ItemIsPub := SecIsPub;
      if (Check(tokPub) or Check(tokPriv)) and (FPeekTok.Kind in [tokIdentifier, tokLBracket, tokAt]) then
      begin
        if Match(tokPub) then
        begin
          ItemHasVis := True;
          ItemIsPub := True;
          AModule.HasExplicitPub := True;
        end
        else if Match(tokPriv) then
        begin
          ItemHasVis := True;
          ItemIsPub := False;
          AModule.HasExplicitPub := True;
        end;
      end;

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
          RecDecl.HasExplicitVis := ItemHasVis;
          RecDecl.IsPublic := ItemIsPub;
          AModule.Types.Add(RecDecl);
        end
        else if Check(tokEnum) then
        begin
          EnumDecl := ParseEnumDecl(TypeName, TLine, TCol);
          EnumDecl.DocComment := TypeDoc;
          EnumDecl.Derives.AddStrings(CurrentAttrs.Derives);
          EnumDecl.Derives.AddStrings(SectionAttrs.Derives);
          EnumDecl.CfgCondition := EffectiveCfg;
          EnumDecl.HasExplicitVis := ItemHasVis;
          EnumDecl.IsPublic := ItemIsPub;
          AModule.Types.Add(EnumDecl);
        end
        else if Check(tokTrait) then
        begin
          TraitDecl := ParseTraitDecl(TypeName, TLine, TCol);
          TraitDecl.DocComment := TypeDoc;
          TraitDecl.HasExplicitVis := ItemHasVis;
          TraitDecl.IsPublic := ItemIsPub;
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
            ArrDecl.HasExplicitVis := ItemHasVis;
            ArrDecl.IsPublic := ItemIsPub;
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
            ArrDecl.HasExplicitVis := ItemHasVis;
            ArrDecl.IsPublic := ItemIsPub;
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
          SetDecl.HasExplicitVis := ItemHasVis;
          SetDecl.IsPublic := ItemIsPub;
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
          MapDecl.HasExplicitVis := ItemHasVis;
          MapDecl.IsPublic := ItemIsPub;
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
          SubDecl.HasExplicitVis := ItemHasVis;
          SubDecl.IsPublic := ItemIsPub;
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
          EnumDecl.HasExplicitVis := ItemHasVis;
          EnumDecl.IsPublic := ItemIsPub;
          AModule.Types.Add(EnumDecl);
        end
        else
        begin
          AliasTarget := ParseTypeRef();
          AliasDecl := TASTTypeAliasDecl.Create(TLine, TCol, TypeName, AliasTarget);
          AliasDecl.DocComment := TypeDoc;
          AliasDecl.CfgCondition := EffectiveCfg;
          AliasDecl.HasExplicitVis := ItemHasVis;
          AliasDecl.IsPublic := ItemIsPub;
          AModule.Types.Add(AliasDecl);
        end;

        ClearAttributes(SectionAttrs);
        Expect(tokSemicolon, 'Esperado ";" apos declaracao de tipo');
      end
      else
      begin
        if ItemHasVis then
        begin
          SectionAttrs.HasVis := ItemHasVis;
          SectionAttrs.IsPublic := ItemIsPub;
        end;
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
      if Check(tokFunction) or Check(tokProcedure) or Check(tokAsync) then
        Result.Methods.Add(ParseFunction(True))
      else
        raise EAetherParserError.Create('Esperado "function" ou "procedure" na declaracao da trait', FCurTok.Line, FCurTok.Col);
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
  FirstName, TraitName, TargetName: string;
  ILine, ICol, J: Integer;
  FuncNode: TASTFunction;
  MHasVis, MIsPub: Boolean;
begin
  ILine := FCurTok.Line;
  ICol := FCurTok.Col;
  Expect(tokImpl);
  FirstName := Expect(tokIdentifier, 'Esperado nome da trait ou tipo apos "impl"').Value;
  if Match(tokFor) then
  begin
    TraitName := FirstName;
    TargetName := Expect(tokIdentifier, 'Esperado nome do tipo apos "for"').Value;
  end
  else
  begin
    TraitName := '';
    TargetName := FirstName;
  end;

  Result := TASTImplDecl.Create(ILine, ICol, TraitName, TargetName);
  try
    while not Check(tokEnd) and not Check(tokEOF) do
    begin
      MHasVis := False;
      MIsPub := True;
      if Match(tokPub) then
      begin
        MHasVis := True;
        MIsPub := True;
      end
      else if Match(tokPriv) then
      begin
        MHasVis := True;
        MIsPub := False;
      end;

      if Check(tokFunction) or Check(tokProcedure) or Check(tokAsync) then
      begin
        FuncNode := ParseFunction(False);
        if MHasVis then
        begin
          FuncNode.HasExplicitVis := True;
          FuncNode.IsPublic := MIsPub;
        end;
        for J := 0 to FuncNode.Params.Count - 1 do
        begin
          if SameText(TASTParam(FuncNode.Params[J]).TypeName, 'Self') then
            TASTParam(FuncNode.Params[J]).TypeName := TargetName;
        end;
        if SameText(FuncNode.ReturnType, 'Self') then
          FuncNode.ReturnType := TargetName
        else if Pos('Self', FuncNode.ReturnType) > 0 then
          FuncNode.ReturnType := StringReplace(FuncNode.ReturnType, '<Self>', '<' + TargetName + '>', [rfReplaceAll, rfIgnoreCase]);
        Result.Methods.Add(FuncNode);
      end
      else
        raise EAetherParserError.Create('Esperado "function" ou "procedure" no bloco impl', FCurTok.Line, FCurTok.Col);
    end;
    Expect(tokEnd, 'Esperado "end" no fechamento do bloco impl');
    Expect(tokSemicolon, 'Esperado ";" apos "end" do bloco impl');
  except
    Result.Free;
    raise;
  end;
end;

procedure TAetherParser.ParseVarSection(ALocalVars: TASTNodeList; ForcePublic: Boolean; HasExplicitVis: Boolean);
var
  VarNames: TStringList;
  VarType: string;
  InitExpr, ClonedInit: TASTExpr;
  VLine, VCol, I: Integer;
  IsMut: Boolean;
  VD: TASTVarDecl;
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
        VD := TASTVarDecl.Create(VLine, VCol, VarNames[I], VarType, ClonedInit, IsMut);
        VD.HasExplicitVis := HasExplicitVis;
        VD.IsPublic := ForcePublic;
        ALocalVars.Add(VD);
      end;
    end;
  finally
    VarNames.Free;
  end;
end;

function TAetherParser.ParseFunction(IsSignatureOnly: Boolean; const Attrs: TParsedAttributes; AllowInterfaceContracts: Boolean): TASTFunction;
var
  FuncName, ReturnType, ParamType, FDoc, CloseName: string;
  FLine, FCol, I, PLine, PCol: Integer;
  Ownership: TOwnershipKind;
  IsProc, IsExt, IsAsyncFunc, IsExportFunc, HasContracts: Boolean;
  FHasVis, FIsPub: Boolean;
  ExtLib, ExtAbi, ExportAbi: string;
  ParamNames: TStringList;

  procedure ParseOptionalContracts;
    function AtContractBoundary: Boolean;
    begin
      Result := Check(tokVar) or Check(tokLet) or Check(tokBegin) or Check(tokEnd) or
                Check(tokFunction) or Check(tokProcedure) or Check(tokType) or Check(tokConst) or
                Check(tokTrait) or Check(tokImplementation) or Check(tokProgram) or Check(tokExtern) or
                Check(tokExport) or Check(tokAsync) or Check(tokPub) or Check(tokPriv) or
                Check(tokImpl) or Check(tokSemicolon) or Check(tokAt) or Check(tokLBracket) or
                Check(tokEOF);
    end;
  begin
    if Match(tokContract) or Check(tokRequire) or Check(tokEnsure) then
    begin
      if Match(tokRequire) then
      begin
        while (not Check(tokEnsure)) and (not AtContractBoundary) do
        begin
          Result.Requires.Add(ParseExpr);
          Expect(tokSemicolon, 'Esperado ";" apos expressao de require');
        end;
      end;

      if Match(tokEnsure) then
      begin
        while not AtContractBoundary do
        begin
          Result.Ensures.Add(ParseExpr);
          Expect(tokSemicolon, 'Esperado ";" apos expressao de ensure');
        end;
      end;
    end;
  end;
begin
  FLine := FCurTok.Line;
  FCol := FCurTok.Col;
  FDoc := FCurTok.DocComment;
  IsExt := False;
  IsAsyncFunc := False;
  IsExportFunc := False;
  FHasVis := Attrs.HasVis;
  FIsPub := Attrs.IsPublic;
  ExtLib := '';
  ExtAbi := 'c';
  ExportAbi := 'cdecl';

  while Check(tokAsync) or Check(tokExtern) or Check(tokExport) or Check(tokPub) or Check(tokPriv) do
  begin
    if Match(tokPub) then
    begin
      FHasVis := True;
      FIsPub := True;
      if (FDoc = '') and (FCurTok.DocComment <> '') then
        FDoc := FCurTok.DocComment;
    end
    else if Match(tokPriv) then
    begin
      FHasVis := True;
      FIsPub := False;
      if (FDoc = '') and (FCurTok.DocComment <> '') then
        FDoc := FCurTok.DocComment;
    end
    else if Match(tokAsync) then
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

  IsProc := Match(tokProcedure);
  if not IsProc then
    Expect(tokFunction, 'Esperado "function" ou "procedure"');
  FuncName := Expect(tokIdentifier, 'Esperado nome da rotina').Value;

  Result := TASTFunction.Create(FLine, FCol, FuncName, '');
  Result.IsProcedure := IsProc;
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
  Result.HasExplicitVis := FHasVis;
  Result.IsPublic := FIsPub;
  ParamNames := TStringList.Create;
  try
    // Parametro generico com bound opcional: function Imprimir<T: Printable>(...)
    if Match(tokLess) then
    begin
      Result.GenericParam := Expect(tokIdentifier, 'Esperado nome do parametro generico').Value;
      if Match(tokColon) then
        Result.TraitBound := Expect(tokIdentifier, 'Esperado nome da trait no bound').Value;
      Expect(tokGreater, 'Esperado ">" no fechamento do parametro generico');
    end;

    // Parenteses opcionais quando nao ha parametros
    if Match(tokLParen) then
    begin
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

          ParamNames.Clear;
          PLine := FCurTok.Line;
          PCol := FCurTok.Col;
          ParamNames.Add(Expect(tokIdentifier, 'Esperado nome do parametro').Value);
          while Match(tokComma) do
            ParamNames.Add(Expect(tokIdentifier, 'Esperado nome do parametro apos ","').Value);

          if Match(tokColon) then
            ParamType := ParseTypeRef
          else if (ParamNames.Count = 1) and SameText(ParamNames[0], 'self') then
            ParamType := 'Self'
          else
            raise EAetherParserError.Create('Esperado ":" apos nome do parametro', FCurTok.Line, FCurTok.Col);

          for I := 0 to ParamNames.Count - 1 do
            Result.Params.Add(TASTParam.Create(PLine, PCol, ParamNames[I], ParamType, Ownership));
        until (not Match(tokSemicolon)) and (not Match(tokComma));
      end;
      Expect(tokRParen, 'Esperado ")" no fechamento dos parametros');
    end;

    // Cláusula de retorno (hard cutover: procedure sem retorno; function obriga "return <Tipo>")
    if IsProc then
    begin
      if Check(tokReturn) or Check(tokColon) then
        raise EAetherParserError.Create('Procedures nao possuem tipo de retorno; use "function ... return <Tipo>"', FCurTok.Line, FCurTok.Col);
      Result.ReturnType := 'Void';
    end
    else
    begin
      if Check(tokColon) then
        raise EAetherParserError.Create('Sintaxe legada ": Tipo" removida. Use "return <Tipo>" na declaracao de function', FCurTok.Line, FCurTok.Col);
      Expect(tokReturn, 'Esperado "return <Tipo>" apos parametros da function');
      ReturnType := ParseTypeRef;
      if SameText(ReturnType, 'Void') then
        raise EAetherParserError.Create('Functions nao podem retornar "Void". Use "procedure"', FCurTok.Line, FCurTok.Col);
      Result.ReturnType := ReturnType;
    end;

    // Modificadores opcionais apos retorno/assinatura (na mesma linha): export; cdecl; stdcall;
    while Check(tokExport) or Check(tokCdecl) or
          (Check(tokIdentifier) and (SameText(FCurTok.Value, 'export') or SameText(FCurTok.Value, 'cdecl') or SameText(FCurTok.Value, 'stdcall'))) or
          (Check(tokSemicolon) and (FPeekTok.Line = FCurTok.Line) and ((FPeekTok.Kind in [tokExport, tokCdecl]) or
            ((FPeekTok.Kind = tokIdentifier) and (SameText(FPeekTok.Value, 'export') or SameText(FPeekTok.Value, 'cdecl') or SameText(FPeekTok.Value, 'stdcall'))))) do
    begin
      if Match(tokSemicolon) then
        Continue
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

    // Se for extern, nao possui "is" nem corpo (pode ter contract antes de ";")
    if IsExt then
    begin
      if Check(tokContract) or Check(tokRequire) or Check(tokEnsure) then
        ParseOptionalContracts;
      if Check(tokSemicolon) then
        Match(tokSemicolon);
      Exit;
    end;

    // Se for assinatura (trait ou secao interface de unit)
    if IsSignatureOnly then
    begin
      if AllowInterfaceContracts then
      begin
        HasContracts := Check(tokContract) or Check(tokRequire) or Check(tokEnsure);
        if HasContracts then
          ParseOptionalContracts
        else
        begin
          Expect(tokSemicolon, 'Esperado ";" apos assinatura na secao interface');
          if Check(tokContract) or Check(tokRequire) or Check(tokEnsure) then
            ParseOptionalContracts;
        end;
      end
      else
        Expect(tokSemicolon, 'Esperado ";" apos assinatura do metodo da trait');
      Exit;
    end;

    // Definicao completa estilo Ada: ... is [contract] [var/let] begin ... end Nome;
    Expect(tokIs, Format('Esperado "is" na definicao de "%s"', [FuncName]));

    ParseOptionalContracts;

    // Variaveis Locais
    while Check(tokVar) or Check(tokLet) do
      ParseVarSection(Result.LocalVars);

    // Corpo begin...end <Nome>;
    Expect(tokBegin, 'Esperado "begin" para iniciar o corpo da rotina');
    while not Check(tokEnd) and not Check(tokEOF) do
    begin
      Result.Body.Add(ParseStatement);
      Expect(tokSemicolon, 'Esperado ";" apos instrucao');
    end;
    Expect(tokEnd, Format('Esperado "end %s;" para fechar a rotina', [FuncName]));
    CloseName := Expect(tokIdentifier, Format('Esperado nome "%s" apos "end"', [FuncName])).Value;
    if not SameText(CloseName, FuncName) then
      raise EAetherParserError.Create(Format('Nome de fechamento divergente: esperado "end %s;", mas encontrado "end %s"', [FuncName, CloseName]), FCurTok.Line, FCurTok.Col);
    Expect(tokSemicolon, Format('Esperado ";" apos "end %s"', [FuncName]));
  except
    ParamNames.Free;
    Result.Free;
    raise;
  end;
  ParamNames.Free;
end;

function TAetherParser.ParseFunction(IsSignatureOnly: Boolean; AllowInterfaceContracts: Boolean): TASTFunction;
var
  EmptyAttrs: TParsedAttributes;
begin
  InitAttributes(EmptyAttrs);
  try
    Result := ParseFunction(IsSignatureOnly, EmptyAttrs, AllowInterfaceContracts);
  finally
    FreeAttributes(EmptyAttrs);
  end;
end;

function TAetherParser.ParseProgramBlock(const AModuleName: string): TASTProgramBlock;
var
  ProgName, CloseMod: string;
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
    Expect(tokEnd, Format('Esperado "end %s." para finalizar o programa', [AModuleName]));
    CloseMod := Expect(tokIdentifier, Format('Esperado nome do modulo "%s" apos "end"', [AModuleName])).Value;
    if not SameText(CloseMod, AModuleName) then
      raise EAetherParserError.Create(Format('Fechamento de modulo divergente: esperado "end %s.", mas encontrado "end %s."', [AModuleName, CloseMod]), FCurTok.Line, FCurTok.Col);
    Expect(tokDot, Format('Esperado "." apos "end %s"', [AModuleName]));
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
  VarName, ValVarName: string;
  StartExpr, EndExpr, ColExpr: TASTExpr;
  FLine, FCol: Integer;
  IsDownTo: Boolean;
begin
  FLine := FCurTok.Line;
  FCol := FCurTok.Col;
  Expect(tokFor);
  VarName := Expect(tokIdentifier, 'Esperado nome da variavel contadora do for').Value;
  ValVarName := '';
  if Match(tokComma) then
    ValVarName := Expect(tokIdentifier, 'Esperado identificador de valor apos "," no laco for..in').Value;

  if Match(tokIn) then
  begin
    ColExpr := ParseExpr;
    Expect(tokDo, 'Esperado "do" apos colecao do laco for..in');
    Result := TASTForStmt.Create(FLine, FCol, VarName, nil, nil, False);
    Result.ValVarName := ValVarName;
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

  if ValVarName <> '' then
    raise EAetherParserError.Create('Esperado "in" apos par chave, valor no laco for..in', FCurTok.Line, FCurTok.Col);

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

function TAetherParser.IsShorthandMatchCaseStart(AllowBareLet: Boolean): Boolean;
begin
  if Check(tokCase) then Exit(True);
  if Check(tokEnd) or Check(tokEOF) then Exit(False);
  if AllowBareLet and Check(tokLet) then Exit(True);
  if Check(tokUnderscore) or Check(tokIntLiteral) or Check(tokStringLiteral) or
     Check(tokCharLiteral) or Check(tokTrue) or Check(tokFalse) then
    Exit(True);
  if Check(tokMinus) and (FPeekTok.Kind = tokIntLiteral) then
    Exit(True);
  if Check(tokIdentifier) and
     ((FPeekTok.Kind = tokColon) or (FPeekTok.Kind = tokFatArrow) or (FPeekTok.Kind = tokComma) or
      (FPeekTok.Kind = tokDot) or (FPeekTok.Kind = tokLParen) or (FPeekTok.Kind = tokIf) or
      ((FPeekTok.Kind = tokIdentifier) and SameText(FPeekTok.Value, 'when'))) then
    Exit(True);
  Result := False;
end;

function TAetherParser.ParseSingleMatchPatternItem: string;
var
  HiVal: string;
begin
  if Match(tokUnderscore) then
    Result := '_'
  else if Check(tokIntLiteral) then
  begin
    Result := FCurTok.Value;
    Advance;
  end
  else if Match(tokMinus) then
    Result := '-' + Expect(tokIntLiteral, 'Esperado literal inteiro apos "-" no case').Value
  else if Check(tokStringLiteral) then
  begin
    Result := '"' + FCurTok.Value + '"';
    Advance;
  end
  else if Check(tokCharLiteral) then
  begin
    Result := '''' + FCurTok.Value + '''';
    Advance;
  end
  else if Match(tokTrue) then
    Result := 'true'
  else if Match(tokFalse) then
    Result := 'false'
  else
  begin
    Result := Expect(tokIdentifier, 'Esperado padrao no case').Value;
    if Match(tokDot) then
      Result := Result + '.' + Expect(tokIdentifier).Value;
  end;

  if Match(tokDotDot) then
  begin
    if Check(tokIntLiteral) then
    begin
      HiVal := FCurTok.Value;
      Advance;
    end
    else if Match(tokMinus) then
      HiVal := '-' + Expect(tokIntLiteral, 'Esperado literal inteiro apos "-" na faixa').Value
    else if Check(tokCharLiteral) then
    begin
      HiVal := '''' + FCurTok.Value + '''';
      Advance;
    end
    else
    begin
      HiVal := Expect(tokIdentifier, 'Esperado limite superior da faixa no case').Value;
      if Match(tokDot) then
        HiVal := HiVal + '.' + Expect(tokIdentifier).Value;
    end;
    Result := Result + '..' + HiVal;
  end;
end;

function TAetherParser.ParseMatchCaseHead: TASTMatchCase;
var
  PatternNode: TASTPattern;
  PatVal, SubVal: string;
  IsLet: Boolean;
  PLine, PCol: Integer;
begin
  PLine := FCurTok.Line;
  PCol := FCurTok.Col;
  SubVal := '';
  IsLet := False;

  if Match(tokLet) then
  begin
    PatVal := '_';
    SubVal := Expect(tokIdentifier, 'Esperado identificador apos "let" no padrao do case').Value;
    IsLet := True;
    PatternNode := TASTPattern.Create(PLine, PCol, PatVal, SubVal, IsLet);
  end
  else
  begin
    PatVal := ParseSingleMatchPatternItem;
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
    while Match(tokComma) do
      PatternNode.Items.Add(ParseSingleMatchPatternItem);
  end;

  Result := TASTMatchCase.Create(PLine, PCol, PatternNode);
  try
    if Match(tokIf) or (Check(tokIdentifier) and SameText(FCurTok.Value, 'when')) then
    begin
      if Check(tokIdentifier) and SameText(FCurTok.Value, 'when') then
        Advance;
      Result.Guard := ParseExpr;
    end;

    if not Match(tokColon) and not Match(tokFatArrow) then
      Expect(tokColon, 'Esperado ":" ou "=>" apos padrao do case');
  except
    Result.Free;
    raise;
  end;
end;

function TAetherParser.ParseMatchStmt: TASTMatchStmt;
var
  MatchExpr: TASTExpr;
  CaseNode: TASTMatchCase;
  UseCaseKeyword: Boolean;
  MLine, MCol: Integer;
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
    while (UseCaseKeyword and Match(tokCase)) or ((not UseCaseKeyword) and IsShorthandMatchCaseStart(False)) do
    begin
      CaseNode := ParseMatchCaseHead;
      Result.Cases.Add(CaseNode);

      while ((UseCaseKeyword and not Check(tokCase)) or ((not UseCaseKeyword) and not IsShorthandMatchCaseStart(False))) and
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

function TAetherParser.ParseMatchExpr: TASTMatchExpr;
var
  TargetExpr: TASTExpr;
  CaseNode: TASTMatchCase;
  UseCaseKeyword: Boolean;
  MLine, MCol: Integer;
begin
  MLine := FCurTok.Line;
  MCol := FCurTok.Col;
  Expect(tokMatch);
  TargetExpr := ParseExpr;
  if not Match(tokDo) and not Match(tokWith) then
    Expect(tokDo, 'Esperado "do" ou "with" apos expressao do match');

  Result := TASTMatchExpr.Create(MLine, MCol, TargetExpr);
  try
    UseCaseKeyword := Check(tokCase);
    while Check(tokCase) or ((not UseCaseKeyword) and IsShorthandMatchCaseStart(True)) do
    begin
      if Check(tokCase) then
      begin
        UseCaseKeyword := True;
        Advance;
      end;
      CaseNode := ParseMatchCaseHead;
      Result.Cases.Add(CaseNode);
      CaseNode.ValueExpr := ParseExpr;
      if not Match(tokSemicolon) then
        Match(tokComma);
    end;
    Expect(tokEnd, 'Esperado "end" no fechamento da expressao match');
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

function TAetherParser.ParseInlineVarStmt: TASTVarDeclStmt;
var
  VarNames: TStringList;
  VarType: string;
  InitExpr, ClonedInit: TASTExpr;
  VLine, VCol, I: Integer;
  IsMut: Boolean;
begin
  VLine := FCurTok.Line;
  VCol := FCurTok.Col;
  IsMut := Check(tokVar);
  Advance; // consome 'var' ou 'let'

  Result := TASTVarDeclStmt.Create(VLine, VCol);
  VarNames := TStringList.Create;
  try
    try
      VarNames.Add(Expect(tokIdentifier, 'Esperado nome da variavel apos "var" ou "let"').Value);
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

      for I := 0 to VarNames.Count - 1 do
      begin
        if I = 0 then
          ClonedInit := InitExpr
        else if Assigned(InitExpr) then
          ClonedInit := TASTExpr(CloneASTNode(InitExpr))
        else
          ClonedInit := nil;
        Result.Decls.Add(TASTVarDecl.Create(VLine, VCol, VarNames[I], VarType, ClonedInit, IsMut));
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    VarNames.Free;
  end;
end;

function TAetherParser.ParseAssignOrCallStmt: TASTStmt;
var
  Expr: TASTExpr;
  TargetExpr: TASTExpr;
  OpStr: string;
begin
  Expr := ParseExpr;
  if Match(tokAssign) then
  begin
    TargetExpr := Expr;
    Result := TASTAssignStmt.Create(TargetExpr.Line, TargetExpr.Col, TargetExpr, ParseExpr);
  end
  else if Check(tokPlusAssign) or Check(tokMinusAssign) or Check(tokStarAssign) or
          Check(tokSlashAssign) or Check(tokModAssign) or Check(tokBitAndAssign) or
          Check(tokBitOrAssign) or Check(tokBitXorAssign) or Check(tokShlAssign) or
          Check(tokShrAssign) then
  begin
    if Check(tokPlusAssign) then OpStr := '+'
    else if Check(tokMinusAssign) then OpStr := '-'
    else if Check(tokStarAssign) then OpStr := '*'
    else if Check(tokSlashAssign) then OpStr := '/'
    else if Check(tokModAssign) then OpStr := 'mod'
    else if Check(tokBitAndAssign) then OpStr := 'and'
    else if Check(tokBitOrAssign) then OpStr := 'or'
    else if Check(tokBitXorAssign) then OpStr := 'xor'
    else if Check(tokShlAssign) then OpStr := 'shl'
    else OpStr := 'shr';
    Advance;
    TargetExpr := Expr;
    Result := TASTAssignStmt.Create(TargetExpr.Line, TargetExpr.Col, TargetExpr,
      TASTBinaryExpr.Create(TargetExpr.Line, TargetExpr.Col, TASTExpr(CloneASTNode(TargetExpr)), OpStr, ParseExpr));
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
  if Check(tokVar) or Check(tokLet) then
    Result := ParseInlineVarStmt
  else if Check(tokIf) then
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
  Id, ArgFieldName: string;
  Line, Col: Integer;
  CallExpr: TASTCallExpr;
  ArgExpr, CondExpr, ThenExpr, ElseExpr: TASTExpr;
  ArgOwn: TOwnershipKind;
  IdxExpr: TASTIndexExpr;
  CallArg: TASTCallArg;
begin
  Line := FCurTok.Line;
  Col := FCurTok.Col;

  // Expressao condicional inline: if cond then a else b
  if Match(tokIf) then
  begin
    CondExpr := ParseExpr;
    Expect(tokThen, 'Esperado "then" na expressao condicional "if"');
    ThenExpr := ParseExpr;
    Expect(tokElse, 'Esperado "else" na expressao condicional "if"');
    ElseExpr := ParseExpr;
    Exit(TASTIfExpr.Create(Line, Col, CondExpr, ThenExpr, ElseExpr));
  end;

  if Check(tokMatch) then
    Exit(ParseMatchExpr);

  // Literais, arrays/conjuntos, agrupamento por parenteses ou identificadores/chamadas
  if Check(tokIntLiteral) then
  begin
    Result := TASTLiteralExpr.Create(Line, Col, lkInt, FCurTok.Value);
    Advance;
  end
  else if Check(tokFloatLiteral) then
  begin
    Result := TASTLiteralExpr.Create(Line, Col, lkFloat, FCurTok.Value);
    Advance;
  end
  else if Check(tokStringLiteral) then
  begin
    Result := TASTLiteralExpr.Create(Line, Col, lkString, FCurTok.Value);
    Advance;
  end
  else if Check(tokInterpStringLiteral) then
  begin
    Result := ParseInterpolatedString(FCurTok.Value, Line, Col);
    Advance;
  end
  else if Check(tokCharLiteral) then
  begin
    Result := TASTLiteralExpr.Create(Line, Col, lkChar, FCurTok.Value);
    Advance;
  end
  else if Match(tokTrue) then
    Result := TASTLiteralExpr.Create(Line, Col, lkBool, 'true')
  else if Match(tokFalse) then
    Result := TASTLiteralExpr.Create(Line, Col, lkBool, 'false')
  else if Match(tokNil) then
    Result := TASTLiteralExpr.Create(Line, Col, lkNil, 'nil')
  else if Match(tokLBracket) then
  begin
    // Literal de Mapa vazio [:], Mapa [k: v, ...] ou Conjunto/Array [e1, e2, ...] / []
    if Match(tokColon) then
    begin
      Expect(tokRBracket, 'Esperado "]" apos "[:" em literal de mapa vazio');
      Result := TASTMapLiteralExpr.Create(Line, Col);
    end
    else if Check(tokRBracket) then
    begin
      Advance;
      Result := TASTSetLiteralExpr.Create(Line, Col);
    end
    else
    begin
      ArgExpr := ParseExpr;
      if Match(tokColon) then
      begin
        Result := TASTMapLiteralExpr.Create(Line, Col);
        TASTMapLiteralExpr(Result).Keys.Add(ArgExpr);
        TASTMapLiteralExpr(Result).Values.Add(ParseExpr);
        while Match(tokComma) do
        begin
          if Check(tokRBracket) then Break;
          TASTMapLiteralExpr(Result).Keys.Add(ParseExpr);
          Expect(tokColon, 'Esperado ":" entre chave e valor no literal de mapa');
          TASTMapLiteralExpr(Result).Values.Add(ParseExpr);
        end;
        Expect(tokRBracket, 'Esperado "]" ao fechar literal de mapa');
      end
      else
      begin
        Result := TASTSetLiteralExpr.Create(Line, Col);
        TASTSetLiteralExpr(Result).Elements.Add(ArgExpr);
        while Match(tokComma) do
        begin
          if Check(tokRBracket) then Break;
          TASTSetLiteralExpr(Result).Elements.Add(ParseExpr);
        end;
        Expect(tokRBracket, 'Esperado "]" ao fechar literal de conjunto');
      end;
    end;
  end
  else if Match(tokLParen) then
  begin
    // Parenteses (Expr)
    Result := ParseExpr;
    Expect(tokRParen, 'Esperado ")" para fechar expressao');
  end
  else if Check(tokIdentifier) then
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
          ArgFieldName := '';
          if Check(tokIdentifier) and (FPeekTok.Kind = tokColon) then
          begin
            ArgFieldName := FCurTok.Value;
            Advance; // consome nome do campo
            Advance; // consome ':'
          end;

          ArgExpr := ParseExpr;
          CallArg := TASTCallArg.Create(Line, Col, ArgOwn, ArgExpr);
          CallArg.FieldName := ArgFieldName;
          CallExpr.Args.Add(CallArg);
        until not Match(tokComma);
      end;
      Expect(tokRParen, 'Esperado ")" no fechamento dos argumentos');
      Result := CallExpr;
    end
    else
    begin
      Result := TASTIdentifierExpr.Create(Line, Col, Id);
    end;
  end
  else
    raise EAetherParserError.Create(Format('Expressao inesperada: "%s"', [FCurTok.Value]), Line, Col);

  // Acesso sequencial para qualquer expressao primaria: membro (obj.campo / UFCS), indexacao (arr[i]), desreferencia (ptr^) ou propagacao (?)
  while Check(tokDot) or Check(tokLBracket) or Check(tokCaret) or Check(tokQuestion) do
  begin
    if Check(tokQuestion) then
    begin
      Result := TASTUnaryExpr.Create(FCurTok.Line, FCurTok.Col, '?', Result);
      Advance;
    end
    else if Match(tokCaret) then
    begin
      Result := TASTUnaryExpr.Create(Line, Col, '^', Result);
    end
    else if Match(tokDot) then
    begin
      Id := Expect(tokIdentifier, 'Esperado identificador apos "."').Value;
      if Match(tokLParen) then
      begin
        // UFCS: expr.Metodo(args...) e transformado transparentemente em Metodo(borrow expr, args...)
        CallExpr := TASTCallExpr.Create(Line, Col, Id);
        CallExpr.IsQualified := True;
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
  else if Match(tokTry) then
    Result := TASTUnaryExpr.Create(Line, Col, '?', ParseUnaryExpr())
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
  while Check(tokStar) or Check(tokSlash) or Check(tokDiv) or Check(tokMod) or Check(tokShl) or Check(tokShr) do
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
  ModName, ModDoc, CloseMod: string;
  MLine, MCol, I, J, StubIdx: Integer;
  PendingAttrs: TParsedAttributes;
  ImplFunc, StubFunc: TASTFunction;
  TraitNode: TASTTraitDecl;
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
    // Imports iniciais
    while Check(tokImport) do
      ParseImport(Result);

    if Check(tokInterface) then
    begin
      // Estrutura de Unit Object Pascal: interface ... implementation ... [initialization] [finalization] end <ModName>.
      Result.IsUnit := True;
      Result.HasExplicitPub := True;
      Advance; // consome 'interface'

      while Check(tokImport) do
        ParseImport(Result);

      while not Check(tokImplementation) and not Check(tokEOF) do
      begin
        while Check(tokLBracket) or Check(tokAt) or Check(tokPub) or Check(tokPriv) do
        begin
          if Match(tokPub) then
          begin
            PendingAttrs.HasVis := True;
            PendingAttrs.IsPublic := True;
          end
          else if Match(tokPriv) then
            raise EAetherParserError.Create('Declaracoes privadas ("priv") devem ficar na secao "implementation", nao na "interface"', FCurTok.Line, FCurTok.Col)
          else
            ParseAttribute(PendingAttrs);
        end;

        if Check(tokConst) then
        begin
          PendingAttrs.HasVis := True;
          PendingAttrs.IsPublic := True;
          ParseConstSection(Result, PendingAttrs);
        end
        else if Check(tokType) then
        begin
          PendingAttrs.HasVis := True;
          PendingAttrs.IsPublic := True;
          ParseTypeSection(Result, PendingAttrs);
        end
        else if Check(tokVar) or Check(tokLet) then
        begin
          ParseVarSection(Result.ModuleVars, True, True);
          ClearAttributes(PendingAttrs);
        end
        else if Check(tokTrait) then
        begin
          TraitNode := ParseTraitDecl('', FCurTok.Line, FCurTok.Col);
          TraitNode.HasExplicitVis := True;
          TraitNode.IsPublic := True;
          Result.Traits.Add(TraitNode);
          ClearAttributes(PendingAttrs);
        end
        else if Check(tokFunction) or Check(tokProcedure) or Check(tokExtern) or Check(tokAsync) or Check(tokExport) then
        begin
          PendingAttrs.HasVis := True;
          PendingAttrs.IsPublic := True;
          StubFunc := ParseFunction(True, PendingAttrs, True);
          if not StubFunc.IsExtern then
            StubFunc.IsInterfaceDecl := True;
          Result.Functions.Add(StubFunc);
          ClearAttributes(PendingAttrs);
        end
        else
          raise EAetherParserError.Create(Format('Declaracao inesperada na secao "interface": "%s"', [FCurTok.Value]), FCurTok.Line, FCurTok.Col);
      end;

      Expect(tokImplementation, Format('Esperado "implementation" na unit "%s"', [ModName]));

      while Check(tokImport) do
        ParseImport(Result);

      while not Check(tokInitialization) and not Check(tokFinalization) and not Check(tokEnd) and not Check(tokEOF) do
      begin
        while Check(tokLBracket) or Check(tokAt) or Check(tokPub) or Check(tokPriv) do
        begin
          if Match(tokPub) then
          begin
            PendingAttrs.HasVis := True;
            PendingAttrs.IsPublic := True;
          end
          else if Match(tokPriv) then
          begin
            PendingAttrs.HasVis := True;
            PendingAttrs.IsPublic := False;
          end
          else
            ParseAttribute(PendingAttrs);
        end;

        if Check(tokConst) then
        begin
          if not PendingAttrs.HasVis then
          begin
            PendingAttrs.HasVis := True;
            PendingAttrs.IsPublic := False;
          end;
          ParseConstSection(Result, PendingAttrs);
        end
        else if Check(tokType) then
        begin
          if not PendingAttrs.HasVis then
          begin
            PendingAttrs.HasVis := True;
            PendingAttrs.IsPublic := False;
          end;
          ParseTypeSection(Result, PendingAttrs);
        end
        else if Check(tokVar) or Check(tokLet) then
        begin
          ParseVarSection(Result.ModuleVars, PendingAttrs.HasVis and PendingAttrs.IsPublic, True);
          ClearAttributes(PendingAttrs);
        end
        else if Check(tokTrait) then
        begin
          TraitNode := ParseTraitDecl('', FCurTok.Line, FCurTok.Col);
          TraitNode.HasExplicitVis := True;
          TraitNode.IsPublic := PendingAttrs.HasVis and PendingAttrs.IsPublic;
          Result.Traits.Add(TraitNode);
          ClearAttributes(PendingAttrs);
        end
        else if Check(tokImpl) then
        begin
          Result.Impls.Add(ParseImplDecl);
          ClearAttributes(PendingAttrs);
        end
        else if Check(tokFunction) or Check(tokProcedure) or Check(tokExtern) or Check(tokAsync) or Check(tokExport) then
        begin
          ImplFunc := ParseFunction(False, PendingAttrs, False);
          ClearAttributes(PendingAttrs);

          StubIdx := -1;
          for I := 0 to Result.Functions.Count - 1 do
          begin
            StubFunc := TASTFunction(Result.Functions[I]);
            if StubFunc.IsInterfaceDecl and SameText(StubFunc.Name, ImplFunc.Name) then
            begin
              StubIdx := I;
              Break;
            end;
          end;

          if StubIdx >= 0 then
          begin
            StubFunc := TASTFunction(Result.Functions[StubIdx]);
            if StubFunc.IsProcedure <> ImplFunc.IsProcedure then
              raise EAetherParserError.Create(Format('Assinatura divergente na implementation para "%s" (function/procedure)', [ImplFunc.Name]), ImplFunc.Line, ImplFunc.Col);
            if (not SameText(StubFunc.GenericParam, ImplFunc.GenericParam)) or (not SameText(StubFunc.TraitBound, ImplFunc.TraitBound)) then
              raise EAetherParserError.Create(Format('Parametro generico divergente na implementation para "%s"', [ImplFunc.Name]), ImplFunc.Line, ImplFunc.Col);
            if not SameText(StubFunc.ReturnType, ImplFunc.ReturnType) then
              raise EAetherParserError.Create(Format('Tipo de retorno divergente na implementation para "%s": esperado "%s", encontrado "%s"',
                [ImplFunc.Name, StubFunc.ReturnType, ImplFunc.ReturnType]), ImplFunc.Line, ImplFunc.Col);
            if StubFunc.Params.Count <> ImplFunc.Params.Count then
              raise EAetherParserError.Create(Format('Quantidade de parametros divergente na implementation para "%s": esperado %d, encontrado %d',
                [ImplFunc.Name, StubFunc.Params.Count, ImplFunc.Params.Count]), ImplFunc.Line, ImplFunc.Col);
            for J := 0 to StubFunc.Params.Count - 1 do
            begin
              if (TASTParam(StubFunc.Params[J]).Ownership <> TASTParam(ImplFunc.Params[J]).Ownership) or
                 (not SameText(TASTParam(StubFunc.Params[J]).TypeName, TASTParam(ImplFunc.Params[J]).TypeName)) then
                raise EAetherParserError.Create(Format('Parametro %d de "%s" na implementation diverge da assinatura na interface',
                  [J + 1, ImplFunc.Name]), ImplFunc.Line, ImplFunc.Col);
            end;

            if (StubFunc.Requires.Count > 0) or (StubFunc.Ensures.Count > 0) then
            begin
              if (ImplFunc.Requires.Count > 0) or (ImplFunc.Ensures.Count > 0) then
                raise EAetherParserError.Create(Format('Contratos de "%s" devem ser declarados apenas na secao "interface", sem duplicacao na "implementation"',
                  [ImplFunc.Name]), ImplFunc.Line, ImplFunc.Col);
              while StubFunc.Requires.Count > 0 do
                ImplFunc.Requires.Add(StubFunc.Requires.Extract(StubFunc.Requires[0]));
              while StubFunc.Ensures.Count > 0 do
                ImplFunc.Ensures.Add(StubFunc.Ensures.Extract(StubFunc.Ensures[0]));
            end;

            if ImplFunc.DocComment = '' then
              ImplFunc.DocComment := StubFunc.DocComment;
            if StubFunc.IsExport then ImplFunc.IsExport := True;
            if ImplFunc.InlineMode = '' then ImplFunc.InlineMode := StubFunc.InlineMode;
            if StubFunc.IsCold then ImplFunc.IsCold := True;
            if ImplFunc.CfgCondition = '' then ImplFunc.CfgCondition := StubFunc.CfgCondition;

            ImplFunc.HasExplicitVis := True;
            ImplFunc.IsPublic := True;
            ImplFunc.IsInterfaceDecl := False;
            Result.Functions[StubIdx] := ImplFunc;
          end
          else
          begin
            if not ImplFunc.HasExplicitVis then
            begin
              ImplFunc.HasExplicitVis := True;
              ImplFunc.IsPublic := False;
            end;
            Result.Functions.Add(ImplFunc);
          end;
        end
        else
          raise EAetherParserError.Create(Format('Declaracao inesperada na secao "implementation": "%s"', [FCurTok.Value]), FCurTok.Line, FCurTok.Col);
      end;

      // Garante que toda assinatura declarada na interface foi implementada
      for I := 0 to Result.Functions.Count - 1 do
      begin
        StubFunc := TASTFunction(Result.Functions[I]);
        if StubFunc.IsInterfaceDecl and (not StubFunc.IsExtern) then
          raise EAetherParserError.Create(Format('Rotina "%s" declarada na secao "interface" nao foi implementada na secao "implementation"',
            [StubFunc.Name]), StubFunc.Line, StubFunc.Col);
      end;

      if Match(tokInitialization) then
      begin
        while not Check(tokFinalization) and not Check(tokEnd) and not Check(tokEOF) do
        begin
          Result.InitBody.Add(ParseStatement);
          Expect(tokSemicolon, 'Esperado ";" apos instrucao na secao initialization');
        end;
      end;

      if Match(tokFinalization) then
      begin
        while not Check(tokEnd) and not Check(tokEOF) do
        begin
          Result.FiniBody.Add(ParseStatement);
          Expect(tokSemicolon, 'Esperado ";" apos instrucao na secao finalization');
        end;
      end;

      Expect(tokEnd, Format('Esperado "end %s." no fechamento da unit', [ModName]));
      CloseMod := Expect(tokIdentifier, Format('Esperado nome "%s" apos "end"', [ModName])).Value;
      if not SameText(CloseMod, ModName) then
        raise EAetherParserError.Create(Format('Fechamento de unit divergente: esperado "end %s.", mas encontrado "end %s."', [ModName, CloseMod]), FCurTok.Line, FCurTok.Col);
      Expect(tokDot, Format('Esperado "." apos "end %s"', [ModName]));
    end
    else
    begin
      // Modulo executavel com "program Main;"
      while not Check(tokEOF) do
      begin
        while Check(tokLBracket) or Check(tokAt) or Check(tokPub) or Check(tokPriv) do
        begin
          if Match(tokPub) then
          begin
            PendingAttrs.HasVis := True;
            PendingAttrs.IsPublic := True;
            Result.HasExplicitPub := True;
          end
          else if Match(tokPriv) then
          begin
            PendingAttrs.HasVis := True;
            PendingAttrs.IsPublic := False;
            Result.HasExplicitPub := True;
          end
          else
            ParseAttribute(PendingAttrs);
        end;

        if Check(tokConst) then
        begin
          ParseConstSection(Result, PendingAttrs);
        end
        else if Check(tokType) then
        begin
          ParseTypeSection(Result, PendingAttrs);
        end
        else if Check(tokVar) or Check(tokLet) then
        begin
          ParseVarSection(Result.ModuleVars, not (PendingAttrs.HasVis and (not PendingAttrs.IsPublic)), PendingAttrs.HasVis);
          ClearAttributes(PendingAttrs);
        end
        else if Check(tokTrait) then
        begin
          Result.Traits.Add(ParseTraitDecl('', FCurTok.Line, FCurTok.Col));
          if PendingAttrs.HasVis then
          begin
            TASTNode(Result.Traits[Result.Traits.Count - 1]).HasExplicitVis := True;
            TASTNode(Result.Traits[Result.Traits.Count - 1]).IsPublic := PendingAttrs.IsPublic;
          end;
          ClearAttributes(PendingAttrs);
        end
        else if Check(tokImpl) then
        begin
          Result.Impls.Add(ParseImplDecl);
          ClearAttributes(PendingAttrs);
        end
        else if Check(tokFunction) or Check(tokProcedure) or Check(tokExtern) or Check(tokAsync) or Check(tokExport) then
        begin
          Result.Functions.Add(ParseFunction(False, PendingAttrs, False));
          ClearAttributes(PendingAttrs);
        end
        else if Check(tokProgram) then
        begin
          Result.ProgramBlock := ParseProgramBlock(ModName);
          Break;
        end
        else
          raise EAetherParserError.Create(Format('Declaracao inesperada no modulo: "%s"', [FCurTok.Value]), FCurTok.Line, FCurTok.Col);
      end;

      if not Assigned(Result.ProgramBlock) then
        raise EAetherParserError.Create(Format('Modulo "%s" sem "program Main;" deve declarar a estrutura de Unit Object Pascal ("interface" ... "implementation" ... end %s.)',
          [ModName, ModName]), FCurTok.Line, FCurTok.Col);
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
