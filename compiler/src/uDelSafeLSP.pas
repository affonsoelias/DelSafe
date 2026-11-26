unit uDelSafeLSP;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  SysUtils, Classes, Math, fpjson, jsonparser,
  uDelSafeTokens, uDelSafeLexer, uDelSafeAST, uDelSafeParser,
  uDelSafeTypeChecker, uDelSafeBorrowChecker, uDelSafeFormatter;

procedure RunDelSafeLSP;

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

  // Read headers until empty CRLF CRLF sequence
  while True do
  begin
    BytesRead := FileRead(StdInputHandle, C, 1);
    if BytesRead <= 0 then Exit(''); // Stream closed
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
  Lexer: TDelSafeLexer;
  Parser: TDelSafeParser;
  TypeChecker: TDelSafeTypeChecker;
  BorrowChecker: TDelSafeBorrowChecker;
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
    Lexer := TDelSafeLexer.Create(SourceText);
    Parser := TDelSafeParser.Create(Lexer);
    try
      ModuleNode := Parser.ParseModule;
    finally
      Parser.Free;
      Lexer.Free;
    end;

    // Cache AST in memory immediately for completion, hover, and go-to-definition
    Idx := FindDocIndex(URI);
    if Idx >= 0 then
    begin
      if Assigned(FDocuments[Idx].AST) then FDocuments[Idx].AST.Free;
      FDocuments[Idx].AST := ModuleNode;
      ModuleNode := nil; // Ownership transferred to FDocuments
    end;

    TypeChecker := TDelSafeTypeChecker.Create;
    try
      if (Idx >= 0) and Assigned(FDocuments[Idx].AST) then
      begin
        TypeChecker.CheckModule(FDocuments[Idx].AST);
        BorrowChecker := TDelSafeBorrowChecker.Create(TypeChecker.Symbols);
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
    on E: EDelSafeBorrowError do
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
      DiagObj.Add('source', 'delsafe-lsp');
      DiagObj.Add('message', ErrMsg);
      DiagsArr.Add(DiagObj);
    end;
    on E: EDelSafeTypeError do
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
      DiagObj.Add('source', 'delsafe-lsp');
      DiagObj.Add('message', ErrMsg);
      DiagsArr.Add(DiagObj);
    end;
    on E: EDelSafeParserError do
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
      DiagObj.Add('source', 'delsafe-lsp');
      DiagObj.Add('message', E.Message);
      DiagsArr.Add(DiagObj);
    end;
    on E: EDelSafeLexerError do
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
      DiagObj.Add('source', 'delsafe-lsp');
      DiagObj.Add('message', E.Message);
      DiagsArr.Add(DiagObj);
    end;
    on E: Exception do
    begin
      // Generic error
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
  if Func.IsProcedure then
    Result := Format('procedure %s(%s)', [Func.Name, ParamsStr])
  else
    Result := Format('function %s(%s) return %s', [Func.Name, ParamsStr, Func.ReturnType]);
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

  // Fundamental keywords
  AddItem('module', 14, 'Module Declaration');
  AddItem('program', 14, 'Main Program Block');
  AddItem('interface', 14, 'Unit Public Interface Section');
  AddItem('implementation', 14, 'Unit Implementation Section');
  AddItem('initialization', 14, 'Unit Initialization Block');
  AddItem('finalization', 14, 'Unit Finalization Block');
  AddItem('import', 14, 'Import DelSafe Module');
  AddItem('extern', 14, 'Declare External C Function');
  AddItem('function', 14, 'Function Declaration (with return)');
  AddItem('procedure', 14, 'Procedure Declaration (no return)');
  AddItem('is', 14, 'Ada-style routine definition start');
  AddItem('contract', 14, 'Contracts Block (require / ensure)');
  AddItem('require', 14, 'Contract Pre-condition');
  AddItem('ensure', 14, 'Contract Post-condition');
  AddItem('type', 14, 'Types Section');
  AddItem('record', 14, 'Record Struct Type');
  AddItem('enum', 14, 'Algebraic Enum Type');
  AddItem('trait', 14, 'Trait / Interface Declaration');
  AddItem('impl', 14, 'Trait Implementation for Type');
  AddItem('for', 14, 'Association Clause (impl Trait for Type)');
  AddItem('var', 14, 'Mutable Variable');
  AddItem('let', 14, 'Immutable Binding');
  AddItem('begin', 14, 'Block Start');
  AddItem('end', 14, 'Block End');
  AddItem('if', 14, 'Conditional Branch');
  AddItem('then', 14, 'Then Clause');
  AddItem('else', 14, 'Else Clause');
  AddItem('while', 14, 'While Loop');
  AddItem('match', 14, 'Exhaustive Pattern Match');
  AddItem('case', 14, 'Match Case Arm');
  AddItem('return', 14, 'Function Return');

  // Ownership & Borrowing
  AddItem('borrow', 14, 'Immutable Borrow (Read-Only)');
  AddItem('take', 14, 'Ownership Transfer (Move)');
  AddItem('mut borrow', 14, 'Exclusive Mutable Borrow');
  AddItem('own', 14, 'Exclusive Ownership Modifier');

  // Primitive Types
  AddItem('Int8', 7, '8-bit signed integer');
  AddItem('Int16', 7, '16-bit signed integer');
  AddItem('Int32', 7, '32-bit signed integer');
  AddItem('Int64', 7, '64-bit signed integer');
  AddItem('UInt8', 7, '8-bit unsigned integer');
  AddItem('UInt16', 7, '16-bit unsigned integer');
  AddItem('UInt32', 7, '32-bit unsigned integer');
  AddItem('UInt64', 7, '64-bit unsigned integer');
  AddItem('Float32', 7, '32-bit floating-point');
  AddItem('Float64', 7, '64-bit floating-point');
  AddItem('Bool', 7, 'Boolean (true/false)');
  AddItem('String', 7, 'UTF-8 String');
  AddItem('Char', 7, 'Unicode Character');

  // Monads
  AddItem('Result', 7, 'Result<T, E> Monad');
  AddItem('Option', 7, 'Option<T> Monad');
  AddItem('Ok', 3, 'Success Constructor: Ok(value)');
  AddItem('Err', 3, 'Error Constructor: Err(error)');
  AddItem('Some', 3, 'Present Optional Constructor: Some(value)');
  AddItem('None', 14, 'Absent Value: None');
  AddItem('PrintLn', 3, 'Prints a formatted line to the console');

  // Symbols from current document
  if Assigned(Params) and Assigned(Params.Find('textDocument')) then
  begin
    URI := (Params.Find('textDocument') as TJSONObject).Get('uri', '');
    Idx := FindDocIndex(URI);
    if (Idx >= 0) and Assigned(FDocuments[Idx].AST) then
    begin
      ModNode := FDocuments[Idx].AST;

      // Records and Enums
      for I := 0 to ModNode.Types.Count - 1 do
      begin
        if ModNode.Types[I] is TASTRecordDecl then
        begin
          Rec := TASTRecordDecl(ModNode.Types[I]);
          AddItem(Rec.Name, 7, 'Module Record Type');
        end
        else if ModNode.Types[I] is TASTEnumDecl then
        begin
          Enm := TASTEnumDecl(ModNode.Types[I]);
          AddItem(Enm.Name, 7, 'Module Algebraic Enum');
        end;
      end;

      // Declared Traits
      for I := 0 to ModNode.Traits.Count - 1 do
      begin
        TraitDecl := TASTTraitDecl(ModNode.Traits[I]);
        AddItem(TraitDecl.Name, 8, 'Module Trait Declaration');
      end;

      // Module functions with full signatures
      for I := 0 to ModNode.Functions.Count - 1 do
      begin
        Func := TASTFunction(ModNode.Functions[I]);
        AddItem(Func.Name, 3, FormatFunctionSignature(Func));
      end;

      // Methods implemented in Impls (UFCS / Trait Methods)
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

  // 1. Ownership and Concurrency Keywords
  if LowerCase(Word) = 'borrow' then
    InfoText := '**borrow (Immutable Borrow)**'#10#10 +
                'Grants read-only access to data without transferring ownership. Multiple concurrent readers allowed.'
  else if LowerCase(Word) = 'take' then
    InfoText := '**take (Ownership Transfer / Move)**'#10#10 +
                'Transfers ownership permanently. The source variable becomes invalid (*Use-After-Move* is prevented).'
  else if LowerCase(Word) = 'mut' then
    InfoText := '**mut (Exclusive Mutability)**'#10#10 +
                'When combined with `mut borrow`, enforces a single active writer at a time, preventing data races.'
  else if LowerCase(Word) = 'own' then
    InfoText := '**own (Memory Ownership)**'#10#10 +
                'Modifier that explicitly denotes ownership over a resource or memory pointer.'
  else if LowerCase(Word) = 'trait' then
    InfoText := '**trait (Interface / Type Contract)**'#10#10 +
                'Defines a set of method signatures and contractual rules that concrete types can implement via `impl Trait for Type`.'
  else if LowerCase(Word) = 'impl' then
    InfoText := '**impl (Trait Implementation)**'#10#10 +
                'Implements the methods and behavior required by a `trait` for a specific record type.'
  else if LowerCase(Word) = 'contract' then
    InfoText := '**contract (Formal Contract)**'#10#10 +
                'Specifies pre-conditions (`require`) and post-conditions (`ensure`) validated by the DelSafe compiler.'
  else if LowerCase(Word) = 'result' then
    InfoText := '**Result<T, E> (Success/Failure Monad)**'#10#10 +
                'Canonical type for fallible operations. Handle exhaustively with `match` (`Ok(v)` or `Err(e)`).'
  else if LowerCase(Word) = 'option' then
    InfoText := '**Option<T> (Optional Monad)**'#10#10 +
                'Eliminates null pointers (`nil`/`null`). Holds `Some(v)` when present or `None` when absent.';

  // 2. Search in current document AST
  if (InfoText = '') and Assigned(FDocuments[Idx].AST) then
  begin
    ModNode := FDocuments[Idx].AST;

    // Module functions
    for I := 0 to ModNode.Functions.Count - 1 do
    begin
      Func := TASTFunction(ModNode.Functions[I]);
      if SameText(Func.Name, Word) then
      begin
        InfoText := Format('```delsafe'#10'%s'#10'```', [FormatFunctionSignature(Func)]);
        if Func.Requires.Count > 0 then
          InfoText := InfoText + #10#10'**Contract (require):** Active validation pre-conditions.';
        if Func.Ensures.Count > 0 then
          InfoText := InfoText + #10#10'**Contract (ensure):** Active validation post-conditions.';
        Break;
      end;

      // Function parameters
      for J := 0 to Func.Params.Count - 1 do
      begin
        ParamNode := TASTParam(Func.Params[J]);
        if SameText(ParamNode.Name, Word) then
        begin
          InfoText := Format('```delsafe'#10'param %s%s: %s'#10'```'#10#10'*Parameter of function `%s`*',
            [OwnershipToString(ParamNode.Ownership), ParamNode.Name, ParamNode.TypeName, Func.Name]);
          Break;
        end;
      end;
      if InfoText <> '' then Break;

      // Local variables of function
      for J := 0 to Func.LocalVars.Count - 1 do
      begin
        VarNode := TASTVarDecl(Func.LocalVars[J]);
        if SameText(VarNode.Name, Word) then
        begin
          InfoText := Format('```delsafe'#10'var %s: %s'#10'```'#10#10'*Local variable of function `%s`*',
            [VarNode.Name, VarNode.TypeName, Func.Name]);
          Break;
        end;
      end;
      if InfoText <> '' then Break;
    end;

    // Module traits
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
          InfoText := Format('```delsafe'#10'trait %s'#10'%send trait;'#10'```', [TraitDecl.Name, SubText]);
          Break;
        end;
      end;
    end;

    // Methods in Impls
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
            InfoText := Format('```delsafe'#10'%s'#10'```'#10#10'*Implementation of trait `%s` for type `%s`*',
              [FormatFunctionSignature(Func), ImplDecl.TraitName, ImplDecl.TargetTypeName]);
            Break;
          end;
        end;
        if InfoText <> '' then Break;
      end;
    end;

    // Records and Enums
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
            InfoText := Format('```delsafe'#10'type %s = record'#10'%send record;'#10'```', [Rec.Name, SubText]);
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
            InfoText := Format('```delsafe'#10'type %s = enum'#10'%s'#10'end enum;'#10'```', [Enm.Name, SubText]);
            Break;
          end;
        end;
      end;
    end;

    // Main program variables
    if (InfoText = '') and Assigned(ModNode.ProgramBlock) then
    begin
      for I := 0 to ModNode.ProgramBlock.LocalVars.Count - 1 do
      begin
        VarNode := TASTVarDecl(ModNode.ProgramBlock.LocalVars[I]);
        if SameText(VarNode.Name, Word) then
        begin
          InfoText := Format('```delsafe'#10'var %s: %s'#10'```'#10#10'*Main program variable*',
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

  // 1. Search module functions
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

  // 2. Search Traits
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

  // 3. Search Impl methods
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

  // 4. Search Types (Records and Enums)
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
  FormattedText := TDelSafeFormatter.FormatSource(SourceText);
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
  Lexer: TDelSafeLexer;
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
  Lexer := TDelSafeLexer.Create(SourceText);
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

    // 1. QuickFix for Borrow Checker (E0401, E0402, or 'ownership' / 'borrow')
    if (Pos('E04', DiagCode) = 1) or (Pos('ownership', LowerCase(DiagMsg)) > 0) or (Pos('borrow', LowerCase(DiagMsg)) > 0) then
    begin
      ActionObj := TJSONObject.Create;
      ActionObj.Add('title', 'Replace argument with "borrow" (Immutable Borrow)');
      ActionObj.Add('kind', 'quickfix');
      ActionObj.Add('isPreferred', True);
      Result.Add(ActionObj);

      ActionObj := TJSONObject.Create;
      ActionObj.Add('title', 'Replace argument with "mut borrow" (Exclusive Mutable Borrow)');
      ActionObj.Add('kind', 'quickfix');
      ActionObj.Add('isPreferred', False);
      Result.Add(ActionObj);
    end;

    // 2. QuickFix for canonical stdlib imports
    if (Pos('FileInfo', DiagMsg) > 0) or (Pos('CreateDir', DiagMsg) > 0) or (Pos('HasDir', DiagMsg) > 0) or (Pos('GetFileInfo', DiagMsg) > 0) then
    begin
      ActionObj := TJSONObject.Create;
      ActionObj.Add('title', 'Add import "std.fs;"');
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
    else if (Pos('Timer', DiagMsg) > 0) or (Pos('NewTimer', DiagMsg) > 0) or (Pos('GetNanoseconds', DiagMsg) > 0) then
    begin
      ActionObj := TJSONObject.Create;
      ActionObj.Add('title', 'Add import "std.time;"');
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
      ActionObj.Add('title', 'Add import "std.http;"');
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
      ActionObj.Add('title', 'Add import "std.json;"');
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

procedure RunDelSafeLSP;
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
          // Handshake completion notification
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
          // Unknown method responds with null
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
