<#
	.SYNOPSIS
		Gets the metadata of any ODBC connection (any database with a good driver
		So far, only tested with SQL Server, Postgres, sqlite  and MariaDB. All were very
		different
	
	.DESCRIPTION
		This uses two techniques. Where the ODBC driver has a GetSchema function
		in its connection object, it uses that. Where it can't, it uses the 
		Information_schema. 
        SQL Server, Azure SQL Database, MySQL, PostgreSQL, MariaDB, Amazon Redshift,
		Snowflake and Informix	have information_schema, but all with variations
		so I need to test each one!
	
	.PARAMETER ODBCConnection
		This requires an ODBC connection. It doesn't have to be open
	
	.PARAMETER WantsComparableObject
		This is for when you want to compare two databases easily.
	
	.EXAMPLE
		$connpsql = new-object system.data.odbc.odbcconnection
		$connpsql.connectionstring = "DSN=PostgreSQL;"
		Get-ODBCSourceMetadata -ODBCConnection $connpsql
	
	.NOTES
		
#>


function Get-ODBCSourceMetadata
{
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param
	(
		[Parameter(Mandatory = $true,
				   Position = 1)]
		[system.data.odbc.odbcconnection]$ODBCConnection,
		[Parameter(Position = 2)]
		[boolean]$WantsComparableObject = $false
	)
	
	try
	{
		if ($ODBCConnection.State -ne 'Open') { $ODBCConnection.Open() }
	}
	catch
	{
		Write-Error "Sadly, I could not open the ODBC connection $($_.Exception.Message)"
	}
	
	if ($ODBCConnection.Driver -eq 'maodbc.dll') #has it a bug in its metadata?
	{
		#We have to use the information schema
		$query = @'
SELECT CONCAT( table_schema, '.',TABLE_NAME) AS NAME, 
	replace(TABLE_Type,'BASE ','') AS TYPE 
FROM information_schema.TABLES  
  WHERE table_schema NOT IN 
    ('information_schema','mysql','performance_schema','sys')
'@
		$cmd = New-object System.Data.Odbc.OdbcCommand($query, $ODBCConnection)
		$ds = New-Object system.Data.DataSet
		(New-Object system.Data.odbc.odbcDataAdapter($cmd)).fill($ds) | out-null
		$TablesAndViews = $ds.Tables[0].Rows
		$query = @'
SELECT 
  CONCAT( table_schema, '.',TABLE_NAME) AS The_NAME, 
  concat(COLUMN_NAME,' ',column_Type,case when IS_NULLABLE='NO' then ' NOT NULL ' ELSE '' end,case when Column_Default IS NOT NULL then CONCAT(' DEFAULT(',Column_Default,')') ELSE '' end ) AS The_COLUMN 
FROM information_schema.columns 
WHERE table_schema NOT IN ('information_schema','mysql','performance_schema','sys')
ORDER BY table_schema, TABLE_NAME, ordinal_Position
'@
		$cmd = New-object System.Data.Odbc.OdbcCommand($query, $ODBCConnection)
		$ds = New-Object system.Data.DataSet
		(New-Object system.Data.odbc.odbcDataAdapter($cmd)).fill($ds) | out-null
		$TablesAndColumns = $ds.Tables[0].Rows
		$query = @'
SELECT CONCAT( routine_schema, '.',routine_NAME) AS NAME, 
r.routine_Type as Type, 
concat(Parameter_name,' ',p.DTD_Identifier) AS parameter
FROM information_schema.routines r
left outer join information_schema.Parameters p
  ON  r.routine_schema=p.SPECIFIC_SCHEMA
  AND r.routine_Name=p.SPECIFIC_NAME
WHERE r.routine_schema NOT IN ('sys')
'@
		$cmd = New-object System.Data.Odbc.OdbcCommand($query, $ODBCConnection)
		$ds = New-Object system.Data.DataSet
		(New-Object system.Data.odbc.odbcDataAdapter($cmd)).fill($ds) | out-null
		$RoutinesAndParameters = $ds.Tables[0].Rows
		$query = @'
SELECT CONCAT( table_schema, '.',TABLE_NAME) AS The_NAME, 
index_Name , 
Group_concat(COLUMN_NAME ORDER BY seq_in_index SEPARATOR ', ') AS columns
  FROM information_schema.STATISTICS
  WHERE index_schema NOT IN ('sys','mysql')
GROUP BY table_schema,  TABLE_NAME, index_Name 
'@
		$cmd = New-object System.Data.Odbc.OdbcCommand($query, $ODBCConnection)
		$ds = New-Object system.Data.DataSet
		(New-Object system.Data.odbc.odbcDataAdapter($cmd)).fill($ds) | out-null
		$IndexesAndColumns = $ds.Tables[0].Rows
		
		$MetadataObject = $TablesAndViews + ($RoutinesAndParameters | select Name, Type -Unique) |
		foreach{
			$CurrentName = $_.NAME
			$Parameters = @()
			if ($_.TYPE -eq 'PROCEDURE')
			{
				$Parameters += $RoutinesAndParameters | where { $_.Name -eq $CurrentName } | foreach{ "($($_.parameter) )" }
			}
			$Columns = @()
			$Columns += $TablesAndColumns | where { $_.The_Name -eq $CurrentName } | foreach{ "($($_.The_COLUMN) )" }
			$Indexes = @()
			$Indexes += $IndexesAndColumns | where { $_.The_Name -eq $CurrentName } | foreach{ "$($_.index_name) ($($_.Columns) )" }
			[pscustomobject]@{ 'Name' = "$CurrentName"; 'Type' = $_.Type; 'Columns' = $Columns; 'indexes' = $Indexes; 'Parameters' = $Parameters }
		}
	}
	else
	{
		#We can use the GetSchema successfully.
		$MetaCollections = $ODBCConnection.GetSchema('MetaDataCollections')
		$WeHaveProceduresOrFunctions = (($MetaCollections |
				where { $_.collectionName -eq 'Procedures' }) -ne $null)
		
		#get a list of base objects Tables views, functions and procedures.
		$ListOfObjects = $ODBCConnection.GetSchema('Tables') + $ODBCConnection.GetSchema('VIEWS') |
		where {
			$_.TABLE_SCHEM -notin @('sys', 'pg_catalog', 'INFORMATION_SCHEMA') -and
			$_.Table_TYPE -notlike 'System*' -and ($_.TABLE_CAT -notin @('performance_schema', 'sys', 'mysql'))
		} | foreach{
			
			[pscustomobject]@{
				'Name' = "$(if ([string]::IsNullOrEmpty($_.TABLE_SCHEM)) { $_.TABLE_CAT }
					else { $_.TABLE_SCHEM }).$($_.TABLE_NAME)";
				'Type' = "$($_.TABLE_TYPE)";
			}
		}
		if ($WeHaveProceduresOrFunctions)
		{
			$ListOfObjects += $ODBCConnection.GetSchema('Procedures') |
			where { $_.PROCEDURE_SCHEM -notin @('sys', 'pg_catalog', 'INFORMATION_SCHEMA') } |
			foreach{
				$Name = ($_.PROCEDURE_NAME -split ';')[0]
				$Typecode = ($_.PROCEDURE_NAME -split ';')[1]
				$Type = 'Routine'
				if ($Typecode -eq 1) { $Type = 'Procedure' }
				if ($Typecode -eq 0) { $Type = 'Function' }
				if ($Typecode -eq 2) { $Type = 'TVF' }
				[pscustomobject]@{
					'Name' = "$($_.PROCEDURE_SCHEM).$($Name)"; 'Type' = "$Type";
				}
			}
		}
		$MetadataObject = $ListOfObjects | ForEach-Object {
			$SplitDataObjectName = $_.NAME -split '\.' #split the object name to allow metadata calls
			$Columns = @()
			$Indexes = @()
			$Parameters = @()
			$Columns = $ODBCConnection.GetSchema('Columns', ([string[]] @($ODBCConnection.database, $SplitDataObjectName[0], $SplitDataObjectName[1]))) |
			foreach{ "$($_.COLUMN_NAME) $($_.TYPE_NAME)$(if ($_.TYPE_NAME -like '*char') { "($($_.COLUMN_SIZE))" }) $(if ($_.NULLABLE -in @('NO', 0)) { 'NOT ' })NULL" }
			
			if ($_.Type -ieq 'TABLE')
			{
				$indexes = $ODBCConnection.GetSchema('Indexes', ([string[]] @($ODBCConnection.database, $SplitDataObjectName[0], $SplitDataObjectName[1]))) |
				foreach{ "$($_.Index_Name)($($_.Column_Name))" }
			}
			if ($_.Type -in @('Function', 'Routine', 'procedure', 'TVF'))
			{
				$parameters = $ODBCConnection.GetSchema('ProcedureParameters', ([string[]] @($ODBCConnection.database, $SplitDataObjectName[0], $SplitDataObjectName[1]))) |
				foreach{ "$($_.COLUMN_NAME) $($_.TYPE_NAME)$(if ($_.TYPE_NAME -like '*char') { "($($_.COLUMN_SIZE))" }) $(if ($_.NULLABLE -in @('NO', 0)) { 'NOT ' })NULL" }
			}
			[pscustomobject]@{
				'Name' = $_.Name; 'Type' = $_.Type; 'columns' = $Columns; 'Indexes' = $indexes;
				'Parameters' = $Parameters
			}
		}
	}
	if ($WantsComparableObject)
	{
		$Metadata = @{ }
		$MetadataObject | foreach{
			$ThisObject = @{ 'Type' = "$($_.Type)"; }
			if ($_.Columns -ne $null) { $ThisObject += @{ 'Columns' = $_.Columns } }
			if ($_.Indexes -ne $null) { $ThisObject += @{ 'Indexes' = $_.Indexes } }
			if ($_.Parameters -ne $null) { $ThisObject += @{ 'Parameters' = $_.Parameters } }
			$Metadata += @{ "$($_.Name)" = $ThisObject }
		}
		$Metadata
	}
	else
	{ $MetadataObject }
}