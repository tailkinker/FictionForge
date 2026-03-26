unit gDocument;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils,
  gCluster, gtags;

type
  tDocument = class (tClusterItem)
  protected
    FTitle : string;
    FPath : string;
    FLastEdit : tDateTime;
    FStatus : integer;
    FWordCount : longint;
    FWordTarget : longint;
    FTags : tTags;
    FSummary : TStringList;
    FPoV : string;
    FVersion : string;
    FExclude : boolean;
  public
    property Title : string read FTitle write FTitle;
    property Path : string read FPath write FPath;
    property LastEdit : tDateTime read FLastEdit write FLastEdit;
    property Status : integer read FStatus write FStatus;
    property WordCount : longint read FWordCount;
    property WordTarget : longint read FWordTarget write FWordTarget;
    property Tags : tTags read FTags write FTags;
    property Summary : TStringList read FSummary write FSummary;
    property PoV : string read FPoV write FPoV;
    property Version : string read FVersion write FVersion;
    property Exclude : boolean read FExclude write FExclude;

    constructor Create;          override;
    constructor Create           (aParent : tClusterItem); override;
    destructor  Destroy;         override;
    function    HandleKey        (const k, v : string) : boolean; override;
    procedure   WriteKeys        (var t : text); override;
    procedure   PreLoad          (var t : text); override;
    procedure   Edit;            override;
    procedure   UpdateWordCount; virtual;
  end;

  tFolder = class (tCluster)
  protected
    FFolderName : string;
    FLastEdit : tDateTime;
    FStatus : integer;
    FWordCount : longint;
    FWordTarget : longint;
    FTags : tTags;
    FSummary : tStringList;
    FExclude : boolean;
    FNextChapter : longint;
  public
    property FolderName: string read FFolderName write FFolderName;
    property LastEdit: TDateTime read FLastEdit write FLastEdit;
    property Status: integer read FStatus write FStatus;
    property WordCount: LongInt read FWordCount;
    property WordTarget: LongInt read FWordTarget write FWordTarget;
    property Tags: tTags read FTags write FTags;
    property Summary: TStringList read FSummary write FSummary;
    property Exclude: boolean read FExclude write FExclude;
    property NextChapter: LongInt read FNextChapter write FNextChapter;

    constructor Create;          override;
    constructor Create           (aParent : tClusterItem); override;
    destructor  Destroy;         override;
    function    HandleKey        (const k, v : string) : boolean; override;
    procedure   WriteKeys        (var t : text); override;
    procedure   PreLoad          (var t : text); override;
    procedure   Edit;            override;
    procedure   UpdateWordCount; virtual;
  end;

implementation

uses
  Forms, Controls, fDocument, dSettings;

{$region tDocument}

constructor tDocument.Create;
begin
  Create (nil);
end;

constructor tDocument.Create (aParent : tClusterItem);
begin
  inherited Create(aParent);
  FTags := tTags.Create;
  FSummary := tStringList.Create;
  FExclude := FALSE;
end;

destructor tDocument.Destroy;
begin
  FTags.Free;
  FSummary.Free;
  inherited Destroy;
end;

function tDocument.HandleKey (const k, v : string) : boolean;
begin
  Result := True;
  case k of
    'Title' : FTitle := v;
    'Path' : FPath := v;
    'Last Edited' : FLastEdit := StrToDateTimeDef(v, 0);
    'Status' : FStatus := StatusTypeID(v);
    'Word Count' : FWordCount := StrToIntDef(v, 0);
    'Word Target' : FWordTarget := StrToIntDef(v, 0);
    'Tags' : FTags.TagList := v;
    'Summary' : FSummary.Add(v);
    'Point of View' : FPoV := v;
    'Version' : FVersion := v;
    'Exclude from Export' :
      FExclude := SameText(v, 'TRUE');
  else
    Result := inherited HandleKey(k, v)
  end;
