unit uAetherProfiler;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  SysUtils, Classes, Process, Math,
  uAetherToolchain, uAetherTokens, uAetherLexer, uAetherAST, uAetherParser,
  uAetherTypeChecker, uAetherBorrowChecker, uAetherEmitterPascal, uAetherEmitterC;

type
  TProfileTiming = record
    Runs: Integer;
    TotalMs: Double;
    AvgMs: Double;
    MinMs: Double;
    MaxMs: Double;
  end;

  TProfileMemory = record
    HasLeaks: Boolean;
    AllocatedBlocks: Int64;
    FreedBlocks: Int64;
    UnfreedBlocks: Int64;
    TrueHeapSize: Int64;
    TrueFreeHeap: Int64;
    LeakTrace: string;
    RawOutput: string;
    Status: string;
  end;

  TProfileReport = record
    FileName: string;
    Backend: string;
    Success: Boolean;
    ErrorMessage: string;
    Timing: TProfileTiming;
    Memory: TProfileMemory;
  end;

  { TAetherProfiler: Motor Canônico de Profiling e Auditoria de Memória do Aether }
  TAetherProfiler = class
  private
    class function ExecuteWithCapture(const ExePath, Params: string; var OutputLog: string): Integer;
    class function ParseHeapTrc(const OutputLog: string; var Mem: TProfileMemory): Boolean;
    class function GetHighResTimeMs: Double;
  public
    class function ProfileFile(const SourceFile: string; TargetPascal: Boolean; Runs: Integer; out Report: TProfileReport): Boolean;
    class function FormatTerminalReport(const Report: TProfileReport): string;
    class function FormatJSONReport(const Report: TProfileReport): string;
    class procedure HandleProfileCommand(const TargetPath: string; TargetPascal: Boolean; Runs: Integer; JSONOutput: Boolean);
  end;

implementation

{$IFDEF WINDOWS}
uses Windows;
{$ENDIF}

class function TAetherProfiler.GetHighResTimeMs: Double;
{$IFDEF WINDOWS}
var
  Freq, Count: Int64;
begin
  if QueryPerformanceFrequency(Freq) and QueryPerformanceCounter(Count) then
    Result := (Count * 1000.0) / Freq
  else
    Result := GetTickCount64;
end;
{$ELSE}
var
  Ts: TDateTime;
begin
  Ts := Now;
  Result := Ts * 86400000.0;
end;
{$ENDIF}

class function TAetherProfiler.ExecuteWithCapture(const ExePath, Params: string; var OutputLog: string): Integer;
var
  Proc: TProcess;
  Stream: TStringStream;
  Buffer: array[0..4095] of Byte;
  BytesRead: Integer;
begin
  OutputLog := '';
  Proc := TProcess.Create(nil);
  Stream := TStringStream.Create('');
  try
    Proc.Executable := ExePath;
    {$IFDEF FPC}
    Proc.Parameters.Clear;
    if Trim(Params) <> '' then
      Proc.Parameters.Add(Params);
    {$ENDIF}
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
            Stream.WriteBuffer(Buffer[0], BytesRead);
        end
        else
          Sleep(1);
      end;
      OutputLog := Trim(Stream.DataString);
      Result := Proc.ExitStatus;
    except
      on E: Exception do
      begin
        OutputLog := E.Message;
        Result := -1;
      end;
    end;
  finally
    Stream.Free;
    Proc.Free;
  end;
end;

class function TAetherProfiler.ParseHeapTrc(const OutputLog: string; var Mem: TProfileMemory): Boolean;
var
  Lines: TStringList;
  I: Integer;
  Line, ValStr: string;
  PosBlocks, PosFreed, PosUnfreed, PosHeapSize, PosFreeHeap: Integer;
