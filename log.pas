unit log;

interface

uses System.SysUtils, System.SyncObjs;

procedure ConsoleWrite(value: String);
procedure ConsoleWriteLn(value: String = '');

var
  logcliticalsection: TCriticalSection;

implementation

procedure ConsoleWrite(value: String);
begin
  logcliticalsection.Enter;
  Write(value);
  logcliticalsection.Leave;
end;

procedure ConsoleWriteLn(value: String);
begin
  logcliticalsection.Enter;
  WriteLn(value);
  logcliticalsection.Leave;
end;

initialization
  logcliticalsection := TCriticalSection.Create;
finalization
  FreeAndNil(logcliticalsection);

end.
