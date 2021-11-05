
<#
	.SYNOPSIS
		Used to Compare two powershell objects
	
	.DESCRIPTION
		This compares two powershell objects by determining their shared 
     keys or array sizes and comparing the values of each. It uses the 
     Display-Object cmdlet for the heavy lifting
	
	
	.PARAMETER Ref
		The source object 
	
	.PARAMETER diff
		The target object 
	
	.PARAMETER Avoid
		a list of any object you wish to avoid comparing
	
	.PARAMETER Parent
		Only used for recursion
	
	.PARAMETER Depth
		The depth to which you wish to recurse
	
	.PARAMETER NullAndBlankSame
		Do we regard null and Blank the same for the purpose of comparisons.

	.PARAMETER $ReportNodes
		Do you wish to report on nodes containing objects as well as values?
	
	.NOTES
		Additional information about the function.

#>
function Diff-Objects
{
	param
	(
		[Parameter(Mandatory = $true,
				   Position = 1)]
		[object]$Ref,
		[Parameter(Mandatory = $true,
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
        [string]$NullAndBlankSame = $true,
		[Parameter(Mandatory = $false,
				   Position = 6)]
		[int]$ReportNodes = $true
	)
	
	$Left = display-object $Ref -Avoid $Avoid -Parent $Parent -Depth 10 -reportNodes $ReportNodes
	$right = display-object $Diff -depth 10 -reportNodes $ReportNodes
	$Paths = $Left + $Right | Select path -Unique
	$Paths | foreach{
		$ThePath = $_.Path;
		$Lvalue = $Left | where { $_.Path -eq $ThePath } | Foreach{ $_.Value };
		$Rvalue = $Right | where { $_.Path -eq $ThePath } | Foreach{ $_.Value };
		if ($RValue -eq $Lvalue)
		{ $equality = '==' }
        elseif ([string]::IsNullOrEmpty($Lvalue) -and 
               [string]::IsNullOrEmpty($rvalue) -and 
               $NullAndBlankSame)
               {$equality = '=='}
 
		else
		{
			$equality = "$(if ($lvalue -eq $null) { '-' }
				else { '<' })$(if ($Rvalue -eq $null) { '-' }
				else { '>' })"
		}
		[pscustomobject]@{ 'Ref' = $ThePath; 'Source' = $Lvalue; 'Target' = $Rvalue; 'Match' = $Equality }
		
	}
}

#A Test for a Display-Object Cmdlet that we are developing.
#We have the reference version of what the data should be in #ref
$Ref=@'
#TYPE System.Management.Automation.PSCustomObject
"Path","Value"
"$.Ham.Downtime",
"$.Ham.Location","Floor two rack"
"$.Ham.Users[0]","Fred"
"$.Ham.Users[1]","Jane"
"$.Ham.Users[2]","Mo"
"$.Ham.Users[3]","Phil"
"$.Ham.Users[4]","Tony"
"$.Ham.version","2019"
"$.Japeth.Location","basement rack"
"$.Japeth.Users[0]","Karen"
"$.Japeth.Users[1]","Wyonna"
"$.Japeth.Users[2]","Henry"
"$.Japeth.version","2008"
"$.Shem.Location","Server room"
"$.Shem.Users[0]","Fred"
"$.Shem.Users[1]","Jane"
"$.Shem.Users[2]","Mo"
"$.Shem.version","2017"
'@ |ConvertFrom-Csv
# We now have the reference result. we now create the test input 
$ServersAndUsers =
@{'Shem' =
  @{
    'version' = '2017'; 'Location' = 'Server room';
        'Users'=@('Fred','Jane','Mo')
     }; 
  'Ham' =
  @{
    'version' = '2019'; 'Location' = 'Floor two rack';
        'Downtime'=$null
        'Users'=@('Fred','Jane','Mo','Phil','Tony')
  }; 
  'Japeth' =
  @{
    'version' = '2008'; 'Location' = 'basement rack';
        'Users'=@('Karen','Wyonna','Henry')
  }
}
#we run the 'Display-Object' that we are developing.
$Diff= Display-Object $ServersAndUsers
# we now have a #Ref object with what the output should be, and we have the $diff object
# of what is produced by the current version 
# We test to see if the $Ref and $Diff match.
$TestResult=Diff-Objects - -Ref $ref -Diff $diff -NullAndBlankSame $True |
    where {$_.Match -ne '=='}
if ($TestResult) #if any differences were reported.
    {Write-warning 'Test for Display-Object with  ServersAndUsers failed'
    $TestResult|format-table}

