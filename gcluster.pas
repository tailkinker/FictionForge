{
Note to future me:
The FPC team went ahead and removed TStringReader / TStringWriter, and
TStreamWriter.  The current version of this unit saves and loads to text files,
because that is all that is shelf-stable.  Don't try to refactor this to use
streams, no matter what ChatGPT or Gemini say, because the FPC team can't be
bothered to keep things working.
}

unit gCluster;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

type
  tClusterItemClass = class of tClusterItem;
  tClusterUpdateProc = procedure(Sender: TObject) of object;

  tClusterItem = class (tObject)
  protected
    FGUID : tGUID;
    FParent : tClusterItem;
    FOnUpdate: TClusterUpdateProc;
  public
    property GUID : tGUID read FGUID;
    property Parent : tClusterItem read FParent write FParent;
    property OnUpdate : TClusterUpdateProc read FOnUpdate write FOnUpdate;
    constructor Create; virtual;
    constructor Create (aParent : tClusterItem); virtual;
    destructor  Destroy; override;
    function    HandleKey     (const k, v : string) : boolean; virtual;
    procedure   WriteKey      (var t : text; const k, v : string);
    procedure   WriteKeys     (var t : text); virtual;
    procedure   PreLoad       (var t : text); virtual;
    procedure   Load          (var t : text); virtual;
    procedure   Save          (var t : text); virtual;
    function    CompareTo     (aItem : tClusterItem) : integer; virtual;
    procedure   LogUnknownKey (const k, v : string); virtual;
    procedure   LoadFromFile  (aFilename : string); virtual;
    procedure   SaveToFile    (aFilename : string); virtual;
    procedure   Edit; virtual;
    procedure   ExportTo      (var t: text); virtual;
    procedure   MarkDirty;    virtual;
    procedure   Update;       virtual;
  end;

  tCluster = class (tClusterItem)
  protected
    FCapacity,
    FLockCount,
    FCount : longint;
    FCluster : array of tClusterItem;
    FDirty,  // Has the list changed?
    FAutoSort,
    FUpdatePending : boolean; // Track if a sort is needed
    procedure ExtendCluster;
    function  GetItem(Index: longint): tClusterItem;
    procedure SetItem(Index: longint; AItem: tClusterItem);
    procedure QuickSort(L, R: Longint); virtual;
    procedure CombSort; virtual;
    function  BinarySearch(aItem: tClusterItem; out Index: Longint): Boolean;
    function  GetLast : longint;
  public
    property Items[Index: longint]: tClusterItem read GetItem write SetItem; default;
    property Count : longint read FCount;
    property AutoSort : boolean read FAutoSort write FAutoSort;
    property Dirty: boolean read FDirty write FDirty;
    property Last : longint read GetLast;

    constructor Create;      override;
    constructor Create       (aParent : tClusterItem); override;
    destructor  Destroy;     override;
    procedure   Add          (AItem: tClusterItem); virtual;
    procedure   Remove       (Index: longint); virtual;
    procedure   Delete       (Index: longint); virtual;
    procedure   Move         (CurIndex, NewIndex : longint); virtual;
    function    IndexOf      (AItem: tClusterItem) : longint; virtual;
    procedure   Load         (var t : text); override;
    procedure   Save         (var t : text); override;
    procedure   Sort;        virtual;
    procedure   BeginUpdate; virtual;
    procedure   EndUpdate;   virtual;
    function    Search       (aItem: tClusterItem) : tClusterItem; virtual;
    procedure   Clear;
    procedure   ExportTo     (var t: text); virtual;
    procedure   MarkDirty;   override;
  end;

  tFileCluster = class (tCluster)
  protected
    FFileName : string;
  public
    property Filename : string read FFileName write FFileName;
    procedure SaveFile; virtual;
    procedure LoadFile; virtual;
  end;


procedure RegisterItemClass (AClass: tClusterItemClass);

implementation

{$region Helper Functions}

var
  ItemRegistry: TStringList; // Global or static registry

procedure RegisterItemClass (AClass: tClusterItemClass);
begin
  if ItemRegistry = nil then begin
    ItemRegistry := TStringList.Create;
    ItemRegistry.CaseSensitive := False;
  end;
  if ItemRegistry.IndexOf(AClass.ClassName) = -1 then
     ItemRegistry.AddObject(AClass.ClassName, TObject(AClass));
end;

function GetClassByName(const AName: string): tClusterItemClass;
var
  idx: integer;
begin
  if ItemRegistry = nil then
    Exit(nil);
  idx := ItemRegistry.IndexOf(AName);
  if idx <> -1 then
    Result := tClusterItemClass(ItemRegistry.Objects[idx])
  else
    Result := nil;
end;

{$endregion}



{$region tClusterItem}

constructor tClusterItem.Create;
begin
  Create (nil);
end;

constructor tClusterItem.Create (aParent : tClusterItem);
begin
  inherited Create;
  FParent := aParent;
  CreateGUID(FGUID);
end;

destructor tClusterItem.Destroy;
begin
  inherited Destroy;
end;

