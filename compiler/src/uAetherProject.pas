unit uAetherProject;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  SysUtils, Classes, fpjson, jsonparser, Process;

type
  TAetherDependency = record
    Name: string;
    Path: string;
    GitUrl: string;
    Version: string;
  end;

  TAetherProjectConfig = record
    Name: string;
    Version: string;
    Description: string;
    Backend: string;
    Entry: string;
    Output: string;
    RootDir: string;
    ConfigFile: string;
    Dependencies: array of TAetherDependency;
  end;

function FindProjectRoot(out RootDir, ConfigFile: string): Boolean;
function LoadProjectConfig(out Config: TAetherProjectConfig): Boolean;
function GetAetherCacheDir: string;
function ExtractPackageNameFromGitUrl(const Url: string): string;
function SyncGitPackage(const PkgName, GitUrl, Version: string; out CacheDir: string; Visited: TStringList = nil): Boolean;
procedure RestoreProjectDependencies(const Config: TAetherProjectConfig);
procedure HandleProjectInit(const ProjectName: string);
procedure HandleProjectAdd(const PkgName: string; const OptPath, OptGit, OptVer: string);

implementation

function RunGitProcess(const Params: string; var OutputLog: string): Integer;
var
  Proc: TProcess;
  Buffer: array[0..2047] of Byte;
  BytesRead: LongInt;
  StringStream: TStringStream;
begin
  Result := -1;
  OutputLog := '';
  Proc := TProcess.Create(nil);
  StringStream := TStringStream.Create('');
  try
    Proc.Executable := 'git';
    Proc.CommandLine := 'git ' + Params;
    Proc.Options := [poUsePipes, poStderrToOutPut];
    Proc.ShowWindow := swoNone;
    try
      Proc.Execute;
      while Proc.Running or (Proc.Output.NumBytesAvailable > 0) do
      begin
        if Proc.Output.NumBytesAvailable > 0 then
        begin
          BytesRead := Proc.Output.Read(Buffer[0], SizeOf(Buffer));
          if BytesRead > 0 then
            StringStream.WriteBuffer(Buffer[0], BytesRead);
        end
        else
          Sleep(10);
      end;
      Result := Proc.ExitStatus;
      OutputLog := Trim(StringStream.DataString);
    except
      on E: Exception do
      begin
        OutputLog := E.Message;
        Result := -1;
      end;
    end;
  finally
    StringStream.Free;
    Proc.Free;
  end;
end;

function ExtractPackageNameFromGitUrl(const Url: string): string;
var
  CleanUrl: string;
  LastSlash: Integer;
