<#
	.SYNOPSIS
		Simple break down into the essential units
	
	.DESCRIPTION
		Takes a sql string and produces a stream of its component parts such as comments, strings numbers, identifiers and so on.
	
	.PARAMETER SQLString
		A description of the SQLString parameter.
	
	.PARAMETER parserRegex
		A description of the parserRegex parameter.
	
	.PARAMETER ReservedWords
		A description of the ReservedWords parameter.
	
	.EXAMPLE
		PS C:\> Tokenize_SQLString -SQLString 'Value1'
	Tokenize_SQLString -SQLString$SecondSample
	.NOTES
		Additional information about the function.
#>
function Tokenize_SQLString
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true)]
		[string]$SQLString,
		[regex]$parserRegex = $null,
		[array]$ReservedSQLWords = @()
	)
	
	if ($parserRegex -eq $null)
	{
		$parserRegex = [regex]@'
(?i)(?s)(?<JavaDoc>/\*\*.*?\*\*/)|(?#
)(?<BlockComment>/\*.*?\*/)|(?#
)(?<EndOfLineComment>--[^\n\r]*)|(?#
)(?<String>N?'.*?')|(?#
)(?<number>[+\-]?\d+\.?\d{0,100}[+\-0-9E]{0,6})|(?#
)(?<SquareBracketed>\[.{1,255}?\])|(?#
)(?<Quoted>".{1,255}?")|(?#
)(?<Identifier>[@]?[\p{N}\p{L}_][\p{L}\p{N}@$#_]{0,127})|(?#
)(?<Operator><>|<=>|>=|<=|==|=|!=|!|<<|>>|<|>|\|\||\||&&|&|-|\+|\*(?!/)|/(?!\*)|\%|~|\^|\?)|(?#
)(?<Punctuation>[^\w\s\r\n])
'@
	}
	$LineRegex = [regex]'(\r\n|\r|\n)';
<# we need to know the SQL reserved words #>
	$ReservedSQLWords = @(
		'ABSOLUTE', 'ACTION', 'ADD', 'ADMIN', 'AFTER', 'AGGREGATE', 'ALIAS', 'ALL', 'ALLOCATE',
		'ALTER', 'AND', 'ANY', 'ARE', 'ARRAY', 'AS', 'ASC', 'ASSERTION', 'ASSERTION', 'AT', 'ATOMIC',
		'AUTHORIZATION', 'BEFORE', 'BEGIN', 'BIGINT', 'BINARY', 'BIT', 'BLOB', 'BOOLEAN', 'BOTH',
		'BREADTH', 'BY', 'CALL', 'CASCADE', 'CASCADED', 'CASE', 'CAST', 'CATALOG', 'CHAR',
		'CHARACTER', 'CHECK', 'CLASS', 'CLOB', 'CLOSE', 'COLLATE', 'COLLATION', 'COLLECT', 'COLUMN',
		'COMMIT', 'COMPLETION', 'CONDITION', 'CONNECT', 'CONNECTION', 'CONSTRAINT', 'CONSTRAINTS',
		'CONSTRUCTOR', 'CONTAINS', 'CONTINUE', 'CORRESPONDING', 'CREATE', 'CROSS', 'CUBE', 'CURRENT',
		'CURRENT_DATE', 'CURRENT_PATH', 'CURRENT_ROLE', 'CURRENT_TIME', 'CURRENT_TIMESTAMP',
		'CURRENT_USER', 'CURSOR', 'CYCLE', 'DATA', 'DATALINK', 'DATE', 'DAY', 'DEALLOCATE',
		'DEC', 'DECIMAL', 'DECLARE', 'DEFAULT', 'DEFERRABLE', 'DELETE', 'DEPTH', 'DEREF', 'DESC',
		'DESCRIPTOR', 'DESTRUCTOR', 'DIAGNOSTICS', 'DICTIONARY', 'DISCONNECT', 'DO', 'DOMAIN', 'DOUBLE',
		'DROP', 'ELEMENT', 'END', 'END-EXEC', 'EQUALS', 'ESCAPE', 'EXCEPT', 'EXCEPTION', 'EXECUTE',
		'EXIT', 'EXPAND', 'EXPANDING', 'FALSE', 'FIRST', 'FLOAT', 'FOR', 'FOREIGN', 'FREE',
		'FROM', 'FUNCTION', 'FUSION', 'GENERAL', 'GET', 'GLOBAL', 'GO', 'GOTO', 'GROUP', 'GROUPING',
		'HANDLER', 'HASH', 'HOUR', 'IDENTITY', 'IF', 'IGNORE', 'IMMEDIATE', 'IN', 'INDICATOR',
		'INITIALIZE', 'INITIALLY', 'INNER', 'INOUT', 'INPUT', 'INSERT', 'INT', 'INTEGER', 'INTERSECT',
		'INTERSECTION', 'INTERVAL', 'INTO', 'IS', 'ISOLATION', 'ITERATE', 'JOIN', 'KEY', 'LANGUAGE',
		'LARGE', 'LAST', 'LATERAL', 'LEADING', 'LEAVE', 'LEFT', 'LESS', 'LEVEL', 'LIKE', 'LIMIT',
		'LOCAL', 'LOCALTIME', 'LOCALTIMESTAMP', 'LOCATOR', 'LOOP', 'MATCH', 'MEMBER', 'MEETS',
		'MERGE', 'MINUTE', 'MODIFIES', 'MODIFY', 'MODULE', 'MONTH', 'MULTISET', 'NAMES', 'NATIONAL',
		'NATURAL', 'NCHAR', 'NCLOB', 'NEW', 'NEXT', 'NO', 'NONE', 'NORMALIZE', 'NOT', 'NULL',
		'NUMERIC', 'OBJECT', 'OF', 'OFF', 'OLD', 'ON', 'ONLY', 'OPEN', 'OPERATION', 'OPTION',
		'OR', 'ORDER', 'ORDINALITY', 'OUT', 'OUTER', 'OUTPUT', 'PAD', 'PARAMETER', 'PARAMETERS',
		'PARTIAL', 'PATH', 'PERIOD', 'POSTFIX', 'PRECEDES', 'PRECISION', 'PREFIX', 'PREORDER',
		'PREPARE', 'PRESERVE', 'PRIMARY', 'PRIOR', 'PRIVILEGES', 'PROCEDURE', 'PUBLIC', 'READ',
		'READS', 'REAL', 'RECURSIVE', 'REDO', 'REF', 'REFERENCES', 'REFERENCING', 'RELATIVE',
		'REPEAT', 'RESIGNAL', 'RESTRICT', 'RESULT', 'RETURN', 'RETURNS', 'REVOKE', 'RIGHT',
		'ROLE', 'ROLLBACK', 'ROLLUP', 'ROUTINE', 'ROW', 'ROWS', 'SAVEPOINT', 'SCHEMA', 'SCROLL',
		'SEARCH', 'SECOND', 'SECTION', 'SELECT', 'SEQUENCE', 'SESSION', 'SESSION_USER', 'SET',
		'SETS', 'SIGNAL', 'SIZE', 'SMALLINT', 'SPECIFIC', 'SPECIFICTYPE', 'SQL', 'SQLEXCEPTION',
		'SQLSTATE', 'SQLWARNING', 'START', 'STATE', 'STATIC', 'STRUCTURE', 'SUBMULTISET',
		'SUCCEEDS', 'SUM', 'SYSTEM_USER', 'TABLE', 'TABLESAMPLE', 'TEMPORARY', 'TERMINATE',
		'THAN', 'THEN', 'TIME', 'TIMESTAMP', 'TIMEZONE_HOUR', 'TIMEZONE_MINUTE', 'TO', 'TRAILING',
		'TRANSACTION', 'TRANSLATION', 'TREAT', 'TRIGGER', 'TRUE', 'UESCAPE', 'UNDER', 'UNDO',
		'UNION', 'UNIQUE', 'UNKNOWN', 'UNTIL', 'UPDATE', 'USAGE', 'USER', 'USING', 'VALUE',
		'VALUES', 'VARCHAR', 'VARIABLE', 'VARYING', 'VIEW', 'WHEN', 'WHENEVER', 'WHERE',
		'WHILE', 'WITH', 'WRITE', 'YEAR', 'ZONE');
	
	
	# we start by breaking the string up into a pipeline of objects according to the
    # type of string. First get the match objects
	$allmatches = $parserRegex.Matches($SQLString)
    # we also break the script up into lines so we can say where each token is 
	$Lines = $Lineregex.Matches($SQLString); #get the offset where lines start
	# we put each token through a pipeline to attach the line and column for 
    # each token 
    $allmatches | foreach  {
		$_.Groups | where { $_.success -eq $true -and $_.name -ne 0 }
	} | # now we convert each object with the columns we later calculate 
	Select name, index, length, value,
		   @{ n = "Type"; e = { '' } }, @{ n = "line"; e = { 0 } },
		   @{ n = "column"; e = { 0 } } | foreach -Begin {
		$state = 'not'; $held = @(); $FirstIndex = $null; $Theline = 1; $token=$null;
	}{
		#get the value, save the previous value, and try to identify the nature of the token
		$PreviousToken=$Token;
        $Token = $_;
		$ItsAnIdentifier = ($Token.name -in ('SquareBracketed', 'Quoted', 'identifier'));
		if ($ItsAnIdentifier)
		{#strip delimiters out to get the value inside
            $TheString=switch ($Token.name )
            {
            'SquareBracketed' { $Token.Value.TrimStart('[').TrimEnd(']') }
            'Quoted' { $Token.Value.Trim('"') }
            default {$Token.Value}
            }
            $Token.Type = $Token.Name; 
            # Catch local identifiers in some RDBMSs with leading '@'
            if ($Token.Type -eq 'identifier' -and $Token.Value -like '@*')
                {$Token.Type='LocalIdentifier'}    
            # distinguish krywords from references.    
			if ($TheString -in $ReservedSQLWords) #
			{ $Token.Name='Keyword';  $ItsAnIdentifier=$false }
			else
			{ $Token.Name = 'Reference' }
            
		} #Now we calculate the location
		$TheIndex = $Token.Index;
		While ($lines.count -gt $TheLine -and #do we bump the line number
			$lines[$TheLine - 1].Index -lt $TheIndex)
		{ $Theline++ }
		$TheStart = switch
		($Theline)
		{
			({ $PSItem -le 2 }) { 0 }
			Default { $lines[$TheLine - 2].Index }
		}
		$TheColumn = $TheIndex - $TheStart; 
        #index of where we found the token - index of start of line
        #now we record the location
		$Token.'Line' = $TheLine; $Token.'Column' = $TheColumn;
        # we now need to extract the multi-part identifiers, and determine 
        # what is just a local identifier.
		$ItsADot = ($_.name -eq 'Punctuation' -and $_.value -eq '.')
        $ItsAnAS = ($_.name -eq 'Keyword' -and $_.value -eq 'AS')
        Write-Verbose "Itsanas=$ItsAnAS itsanidentifier=$ItsAnIdentifier state-$State type=$($token.type) name=$($token.Name) value=$($token.Value) previousTokenValue=$($previousToken.Value) CTE=$cte"       
		switch ($state)
		{
			'not' {
				if ($ItsAnIdentifier -and $token.type -ne 'localIdentifier')
                # local identifiers cannot be multi-part identifiers
				{ $Held += $token; $FirstIndex = $token.index; 
                  $CTE=($previousToken.Value -in ('WITH',','));
                  $FirstLine = $TheLine; $FirstColumn = $TheColumn; $state = 'first'; }
				else { write-output $token }
				break
			}
			
			'first' {
				if ($ItsADot) { $state = 'another'; }
				elseif ($ItsAnIdentifier) 
                    {write-output $held; $held = @(); $Held += $token }
                elseif ($ItsAnAS -and $CTE)
                    {$state = 'not'; $held[0].type='localIdentifier';
                     write-output $held; write-output $token; $held = @(); }
                else
                    { write-output $held; write-output $token; $held = @(); $state = 'not' }
				; break
			}
			'another' { if (!($ItsADot)) {$state = 'following'} else {$Token.Value=''};
                       $Held += $token; break }
			'following' {
				if ($ItsADot) { $state = 'another' }
				else
				{
					$held | foreach -begin { $length = 0; $ref = "" } {
						$ref = "$ref.$($_.value.trim())"; $length += $_.length;
					}
					$ref = $ref.trim('.')
					[psCustomObject]@{
						'Name' = 'identifier'; 'index' = $FirstIndex; 'Length' = $length;
						'Value' = $ref; 'Type' = "$($Held.Count)-Part Dotted Reference";
						'Line' = $FirstLine; 'Column' = $FirstColumn
					}
					Write-output $token
					$held = @()
					$state = 'not'
				}
			} # end more
			
		} # end switch	
		
	} -End{if ($state -ne 'not') 
        {
        $held | foreach -begin { $length = 0; $ref = "" } {
						$ref = "$ref.$($_.value.trim())"; $length += $_.length;
					}
					$ref = $ref.trim('.')
					[psCustomObject]@{
						'Name' = 'identifier'; 'index' = $FirstIndex; 'Length' = $length;
						'Value' = $ref; 'Type' = "$($Held.Count)-Part Dotted Reference";
						'Line' = $FirstLine; 'Column' = $FirstColumn
					}
					#Write-output $token
        }
        }
}

