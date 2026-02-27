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

unit Struct;

interface

uses
  ByteBuffer;

type
  {* All structs in the generated code derive from this class, and add their own accessors. *}
  TStruct = record
  private
    Fbb_pos: Integer;
    Fbb: TByteBuffer;
  public
    // Re-init the internal state with an external buffer {@code ByteBuffer} and an offset within.
    constructor Create(_i: Integer; _bb: TByteBuffer);
    property bb_pos: Integer read Fbb_pos;
    property bb: TByteBuffer read Fbb;
  end;

implementation

{ TStruct }

constructor TStruct.Create(_i: Integer; _bb: TByteBuffer);
begin
  Fbb := _bb;
  Fbb_pos := _i;
end;

end.
