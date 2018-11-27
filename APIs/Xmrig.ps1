using module ..\Include.psm1

class XmRig : Miner {

    [String]GetCommandLineParameters() {
        try {
            return ($this.Arguments | ConvertFrom-Json -ErrorAction SilentlyContinue).Commands
        }
        catch {
            return $this.Arguments
        }    
        
    }
    
    hidden StartMining() {
        $this.Status = [MinerStatus]::Failed

        $this.New = $true
        $this.Activated++

        $Parameters = [PSCustomObject]@{}
        try {
            $Parameters = $this.Arguments | ConvertFrom-Json -ErrorAction SilentlyContinue

            $ConfigFile = "$(Split-Path $this.Path)\$($Parameters.ConfigFile.FileName)"
            $ThreadsConfig = [PSCustomObject]@{}

            if (-not $Parameters.ConfigFile.Content.threads) {
                #Existing complete config file with threads info?
                if (Test-Path $ConfigFile -PathType Leaf) {
                    $ThreadsConfig = (Get-Content $ConfigFile | ConvertFrom-Json -ErrorAction SilentlyContinue).threads
                }
                if (-not $ThreadsConfig.Count) {
                    #Check if we have a valid hw file for all installed hardware (hardware changed, deviceIDs changed?). Thread info depends on algo.
                    $ThreadsConfigFile = "$(Split-Path $this.Path)\$($Parameters.ThreadsConfigFileName)"
                    if (Test-Path $ThreadsConfigFile -PathType Leaf) {
                        $ThreadsConfig = Get-Content $ThreadsConfigFile | ConvertFrom-Json -ErrorAction SilentlyContinue
                    }
                    if (($ThreadsConfig.index).Count -le 1) {
                        #Temporarily start miner with pre-config file (without threads config). Miner will then update hw config file with threads info
                        $Parameters.ConfigFile.Content | ConvertTo-Json -Depth 10 | Set-Content $ThreadsConfigFile -ErrorAction SilentlyContinue -Force
                        $this.Process = Start-Job ([ScriptBlock]::Create("Start-Process $(@{desktop = "powershell"; core = "pwsh"}.$Global:PSEdition) `"-command ```$Process = (Start-Process '$($this.Path)' '$($Parameters.HwDetectCommands)' -WorkingDirectory '$(Split-Path $this.Path)' -WindowStyle Minimized -PassThru).Id; Wait-Process -Id `$PID; Stop-Process -Id ```$Process`" -WindowStyle Hidden -Wait"))
                        if ($this.Process | Get-Job -ErrorAction SilentlyContinue) {
                            for ($WaitForThreadsConfig = 0; $WaitForThreadsConfig -le 360; $WaitForThreadsConfig++) {
                                if ($ThreadsConfig = (Get-Content $ThreadsConfigFile | ConvertFrom-Json -ErrorAction SilentlyContinue).threads) {
                                    $ThreadsConfig | ConvertTo-Json -Depth 10 | Set-Content $ThreadsConfigFile -ErrorAction SilentlyContinue -Force
                                    break
                                }
                                Start-Sleep -Milliseconds 100
                            }
                            $this.Process | Remove-Job -Force
                            $this.Process = $null
                        }
                    }
                    #Write config files. Overwrite because we need to add thread info
                    $Parameters.ConfigFile.Content | Add-Member threads ([Array](($ThreadsConfig | Where-Object {$Parameters.Devices -contains $_.index}) | Select-Object -Unique) * $Parameters.Threads) -Force
                    $Parameters.ConfigFile.Content | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile -ErrorAction SilentlyContinue -Force
                }
            }
            else {    
                #Write config files. Keep separate files and do not overwrite to preserve optional manual customization
                $Parameters.ConfigFile.Content | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile -ErrorAction SilentlyContinue
            }
        }
        catch {}

        if ($this.Process) {
            if ($this.Process | Get-Job -ErrorAction SilentlyContinue) {
                $this.Process | Remove-Job -Force
            }

            if ($this.ProcessId) {
                if (Get-Process -Id $this.ProcessId) {Stop-Process -Id $this.ProcessId -Force -ErrorAction Ignore}
                $this.ProcessId = $null
            }

            if (-not ($this.Process | Get-Job -ErrorAction SilentlyContinue)) {
                $this.Active += $this.Process.PSEndTime - $this.Process.PSBeginTime
                $this.Process = $null
            }
        }

        if (-not $this.Process) {
            if ($this.ShowMinerWindow) {
                $this.Process = Start-Job ([ScriptBlock]::Create("Start-Process $(@{desktop = "powershell"; core = "pwsh"}.$Global:PSEdition) `"-command ```$Process = (Start-Process '$($this.Path)' '$($this.GetCommandLineParameters())' -WorkingDirectory '$(Split-Path $this.Path)' -WindowStyle Minimized -PassThru).Id; Wait-Process -Id `$PID; Stop-Process -Id ```$Process`" -WindowStyle Hidden -Wait"))
            }
            else {
                $this.LogFile = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Logs\$($this.Name)-$($this.Port)_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt")
                $this.Process = Start-SubProcess -FilePath $this.Path -ArgumentList $($this.GetCommandLineParameters()) -LogPath $this.LogFile -WorkingDirectory (Split-Path $this.Path) -Priority ($this.DeviceName | ForEach-Object {if ((Get-Device $_).Type -eq "CPU") {-2}else {-1}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum)
            }

            if ($this.Process | Get-Job -ErrorAction SilentlyContinue) {
                for ($WaitForPID = 0; $WaitForPID -le 20; $WaitForPID++) {
                    if ($this.ProcessId = (Get-CIMInstance CIM_Process | Where-Object {$_.ExecutablePath -eq $this.Path -and $_.CommandLine -like "*$($this.Path)*$($this.GetCommandLineParameters())*"}).ProcessId) {
                        $this.Status = [MinerStatus]::Running
                        break
                    }
                    Start-Sleep -Milliseconds 100
                }
            }
        }
    }
    
    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 5 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/api.json" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            if ((Get-Date) -gt ($this.Process.PSBeginTime.AddSeconds(30))) {$this.SetStatus("Failed")}
            return @($Request, $Response)
        }

        $HashRate_Name = [String]($this.Algorithm -like (Get-Algorithm $Data.algo))
        if (-not $HashRate_Name) {$HashRate_Name = [String]($this.Algorithm -like "$(Get-Algorithm $Data.algo)*")} #temp fix
        if (-not $HashRate_Name) {$HashRate_Name = [String]$this.Algorithm[0]} #fireice fix
        $HashRate_Value = [Int64]$Data.hashrate.total[0]
        if (-not $HashRate_Value) {$HashRate_Value = [Int64]$Data.hashrate.total[1]} #fix
        if (-not $HashRate_Value) {$HashRate_Value = [Int64]$Data.hashrate.total[2]} #fix

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
