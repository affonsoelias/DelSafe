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
  end;

function DetectToolchain: TToolchainInfo;
procedure PrintDoctorReport;
function RunCommandCapture(const ExePath, Params: string; const ExtraPathDir: string; var OutText: string): Integer;
function CompileWithFPC(const PascalSource, OutExe: string; var OutputLog: string; ReleaseMode: Boolean = False;
                        UnitPaths: TStrings = nil; LibDirs: TStrings = nil): Boolean;
function CompileWithGCC(const CSource, OutExe: string; var OutputLog: string; ReleaseMode: Boolean = False;
                        IncludePaths: TStrings = nil; ExtraCSources: TStrings = nil;
                        LibDirs: TStrings = nil; Libs: TStrings = nil): Boolean;

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
    WriteLn('[OK] Compilador C (GCC / Clang Nativo) Encontrado:');
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
    WriteLn('[ALERTA] GCC/Clang nativo nao foi detectado no sistema.');
    WriteLn('         Instale o pacote padrao de compilacao (ex: sudo apt install build-essential).');
    {$ENDIF}
  end;

  WriteLn('--------------------------------------------------------');
  if Info.FPCFound and Info.GCCFound then
    WriteLn('Status Geral: Perfeito! Ambos os backends (Pascal e C) estao operacionais.')
  else if Info.FPCFound then
    WriteLn('Status Geral: Operacional para backend Pascal (Padrao).')
  else
    WriteLn('Status Geral: Atencao! Nao ha compilador nativo configurado.');
  WriteLn('--------------------------------------------------------');
end;

function CompileWithFPC(const PascalSource, OutExe: string; var OutputLog: string; ReleaseMode: Boolean = False;
                        UnitPaths: TStrings = nil; LibDirs: TStrings = nil): Boolean;
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

  if ReleaseMode then
    Params := Format('-O3 -XX -Xs -FE"%s" -o"%s"%s "%s"', [ExtractFileDir(OutExe), ExtractFileName(OutExe), ExtraFlags, PascalSource])
  else
    Params := Format('-O2 -FE"%s" -o"%s"%s "%s"', [ExtractFileDir(OutExe), ExtractFileName(OutExe), ExtraFlags, PascalSource]);

  Code := RunCommandCapture(Info.FPCPath, Params, '', OutputLog);
  Result := (Code = 0) and FileExists(OutExe);
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

end.
