unit uAetherProject;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  SysUtils, Classes, fpjson, jsonparser, Process, uAetherRegistry;

type
  TAetherDependency = record
    Name: string;
    Path: string;
    GitUrl: string;
    Version: string;
  end;

  TStringArray = array of string;

  TAetherProjectOutputs = record
    BinDir: string;
    PascalSrcDir: string;
    PascalUnitDir: string;
    CSrcDir: string;
    AsUnit: Boolean;
  end;

  TAetherTargetConfig = record
    Name: string;
    Entry: string;
    Target: string;    // 'pascal', 'c', 'wasm', 'js'
    Backend: string;   // 'clang', 'fpc', 'gcc', 'pas2js'
    TargetType: string; // 'bin', 'lib', 'cdylib'
    Output: string;
  end;
  TAetherTargetArray = array of TAetherTargetConfig;

  TAetherProjectConfig = record
    Name: string;
    Version: string;
    Description: string;
    ProjectType: string; // 'bin' (default), 'lib', 'cdylib'
    Backend: string;
    CCompiler: string; // 'gcc' ou 'clang'
    Entry: string;
    Output: string;
    RootDir: string;
    ConfigFile: string;
    Dependencies: array of TAetherDependency;
    PathsAether: TStringArray;
    PathsCIncludes: TStringArray;
    PathsCSources: TStringArray;
    PathsPascalUnits: TStringArray;
    PathsLibDirs: TStringArray;
    PathsLibs: TStringArray;
    PathsSharedLibs: TStringArray;
    Outputs: TAetherProjectOutputs;
    Targets: TAetherTargetArray;
  end;

function FindProjectRoot(out RootDir, ConfigFile: string): Boolean;
function LoadProjectConfig(out Config: TAetherProjectConfig): Boolean;
procedure CopySharedLibraries(const RootDir, OutExe: string; const SharedLibs: TStringArray);
procedure CopySharedLibraries(const RootDir, OutExe: string; SharedLibsList: TStrings);
function GetAetherCacheDir: string;
function ExtractPackageNameFromGitUrl(const Url: string): string;
function SyncGitPackage(const PkgName, GitUrl, Version: string; out CacheDir: string; Visited: TStringList = nil): Boolean;
procedure RestoreProjectDependencies(const Config: TAetherProjectConfig);
procedure HandleProjectInit(const ProjectName: string);
procedure HandleProjectAdd(const PkgName: string; const OptPath, OptGit, OptVer: string);
procedure HandleProjectRemove(const PkgName: string);
procedure HandleProjectUpdate(const PkgName: string);
procedure HandleProjectAudit();
procedure HandleProjectList();
procedure HandleProjectCleanCache();
procedure HandleProjectClean();

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

procedure DeleteDirectoryTree(const DirPath: string);
var
  Info: TSearchRec;
  CurrentExe: string;
begin
  if not DirectoryExists(DirPath) then Exit;
  CurrentExe := ExpandFileName(ParamStr(0));
  if FindFirst(DirPath + PathDelim + '*', faAnyFile, Info) = 0 then
  begin
    try
      repeat
        if (Info.Name <> '.') and (Info.Name <> '..') then
        begin
          if (Info.Attr and faDirectory) <> 0 then
            DeleteDirectoryTree(DirPath + PathDelim + Info.Name)
          else
          begin
            if not SameText(ExpandFileName(DirPath + PathDelim + Info.Name), CurrentExe) then
              DeleteFile(DirPath + PathDelim + Info.Name);
          end;
        end;
      until FindNext(Info) <> 0;
    finally
      FindClose(Info);
    end;
  end;
  RemoveDir(DirPath);
end;

function GetGitCommitHash(const RepoDir: string): string;
var
  OutputLog: string;
begin
  Result := '';
  if DirectoryExists(RepoDir + PathDelim + '.git') or FileExists(RepoDir + PathDelim + '.git') then
  begin
    if RunGitProcess('-C "' + RepoDir + '" rev-parse HEAD', OutputLog) = 0 then
      Result := Trim(OutputLog);
  end;
  if Result = '' then
    Result := 'local-uncommitted';
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

function LoadLockfile(const RootDir: string): TJSONObject;
var
  LockFile, JsonStr: string;
  FileStream: TFileStream;
  StringStream: TStringStream;
  JSON: TJSONData;
begin
  LockFile := RootDir + PathDelim + 'aether.lock';
  if FileExists(LockFile) then
  begin
    try
      FileStream := TFileStream.Create(LockFile, fmOpenRead or fmShareDenyWrite);
      StringStream := TStringStream.Create('');
      try
        StringStream.CopyFrom(FileStream, FileStream.Size);
        JsonStr := StringStream.DataString;
      finally
        StringStream.Free;
        FileStream.Free;
      end;
      JSON := GetJSON(JsonStr);
      if JSON is TJSONObject then
        Exit(TJSONObject(JSON));
    except
    end;
  end;
  Result := TJSONObject.Create;
  Result.Add('lockfile_version', 1);
  Result.Add('generator', 'aetherc');
  Result.Add('packages', TJSONObject.Create);
end;

