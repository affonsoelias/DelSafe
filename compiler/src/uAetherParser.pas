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
  TParserState = record
    LexState: TLexerState;
    CurTok: TToken;
    PeekTok: TToken;
  end;

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
    FTupleTempCounter: Integer;

    procedure Advance;
    function Check(Kind: TTokenKind): Boolean;
    function Match(Kind: TTokenKind): Boolean;
    function Expect(Kind: TTokenKind; const Msg: string = ''): TToken;
    function SaveParserState: TParserState;
    procedure RestoreParserState(const AState: TParserState);

    function ParseTypeRef: string;
    function LookaheadIsTupleTypeDecl(AModule: TASTModule): Boolean;
    procedure ParseTupleDestruct(IsMut: Boolean; DestList: TASTNodeList; ForcePublic: Boolean = True; HasExplicitVis: Boolean = False);
    procedure ParseCallArgs(CallExpr: TASTCallExpr);
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
    function ParseIfStmt(RequireClosingEnd: Boolean = True): TASTIfStmt;
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
  inherited Create(Format('[Syntax Error at %d:%d]: %s', [ALine, ACol, Msg]));
  Line := ALine;
  Col := ACol;
end;

constructor TAetherParser.Create(ALexer: TAetherLexer);
begin
  inherited Create;
  FLexer := ALexer;
  FTupleTempCounter := 0;
  Advance;
  Advance;
end;

procedure TAetherParser.Advance;
begin
  FCurTok := FPeekTok;
  FPeekTok := FLexer.NextToken;
end;

function TAetherParser.SaveParserState: TParserState;
begin
  Result.LexState := FLexer.SaveState;
  Result.CurTok := FCurTok;
  Result.PeekTok := FPeekTok;
end;

procedure TAetherParser.RestoreParserState(const AState: TParserState);
begin
  FLexer.RestoreState(AState.LexState);
  FCurTok := AState.CurTok;
  FPeekTok := AState.PeekTok;
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
        Format('Expected token "%s", but found "%s" ("%s")',
          [TokenKindToString(Kind), TokenKindToString(FCurTok.Kind), FCurTok.Value]),
        FCurTok.Line, FCurTok.Col);
  end;
end;

function TAetherParser.ParseTypeRef: string;
var
  BaseType, ParamsStr, RetT: string;
  ElemCount: Integer;

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

  function ParseFnTypeParamList: string;
  var
    PType: string;
  begin
    Result := '';
    if Check(tokRParen) then Exit;
    repeat
      if Match(tokTake) or Match(tokBorrow) then
        // consume ownership modifier if present
      else if Match(tokMut) then
        Expect(tokBorrow, 'Expected "borrow" after "mut"');

      if Check(tokIdentifier) and (FPeekTok.Kind = tokColon) then
      begin
        Advance; // param name
        Advance; // ':'
      end;
      PType := ParseTypeRef();
      if Result <> '' then Result := Result + ', ';
      Result := Result + PType;
    until (not Match(tokComma)) and (not Match(tokSemicolon));
  end;
begin
  if Match(tokLParen) then
  begin
    BaseType := ParseTypeRef();
    ElemCount := 1;
    if Match(tokComma) then
    begin
      BaseType := '(' + BaseType + ', ' + ParseTypeRef();
      Inc(ElemCount);
      while Match(tokComma) do
      begin
        BaseType := BaseType + ', ' + ParseTypeRef();
        Inc(ElemCount);
      end;
      Expect(tokRParen, 'Expected ")" to close tuple type');
      Result := BaseType + ')';
    end
    else
    begin
      Expect(tokRParen, 'Expected ")" to close parenthesized type');
      Result := BaseType;
    end;
    Exit;
  end;
  if Match(tokFunction) then
  begin
    Expect(tokLParen, 'Expected "(" after "function" in function type');
    ParamsStr := ParseFnTypeParamList;
    Expect(tokRParen, 'Expected ")" to close function type parameters');
    if (not Match(tokReturn)) and (not Match(tokColon)) then
      raise EAetherParserError.Create('Expected "return <Type>" or ": <Type>" in function type', FCurTok.Line, FCurTok.Col);
    RetT := ParseTypeRef();
    Result := 'fn(' + ParamsStr + ') -> ' + RetT;
    Exit;
  end;
  if Match(tokProcedure) then
  begin
    ParamsStr := '';
    if Match(tokLParen) then
    begin
      ParamsStr := ParseFnTypeParamList;
      Expect(tokRParen, 'Expected ")" to close procedure type parameters');
    end;
    Result := 'fn(' + ParamsStr + ') -> Void';
    Exit;
  end;
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
    Expect(tokLBracket, 'Expected "[" in array dimensions specification');
    BaseType := 'array[';
    BaseType := BaseType + Expect(tokIntLiteral, 'Expected integer array dimension').Value;
    while Match(tokComma) do
      BaseType := BaseType + ', ' + Expect(tokIntLiteral, 'Expected integer array dimension').Value;
    Expect(tokRBracket, 'Expected "]" to close array dimensions');
    Expect(tokOf, 'Expected "of" after array dimensions');
    BaseType := BaseType + '] of ' + ParseTypeRef();
    Result := BaseType;
    Exit;
  end;
  if Match(tokSet) then
  begin
    Expect(tokOf, 'Expected "of" after "set"');
    Result := 'set of ' + ParseTypeRef();
    Exit;
  end;
  if Match(tokMap) then
  begin
    Expect(tokLBracket, 'Expected "[" after "map"');
    BaseType := 'map[' + ParseTypeRef() + ']';
    Expect(tokRBracket, 'Expected "]" after map key type');
    Result := BaseType + ParseTypeRef();
    Exit;
  end;

  BaseType := Expect(tokIdentifier, 'Expected type identifier').Value;
  while Match(tokDot) do
    BaseType := Expect(tokIdentifier, 'Expected type identifier after "."').Value;
  if Match(tokLess) then
  begin
    BaseType := BaseType + '<' + ParseTypeRef();
    while Match(tokComma) do
      BaseType := BaseType + ', ' + ParseTypeRef();
    if not ConsumeGenericClose then
      Expect(tokGreater, 'Expected ">" to close generic type');
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
    ImportName := Expect(tokIdentifier, 'Expected imported module name').Value;
    while Match(tokDot) do
      ImportName := ImportName + '.' + Expect(tokIdentifier, 'Expected identifier after "." in imported module name').Value;
    if Match(tokAs) then
    begin
      AliasName := Expect(tokIdentifier, 'Expected alias after "as"').Value;
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
      FieldName := Expect(tokIdentifier, 'Expected record field name').Value;
      Expect(tokColon, 'Expected ":" after field name');
      FieldType := ParseTypeRef;
      Expect(tokSemicolon, 'Expected ";" after field definition');
      FieldNode := TASTRecordField.Create(FLine, FCol, FieldName, FieldType);
      FieldNode.DocComment := FDoc;
      FieldNode.HasExplicitVis := FHasVis;
      FieldNode.IsPublic := FIsPub;
      Result.Fields.Add(FieldNode);
    end;
    Expect(tokEnd, 'Expected "end record;" to close record');
    Expect(tokRecord, 'Expected "record" after "end" to close record');
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
      VName := Expect(tokIdentifier, 'Expected enum variant name').Value;
      VariantNode := TASTEnumVariant.Create(VLine, VCol, VName);
      VariantNode.DocComment := VDoc;
      Result.Variants.Add(VariantNode);

      // Optional payload: Variant(field: Type, ...)
      if Match(tokLParen) then
      begin
        while not Check(tokRParen) and not Check(tokEOF) do
        begin
          FName := Expect(tokIdentifier, 'Expected enum field name').Value;
          Expect(tokColon);
          FType := ParseTypeRef;
          VariantNode.Fields.Add(TASTRecordField.Create(VLine, VCol, FName, FType));
          if not Match(tokComma) then
            Break;
        end;
        Expect(tokRParen, 'Expected ")" after enum fields');
      end;

      if not Match(tokComma) then
        Break;
    end;
    Expect(tokEnd, 'Expected "end enum;" to close enum');
    Expect(tokEnum, 'Expected "enum" after "end" to close enum');
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

  AttrId := Expect(tokIdentifier, 'Expected attribute identifier (e.g., derive, cfg, inline, cold)').Value;

  if SameText(AttrId, 'derive') then
  begin
    Expect(tokLParen, 'Expected "(" after derive');
    repeat
      DeriveItem := Expect(tokIdentifier, 'Expected trait name to derive (e.g., Debug, JSON, Clone, Equals)').Value;
      if Assigned(Attrs.Derives) and (Attrs.Derives.IndexOf(DeriveItem) < 0) then
        Attrs.Derives.Add(DeriveItem);
    until not Match(tokComma);
    Expect(tokRParen, 'Expected ")" to close derive');
  end
  else if SameText(AttrId, 'cfg') then
  begin
    Expect(tokLParen, 'Expected "(" after cfg');
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
    Expect(tokRParen, 'Expected ")" to close cfg');
    Attrs.CfgCondition := Trim(CondStr);
  end
  else if SameText(AttrId, 'inline') then
  begin
    if Match(tokLParen) then
    begin
      InlineVal := Expect(tokIdentifier, 'Expected "always" or "never" in inline(...)').Value;
      Attrs.InlineMode := LowerCase(InlineVal);
      Expect(tokRParen, 'Expected ")" to close inline');
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
      Expect(tokRParen, 'Expected ")" to close cold');
    end;
  end
  else
  begin
    // Unknown / future attribute
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
    Expect(tokRBracket, 'Expected "]" to close attribute');
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
        ConstName := Expect(tokIdentifier, 'Expected constant name').Value;
        ConstType := '';
        if Match(tokColon) then
          ConstType := ParseTypeRef;
        Expect(tokEqual, 'Expected "=" in constant definition');
        ValExpr := ParseExpr;
        Expect(tokSemicolon, 'Expected ";" after constant definition');

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

