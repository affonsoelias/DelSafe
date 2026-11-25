
Program aetherc;

{$mode objfpc}{$H+}
{$codepage utf8}

Uses 
SysUtils, Classes,
uAetherTokens,
uAetherLexer,
uAetherAST,
uAetherParser,
uAetherSymbols,
uAetherTypeChecker,
uAetherBorrowChecker,
uAetherEmitterPascal,
uAetherEmitterC,
uAetherToolchain,
uAetherJSONDiag,
uAetherLSP,
uAetherProject,
uAetherFormatter,
uAetherIncremental,
uAetherOptimizer,
uAetherBootstrap,
uAetherDoc,
uAetherRegistry,
uAetherHeaderGen,
uAetherBenchmark,
uAetherDerives,
uAetherLinter,
uAetherProfiler,
uAetherCfg,
uAetherUpgrade;

Procedure PrintBanner;
Begin
  WriteLn('========================================================');
  WriteLn(Format('  AetherLang Compiler (aetherc) - Version %s (Alpha) ', [AETHER_COMPILER_VERSION]));
  WriteLn('  Pascal Structure + Pascal Safety + AI-Native Design   ');
  WriteLn('========================================================');
End;

Procedure PrintVersionInfo;
Var
  OSName, ArchName: string;
Begin
  TAetherUpgrade.DetectPlatform(OSName, ArchName);
  WriteLn(Format('aetherc %s (%s-%s)', [AETHER_COMPILER_VERSION, OSName, ArchName]));
End;

Procedure PrintUsage;
Begin
  WriteLn('Usage: aetherc <command | file.aeth> [options]');
  WriteLn('');
  WriteLn('Build and Execution Commands:');
  WriteLn('  build             Compile the current project based on the aether.json manifest');
  WriteLn('  run               Compile and immediately run the project binary');
  WriteLn('  test [filter]     Run unit tests (--target=pascal|c|all, --both)');
  WriteLn('  bench [filter]    Run benchmark suite (--compare to compare backends)');
  WriteLn('  profile <file>    Run profiling and memory audit (--runs=N, --json)');
  WriteLn('  lint [path]       Run static code quality analysis (--fix for auto-fix)');
  WriteLn('  fmt [path]        Format Aether code according to canonical rules (--check for CI/CD)');
  WriteLn('  doc [path]        Generate canonical project documentation (HTML, Markdown, and Doctests)');
  WriteLn('  emit-header <file> Generate ANSI C/C++-compatible C header (.h)');
  WriteLn('  upgrade           Upgrade the Aether compiler toolchain (--check, --binary, --from-source, --rollback)');
  WriteLn('  clean             Clean project build artifacts (bin/ and generated/)');
  WriteLn('  bootstrap         Run full self-hosting cycle (Stage 1, 2, and 3)');
  WriteLn('');
  WriteLn('Code Emission and Inspection Commands (BlaiseVue Integration):');
  WriteLn('  emit <pascal|c|wasm|runtime> [file] [options]');
  WriteLn('                    Emit transpiled code, Wasm binary, or shared runtime unit');
  WriteLn('    --unit          Generate in Free Pascal Unit format (unit/interface/implementation)');
  WriteLn('    --shared-runtime Generate/use shared uAetherRuntime.pas with --unit (BlaiseVue)');
  WriteLn('    --manifest      Generate .wasm.json export manifest alongside .wasm');
  WriteLn('    --out-dir=<dir> Specify the destination directory for generated files (-d)');
  WriteLn('    --stdout        Print the code directly to the console without saving to disk');
  WriteLn('    --silent, -s    Silent headless mode for external tooling and pipelines');
  WriteLn('    --watch, -w     Watch source file for changes and regenerate automatically');
  WriteLn('    -o <file>       Specify the exact output file name');
  WriteLn('');
  WriteLn('Project and Package Management Commands:');
  WriteLn(
      '  new [name | .]    Create a new project (in a new folder or the current directory)'
  );
  WriteLn(
      '  pkg <subcommand>  Package manager (add, remove, update, publish, search, audit, list, clean)'
  );
  WriteLn('  publish           Publish the current package to the official Aether Registry (--dry-run)');
  WriteLn('  search <query>    Search community packages available in the Registry');
  WriteLn('  test [filter]     Run unit tests from the tests/ directory (--target=all)');
  WriteLn(
      '  build             Compile the current project based on the aether.json manifest'
  );
  WriteLn(
      '  run               Compile and immediately run the project binary'
  );
  WriteLn(
      '  lsp               Start the language server (Language Server Protocol)'
  );
  WriteLn('');
  WriteLn('Subcommands of "aetherc pkg":');
  WriteLn('  pkg add <package>    Add a dependency to the project (Git, Local, or Registry)');
  WriteLn('  pkg add-sys <lib>    Install via MSYS2 pacman / verify via pkg-config & register');
  WriteLn('  pkg add-fpc <pkg>    Install via fppkg / locate FPC/OPM units & register');
  WriteLn('  pkg remove <package> Remove a dependency from aether.json and clean caches (rm)');
  WriteLn('  pkg update [package] Update Git dependencies and synchronize the lockfile (upgrade)');
  WriteLn('  pkg audit            Inspect cryptographic integrity and TLS security');
  WriteLn('  pkg list             Display the list of declared project dependencies (ls)');
  WriteLn('  pkg clean            Clean the global package cache (~/.aether/cache)');
  WriteLn('');
  WriteLn('Main Options:');
  WriteLn('  --doctor          Verify and diagnose the environment (FPC, GCC, Clang, and Pas2JS)');
  WriteLn('  --target=pascal   Compile generating Object Pascal and invoke FPC (Default)');
  WriteLn('  --target=c        Compile generating C99 and invoke GCC or Clang');
  WriteLn('  --target=wasm     Compile generating WebAssembly binary (.wasm) via Clang');
  WriteLn('  --target=js       Compile generating JavaScript (.js) via Pas2JS');
  WriteLn('  --cc=<gcc|clang>  Select the native C compiler (default: gcc)');
  WriteLn('  --backend=<name>  Override the target toolchain (e.g., clang, pas2js)');
  WriteLn('  --html            Generate minimal HTML wrapper to test .wasm or .js in the browser');
  WriteLn('  --check-only      Run syntax, type, and borrow checker analysis only');
  WriteLn('  --incremental     Enable incremental compilation based on SHA-256 hashes');
  WriteLn('  --force           Force full recompilation ignoring the object cache');
  WriteLn('  --release         Release mode: optimize AST and enable -O3, DCE, and symbol stripping');
  WriteLn('  --opt, -O         Enable AST optimizer (Constant Folding and Dead Code Elimination)');
  WriteLn('  --dump-tokens     Display the Lexer token list');
  WriteLn('  --dump-ast        Display the Abstract Syntax Tree (AST)');
  WriteLn(

'  --emit-json-diag  Generate error diagnostic report in JSON format for AI'
  );
  WriteLn(

 '  --lsp             Start the language server (Language Server Protocol)'
  );
  WriteLn('  -o <file.exe>     Specify the output executable file name');
  WriteLn('  -FE <dir>         Set output directory for final executables');
  WriteLn('  -FU <dir>         Set output directory for compiled FPC units (.ppu/.o)');
  WriteLn('  --out-pascal <dir> Set directory where generated .pas sources are written');
  WriteLn('  --out-c <dir>     Set directory where generated .c sources are written');
  WriteLn('  --unit            Emit/compile code as a Pascal Unit (unit... interface... implementation... end.)');
  WriteLn('  -I <dir>          Add search directory for Aether modules and C headers');
  WriteLn('  -Fu <dir>         Add search directory for Free Pascal units (.pas/.ppu)');
  WriteLn('  -L <dir>          Add search directory for native libraries (.a/.lib)');
  WriteLn('  -l <lib>          Link with a C/system library (e.g., -lraylib, -lsqlite3)');
  WriteLn('  --c-source <.c>   Compile an additional C file into the final executable');
  WriteLn('  --shared-lib <.dll> Copy shared library (.dll/.so) to the executable directory');
  WriteLn('  --sys-lib=<lib>   Resolve native C library via pkg-config and bundle MSYS2 DLLs');
  WriteLn('  --fpc-pkg=<pkg>   Include Free Pascal package units (fppkg / Lazarus OPM)');
  WriteLn('  --bundle-dlls     Auto-copy transitive MSYS2 DLLs next to exe (default on Windows)');
  WriteLn('  --no-bundle-dlls  Disable automatic MSYS2 DLL bundling');
  WriteLn('  -V, --version     Display compiler version and host platform');
  WriteLn('  -h, --help        Display this help message');
End;

Function LoadFileContent(Const FileName: String): string;

Var 
  FileStream: TFileStream;
  StringStream: TStringStream;
Begin
  If Not FileExists(FileName) Then
    raise Exception.CreateFmt('File not found: "%s"', [FileName]);

  FileStream := TFileStream.Create(FileName, fmOpenRead Or fmShareDenyWrite);
  StringStream := TStringStream.Create('');
  Try
    StringStream.CopyFrom(FileStream, FileStream.Size);
    Result := StringStream.DataString;
  Finally
    StringStream.Free;
    FileStream.Free;
End;
End;

Procedure DumpTokens(Const SourceFile: String);

Var 
  Source: string;
  Lexer: TAetherLexer;
  Tok: TToken;
  Count: Integer;
Begin
  Source := LoadFileContent(SourceFile);
  Lexer := TAetherLexer.Create(Source);
  Try
    WriteLn(Format('--- Lexical Analysis (Tokens) of: %s ---', [SourceFile]));
    Count := 0;
    Repeat
      Tok := Lexer.NextToken;
      Inc(Count);
      WriteLn(Format('[Line %3d, Col %3d] %-16s : "%s"',
              [Tok.Line, Tok.Col, TokenKindToString(Tok.Kind), Tok.Value]));
    Until Tok.Kind = tokEOF;
    WriteLn(Format('Total tokens analyzed: %d', [Count]));
  Finally
    Lexer.Free;
End;
End;

Function ExtractLastSegment(Const S: String): string;

Var 
  I: Integer;
Begin
  For I := Length(S) Downto 1 Do
    If S[I] = '.' Then
      Exit(Copy(S, I + 1, Length(S)));
  Result := S;
End;

Function CamelToSnake(Const S: String): string;

Var 
  I: Integer;
Begin
  Result := '';
  For I := 1 To Length(S) Do
    Begin
      If (S[I] In ['A'..'Z']) And (I > 1) And (S[I - 1] <> '.') And (S[I - 1] <>
         '_') And (S[I - 1] <> '/') And (S[I - 1] <> '\') Then
        Result := Result + '_' + LowerCase(S[I])
      Else
        Result := Result + LowerCase(S[I]);
    End;
End;

Var
  GlobalIncludePaths: TStringList = nil;
  GlobalPascalUnitPaths: TStringList = nil;
  GlobalCSources: TStringList = nil;
  GlobalLibDirs: TStringList = nil;
  GlobalLibs: TStringList = nil;
  GlobalSharedLibs: TStringList = nil;
  GlobalExtraCFlags: TStringList = nil;
  GlobalSystemLibs: TStringList = nil;
  GlobalPascalPackages: TStringList = nil;
  GlobalBundleDlls: Boolean = True;
  GlobalOutBinDir: string = '';
  GlobalOutPascalSrcDir: string = '';
  GlobalOutPascalUnitDir: string = '';
  GlobalOutCSrcDir: string = '';
  GlobalAsUnit: Boolean = False;
  GlobalCCompiler: string = 'gcc';
  GlobalTargetKind: string = 'pascal';
  GlobalBackendOverride: string = '';
  GlobalEmitHtmlWrapper: Boolean = False;
  GlobalOptionSharedLib: Boolean = False;
  GlobalEmitHeader: Boolean = False;
  GlobalSharedRuntime: Boolean = False;
  GlobalSourceFileDisplay: string = '';
  GlobalLineOffset: Integer = 0;
  GlobalEmitWasmManifest: Boolean = False;

Procedure InitGlobalPaths;
Begin
  If GlobalIncludePaths = nil Then GlobalIncludePaths := TStringList.Create;
  If GlobalPascalUnitPaths = nil Then GlobalPascalUnitPaths := TStringList.Create;
  If GlobalCSources = nil Then GlobalCSources := TStringList.Create;
  If GlobalLibDirs = nil Then GlobalLibDirs := TStringList.Create;
  If GlobalLibs = nil Then GlobalLibs := TStringList.Create;
  If GlobalSharedLibs = nil Then GlobalSharedLibs := TStringList.Create;
  If GlobalExtraCFlags = nil Then GlobalExtraCFlags := TStringList.Create;
  If GlobalSystemLibs = nil Then GlobalSystemLibs := TStringList.Create;
  If GlobalPascalPackages = nil Then GlobalPascalPackages := TStringList.Create;
End;

Procedure FreeGlobalPaths;
Begin
  FreeAndNil(GlobalIncludePaths);
  FreeAndNil(GlobalPascalUnitPaths);
  FreeAndNil(GlobalCSources);
  FreeAndNil(GlobalLibDirs);
  FreeAndNil(GlobalLibs);
  FreeAndNil(GlobalSharedLibs);
  FreeAndNil(GlobalExtraCFlags);
  FreeAndNil(GlobalSystemLibs);
  FreeAndNil(GlobalPascalPackages);
End;

Function ParsePathFlag(Const Arg: String; Var I: Integer): Boolean;
Var
  Val: string;
Begin
  Result := True;
  InitGlobalPaths;
  If (Arg = '-I') Then
  Begin
    Inc(I);
    If I <= ParamCount Then GlobalIncludePaths.Add(ParamStr(I));
  End
  Else If (Copy(Arg, 1, 2) = '-I') And (Length(Arg) > 2) Then
  Begin
    Val := Copy(Arg, 3, Length(Arg));
    If (Length(Val) > 0) And (Val[1] = '=') Then Val := Copy(Val, 2, Length(Val));
    GlobalIncludePaths.Add(Val);
  End
  Else If (Arg = '-Fu') Then
  Begin
    Inc(I);
    If I <= ParamCount Then GlobalPascalUnitPaths.Add(ParamStr(I));
  End
  Else If (Copy(Arg, 1, 3) = '-Fu') And (Length(Arg) > 3) Then
  Begin
    Val := Copy(Arg, 4, Length(Arg));
    If (Length(Val) > 0) And (Val[1] = '=') Then Val := Copy(Val, 2, Length(Val));
    GlobalPascalUnitPaths.Add(Val);
  End
  Else If (Arg = '-FU') Then
  Begin
    Inc(I);
    If I <= ParamCount Then GlobalOutPascalUnitDir := ParamStr(I);
  End
  Else If (Copy(Arg, 1, 3) = '-FU') And (Length(Arg) > 3) Then
  Begin
    Val := Copy(Arg, 4, Length(Arg));
    If (Length(Val) > 0) And (Val[1] = '=') Then Val := Copy(Val, 2, Length(Val));
    GlobalOutPascalUnitDir := Val;
  End
  Else If (Arg = '-FE') Then
  Begin
    Inc(I);
    If I <= ParamCount Then GlobalOutBinDir := ParamStr(I);
  End
  Else If (Copy(Arg, 1, 3) = '-FE') And (Length(Arg) > 3) Then
  Begin
    Val := Copy(Arg, 4, Length(Arg));
    If (Length(Val) > 0) And (Val[1] = '=') Then Val := Copy(Val, 2, Length(Val));
    GlobalOutBinDir := Val;
  End
  Else If (Arg = '-L') Then
  Begin
    Inc(I);
    If I <= ParamCount Then GlobalLibDirs.Add(ParamStr(I));
  End
  Else If (Copy(Arg, 1, 2) = '-L') And (Length(Arg) > 2) Then
  Begin
    Val := Copy(Arg, 3, Length(Arg));
    If (Length(Val) > 0) And (Val[1] = '=') Then Val := Copy(Val, 2, Length(Val));
    GlobalLibDirs.Add(Val);
  End
  Else If (Arg = '-l') Then
  Begin
    Inc(I);
    If I <= ParamCount Then GlobalLibs.Add(ParamStr(I));
  End
  Else If (Copy(Arg, 1, 2) = '-l') And (Length(Arg) > 2) Then
  Begin
    Val := Copy(Arg, 3, Length(Arg));
    If (Length(Val) > 0) And (Val[1] = '=') Then Val := Copy(Val, 2, Length(Val));
    GlobalLibs.Add(Val);
  End
  Else If (Arg = '--c-source') Then
  Begin
    Inc(I);
    If I <= ParamCount Then GlobalCSources.Add(ParamStr(I));
  End
  Else If Pos('--c-source=', Arg) = 1 Then
  Begin
    GlobalCSources.Add(Copy(Arg, 12, Length(Arg)));
  End
  Else If (Arg = '--shared-lib') Then
  Begin
    Inc(I);
    If I <= ParamCount Then GlobalSharedLibs.Add(ParamStr(I));
  End
  Else If Pos('--shared-lib=', Arg) = 1 Then
  Begin
    GlobalSharedLibs.Add(Copy(Arg, 14, Length(Arg)));
  End
  Else If (Arg = '--out-pascal') Then
  Begin
    Inc(I);
    If I <= ParamCount Then GlobalOutPascalSrcDir := ParamStr(I);
  End
  Else If Pos('--out-pascal=', Arg) = 1 Then
  Begin
    GlobalOutPascalSrcDir := Copy(Arg, 14, Length(Arg));
  End
  Else If (Arg = '--out-c') Then
  Begin
    Inc(I);
    If I <= ParamCount Then GlobalOutCSrcDir := ParamStr(I);
  End
  Else If Pos('--out-c=', Arg) = 1 Then
  Begin
    GlobalOutCSrcDir := Copy(Arg, 9, Length(Arg));
  End
  Else If (Arg = '--unit') Then
  Begin
    GlobalAsUnit := True;
  End
  Else If (Arg = '--html') Then
  Begin
    GlobalEmitHtmlWrapper := True;
  End
  Else If Pos('--cc=', Arg) = 1 Then
  Begin
    GlobalCCompiler := Copy(Arg, 6, Length(Arg));
  End
  Else If Pos('--c-compiler=', Arg) = 1 Then
  Begin
    GlobalCCompiler := Copy(Arg, 14, Length(Arg));
  End
  Else If Pos('--backend=', Arg) = 1 Then
  Begin
    GlobalBackendOverride := Copy(Arg, 11, Length(Arg));
  End
  Else If Arg = '--target=wasm' Then
  Begin
    GlobalTargetKind := 'wasm';
  End
  Else If Arg = '--target=js' Then
  Begin
    GlobalTargetKind := 'js';
  End
  Else If Arg = '--target=c' Then
  Begin
    GlobalTargetKind := 'c';
  End
  Else If Arg = '--target=pascal' Then
  Begin
    GlobalTargetKind := 'pascal';
  End
  Else If (Arg = '--sys-lib') Then
  Begin
    Inc(I);
    If I <= ParamCount Then GlobalSystemLibs.Add(ParamStr(I));
  End
  Else If Pos('--sys-lib=', Arg) = 1 Then
  Begin
    GlobalSystemLibs.Add(Copy(Arg, 11, Length(Arg)));
  End
  Else If (Arg = '--fpc-pkg') Then
  Begin
    Inc(I);
    If I <= ParamCount Then GlobalPascalPackages.Add(ParamStr(I));
  End
  Else If Pos('--fpc-pkg=', Arg) = 1 Then
  Begin
    GlobalPascalPackages.Add(Copy(Arg, 11, Length(Arg)));
  End
  Else If (Arg = '--bundle-dlls') Then
  Begin
    GlobalBundleDlls := True;
  End
  Else If (Arg = '--no-bundle-dlls') Then
  Begin
    GlobalBundleDlls := False;
  End
  Else If (Arg = '--shared-runtime') Then
  Begin
    GlobalSharedRuntime := True;
  End
  Else If (Arg = '--wasm-manifest') Or (Arg = '--manifest') Then
  Begin
    GlobalEmitWasmManifest := True;
  End
  Else If (Arg = '--source-file') And (I + 1 <= ParamCount) Then
  Begin
    Inc(I);
    GlobalSourceFileDisplay := ParamStr(I);
  End
  Else If Pos('--source-file=', Arg) = 1 Then
  Begin
    GlobalSourceFileDisplay := Copy(Arg, 15, Length(Arg));
  End
  Else If (Arg = '--line-offset') And (I + 1 <= ParamCount) Then
  Begin
    Inc(I);
    GlobalLineOffset := StrToIntDef(ParamStr(I), 0);
  End
  Else If Pos('--line-offset=', Arg) = 1 Then
  Begin
    GlobalLineOffset := StrToIntDef(Copy(Arg, 15, Length(Arg)), 0);
  End
  Else
    Result := False;
End;

Function FindModuleFile(Const ModName, BaseDir: String): string;

Var 
  Candidate: string;
  ExeDir, StdDir, CacheDir, DepDir: string;
  RelPath, RelPathLower, RelPathSnake: string;
  CleanRelPath, CleanRelPathLower, CleanRelPathSnake: string;
  ProjConfig: TAetherProjectConfig;
  I: Integer;
Begin
  Result := '';
  RelPath := StringReplace(ModName, '.', PathDelim, [rfReplaceAll]);
  RelPathLower := LowerCase(RelPath);
  RelPathSnake := StringReplace(CamelToSnake(ModName), '.', PathDelim, [
                  rfReplaceAll]);

  CleanRelPath := RelPath;
  CleanRelPathLower := RelPathLower;
  CleanRelPathSnake := RelPathSnake;
  if (Pos('std' + PathDelim, RelPathLower) = 1) then
  begin
    CleanRelPath := Copy(RelPath, 5, Length(RelPath) - 4);
    CleanRelPathLower := Copy(RelPathLower, 5, Length(RelPathLower) - 4);
    CleanRelPathSnake := Copy(RelPathSnake, 5, Length(RelPathSnake) - 4);
  end;

  // 1. Source file directory
  Candidate := BaseDir + RelPath + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := BaseDir + RelPathLower + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := BaseDir + RelPathSnake + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);

  // 1b. Custom include directories (-I and paths.aether)
  If Assigned(GlobalIncludePaths) Then
  Begin
    For I := 0 To GlobalIncludePaths.Count - 1 Do
    Begin
      Candidate := IncludeTrailingPathDelimiter(GlobalIncludePaths[I]) + RelPath + '.aeth';
      If FileExists(Candidate) Then Exit(Candidate);
      Candidate := IncludeTrailingPathDelimiter(GlobalIncludePaths[I]) + RelPathLower + '.aeth';
      If FileExists(Candidate) Then Exit(Candidate);
      Candidate := IncludeTrailingPathDelimiter(GlobalIncludePaths[I]) + RelPathSnake + '.aeth';
      If FileExists(Candidate) Then Exit(Candidate);
    End;
  End;

  // 2. std/ subfolder relative to source file directory
  Candidate := BaseDir + 'std' + PathDelim + CleanRelPath + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := BaseDir + 'std' + PathDelim + CleanRelPathLower + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := BaseDir + 'std' + PathDelim + CleanRelPathSnake + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);

  // 3. std/ subfolder relative to compiler (bin/../std)
  ExeDir := ExtractFilePath(ParamStr(0));
  StdDir := ExpandFileName(ExeDir + '..' + PathDelim + 'std');
  Candidate := StdDir + PathDelim + CleanRelPath + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := StdDir + PathDelim + CleanRelPathLower + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := StdDir + PathDelim + CleanRelPathSnake + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);

  // 4. Current working directory (cwd)
  Candidate := GetCurrentDir + PathDelim + RelPath + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := GetCurrentDir + PathDelim + RelPathLower + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := GetCurrentDir + PathDelim + RelPathSnake + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := GetCurrentDir + PathDelim + 'std' + PathDelim + CleanRelPath + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := GetCurrentDir + PathDelim + 'std' + PathDelim + CleanRelPathLower + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);
  Candidate := GetCurrentDir + PathDelim + 'std' + PathDelim + CleanRelPathSnake + '.aeth';
  If FileExists(Candidate) Then Exit(Candidate);



