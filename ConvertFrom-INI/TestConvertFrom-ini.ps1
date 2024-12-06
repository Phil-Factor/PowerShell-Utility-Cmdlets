cls
$VerbosePreference = 'Silentlycontinue'

@( #Beginning if tests	
<# sample test
 @{'Name'='value'; 'Type'='equivalence/Equlity/ShouldBe/test etc'; 'Ref'=@'
'@; 'Diff'=@' 
'@}
#>
	
	
	@{
		'Name' = 'Dotted Section'; 'Type' = 'equivalence';
		'Ref' = @'
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
	},
	# test of an array with a trailing comma
	@{
		'Name' = 'array of values with trailing comma'; 'Type' = 'ShouldBe';
		# The ini code
		'Ref' = @'
array1 = ["value1", "value2", "value3,"] 
'@;
		# The PSON 
		'Shouldbe' = @{ 'array1' = @('value1', 'value2', 'value3') }
	},
	# test of a map
	@{
		'Name' = 'map of values'; 'Type' = 'ShouldBe';
		# The ini code
		'Ref' = @'
array1 = ["value1", "value2", "value3,"] 
'@;
		# The PSON 
		'Shouldbe' = @{ 'array1' = @('value1', 'value2', 'value3') }
	},
	# The quick brown fox equivalence test
	@{
		'Name' = 'folding of strings'; 'Type' = 'test';
		'Ref' = @'
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

'@;
		'test' = {
			param ($test)
			$test.truisms.str1 -eq $test.truisms.str1 -and $test.truisms.str1 -eq $test.truisms.str3
		}
	}
	# End of tests
) | foreach{
	$FirstString = $_.Ref; $SecondString = $_.Diff; $ShouldBe = $_.Shouldbe; $Test = $_.test;
	if ($_.Type -notin ('equality', 'equivalence', 'shouldbe', 'test'))
	{ Write-error "the $($_.Name) $($_.Type) Test was of the wrong type" }
	if ($FirstString -eq $null)
	{ Write-error "no reference object in the $($_.Name) $($_.Type) Test" }
	$ItWentWell = switch ($_.Type)
	{
		'Equivalence' {
			# Are they exactly equivalent (not necessarily correct) ?
			(($FirstString | convertfrom-ini | convertTo-json -depth 5) -eq
				($SecondString | convertfrom-ini | convertTo-json -depth 5))
		}
		'Equality' {
			# Are is it the same as the supplied Javascript ? (where you have a checked result))
			# caution as hashtables aren't ordered.
			(($FirstString | convertfrom-ini | convertTo-json -depth 5) -eq $SecondString)
		}
		'Test' {
			# does it pass the test supplied as a scriptbox by returning 'true' rather than 'false'
			$Test.Invoke(($FirstString | convertfrom-ini))
		}
		'ShouldBe' { # compare with a powershell object directly 
            $TheTOML = $FirstString | Convertfrom-ini 
            !(Compare-Object -ReferenceObject $TheTOML -DifferenceObject $ShouldBe)
		}
		default { $false }
	}
	write-output "The $($_.Name) '$($_.Type)' test went $(if ($ItWentWell) { 'well' }
		else { 'badly' })"
}