function TAetherParser.LookaheadIsTupleTypeDecl(AModule: TASTModule): Boolean;
var
  Saved: TParserState;
  Id: string;
  ItemCount: Integer;
  Node: TASTNode;

  function IsKnownTypeIdent(const N: string): Boolean;
  var
    K: Integer;
    Nd: TASTNode;
  begin
    if SameText(N, 'Int8') or SameText(N, 'Int16') or SameText(N, 'Int32') or SameText(N, 'Int64') or
       SameText(N, 'UInt8') or SameText(N, 'UInt16') or SameText(N, 'UInt32') or SameText(N, 'UInt64') or
       SameText(N, 'Float32') or SameText(N, 'Float64') or SameText(N, 'Bool') or SameText(N, 'Char') or
       SameText(N, 'String') or SameText(N, 'Pointer') or SameText(N, 'Option') or SameText(N, 'Result') or
       SameText(N, 'Box') or SameText(N, 'Task') then
      Exit(True);
    if Assigned(AModule) then
      for K := 0 to AModule.Types.Count - 1 do
      begin
        Nd := TASTNode(AModule.Types[K]);
        if (Nd is TASTRecordDecl) and SameText(TASTRecordDecl(Nd).Name, N) then Exit(True);
        if (Nd is TASTEnumDecl) and SameText(TASTEnumDecl(Nd).Name, N) then Exit(True);
        if (Nd is TASTArrayDecl) and SameText(TASTArrayDecl(Nd).Name, N) then Exit(True);
        if (Nd is TASTSetDecl) and SameText(TASTSetDecl(Nd).Name, N) then Exit(True);
        if (Nd is TASTSubrangeDecl) and SameText(TASTSubrangeDecl(Nd).Name, N) then Exit(True);
        if (Nd is TASTMapDecl) and SameText(TASTMapDecl(Nd).Name, N) then Exit(True);
        if (Nd is TASTTypeAliasDecl) and SameText(TASTTypeAliasDecl(Nd).Name, N) then Exit(True);
      end;
    Result := False;
  end;
begin
  Result := False;
  Saved := SaveParserState;
  try
    if not Match(tokLParen) then Exit;
    ItemCount := 0;
    while not Check(tokRParen) and not Check(tokEOF) do
    begin
      Inc(ItemCount);
      if not Check(tokIdentifier) then
      begin
        Result := True;
        Exit;
      end;
      Id := Expect(tokIdentifier).Value;
      if Check(tokLess) or Check(tokDot) or IsKnownTypeIdent(Id) then
      begin
        Result := True;
        Exit;
      end;
      if not Match(tokComma) then
      begin
        if not Check(tokRParen) then
          Result := True;
        Exit;
      end;
    end;
    Node := nil;
    if Assigned(Node) then;
  finally
    RestoreParserState(Saved);
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
  GenParams: TStringList;
