<#
	.SYNOPSIS
		Converts a tabular object to a multi-row insert statement
	
	.DESCRIPTION
		A quick way to create multi-row insert statements from an array of objects that all  have the same keys in the same order for every row.  You'd get this from reading in a JSON result.
	
	.PARAMETER TheObject
		an array of psCustomObects, each of which have the same noteproperty names for the Nvalues
	
	.PARAMETER TheTableName
		A description of the TheTableName parameter.
	
	.PARAMETER
		A description of the  parameter.
	
	.EXAMPLE
		PS C:\> ConvertTo-InsertStatements - $value1
	
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
		[int]$Batch =500
	)

$TheObject | ForEach-Object -Begin{$lines=@();$ii=$Batch;} -Process{
    $line=$_; 
    $LineProperties=$line.PSObject.Properties
    if ($ii -eq $batch) {
        $Names=$LineProperties |foreach{$_.Name}
        #start a new query (batch them up into rows - there is an optimal amount)
        "INSERT INTO $table ($($Names -join ', '))`r`n  VALUES"
        $Beginning = $false;
        }
    $Values= $LineProperties|foreach{
        if ($_.TypeNameOfValue -eq 'System.String'){'"'+$_.Value+ '"'} else {$_.Value}
        } 
    $lines+="($($Values -join ', '))";
    if ($ii-- -eq 0) {
        ($Lines -join ",`r`n")+';'
        $ii=$Batch;
        $lines=@();
        }
    }  -end{($Lines -join ",`r`n")+';'}
}