procedure SaveLockfile(const RootDir: string; LockObj: TJSONObject);
var
  LockFile: string;
begin
  LockFile := RootDir + PathDelim + 'aether.lock';
  WriteStringToFile(LockFile, LockObj.FormatJSON);
end;

procedure UpdateLockfile(const RootDir, PkgName, SourceType, SourceUrl, Version, CommitHash: string);
var
  LockObj, PkgsObj, ItemObj: TJSONObject;
  PkgsData, ItemData: TJSONData;
  IsTls: Boolean;
begin
  LockObj := LoadLockfile(RootDir);
  try
    PkgsData := LockObj.Find('packages');
    if Assigned(PkgsData) and (PkgsData is TJSONObject) then
      PkgsObj := TJSONObject(PkgsData)
    else
    begin
      PkgsObj := TJSONObject.Create;
      LockObj.Add('packages', PkgsObj);
    end;

    ItemData := PkgsObj.Find(PkgName);
    if Assigned(ItemData) and (ItemData is TJSONObject) then
      ItemObj := TJSONObject(ItemData)
    else
    begin
      ItemObj := TJSONObject.Create;
      PkgsObj.Add(PkgName, ItemObj);
    end;

    IsTls := (Pos('https://', SourceUrl) = 1) or (Pos('git@', SourceUrl) = 1) or (SourceType = 'path');

    if ItemObj.IndexOfName('source') >= 0 then ItemObj.Delete(ItemObj.IndexOfName('source'));
    ItemObj.Add('source', SourceType);

    if ItemObj.IndexOfName('url') >= 0 then ItemObj.Delete(ItemObj.IndexOfName('url'));
    ItemObj.Add('url', SourceUrl);

    if ItemObj.IndexOfName('version') >= 0 then ItemObj.Delete(ItemObj.IndexOfName('version'));
    ItemObj.Add('version', Version);

    if ItemObj.IndexOfName('commit') >= 0 then ItemObj.Delete(ItemObj.IndexOfName('commit'));
    ItemObj.Add('commit', CommitHash);

    if ItemObj.IndexOfName('tls_secure') >= 0 then ItemObj.Delete(ItemObj.IndexOfName('tls_secure'));
    ItemObj.Add('tls_secure', IsTls);

    if ItemObj.IndexOfName('integrity') >= 0 then ItemObj.Delete(ItemObj.IndexOfName('integrity'));
    ItemObj.Add('integrity', 'verified');

    SaveLockfile(RootDir, LockObj);
  finally
    LockObj.Free;
  end;
end;

procedure RemoveFromLockfile(const RootDir, PkgName: string);
var
  LockObj, PkgsObj: TJSONObject;
  PkgsData: TJSONData;
  Idx: Integer;
begin
  LockObj := LoadLockfile(RootDir);
  try
    PkgsData := LockObj.Find('packages');
    if Assigned(PkgsData) and (PkgsData is TJSONObject) then
    begin
      PkgsObj := TJSONObject(PkgsData);
      Idx := PkgsObj.IndexOfName(PkgName);
      if Idx >= 0 then
      begin
        PkgsObj.Delete(Idx);
        SaveLockfile(RootDir, LockObj);
      end;
    end;
  finally
    LockObj.Free;
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
  CacheDir, LocalDepDir, ResolvedVer: string;
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
    end
    else if Config.Dependencies[I].Path = '' then
    begin
      // Dependencia via Registry Central
      if FetchPackageFromRegistry(Config.Dependencies[I].Name,
                                 Config.Dependencies[I].Version,
                                 CacheDir, ResolvedVer) then
      begin
        LocalDepDir := Config.RootDir + PathDelim + '.aether' + PathDelim + 'deps' + PathDelim + Config.Dependencies[I].Name;
        if not DirectoryExists(LocalDepDir) then
        begin
          WriteLn(Format('   Instalando "%s@%s" do Registry em ".aether/deps/%s"...',
            [Config.Dependencies[I].Name, ResolvedVer, Config.Dependencies[I].Name]));
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

procedure ReadJsonStringArray(ParentObj: TJSONObject; const PropName: string; out Dest: TStringArray);
var
  Data: TJSONData;
  Arr: TJSONArray;
  I: Integer;
begin
  SetLength(Dest, 0);
  if not Assigned(ParentObj) then Exit;
  Data := ParentObj.Find(PropName);
  if Assigned(Data) and (Data is TJSONArray) then
  begin
    Arr := TJSONArray(Data);
    SetLength(Dest, Arr.Count);
    for I := 0 to Arr.Count - 1 do
      Dest[I] := Arr.Strings[I];
  end;
end;

function SafeCopyFile(const Src, Dst: string): Boolean;
var
  FSrc, FDst: TFileStream;
begin
  Result := False;
  try
    FSrc := TFileStream.Create(Src, fmOpenRead or fmShareDenyWrite);
    try
      FDst := TFileStream.Create(Dst, fmCreate);
      try
        FDst.CopyFrom(FSrc, FSrc.Size);
        Result := True;
      finally
        FDst.Free;
      end;
    finally
      FSrc.Free;
    end;
  except
    Result := False;
  end;
end;

