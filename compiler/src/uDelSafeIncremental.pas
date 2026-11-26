unit uDelSafeIncremental;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser;

type
  PFileCacheItem = ^TFileCacheItem;
  TFileCacheItem = record
    Path: string;
    Hash: string;
    FileSize: Int64;
    LastModified: Int64;
  end;

  { TDelSafeBuildCache }
  TDelSafeBuildCache = class
  private
    FTargetBackend: string;
    FSourceFile: string;
    FOutputExe: string;
    FOutputExeHash: string;
    FCompilerVersion: string;
    FFiles: TFPList;
    function FindItem(const APath: string): PFileCacheItem;
    procedure ClearFiles;
    function GetFileCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddFile(const APath, AHash: string; ASize, AModTime: Int64);
    function LoadFromFile(const CachePath: string): Boolean;
    function SaveToFile(const CachePath: string): Boolean;
    function IsUpToDate(const AllFiles: TStrings; const CurrentOutputExe: string; out Reason: string): Boolean;

    property Files: TFPList read FFiles;
    property FileCount: Integer read GetFileCount;
    property TargetBackend: string read FTargetBackend write FTargetBackend;
    property SourceFile: string read FSourceFile write FSourceFile;
    property OutputExe: string read FOutputExe write FOutputExe;
    property OutputExeHash: string read FOutputExeHash write FOutputExeHash;
    property CompilerVersion: string read FCompilerVersion write FCompilerVersion;
  end;

// Official DelSafe toolchain version
const
  DELSAFE_COMPILER_VERSION = '0.5.1';

// Standalone high-performance SHA-256 cryptographic functions
function SHA256String(const S: string): string;
function SHA256File(const AFilePath: string): string;

// Incremental Build Cache Management
function GetBuildCacheDir(const BaseDir: string): string;
function GetBuildCachePath(const BaseDir, SourceFile, TargetBackend: string): string;
function CheckIncrementalBuild(const BaseDir, SourceFile, TargetBackend, OutputExe: string;
                               const DependencyFiles: TStrings; ForceRebuild: Boolean;
                               out Reason: string): Boolean;
procedure SaveBuildCache(const BaseDir, SourceFile, TargetBackend, OutputExe: string;
                         const DependencyFiles: TStrings);
procedure InvalidateBuildCache(const BaseDir, SourceFile, TargetBackend: string);

implementation

const
  K256: array[0..63] of Cardinal = (
    $428a2f98, $71374491, $b5c0fbcf, $e9b5dba5, $3956c25b, $59f111f1, $923f82a4, $ab1c5ed5,
    $d807aa98, $12835b01, $243185be, $550c7dc3, $72be5d74, $80deb1fe, $9bdc06a7, $c19bf174,
    $e49b69c1, $efbe4786, $0fc19dc6, $240ca1cc, $2de92c6f, $4a7484aa, $5cb0a9dc, $76f988da,
    $983e5152, $a831c66d, $b00327c8, $bf597fc7, $c6e00bf3, $d5a79147, $06ca6351, $14292967,
    $27b70a85, $2e1b2138, $4d2c6dfc, $53380d13, $650a7354, $766a0abb, $81c2c92e, $92722c85,
    $a2bfe8a1, $a81a664b, $c24b8b70, $c76c51a3, $d192e819, $d6990624, $f40e3585, $106aa070,
    $19a4c116, $1e376c08, $2748774c, $34b0bcb5, $391c0cb3, $4ed8aa4a, $5b9cca4f, $682e6ff3,
    $748f82ee, $78a5636f, $84c87814, $8cc70208, $90befffa, $a4506ceb, $bef9a3f7, $c67178f2
  );

type
  TSHA256Context = record
    State: array[0..7] of Cardinal;
    Count: QWord;
    Buffer: array[0..63] of Byte;
  end;

function ROR(X: Cardinal; N: Byte): Cardinal; inline;
begin
  Result := (X shr N) or (X shl (32 - N));
end;

