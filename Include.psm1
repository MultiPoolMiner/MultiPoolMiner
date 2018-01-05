Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1" -ErrorAction Ignore
Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1" -ErrorAction Ignore

Set-Location (Split-Path $MyInvocation.MyCommand.Path)

Add-Type -Path .\OpenCL\*.cs

function Update-Stats {

# UselessGuru: updates stats (hashrate, GPU and power) receives from GetData

[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Miner,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Miner_Data,
        [Parameter(Mandatory = $true)]
        [TimeSpan]$StatSpan
    )

    $Miner_HashRate = $Miner_Data.HashRate
    $Miner_PowerDraw = $Miner_Data.PowerDraw
    $Miner_ComputeUsage = $Miner_Data.ComputeUsage
    if ($Miner_HashRate -is [Array]) {
        $Miner.Speed_Live = $Miner_HashRate[0]
    }
    else {
        $Miner.Speed_Live = $Miner_HashRate
    }
    
    $Miner_HashRates = ""
    $Miner.Algorithm | Where-Object {$Miner_HashRate.$_} | ForEach-Object {
        $Miner_HashRates += "$($Miner_HashRate.$_ | ConvertTo-Hash)/s | "
    }
    $MinerInfo = "$($Miner.Type) miner '$($Miner.Name)' [GPU Devices: $($Miner.Index)]' ($($Miner.Algorithm -join '|')) [API: $($Miner.API), Port: $($Miner.Port)]"
    Write-Log -Message "Saving stats for $($MinerInfo): [ $Miner_HashRates$($Miner_PowerDraw.ToString("N2")) W | $($Miner_ComputeUsage.ToString("N2"))% ]... "

    $Miner.Algorithm | Where-Object {$Miner_HashRate.$_} | ForEach-Object {
    
        $Stat = Set-Stat -Name "$($Miner.Name)_$($_)_HashRate" -Value $Miner_HashRate.$_ -Duration $StatSpan -FaultDetection $true

        #Update watchdog timer
        $Miner_Algorithm = $_
        $WatchdogTimer = $WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm}
        if ($Stat -and $WatchdogTimer -and $Stat.Updated -gt $WatchdogTimer.Kicked) {
            $WatchdogTimer.Kicked = $Stat.Updated
        }
    }
    $Miner.New = $false
    # Update power stats
    if ($Miner_PowerDraw -gt 0) {
        $Stat = Set-Stat -Name "$($Miner.Name)_$($_.Algorithm -join '')_PowerDraw" -Value $Miner_PowerDraw -Duration $StatSpan -FaultDetection $false
    }
    # Update ComputeUsage stats
    if ($Miner_ComputeUsage -gt 0) {
        $Stat = Set-Stat -Name "$($Miner.Name)_$($_.Algorithm -join '')_ComputeUsage" -Value $Miner_ComputeUsage -Duration $StatSpan -FaultDetection $false
    }
}

