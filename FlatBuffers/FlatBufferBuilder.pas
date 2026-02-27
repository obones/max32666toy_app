{*
 * Copyright 2014 Google Inc. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *}

unit FlatBufferBuilder;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, ByteBuffer, Offset, FlatBufferConstants;

type
  {* Responsible for building up and accessing a FlatBuffer formatted byte
  array (via ByteBuffer). *}
  TFlatBufferBuilder = class
  private
    FSpace: Integer;
    FBb: TByteBuffer;
    FMinAlign: Integer;
    FVtable: TArray<Integer>;
    FVtableSize: Integer;
    FObjectStart: Integer;
    FVtables: TArray<Integer>;
    FNumVtables: Integer;
    FVectorNumElems: Integer;
    FSharedStringMap: TDictionary<string, TStringOffset>;
    FForceDefaults: Boolean;
  public
    procedure GrowBuffer;
    procedure Prep(size: Integer; additionalBytes: Integer);
    procedure PutBool(x: Boolean);
    procedure PutSbyte(x: ShortInt);
    procedure PutByte(x: Byte);
    procedure PutShort(x: SmallInt);
    procedure PutUshort(x: Word);
    procedure PutInt(x: Integer);
    procedure PutUint(x: Cardinal);
    procedure PutLong(x: Int64);
    procedure PutUlong(x: UInt64);
    procedure PutFloat(x: Single);
    procedure PutDouble(x: Double);
    procedure NotNested;
    procedure Nested(obj: Integer);
    procedure Slot(voffset: Integer);
  public
    constructor Create(initialSize: Integer); overload;
    constructor Create(buffer: TByteBuffer); overload;
    destructor Destroy; override;

    procedure Clear;

    property ForceDefaults: Boolean read FForceDefaults write FForceDefaults;
    function GetOffset: Integer;
    procedure Pad(size: Integer);

    // Add methods
    procedure AddBool(x: Boolean); overload;
    procedure AddSbyte(x: ShortInt); overload;
    procedure AddByte(x: Byte); overload;
    procedure AddShort(x: SmallInt); overload;
    procedure AddUshort(x: Word); overload;
    procedure AddInt(x: Integer); overload;
    procedure AddUint(x: Cardinal); overload;
    procedure AddLong(x: Int64); overload;
    procedure AddUlong(x: UInt64); overload;
    procedure AddFloat(x: Single); overload;
    procedure AddDouble(x: Double); overload;
    procedure Add<T>(const x: TArray<T>); overload;

    procedure AddOffset(off: Integer); overload;
    procedure StartVector(elemSize: Integer; count: Integer; alignment: Integer);
    function EndVector: TVectorOffset;
    function CreateVectorOfTables<T>(const offsets: TArray<TOffset<T>>): TVectorOffset;

    procedure StartTable(numfields: Integer);
    function EndTable: Integer;

    // Add methods for table slots
    procedure AddBool(o: Integer; x: Boolean; d: Boolean); overload;
    procedure AddBool(o: Integer; x: Boolean); overload;
    procedure AddSbyte(o: Integer; x: ShortInt; d: ShortInt); overload;
    procedure AddSbyte(o: Integer; x: ShortInt); overload;
    procedure AddByte(o: Integer; x: Byte; d: Byte); overload;
    procedure AddByte(o: Integer; x: Byte); overload;
    procedure AddShort(o: Integer; x: SmallInt; d: Integer); overload;
    procedure AddShort(o: Integer; x: SmallInt); overload;
    procedure AddUshort(o: Integer; x: Word; d: Word); overload;
    procedure AddUshort(o: Integer; x: Word); overload;
    procedure AddInt(o: Integer; x: Integer; d: Integer); overload;
    procedure AddInt(o: Integer; x: Integer); overload;
    procedure AddUint(o: Integer; x: Cardinal; d: Cardinal); overload;
    procedure AddUint(o: Integer; x: Cardinal); overload;
    procedure AddLong(o: Integer; x: Int64; d: Int64); overload;
    procedure AddLong(o: Integer; x: Int64); overload;
    procedure AddUlong(o: Integer; x: UInt64; d: UInt64); overload;
    procedure AddUlong(o: Integer; x: UInt64); overload;
    procedure AddFloat(o: Integer; x: Single; d: Double); overload;
    procedure AddFloat(o: Integer; x: Single); overload;
    procedure AddDouble(o: Integer; x: Double; d: Double); overload;
    procedure AddDouble(o: Integer; x: Double); overload;
    procedure AddOffset(o: Integer; x: Integer; d: Integer); overload;
    procedure AddStruct(voffset: Integer; x: Integer; d: Integer);

    function CreateString(const s: string): TStringOffset;
    function CreateSharedString(const s: string): TStringOffset;

    procedure Required(table: Integer; field: Integer);
    procedure Finish(rootTable: Integer; sizePrefix: Boolean); overload;
    procedure Finish(rootTable: Integer); overload;
    procedure FinishSizePrefixed(rootTable: Integer); overload;
    procedure Finish(rootTable: Integer; const fileIdentifier: string); overload;
    procedure FinishSizePrefixed(rootTable: Integer; const fileIdentifier: string); overload;

    function DataBuffer: TByteBuffer;
    function SizedByteArray: TArray<Byte>;
  end;