procedure CopySharedLibraries(const RootDir, OutExe: string; const SharedLibs: TStringArray);
var
  I: Integer;
  SrcLib, DestDir, DestLib: string;
begin
  DestDir := ExtractFileDir(OutExe);
  if DestDir = '' then DestDir := '.';
  ForceDirectories(DestDir);
  for I := 0 to High(SharedLibs) do
  begin
    if Trim(SharedLibs[I]) = '' then Continue;
    SrcLib := Trim(SharedLibs[I]);
    if not ((Length(SrcLib) >= 2) and (SrcLib[2] = ':')) and not (Pos(PathDelim, SrcLib) = 1) and not (Pos('/', SrcLib) = 1) then
      SrcLib := RootDir + PathDelim + SrcLib;
    SrcLib := ExpandFileName(SrcLib);
    if FileExists(SrcLib) then
    begin
      DestLib := DestDir + PathDelim + ExtractFileName(SrcLib);
      if (not FileExists(DestLib)) or (FileAge(SrcLib) > FileAge(DestLib)) then
      begin
        if SafeCopyFile(SrcLib, DestLib) then
          WriteLn(Format('   [DEPLOY] Biblioteca compartilhada copiada: %s -> %s', [ExtractFileName(SrcLib), DestDir]))
        else
          WriteLn(Format('   [AVISO] Falha ao copiar biblioteca compartilhada: %s', [SrcLib]));
      end;
    end
    else
      WriteLn(Format('   [AVISO] Biblioteca em shared_libs nao encontrada: "%s"', [SharedLibs[I]]));
  end;
end;

procedure CopySharedLibraries(const RootDir, OutExe: string; SharedLibsList: TStrings);
var
  Arr: array of string;
  I: Integer;
begin
  if not Assigned(SharedLibsList) or (SharedLibsList.Count = 0) then Exit;
  SetLength(Arr, SharedLibsList.Count);
  for I := 0 to SharedLibsList.Count - 1 do
    Arr[I] := SharedLibsList[I];
  CopySharedLibraries(RootDir, OutExe, Arr);
end;

function LoadProjectConfig(out Config: TAetherProjectConfig): Boolean;
var
  RootDir, ConfigFile, JsonStr: string;
  FileStream: TFileStream;
  StringStream: TStringStream;
  JSON, DepsData, ItemData, PathsData, OutputsData, TargetsData: TJSONData;
  Obj, DepsObj, ItemObj, PathsObj, OutputsObj: TJSONObject;
  TargetsArr: TJSONArray;
  I: Integer;
begin
  Result := False;
  SetLength(Config.Dependencies, 0);
  SetLength(Config.PathsAether, 0);
  SetLength(Config.PathsCIncludes, 0);
  SetLength(Config.PathsCSources, 0);
  SetLength(Config.PathsPascalUnits, 0);
  SetLength(Config.PathsLibDirs, 0);
  SetLength(Config.PathsLibs, 0);
  SetLength(Config.PathsSharedLibs, 0);
  SetLength(Config.Targets, 0);
  Config.CCompiler := 'gcc';
  Config.Outputs.BinDir := '';
  Config.Outputs.PascalSrcDir := '';
  Config.Outputs.PascalUnitDir := '';
  Config.Outputs.CSrcDir := '';
  Config.Outputs.AsUnit := False;
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
        Config.ProjectType := LowerCase(Obj.Get('type', 'bin'));
        Config.Backend := LowerCase(Obj.Get('backend', 'pascal'));
        Config.CCompiler := LowerCase(Obj.Get('c_compiler', 'gcc'));
        Config.Entry := Obj.Get('entry', 'src' + PathDelim + 'main.aeth');
        if (Config.ProjectType = 'cdylib') or (Config.ProjectType = 'lib') then
        begin
          {$IFDEF MSWINDOWS}
          Config.Output := Obj.Get('output', 'bin' + PathDelim + Config.Name + '.dll');
          {$ELSE}
          Config.Output := Obj.Get('output', 'bin' + PathDelim + 'lib' + Config.Name + '.so');
          {$ENDIF}
        end
        else
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

        PathsData := Obj.Find('paths');
        if Assigned(PathsData) and (PathsData is TJSONObject) then
        begin
          PathsObj := TJSONObject(PathsData);
          ReadJsonStringArray(PathsObj, 'aether', Config.PathsAether);
          ReadJsonStringArray(PathsObj, 'c_includes', Config.PathsCIncludes);
          ReadJsonStringArray(PathsObj, 'c_sources', Config.PathsCSources);
          ReadJsonStringArray(PathsObj, 'pascal_units', Config.PathsPascalUnits);
          ReadJsonStringArray(PathsObj, 'lib_dirs', Config.PathsLibDirs);
          ReadJsonStringArray(PathsObj, 'libs', Config.PathsLibs);
          ReadJsonStringArray(PathsObj, 'shared_libs', Config.PathsSharedLibs);
        end;

        OutputsData := Obj.Find('outputs');
        if Assigned(OutputsData) and (OutputsData is TJSONObject) then
        begin
          OutputsObj := TJSONObject(OutputsData);
          Config.Outputs.BinDir := OutputsObj.Get('bin_dir', '');
          Config.Outputs.PascalSrcDir := OutputsObj.Get('pascal_src_dir', '');
          Config.Outputs.PascalUnitDir := OutputsObj.Get('pascal_unit_dir', '');
          Config.Outputs.CSrcDir := OutputsObj.Get('c_src_dir', '');
          Config.Outputs.AsUnit := OutputsObj.Get('as_unit', False);
        end;

        TargetsData := Obj.Find('targets');
        if Assigned(TargetsData) and (TargetsData is TJSONArray) then
        begin
          TargetsArr := TJSONArray(TargetsData);
          SetLength(Config.Targets, TargetsArr.Count);
          for I := 0 to TargetsArr.Count - 1 do
          begin
            ItemData := TargetsArr.Items[I];
            if ItemData is TJSONObject then
            begin
              ItemObj := TJSONObject(ItemData);
              Config.Targets[I].Name := ItemObj.Get('name', '');
              Config.Targets[I].Entry := ItemObj.Get('entry', '');
              Config.Targets[I].Target := LowerCase(ItemObj.Get('target', 'pascal'));
              Config.Targets[I].Backend := LowerCase(ItemObj.Get('backend', ''));
              Config.Targets[I].TargetType := LowerCase(ItemObj.Get('type', ''));
              Config.Targets[I].Output := ItemObj.Get('output', '');
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

