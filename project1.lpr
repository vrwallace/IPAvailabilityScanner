program project1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, Unit1, unit2, unit3
  { you can add units after this };

{$R *.res}

begin
  Application.Scaled:=True;
  Application.Title:='IP Availability Scanner';
  RequireDerivedFormResource:=True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TFormScanResults, FormScanResults);
  Application.CreateForm(Tpingtrace, pingtrace);
  Application.Run;
end.

