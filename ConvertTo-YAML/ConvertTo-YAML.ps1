<#
	.SYNOPSIS
		Displays an object's values and the 'dot' paths to them
	
	.DESCRIPTION
		A detailed description of the Display-Object function.
	
	.PARAMETER TheObject
		The object that you wish to display
	
	.PARAMETER depth
		the depth of recursion (keep it low!)
	
	.PARAMETER Avoid
		an array of names of pbjects or arrays you wish to avoid.
	
	.PARAMETER Parent
		For internal use, but you can specify the name of the variable
	
	.PARAMETER CurrentDepth
		For internal use
	
	.NOTES
		Additional information about the function.
#>
function ConvertTo-YAML
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true)]
		$TheObject,
		[int]$depth = 5,
		[Object[]]$Avoid = @('#comment'),
		[string]$Parent = '',
		[int]$CurrentDepth = 0,
		[boolean]$starting = $True,
		[string]$comment = '',
		[string]$objectPrefix = '  '
	)
	$Formatting = {
		# effectively a local function
		Param ($TheParent,
			$TheKey,
			$TheChild,
			$ThePrefix = ' ')
		if ($TheKey -imatch '[\t \r\n\b\f\v\''\"\\]')
		{ $TheKey = ($TheKey | ConvertTo-json) };
		$KeyDeclaration = "$($TheParent)$($objectPrefix)$($TheKey)$($Theprefix) ";
		if ($Thechild -eq $null) { $TheValue = 'null' }
		elseif ($Thechild -match '[\r\n]' -or $TheChild.Length -gt 80)
		{
			# right, we have to format it to YAML spec.
			$Indent = 0
			if ($TheParent -imatch '(?<LeadingSpaces>\A *)') { $indent = $matches['LeadingSpaces'].length }
			
			$padding = $TheParent.Substring(0, $Indent) + '  '
			$ItHasLongLines = $False;
			$TheValue = ''
			$TheChild -split '[\n|\r]{1,2}' | ForEach-Object {
				$length = $_.Length;
				$IndexIntoString = 0;
				$wrap = 80;
				while ($length -gt $IndexIntoString + $Wrap)
				{
					$BreakPoint = $wrap
					$ItHasLongLines = $true;
					$earliest = $_.Substring($IndexIntoString, $wrap).LastIndexOf(' ')
					$latest = $_.Substring($IndexIntoString + $wrap).IndexOf(' ')
					if ($earliest -eq -1) #no line breaks so nothing to do
					{ $BreakPoint = $wrap }
					elseif ($latest -eq -1)
					{ $Breakpoint = $earliest }
					elseif ($wrap - $earliest -lt ($latest))
					{ $BreakPoint = $wrap }
					else
					{ $BreakPoint = $wrap + $latest }
					#now we 
					$TheValue += $padding + $_.Substring($IndexIntoString, $BreakPoint).Trim() + "`r`n";
					$IndexIntoString += $BreakPoint
				}
				
				if ($IndexIntoString -lt $length)
				{
					$TheValue += $padding + $_.Substring($IndexIntoString).Trim() + "`r`n`r`n"
				}
				else
				{
					$TheValue += "`r`n`r`n"
				}
			}
			if ($ItHasLongLines) { $TheValue = "> `r`n" + $TheValue }
			else { $TheValue = "| `r`n" + $TheValue -replace '\r\n\r\n', "`r`n" }
		}
		elseif ($Thechild -imatch '[\t\r\n\b\f\v\''\"\\]') { $TheValue = $Thechild | ConvertTo-json }
		else { $TheValue = "$Thechild" }
		"$KeyDeclaration$TheValue"
	}
	
	if ($starting)
	{
		"---$(if ($comment.Length -eq 0) { '' }
			else { " # $comment" })"; $starting = $false
	}
	if (($CurrentDepth -ge $Depth) -or
		($TheObject -eq $Null)) { return; } #prevent runaway recursion
	$ObjectTypeName = $TheObject.GetType().Name #find out what type it is
	if ($ObjectTypeName -in 'HashTable', 'OrderedDictionary')
	{
		#If you can, force it to be a PSCustomObject
		$TheObject = [pscustomObject]$TheObject;
		$ObjectTypeName = 'PSCustomObject'
	}
	if (!($TheObject.Count -gt 1)) #not something that behaves like an array
	{
		# figure out where you get the names from
		if ($ObjectTypeName -in @('PSCustomObject'))
		# Name-Value pair properties created by Powershell 
		{ $MemberType = 'NoteProperty' }
		else
		{ $MemberType = 'Property' }
		#now go through the names 		
		$TheObject |
		gm -MemberType $MemberType | where { $_.Name -notin $Avoid } |
		Foreach{
			Try { $child = $TheObject.($_.Name); }
			Catch { $Child = $null } # avoid crashing on write-only objects
			if ($child -eq $null -or #is the current child a value or a null?
				$child.GetType().BaseType.Name -eq 'ValueType' -or
				$child.GetType().Name -in @('String', 'String[]'))
			{
				& $Formatting $Parent "$($_.Name)" $child ':'
			}
			elseif (($CurrentDepth + 1) -eq $Depth)
			{
				& $Formatting  $parent "$($_.Name)" $child '-'
			}
			else #not a value but an object of some sort
			{
				"$parent$($_.Name):"
				ConvertTo-YAML -TheObject $child -depth $Depth -Avoid $Avoid -Parent "  $parent" `
							   -CurrentDepth ($currentDepth + 1) -starting $False -objectPrefix $objectPrefix
			}
			$objectPrefix = '  '
		}
	}
	else #it is an array
	{
		if ($TheObject.Count -gt 0)
		{
			0..($TheObject.Count - 1) | Foreach{
				$child = $TheObject[$_];
				if (($child -eq $null) -or #is the current child a value or a null?
					($child.GetType().BaseType.Name -eq 'ValueType') -or
					($child.GetType().Name -in @('String', 'String[]'))) #if so display it 
				{ & $Formatting $parent '' $child '-' }
				elseif (($CurrentDepth + 1) -eq $Depth)
				{
					& $Formatting $parent '' $child '-'
				}
				else #not a value but an object of some sort so do a recursive call
				{
					ConvertTo-YAML -TheObject $child -depth $Depth -Avoid $Avoid -parent "$Parent  " -objectPrefix '- '`
								   -CurrentDepth ($currentDepth + 1) -starting $False
				}
				$objectPrefix = '  '
			}
		}
		else { & $Formatting $parent '' $null '-' }
	}
}