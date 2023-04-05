

<#
	.SYNOPSIS
		Gets the files of a git release, either the latest one or, if you specify the tag, the release that has that tag.
	
	.DESCRIPTION
		This is a, hopefully, reliable way of getting the latest release from Github, or a specific release. There are several examples on the internet but I couldn't get any to work. Git changes the protocol, but if you can get the correct path of the zip-ball of the files, you have a better chance.
	
	.PARAMETER RepoPath
		The name of the repository. e.g. Phil-Factor/FlywayGithub
	
	.PARAMETER credentials
		The github 'Personal access token' that is provided by Github. You must provide this the first time that you use the cmdlet. After that it remembers  it
	
	.PARAMETER tag
		This is the name of the tag. This will include the Branch, but if no branch is added, it assumes main.
	
	.PARAMETER TargetFolder
		This is the path to the destination where the code is saved. If you provide nothing then it uses the project name as a directory in your user area
	
	.PARAMETER FileSpec
		The list of types of file you want to have (e.g. *.sql,*.bat). I'd leave this at its default (*)! 
	
	.EXAMPLE
		PS C:\>
		Get-TaggedGitRelease -repopath 'Phil-Factor/FlywayGithubDemo'  -tag 'V1.1' -Filespec '*'
        dir "$env:UserProfile\FlywayGithubDemo" -recurse
	    Get-TaggedGitRelease -repopath 'Phil-Factor/FlywayGithubDemo'  -tag 'latest' -Filespec '*'
	    Get-TaggedGitRelease -repopath 'Phil-Factor/FlywayGithubDemo'  -tag 'penultimate' -Filespec '*'

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
		[string]$credentials = $null,
		[Parameter(Mandatory = $false,
				   Position = 3)]
		[string]$tag = $null,
		[Parameter(Mandatory = $false,
				   Position = 4)]
		[string]$TargetFolder = $null,
		[Parameter(Mandatory = $false,
				   Position = 5)]
		[String]$FileSpec = '*'
	)
	
	$RepoName = $repoPath -split '[\\/]' # get the owner and repo
	$owner = $RepoName[0]; $repository = $RepoName[1]; $CredentialFile = $RepoName -join '_'
	if ([string]::IsNullOrEmpty($TargetFolder))
	{
		$TargetFolder = "$env:UserProfile\$repository"
	}
	#now fetch the credentials from the user area
	if (($owner -eq $null) -or ($repository -eq $null))
	{
		Write-error "we need both the owner and repository. e.g. Genghis/Kahn"
	}
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
	$WorkFolder = "$env:UserProfile\Work$(Get-Random -Minimum 1000 -Maximum 9999)"
	
	#create the authentication header
	$headers = New-Object "System.Collections.Generic.Dictionary[[String], [String]]"
	$headers.Add("Authorization", "token $credentials")
	#Create the basic API string for the project
	$releases = "https://api.github.com/repos/$repopath/releases"
	if ([string]::IsNullOrEmpty($tag)) { $Tag = 'latest' }
	<# You might want the latest version of, say, 1.1.2, if someone has made changes then 
	they would increment the pre-release. The semantic version might be changed from
	1.1.1-alpha to  1.1.2-beta. #>	
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
		$TheReleaseInformation = $TheInformation.Content | convertfrom-json
		$location = $TheReleaseInformation.zipball_url
		$Tag = $TheReleaseInformation.Tag_Name
		Write-verbose "Now we have tag $Tag from $URL"
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
		if (-not (Test-Path "$($ZipBallFolder)"))
		{ $null = New-Item -ItemType Directory -Path "$($ZipBallFolder)" -Force }
		#now get the zip file 
		Invoke-WebRequest -Uri $location -Headers $headers -OutFile "$($ZipBallFolder)$Tag.zip"
		Write-verbose "Extracting release files from $($ZipBallFolder)$Tag.zip to $WorkFolder"
		#now unzip the Zipball
		Expand-Archive "$($ZipBallFolder)$Tag.zip" -DestinationPath $WorkFolder -Force
		$sourceDirectory = (dir $WorkFolder -Directory).name
		#now remove just the directories in the target that we are copying
		if ([string]::IsNullOrEmpty($sourceDirectory) -or [string]::IsNullOrEmpty($TargetFolder))
		{ write-error "cannot delete existing content of your folder" }
		else
		{
			$DirectoriesWeCopy = dir "$WorkFolder\$sourceDirectory\$filespec" -Directory | foreach{ $_.name }
			$DirectoriesWeCopy | foreach{ Remove-Item "$TargetFolder\$_" -ErrorAction SilentlyContinue -recurse -Force }
		}
		Write-verbose "copying items from $WorkFolder\$sourceDirectory\$filespec to $TargetFolder"
		copy-item  "$WorkFolder\$sourceDirectory\$filespec" -Destination "$TargetFolder" -Recurse -Force
		Remove-Item $WorkFolder -Recurse -force
		Remove-Item "$($ZipBallFolder)$Tag.zip" -Force
	}
}
