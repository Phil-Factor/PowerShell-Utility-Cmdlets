<#
  .SYNOPSIS
    Find out if the SQL Tokens in two different blocks of SQL Code match
  
  .DESCRIPTION
    Take two blocks of SQL Code- which can be formatted differently and have 
    all sort of comments or case differences, and see if the actual SQL is the
    same or not. A warning if a difference
  
  .PARAMETER SourceString
    The source version of the SQL Code.
  
  .PARAMETER TargetString
    The target version of the SQL Code that you want to compare the source with.
  
  .EXAMPLE
    Compare-SQLTokens @'  
/* Complex update with case and subquery */
UPDATE Inventory
SET StockLevel = CASE
WHEN StockLevel < 10 THEN StockLevel + 5
ELSE (SELECT AVG(StockLevel) FROM Inventory WHERE CategoryID = Inventory.CategoryID)
END
WHERE ProductID = 101;
'@  @'
UPDATE Inventory
  SET Stocklevel = 
    CASE --Alter Stocklevel Of Low Items
        WHEN Stocklevel < 10 THEN Stocklevel + 4 
        ELSE
        (SELECT Avg (Stocklevel) FROM Inventory WHERE
        Categoryid = Inventory.Categoryid) 
        END
  WHERE Productid = 101;
'@

#>
function Compare-SQLTokens
{
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true)]
    [string]$SourceString,
    [Parameter(Mandatory = $true)]
    [string]$TargetString
  )
  
  #The regex string will check for the major SQL Components  
  $parserRegex = [regex]@' 
(?i)(?s)(?<BlockComment>/\*.*?\*/)|(?#
)(?<EndOfLineComment>--[^\n\r]*)|(?#
)(?<String>N?'.*?')|(?#
)(?<number>[+\-]?\d+\.?\d{0,100}[+\-0-9E]{0,6})|(?#
)(?<SquareBracketed>\[.{1,255}?\])|(?#
)(?<Quoted>".{1,255}?")|(?#
)(?<Identifier>[@]?[\p{N}\p{L}_][\p{L}\p{N}@$#_]{0,127})|(?#
)(?<Operator><>|<=>|>=|<=|==|=|!=|!|<<|>>|<|>|\|\||\||&&|&|-|\+|\*(?!/)|/(?!\*)|\%|~|\^|\?)|(?#
)(?<Punctuation>[^\w\s\r\n])
'@
  $LineRegex = [regex]'(\r\n|\r|\n)';
  $exceptions = @(0, 'BlockComment', 'EndOfLineComment') #things we want to ignore
  $Source = $parserRegex.Matches($SourceString) | Foreach { $index = $_.index; $_.Groups } | foreach {
    if ($_.success -eq $true -and $_.name -ne 0 -and $_.name -notIn $exceptions)
    {
      @{ 'Index' = $index; 'token' = "$($_.Value.ToLower())" };
    }
  }
  
  $Target = $parserRegex.Matches($TargetString) | Foreach { $index = $_.index; $_.Groups } | foreach {
    if ($_.success -eq $true -and $_.name -ne 0 -and $_.name -notIn $exceptions)
    {
      @{ 'Index' = $index; 'token' = "$($_.Value.ToLower())" };
    }
  }
  
  0..([math]::Max($Source.Count, $Target.count) - 1) | foreach -begin { $context = @('', '') } {
    if ($Source[$_].token -ne $Target[$_].token)
    {
      #we have detected an anomaly
      #we need to get the line and column number as well as the index
      $Lines = $Lineregex.Matches($TargetString); #get the offset where lines start
      $Theline = 1;
      $TheIndex = $Target[$_].Index;
      While ($lines.count -ge $TheLine -and #do we bump the line number
        $lines[$TheLine - 1].Index -lt $TheIndex)
      { $Theline++ }
      $TheStart = switch ($Theline)
      {
        ({ $PSItem -le 2 }) { 0 }
        Default { $lines[$TheLine - 2].Index }
      }
      $TheColumn = $TheIndex - $TheStart;
      #retrieve the context - the three tokens before the difference if possible
      $Context = ([math]::max(0, ($_ - 3)))..$_ | foreach { "$($Target[$_].token)" }
      $CodeSectionStart=[math]::max(0,($TheIndex-20))
            $Codelength=[math]::min(30,$TargetString.length-$CodeSectionStart)
      $section  = $TargetString.Substring($CodeSectionStart,$Codelength)
      Write-warning "At line $TheLine, column $($TheColumn): $(
            )'$context' - '$($Target[$_].token)' is different to $(
            )'$($source[$_].token)' in the code `"'...$section...`".No further search attempted.."
            continue;
    }
  }
  
} 


Compare-SQLTokens `
    (Type '\\MillArchive\public\work\Github\FlywayTeamwork\Pubs\Migrations\FormattedFirstRelease' -Raw) `
    (Type '\\MillArchive\public\work\Github\FlywayTeamwork\Pubs\Migrations\V1.1__FirstRelease.sql' -Raw)