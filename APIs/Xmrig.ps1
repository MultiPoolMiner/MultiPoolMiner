using module ..\Include.psm1

class XmRig : Miner {
    [String]GetCommandLineParameters() {
        if ($this.Arguments -like "{*}") {
            return ($this.Arguments | ConvertFrom-Json -ErrorAction SilentlyContinue).Commands
        }
        else {
            return $this.Arguments
        }    
        
    }
    
    hidden StartMining() {
        $this.Status = [MinerStatus]::Failed

        $this.New = $true
        $this.Activated++

        if ($this.Arguments -like "{*}") {
            $Parameters = $this.Arguments | ConvertFrom-Json -ErrorAction SilentlyContinue

            try {
                $ConfigFile = "$(Split-Path $this.Path)\$($Parameters.ConfigFile.FileName)"

                $ThreadsConfig = [PSCustomObject]@{}
                $ThreadsConfigFile = "$(Split-Path $this.Path)\$($Parameters.ThreadsConfigFileName)"

                if ($Parameters.ConfigFile.Content.threads) {
                    #Write full config file, ignore possible hw change
                    $Parameters.ConfigFile.Content | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile -ErrorAction SilentlyContinue -Force
                }
                else {
                    #Check if we have a valid hw file for all installed hardware. If hardware / device order has changed we need to re-create the config files.
                    $ThreadsConfig = Get-Content $ThreadsConfigFile -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
                    if ($ThreadsConfig.Count -lt 1) {
                        if (Test-Path "$(Split-Path $this.Path)\$($this.Algorithm[0])-*.json" -PathType Leaf) {
                            #Remove old config files, thread info is no longer valid
                            Write-Log -Level Warn "Hardware change detected. Deleting existing configuration files for miner ($($this.Name) {$($this.Algorithm[0] -replace 'NiceHash')@$($this.Pool[0])}). "
                            Remove-Item "$(Split-Path $this.Path)\ThreadsConfig-$($this.Algorithm[0])-*.json" -Force -ErrorAction SilentlyContinue
                        }
                        #Temporarily start miner with pre-config file (without threads config). Miner will then update hw config file with threads info
                        $Parameters.ConfigFile.Content | ConvertTo-Json -Depth 10 | Set-Content $ThreadsConfigFile -Force
                        if ((Test-Path ".\CreateProcess.cs" -PathType Leaf) -and ($this.API -ne "Wrapper")) {
                            $this.Process = Start-SubProcessWithoutStealingFocus -FilePath $this.Path -ArgumentList $Parameters.HwDetectCommands -WorkingDirectory (Split-Path $this.Path) -Priority ($this.DeviceName | ForEach-Object {if ($_ -like "CPU#*") {-2} else {-1}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -EnvBlock $this.Environment
                        }
                        else {
                            $EnvCmd = ($this.Environment | ForEach-Object {"```$env:$($_)"}) -join "; "
                            $this.Process = Start-Job ([ScriptBlock]::Create("Start-Process $(@{desktop = "powershell"; core = "pwsh"}.$Global:PSEdition) `"-command $EnvCmd```$Process = (Start-Process '$($this.Path)' '$($Parameters.HwDetectCommands)' -WorkingDirectory '$(Split-Path $this.Path)' -WindowStyle Minimized -PassThru).Id; Wait-Process -Id `$PID; Stop-Process -Id ```$Process`" -WindowStyle Hidden -Wait"))
                        }
                        if ($this.Process | Get-Job -ErrorAction SilentlyContinue) {
                            for ($WaitForPID = 0; $WaitForPID -le 20; $WaitForPID++) {
                                if ($this.ProcessId = (Get-CIMInstance CIM_Process | Where-Object {$_.ExecutablePath -eq $this.Path -and $_.CommandLine -like "*$($this.Path)*$($Parameters.HwDetectCommands)*"}).ProcessId) {
                                    $this.Status = [MinerStatus]::Running
                                    break
                                }
                                Start-Sleep -Milliseconds 100
                            }
                            for ($WaitForThreadsConfig = 0; $WaitForThreadsConfig -le 60; $WaitForThreadsConfig++) {
                                if ($ThreadsConfig = @(Get-Content $ThreadsConfigFile -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue).threads) {
                                    if ($this.DeviceName -like "GPU*") {
                                        ConvertTo-Json -InputObject @($ThreadsConfig | Sort-Object -Property Index -Unique) -Depth 10 | Set-Content $ThreadsConfigFile -ErrorAction SilentlyContinue -Force
                                    }
                                    else {
                                        ConvertTo-Json -InputObject @($ThreadsConfig| Select-Object -Unique) -Depth 10 | Set-Content $ThreadsConfigFile -ErrorAction SilentlyContinue -Force
                                    }
                                    break
                                }
                                Start-Sleep -Milliseconds 500
                            }
                            $this.StopMining()
                        }
                        else {
                            Write-Log -Level Error "Running temporary miner failed - cannot create threads config file ($($this.Name) {$($this.Algorithm[0] -replace 'NiceHash')@$($this.Pool[0])}) [Error: '$($Error[0])']. "
                            return
                        }
                    }

                    if (-not ((Get-Content $ConfigFile -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue).threads)) {
                        #Threads config in config file is invalid, retrieve from threads config file
                        $ThreadsConfig = Get-Content $ThreadsConfigFile | ConvertFrom-Json
                        if ($ThreadsConfig.Count -ge 1) {
                            #Write config files. Overwrite because we need to add thread info
                            if ($this.DeviceName -like "GPU*") {
                                $Parameters.ConfigFile.Content | Add-Member threads ([Array](($ThreadsConfig | Where-Object {$Parameters.Devices -contains $_.index})) * $Parameters.Threads) -Force
                            }
                            else {
                                #CPU thread config does not contain index information
                                $Parameters.ConfigFile.Content | Add-Member threads ([Array]($ThreadsConfig * $Parameters.Threads)) -Force
                            }
                            $Parameters.ConfigFile.Content | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile -Force
                        }
                        else {
                            Write-Log -Level Error "Error parsing threads config file - cannot create miner config file ($($this.Name) {$($this.Algorithm[0] -replace 'NiceHash')@$($this.Pool[0])}) [Error: '$($Error[0])']. "
                            return
                        }                
                    }
                }
            }
            catch {
                Write-Log -Level Error "Creating miner config files failed ($($this.Name) {$($this.Algorithm[0] -replace 'NiceHash')@$($this.Pool[0])}) [Error: '$($Error[0])']. "
                return
            }
            
        }

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
                if ((Test-Path ".\CreateProcess.cs" -PathType Leaf) -and ($this.API -ne "Wrapper")) {
                    $this.Process = Start-SubProcessWithoutStealingFocus -FilePath $this.Path -ArgumentList $this.GetCommandLineParameters() -WorkingDirectory (Split-Path $this.Path) -Priority ($this.DeviceName | ForEach-Object {if ($_ -like "CPU#*") {-2} else {-1}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -EnvBlock $this.Environment
                }
                else {
                    $EnvCmd = ($this.Environment | ForEach-Object {"```$env:$($_)"}) -join "; "
                    $this.Process = Start-Job ([ScriptBlock]::Create("Start-Process $(@{desktop = "powershell"; core = "pwsh"}.$Global:PSEdition) `"-command $EnvCmd```$Process = (Start-Process '$($this.Path)' '$($this.GetCommandLineParameters())' -WorkingDirectory '$(Split-Path $this.Path)' -WindowStyle Minimized -PassThru).Id; Wait-Process -Id `$PID; Stop-Process -Id ```$Process`" -WindowStyle Hidden -Wait"))
                }
            }
            else {
                $this.LogFile = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Logs\$($this.Name)-$($this.Port)_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt")
                $this.Process = Start-SubProcess -FilePath $this.Path -ArgumentList (($this.GetCommandLineParameters() -replace '\(', '`(') -replace '\)', '`)') -LogPath $this.LogFile -WorkingDirectory (Split-Path $this.Path) -Priority ($this.DeviceName | ForEach-Object {if ($_ -like "CPU#*") {-2} else {-1}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -EnvBlock $this.Environment
            }

            if ($this.Process | Get-Job -ErrorAction SilentlyContinue) {
                for ($WaitForPID = 0; $WaitForPID -le 20; $WaitForPID++) {
                    if ($this.ProcessId = (Get-CIMInstance CIM_Process | Where-Object {$_.ExecutablePath -eq $this.Path} | Where-Object {$_.CommandLine -like ("*$($this.Path)*$($this.GetCommandLineParameters())*")}).ProcessId) {
                        $this.Status = [MinerStatus]::Running
                        $this.BeginTime = (Get-Date).ToUniversalTime()
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

        $Request = "http://$($Server):$($this.Port)/api.json"
        $Response = ""

        try {
            if ($Global:PSVersionTable.PSVersion -ge [System.Version]("6.2.0")) {
                $Response = Invoke-WebRequest $Request -TimeoutSec $Timeout -DisableKeepAlive -MaximumRetryCount 3 -RetryIntervalSec 1 -ErrorAction Stop
            }
            else {
                $Response = Invoke-WebRequest $Request -UseBasicParsing -TimeoutSec $Timeout -DisableKeepAlive -ErrorAction Stop
            }
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            return @($Request, $Response)
        }

        $HashRate = [PSCustomObject]@{}
        $HashRate_Name = [String]($this.Algorithm | Select-Object -Index 0)
        $Shares_Accepted = [Int]0
        $Shares_Rejected = [Int]0

        if ($this.AllowedBadShareRatio) {
            $Shares_Accepted = [Double]$Data.results.shares_good
            $Shares_Rejected = [Double]($Data.results.shares_total - $Data.results.shares_good)
            if ((-not $Shares_Accepted -and $Shares_Rejected -ge 3) -or ($Shares_Accepted -and ($Shares_Rejected * $this.AllowedBadShareRatio -gt $Shares_Accepted))) {
                $this.SetStatus("Failed")
                $this.StatusMessage = " was stopped because of too many bad shares for algorithm $HashRate_Name (total: $($Shares_Accepted + $Shares_Rejected) / bad: $($Shares_Rejected) [Configured allowed ratio is 1:$(1 / $this.AllowedBadShareRatio)])"
                return @($Request, $Data | ConvertTo-Json -Depth 10 -Compress)
            }
        }

        $HashRate_Value = [Double]$Data.hashrate.total[0]
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[1]} #fix
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[2]} #fix
        $HashRate | Add-Member @{$HashRate_Name = [Double]$HashRate_Value}

        if ($HashRate.PSObject.Properties.Value -gt 0) {
                $this.Data += [PSCustomObject]@{
                Date       = (Get-Date).ToUniversalTime()
                Raw        = $Data
                HashRate   = $HashRate
                PowerUsage = (Get-PowerUsage $this.DeviceName)
                Shares     = @($Shares_Accepted, $Shares_Rejected, $($Shares_Accepted + $Shares_Rejected))
                Device     = @()
            }
        }

        return @($Request, $Data | ConvertTo-Json -Depth 10 -Compress)
    }
}
