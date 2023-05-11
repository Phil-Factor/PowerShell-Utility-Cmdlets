# PowerShell Utility Cmdlets

This is a repository for a collection of Cmdlets that I wrote only because I needed them and nobody else seemed to have written them.  I won’t claim that they are perfect but  people seem to appreciate them so I’ve put them public. 

## Compare-Resultsets

Used to test databases. This function is used to test whether the JSON results from a SQL expression are the same as a correct result. It checks two objects that are converted into PowerShell from JSON resultsets that are the results from SQL Expressions. Each element in the array has the same keys.

## ConvertFrom-RegEx

Use regex strings to  convert a string or a file from formatted tabular (each row with the same columns) text

## ConvertFrom-XML

 [ConvertFrom-XML](/ConvertFrom-XML/ConvertFrom-XML.ps1)  does what you’d expect.  It works in a similar way to ConvertFrom-JSON. It is not entirely plain-sailing. There are certain problems with tackling a routine that has to successfully convert all the permutations of XML into arrays and hashtables. XML doesn’t handle arrays natively but implies them by assigning them the same keys, it allows empty elements, or elements that contain only other elements. There is no built-in concept of NULLs. It can have elements that contain only text, or that mix text and elements. Additionally, attributes don’t have any intrinsic order whereas elements do.

## ConvertTo-lnsertStatements

A quick way to create multi-row SQL insert statements from an array of objects that all  have the same keys in the same order for every row.  You'd get this from reading in a JSON result. You can specify a list of one or more columns to exclude, and can provide a SQL at the start and end. 

## ConvertTo-PSON

This is a way of converting an object into a PowerShell script. PSON is short for PowerShell Object Notation. You give it an object as input and it returns the script as object notation. This is handy for exploring objects and it is strangely useful in debugging things. It has been curiously hard to write and I keep finding strange objects that it doesn’t do, and then  I have to fix the cmdlet.  It is a surprisingly good way of storing data in a file during dev work since you just execute the file as PowerShell to get the object. Just don’t use it publicly to read in data because it is a terrible security risk. 

## ConvertTo-View

Converts a tabular object to a read-only view for SQL Server, PostgreSQL, MySQL,  MriaDB and SQLite. It ia a quick way to create the code for a view from an array of objects that all have the same keys in the same order for every row.  You'd get this from reading in a JSON result. You can specify a list of one or more columns to exclude

## ConvertTo-YAML

This is an experiment, using the principles of Display-object, to convert any PowerShell object to a YAML document. I’m still fishing a few bugs out but the current version is usable as long as you don’t do anything outlandish. Oddly, it gets shorter the more I fix problems.

## Create-PUMLEntityDiagram

Creates an ER diagram from a database model. You just name the table(s) that need to be included, the model and the verbiage on the diagram.

## Diff-Objects

 [Diff-Objects](/Diff-Objects/Diff-Objects.ps1)  does what you always imagined that Compare-object did. It shows you what has changed in an object. It lists the path to each value, and what is in the value in either object and whether it is different or the same.  It is dependent on Display-object so you need to load both. This is a change, because I was fed up with maintaining two scripts that did very similar things.
## Display-Object

[Display-Object](/Display-Object/Display-Object.ps1)  Is a way of displaying the values in an object. It lists the path to each value and the value itself.  To select just the values that have changed you need to filter out all the ones that are the same.  Recently, I altered this slightly so that it can show you the details of objects that are different, via a switch

## Distribute-LatestVersionOfFile ##

[Distribute-LatestVersionOfFile.ps1](/Distribute-LatestVersionOfFile/Distribute-LatestVersionOfFile.ps1) Finds the latest version of a file and copies it over all other existing copies within all the subdirectories of  the list of base directories that you specify. This is a way of ensuring that the latest version of the file is updatd everywhere within the directory structure 
For the BaseDirectory parameter, you should provide one or more  base directories, each of which is a location where the alterations can take place. For the  Filename parameter, you need to provide  the name of the file that you want synchronized across the location

## ExtractCredential

see  **Get-WindowsCredential**

## Generate-NormallyDistributed

Generates a normally-distributed random number using  the Box-Muller transform

## GenerateRandomText

This function takes a PowerShell object that has several keys representing phrase-banks,each  of which has an array that describes all the alternative components of a string and from it,  it returns a string.    basically, you give it a list of alternatives in an array and it selects one of them.  However, if you put in the name of an array as one of the alternatives,rather than     a word,it will, if it selects it, treat it as a new reference and will select one of   these alternatives.

## Get-DPEConfigItems

Returns an encrypted config file as a Hashtable that can then be splatted to Flyway. This is used to allow you to decrypt flyway configuration items 'on the fly in a form that can be passed to Flyway via splatting

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

## Get-GithubModifiedFiles

Returns the list of  current files modified but uncommitted to a repository

## Get-TaggedGitHubRelease

Gets the files of a git release, either the latest one or, if you specify the tag, the release that has that tag. This is a, hopefully, reliable way of getting the latest release from Github, or a specific release. There are several examples on the internet but I couldn't get any to work. Git changes the protocol, but if you can get the correct path of the zip-ball of the files, you have a better chance.

## Get-WindowsCredential

Gets a windows credential from the credential manager, or creates a credential if it doesn't yet exist. There is also a version of this called **ExtractCredential** that isn’t a cmdlet but is executed as a file. socan be used in the command line 

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

## Import-Log


 [Import-Log](/Import-Log/Import-Log.ps1)  is a way of converting any log into a PowerShell object that allows you to sort and filter the log records. Want just the errors or warnings? This is the Cmdlet for you. I also provide [sample log regexes](/Import-Log/SampleRegexes.ps1) for some Redgate products. Sadly, you’re going to need to adapt one of the samples to create the regex for any particular log because, for some wierd reason, nobody has ever established a common standard.

## Read-DPEncryptedContent

This PowerShell routine will fetch the contents of a file containing an encrypted object stored in an XML Document. You can ceate this with **Write-DPEncryptedContent**. This is encrypted as a system.secure.string. It converts it back into plain text

## Tokenize-SQLString

Takes a SQL string and produces a stream of its component parts such as comments, strings numbers, identifiers and so on. This allows intelligent searched of SQL Files for things like comments

## Write-DocumentationToSQLDDLFile

Takes a JSON file with documentation details and inserts it into the files specified. This takes a whole bunch of files and updates them with the documentation that you request. This is intended for automatically-generated SQL Build scrips and also migration files 

## Write-DPEncryptedContent

This PowerShell routine will save the string in its encrypted form as a system.secure.string within an XML file. It can be read by **Read-DPEncryptedContent**
