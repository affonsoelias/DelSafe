unit uAetherDoc;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Process,
  uAetherTokens, uAetherLexer, uAetherParser, uAetherAST;

type
  TAetherDocFormat = (dfHTML, dfMarkdown, dfAll);

  TDocParam = record
    Name: string;
    TypeName: string;
    Ownership: TOwnershipKind;
    Doc: string;
  end;

  TDocContract = record
    Kind: string;       // 'require' or 'ensure'
    Expression: string; // Ex: 'n >= 0'
  end;

  TDocFunction = record
    Name: string;
    GenericParam: string;
    TraitBound: string;
    ReturnType: string;
    IsProcedure: Boolean;
    IsAsync: Boolean;
    IsExtern: Boolean;
    RawDoc: string;
    Summary: string;
    Description: string;
    Params: array of TDocParam;
    Contracts: array of TDocContract;
    Doctests: array of string;
  end;

  TDocField = record
    Name: string;
    TypeName: string;
    Doc: string;
  end;

  TDocType = record
    Name: string;
    Kind: string;       // 'record' or 'enum'
    RawDoc: string;
    Summary: string;
    Description: string;
    Fields: array of TDocField;
  end;

  TDocTrait = record
    Name: string;
    RawDoc: string;
    Summary: string;
    Description: string;
    Methods: array of TDocFunction;
  end;

  TDocModule = class
  public
    Name: string;
    FilePath: string;
    RawDoc: string;
    Summary: string;
    Description: string;
    Imports: TStringList;
    Types: array of TDocType;
    Traits: array of TDocTrait;
    Functions: array of TDocFunction;
    constructor Create;
    destructor Destroy; override;
  end;

  TAetherDocGenerator = class
  private
    FModules: TFPList; // TDocModule
    FProjectName: string;
    FProjectVersion: string;
    FProjectDesc: string;

    function ExprToCode(Expr: TASTExpr): string;
    function ExtractDoctests(const ADoc: string): TStringArray;
    procedure ParseDocComments(const ADoc: string; out Summary, Desc: string;
      out ParamDocs: TStringList; out ReturnDoc: string);
    procedure ProcessASTModule(ASTMod: TASTModule; const FilePath: string);
    function HTMLEscape(const S: string): string;

    procedure GenerateHTML(const OutDir: string);
    procedure GenerateMarkdown(const OutDir: string);
    procedure RunDoctests;
  public
    constructor Create(const AProjectName: string = 'Aether Project';
      const AProjectVersion: string = '1.0.0'; const AProjectDesc: string = '');
    destructor Destroy; override;

    procedure AddFile(const AFilePath: string);
    procedure AddProject(const ARootDir: string);
    procedure Generate(const AOutDir: string; AFormat: TAetherDocFormat = dfHTML;
      AOpenBrowser: Boolean = False; ATest: Boolean = False);
  end;

procedure HandleDocCommand;

implementation

{ TDocModule }

constructor TDocModule.Create;
begin
  inherited Create;
  Imports := TStringList.Create;
  SetLength(Types, 0);
  SetLength(Traits, 0);
  SetLength(Functions, 0);
end;

destructor TDocModule.Destroy;
begin
  Imports.Free;
  inherited Destroy;
end;

{ TAetherDocGenerator }

constructor TAetherDocGenerator.Create(const AProjectName, AProjectVersion, AProjectDesc: string);
begin
  inherited Create;
  FModules := TFPList.Create;
  FProjectName := AProjectName;
  if FProjectName = '' then FProjectName := 'Aether Project';
  FProjectVersion := AProjectVersion;
  if FProjectVersion = '' then FProjectVersion := '1.0.0';
  FProjectDesc := AProjectDesc;
end;

destructor TAetherDocGenerator.Destroy;
var
  I: Integer;
begin
  for I := 0 to FModules.Count - 1 do
    TDocModule(FModules[I]).Free;
  FModules.Free;
  inherited Destroy;
end;

function TAetherDocGenerator.HTMLEscape(const S: string): string;
var
  Res: string;
begin
  Res := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Res := StringReplace(Res, '<', '&lt;', [rfReplaceAll]);
  Res := StringReplace(Res, '>', '&gt;', [rfReplaceAll]);
  Res := StringReplace(Res, '"', '&quot;', [rfReplaceAll]);
  Result := Res;
end;

function TAetherDocGenerator.ExprToCode(Expr: TASTExpr): string;
var
  I: Integer;
  ArgsStr: string;
  CallE: TASTCallExpr;
  BinE: TASTBinaryExpr;
  UnE: TASTUnaryExpr;
  MemE: TASTMemberAccessExpr;
begin
  if Expr = nil then Exit('');

  if Expr is TASTLiteralExpr then
  begin
    case TASTLiteralExpr(Expr).Kind of
      lkString: Exit('"' + TASTLiteralExpr(Expr).Value + '"');
      lkChar: Exit('''' + TASTLiteralExpr(Expr).Value + '''');
    else
      Exit(TASTLiteralExpr(Expr).Value);
    end;
  end
  else if Expr is TASTIdentifierExpr then
    Exit(TASTIdentifierExpr(Expr).Name)
  else if Expr is TASTBinaryExpr then
  begin
    BinE := TASTBinaryExpr(Expr);
    Exit(ExprToCode(BinE.Left) + ' ' + BinE.Op + ' ' + ExprToCode(BinE.Right));
  end
  else if Expr is TASTUnaryExpr then
  begin
    UnE := TASTUnaryExpr(Expr);
    Exit(UnE.Op + ' ' + ExprToCode(UnE.Expr));
  end
  else if Expr is TASTMemberAccessExpr then
  begin
    MemE := TASTMemberAccessExpr(Expr);
    Exit(ExprToCode(MemE.Target) + '.' + MemE.Member);
  end
  else if Expr is TASTCallExpr then
  begin
    CallE := TASTCallExpr(Expr);
    ArgsStr := '';
    for I := 0 to CallE.Args.Count - 1 do
    begin
      if I > 0 then ArgsStr := ArgsStr + ', ';
      ArgsStr := ArgsStr + ExprToCode(TASTExpr(CallE.Args[I]));
    end;
    Exit(CallE.Callee + '(' + ArgsStr + ')');
  end
  else if Expr is TASTAwaitExpr then
    Exit('await ' + ExprToCode(TASTAwaitExpr(Expr).Expr))
  else if Expr is TASTSpawnExpr then
    Exit('spawn ' + ExprToCode(TASTSpawnExpr(Expr).CallExpr));

  Result := '...';
end;

function TAetherDocGenerator.ExtractDoctests(const ADoc: string): TStringArray;
var
  Lines: TStringList;
  I: Integer;
  Line: string;
  InBlock: Boolean;
  CurTest: string;
  Res: TStringArray;
begin
  SetLength(Res, 0);
  if ADoc = '' then Exit(Res);

  Lines := TStringList.Create;
  try
    Lines.Text := ADoc;
    InBlock := False;
    CurTest := '';

    for I := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[I]);
      if (Pos('```aether', Line) = 1) or (Pos('```', Line) = 1) then
      begin
        if not InBlock and (Pos('```aether', Line) = 1) then
        begin
          InBlock := True;
          CurTest := '';
        end
        else if InBlock and (Line = '```') then
        begin
          InBlock := False;
          if Trim(CurTest) <> '' then
          begin
            SetLength(Res, Length(Res) + 1);
            Res[High(Res)] := CurTest;
          end;
        end;
      end
      else if InBlock then
      begin
        if CurTest <> '' then CurTest := CurTest + LineEnding;
        CurTest := CurTest + Lines[I];
      end;
    end;
    Result := Res;
  finally
    Lines.Free;
  end;
