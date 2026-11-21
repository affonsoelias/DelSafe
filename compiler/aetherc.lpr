program aetherc;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  uAetherTokens,
  uAetherLexer,
  uAetherAST,
  uAetherParser,
  uAetherSymbols,
  uAetherTypeChecker,
  uAetherBorrowChecker,
  uAetherEmitterPascal,
  uAetherEmitterC,
  uAetherToolchain,
  uAetherJSONDiag;

procedure PrintBanner;
begin
  WriteLn('========================================================');
  WriteLn('  AetherLang Compiler (aetherc) - Versao 0.5.0 (Alpha)  ');
  WriteLn('  Pascal Structure + Rust Safety + AI-Native Design     ');
  WriteLn('========================================================');
end;

procedure PrintUsage;
begin
  WriteLn('Uso: aetherc <arquivo.aeth> [opcoes]');
  WriteLn('');
  WriteLn('Opcoes Principais:');
  WriteLn('  --doctor          Verifica e diagnostica o ambiente (FPC e MSYS2/GCC)');
  WriteLn('  --target=pascal   Compila gerando Object Pascal e invoca FPC (Padrao)');
  WriteLn('  --target=c        Compila gerando C99 e invoca GCC (MSYS2 no Windows)');
  WriteLn('  --check-only      Executa apenas analise sintatica, tipos e borrow checker');
  WriteLn('  --dump-tokens     Exibe a lista de tokens do Lexer');
  WriteLn('  --dump-ast        Exibe a Arvore Sintatica Abstrata (AST)');
  WriteLn('  --emit-json-diag  Gera relatorio de diagnostico de erros em formato JSON para IA');
  WriteLn('  -o <arquivo.exe>  Especifica o nome do executavel de saida');
  WriteLn('  -h, --help        Exibe esta mensagem de ajuda');
end;

function LoadFileContent(const FileName: string): string;
var
  FileStream: TFileStream;
  StringStream: TStringStream;
begin
  if not FileExists(FileName) then
    raise Exception.CreateFmt('Arquivo nao encontrado: "%s"', [FileName]);

  FileStream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  StringStream := TStringStream.Create('');
  try
    StringStream.CopyFrom(FileStream, FileStream.Size);
    Result := StringStream.DataString;
  finally
    StringStream.Free;
    FileStream.Free;
  end;
end;

procedure DumpTokens(const SourceFile: string);
var
  Source: string;
  Lexer: TAetherLexer;
  Tok: TToken;
  Count: Integer;
begin
  Source := LoadFileContent(SourceFile);
  Lexer := TAetherLexer.Create(Source);
  try
    WriteLn(Format('--- Analise Lexica (Tokens) de: %s ---', [SourceFile]));
    Count := 0;
    repeat
      Tok := Lexer.NextToken;
      Inc(Count);
      WriteLn(Format('[Linha %3d, Col %3d] %-16s : "%s"', 
        [Tok.Line, Tok.Col, TokenKindToString(Tok.Kind), Tok.Value]));
    until Tok.Kind = tokEOF;
    WriteLn(Format('Total de tokens analisados: %d', [Count]));
  finally
    Lexer.Free;
  end;
end;

procedure CompileFile(const SourceFile: string; TargetPascal: Boolean; CheckOnly, DumpASTOnly: Boolean; const OutputExeName: string; SilentBanner: Boolean);
var
  Source: string;
  Lexer: TAetherLexer;
  Parser: TAetherParser;
  TypeChecker: TAetherTypeChecker;
  BorrowChecker: TAetherBorrowChecker;
  ModuleNode: TASTModule;
  GenDir, IntermediateFile, FinalExe: string;
  GeneratedCode: string;
  EmitterPas: TAetherEmitterPascal;
  EmitterC: TAetherEmitterC;
  Success: Boolean;
  CompileLog: string;
  CodeFile: TStringList;
