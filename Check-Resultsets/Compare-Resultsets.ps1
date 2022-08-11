<#
	.SYNOPSIS
		Check two objects that are converted into PowerShell from JSON results set as results
		from SQL Expressions. Each element in the array has the same keys.
	
	.DESCRIPTION
		This function is used to test whether two JSON results from a SQL expression are the same as a correct result.
	
	.PARAMETER TestResult
		The powershell object derived from a json document sent from SQL.
		This will be the result produced by a test
	
	.PARAMETER CorrectResult
		This is the powershell object from reading a JSON file into Powershell
	
	.PARAMETER KeyField
		Do you want to specify a key field to search on?
	
	.EXAMPLE
		PS C:\> Compare-Resultsets -TestResult $value1 -CorrectResult $value2
	
	.NOTES
		can only specify a single key field. This will be a problem
#>
function Compare-Resultsets
{
	[CmdletBinding()]
	[OutputType([array])]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true)]
		[array]$TestResult,
		[Parameter(Mandatory = $true)]
		[array]$CorrectResult,
		[Parameter(HelpMessage = 'Do you want to specify a key field to search on?')]
		[string]$KeyField = $null
	)
	
	Begin
	{
		$TheErrors = @();
	}
	Process
	{
		if ($TestResult.count -ne $correctResult.count) #check that there are the same number of rows
		{
			#if the row counts are different report this. Don't bother to test each row
			$TheErrors += "there are $($TestResult.count) rows in the test and $($correctResult.count) in the test result"
		}
		# check that the fieldnames match
		$Testfields = ($TestResult[0] | gm -MemberType NoteProperty).Name;
		$Correctfields = ($CorrectResult[0] | gm -MemberType NoteProperty).Name;
		$fields = $Testfields | Where { $Correctfields -Contains $_ } #only check rows in common
		if ($testfields.count -ne $correctfields.count) #not the same number of columns
		{
			#if results have a different column count. Don't bother to test each row
			$TheErrors += "the test result has fields '$($Testfields -join ", ")' but the correct result has '$($correctFields -join ", ")'"
		}
		if ($fields.count -ne $testfields.count)
		{
			#if results have a different column count. Don't bother to test each row
			$TheErrors += "the test result and correct results don't share all their columns in common "
		}
		if ($TheErrors.count -eq 0) # we reject result sets for comparison if they dont have the same columns
		# we might make this configurable
		{
			$checkedOK = 0; #the counters for rows checked and those that were OK
			$checked = 0;
			if ($KeyField -notin @($null, ''))
			{
				$MatchedKeys = @()
				$TestResult | foreach{
					$TestLine = $_
					$KeyValue = $TestLine.$KeyField;
					$matches = $CorrectResult | where { $_.$KeyField -eq $keyvalue }
					if ($matches.count -eq 0)
					{
						$TheErrors += "extra test row $($testline | convertTo-json -Compress) not in correct result"
					}
					elseif ($matches.count -gt 1)
					{
						$TheErrors += "extra row in correct data with $keyvalue key = $keyvalue"
					}
					else
					{
						$MatchedKeys += $matches.$KeyField;
						$RecordWasOK = $true; #assume optimistically that it is OK
						$fields | where { $_ -ne $KeyField } | foreach {
							# for each column in common
							if ($Testline.$_ -ne $matches[0].$_)
							{
								#not the same. Oh dear. Record each failure
								$TheErrors += "for row with the $keyfield '$keyValue', the values for the $($_) column, $($Testline.$_) and $($matches[0].$_) don't match";
								$RecordWasOK = $false;
							}
						}
						$checked++;
						if ($RecordWasOK) { $checkedOK++; } # keep a tally of successes
					}
				}
				$correctResult | where { $_.$keyfield -notin $matchedkeys } | foreach{
					$missing = $_;
					$TheErrors += "missing record $($missing | convertTo-json -Compress)";
				}
			}
			else
			{
				@(0 .. ($TestResult.count - 1)) | foreach {
					#for every row
					$index = $_; #in order to index every row
					$RecordWasOK = $true; #assume optimistically that it is OK
					$fields | foreach {
						# for each column in common
						if ($TestResult[$index].$_ -ne $correctResult[$index].$_)
						{
							#not the same. Oh dear. Record each failure
							$TheErrors += "for row $index the values for the $($_) column, $($TestResult[$index].$_) and $($correctResult[$index].$_) don't match";
							$RecordWasOK = $false;
						}
					}
					$checked++;
					if ($RecordWasOK) { $checkedOK++; } # keep a tally of successes
				} #now report how we did
			}
		}
	}
	
	End
	{
		# report any errors
		"We checked $checked records and $(if ($checked -eq $checkedOK) { 'all were the same' }
			else { "only $checkedOK of them were the same" })"
		if ($TheErrors.count -gt 0) { $TheErrors }
	}
}