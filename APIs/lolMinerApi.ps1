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
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/summary" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop            
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            if ((Get-Date) -gt ($this.Process.PSBeginTime.AddSeconds(30))) {$this.SetStatus("Failed")}
            return @($Request, $Response)
        }

        $HashRate_Name = Get-Algorithm($data.Mining.Algorithm -replace "/")
        $HashRate_Value = [Double]$data.Session.Performance_Summary

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}
        }

        if ($HashRate | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) {
            $this.Data += [PSCustomObject]@{
                Date     = (Get-Date).ToUniversalTime()
                Raw      = $Response
                HashRate = $HashRate
                Device   = @()
            }
        }

        return @($Request, $Data | ConvertTo-Json -Compress)
    }
}