end;

procedure TAetherDocGenerator.ParseDocComments(const ADoc: string;
  out Summary, Desc: string; out ParamDocs: TStringList; out ReturnDoc: string);
var
  Lines: TStringList;
  I, SpIdx: Integer;
  Line, PName, PDesc: string;
  FoundSummary: Boolean;
begin
  Summary := '';
  Desc := '';
  ReturnDoc := '';
  ParamDocs := TStringList.Create;

  if ADoc = '' then Exit;

  Lines := TStringList.Create;
  try
    Lines.Text := ADoc;
    FoundSummary := False;

    for I := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[I]);
      if Line = '' then Continue;

      if Pos('@param', Line) = 1 then
      begin
        Line := Trim(Copy(Line, 7, Length(Line)));
        SpIdx := Pos(' ', Line);
        if SpIdx > 0 then
        begin
          PName := Copy(Line, 1, SpIdx - 1);
          PDesc := Trim(Copy(Line, SpIdx + 1, Length(Line)));
          ParamDocs.Values[PName] := PDesc;
        end
        else
          ParamDocs.Values[Line] := '';
      end
      else if (Pos('@return', Line) = 1) or (Pos('@returns', Line) = 1) then
      begin
        if Pos('@returns', Line) = 1 then
          ReturnDoc := Trim(Copy(Line, 9, Length(Line)))
        else
          ReturnDoc := Trim(Copy(Line, 8, Length(Line)));
      end
      else
      begin
        if not FoundSummary then
        begin
          Summary := Line;
          FoundSummary := True;
        end
        else
        begin
          if Desc <> '' then Desc := Desc + LineEnding;
          Desc := Desc + Lines[I];
        end;
      end;
    end;
  finally
    Lines.Free;
  end;
end;

procedure TAetherDocGenerator.ProcessASTModule(ASTMod: TASTModule; const FilePath: string);
var
  ModDoc: TDocModule;
  I, J, K: Integer;
  FuncNode: TASTFunction;
  ParamNode: TASTParam;
  FieldNode: TASTRecordField;
  RecNode: TASTRecordDecl;
  EnumNode: TASTEnumDecl;
  TraitNode: TASTTraitDecl;
  ParamDocs: TStringList;
  RetDoc, Sum, Dsc: string;
begin
  ModDoc := TDocModule.Create;
  ModDoc.Name := ASTMod.Name;
  ModDoc.FilePath := FilePath;
  ModDoc.RawDoc := ASTMod.DocComment;

  ParamDocs := nil;
  ParseDocComments(ASTMod.DocComment, ModDoc.Summary, ModDoc.Description, ParamDocs, RetDoc);
  if Assigned(ParamDocs) then ParamDocs.Free;

  // Imports
  for I := 0 to ASTMod.Imports.Count - 1 do
    ModDoc.Imports.Add(ASTMod.Imports[I]);

  // Types (Records & Enums)
  for I := 0 to ASTMod.Types.Count - 1 do
  begin
    if ASTMod.Types[I] is TASTRecordDecl then
    begin
      RecNode := TASTRecordDecl(ASTMod.Types[I]);
      SetLength(ModDoc.Types, Length(ModDoc.Types) + 1);
      with ModDoc.Types[High(ModDoc.Types)] do
      begin
        Name := RecNode.Name;
        Kind := 'record';
        RawDoc := RecNode.DocComment;
        ParseDocComments(RawDoc, Summary, Description, ParamDocs, RetDoc);
        if Assigned(ParamDocs) then ParamDocs.Free;

        SetLength(Fields, RecNode.Fields.Count);
        for J := 0 to RecNode.Fields.Count - 1 do
        begin
          FieldNode := TASTRecordField(RecNode.Fields[J]);
          Fields[J].Name := FieldNode.Name;
          Fields[J].TypeName := FieldNode.TypeName;
          Fields[J].Doc := FieldNode.DocComment;
        end;
      end;
    end
    else if ASTMod.Types[I] is TASTEnumDecl then
    begin
      EnumNode := TASTEnumDecl(ASTMod.Types[I]);
      SetLength(ModDoc.Types, Length(ModDoc.Types) + 1);
      with ModDoc.Types[High(ModDoc.Types)] do
      begin
        Name := EnumNode.Name;
        Kind := 'enum';
        RawDoc := EnumNode.DocComment;
        ParseDocComments(RawDoc, Summary, Description, ParamDocs, RetDoc);
        if Assigned(ParamDocs) then ParamDocs.Free;

        SetLength(Fields, EnumNode.Variants.Count);
        for J := 0 to EnumNode.Variants.Count - 1 do
        begin
          Fields[J].Name := TASTEnumVariant(EnumNode.Variants[J]).Name;
          Fields[J].TypeName := '';
          Fields[J].Doc := TASTEnumVariant(EnumNode.Variants[J]).DocComment;
        end;
      end;
    end;
  end;

  // Traits
  for I := 0 to ASTMod.Traits.Count - 1 do
  begin
    TraitNode := TASTTraitDecl(ASTMod.Traits[I]);
    SetLength(ModDoc.Traits, Length(ModDoc.Traits) + 1);
    with ModDoc.Traits[High(ModDoc.Traits)] do
    begin
      Name := TraitNode.Name;
      RawDoc := TraitNode.DocComment;
      ParseDocComments(RawDoc, Summary, Description, ParamDocs, RetDoc);
      if Assigned(ParamDocs) then ParamDocs.Free;

      SetLength(Methods, TraitNode.Methods.Count);
      for J := 0 to TraitNode.Methods.Count - 1 do
      begin
        FuncNode := TASTFunction(TraitNode.Methods[J]);
        with Methods[J] do
        begin
          Name := FuncNode.Name;
          GenericParam := FuncNode.GenericParam;
          TraitBound := FuncNode.TraitBound;
          ReturnType := FuncNode.ReturnType;
          IsProcedure := FuncNode.IsProcedure;
          IsAsync := FuncNode.IsAsync;
          IsExtern := FuncNode.IsExtern;
          RawDoc := FuncNode.DocComment;
          ParseDocComments(RawDoc, Summary, Description, ParamDocs, RetDoc);

          SetLength(Params, FuncNode.Params.Count);
          for K := 0 to FuncNode.Params.Count - 1 do
          begin
            ParamNode := TASTParam(FuncNode.Params[K]);
            Params[K].Name := ParamNode.Name;
            Params[K].TypeName := ParamNode.TypeName;
            Params[K].Ownership := ParamNode.Ownership;
            if Assigned(ParamDocs) then
              Params[K].Doc := ParamDocs.Values[ParamNode.Name];
          end;
          if Assigned(ParamDocs) then ParamDocs.Free;
        end;
      end;
    end;
  end;

  // Functions
  for I := 0 to ASTMod.Functions.Count - 1 do
  begin
    FuncNode := TASTFunction(ASTMod.Functions[I]);
    SetLength(ModDoc.Functions, Length(ModDoc.Functions) + 1);
    with ModDoc.Functions[High(ModDoc.Functions)] do
    begin
      Name := FuncNode.Name;
      GenericParam := FuncNode.GenericParam;
      TraitBound := FuncNode.TraitBound;
      ReturnType := FuncNode.ReturnType;
      IsProcedure := FuncNode.IsProcedure;
      IsAsync := FuncNode.IsAsync;
      IsExtern := FuncNode.IsExtern;
      RawDoc := FuncNode.DocComment;
      ParseDocComments(RawDoc, Summary, Description, ParamDocs, RetDoc);

      SetLength(Params, FuncNode.Params.Count);
      for J := 0 to FuncNode.Params.Count - 1 do
      begin
        ParamNode := TASTParam(FuncNode.Params[J]);
        Params[J].Name := ParamNode.Name;
        Params[J].TypeName := ParamNode.TypeName;
        Params[J].Ownership := ParamNode.Ownership;
        if Assigned(ParamDocs) then
          Params[J].Doc := ParamDocs.Values[ParamNode.Name];
      end;
      if Assigned(ParamDocs) then ParamDocs.Free;

      // Contracts
      SetLength(Contracts, FuncNode.Requires.Count + FuncNode.Ensures.Count);
      K := 0;
      for J := 0 to FuncNode.Requires.Count - 1 do
      begin
        Contracts[K].Kind := 'require';
        Contracts[K].Expression := ExprToCode(TASTExpr(FuncNode.Requires[J]));
        Inc(K);
      end;
      for J := 0 to FuncNode.Ensures.Count - 1 do
      begin
        Contracts[K].Kind := 'ensure';
        Contracts[K].Expression := ExprToCode(TASTExpr(FuncNode.Ensures[J]));
        Inc(K);
      end;

      Doctests := ExtractDoctests(RawDoc);
    end;
  end;

  FModules.Add(ModDoc);
