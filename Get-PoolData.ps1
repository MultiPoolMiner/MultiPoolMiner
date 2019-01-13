using module .\include.psm1

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [String]$Pool_Name, 
    [Parameter(Mandatory = $true)]
    [String]$Path, 
    [Parameter(Mandatory = $true)]
    [Hashtable]$Pool_Parameters = @{}    
)

$Pool_Data = @(Get-ChildItemContent "$Path" -Parameters $Pool_Parameters)

if ($Pool_Data.Count) {Write-Log -Level Verbose "Received $($Pool_Data.Count) data elements for pool $Pool_Name. "}

Return $Pool_data
