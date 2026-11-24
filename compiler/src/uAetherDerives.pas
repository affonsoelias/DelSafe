unit uAetherDerives;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, uAetherAST, uAetherTokens;

procedure ExpandDerives(AModule: TASTModule);

implementation

function IsIntegerType(const AType: string): Boolean;
var
  T: string;
begin
  T := LowerCase(Trim(AType));
  Result := (T = 'int32') or (T = 'int64') or (T = 'uint32') or (T = 'uint64') or
            (T = 'int16') or (T = 'uint16') or (T = 'int8') or (T = 'uint8') or (T = 'int');
end;

function IsFloatType(const AType: string): Boolean;
var
  T: string;
begin
  T := LowerCase(Trim(AType));
  Result := (T = 'float64') or (T = 'float32') or (T = 'double') or (T = 'float');
end;

function FindTrait(AModule: TASTModule; const ATraitName: string): TASTTraitDecl;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to AModule.Traits.Count - 1 do
  begin
    if SameText(TASTTraitDecl(AModule.Traits[I]).Name, ATraitName) then
      Exit(TASTTraitDecl(AModule.Traits[I]));
  end;
end;

function FindEnumDecl(AModule: TASTModule; const AName: string): TASTEnumDecl;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to AModule.Types.Count - 1 do
    if (AModule.Types[I] is TASTEnumDecl) and SameText(TASTEnumDecl(AModule.Types[I]).Name, AName) then
      Exit(TASTEnumDecl(AModule.Types[I]));
end;

function FindRecordDecl(AModule: TASTModule; const AName: string): TASTRecordDecl;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to AModule.Types.Count - 1 do
    if (AModule.Types[I] is TASTRecordDecl) and SameText(TASTRecordDecl(AModule.Types[I]).Name, AName) then
      Exit(TASTRecordDecl(AModule.Types[I]));
end;

function FindSubrangeDecl(AModule: TASTModule; const AName: string): TASTSubrangeDecl;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to AModule.Types.Count - 1 do
    if (AModule.Types[I] is TASTSubrangeDecl) and SameText(TASTSubrangeDecl(AModule.Types[I]).Name, AName) then
      Exit(TASTSubrangeDecl(AModule.Types[I]));
end;

function FindArrayDecl(AModule: TASTModule; const AName: string): TASTArrayDecl;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to AModule.Types.Count - 1 do
    if (AModule.Types[I] is TASTArrayDecl) and SameText(TASTArrayDecl(AModule.Types[I]).Name, AName) then
      Exit(TASTArrayDecl(AModule.Types[I]));
end;

function IsArrayFieldType(AModule: TASTModule; const AType: string; out ElemType: string): Boolean;
var
  T: string;
  P1: Integer;
  ArrDecl: TASTArrayDecl;
begin
  ElemType := '';
  T := Trim(AType);
  if Pos('array of ', LowerCase(T)) = 1 then
  begin
    ElemType := Trim(Copy(T, 10, Length(T)));
    Exit(True);
  end;
  if Pos('array[', LowerCase(T)) = 1 then
  begin
    P1 := Pos('] of ', LowerCase(T));
    if P1 > 0 then
    begin
      ElemType := Trim(Copy(T, P1 + 5, Length(T)));
      Exit(True);
    end;
  end;
  ArrDecl := FindArrayDecl(AModule, T);
  if Assigned(ArrDecl) then
  begin
    ElemType := ArrDecl.ElemType;
    Exit(True);
  end;
  Result := False;
end;

function SplitOptionType(const AType: string; out InnerType: string): Boolean;
var
  T: string;
begin
  InnerType := '';
  T := Trim(AType);
  if (Pos('Option<', T) = 1) and (Length(T) > 8) and (T[Length(T)] = '>') then
  begin
    InnerType := Trim(Copy(T, 8, Length(T) - 8));
    Exit(True);
  end;
  Result := False;
end;

function SplitResultType(const AType: string; out OkType, ErrType: string): Boolean;
var
  T, Inner: string;
  I, Depth, CommaPos: Integer;
begin
  OkType := '';
  ErrType := '';
  T := Trim(AType);
  if (Pos('Result<', T) <> 1) or (Length(T) <= 8) or (T[Length(T)] <> '>') then
    Exit(False);
  Inner := Copy(T, 8, Length(T) - 8);
  Depth := 0;
  CommaPos := 0;
  for I := 1 to Length(Inner) do
  begin
    if Inner[I] = '<' then Inc(Depth)
    else if Inner[I] = '>' then Dec(Depth)
    else if (Inner[I] = ',') and (Depth = 0) then
    begin
      CommaPos := I;
      Break;
    end;
  end;
  if CommaPos > 0 then
  begin
    OkType := Trim(Copy(Inner, 1, CommaPos - 1));
    ErrType := Trim(Copy(Inner, CommaPos + 1, Length(Inner)));
    Exit(True);
  end;
  Result := False;
end;

function HasImplMethod(AModule: TASTModule; const ATargetType, AMethodName: string): Boolean;
var
  I, J: Integer;
  ImplDecl: TASTImplDecl;
begin
  Result := False;
  for I := 0 to AModule.Impls.Count - 1 do
  begin
    ImplDecl := TASTImplDecl(AModule.Impls[I]);
    if SameText(ImplDecl.TargetTypeName, ATargetType) then
    begin
      for J := 0 to ImplDecl.Methods.Count - 1 do
        if SameText(TASTFunction(ImplDecl.Methods[J]).Name, AMethodName) then
          Exit(True);
    end;
  end;
end;

procedure EnsureStandardTraits(AModule: TASTModule);
var
  TraitNode: TASTTraitDecl;
  MethodNode: TASTFunction;
begin
  // Trait Debug
  if not Assigned(FindTrait(AModule, 'Debug')) then
  begin
    TraitNode := TASTTraitDecl.Create(1, 1, 'Debug');
    MethodNode := TASTFunction.Create(1, 1, 'ToString', 'String');
    MethodNode.Params.Add(TASTParam.Create(1, 1, 'self', 'Self', owBorrow));
    TraitNode.Methods.Add(MethodNode);
    AModule.Traits.Add(TraitNode);
  end;

  // Trait JSON
  if not Assigned(FindTrait(AModule, 'JSON')) then
  begin
    TraitNode := TASTTraitDecl.Create(1, 1, 'JSON');
    MethodNode := TASTFunction.Create(1, 1, 'ToJSON', 'String');
    MethodNode.Params.Add(TASTParam.Create(1, 1, 'self', 'Self', owBorrow));
    TraitNode.Methods.Add(MethodNode);
    AModule.Traits.Add(TraitNode);
  end;

  // Trait Clone
  if not Assigned(FindTrait(AModule, 'Clone')) then
  begin
    TraitNode := TASTTraitDecl.Create(1, 1, 'Clone');
    MethodNode := TASTFunction.Create(1, 1, 'Clone', 'Self');
    MethodNode.Params.Add(TASTParam.Create(1, 1, 'self', 'Self', owBorrow));
    TraitNode.Methods.Add(MethodNode);
    AModule.Traits.Add(TraitNode);
  end;

  // Trait Equals
  if not Assigned(FindTrait(AModule, 'Equals')) then
  begin
    TraitNode := TASTTraitDecl.Create(1, 1, 'Equals');
    MethodNode := TASTFunction.Create(1, 1, 'Equals', 'Bool');
    MethodNode.Params.Add(TASTParam.Create(1, 1, 'self', 'Self', owBorrow));
    MethodNode.Params.Add(TASTParam.Create(1, 1, 'other', 'Self', owBorrow));
    TraitNode.Methods.Add(MethodNode);
    AModule.Traits.Add(TraitNode);
  end;
