unit uAetherLSP;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  SysUtils, Classes, Math, fpjson, jsonparser,
  uAetherTokens, uAetherLexer, uAetherAST, uAetherParser,
  uAetherTypeChecker, uAetherBorrowChecker, uAetherFormatter;

procedure RunAetherLSP;

implementation

type
  TDocumentRecord = record
    URI: string;
    Text: string;
    Version: Integer;
    AST: TASTModule;
  end;

var
  FDocuments: array of TDocumentRecord;

function FindDocIndex(const AURI: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FDocuments) do
    if FDocuments[I].URI = AURI then
      Exit(I);
end;

procedure SetDoc(const AURI, AText: string; AVersion: Integer);
var
  Idx: Integer;
begin
  Idx := FindDocIndex(AURI);
  if Idx < 0 then
  begin
    SetLength(FDocuments, Length(FDocuments) + 1);
    Idx := High(FDocuments);
    FDocuments[Idx].URI := AURI;
    FDocuments[Idx].AST := nil;
  end;
  FDocuments[Idx].Text := AText;
  FDocuments[Idx].Version := AVersion;
end;

procedure RemoveDoc(const AURI: string);
var
  Idx, I: Integer;
begin
  Idx := FindDocIndex(AURI);
  if Idx >= 0 then
  begin
    if Assigned(FDocuments[Idx].AST) then
      FreeAndNil(FDocuments[Idx].AST);

    for I := Idx to High(FDocuments) - 1 do
      FDocuments[I] := FDocuments[I + 1];
    SetLength(FDocuments, Length(FDocuments) - 1);
  end;
end;

function ReadLSPMessage: UTF8String;
var
  HeaderBuf: string;
  C: Char;
  BytesRead: Integer;
  ContentLength, SepPos, Code, LineEndPos: Integer;
  LenStr: string;
  Payload: UTF8String;
