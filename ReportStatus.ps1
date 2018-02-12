using module .\Include.psm1

param(
    [Parameter(Mandatory = $true)][String]$Key,
    [Parameter(Mandatory = $true)][String]$WorkerName,
    [Parameter(Mandatory = $true)]$ActiveMiners,
    [Parameter(Mandatory = $true)]$Miners,
    [Parameter(Mandatory = $true)]$MinerStatusURL
)

Write-Log "Pinging monitoring server. "
$profit = ($ActiveMiners | Where-Object {$_.Activated -GT 0 -and $_.Status -eq "Running"} | Measure-Object Profit -Sum).Sum | ConvertTo-Json

# Format the miner values for reporting.  Set relative path so the server doesn't store anything personal (like your system username, if running from somewhere in your profile)
$minerreport = ConvertTo-Json @($ActiveMiners | Where-Object {$_.Activated -GT 0 -and $_.Status -eq "Running"} | Foreach-Object {
        $ActiveMiner = $_
        # Find the matching entry in $Miners, to get pool information. Perhaps there is a better way to do this?
        $MatchingMiner = $Miners | Where-Object {$_.Name -eq $ActiveMiner.Name -and $_.Path -eq $ActiveMiner.Path -and $_.Arguments -eq $ActiveMiner.Arguments -and $_.Wrap -eq $ActiveMiner.Wrap -and $_.API -eq $ActiveMiner.API -and $_.Port -eq $ActiveMiner.Port}
        # Create a custom object to convert to json. Type, Pool, CurrentSpeed and EstimatedSpeed are all forced to be arrays, since they sometimes have multiple values.
        [pscustomobject]@{
            Name           = $_.Name
            Path           = Resolve-Path -Relative $_.Path
            Type           = @($_.Type)
            Active         = "{0:dd} Days {0:hh} Hours {0:mm} Minutes" -f $_.GetActiveTime()
            Algorithm      = @($_.Algorithm)
            Pool           = @($MatchingMiner.Pools.PsObject.Properties.Value.Name)
            CurrentSpeed   = @($_.Speed_Live)
            EstimatedSpeed = @($_.Speed)
            'BTC/day'      = $_.Profit
        }
    })
Invoke-RestMethod -Uri $MinerStatusURL -Method Post -Body @{address = $Key; workername = $WorkerName; miners = $minerreport; profit = $profit}
Write-Host "Your miner status key is: $Key"