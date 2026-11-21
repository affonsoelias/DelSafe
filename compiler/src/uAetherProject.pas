unit uAetherProject;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  SysUtils, Classes, fpjson, jsonparser;

type
  TAetherProjectConfig = record
    Name: string;
    Version: string;
    Description: string;
    Backend: string;
    Entry: string;
    Output: string;
    RootDir: string;
    ConfigFile: string;
  end;

function FindProjectRoot(out RootDir, ConfigFile: string): Boolean;
function LoadProjectConfig(out Config: TAetherProjectConfig): Boolean;
procedure HandleProjectInit(const ProjectName: string);

implementation

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

function LoadProjectConfig(out Config: TAetherProjectConfig): Boolean;
var
  RootDir, ConfigFile, JsonStr: string;
  FileStream: TFileStream;
  StringStream: TStringStream;
  JSON: TJSONData;
  Obj: TJSONObject;
begin
  Result := False;
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
        Config.Backend := LowerCase(Obj.Get('backend', 'pascal'));
        Config.Entry := Obj.Get('entry', 'src' + PathDelim + 'main.aeth');
        Config.Output := Obj.Get('output', 'bin' + PathDelim + Config.Name + '.exe');
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

procedure HandleProjectInit(const ProjectName: string);
var
  TargetDir, EffectiveName: string;
  SrcDir, TestsDir, BinDir: string;
  ConfigFile, MainFile, TestFile, GitignoreFile, ReadmeFile: string;
  ConfigObj: TJSONObject;
begin
  if ProjectName <> '' then
  begin
    EffectiveName := ProjectName;
    TargetDir := ExpandFileName(GetCurrentDir + PathDelim + ProjectName);
    if not DirectoryExists(TargetDir) then
    begin
      if not ForceDirectories(TargetDir) then
        raise Exception.CreateFmt('Nao foi possivel criar o diretorio "%s"', [TargetDir]);
    end;
  end
  else
  begin
    TargetDir := ExpandFileName(GetCurrentDir);
    EffectiveName := ExtractFileName(ExcludeTrailingPathDelimiter(TargetDir));
    if EffectiveName = '' then
      EffectiveName := 'aether_app';
  end;

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
    ConfigObj.Add('entry', 'src/main.aeth');
    ConfigObj.Add('output', 'bin/' + EffectiveName + '.exe');
    WriteStringToFile(ConfigFile, ConfigObj.FormatJSON);
  finally
    ConfigObj.Free;
  end;

  // 2. Gera src/main.aeth
  MainFile := SrcDir + PathDelim + 'main.aeth';
  WriteStringToFile(MainFile,
    'module Main;' + LineEnding +
    '' + LineEnding +
    'import Math;' + LineEnding +
    'import IO;' + LineEnding +
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
    'end.' + LineEnding
  );

  // 3. Gera tests/main_test.aeth
  TestFile := TestsDir + PathDelim + 'main_test.aeth';
  WriteStringToFile(TestFile,
    'module MainTest;' + LineEnding +
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
    '    PrintLn("[SUCESSO] Todos os testes passaram!");' + LineEnding +
    'end.' + LineEnding
  );

  // 4. Gera .gitignore
  GitignoreFile := TargetDir + PathDelim + '.gitignore';
  WriteStringToFile(GitignoreFile,
    'bin/' + LineEnding +
    'generated/' + LineEnding +
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
    '- `src/main.aeth`: Código-fonte principal da aplicação.' + LineEnding +
    '- `tests/main_test.aeth`: Testes unitários do projeto.' + LineEnding +
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
  WriteLn('   ├── src/main.aeth');
  WriteLn('   ├── tests/main_test.aeth');
  WriteLn('   ├── .gitignore');
  WriteLn('   └── README.md');
  WriteLn('');
  WriteLn(' Proximos passos:');
  if ProjectName <> '' then
    WriteLn(Format('   cd %s', [ProjectName]));
  WriteLn('   aetherc run');
  WriteLn('--------------------------------------------------------');
end;

end.