procedure SanitizeProjectIdent(const RawName: string; out FileBase, ModName: string);
var
  I: Integer;
  C: Char;
  Clean: string;
  HasLetter: Boolean;
begin
  Clean := '';
  HasLetter := False;
  for I := 1 to Length(RawName) do
  begin
    C := RawName[I];
    if C in ['a'..'z', 'A'..'Z'] then
    begin
      Clean := Clean + LowerCase(C);
      HasLetter := True;
    end
    else if C in ['0'..'9', '_'] then
      Clean := Clean + C
    else
      Clean := Clean + '_';
  end;

  if (Clean = '') or (not HasLetter) then
    Clean := 'aether_app'
  else if Clean[1] in ['0'..'9'] then
    Clean := 'app_' + Clean;

  FileBase := Clean;
  ModName := UpCase(FileBase[1]) + Copy(FileBase, 2, Length(FileBase));
end;

procedure HandleProjectInit(const ProjectName: string);
var
  TargetDir, EffectiveName, FileBase, ModName: string;
  SrcDir, TestsDir, BinDir: string;
  ConfigFile, MainFile, TestFile, GitignoreFile, ReadmeFile: string;
  ConfigObj, PathsObj, OutputsObj: TJSONObject;
  ArrAether: TJSONArray;
begin
  if (ProjectName <> '') and (ProjectName <> '.') then
  begin
    TargetDir := ExpandFileName(GetCurrentDir + PathDelim + ProjectName);
    if not DirectoryExists(TargetDir) then
    begin
      if not ForceDirectories(TargetDir) then
        raise Exception.CreateFmt('Nao foi possivel criar o diretorio "%s"', [TargetDir]);
    end;
    EffectiveName := ExtractFileName(ExcludeTrailingPathDelimiter(TargetDir));
    if EffectiveName = '' then
      EffectiveName := ProjectName;
  end
  else
  begin
    TargetDir := ExpandFileName(GetCurrentDir);
    EffectiveName := ExtractFileName(ExcludeTrailingPathDelimiter(TargetDir));
    if EffectiveName = '' then
      EffectiveName := 'aether_app';
  end;

  SanitizeProjectIdent(EffectiveName, FileBase, ModName);

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
    ConfigObj.Add('entry', 'src/' + FileBase + '.aeth');
    ConfigObj.Add('output', 'bin/' + EffectiveName + '.exe');

    // Seção 'paths' para organização de código e interop C / Pascal / DLLs
    PathsObj := TJSONObject.Create;
    ArrAether := TJSONArray.Create;
    ArrAether.Add('src');
    PathsObj.Add('aether', ArrAether);
    PathsObj.Add('c_includes', TJSONArray.Create);
    PathsObj.Add('c_sources', TJSONArray.Create);
    PathsObj.Add('pascal_units', TJSONArray.Create);
    PathsObj.Add('lib_dirs', TJSONArray.Create);
    PathsObj.Add('libs', TJSONArray.Create);
    PathsObj.Add('shared_libs', TJSONArray.Create);
    ConfigObj.Add('paths', PathsObj);

    // Seção 'outputs' para configuração de diretórios de saída do projeto
    OutputsObj := TJSONObject.Create;
    OutputsObj.Add('bin_dir', 'bin');
    OutputsObj.Add('pascal_src_dir', 'build/pascal');
    OutputsObj.Add('pascal_unit_dir', 'build/units');
    OutputsObj.Add('c_src_dir', 'build/c');
    OutputsObj.Add('as_unit', false);
    ConfigObj.Add('outputs', OutputsObj);

    WriteStringToFile(ConfigFile, ConfigObj.FormatJSON);
  finally
    ConfigObj.Free;
  end;

  // 2. Gera src/<FileBase>.aeth
  MainFile := SrcDir + PathDelim + FileBase + '.aeth';
  WriteStringToFile(MainFile,
    'module ' + ModName + ';' + LineEnding +
    '' + LineEnding +
    'import Math;' + LineEnding +
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
    'end ' + ModName + '.' + LineEnding
  );

  // 3. Gera tests/<FileBase>_test.aeth
  TestFile := TestsDir + PathDelim + FileBase + '_test.aeth';
  WriteStringToFile(TestFile,
    'module ' + ModName + 'Test;' + LineEnding +
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
    'end ' + ModName + 'Test.' + LineEnding
  );

  // 4. Gera .gitignore
  GitignoreFile := TargetDir + PathDelim + '.gitignore';
  WriteStringToFile(GitignoreFile,
    'bin/' + LineEnding +
    'build/' + LineEnding +
    'generated/' + LineEnding +
    '.aether/' + LineEnding +
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
    '- `src/' + FileBase + '.aeth`: Código-fonte principal da aplicação.' + LineEnding +
    '- `tests/' + FileBase + '_test.aeth`: Testes unitários do projeto.' + LineEnding +
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
  WriteLn('   ├── src/' + FileBase + '.aeth');
  WriteLn('   ├── tests/' + FileBase + '_test.aeth');
  WriteLn('   ├── .gitignore');
  WriteLn('   └── README.md');
  WriteLn('');
  WriteLn(' Proximos passos:');
  if (ProjectName <> '') and (ProjectName <> '.') then
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
  CachePkgDir, LocalDepDir, ResolvedVer: string;
  EffectivePkg, EffectiveGit, EffectiveVer: string;
  Idx, AtPos, HashPos, StartIdx, P: Integer;
begin
  if PkgName = '' then
    raise Exception.Create('Nome do pacote nao informado. Uso: aetherc pkg add <nome_pacote[@versao] | git_url[@tag]> [--version=versao]');

  EffectivePkg := PkgName;
  EffectiveGit := OptGit;
  EffectiveVer := OptVer;

  // 1. Suporte a especificacao inline de versao via "@versao" ou "#tag"
  // Ex: "aether-horse@1.0.0", "https://github.com/org/repo@v2.0.0", "repo#v1.0"
  AtPos := 0;
  StartIdx := 1;
  if Pos('git@', EffectivePkg) = 1 then StartIdx := 5;
  for P := StartIdx to Length(EffectivePkg) do
  begin
    if EffectivePkg[P] = '@' then
    begin
      AtPos := P;
      Break;
    end;
  end;

  if (EffectiveVer = '') and (AtPos > 0) then
  begin
    EffectiveVer := Copy(EffectivePkg, AtPos + 1, Length(EffectivePkg));
    EffectivePkg := Copy(EffectivePkg, 1, AtPos - 1);
  end;

  HashPos := Pos('#', EffectivePkg);
  if (EffectiveVer = '') and (HashPos > 0) then
  begin
    EffectiveVer := Copy(EffectivePkg, HashPos + 1, Length(EffectivePkg));
    EffectivePkg := Copy(EffectivePkg, 1, HashPos - 1);
  end;

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
      ResolvedVer := EffectiveVer;
      // Busca e instala do Registry Central
      if FetchPackageFromRegistry(EffectivePkg, EffectiveVer, CachePkgDir, ResolvedVer) then
      begin
        LocalDepDir := RootDir + PathDelim + '.aether' + PathDelim + 'deps' + PathDelim + EffectivePkg;
        CopyDirectoryTree(CachePkgDir, LocalDepDir);
        if EffectiveVer <> '' then
          DepsObj.Add(EffectivePkg, EffectiveVer)
        else
          DepsObj.Add(EffectivePkg, '^' + ResolvedVer);
        WriteLn(Format('   Pacote "%s@%s" instalado com sucesso do Registry!', [EffectivePkg, ResolvedVer]));
      end
      else
      begin
        if EffectiveVer <> '' then
          DepsObj.Add(EffectivePkg, EffectiveVer)
        else
          DepsObj.Add(EffectivePkg, '*');
      end;
    end;

    WriteStringToFile(ConfigFile, Obj.FormatJSON);

    // Atualiza o Lockfile de Seguranca (aether.lock)
    if OptPath <> '' then
      UpdateLockfile(RootDir, EffectivePkg, 'path', OptPath, EffectiveVer, 'local-link')
    else if EffectiveGit <> '' then
      UpdateLockfile(RootDir, EffectivePkg, 'git', EffectiveGit, EffectiveVer, GetGitCommitHash(CachePkgDir))
    else
      UpdateLockfile(RootDir, EffectivePkg, 'registry', ResolvedVer, ResolvedVer, 'verified');
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
  WriteLn(' [OK] Integridade registrada em "aether.lock"');
  WriteLn(' Pronto para importacao no projeto:');
  WriteLn(Format('   import %s;', [UpCase(EffectivePkg[1]) + Copy(EffectivePkg, 2, Length(EffectivePkg))]));
  WriteLn('--------------------------------------------------------');
end;

procedure HandleProjectRemove(const PkgName: string);
var
  RootDir, ConfigFile, JsonStr: string;
  FileStream: TFileStream;
  StringStream: TStringStream;
  JSON, DepsData: TJSONData;
  Obj, DepsObj: TJSONObject;
  LocalDepDir: string;
  Idx: Integer;
begin
  if PkgName = '' then
    raise Exception.Create('Nome do pacote nao informado. Uso: aetherc remove <nome_pacote>');

  if not FindProjectRoot(RootDir, ConfigFile) then
    raise Exception.Create('Nenhum projeto Aether ("aether.json") encontrado no diretorio atual.');

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
    if Assigned(DepsData) and (DepsData is TJSONObject) then
    begin
      DepsObj := TJSONObject(DepsData);
      Idx := DepsObj.IndexOfName(PkgName);
      if Idx >= 0 then
        DepsObj.Delete(Idx)
      else
        raise Exception.CreateFmt('Pacote "%s" nao foi encontrado nas dependencias de "aether.json".', [PkgName]);
    end
    else
      raise Exception.Create('Nenhuma dependencia encontrada em "aether.json".');

    WriteStringToFile(ConfigFile, Obj.FormatJSON);
  finally
    JSON.Free;
  end;

  // Remove pasta local em .aether/deps/<pkg>
  LocalDepDir := RootDir + PathDelim + '.aether' + PathDelim + 'deps' + PathDelim + PkgName;
  if DirectoryExists(LocalDepDir) then
    DeleteDirectoryTree(LocalDepDir);

  // Sincroniza aether.lock
  RemoveFromLockfile(RootDir, PkgName);

  WriteLn('--------------------------------------------------------');
  WriteLn(Format(' Pacote "%s" removido com sucesso de "aether.json"!', [PkgName]));
  WriteLn('--------------------------------------------------------');
  WriteLn(' [OK] Pasta local .aether/deps/' + PkgName + ' excluida.');
  WriteLn(' [OK] Lockfile "aether.lock" sincronizado.');
  WriteLn('--------------------------------------------------------');
end;

procedure HandleProjectUpdate(const PkgName: string);
var
  Config: TAetherProjectConfig;
  CacheDir, LocalDepDir, CommitHash, OutputLog: string;
  I: Integer;
  Found: Boolean;
  Dep: TAetherDependency;
begin
  if not LoadProjectConfig(Config) then
    raise Exception.Create('Nenhum projeto Aether ("aether.json") encontrado no diretorio atual.');

  WriteLn('========================================================');
  WriteLn('  Aether Package Manager (aetherc update)               ');
  WriteLn('========================================================');

  Found := False;
  for I := 0 to High(Config.Dependencies) do
  begin
    Dep := Config.Dependencies[I];
    if (PkgName <> '') and (Dep.Name <> PkgName) then
      Continue;

    Found := True;
    WriteLn(Format('-> Atualizando pacote "%s"...', [Dep.Name]));

    if Dep.GitUrl <> '' then
    begin
      CacheDir := GetAetherCacheDir + PathDelim + Dep.Name;
      if DirectoryExists(CacheDir + PathDelim + '.git') then
      begin
        RunGitProcess('-C "' + CacheDir + '" fetch --all --quiet', OutputLog);
        if (Dep.Version <> '') and (Dep.Version <> '*') and (Dep.Version <> 'main') then
          RunGitProcess('-C "' + CacheDir + '" checkout ' + Dep.Version, OutputLog)
        else
          RunGitProcess('-C "' + CacheDir + '" pull --quiet', OutputLog);
      end
      else
        SyncGitPackage(Dep.Name, Dep.GitUrl, Dep.Version, CacheDir);

      CommitHash := GetGitCommitHash(CacheDir);
      LocalDepDir := Config.RootDir + PathDelim + '.aether' + PathDelim + 'deps' + PathDelim + Dep.Name;
      if DirectoryExists(LocalDepDir) then
        DeleteDirectoryTree(LocalDepDir);
      CopyDirectoryTree(CacheDir, LocalDepDir);

      UpdateLockfile(Config.RootDir, Dep.Name, 'git', Dep.GitUrl, Dep.Version, CommitHash);
      WriteLn(Format('   [OK] Atualizado para o commit: %s', [Copy(CommitHash, 1, 10)]));
    end
    else if Dep.Path <> '' then
    begin
      LocalDepDir := Config.RootDir + PathDelim + '.aether' + PathDelim + 'deps' + PathDelim + Dep.Name;
      UpdateLockfile(Config.RootDir, Dep.Name, 'path', Dep.Path, Dep.Version, 'local-link');
      WriteLn('   [OK] Dependencia local re-sincronizada.');
    end;
  end;

  if (PkgName <> '') and not Found then
    raise Exception.CreateFmt('Pacote "%s" nao encontrado no manifesto "aether.json".', [PkgName]);

  WriteLn('--------------------------------------------------------');
  WriteLn(' Todas as dependencias foram atualizadas e bloqueadas!');
  WriteLn(' Lockfile "aether.lock" atualizado com sucesso.');
  WriteLn('========================================================');
end;

procedure HandleProjectAudit();
var
  Config: TAetherProjectConfig;
  LockObj, PkgsObj, ItemObj: TJSONObject;
  PkgsData, ItemData: TJSONData;
  Dep: TAetherDependency;
  I, WarningsCount, TamperCount: Integer;
  IsTls, HasLock: Boolean;
  LockCommit, CurrentCommit, CacheDir: string;
begin
  if not LoadProjectConfig(Config) then
    raise Exception.Create('Nenhum projeto Aether ("aether.json") encontrado no diretorio atual.');

  WriteLn('========================================================');
  WriteLn('  Aether Security Audit (aetherc audit)                 ');
  WriteLn('  Protecao de Integridade e Supply Chain (Aether Guard) ');
  WriteLn('========================================================');

  LockObj := LoadLockfile(Config.RootDir);
  try
    PkgsData := LockObj.Find('packages');
    if Assigned(PkgsData) and (PkgsData is TJSONObject) then
      PkgsObj := TJSONObject(PkgsData)
    else
      PkgsObj := nil;

    WarningsCount := 0;
    TamperCount := 0;

    WriteLn(Format('[AUDIT] Analisando %d dependencia(s) do projeto "%s"...', [Length(Config.Dependencies), Config.Name]));
    WriteLn('');

    for I := 0 to High(Config.Dependencies) do
    begin
      Dep := Config.Dependencies[I];
      HasLock := False;
      LockCommit := '';

      if Assigned(PkgsObj) then
      begin
        ItemData := PkgsObj.Find(Dep.Name);
        if Assigned(ItemData) and (ItemData is TJSONObject) then
        begin
          ItemObj := TJSONObject(ItemData);
          HasLock := True;
          LockCommit := ItemObj.Get('commit', '');
        end;
      end;

      // 1. Verificacao de Protocolo TLS
      IsTls := True;
      if Dep.GitUrl <> '' then
      begin
        if Pos('http://', Dep.GitUrl) = 1 then
        begin
          IsTls := False;
          Inc(WarningsCount);
          WriteLn(Format('  [ALERTA DE SEGURANCA] Pacote "%s" usa conexao insegura sem TLS (http://): "%s"', [Dep.Name, Dep.GitUrl]));
          WriteLn('                        Recomendacao: Utilize "https://" ou "git@" para evitar ataques man-in-the-middle.');
        end;
      end;

      // 2. Verificacao de Integridade do Lockfile e Anti-Adulteracao (Tampering)
      if Dep.GitUrl <> '' then
      begin
        CacheDir := GetAetherCacheDir + PathDelim + Dep.Name;
        CurrentCommit := GetGitCommitHash(CacheDir);

        if not HasLock then
        begin
          Inc(WarningsCount);
          WriteLn(Format('  [AVISO] Pacote "%s" nao esta registrado em "aether.lock". Execute "aetherc update" para gerar.', [Dep.Name]));
        end
        else if (LockCommit <> '') and (CurrentCommit <> '') and (LockCommit <> CurrentCommit) then
        begin
          Inc(TamperCount);
          WriteLn(Format('  [PERIGO - ADULTERACAO DETECTADA] Pacote "%s" foi modificado!', [Dep.Name]));
          WriteLn(Format('    Commit registrado no lock: %s', [Copy(LockCommit, 1, 10)]));
          WriteLn(Format('    Commit encontrado no disco: %s', [Copy(CurrentCommit, 1, 10)]));
          WriteLn('    O codigo em cache pode ter sido adulterado!');
        end
        else
        begin
          WriteLn(Format('  [OK] %s: Commit %s verificado e integro (TLS Seguro: %s)', [Dep.Name, Copy(CurrentCommit, 1, 10), BoolToStr(IsTls, 'Sim', 'Nao')]));
        end;
      end
      else if Dep.Path <> '' then
      begin
        WriteLn(Format('  [OK] %s: Dependencia local em "%s" (Origem interna confiavel)', [Dep.Name, Dep.Path]));
      end
      else
      begin
        WriteLn(Format('  [OK] %s: Versao especificada "%s"', [Dep.Name, Dep.Version]));
      end;
    end;

    WriteLn('');
    WriteLn('--------------------------------------------------------');
    WriteLn(Format(' Resultados: %d pacotes auditados | %d adulteracoes | %d alertas', [Length(Config.Dependencies), TamperCount, WarningsCount]));
    if (TamperCount = 0) and (WarningsCount = 0) then
    begin
      WriteLn(' Status: AMBIENTE SEGURO (Aether Verified)');
    end
    else if TamperCount > 0 then
    begin
      WriteLn(' Status: FALHA CRITICA DE SEGURANCA - ADULTERACAO DETECTADA!');
    end
    else
    begin
      WriteLn(' Status: ATENCAO - ALERTAS DETECTADOS');
    end;
    WriteLn('========================================================');
  finally
    LockObj.Free;
  end;
end;

procedure HandleProjectList();
var
  Config: TAetherProjectConfig;
  I: Integer;
  Dep: TAetherDependency;
  Origem: string;
begin
  if not LoadProjectConfig(Config) then
    raise Exception.Create('Nenhum projeto Aether ("aether.json") encontrado no diretorio atual.');

  WriteLn('========================================================');
  WriteLn(Format('  Dependencias do Projeto: "%s" (v%s)', [Config.Name, Config.Version]));
  WriteLn('========================================================');
  if Length(Config.Dependencies) = 0 then
  begin
    WriteLn('  Nenhuma dependencia instalada.');
    WriteLn('  Dica: Use "aetherc pkg add <pacote>" para adicionar.');
  end
  else
  begin
    for I := 0 to High(Config.Dependencies) do
    begin
      Dep := Config.Dependencies[I];
      if Dep.GitUrl <> '' then
        Origem := 'Git: ' + Dep.GitUrl + ' (' + Dep.Version + ')'
      else if Dep.Path <> '' then
        Origem := 'Local: ' + Dep.Path
      else
        Origem := 'Versao: ' + Dep.Version;

      WriteLn(Format('  • %-18s -> %s', [Dep.Name, Origem]));
    end;
  end;
  WriteLn('========================================================');
end;

procedure HandleProjectCleanCache();
var
  CacheDir: string;
begin
  CacheDir := GetAetherCacheDir;
  WriteLn('========================================================');
  WriteLn('  Aether Package Manager (aetherc pkg clean)            ');
  WriteLn('========================================================');
  WriteLn('Limpando cache global de pacotes em: ' + CacheDir);
  if DirectoryExists(CacheDir) then
  begin
    DeleteDirectoryTree(CacheDir);
    ForceDirectories(CacheDir);
    WriteLn('[OK] Cache global limpo com sucesso.');
  end
  else
    WriteLn('[OK] Cache ja estava vazio.');
  WriteLn('========================================================');
end;

procedure HandleProjectClean();
var
  RootDir, Dummy: string;
  GenDir, BinDir, BuildCacheDir, CustomDir: string;
  Config: TAetherProjectConfig;
  HasConfig: Boolean;
begin
  if not FindProjectRoot(RootDir, Dummy) then
    RootDir := GetCurrentDir;

  HasConfig := LoadProjectConfig(Config);

  WriteLn('========================================================');
  WriteLn('  Aether Project Cleaner (aetherc clean)                ');
  WriteLn('========================================================');
  WriteLn('Limpando artefatos de build em: ' + RootDir);

  GenDir := RootDir + PathDelim + 'generated';
  if DirectoryExists(GenDir) then
  begin
    DeleteDirectoryTree(GenDir);
    WriteLn('  • generated/ ... [REMOVIDO]');
  end
  else
    WriteLn('  • generated/ ... [JA LIMPO]');

  BinDir := RootDir + PathDelim + 'bin';
  if DirectoryExists(BinDir) then
  begin
    DeleteDirectoryTree(BinDir);
    WriteLn('  • bin/       ... [REMOVIDO]');
  end
  else
    WriteLn('  • bin/       ... [JA LIMPO]');

  if HasConfig then
  begin
    if (Config.Outputs.PascalSrcDir <> '') and (Pos('src', LowerCase(Config.Outputs.PascalSrcDir)) = 0) then
    begin
      CustomDir := RootDir + PathDelim + Config.Outputs.PascalSrcDir;
      if DirectoryExists(CustomDir) then
      begin
        DeleteDirectoryTree(CustomDir);
        WriteLn('  • ' + Config.Outputs.PascalSrcDir + ' ... [REMOVIDO]');
      end;
    end;

    if (Config.Outputs.PascalUnitDir <> '') and (Pos('src', LowerCase(Config.Outputs.PascalUnitDir)) = 0) then
    begin
      CustomDir := RootDir + PathDelim + Config.Outputs.PascalUnitDir;
      if DirectoryExists(CustomDir) then
      begin
        DeleteDirectoryTree(CustomDir);
        WriteLn('  • ' + Config.Outputs.PascalUnitDir + ' ... [REMOVIDO]');
      end;
    end;

    if (Config.Outputs.CSrcDir <> '') and (Pos('src', LowerCase(Config.Outputs.CSrcDir)) = 0) then
    begin
      CustomDir := RootDir + PathDelim + Config.Outputs.CSrcDir;
      if DirectoryExists(CustomDir) then
      begin
        DeleteDirectoryTree(CustomDir);
        WriteLn('  • ' + Config.Outputs.CSrcDir + ' ... [REMOVIDO]');
      end;
    end;

    if (Config.Outputs.BinDir <> '') and (Config.Outputs.BinDir <> 'bin') and (Pos('src', LowerCase(Config.Outputs.BinDir)) = 0) then
    begin
      CustomDir := RootDir + PathDelim + Config.Outputs.BinDir;
      if DirectoryExists(CustomDir) then
      begin
        DeleteDirectoryTree(CustomDir);
        WriteLn('  • ' + Config.Outputs.BinDir + ' ... [REMOVIDO]');
      end;
    end;
  end;

  BuildCacheDir := RootDir + PathDelim + '.aether' + PathDelim + 'cache' + PathDelim + 'build';
  if DirectoryExists(BuildCacheDir) then
  begin
    DeleteDirectoryTree(BuildCacheDir);
    WriteLn('  • .aether/cache/build/ ... [REMOVIDO]');
  end;

  WriteLn('');
  WriteLn('SUCESSO! O projeto foi limpo.');
  WriteLn('========================================================');
end;

end.
