unit usbasp_hid;

{

  This file is part of
    Nephelae USBasp HID UART.

  HIDAPI Communications.

  Copyright (C) 2021 - 2022 Dimitrios Chr. Ioannidis.
    Nephelae - https://www.nephelae.eu

  https://www.nephelae.eu/

  Licensed under the MIT License (MIT).
  See licence file in root directory.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
  ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
  TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
  PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT
  SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
  ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
  OTHER DEALINGS IN THE SOFTWARE.

}

{$mode ObjFPC}

interface

uses
  Classes, SysUtils, hidapi, fgl;

type

  PUSBaspHIDDevice = ^TUSBaspHIDDevice;

  TUSBaspHIDDevice = record
    HidDevice: PHidDevice;
    index: byte;
    Path: string;
    Serial: string;
    Manufacturer: string;
    Product: string;
    FirmwareVersion: string;
    Capabilities: string;
    VendorID: word;
    ProductID: word;
    InterfaceNumber: integer;
    ReportSize: word;
    PacketCount: byte;
  end;

  TUSBaspHIDDeviceList = specialize TFPGList<PUSBaspHIDDevice>;

procedure usbasp_enumerate(const APrintInfo: boolean = False);
procedure usbasp_open(const AUSBaspHIDDevice: PUSBaspHIDDevice);
procedure usbasp_close(const AUSBaspHIDDevice: PUSBaspHIDDevice);
function usbasp_read(const AUSBaspHIDDevice: PUSBaspHIDDevice; var Data): integer;
function usbasp_write(const AUSBaspHIDDevice: PUSBaspHIDDevice; var Data): integer;
function usbasp_uart_set_conf(const AUSBaspHIDDevice: PUSBaspHIDDevice; var Data): integer;
function usbasp_uart_get_conf(const AUSBaspHIDDevice: PUSBaspHIDDevice; var Data): integer;

var
  USBaspHIDList: TUSBaspHIDDeviceList;

implementation

uses
  StrUtils;

var
  i: integer;

function enumerate_hid(AUSBaspHIDDeviceList: TUSBaspHIDDeviceList): integer;
var
  HidEnumerateList, HidItem: PHidDeviceInfo;
  USBaspHIDDevice: PUSBaspHIDDevice;
  index: byte;
begin
  try
    HidEnumerateList := THidDeviceInfo.Enumerate($16C0, $05DC);
    HidItem := HidEnumerateList;
    index := 0;
    while Assigned(HidItem) do
    begin
      New(USBaspHIDDevice);
      USBaspHIDDevice^.index:=index;
      USBaspHIDDevice^.Path := HidItem^.Path;
      USBaspHIDDevice^.Serial := PCWCharToUnicodeString(HidItem^.SerialNumber);
      USBaspHIDDevice^.Manufacturer :=
        PCWCharToUnicodeString(HidItem^.ManufacturerString);
      USBaspHIDDevice^.Product := PCWCharToUnicodeString(HidItem^.ProductString);
      USBaspHIDDevice^.InterfaceNumber := HidItem^.InterfaceNumber;
      USBaspHIDDevice^.VendorID := HidItem^.VendorID;
      USBaspHIDDevice^.ProductID := HidItem^.ProductID;
      USBaspHIDDevice^.FirmwareVersion :=
        ReverseString(ReverseString(BCDToInt(HidItem^.ReleaseNumber).ToString()).Insert(2, '.'));
      USBaspHIDDevice^.Capabilities := '';
      USBaspHIDDevice^.ReportSize := 8;
      USBaspHIDDevice^.PacketCount := 1;
      AUSBaspHIDDeviceList.Add(USBaspHIDDevice);
      HidItem := HidItem^.Next;
      Inc(Index);
    end;
  finally
    HidEnumerateList^.Free;
  end;
  Result := AUSBaspHIDDeviceList.Count;
end;

procedure PrintInfo(const AUSBaspHIDDevice: PUSBaspHIDDevice);
begin
  WriteLn();
  WriteLn('Index            : ', AUSBaspHIDDevice^.index);
  WriteLn('USB Path         : ', AUSBaspHIDDevice^.Path);
  WriteLn('Vendor           : ', AUSBaspHIDDevice^.Manufacturer);
  WriteLn('Product          : ', AUSBaspHIDDevice^.Product);
  WriteLn('Serial           : ', AUSBaspHIDDevice^.Serial);
  WriteLn('Firmware Version : ', AUSBaspHIDDevice^.FirmwareVersion);
