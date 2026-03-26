unit dutil;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

function WordFor(aValue: Double): string;
function TitleCase(const S: string): string;

implementation

function WordFor(aValue: Double): string;
var
  r, v: LongInt;
  a, b, c: Byte;
  t: string;
const
  ones: array[1..9] of string = (
    'one','two','three','four','five','six','seven','eight','nine');
  tens: array[2..9] of string = (
    'twenty','thirty','forty','fifty','sixty','seventy','eighty','ninety');
  teens: array[0..9] of string = (
    'ten','eleven','twelve','thirteen','fourteen','fifteen',
    'sixteen','seventeen','eighteen','nineteen');
begin
  v := Trunc(aValue);
  if v >= 1000000000 then
    raise Exception.Create('Number too large (>= 1,000,000,000)');

  if v >= 1000000 then begin
    r := v mod 1000000;
    v := v div 1000000;
    WordFor := WordFor(v) + ' million';
    if r > 0 then
      WordFor := WordFor + ' ' + WordFor(r);
  end
  else if v >= 1000 then begin
    r := v mod 1000;
    v := v div 1000;
    WordFor := WordFor(v) + ' thousand';
    if r > 0 then
      WordFor := WordFor + ' ' + WordFor(r);
  end
  else begin
    t := '';
    a := v div 100;        // Hundreds
    b := (v mod 100) div 10; // Tens
    c := v mod 10;           // Ones

    if a in [1..9] then begin
      t := ones[a] + ' hundred';
      if (b + c) > 0 then
        t := t + ' and ';
    end;

    if b = 1 then
      t := t + teens[c]
    else begin
      if b in [2..9] then
        t := t + tens[b];
      if (b > 0) and (c > 0) then
        t := t + '-';
      if c in [1..9] then
        t := t + ones[c];
    end;

    WordFor := t;
  end;

  WordFor := Trim(WordFor);
end;

function TitleCase(const S: string): string;
var
  i: Integer;
  NewWord: Boolean;
begin
  Result := LowerCase(S);
  NewWord := True;

  for i := 1 to Length(Result) do
  begin
    if NewWord and (Result[i] in ['a'..'z']) then
    begin
      Result[i] := UpCase(Result[i]);
      NewWord := False;
    end
    else if Result[i] in [' ', #9, '-', ''''] then
      NewWord := True
    else
      NewWord := False;
  end;
end;

end.

