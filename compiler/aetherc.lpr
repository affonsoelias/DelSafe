
Program aetherc;

{$mode objfpc}{$H+}
{$codepage utf8}

Uses 
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

Procedure PrintBanner;
Begin
  WriteLn('========================================================');
  WriteLn('  AetherLang Compiler (aetherc) - Versao 0.5.0 (Alpha)  ');
  WriteLn('  Pascal Structure + Pascal Safety + AI-Native Design   ');
  WriteLn('========================================================');
End;

Procedure PrintUsage;
Begin
  WriteLn('Uso: aetherc <comando | arquivo.aeth> [opcoes]');
  WriteLn('');
  WriteLn('Comandos de Gerenciamento de Projetos e Pacotes:');
  WriteLn(

'  init [nome]       Inicializa um novo projeto Aether com manifesto aether.json'
  );
  WriteLn(

      '  new <nome>        Cria uma nova pasta com o projeto Aether estruturado'
  );
  WriteLn(

         '  add <pacote>      Adiciona uma dependencia ao manifesto aether.json'
  );
  WriteLn(

         '  remove <pacote>   Remove uma dependencia e limpa caches locais (rm)'
  );
  WriteLn(

         '  update [pacote]   Atualiza pacotes Git e sincroniza o lockfile (upgrade)'
  );
  WriteLn(

         '  audit             Inspeciona a integridade criptografica e seguranca TLS'
  );
  WriteLn('  test [filtro]     Executa testes unitarios da pasta tests/');
  WriteLn(

  '  build             Compila o projeto atual baseado no manifesto aether.json'
  );
  WriteLn(

      '  run               Compila e executa imediatamente o binario do projeto'
  );
  WriteLn(

 '  lsp               Inicia o servidor de linguagem (Language Server Protocol)'
  );
  WriteLn('');
  WriteLn('Opcoes Principais:');
  WriteLn(

       '  --doctor          Verifica e diagnostica o ambiente (FPC e MSYS2/GCC)'
  );
  WriteLn(

       '  --target=pascal   Compila gerando Object Pascal e invoca FPC (Padrao)'
  );
  WriteLn(

       '  --target=c        Compila gerando C99 e invoca GCC (MSYS2 no Windows)'
  );
  WriteLn(

  '  --check-only      Executa apenas analise sintatica, tipos e borrow checker'
  );
  WriteLn('  --dump-tokens     Exibe a lista de tokens do Lexer');
  WriteLn('  --dump-ast        Exibe a Arvore Sintatica Abstrata (AST)');
  WriteLn(

'  --emit-json-diag  Gera relatorio de diagnostico de erros em formato JSON para IA'
  );
  WriteLn(

 '  --lsp             Inicia o servidor de linguagem (Language Server Protocol)'
  );
  WriteLn('  -o <arquivo.exe>  Especifica o nome do executavel de saida');
  WriteLn('  -h, --help        Exibe esta mensagem de ajuda');
End;

Function LoadFileContent(Const FileName: String): string;

Var 
  FileStream: TFileStream;
  StringStream: TStringStream;
Begin
  If Not FileExists(FileName) Then
    raise Exception.CreateFmt('Arquivo nao encontrado: "%s"', [FileName]);

  FileStream := TFileStream.Create(FileName, fmOpenRead Or fmShareDenyWrite);
  StringStream := TStringStream.Create('');
  Try
    StringStream.CopyFrom(FileStream, FileStream.Size);
    Result := StringStream.DataString;
  Finally
    StringStream.Free;
    FileStream.Free;
End;
End;

Procedure DumpTokens(Const SourceFile: String);

Var 
  Source: string;
  Lexer: TAetherLexer;
  Tok: TToken;
  Count: Integer;
Begin
  Source := LoadFileContent(SourceFile);
  Lexer := TAetherLexer.Create(Source);
  Try
    WriteLn(Format('--- Analise Lexica (Tokens) de: %s ---', [SourceFile]));
    Count := 0;
    Repeat
      Tok := Lexer.NextToken;
      Inc(Count);
      WriteLn(Format('[Linha %3d, Col %3d] %-16s : "%s"',
              [Tok.Line, Tok.Col, TokenKindToString(Tok.Kind), Tok.Value]));
    Until Tok.Kind = tokEOF;
    WriteLn(Format('Total de tokens analisados: %d', [Count]));
  Finally
    Lexer.Free;
End;
End;