procedure SHA256Init(var Ctx: TSHA256Context);
begin
  Ctx.State[0] := $6a09e667;
  Ctx.State[1] := $bb67ae85;
  Ctx.State[2] := $3c6ef372;
  Ctx.State[3] := $a54ff53a;
  Ctx.State[4] := $510e527f;
  Ctx.State[5] := $9b05688c;
  Ctx.State[6] := $1f83d9ab;
  Ctx.State[7] := $5be0cd19;
  Ctx.Count := 0;
  FillChar(Ctx.Buffer, SizeOf(Ctx.Buffer), 0);
end;

procedure SHA256Transform(var Ctx: TSHA256Context; const Data: array of Byte; Offset: Integer);
var
  W: array[0..63] of Cardinal;
  A, B, C, D, E, F, G, H: Cardinal;
  S0, S1, Maj, Ch, Temp1, Temp2: Cardinal;
  I: Integer;
begin
  for I := 0 to 15 do
  begin
    W[I] := (Cardinal(Data[Offset + (I * 4)]) shl 24) or
            (Cardinal(Data[Offset + (I * 4) + 1]) shl 16) or
            (Cardinal(Data[Offset + (I * 4) + 2]) shl 8) or
            (Cardinal(Data[Offset + (I * 4) + 3]));
  end;

  for I := 16 to 63 do
  begin
    S0 := ROR(W[I - 15], 7) xor ROR(W[I - 15], 18) xor (W[I - 15] shr 3);
    S1 := ROR(W[I - 2], 17) xor ROR(W[I - 2], 19) xor (W[I - 2] shr 10);
    W[I] := W[I - 16] + S0 + W[I - 7] + S1;
  end;

  A := Ctx.State[0];
  B := Ctx.State[1];
  C := Ctx.State[2];
  D := Ctx.State[3];
  E := Ctx.State[4];
  F := Ctx.State[5];
  G := Ctx.State[6];
  H := Ctx.State[7];

  for I := 0 to 63 do
  begin
    S1 := ROR(E, 6) xor ROR(E, 11) xor ROR(E, 25);
    Ch := (E and F) xor ((not E) and G);
    Temp1 := H + S1 + Ch + K256[I] + W[I];
    S0 := ROR(A, 2) xor ROR(A, 13) xor ROR(A, 22);
    Maj := (A and B) xor (A and C) xor (B and C);
    Temp2 := S0 + Maj;

    H := G;
    G := F;
    F := E;
    E := D + Temp1;
    D := C;
    C := B;
    B := A;
    A := Temp1 + Temp2;
  end;

  Inc(Ctx.State[0], A);
  Inc(Ctx.State[1], B);
  Inc(Ctx.State[2], C);
  Inc(Ctx.State[3], D);
  Inc(Ctx.State[4], E);
  Inc(Ctx.State[5], F);
  Inc(Ctx.State[6], G);
  Inc(Ctx.State[7], H);
end;

procedure SHA256Update(var Ctx: TSHA256Context; const Data: PByte; Len: Cardinal);
var
  Left, Fill, P: Cardinal;
begin
  if Len = 0 then Exit;
  Left := Cardinal(Ctx.Count and $3F);
  Fill := 64 - Left;
  Inc(Ctx.Count, Len);
  P := 0;

  if (Left > 0) and (Len >= Fill) then
  begin
    Move(Data[0], Ctx.Buffer[Left], Fill);
    SHA256Transform(Ctx, Ctx.Buffer, 0);
    P := Fill;
    Dec(Len, Fill);
    Left := 0;
  end;

  while Len >= 64 do
  begin
    SHA256Transform(Ctx, PByteArray(Data)^, P);
    Inc(P, 64);
    Dec(Len, 64);
  end;

  if Len > 0 then
    Move(Data[P], Ctx.Buffer[Left], Len);
end;

function SHA256Final(var Ctx: TSHA256Context): string;
var
  Bits: QWord;
  PadLen: Cardinal;
  Padding: array[0..63] of Byte;
  BitBytes: array[0..7] of Byte;
  I: Integer;
