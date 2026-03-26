unit gtags;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

type
  tTags = class
  private
    t_taglist: string;
    procedure SetTags(const Value: string);
    function GetTagCount : integer;
  public
    property TagList : string read t_taglist write SetTags;
    property TagCount : integer read GetTagCount;
    function Tag (index: Integer): string;
    function Tagged (const aString: string): Boolean;
    procedure AddTag (const aString : string);
  end;

implementation

uses
  StrUtils;

procedure tTags.SetTags(const Value: string);
var
  TagArray: array of string;
  Temp: string;
  i, pos: Integer;
begin
  // 1. Split and Trim
  TagArray := Value.Split([','], TStringSplitOptions.ExcludeEmpty);
  for i := 0 to High(TagArray) do
    TagArray[i] := TagArray[i].Trim;

  // 2. Gnome Sort (The "Stupid Sort")
  // It works by moving an item forward until it finds its place, then bouncing back.
  i := 1;
  while i < Length(TagArray) do
  begin
    if (i = 0) or (CompareStr(TagArray[i], TagArray[i - 1]) >= 0) then
      Inc(i)
    else
    begin
      // Swap elements
      Temp := TagArray[i];
      TagArray[i] := TagArray[i - 1];
      TagArray[i - 1] := Temp;
      Dec(i);
    end;
  end;

  // 3. Recombine into CSV
  t_taglist := string.Join(',', TagArray);
end;

function tTags.GetTagCount : integer;
var
  index : integer;
begin
  if (length (t_taglist) = 0) then
    Result := 0
  else begin
    Result := 1;
    for index := 1 to length (t_taglist) do
      if (t_taglist [index] = ',') then
        Result += 1;
  end;
end;

function tTags.Tag(Index: Integer): string;
var
  Parts: TStringArray;
begin
  Parts := SplitString(t_taglist, ',');
  if (Index >= Low(Parts)) and (Index <= High(Parts)) then
    Result := Trim(Parts[Index])
  else
    Result := '';
end;

function tTags.Tagged(const aString: string): Boolean;
var
  Parts: TStringArray;
  i: Integer;
  TestString,
  S: string;
begin
  Result := False;
  TestString := LowerCase (aString);
  Parts := SplitString(t_taglist, ',');
  for i := Low(Parts) to High(Parts) do
  begin
    S := LowerCase (Trim(Parts[i]));
    if SameText(S, TestString) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure tTags.AddTag (const aString : string);
var
  s : string;
begin
  if (length (aString) > 0) then begin
    s := t_taglist;
    if (length (s) > 0) then
      s := s + ',';
    s := s + aString;
    SetTags(s)
  end
end;

end.


