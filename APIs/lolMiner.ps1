using module ..\Include.psm1

class lolMiner : Miner {

    [String]GetCommandLineParameters() {
        return ($this.Arguments | ConvertFrom-Json).Commands
    }    

    hidden StartMining() {
        $this.Status = [MinerStatus]::Failed

        $this.New = $true
        $this.Activated++

        $Parameters = $this.Arguments | ConvertFrom-Json
        $Arguments = "$($Parameters.Commands)"

        #Write config files. Keep separate files, do not overwrite to preserve optional manual customization
        if (-not (Test-Path "$(Split-Path $this.Path)\$($Parameters.ConfigFile.FileName)" -PathType Leaf)) {$Parameters.ConfigFile.Content | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $this.Path)\$($Parameters.ConfigFile.FileName)" -Encoding UTF8 -ErrorAction Ignore}

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
            if ($this.ShowMinerWindow -and $this.API -ne "Wrapper") {
                $this.Process = Start-Job ([ScriptBlock]::Create("Start-Process $(@{desktop = "powershell"; core = "pwsh"}.$Global:PSEdition) `"-command ```$Process = (Start-Process '$($this.Path)' '$($Arguments)' -WorkingDirectory '$(Split-Path $this.Path)' -WindowStyle Minimized -PassThru).Id; Wait-Process -Id `$PID; Stop-Process -Id ```$Process`" -WindowStyle Hidden -Wait"))
            }
            else {
                $this.LogFile = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Logs\$($this.Name)-$($this.Port)_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt")
                $this.Process = Start-SubProcess -FilePath $this.Path -ArgumentList $Arguments -LogPath $this.LogFile -WorkingDirectory (Split-Path $this.Path) -Priority ($this.DeviceName | ForEach-Object {if ((Get-Device $_).Type -eq "CPU") {-2}else {-1}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum)
            }

            if ($this.Process | Get-Job -ErrorAction SilentlyContinue) {
                for ($WaitForPID = 0; $WaitForPID -le 20; $WaitForPID++) {
                    if ($this.ProcessId = (Get-CIMInstance CIM_Process | Where-Object {$_.ExecutablePath -eq $this.Path -and $_.CommandLine -like "*$($this.Path)*$($Arguments)*"}).ProcessId) {
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

        $Data = [PSCustomObject]@{}

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Get-TCPResponse $Server $this.Port $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            if ((Get-Date) -gt ($this.Process.PSBeginTime.AddSeconds(30))) {$this.SetStatus("Failed")}
            return @($Request, $Response)
        }

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = 0
        #Miner parameter -SHORTSTATS is user settable
        for ($Interval = 1; ($Interval -le 60 -and -not $HashRate_Value); $Interval++) {
            try {
                $HashRate_Value = [Double]$Data."TotalSpeed($($Interval)s)"
            }
            catch {
            }
        }

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = [Double]$HashRate_Value}
        }

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