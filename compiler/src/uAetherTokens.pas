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
    tokInterpStringLiteral,
    tokCharLiteral,

    // Palavras-chave: Estrutura
    tokModule,
    tokProgram,
    tokImport,
    tokAs,
    tokExtern,
    tokExport,
    tokCdecl,
    tokPascal,

    // Palavras-chave: Tipos e Contratos de Tipos (Traits)
    tokType,
    tokRecord,
    tokEnum,
    tokTrait,
    tokImpl,
    tokArray,
    tokOf,
    tokSet,
    tokMap,

    // Palavras-chave: Concorrencia e Async
    tokAsync,
    tokAwait,
    tokSpawn,
    tokYield,

    // Palavras-chave: Funções e Contratos
    tokFunction,
    tokContract,
    tokRequire,
    tokEnsure,

    // Palavras-chave: Constantes e Variaveis
    tokConst,
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
    tokTo,
    tokDownto,
    tokRepeat,
    tokUntil,
    tokBreak,
    tokContinue,
    tokMatch,
    tokWith,
    tokCase,
    tokReturn,
    tokAsm,
    tokDefer,
    tokTry,
    tokExcept,
    tokRaise,
    tokUnsafe,

    // Palavras-chave: Posse e Empréstimo (Ownership)
    tokTake,
    tokBorrow,
    tokMut,

    // Palavras-chave: Lógica, Bitwise e Valores
    tokAnd,
    tokOr,
    tokNot,
    tokXor,
    tokShl,
    tokShr,
    tokImplies,
    tokTrue,
    tokFalse,
    tokNil,
    tokMod,
    tokDiv,

    // Pontuação e Operadores
    tokColon,          // :
    tokSemicolon,      // ;
    tokComma,          // ,
    tokDot,            // .
    tokDotDot,         // ..
    tokAssign,         // :=
    tokPlusAssign,     // +=
    tokMinusAssign,    // -=
    tokStarAssign,     // *=
    tokSlashAssign,    // /=
    tokModAssign,      // mod= / %=
    tokBitAndAssign,   // &=
    tokBitOrAssign,    // |=
    tokBitXorAssign,   // ^=
    tokShlAssign,      // <<=
    tokShrAssign,      // >>=
    tokEqual,          // =
    tokFatArrow,       // =>
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
    tokUnderscore,     // _
    tokAt,             // @
    tokCaret,          // ^
    tokQuestion        // ?
  );

  TToken = record
    Kind: TTokenKind;
    Value: string;
    Line: Integer;
    Col: Integer;
    DocComment: string;
  end;