// 5. Current project dependencies (aether.json) and Global Cache (~/.aether/cache)
  If LoadProjectConfig(ProjConfig) Then
    Begin
      For I := 0 To High(ProjConfig.Dependencies) Do
        Begin
          If ProjConfig.Dependencies[I].Path <> '' Then
            DepDir := ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig
                      .Dependencies[I].Path)
          Else
            DepDir := ExpandFileName(ProjConfig.RootDir + PathDelim + '.aether'
                      + PathDelim + 'deps' + PathDelim + ProjConfig.Dependencies
                      [I].Name);

          Candidate := DepDir + PathDelim + RelPath + '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);
          Candidate := DepDir + PathDelim + 'src' + PathDelim + RelPath +
                       '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);
          Candidate := DepDir + PathDelim + RelPathLower + '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);
          Candidate := DepDir + PathDelim + 'src' + PathDelim + RelPathLower +
                       '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);
          Candidate := DepDir + PathDelim + RelPathSnake + '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);
          Candidate := DepDir + PathDelim + 'src' + PathDelim + RelPathSnake +
                       '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);

          // Global cache (~/.aether/cache/<pkg>)
          CacheDir := GetAetherCacheDir + PathDelim + ProjConfig.Dependencies[I]
                      .Name;
          Candidate := CacheDir + PathDelim + RelPath + '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);
          Candidate := CacheDir + PathDelim + 'src' + PathDelim + RelPath +
                       '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);
          Candidate := CacheDir + PathDelim + RelPathLower + '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);
          Candidate := CacheDir + PathDelim + 'src' + PathDelim + RelPathLower +
                       '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);
          Candidate := CacheDir + PathDelim + RelPathSnake + '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);
          Candidate := CacheDir + PathDelim + 'src' + PathDelim + RelPathSnake +
                       '.aeth';
          If FileExists(Candidate) Then Exit(Candidate);
        End;
    End;
End;

Procedure CollectModuleImports(TargetMod: TASTModule; Const BaseDir: String;
                               Visited: TStringList; AllTypes, AllTraits,
                               AllImpls, AllFuncs: TFPList; PascalImports:
                               TStringList; DependencyFiles: TStrings = nil;
                               AllConsts: TFPList = nil;
                               AllModVars: TFPList = nil;
                               InitProcs: TStringList = nil;
                               FiniProcs: TStringList = nil);

Var 
  I, J, K: Integer;
  ModName, ModPath, ModSource: string;
  SubLexer: TAetherLexer;
  SubParser: TAetherParser;
  SubMod: TASTModule;
  RecDecl: TASTRecordDecl;
  ImplDecl: TASTImplDecl;
  SynProc: TASTFunction;
  ExpectedName, LastSegment: string;
Begin
  For I := 0 To TargetMod.Imports.Count - 1 Do
    Begin
      ModName := TargetMod.Imports[I];
      If Visited.IndexOf(LowerCase(ModName)) >= 0 Then Continue;

      ModPath := FindModuleFile(ModName, BaseDir);
      If ModPath = '' Then
        raise Exception.CreateFmt(

'Aether module "%s" not found. Check if the file exists or is located in "std/".'
                                  , [ModName]);

      If Assigned(DependencyFiles) And (DependencyFiles.IndexOf(ExpandFileName(ModPath)) < 0) Then
        DependencyFiles.Add(ExpandFileName(ModPath));

      If Visited.IndexOf(LowerCase(ModPath)) >= 0 Then Continue;
      Visited.Add(LowerCase(ModName));
      Visited.Add(LowerCase(ModPath));
      Visited.Add(LowerCase(ExtractLastSegment(ModName)));

      ModSource := LoadFileContent(ModPath);
      SubLexer := TAetherLexer.Create(ModSource);
      SubParser := TAetherParser.Create(SubLexer);
      Try
        SubMod := SubParser.ParseModule;
        ApplyCfgToModule(SubMod, GetCurrentOSName, 'pascal', False);
        Try
          CollectModuleImports(SubMod, ExtractFilePath(ModPath), Visited,
          AllTypes, AllTraits, AllImpls, AllFuncs, PascalImports, DependencyFiles,
          AllConsts, AllModVars, InitProcs, FiniProcs);

          // Strict 1:1 Validation of Imported Modules (Phase 13)
          ExpectedName := ModName;
          LastSegment := ExtractLastSegment(ExpectedName);
          If Not SameText(SubMod.Name, ExpectedName) And Not SameText(SubMod.
             Name, LastSegment) Then
            raise Exception.CreateFmt(

'[Module Error E0005 at %s]: Declared module name "%s" differs from expected "%s". In Aether, the module name must match the file name.'
                                      , [ExtractFileName(ModPath), SubMod.Name,
            ExpectedName]);

          For J := 0 To SubMod.PascalImports.Count - 1 Do
            If PascalImports.IndexOf(SubMod.PascalImports[J]) < 0 Then
              PascalImports.Add(SubMod.PascalImports[J]);
          For J := 0 To SubMod.CImports.Count - 1 Do
            If TargetMod.CImports.IndexOf(SubMod.CImports[J]) < 0 Then
              TargetMod.CImports.Add(SubMod.CImports[J]);
          For J := 0 To SubMod.LinkDirectives.Count - 1 Do
            If TargetMod.LinkDirectives.IndexOf(SubMod.LinkDirectives[J]) < 0 Then
              TargetMod.LinkDirectives.Add(SubMod.LinkDirectives[J]);

          // Visibility (Phase 54.1 / 57.2): if the module uses pub/priv explicitly (or is a Unit),
          // declarations without a modifier are private to the module.
          If SubMod.HasExplicitPub Then
          Begin
            For J := 0 To SubMod.Constants.Count - 1 Do
              If Not SubMod.Constants[J].HasExplicitVis Then SubMod.Constants[J].IsPublic := False;
            For J := 0 To SubMod.ModuleVars.Count - 1 Do
              If Not SubMod.ModuleVars[J].HasExplicitVis Then SubMod.ModuleVars[J].IsPublic := False;
            For J := 0 To SubMod.Types.Count - 1 Do
              If Not SubMod.Types[J].HasExplicitVis Then SubMod.Types[J].IsPublic := False;
            For J := 0 To SubMod.Traits.Count - 1 Do
              If Not SubMod.Traits[J].HasExplicitVis Then SubMod.Traits[J].IsPublic := False;
            For J := 0 To SubMod.Functions.Count - 1 Do
              If Not SubMod.Functions[J].HasExplicitVis Then SubMod.Functions[J].IsPublic := False;
          End;

          For J := 0 To SubMod.Constants.Count - 1 Do
            If SubMod.Constants[J].SourceModule = '' Then
              SubMod.Constants[J].SourceModule := SubMod.Name;
          For J := 0 To SubMod.ModuleVars.Count - 1 Do
            If SubMod.ModuleVars[J].SourceModule = '' Then
              SubMod.ModuleVars[J].SourceModule := SubMod.Name;
          For J := 0 To SubMod.Types.Count - 1 Do
          Begin
            If SubMod.Types[J].SourceModule = '' Then
              SubMod.Types[J].SourceModule := SubMod.Name;
            If SubMod.Types[J] is TASTRecordDecl Then
            Begin
              RecDecl := TASTRecordDecl(SubMod.Types[J]);
              For K := 0 To RecDecl.Fields.Count - 1 Do
                If RecDecl.Fields[K].SourceModule = '' Then
                  RecDecl.Fields[K].SourceModule := SubMod.Name;
            End;
          End;
          For J := 0 To SubMod.Traits.Count - 1 Do
            If SubMod.Traits[J].SourceModule = '' Then
              SubMod.Traits[J].SourceModule := SubMod.Name;
          For J := 0 To SubMod.Impls.Count - 1 Do
          Begin
            ImplDecl := TASTImplDecl(SubMod.Impls[J]);
            If ImplDecl.SourceModule = '' Then
              ImplDecl.SourceModule := SubMod.Name;
            For K := 0 To ImplDecl.Methods.Count - 1 Do
              If ImplDecl.Methods[K].SourceModule = '' Then
                ImplDecl.Methods[K].SourceModule := SubMod.Name;
          End;
          For J := 0 To SubMod.Functions.Count - 1 Do
            If SubMod.Functions[J].SourceModule = '' Then
              SubMod.Functions[J].SourceModule := SubMod.Name;

          If Assigned(AllConsts) Then
            While SubMod.Constants.Count > 0 Do
              AllConsts.Add(SubMod.Constants.Extract(SubMod.Constants[0]));

          If Assigned(AllModVars) Then
            While SubMod.ModuleVars.Count > 0 Do
              AllModVars.Add(SubMod.ModuleVars.Extract(SubMod.ModuleVars[0]));

          While SubMod.Types.Count > 0 Do
            AllTypes.Add(SubMod.Types.Extract(SubMod.Types[0]));

          While SubMod.Traits.Count > 0 Do
            AllTraits.Add(SubMod.Traits.Extract(SubMod.Traits[0]));

          While SubMod.Impls.Count > 0 Do
            AllImpls.Add(SubMod.Impls.Extract(SubMod.Impls[0]));

          While SubMod.Functions.Count > 0 Do
            AllFuncs.Add(SubMod.Functions.Extract(SubMod.Functions[0]));

          If SubMod.InitBody.Count > 0 Then
          Begin
            SynProc := TASTFunction.Create(SubMod.Line, SubMod.Col, '_aether_init_' + SubMod.Name, 'Void');
            SynProc.IsProcedure := True;
            SynProc.IsPublic := True;
            SynProc.HasExplicitVis := True;
            SynProc.SourceModule := SubMod.Name;
            While SubMod.InitBody.Count > 0 Do
              SynProc.Body.Add(SubMod.InitBody.Extract(SubMod.InitBody[0]));
            AllFuncs.Add(SynProc);
            If Assigned(InitProcs) Then
              InitProcs.Add(SynProc.Name);
          End;

          If SubMod.FiniBody.Count > 0 Then
          Begin
            SynProc := TASTFunction.Create(SubMod.Line, SubMod.Col, '_aether_fini_' + SubMod.Name, 'Void');
            SynProc.IsProcedure := True;
            SynProc.IsPublic := True;
            SynProc.HasExplicitVis := True;
            SynProc.SourceModule := SubMod.Name;
            While SubMod.FiniBody.Count > 0 Do
              SynProc.Body.Add(SubMod.FiniBody.Extract(SubMod.FiniBody[0]));
            AllFuncs.Add(SynProc);
            If Assigned(FiniProcs) Then
              FiniProcs.Add(SynProc.Name);
          End;
        Finally
          SubMod.Free;
    End;
Finally
  SubParser.Free;
  SubLexer.Free;
End;
End;
End;

Procedure ResolveModuleImports(TargetMod: TASTModule; Const BaseDir: String;
                               Visited: TStringList; DependencyFiles: TStrings = nil);

Var 
  AllConsts, AllModVars, AllTypes, AllTraits, AllImpls, AllFuncs: TFPList;
  InitList, FiniList: TStringList;
  I: Integer;
Begin
  AllConsts := TFPList.Create;
  AllModVars := TFPList.Create;
  AllTypes := TFPList.Create;
  AllTraits := TFPList.Create;
  AllImpls := TFPList.Create;
  AllFuncs := TFPList.Create;
  InitList := TStringList.Create;
  FiniList := TStringList.Create;
  Try
    CollectModuleImports(TargetMod, BaseDir, Visited, AllTypes, AllTraits,
                         AllImpls, AllFuncs, TargetMod.PascalImports, DependencyFiles,
                         AllConsts, AllModVars, InitList, FiniList);
    For I := AllConsts.Count - 1 Downto 0 Do
      TargetMod.Constants.Insert(0, TASTNode(AllConsts[I]));
    For I := AllModVars.Count - 1 Downto 0 Do
      TargetMod.ModuleVars.Insert(0, TASTNode(AllModVars[I]));
    For I := AllTypes.Count - 1 Downto 0 Do
      TargetMod.Types.Insert(0, TASTNode(AllTypes[I]));
    For I := AllTraits.Count - 1 Downto 0 Do
      TargetMod.Traits.Insert(0, TASTNode(AllTraits[I]));
    For I := AllImpls.Count - 1 Downto 0 Do
      TargetMod.Impls.Insert(0, TASTNode(AllImpls[I]));
    For I := AllFuncs.Count - 1 Downto 0 Do
      TargetMod.Functions.Insert(0, TASTFunction(AllFuncs[I]));
    For I := 0 To InitList.Count - 1 Do
      TargetMod.InitProcs.Add(InitList[I]);
    For I := 0 To FiniList.Count - 1 Do
      TargetMod.FiniProcs.Add(FiniList[I]);
  Finally
    AllConsts.Free;
    AllModVars.Free;
    AllTypes.Free;
    AllTraits.Free;
    AllImpls.Free;
    AllFuncs.Free;
    InitList.Free;
    FiniList.Free;
End;
End;

Procedure AddUniqueLprStr(List: TStrings; Const Val: String);
Var
  T: string;
  I: Integer;
Begin
  If Not Assigned(List) Then Exit;
  T := Trim(Val);
  If T = '' Then Exit;
  For I := 0 To List.Count - 1 Do
    If SameText(List[I], T) Then Exit;
  List.Add(T);
End;

Function NormalizeExternLibName(Const RawLib: String): String;
Var
  Base, LowBase: string;
  P, K: Integer;
Begin
  Base := ExtractFileName(Trim(RawLib));
  LowBase := LowerCase(Base);
  For P := 1 To 4 Do
  Begin
    If (Length(LowBase) > 4) And (Copy(LowBase, Length(LowBase) - 3, 4) = '.dll') Then
      Base := Copy(Base, 1, Length(Base) - 4)
    Else If (Length(LowBase) > 3) And (Copy(LowBase, Length(LowBase) - 2, 3) = '.so') Then
      Base := Copy(Base, 1, Length(Base) - 3)
    Else If (Length(LowBase) > 6) And (Copy(LowBase, Length(LowBase) - 5, 6) = '.dylib') Then
      Base := Copy(Base, 1, Length(Base) - 6)
    Else If (Length(LowBase) > 2) And (Copy(LowBase, Length(LowBase) - 1, 2) = '.a') Then
      Base := Copy(Base, 1, Length(Base) - 2)
    Else
      Break;
    LowBase := LowerCase(Base);
  End;
  If (Length(Base) > 3) And (Pos('lib', LowerCase(Base)) = 1) And (LowerCase(Trim(RawLib)) <> LowerCase(Base)) Then
  Begin
    // Only strip "lib" prefix when an archive/shared extension was stripped (e.g. libsqlite3-0.dll -> sqlite3)
    Delete(Base, 1, 3);
    K := Pos('-', Base);
    If (K > 1) And (K < Length(Base)) And (Base[K + 1] In ['0'..'9']) Then
      Base := Copy(Base, 1, K - 1);
  End;
  Result := Trim(Base);