Function ExtractLastSegment(Const S: String): string;

Var 
  I: Integer;
Begin
  For I := Length(S) Downto 1 Do
    If S[I] = '.' Then
      Exit(Copy(S, I + 1, Length(S)));
  Result := S;
End;

Function CamelToSnake(Const S: String): string;

Var 
  I: Integer;
Begin
  Result := '';
  For I := 1 To Length(S) Do
    Begin
      If (S[I] In ['A'..'Z']) And (I > 1) And (S[I - 1] <> '.') And (S[I - 1] <>
         '_') And (S[I - 1] <> '/') And (S[I - 1] <> '\') Then
        Result := Result + '_' + LowerCase(S[I])
      Else
        Result := Result + LowerCase(S[I]);
    End;
End;

Function FindModuleFile(Const ModName, BaseDir: String): string;

Var 
  Candidate: string;
  ExeDir, StdDir, CacheDir, DepDir: string;
  RelPath, RelPathLower, RelPathSnake: string;
  ProjConfig: TAetherProjectConfig;
  I: Integer;
Begin
  Result := '';
  RelPath := StringReplace(ModName, '.', PathDelim, [rfReplaceAll]);
  RelPathLower := LowerCase(RelPath);
  RelPathSnake := StringReplace(CamelToSnake(ModName), '.', PathDelim, [
                  rfReplaceAll]);

  // 1. Diretório do arquivo fonte
  Candidate := BaseDir + RelPath + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := BaseDir + RelPathLower + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := BaseDir + RelPathSnake + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);

  // 2. Subpasta std/ relativa ao diretório do arquivo fonte
  Candidate := BaseDir + 'std' + PathDelim + RelPath + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := BaseDir + 'std' + PathDelim + RelPathLower + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := BaseDir + 'std' + PathDelim + RelPathSnake + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);

  // 3. Subpasta std/ relativa ao compilador (bin/../std)
  ExeDir := ExtractFilePath(ParamStr(0));
  StdDir := ExpandFileName(ExeDir + '..' + PathDelim + 'std');
  Candidate := StdDir + PathDelim + RelPath + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := StdDir + PathDelim + RelPathLower + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := StdDir + PathDelim + RelPathSnake + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);

  // 4. Diretório de trabalho atual (cwd)
  Candidate := GetCurrentDir + PathDelim + RelPath + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := GetCurrentDir + PathDelim + RelPathLower + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := GetCurrentDir + PathDelim + RelPathSnake + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := GetCurrentDir + PathDelim + 'std' + PathDelim + RelPath + '.aeth'
  ;
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := GetCurrentDir + PathDelim + 'std' + PathDelim + RelPathLower +
               '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := GetCurrentDir + PathDelim + 'std' + PathDelim + RelPathSnake +
               '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);



// 5. Dependências do projeto atual (aether.json) e Cache Global (~/.aether/cache)
  If LoadProjectConfig(ProjConfig) Then
    Begin
      For I := 0 To High(ProjConfig.Dependencies) Do
        Begin
          If ProjConfig.Dependencies[I].Path <> '' Then
            DepDir := ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig
                      .Dependencies[I].Path)
          Else
            DepDir := ExpandFileName(ProjConfig.RootDir + PathDelim + '.aether'
                      + PathDelim + 'deps' + PathDelim + ProjConfig.Dependencies
                      [I].Name);

          Candidate := DepDir + PathDelim + RelPath + '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);
          Candidate := DepDir + PathDelim + 'src' + PathDelim + RelPath +
                       '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);
          Candidate := DepDir + PathDelim + RelPathLower + '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);
          Candidate := DepDir + PathDelim + 'src' + PathDelim + RelPathLower +
                       '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);
          Candidate := DepDir + PathDelim + RelPathSnake + '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);
          Candidate := DepDir + PathDelim + 'src' + PathDelim + RelPathSnake +
                       '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);

          // Cache global (~/.aether/cache/<pkg>)
          CacheDir := GetAetherCacheDir + PathDelim + ProjConfig.Dependencies[I]
                      .Name;
          Candidate := CacheDir + PathDelim + RelPath + '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);
          Candidate := CacheDir + PathDelim + 'src' + PathDelim + RelPath +
                       '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);
          Candidate := CacheDir + PathDelim + RelPathLower + '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);
          Candidate := CacheDir + PathDelim + 'src' + PathDelim + RelPathLower +
                       '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);
          Candidate := CacheDir + PathDelim + RelPathSnake + '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);
          Candidate := CacheDir + PathDelim + 'src' + PathDelim + RelPathSnake +
                       '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);
        End;
    End;