implementation

uses
  System.Math, System.Types;

{ TFlatBufferBuilder }

constructor TFlatBufferBuilder.Create(initialSize: Integer);
begin
  inherited Create;
  if initialSize <= 0 then
    raise EArgumentOutOfRangeException.Create('initialSize must be greater than zero');
  FSpace := initialSize;
  FBb := TByteBuffer.Create(initialSize);
  FMinAlign := 1;
  SetLength(FVtable, 16);
  FVtableSize := -1;
  FObjectStart := 0;
  SetLength(FVtables, 16);
  FNumVtables := 0;
  FVectorNumElems := 0;
  FForceDefaults := False;
end;

constructor TFlatBufferBuilder.Create(buffer: TByteBuffer);
begin
  inherited Create;
  FBb := buffer;
  FSpace := buffer.GetLength;
  buffer.Reset;
  FMinAlign := 1;
  SetLength(FVtable, 16);
  FVtableSize := -1;
  FObjectStart := 0;
  SetLength(FVtables, 16);
  FNumVtables := 0;
  FVectorNumElems := 0;
  FForceDefaults := False;
end;

destructor TFlatBufferBuilder.Destroy;
begin
  if Assigned(FSharedStringMap) then
    FSharedStringMap.Free;
  if Assigned(FBb) then
    FBb.Free;
  inherited;
end;

procedure TFlatBufferBuilder.Clear;
begin
  FSpace := FBb.GetLength;
  FBb.Reset;
  FMinAlign := 1;
  while FVtableSize > 0 do
  begin
    Dec(FVtableSize);
    FVtable[FVtableSize] := 0;
  end;
  FVtableSize := -1;
  FObjectStart := 0;
  FNumVtables := 0;
  FVectorNumElems := 0;
  if Assigned(FSharedStringMap) then
    FSharedStringMap.Clear;
end;

function TFlatBufferBuilder.GetOffset: Integer;
begin
  Result := FBb.GetLength - FSpace;
end;

procedure TFlatBufferBuilder.Pad(size: Integer);
begin
  FBb.PutByte(FSpace - size, 0, size);
  Dec(FSpace, size);
end;

procedure TFlatBufferBuilder.GrowBuffer;
var
  oldBufSize: Integer;
begin
  oldBufSize := FBb.GetLength;
  FBb.GrowFront(FBb.GetLength shl 1);
  Inc(FSpace, FBb.GetLength - oldBufSize);
end;

procedure TFlatBufferBuilder.Prep(size: Integer; additionalBytes: Integer);
var
  alignSize: Integer;
  oldBufSize: Integer;
begin
  if size > FMinAlign then
    FMinAlign := size;
  alignSize := ((not (FBb.GetLength - FSpace + additionalBytes)) + 1) and (size - 1);
  while FSpace < alignSize + size + additionalBytes do
  begin
    oldBufSize := FBb.GetLength;
    GrowBuffer;
    Inc(FSpace, FBb.GetLength - oldBufSize);
  end;
  if alignSize > 0 then
    Pad(alignSize);
end;

procedure TFlatBufferBuilder.PutBool(x: Boolean);
begin
  FBb.PutByte(FSpace - SizeOf(Byte), Byte(IfThen(x, 1, 0)));
  Dec(FSpace, SizeOf(Byte));
end;

