program demo;

uses
  Forms,
  udemo in 'udemo.pas' {Form1},
  injection in 'injection.pas',
  ntdll in 'ntdll.pas',
  uDGProcessList in 'uDGProcessList.pas';


{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
