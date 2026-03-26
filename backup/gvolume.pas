unit gVolume;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, gCluster;

type
  tVolume = class (tClusterItem)
  protected
      FVolumeName : string;
      FLastEdit   : tDateTime;
      FWordCount  : longint;
      FStatus     : integer;
      FPath       : string;
      FDescription: TStringList;
    public
      property VolumeName : string read FVolumeName write FVolumeName;
      property LastEdit   : tDateTime read FLastEdit write FLastEdit;
      property WordCount  : longint read FWordCount write FWordCount;
      property Status     : integer read FStatus write FStatus;
      property Path       : string read FPath write FPath;
      property Description: TStringList read FDescription;

      constructor Create; override;
      constructor Create (aParent : tClusterItem); override;
      destructor  Destroy; override;
      function    HandleKey(const k, v : string): boolean; override;
      procedure   WriteKeys(var t : text); override;
      procedure   PreLoad(var t: text); override;
      procedure   Edit; override;
  end;

implementation

uses
  Forms, DateUtils, dsettings, fVolume, Controls;

{$region tVolume}

constructor tVolume.Create;
begin
  Create (nil);
end;

constructor tVolume.Create(aParent: tClusterItem);
begin
  inherited Create(aParent);
  FDescription := TStringList.Create;
end;

destructor tVolume.Destroy;
begin
  FDescription.Free;
  inherited Destroy;
end;

function tVolume.HandleKey(const k, v: string): boolean;
begin
  Result := True;
  if k = 'VolumeName' then
    FVolumeName := v
  else if k = 'Last Edited' then
    FLastEdit := EncodeDateTime(
            StrToInt(Copy(v, 1, 4)),  // Year
            StrToInt(Copy(v, 6, 2)),  // Month
            StrToInt(Copy(v, 9, 2)),  // Day
            StrToInt(Copy(v, 12, 2)), // Hour
            StrToInt(Copy(v, 15, 2)), // Minute
            StrToInt(Copy(v, 18, 2)), // Second
            StrToInt(Copy(v, 21, 3))  // MSec
          )
  else if k = 'WordCount' then
    FWordCount := StrToIntDef(v, 0)
  else if k = 'Status' then
    FStatus := StatusTypeID(v)
  else if k = 'Path' then
    FPath := v
  else if k = 'Description' then
    FDescription.Add(v) // Just append as they come in
  else
    Result := inherited HandleKey(k, v);
end;

procedure tVolume.WriteKeys(var t: text);
var
  i: integer;
begin
  inherited WriteKeys(t);
  WriteKey(t, 'VolumeName', FVolumeName);
  WriteKey(t, 'Last Edited',
    FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', FLastEdit));
  WriteKey(t, 'Word Count', IntToStr(FWordCount));
  WriteKey(t, 'Status', StatusTypeName(FStatus));
  WriteKey(t, 'Path', FPath);

  for i := 0 to FDescription.Count - 1 do
    WriteKey(t, 'Description', FDescription[i]);
end;

procedure tVolume.PreLoad(var t: text);
begin
  inherited PreLoad(t);
  FDescription.Clear; // Wipe existing lines before the new Load loop starts
end;

procedure tVolume.Edit;
var
  Dialog : TfrmVolume;
begin
  Dialog := TfrmVolume.Create (Application);
  try
    Dialog.txtVolumeName.Text := FVolumeName;
    Dialog.cmbStatus.ItemIndex := FStatus;
    Dialog.txtPath.Text := FPath;
    Dialog.txtDescription.Lines.Assign(FDescription);
    if (Dialog.ShowModal = mrOK) then begin
      FVolumeName := Dialog.txtVolumeName.Text;
      FStatus := Dialog.cmbStatus.ItemIndex;
      FPath := Dialog.txtPath.Text;
      Description.Assign(Dialog.txtDescription.Lines);
      FLastEdit := now;
      MarkDirty;
      Update;
    end;
  finally
    Dialog.Free;
  end;
end;

{$endregion tVolume}


initialization
  RegisterItemClass(tVolume);
end.