begin
  Result := '';
  HeaderBuf := '';
  ContentLength := 0;

  // Le cabecalhos ate encontrar sequencia vazia CRLF CRLF
  while True do
  begin
    BytesRead := FileRead(StdInputHandle, C, 1);
    if BytesRead <= 0 then Exit(''); // Stream fechado
    HeaderBuf := HeaderBuf + C;
    if (Length(HeaderBuf) >= 4) and (Copy(HeaderBuf, Length(HeaderBuf) - 3, 4) = #13#10#13#10) then
      Break;
    if (Length(HeaderBuf) >= 2) and (Copy(HeaderBuf, Length(HeaderBuf) - 1, 2) = #10#10) then
      Break;
  end;

  SepPos := Pos('Content-Length:', HeaderBuf);
  if SepPos > 0 then
  begin
    LenStr := Copy(HeaderBuf, SepPos + 15, Length(HeaderBuf));
    LineEndPos := Pos(#13, LenStr);
    if LineEndPos = 0 then LineEndPos := Pos(#10, LenStr);
    if LineEndPos > 0 then
      LenStr := Copy(LenStr, 1, LineEndPos - 1);
    Val(Trim(LenStr), ContentLength, Code);
  end;

  if ContentLength <= 0 then Exit('');

  SetLength(Payload, ContentLength);
  BytesRead := 0;
  while BytesRead < ContentLength do
  begin
    Code := FileRead(StdInputHandle, Payload[BytesRead + 1], ContentLength - BytesRead);
    if Code <= 0 then Break;
    Inc(BytesRead, Code);
  end;

  Result := Payload;
end;

procedure SendLSPMessage(const Payload: UTF8String);
var
  Header: UTF8String;
  Msg: UTF8String;
  Written, Total, Res: Integer;
begin
  Header := Format('Content-Length: %d'#13#10#13#10, [Length(Payload)]);
  Msg := Header + Payload;
  Total := Length(Msg);
  Written := 0;
  while Written < Total do
  begin
    Res := FileWrite(StdOutputHandle, Msg[Written + 1], Total - Written);
    if Res <= 0 then Break;
    Inc(Written, Res);
  end;
end;

procedure SendLSPResponse(Id: TJSONData; ResultData: TJSONData; ErrorData: TJSONData = nil);
var
  Resp: TJSONObject;
begin
  Resp := TJSONObject.Create;
  try
    Resp.Add('jsonrpc', '2.0');
    if Assigned(Id) then
      Resp.Add('id', Id.Clone)
    else
      Resp.Add('id', TJSONNull.Create);

    if Assigned(ErrorData) then
      Resp.Add('error', ErrorData)
    else if Assigned(ResultData) then
      Resp.Add('result', ResultData)
    else
      Resp.Add('result', TJSONNull.Create);

    SendLSPMessage(Resp.AsJSON);
  finally
    Resp.Free;
  end;
end;

procedure SendLSPNotification(const Method: string; Params: TJSONData);
var
  Notif: TJSONObject;
begin
  Notif := TJSONObject.Create;
  try
    Notif.Add('jsonrpc', '2.0');
    Notif.Add('method', Method);
    if Assigned(Params) then
      Notif.Add('params', Params);
    SendLSPMessage(Notif.AsJSON);
  finally
    Notif.Free;
  end;
end;

procedure ValidateAndPublishDiagnostics(const URI, SourceText: string);
var
  Lexer: TAetherLexer;
  Parser: TAetherParser;
  TypeChecker: TAetherTypeChecker;
  BorrowChecker: TAetherBorrowChecker;
  ModuleNode: TASTModule;
  DiagsArr: TJSONArray;
  ParamsObj, DiagObj, RangeObj, StartPos, EndPos: TJSONObject;
  Idx: Integer;
  ErrLine, ErrCol: Integer;
  ErrMsg, ErrCode: string;
begin
  DiagsArr := TJSONArray.Create;
  ModuleNode := nil;

  try
    Lexer := TAetherLexer.Create(SourceText);
    Parser := TAetherParser.Create(Lexer);
    try
      ModuleNode := Parser.ParseModule;
    finally
      Parser.Free;
      Lexer.Free;
    end;

    // Salva AST imediatamente em memoria para autocompletar, hover e go-to-definition
    Idx := FindDocIndex(URI);
    if Idx >= 0 then
    begin
      if Assigned(FDocuments[Idx].AST) then FDocuments[Idx].AST.Free;
      FDocuments[Idx].AST := ModuleNode;
      ModuleNode := nil; // Posse transferida para FDocuments
    end;

    TypeChecker := TAetherTypeChecker.Create;
    try
      if (Idx >= 0) and Assigned(FDocuments[Idx].AST) then
      begin
        TypeChecker.CheckModule(FDocuments[Idx].AST);
        BorrowChecker := TAetherBorrowChecker.Create(TypeChecker.Symbols);
        try
          BorrowChecker.CheckModule(FDocuments[Idx].AST);
        finally
          BorrowChecker.Free;
        end;
      end;
    finally
      TypeChecker.Free;
    end;

  except
    on E: EAetherBorrowError do
    begin
      ErrLine := Math.Max(1, E.Line);
      ErrCol := Math.Max(1, E.Col);
      ErrCode := E.Code;
      ErrMsg := E.Message;

      DiagObj := TJSONObject.Create;
      RangeObj := TJSONObject.Create;
      StartPos := TJSONObject.Create(['line', ErrLine - 1, 'character', ErrCol - 1]);
      EndPos := TJSONObject.Create(['line', ErrLine - 1, 'character', ErrCol + 4]);
      RangeObj.Add('start', StartPos);
      RangeObj.Add('end', EndPos);
      DiagObj.Add('range', RangeObj);
      DiagObj.Add('severity', 1); // 1 = Error
      DiagObj.Add('code', ErrCode);
      DiagObj.Add('source', 'aether-lsp');
      DiagObj.Add('message', ErrMsg);
      DiagsArr.Add(DiagObj);
    end;
    on E: EAetherTypeError do
    begin
      ErrLine := Math.Max(1, E.Line);
      ErrCol := Math.Max(1, E.Col);
      ErrCode := E.Code;
      ErrMsg := E.Message;

      DiagObj := TJSONObject.Create;
      RangeObj := TJSONObject.Create;
      StartPos := TJSONObject.Create(['line', ErrLine - 1, 'character', ErrCol - 1]);
      EndPos := TJSONObject.Create(['line', ErrLine - 1, 'character', ErrCol + 4]);
      RangeObj.Add('start', StartPos);
      RangeObj.Add('end', EndPos);
      DiagObj.Add('range', RangeObj);
      DiagObj.Add('severity', 1);
      DiagObj.Add('code', ErrCode);
      DiagObj.Add('source', 'aether-lsp');
      DiagObj.Add('message', ErrMsg);
      DiagsArr.Add(DiagObj);
    end;
    on E: EAetherParserError do
    begin
      ErrLine := Math.Max(1, E.Line);
      ErrCol := Math.Max(1, E.Col);

      DiagObj := TJSONObject.Create;
      RangeObj := TJSONObject.Create;
      StartPos := TJSONObject.Create(['line', ErrLine - 1, 'character', ErrCol - 1]);
      EndPos := TJSONObject.Create(['line', ErrLine - 1, 'character', ErrCol + 4]);
      RangeObj.Add('start', StartPos);
      RangeObj.Add('end', EndPos);
      DiagObj.Add('range', RangeObj);
      DiagObj.Add('severity', 1);
      DiagObj.Add('code', 'E0001');
      DiagObj.Add('source', 'aether-lsp');
      DiagObj.Add('message', E.Message);
      DiagsArr.Add(DiagObj);
    end;
    on E: EAetherLexerError do
    begin
      ErrLine := Math.Max(1, E.Line);
      ErrCol := Math.Max(1, E.Col);

      DiagObj := TJSONObject.Create;
      RangeObj := TJSONObject.Create;
      StartPos := TJSONObject.Create(['line', ErrLine - 1, 'character', ErrCol - 1]);
      EndPos := TJSONObject.Create(['line', ErrLine - 1, 'character', ErrCol + 4]);
      RangeObj.Add('start', StartPos);
      RangeObj.Add('end', EndPos);
      DiagObj.Add('range', RangeObj);
      DiagObj.Add('severity', 1);
      DiagObj.Add('code', 'E0000');
      DiagObj.Add('source', 'aether-lsp');
      DiagObj.Add('message', E.Message);
      DiagsArr.Add(DiagObj);
    end;
    on E: Exception do
    begin
      // Erro generico
    end;
  end;

  if Assigned(ModuleNode) then
    ModuleNode.Free;

  ParamsObj := TJSONObject.Create;
  ParamsObj.Add('uri', URI);
  ParamsObj.Add('diagnostics', DiagsArr);
  SendLSPNotification('textDocument/publishDiagnostics', ParamsObj);
end;

function FormatFunctionSignature(Func: TASTFunction): string;
var
  I: Integer;
  ParamsStr: string;
  P: TASTParam;
begin
  ParamsStr := '';
  for I := 0 to Func.Params.Count - 1 do
  begin
    P := TASTParam(Func.Params[I]);
    if I > 0 then ParamsStr := ParamsStr + '; ';
    ParamsStr := ParamsStr + OwnershipToString(P.Ownership) + P.Name + ': ' + P.TypeName;
  end;
  Result := Format('function %s(%s): %s', [Func.Name, ParamsStr, Func.ReturnType]);
end;

function HandleCompletion(Params: TJSONObject): TJSONArray;
var
  Items: TJSONArray;
  procedure AddItem(const LabelStr: string; Kind: Integer; const DetailStr: string = '');
  var
    Item: TJSONObject;
  begin
    Item := TJSONObject.Create;
    Item.Add('label', LabelStr);
    Item.Add('kind', Kind); // 14 = Keyword, 7 = Class/Type, 3 = Function, 8 = Interface/Trait
    if DetailStr <> '' then
      Item.Add('detail', DetailStr);
    Items.Add(Item);
  end;
var
  URI: string;
  Idx, I, J: Integer;
  ModNode: TASTModule;
  Func: TASTFunction;
  Rec: TASTRecordDecl;
  Enm: TASTEnumDecl;
  TraitDecl: TASTTraitDecl;
  ImplDecl: TASTImplDecl;
begin
  Items := TJSONArray.Create;

  // Palavras-chave fundamentais
  AddItem('module', 14, 'Declaração de Módulo');
  AddItem('program', 14, 'Bloco de Programa Principal');
  AddItem('import', 14, 'Importar Módulo Aether');
  AddItem('extern', 14, 'Declarar Função Externa C');
  AddItem('function', 14, 'Declaração de Função');
  AddItem('contract', 14, 'Bloco de Contratos (require / ensure)');
  AddItem('require', 14, 'Pré-condição Contratual');
  AddItem('ensure', 14, 'Pós-condição Contratual');
  AddItem('type', 14, 'Seção de Tipos');
  AddItem('record', 14, 'Tipo Estruturado Record');
  AddItem('enum', 14, 'Tipo Algébrico Enum');
  AddItem('trait', 14, 'Declaração de Interface/Trait');
  AddItem('impl', 14, 'Implementação de Trait para Tipo');
  AddItem('for', 14, 'Cláusula de Associação (impl Trait for Tipo)');
  AddItem('var', 14, 'Variável Mutável');
  AddItem('let', 14, 'Variável Imutável');
  AddItem('begin', 14, 'Início de Bloco');
  AddItem('end', 14, 'Fim de Bloco');
  AddItem('if', 14, 'Controle Condicional');
  AddItem('then', 14, 'Cláusula Then');
  AddItem('else', 14, 'Cláusula Else');
  AddItem('while', 14, 'Laço de Repetição');
  AddItem('match', 14, 'Casamento de Padrões Exaustivo');
  AddItem('case', 14, 'Caso do Match');
  AddItem('return', 14, 'Retorno de Função');

  // Ownership & Borrowing
  AddItem('borrow', 14, 'Empréstimo Imutável (Somente Leitura)');
  AddItem('take', 14, 'Transferência de Posse (Move)');
  AddItem('mut borrow', 14, 'Empréstimo Mutável Exclusivo');
  AddItem('own', 14, 'Modificador de Posse Exclusiva');

  // Tipos Primitivos
  AddItem('Int8', 7, 'Inteiro 8-bit com sinal');
  AddItem('Int16', 7, 'Inteiro 16-bit com sinal');
  AddItem('Int32', 7, 'Inteiro 32-bit com sinal');
  AddItem('Int64', 7, 'Inteiro 64-bit com sinal');
  AddItem('UInt8', 7, 'Inteiro 8-bit sem sinal');
  AddItem('UInt16', 7, 'Inteiro 16-bit sem sinal');
  AddItem('UInt32', 7, 'Inteiro 32-bit sem sinal');
  AddItem('UInt64', 7, 'Inteiro 64-bit sem sinal');
  AddItem('Float32', 7, 'Ponto Flutuante 32-bit');
  AddItem('Float64', 7, 'Ponto Flutuante 64-bit');
  AddItem('Bool', 7, 'Booleano (true/false)');
  AddItem('String', 7, 'Texto UTF-8');
  AddItem('Void', 7, 'Retorno Vazio');

  // Mônades
  AddItem('Result', 7, 'Mônade de Resultado Result<T, E>');
  AddItem('Option', 7, 'Mônade Opcional Option<T>');
  AddItem('Ok', 3, 'Construtor de Sucesso: Ok(valor)');
  AddItem('Err', 3, 'Construtor de Erro: Err(erro)');
  AddItem('Some', 3, 'Construtor Opcional Presente: Some(valor)');
  AddItem('None', 14, 'Ausência de Valor: None');
  AddItem('PrintLn', 3, 'Imprime linha formatada no console');

  // Simbolos do documento atual
  if Assigned(Params) and Assigned(Params.Find('textDocument')) then
  begin
    URI := (Params.Find('textDocument') as TJSONObject).Get('uri', '');
    Idx := FindDocIndex(URI);
    if (Idx >= 0) and Assigned(FDocuments[Idx].AST) then
    begin
      ModNode := FDocuments[Idx].AST;

      // Records e Enums
      for I := 0 to ModNode.Types.Count - 1 do
      begin
        if ModNode.Types[I] is TASTRecordDecl then
        begin
          Rec := TASTRecordDecl(ModNode.Types[I]);
          AddItem(Rec.Name, 7, 'Record Definido no Módulo');
        end
        else if ModNode.Types[I] is TASTEnumDecl then
        begin
          Enm := TASTEnumDecl(ModNode.Types[I]);
          AddItem(Enm.Name, 7, 'Enum Algébrico no Módulo');
        end;
      end;

      // Traits declaradas
      for I := 0 to ModNode.Traits.Count - 1 do
      begin
        TraitDecl := TASTTraitDecl(ModNode.Traits[I]);
        AddItem(TraitDecl.Name, 8, 'Trait Declarada no Módulo');
      end;

      // Funcoes do modulo com assinatura completa
      for I := 0 to ModNode.Functions.Count - 1 do
      begin
        Func := TASTFunction(ModNode.Functions[I]);
        AddItem(Func.Name, 3, FormatFunctionSignature(Func));
      end;

      // Metodos implementados em Impls (UFCS / Trait Methods)
      for I := 0 to ModNode.Impls.Count - 1 do
      begin
        ImplDecl := TASTImplDecl(ModNode.Impls[I]);
        for J := 0 to ImplDecl.Methods.Count - 1 do
        begin
          Func := TASTFunction(ImplDecl.Methods[J]);
          AddItem(Func.Name, 3, Format('%s (impl %s for %s)', [FormatFunctionSignature(Func), ImplDecl.TraitName, ImplDecl.TargetTypeName]));
        end;
      end;
    end;
  end;

  Result := Items;
end;

function GetWordAt(const Text: string; Line, Col: Integer): string;
var
  Lines: TStringList;
  L: string;
  StartPos, EndPos: Integer;
begin
  Result := '';
  Lines := TStringList.Create;
  try
    Lines.Text := Text;
    if (Line < 0) or (Line >= Lines.Count) then Exit('');
    L := Lines[Line];
    if (Col < 0) or (Col >= Length(L)) then Exit('');

    StartPos := Col + 1;
    while (StartPos > 1) and (L[StartPos - 1] in ['a'..'z', 'A'..'Z', '0'..'9', '_']) do
      Dec(StartPos);

    EndPos := Col + 1;
    while (EndPos <= Length(L)) and (L[EndPos] in ['a'..'z', 'A'..'Z', '0'..'9', '_']) do
      Inc(EndPos);

    Result := Copy(L, StartPos, EndPos - StartPos);
  finally
    Lines.Free;
  end;
end;

function HandleHover(Params: TJSONObject): TJSONObject;
var
  URI: string;
  PosObj: TJSONObject;
  Line, Col, Idx, I, J: Integer;
  Word: string;
  ModNode: TASTModule;
  Func: TASTFunction;
  Rec: TASTRecordDecl;
  Enm: TASTEnumDecl;
  TraitDecl: TASTTraitDecl;
  ImplDecl: TASTImplDecl;
  ParamNode: TASTParam;
  VarNode: TASTVarDecl;
  ContentsObj: TJSONObject;
  InfoText, SubText: string;
begin
  Result := nil;
  if not Assigned(Params) then Exit;
  URI := (Params.Find('textDocument') as TJSONObject).Get('uri', '');
  PosObj := Params.Find('position') as TJSONObject;
  if not Assigned(PosObj) then Exit;
  Line := PosObj.Get('line', 0);
  Col := PosObj.Get('character', 0);

  Idx := FindDocIndex(URI);
  if Idx < 0 then Exit;

  Word := GetWordAt(FDocuments[Idx].Text, Line, Col);
  if Word = '' then Exit;

  InfoText := '';

  // 1. Palavras-chave de Posse e Concorrencia
  if LowerCase(Word) = 'borrow' then
    InfoText := '**borrow (Empréstimo Imutável)**'#10#10 +
                'Garante acesso somente-leitura ao dado sem transferir posse. Múltiplos leitores permitidos simultaneamente.'
  else if LowerCase(Word) = 'take' then
    InfoText := '**take (Transferência de Posse / Move)**'#10#10 +
                'Move a posse do dado permanentemente. A variável de origem torna-se inválida (*Use-After-Move* é impedido).'
  else if LowerCase(Word) = 'mut' then
    InfoText := '**mut (Mutabilidade Exclusiva)**'#10#10 +
                'Quando combinado com `mut borrow`, garante um único escritor ativo por vez, prevenindo corridas de dados (*data races*).'
  else if LowerCase(Word) = 'own' then
    InfoText := '**own (Posse de Memória / Ownership)**'#10#10 +
                'Modificador que explicita posse sobre um recurso ou ponteiro em memória.'
  else if LowerCase(Word) = 'trait' then
    InfoText := '**trait (Interface / Contrato de Tipos)**'#10#10 +
                'Define um conjunto de assinaturas de métodos e regras contratuais que tipos concretos podem implementar via `impl Trait for Tipo`.'
  else if LowerCase(Word) = 'impl' then
    InfoText := '**impl (Implementação de Trait)**'#10#10 +
                'Implementa os métodos e comportamentos exigidos por uma `trait` para um tipo record específico.'
  else if LowerCase(Word) = 'contract' then
    InfoText := '**contract (Contrato Formal)**'#10#10 +
                'Especifica pré-condições (`require`) e pós-condições (`ensure`) validadas pelo compilador Aether.'
  else if LowerCase(Word) = 'result' then
    InfoText := '**Result<T, E> (Mônade de Sucesso/Falha)**'#10#10 +
                'Tipo canônico para operações que podem falhar. Trate exaustivamente com `match` (`Ok(v)` ou `Err(e)`).'
  else if LowerCase(Word) = 'option' then
    InfoText := '**Option<T> (Mônade Opcional)**'#10#10 +
                'Elimina ponteiros nulos (`nil`/`null`). Contém `Some(v)` quando presente ou `None` quando ausente.';

  // 2. Busca na AST do documento atual
  if (InfoText = '') and Assigned(FDocuments[Idx].AST) then
  begin
    ModNode := FDocuments[Idx].AST;

    // Funcoes do modulo
    for I := 0 to ModNode.Functions.Count - 1 do
    begin
      Func := TASTFunction(ModNode.Functions[I]);
      if SameText(Func.Name, Word) then
      begin
        InfoText := Format('```aether'#10'%s'#10'```', [FormatFunctionSignature(Func)]);
        if Func.Requires.Count > 0 then
          InfoText := InfoText + #10#10'**Contrato (require):** Pré-condições ativas de validação.';
        if Func.Ensures.Count > 0 then
          InfoText := InfoText + #10#10'**Contrato (ensure):** Pós-condições ativas de validação.';
        Break;
      end;

      // Parâmetros da função
      for J := 0 to Func.Params.Count - 1 do
      begin
        ParamNode := TASTParam(Func.Params[J]);
        if SameText(ParamNode.Name, Word) then
        begin
          InfoText := Format('```aether'#10'param %s%s: %s'#10'```'#10#10'*Parâmetro da função `%s`*',
            [OwnershipToString(ParamNode.Ownership), ParamNode.Name, ParamNode.TypeName, Func.Name]);
          Break;
        end;
      end;
      if InfoText <> '' then Break;

      // Variáveis locais da função
      for J := 0 to Func.LocalVars.Count - 1 do
      begin
        VarNode := TASTVarDecl(Func.LocalVars[J]);
        if SameText(VarNode.Name, Word) then
        begin
          InfoText := Format('```aether'#10'var %s: %s'#10'```'#10#10'*Variável local da função `%s`*',
            [VarNode.Name, VarNode.TypeName, Func.Name]);
          Break;
        end;
      end;
      if InfoText <> '' then Break;
    end;

    // Traits do modulo
    if InfoText = '' then
    begin
      for I := 0 to ModNode.Traits.Count - 1 do
      begin
        TraitDecl := TASTTraitDecl(ModNode.Traits[I]);
        if SameText(TraitDecl.Name, Word) then
        begin
          SubText := '';
          for J := 0 to TraitDecl.Methods.Count - 1 do
            SubText := SubText + '    ' + FormatFunctionSignature(TASTFunction(TraitDecl.Methods[J])) + ';'#10;
          InfoText := Format('```aether'#10'trait %s'#10'%send'#10'```', [TraitDecl.Name, SubText]);
          Break;
        end;
      end;
    end;

    // Metodos em Impls
    if InfoText = '' then
    begin
      for I := 0 to ModNode.Impls.Count - 1 do
      begin
        ImplDecl := TASTImplDecl(ModNode.Impls[I]);
        for J := 0 to ImplDecl.Methods.Count - 1 do
        begin
          Func := TASTFunction(ImplDecl.Methods[J]);
          if SameText(Func.Name, Word) then
          begin
            InfoText := Format('```aether'#10'%s'#10'```'#10#10'*Implementação da trait `%s` para o tipo `%s`*',
              [FormatFunctionSignature(Func), ImplDecl.TraitName, ImplDecl.TargetTypeName]);
            Break;
          end;
        end;
        if InfoText <> '' then Break;
      end;
    end;

    // Records e Enums
    if InfoText = '' then
    begin
      for I := 0 to ModNode.Types.Count - 1 do
      begin
        if ModNode.Types[I] is TASTRecordDecl then
        begin
          Rec := TASTRecordDecl(ModNode.Types[I]);
          if SameText(Rec.Name, Word) then
          begin
            SubText := '';
            for J := 0 to Rec.Fields.Count - 1 do
              SubText := SubText + Format('    %s: %s;'#10, [TASTRecordField(Rec.Fields[J]).Name, TASTRecordField(Rec.Fields[J]).TypeName]);
            InfoText := Format('```aether'#10'type %s = record'#10'%send;'#10'```', [Rec.Name, SubText]);
            Break;
          end;
        end
        else if ModNode.Types[I] is TASTEnumDecl then
        begin
          Enm := TASTEnumDecl(ModNode.Types[I]);
          if SameText(Enm.Name, Word) then
          begin
            SubText := '';
            for J := 0 to Enm.Variants.Count - 1 do
            begin
              if J > 0 then SubText := SubText + ','#10;
              SubText := SubText + '    ' + TASTEnumVariant(Enm.Variants[J]).Name;
            end;
            InfoText := Format('```aether'#10'type %s = enum'#10'%s'#10'end;'#10'```', [Enm.Name, SubText]);
            Break;
          end;
        end;
      end;
    end;

    // Variaveis do bloco principal do programa
    if (InfoText = '') and Assigned(ModNode.ProgramBlock) then
    begin
      for I := 0 to ModNode.ProgramBlock.LocalVars.Count - 1 do
      begin
        VarNode := TASTVarDecl(ModNode.ProgramBlock.LocalVars[I]);
        if SameText(VarNode.Name, Word) then
        begin
          InfoText := Format('```aether'#10'var %s: %s'#10'```'#10#10'*Variável do programa principal*',
            [VarNode.Name, VarNode.TypeName]);
          Break;
        end;
      end;
    end;
  end;

  if InfoText <> '' then
  begin
    Result := TJSONObject.Create;
    ContentsObj := TJSONObject.Create(['kind', 'markdown', 'value', InfoText]);
    Result.Add('contents', ContentsObj);
  end;
end;

function HandleDefinition(Params: TJSONObject): TJSONObject;
var
  URI: string;
  PosObj: TJSONObject;
  Line, Col, Idx, I, J: Integer;
  Word: string;
  ModNode: TASTModule;
  Func: TASTFunction;
  Rec: TASTRecordDecl;
  Enm: TASTEnumDecl;
  TraitDecl: TASTTraitDecl;
  ImplDecl: TASTImplDecl;
  DefLine, DefCol: Integer;
  RangeObj, StartPos, EndPos: TJSONObject;
begin
  Result := nil;
  if not Assigned(Params) then Exit;
  URI := (Params.Find('textDocument') as TJSONObject).Get('uri', '');
  PosObj := Params.Find('position') as TJSONObject;
  if not Assigned(PosObj) then Exit;
  Line := PosObj.Get('line', 0);
  Col := PosObj.Get('character', 0);

  Idx := FindDocIndex(URI);
  if (Idx < 0) or not Assigned(FDocuments[Idx].AST) then Exit;

  Word := GetWordAt(FDocuments[Idx].Text, Line, Col);
  if Word = '' then Exit;

  DefLine := -1;
  DefCol := -1;
  ModNode := FDocuments[Idx].AST;

  // 1. Busca em funcoes do modulo
  for I := 0 to ModNode.Functions.Count - 1 do
  begin
    Func := TASTFunction(ModNode.Functions[I]);
    if SameText(Func.Name, Word) then
    begin
      DefLine := Func.Line - 1;
      DefCol := Func.Col - 1;
      Break;
    end;
  end;

  // 2. Busca em Traits
  if DefLine < 0 then
  begin
    for I := 0 to ModNode.Traits.Count - 1 do
    begin
      TraitDecl := TASTTraitDecl(ModNode.Traits[I]);
      if SameText(TraitDecl.Name, Word) then
      begin
        DefLine := TraitDecl.Line - 1;
        DefCol := TraitDecl.Col - 1;
        Break;
      end;
    end;
  end;

  // 3. Busca em Metodos de Impls
  if DefLine < 0 then
  begin
    for I := 0 to ModNode.Impls.Count - 1 do
    begin
      ImplDecl := TASTImplDecl(ModNode.Impls[I]);
      for J := 0 to ImplDecl.Methods.Count - 1 do
      begin
        Func := TASTFunction(ImplDecl.Methods[J]);
        if SameText(Func.Name, Word) then
        begin
          DefLine := Func.Line - 1;
          DefCol := Func.Col - 1;
          Break;
        end;
      end;
      if DefLine >= 0 then Break;
    end;
  end;

  // 4. Busca em Tipos (Records e Enums)
  if DefLine < 0 then
  begin
    for I := 0 to ModNode.Types.Count - 1 do
    begin
      if ModNode.Types[I] is TASTRecordDecl then
      begin
        Rec := TASTRecordDecl(ModNode.Types[I]);
        if SameText(Rec.Name, Word) then
        begin
          DefLine := Rec.Line - 1;
          DefCol := Rec.Col - 1;
          Break;
        end;
      end
      else if ModNode.Types[I] is TASTEnumDecl then
      begin
        Enm := TASTEnumDecl(ModNode.Types[I]);
        if SameText(Enm.Name, Word) then
        begin
          DefLine := Enm.Line - 1;
          DefCol := Enm.Col - 1;
          Break;
        end;
      end;
    end;
  end;

  if DefLine >= 0 then
  begin
    Result := TJSONObject.Create;
    Result.Add('uri', URI);
    RangeObj := TJSONObject.Create;
    StartPos := TJSONObject.Create(['line', DefLine, 'character', DefCol]);
    EndPos := TJSONObject.Create(['line', DefLine, 'character', DefCol + Length(Word)]);
    RangeObj.Add('start', StartPos);
    RangeObj.Add('end', EndPos);
    Result.Add('range', RangeObj);
  end;
end;

function HandleFormatting(Params: TJSONObject): TJSONArray;
var
  URI, SourceText, FormattedText: string;
  Idx, TotalLines, LastLineLen: Integer;
  Lines: TStringList;
  Item, RangeObj, StartPos, EndPos: TJSONObject;
begin
  Result := TJSONArray.Create;
  if not Assigned(Params) or not Assigned(Params.Find('textDocument')) then Exit;
  URI := (Params.Find('textDocument') as TJSONObject).Get('uri', '');
  Idx := FindDocIndex(URI);
  if Idx < 0 then Exit;

  SourceText := FDocuments[Idx].Text;
  FormattedText := TAetherFormatter.FormatSource(SourceText);
  if FormattedText = SourceText then Exit;

  Lines := TStringList.Create;
  try
    Lines.Text := SourceText;
    TotalLines := Math.Max(0, Lines.Count - 1);
    if Lines.Count > 0 then
      LastLineLen := Length(Lines[Lines.Count - 1])
    else
      LastLineLen := 0;
  finally
    Lines.Free;
  end;

  Item := TJSONObject.Create;
  RangeObj := TJSONObject.Create;
  StartPos := TJSONObject.Create(['line', 0, 'character', 0]);
  EndPos := TJSONObject.Create(['line', TotalLines, 'character', LastLineLen]);
  RangeObj.Add('start', StartPos);
  RangeObj.Add('end', EndPos);
  Item.Add('range', RangeObj);
  Item.Add('newText', FormattedText);
  Result.Add(Item);
end;

function HandleRename(Params: TJSONObject): TJSONObject;
var
  URI, SourceText, NewName, OldName: string;
  Line, CharPos, Idx: Integer;
  PosObj: TJSONObject;
  Lexer: TAetherLexer;
  Tok: TToken;
  ChangesObj, EditObj, RangeObj, StartPos, EndPos: TJSONObject;
  Arr: TJSONArray;
begin
  Result := nil;
  if not Assigned(Params) or not Assigned(Params.Find('textDocument')) then Exit;
  URI := (Params.Find('textDocument') as TJSONObject).Get('uri', '');
  NewName := Params.Get('newName', '');
  if NewName = '' then Exit;

  PosObj := Params.Find('position') as TJSONObject;
  if not Assigned(PosObj) then Exit;
  Line := PosObj.Get('line', 0);
  CharPos := PosObj.Get('character', 0);

  Idx := FindDocIndex(URI);
  if Idx < 0 then Exit;
  SourceText := FDocuments[Idx].Text;

  OldName := GetWordAt(SourceText, Line, CharPos);
  if OldName = '' then Exit;

  Arr := TJSONArray.Create;
  Lexer := TAetherLexer.Create(SourceText);
  try
    while True do
    begin
      Tok := Lexer.NextToken;
      if Tok.Kind = tokEOF then Break;
      if (Tok.Kind = tokIdentifier) and SameText(Tok.Value, OldName) then
      begin
        EditObj := TJSONObject.Create;
        RangeObj := TJSONObject.Create;
        StartPos := TJSONObject.Create(['line', Tok.Line - 1, 'character', Tok.Col - 1]);
        EndPos := TJSONObject.Create(['line', Tok.Line - 1, 'character', Tok.Col - 1 + Length(OldName)]);
        RangeObj.Add('start', StartPos);
        RangeObj.Add('end', EndPos);
        EditObj.Add('range', RangeObj);
        EditObj.Add('newText', NewName);
        Arr.Add(EditObj);
      end;
    end;
  finally
    Lexer.Free;
  end;

  ChangesObj := TJSONObject.Create;
  ChangesObj.Add(URI, Arr);
  Result := TJSONObject.Create;
  Result.Add('changes', ChangesObj);
end;

function HandleCodeAction(Params: TJSONObject): TJSONArray;
var
  URI, DiagMsg, DiagCode: string;
  ContextObj, DiagObj, ActionObj, EditObj, ChangesObj, TextEditObj, RangeObj: TJSONObject;
  DiagsArr, EditsArr: TJSONArray;
  I: Integer;
begin
  Result := TJSONArray.Create;
  if not Assigned(Params) or not Assigned(Params.Find('textDocument')) then Exit;
  URI := (Params.Find('textDocument') as TJSONObject).Get('uri', '');
  ContextObj := Params.Find('context') as TJSONObject;
  if not Assigned(ContextObj) then Exit;

  DiagsArr := ContextObj.Find('diagnostics') as TJSONArray;
  if not Assigned(DiagsArr) or (DiagsArr.Count = 0) then Exit;

  for I := 0 to DiagsArr.Count - 1 do
  begin
    if not (DiagsArr[I] is TJSONObject) then Continue;
    DiagObj := TJSONObject(DiagsArr[I]);
    DiagMsg := DiagObj.Get('message', '');
    DiagCode := DiagObj.Get('code', '');

    // 1. QuickFix para Borrow Checker (E0401, E0402 ou 'posse' / 'borrow')
    if (Pos('E04', DiagCode) = 1) or (Pos('posse', LowerCase(DiagMsg)) > 0) or (Pos('borrow', LowerCase(DiagMsg)) > 0) then
    begin
      ActionObj := TJSONObject.Create;
      ActionObj.Add('title', '💡 Substituir argumento por "borrow" (Empréstimo Imutável)');
      ActionObj.Add('kind', 'quickfix');
      ActionObj.Add('isPreferred', True);
      Result.Add(ActionObj);

      ActionObj := TJSONObject.Create;
      ActionObj.Add('title', '💡 Substituir argumento por "mut borrow" (Empréstimo Mutável Exclusivo)');
      ActionObj.Add('kind', 'quickfix');
      ActionObj.Add('isPreferred', False);
      Result.Add(ActionObj);
    end;

    // 2. QuickFix para imports canônicos da stdlib
    if (Pos('FileInfo', DiagMsg) > 0) or (Pos('CreateDir', DiagMsg) > 0) or (Pos('ExisteDiretorio', DiagMsg) > 0) then
    begin
      ActionObj := TJSONObject.Create;
      ActionObj.Add('title', '📦 Adicionar import "std.fs;"');
      ActionObj.Add('kind', 'quickfix');
      ActionObj.Add('isPreferred', True);

      EditObj := TJSONObject.Create;
      ChangesObj := TJSONObject.Create;
      EditsArr := TJSONArray.Create;
      TextEditObj := TJSONObject.Create;
      RangeObj := TJSONObject.Create;
      RangeObj.Add('start', TJSONObject.Create(['line', 1, 'character', 0]));
      RangeObj.Add('end', TJSONObject.Create(['line', 1, 'character', 0]));
      TextEditObj.Add('range', RangeObj);
      TextEditObj.Add('newText', 'import std.fs;'#10);
      EditsArr.Add(TextEditObj);
      ChangesObj.Add(URI, EditsArr);
      EditObj.Add('changes', ChangesObj);
      ActionObj.Add('edit', EditObj);
      Result.Add(ActionObj);
    end
    else if (Pos('Timer', DiagMsg) > 0) or (Pos('NovoTimer', DiagMsg) > 0) or (Pos('GetNanoseconds', DiagMsg) > 0) then
    begin
      ActionObj := TJSONObject.Create;
      ActionObj.Add('title', '📦 Adicionar import "std.time;"');
      ActionObj.Add('kind', 'quickfix');
      ActionObj.Add('isPreferred', True);

      EditObj := TJSONObject.Create;
      ChangesObj := TJSONObject.Create;
      EditsArr := TJSONArray.Create;
      TextEditObj := TJSONObject.Create;
      RangeObj := TJSONObject.Create;
      RangeObj.Add('start', TJSONObject.Create(['line', 1, 'character', 0]));
      RangeObj.Add('end', TJSONObject.Create(['line', 1, 'character', 0]));
      TextEditObj.Add('range', RangeObj);
      TextEditObj.Add('newText', 'import std.time;'#10);
      EditsArr.Add(TextEditObj);
      ChangesObj.Add(URI, EditsArr);
      EditObj.Add('changes', ChangesObj);
      ActionObj.Add('edit', EditObj);
      Result.Add(ActionObj);
    end
    else if (Pos('Client', DiagMsg) > 0) or (Pos('Server', DiagMsg) > 0) or (Pos('NewClient', DiagMsg) > 0) then
    begin
      ActionObj := TJSONObject.Create;
      ActionObj.Add('title', '📦 Adicionar import "std.http;"');
      ActionObj.Add('kind', 'quickfix');
      ActionObj.Add('isPreferred', True);

      EditObj := TJSONObject.Create;
      ChangesObj := TJSONObject.Create;
      EditsArr := TJSONArray.Create;
      TextEditObj := TJSONObject.Create;
      RangeObj := TJSONObject.Create;
      RangeObj.Add('start', TJSONObject.Create(['line', 1, 'character', 0]));
      RangeObj.Add('end', TJSONObject.Create(['line', 1, 'character', 0]));
      TextEditObj.Add('range', RangeObj);
      TextEditObj.Add('newText', 'import std.http;'#10);
      EditsArr.Add(TextEditObj);
      ChangesObj.Add(URI, EditsArr);
      EditObj.Add('changes', ChangesObj);
      ActionObj.Add('edit', EditObj);
      Result.Add(ActionObj);
    end
    else if (Pos('JsonBuilder', DiagMsg) > 0) or (Pos('ParseJson', DiagMsg) > 0) then
    begin
      ActionObj := TJSONObject.Create;
      ActionObj.Add('title', '📦 Adicionar import "std.json;"');
      ActionObj.Add('kind', 'quickfix');
      ActionObj.Add('isPreferred', True);

      EditObj := TJSONObject.Create;
      ChangesObj := TJSONObject.Create;
      EditsArr := TJSONArray.Create;
      TextEditObj := TJSONObject.Create;
      RangeObj := TJSONObject.Create;
      RangeObj.Add('start', TJSONObject.Create(['line', 1, 'character', 0]));
      RangeObj.Add('end', TJSONObject.Create(['line', 1, 'character', 0]));
      TextEditObj.Add('range', RangeObj);
      TextEditObj.Add('newText', 'import std.json;'#10);
      EditsArr.Add(TextEditObj);
      ChangesObj.Add(URI, EditsArr);
      EditObj.Add('changes', ChangesObj);
      ActionObj.Add('edit', EditObj);
      Result.Add(ActionObj);
    end;
  end;
end;

procedure RunAetherLSP;
var
  RawMsg: UTF8String;
  JSON: TJSONData;
  Req: TJSONObject;
  Method: string;
  Id: TJSONData;
  Params: TJSONObject;
  ResultData: TJSONData;
  Caps, CompCaps: TJSONObject;
  DocObj: TJSONObject;
  URI, Text: string;
  Ver: Integer;
  ChangesArr: TJSONArray;
begin
  while True do
  begin
    RawMsg := ReadLSPMessage;
    if RawMsg = '' then Break;

    try
      JSON := GetJSON(RawMsg);
      try
        if not (JSON is TJSONObject) then Continue;
        Req := TJSONObject(JSON);

        Method := Req.Get('method', '');
        Id := Req.Find('id');
        Params := Req.Find('params') as TJSONObject;
        WriteLn(ErrOutput, '[LSP Server] Processing: ', Method);

        if Method = 'initialize' then
        begin
          Caps := TJSONObject.Create;
          // textDocumentSync: 1 (Full)
          Caps.Add('textDocumentSync', 1);

          CompCaps := TJSONObject.Create;
          CompCaps.Add('resolveProvider', False);
          CompCaps.Add('triggerCharacters', TJSONArray.Create(['.', ':']));
          Caps.Add('completionProvider', CompCaps);

          Caps.Add('hoverProvider', True);
          Caps.Add('definitionProvider', True);
          Caps.Add('documentFormattingProvider', True);
          Caps.Add('renameProvider', True);
          Caps.Add('codeActionProvider', True);

          ResultData := TJSONObject.Create;
          TJSONObject(ResultData).Add('capabilities', Caps);
          SendLSPResponse(Id, ResultData);
        end
        else if Method = 'initialized' then
        begin
          // Notificação de handshake concluído
        end
        else if Method = 'textDocument/didOpen' then
        begin
          if Assigned(Params) and Assigned(Params.Find('textDocument')) then
          begin
            DocObj := Params.Find('textDocument') as TJSONObject;
            URI := DocObj.Get('uri', '');
            Text := DocObj.Get('text', '');
            Ver := DocObj.Get('version', 1);
            SetDoc(URI, Text, Ver);
            ValidateAndPublishDiagnostics(URI, Text);
          end;
        end
        else if Method = 'textDocument/didChange' then
        begin
          if Assigned(Params) and Assigned(Params.Find('textDocument')) then
          begin
            DocObj := Params.Find('textDocument') as TJSONObject;
            URI := DocObj.Get('uri', '');
            Ver := DocObj.Get('version', 1);
            ChangesArr := Params.Find('contentChanges') as TJSONArray;
            if Assigned(ChangesArr) and (ChangesArr.Count > 0) then
            begin
              Text := (ChangesArr[0] as TJSONObject).Get('text', '');
              SetDoc(URI, Text, Ver);
              ValidateAndPublishDiagnostics(URI, Text);
            end;
          end;
        end
        else if Method = 'textDocument/didClose' then
        begin
          if Assigned(Params) and Assigned(Params.Find('textDocument')) then
          begin
            DocObj := Params.Find('textDocument') as TJSONObject;
            URI := DocObj.Get('uri', '');
            RemoveDoc(URI);
          end;
        end
        else if Method = 'textDocument/completion' then
        begin
          ResultData := HandleCompletion(Params);
          SendLSPResponse(Id, ResultData);
        end
        else if Method = 'textDocument/hover' then
        begin
          ResultData := HandleHover(Params);
          SendLSPResponse(Id, ResultData);
        end
        else if Method = 'textDocument/definition' then
        begin
          ResultData := HandleDefinition(Params);
          SendLSPResponse(Id, ResultData);
        end
        else if Method = 'textDocument/formatting' then
        begin
          ResultData := HandleFormatting(Params);
          SendLSPResponse(Id, ResultData);
        end
        else if Method = 'textDocument/rename' then
        begin
          ResultData := HandleRename(Params);
          if Assigned(ResultData) then
            SendLSPResponse(Id, ResultData)
          else
            SendLSPResponse(Id, TJSONNull.Create);
        end
        else if Method = 'textDocument/codeAction' then
        begin
          ResultData := HandleCodeAction(Params);
          SendLSPResponse(Id, ResultData);
        end
        else if Method = 'shutdown' then
        begin
          SendLSPResponse(Id, TJSONNull.Create);
        end
        else if Method = 'exit' then
        begin
          Break;
        end
        else if Assigned(Id) then
        begin
          // Metodo desconhecido respondido com null
          SendLSPResponse(Id, TJSONNull.Create);
        end;

      finally
        JSON.Free;
      end;
    except
      on E: Exception do
      begin
        WriteLn(ErrOutput, '[LSP Server Error] ', E.ClassName, ': ', E.Message);
        if Assigned(Id) then
          SendLSPResponse(Id, nil, TJSONObject.Create(['code', -32603, 'message', E.Message]));
      end;
    end;
  end;
end;

end.