End;

Procedure WriteRuntimeUnitIfNeeded(Const DestDir: String; Silent: Boolean);
Var
  RuntimePath, Content, Existing: string;
  SL: TStringList;
Begin
  If DestDir <> '' Then ForceDirectories(DestDir);
  RuntimePath := IncludeTrailingPathDelimiter(DestDir) + 'uAetherRuntime.pas';
  Content := TAetherEmitterPascal.GenerateRuntimeUnit;
  Existing := '';
  If FileExists(RuntimePath) Then
  Begin
    SL := TStringList.Create;
    Try
      SL.LoadFromFile(RuntimePath);
      Existing := SL.Text;
    Finally
      SL.Free;
    End;
  End;
  If (Not FileExists(RuntimePath)) Or (Existing <> Content) Then
  Begin
    SL := TStringList.Create;
    Try
      SL.Text := Content;
      SL.SaveToFile(RuntimePath);
      If Not Silent Then
        WriteLn('  --> ' + RuntimePath + ' (Shared Runtime Unit)');
    Finally
      SL.Free;
    End;
  End;
End;

Procedure SaveWasmManifestToFile(ModuleNode: TASTModule; Const WasmFilePath, ManifestPath: String);
Var
  Lines: TStringList;
  I, J, ExportIdx, ExportTotal: Integer;
  Func: TASTFunction;
  Param: TASTParam;
  RetTypeStr: string;
Begin
  Lines := TStringList.Create;
  Try
    Lines.Add('{');
    Lines.Add('  "schema_version": "1.0",');
    Lines.Add(Format('  "module": "%s",', [EscapeJSONString(ModuleNode.Name)]));
    Lines.Add(Format('  "wasm_file": "%s",', [EscapeJSONString(ExtractFileName(WasmFilePath))]));
    Lines.Add('  "exports": [');

    ExportTotal := 0;
    For I := 0 To ModuleNode.Functions.Count - 1 Do
    Begin
      Func := TASTFunction(ModuleNode.Functions[I]);
      If (Func.SourceModule = '') And (Not Func.IsExtern) And
         (Func.GenericParams.Count = 0) And (Func.GenericParam = '') And
         (Func.IsExport Or Func.IsPublic Or ModuleNode.IsUnit) Then
        Inc(ExportTotal);
    End;

    ExportIdx := 0;
    For I := 0 To ModuleNode.Functions.Count - 1 Do
    Begin
      Func := TASTFunction(ModuleNode.Functions[I]);
      If (Func.SourceModule = '') And (Not Func.IsExtern) And
         (Func.GenericParams.Count = 0) And (Func.GenericParam = '') And
         (Func.IsExport Or Func.IsPublic Or ModuleNode.IsUnit) Then
      Begin
        Inc(ExportIdx);
        If Func.IsProcedure Or (Func.ReturnType = '') Then
          RetTypeStr := 'Void'
        Else
          RetTypeStr := Func.ReturnType;
        Lines.Add('    {');
        Lines.Add(Format('      "name": "%s",', [EscapeJSONString(Func.Name)]));
        If Func.IsProcedure Then
          Lines.Add('      "is_procedure": true,')
        Else
          Lines.Add('      "is_procedure": false,');
        Lines.Add(Format('      "return_type": "%s",', [EscapeJSONString(RetTypeStr)]));
        Lines.Add('      "params": [');
        For J := 0 To Func.Params.Count - 1 Do
        Begin
          Param := TASTParam(Func.Params[J]);
          If J < Func.Params.Count - 1 Then
            Lines.Add(Format('        { "name": "%s", "type": "%s" },', [EscapeJSONString(Param.Name), EscapeJSONString(Param.TypeName)]))
          Else
            Lines.Add(Format('        { "name": "%s", "type": "%s" }', [EscapeJSONString(Param.Name), EscapeJSONString(Param.TypeName)]));
        End;
        Lines.Add('      ]');
        If ExportIdx < ExportTotal Then
          Lines.Add('    },')
        Else
          Lines.Add('    }');
      End;
    End;

    Lines.Add('  ]');
    Lines.Add('}');
    If ExtractFileDir(ManifestPath) <> '' Then
      ForceDirectories(ExtractFileDir(ManifestPath));
    Lines.SaveToFile(ManifestPath);
  Finally
    Lines.Free;
  End;
End;

Function IsBuiltinCrtOrOsLib(Const NormLib: String): Boolean;
Var
  LowLib: string;
Begin
  LowLib := LowerCase(Trim(NormLib));
  Result := (LowLib = '') Or (LowLib = 'msvcrt') Or (LowLib = 'c') Or (LowLib = 'libc') Or
            (LowLib = 'm') Or (LowLib = 'ws2_32') Or (LowLib = 'kernel32') Or
            (LowLib = 'user32') Or (LowLib = 'gdi32') Or (LowLib = 'advapi32') Or
            (LowLib = 'shell32') Or (LowLib = 'ole32') Or (LowLib = 'pthread');
End;

Procedure CompileFile(Const SourceFile: String; Const TargetMode: String; CheckOnly
                      , DumpASTOnly: Boolean; Const OutputExeName: String;
                      SilentBanner: Boolean; Incremental: Boolean = False;
                      ForceRebuild: Boolean = False; ReleaseMode: Boolean = False;
                      RunOptimizer: Boolean = False; Const BackendChoice: String = '';
                      Const CCompilerChoice: String = ''; AsLibrary: Boolean = False;
                      EmitHeader: Boolean = False);

Var 
  Source: string;
  Lexer: TAetherLexer;
  Parser: TAetherParser;
  TypeChecker: TAetherTypeChecker;
  BorrowChecker: TAetherBorrowChecker;
  Optimizer: TAetherOptimizer;
  ModuleNode: TASTModule;
  GenDir, IntermediateFile, FinalExe: string;
  BaseProjDir, Dummy, TargetBackendStr, CachePath: string;
  GeneratedCode: string;
  EmitterPas: TAetherEmitterPascal;
  EmitterC: TAetherEmitterC;
  Success: Boolean;
  CompileLog: string;
  CodeFile: TStringList;
  Visited: TStringList;
  DependencyFiles: TStringList;
  FileBase, CleanBase, CleanMod: string;
  P, I: Integer;
  BuildCache: TAetherBuildCache;
  CacheUpToDate: Boolean;
  CacheItem: PFileCacheItem;
  EffectiveTarget, EffectiveCComp, EffectiveBackend: string;
  EffIncludes, EffExtraCFlags, EffLibDirs, EffLibs, EffPasUnits, EffDllNames, AutoSysLibs: TStringList;
  TCInfo: TToolchainInfo;
  HasTCInfo: Boolean;
  SysLibName, NormLib, ResolveErr, ResolveHint, MsysLibDir: string;
Begin
  ModuleNode := nil;
  DependencyFiles := nil;
  EffIncludes := nil;
  EffExtraCFlags := nil;
  EffLibDirs := nil;
  EffLibs := nil;
  EffPasUnits := nil;
  EffDllNames := nil;
  AutoSysLibs := nil;
  HasTCInfo := False;

  If TargetMode <> '' Then
    EffectiveTarget := LowerCase(TargetMode)
  Else
    EffectiveTarget := 'pascal';

  If (LowerCase(BackendChoice) = 'gcc') Or (LowerCase(BackendChoice) = 'clang') Then
    EffectiveCComp := LowerCase(BackendChoice)
  Else If CCompilerChoice <> '' Then
    EffectiveCComp := LowerCase(CCompilerChoice)
  Else
    EffectiveCComp := LowerCase(GlobalCCompiler);

  If BackendChoice <> '' Then
    EffectiveBackend := LowerCase(BackendChoice)
  Else
    EffectiveBackend := LowerCase(GlobalBackendOverride);

  // Determine BaseProjDir and FinalExe upfront for incremental check
  If Not FindProjectRoot(BaseProjDir, Dummy) Then
    BaseProjDir := GetCurrentDir;
  BaseProjDir := ExcludeTrailingPathDelimiter(BaseProjDir);

  If ReleaseMode Then
    TargetBackendStr := EffectiveTarget + '-release'
  Else
    TargetBackendStr := EffectiveTarget;

  If OutputExeName <> '' Then
    FinalExe := OutputExeName
  Else If GlobalOutBinDir <> '' Then
  Begin
    If EffectiveTarget = 'wasm' Then
      FinalExe := IncludeTrailingPathDelimiter(GlobalOutBinDir) + ChangeFileExt(ExtractFileName(SourceFile), '.wasm')
    Else If EffectiveTarget = 'js' Then
      FinalExe := IncludeTrailingPathDelimiter(GlobalOutBinDir) + ChangeFileExt(ExtractFileName(SourceFile), '.js')
    Else
      FinalExe := IncludeTrailingPathDelimiter(GlobalOutBinDir) + ChangeFileExt(ExtractFileName(SourceFile), '.exe');
  End
  Else
  Begin
    If EffectiveTarget = 'wasm' Then
      FinalExe := BaseProjDir + PathDelim + 'bin' + PathDelim + ChangeFileExt(ExtractFileName(SourceFile), '.wasm')
    Else If EffectiveTarget = 'js' Then
      FinalExe := BaseProjDir + PathDelim + 'bin' + PathDelim + ChangeFileExt(ExtractFileName(SourceFile), '.js')
    Else
      FinalExe := BaseProjDir + PathDelim + 'bin' + PathDelim + ChangeFileExt(ExtractFileName(SourceFile), '.exe');
  End;

  If AsLibrary Or GlobalOptionSharedLib Then
  Begin
    {$IFDEF MSWINDOWS}
    If LowerCase(ExtractFileExt(FinalExe)) <> '.dll' Then
      FinalExe := ChangeFileExt(FinalExe, '.dll');
    {$ELSE}
    If (LowerCase(ExtractFileExt(FinalExe)) <> '.so') and (LowerCase(ExtractFileExt(FinalExe)) <> '.dylib') Then
      FinalExe := ExtractFileDir(FinalExe) + PathDelim + 'lib' + ChangeFileExt(ExtractFileName(FinalExe), '.so');
    {$ENDIF}
  End;

  // Early incremental cache check (0 ms rebuild)
  If Incremental And (Not ForceRebuild) And (Not CheckOnly) And (Not DumpASTOnly) And FileExists(FinalExe) Then
  Begin
    CachePath := GetBuildCachePath(BaseProjDir, SourceFile, TargetBackendStr);
    If FileExists(CachePath) Then
    Begin
      BuildCache := TAetherBuildCache.Create;
      Try
        If BuildCache.LoadFromFile(CachePath) Then
        Begin
          CacheUpToDate := True;
          For I := 0 To BuildCache.Files.Count - 1 Do
          Begin
            CacheItem := PFileCacheItem(BuildCache.Files[I]);
            If (Not FileExists(CacheItem^.Path)) Or (SHA256File(CacheItem^.Path) <> CacheItem^.Hash) Then
            Begin
              CacheUpToDate := False;
              Break;
            End;
          End;

          If CacheUpToDate And FileExists(FinalExe) And (SHA256File(FinalExe) = BuildCache.OutputExeHash) Then
          Begin
            CopySharedLibraries(BaseProjDir, FinalExe, GlobalSharedLibs);
            If GlobalBundleDlls Then
              BundleMSYS2Dlls(FinalExe, DetectToolchain, SilentBanner, nil);
            If Not SilentBanner Then
            Begin
              WriteLn(Format('[INCREMENTAL] No changes detected in "%s" or its %d dependencies.', [ExtractFileName(SourceFile), BuildCache.Files.Count - 1]));
              WriteLn(Format('[INCREMENTAL] Reusing cached executable: "%s"', [FinalExe]));
            End;
            Exit;
          End;
        End;
      Finally
        BuildCache.Free;
      End;
    End;
  End;

  Source := LoadFileContent(SourceFile);
  Lexer := TAetherLexer.Create(Source, 1 + GlobalLineOffset);
  Parser := TAetherParser.Create(Lexer);
  Try
    ModuleNode := Parser.ParseModule;
    // Cross-Platform Conditional Compilation (@cfg) - Phase 40
    ApplyCfgToModule(ModuleNode, GetCurrentOSName, EffectiveTarget, ReleaseMode);

    // Strict 1:1 Module Validation in root file (Phase 13)
    FileBase := ChangeFileExt(ExtractFileName(SourceFile), '');
    CleanBase := FileBase;
    P := 1;
    While (P <= Length(CleanBase)) And (CleanBase[P] In ['0'..'9', '_']) Do
      Inc(P);
    If P <= Length(CleanBase) Then
      CleanBase := Copy(CleanBase, P, Length(CleanBase));
    CleanBase := StringReplace(CleanBase, '_', '', [rfReplaceAll]);
    CleanMod := StringReplace(ModuleNode.Name, '_', '', [rfReplaceAll]);

    If (GlobalSourceFileDisplay = '') And
       (Not SameText(FileBase, ModuleNode.Name)) And
       (Not SameText(CleanBase, CleanMod)) Then
      raise Exception.CreateFmt(

'[Module Error E0005 at %s]: Declared module name "%s" differs from file name "%s.aeth". In Aether, the module name must match the file name.'
                                , [ExtractFileName(SourceFile), ModuleNode.Name,
      FileBase]);

    DependencyFiles := TStringList.Create;
    DependencyFiles.Add(ExpandFileName(SourceFile));
    Visited := TStringList.Create;
    Try
      ResolveModuleImports(ModuleNode, ExtractFilePath(ExpandFileName(
                           SourceFile)), Visited, DependencyFiles);
    Finally
      Visited.Free;
    End;
If DumpASTOnly Then
  Begin
    WriteLn(Format('--- Abstract Syntax Tree (AST) of: %s ---', [SourceFile
            ]));
    WriteLn(ModuleNode.Dump(0));
    Exit;
  End;

If Not SilentBanner Then
  WriteLn(Format('[1/4] Syntax Analysis of "%s": OK', [ExtractFileName(
          SourceFile)]));

// 2. Type Checking and Semantics
TypeChecker := TAetherTypeChecker.Create;
Try
  TypeChecker.CheckModule(ModuleNode);
  If Not SilentBanner Then
    WriteLn('[2/4] Type Checking: OK (0 errors)');

  // 3. Ownership Verification (Borrow Checker)
  BorrowChecker := TAetherBorrowChecker.Create(TypeChecker.Symbols);
  Try
    BorrowChecker.CheckModule(ModuleNode);
    If Not SilentBanner Then
      WriteLn('[3/4] Ownership Check (Borrow Checker): OK (0 errors)');
  Finally
    BorrowChecker.Free;
End;
Finally
  TypeChecker.Free;
End;

If CheckOnly Then
  Begin
    If Not SilentBanner Then
      WriteLn('--check-only mode completed successfully.');
    Exit;
  End;

// 3.5 AST Optimizations (Constant Folding & Dead Code Elimination)
If RunOptimizer Or ReleaseMode Then
Begin
  Optimizer := TAetherOptimizer.Create;
  Try
    If Optimizer.OptimizeModule(ModuleNode) And (Not SilentBanner) Then
    Begin
      WriteLn(Format('      [OPTIMIZER] AST optimized: %d constants folded, %d identities simplified, %d dead branches, and %d unreachable statements eliminated.',
        [Optimizer.Stats.FoldedConstants, Optimizer.Stats.SimplifiedIdentities,
         Optimizer.Stats.EliminatedDeadBranches, Optimizer.Stats.EliminatedUnreachableStmts]));
    End;
  Finally
    Optimizer.Free;
  End;
End;

// 4. Native Dependency Resolution (pkg-config, MSYS2 DLLs, fppkg/OPM, extern c auto-link)
EffIncludes := TStringList.Create;
EffExtraCFlags := TStringList.Create;
EffLibDirs := TStringList.Create;
EffLibs := TStringList.Create;
EffPasUnits := TStringList.Create;
EffDllNames := TStringList.Create;
AutoSysLibs := TStringList.Create;

If Assigned(GlobalIncludePaths) Then
  For I := 0 To GlobalIncludePaths.Count - 1 Do AddUniqueLprStr(EffIncludes, GlobalIncludePaths[I]);
If Assigned(GlobalExtraCFlags) Then
  For I := 0 To GlobalExtraCFlags.Count - 1 Do AddUniqueLprStr(EffExtraCFlags, GlobalExtraCFlags[I]);
If Assigned(GlobalLibDirs) Then
  For I := 0 To GlobalLibDirs.Count - 1 Do AddUniqueLprStr(EffLibDirs, GlobalLibDirs[I]);
If Assigned(GlobalLibs) Then
  For I := 0 To GlobalLibs.Count - 1 Do AddUniqueLprStr(EffLibs, GlobalLibs[I]);
If Assigned(GlobalPascalUnitPaths) Then
  For I := 0 To GlobalPascalUnitPaths.Count - 1 Do AddUniqueLprStr(EffPasUnits, GlobalPascalUnitPaths[I]);

For I := 0 To ModuleNode.Functions.Count - 1 Do
Begin
  If TASTFunction(ModuleNode.Functions[I]).IsExtern And
     (TASTFunction(ModuleNode.Functions[I]).ExternAbi = 'c') And
     (TASTFunction(ModuleNode.Functions[I]).ExternLib <> '') Then
  Begin
    NormLib := NormalizeExternLibName(TASTFunction(ModuleNode.Functions[I]).ExternLib);
    If Not IsBuiltinCrtOrOsLib(NormLib) Then
      AddUniqueLprStr(AutoSysLibs, NormLib);
  End;
End;
For I := 0 To ModuleNode.LinkDirectives.Count - 1 Do
Begin
  NormLib := NormalizeExternLibName(ModuleNode.LinkDirectives[I]);
  If Not IsBuiltinCrtOrOsLib(NormLib) Then
    AddUniqueLprStr(AutoSysLibs, NormLib);
End;

If ((Assigned(GlobalSystemLibs) And (GlobalSystemLibs.Count > 0)) Or
    (Assigned(GlobalPascalPackages) And (GlobalPascalPackages.Count > 0)) Or
    (AutoSysLibs.Count > 0) Or GlobalBundleDlls) Then
Begin
  TCInfo := DetectToolchain;
  HasTCInfo := True;
End;

// Explicit system_libs / --sys-lib (strict pkg-config resolution)
If Assigned(GlobalSystemLibs) Then
Begin
  For I := 0 To GlobalSystemLibs.Count - 1 Do
  Begin
    SysLibName := Trim(GlobalSystemLibs[I]);
    If SysLibName = '' Then Continue;
    If Not ResolvePkgConfigLib(SysLibName, TCInfo, EffIncludes, EffExtraCFlags, EffLibDirs, EffLibs, ResolveErr, ResolveHint) Then
      raise Exception.Create(ResolveErr + LineEnding + ResolveHint);
    AddUniqueLprStr(EffDllNames, ResolveSystemLibDllName(SysLibName, TCInfo));
  End;
