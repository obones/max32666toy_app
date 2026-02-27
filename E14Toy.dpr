program E14Toy;

uses
  System.StartUpCopy,
  FMX.Forms,
  E14ToyForm in 'E14ToyForm.pas' {frmE14Toy},
  ByteBuffer in 'FlatBuffers\ByteBuffer.pas',
  ByteBufferUtil in 'FlatBuffers\ByteBufferUtil.pas',
  FlatBufferBuilder in 'FlatBuffers\FlatBufferBuilder.pas',
  FlatBufferConstants in 'FlatBuffers\FlatBufferConstants.pas',
  FlatbufferObject in 'FlatBuffers\FlatbufferObject.pas',
  FlatBufferVerify in 'FlatBuffers\FlatBufferVerify.pas',
  Offset in 'FlatBuffers\Offset.pas',
  Struct in 'FlatBuffers\Struct.pas',
  Table in 'FlatBuffers\Table.pas',
  Display in 'Display.pas',
  Message in 'Message.pas',
  MessageId in 'MessageId.pas',
  Pixel in 'Pixel.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmE14Toy, frmE14Toy);
  Application.Run;
end.
