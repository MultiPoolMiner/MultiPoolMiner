using module ..\Include.psm1

class Fireice : Miner {
    [String]GetCommandLineParameters() {
        return ($this.Arguments | ConvertFrom-Json).Commands
    }
    
    hidden StartMining() {
        $this.Status = [MinerStatus]::Failed

        $this.New = $true
        $this.Activated++

        $Parameters = $this.Arguments | ConvertFrom-Json
        $ConfigFile = "$(Split-Path $this.Path)\$($Parameters.ConfigFile.FileName)"
        $PoolsFile = "$(Split-Path $this.Path)\$($Parameters.PoolsFile.FileName)"
        $MinerThreadsConfigFile = "$(Split-Path $this.Path)\$($Parameters.MinerThreadsConfigFile)"
        $PlatformThreadsConfigFile = "$(Split-Path $this.Path)\$($Parameters.PlatformThreadsConfigFile)"
        $ThreadsConfig = ""

        try {
            #Write config files
            ($Parameters.ConfigFile.Content | ConvertTo-Json -Depth 10) -replace '^{' -replace '}$' | Set-Content $ConfigFile -Force
            ($Parameters.PoolsFile.Content | ConvertTo-Json -Depth 10) -replace '^{' -replace '}$', ',' | Set-Content $PoolsFile -Force

            #Has hardware config changed? 
            if (-not (Test-Path $PlatformThreadsConfigFile -PathType Leaf)) {
                #Temporarily start miner with empty thread conf file. The miner will then create a hw config file with default threads info for all platform hardware
                $this.Process = Start-Job ([ScriptBlock]::Create("Start-Process $(@{desktop = "powershell"; core = "pwsh"}.$Global:PSEdition) `"-command ```$Process = (Start-Process '$($this.Path)' '$($Parameters.HwDetectCommands)' -WorkingDirectory '$(Split-Path $this.Path)' -WindowStyle Minimized -PassThru).Id; Wait-Process -Id `$PID; Stop-Process -Id ```$Process`" -WindowStyle Hidden -Wait"))
                if ($this.Process | Get-Job -ErrorAction SilentlyContinue) {
                    for ($WaitForThreadsConfig = 0; $WaitForThreadsConfig -le 360; $WaitForThreadsConfig++) {
                        if (Test-Path ($PlatformThreadsConfigFile)) {
                            break
                        }
                        Start-Sleep -Milliseconds 100
                    }
                    $this.Process | Remove-Job -Force
                    $this.Process = $null
                }
            }
            if (-not (Test-Path $MinerThreadsConfigFile -PathType Leaf) -or (Get-Item $PlatformThreadsConfigFile).LastWriteTime -gt (Get-Item $MinerThreadsConfigFile).LastWriteTime) {
                $ThreadsConfig = (Get-Content $PlatformThreadsConfigFile) -replace '^\s*//.*' | Out-String
                $ThreadsConfig = $ThreadsConfig -replace '\/\*.*' -replace '\*\/' -replace '\*.+' -replace '\s' -replace ',\},]','}]' -replace ',\},\{','},{' -replace ',$',''
                for ($DeviceID = 0; $DeviceID -le 32; $DeviceID++) {
                    if ($Parameters.Devices.Count -ge 1 -and $Parameters.Devices -notcontains $DeviceId) {
                        # Filter unwanted miner index
                        $ThreadToRemovePattern = "({`"index`":$($DeviceID).+?},)"
                        $ThreadsConfig = $ThreadsConfig -replace $ThreadToRemovePattern
                    }
                }
                #Set Bfactor to 11 (default is 6 which makes PC unusable)
                $ThreadsConfig = $ThreadsConfig -replace '"bfactor":\d,', '"bfactor":11,'
                #Write HW config file with threads info for active device
                $ThreadsConfig | Set-Content $MinerThreadsConfigFile -Force
            }
        }
        catch {
            Write-Log -Level Error "Creating miner config files failed ($($this.Name) {$(($this.Algorithm | Foreach-Object {"$($_ -replace '-NHMP' -replace 'NiceHash')@$($Pools.$_.Name)"}) -join "; ")}) [Error: '$($Error[0])']. "
            return
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