begin
  Expect(tokType);
  SecHasVis := SectionAttrs.HasVis;
  SecIsPub := SectionAttrs.IsPublic;
  InitAttributes(CurrentAttrs);
  GenParams := TStringList.Create;
  try
    while not Check(tokEOF) do
    begin
      ClearAttributes(CurrentAttrs);
      GenParams.Clear;
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

      if Check(tokIdentifier) and (FPeekTok.Kind in [tokEqual, tokLess]) then
      begin
        TLine := FCurTok.Line;
        TCol := FCurTok.Col;
        TypeDoc := FCurTok.DocComment;
        TypeName := Expect(tokIdentifier).Value;
        if Match(tokLess) then
        begin
          repeat
            GenParams.Add(Expect(tokIdentifier, 'Expected generic type parameter').Value);
          until not Match(tokComma);
          Expect(tokGreater, 'Expected ">" after record generic parameters');
        end;
        Expect(tokEqual, 'Expected "=" in type declaration');

        EffectiveCfg := CurrentAttrs.CfgCondition;
        if EffectiveCfg = '' then
          EffectiveCfg := SectionAttrs.CfgCondition;

        if Check(tokRecord) then
        begin
          RecDecl := ParseRecordDecl(TypeName, TLine, TCol);
          RecDecl.DocComment := TypeDoc;
          RecDecl.Derives.AddStrings(CurrentAttrs.Derives);
          RecDecl.Derives.AddStrings(SectionAttrs.Derives);
          RecDecl.GenericParams.AddStrings(GenParams);
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
          Advance; // consume 'array'
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
            Expect(tokLBracket, 'Expected "[" in array dimensions declaration');
            ArrDecl := TASTArrayDecl.Create(TLine, TCol, TypeName, '');
            ArrDecl.Dims.Add(Expect(tokIntLiteral, 'Expected integer array dimension').Value);
            while Match(tokComma) do
              ArrDecl.Dims.Add(Expect(tokIntLiteral, 'Expected integer array dimension').Value);
            Expect(tokRBracket, 'Expected "]" after array dimensions');
            Expect(tokOf, 'Expected "of" after array dimensions');
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
          Advance; // consume 'set'
          Expect(tokOf, 'Expected "of" after "set"');
          SetDecl := TASTSetDecl.Create(TLine, TCol, TypeName);
          if Match(tokLParen) then
          begin
            while not Check(tokRParen) and not Check(tokEOF) do
            begin
              SetDecl.Variants.Add(TASTEnumVariant.Create(FCurTok.Line, FCurTok.Col, Expect(tokIdentifier, 'Expected set variant identifier').Value));
              if not Match(tokComma) then Break;
            end;
            Expect(tokRParen, 'Expected ")" to close set variants');
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
          Advance; // consume 'map'
          Expect(tokLBracket, 'Expected "[" after "map"');
          KeyType := ParseTypeRef();
          Expect(tokRBracket, 'Expected "]" after map key type');
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
          Expect(tokDotDot, 'Expected ".." in subrange bounds');
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
        else if Check(tokLParen) and (not LookaheadIsTupleTypeDecl(AModule)) then
        begin
          Advance; // consume '('
          EnumDecl := TASTEnumDecl.Create(TLine, TCol, TypeName);
          while not Check(tokRParen) and not Check(tokEOF) do
          begin
            EnumDecl.Variants.Add(TASTEnumVariant.Create(FCurTok.Line, FCurTok.Col, Expect(tokIdentifier, 'Expected enum variant name').Value));
            if not Match(tokComma) then Break;
          end;
          Expect(tokRParen, 'Expected ")" to close enum variants');
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
        Expect(tokSemicolon, 'Expected ";" after type declaration');
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
    GenParams.Free;
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
    TraitName := Expect(tokIdentifier, 'Expected trait name identifier').Value;

  Result := TASTTraitDecl.Create(ALine, ACol, TraitName);
  Result.DocComment := TraitDoc;
  try
    while not Check(tokEnd) and not Check(tokEOF) do
    begin
      if Check(tokFunction) or Check(tokProcedure) or Check(tokAsync) then
        Result.Methods.Add(ParseFunction(True))
      else
        raise EAetherParserError.Create('Expected "function" or "procedure" in trait declaration', FCurTok.Line, FCurTok.Col);
    end;
    Expect(tokEnd, 'Expected "end trait;" to close trait');
    Expect(tokTrait, 'Expected "trait" after "end" to close trait');
    if AName = '' then
      Expect(tokSemicolon, 'Expected ";" after "end trait"');
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
  FirstName := Expect(tokIdentifier, 'Expected trait or type name after "impl"').Value;
  if Match(tokFor) then
  begin
    TraitName := FirstName;
    TargetName := Expect(tokIdentifier, 'Expected type name after "for"').Value;
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
        raise EAetherParserError.Create('Expected "function" or "procedure" in impl block', FCurTok.Line, FCurTok.Col);
    end;
    Expect(tokEnd, 'Expected "end impl;" to close impl block');
    Expect(tokImpl, 'Expected "impl" after "end" to close impl block');
    Expect(tokSemicolon, 'Expected ";" after "end impl"');
  except
    Result.Free;
    raise;
  end;
end;

procedure TAetherParser.ParseTupleDestruct(IsMut: Boolean; DestList: TASTNodeList; ForcePublic, HasExplicitVis: Boolean);
var
  Names: TStringList;
  VarType, TempName: string;
  InitExpr, ItemExpr: TASTExpr;
  VLine, VCol, I: Integer;
  TempVD, ElemVD: TASTVarDecl;
