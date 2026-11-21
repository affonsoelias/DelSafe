unit uAetherLexer;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, uAetherTokens;

type
  EAetherLexerError = class(Exception)
  public
    Line: Integer;
    Col: Integer;
    constructor Create(const Msg: string; ALine, ACol: Integer);
  end;

  TAetherLexer = class
  private
    FSource: string;
    FPos: Integer;
    FLength: Integer;
    FLine: Integer;
    FCol: Integer;

    function PeekChar(Offset: Integer = 0): Char;
    function ReadChar: Char;
    function IsEOF: Boolean;
    procedure SkipWhitespaceAndComments;

    function ScanIdentifierOrKeyword: TToken;
    function ScanNumber: TToken;
    function ScanString: TToken;
    function ScanCharLiteral: TToken;
  public
    constructor Create(const ASource: string);
    function NextToken: TToken;
    property Line: Integer read FLine;
    property Col: Integer read FCol;
  end;

implementation

constructor EAetherLexerError.Create(const Msg: string; ALine, ACol: Integer);
begin
  inherited Create(Format('[Erro Lexico em %d:%d]: %s', [ALine, ACol, Msg]));
  Line := ALine;
  Col := ACol;
end;

constructor TAetherLexer.Create(const ASource: string);
begin
  inherited Create;
  FSource := ASource;
  FLength := Length(FSource);
  FPos := 1;
  FLine := 1;
  FCol := 1;
end;

function TAetherLexer.PeekChar(Offset: Integer): Char;
var
  TargetPos: Integer;
begin
  TargetPos := FPos + Offset;
  if (TargetPos >= 1) and (TargetPos <= FLength) then
    Result := FSource[TargetPos]
  else
    Result := #0;
end;

function TAetherLexer.ReadChar: Char;
begin
  if not IsEOF then
  begin
    Result := FSource[FPos];
    Inc(FPos);
    if Result = #10 then
    begin
      Inc(FLine);
      FCol := 1;
    end
    else
    begin
      Inc(FCol);
    end;
  end
  else
    Result := #0;
end;

function TAetherLexer.IsEOF: Boolean;
begin
  Result := FPos > FLength;
end;

procedure TAetherLexer.SkipWhitespaceAndComments;
var
  C, NextC: Char;
