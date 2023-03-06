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
(?i)(?s)(?<BlockComment>/\*.*?\*/)|(?#
)(?<EndOfLineComment>--[^\n]*?\n)|(?#
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
		'DROP', 'ELEMENT', 'END-EXEC', 'EQUALS', 'ESCAPE', 'EXCEPT', 'EXCEPTION', 'EXECUTE',
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
	
	
	
	$allmatches = $parserRegex.Matches($SQLString);
	$Lines = $Lineregex.Matches($SQLString); #get the offset where lines start
	$allmatches | foreach  {
		$_.Groups | where { $_.success -eq $true -and $_.name -ne 0 }
	} |
	Select name, index, length, value,
		   @{ n = "Type"; e = { '' } }, @{ n = "line"; e = { 0 } },
		   @{ n = "column"; e = { 0 } } | foreach -Begin {
		$state = 'not'; $held = @(); $FirstIndex = $null; $Theline = 1
	}{
		#get the location and value
		$Token = $_;
		if ($Token.name -eq 'identifier')
		{
			if ($Token.Value -in $ReservedSQLWords)
			{ $Token.Type = 'Keyword' }
			else
			{ $Token.Type = 'Reference' }
		}
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
		$Token.'Line' = $TheLine; $Token.'Column' = $TheColumn;
		$ItsAnIdentifier = ($_.name -in ('SquareBracketed', 'Quoted', 'identifier'));
		$ItsADot = ($_.name -eq 'Punctuation' -and $_.value -eq '.')
		switch ($state)
		{
			'not' {
				if ($ItsAnIdentifier)
				{ $Held += $token; $FirstIndex = $token.index; $FirstLine = $TheLine; $FirstColumn = $TheColumn; $state = 'first'; }
				else { write-output $token }
				break
			}
			
			'first' {
				if ($ItsADot) { $state = 'another'; }
				else { write-output $held; write-output $token; $held = @(); $state = 'not' }
				; break
			}
			'another' { $Held += $token; $state = 'following'; break }
			'following' {
				if ($ItsADot) { $state = 'another' }
				else
				{
					write-verbose '---Gotit'
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
		
	}
}



#-----sanity check
$Correct="CREATE VIEW [dbo].[titleview] /* this is a test view */ AS --with comments
 select 'Report' , title , au_ord , au_lname , price , ytd_sales , pub_id from authors , titles , titleauthor where authors.au_id = titleauthor.au_id AND titles.title_id = titleauthor.title_id GO"
$values = @'
CREATE VIEW [dbo].[titleview] /* this is a test view */
AS --with comments
select 'Report', title, au_ord, au_lname, price, ytd_sales, pub_id
from authors, titles, titleauthor
where authors.au_id = titleauthor.au_id
   AND titles.title_id = titleauthor.title_id

GO
'@ | Tokenize_SQLString | Select -ExpandProperty Value
$resultingString=($values -join ' ')
if ($resultingString -ne $correct)
{ write-warning "ooh. that wasn't right"}

#-----end of sanity check