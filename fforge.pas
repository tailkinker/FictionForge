unit fforge;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, ExtCtrls,
  StdCtrls, Buttons, Arrow, gCluster,
  gVolume, gDocument;

type

  { TfrmFictionForge }

  TfrmFictionForge = class(TForm)
    btnDocsEdit: TBitBtn;
    btnDocsDelete: TBitBtn;
    btnDocsMoveUp: TBitBtn;
    btnDocsMoveDown: TBitBtn;
    bvDocsToolbar1: TBevel;
    btnDocsAddFolder: TBitBtn;
    btnDocsAddDocument: TBitBtn;
    btnDocsFilterByTagsClear: TBitBtn;
    bvDocsToolbar2: TBevel;
    bvDocumentsVertical: TBevel;
    btnOptions: TBitBtn;
    btnVolumeOpen: TBitBtn;
    btnExit: TBitBtn;
    btnVolumeDelete: TBitBtn;
    btnVolumeEdit: TBitBtn;
    btnVolumeAdd: TBitBtn;
    imgDocuments: TImageList;
    labDocuments: TLabel;
    lstDocuments: TTreeView;
    txtDocsFilterByTags: TEdit;
    fpDocs: TFlowPanel;
    fpVolumes: TFlowPanel;
    labDocsFilterByTags: TLabel;
    labVolumeList: TLabel;
    lstVolumeList: TListView;
    pgMain: TPageControl;
    sbMain: TStatusBar;
    tsDocs: TTabSheet;
    tsVolumes: TTabSheet;
    procedure btnDocsAddDocumentClick(Sender: TObject);
    procedure btnDocsAddFolderClick(Sender: TObject);
    procedure btnDocsDeleteClick(Sender: TObject);
    procedure btnDocsEditClick(Sender: TObject);
    procedure btnDocsFilterByTagsClearClick(Sender: TObject);
    procedure btnDocsMoveDownClick(Sender: TObject);
    procedure btnDocsMoveUpClick(Sender: TObject);
    procedure btnExitClick(Sender: TObject);
    procedure btnVolumeAddClick(Sender: TObject);
    procedure btnVolumeDeleteClick(Sender: TObject);
    procedure btnVolumeEditClick(Sender: TObject);
    procedure btnVolumeOpenClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure lstDocumentsDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure lstDocumentsDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure lstDocumentsMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure lstDocumentsSelectionChanged(Sender: TObject);
    procedure lstVolumeListSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure SelectCurrentNode;
    procedure SetDocsControls;
  private
    VolumeList : tFileCluster;
    CurrentVolume : tVolume;
    NodeList : tFileCluster;
    CurrentNode : tClusterItem;
    FLastHoverNode: TTreeNode;
    FHoverStart: TDateTime;

    procedure UpdateVolumeList;
    procedure UpdateDocumentList;
  end;

var
  frmFictionForge: TfrmFictionForge;

implementation

uses
  DateUtils, inifiles,
  dsettings, dutil;

{$R *.lfm}

{ TfrmFictionForge }

{$region BaseForm}

procedure TfrmFictionForge.FormClose(Sender: TObject;
  var CloseAction: TCloseAction);
var
  ini: TIniFile;
begin
  ini := TIniFile.Create(GetConfigDir + inifilename);
  try
    ini.WriteInteger('Window', 'Left', Left);
    ini.WriteInteger('Window', 'Top', Top);
    ini.WriteInteger('Window', 'Width', Width);
    ini.WriteInteger('Window', 'Height', Height);
  finally
    ini.Free;
  end;

  VolumeList.Free;
  NodeList.Free;
end;

procedure TfrmFictionForge.FormCloseQuery(Sender: TObject; var CanClose: Boolean
  );
