using module ..\Include.psm1

class Eminer : Miner {
    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/api/v1/stats" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
            return @($Request, $Response)
        }

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [Double]($Data.devices.hashrate_1m | Measure-Object -Sum).Sum

        $HashRate | Where-Object {$HashRate_Name} | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}

        $this.Data += [PSCustomObject]@{
            Date     = (Get-Date).ToUniversalTime()
            Raw      = $Response
            HashRate = $HashRate
            Device   = @()
        }

        return @($Request, $Data | ConvertTo-Json -Compress)
    }
}