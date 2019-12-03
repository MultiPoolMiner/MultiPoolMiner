using module .\Include.psm1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [String]$APIUrl
)

Write-Log "Miner status reporting process started. "

Do { 
    if ($Config = Invoke-WebRequest -Uri "$($APIUrl)/config" -Timeout 5 -ErrorAction SilentlyContinue | ConvertFrom-Json) { 
        $RunningMiners = [Array](Invoke-WebRequest -Uri "$($APIUrl)/runningminers" -Timeout 5 -ErrorAction SilentlyContinue | ConvertFrom-Json)
        if ($Config.ReportStatusInterval -and $Config.MinerStatusKey -and $RunningMiners.Count) { 
            Write-Log "Pinging monitoring server. Your miner status key is: $($Config.MinerStatusKey). "

            $Profit = ($RunningMiners | Measure-Object Profit -Sum).Sum | ConvertTo-Json

            # Format the miner values for reporting. Set relative path so the server doesn't store anything personal (like your system username, if running from somewhere in your profile)
            $Minerreport = ConvertTo-Json @(
                $RunningMiners | Foreach-Object { 
                    # Create a custom object to convert to json. Type, Pool, CurrentSpeed and EstimatedSpeed are all forced to be arrays, since they sometimes have multiple values. 
                    [PSCustomObject]@{ 
                        Name           = $_.Name
                        Path           = Resolve-Path -Relative $_.Path
                        Type           = @($_.DeviceName)
                        Active         = "{0:dd} Days {0:hh} Hours {0:mm} Minutes" -f ((Get-Date).ToUniversalTime() - $_.BeginTime)
                        Algorithm      = @($_.Algorithm)
                        Pool           = @($_.Pool)
                        CurrentSpeed   = @($_.Speed_Live)
                        EstimatedSpeed = @($_.Speed)
                        PID            = @($_.ProcessID)
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

            Start-Sleep (30, $Config.ReportStatusInterval | Measure-Object -Maximum).Maximum

        }
        else {Start-Sleep 5}
    }
} While ($Config)

if ($Config) { 
    Write-Log "Miner status reporting process stopped. "
}
else { 
    Write-Log -Level Warn "Miner status reporting process exited due to missing config information. API down??? "
}