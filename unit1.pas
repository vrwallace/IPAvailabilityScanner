unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Spin, Grids, pingsend, blcksock, winsock, sockets, Windows,
  SyncObjs;

var
  stoppressed: integer=0; // or Boolean, depending on your intended use
  ActiveThreads: integer = 0;
  ThreadLock: TCriticalSection;
  MaxThreads: integer = 255; // Set your max threads here
  RowIndex: integer = 0;



type
  TPingThread = class(TThread)
  private
    FIPAddress, FHostName, FMacAddress: string;
    FPingResult: integer;
    procedure UpdateUI;
    function PingHostfun(const Host: string): integer;
    function GetMacAddr(const IPAddress: string; var ErrCode: DWORD): string;
    function IPAddrToName(IPAddr: string): string;

  protected
    procedure Execute; override;
  public
    constructor Create(const IPAddress: string);
  end;




  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    CheckBox1: TCheckBox;
    CheckBox2: TCheckBox;
    Edit1: TEdit;
    Edit2: TEdit;
    Edit3: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    SpinEdit1: TSpinEdit;
    StringGrid1: TStringGrid;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure DumpExceptionCallStack(E: Exception);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    function GetLocalIPAddress: string;
    procedure SortStringGrid;
    procedure MoveRow(Grid: TStringGrid; FromIndex, ToIndex: integer);

  private




    function CalculateNumberOfIPsInRange: integer;
  public
    { Public declarations }
  end;

function SendArp(DestIP, SrcIP: ULONG; pMacAddr: pointer; PhyAddrLen: pointer): DWord;
  stdcall; external 'iphlpapi.dll' Name 'SendARP';

function CompareIPs(const IP1, IP2: string): integer;


var
  Form1: TForm1;

implementation

{$R *.lfm}

constructor TPingThread.Create(const IPAddress: string);
begin
  inherited Create(True); // Create suspended
  FIPAddress := IPAddress;
  FreeOnTerminate := True;
  // Initialize other fields if necessary
end;

procedure TPingThread.Execute;
var
  errcode: dword;
begin
  ThreadLock.Acquire;
  try
    if ActiveThreads >= MaxThreads then
    begin
      ThreadLock.Release;
      Exit; // or wait and check again
    end;
    Inc(ActiveThreads);
  finally
    ThreadLock.Release;
  end;


  try
    // Check if stop has been pressed
    if stoppressed = 1 then Exit;

    // Perform the ping operation
    FPingResult := PingHostFun(FIPAddress);

    // Get hostname and MAC address
    if (form1.checkbox1.Checked) then FHostName := IPAddrToName(FIPAddress)
    else
      FHostName := 'N/A';
    if (form1.checkbox2.Checked) then FMacAddress := GetMacAddr(FIPAddress, ErrCode)
    else
      FMacAddress := 'N/A';

    // Synchronize the UI update
    Synchronize(@UpdateUI);


  finally
    ThreadLock.Acquire;
    try
      Dec(ActiveThreads);
      if ActiveThreads = 0 then

        Synchronize(@Form1.SortStringGrid); // Sort when all threads are done
    finally
      ThreadLock.Release;
    end;
  end;
end;

procedure TForm1.SortStringGrid;
var
  i, j: integer;
begin
  edit3.Text := 'AutoSizingColumns';
  stringgrid1.AutoSizeColumns;

  edit3.Text := 'Sorting!';
  // Basic bubble sort for demonstration
  for i := 1 to StringGrid1.RowCount - 1 do
    for j := i + 1 to StringGrid1.RowCount - 1 do
      if CompareIPs(StringGrid1.Cells[0, i], StringGrid1.Cells[0, j]) > 0 then
      begin
        // Swap rows if the IP address at i is greater than the one at j
        MoveRow(StringGrid1, i, j);
      end;
  edit3.Text := 'Complete!';
end;


procedure TForm1.MoveRow(Grid: TStringGrid; FromIndex, ToIndex: integer);
var
  i: integer;
  Temp: string;
begin
  for i := 0 to Grid.ColCount - 1 do
  begin
    Temp := Grid.Cells[i, FromIndex];
    Grid.Cells[i, FromIndex] := Grid.Cells[i, ToIndex];
    Grid.Cells[i, ToIndex] := Temp;
  end;
end;

procedure TPingThread.UpdateUI;
begin

  form1.edit3.Text := FIPAddress + #9 + IntToStr(FPingResult) + #9 +
    FHostName + #9 + FMacAddress;


  with Form1.StringGrid1 do
  begin
    RowIndex := RowCount; // Get current row count
    RowCount := RowCount + 1; // Increase row count to add a new row
    Cells[0, RowIndex] := FIPAddress;
    Cells[1, RowIndex] := IntToStr(FPingResult);
    Cells[2, RowIndex] := FHostName;
    Cells[3, RowIndex] := FMacAddress;
  end;
end;


{ TForm1 }

function CompareIPs(const IP1, IP2: String): Integer;
var
  Parts1, Parts2: TStringList;
  i, Num1, Num2: Integer;
begin
  Parts1 := TStringList.Create;
  Parts2 := TStringList.Create;
  try
    Parts1.Delimiter := '.';
    Parts2.Delimiter := '.';
    Parts1.DelimitedText := IP1;
    Parts2.DelimitedText := IP2;

    for i := 0 to Parts1.Count - 1 do
    begin
      Num1 := StrToInt(Parts1[i]);
      Num2 := StrToInt(Parts2[i]);
      if Num1 < Num2 then
        Exit(-1)
      else if Num1 > Num2 then
        Exit(1);
    end;

    Result := 0;
  finally
    Parts1.Free;
    Parts2.Free;
  end;
end;


function TForm1.CalculateNumberOfIPsInRange: integer;
var
  StartIP, EndIP: cardinal;
