using module ..\Include.psm1

class XmRigCfgFile : Miner {
    hidden StartMining() {
        $this.Status = [MinerStatus]::Failed

        $this.New = $true
        $this.Activated++

        $Parameters = $this.Arguments | ConvertFrom-Json
        $Arguments = "$($Parameters.Commands)"
        $ConfigFile = "$(Split-Path $this.Path)\$($Parameters.ConfigFile.FileName)"
        $ThreadsConfig = [PSCustomObject]@{}

        if (-not $Parameters.ConfigFile.Content.threads) {
            #Existing complete config file with threads info?
            if (Test-Path $ConfigFile -PathType Leaf) {
                $ThreadsConfig = (Get-Content $ConfigFile | ConvertFrom-Json -ErrorAction SilentlyContinue).threads
            }
            if (-not $ThreadsConfig) {
                #Check if we have a valid hw file for all installed hardware (hardware changed, deviceIDs changed?). Thread info depends on algo.
                $Vendors = @(((Get-Device $this.DeviceName) | Select-Object Vendor -Unique).Vendor)
                $ThreadsConfigFile = "ThreadsConfig_$($this.Algorithm)_$((((Get-Device $this.DeviceName | Where-Object {$Vendors -contains $_.Vendor}).Model | Select-Object) -replace '[^A-Z0-9]' -replace 'GeForce','') -join '-').json"
                if (Test-Path ("$(Split-Path $this.Path)\$ThreadsConfigFile") -PathType Leaf) {
                    $ThreadsConfig = Get-Content "$(Split-Path $this.Path)\$ThreadsConfigFile" | ConvertFrom-Json -ErrorAction SilentlyContinue
                }
                if (-not $ThreadsConfig.index -or ($ThreadsConfig.index).Count -le 1) {
                    #Temporarily start miner with pre-config file (without threads config). Miner will then update hw config file with threads info
                    $Parameters.ConfigFile.Content | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $this.Path)\$ThreadsConfigFile" -ErrorAction SilentlyContinue -Force
                    $TempMinerArguments = " --config=$ThreadsConfigFile"
                    $this.Process = Start-Job ([ScriptBlock]::Create("Start-Process $(@{desktop = "powershell"; core = "pwsh"}.$Global:PSEdition) `"-command ```$Process = (Start-Process '$($this.Path)' '$($TempMinerArguments)' -WorkingDirectory '$(Split-Path $this.Path)' -WindowStyle Minimized -PassThru).Id; Wait-Process -Id `$PID; Stop-Process -Id ```$Process`" -WindowStyle Hidden -Wait"))
                    Start-Sleep 1
                    $this.SetStatus("Idle")
                    Start-Sleep 1
                    $ThreadsConfig = (Get-Content "$(Split-Path $this.Path)\$ThreadsConfigFile" | ConvertFrom-Json -ErrorAction SilentlyContinue).threads
                    $ThreadsConfig | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $this.Path)\$ThreadsConfigFile" -ErrorAction SilentlyContinue -Force
                }
            }
            #Write config files. Overwrite because we need to add thread info
            $Parameters.ConfigFile.Content | Add-Member threads (@($ThreadsConfig | Where-Object {$Parameters.Devices -contains $_.index}))
            $Parameters.ConfigFile.Content | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile -ErrorAction SilentlyContinue -Force
        }
        else {    
            #Write config files. Do not overwrite to preserve user defined customization
            $Parameters.ConfigFile.Content | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile -ErrorAction SilentlyContinue
        }

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
        $Timeout = 5 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/api.json" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
            return @($Request, $Response)
        }

        $HashRate_Name = [String]($this.Algorithm -like (Get-Algorithm $Data.algo))
        if (-not $HashRate_Name) {$HashRate_Name = [String]($this.Algorithm -like "$(Get-Algorithm $Data.algo)*")} #temp fix
        if (-not $HashRate_Name) {$HashRate_Name = [String]$this.Algorithm[0]} #fireice fix
        $HashRate_Value = [Double]$Data.hashrate.total[0]
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[1]} #fix
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[2]} #fix

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}
        }

        $this.Data += [PSCustomObject]@{
            Date     = (Get-Date).ToUniversalTime()
            Raw      = $Response
            HashRate = $HashRate
            Device   = @()
        }

        return @($Request, $Data | ConvertTo-Json -Compress)
    }
}