End;

Procedure CollectModuleImports(TargetMod: TASTModule; Const BaseDir: String;
                               Visited: TStringList; AllTypes, AllTraits,
                               AllImpls, AllFuncs: TFPList; PascalImports:
                               TStringList);

Var 
  I, J: Integer;
  ModName, ModPath, ModSource: string;
  SubLexer: TAetherLexer;
  SubParser: TAetherParser;
  SubMod: TASTModule;
  ExpectedName, LastSegment: string;
Begin
  For I := 0 To TargetMod.Imports.Count - 1 Do
    Begin
      ModName := TargetMod.Imports[I];
      If Visited.IndexOf(LowerCase(ModName)) >= 0 Then Continue;
      Visited.Add(LowerCase(ModName));

      ModPath := FindModuleFile(ModName, BaseDir);
      If ModPath = '' Then
        raise Exception.CreateFmt(

'Modulo Aether "%s" nao encontrado. Verifique se o arquivo existe ou se esta em "std/".'
                                  , [ModName]);

      ModSource := LoadFileContent(ModPath);
      SubLexer := TAetherLexer.Create(ModSource);
      SubParser := TAetherParser.Create(SubLexer);
      Try
        SubMod := SubParser.ParseModule;
        Try
          CollectModuleImports(SubMod, ExtractFilePath(ModPath), Visited,
          AllTypes, AllTraits, AllImpls, AllFuncs, PascalImports);

          // Validação Estrita 1:1 de Módulos Importados (Fase 13)
          ExpectedName := ModName;
          LastSegment := ExtractLastSegment(ExpectedName);
          If Not SameText(SubMod.Name, ExpectedName) And Not SameText(SubMod.
             Name, LastSegment) Then
            raise Exception.CreateFmt(

'[Erro de Modulo E0005 em %s]: Nome do modulo declarado "%s" difere do esperado "%s". Em Aether, o nome do modulo deve corresponder ao nome do arquivo.'
                                      , [ExtractFileName(ModPath), SubMod.Name,
            ExpectedName]);

          For J := 0 To SubMod.PascalImports.Count - 1 Do
            If PascalImports.IndexOf(SubMod.PascalImports[J]) < 0 Then
              PascalImports.Add(SubMod.PascalImports[J]);

          While SubMod.Types.Count > 0 Do
            AllTypes.Add(SubMod.Types.Extract(SubMod.Types[0]));

          While SubMod.Traits.Count > 0 Do
            AllTraits.Add(SubMod.Traits.Extract(SubMod.Traits[0]));

          While SubMod.Impls.Count > 0 Do
            AllImpls.Add(SubMod.Impls.Extract(SubMod.Impls[0]));

          While SubMod.Functions.Count > 0 Do
            AllFuncs.Add(SubMod.Functions.Extract(SubMod.Functions[0]));
        Finally
          SubMod.Free;
    End;
Finally
  SubParser.Free;
  SubLexer.Free;
End;
End;
End;

Procedure ResolveModuleImports(TargetMod: TASTModule; Const BaseDir: String;
                               Visited: TStringList);

Var 
  AllTypes, AllTraits, AllImpls, AllFuncs: TFPList;
  I: Integer;
Begin
  AllTypes := TFPList.Create;
  AllTraits := TFPList.Create;
  AllImpls := TFPList.Create;
  AllFuncs := TFPList.Create;
  Try
    CollectModuleImports(TargetMod, BaseDir, Visited, AllTypes, AllTraits,
                         AllImpls, AllFuncs, TargetMod.PascalImports);
    For I := AllTypes.Count - 1 Downto 0 Do
      TargetMod.Types.Insert(0, TASTNode(AllTypes[I]));
    For I := AllTraits.Count - 1 Downto 0 Do
      TargetMod.Traits.Insert(0, TASTNode(AllTraits[I]));
    For I := AllImpls.Count - 1 Downto 0 Do
      TargetMod.Impls.Insert(0, TASTNode(AllImpls[I]));
    For I := AllFuncs.Count - 1 Downto 0 Do
      TargetMod.Functions.Insert(0, TASTFunction(AllFuncs[I]));
  Finally
    AllTypes.Free;
    AllTraits.Free;
    AllImpls.Free;
    AllFuncs.Free;