end;

procedure TAetherDocGenerator.AddFile(const AFilePath: string);
var
  Source: string;
  FS: TFileStream;
  StringStream: TStringStream;
  Lexer: TAetherLexer;
  Parser: TAetherParser;
  ASTMod: TASTModule;
begin
  if not FileExists(AFilePath) then
    raise Exception.CreateFmt('Aether file not found: "%s"', [AFilePath]);

  FS := TFileStream.Create(AFilePath, fmOpenRead or fmShareDenyNone);
  StringStream := TStringStream.Create('');
  try
    StringStream.CopyFrom(FS, FS.Size);
    Source := StringStream.DataString;
  finally
    StringStream.Free;
    FS.Free;
  end;

  Lexer := TAetherLexer.Create(Source);
  Parser := TAetherParser.Create(Lexer);
  try
    ASTMod := Parser.ParseModule;
    try
      ProcessASTModule(ASTMod, AFilePath);
    finally
      ASTMod.Free;
    end;
  finally
    Parser.Free;
    Lexer.Free;
  end;
end;

procedure TAetherDocGenerator.AddProject(const ARootDir: string);
var
  SearchRec: TSearchRec;
  ScanDir: string;
  SourceFiles: TStringList;
  I: Integer;

  procedure ScanFolder(const Folder: string);
  var
    SR: TSearchRec;
  begin
    if FindFirst(Folder + PathDelim + '*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') then
        begin
          if (SR.Attr and faDirectory) <> 0 then
          begin
            if (SR.Name <> 'bin') and (SR.Name <> 'build') and
               (SR.Name <> 'generated') and (SR.Name <> '.git') and
               (SR.Name <> '.aether') and (SR.Name <> 'node_modules') then
              ScanFolder(Folder + PathDelim + SR.Name);
          end
          else if LowerCase(ExtractFileExt(SR.Name)) = '.aeth' then
            SourceFiles.Add(Folder + PathDelim + SR.Name);
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
  end;

begin
  SourceFiles := TStringList.Create;
  try
    ScanDir := ARootDir;
    if DirectoryExists(ScanDir + PathDelim + 'src') then
      ScanFolder(ScanDir + PathDelim + 'src')
    else
      ScanFolder(ScanDir);

    for I := 0 to SourceFiles.Count - 1 do
    begin
      try
        AddFile(SourceFiles[I]);
      except
        on E: Exception do
          WriteLn(Format('Warning: Failed to parse "%s" for doc: %s', [ExtractFileName(SourceFiles[I]), E.Message]));
      end;
    end;
  finally
    SourceFiles.Free;
  end;
end;

procedure TAetherDocGenerator.GenerateHTML(const OutDir: string);
var
  I, J, K: Integer;
  ModDoc: TDocModule;
  OutFile, CSSFile, SearchJSFile: string;
  F: TextFile;
  SearchEntries: TStringList;
  TotalFuncs, TotalTypes, TotalTraits: Integer;

  function GetBadgeHTML(Ownership: TOwnershipKind): string;
  begin
    case Ownership of
      owTake: Result := '<span class="badge badge-take">take</span> ';
      owBorrow: Result := '<span class="badge badge-borrow">borrow</span> ';
      owMutBorrow: Result := '<span class="badge badge-mut-borrow">mut borrow</span> ';
    else
      Result := '';
    end;
  end;

