unit SharedConst;

interface

  //
  // ������������� ������

  // � ������ ������
  // +0                       sizeof(TRGeneralRecord)      ��������� ��� ������� GUID (� ������������ ����������)
  // sizeof(TRGeneralRecord)  n * sizeof(TRCommandRecord)  ������ �������� ��� ������� � ���������

  // � ����� ������ - ����� (����) ��� �������� ������

const
  // ��� �������
  SERVER_NAME: String = '{95FC2447-9ADA-4931-A393-477A48400336}';
  // ������ ������ ��� ������������
  SERVER_MEM_SIZE: UInt64 = 256 * 1024;
  // ��� mutex ��� ������� GUID
  GLOBALRECORD_MUTEX_NAME: String = '{718F3915-E128-4032-852F-AC0B22536351}';
  // ��� mutex ��� �������� �������
  SERVERCONTROL_MUTEX_NAME: String = '{F57A659E-F930-4FDC-8686-0F6B90AF85A9}';

type
  // ��������� ��� ������� GUID
  pTRGeneralRecord = ^TRGeneralRecord;
  TRGeneralRecord = record
    Operation: Cardinal;             // ��� 0/1 (������� ��������� ����� Mutex)
    CommandOffset: Cardinal;         // �������� �� ������ ��������� ������
    GUID: array [0..38] of WideChar; // ��� Mutex (UTF-16)
  end;

  // ���� ������ ��� ������ ����� �������� � ��������
  TRCommandCode = (
    cNone,
    cAny,
    cToServerPing,              // ���� �� ������� � �������
    cFromServerPong,            // ����� ������� �� ����
    cToClientPing,              // ���� �� ������� � �������
    cFromClientPong,            // ����� ������� �������
    cToClientExit,              // ���������� ������� ��������, ��� ������ ��������� ��������
    cToServerSendFile,          // ����������� �������, � ������������� ���������� ����
    cToClientGetPartFile,       // ������ ����� ����� � �������
    cToServerPartFile,          // �������� ����� ����� �������
    cToClientEndFile,           // ��������� �������� ����� �������
    cToClientCancelFile         // ����������� �������� �����
  );

  // ��������� ��� ������ ������� ����� �������� � ��������
  pTRCommandRecord = ^TRCommandRecord;
  TRCommandRecord = record
    Command: TRCommandCode;               // ��� �������
    Position, Size: UInt64;               // ������ ������� (������� � ������ ������)
    DataOffset: UInt64;                   // �������� �� ����� ������
    FileName: array [0..256] of WideChar; // ������ ������� (��� �����)
  end;

implementation

end.
