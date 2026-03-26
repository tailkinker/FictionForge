{
Note to future me:
The FPC team went ahead and removed TStringReader / TStringWriter, and
TStreamWriter.  The current version of this unit saves and loads to text files,
because that is all that is shelf-stable.  Don't try to refactor this to use
streams, no matter what ChatGPT or Gemini say, because the FPC team can't be
bothered to keep things working.
}

unit Collections;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

type
  tCollectionItemClass = class of tCollectionItem;
  tCollectionUpdateProc = procedure(Sender: TObject) of object;

  tCollectionItem = class (tObject)
  protected
    FGUID : tGUID;
    FParent : tCollectionItem;
    FOnUpdate: TCollectionUpdateProc;
  public
    property GUID : tGUID read FGUID;
    property Parent : tCollectionItem read FParent write FParent;
    property OnUpdate : TCollectionUpdateProc read FOnUpdate write FOnUpdate;
    constructor Create; virtual;
    constructor Create (aParent : tCollectionItem); virtual;
    destructor  Destroy; override;
    function    HandleKey     (const k, v : string) : boolean; virtual;
    procedure   WriteKey      (var t : text; const k, v : string);
    procedure   WriteKeys     (var t : text); virtual;
    procedure   PreLoad       (var t : text); virtual;
    procedure   Load          (var t : text); virtual;
    procedure   Save          (var t : text); virtual;
    function    CompareTo     (aItem : tCollectionItem) : integer; virtual;
    procedure   LogUnknownKey (const k, v : string); virtual;
    procedure   LoadFromFile  (aFilename : string); virtual;
    procedure   SaveToFile    (aFilename : string); virtual;
    procedure   Edit; virtual;
    procedure   ExportTo      (var t: text); virtual;
    procedure   MarkDirty;    virtual;
    procedure   Update;       virtual;
  end;

  tCollection = class (tCollectionItem)
  protected
    FCapacity,
    FLockCount,
    FCount : longint;
    FCollection : array of tCollectionItem;
    FDirty,  // Has the list changed?
    FAutoSort,
    FUpdatePending : boolean; // Track if a sort is needed
    procedure ExtendCollection;
    function  GetItem(Index: longint): tCollectionItem;
    procedure SetItem(Index: longint; AItem: tCollectionItem);
    procedure QuickSort(L, R: Longint); virtual;
    procedure CombSort; virtual;
    function  BinarySearch(aItem: tCollectionItem; out Index: Longint): Boolean;
  public
    property Items[Index: longint]: tCollectionItem read GetItem write SetItem; default;
    property Count : longint read FCount;
    property AutoSort : boolean read FAutoSort write FAutoSort;
    property Dirty: boolean read FDirty write FDirty;

    constructor Create;      override;
    constructor Create       (aParent : tCollectionItem); override;
    destructor  Destroy;     override;
    procedure   Add          (AItem: tCollectionItem); virtual;
    procedure   Remove       (Index: longint); virtual;
    procedure   Delete       (Index: longint); virtual;
    function    IndexOf      (AItem: tCollectionItem) : longint;
    procedure   Load         (var t : text); override;
    procedure   Save         (var t : text); override;
    procedure   Sort;        virtual;
    procedure   BeginUpdate; virtual;
    procedure   EndUpdate;   virtual;
    function    Search       (aItem: tCollectionItem) : tCollectionItem; virtual;
    procedure   Clear;
    procedure   ExportTo     (var t: text); virtual;
    procedure   MarkDirty;   override;
  end;

  tFileCollection = class (tCollection)
  protected
    FFileName : string;
  public
    property Filename : string read FFileName write FFileName;
    procedure SaveFile; virtual;
    procedure LoadFile; virtual;
  end;


procedure RegisterItemClass (AClass: tCollectionItemClass);

implementation

{$region Helper Functions}

var
  ItemRegistry: TStringList; // Global or static registry

procedure RegisterItemClass (AClass: tCollectionItemClass);
begin
  if ItemRegistry = nil then begin
    ItemRegistry := TStringList.Create;
    ItemRegistry.CaseSensitive := False;
  end;
  if ItemRegistry.IndexOf(AClass.ClassName) = -1 then
     ItemRegistry.AddObject(AClass.ClassName, TObject(AClass));
end;

function GetClassByName(const AName: string): tCollectionItemClass;
var
  idx: integer;
begin
  if ItemRegistry = nil then
    Exit(nil);
  idx := ItemRegistry.IndexOf(AName);
  if idx <> -1 then
    Result := tCollectionItemClass(ItemRegistry.Objects[idx])
  else
    Result := nil;
