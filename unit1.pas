unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Spin, Grids, pingsend,  winsock, sockets, Windows,
  SyncObjs, Clipbrd, Menus, ComCtrls,unit2;


var


  ThreadLock: TCriticalSection;
  MaxThreads: integer = 255; // Set your max threads here
  IPList: TStringList;
  ActiveTasks: integer = 0;
  ProcessedIPs: integer = 0;




type

  // Assuming TPingTask is a simple record for demonstration
  TPingTask = record
    IPAddress: string;
    Data: string;
  end;

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

  TPingThread = class(TThread)
  private
    FTask: TPingTask;

      FHostName, FMacAddress: string;
    FPingResult: integer;
    procedure UpdateUI;
    function PingHostfun(const Host: string): integer;
    function GetMacAddr(const IPAddress: string; var ErrCode: DWORD): string;
    function IPAddrToName(IPAddr: string): string;

  protected
    procedure Execute; override;
  public
  end;

  PPingTask = ^TPingTask; // Pointer to TPingTask


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
    ProgressBar1: TProgressBar;
    SpinEdit1: TSpinEdit;
    StringGrid1: TStringGrid;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure SortStringGrid;
    procedure MoveRow(Grid: TStringGrid; FromIndex, ToIndex: integer);
    procedure TrimAppMemorySize;
    function CalculateNumberOfIPsInRange: integer;
    function GetLocalIPAddress: string;
    procedure FinalizeTasks;
   procedure ScanPorts(const IPAddress, PortList: string; ResultsGrid: TStringGrid);
    function GetPortDescription(Port: Integer): string;
    procedure ButtonScanPortsClick(Sender: TObject);
  private
    TaskQueue: TPingTaskQueue;
    ThreadPool: array of TPingThread;
    procedure StartThreads;
    procedure StopThreads;
    procedure DumpExceptionCallStack(E: Exception);
    procedure CopyMenuItemClick(Sender: TObject);
     procedure PortScanMenuItemClick(Sender: TObject);
     // procedure UpdateGrid(IP: String; Port: Integer; Description: String; Status: String);
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

 procedure TForm1.ScanPorts(const IPAddress, PortList: string; ResultsGrid: TStringGrid);
var
  ClientSocket: LongInt;
  SockAddr: TInetSockAddr;
  Ports: TStringList;
  i, Port: Integer;
  PortStatus, PortDescription: string;
begin
  Ports := TStringList.Create;
  try
    Ports.CommaText := PortList; // Splitting the comma-delimited list into individual ports

    for i := 0 to Ports.Count - 1 do
    begin
      if TryStrToInt(Ports[i], Port) then
      begin
        ClientSocket := fpSocket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        if ClientSocket <> -1 then
        begin
          SockAddr.sin_family := AF_INET;
          SockAddr.sin_port := htons(Port);
          SockAddr.sin_addr.s_addr := inet_addr(PChar(IPAddress));

          if fpConnect(ClientSocket, @SockAddr, SizeOf(SockAddr)) = 0 then
            PortStatus := 'Open'
          else
            PortStatus := 'Closed';

          PortDescription := GetPortDescription(Port);

          // Update the grid

              ResultsGrid.RowCount := ResultsGrid.RowCount + 1;
              ResultsGrid.Cells[0, ResultsGrid.RowCount - 1] := IPAddress;
              ResultsGrid.Cells[1, ResultsGrid.RowCount - 1] := IntToStr(Port);
              ResultsGrid.Cells[2, ResultsGrid.RowCount - 1] := PortDescription;
              ResultsGrid.Cells[3, ResultsGrid.RowCount - 1] := PortStatus;

              resultsgrid.Refresh;

          fpshutdown(ClientSocket, 2);
          CloseSocket(ClientSocket);
        end;
      end;
    end;
  finally
    Ports.Free;
  end;
end;





 function TForm1.GetPortDescription(Port: Integer): string;
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
    143: Result := 'Internet Message Access Protocol (IMAP)';
    161: Result := 'Simple Network Management Protocol (SNMP)';
    194: Result := 'Internet Relay Chat (IRC)';
    443: Result := 'HTTPS - HTTP over TLS/SSL';
    465: Result := 'SMTPS - Secure SMTP over SSL (deprecated)';
    587: Result := 'SMTP Mail Submission';
    993: Result := 'IMAPS - IMAP over SSL';
    995: Result := 'POP3S - POP3 over SSL';
    3306: Result := 'MySQL Database Server';
    3389: Result := 'Remote Desktop Protocol (RDP)';
  else
    Result := 'Unknown';
  end;
end;


 procedure TForm1.ButtonScanPortsClick(Sender: TObject);
var
  SelectedIP, PortList: string;
  SelectedRow: Integer;