begin
  ForceDirectories(OutDir);

  // 1. Generate style.css
  CSSFile := OutDir + PathDelim + 'style.css';
  AssignFile(F, CSSFile);
  Rewrite(F);
  WriteLn(F, ':root {');
  WriteLn(F, '  --bg: #0d1117; --card-bg: #161b22; --border: #30363d; --text: #c9d1d9;');
  WriteLn(F, '  --text-muted: #8b949e; --heading: #58a6ff; --accent: #2ea043; --link: #58a6ff;');
  WriteLn(F, '  --badge-borrow: #238636; --badge-mut: #d29922; --badge-take: #a371f7; --badge-async: #388bfd;');
  WriteLn(F, '  --code-bg: #1f242c; --pre-border: #30363d;');
  WriteLn(F, '}');
  WriteLn(F, 'body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background: var(--bg); color: var(--text); line-height: 1.6; }');
  WriteLn(F, 'header { background: #010409; border-bottom: 1px solid var(--border); padding: 16px 32px; display: flex; justify-content: space-between; align-items: center; position: sticky; top: 0; z-index: 100; }');
  WriteLn(F, '.logo { font-size: 1.3rem; font-weight: 700; color: #f0f6fc; text-decoration: none; display: flex; align-items: center; gap: 8px; }');
  WriteLn(F, '.logo span { color: var(--heading); }');
  WriteLn(F, '.search-bar { background: var(--card-bg); border: 1px solid var(--border); border-radius: 6px; padding: 8px 16px; color: var(--text); font-size: 0.9rem; width: 320px; outline: none; }');
  WriteLn(F, '.search-bar:focus { border-color: var(--link); }');
  WriteLn(F, '.container { display: flex; max-width: 1440px; margin: 0 auto; min-height: calc(100vh - 70px); }');
  WriteLn(F, '.sidebar { width: 280px; background: #090d13; border-right: 1px solid var(--border); padding: 24px; box-sizing: border-box; overflow-y: auto; height: calc(100vh - 70px); position: sticky; top: 70px; }');
  WriteLn(F, '.sidebar h3 { font-size: 0.8rem; text-transform: uppercase; color: var(--text-muted); letter-spacing: 0.05em; margin-top: 16px; }');
  WriteLn(F, '.sidebar ul { list-style: none; padding: 0; margin: 0; }');
  WriteLn(F, '.sidebar li { margin: 6px 0; }');
  WriteLn(F, '.sidebar a { color: var(--text); text-decoration: none; font-size: 0.95rem; display: block; padding: 4px 8px; border-radius: 4px; }');
  WriteLn(F, '.sidebar a:hover, .sidebar a.active { background: var(--card-bg); color: var(--link); }');
  WriteLn(F, '.main-content { flex: 1; padding: 40px; max-width: 960px; box-sizing: border-box; }');
  WriteLn(F, 'h1, h2, h3, h4 { color: #f0f6fc; font-weight: 600; margin-top: 24px; }');
  WriteLn(F, 'h1 { font-size: 2.2rem; border-bottom: 1px solid var(--border); padding-bottom: 12px; margin-top: 0; }');
  WriteLn(F, 'h2 { font-size: 1.5rem; border-bottom: 1px solid var(--border); padding-bottom: 8px; margin-top: 40px; }');
  WriteLn(F, 'h3 { font-size: 1.2rem; margin-top: 24px; }');
  WriteLn(F, 'a { color: var(--link); text-decoration: none; }');
  WriteLn(F, 'a:hover { text-decoration: underline; }');
  WriteLn(F, 'p { margin: 12px 0; }');
  WriteLn(F, '.badge { display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 0.75rem; font-weight: 600; color: #fff; text-transform: uppercase; vertical-align: middle; }');
  WriteLn(F, '.badge-borrow { background: var(--badge-borrow); }');
  WriteLn(F, '.badge-mut-borrow { background: var(--badge-mut); }');
  WriteLn(F, '.badge-take { background: var(--badge-take); }');
  WriteLn(F, '.badge-async { background: var(--badge-async); }');
  WriteLn(F, '.card { background: var(--card-bg); border: 1px solid var(--border); border-radius: 8px; padding: 20px; margin-bottom: 24px; }');
  WriteLn(F, '.code-block { background: var(--code-bg); border: 1px solid var(--pre-border); border-radius: 6px; padding: 14px 18px; font-family: "Fira Code", Consolas, monospace; font-size: 0.95rem; overflow-x: auto; color: #e6edf3; }');
  WriteLn(F, '.contract-box { background: rgba(56, 139, 253, 0.08); border-left: 4px solid var(--link); padding: 12px 16px; margin: 12px 0; border-radius: 0 6px 6px 0; font-family: monospace; }');
  WriteLn(F, '.contract-label { font-weight: bold; color: var(--link); margin-right: 8px; }');
  WriteLn(F, 'table { width: 100%; border-collapse: collapse; margin: 16px 0; }');
  WriteLn(F, 'th, td { text-align: left; padding: 10px 14px; border: 1px solid var(--border); }');
  WriteLn(F, 'th { background: #161b22; color: #f0f6fc; }');
  WriteLn(F, '.search-results { position: absolute; top: 60px; right: 32px; width: 400px; background: #161b22; border: 1px solid var(--border); border-radius: 8px; max-height: 400px; overflow-y: auto; display: none; box-shadow: 0 8px 24px rgba(0,0,0,0.5); z-index: 200; }');
  WriteLn(F, '.search-item { padding: 12px 16px; border-bottom: 1px solid var(--border); cursor: pointer; }');
  WriteLn(F, '.search-item:hover { background: #21262d; }');
  WriteLn(F, '.stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin: 24px 0; }');
  WriteLn(F, '.stat-card { background: var(--card-bg); border: 1px solid var(--border); border-radius: 8px; padding: 20px; text-align: center; }');
  WriteLn(F, '.stat-number { font-size: 2.2rem; font-weight: 700; color: var(--heading); }');
  WriteLn(F, '.stat-label { color: var(--text-muted); font-size: 0.9rem; margin-top: 4px; text-transform: uppercase; }');
  CloseFile(F);

  // 2. Prepare search.js
  SearchEntries := TStringList.Create;
  try
    TotalFuncs := 0;
    TotalTypes := 0;
    TotalTraits := 0;

    for I := 0 to FModules.Count - 1 do
    begin
      ModDoc := TDocModule(FModules[I]);
      Inc(TotalTypes, Length(ModDoc.Types));
      Inc(TotalTraits, Length(ModDoc.Traits));
      Inc(TotalFuncs, Length(ModDoc.Functions));

      SearchEntries.Add(Format('  { name: "%s", kind: "module", link: "%s.html", desc: "%s" },',
        [ModDoc.Name, ModDoc.Name, HTMLEscape(ModDoc.Summary)]));

      for J := 0 to High(ModDoc.Types) do
        SearchEntries.Add(Format('  { name: "%s", kind: "%s", link: "%s.html#type-%s", desc: "%s" },',
          [ModDoc.Types[J].Name, ModDoc.Types[J].Kind, ModDoc.Name, ModDoc.Types[J].Name, HTMLEscape(ModDoc.Types[J].Summary)]));

      for J := 0 to High(ModDoc.Traits) do
        SearchEntries.Add(Format('  { name: "%s", kind: "trait", link: "%s.html#trait-%s", desc: "%s" },',
          [ModDoc.Traits[J].Name, ModDoc.Name, ModDoc.Traits[J].Name, HTMLEscape(ModDoc.Traits[J].Summary)]));

      for J := 0 to High(ModDoc.Functions) do
        SearchEntries.Add(Format('  { name: "%s", kind: "function", link: "%s.html#func-%s", desc: "%s" },',
          [ModDoc.Functions[J].Name, ModDoc.Name, ModDoc.Functions[J].Name, HTMLEscape(ModDoc.Functions[J].Summary)]));
    end;

    SearchJSFile := OutDir + PathDelim + 'search.js';
    AssignFile(F, SearchJSFile);
    Rewrite(F);
    WriteLn(F, 'const DOC_SEARCH_INDEX = [');
    for I := 0 to SearchEntries.Count - 1 do
      WriteLn(F, SearchEntries[I]);
    WriteLn(F, '];');
    WriteLn(F, '');
    WriteLn(F, 'function initSearch() {');
    WriteLn(F, '  const input = document.getElementById("searchInput");');
    WriteLn(F, '  const results = document.getElementById("searchResults");');
    WriteLn(F, '  if (!input || !results) return;');
    WriteLn(F, '  input.addEventListener("input", (e) => {');
    WriteLn(F, '    const q = e.target.value.trim().toLowerCase();');
    WriteLn(F, '    if (q.length === 0) { results.style.display = "none"; return; }');
    WriteLn(F, '    const matches = DOC_SEARCH_INDEX.filter(item => item.name.toLowerCase().includes(q) || item.desc.toLowerCase().includes(q)).slice(0, 8);');
    WriteLn(F, '    if (matches.length === 0) {');
    WriteLn(F, '      results.innerHTML = ''<div class="search-item" style="color: #8b949e;">No symbols found.</div>'';');
    WriteLn(F, '    } else {');
    WriteLn(F, '      results.innerHTML = matches.map(m => `<div class="search-item" onclick="window.location.href=''${m.link}''"><span class="badge badge-async" style="margin-right: 8px;">${m.kind}</span><strong>${m.name}</strong><br><small style="color: #8b949e;">${m.desc || ""}</small></div>`).join("");');
    WriteLn(F, '    }');
    WriteLn(F, '    results.style.display = "block";');
    WriteLn(F, '  });');
    WriteLn(F, '  document.addEventListener("click", (e) => {');
    WriteLn(F, '    if (!input.contains(e.target) && !results.contains(e.target)) results.style.display = "none";');
    WriteLn(F, '  });');
    WriteLn(F, '}');
    WriteLn(F, 'window.addEventListener("DOMContentLoaded", initSearch);');
    CloseFile(F);
  finally
    SearchEntries.Free;
  end;

  // 3. Generate index.html
  OutFile := OutDir + PathDelim + 'index.html';
  AssignFile(F, OutFile);
  Rewrite(F);
  WriteLn(F, '<!DOCTYPE html>');
  WriteLn(F, '<html lang="en">');
  WriteLn(F, '<head>');
  WriteLn(F, '  <meta charset="UTF-8">');
  WriteLn(F, '  <meta name="viewport" content="width=device-width, initial-scale=1.0">');
  WriteLn(F, Format('  <title>%s - API Documentation</title>', [HTMLEscape(FProjectName)]));
  WriteLn(F, '  <link rel="stylesheet" href="style.css">');
  WriteLn(F, '  <script src="search.js"></script>');
  WriteLn(F, '</head>');
  WriteLn(F, '<body>');
  WriteLn(F, '  <header>');
  WriteLn(F, Format('    <a href="index.html" class="logo">⚡ <span>Aether</span>Doc | %s</a>', [HTMLEscape(FProjectName)]));
  WriteLn(F, '    <div style="position: relative;">');
  WriteLn(F, '      <input type="text" id="searchInput" class="search-bar" placeholder="Search modules, functions, types... (Ctrl+K)">');
  WriteLn(F, '      <div id="searchResults" class="search-results"></div>');
  WriteLn(F, '    </div>');
  WriteLn(F, '  </header>');
  WriteLn(F, '  <div class="container">');
  WriteLn(F, '    <aside class="sidebar">');
  WriteLn(F, '      <h3>Project Modules</h3>');
  WriteLn(F, '      <ul>');
  for I := 0 to FModules.Count - 1 do
  begin
    ModDoc := TDocModule(FModules[I]);
    WriteLn(F, Format('        <li><a href="%s.html">%s</a></li>', [ModDoc.Name, ModDoc.Name]));
  end;
  WriteLn(F, '      </ul>');
  WriteLn(F, '    </aside>');
  WriteLn(F, '    <main class="main-content">');
  WriteLn(F, Format('      <h1>%s <span style="font-size: 1rem; color: var(--text-muted); font-weight: normal;">v%s</span></h1>',
    [HTMLEscape(FProjectName), HTMLEscape(FProjectVersion)]));
  if FProjectDesc <> '' then
    WriteLn(F, Format('      <p style="font-size: 1.1rem; color: #8b949e;">%s</p>', [HTMLEscape(FProjectDesc)]));

  WriteLn(F, '      <div class="stats-grid">');
  WriteLn(F, Format('        <div class="stat-card"><div class="stat-number">%d</div><div class="stat-label">Modules</div></div>', [FModules.Count]));
  WriteLn(F, Format('        <div class="stat-card"><div class="stat-number">%d</div><div class="stat-label">Functions & Methods</div></div>', [TotalFuncs]));
  WriteLn(F, Format('        <div class="stat-card"><div class="stat-number">%d</div><div class="stat-label">Structs & Types</div></div>', [TotalTypes]));
  WriteLn(F, Format('        <div class="stat-card"><div class="stat-number">%d</div><div class="stat-label">Traits & Contracts</div></div>', [TotalTraits]));
  WriteLn(F, '      </div>');

  WriteLn(F, '      <h2>Module Index</h2>');
  for I := 0 to FModules.Count - 1 do
  begin
    ModDoc := TDocModule(FModules[I]);
    WriteLn(F, '      <div class="card">');
    WriteLn(F, Format('        <h3 style="margin-top: 0;"><a href="%s.html">%s</a></h3>', [ModDoc.Name, ModDoc.Name]));
    if ModDoc.Summary <> '' then
      WriteLn(F, Format('        <p>%s</p>', [HTMLEscape(ModDoc.Summary)]))
    else
      WriteLn(F, '        <p style="color: var(--text-muted); font-style: italic;">No description available.</p>');
    WriteLn(F, Format('        <small style="color: var(--text-muted);">%d functions | %d types | %d traits</small>',
      [Length(ModDoc.Functions), Length(ModDoc.Types), Length(ModDoc.Traits)]));
    WriteLn(F, '      </div>');
  end;

  WriteLn(F, '    </main>');
  WriteLn(F, '  </div>');
  WriteLn(F, '</body>');
  WriteLn(F, '</html>');
  CloseFile(F);

  // 4. Generate individual page for each module
  for I := 0 to FModules.Count - 1 do
  begin
    ModDoc := TDocModule(FModules[I]);
    OutFile := OutDir + PathDelim + ModDoc.Name + '.html';
    AssignFile(F, OutFile);
    Rewrite(F);
    WriteLn(F, '<!DOCTYPE html>');
    WriteLn(F, '<html lang="en">');
    WriteLn(F, '<head>');
    WriteLn(F, '  <meta charset="UTF-8">');
    WriteLn(F, '  <meta name="viewport" content="width=device-width, initial-scale=1.0">');
    WriteLn(F, Format('  <title>Module %s - %s</title>', [ModDoc.Name, HTMLEscape(FProjectName)]));
    WriteLn(F, '  <link rel="stylesheet" href="style.css">');
    WriteLn(F, '  <script src="search.js"></script>');
    WriteLn(F, '</head>');
    WriteLn(F, '<body>');
    WriteLn(F, '  <header>');
    WriteLn(F, Format('    <a href="index.html" class="logo">⚡ <span>Aether</span>Doc | %s</a>', [HTMLEscape(FProjectName)]));
    WriteLn(F, '    <div style="position: relative;">');
    WriteLn(F, '      <input type="text" id="searchInput" class="search-bar" placeholder="Search symbols... (Ctrl+K)">');
    WriteLn(F, '      <div id="searchResults" class="search-results"></div>');
    WriteLn(F, '    </div>');
    WriteLn(F, '  </header>');
    WriteLn(F, '  <div class="container">');
    WriteLn(F, '    <aside class="sidebar">');
    WriteLn(F, '      <h3>Modules</h3>');
    WriteLn(F, '      <ul>');
    for J := 0 to FModules.Count - 1 do
    begin
      if TDocModule(FModules[J]) = ModDoc then
        WriteLn(F, Format('        <li><a href="%s.html" class="active">%s</a></li>', [TDocModule(FModules[J]).Name, TDocModule(FModules[J]).Name]))
      else
        WriteLn(F, Format('        <li><a href="%s.html">%s</a></li>', [TDocModule(FModules[J]).Name, TDocModule(FModules[J]).Name]));
    end;
    WriteLn(F, '      </ul>');
    WriteLn(F, '      <h3>In This Module</h3>');
    WriteLn(F, '      <ul>');
    if Length(ModDoc.Types) > 0 then WriteLn(F, '        <li><a href="#types">Types & Structs</a></li>');
    if Length(ModDoc.Traits) > 0 then WriteLn(F, '        <li><a href="#traits">Traits</a></li>');
    if Length(ModDoc.Functions) > 0 then WriteLn(F, '        <li><a href="#functions">Functions</a></li>');
    WriteLn(F, '      </ul>');
    WriteLn(F, '    </aside>');
    WriteLn(F, '    <main class="main-content">');
    WriteLn(F, Format('      <h1>Module <code>%s</code></h1>', [ModDoc.Name]));
    if ModDoc.Summary <> '' then
      WriteLn(F, Format('      <p style="font-size: 1.15rem; color: #e6edf3;">%s</p>', [HTMLEscape(ModDoc.Summary)]));
    if ModDoc.Description <> '' then
      WriteLn(F, Format('      <p style="color: var(--text-muted);">%s</p>', [HTMLEscape(ModDoc.Description)]));

    // Imports / Dependency Graph
    if ModDoc.Imports.Count > 0 then
    begin
      WriteLn(F, '      <h3>Imported Dependencies</h3>');
      WriteLn(F, '      <div class="code-block" style="display: flex; gap: 8px; flex-wrap: wrap;">');
      for J := 0 to ModDoc.Imports.Count - 1 do
        WriteLn(F, Format('        <span class="badge badge-async">%s</span>', [ModDoc.Imports[J]]));
      WriteLn(F, '      </div>');
    end;

    // Types
    if Length(ModDoc.Types) > 0 then
    begin
      WriteLn(F, '      <h2 id="types">Types & Structs</h2>');
      for J := 0 to High(ModDoc.Types) do
      begin
        with ModDoc.Types[J] do
        begin
          WriteLn(F, Format('      <div class="card" id="type-%s">', [Name]));
          WriteLn(F, Format('        <h3 style="margin-top: 0;"><span class="badge badge-take">%s</span> %s</h3>', [Kind, Name]));
          if Summary <> '' then WriteLn(F, Format('        <p>%s</p>', [HTMLEscape(Summary)]));
          if Length(Fields) > 0 then
          begin
            WriteLn(F, '        <table><thead><tr><th>Field / Variant</th><th>Type</th><th>Description</th></tr></thead><tbody>');
            for K := 0 to High(Fields) do
            begin
              WriteLn(F, Format('        <tr><td><code>%s</code></td><td><code>%s</code></td><td>%s</td></tr>',
                [Fields[K].Name, Fields[K].TypeName, HTMLEscape(Fields[K].Doc)]));
            end;
            WriteLn(F, '        </tbody></table>');
          end;
          WriteLn(F, '      </div>');
        end;
      end;
    end;

    // Traits
    if Length(ModDoc.Traits) > 0 then
    begin
      WriteLn(F, '      <h2 id="traits">Traits (Type Contracts)</h2>');
      for J := 0 to High(ModDoc.Traits) do
      begin
        with ModDoc.Traits[J] do
        begin
          WriteLn(F, Format('      <div class="card" id="trait-%s">', [Name]));
          WriteLn(F, Format('        <h3 style="margin-top: 0;"><span class="badge badge-mut-borrow">trait</span> %s</h3>', [Name]));
          if Summary <> '' then WriteLn(F, Format('        <p>%s</p>', [HTMLEscape(Summary)]));
          if Length(Methods) > 0 then
          begin
            WriteLn(F, '        <h4>Required Methods:</h4>');
            for K := 0 to High(Methods) do
            begin
              WriteLn(F, '        <div class="code-block">');
              if Methods[K].IsProcedure then
                WriteLn(F, Format('          procedure %s(...);', [Methods[K].Name]))
              else
                WriteLn(F, Format('          function %s(...) return %s;', [Methods[K].Name, Methods[K].ReturnType]));
              WriteLn(F, '        </div>');
            end;
          end;
          WriteLn(F, '      </div>');
        end;
      end;
    end;

    // Functions
    if Length(ModDoc.Functions) > 0 then
    begin
      WriteLn(F, '      <h2 id="functions">Functions & Methods</h2>');
      for J := 0 to High(ModDoc.Functions) do
      begin
        with ModDoc.Functions[J] do
        begin
          WriteLn(F, Format('      <div class="card" id="func-%s">', [Name]));
          WriteLn(F, '        <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 8px;">');
          if IsAsync then WriteLn(F, '          <span class="badge badge-async">async</span>');
          WriteLn(F, Format('          <h3 style="margin: 0;">%s</h3>', [Name]));
          WriteLn(F, '        </div>');

          // Code Signature
          WriteLn(F, '        <div class="code-block">');
          if IsAsync then Write(F, 'async ');
          if IsProcedure then Write(F, 'procedure ') else Write(F, 'function ');
          Write(F, Name);
          if GenericParam <> '' then
          begin
            Write(F, '<' + GenericParam);
            if TraitBound <> '' then Write(F, ': ' + TraitBound);
            Write(F, '>');
          end;
          Write(F, '(');
          for K := 0 to High(Params) do
          begin
            if K > 0 then Write(F, ', ');
            case Params[K].Ownership of
              owTake: Write(F, 'take ');
              owBorrow: Write(F, 'borrow ');
              owMutBorrow: Write(F, 'mut borrow ');
            end;
            Write(F, Params[K].Name + ': ' + Params[K].TypeName);
          end;
          Write(F, ')');
          if (not IsProcedure) and (ReturnType <> '') then Write(F, ' return ' + ReturnType);
          WriteLn(F, ';');
          WriteLn(F, '        </div>');

          if Summary <> '' then WriteLn(F, Format('        <p style="font-weight: 500;">%s</p>', [HTMLEscape(Summary)]));
          if Description <> '' then WriteLn(F, Format('        <p>%s</p>', [HTMLEscape(Description)]));

          // Formal Contracts
          if Length(Contracts) > 0 then
          begin
            WriteLn(F, '        <div style="margin: 14px 0;">');
            for K := 0 to High(Contracts) do
            begin
              WriteLn(F, Format('          <div class="contract-box"><span class="contract-label">%s:</span> <code>%s</code></div>',
                [Contracts[K].Kind, HTMLEscape(Contracts[K].Expression)]));
            end;
            WriteLn(F, '        </div>');
          end;

          // Parameters Table
          if Length(Params) > 0 then
          begin
            WriteLn(F, '        <h4>Parameters</h4>');
            WriteLn(F, '        <table><thead><tr><th>Parameter</th><th>Ownership</th><th>Type</th><th>Description</th></tr></thead><tbody>');
            for K := 0 to High(Params) do
            begin
              WriteLn(F, Format('        <tr><td><code>%s</code></td><td>%s</td><td><code>%s</code></td><td>%s</td></tr>',
                [Params[K].Name, GetBadgeHTML(Params[K].Ownership), Params[K].TypeName, HTMLEscape(Params[K].Doc)]));
            end;
            WriteLn(F, '        </tbody></table>');
          end;

          // Doctests
          if Length(Doctests) > 0 then
          begin
            WriteLn(F, '        <h4>Testable Example (Doctest)</h4>');
            for K := 0 to High(Doctests) do
            begin
              WriteLn(F, '        <pre class="code-block"><code>' + HTMLEscape(Doctests[K]) + '</code></pre>');
            end;
          end;

          WriteLn(F, '      </div>');
        end;
      end;
    end;

    WriteLn(F, '    </main>');
    WriteLn(F, '  </div>');
    WriteLn(F, '</body>');
    WriteLn(F, '</html>');
    CloseFile(F);
  end;
