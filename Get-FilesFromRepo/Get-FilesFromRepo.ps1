<#
	.SYNOPSIS
		Get a github repository and download it to a local directory/folder.
	
	.DESCRIPTION
		This is a powershell cmdlet that allows you to download a 
        reposoitory or just a directory from a repository. 
	
	.PARAMETER Owner
		The owner of the repository
	
	.PARAMETER Repository
		the name of the github repository
	
	.PARAMETER RepoPath
		the path within the repository where you want to download.
	
	.PARAMETER DestinationPath
		the local path to where you want to save the files
	
	.EXAMPLE
		$Params = @{
			'Owner' = 'Phil-Factor';
			'Repository' = 'PubsAndFlyway';
			'RepoPath' = 'PubsPostgreSQL';
			'DestinationPath' = "$env:Temp\PubsPostgreSQL";
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
	
	$baseUri = "https://api.github.com/"
	$Theargs = "repos/$Owner/$Repository/contents/$RepoPath"
	write-verbose "$baseuri $Theargs"
	$files = @(); $Directories = @();
	((Invoke-WebRequest -Uri "$baseuri$Theargs").content | ConvertFrom-Json) |
	foreach {
		if ($_.type -eq 'file')
		{ $files += $_.download_url; }
		else
		{ $directories += $_.name; }
	}
	
	$directories | ForEach {
		$Params = @{
			'Owner' = $Owner;
			'Repository' = $Repository;
			'RepoPath' = "$RepoPath/$($_)";
			'DestinationPath' = "$DestinationPath\$([uri]::UnescapeDataString($_))";
		}
		Get-FilesFromRepo @Params
	}
	
	
	if (-not (Test-Path $DestinationPath -PathType Container))
	{
		# create the destination path if it doesn't exist
		try
		{
			$null = New-Item -Path $DestinationPath -ItemType Directory
		}
		catch
		{
			throw "Could not create path '$DestinationPath'!"
		}
	}
	
	$files | foreach{
		$filename = Split-Path $_ -Leaf # get the filename
		$fileDestination = "$DestinationPath\$([uri]::UnescapeDataString($filename))"
		#we have to strip off any escapes because files allow spaces!
		try
		{
			Invoke-WebRequest -Uri $_ -OutFile $fileDestination -ErrorAction Stop
			#download the file(s))
			write-verbose "saved $_ to $fileDestination"
		}
		catch
		{
			throw "couldn't download $_ to '$($fileDestination)'"
		}
	}
}