procedure TFlatBufferBuilder.PutSbyte(x: ShortInt);
begin
  FBb.PutSbyte(FSpace - SizeOf(ShortInt), x);
  Dec(FSpace, SizeOf(ShortInt));
end;

procedure TFlatBufferBuilder.PutByte(x: Byte);
begin
  FBb.PutByte(FSpace - SizeOf(Byte), x);
  Dec(FSpace, SizeOf(Byte));
end;

procedure TFlatBufferBuilder.PutShort(x: SmallInt);
begin
  FBb.PutShort(FSpace - SizeOf(SmallInt), x);
  Dec(FSpace, SizeOf(SmallInt));
end;

procedure TFlatBufferBuilder.PutUshort(x: Word);
begin
  FBb.PutUshort(FSpace - SizeOf(Word), x);
  Dec(FSpace, SizeOf(Word));
end;

procedure TFlatBufferBuilder.PutInt(x: Integer);
begin
  FBb.PutInt(FSpace - SizeOf(Integer), x);
  Dec(FSpace, SizeOf(Integer));
end;

procedure TFlatBufferBuilder.PutUint(x: Cardinal);
begin
  FBb.PutUint(FSpace - SizeOf(Cardinal), x);
  Dec(FSpace, SizeOf(Cardinal));
end;

procedure TFlatBufferBuilder.PutLong(x: Int64);
begin
  FBb.PutLong(FSpace - SizeOf(Int64), x);
  Dec(FSpace, SizeOf(Int64));
end;

procedure TFlatBufferBuilder.PutUlong(x: UInt64);
begin
  FBb.PutUlong(FSpace - SizeOf(UInt64), x);
  Dec(FSpace, SizeOf(UInt64));
end;

procedure TFlatBufferBuilder.PutFloat(x: Single);
begin
  FBb.PutFloat(FSpace - SizeOf(Single), x);
  Dec(FSpace, SizeOf(Single));
end;

procedure TFlatBufferBuilder.PutDouble(x: Double);
begin
  FBb.PutDouble(FSpace - SizeOf(Double), x);
  Dec(FSpace, SizeOf(Double));
end;

procedure TFlatBufferBuilder.AddBool(x: Boolean);
begin
  Prep(SizeOf(Byte), 0);
  PutBool(x);
end;

procedure TFlatBufferBuilder.AddSbyte(x: ShortInt);
begin
  Prep(SizeOf(ShortInt), 0);
  PutSbyte(x);
end;

procedure TFlatBufferBuilder.AddByte(x: Byte);
begin
  Prep(SizeOf(Byte), 0);
  PutByte(x);
end;

procedure TFlatBufferBuilder.AddShort(x: SmallInt);
begin
  Prep(SizeOf(SmallInt), 0);
  PutShort(x);
end;

procedure TFlatBufferBuilder.AddUshort(x: Word);
begin
  Prep(SizeOf(Word), 0);
  PutUshort(x);
end;

procedure TFlatBufferBuilder.AddInt(x: Integer);
begin
  Prep(SizeOf(Integer), 0);
  PutInt(x);
end;

procedure TFlatBufferBuilder.AddUint(x: Cardinal);
begin
  Prep(SizeOf(Cardinal), 0);
  PutUint(x);
end;

procedure TFlatBufferBuilder.AddLong(x: Int64);
begin
  Prep(SizeOf(Int64), 0);
  PutLong(x);
end;

procedure TFlatBufferBuilder.AddUlong(x: UInt64);
begin
  Prep(SizeOf(UInt64), 0);
  PutUlong(x);
end;

procedure TFlatBufferBuilder.AddFloat(x: Single);
begin
  Prep(SizeOf(Single), 0);
  PutFloat(x);
end;

procedure TFlatBufferBuilder.AddDouble(x: Double);
begin
  Prep(SizeOf(Double), 0);
  PutDouble(x);
end;

procedure TFlatBufferBuilder.Add<T>(const x: TArray<T>);
var
  size: Integer;
begin
  if Length(x) = 0 then
    Exit;

  if not TByteBuffer.IsSupportedType<T> then
    raise EArgumentException.Create('Cannot add this Type array to the builder');

  size := TByteBuffer.SizeOf<T>;
  Prep(size, size * (Length(x) - 1));
  FSpace := FBb.Put<T>(FSpace, x);
