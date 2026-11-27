unit uDelSafeToolchain;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Process
  {$IFDEF MSWINDOWS}
  , Windows
  {$ENDIF}
  ;

type
  TToolchainInfo = record
    FPCFound: Boolean;
    FPCPath: string;
    FPCVersion: string;

    GCCFound: Boolean;
    GCCPath: string;
    GCCVersion: string;
    MSYS2BinDir: string;
    MSYS2RootDir: string;
    MSYS2Subsystem: string;
    PacmanFound: Boolean;
    PacmanPath: string;
    PkgConfigFound: Boolean;
    PkgConfigPath: string;
    ObjdumpFound: Boolean;
    ObjdumpPath: string;
    DlltoolFound: Boolean;
    DlltoolPath: string;

    ClangFound: Boolean;
    ClangPath: string;
    ClangVersion: string;

    Pas2JSFound: Boolean;
    Pas2JSPath: string;
    Pas2JSVersion: string;

    FppkgFound: Boolean;
    FppkgPath: string;
    FpcUnitsDir: string;
    FppkgUnitsDir: string;
    LazarusOpmDir: string;
  end;

function DetectToolchain: TToolchainInfo;
procedure PrintDoctorReport;
function RunCommandCapture(const ExePath, Params: string; const ExtraPathDir: string; var OutText: string): Integer;
function GetMSYS2PackagePrefix(const Subsystem: string): string;
function MapLibToMSYS2Package(const LibName, Subsystem: string): string;
function ResolvePkgConfigLib(const LibName: string; const Info: TToolchainInfo;
                             IncludeDirs, ExtraCFlags, LibDirs, Libs: TStrings;
                             out ErrorMsg, InstallHint: string): Boolean;
function ResolveSystemLibDllName(const LibName: string; const Info: TToolchainInfo): string;
function BundleMSYS2Dlls(const TargetBinary: string; const Info: TToolchainInfo;
                         Silent: Boolean = False; ExtraDllNames: TStrings = nil): Integer;
function InstallMSYS2SystemLib(const LibName: string; const Info: TToolchainInfo;
                               out InstalledPkg, OutputLog: string): Boolean;
function ResolvePascalPackagePaths(const PkgName: string; const Info: TToolchainInfo;
                                   OutUnitPaths: TStrings; out ErrorMsg: string): Boolean;
function InstallFpcPackage(const PkgName: string; const Info: TToolchainInfo; var OutputLog: string): Boolean;
function CompileWithFPC(const PascalSource, OutExe: string; var OutputLog: string; ReleaseMode: Boolean = False;
                        UnitPaths: TStrings = nil; LibDirs: TStrings = nil; const UnitOutputDir: string = '';
                        CompileUnitOnly: Boolean = False): Boolean;
function CompileWithGCC(const CSource, OutExe: string; var OutputLog: string; ReleaseMode: Boolean = False;
                        IncludePaths: TStrings = nil; ExtraCSources: TStrings = nil;
                        LibDirs: TStrings = nil; Libs: TStrings = nil; ExtraCFlags: TStrings = nil): Boolean;
function CompileWithClang(const CSource, OutExe: string; var OutputLog: string; ReleaseMode: Boolean = False;
                          IncludePaths: TStrings = nil; ExtraCSources: TStrings = nil;
                          LibDirs: TStrings = nil; Libs: TStrings = nil; ExtraCFlags: TStrings = nil): Boolean;
function CompileWithC(const CompilerType: string; const CSource, OutExe: string; var OutputLog: string; ReleaseMode: Boolean = False;
                      IncludePaths: TStrings = nil; ExtraCSources: TStrings = nil;
                      LibDirs: TStrings = nil; Libs: TStrings = nil; ExtraCFlags: TStrings = nil): Boolean;
function CompileWithClangWasm(const CSource, OutWasm: string; var OutputLog: string; ReleaseMode: Boolean = False): Boolean;
function CompileWithPas2JS(const PascalSource, OutJS: string; var OutputLog: string; ReleaseMode: Boolean = False;
                           UnitPaths: TStrings = nil): Boolean;
function GenerateWasmHtmlWrapper(const WasmFileName, OutHtmlFile: string): Boolean;
function GenerateJSHtmlWrapper(const JSFileName, OutHtmlFile: string): Boolean;

procedure SplitCmdParams(const Params: string; List: TStrings);

implementation

procedure SplitCmdParams(const Params: string; List: TStrings);
var
  I: Integer;
  CurToken: string;
  InQuote, HadQuote: Boolean;
  QuoteChar: Char;
  Ch: Char;
