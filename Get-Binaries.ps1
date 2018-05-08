using module .\Include.psm1

# Generate configuration and pool info that will ensure all miners get included
$Timer = (Get-Date).ToUniversalTime()
$StatStart = $Timer
$StatEnd = $Timer.AddSeconds(60)
$StatSpan = New-TimeSpan $StatStart $StatEnd

$Stats = [PSCustomObject]@{}
if (Test-Path "Stats") {Get-ChildItemContent "Stats" | ForEach-Object {$Stats | Add-Member $_.Name $_.Content}}

$Config = [PSCustomObject]@{
    Pools = [PSCustomObject]@{}
    Miners = [PSCustomObject]@{}
    Interval = 60
    Region = 'US'
    SSL = $True
    Type = @('CPU','NVIDIA','AMD')
    Algorithm = @()
    Minername = @()
    Poolname = @()
    ExcludeAlgorithm = @()
    ExcludeMinerName = @()
    ExcludePoolName = @()
    Currency = 'USD'
    Donate = 10
    Proxy = ''
    Delay = 0
    Watchdog = $True
    SwitchingPrevention = 1
}

# Generate fake pools for each algorithm
$Algorithms = (Get-Content "Algorithms.txt" | ConvertFrom-Json).PSObject.Properties.Value | Foreach-Object {$_.ToLower() } | Select-Object -Unique
$Pools = [PSCustomObject]@{}
$Algorithms | Foreach-Object {
    $FakePool = [PSCustomObject]@{
        Algorithm = $_
        Info = ""
        Price = 1
        StablePrice = 1
        MarginOfError = 0
        Protocol = "stratum+tcp"
        Host = "google.com"
        Port = 1234
        User = "fake"
        Pass = "fake,c=BTC"
        Region = "US"
        SSL = $false
        Updated = [DateTime](Get-Date).ToUniversalTime()
        Name = "Fake"
        Price_Bias = 0
        Price_Unbias = 0
    }
    $Pools | Add-Member $_ $FakePool
}

# Get all the miners using the fake configuration, then filter to just the ones with unique paths
$Miners = Get-ChildItemContent "Miners" -Parameters @{Pools = $Pools; Stats = $Stats; Config = $Config} | ForEach-Object {$_.Content | Add-Member Name $_.Name -PassThru -Force} | Group-Object -Property Path | Foreach-Object {$_.Group | Select-Object -First 1}

if (-not (Test-Path ".\Bin")) {
    New-Item ".\Bin" -ItemType "Directory" | Out-Null
}

# Load the hashes for binary files
if (Test-Path "binaryhashes.txt" -PathType Leaf) {
    $Hashes = Get-Content "binaryhashes.txt" | ConvertFrom-Json
}
else {
    Write-Warning "binaryhashes.txt does not exist. Will not be able to verify whether the correct miner versions are installed."
    $Hashes = $null
}

$Miners | Foreach-Object {
    $Miner = $_
    if(Test-Path $Miner.Path) {
        Write-Host -NoNewline -ForegroundColor Green "Miner $($Miner.Name) already installed"
        if($Hashes) {
            if ((Get-FileHash $Miner.Path).Hash -eq $Hashes.$($Miner.Path)) {
                Write-Host -ForegroundColor Green " - correct version installed"
            }
            else {
                Write-Host -ForegroundColor Red " - incorrect version installed, delete $(Split-Path $Miner.Path) directory and redownload"
            }
        }
        else {
            Write-Host -ForegroundColor Red " - unable to verify version"
        }
    }
    else {
        if (-not $Miner.URI) {
            if ($Miner.ManualURI) {
                Write-Warning "Miner $($Miner.Name) must be downloaded manually from $($Miner.ManualURI) and extracted to $($Miner.Path)"
            }
            else {
                Write-Warning "Miner $($Miner.Name) must be downloaded manually and extracted to $($Miner.Path)"
            }
        }
        else {
            Write-Host "Downloading $($Miner.Name) from $($Miner.URI)..."
            try {
                if ((Split-Path $Miner.URI -Leaf) -eq (Split-Path $Miner.Path -Leaf)) {
                    # Miner isn't a zip file, download the exe directly
                    New-Item (Split-Path $Miner.Path) -ItemType "Directory" | Out-Null
                    Invoke-WebRequest $Miner.URI -OutFile $Miner.Path -UseBasicParsing -Erroraction Stop
                }
                else {
                    Expand-WebRequest $Miner.URI (Split-Path $Miner.Path) -ErrorAction Stop
                }
            }
            catch {
                Write-Warning "Failed to download $($Miner.Name) - download manually from $($Miner.URI) and extract to $($Miner.Path)"
            }
        }
    }
}

