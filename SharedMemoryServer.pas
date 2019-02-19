unit SharedMemoryServer;

interface

uses Winapi.Windows, System.SysUtils, Generics.Collections, System.Classes,
  System.SyncObjs, SharedMemoryAllocator, SharedConst, SharedMemoryProtocol,
  xmloptions;

type
  TRSharedMemoryServer = class;

  // ����� ��� ������������ ��������
  TRSharedMemoryConnectedClient = class(TThread)
  private
    Server: TRSharedMemoryServer;

    ClientGUID: String;
    ClientMutex: THandle;

    CommandRecordPtr: pTRCommandRecord; // ��������� �� ��������� ������� � ��������� ������

    FileTransfer: TRTransactionFileTransfer;
  public
    procedure Execute; override;

    procedure SetGUID(const guid: String);

    constructor Create(Server: TRSharedMemoryServer);
    destructor Destroy; override;
  end;

  // ����� "�������" GUID ��������
  TRGeneralRecordThread = class(TThread)
  private
    Server: TRSharedMemoryServer;
  public
    procedure Execute; override;

    constructor Create(Server: TRSharedMemoryServer);
    destructor Destroy; override;
  end;

  // ������
  TRSharedMemoryServer = class
  private
    SMHandle: THandle; // ���������� file mapping
    SMPointer: PByte;  // ��������� �� ������ file mapping

    Clients: TObjectList<TRSharedMemoryConnectedClient>; // ������ ��������

    GeneralRecordMutex: THandle; // mutex ��� "�������" GUID ��������
    GeneralRecordThread: TRGeneralRecordThread; // ����� ��� "�������" GUID ��������

    Allocator: TRSharedMemoryAllocator; // "��������" ������

    PrevClient: TRSharedMemoryConnectedClient; // ���������� ������ (�����)

    ControlMutex: THandle; // mutex ��� "�������" GUID ��������

    function GetGUID: String;
    procedure PutNewGeneralRecord;
  public
    function CreateSharedMemoryServer(const ServerName, MutexName: String; const Size: UInt64): Cardinal;
    procedure DestroySharedMemory;

    procedure Start;

    constructor Create;
    destructor Destroy; override;

    class var Options: TROptions;
  end;

implementation

uses log;

{ TRSharedMemoryServer }

constructor TRSharedMemoryServer.Create;
begin
  SMHandle := INVALID_HANDLE_VALUE;
  SMPointer := nil;
  GeneralRecordMutex := INVALID_HANDLE_VALUE;
  ControlMutex := INVALID_HANDLE_VALUE;

  Clients := TObjectList<TRSharedMemoryConnectedClient>.Create;

  GeneralRecordThread := TRGeneralRecordThread.Create(self);

  Allocator := nil;

  PrevClient := nil;

  Options := TROptions.Create;
end;

function TRSharedMemoryServer.CreateSharedMemoryServer(const ServerName, MutexName: String;
  const Size: UInt64): Cardinal;
begin
  SMHandle := CreateFileMapping(
      INVALID_HANDLE_VALUE, // ���������� �����
      nil,                  // ������������
      PAGE_READWRITE,       // ������
      Size shr 32,          // ������� ����� �������
      Size and $ffffffff,   // ������� ����� �������
      PWideChar(ServerName) // ��� �������
  );

  result := GetLastError;

  if SMHandle = 0 then
  begin
    SMHandle := INVALID_HANDLE_VALUE;
    exit;
  end;

  // ServerHandle <> 0 � GetLastError <> 0 - ���� ���������� ������ ��� ������
  // ������� ��� �������
  if result <> 0 then
    exit;

  SMPointer := MapViewOfFile(
      SMHandle,                        // ��������� file mapping
      FILE_MAP_READ or FILE_MAP_WRITE, // ������ � �����
      0,                               // � ������ ����� ������
      0,                               //
      0                                // ���������� ���� ���� ������
  );

  if SMPointer = nil then
    exit(GetLastError);

  GeneralRecordMutex := CreateMutex(nil, false, PWideChar(MutexName));

  result := GetLastError;

  if GeneralRecordMutex = 0 then
  begin
    GeneralRecordMutex := INVALID_HANDLE_VALUE;
    exit;
  end;

  // SMGeneralRecordMutex <> 0 � GetLastError <> 0 - ���� ���������� ������ ��� ������
  // ������� ��� �������
  if result <> 0 then
    exit;

  Allocator := TRSharedMemoryAllocator.Create(SMPointer, Size);

  ControlMutex := CreateMutex(nil, false, PWideChar(SERVERCONTROL_MUTEX_NAME));
end;

destructor TRSharedMemoryServer.Destroy;
var
  client: TRSharedMemoryConnectedClient;
begin
  GeneralRecordThread.Terminate;
  if GeneralRecordThread.Suspended = false then
    GeneralRecordThread.WaitFor;

  DestroySharedMemory;

  for client in Clients do
  begin
    client.Terminate;
    if client.Suspended = false then
      client.WaitFor;
  end;

  FreeAndNil(Clients);

  FreeAndNil(Allocator);

  FreeAndNil(Options);

  inherited;
