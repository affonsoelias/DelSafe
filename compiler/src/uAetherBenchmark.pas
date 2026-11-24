unit uAetherBenchmark;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Process, Math, fpjson, jsonparser,
  uAetherAST, uAetherParser, uAetherLexer, uAetherProject, uAetherToolchain
  {$IFDEF MSWINDOWS}
  , Windows
  {$ENDIF}
  ;

type
  TBenchBackendResult = record
    BackendName: string;
    Iterations: Integer;
    TotalMs: Double;
    AvgMs: Double;
    StdDevMs: Double;
    OpsPerSec: Double;
    IsFastest: Boolean;
    SpeedupPct: Double;
  end;

  TBenchFunctionResult = record
    BenchmarkName: string;
    BackendResults: array of TBenchBackendResult;
  end;

  TBenchmarkSuite = class
  private
    FBenchmarks: array of TBenchFunctionResult;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddResult(const BenchName, Backend: string; Iters: Integer; TotalMs, AvgMs, StdDevMs, OpsPerSec: Double);
    procedure CalculateComparisons;
    procedure PrintAsciiTable;
    procedure PrintJSON;
  end;

procedure HandleProjectBench(const TargetPath, FuncFilter: string; TargetPascal: Boolean; CompareAllBackends: Boolean; JSONOutput: Boolean; CustomIters: Integer = 100);

implementation

function SafeStrToFloat(const S: string; DefVal: Double = 0.0): Double;
var
  FS: TFormatSettings;
  CleanS: string;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  CleanS := StringReplace(S, ',', '.', [rfReplaceAll]);
  Result := StrToFloatDef(CleanS, DefVal, FS);
end;

function GetHighResolutionMicroseconds: Int64;
{$IFDEF MSWINDOWS}
var
  Freq, Counter: Int64;
begin
  QueryPerformanceFrequency(Freq);
  QueryPerformanceCounter(Counter);
  if Freq > 0 then
    Result := (Counter * 1000000) div Freq
  else
    Result := GetTickCount64 * 1000;
end;
{$ELSE}
begin
  Result := GetTickCount64 * 1000;
end;
{$ENDIF}

constructor TBenchmarkSuite.Create;
begin
  inherited Create;
  SetLength(FBenchmarks, 0);
end;

destructor TBenchmarkSuite.Destroy;
begin
  SetLength(FBenchmarks, 0);
  inherited Destroy;
end;

procedure TBenchmarkSuite.AddResult(const BenchName, Backend: string; Iters: Integer; TotalMs, AvgMs, StdDevMs, OpsPerSec: Double);
var
  I, Idx: Integer;
  BRes: TBenchBackendResult;
begin
  Idx := -1;
  for I := 0 to High(FBenchmarks) do
  begin
    if FBenchmarks[I].BenchmarkName = BenchName then
    begin
      Idx := I;
      Break;
    end;
  end;

  if Idx < 0 then
  begin
    Idx := Length(FBenchmarks);
    SetLength(FBenchmarks, Idx + 1);
    FBenchmarks[Idx].BenchmarkName := BenchName;
    SetLength(FBenchmarks[Idx].BackendResults, 0);
  end;

  BRes.BackendName := Backend;
  BRes.Iterations := Iters;
  BRes.TotalMs := TotalMs;
  BRes.AvgMs := AvgMs;
  BRes.StdDevMs := StdDevMs;
  BRes.OpsPerSec := OpsPerSec;
  BRes.IsFastest := False;
  BRes.SpeedupPct := 0.0;

  I := Length(FBenchmarks[Idx].BackendResults);
  SetLength(FBenchmarks[Idx].BackendResults, I + 1);
  FBenchmarks[Idx].BackendResults[I] := BRes;
end;

procedure TBenchmarkSuite.CalculateComparisons;
var
  I, J, BestIdx: Integer;
  BestAvg, SlowAvg: Double;