end;

procedure TAetherDocGenerator.GenerateMarkdown(const OutDir: string);
var
  I, J, K: Integer;
  ModDoc: TDocModule;
  OutFile: string;
  F: TextFile;
begin
  ForceDirectories(OutDir);
  OutFile := OutDir + PathDelim + 'API.md';
  AssignFile(F, OutFile);
  Rewrite(F);

  WriteLn(F, '# ' + FProjectName + ' - API Documentation');
  WriteLn(F, '');
  if FProjectDesc <> '' then WriteLn(F, FProjectDesc + LineEnding);

  for I := 0 to FModules.Count - 1 do
  begin
    ModDoc := TDocModule(FModules[I]);
    WriteLn(F, '---');
    WriteLn(F, '');
    WriteLn(F, '## Module `' + ModDoc.Name + '`');
    WriteLn(F, '');
    if ModDoc.Summary <> '' then WriteLn(F, ModDoc.Summary + LineEnding);

    if Length(ModDoc.Functions) > 0 then
    begin
      WriteLn(F, '### Functions');
      WriteLn(F, '');
      for J := 0 to High(ModDoc.Functions) do
      begin
        with ModDoc.Functions[J] do
        begin
          WriteLn(F, '#### `' + Name + '`');
          WriteLn(F, '');
          if Summary <> '' then WriteLn(F, Summary + LineEnding);

          WriteLn(F, '```aether');
          if IsAsync then Write(F, 'async ');
          if IsProcedure then Write(F, 'procedure ') else Write(F, 'function ');
          Write(F, Name + '(');
          for K := 0 to High(Params) do
          begin
            if K > 0 then Write(F, ', ');
            case Params[K].Ownership of
              owTake: Write(F, 'take ');
              owBorrow: Write(F, 'borrow ');
              owMutBorrow: Write(F, 'mut borrow ');
            end;
            Write(F, Params[K].Name + ': ' + Params[K].TypeName);
          end;
          Write(F, ')');
          if (not IsProcedure) and (ReturnType <> '') then Write(F, ' return ' + ReturnType);
          WriteLn(F, ';');
          WriteLn(F, '```');
          WriteLn(F, '');

          if Length(Contracts) > 0 then
          begin
            WriteLn(F, '**Contratos:**');
            for K := 0 to High(Contracts) do
              WriteLn(F, Format('- `%s: %s`', [Contracts[K].Kind, Contracts[K].Expression]));
            WriteLn(F, '');
          end;
        end;
      end;
    end;
  end;

  CloseFile(F);
