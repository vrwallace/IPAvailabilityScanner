unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Spin, Grids, pingsend, winsock, sockets, Windows,
  SyncObjs, Clipbrd, Menus, ComCtrls, unit2, sqlite3conn, sqldb,
  unit3, blcksock, Types,openssl;


var


  ThreadLock: TCriticalSection;
  MaxThreads: integer = 255; // Set your max threads here
  IPList: TStringList;
  ActiveTasks: integer = 0;
  crlf: string = #13#10;

type
  TScanResult = record
    IPAddress: string;
    Port: integer;
    Status: string;
    Banner: string;
  end;



type
  TPortScanThread = class(TThread)
  private
    FScanResult: TScanResult;
    procedure UpdateGrid;
    procedure UpdateGridWrapper;
    procedure DoScan;
    function HexToString(H: string): string;
  protected
    procedure Execute; override;
  public
    constructor Create(const IPAddress: string; Port: integer);
  end;


type
  // Assuming TPingTask is a simple record for demonstration
  TPingTask = record
    IPAddress: string;
    Data: string;
  end;

type
  // TPingTaskQueue class definition
  TPingTaskQueue = class
  private
    FTaskList: TList;
    FCriticalSection: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Lock;
    procedure Unlock;
    procedure AddTask(const Task: TPingTask);
    function GetCount: integer;
    function LockList: TList;
    procedure UnlockList;

    function TryGetTask(out Task: TPingTask): boolean;
  end;

type
  TPingThread = class(TThread)
  private
    FTask: TPingTask;

    FHostName, FMacAddress: string;
    FPingResult: string;
    procedure UpdateUI;
    function PingHostfun(const Host: string): string;
    function GetMacAddr(const IPAddress: string; var ErrCode: DWORD): string;
    function IPAddrToName(IPAddr: string): string;

  protected
    procedure Execute; override;
  public
  end;

  PPingTask = ^TPingTask; // Pointer to TPingTask


  { TForm1 }
type
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
    ProgressBar1: TProgressBar;
    SpinEdit1: TSpinEdit;
    StringGrid1: TStringGrid;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure SortStringGrid;
    procedure MoveRow(Grid: TStringGrid; FromIndex, ToIndex: integer);
    procedure StringGrid1DrawCell(Sender: TObject; aCol, aRow: integer;
      aRect: TRect; aState: TGridDrawState);
    procedure StringGrid1HeaderClick(Sender: TObject; IsColumn: boolean;
      Index: integer);
    procedure TrimAppMemorySize;
    function CalculateNumberOfIPsInRange: integer;
    function GetLocalIPAddress: string;
    procedure FinalizeTasks;
    function GetPortDescription(Port: integer): string;
    procedure ButtonScanPortsClick(Sender: TObject);
    procedure StartPortScanning(const IPAddress: string; Ports: array of integer);
    procedure PortScanTerminated(Sender: TObject);
    procedure SortGridports;
    procedure SortStringGrid2(Grid: TStringGrid; ColIndex: integer);
    function CompareRows(const Row1, Row2: integer; Grid: TStringGrid;
      const ColIndex: integer): integer;

    procedure LookupMACMenuItemClick(Sender: TObject);
    function LookupMAC(macPrefix: string; out ShortName, LongName: string;
      dbname: string): boolean;
    procedure tracertMenuItemClick(Sender: TObject);
    procedure PingMenuItemClick(Sender: TObject);
    procedure buttonpingClick(Sender: TObject);
    procedure buttontracertClick(Sender: TObject);
    function PingHostfun2(const Host: string): string;
    function TraceRouteHostfun(const Host: string): string;
    function Pingtracertrttl(const Host: string): string;
    function SplitString(const aString, Delimiter: string): TStringList;
    function CompareIPs2(IP1, IP2: string): integer;
  private
    CompletedScans: integer;
    SortAscending: array of boolean;
    // Array to keep track of sort order for each column
    TotalScans: integer;
    ActiveScanThreads: integer;
    LastSortedColumn: integer;

    TaskQueue: TPingTaskQueue;
    ThreadPool: array of TPingThread;
    procedure StartThreads;
    procedure StopThreads;
    //procedure DumpExceptionCallStack(E: Exception);
    procedure CopyMenuItemClick(Sender: TObject);
    procedure PortScanMenuItemClick(Sender: TObject);
    procedure UpdateProgressBar;
  public
    { Public declarations }
  end;



function SendArp(DestIP, SrcIP: ULONG; pMacAddr: pointer; PhyAddrLen: pointer): DWord;
  stdcall; external 'iphlpapi.dll' Name 'SendARP';

function CompareIPs(const IP1, IP2: string): integer;
procedure DumpExceptionCallStack(E: Exception);
//procedure GlobalExceptionHandler(Sender: TObject; E: Exception);
var
  Form1: TForm1;

implementation

{$R *.lfm}

//procedure GlobalExceptionHandler(Sender: TObject; E: Exception);
//begin
//  DumpExceptionCallStack(E);
//  // You can add additional handling here if needed
//end;


constructor TPortScanThread.Create(const IPAddress: string; Port: integer);
begin
  inherited Create(True);
  FScanResult.IPAddress := IPAddress;
  FScanResult.Port := Port;
  FreeOnTerminate := True;
end;

procedure TPortScanThread.Execute;
begin
  DoScan;
  Synchronize(@UpdateGridWrapper);
  InterlockedIncrement(Form1.CompletedScans);
  Synchronize(@Form1.UpdateProgressBar);

end;

procedure TForm1.UpdateProgressBar;
var
  PercentComplete: integer;
begin
  if TotalScans > 0 then
  begin
    PercentComplete := (CompletedScans * 100) div TotalScans;
    FormScanResults.ProgressBar1.Position := PercentComplete;
  end;