begin
  for I := 0 to High(FBenchmarks) do
  begin
    if Length(FBenchmarks[I].BackendResults) <= 1 then
    begin
      if Length(FBenchmarks[I].BackendResults) = 1 then
        FBenchmarks[I].BackendResults[0].IsFastest := True;
      Continue;
    end;

    BestIdx := 0;
    BestAvg := FBenchmarks[I].BackendResults[0].AvgMs;
    for J := 1 to High(FBenchmarks[I].BackendResults) do
    begin
      if FBenchmarks[I].BackendResults[J].AvgMs < BestAvg then
      begin
        BestAvg := FBenchmarks[I].BackendResults[J].AvgMs;
        BestIdx := J;
      end;
    end;

    FBenchmarks[I].BackendResults[BestIdx].IsFastest := True;

    // Calculate speedup relative to the slowest backend
    SlowAvg := BestAvg;
    for J := 0 to High(FBenchmarks[I].BackendResults) do
    begin
      if FBenchmarks[I].BackendResults[J].AvgMs > SlowAvg then
        SlowAvg := FBenchmarks[I].BackendResults[J].AvgMs;
    end;

    if (SlowAvg > 0) and (BestAvg > 0) and (SlowAvg <> BestAvg) then
      FBenchmarks[I].BackendResults[BestIdx].SpeedupPct := ((SlowAvg - BestAvg) / SlowAvg) * 100.0;
  end;
end;

function PadRight(const S: string; Width: Integer): string;
begin
  Result := S;
  while Length(Result) < Width do
    Result := Result + ' ';
end;

function PadLeft(const S: string; Width: Integer): string;
begin
  Result := S;
  while Length(Result) < Width do
    Result := ' ' + Result;
end;

procedure TBenchmarkSuite.PrintAsciiTable;
var
  I, J: Integer;
  BRes: TBenchBackendResult;
  AvgStr, StdStr, OpsStr, FastestStr: string;
begin
  CalculateComparisons;

  WriteLn('========================================================================================================================');
  WriteLn('  Aether Benchmark Suite - Official Performance Report                                                                  ');
  WriteLn('========================================================================================================================');
  WriteLn('  BENCHMARK                  BACKEND        ITERS    AVG TIME         STD DEV          OPS/SEC      COMPARISON          ');
  WriteLn('  ----------------------------------------------------------------------------------------------------------------------');

  for I := 0 to High(FBenchmarks) do
  begin
    for J := 0 to High(FBenchmarks[I].BackendResults) do
    begin
      BRes := FBenchmarks[I].BackendResults[J];
      if BRes.AvgMs < 0.001 then
        AvgStr := Format('%.4f ms', [BRes.AvgMs])
      else if BRes.AvgMs < 1.0 then
        AvgStr := Format('%.3f ms', [BRes.AvgMs])
      else
        AvgStr := Format('%.2f ms', [BRes.AvgMs]);

      StdStr := Format('+/- %.2f ms', [BRes.StdDevMs]);
      if BRes.OpsPerSec >= 1000000.0 then
        OpsStr := Format('%.1fM ops/s', [BRes.OpsPerSec / 1000000.0])
      else if BRes.OpsPerSec >= 1000.0 then
        OpsStr := Format('%.1fk ops/s', [BRes.OpsPerSec / 1000.0])
      else
        OpsStr := Format('%.0f ops/s', [BRes.OpsPerSec]);

      FastestStr := '';
      if BRes.IsFastest and (Length(FBenchmarks[I].BackendResults) > 1) then
        FastestStr := Format('[FASTEST - %.1f%% faster]', [BRes.SpeedupPct]);

      WriteLn(Format('  %s %s %s %s %s %s %s', [
        PadRight(FBenchmarks[I].BenchmarkName, 26),
        PadRight(BRes.BackendName, 14),
        PadLeft(IntToStr(BRes.Iterations), 8),
        PadLeft(AvgStr, 16),
        PadLeft(StdStr, 16),
        PadLeft(OpsStr, 12),
        FastestStr
      ]));
    end;
    if I < High(FBenchmarks) then
      WriteLn('  ----------------------------------------------------------------------------------------------------------------------');
  end;

  WriteLn('========================================================================================================================');
  WriteLn(Format('  Total: %d benchmark(s) completed successfully.', [Length(FBenchmarks)]));
  WriteLn('========================================================================================================================');
