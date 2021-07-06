<#
	.SYNOPSIS
		imports a log and splits it according to a regex that has 
        named backreferences for each field
	
	.DESCRIPTION
		This is a way of selecting log entries that are of a
         particular type, such as Warning, error or critical. 
         It can filter on any type of record if you do a custom filter.
	
	.PARAMETER TheLog
		the path to the log file
	
	.PARAMETER FilterScript
		#the regex for splitting
	
	.PARAMETER SplitRegex
		The Filter scriptblock
	
	.EXAMPLE
    $PromptTrad = [regex]'(?m:^)(?<Date>\d\d \w\w\w \d\d\d\d \d\d\:\d\d\:\d\d\,\d\d\d) \[(?<Number>\d+?)] (?<Level>.{1,20}) (?<Source>.{1,100}?) - (?<details>(?s:.*?))(?=\d\d \w\w\w \d\d\d\d|$)'

    dir "$env:localappdata\Red Gate\Logs\SQL Prompt*\*.log" |
    foreach{ Import-Log $_.FullName $PromptTrad }

    dir "$env:localappdata\Red Gate\Logs\SQL Prompt*\*.log" |
    foreach{
	    Import-Log $_.FullName $PromptTrad {
		    $_.Name -ieq 'Details' -and $_.Value.Trim() -like '*StringactiveStyleName*'
	    }
    }
	

#>
function Import-Log
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true, #the path to the log file
				   Position = 1)]
		[String[]]$TheLogFile,
		[Parameter(Mandatory = $true, #the regex for splitting
				   Position = 2)]
		[regex]$SplitRegex
		
	)
	
	
	$WhatItWas = Select-String -Path $TheLogFile -pattern $SplitRegex -AllMatches
	$ourMatches = $whatItWas.Matches.Groups
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
			$OurHashTable += @{ "$($OurMatches[$_].Name)" = "$OurMatches[$_].Value" }
		}
	} -end {
		if ($OurHashTable.Count -gt 0)
		{ [pscustomObject]$OurHashTable }
	}
	
}