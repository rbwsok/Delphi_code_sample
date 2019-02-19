unit SharedMemoryClient;

interface

uses Winapi.Windows, System.Classes, Generics.Collections, System.SysUtils,
System.SyncObjs, xmloptions,

SharedMemoryProtocol, SharedConst;

type
  TRClientConnectMode = (
    cmNotConnected,
    cmConnected,
    cmError
  );

  TRSharedMemoryClient = class;

  // �����������
  TRSharedMemoryClientStream = class(TThread)
  private
    Client: TRSharedMemoryClient; // ������ �� ������

    ClientGUID: String;  // �������� guid
    ClientMutex: THandle;  // ���������� ������ � GUID ������

    CommandOffset: Cardinal; // �������� ������������ ������ shared memory �� ������ ����� ������

    FileTransfer: TRTransactionFileTransfer; // ��������� ��� �������� �����

    InputsCommandsQueueCriticalSection: TCriticalSection; // ������������� �������
    InputsCommandsQueue: array of TRCommandRecord; // ������� �������� ������ �� ������ �������

    function ConnectToServer: TRClientConnectMode;

    procedure SetGUID(const guid: String);

    function FileSizeFromName(name: String): UInt64;
  public
    Mode: TRClientConnectMode; // ����� (���������, �� ��������� � �.�.)

    procedure Execute; override;

    constructor Create(Client: TRSharedMemoryClient);
    destructor Destroy; override;

    procedure SendPing;
    function SendFile(const filename: String): Boolean;
  end;

  // ������
  TRSharedMemoryClient = class
  private
    FSMHandle: THandle; // ���������� shared memory
    FSMPointer: PByte; // ��������� �� shared memory

    FGeneralRecordMutex: THandle; // ������ ��� ������� � "������������" GUID

    FStreams: TObjectList<TRSharedMemoryClientStream>; // ������ ������
  public
    function ConnectToSharedMemory(const ServerName, MutexName: String): Cardinal;
    procedure DestroySharedMemory;

    procedure StartStream;

    constructor Create;
    destructor Destroy; override;

    property Streams: TObjectList<TRSharedMemoryClientStream> read FStreams;

    class var Options: TROptions;
  end;

implementation

uses log;

{ TRSharedMemoryClient }

function TRSharedMemoryClient.ConnectToSharedMemory(const ServerName, MutexName: String): Cardinal;
begin
  result := 0;

  FSMHandle := OpenFileMapping(
      FILE_MAP_ALL_ACCESS,  // ����� �������
      false,                // ������������
      PWideChar(ServerName) // ��� �������
  );
  if FSMHandle = 0 then
  begin
    FSMHandle := INVALID_HANDLE_VALUE;
    exit(GetLastError);
  end;

  FSMPointer := MapViewOfFile(
      FSMHandle,                        // ��������� file mapping
      FILE_MAP_READ or FILE_MAP_WRITE, // ������ � �����
      0,                               // � ������ ����� ������
      0,                               //
      0                                // ���������� ���� ���� ������
  );
  if FSMPointer = nil then
    exit(GetLastError);

  FGeneralRecordMutex := OpenMutex(MUTEX_ALL_ACCESS, false, PWideChar(MutexName));
  if FGeneralRecordMutex = 0 then
  begin
    FGeneralRecordMutex := INVALID_HANDLE_VALUE;
    exit(GetLastError);
  end;
end;

constructor TRSharedMemoryClient.Create;
begin
  FSMHandle := INVALID_HANDLE_VALUE;
  FSMPointer := nil;

  FGeneralRecordMutex := INVALID_HANDLE_VALUE;

  FStreams := TObjectList<TRSharedMemoryClientStream>.Create;

  Options := TROptions.Create;
end;

destructor TRSharedMemoryClient.Destroy;
var
  stream: TRSharedMemoryClientStream;
begin
  for stream in FStreams do
  begin
    stream.Terminate;
    if stream.Suspended = false then
      stream.WaitFor;
  end;
  FreeAndNil(FStreams);

  DestroySharedMemory;

  FreeAndNil(Options);

  inherited;
end;