begin
  StartIP := inet_addr(PChar(Edit1.Text));
  EndIP := inet_addr(PChar(Edit2.Text));
  Result := ntohl(EndIP) - ntohl(StartIP) + 1;
end;

procedure TForm1.Button1Click(Sender: TObject);
var
  I, ipindexstart, ipindexend: cardinal;
  pingThread: TPingThread;
  startIP, endIP: string;
  IPAddress: in_addr;
begin
  // Example IP range inputs
  startIP := Edit1.Text; // Start IP from Edit1
  endIP := Edit2.Text;   // End IP from Edit2

  // Convert IP addresses to numeric format
  IPAddress.s_addr := inet_addr(PChar(startIP));
  ipindexstart := ntohl(IPAddress.s_addr); // Network to Host Long
  IPAddress.s_addr := inet_addr(PChar(endIP));
  ipindexend := ntohl(IPAddress.s_addr);

  // Validate IP addresses
  if (ipindexstart = INADDR_NONE) or (ipindexend = INADDR_NONE) then
  begin
    ShowMessage('Invalid IP address format');
    Exit;
  end;
  // Initialize the counter

  stringgrid1.Clear;
  stringgrid1.RowCount := 1;
  with StringGrid1 do
  begin
    Cells[0, 0] := 'IP';
    Cells[1, 0] := 'Reply';
    Cells[2, 0] := 'Name';
    Cells[3, 0] := 'Mac Address';
  end;
  //if (calcuatethenumberofips>

  application.ProcessMessages;
  // Iterate over the IP range and create threads
  for I := ipindexstart to ipindexend do
  begin
    //IPAddress.s_addr := htonl(I); // Host to Network Long
    IPAddress.s_addr := i;
    pingThread := TPingThread.Create(HostAddrToStr(IPAddress));
    pingThread.Start;
  end;
end;


procedure TForm1.Button2Click(Sender: TObject);
begin
  stoppressed := 1;

end;


function TPingThread.PingHostfun(const Host: string): integer;
begin
  Result := 0;



  with TPINGSend.Create do

  try
    Timeout := form1.spinedit1.Value;
    if Ping(host) then
    begin
      if ReplyError = IE_NoError then
      begin
        Result := 1;
      end

      else
        Result := 0;
    end
    else
    begin
      Result := 0;
    end;

  finally
    Free;
  end;
end;




procedure TForm1.DumpExceptionCallStack(E: Exception);
var
  I: integer;
  Frames: PPointer;
  Report: string;
begin
  Report := 'Program exception! ' + LineEnding + 'Stacktrace:' +
    LineEnding + LineEnding;
  if E <> nil then
  begin
    Report := Report + 'Exception class: ' + E.ClassName + LineEnding +
      'Message: ' + E.Message + LineEnding;

    Report := Report + BackTraceStrFunc(ExceptAddr);
    Frames := ExceptFrames;
    for I := 0 to ExceptFrameCount - 1 do
      Report := Report + LineEnding + BackTraceStrFunc(Frames[I]);

    ShowMessage(Report);

  end;
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  stoppressed := 1;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  ThreadLock := TCriticalSection.Create;
  edit1.Text := GetLocalIPAddress;
  edit2.Text := GetLocalIPAddress;
  with StringGrid1 do
  begin
    Cells[0, 0] := 'IP';
    Cells[1, 0] := 'Reply';
    Cells[2, 0] := 'Name';
    Cells[3, 0] := 'Mac Address';
  end;

end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  ThreadLock.Free;
end;

function tform1.GetLocalIPAddress: string;
var
  wsaData: TWSAData;
  hostent: PHostEnt;
  namen: array[0..255] of char;
begin
  Result := '';
  WSAStartup($0202, wsaData); // Initialize Winsock
  try
    if gethostname(namen, sizeof(namen)) = 0 then
    begin
      hostent := gethostbyname(namen);
      if hostent <> nil then
      begin
        Result := Format('%d.%d.%d.%d', [byte(hostent^.h_addr^[0]),
          byte(hostent^.h_addr^[1]), byte(hostent^.h_addr^[2]),
          byte(hostent^.h_addr^[3])]);
      end;
    end;
  finally
    WSACleanup; // Clean up Winsock
  end;
end;

function TPingThread.IPAddrToName(IPAddr: string): string;
var
  SockAddrIn: TSockAddrIn;
  HostEnt: PHostEnt;
  WSAData: TWSAData;
begin
  WSAStartup($101, WSAData);
  SockAddrIn.sin_addr.s_addr := inet_addr(PChar(IPAddr));

  HostEnt := gethostbyaddr(@SockAddrIn.sin_addr.S_addr, 4, AF_INET);
  if HostEnt <> nil then
    Result := StrPas(Hostent^.h_name)
  else
    Result := '';
end;

function TPingThread.GetMacAddr(const IPAddress: string; var ErrCode: DWORD): string;
var
  MacAddr: array[0..5] of byte;
  DestIP: ULONG;
  PhyAddrLen: ULONG;
  WSAData: TWSAData;
begin
  Result := '';
  WSAStartup($0101, WSAData);
  try
    ZeroMemory(@MacAddr, SizeOf(MacAddr));
    DestIP := inet_addr(pansichar(IPAddress));
    PhyAddrLen := SizeOf(MacAddr);
    ErrCode := SendArp(DestIP, 0, @MacAddr, @PhyAddrLen);
    if ErrCode = S_OK then
      Result := Format('%2.2x-%2.2x-%2.2x-%2.2x-%2.2x-%2.2x',
        [MacAddr[0], MacAddr[1], MacAddr[2], MacAddr[3], MacAddr[4], MacAddr[5]])
  finally
    WSACleanup;
  end;
end;

end.
