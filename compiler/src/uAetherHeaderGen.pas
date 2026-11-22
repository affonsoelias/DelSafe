unit uAetherHeaderGen;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  uAetherAST;

type
  TAetherHeaderGenerator = class
  private
    FModule: TASTModule;
    FOutput: TStringList;

    procedure Emit(const Line: string = '');
    function MapTypeToC(const AType: string): string;
    function BuildFuncPrototype(Func: TASTFunction): string;
    procedure EmitRecordTypeDef(Rec: TASTRecordDecl);
  public
    constructor Create;
    destructor Destroy; override;
    function Generate(AModule: TASTModule): string;
  end;

function GenerateCHeader(AModule: TASTModule): string;
procedure SaveCHeaderToFile(AModule: TASTModule; const FilePath: string);

implementation

constructor TAetherHeaderGenerator.Create;
begin
  inherited Create;
  FOutput := TStringList.Create;
end;

destructor TAetherHeaderGenerator.Destroy;
begin
  FOutput.Free;
  inherited Destroy;
end;

procedure TAetherHeaderGenerator.Emit(const Line: string);
begin
  FOutput.Add(Line);
end;

function TAetherHeaderGenerator.MapTypeToC(const AType: string): string;
var
  T: string;
begin
  T := Trim(AType);
  if (T = 'Int32') or (T = 'Integer') or (T = 'Int') then Exit('int32_t');
  if (T = 'UInt32') or (T = 'Cardinal') or (T = 'DWord') then Exit('uint32_t');
  if (T = 'Int64') then Exit('int64_t');
  if (T = 'UInt64') or (T = 'QWord') then Exit('uint64_t');
  if (T = 'Int16') or (T = 'SmallInt') then Exit('int16_t');
  if (T = 'UInt16') or (T = 'Word') then Exit('uint16_t');
  if (T = 'Int8') or (T = 'ShortInt') then Exit('int8_t');
  if (T = 'UInt8') or (T = 'Byte') then Exit('uint8_t');
  if (T = 'Float32') or (T = 'Single') then Exit('float');
  if (T = 'Float64') or (T = 'Float') or (T = 'Double') or (T = 'Real') then Exit('double');
  if (T = 'Boolean') or (T = 'Bool') then Exit('bool');
  if (T = 'Char') then Exit('char');
  if (T = 'String') then Exit('const char*');
  if (T = 'Pointer') then Exit('void*');
  if (T = 'Void') or (T = '') then Exit('void');

  // Ponteiros explicitos ^T
  if (Length(T) > 1) and (T[1] = '^') then
    Exit(MapTypeToC(Copy(T, 2, Length(T))) + '*');

  // Tipos de usuario (Records / Structs)
  Result := T;
end;

procedure TAetherHeaderGenerator.EmitRecordTypeDef(Rec: TASTRecordDecl);
var
  I: Integer;
  Field: TASTRecordField;
begin
  if Rec.DocComment <> '' then
  begin
    Emit('/*');
    Emit(' * ' + StringReplace(Rec.DocComment, sLineBreak, sLineBreak + ' * ', [rfReplaceAll]));
    Emit(' */');
  end;

  Emit('typedef struct {');
  for I := 0 to Rec.Fields.Count - 1 do
  begin
    Field := TASTRecordField(Rec.Fields[I]);
    Emit(Format('    %s %s;', [MapTypeToC(Field.TypeName), Field.Name]));
  end;
  Emit(Format('} %s;', [Rec.Name]));
  Emit('');
end;

function TAetherHeaderGenerator.BuildFuncPrototype(Func: TASTFunction): string;
var
  I: Integer;
  Param: TASTParam;
  ParamsStr, ParamType, ModStr: string;
begin
  ParamsStr := '';
  for I := 0 to Func.Params.Count - 1 do
  begin
    Param := TASTParam(Func.Params[I]);
    ModStr := '';
    ParamType := MapTypeToC(Param.TypeName);

    if Param.Ownership = owMutBorrow then
      ModStr := '*'
    else if Param.Ownership = owBorrow then
    begin
      // Se for record grande ou string, pode ser const pointer
      if (Param.TypeName <> 'Int32') and (Param.TypeName <> 'Int64') and
         (Param.TypeName <> 'Float64') and (Param.TypeName <> 'Boolean') and
         (Pos('*', ParamType) = 0) and (Param.TypeName <> 'String') then
        ModStr := '';
    end;

    ParamsStr := ParamsStr + Format('%s %s%s', [ParamType, ModStr, Param.Name]);
    if I < Func.Params.Count - 1 then
      ParamsStr := ParamsStr + ', ';
  end;

  if ParamsStr = '' then
    ParamsStr := 'void';

  Result := Format('AETHER_API %s %s(%s);', [MapTypeToC(Func.ReturnType), Func.Name, ParamsStr]);