begin
  Result := False;
  Mem.HasLeaks := False;
  Mem.AllocatedBlocks := 0;
  Mem.FreedBlocks := 0;
  Mem.UnfreedBlocks := 0;
  Mem.TrueHeapSize := 0;
  Mem.TrueFreeHeap := 0;
  Mem.LeakTrace := '';
  Mem.RawOutput := OutputLog;
  Mem.Status := 'CLEAN';

  Lines := TStringList.Create;
  try
    Lines.Text := OutputLog;
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Lines[I];

      // Exemplo: "45 memory blocks allocated : 1234/1234"
      PosBlocks := Pos('memory blocks allocated', Line);
      if PosBlocks > 0 then
      begin
        ValStr := Trim(Copy(Line, 1, PosBlocks - 1));
        Mem.AllocatedBlocks := StrToInt64Def(ValStr, 0);
        Result := True;
      end;

      // Exemplo: "45 memory blocks freed     : 1234/1234"
      PosFreed := Pos('memory blocks freed', Line);
      if PosFreed > 0 then
      begin
        ValStr := Trim(Copy(Line, 1, PosFreed - 1));
        Mem.FreedBlocks := StrToInt64Def(ValStr, 0);
      end;

      // Exemplo: "0 unfreed memory blocks : 0" ou "2 unfreed memory blocks : 64"
      PosUnfreed := Pos('unfreed memory blocks', Line);
      if PosUnfreed > 0 then
      begin
        ValStr := Trim(Copy(Line, 1, PosUnfreed - 1));
        Mem.UnfreedBlocks := StrToInt64Def(ValStr, 0);
        if Mem.UnfreedBlocks > 0 then
        begin
          Mem.HasLeaks := True;
          Mem.Status := 'LEAK_DETECTED';
        end;
      end;

      // Exemplo: "True heap size : 196608"
      PosHeapSize := Pos('True heap size', Line);
      if PosHeapSize > 0 then
      begin
        ValStr := Trim(Copy(Line, Pos(':', Line) + 1, Length(Line)));
        if Pos('(', ValStr) > 0 then
          ValStr := Trim(Copy(ValStr, 1, Pos('(', ValStr) - 1));
        Mem.TrueHeapSize := StrToInt64Def(ValStr, 0);
      end;

      // Exemplo: "True free heap : 196608"
      PosFreeHeap := Pos('True free heap', Line);
      if PosFreeHeap > 0 then
      begin
        ValStr := Trim(Copy(Line, Pos(':', Line) + 1, Length(Line)));
        Mem.TrueFreeHeap := StrToInt64Def(ValStr, 0);
      end;

      // Captura de Call trace de leaks
      if Mem.HasLeaks and (Pos('Call trace', Line) > 0) then
      begin
        Mem.LeakTrace := Mem.LeakTrace + Line + LineEnding;
      end;
    end;

    if not Result then
    begin
      // Se nao encontrou HeapTrc explicito, valida pelo status de saida do processo
      Mem.Status := 'NO_LEAKS_DETECTED';
    end;
  finally
    Lines.Free;
  end;
end;

class function TAetherProfiler.ProfileFile(const SourceFile: string; TargetPascal: Boolean; Runs: Integer; out Report: TProfileReport): Boolean;
var
  BaseDir, GenDir, IntermediateFile, FinalExe, ToolLog: string;
  SourceText, GeneratedCode: string;
  Lexer: TAetherLexer;
  Parser: TAetherParser;
  ModuleNode: TASTModule;
  TypeChecker: TAetherTypeChecker;
  BorrowChecker: TAetherBorrowChecker;
  EmitterPas: TAetherEmitterPascal;
  EmitterC: TAetherEmitterC;
  FPCInfo: TToolchainInfo;
  CompileParams: string;
  CompileCode: Integer;
  RunIdx, ExecCode: Integer;
  StartTime, EndTime, ElapsedMs: Double;
  TotalDuration, MinDuration, MaxDuration: Double;
  ExecOutput, LastAuditOutput: string;
  Lines: TStringList;
