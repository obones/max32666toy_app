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

unit FlatBufferVerify;

interface

uses
  System.SysUtils, ByteBuffer, FlatBufferConstants;

type
  {* The Class of the Verifier Options *}
  TOptions = class
  public
    const DEFAULT_MAX_DEPTH = 64;
    const DEFAULT_MAX_TABLES = 1000000;
  private
    FMaxDepth: Integer;
    FMaxTables: Integer;
    FStringEndCheck: Boolean;
    FAlignmentCheck: Boolean;
  public
    constructor Create; overload;
    constructor Create(maxDepth: Integer; maxTables: Integer; stringEndCheck: Boolean; alignmentCheck: Boolean); overload;
    property MaxDepth: Integer read FMaxDepth write FMaxDepth;
    property MaxTables: Integer read FMaxTables write FMaxTables;
    property StringEndCheck: Boolean read FStringEndCheck write FStringEndCheck;
    property AlignmentCheck: Boolean read FAlignmentCheck write FAlignmentCheck;
  end;

  TCheckElementStruct = record
    ElementValid: Boolean;
    ElementOffset: Cardinal;
  end;

  TVerifier = class;

  TVerifyTableAction = function(verifier: TVerifier; tablePos: Cardinal): Boolean;
  TVerifyUnionAction = function(verifier: TObject; typeId: Byte; tablePos: Cardinal): Boolean;

  {* The Main Class of the FlatBuffer Verifier *}
  TVerifier = class
  private
    FVerifierBuffer: TByteBuffer;
    FVerifierOptions: TOptions;
    FDepthCnt: Integer;
    FNumTablesCnt: Integer;

    const SIZE_BYTE = 1;
    const SIZE_INT = 4;
    const SIZE_U_OFFSET = 4;
    const SIZE_S_OFFSET = 4;
    const SIZE_V_OFFSET = 2;
    const SIZE_PREFIX_LENGTH = TFlatBufferConstants.SizePrefixLength;
    const FLATBUFFERS_MAX_BUFFER_SIZE: UInt64 = MaxInt;
    const FILE_IDENTIFIER_LENGTH = TFlatBufferConstants.FileIdentifierLength;

    function BufferHasIdentifier(buf: TByteBuffer; startPos: Cardinal; const identifier: string): Boolean;
    function ReadUOffsetT(buf: TByteBuffer; pos: Cardinal): Cardinal;
    function ReadSOffsetT(buf: TByteBuffer; pos: Integer): Integer;
    function ReadVOffsetT(buf: TByteBuffer; pos: Integer): SmallInt;
    function GetVRelOffset(pos: Integer; vtableOffset: SmallInt): SmallInt;
    function GetVOffset(tablePos: Cardinal; vtableOffset: SmallInt): Cardinal;
    function CheckComplexity: Boolean;
    function CheckAlignment(element: Cardinal; align: UInt64): Boolean;
    function CheckElement(pos: Cardinal; elementSize: UInt64): Boolean;
    function CheckScalar(pos: Cardinal; elementSize: UInt64): Boolean;
//    function CheckOffset(offset: Cardinal): Boolean;
    function CheckVectorOrString(pos: Cardinal; elementSize: UInt64): TCheckElementStruct;
    function CheckString(pos: Cardinal): Boolean;
    function CheckVector(pos: Cardinal; elementSize: UInt64): Boolean;
    function CheckTable(tablePos: Cardinal; verifyAction: TVerifyTableAction): Boolean;