end;

function ConcatExpr(Left, Right: TASTExpr; Line, Col: Integer): TASTExpr;
begin
  if not Assigned(Left) then
    Result := Right
  else
    Result := TASTBinaryExpr.Create(Line, Col, Left, '+', Right);
end;

function StrLit(L, C: Integer; const S: string): TASTExpr;
begin
  Result := TASTLiteralExpr.Create(L, C, lkString, S);
end;

function MakeCall1(L, C: Integer; const Callee: string; ArgExpr: TASTExpr; Own: TOwnershipKind = owNone): TASTCallExpr;
begin
  Result := TASTCallExpr.Create(L, C, Callee);
  Result.Args.Add(TASTCallArg.Create(L, C, Own, ArgExpr));
end;

function MakeCall2(L, C: Integer; const Callee: string; Arg1, Arg2: TASTExpr; Own1: TOwnershipKind = owNone; Own2: TOwnershipKind = owNone): TASTCallExpr;
begin
  Result := TASTCallExpr.Create(L, C, Callee);
  Result.Args.Add(TASTCallArg.Create(L, C, Own1, Arg1));
  Result.Args.Add(TASTCallArg.Create(L, C, Own2, Arg2));
end;

function QuoteStrExpr(L, C: Integer; InnerExpr: TASTExpr; const QuoteChar: string = '"'): TASTExpr;
begin
  Result := ConcatExpr(
    StrLit(L, C, QuoteChar),
    ConcatExpr(InnerExpr, StrLit(L, C, QuoteChar), L, C),
    L, C
  );
end;

procedure GenerateEnumDebug(AModule: TASTModule; EnumDecl: TASTEnumDecl); forward;
procedure GenerateEnumJSON(AModule: TASTModule; EnumDecl: TASTEnumDecl); forward;
procedure GenerateEnumFromJSON(AModule: TASTModule; EnumDecl: TASTEnumDecl); forward;
procedure GenerateEnumEquals(AModule: TASTModule; EnumDecl: TASTEnumDecl); forward;

function MakeValueDebugExpr(AModule: TASTModule; ValExpr: TASTExpr; const TypeName: string; L, C: Integer): TASTExpr;
var
  T, InnerT, OkT, ErrT: string;
  SubDecl: TASTSubrangeDecl;
  EnumDecl: TASTEnumDecl;
  IsSomeExpr, IsOkExpr, SomeValExpr, OkValExpr, ErrValExpr: TASTExpr;
  ThenExpr, ElseExpr: TASTExpr;