function TokenKindToString(Kind: TTokenKind): string;
function LookupKeyword(const S: string): TTokenKind;
function CreateToken(Kind: TTokenKind; const Value: string; Line, Col: Integer; const ADocComment: string = ''): TToken;

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
    tokInterpStringLiteral: Result := 'InterpStringLiteral';
    tokCharLiteral:   Result := 'CharLiteral';

    tokModule:        Result := 'module';
    tokProgram:       Result := 'program';
    tokImport:        Result := 'import';
    tokAs:            Result := 'as';
    tokExtern:        Result := 'extern';
    tokExport:        Result := 'export';
    tokCdecl:         Result := 'cdecl';
    tokPascal:        Result := 'pascal';
    tokType:          Result := 'type';
    tokRecord:        Result := 'record';
    tokEnum:          Result := 'enum';
    tokTrait:         Result := 'trait';
    tokImpl:          Result := 'impl';
    tokArray:         Result := 'array';
    tokOf:            Result := 'of';
    tokSet:           Result := 'set';
    tokMap:           Result := 'map';
    tokFunction:      Result := 'function';
    tokContract:      Result := 'contract';
    tokRequire:       Result := 'require';
    tokEnsure:        Result := 'ensure';
    tokConst:         Result := 'const';
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
    tokTo:            Result := 'to';
    tokDownto:        Result := 'downto';
    tokRepeat:        Result := 'repeat';
    tokUntil:         Result := 'until';
    tokBreak:         Result := 'break';
    tokContinue:      Result := 'continue';
    tokMatch:         Result := 'match';
    tokWith:          Result := 'with';
    tokCase:          Result := 'case';
    tokReturn:        Result := 'return';
    tokAsm:           Result := 'asm';
    tokDefer:         Result := 'defer';
    tokTry:           Result := 'try';
    tokExcept:        Result := 'except';
    tokRaise:         Result := 'raise';
    tokUnsafe:        Result := 'unsafe';
    tokAsync:         Result := 'async';
    tokAwait:         Result := 'await';
    tokSpawn:         Result := 'spawn';
    tokYield:         Result := 'yield';
    tokTake:          Result := 'take';
    tokBorrow:        Result := 'borrow';
    tokMut:           Result := 'mut';
    tokAnd:           Result := 'and';
    tokOr:            Result := 'or';
    tokNot:           Result := 'not';
    tokXor:           Result := 'xor';
    tokShl:           Result := 'shl';
    tokShr:           Result := 'shr';
    tokImplies:       Result := 'implies';
    tokTrue:          Result := 'true';
    tokFalse:         Result := 'false';
    tokNil:           Result := 'nil';
    tokMod:           Result := 'mod';
    tokDiv:           Result := 'div';

    tokColon:         Result := ':';
    tokSemicolon:     Result := ';';
    tokComma:         Result := ',';
    tokDot:           Result := '.';
    tokDotDot:        Result := '..';
    tokAssign:        Result := ':=';
    tokPlusAssign:    Result := '+=';
    tokMinusAssign:   Result := '-=';
    tokStarAssign:    Result := '*=';
    tokSlashAssign:   Result := '/=';
    tokModAssign:     Result := 'mod=';
    tokBitAndAssign:  Result := '&=';
    tokBitOrAssign:   Result := '|=';
    tokBitXorAssign:  Result := '^=';
    tokShlAssign:     Result := '<<=';
    tokShrAssign:     Result := '>>=';
    tokEqual:         Result := '=';
    tokFatArrow:      Result := '=>';
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
    tokAt:            Result := '@';
    tokCaret:         Result := '^';
    tokQuestion:      Result := '?';
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
  else if Lower = 'extern' then Result := tokExtern
  else if Lower = 'export' then Result := tokExport
  else if Lower = 'cdecl' then Result := tokCdecl
  else if Lower = 'pascal' then Result := tokPascal
  else if Lower = 'type' then Result := tokType
  else if Lower = 'record' then Result := tokRecord
  else if Lower = 'enum' then Result := tokEnum
  else if Lower = 'trait' then Result := tokTrait
  else if Lower = 'impl' then Result := tokImpl
  else if Lower = 'array' then Result := tokArray
  else if Lower = 'of' then Result := tokOf
  else if Lower = 'set' then Result := tokSet
  else if Lower = 'map' then Result := tokMap
  else if Lower = 'function' then Result := tokFunction
  else if Lower = 'contract' then Result := tokContract
  else if Lower = 'require' then Result := tokRequire
  else if Lower = 'ensure' then Result := tokEnsure
  else if Lower = 'const' then Result := tokConst
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
  else if Lower = 'to' then Result := tokTo
  else if Lower = 'downto' then Result := tokDownto
  else if Lower = 'repeat' then Result := tokRepeat
  else if Lower = 'until' then Result := tokUntil
  else if Lower = 'break' then Result := tokBreak
  else if Lower = 'continue' then Result := tokContinue
  else if Lower = 'match' then Result := tokMatch
  else if Lower = 'with' then Result := tokWith
  else if Lower = 'case' then Result := tokCase
  else if Lower = 'return' then Result := tokReturn
  else if Lower = 'asm' then Result := tokAsm
  else if Lower = 'defer' then Result := tokDefer
  else if Lower = 'try' then Result := tokTry
  else if Lower = 'except' then Result := tokExcept
  else if Lower = 'raise' then Result := tokRaise
  else if Lower = 'unsafe' then Result := tokUnsafe
  else if Lower = 'async' then Result := tokAsync
  else if Lower = 'await' then Result := tokAwait
  else if Lower = 'spawn' then Result := tokSpawn
  else if Lower = 'yield' then Result := tokYield
  else if Lower = 'take' then Result := tokTake
  else if Lower = 'borrow' then Result := tokBorrow
  else if Lower = 'mut' then Result := tokMut
  else if Lower = 'and' then Result := tokAnd
  else if Lower = 'or' then Result := tokOr
  else if Lower = 'not' then Result := tokNot
  else if Lower = 'xor' then Result := tokXor
  else if Lower = 'shl' then Result := tokShl
  else if Lower = 'shr' then Result := tokShr
  else if Lower = 'implies' then Result := tokImplies
  else if Lower = 'true' then Result := tokTrue
  else if Lower = 'false' then Result := tokFalse
  else if Lower = 'nil' then Result := tokNil
  else if Lower = 'mod' then Result := tokMod
  else if Lower = 'div' then Result := tokDiv
  else Result := tokIdentifier;
end;

function CreateToken(Kind: TTokenKind; const Value: string; Line, Col: Integer; const ADocComment: string = ''): TToken;
begin
  Result.Kind := Kind;
  Result.Value := Value;
  Result.Line := Line;
  Result.Col := Col;
  Result.DocComment := ADocComment;
end;

end.