//    function CheckStringFunc(verifier: TObject; pos: Cardinal): Boolean;
    function CheckVectorOfObjects(pos: Cardinal; verifyAction: TVerifyTableAction): Boolean;
    function CheckIndirectOffset(pos: Cardinal): Boolean;
    function CheckBufferFromStart(const identifier: string; startPos: Cardinal; verifyAction: TVerifyTableAction): Boolean;
    function GetIndirectOffset(pos: Cardinal): Cardinal;
  public
    constructor Create; overload;
    constructor Create(buf: TByteBuffer; options: TOptions = nil); overload;
    destructor Destroy; override;

    property Buf: TByteBuffer read FVerifierBuffer write FVerifierBuffer;
    property Options: TOptions read FVerifierOptions write FVerifierOptions;
    property Depth: Integer read FDepthCnt write FDepthCnt;
    property NumTables: Integer read FNumTablesCnt write FNumTablesCnt;

    function SetMaxDepth(value: Integer): TVerifier;
    function SetMaxTables(value: Integer): TVerifier;
    function SetAlignmentCheck(value: Boolean): TVerifier;
    function SetStringCheck(value: Boolean): TVerifier;

    function VerifyTableStart(tablePos: Cardinal): Boolean;
    function VerifyTableEnd(tablePos: Cardinal): Boolean;
    function VerifyField(tablePos: Cardinal; offsetId: SmallInt; elementSize: UInt64; align: UInt64; required: Boolean): Boolean;
    function VerifyString(tablePos: Cardinal; vOffset: SmallInt; required: Boolean): Boolean;
    function VerifyVectorOfData(tablePos: Cardinal; vOffset: SmallInt; elementSize: UInt64; required: Boolean): Boolean;
    function VerifyVectorOfStrings(tablePos: Cardinal; offsetId: SmallInt; required: Boolean): Boolean;
    function VerifyVectorOfTables(tablePos: Cardinal; offsetId: SmallInt; verifyAction: TVerifyTableAction; required: Boolean): Boolean;
    function VerifyTable(tablePos: Cardinal; offsetId: SmallInt; verifyAction: TVerifyTableAction; required: Boolean): Boolean;
    function VerifyNestedBuffer(tablePos: Cardinal; offsetId: SmallInt; verifyAction: TVerifyTableAction; required: Boolean): Boolean;
    function VerifyUnionData(pos: Cardinal; elementSize: UInt64; align: UInt64): Boolean;
    function VerifyUnionString(pos: Cardinal): Boolean;
    function VerifyUnion(tablePos: Cardinal; typeIdVOffset: SmallInt; valueVOffset: SmallInt; verifyAction: TVerifyUnionAction; required: Boolean): Boolean;
    function VerifyVectorOfUnion(tablePos: Cardinal; typeOffsetId: SmallInt; offsetId: SmallInt; verifyAction: TVerifyUnionAction; required: Boolean): Boolean;
    function VerifyBuffer(const identifier: string; sizePrefixed: Boolean; verifyAction: TVerifyTableAction): Boolean;
  end;

implementation

uses
  System.Classes;

{ TOptions }

constructor TOptions.Create;
begin
  inherited;
  FMaxDepth := DEFAULT_MAX_DEPTH;
  FMaxTables := DEFAULT_MAX_TABLES;
  FStringEndCheck := True;
  FAlignmentCheck := True;
end;

constructor TOptions.Create(maxDepth: Integer; maxTables: Integer; stringEndCheck: Boolean; alignmentCheck: Boolean);
begin
  inherited Create;
  FMaxDepth := maxDepth;
  FMaxTables := maxTables;
  FStringEndCheck := stringEndCheck;
  FAlignmentCheck := alignmentCheck;
end;

{ TVerifier }

constructor TVerifier.Create;
begin
  inherited;
  FVerifierBuffer := nil;
  FVerifierOptions := nil;
  FDepthCnt := 0;
  FNumTablesCnt := 0;
end;

constructor TVerifier.Create(buf: TByteBuffer; options: TOptions);
begin
  inherited Create;
  FVerifierBuffer := buf;
  if Assigned(options) then
    FVerifierOptions := options
  else
    FVerifierOptions := TOptions.Create;
  FDepthCnt := 0;
  FNumTablesCnt := 0;
end;

destructor TVerifier.Destroy;
begin
  if Assigned(FVerifierOptions) then
    FVerifierOptions.Free;
  inherited;
end;

function TVerifier.SetMaxDepth(value: Integer): TVerifier;
begin
  FVerifierOptions.MaxDepth := value;
  Result := Self;
end;

function TVerifier.SetMaxTables(value: Integer): TVerifier;
begin
  FVerifierOptions.MaxTables := value;
  Result := Self;
end;

function TVerifier.SetAlignmentCheck(value: Boolean): TVerifier;
begin
  FVerifierOptions.AlignmentCheck := value;
  Result := Self;
end;

function TVerifier.SetStringCheck(value: Boolean): TVerifier;
begin
  FVerifierOptions.StringEndCheck := value;
  Result := Self;
end;

function TVerifier.BufferHasIdentifier(buf: TByteBuffer; startPos: Cardinal; const identifier: string): Boolean;
var
  i: Integer;