end;

procedure TAetherDocGenerator.RunDoctests;
var
  I, J, K, L, TotalTests, PassedTests, AssignIdx, ColonIdx: Integer;
  ModDoc: TDocModule;
  TempDir, TestFile, ExeFile, TestCode, VarLines, BodyLines, TrimmedL: string;
  LineWithoutVar, VarDeclPart, ExprPart, VarNameOnly: string;
  TestLines: TStringList;
  F: TextFile;
  Proc: TProcess;
begin
  WriteLn('========================================================');
  WriteLn('  Aether Doctest Runner - Example Validation            ');
  WriteLn('========================================================');

  TotalTests := 0;
  PassedTests := 0;
  TempDir := GetTempDir(True) + 'aether_doctests_' + IntToStr(GetProcessID);
  ForceDirectories(TempDir);

  for I := 0 to FModules.Count - 1 do
  begin
    ModDoc := TDocModule(FModules[I]);
    for J := 0 to High(ModDoc.Functions) do
    begin
      for K := 0 to High(ModDoc.Functions[J].Doctests) do
      begin
        Inc(TotalTests);
        Write(Format('  [DOCTEST] %s.%s (Example %d)... ', [ModDoc.Name, ModDoc.Functions[J].Name, K + 1]));

        TestFile := TempDir + PathDelim + Format('test_%s_%d.aeth', [ModDoc.Name, TotalTests]);
        ExeFile := TempDir + PathDelim + Format('test_%s_%d.exe', [ModDoc.Name, TotalTests]);

        TestCode := ModDoc.Functions[J].Doctests[K];
        AssignFile(F, TestFile);
        Rewrite(F);

        if (Pos('program ', LowerCase(TestCode)) > 0) or (Pos('begin', LowerCase(TestCode)) > 0) then
        begin
          WriteLn(F, TestCode);
        end
        else
        begin
          VarLines := '';
          BodyLines := '';
          TestLines := TStringList.Create;
          try
            TestLines.Text := TestCode;
            for L := 0 to TestLines.Count - 1 do
            begin
              TrimmedL := Trim(TestLines[L]);
              if Pos('var ', TrimmedL) = 1 then
              begin
                LineWithoutVar := Trim(Copy(TrimmedL, 5, Length(TrimmedL)));
                AssignIdx := Pos(':=', LineWithoutVar);
                if AssignIdx > 0 then
                begin
                  VarDeclPart := Trim(Copy(LineWithoutVar, 1, AssignIdx - 1));
                  ExprPart := Trim(Copy(LineWithoutVar, AssignIdx + 2, Length(LineWithoutVar)));
                  ColonIdx := Pos(':', VarDeclPart);
                  if ColonIdx > 0 then
                  begin
                    VarNameOnly := Trim(Copy(VarDeclPart, 1, ColonIdx - 1));
                    VarLines := VarLines + '  ' + VarDeclPart + ';' + LineEnding;
                    BodyLines := BodyLines + '  ' + VarNameOnly + ' := ' + ExprPart + LineEnding;
                  end
                  else
                  begin
                    VarLines := VarLines + '  ' + VarDeclPart + ';' + LineEnding;
                    BodyLines := BodyLines + '  ' + VarDeclPart + ' := ' + ExprPart + LineEnding;
                  end;
                end
                else
                  VarLines := VarLines + '  ' + LineWithoutVar + LineEnding;
              end
              else if TrimmedL <> '' then
                BodyLines := BodyLines + '  ' + TestLines[L] + LineEnding;
            end;
          finally
            TestLines.Free;
          end;

          WriteLn(F, Format('module test_%s_%d;', [ModDoc.Name, TotalTests]));
          WriteLn(F, Format('import %s;', [ModDoc.Name]));
          WriteLn(F, '');
          WriteLn(F, 'program Main;');
          if VarLines <> '' then
          begin
            WriteLn(F, 'var');
            Write(F, VarLines);
          end;
          WriteLn(F, 'begin');
          Write(F, BodyLines);
          WriteLn(F, Format('end test_%s_%d.', [ModDoc.Name, TotalTests]));
        end;
        CloseFile(F);

        Proc := TProcess.Create(nil);
        try
          Proc.Executable := ParamStr(0); // Invoking aetherc
          Proc.Parameters.Add(TestFile);
          if ModDoc.FilePath <> '' then
          begin
            Proc.Parameters.Add('-I' + ExtractFileDir(ModDoc.FilePath));
            Proc.Parameters.Add('-Fu' + ExtractFileDir(ModDoc.FilePath));
          end;
          Proc.Parameters.Add('-o');
          Proc.Parameters.Add(ExeFile);
          Proc.Options := [poWaitOnExit];
          Proc.Execute;

          if Proc.ExitCode = 0 then
          begin
            // Run test
            Proc.Executable := ExeFile;
            Proc.Parameters.Clear;
            Proc.Execute;
            if Proc.ExitCode = 0 then
            begin
              WriteLn('PASS');
              Inc(PassedTests);
            end
            else
              WriteLn('FAIL (Assertion failure)');
          end
          else
            WriteLn('FAIL (Compilation error)');
        finally
          Proc.Free;
        end;
      end;
    end;
  end;

  WriteLn('--------------------------------------------------------');
  WriteLn(Format('  Results: %d doctests run | %d passed | %d failed',
    [TotalTests, PassedTests, TotalTests - PassedTests]));
  WriteLn('========================================================');