begin
  T := Trim(TypeName);
  if SameText(T, 'String') then
    Result := QuoteStrExpr(L, C, ValExpr, '"')
  else if IsIntegerType(T) then
    Result := MakeCall1(L, C, 'IntToStr', ValExpr)
  else if IsFloatType(T) then
    Result := MakeCall1(L, C, 'FloatToStr', ValExpr)
  else if SameText(T, 'Bool') then
    Result := MakeCall1(L, C, 'BoolToStr', ValExpr)
  else if SameText(T, 'Char') then
    Result := QuoteStrExpr(L, C, MakeCall1(L, C, 'CharToStr', ValExpr), '''')
  else if Assigned(FindSubrangeDecl(AModule, T)) then
  begin
    SubDecl := FindSubrangeDecl(AModule, T);
    if SameText(SubDecl.BaseType, 'Char') then
      Result := QuoteStrExpr(L, C, MakeCall1(L, C, 'CharToStr', ValExpr), '''')
    else
      Result := MakeCall1(L, C, 'IntToStr', ValExpr);
  end
  else if SplitOptionType(T, InnerT) then
  begin
    IsSomeExpr := TASTMemberAccessExpr.Create(L, C, TASTExpr(CloneASTNode(ValExpr)), 'is_some');
    SomeValExpr := TASTMemberAccessExpr.Create(L, C, ValExpr, 'value');
    ThenExpr := ConcatExpr(
      StrLit(L, C, 'Some('),
      ConcatExpr(MakeValueDebugExpr(AModule, SomeValExpr, InnerT, L, C), StrLit(L, C, ')'), L, C),
      L, C
    );
    ElseExpr := StrLit(L, C, 'None');
    Result := TASTIfExpr.Create(L, C, IsSomeExpr, ThenExpr, ElseExpr);
  end
  else if SplitResultType(T, OkT, ErrT) then
  begin
    IsOkExpr := TASTMemberAccessExpr.Create(L, C, TASTExpr(CloneASTNode(ValExpr)), 'is_ok');
    OkValExpr := TASTMemberAccessExpr.Create(L, C, TASTExpr(CloneASTNode(ValExpr)), 'value');
    ErrValExpr := TASTMemberAccessExpr.Create(L, C, ValExpr, 'error');
    ThenExpr := ConcatExpr(
      StrLit(L, C, 'Ok('),
      ConcatExpr(MakeValueDebugExpr(AModule, OkValExpr, OkT, L, C), StrLit(L, C, ')'), L, C),
      L, C
    );
    ElseExpr := ConcatExpr(
      StrLit(L, C, 'Err('),
      ConcatExpr(MakeValueDebugExpr(AModule, ErrValExpr, ErrT, L, C), StrLit(L, C, ')'), L, C),
      L, C
    );
    Result := TASTIfExpr.Create(L, C, IsOkExpr, ThenExpr, ElseExpr);
  end
  else
  begin
    EnumDecl := FindEnumDecl(AModule, T);
    if Assigned(EnumDecl) and not HasImplMethod(AModule, EnumDecl.Name, 'ToString') then
      GenerateEnumDebug(AModule, EnumDecl);
    Result := MakeCall1(L, C, 'ToString', ValExpr, owBorrow);
  end;
end;

function MakeValueJSONExpr(AModule: TASTModule; ValExpr: TASTExpr; const TypeName: string; L, C: Integer): TASTExpr;
var
  T, InnerT, OkT, ErrT: string;
  SubDecl: TASTSubrangeDecl;
  EnumDecl: TASTEnumDecl;
  IsSomeExpr, IsOkExpr, SomeValExpr, OkValExpr, ErrValExpr: TASTExpr;
  ThenExpr, ElseExpr: TASTExpr;
begin
  T := Trim(TypeName);
  if SameText(T, 'String') then
    Result := QuoteStrExpr(L, C, ValExpr, '"')
  else if IsIntegerType(T) then
    Result := MakeCall1(L, C, 'IntToStr', ValExpr)
  else if IsFloatType(T) then
    Result := MakeCall1(L, C, 'FloatToStr', ValExpr)
  else if SameText(T, 'Bool') then
    Result := MakeCall1(L, C, 'BoolToStr', ValExpr)
  else if SameText(T, 'Char') then
    Result := QuoteStrExpr(L, C, MakeCall1(L, C, 'CharToStr', ValExpr), '"')
  else if Assigned(FindSubrangeDecl(AModule, T)) then
  begin
    SubDecl := FindSubrangeDecl(AModule, T);
    if SameText(SubDecl.BaseType, 'Char') then
      Result := QuoteStrExpr(L, C, MakeCall1(L, C, 'CharToStr', ValExpr), '"')
    else
      Result := MakeCall1(L, C, 'IntToStr', ValExpr);
  end
  else if SplitOptionType(T, InnerT) then
  begin
    IsSomeExpr := TASTMemberAccessExpr.Create(L, C, TASTExpr(CloneASTNode(ValExpr)), 'is_some');
    SomeValExpr := TASTMemberAccessExpr.Create(L, C, ValExpr, 'value');
    ThenExpr := MakeValueJSONExpr(AModule, SomeValExpr, InnerT, L, C);
    ElseExpr := StrLit(L, C, 'null');
    Result := TASTIfExpr.Create(L, C, IsSomeExpr, ThenExpr, ElseExpr);
  end
  else if SplitResultType(T, OkT, ErrT) then
  begin
    IsOkExpr := TASTMemberAccessExpr.Create(L, C, TASTExpr(CloneASTNode(ValExpr)), 'is_ok');
    OkValExpr := TASTMemberAccessExpr.Create(L, C, TASTExpr(CloneASTNode(ValExpr)), 'value');
    ErrValExpr := TASTMemberAccessExpr.Create(L, C, ValExpr, 'error');
    ThenExpr := ConcatExpr(
      StrLit(L, C, '{"ok": '),
      ConcatExpr(MakeValueJSONExpr(AModule, OkValExpr, OkT, L, C), StrLit(L, C, '}'), L, C),
      L, C
    );
    ElseExpr := ConcatExpr(
      StrLit(L, C, '{"err": '),
      ConcatExpr(MakeValueJSONExpr(AModule, ErrValExpr, ErrT, L, C), StrLit(L, C, '}'), L, C),
      L, C
    );
    Result := TASTIfExpr.Create(L, C, IsOkExpr, ThenExpr, ElseExpr);
  end
  else
  begin
    EnumDecl := FindEnumDecl(AModule, T);
    if Assigned(EnumDecl) and not HasImplMethod(AModule, EnumDecl.Name, 'ToJSON') then
      GenerateEnumJSON(AModule, EnumDecl);
    Result := MakeCall1(L, C, 'ToJSON', ValExpr, owBorrow);
  end;
end;

function MakeValueEqualsExpr(AModule: TASTModule; LeftExpr, RightExpr: TASTExpr; const TypeName: string; L, C: Integer): TASTExpr;
var
  T, InnerT, OkT, ErrT: string;
  EnumDecl: TASTEnumDecl;
  CondOpt, FlagEq, ThenExpr, ElseExpr, InnerEq, CondRes, ErrEq: TASTExpr;
begin
  T := Trim(TypeName);
  if IsIntegerType(T) or IsFloatType(T) or SameText(T, 'Bool') or SameText(T, 'String') or
     SameText(T, 'Char') or Assigned(FindSubrangeDecl(AModule, T)) then
  begin
    Result := TASTBinaryExpr.Create(L, C, LeftExpr, '=', RightExpr);
  end
  else if Assigned(FindEnumDecl(AModule, T)) then
  begin
    EnumDecl := FindEnumDecl(AModule, T);
    if EnumDecl.HasDerive('Equals') then
      Result := MakeCall2(L, C, 'Equals', LeftExpr, RightExpr, owBorrow, owBorrow)
    else
      Result := TASTBinaryExpr.Create(L, C, LeftExpr, '=', RightExpr);
  end
  else if SplitOptionType(T, InnerT) then
  begin
    FlagEq := TASTBinaryExpr.Create(L, C,
      TASTMemberAccessExpr.Create(L, C, TASTExpr(CloneASTNode(LeftExpr)), 'is_some'),
      '=',
      TASTMemberAccessExpr.Create(L, C, TASTExpr(CloneASTNode(RightExpr)), 'is_some')
    );
    CondOpt := TASTMemberAccessExpr.Create(L, C, TASTExpr(CloneASTNode(LeftExpr)), 'is_some');
    InnerEq := MakeValueEqualsExpr(AModule,
      TASTMemberAccessExpr.Create(L, C, LeftExpr, 'value'),
      TASTMemberAccessExpr.Create(L, C, RightExpr, 'value'),
      InnerT, L, C
    );
    ElseExpr := TASTLiteralExpr.Create(L, C, lkBool, 'true');
    ThenExpr := TASTIfExpr.Create(L, C, CondOpt, InnerEq, ElseExpr);
    Result := TASTBinaryExpr.Create(L, C, FlagEq, 'and', ThenExpr);
  end
  else if SplitResultType(T, OkT, ErrT) then
  begin
    FlagEq := TASTBinaryExpr.Create(L, C,
      TASTMemberAccessExpr.Create(L, C, TASTExpr(CloneASTNode(LeftExpr)), 'is_ok'),
      '=',
      TASTMemberAccessExpr.Create(L, C, TASTExpr(CloneASTNode(RightExpr)), 'is_ok')
    );
    CondRes := TASTMemberAccessExpr.Create(L, C, TASTExpr(CloneASTNode(LeftExpr)), 'is_ok');
    ThenExpr := MakeValueEqualsExpr(AModule,
      TASTMemberAccessExpr.Create(L, C, TASTExpr(CloneASTNode(LeftExpr)), 'value'),
      TASTMemberAccessExpr.Create(L, C, TASTExpr(CloneASTNode(RightExpr)), 'value'),
      OkT, L, C
    );
    ErrEq := MakeValueEqualsExpr(AModule,
      TASTMemberAccessExpr.Create(L, C, LeftExpr, 'error'),
      TASTMemberAccessExpr.Create(L, C, RightExpr, 'error'),
      ErrT, L, C
    );
    Result := TASTBinaryExpr.Create(L, C, FlagEq, 'and', TASTIfExpr.Create(L, C, CondRes, ThenExpr, ErrEq));
  end
  else
    Result := MakeCall2(L, C, 'Equals', LeftExpr, RightExpr, owBorrow, owBorrow);
end;

procedure GenerateRecordStringFormat(AModule: TASTModule; RecDecl: TASTRecordDecl; IsJSON: Boolean);
var
  ImplDecl: TASTImplDecl;
  Func: TASTFunction;
  FullExpr, FieldValExpr, FieldAcc: TASTExpr;
  F: TASTRecordField;
  I, L, C: Integer;
  HasArrayFields: Boolean;
  ElemType, TraitName, MethodName, Prefix, Suffix, Sep, FieldVar, FirstVar: string;
  ForStmt: TASTForStmt;
  IfSep: TASTIfStmt;
begin
  L := RecDecl.Line;
  C := RecDecl.Col;
  if IsJSON then
  begin
    TraitName := 'JSON';
    MethodName := 'ToJSON';
    Prefix := '{';
    Suffix := '}';
  end
  else
  begin
    TraitName := 'Debug';
    MethodName := 'ToString';
    Prefix := RecDecl.Name + ' { ';
    Suffix := ' }';
  end;

  ImplDecl := TASTImplDecl.Create(L, C, TraitName, RecDecl.Name);
  Func := TASTFunction.Create(L, C, MethodName, 'String');
  Func.Params.Add(TASTParam.Create(L, C, 'self', RecDecl.Name, owBorrow));

  if RecDecl.Fields.Count = 0 then
  begin
    if IsJSON then
      FullExpr := StrLit(L, C, '{}')
    else
      FullExpr := StrLit(L, C, RecDecl.Name + ' {}');
    Func.Body.Add(TASTReturnStmt.Create(L, C, FullExpr));
    ImplDecl.Methods.Add(Func);
    AModule.Impls.Add(ImplDecl);
    Exit;
  end;

  HasArrayFields := False;
  for I := 0 to RecDecl.Fields.Count - 1 do
    if IsArrayFieldType(AModule, TASTRecordField(RecDecl.Fields[I]).TypeName, ElemType) then
    begin
      HasArrayFields := True;
      Break;
    end;

  if not HasArrayFields then
  begin
    FullExpr := StrLit(L, C, Prefix);
    for I := 0 to RecDecl.Fields.Count - 1 do
    begin
      F := TASTRecordField(RecDecl.Fields[I]);
      if IsJSON then
        Sep := '"' + F.Name + '": '
      else
        Sep := F.Name + ': ';
      FullExpr := ConcatExpr(FullExpr, StrLit(L, C, Sep), L, C);

      FieldAcc := TASTMemberAccessExpr.Create(L, C, TASTIdentifierExpr.Create(L, C, 'self'), F.Name);
      if IsJSON then
        FieldValExpr := MakeValueJSONExpr(AModule, FieldAcc, F.TypeName, L, C)
      else
        FieldValExpr := MakeValueDebugExpr(AModule, FieldAcc, F.TypeName, L, C);

      FullExpr := ConcatExpr(FullExpr, FieldValExpr, L, C);
      if I < RecDecl.Fields.Count - 1 then
        FullExpr := ConcatExpr(FullExpr, StrLit(L, C, ', '), L, C);
    end;
    FullExpr := ConcatExpr(FullExpr, StrLit(L, C, Suffix), L, C);
    Func.Body.Add(TASTReturnStmt.Create(L, C, FullExpr));
  end
  else
  begin
    Func.LocalVars.Add(TASTVarDecl.Create(L, C, '_fmt_res', 'String', StrLit(L, C, Prefix), True));
    for I := 0 to RecDecl.Fields.Count - 1 do
    begin
      F := TASTRecordField(RecDecl.Fields[I]);
      if IsJSON then Sep := '"' + F.Name + '": ' else Sep := F.Name + ': ';
      Func.Body.Add(TASTAssignStmt.Create(L, C,
        TASTIdentifierExpr.Create(L, C, '_fmt_res'),
        ConcatExpr(TASTIdentifierExpr.Create(L, C, '_fmt_res'), StrLit(L, C, Sep), L, C)
      ));

      FieldAcc := TASTMemberAccessExpr.Create(L, C, TASTIdentifierExpr.Create(L, C, 'self'), F.Name);
      if IsArrayFieldType(AModule, F.TypeName, ElemType) then
      begin
        FieldVar := Format('_fmt_el_%d', [I]);
        FirstVar := Format('_fmt_first_%d', [I]);
        Func.LocalVars.Add(TASTVarDecl.Create(L, C, FieldVar, ElemType, nil, True));
        Func.LocalVars.Add(TASTVarDecl.Create(L, C, FirstVar, 'Bool', TASTLiteralExpr.Create(L, C, lkBool, 'true'), True));

        Func.Body.Add(TASTAssignStmt.Create(L, C,
          TASTIdentifierExpr.Create(L, C, '_fmt_res'),
          ConcatExpr(TASTIdentifierExpr.Create(L, C, '_fmt_res'), StrLit(L, C, '['), L, C)
        ));
        Func.Body.Add(TASTAssignStmt.Create(L, C,
          TASTIdentifierExpr.Create(L, C, FirstVar),
          TASTLiteralExpr.Create(L, C, lkBool, 'true')
        ));

        ForStmt := TASTForStmt.Create(L, C, FieldVar, nil, nil);
        ForStmt.CollectionExpr := FieldAcc;
        IfSep := TASTIfStmt.Create(L, C, TASTUnaryExpr.Create(L, C, 'not', TASTIdentifierExpr.Create(L, C, FirstVar)));
        IfSep.ThenBranch.Add(TASTAssignStmt.Create(L, C,
          TASTIdentifierExpr.Create(L, C, '_fmt_res'),
          ConcatExpr(TASTIdentifierExpr.Create(L, C, '_fmt_res'), StrLit(L, C, ', '), L, C)
        ));
        ForStmt.Body.Add(IfSep);
        ForStmt.Body.Add(TASTAssignStmt.Create(L, C,
          TASTIdentifierExpr.Create(L, C, FirstVar),
          TASTLiteralExpr.Create(L, C, lkBool, 'false')
        ));
        if IsJSON then
          FieldValExpr := MakeValueJSONExpr(AModule, TASTIdentifierExpr.Create(L, C, FieldVar), ElemType, L, C)
        else
          FieldValExpr := MakeValueDebugExpr(AModule, TASTIdentifierExpr.Create(L, C, FieldVar), ElemType, L, C);
        ForStmt.Body.Add(TASTAssignStmt.Create(L, C,
          TASTIdentifierExpr.Create(L, C, '_fmt_res'),
          ConcatExpr(TASTIdentifierExpr.Create(L, C, '_fmt_res'), FieldValExpr, L, C)
        ));
        Func.Body.Add(ForStmt);

        Func.Body.Add(TASTAssignStmt.Create(L, C,
          TASTIdentifierExpr.Create(L, C, '_fmt_res'),
          ConcatExpr(TASTIdentifierExpr.Create(L, C, '_fmt_res'), StrLit(L, C, ']'), L, C)
        ));
      end
      else
      begin
        if IsJSON then
          FieldValExpr := MakeValueJSONExpr(AModule, FieldAcc, F.TypeName, L, C)
        else
          FieldValExpr := MakeValueDebugExpr(AModule, FieldAcc, F.TypeName, L, C);
        Func.Body.Add(TASTAssignStmt.Create(L, C,
          TASTIdentifierExpr.Create(L, C, '_fmt_res'),
          ConcatExpr(TASTIdentifierExpr.Create(L, C, '_fmt_res'), FieldValExpr, L, C)
        ));
      end;

      if I < RecDecl.Fields.Count - 1 then
        Func.Body.Add(TASTAssignStmt.Create(L, C,
          TASTIdentifierExpr.Create(L, C, '_fmt_res'),
          ConcatExpr(TASTIdentifierExpr.Create(L, C, '_fmt_res'), StrLit(L, C, ', '), L, C)
        ));
    end;
    Func.Body.Add(TASTAssignStmt.Create(L, C,
      TASTIdentifierExpr.Create(L, C, '_fmt_res'),
      ConcatExpr(TASTIdentifierExpr.Create(L, C, '_fmt_res'), StrLit(L, C, Suffix), L, C)
    ));
    Func.Body.Add(TASTReturnStmt.Create(L, C, TASTIdentifierExpr.Create(L, C, '_fmt_res')));
  end;

  ImplDecl.Methods.Add(Func);
  AModule.Impls.Add(ImplDecl);
end;

procedure GenerateRecordClone(AModule: TASTModule; RecDecl: TASTRecordDecl);
var
  ImplDecl: TASTImplDecl;
  Func: TASTFunction;
  CallExpr: TASTCallExpr;
  F: TASTRecordField;
  I: Integer;
begin
  ImplDecl := TASTImplDecl.Create(RecDecl.Line, RecDecl.Col, 'Clone', RecDecl.Name);
  Func := TASTFunction.Create(RecDecl.Line, RecDecl.Col, 'Clone', RecDecl.Name);
  Func.Params.Add(TASTParam.Create(RecDecl.Line, RecDecl.Col, 'self', RecDecl.Name, owBorrow));

  CallExpr := TASTCallExpr.Create(RecDecl.Line, RecDecl.Col, RecDecl.Name);
  for I := 0 to RecDecl.Fields.Count - 1 do
  begin
    F := TASTRecordField(RecDecl.Fields[I]);
    CallExpr.Args.Add(TASTCallArg.Create(RecDecl.Line, RecDecl.Col, owNone,
      TASTMemberAccessExpr.Create(RecDecl.Line, RecDecl.Col, TASTIdentifierExpr.Create(RecDecl.Line, RecDecl.Col, 'self'), F.Name)
    ));
  end;

  Func.Body.Add(TASTReturnStmt.Create(RecDecl.Line, RecDecl.Col, CallExpr));
  ImplDecl.Methods.Add(Func);
  AModule.Impls.Add(ImplDecl);
end;

procedure GenerateRecordEquals(AModule: TASTModule; RecDecl: TASTRecordDecl);
var
  ImplDecl: TASTImplDecl;
  Func: TASTFunction;
  EqExpr, FullExpr, SelfAcc, OtherAcc, LenCond, ZeroGuard, ElemSelf, ElemOther: TASTExpr;
  IfLen, IfZero, IfElem: TASTIfStmt;
  ForLoop: TASTForStmt;
  F: TASTRecordField;
  I, L, C: Integer;
  HasArrayFields: Boolean;
  ElemType, IdxVar: string;
begin
  L := RecDecl.Line;
  C := RecDecl.Col;
  ImplDecl := TASTImplDecl.Create(L, C, 'Equals', RecDecl.Name);
  Func := TASTFunction.Create(L, C, 'Equals', 'Bool');
  Func.Params.Add(TASTParam.Create(L, C, 'self', RecDecl.Name, owBorrow));
  Func.Params.Add(TASTParam.Create(L, C, 'other', RecDecl.Name, owBorrow));

  if RecDecl.Fields.Count = 0 then
  begin
    Func.Body.Add(TASTReturnStmt.Create(L, C, TASTLiteralExpr.Create(L, C, lkBool, 'true')));
    ImplDecl.Methods.Add(Func);
    AModule.Impls.Add(ImplDecl);
    Exit;
  end;

  HasArrayFields := False;
  for I := 0 to RecDecl.Fields.Count - 1 do
    if IsArrayFieldType(AModule, TASTRecordField(RecDecl.Fields[I]).TypeName, ElemType) then
    begin
      HasArrayFields := True;
      Break;
    end;

  if not HasArrayFields then
  begin
    FullExpr := nil;
    for I := 0 to RecDecl.Fields.Count - 1 do
    begin
      F := TASTRecordField(RecDecl.Fields[I]);
      SelfAcc := TASTMemberAccessExpr.Create(L, C, TASTIdentifierExpr.Create(L, C, 'self'), F.Name);
      OtherAcc := TASTMemberAccessExpr.Create(L, C, TASTIdentifierExpr.Create(L, C, 'other'), F.Name);
      EqExpr := MakeValueEqualsExpr(AModule, SelfAcc, OtherAcc, F.TypeName, L, C);
      if not Assigned(FullExpr) then
        FullExpr := EqExpr
      else
        FullExpr := TASTBinaryExpr.Create(L, C, FullExpr, 'and', EqExpr);
    end;
    Func.Body.Add(TASTReturnStmt.Create(L, C, FullExpr));
  end
  else
  begin
    for I := 0 to RecDecl.Fields.Count - 1 do
    begin
      F := TASTRecordField(RecDecl.Fields[I]);
      SelfAcc := TASTMemberAccessExpr.Create(L, C, TASTIdentifierExpr.Create(L, C, 'self'), F.Name);
      OtherAcc := TASTMemberAccessExpr.Create(L, C, TASTIdentifierExpr.Create(L, C, 'other'), F.Name);

      if IsArrayFieldType(AModule, F.TypeName, ElemType) then
      begin
        LenCond := TASTBinaryExpr.Create(L, C,
          MakeCall1(L, C, 'Length', SelfAcc),
          '<>',
          MakeCall1(L, C, 'Length', OtherAcc)
        );
        IfLen := TASTIfStmt.Create(L, C, LenCond);
        IfLen.ThenBranch.Add(TASTReturnStmt.Create(L, C, TASTLiteralExpr.Create(L, C, lkBool, 'false')));
        Func.Body.Add(IfLen);

        IdxVar := Format('_eq_i_%d', [I]);
        Func.LocalVars.Add(TASTVarDecl.Create(L, C, IdxVar, 'Int32', TASTLiteralExpr.Create(L, C, lkInt, '0'), True));

        ZeroGuard := TASTBinaryExpr.Create(L, C,
          MakeCall1(L, C, 'Int32', MakeCall1(L, C, 'Length', TASTMemberAccessExpr.Create(L, C, TASTIdentifierExpr.Create(L, C, 'self'), F.Name))),
          '>',
          TASTLiteralExpr.Create(L, C, lkInt, '0')
        );
        IfZero := TASTIfStmt.Create(L, C, ZeroGuard);
        ForLoop := TASTForStmt.Create(L, C, IdxVar,
          TASTLiteralExpr.Create(L, C, lkInt, '0'),
          TASTBinaryExpr.Create(L, C,
            MakeCall1(L, C, 'Int32', MakeCall1(L, C, 'Length', TASTMemberAccessExpr.Create(L, C, TASTIdentifierExpr.Create(L, C, 'self'), F.Name))),
            '-',
            TASTLiteralExpr.Create(L, C, lkInt, '1')
          )
        );

        ElemSelf := TASTIndexExpr.Create(L, C, TASTMemberAccessExpr.Create(L, C, TASTIdentifierExpr.Create(L, C, 'self'), F.Name));
        TASTIndexExpr(ElemSelf).Indices.Add(TASTIdentifierExpr.Create(L, C, IdxVar));
        ElemOther := TASTIndexExpr.Create(L, C, TASTMemberAccessExpr.Create(L, C, TASTIdentifierExpr.Create(L, C, 'other'), F.Name));
        TASTIndexExpr(ElemOther).Indices.Add(TASTIdentifierExpr.Create(L, C, IdxVar));

        IfElem := TASTIfStmt.Create(L, C,
          TASTUnaryExpr.Create(L, C, 'not', MakeValueEqualsExpr(AModule, ElemSelf, ElemOther, ElemType, L, C))
        );
        IfElem.ThenBranch.Add(TASTReturnStmt.Create(L, C, TASTLiteralExpr.Create(L, C, lkBool, 'false')));
        ForLoop.Body.Add(IfElem);
        IfZero.ThenBranch.Add(ForLoop);
        Func.Body.Add(IfZero);
      end
      else
      begin
        IfLen := TASTIfStmt.Create(L, C,
          TASTUnaryExpr.Create(L, C, 'not', MakeValueEqualsExpr(AModule, SelfAcc, OtherAcc, F.TypeName, L, C))
        );
        IfLen.ThenBranch.Add(TASTReturnStmt.Create(L, C, TASTLiteralExpr.Create(L, C, lkBool, 'false')));
        Func.Body.Add(IfLen);
      end;
    end;
    Func.Body.Add(TASTReturnStmt.Create(L, C, TASTLiteralExpr.Create(L, C, lkBool, 'true')));
  end;

  ImplDecl.Methods.Add(Func);
  AModule.Impls.Add(ImplDecl);
end;

function MakeFieldFromJSONExpr(AModule: TASTModule; const FieldName, TypeName: string; L, C: Integer): TASTExpr;
var
  T, InnerT: string;
  SubDecl: TASTSubrangeDecl;
  EnumDecl: TASTEnumDecl;
  RecDecl: TASTRecordDecl;
begin
  T := Trim(TypeName);
  if SameText(T, 'String') then
    Result := MakeCall2(L, C, '__JsonGetStr', TASTIdentifierExpr.Create(L, C, 'json'), StrLit(L, C, FieldName))
  else if IsIntegerType(T) then
    Result := MakeCall2(L, C, '__JsonGetInt', TASTIdentifierExpr.Create(L, C, 'json'), StrLit(L, C, FieldName))
  else if IsFloatType(T) then
    Result := MakeCall2(L, C, '__JsonGetFloat', TASTIdentifierExpr.Create(L, C, 'json'), StrLit(L, C, FieldName))
  else if SameText(T, 'Bool') then
    Result := MakeCall2(L, C, '__JsonGetBool', TASTIdentifierExpr.Create(L, C, 'json'), StrLit(L, C, FieldName))
  else if SameText(T, 'Char') then
    Result := MakeCall2(L, C, '__JsonGetChar', TASTIdentifierExpr.Create(L, C, 'json'), StrLit(L, C, FieldName))
  else if Assigned(FindSubrangeDecl(AModule, T)) then
  begin
    SubDecl := FindSubrangeDecl(AModule, T);
    if SameText(SubDecl.BaseType, 'Char') then
      Result := MakeCall2(L, C, '__JsonGetChar', TASTIdentifierExpr.Create(L, C, 'json'), StrLit(L, C, FieldName))
    else
      Result := MakeCall2(L, C, '__JsonGetInt', TASTIdentifierExpr.Create(L, C, 'json'), StrLit(L, C, FieldName));
  end
  else if SplitOptionType(T, InnerT) then
  begin
    Result := TASTIfExpr.Create(L, C,
      MakeCall2(L, C, '__JsonHasValue', TASTIdentifierExpr.Create(L, C, 'json'), StrLit(L, C, FieldName)),
      MakeCall1(L, C, 'Some', MakeFieldFromJSONExpr(AModule, FieldName, InnerT, L, C)),
      TASTIdentifierExpr.Create(L, C, 'None')
    );
  end
  else if Assigned(FindEnumDecl(AModule, T)) then
  begin
    EnumDecl := FindEnumDecl(AModule, T);
    if not HasImplMethod(AModule, EnumDecl.Name, 'FromJSON') then
      GenerateEnumFromJSON(AModule, EnumDecl);
    Result := MakeCall1(L, C, EnumDecl.Name + '_FromJSON',
      MakeCall2(L, C, '__JsonGetStr', TASTIdentifierExpr.Create(L, C, 'json'), StrLit(L, C, FieldName)),
      owBorrow
    );
  end
  else if Assigned(FindRecordDecl(AModule, T)) then
  begin
    RecDecl := FindRecordDecl(AModule, T);
    Result := MakeCall1(L, C, RecDecl.Name + '_FromJSON',
      MakeCall2(L, C, '__JsonGetObj', TASTIdentifierExpr.Create(L, C, 'json'), StrLit(L, C, FieldName)),
      owBorrow
    );
  end
  else
  begin
    Result := MakeCall1(L, C, 'Default', TASTIdentifierExpr.Create(L, C, T));
  end;
end;

procedure GenerateRecordFromJSON(AModule: TASTModule; RecDecl: TASTRecordDecl);
var
  ImplDecl: TASTImplDecl;
  Func: TASTFunction;
  CtorCall: TASTCallExpr;
  F: TASTRecordField;
  I, L, C: Integer;
begin
  if HasImplMethod(AModule, RecDecl.Name, 'FromJSON') then Exit;
  L := RecDecl.Line;
  C := RecDecl.Col;
  ImplDecl := TASTImplDecl.Create(L, C, '', RecDecl.Name);
  Func := TASTFunction.Create(L, C, 'FromJSON', RecDecl.Name);
  Func.Params.Add(TASTParam.Create(L, C, 'json', 'String', owBorrow));

  CtorCall := TASTCallExpr.Create(L, C, RecDecl.Name);
  for I := 0 to RecDecl.Fields.Count - 1 do
  begin
    F := TASTRecordField(RecDecl.Fields[I]);
    CtorCall.Args.Add(TASTCallArg.Create(L, C, owNone,
      MakeFieldFromJSONExpr(AModule, F.Name, F.TypeName, L, C)
    ));
  end;

  Func.Body.Add(TASTReturnStmt.Create(L, C, CtorCall));
  ImplDecl.Methods.Add(Func);
  AModule.Impls.Add(ImplDecl);
end;

procedure GenerateEnumDebug(AModule: TASTModule; EnumDecl: TASTEnumDecl);
var
  ImplDecl: TASTImplDecl;
  Func: TASTFunction;
  IfStmt: TASTIfStmt;
  Cond: TASTExpr;
  V: TASTEnumVariant;
  I: Integer;
begin
  if HasImplMethod(AModule, EnumDecl.Name, 'ToString') then Exit;
  ImplDecl := TASTImplDecl.Create(EnumDecl.Line, EnumDecl.Col, 'Debug', EnumDecl.Name);
  Func := TASTFunction.Create(EnumDecl.Line, EnumDecl.Col, 'ToString', 'String');
  Func.Params.Add(TASTParam.Create(EnumDecl.Line, EnumDecl.Col, 'self', EnumDecl.Name, owBorrow));

  for I := 0 to EnumDecl.Variants.Count - 1 do
  begin
    V := TASTEnumVariant(EnumDecl.Variants[I]);
    Cond := TASTBinaryExpr.Create(EnumDecl.Line, EnumDecl.Col,
      TASTIdentifierExpr.Create(EnumDecl.Line, EnumDecl.Col, 'self'),
      '=',
      TASTMemberAccessExpr.Create(EnumDecl.Line, EnumDecl.Col,
        TASTIdentifierExpr.Create(EnumDecl.Line, EnumDecl.Col, EnumDecl.Name),
        V.Name
      )
    );
    IfStmt := TASTIfStmt.Create(EnumDecl.Line, EnumDecl.Col, Cond);
    IfStmt.ThenBranch.Add(TASTReturnStmt.Create(EnumDecl.Line, EnumDecl.Col,
      TASTLiteralExpr.Create(EnumDecl.Line, EnumDecl.Col, lkString, EnumDecl.Name + '.' + V.Name)
    ));
    Func.Body.Add(IfStmt);
  end;

  Func.Body.Add(TASTReturnStmt.Create(EnumDecl.Line, EnumDecl.Col,
    TASTLiteralExpr.Create(EnumDecl.Line, EnumDecl.Col, lkString, '')
  ));

  ImplDecl.Methods.Add(Func);
  AModule.Impls.Add(ImplDecl);
end;

procedure GenerateEnumJSON(AModule: TASTModule; EnumDecl: TASTEnumDecl);
var
  ImplDecl: TASTImplDecl;
  Func: TASTFunction;
  IfStmt: TASTIfStmt;
  Cond: TASTExpr;
  V: TASTEnumVariant;
  I: Integer;
begin
  if HasImplMethod(AModule, EnumDecl.Name, 'ToJSON') then Exit;
  ImplDecl := TASTImplDecl.Create(EnumDecl.Line, EnumDecl.Col, 'JSON', EnumDecl.Name);
  Func := TASTFunction.Create(EnumDecl.Line, EnumDecl.Col, 'ToJSON', 'String');
  Func.Params.Add(TASTParam.Create(EnumDecl.Line, EnumDecl.Col, 'self', EnumDecl.Name, owBorrow));

  for I := 0 to EnumDecl.Variants.Count - 1 do
  begin
    V := TASTEnumVariant(EnumDecl.Variants[I]);
    Cond := TASTBinaryExpr.Create(EnumDecl.Line, EnumDecl.Col,
      TASTIdentifierExpr.Create(EnumDecl.Line, EnumDecl.Col, 'self'),
      '=',
      TASTMemberAccessExpr.Create(EnumDecl.Line, EnumDecl.Col,
        TASTIdentifierExpr.Create(EnumDecl.Line, EnumDecl.Col, EnumDecl.Name),
        V.Name
      )
    );
    IfStmt := TASTIfStmt.Create(EnumDecl.Line, EnumDecl.Col, Cond);
    IfStmt.ThenBranch.Add(TASTReturnStmt.Create(EnumDecl.Line, EnumDecl.Col,
      TASTLiteralExpr.Create(EnumDecl.Line, EnumDecl.Col, lkString, '"' + V.Name + '"')
    ));
    Func.Body.Add(IfStmt);
  end;

  Func.Body.Add(TASTReturnStmt.Create(EnumDecl.Line, EnumDecl.Col,
    TASTLiteralExpr.Create(EnumDecl.Line, EnumDecl.Col, lkString, '""')
  ));

  ImplDecl.Methods.Add(Func);
  AModule.Impls.Add(ImplDecl);
end;

procedure GenerateEnumFromJSON(AModule: TASTModule; EnumDecl: TASTEnumDecl);
var
  ImplDecl: TASTImplDecl;
  Func: TASTFunction;
  IfStmt: TASTIfStmt;
  Cond, Cmp1, Cmp2: TASTExpr;
  V: TASTEnumVariant;
  I, L, C: Integer;
begin
  if HasImplMethod(AModule, EnumDecl.Name, 'FromJSON') then Exit;
  L := EnumDecl.Line;
  C := EnumDecl.Col;
  ImplDecl := TASTImplDecl.Create(L, C, '', EnumDecl.Name);
  Func := TASTFunction.Create(L, C, 'FromJSON', EnumDecl.Name);
  Func.Params.Add(TASTParam.Create(L, C, 'json', 'String', owBorrow));

  for I := 0 to EnumDecl.Variants.Count - 1 do
  begin
    V := TASTEnumVariant(EnumDecl.Variants[I]);
    Cmp1 := TASTBinaryExpr.Create(L, C,
      TASTIdentifierExpr.Create(L, C, 'json'),
      '=',
      StrLit(L, C, V.Name)
    );
    Cmp2 := TASTBinaryExpr.Create(L, C,
      TASTIdentifierExpr.Create(L, C, 'json'),
      '=',
      StrLit(L, C, '"' + V.Name + '"')
    );
    Cond := TASTBinaryExpr.Create(L, C, Cmp1, 'or', Cmp2);
    IfStmt := TASTIfStmt.Create(L, C, Cond);
    IfStmt.ThenBranch.Add(TASTReturnStmt.Create(L, C,
      TASTMemberAccessExpr.Create(L, C,
        TASTIdentifierExpr.Create(L, C, EnumDecl.Name),
        V.Name
      )
    ));
    Func.Body.Add(IfStmt);
  end;

  if EnumDecl.Variants.Count > 0 then
    Func.Body.Add(TASTReturnStmt.Create(L, C,
      TASTMemberAccessExpr.Create(L, C,
        TASTIdentifierExpr.Create(L, C, EnumDecl.Name),
        TASTEnumVariant(EnumDecl.Variants[0]).Name
      )
    ));

  ImplDecl.Methods.Add(Func);
  AModule.Impls.Add(ImplDecl);
end;

procedure GenerateEnumClone(AModule: TASTModule; EnumDecl: TASTEnumDecl);
var
  ImplDecl: TASTImplDecl;
  Func: TASTFunction;
begin
  if HasImplMethod(AModule, EnumDecl.Name, 'Clone') then Exit;
  ImplDecl := TASTImplDecl.Create(EnumDecl.Line, EnumDecl.Col, 'Clone', EnumDecl.Name);
  Func := TASTFunction.Create(EnumDecl.Line, EnumDecl.Col, 'Clone', EnumDecl.Name);
  Func.Params.Add(TASTParam.Create(EnumDecl.Line, EnumDecl.Col, 'self', EnumDecl.Name, owBorrow));
  Func.Body.Add(TASTReturnStmt.Create(EnumDecl.Line, EnumDecl.Col,
    TASTIdentifierExpr.Create(EnumDecl.Line, EnumDecl.Col, 'self')
  ));
  ImplDecl.Methods.Add(Func);
  AModule.Impls.Add(ImplDecl);
end;

procedure GenerateEnumEquals(AModule: TASTModule; EnumDecl: TASTEnumDecl);
var
  ImplDecl: TASTImplDecl;
  Func: TASTFunction;
  EqExpr: TASTExpr;
begin
  if HasImplMethod(AModule, EnumDecl.Name, 'Equals') then Exit;
  ImplDecl := TASTImplDecl.Create(EnumDecl.Line, EnumDecl.Col, 'Equals', EnumDecl.Name);
  Func := TASTFunction.Create(EnumDecl.Line, EnumDecl.Col, 'Equals', 'Bool');
  Func.Params.Add(TASTParam.Create(EnumDecl.Line, EnumDecl.Col, 'self', EnumDecl.Name, owBorrow));
  Func.Params.Add(TASTParam.Create(EnumDecl.Line, EnumDecl.Col, 'other', EnumDecl.Name, owBorrow));

  EqExpr := TASTBinaryExpr.Create(EnumDecl.Line, EnumDecl.Col,
    TASTIdentifierExpr.Create(EnumDecl.Line, EnumDecl.Col, 'self'),
    '=',
    TASTIdentifierExpr.Create(EnumDecl.Line, EnumDecl.Col, 'other')
  );

  Func.Body.Add(TASTReturnStmt.Create(EnumDecl.Line, EnumDecl.Col, EqExpr));
  ImplDecl.Methods.Add(Func);
  AModule.Impls.Add(ImplDecl);
end;

procedure ExpandDerives(AModule: TASTModule);
var
  I: Integer;
  Node: TASTNode;
  RecDecl: TASTRecordDecl;
  EnumDecl: TASTEnumDecl;
  HasAnyDerives: Boolean;
begin
  if not Assigned(AModule) then Exit;

  HasAnyDerives := False;
  for I := 0 to AModule.Types.Count - 1 do
  begin
    Node := AModule.Types[I];
    if (Node is TASTRecordDecl) and (TASTRecordDecl(Node).Derives.Count > 0) then
    begin
      HasAnyDerives := True;
      Break;
    end
    else if (Node is TASTEnumDecl) and (TASTEnumDecl(Node).Derives.Count > 0) then
    begin
      HasAnyDerives := True;
      Break;
    end;
  end;

  if not HasAnyDerives then Exit;

  EnsureStandardTraits(AModule);

  // Process Enums first so Records with Enum fields can call ToString/ToJSON/FromJSON
  for I := 0 to AModule.Types.Count - 1 do
  begin
    Node := AModule.Types[I];
    if Node is TASTEnumDecl then
    begin
      EnumDecl := TASTEnumDecl(Node);
      if EnumDecl.HasDerive('Debug') then
        GenerateEnumDebug(AModule, EnumDecl);
      if EnumDecl.HasDerive('JSON') then
      begin
        GenerateEnumJSON(AModule, EnumDecl);
        GenerateEnumFromJSON(AModule, EnumDecl);
      end;
      if EnumDecl.HasDerive('Clone') then
        GenerateEnumClone(AModule, EnumDecl);
      if EnumDecl.HasDerive('Equals') then
        GenerateEnumEquals(AModule, EnumDecl);
    end;
  end;

  // Then process Records
  for I := 0 to AModule.Types.Count - 1 do
  begin
    Node := AModule.Types[I];
    if Node is TASTRecordDecl then
    begin
      RecDecl := TASTRecordDecl(Node);
      if RecDecl.HasDerive('Debug') then
        GenerateRecordStringFormat(AModule, RecDecl, False);
      if RecDecl.HasDerive('JSON') then
      begin
        GenerateRecordStringFormat(AModule, RecDecl, True);
        GenerateRecordFromJSON(AModule, RecDecl);
      end;
      if RecDecl.HasDerive('Clone') then
        GenerateRecordClone(AModule, RecDecl);
      if RecDecl.HasDerive('Equals') then
        GenerateRecordEquals(AModule, RecDecl);
    end;
  end;
end;

end.