function Get-GPUdevices {

# UselessGuru: returns a data structure containing all found OpenCL devices like
#
# Type : AMD
# Device : {}
# Type : NVIDIA
# Device : {@{Type=NVIDIA; Device=GeForce GTX 1080 Ti; Device_Norm=GeforceGTX1080Ti; Vendor=NVIDIA Corporation; Devices=System.Object[]}, @{Type=NVIDIA; Device=GeForce GTX 1060 3GB;
# Device_Norm=GeforceGTX10603GB; Vendor=NVIDIA Corporation; Devices=System.Object[]}}

[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$MinerType,
        [Parameter(Mandatory = $false)]
        [bool]$DeviceSubTypes = $false
    )

    $SimulateExtraHW = $false
    $SimulateAMD = $false

    $GPUs = @()
    $MinerType | ForEach {

        $Miner_Type = $_
        $Devices = @()
        $Device_ID = 0
        $MinerType_Devices = @()

        if ($DeviceSubTypes) {
            [OpenCl.Platform]::GetPlatformIDs() | ForEach-Object {[OpenCl.Device]::GetDeviceIDs($_, [OpenCl.DeviceType]::All)} | Where {$_.Type -eq "GPU" -and $_.Vendor -match "^$($Miner_Type) .+"} | ForEach-Object {
                $Device = $_.Name
                $GPU = [PSCustomObject]@{
                    Type = $Miner_Type
                    Device = $Device
                    Device_Norm = (Get-Culture).TextInfo.ToTitleCase(($Device -replace "-", " " -replace "_", " ")) -replace " "
                    Vendor = $_.Vendor
                    Devices = @("$Device_ID")
                }            
                if ($MinerType_Devices.Type -contains $Miner_Type -and $MinerType_Devices.Device -contains $Device) {
                    $MinerType_Devices | Where {$_.Type -eq $Miner_Type -and $_.Device -eq $Device} | ForEach {$_.Devices += "$Device_ID"}
                }
                else {
                    $MinerType_Devices += $GPU
                }
                $Device_ID++
            }
           if ($SimulateExtraHW) {
                # Simulate more HW   
                [OpenCl.Platform]::GetPlatformIDs() | ForEach-Object {[OpenCl.Device]::GetDeviceIDs($_, [OpenCl.DeviceType]::All)} | Where {$_.Type -eq "GPU" -and $_.Vendor -match "^$($Miner_Type) .+"} | ForEach-Object {
                    $Device = $_.Name
                    $GPU = [PSCustomObject]@{
                        Type = $Miner_Type
                        Device = $Device
                        Device_Norm = (Get-Culture).TextInfo.ToTitleCase(($Device -replace "-", " " -replace "_", " ")) -replace " "
                        Vendor = $_.Vendor
                        Devices = @("$Device_ID")
                    }            
                    if ($MinerType_Devices.Type -contains $Miner_Type -and $MinerType_Devices.Device -contains $Device) {
                        $MinerType_Devices | Where {$_.Type -eq $Miner_Type -and $_.Device -eq $Device} | ForEach {$_.Devices += "$Device_ID"}
                    }
                    else {
                        $MinerType_Devices += $GPU
                    }
                    $Device_ID++
                }
                [OpenCl.Platform]::GetPlatformIDs() | ForEach-Object {[OpenCl.Device]::GetDeviceIDs($_, [OpenCl.DeviceType]::All)} | Where {$_.Type -eq "GPU" -and $_.Vendor -match "^$($Miner_Type) .+"} | ForEach-Object {
                    $Device = $_.Name
                    $GPU = [PSCustomObject]@{
                        Type = $Miner_Type
                        Device = $Device
                        Device_Norm = (Get-Culture).TextInfo.ToTitleCase(($Device -replace "-", " " -replace "_", " ")) -replace " "
                        Vendor = $_.Vendor
                        Devices = @("$Device_ID")
                    }            
                    if ($MinerType_Devices.Type -contains $Miner_Type -and $MinerType_Devices.Device -contains $Device) {
                        $MinerType_Devices | Where {$_.Type -eq $Miner_Type -and $_.Device -eq $Device} | ForEach {$_.Devices += "$Device_ID"}
                    }
                    else {
                        $MinerType_Devices += $GPU
                    }
                    $Device_ID++
                }
            }
        }
        else {
            [OpenCl.Platform]::GetPlatformIDs() | ForEach-Object {[OpenCl.Device]::GetDeviceIDs($_, [OpenCl.DeviceType]::All)} | Where {$_.Type -eq "GPU" -and $_.Vendor -match "^$($Miner_Type) .+"} | ForEach-Object {
                $Devices += $Device_ID
                $Device_ID++
                $Vendor = $_.Vendor
            }
            if ($Devices) {
                $MinerType_Devices += [PSCustomObject]@{
                    Type = $Miner_Type
                    Device = $Miner_Type
                    Device_Norm = $Miner_Type
                    Vendor = $Vendor
                    Devices = $Devices
                }
            }
        }                
        Sleep 0
        if ($MinerType_Devices) {
            $GPUs += [PSCustomObject]@{
                Type = $Miner_Type
                Device = $MinerType_Devices
            }
        }
    }   
    if ($SimulateAMD) { # Fake AMD card with DeviceID 2
        $GPU= [PSCustomObject]@{
            Type = "AMD"
            Device = "Fake AMD Card"
            Device_Norm = "FakeAMDCard"
            Vendor = "AMD Fake Corp."
            Devices = @("2")
        }
        $Devices = @()
        $Devices += $GPU
        $GPUs += [PSCustomObject]@{
            Type = "AMD"
            Device = $Devices
        }
    }
    $GPUs
}

