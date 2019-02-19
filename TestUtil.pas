unit TestUtil;

interface

uses System.SysUtils, System.Math, log;

type

  TRTest = class
  private
    class var SuccessCount: Integer;
    class var FailedCount: Integer;

    class function Check(value: Boolean): String;
  public
    class procedure Init;
    class procedure ResultTest;

    class procedure CheckEqual(const name: String; value1, value2: Boolean); overload;
    class procedure CheckEqual(const name: String; value1, value2: String); overload;

    class procedure CheckEqual(const name: String; value1, value2: NativeInt); overload;
    class procedure CheckLess(const name: String; value1, value2: NativeInt); overload;
    class procedure CheckGreater(const name: String; value1, value2: NativeInt); overload;
    class procedure CheckLessEqual(const name: String; value1, value2: NativeInt); overload;
    class procedure CheckGreaterEqual(const name: String; value1, value2: NativeInt); overload;
    class procedure CheckNotEqual(const name: String; value1, value2: NativeInt); overload;

    class procedure CheckEqual(const name: String; value1, value2: Pointer); overload;
    class procedure CheckLess(const name: String; value1, value2: Pointer); overload;
    class procedure CheckGreater(const name: String; value1, value2: Pointer); overload;
    class procedure CheckLessEqual(const name: String; value1, value2: Pointer); overload;
    class procedure CheckGreaterEqual(const name: String; value1, value2: Pointer); overload;
    class procedure CheckNotEqual(const name: String; value1, value2: Pointer); overload;


    class procedure Category(const name: String);
  end;

implementation

{ TRTest }

class procedure TRTest.CheckEqual(const name: String; value1, value2: NativeInt);
begin
  ConsoleWriteLn(name + ' - ' + Check(value1 = value2));
end;

class procedure TRTest.CheckEqual(const name: String; value1, value2: Boolean);
begin
  ConsoleWriteLn(name + ' - ' + Check(value1 = value2));
end;

class procedure TRTest.Category(const name: String);
begin
  ConsoleWriteLn;
  ConsoleWriteLn('= ' + name);
  ConsoleWriteLn;
end;

class function TRTest.Check(value: Boolean): String;
begin
  if value = false then
  begin
    result := 'false';
    inc(FailedCount);
  end
  else
  begin
    result := 'true';
    inc(SuccessCount);
  end;
end;

class procedure TRTest.CheckEqual(const name: String; value1, value2: Pointer);
begin
  ConsoleWriteLn(name + ' - ' + Check(value1 = value2));
end;

class procedure TRTest.CheckEqual(const name: String; value1, value2: String);
begin
  ConsoleWriteLn(name + ' - ' + Check(value1 = value2));
end;

class procedure TRTest.CheckGreater(const name: String; value1,
  value2: NativeInt);
begin
  ConsoleWriteLn(name + ' - ' + Check(value1 > value2));
end;

class procedure TRTest.CheckGreaterEqual(const name: String; value1,
  value2: NativeInt);
begin
  ConsoleWriteLn(name + ' - ' + Check(value1 >= value2));
end;

class procedure TRTest.CheckLess(const name: String; value1, value2: NativeInt);
begin
  ConsoleWriteLn(name + ' - ' + Check(value1 < value2));
end;

class procedure TRTest.CheckLessEqual(const name: String; value1,
  value2: NativeInt);
begin
  ConsoleWriteLn(name + ' - ' + Check(value1 <= value2));
end;

class procedure TRTest.Init;
begin
  SuccessCount := 0;
  FailedCount := 0;

  ConsoleWriteLn('========================');
  ConsoleWriteLn('= Begin Tests ==========');
  ConsoleWriteLn('========================');
end;

class procedure TRTest.ResultTest;
begin
  ConsoleWriteLn('========================');
  ConsoleWriteLn('= End Tests ============');
  ConsoleWriteLn('========================');
  ConsoleWriteLn;
  ConsoleWriteLn('Sussess: ' + IntToStr(SuccessCount));
  ConsoleWriteLn('Failed: ' + IntToStr(FailedCount));
end;

class procedure TRTest.CheckGreater(const name: String; value1,
  value2: Pointer);
begin
  ConsoleWriteLn(name + ' - ' + Check(NativeInt(value1) > NativeInt(value2)));
end;

class procedure TRTest.CheckGreaterEqual(const name: String; value1,
  value2: Pointer);
begin
  ConsoleWriteLn(name + ' - ' + Check(NativeInt(value1) >= NativeInt(value2)));
end;

class procedure TRTest.CheckLess(const name: String; value1, value2: Pointer);
begin
  ConsoleWriteLn(name + ' - ' + Check(NativeInt(value1) < NativeInt(value2)));
end;

class procedure TRTest.CheckLessEqual(const name: String; value1,
  value2: Pointer);
begin
  ConsoleWriteLn(name + ' - ' + Check(NativeInt(value1) <= NativeInt(value2)));
end;

class procedure TRTest.CheckNotEqual(const name: String; value1,
  value2: NativeInt);
begin
  ConsoleWriteLn(name + ' - ' + Check(value1 <> value2));
end;

class procedure TRTest.CheckNotEqual(const name: String; value1,
  value2: Pointer);
begin
  ConsoleWriteLn(name + ' - ' + Check(value1 <> value2));
end;

end.
