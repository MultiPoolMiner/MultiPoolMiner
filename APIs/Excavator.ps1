using module ..\Include.psm1

class Excavator : Miner {
    hidden static [System.Management.Automation.Job]$Service
    hidden [DateTime]$BeginTime = 0
    hidden [DateTime]$EndTime = 0
    hidden [Array]$Workers = @()
    hidden [Int32]$Service_Id = 0

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
            if ([Excavator]::Service.Id -eq $this.Service_Id) {
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
            Write-Log -Level Error  "Failed to connect to miner ($($this.Name)). "
            $this.SetStatus("Failed")
            return
        }

        $Data_Algorithms = @($Data.algorithms | Select-Object @{"Name" = "ID"; "Expression" = {$_.algorithm_id}}, @{"Name" = "Name"; "Expression" = {$_.name}}, @{"Name" = "Address1"; "Expression" = {$_.pools[0].address}}, @{"Name" = "Login1"; "Expression" = {$_.pools[0].login}}, @{"Name" = "Address2"; "Expression" = {$_.pools[1].address}}, @{"Name" = "Login2"; "Expression" = {$_.pools[1].login}})
        $Arguments_Algorithms = @()

        ($this.Arguments | ConvertFrom-Json) | Where-Object Method -Like "*.add" | ForEach-Object {
            $Argument = $_

            switch ($Argument.method) {
                "algorithm.add" {
                    $Argument_Algorithm = $Argument | Select-Object @{"Name" = "ID"; "Expression" = {""}}, @{"Name" = "Name"; "Expression" = {$_.params[0]}}, @{"Name" = "Address1"; "Expression" = {if ($_.params[1]) {$_.params[1]}else {"benchmark"}}}, @{"Name" = "Login1"; "Expression" = {if ($_.params[2]) {$_.params[2]}else {"benchmark"}}}, @{"Name" = "Address2"; "Expression" = {if ($_.params[3]) {$_.params[3]}else {"benchmark"}}}, @{"Name" = "Login2"; "Expression" = {if ($_.params[4]) {$_.params[4]}else {"benchmark"}}}
                    $Algorithm_ID = $Data_Algorithms | Where-Object Name -EQ $Argument_Algorithm.Name | Where-Object Address1 -EQ $Argument_Algorithm.Address1 | Where-Object Login1 -EQ $Argument_Algorithm.Login1 | Where-Object Address2 -EQ $Argument_Algorithm.Address2 | Where-Object Login2 -EQ $Argument_Algorithm.Login2 | Select-Object -ExpandProperty ID -First 1

                    if (-not "$Algorithm_ID") {
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
                            Write-Log -Level Error  "Failed to connect to miner ($($this.Name)). "
                            $this.SetStatus("Failed")
                            return
                        }

                        $Algorithm_ID = $Data.algorithm_id
                    }

                    if ("$Algorithm_ID") {
                        $Argument_Algorithm.ID = "$Algorithm_ID"
                        $Data_Algorithms += $Argument_Algorithm
                        $Arguments_Algorithms += $Argument_Algorithm
                    }
                }
                "worker.add" {
                    $Argument.params[0] = "$($Arguments_Algorithms[$Argument.params[0]].ID)"
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
                        Write-Log -Level Error  "Failed to connect to miner ($($this.Name)). "
                        $this.SetStatus("Failed")
                        return
                    }

                    if ("$($Data.worker_id)") {
                        $this.Workers += "$($Data.worker_id)"
                    }
                }
                "workers.add" {
                    $Argument.params = @(
                        $Argument.params | ForEach-Object {
                            if ($_ -like "alg-*") {
                                "alg-$($Arguments_Algorithms[$_.TrimStart("alg-")].ID)"
                            }
                            else {
                                $_
                            }
                        }
                    )
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
                        Write-Log -Level Error  "Failed to connect to miner ($($this.Name)). "
                        $this.SetStatus("Failed")
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
                        Write-Log -Level Error  "Failed to connect to miner ($($this.Name)). "
                        $this.SetStatus("Failed")
                        return
                    }
                }
            }
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
            if ([Excavator]::Service.Id -eq $this.Service_Id) {
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

        if (-not [Excavator]::Service) {
            $LogFile = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Logs\Excavator-$($this.Port)_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt")
            [Excavator]::Service = Start-Job ([ScriptBlock]::Create("Start-Process $(@{desktop = "powershell"; core = "pwsh"}.$Global:PSEdition) `"-command ```$Process = (Start-Process '$($this.Path)' '-p $($this.Port) -f 0 -fn \```"$($LogFile)\```"' -WorkingDirectory '$(Split-Path $this.Path)' -WindowStyle Minimized -PassThru).Id; Wait-Process -Id `$PID; Stop-Process -Id ```$Process`" -WindowStyle Hidden -Wait"))
            Start-Sleep 10
        }

        if ($this.Service_Id -ne [Excavator]::Service.Id) {
            $this.Status = "Idle"
            $this.Workers = @()
            $this.Service_Id = [Excavator]::Service.Id
        }

        switch ($Status) {
            "Running" {
                $this.StartMining()
            }
            "Idle" {
                $this.StopMining()
            }
            Default {
                if ([Excavator]::Service | Get-Job -ErrorAction SilentlyContinue) {
                    [Excavator]::Service | Remove-Job -Force
                }

                if (-not ([Excavator]::Service | Get-Job -ErrorAction SilentlyContinue)) {
                    [Excavator]::Service = $null
                }

                $this.Status = $Status
            }
        }
    }

    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = @{id = 1; method = "algorithm.list"; params = @()} | ConvertTo-Json -Compress
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
            Write-Log -Level Error  "Failed to connect to miner ($($this.Name)). "
            $this.SetStatus("Failed")
            return @($Request, $Response)
        }

        $Data.algorithms.name | Select-Object -Unique | ForEach-Object {
            $Workers = @(($Data.algorithms | Where-Object name -EQ $_).workers)
            $Algorithms = $_ -split "_"
            $Algorithms | ForEach-Object {
                $Algorithm = $_

                $HashRate_Name = [String]($this.Algorithm -match (Get-Algorithm $Algorithm))
                if (-not $HashRate_Name) {$HashRate_Name = [String]($this.Algorithm -match "$(Get-Algorithm $Algorithm)*")} #temp fix
                $HashRate_Value = [Double](($Workers | Where-Object {$this.Workers -like $_.worker_id}).speed | Select-Object -Index @($Workers.worker_id | ForEach-Object {$_ * 2 + $Algorithms.IndexOf($Algorithm)}) | Measure-Object -Sum).Sum
                if ($HashRate_Name -and $HashRate_Value -gt 0) {
                    $HashRate | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}
                }
            }
        }

        $Request = @{id = 1; method = "algorithm.print.speeds"; params = @()} | ConvertTo-Json -Compress

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
            Write-Log -Level Error  "Failed to connect to miner ($($this.Name)). "
        }

        $this.Data += [PSCustomObject]@{
            Date = (Get-Date).ToUniversalTime()
            Raw = $Response
            HashRate = $HashRate
            Device = @()
        }

        return @($Request, $Data | ConvertTo-Json -Compress)
    }
}