End;
End;

Procedure CompileFile(Const SourceFile: String; TargetPascal: Boolean; CheckOnly
                      , DumpASTOnly: Boolean; Const OutputExeName: String;
                      SilentBanner: Boolean);

Var 
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
Begin
  Source := LoadFileContent(SourceFile);
  Lexer := TAetherLexer.Create(Source);
  Parser := TAetherParser.Create(Lexer);
  Try
    ModuleNode := Parser.ParseModule;

    // Validação Estrita 1:1 de Módulo no arquivo raiz (Fase 13)
    FileBase := ChangeFileExt(ExtractFileName(SourceFile), '');
    CleanBase := FileBase;
    P := 1;
    While (P <= Length(CleanBase)) And (CleanBase[P] In ['0'..'9', '_']) Do
      Inc(P);
    If P <= Length(CleanBase) Then
      CleanBase := Copy(CleanBase, P, Length(CleanBase));
    CleanBase := StringReplace(CleanBase, '_', '', [rfReplaceAll]);
    CleanMod := StringReplace(ModuleNode.Name, '_', '', [rfReplaceAll]);

    If Not SameText(FileBase, ModuleNode.Name) And Not SameText(CleanBase,
       CleanMod) Then
      raise Exception.CreateFmt(

'[Erro de Modulo E0005 em %s]: Nome do modulo declarado "%s" difere do nome do arquivo "%s.aeth". Em Aether, o nome do modulo deve corresponder ao nome do arquivo.'
                                , [ExtractFileName(SourceFile), ModuleNode.Name,
      FileBase]);

    Try
      Visited := TStringList.Create;
      Try
        ResolveModuleImports(ModuleNode, ExtractFilePath(ExpandFileName(
                             SourceFile)), Visited);
      Finally
        Visited.Free;
End;
If DumpASTOnly Then
  Begin
    WriteLn(Format('--- Arvore Sintatica Abstrata (AST) de: %s ---', [SourceFile
            ]));
    WriteLn(ModuleNode.Dump(0));
    Exit;
  End;

If Not SilentBanner Then
  WriteLn(Format('[1/4] Analise Sintatica de "%s": OK', [ExtractFileName(
          SourceFile)]));

// 2. Verificacao de Tipos e Semantica
TypeChecker := TAetherTypeChecker.Create;
Try
  TypeChecker.CheckModule(ModuleNode);
  If Not SilentBanner Then
    WriteLn('[2/4] Verificacao de Tipos: OK (0 erros)');

  // 3. Verificacao de Posse (Borrow Checker)
  BorrowChecker := TAetherBorrowChecker.Create(TypeChecker.Symbols);
  Try
    BorrowChecker.CheckModule(ModuleNode);
    If Not SilentBanner Then
      WriteLn('[3/4] Verificacao de Posse (Borrow Checker): OK (0 erros)');
  Finally
    BorrowChecker.Free;
End;
Finally
  TypeChecker.Free;
End;

If CheckOnly Then
  Begin
    If Not SilentBanner Then
      WriteLn('Modo --check-only finalizado com sucesso.');
    Exit;
  End;

// 4. Emissao de Codigo e Geracao do Executavel
GenDir := ExtractFilePath(ParamStr(0)) + 'generated';
If Not DirectoryExists(GenDir) Then
  CreateDir(GenDir);

If OutputExeName <> '' Then
  FinalExe := OutputExeName
Else
  FinalExe := ExtractFilePath(ParamStr(0)) + ChangeFileExt(ExtractFileName(
              SourceFile), '.exe');

ForceDirectories(ExtractFileDir(FinalExe));

If TargetPascal Then
  Begin
    IntermediateFile := GenDir + PathDelim + ChangeFileExt(ExtractFileName(
                        SourceFile), '.pas');
    EmitterPas := TAetherEmitterPascal.Create;
    Try
      GeneratedCode := EmitterPas.Generate(ModuleNode);
    Finally
      EmitterPas.Free;
  End;

CodeFile := TStringList.Create;
Try
  CodeFile.Text := GeneratedCode;
  CodeFile.SaveToFile(IntermediateFile);
Finally
  CodeFile.Free;
End;

If Not SilentBanner Then
  Begin
    WriteLn(Format('[4/4] Transpilando para Object Pascal -> "%s"', [
            ExtractFileName(IntermediateFile)]));
    WriteLn('      Invocando Free Pascal (fpc)...');
  End;