end;

procedure TPortScanThread.DoScan;
var
  TriggerString: string;
  TcpSock: TTCPBlockSocket;
begin

   // Initialize TriggerString based on the port
  case FScanResult.Port of
    80, 443, 2082, 2083, 2086, 2087, 2095, 2096, 8080, 8081, 8000, 8443, 8888, 10000:
      TriggerString := 'GET / HTTP/1.0'#13#10#13#10;  // HTTP and common alternate ports
    21, 20:
      TriggerString := 'HELP'#10'USER anonymous'#10'PASS banner@grab.com'#10'QUIT'#10;
    // FTP
    22:
      TriggerString := ''; // SSH, typically doesn't have a banner
    25, 465, 587:
      TriggerString := 'HELO bannergrab.com'#13#10'HELP'#13#10'QUIT'#13#10;
    // SMTP and related email ports
    23:
      TriggerString := #13#10; // Telnet
    110, 995:
      TriggerString := 'QUIT'#13#10;   // POP3
    143, 993:
      TriggerString := 'CAPABILITY'#13#10; // IMAP
    119,563:
      TriggerString := 'HELP'#13#10'LIST NEWSGROUPS'#13#10'QUIT'#13#10; // NNTP
    161:
      TriggerString := HexToString(
        '302902010004067075626c6963a01c0204ffffffff020100020100300e300c06082b060102010101000500302a020100040770726976617465a01c0204fffffffe020100020100300e300c06082b060102010101000500'); // SNMP
    389, 636:
      TriggerString := HexToString(
        '300c0201016007020103040080003035020102633004000a01000a0100020100020100010100870b6f626a656374436c6173733010040e6e616d696e67636f6e7465787473');   //ldap
    // LDAP
    1433:
      TriggerString := HexToString(
        '100100e000000100d80000000100007100000000000000076c04000000000000e0030000000000000908000056000a006a000a007e0000007e002000be00090000000000d0000400d8000000d8000000000c29c6634200000000c8000000420061006e006e00650072004700720061006200420061006e006e006500720047007200610062004d006900630072006f0073006f0066007400200044006100740061002000410063006300650073007300200043006f006d0070006f006e0065006e00740073003100320037002e0030002e0030002e0031004f00440042004300'); // Microsoft SQL Server
    3306:
      TriggerString := ''; // MySQL, typically doesn't use a banner
    5432:
      TriggerString := ''; // PostgreSQL, typically doesn't use a banner
    7, 9:
      TriggerString := 'Echo'#13#10;// Echo
    137:
      TriggerString := HexToString(
        'a2480000000100000000000020434b4141414141414141414141414141414141414141414141414141414141410000210001');
    // NetBIOS Name Service
    123:
      TriggerString := HexToString('e30004fa000100000001000000000000000000000000000000000000000000000000000000000000ca9ba3352d7f950b160200010000000000000000160100010000000000000000');  // NTP
    79:
      TriggerString := 'root bin lp wheel spool adm mail postmaster news uucp snmp daemon'#13#10; // Finger
      // Add more ports and triggers as needed
    else
      TriggerString := '';
  end;

  TcpSock := TTCPBlockSocket.Create;
  try
    TcpSock.ConnectionTimeout := Form1.SpinEdit1.Value;
    TcpSock.Connect(FScanResult.IPAddress, IntToStr(FScanResult.Port));

    if TcpSock.LastError = 0 then
    begin
      FScanResult.Status := 'Open';

      // Sending and receiving data
      TcpSock.SendString(TriggerString);
      FScanResult.Banner := TcpSock.RecvTerminated(5000, CRLF);

    end
    else
      FScanResult.Status := 'Closed';

  finally
    TcpSock.Free;
  end;
end;




procedure TPortScanThread.UpdateGridWrapper;
begin
  UpdateGrid;
end;

procedure TPortScanThread.UpdateGrid;
begin
  with FormScanResults.StringGridResults do
  begin
    RowCount := RowCount + 1;
    Cells[0, RowCount - 1] := FScanResult.IPAddress;
    Cells[1, RowCount - 1] := IntToStr(FScanResult.Port);
    Cells[2, RowCount - 1] := FScanResult.Status; // "Open" or "Closed"
    Cells[3, RowCount - 1] := Form1.GetPortDescription(FScanResult.Port);
    Cells[4, RowCount - 1] := FScanResult.Banner; // Banner column
  end;
end;

procedure TForm1.StartPortScanning(const IPAddress: string; Ports: array of integer);
var
  i: integer;
  PortScanThread: TPortScanThread;
begin
  Inc(ActiveScanThreads, Length(Ports)); // Increment the thread count

  for i := Low(Ports) to High(Ports) do
  begin
    PortScanThread := TPortScanThread.Create(IPAddress, Ports[i]);
    PortScanThread.OnTerminate := @PortScanTerminated;
    // Set the event handler // Set the OnTerminate event
    PortScanThread.Start;
  end;
end;


procedure TForm1.PortScanTerminated(Sender: TObject);
begin
  // Decrement the count in a thread-safe way
  InterlockedDecrement(ActiveScanThreads);

  if ActiveScanThreads = 0 then
  begin
    SortGridports;
    FormScanResults.StringGridResults.AutoSizeColumns;

    if (unit2.stoppressed = 0) then FormScanResults.edit1.Text := 'Complete!'
    else
    begin
      FormScanResults.edit1.Text := 'Stopped!';
      FormScanResults.progressbar1.Position := 0;
    end;
    TrimAppMemorySize;
  end;
end;

procedure TForm1.SortGridports;
begin
  // Implement your sorting logic here
  // Example: Sort by port number (column index 1)
  SortStringGrid2(FormScanResults.StringGridResults, 1); // Sort by column 1

end;

