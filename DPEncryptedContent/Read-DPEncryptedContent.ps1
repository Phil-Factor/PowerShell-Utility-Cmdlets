<#
	.SYNOPSIS
		returns the contents of an encrypted file in the user area.
	
	.DESCRIPTION
		This PowerShell routine will fetch the contents of a file
		containing an encrypted object stored in an XML Document
		This is encrypted as a system.secure.string. It converts
		it back into plain text
	
	.PARAMETER Filename
		A description of the Server parameter.
	
	.NOTES
		Additional information about the function.
#>
function Read-DPEncryptedContent
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
	Write-Output $originalText
}

