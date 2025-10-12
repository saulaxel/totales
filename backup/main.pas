unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, IniFiles;

function FormatoMoneda(Monto: Currency): string;

type
  TPanelCuenta = class(TPanel)
  public
    LabelCuenta: TLabel;
    BtnEliminar: TButton;
    EditExpresion: TEdit;
    LabelValoresSimplificados: TLabel;
    constructor Create(AOwner: TComponent; const Nombre: string; OnDelete: TNotifyEvent); reintroduce;
  end;

  { TFormPrincipal }

  TFormPrincipal = class(TForm)
    BtnAgregarCuenta: TButton;
    BtnCalcularNuevoTotal: TButton;
    MemoResultados: TMemo;
    PanelResultados: TPanel;
    PanelAcciones: TPanel;
    ScrollBoxCuentas: TScrollBox;
    procedure BtnAgregarCuentaClick(Sender: TObject);
    procedure BtnCalcularNuevoTotalClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ScrollBoxCuentasResize(Sender: TObject);
  private
    FIniFile: TIniFile;
    procedure AgregarCuenta(const Nombre: string = ''; const Valores: string = '');
    procedure EditValoresRedimensionar;
    procedure CalcularTotales;
    procedure EditValoresOnChange(Sender: TObject);
    procedure EliminarCuenta(Sender: TObject);
    procedure GuardarCuentas;
    procedure CargarCuentas;
  end;

var
  FormPrincipal: TFormPrincipal;
  TamFuente: Integer;

implementation

{$R *.lfm}

function FormatoMoneda(Monto: Currency): string;
begin
  Result := FormatCurr('$#,##0.00', Monto);
end;

{ TPanelCuenta }

constructor TPanelCuenta.Create(AOwner: TComponent; const Nombre: string; OnDelete: TNotifyEvent);
begin
  inherited Create(AOwner);
  TamFuente := FormPrincipal.Font.Size;

  Self.BevelOuter := bvNone;
  Self.Height := TamFuente * 7;
  Self.Align := alTop;
  Self.Caption := '';

  LabelCuenta := TLabel.Create(Self);
  LabelCuenta.Parent := Self;
  LabelCuenta.Caption := Nombre;
  LabelCuenta.Left := TamFuente;
  LabelCuenta.Top := TamFuente;

  BtnEliminar := TButton.Create(Self);
  BtnEliminar.Parent := Self;
  BtnEliminar.Caption := 'X';
  BtnEliminar.Width := TamFuente * 3;
  BtnEliminar.Top := TamFuente;
  BtnEliminar.Height := TamFuente * 2;
  BtnEliminar.Left := LabelCuenta.Left + LabelCuenta.Width + TamFuente;
  BtnEliminar.Anchors := [akTop, akLeft];
  BtnEliminar.OnClick := OnDelete;

  EditExpresion := TEdit.Create(Self);
  EditExpresion.Parent := Self;
  EditExpresion.Left := TamFuente;
  EditExpresion.Top := TamFuente * 3;
  EditExpresion.Anchors := [akLeft, akTop, akRight];

  LabelValoresSimplificados := TLabel.Create(Self);
  LabelValoresSimplificados.Parent := Self;
  LabelValoresSimplificados.Caption := '';
  LabelValoresSimplificados.Left := TamFuente;
  LabelValoresSimplificados.Top := TamFuente * 5;
end;

{ TFormPrincipal }

procedure TFormPrincipal.FormCreate(Sender: TObject);
begin
  TamFuente := FormPrincipal.Font.Size;
  PanelAcciones.Height := TamFuente * 3;
  PanelResultados.Height := TamFuente * 12;

  // Archivo de configuración
  FIniFile := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'cuentas.ini');
  CargarCuentas;
end;

procedure TFormPrincipal.FormDestroy(Sender: TObject);
begin
  GuardarCuentas;
  FreeAndNil(FIniFile);
end;

procedure TFormPrincipal.AgregarCuenta(const Nombre: string; const Valores: string);
var
  NuevaCuenta: TPanelCuenta;
  Etiqueta: string;
begin

  if Nombre = '' then
    Etiqueta := 'Nueva cuenta ' + IntToStr(ScrollBoxCuentas.ControlCount + 1)
  else
    Etiqueta := Nombre;

  NuevaCuenta := TPanelCuenta.Create(ScrollBoxCuentas, Etiqueta, @EliminarCuenta);
  NuevaCuenta.Parent := ScrollBoxCuentas;
  NuevaCuenta.Top := ScrollBoxCuentas.ControlCount * (7 * TamFuente);
  EditValoresRedimensionar;

  NuevaCuenta.EditExpresion.OnChange := @EditValoresOnChange;

  if Valores <> '' then
    NuevaCuenta.EditExpresion.Text := Valores;

  CalcularTotales;
