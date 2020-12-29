unit ShowSyn;

interface

uses
  Messages, Windows, Dialogs, Classes, SysUtils, Clipbrd, Controls;
type
  TSearchObject = Record
    owner: string;
    name: string;
  end;

  TSynonymAction = procedure(SynonymName: string);

var
  PlugInID: Integer;

const // Description of this Plug-In (as displayed in Plug-In configuration dialog)
  Desc = 'Show Synonym plug-in';
  ToClipboardMenuName = 'Copy synonym to clipboard';
  InsertSynonymMenuName = 'Paste synonym to window';
var
  IDE_GetCursorWord: function: PChar; cdecl;
  IDE_SetText: function (Text: PChar): Bool; cdecl;
  SQL_Execute: function(SQL: PChar): Integer; cdecl;
  SQL_FieldCount: function: Integer; cdecl;
  SQL_Eof: function: Bool; cdecl;
  SQL_Next: function: Integer; cdecl;
  SQL_Field: function(Field: Integer): PChar; cdecl;
  SQL_FieldName: function(Field: Integer): PChar; cdecl;
  SQL_FieldIndex: function(Name: PChar): Integer; cdecl;
  SQL_FieldType: function(Field: Integer): Integer; cdecl;
  SQL_ErrorMessage: function: PChar; cdecl;

  IDE_GetEditorHandle: function : Integer; cdecl;

  IDE_GetCursorX: function : Integer; cdecl;
  IDE_GetCursorY: function : Integer; cdecl;
  IDE_SetCursor: procedure (X, Y: Integer); cdecl;

  IDE_CreatePopupItem: procedure(ID, Index: Integer; Name, ObjectType: PChar); cdecl;



implementation

// Plug-In identification, a unique identifier is received and
// the description is returned
function IdentifyPlugIn(ID: Integer): PChar;  cdecl;
begin
  PlugInID := ID;
  Result := Desc;
end;

// Registration of PL/SQL Developer callback functions
procedure RegisterCallback(Index: Integer; Addr: Pointer); cdecl;
begin
  case Index of
    32 : @IDE_GetCursorWord := Addr;
    33 : @IDE_GetEditorHandle := Addr;
    34 : @IDE_SetText := Addr;
    40 : @SQL_Execute := Addr;
    41 : @SQL_FieldCount := Addr;
    42 : @SQL_Eof := Addr;
    43 : @SQL_Next := Addr;
    44 : @SQL_Field := Addr;
    45 : @SQL_FieldName := Addr;
    46 : @SQL_FieldIndex := Addr;
    47 : @SQL_FieldType := Addr;
    48 : @SQL_ErrorMessage := Addr;
    69 : @IDE_CreatePopupItem := Addr;
    141 : @IDE_GetCursorX := Addr;
    142 : @IDE_GetCursorY := Addr;
    143 : @IDE_SetCursor := Addr;

  end;
end;

// Creating a menu item
function CreateMenuItem(Index: Integer): PChar;  cdecl;
begin
  Result := '';
  case Index of
    1 : Result := 'NOVIS Synonyms / Show synonym by table';
    2 : Result := 'NOVIS Synonyms / Show table by synonym';
    3 : Result := 'NOVIS Synonyms / ' + ToClipboardMenuName;
    4 : Result := 'NOVIS Synonyms / ' + InsertSynonymMenuName;
    5 : Result := 'NOVIS Synonyms / Set cursor';    
  end;
end;

procedure OnActivate; cdecl;
begin
  IDE_CreatePopupItem(PlugInID, 3, ToClipboardMenuName, 'SQLWINDOW');
  IDE_CreatePopupItem(PlugInID, 3, ToClipboardMenuName, 'COMMANDWINDOW');
  IDE_CreatePopupItem(PlugInID, 3, ToClipboardMenuName, 'TESTWINDOW');
  IDE_CreatePopupItem(PlugInID, 3, ToClipboardMenuName, 'COMMANDWINDOW');

  IDE_CreatePopupItem(PlugInID, 4, InsertSynonymMenuName, 'SQLWINDOW');
  IDE_CreatePopupItem(PlugInID, 4, InsertSynonymMenuName, 'COMMANDWINDOW');
  IDE_CreatePopupItem(PlugInID, 4, InsertSynonymMenuName, 'TESTWINDOW');
  IDE_CreatePopupItem(PlugInID, 4, InsertSynonymMenuName, 'COMMANDWINDOW');