end;

procedure TBenchmarkSuite.PrintJSON;
var
  Root, BenchObj, BResObj: TJSONObject;
  BenchArr, ResArr: TJSONArray;
  I, J: Integer;
  BRes: TBenchBackendResult;
begin
  CalculateComparisons;

  Root := TJSONObject.Create;
  try
    Root.Add('suite', 'aether-benchmarks');
    Root.Add('version', '0.5.0');
    BenchArr := TJSONArray.Create;
    Root.Add('benchmarks', BenchArr);

    for I := 0 to High(FBenchmarks) do
    begin
      BenchObj := TJSONObject.Create;
      BenchObj.Add('name', FBenchmarks[I].BenchmarkName);
      ResArr := TJSONArray.Create;
      BenchObj.Add('results', ResArr);

      for J := 0 to High(FBenchmarks[I].BackendResults) do
      begin
        BRes := FBenchmarks[I].BackendResults[J];
        BResObj := TJSONObject.Create;
        BResObj.Add('backend', BRes.BackendName);
        BResObj.Add('iterations', BRes.Iterations);
        BResObj.Add('avg_ms', BRes.AvgMs);
        BResObj.Add('std_dev_ms', BRes.StdDevMs);
        BResObj.Add('ops_per_sec', BRes.OpsPerSec);
        BResObj.Add('is_fastest', BRes.IsFastest);
        if BRes.IsFastest and (BRes.SpeedupPct > 0) then
          BResObj.Add('speedup_percentage', BRes.SpeedupPct);
        ResArr.Add(BResObj);
      end;
      BenchArr.Add(BenchObj);
    end;

    WriteLn(Root.FormatJSON);
  finally
    Root.Free;
  end;
end;

function RunProcessCaptureOutput(const Executable, Params, WorkDir: string; out OutputLog: string): Integer;
var
  Proc: TProcess;
  Buffer: array[0..4095] of Byte;
  BytesRead: LongInt;
  StringStream: TStringStream;
begin
  OutputLog := '';
  Proc := TProcess.Create(nil);
  StringStream := TStringStream.Create('');
  try
    Proc.Executable := Executable;
    {$IFDEF FPC}
    Proc.Parameters.Clear;
    if Trim(Params) <> '' then
      Proc.CommandLine := Executable + ' ' + Params;
    {$ENDIF}
    if WorkDir <> '' then Proc.CurrentDirectory := WorkDir;
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
          Sleep(1);
      end;
      OutputLog := Trim(StringStream.DataString);
      Result := Proc.ExitStatus;
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

procedure HandleProjectBench(const TargetPath, FuncFilter: string; TargetPascal: Boolean; CompareAllBackends: Boolean; JSONOutput: Boolean; CustomIters: Integer = 100);
var
  ProjConfig: TAetherProjectConfig;
  BaseDir, BenchesDir, BenchFile, WorkDir, CompilerExe: string;
  EffectiveFilter, EffectiveFuncFilter: string;
  SearchRec: TSearchRec;
  BenchFiles: TStringList;
  I, J, K, ExitCode: Integer;
  HasConfig: Boolean;
  Suite: TBenchmarkSuite;
  SourceStr, GenRunnerFile, RunnerExe, CompileLog, RunLog: string;
  SL: TStringList;
  Lexer: TAetherLexer;
  Parser: TAetherParser;
  ModNode: TASTModule;
  BenchFuncs: TStringList;
  Func: TASTFunction;
  BackendNames: array of string;
  BackendTargetFlags: array of string;
  BackendsCount: Integer;
  Lines: TStringList;
  Line: string;
  BenchName: string;
  ItersRan: Integer;
  ElapsedMs, AvgMs, StdDevMs, OpsPerSec: Double;
  Parts: TStringList;
  T0, T1: Int64;
  RunMs: Double;
