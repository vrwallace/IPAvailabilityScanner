program project1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, Unit1, unit2, unit3, unit4,SysUtils
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
  Application.CreateForm(Tsplashform, splashform);
  try
    SplashForm.Show;
    SplashForm.Update; // Make sure splash screen is painted immediately
    // Perform any initializations here...
    Sleep(10000); // Display splash for a few seconds
  finally
    SplashForm.Free;
  end;
  Application.Run;
end.