CompileLog := '';
Success := CompileWithFPC(IntermediateFile, FinalExe, CompileLog);
If Success Then
  Begin
    If Not SilentBanner Then
      Begin
        WriteLn('');
        WriteLn('SUCESSO! Executavel nativo gerado:');
        WriteLn('  --> ' + FinalExe);
      End;
  End
Else
  Begin
    WriteLn(ErrOutput, 'Falha na compilacao com FPC:');
    WriteLn(ErrOutput, CompileLog);
    Halt(1);
  End;
End
Else
  Begin
    // Target C (MSYS2 GCC no Windows / GCC no Linux/macOS)
    IntermediateFile := GenDir + PathDelim + ChangeFileExt(ExtractFileName(
                        SourceFile), '.c');
    EmitterC := TAetherEmitterC.Create;
    Try
      GeneratedCode := EmitterC.Generate(ModuleNode);
    Finally
      EmitterC.Free;
  End;

CodeFile := TStringList.Create;
Try
  CodeFile.Text := GeneratedCode;
  CodeFile.SaveToFile(IntermediateFile);
Finally
  CodeFile.Free;
End;

If Not SilentBanner Then
  Begin
    WriteLn(Format('[4/4] Transpilando para C99 -> "%s"', [ExtractFileName(
            IntermediateFile)]));
    WriteLn('      Invocando GCC...');
  End;

CompileLog := '';
Success := CompileWithGCC(IntermediateFile, FinalExe, CompileLog);
If Success Then
  Begin
    If Not SilentBanner Then
      Begin
        WriteLn('');
        WriteLn('SUCESSO! Executavel nativo gerado via GCC:');
        WriteLn('  --> ' + FinalExe);
      End;
  End
Else
  Begin
    WriteLn(ErrOutput, 'Falha na compilacao com GCC:');
    WriteLn(ErrOutput, CompileLog);
    Halt(1);
  End;
End;

Finally
  ModuleNode.Free;
End;
Finally
  Parser.Free;
  Lexer.Free;
End;
End;

Procedure HandleProjectTest(Const Filter: String; TargetPascal: Boolean);

Var 
  ProjConfig: TAetherProjectConfig;
  TestsDir, TestFile, TestExe: string;
  SearchRec: TSearchRec;
  TestFiles: TStringList;
  I, ExitCode: Integer;
  PassedCount, FailedCount: Integer;
  StartTime, ElapsedTime: TDateTime;
  ElapsedMs: Int64;
  BackendName: string;
Begin
  If Not LoadProjectConfig(ProjConfig) Then
    Begin
      WriteLn(ErrOutput,

    'Erro: Nenhum projeto Aether ("aether.json") encontrado no diretorio atual.'
      );
      Halt(1);
    End;

  RestoreProjectDependencies(ProjConfig);

  TestsDir := ProjConfig.RootDir + PathDelim + 'tests';
  If Not DirectoryExists(TestsDir) Then
    Begin
      WriteLn(Format('Aviso: Diretorio de testes "%s" nao encontrado.', [
              TestsDir]));
      Halt(0);
    End;

  TestFiles := TStringList.Create;
  Try
    If FindFirst(TestsDir + PathDelim + '*.aeth', faAnyFile, SearchRec) = 0 Then
      Begin
        Repeat
          If (SearchRec.Attr And faDirectory) = 0 Then
            Begin
              If (Filter = '') Or (Pos(LowerCase(Filter), LowerCase(SearchRec.
                 Name)) > 0) Then
                TestFiles.Add(TestsDir + PathDelim + SearchRec.Name);
            End;
        Until FindNext(SearchRec) <> 0;
        FindClose(SearchRec);
      End;

    If TestFiles.Count = 0 Then
      Begin
        If Filter <> '' Then
          WriteLn(Format(
                  'Nenhum teste encontrado correspondendo ao filtro "%s".', [
                  Filter]))
        Else
          WriteLn(

            'Nenhum arquivo de teste (*.aeth) encontrado no diretorio "tests/".'
          );
        Exit;
      End;

    If TargetPascal Then
      BackendName := 'Free Pascal'
    Else
      BackendName := 'GCC C99';

    WriteLn('========================================================');
    WriteLn('  Aether Test Runner - Suite de Testes Unitarios        ');
    WriteLn('  Backend: ' + BackendName);
    WriteLn('========================================================');

    PassedCount := 0;
    FailedCount := 0;

    For I := 0 To TestFiles.Count - 1 Do
      Begin
        TestFile := TestFiles[I];
        TestExe := ProjConfig.RootDir + PathDelim + 'bin' + PathDelim + 'tests'
                   + PathDelim + ChangeFileExt(ExtractFileName(TestFile), '.exe'
                   );
        ForceDirectories(ExtractFileDir(TestExe));

        Write(Format('  [TEST] %s ... ', [ExtractFileName(TestFile)]));

        Try
          // 1. Compila o teste de forma silenciosa
          CompileFile(TestFile, TargetPascal, False, False, TestExe, True);

          // 2. Executa o teste medindo tempo
          StartTime := Now;
          ExitCode := ExecuteProcess(TestExe, '');
          ElapsedTime := Now - StartTime;
          ElapsedMs := Round(ElapsedTime * 86400 * 1000);

          If ExitCode = 0 Then
            Begin
              Inc(PassedCount);
              WriteLn(Format('PASS (%d ms)', [ElapsedMs]));
            End
          Else
            Begin
              Inc(FailedCount);
              WriteLn(Format('FAIL! (ExitCode: %d)', [ExitCode]));
            End;
        Except
          on E: Exception Do
                Begin
                  Inc(FailedCount);
                  WriteLn('ERRO DE COMPILACAO: ' + E.Message);
                End;
      End;
