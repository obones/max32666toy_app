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

unit Table;

interface

uses
  System.SysUtils, System.Classes, ByteBuffer, FlatbufferObject, FlatBufferConstants;

type
  {* All tables in the generated code derive from this struct, and add their own accessors. *}
  TTable = record
  private
    Fbb_pos: Integer;
    Fbb: TByteBuffer;
  public
    constructor Create(_i: Integer; _bb: TByteBuffer);
    property bb_pos: Integer read Fbb_pos;
    property bb: TByteBuffer read Fbb;
    property ByteBuffer: TByteBuffer read Fbb;

    {* Look up a field in the vtable, return an offset into the object, or 0 if the field is not
    present. *}
    function __offset(vtableOffset: Integer): Integer; overload;
    class function __offset(vtableOffset: Integer; offset: Integer; bb: TByteBuffer): Integer; overload; static;

    {* Retrieve the relative offset stored at "offset" *}
    function __indirect(offset: Integer): Integer; overload;
    class function __indirect(offset: Integer; bb: TByteBuffer): Integer; overload; static;

    {* Create a .NET String from UTF-8 data stored inside the flatbuffer. *}
    function __string(offset: Integer): string;

    {* Get the length of a vector whose offset is stored at "offset" in this object. *}
    function __vector_len(offset: Integer): Integer;

    {* Get the start of data of a vector whose offset is stored at "offset" in this object. *}
    function __vector(offset: Integer): Integer;

    {* Get the data of a vector whoses offset is stored at "offset" in this object as an
    T[]. If the vector is not present in the ByteBuffer, then a nil value will be
    returned. *}
    function __vector_as_array<T>(offset: Integer): TArray<T>;

    {* Initialize any Table-derived type to point to the union at the given offset. *}
    {$IFNDEF WIN64}
    //function __union<T: record, IFlatbufferObject>(offset: Integer): T;
    {$ENDIF WIN64}

    class function __has_identifier(bb: TByteBuffer; ident: string): Boolean; static;

    {* Compare strings in the ByteBuffer. *}
    class function CompareStrings(offset_1: Integer; offset_2: Integer; bb: TByteBuffer): Integer; overload; static;
    class function CompareStrings(offset_1: Integer; key: TArray<Byte>; bb: TByteBuffer): Integer; overload; static;
  end;

implementation

uses
  System.Math;

{ TTable }

constructor TTable.Create(_i: Integer; _bb: TByteBuffer);
begin
  Fbb := _bb;
  Fbb_pos := _i;
end;

function TTable.__offset(vtableOffset: Integer): Integer;
var
  vtable: Integer;
begin
  vtable := Fbb_pos - Fbb.GetInt(Fbb_pos);
  if vtableOffset < Fbb.GetShort(vtable) then
    Result := Integer(Fbb.GetShort(vtable + vtableOffset))
  else
    Result := 0;
end;

class function TTable.__offset(vtableOffset: Integer; offset: Integer; bb: TByteBuffer): Integer;
var
  vtable: Integer;
begin
  vtable := bb.GetLength - offset;
  Result := Integer(bb.GetShort(vtable + vtableOffset - bb.GetInt(vtable))) + vtable;
end;

function TTable.__indirect(offset: Integer): Integer;
begin
  Result := offset + Fbb.GetInt(offset);
end;

class function TTable.__indirect(offset: Integer; bb: TByteBuffer): Integer;
begin
  Result := offset + bb.GetInt(offset);
end;

function TTable.__string(offset: Integer): string;
var
  stringOffset: Integer;
  len: Integer;
  startPos: Integer;
begin
  stringOffset := Fbb.GetInt(offset);
  if stringOffset = 0 then
  begin
    Result := '';
    Exit;
  end;

  offset := offset + stringOffset;
  len := Fbb.GetInt(offset);
  startPos := offset + SizeOf(Integer);
  Result := Fbb.GetStringUTF8(startPos, len);
end;