begin
  while not IsEOF do
  begin
    C := PeekChar;

    // Espacos em branco, tabs e quebras de linha
    if C in [' ', #9, #10, #13] then
    begin
      ReadChar;
      Continue;
    end;

    // Comentario de linha //
    if (C = '/') and (PeekChar(1) = '/') then
    begin
      ReadChar; // Consome primeiro /
      ReadChar; // Consome segundo /
      while (not IsEOF) and (PeekChar <> #10) do
        ReadChar;
      Continue;
    end;

    // Comentario de bloco Pascal { ... }
    if C = '{' then
    begin
      ReadChar; // Consome {
      while (not IsEOF) and (PeekChar <> '}') do
        ReadChar;
      if not IsEOF then
        ReadChar; // Consome }
      Continue;
    end;

    // Comentario de bloco C /* ... */
    if (C = '/') and (PeekChar(1) = '*') then
    begin
      ReadChar; // Consome /
      ReadChar; // Consome *
      while not IsEOF do
      begin
        if (PeekChar = '*') and (PeekChar(1) = '/') then
        begin
          ReadChar; // Consome *
          ReadChar; // Consome /
          Break;
        end;
        ReadChar;
      end;
      Continue;
    end;

    Break;
  end;
end;

function TAetherLexer.ScanIdentifierOrKeyword: TToken;
var
  StartLine, StartCol: Integer;
  Val: string;
  Kind: TTokenKind;
begin
  StartLine := FLine;
  StartCol := FCol;
  Val := '';

  while (not IsEOF) and (PeekChar in ['a'..'z', 'A'..'Z', '0'..'9', '_']) do
  begin
    Val := Val + ReadChar;
  end;

  Kind := LookupKeyword(Val);
  Result := CreateToken(Kind, Val, StartLine, StartCol);
end;

function TAetherLexer.ScanNumber: TToken;
var
  StartLine, StartCol: Integer;
  Val: string;
  IsFloat: Boolean;
  C: Char;
begin
  StartLine := FLine;
  StartCol := FCol;
  Val := '';
  IsFloat := False;

  // Hexadecimal estilo $FF ou 0x
  if (PeekChar = '$') or ((PeekChar = '0') and (PeekChar(1) in ['x', 'X'])) then
  begin
    if PeekChar = '$' then
      Val := Val + ReadChar
    else
    begin
      Val := Val + ReadChar; // '0'
      Val := Val + ReadChar; // 'x'
    end;
    while (not IsEOF) and (PeekChar in ['0'..'9', 'a'..'f', 'A'..'F', '_']) do
    begin
      C := ReadChar;
      if C <> '_' then
        Val := Val + C;
    end;
    Result := CreateToken(tokIntLiteral, Val, StartLine, StartCol);
    Exit;
  end;

  // Binario estilo %1010 ou 0b
  if (PeekChar = '%') or ((PeekChar = '0') and (PeekChar(1) in ['b', 'B'])) then
  begin
    if PeekChar = '%' then
      Val := Val + ReadChar
    else
    begin
      Val := Val + ReadChar; // '0'
      Val := Val + ReadChar; // 'b'
    end;
    while (not IsEOF) and (PeekChar in ['0', '1', '_']) do
    begin
      C := ReadChar;
      if C <> '_' then
        Val := Val + C;
    end;
    Result := CreateToken(tokIntLiteral, Val, StartLine, StartCol);
    Exit;
  end;

  // Decimal ou Float
  while (not IsEOF) and (PeekChar in ['0'..'9', '_']) do
  begin
    C := ReadChar;
    if C <> '_' then
      Val := Val + C;
  end;

  // Ponto flutuante (cuidado com operador '..' de range se existir)
  if (PeekChar = '.') and (PeekChar(1) in ['0'..'9']) then
  begin
    IsFloat := True;
    Val := Val + ReadChar; // '.'
    while (not IsEOF) and (PeekChar in ['0'..'9', '_']) do
    begin
      C := ReadChar;
      if C <> '_' then
        Val := Val + C;
    end;
  end;

  if IsFloat then
    Result := CreateToken(tokFloatLiteral, Val, StartLine, StartCol)
  else
    Result := CreateToken(tokIntLiteral, Val, StartLine, StartCol);
end;

function TAetherLexer.ScanString: TToken;
var
  StartLine, StartCol: Integer;
  Val: string;
  C: Char;
begin
  StartLine := FLine;
  StartCol := FCol;
  Val := '';

  ReadChar; // Consome aspas duplas iniciais '"'

  while not IsEOF do
  begin
    C := PeekChar;
    if C = '"' then
    begin
      ReadChar; // Consome aspas duplas finais
      Result := CreateToken(tokStringLiteral, Val, StartLine, StartCol);
      Exit;
    end
    else if C = '\' then
    begin
      ReadChar; // Consome '\'
      case PeekChar of
        'n': begin ReadChar; Val := Val + #10; end;
        'r': begin ReadChar; Val := Val + #13; end;
        't': begin ReadChar; Val := Val + #9; end;
        '"': begin ReadChar; Val := Val + '"'; end;
        '\': begin ReadChar; Val := Val + '\'; end;
      else
        Val := Val + ReadChar;
      end;
    end
    else if C in [#10, #13] then
    begin
      raise EAetherLexerError.Create('String nao finalizada antes da quebra de linha', StartLine, StartCol);
    end
    else
    begin
      Val := Val + ReadChar;
    end;
  end;

  raise EAetherLexerError.Create('Fim de arquivo inesperado dentro de String literal', StartLine, StartCol);
end;

function TAetherLexer.ScanCharLiteral: TToken;
var
  StartLine, StartCol: Integer;
  CharVal: Char;
begin
  StartLine := FLine;
  StartCol := FCol;

  ReadChar; // Consome aspas simples iniciais "'"

  if IsEOF then
    raise EAetherLexerError.Create('Caractere literal nao finalizado', StartLine, StartCol);

  if PeekChar = '\' then
  begin
    ReadChar; // Consome '\'
    case PeekChar of
      'n': begin ReadChar; CharVal := #10; end;
      'r': begin ReadChar; CharVal := #13; end;
      't': begin ReadChar; CharVal := #9; end;
      '''': begin ReadChar; CharVal := ''''; end;
      '\': begin ReadChar; CharVal := '\'; end;
    else
      CharVal := ReadChar;
    end;
  end
  else
  begin
    CharVal := ReadChar;
  end;

  if PeekChar <> '''' then
    raise EAetherLexerError.Create('Esperado fechamento de aspas simples para Char', StartLine, StartCol);

  ReadChar; // Consome aspas simples finais

  Result := CreateToken(tokCharLiteral, CharVal, StartLine, StartCol);
end;

function TAetherLexer.NextToken: TToken;
var
  StartLine, StartCol: Integer;
  C: Char;
begin
  SkipWhitespaceAndComments;

  if IsEOF then
  begin
    Result := CreateToken(tokEOF, '', FLine, FCol);
    Exit;
  end;

  StartLine := FLine;
  StartCol := FCol;
  C := PeekChar;

  // Letra ou _ -> Identificador ou Palavra-chave
  if C in ['a'..'z', 'A'..'Z'] then
  begin
    Result := ScanIdentifierOrKeyword;
    Exit;
  end;

  // Sublinhado: pode ser identificador ou tokUnderscore
  if C = '_' then
  begin
    if PeekChar(1) in ['a'..'z', 'A'..'Z', '0'..'9', '_'] then
    begin
      Result := ScanIdentifierOrKeyword;
      Exit;
    end
    else
    begin
      ReadChar;
      Result := CreateToken(tokUnderscore, '_', StartLine, StartCol);
      Exit;
    end;
  end;

  // Digito -> Numero
  if (C in ['0'..'9']) or ((C in ['$', '%']) and (PeekChar(1) in ['0'..'9', 'a'..'f', 'A'..'F'])) then
  begin
    Result := ScanNumber;
    Exit;
  end;

  // String
  if C = '"' then
  begin
    Result := ScanString;
    Exit;
  end;

  // Char
  if C = '''' then
  begin
    Result := ScanCharLiteral;
    Exit;
  end;

  // Operadores e Pontuacao
  case C of
    ':':
      begin
        ReadChar;
        if PeekChar = '=' then
        begin
          ReadChar;
          Result := CreateToken(tokAssign, ':=', StartLine, StartCol);
        end
        else
          Result := CreateToken(tokColon, ':', StartLine, StartCol);
      end;
    ';':
      begin
        ReadChar;
        Result := CreateToken(tokSemicolon, ';', StartLine, StartCol);
      end;
    ',':
      begin
        ReadChar;
        Result := CreateToken(tokComma, ',', StartLine, StartCol);
      end;
    '.':
      begin
        ReadChar;
        Result := CreateToken(tokDot, '.', StartLine, StartCol);
      end;
    '=':
      begin
        ReadChar;
        Result := CreateToken(tokEqual, '=', StartLine, StartCol);
      end;
    '<':
      begin
        ReadChar;
        if PeekChar = '>' then
        begin
          ReadChar;
          Result := CreateToken(tokNotEqual, '<>', StartLine, StartCol);
        end
        else if PeekChar = '=' then
        begin
          ReadChar;
          Result := CreateToken(tokLessEqual, '<=', StartLine, StartCol);
        end
        else
          Result := CreateToken(tokLess, '<', StartLine, StartCol);
      end;
    '>':
      begin
        ReadChar;
        if PeekChar = '=' then
        begin
          ReadChar;
          Result := CreateToken(tokGreaterEqual, '>=', StartLine, StartCol);
        end
        else
          Result := CreateToken(tokGreater, '>', StartLine, StartCol);
      end;
    '+':
      begin
        ReadChar;
        Result := CreateToken(tokPlus, '+', StartLine, StartCol);
      end;
    '-':
      begin
        ReadChar;
        Result := CreateToken(tokMinus, '-', StartLine, StartCol);
      end;
    '*':
      begin
        ReadChar;
        Result := CreateToken(tokStar, '*', StartLine, StartCol);
      end;
    '/':
      begin
        ReadChar;
        Result := CreateToken(tokSlash, '/', StartLine, StartCol);
      end;
    '(':
      begin
        ReadChar;
        Result := CreateToken(tokLParen, '(', StartLine, StartCol);
      end;
    ')':
      begin
        ReadChar;
        Result := CreateToken(tokRParen, ')', StartLine, StartCol);
      end;
    '[':
      begin
        ReadChar;
        Result := CreateToken(tokLBracket, '[', StartLine, StartCol);
      end;
    ']':
      begin
        ReadChar;
        Result := CreateToken(tokRBracket, ']', StartLine, StartCol);
      end;
  else
    ReadChar;
    Result := CreateToken(tokUnknown, C, StartLine, StartCol);
  end;
end;

end.
