unit AuxiliarPascal;

{$mode objfpc}{$H+}

interface

function TriploPascal(x: LongInt): LongInt;

implementation

function TriploPascal(x: LongInt): LongInt;
begin
  Result := x * 3;
end;

end.
