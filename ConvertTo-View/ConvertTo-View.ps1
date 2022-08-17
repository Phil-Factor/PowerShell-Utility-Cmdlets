<#
	.SYNOPSIS
		Converts a tabular object to a read-only view for any type of SQL Server database
	
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
		RDBMSs seem to conform to one of three types of syntax,  the MySQL syntax (a CTE),
		the SQL Server/Postgresql table-bale Constructor (TVC) syntax of the DDL code for
		the view, or if nothing else the UNION ALL expression (UNA)


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
	$firstLine = $true
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
			$TheColumn = $_;
			if ($TheColumn.Value -eq $null) { 'NULL' }
			elseif ($TheColumn.Value.ToString() -eq 'NULL') { 'NULL' }
			elseif ($TheColumn.TypeNameOfValue -eq 'System.String')
			{
				$TheString = '''' + $TheColumn.Value.Replace("'", "''").Trim() + ''''
				
				if ($Rules.("$($TheColumn.Name)-column") -ne $null)
				{
					#write-warning "$($_.Name)-column Rule was used for $($_.Name)!"
					$TheRule = [string]$Rules.("$($TheColumn.Name)-column")
					$TheRule.replace('xxx', $TheString)
				}
				else { $TheString }
			}
			elseif ($TheColumn.TypeNameOfValue -eq 'System.Boolean')
			{
				if ($TheColumn.Value) { '1' }
				else { '0' }
			}
			elseif ($TheColumn.TypeNameOfValue -eq 'System.DateTime')
			{ '''' + $TheColumn.Value + '''' }
			else { $TheColumn.Value }
		} | foreach{
			if ($firstLine -and $style -notin @('TVC', 'CTE'))
			{ "$($_) AS `"$($TheColumn.Name)`"" }
			else { $_ }
		}
		$lines += "$($Values -join ', ')";
		$FirstLine = $False;
	}
	
	$joinString = "),`r`n(";
	
	If ($Style -eq 'TVC')
	{
@"
CREATE VIEW $TheNameOfTheView
AS
  SELECT $columnList
    FROM
      ( VALUES ($($Lines -join $joinString))) AS xxx (
    $columnList);
"@
	}
	elseIf ($Style -eq 'CTE')
	{@"
CREATE VIEW $TheNameOfTheView
as
WITH  xxx($columnList) as 
  (VALUES ($($Lines -join $joinstring)))
select $columnList from xxx;

"@
	}
	else
	{ @"
CREATE VIEW $TheNameOfTheView
as
SELECT $($Lines -join "`r`nUNION ALL`r`n SELECT ");
"@
	}
	
}
