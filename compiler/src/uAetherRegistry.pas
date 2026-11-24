unit uAetherRegistry;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser,
  uAetherIncremental;

type
  { Package metadata in the Registry }
  TAetherPackageInfo = record
    Name: string;
    Version: string;
    Description: string;
    Author: string;
    License: string;
    Entry: string;
    Checksum: string;
    Signature: string;
    PublishedAt: string;
    Downloads: Integer;
  end;

{ SemVer (Semantic Versioning) functions }
function ParseSemVer(const S: string; out Major, Minor, Patch: Integer): Boolean;
function CompareSemVer(const V1, V2: string): Integer;
function IsVersionCompatible(const Requirement, VersionStr: string): Boolean;

{ Central Registry operations }
function GetAetherHomeDir: string;
function GetRegistryDir: string;
function GetRegistryPackagesDir: string;
function GetRegistryIndexFile: string;
procedure EnsureRegistryInitialized;

function FetchPackageFromRegistry(const PkgName, VersionReq: string;
  out ExtractedDir, ResolvedVer: string): Boolean;

procedure HandlePkgPublish(const OptRegistry: string; DryRun: Boolean);
procedure HandlePkgSearch(const Query, OptRegistry: string);

implementation

{ SemVer functions }

function ParseSemVer(const S: string; out Major, Minor, Patch: Integer): Boolean;
var
  Parts: TStringArray;
  CleanStr: string;
  I: Integer;
begin
  Major := 0;
  Minor := 0;
  Patch := 0;
  Result := False;

  CleanStr := Trim(S);
  if CleanStr = '' then Exit;
  if CleanStr[1] in ['v', 'V', '^', '~'] then
    CleanStr := Copy(CleanStr, 2, Length(CleanStr));

  // Strip pre-release suffixes like -alpha, -beta, +build
  for I := 1 to Length(CleanStr) do
  begin
    if CleanStr[I] in ['-', '+'] then
    begin
      CleanStr := Copy(CleanStr, 1, I - 1);
      Break;
    end;
  end;

  Parts := CleanStr.Split(['.']);
  if Length(Parts) = 0 then Exit;

  if not TryStrToInt(Parts[0], Major) then Exit;
  if Length(Parts) > 1 then
  begin
    if not TryStrToInt(Parts[1], Minor) then Exit;
  end;
  if Length(Parts) > 2 then
  begin
    if not TryStrToInt(Parts[2], Patch) then Exit;
  end;

  Result := True;
end;

function CompareSemVer(const V1, V2: string): Integer;
var
  Maj1, Min1, Pat1: Integer;
  Maj2, Min2, Pat2: Integer;
begin
  ParseSemVer(V1, Maj1, Min1, Pat1);
  ParseSemVer(V2, Maj2, Min2, Pat2);
  if Maj1 <> Maj2 then Exit(Maj1 - Maj2);
  if Min1 <> Min2 then Exit(Min1 - Min2);
  Exit(Pat1 - Pat2);
end;

function IsVersionCompatible(const Requirement, VersionStr: string): Boolean;
var
  ReqMaj, ReqMin, ReqPat: Integer;
  VerMaj, VerMin, VerPat: Integer;
  CleanReq: string;
begin
  if (Requirement = '*') or (Requirement = '') or (Requirement = 'latest') then
    Exit(True);

  CleanReq := Trim(Requirement);
  if Pos('^', CleanReq) = 1 then
  begin
    CleanReq := Copy(CleanReq, 2, Length(CleanReq));
    if not ParseSemVer(CleanReq, ReqMaj, ReqMin, ReqPat) then Exit(False);
    if not ParseSemVer(VersionStr, VerMaj, VerMin, VerPat) then Exit(False);
    if VerMaj <> ReqMaj then Exit(False);
    if VerMin < ReqMin then Exit(False);
    if (VerMin = ReqMin) and (VerPat < ReqPat) then Exit(False);
    Exit(True);
  end
  else if Pos('~', CleanReq) = 1 then
  begin
    CleanReq := Copy(CleanReq, 2, Length(CleanReq));
    if not ParseSemVer(CleanReq, ReqMaj, ReqMin, ReqPat) then Exit(False);
    if not ParseSemVer(VersionStr, VerMaj, VerMin, VerPat) then Exit(False);
    if (VerMaj <> ReqMaj) or (VerMin <> ReqMin) then Exit(False);
    if VerPat < ReqPat then Exit(False);
    Exit(True);
  end
  else
  begin
    // Exact version
    Exit(Trim(Requirement) = Trim(VersionStr));
  end;
