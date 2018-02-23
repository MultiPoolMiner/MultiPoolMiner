param([String]$Log = ".\.txt", [String]$Sort = "")

Set-Location (Split-Path $MyInvocation.MyCommand.Path)

while ($true) {
    Compare-Object @(Get-Job -ErrorAction Ignore | Select-Object -ExpandProperty Name) @(Get-ChildItem ".\Logs" -ErrorAction Ignore | Select-Object -ExpandProperty Name) | 
        Sort-Object {$_.InputObject -replace $Sort} | 
        Where-Object InputObject -match $Log | 
        Where-Object SideIndicator -EQ "=>" | 
        ForEach-Object {Start-Job ([ScriptBlock]::Create("Get-Content '$(Convert-Path ".\Logs\$($_.InputObject)")' -Wait")) -Name $_.InputObject | Out-Null}

    Start-Sleep 1

    Get-Job | Where-Object {$_ | Receive-Job -Keep} | Select-Object -First 1 | Receive-Job | Where-Object {$_}
}