function tform1.CompareRows(const Row1, Row2: integer; Grid: TStringGrid;
  const ColIndex: integer): integer;
var
  Val1, Val2: string;
begin
  Val1 := Grid.Cells[ColIndex, Row1];
  Val2 := Grid.Cells[ColIndex, Row2];

  // Compare as integer if they are numbers, otherwise as strings
  if TryStrToInt(Val1, Result) and TryStrToInt(Val2, Result) then
    Result := StrToInt(Val1) - StrToInt(Val2)
  else
    Result := CompareStr(Val1, Val2);
end;

procedure TForm1.SortStringGrid2(Grid: TStringGrid; ColIndex: integer);
var
  i, j, k: integer;
  Temp: string;
begin
  for i := Grid.FixedRows to Grid.RowCount - 2 do
    for j := Grid.FixedRows to Grid.RowCount - 2 do
      if CompareRows(j, j + 1, Grid, ColIndex) > 0 then
      begin
        // Swap the rows
        for k := 0 to Grid.ColCount - 1 do
        begin
          Temp := Grid.Cells[k, j];
          Grid.Cells[k, j] := Grid.Cells[k, j + 1];
          Grid.Cells[k, j + 1] := Temp;
        end;
      end;
end;

function TForm1.GetPortDescription(Port: integer): string;
begin
  case Port of
    20: Result := 'FTP Data Transfer';
    21: Result := 'FTP Command Control';
    22: Result := 'Secure Shell (SSH)';
    23: Result := 'Telnet';
    25: Result := 'Simple Mail Transfer Protocol (SMTP)';
    53: Result := 'Domain Name System (DNS)';
    80: Result := 'Hypertext Transfer Protocol (HTTP)';
    110: Result := 'Post Office Protocol (POP3)';
    119: Result := 'Network News Transfer Protocol (NNTP)';
    123: Result := 'Network Time Protocol (NTP)';
    135: Result := 'Microsoft RPC';
    139: Result := 'NetBIOS';
    143: Result := 'Internet Message Access Protocol (IMAP)';
    161: Result := 'Simple Network Management Protocol (SNMP)';
    194: Result := 'Internet Relay Chat (IRC)';
    389: Result := 'LDAP';
    443: Result := 'HTTPS - HTTP over TLS/SSL';
    445: Result := 'Microsoft-DS (SMB)';
    465: Result := 'SMTPS - Secure SMTP over SSL (deprecated)';
    554: Result := 'Real Time Streaming Protocol (RTSP)';
    587: Result := 'SMTP Mail Submission';
    631: Result := 'Internet Printing Protocol (IPP)';
    993: Result := 'IMAPS - IMAP over SSL';
    995: Result := 'POP3S - POP3 over SSL';
    1433: Result := 'Microsoft SQL Server';
    1521: Result := 'Oracle database default listener';
    1723: Result := 'Point-to-Point Tunneling Protocol (PPTP)';
    2049: Result := 'Network File System (NFS)';
    2082: Result := 'cPanel default';
    2083: Result := 'cPanel over SSL';
    2086: Result := 'Web Host Manager default';
    2087: Result := 'Web Host Manager over SSL';
    2095: Result := 'cPanel Webmail';
    2096: Result := 'cPanel Secure Webmail';
    3306: Result := 'MySQL Database Server';
    3389: Result := 'Remote Desktop Protocol (RDP)';
    5060: Result := 'Session Initiation Protocol (SIP)';
    5222: Result := 'XMPP/Jabber Client Connection';
    5269: Result := 'XMPP/Jabber Server Connection';
    5432: Result := 'PostgreSQL database';
    5900: Result := 'Virtual Network Computing (VNC)';
    6001: Result := 'X11:1';
    8080: Result := 'HTTP Alternate (http_alt)';
    8443: Result := 'HTTPS Alternate';
    10000: Result := 'Webmin';
    else
      Result := 'Unknown';
  end;
end;



procedure TForm1.ButtonScanPortsClick(Sender: TObject);
var
  SelectedIP: string;
  SelectedRow: integer;
  PortListString: string;
  PortArray: array of integer;

  i, PortNumber: integer;
begin
  PortListstring :=
    '20,21,22,23,25,53,80,110,119,123,135,139,143,161,194,389,443,445,465,554,587,631,' +
    '993,995,1433,1521,1723,2049,2082,2083,2086,2087,2095,2096,3306,3389,5060,5222,5269,'
    +
    '5432,5900,6001,8080,8443,10000';
  unit2.stoppressed := 0;
  // Check if a row is selected
  SelectedRow := StringGrid1.Row; // Assuming StringGrid1 is your main form StringGrid
  if (SelectedRow > 0) and (SelectedRow < StringGrid1.RowCount) then
  begin
    SelectedIP := StringGrid1.Cells[0, SelectedRow];
    // Assuming IPs are in the first column

    FormScanResults.WindowState := wsnormal;
    FormScanResults.Show;

    // Prepare the StringGrid on FormScanResults
    with FormScanResults.StringGridResults do
    begin
      RowCount := 1; // Reset to 1 to keep the header row
      Cells[0, 0] := 'IP';
      Cells[1, 0] := 'Port';
      Cells[2, 0] := 'Status';
      Cells[3, 0] := 'Description';
      Cells[4, 0] := 'Banner';

    end;
    FormScanResults.StringGridResults.AutoSizeColumns;

    // Perform the port scan for the selected IP

    FormScanResults.edit1.Text := 'Scanning Ports!';
    formscanresults.edit1.Refresh;

    // Split the string and convert each part to an integer
    with TStringList.Create do
    try
      Delimiter := ',';
      DelimitedText := PortListString;
      SetLength(PortArray, Count);

      for i := 0 to Count - 1 do
      begin
        if TryStrToInt(Strings[i], PortNumber) then
          PortArray[i] := PortNumber
        else
          raise Exception.Create('Invalid port number: ' + Strings[i]);
      end;
    finally
      Free;
    end;

    CompletedScans := 0;


    FormScanResults.ProgressBar1.Min := 0;
    FormScanResults.ProgressBar1.Max := 100; // For percentage
    FormScanResults.ProgressBar1.Position := 0;



    TotalScans := Length(PortArray);
    StartPortScanning(SelectedIP, PortArray); // Example IP and ports

  end
  else
    ShowMessage('Please select a row with an IP address.');
