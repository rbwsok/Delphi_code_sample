unit SharedMemoryAllocator;

interface

uses Generics.Collections, Generics.Defaults, System.SysUtils, System.Math,
  System.SyncObjs;

type
  TRMemChunk = class
  public
    ptr: PByte;
    Size: UInt64;
    constructor Create;
    destructor Destroy; override;
  end;

  // "управлятор" памятью File Mapping
  TRSharedMemoryAllocator = class
  private
    FFullPtr: PByte;
    FFullSize: UInt64;

    FBaseRecordsPtr: PByte;

    RecordsChunksCriticalSection: TCriticalSection;
    RecordsChunks: TObjectList<TRMemChunk>;

    BuffersChunksCriticalSection: TCriticalSection;
    BuffersChunks: TObjectList<TRMemChunk>;

    function FindFreeRecordsPointer(Size: UInt64): PByte;
    function FindFreeBuffersPointer(Size: UInt64): PByte;
  public
    constructor Create(Ptr: PByte; Size: UInt64);
    destructor Destroy; override;

    function AllocateRecord: PByte;
    procedure FreeRecord(var ptr: PByte);

    function AllocateBuffer(var NeedSize: UInt64): PByte;
    procedure FreeBuffer(var ptr: PByte);

    function TotalMemory: UInt64;
    function RecordsMemory: UInt64;
    function BuffersMemory: UInt64;

    property FullPtr: PByte read FFullPtr;
    property FullSize: UInt64 read FFullSize;
    property BaseRecordsPtr: PByte read FBaseRecordsPtr;
  end;

implementation

uses SharedConst;

{ TRSharedMemoryAllocator }

function TRSharedMemoryAllocator.AllocateBuffer(var NeedSize: UInt64): PByte;
var
  Chunk: TRMemChunk;
  ptr: PByte;
begin
  result := nil;

  if (NeedSize > 10 * 1024) or (NeedSize = 0) then
    NeedSize := 10 * 1024;

  BuffersChunksCriticalSection.Enter;

  if BuffersChunks.Count = 0 then
  begin
    Chunk := TRMemChunk.Create;
    Chunk.ptr := FullPtr + FFullSize - NeedSize;
    Chunk.Size := NeedSize;
    BuffersChunks.Add(Chunk);

    result := Chunk.ptr;
  end
  else
  begin
    ptr := FindFreeBuffersPointer(NeedSize);
    if ptr <> nil then
    begin
      Chunk := TRMemChunk.Create;
      Chunk.ptr := ptr;
      Chunk.Size := NeedSize;
      BuffersChunks.Add(Chunk);
      BuffersChunks.Sort(TComparer<TRMemChunk>.Construct
        (
          function (const q1, q2: TRMemChunk): Integer
          begin
            result := CompareValue(NativeInt(q1.ptr), NativeInt(q2.ptr));
          end
        )
      );
      result := Chunk.ptr;
    end;
  end;

  BuffersChunksCriticalSection.Leave;
end;

function TRSharedMemoryAllocator.AllocateRecord: PByte;
var
  Chunk: TRMemChunk;
  ptr: PByte;
begin
  result := nil;

  RecordsChunksCriticalSection.Enter;

  if RecordsChunks.Count = 0 then
  begin
    Chunk := TRMemChunk.Create;
    Chunk.ptr := FBaseRecordsPtr;
    Chunk.Size := sizeof(TRCommandRecord);
    RecordsChunks.Add(Chunk);

    result := Chunk.ptr;
  end
  else
  begin
    ptr := FindFreeRecordsPointer(sizeof(TRCommandRecord));
    if ptr <> nil then
    begin
      Chunk := TRMemChunk.Create;
      Chunk.ptr := ptr;
      Chunk.Size := sizeof(TRCommandRecord);
      RecordsChunks.Add(Chunk);
      RecordsChunks.Sort(TComparer<TRMemChunk>.Construct
        (
          function (const q1, q2: TRMemChunk): Integer
          begin
            result := CompareValue(NativeInt(q1.ptr), NativeInt(q2.ptr));
          end
        )
      );
      result := Chunk.ptr;
    end;
  end;

  RecordsChunksCriticalSection.Leave;
end;

function TRSharedMemoryAllocator.BuffersMemory: UInt64;
var
  chunk: TRMemChunk;
