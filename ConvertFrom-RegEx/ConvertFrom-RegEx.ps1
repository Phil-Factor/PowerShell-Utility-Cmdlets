<#
	.SYNOPSIS
		Use regex strings to  convert a string or a file from formatted tabular (each row with the same columns) text
	
	.DESCRIPTION
		Use named backreferences in regex strings to process text that is in some sort of format that someone has invented for the purpose
	
	.PARAMETER source
		This can be either a string containing the formatted text, or a valid filepath to the file containing it
	
	.PARAMETER TheRegex
		This provides the regex string. you are likely to need to need a mode modifier in the string, especially if a record spans several lines.
	
	.PARAMETER ValueAlterations
		this provides pairs of regex strings with match and replace. If there is only one, Powershell will let you use two strings with a comma
        separator. If more, then you need the correct aray-in-array syntax. They are executed from left to right.
		e.g. @(('(?m:^)\s{1,40}?\|',''),("\n",''),("\r",''))|
	
	.EXAMPLE
		
	
#>
function ConvertFrom-Regex
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true,
				   Position = 1)]
		[string]$source,
		[Parameter(Mandatory = $true,
				   Position = 2)]
		[regex]$TheRegex,
		[Parameter(Position = 3)]
		[array]$ValueAlterations
	)
	# the source might be a valid file or it might be a string
	if (Test-Path $source -PathType Leaf -ErrorAction Ignore)
	# if 'source was a filespec, read it in.
	{ $source = [IO.File]::ReadAllText($source) }
	#now source is a string!
	[regex]::Matches($source, $TheRegex) | # use the net Regex directly
	Select-Object  Groups | Foreach{ # get hold of the matches
		#row matched
		$row = $_;
		$line = [ordered]@{ }; # use ordered otherwise the line is higglety-pigglety
		#for each member of the group that is a named backreference
		$row.Groups | Where { $_.Name -like '*[A-Z]*' } | foreach  {
			$column = $_;
			$TheValue = $column.Value
			if ($ValueAlterations.Count -gt 0)
			{
				# some value alterations are specified
				$ValueAlterations | Foreach { $What = $_.GetType().Name }
				if ($What -eq 'Object[]') #Array of calue alteration pairs
				{
					$ValueAlterations | foreach {
						$TheValue = $TheValue -replace $_[0], $_[1]
					}
				}
				else #it is a string
				{
					#simple string/substitution array pair
					$TheValue = $TheValue -replace $ValueAlterations[0], $ValueAlterations[1]
				}
			}
			$Line.Add($column.Name, $TheValue) #add the value to the row 
		}
		[pscustomobject]$line
	}
}