end;

function TAetherHeaderGenerator.Generate(AModule: TASTModule): string;
var
  GuardName: string;
  I: Integer;
  Func: TASTFunction;
  HasExports: Boolean;
begin
  FModule := AModule;
  FOutput.Clear;

  GuardName := 'AETHER_' + UpperCase(StringReplace(AModule.Name, '-', '_', [rfReplaceAll])) + '_H';

  Emit('/* ========================================================================== */');
  Emit('/*  Cabecalho C gerado automaticamente pelo Compilador Aether (aetherc)       */');
  Emit(Format('/*  Modulo: %s                                                         */', [AModule.Name]));
  Emit('/*  Padrao: C99 / C++ compativel com ABI binaria nativa                       */');
  Emit('/* ========================================================================== */');
  Emit('');
  Emit(Format('#ifndef %s', [GuardName]));
  Emit(Format('#define %s', [GuardName]));
  Emit('');
  Emit('#include <stdint.h>');
  Emit('#include <stdbool.h>');
  Emit('#include <stddef.h>');
  Emit('');
  Emit('#ifdef __cplusplus');
  Emit('extern "C" {');
  Emit('#endif');
  Emit('');
  Emit('#if defined(_WIN32) || defined(__CYGWIN__)');
  Emit('  #if defined(AETHER_BUILD_DLL)');
  Emit('    #define AETHER_API __declspec(dllexport)');
  Emit('  #else');
  Emit('    #define AETHER_API __declspec(dllimport)');
  Emit('  #endif');
  Emit('#else');
  Emit('  #if defined(AETHER_BUILD_DLL)');
  Emit('    #define AETHER_API __attribute__((visibility("default")))');
  Emit('  #else');
  Emit('    #define AETHER_API');
  Emit('  #endif');
  Emit('#endif');
  Emit('');

  // Declara tipos/records
  if AModule.Types.Count > 0 then
  begin
    Emit('/* --- Tipos e Registros Exportados --- */');
    for I := 0 to AModule.Types.Count - 1 do
    begin
      if AModule.Types[I] is TASTRecordDecl then
        EmitRecordTypeDef(TASTRecordDecl(AModule.Types[I]));
    end;
  end;

  // Declara funcoes exportadas
  Emit('/* --- Funcoes Exportadas com Chamada C (cdecl) --- */');
  HasExports := False;
  for I := 0 to AModule.Functions.Count - 1 do
  begin
    Func := TASTFunction(AModule.Functions[I]);
    if Func.IsExport then
    begin
      HasExports := True;
      if Func.DocComment <> '' then
      begin
        Emit('/*');
        Emit(' * ' + StringReplace(Func.DocComment, sLineBreak, sLineBreak + ' * ', [rfReplaceAll]));
        Emit(' */');
      end;
      Emit(BuildFuncPrototype(Func));
      Emit('');
    end;
  end;

  if not HasExports then
  begin
    // Se nenhuma funcao tiver explicitamente "export", exporta todas as funcoes publicas do modulo
    for I := 0 to AModule.Functions.Count - 1 do
    begin
      Func := TASTFunction(AModule.Functions[I]);
      if not Func.IsExtern then
      begin
        if Func.DocComment <> '' then
        begin
          Emit('/*');
          Emit(' * ' + StringReplace(Func.DocComment, sLineBreak, sLineBreak + ' * ', [rfReplaceAll]));
          Emit(' */');
        end;
        Emit(BuildFuncPrototype(Func));
        Emit('');
      end;
    end;
  end;

  Emit('#ifdef __cplusplus');
  Emit('}');
  Emit('#endif');
  Emit('');
  Emit(Format('#endif /* %s */', [GuardName]));

  Result := FOutput.Text;
end;

function GenerateCHeader(AModule: TASTModule): string;
var
  Gen: TAetherHeaderGenerator;
begin
  Gen := TAetherHeaderGenerator.Create;
  try
    Result := Gen.Generate(AModule);
  finally
    Gen.Free;
  end;
end;

procedure SaveCHeaderToFile(AModule: TASTModule; const FilePath: string);
var
  HeaderCode: string;
  SL: TStringList;
begin
  HeaderCode := GenerateCHeader(AModule);
  SL := TStringList.Create;
  try
    SL.Text := HeaderCode;
    ForceDirectories(ExtractFileDir(FilePath));
    SL.SaveToFile(FilePath);
  finally
    SL.Free;
  end;
end;

end.
