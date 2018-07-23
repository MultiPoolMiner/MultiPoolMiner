using module ..\Include.psm1

class ExcavatorNHMP : Miner {
    hidden static [System.Management.Automation.Job]$Service
    hidden [DateTime]$BeginTime = 0
    hidden [DateTime]$EndTime = 0
    hidden [Array]$Workers = @()
    hidden [Int32]$Service_Id = 1

    [String[]]GetProcessNames() {
        return @()
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

        $this.BeginTime = Get-Date

        if ($this.Workers) {
            if ([ExcavatorNHMP]::Service.Id -eq $this.Service_Id) {
                # Free all workers for this device
                $Request = @{id = 1; method = "workers.free"; params = $this.Workers} | ConvertTo-Json -Compress
                try {
                    $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                    $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                    if ($Data.id -ne 1) {
                        Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                        $this.SetStatus("Failed")
                    }

                    if ($Data.error) {
                        Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                       $this.SetStatus("Failed")
                    }
                }
                catch {
                    Write-Log -Level Error  "Failed to connect to miner ($($this.Name)). "
                    $this.SetStatus("Failed")
                    return
                }
            }
        }

        # Subscribe to Nicehash        
        $Request = ($this.Arguments | ConvertFrom-Json) | Where-Object Method -Like "subscribe" | Select-Object -Index 0 | ConvertTo-Json -Depth 10 -Compress
        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop

            if ($Data.id -ne 1) {
                Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                $this.SetStatus("Failed")
            }

            if ($Data.error) {
                Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                $this.SetStatus("Failed")
            }
        }
        catch {
            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
            $this.SetStatus("Failed")
            return
        }

        # Build list of all algorithms
        $Request = @{id = 1; method = "algorithm.list"; params = @()} | ConvertTo-Json -Compress
        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop

            if ($Data.id -ne 1) {
                Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                $this.SetStatus("Failed")
            }

