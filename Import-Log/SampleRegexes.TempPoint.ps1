$SQLDoc = [regex]'(?m:^)(?<Date>\d\d\:\d\d:\d\d\.\d\d\d)\|(?<Level>.*?)\|(?<Location>.*?)\|(?<Source>.*?)\|(?<Details>(?s:.*?))(?=\d\d\:\d\d:\d\d\.\d\d\d|$)'
$Prompt = [regex]'(?m:^)(?<Date>\d\d \w\w\w \d\d\d\d \d\d\:\d\d\:\d\d\,\d\d\d) \[(?<Number>\d+?)] (?<Level>.{1,20}) (?<Source>.{1,100}?) - (?<details>(?s:.*?))(?=\d\d \w\w\w \d\d\d\d|$)'
$Installation = [regex]'(?m:^)(?<Date>\d\d\d\d\-\d\d-\d\d \d\d\:\d\d:\d\d\.\d\d\d \+\d\d\:\d\d) \[(?<Level>.{1,20})\] (?<details>(?s:.*?))(?=\d\d\d\d\-\d\d-\d\d \d\d\:\d\d:\d\d\.\d\d\d|$)'
$SQLMonitor = [regex]'(?m:^)(?<Date>\d\d\d\d\-\d\d-\d\d \d\d\:\d\d:\d\d\,\d\d\d?) \[ {0,20}(?<Number>\d{1,10})\] (?<Level>\w{1,20}) (?<Source>.*?) - (?<details>(?s:.*?))(?=\d\d\d\d\-\d\d-\d\d \d\d\:\d\d:\d\d|$)'
$SQLDataCatalog = [regex]'(?m:^)(?<Date>\d\d\d\d\-\d\d-\d\d \d\d\:\d\d:\d\d\.\d\d\d \+\d\d:\d\d?) \[(?<Level>\w{1,20})\](?<details>(?s:.*?))(?=\d\d\d\d|$)'

