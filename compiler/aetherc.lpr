
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
uAetherProject,
uAetherFormatter,
uAetherIncremental,
uAetherOptimizer,
uAetherBootstrap;

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
  WriteLn('Comandos de Construcao e Execucao:');
  WriteLn('  build             Compila o projeto atual baseado no manifesto aether.json');
  WriteLn('  run               Compila e executa imediatamente o binario do projeto');
  WriteLn('  test [filtro]     Executa testes unitarios (arquivos individuais ou pasta tests/)');
  WriteLn('  fmt [caminho]     Formata codigo Aether segundo as normas canonicas (--check para CI/CD)');
  WriteLn('  clean             Limpa artefatos de build (bin/ e generated/) do projeto');
  WriteLn('  bootstrap         Executa ciclo completo de auto-hospedagem (Stage 1, 2 e 3)');
  WriteLn('');
  WriteLn('Comandos de Emissao e Inspecao de Codigo (Integracao BlaiseVue):');
  WriteLn('  emit <pascal|c> [arquivo] [opcoes]');
  WriteLn('                    Emite codigo transpilado em generated/ ou diretorio customizado');
  WriteLn('    --unit          Gera no formato Unit do Free Pascal (unit/interface/implementation)');
  WriteLn('    --out-dir=<dir> Especifica o diretorio de destino para os arquivos gerados (-d)');
  WriteLn('    --stdout        Exibe o codigo diretamente no console sem salvar em disco');
  WriteLn('    --silent, -s    Modo headless silencioso para toolings e pipelines externas');
  WriteLn('    --watch, -w     Monitora alteracoes no arquivo fonte e regera automaticamente');
  WriteLn('    -o <arquivo>    Especifica o nome exato do arquivo gerado');
  WriteLn('');
  WriteLn('Comandos de Gerenciamento de Projetos e Pacotes:');
  WriteLn(
      '  new [nome | .]    Cria um novo projeto (em uma nova pasta ou no diretorio atual)'
  );
  WriteLn(
      '  pkg <subcomando>  Gerenciador de pacotes (add, remove, update, audit, list, clean)'
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
  WriteLn('Subcomandos de "aetherc pkg":');
  WriteLn('  pkg add <pacote>     Adiciona uma dependencia ao projeto (Git, Local ou Registry)');
  WriteLn('  pkg remove <pacote>  Remove uma dependencia de aether.json e limpa caches (rm)');
  WriteLn('  pkg update [pacote]  Atualiza dependencias Git e sincroniza o lockfile (upgrade)');
  WriteLn('  pkg audit            Inspeciona a integridade criptografica e seguranca TLS');
  WriteLn('  pkg list             Exibe a lista de dependencias declaradas no projeto (ls)');
  WriteLn('  pkg clean            Limpa o cache global de pacotes (~/.aether/cache)');
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
  WriteLn('  --incremental     Habilita compilacao incremental baseada em hashes SHA-256');
  WriteLn('  --force           Forca recompilacao total ignorando cache de objetos');
  WriteLn('  --release         Modo release: otimiza AST e ativa -O3, DCE e strip de simbolos');
  WriteLn('  --opt, -O         Ativa otimizador de AST (Constant Folding e Dead Code Elimination)');
  WriteLn('  --dump-tokens     Exibe a lista de tokens do Lexer');
  WriteLn('  --dump-ast        Exibe a Arvore Sintatica Abstrata (AST)');
  WriteLn(

'  --emit-json-diag  Gera relatorio de diagnostico de erros em formato JSON para IA'
  );
  WriteLn(

 '  --lsp             Inicia o servidor de linguagem (Language Server Protocol)'
  );
  WriteLn('  -o <arquivo.exe>  Especifica o nome do executavel de saida');
  WriteLn('  -I <dir>          Adiciona diretorio de busca para modulos Aether e headers C');
  WriteLn('  -Fu <dir>         Adiciona diretorio de busca para units do Free Pascal (.pas/.ppu)');
  WriteLn('  -L <dir>          Adiciona diretorio de busca de bibliotecas nativas (.a/.lib)');
  WriteLn('  -l <lib>          Linka com biblioteca C/sistema (ex: -lraylib, -lsqlite3)');
  WriteLn('  --c-source <.c>   Compila arquivo C adicional junto ao executavel final');
  WriteLn('  --shared-lib <.dll> Copia biblioteca compartilhada (.dll/.so) para a pasta do executavel');
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

Var
  GlobalIncludePaths: TStringList = nil;
  GlobalPascalUnitPaths: TStringList = nil;
  GlobalCSources: TStringList = nil;
  GlobalLibDirs: TStringList = nil;
  GlobalLibs: TStringList = nil;
  GlobalSharedLibs: TStringList = nil;

Procedure InitGlobalPaths;
Begin
  If GlobalIncludePaths = nil Then GlobalIncludePaths := TStringList.Create;
  If GlobalPascalUnitPaths = nil Then GlobalPascalUnitPaths := TStringList.Create;
  If GlobalCSources = nil Then GlobalCSources := TStringList.Create;
  If GlobalLibDirs = nil Then GlobalLibDirs := TStringList.Create;
  If GlobalLibs = nil Then GlobalLibs := TStringList.Create;
  If GlobalSharedLibs = nil Then GlobalSharedLibs := TStringList.Create;
End;

Procedure FreeGlobalPaths;
Begin
  FreeAndNil(GlobalIncludePaths);
  FreeAndNil(GlobalPascalUnitPaths);
  FreeAndNil(GlobalCSources);
  FreeAndNil(GlobalLibDirs);
  FreeAndNil(GlobalLibs);
  FreeAndNil(GlobalSharedLibs);
End;

Function ParsePathFlag(Const Arg: String; Var I: Integer): Boolean;
Var
  Val: string;
Begin
  Result := True;
  InitGlobalPaths;
  If (Arg = '-I') Then
  Begin
    Inc(I);
    If I <= ParamCount Then GlobalIncludePaths.Add(ParamStr(I));
  End
  Else If (Copy(Arg, 1, 2) = '-I') And (Length(Arg) > 2) Then
  Begin
    Val := Copy(Arg, 3, Length(Arg));
    If (Length(Val) > 0) And (Val[1] = '=') Then Val := Copy(Val, 2, Length(Val));
    GlobalIncludePaths.Add(Val);
  End
  Else If (Arg = '-Fu') Then
  Begin
    Inc(I);
    If I <= ParamCount Then GlobalPascalUnitPaths.Add(ParamStr(I));
  End
  Else If (Copy(Arg, 1, 3) = '-Fu') And (Length(Arg) > 3) Then
  Begin
    Val := Copy(Arg, 4, Length(Arg));
    If (Length(Val) > 0) And (Val[1] = '=') Then Val := Copy(Val, 2, Length(Val));
    GlobalPascalUnitPaths.Add(Val);
  End
  Else If (Arg = '-L') Then
  Begin
    Inc(I);
    If I <= ParamCount Then GlobalLibDirs.Add(ParamStr(I));
  End
  Else If (Copy(Arg, 1, 2) = '-L') And (Length(Arg) > 2) Then
  Begin
    Val := Copy(Arg, 3, Length(Arg));
    If (Length(Val) > 0) And (Val[1] = '=') Then Val := Copy(Val, 2, Length(Val));
    GlobalLibDirs.Add(Val);
  End
  Else If (Arg = '-l') Then
  Begin
    Inc(I);
    If I <= ParamCount Then GlobalLibs.Add(ParamStr(I));
  End
  Else If (Copy(Arg, 1, 2) = '-l') And (Length(Arg) > 2) Then
  Begin
    Val := Copy(Arg, 3, Length(Arg));
    If (Length(Val) > 0) And (Val[1] = '=') Then Val := Copy(Val, 2, Length(Val));
    GlobalLibs.Add(Val);
  End
  Else If (Arg = '--c-source') Then
  Begin
    Inc(I);
    If I <= ParamCount Then GlobalCSources.Add(ParamStr(I));
  End
  Else If Pos('--c-source=', Arg) = 1 Then
  Begin
    GlobalCSources.Add(Copy(Arg, 12, Length(Arg)));
  End
  Else If (Arg = '--shared-lib') Then
  Begin
    Inc(I);
    If I <= ParamCount Then GlobalSharedLibs.Add(ParamStr(I));
  End
  Else If Pos('--shared-lib=', Arg) = 1 Then
  Begin
    GlobalSharedLibs.Add(Copy(Arg, 14, Length(Arg)));
  End
  Else
    Result := False;
End;

Function FindModuleFile(Const ModName, BaseDir: String): string;

Var 
  Candidate: string;
  ExeDir, StdDir, CacheDir, DepDir: string;
  RelPath, RelPathLower, RelPathSnake: string;
  CleanRelPath, CleanRelPathLower, CleanRelPathSnake: string;
  ProjConfig: TAetherProjectConfig;
  I: Integer;
Begin
  Result := '';
  RelPath := StringReplace(ModName, '.', PathDelim, [rfReplaceAll]);
  RelPathLower := LowerCase(RelPath);
  RelPathSnake := StringReplace(CamelToSnake(ModName), '.', PathDelim, [
                  rfReplaceAll]);

  CleanRelPath := RelPath;
  CleanRelPathLower := RelPathLower;
  CleanRelPathSnake := RelPathSnake;
  if (Pos('std' + PathDelim, RelPathLower) = 1) then
  begin
    CleanRelPath := Copy(RelPath, 5, Length(RelPath) - 4);
    CleanRelPathLower := Copy(RelPathLower, 5, Length(RelPathLower) - 4);
    CleanRelPathSnake := Copy(RelPathSnake, 5, Length(RelPathSnake) - 4);
  end;

  // 1. Diretório do arquivo fonte
  Candidate := BaseDir + RelPath + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := BaseDir + RelPathLower + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := BaseDir + RelPathSnake + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);

  // 1b. Diretórios customizados de include (-I e paths.aether)
  If Assigned(GlobalIncludePaths) Then
  Begin
    For I := 0 To GlobalIncludePaths.Count - 1 Do
    Begin
      Candidate := IncludeTrailingPathDelimiter(GlobalIncludePaths[I]) + RelPath + '.aeth';
      If FileExists(Candidate) Then Exit(Candidate);
      Candidate := IncludeTrailingPathDelimiter(GlobalIncludePaths[I]) + RelPathLower + '.aeth';
      If FileExists(Candidate) Then Exit(Candidate);
      Candidate := IncludeTrailingPathDelimiter(GlobalIncludePaths[I]) + RelPathSnake + '.aeth';
      If FileExists(Candidate) Then Exit(Candidate);
    End;
  End;

  // 2. Subpasta std/ relativa ao diretório do arquivo fonte
  Candidate := BaseDir + 'std' + PathDelim + CleanRelPath + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := BaseDir + 'std' + PathDelim + CleanRelPathLower + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := BaseDir + 'std' + PathDelim + CleanRelPathSnake + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);

  // 3. Subpasta std/ relativa ao compilador (bin/../std)
  ExeDir := ExtractFilePath(ParamStr(0));
  StdDir := ExpandFileName(ExeDir + '..' + PathDelim + 'std');
  Candidate := StdDir + PathDelim + CleanRelPath + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := StdDir + PathDelim + CleanRelPathLower + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := StdDir + PathDelim + CleanRelPathSnake + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);

  // 4. Diretório de trabalho atual (cwd)
  Candidate := GetCurrentDir + PathDelim + RelPath + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := GetCurrentDir + PathDelim + RelPathLower + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := GetCurrentDir + PathDelim + RelPathSnake + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := GetCurrentDir + PathDelim + 'std' + PathDelim + CleanRelPath + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := GetCurrentDir + PathDelim + 'std' + PathDelim + CleanRelPathLower + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := GetCurrentDir + PathDelim + 'std' + PathDelim + CleanRelPathSnake + '.aeth';
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
                               TStringList; DependencyFiles: TStrings = nil);

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

      ModPath := FindModuleFile(ModName, BaseDir);
      If ModPath = '' Then
        raise Exception.CreateFmt(

'Modulo Aether "%s" nao encontrado. Verifique se o arquivo existe ou se esta em "std/".'
                                  , [ModName]);

      If Assigned(DependencyFiles) And (DependencyFiles.IndexOf(ExpandFileName(ModPath)) < 0) Then
        DependencyFiles.Add(ExpandFileName(ModPath));

      If Visited.IndexOf(LowerCase(ModPath)) >= 0 Then Continue;
      Visited.Add(LowerCase(ModName));
      Visited.Add(LowerCase(ModPath));
      Visited.Add(LowerCase(ExtractLastSegment(ModName)));

      ModSource := LoadFileContent(ModPath);
      SubLexer := TAetherLexer.Create(ModSource);
      SubParser := TAetherParser.Create(SubLexer);
      Try
        SubMod := SubParser.ParseModule;
        Try
          CollectModuleImports(SubMod, ExtractFilePath(ModPath), Visited,
          AllTypes, AllTraits, AllImpls, AllFuncs, PascalImports, DependencyFiles);

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
                               Visited: TStringList; DependencyFiles: TStrings = nil);

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
                         AllImpls, AllFuncs, TargetMod.PascalImports, DependencyFiles);
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
                      SilentBanner: Boolean; Incremental: Boolean = False;
                      ForceRebuild: Boolean = False; ReleaseMode: Boolean = False;
                      RunOptimizer: Boolean = False);

