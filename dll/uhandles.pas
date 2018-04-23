unit uhandles;

interface

uses windows,sysutils;

const
SystemHandleInformation       = $10;
STATUS_SUCCESS               = $00000000;
STATUS_BUFFER_OVERFLOW        = $80000005;
STATUS_INFO_LENGTH_MISMATCH   = $C0000004;
DefaulBUFFERSIZE              = $100000;

type
 OBJECT_INFORMATION_CLASS = (ObjectBasicInformation,ObjectNameInformation,ObjectTypeInformation,ObjectAllTypesInformation,ObjectHandleInformation );

 SYSTEM_HANDLE=packed record
 uIdProcess:ULONG;
 ObjectType:UCHAR;
 Flags     :UCHAR;
 Handle    :Word;
 pObject   :Pointer;
 GrantedAccess:ACCESS_MASK;
 end;

 PSYSTEM_HANDLE      = ^SYSTEM_HANDLE;
 SYSTEM_HANDLE_ARRAY = Array[0..0] of SYSTEM_HANDLE;
 PSYSTEM_HANDLE_ARRAY= ^SYSTEM_HANDLE_ARRAY;

  SYSTEM_HANDLE_INFORMATION=packed record
 uCount:ULONG;
 Handles:SYSTEM_HANDLE_ARRAY;
 end;
 PSYSTEM_HANDLE_INFORMATION=^SYSTEM_HANDLE_INFORMATION;

  UNICODE_STRING=packed record
    Length       :Word;
    MaximumLength:Word;
    Buffer       :PWideChar;
 end;

 OBJECT_NAME_INFORMATION=UNICODE_STRING;
 POBJECT_NAME_INFORMATION=^OBJECT_NAME_INFORMATION;

TNtQuerySystemInformation=function (SystemInformationClass:DWORD; SystemInformation:pointer; SystemInformationLength:DWORD;  ReturnLength:PDWORD):THandle; stdcall;
 TNtQueryObject           =function (ObjectHandle:cardinal; ObjectInformationClass:OBJECT_INFORMATION_CLASS; ObjectInformation:pointer; Length:ULONG;ResultLength:PDWORD):THandle;stdcall;



procedure handles;

implementation

function GetModuleFileNameExA (hProcess: THandle; hModule: HMODULE; lpFilename: PAnsiChar; nSize: DWORD): DWORD stdcall; external 'psapi.dll';

Var
 NTQueryObject           :TNtQueryObject;
 NTQuerySystemInformation:TNTQuerySystemInformation;

function GetObjectInfo(hObject:cardinal; objInfoClass:OBJECT_INFORMATION_CLASS):LPWSTR;
var
 pObjectInfo:POBJECT_NAME_INFORMATION;
 HDummy     :THandle;
 dwSize     :DWORD;
begin
  Result:=nil;
  dwSize      := sizeof(OBJECT_NAME_INFORMATION);
  pObjectInfo := AllocMem(dwSize);
  HDummy      := NTQueryObject(hObject, objInfoClass, pObjectInfo,dwSize, @dwSize);

  if((HDummy = STATUS_BUFFER_OVERFLOW) or (HDummy = STATUS_INFO_LENGTH_MISMATCH)) then
    begin
   FreeMem(pObjectInfo);
   pObjectInfo := AllocMem(dwSize);
   HDummy      := NTQueryObject(hObject, objInfoClass, pObjectInfo,dwSize, @dwSize);
  end;

  if((HDummy >= STATUS_SUCCESS) and (pObjectInfo.Buffer <> nil)) then
  begin
   Result := AllocMem(pObjectInfo.Length + sizeof(WCHAR));
   CopyMemory(result, pObjectInfo.Buffer, pObjectInfo.Length);
  end;
  FreeMem(pObjectInfo);
end;

