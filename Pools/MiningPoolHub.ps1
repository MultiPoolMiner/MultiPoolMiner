. .\Include.ps1

$MiningPoolHub_Request = Invoke-WebRequest "https://miningpoolhub.com/index.php?page=api&action=getautoswitchingandprofitsstatistics" -UseBasicParsing | ConvertFrom-Json

if(-not $MiningPoolHub_Request.success)
{
    return
}

$MiningPoolHub_Request.return | ForEach {
    $Algorithm = $_.algo -replace "-", "_"
    $Stat = Set-Stat -Name "MiningPoolHub_$($Algorithm)_Profit" -Value ([decimal]$_.profit/1000000000)
    
    [PSCustomObject]@{
        Algorithm = $Algorithm
        Price = (($Stat.Live*(1-[Math]::Min($Stat.Hour_Fluctuation,1)))+($Stat.Hour*(0+[Math]::Min($Stat.Hour_Fluctuation,1))))
        Host = $_.host
        Port = $_.algo_switch_port
        User = '$UserName.$WorkerName'
        Pass = 'x'
    }
}