#-----sanity checks
$Correct="CREATE VIEW [dbo].[titleview] /* this is a test view */ AS --with comments select 'Report' , title , au_ord , au_lname , price , ytd_sales , pub_id from authors , titles , titleauthor where authors.au_id = titleauthor.au_id AND titles.title_id = titleauthor.title_id ;"
$values = @'
CREATE VIEW [dbo].[titleview] /* this is a test view */
AS --with comments
select 'Report', title, au_ord, au_lname, price, ytd_sales, pub_id
from authors, titles, titleauthor
where authors.au_id = titleauthor.au_id
   AND titles.title_id = titleauthor.title_id
;
'@ | Tokenize_SQLString | Select -ExpandProperty Value
$resultingString=($values -join ' ')
if ($resultingString -ne $correct)
{ write-warning "ooh. that first test wasn't right"}


$result=@'
/* we no longer access NotMyServer.NotMyDatabase.NotMySchema.NotMyTable */
-- and we wouldn't use NotMySchema.NotMyTable
Select * from MyServer.MyDatabase.MySchema.MyTable
Print 'We are not accessing NotMyDatabase.NotMySchema.NotMyTable' 
Select * from MyDatabase.MySchema.MyTable
Select * from MyDatabase..MyTable
Select * from MySchema.MyTable
Select * from [My Server].MyDatabase.[My Schema].MyTable
Select * from "MyDatabase".MySchema.MyTable
Select * from MyDatabase..[MyTable]
Select * from MySchema."MyTable"
--of course we don't access NotMyDatabase..[NotMyTable]