begin
  VLine := FCurTok.Line;
  VCol := FCurTok.Col;
  Expect(tokLParen, 'Expected "(" in tuple destructuring');
  Names := TStringList.Create;
  try
    if not Check(tokRParen) then
    begin
      repeat
        if Match(tokUnderscore) then
          Names.Add('_')
        else
          Names.Add(Expect(tokIdentifier, 'Expected identifier or "_" in tuple destructuring').Value);
      until not Match(tokComma);
    end;
    if Names.Count < 1 then
      raise EAetherParserError.Create('Tuple destructuring pattern cannot be empty', VLine, VCol);
    Expect(tokRParen, 'Expected ")" to close tuple destructuring pattern');

    VarType := '';
    if Match(tokColon) then
      VarType := ParseTypeRef();

    if (not Match(tokAssign)) and (not Match(tokEqual)) then
      raise EAetherParserError.Create('Expected ":=" or "=" in tuple destructuring declaration', FCurTok.Line, FCurTok.Col);
    InitExpr := ParseExpr;

    Inc(FTupleTempCounter);
    TempName := '__aether_tup_' + IntToStr(FTupleTempCounter);
    TempVD := TASTVarDecl.Create(VLine, VCol, TempName, VarType, InitExpr, False);
    TempVD.ExpectedTupleArity := Names.Count;
    TempVD.HasExplicitVis := HasExplicitVis;
    TempVD.IsPublic := ForcePublic;
    DestList.Add(TempVD);

    for I := 0 to Names.Count - 1 do
    begin
      if Names[I] = '_' then Continue;
      ItemExpr := TASTMemberAccessExpr.Create(VLine, VCol,
        TASTIdentifierExpr.Create(VLine, VCol, TempName), 'item' + IntToStr(I));
      ElemVD := TASTVarDecl.Create(VLine, VCol, Names[I], '', ItemExpr, IsMut);
      ElemVD.HasExplicitVis := HasExplicitVis;
      ElemVD.IsPublic := ForcePublic;
      DestList.Add(ElemVD);
    end;
  finally
    Names.Free;
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
  Advance; // consume 'var' or 'let'

  VarNames := TStringList.Create;
  try
    while Check(tokIdentifier) or Check(tokLParen) do
    begin
      if Check(tokLParen) then
      begin
        ParseTupleDestruct(IsMut, ALocalVars, ForcePublic, HasExplicitVis);
        Expect(tokSemicolon, 'Expected ";" after tuple destructuring');
        Continue;
      end;

      VarNames.Clear;
      VLine := FCurTok.Line;
      VCol := FCurTok.Col;
      VarNames.Add(Expect(tokIdentifier).Value);
      while Match(tokComma) do
        VarNames.Add(Expect(tokIdentifier, 'Expected identifier after "," in variable declaration').Value);

      VarType := '';
      if Match(tokColon) then
        VarType := ParseTypeRef();

      InitExpr := nil;
      if Match(tokAssign) or Match(tokEqual) then
        InitExpr := ParseExpr;

      if (VarType = '') and not Assigned(InitExpr) then
        raise EAetherParserError.Create('Expected ": <Type>" or ":= <Value>" in variable declaration', FCurTok.Line, FCurTok.Col);

      Expect(tokSemicolon, 'Expected ";" after variable declaration');
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
          Expect(tokSemicolon, 'Expected ";" after require expression');
        end;
      end;

      if Match(tokEnsure) then
      begin
        while not AtContractBoundary do
        begin
          Result.Ensures.Add(ParseExpr);
          Expect(tokSemicolon, 'Expected ";" after ensure expression');
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
    Expect(tokFunction, 'Expected "function" or "procedure"');
  FuncName := Expect(tokIdentifier, 'Expected routine name').Value;

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
    // Generic parameters with optional trait bounds: function F<T, U: Printable>(...)
    if Match(tokLess) then
    begin
      repeat
        Result.GenericParams.Add(Expect(tokIdentifier, 'Expected generic parameter name').Value);
        if Match(tokColon) then
          Result.TraitBounds.Add(Expect(tokIdentifier, 'Expected trait name in bound').Value)
        else
          Result.TraitBounds.Add('');
      until not Match(tokComma);
      Expect(tokGreater, 'Expected ">" to close generic parameters');
      if Result.GenericParams.Count > 0 then
      begin
        Result.GenericParam := Result.GenericParams[0];
        Result.TraitBound := Result.TraitBounds[0];
      end;
    end;

    // Optional parentheses when there are no parameters
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
            Expect(tokBorrow, 'Expected "borrow" after "mut"');
            Ownership := owMutBorrow;
          end;

          ParamNames.Clear;
          PLine := FCurTok.Line;
          PCol := FCurTok.Col;
          ParamNames.Add(Expect(tokIdentifier, 'Expected parameter name').Value);
          while Match(tokComma) do
            ParamNames.Add(Expect(tokIdentifier, 'Expected parameter name after ","').Value);

          if Match(tokColon) then
            ParamType := ParseTypeRef
          else if (ParamNames.Count = 1) and SameText(ParamNames[0], 'self') then
            ParamType := 'Self'
          else
            raise EAetherParserError.Create('Expected ":" after parameter name', FCurTok.Line, FCurTok.Col);

          for I := 0 to ParamNames.Count - 1 do
            Result.Params.Add(TASTParam.Create(PLine, PCol, ParamNames[I], ParamType, Ownership));
        until (not Match(tokSemicolon)) and (not Match(tokComma));
      end;
      Expect(tokRParen, 'Expected ")" to close parameters');
    end;

    // Return clause (hard cutover: procedure has no return; function requires "return <Type>")
    if IsProc then
    begin
      if Check(tokReturn) or Check(tokColon) then
        raise EAetherParserError.Create('Procedures cannot have a return type; use "function ... return <Type>"', FCurTok.Line, FCurTok.Col);
      Result.ReturnType := 'Void';
    end
    else
    begin
      if Check(tokColon) then
        raise EAetherParserError.Create('Legacy ": Type" syntax removed. Use "return <Type>" in function declaration', FCurTok.Line, FCurTok.Col);
      Expect(tokReturn, 'Expected "return <Type>" after function parameters');
      ReturnType := ParseTypeRef;
      if SameText(ReturnType, 'Void') then
        raise EAetherParserError.Create('Functions cannot return "Void". Use "procedure"', FCurTok.Line, FCurTok.Col);
      Result.ReturnType := ReturnType;
    end;

    // Optional modifiers after return/signature (on the same line): export; cdecl; stdcall;
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

    // If extern, it has no "is" or body (may have contract before ";")
    if IsExt then
    begin
      if Check(tokContract) or Check(tokRequire) or Check(tokEnsure) then
        ParseOptionalContracts;
      if Check(tokSemicolon) then
        Match(tokSemicolon);
      Exit;
    end;

    // If signature (trait or unit interface section)
    if IsSignatureOnly then
    begin
      if AllowInterfaceContracts then
      begin
        HasContracts := Check(tokContract) or Check(tokRequire) or Check(tokEnsure);
        if HasContracts then
          ParseOptionalContracts
        else
        begin
          Expect(tokSemicolon, 'Expected ";" after signature in interface section');
          if Check(tokContract) or Check(tokRequire) or Check(tokEnsure) then
            ParseOptionalContracts;
        end;
      end
      else
        Expect(tokSemicolon, 'Expected ";" after trait method signature');
      Exit;
    end;

    // Full Ada-style definition: ... is [contract] [var/let] begin ... end Name;
    Expect(tokIs, Format('Expected "is" in definition of "%s"', [FuncName]));

    ParseOptionalContracts;

    // Local Variables
    while Check(tokVar) or Check(tokLet) do
      ParseVarSection(Result.LocalVars);

    // Body begin...end <Name>;
    Expect(tokBegin, 'Expected "begin" to start routine body');
    while not Check(tokEnd) and not Check(tokEOF) do
    begin
      Result.Body.Add(ParseStatement);
      Expect(tokSemicolon, 'Expected ";" after statement');
    end;
    Expect(tokEnd, Format('Expected "end %s;" to close routine', [FuncName]));
    CloseName := Expect(tokIdentifier, Format('Expected name "%s" after "end"', [FuncName])).Value;
    if not SameText(CloseName, FuncName) then
      raise EAetherParserError.Create(Format('Mismatched closing name: expected "end %s;", but found "end %s"', [FuncName, CloseName]), FCurTok.Line, FCurTok.Col);
    Expect(tokSemicolon, Format('Expected ";" after "end %s"', [FuncName]));
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
  ProgName := Expect(tokIdentifier, 'Expected "Main" after "program" keyword').Value;
  if not SameText(ProgName, 'Main') then
    raise EAetherParserError.CreateFmt('Error E0002: The executable block must be "program Main;", but found "program %s;" at line %d, column %d', [ProgName, PLine, PCol]);
  Expect(tokSemicolon, 'Expected ";" after "program Main" declaration');

  Result := TASTProgramBlock.Create(PLine, PCol, ProgName);
  try
    while Check(tokVar) or Check(tokLet) do
      ParseVarSection(Result.LocalVars);

    Expect(tokBegin, 'Expected "begin" to start program block');
    while not Check(tokEnd) and not Check(tokEOF) do
    begin
      Result.Body.Add(ParseStatement);
      Expect(tokSemicolon, 'Expected ";" after statement');
    end;
    Expect(tokEnd, Format('Expected "end %s." to end program', [AModuleName]));
    CloseMod := Expect(tokIdentifier, Format('Expected module name "%s" after "end"', [AModuleName])).Value;
    if not SameText(CloseMod, AModuleName) then
      raise EAetherParserError.Create(Format('Mismatched module closing: expected "end %s.", but found "end %s."', [AModuleName, CloseMod]), FCurTok.Line, FCurTok.Col);
    Expect(tokDot, Format('Expected "." after "end %s"', [AModuleName]));
  except
    Result.Free;
    raise;
  end;
