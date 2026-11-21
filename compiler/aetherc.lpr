program aetherc;

{$mode objfpc}{$H+}
{$codepage utf8}

uses
  SysUtils, Classes,
  uAetherTokens,
  uAetherLexer,
  uAetherAST,
  uAetherParser,
  uAetherSymbols,
  uAetherTypeChecker,
  uAetherBorrowChecker,
  uAetherEmitterPascal,
  uAetherEmitterC,
  uAetherToolchain,
  uAetherJSONDiag,
  uAetherLSP,
  uAetherProject;

procedure PrintBanner;
begin
  WriteLn('========================================================');
  WriteLn('  AetherLang Compiler (aetherc) - Versao 0.5.0 (Alpha)  ');
  WriteLn('  Pascal Structure + Rust Safety + AI-Native Design     ');
  WriteLn('========================================================');
end;

procedure PrintUsage;
begin
  WriteLn('Uso: aetherc <comando | arquivo.aeth> [opcoes]');
  WriteLn('');
  WriteLn('Comandos de Gerenciamento de Projetos e Pacotes:');
  WriteLn('  init [nome]       Inicializa um novo projeto Aether com manifesto aether.json');
  WriteLn('  new <nome>        Cria uma nova pasta com o projeto Aether estruturado');
  WriteLn('  add <pacote>      Adiciona uma dependencia ao manifesto aether.json');
  WriteLn('  test [filtro]     Executa testes unitarios da pasta tests/');
  WriteLn('  build             Compila o projeto atual baseado no manifesto aether.json');
  WriteLn('  run               Compila e executa imediatamente o binario do projeto');
  WriteLn('  lsp               Inicia o servidor de linguagem (Language Server Protocol)');
  WriteLn('');
  WriteLn('Opcoes Principais:');
  WriteLn('  --doctor          Verifica e diagnostica o ambiente (FPC e MSYS2/GCC)');
  WriteLn('  --target=pascal   Compila gerando Object Pascal e invoca FPC (Padrao)');
  WriteLn('  --target=c        Compila gerando C99 e invoca GCC (MSYS2 no Windows)');
  WriteLn('  --check-only      Executa apenas analise sintatica, tipos e borrow checker');
  WriteLn('  --dump-tokens     Exibe a lista de tokens do Lexer');
  WriteLn('  --dump-ast        Exibe a Arvore Sintatica Abstrata (AST)');
  WriteLn('  --emit-json-diag  Gera relatorio de diagnostico de erros em formato JSON para IA');
  WriteLn('  --lsp             Inicia o servidor de linguagem (Language Server Protocol)');
  WriteLn('  -o <arquivo.exe>  Especifica o nome do executavel de saida');
  WriteLn('  -h, --help        Exibe esta mensagem de ajuda');
end;

function LoadFileContent(const FileName: string): string;
var
  FileStream: TFileStream;
  StringStream: TStringStream;
begin
  if not FileExists(FileName) then
    raise Exception.CreateFmt('Arquivo nao encontrado: "%s"', [FileName]);

  FileStream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  StringStream := TStringStream.Create('');
  try
    StringStream.CopyFrom(FileStream, FileStream.Size);
    Result := StringStream.DataString;
  finally
    StringStream.Free;
    FileStream.Free;
  end;
end;

procedure DumpTokens(const SourceFile: string);
var
  Source: string;
  Lexer: TAetherLexer;
  Tok: TToken;
  Count: Integer;
begin
  Source := LoadFileContent(SourceFile);
  Lexer := TAetherLexer.Create(Source);
  try
    WriteLn(Format('--- Analise Lexica (Tokens) de: %s ---', [SourceFile]));
    Count := 0;
    repeat
      Tok := Lexer.NextToken;
      Inc(Count);
      WriteLn(Format('[Linha %3d, Col %3d] %-16s : "%s"', 
        [Tok.Line, Tok.Col, TokenKindToString(Tok.Kind), Tok.Value]));
    until Tok.Kind = tokEOF;
    WriteLn(Format('Total de tokens analisados: %d', [Count]));
  finally
    Lexer.Free;
  end;
end;

function ExtractLastSegment(const S: string): string;
var
  I: Integer;
begin
  for I := Length(S) downto 1 do
    if S[I] = '.' then
      Exit(Copy(S, I + 1, Length(S)));
  Result := S;
end;

