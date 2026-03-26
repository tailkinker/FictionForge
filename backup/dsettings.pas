unit dsettings;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

type
  TNotifyEvent = procedure(Sender: TObject) of object;
  tStatusRec = record
    ID : integer;
    Name : string;
    Readable : string;
  end;

const
  inifilename = 'ficforge.ini';
  inifiledir = 'ficforge';
  StatusList : array[0..7] of tStatusRec = (
    (ID: 0; Name: 'stOUTLINE';   Readable: 'Outline'),
    (ID: 1; Name: 'stDRAFT';     Readable: 'Draft'),
    (ID: 2; Name: 'stEDITING';   Readable: 'Editing'),
    (ID: 3; Name: 'stREVIEW';    Readable: 'In Review'),
    (ID: 4; Name: 'stCOMPLETE';  Readable: 'Complete'),
    (ID: 5; Name: 'stPUBLISHED'; Readable: 'Published'),
    (ID: 6; Name: 'stARCHIVED';  Readable: 'Archived'),
    (ID: 7; Name: 'stDEFERRED';  Readable: 'Deferred')
  );

function GetConfigDir: string;
function StatusTypeID (const Constant : string) : integer;
function StatusTypeName (const Value : integer) : string;
function StatusTypeReadableName (const Value : integer) : string;

implementation

function GetConfigDir: string;
begin
  if GetEnvironmentVariable('XDG_CONFIG_HOME') <> '' then
    Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('XDG_CONFIG_HOME'))
  else
    Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) + '.config/';
  Result := Result + inifiledir + '/'; // final config dir
  if not DirectoryExists(Result) then
    ForceDirectories(Result);
end;

function StatusTypeID (const Constant : string) : integer;
var
  i : integer;
begin
  for i := Low(StatusList) to High(StatusList) do
    if StatusList[i].Name = Constant then
      Exit(StatusList[i].ID);
  Result := -1;
end;

function StatusTypeName (const Value : integer) : string;
var
  i : integer;
begin
  if (Value >= Low(StatusList)) and (Value <= High(StatusList)) then
    Result := StatusList[Value].Name
  else
    Result := '<unknown>';
end;

function StatusTypeReadableName (const Value : integer) : string;
begin
  if (Value >= Low(StatusList)) and (Value <= High(StatusList)) then
    Result := StatusList[Value].Readable
  else
    Result := '<unknown>';
end;

end.