begin
  Bits := Ctx.Count * 8;
  for I := 0 to 7 do
    BitBytes[7 - I] := Byte((Bits shr (I * 8)) and $FF);

  FillChar(Padding, SizeOf(Padding), 0);
  Padding[0] := $80;

  if (Ctx.Count and $3F) < 56 then
    PadLen := 56 - Cardinal(Ctx.Count and $3F)
  else
    PadLen := 120 - Cardinal(Ctx.Count and $3F);

  SHA256Update(Ctx, @Padding[0], PadLen);
  SHA256Update(Ctx, @BitBytes[0], 8);

  Result := '';
  for I := 0 to 7 do
    Result := Result + IntToHex(Ctx.State[I], 8);
  Result := LowerCase(Result);
end;

function SHA256String(const S: string): string;
var
  Ctx: TSHA256Context;
begin
  SHA256Init(Ctx);
  if Length(S) > 0 then
    SHA256Update(Ctx, PByte(@S[1]), Length(S));
  Result := SHA256Final(Ctx);
end;

function SHA256File(const AFilePath: string): string;
var
  F: TFileStream;
  Ctx: TSHA256Context;
  Buffer: array[0..65535] of Byte;
  BytesRead: Integer;
begin
  if not FileExists(AFilePath) then
    Exit('');

  try
    F := TFileStream.Create(AFilePath, fmOpenRead or fmShareDenyNone);
    try
      SHA256Init(Ctx);
      repeat
        BytesRead := F.Read(Buffer, SizeOf(Buffer));
        if BytesRead > 0 then
          SHA256Update(Ctx, @Buffer[0], BytesRead);
      until BytesRead <= 0;
      Result := SHA256Final(Ctx);
    finally
      F.Free;
    end;
  except
    Result := '';
  end;
end;

{ TDelSafeBuildCache }

constructor TDelSafeBuildCache.Create;
begin
  inherited Create;
  FFiles := TFPList.Create;
  FCompilerVersion := DELSAFE_COMPILER_VERSION;
end;

destructor TDelSafeBuildCache.Destroy;
begin
  ClearFiles;
  FFiles.Free;
  inherited Destroy;
end;

function TDelSafeBuildCache.GetFileCount: Integer;
begin
  if Assigned(FFiles) then
    Result := FFiles.Count
  else
    Result := 0;
end;

procedure TDelSafeBuildCache.ClearFiles;
var
  I: Integer;
  Item: PFileCacheItem;
begin
  for I := 0 to FFiles.Count - 1 do
  begin
    Item := PFileCacheItem(FFiles[I]);
    Dispose(Item);
  end;
  FFiles.Clear;
end;

function TDelSafeBuildCache.FindItem(const APath: string): PFileCacheItem;
var
  I: Integer;
  Item: PFileCacheItem;
  NormA, NormB: string;
begin
  NormA := LowerCase(ExpandFileName(APath));
  for I := 0 to FFiles.Count - 1 do
  begin
    Item := PFileCacheItem(FFiles[I]);
    NormB := LowerCase(ExpandFileName(Item^.Path));
    if NormA = NormB then
      Exit(Item);
  end;
  Result := nil;
end;

procedure TDelSafeBuildCache.AddFile(const APath, AHash: string; ASize, AModTime: Int64);
var
  Item: PFileCacheItem;
begin
  Item := FindItem(APath);
  if not Assigned(Item) then
  begin
    New(Item);
    FFiles.Add(Item);
  end;
  Item^.Path := APath;
  Item^.Hash := AHash;
  Item^.FileSize := ASize;
  Item^.LastModified := AModTime;
end;

function TDelSafeBuildCache.LoadFromFile(const CachePath: string): Boolean;
var
  Data: TJSONData;
  RootObj, FileObj: TJSONObject;
  FilesArr: TJSONArray;
  I: Integer;
  P, H, JsonStr: string;
  Sz, Mt: Int64;
  FStream: TFileStream;
  SStream: TStringStream;
