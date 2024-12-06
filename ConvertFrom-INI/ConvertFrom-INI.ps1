
$VerbosePreference='continue'
<#
	.SYNOPSIS
		Converts a string containing a CFG, Conf, or .INI file (not full TOML) into 
        the corresponding powershell Hashtable
	
	.DESCRIPTION
		This routine will interpret an INI file, including one  that contains nested 
        sections or multi-line strings into a Powershell Object. It doesn't do elaborate
        syntax check.
	
	.PARAMETER ConfigLinesToParse
		The  String containing the INI or Config lines, usually read from a file
	
	.EXAMPLE
				PS C:\> ConvertFrom-INI -ConfigLinesToParse 'Value1'
	
	.NOTES
In its broader sense, INI is an informal format which lends itself well to ad-hoc implementation
 while remaining human-configurable. Consequently, many varying specifications (where sometimes
  a parser implementation is the only specification ever written) exist, called INI dialects.

INI interpretations depend a lot on personal taste and the needs of the computing environment,
such as whitespace preservation, field type information, case sensitivity, or preferred comment
delimiters. This makes INI prone to proliferation. Nonetheless, INI-flavoured implementations 
typically share common design features: a text file consisting of a key-value pair on each line,
 delimited by an equals sign, organized into sections denoted by square brackets.

In its most complicated interpretation, the INI format is able to express arbitrary S-expressions,
making it equivalent to standardised formats like XML or JSON, albeit with a syntax which is not set
in stone and to some may feel more comfortable.

As the INI file format is not rigidly defined, many parsers support features beyond those that form
the common core. Implemented support is highly volatile
This parser aims to read the whole range including TOML
		
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
        $StripDelimiters=@'
^["\'](.*)["\']$
'@
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
        write-verbose "conversion was $Conversion"
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
			write-verbose "delimiter $ld"
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
(?#             Regex for main parser of ini file
)(?<CommentLine>[\s]*?[#;](?<Value>.*))(?# Matches lines or end of lines starting with # or ;.
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
)|(?<Error>\S{1,200}[^#\r\n]{1,200})(?# matches any line. If nothing above matches, it is an error
)(?#            Regex for main parser of ini file)
'@
# was
#)|(?<KeyValuePair>(?m:^)[ ]*?[[^=\s]]{1,40}[ ]*?=[ ]*?.{1,200})(?# Matches key-value pairs separated by =.
#)		
		# Parse the input string into a collection of matches based on the Regex
		# first take out line folding, '\' followed by linebreak plus indent
		# for backward compatibility
		$ConfigLinesToParse = $ConfigLinesToParse -ireplace '\\[\n\r]+\s*', ''
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
            if ($MatchName -eq 'error')
			{
				# Handle comment lines
				Write-Warning "Error at $Matchvalue"
			}
			elseif ($MatchName -eq 'commentline')
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
                     # write-verbose " it is an object $($ArrayPosition|convertto-json -Compress)"                   
                    }
				else
                    { # Write-Verbose "Lost $Basename"
                    }
                
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
					# Write-Verbose $MatchName
					$Assignment = $MatchValue  -split '=', 2 | foreach { "$($_)".trim() }
					# if there is no section, the lvalue contains the location 
					# or if the lvalue is relative just combine the two
					$Rvalue = "$($Assignment[1])".Trim();
					$Lvalue = $Assignment[0].trim();
                    if ([string]::IsNullOrEmpty($Lvalue)){Write-warning "Key/LValue is missing"}
                    if ([string]::IsNullOrEmpty($Rvalue)){Write-warning "Value/RValue for key $LValue is missing"}
					#Write-verbose "$Lvalue = $RValue"
                    if ($Matchname -in ('QuotedKeyValuePair'))
                        {$UndelimitedString=$RValue -replace $StripDelimiters, '$1'  ;
                        if ($UndelimitedString -imatch '(?<!\\)\"'){
                            Write-warning "$MatchValue contains a syntax error!"}  }
					if ($Matchname -in ('InlineTable', 'ArrayPair')) #it is an array, assigned to a key
					{
						Write-verbose "Inline value of $Matchname of '$lvalue' '$Rvalue' being processed"
						$Result = $BuildInlineTableorArray.invoke($RValue)
                        if ($result.count -eq 1 -and $Matchname -eq 'InlineTable') {
                              $RValue=$Result[0]} 
                        else {$RValue=$Result}
                      
					}
					elseif ($Matchname -in ( 'MultilineQuotedKeyValuePair',	'QuotedKeyValuePair',
                                             'MultilineLiteralKeyValuePair',	'DelimitedKeyValuePair'))
					{
						$RValue=$ConvertEscapedChars.Invoke($ConvertEscapedUnicode.Invoke($Rvalue)) -join "";
					}
                    elseif ($Matchname -eq 'KeyCommaDelimitedValuePair')
					{
						# Write-Verbose "array $RValue"
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
                    # Write-Verbose "writing $Basename at $($ArrayPosition.GetType().Name) which is   $($ArrayPosition|ConvertTo-json -Compress)"
                    if ($ArrayPosition.GetType().Name -eq 'Hashtable')
                        {$ArrayPosition.$Basename[$ArrayPosition.$Basename.count-1] += @{ $lvalue = $rvalue }}
                    else
                        {# Write-Verbose " we are trying to write to the $basename array at $($ArrayPosition.$Basename) that has keys $($ArrayPosition.Keys -join ',')"
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
