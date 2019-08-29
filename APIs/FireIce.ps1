using module ..\Include.psm1

class Fireice : Miner {
    [String]GetCommandLineParameters() {
        return ($this.Arguments | ConvertFrom-Json).Commands
    }
    
    hidden StartMining() {
        $this.Status = [MinerStatus]::Failed

        $this.New = $true
        $this.Activated++

        if ($this.Arguments -like "{*}") {
            try {
                $Parameters = $this.Arguments | ConvertFrom-Json
                $ConfigFile = "$(Split-Path $this.Path)\$($Parameters.ConfigFile.FileName)"
                $PoolFile = "$(Split-Path $this.Path)\$($Parameters.PoolFile.FileName)"
                $Platform = $Parameters.Platform
                $PlatformThreadsConfigFile = "$(Split-Path $this.Path)\$($Parameters.PlatformThreadsConfigFile)"
                $MinerThreadsConfigFile = "$(Split-Path $this.Path)\$($Parameters.MinerThreadsConfigFile)"
                $ThreadsConfig = ""

                #Write pool config file, overwrite every time
                ($Parameters.PoolFile.Content | ConvertTo-Json -Depth 10) -replace '^{' -replace '}$', ',' | Set-Content $PoolFile -Force
                #Write config file, keep existing file to preserve user custom config
                if (-not (Test-Path $ConfigFile -PathType Leaf)) {($Parameters.ConfigFile.Content | ConvertTo-Json -Depth 10) -replace '^{' -replace '}$' | Set-Content $ConfigFile}

                if ($Parameters.ConfigFile.Content.threads) {
                    #Write full config file, ignore possible hw change
                    $Parameters.ConfigFile.Content | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile -ErrorAction SilentlyContinue -Force
                }
                else {
                    #Check if we have a valid hw file for all installed hardware. If hardware / device order has changed we need to re-create the config files.
                    if (-not (Test-Path $PlatformThreadsConfigFile -PathType Leaf)) {
                        if (Test-Path "$(Split-Path $this.Path)\ThreadsConfig-$($Platform)-$($this.Algorithm[0])-*.txt" -PathType Leaf) {
                            #Remove old config files, thread info is no longer valid
                            Write-Log -Level Warn "Hardware change detected. Deleting existing configuration files for miner ($($this.Name) {$($this.Algorithm[0] -replace 'NiceHash')@$($this.PoolName[0])}). "
                            Remove-Item "$(Split-Path $this.Path)\ThreadsConfig-$($Platform)-$($this.Algorithm[0])-*.txt" -Force -ErrorAction SilentlyContinue
                        }
                        #Temporarily start miner with empty thread conf file. The miner will then create a hw config file with default threads info for all platform hardware

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
                                if (Test-Path ($PlatformThreadsConfigFile)) {
                                    #Read hw config created by miner
                                    $ThreadsConfig = (Get-Content $PlatformThreadsConfigFile) -replace '^\s*//.*' | Out-String
                                    #Set bfactor to 11 (default is 6 which makes PC unusable)
                                    $ThreadsConfig = $ThreadsConfig -replace '"bfactor"\s*:\s*\d,', '"bfactor" : 11,'
                                    #Reformat to proper json
                                    $ThreadsConfigJson = "{$($ThreadsConfig -replace '\/\*.*' -replace '\*\/' -replace '\*.+' -replace '\s' -replace ',\},]','}]' -replace ',\},\{','},{' -replace '},]', '}]' -replace ',$','')}" | ConvertFrom-Json
                                    #Keep one instance per gpu config
                                    $ThreadsConfigJson | Add-Member gpu_threads_conf ($ThreadsConfigJson.gpu_threads_conf | Sort-Object -Property Index -Unique) -Force
                                    #Write json file
                                    $ThreadsConfigJson | ConvertTo-Json -Depth 10 | Set-Content $PlatformThreadsConfigFile -Force
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
                    if (-not (Test-Path $MinerThreadsConfigFile -PathType Leaf)) {
                        #Retrieve hw config from platform config file
                        $ThreadsConfigJson = Get-Content $PlatformThreadsConfigFile | ConvertFrom-Json -ErrorAction SilentlyContinue
                        #Filter index for current cards and apply threads
                        $ThreadsConfigJson | Add-Member gpu_threads_conf ([Array]($ThreadsConfigJson.gpu_threads_conf | Where-Object {$Parameters.Devices -contains $_.Index}) * $Parameters.Threads) -Force
                        #Create correct numer of CPU threads
                        $ThreadsConfigJson | Add-Member cpu_threads_conf ([Array]$ThreadsConfigJson.cpu_threads_conf * $Parameters.Threads) -Force
                        #Write config file
                        ($ThreadsConfigJson | ConvertTo-Json -Depth 10) -replace '^{' -replace '}$' | Set-Content $MinerThreadsConfigFile -Force
                    }
                }
            }
            catch {
                Write-Log -Level Error "Creating miner config files failed ($($this.Name) {$($this.Algorithm[0] -replace 'NiceHash')@$($this.PoolName[0])}) [Error: '$($Error[0])']. "
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
                $this.StatusMessage = " was stopped because of too many bad shares for algorithm $HashRate_Name (total: $($Shares_Accepted + $Shares_Rejected) / bad: $Shares_Rejected [Configured allowed ratio is 1:$(1 / $this.AllowedBadShareRatio)])"
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
