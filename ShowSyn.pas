unit ShowSyn;

interface

uses
  Windows, Dialogs, Classes;

var
  PlugInID: Integer;

const // Description of this Plug-In (as displayed in Plug-In configuration dialog)
  Desc = 'Show Synonym plug-in';
  pasteMenuName = 'Paste synonym by table';
var
  IDE_GetCursorWord: function: PChar; cdecl;
  SQL_Execute: function(SQL: PChar): Integer; cdecl;
  SQL_FieldCount: function: Integer; cdecl;
  SQL_Eof: function: Bool; cdecl;
  SQL_Next: function: Integer; cdecl;
  SQL_Field: function(Field: Integer): PChar; cdecl;
  SQL_FieldName: function(Field: Integer): PChar; cdecl;
  SQL_FieldIndex: function(Name: PChar): Integer; cdecl;
  SQL_FieldType: function(Field: Integer): Integer; cdecl;

  IDE_CreatePopupItem: procedure(ID, Index: Integer; Name, ObjectType: PChar); cdecl;

implementation

{$R *.DFM}

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
    40 : @SQL_Execute := Addr;
    41 : @SQL_FieldCount := Addr;
    42 : @SQL_Eof := Addr;
    43 : @SQL_Next := Addr;
    44 : @SQL_Field := Addr;
    45 : @SQL_FieldName := Addr;
    46 : @SQL_FieldIndex := Addr;
    47 : @SQL_FieldType := Addr;
    69 : @IDE_CreatePopupItem := Addr;
  end;
end;

// Creating a menu item
function CreateMenuItem(Index: Integer): PChar;  cdecl;
begin
  Result := '';
  case Index of
    1 : Result := 'NOVIS Synonyms / Show synonym by table';
    2 : Result := 'NOVIS Synonyms / Show table by synonym';
    3 : Result := 'NOVIS Synonyms / ' + pasteMenuName;
  end;
end;

procedure OnActivate; cdecl;
begin
  IDE_CreatePopupItem(PlugInID, 3, pasteMenuName, 'SQLWINDOW');
  IDE_CreatePopupItem(PlugInID, 3, pasteMenuName, 'COMMANDWINDOW');
  IDE_CreatePopupItem(PlugInID, 3, pasteMenuName, 'TESTWINDOW');
  IDE_CreatePopupItem(PlugInID, 3, pasteMenuName, 'COMMANDWINDOW');
end;

procedure Split(Delimiter: Char; Str: string; ListOfStrings: TStrings) ;
begin
   ListOfStrings.Clear;
   ListOfStrings.Delimiter       := Delimiter;
//   ListOfStrings.StrictDelimiter := True; // Requires D2006 or newer.
   ListOfStrings.DelimitedText   := Str;
end;

function ParseSelectedString(const SelectedString: string): TStringList;
var
  words: TStringList;
begin
  words := TStringList.Create;
  Split('.', SelectedString, words);

  Result := TStringList.Create;

  if (words.count = 0) then
    begin
      ShowMessage('Empty string has been selected');
      Result.add('');
      Result.add('');
    end
  else if (words.count > 2) then
    begin
      ShowMessage('Wrong string is selected');
      Result.add('');
      Result.add('');
    end
  else if (words.count = 1) then
    begin
      ShowMessage('one word ' + words[0]);
      Result.add('');
      Result.add(words[0]);
    end
  else //2
    begin
      ShowMessage('2 words ' + words[0] + '-' + words[1]);
      Result.add(words[0]);
      Result.add(words[1]);
    end
end;

function GetSynonymsByTable(const SelectedString: string): TStringList;
var
  Query: string;
  index: Integer;

  words: TStringList;
begin
  words :=  ParseSelectedString(SelectedString);
  ShowMessage(words[0] + '-' + words[1]);

  Query := 'SELECT synonym_name from all_synonyms '
      + ' WHERE table_owner = UPPER(NVL(''' + words[0] + ''', table_owner))'
      + ' AND table_name = UPPER(''' + words[1] + ''')'
      + ' ORDER BY CASE WHEN synonym_owner = USER THEN 1 ELSE 2 END';
  ShowMessage(Query);
  SQL_Execute(PChar(Query));
  index := SQL_FieldIndex('SYNONYM_NAME');

  Result := TStringList.Create;

  while not SQL_Eof do
  begin
    Result.Add(SQL_Field(index));
  end;
end;

procedure ShowSynonymsByTable(const SelectedString: string) ;
var
  Synonyms: TStringList;
begin
  Synonyms := GetSynonymsByTable(SelectedString);
  ShowMessage(Synonyms.Text);
end;

function getTableBySynonym(const SelectedString: string): string;
var
  Query: string;
  index: Integer;
  words: TStringList;
begin
  words :=   ParseSelectedString(SelectedString);

  Query := 'Select  from all_synonyms '
      + ' WHERE synonym_owner = UPPER(NVL(''' + words[0] + ''', synonym_owner))'
      + ' AND synonym_name = UPPER(''' + words[1] + ''')';
  SQL_Execute(PChar(Query));
  index := SQL_FieldIndex('SYNONYM_NAME');
  // Get first row. If several rows are expected -- rewrite query to get the most valuable result first (or aggregate results)
  if not SQL_Eof then
  begin
    Result := SQL_Field(index);
  end;
end;

// The menu item got selected
procedure OnMenuClick(Index: Integer);  cdecl;
begin
  case Index of
    1 : ShowSynonymsByTable(IDE_GetCursorWord);
    2 : ShowMessage(IDE_GetCursorWord);
    3 : ShowMessage(IDE_GetCursorWord);
  end;
end;

exports // The three basic export functions
  IdentifyPlugIn,
  CreateMenuItem,
  RegisterCallback,
  OnMenuClick,
  OnActivate;

end.