procedure TRSharedMemoryClient.DestroySharedMemory;
begin
  if FSMPointer <> nil then
  begin
    UnmapViewOfFile(FSMPointer);
    FSMPointer := nil;
  end;

  if FSMHandle <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(FSMHandle);
    FSMHandle := INVALID_HANDLE_VALUE;
  end;

  if FGeneralRecordMutex <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(FGeneralRecordMutex);
    FGeneralRecordMutex := INVALID_HANDLE_VALUE;
  end;
end;

procedure TRSharedMemoryClient.StartStream;
var
  stream: TRSharedMemoryClientStream;
begin
  stream := TRSharedMemoryClientStream.Create(self);
  streams.Add(stream);
  stream.Start;
end;

{ TRSharedMemoryClientStream }

function TRSharedMemoryClientStream.ConnectToServer: TRClientConnectMode;
var
  res: Cardinal;
  guid: String;
begin
  result := cmNotConnected;
  res := WaitForSingleObject(client.FGeneralRecordMutex, 100);
  case res of
    WAIT_OBJECT_0:
      begin
        if pTRGeneralRecord(client.FSMPointer).Operation = 1 then
        begin
          // "��������" mutex

          guid := pTRGeneralRecord(client.FSMPointer).GUID;
          CommandOffset := pTRGeneralRecord(client.FSMPointer).CommandOffset;

          // ���������� ��������
          pTRGeneralRecord(client.FSMPointer).Operation := 0;
          // �� ���� - �������� GUID
          ZeroMemory(@pTRGeneralRecord(client.FSMPointer).GUID[0], sizeof(pTRGeneralRecord(client.FSMPointer).GUID));

          self.SetGUID(guid);

          ConsoleWriteLn('Get Client GUID: ' + self.ClientGUID);

          result := cmConnected;
        end
        else
          Sleep(10); // ����. � �� ��������� �����

        ReleaseMutex(client.FGeneralRecordMutex);

        exit;
      end;
    WAIT_ABANDONED: // ������ ������ �������
      begin
        ConsoleWriteLn('Mutex abaddoned');
        exit(cmError);
      end;
    WAIT_FAILED: // ��������� �����-�� �����
      begin
        ConsoleWriteLn('Mutex failed');
        exit(cmError);
      end;
  end;
end;

constructor TRSharedMemoryClientStream.Create(Client: TRSharedMemoryClient);
begin
  inherited Create(true);

  self.Client := Client;

  ClientMutex := INVALID_HANDLE_VALUE;

  FileTransfer := TRTransactionFileTransfer.Create;

  InputsCommandsQueueCriticalSection := TCriticalSection.Create;
end;

destructor TRSharedMemoryClientStream.Destroy;
begin
  if ClientMutex <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(ClientMutex);
    ClientMutex := INVALID_HANDLE_VALUE;
  end;

  FreeAndNil(FileTransfer);

  FreeAndNil(InputsCommandsQueueCriticalSection);

  inherited;
end;

procedure TRSharedMemoryClientStream.Execute;
var
  res: Cardinal;
  rec: pTRCommandRecord;
  name: String;
