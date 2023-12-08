unit Unit3;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls;

type

  { Tpingtrace }

  Tpingtrace = class(TForm)
    Memo1: TMemo;
    procedure FormCreate(Sender: TObject);
  private

  public

  end;

var
  pingtrace: Tpingtrace;

implementation

{$R *.lfm}

{ Tpingtrace }

procedure Tpingtrace.FormCreate(Sender: TObject);

var
  ScreenWidth, ScreenHeight: Integer;
  FormWidth, FormHeight: Integer;

begin
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


end.

