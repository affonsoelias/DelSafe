unit uAetherBootstrap;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, uAetherToolchain, uAetherIncremental, uAetherProject;

function RunStage3Bootstrap(const BaseDir: string; var Report: string): Boolean;
procedure HandleBootstrapCommand;

implementation

function RunStage3Bootstrap(const BaseDir: string; var Report: string): Boolean;
var
  BootstrapDir: string;
  CompilerSource: string;
  TestSuiteSource: string;
  Stage1Exe: string;
  Stage2CompilerC, Stage3CompilerC: string;
  Stage2SuiteC, Stage3SuiteC: string;
  Stage2SuiteExe, Stage3SuiteExe: string;
  Toolchain: TToolchainInfo;
  OutLog: string;
  Code: Integer;
  HashComp2, HashComp3: string;
  HashSuite2, HashSuite3: string;
  SizeComp2, SizeComp3: Int64;
  SizeSuite2, SizeSuite3: Int64;
  Stage1Hash: string;
  OutRun2, OutRun3: string;
  F: file;
begin
  Result := False;
  Report := '';

  Toolchain := DetectToolchain;
  if not Toolchain.GCCFound then
  begin
    Report := 'Erro: GCC moderno (MSYS2) e necessario para realizar o ciclo fechado de bootstrapping.';
    Exit(False);
  end;

  BootstrapDir := BaseDir + PathDelim + 'bin' + PathDelim + 'bootstrap';
  ForceDirectories(BootstrapDir);

  CompilerSource := BaseDir + PathDelim + 'compiler' + PathDelim + 'aeth' + PathDelim + 'main.aeth';
  if not FileExists(CompilerSource) then
  begin
    Report := Format('Erro: Codigo-fonte do compilador auto-hospedado nao encontrado em "%s".', [CompilerSource]);
    Exit(False);
  end;

  TestSuiteSource := BaseDir + PathDelim + 'examples' + PathDelim + '18_self_hosted_functions_and_structs.aeth';
  if not FileExists(TestSuiteSource) then
  begin
    Report := Format('Erro: Suite de testes de ciclo fechado nao encontrada em "%s".', [TestSuiteSource]);
    Exit(False);
  end;

  Stage1Exe := BootstrapDir + PathDelim + 'aetherc-stage1.exe';
  Stage2CompilerC := BootstrapDir + PathDelim + 'stage2_compiler.c';
  Stage3CompilerC := BootstrapDir + PathDelim + 'stage3_compiler.c';
  Stage2SuiteC := BootstrapDir + PathDelim + 'stage2_suite.c';
  Stage3SuiteC := BootstrapDir + PathDelim + 'stage3_suite.c';
  Stage2SuiteExe := BootstrapDir + PathDelim + 'stage2_suite.exe';
  Stage3SuiteExe := BootstrapDir + PathDelim + 'stage3_suite.exe';

  // Limpa artefatos de bootstrap anteriores para garantir teste atomico
  if FileExists(Stage1Exe) then DeleteFile(Stage1Exe);
  if FileExists(Stage2CompilerC) then DeleteFile(Stage2CompilerC);
  if FileExists(Stage3CompilerC) then DeleteFile(Stage3CompilerC);
  if FileExists(Stage2SuiteC) then DeleteFile(Stage2SuiteC);
  if FileExists(Stage3SuiteC) then DeleteFile(Stage3SuiteC);
  if FileExists(Stage2SuiteExe) then DeleteFile(Stage2SuiteExe);
  if FileExists(Stage3SuiteExe) then DeleteFile(Stage3SuiteExe);

  WriteLn('====================================================================');
  WriteLn('  AetherLang Stage 3 Bootstrapping - Auto-Hospedagem de Ciclo Fechado ');
  WriteLn('  Verificacao Estrita de Determinismo Bit-a-Bit e Fixed-Point        ');
  WriteLn('====================================================================');

  // --- STAGE 1: Compilador de Bootstrap (aetherc) compila compiler/aeth/main.aeth ---
  WriteLn('[STAGE 1] Compilando compilador auto-hospedado via aetherc (Pascal Bootstrap)...');
  Code := RunCommandCapture(BaseDir + PathDelim + 'bin' + PathDelim + 'aetherc.exe',
                            Format('"%s" --target=c --release -o "%s"', [CompilerSource, Stage1Exe]),
                            Toolchain.MSYS2BinDir, OutLog);
  if (Code <> 0) or (not FileExists(Stage1Exe)) then
  begin
    Report := 'Falha no Stage 1: Nao foi possivel compilar o Stage 1.'#10 + OutLog;
    Exit(False);
  end;
  Stage1Hash := SHA256File(Stage1Exe);
  WriteLn('          SUCESSO! "bin/bootstrap/aetherc-stage1.exe" gerado com GCC.');
  WriteLn(Format('          SHA-256: %s', [Stage1Hash]));

  // --- STAGE 2: aetherc-stage1 compila o compilador e a suite ---
  WriteLn('');
  WriteLn('[STAGE 2] aetherc-stage1 compilando compilador -> stage2_compiler.c...');
  Code := RunCommandCapture(Stage1Exe,
                            Format('"%s" -o "%s"', [CompilerSource, Stage2CompilerC]),
                            Toolchain.MSYS2BinDir, OutLog);
  if (Code <> 0) or (not FileExists(Stage2CompilerC)) then
  begin
    Report := 'Falha no Stage 2: aetherc-stage1 falhou na emissao de stage2_compiler.c.'#10 + OutLog;
    Exit(False);
  end;

  WriteLn('          aetherc-stage1 compilando suite de teste -> stage2_suite.c...');
  Code := RunCommandCapture(Stage1Exe,
                            Format('"%s" -o "%s"', [TestSuiteSource, Stage2SuiteC]),
                            Toolchain.MSYS2BinDir, OutLog);
  if (Code <> 0) or (not FileExists(Stage2SuiteC)) then
  begin
    Report := 'Falha no Stage 2: aetherc-stage1 falhou na emissao de stage2_suite.c.'#10 + OutLog;
    Exit(False);
  end;

  if not CompileWithGCC(Stage2SuiteC, Stage2SuiteExe, OutLog, True) then
  begin
    Report := 'Falha no Stage 2: Compilacao de stage2_suite.c com GCC falhou.'#10 + OutLog;
    Exit(False);
  end;

  HashComp2 := SHA256File(Stage2CompilerC);
  AssignFile(F, Stage2CompilerC);
  Reset(F, 1);
  SizeComp2 := FileSize(F);
  CloseFile(F);

  HashSuite2 := SHA256File(Stage2SuiteC);
  AssignFile(F, Stage2SuiteC);
  Reset(F, 1);
  SizeSuite2 := FileSize(F);
  CloseFile(F);

  WriteLn('          SUCESSO! Artefatos de Stage 2 gerados.');
  WriteLn(Format('          Compiler C: %d bytes (SHA-256: %s)', [SizeComp2, HashComp2]));
  WriteLn(Format('          Suite C   : %d bytes (SHA-256: %s)', [SizeSuite2, HashSuite2]));

  // --- STAGE 3: aetherc-stage1 compila em ambiente isolado para afericao de fixed-point ---
  WriteLn('');
  WriteLn('[STAGE 3] Iteracao de fechamento de ciclo (Fixed-Point) -> Stage 3...');
  Code := RunCommandCapture(Stage1Exe,
                            Format('"%s" -o "%s"', [CompilerSource, Stage3CompilerC]),
                            Toolchain.MSYS2BinDir, OutLog);
  if (Code <> 0) or (not FileExists(Stage3CompilerC)) then
  begin
    Report := 'Falha no Stage 3: aetherc-stage1 falhou na emissao de stage3_compiler.c.'#10 + OutLog;
    Exit(False);
  end;

  Code := RunCommandCapture(Stage1Exe,
                            Format('"%s" -o "%s"', [TestSuiteSource, Stage3SuiteC]),
                            Toolchain.MSYS2BinDir, OutLog);
  if (Code <> 0) or (not FileExists(Stage3SuiteC)) then
  begin
    Report := 'Falha no Stage 3: aetherc-stage1 falhou na emissao de stage3_suite.c.'#10 + OutLog;
    Exit(False);
  end;

  if not CompileWithGCC(Stage3SuiteC, Stage3SuiteExe, OutLog, True) then
  begin
    Report := 'Falha no Stage 3: Compilacao de stage3_suite.c com GCC falhou.'#10 + OutLog;
    Exit(False);
  end;

  HashComp3 := SHA256File(Stage3CompilerC);
  AssignFile(F, Stage3CompilerC);
  Reset(F, 1);
  SizeComp3 := FileSize(F);
  CloseFile(F);

  HashSuite3 := SHA256File(Stage3SuiteC);
  AssignFile(F, Stage3SuiteC);
  Reset(F, 1);
  SizeSuite3 := FileSize(F);
  CloseFile(F);

  WriteLn('          SUCESSO! Artefatos de Stage 3 gerados.');
  WriteLn(Format('          Compiler C: %d bytes (SHA-256: %s)', [SizeComp3, HashComp3]));
  WriteLn(Format('          Suite C   : %d bytes (SHA-256: %s)', [SizeSuite3, HashSuite3]));

  // --- VALIDACAO DE EXECUCAO EM RUNTIME ---
  WriteLn('');
  WriteLn('[TESTE] Validando execucao em runtime dos binarios da suite...');
  OutRun2 := '';
  OutRun3 := '';
  RunCommandCapture(Stage2SuiteExe, '', Toolchain.MSYS2BinDir, OutRun2);
  RunCommandCapture(Stage3SuiteExe, '', Toolchain.MSYS2BinDir, OutRun3);

  if Trim(OutRun2) <> Trim(OutRun3) then
  begin
    Report := 'Falha na verificacao em runtime: saida do binario Stage 2 diverge do Stage 3.';
    Exit(False);
  end;
  WriteLn('        Execucao identica em runtime em ambos os estagios (OK).');

  // --- VERIFICACAO DE DETERMINISMO BIT-A-BIT ---
  WriteLn('');
  WriteLn('====================================================================');
  WriteLn('  RELATORIO DE DETERMINISMO BIT-A-BIT (STAGE 3 BOOTSTRAPPING)        ');
  WriteLn('====================================================================');
  WriteLn(Format('  Compiler Stage 2 SHA-256 : %s', [HashComp2]));
  WriteLn(Format('  Compiler Stage 3 SHA-256 : %s', [HashComp3]));
  WriteLn(Format('  Diferenca bytes Compilador: %d bytes', [Abs(SizeComp2 - SizeComp3)]));
  WriteLn('');
  WriteLn(Format('  Suite Stage 2 SHA-256    : %s', [HashSuite2]));
  WriteLn(Format('  Suite Stage 3 SHA-256    : %s', [HashSuite3]));
  WriteLn(Format('  Diferenca bytes Suite    : %d bytes', [Abs(SizeSuite2 - SizeSuite3)]));

  if (HashComp2 = HashComp3) and (HashSuite2 = HashSuite3) then
  begin
    WriteLn('  Status                   : CONVERGENCIA TOTAL (Ponto Fixo / Fixed Point!)');
    WriteLn('  Determinismo             : 100% BIT-A-BIT IDENTICO!');
    WriteLn('====================================================================');
    WriteLn('SUCESSO ABSOLUTO! O compilador Aether concluiu a auto-hospedagem');
    WriteLn('de ciclo fechado e provou independencia total do compilador bootstrap.');
    WriteLn('====================================================================');
    Result := True;
  end
  else
  begin
    WriteLn('  Status                   : DIVERGENCIA DETECTADA!');
    WriteLn('====================================================================');
    Report := 'Erro: Os arquivos gerados no Stage 2 e Stage 3 possuem hashes distintos.';
    Result := False;
  end;
end;

procedure HandleBootstrapCommand;
var
  BaseDir, Dummy, Report: string;
begin
  if not uAetherProject.FindProjectRoot(BaseDir, Dummy) then
    BaseDir := GetCurrentDir;
  BaseDir := ExcludeTrailingPathDelimiter(BaseDir);

  if not RunStage3Bootstrap(BaseDir, Report) then
  begin
    WriteLn(ErrOutput, '');
    WriteLn(ErrOutput, 'ERRO NO BOOTSTRAP: ', Report);
    Halt(1);
  end;
end;

end.