end;

procedure TFlatBufferBuilder.AddOffset(off: Integer);
begin
  Prep(SizeOf(Integer), 0);
  if off > GetOffset then
    raise EArgumentException.Create('Invalid offset');
  if off <> 0 then
    off := GetOffset - off + SizeOf(Integer);
  PutInt(off);
end;

procedure TFlatBufferBuilder.StartVector(elemSize: Integer; count: Integer; alignment: Integer);
begin
  NotNested;
  FVectorNumElems := count;
  Prep(SizeOf(Integer), elemSize * count);
  Prep(alignment, elemSize * count);
end;

function TFlatBufferBuilder.EndVector: TVectorOffset;
begin
  PutInt(FVectorNumElems);
  Result := TVectorOffset.Create(GetOffset);
end;

function TFlatBufferBuilder.CreateVectorOfTables<T>(const offsets: TArray<TOffset<T>>): TVectorOffset;
var
  i: Integer;
begin
  NotNested;
  StartVector(SizeOf(Integer), Length(offsets), SizeOf(Integer));
  for i := Length(offsets) - 1 downto 0 do
    AddOffset(offsets[i].Value);
  Result := EndVector;
end;

procedure TFlatBufferBuilder.NotNested;
begin
  if FVtableSize >= 0 then
    raise Exception.Create('FlatBuffers: object serialization must not be nested.');
end;

procedure TFlatBufferBuilder.Nested(obj: Integer);
begin
  if obj <> GetOffset then
    raise Exception.Create('FlatBuffers: struct must be serialized inline.');
end;

procedure TFlatBufferBuilder.StartTable(numfields: Integer);
begin
  if numfields < 0 then
    raise EArgumentOutOfRangeException.Create('Flatbuffers: invalid numfields');

  NotNested;

  if Length(FVtable) < numfields then
    SetLength(FVtable, numfields);

  FVtableSize := numfields;
  FObjectStart := GetOffset;
end;

procedure TFlatBufferBuilder.Slot(voffset: Integer);
begin
  if voffset >= FVtableSize then
    raise ERangeError.Create('Flatbuffers: invalid voffset');
  FVtable[voffset] := GetOffset;
end;

procedure TFlatBufferBuilder.AddBool(o: Integer; x: Boolean; d: Boolean);
begin
  if FForceDefaults or (x <> d) then
  begin
    AddBool(x);
    Slot(o);
  end;
end;

procedure TFlatBufferBuilder.AddBool(o: Integer; x: Boolean);
begin
  AddBool(x);
  Slot(o);
end;

procedure TFlatBufferBuilder.AddSbyte(o: Integer; x: ShortInt; d: ShortInt);
begin
  if FForceDefaults or (x <> d) then
  begin
    AddSbyte(x);
    Slot(o);
  end;
end;

procedure TFlatBufferBuilder.AddSbyte(o: Integer; x: ShortInt);
begin
  AddSbyte(x);
  Slot(o);
end;

procedure TFlatBufferBuilder.AddByte(o: Integer; x: Byte; d: Byte);
begin
  if FForceDefaults or (x <> d) then
  begin
    AddByte(x);
    Slot(o);
  end;
end;

procedure TFlatBufferBuilder.AddByte(o: Integer; x: Byte);
begin
  AddByte(x);
  Slot(o);
end;

procedure TFlatBufferBuilder.AddShort(o: Integer; x: SmallInt; d: Integer);
begin
  if FForceDefaults or (x <> d) then
  begin
    AddShort(x);
    Slot(o);
  end;
end;

procedure TFlatBufferBuilder.AddShort(o: Integer; x: SmallInt);
begin
  AddShort(x);
  Slot(o);
end;

procedure TFlatBufferBuilder.AddUshort(o: Integer; x: Word; d: Word);
begin
  if FForceDefaults or (x <> d) then
  begin
    AddUshort(x);
    Slot(o);
  end;
end;

procedure TFlatBufferBuilder.AddUshort(o: Integer; x: Word);
begin
  AddUshort(x);
  Slot(o);
end;

procedure TFlatBufferBuilder.AddInt(o: Integer; x: Integer; d: Integer);
begin
  if FForceDefaults or (x <> d) then
  begin
    AddInt(x);
    Slot(o);
  end;
end;

