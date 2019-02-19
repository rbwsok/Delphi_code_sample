unit SharedMemoryProtocol;

interface

uses Winapi.Windows, System.SysUtils, System.Classes,

SharedConst, SharedMemoryAllocator;

type
  // передача файлов (учет состояний и т.д.)
  TRTransactionFileTransfer = class
  public
    FileName: String;         // имя файла
    CurrentPosition: UInt64;  // позиция в файле источнике

    stream: TFileStream;      // входной или входной файловый поток

    FileSize: UInt64;         // размер файла

    MemPtr: PByte;            // указатель на блок памяти для копирования файла (в shared области)
    MemSize: UInt64;          // размер блока памяти для копирования файла (в shared области)

    Allocator: TRSharedMemoryAllocator; // аллокатор в shared области

    OutputPath: String;

    ClientGUID: String;

    constructor Create;
    destructor Destroy; override;
  end;

  // описание списка callback'ов
  TRCommandCallback = procedure (rec: pTRCommandRecord; ft: TRTransactionFileTransfer) of object;

  TRCallbacksRec = record
    CommandName: String;           // имя
    Command: TRCommandCode;        // тип
    Callback: TRCommandCallback;   // callback
  end;

  TRSharedMemoryProtocol = class
  public
    class procedure ServerCommandProcessing(rec: pTRCommandRecord; ft: TRTransactionFileTransfer);
    class procedure ClientCommandProcessing(rec: pTRCommandRecord; ft: TRTransactionFileTransfer);

    class procedure ToServerPingCallback(rec: pTRCommandRecord; ft: TRTransactionFileTransfer);
    class procedure FromServerPongCallback(rec: pTRCommandRecord; ft: TRTransactionFileTransfer);
    class procedure ToClientPingCallback(rec: pTRCommandRecord; ft: TRTransactionFileTransfer);
    class procedure FromClientPongCallback(rec: pTRCommandRecord; ft: TRTransactionFileTransfer);

    class procedure ToServerSendFileCallback(rec: pTRCommandRecord; ft: TRTransactionFileTransfer);
    class procedure ToClientGetPartFileCallback(rec: pTRCommandRecord; ft: TRTransactionFileTransfer);
    class procedure ToServerPartFileCallback(rec: pTRCommandRecord; ft: TRTransactionFileTransfer);
    class procedure ToClientEndFileCallback(rec: pTRCommandRecord; ft: TRTransactionFileTransfer);
  end;

var
  TRServerCallbacks: array [0..3] of TRCallbacksRec = (
    (Command: cToServerPing;     Callback: TRSharedMemoryProtocol.ToServerPingCallback),
    (Command: cFromClientPong;   Callback: TRSharedMemoryProtocol.FromClientPongCallback),
    (Command: cToServerSendFile; Callback: TRSharedMemoryProtocol.ToServerSendFileCallback),
    (Command: cToServerPartFile; Callback: TRSharedMemoryProtocol.ToServerPartFileCallback)
  );

  TRClientCallbacks: array [0..3] of TRCallbacksRec = (
    (Command: cFromServerPong;        Callback: TRSharedMemoryProtocol.FromServerPongCallback),
    (Command: cToClientPing;          Callback: TRSharedMemoryProtocol.ToClientPingCallback),
    (Command: cToClientGetPartFile;   Callback: TRSharedMemoryProtocol.ToClientGetPartFileCallback),
    (Command: cToClientEndFile;       Callback: TRSharedMemoryProtocol.ToClientEndFileCallback)
  );

implementation

uses log;

{ TRSharedMemoryProtocol }

class procedure TRSharedMemoryProtocol.ClientCommandProcessing(rec: pTRCommandRecord; ft: TRTransactionFileTransfer);
var
  i: Integer;
begin
  for i := Low(TRClientCallbacks) to High(TRClientCallbacks) do
  begin
    if rec.Command = TRClientCallbacks[i].Command then
    begin
      TRClientCallbacks[i].Callback(rec, ft);
      break;
    end;
  end;
end;

class procedure TRSharedMemoryProtocol.ServerCommandProcessing(rec: pTRCommandRecord; ft: TRTransactionFileTransfer);
var
  i: Integer;
begin
  for i := Low(TRServerCallbacks) to High(TRServerCallbacks) do
  begin
    if rec.Command = TRServerCallbacks[i].Command then
    begin
      TRServerCallbacks[i].Callback(rec, ft);
      break;
    end;
  end;
end;

class procedure TRSharedMemoryProtocol.FromClientPongCallback(
  rec: pTRCommandRecord; ft: TRTransactionFileTransfer);
begin
  ConsoleWriteLn('Recieved "From Client Pong"');
  rec.Command := cNone;
end;

class procedure TRSharedMemoryProtocol.FromServerPongCallback(
  rec: pTRCommandRecord; ft: TRTransactionFileTransfer);
begin
  ConsoleWriteLn('Recieved "From Server Pong"');
  rec.Command := cNone;
end;

class procedure TRSharedMemoryProtocol.ToClientEndFileCallback(
  rec: pTRCommandRecord; ft: TRTransactionFileTransfer);
