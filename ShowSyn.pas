unit ShowSyn;

interface

uses
  {Winapi.Windows, Winapi.Messages, }Windows, Dialogs, Classes, SysUtils, Clipbrd;
type
  TSearchObject = Record
    owner: string;
    name: string;
  end;
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

procedure SynonymByTableToClipboard(const SelectedString: string) ;
var
  FoundObjects: TStringList;
begin
  FoundObjects := GetSynonymsByTable(SelectedString);
  if FoundObjects.Count = 1 then
    begin
      Clipboard.AsText := FoundObjects[0];
     end
  else if FoundObjects.Count > 1 then
    ShowMessage('Multiply synonyms found' + #13 + FoundObjects.Text)
  else
    ShowMessage('No synonyms for table [' + SelectedString + ']');
end;

procedure SynonymByTableToWindow(const SelectedString: string) ;
var
  FoundObjects: TStringList;
  X, Y, windowHandle: Integer;
  the_line : string;
  Buffer  : string;
begin
  FoundObjects := GetSynonymsByTable(SelectedString);
  if FoundObjects.Count = 1 then
    begin
      Clipboard.AsText := FoundObjects[0];
     end
  else if FoundObjects.Count > 1 then
    ShowMessage('Multiply synonyms found' + #13 + FoundObjects.Text)
  else
    ShowMessage('No synonyms for table [' + SelectedString + ']');
end;

////////////////////////////////////////////////////////////////////////////////

function GetTableBySynonym(const SelectedString: string): TStringList;
var
  Query: string;
  searchObject: TSearchObject;
begin
  searchObject :=   ParseSelectedString(SelectedString);

  Query := 'SELECT table_owner || ''.'' || table_name from all_synonyms '
      + ' WHERE owner = UPPER(NVL(''' + searchObject.owner + ''', owner))'
      + ' AND synonym_name = UPPER(''' + searchObject.name + ''')'
      + ' ORDER BY CASE WHEN owner = USER THEN 1 WHEN owner = ''PUBLIC'' THEN 2 ELSE 3 END';
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

////////////////////////////////////////////////////////////////////////////////
// The menu item got selected
procedure OnMenuClick(Index: Integer);  cdecl;
begin
  case Index of
    1 : ShowSynonymsByTable(IDE_GetCursorWord);
    2 : ShowTableBySynonym(IDE_GetCursorWord);
    3 : SynonymByTableToClipboard(IDE_GetCursorWord);
    4 : SynonymByTableToEditor(IDE_GetCursorWord);

  end;
end;

exports // The three basic export functions
  IdentifyPlugIn,
  CreateMenuItem,
  RegisterCallback,
  OnMenuClick,
  OnActivate;

end.


