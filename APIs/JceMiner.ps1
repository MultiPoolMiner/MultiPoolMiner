using module ..\Include.psm1

class JceMiner : Miner {
    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 5 #seconds

        $Request = ""
        $Response = ""

        $Data = [PSCustomObject]@{}

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop            
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            if ((Get-Date) -gt ($this.Process.PSBeginTime.AddSeconds(30))) {$this.SetStatus("Failed")}
            return @($Request, $Response)
        }

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [Double]($Data.hashrate.total)

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

    hidden StopMining() {
        $this.Status = [MinerStatus]::Failed

        if ($this.ProcessId) {
            if (Get-Process -Id $this.ProcessId -ErrorAction SilentlyContinue) {
                Stop-Process -Id $this.ProcessId -Force -ErrorAction Ignore
                # Kill spawned process 'Attrib'
                Stop-Process -Id (Get-CIMInstance CIM_Process | Where-Object {($_.CommandLine -replace '"') -like ("*$($this.Path)*$($this.GetCommandLineParameters())*" -replace '"')}).ProcessId -Force -ErrorAction Ignore
            }
            $this.ProcessId = $null
        }

        if ($this.Process) {
            if ($this.Process | Get-Job -ErrorAction SilentlyContinue) {
                $this.Process | Remove-Job -Force
            }

            if (-not ($this.Process | Get-Job -ErrorAction SilentlyContinue)) {
                $this.Active += $this.Process.PSEndTime - $this.Process.PSBeginTime
                $this.Process = $null
                $this.Status = [MinerStatus]::Idle
            }
        }
    }
}