end;

{$endregion}



{$region tCollectionItem}

constructor tCollectionItem.Create;
begin
  Create (nil);
end;

constructor tCollectionItem.Create (aParent : tCollectionItem);
begin
  inherited Create;
  FParent := aParent;
  CreateGUID(FGUID);
end;

destructor tCollectionItem.Destroy;
begin
  inherited Destroy;
end;

function tCollectionItem.HandleKey (const k, v: string) : boolean;
begin
  if (k = 'GUID') then begin
    FGUID := StringToGUID(v);
    Result := TRUE
  end else
    Result := FALSE;
end;

procedure tCollectionItem.WriteKey (var t: text; const k, v : string);
begin
  writeln (t, k, ' = ', v);
end;

procedure tCollectionItem.WriteKeys (var t : text);
begin
  WriteKey (t, 'GUID', GUIDToString(FGUID));
end;

procedure tCollectionItem.PreLoad (var t : text);
begin
  // Called prior to a Load being performed, though after the header is found.
  // NOP by default.
end;

procedure tCollectionItem.Load (var t : text);
var
  k,
  v,
  s : string;
  i : longint;
  Done : boolean;
begin
  PreLoad(t);
  Done := false;
  repeat
    // Read Keyline
    if (EoF(t)) then
      Exit;
    readln (t, s);
    v := '';
    if (length (s) > 0) then
    	s := Trim (s);
    if (s = '') then
      Continue;

    if (s = '[end ' + ClassName + ']') then
      Done := true
    else begin
      // Find the = sign
      i := Pos('=', s);

      // Split Keyline
      if (i = 0) then
        k := s
      else begin
        k := Trim (copy (s, 1, i - 1));
        v := Trim (copy (s, i + 1, length (s) - i));
      end;

      if not (HandleKey (k, v)) then
        LogUnknownKey(k, v);
    end;
  until Done;
end;

procedure tCollectionItem.Save (var t : text);
begin
  writeln (t, '[' + ClassName + ']');
  WriteKeys (t);
  writeln (t, '[end ' + ClassName + ']');
  writeln (t);
end;

function tCollectionItem.CompareTo(aItem: tCollectionItem): integer;
var
  i: integer;
begin
  if aItem = nil then Exit(1);

  // Compare Data1 (Cardinal/LongWord)
  if self.GUID.D1 < aItem.GUID.D1 then Exit(-1);
  if self.GUID.D1 > aItem.GUID.D1 then Exit(1);

  // Compare Data2 (Word)
  if self.GUID.D2 < aItem.GUID.D2 then Exit(-1);
  if self.GUID.D2 > aItem.GUID.D2 then Exit(1);

  // Compare Data3 (Word)
  if self.GUID.D3 < aItem.GUID.D3 then Exit(-1);
  if self.GUID.D3 > aItem.GUID.D3 then Exit(1);

  // Compare Data4 (Array [0..7] of Byte)
  for i := 0 to 7 do
  begin
    if self.GUID.D4[i] < aItem.GUID.D4[i] then Exit(-1);
    if self.GUID.D4[i] > aItem.GUID.D4[i] then Exit(1);
  end;

  // If we got here, they are identical
  Result := 0;
end;

procedure tCollectionItem.LogUnknownKey (const k, v : string);
begin
  // By default, this is a NOP.  Override if you need it to do something.
end;

procedure tCollectionItem.LoadFromFile (aFilename : string);
var
  t : text;
  s  : string;
begin
  If (FileExists (aFilename)) then begin
    AssignFile (t, aFilename);
    try
      Reset (t);
      repeat
        readln (t, s);
        s := Trim (s);
      until (s = '[' + ClassName + ']');
      Load (t);
    finally
      CloseFile (t);
    end;
  end;
end;

procedure tCollectionItem.SaveToFile (aFilename : string);
var
  t : text;
begin
  AssignFile (t, aFilename);
  try
    Rewrite (t);
    Save (t);
  finally
    Closefile (t);
  end;
end;

procedure tCollectionItem.Edit;
begin
  // Default: Do nothing. Subclasses override this to show a form
  // or perform a specific interactive logic.
end;

procedure tCollectionItem.ExportTo(var t: text);
begin
  // Default: nothing
end;

procedure tCollectionItem.MarkDirty;
begin
  if Assigned (FParent) then
    FParent.MarkDirty;
end;

procedure tCollectionItem.Update;
begin
  if Assigned (FOnUpdate) then
    FOnUpdate (self);
end;

{$endregion tCollectionItem}



{$region tCollection}

constructor tCollection.Create;
begin
  Create (nil);