function CamelToSnake(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    if (S[I] in ['A'..'Z']) and (I > 1) and (S[I - 1] <> '.') and (S[I - 1] <> '_') and (S[I - 1] <> '/') and (S[I - 1] <> '\') then
      Result := Result + '_' + LowerCase(S[I])
    else
      Result := Result + LowerCase(S[I]);
  end;
end;

function FindModuleFile(const ModName, BaseDir: string): string;
var
  Candidate: string;
  ExeDir, StdDir, CacheDir, DepDir: string;
  RelPath, RelPathLower, RelPathSnake: string;
  ProjConfig: TAetherProjectConfig;
  I: Integer;
begin
  Result := '';
  RelPath := StringReplace(ModName, '.', PathDelim, [rfReplaceAll]);
  RelPathLower := LowerCase(RelPath);
  RelPathSnake := StringReplace(CamelToSnake(ModName), '.', PathDelim, [rfReplaceAll]);

  // 1. Diretório do arquivo fonte
  Candidate := BaseDir + RelPath + '.aeth';
  if FileExists(Candidate) then Exit(Candidate);
  Candidate := BaseDir + RelPathLower + '.aeth';
  if FileExists(Candidate) then Exit(Candidate);
  Candidate := BaseDir + RelPathSnake + '.aeth';
  if FileExists(Candidate) then Exit(Candidate);

  // 2. Subpasta std/ relativa ao diretório do arquivo fonte
  Candidate := BaseDir + 'std' + PathDelim + RelPath + '.aeth';
  if FileExists(Candidate) then Exit(Candidate);
  Candidate := BaseDir + 'std' + PathDelim + RelPathLower + '.aeth';
  if FileExists(Candidate) then Exit(Candidate);
  Candidate := BaseDir + 'std' + PathDelim + RelPathSnake + '.aeth';
  if FileExists(Candidate) then Exit(Candidate);

  // 3. Subpasta std/ relativa ao compilador (bin/../std)
  ExeDir := ExtractFilePath(ParamStr(0));
  StdDir := ExpandFileName(ExeDir + '..' + PathDelim + 'std');
  Candidate := StdDir + PathDelim + RelPath + '.aeth';
  if FileExists(Candidate) then Exit(Candidate);
  Candidate := StdDir + PathDelim + RelPathLower + '.aeth';
  if FileExists(Candidate) then Exit(Candidate);
  Candidate := StdDir + PathDelim + RelPathSnake + '.aeth';
  if FileExists(Candidate) then Exit(Candidate);

  // 4. Diretório de trabalho atual (cwd)
  Candidate := GetCurrentDir + PathDelim + RelPath + '.aeth';
  if FileExists(Candidate) then Exit(Candidate);
  Candidate := GetCurrentDir + PathDelim + RelPathLower + '.aeth';
  if FileExists(Candidate) then Exit(Candidate);
  Candidate := GetCurrentDir + PathDelim + RelPathSnake + '.aeth';
  if FileExists(Candidate) then Exit(Candidate);
  Candidate := GetCurrentDir + PathDelim + 'std' + PathDelim + RelPath + '.aeth';
  if FileExists(Candidate) then Exit(Candidate);
  Candidate := GetCurrentDir + PathDelim + 'std' + PathDelim + RelPathLower + '.aeth';
  if FileExists(Candidate) then Exit(Candidate);
  Candidate := GetCurrentDir + PathDelim + 'std' + PathDelim + RelPathSnake + '.aeth';
  if FileExists(Candidate) then Exit(Candidate);

  // 5. Dependências do projeto atual (aether.json) e Cache Global (~/.aether/cache)
  if LoadProjectConfig(ProjConfig) then
  begin
    for I := 0 to High(ProjConfig.Dependencies) do
    begin
      if ProjConfig.Dependencies[I].Path <> '' then
        DepDir := ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.Dependencies[I].Path)
      else
        DepDir := ExpandFileName(ProjConfig.RootDir + PathDelim + '.aether' + PathDelim + 'deps' + PathDelim + ProjConfig.Dependencies[I].Name);

      Candidate := DepDir + PathDelim + RelPath + '.aeth';
      if FileExists(Candidate) then Exit(Candidate);
      Candidate := DepDir + PathDelim + 'src' + PathDelim + RelPath + '.aeth';
      if FileExists(Candidate) then Exit(Candidate);
      Candidate := DepDir + PathDelim + RelPathLower + '.aeth';
      if FileExists(Candidate) then Exit(Candidate);
      Candidate := DepDir + PathDelim + 'src' + PathDelim + RelPathLower + '.aeth';
      if FileExists(Candidate) then Exit(Candidate);
      Candidate := DepDir + PathDelim + RelPathSnake + '.aeth';
      if FileExists(Candidate) then Exit(Candidate);
      Candidate := DepDir + PathDelim + 'src' + PathDelim + RelPathSnake + '.aeth';
      if FileExists(Candidate) then Exit(Candidate);

      // Cache global (~/.aether/cache/<pkg>)
      CacheDir := GetAetherCacheDir + PathDelim + ProjConfig.Dependencies[I].Name;
      Candidate := CacheDir + PathDelim + RelPath + '.aeth';
      if FileExists(Candidate) then Exit(Candidate);
      Candidate := CacheDir + PathDelim + 'src' + PathDelim + RelPath + '.aeth';
      if FileExists(Candidate) then Exit(Candidate);
      Candidate := CacheDir + PathDelim + RelPathLower + '.aeth';
      if FileExists(Candidate) then Exit(Candidate);
      Candidate := CacheDir + PathDelim + 'src' + PathDelim + RelPathLower + '.aeth';
      if FileExists(Candidate) then Exit(Candidate);
      Candidate := CacheDir + PathDelim + RelPathSnake + '.aeth';
      if FileExists(Candidate) then Exit(Candidate);
      Candidate := CacheDir + PathDelim + 'src' + PathDelim + RelPathSnake + '.aeth';
      if FileExists(Candidate) then Exit(Candidate);
    end;
  end;
end;

procedure CollectModuleImports(TargetMod: TASTModule; const BaseDir: string; Visited: TStringList; AllTypes, AllTraits, AllImpls, AllFuncs: TFPList; PascalImports: TStringList);
var
  I, J: Integer;
  ModName, ModPath, ModSource: string;
  SubLexer: TAetherLexer;
  SubParser: TAetherParser;
  SubMod: TASTModule;
  ExpectedName, LastSegment: string;
begin
  for I := 0 to TargetMod.Imports.Count - 1 do
  begin
    ModName := TargetMod.Imports[I];
    if Visited.IndexOf(LowerCase(ModName)) >= 0 then Continue;
    Visited.Add(LowerCase(ModName));

    ModPath := FindModuleFile(ModName, BaseDir);
    if ModPath = '' then
      raise Exception.CreateFmt('Modulo Aether "%s" nao encontrado. Verifique se o arquivo existe ou se esta em "std/".', [ModName]);

    ModSource := LoadFileContent(ModPath);
    SubLexer := TAetherLexer.Create(ModSource);
    SubParser := TAetherParser.Create(SubLexer);
    try
      SubMod := SubParser.ParseModule;
      try
        CollectModuleImports(SubMod, ExtractFilePath(ModPath), Visited, AllTypes, AllTraits, AllImpls, AllFuncs, PascalImports);

        // Validação Estrita 1:1 de Módulos Importados (Fase 13)
        ExpectedName := ModName;
        LastSegment := ExtractLastSegment(ExpectedName);
        if not SameText(SubMod.Name, ExpectedName) and not SameText(SubMod.Name, LastSegment) then
          raise Exception.CreateFmt('[Erro de Modulo E0005 em %s]: Nome do modulo declarado "%s" difere do esperado "%s". Em Aether, o nome do modulo deve corresponder ao nome do arquivo.', [ExtractFileName(ModPath), SubMod.Name, ExpectedName]);

        for J := 0 to SubMod.PascalImports.Count - 1 do
          if PascalImports.IndexOf(SubMod.PascalImports[J]) < 0 then
            PascalImports.Add(SubMod.PascalImports[J]);

        while SubMod.Types.Count > 0 do
          AllTypes.Add(SubMod.Types.Extract(SubMod.Types[0]));

        while SubMod.Traits.Count > 0 do
          AllTraits.Add(SubMod.Traits.Extract(SubMod.Traits[0]));

        while SubMod.Impls.Count > 0 do
          AllImpls.Add(SubMod.Impls.Extract(SubMod.Impls[0]));

        while SubMod.Functions.Count > 0 do
          AllFuncs.Add(SubMod.Functions.Extract(SubMod.Functions[0]));
      finally
        SubMod.Free;
      end;
    finally
      SubParser.Free;
      SubLexer.Free;
    end;
  end;
end;

procedure ResolveModuleImports(TargetMod: TASTModule; const BaseDir: string; Visited: TStringList);
var
  AllTypes, AllTraits, AllImpls, AllFuncs: TFPList;
  I: Integer;
begin
  AllTypes := TFPList.Create;
  AllTraits := TFPList.Create;
  AllImpls := TFPList.Create;
  AllFuncs := TFPList.Create;
  try
    CollectModuleImports(TargetMod, BaseDir, Visited, AllTypes, AllTraits, AllImpls, AllFuncs, TargetMod.PascalImports);
    for I := AllTypes.Count - 1 downto 0 do
      TargetMod.Types.Insert(0, TASTNode(AllTypes[I]));
    for I := AllTraits.Count - 1 downto 0 do
      TargetMod.Traits.Insert(0, TASTNode(AllTraits[I]));
    for I := AllImpls.Count - 1 downto 0 do
      TargetMod.Impls.Insert(0, TASTNode(AllImpls[I]));
    for I := AllFuncs.Count - 1 downto 0 do
      TargetMod.Functions.Insert(0, TASTFunction(AllFuncs[I]));
  finally
    AllTypes.Free;
    AllTraits.Free;
    AllImpls.Free;
    AllFuncs.Free;
  end;
end;

procedure CompileFile(const SourceFile: string; TargetPascal: Boolean; CheckOnly, DumpASTOnly: Boolean; const OutputExeName: string; SilentBanner: Boolean);
var
  Source: string;
  Lexer: TAetherLexer;
  Parser: TAetherParser;
  TypeChecker: TAetherTypeChecker;
  BorrowChecker: TAetherBorrowChecker;
  ModuleNode: TASTModule;
  GenDir, IntermediateFile, FinalExe: string;
  GeneratedCode: string;
  EmitterPas: TAetherEmitterPascal;
  EmitterC: TAetherEmitterC;
  Success: Boolean;
  CompileLog: string;
  CodeFile: TStringList;
  Visited: TStringList;
  FileBase, CleanBase, CleanMod: string;
  P: Integer;
begin
  Source := LoadFileContent(SourceFile);
  Lexer := TAetherLexer.Create(Source);
  Parser := TAetherParser.Create(Lexer);
  try
    ModuleNode := Parser.ParseModule;

    // Validação Estrita 1:1 de Módulo no arquivo raiz (Fase 13)
    FileBase := ChangeFileExt(ExtractFileName(SourceFile), '');
    CleanBase := FileBase;
    P := 1;
    while (P <= Length(CleanBase)) and (CleanBase[P] in ['0'..'9', '_']) do Inc(P);
    if P <= Length(CleanBase) then
      CleanBase := Copy(CleanBase, P, Length(CleanBase));
    CleanBase := StringReplace(CleanBase, '_', '', [rfReplaceAll]);
    CleanMod := StringReplace(ModuleNode.Name, '_', '', [rfReplaceAll]);

    if not SameText(FileBase, ModuleNode.Name) and not SameText(CleanBase, CleanMod) then
      raise Exception.CreateFmt('[Erro de Modulo E0005 em %s]: Nome do modulo declarado "%s" difere do nome do arquivo "%s.aeth". Em Aether, o nome do modulo deve corresponder ao nome do arquivo.', [ExtractFileName(SourceFile), ModuleNode.Name, FileBase]);

    try
      Visited := TStringList.Create;
      try
        ResolveModuleImports(ModuleNode, ExtractFilePath(ExpandFileName(SourceFile)), Visited);
      finally
        Visited.Free;
      end;
      if DumpASTOnly then
      begin
        WriteLn(Format('--- Arvore Sintatica Abstrata (AST) de: %s ---', [SourceFile]));
        WriteLn(ModuleNode.Dump(0));
        Exit;
      end;

      if not SilentBanner then
        WriteLn(Format('[1/4] Analise Sintatica de "%s": OK', [ExtractFileName(SourceFile)]));

      // 2. Verificacao de Tipos e Semantica
      TypeChecker := TAetherTypeChecker.Create;
      try
        TypeChecker.CheckModule(ModuleNode);
        if not SilentBanner then
          WriteLn('[2/4] Verificacao de Tipos: OK (0 erros)');

        // 3. Verificacao de Posse (Borrow Checker)
        BorrowChecker := TAetherBorrowChecker.Create(TypeChecker.Symbols);
        try
          BorrowChecker.CheckModule(ModuleNode);
          if not SilentBanner then
            WriteLn('[3/4] Verificacao de Posse (Borrow Checker): OK (0 erros)');
        finally
          BorrowChecker.Free;
        end;
      finally
        TypeChecker.Free;
      end;

      if CheckOnly then
      begin
        if not SilentBanner then
          WriteLn('Modo --check-only finalizado com sucesso.');
        Exit;
      end;

      // 4. Emissao de Codigo e Geracao do Executavel
      GenDir := ExtractFilePath(ParamStr(0)) + 'generated';
      if not DirectoryExists(GenDir) then
        CreateDir(GenDir);

      if OutputExeName <> '' then
        FinalExe := OutputExeName
      else
        FinalExe := ExtractFilePath(ParamStr(0)) + ChangeFileExt(ExtractFileName(SourceFile), '.exe');

      ForceDirectories(ExtractFileDir(FinalExe));

      if TargetPascal then
      begin
        IntermediateFile := GenDir + PathDelim + ChangeFileExt(ExtractFileName(SourceFile), '.pas');
        EmitterPas := TAetherEmitterPascal.Create;
        try
          GeneratedCode := EmitterPas.Generate(ModuleNode);
        finally
          EmitterPas.Free;
        end;

        CodeFile := TStringList.Create;
        try
          CodeFile.Text := GeneratedCode;
          CodeFile.SaveToFile(IntermediateFile);
        finally
          CodeFile.Free;
        end;

        if not SilentBanner then
        begin
          WriteLn(Format('[4/4] Transpilando para Object Pascal -> "%s"', [ExtractFileName(IntermediateFile)]));
          WriteLn('      Invocando Free Pascal (fpc)...');
        end;

        CompileLog := '';
        Success := CompileWithFPC(IntermediateFile, FinalExe, CompileLog);
        if Success then
        begin
          if not SilentBanner then
          begin
            WriteLn('');
            WriteLn('SUCESSO! Executavel nativo gerado:');
            WriteLn('  --> ' + FinalExe);
          end;
        end
        else
        begin
          WriteLn(ErrOutput, 'Falha na compilacao com FPC:');
          WriteLn(ErrOutput, CompileLog);
          Halt(1);
        end;
      end
      else
      begin
        // Target C (MSYS2 GCC no Windows / GCC no Linux/macOS)
        IntermediateFile := GenDir + PathDelim + ChangeFileExt(ExtractFileName(SourceFile), '.c');
        EmitterC := TAetherEmitterC.Create;
        try
          GeneratedCode := EmitterC.Generate(ModuleNode);
        finally
          EmitterC.Free;
        end;

        CodeFile := TStringList.Create;
        try
          CodeFile.Text := GeneratedCode;
          CodeFile.SaveToFile(IntermediateFile);
        finally
          CodeFile.Free;
        end;

        if not SilentBanner then
        begin
          WriteLn(Format('[4/4] Transpilando para C99 -> "%s"', [ExtractFileName(IntermediateFile)]));
          WriteLn('      Invocando GCC...');
        end;

        CompileLog := '';
        Success := CompileWithGCC(IntermediateFile, FinalExe, CompileLog);
        if Success then
        begin
          if not SilentBanner then
          begin
            WriteLn('');
            WriteLn('SUCESSO! Executavel nativo gerado via GCC:');
            WriteLn('  --> ' + FinalExe);
          end;
        end
        else
        begin
          WriteLn(ErrOutput, 'Falha na compilacao com GCC:');
          WriteLn(ErrOutput, CompileLog);
          Halt(1);
        end;
      end;

    finally
      ModuleNode.Free;
    end;
  finally
    Parser.Free;
    Lexer.Free;
  end;
end;

procedure HandleProjectTest(const Filter: string; TargetPascal: Boolean);
var
  ProjConfig: TAetherProjectConfig;
  TestsDir, TestFile, TestExe: string;
  SearchRec: TSearchRec;
  TestFiles: TStringList;
  I, ExitCode: Integer;
  PassedCount, FailedCount: Integer;
  StartTime, ElapsedTime: TDateTime;
  ElapsedMs: Int64;
  BackendName: string;
begin
  if not LoadProjectConfig(ProjConfig) then
  begin
    WriteLn(ErrOutput, 'Erro: Nenhum projeto Aether ("aether.json") encontrado no diretorio atual.');
    Halt(1);
  end;

  TestsDir := ProjConfig.RootDir + PathDelim + 'tests';
  if not DirectoryExists(TestsDir) then
  begin
    WriteLn(Format('Aviso: Diretorio de testes "%s" nao encontrado.', [TestsDir]));
    Halt(0);
  end;

  TestFiles := TStringList.Create;
  try
    if FindFirst(TestsDir + PathDelim + '*.aeth', faAnyFile, SearchRec) = 0 then
    begin
      repeat
        if (SearchRec.Attr and faDirectory) = 0 then
        begin
          if (Filter = '') or (Pos(LowerCase(Filter), LowerCase(SearchRec.Name)) > 0) then
            TestFiles.Add(TestsDir + PathDelim + SearchRec.Name);
        end;
      until FindNext(SearchRec) <> 0;
      FindClose(SearchRec);
    end;

    if TestFiles.Count = 0 then
    begin
      if Filter <> '' then
        WriteLn(Format('Nenhum teste encontrado correspondendo ao filtro "%s".', [Filter]))
      else
        WriteLn('Nenhum arquivo de teste (*.aeth) encontrado no diretorio "tests/".');
      Exit;
    end;

    if TargetPascal then
      BackendName := 'Free Pascal'
    else
      BackendName := 'GCC C99';

    WriteLn('========================================================');
    WriteLn('  Aether Test Runner - Suite de Testes Unitarios        ');
    WriteLn('  Backend: ' + BackendName);
    WriteLn('========================================================');

    PassedCount := 0;
    FailedCount := 0;

    for I := 0 to TestFiles.Count - 1 do
    begin
      TestFile := TestFiles[I];
      TestExe := ProjConfig.RootDir + PathDelim + 'bin' + PathDelim + 'tests' + PathDelim + ChangeFileExt(ExtractFileName(TestFile), '.exe');
      ForceDirectories(ExtractFileDir(TestExe));

      Write(Format('  [TEST] %s ... ', [ExtractFileName(TestFile)]));

      try
        // 1. Compila o teste de forma silenciosa
        CompileFile(TestFile, TargetPascal, False, False, TestExe, True);

        // 2. Executa o teste medindo tempo
        StartTime := Now;
        ExitCode := ExecuteProcess(TestExe, '');
        ElapsedTime := Now - StartTime;
        ElapsedMs := Round(ElapsedTime * 86400 * 1000);

        if ExitCode = 0 then
        begin
          Inc(PassedCount);
          WriteLn(Format('PASS (%d ms)', [ElapsedMs]));
        end
        else
        begin
          Inc(FailedCount);
          WriteLn(Format('FAIL! (ExitCode: %d)', [ExitCode]));
        end;
      except
        on E: Exception do
        begin
          Inc(FailedCount);
          WriteLn('ERRO DE COMPILACAO: ' + E.Message);
        end;
      end;
    end;

    WriteLn('--------------------------------------------------------');
    WriteLn(Format('  Resultados: %d executados | %d passaram | %d falharam', [TestFiles.Count, PassedCount, FailedCount]));
    WriteLn('========================================================');

    if FailedCount > 0 then
      Halt(1)
    else
      Halt(0);
  finally
    TestFiles.Free;
  end;
end;

var
  InputFile: string;
  OutputExe: string;
  OptionDumpTokens: Boolean;
  OptionDumpAST: Boolean;
  OptionCheckOnly: Boolean;
  OptionTargetPascal: Boolean;
  OptionJSONDiag: Boolean;
  IsRunCommand: Boolean;
  ProjConfig: TAetherProjectConfig;
  I: Integer;
  Arg: string;
  PkgName, OptPath, OptGit, OptVer, FilterName: string;
begin
  InputFile := '';
  OutputExe := '';
  OptionDumpTokens := False;
  OptionDumpAST := False;
  OptionCheckOnly := False;
  OptionTargetPascal := True;
  OptionJSONDiag := False;
  IsRunCommand := False;

  // 1. Checa comandos de projeto: init / new
  if (ParamCount >= 1) and ((LowerCase(ParamStr(1)) = 'init') or (LowerCase(ParamStr(1)) = 'new')) then
  begin
    PrintBanner;
    Arg := '';
    if ParamCount >= 2 then Arg := ParamStr(2);
    try
      HandleProjectInit(Arg);
      Halt(0);
    except
      on E: Exception do
      begin
        WriteLn(ErrOutput, 'Erro ao inicializar projeto: ', E.Message);
        Halt(1);
      end;
    end;
  end;

  // 2. Checa comando de pacotes: add
  if (ParamCount >= 1) and (LowerCase(ParamStr(1)) = 'add') then
  begin
    PrintBanner;
    PkgName := '';
    OptPath := '';
    OptGit := '';
    OptVer := '';
    I := 2;
    while I <= ParamCount do
    begin
      Arg := ParamStr(I);
      if Pos('--path=', Arg) = 1 then
        OptPath := Copy(Arg, 8, Length(Arg))
      else if Pos('--git=', Arg) = 1 then
        OptGit := Copy(Arg, 7, Length(Arg))
      else if Pos('--version=', Arg) = 1 then
        OptVer := Copy(Arg, 11, Length(Arg))
      else if PkgName = '' then
        PkgName := Arg;
      Inc(I);
    end;
    try
      HandleProjectAdd(PkgName, OptPath, OptGit, OptVer);
      Halt(0);
    except
      on E: Exception do
      begin
        WriteLn(ErrOutput, 'Erro ao adicionar pacote: ', E.Message);
        Halt(1);
      end;
    end;
  end;

  // 3. Checa comando de testes: test
  if (ParamCount >= 1) and (LowerCase(ParamStr(1)) = 'test') then
  begin
    PrintBanner;
    FilterName := '';
    OptionTargetPascal := True;
    I := 2;
    while I <= ParamCount do
    begin
      Arg := ParamStr(I);
      if Arg = '--target=pascal' then OptionTargetPascal := True
      else if Arg = '--target=c' then OptionTargetPascal := False
      else if FilterName = '' then FilterName := Arg;
      Inc(I);
    end;
    try
      HandleProjectTest(FilterName, OptionTargetPascal);
    except
      on E: Exception do
      begin
        WriteLn(ErrOutput, 'Erro durante execucao dos testes: ', E.Message);
        Halt(1);
      end;
    end;
  end;

  // 2. Checa comandos de projeto: build / run
  if (ParamCount >= 1) and ((LowerCase(ParamStr(1)) = 'build') or (LowerCase(ParamStr(1)) = 'run')) then
  begin
    IsRunCommand := LowerCase(ParamStr(1)) = 'run';
    if not LoadProjectConfig(ProjConfig) then
    begin
      PrintBanner;
      WriteLn(ErrOutput, 'Erro: Nenhum arquivo "aether.json" foi encontrado no diretorio atual ou pastas superiores.');
      WriteLn(ErrOutput, 'Dica: Execute "aetherc init" para inicializar um novo projeto Aether.');
      Halt(1);
    end;

    InputFile := ProjConfig.RootDir + PathDelim + StringReplace(ProjConfig.Entry, '/', PathDelim, [rfReplaceAll]);
    OutputExe := ProjConfig.RootDir + PathDelim + StringReplace(ProjConfig.Output, '/', PathDelim, [rfReplaceAll]);
    OptionTargetPascal := ProjConfig.Backend <> 'c';

    // Permite sobrescrever flags como --target=c, -o, etc. na linha de comando
    I := 2;
    while I <= ParamCount do
    begin
      Arg := ParamStr(I);
      if Arg = '--target=pascal' then OptionTargetPascal := True
      else if Arg = '--target=c' then OptionTargetPascal := False
      else if Arg = '--check-only' then OptionCheckOnly := True
      else if (Arg = '--emit-json-diag') or (Arg = '--emit-json-diagnostics') then OptionJSONDiag := True
      else if Arg = '-o' then
      begin
        Inc(I);
        if I <= ParamCount then OutputExe := ParamStr(I);
      end;
      Inc(I);
    end;

    if not OptionJSONDiag then
      PrintBanner;

    try
      CompileFile(InputFile, OptionTargetPascal, OptionCheckOnly, False, OutputExe, OptionJSONDiag);
      if IsRunCommand and not OptionCheckOnly then
      begin
        WriteLn('');
        WriteLn('--------------------------------------------------------');
        WriteLn(' Executando: ' + ExtractFileName(OutputExe));
        WriteLn('--------------------------------------------------------');
        ExecuteProcess(OutputExe, '');
      end;
      Halt(0);
    except
      on E: EAetherBorrowError do
      begin
        if OptionJSONDiag then
          WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', E.Code, E.Message, E.Line, E.Col, E.MovedLine, E.MovedCol,
            'borrow_instead_of_move', 'Altere a chamada para "borrow" se a transferencia de posse nao for necessaria.', 'borrow'))
        else
          WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
        Halt(1);
      end;
      on E: EAetherTypeError do
      begin
        if OptionJSONDiag then
          WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', E.Code, E.Message, E.Line, E.Col))
        else
          WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
        Halt(1);
      end;
      on E: EAetherParserError do
      begin
        if OptionJSONDiag then
          WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', 'E0001', E.Message, E.Line, E.Col))
        else
          WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
        Halt(1);
      end;
      on E: EAetherLexerError do
      begin
        if OptionJSONDiag then
          WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', 'E0000', E.Message, E.Line, E.Col))
        else
          WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
        Halt(1);
      end;
      on E: Exception do
      begin
        if OptionJSONDiag then
          WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', 'E9999', E.Message, 1, 1))
        else
          WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
        Halt(1);
      end;
    end;
  end;

  I := 1;
  while I <= ParamCount do
  begin
    Arg := ParamStr(I);
    if (Arg = '-h') or (Arg = '--help') then
    begin
      PrintBanner;
      PrintUsage;
      Halt(0);
    end
    else if Arg = '--doctor' then
    begin
      PrintBanner;
      PrintDoctorReport;
      Halt(0);
    end
    else if (Arg = '--lsp') or (Arg = 'lsp') then
    begin
      RunAetherLSP;
      Halt(0);
    end
    else if Arg = '--dump-tokens' then
      OptionDumpTokens := True
    else if Arg = '--dump-ast' then
      OptionDumpAST := True
    else if Arg = '--check-only' then
      OptionCheckOnly := True
    else if Arg = '--target=pascal' then
      OptionTargetPascal := True
    else if Arg = '--target=c' then
      OptionTargetPascal := False
    else if (Arg = '--emit-json-diag') or (Arg = '--emit-json-diagnostics') then
      OptionJSONDiag := True
    else if Arg = '-o' then
    begin
      Inc(I);
      if I <= ParamCount then OutputExe := ParamStr(I);
    end
    else if (Length(Arg) > 0) and (Arg[1] <> '-') then
    begin
      InputFile := Arg;
    end;
    Inc(I);
  end;

  if not OptionJSONDiag then
    PrintBanner;

  if InputFile = '' then
  begin
    if OptionJSONDiag then
      WriteLn(GenerateJSONDiagnostic('', 'Error', 'E0001', 'Nenhum arquivo fonte .aeth especificado.', 0, 0))
    else
    begin
      WriteLn('Erro: Nenhum arquivo fonte .aeth foi especificado.');
      WriteLn('');
      PrintUsage;
    end;
    Halt(1);
  end;

  try
    if OptionDumpTokens then
      DumpTokens(InputFile);

    CompileFile(InputFile, OptionTargetPascal, OptionCheckOnly, OptionDumpAST, OutputExe, OptionJSONDiag);
  except
    on E: EAetherBorrowError do
    begin
      if OptionJSONDiag then
        WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', E.Code, E.Message, E.Line, E.Col, E.MovedLine, E.MovedCol,
          'borrow_instead_of_move', 'Altere a chamada para "borrow" se a transferencia de posse nao for necessaria.', 'borrow'))
      else
        WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
      Halt(1);
    end;
    on E: EAetherTypeError do
    begin
      if OptionJSONDiag then
        WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', E.Code, E.Message, E.Line, E.Col))
      else
        WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
      Halt(1);
    end;
    on E: EAetherParserError do
    begin
      if OptionJSONDiag then
        WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', 'E0001', E.Message, E.Line, E.Col))
      else
        WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
      Halt(1);
    end;
    on E: EAetherLexerError do
    begin
      if OptionJSONDiag then
        WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', 'E0000', E.Message, E.Line, E.Col))
      else
        WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
      Halt(1);
    end;
    on E: Exception do
    begin
      if OptionJSONDiag then
        WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', 'E9999', E.Message, 1, 1))
      else
        WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
      Halt(1);
    end;
  end;
end.
