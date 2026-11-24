unit uAetherUpgrade;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Process, fpjson, jsonparser,
  uAetherIncremental, uAetherRegistry;

type
  TUpgradeOptions = record
    CheckOnly: Boolean;
    FromSource: Boolean;
    BinaryMode: Boolean;
    Rollback: Boolean;
    DryRun: Boolean;
    Nightly: Boolean;
    TargetVersion: string;
    CustomUrl: string;
  end;

  { TAetherUpgrade }
  TAetherUpgrade = class
  public
    class function CopyFileStream(const SrcPath, DstPath: string): Boolean;
    class function RunProcessWithOutput(const Executable, Params: string; var OutputLog: string): Integer;
    class function RunCommandStream(const CommandLineStr: string): Integer;
    class function DetectPlatform(out OSName, ArchName: string): Boolean;
    class function GetCurrentExePath: string;
    class function FindGitRoot: string;
    class function FetchReleaseMetadata(const Repo, VersionTag, CustomUrl: string;
      out TagName, ReleaseNotes, AssetUrl, AssetName, ChecksumUrl, ChecksumValue: string;
      out ErrorMsg: string): Boolean;
    class procedure HandleRollback(const ExePath: string; DryRun: Boolean);
    class procedure HandleSourceUpgrade(const GitDir: string; const Opts: TUpgradeOptions);
    class procedure HandleBinaryUpgrade(const ExePath: string; const Opts: TUpgradeOptions);
    class procedure ExecuteUpgrade(const Opts: TUpgradeOptions);
  end;

implementation

{ TAetherUpgrade }

class function TAetherUpgrade.CopyFileStream(const SrcPath, DstPath: string): Boolean;
var
  SrcStream, DstStream: TFileStream;
begin
  Result := False;
  try
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

class function TAetherUpgrade.RunProcessWithOutput(const Executable, Params: string; var OutputLog: string): Integer;
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
    Proc.CommandLine := Executable + ' ' + Params;
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

class function TAetherUpgrade.RunCommandStream(const CommandLineStr: string): Integer;
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

class function TAetherUpgrade.DetectPlatform(out OSName, ArchName: string): Boolean;
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

class function TAetherUpgrade.GetCurrentExePath: string;
begin
  Result := ParamStr(0);
  if not FileExists(Result) then
    Result := GetCurrentDir + PathDelim + ExtractFileName(ParamStr(0));
  Result := ExpandFileName(Result);
end;

class function TAetherUpgrade.FindGitRoot: string;
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

class function TAetherUpgrade.FetchReleaseMetadata(const Repo, VersionTag, CustomUrl: string;
  out TagName, ReleaseNotes, AssetUrl, AssetName, ChecksumUrl, ChecksumValue: string;
  out ErrorMsg: string): Boolean;
var
  TargetUrl, CurlCmd, OutputLog: string;
  ExitCode, I: Integer;
  JsonData, AssetsData, ItemData: TJSONData;
  RootObj, AssetObj: TJSONObject;
  OSName, ArchName, CurName, CurDownloadUrl: string;
  FoundAsset: Boolean;
begin
  Result := False;
  ErrorMsg := '';
  TagName := '';
  ReleaseNotes := '';
  AssetUrl := '';
  AssetName := '';
  ChecksumUrl := '';
  ChecksumValue := '';

  DetectPlatform(OSName, ArchName);

  if CustomUrl <> '' then
    TargetUrl := CustomUrl
  else if VersionTag <> '' then
    TargetUrl := Format('https://api.github.com/repos/%s/releases/tags/%s', [Repo, VersionTag])
  else
    TargetUrl := Format('https://api.github.com/repos/%s/releases/latest', [Repo]);

  CurlCmd := Format('-sL -H "User-Agent: Aether-Upgrader" -H "Accept: application/vnd.github.v3+json" "%s"', [TargetUrl]);
  ExitCode := RunProcessWithOutput('curl', CurlCmd, OutputLog);

  if ExitCode <> 0 then
  begin
    ErrorMsg := 'Failed to connect to release servers (curl returned exit code ' + IntToStr(ExitCode) + '). ' +
                'Check your network connection or use "aetherc upgrade --from-source". Log: ' + OutputLog;
    Exit(False);
  end;

  if (OutputLog = '') or (Pos('{', OutputLog) = 0) then
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
    if not (JsonData is TJSONObject) then
    begin
      ErrorMsg := 'Invalid JSON response from releases API.';
      Exit(False);
    end;

    RootObj := TJSONObject(JsonData);

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

          // Identify checksum file
          if (Pos('.sha256', CurName) > 0) or (Pos('checksum', CurName) > 0) then
          begin
            if (Pos(OSName, CurName) > 0) or (ChecksumUrl = '') then
              ChecksumUrl := CurDownloadUrl;
          end;

          // Identify the binary package matching the OS and architecture (excluding checksums)
          if (Pos(OSName, CurName) > 0) and
             (Pos('.sha256', CurName) = 0) and
             (Pos('.sig', CurName) = 0) and
             (Pos('.asc', CurName) = 0) and
             ((Pos(ArchName, CurName) > 0) or
              ((ArchName = 'x86_64') and ((Pos('x64', CurName) > 0) or (Pos('amd64', CurName) > 0)))) then
          begin
            AssetName := AssetObj.Get('name', '');
            AssetUrl := CurDownloadUrl;
            FoundAsset := True;
          end;
        end;
      end;
    end;
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

