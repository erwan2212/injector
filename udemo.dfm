object Form1: TForm1
  Left = 746
  Top = 290
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsToolWindow
  Caption = 'Injection DEMO'
  ClientHeight = 201
  ClientWidth = 425
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 24
    Top = 8
    Width = 69
    Height = 13
    Caption = 'Process Name'
  end
  object Label2: TLabel
    Left = 200
    Top = 24
    Width = 16
    Height = 13
    Caption = 'OR'
  end
  object Label3: TLabel
    Left = 240
    Top = 8
    Width = 18
    Height = 13
    Caption = 'PID'
  end
  object Button1: TButton
    Left = 24
    Top = 80
    Width = 369
    Height = 25
    Caption = 'Inject DLL'
    TabOrder = 0
    OnClick = Button1Click
  end
  object txtprocess: TEdit
    Left = 24
    Top = 24
    Width = 153
    Height = 21
    TabOrder = 1
    Text = 'explorer.exe'
  end
  object Button2: TButton
    Left = 24
    Top = 160
    Width = 121
    Height = 25
    Caption = 'Code'
    TabOrder = 2
    OnClick = Button2Click
  end
  object txtpid: TEdit
    Left = 240
    Top = 24
    Width = 153
    Height = 21
    TabOrder = 3
  end
  object RadioButton1: TRadioButton
    Left = 24
    Top = 56
    Width = 137
    Height = 17
    Caption = 'CreateRemoteThread'
    Checked = True
    TabOrder = 4
    TabStop = True
  end
  object RadioButton2: TRadioButton
    Left = 152
    Top = 56
    Width = 137
    Height = 17
    Caption = 'RtlCreateUserThread'
    TabOrder = 5
  end
  object RadioButton3: TRadioButton
    Left = 272
    Top = 56
    Width = 113
    Height = 17
    Caption = 'NtCreateThreadEx'
    TabOrder = 6
  end
  object RadioButton4: TRadioButton
    Left = 24
    Top = 144
    Width = 113
    Height = 17
    Caption = 'InjectRTL_DLL'
    TabOrder = 7
    Visible = False
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 182
    Width = 425
    Height = 19
    Panels = <>
    SimplePanel = True
  end
  object txtdll: TEdit
    Left = 24
    Top = 112
    Width = 369
    Height = 21
    TabOrder = 9
    Text = 'c:\_apps\hook.dll'
  end
  object Button3: TButton
    Left = 248
    Top = 144
    Width = 75
    Height = 25
    Caption = 'Button3'
    TabOrder = 10
  end
end