End;

// Auto-link from extern c "<lib>" and import link "<lib>"
For I := 0 To AutoSysLibs.Count - 1 Do
Begin
  SysLibName := AutoSysLibs[I];
  AddUniqueLprStr(EffDllNames, ResolveSystemLibDllName(SysLibName, TCInfo));
  If Not ResolvePkgConfigLib(SysLibName, TCInfo, EffIncludes, EffExtraCFlags, EffLibDirs, EffLibs, ResolveErr, ResolveHint) Then
  Begin
    AddUniqueLprStr(EffLibs, SysLibName);
    {$IFDEF MSWINDOWS}
    If TCInfo.MSYS2BinDir <> '' Then
    Begin
      MsysLibDir := ExtractFileDir(ExcludeTrailingPathDelimiter(TCInfo.MSYS2BinDir)) + PathDelim + 'lib';
      If DirectoryExists(MsysLibDir) Then
        AddUniqueLprStr(EffLibDirs, MsysLibDir);
    End;
    {$ENDIF}
  End;
End;

// Free Pascal packages (fppkg / Lazarus OPM / FPC units)
If (EffectiveTarget = 'pascal') And Assigned(GlobalPascalPackages) And (GlobalPascalPackages.Count > 0) Then
Begin
  For I := 0 To GlobalPascalPackages.Count - 1 Do
  Begin
    SysLibName := Trim(GlobalPascalPackages[I]);
    If SysLibName = '' Then Continue;
    If Not ResolvePascalPackagePaths(SysLibName, TCInfo, EffPasUnits, ResolveErr) Then
      raise Exception.Create(ResolveErr);
  End;
End;

// 5. Code Emission and Executable / Binary Generation
If Not FindProjectRoot(BaseProjDir, Dummy) Then
  BaseProjDir := GetCurrentDir;
BaseProjDir := ExcludeTrailingPathDelimiter(BaseProjDir);

If (EffectiveTarget = 'pascal') Or (EffectiveTarget = 'js') Then
Begin
  If GlobalOutPascalSrcDir <> '' Then
    GenDir := GlobalOutPascalSrcDir
  Else
    GenDir := BaseProjDir + PathDelim + 'generated' + PathDelim + 'pascal';
End
Else
Begin
  If GlobalOutCSrcDir <> '' Then
    GenDir := GlobalOutCSrcDir
  Else
    GenDir := BaseProjDir + PathDelim + 'generated' + PathDelim + 'c';
End;

ForceDirectories(GenDir);
ForceDirectories(ExtractFileDir(FinalExe));

If EffectiveTarget = 'wasm' Then
Begin
  // WebAssembly (.wasm) via Clang
  IntermediateFile := GenDir + PathDelim + ChangeFileExt(ExtractFileName(SourceFile), '.c');
  EmitterC := TAetherEmitterC.Create;
  Try
    GeneratedCode := EmitterC.Generate(ModuleNode);
  Finally
    EmitterC.Free;
  End;

  CodeFile := TStringList.Create;
  Try
    CodeFile.Text := GeneratedCode;
    CodeFile.SaveToFile(IntermediateFile);
  Finally
    CodeFile.Free;
  End;

  If Not SilentBanner Then
  Begin
    WriteLn(Format('[4/4] Transpiling to C99 -> "%s"', [ExtractFileName(IntermediateFile)]));
    If ReleaseMode Then
      WriteLn('      Invoking Clang WebAssembly (wasm32) [RELEASE Mode: -O3 -flto]...')
    Else
      WriteLn('      Invoking Clang WebAssembly (wasm32)...');
  End;

  CompileLog := '';
  Success := CompileWithClangWasm(IntermediateFile, FinalExe, CompileLog, ReleaseMode);
  If Success Then
  Begin
    If Incremental Then
      SaveBuildCache(BaseProjDir, SourceFile, TargetBackendStr, FinalExe, DependencyFiles);
    If GlobalEmitWasmManifest Then
      SaveWasmManifestToFile(ModuleNode, FinalExe, ChangeFileExt(FinalExe, '.wasm.json'));
    If Not SilentBanner Then
    Begin
      WriteLn('');
      WriteLn('SUCCESS! WebAssembly module (.wasm) generated via Clang:');
      WriteLn('  --> ' + FinalExe);
      If GlobalEmitWasmManifest Then
        WriteLn('  --> ' + ChangeFileExt(FinalExe, '.wasm.json') + ' (Wasm Manifest)');
      If GlobalEmitHtmlWrapper Then
      Begin
        GenerateWasmHtmlWrapper(FinalExe, ChangeFileExt(FinalExe, '.html'));
        WriteLn('  --> ' + ChangeFileExt(FinalExe, '.html') + ' (HTML Runner)');
      End;
    End;
  End
  Else
  Begin
    WriteLn(ErrOutput, 'WebAssembly compilation failed with Clang:');
    WriteLn(ErrOutput, CompileLog);
    Halt(1);
  End;
End
Else If EffectiveTarget = 'js' Then
Begin
  // Web JavaScript (.js) via Pas2JS
  IntermediateFile := GenDir + PathDelim + ChangeFileExt(ExtractFileName(SourceFile), '.pas');
  EmitterPas := TAetherEmitterPascal.Create;
  Try
    GeneratedCode := EmitterPas.Generate(ModuleNode, not Assigned(ModuleNode.ProgramBlock));
  Finally
    EmitterPas.Free;
  End;

  CodeFile := TStringList.Create;
  Try
    CodeFile.Text := GeneratedCode;
    CodeFile.SaveToFile(IntermediateFile);
  Finally
    CodeFile.Free;
  End;

  If Not SilentBanner Then
  Begin
    WriteLn(Format('[4/4] Transpiling to Object Pascal -> "%s"', [ExtractFileName(IntermediateFile)]));
    If ReleaseMode Then
      WriteLn('      Invoking Pas2JS [RELEASE Mode: -O1 -Jc]...')
    Else
      WriteLn('      Invoking Pas2JS...');
  End;

  CompileLog := '';
  Success := CompileWithPas2JS(IntermediateFile, FinalExe, CompileLog, ReleaseMode, EffPasUnits);
  If Success Then
  Begin
    If Incremental Then
      SaveBuildCache(BaseProjDir, SourceFile, TargetBackendStr, FinalExe, DependencyFiles);
    If Not SilentBanner Then
    Begin
      WriteLn('');
      WriteLn('SUCCESS! JavaScript script (.js) generated via Pas2JS:');
      WriteLn('  --> ' + FinalExe);
      If GlobalEmitHtmlWrapper Then
      Begin
        GenerateJSHtmlWrapper(FinalExe, ChangeFileExt(FinalExe, '.html'));
        WriteLn('  --> ' + ChangeFileExt(FinalExe, '.html') + ' (HTML Runner)');
      End;
    End;
  End
  Else
  Begin
    WriteLn(ErrOutput, 'JavaScript compilation failed with Pas2JS:');
    WriteLn(ErrOutput, CompileLog);
    Halt(1);
  End;
End
Else If EffectiveTarget = 'c' Then
Begin
  // Target C (GCC or Clang)
  IntermediateFile := GenDir + PathDelim + ChangeFileExt(ExtractFileName(SourceFile), '.c');
  EmitterC := TAetherEmitterC.Create;
  Try
    GeneratedCode := EmitterC.Generate(ModuleNode);
  Finally
    EmitterC.Free;
  End;

  CodeFile := TStringList.Create;
  Try
    CodeFile.Text := GeneratedCode;
    CodeFile.SaveToFile(IntermediateFile);
  Finally
    CodeFile.Free;
  End;

  If Not SilentBanner Then
  Begin
    WriteLn(Format('[4/4] Transpiling to C99 -> "%s"', [ExtractFileName(IntermediateFile)]));
    If EffectiveCComp = 'clang' Then
    Begin
      If ReleaseMode Then
        WriteLn('      Invoking Clang [RELEASE Mode: -O3 -flto -s]...')
      Else
        WriteLn('      Invoking Clang...');
    End
    Else
    Begin
      If ReleaseMode Then
        WriteLn('      Invoking GCC [RELEASE Mode: -O3 -flto -s]...')
      Else
        WriteLn('      Invoking GCC...');
    End;
  End;

  CompileLog := '';
  If EffectiveCComp = 'clang' Then
    Success := CompileWithClang(IntermediateFile, FinalExe, CompileLog, ReleaseMode, EffIncludes, GlobalCSources, EffLibDirs, EffLibs, EffExtraCFlags)
  Else
    Success := CompileWithGCC(IntermediateFile, FinalExe, CompileLog, ReleaseMode, EffIncludes, GlobalCSources, EffLibDirs, EffLibs, EffExtraCFlags);

  If Success Then
  Begin
    CopySharedLibraries(BaseProjDir, FinalExe, GlobalSharedLibs);
    If GlobalBundleDlls And HasTCInfo And (Not AsLibrary) And (Not GlobalOptionSharedLib) Then
      BundleMSYS2Dlls(FinalExe, TCInfo, SilentBanner, EffDllNames);
    If Incremental Then
      SaveBuildCache(BaseProjDir, SourceFile, TargetBackendStr, FinalExe, DependencyFiles);
    If EmitHeader Or GlobalEmitHeader Or AsLibrary Or GlobalOptionSharedLib Then
    Begin
      SaveCHeaderToFile(ModuleNode, ChangeFileExt(FinalExe, '.h'));
      If Not SilentBanner Then
        WriteLn('  --> ' + ChangeFileExt(FinalExe, '.h') + ' (C Header)');
    End;
    If Not SilentBanner Then
    Begin
      WriteLn('');
      If AsLibrary Or GlobalOptionSharedLib Or (LowerCase(ExtractFileExt(FinalExe)) = '.dll') Or (LowerCase(ExtractFileExt(FinalExe)) = '.so') Or (LowerCase(ExtractFileExt(FinalExe)) = '.dylib') Then
      Begin
        If EffectiveCComp = 'clang' Then
          WriteLn('SUCCESS! Native Shared Library generated via Clang:')
        Else
          WriteLn('SUCCESS! Native Shared Library generated via GCC:');
      End
      Else If EffectiveCComp = 'clang' Then
        WriteLn('SUCCESS! Native executable generated via Clang:')
      Else
        WriteLn('SUCCESS! Native executable generated via GCC:');
      WriteLn('  --> ' + FinalExe);
    End;
  End
  Else
  Begin
    If EffectiveCComp = 'clang' Then
      WriteLn(ErrOutput, 'Compilation failed with Clang:')
    Else
      WriteLn(ErrOutput, 'Compilation failed with GCC:');
    WriteLn(ErrOutput, CompileLog);
    Halt(1);
  End;
End
Else
Begin
  // Target Pascal (Free Pascal / FPC)
  IntermediateFile := GenDir + PathDelim + ChangeFileExt(ExtractFileName(SourceFile), '.pas');
  EmitterPas := TAetherEmitterPascal.Create;
  Try
    GeneratedCode := EmitterPas.Generate(ModuleNode, GlobalAsUnit, AsLibrary Or GlobalOptionSharedLib, GlobalSharedRuntime);
  Finally
    EmitterPas.Free;
  End;
  If GlobalAsUnit And GlobalSharedRuntime Then
    WriteRuntimeUnitIfNeeded(GenDir, SilentBanner);

  CodeFile := TStringList.Create;
  Try
    CodeFile.Text := GeneratedCode;
    CodeFile.SaveToFile(IntermediateFile);
  Finally
    CodeFile.Free;
  End;

  If Not SilentBanner Then
  Begin
    WriteLn(Format('[4/4] Transpiling to Object Pascal -> "%s"', [ExtractFileName(IntermediateFile)]));
    If ReleaseMode Then
      WriteLn('      Invoking Free Pascal (fpc) [RELEASE Mode: -O3 -XX -Xs]...')
    Else
      WriteLn('      Invoking Free Pascal (fpc)...');
  End;

  CompileLog := '';
  Success := CompileWithFPC(IntermediateFile, FinalExe, CompileLog, ReleaseMode, EffPasUnits, EffLibDirs, GlobalOutPascalUnitDir, GlobalAsUnit);
  If Success Then
  Begin
    If GlobalAsUnit Then
    Begin
      If Not SilentBanner Then
      Begin
        WriteLn('');
        WriteLn('SUCCESS! Object Pascal Unit compiled successfully:');
        If GlobalOutPascalUnitDir <> '' Then
          WriteLn('  --> Units directory (.ppu/.o): ' + GlobalOutPascalUnitDir)
        Else
          WriteLn('  --> ' + IntermediateFile);
      End;
    End
    Else
    Begin
      CopySharedLibraries(BaseProjDir, FinalExe, GlobalSharedLibs);
      If GlobalBundleDlls And HasTCInfo And (Not AsLibrary) And (Not GlobalOptionSharedLib) Then
        BundleMSYS2Dlls(FinalExe, TCInfo, SilentBanner, EffDllNames);
      If Incremental Then
        SaveBuildCache(BaseProjDir, SourceFile, TargetBackendStr, FinalExe, DependencyFiles);
      If EmitHeader Or GlobalEmitHeader Or AsLibrary Or GlobalOptionSharedLib Then
      Begin
        SaveCHeaderToFile(ModuleNode, ChangeFileExt(FinalExe, '.h'));
        If Not SilentBanner Then
          WriteLn('  --> ' + ChangeFileExt(FinalExe, '.h') + ' (C Header)');
      End;
      If Not SilentBanner Then
      Begin
        WriteLn('');
        If AsLibrary Or GlobalOptionSharedLib Or (LowerCase(ExtractFileExt(FinalExe)) = '.dll') Or (LowerCase(ExtractFileExt(FinalExe)) = '.so') Or (LowerCase(ExtractFileExt(FinalExe)) = '.dylib') Then
          WriteLn('SUCCESS! Native Shared Library generated via Free Pascal:')
        Else
          WriteLn('SUCCESS! Native executable generated:');
        WriteLn('  --> ' + FinalExe);
      End;
    End;
  End
  Else
  Begin
    WriteLn(ErrOutput, 'Compilation failed with FPC:');
    WriteLn(ErrOutput, CompileLog);
    Halt(1);
  End;
End;

Finally
  If Assigned(AutoSysLibs) Then AutoSysLibs.Free;
  If Assigned(EffDllNames) Then EffDllNames.Free;
  If Assigned(EffPasUnits) Then EffPasUnits.Free;
  If Assigned(EffLibs) Then EffLibs.Free;
  If Assigned(EffLibDirs) Then EffLibDirs.Free;
  If Assigned(EffExtraCFlags) Then EffExtraCFlags.Free;
  If Assigned(EffIncludes) Then EffIncludes.Free;
  If Assigned(DependencyFiles) Then DependencyFiles.Free;
  If Assigned(ModuleNode) Then ModuleNode.Free;
  Parser.Free;
  Lexer.Free;
End;
End;

Procedure CompileFile(Const SourceFile: String; TargetPascal: Boolean; CheckOnly
                      , DumpASTOnly: Boolean; Const OutputExeName: String;
                      SilentBanner: Boolean; Incremental: Boolean = False;
                      ForceRebuild: Boolean = False; ReleaseMode: Boolean = False;
                      RunOptimizer: Boolean = False; AsLibrary: Boolean = False;
                      EmitHeader: Boolean = False);
Begin
  If TargetPascal Then
    CompileFile(SourceFile, 'pascal', CheckOnly, DumpASTOnly, OutputExeName, SilentBanner, Incremental, ForceRebuild, ReleaseMode, RunOptimizer, '', '', AsLibrary, EmitHeader)
  Else
    CompileFile(SourceFile, 'c', CheckOnly, DumpASTOnly, OutputExeName, SilentBanner, Incremental, ForceRebuild, ReleaseMode, RunOptimizer, '', '', AsLibrary, EmitHeader);
End;

Procedure EmitFile(Const SourceFile: String; TargetPascal: Boolean; Const CustomOutput: String;
                   Const CustomOutDir: String; AsUnit: Boolean; ToStdout: Boolean; Silent: Boolean;
                   SharedRuntime: Boolean = False);
Var 
  Source: string;
  Lexer: TAetherLexer;
  Parser: TAetherParser;
  TypeChecker: TAetherTypeChecker;
  BorrowChecker: TAetherBorrowChecker;
  ModuleNode: TASTModule;
  BaseProjDir, Dummy, TargetDir, FinalTargetFile: string;
  GeneratedCode: string;
  EmitterPas: TAetherEmitterPascal;
  EmitterC: TAetherEmitterC;
  CodeFile: TStringList;
  Visited: TStringList;
  FileBase, CleanBase, CleanMod, TargetExt, FinalBaseName: string;
  P: Integer;
Begin
  ModuleNode := nil;
  Source := LoadFileContent(SourceFile);
  Lexer := TAetherLexer.Create(Source, 1 + GlobalLineOffset);
  Parser := TAetherParser.Create(Lexer);
  Try
    ModuleNode := Parser.ParseModule;
    TargetExt := 'pascal';
    if not TargetPascal then TargetExt := 'c';
    ApplyCfgToModule(ModuleNode, GetCurrentOSName, TargetExt, False);

    FileBase := ChangeFileExt(ExtractFileName(SourceFile), '');
    CleanBase := FileBase;
    P := 1;
    While (P <= Length(CleanBase)) And (CleanBase[P] In ['0'..'9', '_']) Do
      Inc(P);
    If P <= Length(CleanBase) Then
      CleanBase := Copy(CleanBase, P, Length(CleanBase));
    CleanBase := StringReplace(CleanBase, '_', '', [rfReplaceAll]);
    CleanMod := StringReplace(ModuleNode.Name, '_', '', [rfReplaceAll]);

    If (GlobalSourceFileDisplay = '') And
       (Not SameText(FileBase, ModuleNode.Name)) And
       (Not SameText(CleanBase, CleanMod)) Then
      raise Exception.CreateFmt(
        '[Module Error E0005 at %s]: Declared module name "%s" differs from file name "%s.aeth". In Aether, the module name must match the file name.',
        [ExtractFileName(SourceFile), ModuleNode.Name, FileBase]);

    Visited := TStringList.Create;
    Try
      ResolveModuleImports(ModuleNode, ExtractFilePath(ExpandFileName(SourceFile)), Visited);
    Finally
      Visited.Free;
    End;

    TypeChecker := TAetherTypeChecker.Create;
    Try
      TypeChecker.CheckModule(ModuleNode);
      BorrowChecker := TAetherBorrowChecker.Create(TypeChecker.Symbols);
      Try
        BorrowChecker.CheckModule(ModuleNode);
      Finally
        BorrowChecker.Free;
      End;
    Finally
      TypeChecker.Free;
    End;

    If TargetPascal Then
    Begin
      EmitterPas := TAetherEmitterPascal.Create;
      Try
        GeneratedCode := EmitterPas.Generate(ModuleNode, AsUnit, False, SharedRuntime);
      Finally
        EmitterPas.Free;
      End;
    End
    Else
    Begin
      EmitterC := TAetherEmitterC.Create;
      Try
        GeneratedCode := EmitterC.Generate(ModuleNode);
      Finally
        EmitterC.Free;
      End;
    End;

    If ToStdout Then
    Begin
      Write(GeneratedCode);
      Exit;
    End;

    If TargetPascal Then
    Begin
      If AsUnit Then
        FinalBaseName := ModuleNode.Name
      Else
        FinalBaseName := ExtractFileName(SourceFile);
      TargetExt := '.pas';
    End
    Else
    Begin
      FinalBaseName := ExtractFileName(SourceFile);
      TargetExt := '.c';
    End;

    If CustomOutput <> '' Then
      FinalTargetFile := CustomOutput
    Else If CustomOutDir <> '' Then
    Begin
      TargetDir := ExcludeTrailingPathDelimiter(CustomOutDir);
      ForceDirectories(TargetDir);
      FinalTargetFile := TargetDir + PathDelim + ChangeFileExt(FinalBaseName, TargetExt);
    End
    Else
    Begin
      If Not FindProjectRoot(BaseProjDir, Dummy) Then
        BaseProjDir := GetCurrentDir;
      BaseProjDir := ExcludeTrailingPathDelimiter(BaseProjDir);

      If TargetPascal Then
        TargetDir := BaseProjDir + PathDelim + 'generated' + PathDelim + 'pascal'
      Else
        TargetDir := BaseProjDir + PathDelim + 'generated' + PathDelim + 'c';

      ForceDirectories(TargetDir);
      FinalTargetFile := TargetDir + PathDelim + ChangeFileExt(FinalBaseName, TargetExt);
    End;

    ForceDirectories(ExtractFileDir(FinalTargetFile));
    CodeFile := TStringList.Create;
    Try
      CodeFile.Text := GeneratedCode;
      CodeFile.SaveToFile(FinalTargetFile);
    Finally
      CodeFile.Free;
    End;

    If TargetPascal And AsUnit And SharedRuntime Then
      WriteRuntimeUnitIfNeeded(ExtractFileDir(FinalTargetFile), Silent);

    If Not Silent Then
    Begin
      WriteLn(Format('[1/3] Syntax Analysis of "%s": OK', [ExtractFileName(SourceFile)]));
      WriteLn('[2/3] Type and Ownership Check: OK');
      If TargetPascal Then
      Begin
        If AsUnit Then
          WriteLn('[3/3] Object Pascal Unit (BlaiseVue) emitted successfully:')
        Else
          WriteLn('[3/3] Object Pascal code emitted successfully:');
      End
      Else
        WriteLn('[3/3] C99 code emitted successfully:');
      WriteLn('  --> ' + FinalTargetFile);
    End;
  Finally
    ModuleNode.Free;
    Parser.Free;
    Lexer.Free;
  End;
