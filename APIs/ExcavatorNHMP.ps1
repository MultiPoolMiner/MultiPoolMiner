using module ..\Include.psm1

class ExcavatorNHMP : Miner {
    hidden static [System.Management.Automation.Job]$Service
    hidden [DateTime]$BeginTime = 0
    hidden [DateTime]$EndTime = 0
    hidden [Array]$Workers = @()
    
    static [PSCustomObject]InvokeRequest($Miner, $Request) {
        $Server = "localhost"
        $Timeout = 10 #seconds

        try {
            $Response = Invoke-TcpRequest $Server $Miner.Port ($Request | ConvertTo-Json -Compress) $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop

            if ($Data.id -ne 1) {
                Write-Log -Level Error  "Invalid response returned by miner ($($Miner.Name)). "
                $Miner.SetStatus("Failed")
            }

            if ($Data.error) {
                Write-Log -Level Error  "Error returned by miner ($($Miner.Name)): $($Data.error)"
                $Miner.SetStatus("Failed")
            }
        }
        catch {
            Write-Log -Level Error  "Failed to connect to miner ($($Miner.Name)). "
            $Miner.SetStatus("Failed")
            return $null
        }
        return $Data
    }

    static WriteMessage($Miner, $Message) {
        $Data = [ExcavatorNHMP]::InvokeRequest($Miner, @{id = 1; method = "message"; params = @($Message)})
    }

    [String[]]GetProcessNames() {
        return @()
    }