end;

procedure tDocument.WriteKeys (var t : text);
var
  index : integer;
begin
  WriteKey (t, 'Title', FTitle);
  WriteKey (t, 'Path', FPath);
  WriteKey (t, 'Last Edited', DateTimeToStr(FLastEdit));
  WriteKey (t, 'Status', StatusTypeName(FStatus));
  WriteKey (t, 'Word Count', IntToStr(FWordCount));
  if (FWordTarget <> 0) then
    WriteKey (t, 'Word Target', IntToStr (FWordTarget));
  WriteKey (t, 'Tags', FTags.Taglist);
  if (FSummary.Count > 0) then
    for index := 0 to (FSummary.Count - 1) do
      WriteKey (t, 'Summary', FSummary[index]);
  if (FPoV <> '') then
    WriteKey (t, 'Point of View', FPoV);
  if (FVersion <> '') then
    WriteKey (t, 'Version', FVersion);
  if (FExclude) then
    WriteKey (t, 'Exclude from Export', 'TRUE');
end;

procedure tDocument.PreLoad (var t : text);
begin
  if (FSummary.Count > 0) then
    FSummary.Clear;
end;

procedure TDocument.UpdateWordCount;
var
  FileContent: TStringList;
  Line: string;
  i, j: Integer;
  InBraces: Boolean;
  InWord: Boolean;
begin
  FWordCount := 0;
  InBraces := False;

  if FileExists(FPath) then begin
    FileContent := TStringList.Create;
    try
      FileContent.LoadFromFile(FPath);

      for i := 0 to FileContent.Count - 1 do begin
        Line := FileContent[i];

        // Skip lines starting with @ or #
        if (Line = '') or (Line[1] = '@') or (Line[1] = '#') then
          Continue;

        InWord := False;
        for j := 1 to Length(Line) do begin
          case Line[j] of
            '{': InBraces := True;
            '}': InBraces := False;
          else if not InBraces then begin
              // Check for non-whitespace characters
              if Line[j] > #32 then begin
                if not InWord then begin
                  Inc(FWordCount);
                  InWord := True;
                end;
              end else
                InWord := False;
            end;
          end;
        end;
      end;
    finally
      FileContent.Free;
    end;
  end;
end;

procedure tDocument.Edit;
var
  Dialog : TfrmDocument;
begin
  Dialog := TfrmDocument.Create (Application);
  try
    with Dialog do begin
      txtName.Text := FTitle;
      txtPath.Text := FPath;
      cmbStatus.ItemIndex := FStatus;
      txtWordTarget.Text := IntToStr(FWordTarget);
      txtTags.Text := FTags.Taglist;
      if (FSummary.Count > 0) then
        txtSummary.Lines.Assign(FSummary);
      txtPoV.Text := FPoV;
      txtVersion.Text := FVersion;
      chkExclude.Checked := FExclude;
    end;

    if (Dialog.ShowModal = mrOK) then with Dialog do begin
      FTitle := txtName.Text;
      FPath := txtPath.Text;
      FStatus := cmbStatus.ItemIndex;
      FWordTarget := StrToIntDef(txtWordTarget.Text, 0);
      FTags.Taglist := txtTags.Text;
      FSummary.Assign(txtSummary.Lines);
      FPoV := txtPoV.Text;
      FVersion := txtVersion.Text;
      FExclude := chkExclude.Checked;
      UpdateWordCount;
    end;
  finally
    Dialog.Free
  end;
end;

{$endregion tDocument}

{$region tFolder}

constructor tFolder.Create;
begin
  Create (nil);
end;

constructor tFolder.Create (aParent : tClusterItem);
begin
  inherited Create(aParent);
  FTags := tTags.Create;
  FSummary := tStringList.Create;
  FExclude := FALSE;
end;

destructor tFolder.Destroy;
begin
  FTags.Free;
  FSummary.Free;
  inherited Destroy;
