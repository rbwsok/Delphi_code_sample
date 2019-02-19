program sharedclient;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  SharedMemoryClient in 'SharedMemoryClient.pas',
  SharedConst in 'SharedConst.pas',
  SharedMemoryProtocol in 'SharedMemoryProtocol.pas',
  xmloptions in 'xmloptions.pas',
  log in 'log.pas';

var
  smclient: TRSharedMemoryClient;
  res: Integer;

  NumRead: Cardinal;
  NumEvents: Cardinal;
  InputRec: TInputRecord;
  ConsoleHandle: THandle;

  i, j: Integer;
  streamfile: String;
  streamfiles: TStringList;

  ControlMutex: THandle;
begin
{$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}

  smclient := TRSharedMemoryClient.Create;

  try
    try
      // загрузка конфига
      ConsoleWrite('Load Config - ');
      if TRSharedMemoryClient.Options.LoadXML(IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'options.xml') = false then
      begin
        ConsoleWriteLn('false');
        ConsoleWriteLn('File abssent or corrupted');
      end
      else
        ConsoleWriteLn('ok');

      // подключение к серверу
      ConsoleWrite('Create Shared Memory Client - ');
      res := smclient.ConnectToSharedMemory(
          SharedConst.SERVER_NAME,              // имя сервера
          SharedConst.GLOBALRECORD_MUTEX_NAME   // имя mutex
      );
      if res <> 0 then
      begin
        ConsoleWriteLn('Error: ' + IntToStr(res) + ' ' + SysErrorMessage(res));
        ConsoleWriteLn;
        ConsoleWriteLn('Press "Enter" for quit');

        ReadLn;

        exit;
      end;
      ConsoleWriteLn('ok');

      streamfiles := TStringList.Create;

      // разбор комманодной строки, создание и запуск задач для передачи файлов
      if ParamCount > 0 then
      begin
        i := 1;
        j := 1;
        while i <= ParamCount do
        begin
          streamfile := TRSharedMemoryClient.Options.GetStreamFileName(StrToIntDef(ParamStr(i), 0));
          if (streamfile <> '') and (FileExists(streamfile) = true) then
          begin
            ConsoleWriteLn('Stream: ' + IntToStr(j) + ' ' + streamfile);
            streamfiles.Add(streamfile);

            smclient.StartStream; // запуск потока

            inc(j);
          end;
          inc(i);
        end;

        // запуск отправки файлов
        i := 0;
        while i < streamfiles.Count do
        begin
          smclient.Streams[i].SendFile(streamfiles[i]);
          inc(i);
        end;

        if streamfiles.Count > 0 then
        begin
          ConsoleHandle := GetStdHandle(STD_INPUT_HANDLE);
          while true do
          begin
            // проверка наличия работы сервера - по мутексу
            ControlMutex := OpenMutex(MUTEX_ALL_ACCESS, false, PWideChar(SharedConst.SERVERCONTROL_MUTEX_NAME));
            if ControlMutex = 0 then
            begin
              ConsoleWriteln('================================'#$0d#$0a +
                             'Server is destroyed'#$0d#$0a#$0d#$0a +
                             'Press "Enter" for Quit'#$0d#$0a +
                             '================================');

              ReadLn;
              break;
            end
            else
              CloseHandle(ControlMutex);

            GetNumberOfConsoleInputEvents(ConsoleHandle, NumEvents);
            if NumEvents > 0 then
            begin
              if (ReadConsoleInput(ConsoleHandle, InputRec, 1, NumRead) = true) and
                 (InputRec.EventType = KEY_EVENT) and
                 (InputRec.Event.KeyEvent.bKeyDown = false) then // keyup
              begin
                if InputRec.Event.KeyEvent.wVirtualKeyCode <> VK_RETURN then
                  break;
              end;
            end;
          end;
        end;
      end;

      if streamfiles.Count = 0 then
      begin
        ConsoleWriteln;
        ConsoleWriteln('Use command line option');
        ConsoleWriteln('sharedclient.exe [n1] [n2] [n3]...');
        ConsoleWriteln('  [n1]...[nx] - stream numbers from options.xml');
        ConsoleWriteln('example: sharedclient.exe 1 2 3 4 5');

        ConsoleWriteln;
        ConsoleWriteln('Press "Enter" for Quit');

        ReadLn;
      end;

      FreeAndNil(streamfiles);
    except
      on E: Exception do
        ConsoleWriteln(E.ClassName + ': ' + E.Message);
    end;

  finally
    ConsoleWriteLn('Destroy Shared Memory Client');
    FreeAndNil(smclient);
  end;
end.
