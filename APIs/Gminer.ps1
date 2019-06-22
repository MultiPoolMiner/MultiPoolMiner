using module ..\Include.psm1

class Gminer : Miner {
    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 5 #seconds

        $Request = "http://$($Server):$($this.Port)/stat"
        $Response = ""

        try {
            $Response = Invoke-WebRequest $Request -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            return @($Request, $Response)
        }

        $HashRate = [PSCustomObject]@{}
        $HashRate_Name = [String]($this.Algorithm | Select-Object -Index 0)

        if ($this.AllowedBadShareRatio) {
            $Shares_Accepted = [Int64]($Data.gpu_status.good_shares | Measure-Object -Sum).Sum
            $Shares_Rejected = [Int64]($Data.gpu_status.bad_shares | Measure-Object -Sum).Sum
            if ((-not $Shares_Accepted -and $Shares_Rejected -ge 3) -or ($Shares_Accepted -and ($Shares_Rejected * $this.AllowedBadShareRatio -gt $Shares_Accepted))) {
                $this.SetStatus("Failed")
                $this.StatusMessage = " was stopped because of too many bad shares for algorithm $($HashRate_Name) (total: $($Shares_Accepted + $Shares_Rejected) / bad: $($Shares_Rejected) [Configured allowed ratio is 1:$(1 / $this.AllowedBadShareRatio)])"
                return @($Request, $Response)
            }
        }

        $HashRate | Add-Member @{$HashRate_Name = [Double]($Data.devices.speed | Measure-Object -Sum).Sum}

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
