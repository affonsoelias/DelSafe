unit uAetherJSONDiag;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

function EscapeJSONString(const S: string): string;
function GenerateJSONDiagnostic(const AFile, ASeverity, ACode, AMessage: string;
  Line, Col: Integer; MovedLine: Integer = 0; MovedCol: Integer = 0;
  const FixStrategy: string = ''; const FixDesc: string = ''; const FixReplacement: string = ''): string;

implementation

function EscapeJSONString(const S: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    case C of
      '"': Result := Result + '\"';
      '\': Result := Result + '\\';
      #10: Result := Result + '\n';
      #13: Result := Result + '\r';
      #9:  Result := Result + '\t';
    else
      Result := Result + C;
    end;
  end;
end;

function GenerateJSONDiagnostic(const AFile, ASeverity, ACode, AMessage: string;
  Line, Col: Integer; MovedLine: Integer; MovedCol: Integer;
  const FixStrategy: string; const FixDesc: string; const FixReplacement: string): string;
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('{');
    Lines.Add('  "schema_version": "1.0",');
    Lines.Add('  "diagnostics": [');
    Lines.Add('    {');
    Lines.Add(Format('      "severity": "%s",', [EscapeJSONString(ASeverity)]));
    Lines.Add(Format('      "code": "%s",', [EscapeJSONString(ACode)]));
    Lines.Add(Format('      "file": "%s",', [EscapeJSONString(AFile)]));
    Lines.Add('      "range": {');
    Lines.Add(Format('        "start": { "line": %d, "col": %d },', [Line, Col]));
    Lines.Add(Format('        "end": { "line": %d, "col": %d }', [Line, Col + 5]));
    Lines.Add('      },');
    Lines.Add(Format('      "message": "%s"', [EscapeJSONString(AMessage)]));

    if MovedLine > 0 then
    begin
      Lines[Lines.Count - 1] := Lines[Lines.Count - 1] + ',';
      Lines.Add('      "context": {');
      Lines.Add(Format('        "moved_at": { "line": %d, "col": %d, "note": "Value previously moved via \"take\"" }', [MovedLine, MovedCol]));
      Lines.Add('      }');
    end;

    if FixStrategy <> '' then
    begin
      Lines[Lines.Count - 1] := Lines[Lines.Count - 1] + ',';
      Lines.Add('      "suggested_fix": {');
      Lines.Add(Format('        "strategy": "%s",', [EscapeJSONString(FixStrategy)]));
      Lines.Add(Format('        "description": "%s",', [EscapeJSONString(FixDesc)]));
      Lines.Add(Format('        "replacement": "%s"', [EscapeJSONString(FixReplacement)]));
      Lines.Add('      }');
    end;

    Lines.Add('    }');
    Lines.Add('  ]');
    Lines.Add('}');
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

end.
