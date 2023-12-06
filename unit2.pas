unit Unit2;

{$mode ObjFPC}{$H+}

interface

uses
 Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Grids, StdCtrls, Menus,
  clipbrd, ComCtrls, Windows, ShellAPI;


var
  stoppressed: integer = 0;


type

  { TFormScanResults }

  TFormScanResults = class(TForm)
    Button1: TButton;
    Edit1: TEdit;
    ProgressBar1: TProgressBar;
    StringGridResults: TStringGrid;
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure CopySelectedCells(Sender: TObject);
    procedure OpenInDefaultApp(Sender: TObject);
    procedure OpenURL(URL: string);
    procedure FormWindowStateChange(Sender: TObject);
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

 procedure TFormScanResults.FormWindowStateChange(Sender: TObject);
begin
  //if FormScanResults.WindowState = wsMinimized then
  //begin
  //  FormScanResults.WindowState := wsNormal;
  //  FormScanResults.Hide;
  //  FormScanResults.ShowInTaskBar := stAlways;
  //end;
end;
procedure TFormScanResults.FormCreate(Sender: TObject);
var
  MenuItemcopy, MenuItemOpen: TMenuItem;
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

procedure TFormScanResults.Button1Click(Sender: TObject);
begin
  stoppressed := 1;
end;

procedure TFormScanResults.OpenInDefaultApp(Sender: TObject);
var
  SelectedRow: integer;
  IPAddress, PortStr: string;
  Port: integer;
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
        80: URL := 'http://' + IPAddress + ':' + IntToStr(Port);
        443: URL := 'https://' + IPAddress + ':' + IntToStr(Port);
        22: URL := 'ssh://' + IPAddress + ':' + IntToStr(Port);
        21: URL := 'ftp://' + IPAddress + ':' + IntToStr(Port);
        23: URL := 'telnet://' + IPAddress + ':' + IntToStr(Port);
        445: URL := '\\' + IPAddress; // SMB Protocol
        3389: URL := 'rdp://' + IPAddress + ':' + IntToStr(Port);
        3306: URL := 'mysql://' + IPAddress + ':' + IntToStr(Port); // MySQL
        1433: URL := 'mssql://' + IPAddress + ':' + IntToStr(Port); // Microsoft SQL Server
        5432: URL := 'postgresql://' + IPAddress + ':' + IntToStr(Port); // PostgreSQL
        5900: URL := 'vnc://' + IPAddress + ':' + IntToStr(Port); // VNC
        5060: URL := 'sip://' + IPAddress + ':' + IntToStr(Port); // SIP
        25: URL := 'telnet://' + IPAddress+ ':' + IntToStr(Port);
        // SMTP, typically doesn't use URL but can be used for mailto
        119: URL := 'news://' + IPAddress + ':' + IntToStr(Port); // NNTP
        2049: URL := 'nfs://' + IPAddress + ':' + IntToStr(Port); // NFS
        8080, 8000: URL := 'http://' + IPAddress + ':' + IntToStr(Port);
        // Common alternative HTTP ports
        8443: URL := 'https://' + IPAddress + ':' + IntToStr(Port);
        // Common alternative HTTPS port
        10000: URL := 'https://' + IPAddress + ':' + IntToStr(Port);
        // Common alternative HTTPS port
        2082: URL := 'http://' + IPAddress + ':' + IntToStr(Port);
        2083: URL := 'https://' + IPAddress + ':' + IntToStr(Port);
        2086: URL := 'http://' + IPAddress + ':' + IntToStr(Port);
        2087: URL := 'https://' + IPAddress + ':' + IntToStr(Port);
        2095: URL := 'http://' + IPAddress + ':' + IntToStr(Port);
        2096: URL := 'https://' + IPAddress + ':' + IntToStr(Port);



          // Add other ports and protocols as needed
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
  i, j: integer;
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
