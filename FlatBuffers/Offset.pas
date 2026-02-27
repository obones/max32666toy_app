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

unit Offset;

interface

type
  {* Offset class for typesafe assignments. *}
  TOffset<T> = record
    Value: Integer;
    constructor Create(value: Integer);
  end;

  TStringOffset = record
    Value: Integer;
    constructor Create(value: Integer);
  end;

  TVectorOffset = record
    Value: Integer;
    constructor Create(value: Integer);
  end;

implementation

{ TOffset<T> }

constructor TOffset<T>.Create(value: Integer);
begin
  Self.Value := value;
end;

{ TStringOffset }

constructor TStringOffset.Create(value: Integer);
begin
  Self.Value := value;
end;

{ TVectorOffset }

constructor TVectorOffset.Create(value: Integer);
begin
  Self.Value := value;
end;

end.
