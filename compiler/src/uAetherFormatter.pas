unit uAetherFormatter;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

type
  { TAetherFormatter: Formatador Canônico Oficial de Código Aether }
  TAetherFormatter = class
  private
    class function IsAlphaNumChar(C: Char): Boolean;
    class function NormalizeOperators(const Line: string): string;
    class function TrimRightSpaces(const S: string): string;
  public
    class function FormatSource(const Source: string): string;
    class function FormatFile(const FilePath: string; CheckOnly: Boolean = False): Boolean;
    class function FormatDirectory(const DirPath: string; var TotalFiles, FormattedFiles: Integer; CheckOnly: Boolean = False): Boolean;
  end;

implementation

class function TAetherFormatter.IsAlphaNumChar(C: Char): Boolean;
begin
  Result := (C in ['a'..'z', 'A'..'Z', '0'..'9', '_']);
end;

class function TAetherFormatter.TrimRightSpaces(const S: string): string;
var
  I: Integer;
begin
  I := Length(S);
  while (I > 0) and (S[I] in [' ', #9]) do
    Dec(I);
  Result := Copy(S, 1, I);
end;

class function TAetherFormatter.NormalizeOperators(const Line: string): string;
var
  I, Len, GenericDepth: Integer;
  InString, InChar: Boolean;
  C, NextC, LastCh: Char;
  Res, TwoChar: string;

  procedure TrimResTrailingSpaces;
  begin
    while (Length(Res) > 0) and (Res[Length(Res)] = ' ') do
      Delete(Res, Length(Res), 1);
  end;

  procedure SkipLineSpaces;
  begin
    while (I <= Len) and (Line[I] in [' ', #9]) do
      Inc(I);
  end;

  procedure EmitSpacedOp(const Op: string);
  begin
    TrimResTrailingSpaces;
    if Length(Res) > 0 then
      Res := Res + ' ';
    Res := Res + Op + ' ';
    Inc(I, Length(Op));
    SkipLineSpaces;
  end;

begin
  Res := '';
  InString := False;
  InChar := False;
  GenericDepth := 0;
  I := 1;
  Len := Length(Line);

  while I <= Len do
  begin
    C := Line[I];
    if I < Len then NextC := Line[I + 1] else NextC := #0;

    // Detecta comentario de linha
    if (not InString) and (not InChar) and (C = '/') and (NextC = '/') then
    begin
      Res := Res + Copy(Line, I, Len - I + 1);
      Break;
    end;

    // Detecta string literal "..."
    if (not InChar) and (C = '"') then
    begin
      InString := not InString;
      Res := Res + C;
      Inc(I);
      Continue;
    end;

    if InString then
    begin
      if (C = '\') and (NextC <> #0) then
      begin
        Res := Res + C + NextC;
        Inc(I, 2);
        Continue;
      end;
      Res := Res + C;
      Inc(I);
      Continue;
    end;

    // Detecta literal Char '...'
    if C = '''' then
    begin
      InChar := not InChar;
      Res := Res + C;
      Inc(I);
      Continue;
    end;

    if InChar then
    begin
      if (C = '\') and (NextC <> #0) then
      begin
        Res := Res + C + NextC;
        Inc(I, 2);
        Continue;
      end;
      Res := Res + C;
      Inc(I);
      Continue;
    end;

    // Colapsa espacos consecutivos fora de strings/comentarios
    if C in [' ', #9] then
    begin
      if (Length(Res) > 0) and (Res[Length(Res)] <> ' ') then
        Res := Res + ' ';
      Inc(I);
      Continue;
    end;

    // Operadores compostos de 2 caracteres (prioridade sobre 1 caractere)
    TwoChar := C + NextC;
    if (TwoChar = ':=') or (TwoChar = '+=') or (TwoChar = '-=') or (TwoChar = '*=') or
       (TwoChar = '/=') or (TwoChar = '=>') or (TwoChar = '<>') or (TwoChar = '<=') or
       (TwoChar = '>=') then
    begin
      EmitSpacedOp(TwoChar);
      Continue;
    end;

    if TwoChar = '..' then
    begin
      TrimResTrailingSpaces;
      Res := Res + '..';
      Inc(I, 2);
      SkipLineSpaces;
      Continue;
    end;

    if C = ':' then
    begin
      TrimResTrailingSpaces;
      Res := Res + ': ';
      Inc(I);
      SkipLineSpaces;
      Continue;
    end;

    if C = ',' then
    begin
      TrimResTrailingSpaces;
      Res := Res + ', ';
      Inc(I);
      SkipLineSpaces;
      Continue;
    end;

    if C = ';' then
    begin
      TrimResTrailingSpaces;
      Res := Res + ';';
      Inc(I);
      Continue;
    end;

    if C = '=' then
    begin
      EmitSpacedOp('=');
      Continue;
    end;

    if C = '<' then
    begin
      if (Length(Res) > 0) and IsAlphaNumChar(Res[Length(Res)]) then
      begin
        Inc(GenericDepth);
        Res := Res + '<';
        Inc(I);
      end
      else
        EmitSpacedOp('<');
      Continue;
    end;

    if C = '>' then
    begin
      if GenericDepth > 0 then
      begin
        Dec(GenericDepth);
        TrimResTrailingSpaces;
        Res := Res + '>';
        Inc(I);
      end
      else
        EmitSpacedOp('>');
      Continue;
    end;

    if C = '+' then
    begin
      EmitSpacedOp('+');
      Continue;
    end;

    if C = '-' then
    begin
      if Length(Res) = 0 then LastCh := #0 else LastCh := Res[Length(Res)];
      if (LastCh = #0) or (LastCh in ['(', '[', ',', '=', ':', '<', '>', '+', '-', '*', '/', '.']) then
      begin
        // Sinal unario ou negativo apos operador/delimitador (ex: (-42), -10..-1)
        Res := Res + '-';
        Inc(I);
      end
      else if (LastCh = ' ') and (Length(Res) >= 2) and (Res[Length(Res) - 1] in ['=', ':', ',', '<', '>', '+', '-', '*', '/', '(']) then
      begin
        Res := Res + '-';
        Inc(I);
      end
      else if (Pos('return ', LowerCase(Res)) = Length(Res) - 6) or
              (Pos('then ', LowerCase(Res)) = Length(Res) - 4) or
              (Pos('else ', LowerCase(Res)) = Length(Res) - 4) or
              (Pos('case ', LowerCase(Res)) = Length(Res) - 4) or
              (Pos('do ', LowerCase(Res)) = Length(Res) - 2) then
      begin
        Res := Res + '-';
        Inc(I);
      end
      else
        EmitSpacedOp('-');
      Continue;
    end;

    Res := Res + C;
    Inc(I);
  end;

  Result := TrimRightSpaces(Res);
end;

class function TAetherFormatter.FormatSource(const Source: string): string;
const
  bkBlock = 1;
  bkMatch = 2;
  bkMatchArm = 3;
var
  Lines, OutputList: TStringList;
  I, IndentLevel, SectionIndent, CurrentIndent, BlankCount: Integer;
  RawLine, TrimmedLine, LowerLine, CodeOnly, IndentedLine: string;
  InAsmBlock: Boolean;
  BlockStack: array of Integer;

  procedure PushBlock(Kind: Integer);
  begin
    SetLength(BlockStack, Length(BlockStack) + 1);
    BlockStack[High(BlockStack)] := Kind;
  end;

  function TopBlock: Integer;
  begin
    if Length(BlockStack) > 0 then
      Result := BlockStack[High(BlockStack)]
    else
      Result := 0;
  end;

  procedure PopBlock;
  begin
    if Length(BlockStack) > 0 then
      SetLength(BlockStack, Length(BlockStack) - 1);
  end;

  function StripLineComment(const S: string): string;
  var
    K: Integer;
    InS, InC: Boolean;
  begin
    InS := False; InC := False;
    for K := 1 to Length(S) do
    begin
      if (not InC) and (S[K] = '"') and ((K = 1) or (S[K - 1] <> '\')) then InS := not InS
      else if (not InS) and (S[K] = '''') and ((K = 1) or (S[K - 1] <> '\')) then InC := not InC
      else if (not InS) and (not InC) and (S[K] = '/') and (K < Length(S)) and (S[K + 1] = '/') then
        Exit(Trim(Copy(S, 1, K - 1)));
    end;
    Result := Trim(S);
  end;

  function EndsWithWord(const S, W: string): Boolean;
  var
    L, WL: Integer;
  begin
    L := Length(S); WL := Length(W);
    if L < WL then Exit(False);
    if Copy(S, L - WL + 1, WL) <> W then Exit(False);
    Result := (L = WL) or (not IsAlphaNumChar(S[L - WL]));
  end;

  function StartsWithWord(const S, W: string): Boolean;
  var
    L, WL: Integer;
  begin
    L := Length(S); WL := Length(W);
    if L < WL then Exit(False);
    if Copy(S, 1, WL) <> W then Exit(False);
    Result := (L = WL) or (not IsAlphaNumChar(S[WL + 1]));
  end;

begin
  Lines := TStringList.Create;
  OutputList := TStringList.Create;
  SetLength(BlockStack, 0);
  try
    Lines.Text := Source;
    IndentLevel := 0;
    SectionIndent := 0;
    BlankCount := 0;
    InAsmBlock := False;

    for I := 0 to Lines.Count - 1 do
    begin
      RawLine := Lines[I];
      TrimmedLine := Trim(RawLine);

      if TrimmedLine = '' then
      begin
        Inc(BlankCount);
        if BlankCount <= 1 then
          OutputList.Add('');
        Continue;
      end;

      BlankCount := 0;
      CodeOnly := LowerCase(StripLineComment(TrimmedLine));
      LowerLine := LowerCase(TrimmedLine);

      // Bloco asm preserva conteudo interno
      if InAsmBlock then
      begin
        if (CodeOnly = 'end;') or (CodeOnly = 'end') then
        begin
          InAsmBlock := False;
          if IndentLevel > 0 then Dec(IndentLevel);
          if TopBlock = bkBlock then PopBlock;
          CurrentIndent := IndentLevel + SectionIndent;
        end
        else
        begin
          OutputList.Add(StringOfChar(' ', (IndentLevel + SectionIndent) * 4) + TrimmedLine);
          Continue;
        end;
      end
      else
      begin
        // Fim de secao no nivel superior antes de nova funcao, program ou outra secao de modulo
        if (Length(BlockStack) = 0) and (
             StartsWithWord(CodeOnly, 'function') or StartsWithWord(CodeOnly, 'async') or
             StartsWithWord(CodeOnly, 'extern') or StartsWithWord(CodeOnly, 'export') or
             StartsWithWord(CodeOnly, 'program') or (CodeOnly = 'type') or
             (CodeOnly = 'const') or (CodeOnly = 'var') or (CodeOnly = 'let') or
             (CodeOnly = 'contract') or StartsWithWord(CodeOnly, 'impl')
           ) then
          SectionIndent := 0;

        // Secoes require/ensure alinham no nivel 1 dentro de contract antes de var/let/begin
        if (CodeOnly = 'require') or (CodeOnly = 'ensure') then
          SectionIndent := 1
        else if (CodeOnly = 'var') or (CodeOnly = 'let') or (CodeOnly = 'begin') then
          SectionIndent := 0;

        // Fechamento de blocos
        if (CodeOnly = 'end;') or (CodeOnly = 'end.') or (CodeOnly = 'end') then
        begin
          if TopBlock = bkMatchArm then
          begin
            PopBlock;
            if IndentLevel > 0 then Dec(IndentLevel);
          end;
          if Length(BlockStack) > 0 then
            PopBlock;
          if IndentLevel > 0 then Dec(IndentLevel);
          CurrentIndent := IndentLevel + SectionIndent;
        end
        else if StartsWithWord(CodeOnly, 'until') then
        begin
          if Length(BlockStack) > 0 then PopBlock;
          if IndentLevel > 0 then Dec(IndentLevel);
          CurrentIndent := IndentLevel + SectionIndent;
        end
        else if StartsWithWord(CodeOnly, 'else') or (CodeOnly = 'except') then
        begin
          CurrentIndent := IndentLevel + SectionIndent;
          if CurrentIndent > 0 then Dec(CurrentIndent);
        end
        else if (TopBlock = bkMatchArm) and (
                  (Copy(CodeOnly, Length(CodeOnly) - 1, 2) = '=>') or
                  (StartsWithWord(CodeOnly, 'case') and (Length(CodeOnly) > 0) and (CodeOnly[Length(CodeOnly)] = ':')) or
                  ((Length(CodeOnly) > 0) and (CodeOnly[Length(CodeOnly)] = ':') and (Pos(':=', CodeOnly) = 0))
                ) then
        begin
          PopBlock;
          if IndentLevel > 0 then Dec(IndentLevel);
          CurrentIndent := IndentLevel + SectionIndent;
        end
        else
          CurrentIndent := IndentLevel + SectionIndent;
      end;

      // Normaliza operadores apenas fora de comentarios puros
      if (Pos('//', TrimmedLine) <> 1) and (Pos('/*', TrimmedLine) <> 1) and (Pos('{', TrimmedLine) <> 1) then
        TrimmedLine := NormalizeOperators(TrimmedLine);

      if CurrentIndent > 0 then
        IndentedLine := StringOfChar(' ', CurrentIndent * 4) + TrimmedLine
      else
        IndentedLine := TrimmedLine;

      IndentedLine := TrimRightSpaces(IndentedLine);
      OutputList.Add(IndentedLine);

      // Abertura de secoes e blocos compostos para as linhas seguintes
      if (not InAsmBlock) and (CodeOnly <> '') then
      begin
        if CodeOnly = 'asm' then
        begin
          InAsmBlock := True;
          PushBlock(bkBlock);
          Inc(IndentLevel);
        end
        else if (CodeOnly = 'type') or (CodeOnly = 'const') or (CodeOnly = 'var') or (CodeOnly = 'let') or (CodeOnly = 'contract') then
        begin
          SectionIndent := 1;
        end
        else if (CodeOnly = 'require') or (CodeOnly = 'ensure') then
        begin
          if SectionIndent < 2 then SectionIndent := 2;
        end
        else if (TopBlock = bkMatch) and (
                  (Copy(CodeOnly, Length(CodeOnly) - 1, 2) = '=>') or
                  ((Length(CodeOnly) > 0) and (CodeOnly[Length(CodeOnly)] = ':') and (Pos(':=', CodeOnly) = 0))
                ) then
        begin
          PushBlock(bkMatchArm);
          Inc(IndentLevel);
        end
        else if (StartsWithWord(CodeOnly, 'match') and (EndsWithWord(CodeOnly, 'do') or EndsWithWord(CodeOnly, 'with'))) then
        begin
          PushBlock(bkMatch);
          Inc(IndentLevel);
        end
        else if (CodeOnly = 'begin') or (CodeOnly = 'repeat') or (CodeOnly = 'try') or (CodeOnly = 'unsafe') or
                (EndsWithWord(CodeOnly, 'record') and (Pos('end;', CodeOnly) = 0)) or
                (EndsWithWord(CodeOnly, 'enum') and (Pos('end;', CodeOnly) = 0)) or
                (StartsWithWord(CodeOnly, 'impl') and (Pos('end;', CodeOnly) = 0)) or
                (StartsWithWord(CodeOnly, 'trait') and (Pos('end;', CodeOnly) = 0)) or
                ((Pos('= trait', CodeOnly) > 0) and (Pos('end;', CodeOnly) = 0)) or
                (StartsWithWord(CodeOnly, 'if') and EndsWithWord(CodeOnly, 'then')) or
                (StartsWithWord(CodeOnly, 'while') and EndsWithWord(CodeOnly, 'do')) or
                (StartsWithWord(CodeOnly, 'for') and EndsWithWord(CodeOnly, 'do')) then
        begin
          PushBlock(bkBlock);
          Inc(IndentLevel);
        end;
      end;
    end;

    Result := OutputList.Text;
    if (Result <> '') and (Result[Length(Result)] <> #10) then
      Result := Result + LineEnding;
  finally
    Lines.Free;
    OutputList.Free;
  end;
end;

class function TAetherFormatter.FormatFile(const FilePath: string; CheckOnly: Boolean): Boolean;
var
  OriginalContent, FormattedContent: string;
  F: TextFile;
  Line: string;
begin
  Result := True;
  if not FileExists(FilePath) then
    Exit(False);

  // Le conteudo original
  OriginalContent := '';
  AssignFile(F, FilePath);
  {$I-} Reset(F); {$I+}
  if IOResult <> 0 then Exit(False);
  while not Eof(F) do
  begin
    ReadLn(F, Line);
    OriginalContent := OriginalContent + Line + LineEnding;
  end;
  CloseFile(F);

  FormattedContent := FormatSource(OriginalContent);

  // Compara
  if OriginalContent <> FormattedContent then
  begin
    if not CheckOnly then
    begin
      // Grava formatado
      AssignFile(F, FilePath);
      {$I-} Rewrite(F); {$I+}
      if IOResult <> 0 then Exit(True);
      Write(F, FormattedContent);
      CloseFile(F);
    end;
    Result := False; // Retorna False para indicar que precisava de formatacao
  end
  else
    Result := True;
end;

class function TAetherFormatter.FormatDirectory(const DirPath: string; var TotalFiles, FormattedFiles: Integer; CheckOnly: Boolean): Boolean;
var
  SearchRec: TSearchRec;
  FilePath: string;
  IsClean: Boolean;
begin
  Result := True;
  if FindFirst(DirPath + PathDelim + '*.aeth', faAnyFile, SearchRec) = 0 then
  begin
    repeat
      if (SearchRec.Attr and faDirectory) = 0 then
      begin
        FilePath := DirPath + PathDelim + SearchRec.Name;
        Inc(TotalFiles);
        IsClean := FormatFile(FilePath, CheckOnly);
        if not IsClean then
        begin
          Inc(FormattedFiles);
          Result := False;
        end;
      end;
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;

  // Busca recursiva em subpastas
  if FindFirst(DirPath + PathDelim + '*', faDirectory, SearchRec) = 0 then
  begin
    repeat
      if ((SearchRec.Attr and faDirectory) <> 0) and
         (SearchRec.Name <> '.') and (SearchRec.Name <> '..') and
         (SearchRec.Name <> '.git') and (SearchRec.Name <> 'bin') and
         (SearchRec.Name <> 'generated') and (SearchRec.Name <> 'cache') then
      begin
        FormatDirectory(DirPath + PathDelim + SearchRec.Name, TotalFiles, FormattedFiles, CheckOnly);
      end;
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;
end;

end.
