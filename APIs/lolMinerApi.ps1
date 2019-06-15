using module ..\Include.psm1

class lolMinerApi : Miner {
    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 5 #seconds

        $Request = ""
        $Response = ""

        $Data = [PSCustomObject]@{}

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/summary" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction SilentlyContinue
            $Data = $Response | ConvertFrom-Json -ErrorAction SilentlyContinue
        }
        catch {
            return @($Request, $Response)
        }

        $HashRate_Name = [String]($this.Algorithm | Select-Object -Index 0)

        if ($this.AllowedBadShareRatio) {
            $Shares_Accepted = [Int64]$Data.Session.Accepted
            $Shares_Rejected = [Int64]($Data.Session.Submitted - $Data.Session.Accepted)
            if ((-not $Shares_Accepted -and $Shares_Rejected -ge 3) -or ($Shares_Accepted -and ($Shares_Rejected * $this.AllowedBadShareRatio -gt $Shares_Accepted))) {
                $this.SetStatus("Failed")
                $this.StatusMessage = " was stopped because of too many bad shares for algorithm $($HashRate_Name) (total: $($Shares_Accepted + $Shares_Rejected) / bad: $($Shares_Rejected) [Configured allowed ratio is 1:$(1 / $this.AllowedBadShareRatio)])"
                return @($Request, $Response)
            }
        }

        $HashRate | Add-Member @{$HashRate_Name = [Double]$data.Session.Performance_Summary}

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