unit registry_;

interface

uses windows,registry,classes;

procedure getapps(s:tstringlist) ;

implementation

procedure getapps(s:tstringlist) ;
const
   REGKEYAPPS = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall';
var
   reg : TRegistry;
   List1 : TStringList;
   List2 : TStringList;
   j, n : integer;

begin
   reg := TRegistry.Create;
   List1 := TStringList.Create;
   List2 := TStringList.Create;

   {Load all the subkeys}
   with reg do
   begin
     RootKey := HKEY_LOCAL_MACHINE;
     OpenKey(REGKEYAPPS, false) ;
     GetKeyNames(List1) ;
     CloseKey ;
   end;
  {Load all the Value Names}
   for j := 0 to List1.Count -1 do
   begin
     reg.OpenKey( REGKEYAPPS+'\'+List1.Strings[j],false) ;
     reg.GetValueNames(List2) ;

     {We will show only if there is 'DisplayName'}
     n := List2.IndexOf('DisplayName') ;
     if n<>-1
      then s.Add((reg.ReadString(List2.Strings[n])))
      else s.Add(List1.Strings[j]);
     reg.CloseKey;
   end;
   List1.Free;
   List2.Free;
   reg.Destroy;
end;

end.