Var 
  Source: string;
  Lexer: TAetherLexer;
  Parser: TAetherParser;
  TypeChecker: TAetherTypeChecker;
  BorrowChecker: TAetherBorrowChecker;
  Optimizer: TAetherOptimizer;
  ModuleNode: TASTModule;
  GenDir, IntermediateFile, FinalExe: string;
  BaseProjDir, Dummy, TargetBackendStr, CachePath: string;
  GeneratedCode: string;
  EmitterPas: TAetherEmitterPascal;
  EmitterC: TAetherEmitterC;
  Success: Boolean;
  CompileLog: string;
  CodeFile: TStringList;
  Visited: TStringList;
  DependencyFiles: TStringList;
  FileBase, CleanBase, CleanMod: string;
  P, I: Integer;
  BuildCache: TAetherBuildCache;
  CacheUpToDate: Boolean;
  CacheItem: PFileCacheItem;
Begin
  ModuleNode := nil;
  DependencyFiles := nil;

  // Determina BaseProjDir e FinalExe antecipadamente para checagem incremental
  If Not FindProjectRoot(BaseProjDir, Dummy) Then
    BaseProjDir := GetCurrentDir;
  BaseProjDir := ExcludeTrailingPathDelimiter(BaseProjDir);

  If TargetPascal Then
  Begin
    If ReleaseMode Then TargetBackendStr := 'pascal-release' Else TargetBackendStr := 'pascal';
  End
  Else
  Begin
    If ReleaseMode Then TargetBackendStr := 'c-release' Else TargetBackendStr := 'c';
  End;

  If OutputExeName <> '' Then
    FinalExe := OutputExeName
  Else
    FinalExe := BaseProjDir + PathDelim + 'bin' + PathDelim + ChangeFileExt(ExtractFileName(
                SourceFile), '.exe');

  // Checagem antecipada de cache incremental (0 ms rebuild)
  If Incremental And (Not ForceRebuild) And (Not CheckOnly) And (Not DumpASTOnly) And FileExists(FinalExe) Then
  Begin
    CachePath := GetBuildCachePath(BaseProjDir, SourceFile, TargetBackendStr);
    If FileExists(CachePath) Then
    Begin
      BuildCache := TAetherBuildCache.Create;
      Try
        If BuildCache.LoadFromFile(CachePath) Then
        Begin
          CacheUpToDate := True;
          For I := 0 To BuildCache.Files.Count - 1 Do
          Begin
            CacheItem := PFileCacheItem(BuildCache.Files[I]);
            If (Not FileExists(CacheItem^.Path)) Or (SHA256File(CacheItem^.Path) <> CacheItem^.Hash) Then
            Begin
              CacheUpToDate := False;
              Break;
            End;
          End;

          If CacheUpToDate And FileExists(FinalExe) And (SHA256File(FinalExe) = BuildCache.OutputExeHash) Then
          Begin
            CopySharedLibraries(BaseProjDir, FinalExe, GlobalSharedLibs);
            If Not SilentBanner Then
            Begin
              WriteLn(Format('[INCREMENTAL] Nenhuma alteracao detectada em "%s" ou em suas %d dependencias.', [ExtractFileName(SourceFile), BuildCache.Files.Count - 1]));
              WriteLn(Format('[INCREMENTAL] Reutilizando executavel em cache: "%s"', [FinalExe]));
            End;
            Exit;
          End;
        End;
      Finally
        BuildCache.Free;
      End;
    End;
  End;

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

    DependencyFiles := TStringList.Create;
    DependencyFiles.Add(ExpandFileName(SourceFile));
    Visited := TStringList.Create;
    Try
      ResolveModuleImports(ModuleNode, ExtractFilePath(ExpandFileName(
                           SourceFile)), Visited, DependencyFiles);
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

