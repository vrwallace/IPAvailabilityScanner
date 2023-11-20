unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs,
  StdCtrls, Spin, pingsend, blcksock, strutils, winsock, sockets, windows,SyncObjs;
  var
  stoppressed: Integer; // or Boolean, depending on your intended use
  ActiveThreads: Integer = 0;
  ThreadLock: TCriticalSection;
  MaxThreads: Integer = 255; // Set your max threads here



type
  TPingThread = class(TThread)
  private
    FIPAddress, FHostName, FMacAddress: string;
    FPingResult: Integer;
    procedure UpdateUI;
    function PingHostfun(const Host: string): integer;
    function GetMacAddr(const IPAddress: string; var ErrCode : DWORD): string;
    function IPAddrToName(IPAddr: string): string;
    function GetIPAddress(hostname: string): string;

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
    Memo1: TMemo;
    SpinEdit1: TSpinEdit;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure DumpExceptionCallStack(E: Exception);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    function GetLocalIPAddress: string;
  private
     //Semaphore: TSemaphore;
    ActiveThreads: Integer;
    procedure ThreadFinished;
    procedure SortMemoByIP;
    function CalculateNumberOfIPsInRange: Integer;
      procedure DoThreadFinished;
  public
    { Public declarations }
  end;
  function SendArp(DestIP,SrcIP:ULONG;pMacAddr:pointer;PhyAddrLen:pointer) : DWord; StdCall; external 'iphlpapi.dll' name 'SendARP';
  function YourCustomSortFunction(List: TStringList; Index1, Index2: Integer): Integer;
  function CompareIPs(const IP1, IP2: String): Integer;


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
 procedure TForm1.DoThreadFinished;
begin
  Dec(ActiveThreads);
  if ActiveThreads = 0 then
    SortMemoByIP;
end;
procedure TPingThread.Execute;
var
  errcode:dword;
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
  if (form1.checkbox1.checked) then FHostName := IPAddrToName(FIPAddress)
  else
  FHostName :='N/A';
  if (form1.checkbox2.checked) then FMacAddress := GetMacAddr(FIPAddress,ErrCode)
  else
  FMacAddress :='N/A';

  // Synchronize the UI update
  Synchronize(@UpdateUI);
  Synchronize(@Form1.ThreadFinished);

  finally
    ThreadLock.Acquire;
    try
      Dec(ActiveThreads);
      if ActiveThreads = 0 then
        Synchronize(@Form1.SortMemoByIP); // Sort when all threads are done
    finally
      ThreadLock.Release;
    end;
  end;
end;

procedure TPingThread.UpdateUI;
begin
  Form1.Memo1.Lines.Add(FIPAddress + #9 + IntToStr(FPingResult) + #9 + FHostName + #9 + FMacAddress);
  form1.edit3.Text := FIPAddress + #9 + IntToStr(FPingResult) + #9 + FHostName+#9+FMacAddress;
end;


{ TForm1 }
 procedure TForm1.ThreadFinished;
begin
  Dec(ActiveThreads);
  if ActiveThreads = 0 then
    SortMemoByIP;
end;

 procedure TForm1.SortMemoByIP;
 var
   List: TStringList;
 begin
   List := TStringList.Create;
   try
     List.AddStrings(Memo1.Lines);
     List.CustomSort(@YourCustomSortFunction);
     Memo1.Lines.Assign(List);
   finally
     List.Free;
   end;
 end;

 function YourCustomSortFunction(List: TStringList; Index1, Index2: Integer): Integer;
var
  IP1, IP2: String;
begin
  // Extracting the IP addresses from the lines.
  // Assuming IP addresses are at the beginning of each line, followed by a tab.
  IP1 := ExtractDelimited(1, List.Strings[Index1], [#9]); // or [' '] if separated by space
  IP2 := ExtractDelimited(1, List.Strings[Index2], [#9]);

  Result := CompareIPs(IP1, IP2);
end;


function CompareIPs(const IP1, IP2: String): Integer;
var
  Num1, Num2: Cardinal;
begin
  Num1 := inet_addr(PChar(IP1));
  Num2 := inet_addr(PChar(IP2));
  if Num1 < Num2 then
    Result := -1
  else if Num1 > Num2 then
    Result := 1
  else
    Result := 0;
end;

 function TForm1.CalculateNumberOfIPsInRange: Integer;
var
  StartIP, EndIP: Cardinal;
begin
  StartIP := inet_addr(PChar(Edit1.Text));
  EndIP := inet_addr(PChar(Edit2.Text));
  Result := ntohl(EndIP) - ntohl(StartIP) + 1;
end;
procedure TForm1.Button1Click(Sender: TObject);
var
  I,ipindexstart,ipindexend:Cardinal;
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
  ActiveThreads := CalculateNumberOfIPsInRange;
  memo1.Clear;
  // Memo1.Lines.add('Range: '+edit1.text+' to '+edit2.text);
   application.ProcessMessages;
  // Iterate over the IP range and create threads
  for I := ipindexstart to ipindexend do
  begin
    //IPAddress.s_addr := htonl(I); // Host to Network Long
                       IPAddress.s_addr :=i;
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
  edit1.text:=GetLocalIPAddress;
  edit2.text:=GetLocalIPAddress;
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
        Result := Format('%d.%d.%d.%d', [
          Byte(hostent^.h_addr^[0]),
          Byte(hostent^.h_addr^[1]),
          Byte(hostent^.h_addr^[2]),
          Byte(hostent^.h_addr^[3])
        ]);
      end;
    end;
  finally
    WSACleanup; // Clean up Winsock
  end;
end;






function TPingThread.GetIPAddress(hostname: string): string;
type
  pu_long = ^u_long;
var
  varTWSAData: TWSAData;
  varPHostEnt: PHostEnt;
  varTInAddr: winsock.TInAddr;
  //namebuf : Array[0..255] of char;
begin
  if trim(hostname) = '' then
  begin
    Result := '';
    exit;
  end;

  if WSAStartup($101, varTWSAData) <> 0 then
    Result := ''
  else
  begin

    //gethostname(namebuf,sizeof(namebuf));
    try
      varPHostEnt := gethostbyname(PAnsiChar(hostname));
      varTInAddr.S_addr := u_long(pu_long(varPHostEnt^.h_addr_list^)^);
      Result := inet_ntoa(varTInAddr);
    except
      on E: Exception do
        Result := '';
    end;
  end;
  WSACleanup;
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
 function TPingThread.GetMacAddr(const IPAddress: string; var ErrCode : DWORD): string;
var
MacAddr    : Array[0..5] of Byte;
DestIP     : ULONG;
PhyAddrLen : ULONG;
WSAData    : TWSAData;
begin
  Result    :='';
  WSAStartup($0101, WSAData);
  try
    ZeroMemory(@MacAddr,SizeOf(MacAddr));
    DestIP    :=inet_addr(PAnsiChar(IPAddress));
    PhyAddrLen:=SizeOf(MacAddr);
    ErrCode   :=SendArp(DestIP,0,@MacAddr,@PhyAddrLen);
    if ErrCode = S_OK then
     Result:=Format('%2.2x-%2.2x-%2.2x-%2.2x-%2.2x-%2.2x',[MacAddr[0], MacAddr[1],MacAddr[2], MacAddr[3], MacAddr[4], MacAddr[5]])
  finally
    WSACleanup;
  end;
end;

end.