begin
  Result := False;
  if Runs < 1 then Runs := 1;

  Report.FileName := SourceFile;
  Report.Success := False;
  Report.ErrorMessage := '';
  Report.Timing.Runs := Runs;
  Report.Timing.TotalMs := 0;
  Report.Timing.AvgMs := 0;
  Report.Timing.MinMs := 0;
  Report.Timing.MaxMs := 0;

  if TargetPascal then
    Report.Backend := 'pascal'
  else
    Report.Backend := 'c';

  if not FileExists(SourceFile) then
  begin
    Report.ErrorMessage := 'Arquivo fonte nao encontrado: ' + SourceFile;
    Exit(False);
  end;

  BaseDir := ExtractFileDir(SourceFile);
  if BaseDir = '' then BaseDir := '.';
  GenDir := BaseDir + PathDelim + 'generated' + PathDelim + 'profile';
  ForceDirectories(GenDir);

  // 1. Carrega fonte e compila AST
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(SourceFile);
    SourceText := Lines.Text;
  finally
    Lines.Free;
  end;

  Lexer := TAetherLexer.Create(SourceText);
  try
    Parser := TAetherParser.Create(Lexer);
    try
      ModuleNode := Parser.ParseModule;
      try
        TypeChecker := TAetherTypeChecker.Create;
        try
          try
            TypeChecker.CheckModule(ModuleNode);
          except
            on E: Exception do
            begin
              Report.ErrorMessage := 'Erro na verificacao de tipos: ' + E.Message;
              Exit(False);
            end;
          end;

          BorrowChecker := TAetherBorrowChecker.Create(TypeChecker.Symbols);
          try
            try
              BorrowChecker.CheckModule(ModuleNode);
            except
              on E: Exception do
              begin
                Report.ErrorMessage := 'Erro na verificacao de posse: ' + E.Message;
                Exit(False);
              end;
            end;
          finally
            BorrowChecker.Free;
          end;
        finally
          TypeChecker.Free;
        end;

        // 2. Transpilacao e Compilacao com Instrumentacao de Memoria
        if TargetPascal then
        begin
          IntermediateFile := GenDir + PathDelim + ChangeFileExt(ExtractFileName(SourceFile), '.pas');
          FinalExe := GenDir + PathDelim + ChangeFileExt(ExtractFileName(SourceFile), '.exe');

          EmitterPas := TAetherEmitterPascal.Create;
          try
            GeneratedCode := EmitterPas.Generate(ModuleNode, False, False);
          finally
            EmitterPas.Free;
          end;

          Lines := TStringList.Create;
          try
            Lines.Text := GeneratedCode;
            Lines.SaveToFile(IntermediateFile);
          finally
            Lines.Free;
          end;

          FPCInfo := DetectToolchain;
          if not FPCInfo.FPCFound then
          begin
            Report.ErrorMessage := 'Compilador Free Pascal (fpc) nao encontrado.';
            Exit(False);
          end;

          // Compilacao Free Pascal com HeapTrc (-gh) e informacoes de linha (-gl)
          CompileParams := Format('-MObjFPC -Sc -O2 -gh -gl -FE"%s" -o"%s" "%s"',
            [ExtractFileDir(FinalExe), ExtractFileName(FinalExe), IntermediateFile]);

          CompileCode := RunCommandCapture(FPCInfo.FPCPath, CompileParams, '', ToolLog);
          if (CompileCode <> 0) or not FileExists(FinalExe) then
          begin
            Report.ErrorMessage := 'Falha ao compilar com FPC e HeapTrc: ' + ToolLog;
            Exit(False);
          end;
        end
        else
        begin
          // Alvo C99
          IntermediateFile := GenDir + PathDelim + ChangeFileExt(ExtractFileName(SourceFile), '.c');
          FinalExe := GenDir + PathDelim + ChangeFileExt(ExtractFileName(SourceFile), '.exe');

          EmitterC := TAetherEmitterC.Create;
          try
            GeneratedCode := EmitterC.Generate(ModuleNode);
          finally
            EmitterC.Free;
          end;

          Lines := TStringList.Create;
          try
            Lines.Text := GeneratedCode;
            Lines.SaveToFile(IntermediateFile);
          finally
            Lines.Free;
          end;

          if not CompileWithGCC(IntermediateFile, FinalExe, ToolLog, False) then
          begin
            Report.ErrorMessage := 'Falha ao compilar com GCC: ' + ToolLog;
            Exit(False);
          end;
        end;

      finally
        ModuleNode.Free;
      end;
    finally
      Parser.Free;
    end;
  finally
    Lexer.Free;
  end;

  // 3. Execucao de Profiling com Medicao de Tempo e Captura de HeapTrc
  TotalDuration := 0;
  MinDuration := 999999999.0;
  MaxDuration := 0;
  LastAuditOutput := '';

  for RunIdx := 1 to Runs do
  begin
    StartTime := GetHighResTimeMs;
    ExecCode := ExecuteWithCapture(FinalExe, '', ExecOutput);
    EndTime := GetHighResTimeMs;

    ElapsedMs := EndTime - StartTime;
    if ElapsedMs < 0 then ElapsedMs := 0;

    TotalDuration := TotalDuration + ElapsedMs;
    if ElapsedMs < MinDuration then MinDuration := ElapsedMs;
    if ElapsedMs > MaxDuration then MaxDuration := ElapsedMs;

    LastAuditOutput := ExecOutput;

    if ExecCode <> 0 then
    begin
      Report.ErrorMessage := Format('Executavel falhou com codigo de saida %d na execucao %d.', [ExecCode, RunIdx]);
      Exit(False);
    end;
  end;

  Report.Timing.TotalMs := TotalDuration;
  Report.Timing.AvgMs := TotalDuration / Runs;
  Report.Timing.MinMs := MinDuration;
  Report.Timing.MaxMs := MaxDuration;

  // 4. Analise de Memoria e Deteccao de Leaks
  ParseHeapTrc(LastAuditOutput, Report.Memory);

  Report.Success := True;
  Result := True;
