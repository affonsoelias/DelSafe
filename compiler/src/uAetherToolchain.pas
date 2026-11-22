unit uAetherToolchain;

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

    ClangFound: Boolean;
    ClangPath: string;
    ClangVersion: string;

    Pas2JSFound: Boolean;
    Pas2JSPath: string;
    Pas2JSVersion: string;
  end;

function DetectToolchain: TToolchainInfo;
procedure PrintDoctorReport;
function RunCommandCapture(const ExePath, Params: string; const ExtraPathDir: string; var OutText: string): Integer;
function CompileWithFPC(const PascalSource, OutExe: string; var OutputLog: string; ReleaseMode: Boolean = False;
                        UnitPaths: TStrings = nil; LibDirs: TStrings = nil; const UnitOutputDir: string = '';
                        CompileUnitOnly: Boolean = False): Boolean;
function CompileWithGCC(const CSource, OutExe: string; var OutputLog: string; ReleaseMode: Boolean = False;
                        IncludePaths: TStrings = nil; ExtraCSources: TStrings = nil;
                        LibDirs: TStrings = nil; Libs: TStrings = nil): Boolean;
function CompileWithClang(const CSource, OutExe: string; var OutputLog: string; ReleaseMode: Boolean = False;
                          IncludePaths: TStrings = nil; ExtraCSources: TStrings = nil;
                          LibDirs: TStrings = nil; Libs: TStrings = nil): Boolean;
function CompileWithC(const CompilerType: string; const CSource, OutExe: string; var OutputLog: string; ReleaseMode: Boolean = False;
                      IncludePaths: TStrings = nil; ExtraCSources: TStrings = nil;
                      LibDirs: TStrings = nil; Libs: TStrings = nil): Boolean;
function CompileWithClangWasm(const CSource, OutWasm: string; var OutputLog: string; ReleaseMode: Boolean = False): Boolean;
function CompileWithPas2JS(const PascalSource, OutJS: string; var OutputLog: string; ReleaseMode: Boolean = False;
                           UnitPaths: TStrings = nil): Boolean;
function GenerateWasmHtmlWrapper(const WasmFileName, OutHtmlFile: string): Boolean;
function GenerateJSHtmlWrapper(const JSFileName, OutHtmlFile: string): Boolean;

implementation

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
    Proc.CommandLine := '"' + ExePath + '" ' + Params;
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

  // --- 1. Deteccao do Free Pascal (FPC) ---
  {$IFDEF MSWINDOWS}
  SetLength(CandidatePaths, 3);
  CandidatePaths[0] := 'fpc.exe'; // PATH do sistema
  CandidatePaths[1] := 'C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe';
  CandidatePaths[2] := 'C:\fpc\3.2.2\bin\i386-win32\fpc.exe';
  {$ELSE}
  SetLength(CandidatePaths, 3);
  CandidatePaths[0] := 'fpc'; // PATH do sistema Linux/macOS
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

  // --- 2. Deteccao do GCC (MSYS2 no Windows / Nativo no Linux e macOS) ---
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
      // No Windows: para MSYS2, adicionar o diretorio bin correspondente
      {$IFDEF MSWINDOWS}
      if Pos('msys', LowerCase(P)) > 0 then
        Result.MSYS2BinDir := ExtractFileDir(P)
      else
        Result.MSYS2BinDir := '';
      {$ELSE}
      Result.MSYS2BinDir := '';
      {$ENDIF}

      Code := RunCommandCapture(P, '--version', Result.MSYS2BinDir, OutText);
      // Ignora o stub antigo de 2.95 do FPC
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

  // --- 3. Deteccao do Clang (LLVM / WebAssembly wasm32) ---
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

  // --- 4. Deteccao do Pas2JS (Compilador Web JavaScript Free Pascal) ---
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
end;

procedure PrintDoctorReport;
var
  Info: TToolchainInfo;