// 3.5 Otimizacoes de AST (Constant Folding & Dead Code Elimination)
If RunOptimizer Or ReleaseMode Then
Begin
  Optimizer := TAetherOptimizer.Create;
  Try
    If Optimizer.OptimizeModule(ModuleNode) And (Not SilentBanner) Then
    Begin
      WriteLn(Format('      [OPTIMIZER] AST otimizada: %d constantes dobradas, %d identidades simplificadas, %d ramos mortos e %d instrucoes inalcancaveis eliminadas.',
        [Optimizer.Stats.FoldedConstants, Optimizer.Stats.SimplifiedIdentities,
         Optimizer.Stats.EliminatedDeadBranches, Optimizer.Stats.EliminatedUnreachableStmts]));
    End;
  Finally
    Optimizer.Free;
  End;
End;

// 4. Emissao de Codigo e Geracao do Executavel
If Not FindProjectRoot(BaseProjDir, Dummy) Then
  BaseProjDir := GetCurrentDir;
BaseProjDir := ExcludeTrailingPathDelimiter(BaseProjDir);

If TargetPascal Then
  GenDir := BaseProjDir + PathDelim + 'generated' + PathDelim + 'pascal'
Else
  GenDir := BaseProjDir + PathDelim + 'generated' + PathDelim + 'c';

