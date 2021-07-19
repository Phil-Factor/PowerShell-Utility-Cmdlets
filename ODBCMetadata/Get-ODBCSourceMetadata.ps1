<#
	.SYNOPSIS
		Gets the metadata of any ODBC connection (any database with a good driver
	
	.DESCRIPTION
		A detailed description of the Get-ODBCSourceMetadata function.
	
	.PARAMETER ODBCConnection
		This requires an ODBC connectionm
	
	.PARAMETER WantsComparableObject
		A description of the WantsComparableObject parameter.
	
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
	
	
	$MetaCollections = $ODBCConnection.GetSchema('MetaDataCollections')
	$WeHaveProceduresOrFunctions = (($MetaCollections |
			where { $_.collectionName -eq 'Procedures' }) -ne $null)
	
	#get a list of base objects Tables views, functions and procedures.
	$ListOfObjects = $ODBCConnection.GetSchema('Tables') + $ODBCConnection.GetSchema('VIEWS') |
	where {
		$_.TABLE_SCHEM -notin @('sys', 'pg_catalog', 'INFORMATION_SCHEMA') -and
		$_.Table_TYPE -notlike 'System*'
	} | foreach{
		[pscustomobject]@{
			'Name' = "$($_.TABLE_SCHEM).$($_.TABLE_NAME)";
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