end;

procedure TAetherDocGenerator.Generate(const AOutDir: string; AFormat: TAetherDocFormat;
  AOpenBrowser: Boolean; ATest: Boolean);
var
  TargetDir, IndexFile: string;
  Proc: TProcess;
begin
  TargetDir := AOutDir;
  if TargetDir = '' then TargetDir := 'docs' + PathDelim + 'api';

  if (AFormat = dfHTML) or (AFormat = dfAll) then
    GenerateHTML(TargetDir);

  if (AFormat = dfMarkdown) or (AFormat = dfAll) then
    GenerateMarkdown(TargetDir);

  WriteLn('');
  WriteLn('SUCCESS! Canonical documentation generated successfully:');
  if (AFormat = dfHTML) or (AFormat = dfAll) then
    WriteLn('  --> ' + TargetDir + PathDelim + 'index.html (Interactive Static Site)');
  if (AFormat = dfMarkdown) or (AFormat = dfAll) then
    WriteLn('  --> ' + TargetDir + PathDelim + 'API.md (Markdown)');

  if ATest then
    RunDoctests;

  if AOpenBrowser and ((AFormat = dfHTML) or (AFormat = dfAll)) then
  begin
    IndexFile := ExpandFileName(TargetDir + PathDelim + 'index.html');
    Proc := TProcess.Create(nil);
    try
      {$IFDEF WINDOWS}
      Proc.Executable := 'cmd.exe';
      Proc.Parameters.Add('/c');
      Proc.Parameters.Add('start');
      Proc.Parameters.Add('');
      Proc.Parameters.Add(IndexFile);
      {$ELSE}
      Proc.Executable := 'xdg-open';
      Proc.Parameters.Add(IndexFile);
      {$ENDIF}
      Proc.Execute;
    finally
      Proc.Free;
    end;
  end;
