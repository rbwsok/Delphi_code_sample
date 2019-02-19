program test;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  log in 'log.pas',
  SharedConst in 'SharedConst.pas',
  SharedMemoryAllocator in 'SharedMemoryAllocator.pas',
  SharedMemoryClient in 'SharedMemoryClient.pas',
  SharedMemoryProtocol in 'SharedMemoryProtocol.pas',
  SharedMemoryServer in 'SharedMemoryServer.pas',
  TestUtil in 'TestUtil.pas',
  xmloptions in 'xmloptions.pas';

const
  ALLOCATE_SIZE: UInt64 = 256 * 1024;

  BUFFER_ALLOCATE_SIZE: UInt64 = 8 * 1024;

procedure CheckRecords(Allocator: TRSharedMemoryAllocator);
var
  p1, p2, p3, p4, p5: PByte;
begin
  // записи
  p1 := Allocator.AllocateRecord;
  TRTest.CheckEqual('Allocate Record 1', Allocator.RecordsMemory, sizeof(TRCommandRecord));
  p2 := Allocator.AllocateRecord;
  TRTest.CheckEqual('Allocate Record 2', Allocator.RecordsMemory, sizeof(TRCommandRecord) * 2);
  p3 := Allocator.AllocateRecord;
  TRTest.CheckEqual('Allocate Record 3', Allocator.RecordsMemory, sizeof(TRCommandRecord) * 3);

  TRTest.CheckGreater('Records Pointer Position 1', p2, p1);
  TRTest.CheckGreater('RecordsPointer Position 2', p3, p2);

  Allocator.FreeRecord(p2);
  TRTest.CheckEqual('Free Record 1', Allocator.RecordsMemory, sizeof(TRCommandRecord) * 2);

  p4 := Allocator.AllocateRecord;
  TRTest.CheckEqual('Allocate Record 4', Allocator.RecordsMemory, sizeof(TRCommandRecord) * 3);

  TRTest.CheckGreater('Records Pointer Position 3', p4, p1);
  TRTest.CheckGreater('Records Pointer Position 4', p3, p4);

  Allocator.FreeRecord(p1);
  TRTest.CheckEqual('Free Record 2', Allocator.RecordsMemory, sizeof(TRCommandRecord) * 2);

  p5 := Allocator.AllocateRecord;
  TRTest.CheckEqual('Allocate Record 5', Allocator.RecordsMemory, sizeof(TRCommandRecord) * 3);
  TRTest.CheckGreater('Records Pointer Position 5', p4, p5);
  TRTest.CheckEqual('Records Pointer Position 6', p5, Allocator.BaseRecordsPtr);
end;

procedure CheckBuffers(Allocator: TRSharedMemoryAllocator);
var
  p6, p7, p8, p9, p10: PByte;
  size1: UInt64;
  pn: PByte;
begin
  // буферы
  size1 := BUFFER_ALLOCATE_SIZE;
  p6 := Allocator.AllocateBuffer(size1);
  TRTest.CheckEqual('Allocate Buffer 1', Allocator.BuffersMemory, BUFFER_ALLOCATE_SIZE);
  p7 := Allocator.AllocateBuffer(size1);
  TRTest.CheckEqual('Allocate Buffer 2', Allocator.BuffersMemory, BUFFER_ALLOCATE_SIZE * 2);
  p8 := Allocator.AllocateBuffer(size1);
  TRTest.CheckEqual('Allocate Buffer 3', Allocator.BuffersMemory, BUFFER_ALLOCATE_SIZE * 3);

  TRTest.CheckGreater('Buffers Pointer Position 1', p6, p7);
  TRTest.CheckGreater('Buffers Pointer Position 2', p7, p8);

  Allocator.FreeBuffer(p7);
  TRTest.CheckEqual('Free Buffer 1', Allocator.BuffersMemory, BUFFER_ALLOCATE_SIZE * 2);

  p9 := Allocator.AllocateBuffer(size1);
  TRTest.CheckEqual('Allocate Buffer 4', Allocator.BuffersMemory, BUFFER_ALLOCATE_SIZE * 3);

  TRTest.CheckGreater('Buffers Pointer Position 1', p6, p9);
  TRTest.CheckGreater('Buffers Pointer Position 2', p9, p8);

  Allocator.FreeBuffer(p6);
  TRTest.CheckEqual('Free Buffer 2', Allocator.BuffersMemory, BUFFER_ALLOCATE_SIZE * 2);

  p10 := Allocator.AllocateBuffer(size1);
  TRTest.CheckEqual('Allocate Buffer 5', Allocator.BuffersMemory, BUFFER_ALLOCATE_SIZE * 3);
  TRTest.CheckGreater('Buffers Pointer Position 5', p10, p9);
  TRTest.CheckEqual('Buffers Pointer Position 6', p10, Allocator.FullPtr + Allocator.FullSize - size1);

  size1 := ALLOCATE_SIZE;
  pn := Allocator.AllocateBuffer(size1);
  TRTest.CheckNotEqual('Buffers Pointer Position 7', pn, nil);
  TRTest.CheckNotEqual('Size Buffer', size1, ALLOCATE_SIZE);
end;

procedure CheckClientServer(server: TRSharedMemoryServer; client: TRSharedMemoryClient);
var
  res: Cardinal;
begin
  res := client.ConnectToSharedMemory(
       SharedConst.SERVER_NAME,
       SharedConst.GLOBALRECORD_MUTEX_NAME
  );

  TRTest.CheckNotEqual('Create Client 1', res, 0);

  res := server.CreateSharedMemoryServer(
      SharedConst.SERVER_NAME,
      SharedConst.GLOBALRECORD_MUTEX_NAME,
      SharedConst.SERVER_MEM_SIZE
  );

  TRTest.CheckEqual('Create Server 1', res, 0);

  res := server.CreateSharedMemoryServer(
      SharedConst.SERVER_NAME,
      SharedConst.GLOBALRECORD_MUTEX_NAME,
      SharedConst.SERVER_MEM_SIZE
  );

  TRTest.CheckNotEqual('Create Server 2', res, 0);

  res := client.ConnectToSharedMemory(
       SharedConst.SERVER_NAME,
       SharedConst.GLOBALRECORD_MUTEX_NAME
  );

  TRTest.CheckEqual('Create Client 2', res, 0);
end;

var
  ptr: PByte;
  Allocator: TRSharedMemoryAllocator;
  server: TRSharedMemoryServer;
  client: TRSharedMemoryClient;

begin
  try
    TRTest.Init;

    // тесты аллокатора - выделение, освобождение, взаимное расположение адресов
    // граничные позиции и т.д.

    GetMem(ptr, ALLOCATE_SIZE);
    Allocator := TRSharedMemoryAllocator.Create(ptr, ALLOCATE_SIZE);

    TRTest.Category('Allocator');
    CheckRecords(Allocator);
    CheckBuffers(Allocator);

    FreeAndNil(Allocator);
    FreeMem(ptr);

    // сервер и клиент
    server := TRSharedMemoryServer.Create;
    client := TRSharedMemoryClient.Create;

    TRTest.Category('Server and Client');
    CheckClientServer(server, client);

    FreeAndNil(server);
    FreeAndNil(client);

    TRTest.ResultTest;

    ReadLn;

    { TODO -oUser -cConsole Main : Insert code here }
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
