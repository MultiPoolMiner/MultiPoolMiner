using module ..\Include.psm1

class BMiner : Miner {
    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 5 #seconds

        $Request = "http://$($Server):$($this.Port)/api/v1/status/solver"
        $Data = ""

        try {
            if ($Global:PSVersionTable.PSVersion -ge [System.Version]("6.0.0")) {
                $Data = Invoke-RestMethod $Request -TimeoutSec $Timeout -DisableKeepAlive -MaximumRetryCount 3 -RetryIntervalSec 1 -ErrorAction Stop
            }
            else {
                $Data = Invoke-RestMethod $Request -TimeoutSec $Timeout -DisableKeepAlive -ErrorAction Stop
            }
        }
        catch {
            return @($Request, $Data)
        }

        if ($this.AllowedBadShareRatio) {
            #Read stratum info from API
            try {
                if ($Global:PSVersionTable.PSVersion -ge [System.Version]("6.0.0")) {
                        $Data | Add-member stratums (Invoke-RestMethod "http://$($Server):$($this.Port)/api/v1/status/stratum" -TimeoutSec $Timeout -DisableKeepAlive -MaximumRetryCount 3 -RetryIntervalSec 1 -ErrorAction Stop).stratums
                }
                else {
                        $Data | Add-member stratums (Invoke-RestMethod "http://$($Server):$($this.Port)/api/v1/status/stratum" -TimeoutSec $Timeout -DisableKeepAlive -ErrorAction Stop).stratums
                }
            }
            catch {
                if ((Get-Date) -gt ($this.Process.PSBeginTime.AddSeconds($this.WarmupTime))) {$this.SetStatus("Failed")}
                return @($Request, $Data, "Reason: Could not retrieve data from API ")
            }
        }        

        $HashRate = [PSCustomObject]@{}
        $HashRate_Name = ""
        $HashRate_Value = 0

        $this.Algorithm | Select-Object -Unique | ForEach-Object {

            $HashRate_Name = [String]($this.Algorithm -like (Get-Algorithm $_))
            if (-not $HashRate_Name) {$HashRate_Name = [String]($this.Algorithm -like "$(Get-Algorithm $_)*")} #temp fix

            if ($this.AllowedBadShareRatio) {
                $Shares_Accepted = [Int64]$Data.stratums.$_.accepted_shares
                $Shares_Rejected = [Int64]$Data.stratums.$_.rejected_shares
                if ((-not $Shares_Accepted -and $Shares_Rejected -ge 3) -or ($Shares_Accepted -and ($Shares_Rejected * $this.AllowedBadShareRatio -gt $Shares_Accepted))) {
                    $this.SetStatus("Failed")
                    $this.StatusMessage = " was stopped because of too many bad shares for algorithm $($HashRate_Name) (total: $($Shares_Accepted + $Shares_Rejected) / bad: $($Shares_Rejected) [Configured allowed ratio is 1:$(1 / $this.AllowedBadShareRatio)])"
                    return @($Request, $Data)
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
                Raw        = $Data
                HashRate   = $HashRate
                PowerUsage = (Get-PowerUsage $this.DeviceName)
                Device     = @()
            }
        }

        return @($Request, $Data | ConvertTo-Json -Compress)
    }
}
