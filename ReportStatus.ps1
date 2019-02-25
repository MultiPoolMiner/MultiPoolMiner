using module .\Include.psm1

[CmdletBinding()]
param (
    [PSCustomObject]$Config = @{},
    [Miner[]]$ActiveMiners = @()
)

$Profit = [Double]($ActiveMiners | Where-Object Best | Where-Object {$_.GetStatus() -eq "Running"} | Measure-Object Profit -Sum).Sum | ConvertTo-Json

#Format the miner values for reporting. Set relative path so the server doesn't store anything personal (like your system username, if running from somewhere in your profile)
$Minerreport = @(
    $ActiveMiners | Where-Object Best | ForEach-Object {
        #Create a custom object to convert to json. Type, Pool, CurrentSpeed and EstimatedSpeed are all forced to be arrays, since they sometimes have multiple values.
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
) | ConvertTo-Json

Start-Job -Name ReportStatus -ArgumentList $Config.MinerStatusURL, $Config.MinerStatusKey, $Config.WorkerName, $Profit, $Minerreport -ScriptBlock {
    param (
        [String]$MinerStatusURL, 
        [String]$MinerStatusKey, 
        [String]$WorkerName, 
        [string]$Profit, 
        [string]$Minerreport
    )

    Write-Log "Pinging monitoring server. "
    Write-Host "Your miner status key is: $MinerStatusKey"    

    try {
        $Response = Invoke-RestMethod -Uri $MinerStatusURL -Method Post -Body @{address = $MinerStatusKey; workername = $WorkerName; miners = $Minerreport; profit = $Profit} -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop

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
}
