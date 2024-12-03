
$VerbosePreference='continue'
$Testing=$false; #Set to false unless you are checking things
<#
	.SYNOPSIS
		Converts a string containing a CFG, Conf, or .INI file (not full TOML) into 
        the corresponding powershell Hashtable
	
	.DESCRIPTION
		This routine will interpret an INI file, including one  that contains nested 
        sections or multi-line strings into a Powershell Object. It doesn't do elaborate
        syntax checks or TOML array extensions.
	
	.PARAMETER ConfigLinesToParse
		The  String containing the INI or Config lines, usually read from a file
	
	.EXAMPLE
				PS C:\> ConvertFrom-INI -ConfigLinesToParse 'Value1'
	
	.NOTES
		
#>
function ConvertFrom-INI
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true)]
		[string]$ConfigLinesToParse
	)
	
	Begin
	{
		$UsedArrayNames = @();
		$UsedObjectNames = @();
        $ArrayPosition=@{}
        $Basename='';
        $CurrentElement=-1
		$CurrentLocation = $null; # used for remembering sections to resolve relative subsections
  
		# first we define our scriptblocks, used for private routines within the task 
        		
$ConvertStringToNativeValue = {
	param (
		[string]$InputString
	)
	$LiteralRegex = [regex]@'
(?i)(?#-----Analysing a Value 
Integer   )(?<Integer>^(?:\+|-)?\d+$)(?#
Hex Value )|(?<Hexadecimal>^0x[0-9a-fA-F]+$)(?#
Octal     )|(?<Octal>^0o[0-7]+$)(?#
Binary    )|(?<Binary>^0b[01]+$)(?#
Float/ scientific notation)|(?<Float>^(?:\+|-)?\d*\.?\d+(?:e[+-]?\d+)?$)(?#
Infinity e.g., +inf, -inf)|(?<Infinity>^[+\s-]{0,2}?inf)(?#
NAN       )|(?<NAN>^[+\s-]{0,2}?nan)(?#
ISO 8601 UTC datetime    )|(?<ISODateTime>^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$)(?#
ISO 8601 Offset datetime )|(?<ISOOffsetDatetime>^^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?[+-]\d{2}:\d{2}$)(?#
Local Datetime           )|(?<LocalDatetime>^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?$)(?#
Local Date)|(?<LocalDate>^\d{4}-\d{2}-\d{2}$$)(?#
Time with seconds        )|(?<Time>^\d{2}:\d{2}:\d{2}(?:\.\d+)?$)(?#
String    )|(?<String>^.+$)
'@
	$cleanedInput = $InputString.Replace('_', '')
	$identification = $LiteralRegex.matches($cleanedInput).Groups | where {
		$_.success -eq $true -and $_.Length -gt 0 -and $_.name -ne '0'
	}
	
	switch ($identification.Name)
	{
		'Integer' { [int]$cleanedInput }
		'Hexadecimal' { [convert]::ToInt64($cleanedInput, 16) }
		'Octal' { [convert]::ToInt64($cleanedInput.Substring(2), 8) }
		'Binary' { [convert]::ToInt64($cleanedInput.Substring(2), 2) }
		'Float' { [double]$cleanedInput }
		'Infinity' {
			# Infinity (e.g., +inf, -inf)
			if ($cleanedInput -like '-inf')
			{ return [double]::NegativeInfinity }
			else { [double]::PositiveInfinity }
		}
		'NAN' { [double]::NaN }
		'ISODateTime' { [datetimeoffset]::Parse($cleanedInput) }
		'ISOOffsetDatetime' { [datetimeoffset]::Parse($cleanedInput) }
		'LocalDate' { [datetime]::Parse($cleanedInput) }
		'Time' { [timespan]::Parse($cleanedInput) }
		'String' { $InputString }
		default { $result = 'Unknown' }
	}
}
<#	
	.DESCRIPTION
	===========================================================================
	$BuildInlineTableorArray compiles a TOML nested array or hashtable e.g.
	{table = [ { a = 42, b = "test" }, {c = 4.2} ]}
	or
    [ { x = 1, y = 2, z = 3 },
    { x = 7, y = 8, z = 9 },
    { x = 2, y = 4, z = 8 } ]
    ===========================================================================
#>
$BuildInlineTableorArray = {<# compile nested hashtables and arrays #>
	Param ([string]$String)
	$Stacklength = 20 #the depth of the arrays and tables.
	$VerbosePreference = 'continue'
	$TheStack = @(0) * $stacklength; $Stackpointer = 0 # set up the stack
	([regex]@"
(?#  Regex for inline tables and arrays
Octal value       )(?<Octal>0o[\d0-7]*)(?# 
LocalTime         )|(?<LocalTime>\d\d:\d\d:\d\d[.\d]*)(?#
OffsetDateTime    )|(?<OffsetDatetime>\d{4}-\d\d-\d\dT\d\d:.*)(?#
DateTime          )|(?<Date>\d{4}-\d\d-\d\d*)(?#
hex value         )|(?<Hex>0x[\d0-9|\wa-f]*)(?#
binary value      )|(?<Bin>0b[\d0-1]*)(?#
Not a number or infinity)|(?<NAN>[-+]?NAN|INF)(?#
Boolean           )|(?<Boolean>true|false)(?#
integer value     )|(?<Int>[-+]?\d{1,12}?)(?#
Scientific float notation)|(?<Float>[-+]?(?:\b[0-9_]+(?:\.[0-9_]*)?|\.[0-9]+\b)(?:[eE][-+]?[0-9]+\b)?)(?# 
BareString          )|(?<BareString>[\.\w\:/]{1,100}(?=,)|(?<=)[\.\w\:/]{1,100})(?# 
bare key          )|(?<Barekey>\w{1,40})(?# 
Multiline String  )|"""(?<MultiLineQuotedLiteral>(?s:.)*?)"""(?# 
single-quoted Multiline String )|'''(?<MultiLinedelimitedLiteral>(?s:.)*?\s?)'''(?# 
Quoted " string   )|"(?<QuotedLiteral>[^']*?)"(?# 
Delimited ' string)|'(?<delimitedLiteral>[^']*?)'(?# 
Array Start       )|(?<ArrayStart>\[)(?# 
Array End         )|(?<ArrayEnd>\])(?# 
Table Start       )|(?<TableStart>\{)(?# 
Table End         )|(?<TableEnd>\})(?# 
Separator         )|(?<Separator>,)
"@).matches($String).Groups | sort-object -property index -Descending | where {
		$_.success -eq $true -and $_.Length -gt 0 -and $_.name -ne '0'
	} | foreach -begin { $Conversion = $string }{
		$Name = $_.Name; $value = $_.Value; $Index = $_.Index; $Length = $_.Length;
		$insertion = switch ($name)
		{
			'TableStart' { '@{' } 'TableEnd' { '}' }
			'ArrayEnd' { ')' } 'ArrayStart' { '@(' }
			'MultiLineDelimitedLiteral' { "@`"`n$value`n`"@" }
			'MultiLineQuotedLiteral' { "@'`n$value`n`'@" } # need to deal with escape codes
			'DelimitedLiteral' { "$value" }
			'QuotedLiteral' { "$value" } # need to deal with escape codes
			'BareString' { "`"$value`"" } # 
			'BareKey' { "$value" } # 
			'Octal' { [Convert]::ToInt32($value, 8) } # 
			'LocalTime' { [timespan]::Parse("$value") } # 
			'OffsetDateTime' { [datetimeoffset]::Parse("$value") } # 
			'Date' {[datetime]::Parse("$value")}
			'Hex' { "$value" } # 
			'bin' { [convert]::ToInt32("$value", 2) } # 
			'NAN' { switch ( $Value){  '-INF' {'[double]::NegativeInfinity' }
            'INF' {'[double]::PositiveInfinity' } default { '[double]::NaN' }}} # 
			'Float' { "$value" } # 
			'int' { "$value" } # 
			'boolean' { "`$$value" } # 
			'Separator' {
				if ($TheStack[$Stackpointer] -eq 'table') { ';' }
                elseif ($ArrayEnd) {''}
				else { ',' }
			}
			default { '' }
		}
        $ArrayEnd=$false
		if ($name -eq 'ArrayEnd') { $TheStack[++$Stackpointer] = 'array'; $ArrayEnd=$true }
		elseif ($name -eq 'TableEnd') { $TheStack[++$Stackpointer] = 'table' }
		elseif ($name -in @('ArrayStart', 'TableStart')) { $Stackpointer-- }
		$BeforeRange = $Conversion.Substring(0, $index)
		$AfterRange = $Conversion.Substring($index + $Length)
		# Concatenate the parts with the new substring
		$Conversion = $BeforeRange + $insertion + $AfterRange
	} -end {
		#now turn the script into a hashtable/array
		$allowedCommands = @('Invoke-Expression')
		# Convert the array to a List<string> using array cast
		$allowedCommandsList = [System.Collections.Generic.List[string]]($allowedCommands)
		$lookingDodgy = $false
        #write-verbose "conversion was $Conversion"
		$scriptBlock = [scriptblock]::Create($Conversion)
		try { $scriptBlock.CheckRestrictedLanguage($allowedCommandsList, $null, $true) }
		catch
		{
			$lookingDodgy = $True
			Write-error " '$conversion' is not Valid Powershell Object Notation!"
		}
		if (!($lookingDodgy))
		{
			try { $scriptBlock.invoke() }
			catch { Write-error " '$conversion' is not Valid Powershell Object Notation!" }
		}
	} #End of the (end of the) foreach loop
} # end of the scriptblock
		
#a utility scriptblock to convert escaped characters in delimited strings
		$ConvertEscapedChars = {
			Param ([string]$String)
			@(@('\A"""[\t\r\n]{0,2}|"""\z', ''), @("\A'''[\t\r\n]{0,2}|'''\z", ''), @('\A"|"\z', ''),@("\A'|'\z", ''),
				@('\\\\', '\'), @("\\(?-s)\s+", ''), @('\\"', '"'), @('\\n', "`n"), @('\\t', "`t"),
				@('\\f', "`f"), @('\\b', "`b"), @('\\f', "`f")) |
			foreach {
				$String = $String -replace $_[0], $_[1]
			}
			[string]$String
		}
		#a utility scriptblock to convert unicode characters
		$ConvertEscapedUnicode = {
			Param ([string]$String) # $FormatTheBasicFlywayParameters (Don't delete this)
			
			([regex]'(?i)\\U\s*(?<Unicode>[0-9A-F]+)(?#Find All Unicode Strings)').matches($String) |
			sort-object -property index -Descending | foreach{
				$_.Groups | where { $_.success -eq $true } | foreach {
					if ($_.Name -eq '0') { $UnicodeStart = $_.index; $UnicodeLength = $_.Length }
					if ($_.Name -eq 'Unicode') { $UnicodeHexValue = $_.Value; }
				}
				
				$String = $String.Substring(0, $UnicodeStart) + [char][int]"0x$UnicodeHexValue" + $String.Substring($UnicodeStart + $UnicodeLength)
			}
			[string]$String
		}
		#a utility for splitting lists of strings
		$ParseStringArray = {
			Param ($String,
				$LD = ',')
			#write-verbose "delimiter $ld"
			([regex]@"
                  """(?<MultiLineQuotedLiteral>(?s:.)*?)"""$($LD)?\s?(?# Multiline String
                )|'''(?<MultiLinedelimitedLiteral>(?s:.)*?\s?)'''$($LD)?\s?(?# single-quoted Multiline String
                )|"(?<DoubleQuoted>(?<!\\").*?(?<!\\))"$($LD)?\s?(?# quoted " string
                )|'(?<delimited>[^']*)'$($LD)?\s?(?# Delimited ' string
                )|\s*(?<literal>[^$($LD)]*)$($LD)?\s?(?# Bare literal
                )
"@).matches($String) | foreach{
				$_.Groups | where {
					$_.success -eq $true -and $_.Length -gt 0 -and $_.name -ne '0'
				} | Sort-Object index | foreach {
                write-verbose "$string was a $($_.Name) sort of string"
					if ($_.Name -in ('MultiLineQuotedLiteral', 'DoubleQuoted'))
					{
						$ConvertEscapedChars.Invoke($ConvertEscapedUnicode.Invoke($_.value));
					}
					else { $_.value };
				}
			}
		}
		
		
	}
	Process
	{
	<# This script is for converting INI/Conf files to a hash table in PowerShell, 
with the addition of handling TOML-like nested structures processes the
INI/Conf file lines, creates a hash table, and handles nested sections using
a dotted notation. #>
		
		# Regex for parsing comments, sections, and key-value pairs
		$parserRegex = [regex]@'
(?<CommentLine>[#;](?<Value>.*))(?# Matches lines or end of lines starting with # or ;.
)|(?<ArrayOfTables>(?m:^)[\s]*?\[\[(?<Value>.{1,200}?)\]\])(?# Matches array of tables enclosed in [[]].
)|(?<section>(?m:^)[\s]*?\[(?<Value>.{1,200}?)\])(?# Matches section headers enclosed in [].
)|(?<MultilineLiteralKeyValuePair>(?m:^)[^=]{1,200}[ ]*?=[ ]*?'''(?s:.)+?[^\\]''')(?# Multi-line literal -' Key-Value Pair
)|(?<MultilineQuotedKeyValuePair>(?m:^)[^=]{1,200}[ ]*?=[ ]*?"""(?s:.)+?[^\\]""")(?# Multi-line quoted -" Key-Value Pair
)|(?<ArrayPair>(?m:^)[^=]{1,200}[ ]*?=[ ]*?(?<Value>\[(?s:.)+?\])\s*(?m:$))(?# Array [] possibly multiline
)|(?<InlineTable>(?<InlineSection>(?m:^)[^=]{1,200})[ ]*?=[ ]*?\{(?<list>(?s:.)+?)\})(?# Inline Table Key/value pairs {} possibly multiline
)|(?<QuotedKeyValuePair>(?m:^)[ ]*?[^=\r\n]{1,200}[ ]*?=[ ]*?".+")(?# Quoted Key-Value Pair
)|(?<DelimitedKeyValuePair>(?m:^)[ ]*?[^=\r\n]{1,200}[ ]*?=[ ]*?'.+?')(?# Delimited Key-Value Pair
)|(?<KeyCommaDelimitedValuePair>(?m:^).{1,40}=(?:'[^']*'|\b\w+\b)\s*,\s*(?:'[^']*'|\b\w+\b)(?:\s*,\s*(?:'[^']*'|\b\w+\b))*)(?# 
Matches key-value pairs where the value is a simple comma-delimited list
)|(?<KeyValuePair>(?m:^)[^=\r\n]{1,200}[ ]*?=[ ]*?[^#\r\n]{1,200})(?# Matches key-value pairs separated by =.
)
'@
# was
#)|(?<KeyValuePair>(?m:^)[ ]*?[[^=\s]]{1,40}[ ]*?=[ ]*?.{1,200})(?# Matches key-value pairs separated by =.
#)		
		# Parse the input string into a collection of matches based on the Regex
		# first take out line folding, '\' followed by linebreak plus indent
		# for backward compatibility
		$ConfigLinesToParse = $ConfigLinesToParse -ireplace '\\[\n\r]+\s*', ''
		# unwrap any inline tables *** replace this next line ***
		# $ConfigLinesToParse = $UnwrappedInlineTables.Invoke($ConfigLinesToParse)
		$allmatches = $parserRegex.Matches($ConfigLinesToParse)
		
		# Initialize variables
		$Comments = @(); $ObjectName = ''; $IniHashTable= @{ }
		$current = @{ } ;$ItsASection=$True
		
<# Process each match. For each match, determine the type (comment, section,
or key-value pair) and process accordingly.#>
		$allmatches | foreach -begin { $LocationList = @() }{
			$State = 'GetKVPair';
			$_.Groups | where { $_.success -eq $true -and $_.name -ne 0 }
		} | # Convert matches to objects with necessary properties
		Select name, index, length, value | Sort-Object index | foreach {
			$MatchName = $_.Name;
			$MatchValue = $_.Value;
            write-verbose "the match was '$matchname' giving $MatchValue"
			# Comments: Capture comment lines if needed.
			if ($MatchName -eq 'commentline')
			{
				# Handle comment lines
				$state = 'getCommentvalue'
			}
			elseif ($MatchName -eq 'value' -and $state -eq 'getCommentvalue')
			{
				# Capture comment value
				$Comments += $_.Value
				$State = 'GetKVPair'
			}
			#Sections: Update the current section name whenever necessary.
			elseif ($MatchName -eq 'section')
			{
				# Handle section headings
				$state = 'getSectionvalue'
			}
            elseif ($MatchName -eq 'ArrayOfTables')
			{
				# Handle section headings
				$state = 'getArrayOfTablevalues'
			}
			elseif ($MatchName -eq 'value' -and $state -eq 'getSectionvalue')
			{
				# Capture section value
				if ($_.Value -match '\A\s*\.') #it is a section nesting
				{
					if ($CurrentLocation -eq $null) { Error "subsection without a preceding section" }
					$ObjectName = $CurrentLocation + $_.Value
                    $ItsASection=$True;
				}
				else #Straightforward  section
				{
					$ObjectName = $_.Value
					$CurrentLocation = $ObjectName; #Remember in case there is more than one subsection
				}
				$LocationList = $ParseStringArray.Invoke($ObjectName, '\.')
				$State = 'GetKVPair'
			}
            elseif ($MatchName -eq 'value' -and $state -eq 'getArrayOfTablevalues')
			{
				$ObjectName = $null; #so we know it isn't a section (object)
				$ArrayName = $_.Value #could be dotted, denoting a # nested array of tables
				If ($ArrayName -notin $UsedArrayNames) { $UsedArrayNames += $ArrayName }
                #cope with a dotted array
				$ArrayList = $ParseStringArray.Invoke($ArrayName, '\.')
                $ArrayPosition = $IniHashTable
				$ArrayList | Select -First ($ArrayList.count - 1) | foreach -Begin { $ArrayPosition = $IniHashTable } {
					$key = $_.Trim()
                    #if it doesn't exist create an object
					if (-not $ArrayPosition.Contains($key)) { $ArrayPosition[$key] = @{ } }
					$ArrayPosition = $ArrayPosition[$key]
				}
                #if our array is new and empty 
                $Basename= $($ArrayList[$ArrayList.count - 1])
                # we have $Basename $($ArrayPosition.GetType().Name) and  $($ArrayPosition|convertto-json -Compress)
                if ($ArrayPosition.GetType().Name -eq 'Hashtable') {
                    write-verbose " it is a Hashtable $($ArrayPosition|convertto-json -Compress)"                   
                    if  (!($ArrayPosition.Contains($Basename)))
				    {
					    $ArrayPosition.$Basename=[System.Collections.ArrayList]::new()
                    }
                    $ArrayPosition.$Basename+=@{}
                }
                elseif  ($ArrayPosition.GetType().Name -eq 'object[]')
                    {
                    write-verbose "the object is $($ArrayPosition.Count) long having $($ArrayPosition[$ArrayPosition.Count-1]|ConvertTo-json -Compress)"
                    if ($Basename -notin $ArrayPosition[$ArrayPosition.Count-1].Keys)
                        {$ArrayPosition[$ArrayPosition.Count-1]+=@{$Basename=[System.Collections.ArrayList]::new()}}
                    #$ArrayPosition.$Basename+=@{}
                    write-verbose " it is an object $($ArrayPosition|convertto-json -Compress)"                   
                    }
				else
                    {Write-Verbose "Lost $Basename" }
                
                $ItsASection=$False; 

                $State = 'GetKVPair'
			}
			else
			{
<#Key-Value Pairs: Split and trim the key and value. Handle nested keys 
 by splitting on . and creating necessary nested hash tables.#>
				if ($MatchName -in ('MultilineLiteralKeyValuePair', 'QuotedKeyValuePair', 'MultilineQuotedKeyValuePair',
						'DelimitedKeyValuePair', 'KeyValuePair', 'KeyCommaDelimitedValuePair', 'ArrayPair', 'InlineTable'))
				{
					# Process key-value pairs
					# if the value has no dot, it is a relative reference. if it  starts with a dot, it is
					# a relative reference, otherwise it must be an absolute reference
					# Split the expression into key and value, removing leading dot if present
					Write-verbose $MatchName
					#$Assignment = "$($_.Value)" -ireplace '\A\s*\.', '' -split '=' | foreach{ "$($_)".trim() }
					$Assignment = $MatchValue  -split '=', 2 | foreach { "$($_)".trim() }
					# if there is no section, the lvalue contains the location 
					# or if the lvalue is relative just combine the two
					$Rvalue = "$($Assignment[1])".Trim();
					$Lvalue = $Assignment[0].trim();
					if ($Matchname -in ('InlineTable', 'ArrayPair')) #it is an array, assigned to a key
					{
						Write-verbose "Arraypair for '$lvalue' '$Rvalue' being processed"
						$Rvalue = $BuildInlineTableorArray.invoke($RValue)
					}
					elseif ($Matchname -in ( 'MultilineQuotedKeyValuePair',	'QuotedKeyValuePair',
                                             'MultilineLiteralKeyValuePair',	'DelimitedKeyValuePair'))
					{
						$RValue=$ConvertEscapedChars.Invoke($ConvertEscapedUnicode.Invoke($Rvalue)) -join "";
					}
                    elseif ($Matchname -eq 'KeyCommaDelimitedValuePair')
					{
						Write-verbose "array $RValue"
                        $RValue = $BuildInlineTableorArray.invoke($RValue);
 					}
					else
					{
						if ($RValue -like '*,*') #it is a list 
						{ $RValue = $BuildInlineTableorArray.invoke($RValue) }
						else { $RValue = $ConvertStringToNativeValue.invoke($RValue)[0] }#sreingarray
					}
                    #$ParseStringArray.invoke('pinky,perky,bill,ben')
					$ObjectHierarchy = $ParseStringArray.Invoke($LValue, '\.')
					# if there is no defined location and there is no initial dot 
					#then use the LValue as the location
					If ($LocationList.Count -gt 0)
					{ $tree = $LocationList + $ObjectHierarchy }
					Else
					{
						$tree = $ObjectHierarchy
					}
                    if ($ItsASection)
                    {
					    # now we figure out where to put it
					    # Traverse the tree to create necessary nested structures
					    $tree | Select -First ($tree.count - 1) | foreach -Begin { $current = $IniHashTable } {
						    $key = $_.Trim()
						    if (-not $current.Contains($key))
						    {
							    $current[$key] = @{ }
						    }
						
						    $current = $current[$key]
					    }
					    # Set the value at the appropriate key in the nested structure.
					
					    $AssignedValue = $Rvalue
					    if ($current[$tree[$tree.count - 1]] -eq $null)
					    {Try
						   { $current[$tree[$tree.count - 1]] = $AssignedValue}
                        catch {write-warning "Key $key redefined with $AssignedValue"}
					    }
					    else { write-warning "Attempt to redefine Key $lvalue with '$AssignedValue'" }
                    }
                    else #then it is an array
                    {
                    Write-Verbose "writing $Basename at $($ArrayPosition.GetType().Name) which is   $($ArrayPosition|ConvertTo-json -Compress)"
                    if ($ArrayPosition.GetType().Name -eq 'Hashtable')
                        {$ArrayPosition.$Basename[$ArrayPosition.$Basename.count-1] += @{ $lvalue = $rvalue }}
                    else
                        {Write-Verbose " we are trying to write to the $basename array at $($ArrayPosition.$Basename) that has keys $($ArrayPosition.Keys -join ',')"
                        $ArrayPosition[$ArrayPosition.count-1].$Basename += @{ $lvalue = $rvalue }}
                    }
				}
				else
				{
					# Handle unexpected cases
					Write-verbose "Unidentified object '$ObjectName' named '$($_.Name)' of value '$($_.Value)'"
				}
			}
		}
	}
	End
	{
		$IniHashTable
	}
}

If ($Testing){


@'
  [ { x = 1, y = 2, z = 3 },
    { x = 7, y = 8, z = 9 },
    { x = 2, y = 4, z = 8 } ]
'@|convertfrom-ini


@{
	'flyway' = @{
		'url' = 'jdbc:mysql://localhost:3306/customer_test?autoreconnect'; 'placeholders' = @{
			'email_type' = @{
				'work' = 'Traba'; 'primary' = 'Primario'
			}; 'phone_type' = @{ 'home' = 'Casa' }
		};
		'password' = 'pa$$w3!rd'; 'driver' = 'com.mysql.jdbc.Driver';
		'locations' = 'filesystem:src/main/resources/sql/migrations';
		'schemas' = 'customer_test'; 'user' = 'sysdba'
	}
}


<# Equivalence is where two ini files representing the same hashtable 
via different syntaxes are tested to give the same result #>
@(
	
<#
 @{'Name'='value'; 'Type'='equivalence/ShouldBe'; 'Ref'=@'
'@; 'Diff'=@' 
'@}
#>
	
	
	@{
		'Name' = 'Dotted Section'; 'Type' = 'equivalence'; 'Ref' = @'
[dog."tater.man"]
type.name = "pug"
'@; 'Diff' = @' 
[dog."tater.man".type]
name = "pug"
'@
	},
	
	@{
		'Name' = 'Single Entry Array'; 'Type' = 'ShouldBe'; 'Ref' = @'
[flyway]
mixed = true
outOfOrder = true
locations = ["filesystem:migrations"]
validateMigrationNaming = true
defaultSchema = "dbo"

[flyway.placeholders]
placeholderA = "A"
placeholderB = "B"
'@; 'ShouldBe' = @{
			'flyway' = @{
				'url' = 'jdbc:mysql://localhost:3306/customer_test?autoreconnect'; 'placeholders' = @{
					'email_type' = @{
						'work' = 'Traba'; 'primary' = 'Primario'
					}; 'phone_type' = @{ 'home' = 'Casa' }
				};
				'password' = 'pa$$w3!rd'; 'driver' = 'com.mysql.jdbc.Driver';
				'locations' = 'filesystem:src/main/resources/sql/migrations';
				'schemas' = 'customer_test'; 'user' = 'sysdba'
			}
		}
	}
) | foreach{
	$FirstString = $_.Ref; $SecondString = $_.Diff, $ShouldBe = $_.Shouldbe;
    if ( $_.Type -notin ('equality','equivalence','shouldbe')) 
        {Write-error "the $($_.Name) $($_.Type) Test was of the wrong type"}
    if ($FirstString -eq $null){Write-error "no reference object in the $($_.Name) $($_.Type) Test"}
	$ItWentWell = switch ($_.Type)
	{
		
		'Equivalence' {
			(($FirstString | convertfrom-ini | convertTo-json -depth 5) -eq ($SecondString | convertfrom-ini | convertTo-json -depth 5))
		}
        'Equality' { 
            (($FirstString|convertfrom-ini|convertTo-json -depth 5) -eq $SecondString)
        }
		'ShouldBe' {
			((diff-Objects -Ref ($FirstString | convertfrom-ini) -diff $ShouldBe | where { $_.Match -ne '==' } -eq $null))
		}
		default { $false }
	}
	write-output "The $($_.Name) $($_.Type) test went $(if ($ItWentWell) { 'well' }
		else { 'badly' })"
}







#Array with terminating comma
ConvertFrom-INI @'
array1 = ["value1", "value2", "value3",] 
'@
@{'array1' = @('value1','value2','value3')}

#Map
ConvertFrom-INI @'
map1 = { key1 = "value1", key2 = "value2" }
'@|convertto-json

<#gives
@{'map1' = @{'key1' = 'value1';'key2' = 'value2'}}
#>

ConvertFrom-INI @'
# The following strings are byte-for-byte equivalent:
[truisms]
str1 = "The quick brown fox jumps over the lazy dog."
str2 = """
The quick brown \


  fox jumps over \
    the lazy dog."""
str3 = """\
       The quick brown \
       fox jumps over \
       the lazy dog.\
       """
'@|convertto-json -depth 3

$Ref=ConvertFrom-INI @'
[Config]
"127.0.0.1" = "value"
"character encoding" = "value"
'key2' = "value"
'quoted "value"' = "value"
name = "Orange"
physical.color = "orange"
physical.shape = "round"
site."google.com" = true
'@
$diff=@{'Config' = @{'site' = @{'google.com' = 'true'};'quoted "value"' = 'value';
  '127.0.0.1' = 'value';'key2' = 'value';'name' = 'Orange';'physical' = @{'shape' = 'round';'color' = 'orange'};
  'character encoding' = 'ENG'
  }}
diff-Objects -Ref $Ref -Diff $Diff  | where {$_.Match -ne '==' }
diff-objects -Ref $Ref -Diff $Diff 

ConvertFrom-json -AsHashtable @'
{
    "Config":  {
                   "site":  {
                                "google.com":  "true"
                            },
                   "quoted \"value\"":  "value",
                   "127.0.0.1":  "value",
                   "key2":  "value",
                   "name":  "Orange",
                   "physical":  {
                                    "shape":  "round",
                                    "color":  "orange"
                                },
                   "character encoding":  "ENG"
               }
}
'@

Diff-Objects  $Ref  $Diff -IncludeEqual -Property 








ConvertFrom-INI @'
[dummy]
flyway.driver=com.mysql.jdbc.Driver
flyway.url=jdbc:mysql://localhost:3306/customer_test?autoreconnect=true
flyway.user=sysdba
flyway.password=pa$$w3!rd
flyway.schemas=customer_test
flyway.locations=filesystem:src/main/resources/sql/migrations
flyway.placeholders.email_type.primary=Primario
flyway.placeholders.email_type.work=Traba
flyway.placeholders.phone_type.home=Casa
'@|convertto-jSON -depth 5

ConvertFrom-INI @'
[environments.sample]
url = "jdbc:h2:mem:db"
user = "sample user"
password = "sample password"
dryRunOutput = "/my/output/file.sql"

[flyway]
# It is recommended to configure environment as a commandline argument. This allows using different environments depending on the caller.
 environment = "sample" 
 locations = ["filesystem:path/to/sql/files",Another place]
 [environments.build]
 url = "jdbc:sqlite::memory:"
 user = "buildUser"
 password = "buildPassword"

[flyway.check]
buildEnvironment = "build"
'@|convertto-json -depth 5


ConvertFrom-INI @'
flyway.driver=com.mysql.jdbc.Driver
flyway.locations=[filesystem:src/main/resources/sql/migrations,
    ./SQL/migrations,
    ./Scripts/callbacks]
'@|convertto-TOML -depth 5

ConvertFrom-INI @'
flyway.placeholders.email_type.primary=Phil.factor@MyWork.com
flyway.placeholders.email_type.work=Phil.factor@MyWork.com
flyway.placeholders.phone_type.home=Phil.factor@MyHome.com
[Domain]
Name = example.com
[.Build]
buildEnvironment = "build"
'@|convertto-TOML -depth 5


ConvertFrom-INI @'
str = "I'm a string. \"You can quote me\". Name\tJos\u00E9\nLocation\tSF."
# This is a full-line comment
key = "value"  # This is a comment at the end of a line
another = "# This is not a comment"

'@|convertto-json -depth 5

ConvertFrom-INI @'
"127.0.0.1" = "value"
"character encoding" = "value"
"ʎǝʞ" = "value"
'key2' = "value"
'quoted "value"' = "value"
'@|convertto-json -depth 5

ConvertFrom-INI @'
name = "Orange"
physical.color = "orange"
physical.shape = "round"
site."google.com" = true
'@|convertto-json -depth 5

ConvertFrom-INI @'
fruit.name = "banana"     # this is best practice
fruit. color = "yellow"    # same as fruit.color
fruit . flavor = "banana"   # same as fruit.flavor
'@|convertto-json -depth 5

ConvertFrom-INI @'
name = "Tom"
name = "Pradyun"
'@|convertto-json -depth 5

ConvertFrom-INI @'
spelling = "favorite"
"spelling" = "favourite"
'@|convertto-json -depth 5

# THE FOLLOWING IS INVALID
ConvertFrom-INI @'
# This defines the value of fruit.apple to be an integer.
fruit.apple = 1

# But then this treats fruit.apple like it's a table.
# You can't turn an integer into a table.
fruit.apple.smooth = true
'@|convertto-json -depth 5

$What=ConvertFrom-INI @'
MyArray = ["Yan",'Tan','Tethera']
'@
$what|convertTo-json -Compress

ConvertFrom-INI @'
[dog."tater.man"]
type.name = "pug"
'@|convertto-json -Compress -depth 5

ConvertFrom-ini @'
# Top-level table begins.
name = Fido
breed = "pug"

# Top-level table ends.
[owner]
name = 'Regina Dogman'
member_since = 1999-08-04
'@|convertto-json -Compress -depth 5



ConvertFrom-ini  @'
# Settings are simple key-value pairs
flyway.key=value
# Single line comment start with a hash

# Long properties can be split over multiple lines by ending each line with a backslash
flyway.locations=filesystem:my/really/long/path/folder1,\
    filesystem:my/really/long/path/folder2,\
    filesystem:my/really/long/path/folder3

# These are some example settings
flyway.url=jdbc:mydb://mydatabaseurl
flyway.schemas=schema1,schema2
flyway.placeholders.keyABC=valueXYZ
'@ |convertto-json  -depth 5

@'
# Flyway configuration
[flyway]
environment = "prod"
outOfOrder = true
# baseline settings
baselineOnMigrate = true
baselineVersion = "1.0"
baselineDescription = "Initial baseline"
locations = ["filesystem:sql/migrations"]
callbacks = ["com.example.MyCallback"]

# Placeholders
[flyway.placeholders]
Project = "myProject"
Branch = "myBranch"
Variant = "myVariant"

# Code Analysis (Enterprise feature)
[flyway.codeAnalysis]
enabled = true
rule1.regex = "(?i)^select\\s+.*\\s+from\\s+.*"
rule1.description = "Ensure all SELECT statements follow the company SQL guidelines."
rule2.regex = "^insert\\s+into\\s+.*\\s+values\\s+.*"
rule2.description = "Check all INSERT INTO statements for correct value assignment."
rule3.regex = "^update\\s+.*\\s+set\\s+.*"
rule3.description = "Verify UPDATE statements conform to standard practices."

[environments] #You define an environment in the environments (plural) namespace 

# The environment variable has to be lower case
[flyway.dev]
url = "jdbc:h2:mem:flyway_db"
user = "devuser"
password = "devpassword"
locations = ["filesystem:sql/migrations_dev"]

[environments.test]
url = "jdbc:postgresql://localhost:5432/testdb"
user = "testuser"
password = "testpassword"
locations = ["filesystem:sql/migrations_test"]

[environments.prod]
url = "jdbc:postgresql://localhost:5432/proddb"
user = "produser"
password = "prodpassword"
locations = ["filesystem:sql/migrations_prod"]

[environments.full]
url = "jdbc:h2:mem:flyway_db"
user = "myuser"
password = "mysecretpassword"
driver = "org.h2.Driver"
schemas = ["schema1", "schema2"]
connectRetries = 10
connectRetriesInterval = 60
initSql = "ALTER SESSION SET NLS_LANGUAGE='ENGLISH';"
jdbcProperties = { accessToken = "access-token" }
resolvers = ["my.resolver.MigrationResolver1", "my.resolver.MigrationResolver2"]
'@| ConvertFrom-ini |convertto-json  -depth 5 
@'
[environments.prod]
url = "jdbc:postgresql://localhost:5432/proddb"
user = "produser"
password = "prodpassword"
locations = ["filesystem:sql/migrations_prod"]

name = { first = "Tom", last = "Preston-Werner" }
point = { x = 1, y = 2 }
animal = { type.name = "pug" }
'@| ConvertFrom-ini |convertto-json  -depth 5 

@'
contributors = [
  "Foo Bar <foo@example.com>",
  { name = "Baz Qux", email = "bazqux@example.com", url = "https://example.com/bazqux" }
]
'@| ConvertFrom-ini |convertto-json  -depth 5 

@'
[environments.prod]
url = "jdbc:postgresql://localhost:5432/proddb"
user = "produser"
password = "prodpassword"
locations = ["filesystem:sql/migrations_prod"]
[section]
classic=true
[[project.PS.CleanData]]
Name='Phil'
Surname='Factor'
[[project.PS.InsertData]]
Name='Jenny'
Surname='Factor'

'@| ConvertFrom-ini |convertto-json  -depth 5 -Compress

@'
owner = "andrew"

[section]
domain = "example.com"

[section.subsection]
foo = "bar"

[[fruit]]
name = "apple"
color = "red"

[[fruit.variety]]
name = "red delicious"

[[fruit.variety]]
name = "granny smith"

[[fruit]]
name = "banana"
color = "yellow"

[[fruit.variety]]
name = "cavendish"
'@| ConvertFrom-ini|convertto-json  -depth 5 

$What='{"color":"red","name":"apple","variety":[]}'|convertfrom-json
$What.variety+=@{'name' = "red delicious"}
$What.variety+=@{'name' = "Gordon Blimey"}
$what|convertTo-json


@'
databaseType = "SqlServer"
name = "my project"
id = "0018e518-fd44-44d1-8113-5862cbd46874"
 
[flyway]
mixed = true
outOfOrder = true
locations = ["filesystem:migrations"]
validateMigrationNaming = true
defaultSchema = "dbo"
 
[flyway.plugins.clean]
mode = "all"[flywayDesktop]
developmentEnvironment = "development"
shadowEnvironment = "shadow"
schemaModel = "./schema-model"
 
[redgateCompare]
filterFile = "filter.rgf"
 
[redgateCompare.sqlserver]
filterFile = "Filter.scpf"
 
[redgateCompare.sqlserver.options.behavior]
addCreateOrAlterForRerunnableScripts = false
addDropAndCreateForRerunnableScripts = false
addNoPopulationToFulltextIndexes = false
addObjectExistenceChecks = false
addOnlineOnWhenCreatingIndexesOrAlteringColumns = false
addWithEncryption = false
considerNextFilegroupInPartitionSchemes = true
decryptEncryptedObjects = true
disableAutoColumnMapping = false
dontUseAlterAssemblyToChangeClrObjects = false
forbidDuplicateTableStorageSettings = false
forceColumnOrder = false
ignoreMigrationScripts = false
includeDependencies = true
includeRoleExistenceChecks = true
includeSchemaExistenceChecks = true
inlineFulltextFields = false
inlineTableObjects = false
useCaseSensitiveObjectDefinition = false
useDatabaseCompatibilityLevel = false
useSetStatementsInScriptDatabaseInfo = false
writeAssembliesAsDlls = false
 
[redgateCompare.sqlserver.options.ignores]
ignoreAuthorizationOnSchemaObjects = false
ignoreBindings = false
ignoreChangeTracking = false
ignoreCollations = true
ignoreComments = false
ignoreDataCompression = true
ignoreDataSyncSchema = false
ignoreDatabaseAndServerNameInSynonyms = true
ignoreDmlTriggers = false
ignoreDynamicDataMasking = false
ignoreEventNotificationsOnQueues = false
ignoreExtendedProperties = false
ignoreFileGroupsPartitionSchemesAndPartitionFunctions = true
ignoreFillFactorAndIndexPadding = true
ignoreFullTextIndexing = false
ignoreIdentitySeedAndIncrementValues = false
ignoreIndexes = false
ignoreInsteadOfTriggers = false
ignoreInternallyUsedMicrosoftExtendedProperties = false
ignoreLockPropertiesOfIndexes = false
ignoreNocheckAndWithNocheck = false
ignoreNotForReplication = true
ignoreNullabilityOfColumns = false
ignorePerformanceIndexes = false
ignorePermissions = false
ignoreReplicationTriggers = true
ignoreSchemas = false
ignoreSensitivityClassifications = false
ignoreSetQuotedIdentifierAndSetAnsiNullsStatements = false
ignoreSquareBracketsInObjectNames = false
ignoreStatistics = true
ignoreStatisticsIncremental = false
ignoreStatisticsNoRecomputePropertyOnIndexes = false
ignoreSynonymDependencies = false
ignoreSystemNamedConstraintAndIndexNames = false
ignoreTsqltFrameworkAndTests = true
ignoreUserProperties = true
ignoreUsersPermissionsAndRoleMemberships = true
ignoreWhiteSpace = true
ignoreWithElementOrder = true
ignoreWithEncryption = false
ignoreWithNoCheck = true
 
[redgateCompare.sqlserver.data.options.mapping]
includeTimestampColumns = false
useCaseSensitiveObjectDefinition = true
 
[redgateCompare.sqlserver.data.options.comparison]
compressTemporaryFiles = false
forceBinaryCollation = true
treatEmptyStringAsNull = false
trimTrailingWhiteSpace = false
useChecksumComparison = false
useMaxPrecisionForFloatComparison = false
 
[redgateCompare.sqlserver.data.options.deployment]
disableDdlTriggers = true
disableDmlTriggers = false
disableForeignKeys = false
dontIncludeCommentsInScript = false
dropPrimaryKeysIndexesAndUniqueConstraints = false
reseedIdentityColumns = false
skipIntegrityChecksForForeignKeys = false
transportClrDataTypesAsBinary = false
'@| ConvertFrom-ini|convertto-TOML  -depth 10


$tricky=@'
[environments.development]
url = "jdbc:oracle:thin:@//Dev01:1521/dev"
user = "developmentUsername"
password = "developmentPassword"
schemas= ["FW-PROJECT"]
displayName = "Development database"
[environments.Test]
token = "azureAdInteractive"

[environments.production.resolvers.azureAdInteractive]
tenantId = "tenant-id"
clientId = "client-id"

[environments.philsPlayground]
url = "jdbc:oracle:thin:@//Philf:1521/dev"
user = "developmentUsername"
password = "developmentPassword"
schemas= ["FW-PROJECT"]
displayName = "Development database"

 
[environments.test]
url = "jdbc:oracle:thin:@//Test01:1521/test"
user = "shadowUsername"
password = "shadowPassword"
schemas= ["FW-PROJECT_SHADOW"]
displayName = "Shadow database"
provisioner = "clean"

[environments.Deployment]
url = "jdbc:oracle:thin:@//Hoster:1521/DMZ"
user = "shadowUsername"
password = "shadowPassword"
schemas= ["FW-PROJECT_SHADOW"]
displayName = "Shadow database"
provisioner = "clean"
'@| ConvertFrom-ini|convertto-TOML
}

