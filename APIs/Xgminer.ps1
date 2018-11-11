using module ..\Include.psm1

class Xgminer : Miner {
    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = @{command = "summary"; parameter = ""} | ConvertTo-Json -Compress
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
            $Data = $Response.Substring($Response.IndexOf("{"), $Response.LastIndexOf("}") - $Response.IndexOf("{") + 1) -replace " ", "_" | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            if ((Get-Date) -gt ($this.Process.PSBeginTime.AddSeconds(30))) {Write-Log -Level Error "Failed to connect to miner ($($this.Name)) [ProcessId: $($this.ProcessId)]. "}
            return @($Request, $Response)
        }

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = if ($Data.SUMMARY.HS_5s) {[Double]$Data.SUMMARY.HS_5s * [Math]::Pow(1000, 0)}
        elseif ($Data.SUMMARY.KHS_5s) {[Double]$Data.SUMMARY.KHS_5s * [Math]::Pow(1000, 1)}
        elseif ($Data.SUMMARY.MHS_5s) {[Double]$Data.SUMMARY.MHS_5s * [Math]::Pow(1000, 2)}
        elseif ($Data.SUMMARY.GHS_5s) {[Double]$Data.SUMMARY.GHS_5s * [Math]::Pow(1000, 3)}
        elseif ($Data.SUMMARY.THS_5s) {[Double]$Data.SUMMARY.THS_5s * [Math]::Pow(1000, 4)}
        elseif ($Data.SUMMARY.PHS_5s) {[Double]$Data.SUMMARY.PHS_5s * [Math]::Pow(1000, 5)}
        elseif ($Data.SUMMARY.HS_av) {[Double]$Data.SUMMARY.HS_av * [Math]::Pow(1000, 0)}
        elseif ($Data.SUMMARY.KHS_av) {[Double]$Data.SUMMARY.KHS_av * [Math]::Pow(1000, 1)}
        elseif ($Data.SUMMARY.MHS_av) {[Double]$Data.SUMMARY.MHS_av * [Math]::Pow(1000, 2)}
        elseif ($Data.SUMMARY.GHS_av) {[Double]$Data.SUMMARY.GHS_av * [Math]::Pow(1000, 3)}
        elseif ($Data.SUMMARY.THS_av) {[Double]$Data.SUMMARY.THS_av * [Math]::Pow(1000, 4)}
        elseif ($Data.SUMMARY.PHS_av) {[Double]$Data.SUMMARY.PHS_av * [Math]::Pow(1000, 5)}

        if ($HashRate_Name -and $HashRate_Value -GT 0) {$HashRate | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}}

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