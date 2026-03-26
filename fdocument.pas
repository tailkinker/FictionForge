unit fDocument;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Buttons,
  EditBtn;

type

  { TfrmDocument }

  TfrmDocument = class(TForm)
    btnOK: TBitBtn;
    btnCancel: TBitBtn;
    chkExclude: TCheckBox;
    cmbStatus: TComboBox;
    txtName: TEdit;
    txtPath: TDirectoryEdit;
    txtWordTarget: TEdit;
    txtTags: TEdit;
    txtPoV: TEdit;
    txtVersion: TEdit;
    labName: TLabel;
    labPath: TLabel;
    labStatus: TLabel;
    labWordTarget: TLabel;
    labTags: TLabel;
    labPoV: TLabel;
    labVersion: TLabel;
    labSummary: TLabel;
    txtSummary: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private

  public

  end;

var
  frmDocument: TfrmDocument;

implementation

uses
  dSettings;

{$R *.lfm}

{ TfrmDocument }

procedure TfrmDocument.FormCreate(Sender: TObject);
var
  index : integer;
begin
  for index := 0 to High(StatusList) do
    cmbStatus.Items.Add(StatusList[index].Readable);
  cmbStatus.ItemIndex := 0;
end;

procedure TfrmDocument.FormShow(Sender: TObject);
var
  MousePos: TPoint;
begin
  MousePos := Mouse.CursorPos;
  Left := MousePos.X - (Width div 2);
  Top  := MousePos.Y - (Height div 2);
end;

end.