procedure TFlatBufferBuilder.AddInt(o: Integer; x: Integer);
begin
  AddInt(x);
  Slot(o);
end;

procedure TFlatBufferBuilder.AddUint(o: Integer; x: Cardinal; d: Cardinal);
begin
  if FForceDefaults or (x <> d) then
  begin
    AddUint(x);
    Slot(o);
  end;
end;

procedure TFlatBufferBuilder.AddUint(o: Integer; x: Cardinal);
begin
  AddUint(x);
  Slot(o);
end;

procedure TFlatBufferBuilder.AddLong(o: Integer; x: Int64; d: Int64);
begin
  if FForceDefaults or (x <> d) then
  begin
    AddLong(x);
    Slot(o);
  end;
end;

procedure TFlatBufferBuilder.AddLong(o: Integer; x: Int64);
begin
  AddLong(x);
  Slot(o);
end;

procedure TFlatBufferBuilder.AddUlong(o: Integer; x: UInt64; d: UInt64);
begin
  if FForceDefaults or (x <> d) then
  begin
    AddUlong(x);
    Slot(o);
  end;
end;

procedure TFlatBufferBuilder.AddUlong(o: Integer; x: UInt64);
begin
  AddUlong(x);
  Slot(o);
end;

procedure TFlatBufferBuilder.AddFloat(o: Integer; x: Single; d: Double);
begin
  if FForceDefaults or (x <> d) then
  begin
    AddFloat(x);
    Slot(o);
  end;
end;

procedure TFlatBufferBuilder.AddFloat(o: Integer; x: Single);
begin
  AddFloat(x);
  Slot(o);
end;

procedure TFlatBufferBuilder.AddDouble(o: Integer; x: Double; d: Double);
begin
  if FForceDefaults or (x <> d) then
  begin
    AddDouble(x);
    Slot(o);
  end;
end;

procedure TFlatBufferBuilder.AddDouble(o: Integer; x: Double);
begin
  AddDouble(x);
  Slot(o);
end;

procedure TFlatBufferBuilder.AddOffset(o: Integer; x: Integer; d: Integer);
begin
  if x <> d then
  begin
    AddOffset(x);
    Slot(o);
  end;
end;

procedure TFlatBufferBuilder.AddStruct(voffset: Integer; x: Integer; d: Integer);
begin
  if x <> d then
  begin
    Nested(x);
    Slot(voffset);
  end;
end;

function TFlatBufferBuilder.CreateString(const s: string): TStringOffset;
var
  utf8StringLen: Integer;
begin
  if s = '' then
  begin
    Result := TStringOffset.Create(0);
    Exit;
  end;
  NotNested;
  AddByte(0);
  utf8StringLen := TEncoding.UTF8.GetByteCount(s);
  StartVector(1, utf8StringLen, 1);
  FBb.PutStringUTF8(FSpace - utf8StringLen, s);
  Dec(FSpace, utf8StringLen);
  Result := TStringOffset.Create(EndVector.Value);
end;

function TFlatBufferBuilder.CreateSharedString(const s: string): TStringOffset;
var
  stringOffset: TStringOffset;
begin
  if s = '' then
  begin
    Result := TStringOffset.Create(0);
    Exit;
  end;

  if not Assigned(FSharedStringMap) then
    FSharedStringMap := TDictionary<string, TStringOffset>.Create;

  if FSharedStringMap.ContainsKey(s) then
  begin
    Result := FSharedStringMap[s];
    Exit;
  end;

  stringOffset := CreateString(s);
  FSharedStringMap.Add(s, stringOffset);
  Result := stringOffset;
end;

function TFlatBufferBuilder.EndTable: Integer;
var
  vtableloc: Integer;
  i: Integer;
  trimmedSize: Integer;
  off: SmallInt;
  existingVtable: Integer;
  vt1, vt2: Integer;
  len: SmallInt;
  j: Integer;
  newvtables: TArray<Integer>;