begin
  WriteLn('--------------------------------------------------------');
  WriteLn('   Diagnostico do Ambiente Aether (aetherc --doctor)    ');
  WriteLn('--------------------------------------------------------');

  Info := DetectToolchain;

  // Relatorio FPC
  if Info.FPCFound then
  begin
    WriteLn('[OK] Free Pascal (FPC) Encontrado:');
    WriteLn('     Caminho : ', Info.FPCPath);
    WriteLn('     Versao  : ', Info.FPCVersion);
  end
  else
  begin
    WriteLn('[FALHA] Free Pascal (FPC) nao foi encontrado no sistema.');
    {$IFDEF MSWINDOWS}
    WriteLn('        Instale o Lazarus ou Free Pascal em: https://www.lazarus-ide.org/');
    {$ELSE}
    WriteLn('        Instale o Free Pascal via gerenciador de pacotes (ex: sudo apt install fpc)');
    {$ENDIF}
  end;

  WriteLn('');

  // Relatorio GCC / C Compiler
  if Info.GCCFound then
  begin
    {$IFDEF MSWINDOWS}
    WriteLn('[OK] Compilador C (GCC / MSYS2) Encontrado:');
    {$ELSE}
    WriteLn('[OK] Compilador C (GCC) Encontrado:');
    {$ENDIF}
    WriteLn('     Caminho : ', Info.GCCPath);
    WriteLn('     Versao  : ', Trim(Info.GCCVersion));
    if Info.MSYS2BinDir <> '' then
      WriteLn('     Ambiente: MSYS2 UCRT64 Ativo (', Info.MSYS2BinDir, ')');
  end
  else
  begin
    {$IFDEF MSWINDOWS}
    WriteLn('[ALERTA] GCC moderno (MSYS2) nao foi detectado no Windows.');
    WriteLn('         Para habilitar compilacao C via MSYS2:');
    WriteLn('         1. Instale o MSYS2 (https://www.msys2.org/)');
    WriteLn('         2. No terminal MSYS2 rode: pacman -S mingw-w64-ucrt-x86_64-gcc');
    {$ELSE}
    WriteLn('[ALERTA] GCC nativo nao foi detectado no sistema.');
    WriteLn('         Instale o pacote padrao de compilacao (ex: sudo apt install build-essential).');
    {$ENDIF}
  end;

  WriteLn('');

  // Relatorio Clang (LLVM / Wasm)
  if Info.ClangFound then
  begin
    WriteLn('[OK] Compilador Clang (LLVM / WebAssembly) Encontrado:');
    WriteLn('     Caminho : ', Info.ClangPath);
    WriteLn('     Versao  : ', Trim(Info.ClangVersion));
    WriteLn('     Suporte : Nativo x86_64 e WebAssembly (wasm32)');
  end
  else
  begin
    WriteLn('[AVISO] Clang nao detectado no sistema.');
    WriteLn('        Necessario para geracao de WebAssembly (--target=wasm).');
    {$IFDEF MSWINDOWS}
    WriteLn('        No MSYS2 rode: pacman -S mingw-w64-ucrt-x86_64-clang');
    {$ENDIF}
  end;

  WriteLn('');

  // Relatorio Pas2JS (JavaScript)
  if Info.Pas2JSFound then
  begin
    WriteLn('[OK] Compilador Pas2JS (Free Pascal JavaScript) Encontrado:');
    WriteLn('     Caminho : ', Info.Pas2JSPath);
    WriteLn('     Versao  : ', Trim(Info.Pas2JSVersion));
    WriteLn('     Suporte : Web JavaScript (ECMAScript 5/6)');
  end
  else
  begin
    WriteLn('[AVISO] Pas2JS nao detectado no sistema.');
    WriteLn('        Necessario para geracao de JavaScript (--target=js).');
  end;

  WriteLn('--------------------------------------------------------');
  if Info.FPCFound and Info.GCCFound and Info.ClangFound and Info.Pas2JSFound then
    WriteLn('Status Geral: Perfeito! Todos os 4 backends (Pascal, C, Wasm e JS) estao 100% operacionais.')
  else if Info.FPCFound and Info.GCCFound then
    WriteLn('Status Geral: Excelente! Backends nativos (Pascal e C) operacionais.')
  else if Info.FPCFound then
    WriteLn('Status Geral: Operacional para backend Pascal (Padrao).')
  else
    WriteLn('Status Geral: Atencao! Nao ha compilador nativo configurado.');
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
    OutputLog := 'Free Pascal Compiler (fpc) nao encontrado no sistema.';
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
                        LibDirs: TStrings = nil; Libs: TStrings = nil): Boolean;
var
  Info: TToolchainInfo;
  Params, ExtraIncludes, ExtraSources, ExtraLibs: string;
  Code, I: Integer;