Procedure EnumerateOpenFiles();
var
 sDummy      : string;
 hProcess    : THandle;
 hObject     : THandle;
 ResultLength: DWORD;
 aBufferSize : DWORD;
 aIndex      : Integer;
 pHandleInfo : PSYSTEM_HANDLE_INFORMATION;
 HDummy      : THandle;
 lpwsName    : PWideChar;
 lpwsType    : PWideChar;
 lpszProcess : PAnsiChar;
 //
 hfile:thandle;
 written:cardinal;
 buffer:string;
begin
    AbufferSize      := DefaulBUFFERSIZE;
  pHandleInfo      := AllocMem(AbufferSize);
  HDummy           := NTQuerySystemInformation(DWORD(SystemHandleInformation), pHandleInfo,AbufferSize, @ResultLength);  //Get the list of handles

  hFile := CreateFile(pchar('c:\handles.txt'), GENERIC_WRITE, 0, nil, CREATE_ALWAYS, 0, 0);

  if(HDummy = STATUS_SUCCESS) then  //If no error continue
    begin

      for aIndex:=0 to pHandleInfo^.uCount-1 do   //iterate the list
      begin
    hProcess := OpenProcess(PROCESS_DUP_HANDLE or PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, FALSE, pHandleInfo.Handles[aIndex].uIdProcess);  //open the process to get aditional info
    if(hProcess <> INVALID_HANDLE_VALUE) then  //Check valid handle
        begin
     hObject := 0;
     if DuplicateHandle(hProcess, pHandleInfo.Handles[aIndex].Handle,GetCurrentProcess(), @hObject, STANDARD_RIGHTS_REQUIRED,FALSE, 0) then  //Get  a copy of the original handle
          begin
      lpwsName := GetObjectInfo(hObject, ObjectNameInformation); //Get the filename linked to the handle
      //if (lpwsName <> nil)  then
            begin
       lpwsType    := GetObjectInfo(hObject, ObjectTypeInformation);
       lpszProcess := AllocMem(MAX_PATH);

       if GetModuleFileNameExA(hProcess, 0,lpszProcess, MAX_PATH)<>0 then  //get the name of the process
               sDummy:=ExtractFileName(lpszProcess)
              else
               sDummy:= 'System Process';

              buffer:='Type      '+inttostr(pHandleInfo.Handles[aIndex].ObjectType)+#13#10;
              WriteFile(hfile,buffer[1],length(buffer),written,nil);
              buffer:='PID      '+inttostr(pHandleInfo.Handles[aIndex].uIdProcess)+#13#10;
              WriteFile(hfile,buffer[1],length(buffer),written,nil);
              buffer:='Handle   '+inttostr(pHandleInfo.Handles[aIndex].Handle)+#13#10;
              WriteFile(hfile,buffer[1],length(buffer),written,nil);
              buffer:='Process  '+sDummy+#13#10;
              WriteFile(hfile,buffer[1],length(buffer),written,nil);
              buffer:='FileName '+string(lpwsName)+#13#10;
              WriteFile(hfile,buffer[1],length(buffer),written,nil);
              buffer:=#13#10;
              WriteFile(hfile,buffer[1],length(buffer),written,nil);

              FreeMem(lpwsName);
              FreeMem(lpwsType);
              FreeMem(lpszProcess);
      end;
      CloseHandle(hObject);
     end;
     CloseHandle(hProcess);
    end;
   end;
  end;
  FreeMem(pHandleInfo);
  CloseHandle(hfile);
end;

procedure handles;
begin
try
    NTQueryObject            := GetProcAddress(GetModuleHandle('NTDLL.DLL'), 'NtQueryObject');
    NTQuerySystemInformation := GetProcAddress(GetModuleHandle('NTDLL.DLL'), 'NtQuerySystemInformation');
   if (@NTQuerySystemInformation<>nil) and (@NTQuerySystemInformation<>nil) then
    EnumerateOpenFiles();
    //Readln;
  except
    on E:Exception do ;//Writeln(E.Classname, ': ', E.Message);
  end;
end;

end.
