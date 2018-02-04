using module ..\Include.psm1

class Wrapper : Miner {
    StartMining() {
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
            $this.Process = Start-SubProcess -FilePath (@{desktop = "powershell"; core = "pwsh"}.$Global:PSEdition) -ArgumentList "-executionpolicy bypass -command . '$(Convert-Path ".\Wrapper.ps1")' -ControllerProcessID $Global:PID -Id '$($this.Port)' -FilePath '$($this.Path)' -ArgumentList '$($this.Arguments)' -WorkingDirectory '$(Split-Path $this.Path)'" -LogPath ([System.IO.Path]::GetFullPath(".\Logs\$($this.Name)-$($this.Port)_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss")")) -WorkingDirectory (Split-Path $this.Path) -Priority ($this.Type | ForEach-Object {if ($this -eq "CPU") {-2}else {-1}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum)

            if ($this.Process | Get-Job -ErrorAction SilentlyContinue) {
                $this.Status = [MinerStatus]::Running
            }
        }
    }

    [PSCustomObject]GetMinerData ([String[]]$Algorithm, [Bool]$Safe = $false) {
        $MinerData = ([Miner]$this).GetMinerData($Algorithm, $Safe)

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Delta = 0.05
        $Interval = 5
        $HashRates = @()

        $Request = ""

        do {
            $HashRates += $HashRate = [PSCustomObject]@{}

            try {
                try {
                    $Response = Get-Content ".\Wrapper\$($this.Port).txt" -Force -ErrorAction Stop
                    $Data = $Response | ConvertFrom-Json -ErrorAction Stop
                }
                catch {
                    Start-Sleep $Interval
                    $Response = Get-Content ".\Wrapper\$($this.Port).txt" -Force -ErrorAction Stop
                    $Data = $Response | ConvertFrom-Json -ErrorAction Stop
                }
            }
            catch {
                Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                break
            }

            $HashRate_Name = [String]$Algorithm[0]
            $HashRate_Value = [Double]$Data

            $HashRate | Where-Object {$HashRate_Name} | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}

            $Algorithm | Where-Object {-not $HashRate.$_} | ForEach-Object {break}

            if (-not $Safe) {break}

            Start-Sleep $Interval
        } while ($HashRates.Count -lt 6)

        $HashRate = [PSCustomObject]@{}
        $Algorithm | ForEach-Object {$HashRate | Add-Member @{$_ = [Int64]($HashRates.$_ | Measure-Object -Maximum -Minimum -Average | Where-Object {$_.Maximum - $_.Minimum -le $_.Average * $Delta}).Maximum}}
        $Algorithm | Where-Object {-not $HashRate.$_} | Select-Object -First 1 | ForEach-Object {$Algorithm | ForEach-Object {$HashRate.$_ = [Int64]0}}

        $MinerData | Add-Member HashRate $HashRate -Force
        return $MinerData
    }
}