end;

constructor tCollection.Create (aParent : tCollectionItem);
begin
  inherited Create (aParent);
  FCapacity := 32;
  FCount := 0;
  FDirty := FALSE;
  SetLength (fCollection, FCapacity);
end;

destructor tCollection.Destroy;
var
  i: integer;
begin
  for i := 0 to FCount - 1 do
    FCollection[i].Free;
  inherited Destroy;
end;

function tCollection.GetItem(Index: longint): tCollectionItem;
begin
  if (Index < 0) or (Index >= FCount) then
    raise Exception.CreateFmt('Collection index out of bounds: %d', [Index]);
  Result := FCollection[Index];
end;

procedure tCollection.SetItem(Index: longint; AItem: tCollectionItem);
begin
  if (Index < 0) or (Index >= FCount) then
    raise Exception.CreateFmt('Collection index out of bounds: %d', [Index]);
  FCollection[Index] := AItem;
end;

procedure tCollection.ExtendCollection;
begin
  FCapacity := FCapacity * 2;
  SetLength(FCollection, FCapacity);
end;

procedure tCollection.Add (AItem: tCollectionItem);
begin
  if FCount = FCapacity then
    ExtendCollection;
  FCollection[FCount] := AItem;
  Inc(FCount);

  MarkDirty;
  if FAutoSort then
    if FLockCount > 0 then
      FUpdatePending := true // Defer the sort
    else
      Sort; // Sort immediately
end;

procedure tCollection.Remove (Index: longint);
var
  j: longint;
begin
  if (Index < 0) or (Index >= FCount) then
    raise Exception.CreateFmt('Collection index out of bounds: %d', [Index]);

  // Shift elements to the left to fill the gap
  for j := Index to FCount - 2 do
    FCollection[j] := FCollection[j + 1];

  // Clear the now-redundant last slot and decrement count
  FCollection[FCount - 1] := nil;
  Dec(FCount);
  MarkDirty;
end;

procedure tCollection.Delete (Index: longint);
var
  Item: tCollectionItem;
begin
  // Grab the reference before removing it from the array
  Item := GetItem(Index);

  // Remove from the array structure
  Remove(Index);

  // Free the memory of the object itself
  Item.Free;
end;

function tCollection.IndexOf (AItem: tCollectionItem): longint;
var
  i: longint;
begin
  Result := -1;
  for i := 0 to FCount - 1 do
    if FCollection[i] = AItem then
      Exit(i);
end;

procedure tCollection.Save(var t: text);
var
  i: longint;
begin
  writeln(t, '[' + ClassName + ']');
  WriteKeys(t); // Save collection-specific properties if any

  for i := 0 to FCount - 1 do
    FCollection[i].Save(t);

  writeln(t, '[end ' + ClassName + ']');
  writeln(t);
  FDirty := FALSE;
end;

procedure tCollection.Load(var t: text);
var
  k,
  v,
  s,
  ClassNameStr : string;
  i : longint;
  Done : boolean;
  ItemClass: tCollectionItemClass;
  NewItem: tCollectionItem;
begin
  Done := FALSE;
  BeginUpdate;
  try
    repeat
      // Read Keyline
      if EoF(t) then
        Exit;
      readln(t, s);
      v := '';
      if (length (s) > 0) then
    	  s := Trim (s);
      if (s = '') then
        Continue;

      if s = '[end ' + ClassName + ']' then
        Done := TRUE

      // If it's a new object tag like [tSomeItem]
      else if (s[1] = '[') and (s[length(s)] = ']') then begin
        ClassNameStr := copy(s, 2, length(s) - 2);
        ItemClass := GetClassByName(ClassNameStr);

        if Assigned(ItemClass) then begin
          NewItem := ItemClass.Create (self);
          NewItem.Load(t); // The item loads its own keys until [end ClassName]
          Add(NewItem);
        end;
      end else begin
        // Find the = sign
        i := Pos('=', s);

        // Split Keyline
        if (i = 0) then
          k := s
        else begin
          k := Trim (copy (s, 1, i - 1));
          v := Trim (copy (s, i + 1, length (s) - i));
        end;

        if not (HandleKey (k, v)) then
          LogUnknownKey(k, v);
      end;
    until Done;
    FDirty := FALSE;
  finally
    EndUpdate;
  end;
end;

procedure tCollection.QuickSort(L, R: Longint);
var
  i, j: Longint;
  Pivot, Temp: tCollectionItem;
