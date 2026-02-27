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
 *
 * There are conditional compilation symbols that have an impact on performance/features:
 *      UNSAFE_BYTEBUFFER - Use unsafe code for better performance
 *      BYTEBUFFER_NO_BOUNDS_CHECK - Disable bounds checking for performance
 *}

unit ByteBuffer;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.Types;

type
  TByteBufferAllocator = class abstract
  protected
    FLength: Integer;
  public
    property Length: Integer read FLength;
    procedure GrowFront(newSize: Integer); virtual; abstract;
    function GetBuffer: TArray<Byte>; virtual; abstract;
  end;

  TByteArrayAllocator = class sealed(TByteBufferAllocator)
  private
    FBuffer: TArray<Byte>;
  public
    constructor Create(const buffer: TArray<Byte>);
    procedure GrowFront(newSize: Integer); override;
    function GetBuffer: TArray<Byte>; override;
  end;

  {* Class to mimic Java's ByteBuffer which is used heavily in Flatbuffers. *}
  TByteBuffer = class
  private
    FBuffer: TByteBufferAllocator;
    FPos: Integer;  // Must track start of the buffer.

    class var
      FGenericSizes: TDictionary<string, Integer>;
  protected
    class procedure InitializeGenericSizes;
    procedure AssertOffsetAndLength(offset: Integer; length: Integer);
    procedure WriteLittleEndian(offset: Integer; count: Integer; data: UInt64);
    function ReadLittleEndian(offset: Integer; count: Integer): UInt64;
  public
    class function ReverseBytes(input: UInt16): UInt16; overload; static;
    class function ReverseBytes(input: UInt32): UInt32; overload; static;
    class function ReverseBytes(input: UInt64): UInt64; overload; static;
    class function ConvertTsToBytes<T>(valueInTs: Integer): Integer; static;
    class function ConvertBytesToTs<T>(valueInBytes: Integer): Integer; static;
  public
    constructor Create(allocator: TByteBufferAllocator; position: Integer); overload;
    constructor Create(size: Integer); overload;
    constructor Create(const buffer: TArray<Byte>); overload;
    constructor Create(const buffer: TArray<Byte>; pos: Integer); overload;
    destructor Destroy; override;

    property Position: Integer read FPos write FPos;
    function GetLength: Integer; inline;

    procedure Reset;
    function Duplicate: TByteBuffer;
    procedure GrowFront(newSize: Integer);

    function ToArray(pos: Integer; len: Integer): TArray<Byte>; overload;
    function ToArray<T>(posInBytes: Integer; lenInBytes: Integer): TArray<T>; overload;
    function ToArrayPadded<T>(posInBytes: Integer; lenInBytes: Integer; padLeftInBytes: Integer; padRightInBytes: Integer): TArray<T>;
    function ToSizedArrayPadded(padLeft: Integer; padRight: Integer): TArray<Byte>;
    function ToSizedArray: TArray<Byte>;
    function ToFullArray: TArray<Byte>;

    class function SizeOf<T>: Integer;
    class function IsSupportedType<T>: Boolean;
    class function ArraySize<T>(const x: TArray<T>): Integer;

    // Put methods
    procedure PutSbyte(offset: Integer; value: ShortInt);
    procedure PutByte(offset: Integer; value: Byte); overload;
    procedure PutByte(offset: Integer; value: Byte; count: Integer); overload;
    procedure Put(offset: Integer; value: Byte);  overload;
    procedure PutStringUTF8(offset: Integer; const value: string);
    procedure PutShort(offset: Integer; value: SmallInt);
    procedure PutUshort(offset: Integer; value: Word);
    procedure PutInt(offset: Integer; value: Integer);
    procedure PutUint(offset: Integer; value: Cardinal);
    procedure PutLong(offset: Integer; value: Int64);
    procedure PutUlong(offset: Integer; value: UInt64);
    procedure PutFloat(offset: Integer; value: Single);
    procedure PutDouble(offset: Integer; value: Double);
    function Put<T>(offset: Integer; const x: TArray<T>): Integer; overload;

    // Get methods
    function GetSbyte(index: Integer): ShortInt;
    function Get(index: Integer): Byte;
    function GetStringUTF8(startPos: Integer; len: Integer): string;
    function GetShort(offset: Integer): SmallInt;
    function GetUshort(offset: Integer): Word;
    function GetInt(offset: Integer): Integer;
    function GetUint(offset: Integer): Cardinal;
    function GetLong(offset: Integer): Int64;
    function GetUlong(offset: Integer): UInt64;
    function GetFloat(offset: Integer): Single;
    function GetDouble(offset: Integer): Double;
  end;

implementation

uses
  System.Math, System.TypInfo;

{ TByteArrayAllocator }

constructor TByteArrayAllocator.Create(const buffer: TArray<Byte>);
begin
  inherited Create;
  FBuffer := buffer;
  FLength := System.Length(buffer);
end;

procedure TByteArrayAllocator.GrowFront(newSize: Integer);
var
  newBuffer: TArray<Byte>;
begin
  if (FLength and $C0000000) <> 0 then
    raise Exception.Create('ByteBuffer: cannot grow buffer beyond 2 gigabytes.');

  if newSize < FLength then
    raise Exception.Create('ByteBuffer: cannot truncate buffer.');

  SetLength(newBuffer, newSize);
  if FLength > 0 then
    Move(FBuffer[0], newBuffer[newSize - FLength], FLength);
  FBuffer := newBuffer;
  FLength := System.Length(FBuffer);
end;

function TByteArrayAllocator.GetBuffer: TArray<Byte>;
begin
  Result := FBuffer;
end;

{ TByteBuffer }

class procedure TByteBuffer.InitializeGenericSizes;
begin
  if not Assigned(FGenericSizes) then
  begin
    FGenericSizes := TDictionary<string, Integer>.Create;
    FGenericSizes.Add('Boolean', System.SizeOf(Boolean));
    FGenericSizes.Add('Single', System.SizeOf(Single));
    FGenericSizes.Add('Double', System.SizeOf(Double));
    FGenericSizes.Add('ShortInt', System.SizeOf(ShortInt));
    FGenericSizes.Add('Byte', System.SizeOf(Byte));
    FGenericSizes.Add('SmallInt', System.SizeOf(SmallInt));
    FGenericSizes.Add('Word', System.SizeOf(Word));
    FGenericSizes.Add('Integer', System.SizeOf(Integer));
    FGenericSizes.Add('Cardinal', System.SizeOf(Cardinal));
    FGenericSizes.Add('UInt64', System.SizeOf(UInt64));
    FGenericSizes.Add('Int64', System.SizeOf(Int64));
  end;
end;

constructor TByteBuffer.Create(allocator: TByteBufferAllocator; position: Integer);
begin
  inherited Create;
  InitializeGenericSizes;
  FBuffer := allocator;
  FPos := position;
end;

constructor TByteBuffer.Create(size: Integer);
begin
  Create(TByteArrayAllocator.Create(nil), 0);
  TByteArrayAllocator(FBuffer).GrowFront(size);
end;

constructor TByteBuffer.Create(const buffer: TArray<Byte>);
begin
  Create(buffer, 0);
end;

constructor TByteBuffer.Create(const buffer: TArray<Byte>; pos: Integer);
begin
  Create(TByteArrayAllocator.Create(buffer), pos);
end;

destructor TByteBuffer.Destroy;
begin
  if Assigned(FBuffer) then
    FBuffer.Free;
  inherited;
end;

function TByteBuffer.GetLength: Integer;
begin
  Result := FBuffer.Length;
end;

procedure TByteBuffer.Reset;
begin
  FPos := 0;
end;

function TByteBuffer.Duplicate: TByteBuffer;
begin
  Result := TByteBuffer.Create(FBuffer, Position);
end;

procedure TByteBuffer.GrowFront(newSize: Integer);
begin
  FBuffer.GrowFront(newSize);
end;

procedure TByteBuffer.AssertOffsetAndLength(offset: Integer; length: Integer);
begin
  {$IFNDEF BYTEBUFFER_NO_BOUNDS_CHECK}
  if (offset < 0) or (offset > FBuffer.Length - length) then
    raise EArgumentOutOfRangeException.Create('Offset or length out of range');
  {$ENDIF}
end;

class function TByteBuffer.ReverseBytes(input: UInt16): UInt16;
begin
  Result := ((input and $00FF) shl 8) or ((input and $FF00) shr 8);
end;

class function TByteBuffer.ReverseBytes(input: UInt32): UInt32;
begin
  Result := ((input and $000000FF) shl 24) or
            ((input and $0000FF00) shl 8) or
            ((input and $00FF0000) shr 8) or
            ((input and $FF000000) shr 24);
end;

class function TByteBuffer.ReverseBytes(input: UInt64): UInt64;
begin
  Result := ((input and $00000000000000FF) shl 56) or
            ((input and $000000000000FF00) shl 40) or
            ((input and $0000000000FF0000) shl 24) or
            ((input and $00000000FF000000) shl 8) or
            ((input and $000000FF00000000) shr 8) or
            ((input and $0000FF0000000000) shr 24) or
            ((input and $00FF000000000000) shr 40) or
            ((input and $FF00000000000000) shr 56);
end;

procedure TByteBuffer.WriteLittleEndian(offset: Integer; count: Integer; data: UInt64);
var
  i: Integer;
  buffer: TArray<Byte>;
begin
  buffer := FBuffer.GetBuffer;
  // Windows is little-endian, so we can write directly
  for i := 0 to count - 1 do
    buffer[offset + i] := Byte((data shr (i * 8)) and $FF);
end;

function TByteBuffer.ReadLittleEndian(offset: Integer; count: Integer): UInt64;
var
  i: Integer;
  r: UInt64;
  buffer: TArray<Byte>;
begin
  AssertOffsetAndLength(offset, count);
  buffer := FBuffer.GetBuffer;
  r := 0;
  // Windows is little-endian, so we can read directly
  for i := 0 to count - 1 do
    r := r or (UInt64(buffer[offset + i]) shl (i * 8));
  Result := r;
end;

class function TByteBuffer.ConvertTsToBytes<T>(valueInTs: Integer): Integer;
var
  sizeOfT: Integer;
begin
  sizeOfT := SizeOf<T>;
  Result := valueInTs * sizeOfT;
end;

class function TByteBuffer.ConvertBytesToTs<T>(valueInBytes: Integer): Integer;
var
  sizeOfT: Integer;
begin
  sizeOfT := SizeOf<T>;
  Result := valueInBytes div sizeOfT;
  {$IFNDEF BYTEBUFFER_NO_BOUNDS_CHECK}
  if Result * sizeOfT <> valueInBytes then
    raise EArgumentException.Create(Format('%d must be a multiple of SizeOf<T>()=%d', [valueInBytes, sizeOfT]));
  {$ENDIF}
end;

class function TByteBuffer.SizeOf<T>: Integer;
var
  typeName: string;
begin
  typeName := GetTypeName(TypeInfo(T));
  if FGenericSizes.ContainsKey(typeName) then
    Result := FGenericSizes[typeName]
  else
    Result := System.SizeOf(T);
end;

class function TByteBuffer.IsSupportedType<T>: Boolean;
var
  typeName: string;
begin
  typeName := GetTypeName(TypeInfo(T));
  Result := FGenericSizes.ContainsKey(typeName);
end;

class function TByteBuffer.ArraySize<T>(const x: TArray<T>): Integer;
begin
  Result := SizeOf<T> * Length(x);
end;

function TByteBuffer.ToArray(pos: Integer; len: Integer): TArray<Byte>;
begin
  Result := ToArray<Byte>(pos, len);
end;

function TByteBuffer.ToArray<T>(posInBytes: Integer; lenInBytes: Integer): TArray<T>;
var
  lenInTs: Integer;
  arrayOfTs: TArray<T>;
  buffer: TArray<Byte>;
begin
  AssertOffsetAndLength(posInBytes, lenInBytes);
  lenInTs := ConvertBytesToTs<T>(lenInBytes);
  SetLength(arrayOfTs, lenInTs);
  buffer := FBuffer.GetBuffer;
  Move(buffer[posInBytes], arrayOfTs[0], lenInBytes);
  Result := arrayOfTs;
end;

function TByteBuffer.ToArrayPadded<T>(posInBytes: Integer; lenInBytes: Integer; padLeftInBytes: Integer; padRightInBytes: Integer): TArray<T>;
var
  padLeftInTs, lenInTs, padRightInTs, sizeInTs: Integer;
  arrayOfTs: TArray<T>;
  buffer: TArray<Byte>;
begin
  AssertOffsetAndLength(posInBytes, lenInBytes);
  padLeftInTs := ConvertBytesToTs<T>(padLeftInBytes);
  lenInTs := ConvertBytesToTs<T>(lenInBytes);
  padRightInTs := ConvertBytesToTs<T>(padRightInBytes);
  sizeInTs := padLeftInTs + lenInTs + padRightInTs;
  SetLength(arrayOfTs, sizeInTs);
  buffer := FBuffer.GetBuffer;
  Move(buffer[posInBytes], arrayOfTs[padLeftInTs], lenInBytes);
  Result := arrayOfTs;
end;

function TByteBuffer.ToSizedArrayPadded(padLeft: Integer; padRight: Integer): TArray<Byte>;
begin
  Result := ToArrayPadded<Byte>(Position, GetLength - Position, padLeft, padRight);
end;

function TByteBuffer.ToSizedArray: TArray<Byte>;
begin
  Result := ToArray<Byte>(Position, GetLength - Position);
end;

function TByteBuffer.ToFullArray: TArray<Byte>;
begin
  Result := ToArray<Byte>(0, GetLength);
end;

procedure TByteBuffer.PutSbyte(offset: Integer; value: ShortInt);
var
  buffer: TArray<Byte>;
begin
  AssertOffsetAndLength(offset, System.SizeOf(ShortInt));
  buffer := FBuffer.GetBuffer;
  buffer[offset] := Byte(value);
end;

procedure TByteBuffer.PutByte(offset: Integer; value: Byte);
var
  buffer: TArray<Byte>;
begin
  AssertOffsetAndLength(offset, System.SizeOf(Byte));
  buffer := FBuffer.GetBuffer;
  buffer[offset] := value;
end;

procedure TByteBuffer.PutByte(offset: Integer; value: Byte; count: Integer);
var
  i: Integer;
  buffer: TArray<Byte>;
begin
  AssertOffsetAndLength(offset, System.SizeOf(Byte) * count);
  buffer := FBuffer.GetBuffer;
  for i := 0 to count - 1 do
    buffer[offset + i] := value;
end;

procedure TByteBuffer.Put(offset: Integer; value: Byte);
begin
  PutByte(offset, value);
end;

procedure TByteBuffer.PutStringUTF8(offset: Integer; const value: string);
var
  utf8Bytes: TArray<Byte>;
  buffer: TArray<Byte>;
  i: Integer;
begin
  utf8Bytes := TEncoding.UTF8.GetBytes(value);
  AssertOffsetAndLength(offset, Length(utf8Bytes));
  buffer := FBuffer.GetBuffer;
  for i := 0 to Length(utf8Bytes) - 1 do
    buffer[offset + i] := utf8Bytes[i];
end;

procedure TByteBuffer.PutShort(offset: Integer; value: SmallInt);
begin
  PutUshort(offset, Word(value));
end;

procedure TByteBuffer.PutUshort(offset: Integer; value: Word);
begin
  AssertOffsetAndLength(offset, System.SizeOf(Word));
  WriteLittleEndian(offset, System.SizeOf(Word), UInt64(value));
end;

procedure TByteBuffer.PutInt(offset: Integer; value: Integer);
begin
  PutUint(offset, Cardinal(value));
end;

procedure TByteBuffer.PutUint(offset: Integer; value: Cardinal);
begin
  AssertOffsetAndLength(offset, System.SizeOf(Cardinal));
  WriteLittleEndian(offset, System.SizeOf(Cardinal), UInt64(value));
end;

procedure TByteBuffer.PutLong(offset: Integer; value: Int64);
begin
  PutUlong(offset, UInt64(value));
end;

procedure TByteBuffer.PutUlong(offset: Integer; value: UInt64);
begin
  AssertOffsetAndLength(offset, System.SizeOf(UInt64));
  WriteLittleEndian(offset, System.SizeOf(UInt64), value);
end;

procedure TByteBuffer.PutFloat(offset: Integer; value: Single);
var
  intValue: Integer absolute value;
begin
  AssertOffsetAndLength(offset, System.SizeOf(Single));
  WriteLittleEndian(offset, System.SizeOf(Single), UInt64(intValue));
end;

procedure TByteBuffer.PutDouble(offset: Integer; value: Double);
var
  int64Value: Int64 absolute value;
begin
  AssertOffsetAndLength(offset, System.SizeOf(Double));
  WriteLittleEndian(offset, System.SizeOf(Double), UInt64(int64Value));
end;

function TByteBuffer.Put<T>(offset: Integer; const x: TArray<T>): Integer;
var
  numBytes: Integer;
  buffer: TArray<Byte>;
begin
  if not Assigned(x) then
    raise EArgumentNilException.Create('Cannot put a null array');

  if Length(x) = 0 then
    raise EArgumentException.Create('Cannot put an empty array');

  if not IsSupportedType<T> then
    raise EArgumentException.Create('Cannot put an array of type ' + GetTypeName(TypeInfo(T)) + ' into this buffer');

  numBytes := ArraySize<T>(x);
  offset := offset - numBytes;
  AssertOffsetAndLength(offset, numBytes);
  buffer := FBuffer.GetBuffer;
  // For little-endian systems, we can do a block copy
  Move(x[0], buffer[offset], numBytes);
  Result := offset;
end;

function TByteBuffer.GetSbyte(index: Integer): ShortInt;
var
  buffer: TArray<Byte>;
begin
  AssertOffsetAndLength(index, System.SizeOf(ShortInt));
  buffer := FBuffer.GetBuffer;
  Result := ShortInt(buffer[index]);
end;

function TByteBuffer.Get(index: Integer): Byte;
var
  buffer: TArray<Byte>;
begin
  AssertOffsetAndLength(index, System.SizeOf(Byte));
  buffer := FBuffer.GetBuffer;
  Result := buffer[index];
end;

function TByteBuffer.GetStringUTF8(startPos: Integer; len: Integer): string;
var
  buffer: TArray<Byte>;
  utf8Bytes: TArray<Byte>;
begin
  AssertOffsetAndLength(startPos, len);
  buffer := FBuffer.GetBuffer;
  SetLength(utf8Bytes, len);
  Move(buffer[startPos], utf8Bytes[0], len);
  Result := TEncoding.UTF8.GetString(utf8Bytes);
end;

function TByteBuffer.GetShort(offset: Integer): SmallInt;
begin
  Result := SmallInt(ReadLittleEndian(offset, System.SizeOf(SmallInt)));
end;

function TByteBuffer.GetUshort(offset: Integer): Word;
begin
  Result := Word(ReadLittleEndian(offset, System.SizeOf(Word)));
end;

function TByteBuffer.GetInt(offset: Integer): Integer;
begin
  Result := Integer(ReadLittleEndian(offset, System.SizeOf(Integer)));
end;

function TByteBuffer.GetUint(offset: Integer): Cardinal;
begin
  Result := Cardinal(ReadLittleEndian(offset, System.SizeOf(Cardinal)));
end;

function TByteBuffer.GetLong(offset: Integer): Int64;
begin
  Result := Int64(ReadLittleEndian(offset, System.SizeOf(Int64)));
end;

function TByteBuffer.GetUlong(offset: Integer): UInt64;
begin
  Result := ReadLittleEndian(offset, System.SizeOf(UInt64));
end;

function TByteBuffer.GetFloat(offset: Integer): Single;
var
  intValue: Integer;
  floatValue: Single absolute intValue;
begin
  intValue := 0;
  intValue := Integer(ReadLittleEndian(offset, System.SizeOf(Single)));
  Result := floatValue;
end;

function TByteBuffer.GetDouble(offset: Integer): Double;
var
  int64Value: Int64;
  doubleValue: Double absolute int64Value;
begin
  int64Value := ReadLittleEndian(offset, System.SizeOf(Double));
  Result := doubleValue;
end;

initialization
  TByteBuffer.InitializeGenericSizes;

finalization
  if Assigned(TByteBuffer.FGenericSizes) then
    TByteBuffer.FGenericSizes.Free;

end.