begin
  Source := LoadFileContent(SourceFile);
  Lexer := TAetherLexer.Create(Source);
  Parser := TAetherParser.Create(Lexer);
  try
    ModuleNode := Parser.ParseModule;
    try
      if DumpASTOnly then
      begin
        WriteLn(Format('--- Arvore Sintatica Abstrata (AST) de: %s ---', [SourceFile]));
        WriteLn(ModuleNode.Dump(0));
        Exit;
      end;

      if not SilentBanner then
        WriteLn(Format('[1/4] Analise Sintatica de "%s": OK', [ExtractFileName(SourceFile)]));

      // 2. Verificacao de Tipos e Semantica
      TypeChecker := TAetherTypeChecker.Create;
      try
        TypeChecker.CheckModule(ModuleNode);
        if not SilentBanner then
          WriteLn('[2/4] Verificacao de Tipos: OK (0 erros)');

        // 3. Verificacao de Posse (Borrow Checker)
        BorrowChecker := TAetherBorrowChecker.Create(TypeChecker.Symbols);
        try
          BorrowChecker.CheckModule(ModuleNode);
          if not SilentBanner then
            WriteLn('[3/4] Verificacao de Posse (Borrow Checker): OK (0 erros)');
        finally
          BorrowChecker.Free;
        end;
      finally
        TypeChecker.Free;
      end;

      if CheckOnly then
      begin
        if not SilentBanner then
          WriteLn('Modo --check-only finalizado com sucesso.');
        Exit;
      end;

      // 4. Emissao de Codigo e Geracao do Executavel
      GenDir := ExtractFilePath(ParamStr(0)) + 'generated';
      if not DirectoryExists(GenDir) then
        CreateDir(GenDir);

      if OutputExeName <> '' then
        FinalExe := OutputExeName
      else
        FinalExe := ExtractFilePath(ParamStr(0)) + ChangeFileExt(ExtractFileName(SourceFile), '.exe');

      if TargetPascal then
      begin
        IntermediateFile := GenDir + PathDelim + ChangeFileExt(ExtractFileName(SourceFile), '.pas');
        EmitterPas := TAetherEmitterPascal.Create;
        try
          GeneratedCode := EmitterPas.Generate(ModuleNode);
        finally
          EmitterPas.Free;
        end;

        CodeFile := TStringList.Create;
        try
          CodeFile.Text := GeneratedCode;
          CodeFile.SaveToFile(IntermediateFile);
        finally
          CodeFile.Free;
        end;

        if not SilentBanner then
        begin
          WriteLn(Format('[4/4] Transpilando para Object Pascal -> "%s"', [ExtractFileName(IntermediateFile)]));
          WriteLn('      Invocando Free Pascal (fpc)...');
        end;

        CompileLog := '';
        Success := CompileWithFPC(IntermediateFile, FinalExe, CompileLog);
        if Success then
        begin
          if not SilentBanner then
          begin
            WriteLn('');
            WriteLn('SUCESSO! Executavel nativo gerado:');
            WriteLn('  --> ' + FinalExe);
          end;
        end
        else
        begin
          WriteLn(ErrOutput, 'Falha na compilacao com FPC:');
          WriteLn(ErrOutput, CompileLog);
          Halt(1);
        end;
      end
      else
      begin
        // Target C (MSYS2 GCC no Windows / GCC no Linux/macOS)
        IntermediateFile := GenDir + PathDelim + ChangeFileExt(ExtractFileName(SourceFile), '.c');
        EmitterC := TAetherEmitterC.Create;
        try
          GeneratedCode := EmitterC.Generate(ModuleNode);
        finally
          EmitterC.Free;
        end;

        CodeFile := TStringList.Create;
        try
          CodeFile.Text := GeneratedCode;
          CodeFile.SaveToFile(IntermediateFile);
        finally
          CodeFile.Free;
        end;

        if not SilentBanner then
        begin
          WriteLn(Format('[4/4] Transpilando para C99 -> "%s"', [ExtractFileName(IntermediateFile)]));
          WriteLn('      Invocando GCC...');
        end;

        CompileLog := '';
        Success := CompileWithGCC(IntermediateFile, FinalExe, CompileLog);
        if Success then
        begin
          if not SilentBanner then
          begin
            WriteLn('');
            WriteLn('SUCESSO! Executavel nativo gerado via GCC:');
            WriteLn('  --> ' + FinalExe);
          end;
        end
        else
        begin
          WriteLn(ErrOutput, 'Falha na compilacao com GCC:');
          WriteLn(ErrOutput, CompileLog);
          Halt(1);
        end;
      end;

    finally
      ModuleNode.Free;
    end;
  finally
    Parser.Free;
    Lexer.Free;
  end;
