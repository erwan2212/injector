unit injection;

interface

uses windows,ntdll;

function Inject_RemoteThreadCODE(ProcessHandle: longword; EntryPoint: pointer):boolean;
function Inject_RemoteThreadDLL(ProcessHandle: longword; dll: string):boolean;

function InjectRTL_CODE(ProcessHandle: longword; EntryPoint,param: pointer):boolean;
function InjectRTL_DLL(ProcessHandle: longword; dll:string):boolean;

function InjectNT_CODE(ProcessHandle: longword; EntryPoint: pointer):boolean;
function InjectNT_DLL(ProcessHandle: longword; dll: string):boolean;


var
TNtCreateThreadEx : function(
  ThreadHandle: PHANDLE;
  DesiredAccess: ACCESS_MASK;
  ObjectAttributes: Pointer;
  ProcessHandle: THANDLE;
  lpStartAddress: Pointer;
  lpParameter: Pointer;
  CreateSuspended: BOOL;
  dwStackSize: DWORD;
  SizeOfStackCommit: Pointer;
  SizeOfStackReserve: Pointer;
  Thebuf: Pointer): HRESULT; stdcall;


__NtCreateThreadEx: function (
  var hThread: Cardinal;
  DesiredAccess: Cardinal;
  lpThreadAttribtes: Pointer;
  hProcess: Cardinal;
  lpStartAddress, lpParameter: Pointer;
  CreateSuspended: Boolean;
  dwStackZeroBits, SizeOfStackCommit, SizeOfStackReserve: Cardinal;
  var Thebuf: NT_THREAD_BUFFER): Cardinal; stdcall = nil;
  
  
implementation

uses SysUtils;

function Align(Value, Align: Cardinal): Cardinal;
begin
  if ((Value mod Align) = 0) then
    Result := Value
  else
    Result := ((Value + Align - 1) div Align) * Align;
end;

function Inject_RemoteThreadDLL(ProcessHandle: longword; dll:string):boolean;
var
baseaddress: Pointer;
  Size, BytesWritten, TID: longword;
  NtStatus:integer;
  //ClientID:CLIENT_ID ;
  hthread:thandle;
  Status:integer;
begin
result:=false;

    SetLastError(0);
  size:=length(dll)+sizeof(char);
  //size:=align(size,$1000);
  //status:=NtAllocateVirtualMemory(ProcessHandle ,@baseaddress,0,@Size,MEM_COMMIT , PAGE_READWRITE);
  baseaddress:=nil;
  baseaddress :=VirtualAllocEx(ProcessHandle ,nil,size,MEM_COMMIT or MEM_RESERVE , PAGE_EXECUTE_READWRITE);
  OutputDebugStringA(pchar('VirtualAllocEx:'+inttohex(dword(baseaddress),8)));
  //if status<>0 then
  if baseaddress=nil then
    begin
    raise Exception.Create('InjectRTL_DLL, NtAllocateVirtualMemory failed,'+inttohex(status,4));
    result:=false;
    exit;
    end;

  //b:=WriteProcessMemory(ProcessHandle, NewModule, Module, Size, BytesWritten);
  //if b=false
  Status:=NtWriteVirtualMemory(ProcessHandle, baseaddress, @dll[1], size, @BytesWritten);
  if Status<>0
    then
    begin
    raise Exception.Create('NtWriteVirtualMemory failed,'+inttohex(status,4));
    result:=false;
    end;

  hthread:= CreateRemoteThread(ProcessHandle, nil, 0, GetProcAddress(GetModuleHandle('kernel32.dll'), 'LoadLibraryA'), baseaddress , 0, TID);
  if  hthread<>0 then result:=true;
  WaitForSingleObject(hthread,INFINITE);
  CloseHandle(hthread);
  VirtualFreeEx(ProcessHandle, baseaddress, Size, MEM_RELEASE);
end;


function Inject_RemoteThreadCODE(ProcessHandle: longword; EntryPoint: pointer):boolean;
var
  Module, NewModule: Pointer;
  Size, BytesWritten, TID: longword;
  NtStatus:integer;
  //ClientID:CLIENT_ID ;
  hthread:thandle;