end;

procedure Split(Delimiter: Char; Str: string; ListOfStrings: TStrings) ;
begin
   ListOfStrings.Clear;
   ListOfStrings.Delimiter       := Delimiter;
//   ListOfStrings.StrictDelimiter := True; // Requires D2006 or newer.
   ListOfStrings.DelimitedText   := Str;
end;

function ParseSelectedString(const SelectedString: string): TSearchObject;
var
  words: TStringList;
begin
  words := TStringList.Create;
  Split('.', SelectedString, words);

  if (words.count = 0) then
    begin
      ShowMessage('Empty string has been selected');
    end
  else if (words.count > 2) then
    begin
      ShowMessage('Wrong string is selected');
    end
  else if (words.count = 1) then
    begin
      //ShowMessage('one word ' + words[0]);
      Result.name := words[0];
    end
  else //2
    begin
      //ShowMessage('2 words ' + words[0] + '-' + words[1]);
      Result.owner := words[0];
      Result.name := words[1];
    end
end;

function GetResultForQuery(const Query: string): TStringList;
var
  SqlResult: Integer;
begin
  Result := TStringList.Create;
  SqlResult := SQL_Execute(PChar(Query));
  if (SqlResult <> 0) then
  begin
    ShowMessage('Error ' +  IntTOStr(SqlResult) + ': ' + SQL_ErrorMessage);
    exit;
  end;

  while not SQL_Eof do
  begin
    Result.Add(SQL_Field(0));
    SQL_Next;
  end;
end;

////////////////////////////////////////////////////////////////////////////////

function GetSynonymsByTable(const SelectedString: string): TStringList;
var
  Query: string;
  searchObject: TSearchObject;
