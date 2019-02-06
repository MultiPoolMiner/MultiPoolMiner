using module .\Include.psm1

[CmdletBinding()]
param (
    [PSCustomObject]$Config = @{},
    $ActiveMiners = @()
)

Write-Log "Pinging monitoring server. "
Write-Host "Your miner status key is: $($Config.MinerStatusKey)"

$Profit = ($ActiveMiners | Where-Object {$_.Activated -GT 0 -and $_.GetStatus() -eq "Running"} | Measure-Object Profit -Sum).Sum | ConvertTo-Json

# Format the miner values for reporting. Set relative path so the server doesn't store anything personal (like your system username, if running from somewhere in your profile)
$Minerreport = ConvertTo-Json @(
    $ActiveMiners | Where-Object {$_.Activated -GT 0 -and $_.GetStatus() -eq "Running"} | Foreach-Object {
        # Create a custom object to convert to json. Type, Pool, CurrentSpeed and EstimatedSpeed are all forced to be arrays, since they sometimes have multiple values.
        [PSCustomObject]@{
            Name           = $_.Name
            Path           = Resolve-Path -Relative $_.Path
            Type           = @($_.Type)
            Active         = "{0:dd} Days {0:hh} Hours {0:mm} Minutes" -f $_.GetActiveTime()
            Algorithm      = @($_.Algorithm)
            Pool           = @($_.Pool)
            CurrentSpeed   = @($_.Speed_Live)
            EstimatedSpeed = @($_.Speed)
            'BTC/day'      = $_.Profit
        }
    }
)

try {
    $Response = Invoke-RestMethod -Uri $Config.MinerStatusURL -Method Post -Body @{address = $($Config.MinerStatusKey); workername = $Config.WorkerName; miners = $Minerreport; profit = $Profit} -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop

    if ($Response -eq "success") {
        Write-Log "Miner Status ($($Config.MinerStatusURL)): $Response"
    }
    else {
        Write-Log -Level Warn "Miner Status ($($Config.MinerStatusURL)): $Response"
    }
}
catch {
    Write-Log -Level Warn "Miner Status ($($Config.MinerStatusURL)) has failed. "
}