function tClusterItem.HandleKey (const k, v: string) : boolean;
begin
  if (k = 'GUID') then begin
    FGUID := StringToGUID(v);
    Result := TRUE
  end else
    Result := FALSE;
end;

procedure tClusterItem.WriteKey (var t: text; const k, v : string);
begin
  writeln (t, k, ' = ', v);
end;

procedure tClusterItem.WriteKeys (var t : text);
begin
  WriteKey (t, 'GUID', GUIDToString(FGUID));
end;

procedure tClusterItem.PreLoad (var t : text);
begin
  // Called prior to a Load being performed, though after the header is found.
  // NOP by default.
end;

procedure tClusterItem.Load (var t : text);
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

procedure tClusterItem.Save (var t : text);
begin
  writeln (t, '[' + ClassName + ']');
  WriteKeys (t);
  writeln (t, '[end ' + ClassName + ']');
  writeln (t);
end;

function tClusterItem.CompareTo(aItem: tClusterItem): integer;
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

procedure tClusterItem.LogUnknownKey (const k, v : string);
begin
  // By default, this is a NOP.  Override if you need it to do something.
end;

procedure tClusterItem.LoadFromFile (aFilename : string);
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

procedure tClusterItem.SaveToFile (aFilename : string);
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

procedure tClusterItem.Edit;
begin
  // Default: Do nothing. Subclasses override this to show a form
  // or perform a specific interactive logic.
end;

procedure tClusterItem.ExportTo(var t: text);
begin
  // Default: nothing
end;

procedure tClusterItem.MarkDirty;
begin
  if Assigned (FParent) then
    FParent.MarkDirty;
end;

procedure tClusterItem.Update;
begin
  if Assigned (FOnUpdate) then
    FOnUpdate (self);
end;

{$endregion tClusterItem}



{$region tCluster}

constructor tCluster.Create;
begin
  Create (nil);
end;

constructor tCluster.Create (aParent : tClusterItem);
begin
  inherited Create (aParent);
  FCapacity := 32;
  FCount := 0;
  FDirty := FALSE;
  SetLength (fCluster, FCapacity);
end;

destructor tCluster.Destroy;
var
  i: integer;
begin
  for i := 0 to FCount - 1 do
    FCluster[i].Free;
  inherited Destroy;
end;

function tCluster.GetItem(Index: longint): tClusterItem;
begin
  if (Index < 0) or (Index >= FCount) then
    raise Exception.CreateFmt('Cluster index out of bounds: %d', [Index]);
  Result := FCluster[Index];
end;

procedure tCluster.SetItem(Index: longint; AItem: tClusterItem);
begin
  if (Index < 0) or (Index >= FCount) then
    raise Exception.CreateFmt('Cluster index out of bounds: %d', [Index]);
  FCluster[Index] := AItem;
end;

procedure tCluster.ExtendCluster;
begin
  FCapacity := FCapacity * 2;
  SetLength(FCluster, FCapacity);
end;

procedure tCluster.Add (AItem: tClusterItem);
begin
  if FCount = FCapacity then
    ExtendCluster;
  FCluster[FCount] := AItem;
  Inc(FCount);

  MarkDirty;
  if FAutoSort then
    if FLockCount > 0 then
      FUpdatePending := true // Defer the sort
    else
      Sort; // Sort immediately
end;

procedure tCluster.Remove (Index: longint);
var
  j: longint;
begin
  if (Index < 0) or (Index >= FCount) then
    raise Exception.CreateFmt('Cluster index out of bounds: %d', [Index]);

  // Shift elements to the left to fill the gap
  for j := Index to FCount - 2 do
    FCluster[j] := FCluster[j + 1];

  // Clear the now-redundant last slot and decrement count
  FCluster[FCount - 1] := nil;
  Dec(FCount);
  MarkDirty;
end;

procedure tCluster.Delete (Index: longint);
var
  Item: tClusterItem;
begin
  // Grab the reference before removing it from the array
  Item := GetItem(Index);

  // Remove from the array structure
  Remove(Index);

  // Free the memory of the object itself
  Item.Free;
end;

procedure tCluster.Move (CurIndex, NewIndex: Longint);
var
  TempItem: tClusterItem;
  i: Longint;
begin
  if (CurIndex = NewIndex) then Exit;
  if (CurIndex < 0) or (CurIndex >= FCount) then Exit;

  if NewIndex < 0 then NewIndex := 0;
  if NewIndex >= FCount then NewIndex := FCount - 1;

  // 1. Snag the item being moved
  TempItem := FCluster[CurIndex];

  // 2. Shift the remaining items one by one
  if CurIndex < NewIndex then begin
    // Moving Forward: Shift items between Cur and New to the LEFT
    for i := CurIndex to NewIndex - 1 do
      FCluster[i] := FCluster[i + 1];
  end else begin
    // Moving Backward: Shift items between New and Cur to the RIGHT
    for i := CurIndex downto NewIndex + 1 do
      FCluster[i] := FCluster[i - 1];
  end;

  // 3. Place the item back down in the new spot
  FCluster[NewIndex] := TempItem;

  FDirty := True;
  // If manual move occurs, AutoSort usually needs to be disabled
  FAutoSort := False;
