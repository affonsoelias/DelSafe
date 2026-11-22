unit uAetherCfg;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  SysUtils, Classes, uAetherAST;

function GetCurrentOSName: string;
function EvaluateCfgCondition(const CondStr, TargetOS, TargetBackend: string; IsRelease: Boolean): Boolean;
procedure ApplyCfgToModule(AModule: TASTModule; const TargetOS, TargetBackend: string; IsRelease: Boolean);

implementation

function GetCurrentOSName: string;
begin
  {$IFDEF WINDOWS}
  Result := 'windows';
  {$ELSE}
    {$IFDEF DARWIN}
    Result := 'darwin';
    {$ELSE}
    Result := 'linux';
    {$ENDIF}
  {$ENDIF}
end;

function EvaluateCfgCondition(const CondStr, TargetOS, TargetBackend: string; IsRelease: Boolean): Boolean;
var
  CleanCond, Key, Val: string;
  PosEq: Integer;
  IsNegated: Boolean;
begin
  Result := True;
  CleanCond := Trim(CondStr);
  if CleanCond = '' then Exit(True);

  IsNegated := False;
  if (Copy(CleanCond, 1, 4) = 'not(') and (CleanCond[Length(CleanCond)] = ')') then
  begin
    IsNegated := True;
    CleanCond := Trim(Copy(CleanCond, 5, Length(CleanCond) - 5));
  end
  else if (Copy(CleanCond, 1, 4) = 'not ') then
  begin
    IsNegated := True;
    CleanCond := Trim(Copy(CleanCond, 5, Length(CleanCond) - 4));
  end;

  if SameText(CleanCond, 'debug') then
    Result := not IsRelease
  else if SameText(CleanCond, 'release') then
    Result := IsRelease
  else if SameText(CleanCond, 'windows') then
    Result := (LowerCase(TargetOS) = 'windows')
  else if SameText(CleanCond, 'linux') then
    Result := (LowerCase(TargetOS) = 'linux')
  else if SameText(CleanCond, 'darwin') or SameText(CleanCond, 'macos') then
    Result := (LowerCase(TargetOS) = 'darwin')
  else
  begin
    PosEq := Pos('=', CleanCond);
    if PosEq > 0 then
    begin
      Key := LowerCase(Trim(Copy(CleanCond, 1, PosEq - 1)));
      Val := Trim(Copy(CleanCond, PosEq + 1, Length(CleanCond)));
      if (Length(Val) >= 2) and (((Val[1] = '"') and (Val[Length(Val)] = '"')) or ((Val[1] = '''') and (Val[Length(Val)] = ''''))) then
        Val := Copy(Val, 2, Length(Val) - 2);
      Val := LowerCase(Trim(Val));

      if (Key = 'target_os') or (Key = 'os') then
        Result := (Val = LowerCase(TargetOS))
      else if (Key = 'target') or (Key = 'backend') then
        Result := (Val = LowerCase(TargetBackend))
      else
        Result := True;
    end
    else
      Result := True;
  end;

  if IsNegated then
    Result := not Result;
end;

procedure ApplyCfgToModule(AModule: TASTModule; const TargetOS, TargetBackend: string; IsRelease: Boolean);
var
  I: Integer;
  Func: TASTFunction;
  TypeNode: TASTNode;
  RecDecl: TASTRecordDecl;
  EnumDecl: TASTEnumDecl;
begin
  if not Assigned(AModule) then Exit;

  // 1. Filtra funcoes
  I := AModule.Functions.Count - 1;
  while I >= 0 do
  begin
    Func := TASTFunction(AModule.Functions[I]);
    if (Func.CfgCondition <> '') and not EvaluateCfgCondition(Func.CfgCondition, TargetOS, TargetBackend, IsRelease) then
    begin
      AModule.Functions.Delete(I);
    end;
    Dec(I);
  end;

  // 2. Filtra tipos
  I := AModule.Types.Count - 1;
  while I >= 0 do
  begin
    TypeNode := AModule.Types[I];
    if TypeNode is TASTRecordDecl then
    begin
      RecDecl := TASTRecordDecl(TypeNode);
      if (RecDecl.CfgCondition <> '') and not EvaluateCfgCondition(RecDecl.CfgCondition, TargetOS, TargetBackend, IsRelease) then
        AModule.Types.Delete(I);
    end
    else if TypeNode is TASTEnumDecl then
    begin
      EnumDecl := TASTEnumDecl(TypeNode);
      if (EnumDecl.CfgCondition <> '') and not EvaluateCfgCondition(EnumDecl.CfgCondition, TargetOS, TargetBackend, IsRelease) then
        AModule.Types.Delete(I);
    end;
    Dec(I);
  end;
end;

end.