end;



constructor TPingTaskQueue.Create;
begin
  inherited Create;
  FTaskList := TList.Create;
  FCriticalSection := TCriticalSection.Create;
end;

destructor TPingTaskQueue.Destroy;
begin
  FCriticalSection.Free;
  FTaskList.Free;
  inherited Destroy;
end;

procedure TPingTaskQueue.Lock;
begin
  FCriticalSection.Acquire;
end;

procedure TPingTaskQueue.Unlock;
begin
  FCriticalSection.Release;
end;

function TPingTaskQueue.GetCount: integer;
begin
  Result := FTaskList.Count;
end;




function TPingTaskQueue.TryGetTask(out Task: TPingTask): boolean;
var
  TaskPtr: PPingTask;
begin
  FCriticalSection.Acquire;
  try
    Result := FTaskList.Count > 0;
    if Result then
    begin
      TaskPtr := PPingTask(FTaskList[0]);
      Task := TaskPtr^;
      Dispose(TaskPtr); // Free the memory allocated for the task
      FTaskList.Delete(0);
    end;
  finally
    FCriticalSection.Release;
  end;
end;

procedure TPingTaskQueue.AddTask(const Task: TPingTask);
var
  NewTask: PPingTask;
begin
  New(NewTask);
  NewTask^ := Task;
  FCriticalSection.Acquire;
  try
    FTaskList.Add(NewTask);
  finally
    FCriticalSection.Release;
  end;
end;



procedure TPingThread.Execute;
var
  Task: TPingTask;
  ErrCode: DWORD;
begin
  ErrCode := 0;
  while not Terminated do  // Continue looping until the thread is terminated
  begin
    // Attempt to get a task from the queue
    if Form1.TaskQueue.TryGetTask(Task) then
    begin
      FTask := Task;
      // Process the task
      FPingResult := PingHostFun(Task.IPAddress);

      // Optional: Get additional information
      if Form1.CheckBox1.Checked then
        FHostName := IPAddrToName(Task.IPAddress)
      else
        FHostName := 'N/A';

      if Form1.CheckBox2.Checked then
        FMacAddress := GetMacAddr(Task.IPAddress, ErrCode)
      else
        FMacAddress := 'N/A';

      // Synchronize the UI update
      Synchronize(@UpdateUI);

      InterlockedDecrement(ActiveTasks);

    end
    else
    begin
      // If no task is available, wait before trying again
      Sleep(100);
      Break;  // Exit the loop if there are no more tasks
    end;
  end;
  if (ActiveTasks = 0) then
  begin

    Synchronize(@Form1.FinalizeTasks);

  end;
end;



procedure TForm1.SortStringGrid;
var
  i, j: integer;
begin

  edit3.Text := 'Sorting!';
  // Basic bubble sort for demonstration
  for i := 1 to StringGrid1.RowCount - 1 do
    for j := i + 1 to StringGrid1.RowCount - 1 do
      if CompareIPs(StringGrid1.Cells[0, i], StringGrid1.Cells[0, j]) > 0 then
      begin
        // Swap rows if the IP address at i is greater than the one at j
        MoveRow(StringGrid1, i, j);
      end;
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


procedure TForm1.StringGrid1DrawCell(Sender: TObject; aCol, aRow: integer;
  aRect: TRect; aState: TGridDrawState);
var
  Grid: TStringGrid;
  Arrow: string;
begin
  Grid := Sender as TStringGrid;

  if (aRow = 0) and (aCol = LastSortedColumn) then
  begin
    Grid.Canvas.FillRect(aRect); // Fill the cell background

    if SortAscending[aCol] then
      Arrow := ' ↑' // Arrow pointing upwards for ascending order
    else
      Arrow := ' ↓'; // Arrow pointing downwards for descending order

    Grid.Canvas.TextOut(aRect.Left + 2, aRect.Top + 2, Grid.Cells[aCol, aRow] + Arrow);
    //stringgrid1.AutoSizeColumns;
  end
  else if aRow = 0 then
  begin
    // For other header cells without sorting arrow
    Grid.Canvas.FillRect(aRect);
    Grid.Canvas.TextOut(aRect.Left + 2, aRect.Top + 2, Grid.Cells[aCol, aRow]);
  end
  else
  begin
    // For non-header cells
    Grid.Canvas.FillRect(aRect);
    Grid.Canvas.TextOut(aRect.Left + 2, aRect.Top + 2, Grid.Cells[aCol, aRow]);
  end;
end;


function tform1.SplitString(const aString, Delimiter: string): TStringList;
var
  s: string;
  p: integer;
begin
  Result := TStringList.Create;
  s := aString;

  while Length(s) > 0 do
  begin
    p := Pos(Delimiter, s);
    if p > 0 then
    begin
      Result.Add(Copy(s, 1, p - 1));
      s := Copy(s, p + Length(Delimiter), Length(s));
    end
    else
    begin
      Result.Add(s);
      Break;
    end;
  end;
end;

function tform1.CompareIPs2(IP1, IP2: string): integer;
var
  Parts1, Parts2: TStringList;
  i, Num1, Num2: integer;