begin
  if Length(identifier) <> FILE_IDENTIFIER_LENGTH then
    raise EArgumentException.Create('FlatBuffers: file identifier must be length' + IntToStr(FILE_IDENTIFIER_LENGTH));
  for i := 0 to FILE_IDENTIFIER_LENGTH - 1 do
  begin
    if ShortInt(identifier[i + 1]) <> FVerifierBuffer.GetSbyte(Integer(SIZE_S_OFFSET + i + Integer(startPos))) then
    begin
      Result := False;
      Exit;
    end;
  end;
  Result := True;
end;

function TVerifier.ReadUOffsetT(buf: TByteBuffer; pos: Cardinal): Cardinal;
begin
  Result := buf.GetUint(Integer(pos));
end;

function TVerifier.ReadSOffsetT(buf: TByteBuffer; pos: Integer): Integer;
begin
  Result := buf.GetInt(pos);
end;

function TVerifier.ReadVOffsetT(buf: TByteBuffer; pos: Integer): SmallInt;
begin
  Result := buf.GetShort(pos);
end;

function TVerifier.GetVRelOffset(pos: Integer; vtableOffset: SmallInt): SmallInt;
var
  vtable: SmallInt;
begin
  try
    vtable := SmallInt(pos - ReadSOffsetT(FVerifierBuffer, pos));
    if vtableOffset < ReadVOffsetT(FVerifierBuffer, vtable) then
      Result := ReadVOffsetT(FVerifierBuffer, vtable + vtableOffset)
    else
      Result := 0;
  except
    Result := 0;
  end;
end;

function TVerifier.GetVOffset(tablePos: Cardinal; vtableOffset: SmallInt): Cardinal;
var
  relPos: SmallInt;
begin
  relPos := GetVRelOffset(Integer(tablePos), vtableOffset);
  if relPos <> 0 then
    Result := tablePos + Cardinal(relPos)
  else
    Result := 0;
end;

function TVerifier.CheckComplexity: Boolean;
begin
  Result := (FDepthCnt <= FVerifierOptions.MaxDepth) and (FNumTablesCnt <= FVerifierOptions.MaxTables);
end;

function TVerifier.CheckAlignment(element: Cardinal; align: UInt64): Boolean;
begin
  Result := ((element and (align - 1)) = 0) or (not FVerifierOptions.AlignmentCheck);
end;

function TVerifier.CheckElement(pos: Cardinal; elementSize: UInt64): Boolean;
begin
  Result := (elementSize < UInt64(FVerifierBuffer.GetLength)) and
            (pos <= (Cardinal(FVerifierBuffer.GetLength) - elementSize));
end;

function TVerifier.CheckScalar(pos: Cardinal; elementSize: UInt64): Boolean;
begin
  Result := CheckAlignment(pos, elementSize) and CheckElement(pos, elementSize);
end;

(*function TVerifier.CheckOffset(offset: Cardinal): Boolean;
begin
  Result := CheckScalar(offset, SIZE_U_OFFSET);
end;*)

function TVerifier.CheckVectorOrString(pos: Cardinal; elementSize: UInt64): TCheckElementStruct;
var
  vectorPos: Cardinal;
  size: Cardinal;
  max_elements: UInt64;
  bytes_size: Cardinal;
  buffer_end_pos: Cardinal;
begin
  Result.ElementValid := False;
  Result.ElementOffset := 0;

  vectorPos := pos;
  if not CheckScalar(vectorPos, SIZE_U_OFFSET) then
    Exit;

  size := ReadUOffsetT(FVerifierBuffer, vectorPos);
  max_elements := FLATBUFFERS_MAX_BUFFER_SIZE div elementSize;
  if size >= max_elements then
    Exit;

  bytes_size := SIZE_U_OFFSET + (Cardinal(elementSize) * size);
  buffer_end_pos := vectorPos + bytes_size;
  Result.ElementValid := CheckElement(vectorPos, bytes_size);
  Result.ElementOffset := buffer_end_pos;
end;

function TVerifier.CheckString(pos: Cardinal): Boolean;
var
  checkResult: TCheckElementStruct;
begin
  checkResult := CheckVectorOrString(pos, SIZE_BYTE);
  if FVerifierOptions.StringEndCheck then
  begin
    checkResult.ElementValid := checkResult.ElementValid and CheckScalar(checkResult.ElementOffset, 1);
    checkResult.ElementValid := checkResult.ElementValid and (FVerifierBuffer.GetSbyte(Integer(checkResult.ElementOffset)) = 0);
  end;
  Result := checkResult.ElementValid;
end;

function TVerifier.CheckVector(pos: Cardinal; elementSize: UInt64): Boolean;
var
  checkResult: TCheckElementStruct;