End;

Procedure WatchEmitFile(Const SourceFile: String; TargetPascal: Boolean; Const CustomOutput: String;
                        Const CustomOutDir: String; AsUnit: Boolean; Silent: Boolean);
Var
  LastAge, NewAge: LongInt;
  TimeStr: string;
Begin
  WriteLn('========================================================');
  WriteLn('  Aether File Watcher (Hot-Reload / BlaiseVue Ready)    ');
  WriteLn('========================================================');
  WriteLn(Format('Watching for changes in: "%s"', [SourceFile]));
  WriteLn('Press Ctrl+C to stop.');
  WriteLn('');

  // 1. Initial execution
  Try
    EmitFile(SourceFile, TargetPascal, CustomOutput, CustomOutDir, AsUnit, False, Silent);
  Except
    on E: Exception Do
      WriteLn(ErrOutput, 'Initial compilation error: ', E.Message);
  End;

  LastAge := FileAge(SourceFile);
  While True Do
  Begin
    Sleep(250);
    NewAge := FileAge(SourceFile);
    If (NewAge <> -1) And (NewAge <> LastAge) Then
    Begin
      LastAge := NewAge;
      DateTimeToString(TimeStr, 'hh:nn:ss', Now);
      WriteLn(Format('[%s] [WATCH] Change detected in "%s"...', [TimeStr, ExtractFileName(SourceFile)]));
      Try
        EmitFile(SourceFile, TargetPascal, CustomOutput, CustomOutDir, AsUnit, False, Silent);
        WriteLn('      [OK] File regenerated successfully!');
      Except
        on E: Exception Do
          WriteLn(ErrOutput, Format('      [ERROR] %s', [E.Message]));
      End;
      WriteLn('');
    End;
  End;
End;

Function NormalizeTestRelPath(Const S: String): string;
Begin
  Result := StringReplace(S, '\', '/', [rfReplaceAll]);
End;

Function EndsWithLower(Const S, Suffix: String): Boolean;
Var
  LS, LSuf: string;
Begin
  LS := LowerCase(S);
  LSuf := LowerCase(Suffix);
  If Length(LS) < Length(LSuf) Then
    Exit(False);
  Result := Copy(LS, Length(LS) - Length(LSuf) + 1, Length(LSuf)) = LSuf;
End;

Function IsExcludedTestDir(Const DirName: String): Boolean;
Var
  LowName: string;
Begin
  LowName := LowerCase(DirName);
  Result := (LowName = '.') Or (LowName = '..') Or
            (LowName = 'fixtures') Or (LowName = 'lib') Or
            (LowName = 'tooling') Or (LowName = 'bin') Or
            (LowName = 'generated') Or (LowName = '.aether') Or
            (LowName = 'docs') Or (LowName = 'benches') Or
            (LowName = '.git');
End;

Function IsMatchingTestFile(Const FileName: String; AtTestsRoot: Boolean): Boolean;
Var
  LowName: string;
Begin
  LowName := LowerCase(FileName);
  If Not EndsWithLower(LowName, '.aeth') Then
    Exit(False);
  Result := EndsWithLower(LowName, '_test.aeth') Or
            EndsWithLower(LowName, '_fail.aeth') Or
            (AtTestsRoot And (Pos('test', LowName) > 0));
End;

Procedure CollectTestFiles(Const RootDir, CurrentDir, FilterLower: String;
                           AtRoot: Boolean; OutFiles: TStringList);
Var
  SearchRec: TSearchRec;
  FullPath, RelPath: string;
Begin
  // Collect matching test files in the current directory
  If FindFirst(IncludeTrailingPathDelimiter(CurrentDir) + '*.aeth', faAnyFile, SearchRec) = 0 Then
  Begin
    Try
      Repeat
        If (SearchRec.Attr And faDirectory) = 0 Then
        Begin
          If IsMatchingTestFile(SearchRec.Name, AtRoot) Then
          Begin
            FullPath := IncludeTrailingPathDelimiter(CurrentDir) + SearchRec.Name;
            If Length(FullPath) > Length(IncludeTrailingPathDelimiter(RootDir)) Then
              RelPath := Copy(FullPath, Length(IncludeTrailingPathDelimiter(RootDir)) + 1, Length(FullPath))
            Else
              RelPath := SearchRec.Name;
            RelPath := NormalizeTestRelPath(RelPath);
            If (FilterLower = '') Or (Pos(FilterLower, LowerCase(RelPath)) > 0) Then
              OutFiles.Add(FullPath);
          End;
        End;
      Until FindNext(SearchRec) <> 0;
    Finally
      FindClose(SearchRec);
    End;
  End;

  // Recurse into non-excluded subdirectories
  If FindFirst(IncludeTrailingPathDelimiter(CurrentDir) + '*', faDirectory, SearchRec) = 0 Then
  Begin
    Try
      Repeat
        If ((SearchRec.Attr And faDirectory) <> 0) And (Not IsExcludedTestDir(SearchRec.Name)) Then
          CollectTestFiles(RootDir, IncludeTrailingPathDelimiter(CurrentDir) + SearchRec.Name,
                           FilterLower, False, OutFiles);
      Until FindNext(SearchRec) <> 0;
    Finally
      FindClose(SearchRec);
    End;
  End;
End;

Procedure ExtractExpectedErrors(Const FilePath: String; Expected: TStringList);
Var
  Lines: TStringList;
  I: Integer;
  Trimmed, Sub: string;
Begin
  Lines := TStringList.Create;
  Try
    Lines.LoadFromFile(FilePath);
    For I := 0 To Lines.Count - 1 Do
    Begin
      Trimmed := Trim(Lines[I]);
      If LowerCase(Copy(Trimmed, 1, 16)) = '// expect-error:' Then
      Begin
        Sub := Trim(Copy(Trimmed, 17, Length(Trimmed)));
        If Sub <> '' Then
          Expected.Add(Sub);
      End;
    End;
  Finally
    Lines.Free;
  End;
End;

Function HandleProjectTest(Const Filter: String; TargetPascal: Boolean;
                           Out OutPassed, OutFailed, OutTotal: Integer): Boolean;
Var
  ProjConfig: TAetherProjectConfig;
  TestsDir, RootBase, TestFile, TestExe, BaseDir, RelDisplay: string;
  TestFiles, ExpectedErrs: TStringList;
  I, J, ExitCode: Integer;
  PassedCount, FailedCount: Integer;
  StartTime, ElapsedTime: TDateTime;
  ElapsedMs: Int64;
  BackendName, FilterNorm, MissingSubstr: string;
  HasConfig, IsCompileFail, AllMatched: Boolean;
Begin
  OutPassed := 0;
  OutFailed := 0;
  OutTotal := 0;
  Result := False;

  InitGlobalPaths;
  HasConfig := LoadProjectConfig(ProjConfig);
  If HasConfig Then
  Begin
    RestoreProjectDependencies(ProjConfig);
    BaseDir := ProjConfig.RootDir;
    For I := 0 To High(ProjConfig.PathsAether) Do
      If ProjConfig.PathsAether[I] <> '' Then
        GlobalIncludePaths.Add(ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.PathsAether[I]));
    For I := 0 To High(ProjConfig.PathsCIncludes) Do
      If ProjConfig.PathsCIncludes[I] <> '' Then
        GlobalIncludePaths.Add(ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.PathsCIncludes[I]));
    For I := 0 To High(ProjConfig.PathsCSources) Do
      If ProjConfig.PathsCSources[I] <> '' Then
        GlobalCSources.Add(ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.PathsCSources[I]));
    For I := 0 To High(ProjConfig.PathsPascalUnits) Do
      If ProjConfig.PathsPascalUnits[I] <> '' Then
        GlobalPascalUnitPaths.Add(ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.PathsPascalUnits[I]));
    For I := 0 To High(ProjConfig.PathsLibDirs) Do
      If ProjConfig.PathsLibDirs[I] <> '' Then
        GlobalLibDirs.Add(ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.PathsLibDirs[I]));
    For I := 0 To High(ProjConfig.PathsLibs) Do
      If ProjConfig.PathsLibs[I] <> '' Then
        AddUniqueLprStr(GlobalLibs, ProjConfig.PathsLibs[I]);
    For I := 0 To High(ProjConfig.PathsSharedLibs) Do
      If ProjConfig.PathsSharedLibs[I] <> '' Then
        AddUniqueLprStr(GlobalSharedLibs, ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.PathsSharedLibs[I]));
    For I := 0 To High(ProjConfig.SystemLibs) Do
      AddUniqueLprStr(GlobalSystemLibs, ProjConfig.SystemLibs[I]);
    For I := 0 To High(ProjConfig.PascalPackages) Do
      AddUniqueLprStr(GlobalPascalPackages, ProjConfig.PascalPackages[I]);
    If Not ProjConfig.BundleDlls Then
      GlobalBundleDlls := False;
    CollectTransitiveNativeDeps(ProjConfig, GlobalSystemLibs, GlobalPascalPackages,
                                GlobalIncludePaths, GlobalIncludePaths, GlobalCSources,
                                GlobalPascalUnitPaths, GlobalLibDirs, GlobalLibs, GlobalSharedLibs);
  End
  Else
    BaseDir := GetCurrentDir;

  TestsDir := BaseDir + PathDelim + 'tests';
  If Not DirectoryExists(TestsDir) Then
    TestsDir := BaseDir;
  If DirectoryExists(TestsDir) And (GlobalIncludePaths.IndexOf(TestsDir) < 0) Then
    GlobalIncludePaths.Add(TestsDir);

  TestFiles := TStringList.Create;
  Try
    FilterNorm := LowerCase(NormalizeTestRelPath(Filter));

    // 1. If the filter is a directly existing file
    If (Filter <> '') And FileExists(Filter) Then
    Begin
      TestFiles.Add(ExpandFileName(Filter));
    End
    Else If (Filter <> '') And DirectoryExists(Filter) Then
    Begin
      RootBase := ExpandFileName(Filter);
      CollectTestFiles(RootBase, RootBase, '', True, TestFiles);
    End
    Else
    Begin
      CollectTestFiles(TestsDir, TestsDir, FilterNorm, True, TestFiles);
    End;

    TestFiles.Sort;

    If TestFiles.Count = 0 Then
    Begin
      If Filter <> '' Then
        WriteLn(Format('No tests found matching filter "%s".', [Filter]))
      Else
        WriteLn('No test files (*_test.aeth / *_fail.aeth) found in the "tests/" directory.');
      Exit(False);
    End;

    If TargetPascal Then
      BackendName := 'Free Pascal'
    Else
      BackendName := 'GCC C99';

    WriteLn('========================================================');
    WriteLn('  Aether Test Runner - Unit Test Suite                  ');
    WriteLn('  Backend: ' + BackendName);
    WriteLn('========================================================');

    PassedCount := 0;
    FailedCount := 0;

    For I := 0 To TestFiles.Count - 1 Do
    Begin
      TestFile := TestFiles[I];
      If Pos(LowerCase(IncludeTrailingPathDelimiter(TestsDir)), LowerCase(TestFile)) = 1 Then
        RelDisplay := NormalizeTestRelPath(Copy(TestFile, Length(IncludeTrailingPathDelimiter(TestsDir)) + 1, Length(TestFile)))
      Else
        RelDisplay := ExtractFileName(TestFile);

      IsCompileFail := EndsWithLower(TestFile, '_fail.aeth') Or
                       (Pos('compile_fail/', LowerCase(RelDisplay)) > 0);

      If IsCompileFail Then
      Begin
        Write(Format('  [COMPILE-FAIL] %s ... ', [RelDisplay]));
        ExpectedErrs := TStringList.Create;
        Try
          ExtractExpectedErrors(TestFile, ExpectedErrs);
          StartTime := Now;
          Try
            CompileFile(TestFile, TargetPascal, True, False, '', True);
            Inc(FailedCount);
            WriteLn('FAIL! (Unexpectedly compiled without error)');
          Except
            on E: Exception Do
            Begin
              ElapsedTime := Now - StartTime;
              ElapsedMs := Round(ElapsedTime * 86400 * 1000);
              AllMatched := True;
              MissingSubstr := '';
              For J := 0 To ExpectedErrs.Count - 1 Do
              Begin
                If Pos(LowerCase(ExpectedErrs[J]), LowerCase(E.Message)) = 0 Then
                Begin
                  AllMatched := False;
                  MissingSubstr := ExpectedErrs[J];
                  Break;
                End;
              End;

              If AllMatched Then
              Begin
                Inc(PassedCount);
                WriteLn(Format('PASS (expected error, %d ms)', [ElapsedMs]));
              End
              Else
              Begin
                Inc(FailedCount);
                WriteLn(Format('FAIL! (Expected error "%s", got: %s)', [MissingSubstr, E.Message]));
              End;
            End;
          End;
        Finally
          ExpectedErrs.Free;
        End;
      End
      Else
      Begin
        TestExe := BaseDir + PathDelim + 'bin' + PathDelim + 'tests'
                   + PathDelim + ChangeFileExt(ExtractFileName(TestFile), '.exe');
        ForceDirectories(ExtractFileDir(TestExe));

        Write(Format('  [TEST] %s ... ', [RelDisplay]));

        Try
          CompileFile(TestFile, TargetPascal, False, False, TestExe, True);

          StartTime := Now;
          ExitCode := ExecuteProcess(TestExe, '');
          ElapsedTime := Now - StartTime;
          ElapsedMs := Round(ElapsedTime * 86400 * 1000);

          If ExitCode = 0 Then
          Begin
            Inc(PassedCount);
            WriteLn(Format('PASS (%d ms)', [ElapsedMs]));
          End
          Else
          Begin
            Inc(FailedCount);
            WriteLn(Format('FAIL! (ExitCode: %d)', [ExitCode]));
          End;
        Except
          on E: Exception Do
          Begin
            Inc(FailedCount);
            WriteLn('COMPILATION ERROR: ' + E.Message);
          End;
        End;
      End;
    End;

    WriteLn('--------------------------------------------------------');
    WriteLn(Format('  Results: %d run | %d passed | %d failed', [
            TestFiles.Count, PassedCount, FailedCount]));
    WriteLn('========================================================');

    OutPassed := PassedCount;
    OutFailed := FailedCount;
    OutTotal := TestFiles.Count;
    Result := (FailedCount = 0) And (TestFiles.Count > 0);
  Finally
    TestFiles.Free;
  End;
End;

Procedure HandleFmtCommand;
Var
  I: Integer;
  Arg, TargetPath: string;
  CheckOnly: Boolean;
  TotalFiles, FormattedFiles: Integer;
  IsClean: Boolean;
Begin
  TargetPath := '.';
  CheckOnly := False;
  I := 2;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);
    If Arg = '--check' Then
      CheckOnly := True
    Else If (Length(Arg) > 0) And (Arg[1] <> '-') Then
      TargetPath := Arg;
    Inc(I);
  End;

  WriteLn('========================================================');
  WriteLn('  Aether Code Formatter (aetherc fmt)                   ');
  If CheckOnly Then
    WriteLn('  Mode: Check (--check)')
  Else
    WriteLn('  Mode: Auto-format');
  WriteLn('========================================================');

  TotalFiles := 0;
  FormattedFiles := 0;

  If FileExists(TargetPath) Then
  Begin
    TotalFiles := 1;
    IsClean := TAetherFormatter.FormatFile(TargetPath, CheckOnly);
    If Not IsClean Then
    Begin
      FormattedFiles := 1;
      If CheckOnly Then
        WriteLn(Format('  [UNFORMATTED] %s needs formatting.', [TargetPath]))
      Else
        WriteLn(Format('  [FORMATTED] %s', [TargetPath]));
    End
    Else
      WriteLn(Format('  [OK] %s is already properly formatted.', [TargetPath]));
  End
  Else If DirectoryExists(TargetPath) Then
  Begin
    TAetherFormatter.FormatDirectory(TargetPath, TotalFiles, FormattedFiles, CheckOnly);
  End
  Else
  Begin
    WriteLn(ErrOutput, Format('Error: File or directory "%s" not found.', [TargetPath]));
    Halt(1);
  End;

  WriteLn('--------------------------------------------------------');
  If CheckOnly Then
  Begin
    If FormattedFiles > 0 Then
    Begin
      WriteLn(Format('  FAIL: %d of %d files need formatting.', [FormattedFiles, TotalFiles]));
      WriteLn('  Run "aetherc fmt" to format them automatically.');
      WriteLn('========================================================');
      Halt(1);
    End
    Else
    Begin
      WriteLn(Format('  SUCCESS: All %d files are properly formatted!', [TotalFiles]));
      WriteLn('========================================================');
      Halt(0);
    End;
  End
  Else
  Begin
    WriteLn(Format('  Done: %d files checked | %d formatted.', [TotalFiles, FormattedFiles]));
    WriteLn('========================================================');
    Halt(0);
  End;
End;