end;

function TAetherParser.ParseIfStmt(RequireClosingEnd: Boolean): TASTIfStmt;
var
  Cond: TASTExpr;
  ILine, ICol, ElseLine: Integer;
begin
  ILine := FCurTok.Line;
  ICol := FCurTok.Col;
  Expect(tokIf);
  Cond := ParseExpr;
  Expect(tokThen, 'Expected "then" after if condition');

  Result := TASTIfStmt.Create(ILine, ICol, Cond);
  try
    while not Check(tokElse) and not Check(tokEnd) and not Check(tokEOF) do
    begin
      Result.ThenBranch.Add(ParseStatement);
      Expect(tokSemicolon, 'Expected ";" after statement in then branch');
    end;

    if Check(tokElse) then
    begin
      ElseLine := FCurTok.Line;
      Advance;
      if Check(tokIf) and (FCurTok.Line = ElseLine) then
      begin
        // Flattened "else if ... then ..." chain: "end if;" closes only the outermost if
        Result.ElseBranch.Add(ParseIfStmt(False));
      end
      else
      begin
        while not Check(tokEnd) and not Check(tokEOF) do
        begin
          Result.ElseBranch.Add(ParseStatement);
          Expect(tokSemicolon, 'Expected ";" after statement in else branch');
        end;
      end;
    end;

    if RequireClosingEnd then
    begin
      Expect(tokEnd, 'Expected "end if;" to close if');
      Expect(tokIf, 'Expected "if" after "end" to close if');
    end;
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
  Expect(tokDo, 'Expected "do" after while condition');

  Result := TASTWhileStmt.Create(WLine, WCol, Cond);
  try
    while not Check(tokEnd) and not Check(tokEOF) do
    begin
      Result.Body.Add(ParseStatement);
      Expect(tokSemicolon, 'Expected ";" after while statement');
    end;
    Expect(tokEnd, 'Expected "end while;" to close while');
    Expect(tokWhile, 'Expected "while" after "end" to close while');
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
  VarName := Expect(tokIdentifier, 'Expected for loop counter variable name').Value;
  ValVarName := '';
  if Match(tokComma) then
    ValVarName := Expect(tokIdentifier, 'Expected value identifier after "," in for..in loop').Value;

  if Match(tokIn) then
  begin
    ColExpr := ParseExpr;
    Expect(tokDo, 'Expected "do" after collection in for..in loop');
    Result := TASTForStmt.Create(FLine, FCol, VarName, nil, nil, False);
    Result.ValVarName := ValVarName;
    Result.CollectionExpr := ColExpr;
    try
      while not Check(tokEnd) and not Check(tokEOF) do
      begin
        Result.Body.Add(ParseStatement);
        Expect(tokSemicolon, 'Expected ";" after for statement');
      end;
      Expect(tokEnd, 'Expected "end for;" to close for');
      Expect(tokFor, 'Expected "for" after "end" to close for');
    except
      Result.Free;
      raise;
    end;
    Exit;
  end;

  if ValVarName <> '' then
    raise EAetherParserError.Create('Expected "in" after key, value pair in for..in loop', FCurTok.Line, FCurTok.Col);

  Expect(tokAssign, 'Expected ":=" or "in" after variable name in for');
  StartExpr := ParseExpr;
  IsDownTo := False;
  if Match(tokTo) then
    IsDownTo := False
  else if Match(tokDownto) then
    IsDownTo := True
  else
    raise EAetherParserError.CreateFmt('Expected "to" or "downto" in for loop at line %d, column %d', [FCurTok.Line, FCurTok.Col]);

  EndExpr := ParseExpr;
  Expect(tokDo, 'Expected "do" after for loop bounds');

  Result := TASTForStmt.Create(FLine, FCol, VarName, StartExpr, EndExpr, IsDownTo);
  try
    while not Check(tokEnd) and not Check(tokEOF) do
    begin
      Result.Body.Add(ParseStatement);
      Expect(tokSemicolon, 'Expected ";" after for statement');
    end;
    Expect(tokEnd, 'Expected "end for;" to close for');
    Expect(tokFor, 'Expected "for" after "end" to close for');
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
      Expect(tokSemicolon, 'Expected ";" after statement in repeat block');
    end;
    Expect(tokUntil, 'Expected "until" to close repeat block');
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
    Result := '-' + Expect(tokIntLiteral, 'Expected integer literal after "-" in case').Value
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
    Result := Expect(tokIdentifier, 'Expected pattern in case').Value;
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
      HiVal := '-' + Expect(tokIntLiteral, 'Expected integer literal after "-" in range').Value
    else if Check(tokCharLiteral) then
    begin
      HiVal := '''' + FCurTok.Value + '''';
      Advance;
    end
    else
    begin
      HiVal := Expect(tokIdentifier, 'Expected upper range bound in case').Value;
      if Match(tokDot) then
        HiVal := HiVal + '.' + Expect(tokIdentifier).Value;
    end;
    Result := Result + '..' + HiVal;
  end;
end;