end;

procedure HandleDocCommand;
var
  I: Integer;
  Arg, TargetPath, OutDir, FormatStr: string;
  DocFormat: TAetherDocFormat;
  OptOpen, OptTest: Boolean;
  Gen: TAetherDocGenerator;
begin
  TargetPath := '.';
  OutDir := 'docs' + PathDelim + 'api';
  DocFormat := dfHTML;
  OptOpen := False;
  OptTest := False;

  I := 2;
  while I <= ParamCount do
  begin
    Arg := ParamStr(I);
    if Pos('--out-dir=', Arg) = 1 then
      OutDir := Copy(Arg, 11, Length(Arg))
    else if Pos('-o', Arg) = 1 then
    begin
      if Arg = '-o' then
      begin
        Inc(I);
        if I <= ParamCount then OutDir := ParamStr(I);
      end
      else
        OutDir := Copy(Arg, 3, Length(Arg));
    end
    else if Pos('--format=', Arg) = 1 then
    begin
      FormatStr := LowerCase(Copy(Arg, 10, Length(Arg)));
      if FormatStr = 'md' then DocFormat := dfMarkdown
      else if FormatStr = 'all' then DocFormat := dfAll
      else DocFormat := dfHTML;
    end
    else if (Arg = '--open') or (Arg = '-open') then
      OptOpen := True
    else if (Arg = '--test') or (Arg = '-test') then
      OptTest := True
    else if (Length(Arg) > 0) and (Arg[1] <> '-') then
      TargetPath := Arg;
    Inc(I);
  end;

  Gen := TAetherDocGenerator.Create('Aether Application', '1.0.0', 'Canonical API and module documentation for the Aether programming language.');
  try
    if DirectoryExists(TargetPath) then
      Gen.AddProject(TargetPath)
    else if FileExists(TargetPath) then
      Gen.AddFile(TargetPath)
    else
      raise Exception.CreateFmt('Specified path not found: "%s"', [TargetPath]);

    Gen.Generate(OutDir, DocFormat, OptOpen, OptTest);
  finally
    Gen.Free;
  end;
end;

end.