begin
  Info := DetectToolchain;
  if not Info.GCCFound then
  begin
    OutputLog := 'Compilador C (GCC) nao encontrado no sistema.';
    Exit(False);
  end;

  ExtraIncludes := '';
  if Assigned(IncludePaths) then
  begin
    for I := 0 to IncludePaths.Count - 1 do
      if Trim(IncludePaths[I]) <> '' then
        ExtraIncludes := ExtraIncludes + Format(' -I"%s"', [Trim(IncludePaths[I])]);
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
    Params := Format('-O3 -flto -s%s "%s"%s -o "%s"%s -lws2_32 -lm', [ExtraIncludes, CSource, ExtraSources, OutExe, ExtraLibs]);
    {$ELSE}
    Params := Format('-O3 -flto -s%s "%s"%s -o "%s"%s -lm', [ExtraIncludes, CSource, ExtraSources, OutExe, ExtraLibs]);
    {$ENDIF}
  end
  else
  begin
    {$IFDEF MSWINDOWS}
    Params := Format('-O2%s "%s"%s -o "%s"%s -lws2_32 -lm', [ExtraIncludes, CSource, ExtraSources, OutExe, ExtraLibs]);
    {$ELSE}
    Params := Format('-O2%s "%s"%s -o "%s"%s -lm', [ExtraIncludes, CSource, ExtraSources, OutExe, ExtraLibs]);
    {$ENDIF}
  end;
  Code := RunCommandCapture(Info.GCCPath, Params, Info.MSYS2BinDir, OutputLog);
  Result := (Code = 0) and FileExists(OutExe);
end;

function CompileWithClang(const CSource, OutExe: string; var OutputLog: string; ReleaseMode: Boolean = False;
                          IncludePaths: TStrings = nil; ExtraCSources: TStrings = nil;
                          LibDirs: TStrings = nil; Libs: TStrings = nil): Boolean;
var
  Info: TToolchainInfo;
  Params, ExtraIncludes, ExtraSources, ExtraLibs: string;
  Code, I: Integer;
begin
  Info := DetectToolchain;
  if not Info.ClangFound then
  begin
    OutputLog := 'Compilador Clang nao encontrado no sistema.';
    Exit(False);
  end;

  if ExtractFileDir(OutExe) <> '' then
    ForceDirectories(ExtractFileDir(OutExe));

  ExtraIncludes := '';
  if Assigned(IncludePaths) then
  begin
    for I := 0 to IncludePaths.Count - 1 do
      if Trim(IncludePaths[I]) <> '' then
        ExtraIncludes := ExtraIncludes + Format(' -I"%s"', [Trim(IncludePaths[I])]);
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
    Params := Format('-O3 -flto -s%s "%s"%s -o "%s"%s -lws2_32 -lm', [ExtraIncludes, CSource, ExtraSources, OutExe, ExtraLibs]);
    {$ELSE}
    Params := Format('-O3 -flto -s%s "%s"%s -o "%s"%s -lm', [ExtraIncludes, CSource, ExtraSources, OutExe, ExtraLibs]);
    {$ENDIF}
  end
  else
  begin
    {$IFDEF MSWINDOWS}
    Params := Format('-O2%s "%s"%s -o "%s"%s -lws2_32 -lm', [ExtraIncludes, CSource, ExtraSources, OutExe, ExtraLibs]);
    {$ELSE}
    Params := Format('-O2%s "%s"%s -o "%s"%s -lm', [ExtraIncludes, CSource, ExtraSources, OutExe, ExtraLibs]);
    {$ENDIF}
  end;
  Code := RunCommandCapture(Info.ClangPath, Params, Info.MSYS2BinDir, OutputLog);
  Result := (Code = 0) and FileExists(OutExe);
end;

function CompileWithC(const CompilerType: string; const CSource, OutExe: string; var OutputLog: string; ReleaseMode: Boolean = False;
                      IncludePaths: TStrings = nil; ExtraCSources: TStrings = nil;
                      LibDirs: TStrings = nil; Libs: TStrings = nil): Boolean;
