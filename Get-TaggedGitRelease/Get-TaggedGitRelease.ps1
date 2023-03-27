<#
	.SYNOPSIS
		Gets the files of a git release, either the latest one or, if you specify the tag, the release that has that tag.
	
	.DESCRIPTION
		This is a, hopefully, reliable way of getting the latest release from Github, or a specific release. There are several examples on the internet but I couldn't get any to work. Git changes the protocol, but if you can get the correct path of the zip-ball of the files, you have a better chance.
	
	.PARAMETER RepoPath
		The name of the repository. Phil-Factor/FlywayGithub
	
	.PARAMETER credentials
		A description of the credentials parameter.
	
	.PARAMETER tag
		A description of the tag parameter.
	
	.PARAMETER TargetFolder
		A description of the DestinationFolder parameter.
	
	.PARAMETER FileSpec
		The list of types of file you want to have (e.g. *.sql,*.bat)
	
	.EXAMPLE
		PS C:\>
		Get-TaggedGitRelease -repopath 'Phil-Factor/FlywayGithub'  -tag 'v1.1' -Filespec '*.sql'
	    Get-TaggedGitRelease -repopath 'Phil-Factor/FlywayGithub'  -tag 'latest' -Filespec '*'
	    Get-TaggedGitRelease -repopath 'Phil-Factor/FlywayGithub'  -tag 'penultimate' -Filespec '*'
	.NOTES
		Additional information about the function.
#>
function Get-TaggedGitRelease
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true,
				   Position = 1)]
		[string]$RepoPath,
		[Parameter(Mandatory = $false,
				   Position = 2)]
		[string]$credentials,
		[Parameter(Mandatory = $false,
				   Position = 3)]
		[string]$tag,
		[Parameter(Mandatory = $false,
				   Position = 4)]
		[string]$TargetFolder,
		[Parameter(Mandatory = $false,
				   Position = 5)]
		[array]$FileSpec = '*'
	)
	
	$RepoName = $repoPath -split '[\\/]' # get the owner and repo
	$owner = $RepoName[0]; $repository = $RepoName[1]; $CredentialFile = $RepoName -join '_'
	#now fetch the credentials from the user area
	$CredentialLocation = "$env:UserProfile\$CredentialFile.txt"
	if (!([string]::IsNullOrEmpty($credentials)))
	{
		$credentials > "$CredentialLocation" #assume it is a first time 
	}
	else
	{
		#fetch existing credentials
		if (Test-Path "$($CredentialLocation)")
		{ $credentials = Get-Content $CredentialLocation }
		else
		{ Write-Error "Could not find a credential. Github needs a credential to authorise this" }
	}
	$ZipBallFolder = "$env:TMP\$repository\"
	if ([string]::IsNullOrEmpty($TargetFolder)) #create the target folder if necessary
	{ $TargetFolder = "$env:UserProfile\$repo\scripts" }
	#create the authentication header
	$headers = New-Object "System.Collections.Generic.Dictionary[[String], [String]]"
	$headers.Add("Authorization", "token $credentials")
	#Create the basic API string for the project
	$releases = "https://api.github.com/repos/$repopath/releases"
	if ([string]::IsNullOrEmpty($tag)) { $Tag = 'latest' }
	if ($tag -eq 'penultimate')
	{
		$TheInformation = Invoke-WebRequest $releases -Headers $headers
		$ReleaseList = $TheInformation.content | convertFrom-json
		$TheLatest = $ReleaseList.GetEnumerator() | foreach{
			$Badverion = $false; #We need to be able to sort this - assume the best
			if ($_.tag_name -cmatch '\D*(\d([\d\.]){1,40})')
			{
				$Version = $matches[1]
			}
			else { $Badverion = $true; }
			if (!($Badverion))
			{
				try { $Version = [version]$Version }
				catch { $Badverion = $true }
			}
			if ($Badversion) { write-error "sorry but you must use numeric versions to get the latest" }
			[pscustomobject]@{
				'Tag' = $_.tag_name;
				'Version' = $Version;
				'Location' = $_.zipball_url
			}
		} | Sort-Object -Property version -Descending | select -First 2
		if ($TheLatest.count -ne 2) { write-error "sorry but there is no penultimate tag" }
		$Tag = $TheLatest[1].Tag;
		$location = $TheLatest[1].Location;
	}
	else # we use the tag. 'latest' for latest 
	{
		if ($tag -eq 'latest')
		{ $URL = "$releases/latest" }
		else
		{ $URL = "$releases/tags/$tag" }
		$TheInformation = Invoke-WebRequest $URL -Headers $headers
		$TheReleaseInformation = $TheResult.Content | convertfrom-json
		$zipballUrl = $TheReleaseInformation.zipball_url
		$Tag = $TheReleaseInformation.Tag
	}
	
	#we now have the tag and the location
	if (($location -eq $null) -or ($Tag -eq $null))
	{ write_error "could not find that tagged release" }
	else
	{
		Write-verbose "Downloading release $Tag to $ZipBallFolder"
		# $headers.Add("Accept", "application/octet-stream")
		# make sure that the folder is there
		if (-not (Test-Path "$($ZipBallFolder)"))
		{ $null = New-Item -ItemType Directory -Path "$($ZipBallFolder)" -Force }
		#now get the zip file 
		Invoke-WebRequest -Uri $location -Headers $headers -OutFile "$($ZipBallFolder)$Tag.zip"
		Write-verbose "Extracting release files from $($ZipBallFolder)$Tag.zip to $TargetFolder"
		Expand-Archive "$($ZipBallFolder)$Tag.zip" -DestinationPath $TargetFolder -Force
		$sourceDirectory = dir $TargetFolder -Directory
		Remove-Item "$TargetFolder\*" -Exclude $sourceDirectory;
		$filespec | foreach{
			Move-Item -Path "$TargetFolder\$sourceDirectory\$_" -Destination $TargetFolder
		}
		Remove-Item "$TargetFolder\$sourceDirectory" -Recurse
		Remove-Item "$($ZipBallFolder)$Tag.zip" -Force
	}
}