begin
  Result := False;
  ClearFiles;
  if not FileExists(CachePath) then Exit;

  try
    FStream := TFileStream.Create(CachePath, fmOpenRead or fmShareDenyNone);
    SStream := TStringStream.Create('');
    try
      SStream.CopyFrom(FStream, FStream.Size);
      JsonStr := SStream.DataString;
    finally
      SStream.Free;
      FStream.Free;
    end;

    Data := GetJSON(JsonStr);
    try
      if Assigned(Data) and (Data is TJSONObject) then
      begin
        RootObj := TJSONObject(Data);
        FTargetBackend := RootObj.Get('target', 'pascal');
        FSourceFile := RootObj.Get('source_file', '');
        FOutputExe := RootObj.Get('output_exe', '');
        FOutputExeHash := RootObj.Get('output_exe_hash', '');
        FCompilerVersion := RootObj.Get('compiler_version', '');

        FilesArr := RootObj.Get('files', TJSONArray(nil));
        if Assigned(FilesArr) then
        begin
          for I := 0 to FilesArr.Count - 1 do
          begin
            if FilesArr.Items[I] is TJSONObject then
            begin
              FileObj := TJSONObject(FilesArr.Items[I]);
              P := FileObj.Get('path', '');
              H := FileObj.Get('hash', '');
              Sz := FileObj.Get('size', Int64(0));
              Mt := FileObj.Get('modified', Int64(0));
              if (P <> '') and (H <> '') then
                AddFile(P, H, Sz, Mt);
            end;
          end;
        end;
        Result := True;
      end;
    finally
      if Assigned(Data) then Data.Free;
    end;
  except
    Result := False;
  end;
end;

function TDelSafeBuildCache.SaveToFile(const CachePath: string): Boolean;
var
  RootObj, FileObj: TJSONObject;
  FilesArr: TJSONArray;
  I: Integer;
  Item: PFileCacheItem;
  FStr: TFileStream;
  JsonText: string;
begin
  Result := False;
  ForceDirectories(ExtractFileDir(CachePath));
  RootObj := TJSONObject.Create;
  try
    RootObj.Add('target', FTargetBackend);
    RootObj.Add('source_file', FSourceFile);
    RootObj.Add('output_exe', FOutputExe);
    RootObj.Add('output_exe_hash', FOutputExeHash);
    RootObj.Add('compiler_version', FCompilerVersion);
    RootObj.Add('timestamp', Int64(DateTimeToFileDate(Now)));

    FilesArr := TJSONArray.Create;
    for I := 0 to FFiles.Count - 1 do
    begin
      Item := PFileCacheItem(FFiles[I]);
      FileObj := TJSONObject.Create;
      FileObj.Add('path', Item^.Path);
      FileObj.Add('hash', Item^.Hash);
      FileObj.Add('size', Item^.FileSize);
      FileObj.Add('modified', Item^.LastModified);
      FilesArr.Add(FileObj);
    end;
    RootObj.Add('files', FilesArr);

    JsonText := RootObj.FormatJSON();
    try
      FStr := TFileStream.Create(CachePath, fmCreate);
      try
        if Length(JsonText) > 0 then
          FStr.WriteBuffer(JsonText[1], Length(JsonText));
        Result := True;
      finally
        FStr.Free;
      end;
    except
      Result := False;
    end;
  finally
    RootObj.Free;
  end;
end;

function TDelSafeBuildCache.IsUpToDate(const AllFiles: TStrings; const CurrentOutputExe: string; out Reason: string): Boolean;
var
  I: Integer;
  FilePath, CurrentHash: string;
  Item: PFileCacheItem;
  AgeVal: LongInt;
begin
  Reason := '';

  // 1. Final executable must exist
  if not FileExists(CurrentOutputExe) then
  begin
    Reason := 'Executable missing on disk';
    Exit(False);
  end;

  // 2. Compiler version
  if FCompilerVersion <> DELSAFE_COMPILER_VERSION then
  begin
    Reason := 'Compiler version was updated';
    Exit(False);
  end;

  // 3. All current files must exist in cache with matching hashes
  if AllFiles.Count = 0 then
  begin
    Reason := 'Dependency list is empty';
    Exit(False);
  end;

  for I := 0 to AllFiles.Count - 1 do
  begin
    FilePath := AllFiles[I];
    if not FileExists(FilePath) then
    begin
      Reason := Format('Dependency file not found: "%s"', [ExtractFileName(FilePath)]);
      Exit(False);
    end;

    Item := FindItem(FilePath);
    if not Assigned(Item) then
    begin
      Reason := Format('New dependency added: "%s"', [ExtractFileName(FilePath)]);
      Exit(False);
    end;

    // Quick timestamp check before computing full hash
    AgeVal := FileAge(FilePath);
    if (AgeVal <> Item^.LastModified) or (Item^.Hash = '') then
    begin
      CurrentHash := SHA256File(FilePath);
      if CurrentHash <> Item^.Hash then
      begin
        Reason := Format('Content modified: "%s"', [ExtractFileName(FilePath)]);
        Exit(False);
      end;
    end;
  end;

  // 4. Dependency count must match exactly
  if FFiles.Count <> AllFiles.Count then
  begin
    Reason := 'Dependency graph was modified';
    Exit(False);
  end;

  Reason := 'All files are cached and unchanged';
  Result := True;
