<# Now to do a few obvious unit tests. Surprisingly, I've failed all these in the past #>

@(# first test
    [pscustomobject]@{'test'=@(@{ 'This' = 'that' }, @{ 'Error' = 4 }, 'another'); 'result'=@'
---
- This: that
- Error: 4
- another
'@;}, # second test
    [pscustomobject]@{'test'= @(@{ 'This' = 'that' }, 'another'); 'result'=@'
---
- This: that
- another
'@;},# third test
    [pscustomobject]@{'test'=  @{ 'This' = 'that' }; 'result'=@'
---
This: that
'@;},# fourth test
    [pscustomobject]@{'test'= ([pscustomobject](@{ 'This' = 'that' }, 'another')); 'result'=@'
---
- This: that
- another
'@;},# fifth test
    [pscustomobject]@{'test'=  @(@{ 'This' = 'that' }, 'another', 'yet another'); 'result'=@'
---
- This: that
- another
- yet another
'@;},# sixth test
    [pscustomobject]@{'test'=  @(@{ 'This' = 'that' }, 'another',4,65,789.89, 'yet another'); 'result'=@' 
---
- This: that
- another
- 4
- 65
- 789.89
- yet another

'@;})| foreach{
$Yaml=''; $yaml=(ConvertTo-YAML $_.test) -join "`r`n"; $result=$_.result; if (!($Yaml.Trim() -eq $result.Trim())) 
{write-warning "YAML Result `r`n ($Yaml) should have been `r`n($Result)"}}

<# in this test, it turned out there was a PoSh bug, now fixed
 first test
    [pscustomobject]@{'test'= @{ 'First' = 1; 'Second' = 2 }; 'result'=@'
---
First: null
Second: null
'@;}, 
#>
$TheTests=@(
@{
test='Block Sequence in Block Sequence';
json=@'
[
    [
    "s1_i1",
    "s1_i2"
    ],
    "s2"
]
'@; yaml= @'
---
- - s1_i1
  - s1_i2
- s2
'@;},@{
test='Allowed characters in keys';
json=@'
{
      "a!\"#$%&'()*+,-./09:;<=>?@AZ[\\]^_`az{|}~": "safe",
      "?foo": "safe question mark",
      ":foo": "safe colon",
      "-foo": "safe dash",
      "this is#not": "a comment"
}
'@; yaml= @'
---
a!"#$%&'()*+,-./09:;<=>?@AZ[\]^_`az{|}~: safe
?foo: safe question mark
:foo: safe colon
-foo: safe dash
this is#not: a comment
'@;}
)

$TheTests |foreach{
    if ($_.YAML.Trim() -eq (($_.json|convertFrom-json|convertTo-yaml) -join "`r`n"))
        {"passed $($_.test)"} else {"failed $($_.test)"} 
    }
