using module ..\Include.psm1

class Claymore : Miner { 
    [String[]]UpdateMinerData () { 
        if ($this.GetStatus() -ne [MinerStatus]::Running) { return @() }

        $Server = "localhost"
        $Timeout = 5 #seconds

        $Request = @{ id = 1; jsonrpc = "2.0"; method = "miner_getstat1" } | ConvertTo-Json -Compress
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

        $HashRate_Name = [String]($this.Algorithm -match '^(' + [Regex]::Escape("$(Get-Algorithm ($Data.result[0] -split ' - ')[1])") + '(-.+|))$')[0]
        if (-not $HashRate_Name -and -not ($Data.result[0] -split ' - ')[1]) { $HashRate_Name = [String]($this.Algorithm -match '^(ethash(-.+|))$')[0] }
        if (-not $HashRate_Name -and -not ($Data.result[0] -split ' - ')[1]) { $HashRate_Name = [String]$this.Algorithm[0] }
        $HashRate_Value = [Double]($Data.result[2] -split ";")[0]
        if ($this.Algorithm -match '^(ethash(-.+|))$' -and $Data.result[0] -notmatch "^TT-Miner") { $HashRate_Value *= 1000 }
        if ($this.Algorithm -match '^(neoscrypt(-.+|))$') { $HashRate_Value *= 1000 }

        $Shares_Accepted = [Int64]0
        $Shares_Rejected = [Int64]0

        if ($this.AllowedBadShareRatio) { 
            $Shares_Accepted = [Int64]($Data.result[2] -split ";")[1]
            $Shares_Rejected = [Int64]($Data.result[2] -split ";")[2]
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

        if ($this.Algorithm -ne $HashRate_Name) { 
            $HashRate_Name = [String]($this.Algorithm -ne $HashRate_Name)[0]
            $HashRate_Value = [Double]($Data.result[4] -split ";")[0]
            if ($this.Algorithm -match '^(ethash(-.+|))$') { $HashRate_Value *= 1000 }
            if ($this.Algorithm -match '^(neoscrypt(-.+|))$') { $HashRate_Value *= 1000 }

            if ($this.AllowedBadShareRatio) { 
                $Shares_Accepted = [Int64]($Data.result[4] -split ";")[1]
                $Shares_Rejected = [Int64]($Data.result[4] -split ";")[2]
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