begin
  CleanUrl := Url;
  while (Length(CleanUrl) > 0) and (CleanUrl[Length(CleanUrl)] in ['/', '\']) do
    Delete(CleanUrl, Length(CleanUrl), 1);
  if (Length(CleanUrl) > 4) and SameText(Copy(CleanUrl, Length(CleanUrl) - 3, 4), '.git') then
    Delete(CleanUrl, Length(CleanUrl) - 3, 4);
  LastSlash := LastDelimiter('/:\', CleanUrl);
  if LastSlash > 0 then
    Result := Copy(CleanUrl, LastSlash + 1, Length(CleanUrl))
  else
    Result := CleanUrl;
end;

procedure CopyDirectoryTree(const SrcDir, DstDir: string);
var
  SR: TSearchRec;
  SrcItem, DstItem: string;
  SrcStream, DstStream: TFileStream;
begin
  if not DirectoryExists(DstDir) then
    ForceDirectories(DstDir);

  if FindFirst(SrcDir + PathDelim + '*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') or (SR.Name = '.git') then
          Continue;

        SrcItem := SrcDir + PathDelim + SR.Name;
        DstItem := DstDir + PathDelim + SR.Name;

        if (SR.Attr and faDirectory) <> 0 then
          CopyDirectoryTree(SrcItem, DstItem)
        else
        begin
          try
            SrcStream := TFileStream.Create(SrcItem, fmOpenRead or fmShareDenyWrite);
            try
              DstStream := TFileStream.Create(DstItem, fmCreate);
              try
                DstStream.CopyFrom(SrcStream, SrcStream.Size);
              finally
                DstStream.Free;
              end;
            finally
              SrcStream.Free;
            end;
          except
            // Ignora arquivos bloqueados
          end;
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
end;

function SyncGitPackage(const PkgName, GitUrl, Version: string; out CacheDir: string; Visited: TStringList = nil): Boolean;
var
  OwnsVisited: Boolean;
  CmdArgs, OutputLog: string;
  ExitCode: Integer;
  SubConfigFile: string;
  SubConfig: TAetherProjectConfig;
  I: Integer;
  SubCacheDir: string;
begin
  Result := False;
  CacheDir := GetAetherCacheDir + PathDelim + PkgName;

  OwnsVisited := False;
  if not Assigned(Visited) then
  begin
    Visited := TStringList.Create;
    OwnsVisited := True;
  end;

  try
    if Visited.IndexOf(PkgName) >= 0 then
      Exit(True); // Previne dependencia circular
    Visited.Add(PkgName);

    WriteLn(Format('-> Sincronizando pacote Git "%s"...', [PkgName]));

    // Se o repositorio ja existe no cache, tenta atualizar via checkout/pull
    if DirectoryExists(CacheDir + PathDelim + '.git') then
    begin
      WriteLn(Format('   Cache existente em "%s"', [CacheDir]));
      if (Version <> '') and (Version <> '*') and (Version <> 'main') then
        CmdArgs := Format('-C "%s" checkout %s', [CacheDir, Version])
      else
        CmdArgs := Format('-C "%s" pull --quiet', [CacheDir]);

      ExitCode := RunGitProcess(CmdArgs, OutputLog);
      if ExitCode <> 0 then
        WriteLn(Format('   Aviso: Nao foi possivel atualizar o repositorio local via Git (%s). Usando versao em cache.', [OutputLog]));
      Result := True;
    end
    else
    begin
      // Clona o repositorio pela primeira vez
      if not DirectoryExists(CacheDir) then
        ForceDirectories(CacheDir);

      if (Version <> '') and (Version <> '*') and (Version <> 'main') then
        CmdArgs := Format('clone --depth 1 --branch %s %s "%s"', [Version, GitUrl, CacheDir])
      else
        CmdArgs := Format('clone --depth 1 %s "%s"', [GitUrl, CacheDir]);

      WriteLn(Format('   Clonando de "%s"...', [GitUrl]));
      ExitCode := RunGitProcess(CmdArgs, OutputLog);
      if ExitCode = 0 then
      begin
        WriteLn(Format('   [OK] Pacote "%s" clonado com sucesso no cache.', [PkgName]));
        Result := True;
      end
      else
      begin
        // Tenta clone sem --branch se falhar
        CmdArgs := Format('clone --depth 1 %s "%s"', [GitUrl, CacheDir]);
        ExitCode := RunGitProcess(CmdArgs, OutputLog);
        if ExitCode = 0 then
        begin
          WriteLn(Format('   [OK] Pacote "%s" clonado (branch padrao).', [PkgName]));
          Result := True;
        end
        else
        begin
          WriteLn(Format('   [Erro Git]: %s', [OutputLog]));
          Exit(False);
        end;
      end;
    end;

    // Resolucao de dependencias aninhadas (transitiva)
    SubConfigFile := CacheDir + PathDelim + 'aether.json';
    if FileExists(SubConfigFile) then
    begin
      WriteLn(Format('   Verificando dependencias aninhadas em "%s/aether.json"...', [PkgName]));
      try
        // Carrega o manifesto do subpacote
        if LoadProjectConfig(SubConfig) then
        begin
          for I := 0 to High(SubConfig.Dependencies) do
          begin
            if SubConfig.Dependencies[I].GitUrl <> '' then
            begin
              SyncGitPackage(SubConfig.Dependencies[I].Name,
                             SubConfig.Dependencies[I].GitUrl,
                             SubConfig.Dependencies[I].Version,
                             SubCacheDir, Visited);
            end;
          end;
        end;
      except
        // Ignora erros em aether.json de dependencias filhas
      end;
    end;

  finally
    if OwnsVisited then
      Visited.Free;
  end;
end;

procedure RestoreProjectDependencies(const Config: TAetherProjectConfig);
var
  I: Integer;
  CacheDir, LocalDepDir: string;
begin
  if Length(Config.Dependencies) = 0 then Exit;

  WriteLn('Restaurando dependencias do projeto ("aether.json")...');
  for I := 0 to High(Config.Dependencies) do
  begin
    if Config.Dependencies[I].GitUrl <> '' then
    begin
      if SyncGitPackage(Config.Dependencies[I].Name,
                        Config.Dependencies[I].GitUrl,
                        Config.Dependencies[I].Version,
                        CacheDir) then
      begin
        // Copia do cache para .aether/deps/ do projeto atual
        LocalDepDir := Config.RootDir + PathDelim + '.aether' + PathDelim + 'deps' + PathDelim + Config.Dependencies[I].Name;
        if not DirectoryExists(LocalDepDir) then
        begin
          WriteLn(Format('   Instalando "%s" em ".aether/deps/%s"...', [Config.Dependencies[I].Name, Config.Dependencies[I].Name]));
          CopyDirectoryTree(CacheDir, LocalDepDir);
        end;
      end;
    end;
  end;
  WriteLn('Todas as dependencias estao sincronizadas e prontas.');
end;

function GetAetherCacheDir: string;
var
  HomeDir: string;
begin
  {$IFDEF MSWINDOWS}
  HomeDir := SysUtils.GetEnvironmentVariable('USERPROFILE');
  if HomeDir = '' then HomeDir := SysUtils.GetEnvironmentVariable('APPDATA');
  {$ELSE}
  HomeDir := SysUtils.GetEnvironmentVariable('HOME');
  {$ENDIF}
  if HomeDir = '' then HomeDir := GetCurrentDir;
  Result := HomeDir + PathDelim + '.aether' + PathDelim + 'cache';
  if not DirectoryExists(Result) then
    ForceDirectories(Result);
end;

function FindProjectRoot(out RootDir, ConfigFile: string): Boolean;
var
  CurDir, ParentDir: string;
begin
  Result := False;
  RootDir := '';
  ConfigFile := '';

  CurDir := ExpandFileName(GetCurrentDir);
  while CurDir <> '' do
  begin
    if FileExists(CurDir + PathDelim + 'aether.json') then
    begin
      RootDir := CurDir;
      ConfigFile := CurDir + PathDelim + 'aether.json';
      Exit(True);
    end;

    ParentDir := ExtractFileDir(CurDir);
    if (ParentDir = '') or (ParentDir = CurDir) then
      Break;
    CurDir := ParentDir;
  end;
end;

function LoadProjectConfig(out Config: TAetherProjectConfig): Boolean;
var
  RootDir, ConfigFile, JsonStr: string;
  FileStream: TFileStream;
  StringStream: TStringStream;
  JSON, DepsData, ItemData: TJSONData;
  Obj, DepsObj, ItemObj: TJSONObject;
  I: Integer;
begin
  Result := False;
  SetLength(Config.Dependencies, 0);
  if not FindProjectRoot(RootDir, ConfigFile) then
    Exit(False);

  Config.RootDir := RootDir;
  Config.ConfigFile := ConfigFile;

  FileStream := TFileStream.Create(ConfigFile, fmOpenRead or fmShareDenyWrite);
  StringStream := TStringStream.Create('');
  try
    StringStream.CopyFrom(FileStream, FileStream.Size);
    JsonStr := StringStream.DataString;
  finally
    StringStream.Free;
    FileStream.Free;
  end;

  try
    JSON := GetJSON(JsonStr);
    try
      if JSON is TJSONObject then
      begin
        Obj := TJSONObject(JSON);
        Config.Name := Obj.Get('name', ExtractFileName(RootDir));
        Config.Version := Obj.Get('version', '0.1.0');
        Config.Description := Obj.Get('description', '');
        Config.Backend := LowerCase(Obj.Get('backend', 'pascal'));
        Config.Entry := Obj.Get('entry', 'src' + PathDelim + 'main.aeth');
        Config.Output := Obj.Get('output', 'bin' + PathDelim + Config.Name + '.exe');

        DepsData := Obj.Find('dependencies');
        if Assigned(DepsData) and (DepsData is TJSONObject) then
        begin
          DepsObj := TJSONObject(DepsData);
          SetLength(Config.Dependencies, DepsObj.Count);
          for I := 0 to DepsObj.Count - 1 do
          begin
            Config.Dependencies[I].Name := DepsObj.Names[I];
            Config.Dependencies[I].Path := '';
            Config.Dependencies[I].GitUrl := '';
            Config.Dependencies[I].Version := '';

            ItemData := DepsObj.Items[I];
            if ItemData is TJSONObject then
            begin
              ItemObj := TJSONObject(ItemData);
              Config.Dependencies[I].Path := ItemObj.Get('path', '');
              Config.Dependencies[I].GitUrl := ItemObj.Get('git', '');
              Config.Dependencies[I].Version := ItemObj.Get('version', '');
            end
            else if ItemData is TJSONString then
            begin
              Config.Dependencies[I].Version := ItemData.AsString;
            end;
          end;
        end;

        Result := True;
      end;
    finally
      JSON.Free;
    end;
  except
    on E: Exception do
      raise Exception.CreateFmt('Erro ao ler manifesto "aether.json": %s', [E.Message]);
  end;
end;

procedure WriteStringToFile(const FileName, Content: string);
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Text := Content;
    SL.SaveToFile(FileName);
  finally
    SL.Free;
  end;
end;

procedure HandleProjectInit(const ProjectName: string);
var
  TargetDir, EffectiveName: string;
  SrcDir, TestsDir, BinDir: string;
  ConfigFile, MainFile, TestFile, GitignoreFile, ReadmeFile: string;
  ConfigObj: TJSONObject;
begin
  if ProjectName <> '' then
  begin
    EffectiveName := ProjectName;
    TargetDir := ExpandFileName(GetCurrentDir + PathDelim + ProjectName);
    if not DirectoryExists(TargetDir) then
    begin
      if not ForceDirectories(TargetDir) then
        raise Exception.CreateFmt('Nao foi possivel criar o diretorio "%s"', [TargetDir]);
    end;
  end
  else
  begin
    TargetDir := ExpandFileName(GetCurrentDir);
    EffectiveName := ExtractFileName(ExcludeTrailingPathDelimiter(TargetDir));
    if EffectiveName = '' then
      EffectiveName := 'aether_app';
  end;

  ConfigFile := TargetDir + PathDelim + 'aether.json';
  if FileExists(ConfigFile) then
    raise Exception.CreateFmt('O diretorio "%s" ja contem um projeto Aether ("aether.json").', [TargetDir]);

  SrcDir := TargetDir + PathDelim + 'src';
  TestsDir := TargetDir + PathDelim + 'tests';
  BinDir := TargetDir + PathDelim + 'bin';

  ForceDirectories(SrcDir);
  ForceDirectories(TestsDir);
  ForceDirectories(BinDir);

  // 1. Gera aether.json
  ConfigObj := TJSONObject.Create;
  try
    ConfigObj.Add('name', EffectiveName);
    ConfigObj.Add('version', '0.1.0');
    ConfigObj.Add('description', 'Projeto desenvolvido na linguagem de sistemas Aether');
    ConfigObj.Add('backend', 'pascal');
    ConfigObj.Add('entry', 'src/main.aeth');
    ConfigObj.Add('output', 'bin/' + EffectiveName + '.exe');
    WriteStringToFile(ConfigFile, ConfigObj.FormatJSON);
  finally
    ConfigObj.Free;
  end;

  // 2. Gera src/main.aeth
  MainFile := SrcDir + PathDelim + 'main.aeth';
  WriteStringToFile(MainFile,
    'module Main;' + LineEnding +
    '' + LineEnding +
    'import Math;' + LineEnding +
    'import IO;' + LineEnding +
    '' + LineEnding +
    'program Main;' + LineEnding +
    'var' + LineEnding +
    '    val_max: Float64;' + LineEnding +
    '    val_abs: Float64;' + LineEnding +
    'begin' + LineEnding +
    '    PrintLn("========================================");' + LineEnding +
    '    PrintLn("  Bem-vindo ao Projeto: %s", "' + EffectiveName + '");' + LineEnding +
    '    PrintLn("  Aether: Pascal Structure + Rust Safety  ");' + LineEnding +
    '    PrintLn("========================================");' + LineEnding +
    '    PrintLn("");' + LineEnding +
    '    val_max := Max(borrow 10.5, borrow 42.0);' + LineEnding +
    '    val_abs := Abs(borrow -99.0);' + LineEnding +
    '    PrintLn("Testando calculo seguro via std/math:");' + LineEnding +
    '    PrintLn("  Max(10.5, 42.0) = %f", val_max);' + LineEnding +
    '    PrintLn("  Abs(-99.0)      = %f", val_abs);' + LineEnding +
    '    PrintLn("");' + LineEnding +
    '    PrintLn("Projeto compilado e executado com sucesso!");' + LineEnding +
    'end.' + LineEnding
  );

  // 3. Gera tests/main_test.aeth
  TestFile := TestsDir + PathDelim + 'main_test.aeth';
  WriteStringToFile(TestFile,
    'module MainTest;' + LineEnding +
    '' + LineEnding +
    'import Math;' + LineEnding +
    '' + LineEnding +
    'program Main;' + LineEnding +
    'var' + LineEnding +
    '    res: Float64;' + LineEnding +
    'begin' + LineEnding +
    '    PrintLn("[TEST] Executando bateria de testes para ' + EffectiveName + '...");' + LineEnding +
    '    res := Abs(borrow -50.0);' + LineEnding +
    '    if res = 50.0 then' + LineEnding +
    '        PrintLn("  [PASS] Teste Abs passou com sucesso!");' + LineEnding +
    '    end;' + LineEnding +
    '    PrintLn("[SUCESSO] Todos os testes passaram!");' + LineEnding +
    'end.' + LineEnding
  );

  // 4. Gera .gitignore
  GitignoreFile := TargetDir + PathDelim + '.gitignore';
  WriteStringToFile(GitignoreFile,
    'bin/' + LineEnding +
    'generated/' + LineEnding +
    '*.exe' + LineEnding +
    '*.o' + LineEnding +
    '*.ppu' + LineEnding +
    '*.vsix' + LineEnding
  );

  // 5. Gera README.md
  ReadmeFile := TargetDir + PathDelim + 'README.md';
  WriteStringToFile(ReadmeFile,
    '# ' + EffectiveName + LineEnding +
    '' + LineEnding +
    'Projeto desenvolvido com a **Linguagem de Programação Aether**.' + LineEnding +
    '' + LineEnding +
    '## 🚀 Estrutura do Projeto' + LineEnding +
    '- `aether.json`: Manifesto de configuração do projeto.' + LineEnding +
    '- `src/main.aeth`: Código-fonte principal da aplicação.' + LineEnding +
    '- `tests/main_test.aeth`: Testes unitários do projeto.' + LineEnding +
    '' + LineEnding +
    '## 🛠️ Comandos Rápidos' + LineEnding +
    '- **Compilar o projeto:**' + LineEnding +
    '  ```bash' + LineEnding +
    '  aetherc build' + LineEnding +
    '  ```' + LineEnding +
    '- **Compilar e executar imediatamente:**' + LineEnding +
    '  ```bash' + LineEnding +
    '  aetherc run' + LineEnding +
    '  ```' + LineEnding +
    '- **Compilar utilizando o backend C99/GCC:**' + LineEnding +
    '  ```bash' + LineEnding +
    '  aetherc build --target=c' + LineEnding +
    '  ```' + LineEnding
  );

  WriteLn('--------------------------------------------------------');
  WriteLn(Format(' Projeto Aether "%s" criado com sucesso!', [EffectiveName]));
  WriteLn('--------------------------------------------------------');
  WriteLn(' Diretorio: ' + TargetDir);
  WriteLn(' Estrutura inicializada:');
  WriteLn('   ├── aether.json');
  WriteLn('   ├── src/main.aeth');
  WriteLn('   ├── tests/main_test.aeth');
  WriteLn('   ├── .gitignore');
  WriteLn('   └── README.md');
  WriteLn('');
  WriteLn(' Proximos passos:');
  if ProjectName <> '' then
    WriteLn(Format('   cd %s', [ProjectName]));
  WriteLn('   aetherc run');
  WriteLn('--------------------------------------------------------');
end;

procedure HandleProjectAdd(const PkgName: string; const OptPath, OptGit, OptVer: string);
var
  RootDir, ConfigFile, JsonStr: string;
  FileStream: TFileStream;
  StringStream: TStringStream;
  JSON, DepsData: TJSONData;
  Obj, DepsObj, SubObj: TJSONObject;
  CachePkgDir, LocalDepDir: string;
  EffectivePkg, EffectiveGit, EffectiveVer: string;
  Idx: Integer;
begin
  if PkgName = '' then
    raise Exception.Create('Nome do pacote nao informado. Uso: aetherc add <nome_pacote | git_url> [--path=caminho] [--git=url] [--version=versao]');

  EffectivePkg := PkgName;
  EffectiveGit := OptGit;
  EffectiveVer := OptVer;

  // Detecta se o primeiro argumento e uma URL Git
  if (EffectiveGit = '') and
     ((Pos('http://', EffectivePkg) = 1) or (Pos('https://', EffectivePkg) = 1) or
      (Pos('git@', EffectivePkg) = 1) or (Copy(EffectivePkg, Length(EffectivePkg) - 3, 4) = '.git')) then
  begin
    EffectiveGit := EffectivePkg;
    EffectivePkg := ExtractPackageNameFromGitUrl(EffectiveGit);
  end;

  if not FindProjectRoot(RootDir, ConfigFile) then
    raise Exception.Create('Nenhum projeto Aether ("aether.json") encontrado no diretorio atual. Execute "aetherc init" primeiro.');

  FileStream := TFileStream.Create(ConfigFile, fmOpenRead or fmShareDenyWrite);
  StringStream := TStringStream.Create('');
  try
    StringStream.CopyFrom(FileStream, FileStream.Size);
    JsonStr := StringStream.DataString;
  finally
    StringStream.Free;
    FileStream.Free;
  end;

  JSON := GetJSON(JsonStr);
  try
    if not (JSON is TJSONObject) then
      raise Exception.Create('Manifesto "aether.json" invalido.');

    Obj := TJSONObject(JSON);
    DepsData := Obj.Find('dependencies');
    if not Assigned(DepsData) then
    begin
      DepsObj := TJSONObject.Create;
      Obj.Add('dependencies', DepsObj);
    end
    else if DepsData is TJSONObject then
      DepsObj := TJSONObject(DepsData)
    else
      raise Exception.Create('Secao "dependencies" em aether.json deve ser um objeto JSON.');

    // Remove dependencia anterior se ja existia
    Idx := DepsObj.IndexOfName(EffectivePkg);
    if Idx >= 0 then
      DepsObj.Delete(Idx);

    if OptPath <> '' then
    begin
      if not DirectoryExists(ExpandFileName(RootDir + PathDelim + OptPath)) and
         not DirectoryExists(ExpandFileName(OptPath)) then
        WriteLn(Format('Aviso: Diretorio local "%s" nao foi encontrado ainda.', [OptPath]));

      SubObj := TJSONObject.Create;
      SubObj.Add('path', StringReplace(OptPath, '\', '/', [rfReplaceAll]));
      if EffectiveVer <> '' then SubObj.Add('version', EffectiveVer);
      DepsObj.Add(EffectivePkg, SubObj);
    end
    else if EffectiveGit <> '' then
    begin
      SubObj := TJSONObject.Create;
      SubObj.Add('git', EffectiveGit);
      if EffectiveVer <> '' then
        SubObj.Add('version', EffectiveVer)
      else
        SubObj.Add('version', 'main');
      DepsObj.Add(EffectivePkg, SubObj);

      // Clona/sincroniza o repositorio imediatamente
      if SyncGitPackage(EffectivePkg, EffectiveGit, EffectiveVer, CachePkgDir) then
      begin
        LocalDepDir := RootDir + PathDelim + '.aether' + PathDelim + 'deps' + PathDelim + EffectivePkg;
        CopyDirectoryTree(CachePkgDir, LocalDepDir);
      end;
    end
    else
    begin
      if EffectiveVer <> '' then
        DepsObj.Add(EffectivePkg, EffectiveVer)
      else
        DepsObj.Add(EffectivePkg, '*');

      CachePkgDir := GetAetherCacheDir + PathDelim + EffectivePkg;
      if not DirectoryExists(CachePkgDir) then
        ForceDirectories(CachePkgDir);
    end;

    WriteStringToFile(ConfigFile, Obj.FormatJSON);
  finally
    JSON.Free;
  end;

  WriteLn('--------------------------------------------------------');
  WriteLn(Format(' Pacote "%s" adicionado com sucesso a "aether.json"!', [EffectivePkg]));
  WriteLn('--------------------------------------------------------');
  if OptPath <> '' then
    WriteLn(' Origem: ' + OptPath)
  else if EffectiveGit <> '' then
    WriteLn(' Repositorio Git: ' + EffectiveGit)
  else
    WriteLn(' Versao: ' + EffectiveVer);
  WriteLn(' Pronto para importacao no projeto:');
  WriteLn(Format('   import %s;', [UpCase(EffectivePkg[1]) + Copy(EffectivePkg, 2, Length(EffectivePkg))]));
  WriteLn('--------------------------------------------------------');
end;

end.
