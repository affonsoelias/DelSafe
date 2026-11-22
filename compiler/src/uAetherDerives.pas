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
  T := LowerCase(AType);
  Result := (T = 'int32') or (T = 'int64') or (T = 'uint32') or (T = 'uint64') or
            (T = 'int16') or (T = 'uint16') or (T = 'int8') or (T = 'uint8') or (T = 'int');
end;

function IsFloatType(const AType: string): Boolean;
var
  T: string;
begin
  T := LowerCase(AType);
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

procedure GenerateRecordDebug(AModule: TASTModule; RecDecl: TASTRecordDecl);
var
  ImplDecl: TASTImplDecl;
  Func: TASTFunction;
  FullExpr, FieldValExpr: TASTExpr;
  F: TASTRecordField;
  I: Integer;
  CallExpr: TASTCallExpr;
begin
  ImplDecl := TASTImplDecl.Create(RecDecl.Line, RecDecl.Col, 'Debug', RecDecl.Name);
  Func := TASTFunction.Create(RecDecl.Line, RecDecl.Col, 'ToString', 'String');
  Func.Params.Add(TASTParam.Create(RecDecl.Line, RecDecl.Col, 'self', RecDecl.Name, owBorrow));

  if RecDecl.Fields.Count = 0 then
  begin
    FullExpr := TASTLiteralExpr.Create(RecDecl.Line, RecDecl.Col, lkString, RecDecl.Name + ' {}');
  end
  else
  begin
    FullExpr := TASTLiteralExpr.Create(RecDecl.Line, RecDecl.Col, lkString, RecDecl.Name + ' { ');
    for I := 0 to RecDecl.Fields.Count - 1 do
    begin
      F := TASTRecordField(RecDecl.Fields[I]);
      FullExpr := ConcatExpr(FullExpr, TASTLiteralExpr.Create(RecDecl.Line, RecDecl.Col, lkString, F.Name + ': '), RecDecl.Line, RecDecl.Col);

      if F.TypeName = 'String' then
      begin
        FieldValExpr := TASTBinaryExpr.Create(RecDecl.Line, RecDecl.Col,
          TASTLiteralExpr.Create(RecDecl.Line, RecDecl.Col, lkString, '"'),
          '+',
          TASTBinaryExpr.Create(RecDecl.Line, RecDecl.Col,
            TASTMemberAccessExpr.Create(RecDecl.Line, RecDecl.Col, TASTIdentifierExpr.Create(RecDecl.Line, RecDecl.Col, 'self'), F.Name),
            '+',
            TASTLiteralExpr.Create(RecDecl.Line, RecDecl.Col, lkString, '"')
          )
        );
      end
      else if IsIntegerType(F.TypeName) then
      begin
        CallExpr := TASTCallExpr.Create(RecDecl.Line, RecDecl.Col, 'IntToStr');
        CallExpr.Args.Add(TASTCallArg.Create(RecDecl.Line, RecDecl.Col, owNone,
          TASTMemberAccessExpr.Create(RecDecl.Line, RecDecl.Col, TASTIdentifierExpr.Create(RecDecl.Line, RecDecl.Col, 'self'), F.Name)
        ));
        FieldValExpr := CallExpr;
      end
      else if IsFloatType(F.TypeName) then
      begin
        CallExpr := TASTCallExpr.Create(RecDecl.Line, RecDecl.Col, 'FloatToStr');
        CallExpr.Args.Add(TASTCallArg.Create(RecDecl.Line, RecDecl.Col, owNone,
          TASTMemberAccessExpr.Create(RecDecl.Line, RecDecl.Col, TASTIdentifierExpr.Create(RecDecl.Line, RecDecl.Col, 'self'), F.Name)
        ));
        FieldValExpr := CallExpr;
      end
      else if F.TypeName = 'Bool' then
      begin
        CallExpr := TASTCallExpr.Create(RecDecl.Line, RecDecl.Col, 'BoolToStr');
        CallExpr.Args.Add(TASTCallArg.Create(RecDecl.Line, RecDecl.Col, owNone,
          TASTMemberAccessExpr.Create(RecDecl.Line, RecDecl.Col, TASTIdentifierExpr.Create(RecDecl.Line, RecDecl.Col, 'self'), F.Name)
        ));
        FieldValExpr := CallExpr;
      end
      else
      begin
        CallExpr := TASTCallExpr.Create(RecDecl.Line, RecDecl.Col, 'ToString');
        CallExpr.Args.Add(TASTCallArg.Create(RecDecl.Line, RecDecl.Col, owBorrow,
          TASTMemberAccessExpr.Create(RecDecl.Line, RecDecl.Col, TASTIdentifierExpr.Create(RecDecl.Line, RecDecl.Col, 'self'), F.Name)
        ));
        FieldValExpr := CallExpr;
      end;

      FullExpr := ConcatExpr(FullExpr, FieldValExpr, RecDecl.Line, RecDecl.Col);

      if I < RecDecl.Fields.Count - 1 then
        FullExpr := ConcatExpr(FullExpr, TASTLiteralExpr.Create(RecDecl.Line, RecDecl.Col, lkString, ', '), RecDecl.Line, RecDecl.Col);
    end;
    FullExpr := ConcatExpr(FullExpr, TASTLiteralExpr.Create(RecDecl.Line, RecDecl.Col, lkString, ' }'), RecDecl.Line, RecDecl.Col);
  end;

  Func.Body.Add(TASTReturnStmt.Create(RecDecl.Line, RecDecl.Col, FullExpr));
  ImplDecl.Methods.Add(Func);
  AModule.Impls.Add(ImplDecl);
