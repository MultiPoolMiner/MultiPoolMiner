using module .\Include.psm1

param([String]$MPMVersion, [String]$PSVersion, [String]$NFVersion)

if ($script:MyInvocation.MyCommand.Path) {Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)}

$ProgressPreferenceBackup = $ProgressPreference


Function Get-Version ($Version) {
    # System.Version objects can be compared with -gt and -lt properly
    # This strips out anything that doens't belong in a version, eg. v at the beginning, or -preview1 at the end, and returns a version object
    Return [System.Version]($Version -Split "-" -Replace "[^0-9.]")[0]
}


$Name = "MultiPoolMiner"
try {
    $ProgressPreference = "SilentlyContinue"
    $Request = Invoke-RestMethod -Uri "https://api.github.com/repos/multipoolminer/$Name/releases/latest" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    $Version = ($Request.tag_name -replace '^v')
    $Uri = $Request.assets | Where-Object Name -EQ "$($Name)V$($Version).zip" | Select-Object -ExpandProperty browser_download_url

    if ( (Get-Version($Version)) -gt (Get-Version($MPMVersion)) ) {
        Write-Log -Level Warn "$Name is out of date; current version $(Get-Version($Version)), lastest release $(Get-Version($Version)) - there is an updated version available at $URI. "
    }

    if ( (Get-Version($Version)) -lt (Get-Version($MPMVersion)) ) {
        Write-Log -Level Warn "You are running prerelease version $(Get-Version($Version)) of $Name. Use at your own risk."
    }

}
catch {
    Write-Log -Level Warn "The software ($Name) failed to update. "
}

$Name = "PowerShell"
try {
    $ProgressPreference = "SilentlyContinue"
    $Request = Invoke-RestMethod -Uri "https://api.github.com/repos/powershell/$Name/releases" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop

    # Filter to only show the latest non-preview release
    $LatestVersion = $Request.tag_name | Where-Object {$_ -notmatch '-preview' -and $_ -notmatch '-rc' -and $_ -notmatch '-beta' -and $_ -notmatch '-alpha'} | Select-Object -First 1
    $Request = $Request | Where-Object {$_.tag_name -eq $LatestVersion}

    $Version = ($Request.tag_name -replace '^v')
    $URI = $Request.assets | Where-Object Name -EQ "$($Name)-$($Version)-win-x64.msi" | Select-Object -ExpandProperty browser_download_url

    if ( (Get-Version($Version)) -gt (Get-Version($PSVersion)) ) {
        $ProgressPreference = $ProgressPreferenceBackup
        Write-Progress -Activity "Updater" -Status $Name -CurrentOperation "Acquiring Online ($URI)"
        $ProgressPreference = "SilentlyContinue"
        Expand-WebRequest $URI -ErrorAction Stop
    }
}
catch {
    Write-Log -Level Warn "The software ($Name) failed to update. "
}

$ProgressPreference = $ProgressPreferenceBackup

Write-Progress -Activity "Updater" -Completed