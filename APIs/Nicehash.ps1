using module ..\Include.psm1

class Nicehash : Miner {
    hidden StartMining() {
        $this.Status = [MinerStatus]::Failed

        $this.New = $true
        $this.Activated++

        if ($this.Process) {
            if ($this.Process | Get-Job -ErrorAction SilentlyContinue) {
                $this.Process | Remove-Job -Force
            }

            if (-not ($this.Process | Get-Job -ErrorAction SilentlyContinue)) {
                $this.Active += $this.Process.PSEndTime - $this.Process.PSBeginTime
                $this.Process = $null
            }
        }

        if (-not $this.Process) {
            $this.Process = Start-Job ([ScriptBlock]::Create("Start-Process $(@{desktop = "powershell"; core = "pwsh"}.$Global:PSEdition) `"-command ```$Process = (Start-Process '$($this.Path)' '$($this.Arguments)' -WorkingDirectory '$(Split-Path $this.Path)' -WindowStyle Minimized -PassThru).Id; Wait-Process -Id `$PID; Stop-Process -Id ```$Process`" -WindowStyle Hidden -Wait"))

            if ($this.Process | Get-Job -ErrorAction SilentlyContinue) {
                $this.Status = [MinerStatus]::Running
            }
        }
    }

    [PSCustomObject]GetMinerData ([Bool]$Safe = $false) {
        $MinerData = ([Miner]$this).GetMinerData($Safe)

        if ($this.GetStatus() -ne [MinerStatus]::Running) {return $MinerData}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Delta = 0.05
        $Interval = 5
        $HashRates = @()

        $Request = @{id = 1; method = "algorithm.list"; params = @()} | ConvertTo-Json -Compress

        do {
            $HashRates += $HashRate = [PSCustomObject]@{}

            try {
                $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                $Data = $Response | ConvertFrom-Json -ErrorAction Stop
            }
            catch {
                Write-Log -Level Error  "Failed to connect to miner ($($this.Name)). "
                break
            }

            $Data.algorithms.name | Select-Object -Unique | ForEach-Object {
                $HashRate_Name = [String]($this.Algorithm -like (Get-Algorithm $_))
                if (-not $HashRate_Name) {$HashRate_Name = [String]($this.Algorithm -like "$(Get-Algorithm $_)*")} #temp fix
                $HashRate_Value = [Double](($Data.algorithms | Where-Object name -EQ $_).workers.speed | Measure-Object -Sum).Sum

                $HashRate | Where-Object {$HashRate_Name} | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}                
            }

            $this.Algorithm | Where-Object {-not $HashRate.$_} | ForEach-Object {break}

            if (-not $Safe) {break}

            Start-Sleep $Interval
        } while ($HashRates.Count -lt 6)

        $HashRate = [PSCustomObject]@{}
        $this.Algorithm | ForEach-Object {$HashRate | Add-Member @{$_ = [Int64]($HashRates.$_ | Measure-Object -Maximum -Minimum -Average | Where-Object {$_.Maximum - $_.Minimum -le $_.Average * $Delta}).Maximum}}
        $this.Algorithm | Where-Object {-not $HashRate.$_} | Select-Object -First 1 | ForEach-Object {$this.Algorithm | ForEach-Object {$HashRate.$_ = [Int64]0}}

        $MinerData | Add-Member HashRate $HashRate -Force
        return $MinerData
    }
}