end;

function tCluster.IndexOf (AItem: tClusterItem): longint;
var
  i: longint;
begin
  Result := -1;
  for i := 0 to FCount - 1 do
    if FCluster[i] = AItem then
      Exit(i);
end;

procedure tCluster.Save(var t: text);
var
  i: longint;
begin
  writeln(t, '[' + ClassName + ']');
  WriteKeys(t); // Save Cluster-specific properties if any

  for i := 0 to FCount - 1 do
    FCluster[i].Save(t);

  writeln(t, '[end ' + ClassName + ']');
  writeln(t);
  FDirty := FALSE;
end;

procedure tCluster.Load(var t: text);
var
  k,
  v,
  s,
  ClassNameStr : string;
  i : longint;
  Done : boolean;
  ItemClass: tClusterItemClass;
  NewItem: tClusterItem;
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

procedure tCluster.QuickSort(L, R: Longint);
var
  i, j: Longint;
  Pivot, Temp: tClusterItem;
begin
  if (FCount = 0) or (L >= R) then Exit;
  i := L;
  j := R;
  Pivot := FCluster[(L + R) div 2];
  repeat
    while FCluster[i].CompareTo(Pivot) < 0 do Inc(i);
    while FCluster[j].CompareTo(Pivot) > 0 do Dec(j);
    if i <= j then
    begin
      Temp := FCluster[i];
      FCluster[i] := FCluster[j];
      FCluster[j] := Temp;
      Inc(i);
      Dec(j);
    end;
  until i > j;
  if L < j then QuickSort(L, j);
  if i < R then QuickSort(i, R);
end;

procedure tCluster.Sort;
begin
  if FCount > 1 then
    //QuickSort(0, FCount - 1);
    CombSort;
end;

procedure tCluster.CombSort;
var
  Gap, i: Longint;
  Temp: tClusterItem;
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
      if FCluster[i].CompareTo(FCluster[i + Gap]) > 0 then begin
        Temp := FCluster[i];
        FCluster[i] := FCluster[i + Gap];
        FCluster[i + Gap] := Temp;
        Swapped := True;
      end;
    end;
  until (Gap = 1) and not Swapped;

  // --- Phase 2: Gnome Sort ---
  // Since Gap=1 and Swapped=False above, the list is already almost entirely
  // sorted, but a Gnome pass ensures 100% stability.
  i := 1;
  while i < FCount do begin
    if (i = 0) or (FCluster[i].CompareTo(FCluster[i - 1]) >= 0) then
      Inc(i)
    else begin
      Temp := FCluster[i];
      FCluster[i] := FCluster[i - 1];
      FCluster[i - 1] := Temp;
      Dec(i);
    end;
  end;
end;

procedure tCluster.BeginUpdate;
begin
  Inc(FLockCount);
end;

procedure tCluster.EndUpdate;
begin
  if FLockCount > 0 then
    Dec(FLockCount);

  if (FLockCount = 0) and FUpdatePending then
  begin
    if FAutoSort then Sort;
    FUpdatePending := false;
  end;
end;

function tCluster.BinarySearch(aItem: tClusterItem; out Index: Longint): Boolean;
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
    // Use the virtual CompareTo of the item in the Cluster
    C := FCluster[M].CompareTo(aItem);

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

function tCluster.Search(aItem: tClusterItem): tClusterItem;
var
  i, Index: Longint;
begin
  Result := nil;
  if aItem = nil then Exit;

  // Use Binary Search ONLY if sorted AND not currently being modified
  if FAutoSort and (FLockCount = 0) and not FUpdatePending then
  begin
    if BinarySearch(aItem, Index) then
      Result := FCluster[Index];
  end
  else
  begin
    // Fallback to Linear Search using the item's own CompareTo
    for i := 0 to FCount - 1 do
    begin
      if FCluster[i].CompareTo(aItem) = 0 then
      begin
        Result := FCluster[i];
        Break;
      end;
    end;
  end;
end;

procedure tCluster.Clear;
var
  i: integer;
begin
  for i := 0 to FCount - 1 do
    if (FCluster[i].Parent = self) then
      FCluster[i].Free;
  FCount := 0;
  FDirty := FALSE;
end;

procedure tCluster.ExportTo(var t: text);
var
  i: Longint;
begin
  for i := 0 to FCount - 1 do
    FCluster[i].ExportTo(t);
end;

procedure tCluster.MarkDirty;
begin
  if FDirty then
    Exit;
  FDirty := TRUE;
  inherited MarkDirty;
end;

function tCluster.GetLast : longint;
begin
  Result := FCount - 1;
end;

{$endregion tCluster}

{$region tFileCluster}
procedure tFileCluster.SaveFile;
begin
  if (FFileName <> '') then
    SaveToFile (FFilename);
end;

procedure tFileCluster.LoadFile;
begin
  if (FFileName <> '') then
    LoadFromFile (FFilename);
end;

{$endregion tFileCluster}

initialization
  RegisterItemClass (tCluster);
  RegisterItemClass (tFileCluster)
end.


