unit SharedMemoryServer;

interface

uses Winapi.Windows, System.SysUtils, Generics.Collections, System.Classes,
  System.SyncObjs, SharedMemoryAllocator, SharedConst, SharedMemoryProtocol,
  xmloptions;

type
  TRSharedMemoryServer = class;

  // поток для обстуживания клиентов
  TRSharedMemoryConnectedClient = class(TThread)
  private
    Server: TRSharedMemoryServer;

    ClientGUID: String;
    ClientMutex: THandle;

    CommandRecordPtr: pTRCommandRecord; // указатель на системную область с описанием команд

    FileTransfer: TRTransactionFileTransfer;
  public
    procedure Execute; override;

    procedure SetGUID(const guid: String);

    constructor Create(Server: TRSharedMemoryServer);
    destructor Destroy; override;
  end;

  // поток "раздачи" GUID клиентам
  TRGeneralRecordThread = class(TThread)
  private
    Server: TRSharedMemoryServer;
  public
    procedure Execute; override;

    constructor Create(Server: TRSharedMemoryServer);
    destructor Destroy; override;
  end;

  // сервер
  TRSharedMemoryServer = class
  private
    SMHandle: THandle; // дескриптор file mapping
    SMPointer: PByte;  // указатель на память file mapping

    Clients: TObjectList<TRSharedMemoryConnectedClient>; // список клиентов

    GeneralRecordMutex: THandle; // mutex для "раздачи" GUID клиентам
    GeneralRecordThread: TRGeneralRecordThread; // поток для "раздачи" GUID клиентам

    Allocator: TRSharedMemoryAllocator; // "менеджер" памяти

    PrevClient: TRSharedMemoryConnectedClient; // предыдущий клиент (поток)

    ControlMutex: THandle; // mutex для "раздачи" GUID клиентам

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
      INVALID_HANDLE_VALUE, // дескриптор файла
      nil,                  // безопасность
      PAGE_READWRITE,       // доступ
      Size shr 32,          // старшее слово размера
      Size and $ffffffff,   // младшее слово размера
      PWideChar(ServerName) // имя объекта
  );

  result := GetLastError;

  if SMHandle = 0 then
  begin
    SMHandle := INVALID_HANDLE_VALUE;
    exit;
  end;

  // ServerHandle <> 0 и GetLastError <> 0 - если именованый объект уже создан
  // считаем это ошибкой
  if result <> 0 then
    exit;

  SMPointer := MapViewOfFile(
      SMHandle,                        // дискритор file mapping
      FILE_MAP_READ or FILE_MAP_WRITE, // читаем и пишем
      0,                               // с начала блока памяти
      0,                               //
      0                                // отображаем весь блок памяти
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

  // SMGeneralRecordMutex <> 0 и GetLastError <> 0 - если именованый объект уже создан
  // считаем это ошибкой
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

// создание
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

  pTRGeneralRecord(SMPointer).Operation := 1; // признак незанятости GUID
  pTRGeneralRecord(SMPointer).CommandOffset := PByte(Client.CommandRecordPtr) - SMPointer; // смещение до данных записи
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
            Sleep(10); // спим. а то процессор греем

          ReleaseMutex(self.ClientMutex);
        end;
      WAIT_ABANDONED,
      WAIT_FAILED: // произошла какая-то херня
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
            // клиент "забрал" mutex
            // генерим новую инфу
            server.PutNewGeneralRecord;
          end
          else
            Sleep(10); // спим. а то процессор греем
          ReleaseMutex(Server.GeneralRecordMutex);
        end;
      WAIT_ABANDONED,
      WAIT_FAILED: // произошла какая-то херня
        break;
    end;
  end;
end;

end.
