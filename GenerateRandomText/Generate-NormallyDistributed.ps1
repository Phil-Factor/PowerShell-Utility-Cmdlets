<#
	.SYNOPSIS
		return normally-distributed random number
	
	.DESCRIPTION
		This is the Box-Muller transform
	
	.PARAMETER mean
		the mean of the bellcurve.
	
	.PARAMETER stdDev
		The standard deviation.
	
#>
function Generate-NormallyDistributed
{
	[OutputType([double])]
	param
	(
		[Parameter(Mandatory = $false)]
		$mean = '0',
		[Parameter(Mandatory = $false)]
		$stdDev = '1'
	)
	
	[double]$u1 = Get-Random -Minimum 0.0 -Maximum 1.0
	[double]$u2 = Get-Random -Minimum 0.0 -Maximum 1.0
	
	[double]$randStdNormal = [math]::Sqrt(-2.0 * [math]::Log($u1)) * [math]::Sin(2.0 * [math]::PI * $u2)
	[double]$randNormal = $mean + $stdDev * $randStdNormal
	
	$randNormal
}

 