program sharedserver;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  SharedMemoryServer in 'SharedMemoryServer.pas',
  SharedConst in 'SharedConst.pas',
  SharedMemoryAllocator in 'SharedMemoryAllocator.pas',
  SharedMemoryProtocol in 'SharedMemoryProtocol.pas',
  xmloptions in 'xmloptions.pas',
  log in 'log.pas';

var
  smserver: TRSharedMemoryServer;
  res: Integer;

begin
{$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}

  smserver := TRSharedMemoryServer.Create;

  try
    try
      ConsoleWrite('Load Config - ');
      if TRSharedMemoryServer.Options.LoadXML(IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'options.xml') = false then
      begin
        ConsoleWriteLn('false');
        ConsoleWriteLn('File abssent or corrupted');
      end
      else
        ConsoleWriteLn('ok');
      ConsoleWriteLn('output directory: ' + TRSharedMemoryServer.Options.OutputServerPath);

      ConsoleWrite('Create Shared Memory Server - ');
      res := smserver.CreateSharedMemoryServer(
          SharedConst.SERVER_NAME,              // имя сервера
          SharedConst.GLOBALRECORD_MUTEX_NAME,  // имя mutex
          SharedConst.SERVER_MEM_SIZE           // размер выделяемой памяти
      );
      if res <> 0 then
      begin
        ConsoleWriteLn('Error: ' + IntToStr(res) + ' ' + SysErrorMessage(res));
        exit;
      end;
      ConsoleWriteLn('ok');

      ConsoleWriteLn('Shared Memory Server - Start');
      ConsoleWriteLn;
      ConsoleWriteLn('Press "Enter" for quit');

      smserver.Start;

    except
      on E: Exception do
        ConsoleWriteln(E.ClassName + ': ' + E.Message);
    end;

  finally
    ReadLn;

    ConsoleWriteLn('Destroy Shared Memory Server');
    FreeAndNil(smserver);
  end;
end.
