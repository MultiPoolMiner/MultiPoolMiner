using module ..\Include.psm1

# Static values per pool, if set will override values from Config.ps1
# $Wallet = "3JQt8RezoGeEmA5ziAKNvxk34cM9JWsMCo"
# $WorkerName = "Blackbox"
# $Password = "x"
# $ProfitLessFee = $true# If $true reported profit will be less fees as sent by the pool
# End static values per pool, if set will override values from start.bat

# In case some algos are not working properly, comma separated list
#$DisabledAlgorithms = @("X13", "Scrypt")

$ProfitFactor = 1 # 1 = 100%, use lower number to compensate for overoptimistic profit estimates sent by pool
$Fee = 3 # Default pool fee
$ShortPoolName = "NH"
#End of user settable variables

if (-not $WorkerName) {$WorkerName = $env:computername}
if ($WorkerName.Length -gt 15) {$WorkerName = $WorkerName.substring(0,15)}

#$Nicehash_Regions = "eu", "usa", "hk", "jp", "in", "br"
$Nicehash_Regions = "eu"
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
if ($UseShortPoolNames -and $ShortPoolName) {$PoolName = $ShortPoolName} else {$PoolName = $Name}
$URI = "http://api.nicehash.com/api?method=simplemultialgo.info"

# Switch to nicehash wallet
if ($Wallet -eq '1GPSq8txFnyrYdXL8t6S94mYdF8cGqVQJF') {$Wallet = "3JQt8RezoGeEmA5ziAKNvxk34cM9JWsMCo"}

if (-not $Wallet) {Write-Log -Level Warn "Pool API ($Name) has no wallet address to mine to.";return}

if (-not $PriceTimeSpan) {
    $PriceTimeSpan = "Week" # Week, Day, Hour, Minute_10, Minute_5
}

$NiceHash_Request = [PSCustomObject]@{}
try {
    $NiceHash_Request = Invoke-RestMethod $URI -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed."
	return
}

if (($NiceHash_Request.result.simplemultialgo | Measure-Object).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing."
    return
}

$NiceHash_Host = "nicehash.com"

$NiceHash_Request.result.simplemultialgo | ForEach-Object {
    
    $NiceHash_Algorithm = $_.name

    # Do only for selected algorithms
    if ($DisabledAlgorithms -inotcontains $NiceHash_Algorithm -and ($Algorithm -eq $null -or $Algorithm.count -eq 0 -or $Algorithm -icontains $(Get-Algorithm $NiceHash_Algorithm)) -and [Double]$_.paying -gt 0) {

        $NiceHash_Port = $_.port
        $NiceHash_Algorithm_Norm = Get-Algorithm $NiceHash_Algorithm
        if ($NiceHash_Algorithm_Norm -eq "Sia") {$NiceHash_Algorithm_Norm = "SiaNiceHash"} #temp fix
        if ($NiceHash_Algorithm_Norm -eq "Decred") {$NiceHash_Algorithm_Norm = "DecredNiceHash"} #temp fix
#        if ($NiceHash_Algorithm_Norm -eq "Cryptonight") {$NiceHash_Algorithm_Norm = "CryptonightNiceHash"} #temp fix

        if ($Fee) {[Double]$NiceHash_Fee = [Double]$Fee} else {$NiceHash_Fee = 0}
        if ($ProfitLessFee) {$NiceHash_ProfitFactor = [Double]($ProfitFactor * (100 - $NiceHash_Fee) / 100)} else {$NiceHash_ProfitFactor = [Double]$ProfitFactor}
        
        $NiceHash_Info = "ProfitFactor: $($NiceHash_ProfitFactor.ToString("N3")) (Fee: $($NiceHash_Fee.ToString("N1"))%)"
        
        $Divisor = 1000000000 / $NiceHash_ProfitFactor

        $Stat = Set-Stat -Name "$($Name)_$($NiceHash_Algorithm_Norm)_Profit" -Value ($_.paying / $Divisor) -Duration $StatSpan -ChangeDetection $true
        
        $NiceHash_Regions | ForEach-Object {
            $NiceHash_Region = $_
            $NiceHash_Region_Norm = Get-Region $NiceHash_Region

            [PSCustomObject]@{
                PoolName        = $PoolName
                Algorithm       = $NiceHash_Algorithm_Norm
                Info            = $NiceHash_Info
                Price           = $Stat.Live
                StablePrice     = $Stat.$($PriceTimeSpan)
                MarginOfError   = $Stat.$("$($PriceTimeSpan)_Fluctuation")
                Protocol        = "stratum+tcp"
                Host            = "$NiceHash_Algorithm.$NiceHash_Region.$NiceHash_Host"
                Hosts           = ($NiceHash_Regions | ForEach {$NiceHash_Algorithm + "." + $_ + "." + $NiceHash_Host}) -join ";"
                Port            = $NiceHash_Port
                User            = "$Wallet.$WorkerName"
                Pass            = "$Password"
                Region          = $NiceHash_Region_Norm
                SSL             = $false
                Updated         = $Stat.Updated
            }
            
            if ($NiceHash_Algorithm_Norm -eq "Cryptonight" -or $NiceHash_Algorithm_Norm -eq "Equihash") {
                [PSCustomObject]@{
                    PoolName      = $PoolName
                    Algorithm     = $NiceHash_Algorithm_Norm
                    Info          = $NiceHash_Info
                    Price         = $Stat.Live
                    StablePrice   = $Stat.$($PriceTimeSpan)
                    MarginOfError = $Stat.$("$($PriceTimeSpan)_Fluctuation")
                    Protocol      = "stratum+ssl"
                    Host          = "$NiceHash_Algorithm.$NiceHash_Region.$NiceHash_Host"
                    Hosts         = ($NiceHash_Regions | ForEach {$NiceHash_Algorithm + "." + $_ + "." + $NiceHash_Host}) -join ";"
                    Port          = $NiceHash_Port + 30000
                    User          = "$Wallet.$WorkerName"
                    Pass          = "$Password"
                    Region        = $NiceHash_Region_Norm
                    SSL           = $true
                    Updated       = $Stat.Updated
                }
            }
        }
    }
}
Sleep 0