function Get-CommandPerDevice {
# UselessGuru: Split command into seprate command tokens
#
# Supported parameter syntax:
# -param-name[ value1[,value2[,..]]]
# -param-name[=value1[,value2[,..]]]
# --param-name[==value1[,value2[,..]]]
# --param-name[=value1[,value2[,..]]]

[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [String]$Command,
        [Parameter(Mandatory = $false)]
        [Int[]]$Devices
    )
    
    # Write-Log -Level "Debug" -Message "Entering $($MyInvocation.MyCommand): '`$Command=$($Command)', '`$Devices=$($Devices)'"
    
    if ($Devices.count -gt 0) {
        # Only required if more than one different card in system
        $Tokens = @()

        ($Command + " ") -split "(?= --)" -split "(?= -)" | ForEach {
            $Token = $_.Trim()
            if ($Token.length -gt 0) {
                if ($Token -match "^-[a-zA-Z0-9]{1}[a-zA-Z0-9-\+]{0,}[\s]{1,}.*,") {
                    # -param-name[ value1[,value2[,..]]]
                    $Tokens += [PSCustomObject]@{
                        Parameter = $Token.Split(" ")[0]
                        ParamValueSeparator = " "
                        ValueSeparator = ","
                        Values = @($Token.Split(" ")[1].Split(","))
                    }
                }
                elseif ($Token -match "^-[a-zA-Z0-9]{1}[a-zA-Z0-9-\+]{0,}=[^=].*,") {
                    # -param-name[=value1[,value2[,..]]]
                    $Tokens += [PSCustomObject]@{
                        Parameter = $Token.Split("=")[0]
                        ParamValueSeparator = "="
                        ValueSeparator = ","
                        Values = @($Token.Split("=")[1].Split(","))
                    }
                }
                elseif ($Token -match "^--[a-zA-Z0-9]{1}[a-zA-Z0-9-\+]{0,}==[^=].*,") {
                    # --param-name[==value1[,value2[,..]]]
                    $Tokens += [PSCustomObject]@{
                        Parameter = $Token.Split("==")[0]
                        ParamValueSeparator = "=="
                        ValueSeparator = ","
                        Values = @($Token.Split("==")[2].Split(","))
                    }
                }
                elseif ($Token -match "^--[a-zA-Z0-9]{1}[a-zA-Z0-9-\+]{0,}=[^=].*,") {
                    # --param-name[=value1[,value2[,..]]]
                    $Tokens += [PSCustomObject]@{
                        Parameter = $Token.Split("=")[0]
                        ParamValueSeparator = "="
                        ValueSeparator = ","
                        Values = @($Token.Split("=")[1].Split(","))
                    }
                }
                else {
                    $Tokens += [PSCustomObject]@{Parameter = $Token}
                }

            }
        }
        
        # Build command token for selected gpu device
        [String]$Command = ""
        $Tokens | ForEach-Object {
            if ($_.Values.Count) {
                $Token = $_
                $Values = @()
                $Devices | ForEach {
                    if ($Token.Values[$_]) {$Values += $Token.Values[$_]}
                    else {$Values += ""}
                }
                if ($Values -match "\w") {$Command += " $($Token.Parameter)$($Token.ParamValueSeparator)$($Values -join $($Token.ValueSeparator))"}
            }
            else {
                $Command += " $($_.Parameter)"
            }
        }
    }
    
    # Write-Log -Level "Debug" -Message "Exiting $($MyInvocation.MyCommand): '`$Command='$($Command)'"
    
    $Command
}

function Get-ComputeData {

#UselessGuru: reads current GPU compute usage and power draw and from device
#
# returned values are:
#         PowerDraw:    0 - max (in watts)
#         ComputeUsage: 0 - 100 (percent)
#  Requirements for Nvidia:  nvidia-smi.exe (part of driver package)
#  Requirements for AMD:     unknown

[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String[]]$MinerType,
        [Parameter(Mandatory = $false)]
        [String]$Index
    )

    # Write-Log -Level "Debug" -Message "Entering $($MyInvocation.MyCommand): '`$MinerType=$($MinerType)', '`$Index=$($Index)'"

    $ComputerUsageSum = 0
    $ComputeUsageCount = 0

    $PowerDrawSum = 0
    
    switch ($MinerType) {
        "NVIDIA" {
            $NvidiaSMI = "$Env:SystemDrive\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
            if (Test-Path $NvidiaSMI) {
                if ($Index -notmatch "^[0-9].*") { <# Index bust start with a number, otherwise read cumulated power#>
                    $Index = ((&$NvidiaSMI -L) | ForEach {$_.Split(" ")[1].Split(":")[0]}) -join ","
                }
                $Index.Split(",") | ForEach {
                    $idx = $_
                    $Loop = 1
                    do {
                        $Readout = (&$NvidiaSMI -i $idx --format=csv,noheader,nounits --query-gpu=utilization.gpu)
                        # Write-Log -Level "Debug" -Message "$($MyInvocation.MyCommand) reading GPU usage [Try $($Loop) of 3]: '`$MinerType=$($MinerType)', '`$Index=$($Index)', '`$Idx=$($Idx)', '`$Readout=$($Readout)'"
                        Try {
                            $ComputeUsageSum += [Decimal]$Readout
                            if ($Readout -gt 0) {$ComputeUsageCount++}
                        }
                        catch {}
                        $Loop++
                    }
                    until ($Readout -gt 0 -or $Loop -gt 3)
                    
                    if ($Readout -gt 0) {
                        $Loop = 1
                        do {
                            $Readout = (&$NvidiaSMI -i $idx --format=csv,noheader,nounits --query-gpu=power.draw)
                            # Write-Log -Level "Debug" -Message "$($MyInvocation.MyCommand) reading power draw [Try $($Loop) of 3]: '`$MinerType=$($MinerType)', '`$Index=$($Index)', '`$Idx=$($Idx)', '`$Readout=$($Readout)'"
                            try {
                                $PowerDrawSum += [Decimal]$Readout
                            }
                            catch {}
                            $Loop ++
                        }
                        until ($Readout -gt 0 -or $Loop -gt 3)
                    }
                }
            }
        }
#        "AMD" { # To be implemented
#            for ($i = 0; $i -lt (&$NvidiaSMI -L).Count; $i++) {
#                $PowerDraw =+ [Double](&$NvidiaSMI -i $i --format=csv,noheader,nounits --query-gpu=power.draw)
#                $ComputeUsageSum =+ [Double](&$NvidiaSMI -i $i --format=csv,noheader,nounits --query-gpu=utilization.gpu)
#            }
#            $ComputeUsageCount += $i
#        }
        "CPU"  {
            $PowerDrawSum += $CPU_PowerDraw
            $ComputeUsageSum += 100
            $ComputeUsageCount++
        }
    }

    if ($ComputeUsageSum -gt 0 -and $ComputeUsageSum -gt 0) {$ComputeUsage = $ComputeUsageSum / $ComputeUsageCount} else {$ComputeUsage = 0}

    $ComputeData = [PSCustomObject]@{
        PowerDraw    = [Decimal]$PowerDrawSum
        ComputeUsage = [Decimal]$ComputeUsage
    }

    # Write-Log -Level "Debug" -Message "Exiting $($MyInvocation.MyCommand): '`$ComputeData=$($ComputeData)'"

    $ComputeData
}

