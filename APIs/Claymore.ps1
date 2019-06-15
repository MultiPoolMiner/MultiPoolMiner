﻿using module ..\Include.psm1

class Claymore : Miner {
    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 5 #seconds

        $Request = @{id = 1; jsonrpc = "2.0"; method = "miner_getstat1"} | ConvertTo-Json -Compress
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            return @($Request, $Response)
        }

        $HashRate_Name = [String]($this.Algorithm | Select-Object -Index 0)

        if ($this.AllowedBadShareRatio) {
            $Shares_Accepted = [Int64]($Data.result[2] -split ";")[1]
            $Shares_Rejected = [Int64]($Data.result[2] -split ";")[2]
            if ((-not $Shares_Accepted -and $Shares_Rejected -ge 3) -or ($Shares_Accepted -and ($Shares_Rejected * $this.AllowedBadShareRatio -gt $Shares_Accepted))) {
                $this.SetStatus("Failed")
                $this.StatusMessage = " was stopped because of too many bad shares for algorithm $($HashRate_Name) (total: $($Shares_Accepted + $Shares_Rejected) / bad: $($Shares_Rejected) [Configured allowed ratio is 1:$(1 / $this.AllowedBadShareRatio)])"
                return @($Request, $Response)
            }
        }

        $HashRate_Value = [Double]($Data.result[2] -split ";")[0]
        if ($this.Algorithm -like "ethash*" -and $Data.result[0] -notlike "TT-Miner*") {$HashRate_Value *= 1000}
        if ($this.Algorithm -eq "neoscrypt") {$HashRate_Value *= 1000}
        $HashRate | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}

        if ($this.Algorithm | Select-Object -Index 1) {
            $HashRate_Name = [String]($this.Algorithm | Select-Object -Index 1)

            $Shares_Accepted = [Int64]($Data.result[4] -split ";")[1]
            $Shares_Rejected = [Int64]($Data.result[4] -split ";")[2]
            if ($this.AllowedBadShareRatio -and ((-not $Shares_Accepted -and $Shares_Rejected -ge 3) -or ($Shares_Accepted -and ($Shares_Rejected * $this.AllowedBadShareRatio -gt $Shares_Accepted)))) {
                $this.SetStatus("Failed")
                $this.StatusMessage = " was stopped because of too many bad shares for algorithm $($HashRate_Name) (total: $($Shares_Accepted + $Shares_Rejected) / bad: $($Shares_Rejected) [Configured allowed ratio is 1:$(1 / $this.AllowedBadShareRatio)])"
                return @($Request, $Response)
            }

            $HashRate_Value = [Double]($Data.result[4] -split ";")[0]
            if ($this.Algorithm -like "ethash*") {$HashRate_Value *= 1000}
            if ($this.Algorithm -eq "neoscrypt") {$HashRate_Value *= 1000}
            $HashRate | Add-Member @{$HashRate_Name = [Double]$HashRate_Value}
        }

        if ($HashRate.PSObject.Properties.Value -gt 0) {
            $this.Data += [PSCustomObject]@{
                Date       = (Get-Date).ToUniversalTime()
                Raw        = $Response
                HashRate   = $HashRate
                PowerUsage = (Get-PowerUsage $this.DeviceName)
                Device     = @()
            }
        }

        return @($Request, $Data | ConvertTo-Json -Compress)
    }
}