    [String]GetLogFileParameters() {
        if ($this.ShowMinerWindow) {
            Return ""
        }
        else {
            Return " -fn $($Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Logs\Excavator-$($this.Port)_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt"))"
        }
    }

    [String]GetCommandLineParameters() {
        return "-p $($this.Port) -f 0$($this.GetLogFileParameters())"
    }

    hidden StartMining() {
        $Server = "localhost"
        $Timeout = 10 #seconds

        $this.New = $true
        $this.Activated++

        if ($this.Status -ne "Idle") {
            return
        }

        $this.Status = "Running"
        
        #Workers starting message
        [ExcavatorNHMP]::WriteMessage($this, "Starting worker for miner $($this.Name)... ")
        
        if ($this.Workers) {
            if ([ExcavatorNHMP]::Service.ProcessId -eq $this.ProcessId) {
                #Free all workers for this device
                $Data = [ExcavatorNHMP]::InvokeRequest($this, @{id = 1; method = "workers.free"; params = @($this.Workers)})
            }
        }
        #Subscribe to Nicehash        
        $Request = ($this.Arguments | ConvertFrom-Json) | Where-Object Method -Like "subscribe" | Select-Object -Index 0
        $Data = [ExcavatorNHMP]::InvokeRequest($this, $Request)

        #Build list of all algorithms
        $Data = [ExcavatorNHMP]::InvokeRequest($this, @{id = 1; method = "algorithm.list"; params = @()})
        $Algorithms = @($Data.algorithms.name)

        ($this.Arguments | ConvertFrom-Json) | Where-Object Method -Like "*.add" | ForEach-Object {
            $Argument = @($_)

            switch ($Argument.method) {
                #Add algorithms so it will receive new jobs
                "algorithm.add" {
                    if ($Algorithms -notcontains $Argument.params) {
                        $Data = [ExcavatorNHMP]::InvokeRequest($this, $Argument)
                    }
                }

                #Add single worker for device
                "worker.add" {
                    # Add worker for device
                    $Data = [ExcavatorNHMP]::InvokeRequest($this, $Argument)
                    if ("$($Data.worker_id)") {
                        $this.Workers += "$($Data.worker_id)"
                    }
                }

                #Add workers for device
                "workers.add" {
                    $Data = [ExcavatorNHMP]::InvokeRequest($this, $Argument)
                    $Data.Status | Where-Object {"$($_.worker_id)"} | ForEach-Object {
                        $this.Workers += "$($_.worker_id)"
                    }
                }
                Default {
                    $Data = [ExcavatorNHMP]::InvokeRequest($this, $Argument)
                }
            }
        }

        #Worker started message
        if ($this.Workers) {
            [ExcavatorNHMP]::WriteMessage($this, "Worker [$($this.Workers -join " ")] for miner $($this.Name) started. ")
        }
    }

    hidden StopMining() {
        $Server = "localhost"
        $Timeout = 10 #seconds

        if ($this.Status -ne "Running") {
            return
        }

        $this.Status = "Idle"

        if ($this.Workers) {
            if ([ExcavatorNHMP]::Service.ProcessId -eq $this.ProcessId) {
                
                #Get algorithm list
                $Data = [ExcavatorNHMP]::InvokeRequest($this, @{id = 1; method = "algorithm.list"; params = @()})
                $Algorithms = @($Data.algorithms.Name)

                #Free workers for this device
                $Data = [ExcavatorNHMP]::InvokeRequest($this, @{id = 1; method = "workers.free"; params = @($this.Workers)})

                #Worker stopped message
                [ExcavatorNHMP]::WriteMessage($this, "Worker [$($this.Workers -join " ")] for miner $($this.Name) stopped. ")

                #Get worker list
                $Data = [ExcavatorNHMP]::InvokeRequest($this, @{id = 1; method = "worker.list"; params = @()})
                $Active_Algorithms = $Algorithms | Select-Object -Unique |  Where-Object {$Data.workers.algorithms.name -icontains $_}
                $Unused_Algorithms = $Algorithms | Select-Object -Unique |  Where-Object {$Data.workers.algorithms.name -inotcontains $_}

                $Unused_Algorithms | ForEach-Object {
                    #Remove unused algorithm
                    $Data = [ExcavatorNHMP]::InvokeRequest($this, @{id = 1; method = "algorithm.remove"; params = @($_)})

                    #Algorithm cleared message
                    [ExcavatorNHMP]::WriteMessage($this, "Unused algorithm [$_] cleared. ")
                }

                if (-not $Active_Algorithms) {
                    if ($true) {
                        #Stop miner, this will also unsubscribe
                        $Request = @{id = 1; method = "miner.stop"; params = @()}
                    }
                    else{
                        #Quit miner
                        $Request = @{id = 1; method = "quit"; params = @()}
                    }
                    $Data = [ExcavatorNHMP]::InvokeRequest($this, $Request)
                }
            }
        }
    }

    [DateTime]GetActiveLast() {
        if ($this.BeginTime.Ticks -and $this.EndTime.Ticks) {
            return $this.EndTime
        }
        elseif ($this.BeginTime.Ticks) {
            return Get-Date
        }
        else {
            return [DateTime]::MinValue
        }
    }

    [TimeSpan]GetActiveTime() {
        if ($this.BeginTime.Ticks -and $this.EndTime.Ticks) {
            return $this.Active + ($this.EndTime - $this.BeginTime)
        }
        elseif ($this.BeginTime.Ticks) {
            return $this.Active + ((Get-Date) - $this.BeginTime)
        }
        else {
            return $this.Active
        }
    }

    [Int]GetActivateCount() {
        return $this.Activated
    }

    [MinerStatus]GetStatus() {
        return $this.Status
    }

    SetStatus([MinerStatus]$Status) {
        if ($Status -eq $this.GetStatus()) {return}

        if ($this.BeginTime.Ticks) {
            if (-not $this.EndTime.Ticks) {
                $this.EndTime = Get-Date
            }

            $this.Active += $this.EndTime - $this.BeginTime
            $this.BeginTime = 0
            $this.EndTime = 0
        }

        if (-not ([ExcavatorNHMP]::Service.State -eq "Running")) {
            if (Test-Path ".\CreateProcess.cs" -PathType Leaf) {
                [ExcavatorNHMP]::Service = Start-SubProcessWithoutStealingFocus -FilePath $this.Path -ArgumentList $($this.GetCommandLineParameters()) -WorkingDirectory $(Split-Path $this.Path) -Priority ($this.Device.Type | ForEach-Object {if ($_ -eq "CPU") {-2}else {-1}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum)
            }
            else {
               [ExcavatorNHMP]::Service = Start-Job ([ScriptBlock]::Create("Start-Process $(@{desktop = "powershell"; core = "pwsh"}.$Global:PSEdition) `"-command ```$Process = (Start-Process '$($this.Path)' '$($this.GetCommandLineParameters())' -WorkingDirectory '$(Split-Path $this.Path)' -WindowStyle Minimized -PassThru).Id; Wait-Process -Id `$PID; Stop-Process -Id ```$Process`" -WindowStyle Hidden -Wait"))
            }
            #Wait until excavator is ready, max 10 seconds
            $Server = "localhost"
            $Timeout = 1
            $Request = @{id = 1; method = "algorithm.list"; params = @()} | ConvertTo-Json -Compress
            $Response = ""
            for ($WaitForLocalhost = 0; $WaitForLocalhost -le 20; $WaitForLocalhost++) {
                try {
                    $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                    $Data = $Response | ConvertFrom-Json -ErrorAction Stop
                    [ExcavatorNHMP]::Service | Add-Member ProcessId (Get-CIMInstance CIM_Process | Where-Object {$_.ExecutablePath -eq $this.Path -and $_.CommandLine -like "*$($this.Path)*$($this.GetCommandLineParameters())*"}).ProcessId
                    break
                }
                catch {
                }
                Sleep -Milliseconds 100
            }
        }

        if ($this.ProcessId -ne [ExcavatorNHMP]::Service.ProcessId) {
            $this.Status = "Idle"
            $this.Workers = @()
            $this.ProcessId = [ExcavatorNHMP]::Service.ProcessId
        }

        switch ($Status) {
            "Running" {
                $this.StartMining()
            }
            "Idle" {
                $this.StopMining()
            }
            "Failed" {
                $this.StopMining()
                $this.Status = $Status
            }
            Default {
                if ([ExcavatorNHMP]::Service | Get-Job -ErrorAction SilentlyContinue) {
                    [ExcavatorNHMP]::Service | Remove-Job -Force
                }

                if (-not ([ExcavatorNHMP]::Service | Get-Job -ErrorAction SilentlyContinue)) {
                    [ExcavatorNHMP]::Service = $null
                }
                $this.Status = $Status
            }
        }
    }

    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 10 #seconds

        #Get list of all active workers
        $Request = @{id = 1; method = "worker.list"; params = @()} | ConvertTo-Json -Compress
        $Response = ""
        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop

            if ($Data.id -ne 1) {
                Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
            }

            if ($Data.error) {
                Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
            }
        }
        catch {
            if ((Get-Date) -gt ($this.BeginTime.AddSeconds(30))) {$this.SetStatus("Failed")}
            return @($Request, $Response)
        }

        #Get hash rates per algorithm
        $HashRate = [PSCustomObject]@{}
        $HashRate_Name = ""
        $HashRate_Value = [Int64]0
        $Data.workers.algorithms.name | Select-Object -Unique | ForEach-Object {
            $Workers = $Data.workers | Where-Object {$this.workers -match $_.Worker_id}
            $Algorithm = $_

            $HashRate_Name = [String](($this.Algorithm -replace "-NHMP") -match (Get-Algorithm $Algorithm))
            if (-not $HashRate_Name) {$HashRate_Name = [String](($this.Algorithm -replace "-NHMP") -match "$(Get-Algorithm $Algorithm)*")} #temp fix
            $HashRate_Value = [Int64](($Workers.algorithms | Where-Object {$_.name -eq $Algorithm}).speed | Measure-Object -Sum).Sum

            if ($HashRate_Name -and $HashRate_Value -GT 0) {$HashRate | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}}
        }

        #Print algorithm speeds
        $Data = [ExcavatorNHMP]::InvokeRequest($this, @{id = 1; method = "algorithm.print.speeds"; params = @()})

        if ($HashRate | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) {
            $this.Data += [PSCustomObject]@{
                Date       = (Get-Date).ToUniversalTime()
                Raw        = $Response
                HashRate   = $HashRate
                Device     = @()
            }
        }

        return @($Request, $Data | ConvertTo-Json -Compress)
    }
}