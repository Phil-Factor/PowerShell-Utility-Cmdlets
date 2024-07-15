<#
	.SYNOPSIS
		Generates a dependency manifest, giving tables in the order in which they should be deleted or  
        inserted and will give an error if there is a cyclic or mutual dependency
	
	.DESCRIPTION
		This provides the dependency list of tables that gives you a way of insewrting or deleting the
        data in all the tables. It is also a way of checking for cyclic or mutual dependencies 
	
	.PARAMETER SourceDSN
		The name of the DSN. By using a DSN, you can use the GUI to alter the settings and test it 
        out before use.
	
	.PARAMETER Database
		The name of the database 
	
	.PARAMETER Schemas
		 or a list of schemas as in Flyway
	
	.PARAMETER User
		the user for the connection
	
	.PARAMETER Password
		The password for the connection
	
	.PARAMETER Secretsfile
		if you use a 'secrets' config file
	
	.PARAMETER TablesToInclude
		single wildcard string schema and table

    .EXAMPLE

    Generate_DependencyOrderIfPossible  PubsDSN 'PubsWithACircularRelationship' '*' 'sa' 'ismellofpoo4U'
	
#>
function Generate_DependencyOrderIfPossible
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true,
				   HelpMessage = 'The DSN of the database you are accessing')]
		[String]$SourceDSN,
		[Parameter(Mandatory = $true)]
		[String]$Database,
		[Parameter(Mandatory = $true)]
		[String]$Schemas = '*',
		# or a list of schemas as in Flyway

		[String]$User = $null,
		#the user for the connection

		[String]$Password = $null,
		#The password for the connection

		[string]$Secretsfile = $null,
		#if you use a secrets file.

		[string]$TablesToInclude = '*' #single wildcard string schema and table
	)
	
	$SourceDSN = 'PubsDSN'
	$Database = 'PubsWithACircularRelationship'
	$Schemas = '*'; # or a list of schemas as in Flyway
	$User = 'sa'; #the user for the connection
	$Password = 'ismellofpoo4U'; #The password for the connection
	$Secretsfile = $null; #if you use a secrets file.
	$TablesToInclude = '*'; #single wildcard string schema and table
	
	
	
	
	# Firstly, determine the connection
	$DSN = Get-OdbcDsn $SourceDSN -ErrorAction SilentlyContinue
	if ($DSN -eq $Null) { Throw "Sorry but we need a valid DSN installed, not '$SourceDSN'" }
	
	# find out the server and database
	$DefaultDatabase = $DSN.Attribute.Database
	$DefaultServer = $DSN.Attribute.Server
	if ($DefaultServer -eq $Null) { $DefaultServer = $DSN.Attribute.Servername }
<# Now what RDBMS is being requested? Examine the driver name (Might need alteration)
   if the driver name is different or if you use a different RDBMS #>
	$RDBMS = 'SQLserver', 'SQL Server', 'MySQL', 'MariaDB', 'PostgreSQL' | foreach{
		$Drivername = $DSN.DriverName;
		if ($Drivername -like "*$_*") { $_ }
	}
	if ($RDBMS -eq $Null) { Throw "Sorry, but we don't support $($DSN.Name) yet" }