Function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)][ValidateNotNullOrEmpty()][Alias("LogContent")][string]$Message,
        [Parameter(Mandatory=$false)][ValidateSet("Error","Warn","Info","Debug")][string]$Level = "Info"
    )

    Begin {
        $VerbosePreference = 'Continue'
    }
    Process {
        $filename = ".\Logs\MultiPoolMiner-$(Get-Date -Format "yyyy-MM-dd").txt"
        $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        switch($Level) {
            'Error' {
                $LevelText = 'ERROR:'
                Write-Host -ForegroundColor Red -Object "$date $LevelText $Message"
            }
            'Warn' {
                $LevelText = 'WARNING:'
                Write-Host -ForegroundColor Yellow -Object "$date $LevelText $Message"
            }
            'Info' {
                $LevelText = 'INFO:'
                Write-Host -ForegroundColor DarkCyan -Object "$date $LevelText $Message"
            }
            'Debug' {
                $LevelText = 'DEBUG:'
                Write-Host -ForegroundColor Gray -Object "$date $LevelText $Message"
            }
        }
        try {
            "$date $LevelText $Message" | Out-File -FilePath $filename -Append -ErrorAction SilentlyContinue
        }
        catch {
            Sleep 0.2
            "$date $LevelText $Message" | Out-File -FilePath $filename -Append -ErrorAction SilentlyContinue
        }
    }
    End {}
}

