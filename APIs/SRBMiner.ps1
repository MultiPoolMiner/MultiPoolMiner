using module ..\Include.psm1

class SRBMiner : Miner {
    
    hidden StartMining() {
        $this.Status = [MinerStatus]::Failed

        $this.New = $true
        $this.Activated++

        $Parameters = $this.Arguments | ConvertFrom-Json

        #Write config files. Keep separate files and do not overwrite to preserve optional manual customization
        $ConfigFile = "$(Split-Path $this.Path)\$($this.Name)-$($this.Algorithm)-Port$($this.Port).json"
        $Parameters.Config | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile -ErrorAction Ignore

        $Arguments = " --config $ConfigFile $($Parameters.CommandLine)"

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
            if ($this.ShowMinerWindow -and $this.API -ne "Wrapper") {
                $this.Process = Start-Job ([ScriptBlock]::Create("Start-Process $(@{desktop = "powershell"; core = "pwsh"}.$Global:PSEdition) `"-command ```$Process = (Start-Process '$($this.Path)' '$($Arguments)' -WorkingDirectory '$(Split-Path $this.Path)' -WindowStyle Minimized -PassThru).Id; Wait-Process -Id `$PID; Stop-Process -Id ```$Process`" -WindowStyle Hidden -Wait"))
            }
            else {
                $this.LogFile = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Logs\$($this.Name)-$($this.Port)_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt")
                $this.Process = Start-SubProcess -FilePath $this.Path -ArgumentList $Arguments -LogPath $this.LogFile -WorkingDirectory (Split-Path $this.Path) -Priority ($this.DeviceName | ForEach-Object {if ((Get-Device $_).Type -eq "CPU") {-2}else {-1}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum)
            }

            if ($this.Process | Get-Job -ErrorAction SilentlyContinue) {
                $this.Status = [MinerStatus]::Running
            }
        }
    }

    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""
     
        $HashRate = [PSCustomObject]@{}

        try {
            $Data = Invoke-RestMethod "http://$($Server):$($this.Port)" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        }
        catch {
            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
            return @($Request, $Response)
        }

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [Double]$Data.hashrate_total_now

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
