$Testing = $False
<#
	.SYNOPSIS
	
	.DESCRIPTION
		This is a cmdlet that turns a hashtable or array into a 
        powerShell script that, if executed, recreates the object.
        The powershell script is in powershell's object notation
        PSON, and can be safely converted back to an object 
        (see convertFreom-PSON)
        basically, it is like ConvertTo-JSON in its behaviour. It is
        useful for saving powershell objects to disk.
	
	.PARAMETER TheObject
		The object that you wish to turn into its script
	
	.PARAMETER depth
		the depth of recursion to be allowed
	
	.PARAMETER Avoid
		an array of names of objects or arrays you wish to avoid.

	.PARAMETER Compress
		works like JSON

	.PARAMETER Ordered
		set to true if the order of the key/value pairs is important

    .EXAMPLES 
       
#>

function ConvertTo-PSON
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true)]
		$TheObject,
		[int]$depth = 10,
		[boolean]$ordered = $true,
		[boolean]$compress = $true,
		[Object[]]$Avoid = @('#comment')
	)
	
	function Escape-SpecialCharacters
	{
		param (
			[string]$InputString
		)
		if ($InputString -imatch '[\t\r\n\b\f\v\''\"\\]')
		{
			$escapes = @{
				"`0" = "``0" # Null
				"`a" = "``a" # Alert
				"`b" = "``b" # Backspace
				#"`e" = "``e" # Escape (PowerShell 6+)
				"`f" = "``f" # Form feed
				"`n" = "``n" # New line
				"`r" = "``r" # Carriage return
				"`t" = "``t" # Horizontal tab
				"`v" = "``v" # Vertical tab
				"'" = "``'" # Single quote
				"\" = "``\" # Backslash (often useful for escape sequences)
				"`"" = "```"" # Double quote
			}
			
			# Replace Unicode escape sequences
			$InputString = $InputString -replace "([\x80-\xFF])", { "``u{{{0:X}}}" -f [int][char]$args[0] }
			
			# Replace special characters
			foreach ($char in $escapes.Keys)
			{
				$InputString = $InputString -replace [regex]::Escape($char), $escapes[$char]
			}
			return "`"$InputString`""
		}
		return "`'$InputString`'"
		
	}
	
	$ObjectParsing = {
		param ($TheObject,
			$AllowedDepth = 4,
			$avoid = '',
			$ordered = $true,
			$compress = $true)
		# figure out where you get the names from
		if (($AllowedDepth -eq 0) -or
			($TheObject -eq $Null)) { return; } #prevent runaway recursion
		$ObjectTypeName = $TheObject.GetType().Name #find out what type it is
		if ($ordered) { $code = '[ordered]@{' }
		else { $code = '@{' }
		# Handle explicitly ordered hashtables
		if ($TheObject -is [hashtable] -and $TheObject.GetType().Name -eq 'OrderedDictionary')
		{
			$KeyValuepairs = [System.Collections.Specialized.OrderedDictionary]$TheObject | ForEach-Object {
				[PSCustomObject]@{ Name = $_.Key; Value = $_.Value }
			}
		}
		
		# Handle general enumerables (e.g., arrays of key/value pairs)
		elseif ($TheObject -is [System.Collections.IDictionary])
		{
			$KeyValuepairs = $TheObject.GetEnumerator() | ForEach-Object {
				[PSCustomObject]@{ Name = $_.Key; Value = $_.Value }
			}
		}
		
		# Handle [PSCustomObject] or objects with defined properties
		elseif ($TheObject -is [PSObject])
		{
			$KeyValuepairs = $TheObject.PSObject.Properties | ForEach-Object {
				[PSCustomObject]@{ Name = $_.Name; Value = $_.Value }
			}
		}
		
		# Fallback: wrap it and try again
		else
		{
			$Wrapped = [PSCustomObject]$TheObject
			$KeyValuepairs = $Wrapped.PSObject.Properties | ForEach-Object {
				[PSCustomObject]@{ Name = $_.Name; Value = $_.Value }
			}
		}
		$KeyValuepairs | foreach {
			$prefix = ''
		}{
			$child = $_.'value';
			$name = $_.'Name'
			if ($child -eq $null)
			{
				$ChildType = 'null';
				$BaseType = 'ValueType';
			}
			else
			{
				$ChildType = $child.GetType().Name;
				$BaseType = $child.GetType().BaseType.Name;
			}
			$code += switch ($baseType)
			{
				'ValueType' {
					switch ($ChildType)
					{
						'Boolean' {
							$truth = switch ($child)
							{
								$true { '$true' }
								default { '$false' }
							};
							"$prefix'$Name'=$truth"
						}
						'null' {
							"$prefix'$Name'=`$null"
						}
						
						default { "$prefix'$Name'=$child" }
					}
				}
				
				'Object' {
					switch ($ChildType)
					{
						{ $psitem -in ('string', 'string[]') }  { "$prefix'$Name'=$(Escape-SpecialCharacters $child)" }
						default
						{
							if ($child.Count -lt 1) { "$prefix'$Name'=@{}" }
							else
							{
								# Ensure recursion works correctly
								$nestedResult = & ([ScriptBlock]::Create($ObjectParsing)) $child $AllowedDepth-1  $avoid
								"$prefix'$Name'=$nestedResult"
							}
						}
					}
				}
				'Array' {
					if ($child.Count -lt 1) { "$prefix'$Name'=@()" }
					else
					{
						# Ensure recursion works correctly
						$nestedResult = & ([ScriptBlock]::Create($ArrayParsing)) $child $AllowedDepth-1 $avoid
						"$prefix'$Name'=$($nestedResult)"
					}
				}
			}
			$prefix = ';';
		}{ "$code}" }
	}
	
	$ArrayParsing = {
		param ($TheObject,
			$AllowedDepth,
			$avoid)
		# figure out where you get the names from
		if (($AllowedDepth -eq 0) -or
			($TheObject -eq $Null)) { return; } #prevent runaway recursion
		
		$code = '@('; $prefix = ''
		for ($i = 0; $i -lt $TheObject.Count; $i++)
		{
			$child = $TheObject[$i]
			
			if ($child -eq $null)
			{
				$code += "$prefix`$null"
			}
			else
			{
				$ChildType = $child.GetType().Name
				
				$code += switch ($child.GetType().BaseType.Name)
				{
					'ValueType' {
						switch ($ChildType)
						{
							'Boolean' {
								if ($child) { "$prefix`$true" }
								else { "$prefix`$false" }
							}
							default { "$prefix$child" }
						}
					}
					'Object' {
						switch ($ChildType)
						{
							{ $psitem -in ('string', 'string[]') }  { "$prefix$(Escape-SpecialCharacters $child)" }
							default
							{
								if ($child.Count -lt 1) { "$prefix@{}" }
								else
								{
									# Ensure recursion works correctly
									$nestedResult = & ([ScriptBlock]::Create($ObjectParsing)) $child $AllowedDepth-1 $avoid
									"$prefix$nestedResult"
								}
							}
						}
					}
					'Array' {
						if ($child.Count -lt 1) { "$prefix@()" }
						else
						{
							# Ensure recursion works correctly
							$nestedResult = & ([ScriptBlock]::Create($ArrayParsing)) $child $AllowedDepth-1 $avoid
							"$prefix$nestedResult"
						}
					}
					default { Write-Warning "$child not recognised" }
				}
			}
			$prefix = ','
		}
		
		$code += ')'
		return $code
	}
	if ($TheObject.GetType().Basetype.name -in ('System.Array', 'array') -or
		$TheObject.GetType().name -eq 'Array')
	{ . $ArrayParsing $theObject  $depth $avoid }
	elseif ($TheObject.GetType().name -eq 'String')
	{
		Escape-SpecialCharacters $TheObject
	}
	elseif ($TheObject.GetType().Basetype.name -eq 'ValueType')
	{
		switch ($TheObject.GetType().name)
		{
			'Boolean' {
				$truth = switch ($TheObject)
				{
					$true { '$true' }
					default { '$false' }
				};
				$truth
			}
			'null' {
				"$null"
			}
			
			default { "$TheObject" }
		}
	}
	else
	{ . $ObjectParsing $theObject  $depth $avoid }
}

if ($Testing)
{
	$TestData = @(
		@{
			'hashtable' = @(12, 1435.6789, 'string', "this`n`rIs on two lines", $true, $false, $null, 1.34569);
			'ExpectedResult' = '[12,1435.6789,"string","this\n\rIs on two lines",true,false,null,1.34569]'
			'TestDesc' = '1/ various value types'
		},
		@{
			'hashtable' = @(@{ }, @(0));
			'ExpectedResult' = '[{},[0]]'
			'TestDesc' = '2/ array with 0 array and null hashtable'
		},
		@{
			'hashtable' = @(@{ }, @());
			'ExpectedResult' = '[{},[]]'
			'TestDesc' = '3/ array with null array and null hashtable'
		},
		@{
			'hashtable' = @(@{ "first" = @{ } }; @{ "Second" = @() });
			'ExpectedResult' = '[{"first":{}},{"Second":[]}]'
			'TestDesc' = '4/ Array with two hashtables containing a null array and null hashtable'
		},
		@{
			'hashtable' = @(@{ 'first' = @() }; @{ 'Second' = @{ } });
			'ExpectedResult' = '[{"first":[]},{"Second":{}}]'
			'TestDesc' = '5/ Array with two hashtables containing a null Hashtable and null array'
		},
		@{
			'hashtable' = @(@{ 'This' = $null; }, $null, 'another');
			'ExpectedResult' = '[{"This":null},null,"another"]'
			'TestDesc' = '6/ hashtable and string in array with nulls in them'
		},
		@{
			'hashtable' = @(@{ 'This' = 'that' }, 'another');
			'ExpectedResult' = '[{"This":"that"},"another"]'
			'TestDesc' = '7/ hashtable and string in array'
		},
		@{
			'hashtable' = @(@{ 'This' = 'that' }, 'another', 'yet another');
			'ExpectedResult' = '[{"This":"that"},"another","yet another"]'
			'TestDesc' = '8/ hastable and two strings in array'
		},
		@{
			'hashtable' = @('another', @{ 'This' = 'that' }, 4, 65, 789.89, 'yet another');
			'ExpectedResult' = '["another",{"This":"that"},4,65,789.89,"yet another"]'
			'TestDesc' = '9/ test are numbers correctly rendered?'
		},
		@{
			'hashtable' = @($null, $true, $false);
			'ExpectedResult' = '[null,true,false]'
			'TestDesc' = '10/ test are null, true and false rendered properly'
		},
		@{
			'hashtable' = @{
				'items' = @([ordered]@{
						'First' = 'Shadrak'; 'second' = @'
"Something in inverted commas"
'@; 'third' = @{ 'One' = 'meshek'; 'two' = 'Abednego' }
					})
			};
			'ExpectedResult' = '{"items":[{"First":"Shadrak","second":"\"Something in inverted commas\"","third":{"One":"meshek","two":"Abednego"}}]}'
			'TestDesc' = '11/ single element array'
		},
		@{
			'hashtable' = 'this is a string';
			'ExpectedResult' = '"this is a string"'
			'TestDesc' = '12/ does this handle simple string input like ConvertTo-json?'
		},
		@{
			'hashtable' = $True;
			'ExpectedResult' = 'true'
			'TestDesc' = '13/ does this handleboolean input like ConvertTo-json?'
		},
		@{
			'hashtable' = 354.678;
			'ExpectedResult' = '354.678';
			'TestDesc' = '14/ does this handle numeric input like ConvertTo-json?'
		},
		@{
			'hashtable' = @(@{ 'name' = 'Mark McGwire'; 'hr' = 65; 'avg' = 0.278 }, @{ 'name' = 'Sammy Sosa'; 'hr' = 63; 'avg' = 0.288 });
			'ExpectedResult' = '[{"name":"Mark McGwire","hr":65,"avg":0.278},{"name":"Sammy Sosa","hr":63,"avg":0.288}]';
			'TestDesc' = '15/ simple  table- array of objects'
		},
		@{
			'hashtable' = @{ 'flyway' = [ordered]@{ 'password' = 'pa$$w3!rd'; 'user' = 'sysdba'; 'driver' = 'com.mysql.jdbc.Driver'; 'schemas' = 'customer_test'; 'url' = 'jdbc:mysql://localhost:3306/customer_test?autoreconnect'; 'locations' = 'filesystem:src/main/resources/sql/migrations' } }
			'ExpectedResult' = '{"flyway":{"password":"pa$$w3!rd","user":"sysdba","driver":"com.mysql.jdbc.Driver","schemas":"customer_test","url":"jdbc:mysql://localhost:3306/customer_test?autoreconnect","locations":"filesystem:src/main/resources/sql/migrations"}}';
			'TestDesc' = '16/ flyway example'
		}
		
	)
	
	$TestData += @(
		@{
			'hashtable' = @{ "empty string" = "" };
			'ExpectedResult' = '{"empty string":""}';
			'TestDesc' = '17/ property with empty string'
		},
		@{
			'hashtable' = @{ "linebreak" = "Line1`nLine2" };
			'ExpectedResult' = '{"linebreak":"Line1\nLine2"}';
			'TestDesc' = '18/ string with newline character'
		},
		@{
			'hashtable' = @{ "quote" = 'He said: "hello"' };
			'ExpectedResult' = '{"quote":"He said: \"hello\""}';
			'TestDesc' = '19/ string containing double quotes'
		},
		@{
			'hashtable' = @{ "path" = 'C:\Program Files\PowerShell\' };
			'ExpectedResult' = '{"path":"C:\\Program Files\\PowerShell\\"}';
			'TestDesc' = '20/ Windows-style file path with backslashes'
		},
		@{
			'hashtable' = [ordered]@{
				"true" = "not a boolean";
				"false" = $false;
				"null" = "something";
			};
			'ExpectedResult' = '{"true":"not a boolean","false":false,"null":"something"}';
			'TestDesc' = '21/ keys named "true", "false", and "null"'
		},
		@{
			'hashtable' = [ordered]@{
				"日本語" = "Japanese";
				"emoji" = "😊";
			};
			'ExpectedResult' = '{"日本語":"Japanese","emoji":"😊"}';
			'TestDesc' = '22/ Unicode characters in keys and values'
		},
		@{
			'hashtable' = [ordered]@{
				"EmptyArray" = @();
				"EmptyHash" = @{ };
			};
			'ExpectedResult' = '{"EmptyArray":[],"EmptyHash":{}}';
			'TestDesc' = '23/ Empty array and empty object as values'
		},
		@{
			'hashtable' = [ordered]@{
				"nested" = [ordered]@{
					"deeper" = [ordered]@{
						"bottom" = "value";
					};
				};
			};
			'ExpectedResult' = '{"nested":{"deeper":{"bottom":"value"}}}';
			'TestDesc' = '24/ Nested objects to test depth logic'
		},
		@{
			'hashtable' = @([ordered]@{
					"a" = [ordered]@{
						"b" = [ordered]@{
							"c" = [ordered]@{
								"d" = [ordered]@{
									"e" = [ordered]@{
										"f" = [ordered]@{
											"g" = "deep";
										}
									}
								}
							}
						}
					}
				});
			'ExpectedResult' = '{"a":{"b":{"c":{"d":{"e":{"f":{"g":"deep"}}}}}}}';
			'TestDesc' = '25/ very deep nesting'
		},
		@{
			'hashtable' = @{ };
			'ExpectedResult' = '{}';
			'TestDesc' = '26/ completely empty hashtable'
		},
		@{
			'hashtable' = @([ordered]@{ "a" = 1 }, [ordered]@{ "a" = 2 });
			'ExpectedResult' = '[{"a":1},{"a":2}]';
			'TestDesc' = '27/ array of objects with identical keys'
		}
	)
	
	$TestData += @(
		@{
			'hashtable' = @{ "0123" = "leading zero"; "1e6" = "scientific string" };
			'ExpectedResult' = '{"0123":"leading zero","1e6":"scientific string"}';
			'TestDesc' = '28/ numeric-looking strings as keys'
		},
		@{
			'hashtable' = @{ "Line`nBreak" = "Value"; "Tab`tChar" = "Tabbed" };
			'ExpectedResult' = '{"Line\nBreak":"Value","Tab\tChar":"Tabbed"}';
			'TestDesc' = '29/ keys with escape characters'
		},
		@{
			'hashtable' = @{ "quote`"" = "double quote"; "backslash\" = "slash" };
			'ExpectedResult' = '{"quote\"":"double quote","backslash\\":"slash"}';
			'TestDesc' = '30/ special characters in keys'
		},
		@{
			'hashtable' = [pscustomobject]@{ name = 'custom'; value = 42 };
			'ExpectedResult' = '{"name":"custom","value":42}';
			'TestDesc' = '31/ PSCustomObject support'
		},
		@{
			'hashtable' = [ordered]@{ b = 2; a = 1 };
			'ExpectedResult' = '{"b":2,"a":1}';
			'TestDesc' = '32/ ordered dictionary, non-alphabetical'
		},
		@{
			'hashtable' = @(@{ 'a' = 1 }, @{ 'b' = 2 }, @{ 'a' = 3 });
			'ExpectedResult' = '[{"a":1},{"b":2},{"a":3}]';
			'TestDesc' = '33/ repeated keys across array of objects'
		},
		@{
			'hashtable' = @(@{ a = 1 }, $null, @{ b = 2 });
			'ExpectedResult' = '[{"a":1},null,{"b":2}]';
			'TestDesc' = '34/ sparse array with null in between'
		},
	<#{
		'hashtable' = @(); 
		'ExpectedResult' = '[]';
		'TestDesc' = '35/ empty array literal'
	},#>
		@{
			'hashtable' = @{ nested = @{ } };
			'ExpectedResult' = '{"nested":{}}';
			'TestDesc' = '36/ empty nested hashtable'
		},
		@{
			'hashtable' = @{ "emoji" = "💾📦✨" };
			'ExpectedResult' = '{"emoji":"💾📦✨"}';
			'TestDesc' = '37/ Unicode emoji support'
		},
		@{
			'hashtable' = @{ "quotes" = "'single' and `"double`"" };
			'ExpectedResult' = @'
{"quotes":"\u0027single\u0027 and \"double\""}
'@
			'TestDesc' = '38/ quoted string combinations'
		},
		@{
			'hashtable' = @{ "array" = @(1, 2, 3, @{ "nested" = "yes" }) };
			'ExpectedResult' = '{"array":[1,2,3,{"nested":"yes"}]}';
			'TestDesc' = '39/ array with nested object inside'
		},
		@{
			'hashtable' = @{ "bools" = @($true, $false, $null) };
			'ExpectedResult' = '{"bools":[true,false,null]}';
			'TestDesc' = '40/ array of logicals'
		},
		@{
			'hashtable' = @{ "special" = "`nNewline`n`rReturn`r`"`"Quote`"`"" };
			'ExpectedResult' = '{"special":"\nNewline\n\rReturn\r\"\"Quote\"\""}';
			'TestDesc' = '41/ complex escape sequence in value'
		}
	)
	
	
	
	
	$testData | foreach{
		$What = $_
		Try { $JsonString = convertto-json -Compress -depth 8 (Invoke-Expression "$(ConvertTo-PSON $_.hashTable)") }
		catch { $JsonString = ''; write-warning "$($What.TestDesc)  failed because $($_) in " }
		if ($JsonString -ne $_.ExpectedResult)
		{ write-warning "Unfortunately, $($What.TestDesc) produced json ...`n$JsonString not `n$($_.ExpectedResult) `n...from...`n $(ConvertTo-PSON $_.hashTable)" }
		else
		{ write-host "$($What.TestDesc) succeeded" }
	}
	
}