function Set-Stat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Name, 
        [Parameter(Mandatory = $true)]
        [Double]$Value, 
        [Parameter(Mandatory = $false)]
        [DateTime]$Updated = (Get-Date).ToUniversalTime(), 
        [Parameter(Mandatory = $true)]
        [TimeSpan]$Duration, 
        [Parameter(Mandatory = $false)]
        [Bool]$FaultDetection = $false, 
        [Parameter(Mandatory = $false)]
        [Bool]$ChangeDetection = $false
    )

    $Updated = $Updated.ToUniversalTime()

    $Path = "Stats\$Name.txt"
    $SmallestValue = 1E-20

    try {
        $Stat = Get-Content $Path -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

        $Stat = [PSCustomObject]@{
            Live = [Double]$Stat.Live
            Minute = [Double]$Stat.Minute
            Minute_Fluctuation = [Double]$Stat.Minute_Fluctuation
            Minute_5 = [Double]$Stat.Minute_5
            Minute_5_Fluctuation = [Double]$Stat.Minute_5_Fluctuation
            Minute_10 = [Double]$Stat.Minute_10
            Minute_10_Fluctuation = [Double]$Stat.Minute_10_Fluctuation
            Hour = [Double]$Stat.Hour
            Hour_Fluctuation = [Double]$Stat.Hour_Fluctuation
            Day = [Double]$Stat.Day
            Day_Fluctuation = [Double]$Stat.Day_Fluctuation
            Week = [Double]$Stat.Week
            Week_Fluctuation = [Double]$Stat.Week_Fluctuation
            Duration = [TimeSpan]$Stat.Duration
            Updated = [DateTime]$Stat.Updated
        }

        $ToleranceMin = $Value
        $ToleranceMax = $Value

        if ($FaultDetection) {
            $ToleranceMin = $Stat.Week * (1 - [Math]::Min([Math]::Max($Stat.Week_Fluctuation * 2, 0.1), 0.9))
            $ToleranceMax = $Stat.Week * (1 + [Math]::Min([Math]::Max($Stat.Week_Fluctuation * 2, 0.1), 0.9))
        }

        if ($ChangeDetection -and $Value -eq $Stat.Live) {$Updated -eq $Stat.updated}

        if ($Value -lt $ToleranceMin -or $Value -gt $ToleranceMax) {
            Write-Warning "Stat file ($Name) was not updated because the value ($([Decimal]$Value)) is outside fault tolerance ($([Int]$ToleranceMin) ... $([Int]$ToleranceMax)). "
        }
        else {
            $Span_Minute = [Math]::Min($Duration.TotalMinutes / [Math]::Min($Stat.Duration.TotalMinutes, 1), 1)
            $Span_Minute_5 = [Math]::Min(($Duration.TotalMinutes / 5) / [Math]::Min(($Stat.Duration.TotalMinutes / 5), 1), 1)
            $Span_Minute_10 = [Math]::Min(($Duration.TotalMinutes / 10) / [Math]::Min(($Stat.Duration.TotalMinutes / 10), 1), 1)
            $Span_Hour = [Math]::Min($Duration.TotalHours / [Math]::Min($Stat.Duration.TotalHours, 1), 1)
            $Span_Day = [Math]::Min($Duration.TotalDays / [Math]::Min($Stat.Duration.TotalDays, 1), 1)
            $Span_Week = [Math]::Min(($Duration.TotalDays / 7) / [Math]::Min(($Stat.Duration.TotalDays / 7), 1), 1)

            $Stat = [PSCustomObject]@{
                Live = $Value
                Minute = ((1 - $Span_Minute) * $Stat.Minute) + ($Span_Minute * $Value)
                Minute_Fluctuation = ((1 - $Span_Minute) * $Stat.Minute_Fluctuation) + 
                ($Span_Minute * ([Math]::Abs($Value - $Stat.Minute) / [Math]::Max([Math]::Abs($Stat.Minute), $SmallestValue)))
                Minute_5 = ((1 - $Span_Minute_5) * $Stat.Minute_5) + ($Span_Minute_5 * $Value)
                Minute_5_Fluctuation = ((1 - $Span_Minute_5) * $Stat.Minute_5_Fluctuation) + 
                ($Span_Minute_5 * ([Math]::Abs($Value - $Stat.Minute_5) / [Math]::Max([Math]::Abs($Stat.Minute_5), $SmallestValue)))
                Minute_10 = ((1 - $Span_Minute_10) * $Stat.Minute_10) + ($Span_Minute_10 * $Value)
                Minute_10_Fluctuation = ((1 - $Span_Minute_10) * $Stat.Minute_10_Fluctuation) + 
                ($Span_Minute_10 * ([Math]::Abs($Value - $Stat.Minute_10) / [Math]::Max([Math]::Abs($Stat.Minute_10), $SmallestValue)))
                Hour = ((1 - $Span_Hour) * $Stat.Hour) + ($Span_Hour * $Value)
                Hour_Fluctuation = ((1 - $Span_Hour) * $Stat.Hour_Fluctuation) + 
                ($Span_Hour * ([Math]::Abs($Value - $Stat.Hour) / [Math]::Max([Math]::Abs($Stat.Hour), $SmallestValue)))
                Day = ((1 - $Span_Day) * $Stat.Day) + ($Span_Day * $Value)
                Day_Fluctuation = ((1 - $Span_Day) * $Stat.Day_Fluctuation) + 
                ($Span_Day * ([Math]::Abs($Value - $Stat.Day) / [Math]::Max([Math]::Abs($Stat.Day), $SmallestValue)))
                Week = ((1 - $Span_Week) * $Stat.Week) + ($Span_Week * $Value)
                Week_Fluctuation = ((1 - $Span_Week) * $Stat.Week_Fluctuation) + 
                ($Span_Week * ([Math]::Abs($Value - $Stat.Week) / [Math]::Max([Math]::Abs($Stat.Week), $SmallestValue)))
                Duration = $Stat.Duration + $Duration
                Updated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if (Test-Path $Path) {Write-Warning "Stat file ($Name) is corrupt and will be reset. "}

        $Stat = [PSCustomObject]@{
            Live = $Value
            Minute = $Value
            Minute_Fluctuation = 1
            Minute_5 = $Value
            Minute_5_Fluctuation = 1
            Minute_10 = $Value
            Minute_10_Fluctuation = 1
            Hour = $Value
            Hour_Fluctuation = 1
            Day = $Value
            Day_Fluctuation = 1
            Week = $Value
            Week_Fluctuation = 1
            Duration = $Duration
            Updated = (Get-Date).ToUniversalTime()
        }
    }

    if (-not (Test-Path "Stats")) {New-Item "Stats" -ItemType "directory" | Out-Null}
    [PSCustomObject]@{
        Live = [Decimal]$Stat.Live
        Minute = [Decimal]$Stat.Minute
        Minute_Fluctuation = [Double]$Stat.Minute_Fluctuation
        Minute_5 = [Decimal]$Stat.Minute_5
        Minute_5_Fluctuation = [Double]$Stat.Minute_5_Fluctuation
        Minute_10 = [Decimal]$Stat.Minute_10
        Minute_10_Fluctuation = [Double]$Stat.Minute_10_Fluctuation
        Hour = [Decimal]$Stat.Hour
        Hour_Fluctuation = [Double]$Stat.Hour_Fluctuation
        Day = [Decimal]$Stat.Day
        Day_Fluctuation = [Double]$Stat.Day_Fluctuation
        Week = [Decimal]$Stat.Week
        Week_Fluctuation = [Double]$Stat.Week_Fluctuation
        Duration = [String]$Stat.Duration
        Updated = [DateTime]$Stat.Updated
    } | ConvertTo-Json | Set-Content $Path

    $Stat
}

function Get-Stat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Name
    )

    if (-not (Test-Path "Stats")) {New-Item "Stats" -ItemType "directory" | Out-Null}
    Get-ChildItem "Stats" | Where-Object Extension -NE ".ps1" | Where-Object BaseName -EQ $Name | Get-Content | ConvertFrom-Json
}