begin
  checkResult := CheckVectorOrString(pos, elementSize);
  Result := checkResult.ElementValid;
end;

function TVerifier.CheckTable(tablePos: Cardinal; verifyAction: TVerifyTableAction): Boolean;
begin
  Result := verifyAction(Self, tablePos);
end;

function CheckStringFunc(verifier: TVerifier; pos: Cardinal): Boolean;
begin
  Result := TVerifier(verifier).CheckString(pos);
end;

function TVerifier.CheckVectorOfObjects(pos: Cardinal; verifyAction: TVerifyTableAction): Boolean;
var
  size: Cardinal;
  vecStart: Cardinal;
  vecOff: Cardinal;
  i: Cardinal;
  objOffset: Cardinal;
begin
  if not CheckVector(pos, SIZE_U_OFFSET) then
  begin
    Result := False;
    Exit;
  end;
  size := ReadUOffsetT(FVerifierBuffer, pos);
  vecStart := pos + SIZE_U_OFFSET;
  for i := 0 to size - 1 do
  begin
    vecOff := vecStart + (i * SIZE_U_OFFSET);
    if not CheckIndirectOffset(vecOff) then
    begin
      Result := False;
      Exit;
    end;
    objOffset := GetIndirectOffset(vecOff);
    if not verifyAction(Self, objOffset) then
    begin
      Result := False;
      Exit;
    end;
  end;
  Result := True;
end;

function TVerifier.CheckIndirectOffset(pos: Cardinal): Boolean;
var
  offset: Cardinal;
begin
  if not CheckScalar(pos, SIZE_U_OFFSET) then
  begin
    Result := False;
    Exit;
  end;
  offset := ReadUOffsetT(FVerifierBuffer, pos);
  if (offset = 0) or (offset >= FLATBUFFERS_MAX_BUFFER_SIZE) then
  begin
    Result := False;
    Exit;
  end;
  Result := CheckElement(pos + offset, 1);
end;

function TVerifier.CheckBufferFromStart(const identifier: string; startPos: Cardinal; verifyAction: TVerifyTableAction): Boolean;
var
  offset: Cardinal;
begin
  if (identifier <> '') and (Length(identifier) = 0) and
     ((FVerifierBuffer.GetLength < (SIZE_U_OFFSET + FILE_IDENTIFIER_LENGTH)) or
      (not BufferHasIdentifier(FVerifierBuffer, startPos, identifier))) then
  begin
    Result := False;
    Exit;
  end;
  if not CheckIndirectOffset(startPos) then
  begin
    Result := False;
    Exit;
  end;
  offset := GetIndirectOffset(startPos);
  Result := CheckTable(offset, verifyAction);
end;

function TVerifier.GetIndirectOffset(pos: Cardinal): Cardinal;
begin
  Result := pos + ReadUOffsetT(FVerifierBuffer, pos);
end;

function TVerifier.VerifyTableStart(tablePos: Cardinal): Boolean;
var
  vtable: Cardinal;
begin
  Inc(FDepthCnt);
  Inc(FNumTablesCnt);

  if not CheckScalar(tablePos, SIZE_S_OFFSET) then
  begin
    Result := False;
    Exit;
  end;
  vtable := Cardinal(Integer(tablePos) - ReadSOffsetT(FVerifierBuffer, Integer(tablePos)));
  Result := CheckComplexity and
            CheckScalar(vtable, SIZE_V_OFFSET) and
            CheckAlignment(Cardinal(ReadVOffsetT(FVerifierBuffer, Integer(vtable))), SIZE_V_OFFSET) and
            CheckElement(vtable, UInt64(ReadVOffsetT(FVerifierBuffer, Integer(vtable))));
end;

function TVerifier.VerifyTableEnd(tablePos: Cardinal): Boolean;
begin
  Dec(FDepthCnt);
  Result := True;
end;

function TVerifier.VerifyField(tablePos: Cardinal; offsetId: SmallInt; elementSize: UInt64; align: UInt64; required: Boolean): Boolean;
var
  offset: Cardinal;
begin
  offset := GetVOffset(tablePos, offsetId);
  if offset <> 0 then
    Result := CheckAlignment(offset, align) and CheckElement(offset, elementSize)
  else
    Result := not required;
end;

function TVerifier.VerifyString(tablePos: Cardinal; vOffset: SmallInt; required: Boolean): Boolean;
var
  offset: Cardinal;
  strOffset: Cardinal;
