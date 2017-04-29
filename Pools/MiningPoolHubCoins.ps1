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

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Locations = 'Europe', 'US', 'Asia'

$Locations | ForEach {
    $Location = $_

    $MiningPoolHub_Request.return | ForEach {
        $Algorithm = $_.algo -replace "-"
        $Coin = (Get-Culture).TextInfo.ToTitleCase(($_.coin_name -replace "-", " ")) -replace " "

        if((Get-Stat -Name "MiningPoolHubCoins_$($Coin)_Profit") -eq $null){$Stat = Set-Stat -Name "MiningPoolHubCoins_$($Coin)_Profit" -Value ([decimal]$_.profit/1000000000*(1-0.05))}
        else{$Stat = Set-Stat -Name "$($Name)_$($Coin)_Profit" -Value ([decimal]$_.profit/1000000000)}
        $Price = (($Stat.Live*(1-[Math]::Min($Stat.Day_Fluctuation,1)))+($Stat.Day*(0+[Math]::Min($Stat.Day_Fluctuation,1))))
        
        [PSCustomObject]@{
            Algorithm = $Algorithm.ToLower()
            Info = $Coin
            Price = $Price
            StablePrice = $Stat.Week
            Protocol = 'stratum+tcp'
            Host = $_.host_list.split(";") | Sort -Descending {$_ -ilike "$Location*"} | Select -First 1
            Port = $_.port
            User = '$UserName.$WorkerName'
            Pass = 'x'
            Location = $Location
            SSL = $false
        }
        
        [PSCustomObject]@{
            Algorithm = $Algorithm.ToLower()
            Info = $Coin
            Price = $Price
            StablePrice = $Stat.Week
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