begin
result:=false;
  Module := Pointer(GetModuleHandle(nil));
  Size := PImageOptionalHeader(Pointer(integer(Module) + PImageDosHeader(Module)._lfanew + SizeOf(dword) + SizeOf(TImageFileHeader))).SizeOfImage;
  size:=align(size,$1000);
  VirtualFreeEx(ProcessHandle, Module, 0, MEM_RELEASE);
    //begin
    //raise Exception.Create('VirtualFreeEx failed,'+inttostr(getlasterror));
    //result:=false;
    //exit;
    //end;
  NewModule := VirtualAllocEx(ProcessHandle, Module, Size, MEM_COMMIT or MEM_RESERVE, PAGE_EXECUTE_READWRITE);
  if newmodule=nil then
    begin
    raise Exception.Create('VirtualAllocEx failed,'+inttostr(getlasterror));
    result:=false;
    exit;
    end;
  if WriteProcessMemory(ProcessHandle, NewModule, Module, Size, BytesWritten)=false then
    begin
    raise Exception.Create('WriteProcessMemory failed,'+inttostr(getlasterror));
    result:=false;
    exit;
    end;
  hthread:= CreateRemoteThread(ProcessHandle, nil, 0, EntryPoint, Module, 0, TID);
  if  hthread<>0 then result:=true;
  WaitForSingleObject(hthread,INFINITE);
  CloseHandle(hthread);
end;

//https://msdn.microsoft.com/en-us/library/cc704588.aspx -> status codes
function InjectRTL_CODE(ProcessHandle: longword; EntryPoint,param: pointer):boolean;
var
  Module, baseaddress: Pointer;
  Size, BytesWritten, TID: longword;
  Status:integer;
  hThread:thandle;
  ClientID:CLIENT_ID;
  b:boolean;
begin
  //STATUS_FREE_VM_NOT_AT_BASE=0xC000009F
  //STATUS_UNABLE_TO_DELETE_SECTION=0xC000001B
  
  Module := Pointer(GetModuleHandle(nil));
  size:=0;status:=0;
  VirtualFreeEx(ProcessHandle, Module, 0, MEM_RELEASE);
  //status:=NtFreeVirtualMemory(ProcessHandle, @module, @size, MEM_RELEASE);
  {
  if status<>0 then
    begin
    raise Exception.Create('NtFreeVirtualMemory $'+inttohex(integer(module),4)+' failed,'+inttohex(status,4));
    result:=false;
    exit;
    end;
  }
  Size := PImageOptionalHeader(Pointer(integer(Module) + PImageDosHeader(Module)._lfanew + SizeOf(dword) + SizeOf(TImageFileHeader))).SizeOfImage;
  size:=align(size,$1000);
  SetLastError(0);

  //STATUS_INVALID_HANDLE=C0000008
  //baseaddress :=VirtualAllocEx(ProcessHandle ,module,size,MEM_COMMIT or MEM_RESERVE , PAGE_EXECUTE_READWRITE);
  baseaddress:=module;
  status:=NtAllocateVirtualMemory(ProcessHandle ,@baseaddress,0,@Size,MEM_COMMIT or MEM_RESERVE, PAGE_EXECUTE_READWRITE);
  //if baseaddress =nil then
  if status<>0 then
    begin
    raise Exception.Create('NtAllocateVirtualMemory failed,'+inttohex(status,4));
    result:=false;
    exit;
    end;

  //lets write our module to baseaddress
  Status:=NtWriteVirtualMemory(ProcessHandle, baseaddress, Module, Size, @BytesWritten);
  if Status<>0
    then
    begin
    raise Exception.Create('NtWriteVirtualMemory failed,'+inttohex(status,4));
    result:=false;
    end
    else
    begin
    //Status:=RtlCreateUserThread(ProcessHandle, nil, false, 0, 0,0, GetProcAddress (GetModuleHandle('dll'),'func') , pchar('param'), @hThread, @ClientID);

    Status:=RtlCreateUserThread(ProcessHandle, nil, false, 0, 0,0, EntryPoint , nil, @hThread, @ClientID);
    WaitForSingleObject(hThread,INFINITE);
    CloseHandle(hThread);
    if Status <>0 then result:=false else result:=true;
    end;

    //size:=0;
    //NtFreeVirtualMemory(ProcessHandle, module, @size, MEM_RELEASE);