ForceDirectories(GenDir);

If OutputExeName <> '' Then
  FinalExe := OutputExeName
Else
  FinalExe := BaseProjDir + PathDelim + 'bin' + PathDelim + ChangeFileExt(ExtractFileName(
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
    If ReleaseMode Then
      WriteLn('      Invocando Free Pascal (fpc) [Modo RELEASE: -O3 -XX -Xs]...')
    Else
      WriteLn('      Invocando Free Pascal (fpc)...');
  End;

CompileLog := '';
Success := CompileWithFPC(IntermediateFile, FinalExe, CompileLog, ReleaseMode, GlobalPascalUnitPaths, GlobalLibDirs);
If Success Then
  Begin
    CopySharedLibraries(BaseProjDir, FinalExe, GlobalSharedLibs);
    If Incremental Then
      SaveBuildCache(BaseProjDir, SourceFile, TargetBackendStr, FinalExe, DependencyFiles);
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
    If ReleaseMode Then
      WriteLn('      Invocando GCC [Modo RELEASE: -O3 -flto -s]...')
    Else
      WriteLn('      Invocando GCC...');
  End;

CompileLog := '';
Success := CompileWithGCC(IntermediateFile, FinalExe, CompileLog, ReleaseMode, GlobalIncludePaths, GlobalCSources, GlobalLibDirs, GlobalLibs);
If Success Then
  Begin
    CopySharedLibraries(BaseProjDir, FinalExe, GlobalSharedLibs);
    If Incremental Then
      SaveBuildCache(BaseProjDir, SourceFile, TargetBackendStr, FinalExe, DependencyFiles);
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
  If Assigned(DependencyFiles) Then DependencyFiles.Free;
  If Assigned(ModuleNode) Then ModuleNode.Free;
  Parser.Free;
  Lexer.Free;
End;
End;

Procedure EmitFile(Const SourceFile: String; TargetPascal: Boolean; Const CustomOutput: String;
                   Const CustomOutDir: String; AsUnit: Boolean; ToStdout: Boolean; Silent: Boolean);
Var 
  Source: string;
  Lexer: TAetherLexer;
  Parser: TAetherParser;
  TypeChecker: TAetherTypeChecker;
  BorrowChecker: TAetherBorrowChecker;
  ModuleNode: TASTModule;
  BaseProjDir, Dummy, TargetDir, FinalTargetFile: string;
  GeneratedCode: string;
  EmitterPas: TAetherEmitterPascal;
  EmitterC: TAetherEmitterC;
  CodeFile: TStringList;
  Visited: TStringList;
  FileBase, CleanBase, CleanMod, TargetExt, FinalBaseName: string;
  P: Integer;
Begin
  ModuleNode := nil;
  Source := LoadFileContent(SourceFile);
  Lexer := TAetherLexer.Create(Source);
  Parser := TAetherParser.Create(Lexer);
  Try
    ModuleNode := Parser.ParseModule;

    FileBase := ChangeFileExt(ExtractFileName(SourceFile), '');
    CleanBase := FileBase;
    P := 1;
    While (P <= Length(CleanBase)) And (CleanBase[P] In ['0'..'9', '_']) Do
      Inc(P);
    If P <= Length(CleanBase) Then
      CleanBase := Copy(CleanBase, P, Length(CleanBase));
    CleanBase := StringReplace(CleanBase, '_', '', [rfReplaceAll]);
    CleanMod := StringReplace(ModuleNode.Name, '_', '', [rfReplaceAll]);

    If Not SameText(FileBase, ModuleNode.Name) And Not SameText(CleanBase, CleanMod) Then
      raise Exception.CreateFmt(
        '[Erro de Modulo E0005 em %s]: Nome do modulo declarado "%s" difere do nome do arquivo "%s.aeth". Em Aether, o nome do modulo deve corresponder ao nome do arquivo.',
        [ExtractFileName(SourceFile), ModuleNode.Name, FileBase]);

    Visited := TStringList.Create;
    Try
      ResolveModuleImports(ModuleNode, ExtractFilePath(ExpandFileName(SourceFile)), Visited);
    Finally
      Visited.Free;
    End;

    TypeChecker := TAetherTypeChecker.Create;
    Try
      TypeChecker.CheckModule(ModuleNode);
      BorrowChecker := TAetherBorrowChecker.Create(TypeChecker.Symbols);
      Try
        BorrowChecker.CheckModule(ModuleNode);
      Finally
        BorrowChecker.Free;
      End;
    Finally
      TypeChecker.Free;
    End;

    If TargetPascal Then
    Begin
      EmitterPas := TAetherEmitterPascal.Create;
      Try
        GeneratedCode := EmitterPas.Generate(ModuleNode, AsUnit);
      Finally
        EmitterPas.Free;
      End;
    End
    Else
    Begin
      EmitterC := TAetherEmitterC.Create;
      Try
        GeneratedCode := EmitterC.Generate(ModuleNode);
      Finally
        EmitterC.Free;
      End;
    End;

    If ToStdout Then
    Begin
      Write(GeneratedCode);
      Exit;
    End;

    If TargetPascal Then
    Begin
      If AsUnit Then
        FinalBaseName := ModuleNode.Name
      Else
        FinalBaseName := ExtractFileName(SourceFile);
      TargetExt := '.pas';
    End
    Else
    Begin
      FinalBaseName := ExtractFileName(SourceFile);
      TargetExt := '.c';
    End;

    If CustomOutput <> '' Then
      FinalTargetFile := CustomOutput
    Else If CustomOutDir <> '' Then
    Begin
      TargetDir := ExcludeTrailingPathDelimiter(CustomOutDir);
      ForceDirectories(TargetDir);
      FinalTargetFile := TargetDir + PathDelim + ChangeFileExt(FinalBaseName, TargetExt);
    End
    Else
    Begin
      If Not FindProjectRoot(BaseProjDir, Dummy) Then
        BaseProjDir := GetCurrentDir;
      BaseProjDir := ExcludeTrailingPathDelimiter(BaseProjDir);

      If TargetPascal Then
        TargetDir := BaseProjDir + PathDelim + 'generated' + PathDelim + 'pascal'
      Else
        TargetDir := BaseProjDir + PathDelim + 'generated' + PathDelim + 'c';

      ForceDirectories(TargetDir);
      FinalTargetFile := TargetDir + PathDelim + ChangeFileExt(FinalBaseName, TargetExt);
    End;

    ForceDirectories(ExtractFileDir(FinalTargetFile));
    CodeFile := TStringList.Create;
    Try
      CodeFile.Text := GeneratedCode;
      CodeFile.SaveToFile(FinalTargetFile);
    Finally
      CodeFile.Free;
    End;

    If Not Silent Then
    Begin
      WriteLn(Format('[1/3] Analise Sintatica de "%s": OK', [ExtractFileName(SourceFile)]));
      WriteLn('[2/3] Verificacao de Tipos e Posse: OK');
      If TargetPascal Then
      Begin
        If AsUnit Then
          WriteLn('[3/3] Unit Object Pascal (BlaiseVue) emitida com sucesso:')
        Else
          WriteLn('[3/3] Codigo Object Pascal emitido com sucesso:');
      End
      Else
        WriteLn('[3/3] Codigo C99 emitido com sucesso:');
      WriteLn('  --> ' + FinalTargetFile);
    End;
  Finally
    ModuleNode.Free;
    Parser.Free;
    Lexer.Free;
  End;
End;

Procedure WatchEmitFile(Const SourceFile: String; TargetPascal: Boolean; Const CustomOutput: String;
                        Const CustomOutDir: String; AsUnit: Boolean; Silent: Boolean);
Var
  LastAge, NewAge: LongInt;
  TimeStr: string;
Begin
  WriteLn('========================================================');
  WriteLn('  Aether File Watcher (Hot-Reload / BlaiseVue Ready)    ');
  WriteLn('========================================================');
  WriteLn(Format('Observando alteracoes em: "%s"', [SourceFile]));
  WriteLn('Pressione Ctrl+C para interromper.');
  WriteLn('');

  // 1. Execucao inicial
  Try
    EmitFile(SourceFile, TargetPascal, CustomOutput, CustomOutDir, AsUnit, False, Silent);
  Except
    on E: Exception Do
      WriteLn(ErrOutput, 'Erro na compilacao inicial: ', E.Message);
  End;

  LastAge := FileAge(SourceFile);
  While True Do
  Begin
    Sleep(250);
    NewAge := FileAge(SourceFile);
    If (NewAge <> -1) And (NewAge <> LastAge) Then
    Begin
      LastAge := NewAge;
      DateTimeToString(TimeStr, 'hh:nn:ss', Now);
      WriteLn(Format('[%s] [WATCH] Alteracao detectada em "%s"...', [TimeStr, ExtractFileName(SourceFile)]));
      Try
        EmitFile(SourceFile, TargetPascal, CustomOutput, CustomOutDir, AsUnit, False, Silent);
        WriteLn('      [OK] Arquivo regenerado com sucesso!');
      Except
        on E: Exception Do
          WriteLn(ErrOutput, Format('      [ERRO] %s', [E.Message]));
      End;
      WriteLn('');
    End;
  End;
End;

Procedure HandleProjectTest(Const Filter: String; TargetPascal: Boolean);
Var 
  ProjConfig: TAetherProjectConfig;
  TestsDir, TestFile, TestExe, BaseDir: string;
  SearchRec: TSearchRec;
  TestFiles: TStringList;
  I, ExitCode: Integer;
  PassedCount, FailedCount: Integer;
  StartTime, ElapsedTime: TDateTime;
  ElapsedMs: Int64;
  BackendName: string;
  HasConfig: Boolean;
Begin
  HasConfig := LoadProjectConfig(ProjConfig);
  If HasConfig Then
  Begin
    RestoreProjectDependencies(ProjConfig);
    BaseDir := ProjConfig.RootDir;
  End
  Else
    BaseDir := GetCurrentDir;

  TestFiles := TStringList.Create;
  Try
    // 1. Se o filtro for um arquivo que existe diretamente
    If FileExists(Filter) Then
    Begin
      TestFiles.Add(ExpandFileName(Filter));
    End
    Else If DirectoryExists(Filter) Then
    Begin
      TestsDir := ExpandFileName(Filter);
      If FindFirst(TestsDir + PathDelim + '*.aeth', faAnyFile, SearchRec) = 0 Then
      Begin
        Repeat
          If (SearchRec.Attr And faDirectory) = 0 Then
            TestFiles.Add(TestsDir + PathDelim + SearchRec.Name);
        Until FindNext(SearchRec) <> 0;
        FindClose(SearchRec);
      End;
    End
    Else
    Begin
      TestsDir := BaseDir + PathDelim + 'tests';
      If Not DirectoryExists(TestsDir) Then
        TestsDir := BaseDir;

      If FindFirst(TestsDir + PathDelim + '*.aeth', faAnyFile, SearchRec) = 0 Then
      Begin
        Repeat
          If (SearchRec.Attr And faDirectory) = 0 Then
          Begin
            If (Filter = '') Or (Pos(LowerCase(Filter), LowerCase(SearchRec.Name)) > 0) Then
            Begin
              If (Filter <> '') Or (Pos('test', LowerCase(SearchRec.Name)) > 0) Or (TestsDir <> BaseDir) Then
                TestFiles.Add(TestsDir + PathDelim + SearchRec.Name);
            End;
          End;
        Until FindNext(SearchRec) <> 0;
        FindClose(SearchRec);
      End;
    End;

    If TestFiles.Count = 0 Then
    Begin
      If Filter <> '' Then
        WriteLn(Format('Nenhum teste encontrado correspondendo ao filtro "%s".', [Filter]))
      Else
        WriteLn('Nenhum arquivo de teste (*.aeth) encontrado no diretorio "tests/".');
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
      TestExe := BaseDir + PathDelim + 'bin' + PathDelim + 'tests'
                 + PathDelim + ChangeFileExt(ExtractFileName(TestFile), '.exe');
      ForceDirectories(ExtractFileDir(TestExe));

      Write(Format('  [TEST] %s ... ', [ExtractFileName(TestFile)]));

      Try
        CompileFile(TestFile, TargetPascal, False, False, TestExe, True);

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

Procedure HandleFmtCommand;
Var
  I: Integer;
  Arg, TargetPath: string;
  CheckOnly: Boolean;
  TotalFiles, FormattedFiles: Integer;
  IsClean: Boolean;
Begin
  TargetPath := '.';
  CheckOnly := False;
  I := 2;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);
    If Arg = '--check' Then
      CheckOnly := True
    Else If (Length(Arg) > 0) And (Arg[1] <> '-') Then
      TargetPath := Arg;
    Inc(I);
  End;

  WriteLn('========================================================');
  WriteLn('  Aether Code Formatter (aetherc fmt)                   ');
  If CheckOnly Then
    WriteLn('  Modo: Verificacao (--check)')
  Else
    WriteLn('  Modo: Formatacao automatica');
  WriteLn('========================================================');

  TotalFiles := 0;
  FormattedFiles := 0;

  If FileExists(TargetPath) Then
  Begin
    TotalFiles := 1;
    IsClean := TAetherFormatter.FormatFile(TargetPath, CheckOnly);
    If Not IsClean Then
    Begin
      FormattedFiles := 1;
      If CheckOnly Then
        WriteLn(Format('  [DESFORMATADO] %s precisa ser formatado.', [TargetPath]))
      Else
        WriteLn(Format('  [FORMATADO] %s', [TargetPath]));
    End
    Else
      WriteLn(Format('  [OK] %s ja esta devidamente formatado.', [TargetPath]));
  End
  Else If DirectoryExists(TargetPath) Then
  Begin
    TAetherFormatter.FormatDirectory(TargetPath, TotalFiles, FormattedFiles, CheckOnly);
  End
  Else
  Begin
    WriteLn(ErrOutput, Format('Erro: Arquivo ou diretorio "%s" nao encontrado.', [TargetPath]));
    Halt(1);
  End;

  WriteLn('--------------------------------------------------------');
  If CheckOnly Then
  Begin
    If FormattedFiles > 0 Then
    Begin
      WriteLn(Format('  FALHA: %d de %d arquivos precisam de formatacao.', [FormattedFiles, TotalFiles]));
      WriteLn('  Execute "aetherc fmt" para formata-los automaticamente.');
      WriteLn('========================================================');
      Halt(1);
    End
    Else
    Begin
      WriteLn(Format('  SUCESSO: Todos os %d arquivos estao devidamente formatados!', [TotalFiles]));
      WriteLn('========================================================');
      Halt(0);
    End;
  End
  Else
  Begin
    WriteLn(Format('  Concluido: %d arquivos verificados | %d formatados.', [TotalFiles, FormattedFiles]));
    WriteLn('========================================================');
    Halt(0);
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
  OptionIncremental: Boolean;
  OptionForce: Boolean;
  OptionRelease: Boolean;
  OptionOptimize: Boolean;
  IsRunCommand: Boolean;
  ProjConfig: TAetherProjectConfig;
  I, J: Integer;
  Arg: string;
  PkgName, OptPath, OptGit, OptVer, FilterName, SubCmd: string;
  EmitTargetPascal, EmitToStdout, HasTargetSpecified, EmitAsUnit, EmitSilent, EmitWatch: Boolean;
  EmitSource, EmitOut, EmitOutDir: string;
Begin
  InitGlobalPaths;
  InputFile := '';
  OutputExe := '';
  OptionDumpTokens := False;
  OptionDumpAST := False;
  OptionCheckOnly := False;
  OptionTargetPascal := True;
  OptionJSONDiag := False;
  OptionIncremental := False;
  OptionForce := False;
  OptionRelease := False;
  OptionOptimize := False;
  IsRunCommand := False;

  // Checa comando de formatacao: fmt [caminho] [--check]
  If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'fmt') Then
    Begin
      PrintBanner;
      Try
        HandleFmtCommand;
        Halt(0);
      Except
        on E: Exception Do
          Begin
            WriteLn(ErrOutput, 'Erro ao formatar: ', E.Message);
            Halt(1);
          End;
      End;
    End;

  // Checa comando de limpeza: clean
  If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'clean') Then
    Begin
      PrintBanner;
      Try
        HandleProjectClean();
        Halt(0);
      Except
        on E: Exception Do
          Begin
            WriteLn(ErrOutput, 'Erro ao limpar projeto: ', E.Message);
            Halt(1);
          End;
      End;
    End;

  // Checa comando de auto-hospedagem: bootstrap
  If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'bootstrap') Then
    Begin
      PrintBanner;
      Try
        HandleBootstrapCommand();
        Halt(0);
      Except
        on E: Exception Do
          Begin
            WriteLn(ErrOutput, 'Erro durante o processo de bootstrap: ', E.Message);
            Halt(1);
          End;
      End;
    End;

  // Checa comando de emissao: emit <pascal|c> [arquivo] [opcoes]
  If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'emit') Then
    Begin
      EmitTargetPascal := True;
      EmitSource := '';
      EmitOut := '';
      EmitOutDir := '';
      EmitToStdout := False;
      EmitAsUnit := False;
      EmitSilent := False;
      EmitWatch := False;
      HasTargetSpecified := False;

      I := 2;
      While I <= ParamCount Do
        Begin
          Arg := ParamStr(I);
          If LowerCase(Arg) = 'pascal' Then
            Begin
              EmitTargetPascal := True;
              HasTargetSpecified := True;
            End
          Else If LowerCase(Arg) = 'c' Then
            Begin
              EmitTargetPascal := False;
              HasTargetSpecified := True;
            End
          Else If Arg = '--target=pascal' Then
            Begin
              EmitTargetPascal := True;
              HasTargetSpecified := True;
            End
          Else If Arg = '--target=c' Then
            Begin
              EmitTargetPascal := False;
              HasTargetSpecified := True;
            End
          Else If Arg = '--unit' Then
            EmitAsUnit := True
          Else If (Arg = '--silent') Or (Arg = '-s') Then
            EmitSilent := True
          Else If (Arg = '--watch') Or (Arg = '-w') Then
            EmitWatch := True
          Else If Pos('--out-dir=', Arg) = 1 Then
            EmitOutDir := Copy(Arg, 11, Length(Arg))
          Else If Pos('--outdir=', Arg) = 1 Then
            EmitOutDir := Copy(Arg, 10, Length(Arg))
          Else If (Arg = '-d') And (I + 1 <= ParamCount) Then
            Begin
              Inc(I);
              EmitOutDir := ParamStr(I);
            End
          Else If Arg = '--stdout' Then
            EmitToStdout := True
          Else If Arg = '-o' Then
            Begin
              Inc(I);
              If I <= ParamCount Then EmitOut := ParamStr(I);
            End
          Else If Pos('-o', Arg) = 1 Then
            EmitOut := Copy(Arg, 3, Length(Arg))
          Else If (Length(Arg) > 0) And (Arg[1] <> '-') Then
            Begin
              If EmitSource = '' Then EmitSource := Arg;
            End;
          Inc(I);
        End;

      If EmitSource = '' Then
        Begin
          If LoadProjectConfig(ProjConfig) Then
            Begin
              EmitSource := ProjConfig.RootDir + PathDelim + StringReplace(ProjConfig.Entry, '/', PathDelim, [rfReplaceAll]);
              If Not HasTargetSpecified Then
                EmitTargetPascal := ProjConfig.Backend <> 'c';
              RestoreProjectDependencies(ProjConfig);
            End
          Else
            Begin
              WriteLn(ErrOutput, 'Erro: Nenhum arquivo fonte especificado e nenhum "aether.json" encontrado.');
              WriteLn(ErrOutput, 'Uso: aetherc emit <pascal|c> [arquivo.aeth] [--unit] [--out-dir=dir] [--stdout]');
              Halt(1);
            End;
        End;

      If (Not EmitToStdout) And (Not EmitSilent) And (Not EmitWatch) Then
        PrintBanner;

      If EmitWatch Then
        Begin
          WatchEmitFile(EmitSource, EmitTargetPascal, EmitOut, EmitOutDir, EmitAsUnit, EmitSilent);
          Halt(0);
        End;

      Try
        EmitFile(EmitSource, EmitTargetPascal, EmitOut, EmitOutDir, EmitAsUnit, EmitToStdout, EmitSilent);
        Halt(0);
      Except
        on E: Exception Do
          Begin
            WriteLn(ErrOutput, 'Erro na geracao de codigo: ', E.Message);
            Halt(1);
          End;
      End;
    End;

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

