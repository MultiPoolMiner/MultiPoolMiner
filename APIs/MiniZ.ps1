using module ..\Include.psm1

class MiniZ : Miner { 
    [String[]]UpdateMinerData () { 
        if ($this.GetStatus() -ne [MinerStatus]::Running) { return @() }

        $Server = "localhost"
        $Timeout = 5 #seconds

        $Request = '{ "id":"0", "method":"getstat" }'
        $Response = ""

        try { 
            $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch { 
            return @($Request, $Response)
        }

        $HashRate = [PSCustomObject]@{ }
        $Shares = [PSCustomObject]@{ }

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [Double]($Data.result.speed_sps | Measure-Object -Sum).Sum
        if (-not $HashRate_Value) { $HashRate_Value = [Double]($Data.result.sol_ps | Measure-Object -Sum).Sum } #fix

        $Shares_Accepted = [Int64]0
        $Shares_Rejected = [Int64]0

        if ($this.AllowedBadShareRatio) { 
            $Shares_Accepted = [Int64]($Data.result.accepted_shares | Measure-Object -Sum).Sum
            $Shares_Rejected = [Int64]($Data.result.rejected_shares | Measure-Object -Sum).Sum
            if ((-not $Shares_Accepted -and $Shares_Rejected -ge 3) -or ($Shares_Accepted -and ($Shares_Rejected * $this.AllowedBadShareRatio -gt $Shares_Accepted))) { 
                $this.SetStatus("Failed")
                $this.StatusMessage = " was stopped because of too many bad shares for algorithm $HashRate_Name (Total: $($Shares_Accepted + $Shares_Rejected), Rejected: $Shares_Rejected [Configured allowed ratio is 1:$(1 / $this.AllowedBadShareRatio)])"
                return @($Request, $Data | ConvertTo-Json -Depth 10 -Compress)
            }
            $Shares | Add-Member @{ $HashRate_Name = @($Shares_Accepted, $Shares_Rejected, $($Shares_Accepted + $Shares_Rejected)) }
        }

        if ($HashRate_Name) { 
            $HashRate | Add-Member @{ $HashRate_Name = [Double]$HashRate_Value }
        }

        if ($HashRate.PSObject.Properties.Value -gt 0) { 
            $this.Data += [PSCustomObject]@{ 
                Date       = (Get-Date).ToUniversalTime()
                Raw        = $Response
                HashRate   = $HashRate
                PowerUsage = (Get-PowerUsage $this.DeviceName)
                Shares     = $Shares
                Device     = @()
            }
        }

        return @($Request, $Data | ConvertTo-Json -Depth 10 -Compress)
    }
}