end;

procedure GenerateRecordJSON(AModule: TASTModule; RecDecl: TASTRecordDecl);
var
  ImplDecl: TASTImplDecl;
  Func: TASTFunction;
  FullExpr, FieldValExpr: TASTExpr;
  F: TASTRecordField;
  I: Integer;
  CallExpr: TASTCallExpr;
begin
  ImplDecl := TASTImplDecl.Create(RecDecl.Line, RecDecl.Col, 'JSON', RecDecl.Name);
  Func := TASTFunction.Create(RecDecl.Line, RecDecl.Col, 'ToJSON', 'String');
  Func.Params.Add(TASTParam.Create(RecDecl.Line, RecDecl.Col, 'self', RecDecl.Name, owBorrow));

  if RecDecl.Fields.Count = 0 then
  begin
    FullExpr := TASTLiteralExpr.Create(RecDecl.Line, RecDecl.Col, lkString, '{}');
  end
  else
  begin
    FullExpr := TASTLiteralExpr.Create(RecDecl.Line, RecDecl.Col, lkString, '{');
    for I := 0 to RecDecl.Fields.Count - 1 do
    begin
      F := TASTRecordField(RecDecl.Fields[I]);
      FullExpr := ConcatExpr(FullExpr, TASTLiteralExpr.Create(RecDecl.Line, RecDecl.Col, lkString, '"' + F.Name + '": '), RecDecl.Line, RecDecl.Col);

      if F.TypeName = 'String' then
      begin
        FieldValExpr := TASTBinaryExpr.Create(RecDecl.Line, RecDecl.Col,
          TASTLiteralExpr.Create(RecDecl.Line, RecDecl.Col, lkString, '"'),
          '+',
          TASTBinaryExpr.Create(RecDecl.Line, RecDecl.Col,
            TASTMemberAccessExpr.Create(RecDecl.Line, RecDecl.Col, TASTIdentifierExpr.Create(RecDecl.Line, RecDecl.Col, 'self'), F.Name),
            '+',
            TASTLiteralExpr.Create(RecDecl.Line, RecDecl.Col, lkString, '"')
          )
        );
      end
      else if IsIntegerType(F.TypeName) then
      begin
        CallExpr := TASTCallExpr.Create(RecDecl.Line, RecDecl.Col, 'IntToStr');
        CallExpr.Args.Add(TASTCallArg.Create(RecDecl.Line, RecDecl.Col, owNone,
          TASTMemberAccessExpr.Create(RecDecl.Line, RecDecl.Col, TASTIdentifierExpr.Create(RecDecl.Line, RecDecl.Col, 'self'), F.Name)
        ));
        FieldValExpr := CallExpr;
      end
      else if IsFloatType(F.TypeName) then
      begin
        CallExpr := TASTCallExpr.Create(RecDecl.Line, RecDecl.Col, 'FloatToStr');
        CallExpr.Args.Add(TASTCallArg.Create(RecDecl.Line, RecDecl.Col, owNone,
          TASTMemberAccessExpr.Create(RecDecl.Line, RecDecl.Col, TASTIdentifierExpr.Create(RecDecl.Line, RecDecl.Col, 'self'), F.Name)
        ));
        FieldValExpr := CallExpr;
      end
      else if F.TypeName = 'Bool' then
      begin
        CallExpr := TASTCallExpr.Create(RecDecl.Line, RecDecl.Col, 'BoolToStr');
        CallExpr.Args.Add(TASTCallArg.Create(RecDecl.Line, RecDecl.Col, owNone,
          TASTMemberAccessExpr.Create(RecDecl.Line, RecDecl.Col, TASTIdentifierExpr.Create(RecDecl.Line, RecDecl.Col, 'self'), F.Name)
        ));
        FieldValExpr := CallExpr;
      end
      else
      begin
        CallExpr := TASTCallExpr.Create(RecDecl.Line, RecDecl.Col, 'ToJSON');
        CallExpr.Args.Add(TASTCallArg.Create(RecDecl.Line, RecDecl.Col, owBorrow,
          TASTMemberAccessExpr.Create(RecDecl.Line, RecDecl.Col, TASTIdentifierExpr.Create(RecDecl.Line, RecDecl.Col, 'self'), F.Name)
        ));
        FieldValExpr := CallExpr;
      end;

      FullExpr := ConcatExpr(FullExpr, FieldValExpr, RecDecl.Line, RecDecl.Col);

      if I < RecDecl.Fields.Count - 1 then
        FullExpr := ConcatExpr(FullExpr, TASTLiteralExpr.Create(RecDecl.Line, RecDecl.Col, lkString, ', '), RecDecl.Line, RecDecl.Col);
    end;
    FullExpr := ConcatExpr(FullExpr, TASTLiteralExpr.Create(RecDecl.Line, RecDecl.Col, lkString, '}'), RecDecl.Line, RecDecl.Col);
  end;

  Func.Body.Add(TASTReturnStmt.Create(RecDecl.Line, RecDecl.Col, FullExpr));
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
  EqExpr, FullExpr: TASTExpr;
  CallExpr: TASTCallExpr;
  F: TASTRecordField;
  I: Integer;