begin
  inherited;

  Mode := cmNotConnected;

  while true do
  begin
    if Terminated = true then
      break;

    // ����������� � �������
    if Mode = cmNotConnected then
    begin
      Mode := ConnectToServer;
      if Mode = cmError then
         break;
    end;

    // ������� � ��������
    if Mode = cmConnected then
    begin
      res := WaitForSingleObject(self.ClientMutex, 100);
      case res of
        WAIT_OBJECT_0:
          begin
            rec := pTRCommandRecord(client.FSMPointer + self.CommandOffset);
            TRSharedMemoryProtocol.ClientCommandProcessing(rec, self.FileTransfer);

            if rec.Command = cNone then
            begin
              // ����� ������ ������ ������ - �� �������� ���������� ������� ������ �� ������ �������
              InputsCommandsQueueCriticalSection.Enter;
              if High(InputsCommandsQueue) >= 0 then
              begin
                rec.Command := InputsCommandsQueue[High(InputsCommandsQueue)].Command;
                rec.Position := InputsCommandsQueue[High(InputsCommandsQueue)].Position;
                rec.Size := InputsCommandsQueue[High(InputsCommandsQueue)].Size;
                rec.DataOffset := InputsCommandsQueue[High(InputsCommandsQueue)].DataOffset;
                name := ExtractFileName(InputsCommandsQueue[High(InputsCommandsQueue)].FileName);
                ZeroMemory(@rec.FileName[0], sizeof(rec.FileName));
                CopyMemory(@rec.FileName[0], @name[1], Length(name) * StringElementSize(name));

                if rec.Command = cToServerSendFile then
                begin
                  FileTransfer.FileName := InputsCommandsQueue[High(InputsCommandsQueue)].FileName;
                  FileTransfer.CurrentPosition := 0;
                  FileTransfer.MemPtr := self.Client.FSMPointer;
                  try
                    FileTransfer.stream := TFileStream.Create(FileTransfer.FileName, fmOpenRead);
                  except
                    on E: Exception do
                    begin
                      ConsoleWriteln(E.ClassName + ': ' + E.Message);
                      rec.Command := cNone;
                    end;
                  end;
                end;

                // ������� ��������� ������
                SetLength(InputsCommandsQueue, High(InputsCommandsQueue));
              end
              else
                Sleep(10); // ����. � �� ��������� �����

              InputsCommandsQueueCriticalSection.Leave;
            end;

            ReleaseMutex(self.ClientMutex);
          end;
        WAIT_ABANDONED: // ������ ������ �������
          begin
            ConsoleWriteLn('Client Mutex abaddoned');
            Mode := cmError;
            exit;
          end;
        WAIT_FAILED: // ��������� �����-�� �����
          begin
            ConsoleWriteLn('Client Mutex failed');
            Mode := cmError;
            exit;
          end;
      end;
    end;
  end;

end;

function TRSharedMemoryClientStream.FileSizeFromName(name: String): UInt64;
var
  hhfile: HFILE;
  dwSizeHigh, dwSizeLow: Cardinal;
begin
  result := 0;

  if not FileExists(name) then
    exit;

  hhfile := CreateFile(pchar(name), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if hhfile = INVALID_HANDLE_VALUE then
    exit;

  dwSizeLow := GetFileSize(hhfile, @dwSizeHigh);

  result := (dwSizeHigh shl 32) or dwSizeLow;

  CloseHandle(hhfile);
end;

// �������� ������� ��� ����������� ��� �������� �����
function TRSharedMemoryClientStream.SendFile(const filename: String): Boolean;
var
  HighIndex: Integer;
  FileSize: UInt64;
  name: String;
begin
  result := false;

  if FileExists(filename) = false then
    exit;

  InputsCommandsQueueCriticalSection.Enter;

  try
    FileSize := FileSizeFromName(filename);
    if FileSize = 0 then
      exit;

    name := ExtractFileName(filename);
    if Length(name) = 0 then
      exit;

    // ����������� ������ � � ����� �������� ����������� ������� (�����������)
    HighIndex := High(InputsCommandsQueue) + 2;
    SetLength(InputsCommandsQueue, HighIndex);
    InputsCommandsQueue[HighIndex - 1].Command := cToServerSendFile;
    InputsCommandsQueue[HighIndex - 1].Size := FileSize;

    if Length(filename) > sizeof(InputsCommandsQueue[HighIndex - 1].FileName) then
    begin
      SetLength(InputsCommandsQueue, High(InputsCommandsQueue));
      exit;
    end;

    ZeroMemory(@InputsCommandsQueue[HighIndex - 1].FileName[0], sizeof(InputsCommandsQueue[HighIndex - 1].FileName));
    CopyMemory(@InputsCommandsQueue[HighIndex - 1].FileName[0], @filename[1], sizeof(InputsCommandsQueue[HighIndex - 1].FileName));

    result := true;
  finally
    InputsCommandsQueueCriticalSection.Leave;
  end;
end;

// �������� ������� Ping
procedure TRSharedMemoryClientStream.SendPing;
var
  HighIndex: Integer;
begin
  InputsCommandsQueueCriticalSection.Enter;

  try
    HighIndex := High(InputsCommandsQueue) + 2;
    SetLength(InputsCommandsQueue, HighIndex);
    InputsCommandsQueue[HighIndex - 1].Command := cToServerPing;
  finally
    InputsCommandsQueueCriticalSection.Leave;
  end;
end;

// ��������� GUID � �������� ������������ �������
procedure TRSharedMemoryClientStream.SetGUID(const guid: String);
begin
  ClientGUID := guid;
  ClientMutex := CreateMutex(nil, false, PWideChar(ClientGUID));
end;

end.