Procedure HandleLintCommand;
Var
  I, J: Integer;
  Arg, TargetPath: string;
  OptionFix, OptionJSON: Boolean;
  TotalFiles, CleanFiles, IssueFiles, TotalIssues, TotalFixed: Integer;
  SingleRes: TLintResult;
  ResArray: TLintArrayResult;
Begin
  TargetPath := '.';
  OptionFix := False;
  OptionJSON := False;
  I := 2;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);
    If (Arg = '--fix') Or (Arg = '-f') Then
      OptionFix := True
    Else If (Arg = '--json') Or (Arg = '--format=json') Then
      OptionJSON := True
    Else If (Length(Arg) > 0) And (Arg[1] <> '-') Then
      TargetPath := Arg;
    Inc(I);
  End;

  If Not OptionJSON Then
  Begin
    WriteLn('========================================================');
    WriteLn('  Aether Linter & Code Quality (aetherc lint)           ');
    If OptionFix Then
      WriteLn('  Mode: Analysis with auto-fix (--fix)')
    Else
      WriteLn('  Mode: Static quality analysis');
    WriteLn('========================================================');
  End;

  TotalFiles := 0;
  CleanFiles := 0;
  IssueFiles := 0;
  TotalIssues := 0;
  TotalFixed := 0;
  SetLength(ResArray, 0);

  If FileExists(TargetPath) Then
  Begin
    TotalFiles := 1;
    SingleRes := TAetherLinter.LintFile(TargetPath, OptionFix);
    SetLength(ResArray, 1);
    ResArray[0] := SingleRes;
    TotalIssues := SingleRes.IssueCount;
    TotalFixed := SingleRes.FixedCount;
    If TotalIssues = 0 Then CleanFiles := 1 Else IssueFiles := 1;
  End
  Else If DirectoryExists(TargetPath) Then
  Begin
    TAetherLinter.LintDirectory(TargetPath, OptionFix, TotalFiles, CleanFiles, IssueFiles, TotalIssues, TotalFixed, ResArray);
  End
  Else
  Begin
    WriteLn(ErrOutput, Format('Error: File or directory "%s" not found.', [TargetPath]));
    Halt(1);
  End;

  If OptionJSON Then
  Begin
    WriteLn(TAetherLinter.FormatJSON(ResArray));
    If TotalIssues > 0 Then Halt(1) Else Halt(0);
  End;

  // Formatted terminal output
  For I := 0 To High(ResArray) Do
  Begin
    For J := 0 To ResArray[I].IssueCount - 1 Do
    Begin
      WriteLn(TAetherLinter.FormatIssue(ResArray[I].Issues[J]));
    End;
  End;

  WriteLn('--------------------------------------------------------');
  WriteLn(Format('  Results: %d file(s) analyzed | %d with issues | %d clean',
    [TotalFiles, IssueFiles, CleanFiles]));
  If OptionFix Then
    WriteLn(Format('  Fixes applied: %d occurrence(s) resolved.', [TotalFixed]));

  If TotalIssues = 0 Then
  Begin
    WriteLn('  [SUCCESS] No quality issues or code smells found!');
    WriteLn('========================================================');
    Halt(0);
  End
  Else
  Begin
    WriteLn(Format('  Total: %d quality issue(s) found.', [TotalIssues]));
    WriteLn('========================================================');
    Halt(1);
  End;
End;

Procedure HandleEmitHeaderCommand(Const SourcePath, OutPath: String);
Var
  Source, DestPath: string;
  Lexer: TAetherLexer;
  Parser: TAetherParser;
  ModuleNode: TASTModule;
Begin
  ModuleNode := nil;
  DestPath := OutPath;
  If DestPath = '' Then
    DestPath := ChangeFileExt(SourcePath, '.h');

  Source := LoadFileContent(SourcePath);
  Lexer := TAetherLexer.Create(Source);
  Parser := TAetherParser.Create(Lexer);
  Try
    ModuleNode := Parser.ParseModule;
    ApplyCfgToModule(ModuleNode, GetCurrentOSName, 'c', False);
    SaveCHeaderToFile(ModuleNode, DestPath);
    PrintBanner;
    WriteLn('C header (C99/C++) generated successfully:');
    WriteLn('  --> ' + DestPath);
  Finally
    ModuleNode.Free;
    Parser.Free;
    Lexer.Free;
  End;
End;

Var 
  InputFile: string;
  OutputExe: string;
  OptionDumpTokens: Boolean;
  OptionDumpAST: Boolean;
  OptionCheckOnly: Boolean;
  OptionTargetPascal: Boolean;
  OptionJSONDiag: Boolean;
  OptionIncremental: Boolean;
  OptionForce: Boolean;
  OptionRelease: Boolean;
  OptionOptimize: Boolean;
  OptionSharedLib: Boolean;
  OptionEmitHeader: Boolean;
  IsRunCommand: Boolean;
  ProjConfig: TAetherProjectConfig;
  I, J: Integer;
  Arg: string;
  PkgName, OptPath, OptGit, OptVer, FilterName, SubFilter, SubCmd: string;
  OptRegistry, SearchTerm: string;
  IsDryRun, TargetIsLib, OptionCompare, OptionJSON: Boolean;
  BenchIters, ProfileRuns: Integer;
  TargetEntry, TargetOut, TargetBackend, TargetCC: string;
  EmitTargetPascal, EmitToStdout, HasTargetSpecified, EmitAsUnit, EmitSilent, EmitWatch: Boolean;
  EmitSource, EmitOut, EmitOutDir, EmitKind, DisplaySrcFile: string;
  EmitManifest, EmitRelease: Boolean;
  UpgradeOpts: TUpgradeOptions;
  OptionTargetAll, OkPas, OkC, TestOk: Boolean;
  PasPass, PasFail, PasTotal, CPass, CFail, CTotal: Integer;
Begin
  InitGlobalPaths;
  InputFile := '';
  OutputExe := '';
  OptionDumpTokens := False;
  OptionDumpAST := False;
  OptionCheckOnly := False;
  OptionTargetPascal := True;
  OptionJSONDiag := False;
  OptionIncremental := False;
  OptionForce := False;
  OptionRelease := False;
  OptionOptimize := False;
  OptionSharedLib := False;
  OptionEmitHeader := False;
  IsRunCommand := False;

  // Check --version / -V / version
  If (ParamCount >= 1) And ((LowerCase(ParamStr(1)) = '--version') Or (ParamStr(1) = '-V') Or (LowerCase(ParamStr(1)) = 'version')) Then
    Begin
      PrintVersionInfo;
      Halt(0);
    End;

  // Check lint command: lint [path] [--fix] [--json]
  If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'lint') Then
    Begin
      Try
        HandleLintCommand;
      Except
        on E: Exception Do
          Begin
            WriteLn(ErrOutput, 'Error running linter: ', E.Message);
            Halt(1);
          End;
      End;
    End;

  // Check format command: fmt [path] [--check]
  If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'fmt') Then
    Begin
      PrintBanner;
      Try
        HandleFmtCommand;
        Halt(0);
      Except
        on E: Exception Do
          Begin
            WriteLn(ErrOutput, 'Error formatting: ', E.Message);
            Halt(1);
          End;
      End;
    End;

  // Check documentation command: doc [path] [options]
  If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'doc') Then
    Begin
      PrintBanner;
      Try
        HandleDocCommand;
        Halt(0);
      Except
        on E: Exception Do
          Begin
            WriteLn(ErrOutput, 'Error generating documentation: ', E.Message);
            Halt(1);
          End;
      End;
    End;

  // Check clean command: clean
  If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'clean') Then
    Begin
      PrintBanner;
      Try
        HandleProjectClean();
        Halt(0);
      Except
        on E: Exception Do
          Begin
            WriteLn(ErrOutput, 'Error cleaning project: ', E.Message);
            Halt(1);
          End;
      End;
    End;

  // Check self-hosting command: bootstrap
  If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'bootstrap') Then
    Begin
      PrintBanner;
      Try
        HandleBootstrapCommand();
        Halt(0);
      Except
        on E: Exception Do
          Begin
            WriteLn(ErrOutput, 'Error during bootstrap process: ', E.Message);
            Halt(1);
          End;
      End;
    End;

  // Check C header emission command: emit-header <file> [options]
  If (ParamCount >= 1) And ((LowerCase(ParamStr(1)) = 'emit-header') Or ((LowerCase(ParamStr(1)) = 'emit') And (ParamCount >= 2) And (LowerCase(ParamStr(2)) = 'header'))) Then
    Begin
      EmitSource := '';
      EmitOut := '';
      I := 2;
      If LowerCase(ParamStr(1)) = 'emit' Then Inc(I);
      While I <= ParamCount Do
        Begin
          Arg := ParamStr(I);
          If (Arg = '-o') And (I + 1 <= ParamCount) Then
            Begin
              Inc(I);
              EmitOut := ParamStr(I);
            End
          Else If Pos('--output=', Arg) = 1 Then
            EmitOut := Copy(Arg, 10, Length(Arg))
          Else If EmitSource = '' Then
            EmitSource := Arg;
          Inc(I);
        End;

      If EmitSource = '' Then
        Begin
          PrintBanner;
          WriteLn(ErrOutput, 'Error: No .aeth source file specified.');
          WriteLn('Usage: aetherc emit-header <file.aeth> [-o <output.h>]');
          Halt(1);
        End;

      If EmitOut = '' Then
        EmitOut := ChangeFileExt(EmitSource, '.h');

      Try
        HandleEmitHeaderCommand(EmitSource, EmitOut);
        Halt(0);
      Except
        on E: Exception Do
          Begin
            WriteLn(ErrOutput, 'Error generating C header: ', E.Message);
            Halt(1);
          End;
      End;
    End;

  // Check emit command: emit <pascal|c|wasm|runtime> [file] [options]
  If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'emit') Then
    Begin
      EmitTargetPascal := True;
      EmitKind := 'pascal';
      EmitSource := '';
      EmitOut := '';
      EmitOutDir := '';
      EmitToStdout := False;
      EmitAsUnit := False;
      EmitSilent := False;
      EmitWatch := False;
      EmitManifest := False;
      EmitRelease := False;
      HasTargetSpecified := False;

      I := 2;
      While I <= ParamCount Do
        Begin
          Arg := ParamStr(I);
          If LowerCase(Arg) = 'pascal' Then
            Begin
              EmitTargetPascal := True;
              EmitKind := 'pascal';
              HasTargetSpecified := True;
            End
          Else If LowerCase(Arg) = 'c' Then
            Begin
              EmitTargetPascal := False;
              EmitKind := 'c';
              HasTargetSpecified := True;
            End
          Else If LowerCase(Arg) = 'wasm' Then
            Begin
              EmitKind := 'wasm';
              HasTargetSpecified := True;
            End
          Else If LowerCase(Arg) = 'runtime' Then
            Begin
              EmitKind := 'runtime';
              HasTargetSpecified := True;
            End
          Else If Arg = '--target=pascal' Then
            Begin
              EmitTargetPascal := True;
              EmitKind := 'pascal';
              HasTargetSpecified := True;
            End
          Else If Arg = '--target=c' Then
            Begin
              EmitTargetPascal := False;
              EmitKind := 'c';
              HasTargetSpecified := True;
            End
          Else If Arg = '--target=wasm' Then
            Begin
              EmitKind := 'wasm';
              HasTargetSpecified := True;
            End
          Else If Arg = '--unit' Then
            EmitAsUnit := True
          Else If Arg = '--shared-runtime' Then
            GlobalSharedRuntime := True
          Else If (Arg = '--manifest') Or (Arg = '--wasm-manifest') Then
            EmitManifest := True
          Else If Arg = '--release' Then
            EmitRelease := True
          Else If Arg = '--html' Then
            GlobalEmitHtmlWrapper := True
          Else If (Arg = '--emit-json-diag') Or (Arg = '--emit-json-diagnostics') Then
            OptionJSONDiag := True
          Else If (Arg = '--source-file') And (I + 1 <= ParamCount) Then
            Begin
              Inc(I);
              GlobalSourceFileDisplay := ParamStr(I);
            End
          Else If Pos('--source-file=', Arg) = 1 Then
            GlobalSourceFileDisplay := Copy(Arg, 15, Length(Arg))
          Else If (Arg = '--line-offset') And (I + 1 <= ParamCount) Then
            Begin
              Inc(I);
              GlobalLineOffset := StrToIntDef(ParamStr(I), 0);
            End
          Else If Pos('--line-offset=', Arg) = 1 Then
            GlobalLineOffset := StrToIntDef(Copy(Arg, 15, Length(Arg)), 0)
          Else If (Arg = '--silent') Or (Arg = '-s') Then
            EmitSilent := True
          Else If (Arg = '--watch') Or (Arg = '-w') Then
            EmitWatch := True
          Else If Pos('--out-dir=', Arg) = 1 Then
            EmitOutDir := Copy(Arg, 11, Length(Arg))
          Else If Pos('--outdir=', Arg) = 1 Then
            EmitOutDir := Copy(Arg, 10, Length(Arg))
          Else If (Arg = '-d') And (I + 1 <= ParamCount) Then
            Begin
              Inc(I);
              EmitOutDir := ParamStr(I);
            End
          Else If Arg = '--stdout' Then
            EmitToStdout := True
          Else If Arg = '-o' Then
            Begin
              Inc(I);
              If I <= ParamCount Then EmitOut := ParamStr(I);
            End
          Else If Pos('-o', Arg) = 1 Then
            EmitOut := Copy(Arg, 3, Length(Arg))
          Else If ParsePathFlag(Arg, I) Then
          Begin
          End
          Else If (Length(Arg) > 0) And (Arg[1] <> '-') Then
            Begin
              If EmitSource = '' Then EmitSource := Arg;
            End;
          Inc(I);
        End;

      If EmitKind = 'runtime' Then
        Begin
          If EmitToStdout Then
            Begin
              Write(TAetherEmitterPascal.GenerateRuntimeUnit);
              Halt(0);
            End;
          If EmitOutDir = '' Then
            EmitOutDir := GetCurrentDir + PathDelim + 'generated' + PathDelim + 'pascal';
          If Not EmitSilent Then PrintBanner;
          WriteRuntimeUnitIfNeeded(EmitOutDir, EmitSilent);
          Halt(0);
        End;

      If LoadProjectConfig(ProjConfig) Then
        Begin
          If EmitSource = '' Then
            EmitSource := ProjConfig.RootDir + PathDelim + StringReplace(ProjConfig.Entry, '/', PathDelim, [rfReplaceAll]);
          If Not HasTargetSpecified Then
          Begin
            EmitTargetPascal := ProjConfig.Backend <> 'c';
            If EmitTargetPascal Then EmitKind := 'pascal' Else EmitKind := 'c';
          End;
          If EmitOutDir = '' Then
            Begin
              If (EmitKind = 'pascal') And (ProjConfig.Outputs.PascalSrcDir <> '') Then
                EmitOutDir := ProjConfig.RootDir + PathDelim + ProjConfig.Outputs.PascalSrcDir
              Else If (EmitKind = 'c') And (ProjConfig.Outputs.CSrcDir <> '') Then
                EmitOutDir := ProjConfig.RootDir + PathDelim + ProjConfig.Outputs.CSrcDir
              Else If (EmitKind = 'wasm') And (ProjConfig.Outputs.BinDir <> '') Then
                EmitOutDir := ProjConfig.RootDir + PathDelim + ProjConfig.Outputs.BinDir;
            End;
          If ProjConfig.Outputs.AsUnit Then
            EmitAsUnit := True;
          RestoreProjectDependencies(ProjConfig);
        End
      Else If EmitSource = '' Then
        Begin
          WriteLn(ErrOutput, 'Error: No source file specified and no "aether.json" found.');
          WriteLn(ErrOutput, 'Usage: aetherc emit <pascal|c|wasm|runtime> [file.aeth] [--unit] [--shared-runtime] [--out-dir=dir] [--stdout]');
          Halt(1);
        End;

      If GlobalSourceFileDisplay <> '' Then
        DisplaySrcFile := GlobalSourceFileDisplay
      Else
        DisplaySrcFile := EmitSource;

      If (Not EmitToStdout) And (Not EmitSilent) And (Not EmitWatch) And (Not OptionJSONDiag) Then
        PrintBanner;

      If EmitKind = 'wasm' Then
        Begin
          If EmitOutDir <> '' Then
            GlobalOutBinDir := ExcludeTrailingPathDelimiter(EmitOutDir);
          GlobalEmitWasmManifest := GlobalEmitWasmManifest Or EmitManifest;
          Try
            CompileFile(EmitSource, 'wasm', False, False, EmitOut,
                        EmitSilent Or OptionJSONDiag, False, False,
                        EmitRelease, EmitRelease, 'clang', 'clang', False, False);
            Halt(0);
          Except
            on E: EAetherBorrowError Do
              Begin
                If OptionJSONDiag Then
                  WriteLn(GenerateJSONDiagnostic(DisplaySrcFile, 'Error', E.Code, E.Message, E.Line, E.Col, E.MovedLine, E.MovedCol,
                    'borrow_instead_of_move', 'Change the call to "borrow" if ownership transfer is not required.', 'borrow'))
                Else
                  WriteLn(ErrOutput, 'WebAssembly build error: ', E.Message);
                Halt(1);
              End;
            on E: EAetherTypeError Do
              Begin
                If OptionJSONDiag Then
                  WriteLn(GenerateJSONDiagnostic(DisplaySrcFile, 'Error', E.Code, E.Message, E.Line, E.Col))
                Else
                  WriteLn(ErrOutput, 'WebAssembly build error: ', E.Message);
                Halt(1);
              End;
            on E: EAetherParserError Do
              Begin
                If OptionJSONDiag Then
                  WriteLn(GenerateJSONDiagnostic(DisplaySrcFile, 'Error', 'E0001', E.Message, E.Line, E.Col))
                Else
                  WriteLn(ErrOutput, 'WebAssembly build error: ', E.Message);
                Halt(1);
              End;
            on E: EAetherLexerError Do
              Begin
                If OptionJSONDiag Then
                  WriteLn(GenerateJSONDiagnostic(DisplaySrcFile, 'Error', 'E0000', E.Message, E.Line, E.Col))
                Else
                  WriteLn(ErrOutput, 'WebAssembly build error: ', E.Message);
                Halt(1);
              End;
            on E: Exception Do
              Begin
                If OptionJSONDiag Then
                  WriteLn(GenerateJSONDiagnostic(DisplaySrcFile, 'Error', 'E9999', E.Message, 1 + GlobalLineOffset, 1))
                Else
                  WriteLn(ErrOutput, 'WebAssembly build error: ', E.Message);
                Halt(1);
              End;
          End;
        End;

      If EmitWatch Then
        Begin
          WatchEmitFile(EmitSource, EmitTargetPascal, EmitOut, EmitOutDir, EmitAsUnit, EmitSilent);
          Halt(0);
        End;

      Try
        EmitFile(EmitSource, EmitTargetPascal, EmitOut, EmitOutDir, EmitAsUnit, EmitToStdout, EmitSilent, GlobalSharedRuntime);
        Halt(0);
      Except
        on E: EAetherBorrowError Do
          Begin
            If OptionJSONDiag Then
              WriteLn(GenerateJSONDiagnostic(DisplaySrcFile, 'Error', E.Code, E.Message, E.Line, E.Col, E.MovedLine, E.MovedCol,
                'borrow_instead_of_move', 'Change the call to "borrow" if ownership transfer is not required.', 'borrow'))
            Else
              WriteLn(ErrOutput, 'Code generation error: ', E.Message);
            Halt(1);
          End;
        on E: EAetherTypeError Do
          Begin
            If OptionJSONDiag Then
              WriteLn(GenerateJSONDiagnostic(DisplaySrcFile, 'Error', E.Code, E.Message, E.Line, E.Col))
            Else
              WriteLn(ErrOutput, 'Code generation error: ', E.Message);
            Halt(1);
          End;
        on E: EAetherParserError Do
          Begin
            If OptionJSONDiag Then
              WriteLn(GenerateJSONDiagnostic(DisplaySrcFile, 'Error', 'E0001', E.Message, E.Line, E.Col))
            Else
              WriteLn(ErrOutput, 'Code generation error: ', E.Message);
            Halt(1);
          End;
        on E: EAetherLexerError Do
          Begin
            If OptionJSONDiag Then
              WriteLn(GenerateJSONDiagnostic(DisplaySrcFile, 'Error', 'E0000', E.Message, E.Line, E.Col))
            Else
              WriteLn(ErrOutput, 'Code generation error: ', E.Message);
            Halt(1);
          End;
        on E: Exception Do
          Begin
            If OptionJSONDiag Then
              WriteLn(GenerateJSONDiagnostic(DisplaySrcFile, 'Error', 'E9999', E.Message, 1 + GlobalLineOffset, 1))
            Else
              WriteLn(ErrOutput, 'Code generation error: ', E.Message);
            Halt(1);
          End;
      End;
    End;

  // 1. Check project commands: init / new
  If (ParamCount >= 1) And ((LowerCase(ParamStr(1)) = 'init') Or (LowerCase(
     ParamStr(1)) = 'new')) Then
    Begin
      PrintBanner;
      Arg := '';
      If ParamCount >= 2 Then Arg := ParamStr(2);
      Try
        HandleProjectInit(Arg);
        Halt(0);
      Except
        on E: Exception Do
              Begin
                WriteLn(ErrOutput, 'Error initializing project: ', E.Message);
                Halt(1);
              End;
    End;
