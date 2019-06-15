using module ..\Include.psm1

class BMiner : Miner {
    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 5 #seconds

        $Request = ""
        $Response = ""

        $HashRate_Name = ""
        $HashRate_Value = 0
        $HashRate = [PSCustomObject]@{}
        try {
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/api/v1/status/solver" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            return @($Request, $Response)
        }

        if ($this.AllowedBadShareRatio) {
            #Read stratum info from API
            try {
                $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/api/v1/status/stratum" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
                $Data | Add-member stratums ($Response | ConvertFrom-Json -ErrorAction Stop).stratums
            }
            catch {
                if ((Get-Date) -gt ($this.Process.PSBeginTime.AddSeconds($this.WarmupTime))) {$this.SetStatus("Failed")}
                return @($Request, $Response, "Reason: Could not retrieve data from API ")
            }
        }        

        $this.Algorithm | Select-Object -Unique | ForEach-Object {

            $HashRate_Name = [String]($this.Algorithm -like (Get-Algorithm $_))
            if (-not $HashRate_Name) {$HashRate_Name = [String]($this.Algorithm -like "$(Get-Algorithm $_)*")} #temp fix

            if ($this.AllowedBadShareRatio) {
                $Shares_Accepted = [Int64]$Data.stratums.$_.accepted_shares
                $Shares_Rejected = [Int64]$Data.stratums.$_.rejected_shares
                if ((-not $Shares_Accepted -and $Shares_Rejected -ge 3) -or ($Shares_Accepted -and ($Shares_Rejected * $this.AllowedBadShareRatio -gt $Shares_Accepted))) {
                    $this.SetStatus("Failed")
                    $this.StatusMessage = " was stopped because of too many bad shares for algorithm $($HashRate_Name) (total: $($Shares_Accepted + $Shares_Rejected) / bad: $($Shares_Rejected) [Configured allowed ratio is 1:$(1 / $this.AllowedBadShareRatio)])"
                    return @($Request, $Response)
                }
            }

            $HashRate_Value = 0
            $Data.devices | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {
                $Data.devices.$_.solvers | Where-Object {$HashRate_Name -like "$(Get-Algorithm $_.Algorithm)*"} | ForEach-Object {
                    if ($_.speed_info.hash_rate) {$HashRate_Value += [Double]$_.speed_info.hash_rate}
                    else {$HashRate_Value += [Double]$_.speed_info.solution_rate}
                }
            }
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
