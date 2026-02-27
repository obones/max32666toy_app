unit E14ToyForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Layouts, FMX.Controls.Presentation, FMX.Objects, FMX.Colors, FMX.Edit,
  ComPort;

type
  TfrmE14Toy = class(TForm)
    Header: TToolBar;
    Footer: TToolBar;
    HeaderLabel: TLabel;
    GridPanelLayout1: TGridPanelLayout;
    Rectangle1: TRectangle;
    cmbNextColor: TComboColorBox;
    Rectangle2: TRectangle;
    Rectangle3: TRectangle;
    Rectangle4: TRectangle;
    Rectangle5: TRectangle;
    Rectangle6: TRectangle;
    Rectangle7: TRectangle;
    Rectangle8: TRectangle;
    Rectangle9: TRectangle;
    Rectangle10: TRectangle;
    Rectangle11: TRectangle;
    Rectangle12: TRectangle;
    Rectangle13: TRectangle;
    Rectangle14: TRectangle;
    Rectangle15: TRectangle;
    Rectangle16: TRectangle;
    Rectangle17: TRectangle;
    Rectangle18: TRectangle;
    Rectangle19: TRectangle;
    Rectangle20: TRectangle;
    Rectangle21: TRectangle;
    Rectangle22: TRectangle;
    Rectangle23: TRectangle;
    Rectangle24: TRectangle;
    Rectangle25: TRectangle;
    Rectangle26: TRectangle;
    Rectangle27: TRectangle;
    Rectangle28: TRectangle;
    Rectangle29: TRectangle;
    Rectangle30: TRectangle;
    Rectangle31: TRectangle;
    Rectangle32: TRectangle;
    Rectangle33: TRectangle;
    Rectangle34: TRectangle;
    Rectangle35: TRectangle;
    Rectangle36: TRectangle;
    Rectangle37: TRectangle;
    Rectangle38: TRectangle;
    Rectangle39: TRectangle;
    Rectangle40: TRectangle;
    Rectangle41: TRectangle;
    Rectangle42: TRectangle;
    Rectangle43: TRectangle;
    Rectangle44: TRectangle;
    Rectangle45: TRectangle;
    Rectangle46: TRectangle;
    Rectangle47: TRectangle;
    Rectangle48: TRectangle;
    Rectangle49: TRectangle;
    Rectangle50: TRectangle;
    Rectangle51: TRectangle;
    Rectangle52: TRectangle;
    Rectangle53: TRectangle;
    Rectangle54: TRectangle;
    Rectangle55: TRectangle;
    Rectangle56: TRectangle;
    Rectangle57: TRectangle;
    Rectangle58: TRectangle;
    Rectangle59: TRectangle;
    Rectangle60: TRectangle;
    Rectangle61: TRectangle;
    Rectangle62: TRectangle;
    Rectangle63: TRectangle;
    Rectangle64: TRectangle;
    btnSend: TButton;
    edtCOMPort: TEdit;
    procedure btnSendClick(Sender: TObject);
    procedure RectangleMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
  private
    FComPort: TComPort;
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  frmE14Toy: TfrmE14Toy;

implementation

{$R *.fmx}

uses
  FlatBufferBuilder, Display, Message, MessageId;

procedure TfrmE14Toy.btnSendClick(Sender: TObject);
type
  TPixelComponent = TArray<Byte>;
begin
  var R: TPixelComponent;
  var G: TPixelComponent;
  var B: TPixelComponent;

  SetLength(R, 64);
  SetLength(G, 64);
  SetLength(B, 64);

  for var PixelIndex := 0 to 64 - 1 do
  begin
    var Rectangle := FindComponent(Format('Rectangle%d', [PixelIndex + 1])) as TRectangle;
    var Color := TAlphaColorRec(Rectangle.Fill.Color);

    R[PixelIndex] := Color.R;
    G[PixelIndex] := Color.G;
    B[PixelIndex] := Color.B;
  end;

  var builder := TFlatBufferBuilder.Create(1024);
  var display := TDisplay.CreateDisplay(builder, R, G, B);

  TMessage.StartMessage(builder);
  TMessage.AddId(builder, FullDisplay);
  TMessage.AddDisplay(builder, display);
  var messageOffset := TMessage.EndMessage(builder);
  builder.FinishSizePrefixed(messageOffset.Value);

  var buf := builder.SizedByteArray;

  FComPort.DeviceName := edtCOMPort.Text;
  FComPort.BaudRate := br115200;
  FComPort.DataBits := db8;
  FComPort.Parity := paNone;

  FComPort.Open;
  try
    FComPort.WriteBytes(buf);
    FComPort.WaitForWriteCompletion;
  finally
    FComPort.Close;
  end;
end;

constructor TfrmE14Toy.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FComPort := TComPort.Create(Self);
end;

procedure TfrmE14Toy.RectangleMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  case Button of
    TMouseButton.mbLeft:
      (Sender as TRectangle).Fill.Color := cmbNextColor.Color;
    TMouseButton.mbRight:
      (Sender as TRectangle).Fill.Color := TAlphaColors.Black;
  end;
end;

end.