begin
  ImplDecl := TASTImplDecl.Create(RecDecl.Line, RecDecl.Col, 'Equals', RecDecl.Name);
  Func := TASTFunction.Create(RecDecl.Line, RecDecl.Col, 'Equals', 'Bool');
  Func.Params.Add(TASTParam.Create(RecDecl.Line, RecDecl.Col, 'self', RecDecl.Name, owBorrow));
  Func.Params.Add(TASTParam.Create(RecDecl.Line, RecDecl.Col, 'other', RecDecl.Name, owBorrow));

  if RecDecl.Fields.Count = 0 then
  begin
    FullExpr := TASTLiteralExpr.Create(RecDecl.Line, RecDecl.Col, lkBool, 'true');
  end
  else
  begin
    FullExpr := nil;
    for I := 0 to RecDecl.Fields.Count - 1 do
    begin
      F := TASTRecordField(RecDecl.Fields[I]);
      if not IsIntegerType(F.TypeName) and not IsFloatType(F.TypeName) and (F.TypeName <> 'Bool') and (F.TypeName <> 'String') then
      begin
        CallExpr := TASTCallExpr.Create(RecDecl.Line, RecDecl.Col, 'Equals');
        CallExpr.Args.Add(TASTCallArg.Create(RecDecl.Line, RecDecl.Col, owBorrow,
          TASTMemberAccessExpr.Create(RecDecl.Line, RecDecl.Col, TASTIdentifierExpr.Create(RecDecl.Line, RecDecl.Col, 'self'), F.Name)
        ));
        CallExpr.Args.Add(TASTCallArg.Create(RecDecl.Line, RecDecl.Col, owBorrow,
          TASTMemberAccessExpr.Create(RecDecl.Line, RecDecl.Col, TASTIdentifierExpr.Create(RecDecl.Line, RecDecl.Col, 'other'), F.Name)
        ));
        EqExpr := CallExpr;
      end
      else
      begin
        EqExpr := TASTBinaryExpr.Create(RecDecl.Line, RecDecl.Col,
          TASTMemberAccessExpr.Create(RecDecl.Line, RecDecl.Col, TASTIdentifierExpr.Create(RecDecl.Line, RecDecl.Col, 'self'), F.Name),
          '=',
          TASTMemberAccessExpr.Create(RecDecl.Line, RecDecl.Col, TASTIdentifierExpr.Create(RecDecl.Line, RecDecl.Col, 'other'), F.Name)
        );
      end;

      if not Assigned(FullExpr) then
        FullExpr := EqExpr
      else
        FullExpr := TASTBinaryExpr.Create(RecDecl.Line, RecDecl.Col, FullExpr, 'and', EqExpr);
    end;
  end;

  Func.Body.Add(TASTReturnStmt.Create(RecDecl.Line, RecDecl.Col, FullExpr));
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

procedure GenerateEnumClone(AModule: TASTModule; EnumDecl: TASTEnumDecl);
var
  ImplDecl: TASTImplDecl;
  Func: TASTFunction;
begin
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

  for I := 0 to AModule.Types.Count - 1 do
  begin
    Node := AModule.Types[I];
    if Node is TASTRecordDecl then
    begin
      RecDecl := TASTRecordDecl(Node);
      if RecDecl.HasDerive('Debug') then
        GenerateRecordDebug(AModule, RecDecl);
      if RecDecl.HasDerive('JSON') then
        GenerateRecordJSON(AModule, RecDecl);
      if RecDecl.HasDerive('Clone') then
        GenerateRecordClone(AModule, RecDecl);
      if RecDecl.HasDerive('Equals') then
        GenerateRecordEquals(AModule, RecDecl);
    end
    else if Node is TASTEnumDecl then
    begin
      EnumDecl := TASTEnumDecl(Node);
      if EnumDecl.HasDerive('Debug') then
        GenerateEnumDebug(AModule, EnumDecl);
      if EnumDecl.HasDerive('JSON') then
        GenerateEnumJSON(AModule, EnumDecl);
      if EnumDecl.HasDerive('Clone') then
        GenerateEnumClone(AModule, EnumDecl);
      if EnumDecl.HasDerive('Equals') then
        GenerateEnumEquals(AModule, EnumDecl);
    end;
  end;
end;

end.