begin
  ConsoleWriteLn('Recieved "To Client End File"');

  // закончили передавать файл - освобождаем ресурсы
  FreeAndNil(ft.stream);

  rec.Command := cNone;
end;

class procedure TRSharedMemoryProtocol.ToClientGetPartFileCallback(
  rec: pTRCommandRecord; ft: TRTransactionFileTransfer);
var
  readlength: Integer;
begin
  ConsoleWriteLn('Recieved "To Client Get Part File"');

  if ft.stream = nil then
  begin
    rec.Command := cNone;
    exit;
  end;

  try
    ft.stream.Seek(rec.Position, soBeginning);
    readlength := ft.stream.ReadData(ft.MemPtr + rec.DataOffset, rec.Size);
  except
    on E: Exception do
    begin
      ConsoleWriteln(E.ClassName + ': ' + E.Message);

      FreeAndNil(ft.stream);

      rec.Command := cNone;
      exit;
    end;
  end;

  ConsoleWriteLn('Read: ' + IntToStr(readlength));

  rec.Command := cToServerPartFile;
  rec.Size := readlength;
end;

class procedure TRSharedMemoryProtocol.ToClientPingCallback(
  rec: pTRCommandRecord; ft: TRTransactionFileTransfer);
begin
  ConsoleWriteLn('Recieved "To Client Ping"');
  rec.Command := cFromClientPong;
end;

class procedure TRSharedMemoryProtocol.ToServerPartFileCallback(
  rec: pTRCommandRecord; ft: TRTransactionFileTransfer);
begin
  ConsoleWriteLn('Recieved "To Server Part File" ' + ft.ClientGUID);

  try
    ft.stream.WriteData(ft.Allocator.FullPtr + rec.DataOffset, rec.Size);
  except
    on E: Exception do
    begin
      ConsoleWriteln(E.ClassName + ': ' + E.Message);

      rec.Command := cToClientEndFile;
      FreeAndNil(ft.stream);
      ft.Allocator.FreeBuffer(ft.MemPtr);
      exit;
    end;
  end;

  inc(ft.CurrentPosition, rec.Size);

  if ft.CurrentPosition >= ft.FileSize then
  begin
    // закончили принимать файл
    rec.Command := cToClientEndFile;

    // освобождаем ресурсы
    FreeAndNil(ft.stream);
    ft.Allocator.FreeBuffer(ft.MemPtr);
    ft.MemSize := 0;
    ft.FileSize := 0;
    ft.CurrentPosition := 0;
  end
  else
  begin
    // запрашиваекм следующую часть
    rec.Command := cToClientGetPartFile;
    rec.Position := ft.CurrentPosition;
    rec.Size := ft.MemSize;
    rec.DataOffset := ft.MemPtr - ft.Allocator.FullPtr;
  end;
end;

class procedure TRSharedMemoryProtocol.ToServerPingCallback(
  rec: pTRCommandRecord; ft: TRTransactionFileTransfer);
begin
  ConsoleWriteLn('Recieved "To Server Ping" ' + ft.ClientGUID);
  rec.Command := cFromServerPong;
end;

class procedure TRSharedMemoryProtocol.ToServerSendFileCallback(
  rec: pTRCommandRecord; ft: TRTransactionFileTransfer);
var
  name: String;
begin
  ConsoleWriteLn('Recieved "To Server Send File" ' + ft.ClientGUID);

  name := rec.FileName;

  ConsoleWriteLn('FileName: ' + name + #$0d#$0a + 'Size: ' + IntToStr(rec.Size));

  if ft.stream <> nil then
  begin
    ConsoleWriteLn('Other Operation In Progress!');
    rec.Command := cNone;
    exit;
  end;

  try
    DeleteFile(ft.OutputPath + name);
    ft.stream := TFileStream.Create(ft.OutputPath + name, fmCreate);
  except
    on E: Exception do
    begin
      ConsoleWriteln(E.ClassName + ': ' + E.Message);

      rec.Command := cToClientEndFile;
      FreeAndNil(ft.stream);
      exit;
    end;
  end;

  ft.MemSize := 0;
  ft.MemPtr := ft.Allocator.AllocateBuffer(ft.MemSize);
  if ft.MemPtr = nil then
  begin
    ConsoleWriteln('Out of memory');

    rec.Command := cToClientEndFile;
    FreeAndNil(ft.stream);
    exit;
  end;

  ft.FileSize := rec.Size;

  rec.Command := cToClientGetPartFile;
  rec.Position := 0;
  rec.Size := ft.MemSize;
  rec.DataOffset := ft.MemPtr - ft.Allocator.FullPtr;
end;

{ TRTransactionFileTransfer }

constructor TRTransactionFileTransfer.Create;
begin
  stream := nil;

  MemPtr := nil;
  MemSize := 0;

  Allocator := nil;

  FileSize := 0;
end;

destructor TRTransactionFileTransfer.Destroy;
begin
  FreeAndNil(stream);
  inherited;
end;

end.