end;



function InjectRTL_DLL(ProcessHandle: longword; dll:string):boolean;
const
ThreadDynamicCodePolicy =2;
type TGetThreadInformation=function(hThread:thandle;
  ThreadInformationClass:dword;
  ThreadInformation:pointer;
  ThreadInformationSize:DWORD):boolean;stdcall;
var
  baseaddress: Pointer;
  Size, BytesWritten, TID: longword;
  Status:integer;
  hThread:thandle;
  ClientID:CLIENT_ID ;
  b:boolean;
  GetThreadInformation:tGetThreadInformation;
  dwThreadPolicy:dword;
begin
  SetLastError(0);
  size:=length(dll)+sizeof(char);
  //size:=align(size,$1000);
  //status:=NtAllocateVirtualMemory(ProcessHandle ,@baseaddress,0,@Size,MEM_COMMIT , PAGE_READWRITE);
  baseaddress:=nil;
  baseaddress :=VirtualAllocEx(ProcessHandle ,nil,size,MEM_COMMIT or MEM_RESERVE , PAGE_EXECUTE_READWRITE);
  OutputDebugStringA(pchar('VirtualAllocEx:'+inttohex(dword(baseaddress),8)));
  //if status<>0 then
  if baseaddress=nil then
    begin
    raise Exception.Create('InjectRTL_DLL, NtAllocateVirtualMemory failed,'+inttohex(status,4));
    result:=false;
    exit;
    end;

  //b:=WriteProcessMemory(ProcessHandle, NewModule, Module, Size, BytesWritten);
  //if b=false
  Status:=NtWriteVirtualMemory(ProcessHandle, baseaddress, @dll[1], size, @BytesWritten);
  if Status<>0
    then
    begin
    raise Exception.Create('NtWriteVirtualMemory failed,'+inttohex(status,4));
    result:=false;
    end
    else
    begin
    //Status:=RtlCreateUserThread(ProcessHandle, nil, false, 0, 0,0, GetProcAddress (GetModuleHandle('dll'),'func') , pchar('param'), @hThread, @ClientID);
    hThread:=thandle(-1);
    OutputDebugString(pchar('LoadLibraryA:'+inttohex(dword(GetProcAddress(GetModuleHandle('kernel32.dll'), 'LoadLibraryA')),8)));
    Status:=RtlCreateUserThread(ProcessHandle, nil, false, 0, 0,0, GetProcAddress(GetModuleHandle('kernel32.dll'), 'LoadLibraryA'), baseaddress , @hThread, nil);
    //@GetThreadInformation:=GetProcAddress(GetModuleHandle('kernel32.dll'), 'GetThreadInformation');
    //GetThreadInformation(hThread,ThreadDynamicCodePolicy,@dwThreadPolicy, sizeof(DWORD));
    //OutputDebugStringA(pchar('ThreadDynamicCodePolicy:'+inttostr(dwThreadPolicy)));
    //ResumeThread(hThread); //if created suspensed
    OutputDebugStringA(pchar('RtlCreateUserThread:'+inttostr(hThread)));
    WaitForSingleObject(hThread,INFINITE);
    CloseHandle(hThread);
    VirtualFreeEx(ProcessHandle, baseaddress, Size, MEM_RELEASE);
    if Status <>0 then result:=false else result:=true;
    end;

end;

function InjectNT_DLL(ProcessHandle: longword; dll: string):boolean;
var
  baseaddress: Pointer;
  Size, BytesWritten, TID: longword;
  Status:integer;
  hThread:thandle;
  ClientID:CLIENT_ID ;
  //
  Unknown3, Unknown7: Cardinal;
  ntbuf: NT_THREAD_BUFFER;
