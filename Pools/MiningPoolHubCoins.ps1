using module ..\Include.psm1

param(
    [String]$User,
    [String]$Worker,
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$PoolAPIUri= "http://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics&$(Get-Date -Format "yyyy-MM-dd_HH-mm")"
$PoolRegions = "europe", "us-east", "asia"

#defines minimum memory required per coin, default is 4gb
$MinMem = [PSCustomObject]@{
    "Expanse"  = "2gb"
    "Soilcoin" = "2gb"
    "Ubiq"     = "2gb"
    "Musicoin" = "3gb"
}

if ($User) {

    $RetryCount = 3
    $RetryDelay = 2
    while (-not ($APIRequest) -and $RetryCount -gt 0) {
        try {
            if (-not $APIRequest) {$APIRequest = Invoke-RestMethod $PoolAPIUri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
        }
        catch {
            Start-Sleep -Seconds $RetryDelay
            $RetryCount--        
        }
    }

    if (-not $APIRequest) {
        Write-Log -Level Warn "Pool API ($Name) has failed. "
        return
    }

    if ($APIRequest.return.count -le 1) {
        Write-Log -Level Warn "Pool API ($Name) returned nothing. "
        return
    }

    $APIRequest.return | ForEach-Object {

        $PoolHosts      = $_.host_list.split(";")
        $Port           = $_.port
        $Algorithm      = $_.algo
        $Algorithm_Norm = Get-Algorithm $Algorithm
        $CoinName       = (Get-Culture).TextInfo.ToTitleCase(($_.coin_name -replace "-", " " -replace "_", " ").ToLower()) -replace " "

        #Electroneum hardforked. ETN algo changed to previous Cryptonight which is also compatible with ASIC
        if ($CoinName -eq "Electroneum") {$Algorithm_Norm = "Cryptonight"}

        if ($Algorithm_Norm -eq "Sia") {$Algorithm_Norm = "SiaClaymore"} #temp fix

        $Divisor = 1000000000

        $Stat = Set-Stat -Name "$($Name)_$($Algorithm_Norm)_Profit" -Value ([Double]$_.profit / $Divisor) -Duration $StatSpan -ChangeDetection $true

        $PoolRegions | ForEach-Object {
            $Region = $_
            $Region_Norm = Get-Region ($Region -replace "^us-east$", "us")

            [PSCustomObject]@{
                Algorithm     = "$($Algorithm_Norm)$(if ($Algorithm_Norm -EQ "Ethash"){$MinMem.$CoinName})"
                CoinName      = $CoinName
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $PoolHosts | Sort-Object -Descending {$_ -ilike "$Region*"} | Select-Object -First 1
                Port          = $Port
                User          = "$User.$Worker"
                Pass          = "x"
                Region        = $Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
                Fee           = 0.9 / 100
            }
            [PSCustomObject]@{
                Algorithm     = "$($Algorithm_Norm)$(if ($Algorithm_Norm -EQ "Ethash"){$MinMem.$CoinName})"
                CoinName      = $CoinName
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+ssl"
                Host          = $PoolHosts | Sort-Object -Descending {$_ -ilike "$Region*"} | Select-Object -First 1
                Port          = $Port
                User          = "$User.$Worker"
                Pass          = "x"
                Region        = $Region_Norm
                SSL           = $true
                Updated       = $Stat.Updated
                Fee           = 0.9 / 100
            }
        }
    }
}
else { 
    Write-Log -Level Verbose "Cannot mine on pool ($Name) - no wallet address specified. "
}