begin
  if (FCount = 0) or (L >= R) then Exit;
  i := L;
  j := R;
  Pivot := FCollection[(L + R) div 2];
  repeat
    while FCollection[i].CompareTo(Pivot) < 0 do Inc(i);
    while FCollection[j].CompareTo(Pivot) > 0 do Dec(j);
    if i <= j then
    begin
      Temp := FCollection[i];
      FCollection[i] := FCollection[j];
      FCollection[j] := Temp;
      Inc(i);
      Dec(j);
    end;
  until i > j;
  if L < j then QuickSort(L, j);
  if i < R then QuickSort(i, R);
end;

procedure tCollection.Sort;
begin
  if FCount > 1 then
    //QuickSort(0, FCount - 1);
    CombSort;
end;

procedure tCollection.CombSort;
var
  Gap, i: Longint;
  Temp: tCollectionItem;
  Swapped: Boolean;
begin
  if FCount < 2 then
     Exit;

  // --- Phase 1: Comb Sort ---
  Gap := FCount;
  repeat
    Gap := (Gap * 10) div 13; // The "magic" shrink factor
    if Gap < 1 then
      Gap := 1;
    Swapped := False;
    for i := 0 to FCount - 1 - Gap do begin
      if FCollection[i].CompareTo(FCollection[i + Gap]) > 0 then begin
        Temp := FCollection[i];
        FCollection[i] := FCollection[i + Gap];
        FCollection[i + Gap] := Temp;
        Swapped := True;
      end;
    end;
  until (Gap = 1) and not Swapped;

  // --- Phase 2: Gnome Sort ---
  // Since Gap=1 and Swapped=False above, the list is already almost entirely
  // sorted, but a Gnome pass ensures 100% stability.
  i := 1;
  while i < FCount do begin
    if (i = 0) or (FCollection[i].CompareTo(FCollection[i - 1]) >= 0) then
      Inc(i)
    else begin
      Temp := FCollection[i];
      FCollection[i] := FCollection[i - 1];
      FCollection[i - 1] := Temp;
      Dec(i);
    end;
  end;
end;

procedure tCollection.BeginUpdate;
begin
  Inc(FLockCount);
end;

procedure tCollection.EndUpdate;
begin
  if FLockCount > 0 then
    Dec(FLockCount);

  if (FLockCount = 0) and FUpdatePending then
  begin
    if FAutoSort then Sort;
    FUpdatePending := false;
  end;
end;

function tCollection.BinarySearch(aItem: tCollectionItem; out Index: Longint): Boolean;
var
  L, R, M: Longint;
  C: Integer;
begin
  Result := False;
  Index := 0;
  L := 0;
  R := FCount - 1;
  while L <= R do
  begin
    M := L + (R - L) div 2;
    // Use the virtual CompareTo of the item in the collection
    C := FCollection[M].CompareTo(aItem);

    if C < 0 then
      L := M + 1
    else if C > 0 then
      R := M - 1
    else
    begin
      Index := M;
      Exit(True);
    end;
  end;
  Index := L;
end;

function tCollection.Search(aItem: tCollectionItem): tCollectionItem;
var
  i, Index: Longint;
begin
  Result := nil;
  if aItem = nil then Exit;

  // Use Binary Search ONLY if sorted AND not currently being modified
  if FAutoSort and (FLockCount = 0) and not FUpdatePending then
  begin
    if BinarySearch(aItem, Index) then
      Result := FCollection[Index];
  end
  else
  begin
    // Fallback to Linear Search using the item's own CompareTo
    for i := 0 to FCount - 1 do
    begin
      if FCollection[i].CompareTo(aItem) = 0 then
      begin
        Result := FCollection[i];
        Break;
      end;
    end;
  end;
end;

procedure tCollection.Clear;
var
  i: integer;
begin
  for i := 0 to FCount - 1 do
    if (FCollection[i].Parent = self) then
      FCollection[i].Free;
  FCount := 0;
  FDirty := FALSE;
end;

procedure tCollection.ExportTo(var t: text);
var
  i: Longint;
begin
  for i := 0 to FCount - 1 do
    FCollection[i].ExportTo(t);
end;

procedure tCollection.MarkDirty;
begin
  if FDirty then
    Exit;
  FDirty := TRUE;
  inherited MarkDirty;
end;

{$endregion tCollection}

{$region tFileCollection}
procedure tFileCollection.SaveFile;
begin
  if (FFileName <> '') then
    SaveToFile (FFilename);
end;

procedure tFileCollection.LoadFile;
begin
  if (FFileName <> '') then
    LoadFromFile (FFilename);
end;

{$endregion tFileCollection}

initialization
  RegisterItemClass (tCollection);
  RegisterItemClass (tFileCollection)
end.


