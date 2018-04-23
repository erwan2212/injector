unit udemo;

interface

{$IMAGEBASE $13140000}

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls,uDGProcessList,injection,ntdll, ComCtrls;

type
  TForm1 = class(TForm)
    Button1: TButton;
    txtprocess: TEdit;
    txtpid: TEdit;
    RadioButton1: TRadioButton;
    RadioButton2: TRadioButton;
    RadioButton3: TRadioButton;
    StatusBar1: TStatusBar;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    txtdll: TEdit;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  ps:TDGProcessList ;

implementation

{$R *.dfm}

function enablepriv(priv:string):boolean;
var
TP, Prev: TTokenPrivileges;
  RetLength: DWORD;
  Token: THandle;
  LUID: TLargeInteger;
begin
result:=false;
try
if OpenProcessToken(GetCurrentProcess, TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, Token) then
    begin
    if LookupPrivilegeValue(nil, pchar(priv), LUID) then
    begin
    TP.PrivilegeCount := 1;
    TP.Privileges[0].Luid := LUID;
    TP.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;
    if not AdjustTokenPrivileges(Token, False, TP, SizeOf(TTokenPrivileges), Prev, RetLength) then RaiseLastWin32Error;
    result:=true;
    end;//LookupPrivilegeValue
    CloseHandle(Token);
    end;//OpenProcessToken
except
on e:exception do raise exception.Create(e.Message ); 
end;
end;

function EnableDebugPrivilege(const Value: Boolean): Boolean;
const
  SE_DEBUG_NAME = 'SeDebugPrivilege';
var
  hToken: THandle;
  tp: TOKEN_PRIVILEGES;
  d: DWORD;
begin
  Result := False;
  if OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES, hToken) then
  begin
    tp.PrivilegeCount := 1;
    LookupPrivilegeValue(nil, SE_DEBUG_NAME, tp.Privileges[0].Luid);
    if Value then
      tp.Privileges[0].Attributes := $00000002
    else
      tp.Privileges[0].Attributes := $80000000;
    AdjustTokenPrivileges(hToken, False, tp, SizeOf(TOKEN_PRIVILEGES), nil, d);
    if GetLastError = ERROR_SUCCESS then
    begin
      Result := True;
    end;
    CloseHandle(hToken);
  end;
end;



function Proc(dwEntryPoint: Pointer): longword; stdcall;
type msgbox=function(hWnd: HWND; lpText, lpCaption: PAnsiChar; uType: UINT): Integer; stdcall;
var
buffer:pchar;
p:pointer;
func:msgbox;
begin
  {now we are in notepad}
  //LoadLibraryA('kernel32.dll');
  @func:=GetProcAddress(LoadLibraryA('user32.dll'),'messageboxa');
  //p:=VirtualAlloc(buffer,8,MEM_COMMIT,PAGE_READWRITE);
  func(0,pchar('hello from remote process'),pchar('proc'),MB_OK );
  //virtualfree(p,0,MEM_RELEASE);
  Result := 0;
end;

function Proc2(dwEntryPoint: Pointer): longword; stdcall;
var hfile:thandle;
s:string;
written:cardinal;
p:pointer;
begin
  LoadLibrary('kernel32.dll');
  LoadLibrary('user32.dll');
  hFile := CreateFile(pchar('c:\test.txt'), GENERIC_WRITE, 0, nil, CREATE_ALWAYS, 0, 0);
  p:=VirtualAlloc(nil,8,MEM_COMMIT,PAGE_READWRITE);
  s:=(inttostr(GetCurrentProcessId )); //'12345678';
  CopyMemory(p,@s[1],length(s));
  WriteFile(hfile,p^,8,written,nil);
  virtualfree(p,0,MEM_RELEASE);
  CloseHandle(hfile);
  Result := 0;
end;

function Proc3(param: Pointer): longword; stdcall;
var
written:cardinal;
p:pchar;
begin
//p:=pchar(param^);
//showmessage(strpas(p));
  LoadLibrary('kernel32.dll');
  LoadLibrary('user32.dll');
  //messageboxa(0,pchar(inttostr(getcurrentprocessid)),'lpcaption',MB_OK );
  //freelibrary(loadlibrary(p));
  freelibrary(loadlibrary('hook.dll'));
  Result := 0;
end;

procedure TForm1.Button1Click(Sender: TObject);
var
ProcessHandle, PID: longword;
h:thandle;
i:integer;
oa:TObjectAttributes;
cid:CLIENT_ID ;
access:dword;
p:pchar;
status:integer;
begin
ProcessHandle:=thandle(-1);
if EnableDebugPrivilege(true)=false then
  begin
  showmessage('EnableDebugPrivilege failed');
  exit;
  end;
setlasterror(0);
pid:=0;
//findwindow wont work in session 0, lets go thru process names
ps:=TDGProcessList.Create ;
//
ps.Refresh ;
for i:=0 to ps.Count -1 do
  begin
  if (ps[i].Name =txtprocess.Text ) {and (ps[i].UserName =user)} then pid:=ps[i].ProcessID ;
  end;
