unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs,
  StdCtrls, Spin, pingsend, blcksock, strutils, winsock, sockets,windows;

type

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
    function PingHostfun(const Host: string): integer;
    function GetIPAddress(hostname: string): string;
    function IPAddrToName(IPAddr: string): string;

    function GetMacAddr(const IPAddress: string; var ErrCode : DWORD): string;
  private
    stoppressed: integer;

  public

  end;
  function SendArp(DestIP,SrcIP:ULONG;pMacAddr:pointer;PhyAddrLen:pointer) : DWord; StdCall; external 'iphlpapi.dll' name 'SendARP';
var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.Button1Click(Sender: TObject);
var
  pingresult: integer;
  S: string;
  I: cardinal;
  IPAddress: in_addr;
  my_array: array[0..255] of integer;
  oldsite, j, site: integer;
  iprev1, iprev2: string;
  ipindexstart, ipindexend: cardinal;
  macaddress,octet1, octet2, hostname: string;
  resolvehost,resolvemac: boolean;
  ErrCode : DWORD;
begin

  try

    if getipaddress(edit1.Text) = '' then
    begin
      ShowMessage('Start IP is Invalid');
      exit;
    end;

    if getipaddress(edit2.Text) = '' then
    begin
      ShowMessage('End IP is Invalid');
      exit;
    end;

    if (ExtractDelimited(1, edit1.Text, [#46]) <>
      ExtractDelimited(1, edit2.Text, [#46])) then
    begin
      ShowMessage('First and second octets of Start and End must match');
      exit;

    end;

    if (ExtractDelimited(2, edit1.Text, [#46]) <>
      ExtractDelimited(2, edit2.Text, [#46])) then
    begin
      ShowMessage('First and second octets of Start and End must match');
      exit;

    end;

    stoppressed := 0;
    oldsite := -1;
    memo1.Clear;
    edit3.Text := '';

    resolvehost := checkbox1.Checked;
    resolvemac:=checkbox2.Checked;

    application.ProcessMessages;

    if (resolvemac) then showmessage('Resolving MACs will also list hidden devices, this requires using ARP and only works on your local network.');
    octet1 := ExtractDelimited(1, edit1.Text, [#46]);
    octet2 := ExtractDelimited(2, edit1.Text, [#46]);


    iprev1 := ExtractDelimited(4, edit1.Text, [#46]) + '.' + ExtractDelimited(
      3, edit1.Text, [#46]) + '.' + ExtractDelimited(2, edit1.Text, [#46]) +
      '.' + ExtractDelimited(1, edit1.Text, [#46]);
    iprev2 := ExtractDelimited(4, edit2.Text, [#46]) + '.' + ExtractDelimited(
      3, edit2.Text, [#46]) + '.' + ExtractDelimited(2, edit2.Text, [#46]) +
      '.' + ExtractDelimited(1, edit2.Text, [#46]);
    ipindexstart := inet_addr(PChar(iprev1));
    ipindexend := inet_addr(PChar(iprev2));

    if (ipindexstart > ipindexend) then
    begin
      ShowMessage('Start must be less than End');
      exit;
    end;

    for j := 0 to 255 do
    begin
      my_array[j] := 0;
      application.ProcessMessages;
    end;



    for I := ipindexstart to ipindexend do
    begin
      if (stoppressed = 1) then
      begin
        edit3.Text := 'Stopped by user!';
        memo1.Lines.add('Stopped by user!');

        break;

      end;

      IPAddress.s_addr := i;

      s := HostAddrToStr(IPAddress);


      site := StrToInt(ExtractDelimited(3, s, [#46]));

      if (site <> oldsite) then
      begin
        memo1.Lines.add('');
        memo1.Lines.add('Pinging site : ' + s);
        memo1.Lines.add('');
        oldsite := site;

        memo1.Lines.add('IP' + #9 + 'Ping Reply' + #9 + 'Host Name'+#9+'MAC Address');

        application.ProcessMessages;
      end;

      hostname:='';
      macaddress:='';

      pingresult := pinghostfun(s);

      if   (resolvemac)  then macaddress:=getmacaddr(s,ErrCode);


      if ((pingresult = 1) or (trim(macaddress)<>'')) then
      begin
        if (resolvehost) then
          hostname := IPAddrToName(s);

      memo1.Lines.add(s + #9 + IntToStr(pingresult) + #9 + hostname +#9+macaddress);
      edit3.Text := s + #9 + IntToStr(pingresult) + #9 + hostname+#9+macaddress;

      application.ProcessMessages;
      my_array[site] := my_array[site] + 1;
      end;
    end;

    memo1.Lines.add('');
    memo1.Lines.add('Summary for ' + edit1.Text + ' to ' + edit2.Text +
      ' Timeout : ' + IntToStr(spinedit1.Value));
    memo1.Lines.add('');
    memo1.Lines.add('Site' + #9 + 'Used' + #9 + 'Free');
    for j := 0 to 255 do
    begin
      if my_array[j] > 0 then
      begin
        memo1.Lines.add(octet1 + '.' + octet2 + '.' + IntToStr(j) +
          '.0' + #9 + IntToStr(my_array[j]) + #9 + IntToStr(256 - my_array[j]));
        application.ProcessMessages;
      end;
    end;
    edit3.Text := 'Complete!';
  except
    on E: Exception do
      DumpExceptionCallStack(E);

  end;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  stoppressed := 1;
end;


function tform1.PingHostfun(const Host: string): integer;

begin
  Result := 0;



  with TPINGSend.Create do

    try
      Timeout := spinedit1.Value;
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

function tform1.GetIPAddress(hostname: string): string;
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

function TForm1.IPAddrToName(IPAddr: string): string;
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
 function TForm1.GetMacAddr(const IPAddress: string; var ErrCode : DWORD): string;
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