begin
  Result := 0;
  Parts1 := SplitString(IP1, '.');
  Parts2 := SplitString(IP2, '.');

  try
    for i := 0 to 3 do
    begin
      if Parts1.Count > i then
        Num1 := StrToInt(Parts1[i])
      else
        Num1 := 0;

      if Parts2.Count > i then
        Num2 := StrToInt(Parts2[i])
      else
        Num2 := 0;

      if Num1 < Num2 then
      begin
        Result := -1;
        Break;
      end
      else if Num1 > Num2 then
      begin
        Result := 1;
        Break;
      end;
    end;
  finally
    Parts1.Free;
    Parts2.Free;
  end;
end;

procedure TForm1.StringGrid1HeaderClick(Sender: TObject; IsColumn: boolean;
  Index: integer);
var
  i, j: integer;
  Temp: string;
  Sorted: boolean;
  CompareResult: integer;
begin
  if IsColumn then
  begin
    repeat
      Sorted := True;
      for i := 1 to StringGrid1.RowCount - 2 do
      begin
        // Compare the cells in the clicked column
        if Index = 0 then
        begin
          if SortAscending[Index] then
            CompareResult := CompareIPs(StringGrid1.Cells[Index, i],
              StringGrid1.Cells[Index, i + 1])
          else
            CompareResult := CompareIPs(StringGrid1.Cells[Index, i + 1],
              StringGrid1.Cells[Index, i]);
        end
        else if SortAscending[Index] then
          // Standard text comparison for other columns
          CompareResult := AnsiCompareText(StringGrid1.Cells[Index, i],
            StringGrid1.Cells[Index, i + 1])
        else
          CompareResult := AnsiCompareText(StringGrid1.Cells[Index, i + 1],
            StringGrid1.Cells[Index, i]);

        // Swap rows if the comparison result indicates they are out of order
        if CompareResult > 0 then
        begin
          for j := 0 to StringGrid1.ColCount - 1 do
          begin
            Temp := StringGrid1.Cells[j, i];
            StringGrid1.Cells[j, i] := StringGrid1.Cells[j, i + 1];
            StringGrid1.Cells[j, i + 1] := Temp;
          end;
          Sorted := False;
        end;
      end;
    until Sorted;

    // Toggle the sort order for the next click
    SortAscending[Index] := not SortAscending[Index];
    LastSortedColumn := Index;
    StringGrid1.Invalidate;
  end;
end;




procedure TPingThread.UpdateUI;
var
  RowIndex, PercentComplete: integer;
begin
  with Form1.StringGrid1 do
  begin
    // Lock the grid or ensure thread safety before updating
    ThreadLock.Acquire;

    try

      RowIndex := RowCount; // Get current row count
      RowCount := RowCount + 1; // Increase row count to add a new row

      // Update the grid with the ping results
      Cells[0, RowIndex] := FTask.IPAddress;       // IP Address
      Cells[1, RowIndex] := FPingResult; // Ping Result
      Cells[2, RowIndex] := FHostName;             // Host Name
      Cells[3, RowIndex] := FMacAddress;           // MAC Address


      if IPList.Count > 0 then
        // Avoid division by zero
      begin
        PercentComplete := (rowcount * 100) div IPList.Count;
        form1.ProgressBar1.Position := PercentComplete;
      end;
    finally
      ThreadLock.Release;
    end;
  end;

  // Additional UI updates can be added here if needed
end;



{ TForm1 }

function CompareIPs(const IP1, IP2: string): integer;
var
  Parts1, Parts2: TStringList;
  i, Num1, Num2: integer;
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
  IPAddress: Winsock.in_addr;
  startIP, endIP: string;
  Task: TPingTask;
begin

  progressbar1.Position := 0;
  ActiveTasks := 0;
  edit3.Text := '';
  stringgrid1.Clear;
  stringgrid1.RowCount := 1;
  stringgrid1.Fixedrows := 1;
  with StringGrid1 do
  begin
    Cells[0, 0] := 'IP';
    Cells[1, 0] := 'Reply';
    Cells[2, 0] := 'Name';
    Cells[3, 0] := 'MAC Address';
  end;

  // Get the start and end IPs from the user inputs
  startIP := Edit1.Text; // Start IP from Edit1
  endIP := Edit2.Text;   // End IP from Edit2

  // Convert the start and end IPs from strings to numeric format
  IPAddress.s_addr := inet_addr(PChar(startIP));
  ipindexstart := ntohl(IPAddress.s_addr);
  // Convert from network byte order to host byte order

  IPAddress.s_addr := inet_addr(PChar(endIP));
  ipindexend := ntohl(IPAddress.s_addr);

  // Check if the IP addresses are valid
  if (ipindexstart = INADDR_NONE) or (ipindexend = INADDR_NONE) then
  begin
    ShowMessage('Invalid IP address format');
    Exit;
  end;

  if (ipindexend < ipindexstart) then
  begin
    ShowMessage('Starting Has to be less than ending IP');
    exit;
  end;

  // Clear the previous list of IP addresses
  IPList.Clear;
  edit3.Text := 'Scanning!';
  // Iterate over the IP range and add each IP to the list
  for I := ipindexstart to ipindexend do
  begin
    IPAddress.s_addr := htonl(I); // Convert back to network byte order
    IPList.Add(inet_ntoa(IPAddress)); // Convert to string and add to the list
  end;

  // Enqueue tasks into the TaskQueue
  for startIP in IPList do
  begin
    Task.IPAddress := startIP;
    InterlockedIncrement(ActiveTasks);
    TaskQueue.AddTask(Task);

  end;

  // Start processing the tasks
  StartThreads;
end;




procedure TForm1.Button2Click(Sender: TObject);
var
  i: integer;