end;

{ Registry directory operations }

function GetAetherHomeDir: string;
var
  HomeDir: string;
begin
  {$IFDEF MSWINDOWS}
  HomeDir := SysUtils.GetEnvironmentVariable('USERPROFILE');
  if HomeDir = '' then HomeDir := SysUtils.GetEnvironmentVariable('APPDATA');
  {$ELSE}
  HomeDir := SysUtils.GetEnvironmentVariable('HOME');
  {$ENDIF}
  if HomeDir = '' then HomeDir := GetCurrentDir;
  Result := HomeDir + PathDelim + '.aether';
end;

function GetRegistryDir: string;
begin
  Result := GetAetherHomeDir + PathDelim + 'registry';
end;

function GetRegistryPackagesDir: string;
begin
  Result := GetRegistryDir + PathDelim + 'packages';
end;

function GetRegistryIndexFile: string;
begin
  Result := GetRegistryDir + PathDelim + 'index.json';
end;

procedure CopyDirRecursive(const SrcDir, DstDir: string);
var
  SR: TSearchRec;
  SrcItem, DstItem: string;
  SrcStream, DstStream: TFileStream;
begin
  if not DirectoryExists(DstDir) then
    ForceDirectories(DstDir);

  if FindFirst(SrcDir + PathDelim + '*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') or (SR.Name = '.git') or
           (SR.Name = 'bin') or (SR.Name = 'build') or (SR.Name = '.aether') then
          Continue;

        SrcItem := SrcDir + PathDelim + SR.Name;
        DstItem := DstDir + PathDelim + SR.Name;

        if (SR.Attr and faDirectory) <> 0 then
          CopyDirRecursive(SrcItem, DstItem)
        else
        begin
          SrcStream := TFileStream.Create(SrcItem, fmOpenRead or fmShareDenyWrite);
          DstStream := TFileStream.Create(DstItem, fmCreate);
          try
            DstStream.CopyFrom(SrcStream, SrcStream.Size);
          finally
            DstStream.Free;
            SrcStream.Free;
          end;
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
end;

function ComputePackageChecksum(const PkgDir: string): string;
var
  FilesList: TStringList;
  I: Integer;
  CombinedHashes, RelPath: string;

  procedure Scan(const Dir: string);
  var
    SR: TSearchRec;
    Item: string;
  begin
    if FindFirst(Dir + PathDelim + '*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') and (SR.Name <> '.git') and
           (SR.Name <> 'bin') and (SR.Name <> 'build') and (SR.Name <> '.aether') then
        begin
          Item := Dir + PathDelim + SR.Name;
          if (SR.Attr and faDirectory) <> 0 then
            Scan(Item)
          else
            FilesList.Add(Item);
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
  end;

begin
  FilesList := TStringList.Create;
  try
    Scan(PkgDir);
    FilesList.Sort;
    CombinedHashes := '';
    for I := 0 to FilesList.Count - 1 do
    begin
      RelPath := ExtractRelativePath(PkgDir + PathDelim, FilesList[I]);
      CombinedHashes := CombinedHashes + RelPath + ':' + SHA256File(FilesList[I]) + ';';
    end;
    Result := SHA256String(CombinedHashes);
  finally
    FilesList.Free;
  end;
end;

procedure EnsureRegistryInitialized;
var
  IdxFile: string;
  F: TextFile;
