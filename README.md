# PowerShell Utility Cmdlets

This is a repository for a collection of Cmdlets that I wrote only because I needed them and nobody else seemed to have written them. 

## ConvertFrom-XML

 [ConvertFrom-XML](/ConvertFrom-XML/ConvertFrom-XML.ps1)  does what you’d expect.  It works in a similar way to ConvertFrom-JSON. It is not entirely plain-sailing. There are certain problems with tackling a routine that has to successfully convert all the permutations of XML into arrays and hashtables. XML doesn’t handle arrays natively but implies them by assigning them the same keys, it allows empty elements, or elements that contain only other elements. There is no built-in concept of NULLs. It can have elements that contain only text, or that mix text and elements. Additionally, attributes don’t have any intrinsic order whereas elements do.

## Diff-Objects

 [Diff-Objects](/Diff-Objects/Diff-Objects.ps1)  does what you always imagined that Compare-object did. It shows you what has changed in an object. It lists the path to each value, and what is in the value in either object and whether it is different or the same.  It is dependent on Display-object so you need to load both. This is a change, because I was fed up with maintaining two scripts that did very similar things.

## Display-Object

[Display-Object](/Display-Object/Display-Object.ps1)  Is a way of displaying the values in an object. It lists the path to each value and the value itself.  To select just the values that have changed you need to filter out all the ones that are the same.  Recently, I altered this slightly so that it can show you the details of objects that are different, via a switch

## Import-Log

 [Import-Log](/Import-Log/Import-Log.ps1)  is a way of converting any log into a PowerShell object that allows you to sort and filter the log records. Want just the errors or warnings? This is the Cmdlet for you. I also provide [sample log regexes](/Import-Log/SampleRegexes.ps1) for some Redgate products. Sadly, you’re going to need to adapt one of the samples to create the regex for any particular log because, for some wierd reason, nobody has ever established a common standard.

## Get-ODBCMetadata

Gets the metadata of any ODBC connection (any database with a good driver. So far, only tested with SQL Server, Postgres, sqlite  and MariaDB. All were very different
This uses two techniques. Where the ODBC driver has a GetSchema function
in its connection object, it uses that. Where it can't, it uses the Information_schema. 
SQL Server, Azure SQL Database, MySQL, PostgreSQL, MariaDB, Amazon Redshift,
Snowflake and Informix	have information_schema, but all with variations so I need to test each one!

```
$connpsql = new-object system.data.odbc.odbcconnection
		$connpsql.connectionstring = "DSN=PostgreSQL;"
		Get-ODBCSourceMetadata -ODBCConnection $connpsql
```



## ConvertTo-YAML

This is an experiment, using the principles of Display-object, to convert any PowerShell object to a YAML document.

## Get-FilesFromRepo

Get a github repository and download it to a local directory/folder. This is a PowerShell cmdlet that allows you to download a  repository or just a directory from a repository. 
e.g.

```
`$Params = @{`
			'Owner' = 'Phil-Factor';
			'Repository' = 'PubsAndFlyway';
			'RepoPath' = 'PubsPostgreSQL';
			'DestinationPath' = "$env:Temp\PubsPostgreSQL";
		}
		Get-FilesFromRepo @Params
```



## Distribute-LatestVersionOfFile

Finds the latest version of a file and copies  it over all other existing copies within all the subdirectories of  the base directory you specify. This is a way of ensuring that the latest version of the file is updated everywhere within the directory structure 
For the BaseDirectory parameter, you should provide the base directory of the location where the alterations can take place. For the  Filename parameter, you need to provide  the name of the file that you want synchronized across the location
