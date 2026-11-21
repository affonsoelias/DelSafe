unit uAetherTokens;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TTokenKind = (
    // Controle e Especiais
    tokEOF,
    tokUnknown,

    // Identificadores e Literais
    tokIdentifier,
    tokIntLiteral,
    tokFloatLiteral,
    tokStringLiteral,
    tokCharLiteral,

    // Palavras-chave: Estrutura
    tokModule,
    tokProgram,
    tokImport,
    tokAs,

    // Palavras-chave: Tipos
    tokType,
    tokRecord,
    tokEnum,

    // Palavras-chave: Funções e Contratos
    tokFunction,
    tokContract,
    tokRequire,
    tokEnsure,

    // Palavras-chave: Variáveis
    tokVar,
    tokLet,

    // Palavras-chave: Blocos e Fluxo
    tokBegin,
    tokEnd,
    tokIf,
    tokThen,
    tokElse,
    tokWhile,
    tokDo,
    tokFor,
    tokIn,
    tokMatch,
    tokCase,
    tokReturn,

    // Palavras-chave: Posse e Empréstimo (Ownership)
    tokTake,
    tokBorrow,
    tokMut,

    // Palavras-chave: Lógica e Valores
    tokAnd,
    tokOr,
    tokNot,
    tokImplies,
    tokTrue,
    tokFalse,
    tokMod,

    // Pontuação e Operadores
    tokColon,          // :
    tokSemicolon,      // ;
    tokComma,          // ,
    tokDot,            // .
    tokAssign,         // :=
    tokEqual,          // =
    tokNotEqual,       // <>
    tokLess,           // <
    tokLessEqual,      // <=
    tokGreater,        // >
    tokGreaterEqual,   // >=
    tokPlus,           // +
    tokMinus,          // -
    tokStar,           // *
    tokSlash,          // /
    tokLParen,         // (
    tokRParen,         // )
    tokLBracket,       // [
    tokRBracket,       // ]
    tokUnderscore      // _
  );

  TToken = record
    Kind: TTokenKind;
    Value: string;
    Line: Integer;
    Col: Integer;
  end;

function TokenKindToString(Kind: TTokenKind): string;
function LookupKeyword(const S: string): TTokenKind;
function CreateToken(Kind: TTokenKind; const Value: string; Line, Col: Integer): TToken;

implementation

function TokenKindToString(Kind: TTokenKind): string;
begin
  case Kind of
    tokEOF:           Result := 'EOF';
    tokUnknown:       Result := 'Unknown';
    tokIdentifier:    Result := 'Identifier';
    tokIntLiteral:    Result := 'IntLiteral';
    tokFloatLiteral:  Result := 'FloatLiteral';
    tokStringLiteral: Result := 'StringLiteral';
    tokCharLiteral:   Result := 'CharLiteral';

    tokModule:        Result := 'module';
    tokProgram:       Result := 'program';
    tokImport:        Result := 'import';
    tokAs:            Result := 'as';
    tokType:          Result := 'type';
    tokRecord:        Result := 'record';
    tokEnum:          Result := 'enum';
    tokFunction:      Result := 'function';
    tokContract:      Result := 'contract';
    tokRequire:       Result := 'require';
    tokEnsure:        Result := 'ensure';
    tokVar:           Result := 'var';
    tokLet:           Result := 'let';
    tokBegin:         Result := 'begin';
    tokEnd:           Result := 'end';
    tokIf:            Result := 'if';
    tokThen:          Result := 'then';
    tokElse:          Result := 'else';
    tokWhile:         Result := 'while';
    tokDo:            Result := 'do';
    tokFor:           Result := 'for';
    tokIn:            Result := 'in';
    tokMatch:         Result := 'match';
    tokCase:          Result := 'case';
    tokReturn:        Result := 'return';
    tokTake:          Result := 'take';
    tokBorrow:        Result := 'borrow';
    tokMut:           Result := 'mut';
    tokAnd:           Result := 'and';
    tokOr:            Result := 'or';
    tokNot:           Result := 'not';
    tokImplies:       Result := 'implies';
    tokTrue:          Result := 'true';
    tokFalse:         Result := 'false';
    tokMod:           Result := 'mod';

    tokColon:         Result := ':';
    tokSemicolon:     Result := ';';
    tokComma:         Result := ',';
    tokDot:           Result := '.';
    tokAssign:        Result := ':=';
    tokEqual:         Result := '=';
    tokNotEqual:      Result := '<>';
    tokLess:          Result := '<';
    tokLessEqual:     Result := '<=';
    tokGreater:       Result := '>';
    tokGreaterEqual:  Result := '>=';
    tokPlus:          Result := '+';
    tokMinus:         Result := '-';
    tokStar:          Result := '*';
    tokSlash:         Result := '/';
    tokLParen:        Result := '(';
    tokRParen:        Result := ')';
    tokLBracket:      Result := '[';
    tokRBracket:      Result := ']';
    tokUnderscore:    Result := '_';
  else
    Result := 'Desconhecido';
  end;
end;

function LookupKeyword(const S: string): TTokenKind;
var
  Lower: string;
begin
  Lower := LowerCase(S);
  if Lower = 'module' then Result := tokModule
  else if Lower = 'program' then Result := tokProgram
  else if Lower = 'import' then Result := tokImport
  else if Lower = 'as' then Result := tokAs
  else if Lower = 'type' then Result := tokType
  else if Lower = 'record' then Result := tokRecord
  else if Lower = 'enum' then Result := tokEnum
  else if Lower = 'function' then Result := tokFunction
  else if Lower = 'contract' then Result := tokContract
  else if Lower = 'require' then Result := tokRequire
  else if Lower = 'ensure' then Result := tokEnsure
  else if Lower = 'var' then Result := tokVar
  else if Lower = 'let' then Result := tokLet
  else if Lower = 'begin' then Result := tokBegin
  else if Lower = 'end' then Result := tokEnd
  else if Lower = 'if' then Result := tokIf
  else if Lower = 'then' then Result := tokThen
  else if Lower = 'else' then Result := tokElse
  else if Lower = 'while' then Result := tokWhile
  else if Lower = 'do' then Result := tokDo
  else if Lower = 'for' then Result := tokFor
  else if Lower = 'in' then Result := tokIn
  else if Lower = 'match' then Result := tokMatch
  else if Lower = 'case' then Result := tokCase
  else if Lower = 'return' then Result := tokReturn
  else if Lower = 'take' then Result := tokTake
  else if Lower = 'borrow' then Result := tokBorrow
  else if Lower = 'mut' then Result := tokMut
  else if Lower = 'and' then Result := tokAnd
  else if Lower = 'or' then Result := tokOr
  else if Lower = 'not' then Result := tokNot
  else if Lower = 'implies' then Result := tokImplies
  else if Lower = 'true' then Result := tokTrue
  else if Lower = 'false' then Result := tokFalse
  else if Lower = 'mod' then Result := tokMod
  else Result := tokIdentifier;
end;

function CreateToken(Kind: TTokenKind; const Value: string; Line, Col: Integer): TToken;
begin
  Result.Kind := Kind;
  Result.Value := Value;
  Result.Line := Line;
  Result.Col := Col;
end;

end.