'@ |
Tokenize_SQLString | 
     where {$_.type -like '*Part Dotted Reference'}|
        Select Value, line, Type
$ReferenceObject=@'
[{"Value":"MyServer.MyDatabase.MySchema.MyTable","Line":3,"Type":"4-Part Dotted Reference"},
  {"Value":"MyDatabase.MySchema.MyTable","Line":5,"Type":"3-Part Dotted Reference"},
  {"Value":"MyDatabase..MyTable","Line":6,"Type":"3-Part Dotted Reference"},
  {"Value":"MySchema.MyTable","Line":7,"Type":"2-Part Dotted Reference"},
  {"Value":"[My Server].MyDatabase.[My Schema].MyTable","Line":8,"Type":"4-Part Dotted Reference"},
  {"Value":"\"MyDatabase\".MySchema.MyTable","Line":9,"Type":"3-Part Dotted Reference"},
  {"Value":"MyDatabase..[MyTable]","Line":10,"Type":"3-Part Dotted Reference"},
  {"Value":"MySchema.\"MyTable\"","Line":11,"Type":"2-Part Dotted Reference"}
  ]
'@ | convertfrom-json

$BadResults=Compare-Object -Property Value, Line, Type -IncludeEqual -ReferenceObject $ReferenceObject -DifferenceObject $result |
    where {$_.sideIndicator -ne '=='}
