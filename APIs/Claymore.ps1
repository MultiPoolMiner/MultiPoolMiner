using module ..\Include.psm1

class Claymore : Miner {
    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = @{id = 1; jsonrpc = "2.0"; method = "miner_getstat1"} | ConvertTo-Json -Compress
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            if ((Get-Date) -gt ($this.Process.PSBeginTime.AddSeconds(30))) {$this.SetStatus("Failed")}
            return @($Request, $Response)
        }

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [Double]($Data.result[2] -split ";")[0]
        if ($this.Algorithm -like "ethash*" -and $Data.result[0] -notlike "TT-Miner*") {$HashRate_Value *= 1000}
        if ($this.Algorithm -eq "neoscrypt") {$HashRate_Value *= 1000}

        if ($HashRate_Name -and $HashRate_Value -GT 0) {$HashRate | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}}

        if ($this.Algorithm[1]) {
            $HashRate_Name = [String]$this.Algorithm[1]
            $HashRate_Value = [Double]($Data.result[4] -split ";")[0]
            if ($this.Algorithm -like "ethash*") {$HashRate_Value *= 1000}
            if ($this.Algorithm -eq "neoscrypt") {$HashRate_Value *= 1000}

            if ($HashRate_Name -and $HashRate_Value -GT 0) {$HashRate | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}}
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