<#
	.SYNOPSIS
		Finds the latest version of a file and does an update by copying it over all other existing copies within the base directory you specify
	
	.DESCRIPTION
		This is a way of ensuring that the latest version of the file is updated everywhere within the directory structure
	
	.PARAMETER BaseDirectory
		The base directory of the location where the alterations can take place
	
	.PARAMETER Filename
		The name of the file that you want synchronized across the location
	
	.PARAMETER CanonicalSourcePath
		The name and path of the file that you want synchronized across the location. If not supplied, the routine just
		looks for the latest, most recently updated version in the BaseDirectory
	
	.EXAMPLE
		Distribute-LatestVersionOfFile '<pathTo>\github' 'DatabaseBuildAndMigrateTasks.ps1'
		Distribute-LatestVersionOfFile -Filename preliminary.ps1 -BaseDirectory '<pathTo>\FlywayTeamwork\Pubs'
	
	.NOTES
		Additional information about the function.
#>
function Distribute-LatestVersionOfFile
{
	[CmdletBinding(SupportsShouldProcess = $true)]
	param
	(
		[Parameter(Mandatory = $true)]
		$BaseDirectory,
		[Parameter(Mandatory = $true)]
		$Filename,
		[Parameter(Mandatory = $false)]
		$CanonicalSourcePath = $null
	)
	
	$canonicalVersion = "$CanonicalSourcePath\$filename";
	if ($CanonicalSourcePath -eq $null)
	{
		$canonicalVersion = dir "$BaseDirectory\$Filename" -recurse |
		Sort-Object -Property lastWriteTime -Descending |
		select-object -first 1
	}
	if ($canonicalVersion -eq $null) { write-error 'We must know the name of the file to update' }
	$parent = Split-Path -path $canonicalVersion -parent
	If (!(Test-Path -path $parent -PathType Container))
	{
		write-error " the $parent folder Does not Exist"
	}
	else
	{
		If (!(Test-Path -Path $canonicalVersion -PathType Leaf))
		{
			write-error "$canonicalVersion does not exist in $parent"
		}
	}
	$VersionDate = $canonicalVersion.LastWriteTime
	dir "$BaseDirectory\$Filename" -Recurse |
	where { $_.LastWriteTime -lt $VersionDate } |
	foreach{
		write-verbose "Copying $canonicalVersion to $_";
		Copy-Item -path $canonicalVersion -destination $_ -force -WhatIf:$WhatIfPreference
	}
}

