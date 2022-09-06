<#
	.SYNOPSIS
		Get a github repository and download it to a local directory/folder.
        This used to be able to download directories but Github stopped
        that. 
	
	.DESCRIPTION
		This is a powershell cmdlet that allows you to download a 
        reposoitory or just a directory from a repository. 
	
	.PARAMETER Owner
		The owner of the repository e.g. 'Phil-Factor'
	
	.PARAMETER Repository
		the name of the github repository e.g. 'PowerShell-Utility-Cmdlets'
	
	.PARAMETER RepoPath e.g. 
		the path within the repository where you want to download.
        eg 'archive/refs/heads/main' or 'archive/refs/heads/master'
	
	.PARAMETER DestinationPath
		the local path to where you want to save the files
	
	.EXAMPLE
		$Params = @{
			'Owner' = 'Phil-Factor';
			'Repository' = 'PubsAndFlyway';
			'RepoPath' = 'archive/refs/heads/main';
			'DestinationPath' = "d:\PubsPostgreSQL";
		}
		Get-FilesFromRepo @Params

#>
function Get-FilesFromRepo
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true,
				   Position = 1)]
		[string]$Owner,
		#The owner of the repository

		[Parameter(Mandatory = $true,
				   Position = 2)]
		[string]$Repository,
		#the name of the github repository

		[Parameter(Mandatory = $true,
				   Position = 3)]
		[string]$RepoPath,
		# the path within the repository where you want to download.

		[Parameter(Mandatory = $true,
				   Position = 4)]
		[string]$DestinationPath #the local path to where you want to save the files
	)
	

    $baseUri = "https://github.com"
	$MyZipFile="$env:temp\$owner.zip"
    write-verbose "downloading the file  $baseUri/$Owner/$Repository/$RepoPath.zip"
    Invoke-WebRequest "$baseUri/$Owner/$Repository/$RepoPath.zip" -OutFile $MyZipFile
    Expand-Archive -Path $MyZipFile -DestinationPath $DestinationPath
    Remove-Item $MyZipFile

}