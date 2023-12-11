unit Unit2;

{$mode ObjFPC}{$H+}

interface

uses
 Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Grids, StdCtrls, Menus,
  clipbrd, ComCtrls, Windows, ShellAPI, Types;


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
    procedure StringGridResultsDrawCell(Sender: TObject; aCol, aRow: Integer;
      aRect: TRect; aState: TGridDrawState);
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

 procedure TFormScanResults.StringGridResultsDrawCell(Sender: TObject; aCol, aRow: Integer; aRect: TRect; aState: TGridDrawState);
begin
  with TStringGrid(Sender) do
  begin
    if aCol = 2 then // Check if third column
    begin
      if Cells[aCol, aRow] = 'Open' then
        Canvas.Brush.Color := clred // Green for open
      else if Cells[aCol, aRow] = 'Closed' then
        Canvas.Brush.Color := clgreen // Red for closed
      //else
        //Canvas.Brush.Color := clWhite; // Default white for other values
    end;
    Canvas.FillRect(aRect); // Fill rectangle with the brush color
    DefaultDrawCell(aCol, aRow, aRect, aState); // Default cell drawing
  end;
end;



procedure TFormScanResults.FormCreate(Sender: TObject);
var
  MenuItemcopy, MenuItemOpen: TMenuItem;
   ScreenWidth, ScreenHeight: Integer;
  FormWidth, FormHeight: Integer;
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

   // Get the screen width and height
  ScreenWidth := Screen.Width;
  ScreenHeight := Screen.Height;

  // Calculate the form size as 70% of the screen size
  FormWidth := Round(ScreenWidth * 0.5);
  FormHeight := Round(ScreenHeight * 0.7);

  // Set the form's width and height
  Width := FormWidth;
  Height := FormHeight;

  // Optionally, center the form on the screen
  Left := (ScreenWidth - FormWidth) div 2;
  Top := (ScreenHeight - FormHeight) div 2;
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
    80, 8080, 8000, 2082, 2086, 2095: URL := 'http://' + IPAddress + ':' + IntToStr(Port); // HTTP
    443, 8443, 10000, 2083, 2087, 2096: URL := 'https://' + IPAddress + ':' + IntToStr(Port); // HTTPS
    21: URL := 'ftp://' + IPAddress + ':' + IntToStr(Port); // FTP
    22, 2222: URL := 'ssh://' + IPAddress + ':' + IntToStr(Port); // SSH and SFTP
    23, 25: URL := 'telnet://' + IPAddress + ':' + IntToStr(Port); // TELNET and SMTP
    465: URL := 'smtps://' + IPAddress + ':' + IntToStr(Port); // SMTPS
    587: URL := 'smtp://' + IPAddress + ':' + IntToStr(Port); // SMTP alternative
    110: URL := 'pop3://' + IPAddress + ':' + IntToStr(Port); // POP3
    995: URL := 'pop3s://' + IPAddress + ':' + IntToStr(Port); // POP3S
    143: URL := 'imap://' + IPAddress + ':' + IntToStr(Port); // IMAP
    993: URL := 'imaps://' + IPAddress + ':' + IntToStr(Port); // IMAPS
    119: URL := 'news://' + IPAddress + ':' + IntToStr(Port); // NNTP
    3306: URL := 'mysql://' + IPAddress + ':' + IntToStr(Port); // MySQL
    1433: URL := 'mssql://' + IPAddress + ':' + IntToStr(Port); // Microsoft SQL Server
    5432: URL := 'postgresql://' + IPAddress + ':' + IntToStr(Port); // PostgreSQL
    3389: URL := 'rdp://' + IPAddress + ':' + IntToStr(Port); // RDP
    445: URL := '\\' + IPAddress; // SMB Protocol
    554: URL := 'rtsp://' + IPAddress + ':' + IntToStr(Port); // RTSP
    1935: URL := 'rtmp://' + IPAddress + ':' + IntToStr(Port); // RTMP
    5060: URL := 'sip://' + IPAddress + ':' + IntToStr(Port); // SIP
    389: URL := 'ldap://' + IPAddress + ':' + IntToStr(Port); // LDAP
    636: URL := 'ldaps://' + IPAddress + ':' + IntToStr(Port); // LDAPS
    6379: URL := 'redis://' + IPAddress + ':' + IntToStr(Port); // Redis
    27017: URL := 'mongodb://' + IPAddress + ':' + IntToStr(Port); // MongoDB
    5672: URL := 'amqp://' + IPAddress + ':' + IntToStr(Port); // RabbitMQ
    5900: URL := 'vnc://' + IPAddress + ':' + IntToStr(Port); // VNC
    2049: URL := 'nfs://' + IPAddress + ':' + IntToStr(Port); // NFS
    // Add any additional specific ports and protocols here
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
