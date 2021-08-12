<#
	.SYNOPSIS
		imports a log and splits it according to a regex that has
		named backreferences for each field
	
	.DESCRIPTION
		This is a way of selecting log entries that are of a
		particular type, such as Warning, error or critical.
		It can filter on any type of record if you do a custom filter.
	
	.PARAMETER TheLogFile
		A description of the TheLogFile parameter.
	
	.PARAMETER SplitRegex
		The Filter scriptblock
	
	.PARAMETER TheLog
		the path to the log file
	
	.EXAMPLE
		$PromptTrad = [regex]'(?m:^)(?<Date>\d\d \w\w\w \d\d\d\d \d\d\:\d\d\:\d\d\,\d\d\d) \[(?<Number>\d+?)] (?<Level>.{1,20}) (?<Source>.{1,100}?) - (?<details>(?s:.*?))(?=\d\d \w\w\w \d\d\d\d|$)'
		
		dir "$env:localappdata\Red Gate\Logs\SQL Prompt*\*.log" |
		foreach{ Import-Log $_.FullName $PromptTrad }
		
		dir "$env:localappdata\Red Gate\Logs\SQL Prompt*\*.log" |
		foreach{
		Import-Log $_.FullName $PromptTrad
		}
		}
	
	.NOTES
		Additional information about the function.
#>
function Import-Log
{
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param
	(
		[Parameter(Mandatory = $true,
				   Position = 1)]
		[String[]]$TheLogFile,
		[Parameter(Mandatory = $true,
				   Position = 2)]
		[regex]$SplitRegex
	)
	$Log = [IO.File]::ReadAllText("$TheLogFile")
	$TheSplitLog = $log | Select-String  $SplitRegex -AllMatches
	$ourMatches = $TheSplitLog.Matches.Groups
	@(0..$OurMatches.Count) | Foreach -Begin {
		$OurHashTable = @{ }
	} -process {
		if ($OurMatches[$_].Name -in @('0', $null))
		{
			if ($OurHashTable.Count -gt 0)
			{ [pscustomObject]$OurHashTable }
			
			$OurHashTable = @{ }
		}
		else
		{
			$OurHashTable += @{ "$($OurMatches[$_].Name)" = "$($OurMatches[$_].Value)" }
		}
	} -end {
		if ($OurHashTable.Count -gt 0)
		{ [pscustomObject]$OurHashTable }
	}
}