End;

// Check unified package management command: pkg
If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'pkg') Then
  Begin
    PrintBanner;
    SubCmd := '';
    If ParamCount >= 2 Then SubCmd := LowerCase(ParamStr(2));

    If SubCmd = 'add' Then
    Begin
      PkgName := '';
      OptPath := '';
      OptGit := '';
      OptVer := '';
      I := 3;
      While I <= ParamCount Do
      Begin
        Arg := ParamStr(I);
        If Pos('--path=', Arg) = 1 Then OptPath := Copy(Arg, 8, Length(Arg))
        Else If Pos('--git=', Arg) = 1 Then OptGit := Copy(Arg, 7, Length(Arg))
        Else If Pos('--version=', Arg) = 1 Then OptVer := Copy(Arg, 11, Length(Arg))
        Else If Pos('--branch=', Arg) = 1 Then OptVer := Copy(Arg, 10, Length(Arg))
        Else If Pos('--tag=', Arg) = 1 Then OptVer := Copy(Arg, 7, Length(Arg))
        Else If PkgName = '' Then PkgName := Arg
        Else If (OptVer = '') And (Length(Arg) > 0) And (Arg[1] <> '-') Then OptVer := Arg;
        Inc(I);
      End;
      Try
        HandleProjectAdd(PkgName, OptPath, OptGit, OptVer);
        Halt(0);
      Except
        on E: Exception Do
        Begin
          WriteLn(ErrOutput, 'Error adding package: ', E.Message);
          Halt(1);
        End;
      End;
    End
    Else If (SubCmd = 'add-sys') Then
    Begin
      PkgName := '';
      IsDryRun := False;
      I := 3;
      While I <= ParamCount Do
      Begin
        Arg := ParamStr(I);
        If (Arg = '--no-install') Or (Arg = '--manifest-only') Then IsDryRun := True
        Else If (PkgName = '') And (Length(Arg) > 0) And (Arg[1] <> '-') Then PkgName := Arg;
        Inc(I);
      End;
      Try
        HandleProjectAddSys(PkgName, IsDryRun);
        Halt(0);
      Except
        on E: Exception Do
        Begin
          WriteLn(ErrOutput, 'Error adding system library: ', E.Message);
          Halt(1);
        End;
      End;
    End
    Else If (SubCmd = 'add-fpc') Then
    Begin
      PkgName := '';
      IsDryRun := False;
      I := 3;
      While I <= ParamCount Do
      Begin
        Arg := ParamStr(I);
        If (Arg = '--no-install') Or (Arg = '--manifest-only') Then IsDryRun := True
        Else If (PkgName = '') And (Length(Arg) > 0) And (Arg[1] <> '-') Then PkgName := Arg;
        Inc(I);
      End;
      Try
        HandleProjectAddFpc(PkgName, IsDryRun);
        Halt(0);
      Except
        on E: Exception Do
        Begin
          WriteLn(ErrOutput, 'Error adding Free Pascal package: ', E.Message);
          Halt(1);
        End;
      End;
    End
    Else If (SubCmd = 'remove') Or (SubCmd = 'rm') Then
    Begin
      PkgName := '';
      If ParamCount >= 3 Then PkgName := ParamStr(3);
      Try
        HandleProjectRemove(PkgName);
        Halt(0);
      Except
        on E: Exception Do
        Begin
          WriteLn(ErrOutput, 'Error removing package: ', E.Message);
          Halt(1);
        End;
      End;
    End
    Else If (SubCmd = 'update') Or (SubCmd = 'upgrade') Then
    Begin
      PkgName := '';
      If ParamCount >= 3 Then PkgName := ParamStr(3);
      Try
        HandleProjectUpdate(PkgName);
        Halt(0);
      Except
        on E: Exception Do
        Begin
          WriteLn(ErrOutput, 'Error updating packages: ', E.Message);
          Halt(1);
        End;
      End;
    End
    Else If SubCmd = 'audit' Then
    Begin
      Try
        HandleProjectAudit();
        Halt(0);
      Except
        on E: Exception Do
        Begin
          WriteLn(ErrOutput, 'Error during security audit: ', E.Message);
          Halt(1);
        End;
      End;
    End
    Else If (SubCmd = 'list') Or (SubCmd = 'ls') Then
    Begin
      Try
        HandleProjectList();
        Halt(0);
      Except
        on E: Exception Do
        Begin
          WriteLn(ErrOutput, 'Error listing dependencies: ', E.Message);
          Halt(1);
        End;
      End;
    End
    Else If SubCmd = 'clean' Then
    Begin
      Try
        HandleProjectCleanCache();
        Halt(0);
      Except
        on E: Exception Do
        Begin
          WriteLn(ErrOutput, 'Error cleaning cache: ', E.Message);
          Halt(1);
        End;
      End;
    End
    Else If SubCmd = 'publish' Then
    Begin
      OptRegistry := '';
      IsDryRun := False;
      I := 3;
      While I <= ParamCount Do
      Begin
        Arg := ParamStr(I);
        If Pos('--registry=', Arg) = 1 Then OptRegistry := Copy(Arg, 12, Length(Arg))
        Else If (Arg = '--dry-run') Or (Arg = '-n') Then IsDryRun := True;
        Inc(I);
      End;
      Try
        HandlePkgPublish(OptRegistry, IsDryRun);
        Halt(0);
      Except
        on E: Exception Do
        Begin
          WriteLn(ErrOutput, 'Error publishing package: ', E.Message);
          Halt(1);
        End;
      End;
    End
    Else If (SubCmd = 'search') Or (SubCmd = 'find') Then
    Begin
      SearchTerm := '';
      OptRegistry := '';
      I := 3;
      While I <= ParamCount Do
      Begin
        Arg := ParamStr(I);
        If Pos('--registry=', Arg) = 1 Then OptRegistry := Copy(Arg, 12, Length(Arg))
        Else If SearchTerm = '' Then SearchTerm := Arg;
        Inc(I);
      End;
      Try
        HandlePkgSearch(SearchTerm, OptRegistry);
        Halt(0);
      Except
        on E: Exception Do
        Begin
          WriteLn(ErrOutput, 'Error searching packages: ', E.Message);
          Halt(1);
        End;
      End;
    End
    Else
    Begin
      WriteLn('Usage: aetherc pkg <subcommand> [options]');
      WriteLn('');
      WriteLn('Available Subcommands:');
      WriteLn('  add <package>    Add a dependency to the project (Git, Local, or Registry)');
      WriteLn('  add-sys <lib>    Install MSYS2 package / verify pkg-config & add to system_libs');
      WriteLn('  add-fpc <pkg>    Install via fppkg / locate FPC/OPM units & add to pascal_packages');
      WriteLn('  remove <package> Remove a dependency from aether.json and clean caches (rm)');
      WriteLn('  update [package] Update Git dependencies and synchronize the lockfile (upgrade)');
      WriteLn('  publish          Publish the current package to the official Aether Registry (--dry-run)');
      WriteLn('  search <query>   Search community packages available in the Registry');
      WriteLn('  audit            Inspect cryptographic integrity and TLS security');
      WriteLn('  list             Display the list of all project dependencies (ls)');
      WriteLn('  clean            Clean the global package cache (~/.aether/cache)');
      Halt(0);
    End;
  End;

// 2. Check package command: add
If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'add') Then
  Begin
    PrintBanner;
    PkgName := '';
    OptPath := '';
    OptGit := '';
    OptVer := '';
    I := 2;
    While I <= ParamCount Do
      Begin
        Arg := ParamStr(I);
        If Pos('--path=', Arg) = 1 Then
          OptPath := Copy(Arg, 8, Length(Arg))
        Else If Pos('--git=', Arg) = 1 Then
               OptGit := Copy(Arg, 7, Length(Arg))
        Else If Pos('--version=', Arg) = 1 Then
               OptVer := Copy(Arg, 11, Length(Arg))
        Else If Pos('--branch=', Arg) = 1 Then
               OptVer := Copy(Arg, 10, Length(Arg))
        Else If Pos('--tag=', Arg) = 1 Then
               OptVer := Copy(Arg, 7, Length(Arg))
        Else If PkgName = '' Then
               PkgName := Arg
        Else If (OptVer = '') And (Length(Arg) > 0) And (Arg[1] <> '-') Then
               OptVer := Arg;
        Inc(I);
      End;
    Try
      HandleProjectAdd(PkgName, OptPath, OptGit, OptVer);
      Halt(0);
    Except
      on E: Exception Do
            Begin
              WriteLn(ErrOutput, 'Error adding package: ', E.Message);
              Halt(1);
            End;
  End;
End;

// Check package command: remove / rm
If (ParamCount >= 1) And ((LowerCase(ParamStr(1)) = 'remove') Or (LowerCase(ParamStr(1)) = 'rm')) Then
  Begin
    PrintBanner;
    PkgName := '';
    If ParamCount >= 2 Then PkgName := ParamStr(2);
    Try
      HandleProjectRemove(PkgName);
      Halt(0);
    Except
      on E: Exception Do
            Begin
              WriteLn(ErrOutput, 'Error removing package: ', E.Message);
              Halt(1);
            End;
  End;
End;

// Check package command: update (shortcut for "aetherc pkg update")
If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'update') Then
  Begin
    PrintBanner;
    PkgName := '';
    If ParamCount >= 2 Then PkgName := ParamStr(2);
    Try
      HandleProjectUpdate(PkgName);
      Halt(0);
    Except
      on E: Exception Do
            Begin
              WriteLn(ErrOutput, 'Error updating packages: ', E.Message);
              Halt(1);
            End;
  End;
End;

// Check toolchain self-update command: upgrade
If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'upgrade') Then
  Begin
    PrintBanner;
    UpgradeOpts.CheckOnly := False;
    UpgradeOpts.FromSource := False;
    UpgradeOpts.BinaryMode := False;
    UpgradeOpts.Rollback := False;
    UpgradeOpts.DryRun := False;
    UpgradeOpts.Nightly := False;
    UpgradeOpts.AllowUnsigned := False;
    UpgradeOpts.NoStdUpdate := False;
    UpgradeOpts.Channel := 'stable';
    UpgradeOpts.TargetVersion := '';
    UpgradeOpts.CustomUrl := '';

    I := 2;
    While I <= ParamCount Do
      Begin
        Arg := ParamStr(I);
        If (Arg = '--check') Or (Arg = '-c') Then
          UpgradeOpts.CheckOnly := True
        Else If (Arg = '--from-source') Or (Arg = '--source') Or (Arg = '-s') Then
          UpgradeOpts.FromSource := True
        Else If (Arg = '--binary') Or (Arg = '-b') Then
          UpgradeOpts.BinaryMode := True
        Else If (Arg = '--rollback') Or (Arg = '-r') Then
          UpgradeOpts.Rollback := True
        Else If (Arg = '--dry-run') Or (Arg = '--dry') Or (Arg = '-d') Then
          UpgradeOpts.DryRun := True
        Else If Arg = '--nightly' Then
        Begin
          UpgradeOpts.Nightly := True;
          UpgradeOpts.Channel := 'nightly';
        End
        Else If Arg = '--allow-unsigned' Then
          UpgradeOpts.AllowUnsigned := True
        Else If Arg = '--no-std' Then
          UpgradeOpts.NoStdUpdate := True
        Else If (Arg = '--channel') And (I + 1 <= ParamCount) Then
        Begin
          Inc(I);
          UpgradeOpts.Channel := LowerCase(ParamStr(I));
          If UpgradeOpts.Channel = 'nightly' Then UpgradeOpts.Nightly := True;
        End
        Else If Pos('--channel=', Arg) = 1 Then
        Begin
          UpgradeOpts.Channel := LowerCase(Copy(Arg, 11, Length(Arg)));
          If UpgradeOpts.Channel = 'nightly' Then UpgradeOpts.Nightly := True;
        End
        Else If (Arg = '--version') And (I + 1 <= ParamCount) Then
        Begin
          Inc(I);
          UpgradeOpts.TargetVersion := ParamStr(I);
        End
        Else If Pos('--version=', Arg) = 1 Then
          UpgradeOpts.TargetVersion := Copy(Arg, 11, Length(Arg))
        Else If Pos('-v=', Arg) = 1 Then
          UpgradeOpts.TargetVersion := Copy(Arg, 4, Length(Arg))
        Else If (Arg = '--url') And (I + 1 <= ParamCount) Then
        Begin
          Inc(I);
          UpgradeOpts.CustomUrl := ParamStr(I);
        End
        Else If Pos('--url=', Arg) = 1 Then
          UpgradeOpts.CustomUrl := Copy(Arg, 7, Length(Arg))
        Else If (Arg = '-h') Or (Arg = '--help') Then
          Begin
            WriteLn('Usage: aetherc upgrade [options]');
            WriteLn('');
            WriteLn('Toolchain Upgrade Options:');
            WriteLn('  --check, -c           Only check if newer versions are available');
            WriteLn('  --from-source, -s     Upgrade by compiling from the local Git repository');
            WriteLn('  --binary, -b          Download and install the pre-built release (bin + std)');
            WriteLn('  --rollback, -r        Restore previous executable and stdlib backup (.bak)');
            WriteLn('  --dry-run, -d         Simulate all steps without modifying files');
            WriteLn('  --version=<tag>       Install a specific version or tag (e.g., --version=v0.6.0)');
            WriteLn('  --channel=<name>      Select release channel: stable (default) or nightly');
            WriteLn('  --nightly             Shortcut for --channel=nightly');
            WriteLn('  --url=<url>           Custom release metadata JSON URL (supports file:/// for tests)');
            WriteLn('  --allow-unsigned      Allow binary install when no SHA-256 checksum asset exists');
            WriteLn('  --no-std              Update compiler binary only, keeping existing std/ intact');
            Halt(0);
          End
        Else If (Length(Arg) > 0) And (Arg[1] <> '-') And (UpgradeOpts.TargetVersion = '') Then
          UpgradeOpts.TargetVersion := Arg;
        Inc(I);
      End;

    Try
      TAetherUpgrade.ExecuteUpgrade(UpgradeOpts);
      Halt(0);
    Except
      on E: Exception Do
            Begin
              WriteLn(ErrOutput, 'Error during toolchain upgrade: ', E.Message);
              Halt(1);
            End;
    End;
  End;

// Check security command: audit
If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'audit') Then
  Begin
    PrintBanner;
    Try
      HandleProjectAudit();
      Halt(0);
    Except
      on E: Exception Do
            Begin
              WriteLn(ErrOutput, 'Error during security audit: ', E.Message);
              Halt(1);
            End;
  End;
End;

// Check Registry publish command: publish
If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'publish') Then
  Begin
    PrintBanner;
    OptRegistry := '';
    IsDryRun := False;
    I := 2;
    While I <= ParamCount Do
      Begin
        Arg := ParamStr(I);
        If Pos('--registry=', Arg) = 1 Then OptRegistry := Copy(Arg, 12, Length(Arg))
        Else If (Arg = '--dry-run') Or (Arg = '-n') Then IsDryRun := True;
        Inc(I);
      End;
    Try
      HandlePkgPublish(OptRegistry, IsDryRun);
      Halt(0);
    Except
      on E: Exception Do
        Begin
          WriteLn(ErrOutput, 'Error publishing package: ', E.Message);
          Halt(1);
        End;
    End;
  End;

// Check Registry search command: search / find
If (ParamCount >= 1) And ((LowerCase(ParamStr(1)) = 'search') Or (LowerCase(ParamStr(1)) = 'find')) Then
  Begin
    PrintBanner;
    SearchTerm := '';
    OptRegistry := '';
    I := 2;
    While I <= ParamCount Do
      Begin
        Arg := ParamStr(I);
        If Pos('--registry=', Arg) = 1 Then OptRegistry := Copy(Arg, 12, Length(Arg))
        Else If SearchTerm = '' Then SearchTerm := Arg;
        Inc(I);
      End;
    Try
      HandlePkgSearch(SearchTerm, OptRegistry);
      Halt(0);
    Except
      on E: Exception Do
        Begin
          WriteLn(ErrOutput, 'Error searching packages: ', E.Message);
          Halt(1);
        End;
    End;
  End;

// 3. Check test command: test [filter] [--target=pascal|c|all] [--both]
If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'test') Then
  Begin
    PrintBanner;
    FilterName := '';
    OptionTargetPascal := True;
    OptionTargetAll := False;
    I := 2;
    While I <= ParamCount Do
      Begin
        Arg := ParamStr(I);
        If Arg = '--target=pascal' Then
          Begin
            OptionTargetPascal := True;
            OptionTargetAll := False;
          End
        Else If Arg = '--target=c' Then
          Begin
            OptionTargetPascal := False;
            OptionTargetAll := False;
          End
        Else If (Arg = '--target=all') Or (Arg = '--both') Then
          OptionTargetAll := True
        Else If FilterName = '' Then FilterName := Arg;
        Inc(I);
      End;
    Try
      If OptionTargetAll Then
        Begin
          OkPas := HandleProjectTest(FilterName, True, PasPass, PasFail, PasTotal);
          WriteLn('');
          OkC := HandleProjectTest(FilterName, False, CPass, CFail, CTotal);
          WriteLn('');
          WriteLn('========================================================');
          WriteLn(Format('  Summary (All Backends): FPC %d/%d | C99 %d/%d',
                  [PasPass, PasTotal, CPass, CTotal]));
          WriteLn('========================================================');
          If OkPas And OkC Then Halt(0) Else Halt(1);
        End
      Else
        Begin
          TestOk := HandleProjectTest(FilterName, OptionTargetPascal, PasPass, PasFail, PasTotal);
          If TestOk Then Halt(0) Else Halt(1);
        End;
    Except
      on E: Exception Do
            Begin
              WriteLn(ErrOutput, 'Error during test execution: ', E.Message
              );
              Halt(1);
            End;
  End;