begin
  if FVtableSize < 0 then
    raise EInvalidOperation.Create('Flatbuffers: calling EndTable without a StartTable');

  AddInt(0);
  vtableloc := GetOffset;
  i := FVtableSize - 1;
  while (i >= 0) and (FVtable[i] = 0) do
    Dec(i);
  trimmedSize := i + 1;
  while i >= 0 do
  begin
    if FVtable[i] <> 0 then
      off := SmallInt(vtableloc - FVtable[i])
    else
      off := 0;
    AddShort(off);
    FVtable[i] := 0;
    Dec(i);
  end;

  AddShort(SmallInt(vtableloc - FObjectStart));
  AddShort(SmallInt((trimmedSize + 2) * SizeOf(SmallInt)));

  existingVtable := 0;
  for i := 0 to FNumVtables - 1 do
  begin
    vt1 := FBb.GetLength - FVtables[i];
    vt2 := FSpace;
    len := FBb.GetShort(vt1);
    if len = FBb.GetShort(vt2) then
    begin
      j := SizeOf(SmallInt);
      while j < len do
      begin
        if FBb.GetShort(vt1 + j) <> FBb.GetShort(vt2 + j) then
          Break;
        Inc(j, SizeOf(SmallInt));
      end;
      if j >= len then
      begin
        existingVtable := FVtables[i];
        Break;
      end;
    end;
  end;

  if existingVtable <> 0 then
  begin
    FSpace := FBb.GetLength - vtableloc;
    FBb.PutInt(FSpace, existingVtable - vtableloc);
  end
  else
  begin
    if FNumVtables = Length(FVtables) then
    begin
      SetLength(newvtables, FNumVtables * 2);
      Move(FVtables[0], newvtables[0], Length(FVtables) * SizeOf(Integer));
      FVtables := newvtables;
    end;
    FVtables[FNumVtables] := GetOffset;
    Inc(FNumVtables);
    FBb.PutInt(FBb.GetLength - vtableloc, GetOffset - vtableloc);
  end;

  FVtableSize := -1;
  Result := vtableloc;
end;

procedure TFlatBufferBuilder.Required(table: Integer; field: Integer);
var
  table_start: Integer;
  vtable_start: Integer;
  ok: Boolean;
begin
  table_start := FBb.GetLength - table;
  vtable_start := table_start - FBb.GetInt(table_start);
  ok := FBb.GetShort(vtable_start + field) <> 0;
  if not ok then
    raise EInvalidOperation.Create(Format('FlatBuffers: field %d must be set', [field]));
end;

procedure TFlatBufferBuilder.Finish(rootTable: Integer; sizePrefix: Boolean);
begin
  Prep(FMinAlign, SizeOf(Integer) + IfThen(sizePrefix, SizeOf(Integer), 0));
  AddOffset(rootTable);
  if sizePrefix then
    AddInt(FBb.GetLength - FSpace);
  FBb.Position := FSpace;
end;

procedure TFlatBufferBuilder.Finish(rootTable: Integer);
begin
  Finish(rootTable, False);
end;

procedure TFlatBufferBuilder.FinishSizePrefixed(rootTable: Integer);
begin
  Finish(rootTable, True);
end;

procedure TFlatBufferBuilder.Finish(rootTable: Integer; const fileIdentifier: string);
var
  i: Integer;
begin
  Prep(FMinAlign, SizeOf(Integer) + TFlatBufferConstants.SizePrefixLength);
  if Length(fileIdentifier) <> TFlatBufferConstants.FileIdentifierLength then
    raise EArgumentException.Create(Format('FlatBuffers: file identifier must be length %d', [TFlatBufferConstants.FileIdentifierLength]));
  for i := TFlatBufferConstants.FileIdentifierLength - 1 downto 0 do
    AddByte(Byte(fileIdentifier[i + 1]));
  Finish(rootTable, False);
end;

procedure TFlatBufferBuilder.FinishSizePrefixed(rootTable: Integer; const fileIdentifier: string);
begin
  Prep(FMinAlign, SizeOf(Integer) + SizeOf(Integer) + TFlatBufferConstants.FileIdentifierLength);
  if Length(fileIdentifier) <> TFlatBufferConstants.FileIdentifierLength then
    raise EArgumentException.Create(Format('FlatBuffers: file identifier must be length %d', [TFlatBufferConstants.FileIdentifierLength]));
  Finish(rootTable, True);
end;

function TFlatBufferBuilder.DataBuffer: TByteBuffer;
begin
  Result := FBb;
end;

function TFlatBufferBuilder.SizedByteArray: TArray<Byte>;
begin
  Result := FBb.ToSizedArray;
end;

end.