if ($BadResults.Count -ne 0) { write-warning "ooh. that second test wasn't right"}


$Correct=[ordered]@{}
$TestValues=[ordered]@{}
$Correct=@'
[{"Name":"Keyword","Value":"CREATE"},{"Name":"Keyword","Value":"TABLE"},{"Name":"Reference","Value":"tricky"},{"Name":"Punctuation","Value":"("},{"Name":"Keyword","Value":"\"NULL\""},{"Name":"Keyword","Value":"[INT]"},{"Name":"Keyword","Value":"DEFAULT"},{"Name":"Keyword","Value":"NULL"},{"Name":"Punctuation","Value":")"},{"Name":"Keyword","Value":"INSERT"},{"Name":"Keyword","Value":"INTO"},{"Name":"Reference","Value":"tricky"},{"Name":"Punctuation","Value":"("},{"Name":"Keyword","Value":"\"NULL\""},{"Name":"Punctuation","Value":")"},{"Name":"Keyword","Value":"VALUES"},{"Name":"Punctuation","Value":"("},{"Name":"Keyword","Value":"NULL"},{"Name":"Punctuation","Value":")"},{"Name":"Keyword","Value":"SELECT"},{"Name":"Keyword","Value":"NULL"},{"Name":"Keyword","Value":"AS"},{"Name":"Keyword","Value":"\"VALUE\""},{"Name":"Punctuation","Value":","},{"Name":"Keyword","Value":"[null]"},{"Name":"Punctuation","Value":","},{"Name":"Keyword","Value":"\"null\""},{"Name":"Punctuation","Value":","},{"Name":"String","Value":"\u0027NULL\u0027"},{"Name":"Keyword","Value":"as"},{"Name":"Reference","Value":"\"String\""},{"Name":"Keyword","Value":"FROM"},{"Name":"Reference","Value":"tricky"},{"Name":"Punctuation","Value":";"}]
'@|convertfrom-json 
$TestValues= Tokenize_SQLString @'
 CREATE TABLE tricky ("NULL" [INT] DEFAULT NULL)
 INSERT INTO tricky ("NULL") VALUES (NULL)
 SELECT NULL AS "VALUE",[null],"null",'NULL'as "String" FROM tricky;