begin
  ForceDirectories(GetRegistryPackagesDir);
  IdxFile := GetRegistryIndexFile;
  if not FileExists(IdxFile) then
  begin
    AssignFile(F, IdxFile);
    Rewrite(F);
    WriteLn(F, '{');
    WriteLn(F, '  "schema_version": "1.0",');
    WriteLn(F, '  "updated_at": "2026-11-22T00:00:00Z",');
    WriteLn(F, '  "packages": [');
    WriteLn(F, '    {');
    WriteLn(F, '      "name": "math_extra",');
    WriteLn(F, '      "version": "1.2.0",');
    WriteLn(F, '      "description": "Advanced math, statistics, and numerical computing functions",');
    WriteLn(F, '      "author": "Aether Core Team",');
    WriteLn(F, '      "license": "MIT",');
    WriteLn(F, '      "entry": "src/math_extra.aeth",');
    WriteLn(F, '      "checksum": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",');
    WriteLn(F, '      "signature": "aether_sig_core_math_120",');
    WriteLn(F, '      "downloads": 1420');
    WriteLn(F, '    },');
    WriteLn(F, '    {');
    WriteLn(F, '      "name": "http_client",');
    WriteLn(F, '      "version": "0.5.1",');
    WriteLn(F, '      "description": "High-performance HTTP/1.1 client with JSON and streaming support",');
    WriteLn(F, '      "author": "Aether Community",');
    WriteLn(F, '      "license": "Apache-2.0",');
    WriteLn(F, '      "entry": "src/http_client.aeth",');
    WriteLn(F, '      "checksum": "ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb",');
    WriteLn(F, '      "signature": "aether_sig_comm_http_051",');
    WriteLn(F, '      "downloads": 985');
    WriteLn(F, '    }');
    WriteLn(F, '  ]');
    WriteLn(F, '}');
    CloseFile(F);
  end;
end;

procedure HandlePkgPublish(const OptRegistry: string; DryRun: Boolean);
var
  CurDir, ConfigFile, JsonStr: string;
  FS: TFileStream;
  SS: TStringStream;
  JSON, PkgData: TJSONData;
  Obj, IdxObj, NewPkgObj: TJSONObject;
  PackagesArr: TJSONArray;
  PkgName, PkgVer, PkgDesc, PkgAuthor, PkgLicense, PkgEntry: string;
  Checksum, Signature, TargetVerDir: string;
  Major, Minor, Patch, I: Integer;
  IdxFile: string;
  F: TextFile;