begin
  offset := GetVOffset(tablePos, vOffset);
  if offset = 0 then
  begin
    Result := not required;
    Exit;
  end;
  if not CheckIndirectOffset(offset) then
  begin
    Result := False;
    Exit;
  end;
  strOffset := GetIndirectOffset(offset);
  Result := CheckString(strOffset);
end;

function TVerifier.VerifyVectorOfData(tablePos: Cardinal; vOffset: SmallInt; elementSize: UInt64; required: Boolean): Boolean;
var
  offset: Cardinal;
  vecOffset: Cardinal;
begin
  offset := GetVOffset(tablePos, vOffset);
  if offset = 0 then
  begin
    Result := not required;
    Exit;
  end;
  if not CheckIndirectOffset(offset) then
  begin
    Result := False;
    Exit;
  end;
  vecOffset := GetIndirectOffset(offset);
  Result := CheckVector(vecOffset, elementSize);
end;

function TVerifier.VerifyVectorOfStrings(tablePos: Cardinal; offsetId: SmallInt; required: Boolean): Boolean;
var
  offset: Cardinal;
  vecOffset: Cardinal;
begin
  offset := GetVOffset(tablePos, offsetId);
  if offset = 0 then
  begin
    Result := not required;
    Exit;
  end;
  if not CheckIndirectOffset(offset) then
  begin
    Result := False;
    Exit;
  end;
  vecOffset := GetIndirectOffset(offset);
  Result := CheckVectorOfObjects(vecOffset, CheckStringFunc);
end;

function TVerifier.VerifyVectorOfTables(tablePos: Cardinal; offsetId: SmallInt; verifyAction: TVerifyTableAction; required: Boolean): Boolean;
var
  offset: Cardinal;
  vecOffset: Cardinal;
begin
  offset := GetVOffset(tablePos, offsetId);
  if offset = 0 then
  begin
    Result := not required;
    Exit;
  end;
  if not CheckIndirectOffset(offset) then
  begin
    Result := False;
    Exit;
  end;
  vecOffset := GetIndirectOffset(offset);
  Result := CheckVectorOfObjects(vecOffset, verifyAction);
end;

function TVerifier.VerifyTable(tablePos: Cardinal; offsetId: SmallInt; verifyAction: TVerifyTableAction; required: Boolean): Boolean;
var
  offset: Cardinal;
  tabOffset: Cardinal;
begin
  offset := GetVOffset(tablePos, offsetId);
  if offset = 0 then
  begin
    Result := not required;
    Exit;
  end;
  if not CheckIndirectOffset(offset) then
  begin
    Result := False;
    Exit;
  end;
  tabOffset := GetIndirectOffset(offset);
  Result := CheckTable(tabOffset, verifyAction);
end;

function TVerifier.VerifyNestedBuffer(tablePos: Cardinal; offsetId: SmallInt; verifyAction: TVerifyTableAction; required: Boolean): Boolean;
var
  offset: Cardinal;
  vecOffset: Cardinal;
  vecLength: Cardinal;
  vecStart: Cardinal;
  nestedByteBuffer: TByteBuffer;
  nestedVerifier: TVerifier;
begin
  offset := GetVOffset(tablePos, offsetId);
  if offset = 0 then
  begin
    Result := not required;
    Exit;
  end;
  vecOffset := GetIndirectOffset(offset);
  if not CheckVector(vecOffset, SIZE_BYTE) then
  begin
    Result := False;
    Exit;
  end;
  if Assigned(verifyAction) then
  begin
    vecLength := ReadUOffsetT(FVerifierBuffer, vecOffset);
    vecStart := vecOffset + SIZE_U_OFFSET;
    nestedByteBuffer := TByteBuffer.Create(FVerifierBuffer.ToArray(Integer(vecStart), Integer(vecLength)));
    nestedVerifier := TVerifier.Create(nestedByteBuffer, FVerifierOptions);
    try
      if not nestedVerifier.CheckBufferFromStart('', 0, verifyAction) then
      begin
        Result := False;
        Exit;
      end;
    finally
      nestedVerifier.Free;
      nestedByteBuffer.Free;
    end;
  end;
  Result := True;
end;

function TVerifier.VerifyUnionData(pos: Cardinal; elementSize: UInt64; align: UInt64): Boolean;
begin
  Result := CheckAlignment(pos, align) and CheckElement(pos, elementSize);
end;

function TVerifier.VerifyUnionString(pos: Cardinal): Boolean;
begin
  Result := CheckString(pos);
end;

