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
		[boolean]$starting = $True
	)
	$Formatting = {
		Param ($TheParent,
			$TheChild)
		"$Parent- $(
			if ($child -eq $null) { 'null' }
			elseif ($child -imatch '[\t \r\n\b\f\v\''\"\\]') { ($Child | ConvertTo-json) }
			#elseif  ($child -like '* *')  {a$child`"} 
			else { "$child" }
		)"
	}
	
	if ($starting) { '---'; $starting = $false }
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
			{ "$Parent$($_.Name): $(if ($child -eq $null) { 'null' }
					else { $Child | ConvertTo-json })"; }
			elseif (($CurrentDepth + 1) -eq $Depth)
			{
				& $Formatting -ArgumentList $parent $child
			}
			else #not a value but an object of some sort
			{
				"$parent$($_.Name):"
				ConvertTo-YAML -TheObject $child -depth $Depth -Avoid $Avoid -Parent "  $parent" `
							   -CurrentDepth ($currentDepth + 1) -starting $False
			}
			
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
				{ & $Formatting -ArgumentList $parent $child }
				elseif (($CurrentDepth + 1) -eq $Depth)
				{
					& $Formatting -ArgumentList $parent $child
				}
				else #not a value but an object of some sort so do a recursive call
				{
					ConvertTo-YAML -TheObject $child -depth $Depth -Avoid $Avoid -parent "$Parent[$_]" `
								   -CurrentDepth ($currentDepth + 1)
				}
				
			}
		}
		else { [pscustomobject]@{ 'Path' = "$Parent"; 'Value' = $Null } }
	}
}
