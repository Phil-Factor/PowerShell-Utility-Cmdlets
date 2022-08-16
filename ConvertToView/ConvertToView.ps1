<#
	.SYNOPSIS
		Converts a tabular object to a read-only view for SQL Server, PostgreSQL, MySQL, 
        MriaDB and SQLite
	
	.DESCRIPTION
		A quick way to create the code for a view from an array of objects that all  
		have the same keys in the same order for every row.  You'd get this from reading 
		in a JSON result. You can specify a list of one or more columns to exclude
	
	.PARAMETER TheObject
		an array of psCustomObjects, each of which have the same noteproperty names for the 
		column values
	
	.PARAMETER TheNameOfTheView
		A description of the TheNameOfTheView parameter.
	
	.PARAMETER Exclude
		list of columns/Keys in the tabular object  to exclude from the view.

	.PARAMETER TypeOfView
		RDBMSs seem to conform to either the MySQL syntax (a CTE) or the SQL Server/Postgresql 
        table-bale Constructor (TVC) syntax of the DDL code for the view


	.EXAMPLE
		PS C:\> ConvertToView MyObjectReadFromJSON 'TheNameOfTheView'
	

#>
function ConvertTo-View
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
		[string]$TheNameOfTheView,
		[Parameter(Mandatory = $False,
				   Position = 3)]
		[string]$style = 'TVC',
		[Parameter(Mandatory = $false,
				   Position = 4)]
		[Array]$exclude = @(),
		[Parameter(Mandatory = $false,
				   Position = 5)]
		[Object[]]$Rules = $null
	)
	$Lines = @()
	$columnList = @()
	$TheValuesStatements =
	$TheObject | ForEach-Object {
		$line = $_;
		$LineProperties = $line.PSObject.Properties
		If ($columnList.count -eq 0)
		{
			$columnList = ($LineProperties | where { $_.Name -notin $exclude } | foreach{
					$_.Name
				}
			) -join ', '
		}
		$Values = $LineProperties | where { $_.Name -notin $exclude } | foreach{
			if ($_.Value -eq $null) { 'NULL' }
			elseif ($_.Value.ToString() -eq 'NULL') { 'NULL' }
			elseif ($_.TypeNameOfValue -eq 'System.String')
			{
				$TheString = '''' + $_.Value.Replace("'", "''").Trim() + ''''
				
				if ($Rules.("$($_.Name)-column") -ne $null)
				{
					#write-warning "$($_.Name)-column Rule was used for $($_.Name)!"
					$TheRule = [string]$Rules.("$($_.Name)-column")
					$TheRule.replace('xxx', $TheString)
				}
				else { $TheString }
			}
			elseif ($_.TypeNameOfValue -eq 'System.Boolean')
			{
				if ($_.Value) { '1' }
				else { '0' }
			}
			elseif ($_.TypeNameOfValue -eq 'System.DateTime') { '''' + $_.Value + '''' }
			else { $_.Value }
		}
		$lines += "($($Values -join ', '))";
	}
	
	
	If ($Style -eq 'TVC')
	{@"
CREATE VIEW $TheNameOfTheView
AS
  SELECT $columnList
    FROM
      ( VALUES $($Lines -join ",`r`n")) AS xxx (
    $columnList);
"@
	}
	else
	{ @"
CREATE VIEW $TheNameOfTheView
as
WITH  xxx($columnList) as 
  (VALUES $($Lines -join ",`r`n"))
select $columnList from xxx;

"@
	}
	
}