function TVerifier.VerifyUnion(tablePos: Cardinal; typeIdVOffset: SmallInt; valueVOffset: SmallInt; verifyAction: TVerifyUnionAction; required: Boolean): Boolean;
var
  offset: Cardinal;
  typeId: Byte;
  unionOffset: Cardinal;
begin
  offset := GetVOffset(tablePos, typeIdVOffset);
  if offset = 0 then
  begin
    Result := not required;
    Exit;
  end;
  if not (CheckAlignment(offset, SIZE_BYTE) and CheckElement(offset, SIZE_BYTE)) then
  begin
    Result := False;
    Exit;
  end;
  typeId := FVerifierBuffer.Get(Integer(offset));
  offset := GetVOffset(tablePos, valueVOffset);
  if offset = 0 then
  begin
    Result := verifyAction(Self, typeId, Cardinal(FVerifierBuffer.GetLength));
    Exit;
  end;
  if not CheckIndirectOffset(offset) then
  begin
    Result := False;
    Exit;
  end;
  unionOffset := GetIndirectOffset(offset);
  Result := verifyAction(Self, typeId, unionOffset);
end;

function TVerifier.VerifyVectorOfUnion(tablePos: Cardinal; typeOffsetId: SmallInt; offsetId: SmallInt; verifyAction: TVerifyUnionAction; required: Boolean): Boolean;
var
  offset: Cardinal;
  typeIdVectorOffset: Cardinal;
  valueVectorOffset: Cardinal;
  typeIdVectorLength: Cardinal;
  valueVectorLength: Cardinal;
  typeIdStart: Cardinal;
  valueStart: Cardinal;
  i: Cardinal;
  typeId: Byte;
  off: Cardinal;
  valueOffset: Cardinal;
begin
  offset := GetVOffset(tablePos, typeOffsetId);
  if offset = 0 then
  begin
    Result := not required;
    Exit;
  end;
  if not CheckIndirectOffset(offset) then
  begin
    Result := False;
    Exit;
  end;
  typeIdVectorOffset := GetIndirectOffset(offset);
  offset := GetVOffset(tablePos, offsetId);
  if not CheckIndirectOffset(offset) then
  begin
    Result := False;
    Exit;
  end;
  valueVectorOffset := GetIndirectOffset(offset);
  if not CheckVector(typeIdVectorOffset, SIZE_BYTE) or
     not CheckVector(valueVectorOffset, SIZE_U_OFFSET) then
  begin
    Result := False;
    Exit;
  end;
  typeIdVectorLength := ReadUOffsetT(FVerifierBuffer, typeIdVectorOffset);
  valueVectorLength := ReadUOffsetT(FVerifierBuffer, valueVectorOffset);
  if typeIdVectorLength <> valueVectorLength then
  begin
    Result := False;
    Exit;
  end;
  typeIdStart := typeIdVectorOffset + SIZE_U_OFFSET;
  valueStart := valueVectorOffset + SIZE_U_OFFSET;
  for i := 0 to typeIdVectorLength - 1 do
  begin
    typeId := FVerifierBuffer.Get(Integer(typeIdStart + i * SIZE_U_OFFSET));
    off := valueStart + i * SIZE_U_OFFSET;
    if not CheckIndirectOffset(off) then
    begin
      Result := False;
      Exit;
    end;
    valueOffset := GetIndirectOffset(off);
    if not verifyAction(Self, typeId, valueOffset) then
    begin
      Result := False;
      Exit;
    end;
  end;
  Result := True;
end;

function TVerifier.VerifyBuffer(const identifier: string; sizePrefixed: Boolean; verifyAction: TVerifyTableAction): Boolean;
var
  start: Cardinal;
  size: Cardinal;
begin
  FDepthCnt := 0;
  FNumTablesCnt := 0;

  start := Cardinal(FVerifierBuffer.Position);
  if sizePrefixed then
  begin
    start := Cardinal(FVerifierBuffer.Position) + SIZE_PREFIX_LENGTH;
    if not CheckScalar(Cardinal(FVerifierBuffer.Position), SIZE_PREFIX_LENGTH) then
    begin
      Result := False;
      Exit;
    end;
    size := ReadUOffsetT(FVerifierBuffer, Cardinal(FVerifierBuffer.Position));
    if size <> (Cardinal(FVerifierBuffer.GetLength) - start) then
    begin
      Result := False;
      Exit;
    end;
  end;
  Result := CheckBufferFromStart(identifier, start, verifyAction);
end;

end.