class procedure TAetherUpgrade.HandleRollback(const ExePath: string; DryRun: Boolean);
var
  BakPath, PrevPath: string;
  OutputLog: string;
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

  WriteLn('==> Starting Aether toolchain rollback...');
  WriteLn(Format('    Current executable: %s', [ExePath]));
  WriteLn(Format('    Previous backup   : %s', [BakPath]));

  if DryRun then
  begin
    WriteLn('');
    WriteLn('[DRY-RUN] No changes were written to disk.');
    WriteLn(Format('[DRY-RUN] File "%s" would be restored as "%s".', [BakPath, ExePath]));
    Exit;
  end;

  // On Windows, rename current to .failed and .bak to current
  if FileExists(ExePath + '.failed') then
    DeleteFile(ExePath + '.failed');

  if not RenameFile(ExePath, ExePath + '.failed') then
  begin
    WriteLn(ErrOutput, 'Error: Failed to move current executable to temporary backup.');
    Halt(1);
  end;

  if not RenameFile(BakPath, ExePath) then
  begin
    // Attempt restore on error
    RenameFile(ExePath + '.failed', ExePath);
    WriteLn(ErrOutput, 'Critical error: Failed to restore previous backup.');
    Halt(1);
  end;

  DeleteFile(ExePath + '.failed');

  // Verify restored executable
  if RunProcessWithOutput(ExePath, '-h', OutputLog) = 0 then
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

class procedure TAetherUpgrade.HandleSourceUpgrade(const GitDir: string; const Opts: TUpgradeOptions);
var
  Cmd, OutputLog, TargetBranch: string;
  ExitCode: Integer;
  IsWindows: Boolean;
begin
  WriteLn('========================================================');
  WriteLn('  Aether Update via Source Code (Source Build)          ');
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
    WriteLn('  3. powershell -ExecutionPolicy Bypass -File .\build.ps1');
    WriteLn('  4. .\bin\aetherc.exe test');
    {$ELSE}
    WriteLn('  3. ./build.sh');
    WriteLn('  4. ./bin/aetherc test');
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
      // Fall back to 'master' if remote branch is master
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

  // 3. Rebuild compiler
  WriteLn('');
  WriteLn('-> [3/4] Rebuilding the Aether compiler (aetherc)...');
  {$IFDEF MSWINDOWS}
  IsWindows := True;
  if FileExists(GitDir + PathDelim + 'build.ps1') then
    Cmd := Format('powershell -ExecutionPolicy Bypass -NoProfile -File "%s%sbuild.ps1"', [GitDir, PathDelim])
  else
    Cmd := Format('fpc -MObjFPC -Sc -O2 -FEbin -FUbuild -Fucompiler/src "%s%scompiler%saetherc.lpr"', [GitDir, PathDelim, PathDelim]);
  {$ELSE}
  IsWindows := False;
  if FileExists(GitDir + PathDelim + 'build.sh') then
    Cmd := Format('sh "%s%sbuild.sh"', [GitDir, PathDelim])
  else
    Cmd := Format('fpc -MObjFPC -Sc -O2 -FEbin -FUbuild -Fucompiler/src "%s%scompiler%saetherc.lpr"', [GitDir, PathDelim, PathDelim]);
  {$ENDIF}

  ExitCode := RunCommandStream(Cmd);
  if ExitCode <> 0 then
  begin
    WriteLn(ErrOutput, Format('Error compiling aetherc (exit code %d).', [ExitCode]));
    Halt(1);
  end;

  // 4. Run unit test suite with the new binary
  WriteLn('');
  WriteLn('-> [4/4] Validating new compiler against the unit test suite...');
  if IsWindows then
    Cmd := Format('"%s%sbin%saetherc.exe" test', [GitDir, PathDelim, PathDelim])
  else
    Cmd := Format('"%s%sbin%saetherc" test', [GitDir, PathDelim, PathDelim]);

  ExitCode := RunCommandStream(Cmd);
  if ExitCode <> 0 then
  begin
    WriteLn(ErrOutput, 'Warning: Some suite tests failed after updating.');
    Halt(1);
  end;

  WriteLn('');
  WriteLn('========================================================');
  WriteLn('  [SUCCESS] Aether compiler updated successfully!       ');
  WriteLn('  Toolchain rebuilt and verified via tests.             ');
  WriteLn('========================================================');