function TAetherParser.ParseMatchCaseHead: TASTMatchCase;
var
  PatternNode: TASTPattern;
  PatVal, SubVal, ArgBind: string;
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
    SubVal := Expect(tokIdentifier, 'Expected identifier after "let" in case pattern').Value;
    IsLet := True;
    PatternNode := TASTPattern.Create(PLine, PCol, PatVal, SubVal, IsLet);
  end
  else
  begin
    PatVal := ParseSingleMatchPatternItem;
    PatternNode := TASTPattern.Create(PLine, PCol, PatVal, '', False);
    if Match(tokLParen) then
    begin
      if not Check(tokRParen) then
      begin
        repeat
          ArgBind := '';
          if Match(tokLet) then
            IsLet := True;
          if Check(tokIdentifier) then
            ArgBind := Expect(tokIdentifier).Value
          else if Match(tokUnderscore) then
            ArgBind := '_'
          else if Check(tokIntLiteral) or Check(tokStringLiteral) or Check(tokCharLiteral) then
          begin
            ArgBind := FCurTok.Value;
            Advance;
          end
          else if Match(tokTrue) then
            ArgBind := 'true'
          else if Match(tokFalse) then
            ArgBind := 'false';

          if Match(tokDot) then
            ArgBind := ArgBind + '.' + Expect(tokIdentifier).Value;

          PatternNode.Bindings.Add(ArgBind);
        until not Match(tokComma);
      end;
      PatternNode.IsLet := IsLet;
      if PatternNode.Bindings.Count > 0 then
        PatternNode.SubPattern := PatternNode.Bindings[0];
      Expect(tokRParen, 'Expected ")" after pattern argument');
    end;

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
      Expect(tokColon, 'Expected ":" or "=>" after case pattern');
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
    Expect(tokDo, 'Expected "do" or "with" after match expression');

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
        Expect(tokSemicolon, 'Expected ";" after case statement');
      end;
    end;
    Expect(tokEnd, 'Expected "end match;" to close match');
    Expect(tokMatch, 'Expected "match" after "end" to close match');
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
    Expect(tokDo, 'Expected "do" or "with" after match expression');

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
    Expect(tokEnd, 'Expected "end match" to close match expression');
    Expect(tokMatch, 'Expected "match" after "end" to close match expression');
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
  Expect(tokEnd, 'Expected "end asm;" to close asm block');
  Expect(tokAsm, 'Expected "asm" after "end" to close asm block');
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
      Expect(tokSemicolon, 'Expected ";" after statement in try block');
    end;
    Expect(tokExcept, 'Expected "except" in try..except block');
    while not Check(tokEnd) and not Check(tokEOF) do
    begin
      Result.ExceptBody.Add(ParseStatement);
      Expect(tokSemicolon, 'Expected ";" after statement in except block');
    end;
    Expect(tokEnd, 'Expected "end try;" to close try..except block');
    Expect(tokTry, 'Expected "try" after "end" to close try..except block');
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
      Expect(tokSemicolon, 'Expected ";" after statement in unsafe block');
    end;
    Expect(tokEnd, 'Expected "end unsafe;" to close unsafe block');
    Expect(tokUnsafe, 'Expected "unsafe" after "end" to close unsafe block');
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
  Advance; // consume 'var' or 'let'

  Result := TASTVarDeclStmt.Create(VLine, VCol);
  if Check(tokLParen) then
  begin
    try
      ParseTupleDestruct(IsMut, Result.Decls, True, False);
    except
      Result.Free;
      raise;
    end;
    Exit;
  end;

  VarNames := TStringList.Create;
  try
    try
      VarNames.Add(Expect(tokIdentifier, 'Expected variable name after "var" or "let"').Value);
      while Match(tokComma) do
        VarNames.Add(Expect(tokIdentifier, 'Expected identifier after "," in variable declaration').Value);

      VarType := '';
      if Match(tokColon) then
        VarType := ParseTypeRef();

      InitExpr := nil;
      if Match(tokAssign) or Match(tokEqual) then
        InitExpr := ParseExpr;

      if (VarType = '') and not Assigned(InitExpr) then
        raise EAetherParserError.Create('Expected ": <Type>" or ":= <Value>" in variable declaration', FCurTok.Line, FCurTok.Col);

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
  else if (Expr is TASTAwaitExpr) or (Expr is TASTSpawnExpr) then
  begin
    Result := TASTExprStmt.Create(Expr.Line, Expr.Col, Expr);
  end
  else
    raise EAetherParserError.Create('Invalid statement (expected assignment or function call)', Expr.Line, Expr.Col);
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
  else if Check(tokYield) then
  begin
    Result := TASTYieldStmt.Create(FCurTok.Line, FCurTok.Col);
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
        raise EAetherParserError.Create('Unclosed "{" brace in interpolated string', ALine, ACol);
      InnerCode := Trim(Copy(RawStr, StartPos, I - StartPos));
      Inc(I);
      if InnerCode = '' then
        raise EAetherParserError.Create('Empty expression inside "{}" interpolation', ALine, ACol);

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

procedure TAetherParser.ParseCallArgs(CallExpr: TASTCallExpr);
var
  ArgLine, ArgCol: Integer;
  ArgOwn: TOwnershipKind;
  ArgFieldName: string;
  ArgExpr: TASTExpr;
  CallArg: TASTCallArg;
begin
  if Check(tokRParen) then Exit;
  repeat
    ArgLine := FCurTok.Line;
    ArgCol := FCurTok.Col;
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

    ArgFieldName := '';
    if Check(tokIdentifier) and (FPeekTok.Kind = tokColon) then
    begin
      ArgFieldName := FCurTok.Value;
      Advance; // consume field name
      Advance; // consume ':'
    end;

    ArgExpr := ParseExpr;
    CallArg := TASTCallArg.Create(ArgLine, ArgCol, ArgOwn, ArgExpr);
    CallArg.FieldName := ArgFieldName;
    CallExpr.Args.Add(CallArg);
  until not Match(tokComma);
end;

function TAetherParser.ParsePrimaryExpr: TASTExpr;
var
  Id, PartA, PartB, FloatVal, PName, PType, CloseKw: string;
  Line, Col, DotPos, I, PLine, PCol: Integer;
  CallExpr: TASTCallExpr;
  ArgExpr, CondExpr, ThenExpr, ElseExpr: TASTExpr;
  IdxExpr: TASTIndexExpr;
  TupExpr: TASTTupleLiteralExpr;
  LambdaExpr: TASTLambdaExpr;
  POwn: TOwnershipKind;
  ParamNames, GenArgs: TStringList;
  SavedState: TParserState;
  TryGenOk: Boolean;
