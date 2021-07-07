<#
	.SYNOPSIS
		Used to Compare two SQL Prompt Code analysis settings files or 
        style Format files
	
	.DESCRIPTION
		This compares two objects that are either XML objects or are derived from
first reading in JSON Files and converting them, using Convertfrom-JSON. 
This compares two powershell objects but because the styles or CA Settingsd do not 
have any value arrays, it doesn't bother to deal with that.
	
	.PARAMETER Ref
		The source object derived from ConvertFrom-JSON or the XML object 
	
	.PARAMETER diff
		The target object derived from ConvertFrom-JSON or the XML object 
	
	.PARAMETER Avoid
		a list of any object you wish to avoid comparing

	.PARAMETER Depth
		The depth to which you wish to recurse

	.PARAMETER Parent
		Only used for recursion

    .PARAMETER CurrentDepth
		Only used for recursion
	
#>
function Diff-Objects
{
	param
	(
		[Parameter(Mandatory = $true, #The source object derived from ConvertFrom-JSON
				   Position = 1)]
		[object]$Ref,
		[Parameter(Mandatory = $true, #The target object derived from ConvertFrom-JSON
				   Position = 2)]
		[object]$Diff,
		[Parameter(Mandatory = $false,
				   Position = 3)]
		[object[]]$Avoid = @('Metadata', '#comment'),
		[Parameter(Mandatory = $false,
				   Position = 4)]
		[string]$Parent = '$',
		[Parameter(Mandatory = $false,
				   Position = 5)]
		[int]$Depth = 4,
		[Parameter(Mandatory = $false,
				   Position = 6)]
		[int]$CurrentDepth = 0
	)
	if ($CurrentDepth -eq $Depth) { Return };
	# first create a  unique (unduplicated) list of all the key names obtained from 
	# either the source or target object
	$SourceInputType = $Ref.GetType().Name
	$TargetInputType = $Diff.GetType().Name
	if ($SourceInputType -in 'HashTable', 'OrderedDictionary')
	{
		$Ref = [pscustomObject]$Ref;
		$SourceInputType = 'PSCustomObject'
	}
	if ($TargetInputType -in 'HashTable', 'OrderedDictionary')
	{
		$Diff = [pscustomObject]$Diff;
		$TargetInputType = 'PSCustomObject'
	}
	$InputType = $SourceInputType #we discard different types as different!
	#are they  both value types?
	if ($Ref.GetType().IsValueType -and $Diff.GetType().IsValueType)
	{
		$Nodes = [pscustomobject]@{ 'Name' = ''; 'Match' = ''; 'SourceValue' = $Ref; 'TargetValue' = $Diff; }
	}
	elseif ($sourceInputType -ne $TargetInputType)
	{
		$Nodes = [pscustomobject]@{ 'Name' = ''; 'Match' = '<>'; 'SourceValue' = $Ref; 'TargetValue' = $Diff; }
	}
	elseif ($InputType -eq 'Object[]') # is it an array?
	{
		#iterate through it to get the array elements from both arrays
		$ValueCount = if ($Ref.Count -ge $Diff.Count)
		{ $Ref.Count }
		else { $Diff.Count }
		$Nodes = @{ }
		$Nodes =
		@(0..($ValueCount - 1)) | foreach{
			$TheMatch = ''
			if ($_ -ge $ref.count) { $TheMatch = '->' }
			if ($_ -ge $Diff.count) { $TheMatch = '<-' }
			$_ | Select @{ Name = 'Name'; Expression = { "[$_]" } },
						@{ Name = 'Match'; Expression = { $TheMatch } },
						@{ Name = 'SourceValue'; Expression = { $Ref[$_] } },
						@{ Name = 'TargetValue'; Expression = { $Diff[$_] } }
			
		}
	}
	#process the name/value objects
	else
	{
		if ($InputType -in @('Hashtable', 'PSCustomObject'))
		{
			[string[]]$RefNames = [pscustomobject]$Ref | gm -MemberType NoteProperty | foreach{ $_.Name };
			[string[]]$DiffNames = [pscustomobject]$Diff | gm -MemberType NoteProperty | foreach{ $_.Name };
		}
		else
		{
			[string[]]$RefNames = $Ref | gm -MemberType Property | foreach{ $_.Name };
			[string[]]$DiffNames = $Diff | gm -MemberType Property | foreach{ $_.Name };
		}
		#the nodes can all be obtained by dot references
		$Nodes = $RefNames + $DiffNames | select -Unique | foreach{
			#Simple values just won't go down the pipeline, just keynames
			# see if the key is there and if so what type of value it has 
			$Name = $_;
			$index = $null;
			$Type = $Null; #because we don't know it and it may not exist
			$SourceValue = $null; #we fill this where possible
			$TargetValue = $null; #we fill this where possible
			if ($Name -notin $Avoid) #if the user han't asked for it to be avoided
			{
				try
				{
					$TheMatch = $null;
					if ($Name -notin $DiffNames) #if it isn't in the target
					{
						$TheMatch = '<-' #meaning only in the source
						$SourceValue = $Ref.($Name)
						#logically the source has a value but it may be null
					}
					elseif ($Name -notin $RefNames) #if it isn't in the source
					{
						$TheMatch = '->' #meaning only in the target
						$TargetValue = $Diff.($Name)
						# and logically the target has a value, perhaps null
					}
					else # it is OK to read both
					{
						$TargetValue = $Diff.($Name);
						$SourceValue = $Ref.($Name)
						if ($Null -eq $TargetValue -or $Null -eq $SourceValue)
						{
							$TheMatch = "$(if ($Null -eq $Ref) { '-' }
								else { '<' })$(if ($Null -eq $Diff) { '-' }
								else { '>' })"
						}
					}
				}
				
				catch
				{ $TargetValue = $null; $SourceValue = $null; $TheMatch = '--' }
				$_ | Select 	@{ Name = 'Name'; Expression = { ".$Name" } },
							@{ Name = 'Match'; Expression = { $TheMatch } },
							@{ Name = 'SourceValue'; Expression = { $SourceValue } },
							@{ Name = 'TargetValue'; Expression = { $TargetValue } }
				
			}
		}
	}
	$Nodes | foreach{
		#Write-verbose $_| Format-Table
		$DisplayableTypes = @('string', 'byte', 'boolean', 'decimal', 'double',
			'float', 'single', 'int', 'int32', 'int16', 'intptr', 'long',
			'int64', 'sbyte', 'uint16', 'null', 'uint32', 'uint64')
		$DisplayableBaseTypes = @('System.ValueType', 'System.Enum')
		$DiffType = 'NULL'; $DiffBaseType = 'NULL'; $RefType = 'NULL'; $RefBaseType = 'NULL';
		$ItsAnObject = $null; $ItsAnArray = $null; $ItsAComparableValue = $Null;
		$name = $_.Name; $TheMatch = $_.Match;
		$SourceValue = $_.SourceValue; $TargetValue = $_.TargetValue;
		$FullName = "$Parent$inputName$Name";
		# now find out its type
		if ($_.SourceValue -ne $null)
		{
			$RefType = $_.SourceValue.GetType().Name;
			$RefBaseType = $_.SourceValue.GetType().BaseType
			$RefDisplayable = (($RefType -in $DisplayableTypes) -or ($RefBaseType -in $DisplayableBaseTypes))
		}
		if ($_.TargetValue -ne $null)
		{
			$DiffType = $_.TargetValue.GetType().Name;
			$DiffBaseType = $_.TargetValue.GetType().BaseType
			$DiffDisplayable = (($DiffType -in $DisplayableTypes) -or ($DiffBaseType -in $DisplayableBaseTypes))
		}
		
		$ItsAComparableValue = $false; # until proven otherwise
		if ($TheMatch -eq $null -or $TheMatch -eq '') # if no match done yet
		{
			If ($RefDisplayable -and $DiffDisplayable)
			{
				#just compare the values
				if ($SourceValue -eq $TargetValue)
				{ $TheMatch = '==' } # the same
				else { $TheMatch = '<>' } # different 
				$ItsAComparableValue = $true;
			}
			
		}
		#is it an Array?
		$ItsAnArray = $RefType -in 'Object[]';
		#is it an object?
		$ItsAnObject = ($RefBaseType -in @(
				'System.Xml.XmlLinkedNode', 'System.Xml.XmlNode',
				'System.Object', 'System.ComponentModel.Component'
				
			))
		if (!($TheMatch -eq $null -or $TheMatch -eq ''))
		{
			#if we have a match
			if ($ItsAnObject)
			{
				$TheTypeItIs = '(Object)';
			} #as a display reference
			if ($ItsAnArray)
			{
				$TheTypeItIs = '[Array]'; $FullName = "$Parent$Name" #as a display reference
			};
			
			#create a sensible display for object values
			$DisplayedValue = @($SourceValue, $TargetValue) | foreach{
				if ($ItsAComparableValue) { $_ }
				elseif ($_ -ne $Null) { $_.GetType().Name }
				else { '' }
			}
			if ($RefDisplayable -and ($DisplayedValue)) { $DisplayedValue[0] = $SourceValue }
			if ($DiffDisplayable -and ($DisplayedValue)) { $DisplayedValue[1] = $TargetValue }
			# create the next row of our 'table' with a pscustomobject
			
			1 | Select 	@{ Name = 'Ref'; Expression = { $FullName } },
					   @{ Name = 'Source'; Expression = { $DisplayedValue[0] } },
					   @{ Name = 'Target'; Expression = { $DisplayedValue[1] } },
					   @{ Name = 'Match'; Expression = { $TheMatch } }
		}
		else
		{
			if (($ItsAnObject) -or ($ItsAnArray))
			{
				#if it is an object or array on both sides
				Diff-Objects $SourceValue $targetValue $Avoid "$Fullname" $Depth ($CurrentDepth + 1)
			}
			# call the routine recursively 
			else { write-warning "No idea what to do with  object of named '$($Name)', basetype '$($RefBaseType)''$($DiffBaseType)' with match of '$TheMatch'" }
			if ($RefType -ne $Null)
			{ write-Verbose "compared  [$RefType]$FullName $RefDisplayable $DiffDisplayable '($RefBaseType)'-- '($DiffBaseType)' with '$TheMatch' match" }
		}
	}
}