begin
  if SameText(CompilerType, 'clang') then
    Result := CompileWithClang(CSource, OutExe, OutputLog, ReleaseMode, IncludePaths, ExtraCSources, LibDirs, Libs)
  else
    Result := CompileWithGCC(CSource, OutExe, OutputLog, ReleaseMode, IncludePaths, ExtraCSources, LibDirs, Libs);
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
    OutputLog := 'Compilador Clang nao encontrado no sistema. Necessario para compilar WebAssembly (wasm32).' + LineEnding +
                 'Instale o Clang no MSYS2 com: pacman -S mingw-w64-ucrt-x86_64-clang mingw-w64-ucrt-x86_64-lld';
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
    OutputLog := 'Compilador Pas2JS nao encontrado no sistema. Necessario para compilar para JavaScript.';
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
          // Nao interromper caso ocorra erro ao copiar rtl.js
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
    Lines.Add('<html lang="pt-BR">');
    Lines.Add('<head>');
    Lines.Add('  <meta charset="UTF-8">');
    Lines.Add('  <title>Aether WebAssembly Runner</title>');
    Lines.Add('  <style>');
    Lines.Add('    body { font-family: monospace; background: #1e1e2e; color: #cdd6f4; padding: 25px; line-height: 1.5; }');
    Lines.Add('    h1 { color: #89b4fa; }');
    Lines.Add('    pre { background: #11111b; padding: 15px; border-radius: 8px; border: 1px solid #313244; color: #a6e3a1; overflow-x: auto; }');
    Lines.Add('  </style>');
    Lines.Add('</head>');
    Lines.Add('<body>');
    Lines.Add('  <h1>Aether WebAssembly (Wasm) Runner</h1>');
    Lines.Add('  <p>Modulo Wasm: <b>' + WasmBase + '</b></p>');
    Lines.Add('  <pre id="output">Inicializando WebAssembly...</pre>');
    Lines.Add('  <script>');
    Lines.Add('    const log = (msg) => {');
    Lines.Add('      document.getElementById("output").textContent += "\n" + msg;');
    Lines.Add('      console.log(msg);');
    Lines.Add('    };');
    Lines.Add('    WebAssembly.instantiateStreaming(fetch("' + WasmBase + '"))');
    Lines.Add('      .then(obj => {');
    Lines.Add('        log("[OK] Modulo WebAssembly carregado com sucesso!");');
    Lines.Add('        const exp = Object.keys(obj.instance.exports);');
    Lines.Add('        log("Exports disponiveis: " + exp.join(", "));');
    Lines.Add('        window.aetherWasm = obj.instance.exports;');
    Lines.Add('        log("Objeto disponivel no console em: window.aetherWasm");');
    Lines.Add('      })');
    Lines.Add('      .catch(err => log("[ERRO] Falha ao instanciar WebAssembly: " + err));');
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
    Lines.Add('<html lang="pt-BR">');
    Lines.Add('<head>');
    Lines.Add('  <meta charset="UTF-8">');
    Lines.Add('  <title>Aether JavaScript (Pas2JS) Runner</title>');
    Lines.Add('  <style>');
    Lines.Add('    body { font-family: monospace; background: #1e1e2e; color: #cdd6f4; padding: 25px; line-height: 1.5; }');
    Lines.Add('    h1 { color: #a6e3a1; }');
    Lines.Add('    pre { background: #11111b; padding: 15px; border-radius: 8px; border: 1px solid #313244; color: #89b4fa; }');
    Lines.Add('  </style>');
    Lines.Add('</head>');
    Lines.Add('<body>');
    Lines.Add('  <h1>Aether JavaScript (Pas2JS) Runner</h1>');
    Lines.Add('  <p>Script: <b>' + JSBase + '</b></p>');
    Lines.Add('  <pre id="output">Inicializando JavaScript (Pas2JS)...</pre>');
    Lines.Add('  <script src="rtl.js"></script>');
    Lines.Add('  <script src="' + JSBase + '"></script>');
    Lines.Add('  <script>');
    Lines.Add('    const outElem = document.getElementById("output");');
    Lines.Add('    if (typeof rtl !== ''undefined'') {');
    Lines.Add('      try { rtl.run(); } catch (e) { console.warn("rtl.run aviso:", e); }');
    Lines.Add('    }');
    Lines.Add('    if (window.pas) {');
    Lines.Add('      const mods = Object.keys(window.pas);');
    Lines.Add('      outElem.textContent = "[OK] Script carregado com sucesso!\nModulos disponiveis em window.pas: " + mods.join(", ");');
    Lines.Add('      console.log("Modulos Pas2JS disponiveis em window.pas:", window.pas);');
    Lines.Add('    } else {');
    Lines.Add('      outElem.textContent = "[OK] Script carregado. Abra o DevTools (F12) para interagir.";');
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
