unit uAetherLexer;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, uAetherTokens;

type
  TLexerState = record
    Pos: Integer;
    Line: Integer;
    Col: Integer;
    LastTokenKind: TTokenKind;
    CurrentDocComment: string;
  end;

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
    FCurrentDocComment: string;
    FLastTokenKind: TTokenKind;

    function PeekChar(Offset: Integer = 0): Char;
    function ReadChar: Char;
    function IsEOF: Boolean;
    procedure SkipWhitespaceAndComments;

    function ScanTokenInternal: TToken;
    function ScanIdentifierOrKeyword: TToken;
    function ScanAsmBlock: string;
    function ScanNumber: TToken;
    function ScanString: TToken;
    function ScanCharLiteral: TToken;
  public
    constructor Create(const ASource: string);
    function NextToken: TToken;
    function ConsumeDocComment: string;
    function SaveState: TLexerState;
    procedure RestoreState(const AState: TLexerState);
    property Line: Integer read FLine;
    property Col: Integer read FCol;
  end;

implementation

constructor EAetherLexerError.Create(const Msg: string; ALine, ACol: Integer);
begin
  inherited Create(Format('[Lexical Error at %d:%d]: %s', [ALine, ACol, Msg]));
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
  FCurrentDocComment := '';
  FLastTokenKind := tokEOF;
end;

function TAetherLexer.ConsumeDocComment: string;
begin
  Result := FCurrentDocComment;
  FCurrentDocComment := '';
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
  DocLine: string;