function Get-ChildItemContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Path, 
        [Parameter(Mandatory = $false)]
        [Hashtable]$Parameters = @{}
    )

    Get-ChildItem $Path -Exclude "_*" | ForEach-Object { <# UselessGura added -Exclude "_*"; all files beginning with _ will be ignored #>
#    Get-ChildItem $Path | ForEach-Object {
        $Name = $_.BaseName
        $Content = @()
        if ($_.Extension -eq ".ps1") {
            $Content = & {
                $Parameters.Keys | ForEach-Object {Set-Variable $_ $Parameters[$_]}
                & $_.FullName @Parameters
            }
        }
        else {
            $Content = & {
                $Parameters.Keys | ForEach-Object {Set-Variable $_ $Parameters[$_]}
                try {
                    ($_ | Get-Content | ConvertFrom-Json) | ForEach-Object {
                        $Item = $_
                        $ItemKeys = $Item.PSObject.Properties.Name.Clone()
                        $ItemKeys | ForEach-Object {
                            if ($Item.$_ -is [String]) {
                                $Item.$_ = Invoke-Expression "`"$($Item.$_)`""
                            }
                            elseif ($Item.$_ -is [PSCustomObject]) {
                                $Property = $Item.$_
                                $PropertyKeys = $Property.PSObject.Properties.Name
                                $PropertyKeys | ForEach-Object {
                                    if ($Property.$_ -is [String]) {
                                        $Property.$_ = Invoke-Expression "`"$($Property.$_)`""
                                    }
                                }
                            }
                        }
                        $Item
                    }
                }
                catch [ArgumentException] {
                    $null
                }
            }
            if ($Content -eq $null) {$Content = $_ | Get-Content}
        }
        $Content | ForEach-Object {
            if ($_.Name) {
                [PSCustomObject]@{Name = $_.Name; Content = $_}
            }
            else {
                [PSCustomObject]@{Name = $Name; Content = $_}
            }
        }
#		$Content | ForEach-Object {
#            [PSCustomObject]@{Name = $Name; Content = $_}
#        }
    }
}

filter ConvertTo-Hash { 
    [CmdletBinding()]
    $Hash = $_
    switch ([math]::truncate([math]::log($Hash, [Math]::Pow(1000, 1)))) {
        "-Infinity" {"0  H"}
        0 {"{0:n2}  H" -f ($Hash / [Math]::Pow(1000, 0))}
        1 {"{0:n2} KH" -f ($Hash / [Math]::Pow(1000, 1))}
        2 {"{0:n2} MH" -f ($Hash / [Math]::Pow(1000, 2))}
        3 {"{0:n2} GH" -f ($Hash / [Math]::Pow(1000, 3))}
        4 {"{0:n2} TH" -f ($Hash / [Math]::Pow(1000, 4))}
        Default {"{0:n2} PH" -f ($Hash / [Math]::Pow(1000, 5))}
    }
}

function Get-Combination {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Array]$Value, 
        [Parameter(Mandatory = $false)]
        [Int]$SizeMax = $Value.Count, 
        [Parameter(Mandatory = $false)]
        [Int]$SizeMin = 1
    )

    $Combination = [PSCustomObject]@{}

    for ($i = 0; $i -lt $Value.Count; $i++) {
        $Combination | Add-Member @{[Math]::Pow(2, $i) = $Value[$i]}
    }

    $Combination_Keys = $Combination | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

    for ($i = $SizeMin; $i -le $SizeMax; $i++) {
        $x = [Math]::Pow(2, $i) - 1

        while ($x -le [Math]::Pow(2, $Value.Count) - 1) {
            [PSCustomObject]@{Combination = $Combination_Keys | Where-Object {$_ -band $x} | ForEach-Object {$Combination.$_}}
            $smallest = ($x -band - $x)
            $ripple = $x + $smallest
            $new_smallest = ($ripple -band - $ripple)
            $ones = (($new_smallest / $smallest) -shr 1) - 1
            $x = $ripple -bor $ones
        }
    }
}