begin
  // Signal all threads to terminate
  for i := 0 to High(ThreadPool) do
  begin
    if Assigned(ThreadPool[i]) and not ThreadPool[i].Finished then
    begin
      ThreadPool[i].Terminate; // Signal the thread to terminate
    end;
  end;

  // Wait for all threads to finish
  for i := 0 to High(ThreadPool) do
  begin
    if Assigned(ThreadPool[i]) then
    begin
      ThreadPool[i].WaitFor; // Wait for the thread to finish
      FreeAndNil(ThreadPool[i]); // Free the thread object
    end;
  end;

  // Clear the task queue to prevent new tasks from being started
  with TaskQueue.LockList do
  try
    Clear; // Clear all pending tasks
  finally
    TaskQueue.UnlockList;
  end;
  ActiveTasks := 0; // Reset ActiveTasks count
  edit3.Text := 'Stopped!';

  // Additional logic to update the UI or application state can be added here
end;




function TPingThread.PingHostfun(const Host: string): string;
begin
  Result := 'N/A';



  with TPINGSend.Create do

  try
    Timeout := form1.spinedit1.Value;
    if Ping(host) then
    begin
      if ReplyError = IE_NoError then
      begin

        Result := IntToStr(PingTime) + ' ms';

      end

      else
        Result := 'N/A';
    end
    else
    begin
      Result := 'N/A';
    end;

  finally
    Free;
  end;
end;




procedure DumpExceptionCallStack(E: Exception);
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


procedure TForm1.FinalizeTasks;
begin

  ThreadLock.Acquire;
  try
    SortStringGrid;
    edit3.Text := 'Auto Sizing Comumns';
    StringGrid1.AutoSizeColumns;

    Edit3.Text := 'Complete!';
  finally
    ThreadLock.Release;
  end;
  trimappmemorysize;

end;

procedure TForm1.tracertMenuItemClick(Sender: TObject);
begin
  ButtonTracertClick(Sender);
end;

procedure TForm1.PingMenuItemClick(Sender: TObject);
begin
  ButtonPingClick(Sender);
end;


procedure TForm1.PortScanMenuItemClick(Sender: TObject);
begin
  ButtonScanPortsClick(Sender);
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  CopyMenuItem: TMenuItem;
  PortScanMenuItem: TMenuItem;
  LookupMACMenuItem, PingMenuItem, tracertmenuitem: TMenuItem;
begin
  LastSortedColumn := -1;
  stoppressed := 0;
  // Initialize the critical section for thread synchronization
  ThreadLock := TCriticalSection.Create;

  // Initialize the task queue for managing ping tasks
  TaskQueue := TPingTaskQueue.Create;

  // Initialize the list for storing IP addresses
  IPList := TStringList.Create;




  // Create the popup menu
  StringGrid1.PopupMenu := TPopupMenu.Create(StringGrid1);

  // Create the port scan menu item
  PingMenuItem := TMenuItem.Create(StringGrid1.PopupMenu);
  PingMenuItem.Caption := 'Ping (Single)';
  PingMenuItem.OnClick := @PingMenuItemClick;
  StringGrid1.PopupMenu.Items.Add(PingMenuItem);

  // Create the port scan menu item
  tracertMenuItem := TMenuItem.Create(StringGrid1.PopupMenu);
  tracertMenuItem.Caption := 'Traceroute (Single)';
  tracertMenuItem.OnClick := @tracertMenuItemClick;
  StringGrid1.PopupMenu.Items.Add(tracertMenuItem);



  // Create the port scan menu item
  PortScanMenuItem := TMenuItem.Create(StringGrid1.PopupMenu);
  PortScanMenuItem.Caption := 'Scan Ports (Single)';
  PortScanMenuItem.OnClick := @PortScanMenuItemClick;
  StringGrid1.PopupMenu.Items.Add(PortScanMenuItem);

  // Initialize the popup menu and its item

  LookupMACMenuItem := TMenuItem.Create(StringGrid1.PopupMenu);
  LookupMACMenuItem.Caption := 'Look up Manufacturer (Single)';
  LookupMACMenuItem.OnClick := @LookupMACMenuItemClick;
  StringGrid1.PopupMenu.Items.Add(LookupMACMenuItem);


  // Create the copy menu item
  CopyMenuItem := TMenuItem.Create(StringGrid1.PopupMenu);
  CopyMenuItem.Caption := 'Copy (Multiple)';
  CopyMenuItem.OnClick := @CopyMenuItemClick;
  StringGrid1.PopupMenu.Items.Add(CopyMenuItem);


  edit1.Text := GetLocalIPAddress;
  edit2.Text := GetLocalIPAddress;

  SpinEdit1.Value := 4000;
  with StringGrid1 do
  begin
    Cells[0, 0] := 'IP';
    Cells[1, 0] := 'Reply';
    Cells[2, 0] := 'Name';
    Cells[3, 0] := 'MAC Address';
  end;
  stringgrid1.AutoSizeColumns;

  SetLength(SortAscending, StringGrid1.ColCount);
  // Initialize all columns to sort ascending initially
  FillChar(SortAscending[0], Length(SortAscending) * SizeOf(boolean), False);

  // Other initializations...
end;

procedure TForm1.LookupMACMenuItemClick(Sender: TObject);
var
  MACAddress: string;
  ShortName, LongName: string;
  MACPrefix, dbname, dllname: string;