begin
  PortList := '20,21,22,23,25,53,80,110,119,123,143,161,194,443,465,587,993,995,3306,3389'; // Example port list

  // Check if a row is selected
  SelectedRow := StringGrid1.Row; // Assuming StringGrid1 is your main form StringGrid
  if (SelectedRow > 0) and (SelectedRow < StringGrid1.RowCount) then
  begin
    SelectedIP := StringGrid1.Cells[0, SelectedRow]; // Assuming IPs are in the first column

     FormScanResults.show;
    // FormScanResults.ShowModal;

    // Prepare the StringGrid on FormScanResults
    with FormScanResults.StringGridResults do
    begin
      RowCount := 1; // Reset to 1 to keep the header row
      Cells[0, 0] := 'IP';
      Cells[1, 0] := 'Port';
      Cells[2, 0] := 'Description';
      Cells[3, 0] := 'Status';
    end;

    // Perform the port scan for the selected IP

    FormScanResults.edit1.text:='Scanning Ports!';
    formscanresults.edit1.Refresh;
    ScanPorts(SelectedIP, PortList, FormScanResults.StringGridResults);
    FormScanResults.StringGridResults.AutoSizeColumns;
    FormScanResults.edit1.text:='Complete!';
    // Show the results
   // FormScanResults.ShowModal;
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
  Lock;
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
    Unlock;
  end;
end;

procedure TPingTaskQueue.AddTask(const Task: TPingTask);
var
  NewTask: PPingTask;
begin
  New(NewTask);
  NewTask^ := Task;
  Lock;
  try
    FTaskList.Add(NewTask);
  finally
    Unlock;
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

      Dec(ActiveTasks);

    end
    else
    begin
      // If no task is available, wait before trying again
      Sleep(100);
      Break;  // Exit the loop if there are no more tasks
    end;
  end;

  ThreadLock.Acquire;
  try

    if (ActiveTasks = 0) then
      Synchronize(@Form1.FinalizeTasks);
  finally
    ThreadLock.Release;
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
      Cells[1, RowIndex] := IntToStr(FPingResult); // Ping Result
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
  I,ipindexstart, ipindexend: cardinal;
  IPAddress: Winsock.in_addr;
  startIP, endIP: string;
  Task: TPingTask;
begin
  progressbar1.Position:=0;
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
    Cells[3, 0] := 'Mac Address';
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

  if (ipindexend<ipindexstart) then
  begin
    showmessage('Starting Has to be less than ending IP');
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
  ProcessedIPs := 0;
  // Enqueue tasks into the TaskQueue
  for startIP in IPList do
  begin
    Task.IPAddress := startIP;
    Inc(ActiveTasks);
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


procedure TForm1.FinalizeTasks;
begin
  if (ActiveTasks = 0) then  // Check if all threads are done
  begin
    SortStringGrid;
    edit3.Text := 'Auto Sizing Comumns';
    StringGrid1.AutoSizeColumns;
    edit3.Text := 'Trim App Memory Size';
    trimappmemorysize;
    Edit3.Text := 'Complete!';

  end;
end;
 procedure TForm1.PortScanMenuItemClick(Sender: TObject);
 begin
    ButtonScanPortsClick(Sender);
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  CopyMenuItem: TMenuItem;
  PortScanMenuItem: TMenuItem;
begin

  // Initialize the critical section for thread synchronization
  ThreadLock := TCriticalSection.Create;

  // Initialize the task queue for managing ping tasks
  TaskQueue := TPingTaskQueue.Create;

  // Initialize the list for storing IP addresses
  IPList := TStringList.Create;

  // Create the popup menu
  StringGrid1.PopupMenu := TPopupMenu.Create(StringGrid1);

  // Create the port scan menu item
  PortScanMenuItem := TMenuItem.Create(StringGrid1.PopupMenu);
  PortScanMenuItem.Caption := 'Scan Ports (Single)';
  PortScanMenuItem.OnClick := @PortScanMenuItemClick;
  StringGrid1.PopupMenu.Items.Add(PortScanMenuItem);
  // Create the copy menu item
  CopyMenuItem := TMenuItem.Create(StringGrid1.PopupMenu);
  CopyMenuItem.Caption := 'Copy (Multiple)';
  CopyMenuItem.OnClick := @CopyMenuItemClick;
  StringGrid1.PopupMenu.Items.Add(CopyMenuItem);


  edit1.Text := GetLocalIPAddress;
  edit2.Text := GetLocalIPAddress;

  SpinEdit1.Value := 1000;
  with StringGrid1 do
  begin
    Cells[0, 0] := 'IP';
    Cells[1, 0] := 'Reply';
    Cells[2, 0] := 'Name';
    Cells[3, 0] := 'Mac Address';
  end;


  // Other initializations...
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

end.
