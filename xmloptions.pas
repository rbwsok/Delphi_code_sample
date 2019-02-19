unit xmloptions;

interface

uses System.Classes, System.Variants, System.SysUtils, System.Win.ComObj,
Winapi.ActiveX;

type
  TROptions = class
  private
    FOutputServerPath: String;

    FStreams: TStringList;

    function GetStringAttribute(node: Variant; const attribute, DefaultValue: String): String;
    function GetIntAttribute(node: Variant; const attribute: String; DefaultValue: Integer): Integer;
  public
    constructor Create;
    destructor Destroy; override;

    function LoadXML(const filename: String): Boolean;

    function GetStreamFileName(id: Integer): String;

    property OutputServerPath: String read FOutputServerPath;
  end;

implementation

{ TROptions }

constructor TROptions.Create;
begin
  FStreams := TStringList.Create;
  // по умолчанию - путь для сохренения файлов - место расположения exe
  FOutputServerPath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
end;

destructor TROptions.Destroy;
begin
  FreeAndNil(FStreams);
  inherited;
end;

function TROptions.GetStreamFileName(id: Integer): String;
var
  i: Integer;
begin
  i := 0;
  while i < FStreams.Count do
  begin
    if Integer(FStreams.Objects[i]) = id then
      exit(FStreams[i]);

    inc(i);
  end;

  result := '';
end;

function TROptions.GetStringAttribute(node: Variant; const attribute, DefaultValue: String): String;
var
  value: Variant;
begin
  result := DefaultValue;
  value := node.getAttribute(attribute);

  if VarIsNull(value) = false then
  begin
    result := node.getAttribute(attribute)
  end;
end;

function TROptions.GetIntAttribute(node: Variant; const attribute: String; DefaultValue: Integer): Integer;
var
  value: Variant;
  str: String;
begin
  result := DefaultValue;
  value := node.getAttribute(attribute);
  if VarIsNull(value) = false then
  begin
    str := value;
    if (Length(str) > 0) and (str[1] = '#') then
    begin
      str[1] := '$';
      result := StrToIntDef(str,DefaultValue);
    end
    else
      result := value;
  end;
end;

function TROptions.LoadXML(const filename: String): Boolean;
var
  configxml: Variant;
  rootnode, node: Variant;
  i, id: Integer;
  streamfilename: String;
begin
  result := false;

  if FileExists(filename) = false then
    exit;

  try
    configxml := CreateOleObject('Microsoft.XMLDOM');
    configxml.load(filename);

    // ошибка парсинга
    if configxml.parseError.reason <> '' then
      exit;

    rootnode := configxml.documentElement;

    // не тот рутовый элемент
    if rootnode.nodeName <> 'streams' then
      exit;

    i := 0;
    while i < rootnode.childNodes.length do
    begin
      node := rootnode.childNodes.item[i];

      // настройка сервера
      if node.nodeName = 'server' then
      begin
        FOutputServerPath := GetStringAttribute(node,'outputpath','');
        if FOutputServerPath <> '' then
        begin
          FOutputServerPath := IncludeTrailingPathDelimiter(FOutputServerPath);
          // создаем директорию, если ее нет
          ForceDirectories(FOutputServerPath);
        end;
      end;

      // настройка клиентских потоков
      if node.nodeName = 'stream' then
      begin
        id := GetIntAttribute(node, 'id', 0);
        streamfilename := GetStringAttribute(node,'file','');
        if id > 0 then
          FStreams.AddObject(streamfilename, TObject(id));
      end;

      inc(i);
    end;

  finally
    configxml := null;
  end;

  result := true;
end;

initialization
  CoInitialize(nil);
finalization
  CoUninitialize;

end.
