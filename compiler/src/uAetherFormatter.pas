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
  I, Len: Integer;
  InString: Boolean;
  InComment: Boolean;
  C, NextC: Char;
  Res: string;
begin
  Res := '';
  InString := False;
  InComment := False;
  I := 1;
  Len := Length(Line);

  while I <= Len do
  begin
    C := Line[I];
    if I < Len then NextC := Line[I + 1] else NextC := #0;

    // Detecta comentario de linha
    if (not InString) and (C = '/') and (NextC = '/') then
    begin
      InComment := True;
      Res := Res + Copy(Line, I, Len - I + 1);
      Break;
    end;

    // Detecta string literal
    if (not InComment) and (C = '"') then
    begin
      InString := not InString;
      Res := Res + C;
      Inc(I);
      Continue;
    end;

    // Se estiver dentro de string, mantem inalterado
    if InString then
    begin
      Res := Res + C;
      Inc(I);
      Continue;
    end;

    // Normalizacao de atribuicao :=
    if (C = ':') and (NextC = '=') then
    begin
      // Garante espaço antes se o anterior nao for espaço
      if (Length(Res) > 0) and (Res[Length(Res)] <> ' ') then
        Res := Res + ' ';
      Res := Res + ':= ';
      Inc(I, 2);
      // Pula espacos adicionais apos :=
      while (I <= Len) and (Line[I] in [' ', #9]) do Inc(I);
      Continue;
    end;

    // Normalizacao de dois-pontos : (declaracao de tipo)
    if (C = ':') and (NextC <> '=') then
    begin
      // Remove espacos anteriores a ':' se houver
      while (Length(Res) > 0) and (Res[Length(Res)] = ' ') do
        Delete(Res, Length(Res), 1);
      Res := Res + ': ';
      Inc(I);
      while (I <= Len) and (Line[I] in [' ', #9]) do Inc(I);
      Continue;
    end;

    // Normalizacao de virgula ,
    if C = ',' then
    begin
      while (Length(Res) > 0) and (Res[Length(Res)] = ' ') do
        Delete(Res, Length(Res), 1);
      Res := Res + ', ';
      Inc(I);
      while (I <= Len) and (Line[I] in [' ', #9]) do Inc(I);
      Continue;
    end;

    // Normalizacao de ponto e virgula ;
    if C = ';' then
    begin
      while (Length(Res) > 0) and (Res[Length(Res)] = ' ') do
        Delete(Res, Length(Res), 1);
      Res := Res + ';';
      Inc(I);
      Continue;
    end;

    // Normalizacao de operadores relacionais e binarios
    if (C = '=') and (Length(Res) > 0) and (Res[Length(Res)] <> ':') and
       (Res[Length(Res)] <> '<') and (Res[Length(Res)] <> '>') and
       (Res[Length(Res)] <> '=') and (NextC <> '=') then
    begin
      if Res[Length(Res)] <> ' ' then Res := Res + ' ';
      Res := Res + '= ';
      Inc(I);
      while (I <= Len) and (Line[I] in [' ', #9]) do Inc(I);
      Continue;
    end;

    if (C = '<') and (NextC <> '=') and (NextC <> '>') then
    begin
      if (Length(Res) > 0) and (Res[Length(Res)] <> ' ') then Res := Res + ' ';
      Res := Res + '< ';
      Inc(I);
      while (I <= Len) and (Line[I] in [' ', #9]) do Inc(I);
      Continue;
    end;

    if (C = '>') and (NextC <> '=') then
    begin
      if (Length(Res) > 0) and (Res[Length(Res)] <> ' ') then Res := Res + ' ';
      Res := Res + '> ';
      Inc(I);
      while (I <= Len) and (Line[I] in [' ', #9]) do Inc(I);
      Continue;
    end;

    if (C = '+') then
    begin
      if (Length(Res) > 0) and (Res[Length(Res)] <> ' ') then Res := Res + ' ';
      Res := Res + '+ ';
      Inc(I);
      while (I <= Len) and (Line[I] in [' ', #9]) do Inc(I);
      Continue;
    end;

    if (C = '-') and (Length(Res) > 0) and (IsAlphaNumChar(Res[Length(Res)]) or (Res[Length(Res)] = ' ')) then
    begin
      if Res[Length(Res)] <> ' ' then Res := Res + ' ';
      Res := Res + '- ';
      Inc(I);
      while (I <= Len) and (Line[I] in [' ', #9]) do Inc(I);
      Continue;
    end;

    Res := Res + C;
    Inc(I);
  end;

  Result := Res;
end;

class function TAetherFormatter.FormatSource(const Source: string): string;
var
  Lines: TStringList;
  I: Integer;
  RawLine, TrimmedLine, LowerLine: string;
  IndentLevel: Integer;
  CurrentIndent: Integer;
  IndentedLine: string;
  OutputList: TStringList;
  BlankCount: Integer;
  InAsmBlock: Boolean;
begin
  Lines := TStringList.Create;
  OutputList := TStringList.Create;
  try
    Lines.Text := Source;
    IndentLevel := 0;
    BlankCount := 0;
    InAsmBlock := False;

    for I := 0 to Lines.Count - 1 do
    begin
      RawLine := Lines[I];
      TrimmedLine := Trim(RawLine);

      // Tratamento de linhas em branco
      if TrimmedLine = '' then
      begin
        Inc(BlankCount);
        if BlankCount <= 1 then // Maximo de 1 linha em branco consecutiva
          OutputList.Add('');
        Continue;
      end;

      BlankCount := 0;
      LowerLine := LowerCase(TrimmedLine);

      // Se estiver em bloco asm, preserva conteudo interno com indentacao
      if InAsmBlock then
      begin
        if (Pos('end;', LowerLine) = 1) or (Pos('end', LowerLine) = 1) then
        begin
          InAsmBlock := False;
          if IndentLevel > 0 then Dec(IndentLevel);
          CurrentIndent := IndentLevel;
        end
        else
        begin
          CurrentIndent := IndentLevel;
          OutputList.Add(StringOfChar(' ', CurrentIndent * 4) + TrimmedLine);
          Continue;
        end;
      end
      else
      begin
        // Checa se esta linha fecha um bloco ou diminui indentacao visual
        CurrentIndent := IndentLevel;

        if (Pos('end;', LowerLine) = 1) or (Pos('end.', LowerLine) = 1) or (Pos('end', LowerLine) = 1) then
        begin
          if IndentLevel > 0 then Dec(IndentLevel);
          CurrentIndent := IndentLevel;
        end
        else if (LowerLine = 'begin') and (IndentLevel > 0) then
        begin
          IndentLevel := IndentLevel - 1;
          CurrentIndent := IndentLevel;
        end
        else if (Pos('else', LowerLine) = 1) or (Pos('else ', LowerLine) = 1) then
        begin
          if CurrentIndent > 0 then
            CurrentIndent := CurrentIndent - 1;
        end
        else if (Pos('until ', LowerLine) = 1) or (Pos('until(', LowerLine) = 1) then
        begin
          if IndentLevel > 0 then Dec(IndentLevel);
          CurrentIndent := IndentLevel;
        end;
      end;

      // Normaliza operadores da linha
      TrimmedLine := NormalizeOperators(TrimmedLine);

      // Aplica a indentacao correta (4 espacos por nivel)
      if CurrentIndent > 0 then
        IndentedLine := StringOfChar(' ', CurrentIndent * 4) + TrimmedLine
      else
        IndentedLine := TrimmedLine;

      IndentedLine := TrimRightSpaces(IndentedLine);
      OutputList.Add(IndentedLine);

      // Checa se a linha abre um novo bloco de indentacao
      if not InAsmBlock then
      begin
        if (Pos('asm', LowerLine) = 1) or (Pos('asm ', LowerLine) = 1) then
        begin
          InAsmBlock := True;
          Inc(IndentLevel);
        end
        else if (Pos('begin', LowerLine) = 1) or (Pos('record', LowerLine) = 1) or
                (Pos('enum', LowerLine) = 1) or (Pos('trait', LowerLine) = 1) or
                (Pos('type', LowerLine) = 1) or (Pos('var', LowerLine) = 1) then
        begin
          // Se nao for uma linha com fechamento embutido (ex: begin end;)
          if Pos('end;', LowerLine) = 0 then
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