'@|select Name,value
$BadResults=Compare-Object -Property Name, Value -IncludeEqual -ReferenceObject $correct -DifferenceObject $TestValues |
    where {$_.sideIndicator -ne '=='}
if ($BadResults.Count -ne 0) { write-warning "ooh. that third test wasn't right"}
$result=@'
CREATE OR ALTER FUNCTION dbo.PublishersEmployees
(
    @company varchar(30) --the name of the publishing company or '_' for all.
)
RETURNS TABLE AS RETURN
(
SELECT fname
       + CASE WHEN minit = '' THEN ' ' ELSE COALESCE (' ' + minit + ' ', ' ') END
       + lname AS NAME, job_desc, pub_name, person.person_id
  FROM
  employee
    INNER JOIN jobs
      ON jobs.job_id = employee.job_id
    INNER JOIN dbo.publishers
      ON publishers.pub_id = employee.pub_id
	INNER JOIN people.person
	ON person.LegacyIdentifier='em-'+employee.emp_id
	WHERE pub_name LIKE '%'+@company+'%'
)
'@ |Tokenize_SQLString |Where {$_.Type -eq 'LocalIdentifier'}|select  -ExpandProperty value|sort -Unique
if ($result -ne '@company')  { write-warning "ooh. that fourth test checking for '@' variables wasn't right"}


$Result=@'
WITH top_authors
AS (SELECT au.au_id as au, au.au_fname, au.au_lname,
                 SUM (sale.qty) AS total_sales
      FROM
      dbo.authors as au
        JOIN dbo.titleauthor ta
          ON au.au_id = ta.au_id
        JOIN dbo.sales sale
          ON ta.title_id = sale.title_id
      GROUP BY
      au.au_id, au.au_fname, au.au_lname
      ORDER BY total_sales DESC limit 5), avg_sales
AS (SELECT title_id, AVG (qty) AS avg_qty FROM dbo.sales GROUP BY title_id)
  SELECT ta.au_id, ta.au_fname, ta.au_lname, t.title_id, t.title, t.price,
         s.avg_qty
    FROM
    top_authors as ta
      JOIN dbo.titleauthor ta2
        ON ta.au_id = ta2.au_id
      JOIN dbo.titles t
        ON ta2.title_id = t.title_id
      JOIN avg_sales s
        ON t.title_id = s.title_id;
'@  |Tokenize_SQLString  |Where {$_.Type -eq 'LocalIdentifier'}|select  -ExpandProperty value|sort -Unique
if ($result[0] -ne 'avg_sales' -or $result[1] -ne 'top_authors' )
      { write-warning "ooh. that fifth test about the WITH wasn't right"}

# cls
#-----end of sanity check