begin


 size:=length(dll)+sizeof(char);
  //size:=align(size,$1000);
  //status:=NtAllocateVirtualMemory(ProcessHandle ,@baseaddress,0,@Size,MEM_COMMIT or MEM_RESERVE, PAGE_EXECUTE_READWRITE);
  baseaddress:=nil;
  baseaddress :=VirtualAllocEx(ProcessHandle ,nil,size,MEM_COMMIT or MEM_RESERVE , PAGE_EXECUTE_READWRITE);
  OutputDebugStringA(pchar('VirtualAllocEx:'+inttohex(dword(baseaddress),8)));
  //if status<>0 then
  if baseaddress=nil then
    begin
    result:=false;
    raise Exception.Create('NtAllocateVirtualMemory failed,'+inttohex(status,4));
    exit;
    end;


  Status:=NtWriteVirtualMemory(ProcessHandle, baseaddress, @dll[1], size, @BytesWritten);
  if Status<>0
    then
    begin
    result:=false;
    raise Exception.Create('NtWriteVirtualMemory failed,'+inttohex(status,4));
    end
    else
    begin
    //
    TNtCreateThreadEx:=GetProcAddress(LoadLibrary('ntdll.dll'), 'NtCreateThreadEx');

  if (@TNtCreateThreadEx <> nil) then
  begin
  ntbuf.Size := SizeOf(NT_THREAD_BUFFER);
  Unknown3 := 0; Unknown7 := 0;
  ntbuf.Unknown1 := $10003;
  ntbuf.Unknown2 := $8;
  ntbuf.Unknown3 := @Unknown3;
  ntbuf.Unknown4 := 0;
  ntbuf.Unknown5 := $10004;
  ntbuf.Unknown6 := 4;
  ntbuf.Unknown7 := @Unknown7;
  ntbuf.Unknown8 := 0;
  hThread:=0;
  OutputDebugString(pchar('LoadLibraryA:'+inttohex(dword(GetProcAddress(GetModuleHandle('kernel32.dll'), 'LoadLibraryA')),8)));
  TNtCreateThreadEx(@hThread,$1FFFFF, nil, ProcessHandle, GetProcAddress(GetModuleHandle('kernel32.dll'), 'LoadLibraryA'), baseaddress, False, 0, 0, 0, @ntbuf);
  end;
  //
    OutputDebugStringA(pchar('NtCreateThreadEx:'+inttostr(hThread)));
    WaitForSingleObject(hThread,INFINITE);
    CloseHandle(hThread);
    VirtualFreeEx(ProcessHandle, baseaddress, Size, MEM_RELEASE);

    if hThread <>0 then result:=true else result:=false;
    end;


end;



function InjectNT_CODE(ProcessHandle: longword; EntryPoint: pointer):boolean;
var
  Module, baseaddress: Pointer;
  Size, BytesWritten, TID: longword;
  Status:integer;
  hThread:thandle;
  ClientID:CLIENT_ID ;
  //
  Unknown3, Unknown7: Cardinal;
  ntbuf: NT_THREAD_BUFFER;
begin

  Module := Pointer(GetModuleHandle(nil));
  size:=0;status:=0;
  //VirtualFreeEx(ProcessHandle, Module, 0, MEM_RELEASE);
  status:=NtFreeVirtualMemory(ProcessHandle, @module, @size, MEM_RELEASE);
  if status<>0 then
    begin
    raise Exception.Create('NtFreeVirtualMemory $'+inttohex(integer(module),4)+' failed,'+inttohex(status,4));
    result:=false;
    exit;
    end;

  Size := PImageOptionalHeader(Pointer(integer(Module) + PImageDosHeader(Module)._lfanew + SizeOf(dword) + SizeOf(TImageFileHeader))).SizeOfImage;
  size:=align(size,$1000);
  SetLastError(0);

  //STATUS_INVALID_HANDLE=C0000008
  //STATUS_ACCESS_DENIED=C0000005
  //STATUS_CONFLICTING_ADDRESSES=0xC0000018
  baseaddress:=module;
  status:=NtAllocateVirtualMemory(ProcessHandle ,@baseaddress,0,@Size,MEM_COMMIT or MEM_RESERVE, PAGE_EXECUTE_READWRITE);
  if status<>0 then
    begin
    result:=false;
    raise Exception.Create('NtAllocateVirtualMemory failed,'+inttohex(status,4));
    exit;
    end;

  Status:=NtWriteVirtualMemory(ProcessHandle, baseaddress, Module, Size, @BytesWritten);
  if Status<>0
    then
    begin
    result:=false;
    raise Exception.Create('NtWriteVirtualMemory failed,'+inttohex(status,4));
    end
    else
    begin
    //
    TNtCreateThreadEx:=GetProcAddress(LoadLibrary('ntdll.dll'), 'NtCreateThreadEx');
  if (@TNtCreateThreadEx <> nil) then
  begin
  ntbuf.Size := SizeOf(NT_THREAD_BUFFER);
  Unknown3 := 0; Unknown7 := 0;
  ntbuf.Unknown1 := $10003;
  ntbuf.Unknown2 := $8;
  ntbuf.Unknown3 := @Unknown3;
  ntbuf.Unknown4 := 0;
  ntbuf.Unknown5 := $10004;
  ntbuf.Unknown6 := 4;
  ntbuf.Unknown7 := @Unknown7;
  ntbuf.Unknown8 := 0;
  hThread:=0;
  TNtCreateThreadEx(@hThread,$1FFFFF, nil, ProcessHandle, EntryPoint, nil, False, 0, 0, 0, @ntbuf);
  end;
  //
    WaitForSingleObject(hThread, INFINITE);
    if hThread <>0 then result:=true else result:=false;
    end;

    //size:=0;
    //NtFreeVirtualMemory(ProcessHandle, @module, @size, MEM_RELEASE);

