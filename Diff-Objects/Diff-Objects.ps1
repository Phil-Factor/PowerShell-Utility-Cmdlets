
<#
	.SYNOPSIS
		Used to Compare two powershell objects
	
	.DESCRIPTION
		This compares two powershell objects by determining their shared 
     keys or array sizes and comparing the values of each. It uses the 
     Display-Object cmdlet for the heavy lifting
	
	
	.PARAMETER Ref
		The source object 
	
	.PARAMETER diff
		The target object 
	
	.PARAMETER Avoid
		a list of any object you wish to avoid comparing
	
	.PARAMETER Parent
		Only used for recursion
	
	.PARAMETER Depth
		The depth to which you wish to recurse
	
	.PARAMETER CurrentDepth
		Only used for recursion
	
	.PARAMETER NullAndBlankSame
		Do we regard null and Blank the same for the purpose of comparisons.
	
	.NOTES
		Additional information about the function.

#>
function Diff-Objects
{
	param
	(
		[Parameter(Mandatory = $true,
				   Position = 1)]
		[object]$Ref,
		[Parameter(Mandatory = $true,
				   Position = 2)]
		[object]$Diff,
		[Parameter(Mandatory = $false,
				   Position = 3)]
		[object[]]$Avoid = @('Metadata', '#comment'),
		[Parameter(Mandatory = $false,
				   Position = 4)]
		[string]$Parent = '$',
		[Parameter(Mandatory = $false,
				   Position = 5)]
		[int]$Depth = 10,
		[Parameter(Mandatory = $false,
				   Position = 6)]
		[int]$ReportNodes = $true
	)
	
	$Left = display-object $Ref -Avoid $Avoid -Parent $Parent -Depth $Depth -reportNodes $ReportNodes
	$right = display-object $Diff -depth 10 -reportNodes $ReportNodes
	$Paths = $Left + $Right | Select path -Unique
	$Paths | foreach{
		$ThePath = $_.Path;
		$Lvalue = $Left | where { $_.Path -eq $ThePath } | Foreach{ $_.Value };
		$Rvalue = $Right | where { $_.Path -eq $ThePath } | Foreach{ $_.Value };
		if ($RValue -eq $Lvalue)
		{ $equality = '==' }
		else
		{
			$equality = "$(if ($lvalue -eq $null) { '-' }
				else { '<' })$(if ($Rvalue -eq $null) { '-' }
				else { '>' })"
		}
		[pscustomobject]@{ 'Ref' = $ThePath; 'Source' = $Lvalue; 'Target' = $Rvalue; 'Match' = $Equality }
		
	}
}