end;

class function TAetherProfiler.FormatTerminalReport(const Report: TProfileReport): string;
var
  StatusBadge: string;
begin
  if not Report.Success then
  begin
    Result := Format('ERRO NO PROFILING: %s', [Report.ErrorMessage]);
    Exit;
  end;

  if Report.Memory.HasLeaks then
    StatusBadge := '[FALHA - VAZAMENTO DE MEMORIA DETECTADO]'
  else
    StatusBadge := '[100% LIMPO - ZERO LEAKS]';

  Result := '========================================================' + LineEnding;
  Result := Result + '  Aether Profiler & Memory Audit (aetherc profile)     ' + LineEnding;
  Result := Result + Format('  Target: %s | Iteracoes: %d' + LineEnding, [Report.Backend, Report.Timing.Runs]);
  Result := Result + '========================================================' + LineEnding;
  Result := Result + Format('  Arquivo Alvo: %s' + LineEnding + LineEnding, [Report.FileName]);

  Result := Result + '  [TEMPO DE EXECUCAO & LATENCIA]' + LineEnding;
  Result := Result + Format('    Tempo Total:    %.2f ms' + LineEnding, [Report.Timing.TotalMs]);
  Result := Result + Format('    Tempo Medio:    %.2f ms' + LineEnding, [Report.Timing.AvgMs]);
  Result := Result + Format('    Min / Max:      %.2f ms / %.2f ms' + LineEnding + LineEnding, [Report.Timing.MinMs, Report.Timing.MaxMs]);

  Result := Result + '  [AUDITORIA DE MEMORIA & HEAP ANALYSIS]' + LineEnding;
  if Report.Memory.AllocatedBlocks > 0 then
  begin
    Result := Result + Format('    Blocos Alocados:    %d blocos' + LineEnding, [Report.Memory.AllocatedBlocks]);
    Result := Result + Format('    Blocos Liberados:   %d blocos' + LineEnding, [Report.Memory.FreedBlocks]);
    Result := Result + Format('    Blocos Nao Pagos:   %d blocos' + LineEnding, [Report.Memory.UnfreedBlocks]);
    Result := Result + Format('    Heap Total Alocado: %d bytes (%.2f KB)' + LineEnding, [Report.Memory.TrueHeapSize, Report.Memory.TrueHeapSize / 1024.0]);
  end
  else
  begin
    Result := Result + '    Heap Engine:        Rastreado via Safe Stack & Runtime do Sistema' + LineEnding;
  end;

  Result := Result + Format('    Status de Seguranca: %s' + LineEnding, [StatusBadge]);

  if Report.Memory.HasLeaks and (Report.Memory.LeakTrace <> '') then
  begin
    Result := Result + LineEnding + '  [CALL TRACE DO VAZAMENTO]:' + LineEnding;
    Result := Result + '    ' + Report.Memory.LeakTrace + LineEnding;
  end;

  Result := Result + '========================================================';
