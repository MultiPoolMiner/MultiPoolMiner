using module .\include.psm1

[CmdletBinding()]
Param(
    [TimeSpan]$StatSpan,
    [PSCustomObject]$Config
)

@(Get-ChildItem "Pools" -File | Where-Object {$Config.Pools.$($_.BaseName) -and $Config.ExcludePoolName -inotcontains $_.BaseName} | Where-Object {$Config.PoolName.Count -eq 0 -or $Config.PoolName -contains $_.BaseName} | ForEach-Object {
    $Pool_Name = $_.BaseName
    $Pool_Parameters = @{StatSpan = $StatSpan; Config = $Config}
    $Config.Pools.$Pool_Name | Get-Member -MemberType NoteProperty | ForEach-Object {$Pool_Parameters.($_.Name) = $Config.Pools.$Pool_Name.($_.Name)}
    Get-ChildItemContent "Pools\$($_.Name)" -Parameters $Pool_Parameters
} | ForEach-Object {$_.Content | Add-Member Name $_.Name -PassThru})