function Start-SubProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath, 
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "", 
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = "", 
        [ValidateRange(-2, 3)]
        [Parameter(Mandatory = $false)]
        [Int]$Priority = 0,
        [Parameter(Mandatory = $false)] <# UselessGuru #>
        [String]$MinerWindowStyle = "Minimized" <# UselessGuru #>
    )

    $PriorityNames = [PSCustomObject]@{-2 = "Idle"; -1 = "BelowNormal"; 0 = "Normal"; 1 = "AboveNormal"; 2 = "High"; 3 = "RealTime"}

    $Job = Start-Job -ArgumentList $PID, $FilePath, $ArgumentList, $WorkingDirectory, $MinerWindowStyle {
        param($ControllerProcessID, $FilePath, $ArgumentList, $WorkingDirectory, $MinerWindowStyle)

        $ControllerProcess = Get-Process -Id $ControllerProcessID
        if ($ControllerProcess -eq $null) {return}

        $ProcessParam = @{}
        $ProcessParam.Add("FilePath", $FilePath)
        $ProcessParam.Add("WindowStyle", $MinerWindowStyle) <# UselessGuru #>
        <# $ProcessParam.Add("WindowStyle", 'Minimized') UselessGuru #>
        if ($ArgumentList -ne "") {$ProcessParam.Add("ArgumentList", $ArgumentList)}
        if ($WorkingDirectory -ne "") {$ProcessParam.Add("WorkingDirectory", $WorkingDirectory)}
        $Process = Start-Process @ProcessParam -PassThru
        if ($Process -eq $null) {
            [PSCustomObject]@{ProcessId = $null}
            return        
        }

        [PSCustomObject]@{ProcessId = $Process.Id; ProcessHandle = $Process.Handle}

        $ControllerProcess.Handle | Out-Null
        $Process.Handle | Out-Null

        do {if ($ControllerProcess.WaitForExit(1000)) {$Process.CloseMainWindow() | Out-Null}}
        while ($Process.HasExited -eq $false)
    }

    do {Start-Sleep 1; $JobOutput = Receive-Job $Job}
    while ($JobOutput -eq $null)

    $Process = Get-Process | Where-Object Id -EQ $JobOutput.ProcessId
    $Process.Handle | Out-Null
    $Process

    if ($Process) {$Process.PriorityClass = $PriorityNames.$Priority}
}

function Expand-WebRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Uri, 
        [Parameter(Mandatory = $false)]
        [String]$Path = ""
    )

    if (-not $Path) {$Path = Join-Path ".\Downloads" ([IO.FileInfo](Split-Path $Uri -Leaf)).BaseName}
    if (-not (Test-Path ".\Downloads")) {New-Item "Downloads" -ItemType "directory" | Out-Null}
    $FileName = Join-Path ".\Downloads" (Split-Path $Uri -Leaf)

    if (Test-Path $FileName) {Remove-Item $FileName}
    Invoke-WebRequest $Uri -OutFile $FileName -UseBasicParsing

    if (".msi", ".exe" -contains ([IO.FileInfo](Split-Path $Uri -Leaf)).Extension) {
        Start-Process $FileName "-qb" -Wait
    }
    else {
        $Path_Old = (Join-Path (Split-Path $Path) ([IO.FileInfo](Split-Path $Uri -Leaf)).BaseName)
        $Path_New = (Join-Path (Split-Path $Path) (Split-Path $Path -Leaf))

        if (Test-Path $Path_Old) {Remove-Item $Path_Old -Recurse}
        Start-Process "7z" "x `"$([IO.Path]::GetFullPath($FileName))`" -o`"$([IO.Path]::GetFullPath($Path_Old))`" -y -spe" -Wait

        if (Test-Path $Path_New) {Remove-Item $Path_New -Recurse}
        if (Get-ChildItem $Path_Old | Where-Object PSIsContainer -EQ $false) {
            Rename-Item $Path_Old (Split-Path $Path -Leaf)
        }
        else {
            Get-ChildItem $Path_Old | Where-Object PSIsContainer -EQ $true | ForEach-Object {Move-Item (Join-Path $Path_Old $_) $Path_New}
            Remove-Item $Path_Old
        }
    }
}