end;

procedure TRSharedMemoryServer.DestroySharedMemory;
begin
  if SMPointer <> nil then
  begin
    UnmapViewOfFile(SMPointer);
    SMPointer := nil;
  end;

  if SMHandle <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(SMHandle);
    SMHandle := INVALID_HANDLE_VALUE;
  end;

  if GeneralRecordMutex <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(GeneralRecordMutex);
    GeneralRecordMutex := INVALID_HANDLE_VALUE;
  end;

  if ControlMutex <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(ControlMutex);
    GeneralRecordMutex := ControlMutex;
  end;
end;

function TRSharedMemoryServer.GetGUID: String;
var
  guid: System.TGUID;
begin
  CreateGUID(guid);
  result := GUIDToString(guid);
end;

// ��������
procedure TRSharedMemoryServer.PutNewGeneralRecord;
var
  str: String;
  Client: TRSharedMemoryConnectedClient;
begin
  if PrevClient <> nil then
    PrevClient.Start;

  str := GetGUID;
  Client := TRSharedMemoryConnectedClient.Create(self);
  Clients.Add(Client);
  Client.SetGUID(str);

  pTRGeneralRecord(SMPointer).Operation := 1; // ������� ����������� GUID
  pTRGeneralRecord(SMPointer).CommandOffset := PByte(Client.CommandRecordPtr) - SMPointer; // �������� �� ������ ������
  CopyMemory(@pTRGeneralRecord(SMPointer).GUID, @str[1], sizeof(pTRGeneralRecord(SMPointer).GUID)); // GUID

  PrevClient := Client;

  ConsoleWriteLn('New GUID: ' + str);
end;

procedure TRSharedMemoryServer.Start;
begin
  PutNewGeneralRecord;
  GeneralRecordThread.Start;
end;

{ TRSharedMemoryConnectedClient }

constructor TRSharedMemoryConnectedClient.Create(Server: TRSharedMemoryServer);
begin
  inherited Create(true);

  self.Server := Server;

  ClientMutex := INVALID_HANDLE_VALUE;

  FileTransfer := TRTransactionFileTransfer.Create;
  FileTransfer.Allocator := Server.Allocator;
  FileTransfer.OutputPath := TRSharedMemoryServer.Options.OutputServerPath;
end;

destructor TRSharedMemoryConnectedClient.Destroy;
begin
  if ClientMutex <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(ClientMutex);
    ClientMutex := INVALID_HANDLE_VALUE;
  end;

  FreeAndNil(FileTransfer);

  inherited;
end;

procedure TRSharedMemoryConnectedClient.Execute;
var
  res: Cardinal;
begin
  inherited;

  while true do
  begin
    if Terminated = true then
      break;

    res := WaitForSingleObject(self.ClientMutex, 100);
    case res of
      WAIT_OBJECT_0:
        begin
          if CommandRecordPtr.Command <> cNone then
            TRSharedMemoryProtocol.ServerCommandProcessing(CommandRecordPtr, self.FileTransfer)
          else
            Sleep(10); // ����. � �� ��������� �����

          ReleaseMutex(self.ClientMutex);
        end;
      WAIT_ABANDONED,
      WAIT_FAILED: // ��������� �����-�� �����
        break;
    end;
  end;

end;

procedure TRSharedMemoryConnectedClient.SetGUID(const guid: String);
begin
  ClientGUID := guid;

  FileTransfer.ClientGUID := self.ClientGUID;

  ClientMutex := CreateMutex(nil, false, PWideChar(ClientGUID));

  CommandRecordPtr := pTRCommandRecord(server.Allocator.AllocateRecord);
  if CommandRecordPtr <> nil then
    CommandRecordPtr.Command := cNone;
end;

{ TRGlobalRecordThread }

constructor TRGeneralRecordThread.Create(Server: TRSharedMemoryServer);
begin
  inherited Create(true);

  self.Server := Server;
end;

destructor TRGeneralRecordThread.Destroy;
begin

  inherited;
end;

procedure TRGeneralRecordThread.Execute;
var
  res: Cardinal;
begin
  inherited;

  while true do
  begin
    if Terminated = true then
      break;

    res := WaitForSingleObject(Server.GeneralRecordMutex, 100);
    case res of
      WAIT_OBJECT_0:
        begin
          if pTRGeneralRecord(server.SMPointer).Operation = 0 then
          begin
            // ������ "������" mutex
            // ������� ����� ����
            server.PutNewGeneralRecord;
          end
          else
            Sleep(10); // ����. � �� ��������� �����
          ReleaseMutex(Server.GeneralRecordMutex);
        end;
      WAIT_ABANDONED,
      WAIT_FAILED: // ��������� �����-�� �����
        break;
    end;
  end;
end;

end.