begin
  if (VolumeList.Dirty) then
    if MessageDlg('Save Volume List',
      'There are changes to the Volume List.  Would you like to save them ' +
        'before exiting?',
        mtConfirmation, [mbYes, mbNo], 0) = mrYes then
      VolumeList.SaveFile;
  if MessageDlg('Exit FictionForge', 'Are you sure you want to quit?',
                mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    CanClose := True
  else
    CanClose := False;
end;

procedure TfrmFictionForge.FormCreate(Sender: TObject);
var
  ini: TIniFile;
begin
  ini := TIniFile.Create(GetConfigDir + inifilename);
  try
    Left := ini.ReadInteger('Window', 'Left', Left);
    Top := ini.ReadInteger('Window', 'Top', Top);
    Width := ini.ReadInteger('Window', 'Width', Width);
    Height := ini.ReadInteger('Window', 'Height', Height);
  finally
    ini.Free;
  end;

  VolumeList := tFileCluster.Create;
  VolumeList.Filename := GetConfigDir + PathDelim + 'volumes.cfg';
  VolumeList.LoadFile;
  NodeList := tFileCluster.Create;
  pgMain.ActivePage := tsVolumes;
  UpdateVolumeList
end;

{$endregion BaseForm}

{$region VolumeTab}

procedure TfrmFictionForge.btnVolumeAddClick(Sender: TObject);
var
  NewVolume : tVolume;
begin
  NewVolume := tVolume.Create (VolumeList);
  NewVolume.Edit;
  VolumeList.Add (NewVolume);
  UpdateVolumeList;
end;

procedure TfrmFictionForge.btnExitClick(Sender: TObject);
begin
  Close
end;

procedure TfrmFictionForge.btnVolumeDeleteClick(Sender: TObject);
var
  index : integer;
begin
  if (Assigned (CurrentVolume)) then begin
    index := VolumeList.IndexOf (CurrentVolume);
    VolumeList.Delete(index);
    CurrentVolume := nil;
    lstVolumeList.ClearSelection;
    btnVolumeEdit.Enabled := FALSE;
    btnVolumeDelete.Enabled := FALSE;
    UpdateVolumeList;
  end;
end;

procedure TfrmFictionForge.btnVolumeEditClick(Sender: TObject);
begin
  if (Assigned (CurrentVolume)) then begin
    CurrentVolume.Edit;
    UpdateVolumeList;
  end;
end;

procedure TfrmFictionForge.btnVolumeOpenClick(Sender: TObject);
begin
  pgMain.ActivePage := tsDocs;
end;

procedure TfrmFictionForge.lstVolumeListSelectItem(Sender: TObject;
  Item: TListItem; Selected: Boolean);
begin
  if (Assigned (Item)) then begin
    CurrentVolume := tVolume(Item.Data);
    btnVolumeEdit.Enabled := TRUE;
    btnVolumeDelete.Enabled := TRUE;
    btnVolumeOpen.Enabled := TRUE;
    tsDocs.Enabled := TRUE;
    UpdateDocumentList;
  end else begin
    btnVolumeEdit.Enabled := FALSE;
    btnVolumeDelete.Enabled := FALSE;
    btnVolumeOpen.Enabled := FALSE;
    tsDocs.Enabled := FALSE;
  end;
end;

procedure TfrmFictionForge.UpdateVolumeList;
var
  index : integer;
  NewItem : TListItem;
  Volume : tVolume;
begin
  if VolumeList.Dirty then
    VolumeList.SaveFile;

  lstVolumeList.BeginUpdate;

  try
    lstVolumeList.Clear;
    for index := 0 to (VolumeList.Count - 1) do begin
      Volume := tVolume(VolumeList[index]);
      NewItem := lstVolumeList.Items.Add;
      NewItem.Data := Volume;
      with (Volume) do begin
        NewItem.Caption := VolumeName;
        NewItem.SubItems.Add(FormatDateTime('yyyy-mm-dd hh:nn', LastEdit));
        NewItem.SubItems.Add (IntToStr(WordCount));
        NewItem.SubItems.Add (StatusTypeReadableName(Status));
        NewItem.SubItems.Add (Path);
      end;
    end;
  finally
    lstVolumeList.EndUpdate;
  end;
end;

{$endregion VolumeTab}

{$region DocsTab}

procedure TfrmFictionForge.btnDocsFilterByTagsClearClick(Sender: TObject);
begin
  txtDocsFilterByTags.Text := '';
end;

procedure TfrmFictionForge.btnDocsMoveDownClick(Sender: TObject);
var
  index : longint;
  aParent : tCluster;
begin
  if Assigned (CurrentNode) then begin
    aParent := tCluster(CurrentNode.Parent);
    index := aParent.IndexOf (CurrentNode);
    if (index = aParent.Last) then
      btnDocsMoveDown.Enabled := FALSE
    else begin
      aParent.Move (index, index + 1);
      aParent.MarkDirty;
      UpdateDocumentList
    end;
  end;
end;

procedure TfrmFictionForge.btnDocsMoveUpClick(Sender: TObject);
var
  index : longint;
  aParent : tCluster;
begin
  if Assigned (CurrentNode) then begin
    aParent := tCluster(CurrentNode.Parent);
    index := aParent.IndexOf (CurrentNode);
    if (index = 0) then
      btnDocsMoveUp.Enabled := FALSE
    else begin
      aParent.Move (index, index - 1);
      aParent.MarkDirty;
      UpdateDocumentList
    end;
  end;
end;

procedure TfrmFictionForge.btnDocsAddFolderClick(Sender: TObject);
var
  aParent : tCluster;
  NewFolder : tFolder;
begin
  if (Assigned (CurrentNode)) then
    if (CurrentNode is tFolder) then
      aParent := tCluster(CurrentNode)
    else
      aParent := tCluster(CurrentNode.Parent)
  else
    aParent := tCluster(NodeList);

  NewFolder := tFolder.Create (aParent);
  NewFolder.Edit;
  aParent.Add (NewFolder);
  UpdateDocumentList
end;

procedure TfrmFictionForge.btnDocsDeleteClick(Sender: TObject);
var
  s : string;
  index : longint;
  aParent : tCluster;
begin
  if Assigned (CurrentNode) then begin
    If (CurrentNode is tDocument) then
      s := 'Delete the document "' + tDocument(CurrentNode).Title + '"?'
    else if (CurrentNode is tFolder) then begin
      s := 'Folder "' + tFolder (CurrentNode).FolderName + '"';
      if (tFolder (CurrentNode).Count > 0) then
        s := s + ' contains ' + WordFor (tFolder (CurrentNode).Count) + ' entries!  Are you sure you want to delete them all?'
      else
        s := 'Are you sure you want to delete ' + s + '?';
    end;

    if MessageDlg(s, mtConfirmation, [mbYes, mbNo], 0) = mrYes then begin
      aParent := tCluster(CurrentNode.Parent);
      index := aParent.IndexOf (CurrentNode);
      aParent.Delete(index);
      UpdateDocumentList;
    end;
  end;
end;

procedure TfrmFictionForge.btnDocsEditClick(Sender: TObject);
begin
  if Assigned (CurrentNode) then
    CurrentNode.Edit;
  UpdateDocumentList;
end;

procedure TfrmFictionForge.btnDocsAddDocumentClick(Sender: TObject);
var
  aParent : tCluster;
  NewDocument : tDocument;
begin
  if (Assigned (CurrentNode)) then
    if (CurrentNode is tFolder) then
      aParent := tCluster(CurrentNode)
    else
      aParent := tCluster(CurrentNode.Parent)
  else
    aParent := tCluster(NodeList);

  NewDocument := tDocument.Create (aParent);
  NewDocument.Edit;
  aParent.Add (NewDocument);
  if (aParent is tFolder) then
    tFolder (aParent).UpdateWordCount
  else
    NewDocument.UpdateWordCount;
  UpdateDocumentList;
end;

procedure TfrmFictionForge.UpdateDocumentList;
  procedure AddClusterItems(ParentNode: TTreeNode; CurrentList: tCluster);
  var
    i: longint;
    CurrentItem: tClusterItem;
    NewNode: TTreeNode;
  begin
    // Iterate from 0 to the Last index of the current Cluster/folder
    for i := 0 to CurrentList.Last do
    begin
      CurrentItem := CurrentList[i];

      // Add the item to lstDocuments under the ParentNode
      if (CurrentItem is tDocument) then begin
        NewNode := lstDocuments.Items.AddChild(ParentNode,
          tDocument(CurrentItem).Title);
        NewNode.ImageIndex := 2;      // Normal state
        NewNode.SelectedIndex := 2;   // When clicked/highlighted
      end else if (CurrentItem is tFolder) then begin
        NewNode := lstDocuments.Items.AddChild(ParentNode,
          tFolder (CurrentItem).FolderName);
        NewNode.ImageIndex := 1;      // Normal state
        NewNode.SelectedIndex := 1;   // When clicked/highlighted
      end;
      NewNode.Data := CurrentItem;

      // If the item is a tFolder, recurse into its own array of objects
      if CurrentItem is tFolder then
      begin
        // Since tFolder is a tCluster, we pass it as the next list to process
        AddClusterItems(NewNode, tFolder(CurrentItem));
      end;
    end;
  end;

var
  RootNode : tTreeNode;
begin
  lstDocuments.Items.BeginUpdate;
  try
    lstDocuments.Items.Clear;
    // Add the Root Node
    RootNode := lstDocuments.Items.Add(nil, CurrentVolume.VolumeName);
    RootNode.ImageIndex := 0;
    RootNode.SelectedIndex := 0;
    // Start the recursive process using the NodeList
    AddClusterItems(RootNode, NodeList);
  finally
    lstDocuments.Items.EndUpdate;
  end;

  if Assigned (CurrentNode) then
    SelectCurrentNode;
end;

procedure TfrmFictionForge.SetDocsControls;
var
  index : longint;
  aParent : tCluster;
begin
  btnDocsMoveUp.Enabled := FALSE;
  btnDocsMoveDown.Enabled := FALSE;
  if (Assigned (CurrentNode)) then begin
    aParent := tCluster (CurrentNode.Parent);
    index := aParent.IndexOf (CurrentNode);

    if (index > 0) then
      btnDocsMoveUp.Enabled := TRUE;
    if (index < aParent.Last) then
      btnDocsMoveDown.Enabled := TRUE;

    btnDocsEdit.Enabled := TRUE;
    btnDocsDelete.Enabled := TRUE;
  end else begin
    btnDocsEdit.Enabled := FALSE;
    btnDocsDelete.Enabled := FALSE;
  end;
end;

procedure TfrmFictionForge.lstDocumentsSelectionChanged(Sender: TObject);
var
  s : string;
begin
  if Assigned (lstDocuments.Selected) then
    if (lstDocuments.Selected.Parent = nil) then begin
      CurrentNode := nil;
      s := 'Root of "' + CurrentVolume.VolumeName + '" selected.';
      sbMain.SimpleText := s
    end else begin
      CurrentNode := tClusterItem(lstDocuments.Selected.Data);
      if (CurrentNode is tFolder) then
        s := 'Folder "' + tFolder (CurrentNode).FolderName
      else if (CurrentNode is tDocument) then
        s := 'Document "' + tDocument (CurrentNode).Title;
      s := s + '" selected.';
      sbMain.SimpleText := s
    end;
  SetDocsControls;
end;

procedure TfrmFictionForge.SelectCurrentNode;
var
  Node: TTreeNode;
begin
  Node := lstDocuments.Items.GetFirstNode;
  while Assigned(Node) do begin
    if tClusterItem(Node.Data) = CurrentNode then begin
      lstDocuments.Selected := Node;
      Node.MakeVisible;  // optional, scrolls to it
      Break;
    end;
    Node := Node.GetNext;
  end;
end;


procedure TfrmFictionForge.lstDocumentsDragDrop(Sender, Source: TObject; X,
  Y: Integer);
var
  SourceNode,
  TargetNode: TTreeNode;
  NewParent,
  OldParent,
  SourceItem,
  TargetItem: TClusterItem;
  index : integer;
begin
  SourceNode := lstDocuments.Selected;
  TargetNode := lstDocuments.GetNodeAt(X, Y);

  if (SourceNode <> nil) then
  begin
    SourceItem := TClusterItem(SourceNode.Data);

    // If dropped on a node, make that node the parent.
    // If dropped on empty space (TargetNode = nil), make it a root item.
    if TargetNode <> nil then
      TargetItem := TClusterItem(TargetNode.Data)
    else
      TargetItem := nil;

    // DATA CHANGE
    OldParent := SourceItem.Parent;
    if (TargetItem is tFolder) then
      NewParent := TargetItem
    else if (TargetItem is tDocument) then
      NewParent := TargetItem.Parent
    else
      NewParent := NodeList;

    if (SourceItem.Parent <> NewParent) then begin
      // Prevent moving a folder into itself
      if (NewParent = SourceItem) then Exit;
      if Assigned(SourceItem.Parent) then begin
        index := tCluster(SourceItem.Parent).IndexOf(SourceItem);
        tCluster(SourceItem.Parent).Remove(index);
      end;
      SourceItem.Parent := NewParent;
      tCluster(NewParent).Add(SourceItem);

    end;

    // UI REFRESH
    UpdateDocumentList;
  end;
end;

procedure TfrmFictionForge.lstDocumentsDragOver(Sender, Source: TObject; X,
  Y: Integer; State: TDragState; var Accept: Boolean);
var
  TargetNode, SourceNode: TTreeNode;
begin
  TargetNode := lstDocuments.GetNodeAt(X, Y);
  SourceNode := lstDocuments.Selected;

  // Basic validation: Are we dragging a node onto another node?
  Accept := (SourceNode <> nil) and (TargetNode <> nil) and (SourceNode <> TargetNode);

  // Prevent dropping a parent into one of its own descendants
  if Accept then
    Accept := not TargetNode.HasAsParent(SourceNode);

  if (TargetNode <> nil) and (TargetNode <> FLastHoverNode) then begin
      FLastHoverNode := TargetNode;
      FHoverStart := Now;
    end;

  // If hovering over a collapsed node for > 750ms, expand it
  if (TargetNode <> nil) and (not TargetNode.Expanded) and (TargetNode.HasChildren) then
    if (MilliSecondsBetween(Now, FHoverStart) > 750) then
      TargetNode.Expand(False);
end;

procedure TfrmFictionForge.lstDocumentsMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Hit: TTreeNode;
begin
  Hit := lstDocuments.GetNodeAt(X, Y);
  if Hit = nil then begin
    lstDocuments.Selected := nil;
    sbMain.SimpleText := '';
    CurrentNode := nil
  end;
end;

{$endregion DocsTab}

end.