End;

// Check benchmark command: bench [path_or_filter] [func_filter] [--compare] [--json|--format=json] [--iters=N] [--target=pascal|c]
If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'bench') Then
  Begin
    FilterName := '';
    SubFilter := '';
    OptionTargetPascal := True;
    OptionCompare := False;
    OptionJSON := False;
    BenchIters := 100;
    I := 2;
    While I <= ParamCount Do
      Begin
        Arg := ParamStr(I);
        If Arg = '--target=pascal' Then OptionTargetPascal := True
        Else If Arg = '--target=c' Then OptionTargetPascal := False
        Else If (Arg = '--compare') Or (Arg = '--all-targets') Then OptionCompare := True
        Else If (Arg = '--format=json') Or (Arg = '--json') Then OptionJSON := True
        Else If Pos('--iters=', Arg) = 1 Then BenchIters := StrToIntDef(Copy(Arg, 9, Length(Arg)), 100)
        Else If FilterName = '' Then FilterName := Arg
        Else If SubFilter = '' Then SubFilter := Arg;
        Inc(I);
      End;
    If Not OptionJSON Then
      PrintBanner;
    Try
      HandleProjectBench(FilterName, SubFilter, OptionTargetPascal, OptionCompare, OptionJSON, BenchIters);
      Halt(0);
    Except
      on E: Exception Do
        Begin
          WriteLn(ErrOutput, 'Error during benchmark execution: ', E.Message);
          Halt(1);
        End;
    End;
  End;

// Check profiling command: profile <file.aeth> [--runs=N] [--target=pascal|c] [--json]
If (ParamCount >= 1) And (LowerCase(ParamStr(1)) = 'profile') Then
  Begin
    FilterName := '';
    OptionTargetPascal := True;
    OptionJSON := False;
    ProfileRuns := 3;
    I := 2;
    While I <= ParamCount Do
      Begin
        Arg := ParamStr(I);
        If Arg = '--target=pascal' Then OptionTargetPascal := True
        Else If Arg = '--target=c' Then OptionTargetPascal := False
        Else If (Arg = '--format=json') Or (Arg = '--json') Then OptionJSON := True
        Else If Pos('--runs=', Arg) = 1 Then ProfileRuns := StrToIntDef(Copy(Arg, 8, Length(Arg)), 3)
        Else If FilterName = '' Then FilterName := Arg;
        Inc(I);
      End;

    If FilterName = '' Then
      Begin
        WriteLn(ErrOutput, 'Error: No source file specified for profiling.');
        WriteLn(ErrOutput, 'Usage: aetherc profile <file.aeth> [--runs=N] [--target=pascal|c] [--json]');
        Halt(1);
      End;

    Try
      TAetherProfiler.HandleProfileCommand(FilterName, OptionTargetPascal, ProfileRuns, OptionJSON);
      Halt(0);
    Except
      on E: Exception Do
        Begin
          WriteLn(ErrOutput, 'Error during profiling execution: ', E.Message);
          Halt(1);
        End;
    End;
  End;

// 2. Check project commands: build / run
If (ParamCount >= 1) And ((LowerCase(ParamStr(1)) = 'build') Or (LowerCase(
   ParamStr(1)) = 'run')) Then
  Begin
    IsRunCommand := LowerCase(ParamStr(1)) = 'run';
    If Not LoadProjectConfig(ProjConfig) Then
      Begin
        PrintBanner;
        WriteLn(ErrOutput,

'Error: No "aether.json" file found in the current directory or parent folders.'
        );
        WriteLn(ErrOutput,

         'Hint: Run "aetherc init" to initialize a new Aether project.'
        );
        Halt(1);
      End;

    InputFile := ProjConfig.RootDir + PathDelim + StringReplace(ProjConfig.Entry
                 , '/', PathDelim, [rfReplaceAll]);
    OutputExe := ProjConfig.RootDir + PathDelim + StringReplace(ProjConfig.
                 Output, '/', PathDelim, [rfReplaceAll]);
    If ProjConfig.Backend <> '' Then
      GlobalTargetKind := LowerCase(ProjConfig.Backend)
    Else
      GlobalTargetKind := 'pascal';
    OptionTargetPascal := GlobalTargetKind <> 'c';
    OptionIncremental := True; // Enabled by default for aether.json projects
    InitGlobalPaths;
    RestoreProjectDependencies(ProjConfig);

    // Load paths declared in the 'paths' section of aether.json
    For J := 0 To High(ProjConfig.PathsAether) Do
      If ProjConfig.PathsAether[J] <> '' Then
        GlobalIncludePaths.Add(ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.PathsAether[J]));
    For J := 0 To High(ProjConfig.PathsCIncludes) Do
      If ProjConfig.PathsCIncludes[J] <> '' Then
        GlobalIncludePaths.Add(ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.PathsCIncludes[J]));
    For J := 0 To High(ProjConfig.PathsCSources) Do
      If ProjConfig.PathsCSources[J] <> '' Then
        GlobalCSources.Add(ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.PathsCSources[J]));
    For J := 0 To High(ProjConfig.PathsPascalUnits) Do
      If ProjConfig.PathsPascalUnits[J] <> '' Then
        GlobalPascalUnitPaths.Add(ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.PathsPascalUnits[J]));
    For J := 0 To High(ProjConfig.PathsLibDirs) Do
      If ProjConfig.PathsLibDirs[J] <> '' Then
        GlobalLibDirs.Add(ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.PathsLibDirs[J]));
    For J := 0 To High(ProjConfig.PathsLibs) Do
      If ProjConfig.PathsLibs[J] <> '' Then
        AddUniqueLprStr(GlobalLibs, ProjConfig.PathsLibs[J]);
    For J := 0 To High(ProjConfig.PathsSharedLibs) Do
      If ProjConfig.PathsSharedLibs[J] <> '' Then
        AddUniqueLprStr(GlobalSharedLibs, ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.PathsSharedLibs[J]));
    For J := 0 To High(ProjConfig.SystemLibs) Do
      AddUniqueLprStr(GlobalSystemLibs, ProjConfig.SystemLibs[J]);
    For J := 0 To High(ProjConfig.PascalPackages) Do
      AddUniqueLprStr(GlobalPascalPackages, ProjConfig.PascalPackages[J]);
    If Not ProjConfig.BundleDlls Then
      GlobalBundleDlls := False;
    CollectTransitiveNativeDeps(ProjConfig, GlobalSystemLibs, GlobalPascalPackages,
                                GlobalIncludePaths, GlobalIncludePaths, GlobalCSources,
                                GlobalPascalUnitPaths, GlobalLibDirs, GlobalLibs, GlobalSharedLibs);

    // Load output settings declared in the 'outputs' section of aether.json
    If (GlobalOutBinDir = '') And (ProjConfig.Outputs.BinDir <> '') Then
      GlobalOutBinDir := ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.Outputs.BinDir);
    If (GlobalOutPascalSrcDir = '') And (ProjConfig.Outputs.PascalSrcDir <> '') Then
      GlobalOutPascalSrcDir := ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.Outputs.PascalSrcDir);
    If (GlobalOutPascalUnitDir = '') And (ProjConfig.Outputs.PascalUnitDir <> '') Then
      GlobalOutPascalUnitDir := ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.Outputs.PascalUnitDir);
    If (GlobalOutCSrcDir = '') And (ProjConfig.Outputs.CSrcDir <> '') Then
      GlobalOutCSrcDir := ExpandFileName(ProjConfig.RootDir + PathDelim + ProjConfig.Outputs.CSrcDir);
    If ProjConfig.Outputs.AsUnit Then
      GlobalAsUnit := True;

    // Allow overriding flags such as --target=c, -o, -I, -Fu, etc. on the command line
    I := 2;
    While I <= ParamCount Do
      Begin
        Arg := ParamStr(I);
        If ParsePathFlag(Arg, I) Then
          // Consumed by the path flag
        Else If Arg = '--target=pascal' Then OptionTargetPascal := True
        Else If Arg = '--target=c' Then OptionTargetPascal := False
        Else If Arg = '--check-only' Then OptionCheckOnly := True
        Else If Arg = '--incremental' Then OptionIncremental := True
        Else If Arg = '--no-incremental' Then OptionIncremental := False
        Else If Arg = '--force' Then OptionForce := True
        Else If (Arg = '--lib') Or (Arg = '--shared') Then OptionSharedLib := True
        Else If Arg = '--emit-header' Then OptionEmitHeader := True
        Else If Arg = '--release' Then
        Begin
          OptionRelease := True;
          OptionOptimize := True;
        End
        Else If (Arg = '--opt') Or (Arg = '-O') Then OptionOptimize := True
        Else If (Arg = '--emit-json-diag') Or (Arg = '--emit-json-diagnostics')
               Then OptionJSONDiag := True
        Else If Arg = '-o' Then
               Begin
                 Inc(I);
                 If I <= ParamCount Then OutputExe := ParamStr(I);
               End;
        Inc(I);
      End;

    If (ProjConfig.ProjectType = 'cdylib') Or (ProjConfig.ProjectType = 'lib') Then
      OptionSharedLib := True;

    If (GlobalOutBinDir <> '') And (OutputExe = ProjConfig.RootDir + PathDelim + StringReplace(ProjConfig.Output, '/', PathDelim, [rfReplaceAll])) Then
      OutputExe := IncludeTrailingPathDelimiter(GlobalOutBinDir) + ExtractFileName(OutputExe);

    If Not OptionJSONDiag Then
      PrintBanner;

    Try
      If Length(ProjConfig.Targets) > 0 Then
      Begin
        For J := 0 To High(ProjConfig.Targets) Do
        Begin
          TargetEntry := ProjConfig.RootDir + PathDelim + StringReplace(ProjConfig.Targets[J].Entry, '/', PathDelim, [rfReplaceAll]);
          TargetOut := ProjConfig.RootDir + PathDelim + StringReplace(ProjConfig.Targets[J].Output, '/', PathDelim, [rfReplaceAll]);
          If Not OptionJSONDiag Then
          Begin
            WriteLn('');
            WriteLn(Format('==> Compiling Target [%s] (%s): "%s"', [ProjConfig.Targets[J].Name, ProjConfig.Targets[J].Target, ProjConfig.Targets[J].Entry]));
          End;
          TargetBackend := LowerCase(ProjConfig.Targets[J].Backend);
          If (TargetBackend = 'gcc') Or (TargetBackend = 'clang') Then
            TargetCC := TargetBackend
          Else
            TargetCC := ProjConfig.CCompiler;

          TargetIsLib := (ProjConfig.Targets[J].TargetType = 'cdylib') Or (ProjConfig.Targets[J].TargetType = 'lib') Or OptionSharedLib;

          CompileFile(TargetEntry, ProjConfig.Targets[J].Target, OptionCheckOnly, False,
                      TargetOut, OptionJSONDiag, OptionIncremental, OptionForce,
                      OptionRelease, OptionOptimize, ProjConfig.Targets[J].Backend, TargetCC,
                      TargetIsLib, OptionEmitHeader);
        End;
      End
      Else
      Begin
        CompileFile(InputFile, GlobalTargetKind, OptionCheckOnly, False,
                    OutputExe, OptionJSONDiag, OptionIncremental, OptionForce,
                    OptionRelease, OptionOptimize, GlobalBackendOverride, ProjConfig.CCompiler,
                    OptionSharedLib, OptionEmitHeader);
      End;

      If IsRunCommand And Not OptionCheckOnly Then
        Begin
          If OptionSharedLib Or (LowerCase(ExtractFileExt(OutputExe)) = '.dll') Or (LowerCase(ExtractFileExt(OutputExe)) = '.so') Or (LowerCase(ExtractFileExt(OutputExe)) = '.dylib') Or GlobalAsUnit Or (GlobalTargetKind = 'wasm') Or (GlobalTargetKind = 'js') Then
            Begin
              WriteLn('');
              WriteLn('Warning: Project compiled as a shared library, unit, or Web module.');
              WriteLn('Shared libraries do not have a direct native executable entry point for "run".');
            End
          Else
            Begin
              WriteLn('');
              WriteLn('--------------------------------------------------------');
              WriteLn(' Running: ' + ExtractFileName(OutputExe));
              WriteLn('--------------------------------------------------------');
              ExecuteProcess(OutputExe, '');
            End;
        End;
      Halt(0);
    Except
      on E: EAetherBorrowError Do
            Begin
              If OptionJSONDiag Then
                WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', E.Code, E.
                        Message, E.Line, E.Col, E.MovedLine, E.MovedCol,
                        'borrow_instead_of_move',

'Change the call to "borrow" if ownership transfer is not required.'
                        , 'borrow'))
              Else
                WriteLn(ErrOutput, 'Compilation Error: ', E.Message);
              Halt(1);
            End;
      on E: EAetherTypeError Do
            Begin
              If OptionJSONDiag Then
                WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', E.Code, E.
                        Message, E.Line, E.Col))
              Else
                WriteLn(ErrOutput, 'Compilation Error: ', E.Message);
              Halt(1);
            End;
      on E: EAetherParserError Do
            Begin
              If OptionJSONDiag Then
                WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', 'E0001', E.
                        Message, E.Line, E.Col))
              Else
                WriteLn(ErrOutput, 'Compilation Error: ', E.Message);
              Halt(1);
            End;
      on E: EAetherLexerError Do
            Begin
              If OptionJSONDiag Then
                WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', 'E0000', E.
                        Message, E.Line, E.Col))
              Else
                WriteLn(ErrOutput, 'Compilation Error: ', E.Message);
              Halt(1);
            End;
      on E: Exception Do
            Begin
              If OptionJSONDiag Then
                WriteLn(GenerateJSONDiagnostic(InputFile, 'Error', 'E9999', E.
                        Message, 1, 1))
              Else
                WriteLn(ErrOutput, 'Compilation Error: ', E.Message);
              Halt(1);
            End;
  End;
End;

I := 1;
While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);
    If ParsePathFlag(Arg, I) Then
      // Consumed by path flag (-I, -Fu, -L, -l, --c-source, --shared-lib)
    Else If (Arg = '-h') Or (Arg = '--help') Then
      Begin
        PrintBanner;
        PrintUsage;
        Halt(0);
      End
    Else If Arg = '--doctor' Then
           Begin
             PrintBanner;
             PrintDoctorReport;
             Halt(0);
           End
    Else If (Arg = '--lsp') Or (Arg = 'lsp') Then
           Begin
             RunAetherLSP;
             Halt(0);
           End
    Else If Arg = '--dump-tokens' Then
           OptionDumpTokens := True
    Else If Arg = '--dump-ast' Then
           OptionDumpAST := True
    Else If Arg = '--check-only' Then
           OptionCheckOnly := True
    Else If Arg = '--incremental' Then
           OptionIncremental := True
    Else If Arg = '--no-incremental' Then
           OptionIncremental := False
    Else If Arg = '--force' Then
           OptionForce := True
    Else If (Arg = '--lib') Or (Arg = '--shared') Then
           OptionSharedLib := True
    Else If Arg = '--emit-header' Then
           OptionEmitHeader := True
    Else If Arg = '--release' Then
           Begin
             OptionRelease := True;
             OptionOptimize := True;
           End
    Else If (Arg = '--opt') Or (Arg = '-O') Then
           OptionOptimize := True
    Else If Arg = '--target=pascal' Then
           OptionTargetPascal := True
    Else If Arg = '--target=c' Then
           OptionTargetPascal := False
    Else If (Arg = '--emit-json-diag') Or (Arg = '--emit-json-diagnostics') Then
           OptionJSONDiag := True
    Else If Arg = '-o' Then
           Begin
             Inc(I);
             If I <= ParamCount Then OutputExe := ParamStr(I);
           End
    Else If (Length(Arg) > 0) And (Arg[1] <> '-') Then
           Begin
             InputFile := Arg;
           End;
    Inc(I);
  End;

If Not OptionJSONDiag Then
  PrintBanner;

If InputFile = '' Then
  Begin
    If OptionJSONDiag Then
      WriteLn(GenerateJSONDiagnostic('', 'Error', 'E0001',
              'No .aeth source file specified.', 0, 0))
    Else
      Begin
        WriteLn('Error: No .aeth source file specified.');
        WriteLn('');
        PrintUsage;
      End;
    Halt(1);
  End;

Try
  If OptionDumpTokens Then
    DumpTokens(InputFile);

  If GlobalSourceFileDisplay <> '' Then
    DisplaySrcFile := GlobalSourceFileDisplay
  Else
    DisplaySrcFile := InputFile;

  CompileFile(InputFile, GlobalTargetKind, OptionCheckOnly, OptionDumpAST,
              OutputExe, OptionJSONDiag, OptionIncremental, OptionForce,
              OptionRelease, OptionOptimize, GlobalBackendOverride, GlobalCCompiler,
              OptionSharedLib, OptionEmitHeader);
Except
  on E: EAetherBorrowError Do
        Begin
          If OptionJSONDiag Then
            WriteLn(GenerateJSONDiagnostic(DisplaySrcFile, 'Error', E.Code, E.Message
                    , E.Line, E.Col, E.MovedLine, E.MovedCol,
                    'borrow_instead_of_move',

'Change the call to "borrow" if ownership transfer is not required.'
                    , 'borrow'))
          Else
            WriteLn(ErrOutput, 'Compilation Error: ', E.Message);
          Halt(1);
        End;
  on E: EAetherTypeError Do
        Begin
          If OptionJSONDiag Then
            WriteLn(GenerateJSONDiagnostic(DisplaySrcFile, 'Error', E.Code, E.Message
                    , E.Line, E.Col))
          Else
            WriteLn(ErrOutput, 'Compilation Error: ', E.Message);
          Halt(1);
        End;
  on E: EAetherParserError Do
        Begin
          If OptionJSONDiag Then
            WriteLn(GenerateJSONDiagnostic(DisplaySrcFile, 'Error', 'E0001', E.
                    Message, E.Line, E.Col))
          Else
            WriteLn(ErrOutput, 'Compilation Error: ', E.Message);
          Halt(1);
        End;
  on E: EAetherLexerError Do
        Begin
          If OptionJSONDiag Then
            WriteLn(GenerateJSONDiagnostic(DisplaySrcFile, 'Error', 'E0000', E.
                    Message, E.Line, E.Col))
          Else
            WriteLn(ErrOutput, 'Compilation Error: ', E.Message);
          Halt(1);
        End;
  on E: Exception Do
        Begin
          If OptionJSONDiag Then
            WriteLn(GenerateJSONDiagnostic(DisplaySrcFile, 'Error', 'E9999', E.
                    Message, 1 + GlobalLineOffset, 1))
          Else
            WriteLn(ErrOutput, 'Compilation Error: ', E.Message);
          Halt(1);
        End;
End;
End.
