unit SharedConst;

interface

  //
  // распределение памяти

  // с начала памяти
  // +0                       sizeof(TRGeneralRecord)      структура для раздачи GUID (в единственном экземпляре)
  // sizeof(TRGeneralRecord)  n * sizeof(TRCommandRecord)  список структур для общения с клиентами

  // с конца памяти - блоки (окна) для передачи файлов

const
  // имя сервера
  SERVER_NAME: String = '{95FC2447-9ADA-4931-A393-477A48400336}';
  // размер памяти для расшаривания
  SERVER_MEM_SIZE: UInt64 = 256 * 1024;
  // имя mutex для раздачи GUID
  GLOBALRECORD_MUTEX_NAME: String = '{718F3915-E128-4032-852F-AC0B22536351}';
  // имя mutex для контроля сервера
  SERVERCONTROL_MUTEX_NAME: String = '{F57A659E-F930-4FDC-8686-0F6B90AF85A9}';

type
  // структура для раздачи GUID
  pTRGeneralRecord = ^TRGeneralRecord;
  TRGeneralRecord = record
    Operation: Cardinal;             // код 0/1 (признак занятости имени Mutex)
    CommandOffset: Cardinal;         // смещение до данных командной записи
    GUID: array [0..38] of WideChar; // имя Mutex (UTF-16)
  end;

  // типы коменд для обмена между клиентом и сервером
  TRCommandCode = (
    cNone,
    cAny,
    cToServerPing,              // пинг от клиента к серверу
    cFromServerPong,            // ответ сервера на пинг
    cToClientPing,              // пинг от сервера к клиенту
    cFromClientPong,            // ответ клиента серверу
    cToClientExit,              // оповещение сервера клиентам, что сервер перестает работать
    cToServerSendFile,          // уведомление серверу, о необходимости передавать файл
    cToClientGetPartFile,       // запрос части файла у клиента
    cToServerPartFile,          // передача части файла серверу
    cToClientEndFile,           // окончание передачи файла серверу
    cToClientCancelFile         // прерываение передачи файла
  );

  // структура для обмена данными между клиентом и сервером
  pTRCommandRecord = ^TRCommandRecord;
  TRCommandRecord = record
    Command: TRCommandCode;               // тип команды
    Position, Size: UInt64;               // данные команды (позиция и размер данных)
    DataOffset: UInt64;                   // смещение до блока данных
    FileName: array [0..256] of WideChar; // данные команды (имя файла)
  end;

implementation

end.
