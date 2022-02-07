<#
	.SYNOPSIS
		Finds the latest version of a file and copy it over all other existing copies within the base directory you specify
	
	.DESCRIPTION
		This is a way of ensuring that the latest version of the file is updated everywhere within the directory structure
	
	.PARAMETER BaseDirectory
		The base directory of the location where the alterations can take place
	.PARAMETER Filename
		The name of the file that you want synchronized across the location
	
	.EXAMPLE
		Distribute-LatestVersionOfFile '<pathTo>\github' 'DatabaseBuildAndMigrateTasks.ps1'
	
	.NOTES
		Additional information about the function.
#>
function Distribute-LatestVersionOfFile
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		$BaseDirectory,
		[Parameter(Mandatory = $true)]
		$Filename
	)
	

	$canonicalVersion = dir "$BaseDirectory\$Filename" -recurse |
	Sort-Object -Property lastWriteTime -Descending |
	select-object -first 1
	$VersionDate = $canonicalVersion.LastWriteTime
	dir "$BaseDirectory\$Filename" -Recurse |
	where { $_.LastWriteTime -lt $VersionDate } |
	foreach{ Copy-Item -path $canonicalVersion -destination $_ -force }
}