            if ($Data.error) {
                Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                $this.SetStatus("Failed")
            }
        }
        catch {
            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
            $this.SetStatus("Failed")
            return
        }
        $Algorithms = @($Data.algorithms.Name)

        ($this.Arguments | ConvertFrom-Json) | Where-Object Method -Like "*.add" | ForEach-Object {
            $Argument = $_

            switch ($Argument.method) {
                #Add algorithms so it will receive new jobs
                "algorithm.add" {
                    if ($Algorithms -notcontains $Argument.params) {
                        $Request = $Argument | ConvertTo-Json -Compress

                        try {
                            $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                            $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                            if ($Data.id -ne 1) {
                                Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                                $this.SetStatus("Failed")
                            }

                            if ($Data.error) {
                                Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                                $this.SetStatus("Failed")
                            }
                        }
                        catch {
                            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                            $this.SetStatus("Failed")
                            return
                        }

                    }
                }

                "worker.add" {
                    # Add worker for device
                    $Request = $Argument | ConvertTo-Json -Compress

                    try {
                        $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                        $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                        if ($Data.id -ne 1) {
                            Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                            $this.SetStatus("Failed")
                        }

                        if ($Data.error) {
                            Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                            $this.SetStatus("Failed")
                        }
                    }
                    catch {
                        Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                        $this.SetStatus("Failed")
                        return
                    }

                    if ("$($Data.worker_id)") {
                        $this.Workers += "$($Data.worker_id)"
                    }
                }

                #Add workers for device
                "workers.add" {
                    $Request = $Argument | ConvertTo-Json -Compress

                    try {
                        $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                        $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                        if ($Data.id -ne 1) {
                            Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                            $this.SetStatus("Failed")
                        }

                        $Data.Status | ForEach-Object {
                            if ($_.error) {
                                Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($_.error)"
                                $this.SetStatus("Failed")
                            }
                        }
                    }
                    catch {
                        if ($this.GetActiveTime().TotalSeconds -gt 60) {
                            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                            $this.SetStatus("Failed")
                        }
                        return
                    }

                    $Data.Status | Where-Object {"$($_.worker_id)"} | ForEach-Object {
                        $this.Workers += "$($_.worker_id)"
                    }
                }
                Default {
                    $Request = $Argument | ConvertTo-Json -Compress

                    try {
                        $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                        $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                        if ($Data.id -ne 1) {
                            Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                            $this.SetStatus("Failed")
                        }

                        if ($Data.error) {
                            Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                            $this.SetStatus("Failed")
                        }
                    }
                    catch {
                        Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                        $this.SetStatus("Failed")
                        return
                    }
                }
            }
        }

        # Worker started message
        $Request = @{id = 1; method = "message"; params = @("Worker [$($this.Workers -join "&")] for miner $($this.Name) started. ")} | ConvertTo-Json -Compress
        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop

            if ($Data.id -ne 1) {
                Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                $this.SetStatus("Failed")
            }

            if ($Data.error) {
                Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                $this.SetStatus("Failed")
            }
        }
        catch {
            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
            $this.SetStatus("Failed")
            return
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
            if ([ExcavatorNHMP]::Service.Id -eq $this.Service_Id) {
                
                #Get algorithm list
                $Request = @{id = 1; method = "algorithm.list"; params = @()} | ConvertTo-Json -Compress
                try {
                    $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                    $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                    if ($Data.id -ne 1) {
                        Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                        $this.SetStatus("Failed")
                    }

                    if ($Data.error) {
                        Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                        $this.SetStatus("Failed")
                    }
                }
                catch {
                    Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                    $this.SetStatus("Failed")
                    return
                }
                $Algorithms = @($Data.algorithms.Name)

                # Free workers for this device
                $Request = @{id = 1; method = "workers.free"; params = $this.Workers} | ConvertTo-Json -Compress
                $Response = ""
                $HashRate = [PSCustomObject]@{}

                try {
                    $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                    $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                    if ($Data.id -ne 1) {
                        Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                        $this.SetStatus("Failed")
                    }

                    if ($Data.error) {
                        Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                        $this.SetStatus("Failed")
                    }
                }
                catch {
                    Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                    $this.SetStatus("Failed")
                    return
                }

                #Get worker list
                $Request = @{id = 1; method = "worker.list"; params = @()} | ConvertTo-Json -Compress

                try {
                    $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                    $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                    if ($Data.id -ne 1) {
                        Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                        $this.SetStatus("Failed")
                    }

                    if ($Data.error) {
                        Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                        $this.SetStatus("Failed")
                    }
                }
                catch {
                    Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                    $this.SetStatus("Failed")
                    return
                }
                $Active_Algorithms = $Algorithms | Select-Object -Unique |  Where-Object {$Data.workers.algorithms.name -icontains $_}
                $Unused_Algorithms = $Algorithms | Select-Object -Unique |  Where-Object {$Data.workers.algorithms.name -inotcontains $_}

                if ($Unused_Algorithms) {
                    #Remove unused algorithms
                    $Request = @{id = 1; method = "algorithm.remove"; params = @($Unused_Algorithms)} | ConvertTo-Json -Compress

                    try {
                        $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                        $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                        if ($Data.id -ne 1) {
                            Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                            $this.SetStatus("Failed")
                        }

                        if ($Data.error) {
                            Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                            $this.SetStatus("Failed")
                        }
                    }
                    catch {
                        Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                        $this.SetStatus("Failed")
                        return
                    }
                }


                # Worker stopped message
                $Request = @{id = 1; method = "message"; params = @("Worker [$($this.Workers -join "&")] for miner $($this.Name) stopped. ")} | ConvertTo-Json -Compress
                try {
                    $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                    $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                    if ($Data.id -ne 1) {
                        Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                        $this.SetStatus("Failed")
                    }

                    if ($Data.error) {
                        Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                        $this.SetStatus("Failed")
                    }
                }
                catch {
                    Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                    $this.SetStatus("Failed")
                    return
                }

                if (-not $Active_Algorithms) {
                    if ($true) {
                        #Stop miner, this will also unsubscribe
                        $Request = @{id = 1; method = "miner.stop"; params = @()} | ConvertTo-Json -Compress
                    }
                    else{
                        #Quit miner
                        $Request = @{id = 1; method = "quit"; params = @()} | ConvertTo-Json -Compress
                    }
                    $Response = ""

                    $HashRate = [PSCustomObject]@{}

                    try {
                        $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                        $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                        if ($Data.id -ne 1) {
                            Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                            $this.SetStatus("Failed")
                        }

                        if ($Data.error) {
                            Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                            $this.SetStatus("Failed")
                        }
                    }
                    catch {
                        Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                        $this.SetStatus("Failed")
                        return
                    }
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

        if (-not [ExcavatorNHMP]::Service) {
            $LogFile = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Logs\Excavator-$($this.Port)_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt")
            [ExcavatorNHMP]::Service = Start-Job ([ScriptBlock]::Create("Start-Process $(@{desktop = "powershell"; core = "pwsh"}.$Global:PSEdition) `"-command ```$Process = (Start-Process '$($this.Path)' '-d 2 -p $($this.Port) -wp $([Int]($this.Port) + 1) -f 0 -fn \```"$($LogFile)\```"' -WorkingDirectory '$(Split-Path $this.Path)' -WindowStyle Minimized -PassThru).Id; Wait-Process -Id `$PID; Stop-Process -Id ```$Process`" -WindowStyle Hidden -Wait"))
            #Start-Sleep 5
            $Server = "localhost"
            $Timeout = 1
            $Request = @{id = 1; method = "algorithm.list"; params = @()} | ConvertTo-Json -Compress
            $Response = ""
            for($waitforlocalhost=0; $waitforlocalhost -le 10; $waitforlocalhost++) {
                try {
                    $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                    $Data = $Response | ConvertFrom-Json -ErrorAction Stop
                    break
                }
                catch {
                }
            }
        }

        if ($this.Service_Id -ne [ExcavatorNHMP]::Service.Id) {
            $this.Status = "Idle"
            $this.Workers = @()
            $this.Service_Id = [ExcavatorNHMP]::Service.Id
        }

        switch ($Status) {
            "Running" {
                $this.StartMining()
            }
            "Idle" {
                $this.StopMining()
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
        $HashRate = [PSCustomObject]@{}

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
            if ($this.GetActiveTime().TotalSeconds -gt 60) {
                Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                $this.SetStatus("Failed")
            }
            return @($Request, $Response)
        }

        #Get hash rates per algorithm
        $Data.workers.algorithms.name | Select-Object -Unique | ForEach-Object {
            $Workers = $Data.workers | Where-Object {$this.workers -match $_.Worker_id}
            $Algorithm = $_

            $HashRate_Name = [String](($this.Algorithm -replace "-NHMP") -match (Get-Algorithm $Algorithm))
            if (-not $HashRate_Name) {$HashRate_Name = [String](($this.Algorithm -replace "-NHMP") -match "$(Get-Algorithm $Algorithm)*")} #temp fix
            $HashRate_Value = [Double](($Workers.algorithms | Where-Object {$_.name -eq $Algorithm}).speed | Measure-Object -Sum).Sum
            if ($HashRate_Name -and $HashRate_Value -gt 0) {
                $HashRate | Add-Member @{"$($HashRate_Name)-NHMP" = [Int64]$HashRate_Value}
            }
        }

        #Print algorithm speeds
        $Request = @{id = 1; method = "algorithm.print.speeds"; params = @()} | ConvertTo-Json -Compress
        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop

            if ($Data.id -ne 1) {
                Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                $this.SetStatus("Failed")
            }

            if ($Data.error) {
                Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                $this.SetStatus("Failed")
            }
        }
        catch {
            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
            $this.SetStatus("Failed")
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