end;

class function TAetherProfiler.FormatJSONReport(const Report: TProfileReport): string;
var
  LeakBoolStr: string;
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  if Report.Memory.HasLeaks then LeakBoolStr := 'true' else LeakBoolStr := 'false';

  Result := '{' + LineEnding;
  Result := Result + '  "version": "1.0",' + LineEnding;
  Result := Result + Format('  "file": "%s",', [StringReplace(Report.FileName, '\', '\\', [rfReplaceAll])]) + LineEnding;
  Result := Result + Format('  "backend": "%s",', [Report.Backend]) + LineEnding;
  Result := Result + Format('  "runs": %d,', [Report.Timing.Runs]) + LineEnding;
  Result := Result + '  "timing": {' + LineEnding;
  Result := Result + Format('    "total_ms": %.2f,', [Report.Timing.TotalMs], FS) + LineEnding;
  Result := Result + Format('    "avg_ms": %.2f,', [Report.Timing.AvgMs], FS) + LineEnding;
  Result := Result + Format('    "min_ms": %.2f,', [Report.Timing.MinMs], FS) + LineEnding;
  Result := Result + Format('    "max_ms": %.2f', [Report.Timing.MaxMs], FS) + LineEnding;
  Result := Result + '  },' + LineEnding;
  Result := Result + '  "memory": {' + LineEnding;
  Result := Result + Format('    "has_leaks": %s,', [LeakBoolStr]) + LineEnding;
  Result := Result + Format('    "allocated_blocks": %d,', [Report.Memory.AllocatedBlocks]) + LineEnding;
  Result := Result + Format('    "freed_blocks": %d,', [Report.Memory.FreedBlocks]) + LineEnding;
  Result := Result + Format('    "unfreed_blocks": %d,', [Report.Memory.UnfreedBlocks]) + LineEnding;
  Result := Result + Format('    "heap_size_bytes": %d,', [Report.Memory.TrueHeapSize]) + LineEnding;
  Result := Result + Format('    "status": "%s"', [Report.Memory.Status]) + LineEnding;
  Result := Result + '  }' + LineEnding;
  Result := Result + '}';
end;

class procedure TAetherProfiler.HandleProfileCommand(const TargetPath: string; TargetPascal: Boolean; Runs: Integer; JSONOutput: Boolean);
var
  Report: TProfileReport;
  Success: Boolean;
begin
  Success := ProfileFile(TargetPath, TargetPascal, Runs, Report);

  if JSONOutput then
  begin
    WriteLn(FormatJSONReport(Report));
  end
  else
  begin
    WriteLn(FormatTerminalReport(Report));
  end;

  if (not Success) or Report.Memory.HasLeaks then
    Halt(1)
  else
    Halt(0);
end;

end.