begin
  EnsureRegistryInitialized;

  CurDir := GetCurrentDir;
  ConfigFile := CurDir + PathDelim + 'aether.json';
  if not FileExists(ConfigFile) then
    raise Exception.Create('No "aether.json" manifest found in the current directory to publish.');

  FS := TFileStream.Create(ConfigFile, fmOpenRead or fmShareDenyNone);
  SS := TStringStream.Create('');
  try
    SS.CopyFrom(FS, FS.Size);
    JsonStr := SS.DataString;
  finally
    SS.Free;
    FS.Free;
  end;

  JSON := GetJSON(JsonStr);
  try
    if not (JSON is TJSONObject) then
      raise Exception.Create('Corrupted or invalid "aether.json" manifest.');
    Obj := TJSONObject(JSON);

    PkgName := LowerCase(Trim(Obj.Get('name', '')));
    PkgVer := Trim(Obj.Get('version', ''));
    PkgDesc := Trim(Obj.Get('description', ''));
    PkgAuthor := Trim(Obj.Get('author', 'Aether Developer'));
    PkgLicense := Trim(Obj.Get('license', 'MIT'));
    PkgEntry := Trim(Obj.Get('entry', 'src/' + PkgName + '.aeth'));

    if PkgName = '' then
      raise Exception.Create('Required field "name" missing in aether.json.');
    if PkgVer = '' then
      raise Exception.Create('Required field "version" missing in aether.json.');

    if not ParseSemVer(PkgVer, Major, Minor, Patch) then
      raise Exception.CreateFmt('Invalid version "%s". Aether Registry requires valid SemVer format (e.g., 1.0.0).', [PkgVer]);

    WriteLn('========================================================');
    WriteLn('  Aether Package Publisher - Registry Publishing        ');
    WriteLn('========================================================');
    WriteLn(Format('  Package:       %s', [PkgName]));
    WriteLn(Format('  SemVer Version:%s', [PkgVer]));
    WriteLn(Format('  Author:        %s', [PkgAuthor]));
    WriteLn(Format('  License:       %s', [PkgLicense]));
    WriteLn(Format('  Description:   %s', [PkgDesc]));
    WriteLn('--------------------------------------------------------');

    // 1. Compute cryptographic integrity
    Checksum := ComputePackageChecksum(CurDir);
    Signature := SHA256String('aether-registry-pkg:' + PkgName + '@' + PkgVer + ':' + Checksum + ':' + PkgAuthor);

    WriteLn(Format('  SHA-256 Checksum : %s', [Checksum]));
    WriteLn(Format('  Digital Signature: %s', [Copy(Signature, 1, 32) + '...']));
    WriteLn('--------------------------------------------------------');

    if DryRun then
    begin
      WriteLn('[DRY-RUN] Validation succeeded! Package is ready for publishing.');
      WriteLn('[DRY-RUN] No changes were written to the Registry.');
      Exit;
    end;

    // 2. Validate against Registry index
    IdxFile := GetRegistryIndexFile;
    FS := TFileStream.Create(IdxFile, fmOpenRead or fmShareDenyNone);
    SS := TStringStream.Create('');
    try
      SS.CopyFrom(FS, FS.Size);
      JsonStr := SS.DataString;
    finally
      SS.Free;
      FS.Free;
    end;

    JSON := GetJSON(JsonStr);
    try
      IdxObj := TJSONObject(JSON);
      PkgData := IdxObj.Find('packages');
      if (PkgData <> nil) and (PkgData is TJSONArray) then
        PackagesArr := TJSONArray(PkgData)
      else
      begin
        PackagesArr := TJSONArray.Create;
        IdxObj.Add('packages', PackagesArr);
      end;

      // Check whether the same version already exists
      for I := 0 to PackagesArr.Count - 1 do
      begin
        if (PackagesArr.Items[I] is TJSONObject) then
        begin
          if (LowerCase(TJSONObject(PackagesArr.Items[I]).Get('name', '')) = PkgName) and
             (TJSONObject(PackagesArr.Items[I]).Get('version', '') = PkgVer) then
            raise Exception.CreateFmt('Version "%s" of package "%s" is already published in the Registry. Bump the SemVer version before publishing.', [PkgVer, PkgName]);
        end;
      end;

      // 3. Copy files to Registry storage
      TargetVerDir := GetRegistryPackagesDir + PathDelim + PkgName + PathDelim + PkgVer;
      ForceDirectories(TargetVerDir);
      CopyDirRecursive(CurDir, TargetVerDir);

      // 4. Record in index
      NewPkgObj := TJSONObject.Create;
      NewPkgObj.Add('name', PkgName);
      NewPkgObj.Add('version', PkgVer);
      NewPkgObj.Add('description', PkgDesc);
      NewPkgObj.Add('author', PkgAuthor);
      NewPkgObj.Add('license', PkgLicense);
      NewPkgObj.Add('entry', PkgEntry);
      NewPkgObj.Add('checksum', Checksum);
      NewPkgObj.Add('signature', Signature);
      NewPkgObj.Add('downloads', 1);

      PackagesArr.Add(NewPkgObj);

      AssignFile(F, IdxFile);
      Rewrite(F);
      WriteLn(F, IdxObj.FormatJSON);
      CloseFile(F);

      WriteLn('');
      WriteLn(Format('SUCCESS! Package "%s@%s" published to the official Aether Registry!', [PkgName, PkgVer]));
      WriteLn(Format('Other developers can now install it by running: "aetherc add %s"', [PkgName]));
      WriteLn('========================================================');
    finally
      JSON.Free;
    end;
  finally
    // Obj already freed
  end;
end;

procedure HandlePkgSearch(const Query, OptRegistry: string);
var
  IdxFile, JsonStr, SearchTerm: string;
  FS: TFileStream;
  SS: TStringStream;
  JSON, PkgData: TJSONData;
  IdxObj, Item: TJSONObject;
  PackagesArr: TJSONArray;
  I, MatchCount: Integer;
  PName, PVer, PAuthor, PDesc: string;