begin
  if StringGrid1.Row >= 0 then
  begin
    MACAddress := StringGrid1.Cells[3, StringGrid1.Row];
    // Assuming MAC is in the 5th column
    // Replace hyphens with colons and extract the MAC prefix (first 8 characters)

    if Pos('-', macAddress) = 3 then
    begin

      MACPrefix := StringReplace(Copy(MACAddress, 1, 8), '-', ':', [rfReplaceAll]);
      dbname := 'mac.db';
      dllname := 'sqlite3.dll';
      if FileExists(dbname) then
      begin
        if FileExists(dllname) then
        begin
          // Call your function to look up the MAC manufacturer using the prefix
          LookupMAC(MACPrefix, ShortName, LongName, dbname);

          // Show the results
          ShowMessage('MAC Prefix: ' + MACPrefix + sLineBreak +
            'Short Name: ' + ShortName + sLineBreak + 'Long Name: ' + LongName);
        end
        else
          ShowMessage(dllname +
            ' Not found did you place it in the same directory as the exe?');

      end
      else
        ShowMessage(dbname +
          ' Not found did you place it in the same directory as the exe?');

    end
    else
      ShowMessage(macprefix + ' Not a valid MAC address!');
  end;
end;

function tform1.LookupMAC(macPrefix: string; out ShortName, LongName: string;
  dbname: string): boolean;
var
  dbConnection: TSQLite3Connection;
  sqlTransaction: TSQLTransaction;
  sqlCommand: TSQLQuery;
begin
  ShortName := '';
  LongName := '';
  Result := False;

  // Initialize database connection
  dbConnection := TSQLite3Connection.Create(nil);
  sqlTransaction := TSQLTransaction.Create(dbConnection);
  sqlCommand := TSQLQuery.Create(nil);

  try
    dbConnection.DatabaseName := dbname; // Set your database path
    dbConnection.Connected := True;
    sqlCommand.Database := dbConnection;
    sqlCommand.Transaction := sqlTransaction;
    sqlTransaction.Database := dbConnection;
    sqlTransaction.StartTransaction;

    // Prepare and execute SQL command
    sqlCommand.SQL.Text :=
      'SELECT short_name, full_name FROM mac_addresses WHERE prefix = :prefix';
    sqlCommand.ParamByName('prefix').AsString := macPrefix;
    sqlCommand.Open;

    if not sqlCommand.EOF then
    begin
      ShortName := sqlCommand.FieldByName('short_name').AsString;
      LongName := sqlCommand.FieldByName('full_name').AsString;
      Result := True; // Indicate that a record was found
    end;

    sqlTransaction.Commit;
  finally
    sqlCommand.Free;
    sqlTransaction.Free;
    dbConnection.Free;
  end;
end;


procedure TForm1.CopyMenuItemClick(Sender: TObject);
var
  S: string;
  i, j: integer;
begin
  S := '';
  with StringGrid1 do
  begin
    for i := Selection.Top to Selection.Bottom do
    begin
      for j := Selection.Left to Selection.Right do
      begin
        S := S + Cells[j, i] + #9; // Tab delimited
      end;
      SetLength(S, Length(S) - 1); // Remove last tab
      S := S + sLineBreak; // Add a line break after each row
    end;
  end;
  Clipboard.AsText := S; // Copy to clipboard
end;

procedure TForm1.buttonpingClick(Sender: TObject);
var
  ip: string;
begin
  if StringGrid1.Row >= 0 then
  begin
    IP := StringGrid1.Cells[0, StringGrid1.Row];
    if (pos('.', ip) > 0) then
    begin
      pingtrace.WindowState := wsNormal;
      pingtrace.Show;
      pingtrace.memo1.Clear;
      pingtrace.memo1.Lines.add('Pinging...');
      application.ProcessMessages;
      pingtrace.memo1.Lines.add(pinghostfun2(ip));
    end;
  end;
end;

procedure TForm1.buttontracertClick(Sender: TObject);
var
  ip: string;
begin
  if StringGrid1.Row >= 0 then

    IP := StringGrid1.Cells[0, StringGrid1.Row];
  if (pos('.', ip) > 0) then
  begin
    pingtrace.WindowState := wsNormal;
    pingtrace.Show;
    pingtrace.memo1.Clear;
    pingtrace.memo1.Lines.add('Tracerouting...');
    application.ProcessMessages;
    pingtrace.memo1.Lines.add(traceroutehostfun(ip));
  end;
end;


procedure TForm1.FormDestroy(Sender: TObject);
begin
  // Ensure all running threads are properly terminated and freed
  StopThreads;  // Implement this to handle your threads' termination

  // Free the task queue
  TaskQueue.Free;

  // Free the list of IP addresses
  IPList.Free;

  // Free the critical section object
  ThreadLock.Free;

  // Free other dynamically allocated resources
  // ...
end;

procedure TForm1.StartThreads;
var
  i, ThreadCount: integer;
begin
  // Determine the number of threads to create based on ActiveTasks and MaxThreads
  if ActiveTasks <= MaxThreads then
    ThreadCount := ActiveTasks
  else
    ThreadCount := MaxThreads;

  // Resize the ThreadPool array based on the determined ThreadCount
  SetLength(ThreadPool, ThreadCount);

  // Create and start threads
  for i := 0 to High(ThreadPool) do
  begin
    ThreadPool[i] := TPingThread.Create(True); // Create the thread suspended
    ThreadPool[i].FreeOnTerminate := False;
    ThreadPool[i].Start; // Start the thread
  end;
end;


procedure TForm1.StopThreads;
var
  i: integer;
begin
  // Signal all threads to terminate
  for i := 0 to High(ThreadPool) do
  begin
    if Assigned(ThreadPool[i]) and not ThreadPool[i].Finished then
      ThreadPool[i].Terminate;
  end;

  // Wait for all threads to finish
  for i := 0 to High(ThreadPool) do
  begin
    if Assigned(ThreadPool[i]) then
    begin
      ThreadPool[i].WaitFor;
      FreeAndNil(ThreadPool[i]);
    end;
  end;
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

function TPingTaskQueue.LockList: TList;
begin
  FCriticalSection.Acquire;
  Result := FTaskList;
end;

procedure TPingTaskQueue.UnlockList;
begin
  FCriticalSection.Release;
end;

