unit uDelSafeUpgrade;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Process, fpjson, jsonparser,
  uDelSafeIncremental, uDelSafeRegistry;

type
  TUpgradeOptions = record
    CheckOnly: Boolean;
    FromSource: Boolean;
    BinaryMode: Boolean;
    Rollback: Boolean;
    DryRun: Boolean;
    Nightly: Boolean;
    AllowUnsigned: Boolean;
    NoStdUpdate: Boolean;
    Channel: string;
    TargetVersion: string;
    CustomUrl: string;
  end;

  { TDelSafeUpgrade }
  TDelSafeUpgrade = class
  public
    class function CopyFileStream(const SrcPath, DstPath: string): Boolean;
    class function CopyDirectoryRecursive(const SrcDir, DstDir: string): Boolean;
    class function DeleteDirectoryRecursive(const DirPath: string): Boolean;
    class procedure EnsureExecutableBit(const FilePath: string);
    class function FindStdDirForExe(const ExePath: string): string;
    class function FileUrlToLocalPath(const Url: string): string;
    class function FetchUrlText(const Url: string; var OutText: string): Integer;
    class function DownloadUrlToFile(const Url, DstFile: string): Boolean;
    class procedure SaveUpdateCheckCache(const LatestTag: string);
    class function RunProcessWithOutput(const Executable, Params: string; var OutputLog: string): Integer;
    class function RunCommandStream(const CommandLineStr: string): Integer;
    class function DetectPlatform(out OSName, ArchName: string): Boolean;
    class function GetCurrentExePath: string;
    class function FindGitRoot: string;
    class function FetchReleaseMetadata(const Repo, VersionTag, CustomUrl: string;
      Nightly: Boolean;
      out TagName, ReleaseNotes, AssetUrl, AssetName, ChecksumUrl, ChecksumValue: string;
      out ErrorMsg: string): Boolean;
    class procedure HandleRollback(const ExePath: string; DryRun: Boolean);
    class procedure HandleSourceUpgrade(const GitDir: string; const Opts: TUpgradeOptions);
    class procedure HandleBinaryUpgrade(const ExePath: string; const Opts: TUpgradeOptions);
    class procedure ExecuteUpgrade(const Opts: TUpgradeOptions);
    class function IsValidChannel(const ChannelName: string): Boolean;
    class function GetDelSafeConfigDir: string;
    class function GetConfigFilePath: string;
    class function GetConfiguredChannel(out SourceLabel: string): string; overload;
    class function GetConfiguredChannel: string; overload;
    class function SetConfiguredChannel(const NewChannel: string; out ErrorMsg: string): Boolean;
    class procedure HandleChannelCommand(const Action, Value: string);
  end;

implementation

{ TDelSafeUpgrade }

class function TDelSafeUpgrade.CopyFileStream(const SrcPath, DstPath: string): Boolean;
var
  SrcStream, DstStream: TFileStream;
begin
  Result := False;
  try
    if ExtractFileDir(DstPath) <> '' then
      ForceDirectories(ExtractFileDir(DstPath));
    SrcStream := TFileStream.Create(SrcPath, fmOpenRead or fmShareDenyWrite);
    try
      DstStream := TFileStream.Create(DstPath, fmCreate);
      try
        DstStream.CopyFrom(SrcStream, SrcStream.Size);
        Result := True;
      finally
        DstStream.Free;
      end;
    finally
      SrcStream.Free;
    end;
  except
    Result := False;
  end;
end;

class function TDelSafeUpgrade.CopyDirectoryRecursive(const SrcDir, DstDir: string): Boolean;
var
  SR: TSearchRec;
  SrcItem, DstItem: string;