end;

function tFolder.HandleKey (const k, v : string) : boolean;
begin
  Result := True;
  case k of
    'Folder Name' : FFolderName := v;
    'Last Edited' : FLastEdit := StrToDateTimeDef(v, 0);
    'Status' : FStatus := StatusTypeID(v);
    'Word Count' : FWordCount := StrToIntDef(v, 0);
    'Word Target' : FWordTarget := StrToIntDef(v, 0);
    'Tags' : FTags.TagList := v;
    'Summary' : FSummary.Add(v);
    'Exclude from Export' : FExclude := SameText(v, 'TRUE');
    'Next Chapter' : FNextChapter := StrToIntDef(v, 0);
  else
    Result := inherited HandleKey(k, v)
  end;
end;

procedure tFolder.WriteKeys (var t : text);
var
  index : integer;
begin
  WriteKey (t, 'Folder Name', FFolderName);
  WriteKey (t, 'Last Edited', DateTimeToStr(FLastEdit));
  WriteKey (t, 'Status', StatusTypeName(FStatus));
  WriteKey (t, 'Word Count', IntToStr(FWordCount));
  if (FWordTarget <> 0) then
    WriteKey (t, 'Word Target', IntToStr (FWordTarget));
  WriteKey (t, 'Tags', FTags.Taglist);
  if (FSummary.Count > 0) then
    for index := 0 to (FSummary.Count - 1) do
      WriteKey (t, 'Summary', FSummary[index]);
  if (FExclude) then
    WriteKey (t, 'Exclude from Export', 'TRUE');
  if (FNextChapter <> 0) then
    WriteKey (t, 'Next Chapter', IntToStr(FNextChapter));
end;

procedure tFolder.PreLoad (var t : text);
begin
  if (FSummary.Count > 0) then
    FSummary.Clear;
end;

procedure tFolder.UpdateWordCount;
var
  index : integer;
  CurrentItem : TClusterItem;
begin
  FWordCount := 0;
  if Count > 0 then
    for index := 0 to Last do begin
      CurrentItem := FCluster [index];
      if (CurrentItem is tDocument) then begin
        tDocument (CurrentItem).UpdateWordCount;
        FWordCount := FWordCount + tDocument (CurrentItem).WordCount;
      end else if (CurrentItem is tFolder) then begin
        tFolder (CurrentItem).UpdateWordCount;
        FWordCount := FWordCount + tFolder (CurrentItem).WordCount;
      end;
    end;
end;

procedure tFolder.Edit;
var
  Dialog : TfrmDocument;
begin
  Dialog := TfrmDocument.Create (Application);
  try
    with Dialog do begin
      labName.Caption := 'Folder Name';
      txtName.Text := FolderName;
      labPath.Visible := FALSE;
      txtPath.Visible := FALSE;
      cmbStatus.ItemIndex := FStatus;
      txtWordTarget.Text := IntToStr(FWordTarget);
      txtTags.Text := FTags.Taglist;
      if (FSummary.Count > 0) then
        txtSummary.Lines.Assign(FSummary);
      labPoV.Visible := FALSE;
      txtPoV.Visible := FALSE;
      labVersion.Caption := 'Next Chapter';
      txtVersion.Text := IntToStr (FNextChapter);
      chkExclude.Checked := FExclude;
    end;

    if (Dialog.ShowModal = mrOK) then with Dialog do begin
      FolderName := txtName.Text;
      FStatus := cmbStatus.ItemIndex;
      FWordTarget := StrToIntDef(txtWordTarget.Text, 0);
      FTags.Taglist := txtTags.Text;
      FSummary.Assign(txtSummary.Lines);
      FNextChapter := StrToIntDef(txtVersion.Text, 0);
      FExclude := chkExclude.Checked;
      UpdateWordCount;
    end;
  finally
    Dialog.Free
  end;
end;

{$endregion tFolder}

end.

