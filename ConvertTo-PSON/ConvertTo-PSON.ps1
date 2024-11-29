<#
	.SYNOPSIS
		converts a powershell object into a PSON representation of it 
	
	.DESCRIPTION
		
	
	.PARAMETER TheObject
		The object that you wish to display
	
	.PARAMETER depth
		the depth of recursion (keep it low!)
	
	.PARAMETER Avoid
		an array of names of objects or arrays you wish to avoid.
	
	.PARAMETER Comment
		comment at the start of the PSON output
	
	.NOTES
		Additional information about the function.
#>
function ConvertTo-PSON
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true)]
		$TheObject, # the object you are passing
		[int]$depth = 5, #your maximum depth. Called 'depth' to be compatible with ConvertTo-json etc
		[Object[]]$Avoid = @('#comment'), #A list of names. by default avoid XML comment blocks
		[int]$CurrentDepth = 0, #--internal use only--the recursion level for depth limitation and formatting
		[boolean]$starting = $True, #--internal use only-- if called recursively, this is set to false
		[string]$comment = '', # do you want to put a comment at the head? (e.g. if writing to file)
		[int]$ParentIsArray = $false #--internal use only-- is this being called from an array?
	)
	$Formatting = {
		<# a scriptblock used as a local function. It is used extensively within the cmdlet. It looks after the
        formatting #>
        
		Param (
			$TheKey,
			# the key of the key/value pair null if array
			$TheChild,
			# the value
			$IsChildaString = $false # is this a string?
		)
		$column = 0;
		if ("`r`n"+$TheOutput -imatch '(?-s)\n.*\z')
		{
			$Column = $matches[0].Length
		}
		if ($Column -ge 50)
		{ $margin = "`r`n$padding"; }
		else { $margin = '' }
		
		$bbstart = ''
		$bbend = ''
		if ($IsChildaString)
		{
			$bbStart = '''';
			$bbEnd = '''';
			if ($IsChildaString -and $Thechild -imatch '[\t\r\n\b\f\v\''\"\\]')
			{
				$bbStart = "@'`r`n";
				$bbEnd = "`r`n'@$padding";
			}
		}
		if ([string]::IsNullOrEmpty($TheKey))
		{ "$MaybeAComma$margin$bbStart$TheChild$bbEnd" }
		else
		{ "$MaybeAComma$margin'$TheKey' = $bbStart$TheChild$bbEnd" }
	}
	$AddBracket = {
		# effectively a local function for adding brackets
		Param (
			$TheBracket
			# 
		)
		$column = 0;
		if ($TheOutput -imatch '(?-s)\n.*\z')
		{
			$Column = $matches[0].Length
		}
		if ($Column -ge 30)
		{ $margin = "`r`n$padding"; }
		else { $margin = '' }
		
		if ($TheBracket -in @('@{', '@(')) #open bracket
		{
			"$margin$TheBracket"
		}
		else
		{ "$margin$TheBracket" }
		
	}
    # cmdlet starts here
    # make sure that the result is nicely formatted
	$Padding = '                      '.Substring(1, ($currentdepth * 2))
	$TheOutput = [string]'';
	if ($starting)
	{
		"$(if ($comment.Length -eq 0) { '' }
			else { " # $comment" })"; $starting = $false
	}
	if (($CurrentDepth -ge $Depth) -or
		($TheObject -eq $Null)) { return; } #prevent runaway recursion
	$ObjectTypeName = $TheObject.GetType().Name #find out what type it is
    $ObjectIsString=($TheObject -is [string]);
    $ObjectIsBoolean=($TheObject -is [boolean]);
    $ObjectIsStringOrValue=$TheObject.GetType().IsValueType -or $ObjectIsString;
	if ($ObjectTypeName -in 'HashTable', 'OrderedDictionary')
	{
		#If you can, force it to be a PSCustomObject
		$TheObject = [pscustomObject]$TheObject;
		$ObjectTypeName = 'PSCustomObject'
	}
    elseif ($ObjectTypeName -eq 'Collection`1')#and anything else it spits on 
        {$TheOldObject=$TheObject
        $TheObject=$TheOldObject|foreach{[pscustomobject]$_}}
	
	
    if ($TheObject.Count -eq $null # -and $TheObject.psobject.Properties.count -lt 1
        )
	{
		$TheOutput += & $Formatting  "$($_.Name)" ""  $false
	} 
	if ($TheObject.Count -eq 0)
	{
		$TheOutput += & $Formatting  "$($_.Name)" "@()" $false
	}
    elseif ($ObjectIsStringOrValue) 
        {$TheOutput += & $Formatting  "" "$(if ($objectIsBoolean){'$'})$TheObject" $ObjectIsString}
	elseif (!($TheObject.Count -gt 1 -or $($TheObject.GetType().Name) -eq 'Object[]' )) #not something that behaves like an array
	{
		# 
		$TheOutput += & $AddBracket "@{"
		$MaybeAComma = '';
		$TheObject.PSObject.Properties | where { $_.Name -notin $Avoid } | Foreach{
			$child = $_.Value;
			$ChildisAString = $_.TypeNameOfValue -like '*String*';
			if ($child -eq $null)
			{
            	$TheOutput += & $Formatting  "$($_.Name)" '$null' $false
			}
            elseif ($_.TypeNameOfValue -eq 'System.Boolean')
			{
				$TheOutput += & $Formatting  "$($_.Name)" "`$$child" $false
			}
			elseif ($ChildisAString -or
				$child.GetType().IsValueType)
			{
				$TheOutput += & $Formatting  "$($_.Name)" "$child" $ChildisAString
			}
			elseif (($CurrentDepth + 1) -eq $Depth)
			{
				$TheOutput += & $Formatting   "$($_.Name)" "$child" $ChildisAString
			}
			elseif ($child -in @($null, '') -and ($child.count -lt 1)  ) #empty array
			{
				$TheOutput += & $Formatting   "$($_.Name)" "@()" $false
			}
			elseif ($child.count -eq 0) #empty hashtable
			{
				$TheOutput += & $Formatting   "$($_.Name)" "@{}" $false
			}
			else #not a value but an object of some sort
			{
                if ($_.TypeNameOfValue -eq 'System.Object[]')
                {$TheOutput += & $Formatting   "$($_.Name)" "$(ConvertTo-PSON -TheObject $child -depth $Depth -Avoid $Avoid  -CurrentDepth ($currentDepth + 1) -starting $False)" $false}
				else
                 {$TheOutput += ConvertTo-PSON -TheObject $child -depth $Depth -Avoid $Avoid `
											 -CurrentDepth ($currentDepth + 1) -starting $False
                 }
				
			}
			$MaybeAComma = ';';
		}
		$TheOutput += & $AddBracket "}"
	}
	else # it is an array
	{
		$TheOutput += & $AddBracket "@("
		if ($TheObject.Count -gt 0)
		{
			$MaybeAComma = '';
			0..($TheObject.Count - 1) | Foreach{
				$child = $TheObject[$_];
				if ($child -eq $null)
				{ $TheOutput += & $Formatting  '' '$null' $false }
				else
				{
                    $ChildType=$child.GetType().Name
                    $ChildisAString = $ChildType -in @('String', 'String[]');
                     if ($ChildType -eq 'Boolean')
                        {$TheOutput += & $Formatting  '' "`$$child" $false}
					elseif (($child.GetType().BaseType.Name -eq 'ValueType') -or
						($ChildisAString)) #if so display it 
					    { $TheOutput += & $Formatting  '' $child $ChildisAString }
					elseif (($CurrentDepth + 1) -eq $Depth)
					{
						$TheOutput += & $Formatting  '' $child $ChildType $ChildisAString
					}
					else #not a value but an object of some sort so do a recursive call
					{
						$TheOutput += ConvertTo-PSON -TheObject $child -depth $Depth -Avoid $Avoid  `
													 -CurrentDepth ($currentDepth + 1) -starting $False -ParentIsArray $true
						
					}
				}
            $MaybeAComma = ','
			}
		}
		else { & $Formatting  '' $null $false }
		$TheOutput += & $AddBracket ")"
	}
	$TheOutput
}


$TestData = @(
	@{
		'hashtable' = @(12,1435.6789,'string',"this`n`rIs on two lines",$true,$false,$null,1.34569) ;
		'ExpectedResult' = '[12,1435.6789,"string","this\n\rIs on two lines",true,false,null,1.34569]'
		'TestDesc' = '1/ various value types'
	},
	@{
		'hashtable' = @(@{},@());
		'ExpectedResult' = '[{},[]]'
		'TestDesc' = '2/ array with null array and null hashtable'
	},
	@{
		'hashtable' = @{ 'First' = @{ }; 'Second' = @() };
		'ExpectedResult' = '{"First":{},"Second":[]}'
		'TestDesc' = '3/ Null array and null hashtable'
	},
	@{
		'hashtable' = @(@{'first'=@{}};@{'Second'=@()});
		'ExpectedResult' = '[{"first":{}},{"Second":[]}]'
		'TestDesc' = '4/ Array with two hashtables containing a null array and null hastable'
	},
	@{
		'hashtable' = @(@{ 'This' = $null; }, $null, 'another');
		'ExpectedResult' = '[{"This":null},null,"another"]'
		'TestDesc' = '5/ hashtable and string in array with nulls in them'
	},
	@{
		'hashtable' = @(@{ 'This' = 'that' }, 'another');
		'ExpectedResult' = '[{"This":"that"},"another"]'
		'TestDesc' = '6/ hashtable and string in array'
	},
	@{
		'hashtable' = @(@{ 'This' = 'that' }, 'another', 'yet another');
		'ExpectedResult' = '[{"This":"that"},"another","yet another"]'
		'TestDesc' = '7/ hastable and two strings in array'
	},
	@{
		'hashtable' = @('another', @{ 'This' = 'that' }, 4, 65, 789.89, 'yet another');
		'ExpectedResult' = '["another",{"This":"that"},4,65,789.89,"yet another"]'
		'TestDesc' = '8/ test are numbers correctly rendered?'
	},
	@{
		'hashtable' = @($null,$true,$false);
		'ExpectedResult' = '[null,true,false]'
		'TestDesc' = '9/ test are null, true and false rendered properly'
    },
	@{
		'hashtable' = @{'items' = @(@{'First' = 'Shadrak';'second' = @'
"Something in inverted commas"
'@    ;'third' = @{'One' = 'meshek';'two' = 'Abednego'}
    })};
		'ExpectedResult' = '{"items":[{"second":"\"Something in inverted commas\"","First":"Shadrak","third":{"One":"meshek","two":"Abednego"}}]}'
		'TestDesc' = '10/ single element array'
    },
	@{
		'hashtable' = 'this is a string';
		'ExpectedResult' = '"this is a string"'
		'TestDesc' = '11/ does this handle simple string input like ConvertTo-json?'
    },
	@{
		'hashtable' = $True;
		'ExpectedResult' = 'true'
		'TestDesc' = '12/ does this handleboolean input like ConvertTo-json?'
    },
	@{
		'hashtable' = 354.678;
		'ExpectedResult' = '354.678';
		'TestDesc' = '13/ does this handle numeric input like ConvertTo-json?'
    }
	@{
		'hashtable' = @(@{'name' = 'Mark McGwire';'hr' = 65;'avg' = 0.278},@{'name' = 'Sammy Sosa';'hr' = 63;'avg' = 0.288});
		'ExpectedResult' = '[{"name":"Mark McGwire","hr":65,"avg":0.278},{"name":"Sammy Sosa","hr":63,"avg":0.288}]';
		'TestDesc' = '14/ simple  table- array of objects'
    }
    )

$testData | foreach{
	$What = $_
	Try { $JsonString = convertto-json -Compress -depth 8 (Invoke-Expression "$(ConvertTo-PSON $_.hashTable)") }
	catch { write-warning "$($What.TestDesc)  failed because $($_) in " }
	if ($JsonString -ne $_.ExpectedResult)
	{ write-warning "$($What.TestDesc) produced $JsonString not $($_.ExpectedResult)" }
}