end;

procedure TFormPrincipal.EliminarCuenta(Sender: TObject);
var
  Boton: TButton;
  Panel: TPanelCuenta;
begin
  if Sender is TButton then
  begin
    Boton := TButton(Sender);
    Panel := TPanelCuenta(Boton.Parent);
    Panel.Free;
    CalcularTotales;
  end;
end;

procedure TFormPrincipal.ScrollBoxCuentasResize(Sender: TObject);
begin
  EditValoresRedimensionar;
end;

procedure TFormPrincipal.EditValoresRedimensionar;
var
  i: Integer;
  Cuenta: TPanelCuenta;
begin
  for i := 0 to ScrollBoxCuentas.ControlCount - 1 do
  begin
    if ScrollBoxCuentas.Controls[i] is TPanelCuenta then
    begin
      Cuenta := TPanelCuenta(ScrollBoxCuentas.Controls[i]);
      Cuenta.EditExpresion.Width := Cuenta.ClientWidth - TamFuente * 2;
      Cuenta.BtnEliminar.Left := Cuenta.LabelCuenta.Left + Cuenta.LabelCuenta.Width + TamFuente;
    end;
  end;
end;

procedure TFormPrincipal.CalcularTotales;
var
  i, v: Integer;
  PanelCuenta: TPanelCuenta;
  valores: TStringList;
  ValoresSimplificados: string;
  subtotal, total: Currency;
begin
  total := 0;
  MemoResultados.Clear;
  ValoresSimplificados := '';

  for i := 0 to ScrollBoxCuentas.ControlCount - 1 do
  begin
    if ScrollBoxCuentas.Controls[i] is TPanelCuenta then
    begin
      PanelCuenta := TPanelCuenta(ScrollBoxCuentas.Controls[i]);
      subtotal := 0;
      valores := TStringList.Create;
      try
        valores.Delimiter := ' ';
        valores.StrictDelimiter := True;
        valores.DelimitedText := PanelCuenta.EditExpresion.Text;

        for v := 0 to valores.Count - 1 do
        begin
          subtotal += StrToCurrDef(valores[v], 0);
        end;

        ValoresSimplificados := valores.DelimitedText;
        PanelCuenta.LabelValoresSimplificados.Caption := ValoresSimplificados;

      finally
        valores.Free;
      end;

      total += subtotal;
      MemoResultados.Lines.Add(PanelCuenta.LabelCuenta.Caption + ': ' + FormatoMoneda(subtotal));
    end;
  end;
  MemoResultados.Lines.Add('-----------------------');
  MemoResultados.Lines.Add('Total: ' + FormatoMoneda(total));
end;

procedure TFormPrincipal.BtnAgregarCuentaClick(Sender: TObject);
begin
  AgregarCuenta('');
end;

procedure TFormPrincipal.BtnCalcularNuevoTotalClick(Sender: TObject);
var
  i: Integer;
  PanelCuenta: TPanelCuenta;
begin
  for i := 0 to ScrollBoxCuentas.ControlCount - 1 do
    begin
      if ScrollBoxCuentas.Controls[i] is TPanelCuenta then
      begin
        PanelCuenta := TPanelCuenta(ScrollBoxCuentas.Controls[i]);
        PanelCuenta.EditExpresion.Text := '';
      end;
    end;
  CalcularTotales;
end;

procedure TFormPrincipal.EditValoresOnChange(Sender: TObject);
begin
  CalcularTotales;
end;

procedure TFormPrincipal.GuardarCuentas;
var
  i: Integer;
  PanelCuenta: TPanelCuenta;
begin
  FIniFile.EraseSection('Cuentas');

  for i := 0 to ScrollBoxCuentas.ControlCount - 1 do
  begin
    if ScrollBoxCuentas.Controls[i] is TPanelCuenta then
    begin
      PanelCuenta := TPanelCuenta(ScrollBoxCuentas.Controls[i]);
      FIniFile.WriteString('Cuenta' + IntToStr(i), 'Nombre', PanelCuenta.LabelCuenta.Caption);
    end;
  end;
end;

procedure TFormPrincipal.CargarCuentas;
var
  i, cant: Integer;
  Nombre: String;
begin
  cant := FIniFile.ReadInteger('Cuentas', 'Cantidad', 0);
  if cant = 0 then
  begin
    // Cuentas por defecto
    AgregarCuenta('Papelería');
    AgregarCuenta('Internet');
  end
  else
  begin
    for i := 0 to cant - 1 do
    begin
      Nombre := FIniFile.ReadString('Cuenta' + IntToStr(i), 'Nombre', 'Cuenta ' + IntToStr(i + 1));
      AgregarCuenta(Nombre);
    end;
  end;
end;


end.

