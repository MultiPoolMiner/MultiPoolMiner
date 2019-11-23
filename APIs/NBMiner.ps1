using module ..\Include.psm1

class NBMiner : Miner { 
    [String[]]UpdateMinerData () { 
        if ($this.GetStatus() -ne [MinerStatus]::Running) { return @() }

        $Server = "localhost"
        $Timeout = 5 #seconds

        $Request = "http://$($Server):$($this.Port)/api/v1/status"
        $Response = ""

        try { 
            if ($Global:PSVersionTable.PSVersion -ge [System.Version]("6.2.0")) { 
                $Response = Invoke-WebRequest $Request -TimeoutSec $Timeout -DisableKeepAlive -MaximumRetryCount 3 -RetryIntervalSec 1 -ErrorAction Stop
            }
            else { 
                $Response = Invoke-WebRequest $Request -UseBasicParsing -TimeoutSec $Timeout -DisableKeepAlive -ErrorAction Stop
            }
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch { 
            return @($Request, $Response)
        }

        $HashRate = [PSCustomObject]@{ }
        $Shares = [PSCustomObject]@{ }

        $HashRate_Name = $this.Algorithm | Select-Object -Index 0
        $Shares_Accepted = [Int]0
        $Shares_Rejected = [Int]0

        if ($this.AllowedBadShareRatio) { 
            $Shares_Accepted = [Int64]$Data.stratum.accepted_shares
            $Shares_Rejected = [Int64]$Data.stratum.rejected_shares
            if ((-not $Shares_Accepted -and $Shares_Rejected -ge 3) -or ($Shares_Accepted -and ($Shares_Rejected * $this.AllowedBadShareRatio -gt $Shares_Accepted))) { 
                $this.SetStatus("Failed")
                $this.StatusMessage = " was stopped because of too many bad shares for algorithm $HashRate_Name (Total: $($Shares_Accepted + $Shares_Rejected), Rejected: $Shares_Rejected [Configured allowed ratio is 1:$(1 / $this.AllowedBadShareRatio)])"
                return @($Request, $Data)
            }
            $Shares | Add-Member @{ $HashRate_Name = @($Shares_Accepted, $Shares_Rejected, $($Shares_Accepted + $Shares_Rejected)) }
        }

        $HashRate | Add-Member @{ $HashRate_Name = [Double]$Data.miner.total_hashrate_raw }

        if ($Data.stratum.url2) { 
            $HashRate_Name = $this.Algorithm | Select-Object -Index 1
            $HashRate | Add-Member @{ $HashRate_Name = [Double]$Data.miner.total_hashrate2_raw }

            if ($this.AllowedBadShareRatio) { 
                $Shares_Accepted = [Int64]$Data.stratum.accepted_shares2
                $Shares_Rejected = [Int64]$Data.stratum.rejected_shares2
                if ((-not $Shares_Accepted -and $Shares_Rejected -ge 3) -or ($Shares_Accepted -and ($Shares_Rejected * $this.AllowedBadShareRatio -gt $Shares_Accepted))) { 
                    $this.SetStatus("Failed")
                    $this.StatusMessage = " was stopped because of too many bad shares for algorithm $HashRate_Name (Total: $($Shares_Accepted + $Shares_Rejected), Rejected: $Shares_Rejected [Configured allowed ratio is 1:$(1 / $this.AllowedBadShareRatio)])"
                    return @($Request, $Data | ConvertTo-Json -Depth 10 -Compress)
                }
                $Shares | Add-Member @{ $HashRate_Name = @($Shares_Accepted, $Shares_Rejected, $($Shares_Accepted + $Shares_Rejected)) }
            }
        }

        if ($HashRate.PSObject.Properties.Value -gt 0) { 
            $this.Data += [PSCustomObject]@{ 
                Date       = (Get-Date).ToUniversalTime()
                Raw        = $Data
                HashRate   = $HashRate
                PowerUsage = (Get-PowerUsage $this.DeviceName)
                Shares     = $Shares
                Device     = @()
            }
        }

        return @($Request, $Data | ConvertTo-Json -Depth 10 -Compress)
    }
}

