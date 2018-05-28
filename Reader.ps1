param([String]$Log = ".\.txt", [String]$Sort = "", [Switch]$QuickStart)

Set-Location (Split-Path $MyInvocation.MyCommand.Path)

$Active = @()

while ($true) {
    Compare-Object @(Get-Job -ErrorAction Ignore | Select-Object -ExpandProperty Name) @(Get-ChildItem ".\Logs" -ErrorAction Ignore | Where-Object {(-not $QuickStart) -or ((Get-Date) - $_.LastWriteTime).TotalMinutes -le 1} | Select-Object -ExpandProperty Name) | 
        Sort-Object {$_.InputObject -replace $Sort} | 
        Where-Object InputObject -match $Log | 
        Where-Object SideIndicator -EQ "=>" | 
        ForEach-Object {$Active += @{Id = (Start-Job ([ScriptBlock]::Create("Get-Content '$(Convert-Path ".\Logs\$($_.InputObject)")' -Wait$(if($QuickStart){" -Tail 1000"})")) -Name $_.InputObject).Id; Time = (Get-Date).ToUniversalTime()}}

    Start-Sleep 1

    Get-Job | Where-Object {$_ | Receive-Job -Keep; $Active += @{Id = $_.Id; Time = (Get-Date).ToUniversalTime()}} | Select-Object -First 1 | Receive-Job | Where-Object {$_}

    $Active = @($Active | Where-Object Time -ge (Get-Date).ToUniversalTime().AddMinutes(-10))
    Get-Job | Where-Object {-not ($Active | Where-Object Id -EQ $_.Id)} | Remove-Job -Force
}
