﻿<#
	.SYNOPSIS
		Displays an object's values and the 'dot' paths to them
	
	.DESCRIPTION
		A detailed description of the Display-Object function.
	
	.PARAMETER TheObject
		The object that you wish to display
	
	.PARAMETER depth
		the depth of recursion (keep it low!)
	
	.PARAMETER Avoid
		an array of names of objects or arrays you wish to avoid.
	
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
		[int]$CurrentDepth = 0,
		[boolean]$starting = $True,
		[string]$comment = '',
		[int]$ParentIsArray= $false #is this being called from an array?
	)
	$Formatting = {
		# effectively a local function
		Param (
			$TheKey,
			# the key of the key/value pair
			$TheChild,
			# the key of the key/value pair
			$ThePrefix = ' '
             # the prefix for the value : or -
    
		)
		Write-verbose "depth='$currentdepth', TheKey='$TheKey', TheChild='$TheChild', ThePrefix='$ThePrefix' "
		if ($TheKey -imatch '[\t \r\n\b\f\v\''\"\\]') #If the key contains json escapes...
		{ $TheKey = ($TheKey | ConvertTo-json) }; #just so escape it
		$KeyDeclaration = "$PaddingMaybeIndicator$($TheKey)$($Theprefix) ";
		if ($Thechild -eq $null) { $TheValue = 'null' }
		elseif ($Thechild -match '[\r\n]' -or $TheChild.Length -gt 80)
		{
			# right, we have to format it to YAML spec.
			$Indent = 0
			$ItHasLongLines = $False; #until proved otherwise
			$TheValue = ''
			#split the text up
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
					$TheValue += $padding+'  '+$_.Substring($IndexIntoString, $BreakPoint).Trim() + "`r`n";
					$IndexIntoString += $BreakPoint
				}
				
				if ($IndexIntoString -lt $length)
				{
					$TheValue += $padding+'  '+$_.Substring($IndexIntoString).Trim() + "`r`n"
				}
				else
				{
					$TheValue += "`r`n"
				}
			}
			if ($ItHasLongLines)
			{ $TheValue = "> `r`n" + $TheValue }
			else { $TheValue = "| `r`n" + $TheValue -replace '\r\n\r\n', "`r`n" }
		}
		elseif ($Thechild -imatch '[\t\r\n\b\f\v\''\"\\]') { $TheValue = $Thechild | ConvertTo-json }
		else { $TheValue = "$Thechild" } # just let powershell format it
		"$KeyDeclaration$TheValue"
	}

    $Padding='                      '.Substring(1,($currentdepth*2))
    $PaddingMaybeIndicator=if ($ParentIsArray){$Padding.Substring(0,$Padding.Length-2)+'- '} else {$Padding};	
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
		#now go through the names 
        
		$TheObject.PSObject.Properties | where { $_.Name -notin $Avoid } | Foreach{
            Write-verbose "type='$($_.TypeNameOfValue)'"
			$child = $_.value;
			if ($_.TypeNameOfValue -like '*String*' -or
                $_.TypeNameOfValue -in @('System.Object','System.boolean','System.int32','System.Decimal'))
			{
                & $Formatting  "$($_.Name)" "$child"  ':'
			}
			elseif (($CurrentDepth + 1) -eq $Depth)
			{
				& $Formatting   "$($_.Name)" "$child" ':'
			}
			else #not a value but an object of some sort
			{
                Write-Verbose "recursion with object  $($_.Name)"
				$padding+"$($_.Name):"#
				ConvertTo-YAML -TheObject $child -depth $Depth -Avoid $Avoid `
							   -CurrentDepth ($currentDepth + 1) -starting $False 
			}
			$objectPrefix = '  '
			
		}
	}
	else # it is an array
		{
			if ($TheObject.Count -gt 0)
			{
				0..($TheObject.Count - 1) | Foreach{
					$child = $TheObject[$_];
					if (($child -eq $null) -or #is the current child a value or a null?
						($child.GetType().BaseType.Name -eq 'ValueType') -or
						($child.GetType().Name -in @('String', 'String[]'))) #if so display it 
					{ & $Formatting  '' $child '-' }
					elseif (($CurrentDepth + 1) -eq $Depth)
					{
						& $Formatting  '' $child '-'
					}
					else #not a value but an object of some sort so do a recursive call
					{
                    Write-Verbose "recursion with array element  $child"
					ConvertTo-YAML -TheObject $child -depth $Depth -Avoid $Avoid  `
								 -CurrentDepth ($currentDepth + 1) -starting $False -ParentIsArray $true
					}
									}
			}
			else { & $Formatting  '' $null '-' }
		}
	}
	
	