begin
  Line := FCurTok.Line;
  Col := FCurTok.Col;

  // Inline conditional expression: if cond then a else b
  if Match(tokIf) then
  begin
    CondExpr := ParseExpr;
    Expect(tokThen, 'Expected "then" in "if" conditional expression');
    ThenExpr := ParseExpr;
    Expect(tokElse, 'Expected "else" in "if" conditional expression');
    ElseExpr := ParseExpr;
    Exit(TASTIfExpr.Create(Line, Col, CondExpr, ThenExpr, ElseExpr));
  end;

  if Check(tokMatch) then
    Exit(ParseMatchExpr);

  // Lambda / closure expression: fn(params) [return Type | : Type] => expr  OR  begin ... end fn
  if Check(tokIdentifier) and SameText(FCurTok.Value, 'fn') and (FPeekTok.Kind = tokLParen) then
  begin
    Advance; // consume 'fn'
    Expect(tokLParen, 'Expected "(" after "fn"');
    LambdaExpr := TASTLambdaExpr.Create(Line, Col);
    ParamNames := TStringList.Create;
    try
      if not Check(tokRParen) then
      begin
        repeat
          POwn := owNone;
          if Match(tokTake) then POwn := owTake
          else if Match(tokBorrow) then POwn := owBorrow
          else if Match(tokMut) then
          begin
            Expect(tokBorrow, 'Expected "borrow" after "mut"');
            POwn := owMutBorrow;
          end;

          ParamNames.Clear;
          PLine := FCurTok.Line;
          PCol := FCurTok.Col;
          PName := Expect(tokIdentifier, 'Expected lambda parameter name').Value;
          ParamNames.Add(PName);
          while Match(tokComma) do
          begin
            // Peek ahead: if next looks like another bare param in a group (e.g. a, b: Int32), group it; else break if annotated/different
            if Check(tokIdentifier) and ((FPeekTok.Kind = tokComma) or (FPeekTok.Kind = tokColon) or (FPeekTok.Kind = tokRParen)) then
              ParamNames.Add(Expect(tokIdentifier).Value)
            else
              Break;
          end;

          PType := '';
          if Match(tokColon) then
            PType := ParseTypeRef();

          for I := 0 to ParamNames.Count - 1 do
            LambdaExpr.Params.Add(TASTParam.Create(PLine, PCol, ParamNames[I], PType, POwn));
        until (not Match(tokSemicolon)) and (not Match(tokComma));
      end;
      Expect(tokRParen, 'Expected ")" to close lambda parameters');

      if Match(tokReturn) or Match(tokColon) then
        LambdaExpr.ReturnType := ParseTypeRef();

      if Match(tokFatArrow) then
      begin
        LambdaExpr.BodyExpr := ParseExpr;
      end
      else
      begin
        Match(tokIs);
        Expect(tokBegin, 'Expected "=>" or "begin" in lambda body');
        while not Check(tokEnd) and not Check(tokEOF) do
        begin
          LambdaExpr.BodyStmts.Add(ParseStatement);
          Expect(tokSemicolon, 'Expected ";" after statement in lambda body');
        end;
        Expect(tokEnd, 'Expected "end fn" to close lambda block');
        CloseKw := Expect(tokIdentifier, 'Expected "fn" after "end" to close lambda block').Value;
        if not SameText(CloseKw, 'fn') then
          raise EAetherParserError.Create(Format('Expected "end fn" to close lambda block, found "end %s"', [CloseKw]), FCurTok.Line, FCurTok.Col);
      end;
      Result := LambdaExpr;
    except
      ParamNames.Free;
      LambdaExpr.Free;
      raise;
    end;
    ParamNames.Free;
  end
  // Literals, arrays/sets, parenthesized grouping / tuple literals, or identifiers/calls
  else if Check(tokIntLiteral) then
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
    // Empty Map literal [:], Map [k: v, ...], or Set/Array [e1, e2, ...] / []
    if Match(tokColon) then
    begin
      Expect(tokRBracket, 'Expected "]" after "[:" in empty map literal');
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
          Expect(tokColon, 'Expected ":" between key and value in map literal');
          TASTMapLiteralExpr(Result).Values.Add(ParseExpr);
        end;
        Expect(tokRBracket, 'Expected "]" to close map literal');
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
        Expect(tokRBracket, 'Expected "]" to close set literal');
      end;
    end;
  end
  else if Match(tokLParen) then
  begin
    // Parenthesized expression (Expr) or Tuple Literal (e0, e1, ...)
    ArgExpr := ParseExpr;
    if Match(tokComma) then
    begin
      TupExpr := TASTTupleLiteralExpr.Create(Line, Col);
      try
        TupExpr.Elements.Add(ArgExpr);
        if not Check(tokRParen) then
        begin
          TupExpr.Elements.Add(ParseExpr);
          while Match(tokComma) do
          begin
            if Check(tokRParen) then Break;
            TupExpr.Elements.Add(ParseExpr);
          end;
        end;
        Expect(tokRParen, 'Expected ")" to close tuple literal');
      except
        TupExpr.Free;
        raise;
      end;
      Result := TupExpr;
    end
    else
    begin
      Expect(tokRParen, 'Expected ")" to close expression');
      Result := ArgExpr;
    end;
  end
  else if Check(tokIdentifier) then
  begin
    Id := Expect(tokIdentifier).Value;
    GenArgs := TStringList.Create;
    try
      TryGenOk := False;
      if Check(tokLess) then
      begin
        SavedState := SaveParserState;
        try
          Advance; // consume '<'
          repeat
            GenArgs.Add(ParseTypeRef);
          until not Match(tokComma);
          if Match(tokGreater) and Check(tokLParen) then
            TryGenOk := True
          else
          begin
            GenArgs.Clear;
            RestoreParserState(SavedState);
          end;
        except
          GenArgs.Clear;
          RestoreParserState(SavedState);
          TryGenOk := False;
        end;
      end;

      // Function Call or Record Constructor (with optional <TypeArgs>)
      if Match(tokLParen) then
      begin
        CallExpr := TASTCallExpr.Create(Line, Col, Id);
        if TryGenOk then
          CallExpr.GenericArgs.AddStrings(GenArgs);
        ParseCallArgs(CallExpr);
        Expect(tokRParen, 'Expected ")" to close arguments');
        Result := CallExpr;
      end
      else
      begin
        Result := TASTIdentifierExpr.Create(Line, Col, Id);
      end;
    finally
      GenArgs.Free;
    end;
  end
  else
    raise EAetherParserError.Create(Format('Unexpected expression: "%s"', [FCurTok.Value]), Line, Col);

  // Postfix access on any primary expression: member, tuple .N, UFCS, indexing [i], dereference ^, propagation ?, or chained call (args)
  while Check(tokDot) or Check(tokLBracket) or Check(tokCaret) or Check(tokQuestion) or Check(tokLParen) do
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
    else if Match(tokLParen) then
    begin
      CallExpr := TASTCallExpr.Create(Line, Col, '');
      CallExpr.CalleeExpr := Result;
      CallExpr.IsIndirectCall := True;
      ParseCallArgs(CallExpr);
      Expect(tokRParen, 'Expected ")" to close arguments');
      Result := CallExpr;
    end
    else if Match(tokDot) then
    begin
      if Check(tokIntLiteral) then
      begin
        Result := TASTMemberAccessExpr.Create(Line, Col, Result, 'item' + FCurTok.Value);
        Advance;
      end
      else if Check(tokFloatLiteral) and (Pos('.', FCurTok.Value) > 0) then
      begin
        FloatVal := FCurTok.Value;
        DotPos := Pos('.', FloatVal);
        PartA := Copy(FloatVal, 1, DotPos - 1);
        PartB := Copy(FloatVal, DotPos + 1, Length(FloatVal));
        Advance;
        Result := TASTMemberAccessExpr.Create(Line, Col, Result, 'item' + PartA);
        Result := TASTMemberAccessExpr.Create(Line, Col, Result, 'item' + PartB);
      end
      else
      begin
        Id := Expect(tokIdentifier, 'Expected identifier after "."').Value;
        if Match(tokLParen) then
        begin
          // UFCS: expr.Method(args...) is transparently lowered to Method(borrow expr, args...)
          CallExpr := TASTCallExpr.Create(Line, Col, Id);
          CallExpr.IsQualified := True;
          CallExpr.Args.Add(TASTCallArg.Create(Line, Col, owBorrow, Result));
          ParseCallArgs(CallExpr);
          Expect(tokRParen, 'Expected ")" to close arguments');
          Result := CallExpr;
        end
        else
        begin
          Result := TASTMemberAccessExpr.Create(Line, Col, Result, Id);
        end;
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
      Expect(tokRBracket, 'Expected "]" to close array indexer');
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
  Expect(tokModule, 'Every Aether file must start with "module <Name>;"');
  ModName := Expect(tokIdentifier, 'Expected module name').Value;
  Expect(tokSemicolon, 'Expected ";" after module name');

  Result := TASTModule.Create(MLine, MCol, ModName);
  Result.DocComment := ModDoc;
  InitAttributes(PendingAttrs);
  try
    // Initial imports
    while Check(tokImport) do
      ParseImport(Result);

    if Check(tokInterface) then
    begin
      // Object Pascal Unit structure: interface ... implementation ... [initialization] [finalization] end <ModName>.
      Result.IsUnit := True;
      Result.HasExplicitPub := True;
      Advance; // consume 'interface'

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
            raise EAetherParserError.Create('Private declarations ("priv") must be in the "implementation" section, not "interface"', FCurTok.Line, FCurTok.Col)
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
          raise EAetherParserError.Create(Format('Unexpected declaration in "interface" section: "%s"', [FCurTok.Value]), FCurTok.Line, FCurTok.Col);
      end;

      Expect(tokImplementation, Format('Expected "implementation" in unit "%s"', [ModName]));

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
              raise EAetherParserError.Create(Format('Mismatched signature in implementation for "%s" (function/procedure)', [ImplFunc.Name]), ImplFunc.Line, ImplFunc.Col);
            if (not SameText(StubFunc.GenericParams.CommaText, ImplFunc.GenericParams.CommaText)) or
               (not SameText(StubFunc.TraitBounds.CommaText, ImplFunc.TraitBounds.CommaText)) then
              raise EAetherParserError.Create(Format('Mismatched generic parameter in implementation for "%s"', [ImplFunc.Name]), ImplFunc.Line, ImplFunc.Col);
            if not SameText(StubFunc.ReturnType, ImplFunc.ReturnType) then
              raise EAetherParserError.Create(Format('Mismatched return type in implementation for "%s": expected "%s", found "%s"',
                [ImplFunc.Name, StubFunc.ReturnType, ImplFunc.ReturnType]), ImplFunc.Line, ImplFunc.Col);
            if StubFunc.Params.Count <> ImplFunc.Params.Count then
              raise EAetherParserError.Create(Format('Mismatched parameter count in implementation for "%s": expected %d, found %d',
                [ImplFunc.Name, StubFunc.Params.Count, ImplFunc.Params.Count]), ImplFunc.Line, ImplFunc.Col);
            for J := 0 to StubFunc.Params.Count - 1 do
            begin
              if (TASTParam(StubFunc.Params[J]).Ownership <> TASTParam(ImplFunc.Params[J]).Ownership) or
                 (not SameText(TASTParam(StubFunc.Params[J]).TypeName, TASTParam(ImplFunc.Params[J]).TypeName)) then
                raise EAetherParserError.Create(Format('Parameter %d of "%s" in implementation differs from interface signature',
                  [J + 1, ImplFunc.Name]), ImplFunc.Line, ImplFunc.Col);
            end;

            if (StubFunc.Requires.Count > 0) or (StubFunc.Ensures.Count > 0) then
            begin
              if (ImplFunc.Requires.Count > 0) or (ImplFunc.Ensures.Count > 0) then
                raise EAetherParserError.Create(Format('Contracts for "%s" must be declared only in the "interface" section, without duplication in "implementation"',
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
          raise EAetherParserError.Create(Format('Unexpected declaration in "implementation" section: "%s"', [FCurTok.Value]), FCurTok.Line, FCurTok.Col);
      end;

      // Ensure every signature declared in interface was implemented
      for I := 0 to Result.Functions.Count - 1 do
      begin
        StubFunc := TASTFunction(Result.Functions[I]);
        if StubFunc.IsInterfaceDecl and (not StubFunc.IsExtern) then
          raise EAetherParserError.Create(Format('Routine "%s" declared in "interface" section was not implemented in "implementation" section',
            [StubFunc.Name]), StubFunc.Line, StubFunc.Col);
      end;

      if Match(tokInitialization) then
      begin
        while not Check(tokFinalization) and not Check(tokEnd) and not Check(tokEOF) do
        begin
          Result.InitBody.Add(ParseStatement);
          Expect(tokSemicolon, 'Expected ";" after statement in initialization section');
        end;
      end;

      if Match(tokFinalization) then
      begin
        while not Check(tokEnd) and not Check(tokEOF) do
        begin
          Result.FiniBody.Add(ParseStatement);
          Expect(tokSemicolon, 'Expected ";" after statement in finalization section');
        end;
      end;

      Expect(tokEnd, Format('Expected "end %s." to close unit', [ModName]));
      CloseMod := Expect(tokIdentifier, Format('Expected name "%s" after "end"', [ModName])).Value;
      if not SameText(CloseMod, ModName) then
        raise EAetherParserError.Create(Format('Mismatched unit closing: expected "end %s.", but found "end %s."', [ModName, CloseMod]), FCurTok.Line, FCurTok.Col);
      Expect(tokDot, Format('Expected "." after "end %s"', [ModName]));
    end
    else
    begin
      // Executable module with "program Main;"
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
          raise EAetherParserError.Create(Format('Unexpected declaration in module: "%s"', [FCurTok.Value]), FCurTok.Line, FCurTok.Col);
      end;

      if not Assigned(Result.ProgramBlock) then
        raise EAetherParserError.Create(Format('Module "%s" without "program Main;" must declare the Object Pascal Unit structure ("interface" ... "implementation" ... end %s.)',
          [ModName, ModName]), FCurTok.Line, FCurTok.Col);
    end;

    // Expand automatic derivations (Debug, JSON, Clone, Equals)
    ExpandDerives(Result);
  except
    FreeAttributes(PendingAttrs);
    Result.Free;
    raise;
  end;
  FreeAttributes(PendingAttrs);
end;

end.
