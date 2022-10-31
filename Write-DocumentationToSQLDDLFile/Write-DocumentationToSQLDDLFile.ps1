<#
	.SYNOPSIS
		Takes a JSON file with documentation details and inserts it into the files specified
	
	.DESCRIPTION
		This takes a whole bunch of files and updates them with the documentation that you request. This is intended for automatically-generated SQL Build scrips and also migration files 
	
	.PARAMETER FileList
		A description of the FileList parameter.
	
	.PARAMETER Documentation
		A description of the Documentation parameter.
	
	.PARAMETER FileVersion
		A description of the FileVersion parameter.
	
	.EXAMPLE
				PS C:\> Write-DocumentationToSQLDDLFile -FileList $value1 -Documentation 'Value2'
	
	.NOTES
		Additional information about the function.
#>
function Write-DocumentationToSQLDDLFile
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true)]
		[Array]$FileList,
		#the list of files to process

		[Parameter(Mandatory = $true)]
		[string]$Documentation,
		#The JSON file with the table documentation

		[string]$FileVersion = '' #if you want the processed file to have a different name or in a subdirectory
	)
	
	$Regex = [regex]@'
(?s)(?#Find create or alter for the table specified
find any initial comment
)(?<Initial>(/\*(?>[^*/]+|\*[^/]|/[^*]|/\*(?>[^*/]+|\*[^/]|/[^*])*\*/)*\*/|--[\w\s\d]{1,1000}){0,1})\s{0,20}(?#
first find the action statement 
)(?<Action>(CREATE|ALTER|DROP))\s{1,100}?(?#
And now the type of object
)(?<Object>(INDEX|TABLE|TRIGGER|VIEW|FUNCTION))\s{1,10}(?#
Ignore block comments with embedded /*..*/, IF EXISTS  or inline comments
)(?<Comment>(/\*(?>[^*/]+|\*[^/]|/[^*]|/\*(?>[^*/]+|\*[^/]|/[^*])*\*/)*\*/|--[^\r\n]{1,1000}|IF EXISTS){0,1})(?#
Find the schema, including any pesky square brackets or double-quotes if present for schema
)\s{0,100}(?<Schema>((\[|")[\w\s\d]{1,1000}(\]|")|[\w\d]{1,1000}))\.(?#
and now the object name
)(?<Name>((\[|")[\w\s\d]{1,1000}(\]|")|[\w\d]{1,1000}))(?#
and lastly any trailing comment
)\s{0,20}(?<TrailingComment>(/\*(?>[^*/]+|\*[^/]|/[^*]|/\*(?>[^*/]+|\*[^/]|/[^*])*\*/)*\*/|--[^\r\n]{1,1000}){0,1})
'@
	
	#we might have a filename for the documentation
	if (Test-Path $Documentation -PathType Leaf -ErrorAction Ignore)
	# if 'source was a filespec, read it in.
	{ $Documentation = [IO.File]::ReadAllText($Documentation) }
	$DatabaseDocumentationModel = $Documentation | convertfrom-JSON
	
	$LineRegex = [regex]'(\r\n|\r|\n)';
	#if getting the migration list was successful
	# the source might be a valid file or it might be a string
	$FileList | foreach{
		# is this ambiguous?
		if (!(Test-Path $_ -PathType Leaf -IsValid -ErrorAction Ignore))
		{
			dir $_ | foreach{ $what.FullName }
		}
		else { $_ }
	} | foreach{
		$filename = Split-Path $_ -leaf; #we'll want to save any altered files
		$DestinationFilepath = Split-Path $_ -parent
		[IO.File]::ReadAllText("$($_)") | foreach{
			$FileContents = $_ #We'll need this for the documented version of the file
			$allmatches = $regex.Matches($FileContents); #Check each file for all regexes that match 
			if ($allmatches.count -gt 0) #if there was a match
			{
				#we look through all matches, and make an array that tells us where each alteration must be
				# we need to sort this and make the alterations from the end of the file contents
				# backwards to the start. 
				$Alterations = $allmatches | foreach{
					$_
				} -PipelineVariable currentMatch | Select-Object  Groups | Foreach{
					$group = $_;
					$Thisindex = $currentMatch.Index #You need the index to the start of the entire match
					$ThisIndexLength = $currentMatch.Length #You need length of the entire match
					$ThisMatch = [ordered]@{ }; # We'll store each named  
					$group.Groups | Where { $_.Name -match '\D' } | foreach  {
						# each capturing group
						$BackReference = $_; #we pick up each back-reference
						$TheValue = $BackReference.Value -Replace ('(\A\[+|\]+\z)|(\A"+|"+\z)', '');
						#lets take out the irritating square brackets
						if ($BackReference.Name -in @('Name', 'Schema'))
						{
							#check to see if it is a valid SQL Schema or object name 
							if ($TheValue -notmatch '^(\A[\p{N}\p{L}_][\p{L}\p{N}@$#_]{0,127})$')
							# if it isn't valid we use the SQL Standard delimiter
							{ $TheValue = "`"$TheValue`"" }
						}
						$ThisMatch.Add($BackReference.Name, $TheValue) # add each captured backreference
						
					}
					# we now gather up the existing table comments into a single string
					$TheComment = "$($ThisMatch.initial)$($ThisMatch.Comment)$($ThisMatch.TrailingComment)"
					$TheComment = $TheComment.Replace('/*', '').Replace('*/', '').Replace('--', '')
					#now we see what it should be. 
					$thisObject = $DatabaseDocumentationModel | where {
						$_.TableObjectName -like "$($ThisMatch.Schema).$($ThisMatch.Name)"
					}
					# was this a create statement? 
					if ($ThisMatch.Action -ieq 'CREATE') #if create, then we use the full description
					{ $correctDocumentation = $thisObject.Description }
					else #we just add the most meagre description
					{ $correctDocumentation = $thisObject.Brief }
					if ([string]::IsNullOrEmpty($correctDocumentation))
					{
						$correctDocumentation = $TheComment
					}
					write-verbose "changing '$TheComment' to '$correctDocumentation' for $($ThisMatch.Schema).$($ThisMatch.Name) in $filename"
					if ($correctDocumentation.trim() -ne $TheComment.Trim())
					#if we haven't documention for this, we just use what was there
					#we only change if it is different
					{
						# if there is something to add, then delimit it with a block delimiter
						if ($correctDocumentation.Length -gt 0)
						{ $correctDocumentation = "`r`n/* $correctDocumentation */`r`n" }
						#Now we add it to the list of changes required for this file
						[psCustomObject]@{
							'Index' = $ThisIndex;
							'clauseLength' = $ThisIndexLength;
							'clause' = "$($ThisMatch.Action) $($ThisMatch.Object) $($ThisMatch.Schema).$($ThisMatch.Name) $correctDocumentation"
						}
					} # if there has been a change 
				}
				# for each match, make the alteration, inserting the documentation
				$alterations | Sort-Object -Property index -Descending | foreach{
					$fileContents = $FileContents.substring(0, $_.Index) + "`r`n$(
						$_.clause + $FileContents.substring($_.Index + $_.clauselength))";
					#Write out the new file
					$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
					$FileContents>"$DestinationFilepath\$FileVersion$filename"
				}
			} #if there was a match
		} #end read file contents
	} # for each file in the list
}
