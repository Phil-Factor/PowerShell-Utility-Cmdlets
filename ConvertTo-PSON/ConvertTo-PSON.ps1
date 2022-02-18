<#
	.SYNOPSIS
		converts a powershell object into a YAML representation of it 
	
	.DESCRIPTION
		
	
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
function ConvertTo-PSON
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
		[int]$ParentIsArray = $false #is this being called from an array?
	)
	$Formatting = {
		# effectively a local function
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
		write-verbose "1/ $TheKey, $TheChild, $IsChildAString $column $($TheOutput.Length)"
		if ([string]::IsNullOrEmpty($TheKey))
		{ "$MaybeAComma$margin$bbStart$TheChild$bbEnd" }
		else
		{ "$MaybeAComma$margin'$TheKey' = $bbStart$TheChild$bbEnd" }
	}
	$AddBracket = {
		# effectively a local function
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
	Write-Verbose "2/ called with parameter $($TheObject.GetType().Name) at level $currentDepth"
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
	if ($ObjectTypeName -in 'HashTable', 'OrderedDictionary')
	{
		#If you can, force it to be a PSCustomObject
		$TheObject = [pscustomObject]$TheObject;
		$ObjectTypeName = 'PSCustomObject'
	}
	
	Write-Verbose "3/ the parameter is an $($TheObject.GetType().Name) of count $($TheObject.Count)"
	
    if ($TheObject.Count -eq $null # -and $TheObject.psobject.Properties.count -lt 1
        )
	{
		Write-Verbose "4/ this has null count - $TheObject.Name"
		$TheOutput += & $Formatting  "$($_.Name)" ""  $false
	} 
	if ($TheObject.Count -eq 0)
	{
		Write-Verbose "5/ this has no count - $TheObject.Name"
		$TheOutput += & $Formatting  "$($_.Name)" "@()" $false
	}
	elseif (!($TheObject.Count -gt 1 -or $($TheObject.GetType().Name) -eq 'Object[]' )) #not something that behaves like an array
	{
		# 
		$TheOutput += & $AddBracket "@{"
		$MaybeAComma = '';
		$TheObject.PSObject.Properties | where { $_.Name -notin $Avoid } | Foreach{
			$child = $_.Value;
			Write-verbose "6/ Its an object. type of child ='$($_.TypeNameOfValue)', value is '$child'"
			$ChildisAString = $_.TypeNameOfValue -like '*String*';
			if ($child -eq $null)
			{
			    Write-verbose " 6a/ Child Was null so represent that"
            	$TheOutput += & $Formatting  "$($_.Name)" '$null' $false
			}
            elseif ($_.TypeNameOfValue -eq 'System.Boolean')
			{
			    Write-verbose " 6b/ Child Was logical value"
				$TheOutput += & $Formatting  "$($_.Name)" "`$$child" $false
			}
			elseif ($ChildisAString -or
				$_.TypeNameOfValue -in @('System.Object', 'System.int32', 'System.Decimal'))
			{
			    Write-verbose " 6c/ Child Was an easily represented object"
				$TheOutput += & $Formatting  "$($_.Name)" "$child" $ChildisAString
			}
			elseif (($CurrentDepth + 1) -eq $Depth)
			{
			    Write-verbose " 6d/ no recursion possible so do your best"
				$TheOutput += & $Formatting   "$($_.Name)" "$child" $ChildisAString
			}
			elseif ($child -in @($null, '') -and ($child.count -lt 1)  ) #empty array
			{
			    Write-verbose " 6e/ Child '$($_.Name)' was a null array"
				$TheOutput += & $Formatting   "$($_.Name)" "@()" $false
			}
			elseif ($child.count -eq 0) #empty hashtable
			{
			    Write-verbose " 6f/ Child $($_.Name) Was an empty hastable"
				$TheOutput += & $Formatting   "$($_.Name)" "@{}" $false
			}
			else #not a value but an object of some sort
			{
				Write-Verbose "7/ recursion with $($_.TypeNameOfValue) object  $($_.Name)"
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
        Write-Verbose "8/ we have an array of $($TheObject.Count) items"
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
					Write-Verbose "9/ array element $child is a $ChildType "
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
						Write-Verbose "10/ recursion with array element  $child"
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
	}
	@{
		'hashtable' = @($null,$true,$false);
		'ExpectedResult' = '[null,true,false]'
		'TestDesc' = '9/ test are null, true and false rendered properly'
    }
	@{
		'hashtable' = @{'items' = @(@{'First' = 'Shadrak';'second' = @'
"Something in inverted commas"
'@    ;'third' = @{'One' = 'meshek';'two' = 'Abednego'}
    })};
		'ExpectedResult' = '{"items":[{"second":"\"Something in inverted commas\"","First":"Shadrak","third":{"One":"meshek","two":"Abednego"}}]}'
		'TestDesc' = '10/ single element array'
    }
)


$testData | foreach{
	$What = $_
	Try { $JsonString = convertto-json -Compress -depth 8 (Invoke-Expression "$(ConvertTo-PSON $_.hashTable)") }
	catch { write-warning "$($What.TestDesc)  failed because $($_)" }
	if ($JsonString -ne $_.ExpectedResult)
	{ write-warning "$($What.TestDesc) produced $JsonString not $($_.ExpectedResult)" }
}

