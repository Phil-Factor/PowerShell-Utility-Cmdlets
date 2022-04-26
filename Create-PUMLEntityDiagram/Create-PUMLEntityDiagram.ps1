<#
	.SYNOPSIS
		Creates an ER diagram from a databasae model. You just name the table(s) that need to be included, the model and the verbiage on the diagram.
	
	.DESCRIPTION
		Mapping and documenting the Foreign key relationships between tables is one of those many rather tedious routine tasks that tend to be neglected when a team gets under pressure, which is a shame because it is so easy to spot mistakes in a diagram, whereas errors tend to get lost in lists or code. Far more time is wasted tracking down foreign key problems than are saved by abandoning diagramming. So why not automate the process?
		I usually create the  UML diagrams for designing databases and processes from PlantUML.  These are scripts, so they can easily be placed in source control, and a change can automatically update the graphic.  PlantUML will create Entity-relationship diagrams as well as classes, states, deployment, or Gantt charts.  I've already demonstrated how it can produce a Gantt chart from a Flyway History.  Although it will produce Entity Relationship diagrams, you generally wouldn't want a diagram for an entire database: no paper-size is big enough for a typical corporate database. You'd be more
	
	.PARAMETER SchemaToDo
		The schema to do. Can be a wildcard
	
	.PARAMETER FirstTableToDo
		The table to do. Can be a wildcard
	
	.PARAMETER Model
		The model of the database. Not the JSON, but as a Powershell object.
	
	.PARAMETER Title
		The title of the ER Diagram (usually database, table-cluster and version)
	
	.PARAMETER Footer
		The Footer.
	
	.PARAMETER Date
		The  Date for the diagram.
	
	.EXAMPLE
				Create-PUMLEntityDiagram 'dbo' 'sales' $model 
	            Create-PUMLEntityDiagram 'dbo' 'sales' $model 'Publications from PubsMySQL 1.1.7' 'phil Factor Enterprises'

#>

function Create-PUMLEntityDiagram
{
	[CmdletBinding()]
	[OutputType([string])]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$SchemaToDo,
		#this is a wildcard parameter 

		[Parameter(Mandatory = $true)]
		[string]$FirstTableToDo,
		# this is a wildcard parameter as well

		[Parameter(Mandatory = $true)]
		[object]$Model,
		[string]$Title = "ER Database Diagram",
		# the title of the diagram

		[string]$Footer = 'Produced by PlantUML',
		# the footer of the diagram

		[String]$Date = "$((Get-date).Date.ToString().Replace('00:00:00', ''))" #The Date
	)
	
	
<# We can first produce an object that lists all the tables that
 are referencing other tables, what these tables are, and the keys invvolved
 A key can have one or more key columns #>
	$Reference = $model | Display-object -depth 10 |
	where{ $_.path -like '$.*.*.*.foreign key.*.Foreign Table' } |
	foreach{
		$bits = $_.Path.split('.');
		[pscustomobject]@{
			'TableSchema' = "$($Bits[1])";
			'TableName' = "$($bits[3])";
			'Key' = "$($bits[5])";
			'ReferenceSchema' = "$($_.Value)".Split('.')[0];
			'ReferenceTable' = "$($_.Value)".Split('.')[1]
		}
	}
	
	$TablesToDo = @()
	#get a list of all the tables that the user wants
	$model.psobject.Properties.name | where { $_ -ilike $schemaToDo } | foreach {
		#for each schema
		$Schema = $_
		$TablesToDo += $model.$Schema.Table.psobject.Properties.Name |
		where { $_ -ilike $FirstTableToDo } |
		foreach  {
			[psCustomObject]@{ 'Schema' = $Schema; 'Table' = $_; }
		}
	}
	
	
	$WeGottaIterate = $true; #we will always need the first iteration
	$TheLastPassTotal = 0; #because we haven't done it yet
	while ($WeGottaIterate)
	{
		$TablesToDo | foreach{
			$ItsLinkedTo = @()
			$TableName = $_.Table; #just the tablename
			$Schema = $_.Schema; #just the Schema
			#determine both the tables that refer to it and the tables it reefers to
			$ItsLinkedTo += $Reference |
			where { ($_.TableName -eq $Tablename) -and ($_.TableSchema -eq $Schema) } |
			Foreach { [psCustomObject]@{ 'Schema' = $_.ReferenceSchema; 'Table' = $_.ReferenceTable; } };
			$ItsLinkedTo += $Reference |
			where { [psCustomObject]($_.ReferenceTable -eq $Tablename) -and ($_.ReferenceSchema -eq $Schema) } |
			Foreach { [psCustomObject]@{ 'Schema' = $_.TableSchema; 'Table' = $_.TableName; } }
		}
		$TablesToDo = $ItsLinkedTo | sort -Unique schema, table #process these links subsequently
		$TotalLinks = $TotalLinks + $ItsLinkedTo | sort -Unique schema, table
		#we find out which tables are in the group
		$WeGottaIterate = ($TotalLinks.count -gt $TheLastPassTotal)
		#Have we grown the group of inter-related tables? 
		$TheLastPassTotal = $TotalLinks.count
		#update the count in case we have
		#otherwise, our task is done
	}
	
	
<# we boil this down to a list of all the participating tables and for each 
of them we produce a simple PUML code that defines each entity. We can read 
any additional information we need from the table, in this case the comment#>
	
	$EntityCode = $TotalLinks | Foreach{
		$TableSchema = $_.Schema; #remember the table schema
		$TableName = $_.table; #and the table name
		#now we can get the value of the comment for that table. 
		#Lucky uo did comments eh?
		$comment = $model.$TableSchema.table.$TableName.comment
		#we reference the foreign keys. one after another to get a list of keys
		$keys = $model.$TableSchema.table.$TableName.'foreign key' |
		foreach{ $_.psobject.Properties.Value } | select -ExpandProperty Cols
		#We can now create the data within the table entity of the foreign
		#keys accesses. If you don't have table documentation, you might need
		#some columns too
		$TheListOfKeys = ($keys | foreach{ "* $($_) : number <<FK>>" }) -join "`r`n  "
    @"

entity "$TableSchema.$TableName"  {
  $comment
  --
  $TheListOfKeys
}
"@
	}
	
	$TotalTables = $TotalLinks | foreach { "$($_.Schema).$($_.Table)" }
	$EntityRelations = $reference |
	foreach {
		[pscustomobject] @{
			'References' = "$($_.TableSchema).$($_.TableName)";
			'referenced' = "$($_.ReferenceSchema).$($_.ReferenceTable)"
		}
	} |
	where {
		($_.References -in $TotalTables) -or
		($_.Referenced -in $TotalTables)
	} | foreach{@"
$($_.References) }|..|| $($_.referenced)
"@
	}
	
	$pumlCode = @"
@startuml
' hide the spot
hide circle

' avoid problems with angled crows feet

skinparam linetype ortho
skinparam wrapWidth 150
skinparam MessageAlign left
skinparam header{
  FontColor black
  FontSize 14
}

Title $title
header Date: $date
footer $footer

$($EntityCode -join "`r`n") 
$($EntityRelations -join "`r`n  ")

@enduml
"@
	
	$PumlCode
}