@(#  Tests
	@('embedded parameter Test',
		'table = [{ a = 42, b = test }, {c = 4.2} ]',
		'{"table":[{"a":42,"b":"test"},{"c":4.2}]}'
	),
	@('Array with embedded tables',
		'MyArray = [ { x = 1, y = 2, z = 3 }, { x = 7, y = 8, z = 9 }, { x = 2, y = 4, z = 8 } ]
    ',
		'{"MyArray":[{"y":2,"z":3,"x":1},{"y":8,"z":9,"x":7},{"y":4,"z":8,"x":2}]}'
	),
	@('embedded table Test',
		'table = [ { a = 42, b = "test" }, {c = 4.2} ]',
		'{"table":[{"a":42,"b":"test"},{"c":4.2}]}'
	),
	@('array of arrays',
		' MyArray = [ { x = 1, y = 2, z = 3 },
    { x = 7, y = 8, z = 9 },
    { x = 2, y = 4, z = 8 } ]
', '{"MyArray":[{"y":2,"z":3,"x":1},{"y":8,"z":9,"x":7},{"y":4,"z":8,"x":2}]}'
	),
	@('inline_table',
		'MyInlineTable={ key1 = "value1", key2 = 123, key3 = "true"}',
		'{"MyInlineTable":{"key3":"true","key1":"value1","key2":123}}'
	),
	@('Flyway config file', @'
flyway.driver=com.mysql.jdbc.Driver
flyway.url=jdbc:mysql://localhost:3306/customer_test?autoreconnect=true
flyway.user=sysdba
flyway.password=pa$$w3!rd
flyway.schemas=customer_test
flyway.locations=filesystem:src/main/resources/sql/migrations
flyway.placeholders.email_type.primary=Primario
flyway.placeholders.email_type.work=Traba
flyway.placeholders.phone_type.home=Casa
'@,
		'{"flyway":{"url":"jdbc:mysql://localhost:3306/customer_test?autoreconnect=true","placeholders":{"email_type":{"work":"Traba","primary":"Primario"},"phone_type":{"home":"Casa"}},"password":"pa$$w3!rd","driver":"com.mysql.jdbc.Driver","locations":"filesystem:src/main/resources/sql/migrations","schemas":"customer_test","user":"sysdba"}}'
	), #long strings that wrap
	@('long strings that wrap', @'
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
'@, @'
{"flyway":{"url":"jdbc:mydb://mydatabaseurl","schemas":["schema1","schema2"],"key":"value","placeholders":{"keyABC":"valueXYZ"},"locations":["filesystem:my/really/long/path/folder1","filesystem:my/really/long/path/folder2","filesystem:my/really/long/path/folder3"]}}
'@
	), #Flyway config with array
	@('Flyway config with array', @'
[environments.sample]
url = "jdbc:h2:mem:db"
user = "sample user"
password = "sample password"
dryRunOutput = "/my/output/file.sql"
[flyway]
# It is recommended to configure environment as a commandline argument. This allows using different environments depending on the caller.
environment = "sample" 
locations = ["filesystem:path/to/sql/files","Another place"]
[environments.build]
 url = "jdbc:sqlite::memory:"
 user = "buildUser"
 password = "buildPassword"
[flyway.check]
buildEnvironment = "build"
'@, @'
{"environments":{"sample":{"dryRunOutput":"/my/output/file.sql","url":"jdbc:h2:mem:db","user":"sample user","password":"sample password"},"build":{"url":"jdbc:sqlite::memory:","user":"buildUser","password":"buildPassword"}},"flyway":{"environment":"sample","check":{"buildEnvironment":"build"},"locations":["filesystem:path/to/sql/files","Another place"]}}
'@
	), #are escaped quotes ignored?
	@('are escaped quotes ignored?', @'
str = "I'm a string. \"You can quote me\". Name\tJos\u00E9\nLocation\tSF."
# This is a full-line comment
key = "value"  # This is a comment at the end of a line
another = "# This is not a comment"
'@, @'
{"another":"# This is not a comment","key":"value","str":"I\u0027m a string. \"You can quote me\". Name\tJosé\nLocation\tSF."}
'@
	), #check for unicode and quoted values
	@('check for unicode and quoted values', @'
"127.0.0.1" = "value"
"character encoding" = "value"
"ʎǝʞ" = "value"
'key2' = "value"
'quoted "value"' = "value"
'@, @'
{"ʎǝʞ":"value","key2":"value","character encoding":"value","quoted \"value\"":"value","127.0.0.1":"value"}
'@
	), #Check for escapes in quoted values
	@('Check for escapes in quoted values', @'
name = "Orange"
physical.color = "orange"
physical.shape = "round"
site."google.com" = true
'@, @'
{"site":{"google.com":"true"},"physical":{"shape":"round","color":"orange"},"name":"Orange"}
'@
	), #dotted hashtable
	@('Title', @'
name = "Orange"
physical.color = "orange"
physical.shape = "round"
site."google.com" = true
'@, @'
{"site":{"google.com":"true"},"physical":{"shape":"round","color":"orange"},"name":"Orange"}
'@
	), #white space between the dots
	@('white space between the dots', @'
fruit.name = "banana"     # this is best practice
fruit. color = "yellow"    # same as fruit.color
fruit . flavor = "banana"   # same as fruit.flavor
'@, @'
{"fruit":{"color":"yellow","name":"banana","flavor":"banana"}}
'@
	), # Array as an assignment to a key
	@('Array as an assignment to a key', @'
MyArray = ["Yan",'Tan','Tethera']
'@, @'
{"MyArray":["Yan","Tan","Tethera"]}
'@
	), #Embedded hashtable as assignment
	@('Embedded hashtable as assignment', @'
[dog."tater.man"]
type.name = "pug"
'@, @'
{"dog":{"tater.man":{"type":{"name":"pug"}}}}
'@
	), #ini-style table
	@('ini-style table', @'
# Top-level table begins.
name = Fido
breed = "pug"

# Top-level table ends.
[owner]
name = 'Regina Dogman'
member_since = 1999-08-04
'@, @'
{"name":"Fido","breed":"pug","owner":{"name":"Regina Dogman","member_since":"\/Date(933721200000)\/"}}
'@),	@('Ensuring that types are parsed correctly',@'
#String
name=phil Factor
Name1="Phil Factor"
Name2='Phil Factor'

# integers
int1 = +99
int2 = 42
int3 = 0
int4 = -17

# hexadecimal with prefix `0x`
hex1 = 0xDEADBEEF
hex2 = 0xdeadbeef
hex3 = 0xdead_beef

# octal with prefix `0o`
oct1 = 0o01234567
oct2 = 0o755

# binary with prefix `0b`
bin1 = 0b11010110

# fractional
float1 = +1.0
float2 = 3.1415
float3 = -0.01

# exponent
float4 = 5e+22
float5 = 1e06
float6 = -2E-2

# both
float7 = 6.626e-34

# separators
float8 = 224_617.445_991_228

# infinity
infinite1 = inf # positive infinity
infinite2 = +inf # positive infinity
infinite3 = -inf # negative infinity

# not a number
not1 = nan
not2 = +nan
not3 = -nan 
'@, @'
{"float5":1000000,"float8":224617.445991228,"oct1":342391,"hex2":3735928559,"float2":3.1415,"infinite1":Infinity,"hex3":3735928559,"float1":1,"int1":99,"not2":NaN,"float4":5E+22,"not1":NaN,"oct2":493,"infinite3":-Infinity,"int2":42,"not3":NaN,"infinite2":Infinity,"int3":0,"Name1":"Phil Factor","hex1":3735928559,"int4":-17,"float7":6.626E-34,"Name2":"Phil Factor","float6":-0.02,"name":"phil Factor","float3":-0.01,"bin1":214}
'@
	),	@('Check the standard string and string escapes', @'

str1 = "I'm a string."
str2 = "You can \"quote\" me."
str3 = "Name\tJos\u00E9\nLoc\tSF."
str4 = """
Roses are red
Violets are blue"""

str5 = """\
  The quick brown \
  fox jumps over \
  the lazy dog.\
  """
path = 'C:\Users\nodejs\templates'
path2 = '\\User\admin$\system32'
quoted = 'Tom "Dubs" Preston-Werner'
regex = '<\i\c*\s*>'
re = '''I [dw]on't need \d{2} apples'''
lines = '''
The first newline is
trimmed in raw strings.
All other whitespace
is preserved.
'''
'@, @'
{"re":"I [dw]on\u0027t need \\d{2} apples","path":"C:\\Users\nodejs\templates","str5":"The quick brown fox jumps over the lazy dog.","str4":"Roses are red\r\nViolets are blue","quoted":"Tom \"Dubs\" Preston-Werner","str3":"Name\tJosé\nLoc\tSF.","path2":"\\User\\admin$\\system32","regex":"\u003c\\i\\c*\\s*\u003e","str2":"You can \"quote\" me.","lines":"The first newline is\r\ntrimmed in raw strings.\r\nAll other whitespace\r\nis preserved.\r\n","str1":"I\u0027m a string."}
'@),@('Testing dates', @'
# offset datetime
odt1 = 1979-05-27T07:32:00Z
odt2 = 1979-05-27T00:32:00-07:00
odt3 = 1979-05-27T00:32:00.999999-07:00

# local datetime
ldt1 = 1979-05-27T07:32:00
ldt2 = 1979-05-27T00:32:00.999999

# local date
ld1 = 1979-05-27

# local time
lt1 = 07:32:00
lt2 = 00:32:00.999999
'@, @'
{"ld1":"\/Date(296607600000)\/","odt3":"\/Date(296638320999)\/","lt2":{"Ticks":19209999990,"Days":0,"Hours":0,"Milliseconds":999,"Minutes":32,"Seconds":0,"TotalDays":0.022233796284722222,"TotalHours":0.53361111083333335,"TotalMilliseconds":1920999.999,"TotalMinutes":32.01666665,"TotalSeconds":1920.999999},"ldt2":null,"odt2":"\/Date(296638320000)\/","odt1":"\/Date(296638320000)\/","lt1":{"Ticks":271200000000,"Days":0,"Hours":7,"Milliseconds":0,"Minutes":32,"Seconds":0,"TotalDays":0.31388888888888888,"TotalHours":7.5333333333333332,"TotalMilliseconds":27120000,"TotalMinutes":452,"TotalSeconds":27120},"ldt1":null}
'@
	) #Dealing with comments
