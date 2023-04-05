<#
	.SYNOPSIS
		Get current files modified but uncommitted
	
	.DESCRIPTION
		A detailed description of the Get-GithubModifiedFiles function.
	
	.PARAMETER RepoPath
		The path to the repository. Eg GengisKahn/Bloodbath
	
	.PARAMETER Branch
		the branch
	
	.EXAMPLE
				PS C:\> Get-GithubModifiedFiles -RepoPath 'GengisKahn/Bloodbath' -Branch 'main'
	
#>
function Get-GithubModifiedFiles
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[String]$RepoPath,
		[Parameter(Mandatory = $true)]
		[string]$Branch
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
	
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", "token $credentials")
	
	# Get the current commit SHA for the branch
	$branch_url = "https://api.github.com/repos/$repoPath/branches/$branch"
	$branch_data = Invoke-RestMethod -Uri $branch_url -Headers $headers
	$commit_sha = $branch_data.commit.sha
	
	# Get the list of files in the current commit tree
	$tree_url = "https://api.github.com/repos/$repoPath/git/trees/$commit_sha"
	$tree_data = Invoke-RestMethod -Uri $tree_url -Headers $headers
	
	# Filter the tree to only include files that have been modified or added
	$changed_files = $tree_data.tree |
	Where-Object { $_.type -eq "blob" -and $_.sha -ne $commit_sha } |
	select path -ExpandProperty path
	
}


