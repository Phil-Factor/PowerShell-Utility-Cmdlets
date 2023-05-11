<#
	.SYNOPSIS
		Writes the string as an XML file in the user area with the 
		given filename.
	
	.DESCRIPTION
		This PowerShell routine will save the string in its
		encrypted form as a system.secure.string an XML file
		
	.EXAMPLE
Write-DPEncryptedContent 'Fee-fi-fo-fum,
I smell the blood of an Englishman,
Be he alive, or be he dead
I''ll grind his bones to make my bread' "$env:USERPROFILE\SecretKey"
	
	.PARAMETER String
		the string that you wish to encrypt.
	
	.PARAMETER Filename
		The file you want to save the encrypted text in
	

#>
function Write-DPEncryptedContent
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true,
				   HelpMessage = 'the string that you wish to encrypt.')]
		[String]$String,
		[Parameter(Mandatory = $true,
				   HelpMessage = 'The file you want to save the encrypted text in')]
		[String]$Filename
	)
	
	$String | ConvertTo-SecureString -AsPlainText -Force | Export-Clixml  $Filename -Force
}