begin
  Result := True;
  if not DirectoryExists(SrcDir) then Exit(False);
  if not ForceDirectories(DstDir) then Exit(False);

  if SysUtils.FindFirst(IncludeTrailingPathDelimiter(SrcDir) + '*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        SrcItem := IncludeTrailingPathDelimiter(SrcDir) + SR.Name;
        DstItem := IncludeTrailingPathDelimiter(DstDir) + SR.Name;
        if (SR.Attr and faDirectory) <> 0 then
        begin
          if not CopyDirectoryRecursive(SrcItem, DstItem) then
            Result := False;
        end
        else
        begin
          if not CopyFileStream(SrcItem, DstItem) then
            Result := False;
        end;
      until SysUtils.FindNext(SR) <> 0;
    finally
      SysUtils.FindClose(SR);
    end;
  end;
end;

class function TDelSafeUpgrade.DeleteDirectoryRecursive(const DirPath: string): Boolean;
var
  SR: TSearchRec;
  ItemPath, CurrentExe: string;
begin
  Result := True;
  if not DirectoryExists(DirPath) then Exit(True);
  CurrentExe := ExpandFileName(GetCurrentExePath);
  if SysUtils.FindFirst(IncludeTrailingPathDelimiter(DirPath) + '*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        ItemPath := IncludeTrailingPathDelimiter(DirPath) + SR.Name;
        if (SR.Attr and faDirectory) <> 0 then
        begin
          if not DeleteDirectoryRecursive(ItemPath) then
            Result := False;
        end
        else
        begin
          if not SameText(ExpandFileName(ItemPath), CurrentExe) then
          begin
            if not DeleteFile(ItemPath) then
              Result := False;
          end;
        end;
      until SysUtils.FindNext(SR) <> 0;
    finally
      SysUtils.FindClose(SR);
    end;
  end;
  if not RemoveDir(DirPath) then
    Result := False;
end;

class procedure TDelSafeUpgrade.EnsureExecutableBit(const FilePath: string);
{$IFNDEF MSWINDOWS}
var
  LogText: string;
{$ENDIF}
begin
  {$IFNDEF MSWINDOWS}
  if FileExists(FilePath) then
    RunProcessWithOutput('chmod', '+x "' + FilePath + '"', LogText);
  {$ENDIF}
end;

class function TDelSafeUpgrade.FindStdDirForExe(const ExePath: string): string;
var
  ExeDir, CandidateA, CandidateB: string;
begin
  ExeDir := ExtractFileDir(ExpandFileName(ExePath));
  CandidateA := ExpandFileName(ExeDir + PathDelim + '..' + PathDelim + 'std');
  CandidateB := ExeDir + PathDelim + 'std';
  if DirectoryExists(CandidateA) then
    Exit(CandidateA);
  if DirectoryExists(CandidateB) then
    Exit(CandidateB);
  Result := CandidateA;
end;

class function TDelSafeUpgrade.FileUrlToLocalPath(const Url: string): string;
var
  Raw: string;
begin
  Raw := Trim(Url);
  if Pos('file://', LowerCase(Raw)) <> 1 then Exit(Raw);
  Delete(Raw, 1, 7);
  {$IFDEF MSWINDOWS}
  while (Length(Raw) > 2) and (Raw[1] = '/') and (Raw[3] = ':') do
    Delete(Raw, 1, 1);
  if (Length(Raw) >= 2) and (Raw[1] = '/') and (Raw[2] <> '/') then
    Delete(Raw, 1, 1);
  Raw := StringReplace(Raw, '/', '\', [rfReplaceAll]);
  {$ENDIF}
  Raw := StringReplace(Raw, '%20', ' ', [rfReplaceAll]);
  Result := Raw;
end;

class function TDelSafeUpgrade.FetchUrlText(const Url: string; var OutText: string): Integer;
var
  LocalPath, CurlCmd: string;
  FS: TFileStream;
  SS: TStringStream;
begin
  OutText := '';
  if Pos('file://', LowerCase(Trim(Url))) = 1 then
  begin
    LocalPath := FileUrlToLocalPath(Url);
    if not FileExists(LocalPath) then
    begin
      OutText := 'Local file not found: ' + LocalPath;
      Exit(1);
    end;
    FS := TFileStream.Create(LocalPath, fmOpenRead or fmShareDenyWrite);
    SS := TStringStream.Create('');
    try
      SS.CopyFrom(FS, FS.Size);
      OutText := Trim(SS.DataString);
      Exit(0);
    finally
      SS.Free;
      FS.Free;
    end;
  end;

  CurlCmd := Format('-sL -H "User-Agent: DelSafe-Upgrader" -H "Accept: application/vnd.github.v3+json" "%s"', [Url]);
  Result := RunProcessWithOutput('curl', CurlCmd, OutText);
end;

class function TDelSafeUpgrade.DownloadUrlToFile(const Url, DstFile: string): Boolean;
var
  LocalPath, CurlCmd: string;
begin
  if Pos('file://', LowerCase(Trim(Url))) = 1 then
  begin
    LocalPath := FileUrlToLocalPath(Url);
    Exit(CopyFileStream(LocalPath, DstFile));
  end;

  if ExtractFileDir(DstFile) <> '' then
    ForceDirectories(ExtractFileDir(DstFile));
  CurlCmd := Format('-sL -H "User-Agent: DelSafe-Upgrader" -o "%s" "%s"', [DstFile, Url]);
  Result := (RunCommandStream('curl ' + CurlCmd) = 0) and FileExists(DstFile);
end;

class function TDelSafeUpgrade.GetDelSafeConfigDir: string;
var
  HomeDir: string;
begin
  {$IFDEF MSWINDOWS}
  HomeDir := SysUtils.GetEnvironmentVariable('USERPROFILE');
  if HomeDir = '' then HomeDir := SysUtils.GetEnvironmentVariable('APPDATA');
  {$ELSE}
  HomeDir := SysUtils.GetEnvironmentVariable('HOME');
  {$ENDIF}
  if HomeDir = '' then
    Result := ''
  else
    Result := IncludeTrailingPathDelimiter(HomeDir) + '.delsafe';
end;

class function TDelSafeUpgrade.GetConfigFilePath: string;
var
  ConfigDir: string;
begin
  ConfigDir := GetDelSafeConfigDir;
  if ConfigDir = '' then
    Result := ''
  else
    Result := ConfigDir + PathDelim + 'config.json';
end;

class function TDelSafeUpgrade.IsValidChannel(const ChannelName: string): Boolean;
var
  Norm: string;
begin
  Norm := LowerCase(Trim(ChannelName));
  Result := (Norm = 'stable') or (Norm = 'nightly');
end;

class function TDelSafeUpgrade.GetConfiguredChannel(out SourceLabel: string): string;
var
  EnvVal, ConfigPath, FileVal: string;
  SL: TStringList;
  JSON: TJSONData;
  Obj: TJSONObject;
begin
  Result := 'stable';
  SourceLabel := 'default';

  EnvVal := LowerCase(Trim(SysUtils.GetEnvironmentVariable('DELSAFE_CHANNEL')));
  if (EnvVal <> '') and IsValidChannel(EnvVal) then
  begin
    Result := EnvVal;
    SourceLabel := 'env (DELSAFE_CHANNEL)';
    Exit;
  end;

  ConfigPath := GetConfigFilePath;
  if (ConfigPath <> '') and FileExists(ConfigPath) then
  begin
    SL := TStringList.Create;
    JSON := nil;
    try
      try
        SL.LoadFromFile(ConfigPath);
        JSON := GetJSON(SL.Text);
        if (JSON <> nil) and (JSON.JSONType = jtObject) then
        begin
          Obj := TJSONObject(JSON);
          FileVal := LowerCase(Trim(Obj.Get('channel', '')));
          if IsValidChannel(FileVal) then
          begin
            Result := FileVal;
            SourceLabel := ConfigPath;
          end;
        end;
      except
        // Malformed config.json falls back cleanly to default
      end;
    finally
      JSON.Free;
      SL.Free;
    end;
  end;
end;

class function TDelSafeUpgrade.GetConfiguredChannel: string;
var
  DummySource: string;
begin
  Result := GetConfiguredChannel(DummySource);
end;

class function TDelSafeUpgrade.SetConfiguredChannel(const NewChannel: string; out ErrorMsg: string): Boolean;
var
  Norm, ConfigDir, ConfigPath: string;
  SL: TStringList;
  JSON: TJSONData;
  Obj: TJSONObject;
  Idx: Integer;
begin
  Result := False;
  ErrorMsg := '';
  Norm := LowerCase(Trim(NewChannel));

  if not IsValidChannel(Norm) then
  begin
    ErrorMsg := Format('Invalid channel "%s". Valid channels: stable, nightly.', [NewChannel]);
    Exit;
  end;

  ConfigDir := GetDelSafeConfigDir;
  ConfigPath := GetConfigFilePath;
  if (ConfigDir = '') or (ConfigPath = '') then
  begin
    ErrorMsg := 'Could not determine user home directory for ~/.delsafe/config.json.';
    Exit;
  end;

  if not ForceDirectories(ConfigDir) then
  begin
    ErrorMsg := Format('Could not create configuration directory "%s".', [ConfigDir]);
    Exit;
  end;

  Obj := nil;
  JSON := nil;
  SL := TStringList.Create;
  try
    if FileExists(ConfigPath) then
    begin
      try
        SL.LoadFromFile(ConfigPath);
        JSON := GetJSON(SL.Text);
        if (JSON <> nil) and (JSON.JSONType = jtObject) then
          Obj := TJSONObject(JSON)
        else
        begin
          JSON.Free;
          JSON := nil;
        end;
      except
        JSON.Free;
        JSON := nil;
      end;
    end;

    if Obj = nil then
      Obj := TJSONObject.Create;

    Idx := Obj.IndexOfName('channel');
    if Idx >= 0 then
      Obj.Delete(Idx);
    Obj.Add('channel', Norm);

    SL.Text := Obj.FormatJSON;
    SL.SaveToFile(ConfigPath);
    Result := True;
  except
    on E: Exception do
    begin
      ErrorMsg := E.Message;
      Result := False;
    end;
  end;
  if JSON <> nil then
    JSON.Free
  else if Obj <> nil then
    Obj.Free;
  SL.Free;
end;

class procedure TDelSafeUpgrade.HandleChannelCommand(const Action, Value: string);
var
  CurChan, SourceLabel, ConfigPath, TargetChan, ErrorMsg: string;
begin
  if (Action = '-h') or (Action = '--help') or SameText(Action, 'help') then
  begin
    WriteLn('Usage: delsafec channel [stable | nightly | show | set <name>]');
    WriteLn('');
    WriteLn('Manage the default release channel persisted in ~/.delsafe/config.json.');
    WriteLn('');
    WriteLn('Subcommands:');
    WriteLn('  (none), show      Display the active release channel and available channels');
    WriteLn('  stable            Switch default channel to stable (SemVer tags v*.*.*)');
    WriteLn('  nightly           Switch default channel to nightly (weekly builds from main)');
    WriteLn('  set <name>        Explicitly set the default channel (stable or nightly)');
    WriteLn('');
    WriteLn('Environment Override:');
    WriteLn('  DELSAFE_CHANNEL   Temporarily override the configured channel');
    Exit;
  end;

  if (Action = '') or SameText(Action, 'show') or SameText(Action, 'list') or SameText(Action, 'status') then
  begin
    CurChan := GetConfiguredChannel(SourceLabel);
    ConfigPath := GetConfigFilePath;
    if ConfigPath = '' then ConfigPath := '~/.delsafe/config.json';
    WriteLn('--------------------------------------------------------');
    WriteLn('  DelSafe Release Channel Configuration                 ');
    WriteLn('--------------------------------------------------------');
    WriteLn(Format('Active channel : %s (source: %s)', [CurChan, SourceLabel]));
    WriteLn(Format('Config file    : %s', [ConfigPath]));
    WriteLn('');
    WriteLn('Available channels:');
    if CurChan = 'stable' then
      WriteLn('  * stable   - Official SemVer releases (v*.*.*)')
    else
      WriteLn('    stable   - Official SemVer releases (v*.*.*)');
    if CurChan = 'nightly' then
      WriteLn('  * nightly  - Weekly development pre-releases built from main')
    else
      WriteLn('    nightly  - Weekly development pre-releases built from main');
    WriteLn('');
    WriteLn('To switch channels: delsafec channel <stable|nightly>');
    Exit;
  end;

  if SameText(Action, 'set') or SameText(Action, 'use') then
  begin
    if Trim(Value) = '' then
    begin
      WriteLn(ErrOutput, 'Error: Missing channel name. Usage: delsafec channel set <stable|nightly>');
      Halt(1);
    end;
    TargetChan := Value;
  end
  else
    TargetChan := Action;

  if not SetConfiguredChannel(TargetChan, ErrorMsg) then
  begin
    WriteLn(ErrOutput, 'Error: ' + ErrorMsg);
    Halt(1);
  end;

  CurChan := LowerCase(Trim(TargetChan));
  ConfigPath := GetConfigFilePath;
  WriteLn(Format('Active update channel set to: %s', [CurChan]));
  if ConfigPath <> '' then
    WriteLn(Format('Saved configuration to: %s', [ConfigPath]));
  WriteLn(Format('Run "delsafec upgrade" to update from the %s channel.', [CurChan]));
end;

class procedure TDelSafeUpgrade.SaveUpdateCheckCache(const LatestTag: string);
var
  DelSafeDir, CacheFile: string;
  Obj: TJSONObject;
  SL: TStringList;
begin
  if SysUtils.GetEnvironmentVariable('DELSAFE_NO_UPDATE_CHECK') = '1' then Exit;
  DelSafeDir := GetDelSafeConfigDir;
  if DelSafeDir = '' then Exit;
  try
    ForceDirectories(DelSafeDir);
    CacheFile := DelSafeDir + PathDelim + 'update_check.json';
    Obj := TJSONObject.Create;
    SL := TStringList.Create;
    try
      Obj.Add('checked_at', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now));
      Obj.Add('installed_version', DELSAFE_COMPILER_VERSION);
      Obj.Add('latest_tag', LatestTag);
      SL.Text := Obj.FormatJSON;
      SL.SaveToFile(CacheFile);
    finally
      SL.Free;
      Obj.Free;
    end;
  except
    // Non-fatal metadata cache write
  end;
end;

class function TDelSafeUpgrade.RunProcessWithOutput(const Executable, Params: string; var OutputLog: string): Integer;
var
  Proc: TProcess;
  Buffer: array[0..4095] of Byte;
  BytesRead: LongInt;
  StringStream: TStringStream;
begin
  Result := -1;
  OutputLog := '';
  Proc := TProcess.Create(nil);
  StringStream := TStringStream.Create('');
  try
    Proc.Executable := Executable;
    {$PUSH}{$WARN 5044 OFF}
    Proc.CommandLine := '"' + Executable + '" ' + Params;
    {$POP}
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

class function TDelSafeUpgrade.RunCommandStream(const CommandLineStr: string): Integer;
var
  Proc: TProcess;
  Buffer: array[0..2047] of Byte;
  BytesRead: LongInt;
  LineChunk: string;
begin
  Result := -1;
  Proc := TProcess.Create(nil);
  try
    {$PUSH}{$WARN 5044 OFF}
    Proc.CommandLine := CommandLineStr;
    {$POP}
    Proc.Options := [poUsePipes, poStderrToOutPut];
    Proc.ShowWindow := swoNone;
    try
      Proc.Execute;
      while Proc.Running or (Proc.Output.NumBytesAvailable > 0) do
      begin
        if Proc.Output.NumBytesAvailable > 0 then
        begin
          BytesRead := Proc.Output.Read(Buffer[0], SizeOf(Buffer) - 1);
          if BytesRead > 0 then
          begin
            Buffer[BytesRead] := 0;
            SetString(LineChunk, PAnsiChar(@Buffer[0]), BytesRead);
            Write(LineChunk);
          end;
        end
        else
          Sleep(15);
      end;
      Result := Proc.ExitStatus;
    except
      on E: Exception do
      begin
        WriteLn(ErrOutput, 'Error executing command: ', E.Message);
        Result := -1;
      end;
    end;
  finally
    Proc.Free;
  end;
end;

class function TDelSafeUpgrade.DetectPlatform(out OSName, ArchName: string): Boolean;
begin
  {$IFDEF MSWINDOWS}
  OSName := 'windows';
  {$ELSE}
    {$IFDEF DARWIN}
    OSName := 'macos';
    {$ELSE}
    OSName := 'linux';
    {$ENDIF}
  {$ENDIF}

  {$IFDEF CPUX86_64}
  ArchName := 'x86_64';
  {$ELSE}
    {$IFDEF CPUAARCH64}
    ArchName := 'aarch64';
    {$ELSE}
      {$IFDEF CPUARM}
      ArchName := 'arm';
      {$ELSE}
      ArchName := 'x86';
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}

  Result := True;
end;

class function TDelSafeUpgrade.GetCurrentExePath: string;
begin
  Result := ParamStr(0);
  if not FileExists(Result) then
    Result := GetCurrentDir + PathDelim + ExtractFileName(ParamStr(0));
  Result := ExpandFileName(Result);
end;

class function TDelSafeUpgrade.FindGitRoot: string;
var
  CurDir, ParentDir: string;
begin
  Result := '';
  CurDir := GetCurrentDir;
  while CurDir <> '' do
  begin
    if DirectoryExists(CurDir + PathDelim + '.git') or FileExists(CurDir + PathDelim + '.git') then
      Exit(CurDir);
    ParentDir := ExtractFileDir(CurDir);
    if (ParentDir = '') or (ParentDir = CurDir) then Break;
    CurDir := ParentDir;
  end;
end;

function SelectReleaseObject(JsonData: TJSONData; Nightly: Boolean): TJSONObject;
var
  Arr: TJSONArray;
  Candidate: TJSONObject;
  I: Integer;
  TagLower: string;
begin
  Result := nil;
  if JsonData is TJSONObject then
    Exit(TJSONObject(JsonData));
  if JsonData is TJSONArray then
  begin
    Arr := TJSONArray(JsonData);
    if Arr.Count = 0 then Exit(nil);
    if Nightly then
    begin
      for I := 0 to Arr.Count - 1 do
      begin
        if Arr.Items[I] is TJSONObject then
        begin
          Candidate := TJSONObject(Arr.Items[I]);
          TagLower := LowerCase(Candidate.Get('tag_name', ''));
          if Candidate.Get('prerelease', False) or (Pos('nightly', TagLower) > 0) then
            Exit(Candidate);
        end;
      end;
    end;
    if Arr.Items[0] is TJSONObject then
      Result := TJSONObject(Arr.Items[0]);
  end;
end;

function MatchesChecksumName(const CurName: string): Boolean;
begin
  Result := (Pos('.sha256', CurName) > 0) or (Pos('checksum', CurName) > 0) or
            (Pos('sha256sums', CurName) > 0);
end;

function FindExtractedStdDir(const ExtractDir: string): string;
var
  SR: TSearchRec;
  SubDir: string;
begin
  Result := '';
  if DirectoryExists(ExtractDir + PathDelim + 'std') then
    Exit(ExtractDir + PathDelim + 'std');
  if SysUtils.FindFirst(IncludeTrailingPathDelimiter(ExtractDir) + '*', faDirectory, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') or ((SR.Attr and faDirectory) = 0) then Continue;
        SubDir := IncludeTrailingPathDelimiter(ExtractDir) + SR.Name;
        if DirectoryExists(SubDir + PathDelim + 'std') then
          Exit(SubDir + PathDelim + 'std');
      until SysUtils.FindNext(SR) <> 0;
    finally
      SysUtils.FindClose(SR);
    end;
  end;
end;

function FindExtractedExe(const ExtractDir: string): string;
var
  SR: TSearchRec;
  SubDir, ExeBase: string;
begin
  {$IFDEF MSWINDOWS}
  ExeBase := 'delsafec.exe';
  {$ELSE}
  ExeBase := 'delsafec';
  {$ENDIF}
  if FileExists(ExtractDir + PathDelim + ExeBase) then
    Exit(ExtractDir + PathDelim + ExeBase);
  if FileExists(ExtractDir + PathDelim + 'bin' + PathDelim + ExeBase) then
    Exit(ExtractDir + PathDelim + 'bin' + PathDelim + ExeBase);

  if SysUtils.FindFirst(IncludeTrailingPathDelimiter(ExtractDir) + '*', faDirectory, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') or ((SR.Attr and faDirectory) = 0) then Continue;
        SubDir := IncludeTrailingPathDelimiter(ExtractDir) + SR.Name;
        if FileExists(SubDir + PathDelim + ExeBase) then
          Exit(SubDir + PathDelim + ExeBase);
        if FileExists(SubDir + PathDelim + 'bin' + PathDelim + ExeBase) then
          Exit(SubDir + PathDelim + 'bin' + PathDelim + ExeBase);
      until SysUtils.FindNext(SR) <> 0;
    finally
      SysUtils.FindClose(SR);
    end;
  end;
  Result := '';
end;

function VerifySha256TextMatchesAsset(const ChecksumText, HashLower, AssetName: string): Boolean;
var
  Lines: TStringList;
  I: Integer;
  Line, LowLine, LowAsset: string;
begin
  Result := False;
  LowAsset := LowerCase(ExtractFileName(AssetName));
  Lines := TStringList.Create;
  try
    Lines.Text := ChecksumText;
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[I]);
      if Line = '' then Continue;
      LowLine := LowerCase(Line);
      if (Pos(LowAsset, LowLine) > 0) and (Pos(HashLower, LowLine) > 0) then
        Exit(True);
    end;
    // Also support single-line "<hash>" .sha256 files without filename
    if (Lines.Count = 1) and (Pos(HashLower, LowerCase(Lines[0])) > 0) then
      Result := True;
  finally
    Lines.Free;
  end;
end;

class function TDelSafeUpgrade.FetchReleaseMetadata(const Repo, VersionTag, CustomUrl: string;
  Nightly: Boolean;
  out TagName, ReleaseNotes, AssetUrl, AssetName, ChecksumUrl, ChecksumValue: string;
  out ErrorMsg: string): Boolean;
var
  TargetUrl, OutputLog: string;
  ExitCode, I: Integer;
  JsonData, AssetsData, ItemData: TJSONData;
  RootObj, AssetObj: TJSONObject;
  OSName, ArchName, CurName, CurDownloadUrl, SpecificSumUrl: string;
  FoundAsset, ArchMatch: Boolean;
begin
  Result := False;
  ErrorMsg := '';
  TagName := '';
  ReleaseNotes := '';
  AssetUrl := '';
  AssetName := '';
  ChecksumUrl := '';
  ChecksumValue := '';
  SpecificSumUrl := '';

  DetectPlatform(OSName, ArchName);

  if CustomUrl <> '' then
    TargetUrl := CustomUrl
  else if VersionTag <> '' then
    TargetUrl := Format('https://api.github.com/repos/%s/releases/tags/%s', [Repo, VersionTag])
  else if Nightly then
    TargetUrl := Format('https://api.github.com/repos/%s/releases?per_page=10', [Repo])
  else
    TargetUrl := Format('https://api.github.com/repos/%s/releases/latest', [Repo]);

  ExitCode := FetchUrlText(TargetUrl, OutputLog);

  if ExitCode <> 0 then
  begin
    ErrorMsg := 'Failed to connect to release servers (exit code ' + IntToStr(ExitCode) + '). ' +
                'Check your network connection or use "delsafec upgrade --from-source". Log: ' + OutputLog;
    Exit(False);
  end;

  if (OutputLog = '') or ((Pos('{', OutputLog) = 0) and (Pos('[', OutputLog) = 0)) then
  begin
    ErrorMsg := 'Unexpected response from release server. Log: ' + OutputLog;
    Exit(False);
  end;

  try
    JsonData := GetJSON(OutputLog);
  except
    on E: Exception do
    begin
      ErrorMsg := 'Failed to parse release JSON metadata: ' + E.Message;
      Exit(False);
    end;
  end;

  try
    RootObj := SelectReleaseObject(JsonData, Nightly);
    if not Assigned(RootObj) then
    begin
      ErrorMsg := 'No matching release entry found in metadata response.';
      Exit(False);
    end;

    // Check for GitHub API error message (e.g., 404 Not Found, Rate limit exceeded)
    if RootObj.IndexOfName('message') >= 0 then
    begin
      ErrorMsg := 'GitHub API: ' + RootObj.Get('message', 'Unknown error');
      Exit(False);
    end;

    TagName := RootObj.Get('tag_name', '');
    ReleaseNotes := RootObj.Get('body', '');

    FoundAsset := False;
    AssetsData := RootObj.FindPath('assets');
    if (AssetsData <> nil) and (AssetsData is TJSONArray) then
    begin
      for I := 0 to TJSONArray(AssetsData).Count - 1 do
      begin
        ItemData := TJSONArray(AssetsData).Items[I];
        if ItemData is TJSONObject then
        begin
          AssetObj := TJSONObject(ItemData);
          CurName := LowerCase(AssetObj.Get('name', ''));
          CurDownloadUrl := AssetObj.Get('browser_download_url', '');

          if MatchesChecksumName(CurName) then
          begin
            if (Pos(OSName, CurName) > 0) and (Pos(ArchName, CurName) > 0) then
              SpecificSumUrl := CurDownloadUrl
            else if (Pos(OSName, CurName) > 0) and (SpecificSumUrl = '') then
              SpecificSumUrl := CurDownloadUrl
            else if ChecksumUrl = '' then
              ChecksumUrl := CurDownloadUrl;
          end
          else if (Pos(OSName, CurName) > 0) and
                  (Pos('.sig', CurName) = 0) and
                  (Pos('.asc', CurName) = 0) then
          begin
            ArchMatch := (Pos(ArchName, CurName) > 0) or
                         ((ArchName = 'x86_64') and ((Pos('x64', CurName) > 0) or (Pos('amd64', CurName) > 0))) or
                         ((ArchName = 'aarch64') and (Pos('arm64', CurName) > 0));
            if ArchMatch then
            begin
              AssetName := AssetObj.Get('name', '');
              AssetUrl := CurDownloadUrl;
              FoundAsset := True;
            end;
          end;
        end;
      end;
    end;

    if SpecificSumUrl <> '' then
      ChecksumUrl := SpecificSumUrl;
  finally
    JsonData.Free;
  end;

  if not FoundAsset and (AssetUrl = '') then
  begin
    ErrorMsg := Format('No binary package compatible with platform (%s-%s) was found in release %s.',
      [OSName, ArchName, TagName]);
    Exit(False);
  end;

  Result := True;
end;

class procedure TDelSafeUpgrade.HandleRollback(const ExePath: string; DryRun: Boolean);
var
  BakPath, PrevPath, StdDir, StdBak, StdFailed, OutputLog: string;
begin
  BakPath := ExePath + '.bak';
  PrevPath := ExePath + '.prev';

  if not FileExists(BakPath) and FileExists(PrevPath) then
    BakPath := PrevPath;

  if not FileExists(BakPath) then
  begin
    WriteLn(ErrOutput, Format('Error: No previous version backup found at "%s".', [BakPath]));
    WriteLn(ErrOutput, 'Rollback is only available after a previously successful update.');
    Halt(1);
  end;

  StdDir := FindStdDirForExe(ExePath);
  StdBak := StdDir + '.bak';

  WriteLn('==> Starting DelSafe toolchain rollback...');
  WriteLn(Format('    Current executable: %s', [ExePath]));
  WriteLn(Format('    Previous backup   : %s', [BakPath]));
  if DirectoryExists(StdBak) then
    WriteLn(Format('    Stdlib backup     : %s', [StdBak]));

  if DryRun then
  begin
    WriteLn('');
    WriteLn('[DRY-RUN] No changes were written to disk.');
    WriteLn(Format('[DRY-RUN] File "%s" would be restored as "%s".', [BakPath, ExePath]));
    if DirectoryExists(StdBak) then
      WriteLn(Format('[DRY-RUN] Directory "%s" would be restored as "%s".', [StdBak, StdDir]));
    Exit;
  end;

  if FileExists(ExePath + '.failed') then
    DeleteFile(ExePath + '.failed');

  if not RenameFile(ExePath, ExePath + '.failed') then
  begin
    WriteLn(ErrOutput, 'Error: Failed to move current executable to temporary backup.');
    Halt(1);
  end;

  if not RenameFile(BakPath, ExePath) then
  begin
    RenameFile(ExePath + '.failed', ExePath);
    WriteLn(ErrOutput, 'Critical error: Failed to restore previous backup.');
    Halt(1);
  end;

  EnsureExecutableBit(ExePath);
  DeleteFile(ExePath + '.failed');

  if DirectoryExists(StdBak) then
  begin
    StdFailed := StdDir + '.failed';
    if DirectoryExists(StdFailed) then
      DeleteDirectoryRecursive(StdFailed);
    if DirectoryExists(StdDir) then
      RenameFile(StdDir, StdFailed);
    if not RenameFile(StdBak, StdDir) then
    begin
      if DirectoryExists(StdFailed) then RenameFile(StdFailed, StdDir);
      WriteLn('Warning: Failed to restore stdlib backup from ', StdBak);
    end
    else
      DeleteDirectoryRecursive(StdFailed);
  end;

  if (RunProcessWithOutput(ExePath, '--version', OutputLog) = 0) or
     (RunProcessWithOutput(ExePath, '-h', OutputLog) = 0) then
  begin
    WriteLn('');
    WriteLn('========================================================');
    WriteLn('  [SUCCESS] Rollback completed successfully!            ');
    WriteLn('  The previous toolchain version has been restored.      ');
    WriteLn('========================================================');
  end
  else
  begin
    WriteLn('');
    WriteLn('Warning: Restored binary returned a non-zero exit code.');
  end;
end;

class procedure TDelSafeUpgrade.HandleSourceUpgrade(const GitDir: string; const Opts: TUpgradeOptions);
var
  Cmd, OutputLog, TargetBranch, CurExe, TargetExe, BakExe: string;
  ExitCode: Integer;
  IsWindows, MovedRunningExe: Boolean;
begin
  WriteLn('========================================================');
  WriteLn('  DelSafe Update via Source Code (Source Build)          ');
  WriteLn('========================================================');
  WriteLn(Format('Git repository detected: %s', [GitDir]));

  if Opts.DryRun then
  begin
    WriteLn('');
    WriteLn('[DRY-RUN] Commands that would be executed:');
    WriteLn('  1. git -C "' + GitDir + '" fetch --tags --all');
    if Opts.TargetVersion <> '' then
      WriteLn('  2. git -C "' + GitDir + '" checkout ' + Opts.TargetVersion)
    else
      WriteLn('  2. git -C "' + GitDir + '" pull origin main');
    {$IFDEF MSWINDOWS}
    WriteLn('  3. Backup running bin\delsafec.exe -> bin\delsafec.exe.bak and run build.ps1');
    WriteLn('  4. .\bin\delsafec.exe test --target=all');
    {$ELSE}
    WriteLn('  3. ./build.sh');
    WriteLn('  4. ./bin/delsafec test --target=all');
    {$ENDIF}
    Exit;
  end;

  // 1. Git Fetch
  WriteLn('');
  WriteLn('-> [1/4] Fetching remote updates and tags via Git...');
  ExitCode := RunProcessWithOutput('git', Format('-C "%s" fetch --tags --all', [GitDir]), OutputLog);
  if ExitCode <> 0 then
  begin
    WriteLn(ErrOutput, 'Error running git fetch: ' + OutputLog);
    Halt(1);
  end;

  // 2. Checkout / Pull
  if Opts.TargetVersion <> '' then
  begin
    WriteLn(Format('-> [2/4] Updating to specific version/tag: %s...', [Opts.TargetVersion]));
    ExitCode := RunProcessWithOutput('git', Format('-C "%s" checkout %s', [GitDir, Opts.TargetVersion]), OutputLog);
  end
  else
  begin
    WriteLn('-> [2/4] Pulling latest code from main branch...');
    TargetBranch := 'main';
    ExitCode := RunProcessWithOutput('git', Format('-C "%s" pull origin %s', [GitDir, TargetBranch]), OutputLog);
    if ExitCode <> 0 then
    begin
      TargetBranch := 'master';
      ExitCode := RunProcessWithOutput('git', Format('-C "%s" pull origin %s', [GitDir, TargetBranch]), OutputLog);
    end;
  end;

  if ExitCode <> 0 then
  begin
    WriteLn(ErrOutput, 'Error syncing Git branch/tag: ' + OutputLog);
    Halt(1);
  end;
  WriteLn('   Git synchronized successfully.');

  // 3. Rebuild compiler (move running exe to .bak on Windows to avoid linker lock)
  WriteLn('');
  WriteLn('-> [3/4] Rebuilding the DelSafe compiler (delsafec)...');
  MovedRunningExe := False;
  CurExe := GetCurrentExePath;
  {$IFDEF MSWINDOWS}
  IsWindows := True;
  TargetExe := ExpandFileName(GitDir + PathDelim + 'bin' + PathDelim + 'delsafec.exe');
  BakExe := TargetExe + '.bak';
  if SameText(CurExe, TargetExe) and FileExists(TargetExe) then
  begin
    if FileExists(BakExe) then DeleteFile(BakExe);
    if RenameFile(TargetExe, BakExe) then
      MovedRunningExe := True;
  end;
  if FileExists(GitDir + PathDelim + 'build.ps1') then
    Cmd := Format('powershell -ExecutionPolicy Bypass -NoProfile -File "%s%sbuild.ps1"', [GitDir, PathDelim])
  else
    Cmd := Format('fpc -MObjFPC -Sc -O2 -FE"%s%sbin" -FU"%s%sbuild" -Fu"%s%scompiler%ssrc" "%s%scompiler%sdelsafec.lpr"',
      [GitDir, PathDelim, GitDir, PathDelim, GitDir, PathDelim, PathDelim, GitDir, PathDelim, PathDelim]);
  {$ELSE}
  IsWindows := False;
  TargetExe := ExpandFileName(GitDir + PathDelim + 'bin' + PathDelim + 'delsafec');
  BakExe := TargetExe + '.bak';
  if FileExists(GitDir + PathDelim + 'build.sh') then
    Cmd := Format('sh "%s%sbuild.sh"', [GitDir, PathDelim])
  else
    Cmd := Format('fpc -MObjFPC -Sc -O2 -FE"%s%sbin" -FU"%s%sbuild" -Fu"%s%scompiler%ssrc" "%s%scompiler%sdelsafec.lpr"',
      [GitDir, PathDelim, GitDir, PathDelim, GitDir, PathDelim, PathDelim, GitDir, PathDelim, PathDelim]);
  {$ENDIF}

  ExitCode := RunCommandStream(Cmd);
  if ExitCode <> 0 then
  begin
    if MovedRunningExe and FileExists(BakExe) and not FileExists(TargetExe) then
      RenameFile(BakExe, TargetExe);
    WriteLn(ErrOutput, Format('Error compiling delsafec (exit code %d).', [ExitCode]));
    Halt(1);
  end;

  // 4. Run full dual-backend test suite with the new binary
  WriteLn('');
  WriteLn('-> [4/4] Validating new compiler against the dual-backend test suite...');
  if IsWindows then
    Cmd := Format('"%s%sbin%sdelsafec.exe" test --target=all', [GitDir, PathDelim, PathDelim])
  else
    Cmd := Format('"%s%sbin%sdelsafec" test --target=all', [GitDir, PathDelim, PathDelim]);

  ExitCode := RunCommandStream(Cmd);
  if ExitCode <> 0 then
  begin
    if MovedRunningExe and FileExists(BakExe) then
    begin
      if FileExists(TargetExe) then DeleteFile(TargetExe);
      RenameFile(BakExe, TargetExe);
    end;
    WriteLn(ErrOutput, 'Error: Test suite failed after updating; previous binary restored.');
    Halt(1);
  end;

  WriteLn('');
  WriteLn('========================================================');
  WriteLn('  [SUCCESS] DelSafe compiler updated successfully!       ');
  WriteLn('  Toolchain rebuilt and verified (FPC + C99 tests).     ');
  WriteLn('========================================================');
end;

class procedure TDelSafeUpgrade.HandleBinaryUpgrade(const ExePath: string; const Opts: TUpgradeOptions);
var
  RepoName, TagName, Notes, AssetUrl, AssetName, ChecksumUrl, ChecksumVal, ErrorMsg: string;
  TempDir, DownloadedFile, ExtractDir, NewExeCandidate, ExtractedStdDir: string;
  BakPath, StdDir, StdBak, HashCalc, TarCmd, TestLog, ChannelLabel: string;
  ExitCode: Integer;
  OSName, ArchName: string;
  IsNightly, StdUpdated: Boolean;
begin
  RepoName := SysUtils.GetEnvironmentVariable('DELSAFE_UPGRADE_REPO');
  if RepoName = '' then
    RepoName := 'affonsoelias/delsafe';

  IsNightly := Opts.Nightly or SameText(Opts.Channel, 'nightly');
  if IsNightly then ChannelLabel := 'nightly' else ChannelLabel := 'stable';

  DetectPlatform(OSName, ArchName);

  WriteLn('========================================================');
  WriteLn('  Checking for DelSafe Compiler Updates             ');
  WriteLn('========================================================');
  WriteLn(Format('Current installed version : v%s', [DELSAFE_COMPILER_VERSION]));
  WriteLn(Format('Update channel            : %s', [ChannelLabel]));
  WriteLn(Format('Detected platform         : %s-%s', [OSName, ArchName]));
  WriteLn(Format('Releases repository       : %s', [RepoName]));
  WriteLn('Fetching release metadata...');

  if not FetchReleaseMetadata(RepoName, Opts.TargetVersion, Opts.CustomUrl, IsNightly,
                              TagName, Notes, AssetUrl, AssetName, ChecksumUrl, ChecksumVal, ErrorMsg) then
  begin
    WriteLn(ErrOutput, 'Error: ' + ErrorMsg);
    Halt(1);
  end;

  SaveUpdateCheckCache(TagName);

  WriteLn('');
  WriteLn(Format('Latest version found      : %s', [TagName]));
  if AssetName <> '' then
    WriteLn(Format('Compatible package        : %s', [AssetName]));

  if (not IsNightly) and (CompareSemVer(TagName, DELSAFE_COMPILER_VERSION) <= 0) and (Opts.TargetVersion = '') then
  begin
    WriteLn('');
    WriteLn('========================================================');
    WriteLn(Format('  DelSafe is already up to date at v%s!        ', [DELSAFE_COMPILER_VERSION]));
    WriteLn('  No further action is required.                        ');
    WriteLn('========================================================');
    Exit;
  end;

  if Opts.CheckOnly then
  begin
    WriteLn('');
    WriteLn('--------------------------------------------------------');
    WriteLn(Format('New version available: %s (installed: v%s)', [TagName, DELSAFE_COMPILER_VERSION]));
    if Trim(Notes) <> '' then
    begin
      WriteLn('');
      WriteLn('Release Notes:');
      WriteLn(Copy(Notes, 1, 400));
      if Length(Notes) > 400 then WriteLn('...');
    end;
    WriteLn('--------------------------------------------------------');
    WriteLn('To update to this version now, run:');
    WriteLn('  delsafec upgrade --binary');
    Exit;
  end;

  StdDir := FindStdDirForExe(ExePath);

  if Opts.DryRun then
  begin
    WriteLn('');
    WriteLn('[DRY-RUN] Update execution plan:');
    WriteLn(Format('  1. Download package : %s', [AssetUrl]));
    if ChecksumUrl <> '' then
      WriteLn(Format('  2. Verify SHA-256   : %s', [ChecksumUrl]))
    else if Opts.AllowUnsigned then
      WriteLn('  2. Verify SHA-256   : skipped (--allow-unsigned)')
    else
      WriteLn('  2. Verify SHA-256   : REQUIRED (no checksum URL found -> would fail unless --allow-unsigned)');
    WriteLn(Format('  3. Extract archive  : %s', [AssetName]));
    WriteLn(Format('  4. Backup & update  : %s -> %s.bak', [ExePath, ExePath]));
    if not Opts.NoStdUpdate then
      WriteLn(Format('  5. Sync stdlib (std): %s -> %s.bak', [StdDir, StdDir]));
    WriteLn('  6. Self-test        : delsafec --version');
    Exit;
  end;

  TempDir := GetTempDir + 'delsafe_upgrade_' + IntToStr(DateTimeToFileDate(Now));
  if not ForceDirectories(TempDir) then
  begin
    WriteLn(ErrOutput, 'Error creating temporary update directory: ' + TempDir);
    Halt(1);
  end;

  DownloadedFile := TempDir + PathDelim + AssetName;
  ExtractDir := TempDir + PathDelim + 'extracted';
  ForceDirectories(ExtractDir);

  try
    // 1. Download release archive
    WriteLn('');
    WriteLn(Format('-> [1/4] Downloading release %s (%s)...', [TagName, AssetName]));
    if not DownloadUrlToFile(AssetUrl, DownloadedFile) then
    begin
      WriteLn(ErrOutput, 'Error downloading release artifact from: ' + AssetUrl);
      Halt(1);
    end;

    // 2. SHA-256 integrity verification
    WriteLn('-> [2/4] Verifying cryptographic integrity (SHA-256)...');
    HashCalc := LowerCase(SHA256File(DownloadedFile));
    WriteLn(Format('   Computed SHA-256 hash: %s', [HashCalc]));

    if ChecksumUrl <> '' then
    begin
      ExitCode := FetchUrlText(ChecksumUrl, ChecksumVal);
      if (ExitCode <> 0) or (Trim(ChecksumVal) = '') then
      begin
        WriteLn(ErrOutput, 'Security Error E9991: Failed to fetch release SHA-256 checksum from: ' + ChecksumUrl);
        Halt(1);
      end;
      if not VerifySha256TextMatchesAsset(ChecksumVal, HashCalc, AssetName) then
      begin
        WriteLn(ErrOutput, 'Security Error E9991: Downloaded file SHA-256 hash does not match the official release.');
        WriteLn(ErrOutput, 'Operation aborted due to integrity check failure.');
        Halt(1);
      end;
      WriteLn('   [OK] SHA-256 checksum verified against the release signature.');
    end
    else if not Opts.AllowUnsigned then
    begin
      WriteLn(ErrOutput, 'Security Error E9992: Release does not provide a SHA-256 checksum asset.');
      WriteLn(ErrOutput, 'Re-run with --allow-unsigned only if you explicitly trust this release source.');
      Halt(1);
    end
    else
      WriteLn('   [WARNING] Integrity check skipped (--allow-unsigned).');

    // 3. Extract archive
    WriteLn('-> [3/4] Extracting release artifact...');
    TarCmd := Format('-xf "%s" -C "%s"', [DownloadedFile, ExtractDir]);
    ExitCode := RunProcessWithOutput('tar', TarCmd, TestLog);
    {$IFDEF MSWINDOWS}
    if (ExitCode <> 0) and (LowerCase(ExtractFileExt(DownloadedFile)) = '.zip') then
      ExitCode := RunProcessWithOutput('powershell',
        Format('-NoProfile -Command "Expand-Archive -Force -Path ''%s'' -DestinationPath ''%s''"', [DownloadedFile, ExtractDir]),
        TestLog);
    {$ENDIF}
    if ExitCode <> 0 then
    begin
      WriteLn(ErrOutput, 'Error extracting artifact: ' + TestLog);
      Halt(1);
    end;

    NewExeCandidate := FindExtractedExe(ExtractDir);
    if not FileExists(NewExeCandidate) then
    begin
      WriteLn(ErrOutput, 'Error: The delsafec compiler executable was not found in the extracted package.');
      Halt(1);
    end;

    ExtractedStdDir := FindExtractedStdDir(ExtractDir);

    // 4. Atomic filesystem replacement (executable + stdlib)
    WriteLn('-> [4/4] Applying atomic update to the compiler toolchain...');
    BakPath := ExePath + '.bak';
    if FileExists(BakPath) then
      DeleteFile(BakPath);

    if not RenameFile(ExePath, BakPath) then
    begin
      WriteLn(ErrOutput, Format('Error creating backup of current executable at "%s".', [BakPath]));
      Halt(1);
    end;

    if not RenameFile(NewExeCandidate, ExePath) then
    begin
      if not CopyFileStream(NewExeCandidate, ExePath) then
      begin
        WriteLn(ErrOutput, 'Error writing new executable. Restoring previous backup...');
        RenameFile(BakPath, ExePath);
        Halt(1);
      end;
    end;
    EnsureExecutableBit(ExePath);

    StdUpdated := False;
    StdBak := StdDir + '.bak';
    if (ExtractedStdDir <> '') and (not Opts.NoStdUpdate) then
    begin
      if DirectoryExists(StdBak) then
        DeleteDirectoryRecursive(StdBak);
      if DirectoryExists(StdDir) then
      begin
        if not RenameFile(StdDir, StdBak) then
        begin
          WriteLn(ErrOutput, 'Error creating backup of stdlib directory. Rolling back executable...');
          DeleteFile(ExePath);
          RenameFile(BakPath, ExePath);
          Halt(1);
        end;
      end;
      if not CopyDirectoryRecursive(ExtractedStdDir, StdDir) then
      begin
        WriteLn(ErrOutput, 'Error copying updated stdlib directory. Restoring backup...');
        DeleteDirectoryRecursive(StdDir);
        if DirectoryExists(StdBak) then RenameFile(StdBak, StdDir);
        DeleteFile(ExePath);
        RenameFile(BakPath, ExePath);
        Halt(1);
      end;
      StdUpdated := True;
      WriteLn(Format('   [OK] Updated standard library in "%s".', [StdDir]));
    end;

    // Verify execution of the new binary
    ExitCode := RunProcessWithOutput(ExePath, '--version', TestLog);
    if ExitCode <> 0 then
      ExitCode := RunProcessWithOutput(ExePath, '-h', TestLog);
    if ExitCode <> 0 then
    begin
      WriteLn(ErrOutput, 'Warning: New binary failed initial self-test. Restoring previous backup...');
      DeleteFile(ExePath);
      RenameFile(BakPath, ExePath);
      if StdUpdated then
      begin
        DeleteDirectoryRecursive(StdDir);
        if DirectoryExists(StdBak) then RenameFile(StdBak, StdDir);
      end;
      WriteLn(ErrOutput, 'Automatic rollback completed successfully.');
      Halt(1);
    end;

    WriteLn('');
    WriteLn('========================================================');
    WriteLn(Format('  [SUCCESS] DelSafe compiler updated to %s!          ', [TagName]));
    WriteLn('  Previous version backup preserved at:                ');
    WriteLn(Format('    %s', [BakPath]));
    if StdUpdated then
      WriteLn(Format('    %s', [StdBak]));
    WriteLn('  To revert if needed: delsafec upgrade --rollback');
    WriteLn('========================================================');

  finally
    DeleteDirectoryRecursive(TempDir);
  end;
end;

class procedure TDelSafeUpgrade.ExecuteUpgrade(const Opts: TUpgradeOptions);
var
  CurExe, GitDir: string;
begin
  CurExe := GetCurrentExePath;

  if Opts.Rollback then
  begin
    HandleRollback(CurExe, Opts.DryRun);
    Exit;
  end;

  GitDir := FindGitRoot;

  if Opts.FromSource or ((GitDir <> '') and not Opts.BinaryMode and not Opts.CheckOnly) then
  begin
    if GitDir <> '' then
    begin
      HandleSourceUpgrade(GitDir, Opts);
      Exit;
    end
    else
    begin
      WriteLn(ErrOutput, 'Error: No Git repository detected in the current or parent directories.');
      WriteLn(ErrOutput, 'To update using prebuilt binaries from the official release:');
      WriteLn(ErrOutput, '  delsafec upgrade --binary');
      Halt(1);
    end;
  end;

  HandleBinaryUpgrade(CurExe, Opts);
end;

end.
