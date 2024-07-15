<#
	.SYNOPSIS
		Converts from PSD1 (PSON) to an object
	
	.DESCRIPTION
		Takes a string of object notation and converts
    it into an object safely. It will not execute random
    Powershell - only object notation
	
	.PARAMETER contents
	The string containing the PowerShell object notation.
	
	.EXAMPLE
	ConvertFrom-PSON -contents @'
@( @{ x = 1; y = 2; z = 3 },
   @{ x = 7; y = 8; z = 9 },
   @{ x = 2; y = 4; z = 8 } )
'@          	
	.NOTES
		returns a hash table by default but you can specify
        the object type in Posershell object notation.
#>
$Points|ConvertTo-JSON


function ConvertFrom-PSON
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true)]
		[string]$contents
	)
	
	Begin
	{
		
	}
	Process
	{
		$allowedCommands = @('Invoke-Expression')
		# Convert the array to a List<string> using array cast
		$allowedCommandsList = [System.Collections.Generic.List[string]]($allowedCommands)
		$lookingDodgy = $false
		$scriptBlock = [scriptblock]::Create($contents)
		try
		{
			$scriptBlock.CheckRestrictedLanguage($allowedCommandsList, $null, $true)
		}
		catch
		{
			$lookingDodgy = $True
			Write-error "string is not Valid Powershell Object Notation!"
		}
		if (!($lookingDodgy)) { $scriptBlock.invoke() }
    }
	End
	{
		
	}
}