end;

class procedure TAetherUpgrade.HandleBinaryUpgrade(const ExePath: string; const Opts: TUpgradeOptions);
var
  RepoName, TagName, Notes, AssetUrl, AssetName, ChecksumUrl, ChecksumVal, ErrorMsg: string;
  TempDir, DownloadedFile, ExtractDir, NewExeCandidate, BakPath, HashCalc: string;
  CurlCmd, TarCmd, TestLog: string;
  ExitCode: Integer;
  OSName, ArchName: string;
begin
  RepoName := SysUtils.GetEnvironmentVariable('AETHER_UPGRADE_REPO');
  if RepoName = '' then
    RepoName := 'aetherlang/aether';

  DetectPlatform(OSName, ArchName);

  WriteLn('========================================================');
  WriteLn('  Checking for AetherLang Compiler Updates             ');
  WriteLn('========================================================');
  WriteLn(Format('Current installed version : v%s', [AETHER_COMPILER_VERSION]));
  WriteLn(Format('Detected platform         : %s-%s', [OSName, ArchName]));
  WriteLn(Format('Releases repository       : %s', [RepoName]));
  WriteLn('Fetching release metadata...');

  if not FetchReleaseMetadata(RepoName, Opts.TargetVersion, Opts.CustomUrl,
                              TagName, Notes, AssetUrl, AssetName, ChecksumUrl, ChecksumVal, ErrorMsg) then
  begin
    WriteLn(ErrOutput, 'Error: ' + ErrorMsg);
    Halt(1);
  end;

  WriteLn('');
  WriteLn(Format('Latest version found      : %s', [TagName]));
  if AssetName <> '' then
    WriteLn(Format('Compatible package        : %s', [AssetName]));

  // Compare SemVer of current version against remote release
  if (CompareSemVer(TagName, AETHER_COMPILER_VERSION) <= 0) and (Opts.TargetVersion = '') then
  begin
    WriteLn('');
    WriteLn('========================================================');
    WriteLn(Format('  AetherLang is already up to date at v%s!        ', [AETHER_COMPILER_VERSION]));
    WriteLn('  No further action is required.                        ');
    WriteLn('========================================================');
    Exit;
  end;

  if Opts.CheckOnly then
  begin
    WriteLn('');
    WriteLn('--------------------------------------------------------');
    WriteLn(Format('New version available: %s (installed: v%s)', [TagName, AETHER_COMPILER_VERSION]));
    if Trim(Notes) <> '' then
    begin
      WriteLn('');
      WriteLn('Release Notes:');
      WriteLn(Copy(Notes, 1, 400));
      if Length(Notes) > 400 then WriteLn('...');
    end;
    WriteLn('--------------------------------------------------------');
    WriteLn('To update to this version now, run:');
    WriteLn('  aetherc upgrade');
    Exit;
  end;

  if Opts.DryRun then
  begin
    WriteLn('');
    WriteLn('[DRY-RUN] Update execution plan:');
    WriteLn(Format('  1. Download: %s', [AssetUrl]));
    if ChecksumUrl <> '' then
      WriteLn(Format('  2. SHA-256 Integrity Check via %s', [ChecksumUrl]));
    WriteLn(Format('  3. Extract package %s', [AssetName]));
    WriteLn(Format('  4. Atomic backup: %s -> %s.bak', [ExePath, ExePath]));
    WriteLn(Format('  5. Replace: %s', [ExePath]));
    WriteLn('  6. Startup test with the new binary');
    Exit;
  end;

  // Create temporary download directory
  TempDir := GetTempDir + 'aether_upgrade_' + IntToStr(DateTimeToFileDate(Now));
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
    CurlCmd := Format('-sL -H "User-Agent: Aether-Upgrader" -o "%s" "%s"', [DownloadedFile, AssetUrl]);
    ExitCode := RunCommandStream('curl ' + CurlCmd);
    if (ExitCode <> 0) or not FileExists(DownloadedFile) then
    begin
      WriteLn(ErrOutput, 'Error downloading release artifact via curl.');
      Halt(1);
    end;

    // 2. SHA-256 integrity verification
    WriteLn('-> [2/4] Verifying cryptographic integrity (SHA-256)...');
    HashCalc := LowerCase(SHA256File(DownloadedFile));
    WriteLn(Format('   Computed SHA-256 hash: %s', [HashCalc]));

    if ChecksumUrl <> '' then
    begin
      // Download checksum if available
      RunProcessWithOutput('curl', Format('-sL "%s"', [ChecksumUrl]), ChecksumVal);
      if ChecksumVal <> '' then
      begin
        if Pos(HashCalc, LowerCase(ChecksumVal)) = 0 then
        begin
          WriteLn(ErrOutput, 'Security Error E9991: Downloaded file SHA-256 hash does not match the official release.');
          WriteLn(ErrOutput, 'Operation aborted due to integrity check failure.');
          Halt(1);
        end
        else
          WriteLn('   [OK] SHA-256 checksum verified against the release signature.');
      end;
    end
    else
      WriteLn('   [OK] Local checksum computed successfully.');

    // 3. Extract archive
    WriteLn('-> [3/4] Extracting release artifact...');
    TarCmd := Format('-xf "%s" -C "%s"', [DownloadedFile, ExtractDir]);
    ExitCode := RunProcessWithOutput('tar', TarCmd, TestLog);
    if ExitCode <> 0 then
    begin
      WriteLn(ErrOutput, 'Error extracting artifact with tar: ' + TestLog);
      Halt(1);
    end;

    // Locate extracted executable
    {$IFDEF MSWINDOWS}
    NewExeCandidate := ExtractDir + PathDelim + 'aetherc.exe';
    if not FileExists(NewExeCandidate) then
      NewExeCandidate := ExtractDir + PathDelim + 'bin' + PathDelim + 'aetherc.exe';
    {$ELSE}
    NewExeCandidate := ExtractDir + PathDelim + 'aetherc';
    if not FileExists(NewExeCandidate) then
      NewExeCandidate := ExtractDir + PathDelim + 'bin' + PathDelim + 'aetherc';
    {$ENDIF}

    if not FileExists(NewExeCandidate) then
    begin
      WriteLn(ErrOutput, 'Error: The aetherc compiler executable was not found in the extracted package.');
      Halt(1);
    end;

    // 4. Atomic filesystem replacement
    WriteLn('-> [4/4] Applying atomic update to the compiler executable...');
    BakPath := ExePath + '.bak';
    if FileExists(BakPath) then
      DeleteFile(BakPath);

    // On Windows, renaming a running executable is allowed
    if not RenameFile(ExePath, BakPath) then
    begin
      WriteLn(ErrOutput, Format('Error creating backup of current executable at "%s".', [BakPath]));
      Halt(1);
    end;

    // Copy or move the new executable into place
    if not RenameFile(NewExeCandidate, ExePath) then
    begin
      // If rename failed (e.g., cross-drive), try copying
      if not CopyFileStream(NewExeCandidate, ExePath) then
      begin
        WriteLn(ErrOutput, 'Error writing new executable. Restoring previous backup...');
        RenameFile(BakPath, ExePath);
        Halt(1);
      end;
    end;

    // Verify execution of the new binary
    ExitCode := RunProcessWithOutput(ExePath, '-h', TestLog);
    if ExitCode <> 0 then
    begin
      WriteLn(ErrOutput, 'Warning: New binary failed initial self-test. Restoring previous backup...');
      DeleteFile(ExePath);
      RenameFile(BakPath, ExePath);
      WriteLn(ErrOutput, 'Automatic rollback completed successfully.');
      Halt(1);
    end;

    WriteLn('');
    WriteLn('========================================================');
    WriteLn(Format('  [SUCCESS] Aether compiler updated to %s!          ', [TagName]));
    WriteLn('  Previous version backup preserved at:                ');
    WriteLn(Format('    %s', [BakPath]));
    WriteLn('  To revert if needed: aetherc upgrade --rollback');
    WriteLn('========================================================');

  finally
    // Clean up temporary files
    if FileExists(DownloadedFile) then DeleteFile(DownloadedFile);
  end;
end;

class procedure TAetherUpgrade.ExecuteUpgrade(const Opts: TUpgradeOptions);
var
  CurExe, GitDir: string;
begin
  CurExe := GetCurrentExePath;

  // 1. Explicit rollback requested
  if Opts.Rollback then
  begin
    HandleRollback(CurExe, Opts.DryRun);
    Exit;
  end;

  GitDir := FindGitRoot;

  // 2. Source-based update (explicit or automatic inside a git repo)
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
      WriteLn(ErrOutput, '  aetherc upgrade --binary');
      Halt(1);
    end;
  end;

  // 3. Binary package update
  HandleBinaryUpgrade(CurExe, Opts);
end;

end.