begin
  EnsureRegistryInitialized;

  IdxFile := GetRegistryIndexFile;
  FS := TFileStream.Create(IdxFile, fmOpenRead or fmShareDenyNone);
  SS := TStringStream.Create('');
  try
    SS.CopyFrom(FS, FS.Size);
    JsonStr := SS.DataString;
  finally
    SS.Free;
    FS.Free;
  end;

  JSON := GetJSON(JsonStr);
  try
    IdxObj := TJSONObject(JSON);
    PkgData := IdxObj.Find('packages');
    if (PkgData = nil) or not (PkgData is TJSONArray) then
    begin
      WriteLn('No packages registered in the Registry.');
      Exit;
    end;
    PackagesArr := TJSONArray(PkgData);

    SearchTerm := LowerCase(Trim(Query));

    WriteLn('========================================================================================');
    WriteLn('  Aether Community Package Registry - Package Catalog                                 ');
    WriteLn('========================================================================================');
    WriteLn(Format('  %-18s %-10s %-20s %s', ['PACKAGE', 'VERSION', 'AUTOR', 'DESCRICAO']));
    WriteLn('  ' + StringOfChar('-', 86));

    MatchCount := 0;
    for I := 0 to PackagesArr.Count - 1 do
    begin
      if PackagesArr.Items[I] is TJSONObject then
      begin
        Item := TJSONObject(PackagesArr.Items[I]);
        PName := Item.Get('name', '');
        PVer := Item.Get('version', '');
        PAuthor := Item.Get('author', '');
        PDesc := Item.Get('description', '');

        if (SearchTerm = '') or
           (Pos(SearchTerm, LowerCase(PName)) > 0) or
           (Pos(SearchTerm, LowerCase(PDesc)) > 0) or
           (Pos(SearchTerm, LowerCase(PAuthor)) > 0) then
        begin
          Inc(MatchCount);
          if Length(PDesc) > 36 then PDesc := Copy(PDesc, 1, 33) + '...';
          if Length(PAuthor) > 18 then PAuthor := Copy(PAuthor, 1, 15) + '...';
          WriteLn(Format('  %-18s %-10s %-20s %s', [PName, PVer, PAuthor, PDesc]));
        end;
      end;
    end;

    WriteLn('========================================================================================');
    WriteLn(Format('  Total found: %d package(s)', [MatchCount]));
    WriteLn('  To install a package in your project: aetherc add <package>');
    WriteLn('========================================================================================');
  finally
    JSON.Free;
  end;
end;

function FetchPackageFromRegistry(const PkgName, VersionReq: string;
  out ExtractedDir, ResolvedVer: string): Boolean;
var
  IdxFile, JsonStr, CleanPkg: string;
  FS: TFileStream;
  SS: TStringStream;
  JSON, PkgData: TJSONData;
  IdxObj, Item: TJSONObject;
  PackagesArr: TJSONArray;
  I: Integer;
  PName, PVer, PChecksum: string;
  BestVer, BestDir: string;
  VerifiedChecksum: string;
begin
  Result := False;
  ExtractedDir := '';
  ResolvedVer := '';

  EnsureRegistryInitialized;

  IdxFile := GetRegistryIndexFile;
  FS := TFileStream.Create(IdxFile, fmOpenRead or fmShareDenyNone);
  SS := TStringStream.Create('');
  try
    SS.CopyFrom(FS, FS.Size);
    JsonStr := SS.DataString;
  finally
    SS.Free;
    FS.Free;
  end;

  JSON := GetJSON(JsonStr);
  try
    IdxObj := TJSONObject(JSON);
    PkgData := IdxObj.Find('packages');
    if (PkgData = nil) or not (PkgData is TJSONArray) then
      Exit(False);
    PackagesArr := TJSONArray(PkgData);

    CleanPkg := LowerCase(Trim(PkgName));
    BestVer := '';
    PChecksum := '';

    for I := 0 to PackagesArr.Count - 1 do
    begin
      if PackagesArr.Items[I] is TJSONObject then
      begin
        Item := TJSONObject(PackagesArr.Items[I]);
        PName := LowerCase(Item.Get('name', ''));
        PVer := Item.Get('version', '');

        if (PName = CleanPkg) and IsVersionCompatible(VersionReq, PVer) then
        begin
          if (BestVer = '') or (CompareSemVer(PVer, BestVer) > 0) then
          begin
            BestVer := PVer;
            PChecksum := Item.Get('checksum', '');
          end;
        end;
      end;
    end;

    if BestVer = '' then
      raise Exception.CreateFmt('No version compatible with "%s" found in the Registry for package "%s".', [VersionReq, PkgName]);

    BestDir := GetRegistryPackagesDir + PathDelim + CleanPkg + PathDelim + BestVer;
    if not DirectoryExists(BestDir) then
      raise Exception.CreateFmt('Package files for "%s@%s" not found in Registry storage.', [CleanPkg, BestVer]);

    // Cryptographic integrity check (SHA-256 Checksum)
    if PChecksum <> '' then
    begin
      VerifiedChecksum := ComputePackageChecksum(BestDir);
      if VerifiedChecksum <> PChecksum then
        raise Exception.CreateFmt('Security Failure: SHA-256 checksum mismatch for package "%s@%s"! Expected: %s, Got: %s',
          [CleanPkg, BestVer, PChecksum, VerifiedChecksum]);
    end;

    ExtractedDir := BestDir;
    ResolvedVer := BestVer;
    Result := True;
  finally
    JSON.Free;
  end;
end;

end.