<# we need to get the relationship data from the information schema because it isn't
provided by default by ODBC for some reason. We use it to work out the correct sequence
for import and check for circular dependencies  #>
	#if we have our secrets in a flyway config file 
	if (!([string]::IsNullOrEmpty($SecretsFile)))
	{
		$OurSecrets = get-content "$env:USERPROFILE\$SecretsFile" | where {
			($_ -notlike '#*') -and ("$($_)".Trim() -notlike '')
		} |
		foreach{ $_ -replace '\\', '\\' -replace '\Aflyway\.', '' } |
		ConvertFrom-StringData
	}
	else
	{
		$OurSecrets = @{ 'Password' = $Password; 'User' = $User }
	}
	#start by creating the ODBC Connection
	$conn = New-Object System.Data.Odbc.OdbcConnection;
	#now we create the connection string, using our DSN, the credentials and anything else we need
	#we access the sourceDSN to get the metadata.
	#We check to see if the database name has been over-ridden
	$TheDatabase = if ($Database -ne $null)
	{
		"database=$Database;"
	}
	else { '' }; #take the database from the DSN
	Write-verbose "connection via $SourceDSN to  server=$DefaultServer  $TheDatabase"
	$conn.ConnectionString = "DSN=$SourceDSN; $TheDatabase pwd=$($OurSecrets.Password); UID=$($OurSecrets.User)";
	#Crunch time. 
	$conn.open(); #open the connection 
	if ($Schemas -eq '*')
	{
		$WhereClause = "where table_schema not in ('pg_catalog','information_schema', 'performance_schema','mysql')"
	}
	else
	{
		$WhereClause = "where table_schema in ('$(($Schemas -split ',') -join "','")')"
	}
	# we check that the DSN supports what we need to do 
	if ($RDBMS -in ('PostgreSQL', 'SQL Server', 'SQLServer'))
	{
		$DependencyCommand = New-object System.Data.Odbc.OdbcCommand(@"
Select concat(table_schema, '.', table_name) as The_Table, f.Referenced_by  
from information_schema.tables Mytables
left outer join
(Select Concat(tc.table_schema, '.', tc.Table_name) as Reference , Concat(t.table_schema, '.', t.Table_name) as Referenced_by  
from information_schema.referential_constraints rc
inner join 
information_schema.table_constraints tc
    on rc.unique_constraint_name = tc.constraint_name
    and rc.unique_constraint_schema = tc.table_schema
inner join 
information_schema.table_constraints t
    on rc.constraint_name = t.constraint_name
    and rc.constraint_schema = t.table_schema)f
on f.reference=(concat(Mytables.table_schema, '.', Mytables.table_name))
$WhereClause  AND TABLE_TYPE = 'BASE TABLE';
"@, $conn);
	}
	elseif ($RDBMS -in ('MySQL', 'MariaDB'))
	{
		$DependencyCommand = New-object System.Data.Odbc.OdbcCommand(@"
    Select concat(Mytables.table_schema, '.', Mytables.table_name) as The_Table, 
	       concat(rc.UNIQUE_CONSTRAINT_SCHEMA, '.', rc.REFERENCED_TABLE_NAME) as  Referenced_by
    from information_schema.tables Mytables
    left outer join 
    information_schema.referential_constraints rc
    on concat(Mytables.table_schema, '.', Mytables.table_name)=concat(rc.CONSTRAINT_SCHEMA, '.', rc.TABLE_NAME)
    $WhereClause AND TABLE_TYPE = 'BASE TABLE';
"@, $conn);
	}
	elseif ($RDBMS -ieq ('oracle'))
	{
		$DependencyCommand = New-object System.Data.Odbc.OdbcCommand(@"
    SELECT 
    concat(uc.owner, '.', uc.table_name) AS The_Table, 
    concat(c.owner, '.', c.table_name) AS Referenced_by
    FROM 
        all_tables t
    LEFT OUTER JOIN
    (
        SELECT 
            a.owner,
            a.table_name,
            b.owner AS ref_owner,
            b.table_name AS ref_table_name,
            a.constraint_name
        FROM 
            all_constraints a
        JOIN 
            all_constraints b ON a.r_constraint_name = b.constraint_name 
            AND a.r_owner = b.owner
        WHERE 
            a.constraint_type = 'R'
    ) c ON t.owner = c.owner AND t.table_name = c.table_name
    LEFT OUTER JOIN
    (
        SELECT 
            a.owner,
            a.table_name,
            b.owner AS ref_owner,
            b.table_name AS ref_table_name,
            a.constraint_name
        FROM 
            all_constraints a
        JOIN 
            all_constraints b ON a.r_constraint_name = b.constraint_name 
            AND a.r_owner = b.owner
        WHERE 
            a.constraint_type = 'R'
    ) uc ON t.owner = uc.ref_owner AND t.table_name = uc.ref_table_name
    WHERE 
        t.owner NOT IN ('SYS', 'SYSTEM') 
        AND t.iot_type IS NULL
    ORDER BY 
        t.owner, t.table_name;

"@, $conn);
	};
<# now get the relationship data #>
	$DependencyData = New-Object system.Data.DataSet;
	(New-Object system.Data.odbc.odbcDataAdapter($DependencyCommand)).fill($DependencyData) | out-null;
	$TheListOfDependencies = $DependencyData.Tables[0] |
	   Select @{ n = "Table"; e = { $_.item(0) } }, @{ n = "Referrer"; e = { $_.item(1) } }
	$TheOrderOfDependency = @() # our manifest table
    <# Now create the manifest table #>
	$TheRemainingTables = $TheListOfDependencies | select Table -unique # Get the list of tables
	$TableCount = $TheRemainingTables.count # Get the number so we know when they are all listed
	$DependencyLevel = 1 #start at 1 - meaning they make no foreign references
	while ($TheOrderOfDependency.count -lt $TableCount -and $DependencyLevel -lt 30)
	{
		$TheRemainingTables = $TheRemainingTables |
		   where { $_.Table -notin $TheOrderOfDependency.Table }
		#select tables that are not making references to surviving objects 
		$TheRemainingForeignReferences = $TheListOfDependencies |
		    where { $_.Table -notin $TheOrderOfDependency.Table } |
		    Select -ExpandProperty Referrer -unique | where { !([string]::IsNullOrEmpty($_)) }
		$TheOrderOfDependency += $TheRemainingTables | where { $_.Table -notin $TheRemainingForeignReferences } |
		    Select Table, @{ n = "Sequence"; e = { $DependencyLevel } }
		$DependencyLevel++
	}
	if ($DependencyLevel -ge 30)
	{
		Write-Warning "Unable to create the Dependency List of tables for the manifest due to a circular dependency"
		$Referrers = @();
		$ii = 30; #this will only be called after a circular dependency is found
		$TableList = $TheListOfDependencies |
		   where { [string]::IsNullOrEmpty($_.Referrer) } | select -ExpandProperty Table
		#initialise the dependency walker
		$CurrentGeneration = $TheListOfDependencies | where { $_.Referrer -in $TableList }
		#now walk all the dependencies
		While ($ii -ge 0)
		{
			$Referrers += $CurrentGeneration | foreach {
				if ($_.referrer -notin $Referrers) { $_.referrer } }
			if ($CurrentGeneration.Count -le 0) { break }
			$Referrers | foreach{
				if ($_ -in $CurrentGeneration.Table)
				{
					$Ref = $_; $TheReferrer = $CurrentGeneration | where {
						$_.Table -eq $Ref
					} | foreach{ $_.Referrer }; write-Warning "circular reference involving $TheReferrer -> $($_)"
					break;
				}
			}
			$CurrentGeneration = $TheListOfDependencies | where { $_.Referrer -in $CurrentGeneration.Table }
			$ii-- #iterator to prevent an endless loop
		}
		
		
	}
	else
	{ $TheOrderOfDependency }
}





