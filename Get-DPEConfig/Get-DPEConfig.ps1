<#
	.SYNOPSIS
		Returns an encrypted config file as a Hashtable that can then be splatted to Flyway
	
	.DESCRIPTION
		This is used to allow you to decrypt flyway configuration items 'on the fly in a form that can be passed to Flyway via splatting.
	
	.EXAMPLE
		flyway @("$env:USERPROFILE\PubsMain"|Get-DPE) info
	
	.NOTES
		Additional information about the function.
#>
function Get-DPEConfig
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true,
				   HelpMessage = 'The File to decrypt')]
		$Filename
	)
	
	$secureString = Import-Clixml $Filename
	$bstrPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
	try
	{
		$originalText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstrPtr)
	}
	Catch { write-error "sadly we couldn't get the unencrypted contents of  $Filename" }
	finally
	{
		[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstrPtr)
	}
	
	
	$originalText | foreach -Begin {
		$Values = @();
	} `
	{
		$Values += $_.Split("`n") |
		where { ($_ -notlike '#*') -and ("$($_)".Trim() -notlike '') } |
		foreach{ $_ -replace '\Aflyway\.', '-' }
	} `
							-End { $Values }
	
}