// Checa comando unificado de gerenciamento de pacotes: pkg
If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'pkg') Then
  Begin
    PrintBanner;
    SubCmd := '';
    If ParamCount >= 2 Then SubCmd := LowerCase(ParamStr(2));

    If SubCmd = 'add' Then
    Begin
      PkgName := '';
      OptPath := '';
      OptGit := '';
      OptVer := '';
      I := 3;
      While I <= ParamCount Do
      Begin
        Arg := ParamStr(I);
        If Pos('--path=', Arg) = 1 Then OptPath := Copy(Arg, 8, Length(Arg))
        Else If Pos('--git=', Arg) = 1 Then OptGit := Copy(Arg, 7, Length(Arg))
        Else If Pos('--version=', Arg) = 1 Then OptVer := Copy(Arg, 11, Length(Arg))
        Else If Pos('--branch=', Arg) = 1 Then OptVer := Copy(Arg, 10, Length(Arg))
        Else If Pos('--tag=', Arg) = 1 Then OptVer := Copy(Arg, 7, Length(Arg))
        Else If PkgName = '' Then PkgName := Arg
        Else If (OptVer = '') And (Length(Arg) > 0) And (Arg[1] <> '-') Then OptVer := Arg;
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
    End
    Else If (SubCmd = 'remove') Or (SubCmd = 'rm') Then
    Begin
      PkgName := '';
      If ParamCount >= 3 Then PkgName := ParamStr(3);
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
    End
    Else If (SubCmd = 'update') Or (SubCmd = 'upgrade') Then
    Begin
      PkgName := '';
      If ParamCount >= 3 Then PkgName := ParamStr(3);
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
    End
    Else If SubCmd = 'audit' Then
    Begin
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
    End
    Else If (SubCmd = 'list') Or (SubCmd = 'ls') Then
    Begin
      Try
        HandleProjectList();
        Halt(0);
      Except
        on E: Exception Do
        Begin
          WriteLn(ErrOutput, 'Erro ao listar dependencias: ', E.Message);
          Halt(1);
        End;
      End;
    End
    Else If SubCmd = 'clean' Then
    Begin
      Try
        HandleProjectCleanCache();
        Halt(0);
      Except
        on E: Exception Do
        Begin
          WriteLn(ErrOutput, 'Erro ao limpar cache: ', E.Message);
          Halt(1);
        End;
      End;
    End
    Else
    Begin
      WriteLn('Uso: aetherc pkg <subcomando> [opcoes]');
      WriteLn('');
      WriteLn('Subcomandos Disponiveis:');
      WriteLn('  add <pacote>     Adiciona uma dependencia ao projeto (Git, Local ou Registry)');
      WriteLn('  remove <pacote>  Remove uma dependencia de aether.json e limpa caches (rm)');
      WriteLn('  update [pacote]  Atualiza dependencias Git e sincroniza o lockfile (upgrade)');
      WriteLn('  audit            Inspeciona a integridade criptografica e seguranca TLS');
      WriteLn('  list             Exibe a lista de todas as dependencias do projeto (ls)');
      WriteLn('  clean            Limpa o cache global de pacotes (~/.aether/cache)');
      Halt(0);
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
               PkgName := Arg
        Else If (OptVer = '') And (Length(Arg) > 0) And (Arg[1] <> '-') Then
               OptVer := Arg;
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
    OptionIncremental := True; // Habilitado por padrão para projetos aether.json
    RestoreProjectDependencies(ProjConfig);

    // Carrega caminhos declarados na secao 'paths' do aether.json
    For J := 0 To High(ProjConfig.PathsAether) Do
      If ProjConfig.PathsAether[J] <> '' Then
        GlobalIncludePaths.Add(ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.PathsAether[J]));
    For J := 0 To High(ProjConfig.PathsCIncludes) Do
      If ProjConfig.PathsCIncludes[J] <> '' Then
        GlobalIncludePaths.Add(ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.PathsCIncludes[J]));
    For J := 0 To High(ProjConfig.PathsCSources) Do
      If ProjConfig.PathsCSources[J] <> '' Then
        GlobalCSources.Add(ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.PathsCSources[J]));
    For J := 0 To High(ProjConfig.PathsPascalUnits) Do
      If ProjConfig.PathsPascalUnits[J] <> '' Then
        GlobalPascalUnitPaths.Add(ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.PathsPascalUnits[J]));
    For J := 0 To High(ProjConfig.PathsLibDirs) Do
      If ProjConfig.PathsLibDirs[J] <> '' Then
        GlobalLibDirs.Add(ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.PathsLibDirs[J]));
    For J := 0 To High(ProjConfig.PathsLibs) Do
      If ProjConfig.PathsLibs[J] <> '' Then
        GlobalLibs.Add(ProjConfig.PathsLibs[J]);
    For J := 0 To High(ProjConfig.PathsSharedLibs) Do
      If ProjConfig.PathsSharedLibs[J] <> '' Then
        GlobalSharedLibs.Add(ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.PathsSharedLibs[J]));

    // Permite sobrescrever flags como --target=c, -o, -I, -Fu, etc. na linha de comando
    I := 2;
    While I <= ParamCount Do
      Begin
        Arg := ParamStr(I);
        If ParsePathFlag(Arg, I) Then
          // Consumido pela flag de path
        Else If Arg = '--target=pascal' Then OptionTargetPascal := True
        Else If Arg = '--target=c' Then OptionTargetPascal := False
        Else If Arg = '--check-only' Then OptionCheckOnly := True
        Else If Arg = '--incremental' Then OptionIncremental := True
        Else If Arg = '--no-incremental' Then OptionIncremental := False
        Else If Arg = '--force' Then OptionForce := True
        Else If Arg = '--release' Then
        Begin
          OptionRelease := True;
          OptionOptimize := True;
        End
        Else If (Arg = '--opt') Or (Arg = '-O') Then OptionOptimize := True
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
                  OutputExe, OptionJSONDiag, OptionIncremental, OptionForce,
                  OptionRelease, OptionOptimize);
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
    If ParsePathFlag(Arg, I) Then
      // Consumido pela flag de path (-I, -Fu, -L, -l, --c-source, --shared-lib)
    Else If (Arg = '-h') Or (Arg = '--help') Then
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
    Else If Arg = '--incremental' Then
           OptionIncremental := True
    Else If Arg = '--no-incremental' Then
           OptionIncremental := False
    Else If Arg = '--force' Then
           OptionForce := True
    Else If Arg = '--release' Then
           Begin
             OptionRelease := True;
             OptionOptimize := True;
           End
    Else If (Arg = '--opt') Or (Arg = '-O') Then
           OptionOptimize := True
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
              OutputExe, OptionJSONDiag, OptionIncremental, OptionForce,
              OptionRelease, OptionOptimize);
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