End;

WriteLn('--------------------------------------------------------');
WriteLn(Format('  Resultados: %d executados | %d passaram | %d falharam', [
        TestFiles.Count, PassedCount, FailedCount]));
WriteLn('========================================================');

If FailedCount > 0 Then
  Halt(1)
Else
  Halt(0);
Finally
  TestFiles.Free;
End;
End;

Var 
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
Begin
  InputFile := '';
  OutputExe := '';
  OptionDumpTokens := False;
  OptionDumpAST := False;
  OptionCheckOnly := False;
  OptionTargetPascal := True;
  OptionJSONDiag := False;
  IsRunCommand := False;

  // 1. Checa comandos de projeto: init / new
  If (ParamCount >= 1) And ((LowerCase(ParamStr(1)) = 'init') Or (LowerCase(
     ParamStr(1)) = 'new')) Then
    Begin
      PrintBanner;
      Arg := '';
      If ParamCount >= 2 Then Arg := ParamStr(2);
      Try
        HandleProjectInit(Arg);
        Halt(0);
      Except
        on E: Exception Do
              Begin
                WriteLn(ErrOutput, 'Erro ao inicializar projeto: ', E.Message);
                Halt(1);
              End;
    End;
End;

// 2. Checa comando de pacotes: add
If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'add') Then
  Begin
    PrintBanner;
    PkgName := '';
    OptPath := '';
    OptGit := '';
    OptVer := '';
    I := 2;
    While I <= ParamCount Do
      Begin
        Arg := ParamStr(I);
        If Pos('--path=', Arg) = 1 Then
          OptPath := Copy(Arg, 8, Length(Arg))
        Else If Pos('--git=', Arg) = 1 Then
               OptGit := Copy(Arg, 7, Length(Arg))
        Else If Pos('--version=', Arg) = 1 Then
               OptVer := Copy(Arg, 11, Length(Arg))
        Else If Pos('--branch=', Arg) = 1 Then
               OptVer := Copy(Arg, 10, Length(Arg))
        Else If Pos('--tag=', Arg) = 1 Then
               OptVer := Copy(Arg, 7, Length(Arg))
        Else If PkgName = '' Then
               PkgName := Arg;
        Inc(I);
      End;
    Try
      HandleProjectAdd(PkgName, OptPath, OptGit, OptVer);
      Halt(0);
    Except
      on E: Exception Do
            Begin
              WriteLn(ErrOutput, 'Erro ao adicionar pacote: ', E.Message);
              Halt(1);
            End;
  End;
End;

// Checa comando de pacotes: remove / rm
If (ParamCount >= 1) And ((LowerCase(ParamStr(1)) = 'remove') Or (LowerCase(ParamStr(1)) = 'rm')) Then
  Begin
    PrintBanner;
    PkgName := '';
    If ParamCount >= 2 Then PkgName := ParamStr(2);
    Try
      HandleProjectRemove(PkgName);
      Halt(0);
    Except
      on E: Exception Do
            Begin
              WriteLn(ErrOutput, 'Erro ao remover pacote: ', E.Message);
              Halt(1);
            End;
  End;
