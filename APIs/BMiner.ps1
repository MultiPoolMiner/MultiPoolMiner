using module ..\Include.psm1

class BMiner : Miner {
    [PSCustomObject]GetMinerData ([Bool]$Safe = $false) {
        $MinerData = ([Miner]$this).GetMinerData($Safe)

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Delta = 0.05
        $Interval = 5
        $HashRates = @()

        $PowerDraws = @()
        $ComputeUsages = @()

        if ($this.index -eq $null -or $this.index -le 0) {

            # Supports max. 20 cards
            $Index = @()
            for ($i = 0; $i -le 20; $i++) {$Index += $i}               
        }
        else {
            $Index = $this.index
        }

        $URI = "http://$($Server):$($this.Port)/api/status"

        do {
            $HashRates += $HashRate = [PSCustomObject]@{}

            try {
                $Response = Invoke-WebRequest $URI -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
                $Data = $Response | ConvertFrom-Json -ErrorAction Stop
            }
            catch {
                Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                break
            }

            $HashRate_Value = 0
            $Index | Where {$Data.miners.$_.solver} | ForEach {
                $HashRate_Value += [Double]$Data.miners.$_.solver.solution_rate
            }

            $HashRate_Name = [String]$this.Algorithm[0]
            if ($this.Algorithm[0] -match ".+NiceHash") {
                $HashRate_Name = "$($HashRate_Name)Nicehash"
            }

            if ($HashRate_Name -and ($this.Algorithm -like (Get-Algorithm $HashRate_Name)).Count -eq 1) {
                $HashRate | Add-Member @{(Get-Algorithm $HashRate_Name) = [Int64]$HashRate_Value}
            }

            $this.Algorithm | Where-Object {-not $HashRate.$_} | ForEach-Object {break}

            if (-not $Safe) {break}

            Start-Sleep $Interval
        } while ($HashRates.Count -lt 6)

        $HashRate = [PSCustomObject]@{}
        $this.Algorithm | ForEach-Object {$HashRate | Add-Member @{$_ = [Int64]($HashRates.$_ | Measure-Object -Maximum -Minimum -Average | Where-Object {$_.Maximum - $_.Minimum -le $_.Average * $Delta}).Maximum}}
        $this.Algorithm | Where-Object {-not $HashRate.$_} | Select-Object -First 1 | ForEach-Object {$this.Algorithm | ForEach-Object {$HashRate.$_ = [Int]0}}

        $MinerData | Add-Member HashRate $HashRate -Force
        return $MinerData
    }
}
