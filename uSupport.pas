//
//  File:    Support.pas v1.00
//  Autor:   Arjen van der Meulen
//  Country: The Netherlands
//  Date:    10-10-2002
//
//
//  WordToStr()   : Converts a WORD to a 2 byte string
//  DwordToStr()  : Converts a DWORD to a 4 byte string
//  StrToDWord()  : Converts a 4 byte string to a DWORD
//  StrToWord()   : Converts a 2 byte string to a WORD
//
//  SetBit()      : Sets a single BIT in a string to true or false
//  GetBit()      : Returns the state of a single bit in a string
//
//  Pack()        : Compresses a string to a hopefully smaller string
//  UnPack()      : DeCompresses a string compressed with Pack()
//
//  FindBest()    : Finds a substring in another string an returns position and
//                  the number of characters upto where they are equal

unit uSupport;

interface

type dword=longword;

function WordToStr(Value: word): string;
function DwordToStr(Value: dword): string;
function StrToWord(Value: string): word;
function StrToDword(Value: string): dword;

procedure SetBit(var Str: string; BitNr: dword; Value: boolean);
function  GetBit(Str: string; BitNr: dword): boolean;

function Pack(I: string):string;
function UnPack(I: string): string;

procedure FindBest(Main, Sub: string;var FoundLen, FoundPos: integer);

implementation

//  DwordToStr()  : Converts a DWORD to a 4 byte string
function DwordToStr(Value: dword): string;
var
   ResultPtr: PChar;
begin
   SetLength(Result, 4);
   ResultPtr:=@Result[1];
   asm
   MOV EAX, [ResultPtr]
   MOV EBX, Value
   MOV [EAX], EBX
   //MOV result, EAX
   end;
end;

//  StrToDWord()  : Converts a 4 byte string to a DWORD
function StrToDword(Value: string): dword;
var
   ValuePtr: PChar;
begin
   ValuePtr:=@Value[1];
   asm
   MOV EAX, [ValuePtr]
   MOV EAX, [EAX]
   MOV Result, EAX end;
end;

//  WordToStr()   : Converts a WORD to a 2 byte string
function WordToStr(Value: word): string;
var
   ResultPtr: PChar;
begin
   SetLength(Result, 2);
   ResultPtr:=@Result[1];
   asm
   MOV EAX, [ResultPtr]
   MOV BX, Value
   MOV [EAX], BX end;
end;

//  StrToWord()   : Converts a 2 byte string to a WORD
function StrToWord(Value: string): word;
var
   ValuePtr: PChar;
begin
   ValuePtr:=@Value[1];
   asm
   MOV EAX, [ValuePtr]
   MOV AX, [EAX]
   MOV Result, AX end;
end;

//  SetBit()      : Sets a single BIT in a string to true or false
procedure SetBit(var Str: string; BitNr: dword; Value: boolean);
var
   CharNr: dword;
   CharBit: byte;
   Original, Mask: byte;
begin
   CharNr:=(BitNr DIV 8)+1;
   CharBit:=(BitNr MOD 8);
   Original:=byte(Str[CharNr]);
   Mask:=1 shl CharBit;
   if Value=true then
        Original:=(Original or Mask)
   else
        Original:=(Original and not Mask);
   Str[CharNr]:=char(Original);
end;

//  GetBit()      : Returns the state of a single bit in a string
function GetBit(Str: string; BitNr: dword): boolean;
var
   CharNr: dword;
   CharBit: byte;
   Original, Mask: byte;
begin
   CharNr:=(BitNr DIV 8)+1;
   CharBit:=(BitNr MOD 8);
   Original:=byte(Str[CharNr]);
   Mask:=1 shl CharBit;
   if (Original and Mask)=Mask then
       Result:=true
   else
       Result:=false;
end;

//  Pack()        : Compresses a string to a hopefully smaller string
function Pack(I: string):string;
var
   Header: string;
   Tag,T1,T2: string;
   Buffer: string;

   History: string;
   FindStr: string;
   P: integer;
   FP,FL: integer;
begin
   SetLength(Tag,(Length(I) DIV 8)+1);  // Create TAG string
   Header:=DwordToStr(Length(I));       // Create Header string (length of original)

   // Pack the string
   P:=1; while P<=Length(I) do begin
    FindStr:=Copy(I,P,10);
    FindBest(History,FindStr,FL,FP);
    if FL>2 then begin       // if match found in history and length>2
       Buffer:=Buffer+WordToStr((FP SHL 3)+(FL-3));
       History:=History+Copy(History,FP,FL);
        T1:=Copy(I,P,FL);
        T2:=Copy(History,FP,FL);
       SetBit(Tag,P-1,true);
       P:=P+(FL-1);
    end else begin           // if no match found in history
       Buffer:=Buffer+I[P];
       History:=History+I[P];
       SetBit(Tag,P-1,false);
    end;
    if Length(History)>8100 then History:=Copy(History,1024,8100); INC(P);
   end;

   Result:=Header+Tag+Buffer;
end;

//  UnPack()      : DeCompresses a string compressed with Pack()
function UnPack(I: string): string;
var
   Tag,T: string;
   Buffer: string;

   TmpWrd: string;
   History: string;
   P, OL: integer;
   FP, FL: integer;
begin
   // Split I in Tag and Buffer
   OL:=StrToDword(I);
   SetLength(Buffer, OL);
   SetLength(Tag,(OL DIV 8)+1);
   P:=5;
    Tag:=Copy(I,P,Length(Tag));
   P:=P+Length(Tag);
    Buffer:=Copy(I,P,Length(Buffer));
   Result:='';

   // begin unpacking
   P:=1; while Length(Result)<OL do begin
    if GetBit(Tag, Length(Result))=true then begin // if is packed
       TmpWrd:=Buffer[P]+Buffer[P+1];
       FL:=(StrToWord(TmpWrd) and 7)+3;
       FP:=(StrToWord(TmpWrd) shr 3) and 8191;
       Result:=Result+Copy(History,FP,FL);
       History:=History+Copy(History,FP,FL);
        T:=Copy(History,FP,FL);
       P:=P+1;
    end else begin                    // if is not packed
       Result:=Result+Buffer[P];
       History:=History+Buffer[P];
    end;
    if Length(History)>8100 then History:=Copy(History,1024,8100); INC(P);
   end;
end;

//  FindBest()    : Finds a substring in another string an returns position and
//                  the number of characters upto where they are equal
procedure FindBest(Main, Sub: string;var FoundLen, FoundPos: integer);
var
   P,T,FL,MaxLen: integer;
begin
    if Length(Sub)>Length(Main) then
        MaxLen:=Length(Main)
    else
        MaxLen:=Length(Sub);
    FoundLen:=0; FoundPos:=0;
    for P:=1 to Length(Main)-MaxLen do begin
       FL:=0;
       for T:=1 to MaxLen do begin
          if Main[P+T-1]=Sub[T] then FL:=T else Break;
       end;
       if FL>FoundLen then begin
          FoundLen:=FL;
          FoundPos:=P;
       end;
    end;
end;

end. 