End;

// Checa comando de pacotes: update / upgrade
If (ParamCount >= 1) And ((LowerCase(ParamStr(1)) = 'update') Or (LowerCase(ParamStr(1)) = 'upgrade')) Then
  Begin
    PrintBanner;
    PkgName := '';
    If ParamCount >= 2 Then PkgName := ParamStr(2);
    Try
      HandleProjectUpdate(PkgName);
      Halt(0);
    Except
      on E: Exception Do
            Begin
              WriteLn(ErrOutput, 'Erro ao atualizar pacotes: ', E.Message);
              Halt(1);
            End;
  End;
End;

// Checa comando de seguranca: audit
If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'audit') Then
  Begin
    PrintBanner;
    Try
      HandleProjectAudit();
      Halt(0);
    Except
      on E: Exception Do
            Begin
              WriteLn(ErrOutput, 'Erro durante auditoria de seguranca: ', E.Message);
              Halt(1);
            End;
  End;
End;

// 3. Checa comando de testes: test
If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'test') Then
  Begin
    PrintBanner;
    FilterName := '';
    OptionTargetPascal := True;
    I := 2;
    While I <= ParamCount Do
      Begin
        Arg := ParamStr(I);
        If Arg = '--target=pascal' Then OptionTargetPascal := True
        Else If Arg = '--target=c' Then OptionTargetPascal := False
        Else If FilterName = '' Then FilterName := Arg;
        Inc(I);
      End;
    Try
      HandleProjectTest(FilterName, OptionTargetPascal);
    Except
      on E: Exception Do
            Begin
              WriteLn(ErrOutput, 'Erro durante execucao dos testes: ', E.Message
              );
              Halt(1);
            End;
  End;
End;

// 2. Checa comandos de projeto: build / run
If (ParamCount >= 1) And ((LowerCase(ParamStr(1)) = 'build') Or (LowerCase(
   ParamStr(1)) = 'run')) Then
  Begin
    IsRunCommand := LowerCase(ParamStr(1)) = 'run';
    If Not LoadProjectConfig(ProjConfig) Then
      Begin
        PrintBanner;
        WriteLn(ErrOutput,

'Erro: Nenhum arquivo "aether.json" foi encontrado no diretorio atual ou pastas superiores.'
        );
        WriteLn(ErrOutput,

         'Dica: Execute "aetherc init" para inicializar um novo projeto Aether.'
        );
        Halt(1);
      End;

    InputFile := ProjConfig.RootDir + PathDelim + StringReplace(ProjConfig.Entry
                 , '/', PathDelim, [rfReplaceAll]);
    OutputExe := ProjConfig.RootDir + PathDelim + StringReplace(ProjConfig.
                 Output, '/', PathDelim, [rfReplaceAll]);
    OptionTargetPascal := ProjConfig.Backend <> 'c';
    RestoreProjectDependencies(ProjConfig);

    // Permite sobrescrever flags como --target=c, -o, etc. na linha de comando
    I := 2;
    While I <= ParamCount Do
      Begin
        Arg := ParamStr(I);
        If Arg = '--target=pascal' Then OptionTargetPascal := True
        Else If Arg = '--target=c' Then OptionTargetPascal := False
        Else If Arg = '--check-only' Then OptionCheckOnly := True
        Else If (Arg = '--emit-json-diag') Or (Arg = '--emit-json-diagnostics')
               Then OptionJSONDiag := True
        Else If Arg = '-o' Then
               Begin
                 Inc(I);
                 If I <= ParamCount Then OutputExe := ParamStr(I);
               End;
        Inc(I);
      End;

    If Not OptionJSONDiag Then
      PrintBanner;

    Try
      CompileFile(InputFile, OptionTargetPascal, OptionCheckOnly, False,
                  OutputExe, OptionJSONDiag);
      If IsRunCommand And Not OptionCheckOnly Then
        Begin
          WriteLn('');
          WriteLn('--------------------------------------------------------');
          WriteLn(' Executando: ' + ExtractFileName(OutputExe));
          WriteLn('--------------------------------------------------------');
          ExecuteProcess(OutputExe, '');
        End;
      Halt(0);
    Except
      on E: EAetherBorrowError Do
            Begin
              If OptionJSONDiag Then
                WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', E.Code, E.
                        Message, E.Line, E.Col, E.MovedLine, E.MovedCol,
                        'borrow_instead_of_move',