begin
  searchObject :=  ParseSelectedString(SelectedString);

  Query := 'SELECT CASE WHEN owner != USER AND owner != ''PUBLIC'' THEN owner || ''.'' END || synonym_name AS synonym_name'
      + ' FROM all_synonyms t'
      + ' WHERE table_name = UPPER(''' + searchObject.name + ''')'
      + '   AND table_owner = UPPER(NVL(''' + searchObject.owner + ''', owner))'
      + ' ORDER BY CASE WHEN owner = USER THEN 1 WHEN owner = ''PUBLIC'' THEN 2 ELSE 3 END';
  Result := GetResultForQuery(Query);
end;

procedure ShowSynonymsByTable(const SelectedString: string) ;
var
  FoundObjects: TStringList;
begin
  FoundObjects := GetSynonymsByTable(SelectedString);
  if FoundObjects.Count > 0 then
    ShowMessage(FoundObjects.Text)
  else
    ShowMessage('No synonyms for table [' + SelectedString + ']');
end;

// See TSynonymAction below
procedure ProcessSynonymByTable(const SelectedString: string; SynonymAction: TSynonymAction) ;
var
  FoundObjects: TStringList;
begin
  FoundObjects := GetSynonymsByTable(SelectedString);
  if FoundObjects.Count = 1 then
    begin
      SynonymAction(FoundObjects[0]);
     end
  else if FoundObjects.Count > 1 then
    ShowMessage('Multiply synonyms found' + #13 + FoundObjects.Text)
  else
    ShowMessage('No synonyms for table [' + SelectedString + ']');
end;

////////////////////////////////////////////////////////////////////////////////
//TSynonymAction Synonym action
procedure ToClipboard(Str: string);
begin
  Clipboard.AsText := Str;
end;

function GetLineFromRichedit(REHandle: Integer; line: Integer ): WideString;
var
   LineIndex, LineLength, I: Integer;
begin
   Result := '';
   LineIndex := SendMessageW(REHandle, EM_LINEINDEX, line, 0);
   if LineIndex >= 0 then begin
     LineLength := SendMessageW(REHandle, EM_LINELENGTH, LineIndex, 0);
     if LineLength > 0 then begin
       SetLength(Result, LineLength);
       Result[1] := Widechar(LineLength);
       I:= SendMessageW(REHandle, EM_GETLINE, line, LPARAM(PWideChar(Result)));
       if I < LineLength then
         SetLength(Result, I);
     end; { if }
   end; { if }
end; { GetLineFromRichedit }

function GetCursorPosition(REHandle: HWND): Integer;
begin
  Result := Lo(FindControl(REHandle).Perform(EM_GETSEL, 0, 0));
end;

function GetActiveLine(REHandle: Integer): WideString;
var
  Pos, ActiveLine: Integer;
begin
  //Get current cursor position (selection actually)
  Pos := GetCursorPosition(REHandle);
  ActiveLine := FindControl(REHandle).Perform(EM_LINEFROMCHAR, Pos, 0);

  Result:= GetLineFromRichedit(REHandle, ActiveLine);
end;

procedure SetTextToPosition(REHandle: HWND; Const Str: String; X, Y: Integer);
var
  Pos: Integer;
begin
  //Move to position
  //ShowMessage(format('Cursor position: (%d;%d)', [IDE_GetCursorX, IDE_GetCursorY]));
  IDE_SetCursor(X, Y);
  //ShowMessage(format('Cursor position: (%d;%d)', [IDE_GetCursorX, IDE_GetCursorY]));
  SendMessage(REHandle, EM_REPLACESEL, 1, Longint(PChar(Str)));
end;

procedure ToEditor(Str: string);
var
  ActiveString: WideString;
  i, Offset: Integer;
  EditorHWND: Integer;
const
  VALID_SYMBOLS = ['0'..'9', 'a'..'z', 'A'..'Z', '.', '_', '@'];
begin
  EditorHWND := IDE_GetEditorHandle;
  ActiveString := GetActiveLine(EditorHWND);
  Offset := 0;
  for i := IDE_GetCursorX to Length(ActiveString) do
  begin
    if not (Char(ActiveString[i]) in VALID_SYMBOLS) then
      break;
    Inc(Offset);
  end;

  SetTextToPosition(EditorHWND, ' ' + Str, i, IDE_GetCursorY);
end;

////////////////////////////////////////////////////////////////////////////////

function GetTableBySynonym(const SelectedString: string): TStringList;
var
  Query: string;
  searchObject: TSearchObject;
begin
  searchObject :=   ParseSelectedString(SelectedString);

  Query := 'SELECT table_owner || ''.'' || table_name from all_synonyms '
      + ' WHERE owner IN (UPPER(''' + searchObject.owner + '''), USER, ''PUBLIC'')'
      + ' AND synonym_name = UPPER(''' + searchObject.name + ''')'
      + ' ORDER BY CASE owner WHEN  UPPER(''' + searchObject.owner + ''') THEN 1 WHEN USER THEN 2 WHEN ''PUBLIC'' THEN 3 ELSE 4 END';
  GetResultForQuery(Query);

  Result := GetResultForQuery(Query);
end;

procedure ShowTableBySynonym(const SelectedString: string) ;
var
  FoundObjects: TStringList;
begin
  FoundObjects := GetTableBySynonym(SelectedString);
  if FoundObjects.Count > 0 then
    ShowMessage(FoundObjects.Text)
  else
    ShowMessage('No tables for synonym [' + SelectedString + ']');
end;

procedure SetCursor();
var
  Str:String;

  REHandle: HWND;
begin
  REHandle := IDE_GetEditorHandle;
  Str :=  'XXX';

  ShowMessage(format('Cursor position: (%d;%d)', [IDE_GetCursorX, IDE_GetCursorY]));
  IDE_SetCursor(2,1);

//  SendMessageW(REHandle, EM_SETSEL, 1, 1);
  ShowMessage(format('Cursor position: (%d;%d)', [IDE_GetCursorX, IDE_GetCursorY]));

  SendMessage(REHandle, EM_REPLACESEL, 1, Longint(PChar(Str)));
end;
////////////////////////////////////////////////////////////////////////////////
// The menu item got selected
procedure OnMenuClick(Index: Integer);  cdecl;
begin
  case Index of
    1 : ShowSynonymsByTable(IDE_GetCursorWord);
    2 : ShowTableBySynonym(IDE_GetCursorWord);
    3 : ProcessSynonymByTable(IDE_GetCursorWord, ToClipboard);
    4 : ProcessSynonymByTable(IDE_GetCursorWord, ToEditor);
    5 : SetCursor();

  end;
end;

exports // The three basic export functions
  IdentifyPlugIn,
  CreateMenuItem,
  RegisterCallback,
  OnMenuClick,
  OnActivate;

end.