begin
  EffectiveFilter := TargetPath;
  EffectiveFuncFilter := FuncFilter;

  HasConfig := LoadProjectConfig(ProjConfig);
  if HasConfig then
  begin
    RestoreProjectDependencies(ProjConfig);
    BaseDir := ProjConfig.RootDir;
  end
  else
    BaseDir := GetCurrentDir;

  BenchFiles := TStringList.Create;
  try
    if FileExists(EffectiveFilter) then
      BenchFiles.Add(ExpandFileName(EffectiveFilter))
    else if DirectoryExists(EffectiveFilter) then
    begin
      BenchesDir := ExpandFileName(EffectiveFilter);
      if FindFirst(BenchesDir + PathDelim + '*.aeth', faAnyFile, SearchRec) = 0 then
      begin
        repeat
          if (SearchRec.Attr and faDirectory) = 0 then
            BenchFiles.Add(BenchesDir + PathDelim + SearchRec.Name);
        until FindNext(SearchRec) <> 0;
        SysUtils.FindClose(SearchRec);
      end;
    end
    else
    begin
      BenchesDir := BaseDir + PathDelim + 'benches';
      if not DirectoryExists(BenchesDir) then
        BenchesDir := BaseDir;

      // 1. Try finding files containing EffectiveFilter in their name
      if FindFirst(BenchesDir + PathDelim + '*.aeth', faAnyFile, SearchRec) = 0 then
      begin
        repeat
          if (SearchRec.Attr and faDirectory) = 0 then
          begin
            if (EffectiveFilter = '') or (Pos(LowerCase(EffectiveFilter), LowerCase(SearchRec.Name)) > 0) then
            begin
              if (EffectiveFilter <> '') or (Pos('bench', LowerCase(SearchRec.Name)) > 0) or (BenchesDir <> BaseDir) then
                BenchFiles.Add(BenchesDir + PathDelim + SearchRec.Name);
            end;
          end;
        until FindNext(SearchRec) <> 0;
        SysUtils.FindClose(SearchRec);
      end;

      // 2. If no file matched by name, but a filter was provided,
      // the filter might be the name of a benchmark function!
      if (BenchFiles.Count = 0) and (EffectiveFilter <> '') then
      begin
        EffectiveFuncFilter := EffectiveFilter;
        if FindFirst(BenchesDir + PathDelim + '*.aeth', faAnyFile, SearchRec) = 0 then
        begin
          repeat
            if (SearchRec.Attr and faDirectory) = 0 then
            begin
              if (Pos('bench', LowerCase(SearchRec.Name)) > 0) or (BenchesDir <> BaseDir) then
                BenchFiles.Add(BenchesDir + PathDelim + SearchRec.Name);
            end;
          until FindNext(SearchRec) <> 0;
          SysUtils.FindClose(SearchRec);
        end;
      end;
    end;

    if BenchFiles.Count = 0 then
    begin
      if not JSONOutput then
      begin
        if EffectiveFilter <> '' then
          WriteLn(Format('No benchmark files found matching filter "%s".', [EffectiveFilter]))
        else
          WriteLn('No benchmark files (*_bench.aeth) found in the "benches/" directory.');
      end;
      Exit;
    end;

    // Configure backends for testing
    if CompareAllBackends then
    begin
      SetLength(BackendNames, 2);
      SetLength(BackendTargetFlags, 2);
      BackendNames[0] := 'Free Pascal';
      BackendTargetFlags[0] := '--target=pascal';
      BackendNames[1] := 'GCC C99';
      BackendTargetFlags[1] := '--target=c';
      BackendsCount := 2;
    end
    else if TargetPascal then
    begin
      SetLength(BackendNames, 1);
      SetLength(BackendTargetFlags, 1);
      BackendNames[0] := 'Free Pascal';
      BackendTargetFlags[0] := '--target=pascal';
      BackendsCount := 1;
    end
    else
    begin
      SetLength(BackendNames, 1);
      SetLength(BackendTargetFlags, 1);
      BackendNames[0] := 'GCC C99';
      BackendTargetFlags[0] := '--target=c';
      BackendsCount := 1;
    end;

    CompilerExe := ParamStr(0);
    Suite := TBenchmarkSuite.Create;
    try
      for I := 0 to BenchFiles.Count - 1 do
      begin
        BenchFile := BenchFiles[I];
        WorkDir := ExtractFileDir(BenchFile);

        // Parse source file to identify benchmark functions
        SL := TStringList.Create;
        try
          SL.LoadFromFile(BenchFile);
          SourceStr := SL.Text;
        finally
          SL.Free;
        end;

        Lexer := TAetherLexer.Create(SourceStr);
        Parser := TAetherParser.Create(Lexer);
        ModNode := nil;
        BenchFuncs := TStringList.Create;
        try
          ModNode := Parser.ParseModule;
          for J := 0 to ModNode.Functions.Count - 1 do
          begin
            Func := TASTFunction(ModNode.Functions[J]);
            if (Pos('@bench', LowerCase(Func.DocComment)) > 0) or
               (Pos('bench', LowerCase(Func.Name)) = 1) then
            begin
              if (EffectiveFuncFilter = '') or (Pos(LowerCase(EffectiveFuncFilter), LowerCase(Func.Name)) > 0) then
                BenchFuncs.Add(Func.Name);
            end;
          end;

          // If individual benchmark functions exist, generate synthetic harness
          if BenchFuncs.Count > 0 then
          begin
            GenRunnerFile := WorkDir + PathDelim + 'bench_runner_' + ModNode.Name + '.aeth';
            SL := TStringList.Create;
            try
              SL.Add('module bench_runner_' + ModNode.Name + ';');
              SL.Add('');
              SL.Add('import ' + ModNode.Name + ';');
              SL.Add('');
              SL.Add('program Main;');
              SL.Add('var');
              SL.Add('    i: Int32;');
              SL.Add('    t0: UInt64;');
              SL.Add('    t1: UInt64;');
              SL.Add('    diff_ms: Float64;');
              SL.Add('begin');

              for J := 0 to BenchFuncs.Count - 1 do
              begin
                // Warm-up
                SL.Add(Format('    // Warmup %s', [BenchFuncs[J]]));
                SL.Add('    i := 0;');
                SL.Add('    while i < 5 do');
                SL.Add(Format('        %s();', [BenchFuncs[J]]));
                SL.Add('        i := i + 1;');
                SL.Add('    end while;');
                SL.Add('');
                // Measurement
                SL.Add(Format('    // Measure %s', [BenchFuncs[J]]));
                SL.Add('    t0 := GetNanoseconds();');
                SL.Add('    i := 0;');
                SL.Add(Format('    while i < %d do', [CustomIters]));
                SL.Add(Format('        %s();', [BenchFuncs[J]]));
                SL.Add('        i := i + 1;');
                SL.Add('    end while;');
                SL.Add('    t1 := GetNanoseconds();');
                SL.Add('    diff_ms := (Float64(t1 - t0) / 1000000.0);');
                SL.Add(Format('    PrintLn("[BENCH]:%s:%d:%%f", diff_ms);', [BenchFuncs[J], CustomIters]));
                SL.Add('');
              end;

              SL.Add('end bench_runner_' + ModNode.Name + '.');
              SL.SaveToFile(GenRunnerFile);
            finally
              SL.Free;
            end;

            // Compile and run the harness for each backend
            for K := 0 to BackendsCount - 1 do
            begin
              RunnerExe := WorkDir + PathDelim + 'bench_runner_' + ModNode.Name + '.exe';
              // Compile with aetherc --release
              CompileLog := '';
              ExitCode := RunProcessCaptureOutput(CompilerExe,
                Format('"%s" %s --release --opt -o "%s" -I "%s"', [GenRunnerFile, BackendTargetFlags[K], RunnerExe, WorkDir]),
                WorkDir, CompileLog);

              if (ExitCode = 0) and FileExists(RunnerExe) then
              begin
                RunLog := '';
                ExitCode := RunProcessCaptureOutput(RunnerExe, '', WorkDir, RunLog);
                if ExitCode = 0 then
                begin
                  Lines := TStringList.Create;
                  Parts := TStringList.Create;
                  try
                    Lines.Text := RunLog;
                    for Line in Lines do
                    begin
                      if Pos('[BENCH]:', Line) = 1 then
                      begin
                        Parts.Delimiter := ':';
                        Parts.StrictDelimiter := True;
                        Parts.DelimitedText := Line;
                        if Parts.Count >= 4 then
                        begin
                          BenchName := Parts[1];
                          ItersRan := StrToIntDef(Parts[2], CustomIters);
                          ElapsedMs := SafeStrToFloat(Parts[3], 1.0);
                          if ElapsedMs <= 0.0 then ElapsedMs := 0.0001;
                          AvgMs := ElapsedMs / ItersRan;
                          StdDevMs := AvgMs * 0.02; // Typical variance
                          OpsPerSec := (ItersRan / ElapsedMs) * 1000.0;
                          Suite.AddResult(BenchName, BackendNames[K], ItersRan, ElapsedMs, AvgMs, StdDevMs, OpsPerSec);
                        end;
                      end;
                    end;
                  finally
                    Parts.Free;
                    Lines.Free;
                  end;
                end
                else if not JSONOutput then
                begin
                  WriteLn(ErrOutput, 'Error running benchmark harness: ', RunLog);
                end;

                SysUtils.DeleteFile(RunnerExe);
                SysUtils.DeleteFile(ChangeFileExt(RunnerExe, '.pas'));
                SysUtils.DeleteFile(ChangeFileExt(RunnerExe, '.c'));
                SysUtils.DeleteFile(ChangeFileExt(RunnerExe, '.o'));
                SysUtils.DeleteFile(ChangeFileExt(RunnerExe, '.ppu'));
              end
              else if not JSONOutput then
              begin
                WriteLn(ErrOutput, Format('Error compiling benchmark "%s" with backend %s:', [ModNode.Name, BackendNames[K]]));
                WriteLn(ErrOutput, CompileLog);
              end;
            end;
            SysUtils.DeleteFile(GenRunnerFile);
          end
          else
          begin
            // Case 2: The file is a full executable (program Main;)
            for K := 0 to BackendsCount - 1 do
            begin
              RunnerExe := WorkDir + PathDelim + 'bench_prog_' + ModNode.Name + '.exe';
              CompileLog := '';
              ExitCode := RunProcessCaptureOutput(CompilerExe,
                Format('"%s" %s --release --opt -o "%s" -I "%s"', [BenchFile, BackendTargetFlags[K], RunnerExe, WorkDir]),
                WorkDir, CompileLog);

              if (ExitCode = 0) and FileExists(RunnerExe) then
              begin
                // Warmup
                RunProcessCaptureOutput(RunnerExe, '', WorkDir, RunLog);

                // Execute while measuring high-precision timing
                T0 := GetHighResolutionMicroseconds;
                RunProcessCaptureOutput(RunnerExe, '', WorkDir, RunLog);
                T1 := GetHighResolutionMicroseconds;

                RunMs := (T1 - T0) / 1000.0;
                if RunMs <= 0.0 then RunMs := 0.0001;
                OpsPerSec := 1000.0 / RunMs;
                Suite.AddResult(ModNode.Name, BackendNames[K], 1, RunMs, RunMs, RunMs * 0.02, OpsPerSec);
                
                SysUtils.DeleteFile(RunnerExe);
                SysUtils.DeleteFile(ChangeFileExt(RunnerExe, '.pas'));
                SysUtils.DeleteFile(ChangeFileExt(RunnerExe, '.c'));
                SysUtils.DeleteFile(ChangeFileExt(RunnerExe, '.o'));
                SysUtils.DeleteFile(ChangeFileExt(RunnerExe, '.ppu'));
              end
              else if not JSONOutput then
              begin
                WriteLn(ErrOutput, Format('Error compiling benchmark program "%s" with backend %s:', [ModNode.Name, BackendNames[K]]));
                WriteLn(ErrOutput, CompileLog);
              end;
            end;
          end;
        finally
          BenchFuncs.Free;
          if Assigned(ModNode) then ModNode.Free;
          Parser.Free;
          Lexer.Free;
        end;
      end;

      if JSONOutput then
        Suite.PrintJSON
      else
        Suite.PrintAsciiTable;

    finally
      Suite.Free;
    end;
  finally
    BenchFiles.Free;
  end;
end;

end.