begin
  result := 0;
  for chunk in BuffersChunks do
  begin
    inc(result, chunk.Size);
  end;
end;

constructor TRSharedMemoryAllocator.Create(Ptr: PByte; Size: UInt64);
begin
  FFullPtr := Ptr;
  FFullSize := Size;

  FBaseRecordsPtr := FullPtr + sizeof(TRGeneralRecord);

  RecordsChunks := TObjectList<TRMemChunk>.Create;
  RecordsChunksCriticalSection := TCriticalSection.Create;

  BuffersChunks := TObjectList<TRMemChunk>.Create;
  BuffersChunksCriticalSection := TCriticalSection.Create;
end;

destructor TRSharedMemoryAllocator.Destroy;
begin
  FreeAndNil(RecordsChunks);
  FreeAndNil(RecordsChunksCriticalSection);
  FreeAndNil(BuffersChunks);
  FreeAndNil(BuffersChunksCriticalSection);
  inherited;
end;

function TRSharedMemoryAllocator.FindFreeBuffersPointer(Size: UInt64): PByte;
var
  chunk: TRMemChunk;
  ptr: PByte;
  i: Integer;
begin
  ptr := nil;
  for i := BuffersChunks.Count - 1 downto 0 do
  begin
    chunk := BuffersChunks[i];
    if ptr = nil then
    begin
      // проверка конца
      if chunk.ptr + chunk.Size < FFullPtr + FFullSize then
      begin
        if (FullPtr + FFullSize) - (chunk.ptr + chunk.Size) >= Size then
          exit(FullPtr + FFullSize - Size);
      end;

      ptr := chunk.ptr;
    end
    else
    if chunk.ptr + chunk.Size < ptr then
    begin
      if ptr - (chunk.ptr + chunk.Size) >= Size then
        exit(ptr - Size);
      ptr := chunk.ptr;
    end
    else
      ptr := chunk.ptr;
  end;

  result := ptr - Size;
end;

function TRSharedMemoryAllocator.FindFreeRecordsPointer(Size: UInt64): PByte;
var
  chunk: TRMemChunk;
  ptr: PByte;
begin
  ptr := nil;
  for chunk in RecordsChunks do
  begin
    if ptr = nil then
    begin
      // проверка начала
      if chunk.ptr > FBaseRecordsPtr then
      begin
        if chunk.ptr - FBaseRecordsPtr >= Size then
          exit(FBaseRecordsPtr);
      end;

      ptr := chunk.ptr + chunk.Size;
    end
    else
    if ptr < chunk.ptr then
    begin
      if chunk.ptr - ptr >= Size then
        exit(ptr);
      ptr := chunk.ptr + chunk.Size;
    end
    else
      ptr := chunk.ptr + chunk.Size;
  end;

  result := ptr;
end;

procedure TRSharedMemoryAllocator.FreeBuffer(var ptr: PByte);
var
  chunk: TRMemChunk;
begin
  BuffersChunksCriticalSection.Enter;

  try
    if ptr = nil then
      exit;

    for chunk in BuffersChunks do
    begin
      if chunk.ptr = ptr then
      begin
        BuffersChunks.Remove(chunk);
        ptr := nil;
        exit;
      end;
    end;

    ptr := nil;
  finally
    BuffersChunksCriticalSection.Leave;
  end;
end;

procedure TRSharedMemoryAllocator.FreeRecord(var ptr: PByte);
var
  chunk: TRMemChunk;
begin
  RecordsChunksCriticalSection.Enter;

  try
    if ptr = nil then
      exit;

    for chunk in RecordsChunks do
    begin
      if chunk.ptr = ptr then
      begin
        RecordsChunks.Remove(chunk);
        ptr := nil;
        exit;
      end;
    end;

    ptr := nil;
  finally
    RecordsChunksCriticalSection.Leave;
  end;
end;

function TRSharedMemoryAllocator.RecordsMemory: UInt64;
var
  chunk: TRMemChunk;
begin
  result := 0;
  for chunk in RecordsChunks do
  begin
    inc(result, chunk.Size);
  end;
end;

function TRSharedMemoryAllocator.TotalMemory: UInt64;
begin
  result := RecordsMemory + BuffersMemory;
end;

{ TRMemChunk }

constructor TRMemChunk.Create;
begin

end;

destructor TRMemChunk.Destroy;
begin

  inherited;
end;

end.
