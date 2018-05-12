using module .\Include.psm1

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false)]
    [Switch]$VerifyOnly = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$Overwrite = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$SkipCPU = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$SkipAMD = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$SkipNVIDIA = $false

)

# Make sure we are in the script's directory
Set-Location (Split-Path $MyInvocation.MyCommand.Path)

# Get device information
$Devices = Get-Devices

# Choose which types to download
$Types = @()
if(-not $SkipAMD) {$Types += "AMD"}
if(-not $SkipNVIDIA) {$Types += "NVIDIA"}
if(-not $SkipCPU) {$Types += "CPU"}

Write-Verbose "Downloading miners for types: $Types"

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
$BinDirectory = (Resolve-Path ".\Bin").Path

# Get all the miners using the fake configuration
$Miners = Get-ChildItemContent "Miners" -Parameters @{Pools = $Pools; Stats = $Stats; Config = $Config; Devices = $Devices} | ForEach-Object {$_.Content | Add-Member Name $_.Name -PassThru -Force} 
Write-Debug "$($Miners.Count) miners loaded (including duplicates)"

# Filter duplicates (same miner, different algo) out of the list
$Miners = $Miners | Sort-Object -Property Name, Path, HashSHA256 -Unique
Write-Debug "$($Miners.Count) miners (excluding duplicates)"

$Miners | Foreach-Object {
    $Miner = $_

    # Check if skipping this type of miner
    If (($Miner.Type | Where-Object {$Types -contains $_}).Count -eq 0) {
        Write-Verbose "$($Miner.Name) - skipped, only supports $($Miner.Type)"
        Return
    }

    if(Test-Path $Miner.Path) {
        #Miner file exists
        if($Miner.HashSHA256) {
            # A hash was provided in the miner file
            $Hash = (Get-FileHash $Miner.Path).Hash
            if ($Hash -eq $Miner.HashSHA256) {
                # Correct file installed.  Only show output if -Verbose specified
                Write-Verbose "$($Miner.Name) - correct version installed"
                Return
            }
            else {
                # Wrong version of miner installed - if -Overwrite specified and miner can be automatically downloaded, delete it
                if($Overwrite -and $Miner.URI) {
                    Write-Warning "$($Miner.Name) - incorrect version installed (got hash $($Hash), expected $($Miner.HashSHA256)), updating..."
                    # Delete the existing miner and stats files, and don't return so the miner gets redownloaded
                    Write-Host "    Deleting $(Split-Path $Miner.Path)"
                    
                    # As a failsafe here, make sure the folder is a subdirectory of .\Bin - otherwise a bad miner file could list the path as c:\windows\cmd.exe and try to wipe out your windows directory!
                    $MinerFolder = (Resolve-Path (Split-Path $Miner.Path)).Path
                    If($MinerFolder.StartsWith($BinDirectory)) {
                        # Have to use -force because many of the download files are flagged as read-only
                        Remove-Item -Force -Recurse (Split-Path $Miner.Path)
                        Write-Host "    Deleting .\Stats\$($Miner.Name)_*.txt"
                        Remove-Item ".\Stats\$($Miner.Name)_*.txt"
                    } else {
                        Write-Warning "$($Miner.Name) - path $($Miner.Path) is not in the .\Bin directory, path is invalid, not deleting."
                        Return
                    }
                } else {
                    Write-Warning "$($Miner.Name) - incorrect version installed, delete $(Split-Path $Miner.Path) directory and redownload - got $($Hash), expected $($Miner.HashSHA256)"
                    Return
                }
            }
        }
        else {
            Write-Warning "$($Miner.Name) - unable to verify version, miner missing HashSHA256 property."
            Return
        }
    }
    
    # If the loop reaches here, the miner either didn't exist, or we removed it
    If ($VerifyOnly) {
        Write-Warning "$($Miner.Name) - $($Miner.Path) missing"
        Return
    }
    
    If (-not $Miner.URI) {
        if ($Miner.ManualURI) {
            Write-Warning "$($Miner.Name) - must be downloaded manually from $($Miner.ManualURI) and extracted to $($Miner.Path)"
            Return
        }
        else {
            Write-Warning "$($Miner.Name) - must be downloaded manually and extracted to $($Miner.Path)"
            Return
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
            Return
        }
    }

    # Test again to verify that the freshly downloaded miner is the correct version
    if(Test-Path $Miner.Path) {
        #Miner file exists
        if($Miner.HashSHA256) {
            # A hash was provided in the miner file
            $Hash = (Get-FileHash $Miner.Path).Hash
            if ($Hash -eq $Miner.HashSHA256) {
                # Correct file installed.  Only show output if -Verbose specified
                Write-Verbose "$($Miner.Name) - correct version installed"
                Return
            }
            else {
                # Wrong version of miner installed - already tried downloading it, so just give a warning
                Write-Warning "$($Miner.Name) - incorrect version installed after downloading. HashSHA256 may be incorrect or file may have changed. Got $($Hash), expected $($Miner.HashSHA256)"
                Return
            }
        }
        else {
            Write-Warning "$($Miner.Name) - unable to verify version, miner missing HashSHA256 property."
            Return
        }
    } else {
        Write-Warning "$($Miner.Name) - failed to download"
    }
}