end;

var
  InputFile: string;
  OutputExe: string;
  OptionDumpTokens: Boolean;
  OptionDumpAST: Boolean;
  OptionCheckOnly: Boolean;
  OptionTargetPascal: Boolean;
  OptionJSONDiag: Boolean;
  I: Integer;
  Arg: string;
begin
  InputFile := '';
  OutputExe := '';
  OptionDumpTokens := False;
  OptionDumpAST := False;
  OptionCheckOnly := False;
  OptionTargetPascal := True;
  OptionJSONDiag := False;

  I := 1;
  while I <= ParamCount do
  begin
    Arg := ParamStr(I);
    if (Arg = '-h') or (Arg = '--help') then
    begin
      PrintBanner;
      PrintUsage;
      Halt(0);
    end
    else if Arg = '--doctor' then
    begin
      PrintBanner;
      PrintDoctorReport;
      Halt(0);
    end
    else if Arg = '--dump-tokens' then
      OptionDumpTokens := True
    else if Arg = '--dump-ast' then
      OptionDumpAST := True
    else if Arg = '--check-only' then
      OptionCheckOnly := True
    else if Arg = '--target=pascal' then
      OptionTargetPascal := True
    else if Arg = '--target=c' then
      OptionTargetPascal := False
    else if (Arg = '--emit-json-diag') or (Arg = '--emit-json-diagnostics') then
      OptionJSONDiag := True
    else if Arg = '-o' then
    begin
      Inc(I);
      if I <= ParamCount then OutputExe := ParamStr(I);
    end
    else if (Length(Arg) > 0) and (Arg[1] <> '-') then
    begin
      InputFile := Arg;
    end;
    Inc(I);
  end;

  if not OptionJSONDiag then
    PrintBanner;

  if InputFile = '' then
  begin
    if OptionJSONDiag then
      WriteLn(GenerateJSONDiagnostic('', 'Error', 'E0001', 'Nenhum arquivo fonte .aeth especificado.', 0, 0))
    else
    begin
      WriteLn('Erro: Nenhum arquivo fonte .aeth foi especificado.');
      WriteLn('');
      PrintUsage;
    end;
    Halt(1);
  end;

  try
    if OptionDumpTokens then
      DumpTokens(InputFile);

    CompileFile(InputFile, OptionTargetPascal, OptionCheckOnly, OptionDumpAST, OutputExe, OptionJSONDiag);
  except
    on E: EAetherBorrowError do
    begin
      if OptionJSONDiag then
        WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', E.Code, E.Message, E.Line, E.Col, E.MovedLine, E.MovedCol,
          'borrow_instead_of_move', 'Altere a chamada para "borrow" se a transferencia de posse nao for necessaria.', 'borrow'))
      else
        WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
      Halt(1);
    end;
    on E: EAetherTypeError do
    begin
      if OptionJSONDiag then
        WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', E.Code, E.Message, E.Line, E.Col))
      else
        WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
      Halt(1);
    end;
    on E: EAetherParserError do
    begin
      if OptionJSONDiag then
        WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', 'E0001', E.Message, E.Line, E.Col))
      else
        WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
      Halt(1);
    end;
    on E: EAetherLexerError do
    begin
      if OptionJSONDiag then
        WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', 'E0000', E.Message, E.Line, E.Col))
      else
        WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
      Halt(1);
    end;
    on E: Exception do
    begin
      if OptionJSONDiag then
        WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', 'E9999', E.Message, 1, 1))
      else
        WriteLn(ErrOutput, 'Erro de Compilacao: ', E.Message);
      Halt(1);
    end;
  end;
end.