procedure TForm1.TrimAppMemorySize;
var
  MainHandle: THandle;
begin
  // It's better to use PROCESS_SET_QUOTA instead of PROCESS_ALL_ACCESS
  // as it requires fewer privileges and is more specific to the task.
  MainHandle := OpenProcess(PROCESS_SET_QUOTA, False, GetCurrentProcessID);
  if MainHandle <> 0 then
  begin
    try
      // The magic numbers $FFFFFFFF are replaced with -1 for readability
      // It tells Windows to trim the working set to the minimum possible size
      if not SetProcessWorkingSetSize(MainHandle, cardinal(-1), cardinal(-1)) then
        RaiseLastOSError; // Raise an error if the function fails
    finally
      CloseHandle(MainHandle); // Ensure the handle is closed in all cases
    end;
  end
  else
    RaiseLastOSError; // Raise an error if OpenProcess fails

  // Application.ProcessMessages should be used cautiously
  // It's not typically needed in a memory trimming routine
  // Application.ProcessMessages;
end;

function TPortScanThread.HexToString(H: string): string;
var
  I: integer;
  B: byte;
begin
  Result := '';
  H := H.Replace(' ', ''); // Remove spaces if any
  for I := 1 to Length(H) div 2 do
  begin
    B := StrToInt('$' + Copy(H, (I - 1) * 2 + 1, 2));
    Result := Result + Chr(B);
  end;
end;

function tform1.PingHostfun2(const Host: string): string;
var
  low, high, timetotal, j, success: integer;
  ipaddrval: string;
begin
  Result := '';

  ipaddrval := host;
  if ipaddrval = '' then
  begin
    Result := 'Could not resolve IP Address!';
    application.ProcessMessages;
    exit;
  end;

  with TPINGSend.Create do

  try
    success := 0;
    timetotal := 0;
    low := 99999;
    high := 0;
    Result := 'Pinging ' + ipaddrval + ' with ' + IntToStr(PacketSize) +
      ' bytes of data:' + #13#10;
    for j := 1 to 4 do
    begin
      if Ping(ipaddrval) then
      begin
        if ReplyError = IE_NoError then
        begin
          Result := Result + 'Reply from ' + ReplyFrom + ': bytes=' +
            IntToStr(PacketSize) + ' time=' + IntToStr(PingTime) +
            ' TTL=' + IntToStr(Ord(TTL)) + #13#10;
          timetotal := timetotal + pingtime;
          success := success + 1;
          if pingtime < low then
            low := pingtime;
          if pingtime > high then
            high := pingtime;
        end

        else
          Result := Result + 'Reply from ' + ReplyFrom + ': ' +
            ReplyErrorDesc + #13#10;
      end
      else
      begin
        Result := Result + 'Ping Failed!' + #13#10;
        low := 0;
        break;
      end;
    end;

    Result := Result + #13#10 + 'Ping statistics for ' + ipaddrval + ':'#13#10;
    Result := Result + 'Packets: Sent = ' + IntToStr(j) + ', Received = ' +
      IntToStr(success) + ', Lost = ' + IntToStr(j - success) + ' (' +
      IntToStr(trunc((100 - ((success / j) * 100)))) + '% loss)' + #13#10;
    Result := Result + 'Approximate round trip times in milli-seconds: ' +
      IntToStr(timetotal) + 'ms' + #13#10;
    Result := Result + 'Minimum = ' + IntToStr(low) + 'ms, Maximum = ' +
      IntToStr(high) + 'ms, Average = ' + IntToStr(trunc(timetotal / j)) +
      'ms' + #13#10;

  finally
    Free;
  end;
end;

function tform1.Pingtracertrttl(const Host: string): string;
var
  j: integer;
begin

  Result := '';
  with TPINGSend.Create do
  try
    for j := 1 to 2 do
    begin
      if Ping(Host) then
      begin
        if ReplyError = IE_NoError then
        begin
          Result := Result + IntToStr(PingTime) + ' ms    ';
        end

        else
          Result := Result + '*     ';
      end
      else
        Result := Result + '*     ';
    end;

  finally
    Free;
  end;
end;

function tform1.TraceRouteHostfun(const Host: string): string;
var
  Ping: TPingSend;
  ttl: byte;
  hopcount: integer;
  ipaddrval: string;
begin

  ipaddrval := host;
  if ipaddrval = '' then
  begin
    Result := 'Could not resolve IP Address!';
    application.ProcessMessages;
    exit;
  end;

  hopcount := 0;
  Result := 'Tracing route to ' + ipaddrval + ' over a maximum of 30 hops' + crlf + crlf;

  Ping := TPINGSend.Create;
  try
    ttl := 1;
    repeat
      hopcount := hopcount + 1;
      ping.TTL := ttl;
      Inc(ttl);
      if ttl > 31 then
        Break;
      if not ping.Ping(ipaddrval) then
      begin
        Result := Result + IntToStr(hopcount) + '    ' + cAnyHost + ' Timeout' + CRLF;
        continue;
      end;
      if (ping.ReplyError <> IE_NoError) and (ping.ReplyError <>
        IE_TTLExceed) then
      begin
        Result := Result + IntToStr(hopcount) + '    ' + Ping.ReplyFrom +
          ' ' + Ping.ReplyErrorDesc + CRLF;
        break;
      end;

      Result := Result + IntToStr(hopcount) + '    ' + IntToStr(Ping.PingTime) +
        ' ms    ' + Pingtracertrttl(Ping.ReplyFrom) + Ping.ReplyFrom + CRLF;
    until ping.ReplyError = IE_NoError;

    Result := Result + crlf + 'Trace complete.';

  finally
    Ping.Free;
  end;
end;

//initialization
  //SSLImplementation := TSSLOpenSSL;  // Initialize OpenSSL for SSL support

end.
