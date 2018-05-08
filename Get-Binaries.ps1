using module .\Include.psm1

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false)]
    [Switch]$VerifyOnly = $false
)

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

if (-not (Test-Path ".\Bin")) {
    New-Item ".\Bin" -ItemType "Directory" | Out-Null
}

# Get all the miners using the fake configuration
$Miners = Get-ChildItemContent "Miners" -Parameters @{Pools = $Pools; Stats = $Stats; Config = $Config} | ForEach-Object {$_.Content | Add-Member Name $_.Name -PassThru -Force} | Foreach-Object {
    $Miner = $_
    if(Test-Path $Miner.Path) {
        #Miner file exists
        if($Miner.HashSHA256) {
            # A hash was provided in the miner file
            $Hash = (Get-FileHash $Miner.Path).Hash
            if ($Hash -eq $Miner.HashSHA256) {
                # Correct file installed.  Only show output if -Verbose specified
                Write-Verbose "$($Miner.Name) - correct version installed"
            }
            else {
                # Wrong version of miner installed
                Write-Warning "$($Miner.Name) - incorrect version installed, delete $(Split-Path $Miner.Path) directory and redownload - got $($Hash), expected $($Miner.HashSHA256)"
            }
        }
        else {
            Write-Warning "$($Miner.Name) - unable to verify version, miner missing HashSHA256 property"
        }
    }
    else {
        if($VerifyOnly) {
            Write-Warning "$($Miner.Name) - $($Miner.Path) missing"
        }
        else {
            if (-not $Miner.URI) {
                if ($Miner.ManualURI) {
                    Write-Warning "$($Miner.Name) - must be downloaded manually from $($Miner.ManualURI) and extracted to $($Miner.Path)"
                }
                else {
                    Write-Warning "$($Miner.Name) - must be downloaded manually and extracted to $($Miner.Path)"
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
}

