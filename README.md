# PowerShell Utility Cmdlets

This is a repository for a collection of Cmdlets that I wrote only because I needed them and nobody else seemed to have written them. 

## ConvertFrom-XML

 [ConvertFrom-XML](ConvertF)  does what you’d expect.  It works in a similar way to ConvertFrom-JSON. It is not entirely plain-sailing. There are certain problems with tackling a routine that has to successfully convert all the permutations of XML into arrays and hashtables. XML doesn’t handle arrays natively but implies them by assigning them the same keys, it allows empty elements, or elements that contain only other elements. There is no built-in concept of NULLs. It can have elements that contain only text, or that mix text and elements. Additionally, attributes don’t have any intrinsic order whereas elements do.

## Diff-Objects

 [Diff-Objects](Diff-Objects)  does what you always imagined that Compare-object did. It shows you what has changed in an object. It lists the path to each value, and what is in the value in either object and whether it is different or the same. 

## Display-Object

[Display-Object](Display-Object)  Is a way of displaying the values in an object. It lists the path to each value and the value itself. 

## Import-Log

 [Import-Log](Import-Log)  is a way of converting any log into a PowerShell object that allows you to sort and filter the log records. Want just the errors or warnings? This is the Cmdlet for you. I also provide log Regex strings for some Redgate products. Sadly, you’re going to need to adapt one of the samples to create the regex for any particular log because, for some wierd reason, nobody has ever established a common standard.