end;

procedure usbasp_enumerate(const APrintInfo: boolean);
var
  USBasp: PUSBaspHIDDevice;
begin
  WriteLn();
  WriteLn('Enumerating USBasp HIDUART (Hid Api Library Version : ', HidApiVersion, ' )');

  if enumerate_hid(USBaspHIDList) > 0 then
  begin
    for USBasp in USBaspHIDList do
    begin
      usbasp_open(USBasp);
      usbasp_close(USBasp);
      if APrintInfo then
        PrintInfo(USBasp);
    end;
    //ReadLn();
  end
  else
    WriteLn('No USBasp HID UART found.');
end;

procedure usbasp_open(const AUSBaspHIDDevice: PUSBaspHIDDevice);
begin
  AUSBaspHIDDevice^.HidDevice := THidDevice.OpenPath(AUSBaspHIDDevice^.Path);
end;

procedure usbasp_close(const AUSBaspHIDDevice: PUSBaspHIDDevice);
begin
  AUSBaspHIDDevice^.HidDevice^.Close;
end;

function usbasp_read(const AUSBaspHIDDevice: PUSBaspHIDDevice; var Data): integer;
var
  HidBuffer: array[0..8] of byte = (0, 0, 0, 0, 0, 0, 0, 0, 0);
begin
  // Read default 0 Report ID
  Result := AUSBaspHIDDevice^.HidDevice^.ReadTimeout(HidBuffer, AUSBaspHIDDevice^.ReportSize, 250);
  Move(HidBuffer, Data, AUSBaspHIDDevice^.ReportSize);
end;

function usbasp_write(const AUSBaspHIDDevice: PUSBaspHIDDevice; var Data): integer;
var
  HidBuffer: array[0..8] of byte = (0, 0, 0, 0, 0, 0, 0, 0, 0);
begin
  // Add Report ID
  HidBuffer[0] := $00;
  Move(Data, HidBuffer[1], AUSBaspHIDDevice^.ReportSize + 1);

  // Report size plus added Report ID
  Result := AUSBaspHIDDevice^.HidDevice^.Write(HidBuffer, AUSBaspHIDDevice^.ReportSize + 1) - 1;
end;

function usbasp_uart_get_conf(const AUSBaspHIDDevice: PUSBaspHIDDevice; var Data): integer;
var
  HidBuffer: array[0..8] of byte = (0, 0, 0, 0, 0, 0, 0, 0, 0);
  HidSize: SizeInt;
begin
  // Add Report ID
  HidBuffer[0] := $00;

  // Report size plus added Report ID
  HidSize := AUSBaspHIDDevice^.HidDevice^.GetFeatureReport(HidBuffer, AUSBaspHIDDevice^.ReportSize + 1) - 1;

  Move(HidBuffer[1], Data, HidSize);

  Result := HidSize - 1;
end;

function usbasp_uart_set_conf(const AUSBaspHIDDevice: PUSBaspHIDDevice; var Data): integer;
var
  HidBuffer: array[0..8] of byte = (0, 0, 0, 0, 0, 0, 0, 0, 0);
  HidSize: SizeInt;
begin
  // Add Report ID
  HidBuffer[0] := $00;
  Move(Data, HidBuffer[1], AUSBaspHIDDevice^.ReportSize + 1);

  // Report size plus added Report ID
  HidSize := AUSBaspHIDDevice^.HidDevice^.SendFeatureReport(HidBuffer, AUSBaspHIDDevice^.ReportSize + 1);

  Move(HidBuffer[1], Data, HidSize - 1);

  Result := HidSize;
end;

initialization
  HidInit();
  USBaspHIDList := TUSBaspHIDDeviceList.Create;

finalization;
  i := USBaspHIDList.Count - 1;
  while i >= 0 do
  begin
    Dispose(USBaspHIDList[i]);
    Dec(i);
  end;
  USBaspHIDList.Free;
  HidExit();

end.