'Altere a chamada para "borrow" se a transferencia de posse nao for necessaria.'
                        , 'borrow'))
              Else
                WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
              Halt(1);
            End;
      on E: EAetherTypeError Do
            Begin
              If OptionJSONDiag Then
                WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', E.Code, E.
                        Message, E.Line, E.Col))
              Else
                WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
              Halt(1);
            End;
      on E: EAetherParserError Do
            Begin
              If OptionJSONDiag Then
                WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', 'E0001', E.
                        Message, E.Line, E.Col))
              Else
                WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
              Halt(1);
            End;
      on E: EAetherLexerError Do
            Begin
              If OptionJSONDiag Then
                WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', 'E0000', E.
                        Message, E.Line, E.Col))
              Else
                WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
              Halt(1);
            End;
      on E: Exception Do
            Begin
              If OptionJSONDiag Then
                WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', 'E9999', E.
                        Message, 1, 1))
              Else
                WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
              Halt(1);
            End;
  End;
End;

I := 1;
While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);
    If (Arg = '-h') Or (Arg = '--help') Then
      Begin
        PrintBanner;
        PrintUsage;
        Halt(0);
      End
    Else If Arg = '--doctor' Then
           Begin
             PrintBanner;
             PrintDoctorReport;
             Halt(0);
           End
    Else If (Arg = '--lsp') Or (Arg = 'lsp') Then
           Begin
             RunAetherLSP;
             Halt(0);
           End
    Else If Arg = '--dump-tokens' Then
           OptionDumpTokens := True
    Else If Arg = '--dump-ast' Then
           OptionDumpAST := True
    Else If Arg = '--check-only' Then
           OptionCheckOnly := True
    Else If Arg = '--target=pascal' Then
           OptionTargetPascal := True
    Else If Arg = '--target=c' Then
           OptionTargetPascal := False
    Else If (Arg = '--emit-json-diag') Or (Arg = '--emit-json-diagnostics') Then
           OptionJSONDiag := True
    Else If Arg = '-o' Then
           Begin
             Inc(I);
             If I <= ParamCount Then OutputExe := ParamStr(I);
           End
    Else If (Length(Arg) > 0) And (Arg[1] <> '-') Then
           Begin
             InputFile := Arg;
           End;
    Inc(I);
  End;

If Not OptionJSONDiag Then
  PrintBanner;

If InputFile = '' Then
  Begin
    If OptionJSONDiag Then
      WriteLn(GenerateJSONDiagnostic('', 'Error', 'E0001',
              'Nenhum arquivo fonte .aeth especificado.', 0, 0))
    Else
      Begin
        WriteLn('Erro: Nenhum arquivo fonte .aeth foi especificado.');
        WriteLn('');
        PrintUsage;
      End;
    Halt(1);
  End;

Try
  If OptionDumpTokens Then
    DumpTokens(InputFile);

  CompileFile(InputFile, OptionTargetPascal, OptionCheckOnly, OptionDumpAST,
              OutputExe, OptionJSONDiag);
Except
  on E: EAetherBorrowError Do
        Begin
          If OptionJSONDiag Then
            WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', E.Code, E.Message
                    , E.Line, E.Col, E.MovedLine, E.MovedCol,
                    'borrow_instead_of_move',

'Altere a chamada para "borrow" se a transferencia de posse nao for necessaria.'
                    , 'borrow'))
          Else
            WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
          Halt(1);
        End;
  on E: EAetherTypeError Do
        Begin
          If OptionJSONDiag Then
            WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', E.Code, E.Message
                    , E.Line, E.Col))
          Else
            WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
          Halt(1);
        End;
  on E: EAetherParserError Do
        Begin
          If OptionJSONDiag Then
            WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', 'E0001', E.
                    Message, E.Line, E.Col))
          Else
            WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
          Halt(1);
        End;
  on E: EAetherLexerError Do
        Begin
          If OptionJSONDiag Then
            WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', 'E0000', E.
                    Message, E.Line, E.Col))
          Else
            WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
          Halt(1);
        End;
  on E: Exception Do
        Begin
          If OptionJSONDiag Then
            WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', 'E9999', E.
                    Message, 1, 1))
          Else
            WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
          Halt(1);
        End;
End;
End.
