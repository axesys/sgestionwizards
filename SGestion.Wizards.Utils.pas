unit SGestion.Wizards.Utils;

interface

uses
  ToolsAPI;

function SelectDir(IsProject: Boolean = False): Boolean;

/// <summary>
///  These funcions are all by David Hoyle's, and you can find them all in his book:
///  The Delphi Open Tools API book at:
/// </summary>

/// <summary>
///  Returns the current Project Group opened in the IDE
///  If there is no Project Group opened, returns NIL
/// </summary>
function ActiveProjectGroup: IOTAProjectGroup;

/// <summary>
///  Returns the current Project active (ie. in Bold) in the Project Manager
///  If there is no Project active, returns NILL
/// </summary>
function ActiveProject: IOTAProject;

/// <summary>
///  Retunrs Source Modules (DPR, DPK, etc) for the given Project
/// </summary>
function ProjectModule(const Project: IOTAProject): IOTAModule;

/// <summary>
///  Returns the active IDE Source Editor Interface. If there is no active Editor then this method returns NIL.
/// </summary>
function ActiveSourceEditor: IOTASourceEditor;

/// <summary>
///  Returns the IDE Source Editor Interface for a given Module. If there is no Editor then this method returns NIL.
/// </summary>
function SourceEditor(const Module: IOTAModule): IOTASourceEditor;

/// <summary>
///  Returns the SourceEditor source code as string
/// </summary>
function EditorAsString(const SourceEditor: IOTASourceEditor): string;

type
/// <summary>
///   Reads source code from a RT_RCDATA Resource
/// </summary>
  TResourceFile = class(TInterfacedObject, IOTAFile)
  strict private
    FName: string;
    FResourceName: string;
  strict
  private
    property Name: string read FName;
    property ResourceName: string read FResourceName;
  public
    constructor Create(const Name: string; const AResourceName: string);
    function GetAge: TDateTime; virtual;
    function GetSource: string; virtual;
  end;

implementation

uses
  System.Types,
  System.SysUtils,
  System.StrUtils,
	System.Classes,
  System.IOUtils,
  System.Win.Registry,
  Vcl.Dialogs,
  Windows;

function SelectDir(IsProject: Boolean = False): Boolean;
const
  APP_KEY = 'Software\SGestionWizards\';
begin
  with TFileOpenDialog.Create(nil) do
    try
      Title := 'Selecciona una carpeta';
      Options := [fdoPickFolders, fdoPathMustExist, fdoForceFileSystem]; // YMMV
      OkButtonLabel := 'Selecconar';
      DefaultFolder := TPath.GetDocumentsPath + '\Embarcadero\Studio\Projects';
      FileName := TPath.GetDocumentsPath + '\Embarcadero\Studio\Projects';
      if IsProject and Execute then
      begin
        SetCurrentDir(FileName);
        with TRegistry.Create(KEY_READ or KEY_WOW64_64KEY) do
        try
          RootKey:= HKEY_CURRENT_USER;
          Access := KEY_WRITE or KEY_WOW64_64KEY;
          OpenKey(APP_KEY, True);
          WriteString('Path', FileName);
          CloseKey;
        finally
          Free
        end;
        Result:= True;
      end
      else
      begin
        with TRegistry.Create(KEY_READ or KEY_WOW64_64KEY) do
        try
          RootKey:= HKEY_CURRENT_USER;
          OpenKey(APP_KEY, True);
          SetCurrentDir(ReadString('Path'));
          CloseKey;
        finally
          Free;
        end;
      end;
    finally
      Free;
    end
end;

function ActiveProjectGroup: IOTAProjectGroup;
var
  I: Integer;
  AModuleServices: IOTAModuleServices;
  AModule: IOTAModule;
  AProjectGroup: IOTAProjectGroup;
begin
  Result := NIL;
  AModuleServices := BorlandIDEServices as IOTAModuleServices;
  for I := 0 to AModuleServices.ModuleCount - 1 do
  begin
    AModule := AModuleServices.Modules[I];
    if AModule.QueryInterface(IOTAProjectGroup, AProjectGroup) = S_OK then
      Break;
  end;
  Result := AProjectGroup;
end;

function ActiveProject: IOTAProject;
var
  PG: IOTAProjectGroup;
begin
  PG := ActiveProjectGroup;
  if PG <> NIL then
    Result := PG.ActiveProject;
end;

function ProjectModule(const Project: IOTAProject): IOTAModule;
var
  I: Integer;
  AModuleServices: IOTAModuleServices;
  AModule: IOTAModule;
  AProject: IOTAProject;
begin
  Result := NIL;
  AModuleServices := BorlandIDEServices as IOTAModuleServices;
  for I := 0 to AModuleServices.ModuleCount - 1 do
  begin
    AModule := AModuleServices.Modules[I];
    if (AModule.QueryInterface(IOTAProject, AProject) = S_OK) and (Project = AProject) then
      Break;
  end;
  Result := AProject;
end;

function SourceEditor(const Module: IOTAModule): IOTASourceEditor;
var
  I, LFileCount: Integer;
begin
  Result := NIL;
  if Module = NIL then
    Exit;

  LFileCount := Module.GetModuleFileCount;
  for I := 0 to LFileCount - 1 do
  begin
    if Module.GetModuleFileEditor(I).QueryInterface(IOTASourceEditor, Result) = S_OK then
      Break;
  end;
end;

function ActiveSourceEditor: IOTASourceEditor;
var
  CM: IOTAModule;
begin
  Result := NIL;
  if BorlandIDEServices = NIL then
    Exit;

  CM := (BorlandIDEServices as IOTAModuleServices).CurrentModule;
  Result := SourceEditor(CM);
end;

function EditorAsString(const SourceEditor: IOTASourceEditor): string;
Const
  iBufferSize: Integer = 1024;
var
  Reader: IOTAEditReader;
  iPosition, iRead: Integer;
  strBuffer: AnsiString;
begin
  Result := '';
  Reader := SourceEditor.CreateReader;
  try
    iPosition := 0;
    repeat
      SetLength(strBuffer, iBufferSize);
      iRead := Reader.GetText(iPosition, PAnsiChar(strBuffer), iBufferSize);
      SetLength(strBuffer, iRead);
      Result := Result + string(strBuffer);
      Inc(iPosition, iRead);
    until iRead < iBufferSize;
  finally
    Reader := NIL;
  end;
end;

{$REGION 'TSGestionSourceFile'}

constructor TResourceFile.Create(const Name: string; const AResourceName: string);
begin
  inherited Create;
  FName:= Name;
  FResourceName := AResourceName;
end;

function TResourceFile.GetAge: TDateTime;
begin
  Result := -1;
end;

function TResourceFile.GetSource: string;
var
  Res: TResourceStream;
  S: TStrings;
begin
  Res := TResourceStream.Create(HInstance, ResourceName, RT_RCDATA);
  try
    if Res.Size = 0 then
      raise Exception.CreateFmt('Resource %s is empty', [ResourceName]);

    S := TStringList.Create;
    try
      Res.Position := 0;
      S.LoadFromStream(Res);
      Result := StringReplace(s.Text, '?', Name, [rfReplaceAll, rfIgnoreCase]);
    finally
      S.Free;
    end;
  finally
    Res.Free;
  end;
end;

{$ENDREGION}

end.