begin
  List.Clear;
  CurToken := '';
  InQuote := False;
  HadQuote := False;
  QuoteChar := #0;
  I := 1;
  while I <= Length(Params) do
  begin
    Ch := Params[I];
    if InQuote then
    begin
      if Ch = QuoteChar then
      begin
        InQuote := False;
        QuoteChar := #0;
      end
      else
        CurToken := CurToken + Ch;
    end
    else
    begin
      if (Ch = '"') or (Ch = '''') then
      begin
        InQuote := True;
        HadQuote := True;
        QuoteChar := Ch;
      end
      else if Ch in [' ', #9, #10, #13] then
      begin
        if (CurToken <> '') or HadQuote then
        begin
          List.Add(CurToken);
          CurToken := '';
          HadQuote := False;
        end;
      end
      else
        CurToken := CurToken + Ch;
    end;
    Inc(I);
  end;
  if (CurToken <> '') or HadQuote then
    List.Add(CurToken);
end;

function RunCommandCapture(const ExePath, Params: string; const ExtraPathDir: string; var OutText: string): Integer;
var
  Proc: TProcess;
  Buffer: array[0..2047] of Byte;
  BytesRead: LongInt;
  StringStream: TStringStream;
  {$IFDEF MSWINDOWS}
  OldPath: string;
  {$ENDIF}
begin
  Result := -1;
  OutText := '';
  Proc := TProcess.Create(nil);
  StringStream := TStringStream.Create('');
  try
    Proc.Executable := ExePath;
    Proc.Parameters.Clear;
    SplitCmdParams(Params, Proc.Parameters);
    Proc.Options := [poUsePipes, poStderrToOutPut];
    Proc.ShowWindow := swoNone;

    {$IFDEF MSWINDOWS}
    if ExtraPathDir <> '' then
    begin
      OldPath := SysUtils.GetEnvironmentVariable('PATH');
      Windows.SetEnvironmentVariableA(PAnsiChar('PATH'), PAnsiChar(ExtraPathDir + ';' + OldPath));
    end;
    {$ENDIF}

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
    OutText := Trim(StringStream.DataString);

    {$IFDEF MSWINDOWS}
    if ExtraPathDir <> '' then
      Windows.SetEnvironmentVariableA(PAnsiChar('PATH'), PAnsiChar(OldPath));
    {$ENDIF}
  finally
    StringStream.Free;
    Proc.Free;
  end;
end;

function DetectToolchain: TToolchainInfo;
var
  CandidatePaths: array of string;
  P: string;
  OutText: string;
  Code: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);

  // --- 1. Free Pascal (FPC) Detection ---
  {$IFDEF MSWINDOWS}
  SetLength(CandidatePaths, 3);
  CandidatePaths[0] := 'fpc.exe'; // System PATH
  CandidatePaths[1] := 'C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe';
  CandidatePaths[2] := 'C:\fpc\3.2.2\bin\i386-win32\fpc.exe';
  {$ELSE}
  SetLength(CandidatePaths, 3);
  CandidatePaths[0] := 'fpc'; // Linux/macOS System PATH
  CandidatePaths[1] := '/usr/bin/fpc';
  CandidatePaths[2] := '/usr/local/bin/fpc';
  {$ENDIF}

  for P in CandidatePaths do
  begin
    if (P = 'fpc.exe') or (P = 'fpc') or FileExists(P) then
    begin
      Code := RunCommandCapture(P, '-iV', '', OutText);
      if Code = 0 then
      begin
        Result.FPCFound := True;
        Result.FPCPath := P;
        Result.FPCVersion := OutText;
        Break;
      end;
    end;
  end;

  // --- 2. GCC Detection (MSYS2 on Windows / Native on Linux and macOS) ---
  {$IFDEF MSWINDOWS}
  SetLength(CandidatePaths, 5);
  CandidatePaths[0] := 'C:\msys64\ucrt64\bin\gcc.exe';
  CandidatePaths[1] := 'C:\msys64\mingw64\bin\gcc.exe';
  CandidatePaths[2] := 'C:\msys64\clang64\bin\gcc.exe';
  CandidatePaths[3] := 'C:\msys2\mingw64\bin\gcc.exe';
  CandidatePaths[4] := 'gcc.exe';
  {$ELSE}
  SetLength(CandidatePaths, 5);
  CandidatePaths[0] := 'gcc';
  CandidatePaths[1] := '/usr/bin/gcc';
  CandidatePaths[2] := '/usr/local/bin/gcc';
  CandidatePaths[3] := 'clang';
  CandidatePaths[4] := '/usr/bin/clang';
  {$ENDIF}

  for P in CandidatePaths do
  begin
    if (P = 'gcc.exe') or (P = 'gcc') or (P = 'clang') or FileExists(P) then
    begin
      // On Windows: for MSYS2, add the corresponding bin directory
      {$IFDEF MSWINDOWS}
      if Pos('msys', LowerCase(P)) > 0 then
        Result.MSYS2BinDir := ExtractFileDir(P)
      else
        Result.MSYS2BinDir := '';
      {$ELSE}
      Result.MSYS2BinDir := '';
      {$ENDIF}

      Code := RunCommandCapture(P, '--version', Result.MSYS2BinDir, OutText);
      // Ignore FPC legacy 2.95 stub
      if (Code = 0) and (Pos('2.95', OutText) = 0) then
      begin
        Result.GCCFound := True;
        Result.GCCPath := P;
        if Length(OutText) > 60 then
          Result.GCCVersion := Copy(OutText, 1, Pos(#10, OutText) - 1)
        else
          Result.GCCVersion := OutText;
        Break;
      end;
    end;
  end;

  // --- 3. Clang Detection (LLVM / WebAssembly wasm32) ---
  {$IFDEF MSWINDOWS}
  SetLength(CandidatePaths, 5);
  CandidatePaths[0] := 'C:\msys64\ucrt64\bin\clang.exe';
  CandidatePaths[1] := 'C:\msys64\clang64\bin\clang.exe';
  CandidatePaths[2] := 'C:\tools\msys64\ucrt64\bin\clang.exe';
  CandidatePaths[3] := 'C:\msys2\ucrt64\bin\clang.exe';
  CandidatePaths[4] := 'clang.exe';
  {$ELSE}
  SetLength(CandidatePaths, 3);
  CandidatePaths[0] := 'clang';
  CandidatePaths[1] := '/usr/bin/clang';
  CandidatePaths[2] := '/usr/local/bin/clang';
  {$ENDIF}

  for P in CandidatePaths do
  begin
    if (P = 'clang.exe') or (P = 'clang') or FileExists(P) then
    begin
      Code := RunCommandCapture(P, '--version', Result.MSYS2BinDir, OutText);
      if Code = 0 then
      begin
        Result.ClangFound := True;
        Result.ClangPath := P;
        if Pos(#10, OutText) > 0 then
          Result.ClangVersion := Trim(Copy(OutText, 1, Pos(#10, OutText) - 1))
        else
          Result.ClangVersion := Trim(OutText);
        Break;
      end;
    end;
  end;

  // --- 4. Pas2JS Detection (Free Pascal Web JavaScript Compiler) ---
  {$IFDEF MSWINDOWS}
  SetLength(CandidatePaths, 4);
  CandidatePaths[0] := 'C:\ComponenteLazarus\pas2js-win64-x86_64-3.2.0\bin\pas2js.exe';
  CandidatePaths[1] := 'C:\lazarus\fpc\3.2.2\bin\x86_64-win64\pas2js.exe';
  CandidatePaths[2] := 'C:\LazarusTrunk_FPC_3.3.1_Fresnel\fpcsrc\utils\pas2js\pas2js.exe';
  CandidatePaths[3] := 'pas2js.exe';
  {$ELSE}
  SetLength(CandidatePaths, 3);
  CandidatePaths[0] := 'pas2js';
  CandidatePaths[1] := '/usr/bin/pas2js';
  CandidatePaths[2] := '/usr/local/bin/pas2js';
  {$ENDIF}

  for P in CandidatePaths do
  begin
    if (P = 'pas2js.exe') or (P = 'pas2js') or FileExists(P) then
    begin
      Code := RunCommandCapture(P, '-iV', '', OutText);
      if Code = 0 then
      begin
        Result.Pas2JSFound := True;
        Result.Pas2JSPath := P;
        Result.Pas2JSVersion := Trim(OutText);
        Break;
      end;
    end;
  end;

  // --- 5. MSYS2 Ecosystem (pkg-config, pacman, objdump, dlltool) ---
  {$IFDEF MSWINDOWS}
  if Result.MSYS2BinDir <> '' then
  begin
    P := ExcludeTrailingPathDelimiter(Result.MSYS2BinDir);
    Result.MSYS2Subsystem := LowerCase(ExtractFileName(ExtractFileDir(P)));
    Result.MSYS2RootDir := ExtractFileDir(ExtractFileDir(P));
    if FileExists(Result.MSYS2RootDir + '\usr\bin\pacman.exe') then
    begin
      Result.PacmanFound := True;
      Result.PacmanPath := Result.MSYS2RootDir + '\usr\bin\pacman.exe';
    end;
    if FileExists(P + '\pkg-config.exe') then
    begin
      Result.PkgConfigFound := True;
      Result.PkgConfigPath := P + '\pkg-config.exe';
    end;
    if FileExists(P + '\objdump.exe') then
    begin
      Result.ObjdumpFound := True;
      Result.ObjdumpPath := P + '\objdump.exe';
    end;
    if FileExists(P + '\dlltool.exe') then
    begin
      Result.DlltoolFound := True;
      Result.DlltoolPath := P + '\dlltool.exe';
    end;
  end;
  if not Result.PkgConfigFound then
  begin
    SetLength(CandidatePaths, 3);
    CandidatePaths[0] := 'C:\msys64\ucrt64\bin\pkg-config.exe';
    CandidatePaths[1] := 'C:\msys64\mingw64\bin\pkg-config.exe';
    CandidatePaths[2] := 'pkg-config.exe';
    for P in CandidatePaths do
    begin
      if (P = 'pkg-config.exe') or FileExists(P) then
      begin
        if RunCommandCapture(P, '--version', Result.MSYS2BinDir, OutText) = 0 then
        begin
          Result.PkgConfigFound := True;
          Result.PkgConfigPath := P;
          if (Result.MSYS2BinDir = '') and (Pos('msys', LowerCase(P)) > 0) then
          begin
            Result.MSYS2BinDir := ExtractFileDir(P);
            Result.MSYS2Subsystem := LowerCase(ExtractFileName(ExtractFileDir(Result.MSYS2BinDir)));
            Result.MSYS2RootDir := ExtractFileDir(ExtractFileDir(Result.MSYS2BinDir));
          end;
          Break;
        end;
      end;
    end;
  end;
  if (not Result.PacmanFound) and FileExists('C:\msys64\usr\bin\pacman.exe') then
  begin
    Result.PacmanFound := True;
    Result.PacmanPath := 'C:\msys64\usr\bin\pacman.exe';
    if Result.MSYS2RootDir = '' then Result.MSYS2RootDir := 'C:\msys64';
    if Result.MSYS2Subsystem = '' then Result.MSYS2Subsystem := 'ucrt64';
  end;
  if not Result.ObjdumpFound then
  begin
    SetLength(CandidatePaths, 3);
    CandidatePaths[0] := 'C:\msys64\ucrt64\bin\objdump.exe';
    CandidatePaths[1] := 'C:\msys64\mingw64\bin\objdump.exe';
    CandidatePaths[2] := 'objdump.exe';
    for P in CandidatePaths do
      if (P = 'objdump.exe') or FileExists(P) then
        if RunCommandCapture(P, '--version', Result.MSYS2BinDir, OutText) = 0 then
        begin
          Result.ObjdumpFound := True;
          Result.ObjdumpPath := P;
          Break;
        end;
  end;
  if not Result.DlltoolFound then
  begin
    SetLength(CandidatePaths, 3);
    CandidatePaths[0] := 'C:\msys64\ucrt64\bin\dlltool.exe';
    CandidatePaths[1] := 'C:\msys64\mingw64\bin\dlltool.exe';
    CandidatePaths[2] := 'dlltool.exe';
    for P in CandidatePaths do
      if (P = 'dlltool.exe') or FileExists(P) then
        if RunCommandCapture(P, '--version', Result.MSYS2BinDir, OutText) = 0 then
        begin
          Result.DlltoolFound := True;
          Result.DlltoolPath := P;
          Break;
        end;
  end;
  {$ELSE}
  SetLength(CandidatePaths, 3);
  CandidatePaths[0] := 'pkg-config';
  CandidatePaths[1] := '/usr/bin/pkg-config';
  CandidatePaths[2] := '/usr/local/bin/pkg-config';
  for P in CandidatePaths do
    if (P = 'pkg-config') or FileExists(P) then
      if RunCommandCapture(P, '--version', '', OutText) = 0 then
      begin
        Result.PkgConfigFound := True;
        Result.PkgConfigPath := P;
        Break;
      end;
  {$ENDIF}

  // --- 6. Free Pascal Ecosystem (fppkg, FPC units, Lazarus OPM) ---
  SetLength(CandidatePaths, 2);
  if Result.FPCFound and (ExtractFileDir(Result.FPCPath) <> '') then
    CandidatePaths[0] := IncludeTrailingPathDelimiter(ExtractFileDir(Result.FPCPath)) +
                         {$IFDEF MSWINDOWS}'fppkg.exe'{$ELSE}'fppkg'{$ENDIF}
  else
    CandidatePaths[0] := {$IFDEF MSWINDOWS}'fppkg.exe'{$ELSE}'fppkg'{$ENDIF};
  CandidatePaths[1] := {$IFDEF MSWINDOWS}'fppkg.exe'{$ELSE}'fppkg'{$ENDIF};
  for P in CandidatePaths do
  begin
    if (P = 'fppkg.exe') or (P = 'fppkg') or FileExists(P) then
    begin
      if RunCommandCapture(P, '--version', '', OutText) = 0 then
      begin
        Result.FppkgFound := True;
        Result.FppkgPath := P;
        Break;
      end;
    end;
  end;

  {$IFDEF MSWINDOWS}
  if Result.FPCFound and (Pos('bin\', LowerCase(Result.FPCPath)) > 0) then
  begin
    P := ExpandFileName(ExtractFileDir(Result.FPCPath) + '\..\..\units\x86_64-win64');
    if DirectoryExists(P) then
      Result.FpcUnitsDir := P;
  end;
  if (Result.FpcUnitsDir = '') and DirectoryExists('C:\lazarus\fpc\3.2.2\units\x86_64-win64') then
    Result.FpcUnitsDir := 'C:\lazarus\fpc\3.2.2\units\x86_64-win64';

  P := SysUtils.GetEnvironmentVariable('LOCALAPPDATA');
  if P <> '' then
  begin
    if DirectoryExists(P + '\FreePascal\fppkg') then
      Result.FppkgUnitsDir := P + '\FreePascal\fppkg';
    if DirectoryExists(P + '\lazarus\onlinepackagemanager\packages') then
      Result.LazarusOpmDir := P + '\lazarus\onlinepackagemanager\packages';
  end;
  {$ELSE}
  P := SysUtils.GetEnvironmentVariable('HOME');
  if P <> '' then
  begin
    if DirectoryExists(P + '/.fppkg') then
      Result.FppkgUnitsDir := P + '/.fppkg';
    if DirectoryExists(P + '/.lazarus/onlinepackagemanager/packages') then
      Result.LazarusOpmDir := P + '/.lazarus/onlinepackagemanager/packages';
  end;
  if DirectoryExists('/usr/lib/fpc') then
    Result.FpcUnitsDir := '/usr/lib/fpc';
  {$ENDIF}
end;

procedure AddUniqueStr(List: TStrings; const Val: string);
var
  Trimmed: string;
  I: Integer;
begin
  if not Assigned(List) then Exit;
  Trimmed := Trim(Val);
  if Trimmed = '' then Exit;
  for I := 0 to List.Count - 1 do
    if SameText(List[I], Trimmed) then Exit;
  List.Add(Trimmed);
end;

function GetMSYS2PackagePrefix(const Subsystem: string): string;
var
  LowSub: string;
begin
  LowSub := LowerCase(Trim(Subsystem));
  if LowSub = 'mingw64' then
    Result := 'mingw-w64-x86_64-'
  else if LowSub = 'clang64' then
    Result := 'mingw-w64-clang-x86_64-'
  else if LowSub = 'clangarm64' then
    Result := 'mingw-w64-clang-aarch64-'
  else if LowSub = 'mingw32' then
    Result := 'mingw-w64-i686-'
  else
    Result := 'mingw-w64-ucrt-x86_64-';
end;

function MapLibToMSYS2Package(const LibName, Subsystem: string): string;
var
  LowName, PkgBase: string;
begin
  LowName := LowerCase(Trim(LibName));
  if Pos('mingw-w64-', LowName) = 1 then
    Exit(LowName);
  if (LowName = 'z') or (LowName = 'zlib') then PkgBase := 'zlib'
  else if (LowName = 'curl') or (LowName = 'libcurl') then PkgBase := 'curl'
  else if (LowName = 'png') or (LowName = 'libpng') or (LowName = 'libpng16') then PkgBase := 'libpng'
  else if (LowName = 'ssl') or (LowName = 'crypto') or (LowName = 'openssl') then PkgBase := 'openssl'
  else if (LowName = 'zstd') or (LowName = 'libzstd') then PkgBase := 'zstd'
  else if (LowName = 'bz2') or (LowName = 'bzip2') then PkgBase := 'bzip2'
  else if (LowName = 'sqlite') or (LowName = 'sqlite3') then PkgBase := 'sqlite3'
  else if (LowName = 'raylib') then PkgBase := 'raylib'
  else if (LowName = 'sdl2') then PkgBase := 'SDL2'
  else if (LowName = 'sdl3') then PkgBase := 'SDL3'
  else PkgBase := Trim(LibName);
  Result := GetMSYS2PackagePrefix(Subsystem) + PkgBase;
end;

procedure TokenizePkgConfigOutput(const Raw: string; Tokens: TStrings);
var
  I, N: Integer;
  Cur: string;
  QuoteCh: Char;
begin
  Tokens.Clear;
  Cur := '';
  QuoteCh := #0;
  N := Length(Raw);
  I := 1;
  while I <= N do
  begin
    if QuoteCh <> #0 then
    begin
      if Raw[I] = QuoteCh then
        QuoteCh := #0
      else if (Raw[I] = '\') and (I < N) and (Raw[I + 1] = QuoteCh) then
      begin
        Cur := Cur + QuoteCh;
        Inc(I);
      end
      else
        Cur := Cur + Raw[I];
    end
    else
    begin
      if (Raw[I] = '"') or (Raw[I] = '''') then
        QuoteCh := Raw[I]
      else if Raw[I] in [' ', #9, #10, #13] then
      begin
        if Cur <> '' then
        begin
          Tokens.Add(Cur);
          Cur := '';
        end;
      end
      else
        Cur := Cur + Raw[I];
    end;
    Inc(I);
  end;
  if Cur <> '' then
    Tokens.Add(Cur);
end;

function ResolvePkgConfigLib(const LibName: string; const Info: TToolchainInfo;
                             IncludeDirs, ExtraCFlags, LibDirs, Libs: TStrings;
                             out ErrorMsg, InstallHint: string): Boolean;
var
  OutText, Tok, NextTok, NormPath, PkgName: string;
  Code, I: Integer;
  Tokens: TStringList;
begin
  Result := False;
  ErrorMsg := '';
  {$IFDEF MSWINDOWS}
  PkgName := MapLibToMSYS2Package(LibName, Info.MSYS2Subsystem);
  InstallHint := Format('Install in MSYS2 with: pacman -S %s (or run: delsafec pkg add-sys %s)', [PkgName, LibName]);
  {$ELSE}
  {$IFDEF DARWIN}
  InstallHint := Format('Install with Homebrew: brew install %s', [LibName]);
  {$ELSE}
  InstallHint := Format('Install development package via OS package manager (e.g. sudo apt install lib%s-dev)', [LibName]);
  {$ENDIF}
  {$ENDIF}

  if not Info.PkgConfigFound then
  begin
    ErrorMsg := Format('pkg-config was not found while resolving system library "%s".', [LibName]);
    Exit(False);
  end;

  Code := RunCommandCapture(Info.PkgConfigPath, '--cflags --libs "' + LibName + '"', Info.MSYS2BinDir, OutText);
  if Code <> 0 then
  begin
    ErrorMsg := Format('System library "%s" was not found via pkg-config (%s).', [LibName, Trim(OutText)]);
    Exit(False);
  end;

  Tokens := TStringList.Create;
  try
    TokenizePkgConfigOutput(OutText, Tokens);
    I := 0;
    while I < Tokens.Count do
    begin
      Tok := Tokens[I];
      if (Tok = '-I') and (I + 1 < Tokens.Count) then
      begin
        Inc(I);
        NextTok := Tokens[I];
        if Pos('..', NextTok) > 0 then NextTok := ExpandFileName(NextTok);
        AddUniqueStr(IncludeDirs, NextTok);
      end
      else if (Copy(Tok, 1, 2) = '-I') and (Length(Tok) > 2) then
      begin
        NormPath := Copy(Tok, 3, Length(Tok));
        if Pos('..', NormPath) > 0 then NormPath := ExpandFileName(NormPath);
        AddUniqueStr(IncludeDirs, NormPath);
      end
      else if (Tok = '-L') and (I + 1 < Tokens.Count) then
      begin
        Inc(I);
        NextTok := Tokens[I];
        if Pos('..', NextTok) > 0 then NextTok := ExpandFileName(NextTok);
        AddUniqueStr(LibDirs, NextTok);
      end
      else if (Copy(Tok, 1, 2) = '-L') and (Length(Tok) > 2) then
      begin
        NormPath := Copy(Tok, 3, Length(Tok));
        if Pos('..', NormPath) > 0 then NormPath := ExpandFileName(NormPath);
        AddUniqueStr(LibDirs, NormPath);
      end
      else if (Tok = '-l') and (I + 1 < Tokens.Count) then
      begin
        Inc(I);
        AddUniqueStr(Libs, Tokens[I]);
      end
      else if (Copy(Tok, 1, 2) = '-l') and (Length(Tok) > 2) then
      begin
        AddUniqueStr(Libs, Copy(Tok, 3, Length(Tok)));
      end
      else if Tok <> '' then
      begin
        AddUniqueStr(ExtraCFlags, Tok);
      end;
      Inc(I);
    end;
  finally
    Tokens.Free;
  end;

  Result := True;
end;

function IsBuiltinWin32Lib(const LowLib: string): Boolean;
begin
  Result := (LowLib = 'msvcrt') or (LowLib = 'kernel32') or (LowLib = 'user32') or
            (LowLib = 'gdi32') or (LowLib = 'advapi32') or (LowLib = 'ws2_32') or
            (LowLib = 'shell32') or (LowLib = 'ole32') or (LowLib = 'comdlg32') or
            (LowLib = 'winmm') or (LowLib = 'opengl32') or (LowLib = 'c') or
            (LowLib = 'libc') or (LowLib = 'm');
end;

function ResolveSystemLibDllName(const LibName: string; const Info: TToolchainInfo): string;
var
  CleanName, LowName, SubRoot, ImpLib, OutText, Line: string;
  Cands, Tokens: TStringList;
  I: Integer;
  SR: TSearchRec;
begin
  CleanName := Trim(LibName);
  Result := CleanName;
  if CleanName = '' then Exit;

  LowName := LowerCase(CleanName);
  if (Pos('.dll', LowName) > 0) or (Pos('.so', LowName) > 0) or (Pos('.dylib', LowName) > 0) then
    Exit(CleanName);
  if IsBuiltinWin32Lib(LowName) then
    Exit(CleanName);

  {$IFDEF MSWINDOWS}
  if Info.MSYS2BinDir = '' then Exit(CleanName);
  SubRoot := ExtractFileDir(ExcludeTrailingPathDelimiter(Info.MSYS2BinDir));

  Cands := TStringList.Create;
  Tokens := TStringList.Create;
  try
    if Info.PkgConfigFound then
    begin
      if RunCommandCapture(Info.PkgConfigPath, '--libs-only-l "' + CleanName + '"', Info.MSYS2BinDir, OutText) = 0 then
      begin
        TokenizePkgConfigOutput(OutText, Tokens);
        for I := 0 to Tokens.Count - 1 do
          if (Copy(Tokens[I], 1, 2) = '-l') and (Length(Tokens[I]) > 2) then
            AddUniqueStr(Cands, Copy(Tokens[I], 3, Length(Tokens[I])));
      end;
    end;
    AddUniqueStr(Cands, CleanName);
    if LowName = 'zlib' then AddUniqueStr(Cands, 'z');

    if Info.DlltoolFound then
    begin
      for I := 0 to Cands.Count - 1 do
      begin
        ImpLib := SubRoot + '\lib\lib' + Cands[I] + '.dll.a';
        if FileExists(ImpLib) then
        begin
          if RunCommandCapture(Info.DlltoolPath, '-I "' + ImpLib + '"', Info.MSYS2BinDir, OutText) = 0 then
          begin
            Line := Trim(OutText);
            if Pos(#10, Line) > 0 then Line := Trim(Copy(Line, 1, Pos(#10, Line) - 1));
            if Line <> '' then Exit(Line);
          end;
        end;
      end;
    end;

    // Fallback: match MSYS2 bin DLL pattern
    for I := 0 to Cands.Count - 1 do
    begin
      if FileExists(Info.MSYS2BinDir + '\lib' + Cands[I] + '.dll') then
        Exit('lib' + Cands[I] + '.dll');
      if FileExists(Info.MSYS2BinDir + '\' + Cands[I] + '.dll') then
        Exit(Cands[I] + '.dll');
      if FindFirst(Info.MSYS2BinDir + '\lib' + Cands[I] + '-*.dll', faAnyFile, SR) = 0 then
      begin
        try
          Exit(SR.Name);
        finally
          SysUtils.FindClose(SR);
        end;
      end;
    end;
  finally
    Tokens.Free;
    Cands.Free;
  end;
  {$ENDIF}
end;

function SafeCopyBinaryFile(const Src, Dst: string): Boolean;
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

function BundleMSYS2Dlls(const TargetBinary: string; const Info: TToolchainInfo;
                         Silent: Boolean = False; ExtraDllNames: TStrings = nil): Integer;
{$IFDEF MSWINDOWS}
var
  DestDir, CurBin, OutText, Line, DllName, SrcDll, DstDll: string;
  Queue, Visited, Lines: TStringList;
  I, P: Integer;
begin
  Result := 0;
  if (Info.MSYS2BinDir = '') or (not FileExists(TargetBinary)) then Exit;

  DestDir := ExtractFileDir(ExpandFileName(TargetBinary));
  if DestDir = '' then DestDir := '.';
  ForceDirectories(DestDir);

  Queue := TStringList.Create;
  Visited := TStringList.Create;
  Lines := TStringList.Create;
  Visited.CaseSensitive := False;
  try
    Queue.Add(ExpandFileName(TargetBinary));
    Visited.Add(ExpandFileName(TargetBinary));

    if Assigned(ExtraDllNames) then
    begin
      for I := 0 to ExtraDllNames.Count - 1 do
      begin
        DllName := Trim(ExtraDllNames[I]);
        if DllName = '' then Continue;
        SrcDll := Info.MSYS2BinDir + PathDelim + DllName;
        if FileExists(SrcDll) then
        begin
          DstDll := DestDir + PathDelim + ExtractFileName(SrcDll);
          if (not FileExists(DstDll)) or (FileAge(SrcDll) > FileAge(DstDll)) then
          begin
            if SafeCopyBinaryFile(SrcDll, DstDll) then
            begin
              Inc(Result);
              if not Silent then
                WriteLn(Format('   [BUNDLE] MSYS2 DLL copied: %s -> %s', [ExtractFileName(SrcDll), DestDir]));
            end;
          end;
          if Visited.IndexOf(SrcDll) < 0 then
          begin
            Visited.Add(SrcDll);
            Queue.Add(SrcDll);
          end;
        end;
      end;
    end;

    if not Info.ObjdumpFound then Exit;

    while Queue.Count > 0 do
    begin
      CurBin := Queue[0];
      Queue.Delete(0);
      if RunCommandCapture(Info.ObjdumpPath, '-p "' + CurBin + '"', Info.MSYS2BinDir, OutText) <> 0 then
        Continue;
      Lines.Text := OutText;
      for I := 0 to Lines.Count - 1 do
      begin
        Line := Lines[I];
        P := Pos('DLL Name:', Line);
        if P > 0 then
        begin
          DllName := Trim(Copy(Line, P + 9, Length(Line)));
          if DllName = '' then Continue;
          SrcDll := Info.MSYS2BinDir + PathDelim + DllName;
          // Copy only DLLs originating from MSYS2BinDir (ignores Windows OS system DLLs)
          if FileExists(SrcDll) then
          begin
            DstDll := DestDir + PathDelim + DllName;
            if (not FileExists(DstDll)) or (FileAge(SrcDll) > FileAge(DstDll)) then
            begin
              if SafeCopyBinaryFile(SrcDll, DstDll) then
              begin
                Inc(Result);
                if not Silent then
                  WriteLn(Format('   [BUNDLE] MSYS2 DLL copied: %s -> %s', [DllName, DestDir]));
              end;
            end;
            if Visited.IndexOf(SrcDll) < 0 then
            begin
              Visited.Add(SrcDll);
              Queue.Add(SrcDll);
            end;
          end;
        end;
      end;
    end;
  finally
    Lines.Free;
    Visited.Free;
    Queue.Free;
  end;
end;
{$ELSE}
begin
  Result := 0;
end;
{$ENDIF}

function InstallMSYS2SystemLib(const LibName: string; const Info: TToolchainInfo;
                               out InstalledPkg, OutputLog: string): Boolean;
var
  PacmanBinDir: string;
  Code: Integer;
begin
  InstalledPkg := MapLibToMSYS2Package(LibName, Info.MSYS2Subsystem);
  OutputLog := '';
  if not Info.PacmanFound then
  begin
    OutputLog := 'MSYS2 pacman.exe not found on this system.';
    Exit(False);
  end;
  PacmanBinDir := ExtractFileDir(Info.PacmanPath);
  Code := RunCommandCapture(Info.PacmanPath, '-S --needed --noconfirm "' + InstalledPkg + '"', PacmanBinDir, OutputLog);
  Result := (Code = 0);
end;

procedure ScanPackageDirMatches(const BaseDir, PkgName: string; Depth: Integer; OutUnitPaths: TStrings);
var
  SR: TSearchRec;
  SubDir, TargetSub: string;
  FoundSub: Boolean;
begin
  if (BaseDir = '') or (not DirectoryExists(BaseDir)) or (Depth > 3) then Exit;
  if FindFirst(IncludeTrailingPathDelimiter(BaseDir) + '*', faDirectory, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') or ((SR.Attr and faDirectory) = 0) then Continue;
        SubDir := IncludeTrailingPathDelimiter(BaseDir) + SR.Name;
        if SameText(SR.Name, PkgName) then
        begin
          FoundSub := False;
          for TargetSub in ['units', 'lib', 'src', 'source'] do
          begin
            if DirectoryExists(SubDir + PathDelim + TargetSub) then
            begin
              AddUniqueStr(OutUnitPaths, SubDir + PathDelim + TargetSub);
              ScanPackageDirMatches(SubDir + PathDelim + TargetSub, '', Depth + 1, OutUnitPaths);
              FoundSub := True;
            end;
          end;
          if not FoundSub then
            AddUniqueStr(OutUnitPaths, SubDir)
          else
            AddUniqueStr(OutUnitPaths, SubDir);
        end
        else if PkgName = '' then
        begin
          // Subdirectories such as lib/x86_64-win64 inside an OPM package
          AddUniqueStr(OutUnitPaths, SubDir);
        end
        else if Depth < 2 then
          ScanPackageDirMatches(SubDir, PkgName, Depth + 1, OutUnitPaths);
      until FindNext(SR) <> 0;
    finally
      SysUtils.FindClose(SR);
    end;
  end;
end;

function ResolvePascalPackagePaths(const PkgName: string; const Info: TToolchainInfo;
                                   OutUnitPaths: TStrings; out ErrorMsg: string): Boolean;
var
  BeforeCount: Integer;
begin
  ErrorMsg := '';
  BeforeCount := OutUnitPaths.Count;
  if Info.FppkgUnitsDir <> '' then
    ScanPackageDirMatches(Info.FppkgUnitsDir, PkgName, 0, OutUnitPaths);
  if Info.LazarusOpmDir <> '' then
    ScanPackageDirMatches(Info.LazarusOpmDir, PkgName, 0, OutUnitPaths);
  if Info.FpcUnitsDir <> '' then
    ScanPackageDirMatches(Info.FpcUnitsDir, PkgName, 0, OutUnitPaths);
  Result := (OutUnitPaths.Count > BeforeCount);
  if not Result then
    ErrorMsg := Format('Free Pascal package "%s" not found in fppkg/Lazarus OPM/FPC units directories. Run "delsafec pkg add-fpc %s" or "fppkg install %s".', [PkgName, PkgName, PkgName]);
end;

function InstallFpcPackage(const PkgName: string; const Info: TToolchainInfo; var OutputLog: string): Boolean;
var
  Code: Integer;
begin
  OutputLog := '';
  if not Info.FppkgFound then
  begin
    OutputLog := 'fppkg was not found on this system.';
    Exit(False);
  end;
  Code := RunCommandCapture(Info.FppkgPath, 'install ' + PkgName, '', OutputLog);
  Result := (Code = 0);
end;

procedure PrintDoctorReport;
var
  Info: TToolchainInfo;
begin
  WriteLn('--------------------------------------------------------');
  WriteLn('   DelSafe Environment Diagnostics (delsafec --doctor)     ');
  WriteLn('--------------------------------------------------------');

  Info := DetectToolchain;

  // FPC Report
  if Info.FPCFound then
  begin
    WriteLn('[OK] Free Pascal (FPC) Found:');
    WriteLn('     Path    : ', Info.FPCPath);
    WriteLn('     Version : ', Info.FPCVersion);
  end
  else
  begin
    WriteLn('[FAIL] Free Pascal (FPC) was not found on the system.');
    {$IFDEF MSWINDOWS}
    WriteLn('       Install Lazarus or Free Pascal from: https://www.lazarus-ide.org/');
    {$ELSE}
    WriteLn('       Install Free Pascal via package manager (e.g., sudo apt install fpc)');
    {$ENDIF}
  end;

  WriteLn('');

  // GCC / C Compiler Report
  if Info.GCCFound then
  begin
    {$IFDEF MSWINDOWS}
    WriteLn('[OK] C Compiler (GCC / MSYS2) Found:');
    {$ELSE}
    WriteLn('[OK] C Compiler (GCC) Found:');
    {$ENDIF}
    WriteLn('     Path    : ', Info.GCCPath);
    WriteLn('     Version : ', Trim(Info.GCCVersion));
    if Info.MSYS2BinDir <> '' then
      WriteLn(Format('     Env     : Active MSYS2 %s (%s)', [UpperCase(Info.MSYS2Subsystem), Info.MSYS2BinDir]));
    if Info.PkgConfigFound then
      WriteLn('     pkg-cfg : ', Info.PkgConfigPath)
    else
      WriteLn('     pkg-cfg : not found (install pkgconf in MSYS2 for auto C library resolution)');
    if Info.PacmanFound then
      WriteLn('     pacman  : ', Info.PacmanPath);
  end
  else
  begin
    {$IFDEF MSWINDOWS}
    WriteLn('[WARNING] Modern GCC (MSYS2) was not detected on Windows.');
    WriteLn('          To enable C compilation via MSYS2:');
    WriteLn('          1. Install MSYS2 (https://www.msys2.org/)');
    WriteLn('          2. In MSYS2 terminal run: pacman -S mingw-w64-ucrt-x86_64-gcc');
    {$ELSE}
    WriteLn('[WARNING] Native GCC was not detected on the system.');
    WriteLn('          Install the standard build toolchain (e.g., sudo apt install build-essential).');
    {$ENDIF}
  end;

  WriteLn('');

  // Clang (LLVM / Wasm) Report
  if Info.ClangFound then
  begin
    WriteLn('[OK] Clang Compiler (LLVM / WebAssembly) Found:');
    WriteLn('     Path    : ', Info.ClangPath);
    WriteLn('     Version : ', Trim(Info.ClangVersion));
    WriteLn('     Support : Native x86_64 and WebAssembly (wasm32)');
  end
  else
  begin
    WriteLn('[WARNING] Clang not detected on the system.');
    WriteLn('          Required for WebAssembly generation (--target=wasm).');
    {$IFDEF MSWINDOWS}
    WriteLn('          In MSYS2 run: pacman -S mingw-w64-ucrt-x86_64-clang');
    {$ENDIF}
  end;

  WriteLn('');

  // Pas2JS (JavaScript) Report
  if Info.Pas2JSFound then
  begin
    WriteLn('[OK] Pas2JS Compiler (Free Pascal JavaScript) Found:');
    WriteLn('     Path    : ', Info.Pas2JSPath);
    WriteLn('     Version : ', Trim(Info.Pas2JSVersion));
    WriteLn('     Support : Web JavaScript (ECMAScript 5/6)');
  end
  else
  begin
    WriteLn('[WARNING] Pas2JS not detected on the system.');
    WriteLn('          Required for JavaScript generation (--target=js).');
  end;

  WriteLn('');
  WriteLn('[INFO] Native Package Ecosystems:');
  if Info.FppkgFound then
    WriteLn('     fppkg   : ', Info.FppkgPath)
  else
    WriteLn('     fppkg   : not found');
  if Info.FpcUnitsDir <> '' then
    WriteLn('     FPC Lib : ', Info.FpcUnitsDir);
  if Info.FppkgUnitsDir <> '' then
    WriteLn('     fppkgDir: ', Info.FppkgUnitsDir);
  if Info.LazarusOpmDir <> '' then
    WriteLn('     Laz OPM : ', Info.LazarusOpmDir);

  WriteLn('--------------------------------------------------------');
  if Info.FPCFound and Info.GCCFound and Info.ClangFound and Info.Pas2JSFound then
    WriteLn('Overall Status: Perfect! All 4 backends (Pascal, C, Wasm, and JS) are 100% operational.')
  else if Info.FPCFound and Info.GCCFound then
    WriteLn('Overall Status: Great! Native backends (Pascal and C) are operational.')
  else if Info.FPCFound then
    WriteLn('Overall Status: Operational for Pascal backend (Default).')
  else
    WriteLn('Overall Status: Attention! No native compiler configured.');
  WriteLn('--------------------------------------------------------');
end;

function CompileWithFPC(const PascalSource, OutExe: string; var OutputLog: string; ReleaseMode: Boolean = False;
                        UnitPaths: TStrings = nil; LibDirs: TStrings = nil; const UnitOutputDir: string = '';
                        CompileUnitOnly: Boolean = False): Boolean;
var
  Info: TToolchainInfo;
  Params, ExtraFlags: string;
  Code, I: Integer;
begin
  Info := DetectToolchain;
  if not Info.FPCFound then
  begin
    OutputLog := 'Free Pascal Compiler (fpc) not found on the system.';
    Exit(False);
  end;

  ExtraFlags := '';
  if Assigned(UnitPaths) then
  begin
    for I := 0 to UnitPaths.Count - 1 do
      if Trim(UnitPaths[I]) <> '' then
        ExtraFlags := ExtraFlags + Format(' -Fu"%s"', [Trim(UnitPaths[I])]);
  end;

  if Assigned(LibDirs) then
  begin
    for I := 0 to LibDirs.Count - 1 do
      if Trim(LibDirs[I]) <> '' then
        ExtraFlags := ExtraFlags + Format(' -Fl"%s"', [Trim(LibDirs[I])]);
  end;

  if Trim(UnitOutputDir) <> '' then
  begin
    ForceDirectories(Trim(UnitOutputDir));
    ExtraFlags := ExtraFlags + Format(' -FU"%s"', [Trim(UnitOutputDir)]);
  end;

  if ExtractFileDir(OutExe) <> '' then
    ForceDirectories(ExtractFileDir(OutExe));

  if CompileUnitOnly then
  begin
    if ReleaseMode then
      Params := Format('-O3 -XX -Xs -Cn%s "%s"', [ExtraFlags, PascalSource])
    else
      Params := Format('-O2 -Cn%s "%s"', [ExtraFlags, PascalSource]);
    Code := RunCommandCapture(Info.FPCPath, Params, '', OutputLog);
    Result := (Code = 0);
  end
  else
  begin
    if ReleaseMode then
      Params := Format('-O3 -XX -Xs -FE"%s" -o"%s"%s "%s"', [ExtractFileDir(OutExe), ExtractFileName(OutExe), ExtraFlags, PascalSource])
    else
      Params := Format('-O2 -FE"%s" -o"%s"%s "%s"', [ExtractFileDir(OutExe), ExtractFileName(OutExe), ExtraFlags, PascalSource]);

    Code := RunCommandCapture(Info.FPCPath, Params, '', OutputLog);
    Result := (Code = 0) and FileExists(OutExe);
  end;
end;

function CompileWithGCC(const CSource, OutExe: string; var OutputLog: string; ReleaseMode: Boolean = False;
                        IncludePaths: TStrings = nil; ExtraCSources: TStrings = nil;
                        LibDirs: TStrings = nil; Libs: TStrings = nil; ExtraCFlags: TStrings = nil): Boolean;
var
  Info: TToolchainInfo;
  Params, ExtraIncludes, ExtraSources, ExtraLibs, ExtraFlags, SharedFlag: string;
  Code, I: Integer;
begin
  Info := DetectToolchain;
  if not Info.GCCFound then
  begin
    OutputLog := 'C Compiler (GCC) not found on the system.';
    Exit(False);
  end;

  SharedFlag := '';
  if (LowerCase(ExtractFileExt(OutExe)) = '.dll') or
     (LowerCase(ExtractFileExt(OutExe)) = '.so') or
     (LowerCase(ExtractFileExt(OutExe)) = '.dylib') then
    SharedFlag := ' -shared -fPIC';

  ExtraIncludes := '';
  if Assigned(IncludePaths) then
  begin
    for I := 0 to IncludePaths.Count - 1 do
      if Trim(IncludePaths[I]) <> '' then
        ExtraIncludes := ExtraIncludes + Format(' -I"%s"', [Trim(IncludePaths[I])]);
  end;

  ExtraFlags := '';
  if Assigned(ExtraCFlags) then
  begin
    for I := 0 to ExtraCFlags.Count - 1 do
      if Trim(ExtraCFlags[I]) <> '' then
        ExtraFlags := ExtraFlags + ' ' + Trim(ExtraCFlags[I]);
  end;

  ExtraSources := '';
  if Assigned(ExtraCSources) then
  begin
    for I := 0 to ExtraCSources.Count - 1 do
      if Trim(ExtraCSources[I]) <> '' then
        ExtraSources := ExtraSources + Format(' "%s"', [Trim(ExtraCSources[I])]);
  end;

  ExtraLibs := '';
  if Assigned(LibDirs) then
  begin
    for I := 0 to LibDirs.Count - 1 do
      if Trim(LibDirs[I]) <> '' then
        ExtraLibs := ExtraLibs + Format(' -L"%s"', [Trim(LibDirs[I])]);
  end;

  if Assigned(Libs) then
  begin
    for I := 0 to Libs.Count - 1 do
      if Trim(Libs[I]) <> '' then
        ExtraLibs := ExtraLibs + Format(' -l%s', [Trim(Libs[I])]);
  end;

  if ReleaseMode then
  begin
    {$IFDEF MSWINDOWS}
    Params := Format('-O3 -flto -s%s%s%s "%s"%s -o "%s"%s -lws2_32 -lm', [SharedFlag, ExtraIncludes, ExtraFlags, CSource, ExtraSources, OutExe, ExtraLibs]);
    {$ELSE}
    Params := Format('-O3 -flto -s%s%s%s "%s"%s -o "%s"%s -pthread -lm', [SharedFlag, ExtraIncludes, ExtraFlags, CSource, ExtraSources, OutExe, ExtraLibs]);
    {$ENDIF}
  end
  else
  begin
    {$IFDEF MSWINDOWS}
    Params := Format('-O2%s%s%s "%s"%s -o "%s"%s -lws2_32 -lm', [SharedFlag, ExtraIncludes, ExtraFlags, CSource, ExtraSources, OutExe, ExtraLibs]);
    {$ELSE}
    Params := Format('-O2%s%s%s "%s"%s -o "%s"%s -pthread -lm', [SharedFlag, ExtraIncludes, ExtraFlags, CSource, ExtraSources, OutExe, ExtraLibs]);
    {$ENDIF}
  end;
  Code := RunCommandCapture(Info.GCCPath, Params, Info.MSYS2BinDir, OutputLog);
  Result := (Code = 0) and FileExists(OutExe);
end;

function CompileWithClang(const CSource, OutExe: string; var OutputLog: string; ReleaseMode: Boolean = False;
                          IncludePaths: TStrings = nil; ExtraCSources: TStrings = nil;
                          LibDirs: TStrings = nil; Libs: TStrings = nil; ExtraCFlags: TStrings = nil): Boolean;
var
  Info: TToolchainInfo;
  Params, ExtraIncludes, ExtraSources, ExtraLibs, ExtraFlags, SharedFlag: string;
  Code, I: Integer;
begin
  Info := DetectToolchain;
  if not Info.ClangFound then
  begin
    OutputLog := 'Clang compiler not found on the system.';
    Exit(False);
  end;

  SharedFlag := '';
  if (LowerCase(ExtractFileExt(OutExe)) = '.dll') or
     (LowerCase(ExtractFileExt(OutExe)) = '.so') or
     (LowerCase(ExtractFileExt(OutExe)) = '.dylib') then
    SharedFlag := ' -shared -fPIC';

  if ExtractFileDir(OutExe) <> '' then
    ForceDirectories(ExtractFileDir(OutExe));

  ExtraIncludes := '';
  if Assigned(IncludePaths) then
  begin
    for I := 0 to IncludePaths.Count - 1 do
      if Trim(IncludePaths[I]) <> '' then
        ExtraIncludes := ExtraIncludes + Format(' -I"%s"', [Trim(IncludePaths[I])]);
  end;

  ExtraFlags := '';
  if Assigned(ExtraCFlags) then
  begin
    for I := 0 to ExtraCFlags.Count - 1 do
      if Trim(ExtraCFlags[I]) <> '' then
        ExtraFlags := ExtraFlags + ' ' + Trim(ExtraCFlags[I]);
  end;

  ExtraSources := '';
  if Assigned(ExtraCSources) then
  begin
    for I := 0 to ExtraCSources.Count - 1 do
      if Trim(ExtraCSources[I]) <> '' then
        ExtraSources := ExtraSources + Format(' "%s"', [Trim(ExtraCSources[I])]);
  end;

  ExtraLibs := '';
  if Assigned(LibDirs) then
  begin
    for I := 0 to LibDirs.Count - 1 do
      if Trim(LibDirs[I]) <> '' then
        ExtraLibs := ExtraLibs + Format(' -L"%s"', [Trim(LibDirs[I])]);
  end;

  if Assigned(Libs) then
  begin
    for I := 0 to Libs.Count - 1 do
      if Trim(Libs[I]) <> '' then
        ExtraLibs := ExtraLibs + Format(' -l%s', [Trim(Libs[I])]);
  end;

  if ReleaseMode then
  begin
    {$IFDEF MSWINDOWS}
    Params := Format('-O3 -flto -s%s%s%s "%s"%s -o "%s"%s -lws2_32 -lm', [SharedFlag, ExtraIncludes, ExtraFlags, CSource, ExtraSources, OutExe, ExtraLibs]);
    {$ELSE}
    Params := Format('-O3 -flto -s%s%s%s "%s"%s -o "%s"%s -pthread -lm', [SharedFlag, ExtraIncludes, ExtraFlags, CSource, ExtraSources, OutExe, ExtraLibs]);
    {$ENDIF}
  end
  else
  begin
    {$IFDEF MSWINDOWS}
    Params := Format('-O2%s%s%s "%s"%s -o "%s"%s -lws2_32 -lm', [SharedFlag, ExtraIncludes, ExtraFlags, CSource, ExtraSources, OutExe, ExtraLibs]);
    {$ELSE}
    Params := Format('-O2%s%s%s "%s"%s -o "%s"%s -pthread -lm', [SharedFlag, ExtraIncludes, ExtraFlags, CSource, ExtraSources, OutExe, ExtraLibs]);
    {$ENDIF}
  end;
  Code := RunCommandCapture(Info.ClangPath, Params, Info.MSYS2BinDir, OutputLog);
  Result := (Code = 0) and FileExists(OutExe);
end;

function CompileWithC(const CompilerType: string; const CSource, OutExe: string; var OutputLog: string; ReleaseMode: Boolean = False;
                      IncludePaths: TStrings = nil; ExtraCSources: TStrings = nil;
                      LibDirs: TStrings = nil; Libs: TStrings = nil; ExtraCFlags: TStrings = nil): Boolean;
begin
  if SameText(CompilerType, 'clang') then
    Result := CompileWithClang(CSource, OutExe, OutputLog, ReleaseMode, IncludePaths, ExtraCSources, LibDirs, Libs, ExtraCFlags)
  else
    Result := CompileWithGCC(CSource, OutExe, OutputLog, ReleaseMode, IncludePaths, ExtraCSources, LibDirs, Libs, ExtraCFlags);
end;

function CompileWithClangWasm(const CSource, OutWasm: string; var OutputLog: string; ReleaseMode: Boolean = False): Boolean;
var
  Info: TToolchainInfo;
  Params: string;
  Code: Integer;
begin
  Info := DetectToolchain;
  if not Info.ClangFound then
  begin
    OutputLog := 'Clang compiler not found on the system. Required to compile WebAssembly (wasm32).' + LineEnding +
                 'Install Clang in MSYS2 with: pacman -S mingw-w64-ucrt-x86_64-clang mingw-w64-ucrt-x86_64-lld';
    Exit(False);
  end;

  if ExtractFileDir(OutWasm) <> '' then
    ForceDirectories(ExtractFileDir(OutWasm));

  if ReleaseMode then
    Params := Format('--target=wasm32 -O3 -flto -nostdlib -Wl,--no-entry -Wl,--export-all -o "%s" "%s"', [OutWasm, CSource])
  else
    Params := Format('--target=wasm32 -O2 -nostdlib -Wl,--no-entry -Wl,--export-all -o "%s" "%s"', [OutWasm, CSource]);

  Code := RunCommandCapture(Info.ClangPath, Params, Info.MSYS2BinDir, OutputLog);
  Result := (Code = 0) and FileExists(OutWasm);
end;

function CompileWithPas2JS(const PascalSource, OutJS: string; var OutputLog: string; ReleaseMode: Boolean = False;
                           UnitPaths: TStrings = nil): Boolean;
var
  Info: TToolchainInfo;
  Params, ExtraFlags, Pas2JSRtlSrc, DestRtl: string;
  Code, I: Integer;
  SrcStream, DstStream: TFileStream;
begin
  Info := DetectToolchain;
  if not Info.Pas2JSFound then
  begin
    OutputLog := 'Pas2JS compiler not found on the system. Required to compile to JavaScript.';
    Exit(False);
  end;

  if ExtractFileDir(OutJS) <> '' then
    ForceDirectories(ExtractFileDir(OutJS));

  ExtraFlags := '';
  if Assigned(UnitPaths) then
  begin
    for I := 0 to UnitPaths.Count - 1 do
      if Trim(UnitPaths[I]) <> '' then
        ExtraFlags := ExtraFlags + Format(' -Fu"%s"', [Trim(UnitPaths[I])]);
  end;

  if ReleaseMode then
    Params := Format('-Jc -O1%s -o"%s" "%s"', [ExtraFlags, OutJS, PascalSource])
  else
    Params := Format('-Jc%s -o"%s" "%s"', [ExtraFlags, OutJS, PascalSource]);

  Code := RunCommandCapture(Info.Pas2JSPath, Params, '', OutputLog);
  Result := (Code = 0) and FileExists(OutJS);

  if Result then
  begin
    Pas2JSRtlSrc := ExtractFileDir(ExtractFileDir(Info.Pas2JSPath)) + PathDelim + 'packages' + PathDelim + 'rtl' + PathDelim + 'src' + PathDelim + 'rtl.js';
    if FileExists(Pas2JSRtlSrc) then
    begin
      DestRtl := ExtractFileDir(OutJS);
      if DestRtl <> '' then
        DestRtl := DestRtl + PathDelim + 'rtl.js'
      else
        DestRtl := 'rtl.js';
      if not FileExists(DestRtl) then
      begin
        try
          SrcStream := TFileStream.Create(Pas2JSRtlSrc, fmOpenRead or fmShareDenyNone);
          try
            DstStream := TFileStream.Create(DestRtl, fmCreate);
            try
              DstStream.CopyFrom(SrcStream, SrcStream.Size);
            finally
              DstStream.Free;
            end;
          finally
            SrcStream.Free;
          end;
        except
          // Do not abort if copying rtl.js fails
        end;
      end;
    end;
  end;
end;

function GenerateWasmHtmlWrapper(const WasmFileName, OutHtmlFile: string): Boolean;
var
  Lines: TStringList;
  WasmBase: string;
begin
  Result := False;
  WasmBase := ExtractFileName(WasmFileName);
  Lines := TStringList.Create;
  try
    Lines.Add('<!DOCTYPE html>');
    Lines.Add('<html lang="en">');
    Lines.Add('<head>');
    Lines.Add('  <meta charset="UTF-8">');
    Lines.Add('  <title>DelSafe WebAssembly Runner</title>');
    Lines.Add('  <style>');
    Lines.Add('    body { font-family: monospace; background: #1e1e2e; color: #cdd6f4; padding: 25px; line-height: 1.5; }');
    Lines.Add('    h1 { color: #89b4fa; }');
    Lines.Add('    pre { background: #11111b; padding: 15px; border-radius: 8px; border: 1px solid #313244; color: #a6e3a1; overflow-x: auto; }');
    Lines.Add('  </style>');
    Lines.Add('</head>');
    Lines.Add('<body>');
    Lines.Add('  <h1>DelSafe WebAssembly (Wasm) Runner</h1>');
    Lines.Add('  <p>Wasm Module: <b>' + WasmBase + '</b></p>');
    Lines.Add('  <pre id="output">Initializing WebAssembly...</pre>');
    Lines.Add('  <script>');
    Lines.Add('    const log = (msg) => {');
    Lines.Add('      document.getElementById("output").textContent += "\n" + msg;');
    Lines.Add('      console.log(msg);');
    Lines.Add('    };');
    Lines.Add('    WebAssembly.instantiateStreaming(fetch("' + WasmBase + '"))');
    Lines.Add('      .then(obj => {');
    Lines.Add('        log("[OK] WebAssembly module loaded successfully!");');
    Lines.Add('        const exp = Object.keys(obj.instance.exports);');
    Lines.Add('        log("Available exports: " + exp.join(", "));');
    Lines.Add('        window.delsafeWasm = obj.instance.exports;');
    Lines.Add('        log("Object available in console at: window.delsafeWasm");');
    Lines.Add('      })');
    Lines.Add('      .catch(err => log("[ERROR] Failed to instantiate WebAssembly: " + err));');
    Lines.Add('  </script>');
    Lines.Add('</body>');
    Lines.Add('</html>');
    if ExtractFileDir(OutHtmlFile) <> '' then
      ForceDirectories(ExtractFileDir(OutHtmlFile));
    Lines.SaveToFile(OutHtmlFile);
    Result := True;
  finally
    Lines.Free;
  end;
end;

function GenerateJSHtmlWrapper(const JSFileName, OutHtmlFile: string): Boolean;
var
  Lines: TStringList;
  JSBase: string;
begin
  Result := False;
  JSBase := ExtractFileName(JSFileName);
  Lines := TStringList.Create;
  try
    Lines.Add('<!DOCTYPE html>');
    Lines.Add('<html lang="en">');
    Lines.Add('<head>');
    Lines.Add('  <meta charset="UTF-8">');
    Lines.Add('  <title>DelSafe JavaScript (Pas2JS) Runner</title>');
    Lines.Add('  <style>');
    Lines.Add('    body { font-family: monospace; background: #1e1e2e; color: #cdd6f4; padding: 25px; line-height: 1.5; }');
    Lines.Add('    h1 { color: #a6e3a1; }');
    Lines.Add('    pre { background: #11111b; padding: 15px; border-radius: 8px; border: 1px solid #313244; color: #89b4fa; }');
    Lines.Add('  </style>');
    Lines.Add('</head>');
    Lines.Add('<body>');
    Lines.Add('  <h1>DelSafe JavaScript (Pas2JS) Runner</h1>');
    Lines.Add('  <p>Script: <b>' + JSBase + '</b></p>');
    Lines.Add('  <pre id="output">Initializing JavaScript (Pas2JS)...</pre>');
    Lines.Add('  <script src="rtl.js"></script>');
    Lines.Add('  <script src="' + JSBase + '"></script>');
    Lines.Add('  <script>');
    Lines.Add('    const outElem = document.getElementById("output");');
    Lines.Add('    if (typeof rtl !== ''undefined'') {');
    Lines.Add('      try { rtl.run(); } catch (e) { console.warn("rtl.run warning:", e); }');
    Lines.Add('    }');
    Lines.Add('    if (window.pas) {');
    Lines.Add('      const mods = Object.keys(window.pas);');
    Lines.Add('      outElem.textContent = "[OK] Script loaded successfully!\nModules available in window.pas: " + mods.join(", ");');
    Lines.Add('      console.log("Pas2JS modules available in window.pas:", window.pas);');
    Lines.Add('    } else {');
    Lines.Add('      outElem.textContent = "[OK] Script loaded. Open DevTools (F12) to interact.";');
    Lines.Add('    }');
    Lines.Add('  </script>');
    Lines.Add('</body>');
    Lines.Add('</html>');
    if ExtractFileDir(OutHtmlFile) <> '' then
      ForceDirectories(ExtractFileDir(OutHtmlFile));
    Lines.SaveToFile(OutHtmlFile);
    Result := True;
  finally
    Lines.Free;
  end;
end;

end.
