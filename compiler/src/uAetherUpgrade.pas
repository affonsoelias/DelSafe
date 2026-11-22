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
        WriteLn(ErrOutput, 'Erro ao executar comando: ', E.Message);
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
    ErrorMsg := 'Falha ao conectar aos servidores de release (curl retornou codigo ' + IntToStr(ExitCode) + '). ' +
                'Verifique sua conexao de rede ou use "aetherc upgrade --from-source". Log: ' + OutputLog;
    Exit(False);
  end;

  if (OutputLog = '') or (Pos('{', OutputLog) = 0) then
  begin
    ErrorMsg := 'Resposta inesperada do servidor de release. Log: ' + OutputLog;
    Exit(False);
  end;

  try
    JsonData := GetJSON(OutputLog);
  except
    on E: Exception do
    begin
      ErrorMsg := 'Falha ao processar metadados JSON do release: ' + E.Message;
      Exit(False);
    end;
  end;

  try
    if not (JsonData is TJSONObject) then
    begin
      ErrorMsg := 'Resposta JSON invalida da API de releases.';
      Exit(False);
    end;

    RootObj := TJSONObject(JsonData);

    // Verifica se houve mensagem de erro da API do GitHub (ex: 404 Not Found, Rate limit exceeded)
    if RootObj.IndexOfName('message') >= 0 then
    begin
      ErrorMsg := 'API GitHub: ' + RootObj.Get('message', 'Erro desconhecido');
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

          // Identifica arquivo de checksum
          if (Pos('.sha256', CurName) > 0) or (Pos('checksum', CurName) > 0) then
          begin
            if (Pos(OSName, CurName) > 0) or (ChecksumUrl = '') then
              ChecksumUrl := CurDownloadUrl;
          end;

          // Identifica o pacote binario correspondente ao sistema operacional e arquitetura (excluindo checksums)
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
    ErrorMsg := Format('Nenhum pacote binario compativel com a plataforma (%s-%s) foi encontrado no release %s.',
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
    WriteLn(ErrOutput, Format('Erro: Nenhum backup de versao anterior foi encontrado em "%s".', [BakPath]));
    WriteLn(ErrOutput, 'O rollback so e possivel apos uma atualizacao anterior bem-sucedida.');
    Halt(1);
  end;

  WriteLn('==> Iniciando reversao (Rollback) da toolchain Aether...');
  WriteLn(Format('    Executavel atual : %s', [ExePath]));
  WriteLn(Format('    Backup anterior  : %s', [BakPath]));

  if DryRun then
  begin
    WriteLn('');
    WriteLn('[DRY-RUN] Nenhuma alteracao foi feita no disco.');
    WriteLn(Format('[DRY-RUN] O arquivo "%s" seria restaurado como "%s".', [BakPath, ExePath]));
    Exit;
  end;

  // No Windows, renomeamos o atual para .failed e o .bak para o atual
  if FileExists(ExePath + '.failed') then
    DeleteFile(ExePath + '.failed');

  if not RenameFile(ExePath, ExePath + '.failed') then
  begin
    WriteLn(ErrOutput, 'Erro: Falha ao mover o executavel atual para backup temporario.');
    Halt(1);
  end;

  if not RenameFile(BakPath, ExePath) then
  begin
    // Tenta restaurar em caso de erro
    RenameFile(ExePath + '.failed', ExePath);
    WriteLn(ErrOutput, 'Erro critico: Falha ao restaurar o backup anterior.');
    Halt(1);
  end;

  DeleteFile(ExePath + '.failed');

  // Verifica o executavel restaurado
  if RunProcessWithOutput(ExePath, '-h', OutputLog) = 0 then
  begin
    WriteLn('');
    WriteLn('========================================================');
    WriteLn('  [SUCESSO] Reversao concluida com sucesso!             ');
    WriteLn('  A versao anterior da toolchain foi restaurada.        ');
    WriteLn('========================================================');
  end
  else
  begin
    WriteLn('');
    WriteLn('Aviso: O binario restaurado retornou codigo de saida diferente de zero.');
  end;
end;

class procedure TAetherUpgrade.HandleSourceUpgrade(const GitDir: string; const Opts: TUpgradeOptions);
var
  Cmd, OutputLog, TargetBranch: string;
  ExitCode: Integer;
  IsWindows: Boolean;
begin
  WriteLn('========================================================');
  WriteLn('  Atualizacao Aether via Codigo-Fonte (Source Build)    ');
  WriteLn('========================================================');
  WriteLn(Format('Repositorio Git detectado: %s', [GitDir]));

  if Opts.DryRun then
  begin
    WriteLn('');
    WriteLn('[DRY-RUN] Comandos que seriam executados:');
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
  WriteLn('-> [1/4] Buscando atualizacoes e tags remotas via Git...');
  ExitCode := RunProcessWithOutput('git', Format('-C "%s" fetch --tags --all', [GitDir]), OutputLog);
  if ExitCode <> 0 then
  begin
    WriteLn(ErrOutput, 'Erro ao executar git fetch: ' + OutputLog);
    Halt(1);
  end;

  // 2. Checkout / Pull
  if Opts.TargetVersion <> '' then
  begin
    WriteLn(Format('-> [2/4] Atualizando para versao/tag especifica: %s...', [Opts.TargetVersion]));
    ExitCode := RunProcessWithOutput('git', Format('-C "%s" checkout %s', [GitDir, Opts.TargetVersion]), OutputLog);
  end
  else
  begin
    WriteLn('-> [2/4] Mesclando codigo mais recente da branch principal (pull)...');
    TargetBranch := 'main';
    ExitCode := RunProcessWithOutput('git', Format('-C "%s" pull origin %s', [GitDir, TargetBranch]), OutputLog);
    if ExitCode <> 0 then
    begin
      // Tenta 'master' caso a branch remota seja master
      TargetBranch := 'master';
      ExitCode := RunProcessWithOutput('git', Format('-C "%s" pull origin %s', [GitDir, TargetBranch]), OutputLog);
    end;
  end;

  if ExitCode <> 0 then
  begin
    WriteLn(ErrOutput, 'Erro ao sincronizar branch/tag Git: ' + OutputLog);
    Halt(1);
  end;
  WriteLn('   Git sincronizado com sucesso.');

  // 3. Recompilação do compilador
  WriteLn('');
  WriteLn('-> [3/4] Recompilando o compilador Aether (aetherc)...');
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
    WriteLn(ErrOutput, Format('Erro na compilacao do aetherc (codigo %d).', [ExitCode]));
    Halt(1);
  end;

  // 4. Executa a suite de testes unitarios com o novo binario
  WriteLn('');
  WriteLn('-> [4/4] Validando novo compilador com a suite de testes unitarios...');
  if IsWindows then
    Cmd := Format('"%s%sbin%saetherc.exe" test', [GitDir, PathDelim, PathDelim])
  else
    Cmd := Format('"%s%sbin%saetherc" test', [GitDir, PathDelim, PathDelim]);

  ExitCode := RunCommandStream(Cmd);
  if ExitCode <> 0 then
  begin
    WriteLn(ErrOutput, 'Aviso: Alguns testes da suite falharam apos a atualizacao.');
    Halt(1);
  end;

  WriteLn('');
  WriteLn('========================================================');
  WriteLn('  [SUCESSO] Compilador Aether atualizado com sucesso!   ');
  WriteLn('  Toolchain reconstruida e validada via testes.         ');
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
  WriteLn('  Verificando Atualizacoes do Compilador AetherLang     ');
  WriteLn('========================================================');
  WriteLn(Format('Versao instalada atual : v%s', [AETHER_COMPILER_VERSION]));
  WriteLn(Format('Plataforma detectada   : %s-%s', [OSName, ArchName]));
  WriteLn(Format('Repositorio de releases: %s', [RepoName]));
  WriteLn('Consultando metadados de release...');

  if not FetchReleaseMetadata(RepoName, Opts.TargetVersion, Opts.CustomUrl,
                              TagName, Notes, AssetUrl, AssetName, ChecksumUrl, ChecksumVal, ErrorMsg) then
  begin
    WriteLn(ErrOutput, 'Erro: ' + ErrorMsg);
    Halt(1);
  end;

  WriteLn('');
  WriteLn(Format('Ultima versao encontrada : %s', [TagName]));
  if AssetName <> '' then
    WriteLn(Format('Pacote compativel        : %s', [AssetName]));

  // Compara SemVer da versão atual com o release remoto
  if (CompareSemVer(TagName, AETHER_COMPILER_VERSION) <= 0) and (Opts.TargetVersion = '') then
  begin
    WriteLn('');
    WriteLn('========================================================');
    WriteLn(Format('  O AetherLang ja esta atualizado na versao v%s!  ', [AETHER_COMPILER_VERSION]));
    WriteLn('  Nenhuma acao adicional e necessaria.                  ');
    WriteLn('========================================================');
    Exit;
  end;

  if Opts.CheckOnly then
  begin
    WriteLn('');
    WriteLn('--------------------------------------------------------');
    WriteLn(Format('Nova versao disponivel: %s (instalada: v%s)', [TagName, AETHER_COMPILER_VERSION]));
    if Trim(Notes) <> '' then
    begin
      WriteLn('');
      WriteLn('Notas de Lancamento:');
      WriteLn(Copy(Notes, 1, 400));
      if Length(Notes) > 400 then WriteLn('...');
    end;
    WriteLn('--------------------------------------------------------');
    WriteLn('Para atualizar para esta versao agora, execute:');
    WriteLn('  aetherc upgrade');
    Exit;
  end;

  if Opts.DryRun then
  begin
    WriteLn('');
    WriteLn('[DRY-RUN] Plano de execucao da atualizacao:');
    WriteLn(Format('  1. Download: %s', [AssetUrl]));
    if ChecksumUrl <> '' then
      WriteLn(Format('  2. Verificacao de Integridade SHA-256 via %s', [ChecksumUrl]));
    WriteLn(Format('  3. Extracao do pacote %s', [AssetName]));
    WriteLn(Format('  4. Backup atomico: %s -> %s.bak', [ExePath, ExePath]));
    WriteLn(Format('  5. Substituicao de: %s', [ExePath]));
    WriteLn('  6. Teste de inicializacao com o novo binario');
    Exit;
  end;

  // Cria diretorio temporario para download
  TempDir := GetTempDir + 'aether_upgrade_' + IntToStr(DateTimeToFileDate(Now));
  if not ForceDirectories(TempDir) then
  begin
    WriteLn(ErrOutput, 'Erro ao criar diretorio temporario de atualizacao: ' + TempDir);
    Halt(1);
  end;

  DownloadedFile := TempDir + PathDelim + AssetName;
  ExtractDir := TempDir + PathDelim + 'extracted';
  ForceDirectories(ExtractDir);

  try
    // 1. Download do arquivo de release
    WriteLn('');
    WriteLn(Format('-> [1/4] Baixando release %s (%s)...', [TagName, AssetName]));
    CurlCmd := Format('-sL -H "User-Agent: Aether-Upgrader" -o "%s" "%s"', [DownloadedFile, AssetUrl]);
    ExitCode := RunCommandStream('curl ' + CurlCmd);
    if (ExitCode <> 0) or not FileExists(DownloadedFile) then
    begin
      WriteLn(ErrOutput, 'Erro ao baixar o artefato de release via curl.');
      Halt(1);
    end;

    // 2. Verificação de integridade SHA-256
    WriteLn('-> [2/4] Verificando integridade criptografica (SHA-256)...');
    HashCalc := LowerCase(SHA256File(DownloadedFile));
    WriteLn(Format('   Hash SHA-256 calculado: %s', [HashCalc]));

    if ChecksumUrl <> '' then
    begin
      // Baixa checksum se disponivel
      RunProcessWithOutput('curl', Format('-sL "%s"', [ChecksumUrl]), ChecksumVal);
      if ChecksumVal <> '' then
      begin
        if Pos(HashCalc, LowerCase(ChecksumVal)) = 0 then
        begin
          WriteLn(ErrOutput, 'Erro de Seguranca E9991: O hash SHA-256 do arquivo baixado nao confere com o release oficial.');
          WriteLn(ErrOutput, 'Operacao abortada por motivos de integridade.');
          Halt(1);
        end
        else
          WriteLn('   [OK] Checksum SHA-256 verificado com sucesso contra a assinatura do release.');
      end;
    end
    else
      WriteLn('   [OK] Checksum local calculado com sucesso.');

    // 3. Descompactação do arquivo
    WriteLn('-> [3/4] Extraindo artefato de release...');
    TarCmd := Format('-xf "%s" -C "%s"', [DownloadedFile, ExtractDir]);
    ExitCode := RunProcessWithOutput('tar', TarCmd, TestLog);
    if ExitCode <> 0 then
    begin
      WriteLn(ErrOutput, 'Erro ao descompactar artefato com tar: ' + TestLog);
      Halt(1);
    end;

    // Localiza o executável extraído
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
      WriteLn(ErrOutput, 'Erro: O executavel do compilador aetherc nao foi encontrado no pacote descompactado.');
      Halt(1);
    end;

    // 4. Substituição atômica no sistema de arquivos
    WriteLn('-> [4/4] Aplicando atualizacao atomica no executavel do compilador...');
    BakPath := ExePath + '.bak';
    if FileExists(BakPath) then
      DeleteFile(BakPath);

    // No Windows, renomear o executavel em execucao e permitido
    if not RenameFile(ExePath, BakPath) then
    begin
      WriteLn(ErrOutput, Format('Erro ao criar backup do executavel atual em "%s".', [BakPath]));
      Halt(1);
    end;

    // Copia ou move o novo executável para o local definitivo
    if not RenameFile(NewExeCandidate, ExePath) then
    begin
      // Se mover falhou (ex: unidades de disco diferentes), tenta copiar
      if not CopyFileStream(NewExeCandidate, ExePath) then
      begin
        WriteLn(ErrOutput, 'Erro ao gravar o novo executavel. Restaurando backup anterior...');
        RenameFile(BakPath, ExePath);
        Halt(1);
      end;
    end;

    // Valida execução do novo binário
    ExitCode := RunProcessWithOutput(ExePath, '-h', TestLog);
    if ExitCode <> 0 then
    begin
      WriteLn(ErrOutput, 'Aviso: O novo binario falhou no auto-teste inicial. Restaurando backup anterior...');
      DeleteFile(ExePath);
      RenameFile(BakPath, ExePath);
      WriteLn(ErrOutput, 'Rollback automatico concluido com sucesso.');
      Halt(1);
    end;

    WriteLn('');
    WriteLn('========================================================');
    WriteLn(Format('  [SUCESSO] Compilador Aether atualizado para %s!   ', [TagName]));
    WriteLn('  Backup da versao anterior preservado em:             ');
    WriteLn(Format('    %s', [BakPath]));
    WriteLn('  Para reverter caso necessario: aetherc upgrade --rollback');
    WriteLn('========================================================');

  finally
    // Limpeza de arquivos temporários
    if FileExists(DownloadedFile) then DeleteFile(DownloadedFile);
  end;
end;

class procedure TAetherUpgrade.ExecuteUpgrade(const Opts: TUpgradeOptions);
var
  CurExe, GitDir: string;
begin
  CurExe := GetCurrentExePath;

  // 1. Rollback explícito solicitado
  if Opts.Rollback then
  begin
    HandleRollback(CurExe, Opts.DryRun);
    Exit;
  end;

  GitDir := FindGitRoot;

  // 2. Atualização via código-fonte explícita ou automática quando dentro de repo git
  if Opts.FromSource or ((GitDir <> '') and not Opts.BinaryMode and not Opts.CheckOnly) then
  begin
    if GitDir <> '' then
    begin
      HandleSourceUpgrade(GitDir, Opts);
      Exit;
    end
    else
    begin
      WriteLn(ErrOutput, 'Erro: Nenhum repositorio Git foi detectado no diretorio atual ou pastas superiores.');
      WriteLn(ErrOutput, 'Para atualizar usando binarios pre-compilados do release oficial:');
      WriteLn(ErrOutput, '  aetherc upgrade --binary');
      Halt(1);
    end;
  end;

  // 3. Atualização via pacotes binários
  HandleBinaryUpgrade(CurExe, Opts);
end;

end.
