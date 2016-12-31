. .\Include.ps1

try
{
    $MiningPoolHub_Request = Invoke-WebRequest "http://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics" -UseBasicParsing | ConvertFrom-Json
}
catch
{
    return
}

if(-not $MiningPoolHub_Request.success)
{
    return
}

$Locations = 'Europe', 'US', 'Asia'

$Locations | ForEach {
    $Location = $_

    $MiningPoolHub_Request.return | ForEach {
        $Algorithm = $_.algo -replace "-", "_"

        $Stat = Set-Stat -Name "MiningPoolHubCoins_$($_.coin_name)_Profit" -Value ([decimal]$_.profit/1000000000)
        $Price = (($Stat.Live*(1-[Math]::Min($Stat.Hour_Fluctuation,1)))+($Stat.Hour*(0+[Math]::Min($Stat.Hour_Fluctuation,1))))
        
        [PSCustomObject]@{
            Algorithm = $Algorithm
            Price = $Price
            Protocol = 'stratum+tcp'
            Host = $_.host_list.split(";") | Sort -Descending {$_ -ilike "$Location*"} | Select -First 1
            Port = $_.port
            User = '$UserName.$WorkerName'
            Pass = 'x'
            Location = $Location
            SSL = $false
        }
        
        [PSCustomObject]@{
            Algorithm = $Algorithm
            Price = $Price
            Protocol = 'stratum+ssl'
            Host = $_.host_list.split(";") | Sort -Descending {$_ -ilike "$Location*"} | Select -First 1
            Port = $_.port
            User = '$UserName.$WorkerName'
            Pass = 'x'
            Location = $Location
            SSL = $true
        }
    }
}