//
  if txtpid.Text <>'' then pid:=strtoint(txtpid.Text );
  if pid<>0 then
  begin
    ProcessHandle :=thandle(-1);
    access:=PROCESS_ALL_ACCESS ;
    //access:=PROCESS_CREATE_THREAD or PROCESS_QUERY_INFORMATION or PROCESS_VM_OPERATION or PROCESS_VM_WRITE or PROCESS_VM_READ;
    //ProcessHandle := OpenProcess(access, False, PID);
    //

    InitializeObjectAttributes(oa,nil,0,0,nil);
    cid.UniqueProcess :=pid;
    cid.UniqueThread :=0;
    status:=NtOpenProcess(@ProcessHandle,access,@oa,@cid);
    if status<>0 then begin showmessage('NtOpenProcess failed,'+inttohex(status,4));exit;end;
    //
    if ProcessHandle >0 then
      begin
      try
      if RadioButton1.Checked then
        begin
  
        //if Inject_RemoteThreadCODE (ProcessHandle, @proc3)=false then showmessage('Inject failed') else  showmessage('Inject ok');
        if Inject_RemoteThreadDLL (ProcessHandle, txtdll.text+#0)=false then showmessage('Inject failed') else  showmessage('Inject ok');
        end;
      if RadioButton2.Checked then
        begin
        //getmem(p,length(ExtractFilePath(Application.ExeName)+'hook.dll'));
        //p:=pchar(ExtractFilePath(Application.ExeName)+'hook.dll');
        p:='hook.dll';
        //if InjectRTL_CODE(ProcessHandle, @proc,p)=false then showmessage('InjectRTL failed') else showmessage('InjectRTL ok');
        if InjectRTL_dll(ProcessHandle, txtdll.text+#0)=false then showmessage('InjectRTL failed') else showmessage('InjectRTL ok');
        end;
      {
      if RadioButton4.Checked then
        begin
        if InjectRTL_DLL(ProcessHandle, 'c:\hook.dll')=false then showmessage('InjectRTL failed') else showmessage('InjectRTL ok');
        end;
      }
      if RadioButton3.Checked then
        begin
        //if InjectNT_CODE(ProcessHandle, @proc3)=false then showmessage('InjectNT failed') else showmessage('InjectNT ok');
        if InjectNT_DLL(ProcessHandle, txtdll.text+#0)=false then showmessage('InjectNT failed') else showmessage('InjectNT ok');
        end;
      except
      on e:exception do showmessage(e.Message );
      end;
      CloseHandle(ProcessHandle);
      end
      else showmessage('NtOpenProcess failed,'+inttostr(getlasterror));
  end
  else showmessage('GetWindowThreadProcessId failed,'+inttostr(getlasterror));
//
ps.free;
end;

procedure TForm1.Button2Click(Sender: TObject);
var
p:pchar;
begin
//use the heap with new-dispose/getmem-freemem, not the stack
//getmem(p,length('c:\hook.dll'));
//p:='c:\hook.dll';
//Proc3(p);
proc3(nil);
end;

procedure TForm1.FormCreate(Sender: TObject);
var
p:pchar;
dw:dword;
s:string;
begin
StatusBar1.SimpleText :='$'+inttohex(integer(Pointer(GetModuleHandle(nil))),4);
dw:=1000;
//p:=pchar(DwordToStr(dw));
//p:=pchar('test');
//showmessage(strpas(p));
end;

procedure loadDll; assembler;
asm
      push $DEADBEEF // EIP
      pushfd
      pushad
      push $DEADBEEF // memory with dll name
      mov eax, $DEADBEEF // loadlibrary address
      call eax
      popad
      popfd
      ret
end;

procedure dEnd; assembler;
asm

end;

procedure InjectLib(const PID, TID: DWORD; DLL_NAME: PChar);
var
   stub, dllString: Pointer;
  stubLen, oldIP, oldprot, loadLibAddy, ret: DWORD;
  hProcess, hThread: THandle;
  ctx: CONTEXT;
  begin
   stubLen := DWORD(@dEnd) - DWORD(@loadDll);

   loadLibAddy := DWORD(GetProcAddress(GetModuleHandle('kernel32.dll'), 'LoadLibraryA'));

   hProcess := OpenProcess(PROCESS_VM_WRITE or PROCESS_VM_OPERATION, False, PID);

   dllString := VirtualAllocEx(hProcess, nil, (lstrlen(DLL_NAME)+1), MEM_COMMIT, PAGE_READWRITE);
   stub := VirtualAllocEx(hProcess, nil, stubLen, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
   WriteProcessMemory(hProcess, dllString, DLL_NAME, lstrlen(DLL_NAME), ret);

   hThread := OpenThread(THREAD_GET_CONTEXT or THREAD_SET_CONTEXT or THREAD_SUSPEND_RESUME, false, TID);
   SuspendThread(hThread);

   ZeroMemory(@ctx, sizeof(ctx));

   ctx.ContextFlags := CONTEXT_CONTROL;
   GetThreadContext(hThread, ctx);
   oldIP := ctx.Eip;
   ctx.Eip := DWORD(stub);
   ctx.ContextFlags := CONTEXT_CONTROL;

   VirtualProtect(@loadDll, stubLen, PAGE_EXECUTE_READWRITE, @oldprot);

   CopyMemory(pointer(dword(@loaddll) + 1), @oldIP, 4);
   CopyMemory(pointer(dword(@loaddll) + 8), dllString, 4);
   CopyMemory(pointer(dword(@loaddll) + 13), @loadLibAddy, 4);

   WriteProcessMemory(hProcess, stub, @loaddll, stubLen, ret);

   SetThreadContext(hThread, ctx);

   ResumeThread(hThread);

   Sleep(8000);

   VirtualFreeEx(hProcess, dllString, strlen(DLL_NAME), MEM_DECOMMIT);
   VirtualFreeEx(hProcess, stub, stubLen, MEM_DECOMMIT);
   CloseHandle(hProcess);
   CloseHandle(hThread);
end;


end.