function TTable.__vector_len(offset: Integer): Integer;
begin
  offset := offset + Fbb_pos;
  offset := offset + Fbb.GetInt(offset);
  Result := Fbb.GetInt(offset);
end;

function TTable.__vector(offset: Integer): Integer;
begin
  offset := offset + Fbb_pos;
  Result := offset + Fbb.GetInt(offset) + SizeOf(Integer);  // data starts after the length
end;

function TTable.__vector_as_array<T>(offset: Integer): TArray<T>;
var
  o: Integer;
  pos: Integer;
  len: Integer;
begin
  // Note: Delphi doesn't have BitConverter.IsLittleEndian, but Windows is little-endian
  // For cross-platform, you might need to add a helper function

  o := Self.__offset(offset);
  if o = 0 then
  begin
    Result := nil;
    Exit;
  end;

  pos := Self.__vector(o);
  len := Self.__vector_len(o);
  Result := Fbb.ToArray<T>(pos, len);
end;

{$IFNDEF WIN64}
(*function TTable.__union<T>(offset: Integer): T;
var
//  t: T;
  obj: IFlatbufferObject;
begin
  // Note: This requires T to implement IFlatbufferObject
  // In Delphi, we need to use constraints or interfaces
  // This is a simplified version - actual implementation may need adjustment
  obj := Default(T);// as IFlatbufferObject;
  if Assigned(obj) then
  begin
    obj.__init(__indirect(offset), Fbb);
    Result := T(obj);
  end
  else
    Result := Default(T);
end; *)
{$ENDIF WIN64}

class function TTable.__has_identifier(bb: TByteBuffer; ident: string): Boolean;
var
  i: Integer;
begin
  if Length(ident) <> TFlatBufferConstants.FileIdentifierLength then
    raise EArgumentException.Create('FlatBuffers: file identifier must be length ' + IntToStr(TFlatBufferConstants.FileIdentifierLength));

  for i := 0 to TFlatBufferConstants.FileIdentifierLength - 1 do
  begin
    if ident[i + 1] <> Chr(bb.Get(bb.Position + SizeOf(Integer) + i)) then
    begin
      Result := False;
      Exit;
    end;
  end;

  Result := True;
end;

class function TTable.CompareStrings(offset_1: Integer; offset_2: Integer; bb: TByteBuffer): Integer;
var
  len_1, len_2: Integer;
  startPos_1, startPos_2: Integer;
  len: Integer;
  i: Integer;
  b1, b2: Byte;
begin
  offset_1 := offset_1 + bb.GetInt(offset_1);
  offset_2 := offset_2 + bb.GetInt(offset_2);
  len_1 := bb.GetInt(offset_1);
  len_2 := bb.GetInt(offset_2);
  startPos_1 := offset_1 + SizeOf(Integer);
  startPos_2 := offset_2 + SizeOf(Integer);

  len := Min(len_1, len_2);
  for i := 0 to len - 1 do
  begin
    b1 := bb.Get(i + startPos_1);
    b2 := bb.Get(i + startPos_2);
    if b1 <> b2 then
    begin
      Result := b1 - b2;
      Exit;
    end;
  end;
  Result := len_1 - len_2;
end;

class function TTable.CompareStrings(offset_1: Integer; key: TArray<Byte>; bb: TByteBuffer): Integer;
var
  len_1, len_2: Integer;
  startPos_1: Integer;
  len: Integer;
  i: Integer;
  b: Byte;
begin
  offset_1 := offset_1 + bb.GetInt(offset_1);
  len_1 := bb.GetInt(offset_1);
  len_2 := Length(key);
  startPos_1 := offset_1 + SizeOf(Integer);

  len := Min(len_1, len_2);
  for i := 0 to len - 1 do
  begin
    b := bb.Get(i + startPos_1);
    if b <> key[i] then
    begin
      Result := b - key[i];
      Exit;
    end;
  end;
  Result := len_1 - len_2;
end;

end.
