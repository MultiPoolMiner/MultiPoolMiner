using module ..\Include.psm1

class NanoMiner : Miner {
    [String]GetCommandLineParameters() {
        return ($this.Arguments | ConvertFrom-Json).Commands
    }

    hidden StartMining() {
        $this.Status = [MinerStatus]::Failed

        $this.New = $true
        $this.Activated++

        $Parameters = $this.Arguments | ConvertFrom-Json

        #Write config files. Keep separate files, do not overwrite to preserve optional manual customization
        if (-not (Test-Path "$(Split-Path $this.Path)\$($Parameters.ConfigFile.FileName)" -PathType Leaf)) {$Parameters.ConfigFile.Content | Set-Content "$(Split-Path $this.Path)\$($Parameters.ConfigFile.FileName)" -ErrorAction Ignore}

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
            if ($this.ShowMinerWindow) {
                if ((Test-Path ".\CreateProcess.cs" -PathType Leaf) -and ($this.API -ne "Wrapper")) {
                    $this.Process = Start-SubProcessWithoutStealingFocus -FilePath $this.Path -ArgumentList $this.GetCommandLineParameters() -WorkingDirectory (Split-Path $this.Path) -Priority ($this.DeviceName | ForEach-Object {if ($_ -like "CPU#*") {-2} else {-1}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -EnvBlock $this.Environment
                }
                else {
                    $EnvCmd = ($this.Environment | Foreach-Object {"```$env:$($_)"}) -join "; "
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

        $Request = "http://$($Server):$($this.Port)/stats"
        $Data = [PSCustomObject]@{}

        try {
            if ($Global:PSVersionTable.PSVersion -ge [System.Version]("6.2.0")) {
                $Data = Invoke-RestMethod $Request -TimeoutSec $Timeout -DisableKeepAlive -MaximumRetryCount 3 -RetryIntervalSec 1 -ErrorAction Stop
            }
            else {
                $Data = Invoke-RestMethod $Request -TimeoutSec $Timeout -DisableKeepAlive -ErrorAction Stop
            }
        }
        catch {
            return @($Request, $Data)
        }

        $HashRate = [PSCustomObject]@{}
        $HashRate_Name = [String]($this.Algorithm | Select-Object -Index 0)

        if ($this.AllowedBadShareRatio) {
            $Shares_Accepted = [Int64](($Data.Algorithms | Select-Object -Index 0).(($Data.Algorithms | Select-Object -Index 0) | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name).Total.Accepted)
            $Shares_Rejected = [Int64](($Data.Algorithms | Select-Object -Index 0).(($Data.Algorithms | Select-Object -Index 0) | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name).Total.Denied)

            if ((-not $Shares_Accepted -and $Shares_Rejected -ge 3) -or ($Shares_Accepted -and ($Shares_Rejected * $this.AllowedBadShareRatio -gt $Shares_Accepted))) {
                $this.SetStatus("Failed")
                $this.StatusMessage = " was stopped because of too many bad shares for algorithm $($HashRate_Name) (total: $($Shares_Accepted + $Shares_Rejected) / bad: $($Shares_Rejected) [Configured allowed ratio is 1:$(1 / $this.AllowedBadShareRatio)])"
                return @($Request, $Data | ConvertTo-Json -Depth 10 -Compress)
            }
        }

        $HashRate | Add-Member @{$HashRate_Name = [Double](($Data.Algorithms | Select-Object -Index 0).(($Data.Algorithms | Select-Object -Index 0) | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name).Total.Hashrate)}

        if ($HashRate.PSObject.Properties.Value -gt 0) {
            $this.Data += [PSCustomObject]@{
                Date       = (Get-Date).ToUniversalTime()
                Raw        = $Data
                HashRate   = $HashRate
                PowerUsage = (Get-PowerUsage $this.DeviceName)
                Device     = @()
            }
        }

        return @($Request, $Data | ConvertTo-Json -Depth 10 -Compress)
    }
}