function Invoke-TcpRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Server = "localhost", 
        [Parameter(Mandatory = $true)]
        [String]$Port, 
        [Parameter(Mandatory = $true)]
        [String]$Request, 
        [Parameter(Mandatory = $true)]
        [Int]$Timeout = 10 #seconds
    )

    try {
        $Client = New-Object System.Net.Sockets.TcpClient $Server, $Port
        $Stream = $Client.GetStream()
        $Writer = New-Object System.IO.StreamWriter $Stream
        $Reader = New-Object System.IO.StreamReader $Stream
        $client.SendTimeout = $Timeout * 1000
        $client.ReceiveTimeout = $Timeout * 1000
        $Writer.AutoFlush = $true

        $Writer.WriteLine($Request)
        $Response = $Reader.ReadLine()
    }
    finally {
        if ($Reader) {$Reader.Close()}
        if ($Writer) {$Writer.Close()}
        if ($Stream) {$Stream.Close()}
        if ($Client) {$Client.Close()}
    }

    $Response
}

function Get-Algorithm {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Algorithm = ""
    )

    $Algorithms = Get-Content "Algorithms.txt" | ConvertFrom-Json

    $Algorithm = (Get-Culture).TextInfo.ToTitleCase(($Algorithm -replace "-", " " -replace "_", " ")) -replace " "

    if ($Algorithms.$Algorithm) {$Algorithms.$Algorithm}
    else {$Algorithm}
}

function Get-Region {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Region = ""
    )

    $Regions = Get-Content "Regions.txt" | ConvertFrom-Json

    $Region = (Get-Culture).TextInfo.ToTitleCase(($Region -replace "-", " " -replace "_", " ")) -replace " "

    if ($Regions.$Region) {$Regions.$Region}
    else {$Region}
}

class Miner {
    $Name
    $Path
    $Arguments
    $Wrap
    $API
    $Port
    $Algorithm
    $Type
    $Index
    $Device
    $Device_Auto
    $Profit
    $Profit_Comparison
    $Profit_MarginOfError
    $Profit_Bias
    $Speed
    $Speed_Live
    $Best
    $Best_Comparison
    $Process
    $New
    $Active
    $Activated
    $Status
    $Benchmarked
	<# Power power and profit calculation added by UselessGuru #>
    $Earning <# UselessGuru added Earning #>
    $PowerDraw <# Power consumption of all cards #>
    $PowerCost <# Total power draw  * $PowerPricePerKW #>
    $ComputeUsage <# UselessGuru added -MinerWindowStyle #>
    $Pool <# UselessGuru added Pool #>
    $MinerWindowStyle <# UselessGuru added MinerWindowStyle #>
    $UseNewMinerLauncher <# UselessGuru added UseNewMinerLauncher #>
    $ShowWindow <# UselessGuru added ShowWindow #>
    
    StartMining() {
        $this.New = $true
        $this.Activated++
        if ($this.Process -ne $null) {$this.Active += $this.Process.ExitTime - $this.Process.StartTime}
        # Begin UselessGuru added $UseNewMinerLauncher
        if ($this.UseNewMinerLauncher) {
            . .\MyInclude.ps1
            switch ($this.MinerWindowStyle) {
                "Normal"    {$this.ShowWindow = "SW_SHOW"}
                "Maximized" {$this.ShowWindow = "SW_SHOWMAXIMIZE"}
                "Minimized" {$this.ShowWindow = "SW_SHOWMINNOACTIVE"}
                "Hidden"    {$this.ShowWindow = "SW_HIDDEN"}
            }
            $this.Process = Invoke-CreateProcess -Binary $this.Path -Arguments $this.Arguments -CreationFlags CREATE_NEW_CONSOLE -ShowWindow $this.ShowWindow -StartF STARTF_USESHOWWINDOW -Priority BelowNormal -WorkingDirectory (Split-Path $this.Path)
        }
        else {
            $this.Process = Start-SubProcess -FilePath $this.Path -ArgumentList ($this.Arguments) -WorkingDirectory (Split-Path $this.Path) -Priority ($this.Type | ForEach-Object {if ($this -eq "CPU") {-2}else {-1}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -MinerWindowStyle $this.MinerWindowStyle <# UselessGuru added -MinerWindowStyle #>
        }
        # Begin UselessGuru added $UseNewMinerLauncher
        # $this.Process = Start-SubProcess -FilePath $this.Path -ArgumentList $this.Arguments -WorkingDirectory (Split-Path $this.Path) -Priority ($this.Type | ForEach-Object {if ($this -eq "CPU") {-2}else {-1}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -MinerWindowStyle $this.MinerWindowStyle <# UselessGuru added -MinerWindowStyle #>

        if ($this.Process -eq $null) {$this.Status = "Failed"}
        else {$this.Status = "Running"}
    }

    StopMining() {
        $this.Process.CloseMainWindow() | Out-Null
        $this.Status = "Idle"
    }
}