begin
  while not IsEOF do
  begin
    C := PeekChar;

    // Whitespace, tabs, and newlines
    if C in [' ', #9, #10, #13] then
    begin
      ReadChar;
      Continue;
    end;

    // Documentation comment /// (three slashes, not four)
    if (C = '/') and (PeekChar(1) = '/') and (PeekChar(2) = '/') and (PeekChar(3) <> '/') then
    begin
      ReadChar; // Consume first /
      ReadChar; // Consume second /
      ReadChar; // Consume third /
      if (not IsEOF) and (PeekChar = ' ') then
        ReadChar; // Consume optional space after ///
      DocLine := '';
      while (not IsEOF) and (PeekChar <> #10) and (PeekChar <> #13) do
        DocLine := DocLine + ReadChar;
      if FCurrentDocComment <> '' then
        FCurrentDocComment := FCurrentDocComment + LineEnding + DocLine
      else
        FCurrentDocComment := DocLine;
      Continue;
    end;

    // Line comment //
    if (C = '/') and (PeekChar(1) = '/') then
    begin
      ReadChar; // Consume first /
      ReadChar; // Consume second /
      while (not IsEOF) and (PeekChar <> #10) do
        ReadChar;
      Continue;
    end;

    // Pascal block comment { ... }
    if C = '{' then
    begin
      ReadChar; // Consume {
      while (not IsEOF) and (PeekChar <> '}') do
        ReadChar;
      if not IsEOF then
        ReadChar; // Consume }
      Continue;
    end;

    // C-style block comment /* ... */
    if (C = '/') and (PeekChar(1) = '*') then
    begin
      ReadChar; // Consume /
      ReadChar; // Consume *
      while not IsEOF do
      begin
        if (PeekChar = '*') and (PeekChar(1) = '/') then
        begin
          ReadChar; // Consume *
          ReadChar; // Consume /
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
  if (Kind = tokMod) and (PeekChar = '=') then
  begin
    ReadChar;
    Result := CreateToken(tokModAssign, 'mod=', StartLine, StartCol);
    Exit;
  end;
  if (Kind = tokAsm) and (FLastTokenKind <> tokEnd) then
  begin
    Val := ScanAsmBlock;
    Result := CreateToken(tokAsm, Val, StartLine, StartCol);
    Exit;
  end;
  Result := CreateToken(Kind, Val, StartLine, StartCol);
end;

function TAetherLexer.ScanAsmBlock: string;
var
  Buffer: string;
  SavedPos, SavedLine, SavedCol: Integer;
  WordBuf: string;
begin
  Buffer := '';
  while not IsEOF do
  begin
    if PeekChar in ['e', 'E'] then
    begin
      SavedPos := FPos;
      SavedLine := FLine;
      SavedCol := FCol;
      WordBuf := '';
      while (not IsEOF) and (PeekChar in ['a'..'z', 'A'..'Z', '0'..'9', '_']) do
        WordBuf := WordBuf + ReadChar;

      if LowerCase(WordBuf) = 'end' then
      begin
        FPos := SavedPos;
        FLine := SavedLine;
        FCol := SavedCol;
        Break;
      end
      else
        Buffer := Buffer + WordBuf;
    end
    else
      Buffer := Buffer + ReadChar;
  end;
  Result := Trim(Buffer);
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

  // Hexadecimal literal ($FF or 0x style)
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

  // Binary literal (%1010 or 0b style)
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

  // Decimal or Float
  while (not IsEOF) and (PeekChar in ['0'..'9', '_']) do
  begin
    C := ReadChar;
    if C <> '_' then
      Val := Val + C;
  end;

  // Floating-point (be careful with '..' range operator if present)
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

  ReadChar; // Consume opening double quote '"'

  while not IsEOF do
  begin
    C := PeekChar;
    if C = '"' then
    begin
      ReadChar; // Consume closing double quote
      Result := CreateToken(tokStringLiteral, Val, StartLine, StartCol);
      Exit;
    end
    else if C = '\' then
    begin
      ReadChar; // Consume '\'
      case PeekChar of
        'n': begin ReadChar; Val := Val + #10; end;
        'r': begin ReadChar; Val := Val + #13; end;
        't': begin ReadChar; Val := Val + #9; end;
        '0': begin ReadChar; Val := Val + #0; end;
        '"': begin ReadChar; Val := Val + '"'; end;
        '''': begin ReadChar; Val := Val + ''''; end;
        '\': begin ReadChar; Val := Val + '\'; end;
      else
        Val := Val + ReadChar;
      end;
    end
    else if C in [#10, #13] then
    begin
      raise EAetherLexerError.Create('Unterminated string before newline', StartLine, StartCol);
    end
    else
    begin
      Val := Val + ReadChar;
    end;
  end;

  raise EAetherLexerError.Create('Unexpected end of file inside string literal', StartLine, StartCol);
end;

function TAetherLexer.ScanCharLiteral: TToken;
var
  StartLine, StartCol: Integer;
  CharVal: Char;
begin
  StartLine := FLine;
  StartCol := FCol;

  ReadChar; // Consume opening single quote "'"

  if IsEOF then
    raise EAetherLexerError.Create('Unterminated character literal', StartLine, StartCol);

  if PeekChar = '\' then
  begin
    ReadChar; // Consume '\'
    case PeekChar of
      'n': begin ReadChar; CharVal := #10; end;
      'r': begin ReadChar; CharVal := #13; end;
      't': begin ReadChar; CharVal := #9; end;
      '0': begin ReadChar; CharVal := #0; end;
      '"': begin ReadChar; CharVal := '"'; end;
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
    raise EAetherLexerError.Create('Expected closing single quote for Char literal', StartLine, StartCol);

  ReadChar; // Consume closing single quote

  Result := CreateToken(tokCharLiteral, CharVal, StartLine, StartCol);
end;

function TAetherLexer.ScanTokenInternal: TToken;
var
  StartLine, StartCol: Integer;
  C: Char;
begin
  if IsEOF then
  begin
    Result := CreateToken(tokEOF, '', FLine, FCol);
    Exit;
  end;

  StartLine := FLine;
  StartCol := FCol;
  C := PeekChar;

  // Letter or _ -> Identifier or Keyword
  if C in ['a'..'z', 'A'..'Z'] then
  begin
    Result := ScanIdentifierOrKeyword;
    Exit;
  end;

  // Underscore: can be an identifier or tokUnderscore
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

  // Interpolated string $"..."
  if (C = '$') and (PeekChar(1) = '"') then
  begin
    ReadChar; // Consume '$'
    Result := ScanString;
    Result.Kind := tokInterpStringLiteral;
    Exit;
  end;

  // Digit -> Number
  if (C in ['0'..'9']) or ((C = '$') and (PeekChar(1) in ['0'..'9', 'a'..'f', 'A'..'F'])) or
     ((C = '%') and (PeekChar(1) in ['0', '1'])) then
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

  // Operators and Punctuation
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
        if PeekChar = '.' then
        begin
          ReadChar;
          Result := CreateToken(tokDotDot, '..', StartLine, StartCol);
        end
        else
          Result := CreateToken(tokDot, '.', StartLine, StartCol);
      end;
    '!':
      begin
        ReadChar;
        if PeekChar = '=' then
        begin
          ReadChar;
          Result := CreateToken(tokNotEqual, '!=', StartLine, StartCol);
        end
        else
          Result := CreateToken(tokUnknown, '!', StartLine, StartCol);
      end;
    '=':
      begin
        ReadChar;
        if PeekChar = '>' then
        begin
          ReadChar;
          Result := CreateToken(tokFatArrow, '=>', StartLine, StartCol);
        end
        else
          Result := CreateToken(tokEqual, '=', StartLine, StartCol);
      end;
    '<':
      begin
        ReadChar;
        if PeekChar = '<' then
        begin
          ReadChar;
          if PeekChar = '=' then
          begin
            ReadChar;
            Result := CreateToken(tokShlAssign, '<<=', StartLine, StartCol);
          end
          else
            Result := CreateToken(tokShl, 'shl', StartLine, StartCol);
        end
        else if PeekChar = '>' then
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
        if PeekChar = '>' then
        begin
          ReadChar;
          if PeekChar = '=' then
          begin
            ReadChar;
            Result := CreateToken(tokShrAssign, '>>=', StartLine, StartCol);
          end
          else
            Result := CreateToken(tokShr, 'shr', StartLine, StartCol);
        end
        else if PeekChar = '=' then
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
        if PeekChar = '=' then
        begin
          ReadChar;
          Result := CreateToken(tokPlusAssign, '+=', StartLine, StartCol);
        end
        else
          Result := CreateToken(tokPlus, '+', StartLine, StartCol);
      end;
    '-':
      begin
        ReadChar;
        if PeekChar = '=' then
        begin
          ReadChar;
          Result := CreateToken(tokMinusAssign, '-=', StartLine, StartCol);
        end
        else
          Result := CreateToken(tokMinus, '-', StartLine, StartCol);
      end;
    '*':
      begin
        ReadChar;
        if PeekChar = '=' then
        begin
          ReadChar;
          Result := CreateToken(tokStarAssign, '*=', StartLine, StartCol);
        end
        else
          Result := CreateToken(tokStar, '*', StartLine, StartCol);
      end;
    '/':
      begin
        ReadChar;
        if PeekChar = '=' then
        begin
          ReadChar;
          Result := CreateToken(tokSlashAssign, '/=', StartLine, StartCol);
        end
        else
          Result := CreateToken(tokSlash, '/', StartLine, StartCol);
      end;
    '%':
      begin
        ReadChar;
        if PeekChar = '=' then
        begin
          ReadChar;
          Result := CreateToken(tokModAssign, '%=', StartLine, StartCol);
        end
        else
          Result := CreateToken(tokMod, 'mod', StartLine, StartCol);
      end;
    '&':
      begin
        ReadChar;
        if PeekChar = '=' then
        begin
          ReadChar;
          Result := CreateToken(tokBitAndAssign, '&=', StartLine, StartCol);
        end
        else
          Result := CreateToken(tokAnd, 'and', StartLine, StartCol);
      end;
    '|':
      begin
        ReadChar;
        if PeekChar = '=' then
        begin
          ReadChar;
          Result := CreateToken(tokBitOrAssign, '|=', StartLine, StartCol);
        end
        else
          Result := CreateToken(tokOr, 'or', StartLine, StartCol);
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
    '@':
      begin
        ReadChar;
        Result := CreateToken(tokAt, '@', StartLine, StartCol);
      end;
    '^':
      begin
        ReadChar;
        if PeekChar = '=' then
        begin
          ReadChar;
          Result := CreateToken(tokBitXorAssign, '^=', StartLine, StartCol);
        end
        else
          Result := CreateToken(tokCaret, '^', StartLine, StartCol);
      end;
    '?':
      begin
        ReadChar;
        Result := CreateToken(tokQuestion, '?', StartLine, StartCol);
      end;
  else
    ReadChar;
    Result := CreateToken(tokUnknown, C, StartLine, StartCol);
  end;
end;

function TAetherLexer.SaveState: TLexerState;
begin
  Result.Pos := FPos;
  Result.Line := FLine;
  Result.Col := FCol;
  Result.LastTokenKind := FLastTokenKind;
  Result.CurrentDocComment := FCurrentDocComment;
end;

procedure TAetherLexer.RestoreState(const AState: TLexerState);
begin
  FPos := AState.Pos;
  FLine := AState.Line;
  FCol := AState.Col;
  FLastTokenKind := AState.LastTokenKind;
  FCurrentDocComment := AState.CurrentDocComment;
end;

function TAetherLexer.NextToken: TToken;
var
  SavedDoc: string;
begin
  SkipWhitespaceAndComments;
  SavedDoc := FCurrentDocComment;
  FCurrentDocComment := '';

  Result := ScanTokenInternal;
  Result.DocComment := SavedDoc;
  FLastTokenKind := Result.Kind;
end;

end.
