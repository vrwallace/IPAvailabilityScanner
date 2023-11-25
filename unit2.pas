unit Unit2;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Grids, StdCtrls,menus,clipbrd,Windows, ShellAPI;

type

  { TFormScanResults }

  TFormScanResults = class(TForm)
    Edit1: TEdit;
    StringGridResults: TStringGrid;
    procedure FormCreate(Sender: TObject);
     procedure CopySelectedCells(Sender: TObject);
     procedure OpenInDefaultApp(Sender: TObject);
     procedure OpenURL(URL: string);
  private

  public

  end;

var
  FormScanResults: TFormScanResults;

implementation

{$R *.lfm}

{ TFormScanResults }


procedure TFormScanResults.OpenURL(URL: string);
begin
  ShellExecute(0, 'open', PChar(URL), nil, nil, SW_SHOWNORMAL);
end;


procedure TFormScanResults.FormCreate(Sender: TObject);

  var
  MenuItemcopy,MenuItemOpen: TMenuItem;
  begin
 // inherited Create(AOwner);



  // Create popup menu
 stringgridresults.PopupMenu := TPopupMenu.Create(stringgridresults);

   // Open MenuItem
  MenuItemOpen := TMenuItem.Create(PopupMenu);
  MenuItemOpen.Caption := 'Open in Default Application';
  MenuItemOpen.OnClick := @OpenInDefaultApp;
  stringgridresults.PopupMenu.Items.Add(MenuItemOpen);


  MenuItemCopy := TMenuItem.Create(stringgridresults.PopupMenu);
  MenuItemCopy.Caption := 'Copy (Multiple)';
  MenuItemCopy.OnClick := @CopySelectedCells;
  stringgridresults.PopupMenu.Items.Add(MenuItemCopy);





end;
 procedure TFormScanResults.OpenInDefaultApp(Sender: TObject);
var
  SelectedRow: Integer;
  IPAddress, PortStr: string;
  Port: Integer;
  URL: string;
begin
  SelectedRow := StringGridResults.Row;
  if (SelectedRow > 0) and (SelectedRow < StringGridResults.RowCount) then
  begin
    IPAddress := StringGridResults.Cells[0, SelectedRow];
    PortStr := StringGridResults.Cells[1, SelectedRow];

    if TryStrToInt(PortStr, Port) then
    begin
      case Port of
        80: URL := 'http://' + IPAddress+':'+inttostr(port);
        443: URL := 'https://' + IPAddress+':'+inttostr(port);
        22: URL := 'ssh://' + IPAddress+':'+inttostr(port);
        21: URL := 'ftp://' + IPAddress+':'+inttostr(port);
        23: URL := 'telnet://' + IPAddress+':'+inttostr(port); // Assuming the system has a telnet handler
        3389: URL := 'rdp://' + IPAddress+':'+inttostr(port); // RDP - Specific to applications that can handle RDP URLs
        // Add additional ports and protocols as needed
      else
        Exit; // Do nothing for unknown ports
      end;

      // Open the URL with the default application
      if URL <> '' then
        OpenURL(URL);
    end;
  end;
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

