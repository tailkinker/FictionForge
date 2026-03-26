unit fvolume;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, EditBtn,
  Buttons;

type

  { TfrmVolume }

  TfrmVolume = class(TForm)
    btnOK: TBitBtn;
    btnCancel: TBitBtn;
    cmbStatus: TComboBox;
    labDescription: TLabel;
    txtDescription: TMemo;
    txtPath: TDirectoryEdit;
    txtVolumeName: TEdit;
    labVolumeName: TLabel;
    labStatus: TLabel;
    labPath: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private

  public

  end;

var
  frmVolume: TfrmVolume;

implementation

uses
  dSettings;

{$R *.lfm}

{ TfrmVolume }

procedure TfrmVolume.FormCreate(Sender: TObject);
var
  index : integer;
begin
  for index := 0 to High (StatusList) do
    cmbStatus.Items.Add (StatusList [index].Readable);
  cmbStatus.ItemIndex := 0;
end;

procedure TfrmVolume.FormShow(Sender: TObject);
var
  MousePos: TPoint;
begin
  MousePos := Mouse.CursorPos;
  Left := MousePos.X - (Width div 2);
  Top  := MousePos.Y - (Height div 2);
end;

end.

