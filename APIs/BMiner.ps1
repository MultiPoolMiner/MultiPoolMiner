using module ..\Include.psm1

class BMiner : Miner {
    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 5 #seconds

        $Request = "http://$($Server):$($this.Port)/api/v1/status/solver"
        $Request2 = "http://$($Server):$($this.Port)/api/v1/status/stratum"
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

        if ($this.AllowedBadShareRatio) {
            #Read stratum info from API
            try {
                if ($Global:PSVersionTable.PSVersion -ge [System.Version]("6.2.0")) {
                    $Data | Add-member stratums (Invoke-WebRequest $Request2 -TimeoutSec $Timeout -DisableKeepAlive -MaximumRetryCount 3 -RetryIntervalSec 1 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop).stratums
                }
                else {
                    $Data | Add-member stratums (Invoke-WebRequest $Request2 -TimeoutSec $Timeout -UseBasicParsing -DisableKeepAlive -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop).stratums
                }
            }
            catch {
                return @($Request, $Data)
            }
        }

        $HashRate = [PSCustomObject]@{}
        $HashRate_Name = ""
        $HashRate_Value = [Double]0
        $Shares_Accepted = [Int]0
        $Shares_Rejected = [Int]0

        $Data.devices | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Data.devices.$_.solvers | ForEach-Object {$_.Algorithm}} | Select-Object -Unique | ForEach-Object {
            $Algorithm = $_
            $HashRate_Name = Get-Algorithm $Algorithm
            $HashRate_Value = [Double]0

            if ($this.AllowedBadShareRatio) {
                $Shares_Accepted = [Int64]$Data.stratums.$Algorithm.accepted_shares
                $Shares_Rejected = [Int64]$Data.stratums.$Algorithm.rejected_shares
                if ((-not $Shares_Accepted -and $Shares_Rejected -ge 3) -or ($Shares_Accepted -and ($Shares_Rejected * $this.AllowedBadShareRatio -gt $Shares_Accepted))) {
                    $this.SetStatus("Failed")
                    $this.StatusMessage = " was stopped because of too many bad shares for algorithm $HashRate_Name (total: $($Shares_Accepted + $Shares_Rejected) / bad: $Shares_Rejected [Configured allowed ratio is 1:$(1 / $this.AllowedBadShareRatio)])"
                    return @($Request, $Data | ConvertTo-Json -Depth 10 -Compress)
                }
            }

            $Data.devices | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {
                $Data.devices.$_.solvers | Where-Object {$_.Algorithm -eq $Algorithm} | ForEach-Object {
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
                Shares     = @($Shares_Accepted, $Shares_Rejected, $($Shares_Accepted + $Shares_Rejected))
                Device     = @()
            }
        }

        return @($Request, $Data | ConvertTo-Json -Depth 10 -Compress)
    }
}
