
Unit uDelSafeEmitterPascal;

{$mode objfpc}{$H+}

Interface

Uses 
SysUtils, Classes,
uDelSafeAST, uDelSafeToolchain;

Type 
  TDelSafeEmitterPascal = Class
    Private 
      FOutput: TStringList;
      FIndent: Integer;
      FModule: TASTModule;
      FCurrentFunc: TASTFunction;
      FProgramBlock: TASTProgramBlock;
      FActiveDefers: TFPList;
      FLoopDeferBase: Integer;
      FRaiiNames: TStringList;
      FRaiiTypes: TStringList;
      FLoopRaiiBase: Integer;
      FCurrentScopeList: TASTNodeList;
      FGuardBindNames: TStringList;
      FGuardBindExprs: TStringList;
      FMatchBindNames: TStringList;
      FMatchBindTargets: TStringList;
      FMatchBindTypes: TStringList;
      FDynTags: TStringList;
      FDynElems: TStringList;
      FFnTags: TStringList;
      FFnSigs: TStringList;
      FThunkFuncs: TStringList;
      FLambdas: TFPList;
      FTaskTags: TStringList;
      FTaskInners: TStringList;
      FChanTags: TStringList;
      FChanElems: TStringList;
      FSpawns: TFPList;
      FSpawnRefNames: TStringList;
      FSpawnRefTargets: TStringList;
      FToolchain: TToolchainInfo;
      FToolchainLoaded: Boolean;

      Function ResolvePascalExternLib(Const LibName: String): string;

      Procedure Emit(Const Line: String = '');
      Procedure IncIndent;
      Procedure DecIndent;
      Function IndentStr: string;
      Procedure EmitActiveDefers(DownToIndex: Integer = 0);
      Function FindFunction(Const AName: String): TASTFunction;
      Function FindDropFunc(Const ATypeName: String): TASTFunction;
      Function RaiiExprUsesVar(Expr: TASTExpr; Const AVarName: String): Boolean;
      Function IsNonBorrowArgCapture(Call: TASTCallExpr; ArgIdx: Integer):

                                                                         Boolean
      ;
      Function IsVarEscapedInStmts(Const AVarName: String; Stmts: TASTNodeList):

                                                                         Boolean
      ;
      Procedure RegisterRaiiVar(Const AVarName, ATypeName: String; ScopeStmts:
                                TASTNodeList);
      Procedure EmitRaiiCleanupFor(Const AVarName, ATypeName: String);
      Procedure EmitActiveRaii(DownToIndex: Integer = 0);
      Procedure EmitStmtList(List: TASTNodeList; IsLoopBody: Boolean = False);

      Function IsEnumName(Const AName: String): Boolean;
      Function FindEnumDecl(Const AName: String): TASTEnumDecl;
      Function FindEnumVariantUnqualified(Const AName: String; out Enm:
                                          TASTEnumDecl; out VarN:
                                          TASTEnumVariant): Boolean;
      Function IsRecordName(Const AName: String): Boolean;
      Function IsModulePrefixName(Const AName: String): Boolean;
      Function ResolveAliasType(Const AType: String): string;
      Function IsSetType(Const AName: String): Boolean;
      Function IsDynamicArrayType(Const AType: String): Boolean;
      Function IsValueOptionType(Const AType: String): Boolean;
      Function SplitResultTypes(Const AType: String; out ValType, ErrType:
                                String): Boolean;
      Function SplitFnType(Const AType: String; ParamTypes: TStringList; out
                           RetType: String): Boolean;
      Function FnTypeTag(Const AType: String): string;
      Procedure RegisterFnType(Const AType: String);
      Procedure RegisterLambda(Lambda: TASTLambdaExpr);
      Procedure RegisterThunkFunc(Const FuncName: String);
      Procedure EmitFnRuntimeHelpers(DeclOnly: Boolean);
      Procedure EmitLambdaAndThunkDecls(ForwardOnly: Boolean);
      Function RegisterTaskType(Const AType: String): string;
      Function RegisterChanType(Const AType: String; OptTags, OptInners:
                                TStrings): string;
      Procedure RegisterSpawn(Spawn: TASTSpawnExpr);
      Procedure EmitChanRuntimeHelpers(OptTags, OptInners: TStrings; DeclOnly:
                                       Boolean);
      Procedure EmitSpawnDecls(ForwardOnly: Boolean);
      Function MangleTypeTag(Const AType: String): string;
      Function IsCompoundMonadType(Const AType: String): Boolean;
      Function IsTypedValueOption(Const AType: String; out InnerT: String):

                                                                         Boolean
      ;
      Function IsTypedResult(Const AType: String; out ValT, ErrT: String):

                                                                         Boolean
      ;
      Function SafeUnwrapGeneric(Const AType, Prefix: String): string;
      Procedure PushMatchBindings(CaseNode: TASTMatchCase; Const MatchedType:
                                  String);
      Procedure PopMatchBindings(Count: Integer);
      Function GetMatchArmBindingCount(CaseNode: TASTMatchCase): Integer;
      Procedure GetMatchArmBindingInfo(CaseNode: TASTMatchCase; Idx: Integer;
                                       Const MatchedType: String;
                                       out BindName, TargetVar, BindType: String
      );
      Procedure CollectTypedMonadsFromType(Const AType: String; OptTags,
                                           OptInners, ResTags, ResVals, ResErrs:
                                           TStrings);
      Procedure CollectTypedMonadsFromExpr(Expr: TASTExpr; OptTags, OptInners,
                                           ResTags, ResVals, ResErrs: TStrings);
      Procedure CollectTypedMonadsFromStmts(Stmts: TASTNodeList; OptTags,
                                            OptInners, ResTags, ResVals, ResErrs
                                            : TStrings);
      Procedure CollectTypedMonadsFromModule(AModule: TASTModule; OptTags,
                                             OptInners, ResTags, ResVals,
                                             ResErrs: TStrings);
      Procedure EmitTypedOptionDecl(Const Tag, InnerT: String);
      Procedure EmitTypedResultDecl(Const Tag, ValT, ErrT: String);
      Procedure EmitTypedMonadHelpers(OptTags, OptInners, ResTags, ResVals,
                                      ResErrs: TStrings; DeclOnly: Boolean);
      Procedure EmitPayloadEnumConstructors(Enm: TASTEnumDecl; DeclOnly: Boolean
      );
      Procedure EmitTopologicalTypesAndMonads(Const TypeUsed: Array Of Boolean;
                                              OptTags, OptInners: TStrings;
                                              Const OptUsed: Array Of Boolean;
                                              ResTags, ResVals, ResErrs:
                                              TStrings; Const ResUsed: Array Of
                                              Boolean);
      Function IsTypeIdentifier(Const AName: String): Boolean;
      Function EmitMonadFieldExtract(Const ExprStr, FieldType, NumField,
                                     StrField: String): string;
      Procedure EmitArrayLiteralAssign(Const TargetStr, TargetType: String;
                                       SetLit: TASTSetLiteralExpr);
      Procedure EmitMapLiteralAssign(Const TargetStr, TargetType: String; MapLit
                                     : TASTMapLiteralExpr);
      Function IsMapType(Const AType: String; out KeyType, ValType: String):

                                                                         Boolean
      ;
      Function MapTag(Const K, V: String): string;
      Function NormalizeIntLit(Const Val: String): string;
      Function GetCollectionElemType(Expr: TASTExpr): string;
      Function IsBuiltinMapSideType(Const AType: String): Boolean;
      Function FindInlineVarType(Stmts: TASTNodeList; Const AName: String):

                                                                          string
      ;
      Procedure CollectAutoVarsFromExpr(Expr: TASTExpr; VarNames, VarTypes:
                                        TStrings; Const SkipNames: TStrings);
      Procedure CollectAutoVarsFromStmts(Stmts: TASTNodeList; VarNames, VarTypes
                                         : TStrings; Const SkipNames: TStrings);
      Procedure CollectMapsFromType(Const AType: String; Tags, Keys, Vals:
                                    TStrings);
      Procedure CollectMapsFromExpr(Expr: TASTExpr; Tags, Keys, Vals: TStrings);
      Procedure CollectMapsFromStmts(Stmts: TASTNodeList; Tags, Keys, Vals:
                                     TStrings);
      Procedure CollectMapsFromModule(AModule: TASTModule; Tags, Keys, Vals:
                                      TStrings);
      Procedure EmitMapRuntimeDecls(Tags, Keys, Vals: TStrings; BuiltinOnly:
                                    Boolean);
      Procedure EmitMapRuntimeHelpers(Tags, Keys, Vals: TStrings; DeclOnly:
                                      Boolean);
      Function EscapePascalString(Const S: String): string;
      Function EscapePascalChar(Const S: String): string;
      Function GetExprTypeName(Expr: TASTExpr): string;
      Function IsPointerTarget(Expr: TASTExpr): Boolean;
      Procedure BuildMatchCaseCond(CaseNode: TASTMatchCase; Const ExprStr,
                                   MatchedType: String;
                                   out CondStr, BindStmt, BindVarType: String;
                                   out IsWildcardArm: Boolean);

      Function EmitTypeRef(Const AType: String): string;
      Function EmitExpr(Expr: TASTExpr): string;
      Procedure EmitStmt(Stmt: TASTStmt);
      Procedure EmitRecordType(Rec: TASTRecordDecl);
      Procedure EmitRecordConstructor(Rec: TASTRecordDecl);
      Procedure EmitEnumDecl(Enm: TASTEnumDecl);
      Procedure EmitArrayDecl(Arr: TASTArrayDecl);
      Procedure EmitSetDecl(SetD: TASTSetDecl);
      Procedure EmitSubrangeDecl(SubR: TASTSubrangeDecl);
      Procedure EmitMapDecl(MapD: TASTMapDecl);
      Procedure EmitTypeAliasDecl(AliasD: TASTTypeAliasDecl);
      Procedure EmitFunction(Func: TASTFunction);
      Procedure EmitProgramBlock(Prog: TASTProgramBlock);

      Function BuildFuncSig(Func: TASTFunction): string;
      Function BuildRecordConstructorSig(Rec: TASTRecordDecl): string;
      Procedure EmitRuntimeTypeDecls(Const RefText: String; MapTags, MapKeys,
                                     MapVals: TStringList; AsUnit: Boolean;
                                     SkipCoreRuntime: Boolean = False);
      Procedure EmitRuntimeHelpersInterface(Const RefText: String);
      Procedure EmitRuntimeHelpersImplementation(Const RefText: String);
    Public 
      constructor Create;
      destructor Destroy;
      override;
      Function Generate(AModule: TASTModule; AsUnit: Boolean = False; AsLibrary:
                        Boolean = False; SharedRuntime: Boolean = False): string
      ;
      Class Function GenerateRuntimeUnit: string;
      End;

      Implementation

      constructor TDelSafeEmitterPascal.Create;
      Begin
        inherited Create;
        FOutput := TStringList.Create;
        FIndent := 0;
        FActiveDefers := TFPList.Create;
        FLoopDeferBase := 0;
        FRaiiNames := TStringList.Create;
        FRaiiTypes := TStringList.Create;
        FLoopRaiiBase := 0;
        FCurrentScopeList := Nil;
        FGuardBindNames := TStringList.Create;
        FGuardBindExprs := TStringList.Create;
        FMatchBindNames := TStringList.Create;
        FMatchBindTargets := TStringList.Create;
        FMatchBindTypes := TStringList.Create;
        FDynTags := TStringList.Create;
        FDynElems := TStringList.Create;
        FFnTags := TStringList.Create;
        FFnSigs := TStringList.Create;
        FThunkFuncs := TStringList.Create;
        FLambdas := TFPList.Create;
        FTaskTags := TStringList.Create;
        FTaskInners := TStringList.Create;
        FChanTags := TStringList.Create;
        FChanElems := TStringList.Create;
        FSpawns := TFPList.Create;
        FSpawnRefNames := TStringList.Create;
        FSpawnRefTargets := TStringList.Create;
        FToolchainLoaded := False;
      End;

      Function TDelSafeEmitterPascal.ResolvePascalExternLib(Const LibName: String
      ): string;
      Begin
        If Not FToolchainLoaded Then
          Begin
            FToolchain := DetectToolchain;
            FToolchainLoaded := True;
          End;
        Result := ResolveSystemLibDllName(LibName, FToolchain);
      End;

      destructor TDelSafeEmitterPascal.Destroy;
      Begin
        FSpawnRefTargets.Free;
        FSpawnRefNames.Free;
        FSpawns.Free;
        FChanElems.Free;
        FChanTags.Free;
        FTaskInners.Free;
        FTaskTags.Free;
        FLambdas.Free;
        FThunkFuncs.Free;
        FFnSigs.Free;
        FFnTags.Free;
        FDynElems.Free;
        FDynTags.Free;
        FMatchBindTypes.Free;
        FMatchBindTargets.Free;
        FMatchBindNames.Free;
        FGuardBindExprs.Free;
        FGuardBindNames.Free;
        FRaiiNames.Free;
        FRaiiTypes.Free;
        FActiveDefers.Free;
        FOutput.Free;
        inherited Destroy;
      End;

      Function TDelSafeEmitterPascal.IndentStr: string;
      Begin
        Result := StringOfChar(' ', FIndent * 2);
      End;

      Procedure TDelSafeEmitterPascal.Emit(Const Line: String);
      Begin
        If Line = '' Then
          FOutput.Add('')
        Else
          FOutput.Add(IndentStr + Line);
      End;

      Procedure TDelSafeEmitterPascal.IncIndent;
      Begin
        Inc(FIndent);
      End;

      Procedure TDelSafeEmitterPascal.DecIndent;
      Begin
        If FIndent > 0 Then
          Dec(FIndent);
      End;

      Function TDelSafeEmitterPascal.IsEnumName(Const AName: String): Boolean;
      Begin
        Result := Assigned(FindEnumDecl(AName));
      End;

      Function TDelSafeEmitterPascal.FindEnumDecl(Const AName: String):

                                                                    TASTEnumDecl
      ;

      Var 
        I: Integer;
      Begin
        Result := Nil;
        If Assigned(FModule) Then
          For I := 0 To FModule.Types.Count - 1 Do
            If (TASTNode(FModule.Types[I]) is TASTEnumDecl) And
               SameText(TASTEnumDecl(FModule.Types[I]).Name, AName) Then
              Exit(TASTEnumDecl(FModule.Types[I]));
      End;

      Function TDelSafeEmitterPascal.FindEnumVariantUnqualified(Const AName:
                                                               String; out Enm:
                                                               TASTEnumDecl; out
                                                               VarN:
                                                               TASTEnumVariant):

                                                                         Boolean
      ;

      Var 
        I, J: Integer;
        E: TASTEnumDecl;
      Begin
        Result := False;
        Enm := Nil;
        VarN := Nil;
        If Not Assigned(FModule) Then Exit;
        For I := 0 To FModule.Types.Count - 1 Do
          Begin
            If TASTNode(FModule.Types[I]) is TASTEnumDecl Then
              Begin
                E := TASTEnumDecl(FModule.Types[I]);
                For J := 0 To E.Variants.Count - 1 Do
                  If SameText(TASTEnumVariant(E.Variants[J]).Name, AName) Then
                    Begin
                      Enm := E;
                      VarN := TASTEnumVariant(E.Variants[J]);
                      Exit(True);
                    End;
              End;
          End;
      End;

      Function TDelSafeEmitterPascal.IsRecordName(Const AName: String): Boolean;

      Var 
        I: Integer;
      Begin
        Result := False;
        If Assigned(FModule) Then
          For I := 0 To FModule.Types.Count - 1 Do
            If (TASTNode(FModule.Types[I]) is TASTRecordDecl) And
               SameText(TASTRecordDecl(FModule.Types[I]).Name, AName) Then
              Exit(True);
      End;

      Function TDelSafeEmitterPascal.IsModulePrefixName(Const AName: String):

                                                                         Boolean
      ;

      Var 
        I: Integer;
        Imp, LastSeg: string;
      Begin
        Result := False;
        If Assigned(FCurrentFunc) Then
          Begin
            For I := 0 To FCurrentFunc.LocalVars.Count - 1 Do
              If SameText(TASTVarDecl(FCurrentFunc.LocalVars[I]).Name, AName)
                Then Exit(False);
            For I := 0 To FCurrentFunc.Params.Count - 1 Do
              If SameText(TASTParam(FCurrentFunc.Params[I]).Name, AName) Then
                Exit(False);
            If FindInlineVarType(FCurrentFunc.Body, AName) <> '' Then Exit(False
              );
          End;
        If Assigned(FProgramBlock) Then
          Begin
            For I := 0 To FProgramBlock.LocalVars.Count - 1 Do
              If SameText(TASTVarDecl(FProgramBlock.LocalVars[I]).Name, AName)
                Then Exit(False);
            If FindInlineVarType(FProgramBlock.Body, AName) <> '' Then Exit(

                                                                           False
              );
          End;
        If IsTypeIdentifier(AName) Then Exit(False);

        If Assigned(FModule) And Assigned(FModule.ImportAliases) And (FModule.
           ImportAliases.Values[AName] <> '') Then
          Exit(True);

        If Assigned(FModule) And Assigned(FModule.Imports) Then
          Begin
            For I := 0 To FModule.Imports.Count - 1 Do
              Begin
                Imp := FModule.Imports[I];
                LastSeg := Imp;
                If Pos('.', LastSeg) > 0 Then
                  LastSeg := Copy(LastSeg, LastDelimiter('.', LastSeg) + 1,
                             Length(LastSeg));
                If SameText(AName, Imp) Or SameText(AName, LastSeg) Then
                  Exit(True);
              End;
          End;
      End;

      Function TDelSafeEmitterPascal.EscapePascalString(Const S: String): string;

      Var 
        I: Integer;
        InQuotes: Boolean;
      Begin
        Result := '';
        InQuotes := False;
        For I := 1 To Length(S) Do
          Begin
            If S[I] In [#0..#31, #127] Then
              Begin
                If InQuotes Then
                  Begin
                    Result := Result + '''';
                    InQuotes := False;
                  End;
                Result := Result + '#' + IntToStr(Ord(S[I]));
              End
            Else
              Begin
                If Not InQuotes Then
                  Begin
                    Result := Result + '''';
                    InQuotes := True;
                  End;
                If S[I] = '''' Then
                  Result := Result + ''''''
                Else
                  Result := Result + S[I];
              End;
          End;
        If InQuotes Then
          Result := Result + '''';
        If Result = '' Then
          Result := '''''';
      End;

      Function TDelSafeEmitterPascal.EscapePascalChar(Const S: String): string;
      Begin
        If Length(S) = 0 Then Exit('#0');
        If S[1] In [#0..#31, #127] Then
          Result := '#' + IntToStr(Ord(S[1]))
        Else If S[1] = '''' Then
               Result := ''''''''''
        Else
          Result := '''' + S[1] + '''';
      End;

      Function IsIntegerType(Const AType: String): Boolean;
      Begin
        Result := (AType = 'Int8') Or (AType = 'Int16') Or (AType = 'Int32') Or
                  (AType = 'Int64') Or
                  (AType = 'UInt8') Or (AType = 'UInt16') Or (AType = 'UInt32')
                  Or (AType = 'UInt64') Or
                  (AType = 'IntLiteral');
      End;

      Function TDelSafeEmitterPascal.ResolveAliasType(Const AType: String):

                                                                          string
      ;

      Var 
        Cur: string;
        Hops, I: Integer;
      Begin
        Cur := Trim(AType);
        Hops := 0;
        While (Hops < 8) And Assigned(FModule) Do
          Begin
            I := 0;
            While I < FModule.Types.Count Do
              Begin
                If (FModule.Types[I] is TASTTypeAliasDecl) And SameText(
                   TASTTypeAliasDecl(FModule.Types[I]).Name, Cur) Then
                  Begin
                    Cur := Trim(TASTTypeAliasDecl(FModule.Types[I]).TargetType);
                    Inc(Hops);
                    Break;
                  End;
                Inc(I);
              End;
            If I >= FModule.Types.Count Then Break;
          End;
        Result := Cur;
      End;

      Function TDelSafeEmitterPascal.IsSetType(Const AName: String): Boolean;

      Var 
        I: Integer;
        T: string;
      Begin
        T := ResolveAliasType(AName);
        If Pos('set of', T) > 0 Then Exit(True);
        If Assigned(FModule) Then
          For I := 0 To FModule.Types.Count - 1 Do
            If (FModule.Types[I] is TASTSetDecl) And SameText(TASTSetDecl(
               FModule.Types[I]).Name, T) Then
              Exit(True);
        Result := False;
      End;

      Function TDelSafeEmitterPascal.IsDynamicArrayType(Const AType: String):

                                                                         Boolean
      ;

      Var 
        I: Integer;
        T: string;
      Begin
        T := ResolveAliasType(AType);
        If Pos('array of ', T) = 1 Then Exit(True);
        If Assigned(FModule) Then
          For I := 0 To FModule.Types.Count - 1 Do
            If (FModule.Types[I] is TASTArrayDecl) And SameText(TASTArrayDecl(
               FModule.Types[I]).Name, T) And
               (TASTArrayDecl(FModule.Types[I]).Dims.Count = 0) Then
              Exit(True);
        Result := False;
      End;

      Function TDelSafeEmitterPascal.IsValueOptionType(Const AType: String):

                                                                         Boolean
      ;

      Var 
        T, Inner: string;
      Begin
        T := ResolveAliasType(AType);
        If Pos('Option<', T) <> 1 Then Exit(False);
        Inner := ResolveAliasType(Trim(Copy(T, 8, Length(T) - 8)));
        Result := (Inner <> '') And (Pos('Box<', Inner) <> 1) And (Pos('^',
                  Inner) <> 1) And (Inner <> 'Pointer');
      End;

      Function TDelSafeEmitterPascal.SplitResultTypes(Const AType: String; out
                                                     ValType, ErrType: String):

                                                                         Boolean
      ;

      Var 
        T, Inner: string;
        I, Depth, CommaPos: Integer;
      Begin
        ValType := 'Float64';
        ErrType := 'Int32';
        T := ResolveAliasType(AType);
        If Pos('Result<', T) <> 1 Then Exit(False);
        Inner := Copy(T, 8, Length(T) - 8);
        Depth := 0;
        CommaPos := 0;
        For I := 1 To Length(Inner) Do
          Begin
            If Inner[I] = '<' Then Inc(Depth)
            Else If Inner[I] = '>' Then Dec(Depth)
            Else If (Inner[I] = ',') And (Depth = 0) Then
                   Begin
                     CommaPos := I;
                     Break;
                   End;
          End;
        If CommaPos > 0 Then
          Begin
            ValType := Trim(Copy(Inner, 1, CommaPos - 1));
            ErrType := Trim(Copy(Inner, CommaPos + 1, Length(Inner)));
            Exit(True);
          End;
        Result := False;
      End;

      Function TDelSafeEmitterPascal.SafeUnwrapGeneric(Const AType, Prefix:
                                                      String): string;

      Var 
        T, Pre: string;
      Begin
        T := Trim(AType);
        Pre := Prefix + '<';
        If (Pos(Pre, T) = 1) And (Length(T) > Length(Pre)) And (T[Length(T)] =
           '>') Then
          Result := Trim(Copy(T, Length(Pre) + 1, Length(T) - Length(Pre) - 1))
        Else
          Result := '';
      End;

      Function TDelSafeEmitterPascal.SplitFnType(Const AType: String; ParamTypes:
                                                TStringList; out RetType: String
      ): Boolean;

      Var 
        T, Inner, Cur, AfterParen: string;
        I, DepthParen, DepthAngle, DepthBracket, ClosePos: Integer;
      Begin
        Result := False;
        ParamTypes.Clear;
        RetType := 'Void';
        T := Trim(AType);
        If Pos('fn(', T) <> 1 Then Exit;
        DepthParen := 0;
        ClosePos := 0;
        For I := 3 To Length(T) Do
          Begin
            If T[I] = '(' Then Inc(DepthParen)
            Else If T[I] = ')' Then
                   Begin
                     Dec(DepthParen);
                     If DepthParen = 0 Then
                       Begin
                         ClosePos := I;
                         Break;
                       End;
                   End;
          End;
        If ClosePos = 0 Then Exit;
        AfterParen := Trim(Copy(T, ClosePos + 1, Length(T)));
        If Pos('->', AfterParen) <> 1 Then Exit;
        RetType := Trim(Copy(AfterParen, 3, Length(AfterParen)));
        Inner := Trim(Copy(T, 4, ClosePos - 4));
        If Inner <> '' Then
          Begin
            DepthParen := 0;
            DepthAngle := 0;
            DepthBracket := 0;
            Cur := '';
            For I := 1 To Length(Inner) Do
              Begin
                Case Inner[I] Of 
                  '<': Inc(DepthAngle);
                  '>': Dec(DepthAngle);
                  '(': Inc(DepthParen);
                  ')': Dec(DepthParen);
                  '[': Inc(DepthBracket);
                  ']': Dec(DepthBracket);
                End;
                If (Inner[I] = ',') And (DepthAngle = 0) And (DepthParen = 0)
                   And (DepthBracket = 0) Then
                  Begin
                    ParamTypes.Add(Trim(Cur));
                    Cur := '';
                  End
                Else
                  Cur := Cur + Inner[I];
              End;
            If Trim(Cur) <> '' Then ParamTypes.Add(Trim(Cur));
          End;
        Result := RetType <> '';
      End;

      Function TDelSafeEmitterPascal.FnTypeTag(Const AType: String): string;

      Var 
        Params: TStringList;
        RetT: string;
        I: Integer;
      Begin
        Params := TStringList.Create;
        Try
          If SplitFnType(AType, Params, RetT) Then
            Begin
              If Params.Count = 0 Then
                Result := 'void'
              Else
                Begin
                  Result := '';
                  For I := 0 To Params.Count - 1 Do
                    Begin
                      If I > 0 Then Result := Result + '_';
                      Result := Result + MangleTypeTag(Params[I]);
                    End;
                End;
              Result := Result + '__ret__' + MangleTypeTag(RetT);
            End
          Else
            Result := 'unknown';
        Finally
          Params.Free;
      End;
  End;

Procedure TDelSafeEmitterPascal.RegisterFnType(Const AType: String);

Var 
  T, Tag: string;
Begin
  T := ResolveAliasType(Trim(AType));
  If Pos('fn(', T) <> 1 Then Exit;
  Tag := FnTypeTag(T);
  If FFnTags.IndexOf(Tag) < 0 Then
    Begin
      FFnTags.Add(Tag);
      FFnSigs.Add(T);
    End;
End;

Procedure TDelSafeEmitterPascal.RegisterLambda(Lambda: TASTLambdaExpr);
Begin
  If Assigned(Lambda) And (FLambdas.IndexOf(Lambda) < 0) Then
    FLambdas.Add(Lambda);
End;

Procedure TDelSafeEmitterPascal.RegisterThunkFunc(Const FuncName: String);
Begin
  If (FuncName <> '') And (FThunkFuncs.IndexOf(FuncName) < 0) Then
    FThunkFuncs.Add(FuncName);
End;

Function TDelSafeEmitterPascal.RegisterTaskType(Const AType: String): string;

Var 
  T, InnerT, Tag: string;
Begin
  T := ResolveAliasType(Trim(AType));
  If (Copy(T, 1, 5) <> 'Task<') Or (T[Length(T)] <> '>') Then Exit('');
  InnerT := Trim(Copy(T, 6, Length(T) - 6));
  If InnerT = '' Then InnerT := 'Void';
  Tag := MangleTypeTag(InnerT);
  If FTaskTags.IndexOf(Tag) < 0 Then
    Begin
      FTaskTags.Add(Tag);
      FTaskInners.Add(InnerT);
    End;
  Result := Tag;
End;

Function TDelSafeEmitterPascal.RegisterChanType(Const AType: String; OptTags,
                                               OptInners: TStrings): string;

Var 
  T, ElemT, Tag, OptTag: string;
Begin
  T := ResolveAliasType(Trim(AType));
  If (Copy(T, 1, 8) <> 'Channel<') Or (T[Length(T)] <> '>') Then Exit('');
  ElemT := Trim(Copy(T, 9, Length(T) - 9));
  If ElemT = '' Then ElemT := 'Int32';
  Tag := MangleTypeTag(ElemT);
  If FChanTags.IndexOf(Tag) < 0 Then
    Begin
      FChanTags.Add(Tag);
      FChanElems.Add(ElemT);
    End;
  If Assigned(OptTags) And Assigned(OptInners) And IsTypedValueOption('Option<'
     + ElemT + '>', ElemT) Then
    Begin
      OptTag := MangleTypeTag(ElemT);
      If OptTags.IndexOf(OptTag) < 0 Then
        Begin
          OptTags.Add(OptTag);
          OptInners.Add(ElemT);
        End;
    End;
  Result := Tag;
End;

Procedure TDelSafeEmitterPascal.RegisterSpawn(Spawn: TASTSpawnExpr);
Begin
  If Assigned(Spawn) And (FSpawns.IndexOf(Spawn) < 0) Then
    FSpawns.Add(Spawn);
End;

Function TDelSafeEmitterPascal.MangleTypeTag(Const AType: String): string;

Var 
  T, ValT, ErrT, InnerT, Res: string;
  I: Integer;
  Ch: Char;
Begin
  T := ResolveAliasType(Trim(AType));
  If T = '' Then Exit('Void');
  If Pos('fn(', T) = 1 Then
    Exit('Fn__' + FnTypeTag(T));
  If (Copy(T, 1, 5) = 'Task<') And (T[Length(T)] = '>') Then
    Exit('Task__' + MangleTypeTag(Copy(T, 6, Length(T) - 6)));
  If (Copy(T, 1, 8) = 'Channel<') And (T[Length(T)] = '>') Then
    Exit('Chan__' + MangleTypeTag(Copy(T, 9, Length(T) - 9)));
  If Pos('^', T) = 1 Then
    Exit('ptr_' + MangleTypeTag(Copy(T, 2, Length(T))));
  If Pos('array of ', T) = 1 Then
    Exit('arr_' + MangleTypeTag(Copy(T, 10, Length(T))));
  If SplitResultTypes(T, ValT, ErrT) Then
    Exit('Result__' + MangleTypeTag(ValT) + '__' + MangleTypeTag(ErrT));
  If Pos('Option<', T) = 1 Then
    Begin
      InnerT := SafeUnwrapGeneric(T, 'Option');
      If InnerT <> '' Then
        Exit('Option__' + MangleTypeTag(InnerT));
    End;
  If Pos('Box<', T) = 1 Then
    Begin
      InnerT := SafeUnwrapGeneric(T, 'Box');
      If InnerT <> '' Then
        Exit('Box__' + MangleTypeTag(InnerT));
    End;
  Res := '';
  For I := 1 To Length(T) Do
    Begin
      Ch := T[I];
      If Ch In ['A'..'Z', 'a'..'z', '0'..'9', '_'] Then
        Res := Res + Ch
      Else If (Res = '') Or (Res[Length(Res)] <> '_') Then
             Res := Res + '_';
    End;
  Result := Res;
End;

Function TDelSafeEmitterPascal.IsCompoundMonadType(Const AType: String): Boolean;

Var 
  T, K, V: string;
  I: Integer;
  Enm: TASTEnumDecl;
Begin
  T := ResolveAliasType(Trim(AType));
  If (T = '') Or (T = 'IntLiteral') Or (T = 'FloatLiteral') Or
     (T = 'GenericValue') Or (T = 'GenericError') Or (T = 'GenericNone') Or
     (T = 'Int8') Or (T = 'Int16') Or (T = 'Int32') Or (T = 'Int64') Or
     (T = 'UInt8') Or (T = 'UInt16') Or (T = 'UInt32') Or (T = 'UInt64') Or
     (T = 'Float32') Or (T = 'Float64') Or (T = 'Bool') Or (T = 'Char') Or
     (T = 'String') Or (T = 'Pointer') Or (Pos('^', T) = 1) Or (Pos('Box<', T) =
     1) Then
    Exit(False);

  If (Pos('array of ', T) = 1) Or (Pos('array[', T) = 1) Or (Pos('fn(', T) = 1)
     Or
     (Pos('Task<', T) = 1) Or (Pos('Channel<', T) = 1) Or
     (Pos('Option<', T) = 1) Or (Pos('Result<', T) = 1) Or IsMapType(T, K, V)
    Then
    Exit(True);

  Enm := FindEnumDecl(T);
  If Assigned(Enm) Then
    Exit(Enm.HasPayload);

  If Assigned(FModule) Then
    Begin
      For I := 0 To FModule.Types.Count - 1 Do
        Begin
          If (TASTNode(FModule.Types[I]) is TASTRecordDecl) And SameText(
             TASTRecordDecl(FModule.Types[I]).Name, T) Then
            Exit(True);
          If (TASTNode(FModule.Types[I]) is TASTArrayDecl) And SameText(
             TASTArrayDecl(FModule.Types[I]).Name, T) Then
            Exit(True);
        End;
    End;
  Result := False;
End;

Function TDelSafeEmitterPascal.IsTypedValueOption(Const AType: String; out InnerT
                                                 : String): Boolean;

Var 
  T: string;
Begin
  InnerT := '';
  If Not IsValueOptionType(AType) Then Exit(False);
  T := ResolveAliasType(AType);
  InnerT := ResolveAliasType(SafeUnwrapGeneric(T, 'Option'));
  If (InnerT = '') Or (InnerT = 'GenericNone') Or (InnerT = 'IntLiteral') Or (
     InnerT = 'FloatLiteral') Then
    Exit(False);
  Result := IsCompoundMonadType(InnerT) Or IsEnumName(InnerT);
End;

Function TDelSafeEmitterPascal.IsTypedResult(Const AType: String; out ValT, ErrT:
                                            String): Boolean;
Begin
  If Not SplitResultTypes(AType, ValT, ErrT) Then Exit(False);
  ValT := ResolveAliasType(ValT);
  ErrT := ResolveAliasType(ErrT);
  If (ValT = 'GenericValue') Or (ErrT = 'GenericError') Or (ValT = 'IntLiteral')
     Or (ValT = 'FloatLiteral') Then
    Exit(False);
  Result := IsCompoundMonadType(ValT) Or IsCompoundMonadType(ErrT);
End;

Function TDelSafeEmitterPascal.GetMatchArmBindingCount(CaseNode: TASTMatchCase):

                                                                         Integer
;
Begin
  If CaseNode.Pattern.Bindings.Count > 0 Then
    Result := CaseNode.Pattern.Bindings.Count
  Else If CaseNode.Pattern.IsLet And (CaseNode.Pattern.SubPattern <> '') Then
         Result := 1
  Else
    Result := 0;
End;

Procedure TDelSafeEmitterPascal.GetMatchArmBindingInfo(CaseNode: TASTMatchCase;
                                                      Idx: Integer; Const
                                                      MatchedType: String;
                                                      out BindName, TargetVar,
                                                      BindType: String);

Var 
  PatStr, ValF, ErrF, EnmName, VarName: string;
  PDot: Integer;
  Enm: TASTEnumDecl;
  VarN: TASTEnumVariant;
  J: Integer;
Begin
  If CaseNode.Pattern.Bindings.Count > 0 Then
    BindName := CaseNode.Pattern.Bindings[Idx]
  Else
    BindName := CaseNode.Pattern.SubPattern;

  TargetVar := Format('_mb_%d_%d_%s', [CaseNode.Line, CaseNode.Col, BindName]);
  BindType := MatchedType;
  PatStr := CaseNode.Pattern.Value;

  If PatStr = '_' Then
    BindType := MatchedType
  Else If Pos('Ok', PatStr) = 1 Then
         Begin
           SplitResultTypes(MatchedType, ValF, ErrF);
           BindType := ValF;
         End
  Else If Pos('Err', PatStr) = 1 Then
         Begin
           SplitResultTypes(MatchedType, ValF, ErrF);
           BindType := ErrF;
         End
  Else If PatStr = 'Some' Then
         Begin
           BindType := SafeUnwrapGeneric(MatchedType, 'Option');
           If BindType = '' Then BindType := 'Int32';
         End
  Else
    Begin
      Enm := FindEnumDecl(MatchedType);
      If Assigned(Enm) And Enm.HasPayload Then
        Begin
          EnmName := PatStr;
          PDot := Pos('.', EnmName);
          If PDot > 0 Then VarName := Copy(EnmName, PDot + 1, Length(EnmName))
          Else VarName := EnmName;
          For J := 0 To Enm.Variants.Count - 1 Do
            Begin
              VarN := TASTEnumVariant(Enm.Variants[J]);
              If SameText(VarN.Name, VarName) And (Idx < VarN.Fields.Count) Then
                Begin
                  BindType := TASTRecordField(VarN.Fields[Idx]).TypeName;
                  Break;
                End;
            End;
        End;
    End;
End;

Procedure TDelSafeEmitterPascal.PushMatchBindings(CaseNode: TASTMatchCase; Const
                                                 MatchedType: String);

Var 
  I, Cnt: Integer;
  BName, TVar, BType: string;
Begin
  Cnt := GetMatchArmBindingCount(CaseNode);
  For I := 0 To Cnt - 1 Do
    Begin
      GetMatchArmBindingInfo(CaseNode, I, MatchedType, BName, TVar, BType);
      If (BName <> '') And (BName <> '_') Then
        Begin
          FMatchBindNames.Add(BName);
          FMatchBindTargets.Add(TVar);
          FMatchBindTypes.Add(BType);
        End;
    End;
End;

Procedure TDelSafeEmitterPascal.PopMatchBindings(Count: Integer);

Var 
  I: Integer;
Begin
  For I := 1 To Count Do
    Begin
      If FMatchBindNames.Count > 0 Then
        Begin
          FMatchBindNames.Delete(FMatchBindNames.Count - 1);
          FMatchBindTargets.Delete(FMatchBindTargets.Count - 1);
          FMatchBindTypes.Delete(FMatchBindTypes.Count - 1);
        End;
    End;
End;

Procedure TDelSafeEmitterPascal.CollectTypedMonadsFromType(Const AType: String;
                                                          OptTags, OptInners,
                                                          ResTags, ResVals,
                                                          ResErrs: TStrings);

Var 
  T, InnerT, ValT, ErrT, Tag, KeyT, ValM, RetT: string;
  FnParams: TStringList;
  K: Integer;
Begin
  T := ResolveAliasType(Trim(AType));
  If T = '' Then Exit;
  FnParams := TStringList.Create;
  Try
    If SplitFnType(T, FnParams, RetT) Then
      Begin
        For K := 0 To FnParams.Count - 1 Do
          CollectTypedMonadsFromType(FnParams[K], OptTags, OptInners, ResTags,
                                     ResVals, ResErrs);
        If (RetT <> '') And (Not SameText(RetT, 'Void')) Then
          CollectTypedMonadsFromType(RetT, OptTags, OptInners, ResTags, ResVals,
                                     ResErrs);
        RegisterFnType(T);
        Exit;
      End;
  Finally
    FnParams.Free;
End;
If Pos('^', T) = 1 Then
  Begin
    CollectTypedMonadsFromType(Copy(T, 2, Length(T)), OptTags, OptInners,
    ResTags, ResVals, ResErrs);
    Exit;
  End;
If Pos('array of ', T) = 1 Then
  Begin
    InnerT := Trim(Copy(T, 10, Length(T)));
    CollectTypedMonadsFromType(InnerT, OptTags, OptInners, ResTags, ResVals,
                               ResErrs);
    If Not ((InnerT = 'Int8') Or (InnerT = 'Int16') Or (InnerT = 'Int32') Or (
       InnerT = 'Int64') Or
       (InnerT = 'UInt8') Or (InnerT = 'UInt16') Or (InnerT = 'UInt32') Or (
       InnerT = 'UInt64') Or
       (InnerT = 'Float32') Or (InnerT = 'Float64') Or (InnerT = 'Bool') Or (
       InnerT = 'Char') Or
       (InnerT = 'String') Or (InnerT = 'Pointer')) Then
      Begin
        Tag := MangleTypeTag(InnerT);
        If Assigned(FDynTags) And (FDynTags.IndexOf(Tag) = -1) Then
          Begin
            FDynTags.Add(Tag);
            FDynElems.Add(InnerT);
          End;
      End;
    Exit;
  End;
If IsMapType(T, KeyT, ValM) Then
  Begin
    CollectTypedMonadsFromType(KeyT, OptTags, OptInners, ResTags, ResVals,
                               ResErrs);
    CollectTypedMonadsFromType(ValM, OptTags, OptInners, ResTags, ResVals,
                               ResErrs);
    Exit;
  End;
If (Copy(T, 1, 5) = 'Task<') And (T[Length(T)] = '>') Then
  Begin
    InnerT := Trim(Copy(T, 6, Length(T) - 6));
    If InnerT = '' Then InnerT := 'Void';
    If Not SameText(InnerT, 'Void') Then
      CollectTypedMonadsFromType(InnerT, OptTags, OptInners, ResTags, ResVals,
                                 ResErrs);
    RegisterTaskType('Task<' + InnerT + '>');
    Exit;
  End;
If (Copy(T, 1, 8) = 'Channel<') And (T[Length(T)] = '>') Then
  Begin
    InnerT := Trim(Copy(T, 9, Length(T) - 9));
    If InnerT = '' Then InnerT := 'Int32';
    CollectTypedMonadsFromType(InnerT, OptTags, OptInners, ResTags, ResVals,
                               ResErrs);
    CollectTypedMonadsFromType('Option<' + InnerT + '>', OptTags, OptInners,
                               ResTags, ResVals, ResErrs);
    RegisterChanType('Channel<' + InnerT + '>', OptTags, OptInners);
    Exit;
  End;
If IsTypedValueOption(T, InnerT) Then
  Begin
    CollectTypedMonadsFromType(InnerT, OptTags, OptInners, ResTags, ResVals,
                               ResErrs);
    Tag := MangleTypeTag(InnerT);
    If OptTags.IndexOf(Tag) = -1 Then
      Begin
        OptTags.Add(Tag);
        OptInners.Add(InnerT);
      End;
  End
Else If IsTypedResult(T, ValT, ErrT) Then
       Begin
         CollectTypedMonadsFromType(ValT, OptTags, OptInners, ResTags, ResVals,
                                    ResErrs);
         CollectTypedMonadsFromType(ErrT, OptTags, OptInners, ResTags, ResVals,
                                    ResErrs);
         Tag := MangleTypeTag(ValT) + '__' + MangleTypeTag(ErrT);
         If ResTags.IndexOf(Tag) = -1 Then
           Begin
             ResTags.Add(Tag);
             ResVals.Add(ValT);
             ResErrs.Add(ErrT);
           End;
       End;
End;

Procedure TDelSafeEmitterPascal.CollectTypedMonadsFromExpr(Expr: TASTExpr;
                                                          OptTags, OptInners,
                                                          ResTags, ResVals,
                                                          ResErrs: TStrings);

Var 
  I, Cnt, AddedB: Integer;
  Call: TASTCallExpr;
  ME: TASTMatchExpr;
  CaseN: TASTMatchCase;
  MT, BName, TVar, BType: string;
Begin
  If Not Assigned(Expr) Then Exit;
  If Expr is TASTIdentifierExpr Then
    Begin
      If TASTIdentifierExpr(Expr).IsFnValueRef Then
        Begin
          CollectTypedMonadsFromType(TASTIdentifierExpr(Expr).ResolvedFnType,
          OptTags, OptInners, ResTags, ResVals, ResErrs);
          RegisterThunkFunc(TASTIdentifierExpr(Expr).Name);
        End;
      If TASTIdentifierExpr(Expr).ResolvedMonadType <> '' Then
        CollectTypedMonadsFromType(TASTIdentifierExpr(Expr).ResolvedMonadType,
        OptTags, OptInners, ResTags, ResVals, ResErrs);
    End
  Else If Expr is TASTTupleLiteralExpr Then
         Begin
           CollectTypedMonadsFromType(TASTTupleLiteralExpr(Expr).ResolvedType,
           OptTags, OptInners, ResTags, ResVals, ResErrs);
           For I := 0 To TASTTupleLiteralExpr(Expr).Elements.Count - 1 Do
             CollectTypedMonadsFromExpr(TASTExpr(TASTTupleLiteralExpr(Expr).
             Elements[I]), OptTags, OptInners, ResTags, ResVals, ResErrs);
         End
  Else If Expr is TASTLambdaExpr Then
         Begin
           CollectTypedMonadsFromType(TASTLambdaExpr(Expr).ResolvedFnType,
           OptTags, OptInners, ResTags, ResVals, ResErrs);
           RegisterLambda(TASTLambdaExpr(Expr));
           For I := 0 To TASTLambdaExpr(Expr).CaptureTypes.Count - 1 Do
             CollectTypedMonadsFromType(TASTLambdaExpr(Expr).CaptureTypes[I],
             OptTags, OptInners, ResTags, ResVals, ResErrs);
           If Assigned(TASTLambdaExpr(Expr).BodyExpr) Then
             CollectTypedMonadsFromExpr(TASTLambdaExpr(Expr).BodyExpr, OptTags,
             OptInners, ResTags, ResVals, ResErrs)
           Else
             CollectTypedMonadsFromStmts(TASTLambdaExpr(Expr).BodyStmts, OptTags
             , OptInners, ResTags, ResVals, ResErrs);
         End
  Else If Expr is TASTMemberAccessExpr Then
         CollectTypedMonadsFromExpr(TASTMemberAccessExpr(Expr).Target, OptTags,
         OptInners, ResTags, ResVals, ResErrs)
  Else If Expr is TASTBinaryExpr Then
         Begin
           CollectTypedMonadsFromExpr(TASTBinaryExpr(Expr).Left, OptTags,
           OptInners, ResTags, ResVals, ResErrs);
           CollectTypedMonadsFromExpr(TASTBinaryExpr(Expr).Right, OptTags,
           OptInners, ResTags, ResVals, ResErrs);
         End
  Else If Expr is TASTUnaryExpr Then
         Begin
           If TASTUnaryExpr(Expr).Op = '?' Then
             CollectTypedMonadsFromType(GetExprTypeName(TASTUnaryExpr(Expr).Expr
             ), OptTags, OptInners, ResTags, ResVals, ResErrs);
           CollectTypedMonadsFromExpr(TASTUnaryExpr(Expr).Expr, OptTags,
           OptInners, ResTags, ResVals, ResErrs);
         End
  Else If Expr is TASTAwaitExpr Then
         Begin
           CollectTypedMonadsFromExpr(TASTAwaitExpr(Expr).Expr, OptTags,
           OptInners, ResTags, ResVals, ResErrs);
           CollectTypedMonadsFromType(GetExprTypeName(TASTAwaitExpr(Expr).Expr),
           OptTags, OptInners, ResTags, ResVals, ResErrs);
         End
  Else If Expr is TASTSpawnExpr Then
         Begin
           RegisterSpawn(TASTSpawnExpr(Expr));
           If TASTSpawnExpr(Expr).ResolvedTaskType <> '' Then
             CollectTypedMonadsFromType(TASTSpawnExpr(Expr).ResolvedTaskType,
             OptTags, OptInners, ResTags, ResVals, ResErrs);
           For I := 0 To TASTSpawnExpr(Expr).CaptureTypes.Count - 1 Do
             CollectTypedMonadsFromType(TASTSpawnExpr(Expr).CaptureTypes[I],
             OptTags, OptInners, ResTags, ResVals, ResErrs);
           CollectTypedMonadsFromExpr(TASTSpawnExpr(Expr).CallExpr, OptTags,
           OptInners, ResTags, ResVals, ResErrs);
         End
  Else If Expr is TASTCallExpr Then
         Begin
           Call := TASTCallExpr(Expr);
           If SameText(Call.Callee, 'NewChannel') And (Call.GenericArgs.Count =
              1) Then
             CollectTypedMonadsFromType('Channel<' + Call.GenericArgs[0] + '>',
                                        OptTags, OptInners, ResTags, ResVals,
                                        ResErrs);
           If Assigned(Call.CalleeExpr) Then
             CollectTypedMonadsFromExpr(Call.CalleeExpr, OptTags, OptInners,
                                        ResTags, ResVals, ResErrs);
           If Call.IsIndirectCall And (Call.IndirectFnType <> '') Then
             CollectTypedMonadsFromType(Call.IndirectFnType, OptTags, OptInners,
                                        ResTags, ResVals, ResErrs);
           If Call.ResolvedMonadType <> '' Then
             CollectTypedMonadsFromType(Call.ResolvedMonadType, OptTags,
                                        OptInners, ResTags, ResVals, ResErrs)
           Else If (Call.Callee = 'Some') And (Call.Args.Count >= 1) Then
                  CollectTypedMonadsFromType('Option<' + GetExprTypeName(
                                             TASTCallArg(Call.Args[0]).Expr) +
                  '>', OptTags, OptInners, ResTags, ResVals, ResErrs);
           For I := 0 To Call.Args.Count - 1 Do
             CollectTypedMonadsFromExpr(TASTCallArg(Call.Args[I]).Expr, OptTags,
             OptInners, ResTags, ResVals, ResErrs);
         End
  Else If Expr is TASTIndexExpr Then
         Begin
           CollectTypedMonadsFromExpr(TASTIndexExpr(Expr).Target, OptTags,
           OptInners, ResTags, ResVals, ResErrs);
           For I := 0 To TASTIndexExpr(Expr).Indices.Count - 1 Do
             CollectTypedMonadsFromExpr(TASTExpr(TASTIndexExpr(Expr).Indices[I])
             , OptTags, OptInners, ResTags, ResVals, ResErrs);
         End
  Else If Expr is TASTSetLiteralExpr Then
         Begin
           For I := 0 To TASTSetLiteralExpr(Expr).Elements.Count - 1 Do
             CollectTypedMonadsFromExpr(TASTExpr(TASTSetLiteralExpr(Expr).
             Elements[I]), OptTags, OptInners, ResTags, ResVals, ResErrs);
         End
  Else If Expr is TASTMapLiteralExpr Then
         Begin
           For I := 0 To TASTMapLiteralExpr(Expr).Keys.Count - 1 Do
             Begin
               CollectTypedMonadsFromExpr(TASTExpr(TASTMapLiteralExpr(Expr).Keys
               [I]), OptTags, OptInners, ResTags, ResVals, ResErrs);
               CollectTypedMonadsFromExpr(TASTExpr(TASTMapLiteralExpr(Expr).
               Values[I]), OptTags, OptInners, ResTags, ResVals, ResErrs);
             End;
         End
  Else If Expr is TASTIfExpr Then
         Begin
           CollectTypedMonadsFromExpr(TASTIfExpr(Expr).Condition, OptTags,
           OptInners, ResTags, ResVals, ResErrs);
           CollectTypedMonadsFromExpr(TASTIfExpr(Expr).ThenExpr, OptTags,
           OptInners, ResTags, ResVals, ResErrs);
           CollectTypedMonadsFromExpr(TASTIfExpr(Expr).ElseExpr, OptTags,
           OptInners, ResTags, ResVals, ResErrs);
         End
  Else If Expr is TASTMatchExpr Then
         Begin
           ME := TASTMatchExpr(Expr);
           CollectTypedMonadsFromExpr(ME.Expr, OptTags, OptInners, ResTags,
                                      ResVals, ResErrs);
           MT := ResolveAliasType(GetExprTypeName(ME.Expr));
           CollectTypedMonadsFromType(MT, OptTags, OptInners, ResTags, ResVals,
                                      ResErrs);
           For I := 0 To ME.Cases.Count - 1 Do
             Begin
               CaseN := TASTMatchCase(ME.Cases[I]);
               Cnt := GetMatchArmBindingCount(CaseN);
               For AddedB := 0 To Cnt - 1 Do
                 Begin
                   GetMatchArmBindingInfo(CaseN, AddedB, MT, BName, TVar, BType)
                   ;
                   If (BName <> '') And (BName <> '_') Then
                     Begin
                       FMatchBindNames.Add(BName);
                       FMatchBindTargets.Add(TVar);
                       FMatchBindTypes.Add(BType);
                     End;
                 End;
               Try
                 CollectTypedMonadsFromExpr(CaseN.Guard, OptTags, OptInners,
                                            ResTags, ResVals, ResErrs);
                 CollectTypedMonadsFromExpr(CaseN.ValueExpr, OptTags, OptInners,
                                            ResTags, ResVals, ResErrs);
               Finally
                 For AddedB := 0 To Cnt - 1 Do
                   Begin
                     GetMatchArmBindingInfo(CaseN, AddedB, MT, BName, TVar,
                                            BType);
                     If (BName <> '') And (BName <> '_') Then PopMatchBindings(1
                       );
                   End;
             End;
         End;
End;
End;

Procedure TDelSafeEmitterPascal.CollectTypedMonadsFromStmts(Stmts: TASTNodeList;
                                                           OptTags, OptInners,
                                                           ResTags, ResVals,
                                                           ResErrs: TStrings);

Var 
  I, J, K, Cnt: Integer;
  S: TASTStmt;
  VD: TASTVarDecl;
  ForS: TASTForStmt;
  MS: TASTMatchStmt;
  CN: TASTMatchCase;
  MT, BName, TVar, BType: string;
Begin
  If Not Assigned(Stmts) Then Exit;
  For I := 0 To Stmts.Count - 1 Do
    Begin
      S := TASTStmt(Stmts[I]);
      If S is TASTVarDeclStmt Then
        Begin
          For K := 0 To TASTVarDeclStmt(S).Decls.Count - 1 Do
            Begin
              VD := TASTVarDecl(TASTVarDeclStmt(S).Decls[K]);
              CollectTypedMonadsFromType(VD.TypeName, OptTags, OptInners,
                                         ResTags, ResVals, ResErrs);
              CollectTypedMonadsFromExpr(VD.InitialExpr, OptTags, OptInners,
                                         ResTags, ResVals, ResErrs);
            End;
        End
      Else If S is TASTAssignStmt Then
             Begin
               CollectTypedMonadsFromExpr(TASTAssignStmt(S).Target, OptTags,
               OptInners, ResTags, ResVals, ResErrs);
               CollectTypedMonadsFromExpr(TASTAssignStmt(S).Expr, OptTags,
               OptInners, ResTags, ResVals, ResErrs);
             End
      Else If S is TASTCallStmt Then
             CollectTypedMonadsFromExpr(TASTCallStmt(S).CallExpr, OptTags,
             OptInners, ResTags, ResVals, ResErrs)
      Else If S is TASTExprStmt Then
             CollectTypedMonadsFromExpr(TASTExprStmt(S).Expr, OptTags, OptInners
             , ResTags, ResVals, ResErrs)
      Else If S is TASTReturnStmt Then
             CollectTypedMonadsFromExpr(TASTReturnStmt(S).Expr, OptTags,
             OptInners, ResTags, ResVals, ResErrs)
      Else If S is TASTIfStmt Then
             Begin
               CollectTypedMonadsFromExpr(TASTIfStmt(S).Condition, OptTags,
               OptInners, ResTags, ResVals, ResErrs);
               CollectTypedMonadsFromStmts(TASTIfStmt(S).ThenBranch, OptTags,
               OptInners, ResTags, ResVals, ResErrs);
               CollectTypedMonadsFromStmts(TASTIfStmt(S).ElseBranch, OptTags,
               OptInners, ResTags, ResVals, ResErrs);
             End
      Else If S is TASTWhileStmt Then
             Begin
               CollectTypedMonadsFromExpr(TASTWhileStmt(S).Condition, OptTags,
               OptInners, ResTags, ResVals, ResErrs);
               CollectTypedMonadsFromStmts(TASTWhileStmt(S).Body, OptTags,
               OptInners, ResTags, ResVals, ResErrs);
             End
      Else If S is TASTForStmt Then
             Begin
               ForS := TASTForStmt(S);
               CollectTypedMonadsFromExpr(ForS.StartExpr, OptTags, OptInners,
                                          ResTags, ResVals, ResErrs);
               CollectTypedMonadsFromExpr(ForS.EndExpr, OptTags, OptInners,
                                          ResTags, ResVals, ResErrs);
               CollectTypedMonadsFromExpr(ForS.CollectionExpr, OptTags,
                                          OptInners, ResTags, ResVals, ResErrs);
               CollectTypedMonadsFromStmts(ForS.Body, OptTags, OptInners,
                                           ResTags, ResVals, ResErrs);
             End
      Else If S is TASTRepeatStmt Then
             Begin
               CollectTypedMonadsFromStmts(TASTRepeatStmt(S).Body, OptTags,
               OptInners, ResTags, ResVals, ResErrs);
               CollectTypedMonadsFromExpr(TASTRepeatStmt(S).Condition, OptTags,
               OptInners, ResTags, ResVals, ResErrs);
             End
      Else If S is TASTUnsafeStmt Then
             CollectTypedMonadsFromStmts(TASTUnsafeStmt(S).Body, OptTags,
             OptInners, ResTags, ResVals, ResErrs)
      Else If S is TASTTryStmt Then
             Begin
               CollectTypedMonadsFromStmts(TASTTryStmt(S).TryBody, OptTags,
               OptInners, ResTags, ResVals, ResErrs);
               CollectTypedMonadsFromStmts(TASTTryStmt(S).ExceptBody, OptTags,
               OptInners, ResTags, ResVals, ResErrs);
             End
      Else If S is TASTMatchStmt Then
             Begin
               MS := TASTMatchStmt(S);
               CollectTypedMonadsFromExpr(MS.Expr, OptTags, OptInners, ResTags,
                                          ResVals, ResErrs);
               MT := ResolveAliasType(GetExprTypeName(MS.Expr));
               CollectTypedMonadsFromType(MT, OptTags, OptInners, ResTags,
                                          ResVals, ResErrs);
               For K := 0 To MS.Cases.Count - 1 Do
                 Begin
                   CN := TASTMatchCase(MS.Cases[K]);
                   Cnt := GetMatchArmBindingCount(CN);
                   For J := 0 To Cnt - 1 Do
                     Begin
                       GetMatchArmBindingInfo(CN, J, MT, BName, TVar, BType);
                       If (BName <> '') And (BName <> '_') Then
                         Begin
                           FMatchBindNames.Add(BName);
                           FMatchBindTargets.Add(TVar);
                           FMatchBindTypes.Add(BType);
                         End;
                     End;
                   Try
                     CollectTypedMonadsFromExpr(CN.Guard, OptTags, OptInners,
                                                ResTags, ResVals, ResErrs);
                     CollectTypedMonadsFromStmts(CN.Body, OptTags, OptInners,
                                                 ResTags, ResVals, ResErrs);
                   Finally
                     For J := 0 To Cnt - 1 Do
                       Begin
                         GetMatchArmBindingInfo(CN, J, MT, BName, TVar, BType);
                         If (BName <> '') And (BName <> '_') Then
                           PopMatchBindings(1);
                       End;
                 End;
             End;
    End;
End;
End;

Procedure TDelSafeEmitterPascal.CollectTypedMonadsFromModule(AModule: TASTModule;
                                                            OptTags, OptInners,
                                                            ResTags, ResVals,
                                                            ResErrs: TStrings);

Var 
  I, J, K: Integer;
  Node: TASTNode;
  Rec: TASTRecordDecl;
  Enm: TASTEnumDecl;
  VarN: TASTEnumVariant;
  Func: TASTFunction;
  OldFunc: TASTFunction;
  OldProg: TASTProgramBlock;
Begin
  For I := 0 To AModule.Types.Count - 1 Do
    Begin
      Node := AModule.Types[I];
      If Node is TASTRecordDecl Then
        Begin
          Rec := TASTRecordDecl(Node);
          If Rec.GenericParams.Count = 0 Then
            For J := 0 To Rec.Fields.Count - 1 Do
              CollectTypedMonadsFromType(TASTRecordField(Rec.Fields[J]).TypeName
              , OptTags, OptInners, ResTags, ResVals, ResErrs);
        End
      Else If Node is TASTEnumDecl Then
             Begin
               Enm := TASTEnumDecl(Node);
               For J := 0 To Enm.Variants.Count - 1 Do
                 Begin
                   VarN := TASTEnumVariant(Enm.Variants[J]);
                   For K := 0 To VarN.Fields.Count - 1 Do
                     CollectTypedMonadsFromType(TASTRecordField(VarN.Fields[K]).
                     TypeName, OptTags, OptInners, ResTags, ResVals, ResErrs);
                 End;
             End
      Else If Node is TASTArrayDecl Then
             CollectTypedMonadsFromType(TASTArrayDecl(Node).ElemType, OptTags,
             OptInners, ResTags, ResVals, ResErrs)
      Else If Node is TASTMapDecl Then
             Begin
               CollectTypedMonadsFromType(TASTMapDecl(Node).KeyType, OptTags,
               OptInners, ResTags, ResVals, ResErrs);
               CollectTypedMonadsFromType(TASTMapDecl(Node).ValType, OptTags,
               OptInners, ResTags, ResVals, ResErrs);
             End
      Else If Node is TASTTypeAliasDecl Then
             CollectTypedMonadsFromType(TASTTypeAliasDecl(Node).TargetType,
             OptTags, OptInners, ResTags, ResVals, ResErrs);
    End;

  For I := 0 To AModule.ModuleVars.Count - 1 Do
    Begin
      CollectTypedMonadsFromType(TASTVarDecl(AModule.ModuleVars[I]).TypeName,
      OptTags, OptInners, ResTags, ResVals, ResErrs);
      CollectTypedMonadsFromExpr(TASTVarDecl(AModule.ModuleVars[I]).InitialExpr,
      OptTags, OptInners, ResTags, ResVals, ResErrs);
    End;

  OldFunc := FCurrentFunc;
  OldProg := FProgramBlock;
  Try
    For I := 0 To AModule.Functions.Count - 1 Do
      Begin
        Func := TASTFunction(AModule.Functions[I]);
        If (Func.GenericParams.Count > 0) Or (Func.GenericParam <> '') Then
          Continue;
        FCurrentFunc := Func;
        FProgramBlock := Nil;
        If Not Func.IsProcedure Then
          CollectTypedMonadsFromType(Func.ReturnType, OptTags, OptInners,
                                     ResTags, ResVals, ResErrs);
        If Func.IsAsync Then
          CollectTypedMonadsFromType('Task<' + Func.ReturnType + '>', OptTags,
                                     OptInners, ResTags, ResVals, ResErrs);
        For J := 0 To Func.Params.Count - 1 Do
          CollectTypedMonadsFromType(TASTParam(Func.Params[J]).TypeName, OptTags
          , OptInners, ResTags, ResVals, ResErrs);
        For J := 0 To Func.LocalVars.Count - 1 Do
          Begin
            CollectTypedMonadsFromType(TASTVarDecl(Func.LocalVars[J]).TypeName,
            OptTags, OptInners, ResTags, ResVals, ResErrs);
            CollectTypedMonadsFromExpr(TASTVarDecl(Func.LocalVars[J]).
            InitialExpr, OptTags, OptInners, ResTags, ResVals, ResErrs);
          End;
        CollectTypedMonadsFromStmts(Func.Body, OptTags, OptInners, ResTags,
                                    ResVals, ResErrs);
      End;

    CollectTypedMonadsFromStmts(AModule.InitBody, OptTags, OptInners, ResTags,
                                ResVals, ResErrs);
    CollectTypedMonadsFromStmts(AModule.FiniBody, OptTags, OptInners, ResTags,
                                ResVals, ResErrs);

    If Assigned(AModule.ProgramBlock) Then
      Begin
        FCurrentFunc := Nil;
        FProgramBlock := AModule.ProgramBlock;
        For J := 0 To AModule.ProgramBlock.LocalVars.Count - 1 Do
          Begin
            CollectTypedMonadsFromType(TASTVarDecl(AModule.ProgramBlock.
                                       LocalVars[J]).TypeName, OptTags,
            OptInners, ResTags, ResVals, ResErrs);
            CollectTypedMonadsFromExpr(TASTVarDecl(AModule.ProgramBlock.
                                       LocalVars[J]).InitialExpr, OptTags,
            OptInners, ResTags, ResVals, ResErrs);
          End;
        CollectTypedMonadsFromStmts(AModule.ProgramBlock.Body, OptTags,
                                    OptInners, ResTags, ResVals, ResErrs);
      End;
  Finally
    FCurrentFunc := OldFunc;
    FProgramBlock := OldProg;
End;
End;

Procedure TDelSafeEmitterPascal.EmitTypedOptionDecl(Const Tag, InnerT: String);
Begin
  Emit(Format('TDelSafeOpt_%s = record', [Tag]));
  IncIndent;
  Emit('is_some: Boolean;');
  Emit('is_none: Boolean;');
  Emit(Format('value: %s;', [EmitTypeRef(InnerT)]));
  DecIndent;
  Emit('end;');
  Emit('');
End;

Procedure TDelSafeEmitterPascal.EmitTypedResultDecl(Const Tag, ValT, ErrT: String
);
Begin
  Emit(Format('TDelSafeRes_%s = record', [Tag]));
  IncIndent;
  Emit('is_ok: Boolean;');
  Emit('is_err: Boolean;');
  Emit(Format('value: %s;', [EmitTypeRef(ValT)]));
  Emit(Format('error: %s;', [EmitTypeRef(ErrT)]));
  DecIndent;
  Emit('end;');
  Emit('');
End;

Procedure TDelSafeEmitterPascal.EmitTypedMonadHelpers(OptTags, OptInners, ResTags
                                                     , ResVals, ResErrs:
                                                     TStrings; DeclOnly: Boolean
);

Var 
  I: Integer;
  T, InnerPas, ValPas, ErrPas: string;
Begin
  For I := 0 To OptTags.Count - 1 Do
    Begin
      T := OptTags[I];
      InnerPas := EmitTypeRef(OptInners[I]);
      Emit(Format('function DelSafeSome_%s(const V: %s): TDelSafeOpt_%s;', [T,
           InnerPas, T]));
      If Not DeclOnly Then
        Begin
          Emit('begin');
          Emit(Format('  Result := Default(TDelSafeOpt_%s);', [T]));
          Emit('  Result.is_some := True;');
          Emit('  Result.is_none := False;');
          Emit('  Result.value := V;');
          Emit('end;');
          Emit('');
        End;
      Emit(Format('function DelSafeNone_%s(): TDelSafeOpt_%s;', [T, T]));
      If Not DeclOnly Then
        Begin
          Emit('begin');
          Emit(Format('  Result := Default(TDelSafeOpt_%s);', [T]));
          Emit('  Result.is_some := False;');
          Emit('  Result.is_none := True;');
          Emit('end;');
          Emit('');
        End;
    End;

  For I := 0 To ResTags.Count - 1 Do
    Begin
      T := ResTags[I];
      ValPas := EmitTypeRef(ResVals[I]);
      ErrPas := EmitTypeRef(ResErrs[I]);
      Emit(Format('function DelSafeOk_%s(const V: %s): TDelSafeRes_%s;', [T,
           ValPas, T]));
      If Not DeclOnly Then
        Begin
          Emit('begin');
          Emit(Format('  Result := Default(TDelSafeRes_%s);', [T]));
          Emit('  Result.is_ok := True;');
          Emit('  Result.is_err := False;');
          Emit('  Result.value := V;');
          Emit('end;');
          Emit('');
        End;
      Emit(Format('function DelSafeErr_%s(const E: %s): TDelSafeRes_%s;', [T,
           ErrPas, T]));
      If Not DeclOnly Then
        Begin
          Emit('begin');
          Emit(Format('  Result := Default(TDelSafeRes_%s);', [T]));
          Emit('  Result.is_ok := False;');
          Emit('  Result.is_err := True;');
          Emit('  Result.error := E;');
          Emit('end;');
          Emit('');
        End;
    End;
End;

Procedure TDelSafeEmitterPascal.EmitPayloadEnumConstructors(Enm: TASTEnumDecl;
                                                           DeclOnly: Boolean);

Var 
  I, J: Integer;
  V: TASTEnumVariant;
  F: TASTRecordField;
  ParamsStr, FnName: string;
Begin
  If Not Enm.HasPayload Then Exit;
  For I := 0 To Enm.Variants.Count - 1 Do
    Begin
      V := TASTEnumVariant(Enm.Variants[I]);
      FnName := Enm.Name + '_' + V.Name;
      ParamsStr := '';
      For J := 0 To V.Fields.Count - 1 Do
        Begin
          F := TASTRecordField(V.Fields[J]);
          If J > 0 Then ParamsStr := ParamsStr + '; ';
          ParamsStr := ParamsStr + Format('const A_%s: %s', [F.Name, EmitTypeRef
                       (F.TypeName)]);
        End;
      Emit(Format('function %s(%s): T%s;', [FnName, ParamsStr, Enm.Name]));
      If Not DeclOnly Then
        Begin
          Emit('begin');
          IncIndent;
          Emit(Format('Result := Default(T%s);', [Enm.Name]));
          Emit(Format('Result.tag := %s_Tag_%s;', [Enm.Name, V.Name]));
          For J := 0 To V.Fields.Count - 1 Do
            Begin
              F := TASTRecordField(V.Fields[J]);
              Emit(Format('Result._v_%s_%s := A_%s;', [V.Name, F.Name, F.Name]))
              ;
            End;
          DecIndent;
          Emit('end;');
          Emit('');
        End;
    End;
End;

Function TDelSafeEmitterPascal.IsTypeIdentifier(Const AName: String): Boolean;

Var 
  I: Integer;
Begin
  If Assigned(FCurrentFunc) Then
    Begin
      For I := 0 To FCurrentFunc.LocalVars.Count - 1 Do
        If SameText(TASTVarDecl(FCurrentFunc.LocalVars[I]).Name, AName) Then
          Exit(False);
      For I := 0 To FCurrentFunc.Params.Count - 1 Do
        If SameText(TASTParam(FCurrentFunc.Params[I]).Name, AName) Then Exit(

                                                                           False
          );
      If FindInlineVarType(FCurrentFunc.Body, AName) <> '' Then Exit(False);
    End;
  If Assigned(FProgramBlock) Then
    Begin
      For I := 0 To FProgramBlock.LocalVars.Count - 1 Do
        If SameText(TASTVarDecl(FProgramBlock.LocalVars[I]).Name, AName) Then
          Exit(False);
      If FindInlineVarType(FProgramBlock.Body, AName) <> '' Then Exit(False);
    End;
  If (AName = 'Int8') Or (AName = 'Int16') Or (AName = 'Int32') Or (AName =
     'Int64') Or
     (AName = 'UInt8') Or (AName = 'UInt16') Or (AName = 'UInt32') Or (AName =
     'UInt64') Or
     (AName = 'Float32') Or (AName = 'Float64') Or (AName = 'Bool') Or (AName =
     'Char') Or
     (AName = 'String') Or (AName = 'Pointer') Then
    Exit(True);
  If Assigned(FModule) Then
    Begin
      For I := 0 To FModule.Types.Count - 1 Do
        Begin
          If ((FModule.Types[I] is TASTRecordDecl) And SameText(TASTRecordDecl(
             FModule.Types[I]).Name, AName)) Or
             ((FModule.Types[I] is TASTEnumDecl) And SameText(TASTEnumDecl(
             FModule.Types[I]).Name, AName)) Or
             ((FModule.Types[I] is TASTArrayDecl) And SameText(TASTArrayDecl(
             FModule.Types[I]).Name, AName)) Or
             ((FModule.Types[I] is TASTSetDecl) And SameText(TASTSetDecl(FModule
             .Types[I]).Name, AName)) Or
             ((FModule.Types[I] is TASTSubrangeDecl) And SameText(
             TASTSubrangeDecl(FModule.Types[I]).Name, AName)) Or
             ((FModule.Types[I] is TASTMapDecl) And SameText(TASTMapDecl(FModule
             .Types[I]).Name, AName)) Or
             ((FModule.Types[I] is TASTTypeAliasDecl) And SameText(
             TASTTypeAliasDecl(FModule.Types[I]).Name, AName)) Then
            Exit(True);
        End;
    End;
  Result := False;
End;

Function TDelSafeEmitterPascal.EmitMonadFieldExtract(Const ExprStr, FieldType,
                                                    NumField, StrField: String):

                                                                          string
;

Var 
  R: string;
Begin
  R := ResolveAliasType(FieldType);
  If R = 'String' Then
    Result := ExprStr + '.' + StrField
  Else If R = 'Bool' Then
         Result := Format('(%s.%s <> 0)', [ExprStr, NumField])
  Else If R = 'Char' Then
         Result := Format('Chr(Round(%s.%s))', [ExprStr, NumField])
  Else If IsIntegerType(R) Or IsEnumName(R) Then
         Result := Format('%s(Round(%s.%s))', [EmitTypeRef(FieldType), ExprStr,
                   NumField])
  Else
    Result := ExprStr + '.' + NumField;
End;

Procedure TDelSafeEmitterPascal.EmitArrayLiteralAssign(Const TargetStr,
                                                      TargetType: String; SetLit
                                                      : TASTSetLiteralExpr);

Var 
  I: Integer;
Begin
  If IsDynamicArrayType(TargetType) Then
    Emit(Format('SetLength(%s, %d);', [TargetStr, SetLit.Elements.Count]));
  For I := 0 To SetLit.Elements.Count - 1 Do
    Emit(Format('%s[%d] := %s;', [TargetStr, I, EmitExpr(TASTExpr(SetLit.
         Elements[I]))]));
End;

Procedure TDelSafeEmitterPascal.EmitMapLiteralAssign(Const TargetStr, TargetType:
                                                    String; MapLit:
                                                    TASTMapLiteralExpr);

Var 
  I: Integer;
  K, V, Tag: string;
Begin
  If IsMapType(TargetType, K, V) Then
    Begin
      Tag := MapTag(K, V);
      Emit(Format('%s.count := 0; SetLength(%s.entries, 0);', [TargetStr,
           TargetStr]));
      For I := 0 To MapLit.Keys.Count - 1 Do
        Emit(Format('DelSafeMapSet_%s(%s, %s, %s);',
             [Tag, TargetStr, EmitExpr(TASTExpr(MapLit.Keys[I])), EmitExpr(

                                                                        TASTExpr
                                                                           (

                                                                          MapLit
                                                                           .

                                                                          Values
                                                                           [I]))
        ]));
    End;
End;

Function TDelSafeEmitterPascal.IsMapType(Const AType: String; out KeyType,
                                        ValType: String): Boolean;

Var 
  PClose, I: Integer;
  MapD: TASTMapDecl;
  T: string;
Begin
  KeyType := '';
  ValType := '';
  T := ResolveAliasType(AType);
  If Pos('map[', T) = 1 Then
    Begin
      PClose := Pos(']', T);
      If PClose > 4 Then
        Begin
          KeyType := Trim(Copy(T, 5, PClose - 5));
          ValType := Trim(Copy(T, PClose + 1, Length(T)));
          Exit(True);
        End;
    End;
  If Assigned(FModule) Then
    Begin
      For I := 0 To FModule.Types.Count - 1 Do
        If (FModule.Types[I] is TASTMapDecl) And SameText(TASTMapDecl(FModule.
           Types[I]).Name, T) Then
          Begin
            MapD := TASTMapDecl(FModule.Types[I]);
            KeyType := MapD.KeyType;
            ValType := MapD.ValType;
            Exit(True);
          End;
    End;
  Result := False;
End;

Function SanitizeTagPart(Const S: String): string;

Var 
  I: Integer;
Begin
  Result := '';
  For I := 1 To Length(S) Do
    If S[I] In ['a'..'z', 'A'..'Z', '0'..'9', '_'] Then
      Result := Result + S[I]
    Else If (S[I] = '^') Then
           Result := Result + 'Ptr_'
    Else
      Result := Result + '_';
End;

Function TDelSafeEmitterPascal.MapTag(Const K, V: String): string;
Begin
  Result := SanitizeTagPart(K) + '_' + SanitizeTagPart(V);
End;

Function TDelSafeEmitterPascal.NormalizeIntLit(Const Val: String): string;

Var 
  Prefix, Rest: string;
Begin
  Prefix := '';
  Rest := Val;
  If (Length(Rest) > 1) And (Rest[1] = '-') Then
    Begin
      Prefix := '-';
      Rest := Copy(Rest, 2, Length(Rest));
    End;
  If (Copy(Rest, 1, 2) = '0x') Or (Copy(Rest, 1, 2) = '0X') Then
    Result := Prefix + '$' + Copy(Rest, 3, Length(Rest))
  Else If (Copy(Rest, 1, 2) = '0b') Or (Copy(Rest, 1, 2) = '0B') Then
         Result := Prefix + '%' + Copy(Rest, 3, Length(Rest))
  Else
    Result := Val;
End;

Function TDelSafeEmitterPascal.IsBuiltinMapSideType(Const AType: String): Boolean
;
Begin
  Result := (AType = 'Int8') Or (AType = 'Int16') Or (AType = 'Int32') Or (AType
            = 'Int64') Or
            (AType = 'UInt8') Or (AType = 'UInt16') Or (AType = 'UInt32') Or (
            AType = 'UInt64') Or
            (AType = 'Float32') Or (AType = 'Float64') Or (AType = 'Bool') Or (
            AType = 'Char') Or
            (AType = 'String') Or (AType = 'Pointer');
End;

Function TDelSafeEmitterPascal.GetCollectionElemType(Expr: TASTExpr): string;

Var 
  ColType: string;
  P1, I: Integer;
Begin
  Result := '';
  ColType := GetExprTypeName(Expr);
  If ColType = 'String' Then
    Exit('Char')
  Else If Pos('array of ', ColType) = 1 Then
         Exit(Trim(Copy(ColType, 10, Length(ColType))))
  Else If Pos('] of ', ColType) > 0 Then
         Begin
           P1 := Pos('] of ', ColType);
           Exit(Trim(Copy(ColType, P1 + 5, Length(ColType))));
         End
  Else If Assigned(FModule) Then
         Begin
           For I := 0 To FModule.Types.Count - 1 Do
             If (FModule.Types[I] is TASTArrayDecl) And SameText(TASTArrayDecl(
                FModule.Types[I]).Name, ColType) Then
               Exit(TASTArrayDecl(FModule.Types[I]).ElemType);
         End;
End;

Function TDelSafeEmitterPascal.FindInlineVarType(Stmts: TASTNodeList; Const AName
                                                : String): string;

Var 
  I, K: Integer;
  S: TASTStmt;
  VD: TASTVarDecl;
  MatchNode: TASTMatchStmt;
  CaseNode: TASTMatchCase;
Begin
  Result := '';
  If Not Assigned(Stmts) Then Exit;
  For I := 0 To Stmts.Count - 1 Do
    Begin
      S := TASTStmt(Stmts[I]);
      If S is TASTVarDeclStmt Then
        Begin
          For K := 0 To TASTVarDeclStmt(S).Decls.Count - 1 Do
            Begin
              VD := TASTVarDecl(TASTVarDeclStmt(S).Decls[K]);
              If SameText(VD.Name, AName) Then
                Exit(VD.TypeName);
            End;
        End
      Else If S is TASTIfStmt Then
             Begin
               Result := FindInlineVarType(TASTIfStmt(S).ThenBranch, AName);
               If Result <> '' Then Exit;
               Result := FindInlineVarType(TASTIfStmt(S).ElseBranch, AName);
               If Result <> '' Then Exit;
             End
      Else If S is TASTWhileStmt Then
             Begin
               Result := FindInlineVarType(TASTWhileStmt(S).Body, AName);
               If Result <> '' Then Exit;
             End
      Else If S is TASTForStmt Then
             Begin
               Result := FindInlineVarType(TASTForStmt(S).Body, AName);
               If Result <> '' Then Exit;
             End
      Else If S is TASTRepeatStmt Then
             Begin
               Result := FindInlineVarType(TASTRepeatStmt(S).Body, AName);
               If Result <> '' Then Exit;
             End
      Else If S is TASTUnsafeStmt Then
             Begin
               Result := FindInlineVarType(TASTUnsafeStmt(S).Body, AName);
               If Result <> '' Then Exit;
             End
      Else If S is TASTTryStmt Then
             Begin
               Result := FindInlineVarType(TASTTryStmt(S).TryBody, AName);
               If Result <> '' Then Exit;
               Result := FindInlineVarType(TASTTryStmt(S).ExceptBody, AName);
               If Result <> '' Then Exit;
             End
      Else If S is TASTMatchStmt Then
             Begin
               MatchNode := TASTMatchStmt(S);
               For K := 0 To MatchNode.Cases.Count - 1 Do
                 Begin
                   CaseNode := TASTMatchCase(MatchNode.Cases[K]);
                   Result := FindInlineVarType(CaseNode.Body, AName);
                   If Result <> '' Then Exit;
                 End;
             End;
    End;
End;

Procedure TDelSafeEmitterPascal.CollectAutoVarsFromExpr(Expr: TASTExpr; VarNames,
                                                       VarTypes: TStrings; Const
                                                       SkipNames: TStrings);

Var 
  I, K, BIdx: Integer;
  CaseNode: TASTMatchCase;
  MT, DeclType, KeyT, ValT, BName, TVar, BType: string;

Procedure AddAutoVarLocal(Const AName, AType: String);

Var 
  J: Integer;
Begin
  For J := 0 To SkipNames.Count - 1 Do
    If SameText(SkipNames[J], AName) Then Exit;
  For J := 0 To VarNames.Count - 1 Do
    If SameText(VarNames[J], AName) Then Exit;
  VarNames.Add(AName);
  VarTypes.Add(AType);
End;
Begin
  If Not Assigned(Expr) Then Exit;
  If Expr is TASTMemberAccessExpr Then
    CollectAutoVarsFromExpr(TASTMemberAccessExpr(Expr).Target, VarNames,
    VarTypes, SkipNames)
  Else If Expr is TASTBinaryExpr Then
         Begin
           CollectAutoVarsFromExpr(TASTBinaryExpr(Expr).Left, VarNames, VarTypes
           , SkipNames);
           CollectAutoVarsFromExpr(TASTBinaryExpr(Expr).Right, VarNames,
           VarTypes, SkipNames);
         End
  Else If Expr is TASTUnaryExpr Then
         Begin
           If TASTUnaryExpr(Expr).Op = '?' Then
             Begin
               MT := EmitTypeRef(ResolveAliasType(GetExprTypeName(TASTUnaryExpr(
                     Expr).Expr)));
               If MT = '' Then MT := 'TResultDoubleError';
               AddAutoVarLocal(Format('_delsafe_try_%d_%d', [Expr.Line, Expr.Col]
               ), MT);
             End;
           CollectAutoVarsFromExpr(TASTUnaryExpr(Expr).Expr, VarNames, VarTypes,
           SkipNames);
         End
  Else If Expr is TASTAwaitExpr Then
         CollectAutoVarsFromExpr(TASTAwaitExpr(Expr).Expr, VarNames, VarTypes,
         SkipNames)
  Else If Expr is TASTSpawnExpr Then
         CollectAutoVarsFromExpr(TASTSpawnExpr(Expr).CallExpr, VarNames,
         VarTypes, SkipNames)
  Else If Expr is TASTCallExpr Then
         Begin
           If Assigned(TASTCallExpr(Expr).CalleeExpr) Then
             CollectAutoVarsFromExpr(TASTCallExpr(Expr).CalleeExpr, VarNames,
             VarTypes, SkipNames);
           For I := 0 To TASTCallExpr(Expr).Args.Count - 1 Do
             CollectAutoVarsFromExpr(TASTCallArg(TASTCallExpr(Expr).Args[I]).
             Expr, VarNames, VarTypes, SkipNames);
         End
  Else If Expr is TASTTupleLiteralExpr Then
         Begin
           For I := 0 To TASTTupleLiteralExpr(Expr).Elements.Count - 1 Do
             CollectAutoVarsFromExpr(TASTExpr(TASTTupleLiteralExpr(Expr).
             Elements[I]), VarNames, VarTypes, SkipNames);
         End
  Else If Expr is TASTIndexExpr Then
         Begin
           CollectAutoVarsFromExpr(TASTIndexExpr(Expr).Target, VarNames,
           VarTypes, SkipNames);
           For I := 0 To TASTIndexExpr(Expr).Indices.Count - 1 Do
             CollectAutoVarsFromExpr(TASTExpr(TASTIndexExpr(Expr).Indices[I]),
             VarNames, VarTypes, SkipNames);
         End
  Else If Expr is TASTSetLiteralExpr Then
         Begin
           For I := 0 To TASTSetLiteralExpr(Expr).Elements.Count - 1 Do
             CollectAutoVarsFromExpr(TASTExpr(TASTSetLiteralExpr(Expr).Elements[
             I]), VarNames, VarTypes, SkipNames);
         End
  Else If Expr is TASTMapLiteralExpr Then
         Begin
           MT := GetExprTypeName(Expr);
           If IsMapType(MT, KeyT, ValT) Then
             AddAutoVarLocal(Format('_delsafe_mlit_%d_%d', [Expr.Line, Expr.Col])
             , EmitTypeRef(MT));
           For I := 0 To TASTMapLiteralExpr(Expr).Keys.Count - 1 Do
             Begin
               CollectAutoVarsFromExpr(TASTExpr(TASTMapLiteralExpr(Expr).Keys[I]
               ), VarNames, VarTypes, SkipNames);
               CollectAutoVarsFromExpr(TASTExpr(TASTMapLiteralExpr(Expr).Values[
               I]), VarNames, VarTypes, SkipNames);
             End;
         End
  Else If Expr is TASTIfExpr Then
         Begin
           CollectAutoVarsFromExpr(TASTIfExpr(Expr).Condition, VarNames,
           VarTypes, SkipNames);
           CollectAutoVarsFromExpr(TASTIfExpr(Expr).ThenExpr, VarNames, VarTypes
           , SkipNames);
           CollectAutoVarsFromExpr(TASTIfExpr(Expr).ElseExpr, VarNames, VarTypes
           , SkipNames);
         End
  Else If Expr is TASTMatchExpr Then
         Begin
           DeclType := EmitTypeRef(ResolveAliasType(GetExprTypeName(Expr)));
           If DeclType = '' Then DeclType := 'Int32';
           AddAutoVarLocal(Format('_delsafe_mexpr_%d_%d', [Expr.Line, Expr.Col]),
           DeclType);
           CollectAutoVarsFromExpr(TASTMatchExpr(Expr).Expr, VarNames, VarTypes,
           SkipNames);
           MT := ResolveAliasType(GetExprTypeName(TASTMatchExpr(Expr).Expr));
           DeclType := EmitTypeRef(MT);
           If DeclType = '' Then DeclType := 'Int32';
           AddAutoVarLocal(Format('_delsafe_mval_%d_%d', [Expr.Line, Expr.Col]),
           DeclType);
           For K := 0 To TASTMatchExpr(Expr).Cases.Count - 1 Do
             Begin
               CaseNode := TASTMatchCase(TASTMatchExpr(Expr).Cases[K]);
               I := GetMatchArmBindingCount(CaseNode);
               For BIdx := 0 To I - 1 Do
                 Begin
                   GetMatchArmBindingInfo(CaseNode, BIdx, MT, BName, TVar, BType
                   );
                   If (BName <> '') And (BName <> '_') Then
                     Begin
                       DeclType := EmitTypeRef(BType);
                       If DeclType = '' Then DeclType := 'Int32';
                       AddAutoVarLocal(TVar, DeclType);
                     End;
                 End;
               PushMatchBindings(CaseNode, MT);
               Try
                 CollectAutoVarsFromExpr(CaseNode.Guard, VarNames, VarTypes,
                                         SkipNames);
                 CollectAutoVarsFromExpr(CaseNode.ValueExpr, VarNames, VarTypes,
                                         SkipNames);
               Finally
                 For BIdx := 0 To I - 1 Do
                   Begin
                     GetMatchArmBindingInfo(CaseNode, BIdx, MT, BName, TVar,
                                            BType);
                     If (BName <> '') And (BName <> '_') Then PopMatchBindings(1
                       );
                   End;
             End;
         End;
End;
End;

Procedure TDelSafeEmitterPascal.CollectAutoVarsFromStmts(Stmts: TASTNodeList;
                                                        VarNames, VarTypes:
                                                        TStrings; Const
                                                        SkipNames: TStrings);

Var 
  I, K, BIdx, BCount: Integer;
  S: TASTStmt;
  ForStmt: TASTForStmt;
  MatchNode: TASTMatchStmt;
  CaseNode: TASTMatchCase;
  VD: TASTVarDecl;
  ElemT, MT, DeclType, KeyT, ValT, BName, TVar, BType: string;

Procedure AddAutoVar(Const AName, AType: String);

Var 
  J: Integer;
Begin
  For J := 0 To SkipNames.Count - 1 Do
    If SameText(SkipNames[J], AName) Then Exit;
  For J := 0 To VarNames.Count - 1 Do
    If SameText(VarNames[J], AName) Then Exit;
  VarNames.Add(AName);
  VarTypes.Add(AType);
End;
Begin
  If Not Assigned(Stmts) Then Exit;
  For I := 0 To Stmts.Count - 1 Do
    Begin
      S := TASTStmt(Stmts[I]);
      If S is TASTVarDeclStmt Then
        Begin
          For K := 0 To TASTVarDeclStmt(S).Decls.Count - 1 Do
            Begin
              VD := TASTVarDecl(TASTVarDeclStmt(S).Decls[K]);
              AddAutoVar(VD.Name, EmitTypeRef(VD.TypeName));
              If Assigned(VD.InitialExpr) And Not (VD.InitialExpr is
                 TASTMapLiteralExpr) Then
                CollectAutoVarsFromExpr(VD.InitialExpr, VarNames, VarTypes,
                                        SkipNames);
            End;
        End
      Else If S is TASTAssignStmt Then
             Begin
               CollectAutoVarsFromExpr(TASTAssignStmt(S).Target, VarNames,
               VarTypes, SkipNames);
               If Not (TASTAssignStmt(S).Expr is TASTMapLiteralExpr) Then
                 CollectAutoVarsFromExpr(TASTAssignStmt(S).Expr, VarNames,
                 VarTypes, SkipNames);
             End
      Else If S is TASTCallStmt Then
             CollectAutoVarsFromExpr(TASTCallStmt(S).CallExpr, VarNames,
             VarTypes, SkipNames)
      Else If S is TASTExprStmt Then
             CollectAutoVarsFromExpr(TASTExprStmt(S).Expr, VarNames, VarTypes,
             SkipNames)
      Else If S is TASTReturnStmt Then
             CollectAutoVarsFromExpr(TASTReturnStmt(S).Expr, VarNames, VarTypes,
             SkipNames)
      Else If S is TASTDeferStmt Then
             Begin
               If Assigned(TASTDeferStmt(S).Stmt) Then
                 Begin
                   If TASTDeferStmt(S).Stmt is TASTCallStmt Then
                     CollectAutoVarsFromExpr(TASTCallStmt(TASTDeferStmt(S).Stmt)
                     .CallExpr, VarNames, VarTypes, SkipNames)
                   Else If TASTDeferStmt(S).Stmt is TASTAssignStmt Then
                          CollectAutoVarsFromExpr(TASTAssignStmt(TASTDeferStmt(S
                          ).Stmt).Expr, VarNames, VarTypes, SkipNames);
                 End;
             End
      Else If S is TASTForStmt Then
             Begin
               ForStmt := TASTForStmt(S);
               If Assigned(ForStmt.CollectionExpr) Then
                 Begin
                   CollectAutoVarsFromExpr(ForStmt.CollectionExpr, VarNames,
                                           VarTypes, SkipNames);
                   MT := GetExprTypeName(ForStmt.CollectionExpr);
                   If IsMapType(MT, KeyT, ValT) Then
                     Begin
                       AddAutoVar(ForStmt.VarName, EmitTypeRef(KeyT));
                       If ForStmt.ValVarName <> '' Then
                         AddAutoVar(ForStmt.ValVarName, EmitTypeRef(ValT));
                       AddAutoVar(Format('_delsafe_mi_%d_%d', [ForStmt.Line,
                                  ForStmt.Col]), 'Int32');
                     End
                   Else
                     Begin
                       ElemT := GetCollectionElemType(ForStmt.CollectionExpr);
                       If ElemT <> '' Then
                         AddAutoVar(ForStmt.VarName, EmitTypeRef(ElemT))
                       Else
                         AddAutoVar(ForStmt.VarName, 'LongInt');
                     End;
                 End
               Else
                 Begin
                   CollectAutoVarsFromExpr(ForStmt.StartExpr, VarNames, VarTypes
                                           , SkipNames);
                   CollectAutoVarsFromExpr(ForStmt.EndExpr, VarNames, VarTypes,
                                           SkipNames);
                   AddAutoVar(ForStmt.VarName, 'LongInt');
                 End;
               CollectAutoVarsFromStmts(ForStmt.Body, VarNames, VarTypes,
                                        SkipNames);
             End
      Else If S is TASTIfStmt Then
             Begin
               CollectAutoVarsFromExpr(TASTIfStmt(S).Condition, VarNames,
               VarTypes, SkipNames);
               CollectAutoVarsFromStmts(TASTIfStmt(S).ThenBranch, VarNames,
               VarTypes, SkipNames);
               CollectAutoVarsFromStmts(TASTIfStmt(S).ElseBranch, VarNames,
               VarTypes, SkipNames);
             End
      Else If S is TASTWhileStmt Then
             Begin
               CollectAutoVarsFromExpr(TASTWhileStmt(S).Condition, VarNames,
               VarTypes, SkipNames);
               CollectAutoVarsFromStmts(TASTWhileStmt(S).Body, VarNames,
               VarTypes, SkipNames);
             End
      Else If S is TASTRepeatStmt Then
             Begin
               CollectAutoVarsFromStmts(TASTRepeatStmt(S).Body, VarNames,
               VarTypes, SkipNames);
               CollectAutoVarsFromExpr(TASTRepeatStmt(S).Condition, VarNames,
               VarTypes, SkipNames);
             End
      Else If S is TASTUnsafeStmt Then
             CollectAutoVarsFromStmts(TASTUnsafeStmt(S).Body, VarNames, VarTypes
             , SkipNames)
      Else If S is TASTTryStmt Then
             Begin
               CollectAutoVarsFromStmts(TASTTryStmt(S).TryBody, VarNames,
               VarTypes, SkipNames);
               CollectAutoVarsFromStmts(TASTTryStmt(S).ExceptBody, VarNames,
               VarTypes, SkipNames);
             End
      Else If S is TASTMatchStmt Then
             Begin
               MatchNode := TASTMatchStmt(S);
               CollectAutoVarsFromExpr(MatchNode.Expr, VarNames, VarTypes,
                                       SkipNames);
               MT := ResolveAliasType(GetExprTypeName(MatchNode.Expr));
               DeclType := EmitTypeRef(MT);
               If DeclType = '' Then DeclType := 'Int32';
               AddAutoVar(Format('_delsafe_mval_%d_%d', [MatchNode.Line,
                          MatchNode.Col]), DeclType);
               For K := 0 To MatchNode.Cases.Count - 1 Do
                 Begin
                   CaseNode := TASTMatchCase(MatchNode.Cases[K]);
                   BCount := GetMatchArmBindingCount(CaseNode);
                   For BIdx := 0 To BCount - 1 Do
                     Begin
                       GetMatchArmBindingInfo(CaseNode, BIdx, MT, BName, TVar,
                                              BType);
                       If (BName <> '') And (BName <> '_') Then
                         Begin
                           DeclType := EmitTypeRef(BType);
                           If DeclType = '' Then DeclType := 'Int32';
                           AddAutoVar(TVar, DeclType);
                         End;
                     End;
                   PushMatchBindings(CaseNode, MT);
                   Try
                     CollectAutoVarsFromExpr(CaseNode.Guard, VarNames, VarTypes,
                                             SkipNames);
                     CollectAutoVarsFromStmts(CaseNode.Body, VarNames, VarTypes,
                                              SkipNames);
                   Finally
                     For BIdx := 0 To BCount - 1 Do
                       Begin
                         GetMatchArmBindingInfo(CaseNode, BIdx, MT, BName, TVar,
                                                BType);
                         If (BName <> '') And (BName <> '_') Then
                           PopMatchBindings(1);
                       End;
                 End;
             End;
    End;
End;
End;

Procedure TDelSafeEmitterPascal.CollectMapsFromType(Const AType: String; Tags,
                                                   Keys, Vals: TStrings);

Var 
  K, V, Tag: string;
Begin
  If IsMapType(AType, K, V) Then
    Begin
      Tag := MapTag(K, V);
      If Tags.IndexOf(Tag) = -1 Then
        Begin
          Tags.Add(Tag);
          Keys.Add(K);
          Vals.Add(V);
        End;
    End;
End;

Procedure TDelSafeEmitterPascal.CollectMapsFromExpr(Expr: TASTExpr; Tags, Keys,
                                                   Vals: TStrings);

Var 
  I: Integer;
Begin
  If Not Assigned(Expr) Then Exit;
  If Expr is TASTMapLiteralExpr Then
    Begin
      CollectMapsFromType(GetExprTypeName(Expr), Tags, Keys, Vals);
      For I := 0 To TASTMapLiteralExpr(Expr).Keys.Count - 1 Do
        Begin
          CollectMapsFromExpr(TASTExpr(TASTMapLiteralExpr(Expr).Keys[I]), Tags,
          Keys, Vals);
          CollectMapsFromExpr(TASTExpr(TASTMapLiteralExpr(Expr).Values[I]), Tags
          , Keys, Vals);
        End;
    End
  Else If Expr is TASTBinaryExpr Then
         Begin
           CollectMapsFromExpr(TASTBinaryExpr(Expr).Left, Tags, Keys, Vals);
           CollectMapsFromExpr(TASTBinaryExpr(Expr).Right, Tags, Keys, Vals);
         End
  Else If Expr is TASTUnaryExpr Then
         CollectMapsFromExpr(TASTUnaryExpr(Expr).Expr, Tags, Keys, Vals)
  Else If Expr is TASTMemberAccessExpr Then
         CollectMapsFromExpr(TASTMemberAccessExpr(Expr).Target, Tags, Keys, Vals
         )
  Else If Expr is TASTCallExpr Then
         Begin
           For I := 0 To TASTCallExpr(Expr).Args.Count - 1 Do
             CollectMapsFromExpr(TASTCallArg(TASTCallExpr(Expr).Args[I]).Expr,
             Tags, Keys, Vals);
         End
  Else If Expr is TASTIndexExpr Then
         Begin
           CollectMapsFromExpr(TASTIndexExpr(Expr).Target, Tags, Keys, Vals);
           For I := 0 To TASTIndexExpr(Expr).Indices.Count - 1 Do
             CollectMapsFromExpr(TASTExpr(TASTIndexExpr(Expr).Indices[I]), Tags,
             Keys, Vals);
         End
  Else If Expr is TASTIfExpr Then
         Begin
           CollectMapsFromExpr(TASTIfExpr(Expr).Condition, Tags, Keys, Vals);
           CollectMapsFromExpr(TASTIfExpr(Expr).ThenExpr, Tags, Keys, Vals);
           CollectMapsFromExpr(TASTIfExpr(Expr).ElseExpr, Tags, Keys, Vals);
         End
  Else If Expr is TASTMatchExpr Then
         Begin
           CollectMapsFromExpr(TASTMatchExpr(Expr).Expr, Tags, Keys, Vals);
           For I := 0 To TASTMatchExpr(Expr).Cases.Count - 1 Do
             Begin
               CollectMapsFromExpr(TASTMatchCase(TASTMatchExpr(Expr).Cases[I]).
               Guard, Tags, Keys, Vals);
               CollectMapsFromExpr(TASTMatchCase(TASTMatchExpr(Expr).Cases[I]).
               ValueExpr, Tags, Keys, Vals);
             End;
         End;
End;

Procedure TDelSafeEmitterPascal.CollectMapsFromStmts(Stmts: TASTNodeList; Tags,
                                                    Keys, Vals: TStrings);

Var 
  I, K: Integer;
  S: TASTStmt;
Begin
  If Not Assigned(Stmts) Then Exit;
  For I := 0 To Stmts.Count - 1 Do
    Begin
      S := TASTStmt(Stmts[I]);
      If S is TASTVarDeclStmt Then
        Begin
          For K := 0 To TASTVarDeclStmt(S).Decls.Count - 1 Do
            Begin
              CollectMapsFromType(TASTVarDecl(TASTVarDeclStmt(S).Decls[K]).
              TypeName, Tags, Keys, Vals);
              CollectMapsFromExpr(TASTVarDecl(TASTVarDeclStmt(S).Decls[K]).
              InitialExpr, Tags, Keys, Vals);
            End;
        End
      Else If S is TASTAssignStmt Then
             Begin
               CollectMapsFromExpr(TASTAssignStmt(S).Target, Tags, Keys, Vals);
               CollectMapsFromExpr(TASTAssignStmt(S).Expr, Tags, Keys, Vals);
             End
      Else If S is TASTCallStmt Then
             CollectMapsFromExpr(TASTCallStmt(S).CallExpr, Tags, Keys, Vals)
      Else If S is TASTReturnStmt Then
             CollectMapsFromExpr(TASTReturnStmt(S).Expr, Tags, Keys, Vals)
      Else If S is TASTIfStmt Then
             Begin
               CollectMapsFromExpr(TASTIfStmt(S).Condition, Tags, Keys, Vals);
               CollectMapsFromStmts(TASTIfStmt(S).ThenBranch, Tags, Keys, Vals);
               CollectMapsFromStmts(TASTIfStmt(S).ElseBranch, Tags, Keys, Vals);
             End
      Else If S is TASTWhileStmt Then
             Begin
               CollectMapsFromExpr(TASTWhileStmt(S).Condition, Tags, Keys, Vals)
               ;
               CollectMapsFromStmts(TASTWhileStmt(S).Body, Tags, Keys, Vals);
             End
      Else If S is TASTForStmt Then
             Begin
               CollectMapsFromExpr(TASTForStmt(S).CollectionExpr, Tags, Keys,
               Vals);
               CollectMapsFromStmts(TASTForStmt(S).Body, Tags, Keys, Vals);
             End
      Else If S is TASTRepeatStmt Then
             Begin
               CollectMapsFromStmts(TASTRepeatStmt(S).Body, Tags, Keys, Vals);
               CollectMapsFromExpr(TASTRepeatStmt(S).Condition, Tags, Keys, Vals
               );
             End
      Else If S is TASTUnsafeStmt Then
             CollectMapsFromStmts(TASTUnsafeStmt(S).Body, Tags, Keys, Vals)
      Else If S is TASTTryStmt Then
             Begin
               CollectMapsFromStmts(TASTTryStmt(S).TryBody, Tags, Keys, Vals);
               CollectMapsFromStmts(TASTTryStmt(S).ExceptBody, Tags, Keys, Vals)
               ;
             End
      Else If S is TASTMatchStmt Then
             Begin
               CollectMapsFromExpr(TASTMatchStmt(S).Expr, Tags, Keys, Vals);
               For K := 0 To TASTMatchStmt(S).Cases.Count - 1 Do
                 Begin
                   CollectMapsFromExpr(TASTMatchCase(TASTMatchStmt(S).Cases[K]).
                   Guard, Tags, Keys, Vals);
                   CollectMapsFromStmts(TASTMatchCase(TASTMatchStmt(S).Cases[K])
                   .Body, Tags, Keys, Vals);
                 End;
             End;
    End;
End;

Procedure TDelSafeEmitterPascal.CollectMapsFromModule(AModule: TASTModule; Tags,
                                                     Keys, Vals: TStrings);

Var 
  I, J: Integer;
  Rec: TASTRecordDecl;
  Func: TASTFunction;
Begin
  For I := 0 To AModule.Types.Count - 1 Do
    Begin
      If AModule.Types[I] is TASTMapDecl Then
        CollectMapsFromType(TASTMapDecl(AModule.Types[I]).Name, Tags, Keys, Vals
        )
      Else If AModule.Types[I] is TASTRecordDecl Then
             Begin
               Rec := TASTRecordDecl(AModule.Types[I]);
               For J := 0 To Rec.Fields.Count - 1 Do
                 CollectMapsFromType(TASTRecordField(Rec.Fields[J]).TypeName,
                 Tags, Keys, Vals);
             End
      Else If AModule.Types[I] is TASTArrayDecl Then
             CollectMapsFromType(TASTArrayDecl(AModule.Types[I]).ElemType, Tags,
             Keys, Vals);
    End;
  For I := 0 To AModule.Functions.Count - 1 Do
    Begin
      Func := TASTFunction(AModule.Functions[I]);
      FCurrentFunc := Func;
      CollectMapsFromType(Func.ReturnType, Tags, Keys, Vals);
      For J := 0 To Func.Params.Count - 1 Do
        CollectMapsFromType(TASTParam(Func.Params[J]).TypeName, Tags, Keys, Vals
        );
      For J := 0 To Func.LocalVars.Count - 1 Do
        Begin
          CollectMapsFromType(TASTVarDecl(Func.LocalVars[J]).TypeName, Tags,
          Keys, Vals);
          CollectMapsFromExpr(TASTVarDecl(Func.LocalVars[J]).InitialExpr, Tags,
          Keys, Vals);
        End;
      CollectMapsFromStmts(Func.Body, Tags, Keys, Vals);
      FCurrentFunc := Nil;
    End;
  For I := 0 To AModule.ModuleVars.Count - 1 Do
    Begin
      CollectMapsFromType(TASTVarDecl(AModule.ModuleVars[I]).TypeName, Tags,
      Keys, Vals);
      CollectMapsFromExpr(TASTVarDecl(AModule.ModuleVars[I]).InitialExpr, Tags,
      Keys, Vals);
    End;
  CollectMapsFromStmts(AModule.InitBody, Tags, Keys, Vals);
  CollectMapsFromStmts(AModule.FiniBody, Tags, Keys, Vals);
  If Assigned(AModule.ProgramBlock) Then
    Begin
      FProgramBlock := AModule.ProgramBlock;
      For I := 0 To AModule.ProgramBlock.LocalVars.Count - 1 Do
        Begin
          CollectMapsFromType(TASTVarDecl(AModule.ProgramBlock.LocalVars[I]).
          TypeName, Tags, Keys, Vals);
          CollectMapsFromExpr(TASTVarDecl(AModule.ProgramBlock.LocalVars[I]).
          InitialExpr, Tags, Keys, Vals);
        End;
      CollectMapsFromStmts(AModule.ProgramBlock.Body, Tags, Keys, Vals);
      FProgramBlock := Nil;
    End;
End;

Procedure TDelSafeEmitterPascal.EmitMapRuntimeDecls(Tags, Keys, Vals: TStrings;
                                                   BuiltinOnly: Boolean);

Var 
  I: Integer;
  IsBuiltin: Boolean;
Begin
  For I := 0 To Tags.Count - 1 Do
    Begin
      IsBuiltin := IsBuiltinMapSideType(Keys[I]) And IsBuiltinMapSideType(Vals[I
                   ]);
      If IsBuiltin = BuiltinOnly Then
        Begin
          Emit(Format('  TDelSafeMapEntry_%s = record', [Tags[I]]));
          Emit(Format('    key: %s;', [EmitTypeRef(Keys[I])]));
          Emit(Format('    val: %s;', [EmitTypeRef(Vals[I])]));
          Emit('  end;');
          Emit(Format('  TDelSafeMap_%s = record', [Tags[I]]));
          Emit(Format('    entries: array of TDelSafeMapEntry_%s;', [Tags[I]]));
          Emit('    count: Int32;');
          Emit('  end;');
        End;
    End;
End;

Procedure TDelSafeEmitterPascal.EmitMapRuntimeHelpers(Tags, Keys, Vals: TStrings;
                                                     DeclOnly: Boolean);

Var 
  I: Integer;
  Tag, PK, PV, DefStmt: string;
Begin
  For I := 0 To Tags.Count - 1 Do
    Begin
      Tag := Tags[I];
      PK := EmitTypeRef(Keys[I]);
      PV := EmitTypeRef(Vals[I]);

      If DeclOnly Then
        Begin
          Emit(Format(

    'procedure DelSafeMapSet_%s(var m: TDelSafeMap_%s; const k: %s; const v: %s);'
               , [Tag, Tag, PK, PV]));
          Emit(Format(

            'function DelSafeMapGet_%s(const m: TDelSafeMap_%s; const k: %s): %s;'
               , [Tag, Tag, PK, PV]));
          Emit(Format(

  'function DelSafeMapContains_%s(const m: TDelSafeMap_%s; const k: %s): Boolean;'
               , [Tag, Tag, PK]));
          Emit(Format(

              'procedure DelSafeMapRemove_%s(var m: TDelSafeMap_%s; const k: %s);'
               , [Tag, Tag, PK]));
        End
      Else
        Begin
          Emit(Format(

    'procedure DelSafeMapSet_%s(var m: TDelSafeMap_%s; const k: %s; const v: %s);'
               , [Tag, Tag, PK, PV]));
          Emit('var i: Int32;');
          Emit('begin');
          Emit('  for i := 0 to m.count - 1 do');
          Emit(

      '    if m.entries[i].key = k then begin m.entries[i].val := v; Exit; end;'
          );
          Emit('  if m.count >= Length(m.entries) then');
          Emit('  begin');
          Emit('    if Length(m.entries) = 0 then SetLength(m.entries, 8)');
          Emit('    else SetLength(m.entries, Length(m.entries) * 2);');
          Emit('  end;');
          Emit('  m.entries[m.count].key := k;');
          Emit('  m.entries[m.count].val := v;');
          Emit('  Inc(m.count);');
          Emit('end;');
          Emit('');

          If Vals[I] = 'String' Then DefStmt := '  Result := '''';'
          Else If Vals[I] = 'Bool' Then DefStmt := '  Result := False;'
          Else If Vals[I] = 'Char' Then DefStmt := '  Result := #0;'
          Else If (Vals[I] = 'Float32') Or (Vals[I] = 'Float64') Then DefStmt :=

                                                              '  Result := 0.0;'
          Else If IsIntegerType(Vals[I]) Then DefStmt := '  Result := 0;'
          Else If (Pos('^', Vals[I]) = 1) Or (Vals[I] = 'Pointer') Or (Pos(
                  'Box<', Vals[I]) > 0) Then DefStmt := '  Result := nil;'
          Else DefStmt := '  FillChar(Result, SizeOf(Result), 0);';

          Emit(Format(

            'function DelSafeMapGet_%s(const m: TDelSafeMap_%s; const k: %s): %s;'
               , [Tag, Tag, PK, PV]));
          Emit('var i: Int32;');
          Emit('begin');
          Emit('  for i := 0 to m.count - 1 do');
          Emit('    if m.entries[i].key = k then Exit(m.entries[i].val);');
          Emit(DefStmt);
          Emit('end;');
          Emit('');

          Emit(Format(

  'function DelSafeMapContains_%s(const m: TDelSafeMap_%s; const k: %s): Boolean;'
               , [Tag, Tag, PK]));
          Emit('var i: Int32;');
          Emit('begin');
          Emit('  for i := 0 to m.count - 1 do');
          Emit('    if m.entries[i].key = k then Exit(True);');
          Emit('  Result := False;');
          Emit('end;');
          Emit('');

          Emit(Format(

              'procedure DelSafeMapRemove_%s(var m: TDelSafeMap_%s; const k: %s);'
               , [Tag, Tag, PK]));
          Emit('var i: Int32;');
          Emit('begin');
          Emit('  for i := 0 to m.count - 1 do');
          Emit('    if m.entries[i].key = k then');
          Emit('    begin');
          Emit('      Dec(m.count);');
          Emit('      m.entries[i] := m.entries[m.count];');
          Emit('      Exit;');
          Emit('    end;');
          Emit('end;');
          Emit('');
        End;
    End;
End;

Function TDelSafeEmitterPascal.GetExprTypeName(Expr: TASTExpr): string;

Var 
  Id: TASTIdentifierExpr;
  Acc: TASTMemberAccessExpr;
  Call: TASTCallExpr;
  Bin: TASTBinaryExpr;
  TargetType, CleanTarget, KeyType, ValType, LeftType: string;
  I, J, P1, P2: Integer;
  Rec: TASTRecordDecl;
  V: TASTVarDecl;
  P: TASTParam;
  FnParams: TStringList;
Begin
  Result := '';
  If Not Assigned(Expr) Then Exit;

  If Expr is TASTLiteralExpr Then
    Begin
      Case TASTLiteralExpr(Expr).Kind Of 
        lkInt: Exit('Int32');
        lkFloat: Exit('Float64');
        lkBool: Exit('Bool');
        lkString: Exit('String');
        lkChar: Exit('Char');
      End;
    End;

  If Expr is TASTIdentifierExpr Then
    Begin
      Id := TASTIdentifierExpr(Expr);
      If Id.IsFnValueRef And (Id.ResolvedFnType <> '') Then
        Exit(Id.ResolvedFnType);
      If Id.ResolvedMonadType <> '' Then
        Exit(Id.ResolvedMonadType);
      For I := FMatchBindNames.Count - 1 Downto 0 Do
        If SameText(FMatchBindNames[I], Id.Name) Then
          Exit(FMatchBindTypes[I]);
      If Assigned(FCurrentFunc) And SameText(Id.Name, 'result') Then
        Exit(FCurrentFunc.ReturnType);
      If Assigned(FCurrentFunc) Then
        Begin
          For I := 0 To FCurrentFunc.LocalVars.Count - 1 Do
            Begin
              V := TASTVarDecl(FCurrentFunc.LocalVars[I]);
              If SameText(V.Name, Id.Name) Then Exit(V.TypeName);
            End;
          For I := 0 To FCurrentFunc.Params.Count - 1 Do
            Begin
              P := TASTParam(FCurrentFunc.Params[I]);
              If SameText(P.Name, Id.Name) Then Exit(P.TypeName);
            End;
          LeftType := FindInlineVarType(FCurrentFunc.Body, Id.Name);
          If LeftType <> '' Then Exit(LeftType);
        End;
      If Assigned(FProgramBlock) Then
        Begin
          For I := 0 To FProgramBlock.LocalVars.Count - 1 Do
            Begin
              V := TASTVarDecl(FProgramBlock.LocalVars[I]);
              If SameText(V.Name, Id.Name) Then Exit(V.TypeName);
            End;
          LeftType := FindInlineVarType(FProgramBlock.Body, Id.Name);
          If LeftType <> '' Then Exit(LeftType);
        End;
      If Assigned(FModule) Then
        Begin
          For I := 0 To FModule.Constants.Count - 1 Do
            If SameText(TASTConstDecl(FModule.Constants[I]).Name, Id.Name) Then
              Exit(TASTConstDecl(FModule.Constants[I]).TypeName);
          For I := 0 To FModule.Types.Count - 1 Do
            If FModule.Types[I] is TASTEnumDecl Then
              For J := 0 To TASTEnumDecl(FModule.Types[I]).Variants.Count - 1 Do
                If SameText(TASTEnumVariant(TASTEnumDecl(FModule.Types[I]).
                   Variants[J]).Name, Id.Name) Then
                  Exit(TASTEnumDecl(FModule.Types[I]).Name);
        End;
    End
  Else If Expr is TASTMemberAccessExpr Then
         Begin
           Acc := TASTMemberAccessExpr(Expr);
           If (Acc.Target is TASTIdentifierExpr) And IsEnumName(
              TASTIdentifierExpr(Acc.Target).Name) Then
             Exit(TASTIdentifierExpr(Acc.Target).Name);
           TargetType := ResolveAliasType(GetExprTypeName(Acc.Target));
           If (Pos('Result', TargetType) = 1) Then
             Begin
               If SameText(Acc.Member, 'is_ok') Or SameText(Acc.Member, 'is_err'
                  ) Then Exit('Bool');
               SplitResultTypes(TargetType, KeyType, ValType);
               If SameText(Acc.Member, 'value') Then Exit(KeyType);
               If SameText(Acc.Member, 'error') Then Exit(ValType);
             End;
           If (Pos('Option<', TargetType) = 1) Then
             Begin
               If SameText(Acc.Member, 'is_some') Or SameText(Acc.Member,
                  'is_none') Then Exit('Bool');
               If SameText(Acc.Member, 'value') Then
                 Begin
                   CleanTarget := SafeUnwrapGeneric(TargetType, 'Option');
                   If Pos('Box<', CleanTarget) = 1 Then
                     CleanTarget := SafeUnwrapGeneric(CleanTarget, 'Box');
                   Exit(CleanTarget);
                 End;
             End;
           If Pos('Box<', TargetType) > 0 Then
             Begin
               CleanTarget := TargetType;
               If Pos('Option<', CleanTarget) = 1 Then
                 CleanTarget := SafeUnwrapGeneric(CleanTarget, 'Option');
               If Pos('Box<', CleanTarget) = 1 Then
                 CleanTarget := SafeUnwrapGeneric(CleanTarget, 'Box');
             End
           Else If Pos('Option<', TargetType) = 1 Then
                  Begin
                    CleanTarget := SafeUnwrapGeneric(TargetType, 'Option');
                    If Pos('Box<', CleanTarget) = 1 Then
                      CleanTarget := SafeUnwrapGeneric(CleanTarget, 'Box');
                  End
           Else
             CleanTarget := TargetType;

           If Assigned(FModule) Then
             Begin
               For I := 0 To FModule.Types.Count - 1 Do
                 Begin
                   If (FModule.Types[I] is TASTRecordDecl) And SameText(
                      TASTRecordDecl(FModule.Types[I]).Name, CleanTarget) Then
                     Begin
                       Rec := TASTRecordDecl(FModule.Types[I]);
                       For J := 0 To Rec.Fields.Count - 1 Do
                         Begin
                           If SameText(TASTRecordField(Rec.Fields[J]).Name, Acc.
                              Member) Then
                             Exit(TASTRecordField(Rec.Fields[J]).TypeName);
                         End;
                     End;
                 End;
             End;
         End
  Else If Expr is TASTBinaryExpr Then
         Begin
           Bin := TASTBinaryExpr(Expr);
           If (Bin.Op = '+') And ((GetExprTypeName(Bin.Left) = 'String') Or (
              GetExprTypeName(Bin.Right) = 'String')) Then
             Exit('String');
           If (Bin.Op = '=') Or (Bin.Op = '<>') Or (Bin.Op = '<') Or (Bin.Op =
              '<=') Or
              (Bin.Op = '>') Or (Bin.Op = '>=') Or SameText(Bin.Op, 'implies')
              Or SameText(Bin.Op, 'in') Then
             Exit('Bool');
           If SameText(Bin.Op, 'and') Or SameText(Bin.Op, 'or') Then
             Begin
               LeftType := GetExprTypeName(Bin.Left);
               If LeftType = 'Bool' Then Exit('Bool');
               If IsIntegerType(LeftType) Then Exit(LeftType);
             End;
           If SameText(Bin.Op, 'shl') Or SameText(Bin.Op, 'shr') Or SameText(Bin
              .Op, 'xor') Or
              SameText(Bin.Op, 'div') Or SameText(Bin.Op, 'mod') Or
              (Bin.Op = '+') Or (Bin.Op = '-') Or (Bin.Op = '*') Or (Bin.Op =
              '/') Then
             Begin
               LeftType := GetExprTypeName(Bin.Left);
               If LeftType <> '' Then Exit(LeftType);
               Exit(GetExprTypeName(Bin.Right));
             End;
         End
  Else If Expr is TASTIndexExpr Then
         Begin
           If TASTIndexExpr(Expr).Target is TASTSetLiteralExpr Then
             Begin
               If TASTSetLiteralExpr(TASTIndexExpr(Expr).Target).Elements.Count
                  > 0 Then
                 Exit(GetExprTypeName(TASTExpr(TASTSetLiteralExpr(TASTIndexExpr(
                      Expr).Target).Elements[0])));
             End;
           TargetType := ResolveAliasType(GetExprTypeName(TASTIndexExpr(Expr).
                         Target));
           If TargetType = 'String' Then
             Exit('Char')
           Else If IsMapType(TargetType, KeyType, ValType) Then
                  Exit(ValType)
           Else If Pos('array of ', TargetType) = 1 Then
                  Exit(Trim(Copy(TargetType, 10, Length(TargetType))))
           Else If Pos('] of ', TargetType) > 0 Then
                  Exit(Trim(Copy(TargetType, Pos('] of ', TargetType) + 5,
                  Length(TargetType))))
           Else If Assigned(FModule) Then
                  Begin
                    For I := 0 To FModule.Types.Count - 1 Do
                      If (FModule.Types[I] is TASTArrayDecl) And SameText(
                         TASTArrayDecl(FModule.Types[I]).Name, TargetType) Then
                        Exit(TASTArrayDecl(FModule.Types[I]).ElemType);
                  End;
         End
  Else If Expr is TASTUnaryExpr Then
         Begin
           TargetType := ResolveAliasType(GetExprTypeName(TASTUnaryExpr(Expr).
                         Expr));
           If TASTUnaryExpr(Expr).Op = '?' Then
             Begin
               If Pos('Result', TargetType) = 1 Then
                 Begin
                   SplitResultTypes(TargetType, KeyType, ValType);
                   Exit(KeyType);
                 End
               Else If Pos('Option<', TargetType) = 1 Then
                      Exit(Trim(Copy(TargetType, 8, Length(TargetType) - 8)));
             End
           Else If TASTUnaryExpr(Expr).Op = '@' Then
                  Exit('^' + TargetType)
           Else If (TASTUnaryExpr(Expr).Op = '^') And (Pos('^', TargetType) = 1)
                  Then
                  Exit(Copy(TargetType, 2, Length(TargetType)))
           Else If SameText(TASTUnaryExpr(Expr).Op, 'not') Or (TASTUnaryExpr(
                   Expr).Op = '-') Then
                  Exit(TargetType);
         End
  Else If Expr is TASTMapLiteralExpr Then
         Begin
           If TASTMapLiteralExpr(Expr).Keys.Count > 0 Then
             Begin
               KeyType := GetExprTypeName(TASTExpr(TASTMapLiteralExpr(Expr).Keys
                          [0]));
               ValType := GetExprTypeName(TASTExpr(TASTMapLiteralExpr(Expr).
                          Values[0]));
               If (KeyType <> '') And (ValType <> '') Then
                 Exit(Format('map[%s]%s', [KeyType, ValType]));
             End;
         End
  Else If Expr is TASTMatchExpr Then
         Begin
           For I := 0 To TASTMatchExpr(Expr).Cases.Count - 1 Do
             Begin
               LeftType := ResolveAliasType(GetExprTypeName(TASTMatchCase(
                           TASTMatchExpr(Expr).Cases[I]).ValueExpr));
               If LeftType <> '' Then Exit(LeftType);
             End;
         End
  Else If Expr is TASTIfExpr Then
         Begin
           LeftType := ResolveAliasType(GetExprTypeName(TASTIfExpr(Expr).
                       ThenExpr));
           CleanTarget := ResolveAliasType(GetExprTypeName(TASTIfExpr(Expr).
                          ElseExpr));
           If (LeftType = 'Float64') Or (CleanTarget = 'Float64') Then Exit(

                                                                       'Float64'
             );
           If (LeftType = 'Float32') Or (CleanTarget = 'Float32') Then Exit(

                                                                       'Float32'
             );
           If (LeftType = 'Int64') Or (CleanTarget = 'Int64') Then Exit('Int64')
           ;
           If (LeftType = 'UInt64') Or (CleanTarget = 'UInt64') Then Exit(

                                                                        'UInt64'
             );
           If LeftType <> '' Then Exit(LeftType);
           Exit(CleanTarget);
         End
  Else If Expr is TASTTupleLiteralExpr Then
         Exit(TASTTupleLiteralExpr(Expr).ResolvedType)
  Else If Expr is TASTLambdaExpr Then
         Exit(TASTLambdaExpr(Expr).ResolvedFnType)
  Else If Expr is TASTAwaitExpr Then
         Begin
           If TASTAwaitExpr(Expr).ResolvedInnerType <> '' Then
             Exit(TASTAwaitExpr(Expr).ResolvedInnerType);
           TargetType := ResolveAliasType(GetExprTypeName(TASTAwaitExpr(Expr).
                         Expr));
           If (Copy(TargetType, 1, 5) = 'Task<') And (TargetType[Length(
              TargetType)] = '>') Then
             Exit(Copy(TargetType, 6, Length(TargetType) - 6));
           Exit(TargetType);
         End
  Else If Expr is TASTSpawnExpr Then
         Begin
           If TASTSpawnExpr(Expr).ResolvedTaskType <> '' Then
             Exit(TASTSpawnExpr(Expr).ResolvedTaskType);
           TargetType := GetExprTypeName(TASTSpawnExpr(Expr).CallExpr);
           If (Copy(TargetType, 1, 5) = 'Task<') And (TargetType[Length(
              TargetType)] = '>') Then
             Exit(TargetType);
           Exit('Task<' + TargetType + '>');
         End
  Else If Expr is TASTCallExpr Then
         Begin
           Call := TASTCallExpr(Expr);
           If Call.IsIndirectCall And (Call.IndirectFnType <> '') Then
             Begin
               FnParams := TStringList.Create;
               Try
                 If SplitFnType(Call.IndirectFnType, FnParams, TargetType) Then
                   Exit(TargetType);
               Finally
                 FnParams.Free;
             End;
         End;
  If Call.ResolvedMonadType <> '' Then Exit(Call.ResolvedMonadType);
  If Call.Callee = 'Box' Then Exit('Box');
  If (Call.Callee = 'Ok') And (Call.Args.Count >= 1) Then
    Begin
      TargetType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).
                    Expr));
      If TargetType = '' Then TargetType := 'Int32';
      Exit('Result<' + TargetType + ', Int32>');
    End;
  If Call.Callee = 'Err' Then
    Begin
      If Call.Args.Count >= 1 Then
        TargetType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0])
                      .Expr))
      Else
        TargetType := 'Int32';
      If TargetType = '' Then TargetType := 'Int32';
      Exit('Result<Int32, ' + TargetType + '>');
    End;
  If Call.Callee = 'Some' Then
    Begin
      If Call.Args.Count >= 1 Then
        TargetType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0])
                      .Expr))
      Else
        TargetType := '';
      If (TargetType <> '') And (TargetType <> 'Box') And (Pos('Box<',
         TargetType) <> 1) And
         (Pos('^', TargetType) <> 1) And (TargetType <> 'Pointer') Then
        Exit('Option<' + TargetType + '>')
      Else
        Exit('Option');
    End;
  If Pos('.', Call.Callee) > 0 Then
    Begin
      LeftType := Copy(Call.Callee, 1, Pos('.', Call.Callee) - 1);
      If IsEnumName(LeftType) Then
        Exit(LeftType);
    End;
  If SameText(Call.Callee, 'Default') And (Call.Args.Count = 1) And (TASTCallArg
     (Call.Args[0]).Expr is TASTIdentifierExpr) Then
    Exit(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name);
  If (Call.Callee = 'ReadFile') Or (Call.Callee = 'CharAt') Or (Call.Callee =
     'Substring') Or (Call.Callee = 'ToString') Or
     (Call.Callee = 'IntToStr') Or (Call.Callee = 'FloatToStr') Or (Call.Callee
     = 'BoolToStr') Or (Call.Callee = 'CharToStr') Or
     (Call.Callee = '__InterpToStr') Or (Call.Callee = '__JsonGetStr') Or (Call.
     Callee = '__JsonGetObj') Or
     (Call.Callee = 'SocketRecv') Or (Call.Callee = 'SocketRecvHex') Or (Call.
     Callee = 'SocketPeerIP') Or
     (Call.Callee = 'CharFromByte') Or (Call.Callee = 'ParamStr') Or
     SameText(Call.Callee, 'Trim') Or SameText(Call.Callee, 'UpperCase') Or
     SameText(Call.Callee, 'LowerCase') Or SameText(Call.Callee, 'Replace') Or
     SameText(Call.Callee, 'Join') Or SameText(Call.Callee, 'PadLeft') Or
     SameText(Call.Callee, 'PadRight') Or
     SameText(Call.Callee, 'RepeatStr') Or SameText(Call.Callee, 'ReadLn') Or
     SameText(Call.Callee, 'GetEnv') Then Exit('String');
  If SameText(Call.Callee, 'Split') Or SameText(Call.Callee, 'ListDir') Then
    Exit('array of String');
  If SameText(Call.Callee, 'TryStrToInt') Then Exit('Option<Int32>');
  If SameText(Call.Callee, 'TryStrToFloat') Then Exit('Option<Float64>');
  If SameText(Call.Callee, 'NewChannel') And (Call.GenericArgs.Count = 1) Then
    Exit('Channel<' + Call.GenericArgs[0] + '>');
  If (SameText(Call.Callee, 'Recv') Or SameText(Call.Callee, 'TryRecv')) And (
     Call.Args.Count >= 1) Then
    Begin
      TargetType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).
                    Expr));
      If (Copy(TargetType, 1, 8) = 'Channel<') And (TargetType[Length(TargetType
         )] = '>') Then
        Exit('Option<' + Trim(Copy(TargetType, 9, Length(TargetType) - 9)) + '>'
        );
    End;
  If SameText(Call.Callee, 'Send') Or SameText(Call.Callee, 'TrySend') Or
     SameText(Call.Callee, 'IsChannelEmpty') Or SameText(Call.Callee,
     'IsChannelFull') Or
     SameText(Call.Callee, 'IsChannelClosed') Or (Call.Callee =
     '__SyncAtomicCas') Or
     (Call.Callee = '__SyncMutexTryLock') Then Exit('Bool');
  If (Call.Callee = '__SyncAtomicNew') Or (Call.Callee = '__SyncMutexNew') Then
    Exit('Pointer');
  If (Call.Callee = '__SyncAtomicLoad') Or (Call.Callee = '__SyncAtomicAdd') Or
     SameText(Call.Callee, 'ChannelLen') Then Exit('Int32');
  If (Call.Callee = '__SyncAtomicStore') Or (Call.Callee = '__SyncAtomicFree')
     Or
     (Call.Callee = '__SyncMutexLock') Or (Call.Callee = '__SyncMutexUnlock') Or
     (Call.Callee = '__SyncMutexFree') Or SameText(Call.Callee, 'CloseChannel')
     Or
     SameText(Call.Callee, 'DestroyChannel') Then Exit('Void');
  If (Call.Callee = '__JsonGetInt') Then Exit('Int32');
  If (Call.Callee = '__JsonGetFloat') Then Exit('Float64');
  If (Call.Callee = '__JsonGetBool') Or (Call.Callee = '__JsonHasValue') Then
    Exit('Bool');
  If (Call.Callee = '__JsonGetChar') Or SameText(Call.Callee, 'Chr') Or SameText
     (Call.Callee, 'Char') Then Exit('Char');
  If SameText(Call.Callee, 'Slice') And (Call.Args.Count >= 1) Then
    Begin
      TargetType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).
                    Expr));
      Exit(TargetType);
    End;
  If SameText(Call.Callee, 'Abs') And (Call.Args.Count = 1) Then
    Begin
      TargetType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).
                    Expr));
      If TargetType = '' Then Exit('Int32');
      Exit(TargetType);
    End;
  If (SameText(Call.Callee, 'Min') Or SameText(Call.Callee, 'Max') Or SameText(
     Call.Callee, 'Clamp')) And (Call.Args.Count >= 2) Then
    Begin
      LeftType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).
                  Expr));
      CleanTarget := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[1]).
                     Expr));
      If (LeftType = 'Float64') Or (CleanTarget = 'Float64') Then Exit('Float64'
        );
      If (LeftType = 'Float32') Or (CleanTarget = 'Float32') Then Exit('Float32'
        );
      If (LeftType = 'Int64') Or (CleanTarget = 'Int64') Then Exit('Int64');
      If (LeftType = 'UInt64') Or (CleanTarget = 'UInt64') Then Exit('UInt64');
      If LeftType <> '' Then Exit(LeftType);
      Exit(CleanTarget);
    End;
  If SameText(Call.Callee, 'Pop') And (Call.Args.Count = 1) Then
    Begin
      TargetType := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).
                    Expr));
      If Pos('array of ', TargetType) = 1 Then
        Exit(Trim(Copy(TargetType, 10, Length(TargetType))));
      If Assigned(FModule) Then
        For I := 0 To FModule.Types.Count - 1 Do
          If (FModule.Types[I] is TASTArrayDecl) And SameText(TASTArrayDecl(
             FModule.Types[I]).Name, TargetType) Then
            Exit(TASTArrayDecl(FModule.Types[I]).ElemType);
    End;
  If SameText(Call.Callee, 'Length') Or SameText(Call.Callee, 'Count') Or
     SameText(Call.Callee, 'Ord') Or SameText(Call.Callee, 'SizeOf') Or
     SameText(Call.Callee, 'IndexOf') Or (Call.Callee = 'StrToInt') Or SameText(
     Call.Callee, 'RandomInt') Or (Call.Callee = 'SocketCreate') Or
     (Call.Callee = 'SocketListen') Or (Call.Callee = 'SocketAccept') Or (Call.
     Callee = 'SocketConnect') Or
     (Call.Callee = 'SocketSend') Or (Call.Callee = 'SocketSendHex') Or (Call.
     Callee = 'ByteAt') Or (Call.Callee = 'ParamCount') Then Exit('Int32');
  If SameText(Call.Callee, 'sin') Or SameText(Call.Callee, 'cos') Or SameText(
     Call.Callee, 'tan') Or
     SameText(Call.Callee, 'sqrt') Or SameText(Call.Callee, 'floor') Or SameText
     (Call.Callee, 'ceil') Or
     SameText(Call.Callee, 'round') Or SameText(Call.Callee, 'pow') Or SameText(
     Call.Callee, 'exp') Or
     SameText(Call.Callee, 'log') Or SameText(Call.Callee, 'atan2') Or SameText(
     Call.Callee, 'RandomFloat') Or
     SameText(Call.Callee, 'StrToFloat') Or (Call.Callee = 'Now') Then Exit(

                                                                       'Float64'
    );
  If (Call.Callee = 'GetTickCount64') Or (Call.Callee = 'GetNanoseconds') Then
    Exit('UInt64');
  If (Call.Callee = 'FileSize') Or (Call.Callee = 'SocketSendFile') Then Exit('Int64');
  If SameText(Call.Callee, 'Contains') Or SameText(Call.Callee, 'StartsWith') Or
     SameText(Call.Callee, 'EndsWith') Or
     (Call.Callee = 'FileExists') Or (Call.Callee = 'WriteFile') Or (Call.Callee
     = 'CreateDir') Or (Call.Callee = 'RemoveDir') Or
     (Call.Callee = 'DeleteFile') Or (Call.Callee = 'DirExists') Or (Call.Callee
     = 'SocketSetTimeout') Or
     SameText(Call.Callee, 'SetEnv') Or SameText(Call.Callee, 'CopyFile') Or
     SameText(Call.Callee, 'RenameFile') Then Exit('Bool');
  If SameText(Call.Callee, 'Clear') Or SameText(Call.Callee, 'Delete') Or
     SameText(Call.Callee, 'Insert') Or
     SameText(Call.Callee, 'Inc') Or SameText(Call.Callee, 'Dec') Or SameText(
     Call.Callee, 'Remove') Or
     SameText(Call.Callee, 'Print') Or (Call.Callee = 'SocketClose') Or (Call.
     Callee = 'Assert') Or (Call.Callee = 'SleepMs') Then Exit('Void');
  If IsTypeIdentifier(Call.Callee) Then Exit(Call.Callee);
  If Assigned(FModule) Then
    Begin
      For I := 0 To FModule.Functions.Count - 1 Do
        If SameText(TASTFunction(FModule.Functions[I]).Name, Call.Callee) Then
          Begin
            If TASTFunction(FModule.Functions[I]).IsAsync Then
              Exit('Task<' + TASTFunction(FModule.Functions[I]).ReturnType + '>'
              )
            Else
              Exit(TASTFunction(FModule.Functions[I]).ReturnType);
          End;
    End;
End;
End;

Function TDelSafeEmitterPascal.IsPointerTarget(Expr: TASTExpr): Boolean;

Var 
  T: string;
Begin
  T := ResolveAliasType(GetExprTypeName(Expr));
  Result := (Pos('Box<', T) > 0) Or (Pos('Pointer', T) > 0) Or (T = 'Box') Or (
            Pos('^', T) = 1);
End;

Function FormatPascalArrayType(Const S: String): string;

Var 
  P1, P2, I, DimVal: Integer;
  DimsPart, ElemPart, ResultDims: string;
  DimsList: TStringList;
Begin
  P1 := Pos('[', S);
  P2 := Pos('] of ', S);
  If (P1 > 0) And (P2 > P1) Then
    Begin
      DimsPart := Copy(S, P1 + 1, P2 - P1 - 1);
      ElemPart := Copy(S, P2 + 5, Length(S));
      DimsList := TStringList.Create;
      Try
        DimsList.CommaText := DimsPart;
        ResultDims := '';
        For I := 0 To DimsList.Count - 1 Do
          Begin
            DimVal := StrToIntDef(Trim(DimsList[I]), 1);
            If I > 0 Then ResultDims := ResultDims + ', ';
            ResultDims := ResultDims + Format('0..%d', [DimVal - 1]);
          End;
        Result := Format('array[%s] of %s', [ResultDims, Trim(ElemPart)]);
      Finally
        DimsList.Free;
    End;
End
Else
  Result := S;
End;

Function TDelSafeEmitterPascal.EmitTypeRef(Const AType: String): string;

Var 
  Inner, Inner2, ValT, ErrT: string;
Begin
  If AType = 'Bool' Then Result := 'Boolean'
  Else If AType = 'Float32' Then Result := 'Single'
  Else If AType = 'Float64' Then Result := 'Double'
  Else If AType = 'Void' Then Result := ''
  Else If (AType = 'Int8') Or (AType = 'Int16') Or (AType = 'Int32') Or (AType =
          'Int64') Or
          (AType = 'UInt8') Or (AType = 'UInt16') Or (AType = 'UInt32') Or (
          AType = 'UInt64') Or
          (AType = 'Char') Or (AType = 'String') Or (AType = 'Pointer') Then
         Result := AType
  Else If Pos('^', AType) = 1 Then
         Begin
           Inner := Trim(Copy(AType, 2, Length(AType)));
           If (Inner = 'Int8') Or (Inner = 'Int16') Or (Inner = 'Int32') Or (
              Inner = 'Int64') Or
              (Inner = 'UInt8') Or (Inner = 'UInt16') Or (Inner = 'UInt32') Or (
              Inner = 'UInt64') Or
              (Inner = 'Float32') Or (Inner = 'Float64') Or (Inner = 'Bool') Or
              (Inner = 'Char') Or
              (Inner = 'String') Then
             Result := 'PDelSafePtr_' + Inner
           Else If IsRecordName(Inner) Or (Assigned(FindEnumDecl(Inner)) And
                   FindEnumDecl(Inner).HasPayload) Then
                  Result := 'PT' + Inner
           Else
             Result := '^' + EmitTypeRef(Inner);
         End
  Else If Pos('array of ', AType) = 1 Then
         Begin
           Inner := Trim(Copy(AType, 10, Length(AType)));
           If (Inner = 'Int8') Or (Inner = 'Int16') Or (Inner = 'Int32') Or (
              Inner = 'Int64') Or
              (Inner = 'UInt8') Or (Inner = 'UInt16') Or (Inner = 'UInt32') Or (
              Inner = 'UInt64') Or
              (Inner = 'Float32') Or (Inner = 'Float64') Or (Inner = 'Bool') Or
              (Inner = 'Char') Or
              (Inner = 'String') Or (Inner = 'Pointer') Then
             Result := 'TDelSafeDyn_' + Inner
           Else
             Result := 'TDelSafeDyn_' + MangleTypeTag(Inner);
         End
  Else If IsTypedResult(AType, ValT, ErrT) Then
         Result := 'TDelSafeRes_' + MangleTypeTag(ValT) + '__' + MangleTypeTag(
                   ErrT)
  Else If Pos('Result', AType) = 1 Then
         Result := 'TResultDoubleError'
  Else If Pos('array[', AType) = 1 Then
         Result := FormatPascalArrayType(AType)
  Else If Pos('set of ', AType) = 1 Then
         Result := 'set of ' + EmitTypeRef(Trim(Copy(AType, 8, Length(AType))))
  Else If Pos('Box<', AType) > 0 Then
         Begin
           Inner := AType;
           If Pos('Option<', Inner) = 1 Then
             Inner := SafeUnwrapGeneric(Inner, 'Option');
           If Pos('Box<', Inner) = 1 Then
             Inner := SafeUnwrapGeneric(Inner, 'Box');
           Result := 'P' + EmitTypeRef(Inner);
         End
  Else If (Copy(AType, 1, 5) = 'Task<') And (AType[Length(AType)] = '>') Then
         Begin
           Inner := Copy(AType, 6, Length(AType) - 6);
           If Inner = '' Then Inner := 'Void';
           Result := 'TDelSafeTask_' + MangleTypeTag(Inner);
         End
  Else If (Copy(AType, 1, 8) = 'Channel<') And (AType[Length(AType)] = '>') Then
         Begin
           Inner := Copy(AType, 9, Length(AType) - 9);
           If Inner = '' Then Inner := 'Int32';
           Result := 'TDelSafeChan_' + MangleTypeTag(Inner);
         End
  Else If IsTypedValueOption(AType, Inner) Then
         Result := 'TDelSafeOpt_' + MangleTypeTag(Inner)
  Else If Pos('Option<', AType) = 1 Then
         Begin
           If IsValueOptionType(AType) Then
             Result := 'TDelSafeOption'
           Else
             Begin
               Inner := SafeUnwrapGeneric(AType, 'Option');
               Result := EmitTypeRef(Inner);
             End;
         End
  Else If IsMapType(AType, Inner, Inner2) Then
         Result := 'TDelSafeMap_' + MapTag(Inner, Inner2)
  Else If Pos('fn(', AType) = 1 Then
         Result := 'TDelSafeFn_' + FnTypeTag(AType)
  Else
    Result := 'T' + AType;
End;

Function TDelSafeEmitterPascal.EmitExpr(Expr: TASTExpr): string;

Var 
  Lit: TASTLiteralExpr;
  Id: TASTIdentifierExpr;
  Acc: TASTMemberAccessExpr;
  Bin: TASTBinaryExpr;
  Un: TASTUnaryExpr;
  Call: TASTCallExpr;
  Idx: TASTIndexExpr;
  SetLit: TASTSetLiteralExpr;
  ArgsStr, KeyT, ValT, TargetT, ValF, ErrF, RetT, RetValF, RetErrF, MTag,
  RetMTag, ErrValExpr: string;
  I, BindCount, BIdx: Integer;
  TargetStr, ScruVar, BName, TVar, BType: string;
  IsWild, OpTyped, RetTyped: Boolean;
  BindVarT: string;
  Enm: TASTEnumDecl;
  VarN: TASTEnumVariant;
  MC: TASTMatchCase;
  TargetFn: TASTFunction;
  ArgItemStr: string;
Begin
  If Not Assigned(Expr) Then Exit('');

  If Expr is TASTLiteralExpr Then
    Begin
      Lit := TASTLiteralExpr(Expr);
      Case Lit.Kind Of 
        lkInt:    Result := NormalizeIntLit(Lit.Value);
        lkString: Result := EscapePascalString(Lit.Value);
        lkChar:   Result := EscapePascalChar(Lit.Value);
        lkBool:   Result := LowerCase(Lit.Value);
        lkNil:    Result := 'nil';
        Else
          Result := Lit.Value;
      End;
      Exit;
    End;

  If Expr is TASTIdentifierExpr Then
    Begin
      Id := TASTIdentifierExpr(Expr);
      For I := FGuardBindNames.Count - 1 Downto 0 Do
        If SameText(FGuardBindNames[I], Id.Name) Then
          Exit('(' + FGuardBindExprs[I] + ')');
      For I := FSpawnRefNames.Count - 1 Downto 0 Do
        If SameText(FSpawnRefNames[I], Id.Name) Then
          Exit(FSpawnRefTargets[I]);
      For I := FMatchBindNames.Count - 1 Downto 0 Do
        If SameText(FMatchBindNames[I], Id.Name) Then
          Exit(FMatchBindTargets[I]);
      If Id.Name = '__ValueNone' Then
        Begin
          If (Id.ResolvedMonadType <> '') And IsTypedValueOption(Id.
             ResolvedMonadType, ValF) Then
            Result := 'DelSafeNone_' + MangleTypeTag(ValF) + '()'
          Else
            Result := 'DelSafeNone()';
        End
      Else If Id.Name = 'None' Then
             Result := 'nil'
      Else If FindEnumVariantUnqualified(Id.Name, Enm, VarN) Then
             Begin
               If Enm.HasPayload Then
                 Result := Enm.Name + '_' + VarN.Name + '()'
               Else
                 Result := Enm.Name + '_' + VarN.Name;
             End
      Else If Id.IsFnValueRef And (Id.ResolvedFnType <> '') Then
             Result := Format('DelSafeMakeFn_%s(@__delsafe_thunk_%s, nil)', [
                       FnTypeTag(Id.ResolvedFnType), Id.Name])
      Else
        Result := Id.Name;
      Exit;
    End;

  If Expr is TASTMemberAccessExpr Then
    Begin
      Acc := TASTMemberAccessExpr(Expr);
      If (Acc.Target is TASTIdentifierExpr) And IsModulePrefixName(
         TASTIdentifierExpr(Acc.Target).Name) Then
        Exit(Acc.Member);
      TargetStr := EmitExpr(Acc.Target);
      TargetT := ResolveAliasType(GetExprTypeName(Acc.Target));
      // Case Enum.Variant or Alias.Enum.Variant
      If ((Acc.Target is TASTIdentifierExpr) And IsEnumName(TASTIdentifierExpr(
         Acc.Target).Name)) Or
         ((Acc.Target is TASTMemberAccessExpr) And IsEnumName(TargetStr)) Then
        Begin
          If Acc.Target is TASTIdentifierExpr Then
            Enm := FindEnumDecl(TASTIdentifierExpr(Acc.Target).Name)
          Else
            Enm := FindEnumDecl(TargetStr);
          If Assigned(Enm) And Enm.HasPayload Then
            Result := TargetStr + '_' + Acc.Member + '()'
          Else
            Result := TargetStr + '_' + Acc.Member;
        End
      Else If IsTypedResult(TargetT, ValF, ErrF) Then
             Result := TargetStr + '.' + Acc.Member
      Else If Pos('Result', TargetT) = 1 Then
             Begin
               If Acc.Member = 'value' Then
                 Begin
                   SplitResultTypes(TargetT, ValF, ErrF);
                   Result := EmitMonadFieldExtract(TargetStr, ValF, 'value',
                             'str_val');
                 End
               Else If Acc.Member = 'error' Then
                      Begin
                        SplitResultTypes(TargetT, ValF, ErrF);
                        If ResolveAliasType(ErrF) = 'String' Then
                          Result := TargetStr + '.err_str'
                        Else
                          Result := Format('%s(%s.error)', [EmitTypeRef(ErrF),
                                    TargetStr]);
                      End
               Else
                 Result := TargetStr + '.' + Acc.Member;
             End
      Else If IsTypedValueOption(TargetT, ValF) Then
             Result := TargetStr + '.' + Acc.Member
      Else If IsValueOptionType(TargetT) Then
             Begin
               If Acc.Member = 'is_some' Then
                 Result := TargetStr + '.is_some'
               Else If Acc.Member = 'is_none' Then
                      Result := TargetStr + '.is_none'
               Else If Acc.Member = 'value' Then
                      Begin
                        ValF := SafeUnwrapGeneric(TargetT, 'Option');
                        Result := EmitMonadFieldExtract(TargetStr, ValF,
                                  'num_val', 'str_val');
                      End
               Else
                 Result := TargetStr + '.' + Acc.Member;
             End
      Else If Acc.Member = 'is_some' Then
             Result := '(' + TargetStr + ' <> nil)'
      Else If Acc.Member = 'is_none' Then
             Result := '(' + TargetStr + ' = nil)'
      Else If IsPointerTarget(Acc.Target) Then
             Begin
               If Acc.Member = 'value' Then
                 Result := TargetStr + '^'
               Else
                 Result := TargetStr + '^.' + Acc.Member;
             End
      Else
        Begin
          If Acc.Member = 'value' Then
            Result := TargetStr
          Else
            Result := TargetStr + '.' + Acc.Member;
        End;
      Exit;
    End;

  If Expr is TASTBinaryExpr Then
    Begin
      Bin := TASTBinaryExpr(Expr);
      If Bin.Op = 'implies' Then
        Result := Format('((not (%s)) or (%s))', [EmitExpr(Bin.Left), EmitExpr(
                  Bin.Right)])
      Else If Bin.Op = '/' Then
             Begin
               If (Bin.Right is TASTLiteralExpr) And (Pos('.', TASTLiteralExpr(
                  Bin.Right).Value) > 0) Then
                 Result := Format('(%s / %s)', [EmitExpr(Bin.Left), EmitExpr(Bin
                           .Right)])
               Else If (Bin.Left is TASTLiteralExpr) And (Pos('.',
                       TASTLiteralExpr(Bin.Left).Value) > 0) Then
                      Result := Format('(%s / %s)', [EmitExpr(Bin.Left),
                                EmitExpr(Bin.Right)])
               Else If IsIntegerType(GetExprTypeName(Bin.Left)) And
                       IsIntegerType(GetExprTypeName(Bin.Right)) Then
                      Result := Format('(%s div %s)', [EmitExpr(Bin.Left),
                                EmitExpr(Bin.Right)])
               Else
                 Result := Format('(%s / %s)', [EmitExpr(Bin.Left), EmitExpr(Bin
                           .Right)]);
             End
      Else
        Result := Format('(%s %s %s)', [EmitExpr(Bin.Left), Bin.Op, EmitExpr(Bin
                  .Right)]);
      Exit;
    End;

  If Expr is TASTUnaryExpr Then
    Begin
      Un := TASTUnaryExpr(Expr);
      If Un.Op = '?' Then
        Begin
          TargetT := ResolveAliasType(GetExprTypeName(Un.Expr));
          TargetStr := Format('_delsafe_try_%d_%d', [Un.Line, Un.Col]);
          Emit(Format('%s := %s;', [TargetStr, EmitExpr(Un.Expr)]));
          RetT := '';
          If Assigned(FCurrentFunc) Then RetT := ResolveAliasType(FCurrentFunc.
                                                 ReturnType);

          If Pos('Result', TargetT) = 1 Then
            Begin
              SplitResultTypes(TargetT, ValF, ErrF);
              OpTyped := IsTypedResult(TargetT, ValF, ErrF);
              RetTyped := (RetT <> '') And IsTypedResult(RetT, RetValF, RetErrF)
              ;
              Emit(Format('if %s.is_err then', [TargetStr]));
              Emit('begin');
              IncIndent;
              If FActiveDefers.Count > 0 Then EmitActiveDefers(0);
              If Not OpTyped And Not RetTyped Then
                Emit(Format('Exit(%s);', [TargetStr]))
              Else If OpTyped And RetTyped Then
                     Begin
                       MTag := MangleTypeTag(ValF) + '__' + MangleTypeTag(ErrF);
                       RetMTag := MangleTypeTag(RetValF) + '__' + MangleTypeTag(
                                  RetErrF);
                       If MTag = RetMTag Then
                         Emit(Format('Exit(%s);', [TargetStr]))
                       Else
                         Emit(Format('Exit(DelSafeErr_%s(%s.error));', [RetMTag,
                              TargetStr]));
                     End
              Else If (Not OpTyped) And RetTyped Then
                     Begin
                       RetMTag := MangleTypeTag(RetValF) + '__' + MangleTypeTag(
                                  RetErrF);
                       If ResolveAliasType(ErrF) = 'String' Then
                         ErrValExpr := TargetStr + '.err_str'
                       Else
                         ErrValExpr := Format('%s(%s.error)', [EmitTypeRef(ErrF)
                                       , TargetStr]);
                       Emit(Format('Exit(DelSafeErr_%s(%s));', [RetMTag,
                            ErrValExpr]));
                     End
              Else
                Begin
                  If ResolveAliasType(ErrF) = 'String' Then
                    Emit(Format('Exit(DelSafeErr(%s.error));', [TargetStr]))
                  Else
                    Emit(Format('Exit(DelSafeErr(Integer(%s.error)));', [
                         TargetStr]));
                End;
              DecIndent;
              Emit('end;');
              If OpTyped Then
                Result := TargetStr + '.value'
              Else
                Result := EmitMonadFieldExtract(TargetStr, ValF, 'value',
                          'str_val');
            End
          Else If IsValueOptionType(TargetT) Then
                 Begin
                   OpTyped := IsTypedValueOption(TargetT, ValF);
                   If Not OpTyped Then ValF := SafeUnwrapGeneric(TargetT,
                                               'Option');
                   RetTyped := (RetT <> '') And IsTypedValueOption(RetT, RetValF
                               );
                   Emit(Format('if %s.is_none then', [TargetStr]));
                   Emit('begin');
                   IncIndent;
                   If FActiveDefers.Count > 0 Then EmitActiveDefers(0);
                   If RetTyped Then
                     Emit(Format('Exit(DelSafeNone_%s());', [MangleTypeTag(
                          RetValF)]))
                   Else If (RetT = '') Or IsValueOptionType(RetT) Then
                          Emit('Exit(DelSafeNone());')
                   Else
                     Emit('Exit(nil);');
                   DecIndent;
                   Emit('end;');
                   If OpTyped Then
                     Result := TargetStr + '.value'
                   Else
                     Result := EmitMonadFieldExtract(TargetStr, ValF, 'num_val',
                               'str_val');
                 End
          Else
            Begin
              RetTyped := (RetT <> '') And IsTypedValueOption(RetT, RetValF);
              Emit(Format('if %s = nil then', [TargetStr]));
              Emit('begin');
              IncIndent;
              If FActiveDefers.Count > 0 Then EmitActiveDefers(0);
              If RetTyped Then
                Emit(Format('Exit(DelSafeNone_%s());', [MangleTypeTag(RetValF)]))
              Else
                Emit('Exit(nil);');
              DecIndent;
              Emit('end;');
              Result := TargetStr;
            End;
          Exit;
        End;
      If Un.Op = '@' Then
        Result := '(@' + EmitExpr(Un.Expr) + ')'
      Else If Un.Op = '^' Then
             Result := EmitExpr(Un.Expr) + '^'
      Else
        Result := Format('(%s %s)', [Un.Op, EmitExpr(Un.Expr)]);
      Exit;
    End;

  If Expr is TASTAwaitExpr Then
    Begin
      TargetT := ResolveAliasType(GetExprTypeName(TASTAwaitExpr(Expr).Expr));
      If (Copy(TargetT, 1, 5) = 'Task<') And (TargetT[Length(TargetT)] = '>')
        Then
        ValF := Trim(Copy(TargetT, 6, Length(TargetT) - 6))
      Else
        ValF := TASTAwaitExpr(Expr).ResolvedInnerType;
      If ValF = '' Then ValF := 'Void';
      MTag := RegisterTaskType('Task<' + ValF + '>');
      Result := Format('DelSafeAwaitTask_%s(%s)', [MTag, EmitExpr(TASTAwaitExpr(
                Expr).Expr)]);
      Exit;
    End;

  If Expr is TASTSpawnExpr Then
    Begin
      RegisterSpawn(TASTSpawnExpr(Expr));
      If TASTSpawnExpr(Expr).ResolvedTaskType <> '' Then
        RegisterTaskType(TASTSpawnExpr(Expr).ResolvedTaskType);
      ArgsStr := '';
      For I := 0 To TASTSpawnExpr(Expr).CaptureNames.Count - 1 Do
        Begin
          If I > 0 Then ArgsStr := ArgsStr + ', ';
          ArgsStr := ArgsStr + TASTSpawnExpr(Expr).CaptureNames[I];
        End;
      Result := Format('__delsafe_spawn_%d(%s)', [TASTSpawnExpr(Expr).SpawnId,
                ArgsStr]);
      Exit;
    End;

  If Expr is TASTIndexExpr Then
    Begin
      Idx := TASTIndexExpr(Expr);
      If Idx.Target is TASTSetLiteralExpr Then
        Begin
          ValF := ResolveAliasType(GetExprTypeName(Idx));
          If ValF = '' Then ValF := 'Int32';
          ArgsStr := '';
          For I := 0 To TASTSetLiteralExpr(Idx.Target).Elements.Count - 1 Do
            Begin
              If I > 0 Then ArgsStr := ArgsStr + ', ';
              ArgsStr := ArgsStr + EmitExpr(TASTExpr(TASTSetLiteralExpr(Idx.
                         Target).Elements[I]));
            End;
          TargetStr := EmitTypeRef('array of ' + ValF);
          Result := Format('%s.Create(%s)[%s]', [TargetStr, ArgsStr, EmitExpr(
                    TASTExpr(Idx.Indices[0]))]);
          Exit;
        End;
      TargetT := ResolveAliasType(GetExprTypeName(Idx.Target));
      If TargetT = 'String' Then
        Begin
          Result := Format('%s[(%s) + 1]', [EmitExpr(Idx.Target), EmitExpr(
                    TASTExpr(Idx.Indices[0]))]);
          Exit;
        End;
      If IsMapType(TargetT, KeyT, ValT) Then
        Begin
          Result := Format('DelSafeMapGet_%s(%s, %s)', [MapTag(KeyT, ValT),
                    EmitExpr(Idx.Target), EmitExpr(TASTExpr(Idx.Indices[0]))]);
          Exit;
        End;
      TargetStr := EmitExpr(Idx.Target);
      ArgsStr := '';
      For I := 0 To Idx.Indices.Count - 1 Do
        Begin
          If I > 0 Then ArgsStr := ArgsStr + ', ';
          ArgsStr := ArgsStr + EmitExpr(TASTExpr(Idx.Indices[I]));
        End;
      Result := Format('%s[%s]', [TargetStr, ArgsStr]);
      Exit;
    End;

  If Expr is TASTSetLiteralExpr Then
    Begin
      SetLit := TASTSetLiteralExpr(Expr);
      ArgsStr := '';
      For I := 0 To SetLit.Elements.Count - 1 Do
        Begin
          If I > 0 Then ArgsStr := ArgsStr + ', ';
          ArgsStr := ArgsStr + EmitExpr(TASTExpr(SetLit.Elements[I]));
        End;
      Result := Format('[%s]', [ArgsStr]);
      Exit;
    End;

  If Expr is TASTMapLiteralExpr Then
    Begin
      TargetStr := Format('_delsafe_mlit_%d_%d', [Expr.Line, Expr.Col]);
      EmitMapLiteralAssign(TargetStr, GetExprTypeName(Expr), TASTMapLiteralExpr(

                                                                            Expr
      ));
      Result := TargetStr;
      Exit;
    End;

  If Expr is TASTCallExpr Then
    Begin
      Call := TASTCallExpr(Expr);
      If Call.IsIndirectCall Then
        Begin
          If Assigned(Call.CalleeExpr) Then
            TargetStr := EmitExpr(Call.CalleeExpr)
          Else
            TargetStr := Call.Callee;
          ArgsStr := '';
          For I := 0 To Call.Args.Count - 1 Do
            Begin
              If I > 0 Then ArgsStr := ArgsStr + ', ';
              ArgsStr := ArgsStr + EmitExpr(TASTCallArg(Call.Args[I]).Expr);
            End;
          If ArgsStr <> '' Then
            Result := Format('DelSafeCallFn_%s(%s, %s)', [FnTypeTag(Call.
                      IndirectFnType), TargetStr, ArgsStr])
          Else
            Result := Format('DelSafeCallFn_%s(%s)', [FnTypeTag(Call.
                      IndirectFnType), TargetStr]);
          Exit;
        End;

      // PrintLn / Print translates to WriteLn / Write or Format(...)
      If (Call.Callee = 'PrintLn') Or (Call.Callee = 'Print') Then
        Begin
          If Call.Args.Count = 1 Then
            Begin
              If Call.Callee = 'PrintLn' Then
                Result := 'WriteLn(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr)
                          + ')'
              Else
                Result := 'Write(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) +
                          ')';
            End
          Else
            Begin
              ArgsStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ', [';
              For I := 1 To Call.Args.Count - 1 Do
                Begin
                  ArgsStr := ArgsStr + EmitExpr(TASTCallArg(Call.Args[I]).Expr);
                  If I < Call.Args.Count - 1 Then
                    ArgsStr := ArgsStr + ', ';
                End;
              ArgsStr := ArgsStr + ']';
              If Call.Callee = 'PrintLn' Then
                Result := 'WriteLn(Format(' + ArgsStr + '))'
              Else
                Result := 'Write(Format(' + ArgsStr + '))';
            End;
          Exit;
        End;

      If (Call.Callee = 'Float64') And (Call.Args.Count = 1) Then
        Begin
          Result := 'Double(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
          Exit;
        End;

      If (Call.Callee = 'Float32') And (Call.Args.Count = 1) Then
        Begin
          Result := 'Single(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
          Exit;
        End;

      // Ok, Err, and Some constructors
      If Call.Callee = 'Ok' Then
        Begin
          If (Call.ResolvedMonadType <> '') And IsTypedResult(Call.
             ResolvedMonadType, ValF, ErrF) Then
            Begin
              MTag := MangleTypeTag(ValF) + '__' + MangleTypeTag(ErrF);
              Result := Format('DelSafeOk_%s(%s)', [MTag, EmitExpr(TASTCallArg(
                        Call.Args[0]).Expr)]);
            End
          Else
            Begin
              TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[
                         0]).Expr));
              If TargetT = 'Char' Then
                Result := 'DelSafeOk(Ord(' + EmitExpr(TASTCallArg(Call.Args[0]).
                          Expr) + '))'
              Else
                Result := 'DelSafeOk(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr)
                          + ')';
            End;
          Exit;
        End;

      If Call.Callee = 'Err' Then
        Begin
          If (Call.ResolvedMonadType <> '') And IsTypedResult(Call.
             ResolvedMonadType, ValF, ErrF) Then
            Begin
              MTag := MangleTypeTag(ValF) + '__' + MangleTypeTag(ErrF);
              Result := Format('DelSafeErr_%s(%s)', [MTag, EmitExpr(TASTCallArg(
                        Call.Args[0]).Expr)]);
            End
          Else
            Begin
              TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[
                         0]).Expr));
              If TargetT = 'String' Then
                Result := 'DelSafeErr(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr
                          ) + ')'
              Else
                Result := 'DelSafeErr(Integer(' + EmitExpr(TASTCallArg(Call.Args[
                          0]).Expr) + '))';
            End;
          Exit;
        End;

      If Call.Callee = 'Some' Then
        Begin
          If IsPointerTarget(TASTCallArg(Call.Args[0]).Expr) Then
            Result := EmitExpr(TASTCallArg(Call.Args[0]).Expr)
          Else
            Begin
              MTag := Call.ResolvedMonadType;
              If MTag = '' Then
                MTag := 'Option<' + ResolveAliasType(GetExprTypeName(TASTCallArg
                        (Call.Args[0]).Expr)) + '>';
              If IsTypedValueOption(MTag, ValF) Then
                Result := Format('DelSafeSome_%s(%s)', [MangleTypeTag(ValF),
                          EmitExpr(TASTCallArg(Call.Args[0]).Expr)])
              Else
                Begin
                  TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.
                             Args[0]).Expr));
                  If TargetT = 'Char' Then
                    Result := 'DelSafeSome(Ord(' + EmitExpr(TASTCallArg(Call.Args
                              [0]).Expr) + '))'
                  Else
                    Result := 'DelSafeSome(' + EmitExpr(TASTCallArg(Call.Args[0])
                              .Expr) + ')';
                End;
            End;
          Exit;
        End;

      If Call.Callee = 'Box' Then
        Begin
          Result := 'DelSafeBox(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) +
                    ')';
          Exit;
        End;

      If Call.Callee = '__InterpToStr' Then
        Begin
          Result := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
          Exit;
        End;

      If Call.Callee = 'CharToStr' Then
        Begin
          Result := 'String(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
          Exit;
        End;

      If SameText(Call.Callee, 'Length') Or SameText(Call.Callee, 'Count') Then
        Begin
          If IsMapType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr), KeyT,
             ValT) Then
            Result := EmitExpr(TASTCallArg(Call.Args[0]).Expr) + '.count'
          Else
            Begin
              TargetStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
              Result := 'Int32(Length(' + TargetStr + '))';
            End;
          Exit;
        End;

      If SameText(Call.Callee, 'Default') Then
        Begin
          TargetT := TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr).Name;
          Result := 'Default(' + EmitTypeRef(TargetT) + ')';
          Exit;
        End;

      If SameText(Call.Callee, 'Contains') Then
        Begin
          TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).
                     Expr));
          If TargetT = 'String' Then
            Result := Format('DelSafeStrContains(%s, %s)', [EmitExpr(TASTCallArg(
                      Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).
                      Expr)])
          Else
            Begin
              IsMapType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr), KeyT,
              ValT);
              Result := Format('DelSafeMapContains_%s(%s, %s)', [MapTag(KeyT,
                        ValT), EmitExpr(TASTCallArg(Call.Args[0]).Expr),
                        EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
            End;
          Exit;
        End;

      If SameText(Call.Callee, 'Trim') Then
        Begin
          Result := Format('DelSafeStrTrim(%s)', [EmitExpr(TASTCallArg(Call.Args[
                    0]).Expr)]);
          Exit;
        End;

      If SameText(Call.Callee, 'UpperCase') Then
        Begin
          Result := Format('DelSafeUpperCase(%s)', [EmitExpr(TASTCallArg(Call.
                    Args[0]).Expr)]);
          Exit;
        End;

      If SameText(Call.Callee, 'LowerCase') Then
        Begin
          Result := Format('DelSafeLowerCase(%s)', [EmitExpr(TASTCallArg(Call.
                    Args[0]).Expr)]);
          Exit;
        End;

      If SameText(Call.Callee, 'StartsWith') Then
        Begin
          Result := Format('DelSafeStartsWith(%s, %s)', [EmitExpr(TASTCallArg(
                    Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr
                    )]);
          Exit;
        End;

      If SameText(Call.Callee, 'EndsWith') Then
        Begin
          Result := Format('DelSafeEndsWith(%s, %s)', [EmitExpr(TASTCallArg(Call.
                    Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
          Exit;
        End;

      If SameText(Call.Callee, 'IndexOf') Then
        Begin
          Result := Format('DelSafeIndexOf(%s, %s)', [EmitExpr(TASTCallArg(Call.
                    Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
          Exit;
        End;

      If SameText(Call.Callee, 'Replace') Then
        Begin
          Result := Format('DelSafeStrReplace(%s, %s, %s)', [EmitExpr(TASTCallArg
                    (Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).
                    Expr), EmitExpr(TASTCallArg(Call.Args[2]).Expr)]);
          Exit;
        End;

      If SameText(Call.Callee, 'Split') Then
        Begin
          Result := Format('DelSafeStrSplit(%s, %s)', [EmitExpr(TASTCallArg(Call.
                    Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
          Exit;
        End;

      If SameText(Call.Callee, 'Join') Then
        Begin
          Result := Format('DelSafeStrJoin(%s, %s)', [EmitExpr(TASTCallArg(Call.
                    Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
          Exit;
        End;

      If SameText(Call.Callee, 'PadLeft') Or SameText(Call.Callee, 'PadRight')
        Then
        Begin
          If Call.Args.Count = 2 Then
            TargetStr := ''' '''
          Else
            Begin
              TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[
                         2]).Expr));
              If TargetT = 'Char' Then
                TargetStr := 'String(' + EmitExpr(TASTCallArg(Call.Args[2]).Expr
                             ) + ')'
              Else
                TargetStr := EmitExpr(TASTCallArg(Call.Args[2]).Expr);
            End;
          If SameText(Call.Callee, 'PadLeft') Then
            Result := Format('DelSafePadLeft(%s, %s, %s)', [EmitExpr(TASTCallArg(
                      Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).
                      Expr), TargetStr])
          Else
            Result := Format('DelSafePadRight(%s, %s, %s)', [EmitExpr(TASTCallArg
                      (Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).
                      Expr), TargetStr]);
          Exit;
        End;

      If SameText(Call.Callee, 'RepeatStr') Then
        Begin
          Result := Format('DelSafeRepeatStr(%s, %s)', [EmitExpr(TASTCallArg(Call
                    .Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
          Exit;
        End;

      If SameText(Call.Callee, 'Sqrt') Then
        Begin
          Result := 'System.Sqrt(Double(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + '))';
          Exit;
        End;

      If SameText(Call.Callee, 'Floor') Then
        Begin
          Result := 'Double(Math.Floor(Double(' + EmitExpr(TASTCallArg(Call.Args
                    [0]).Expr) + ')))';
          Exit;
        End;

      If SameText(Call.Callee, 'Ceil') Then
        Begin
          Result := 'Double(Math.Ceil(Double(' + EmitExpr(TASTCallArg(Call.Args[
                    0]).Expr) + ')))';
          Exit;
        End;

      If SameText(Call.Callee, 'Round') Then
        Begin
          Result := 'DelSafeRound(Double(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + '))';
          Exit;
        End;

      If SameText(Call.Callee, 'Pow') Then
        Begin
          Result := Format('Math.Power(Double(%s), Double(%s))', [EmitExpr(
                    TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.
                    Args[1]).Expr)]);
          Exit;
        End;

      If SameText(Call.Callee, 'Exp') Then
        Begin
          Result := 'System.Exp(Double(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + '))';
          Exit;
        End;

      If SameText(Call.Callee, 'Log') Then
        Begin
          Result := 'System.Ln(Double(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + '))';
          Exit;
        End;

      If SameText(Call.Callee, 'Sin') Then
        Begin
          Result := 'System.Sin(Double(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + '))';
          Exit;
        End;

      If SameText(Call.Callee, 'Cos') Then
        Begin
          Result := 'System.Cos(Double(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + '))';
          Exit;
        End;

      If SameText(Call.Callee, 'Tan') Then
        Begin
          Result := 'Math.Tan(Double(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr
                    ) + '))';
          Exit;
        End;

      If SameText(Call.Callee, 'Atan2') Then
        Begin
          Result := Format('Math.ArcTan2(Double(%s), Double(%s))', [EmitExpr(
                    TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.
                    Args[1]).Expr)]);
          Exit;
        End;

      If SameText(Call.Callee, 'RandomInt') Then
        Begin
          Result := Format('DelSafeRandomInt(%s, %s)', [EmitExpr(TASTCallArg(Call
                    .Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
          Exit;
        End;

      If SameText(Call.Callee, 'RandomFloat') Then
        Begin
          Result := 'DelSafeRandomFloat()';
          Exit;
        End;

      If SameText(Call.Callee, 'Abs') Then
        Begin
          Result := 'System.Abs(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) +
                    ')';
          Exit;
        End;

      If SameText(Call.Callee, 'Min') Then
        Begin
          TargetT := ResolveAliasType(GetExprTypeName(Call));
          If TargetT = '' Then TargetT := 'Int32';
          Result := Format('specialize DelSafeMin<%s>(%s, %s)', [EmitTypeRef(
                    TargetT), EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr
                    (TASTCallArg(Call.Args[1]).Expr)]);
          Exit;
        End;

      If SameText(Call.Callee, 'Max') Then
        Begin
          TargetT := ResolveAliasType(GetExprTypeName(Call));
          If TargetT = '' Then TargetT := 'Int32';
          Result := Format('specialize DelSafeMax<%s>(%s, %s)', [EmitTypeRef(
                    TargetT), EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr
                    (TASTCallArg(Call.Args[1]).Expr)]);
          Exit;
        End;

      If SameText(Call.Callee, 'Clamp') Then
        Begin
          TargetT := ResolveAliasType(GetExprTypeName(Call));
          If TargetT = '' Then TargetT := 'Int32';
          Result := Format('specialize DelSafeClamp<%s>(%s, %s, %s)', [
                    EmitTypeRef(TargetT), EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr), EmitExpr(
                    TASTCallArg(Call.Args[2]).Expr)]);
          Exit;
        End;

      If SameText(Call.Callee, 'Remove') Then
        Begin
          IsMapType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr), KeyT, ValT)
          ;
          Result := Format('DelSafeMapRemove_%s(%s, %s)', [MapTag(KeyT, ValT),
                    EmitExpr(TASTCallArg(Call.Args[0]).Expr), EmitExpr(
                    TASTCallArg(Call.Args[1]).Expr)]);
          Exit;
        End;

      If SameText(Call.Callee, 'SetLength') Then
        Begin
          Result := Format('SetLength(%s, %s)', [EmitExpr(TASTCallArg(Call.Args[
                    0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
          Exit;
        End;

      If SameText(Call.Callee, 'Push') Then
        Begin
          TargetStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
          Result := Format(

                  'begin SetLength(%s, Length(%s) + 1); %s[High(%s)] := %s; end'
                    ,
                    [TargetStr, TargetStr, TargetStr, TargetStr, EmitExpr(
                    TASTCallArg(Call.Args[1]).Expr)]);
          Exit;
        End;

      If SameText(Call.Callee, 'Pop') Then
        Begin
          TargetStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
          TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).
                     Expr));
          ValF := 'Int32';
          If Pos('array of ', TargetT) = 1 Then
            ValF := ResolveAliasType(Trim(Copy(TargetT, 10, Length(TargetT))))
          Else If Assigned(FModule) Then
                 For I := 0 To FModule.Types.Count - 1 Do
                   If (FModule.Types[I] is TASTArrayDecl) And SameText(
                      TASTArrayDecl(FModule.Types[I]).Name, TargetT) Then
                     ValF := ResolveAliasType(TASTArrayDecl(FModule.Types[I]).
                             ElemType);
          Result := Format('DelSafeDynPop_%s(%s)', [ValF, TargetStr]);
          Exit;
        End;

      If SameText(Call.Callee, 'Delete') Then
        Begin
          Result := Format('System.Delete(%s, %s, 1)', [EmitExpr(TASTCallArg(
                    Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr
                    )]);
          Exit;
        End;

      If SameText(Call.Callee, 'Insert') Then
        Begin
          Result := Format('System.Insert(%s, %s, %s)', [EmitExpr(TASTCallArg(
                    Call.Args[2]).Expr), EmitExpr(TASTCallArg(Call.Args[0]).Expr
                    ), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
          Exit;
        End;

      If SameText(Call.Callee, 'Slice') Then
        Begin
          Result := Format('System.Copy(%s, %s, %s)', [EmitExpr(TASTCallArg(Call
                    .Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr),
                    EmitExpr(TASTCallArg(Call.Args[2]).Expr)]);
          Exit;
        End;

      If SameText(Call.Callee, 'Clear') Then
        Begin
          TargetStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
          If IsMapType(GetExprTypeName(TASTCallArg(Call.Args[0]).Expr), KeyT,
             ValT) Then
            Result := Format('%s.count := 0', [TargetStr])
          Else
            Result := Format('SetLength(%s, 0)', [TargetStr]);
          Exit;
        End;

      If SameText(Call.Callee, 'Free') Or SameText(Call.Callee, 'Dispose') Then
        Begin
          TargetStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
          TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).
                     Expr));
          IsWild := (TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr) Or
                    (TASTCallArg(Call.Args[0]).Expr is TASTMemberAccessExpr);
          If IsDynamicArrayType(TargetT) Then
            Result := Format('SetLength(%s, 0)', [TargetStr])
          Else If IsMapType(TargetT, KeyT, ValT) Then
                 Result := Format(
                           'begin SetLength(%s.entries, 0); %s.count := 0; end',
                           [TargetStr, TargetStr])
          Else If SameText(TargetT, 'Pointer') Then
                 Begin
                   If IsWild Then
                     Result := Format(

                'begin if %s <> nil then begin FreeMem(%s); %s := nil; end; end'
                               , [TargetStr, TargetStr, TargetStr])
                   Else
                     Result := Format('FreeMem(%s)', [TargetStr]);
                 End
          Else
            Begin
              ArgsStr := '';
              If Pos('Box<', TargetT) = 1 Then
                Begin
                  ValF := Trim(Copy(TargetT, 5, Length(TargetT) - 5));
                  If FindDropFunc(ValF) <> Nil Then
                    ArgsStr := Format('%s(%s^); ', [FindDropFunc(ValF).Name,
                               TargetStr]);
                End;
              If IsWild Then
                Result := Format(

              'begin if %s <> nil then begin %sDispose(%s); %s := nil; end; end'
                          , [TargetStr, ArgsStr, TargetStr, TargetStr])
              Else
                Result := Format('Dispose(%s)', [TargetStr]);
            End;
          Exit;
        End;

      If SameText(Call.Callee, 'Inc') Or SameText(Call.Callee, 'Dec') Then
        Begin
          If Call.Args.Count = 2 Then
            Result := Format('%s(%s, %s)', [Call.Callee, EmitExpr(TASTCallArg(
                      Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).
                      Expr)])
          Else
            Result := Format('%s(%s)', [Call.Callee, EmitExpr(TASTCallArg(Call.
                      Args[0]).Expr)]);
          Exit;
        End;

      If SameText(Call.Callee, 'Ord') Then
        Begin
          Result := 'Int32(Ord(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) +
                    '))';
          Exit;
        End;

      If SameText(Call.Callee, 'Chr') Then
        Begin
          Result := 'Chr(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')';
          Exit;
        End;

      If SameText(Call.Callee, 'SizeOf') Then
        Begin
          If (TASTCallArg(Call.Args[0]).Expr is TASTIdentifierExpr) And
             IsTypeIdentifier(TASTIdentifierExpr(TASTCallArg(Call.Args[0]).Expr)
             .Name) Then
            Result := 'Int32(SizeOf(' + EmitTypeRef(TASTIdentifierExpr(
                      TASTCallArg(Call.Args[0]).Expr).Name) + '))'
          Else
            Result := 'Int32(SizeOf(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr)
                      + '))';
          Exit;
        End;

      If (Call.Args.Count = 1) And IsTypeIdentifier(Call.Callee) And Not
         IsEnumName(Call.Callee) And Not IsRecordName(Call.Callee) Then
        Begin
          ValF := ResolveAliasType(Call.Callee);
          TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).
                     Expr));
          If IsIntegerType(ValF) And ((TargetT = 'Float32') Or (TargetT =
             'Float64') Or (TargetT = 'FloatLiteral')) Then
            Result := EmitTypeRef(Call.Callee) + '(Trunc(' + EmitExpr(
                      TASTCallArg(Call.Args[0]).Expr) + '))'
          Else
            Result := EmitTypeRef(Call.Callee) + '(' + EmitExpr(TASTCallArg(Call
                      .Args[0]).Expr) + ')';
          Exit;
        End;

      If Call.Callee = '__JsonGetStr' Then
        Begin
          Result := 'DelSafeJsonGetStr(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) +
                    ')';
          Exit;
        End;

      If Call.Callee = '__JsonGetInt' Then
        Begin
          Result := 'DelSafeJsonGetInt(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) +
                    ')';
          Exit;
        End;

      If Call.Callee = '__JsonGetFloat' Then
        Begin
          Result := 'DelSafeJsonGetFloat(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) +
                    ')';
          Exit;
        End;

      If Call.Callee = '__JsonGetBool' Then
        Begin
          Result := 'DelSafeJsonGetBool(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) +
                    ')';
          Exit;
        End;

      If Call.Callee = '__JsonGetChar' Then
        Begin
          Result := 'DelSafeJsonGetChar(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) +
                    ')';
          Exit;
        End;

      If Call.Callee = '__JsonHasValue' Then
        Begin
          Result := 'DelSafeJsonHasValue(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) +
                    ')';
          Exit;
        End;

      If Call.Callee = '__JsonGetObj' Then
        Begin
          Result := 'DelSafeJsonGetObj(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) +
                    ')';
          Exit;
        End;

      If Call.Callee = 'CharAt' Then
        Begin
          Result := 'DelSafeCharAt(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) +
                    ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) + ')';
          Exit;
        End;

      If Call.Callee = 'ByteAt' Then
        Begin
          Result := 'DelSafeByteAt(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) +
                    ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) + ')';
          Exit;
        End;

      If Call.Callee = 'CharFromByte' Then
        Begin
          Result := 'DelSafeCharFromByte(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ')';
          Exit;
        End;

      If Call.Callee = 'Substring' Then
        Begin
          Result := 'DelSafeSubstring(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr
                    ) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) + ', ' +
                    EmitExpr(TASTCallArg(Call.Args[2]).Expr) + ')';
          Exit;
        End;

      If Call.Callee = 'FileExists' Then
        Begin
          Result := 'DelSafeFileExists(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ')';
          Exit;
        End;

      If Call.Callee = 'ReadFile' Then
        Begin
          Result := 'DelSafeReadFile(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr)
                    + ')';
          Exit;
        End;

      If Call.Callee = 'WriteFile' Then
        Begin
          Result := 'DelSafeWriteFile(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr
                    ) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) + ')';
          Exit;
        End;

      If Call.Callee = 'CreateDir' Then
        Begin
          Result := 'DelSafeCreateDir(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr
                    ) + ')';
          Exit;
        End;

      If Call.Callee = 'RemoveDir' Then
        Begin
          Result := 'DelSafeRemoveDir(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr
                    ) + ')';
          Exit;
        End;

      If Call.Callee = 'DeleteFile' Then
        Begin
          Result := 'DelSafeDeleteFile(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ')';
          Exit;
        End;

      If Call.Callee = 'DirExists' Then
        Begin
          Result := 'DelSafeDirExists(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr
                    ) + ')';
          Exit;
        End;

      If Call.Callee = 'FileSize' Then
        Begin
          Result := 'DelSafeFileSize(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr)
                    + ')';
          Exit;
        End;

      If SameText(Call.Callee, 'ListDir') Then
        Begin
          Result := 'DelSafeListDir(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr)
                    + ')';
          Exit;
        End;

      If SameText(Call.Callee, 'CopyFile') Then
        Begin
          Result := Format('DelSafeCopyFile(%s, %s)', [EmitExpr(TASTCallArg(Call.
                    Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
          Exit;
        End;

      If SameText(Call.Callee, 'RenameFile') Then
        Begin
          Result := Format('DelSafeRenameFile(%s, %s)', [EmitExpr(TASTCallArg(
                    Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr
                    )]);
          Exit;
        End;

      If SameText(Call.Callee, 'ReadLn') Then
        Begin
          Result := 'DelSafeReadLn()';
          Exit;
        End;

      If SameText(Call.Callee, 'GetEnv') Then
        Begin
          Result := 'DelSafeGetEnv(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) +
                    ')';
          Exit;
        End;

      If SameText(Call.Callee, 'SetEnv') Then
        Begin
          Result := Format('DelSafeSetEnv(%s, %s)', [EmitExpr(TASTCallArg(Call.
                    Args[0]).Expr), EmitExpr(TASTCallArg(Call.Args[1]).Expr)]);
          Exit;
        End;

      If Call.Callee = 'GetNanoseconds' Then
        Begin
          Result := 'DelSafeGetNanoseconds()';
          Exit;
        End;

      If Call.Callee = 'SleepMs' Then
        Begin
          Result := 'DelSafeSleepMs(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr)
                    + ')';
          Exit;
        End;

      If Call.Callee = 'IntToStr' Then
        Begin
          Result := 'IntToStr(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')'
          ;
          Exit;
        End;

      If Call.Callee = 'FloatToStr' Then
        Begin
          Result := 'DelSafeFloatToStr(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ')';
          Exit;
        End;

      If Call.Callee = 'BoolToStr' Then
        Begin
          Result := 'DelSafeBoolToStr(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr
                    ) + ')';
          Exit;
        End;

      If Call.Callee = 'StrToInt' Then
        Begin
          Result := 'StrToIntDef(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) +
                    ', 0)';
          Exit;
        End;

      If SameText(Call.Callee, 'StrToFloat') Then
        Begin
          Result := 'DelSafeStrToFloat(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ')';
          Exit;
        End;

      If SameText(Call.Callee, 'TryStrToInt') Then
        Begin
          Result := 'DelSafeTryStrToInt(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ')';
          Exit;
        End;

      If SameText(Call.Callee, 'TryStrToFloat') Then
        Begin
          Result := 'DelSafeTryStrToFloat(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ')';
          Exit;
        End;

      If Call.Callee = 'ParamCount' Then
        Begin
          Result := 'ParamCount';
          Exit;
        End;

      If Call.Callee = 'ParamStr' Then
        Begin
          Result := 'ParamStr(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')'
          ;
          Exit;
        End;

      If Call.Callee = 'Assert' Then
        Begin
          If Call.Args.Count = 1 Then
            Result := 'Assert(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) + ')'
          Else
            Result := 'Assert(' + EmitExpr(TASTCallArg(Call.Args[0]).Expr) +
                      ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) + ')';
          Exit;
        End;

      If Call.Callee = 'SocketCreate' Then
        Begin
          Result := 'DelSafeSocketCreate()';
          Exit;
        End;

      If Call.Callee = 'SocketListen' Then
        Begin
          Result := 'DelSafeSocketListen(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) +
                    ')';
          Exit;
        End;

      If Call.Callee = 'SocketAccept' Then
        Begin
          Result := 'DelSafeSocketAccept(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ')';
          Exit;
        End;

      If Call.Callee = 'SocketConnect' Then
        Begin
          Result := 'DelSafeSocketConnect(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) +
                    ')';
          Exit;
        End;

      If Call.Callee = 'SocketSend' Then
        Begin
          Result := 'DelSafeSocketSend(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) +
                    ')';
          Exit;
        End;

      If Call.Callee = 'SocketRecv' Then
        Begin
          Result := 'DelSafeSocketRecv(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) +
                    ')';
          Exit;
        End;

      If Call.Callee = 'SocketClose' Then
        Begin
          Result := 'DelSafeSocketClose(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ')';
          Exit;
        End;

      If Call.Callee = 'SocketSetTimeout' Then
        Begin
          Result := 'DelSafeSocketSetTimeout(' + EmitExpr(TASTCallArg(Call.Args[0
                    ]).Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) +
                    ', ' + EmitExpr(TASTCallArg(Call.Args[2]).Expr) + ')';
          Exit;
        End;

      If Call.Callee = 'SocketPeerIP' Then
        Begin
          Result := 'DelSafeSocketPeerIP(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ')';
          Exit;
        End;

      If Call.Callee = 'SocketSendHex' Then
        Begin
          Result := 'DelSafeSocketSendHex(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) +
                    ')';
          Exit;
        End;

      If Call.Callee = 'SocketRecvHex' Then
        Begin
          Result := 'DelSafeSocketRecvHex(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) +
                    ')';
          Exit;
        End;

      If Call.Callee = 'SocketSendFile' Then
        Begin
          Result := 'DelSafeSocketSendFile(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) +
                    ')';
          Exit;
        End;

      If Call.Callee = '__SyncAtomicNew' Then
        Begin
          Result := 'DelSafeSyncAtomicNew(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ')';
          Exit;
        End;
      If Call.Callee = '__SyncAtomicLoad' Then
        Begin
          Result := 'DelSafeSyncAtomicLoad(' + EmitExpr(TASTCallArg(Call.Args[0])
                    .Expr) + ')';
          Exit;
        End;
      If Call.Callee = '__SyncAtomicStore' Then
        Begin
          Result := 'DelSafeSyncAtomicStore(' + EmitExpr(TASTCallArg(Call.Args[0]
                    ).Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) +
                    ')';
          Exit;
        End;
      If Call.Callee = '__SyncAtomicAdd' Then
        Begin
          Result := 'DelSafeSyncAtomicAdd(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ', ' + EmitExpr(TASTCallArg(Call.Args[1]).Expr) +
                    ')';
          Exit;
        End;
      If Call.Callee = '__SyncAtomicCas' Then
        Begin
          Result := 'DelSafeSyncAtomicCas(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ', ' +
                    EmitExpr(TASTCallArg(Call.Args[1]).Expr) + ', ' + EmitExpr(
                    TASTCallArg(Call.Args[2]).Expr) + ')';
          Exit;
        End;
      If Call.Callee = '__SyncAtomicFree' Then
        Begin
          Result := 'DelSafeSyncAtomicFree(' + EmitExpr(TASTCallArg(Call.Args[0])
                    .Expr) + ')';
          Exit;
        End;
      If Call.Callee = '__SyncMutexNew' Then
        Begin
          Result := 'DelSafeSyncMutexNew()';
          Exit;
        End;
      If Call.Callee = '__SyncMutexLock' Then
        Begin
          Result := 'DelSafeSyncMutexLock(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ')';
          Exit;
        End;
      If Call.Callee = '__SyncMutexTryLock' Then
        Begin
          Result := 'DelSafeSyncMutexTryLock(' + EmitExpr(TASTCallArg(Call.Args[0
                    ]).Expr) + ')';
          Exit;
        End;
      If Call.Callee = '__SyncMutexUnlock' Then
        Begin
          Result := 'DelSafeSyncMutexUnlock(' + EmitExpr(TASTCallArg(Call.Args[0]
                    ).Expr) + ')';
          Exit;
        End;
      If Call.Callee = '__SyncMutexFree' Then
        Begin
          Result := 'DelSafeSyncMutexFree(' + EmitExpr(TASTCallArg(Call.Args[0]).
                    Expr) + ')';
          Exit;
        End;

      If SameText(Call.Callee, 'NewChannel') And (Call.GenericArgs.Count = 1)
        Then
        Begin
          MTag := RegisterChanType('Channel<' + Call.GenericArgs[0] + '>', Nil,
                  Nil);
          Result := Format('DelSafeChanNew_%s(%s)', [MTag, EmitExpr(TASTCallArg(
                    Call.Args[0]).Expr)]);
          Exit;
        End;
      If SameText(Call.Callee, 'Send') Or SameText(Call.Callee, 'TrySend') Then
        Begin
          TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).
                     Expr));
          MTag := RegisterChanType(TargetT, Nil, Nil);
          If SameText(Call.Callee, 'TrySend') Then
            Result := Format('DelSafeChanTrySend_%s(%s, %s)', [MTag, EmitExpr(
                      TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call
                      .Args[1]).Expr)])
          Else
            Result := Format('DelSafeChanSend_%s(%s, %s)', [MTag, EmitExpr(
                      TASTCallArg(Call.Args[0]).Expr), EmitExpr(TASTCallArg(Call
                      .Args[1]).Expr)]);
          Exit;
        End;
      If SameText(Call.Callee, 'Recv') Or SameText(Call.Callee, 'TryRecv') Or
         SameText(Call.Callee, 'CloseChannel') Or SameText(Call.Callee,
         'ChannelLen') Or
         SameText(Call.Callee, 'IsChannelEmpty') Or SameText(Call.Callee,
         'IsChannelFull') Or
         SameText(Call.Callee, 'IsChannelClosed') Or SameText(Call.Callee,
         'DestroyChannel') Then
        Begin
          TargetT := ResolveAliasType(GetExprTypeName(TASTCallArg(Call.Args[0]).
                     Expr));
          MTag := RegisterChanType(TargetT, Nil, Nil);
          TargetStr := EmitExpr(TASTCallArg(Call.Args[0]).Expr);
          If SameText(Call.Callee, 'Recv') Then Result := Format(

                                                         'DelSafeChanRecv_%s(%s)'
                                                          , [MTag, TargetStr])
          Else If SameText(Call.Callee, 'TryRecv') Then Result := Format(

                                                      'DelSafeChanTryRecv_%s(%s)'
                                                                  , [MTag,
                                                                  TargetStr])
          Else If SameText(Call.Callee, 'CloseChannel') Then Result := Format(

                                                        'DelSafeChanClose_%s(%s)'
                                                                       , [MTag,
                                                                       TargetStr
                                                                       ])
          Else If SameText(Call.Callee, 'ChannelLen') Then Result := Format(

                                                          'DelSafeChanLen_%s(%s)'
                                                                     , [MTag,
                                                                     TargetStr])
          Else If SameText(Call.Callee, 'IsChannelEmpty') Then Result := Format(

                                                      'DelSafeChanIsEmpty_%s(%s)'
                                                                         , [MTag
                                                                         ,

                                                                       TargetStr
                                                                         ])
          Else If SameText(Call.Callee, 'IsChannelFull') Then Result := Format(

                                                       'DelSafeChanIsFull_%s(%s)'
                                                                        , [MTag,

                                                                       TargetStr
                                                                        ])
          Else If SameText(Call.Callee, 'IsChannelClosed') Then Result := Format
                                                                          (

                                                     'DelSafeChanIsClosed_%s(%s)'
                                                                          , [
                                                                          MTag,

                                                                       TargetStr
                                                                          ])
          Else Result := Format('DelSafeChanDestroy_%s(%s)', [MTag, TargetStr]);
          Exit;
        End;

      // Normal call, enum variant constructor, or record constructor
      TargetFn := FindFunction(Call.Callee);
      ArgsStr := '';
      For I := 0 To Call.Args.Count - 1 Do
        Begin
          ArgItemStr := EmitExpr(TASTCallArg(Call.Args[I]).Expr);
          If Assigned(TargetFn) And TargetFn.IsExtern And (TargetFn.ExternAbi =
             'c') And
             (I < TargetFn.Params.Count) And
             SameText(TASTParam(TargetFn.Params[I]).TypeName, 'String') And
             (TASTParam(TargetFn.Params[I]).Ownership <> owMutBorrow) And
             (Not ((TASTCallArg(Call.Args[I]).Expr is TASTLiteralExpr) And
             (TASTLiteralExpr(TASTCallArg(Call.Args[I]).Expr).Kind = lkNil)))
            Then
            ArgItemStr := Format('PChar(String(%s))', [ArgItemStr]);
          ArgsStr := ArgsStr + ArgItemStr;
          If I < Call.Args.Count - 1 Then
            ArgsStr := ArgsStr + ', ';
        End;
      If Pos('.', Call.Callee) > 0 Then
        Begin
          ValF := Copy(Call.Callee, 1, Pos('.', Call.Callee) - 1);
          If IsEnumName(ValF) Then
            Exit(StringReplace(Call.Callee, '.', '_', [rfReplaceAll]) + '(' +
            ArgsStr + ')');
        End;
      If Assigned(TargetFn) And TargetFn.IsExtern And (TargetFn.ExternAbi = 'c')
         And
         SameText(TargetFn.ReturnType, 'String') Then
        Result := Format('String(%s(%s))', [Call.Callee, ArgsStr])
      Else
        Result := Call.Callee + '(' + ArgsStr + ')';
      Exit;
    End
  Else If Expr is TASTIfExpr Then
         Begin
           TargetT := ResolveAliasType(GetExprTypeName(Expr));
           If TargetT = '' Then TargetT := 'Int32';
           Result := Format('specialize DelSafeIfThen<%s>(%s, %s, %s)',
                     [EmitTypeRef(TargetT), EmitExpr(TASTIfExpr(Expr).Condition)
                     , EmitExpr(TASTIfExpr(Expr).ThenExpr), EmitExpr(TASTIfExpr(
                     Expr).ElseExpr)]);
           Exit;
         End
  Else If Expr is TASTMatchExpr Then
         Begin
           TargetStr := Format('_delsafe_mexpr_%d_%d', [Expr.Line, Expr.Col]);
           ScruVar := Format('_delsafe_mval_%d_%d', [Expr.Line, Expr.Col]);
           Emit(Format('%s := %s;', [ScruVar, EmitExpr(TASTMatchExpr(Expr).Expr)
           ]));
           ErrF := ResolveAliasType(GetExprTypeName(TASTMatchExpr(Expr).Expr));
           For I := 0 To TASTMatchExpr(Expr).Cases.Count - 1 Do
             Begin
               MC := TASTMatchCase(TASTMatchExpr(Expr).Cases[I]);
               BuildMatchCaseCond(MC, ScruVar, ErrF, KeyT, ValT, BindVarT,
                                  IsWild);
               If IsWild Then
                 Begin
                   If I > 0 Then Emit('else');
                 End
               Else
                 Begin
                   If KeyT = '' Then KeyT := 'True';
                   If I = 0 Then Emit('if ' + KeyT + ' then')
                   Else Emit('else if ' + KeyT + ' then');
                 End;
               Emit('begin');
               IncIndent;
               If ValT <> '' Then Emit(ValT);
               BindCount := GetMatchArmBindingCount(MC);
               PushMatchBindings(MC, ErrF);
               Try
                 Emit(Format('%s := %s;', [TargetStr, EmitExpr(MC.ValueExpr)]));
               Finally
                 For BIdx := 0 To BindCount - 1 Do
                   Begin
                     GetMatchArmBindingInfo(MC, BIdx, ErrF, BName, TVar, BType);
                     If (BName <> '') And (BName <> '_') Then PopMatchBindings(1
                       );
                   End;
             End;
           DecIndent;
           If I < TASTMatchExpr(Expr).Cases.Count - 1 Then Emit('end')
           Else Emit('end;');
         End;
  Result := TargetStr;
  Exit;
End
Else If Expr is TASTTupleLiteralExpr Then
       Begin
         ArgsStr := '';
         For I := 0 To TASTTupleLiteralExpr(Expr).Elements.Count - 1 Do
           Begin
             If I > 0 Then ArgsStr := ArgsStr + ', ';
             ArgsStr := ArgsStr + EmitExpr(TASTExpr(TASTTupleLiteralExpr(Expr).
                        Elements[I]));
           End;
         Result := Format('%s(%s)', [TASTTupleLiteralExpr(Expr).ResolvedType,
                   ArgsStr]);
         Exit;
       End
Else If Expr is TASTLambdaExpr Then
       Begin
         With TASTLambdaExpr(Expr) Do
           Begin
             If CaptureNames.Count = 0 Then
               Result := Format('DelSafeMakeFn_%s(@__delsafe_lambda_%d, nil)', [
                         FnTypeTag(ResolvedFnType), LambdaId])
             Else
               Begin
                 ArgsStr := '';
                 For I := 0 To CaptureNames.Count - 1 Do
                   Begin
                     If I > 0 Then ArgsStr := ArgsStr + ', ';
                     ArgsStr := ArgsStr + CaptureNames[I];
                   End;
                 Result := Format('__delsafe_make_lambda_%d(%s)', [LambdaId,
                           ArgsStr]);
               End;
           End;
         Exit;
       End;

Result := '';
End;

Procedure TDelSafeEmitterPascal.EmitActiveDefers(DownToIndex: Integer);

Var 
  I: Integer;
Begin
  For I := FActiveDefers.Count - 1 Downto DownToIndex Do
    EmitStmt(TASTStmt(FActiveDefers[I]));
End;

Function TDelSafeEmitterPascal.FindFunction(Const AName: String): TASTFunction;

Var 
  I: Integer;
Begin
  Result := Nil;
  If Assigned(FModule) Then
    For I := 0 To FModule.Functions.Count - 1 Do
      If SameText(TASTFunction(FModule.Functions[I]).Name, AName) Then
        Exit(TASTFunction(FModule.Functions[I]));
End;

Function TDelSafeEmitterPascal.FindDropFunc(Const ATypeName: String):

                                                                    TASTFunction
;

Var 
  BaseT: string;
  Fn: TASTFunction;
Begin
  Result := Nil;
  BaseT := ResolveAliasType(ATypeName);
  If BaseT = '' Then Exit;
  Fn := FindFunction(BaseT + '_Drop');
  If Assigned(Fn) And (Not Fn.IsExtern) And (Fn.GenericParams.Count = 0) And (Fn
     .GenericParam = '') And (Fn.Params.Count = 1) Then
    Result := Fn;
End;

Function TDelSafeEmitterPascal.RaiiExprUsesVar(Expr: TASTExpr; Const AVarName:
                                              String): Boolean;

Var 
  I: Integer;
  C: TASTCallExpr;
Begin
  Result := False;
  If Not Assigned(Expr) Then Exit;
  If Expr is TASTIdentifierExpr Then
    Exit(SameText(TASTIdentifierExpr(Expr).Name, AVarName));
  If Expr is TASTUnaryExpr Then
    Exit(RaiiExprUsesVar(TASTUnaryExpr(Expr).Expr, AVarName));
  If Expr is TASTBinaryExpr Then
    Exit(RaiiExprUsesVar(TASTBinaryExpr(Expr).Left, AVarName) or RaiiExprUsesVar
    (TASTBinaryExpr(Expr).Right, AVarName));
  If Expr is TASTMemberAccessExpr Then
    Exit(RaiiExprUsesVar(TASTMemberAccessExpr(Expr).Target, AVarName));
  If Expr is TASTIndexExpr Then
    Begin
      If RaiiExprUsesVar(TASTIndexExpr(Expr).Target, AVarName) Then Exit(True);
      For I := 0 To TASTIndexExpr(Expr).Indices.Count - 1 Do
        If RaiiExprUsesVar(TASTExpr(TASTIndexExpr(Expr).Indices[I]), AVarName)
          Then Exit(True);
    End;
  If Expr is TASTAwaitExpr Then
    Exit(RaiiExprUsesVar(TASTAwaitExpr(Expr).Expr, AVarName));
  If Expr is TASTSpawnExpr Then
    Exit(RaiiExprUsesVar(TASTSpawnExpr(Expr).CallExpr, AVarName));
  If Expr is TASTCallExpr Then
    Begin
      C := TASTCallExpr(Expr);
      If Assigned(C.CalleeExpr) And RaiiExprUsesVar(C.CalleeExpr, AVarName) Then
        Exit(True);
      For I := 0 To C.Args.Count - 1 Do
        If RaiiExprUsesVar(TASTCallArg(C.Args[I]).Expr, AVarName) Then Exit(True
          );
    End;
  If Expr is TASTTupleLiteralExpr Then
    Begin
      For I := 0 To TASTTupleLiteralExpr(Expr).Elements.Count - 1 Do
        If RaiiExprUsesVar(TASTExpr(TASTTupleLiteralExpr(Expr).Elements[I]),
           AVarName) Then Exit(True);
    End;
  If Expr is TASTLambdaExpr Then
    Begin
      For I := 0 To TASTLambdaExpr(Expr).CaptureNames.Count - 1 Do
        If SameText(TASTLambdaExpr(Expr).CaptureNames[I], AVarName) Then Exit(

                                                                            True
          );
    End;
  If Expr is TASTSetLiteralExpr Then
    Begin
      For I := 0 To TASTSetLiteralExpr(Expr).Elements.Count - 1 Do
        If RaiiExprUsesVar(TASTExpr(TASTSetLiteralExpr(Expr).Elements[I]),
           AVarName) Then Exit(True);
    End;
  If Expr is TASTMapLiteralExpr Then
    Begin
      For I := 0 To TASTMapLiteralExpr(Expr).Keys.Count - 1 Do
        If RaiiExprUsesVar(TASTExpr(TASTMapLiteralExpr(Expr).Keys[I]), AVarName)
           Or
           RaiiExprUsesVar(TASTExpr(TASTMapLiteralExpr(Expr).Values[I]),
           AVarName) Then Exit(True);
    End;
  If Expr is TASTIfExpr Then
    Exit(RaiiExprUsesVar(TASTIfExpr(Expr).Condition, AVarName) or
    RaiiExprUsesVar(TASTIfExpr(Expr).ThenExpr, AVarName) or
    RaiiExprUsesVar(TASTIfExpr(Expr).ElseExpr, AVarName));
  If Expr is TASTMatchExpr Then
    Begin
      If RaiiExprUsesVar(TASTMatchExpr(Expr).Expr, AVarName) Then Exit(True);
      For I := 0 To TASTMatchExpr(Expr).Cases.Count - 1 Do
        If RaiiExprUsesVar(TASTMatchCase(TASTMatchExpr(Expr).Cases[I]).ValueExpr
           , AVarName) Then Exit(True);
    End;
End;

Function TDelSafeEmitterPascal.IsNonBorrowArgCapture(Call: TASTCallExpr; ArgIdx:
                                                    Integer): Boolean;

Var 
  Fn: TASTFunction;
Begin
  If SameText(Call.Callee, 'PrintLn') Or SameText(Call.Callee, 'Print') Or
     SameText(Call.Callee, 'WriteLn') Or SameText(Call.Callee, 'Assert') Or
     SameText(Call.Callee, 'Length') Or SameText(Call.Callee, 'Count') Or
     SameText(Call.Callee, 'Contains') Or
     SameText(Call.Callee, 'High') Or SameText(Call.Callee, 'Low') Or SameText(
     Call.Callee, 'Pop') Or
     SameText(Call.Callee, 'Clear') Or SameText(Call.Callee, 'Remove') Or
     SameText(Call.Callee, 'Delete') Or
     SameText(Call.Callee, 'Slice') Or SameText(Call.Callee, 'SetLength') Or
     SameText(Call.Callee, 'Free') Or
     SameText(Call.Callee, 'Dispose') Or SameText(Call.Callee, 'Addr') Or
     SameText(Call.Callee, 'Split') Or SameText(Call.Callee, 'Join') Or SameText
     (Call.Callee, 'PadLeft') Or
     SameText(Call.Callee, 'PadRight') Or SameText(Call.Callee, 'RepeatStr') Or
     SameText(Call.Callee, 'StrToFloat') Or
     SameText(Call.Callee, 'TryStrToInt') Or SameText(Call.Callee,
     'TryStrToFloat') Or SameText(Call.Callee, 'GetEnv') Or
     SameText(Call.Callee, 'SetEnv') Or SameText(Call.Callee, 'ListDir') Or
     SameText(Call.Callee, 'CopyFile') Or
     SameText(Call.Callee, 'RenameFile') Then
    Exit(False);
  If SameText(Call.Callee, 'Push') Then
    Exit(ArgIdx = 1);
  If SameText(Call.Callee, 'Insert') Then
    Exit(ArgIdx = 2);
  If SameText(Call.Callee, 'Some') Or SameText(Call.Callee, 'Ok') Or SameText(
     Call.Callee, 'Err') Or
     SameText(Call.Callee, 'Box') Then
    Exit(True);
  Fn := FindFunction(Call.Callee);
  If Assigned(Fn) And (ArgIdx < Fn.Params.Count) Then
    Exit(Not (TASTParam(Fn.Params[ArgIdx]).Ownership in [owBorrow, owMutBorrow])
    );
  Result := True;
End;

Function TDelSafeEmitterPascal.IsVarEscapedInStmts(Const AVarName: String; Stmts:
                                                  TASTNodeList): Boolean;
Function ExprCapturesDirectVar(Expr: TASTExpr): Boolean;

Var 
  I: Integer;
Begin
  Result := False;
  If Not Assigned(Expr) Then Exit;
  If Expr is TASTIdentifierExpr Then
    Exit(SameText(TASTIdentifierExpr(Expr).Name, AVarName));
  If Expr is TASTIfExpr Then
    Exit(ExprCapturesDirectVar(TASTIfExpr(Expr).ThenExpr) or
    ExprCapturesDirectVar(TASTIfExpr(Expr).ElseExpr));
  If Expr is TASTMatchExpr Then
    For I := 0 To TASTMatchExpr(Expr).Cases.Count - 1 Do
      If ExprCapturesDirectVar(TASTMatchCase(TASTMatchExpr(Expr).Cases[I]).
         ValueExpr) Then Exit(True);
End;

Function CheckExprEscape(Expr: TASTExpr): Boolean;

Var 
  I: Integer;
  C: TASTCallExpr;
  U: TASTUnaryExpr;
  Arg: TASTCallArg;
Begin
  Result := False;
  If Not Assigned(Expr) Then Exit;
  If Expr is TASTUnaryExpr Then
    Begin
      U := TASTUnaryExpr(Expr);
      If (U.Op = '@') And RaiiExprUsesVar(U.Expr, AVarName) Then Exit(True);
      Exit(CheckExprEscape(U.Expr));
    End;
  If Expr is TASTBinaryExpr Then
    Exit(CheckExprEscape(TASTBinaryExpr(Expr).Left) or CheckExprEscape(

                                                                  TASTBinaryExpr
                                                                       (Expr).
    Right));
  If Expr is TASTMemberAccessExpr Then
    Exit(CheckExprEscape(TASTMemberAccessExpr(Expr).Target));
  If Expr is TASTIndexExpr Then
    Begin
      If CheckExprEscape(TASTIndexExpr(Expr).Target) Then Exit(True);
      For I := 0 To TASTIndexExpr(Expr).Indices.Count - 1 Do
        If CheckExprEscape(TASTExpr(TASTIndexExpr(Expr).Indices[I])) Then Exit(

                                                                            True
          );
    End;
  If Expr is TASTCallExpr Then
    Begin
      C := TASTCallExpr(Expr);
      For I := 0 To C.Args.Count - 1 Do
        Begin
          Arg := TASTCallArg(C.Args[I]);
          If (Arg.Ownership = owTake) And ExprCapturesDirectVar(Arg.Expr) Then
            Exit(True);
          If (Arg.Expr is TASTIdentifierExpr) And SameText(TASTIdentifierExpr(
             Arg.Expr).Name, AVarName) Then
            Begin
              If IsNonBorrowArgCapture(C, I) Then Exit(True);
            End
          Else If CheckExprEscape(Arg.Expr) Then
                 Exit(True);
        End;
    End;
  If Expr is TASTSetLiteralExpr Then
    Begin
      For I := 0 To TASTSetLiteralExpr(Expr).Elements.Count - 1 Do
        If ExprCapturesDirectVar(TASTExpr(TASTSetLiteralExpr(Expr).Elements[I]))
           Or
           CheckExprEscape(TASTExpr(TASTSetLiteralExpr(Expr).Elements[I])) Then
          Exit(True);
    End;
  If Expr is TASTMapLiteralExpr Then
    Begin
      For I := 0 To TASTMapLiteralExpr(Expr).Keys.Count - 1 Do
        If ExprCapturesDirectVar(TASTExpr(TASTMapLiteralExpr(Expr).Keys[I])) Or
           ExprCapturesDirectVar(TASTExpr(TASTMapLiteralExpr(Expr).Values[I]))
           Or
           CheckExprEscape(TASTExpr(TASTMapLiteralExpr(Expr).Keys[I])) Or
           CheckExprEscape(TASTExpr(TASTMapLiteralExpr(Expr).Values[I])) Then
          Exit(True);
    End;
  If Expr is TASTIfExpr Then
    Exit(CheckExprEscape(TASTIfExpr(Expr).Condition) or
    CheckExprEscape(TASTIfExpr(Expr).ThenExpr) or
    CheckExprEscape(TASTIfExpr(Expr).ElseExpr));
  If Expr is TASTMatchExpr Then
    Begin
      If CheckExprEscape(TASTMatchExpr(Expr).Expr) Then Exit(True);
      For I := 0 To TASTMatchExpr(Expr).Cases.Count - 1 Do
        If CheckExprEscape(TASTMatchCase(TASTMatchExpr(Expr).Cases[I]).ValueExpr
           ) Then Exit(True);
    End;
End;

Var 
  I, J: Integer;
  S: TASTStmt;
  VD: TASTVarDecl;
Begin
  Result := False;
  If Not Assigned(Stmts) Then Exit;
  For I := 0 To Stmts.Count - 1 Do
    Begin
      S := TASTStmt(Stmts[I]);
      If S is TASTReturnStmt Then
        Begin
          If ExprCapturesDirectVar(TASTReturnStmt(S).Expr) Or CheckExprEscape(
             TASTReturnStmt(S).Expr) Then Exit(True);
        End
      Else If S is TASTVarDeclStmt Then
             Begin
               For J := 0 To TASTVarDeclStmt(S).Decls.Count - 1 Do
                 Begin
                   VD := TASTVarDecl(TASTVarDeclStmt(S).Decls[J]);
                   If Assigned(VD.InitialExpr) And
                      (ExprCapturesDirectVar(VD.InitialExpr) Or CheckExprEscape(
                      VD.InitialExpr)) Then Exit(True);
                 End;
             End
      Else If S is TASTAssignStmt Then
             Begin
               If Not ((TASTAssignStmt(S).Target is TASTIdentifierExpr) And
                  SameText(TASTIdentifierExpr(TASTAssignStmt(S).Target).Name,
                  AVarName)) Then
                 Begin
                   If ExprCapturesDirectVar(TASTAssignStmt(S).Expr) Or
                      CheckExprEscape(TASTAssignStmt(S).Expr) Then Exit(True);
                 End
               Else If CheckExprEscape(TASTAssignStmt(S).Expr) Then
                      Exit(True);
             End
      Else If S is TASTCallStmt Then
             Begin
               If CheckExprEscape(TASTCallStmt(S).CallExpr) Then Exit(True);
             End
      Else If S is TASTIfStmt Then
             Begin
               If CheckExprEscape(TASTIfStmt(S).Condition) Or
                  IsVarEscapedInStmts(AVarName, TASTIfStmt(S).ThenBranch) Or
                  IsVarEscapedInStmts(AVarName, TASTIfStmt(S).ElseBranch) Then
                 Exit(True);
             End
      Else If S is TASTWhileStmt Then
             Begin
               If CheckExprEscape(TASTWhileStmt(S).Condition) Or
                  IsVarEscapedInStmts(AVarName, TASTWhileStmt(S).Body) Then Exit
                 (True);
             End
      Else If S is TASTForStmt Then
             Begin
               If CheckExprEscape(TASTForStmt(S).CollectionExpr) Or
                  IsVarEscapedInStmts(AVarName, TASTForStmt(S).Body) Then Exit(

                                                                            True
                 );
             End
      Else If S is TASTRepeatStmt Then
             Begin
               If IsVarEscapedInStmts(AVarName, TASTRepeatStmt(S).Body) Or
                  CheckExprEscape(TASTRepeatStmt(S).Condition) Then Exit(True);
             End
      Else If S is TASTUnsafeStmt Then
             Begin
               If IsVarEscapedInStmts(AVarName, TASTUnsafeStmt(S).Body) Then
                 Exit(True);
             End
      Else If S is TASTTryStmt Then
             Begin
               If IsVarEscapedInStmts(AVarName, TASTTryStmt(S).TryBody) Or
                  IsVarEscapedInStmts(AVarName, TASTTryStmt(S).ExceptBody) Then
                 Exit(True);
             End
      Else If S is TASTMatchStmt Then
             Begin
               If CheckExprEscape(TASTMatchStmt(S).Expr) Then Exit(True);
               For J := 0 To TASTMatchStmt(S).Cases.Count - 1 Do
                 If IsVarEscapedInStmts(AVarName, TASTMatchCase(TASTMatchStmt(S)
                    .Cases[J]).Body) Then Exit(True);
             End;
    End;
End;

Procedure TDelSafeEmitterPascal.RegisterRaiiVar(Const AVarName, ATypeName: String
                                               ; ScopeStmts: TASTNodeList);

Var 
  BaseT, KeyT, ValT: string;
Begin
  BaseT := ResolveAliasType(ATypeName);
  If (FindDropFunc(BaseT) = Nil) And (Pos('Box<', BaseT) <> 1) And
     (Not IsDynamicArrayType(BaseT)) And (Not IsMapType(BaseT, KeyT, ValT)) Then
    Exit;
  If IsVarEscapedInStmts(AVarName, ScopeStmts) Then
    Exit;
  FRaiiNames.Add(AVarName);
  FRaiiTypes.Add(BaseT);
End;

Procedure TDelSafeEmitterPascal.EmitRaiiCleanupFor(Const AVarName, ATypeName:
                                                  String);

Var 
  BaseT, InnerT, KeyT, ValT, DropCall: string;
  DropFn: TASTFunction;
Begin
  BaseT := ResolveAliasType(ATypeName);
  DropFn := FindDropFunc(BaseT);
  If Assigned(DropFn) Then
    Begin
      Emit(Format('%s(%s);', [DropFn.Name, AVarName]));
      Exit;
    End;
  If Pos('Box<', BaseT) = 1 Then
    Begin
      InnerT := Trim(Copy(BaseT, 5, Length(BaseT) - 5));
      DropFn := FindDropFunc(InnerT);
      DropCall := '';
      If Assigned(DropFn) Then
        DropCall := Format('%s(%s^); ', [DropFn.Name, AVarName]);
      Emit(Format('if %s <> nil then begin %sDispose(%s); %s := nil; end;', [
           AVarName, DropCall, AVarName, AVarName]));
    End
  Else If IsDynamicArrayType(BaseT) Then
         Begin
           Emit(Format('SetLength(%s, 0);', [AVarName]));
         End
  Else If IsMapType(BaseT, KeyT, ValT) Then
         Begin
           Emit(Format('SetLength(%s.entries, 0); %s.count := 0;', [AVarName,
                AVarName]));
         End;
End;

Procedure TDelSafeEmitterPascal.EmitActiveRaii(DownToIndex: Integer);

Var 
  I: Integer;
Begin
  For I := FRaiiNames.Count - 1 Downto DownToIndex Do
    EmitRaiiCleanupFor(FRaiiNames[I], FRaiiTypes[I]);
End;

Procedure TDelSafeEmitterPascal.EmitStmtList(List: TASTNodeList; IsLoopBody:
                                            Boolean);

Var 
  I, SavedBase, OldLoopBase, SavedRaiiBase, OldLoopRaiiBase: Integer;
  OldScopeList: TASTNodeList;
Begin
  SavedBase := FActiveDefers.Count;
  OldLoopBase := FLoopDeferBase;
  SavedRaiiBase := FRaiiNames.Count;
  OldLoopRaiiBase := FLoopRaiiBase;
  OldScopeList := FCurrentScopeList;
  FCurrentScopeList := List;
  If IsLoopBody Then
    Begin
      FLoopDeferBase := SavedBase;
      FLoopRaiiBase := SavedRaiiBase;
    End;
  Try
    For I := 0 To List.Count - 1 Do
      EmitStmt(TASTStmt(List[I]));
    If (List.Count = 0) Or Not (List[List.Count - 1] is TASTReturnStmt) Then
      Begin
        EmitActiveDefers(SavedBase);
        EmitActiveRaii(SavedRaiiBase);
      End;
  Finally
    FCurrentScopeList := OldScopeList;
    FLoopDeferBase := OldLoopBase;
    FLoopRaiiBase := OldLoopRaiiBase;
    While FActiveDefers.Count > SavedBase Do
      FActiveDefers.Delete(FActiveDefers.Count - 1);
    While FRaiiNames.Count > SavedRaiiBase Do
      Begin
        FRaiiNames.Delete(FRaiiNames.Count - 1);
        FRaiiTypes.Delete(FRaiiTypes.Count - 1);
      End;
End;
End;

Procedure TDelSafeEmitterPascal.BuildMatchCaseCond(CaseNode: TASTMatchCase; Const
                                                  ExprStr, MatchedType: String;
                                                  out CondStr, BindStmt,
                                                  BindVarType: String; out
                                                  IsWildcardArm: Boolean);

Var 
  PatStr, ValF, ErrF, PatItem, LoStr, HiStr, LoExpr, HiExpr, ItemCond,
  BindExprStr, GuardStr: string;
  K, P2, BIdx, BCount, GuardAdded, PDot, J: Integer;
  Enm: TASTEnumDecl;
  VarN: TASTEnumVariant;
  VarName, BName, TVar, BType: string;

Function FormatMatchAtom(Const S, MT: String): string;
Begin
  If (Length(S) >= 2) And (S[1] = '''') Then
    Result := EscapePascalChar(Copy(S, 2, Length(S) - 2))
  Else If (S = 'true') Or (S = 'false') Then
         Result := S
  Else If (S <> '') And ((S[1] In ['0'..'9', '$', '%']) Or ((S[1] = '-') And (
          Length(S) > 1))) Then
         Result := NormalizeIntLit(S)
  Else If Pos('.', S) > 0 Then
         Result := StringReplace(S, '.', '_', [rfReplaceAll])
  Else If IsEnumName(MT) Then
         Result := MT + '_' + S
  Else
    Result := S;
End;
Begin
  PatStr := CaseNode.Pattern.Value;
  CondStr := '';
  BindStmt := '';
  BindVarType := MatchedType;
  BindExprStr := ExprStr;
  IsWildcardArm := (PatStr = '_') And (Not Assigned(CaseNode.Guard));
  GuardAdded := 0;

  Enm := FindEnumDecl(MatchedType);

  If PatStr = '_' Then
    Begin
      If CaseNode.Pattern.IsLet And (CaseNode.Pattern.SubPattern <> '') And (
         CaseNode.Pattern.SubPattern <> '_') Then
        Begin
          GetMatchArmBindingInfo(CaseNode, 0, MatchedType, BName, TVar, BType);
          BindStmt := Format('%s := %s;', [TVar, ExprStr]);
          FGuardBindNames.Add(BName);
          FGuardBindExprs.Add(ExprStr);
          Inc(GuardAdded);
        End;
    End
  Else If Pos('Ok', PatStr) = 1 Then
         Begin
           CondStr := Format('%s.is_ok', [ExprStr]);
           If CaseNode.Pattern.IsLet And (CaseNode.Pattern.SubPattern <> '') And
              (CaseNode.Pattern.SubPattern <> '_') Then
             Begin
               SplitResultTypes(MatchedType, ValF, ErrF);
               BindVarType := ValF;
               GetMatchArmBindingInfo(CaseNode, 0, MatchedType, BName, TVar,
                                      BType);
               If IsTypedResult(MatchedType, ValF, ErrF) Then
                 BindExprStr := ExprStr + '.value'
               Else
                 BindExprStr := EmitMonadFieldExtract(ExprStr, ValF, 'value',
                                'str_val');
               BindStmt := Format('%s := %s;', [TVar, BindExprStr]);
               FGuardBindNames.Add(BName);
               FGuardBindExprs.Add(BindExprStr);
               Inc(GuardAdded);
             End;
         End
  Else If Pos('Err', PatStr) = 1 Then
         Begin
           If (CaseNode.Pattern.SubPattern <> '') And (CaseNode.Pattern.
              SubPattern <> '_') Then
             Begin
               SplitResultTypes(MatchedType, ValF, ErrF);
               If CaseNode.Pattern.IsLet Then
                 Begin
                   CondStr := Format('%s.is_err', [ExprStr]);
                   BindVarType := ErrF;
                   GetMatchArmBindingInfo(CaseNode, 0, MatchedType, BName, TVar,
                                          BType);
                   If IsTypedResult(MatchedType, ValF, ErrF) Then
                     BindExprStr := ExprStr + '.error'
                   Else If ResolveAliasType(ErrF) = 'String' Then
                          BindExprStr := ExprStr + '.err_str'
                   Else
                     BindExprStr := Format('%s(%s.error)', [EmitTypeRef(ErrF),
                                    ExprStr]);
                   BindStmt := Format('%s := %s;', [TVar, BindExprStr]);
                   FGuardBindNames.Add(BName);
                   FGuardBindExprs.Add(BindExprStr);
                   Inc(GuardAdded);
                 End
               Else If IsTypedResult(MatchedType, ValF, ErrF) Then
                      Begin
                        If (Length(CaseNode.Pattern.SubPattern) >= 2) And (
                           CaseNode.Pattern.SubPattern[1] = '"') Then
                          CondStr := Format('(%s.is_err) and (%s.error = %s)',
                                     [ExprStr, ExprStr, EscapePascalString(Copy(
                                     CaseNode.Pattern.SubPattern, 2, Length(
                                     CaseNode.Pattern.SubPattern) - 2))])
                        Else
                          CondStr := Format('(%s.is_err) and (%s.error = %s)',
                                     [ExprStr, ExprStr, StringReplace(CaseNode.
                                     Pattern.SubPattern, '.', '_', [rfReplaceAll
                                     ])]);
                      End
               Else If (Length(CaseNode.Pattern.SubPattern) >= 2) And (CaseNode.
                       Pattern.SubPattern[1] = '"') Then
                      CondStr := Format('(%s.is_err) and (%s.err_str = %s)',
                                 [ExprStr, ExprStr, EscapePascalString(Copy(
                                 CaseNode.Pattern.SubPattern, 2, Length(CaseNode
                                 .Pattern.SubPattern) - 2))])
               Else
                 CondStr := Format('(%s.is_err) and (%s.error = Integer(%s))',
                            [ExprStr, ExprStr, StringReplace(CaseNode.Pattern.
                            SubPattern, '.', '_', [rfReplaceAll])]);
             End
           Else
             CondStr := Format('%s.is_err', [ExprStr]);
         End
  Else If PatStr = 'Some' Then
         Begin
           If IsTypedValueOption(MatchedType, ValF) Then
             Begin
               CondStr := Format('%s.is_some', [ExprStr]);
               If CaseNode.Pattern.IsLet And (CaseNode.Pattern.SubPattern <> '')
                  And (CaseNode.Pattern.SubPattern <> '_') Then
                 Begin
                   BindVarType := ValF;
                   GetMatchArmBindingInfo(CaseNode, 0, MatchedType, BName, TVar,
                                          BType);
                   BindExprStr := ExprStr + '.value';
                   BindStmt := Format('%s := %s;', [TVar, BindExprStr]);
                   FGuardBindNames.Add(BName);
                   FGuardBindExprs.Add(BindExprStr);
                   Inc(GuardAdded);
                 End;
             End
           Else If IsValueOptionType(MatchedType) Then
                  Begin
                    CondStr := Format('%s.is_some', [ExprStr]);
                    If CaseNode.Pattern.IsLet And (CaseNode.Pattern.SubPattern
                       <> '') And (CaseNode.Pattern.SubPattern <> '_') Then
                      Begin
                        ValF := SafeUnwrapGeneric(MatchedType, 'Option');
                        BindVarType := ValF;
                        GetMatchArmBindingInfo(CaseNode, 0, MatchedType, BName,
                                               TVar, BType);
                        BindExprStr := EmitMonadFieldExtract(ExprStr, ValF,
                                       'num_val', 'str_val');
                        BindStmt := Format('%s := %s;', [TVar, BindExprStr]);
                        FGuardBindNames.Add(BName);
                        FGuardBindExprs.Add(BindExprStr);
                        Inc(GuardAdded);
                      End;
                  End
           Else
             Begin
               CondStr := Format('(%s <> nil)', [ExprStr]);
               If CaseNode.Pattern.IsLet And (CaseNode.Pattern.SubPattern <> '')
                  And (CaseNode.Pattern.SubPattern <> '_') Then
                 Begin
                   If Pos('Option<', MatchedType) = 1 Then
                     BindVarType := SafeUnwrapGeneric(MatchedType, 'Option');
                   GetMatchArmBindingInfo(CaseNode, 0, MatchedType, BName, TVar,
                                          BType);
                   BindStmt := Format('%s := %s;', [TVar, ExprStr]);
                   FGuardBindNames.Add(BName);
                   FGuardBindExprs.Add(ExprStr);
                   Inc(GuardAdded);
                 End;
             End;
         End
  Else If (CaseNode.Pattern.Items.Count <= 1) And (PatStr = 'None') And (Not
          Assigned(Enm)) Then
         Begin
           If IsValueOptionType(MatchedType) Then
             CondStr := Format('%s.is_none', [ExprStr])
           Else
             CondStr := Format('(%s = nil)', [ExprStr]);
         End
  Else If Assigned(Enm) And Enm.HasPayload Then
         Begin
           VarN := Nil;
           For K := 0 To CaseNode.Pattern.Items.Count - 1 Do
             Begin
               PatItem := Trim(CaseNode.Pattern.Items[K]);
               PDot := Pos('.', PatItem);
               If PDot > 0 Then VarName := Copy(PatItem, PDot + 1, Length(
                                           PatItem))
               Else VarName := PatItem;
               For J := 0 To Enm.Variants.Count - 1 Do
                 If SameText(TASTEnumVariant(Enm.Variants[J]).Name, VarName)
                   Then
                   Begin
                     VarN := TASTEnumVariant(Enm.Variants[J]);
                     VarName := VarN.Name;
                     Break;
                   End;
               ItemCond := Format('(%s.tag = %s_Tag_%s)', [ExprStr, Enm.Name,
                           VarName]);
               If K > 0 Then CondStr := CondStr + ' or ';
               CondStr := CondStr + ItemCond;
             End;
           If CaseNode.Pattern.Items.Count > 1 Then
             CondStr := '(' + CondStr + ')';

           BCount := GetMatchArmBindingCount(CaseNode);
           If Assigned(VarN) And (BCount > 0) Then
             Begin
               For BIdx := 0 To BCount - 1 Do
                 Begin
                   GetMatchArmBindingInfo(CaseNode, BIdx, MatchedType, BName,
                                          TVar, BType);
                   If (BIdx < VarN.Fields.Count) Then
                     Begin
                       BindExprStr := Format('%s._v_%s_%s', [ExprStr, VarN.Name,
                                      TASTRecordField(VarN.Fields[BIdx]).Name]);
                       If (BName <> '') And (BName <> '_') Then
                         Begin
                           BindStmt := BindStmt + Format('%s := %s; ', [TVar,
                                       BindExprStr]);
                           FGuardBindNames.Add(BName);
                           FGuardBindExprs.Add(BindExprStr);
                           Inc(GuardAdded);
                         End;
                     End;
                 End;
             End;
         End
  Else
    Begin
      For K := 0 To CaseNode.Pattern.Items.Count - 1 Do
        Begin
          PatItem := Trim(CaseNode.Pattern.Items[K]);
          If (Pos('..', PatItem) > 0) And (Length(PatItem) > 0) And (PatItem[1]
             <> '"') Then
            Begin
              P2 := Pos('..', PatItem);
              LoStr := Trim(Copy(PatItem, 1, P2 - 1));
              HiStr := Trim(Copy(PatItem, P2 + 2, Length(PatItem)));
              LoExpr := FormatMatchAtom(LoStr, MatchedType);
              HiExpr := FormatMatchAtom(HiStr, MatchedType);
              ItemCond := Format('((%s >= %s) and (%s <= %s))', [ExprStr, LoExpr
                          , ExprStr, HiExpr]);
            End
          Else If (Length(PatItem) >= 2) And (PatItem[1] = '"') Then
                 ItemCond := Format('(%s = %s)', [ExprStr, EscapePascalString(
                             Copy(PatItem, 2, Length(PatItem) - 2))])
          Else
            ItemCond := Format('(%s = %s)', [ExprStr, FormatMatchAtom(PatItem,
                        MatchedType)]);
          If K > 0 Then CondStr := CondStr + ' or ';
          CondStr := CondStr + ItemCond;
        End;
      If CaseNode.Pattern.Items.Count > 1 Then
        CondStr := '(' + CondStr + ')';
    End;

  If Assigned(CaseNode.Guard) Then
    Begin
      Try
        GuardStr := EmitExpr(CaseNode.Guard);
      Finally
        For BIdx := 1 To GuardAdded Do
          If FGuardBindNames.Count > 0 Then
            Begin
              FGuardBindNames.Delete(FGuardBindNames.Count - 1);
              FGuardBindExprs.Delete(FGuardBindExprs.Count - 1);
            End;
    End;
  If CondStr = '' Then
    CondStr := GuardStr
  Else
    CondStr := Format('((%s) and (%s))', [CondStr, GuardStr]);
End
Else
  Begin
    For BIdx := 1 To GuardAdded Do
      If FGuardBindNames.Count > 0 Then
        Begin
          FGuardBindNames.Delete(FGuardBindNames.Count - 1);
          FGuardBindExprs.Delete(FGuardBindExprs.Count - 1);
        End;
  End;
End;

Procedure TDelSafeEmitterPascal.EmitStmt(Stmt: TASTStmt);

Var 
  Assign: TASTAssignStmt;
  CallStmt: TASTCallStmt;
  IfStmt: TASTIfStmt;
  WhileStmt: TASTWhileStmt;
  ForStmt: TASTForStmt;
  RepeatStmt: TASTRepeatStmt;
  MatchStmt: TASTMatchStmt;
  CaseNode: TASTMatchCase;
  Ret: TASTReturnStmt;
  VD: TASTVarDecl;
  Lines: TStringList;
  LineStr, ExprStr, MatchedType, Prefix, CondStr, BindStmt, BindVarT,
  OldBindName, OldBindType, KeyT, ValT, TargetT, IdxVar: string;
  IsWild: Boolean;
  I, J, Idx: Integer;
Begin
  If Stmt is TASTVarDeclStmt Then
    Begin
      For I := 0 To TASTVarDeclStmt(Stmt).Decls.Count - 1 Do
        Begin
          VD := TASTVarDecl(TASTVarDeclStmt(Stmt).Decls[I]);
          If Assigned(VD.InitialExpr) Then
            Begin
              If VD.InitialExpr is TASTMapLiteralExpr Then
                EmitMapLiteralAssign(VD.Name, VD.TypeName, TASTMapLiteralExpr(VD
                                     .InitialExpr))
              Else If (VD.InitialExpr is TASTSetLiteralExpr) And (Not IsSetType(
                      VD.TypeName)) Then
                     EmitArrayLiteralAssign(VD.Name, VD.TypeName,
                                            TASTSetLiteralExpr(VD.InitialExpr))
              Else
                Emit(Format('%s := %s;', [VD.Name, EmitExpr(VD.InitialExpr)]));
            End
          Else If (Pos('Box<', ResolveAliasType(VD.TypeName)) = 1) Or (Pos('^',
                  VD.TypeName) = 1) Or SameText(VD.TypeName, 'Pointer') Then
                 Emit(Format('%s := nil;', [VD.Name]))
          Else If IsMapType(VD.TypeName, KeyT, ValT) Then
                 Emit(Format('%s.count := 0; SetLength(%s.entries, 0);', [VD.
                      Name, VD.Name]));
          RegisterRaiiVar(VD.Name, VD.TypeName, FCurrentScopeList);
        End;
    End
  Else If Stmt is TASTAssignStmt Then
         Begin
           Assign := TASTAssignStmt(Stmt);
           TargetT := GetExprTypeName(Assign.Target);
           If Assign.Expr is TASTMapLiteralExpr Then
             EmitMapLiteralAssign(EmitExpr(Assign.Target), TargetT,
             TASTMapLiteralExpr(Assign.Expr))
           Else If (Assign.Expr is TASTSetLiteralExpr) And (Not IsSetType(
                   TargetT)) Then
                  EmitArrayLiteralAssign(EmitExpr(Assign.Target), TargetT,
                  TASTSetLiteralExpr(Assign.Expr))
           Else If (Assign.Target is TASTIndexExpr) And IsMapType(
                   GetExprTypeName(TASTIndexExpr(Assign.Target).Target), KeyT,
                   ValT) Then
                  Emit(Format('DelSafeMapSet_%s(%s, %s, %s);', [
                       MapTag(KeyT, ValT),
                  EmitExpr(TASTIndexExpr(Assign.Target).Target),
                  EmitExpr(TASTExpr(TASTIndexExpr(Assign.Target).Indices[0])),
                  EmitExpr(Assign.Expr)]))
           Else
             Emit(Format('%s := %s;', [EmitExpr(Assign.Target), EmitExpr(Assign.
                                                                         Expr)])
             );
         End
  Else If Stmt is TASTCallStmt Then
         Begin
           CallStmt := TASTCallStmt(Stmt);
           Emit(EmitExpr(CallStmt.CallExpr) + ';');
         End
  Else If Stmt is TASTExprStmt Then
         Begin
           If Assigned(TASTExprStmt(Stmt).Expr) Then
             Emit(EmitExpr(TASTExprStmt(Stmt).Expr) + ';');
         End
  Else If Stmt is TASTYieldStmt Then
         Begin
           Emit('ThreadSwitch;');
         End
  Else If Stmt is TASTIfStmt Then
         Begin
           IfStmt := TASTIfStmt(Stmt);
           Emit(Format('if %s then', [EmitExpr(IfStmt.Condition)]));
           Emit('begin');
           IncIndent;
           EmitStmtList(IfStmt.ThenBranch);
           DecIndent;
           If IfStmt.ElseBranch.Count > 0 Then
             Begin
               Emit('end');
               Emit('else');
               Emit('begin');
               IncIndent;
               EmitStmtList(IfStmt.ElseBranch);
               DecIndent;
             End;
           Emit('end;');
         End
  Else If Stmt is TASTWhileStmt Then
         Begin
           WhileStmt := TASTWhileStmt(Stmt);
           Emit(Format('while %s do', [EmitExpr(WhileStmt.Condition)]));
           Emit('begin');
           IncIndent;
           EmitStmtList(WhileStmt.Body, True);
           DecIndent;
           Emit('end;');
         End
  Else If Stmt is TASTForStmt Then
         Begin
           ForStmt := TASTForStmt(Stmt);
           If Assigned(ForStmt.CollectionExpr) And IsMapType(GetExprTypeName(
              ForStmt.CollectionExpr), KeyT, ValT) Then
             Begin
               IdxVar := Format('_delsafe_mi_%d_%d', [ForStmt.Line, ForStmt.Col])
               ;
               ExprStr := EmitExpr(ForStmt.CollectionExpr);
               Emit(Format('for %s := 0 to %s.count - 1 do', [IdxVar, ExprStr]))
               ;
               Emit('begin');
               IncIndent;
               Emit(Format('%s := %s.entries[%s].key;', [ForStmt.VarName,
                    ExprStr, IdxVar]));
               If ForStmt.ValVarName <> '' Then
                 Emit(Format('%s := %s.entries[%s].val;', [ForStmt.ValVarName,
                      ExprStr, IdxVar]));
               EmitStmtList(ForStmt.Body, True);
               DecIndent;
               Emit('end;');
             End
           Else
             Begin
               If Assigned(ForStmt.CollectionExpr) Then
                 Emit(Format('for %s in %s do', [ForStmt.VarName, EmitExpr(
                      ForStmt.CollectionExpr)]))
               Else If ForStmt.IsDownTo Then
                      Emit(Format('for %s := %s downto %s do', [ForStmt.VarName,
                           EmitExpr(ForStmt.StartExpr), EmitExpr(ForStmt.EndExpr
                      )]))
               Else
                 Emit(Format('for %s := %s to %s do', [ForStmt.VarName, EmitExpr
                      (ForStmt.StartExpr), EmitExpr(ForStmt.EndExpr)]));
               Emit('begin');
               IncIndent;
               EmitStmtList(ForStmt.Body, True);
               DecIndent;
               Emit('end;');
             End;
         End
  Else If Stmt is TASTRepeatStmt Then
         Begin
           RepeatStmt := TASTRepeatStmt(Stmt);
           Emit('repeat');
           IncIndent;
           EmitStmtList(RepeatStmt.Body, True);
           DecIndent;
           Emit(Format('until %s;', [EmitExpr(RepeatStmt.Condition)]));
         End
  Else If Stmt is TASTBreakStmt Then
         Begin
           If FActiveDefers.Count > FLoopDeferBase Then
             EmitActiveDefers(FLoopDeferBase);
           If FRaiiNames.Count > FLoopRaiiBase Then
             EmitActiveRaii(FLoopRaiiBase);
           Emit('break;');
         End
  Else If Stmt is TASTContinueStmt Then
         Begin
           If FActiveDefers.Count > FLoopDeferBase Then
             EmitActiveDefers(FLoopDeferBase);
           If FRaiiNames.Count > FLoopRaiiBase Then
             EmitActiveRaii(FLoopRaiiBase);
           Emit('continue;');
         End
  Else If Stmt is TASTDeferStmt Then
         Begin
           If Assigned(TASTDeferStmt(Stmt).Stmt) Then
             FActiveDefers.Add(TASTDeferStmt(Stmt).Stmt);
         End
  Else If Stmt is TASTTryStmt Then
         Begin
           Emit('try');
           IncIndent;
           EmitStmtList(TASTTryStmt(Stmt).TryBody);
           DecIndent;
           Emit('except');
           IncIndent;
           EmitStmtList(TASTTryStmt(Stmt).ExceptBody);
           DecIndent;
           Emit('end;');
         End
  Else If Stmt is TASTRaiseStmt Then
         Begin
           Emit(Format('raise Exception.Create(%s);', [EmitExpr(TASTRaiseStmt(
                Stmt).Expr)]));
         End
  Else If Stmt is TASTUnsafeStmt Then
         Begin
           Emit('// unsafe block');
           Emit('begin');
           IncIndent;
           EmitStmtList(TASTUnsafeStmt(Stmt).Body);
           DecIndent;
           Emit('end;');
         End
  Else If Stmt is TASTReturnStmt Then
         Begin
           Ret := TASTReturnStmt(Stmt);
           If (FActiveDefers.Count > 0) Or (FRaiiNames.Count > 0) Or (Assigned(
              FCurrentFunc) And (FCurrentFunc.Ensures.Count > 0)) Then
             Begin
               If Assigned(Ret.Expr) Then
                 Begin
                   If Assigned(FCurrentFunc) And FCurrentFunc.IsAsync Then
                     Emit(Format(

'Result := Default(%s); Result.state := nil; Result.is_completed := True; Result.value := %s;'
                          ,
                          [EmitTypeRef('Task<' + FCurrentFunc.ReturnType + '>'),
                     EmitExpr(Ret.Expr)]))
                   Else
                     Emit(Format('Result := %s;', [EmitExpr(Ret.Expr)]));
                   If FActiveDefers.Count > 0 Then
                     EmitActiveDefers(0);
                   If Assigned(FCurrentFunc) Then
                     For J := 0 To FCurrentFunc.Ensures.Count - 1 Do
                       Emit(Format(

             'Assert(%s, ''Post-condition (ensure) violation in function %s'');'
                            ,
                            [EmitExpr(TASTExpr(FCurrentFunc.Ensures[J])),
                       FCurrentFunc.Name]));
                   If FRaiiNames.Count > 0 Then
                     EmitActiveRaii(0);
                   Emit('Exit(Result);');
                 End
               Else
                 Begin
                   If FActiveDefers.Count > 0 Then
                     EmitActiveDefers(0);
                   If Assigned(FCurrentFunc) Then
                     For J := 0 To FCurrentFunc.Ensures.Count - 1 Do
                       Emit(Format(

             'Assert(%s, ''Post-condition (ensure) violation in function %s'');'
                            ,
                            [EmitExpr(TASTExpr(FCurrentFunc.Ensures[J])),
                       FCurrentFunc.Name]));
                   If FRaiiNames.Count > 0 Then
                     EmitActiveRaii(0);
                   If Assigned(FCurrentFunc) And FCurrentFunc.IsAsync Then
                     Begin
                       Emit(Format(

'Result := Default(%s); Result.state := nil; Result.is_completed := True; Exit(Result);'
                            ,
                            [EmitTypeRef('Task<' + FCurrentFunc.ReturnType + '>'
                       )]));
                     End
                   Else
                     Emit('Exit;');
                 End;
             End
           Else
             Begin
               If Assigned(Ret.Expr) Then
                 Begin
                   If Assigned(FCurrentFunc) And FCurrentFunc.IsAsync Then
                     Emit(Format(

'begin Result := Default(%s); Result.state := nil; Result.is_completed := True; Result.value := %s; Exit(Result); end;'
                          ,
                          [EmitTypeRef('Task<' + FCurrentFunc.ReturnType + '>'),
                     EmitExpr(Ret.Expr)]))
                   Else
                     Emit(Format('Exit(%s);', [EmitExpr(Ret.Expr)]));
                 End
               Else If Assigned(FCurrentFunc) And FCurrentFunc.IsAsync Then
                      Emit(Format(

'begin Result := Default(%s); Result.state := nil; Result.is_completed := True; Exit(Result); end;'
                           ,
                           [EmitTypeRef('Task<' + FCurrentFunc.ReturnType + '>')
                      ]))
               Else
                 Emit('Exit;');
             End;
         End
  Else If Stmt is TASTAsmStmt Then
         Begin
           Emit('{$ASMMODE INTEL}');
           Emit('asm');
           IncIndent;
           Lines := TStringList.Create;
           Try
             Lines.Text := TASTAsmStmt(Stmt).AsmCode;
             For J := 0 To Lines.Count - 1 Do
               Begin
                 LineStr := Trim(Lines[J]);
                 If LineStr <> '' Then
                   Emit(LineStr);
               End;
           Finally
             Lines.Free;
         End;
  DecIndent;
  Emit('end;');
End
Else If Stmt is TASTMatchStmt Then
       Begin
         MatchStmt := TASTMatchStmt(Stmt);
         TargetT := Format('_delsafe_mval_%d_%d', [MatchStmt.Line, MatchStmt.Col]
                    );
         Emit(Format('%s := %s;', [TargetT, EmitExpr(MatchStmt.Expr)]));
         MatchedType := ResolveAliasType(GetExprTypeName(MatchStmt.Expr));
         Emit('// Match generated by the DelSafe compiler');
         For I := 0 To MatchStmt.Cases.Count - 1 Do
           Begin
             CaseNode := TASTMatchCase(MatchStmt.Cases[I]);
             BuildMatchCaseCond(CaseNode, TargetT, MatchedType, CondStr,
                                BindStmt, BindVarT, IsWild);
             If IsWild Then
               Begin
                 If I > 0 Then Emit('else');
                 Emit('begin');
                 IncIndent;
               End
             Else
               Begin
                 If I = 0 Then Prefix := 'if '
                 Else Prefix := 'else if ';
                 If CondStr = '' Then CondStr := 'True';
                 Emit(Prefix + CondStr + ' then');
                 Emit('begin');
                 IncIndent;
               End;
             If BindStmt <> '' Then Emit(BindStmt);
             J := GetMatchArmBindingCount(CaseNode);
             PushMatchBindings(CaseNode, MatchedType);
             Try
               For Idx := 0 To CaseNode.Body.Count - 1 Do
                 EmitStmt(TASTStmt(CaseNode.Body[Idx]));
             Finally
               For Idx := 0 To J - 1 Do
                 Begin
                   GetMatchArmBindingInfo(CaseNode, Idx, MatchedType, KeyT, ValT
                                          , LineStr);
                   If (KeyT <> '') And (KeyT <> '_') Then PopMatchBindings(1);
                 End;
           End;
         DecIndent;

         If I < MatchStmt.Cases.Count - 1 Then
           Emit('end')
         Else
           Emit('end;');
       End;
End;
End;

Procedure TDelSafeEmitterPascal.EmitRecordType(Rec: TASTRecordDecl);

Var 
  I: Integer;
  Field: TASTRecordField;
Begin
  Emit(Format('T%s = record', [Rec.Name]));
  IncIndent;
  For I := 0 To Rec.Fields.Count - 1 Do
    Begin
      Field := TASTRecordField(Rec.Fields[I]);
      Emit(Format('%s: %s;', [Field.Name, EmitTypeRef(Field.TypeName)]));
    End;
  DecIndent;
  Emit('end;');
  Emit('');
End;

Procedure TDelSafeEmitterPascal.EmitRecordConstructor(Rec: TASTRecordDecl);

Var 
  I: Integer;
  Field: TASTRecordField;
  CtorParams: string;
Begin
  CtorParams := '';
  For I := 0 To Rec.Fields.Count - 1 Do
    Begin
      Field := TASTRecordField(Rec.Fields[I]);
      CtorParams := CtorParams + Format('const A_%s: %s', [Field.Name,
                    EmitTypeRef(Field.TypeName)]);
      If I < Rec.Fields.Count - 1 Then
        CtorParams := CtorParams + '; ';
    End;

  Emit(Format('function %s(%s): T%s;', [Rec.Name, CtorParams, Rec.Name]));
  Emit('begin');
  IncIndent;
  For I := 0 To Rec.Fields.Count - 1 Do
    Begin
      Field := TASTRecordField(Rec.Fields[I]);
      Emit(Format('Result.%s := A_%s;', [Field.Name, Field.Name]));
    End;
  DecIndent;
  Emit('end;');
  Emit('');
End;

Procedure TDelSafeEmitterPascal.EmitEnumDecl(Enm: TASTEnumDecl);

Var 
  I, J: Integer;
  VariantName: string;
  V: TASTEnumVariant;
  F: TASTRecordField;
Begin
  If Enm.HasPayload Then
    Begin
      Emit(Format('T%s_Tag = (', [Enm.Name]));
      IncIndent;
      For I := 0 To Enm.Variants.Count - 1 Do
        Begin
          VariantName := Enm.Name + '_Tag_' + TASTEnumVariant(Enm.Variants[I]).
                         Name;
          If I < Enm.Variants.Count - 1 Then
            Emit(VariantName + ',')
          Else
            Emit(VariantName);
        End;
      DecIndent;
      Emit(');');
      Emit(Format('T%s = record', [Enm.Name]));
      IncIndent;
      Emit(Format('tag: T%s_Tag;', [Enm.Name]));
      For I := 0 To Enm.Variants.Count - 1 Do
        Begin
          V := TASTEnumVariant(Enm.Variants[I]);
          For J := 0 To V.Fields.Count - 1 Do
            Begin
              F := TASTRecordField(V.Fields[J]);
              Emit(Format('_v_%s_%s: %s;', [V.Name, F.Name, EmitTypeRef(F.
                   TypeName)]));
            End;
        End;
      DecIndent;
      Emit('end;');
      Emit(Format('%s = T%s;', [Enm.Name, Enm.Name]));
      Emit('');
      Exit;
    End;

  Emit(Format('T%s = (', [Enm.Name]));
  IncIndent;
  For I := 0 To Enm.Variants.Count - 1 Do
    Begin
      VariantName := Enm.Name + '_' + TASTEnumVariant(Enm.Variants[I]).Name;
      If I < Enm.Variants.Count - 1 Then
        Emit(VariantName + ',')
      Else
        Emit(VariantName);
    End;
  DecIndent;
  Emit(');');
  Emit(Format('%s = T%s;', [Enm.Name, Enm.Name]));
  Emit('');
End;

Procedure TDelSafeEmitterPascal.EmitArrayDecl(Arr: TASTArrayDecl);

Var 
  I, DimVal: Integer;
  DimsStr: string;
Begin
  If Arr.Dims.Count = 0 Then
    Begin
      Emit(Format('T%s = array of %s;', [Arr.Name, EmitTypeRef(Arr.ElemType)]));
      Emit(Format('%s = T%s;', [Arr.Name, Arr.Name]));
      Emit('');
      Exit;
    End;
  DimsStr := '';
  For I := 0 To Arr.Dims.Count - 1 Do
    Begin
      DimVal := StrToIntDef(Arr.Dims[I], 1);
      If I > 0 Then DimsStr := DimsStr + ', ';
      DimsStr := DimsStr + Format('0..%d', [DimVal - 1]);
    End;
  Emit(Format('T%s = array[%s] of %s;', [Arr.Name, DimsStr, EmitTypeRef(Arr.
       ElemType)]));
  Emit(Format('%s = T%s;', [Arr.Name, Arr.Name]));
  Emit('');
End;

Procedure TDelSafeEmitterPascal.EmitSetDecl(SetD: TASTSetDecl);

Var 
  I: Integer;
  VarsStr: string;
Begin
  If SetD.Variants.Count > 0 Then
    Begin
      VarsStr := '';
      For I := 0 To SetD.Variants.Count - 1 Do
        Begin
          If I > 0 Then VarsStr := VarsStr + ', ';
          VarsStr := VarsStr + TASTEnumVariant(SetD.Variants[I]).Name;
        End;
      Emit(Format('T%s_Enum = (%s);', [SetD.Name, VarsStr]));
      Emit(Format('T%s = set of T%s_Enum;', [SetD.Name, SetD.Name]));
      Emit(Format('%s = T%s;', [SetD.Name, SetD.Name]));
    End
  Else
    Begin
      Emit(Format('T%s = set of %s;', [SetD.Name, EmitTypeRef(SetD.ElemType)]));
      Emit(Format('%s = T%s;', [SetD.Name, SetD.Name]));
    End;
  Emit('');
End;

Procedure TDelSafeEmitterPascal.EmitSubrangeDecl(SubR: TASTSubrangeDecl);
Begin
  Emit(Format('T%s = %s..%s;', [SubR.Name, SubR.LowBound, SubR.HighBound]));
  Emit(Format('%s = T%s;', [SubR.Name, SubR.Name]));
  Emit('');
End;

Procedure TDelSafeEmitterPascal.EmitMapDecl(MapD: TASTMapDecl);
Begin
  Emit(Format('T%s = TDelSafeMap_%s;', [MapD.Name, MapTag(MapD.KeyType, MapD.
       ValType)]));
  Emit(Format('%s = T%s;', [MapD.Name, MapD.Name]));
  Emit('');
End;

Procedure TDelSafeEmitterPascal.EmitTypeAliasDecl(AliasD: TASTTypeAliasDecl);
Begin
  Emit(Format('T%s = %s;', [AliasD.Name, EmitTypeRef(AliasD.TargetType)]));
  Emit(Format('%s = T%s;', [AliasD.Name, AliasD.Name]));
  Emit('');
End;

Procedure TDelSafeEmitterPascal.EmitFunction(Func: TASTFunction);

Var 
  ParamListStr: string;
  I: Integer;
  Param: TASTParam;
  ModStr, ExportClause: string;
  VarDecl: TASTVarDecl;
  LibClause, CleanLib, LowLib: string;
  ParamType, KeyT, ValT: string;
  SkipNames, AutoNames, AutoTypes: TStringList;
Begin
  If (Func.GenericParams.Count > 0) Or (Func.GenericParam <> '') Then Exit;
  // Generic template does not emit code directly
  If SameText(Func.Name, 'Abs') Or SameText(Func.Name, 'Min') Or SameText(Func.
     Name, 'Max') Or SameText(Func.Name, 'Clamp') Then Exit;
  FCurrentFunc := Func;
  If Func.IsExtern Then
    Begin
      If Func.ExternAbi = 'pascal' Then
        Begin
          Emit(Format('// Extern Pascal: %s (provided by FPC unit)', [Func.Name]
          ));
          Emit('');
          Exit;
        End;

      // Standard C math functions mapped directly to FPC Math
      If (Func.ExternAbi = 'c') And ((Func.Name = 'sin') Or (Func.Name = 'cos')
         Or (Func.Name = 'sqrt') Or
         (Func.Name = 'tan') Or (Func.Name = 'abs') Or (Func.Name = 'floor') Or
         (Func.Name = 'ceil')) Then
        Begin
          Emit(Format(
               '// Extern C Math: %s (natively provided by FPC System/Math)', [
               Func.Name]));
          Emit('');
          Exit;
        End;

      If Func.ExternLib <> '' Then
        Begin
          CleanLib := ResolvePascalExternLib(Func.ExternLib);
          LibClause := Format(' external ''%s'';', [CleanLib]);
          LowLib := LowerCase(CleanLib);
          If Copy(LowLib, Length(LowLib) - 5, 6) = '.dylib' Then
            CleanLib := Copy(CleanLib, 1, Length(CleanLib) - 6)
          Else If Copy(LowLib, Length(LowLib) - 2, 3) = '.so' Then
            CleanLib := Copy(CleanLib, 1, Length(CleanLib) - 3)
          Else If Copy(LowLib, Length(LowLib) - 3, 4) = '.dll' Then
            CleanLib := Copy(CleanLib, 1, Length(CleanLib) - 4);
          If (Length(CleanLib) > 3) And SameText(Copy(CleanLib, 1, 3), 'lib') And
             Not SameText(CleanLib, 'libc') Then
            CleanLib := Copy(CleanLib, 4, Length(CleanLib) - 3);
          LowLib := LowerCase(CleanLib);
          If (CleanLib <> '') And (LowLib <> 'msvcrt') And (LowLib <> 'c') And
             (LowLib <> 'libc') Then
            Emit(Format('{$IFDEF DARWIN}{$linklib %s}{$ENDIF}', [CleanLib]));
        End
      Else
        LibClause := ' external ''msvcrt'';';
      // Standard C runtime on Windows/FPC

      ParamListStr := '';
      For I := 0 To Func.Params.Count - 1 Do
        Begin
          Param := TASTParam(Func.Params[I]);
          Case Param.Ownership Of 
            owMutBorrow: ModStr := 'var ';
            owBorrow:    ModStr := 'const ';
            Else
              ModStr := 'const ';
          End;
          ParamType := EmitTypeRef(Param.TypeName);
          If SameText(Param.TypeName, 'String') Then ParamType := 'PChar';
          ParamListStr := ParamListStr + Format('%s%s: %s', [ModStr, Param.Name,
                          ParamType]);
          If I < Func.Params.Count - 1 Then
            ParamListStr := ParamListStr + '; ';
        End;

      If (Func.ReturnType = 'Void') Or (Func.ReturnType = '') Then
        Emit(Format('procedure %s(%s); cdecl;%s', [Func.Name, ParamListStr,
             LibClause]))
      Else
        Begin
          ParamType := EmitTypeRef(Func.ReturnType);
          If SameText(Func.ReturnType, 'String') Then ParamType := 'PChar';
          Emit(Format('function %s(%s): %s; cdecl;%s', [Func.Name, ParamListStr,
               ParamType, LibClause]));
        End;
      Emit('');
      Exit;
    End;

  ParamListStr := '';
  For I := 0 To Func.Params.Count - 1 Do
    Begin
      Param := TASTParam(Func.Params[I]);
      Case Param.Ownership Of 
        owMutBorrow: ModStr := 'var ';
        owBorrow:    ModStr := 'const ';
        owTake:      ModStr := '';
        Else
          ModStr := 'const ';
      End;
      ParamListStr := ParamListStr + Format('%s%s: %s', [ModStr, Param.Name,
                      EmitTypeRef(Param.TypeName)]);
      If I < Func.Params.Count - 1 Then
        ParamListStr := ParamListStr + '; ';
    End;

  ExportClause := '';
  If Func.IsExport Then
    ExportClause := ' cdecl;';
  If Func.InlineMode = 'always' Then
    ExportClause := ExportClause + ' inline;';

  If Func.IsAsync Then
    Emit(Format('function %s(%s): %s;%s', [Func.Name, ParamListStr, EmitTypeRef(
         'Task<' + Func.ReturnType + '>'), ExportClause]))
  Else If (Func.ReturnType = 'Void') Or (Func.ReturnType = '') Then
         Emit(Format('procedure %s(%s);%s', [Func.Name, ParamListStr,
              ExportClause]))
  Else
    Emit(Format('function %s(%s): %s;%s', [Func.Name, ParamListStr, EmitTypeRef(
         Func.ReturnType), ExportClause]));

  // Local Variables
  SkipNames := TStringList.Create;
  AutoNames := TStringList.Create;
  AutoTypes := TStringList.Create;
  Try
    For I := 0 To Func.Params.Count - 1 Do
      SkipNames.Add(TASTParam(Func.Params[I]).Name);
    For I := 0 To Func.LocalVars.Count - 1 Do
      Begin
        SkipNames.Add(TASTVarDecl(Func.LocalVars[I]).Name);
        If Assigned(TASTVarDecl(Func.LocalVars[I]).InitialExpr) And
           Not (TASTVarDecl(Func.LocalVars[I]).InitialExpr is TASTMapLiteralExpr
           ) Then
          CollectAutoVarsFromExpr(TASTVarDecl(Func.LocalVars[I]).InitialExpr,
          AutoNames, AutoTypes, SkipNames);
      End;
    CollectAutoVarsFromStmts(Func.Body, AutoNames, AutoTypes, SkipNames);

    If (Func.LocalVars.Count > 0) Or (AutoNames.Count > 0) Then
      Begin
        Emit('var');
        IncIndent;
        For I := 0 To Func.LocalVars.Count - 1 Do
          Begin
            VarDecl := TASTVarDecl(Func.LocalVars[I]);
            Emit(Format('%s: %s;', [VarDecl.Name, EmitTypeRef(VarDecl.TypeName)]
            ));
          End;
        For I := 0 To AutoNames.Count - 1 Do
          Emit(Format('%s: %s;', [AutoNames[I], AutoTypes[I]]));
        DecIndent;
      End;
  Finally
    SkipNames.Free;
    AutoNames.Free;
    AutoTypes.Free;
End;

Emit('begin');
IncIndent;

For I := 0 To Func.LocalVars.Count - 1 Do
  Begin
    VarDecl := TASTVarDecl(Func.LocalVars[I]);
    If Assigned(VarDecl.InitialExpr) Then
      Begin
        If VarDecl.InitialExpr is TASTMapLiteralExpr Then
          EmitMapLiteralAssign(VarDecl.Name, VarDecl.TypeName,
                               TASTMapLiteralExpr(VarDecl.InitialExpr))
        Else If (VarDecl.InitialExpr is TASTSetLiteralExpr) And (Not IsSetType(
                VarDecl.TypeName)) Then
               EmitArrayLiteralAssign(VarDecl.Name, VarDecl.TypeName,
                                      TASTSetLiteralExpr(VarDecl.InitialExpr))
        Else
          Emit(Format('%s := %s;', [VarDecl.Name, EmitExpr(VarDecl.InitialExpr)]
          ));
      End
    Else If (Pos('Box<', ResolveAliasType(VarDecl.TypeName)) = 1) Or (Pos('^',
            VarDecl.TypeName) = 1) Or SameText(VarDecl.TypeName, 'Pointer') Then
           Emit(Format('%s := nil;', [VarDecl.Name]))
    Else If IsMapType(VarDecl.TypeName, KeyT, ValT) Then
           Emit(Format('%s.count := 0; SetLength(%s.entries, 0);', [VarDecl.Name
                , VarDecl.Name]));
  End;

// Runtime require contract checks (Asserts)
For I := 0 To Func.Requires.Count - 1 Do
  Begin
    Emit(Format(
         'Assert(%s, ''Pre-condition (require) violation in function %s'');', [
         EmitExpr(TASTExpr(Func.Requires[I])), Func.Name]));
  End;

// Body
FActiveDefers.Clear;
FLoopDeferBase := 0;
FRaiiNames.Clear;
FRaiiTypes.Clear;
FLoopRaiiBase := 0;
FCurrentScopeList := Func.Body;
For I := 0 To Func.LocalVars.Count - 1 Do
  RegisterRaiiVar(TASTVarDecl(Func.LocalVars[I]).Name, TASTVarDecl(Func.
                                                                   LocalVars[I])
  .TypeName, Func.Body);
EmitStmtList(Func.Body);
FActiveDefers.Clear;

If (Func.Body.Count = 0) Or Not (Func.Body[Func.Body.Count - 1] is
   TASTReturnStmt) Then
  Begin
    For I := 0 To Func.Ensures.Count - 1 Do
      Emit(Format(
           'Assert(%s, ''Post-condition (ensure) violation in function %s'');',
           [EmitExpr(TASTExpr(Func.Ensures[I])), Func.Name]));
    If FRaiiNames.Count > 0 Then
      EmitActiveRaii(0);
    If Func.IsAsync And (Func.IsProcedure Or (Func.ReturnType = 'Void') Or (Func
       .ReturnType = '')) Then
      Begin
        Emit(Format(

      'Result := Default(%s); Result.state := nil; Result.is_completed := True;'
             ,
             [EmitTypeRef('Task<' + Func.ReturnType + '>')]));
      End;
  End;
FRaiiNames.Clear;
FRaiiTypes.Clear;
FCurrentScopeList := Nil;

DecIndent;
Emit('end;');
Emit('');
End;

Procedure TDelSafeEmitterPascal.EmitProgramBlock(Prog: TASTProgramBlock);

Var 
  I: Integer;
  VarDecl: TASTVarDecl;
  KeyT, ValT: string;
  SkipNames, AutoNames, AutoTypes: TStringList;
Begin
  FCurrentFunc := Nil;
  FProgramBlock := Prog;
  SkipNames := TStringList.Create;
  AutoNames := TStringList.Create;
  AutoTypes := TStringList.Create;
  Try
    For I := 0 To Prog.LocalVars.Count - 1 Do
      Begin
        SkipNames.Add(TASTVarDecl(Prog.LocalVars[I]).Name);
        If Assigned(TASTVarDecl(Prog.LocalVars[I]).InitialExpr) And
           Not (TASTVarDecl(Prog.LocalVars[I]).InitialExpr is TASTMapLiteralExpr
           ) Then
          CollectAutoVarsFromExpr(TASTVarDecl(Prog.LocalVars[I]).InitialExpr,
          AutoNames, AutoTypes, SkipNames);
      End;
    CollectAutoVarsFromStmts(Prog.Body, AutoNames, AutoTypes, SkipNames);

    If (Prog.LocalVars.Count > 0) Or (AutoNames.Count > 0) Then
      Begin
        Emit('var');
        IncIndent;
        For I := 0 To Prog.LocalVars.Count - 1 Do
          Begin
            VarDecl := TASTVarDecl(Prog.LocalVars[I]);
            Emit(Format('%s: %s;', [VarDecl.Name, EmitTypeRef(VarDecl.TypeName)]
            ));
          End;
        For I := 0 To AutoNames.Count - 1 Do
          Emit(Format('%s: %s;', [AutoNames[I], AutoTypes[I]]));
        DecIndent;
      End;
  Finally
    SkipNames.Free;
    AutoNames.Free;
    AutoTypes.Free;
End;

Emit('begin');
IncIndent;
If Assigned(FModule) Then
  Begin
    For I := 0 To FModule.ModuleVars.Count - 1 Do
      Begin
        VarDecl := TASTVarDecl(FModule.ModuleVars[I]);
        If Assigned(VarDecl.InitialExpr) Then
          Begin
            If VarDecl.InitialExpr is TASTMapLiteralExpr Then
              EmitMapLiteralAssign(VarDecl.Name, VarDecl.TypeName,
                                   TASTMapLiteralExpr(VarDecl.InitialExpr))
            Else If (VarDecl.InitialExpr is TASTSetLiteralExpr) And (Not
                    IsSetType(VarDecl.TypeName)) Then
                   EmitArrayLiteralAssign(VarDecl.Name, VarDecl.TypeName,
                                          TASTSetLiteralExpr(VarDecl.InitialExpr
                   ))
            Else
              Emit(Format('%s := %s;', [VarDecl.Name, EmitExpr(VarDecl.
                   InitialExpr)]));
          End
        Else If (Pos('Box<', ResolveAliasType(VarDecl.TypeName)) = 1) Or (Pos(
                '^', VarDecl.TypeName) = 1) Or SameText(VarDecl.TypeName,
                'Pointer') Then
               Emit(Format('%s := nil;', [VarDecl.Name]))
        Else If IsMapType(VarDecl.TypeName, KeyT, ValT) Then
               Emit(Format('%s.count := 0; SetLength(%s.entries, 0);', [VarDecl.
                    Name, VarDecl.Name]));
      End;
    For I := 0 To FModule.InitProcs.Count - 1 Do
      Emit(Format('%s;', [FModule.InitProcs[I]]));
  End;

For I := 0 To Prog.LocalVars.Count - 1 Do
  Begin
    VarDecl := TASTVarDecl(Prog.LocalVars[I]);
    If Assigned(VarDecl.InitialExpr) Then
      Begin
        If VarDecl.InitialExpr is TASTMapLiteralExpr Then
          EmitMapLiteralAssign(VarDecl.Name, VarDecl.TypeName,
                               TASTMapLiteralExpr(VarDecl.InitialExpr))
        Else If (VarDecl.InitialExpr is TASTSetLiteralExpr) And (Not IsSetType(
                VarDecl.TypeName)) Then
               EmitArrayLiteralAssign(VarDecl.Name, VarDecl.TypeName,
                                      TASTSetLiteralExpr(VarDecl.InitialExpr))
        Else
          Emit(Format('%s := %s;', [VarDecl.Name, EmitExpr(VarDecl.InitialExpr)]
          ));
      End
    Else If (Pos('Box<', ResolveAliasType(VarDecl.TypeName)) = 1) Or (Pos('^',
            VarDecl.TypeName) = 1) Or SameText(VarDecl.TypeName, 'Pointer') Then
           Emit(Format('%s := nil;', [VarDecl.Name]))
    Else If IsMapType(VarDecl.TypeName, KeyT, ValT) Then
           Emit(Format('%s.count := 0; SetLength(%s.entries, 0);', [VarDecl.Name
                , VarDecl.Name]));
  End;

If Assigned(FModule) And (FModule.FiniProcs.Count > 0) Then
  Begin
    Emit('try');
    IncIndent;
  End;

FActiveDefers.Clear;
FLoopDeferBase := 0;
FRaiiNames.Clear;
FRaiiTypes.Clear;
FLoopRaiiBase := 0;
FCurrentScopeList := Prog.Body;
For I := 0 To Prog.LocalVars.Count - 1 Do
  RegisterRaiiVar(TASTVarDecl(Prog.LocalVars[I]).Name, TASTVarDecl(Prog.
                                                                   LocalVars[I])
  .TypeName, Prog.Body);
EmitStmtList(Prog.Body);
FActiveDefers.Clear;
If (Prog.Body.Count = 0) Or Not (Prog.Body[Prog.Body.Count - 1] is
   TASTReturnStmt) Then
  Begin
    If FRaiiNames.Count > 0 Then
      EmitActiveRaii(0);
  End;
FRaiiNames.Clear;
FRaiiTypes.Clear;
FCurrentScopeList := Nil;

If Assigned(FModule) And (FModule.FiniProcs.Count > 0) Then
  Begin
    DecIndent;
    Emit('finally');
    IncIndent;
    For I := FModule.FiniProcs.Count - 1 Downto 0 Do
      Emit(Format('%s;', [FModule.FiniProcs[I]]));
    DecIndent;
    Emit('end;');
  End;

DecIndent;
Emit('end.');
End;

Function TDelSafeEmitterPascal.BuildFuncSig(Func: TASTFunction): string;

Var 
  J: Integer;
  Param: TASTParam;
  ParamListStr, ModStr, LibClause, ParamType, ExportClause: string;
Begin
  If SameText(Func.Name, 'Abs') Or SameText(Func.Name, 'Min') Or SameText(Func.
     Name, 'Max') Or SameText(Func.Name, 'Clamp') Then
    Exit('');
  If Func.IsExtern Then
    Begin
      If (Func.ExternAbi = 'pascal') Or (Func.ExternLib = 'pascal') Or (
         LowerCase(Func.ExternLib) = 'unit') Then
        Exit('');

      If (Func.ExternLib = '') And ((Func.Name = 'sin') Or (Func.Name = 'cos')
         Or (Func.Name = 'sqrt')) Then
        Exit('');

      If Func.ExternLib <> '' Then
        LibClause := Format(' external ''%s'';', [ResolvePascalExternLib(Func.
                     ExternLib)])
      Else
        LibClause := ' external ''msvcrt'';';

      ParamListStr := '';
      For J := 0 To Func.Params.Count - 1 Do
        Begin
          Param := TASTParam(Func.Params[J]);
          Case Param.Ownership Of 
            owMutBorrow: ModStr := 'var ';
            owBorrow:    ModStr := 'const ';
            Else
              ModStr := 'const ';
          End;
          ParamType := EmitTypeRef(Param.TypeName);
          If SameText(Param.TypeName, 'String') Then ParamType := 'PChar';
          ParamListStr := ParamListStr + Format('%s%s: %s', [ModStr, Param.Name,
                          ParamType]);
          If J < Func.Params.Count - 1 Then
            ParamListStr := ParamListStr + '; ';
        End;

      If (Func.ReturnType = 'Void') Or (Func.ReturnType = '') Then
        Result := Format('procedure %s(%s); cdecl;%s', [Func.Name, ParamListStr,
                  LibClause])
      Else
        Begin
          ParamType := EmitTypeRef(Func.ReturnType);
          If SameText(Func.ReturnType, 'String') Then ParamType := 'PChar';
          Result := Format('function %s(%s): %s; cdecl;%s', [Func.Name,
                    ParamListStr, ParamType, LibClause]);
        End;
      Exit;
    End;

  ParamListStr := '';
  For J := 0 To Func.Params.Count - 1 Do
    Begin
      Param := TASTParam(Func.Params[J]);
      Case Param.Ownership Of 
        owMutBorrow: ModStr := 'var ';
        owBorrow:    ModStr := 'const ';
        owTake:      ModStr := '';
        Else
          ModStr := 'const ';
      End;
      ParamListStr := ParamListStr + Format('%s%s: %s', [ModStr, Param.Name,
                      EmitTypeRef(Param.TypeName)]);
      If J < Func.Params.Count - 1 Then
        ParamListStr := ParamListStr + '; ';
    End;

  ExportClause := '';
  If Func.IsExport Then
    ExportClause := ' cdecl;';

  If Func.IsAsync Then
    Result := Format('function %s(%s): %s;%s', [Func.Name, ParamListStr,
              EmitTypeRef('Task<' + Func.ReturnType + '>'), ExportClause])
  Else If (Func.ReturnType = 'Void') Or (Func.ReturnType = '') Then
         Result := Format('procedure %s(%s);%s', [Func.Name, ParamListStr,
                   ExportClause])
  Else
    Result := Format('function %s(%s): %s;%s', [Func.Name, ParamListStr,
              EmitTypeRef(Func.ReturnType), ExportClause]);
End;

Function TDelSafeEmitterPascal.BuildRecordConstructorSig(Rec: TASTRecordDecl):

                                                                          string
;

Var 
  I: Integer;
  Field: TASTRecordField;
  CtorParams: string;
Begin
  CtorParams := '';
  For I := 0 To Rec.Fields.Count - 1 Do
    Begin
      Field := TASTRecordField(Rec.Fields[I]);
      CtorParams := CtorParams + Format('const A_%s: %s', [Field.Name,
                    EmitTypeRef(Field.TypeName)]);
      If I < Rec.Fields.Count - 1 Then
        CtorParams := CtorParams + '; ';
    End;
  Result := Format('function %s(%s): T%s;', [Rec.Name, CtorParams, Rec.Name]);
End;

Procedure TDelSafeEmitterPascal.EmitRuntimeTypeDecls(Const RefText: String;
                                                    MapTags, MapKeys, MapVals:
                                                    TStringList; AsUnit: Boolean
                                                    ; SkipCoreRuntime: Boolean);

Var 
  I: Integer;
  NeedFloat64, NeedFloat32, NeedPtr, NeedDyn, NeedResult, NeedTask, NeedOption,
  HasBuiltinMap, HasAnyType: Boolean;
Begin
  NeedFloat64 := (Not SkipCoreRuntime) And (Pos('Float64', RefText) > 0);
  NeedFloat32 := (Not SkipCoreRuntime) And (Pos('Float32', RefText) > 0);
  NeedPtr := (Not SkipCoreRuntime) And (Pos('PDelSafePtr_', RefText) > 0);
  NeedDyn := (Not SkipCoreRuntime) And ((Pos('TDelSafeDyn_', RefText) > 0) Or (
             Pos('DelSafeDynPop_', RefText) > 0) Or
             (Pos('DelSafeStrSplit', RefText) > 0) Or (Pos('DelSafeStrJoin',
             RefText) > 0) Or
             (Pos('DelSafeListDir', RefText) > 0));
  NeedResult := (Not SkipCoreRuntime) And ((Pos('TDelSafeResult', RefText) > 0)
                Or (Pos('TResultDoubleError', RefText) > 0) Or
                (Pos('DelSafeOk(', RefText) > 0) Or (Pos('DelSafeErr(', RefText) >
                0));
  NeedTask := False;
  NeedOption := (Not SkipCoreRuntime) And ((Pos('TDelSafeOption', RefText) > 0)
                Or (Pos('DelSafeSome(', RefText) > 0) Or
                (Pos('DelSafeNone(', RefText) > 0) Or (Pos('DelSafeTryStrToInt',
                RefText) > 0) Or
                (Pos('DelSafeTryStrToFloat', RefText) > 0));
  HasBuiltinMap := False;
  For I := 0 To MapTags.Count - 1 Do
    If IsBuiltinMapSideType(MapKeys[I]) And IsBuiltinMapSideType(MapVals[I])
      Then
      Begin
        HasBuiltinMap := True;
        Break;
      End;
  HasAnyType := NeedFloat64 Or NeedFloat32 Or NeedPtr Or NeedDyn Or NeedResult
                Or NeedTask Or NeedOption Or HasBuiltinMap;
  If Not HasAnyType Then Exit;

  If AsUnit Then
    Emit('// --- DelSafe Runtime Helpers & Monads ---')
  Else
    Emit('// --- DelSafe Runtime Helpers ---');

  If NeedFloat64 Or NeedFloat32 Or NeedDyn Or NeedResult Then
    Begin
      Emit('type');
      If NeedFloat64 Then Emit('  Float64 = Double;');
      If NeedFloat32 Then Emit('  Float32 = Single;');
      If NeedDyn Then
        Begin
          Emit(

'  TDelSafeDyn_Int8 = array of Int8; TDelSafeDyn_Int16 = array of Int16; TDelSafeDyn_Int32 = array of Int32; TDelSafeDyn_Int64 = array of Int64;'
          );
          Emit(

'  TDelSafeDyn_UInt8 = array of UInt8; TDelSafeDyn_UInt16 = array of UInt16; TDelSafeDyn_UInt32 = array of UInt32; TDelSafeDyn_UInt64 = array of UInt64;'
          );
          Emit(

'  TDelSafeDyn_Float32 = array of Single; TDelSafeDyn_Float64 = array of Double; TDelSafeDyn_Bool = array of Boolean; TDelSafeDyn_Char = array of Char;'
          );
          Emit('  TDelSafeDyn_String = array of String;');
          Emit(

              '  {$IFNDEF PAS2JS}TDelSafeDyn_Pointer = array of Pointer;{$ENDIF}'
          );
        End;
      If NeedResult Then
        Begin
          Emit('  generic TDelSafeResult<TVal, TErr> = record');
          Emit('    is_ok: Boolean;');
          Emit('    is_err: Boolean;');
          Emit('    value: TVal;');
          Emit('    error: TErr;');
          Emit('    str_val: String;');
          Emit('    err_str: String;');
          Emit('  end;');
          Emit(

             '  TResultDoubleError = specialize TDelSafeResult<Double, Integer>;'
          );
        End;
      Emit('');
    End;

  If NeedPtr Then
    Begin
      Emit('{$IFNDEF PAS2JS}');
      Emit('type');
      Emit(

'  PDelSafePtr_Int8 = ^Int8; PDelSafePtr_Int16 = ^Int16; PDelSafePtr_Int32 = ^Int32; PDelSafePtr_Int64 = ^Int64;'
      );
      Emit(

'  PDelSafePtr_UInt8 = ^UInt8; PDelSafePtr_UInt16 = ^UInt16; PDelSafePtr_UInt32 = ^UInt32; PDelSafePtr_UInt64 = ^UInt64;'
      );
      Emit(

'  PDelSafePtr_Float32 = ^Single; PDelSafePtr_Float64 = ^Double; PDelSafePtr_Bool = ^Boolean; PDelSafePtr_Char = ^Char; PDelSafePtr_String = ^String;'
      );
      Emit('{$ENDIF}');
      Emit('');
    End;

  If NeedTask Then
    Begin
      Emit('type');
      Emit('  generic TDelSafeTask<TVal> = record');
      Emit('    is_completed: Boolean;');
      Emit('    value: TVal;');
      Emit('  end;');
      Emit('');
    End;

  If NeedOption Then
    Begin
      Emit('type');
      Emit('  TDelSafeOption = record');
      Emit('    is_some: Boolean;');
      Emit('    is_none: Boolean;');
      Emit('    num_val: Double;');
      Emit('    str_val: String;');
      Emit('  end;');
      Emit('');
    End;

  If HasBuiltinMap Then
    Begin
      Emit('type');
      EmitMapRuntimeDecls(MapTags, MapKeys, MapVals, True);
      Emit('');
    End;
End;

Procedure TDelSafeEmitterPascal.EmitRuntimeHelpersInterface(Const RefText: String
);

Var 
  NeedResult, NeedOption, NeedFileIO, NeedJson, NeedSockets, NeedSync,
  EmittedAny: Boolean;
Begin
  EmittedAny := False;
  NeedResult := (Pos('DelSafeOk(', RefText) > 0) Or (Pos('DelSafeErr(', RefText) >
                0);
  NeedOption := (Pos('DelSafeSome(', RefText) > 0) Or (Pos('DelSafeNone(', RefText
                ) > 0) Or
                (Pos('DelSafeTryStrToInt', RefText) > 0) Or (Pos(
                'DelSafeTryStrToFloat', RefText) > 0);
  NeedFileIO := (Pos('DelSafeFileExists', RefText) > 0) Or (Pos('DelSafeReadFile',
                RefText) > 0) Or
                (Pos('DelSafeWriteFile', RefText) > 0) Or (Pos('DelSafeCreateDir',
                RefText) > 0) Or
                (Pos('DelSafeRemoveDir', RefText) > 0) Or (Pos('DelSafeDeleteFile'
                , RefText) > 0) Or
                (Pos('DelSafeDirExists', RefText) > 0) Or (Pos('DelSafeFileSize',
                RefText) > 0) Or
                (Pos('DelSafeListDir', RefText) > 0) Or (Pos('DelSafeCopyFile',
                RefText) > 0) Or
                (Pos('DelSafeRenameFile', RefText) > 0);
  NeedJson := (Pos('DelSafeJson', RefText) > 0);
  NeedSockets := (Pos('DelSafeSocket', RefText) > 0);

  If NeedResult Then
    Begin
      Emit('function DelSafeOk(const V: Double): TResultDoubleError; overload;');
      Emit('function DelSafeOk(const V: String): TResultDoubleError; overload;');
      Emit('function DelSafeOk(const V: Boolean): TResultDoubleError; overload;')
      ;
      Emit('function DelSafeErr(const E: Integer): TResultDoubleError; overload;'
      );
      Emit('function DelSafeErr(const E: String): TResultDoubleError; overload;')
      ;
      EmittedAny := True;
    End;
  If NeedOption Then
    Begin
      Emit('function DelSafeSome(const V: Double): TDelSafeOption; overload;');
      Emit('function DelSafeSome(const V: String): TDelSafeOption; overload;');
      Emit('function DelSafeSome(const V: Boolean): TDelSafeOption; overload;');
      Emit('function DelSafeNone(): TDelSafeOption;');
      EmittedAny := True;
    End;
  If Pos('DelSafeDynPop_Int8', RefText) > 0 Then
    Begin
      Emit('function DelSafeDynPop_Int8(var A: TDelSafeDyn_Int8): Int8;');
      EmittedAny := True;
    End;
  If Pos('DelSafeDynPop_Int16', RefText) > 0 Then
    Begin
      Emit('function DelSafeDynPop_Int16(var A: TDelSafeDyn_Int16): Int16;');
      EmittedAny := True;
    End;
  If Pos('DelSafeDynPop_Int32', RefText) > 0 Then
    Begin
      Emit('function DelSafeDynPop_Int32(var A: TDelSafeDyn_Int32): Int32;');
      EmittedAny := True;
    End;
  If Pos('DelSafeDynPop_Int64', RefText) > 0 Then
    Begin
      Emit('function DelSafeDynPop_Int64(var A: TDelSafeDyn_Int64): Int64;');
      EmittedAny := True;
    End;
  If Pos('DelSafeDynPop_UInt8', RefText) > 0 Then
    Begin
      Emit('function DelSafeDynPop_UInt8(var A: TDelSafeDyn_UInt8): UInt8;');
      EmittedAny := True;
    End;
  If Pos('DelSafeDynPop_UInt16', RefText) > 0 Then
    Begin
      Emit('function DelSafeDynPop_UInt16(var A: TDelSafeDyn_UInt16): UInt16;');
      EmittedAny := True;
    End;
  If Pos('DelSafeDynPop_UInt32', RefText) > 0 Then
    Begin
      Emit('function DelSafeDynPop_UInt32(var A: TDelSafeDyn_UInt32): UInt32;');
      EmittedAny := True;
    End;
  If Pos('DelSafeDynPop_UInt64', RefText) > 0 Then
    Begin
      Emit('function DelSafeDynPop_UInt64(var A: TDelSafeDyn_UInt64): UInt64;');
      EmittedAny := True;
    End;
  If Pos('DelSafeDynPop_Float32', RefText) > 0 Then
    Begin
      Emit('function DelSafeDynPop_Float32(var A: TDelSafeDyn_Float32): Single;');
      EmittedAny := True;
    End;
  If Pos('DelSafeDynPop_Float64', RefText) > 0 Then
    Begin
      Emit('function DelSafeDynPop_Float64(var A: TDelSafeDyn_Float64): Double;');
      EmittedAny := True;
    End;
  If Pos('DelSafeDynPop_Bool', RefText) > 0 Then
    Begin
      Emit('function DelSafeDynPop_Bool(var A: TDelSafeDyn_Bool): Boolean;');
      EmittedAny := True;
    End;
  If Pos('DelSafeDynPop_Char', RefText) > 0 Then
    Begin
      Emit('function DelSafeDynPop_Char(var A: TDelSafeDyn_Char): Char;');
      EmittedAny := True;
    End;
  If Pos('DelSafeDynPop_String', RefText) > 0 Then
    Begin
      Emit('function DelSafeDynPop_String(var A: TDelSafeDyn_String): String;');
      EmittedAny := True;
    End;
  If Pos('DelSafeDynPop_Pointer', RefText) > 0 Then
    Begin
      Emit(

'{$IFNDEF PAS2JS}function DelSafeDynPop_Pointer(var A: TDelSafeDyn_Pointer): Pointer;{$ENDIF}'
      );
      EmittedAny := True;
    End;
  If Pos('DelSafeCharAt', RefText) > 0 Then
    Begin
      Emit('function DelSafeCharAt(const S: string; Index: Cardinal): string;');
      EmittedAny := True;
    End;
  If Pos('DelSafeByteAt', RefText) > 0 Then
    Begin
      Emit('function DelSafeByteAt(const S: string; Index: LongInt): LongInt;');
      EmittedAny := True;
    End;
  If Pos('DelSafeCharFromByte', RefText) > 0 Then
    Begin
      Emit('function DelSafeCharFromByte(B: LongInt): string;');
      EmittedAny := True;
    End;
  If Pos('DelSafeSubstring', RefText) > 0 Then
    Begin
      Emit(

      'function DelSafeSubstring(const S: string; Start, Len: Cardinal): string;'
      );
      EmittedAny := True;
    End;
  If Pos('DelSafeIfThen', RefText) > 0 Then
    Begin
      Emit('generic function DelSafeIfThen<T>(Cond: Boolean; const A, B: T): T;')
      ;
      EmittedAny := True;
    End;
  If Pos('DelSafeMin', RefText) > 0 Then
    Begin
      Emit('generic function DelSafeMin<T>(const A, B: T): T;');
      EmittedAny := True;
    End;
  If Pos('DelSafeMax', RefText) > 0 Then
    Begin
      Emit('generic function DelSafeMax<T>(const A, B: T): T;');
      EmittedAny := True;
    End;
  If Pos('DelSafeClamp', RefText) > 0 Then
    Begin
      Emit('generic function DelSafeClamp<T>(const V, Lo, Hi: T): T;');
      EmittedAny := True;
    End;
  If Pos('DelSafeStrTrim', RefText) > 0 Then
    Begin
      Emit('function DelSafeStrTrim(const S: string): string;');
      EmittedAny := True;
    End;
  If Pos('DelSafeUpperCase', RefText) > 0 Then
    Begin
      Emit('function DelSafeUpperCase(const S: string): string;');
      EmittedAny := True;
    End;
  If Pos('DelSafeLowerCase', RefText) > 0 Then
    Begin
      Emit('function DelSafeLowerCase(const S: string): string;');
      EmittedAny := True;
    End;
  If Pos('DelSafeStartsWith', RefText) > 0 Then
    Begin
      Emit('function DelSafeStartsWith(const S, Prefix: string): Boolean;');
      EmittedAny := True;
    End;
  If Pos('DelSafeEndsWith', RefText) > 0 Then
    Begin
      Emit('function DelSafeEndsWith(const S, Suffix: string): Boolean;');
      EmittedAny := True;
    End;
  If Pos('DelSafeStrContains', RefText) > 0 Then
    Begin
      Emit('function DelSafeStrContains(const S, Sub: string): Boolean;');
      EmittedAny := True;
    End;
  If Pos('DelSafeIndexOf', RefText) > 0 Then
    Begin
      Emit('function DelSafeIndexOf(const S, Sub: string): Int32;');
      EmittedAny := True;
    End;
  If Pos('DelSafeStrReplace', RefText) > 0 Then
    Begin
      Emit('function DelSafeStrReplace(const S, OldStr, NewStr: string): string;'
      );
      EmittedAny := True;
    End;
  If Pos('DelSafeStrSplit', RefText) > 0 Then
    Begin
      Emit('function DelSafeStrSplit(const S, Sep: string): TDelSafeDyn_String;');
      EmittedAny := True;
    End;
  If Pos('DelSafeStrJoin', RefText) > 0 Then
    Begin
      Emit(

'function DelSafeStrJoin(const Parts: TDelSafeDyn_String; const Sep: string): string;'
      );
      EmittedAny := True;
    End;
  If Pos('DelSafePadLeft', RefText) > 0 Then
    Begin
      Emit(

'function DelSafePadLeft(const S: string; Width: Int32; const Pad: string): string;'
      );
      EmittedAny := True;
    End;
  If Pos('DelSafePadRight', RefText) > 0 Then
    Begin
      Emit(

'function DelSafePadRight(const S: string; Width: Int32; const Pad: string): string;'
      );
      EmittedAny := True;
    End;
  If Pos('DelSafeRepeatStr', RefText) > 0 Then
    Begin
      Emit('function DelSafeRepeatStr(const S: string; Count: Int32): string;');
      EmittedAny := True;
    End;
  If Pos('DelSafeStrToFloat', RefText) > 0 Then
    Begin
      Emit('function DelSafeStrToFloat(const S: string): Double;');
      EmittedAny := True;
    End;
  If Pos('DelSafeTryStrToInt', RefText) > 0 Then
    Begin
      Emit('function DelSafeTryStrToInt(const S: string): TDelSafeOption;');
      EmittedAny := True;
    End;
  If Pos('DelSafeTryStrToFloat', RefText) > 0 Then
    Begin
      Emit('function DelSafeTryStrToFloat(const S: string): TDelSafeOption;');
      EmittedAny := True;
    End;
  If Pos('DelSafeRound', RefText) > 0 Then
    Begin
      Emit('function DelSafeRound(V: Double): Double;');
      EmittedAny := True;
    End;
  If Pos('DelSafeRandomInt', RefText) > 0 Then
    Begin
      Emit('function DelSafeRandomInt(MinV, MaxV: Int32): Int32;');
      EmittedAny := True;
    End;
  If Pos('DelSafeRandomFloat', RefText) > 0 Then
    Begin
      Emit('function DelSafeRandomFloat(): Double;');
      EmittedAny := True;
    End;
  If Pos('DelSafeReadLn', RefText) > 0 Then
    Begin
      Emit('function DelSafeReadLn(): string;');
      EmittedAny := True;
    End;
  If Pos('DelSafeGetEnv', RefText) > 0 Then
    Begin
      Emit('function DelSafeGetEnv(const AName: string): string;');
      EmittedAny := True;
    End;
  If Pos('DelSafeSetEnv', RefText) > 0 Then
    Begin
      Emit('function DelSafeSetEnv(const AName, AVal: string): Boolean;');
      EmittedAny := True;
    End;
  If NeedFileIO Then
    Begin
      Emit('function DelSafeFileExists(const APath: string): Boolean;');
      Emit('function DelSafeReadFile(const APath: string): string;');
      Emit(

'function DelSafeWriteFile(const APath: string; const AContent: string): Boolean;'
      );
      Emit('function DelSafeCreateDir(const APath: string): Boolean;');
      Emit('function DelSafeRemoveDir(const APath: string): Boolean;');
      Emit('function DelSafeDeleteFile(const APath: string): Boolean;');
      Emit('function DelSafeDirExists(const APath: string): Boolean;');
      Emit(

'function DelSafeFileSize(const APath: string): {$IFDEF PAS2JS}NativeInt{$ELSE}Int64{$ENDIF};'
      );
      If Pos('DelSafeListDir', RefText) > 0 Then Emit(

               'function DelSafeListDir(const APath: string): TDelSafeDyn_String;'
        );
      If Pos('DelSafeCopyFile', RefText) > 0 Then Emit(

                   'function DelSafeCopyFile(const ASrc, ADst: string): Boolean;'
        );
      If Pos('DelSafeRenameFile', RefText) > 0 Then Emit(

                 'function DelSafeRenameFile(const AOld, ANew: string): Boolean;'
        );
      EmittedAny := True;
    End;
  If Pos('DelSafeBoolToStr', RefText) > 0 Then
    Begin
      Emit('function DelSafeBoolToStr(B: Boolean): string;');
      EmittedAny := True;
    End;
  If Pos('DelSafeFloatToStr', RefText) > 0 Then
    Begin
      Emit('function DelSafeFloatToStr(AVal: Double): string;');
      EmittedAny := True;
    End;
  If NeedJson Then
    Begin
      Emit('function DelSafeJsonExtractRaw(const Json, Key: string): string;');
      Emit('function DelSafeJsonGetStr(const Json, Key: string): string;');
      Emit('function DelSafeJsonGetInt(const Json, Key: string): Int32;');
      Emit('function DelSafeJsonGetFloat(const Json, Key: string): Double;');
      Emit('function DelSafeJsonGetBool(const Json, Key: string): Boolean;');
      Emit('function DelSafeJsonGetChar(const Json, Key: string): Char;');
      Emit('function DelSafeJsonHasValue(const Json, Key: string): Boolean;');
      Emit('function DelSafeJsonGetObj(const Json, Key: string): string;');
      EmittedAny := True;
    End;
  If Pos('DelSafeGetNanoseconds', RefText) > 0 Then
    Begin
      Emit(

     'function DelSafeGetNanoseconds: {$IFDEF PAS2JS}Double{$ELSE}QWord{$ENDIF};'
      );
      EmittedAny := True;
    End;
  If Pos('DelSafeSleepMs', RefText) > 0 Then
    Begin
      Emit('procedure DelSafeSleepMs(AMs: Cardinal);');
      EmittedAny := True;
    End;
  NeedSync := (Pos('DelSafeSync', RefText) > 0);
  If NeedSync Then
    Begin
      Emit('{$IFNDEF PAS2JS}');
      Emit('function DelSafeSyncAtomicNew(AInit: Int32): Pointer;');
      Emit('function DelSafeSyncAtomicLoad(P: Pointer): Int32;');
      Emit('procedure DelSafeSyncAtomicStore(P: Pointer; V: Int32);');
      Emit('function DelSafeSyncAtomicAdd(P: Pointer; Delta: Int32): Int32;');
      Emit(

  'function DelSafeSyncAtomicCas(P: Pointer; Expected, Desired: Int32): Boolean;'
      );
      Emit('procedure DelSafeSyncAtomicFree(P: Pointer);');
      Emit('function DelSafeSyncMutexNew(): Pointer;');
      Emit('procedure DelSafeSyncMutexLock(P: Pointer);');
      Emit('function DelSafeSyncMutexTryLock(P: Pointer): Boolean;');
      Emit('procedure DelSafeSyncMutexUnlock(P: Pointer);');
      Emit('procedure DelSafeSyncMutexFree(P: Pointer);');
      Emit('{$ENDIF}');
      EmittedAny := True;
    End;
  If NeedSockets Then
    Begin
      Emit('function DelSafeSocketCreate(): LongInt;');
      Emit('function DelSafeSocketListen(Port: Word; Backlog: LongInt): LongInt;'
      );
      Emit('function DelSafeSocketAccept(ListenFd: LongInt): LongInt;');
      Emit(

        'function DelSafeSocketConnect(const Host: String; Port: Word): LongInt;'
      );
      Emit(

          'function DelSafeSocketSend(Fd: LongInt; const Data: String): LongInt;'
      );
      Emit('function DelSafeSocketRecv(Fd: LongInt; MaxLen: LongInt): String;');
      Emit('procedure DelSafeSocketClose(Fd: LongInt);');
      Emit(

       'function DelSafeSocketSetTimeout(Fd, ReadMs, WriteMs: LongInt): Boolean;'
      );
      Emit('function DelSafeSocketPeerIP(Fd: LongInt): String;');
      Emit(

    'function DelSafeSocketSendHex(Fd: LongInt; const HexData: String): LongInt;'
      );
      Emit('function DelSafeSocketRecvHex(Fd, MaxLen: LongInt): String;');
      Emit('function DelSafeSocketSendFile(Fd: LongInt; const Path: String): Int64;');
      EmittedAny := True;
    End;
  If EmittedAny Then Emit('');
End;

Procedure TDelSafeEmitterPascal.EmitRuntimeHelpersImplementation(Const RefText:
                                                                String);

Var 
  NeedResult, NeedOption, NeedFileIO, NeedJson, NeedSockets, HadPop: Boolean;
Begin
  NeedResult := (Pos('DelSafeOk(', RefText) > 0) Or (Pos('DelSafeErr(', RefText) >
                0);
  NeedOption := (Pos('DelSafeSome(', RefText) > 0) Or (Pos('DelSafeNone(', RefText
                ) > 0) Or
                (Pos('DelSafeTryStrToInt', RefText) > 0) Or (Pos(
                'DelSafeTryStrToFloat', RefText) > 0);
  NeedFileIO := (Pos('DelSafeFileExists', RefText) > 0) Or (Pos('DelSafeReadFile',
                RefText) > 0) Or
                (Pos('DelSafeWriteFile', RefText) > 0) Or (Pos('DelSafeCreateDir',
                RefText) > 0) Or
                (Pos('DelSafeRemoveDir', RefText) > 0) Or (Pos('DelSafeDeleteFile'
                , RefText) > 0) Or
                (Pos('DelSafeDirExists', RefText) > 0) Or (Pos('DelSafeFileSize',
                RefText) > 0) Or
                (Pos('DelSafeListDir', RefText) > 0) Or (Pos('DelSafeCopyFile',
                RefText) > 0) Or
                (Pos('DelSafeRenameFile', RefText) > 0);
  NeedJson := (Pos('DelSafeJson', RefText) > 0);
  NeedSockets := (Pos('DelSafeSocket', RefText) > 0);

  If NeedResult Then
    Begin
      Emit('function DelSafeOk(const V: Double): TResultDoubleError; overload;');
      Emit(

'begin Result := Default(TResultDoubleError); Result.is_ok := True; Result.is_err := False; Result.value := V; end;'
      );
      Emit('');
      Emit('function DelSafeOk(const V: String): TResultDoubleError; overload;');
      Emit(

'begin Result := Default(TResultDoubleError); Result.is_ok := True; Result.is_err := False; Result.str_val := V; end;'
      );
      Emit('');
      Emit('function DelSafeOk(const V: Boolean): TResultDoubleError; overload;')
      ;
      Emit(

'begin Result := Default(TResultDoubleError); Result.is_ok := True; Result.is_err := False; if V then Result.value := 1 else Result.value := 0; end;'
      );
      Emit('');
      Emit('function DelSafeErr(const E: Integer): TResultDoubleError; overload;'
      );
      Emit(

'begin Result := Default(TResultDoubleError); Result.is_ok := False; Result.is_err := True; Result.error := E; end;'
      );
      Emit('');
      Emit('function DelSafeErr(const E: String): TResultDoubleError; overload;')
      ;
      Emit(

'begin Result := Default(TResultDoubleError); Result.is_ok := False; Result.is_err := True; Result.err_str := E; end;'
      );
      Emit('');
    End;

  If NeedOption Then
    Begin
      Emit('function DelSafeSome(const V: Double): TDelSafeOption; overload;');
      Emit(

'begin Result.is_some := True; Result.is_none := False; Result.num_val := V; Result.str_val := ''''; end;'
      );
      Emit('');
      Emit('function DelSafeSome(const V: String): TDelSafeOption; overload;');
      Emit(

'begin Result.is_some := True; Result.is_none := False; Result.num_val := 0; Result.str_val := V; end;'
      );
      Emit('');
      Emit('function DelSafeSome(const V: Boolean): TDelSafeOption; overload;');
      Emit(

'begin Result.is_some := True; Result.is_none := False; if V then Result.num_val := 1 else Result.num_val := 0; Result.str_val := ''''; end;'
      );
      Emit('');
      Emit('function DelSafeNone(): TDelSafeOption;');
      Emit(

'begin Result.is_some := False; Result.is_none := True; Result.num_val := 0; Result.str_val := ''''; end;'
      );
      Emit('');
    End;

  HadPop := False;
  If Pos('DelSafeDynPop_Int8', RefText) > 0 Then
    Begin
      Emit(

'function DelSafeDynPop_Int8(var A: TDelSafeDyn_Int8): Int8; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'
      );
      HadPop := True;
    End;
  If Pos('DelSafeDynPop_Int16', RefText) > 0 Then
    Begin
      Emit(

'function DelSafeDynPop_Int16(var A: TDelSafeDyn_Int16): Int16; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'
      );
      HadPop := True;
    End;
  If Pos('DelSafeDynPop_Int32', RefText) > 0 Then
    Begin
      Emit(

'function DelSafeDynPop_Int32(var A: TDelSafeDyn_Int32): Int32; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'
      );
      HadPop := True;
    End;
  If Pos('DelSafeDynPop_Int64', RefText) > 0 Then
    Begin
      Emit(

'function DelSafeDynPop_Int64(var A: TDelSafeDyn_Int64): Int64; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'
      );
      HadPop := True;
    End;
  If Pos('DelSafeDynPop_UInt8', RefText) > 0 Then
    Begin
      Emit(

'function DelSafeDynPop_UInt8(var A: TDelSafeDyn_UInt8): UInt8; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'
      );
      HadPop := True;
    End;
  If Pos('DelSafeDynPop_UInt16', RefText) > 0 Then
    Begin
      Emit(

'function DelSafeDynPop_UInt16(var A: TDelSafeDyn_UInt16): UInt16; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'
      );
      HadPop := True;
    End;
  If Pos('DelSafeDynPop_UInt32', RefText) > 0 Then
    Begin
      Emit(

'function DelSafeDynPop_UInt32(var A: TDelSafeDyn_UInt32): UInt32; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'
      );
      HadPop := True;
    End;
  If Pos('DelSafeDynPop_UInt64', RefText) > 0 Then
    Begin
      Emit(

'function DelSafeDynPop_UInt64(var A: TDelSafeDyn_UInt64): UInt64; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'
      );
      HadPop := True;
    End;
  If Pos('DelSafeDynPop_Float32', RefText) > 0 Then
    Begin
      Emit(

'function DelSafeDynPop_Float32(var A: TDelSafeDyn_Float32): Single; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'
      );
      HadPop := True;
    End;
  If Pos('DelSafeDynPop_Float64', RefText) > 0 Then
    Begin
      Emit(

'function DelSafeDynPop_Float64(var A: TDelSafeDyn_Float64): Double; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'
      );
      HadPop := True;
    End;
  If Pos('DelSafeDynPop_Bool', RefText) > 0 Then
    Begin
      Emit(

'function DelSafeDynPop_Bool(var A: TDelSafeDyn_Bool): Boolean; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'
      );
      HadPop := True;
    End;
  If Pos('DelSafeDynPop_Char', RefText) > 0 Then
    Begin
      Emit(

'function DelSafeDynPop_Char(var A: TDelSafeDyn_Char): Char; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'
      );
      HadPop := True;
    End;
  If Pos('DelSafeDynPop_String', RefText) > 0 Then
    Begin
      Emit(

'function DelSafeDynPop_String(var A: TDelSafeDyn_String): String; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;'
      );
      HadPop := True;
    End;
  If Pos('DelSafeDynPop_Pointer', RefText) > 0 Then
    Begin
      Emit(

'{$IFNDEF PAS2JS}function DelSafeDynPop_Pointer(var A: TDelSafeDyn_Pointer): Pointer; begin Result := A[High(A)]; SetLength(A, Length(A) - 1); end;{$ENDIF}'
      );
      HadPop := True;
    End;
  If HadPop Then Emit('');

  If Pos('DelSafeIfThen', RefText) > 0 Then
    Begin
      Emit('generic function DelSafeIfThen<T>(Cond: Boolean; const A, B: T): T;')
      ;
      Emit('begin');
      Emit('  if Cond then Result := A else Result := B;');
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeMin', RefText) > 0 Then
    Begin
      Emit('generic function DelSafeMin<T>(const A, B: T): T;');
      Emit('begin');
      Emit('  if A < B then Result := A else Result := B;');
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeMax', RefText) > 0 Then
    Begin
      Emit('generic function DelSafeMax<T>(const A, B: T): T;');
      Emit('begin');
      Emit('  if A > B then Result := A else Result := B;');
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeClamp', RefText) > 0 Then
    Begin
      Emit('generic function DelSafeClamp<T>(const V, Lo, Hi: T): T;');
      Emit('begin');
      Emit(

'  if V < Lo then Result := Lo else if V > Hi then Result := Hi else Result := V;'
      );
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeStrTrim', RefText) > 0 Then
    Begin
      Emit('function DelSafeStrTrim(const S: string): string;');
      Emit('begin');
      Emit('  Result := SysUtils.Trim(S);');
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeUpperCase', RefText) > 0 Then
    Begin
      Emit('function DelSafeUpperCase(const S: string): string;');
      Emit('begin');
      Emit('  Result := SysUtils.UpperCase(S);');
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeLowerCase', RefText) > 0 Then
    Begin
      Emit('function DelSafeLowerCase(const S: string): string;');
      Emit('begin');
      Emit('  Result := SysUtils.LowerCase(S);');
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeStartsWith', RefText) > 0 Then
    Begin
      Emit('function DelSafeStartsWith(const S, Prefix: string): Boolean;');
      Emit('begin');
      Emit(

'  Result := (Length(Prefix) <= Length(S)) and (Copy(S, 1, Length(Prefix)) = Prefix);'
      );
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeEndsWith', RefText) > 0 Then
    Begin
      Emit('function DelSafeEndsWith(const S, Suffix: string): Boolean;');
      Emit('begin');
      Emit(

'  Result := (Length(Suffix) <= Length(S)) and (Copy(S, Length(S) - Length(Suffix) + 1, Length(Suffix)) = Suffix);'
      );
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeStrContains', RefText) > 0 Then
    Begin
      Emit('function DelSafeStrContains(const S, Sub: string): Boolean;');
      Emit('begin');
      Emit('  if Sub = '''' then Exit(True);');
      Emit('  Result := Pos(Sub, S) > 0;');
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeIndexOf', RefText) > 0 Then
    Begin
      Emit('function DelSafeIndexOf(const S, Sub: string): Int32;');
      Emit('begin');
      Emit('  if Sub = '''' then Exit(0);');
      Emit('  Result := Int32(Pos(Sub, S)) - 1;');
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeStrReplace', RefText) > 0 Then
    Begin
      Emit('function DelSafeStrReplace(const S, OldStr, NewStr: string): string;'
      );
      Emit('begin');
      Emit('  if OldStr = '''' then Exit(S);');
      Emit(

        '  Result := SysUtils.StringReplace(S, OldStr, NewStr, [rfReplaceAll]);'
      );
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeStrSplit', RefText) > 0 Then
    Begin
      Emit('function DelSafeStrSplit(const S, Sep: string): TDelSafeDyn_String;');
      Emit('var I, StartPos, SepLen, P, CurLen: Integer;');
      Emit('begin');
      Emit('  SetLength(Result, 0);');
      Emit('  if Sep = '''' then');
      Emit('  begin');
      Emit('    SetLength(Result, Length(S));');
      Emit('    for I := 1 to Length(S) do Result[I - 1] := S[I];');
      Emit('    Exit;');
      Emit('  end;');
      Emit('  SepLen := Length(Sep);');
      Emit('  StartPos := 1;');
      Emit('  while True do');
      Emit('  begin');
      Emit('    P := Pos(Sep, Copy(S, StartPos, Length(S) - StartPos + 1));');
      Emit('    CurLen := Length(Result);');
      Emit('    SetLength(Result, CurLen + 1);');
      Emit('    if P = 0 then');
      Emit('    begin');
      Emit(

          '      Result[CurLen] := Copy(S, StartPos, Length(S) - StartPos + 1);'
      );
      Emit('      Break;');
      Emit('    end;');
      Emit('    Result[CurLen] := Copy(S, StartPos, P - 1);');
      Emit('    StartPos := StartPos + P - 1 + SepLen;');
      Emit('  end;');
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeStrJoin', RefText) > 0 Then
    Begin
      Emit(

'function DelSafeStrJoin(const Parts: TDelSafeDyn_String; const Sep: string): string;'
      );
      Emit('var I: Integer;');
      Emit('begin');
      Emit('  Result := '''';');
      Emit('  for I := 0 to High(Parts) do');
      Emit('  begin');
      Emit('    if I > 0 then Result := Result + Sep;');
      Emit('    Result := Result + Parts[I];');
      Emit('  end;');
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafePadLeft', RefText) > 0 Then
    Begin
      Emit(

'function DelSafePadLeft(const S: string; Width: Int32; const Pad: string): string;'
      );
      Emit('var P, Prefix: string; NeedLen: Integer;');
      Emit('begin');
      Emit('  if Length(S) >= Width then Exit(S);');
      Emit('  if Pad = '''' then P := '' '' else P := Pad;');
      Emit('  NeedLen := Width - Length(S);');
      Emit('  Prefix := '''';');
      Emit('  while Length(Prefix) < NeedLen do Prefix := Prefix + P;');
      Emit(

        '  if Length(Prefix) > NeedLen then Prefix := Copy(Prefix, 1, NeedLen);'
      );
      Emit('  Result := Prefix + S;');
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafePadRight', RefText) > 0 Then
    Begin
      Emit(

'function DelSafePadRight(const S: string; Width: Int32; const Pad: string): string;'
      );
      Emit('var P, Suffix: string; NeedLen: Integer;');
      Emit('begin');
      Emit('  if Length(S) >= Width then Exit(S);');
      Emit('  if Pad = '''' then P := '' '' else P := Pad;');
      Emit('  NeedLen := Width - Length(S);');
      Emit('  Suffix := '''';');
      Emit('  while Length(Suffix) < NeedLen do Suffix := Suffix + P;');
      Emit(

        '  if Length(Suffix) > NeedLen then Suffix := Copy(Suffix, 1, NeedLen);'
      );
      Emit('  Result := S + Suffix;');
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeRepeatStr', RefText) > 0 Then
    Begin
      Emit('function DelSafeRepeatStr(const S: string; Count: Int32): string;');
      Emit('var I: Integer;');
      Emit('begin');
      Emit('  Result := '''';');
      Emit('  if (Count <= 0) or (S = '''') then Exit;');
      Emit('  for I := 1 to Count do Result := Result + S;');
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeStrToFloat', RefText) > 0 Then
    Begin
      Emit('function DelSafeStrToFloat(const S: string): Double;');
      Emit('{$IFNDEF PAS2JS}');
      Emit('var FS: TFormatSettings;');
      Emit('begin');
      Emit('  FS := DefaultFormatSettings;');
      Emit('  FS.DecimalSeparator := ''.'';');
      Emit('  Result := SysUtils.StrToFloatDef(SysUtils.Trim(S), 0.0, FS);');
      Emit('end;');
      Emit('{$ELSE}');
      Emit('begin');
      Emit('  Result := SysUtils.StrToFloatDef(SysUtils.Trim(S), 0.0);');
      Emit('end;');
      Emit('{$ENDIF}');
      Emit('');
    End;

  If Pos('DelSafeTryStrToInt', RefText) > 0 Then
    Begin
      Emit('function DelSafeTryStrToInt(const S: string): TDelSafeOption;');
      Emit('var V: LongInt; T: string;');
      Emit('begin');
      Emit('  T := SysUtils.Trim(S);');
      Emit(

'  if (T <> '''') and SysUtils.TryStrToInt(T, V) then Result := DelSafeSome(Double(V))'
      );
      Emit('  else Result := DelSafeNone();');
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeTryStrToFloat', RefText) > 0 Then
    Begin
      Emit('function DelSafeTryStrToFloat(const S: string): TDelSafeOption;');
      Emit('{$IFNDEF PAS2JS}');
      Emit('var V: Double; T: string; FS: TFormatSettings;');
      Emit('begin');
      Emit('  T := SysUtils.Trim(S);');
      Emit('  FS := DefaultFormatSettings;');
      Emit('  FS.DecimalSeparator := ''.'';');
      Emit(

'  if (T <> '''') and SysUtils.TryStrToFloat(T, V, FS) then Result := DelSafeSome(V)'
      );
      Emit('  else Result := DelSafeNone();');
      Emit('end;');
      Emit('{$ELSE}');
      Emit('var V: Double; T: string;');
      Emit('begin');
      Emit('  T := SysUtils.Trim(S);');
      Emit(

'  if (T <> '''') and SysUtils.TryStrToFloat(T, V) then Result := DelSafeSome(V)'
      );
      Emit('  else Result := DelSafeNone();');
      Emit('end;');
      Emit('{$ENDIF}');
      Emit('');
    End;

  If Pos('DelSafeRound', RefText) > 0 Then
    Begin
      Emit('function DelSafeRound(V: Double): Double;');
      Emit('begin');
      Emit(

      '  if V >= 0.0 then Result := Int(V + 0.5) else Result := -Int(-V + 0.5);'
      );
      Emit('end;');
      Emit('');
    End;

  If (Pos('DelSafeRandomInt', RefText) > 0) Or (Pos('DelSafeRandomFloat', RefText)
     > 0) Then
    Begin
      Emit('var GDelSafeRandSeeded: Boolean = False;');
      Emit('');
    End;

  If Pos('DelSafeRandomInt', RefText) > 0 Then
    Begin
      Emit('function DelSafeRandomInt(MinV, MaxV: Int32): Int32;');
      Emit('{$IFNDEF PAS2JS}');
      Emit('var Lo, Hi: Int32; Span: Int64;');
      Emit('begin');
      Emit(

'  if not GDelSafeRandSeeded then begin System.Randomize; GDelSafeRandSeeded := True; end;'
      );
      Emit(

'  if MinV <= MaxV then begin Lo := MinV; Hi := MaxV; end else begin Lo := MaxV; Hi := MinV; end;'
      );
      Emit('  if Lo = Hi then Exit(Lo);');
      Emit('  Span := Int64(Hi) - Int64(Lo) + 1;');
      Emit('  Result := Lo + Int32(System.Random(Span));');
      Emit('end;');
      Emit('{$ELSE}');
      Emit('var Lo, Hi: Int32;');
      Emit('begin');
      Emit(

'  if MinV <= MaxV then begin Lo := MinV; Hi := MaxV; end else begin Lo := MaxV; Hi := MinV; end;'
      );
      Emit('  if Lo = Hi then Exit(Lo);');
      Emit('  Result := Lo + Trunc(Random * (Hi - Lo + 1));');
      Emit('end;');
      Emit('{$ENDIF}');
      Emit('');
    End;

  If Pos('DelSafeRandomFloat', RefText) > 0 Then
    Begin
      Emit('function DelSafeRandomFloat(): Double;');
      Emit('{$IFNDEF PAS2JS}');
      Emit('begin');
      Emit(

'  if not GDelSafeRandSeeded then begin System.Randomize; GDelSafeRandSeeded := True; end;'
      );
      Emit('  Result := System.Random;');
      Emit('end;');
      Emit('{$ELSE}');
      Emit('begin');
      Emit('  Result := Random;');
      Emit('end;');
      Emit('{$ENDIF}');
      Emit('');
    End;

  If Pos('DelSafeReadLn', RefText) > 0 Then
    Begin
      Emit('function DelSafeReadLn(): string;');
      Emit('begin');
      Emit(

        '  {$IFNDEF PAS2JS}System.ReadLn(Result);{$ELSE}Result := '''';{$ENDIF}'
      );
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeGetEnv', RefText) > 0 Then
    Begin
      Emit('{$IFNDEF PAS2JS}{$IFNDEF WINDOWS}');
      Emit('function delsafe_c_getenv(name: PAnsiChar): PAnsiChar; cdecl; external ''c'' name ''getenv'';');
      Emit('{$ENDIF}{$ENDIF}');
      Emit('function DelSafeGetEnv(const AName: string): string;');
      Emit('{$IFNDEF PAS2JS}{$IFNDEF WINDOWS}');
      Emit('var P: PAnsiChar;');
      Emit('{$ENDIF}{$ENDIF}');
      Emit('begin');
      Emit('  {$IFDEF PAS2JS}Result := '''';');
      Emit('  {$ELSE}{$IFDEF WINDOWS}Result := SysUtils.GetEnvironmentVariable(AName);');
      Emit('  {$ELSE}');
      Emit('  P := delsafe_c_getenv(PAnsiChar(AnsiString(AName)));');
      Emit('  if P <> nil then Result := string(P) else Result := SysUtils.GetEnvironmentVariable(AName);');
      Emit('  {$ENDIF}{$ENDIF}');
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeSetEnv', RefText) > 0 Then
    Begin
      Emit('{$IFNDEF PAS2JS}{$IFNDEF WINDOWS}');
      Emit(

'function delsafe_c_setenv(name, val: PAnsiChar; overwrite: LongInt): LongInt; cdecl; external ''c'' name ''setenv'';'
      );
      Emit('{$ENDIF}{$ENDIF}');
      Emit('function DelSafeSetEnv(const AName, AVal: string): Boolean;');
      Emit('begin');
      Emit('  {$IFDEF PAS2JS}Result := False;');
      Emit('  {$ELSE}{$IFDEF WINDOWS}');
      Emit(

'  Result := Windows.SetEnvironmentVariableA(PAnsiChar(AnsiString(AName)), PAnsiChar(AnsiString(AVal)));'
      );
      Emit('  {$ELSE}');
      Emit(

'  Result := delsafe_c_setenv(PAnsiChar(AnsiString(AName)), PAnsiChar(AnsiString(AVal)), 1) = 0;'
      );
      Emit('  {$ENDIF}{$ENDIF}');
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeCharAt', RefText) > 0 Then
    Begin
      Emit('function DelSafeCharAt(const S: string; Index: Cardinal): string;');
      Emit('begin');
      Emit(

'  if (Index + 1 <= Cardinal(Length(S))) then Result := S[Index + 1] else Result := '''';'
      );
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeByteAt', RefText) > 0 Then
    Begin
      Emit('function DelSafeByteAt(const S: string; Index: LongInt): LongInt;');
      Emit('begin');
      Emit(

'  if (Index >= 0) and (Index < Length(S)) then Result := Ord(S[Index + 1]) and $FF else Result := 0;'
      );
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeCharFromByte', RefText) > 0 Then
    Begin
      Emit('function DelSafeCharFromByte(B: LongInt): string;');
      Emit('begin');
      Emit(

  '  if (B > 0) and (B <= 255) then Result := Chr(Byte(B)) else Result := '''';'
      );
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeSubstring', RefText) > 0 Then
    Begin
      Emit(

      'function DelSafeSubstring(const S: string; Start, Len: Cardinal): string;'
      );
      Emit('begin');
      Emit('  Result := Copy(S, Start + 1, Len);');
      Emit('end;');
      Emit('');
    End;

  If NeedFileIO Then
    Begin
      Emit('{$IFNDEF PAS2JS}');
      Emit('function DelSafeFileExists(const APath: string): Boolean;');
      Emit('begin');
      Emit('  Result := SysUtils.FileExists(APath);');
      Emit('end;');
      Emit('');
      Emit('function DelSafeReadFile(const APath: string): string;');
      Emit('var');
      Emit('  F: TextFile;');
      Emit('  Line, Content: string;');
      Emit('begin');
      Emit('  Content := '''';');
      Emit('  if not SysUtils.FileExists(APath) then Exit('''');');
      Emit('  AssignFile(F, APath);');
      Emit('  {$I-} Reset(F); {$I+}');
      Emit('  if IOResult <> 0 then Exit('''');');
      Emit(

'  while not Eof(F) do begin ReadLn(F, Line); Content := Content + Line + LineEnding; end;'
      );
      Emit('  CloseFile(F);');
      Emit('  Result := Content;');
      Emit('end;');
      Emit('');
      Emit(

'function DelSafeWriteFile(const APath: string; const AContent: string): Boolean;'
      );
      Emit('var');
      Emit('  F: TextFile;');
      Emit('begin');
      Emit('  AssignFile(F, APath);');
      Emit('  {$I-} Rewrite(F); {$I+}');
      Emit('  if IOResult <> 0 then Exit(False);');
      Emit('  Write(F, AContent);');
      Emit('  CloseFile(F);');
      Emit('  Result := True;');
      Emit('end;');
      Emit('');
      Emit('function DelSafeCreateDir(const APath: string): Boolean;');
      Emit('begin Result := SysUtils.CreateDir(APath); end;');
      Emit('');
      Emit('function DelSafeRemoveDir(const APath: string): Boolean;');
      Emit('begin Result := SysUtils.RemoveDir(APath); end;');
      Emit('');
      Emit('function DelSafeDeleteFile(const APath: string): Boolean;');
      Emit('begin Result := SysUtils.DeleteFile(APath); end;');
      Emit('');
      Emit('function DelSafeDirExists(const APath: string): Boolean;');
      Emit('begin Result := SysUtils.DirectoryExists(APath); end;');
      Emit('');
      Emit('function DelSafeFileSize(const APath: string): Int64;');
      Emit('var H: THandle;');
      Emit('begin');
      Emit('  Result := -1;');
      Emit('  H := FileOpen(APath, fmOpenRead or fmShareDenyNone);');
      Emit(

'  if H <> feInvalidHandle then begin Result := FileSeek(H, Int64(0), 2); FileClose(H); end;'
      );
      Emit('end;');
      If Pos('DelSafeListDir', RefText) > 0 Then
        Begin
          Emit('');
          Emit('function DelSafeListDir(const APath: string): TDelSafeDyn_String;'
          );
          Emit('var SR: TSearchRec; Pattern: string; N: Integer;');
          Emit('begin');
          Emit('  SetLength(Result, 0);');
          Emit(

'  if APath = '''' then Pattern := ''*'' else Pattern := SysUtils.IncludeTrailingPathDelimiter(APath) + ''*'';'
          );
          Emit('  if SysUtils.FindFirst(Pattern, faAnyFile, SR) = 0 then');
          Emit('  begin');
          Emit('    repeat');
          Emit('      if (SR.Name <> ''.'') and (SR.Name <> ''..'') then');
          Emit('      begin');
          Emit('        N := Length(Result);');
          Emit('        SetLength(Result, N + 1);');
          Emit('        Result[N] := SR.Name;');
          Emit('      end;');
          Emit('    until SysUtils.FindNext(SR) <> 0;');
          Emit('    SysUtils.FindClose(SR);');
          Emit('  end;');
          Emit('end;');
        End;
      If Pos('DelSafeCopyFile', RefText) > 0 Then
        Begin
          Emit('');
          Emit('function DelSafeCopyFile(const ASrc, ADst: string): Boolean;');
          Emit(

              'var HS, HD: THandle; Buf: array[0..4095] of Byte; R, W: LongInt;'
          );
          Emit('begin');
          Emit('  Result := False;');
          Emit('  HS := FileOpen(ASrc, fmOpenRead or fmShareDenyNone);');
          Emit('  if HS = feInvalidHandle then Exit;');
          Emit('  HD := FileCreate(ADst);');
          Emit('  if HD = feInvalidHandle then begin FileClose(HS); Exit; end;')
          ;
          Emit('  Result := True;');
          Emit('  repeat');
          Emit('    R := FileRead(HS, Buf[0], SizeOf(Buf));');
          Emit('    if R > 0 then');
          Emit('    begin');
          Emit('      W := FileWrite(HD, Buf[0], R);');
          Emit('      if W <> R then begin Result := False; Break; end;');
          Emit('    end;');
          Emit('  until R <= 0;');
          Emit('  FileClose(HD);');
          Emit('  FileClose(HS);');
          Emit('end;');
        End;
      If Pos('DelSafeRenameFile', RefText) > 0 Then
        Begin
          Emit('');
          Emit('function DelSafeRenameFile(const AOld, ANew: string): Boolean;');
          Emit('begin Result := SysUtils.RenameFile(AOld, ANew); end;');
        End;
      Emit('{$ELSE}');
      Emit(

'function DelSafeFileExists(const APath: string): Boolean; begin Result := False; end;'
      );
      Emit(

'function DelSafeReadFile(const APath: string): string; begin Result := ''''; end;'
      );
      Emit(

'function DelSafeWriteFile(const APath: string; const AContent: string): Boolean; begin Result := False; end;'
      );
      Emit(

'function DelSafeCreateDir(const APath: string): Boolean; begin Result := False; end;'
      );
      Emit(

'function DelSafeRemoveDir(const APath: string): Boolean; begin Result := False; end;'
      );
      Emit(

'function DelSafeDeleteFile(const APath: string): Boolean; begin Result := False; end;'
      );
      Emit(

'function DelSafeDirExists(const APath: string): Boolean; begin Result := False; end;'
      );
      Emit(

'function DelSafeFileSize(const APath: string): {$IFDEF PAS2JS}NativeInt{$ELSE}Int64{$ENDIF}; begin Result := -1; end;'
      );
      If Pos('DelSafeListDir', RefText) > 0 Then Emit(

'function DelSafeListDir(const APath: string): TDelSafeDyn_String; begin SetLength(Result, 0); end;'
        );
      If Pos('DelSafeCopyFile', RefText) > 0 Then Emit(

'function DelSafeCopyFile(const ASrc, ADst: string): Boolean; begin Result := False; end;'
        );
      If Pos('DelSafeRenameFile', RefText) > 0 Then Emit(

'function DelSafeRenameFile(const AOld, ANew: string): Boolean; begin Result := False; end;'
        );
      Emit('{$ENDIF}');
      Emit('');
    End;

  If Pos('DelSafeBoolToStr', RefText) > 0 Then
    Begin
      Emit('function DelSafeBoolToStr(B: Boolean): string;');
      Emit('begin if B then Result := ''true'' else Result := ''false''; end;');
      Emit('');
    End;

  If Pos('DelSafeFloatToStr', RefText) > 0 Then
    Begin
      Emit('function DelSafeFloatToStr(AVal: Double): string;');
      Emit('{$IFNDEF PAS2JS}');
      Emit('var FS: TFormatSettings;');
      Emit('begin');
      Emit('  FS := DefaultFormatSettings;');
      Emit('  FS.DecimalSeparator := ''.'';');
      Emit('  Result := FloatToStr(AVal, FS);');
      Emit('end;');
      Emit('{$ELSE}');
      Emit('begin');
      Emit('  Result := FloatToStr(AVal);');
      Emit('end;');
      Emit('{$ENDIF}');
      Emit('');
    End;

  If NeedJson Then
    Begin
      Emit('function DelSafeJsonExtractRaw(const Json, Key: string): string;');
      Emit('var');
      Emit('  Pattern: string;');
      Emit('  P, SearchPos, JLen, Depth, StartPos: Integer;');
      Emit('  InStr: Boolean;');
      Emit('begin');
      Emit('  Pattern := ''"'' + Key + ''"'';');
      Emit('  SearchPos := 1;');
      Emit('  JLen := Length(Json);');
      Emit('  while SearchPos <= JLen do');
      Emit('  begin');
      Emit('    P := Pos(Pattern, Copy(Json, SearchPos, JLen - SearchPos + 1));'
      );
      Emit('    if P = 0 then Exit('''');');
      Emit('    P := SearchPos + P - 1 + Length(Pattern);');
      Emit(

       '    while (P <= JLen) and (Json[P] in ['' '', #9, #10, #13]) do Inc(P);'
      );
      Emit('    if (P <= JLen) and (Json[P] = '':'') then');
      Emit('    begin');
      Emit('      Inc(P);');
      Emit(

     '      while (P <= JLen) and (Json[P] in ['' '', #9, #10, #13]) do Inc(P);'
      );
      Emit('      if P > JLen then Exit('''');');
      Emit('      if Json[P] = ''"'' then');
      Emit('      begin');
      Emit('        StartPos := P; Inc(P);');
      Emit('        while P <= JLen do');
      Emit('        begin');
      Emit(

'          if (Json[P] = ''"'') and ((P = StartPos + 1) or (Json[P - 1] <> ''\'')) then'
      );
      Emit('            Exit(Copy(Json, StartPos, P - StartPos + 1));');
      Emit('          Inc(P);');
      Emit('        end;');
      Emit('        Exit(Copy(Json, StartPos, JLen - StartPos + 1));');
      Emit('      end');
      Emit('      else if Json[P] = ''{'' then');
      Emit('      begin');
      Emit('        StartPos := P; Depth := 0; InStr := False;');
      Emit('        while P <= JLen do');
      Emit('        begin');
      Emit(

'          if (Json[P] = ''"'') and ((P = 1) or (Json[P - 1] <> ''\'')) then InStr := not InStr'
      );
      Emit('          else if not InStr then');
      Emit('          begin');
      Emit('            if Json[P] = ''{'' then Inc(Depth)');
      Emit(

'            else if Json[P] = ''}'' then begin Dec(Depth); if Depth = 0 then Exit(Copy(Json, StartPos, P - StartPos + 1)); end;'
      );
      Emit('          end;');
      Emit('          Inc(P);');
      Emit('        end;');
      Emit('        Exit(Copy(Json, StartPos, JLen - StartPos + 1));');
      Emit('      end');
      Emit('      else');
      Emit('      begin');
      Emit('        StartPos := P;');
      Emit(

'        while (P <= JLen) and not (Json[P] in ['','', ''}'', '']'', '' '', #9, #10, #13]) do Inc(P);'
      );
      Emit('        Exit(Copy(Json, StartPos, P - StartPos));');
      Emit('      end;');
      Emit('    end;');
      Emit('    SearchPos := P;');
      Emit('  end;');
      Emit('  Result := '''';');
      Emit('end;');
      Emit('');
      Emit('function DelSafeJsonGetStr(const Json, Key: string): string;');
      Emit('begin');
      Emit('  Result := DelSafeJsonExtractRaw(Json, Key);');
      Emit(

'  if (Length(Result) >= 2) and (Result[1] = ''"'') and (Result[Length(Result)] = ''"'') then'
      );
      Emit('    Result := Copy(Result, 2, Length(Result) - 2);');
      Emit('end;');
      Emit('');
      Emit('function DelSafeJsonGetInt(const Json, Key: string): Int32;');
      Emit('begin');
      Emit('  Result := StrToIntDef(DelSafeJsonExtractRaw(Json, Key), 0);');
      Emit('end;');
      Emit('');
      Emit('function DelSafeJsonGetFloat(const Json, Key: string): Double;');
      Emit('{$IFNDEF PAS2JS}');
      Emit('var FS: TFormatSettings;');
      Emit('begin');
      Emit('  FS := DefaultFormatSettings;');
      Emit('  FS.DecimalSeparator := ''.'';');
      Emit(

          '  Result := StrToFloatDef(DelSafeJsonExtractRaw(Json, Key), 0.0, FS);'
      );
      Emit('end;');
      Emit('{$ELSE}');
      Emit('begin');
      Emit('  Result := StrToFloatDef(DelSafeJsonExtractRaw(Json, Key), 0.0);');
      Emit('end;');
      Emit('{$ENDIF}');
      Emit('');
      Emit('function DelSafeJsonGetBool(const Json, Key: string): Boolean;');
      Emit('begin');
      Emit('  Result := SameText(DelSafeJsonExtractRaw(Json, Key), ''true'');');
      Emit('end;');
      Emit('');
      Emit('function DelSafeJsonGetChar(const Json, Key: string): Char;');
      Emit('var S: string;');
      Emit('begin');
      Emit('  S := DelSafeJsonGetStr(Json, Key);');
      Emit('  if Length(S) > 0 then Result := S[1] else Result := #0;');
      Emit('end;');
      Emit('');
      Emit('function DelSafeJsonHasValue(const Json, Key: string): Boolean;');
      Emit('var Raw: string;');
      Emit('begin');
      Emit('  Raw := DelSafeJsonExtractRaw(Json, Key);');
      Emit('  Result := (Raw <> '''') and (not SameText(Raw, ''null''));');
      Emit('end;');
      Emit('');
      Emit('function DelSafeJsonGetObj(const Json, Key: string): string;');
      Emit('begin');
      Emit('  Result := DelSafeJsonExtractRaw(Json, Key);');
      Emit('end;');
      Emit('');
    End;

  If Pos('DelSafeGetNanoseconds', RefText) > 0 Then
    Begin
      Emit(

     'function DelSafeGetNanoseconds: {$IFDEF PAS2JS}Double{$ELSE}QWord{$ENDIF};'
      );
      Emit('{$IFDEF PAS2JS}');
      Emit('begin Result := 0; end;');
      Emit('{$ELSE}');
      Emit('{$IFDEF WINDOWS}');
      Emit('var Freq, Count: Int64;');
      Emit('begin');
      Emit('  Freq := 0; Count := 0;');
      Emit('  Windows.QueryPerformanceFrequency(Freq);');
      Emit('  Windows.QueryPerformanceCounter(Count);');
      Emit('  if Freq > 0 then Result := QWord((Count * 1000000000) div Freq)');
      Emit('  else Result := QWord(GetTickCount64 * 1000000);');
      Emit('end;');
      Emit('{$ELSE}');
      Emit('begin Result := QWord(GetTickCount64 * 1000000); end;');
      Emit('{$ENDIF}');
      Emit('{$ENDIF}');
      Emit('');
    End;

  If Pos('DelSafeSleepMs', RefText) > 0 Then
    Begin
      Emit('procedure DelSafeSleepMs(AMs: Cardinal);');
      Emit('{$IFDEF PAS2JS}');
      Emit('begin end;');
      Emit('{$ELSE}');
      Emit('begin SysUtils.Sleep(AMs); end;');
      Emit('{$ENDIF}');
      Emit('');
    End;

  If NeedSockets Then
    Begin
      Emit('{$IFNDEF PAS2JS}');
      Emit('// Native Sockets via FPC Sockets');
      Emit('function DelSafeSocketCreate(): LongInt;');
      Emit('begin');
      Emit('  Result := Sockets.fpsocket(AF_INET, SOCK_STREAM, 0);');
      Emit('end;');
      Emit('');
      Emit('function DelSafeSocketListen(Port: Word; Backlog: LongInt): LongInt;'
      );
      Emit('var');
      Emit('  Addr: TInetSockAddr;');
      Emit('  Opt: LongInt;');
      Emit('begin');
      Emit('  Result := Sockets.fpsocket(AF_INET, SOCK_STREAM, 0);');
      Emit('  if Result < 0 then Exit(-1);');
      Emit('  Opt := 1;');
      Emit(

  '  Sockets.fpsetsockopt(Result, SOL_SOCKET, SO_REUSEADDR, @Opt, SizeOf(Opt));'
      );
      Emit('  FillChar(Addr, SizeOf(Addr), 0);');
      Emit('  Addr.sin_family := AF_INET;');
      Emit('  Addr.sin_port := Sockets.htons(Port);');
      Emit('  Addr.sin_addr.s_addr := 0; // INADDR_ANY');
      Emit('  if Sockets.fpbind(Result, @Addr, SizeOf(Addr)) <> 0 then');
      Emit('  begin');
      Emit('    Sockets.CloseSocket(Result);');
      Emit('    Exit(-1);');
      Emit('  end;');
      Emit('  if Sockets.fplisten(Result, Backlog) <> 0 then');
      Emit('  begin');
      Emit('    Sockets.CloseSocket(Result);');
      Emit('    Exit(-1);');
      Emit('  end;');
      Emit('end;');
      Emit('');
      Emit('function DelSafeSocketAccept(ListenFd: LongInt): LongInt;');
      Emit('var');
      Emit('  Addr: TInetSockAddr;');
      Emit('  AddrLen: LongInt;');
      Emit('begin');
      Emit('  AddrLen := SizeOf(Addr);');
      Emit('  Result := Sockets.fpaccept(ListenFd, @Addr, @AddrLen);');
      Emit('end;');
      Emit('');
      Emit(

        'function DelSafeSocketConnect(const Host: String; Port: Word): LongInt;'
      );
      Emit('var');
      Emit('  Addr: TInetSockAddr;');
      Emit('begin');
      Emit('  Result := Sockets.fpsocket(AF_INET, SOCK_STREAM, 0);');
      Emit('  if Result < 0 then Exit(-1);');
      Emit('  FillChar(Addr, SizeOf(Addr), 0);');
      Emit('  Addr.sin_family := AF_INET;');
      Emit('  Addr.sin_port := Sockets.htons(Port);');
      Emit('  Addr.sin_addr := Sockets.StrToNetAddr(Host);');
      Emit('  if Sockets.fpconnect(Result, @Addr, SizeOf(Addr)) <> 0 then');
      Emit('  begin');
      Emit('    Sockets.CloseSocket(Result);');
      Emit('    Exit(-1);');
      Emit('  end;');
      Emit('end;');
      Emit('');
      Emit(

          'function DelSafeSocketSend(Fd: LongInt; const Data: String): LongInt;'
      );
      Emit('var Off, Sent, Len: LongInt;');
      Emit('begin');
      Emit('  Len := Length(Data);');
      Emit('  if Len = 0 then Exit(0);');
      Emit('  Off := 0;');
      Emit('  while Off < Len do');
      Emit('  begin');
      Emit('    Sent := Sockets.fpsend(Fd, @Data[Off + 1], Len - Off, 0);');
      Emit('    if Sent <= 0 then begin if Off > 0 then Exit(Off) else Exit(-1); end;');
      Emit('    Off := Off + Sent;');
      Emit('  end;');
      Emit('  Result := Off;');
      Emit('end;');
      Emit('');
      Emit('function DelSafeSocketRecv(Fd: LongInt; MaxLen: LongInt): String;');
      Emit('var');
      Emit('  Buf: array of Char;');
      Emit('  Bytes: LongInt;');
      Emit('begin');
      Emit('  SetLength(Buf, MaxLen);');
      Emit('  Bytes := Sockets.fprecv(Fd, @Buf[0], MaxLen, 0);');
      Emit('  if Bytes > 0 then');
      Emit('    SetString(Result, PChar(@Buf[0]), Bytes)');
      Emit('  else');
      Emit('    Result := '''';');
      Emit('end;');
      Emit('');
      Emit('procedure DelSafeSocketClose(Fd: LongInt);');
      Emit('begin');
      Emit('  if Fd >= 0 then Sockets.CloseSocket(Fd);');
      Emit('end;');
      Emit('');
      Emit(

       'function DelSafeSocketSetTimeout(Fd, ReadMs, WriteMs: LongInt): Boolean;'
      );
      Emit('{$IFDEF WINDOWS}');
      Emit('var MsVal: LongWord;');
      Emit('begin');
      Emit('  Result := True;');
      Emit('  if Fd < 0 then Exit(False);');
      Emit(

'  if ReadMs > 0 then begin MsVal := LongWord(ReadMs); if Sockets.fpsetsockopt(Fd, SOL_SOCKET, $1006, @MsVal, SizeOf(MsVal)) <> 0 then Result := False; end;'
      );
      Emit(

'  if WriteMs > 0 then begin MsVal := LongWord(WriteMs); if Sockets.fpsetsockopt(Fd, SOL_SOCKET, $1005, @MsVal, SizeOf(MsVal)) <> 0 then Result := False; end;'
      );
      Emit('end;');
      Emit('{$ELSE}');
      Emit('type TDelSafeTimeVal = record tv_sec, tv_usec: PtrInt; end;');
      Emit('var TV: TDelSafeTimeVal;');
      Emit('begin');
      Emit('  Result := True;');
      Emit('  if Fd < 0 then Exit(False);');
      Emit(

'  if ReadMs > 0 then begin TV.tv_sec := ReadMs div 1000; TV.tv_usec := (ReadMs mod 1000) * 1000; if Sockets.fpsetsockopt(Fd, SOL_SOCKET, SO_RCVTIMEO, @TV, SizeOf(TV)) <> 0 then Result := False; end;'
      );
      Emit(

'  if WriteMs > 0 then begin TV.tv_sec := WriteMs div 1000; TV.tv_usec := (WriteMs mod 1000) * 1000; if Sockets.fpsetsockopt(Fd, SOL_SOCKET, SO_SNDTIMEO, @TV, SizeOf(TV)) <> 0 then Result := False; end;'
      );
      Emit('end;');
      Emit('{$ENDIF}');
      Emit('');
      Emit('function DelSafeSocketPeerIP(Fd: LongInt): String;');
      Emit('var');
      Emit('  Addr: TInetSockAddr;');
      Emit('  AddrLen: TSockLen;');
      Emit('begin');
      Emit('  AddrLen := SizeOf(Addr);');
      Emit('  FillChar(Addr, SizeOf(Addr), 0);');
      Emit('  if Sockets.fpgetpeername(Fd, @Addr, @AddrLen) = 0 then');
      Emit('  begin');
      Emit('    Result := Sockets.NetAddrToStr(Addr.sin_addr);');
      Emit('    if Result = '''' then Result := ''127.0.0.1'';');
      Emit('  end');
      Emit('  else');
      Emit('    Result := ''127.0.0.1'';');
      Emit('end;');
      Emit('');
      Emit(

    'function DelSafeSocketSendHex(Fd: LongInt; const HexData: String): LongInt;'
      );
      Emit('var');
      Emit('  Buf: array of Byte;');
      Emit('  N, I, Off, Sent: LongInt;');
      Emit('begin');
      Emit('  N := Length(HexData) div 2;');
      Emit('  if N <= 0 then Exit(0);');
      Emit('  SetLength(Buf, N);');
      Emit('  for I := 0 to N - 1 do');
      Emit(

      '    Buf[I] := Byte(StrToIntDef(''$'' + Copy(HexData, I * 2 + 1, 2), 0));'
      );
      Emit('  Off := 0;');
      Emit('  while Off < N do');
      Emit('  begin');
      Emit('    Sent := Sockets.fpsend(Fd, @Buf[Off], N - Off, 0);');
      Emit('    if Sent <= 0 then begin if Off > 0 then Exit(Off) else Exit(-1); end;');
      Emit('    Off := Off + Sent;');
      Emit('  end;');
      Emit('  Result := Off;');
      Emit('end;');
      Emit('');
      Emit('function DelSafeSocketRecvHex(Fd, MaxLen: LongInt): String;');
      Emit('var');
      Emit('  Buf: array of Byte;');
      Emit('  Bytes, I: LongInt;');
      Emit('begin');
      Emit('  Result := '''';');
      Emit('  if MaxLen <= 0 then MaxLen := 4096;');
      Emit('  SetLength(Buf, MaxLen);');
      Emit('  Bytes := Sockets.fprecv(Fd, @Buf[0], MaxLen, 0);');
      Emit('  if Bytes > 0 then');
      Emit('    for I := 0 to Bytes - 1 do');
      Emit('      Result := Result + LowerCase(IntToHex(Buf[I], 2));');
      Emit('end;');
      Emit('');
      Emit('function DelSafeSocketSendFile(Fd: LongInt; const Path: String): Int64;');
      Emit('var');
      Emit('  FH: THandle;');
      Emit('  Buf: array[0..65535] of Byte;');
      Emit('  Rd, Off, Sent: LongInt;');
      Emit('begin');
      Emit('  if (Fd < 0) or (Path = '''') then Exit(-1);');
      Emit('  FH := FileOpen(Path, fmOpenRead or fmShareDenyNone);');
      Emit('  if FH = THandle(-1) then Exit(-1);');
      Emit('  Result := 0;');
      Emit('  try');
      Emit('    Rd := FileRead(FH, Buf[0], SizeOf(Buf));');
      Emit('    while Rd > 0 do');
      Emit('    begin');
      Emit('      Off := 0;');
      Emit('      while Off < Rd do');
      Emit('      begin');
      Emit('        Sent := Sockets.fpsend(Fd, @Buf[Off], Rd - Off, 0);');
      Emit('        if Sent <= 0 then Exit(-1);');
      Emit('        Off := Off + Sent;');
      Emit('        Result := Result + Sent;');
      Emit('      end;');
      Emit('      Rd := FileRead(FH, Buf[0], SizeOf(Buf));');
      Emit('    end;');
      Emit('  finally');
      Emit('    FileClose(FH);');
      Emit('  end;');
      Emit('end;');
      Emit('{$ELSE}');
      Emit('function DelSafeSocketCreate(): LongInt; begin Result := -1; end;');
      Emit(

'function DelSafeSocketListen(Port: Word; Backlog: LongInt): LongInt; begin Result := -1; end;'
      );
      Emit(

'function DelSafeSocketAccept(ListenFd: LongInt): LongInt; begin Result := -1; end;'
      );
      Emit(

'function DelSafeSocketConnect(const Host: String; Port: Word): LongInt; begin Result := -1; end;'
      );
      Emit(

'function DelSafeSocketSend(Fd: LongInt; const Data: String): LongInt; begin Result := 0; end;'
      );
      Emit(

'function DelSafeSocketRecv(Fd: LongInt; MaxLen: LongInt): String; begin Result := ''''; end;'
      );
      Emit('procedure DelSafeSocketClose(Fd: LongInt); begin end;');
      Emit(

'function DelSafeSocketSetTimeout(Fd, ReadMs, WriteMs: LongInt): Boolean; begin Result := False; end;'
      );
      Emit(

'function DelSafeSocketPeerIP(Fd: LongInt): String; begin Result := ''127.0.0.1''; end;'
      );
      Emit(

'function DelSafeSocketSendHex(Fd: LongInt; const HexData: String): LongInt; begin Result := 0; end;'
      );
      Emit(

'function DelSafeSocketRecvHex(Fd, MaxLen: LongInt): String; begin Result := ''''; end;'
      );
      Emit(

'function DelSafeSocketSendFile(Fd: LongInt; const Path: String): Int64; begin Result := -1; end;'
      );
      Emit('{$ENDIF}');
      Emit('');
    End;

  If Pos('DelSafeSync', RefText) > 0 Then
    Begin
      Emit('{$IFNDEF PAS2JS}');
      Emit('function DelSafeSyncAtomicNew(AInit: Int32): Pointer;');
      Emit('var P: PLongInt;');
      Emit('begin');
      Emit('  New(P);');
      Emit('  P^ := AInit;');
      Emit('  Result := P;');
      Emit('end;');
      Emit('');
      Emit('function DelSafeSyncAtomicLoad(P: Pointer): Int32;');
      Emit('begin');
      Emit('  if P = nil then Exit(0);');
      Emit('  Result := InterlockedExchangeAdd(PLongInt(P)^, 0);');
      Emit('end;');
      Emit('');
      Emit('procedure DelSafeSyncAtomicStore(P: Pointer; V: Int32);');
      Emit('begin');
      Emit('  if P <> nil then InterlockedExchange(PLongInt(P)^, V);');
      Emit('end;');
      Emit('');
      Emit('function DelSafeSyncAtomicAdd(P: Pointer; Delta: Int32): Int32;');
      Emit('begin');
      Emit('  if P = nil then Exit(0);');
      Emit('  Result := InterlockedExchangeAdd(PLongInt(P)^, Delta) + Delta;');
      Emit('end;');
      Emit('');
      Emit(

  'function DelSafeSyncAtomicCas(P: Pointer; Expected, Desired: Int32): Boolean;'
      );
      Emit('begin');
      Emit('  if P = nil then Exit(False);');
      Emit(

'  Result := InterlockedCompareExchange(PLongInt(P)^, Desired, Expected) = Expected;'
      );
      Emit('end;');
      Emit('');
      Emit('procedure DelSafeSyncAtomicFree(P: Pointer);');
      Emit('begin');
      Emit('  if P <> nil then Dispose(PLongInt(P));');
      Emit('end;');
      Emit('');
      Emit('function DelSafeSyncMutexNew(): Pointer;');
      Emit('var M: PRTLCriticalSection;');
      Emit('begin');
      Emit('  New(M);');
      Emit('  System.InitCriticalSection(M^);');
      Emit('  Result := M;');
      Emit('end;');
      Emit('');
      Emit('procedure DelSafeSyncMutexLock(P: Pointer);');
      Emit('begin');
      Emit(

      '  if P <> nil then System.EnterCriticalSection(PRTLCriticalSection(P)^);'
      );
      Emit('end;');
      Emit('');
      Emit('function DelSafeSyncMutexTryLock(P: Pointer): Boolean;');
      Emit('begin');
      Emit('  if P = nil then Exit(False);');
      Emit(

     '  Result := System.TryEnterCriticalSection(PRTLCriticalSection(P)^) <> 0;'
      );
      Emit('end;');
      Emit('');
      Emit('procedure DelSafeSyncMutexUnlock(P: Pointer);');
      Emit('begin');
      Emit(

      '  if P <> nil then System.LeaveCriticalSection(PRTLCriticalSection(P)^);'
      );
      Emit('end;');
      Emit('');
      Emit('procedure DelSafeSyncMutexFree(P: Pointer);');
      Emit('begin');
      Emit('  if P <> nil then');
      Emit('  begin');
      Emit('    System.DoneCriticalSection(PRTLCriticalSection(P)^);');
      Emit('    Dispose(PRTLCriticalSection(P));');
      Emit('  end;');
      Emit('end;');
      Emit('{$ENDIF}');
      Emit('');
    End;
End;

Procedure TDelSafeEmitterPascal.EmitTopologicalTypesAndMonads(Const TypeUsed:
                                                             Array Of Boolean;
                                                             OptTags, OptInners:
                                                             TStrings; Const
                                                             OptUsed: Array Of
                                                             Boolean;
                                                             ResTags, ResVals,
                                                             ResErrs: TStrings;
                                                             Const ResUsed:
                                                             Array Of Boolean);

Var 
  ItemKind, ItemIdx: array Of Integer;
  ItemKey: array Of string;
  ItemDeps: array Of TStringList;
  ItemEmitted: array Of Boolean;
  Count, I, J, K, Rem, ReadyIdx: Integer;
  Node: TASTNode;
  Rec: TASTRecordDecl;
  Enm: TASTEnumDecl;
  VarN: TASTEnumVariant;
  FnParams2: TStringList;
  FnRet2, FnPSig: string;
  FIdx: Integer;

Procedure AddDepToList(Deps: TStrings; Const TStr: String);

Var 
  T, InnerT, VT, ET, M, RetT: string;
  POf: Integer;
  FnP: TStringList;
Begin
  T := ResolveAliasType(Trim(TStr));
  If (T = '') Or (Pos('^', T) = 1) Or (Pos('Box<', T) = 1) Or
     (T = 'Int8') Or (T = 'Int16') Or (T = 'Int32') Or (T = 'Int64') Or
     (T = 'UInt8') Or (T = 'UInt16') Or (T = 'UInt32') Or (T = 'UInt64') Or
     (T = 'Float32') Or (T = 'Float64') Or (T = 'Bool') Or (T = 'Char') Or
     (T = 'String') Or (T = 'Pointer') Then
    Exit;
  FnP := TStringList.Create;
  Try
    If SplitFnType(T, FnP, RetT) Then
      Begin
        Deps.Add('__FN_' + UpperCase(FnTypeTag(T)));
        Exit;
      End;
  Finally
    FnP.Free;
End;
If Pos('array of ', T) = 1 Then
  Begin
    InnerT := Trim(Copy(T, 10, Length(T)));
    If Not ((InnerT = 'Int8') Or (InnerT = 'Int16') Or (InnerT = 'Int32') Or (
       InnerT = 'Int64') Or
       (InnerT = 'UInt8') Or (InnerT = 'UInt16') Or (InnerT = 'UInt32') Or (
       InnerT = 'UInt64') Or
       (InnerT = 'Float32') Or (InnerT = 'Float64') Or (InnerT = 'Bool') Or (
       InnerT = 'Char') Or
       (InnerT = 'String') Or (InnerT = 'Pointer')) Then
      Deps.Add('__DYN_' + UpperCase(MangleTypeTag(InnerT)))
    Else
      AddDepToList(Deps, InnerT);
    Exit;
  End;
If Pos('array[', T) = 1 Then
  Begin
    POf := Pos(' of ', T);
    If POf > 0 Then AddDepToList(Deps, Copy(T, POf + 4, Length(T)));
    Exit;
  End;
If IsMapType(T, VT, ET) Then Exit;
If (Copy(T, 1, 5) = 'Task<') And (T[Length(T)] = '>') Then
  Begin
    InnerT := Trim(Copy(T, 6, Length(T) - 6));
    If InnerT = '' Then InnerT := 'Void';
    Deps.Add('__TASK_' + UpperCase(MangleTypeTag(InnerT)));
    Exit;
  End;
If (Copy(T, 1, 8) = 'Channel<') And (T[Length(T)] = '>') Then
  Begin
    InnerT := Trim(Copy(T, 9, Length(T) - 9));
    If InnerT = '' Then InnerT := 'Int32';
    Deps.Add('__CHAN_' + UpperCase(MangleTypeTag(InnerT)));
    Exit;
  End;
If IsTypedValueOption(T, InnerT) Then
  Begin
    Deps.Add('__OPT_' + UpperCase(MangleTypeTag(InnerT)));
    Exit;
  End;
If IsTypedResult(T, VT, ET) Then
  Begin
    M := MangleTypeTag(VT) + '__' + MangleTypeTag(ET);
    Deps.Add('__RES_' + UpperCase(M));
    Exit;
  End;
Deps.Add(UpperCase(T));
End;

Function AllDepsEmitted(Idx: Integer): Boolean;

Var 
  D, M: Integer;
  DepKey: string;
Begin
  Result := True;
  For D := 0 To ItemDeps[Idx].Count - 1 Do
    Begin
      DepKey := ItemDeps[Idx][D];
      If DepKey = ItemKey[Idx] Then Continue;
      For M := 0 To Count - 1 Do
        If (Not ItemEmitted[M]) And (ItemKey[M] = DepKey) Then
          Exit(False);
    End;
End;

Procedure AppendItem(Kind, Idx: Integer; Const Key: String);
Begin
  SetLength(ItemKind, Count + 1);
  SetLength(ItemIdx, Count + 1);
  SetLength(ItemKey, Count + 1);
  SetLength(ItemDeps, Count + 1);
  SetLength(ItemEmitted, Count + 1);
  ItemKind[Count] := Kind;
  ItemIdx[Count] := Idx;
  ItemKey[Count] := Key;
  ItemDeps[Count] := TStringList.Create;
  ItemEmitted[Count] := False;
  Inc(Count);
End;

Begin
  Count := 0;
  For I := 0 To FModule.Types.Count - 1 Do
    Begin
      If Not TypeUsed[I] Then Continue;
      Node := TASTNode(FModule.Types[I]);
      If (Node is TASTRecordDecl) And (TASTRecordDecl(Node).GenericParams.Count
         > 0) Then Continue;
      If Node is TASTMapDecl Then Continue;
      If Node is TASTRecordDecl Then
        Begin
          Rec := TASTRecordDecl(Node);
          AppendItem(0, I, UpperCase(Rec.Name));
          For J := 0 To Rec.Fields.Count - 1 Do
            AddDepToList(ItemDeps[Count - 1], TASTRecordField(Rec.Fields[J]).
            TypeName);
        End
      Else If Node is TASTEnumDecl Then
             Begin
               Enm := TASTEnumDecl(Node);
               AppendItem(0, I, UpperCase(Enm.Name));
               If Enm.HasPayload Then
                 For J := 0 To Enm.Variants.Count - 1 Do
                   Begin
                     VarN := TASTEnumVariant(Enm.Variants[J]);
                     For K := 0 To VarN.Fields.Count - 1 Do
                       AddDepToList(ItemDeps[Count - 1], TASTRecordField(VarN.
                                    Fields[K]).TypeName);
                   End;
             End
      Else If Node is TASTArrayDecl Then
             Begin
               AppendItem(0, I, UpperCase(TASTArrayDecl(Node).Name));
               AddDepToList(ItemDeps[Count - 1], TASTArrayDecl(Node).ElemType);
             End
      Else If Node is TASTSetDecl Then
             AppendItem(0, I, UpperCase(TASTSetDecl(Node).Name))
      Else If Node is TASTSubrangeDecl Then
             AppendItem(0, I, UpperCase(TASTSubrangeDecl(Node).Name))
      Else If Node is TASTTypeAliasDecl Then
             Begin
               AppendItem(0, I, UpperCase(TASTTypeAliasDecl(Node).Name));
               AddDepToList(ItemDeps[Count - 1], TASTTypeAliasDecl(Node).
               TargetType);
             End;
    End;

  For I := 0 To OptTags.Count - 1 Do
    Begin
      If (I <= High(OptUsed)) And OptUsed[I] Then
        Begin
          AppendItem(1, I, '__OPT_' + UpperCase(OptTags[I]));
          AddDepToList(ItemDeps[Count - 1], OptInners[I]);
        End;
    End;

  For I := 0 To ResTags.Count - 1 Do
    Begin
      If (I <= High(ResUsed)) And ResUsed[I] Then
        Begin
          AppendItem(2, I, '__RES_' + UpperCase(ResTags[I]));
          AddDepToList(ItemDeps[Count - 1], ResVals[I]);
          AddDepToList(ItemDeps[Count - 1], ResErrs[I]);
        End;
    End;

  If Assigned(FDynTags) Then
    For I := 0 To FDynTags.Count - 1 Do
      Begin
        AppendItem(3, I, '__DYN_' + UpperCase(FDynTags[I]));
        AddDepToList(ItemDeps[Count - 1], FDynElems[I]);
      End;

  If Assigned(FFnTags) Then
    For I := 0 To FFnTags.Count - 1 Do
      Begin
        AppendItem(4, I, '__FN_' + UpperCase(FFnTags[I]));
        FnParams2 := TStringList.Create;
        Try
          If SplitFnType(FFnSigs[I], FnParams2, FnRet2) Then
            Begin
              For J := 0 To FnParams2.Count - 1 Do
                AddDepToList(ItemDeps[Count - 1], FnParams2[J]);
              If (FnRet2 <> '') And (Not SameText(FnRet2, 'Void')) Then
                AddDepToList(ItemDeps[Count - 1], FnRet2);
            End;
        Finally
          FnParams2.Free;
      End;
End;

If Assigned(FTaskTags) Then
  For I := 0 To FTaskTags.Count - 1 Do
    Begin
      AppendItem(5, I, '__TASK_' + UpperCase(FTaskTags[I]));
      If (FTaskInners[I] <> '') And (Not SameText(FTaskInners[I], 'Void')) Then
        AddDepToList(ItemDeps[Count - 1], FTaskInners[I]);
    End;

If Assigned(FChanTags) Then
  For I := 0 To FChanTags.Count - 1 Do
    Begin
      AppendItem(6, I, '__CHAN_' + UpperCase(FChanTags[I]));
      AddDepToList(ItemDeps[Count - 1], FChanElems[I]);
    End;

Try
  Rem := Count;
  While Rem > 0 Do
    Begin
      ReadyIdx := -1;
      For I := 0 To Count - 1 Do
        If (Not ItemEmitted[I]) And AllDepsEmitted(I) Then
          Begin
            ReadyIdx := I;
            Break;
          End;
      If ReadyIdx = -1 Then
        For I := 0 To Count - 1 Do
          If Not ItemEmitted[I] Then
            Begin
              ReadyIdx := I;
              Break;
            End;
      If ReadyIdx = -1 Then Break;
      ItemEmitted[ReadyIdx] := True;
      Dec(Rem);

      If ItemKind[ReadyIdx] = 0 Then
        Begin
          Node := TASTNode(FModule.Types[ItemIdx[ReadyIdx]]);
          If Node is TASTRecordDecl Then EmitRecordType(TASTRecordDecl(Node))
          Else If Node is TASTEnumDecl Then EmitEnumDecl(TASTEnumDecl(Node))
          Else If Node is TASTArrayDecl Then EmitArrayDecl(TASTArrayDecl(Node))
          Else If Node is TASTSetDecl Then EmitSetDecl(TASTSetDecl(Node))
          Else If Node is TASTSubrangeDecl Then EmitSubrangeDecl(

                                                                TASTSubrangeDecl
                                                                 (Node))
          Else If Node is TASTTypeAliasDecl Then EmitTypeAliasDecl(

                                                               TASTTypeAliasDecl
                                                                   (Node));
        End
      Else If ItemKind[ReadyIdx] = 1 Then
             EmitTypedOptionDecl(OptTags[ItemIdx[ReadyIdx]], OptInners[ItemIdx[
                                 ReadyIdx]])
      Else If ItemKind[ReadyIdx] = 2 Then
             EmitTypedResultDecl(ResTags[ItemIdx[ReadyIdx]], ResVals[ItemIdx[
                                 ReadyIdx]], ResErrs[ItemIdx[ReadyIdx]])
      Else If ItemKind[ReadyIdx] = 3 Then
             Begin
               Emit(Format('TDelSafeDyn_%s = array of %s;', [FDynTags[ItemIdx[
                    ReadyIdx]], EmitTypeRef(FDynElems[ItemIdx[ReadyIdx]])]));
               Emit('');
             End
      Else If ItemKind[ReadyIdx] = 4 Then
             Begin
               FIdx := ItemIdx[ReadyIdx];
               FnParams2 := TStringList.Create;
               Try
                 If SplitFnType(FFnSigs[FIdx], FnParams2, FnRet2) Then
                   Begin
                     FnPSig := 'AEnv: Pointer';
                     For J := 0 To FnParams2.Count - 1 Do
                       FnPSig := FnPSig + Format('; const _p%d: %s', [J,
                                 EmitTypeRef(FnParams2[J])]);
                     If (FnRet2 = '') Or SameText(FnRet2, 'Void') Then
                       Emit(Format('TDelSafeFn_%s_Call = procedure(%s);', [
                            FFnTags[FIdx], FnPSig]))
                     Else
                       Emit(Format('TDelSafeFn_%s_Call = function(%s): %s;', [
                            FFnTags[FIdx], FnPSig, EmitTypeRef(FnRet2)]));
                     Emit(Format('TDelSafeFn_%s = record', [FFnTags[FIdx]]));
                     IncIndent;
                     Emit(Format('fn_ptr: TDelSafeFn_%s_Call;', [FFnTags[FIdx]]))
                     ;
                     Emit('env: Pointer;');
                     DecIndent;
                     Emit('end;');
                     Emit('');
                   End;
               Finally
                 FnParams2.Free;
             End;
    End
    Else If ItemKind[ReadyIdx] = 5 Then
           Begin
             FIdx := ItemIdx[ReadyIdx];
             FnPSig := FTaskTags[FIdx];
             FnRet2 := FTaskInners[FIdx];
             Emit(Format('PDelSafeTaskState_%s = ^TDelSafeTaskState_%s;', [FnPSig,
                  FnPSig]));
             Emit(Format('TDelSafeTaskState_%s = record', [FnPSig]));
             IncIndent;
             Emit('thread_id: TThreadID;');
             Emit('has_thread: Boolean;');
             Emit('is_completed: Boolean;');
             If (FnRet2 <> '') And (Not SameText(FnRet2, 'Void')) Then
               Emit(Format('value: %s;', [EmitTypeRef(FnRet2)]));
             DecIndent;
             Emit('end;');
             Emit(Format('TDelSafeTask_%s = record', [FnPSig]));
             IncIndent;
             Emit(Format('state: PDelSafeTaskState_%s;', [FnPSig]));
             Emit('is_completed: Boolean;');
             If (FnRet2 <> '') And (Not SameText(FnRet2, 'Void')) Then
               Emit(Format('value: %s;', [EmitTypeRef(FnRet2)]));
             DecIndent;
             Emit('end;');
             Emit('');
           End
    Else If ItemKind[ReadyIdx] = 6 Then
           Begin
             FIdx := ItemIdx[ReadyIdx];
             FnPSig := FChanTags[FIdx];
             FnRet2 := FChanElems[FIdx];
             Emit(Format('PDelSafeChanState_%s = ^TDelSafeChanState_%s;', [FnPSig,
                  FnPSig]));
             Emit(Format('TDelSafeChanState_%s = record', [FnPSig]));
             IncIndent;
             Emit('lock: TRTLCriticalSection;');
             Emit(Format('buf: array of %s;', [EmitTypeRef(FnRet2)]));
             Emit('capacity: Int32;');
             Emit('count: Int32;');
             Emit('head: Int32;');
             Emit('tail: Int32;');
             Emit('is_closed: Boolean;');
             DecIndent;
             Emit('end;');
             Emit(Format('TDelSafeChan_%s = record', [FnPSig]));
             IncIndent;
             Emit(Format('state: PDelSafeChanState_%s;', [FnPSig]));
             DecIndent;
             Emit('end;');
             Emit('');
           End;
End;
Finally
  For I := 0 To Count - 1 Do
    ItemDeps[I].Free;
End;
End;

Procedure TDelSafeEmitterPascal.EmitFnRuntimeHelpers(DeclOnly: Boolean);

Var 
  I, J: Integer;
  Params: TStringList;
  RetT, ParamDecls, CallArgs, Tag: string;
  IsProc: Boolean;
Begin
  Params := TStringList.Create;
  Try
    For I := 0 To FFnTags.Count - 1 Do
      Begin
        Tag := FFnTags[I];
        If Not SplitFnType(FFnSigs[I], Params, RetT) Then Continue;
        IsProc := (RetT = '') Or SameText(RetT, 'Void');

        Emit(Format(

'function DelSafeMakeFn_%s(AFn: TDelSafeFn_%s_Call; AEnv: Pointer): TDelSafeFn_%s;'
             , [Tag, Tag, Tag]));
        If Not DeclOnly Then
          Begin
            Emit('begin');
            IncIndent;
            Emit('Result.fn_ptr := AFn;');
            Emit('Result.env := AEnv;');
            DecIndent;
            Emit('end;');
            Emit('');
          End;

        ParamDecls := Format('const AFn: TDelSafeFn_%s', [Tag]);
        CallArgs := 'AFn.env';
        For J := 0 To Params.Count - 1 Do
          Begin
            ParamDecls := ParamDecls + Format('; const _p%d: %s', [J,
                          EmitTypeRef(Params[J])]);
            CallArgs := CallArgs + Format(', _p%d', [J]);
          End;
        If IsProc Then
          Emit(Format('procedure DelSafeCallFn_%s(%s);', [Tag, ParamDecls]))
        Else
          Emit(Format('function DelSafeCallFn_%s(%s): %s;', [Tag, ParamDecls,
               EmitTypeRef(RetT)]));

        If Not DeclOnly Then
          Begin
            Emit('begin');
            IncIndent;
            If IsProc Then
              Emit(Format('AFn.fn_ptr(%s);', [CallArgs]))
            Else
              Emit(Format('Result := AFn.fn_ptr(%s);', [CallArgs]));
            DecIndent;
            Emit('end;');
            Emit('');
          End;
      End;
  Finally
    Params.Free;
End;
End;

Procedure TDelSafeEmitterPascal.EmitLambdaAndThunkDecls(ForwardOnly: Boolean);

Var 
  I, J: Integer;
  Fn, TempFunc, OldFunc: TASTFunction;
  L: TASTLambdaExpr;
  ParamDecls, CallArgs, Sig, FwdSuffix, Tag, MakeParams: string;
  SkipNames, AutoNames, AutoTypes: TStringList;
  OldProg: TASTProgramBlock;
  OldScopeList: TASTNodeList;
  IsProc: Boolean;
Begin
  If ForwardOnly Then FwdSuffix := ' forward;'
  Else FwdSuffix := '';

  // 1. Named function thunks
  For I := 0 To FThunkFuncs.Count - 1 Do
    Begin
      Fn := FindFunction(FThunkFuncs[I]);
      If Not Assigned(Fn) Then Continue;
      ParamDecls := 'AEnv: Pointer';
      CallArgs := '';
      For J := 0 To Fn.Params.Count - 1 Do
        Begin
          If TASTParam(Fn.Params[J]).Ownership = owMutBorrow Then
            ParamDecls := ParamDecls + Format('; var _p%d: %s', [J, EmitTypeRef(
                          TASTParam(Fn.Params[J]).TypeName)])
          Else
            ParamDecls := ParamDecls + Format('; const _p%d: %s', [J,
                          EmitTypeRef(TASTParam(Fn.Params[J]).TypeName)]);
          If J > 0 Then CallArgs := CallArgs + ', ';
          CallArgs := CallArgs + Format('_p%d', [J]);
        End;
      IsProc := Fn.IsProcedure Or (Fn.ReturnType = '') Or SameText(Fn.ReturnType
                , 'Void');
      If IsProc Then
        Sig := Format('procedure __delsafe_thunk_%s(%s);%s', [Fn.Name, ParamDecls
               , FwdSuffix])
      Else
        Sig := Format('function __delsafe_thunk_%s(%s): %s;%s', [Fn.Name,
               ParamDecls, EmitTypeRef(Fn.ReturnType), FwdSuffix]);
      Emit(Sig);
      If Not ForwardOnly Then
        Begin
          Emit('begin');
          IncIndent;
          Emit('if AEnv <> nil then ;');
          If IsProc Then
            Emit(Format('%s(%s);', [Fn.Name, CallArgs]))
          Else
            Emit(Format('Result := %s(%s);', [Fn.Name, CallArgs]));
          DecIndent;
          Emit('end;');
          Emit('');
        End;
    End;

  // 2. Lifted lambdas and env constructors
  For I := 0 To FLambdas.Count - 1 Do
    Begin
      L := TASTLambdaExpr(FLambdas[I]);
      Tag := FnTypeTag(L.ResolvedFnType);
      ParamDecls := 'AEnv: Pointer';
      For J := 0 To L.Params.Count - 1 Do
        Begin
          If TASTParam(L.Params[J]).Ownership = owMutBorrow Then
            ParamDecls := ParamDecls + Format('; var %s: %s', [TASTParam(L.
                          Params[J]).Name, EmitTypeRef(TASTParam(L.Params[J]).
                          TypeName)])
          Else
            ParamDecls := ParamDecls + Format('; const %s: %s', [TASTParam(L.
                          Params[J]).Name, EmitTypeRef(TASTParam(L.Params[J]).
                          TypeName)]);
        End;
      IsProc := (L.ReturnType = '') Or SameText(L.ReturnType, 'Void');
      If IsProc Then
        Sig := Format('procedure __delsafe_lambda_%d(%s);%s', [L.LambdaId,
               ParamDecls, FwdSuffix])
      Else
        Sig := Format('function __delsafe_lambda_%d(%s): %s;%s', [L.LambdaId,
               ParamDecls, EmitTypeRef(L.ReturnType), FwdSuffix]);
      Emit(Sig);

      If Not ForwardOnly Then
        Begin
          OldFunc := FCurrentFunc;
          OldProg := FProgramBlock;
          OldScopeList := FCurrentScopeList;
          TempFunc := TASTFunction.Create(L.Line, L.Col, '__delsafe_lambda_' +
                      IntToStr(L.LambdaId), L.ReturnType);
          TempFunc.IsProcedure := IsProc;
          For J := 0 To L.Params.Count - 1 Do
            TempFunc.Params.Add(CloneASTNode(TASTParam(L.Params[J])));
          For J := 0 To L.CaptureNames.Count - 1 Do
            TempFunc.LocalVars.Add(TASTVarDecl.Create(L.Line, L.Col, L.
                                   CaptureNames[J], L.CaptureTypes[J], Nil, True
            ));

          FCurrentFunc := TempFunc;
          FProgramBlock := Nil;
          SkipNames := TStringList.Create;
          AutoNames := TStringList.Create;
          AutoTypes := TStringList.Create;
          Try
            For J := 0 To TempFunc.Params.Count - 1 Do
              SkipNames.Add(TASTParam(TempFunc.Params[J]).Name);
            For J := 0 To TempFunc.LocalVars.Count - 1 Do
              SkipNames.Add(TASTVarDecl(TempFunc.LocalVars[J]).Name);
            If Assigned(L.BodyExpr) Then
              CollectAutoVarsFromExpr(L.BodyExpr, AutoNames, AutoTypes,
                                      SkipNames)
            Else
              CollectAutoVarsFromStmts(L.BodyStmts, AutoNames, AutoTypes,
                                       SkipNames);

            If (TempFunc.LocalVars.Count > 0) Or (AutoNames.Count > 0) Then
              Begin
                Emit('var');
                IncIndent;
                For J := 0 To TempFunc.LocalVars.Count - 1 Do
                  Emit(Format('%s: %s;', [TASTVarDecl(TempFunc.LocalVars[J]).
                  Name, EmitTypeRef(TASTVarDecl(TempFunc.LocalVars[J]).TypeName)
                  ]));
                For J := 0 To AutoNames.Count - 1 Do
                  Emit(Format('%s: %s;', [AutoNames[J], AutoTypes[J]]));
                DecIndent;
              End;

            Emit('begin');
            IncIndent;
            If L.CaptureNames.Count = 0 Then
              Emit('if AEnv <> nil then ;')
            Else
              For J := 0 To L.CaptureNames.Count - 1 Do
                Emit(Format('%s := PDelSafeEnv_lambda_%d(AEnv)^.%s;', [L.
                     CaptureNames[J], L.LambdaId, L.CaptureNames[J]]));

            If Assigned(L.BodyExpr) Then
              Begin
                If IsProc Then
                  Emit(EmitExpr(L.BodyExpr) + ';')
                Else
                  Emit('Result := ' + EmitExpr(L.BodyExpr) + ';');
              End
            Else
              Begin
                FActiveDefers.Clear;
                FLoopDeferBase := 0;
                FRaiiNames.Clear;
                FRaiiTypes.Clear;
                FLoopRaiiBase := 0;
                FCurrentScopeList := L.BodyStmts;
                EmitStmtList(L.BodyStmts);
                If FRaiiNames.Count > 0 Then
                  EmitActiveRaii(0);
                FActiveDefers.Clear;
                FRaiiNames.Clear;
                FRaiiTypes.Clear;
              End;
            DecIndent;
            Emit('end;');
            Emit('');
          Finally
            SkipNames.Free;
            AutoNames.Free;
            AutoTypes.Free;
            FCurrentFunc := OldFunc;
            FProgramBlock := OldProg;
            FCurrentScopeList := OldScopeList;
            TempFunc.Free;
        End;
    End;

  If L.CaptureNames.Count > 0 Then
    Begin
      MakeParams := '';
      For J := 0 To L.CaptureNames.Count - 1 Do
        Begin
          If J > 0 Then MakeParams := MakeParams + '; ';
          MakeParams := MakeParams + Format('const A_%s: %s', [L.CaptureNames[J]
                        , EmitTypeRef(L.CaptureTypes[J])]);
        End;
      Emit(Format('function __delsafe_make_lambda_%d(%s): TDelSafeFn_%s;%s', [L.
           LambdaId, MakeParams, Tag, FwdSuffix]));
      If Not ForwardOnly Then
        Begin
          Emit('var');
          IncIndent;
          Emit(Format('_env: PDelSafeEnv_lambda_%d;', [L.LambdaId]));
          DecIndent;
          Emit('begin');
          IncIndent;
          Emit('New(_env);');
          For J := 0 To L.CaptureNames.Count - 1 Do
            Emit(Format('_env^.%s := A_%s;', [L.CaptureNames[J], L.CaptureNames[
                 J]]));
          Emit(Format('Result := DelSafeMakeFn_%s(@__delsafe_lambda_%d, _env);', [
               Tag, L.LambdaId]));
          DecIndent;
          Emit('end;');
          Emit('');
        End;
    End;
End;
End;

Procedure TDelSafeEmitterPascal.EmitChanRuntimeHelpers(OptTags, OptInners:
                                                      TStrings; DeclOnly:
                                                      Boolean);

Var 
  I: Integer;
  Tag, InnerT, PasT, OptRet, OptTag, Dummy: string;
  IsVoid, TypedOpt: Boolean;
Begin
  // Task await helpers
  For I := 0 To FTaskTags.Count - 1 Do
    Begin
      Tag := FTaskTags[I];
      InnerT := FTaskInners[I];
      IsVoid := (InnerT = '') Or SameText(InnerT, 'Void');
      If IsVoid Then
        Begin
          Emit(Format('procedure DelSafeAwaitTask_%s(const T: TDelSafeTask_%s);',
               [Tag, Tag]));
          If Not DeclOnly Then
            Begin
              Emit('begin');
              IncIndent;
              Emit('if T.state <> nil then');
              Emit('begin');
              IncIndent;
              Emit('if T.state^.has_thread then');
              Emit('begin');
              IncIndent;
              Emit('WaitForThreadTerminate(T.state^.thread_id, 0);');
              Emit('CloseThread(T.state^.thread_id);');
              DecIndent;
              Emit('end;');
              Emit('Dispose(T.state);');
              DecIndent;
              Emit('end;');
              DecIndent;
              Emit('end;');
              Emit('');
            End;
        End
      Else
        Begin
          PasT := EmitTypeRef(InnerT);
          Emit(Format(
               'function DelSafeAwaitTask_%s(const T: TDelSafeTask_%s): %s;', [Tag
               , Tag, PasT]));
          If Not DeclOnly Then
            Begin
              Emit('begin');
              IncIndent;
              Emit('if T.state <> nil then');
              Emit('begin');
              IncIndent;
              Emit('if T.state^.has_thread then');
              Emit('begin');
              IncIndent;
              Emit('WaitForThreadTerminate(T.state^.thread_id, 0);');
              Emit('CloseThread(T.state^.thread_id);');
              DecIndent;
              Emit('end;');
              Emit('Result := T.state^.value;');
              Emit('Dispose(T.state);');
              DecIndent;
              Emit('end');
              Emit('else');
              Emit('  Result := T.value;');
              DecIndent;
              Emit('end;');
              Emit('');
            End;
        End;
    End;

  // Channel helpers
  For I := 0 To FChanTags.Count - 1 Do
    Begin
      Tag := FChanTags[I];
      InnerT := FChanElems[I];
      PasT := EmitTypeRef(InnerT);
      TypedOpt := IsTypedValueOption('Option<' + InnerT + '>', Dummy);
      If TypedOpt Then
        Begin
          OptTag := MangleTypeTag(InnerT);
          OptRet := 'TDelSafeOpt_' + OptTag;
        End
      Else
        Begin
          OptTag := '';
          OptRet := 'TDelSafeOption';
        End;

      Emit(Format('function DelSafeChanNew_%s(ACap: Int32): TDelSafeChan_%s;', [
           Tag, Tag]));
      If Not DeclOnly Then
        Begin
          Emit('var _st: PDelSafeChanState_' + Tag + '; _cap: Int32;');
          Emit('begin');
          IncIndent;
          Emit('_cap := ACap;');
          Emit('if _cap < 1 then _cap := 1;');
          Emit('New(_st);');
          Emit(Format('_st^ := Default(TDelSafeChanState_%s);', [Tag]));
          Emit('InitCriticalSection(_st^.lock);');
          Emit('SetLength(_st^.buf, _cap);');
          Emit('_st^.capacity := _cap;');
          Emit('Result.state := _st;');
          DecIndent;
          Emit('end;');
          Emit('');
        End;

      Emit(Format(

    'function DelSafeChanSend_%s(const C: TDelSafeChan_%s; const V: %s): Boolean;'
           , [Tag, Tag, PasT]));
      If Not DeclOnly Then
        Begin
          Emit('begin');
          IncIndent;
          Emit('if C.state = nil then Exit(False);');
          Emit('EnterCriticalSection(C.state^.lock);');
          Emit(

   'while (not C.state^.is_closed) and (C.state^.count >= C.state^.capacity) do'
          );
          Emit('begin');
          IncIndent;
          Emit('LeaveCriticalSection(C.state^.lock);');
          Emit('ThreadSwitch;');
          Emit('EnterCriticalSection(C.state^.lock);');
          DecIndent;
          Emit('end;');
          Emit('if C.state^.is_closed then');
          Emit('begin');
          IncIndent;
          Emit('LeaveCriticalSection(C.state^.lock);');
          Emit('Exit(False);');
          DecIndent;
          Emit('end;');
          Emit('C.state^.buf[C.state^.tail] := V;');
          Emit('C.state^.tail := (C.state^.tail + 1) mod C.state^.capacity;');
          Emit('Inc(C.state^.count);');
          Emit('LeaveCriticalSection(C.state^.lock);');
          Emit('Result := True;');
          DecIndent;
          Emit('end;');
          Emit('');
        End;

      Emit(Format(

 'function DelSafeChanTrySend_%s(const C: TDelSafeChan_%s; const V: %s): Boolean;'
           , [Tag, Tag, PasT]));
      If Not DeclOnly Then
        Begin
          Emit('begin');
          IncIndent;
          Emit('if C.state = nil then Exit(False);');
          Emit('EnterCriticalSection(C.state^.lock);');
          Emit(

           'if C.state^.is_closed or (C.state^.count >= C.state^.capacity) then'
          );
          Emit('begin');
          IncIndent;
          Emit('LeaveCriticalSection(C.state^.lock);');
          Emit('Exit(False);');
          DecIndent;
          Emit('end;');
          Emit('C.state^.buf[C.state^.tail] := V;');
          Emit('C.state^.tail := (C.state^.tail + 1) mod C.state^.capacity;');
          Emit('Inc(C.state^.count);');
          Emit('LeaveCriticalSection(C.state^.lock);');
          Emit('Result := True;');
          DecIndent;
          Emit('end;');
          Emit('');
        End;

      Emit(Format('function DelSafeChanRecv_%s(const C: TDelSafeChan_%s): %s;', [
           Tag, Tag, OptRet]));
      If Not DeclOnly Then
        Begin
          Emit('var _item: ' + PasT + ';');
          Emit('begin');
          IncIndent;
          Emit('if C.state = nil then');
          If TypedOpt Then Emit(Format('  Exit(DelSafeNone_%s());', [OptTag]))
          Else Emit('  Exit(DelSafeNone());');
          Emit('EnterCriticalSection(C.state^.lock);');
          Emit('while (C.state^.count = 0) and (not C.state^.is_closed) do');
          Emit('begin');
          IncIndent;
          Emit('LeaveCriticalSection(C.state^.lock);');
          Emit('ThreadSwitch;');
          Emit('EnterCriticalSection(C.state^.lock);');
          DecIndent;
          Emit('end;');
          Emit('if C.state^.count = 0 then');
          Emit('begin');
          IncIndent;
          Emit('LeaveCriticalSection(C.state^.lock);');
          If TypedOpt Then Emit(Format('Exit(DelSafeNone_%s());', [OptTag]))
          Else Emit('Exit(DelSafeNone());');
          DecIndent;
          Emit('end;');
          Emit('_item := C.state^.buf[C.state^.head];');
          Emit(Format('C.state^.buf[C.state^.head] := Default(%s);', [PasT]));
          Emit('C.state^.head := (C.state^.head + 1) mod C.state^.capacity;');
          Emit('Dec(C.state^.count);');
          Emit('LeaveCriticalSection(C.state^.lock);');
          If TypedOpt Then Emit(Format('Result := DelSafeSome_%s(_item);', [
                                OptTag]))
          Else Emit('Result := DelSafeSome(_item);');
          DecIndent;
          Emit('end;');
          Emit('');
        End;

      Emit(Format('function DelSafeChanTryRecv_%s(const C: TDelSafeChan_%s): %s;',
           [Tag, Tag, OptRet]));
      If Not DeclOnly Then
        Begin
          Emit('var _item: ' + PasT + ';');
          Emit('begin');
          IncIndent;
          Emit('if C.state = nil then');
          If TypedOpt Then Emit(Format('  Exit(DelSafeNone_%s());', [OptTag]))
          Else Emit('  Exit(DelSafeNone());');
          Emit('EnterCriticalSection(C.state^.lock);');
          Emit('if C.state^.count = 0 then');
          Emit('begin');
          IncIndent;
          Emit('LeaveCriticalSection(C.state^.lock);');
          If TypedOpt Then Emit(Format('Exit(DelSafeNone_%s());', [OptTag]))
          Else Emit('Exit(DelSafeNone());');
          DecIndent;
          Emit('end;');
          Emit('_item := C.state^.buf[C.state^.head];');
          Emit(Format('C.state^.buf[C.state^.head] := Default(%s);', [PasT]));
          Emit('C.state^.head := (C.state^.head + 1) mod C.state^.capacity;');
          Emit('Dec(C.state^.count);');
          Emit('LeaveCriticalSection(C.state^.lock);');
          If TypedOpt Then Emit(Format('Result := DelSafeSome_%s(_item);', [
                                OptTag]))
          Else Emit('Result := DelSafeSome(_item);');
          DecIndent;
          Emit('end;');
          Emit('');
        End;

      Emit(Format('procedure DelSafeChanClose_%s(const C: TDelSafeChan_%s);', [Tag
           , Tag]));
      If Not DeclOnly Then
        Begin
          Emit('begin');
          IncIndent;
          Emit('if C.state = nil then Exit;');
          Emit('EnterCriticalSection(C.state^.lock);');
          Emit('C.state^.is_closed := True;');
          Emit('LeaveCriticalSection(C.state^.lock);');
          DecIndent;
          Emit('end;');
          Emit('');
        End;

      Emit(Format('function DelSafeChanLen_%s(const C: TDelSafeChan_%s): Int32;',
           [Tag, Tag]));
      If Not DeclOnly Then
        Begin
          Emit('begin');
          IncIndent;
          Emit('if C.state = nil then Exit(0);');
          Emit('EnterCriticalSection(C.state^.lock);');
          Emit('Result := C.state^.count;');
          Emit('LeaveCriticalSection(C.state^.lock);');
          DecIndent;
          Emit('end;');
          Emit('');
        End;

      Emit(Format(
           'function DelSafeChanIsEmpty_%s(const C: TDelSafeChan_%s): Boolean;', [
           Tag, Tag]));
      If Not DeclOnly Then
        Begin
          Emit('begin');
          IncIndent;
          Emit('if C.state = nil then Exit(True);');
          Emit('EnterCriticalSection(C.state^.lock);');
          Emit('Result := (C.state^.count = 0);');
          Emit('LeaveCriticalSection(C.state^.lock);');
          DecIndent;
          Emit('end;');
          Emit('');
        End;

      Emit(Format(
           'function DelSafeChanIsFull_%s(const C: TDelSafeChan_%s): Boolean;', [
           Tag, Tag]));
      If Not DeclOnly Then
        Begin
          Emit('begin');
          IncIndent;
          Emit('if C.state = nil then Exit(False);');
          Emit('EnterCriticalSection(C.state^.lock);');
          Emit('Result := (C.state^.count >= C.state^.capacity);');
          Emit('LeaveCriticalSection(C.state^.lock);');
          DecIndent;
          Emit('end;');
          Emit('');
        End;

      Emit(Format(
           'function DelSafeChanIsClosed_%s(const C: TDelSafeChan_%s): Boolean;',
           [Tag, Tag]));
      If Not DeclOnly Then
        Begin
          Emit('begin');
          IncIndent;
          Emit('if C.state = nil then Exit(True);');
          Emit('EnterCriticalSection(C.state^.lock);');
          Emit('Result := C.state^.is_closed;');
          Emit('LeaveCriticalSection(C.state^.lock);');
          DecIndent;
          Emit('end;');
          Emit('');
        End;

      Emit(Format('procedure DelSafeChanDestroy_%s(const C: TDelSafeChan_%s);', [
           Tag, Tag]));
      If Not DeclOnly Then
        Begin
          Emit('begin');
          IncIndent;
          Emit('if C.state = nil then Exit;');
          Emit('DoneCriticalSection(C.state^.lock);');
          Emit('SetLength(C.state^.buf, 0);');
          Emit('Dispose(C.state);');
          DecIndent;
          Emit('end;');
          Emit('');
        End;
    End;
End;

Procedure TDelSafeEmitterPascal.EmitSpawnDecls(ForwardOnly: Boolean);

Var 
  I, J: Integer;
  S: TASTSpawnExpr;
  TempFunc, OldFunc: TASTFunction;
  OldProg: TASTProgramBlock;
  OldScopeList: TASTNodeList;
  NewV: TASTVarDecl;
  SkipNames, AutoNames, AutoTypes: TStringList;
  TaskTag, InnerT, FwdSuffix, CapParams, CallType, CallExprStr, AwaitTag: string
  ;
  IsVoid: Boolean;
Begin
  If ForwardOnly Then FwdSuffix := ' forward;'
  Else FwdSuffix := '';
  For I := 0 To FSpawns.Count - 1 Do
    Begin
      S := TASTSpawnExpr(FSpawns[I]);
      InnerT := S.InnerReturnType;
      If InnerT = '' Then InnerT := 'Void';
      TaskTag := RegisterTaskType('Task<' + InnerT + '>');
      IsVoid := SameText(InnerT, 'Void');

      Emit(Format('function __delsafe_spawn_worker_%d(_raw: Pointer): PtrInt;%s',
           [S.SpawnId, FwdSuffix]));
      If Not ForwardOnly Then
        Begin
          OldFunc := FCurrentFunc;
          OldProg := FProgramBlock;
          OldScopeList := FCurrentScopeList;
          TempFunc := TASTFunction.Create(S.Line, S.Col, Format(
                      '__delsafe_spawn_worker_%d', [S.SpawnId]), 'Void');
          Try
            For J := 0 To S.CaptureNames.Count - 1 Do
              Begin
                NewV := TASTVarDecl.Create(S.Line, S.Col, S.CaptureNames[J], S.
                        CaptureTypes[J]);
                TempFunc.LocalVars.Add(NewV);
              End;
            FCurrentFunc := TempFunc;
            FProgramBlock := Nil;
            FCurrentScopeList := Nil;
            FSpawnRefNames.Clear;
            FSpawnRefTargets.Clear;

            Emit('var');
            IncIndent;
            Emit(Format('_e: PDelSafeSpawnEnv_%d;', [S.SpawnId]));
            For J := 0 To S.CaptureNames.Count - 1 Do
              If (J >= S.CaptureByRef.Count) Or (S.CaptureByRef[J] <> '1') Then
                Emit(Format('%s: %s;', [S.CaptureNames[J], EmitTypeRef(S.
                     CaptureTypes[J])]));

            SkipNames := TStringList.Create;
            AutoNames := TStringList.Create;
            AutoTypes := TStringList.Create;
            Try
              For J := 0 To S.CaptureNames.Count - 1 Do
                SkipNames.Add(S.CaptureNames[J]);
              CollectAutoVarsFromExpr(S.CallExpr, AutoNames, AutoTypes,
                                      SkipNames);
              For J := 0 To AutoNames.Count - 1 Do
                Emit(Format('%s: %s;', [AutoNames[J], AutoTypes[J]]));
            Finally
              SkipNames.Free;
              AutoNames.Free;
              AutoTypes.Free;
        End;
      DecIndent;

      Emit('begin');
      IncIndent;
      Emit(Format('_e := PDelSafeSpawnEnv_%d(_raw);', [S.SpawnId]));
      For J := 0 To S.CaptureNames.Count - 1 Do
        Begin
          If (J < S.CaptureByRef.Count) And (S.CaptureByRef[J] = '1') Then
            Begin
              FSpawnRefNames.Add(S.CaptureNames[J]);
              FSpawnRefTargets.Add('_e^.' + S.CaptureNames[J] + '^');
            End
          Else
            Emit(Format('%s := _e^.%s;', [S.CaptureNames[J], S.CaptureNames[J]])
            );
        End;

      CallType := ResolveAliasType(GetExprTypeName(S.CallExpr));
      CallExprStr := EmitExpr(S.CallExpr);
      If (Copy(CallType, 1, 5) = 'Task<') And (CallType[Length(CallType)] = '>')
        Then
        Begin
          AwaitTag := RegisterTaskType(CallType);
          CallExprStr := Format('DelSafeAwaitTask_%s(%s)', [AwaitTag, CallExprStr
                         ]);
        End;
      If IsVoid Then
        Emit(CallExprStr + ';')
      Else
        Emit(Format('_e^.state^.value := %s;', [CallExprStr]));
      Emit('_e^.state^.is_completed := True;');
      Emit('Dispose(_e);');
      Emit('Result := 0;');
      DecIndent;
      Emit('end;');
      Emit('');
    Finally
      FSpawnRefNames.Clear;
      FSpawnRefTargets.Clear;
      FCurrentFunc := OldFunc;
      FProgramBlock := OldProg;
      FCurrentScopeList := OldScopeList;
      TempFunc.Free;
End;
End;

CapParams := '';
For J := 0 To S.CaptureNames.Count - 1 Do
  Begin
    If J > 0 Then CapParams := CapParams + '; ';
    If (J < S.CaptureByRef.Count) And (S.CaptureByRef[J] = '1') Then
      CapParams := CapParams + Format('var A_%s: %s', [S.CaptureNames[J],
                   EmitTypeRef(S.CaptureTypes[J])])
    Else
      CapParams := CapParams + Format('const A_%s: %s', [S.CaptureNames[J],
                   EmitTypeRef(S.CaptureTypes[J])]);
  End;
Emit(Format('function __delsafe_spawn_%d(%s): TDelSafeTask_%s;%s', [S.SpawnId,
     CapParams, TaskTag, FwdSuffix]));
If Not ForwardOnly Then
  Begin
    Emit('var');
    IncIndent;
    Emit(Format('_st: PDelSafeTaskState_%s;', [TaskTag]));
    Emit(Format('_env: PDelSafeSpawnEnv_%d;', [S.SpawnId]));
    DecIndent;
    Emit('begin');
    IncIndent;
    Emit('New(_st);');
    Emit(Format('_st^ := Default(TDelSafeTaskState_%s);', [TaskTag]));
    Emit('_st^.has_thread := True;');
    Emit('_st^.is_completed := False;');
    Emit('New(_env);');
    Emit(Format('_env^ := Default(TDelSafeSpawnEnv_%d);', [S.SpawnId]));
    Emit('_env^.state := _st;');
    For J := 0 To S.CaptureNames.Count - 1 Do
      Begin
        If (J < S.CaptureByRef.Count) And (S.CaptureByRef[J] = '1') Then
          Emit(Format('_env^.%s := @A_%s;', [S.CaptureNames[J], S.CaptureNames[J
               ]]))
        Else
          Emit(Format('_env^.%s := A_%s;', [S.CaptureNames[J], S.CaptureNames[J]
               ]));
      End;
    Emit(Format(
         '_st^.thread_id := BeginThread(@__delsafe_spawn_worker_%d, _env);', [S.
         SpawnId]));
    Emit(Format('Result := Default(TDelSafeTask_%s);', [TaskTag]));
    Emit('Result.state := _st;');
    Emit('Result.is_completed := False;');
    DecIndent;
    Emit('end;');
    Emit('');
  End;
End;
End;

Function TDelSafeEmitterPascal.Generate(AModule: TASTModule; AsUnit: Boolean;
                                       AsLibrary: Boolean; SharedRuntime:
                                       Boolean): string;

Var 
  I, ExportCount, CurExp, UsedConstCount, UsedTypeCount, UsedOptCount,
  UsedResCount: Integer;
  UsesClause, Sig, ReachText, ProgText, MapText, FnHelperText: string;
  Func: TASTFunction;
  Rec: TASTRecordDecl;
  ConstDecl: TASTConstDecl;
  VarDecl: TASTVarDecl;
  EffectiveLibrary, KeepAll, Changed, NeedBox, HasCustomMap, HasVarsBlock,
  HasEnvTypes: Boolean;
  MapTags, MapKeys, MapVals: TStringList;
  OptTags, OptInners, ResTags, ResVals, ResErrs: TStringList;
  UOptTags, UOptInners, UResTags, UResVals, UResErrs: TStringList;
  ConstUsed, TypeUsed, FuncUsed, OptUsed, ResUsed: array Of Boolean;
  ConstBodies, TypeBodies, TypeNames, FuncBodies, FuncSigs: array Of string;
Begin
  FModule := AModule;
  FOutput.Clear;
  FIndent := 0;
  MapTags := TStringList.Create;
  MapKeys := TStringList.Create;
  MapVals := TStringList.Create;
  OptTags := TStringList.Create;
  OptInners := TStringList.Create;
  ResTags := TStringList.Create;
  ResVals := TStringList.Create;
  ResErrs := TStringList.Create;
  UOptTags := TStringList.Create;
  UOptInners := TStringList.Create;
  UResTags := TStringList.Create;
  UResVals := TStringList.Create;
  UResErrs := TStringList.Create;
  Try
    FDynTags.Clear;
    FDynElems.Clear;
    FFnTags.Clear;
    FFnSigs.Clear;
    FThunkFuncs.Clear;
    FLambdas.Clear;
    FTaskTags.Clear;
    FTaskInners.Clear;
    FChanTags.Clear;
    FChanElems.Clear;
    FSpawns.Clear;
    FSpawnRefNames.Clear;
    FSpawnRefTargets.Clear;
    CollectMapsFromModule(AModule, MapTags, MapKeys, MapVals);
    CollectTypedMonadsFromModule(AModule, OptTags, OptInners, ResTags, ResVals,
                                 ResErrs);
    HasEnvTypes := (FSpawns.Count > 0);
    For I := 0 To FLambdas.Count - 1 Do
      If TASTLambdaExpr(FLambdas[I]).CaptureNames.Count > 0 Then
        Begin
          HasEnvTypes := True;
          Break;
        End;

    EffectiveLibrary := AsLibrary;
    If (Not EffectiveLibrary) And (Not Assigned(AModule.ProgramBlock)) Then
      Begin
        For I := 0 To AModule.Functions.Count - 1 Do
          Begin
            If TASTFunction(AModule.Functions[I]).IsExport Then
              Begin
                EffectiveLibrary := True;
                Break;
              End;
          End;
      End;

    KeepAll := AsUnit Or EffectiveLibrary Or AModule.IsUnit;

    // 1. Pre-render declarations for reachability analysis (Tree-Shaking)
    SetLength(ConstUsed, AModule.Constants.Count);
    SetLength(ConstBodies, AModule.Constants.Count);
    For I := 0 To AModule.Constants.Count - 1 Do
      Begin
        ConstDecl := TASTConstDecl(AModule.Constants[I]);
        If ConstDecl.DeclaredType <> '' Then
          ConstBodies[I] := Format('%s: %s = %s;', [ConstDecl.Name, EmitTypeRef(
                            ConstDecl.DeclaredType), EmitExpr(ConstDecl.
                            ValueExpr)])
        Else
          ConstBodies[I] := Format('%s = %s;', [ConstDecl.Name, EmitExpr(
                            ConstDecl.ValueExpr)]);
        ConstUsed[I] := KeepAll Or (ConstDecl.SourceModule = '');
      End;

    SetLength(TypeUsed, AModule.Types.Count);
    SetLength(TypeBodies, AModule.Types.Count);
    SetLength(TypeNames, AModule.Types.Count);
    For I := 0 To AModule.Types.Count - 1 Do
      Begin
        FOutput.Clear;
        FIndent := 0;
        TypeNames[I] := '';
        If AModule.Types[I] is TASTRecordDecl Then
          Begin
            Rec := TASTRecordDecl(AModule.Types[I]);
            If Rec.GenericParams.Count = 0 Then
              Begin
                TypeNames[I] := Rec.Name;
                EmitRecordType(Rec);
                EmitRecordConstructor(Rec);
              End;
          End
        Else If AModule.Types[I] is TASTEnumDecl Then
               Begin
                 TypeNames[I] := TASTEnumDecl(AModule.Types[I]).Name;
                 EmitEnumDecl(TASTEnumDecl(AModule.Types[I]));
                 EmitPayloadEnumConstructors(TASTEnumDecl(AModule.Types[I]),
                 False);
               End
        Else If AModule.Types[I] is TASTArrayDecl Then
               Begin
                 TypeNames[I] := TASTArrayDecl(AModule.Types[I]).Name;
                 EmitArrayDecl(TASTArrayDecl(AModule.Types[I]));
               End
        Else If AModule.Types[I] is TASTSetDecl Then
               Begin
                 TypeNames[I] := TASTSetDecl(AModule.Types[I]).Name;
                 EmitSetDecl(TASTSetDecl(AModule.Types[I]));
               End
        Else If AModule.Types[I] is TASTSubrangeDecl Then
               Begin
                 TypeNames[I] := TASTSubrangeDecl(AModule.Types[I]).Name;
                 EmitSubrangeDecl(TASTSubrangeDecl(AModule.Types[I]));
               End
        Else If AModule.Types[I] is TASTTypeAliasDecl Then
               Begin
                 TypeNames[I] := TASTTypeAliasDecl(AModule.Types[I]).Name;
                 EmitTypeAliasDecl(TASTTypeAliasDecl(AModule.Types[I]));
               End
        Else If AModule.Types[I] is TASTMapDecl Then
               Begin
                 TypeNames[I] := TASTMapDecl(AModule.Types[I]).Name;
                 EmitMapDecl(TASTMapDecl(AModule.Types[I]));
               End;
        TypeBodies[I] := FOutput.Text;
        TypeUsed[I] := KeepAll Or (TASTNode(AModule.Types[I]).SourceModule = '')
        ;
      End;

    SetLength(FuncUsed, AModule.Functions.Count);
    SetLength(FuncBodies, AModule.Functions.Count);
    SetLength(FuncSigs, AModule.Functions.Count);
    For I := 0 To AModule.Functions.Count - 1 Do
      Begin
        Func := TASTFunction(AModule.Functions[I]);
        FOutput.Clear;
        FIndent := 0;
        FuncSigs[I] := BuildFuncSig(Func);
        EmitFunction(Func);
        FuncBodies[I] := FOutput.Text;
        FuncUsed[I] := KeepAll Or (Func.SourceModule = '') Or Func.IsExport;
      End;

    FOutput.Clear;
    FIndent := 0;
    EmitMapRuntimeDecls(MapTags, MapKeys, MapVals, False);
    EmitMapRuntimeHelpers(MapTags, MapKeys, MapVals, False);
    MapText := FOutput.Text;

    FOutput.Clear;
    FIndent := 0;
    If Assigned(AModule.ProgramBlock) Then
      Begin
        If AsUnit Then
          Begin
            For I := 0 To AModule.ProgramBlock.Body.Count - 1 Do
              EmitStmt(TASTStmt(AModule.ProgramBlock.Body[I]));
          End
        Else If Not EffectiveLibrary Then
               EmitProgramBlock(AModule.ProgramBlock);
      End;
    If AsUnit Or (Not Assigned(AModule.ProgramBlock)) Then
      Begin
        For I := 0 To AModule.InitBody.Count - 1 Do
          EmitStmt(TASTStmt(AModule.InitBody[I]));
        For I := 0 To AModule.FiniBody.Count - 1 Do
          EmitStmt(TASTStmt(AModule.FiniBody[I]));
      End;
    For I := 0 To AModule.ModuleVars.Count - 1 Do
      If Assigned(TASTVarDecl(AModule.ModuleVars[I]).InitialExpr) Then
        Emit(EmitExpr(TASTVarDecl(AModule.ModuleVars[I]).InitialExpr) + ';');
    ProgText := FOutput.Text;

    FOutput.Clear;
    FIndent := 0;
    EmitFnRuntimeHelpers(False);
    EmitLambdaAndThunkDecls(False);
    EmitChanRuntimeHelpers(OptTags, OptInners, False);
    EmitSpawnDecls(False);
    FnHelperText := FOutput.Text;

    ReachText := ProgText + #10 + MapText + #10 + FnHelperText;
    For I := 0 To AModule.Constants.Count - 1 Do
      If ConstUsed[I] Then ReachText := ReachText + #10 + ConstBodies[I];
    For I := 0 To AModule.ModuleVars.Count - 1 Do
      ReachText := ReachText + #10 + TASTVarDecl(AModule.ModuleVars[I]).Name +
                   ': ' + EmitTypeRef(TASTVarDecl(AModule.ModuleVars[I]).
                   TypeName);
    For I := 0 To AModule.Types.Count - 1 Do
      If (TypeBodies[I] <> '') And TypeUsed[I] Then ReachText := ReachText + #10
                                                                 + TypeBodies[I]
    ;
    For I := 0 To AModule.Functions.Count - 1 Do
      If FuncUsed[I] Then ReachText := ReachText + #10 + FuncSigs[I] + #10 +
                                       FuncBodies[I];

    SetLength(OptUsed, OptTags.Count);
    For I := 0 To OptTags.Count - 1 Do
      OptUsed[I] := KeepAll Or (Pos('TDelSafeOpt_' + OptTags[I], ReachText) > 0)
                    Or
                    (Pos('DelSafeSome_' + OptTags[I], ReachText) > 0) Or (Pos(
                    'DelSafeNone_' + OptTags[I], ReachText) > 0);

    SetLength(ResUsed, ResTags.Count);
    For I := 0 To ResTags.Count - 1 Do
      ResUsed[I] := KeepAll Or (Pos('TDelSafeRes_' + ResTags[I], ReachText) > 0)
                    Or
                    (Pos('DelSafeOk_' + ResTags[I], ReachText) > 0) Or (Pos(
                    'DelSafeErr_' + ResTags[I], ReachText) > 0);

    If Not KeepAll Then
      Begin
        Repeat
          Changed := False;
          For I := 0 To AModule.Functions.Count - 1 Do
            Begin
              Func := TASTFunction(AModule.Functions[I]);
              If (Not FuncUsed[I]) And ((FuncBodies[I] <> '') Or (FuncSigs[I] <>
                 '')) And
                 (Pos(Func.Name, ReachText) > 0) Then
                Begin
                  FuncUsed[I] := True;
                  ReachText := ReachText + #10 + FuncSigs[I] + #10 + FuncBodies[
                               I];
                  Changed := True;
                End;
            End;
          For I := 0 To OptTags.Count - 1 Do
            Begin
              If (Not OptUsed[I]) And ((Pos('TDelSafeOpt_' + OptTags[I],
                 ReachText) > 0) Or
                 (Pos('DelSafeSome_' + OptTags[I], ReachText) > 0) Or (Pos(
                 'DelSafeNone_' + OptTags[I], ReachText) > 0)) Then
                Begin
                  OptUsed[I] := True;
                  ReachText := ReachText + #10 + EmitTypeRef(OptInners[I]);
                  Changed := True;
                End;
            End;
          For I := 0 To ResTags.Count - 1 Do
            Begin
              If (Not ResUsed[I]) And ((Pos('TDelSafeRes_' + ResTags[I],
                 ReachText) > 0) Or
                 (Pos('DelSafeOk_' + ResTags[I], ReachText) > 0) Or (Pos(
                 'DelSafeErr_' + ResTags[I], ReachText) > 0)) Then
                Begin
                  ResUsed[I] := True;
                  ReachText := ReachText + #10 + EmitTypeRef(ResVals[I]) + ' ' +
                               EmitTypeRef(ResErrs[I]);
                  Changed := True;
                End;
            End;
          For I := 0 To AModule.Types.Count - 1 Do
            Begin
              If (Not TypeUsed[I]) And (TypeNames[I] <> '') And
                 (Pos(TypeNames[I], ReachText) > 0) Then
                Begin
                  TypeUsed[I] := True;
                  ReachText := ReachText + #10 + TypeBodies[I];
                  Changed := True;
                End;
            End;
          For I := 0 To AModule.Constants.Count - 1 Do
            Begin
              ConstDecl := TASTConstDecl(AModule.Constants[I]);
              If (Not ConstUsed[I]) And (Pos(ConstDecl.Name, ReachText) > 0)
                Then
                Begin
                  ConstUsed[I] := True;
                  ReachText := ReachText + #10 + ConstBodies[I];
                  Changed := True;
                End;
            End;
        Until Not Changed;
      End;

    UsedOptCount := 0;
    For I := 0 To OptTags.Count - 1 Do
      If OptUsed[I] Then
        Begin
          Inc(UsedOptCount);
          UOptTags.Add(OptTags[I]);
          UOptInners.Add(OptInners[I]);
        End;

    UsedResCount := 0;
    For I := 0 To ResTags.Count - 1 Do
      If ResUsed[I] Then
        Begin
          Inc(UsedResCount);
          UResTags.Add(ResTags[I]);
          UResVals.Add(ResVals[I]);
          UResErrs.Add(ResErrs[I]);
        End;

    UsedConstCount := 0;
    For I := 0 To AModule.Constants.Count - 1 Do
      If ConstUsed[I] Then Inc(UsedConstCount);

    UsedTypeCount := 0;
    For I := 0 To AModule.Types.Count - 1 Do
      If TypeUsed[I] And (TypeNames[I] <> '') Then Inc(UsedTypeCount);

    HasCustomMap := False;
    For I := 0 To MapTags.Count - 1 Do
      If Not (IsBuiltinMapSideType(MapKeys[I]) And IsBuiltinMapSideType(MapVals[
         I])) Then
        Begin
          HasCustomMap := True;
          Break;
        End;

    NeedBox := AsUnit Or (Pos('DelSafeBox', ReachText) > 0);

    FOutput.Clear;
    FIndent := 0;

    If (Not AsUnit) And ((FTaskTags.Count > 0) Or (FChanTags.Count > 0) Or (
       FSpawns.Count > 0) Or (Pos('DelSafeSync', ReachText) > 0)) Then
      UsesClause := 

       '  {$IFNDEF PAS2JS}{$IFDEF UNIX}cthreads, {$ENDIF}{$ENDIF}SysUtils, Math'
    Else
      UsesClause := '  SysUtils, Math';
    If AsUnit And SharedRuntime Then
      UsesClause := UsesClause + ', uDelSafeRuntime';
    If Pos('DelSafeSocket', ReachText) > 0 Then
      UsesClause := UsesClause + '{$IFNDEF PAS2JS}, Sockets{$ENDIF}';
    If (Pos('DelSafeGetNanoseconds', ReachText) > 0) Or (Pos('DelSafeSetEnv',
       ReachText) > 0) Then
      UsesClause := UsesClause +
                    '{$IFNDEF PAS2JS}{$IFDEF WINDOWS}, Windows{$ENDIF}{$ENDIF}';
    For I := 0 To AModule.PascalImports.Count - 1 Do
      Begin
        If Pos(LowerCase(AModule.PascalImports[I]), LowerCase(UsesClause)) = 0
          Then
          UsesClause := UsesClause + ', ' + AModule.PascalImports[I];
      End;
    UsesClause := UsesClause + ';';

    If AsUnit Then
      Begin
        Emit('// Code automatically generated by the DelSafe Compiler (delsafec)')
        ;
        Emit('// Target: Object Pascal Unit (Free Pascal / BlaiseVue)');
        Emit('unit ' + AModule.Name + ';');
        Emit('');
        Emit('{$mode objfpc}{$H+}{$assertions on}');
        Emit('');
        Emit('interface');
        Emit('');
        Emit('uses');
        Emit(UsesClause);
        Emit('');

        EmitRuntimeTypeDecls(ReachText, MapTags, MapKeys, MapVals, True,
                             SharedRuntime);

        If UsedConstCount > 0 Then
          Begin
            Emit('const');
            IncIndent;
            For I := 0 To AModule.Constants.Count - 1 Do
              If ConstUsed[I] Then Emit(ConstBodies[I]);
            DecIndent;
            Emit('');
          End;

        If (UsedTypeCount > 0) Or (UsedOptCount > 0) Or (UsedResCount > 0) Or (
           FDynTags.Count > 0) Or HasCustomMap Or (FFnTags.Count > 0) Or (
           FTaskTags.Count > 0) Or (FChanTags.Count > 0) Then
          Begin
            Emit('type');
            IncIndent;
            For I := 0 To AModule.Types.Count - 1 Do
              Begin
                If TypeUsed[I] And (AModule.Types[I] is TASTRecordDecl) And (
                   TASTRecordDecl(AModule.Types[I]).GenericParams.Count = 0)
                  Then
                  Begin
                    Emit('{$IFNDEF PAS2JS}');
                    Emit(Format('P%s = ^T%s;', [TASTRecordDecl(AModule.Types[I])
                    .Name, TASTRecordDecl(AModule.Types[I]).Name]));
                    Emit(Format('PT%s = ^T%s;', [TASTRecordDecl(AModule.Types[I]
                    ).Name, TASTRecordDecl(AModule.Types[I]).Name]));
                    Emit('{$ENDIF}');
                  End
                Else If TypeUsed[I] And (AModule.Types[I] is TASTEnumDecl) And
                        TASTEnumDecl(AModule.Types[I]).HasPayload Then
                       Begin
                         Emit('{$IFNDEF PAS2JS}');
                         Emit(Format('P%s = ^T%s;', [TASTEnumDecl(AModule.Types[
                              I]).Name, TASTEnumDecl(AModule.Types[I]).Name]));
                         Emit(Format('PT%s = ^T%s;', [TASTEnumDecl(AModule.Types
                              [I]).Name, TASTEnumDecl(AModule.Types[I]).Name]));
                         Emit('{$ENDIF}');
                       End;
              End;

            EmitTopologicalTypesAndMonads(TypeUsed, OptTags, OptInners, OptUsed,
                                          ResTags, ResVals, ResErrs, ResUsed);
            EmitMapRuntimeDecls(MapTags, MapKeys, MapVals, False);
            For I := 0 To AModule.Types.Count - 1 Do
              If TypeUsed[I] And (AModule.Types[I] is TASTMapDecl) Then
                EmitMapDecl(TASTMapDecl(AModule.Types[I]));
            DecIndent;
            Emit('');

            For I := 0 To AModule.Types.Count - 1 Do
              Begin
                If TypeUsed[I] And (AModule.Types[I] is TASTRecordDecl) And (
                   TASTRecordDecl(AModule.Types[I]).GenericParams.Count = 0)
                  Then
                  Begin
                    Rec := TASTRecordDecl(AModule.Types[I]);
                    Emit(BuildRecordConstructorSig(Rec));
                    If NeedBox Then
                      Begin
                        Emit('{$IFNDEF PAS2JS}');
                        Emit(Format('function DelSafeBox(const V: T%s): P%s;', [
                             Rec.Name, Rec.Name]));
                        Emit('{$ENDIF}');
                      End;
                  End
                Else If TypeUsed[I] And (AModule.Types[I] is TASTEnumDecl) Then
                       EmitPayloadEnumConstructors(TASTEnumDecl(AModule.Types[I]
                       ), True);
              End;
            Emit('');
          End;

        If Not SharedRuntime Then
          EmitRuntimeHelpersInterface(ReachText);
        EmitTypedMonadHelpers(UOptTags, UOptInners, UResTags, UResVals, UResErrs
                              , True);
        EmitMapRuntimeHelpers(MapTags, MapKeys, MapVals, True);
        EmitFnRuntimeHelpers(True);
        EmitChanRuntimeHelpers(UOptTags, UOptInners, True);

        HasVarsBlock := False;
        For I := 0 To AModule.ModuleVars.Count - 1 Do
          If TASTVarDecl(AModule.ModuleVars[I]).IsPublic Then
            Begin
              HasVarsBlock := True;
              Break;
            End;
        If HasVarsBlock Then
          Begin
            Emit('var');
            IncIndent;
            For I := 0 To AModule.ModuleVars.Count - 1 Do
              Begin
                VarDecl := TASTVarDecl(AModule.ModuleVars[I]);
                If VarDecl.IsPublic Then
                  Emit(Format('%s: %s;', [VarDecl.Name, EmitTypeRef(VarDecl.
                       TypeName)]));
              End;
            DecIndent;
            Emit('');
          End;

        For I := 0 To AModule.Functions.Count - 1 Do
          Begin
            If Not FuncUsed[I] Then Continue;
            Func := TASTFunction(AModule.Functions[I]);
            If (Not Func.IsExtern) And (Func.GenericParams.Count = 0) And (Func.
               GenericParam = '') Then
              Begin
                Sig := FuncSigs[I];
                If Sig <> '' Then
                  Emit(Sig);
              End;
          End;
        Emit('');

        Emit('implementation');
        Emit('');

        If HasEnvTypes Then
          Begin
            Emit('type');
            IncIndent;
            For I := 0 To FLambdas.Count - 1 Do
              Begin
                If TASTLambdaExpr(FLambdas[I]).CaptureNames.Count > 0 Then
                  Begin
                    Emit(Format('PDelSafeEnv_lambda_%d = ^TDelSafeEnv_lambda_%d;',
                         [TASTLambdaExpr(FLambdas[I]).LambdaId, TASTLambdaExpr(

                                                                        FLambdas
                                                                               [
                                                                               I
                                                                               ]
                    ).LambdaId]));
                    Emit(Format('TDelSafeEnv_lambda_%d = record', [TASTLambdaExpr
                         (FLambdas[I]).LambdaId]));
                    IncIndent;
                    For CurExp := 0 To TASTLambdaExpr(FLambdas[I]).CaptureNames.
                        Count - 1 Do
                      Emit(Format('%s: %s;', [TASTLambdaExpr(FLambdas[I]).
                      CaptureNames[CurExp], EmitTypeRef(TASTLambdaExpr(FLambdas[
                                                        I]).CaptureTypes[CurExp]
                      )]));
                    DecIndent;
                    Emit('end;');
                    Emit('');
                  End;
              End;
            For I := 0 To FSpawns.Count - 1 Do
              Begin
                Emit(Format('PDelSafeSpawnEnv_%d = ^TDelSafeSpawnEnv_%d;', [
                     TASTSpawnExpr(FSpawns[I]).SpawnId, TASTSpawnExpr(FSpawns[I]
                ).SpawnId]));
                Emit(Format('TDelSafeSpawnEnv_%d = record', [TASTSpawnExpr(
                     FSpawns[I]).SpawnId]));
                IncIndent;
                Emit(Format('state: PDelSafeTaskState_%s;', [RegisterTaskType(
                     'Task<' + TASTSpawnExpr(FSpawns[I]).InnerReturnType + '>')]
                ));
                For CurExp := 0 To TASTSpawnExpr(FSpawns[I]).CaptureNames.Count
                    - 1 Do
                  If (CurExp < TASTSpawnExpr(FSpawns[I]).CaptureByRef.Count) And
                     (TASTSpawnExpr(FSpawns[I]).CaptureByRef[CurExp] = '1') Then
                    Emit(Format('%s: ^%s;', [TASTSpawnExpr(FSpawns[I]).
                    CaptureNames[CurExp], EmitTypeRef(TASTSpawnExpr(FSpawns[I]).
                    CaptureTypes[CurExp])]))
                  Else
                    Emit(Format('%s: %s;', [TASTSpawnExpr(FSpawns[I]).
                    CaptureNames[CurExp], EmitTypeRef(TASTSpawnExpr(FSpawns[I]).
                    CaptureTypes[CurExp])]));
                DecIndent;
                Emit('end;');
                Emit('');
              End;
            DecIndent;
          End;

        HasVarsBlock := False;
        For I := 0 To AModule.ModuleVars.Count - 1 Do
          If Not TASTVarDecl(AModule.ModuleVars[I]).IsPublic Then
            Begin
              HasVarsBlock := True;
              Break;
            End;
        If HasVarsBlock Then
          Begin
            Emit('var');
            IncIndent;
            For I := 0 To AModule.ModuleVars.Count - 1 Do
              Begin
                VarDecl := TASTVarDecl(AModule.ModuleVars[I]);
                If Not VarDecl.IsPublic Then
                  Emit(Format('%s: %s;', [VarDecl.Name, EmitTypeRef(VarDecl.
                       TypeName)]));
              End;
            DecIndent;
            Emit('');
          End;

        If UsedTypeCount > 0 Then
          Begin
            For I := 0 To AModule.Types.Count - 1 Do
              Begin
                If TypeUsed[I] And (AModule.Types[I] is TASTRecordDecl) And (
                   TASTRecordDecl(AModule.Types[I]).GenericParams.Count = 0)
                  Then
                  Begin
                    EmitRecordConstructor(TASTRecordDecl(AModule.Types[I]));
                    If NeedBox Then
                      Begin
                        Emit('{$IFNDEF PAS2JS}');
                        Emit(Format('function DelSafeBox(const V: T%s): P%s;', [
                             TASTRecordDecl(AModule.Types[I]).Name,
                        TASTRecordDecl(AModule.Types[I]).Name]));
                        Emit('begin');
                        Emit('  New(Result);');
                        Emit('  Result^ := V;');
                        Emit('end;');
                        Emit('{$ENDIF}');
                        Emit('');
                      End;
                  End
                Else If TypeUsed[I] And (AModule.Types[I] is TASTEnumDecl) Then
                       EmitPayloadEnumConstructors(TASTEnumDecl(AModule.Types[I]
                       ), False);
              End;
          End;

        If Not SharedRuntime Then
          EmitRuntimeHelpersImplementation(ReachText);
        EmitTypedMonadHelpers(UOptTags, UOptInners, UResTags, UResVals, UResErrs
                              , False);
        EmitMapRuntimeHelpers(MapTags, MapKeys, MapVals, False);
        EmitFnRuntimeHelpers(False);
        EmitChanRuntimeHelpers(UOptTags, UOptInners, False);
        EmitLambdaAndThunkDecls(True);
        EmitSpawnDecls(True);

        For I := 0 To AModule.Functions.Count - 1 Do
          If FuncUsed[I] Then
            EmitFunction(TASTFunction(AModule.Functions[I]));

        EmitLambdaAndThunkDecls(False);
        EmitSpawnDecls(False);

        HasVarsBlock := False;
        For I := 0 To AModule.ModuleVars.Count - 1 Do
          If Assigned(TASTVarDecl(AModule.ModuleVars[I]).InitialExpr) Then
            Begin
              HasVarsBlock := True;
              Break;
            End;
        If Assigned(AModule.ProgramBlock) Or (AModule.InitBody.Count > 0) Or
           HasVarsBlock Then
          Begin
            Emit('');
            Emit('initialization');
            IncIndent;
            For I := 0 To AModule.ModuleVars.Count - 1 Do
              Begin
                VarDecl := TASTVarDecl(AModule.ModuleVars[I]);
                If Assigned(VarDecl.InitialExpr) Then
                  Begin
                    If VarDecl.InitialExpr is TASTMapLiteralExpr Then
                      EmitMapLiteralAssign(VarDecl.Name, VarDecl.TypeName,
                                           TASTMapLiteralExpr(VarDecl.
                                           InitialExpr))
                    Else If (VarDecl.InitialExpr is TASTSetLiteralExpr) And (Not
                            IsSetType(VarDecl.TypeName)) Then
                           EmitArrayLiteralAssign(VarDecl.Name, VarDecl.TypeName
                                                  , TASTSetLiteralExpr(VarDecl.
                                                  InitialExpr))
                    Else
                      Emit(Format('%s := %s;', [VarDecl.Name, EmitExpr(VarDecl.
                           InitialExpr)]));
                  End;
              End;
            For I := 0 To AModule.InitBody.Count - 1 Do
              EmitStmt(TASTStmt(AModule.InitBody[I]));
            If Assigned(AModule.ProgramBlock) Then
              For I := 0 To AModule.ProgramBlock.Body.Count - 1 Do
                EmitStmt(TASTStmt(AModule.ProgramBlock.Body[I]));
            DecIndent;
          End;

        If AModule.FiniBody.Count > 0 Then
          Begin
            Emit('');
            Emit('finalization');
            IncIndent;
            For I := 0 To AModule.FiniBody.Count - 1 Do
              EmitStmt(TASTStmt(AModule.FiniBody[I]));
            DecIndent;
          End;

        Emit('end.');
      End
    Else
      Begin
        Emit('// Code automatically generated by the DelSafe Compiler (delsafec)')
        ;
        Emit('// Target: Object Pascal (Free Pascal)');
        If EffectiveLibrary Then
          Emit('library ' + AModule.Name + ';')
        Else
          Emit('program ' + AModule.Name + ';');
        Emit('');
        Emit('{$mode objfpc}{$H+}{$assertions on}');
        Emit('');
        Emit('uses');
        Emit(UsesClause);
        Emit('');

        EmitRuntimeTypeDecls(ReachText, MapTags, MapKeys, MapVals, False);

        If UsedConstCount > 0 Then
          Begin
            Emit('const');
            IncIndent;
            For I := 0 To AModule.Constants.Count - 1 Do
              If ConstUsed[I] Then Emit(ConstBodies[I]);
            DecIndent;
            Emit('');
          End;

        If (UsedTypeCount > 0) Or (UsedOptCount > 0) Or (UsedResCount > 0) Or (
           FDynTags.Count > 0) Or HasCustomMap Or (FFnTags.Count > 0) Or (
           FTaskTags.Count > 0) Or (FChanTags.Count > 0) Or HasEnvTypes Then
          Begin
            Emit('type');
            IncIndent;
            For I := 0 To AModule.Types.Count - 1 Do
              Begin
                If TypeUsed[I] And (AModule.Types[I] is TASTRecordDecl) And (
                   TASTRecordDecl(AModule.Types[I]).GenericParams.Count = 0)
                  Then
                  Begin
                    Emit(Format('P%s = ^T%s;', [TASTRecordDecl(AModule.Types[I])
                    .Name, TASTRecordDecl(AModule.Types[I]).Name]));
                    Emit(Format('PT%s = ^T%s;', [TASTRecordDecl(AModule.Types[I]
                    ).Name, TASTRecordDecl(AModule.Types[I]).Name]));
                  End
                Else If TypeUsed[I] And (AModule.Types[I] is TASTEnumDecl) And
                        TASTEnumDecl(AModule.Types[I]).HasPayload Then
                       Begin
                         Emit(Format('P%s = ^T%s;', [TASTEnumDecl(AModule.Types[
                              I]).Name, TASTEnumDecl(AModule.Types[I]).Name]));
                         Emit(Format('PT%s = ^T%s;', [TASTEnumDecl(AModule.Types
                              [I]).Name, TASTEnumDecl(AModule.Types[I]).Name]));
                       End;
              End;

            EmitTopologicalTypesAndMonads(TypeUsed, OptTags, OptInners, OptUsed,
                                          ResTags, ResVals, ResErrs, ResUsed);
            EmitMapRuntimeDecls(MapTags, MapKeys, MapVals, False);
            For I := 0 To AModule.Types.Count - 1 Do
              If TypeUsed[I] And (AModule.Types[I] is TASTMapDecl) Then
                EmitMapDecl(TASTMapDecl(AModule.Types[I]));
            For I := 0 To FLambdas.Count - 1 Do
              Begin
                If TASTLambdaExpr(FLambdas[I]).CaptureNames.Count > 0 Then
                  Begin
                    Emit(Format('PDelSafeEnv_lambda_%d = ^TDelSafeEnv_lambda_%d;',
                         [TASTLambdaExpr(FLambdas[I]).LambdaId, TASTLambdaExpr(

                                                                        FLambdas
                                                                               [
                                                                               I
                                                                               ]
                    ).LambdaId]));
                    Emit(Format('TDelSafeEnv_lambda_%d = record', [TASTLambdaExpr
                         (FLambdas[I]).LambdaId]));
                    IncIndent;
                    For CurExp := 0 To TASTLambdaExpr(FLambdas[I]).CaptureNames.
                        Count - 1 Do
                      Emit(Format('%s: %s;', [TASTLambdaExpr(FLambdas[I]).
                      CaptureNames[CurExp], EmitTypeRef(TASTLambdaExpr(FLambdas[
                                                        I]).CaptureTypes[CurExp]
                      )]));
                    DecIndent;
                    Emit('end;');
                    Emit('');
                  End;
              End;
            For I := 0 To FSpawns.Count - 1 Do
              Begin
                Emit(Format('PDelSafeSpawnEnv_%d = ^TDelSafeSpawnEnv_%d;', [
                     TASTSpawnExpr(FSpawns[I]).SpawnId, TASTSpawnExpr(FSpawns[I]
                ).SpawnId]));
                Emit(Format('TDelSafeSpawnEnv_%d = record', [TASTSpawnExpr(
                     FSpawns[I]).SpawnId]));
                IncIndent;
                Emit(Format('state: PDelSafeTaskState_%s;', [RegisterTaskType(
                     'Task<' + TASTSpawnExpr(FSpawns[I]).InnerReturnType + '>')]
                ));
                For CurExp := 0 To TASTSpawnExpr(FSpawns[I]).CaptureNames.Count
                    - 1 Do
                  If (CurExp < TASTSpawnExpr(FSpawns[I]).CaptureByRef.Count) And
                     (TASTSpawnExpr(FSpawns[I]).CaptureByRef[CurExp] = '1') Then
                    Emit(Format('%s: ^%s;', [TASTSpawnExpr(FSpawns[I]).
                    CaptureNames[CurExp], EmitTypeRef(TASTSpawnExpr(FSpawns[I]).
                    CaptureTypes[CurExp])]))
                  Else
                    Emit(Format('%s: %s;', [TASTSpawnExpr(FSpawns[I]).
                    CaptureNames[CurExp], EmitTypeRef(TASTSpawnExpr(FSpawns[I]).
                    CaptureTypes[CurExp])]));
                DecIndent;
                Emit('end;');
                Emit('');
              End;
            DecIndent;
            Emit('');

            For I := 0 To AModule.Types.Count - 1 Do
              Begin
                If TypeUsed[I] And (AModule.Types[I] is TASTRecordDecl) And (
                   TASTRecordDecl(AModule.Types[I]).GenericParams.Count = 0)
                  Then
                  Begin
                    EmitRecordConstructor(TASTRecordDecl(AModule.Types[I]));
                    If NeedBox Then
                      Begin
                        Emit(Format(
                             'function DelSafeBox(const V: T%s): P%s; overload;',
                             [TASTRecordDecl(AModule.Types[I]).Name,
                        TASTRecordDecl(AModule.Types[I]).Name]));
                        Emit('begin');
                        Emit('  New(Result);');
                        Emit('  Result^ := V;');
                        Emit('end;');
                        Emit('');
                      End;
                  End
                Else If TypeUsed[I] And (AModule.Types[I] is TASTEnumDecl) Then
                       EmitPayloadEnumConstructors(TASTEnumDecl(AModule.Types[I]
                       ), False);
              End;
          End;

        EmitRuntimeHelpersImplementation(ReachText);
        EmitTypedMonadHelpers(UOptTags, UOptInners, UResTags, UResVals, UResErrs
                              , False);
        EmitMapRuntimeHelpers(MapTags, MapKeys, MapVals, False);
        EmitFnRuntimeHelpers(False);
        EmitChanRuntimeHelpers(UOptTags, UOptInners, False);

        HasVarsBlock := False;
        For I := 0 To AModule.ModuleVars.Count - 1 Do
          If KeepAll Or (TASTVarDecl(AModule.ModuleVars[I]).SourceModule = '')
             Or
             (Pos(TASTVarDecl(AModule.ModuleVars[I]).Name, ReachText) > 0) Then
            Begin
              HasVarsBlock := True;
              Break;
            End;
        If HasVarsBlock Then
          Begin
            Emit('var');
            IncIndent;
            For I := 0 To AModule.ModuleVars.Count - 1 Do
              Begin
                VarDecl := TASTVarDecl(AModule.ModuleVars[I]);
                If KeepAll Or (VarDecl.SourceModule = '') Or (Pos(VarDecl.Name,
                   ReachText) > 0) Then
                  Emit(Format('%s: %s;', [VarDecl.Name, EmitTypeRef(VarDecl.
                       TypeName)]));
              End;
            DecIndent;
            Emit('');
          End;

        For I := 0 To AModule.Functions.Count - 1 Do
          Begin
            If Not FuncUsed[I] Then Continue;
            Func := TASTFunction(AModule.Functions[I]);
            If (Not Func.IsExtern) And (Func.GenericParams.Count = 0) And (Func.
               GenericParam = '') And (Func.InlineMode <> 'always') Then
              Begin
                Sig := FuncSigs[I];
                If Sig <> '' Then
                  Emit(Copy(Sig, 1, Length(Sig) - 1) + ' forward;');
              End;
          End;
        EmitLambdaAndThunkDecls(True);
        EmitSpawnDecls(True);
        Emit('');

        For I := 0 To AModule.Functions.Count - 1 Do
          If FuncUsed[I] Then
            EmitFunction(TASTFunction(AModule.Functions[I]));

        EmitLambdaAndThunkDecls(False);
        EmitSpawnDecls(False);

        If EffectiveLibrary Then
          Begin
            ExportCount := 0;
            For I := 0 To AModule.Functions.Count - 1 Do
              If FuncUsed[I] And TASTFunction(AModule.Functions[I]).IsExport
                Then Inc(ExportCount);

            If ExportCount > 0 Then
              Begin
                Emit('');
                Emit('exports');
                IncIndent;
                CurExp := 0;
                For I := 0 To AModule.Functions.Count - 1 Do
                  Begin
                    If Not FuncUsed[I] Then Continue;
                    Func := TASTFunction(AModule.Functions[I]);
                    If Func.IsExport Then
                      Begin
                        Inc(CurExp);
                        If CurExp = ExportCount Then
                          Emit(Format('%s name ''%s'';', [Func.Name, Func.Name])
                          )
                        Else
                          Emit(Format('%s name ''%s'',', [Func.Name, Func.Name])
                          );
                      End;
                  End;
                DecIndent;
              End;
            Emit('');
            Emit('begin');
            Emit('end.');
          End
        Else If Assigned(AModule.ProgramBlock) Then
               EmitProgramBlock(AModule.ProgramBlock)
        Else
          Begin
            Emit('begin');
            Emit('end.');
          End;
      End;

    Result := FOutput.Text;
  Finally
    UResErrs.Free;
    UResVals.Free;
    UResTags.Free;
    UOptInners.Free;
    UOptTags.Free;
    ResErrs.Free;
    ResVals.Free;
    ResTags.Free;
    OptInners.Free;
    OptTags.Free;
    MapTags.Free;
    MapKeys.Free;
    MapVals.Free;
End;
End;

Class Function TDelSafeEmitterPascal.GenerateRuntimeUnit: string;

  Const 
    AllRuntimeRef = 


'Float64 Float32 PDelSafePtr_ TDelSafeDyn_ TDelSafeResult TResultDoubleError TDelSafeTask TDelSafeOption '
                    +
                    'DelSafeOk( DelSafeErr( DelSafeSome( DelSafeNone( ' +


   'DelSafeDynPop_Int8 DelSafeDynPop_Int16 DelSafeDynPop_Int32 DelSafeDynPop_Int64 '
                    +


'DelSafeDynPop_UInt8 DelSafeDynPop_UInt16 DelSafeDynPop_UInt32 DelSafeDynPop_UInt64 '
                    +


'DelSafeDynPop_Float32 DelSafeDynPop_Float64 DelSafeDynPop_Bool DelSafeDynPop_Char '
                    +
                    'DelSafeDynPop_String DelSafeDynPop_Pointer ' +


'DelSafeCharAt DelSafeByteAt DelSafeCharFromByte DelSafeSubstring DelSafeIfThen DelSafeMin DelSafeMax DelSafeClamp '
                    +


'DelSafeStrTrim DelSafeUpperCase DelSafeLowerCase DelSafeStartsWith DelSafeEndsWith '
                    +


'DelSafeStrContains DelSafeIndexOf DelSafeStrReplace DelSafeStrSplit DelSafeStrJoin '
                    +


'DelSafePadLeft DelSafePadRight DelSafeRepeatStr DelSafeStrToFloat DelSafeTryStrToInt '
                    +


'DelSafeTryStrToFloat DelSafeRound DelSafeRandomInt DelSafeRandomFloat DelSafeReadLn '
                    +


    'DelSafeGetEnv DelSafeSetEnv DelSafeFileExists DelSafeReadFile DelSafeWriteFile '
                    +


'DelSafeCreateDir DelSafeRemoveDir DelSafeDeleteFile DelSafeDirExists DelSafeFileSize '
                    +


'DelSafeListDir DelSafeCopyFile DelSafeRenameFile DelSafeBoolToStr DelSafeFloatToStr '
                    +


         'DelSafeJson DelSafeGetNanoseconds DelSafeSleepMs DelSafeSync DelSafeSocket'
    ;

  Var 
    Em: TDelSafeEmitterPascal;
    EmptyTags, EmptyKeys, EmptyVals: TStringList;
  Begin
    Em := TDelSafeEmitterPascal.Create;
    EmptyTags := TStringList.Create;
    EmptyKeys := TStringList.Create;
    EmptyVals := TStringList.Create;
    Try
      Em.Emit('// Code automatically generated by the DelSafe Compiler (delsafec)'
      );
      Em.Emit('// Shared BlaiseVue / Free Pascal / Pas2JS Runtime Unit');
      Em.Emit('unit uDelSafeRuntime;');
      Em.Emit('');
      Em.Emit('{$mode objfpc}{$H+}{$assertions on}');
      Em.Emit('');
      Em.Emit('interface');
      Em.Emit('');
      Em.Emit('uses');
      Em.Emit(

'  SysUtils, Math{$IFNDEF PAS2JS}, Sockets{$IFDEF WINDOWS}, Windows{$ENDIF}{$ENDIF};'
      );
      Em.Emit('');
      Em.EmitRuntimeTypeDecls(AllRuntimeRef, EmptyTags, EmptyKeys, EmptyVals,
                              True, False);
      Em.EmitRuntimeHelpersInterface(AllRuntimeRef);
      Em.Emit('implementation');
      Em.Emit('');
      Em.EmitRuntimeHelpersImplementation(AllRuntimeRef);
      Em.Emit('end.');
      Result := Em.FOutput.Text;
    Finally
      EmptyVals.Free;
      EmptyKeys.Free;
      EmptyTags.Free;
      Em.Free;
  End;
End;

End.
