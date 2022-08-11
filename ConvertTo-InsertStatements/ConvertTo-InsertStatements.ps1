<#
	.SYNOPSIS
		Converts a tabular object to a multi-row insert statement
	
	.DESCRIPTION
		A quick way to create multi-row insert statements from an array of objects that all  
		have the same keys in the same order for every row.  You'd get this from reading 
		in a JSON result. You can specify a list of one or more columns to exclude, and 
		can provide a SQL at the start and end. 
	
	.PARAMETER TheObject
		an array of psCustomObjects, each of which have the same noteproperty names for the 
		column values
	
	.PARAMETER TheTableName
		A description of the TheTableName parameter.
	
	.PARAMETER Batch
		how many lines should we batch up in an insert statement. (performance)
	
	.PARAMETER Exclude
		list of columns in the table  to exclude from the insert.
	
	.PARAMETER Prequel
		A sql command to include before the insert. This can include a placeholder 
		for the name of the table, (${table}) so you can create a looping construct 
		with the same SQL
	
	.PARAMETER Sequel
		A sql command to append  after the end of the insert.This can include a placeholder
		for the name of the table, (${table}) so you can create a looping construct
		with the same SQL

	.PARAMETER Rule
		Where it is impossible to do the conversion from the json datatype (string, number 
        boolean null true false) to the database type, you can add a conversion for a column
        by specifying the column. e.g. $MyRules=@{'logo-column'='CONVERT(VARBINARY(MAX),xxx)'}
        the column has a '-column' suffix to add to clarity. xxx represents the json value.
	
	.EXAMPLE
		PS C:\> ConvertTo-InsertStatements MyObjectReadFromJSON 'MyTableName'
	
	.NOTES
		Additional information about the function.
#>
function ConvertTo-InsertStatements
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true,
				   Position = 1)]
		[Object[]]$TheObject,
		[Parameter(Mandatory = $true,
				   Position = 2)]
		[string]$TheTableName,
		[Parameter(Mandatory = $false,
				   Position = 3)]
		[int]$Batch = 500,
		[Parameter(Mandatory = $false,
				   Position = 4)]
		[Array]$exclude = @(),
		[Parameter(Mandatory = $false,
				   Position = 5)]
		[string]$Prequel = $null,
		[Parameter(Mandatory = $false,
				   Position = 6)]
		[string]$Sequel = $null,
        [Parameter(Mandatory = $false,
				   Position = 7)]
		[Object[]]$Clause = '',
        [Parameter(Mandatory = $false,
				   Position = 8)]
		[Object[]]$Rules = $null
	)
	
	if ($Prequel -ne $null) { "$Prequel" -ireplace '\${table}', $TheTableName };

	$TheObject | ForEach-Object -Begin { $lines = @(); $ii = $Batch; } -Process {
		$line = $_;
		$LineProperties = $line.PSObject.Properties
		if ($ii -eq $batch)
		{
			$Names = $LineProperties | foreach{ $_.Name }|where {$_ -notin $exclude}
			#start a new query (batch them up into rows - there is an optimal amount)
			"INSERT INTO $TheTableName ($($Names -join ', '))`r`n  $clause VALUES"
			$Beginning = $false;
		}
		$Values = $LineProperties | where {$_.Name -notin $exclude} | foreach{
            if ($_.Value -eq $null) { 'NULL' }
			elseif ($_.Value.ToString() -eq 'NULL') { 'NULL' }
			elseif ($_.TypeNameOfValue -eq 'System.String') {
             $TheString='''' + $_.Value.Replace("'","''") + '''' 
             
             if ($Rules.("$($_.Name)-column") -ne $null)
                    {
                    #write-warning "$($_.Name)-column Rule was used for $($_.Name)!"
                    $TheRule=[string]$Rules.("$($_.Name)-column")
                    $TheRule.replace('xxx',$TheString)}
             else {$TheString}
             }
			elseif ($_.TypeNameOfValue -eq 'System.Boolean') { if ($_.Value) {'1'} else {'0'}}
             else { $_.Value }
		}
		$lines += "($($Values -join ', '))";
		if ($ii-- -eq 1)
		{
			($Lines -join ",`r`n") + ';'
			$ii = $Batch;
			$lines = @();
		}
	} -end { ($Lines -join ",`r`n") + ';' }
	
	if ($Sequel -ne $null) { "$Sequel" -ireplace '\${table}', $TheTableName };
}