,	@('Dealing with comments', @'
# This is a full-line comment
key = "value"  # This is a comment at the end of a line
another = "# This is not a comment"
'@, @'
{"key":"value","another":"# This is not a comment"}
'@
	)	  # Check for correct interpretation of inline table
,	@('Check for correct interpretation of inline table', @'
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
'@, @'
{"environments":{"full":{"url":"jdbc:h2:mem:flyway_db","initSql":"ALTER SESSION SET NLS_LANGUAGE=\u0027ENGLISH\u0027;","jdbcProperties":{"accessToken":"access-token"},"password":"mysecretpassword","driver":"org.h2.Driver","connectRetriesInterval":60,"connectRetries":10,"resolvers":["my.resolver.MigrationResolver1","my.resolver.MigrationResolver2"],"schemas":["schema1","schema2"],"user":"myuser"}}}
'@
	) 

 
<#	  #My Test
,	@('Title', @'
INI
'@, @'
JSON
'@
	) 

#>
) | foreach {
	Write-Verbose "Running the '$($_[0])' test"
    $result = ConvertFrom-ini($_[1]) | convertTo-JSON -Compress -depth 10
	    if ($result -ne $_[2])
	    {
		    Write-Warning "Oops! $($_[0]): $($_[1]) produced `n$result ...not... `n$($_[2])"
	    }
	    else { Write-host "$($_[0]) test successful" }
    }