end;

//***************************************************************************************************************
function __CreateRemoteThread(hProcess: Cardinal; lpThreadAttributes: Pointer; dwStackSize: Cardinal;
lpStartAddress, lpParameter: Pointer; dwCreationFlags: Cardinal; var lpThreadId: Cardinal): Cardinal;
var
Unknown3, Unknown7, hThread: Cardinal;
ntbuf: NT_THREAD_BUFFER;
begin
Result := 0;

__NtCreateThreadEx := GetProcAddress(LoadLibrary('ntdll.dll'), 'NtCreateThreadEx');
if (@__NtCreateThreadEx <> nil) then
begin
ntbuf.Size := SizeOf(NT_THREAD_BUFFER);
Unknown3 := 0;
Unknown7 := 0;
ntbuf.Unknown1 := $10003;
ntbuf.Unknown2 := $8;
ntbuf.Unknown3 := @Unknown3;
ntbuf.Unknown4 := 0;
ntbuf.Unknown5 := $10004;
ntbuf.Unknown6 := 4;
ntbuf.Unknown7 := @Unknown7;
ntbuf.Unknown8 := 0;

__NtCreateThreadEx(hThread, $1FFFFF, nil, hProcess, lpStartAddress, lpParameter, False, 0, 0, 0, ntbuf);

if (hThread <> 0) then
Result := hThread;
end
else
Result := CreateRemoteThread(hProcess, lpThreadAttributes, dwStackSize, lpStartAddress, lpParameter, dwCreationFlags,
lpThreadId);
end;

function InjectString(hProcess: Cardinal; Text: String): PChar;
var
nBytes: Cardinal;
begin
Result := VirtualAllocEx(hProcess, nil, Length(Text) + 1, MEM_COMMIT or MEM_RESERVE, PAGE_READWRITE);
if not (WriteProcessMemory(hProcess, Result, PChar(Text), Length(Text) + 1, nBytes)) then
Result := nil;
end;

function InjectMemory(hProcess: Cardinal; pBuffer: Pointer; dwBufLen: Cardinal): Pointer;
var
nBytes: Cardinal;
begin
Result := VirtualAllocEx(hProcess, nil, dwBufLen, MEM_COMMIT or MEM_RESERVE, PAGE_EXECUTE_READWRITE);
if not (WriteProcessMemory(hProcess, Result, pBuffer, dwBufLen, nBytes)) then
Result := nil;
end;

function InjectThread(hProcess: Cardinal; pThreadFunc: Pointer; pThreadParam: Pointer; dwFuncSize,
dwParamSize: Cardinal; Results: Boolean): Cardinal;
var
pThread, pParam: Pointer;
nBytes, TID: Cardinal;
begin
pParam := InjectMemory(hProcess, pThreadParam, dwParamSize);
pThread := InjectMemory(hProcess, pThreadFunc, dwFuncSize);
Result := __CreateRemoteThread(hProcess, nil, 0, pThread, pParam, 0, TID);
if Results then
begin
WaitForSingleObject(Result, INFINITE);
ReadProcessMemory(hProcess, pParam, pThreadParam, dwParamSize, nBytes);
end; 
end;

end.
