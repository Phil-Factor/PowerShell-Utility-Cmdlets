$TestConvertToTOML=$False

<#
	.SYNOPSIS
		Converts an object to TOML
	
	.DESCRIPTION
		takes a hashtable or PSCustomObject with maybe arrays as parameters, and converts it to TOML
	
	.PARAMETER OurObject
		This is the only required parameter, being the powershell object that you wish to process
	
	.PARAMETER Basename
		used internally - specifies the parent of the object
	
	.PARAMETER Depth
		used internally - the allowable recursion level
	
	.PARAMETER Recursion
		only used internally -the actual recursion level.
	
	.EXAMPLE
				PS C:\> ConvertTo-TOML -OurObject $value1 -Basename 'Value2'
	
	.NOTES
		Additional information about the function.
#>
function ConvertTo-TOML
{
	[CmdletBinding()]
	[OutputType([string])]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true)]
		[object]$OurObject,
		[string]$Basename = '',
		[string]$LocalPrefix = '',
		[int]$Recursion = 0,
		[int]$Depth = 5) 

    
$ValueToTomlString = {<# convert a value to a string #>
    param (
        [Parameter(Mandatory)]
        [object]$Value
    )
    
    switch ($Value.GetType().Name) {
        'String' {
            # TOML strings need to be enclosed in quotes and escaped
            $Delimiter='"';
            if ($Value -match "(\r?\n)") { $Delimiter='"""'}
            return $Delimiter + ($Value -replace '"', '\"') + $Delimiter
        }
        {$psitem -in ('Int32','Int64','Byte','SByte')} {
            # Integers are represented directly
            return $Value
        }
        {$psitem -in ('Double','Single')} {
            # Floats are represented directly, but check for NaN or Infinity
            if ([double]::IsNaN($Value)) {
                return 'nan'
            } elseif ([double]::IsInfinity($Value)) {
                if ($Value -gt 0) {'inf'} else {'-inf'}
                
            } else {
                return $Value
            }
        }
        'Boolean' {
            # Booleans in TOML are 'true' or 'false'
            return $Value.ToString().ToLower()
        }
        'DateTime' {
            # Handle both local and offset times
            if ($Value.Kind -eq [System.DateTimeKind]::Local) {
                return $Value.ToString("yyyy-MM-ddTHH:mm:ss") # Local time format
            } else {
                return $Value.ToString("yyyy-MM-ddTHH:mm:ssK") # Offset datetime
            }
        }
        'Byte[]' {
            # Assume a binary array represented in base64 for TOML
            return '"0b' + [convert]::ToBase64String($Value) + '"'
        }
        {$psitem -in ('UInt64','UInt32','UInt16')} {
            # Handle unsigned integers
            return $Value
        }
        'Char' {
            # Single characters treated as strings
            return '"' + $Value + '"'
        }
        default {
            throw "Unsupported type: $($Value.GetType().Name)"
        }
    }
    }


   	$Typename = $OurObject.GetType().Name
	if ($Recursion -ge $Depth) { write-error "recursion level $Depth  exceeded" }
	$ValidObjectTypes = @('PSCustomObject', 'HashTable','Collection`1', 'object[]')
	$PreviousBasename = '';
	$Sep = switch ($Basename) # manage separators in dotted sections
	{
		'' { '' }
		default { '.' }
	}
    <# Deal with Key/Value pair objects. for a general utility, you'd need to convert
       many different types of object. Here, wy just deal with the most common ones #>
    Write-Verbose "Type= $Typename, Basename= $Basename, Recursionlevel= $Recursion"
	if ($Typename -in ('HashTable', 'PSCustomObject'))
	{
		if ($Typename -eq 'HashTable')
		{
			$OurKeyValuePairs = foreach ($key in $OurObject.Keys)
			{
				@{ 'name' = "$key"; 'value' = $OurObject[$key] }
			}
		}
		elseif ($Typename -eq 'PSCustomObject')
		{
			$OurKeyValuePairs = $OurObject.psobject.Properties | foreach{
				@{ 'name' = $_.Name; 'value' = $_.Value }
			}
		}
		else { Write-warning "couldn't deal with key/value object of the type  $Typename" }
		
        #$OurKeyValuePairs|foreach{write-warning "$($_.name)"}
        $OurKeyValuePairs | foreach{ # for each item
			$name = $_.Name
			$value = $_.Value
            write-verbose "$name value is of type $($value.GetType().Name)"
			if ($value.GetType().Name -in $ValidObjectTypes)#if it is one of our objects
			{
            $updatedRecursion=$Recursion
             ConvertTo-TOML  $value  "$Basename$Sep$name" "$LocalPrefix$name"  $updatedRecursion }
			else #it was not an object
			{
                #is it a different assignment
				if (($PreviousBasename -ne $Basename) -and ($LocalPrefix -ne ''))
				{ $Section = "`n[$basename]`n" }
				else { $Section = '' }
				$PreviousBasename = $Basename;
				$DisplayedValue = switch ($value.GetType().name) { 'string'{ "`"$value`"" }
					default { $value } }
				write-output "$Section$name = $DisplayedValue"
				$PreviousBasename = $Basename;
			}
			
		}
	}
    elseif ($Typename -eq 'object[]')
	{
		$OurObject | ForEach-Object -Begin { $OurIndex = 0; $Array=@() } {
			$Value = $_;
            $TheTypeOfValue=$value.GetType().Name
			if ($TheTypeOfValue -in $ValidObjectTypes)
			{
				write-output "`n[[$Basename]]"
				ConvertTo-TOML $value  "$Basename"  '' $Recursion
			}
			
			else {
                write-verbose "a $Basename $TheTypeOfValue value $Value"
                $Array+=  $ValueToTomlString.invoke($Value) 
                  }
			$OurIndex++
		} -end {if ($Array.Count -gt 0) {"$Basename = [$($Array -join ',')]" } }
		
	}
	elseif ($Typename -in  ('Collection`1'))
	{
         write-verbose "$name is an array"
        $OurObject | ForEach-Object -Begin { $OurIndex = 0;$Rendering= "$name = [ "; $Separator='' } {
			$Value = $_;
			if ($value.GetType().Name -in $ValidObjectTypes)
			{
				write-output "`n[[$Basename]]"
                $updatedRecursion=$Recursion
				ConvertTo-TOML $value "$Basename" '' $updatedRecursion
			}
			
			else { 
            $Rendering+= "$Separator$value"
            $Separator=', '
            write-verbose "object type=$($value.GetType().Name) Value='$Value'"
            }
            #$Basename[$OurIndex] = $Value }
			$OurIndex++
		}
        write-output "$Rendering ]"
		
	}
	else { Write-Warning "cannot deal with a $Typename " }
}

if ($TestConvertToTOML) {

@(
	@(
		'Compliance With public example',
		@'
{
  "fruits": [
    {
      "name": "apple",
      "physical": {
        "color": "red",
        "shape": "round"
      },
      "varieties": [
        { "name": "red delicious" },
        { "name": "granny smith" }
      ]
    },
    {
      "name": "banana",
      "varieties": [
        { "name": "plantain" }
      ]
    }
  ]
}
'@,
		@'
[[fruits]]
name = "apple"

[fruits.physical]
color = "red"
shape = "round"

[[fruits.varieties]]
name = "red delicious"

[[fruits.varieties]]
name = "granny smith"

[[fruits]]
name = "banana"

[[fruits.varieties]]
name = "plantain"
'@
	),
	@(
		@('second'), @(@'
{ 
  "products": [
    {
      "name": "array of table",
      "sku": 7385594937,
      "emptyTableAreAllowed": true
    },
    {},
    {
      "name": "Nail",
      "sku": 284758393,
      "color": "gray"
    }
  ]
}
'@), @'
[[products]]
name = "array of table"
sku = 7385594937
emptyTableAreAllowed = True

[[products]]

[[products]]
name = "Nail"
sku = 284758393
color = "gray"
'@
	),
	@(
		@'
Third compliance test
'@,
		@'
{
  "fruit": [
    {
      "name": "apple",
      "geometry": { "shape": "round", "note": "I am a property in geometry table/map"},
      "color": [
        { "name": "red", "note": "I am an array item in apple fruit's table/map" },
        { "name": "green", "note": "I am in the same array as red" }
      ]
    },
    {
      "name": "banana",
      "color": [
        { "name": "yellow", "note": "I am an array item in banana fruit's table/map" }
      ]
    }
  ]
}
'@, @'
[[fruit]]
  name = "apple"

  [fruit.geometry]
    shape = "round"
    note = "I am a property in geometry table/map"

  [[fruit.color]]
    name = "red"
    note = "I am an array item in apple fruit's table/map"

  [[fruit.color]]
    name = "green"
    note = "I am in the same array as red"

[[fruit]]
  name = "banana"

  [[fruit.color]]
    name = "yellow"
    note = "I am an array item in banana fruit's table/map"
'@
	),
	@(
		@'
Array Test with empty element
'@,
		@'
{
  "products": [
    { "name": "Hammer", "sku": 738594937 },
    { },
    { "name": "Nail", "sku": 284758393, "color": "gray" }
  ]
}
'@, @'
[[products]]
name = "Hammer"
sku = 738594937

[[products]]

[[products]]
name = "Nail"
sku = 284758393
color = "gray"
'@
	)
) | foreach {$Test = "The Test '$($_[0])' ";
   $MyAttempt="$($_[1]|Convertfrom-json|ConvertTo-TOML)" -replace '\s', ''
   $WhatItShouldBe=$_[2]  -replace '\s', '';
   if ($MyAttempt -eq $WhatItShouldBe){
    Write-host "$test looks good"} else {write-warning "$Test `n$MyAttempt `n didn''t look like `n$WhatItShouldBe"}
   }

}