$TheErrorFile="$($env:TEMP)\warning.txt"
"no error">$TheErrorFile
$null=ConvertFrom-INI @'
name = "Tom"
name = "Pradyun"
'@ 3>$TheErrorFile
if ((Type $TheErrorFile) -ne "Attempt to redefine Key name with 'Pradyun'")
    {Write-Warning "Should have given warning`"Attempt to redefine Key name with 'Pradyun'`""}
else {write-host " test to prevent redefining  Key name succeeded"}

$null=ConvertFrom-INI @'
spelling = "favorite"
"spelling" = "favourite"
'@ 3>$TheErrorFile
if ((Type $TheErrorFile) -ne "Attempt to redefine Key `"spelling`" with 'favourite'")
    {Write-Warning "Should have given warning`"Attempt to redefine Key `"spelling`" with 'favourite'`""}
else {write-host " test to prevent attempt to redefine Key succeeded"}

# THE FOLLOWING IS INVALID
$null=ConvertFrom-INI @'
# This defines the value of fruit.apple to be an integer.
fruit.apple = 1

# But then this treats fruit.apple like it's a table.
# You can't turn an integer into a table.
fruit.apple.smooth = true
'@3>$TheErrorFile
if ((Type $TheErrorFile) -ne "Key apple redefined with true")
    {Write-Warning "Should have given the warning`"Key apple redefined with true`""}
else {write-host "Test to prevent attempt to implcitly redefine a simple value as an object succeeded"}

$null=ConvertFrom-INI 'first = "Tom" last = "Preston-Werner" # INVALID'3>$TheErrorFile
if ((Type $TheErrorFile) -ne @"
first = "Tom" last = "Preston-Werner" contains a syntax error!
"@)  {Write-Warning @"
Should have given the warning`"first = "Tom" last = "Preston-Werner" contains a syntax error!`"
"@}
else {write-host "Test to ensure that there is a newline after a key value pair succeeded"}

<#




@'
[environments.sample]
url = "jdbc:h2:mem:db"
user = "sample user"
password = "sample password"
dryRunOutput = "/my/output/file.sql"
[flyway]
# It is recommended to configure environment as a commandline argument. This allows using different environments depending on the caller.
environment = "sample" 
locations = ["filesystem:path/to/sql/files","Another place"]
[environments.build]
 url = "jdbc:sqlite::memory:"
 user = "buildUser"
 password = "buildPassword"
[flyway.check]
buildEnvironment = "build"
'@|ConvertFrom-INI|convertto-json

$VerbosePreference = 'continue'
@'
= "no key name"  # INVALID
"" = "blank"     # VALID but discouraged
'' = 'blank'     # VALID but discouraged
'@|ConvertFrom-INI|convertto-json

Display-Object  (@'
{
  "environments": {
    "full": {
      "connectRetries": 10,
      "connectRetriesInterval": 60,
      "driver": "org.h2.Driver",
      "initSql": "ALTER SESSION SET NLS_LANGUAGE='ENGLISH';",
      "password": "mysecretpassword",
      "resolvers": [
        "my.resolver.MigrationResolver1",
        "my.resolver.MigrationResolver2"
      ],
      "schemas": [
        "schema1",
        "schema2"
      ],
      "url": "jdbc:h2:mem:flyway_db",
      "user": "myuser",
      "jdbcProperties": {
        "accessToken": "access-token"
      }
    },
    "prod": {
      "locations": [
        "filesystem:sql/migrations_prod"
      ],
      "password": "prodpassword",
      "url": "jdbc:postgresql://localhost:5432/proddb",
      "user": "produser"
    },
    "test": {
      "locations": [
        "filesystem:sql/migrations_test"
      ],
      "password": "testpassword",
      "url": "jdbc:postgresql://localhost:5432/testdb",
      "user": "testuser"
    }
  },
  "flyway": {
    "baselineDescription": "Initial baseline",
    "baselineOnMigrate": true,
    "baselineVersion": "1.0",
    "callbacks": [
      "com.example.MyCallback"
    ],
    "environment": "prod",
    "locations": [
      "filesystem:sql/migrations"
    ],
    "outOfOrder": true,
    "codeAnalysis": {
      "enabled": true,
      "rule1": {
        "description": "Ensure all SELECT statements follow the company SQL guidelines.",
        "regex": "(?i)^select\\s+.*\\s+from\\s+.*"
      },
      "rule2": {
        "description": "Check all INSERT INTO statements for correct value assignment.",
        "regex": "^insert\\s+into\\s+.*\\s+values\\s+.*"
      },
      "rule3": {
        "description": "Verify UPDATE statements conform to standard practices.",
        "regex": "^update\\s+.*\\s+set\\s+.*"
      }
    },
    "dev": {
      "locations": [
        "filesystem:sql/migrations_dev"
      ],
      "password": "devpassword",
      "url": "jdbc:h2:mem:flyway_db",
      "user": "devuser"
    },
    "placeholders": {
      "Branch": "myBranch",
      "Project": "myProject",
      "Variant": "myVariant"
    }
  }
}
'@ |convertfrom-json)




 Display-object (Convertfrom-ini @'
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
'@ ) 
#>