end;

function GetBuildCacheDir(const BaseDir: string): string;
begin
  Result := BaseDir + PathDelim + '.delsafe' + PathDelim + 'cache' + PathDelim + 'build';
end;

function GetBuildCachePath(const BaseDir, SourceFile, TargetBackend: string): string;
var
  SafeName: string;
begin
  SafeName := ChangeFileExt(ExtractFileName(SourceFile), '') + '_' + LowerCase(TargetBackend) + '.cache.json';
  Result := GetBuildCacheDir(BaseDir) + PathDelim + SafeName;
end;

function CheckIncrementalBuild(const BaseDir, SourceFile, TargetBackend, OutputExe: string;
                               const DependencyFiles: TStrings; ForceRebuild: Boolean;
                               out Reason: string): Boolean;
var
  CachePath: string;
  Cache: TDelSafeBuildCache;
begin
  Reason := '';
  if ForceRebuild then
  begin
    Reason := 'Full rebuild forced (--force)';
    Exit(False);
  end;

  CachePath := GetBuildCachePath(BaseDir, SourceFile, TargetBackend);
  if not FileExists(CachePath) then
  begin
    Reason := 'No previous build cache found';
    Exit(False);
  end;

  Cache := TDelSafeBuildCache.Create;
  try
    if not Cache.LoadFromFile(CachePath) then
    begin
      Reason := 'Corrupted or invalid build cache';
      Exit(False);
    end;

    Result := Cache.IsUpToDate(DependencyFiles, OutputExe, Reason);
  finally
    Cache.Free;
  end;
end;

procedure SaveBuildCache(const BaseDir, SourceFile, TargetBackend, OutputExe: string;
                         const DependencyFiles: TStrings);
var
  CachePath, FilePath: string;
  Cache: TDelSafeBuildCache;
  I: Integer;
  FSize: Int64;
  FMod: LongInt;
  H: THandle;
begin
  CachePath := GetBuildCachePath(BaseDir, SourceFile, TargetBackend);
  Cache := TDelSafeBuildCache.Create;
  try
    Cache.TargetBackend := TargetBackend;
    Cache.SourceFile := SourceFile;
    Cache.OutputExe := OutputExe;
    Cache.OutputExeHash := SHA256File(OutputExe);
    Cache.CompilerVersion := DELSAFE_COMPILER_VERSION;

    for I := 0 to DependencyFiles.Count - 1 do
    begin
      FilePath := DependencyFiles[I];
      if FileExists(FilePath) then
      begin
        FSize := 0;
        H := FileOpen(FilePath, fmOpenRead or fmShareDenyNone);
        if H <> feInvalidHandle then
        begin
          FSize := FileSeek(H, Int64(0), 2);
          FileClose(H);
        end;
        FMod := FileAge(FilePath);
        Cache.AddFile(FilePath, SHA256File(FilePath), FSize, Int64(FMod));
      end;
    end;

    Cache.SaveToFile(CachePath);
  finally
    Cache.Free;
  end;
end;

procedure InvalidateBuildCache(const BaseDir, SourceFile, TargetBackend: string);
var
  CachePath: string;
begin
  CachePath := GetBuildCachePath(BaseDir, SourceFile, TargetBackend);
  if FileExists(CachePath) then
    SysUtils.DeleteFile(CachePath);
end;

end.
