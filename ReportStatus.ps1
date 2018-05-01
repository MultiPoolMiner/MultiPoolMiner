using module .\Include.psm1

param(
    [Parameter(Mandatory = $true)][String]$Key,
    [Parameter(Mandatory = $true)][String]$WorkerName,
    [Parameter(Mandatory = $true)]$ActiveMiners,
    [Parameter(Mandatory = $true)]$MinerStatusURL
)

Write-Log "Pinging monitoring server. "
$profit = ($ActiveMiners | Where-Object {$_.Activated -GT 0 -and $_.GetStatus() -eq "Running"} | Measure-Object Profit -Sum).Sum | ConvertTo-Json

# Format the miner values for reporting.  Set relative path so the server doesn't store anything personal (like your system username, if running from somewhere in your profile)
$minerreport = ConvertTo-Json @(
    $ActiveMiners | Where-Object {$_.Activated -GT 0 -and $_.GetStatus() -eq "Running"} | Foreach-Object {
        # Create a custom object to convert to json. Type, Pool, CurrentSpeed and EstimatedSpeed are all forced to be arrays, since they sometimes have multiple values.
        [pscustomobject]@{
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
    $Response = Invoke-RestMethod -Uri $MinerStatusURL -Method Post -Body @{address = $Key; workername = $WorkerName; miners = $minerreport; profit = $profit} -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop

    if ($Response -eq "success") {
        Write-Log "Miner Status ($MinerStatusURL): $Response"
    }
    else {
        Write-Log -Level Warn "Miner Status ($MinerStatusURL): $Response"
    }
}
catch {
    Write-Log -Level Warn "Miner Status ($MinerStatusURL) has failed. "
}

Write-Host "Your miner status key is: $Key"