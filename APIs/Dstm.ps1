using module ..\Include.psm1

class Dstm : Miner {
    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 5 #seconds

        $Request = @{id = 1; method = "getstat"} | ConvertTo-Json -Compress
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
            $Shares_Accepted = [Double]($Data.result.accepted_shares | Measure-Object -Sum).Sum
            $Shares_Rejected = [Double]($Data.result.rejected_shares | Measure-Object -Sum).Sum
            if ((-not $Shares_Accepted -and $Shares_Rejected -ge 3) -or ($Shares_Accepted -and ($Shares_Rejected * $this.AllowedBadShareRatio -gt $Shares_Accepted))) {
                $this.SetStatus("Failed")
                $this.StatusMessage = " was stopped because of too many bad shares for algorithm $($HashRate_Name) (total: $($Shares_Accepted + $Shares_Rejected) / bad: $($Shares_Rejected) [Configured allowed ratio is 1:$(1 / $this.AllowedBadShareRatio)])"
                return @($Request, $Response)
            }
        }

        $HashRate_Value = [Double]($Data.result.sol_ps | Measure-Object -Sum).Sum
        if (-not $HashRate_Value) {$HashRate_Value = [Double]($Data.result.speed_sps | Measure-Object -Sum).Sum} #ewbf fix
        $HashRate | Add-Member @{$HashRate_Name = [Double]$HashRate_Value}

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
