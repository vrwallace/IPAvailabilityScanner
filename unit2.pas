unit Unit2;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Grids, StdCtrls,menus,clipbrd;

type

  { TFormScanResults }

  TFormScanResults = class(TForm)
    Edit1: TEdit;
    StringGridResults: TStringGrid;
    procedure FormCreate(Sender: TObject);
     procedure CopySelectedCells(Sender: TObject);
  private

  public

  end;

var
  FormScanResults: TFormScanResults;

implementation

{$R *.lfm}

{ TFormScanResults }

procedure TFormScanResults.FormCreate(Sender: TObject);

  var
  MenuItemcopy: TMenuItem;
  begin
 // inherited Create(AOwner);



  // Create popup menu
 stringgridresults.PopupMenu := TPopupMenu.Create(stringgridresults);
  MenuItemCopy := TMenuItem.Create(stringgridresults.PopupMenu);
  MenuItemCopy.Caption := 'Copy (Multiple)';
  MenuItemCopy.OnClick := @CopySelectedCells;
  stringgridresults.PopupMenu.Items.Add(MenuItemCopy);


end;
     procedure TFormScanResults.CopySelectedCells(Sender: TObject);
var
  ClipBoardText: string;
  i, j: Integer;
begin
  ClipBoardText := '';
  with StringGridResults do
  begin
    for i := Selection.Top to Selection.Bottom do
    begin
      for j := Selection.Left to Selection.Right do
      begin
        ClipBoardText := ClipBoardText + Cells[j, i] + #9; // Tab separated
      end;
      ClipBoardText := ClipBoardText + sLineBreak; // New line for each row
    end;
  end;
  Clipboard.AsText := ClipBoardText;
end;
end.

