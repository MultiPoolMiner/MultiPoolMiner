Set-Location (Split-Path $MyInvocation.MyCommand.Path)

try { 
    Add-Type -Path .\~OpenCL.dll -ErrorAction Stop
}
catch { 
    Remove-Item .\~OpenCL.dll -Force -ErrorAction Ignore
    Add-Type -Path .\OpenCL\*.cs -OutputAssembly ~OpenCL.dll
    Add-Type -Path .\~OpenCL.dll
}

try { 
    Add-Type -Path .\~MonoTorrent.dll -ErrorAction Stop
}
catch { 
    try { 
        Remove-Item .\~MonoTorrent.dll -Force -ErrorAction Ignore
        Add-Type -Path (".\MonoTorrent\*.cs" | Get-ChildItem -Recurse).FullName -IgnoreWarnings -WarningAction SilentlyContinue -ReferencedAssemblies "System.Xml" -OutputAssembly ~MonoTorrent.dll -ErrorAction Stop
    }
    catch { 
        Remove-Item .\~MonoTorrent.dll -Force -ErrorAction Ignore
        Add-Type -Path (".\MonoTorrent\*.cs" | Get-ChildItem -Recurse).FullName -IgnoreWarnings -WarningAction SilentlyContinue -OutputAssembly ~MonoTorrent.dll
    }

    Add-Type -Path .\~MonoTorrent.dll
}

try { 
    Add-Type -Path .\~CPUID.dll -ErrorAction Stop
}
catch { 
    Remove-Item .\~CPUID.dll -Force -ErrorAction Ignore
    Add-Type -Path .\CPUID.cs -OutputAssembly ~CPUID.dll
    Add-Type -Path .\~CPUID.dll
}

function Get-MinerConfig { 

    #Read miner config

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Name, 
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )

    $Miner_BaseName = $Name -split '-' | Select-Object -Index 0
    $Miner_Version = $Name -split '-' | Select-Object -Index 1
    $Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
    if (-not $Miner_Config) { $Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*" }

    return $Miner_Config
}

#Function to be removed
function Update-APIDeviceStatus { 

    #Update device status in API

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [HashTable]$Api, 
        [Parameter(Mandatory = $false)]
        [Array]$Devices
    )

    $API.AllDevices | ForEach-Object { 
        if ($Devices.Name -contains $_.Name) { 
            if ($Miner = $API.FailedMiners | Where-Object DeviceName -contains $_.Name) { $_ | Add-Member Status "Failed ($($Miner.BaseName)-$($Miner.Version) {$(($Miner.Algorithm | ForEach-Object { "$($_)@$($Miner.PoolName | Select-Object -Index ([array]::indexof($Miner.Algorithm, $_)))" }) -join "; ")})" -Force }
            elseif ($Miner = $API.RunningMiners | Where-Object DeviceName -contains $_.Name) { 
                if ($Miner.Speed -contains $null) { 
                    $_ | Add-Member Status "Benchmarking ($($Miner.BaseName)-$($Miner.Version) {$(($Miner.Algorithm | ForEach-Object { "$($_)@$($Miner.PoolName | Select-Object -Index ([array]::indexof($Miner.Algorithm, $_)))" }) -join "; ")})" -Force
                }
                else { 
                    $_ | Add-Member Status "Running ($($Miner.BaseName)-$($Miner.Version) {$(($Miner.Algorithm | ForEach-Object { "$($_)@$($Miner.PoolName | Select-Object -Index ([array]::indexof($Miner.Algorithm, $_)))" }) -join "; ")})" -Force
                }
            }
            else { $_ | Add-Member Status "Idle" -Force }
        }
        else { $_ | Add-Member Status "Disabled" -Force }
    }
}

function Get-PrePostCommand { 

    #Get Pre / Post miner exec commands

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Miner, 
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config, 
        [Parameter(Mandatory = $true)]
        [String]$Event
    )

    try { 
        $Miner_Config = $Config.MinersLegacy.($Miner.BaseName).($Miner.Version)
        if (-not $Miner_Config."$($Event)Command") { $Miner_Config = $Config.MinersLegacy.($Miner.BaseName)."*" }
        if (-not $Miner_Config."$($Event)Command") { $Miner_Config = $Config.MinersLegacy."*" }
    }
    catch { }

    return $Miner_Config."$($Event)Command"

}

function Start-PrePostCommand { 

    #Pre / Post miner exec commands

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Command, 
        [Parameter(Mandatory = $true)]
        [String]$Event
    )

    if ($Command) { 
        try { 
            Switch ($Event) { 
                "PreStart" { Write-Log "Executing ($Command) before miner start. " }
                "PostStart" { Write-Log "Executing ($Command) after miner start. " }
                "PreStop" { Write-Log "Executing ($Command) before miner stop. " }
                "PostStop" { Write-Log "Executing ($Command) after miner stop. " }
                "PostFailure" { Write-Log "Executing ($Command) after miner failure. " }
            }

            if ($Command -match "^'.*") { 
                $Exe = ($Command -split "' " | Select-Object -Index 0) -replace "'"
                $Arguments = @($Command -split "' " | Select-Object -Skip 1) -join ' '
            }
            else { 
                $Exe = ($Command -split ' ' | Select-Object -Index 0)
                $Arguments = @($Command -split ' ' | Select-Object -Skip 1) -join ' '
            }

            Start-Process $Exe $Arguments
        }
        catch { }
    }
}

function Get-CpuId { 

    # Brief : gets CPUID (CPU name and registers)

    #OS Features
    $OS_x64 = "" #not implemented
    $OS_AVX = "" #not implemented
    $OS_AVX512 = "" #not implemented

    #Vendor
    $vendor = "" #not implemented

    if ($vendor -eq "GenuineIntel") { 
        $Vendor_Intel = $true;
    }
    elseif ($vendor -eq "AuthenticAMD") { 
        $Vendor_AMD = $true;
    }

    $info = [CpuID]::Invoke(0)
    #convert 16 bytes to 4 ints for compatibility with existing code
    $info = [int[]]@(
        [BitConverter]::ToInt32($info, 0 * 4)
        [BitConverter]::ToInt32($info, 1 * 4)
        [BitConverter]::ToInt32($info, 2 * 4)
        [BitConverter]::ToInt32($info, 3 * 4)
    )

    $nIds = $info[0]

    $info = [CpuID]::Invoke(0x80000000)
    $nExIds = [BitConverter]::ToUInt32($info, 0 * 4) #not sure as to why 'nExIds' is unsigned; may not be necessary
    #convert 16 bytes to 4 ints for compatibility with existing code
    $info = [int[]]@(
        [BitConverter]::ToInt32($info, 0 * 4)
        [BitConverter]::ToInt32($info, 1 * 4)
        [BitConverter]::ToInt32($info, 2 * 4)
        [BitConverter]::ToInt32($info, 3 * 4)
    )

    #Detect Features
    $features = @{ }
    if ($nIds -ge 0x00000001) { 

        $info = [CpuID]::Invoke(0x00000001)
        #convert 16 bytes to 4 ints for compatibility with existing code
        $info = [int[]]@(
            [BitConverter]::ToInt32($info, 0 * 4)
            [BitConverter]::ToInt32($info, 1 * 4)
            [BitConverter]::ToInt32($info, 2 * 4)
            [BitConverter]::ToInt32($info, 3 * 4)
        )

        $features.MMX = ($info[3] -band ([int]1 -shl 23)) -ne 0
        $features.SSE = ($info[3] -band ([int]1 -shl 25)) -ne 0
        $features.SSE2 = ($info[3] -band ([int]1 -shl 26)) -ne 0
        $features.SSE3 = ($info[2] -band ([int]1 -shl 00)) -ne 0

        $features.SSSE3 = ($info[2] -band ([int]1 -shl 09)) -ne 0
        $features.SSE41 = ($info[2] -band ([int]1 -shl 19)) -ne 0
        $features.SSE42 = ($info[2] -band ([int]1 -shl 20)) -ne 0
        $features.AES = ($info[2] -band ([int]1 -shl 25)) -ne 0

        $features.AVX = ($info[2] -band ([int]1 -shl 28)) -ne 0
        $features.FMA3 = ($info[2] -band ([int]1 -shl 12)) -ne 0

        $features.RDRAND = ($info[2] -band ([int]1 -shl 30)) -ne 0
    }

    if ($nIds -ge 0x00000007) { 

        $info = [CpuID]::Invoke(0x00000007)
        #convert 16 bytes to 4 ints for compatibility with existing code
        $info = [int[]]@(
            [BitConverter]::ToInt32($info, 0 * 4)
            [BitConverter]::ToInt32($info, 1 * 4)
            [BitConverter]::ToInt32($info, 2 * 4)
            [BitConverter]::ToInt32($info, 3 * 4)
        )

        $features.AVX2 = ($info[1] -band ([int]1 -shl 05)) -ne 0

        $features.BMI1 = ($info[1] -band ([int]1 -shl 03)) -ne 0
        $features.BMI2 = ($info[1] -band ([int]1 -shl 08)) -ne 0
        $features.ADX = ($info[1] -band ([int]1 -shl 19)) -ne 0
        $features.MPX = ($info[1] -band ([int]1 -shl 14)) -ne 0
        $features.SHA = ($info[1] -band ([int]1 -shl 29)) -ne 0
        $features.PREFETCHWT1 = ($info[2] -band ([int]1 -shl 00)) -ne 0

        $features.AVX512_F = ($info[1] -band ([int]1 -shl 16)) -ne 0
        $features.AVX512_CD = ($info[1] -band ([int]1 -shl 28)) -ne 0
        $features.AVX512_PF = ($info[1] -band ([int]1 -shl 26)) -ne 0
        $features.AVX512_ER = ($info[1] -band ([int]1 -shl 27)) -ne 0
        $features.AVX512_VL = ($info[1] -band ([int]1 -shl 31)) -ne 0
        $features.AVX512_BW = ($info[1] -band ([int]1 -shl 30)) -ne 0
        $features.AVX512_DQ = ($info[1] -band ([int]1 -shl 17)) -ne 0
        $features.AVX512_IFMA = ($info[1] -band ([int]1 -shl 21)) -ne 0
        $features.AVX512_VBMI = ($info[2] -band ([int]1 -shl 01)) -ne 0
    }

    if ($nExIds -ge 0x80000001) { 

        $info = [CpuID]::Invoke(0x80000001)
        #convert 16 bytes to 4 ints for compatibility with existing code
        $info = [int[]]@(
            [BitConverter]::ToInt32($info, 0 * 4)
            [BitConverter]::ToInt32($info, 1 * 4)
            [BitConverter]::ToInt32($info, 2 * 4)
            [BitConverter]::ToInt32($info, 3 * 4)
        )

        $features.x64 = ($info[3] -band ([int]1 -shl 29)) -ne 0
        $features.ABM = ($info[2] -band ([int]1 -shl 05)) -ne 0
        $features.SSE4a = ($info[2] -band ([int]1 -shl 06)) -ne 0
        $features.FMA4 = ($info[2] -band ([int]1 -shl 16)) -ne 0
        $features.XOP = ($info[2] -band ([int]1 -shl 11)) -ne 0
    }

    # wrap data into PSObject
    [PSCustomObject]@{ 
        Vendor   = $vendor
        Name     = $name
        Features = $features.Keys.ForEach{ if ($features.$_) { $_ } }
    }
}

function Get-PowerUsage { 

    # Reads current power draw from devices
    #
    # returned values are: 
    # PowerDraw:    0 - max (in watts)
    #
    # Requirement: Running instance of HWiNFO64
    # https://www.hwinfo.com/download/
    #
    # For each device (CPU & GPU) the power usage sensor must be exposed to the HWiNFO Gadget
    # and the power sensor name must end in $DeviceName as found in the web GUI (http://localhost:3999/devices.html)
    # e.g. GPU Chip Power (RX 580) GPU#00
    #
    # For details see ConfigHWinfo64.pdf
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String[]]$DeviceNames
    )

    $HwINFO64_RegKey = "HKCU:\Software\HWiNFO64\VSB"

    if (Test-Path $HwINFO64_RegKey) { 
        $PowerUsage = [Float]0
        $Hashtable = @{ }

        $RegistryValue = Get-ItemProperty $HwINFO64_RegKey
        $RegistryValue.PSObject.Properties | Where-Object { $_.Name -match "^Label[0-9]+$" -and (Compare-Object @($_.Value -split ' ' | Select-Object) @($DeviceNames | Select-Object) -IncludeEqual -ExcludeDifferent) } | ForEach-Object { 
            $Hashtable[(($_.Value -split ' ') | Select-Object -last 1)] = $RegistryValue.($_.Name -replace "Label", "Value")
        }
        $DeviceNames | ForEach-Object { 
            $PowerUsage += [Float]($Hashtable.$_ -split ' ' | Select-Object -Index 0)
        }
    }

    $PowerUsage
}

function Get-CommandPerDevice { 

    # filters the command to contain only parameter values for present devices
    # if a parameter has multiple values, only the values for the available devices are included
    # parameters with a single value are valid for all devices and remain untouched
    # excluded parameters are passed unmodified

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [String]$Command = "", 
        [Parameter(Mandatory = $false)]
        [String[]]$ExcludeParameters = "", 
        [Parameter(Mandatory = $false)]
        [Int[]]$DeviceIDs
    )

    $CommandPerDevice = ""

    " $($Command.TrimStart().TrimEnd())" -split "(?=\s+[-]{1,2})" | ForEach-Object { 
        $Token = $_
        $Prefix = ""
        $ParameterValueSeparator = ""
        $ValueSeparator = ""
        $Values = ""

        if ($Token -match "(?:^\s[-=]+)" <#supported prefix characters are listed in brackets [-=]#>) { 
            $Prefix = "$($Token -split $Matches[0] | Select-Object -Index 0)$($Matches[0])"
            $Token = $Token -split $Matches[0] | Select-Object -Last 1

            if ($Token -match "(?:[ =]+)" <#supported separators are listed in brackets [ =]#>) { 
                $ParameterValueSeparator = $Matches[0]
                $Parameter = $Token -split $ParameterValueSeparator | Select-Object -Index 0
                $Values = $Token.Substring(("$Parameter$($ParameterValueSeparator)").length)

                if ($Parameter -notin $ExcludeParameters -and $Values -match "(?:[,; ]{1})" <#supported separators are listed in brackets [,; ]#>) { 
                    $ValueSeparator = $Matches[0]
                    $RelevantValues = @()
                    $DeviceIDs | ForEach-Object { 
                        $RelevantValues += ($Values.Split($ValueSeparator) | Select-Object -Index $_)
                    }
                    $CommandPerDevice += "$Prefix$Parameter$ParameterValueSeparator$($RelevantValues -join $ValueSeparator)"
                }
                else { $CommandPerDevice += "$Prefix$Parameter$ParameterValueSeparator$Values" }
            }
            else { $CommandPerDevice += "$Prefix$Token" }
        }
        else { $CommandPerDevice += $Token }
    }
    $CommandPerDevice
}

function Write-Log { 
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("LogContent")]
        [string]$Message, 
        [Parameter(Mandatory = $false)]
        [ValidateSet("Error", "Warn", "Info", "Verbose", "Debug")]
        [string]$Level = "Info"
    )

    Begin { }
    Process { 
        # Inherit the same verbosity settings as the script importing this
        if (-not $PSBoundParameters.ContainsKey('InformationPreference')) { $InformationPreference = $PSCmdlet.GetVariableValue('InformationPreference') }
        if (-not $PSBoundParameters.ContainsKey('Verbose')) { $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference') }
        if (-not $PSBoundParameters.ContainsKey('Debug')) { $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference') }

        # Get mutex named MPMWriteLog. Mutexes are shared across all threads and processes. 
        # This lets us ensure only one thread is trying to write to the file at a time. 
        $mutex = New-Object System.Threading.Mutex($false, "MPMWriteLog")

        $filename = ".\Logs\MultiPoolMiner_$(Get-Date -Format "yyyy-MM-dd").txt"
        $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        if (-not (Test-Path "Stats" -PathType Container)) { New-Item "Stats" -ItemType "directory" | Out-Null }

        switch ($Level) { 
            'Error' { 
                $LevelText = 'ERROR:'
                Write-Warning -Message $Message
            }
            'Warn' { 
                $LevelText = 'WARNING:'
                Write-Warning -Message $Message
            }
            'Info' { 
                $LevelText = 'INFO:'
                Write-Information -MessageData $Message
            }
            'Verbose' { 
                $LevelText = 'VERBOSE:'
                Write-Verbose -Message $Message
            }
            'Debug' { 
                $LevelText = 'DEBUG:'
                Write-Debug -Message $Message
            }
        }

        # Attempt to aquire mutex, waiting up to 1 second if necessary.  If aquired, write to the log file and release mutex.  Otherwise, display an error. 
        if ($mutex.WaitOne(1000)) { 
            "$date $LevelText $Message" | Out-File -FilePath $filename -Append -Encoding utf8
            $mutex.ReleaseMutex()
        }
        else { 
            Write-Error -Message "Log file is locked, unable to write message to $FileName."
        }
    }
    End { }
}

function Set-Stat { 
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Name, 
        [Parameter(Mandatory = $true)]
        [Double]$Value, 
        [Parameter(Mandatory = $false)]
        [DateTime]$Updated = (Get-Date), 
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

    $Stat = Get-Stat $Name

    if ($Stat -is [Hashtable] -and $Stat.IsSynchronized) { 
        $ToleranceMin = $Value
        $ToleranceMax = $Value

        if ($FaultDetection) { 
            $ToleranceMin = $Stat.Week * (1 - [Math]::Min([Math]::Max($Stat.Week_Fluctuation * 2, 0.1), 0.9))
            $ToleranceMax = $Stat.Week * (1 + [Math]::Min([Math]::Max($Stat.Week_Fluctuation * 2, 0.1), 0.9))
        }

        if ($ChangeDetection -and [Decimal]$Value -eq [Decimal]$Stat.Live) { $Updated = $Stat.updated }

        if ($Value -lt $ToleranceMin -or $Value -gt $ToleranceMax) { 
            Write-Log -Level Warn "Stat file ($Name) was not updated because the value ($([Decimal]$Value)) is outside fault tolerance ($([Int]$ToleranceMin) to $([Int]$ToleranceMax)). "
        }
        else { 
            $Span_Minute = [Math]::Min($Duration.TotalMinutes / [Math]::Min($Stat.Duration.TotalMinutes, 1), 1)
            $Span_Minute_5 = [Math]::Min(($Duration.TotalMinutes / 5) / [Math]::Min(($Stat.Duration.TotalMinutes / 5), 1), 1)
            $Span_Minute_10 = [Math]::Min(($Duration.TotalMinutes / 10) / [Math]::Min(($Stat.Duration.TotalMinutes / 10), 1), 1)
            $Span_Hour = [Math]::Min($Duration.TotalHours / [Math]::Min($Stat.Duration.TotalHours, 1), 1)
            $Span_Day = [Math]::Min($Duration.TotalDays / [Math]::Min($Stat.Duration.TotalDays, 1), 1)
            $Span_Week = [Math]::Min(($Duration.TotalDays / 7) / [Math]::Min(($Stat.Duration.TotalDays / 7), 1), 1)

            $Stat.Name = $Name
            $Stat.Live = $Value
            $Stat.Minute_Fluctuation = ((1 - $Span_Minute) * $Stat.Minute_Fluctuation) + ($Span_Minute * ([Math]::Abs($Value - $Stat.Minute) / [Math]::Max([Math]::Abs($Stat.Minute), $SmallestValue)))
            $Stat.Minute = ((1 - $Span_Minute) * $Stat.Minute) + ($Span_Minute * $Value)
            $Stat.Minute_5_Fluctuation = ((1 - $Span_Minute_5) * $Stat.Minute_5_Fluctuation) + ($Span_Minute_5 * ([Math]::Abs($Value - $Stat.Minute_5) / [Math]::Max([Math]::Abs($Stat.Minute_5), $SmallestValue)))
            $Stat.Minute_5 = ((1 - $Span_Minute_5) * $Stat.Minute_5) + ($Span_Minute_5 * $Value)
            $Stat.Minute_10_Fluctuation = ((1 - $Span_Minute_10) * $Stat.Minute_10_Fluctuation) + ($Span_Minute_10 * ([Math]::Abs($Value - $Stat.Minute_10) / [Math]::Max([Math]::Abs($Stat.Minute_10), $SmallestValue)))
            $Stat.Minute_10 = ((1 - $Span_Minute_10) * $Stat.Minute_10) + ($Span_Minute_10 * $Value)
            $Stat.Hour_Fluctuation = ((1 - $Span_Hour) * $Stat.Hour_Fluctuation) + ($Span_Hour * ([Math]::Abs($Value - $Stat.Hour) / [Math]::Max([Math]::Abs($Stat.Hour), $SmallestValue)))
            $Stat.Hour = ((1 - $Span_Hour) * $Stat.Hour) + ($Span_Hour * $Value)
            $Stat.Day_Fluctuation = ((1 - $Span_Day) * $Stat.Day_Fluctuation) + ($Span_Day * ([Math]::Abs($Value - $Stat.Day) / [Math]::Max([Math]::Abs($Stat.Day), $SmallestValue)))
            $Stat.Day = ((1 - $Span_Day) * $Stat.Day) + ($Span_Day * $Value)
            $Stat.Week_Fluctuation = ((1 - $Span_Week) * $Stat.Week_Fluctuation) + ($Span_Week * ([Math]::Abs($Value - $Stat.Week) / [Math]::Max([Math]::Abs($Stat.Week), $SmallestValue)))
            $Stat.Week = ((1 - $Span_Week) * $Stat.Week) + ($Span_Week * $Value)
            $Stat.Duration = $Stat.Duration + $Duration
            $Stat.Updated = $Updated
        }
    }
    else { 
        $Global:Stats.$Stat_Name = $Stat = [Hashtable]::Synchronized(
            @{ 
                Name                  = [String]$Name
                Live                  = [Double]$Value
                Minute                = [Double]$Value
                Minute_Fluctuation    = [Double]0
                Minute_5              = [Double]$Value
                Minute_5_Fluctuation  = [Double]0
                Minute_10             = [Double]$Value
                Minute_10_Fluctuation = [Double]0
                Hour                  = [Double]$Value
                Hour_Fluctuation      = [Double]0
                Day                   = [Double]$Value
                Day_Fluctuation       = [Double]0
                Week                  = [Double]$Value
                Week_Fluctuation      = [Double]0
                Duration              = [TimeSpan]$Duration
                Updated               = [DateTime]$Updated
            }
        )
    }

    @{ 
        Live                  = [Decimal]$Stat.Live
        Minute                = [Decimal]$Stat.Minute
        Minute_Fluctuation    = [Double]$Stat.Minute_Fluctuation
        Minute_5              = [Decimal]$Stat.Minute_5
        Minute_5_Fluctuation  = [Double]$Stat.Minute_5_Fluctuation
        Minute_10             = [Decimal]$Stat.Minute_10
        Minute_10_Fluctuation = [Double]$Stat.Minute_10_Fluctuation
        Hour                  = [Decimal]$Stat.Hour
        Hour_Fluctuation      = [Double]$Stat.Hour_Fluctuation
        Day                   = [Decimal]$Stat.Day
        Day_Fluctuation       = [Double]$Stat.Day_Fluctuation
        Week                  = [Decimal]$Stat.Week
        Week_Fluctuation      = [Double]$Stat.Week_Fluctuation
        Duration              = [String]$Stat.Duration
        Updated               = [DateTime]$Stat.Updated
    } | ConvertTo-Json | Set-Content $Path

    $Stat
}

function Get-Stat { 
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String[]]$Name = @($Global:Stats.Keys | Select-Object) + @(Get-ChildItem "Stats" -ErrorAction Ignore | Select-Object -ExpandProperty BaseName)
    )

    $Name | Sort-Object -Unique | ForEach-Object { 
        $Stat_Name = $_
        if ($Global:Stats.$Stat_Name -isnot [Hashtable] -or -not $Global:Stats.$Stat_Name.IsSynchronized) { 
            if ($Global:Stats -isnot [Hashtable] -or -not $Global:Stats.IsSynchronized) { 
                $Global:Stats = [Hashtable]::Synchronized(@{ })
            }

            #Reduce number of errors
            if (-not (Test-Path "Stats\$Stat_Name.txt")) { 
                if (-not (Test-Path "Stats" -PathType Container)) { 
                    New-Item "Stats" -ItemType "directory" -Force | Out-Null
                }
                return
            }

            try { 
                $Stat = Get-Content "Stats\$Stat_Name.txt" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                $Global:Stats.$Stat_Name = [Hashtable]::Synchronized(
                    @{ 
                        Name                  = [String]$Stat_Name
                        Live                  = [Double]$Stat.Live
                        Minute                = [Double]$Stat.Minute
                        Minute_Fluctuation    = [Double]$Stat.Minute_Fluctuation
                        Minute_5              = [Double]$Stat.Minute_5
                        Minute_5_Fluctuation  = [Double]$Stat.Minute_5_Fluctuation
                        Minute_10             = [Double]$Stat.Minute_10
                        Minute_10_Fluctuation = [Double]$Stat.Minute_10_Fluctuation
                        Hour                  = [Double]$Stat.Hour
                        Hour_Fluctuation      = [Double]$Stat.Hour_Fluctuation
                        Day                   = [Double]$Stat.Day
                        Day_Fluctuation       = [Double]$Stat.Day_Fluctuation
                        Week                  = [Double]$Stat.Week
                        Week_Fluctuation      = [Double]$Stat.Week_Fluctuation
                        Duration              = [TimeSpan]$Stat.Duration
                        Updated               = [DateTime]$Stat.Updated
                    }
                )
            }
            catch { 
                Write-Log -Level Warn "Stat file ($Stat_Name) is corrupt and will be reset. "
                Remove-Stat $Stat_Name
            }
        }

        $Global:Stats.$Stat_Name
    }
}

function Remove-Stat { 
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String[]]$Name = @($Global:Stats.Keys | Select-Object) + @(Get-ChildItem "Stats" -ErrorAction Ignore | Select-Object -ExpandProperty BaseName)
    )

    $Name | Sort-Object -Unique | ForEach-Object { 
        if ($Global:Stats.$_) { $Global:Stats.Remove($_) }
        Remove-Item -Path  "Stats\$_.txt" -Force -Confirm:$false -ErrorAction SilentlyContinue
    }
}

function Get-ChildItemContent { 
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Path, 
        [Parameter(Mandatory = $false)]
        [Hashtable]$Parameters = @{ }, 
        [Parameter(Mandatory = $false)]
        [Switch]$Threaded = $false, 
        [Parameter(Mandatory = $false)]
        [String]$Priority
    )

    $DefaultPriority = ([System.Diagnostics.Process]::GetCurrentProcess()).PriorityClass
    if ($Priority) { ([System.Diagnostics.Process]::GetCurrentProcess()).PriorityClass = $Priority }

    if ($Parameters.JobName) { $JobName = $Parameters.JobName } else { $JobName = "JobName" } #temp fix

    $Job = Start-Job -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)')")) -Name $JobName -ScriptBlock { 
        param(
            [Parameter(Mandatory = $true)]
            [String]$Path, 
            [Parameter(Mandatory = $false)]
            [Hashtable]$Parameters = @{ }, 
            [Parameter(Mandatory = $false)]
            [String]$Priority
        )

        if ($Priority) { ([System.Diagnostics.Process]::GetCurrentProcess()).PriorityClass = $Priority }

        function Invoke-ExpressionRecursive ($Expression) { 
            if ($Expression -is [String]) { 
                if ($Expression -match '\$') { 
                    try { $Expression = Invoke-Expression $Expression }
                    catch { $Expression = Invoke-Expression "`"$Expression`"" }
                }
            }
            elseif ($Expression -is [PSCustomObject]) { 
                $Expression | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { 
                    $Expression.$_ = Invoke-ExpressionRecursive $Expression.$_
                }
            }
            return $Expression
        }

        Get-ChildItem $Path -File -ErrorAction SilentlyContinue | ForEach-Object { 
            $Name = $_.BaseName
            $Content = @()
            if ($_.Extension -eq ".ps1") { 
                $Content = & { 
                    $Parameters.Keys | ForEach-Object { Set-Variable $_ $Parameters.$_ }
                    & $_.FullName @Parameters
                }
            }
            else { 
                $Content = & { 
                    $Parameters.Keys | ForEach-Object { Set-Variable $_ $Parameters.$_ }
                    try { 
                        ($_ | Get-Content | ConvertFrom-Json) | ForEach-Object { Invoke-ExpressionRecursive $_ }
                    }
                    catch [ArgumentException] { 
                        $null
                    }
                }
                if ($null -eq $Content) { $Content = $_ | Get-Content }
            }
            $Content | ForEach-Object { 
                [PSCustomObject]@{ Name = $Name; Content = $_ }
            }
        }
    } -ArgumentList $Path, $Parameters, $Priority

    if ($Threaded) { $Job }
    else { $Job | Receive-Job -Wait -AutoRemoveJob }

    ([System.Diagnostics.Process]::GetCurrentProcess()).PriorityClass = $DefaultPriority
}

filter ConvertTo-Hash { 
    [CmdletBinding()]
    $Units = " kMGTPEZY" #k(ilo) in small letters, see https://en.wikipedia.org/wiki/Metric_prefix
    $Base1000 = [Math]::Truncate([Math]::Log([Math]::Abs($_), [Math]::Pow(1000, 1)))
    $Base1000 = [Math]::Max([Double]0, [Math]::Min($Base1000, $Units.Length - 1))
    "{0:n2} $($Units[$Base1000])H" -f ($_ / [Math]::Pow(1000, $Base1000))
}

function ConvertTo-LocalCurrency { 

    # To get same numbering scheme regardless of value BTC value (size) to determine formatting
    # Use $Offset to add/remove decimal places

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Double]$Value, 
        [Parameter(Mandatory = $true)]
        [Double]$BTCRate, 
        [Parameter(Mandatory = $false)]
        [Int]$Offset
    )

    $Digits = ([math]::truncate(10 - $Offset - [math]::log($BTCRate, 10)))
    if ($Digits -lt 0) { $Digits = 0 }
    if ($Digits -gt 10) { $Digits = 10 }

    ($Value * $BTCRate).ToString("N$($Digits)")
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

    $Combination = [PSCustomObject]@{ }

    for ($i = 0; $i -lt $Value.Count; $i++) { 
        $Combination | Add-Member @{[Math]::Pow(2, $i) = $Value[$i] }
    }

    $Combination_Keys = $Combination | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

    for ($i = $SizeMin; $i -le $SizeMax; $i++) { 
        $x = [Math]::Pow(2, $i) - 1

        while ($x -le [Math]::Pow(2, $Value.Count) - 1) { 
            [PSCustomObject]@{Combination = $Combination_Keys | Where-Object { $_ -band $x } | ForEach-Object { $Combination.$_ } }
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
        [String]$LogPath = "", 
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = "", 
        [ValidateRange(-2, 3)]
        [Parameter(Mandatory = $false)]
        [Int]$Priority = 0, 
        [Parameter(Mandatory = $false)]
        [String[]]$EnvBlock
    )

    if ($EnvBlock) { $EnvBlock | ForEach-Object { Set-Item -Path "Env:$($_ -split '=' | Select-Object -Index 0)" "$($_ -split '=' | Select-Object -Index 1)" -Force } }

    $ScriptBlock = "Set-Location '$WorkingDirectory'; (Get-Process -Id `$PID).PriorityClass = '$(@{-2 = "Idle"; -1 = "BelowNormal"; 0 = "Normal"; 1 = "AboveNormal"; 2 = "High"; 3 = "RealTime"}[$Priority])'; "
    $ScriptBlock += "& '$FilePath'"
    if ($ArgumentList) { $ScriptBlock += " $ArgumentList" }
    $ScriptBlock += " *>&1"
    $ScriptBlock += " | Write-Output"
    if ($LogPath) { $ScriptBlock += " | Tee-Object '$LogPath'" }

    Start-Job ([ScriptBlock]::Create($ScriptBlock))
}

function Start-SubProcessWithoutStealingFocus { 
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath, 
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "", 
        [Parameter(Mandatory = $false)]
        [String]$LogPath = "", 
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = "", 
        [ValidateRange(-2, 3)]
        [Parameter(Mandatory = $false)]
        [Int]$Priority = 0, 
        [Parameter(Mandatory = $false)]
        [String[]]$EnvBlock
    )

    $PriorityNames = [PSCustomObject]@{-2 = "Idle"; -1 = "BelowNormal"; 0 = "Normal"; 1 = "AboveNormal"; 2 = "High"; 3 = "RealTime" }

    if ($EnvBlock) { $EnvBlock | ForEach-Object { Set-Item -Path "Env:$($_ -split '=' | Select-Object -Index 0)" "$($_ -split '=' | Select-Object -Index 1)" -Force } }

    $Job = Start-Job -ArgumentList $PID, (Resolve-Path ".\CreateProcess.cs"), $FilePath, $ArgumentList, $WorkingDirectory, $MinerVisibility, $EnvBlock { 
        param($ControllerProcessID, $CreateProcessPath, $FilePath, $ArgumentList, $WorkingDirectory, $MinerVisibility, $EnvBlock)

        $ControllerProcess = Get-Process -Id $ControllerProcessID
        if ($null -eq $ControllerProcess) { return }

        #CreateProcess won't be usable inside this job if Add-Type is run outside the job
        Add-Type -Path $CreateProcessPath

        $lpApplicationName = $FilePath;

        $lpCommandLine = '"' + $FilePath + '"' #Windows paths cannot contain ", so there is no need to escape
        if ($ArgumentList -ne "") { $lpCommandLine += " " + $ArgumentList }

        $lpProcessAttributes = New-Object SECURITY_ATTRIBUTES
        $lpProcessAttributes.Length = [System.Runtime.InteropServices.Marshal]::SizeOf($lpProcessAttributes)

        $lpThreadAttributes = New-Object SECURITY_ATTRIBUTES
        $lpThreadAttributes.Length = [System.Runtime.InteropServices.Marshal]::SizeOf($lpThreadAttributes)

        $bInheritHandles = $false

        $dwCreationFlags = [CreationFlags]::CREATE_NEW_CONSOLE

        $lpEnvironment = [IntPtr]::Zero

        if ($WorkingDirectory -ne "") { $lpCurrentDirectory = $WorkingDirectory }
        else { $lpCurrentDirectory = [IntPtr]::Zero }

        $lpStartupInfo = New-Object STARTUPINFO
        $lpStartupInfo.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($lpStartupInfo)
        $lpStartupInfo.wShowWindow = [ShowWindow]::SW_SHOWMINNOACTIVE
        $lpStartupInfo.dwFlags = [STARTF]::STARTF_USESHOWWINDOW

        $lpProcessInformation = New-Object PROCESS_INFORMATION

        [Kernel32]::CreateProcess($lpApplicationName, $lpCommandLine, [ref] $lpProcessAttributes, [ref] $lpThreadAttributes, $bInheritHandles, $dwCreationFlags, $lpEnvironment, $lpCurrentDirectory, [ref] $lpStartupInfo, [ref] $lpProcessInformation)

        $Process = Get-Process -Id $lpProcessInformation.dwProcessId
        if ($null -eq $Process) { 
            [PSCustomObject]@{ProcessId = $null }
            return
        }

        [PSCustomObject]@{ProcessId = $Process.Id; ProcessHandle = $Process.Handle }

        $ControllerProcess.Handle | Out-Null
        $Process.Handle | Out-Null

        do { if ($ControllerProcess.WaitForExit(1000)) { $Process.CloseMainWindow() | Out-Null } }
        while ($Process.HasExited -eq $false)
    }

    do { Start-Sleep 1; $JobOutput = Receive-Job $Job }
    while ($null -eq $JobOutput)

    $Process = Get-Process | Where-Object Id -EQ $JobOutput.ProcessId
    if ($Process) { $Process.PriorityClass = $PriorityNames.$Priority }
    Return $Job
}

function Expand-WebRequest { 
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Uri, 
        [Parameter(Mandatory = $false)]
        [String]$Path = ""
    )

    # Set current path used by .net methods to the same as the script's path
    [Environment]::CurrentDirectory = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation

    if (-not $Path) { $Path = Join-Path ".\Downloads" ([IO.FileInfo](Split-Path $Uri -Leaf)).BaseName }
    if (-not (Test-Path ".\Downloads" -PathType Container)) { New-Item "Downloads" -ItemType "directory" | Out-Null }
    $FileName = Join-Path ".\Downloads" (Split-Path $Uri -Leaf)

    if (Test-Path $FileName -PathType Leaf) { Remove-Item $FileName }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest $Uri -OutFile $FileName -UseBasicParsing

    if (".msi", ".exe" -contains ([IO.FileInfo](Split-Path $Uri -Leaf)).Extension) { 
        Start-Process $FileName "-qb" -Wait
    }
    else { 
        $Path_Old = (Join-Path (Split-Path (Split-Path $Path)) ([IO.FileInfo](Split-Path $Uri -Leaf)).BaseName)
        $Path_New = Split-Path $Path

        if (Test-Path $Path_Old -PathType Container) { Remove-Item $Path_Old -Recurse -Force }
        Start-Process "7z" "x `"$([IO.Path]::GetFullPath($FileName))`" -o`"$([IO.Path]::GetFullPath($Path_Old))`" -y -spe" -Wait -WindowStyle Hidden

        if (Test-Path $Path_New -PathType Container) { Remove-Item $Path_New -Recurse -Force }

        #use first (topmost) directory in case, e.g. ClaymoreDual_v11.9, contain multiple miner binaries for different driver versions in various sub dirs
        $Path_Old = (Get-ChildItem $Path_Old -File -Recurse | Where-Object { $_.Name -EQ $(Split-Path $Path -Leaf) }).Directory | Select-Object -Index 0

        if ($Path_Old) { 
            Move-Item $Path_Old $Path_New -PassThru | ForEach-Object -Process { $_.LastWriteTime = Get-Date }
            $Path_Old = (Join-Path (Split-Path (Split-Path $Path)) ([IO.FileInfo](Split-Path $Uri -Leaf)).BaseName)
            if (Test-Path $Path_Old -PathType Container) { Remove-Item $Path_Old -Recurse -Force }
        }
        else { 
            Throw "Error: Cannot find $($Path). "
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
        [Int]$Timeout = 10, #seconds
        [Parameter(Mandatory = $false)]
        [Bool]$ReadToEnd = $false
    )

    try { 
        $Client = New-Object System.Net.Sockets.TcpClient $Server, $Port
        $Stream = $Client.GetStream()
        $Writer = New-Object System.IO.StreamWriter $Stream
        $Reader = New-Object System.IO.StreamReader $Stream
        $Client.SendTimeout = $Timeout * 1000
        $Client.ReceiveTimeout = $Timeout * 1000
        $Writer.AutoFlush = $true

        $Writer.WriteLine($Request)
        if ($ReadToEnd) { $Response = $Reader.ReadToEnd() } else { $Response = $Reader.ReadLine() }
    }
    finally { 
        if ($Reader) { $Reader.Close(); $Reader.Dispose() }
        if ($Writer) { $Writer.Close(); $Writer.Dispose() }
        if ($Stream) { $Stream.Close(); $Stream.Dispose() }
        if ($Client) { $Client.Close(); $Client.Dispose() }
    }

    $Response
}

function Get-Device { 
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String[]]$Name = @(), 
        [Parameter(Mandatory = $false)]
        [String[]]$ExcludeName = @(), 
        [Parameter(Mandatory = $false)]
        [Switch]$Refresh = $false
    )

    if ($Name) { 
        $DeviceList = Get-Content "Devices.txt" | ConvertFrom-Json
        $Name_Devices = $Name | ForEach-Object { 
            $Name_Split = $_ -split '#'
            $Name_Split = @($Name_Split | Select-Object -Index 0) + @($Name_Split | Select-Object -Skip 1 | ForEach-Object { [Int]$_ })
            $Name_Split += @("*") * (100 - $Name_Split.Count)

            $Name_Device = $DeviceList.("{0}" -f $Name_Split) | Select-Object *
            $Name_Device | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object { $Name_Device.$_ = $Name_Device.$_ -f $Name_Split }

            $Name_Device
        }
    }

    if ($ExcludeName) { 
        if (-not $DeviceList) { $DeviceList = Get-Content "Devices.txt" | ConvertFrom-Json }
        $ExcludeName_Devices = $ExcludeName | ForEach-Object { 
            $ExcludeName_Split = $_ -split '#'
            $ExcludeName_Split = @($ExcludeName_Split | Select-Object -Index 0) + @($ExcludeName_Split | Select-Object -Skip 1 | ForEach-Object { [Int]$_ })
            $ExcludeName_Split += @("*") * (100 - $ExcludeName_Split.Count)

            $ExcludeName_Device = $DeviceList.("{0}" -f $ExcludeName_Split) | Select-Object *
            $ExcludeName_Device | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object { $ExcludeName_Device.$_ = $ExcludeName_Device.$_ -f $ExcludeName_Split }

            $ExcludeName_Device
        }
    }

    if ($Global:Devices -isnot [Array] -or $Refresh) { 
        $Global:Devices = [Array]$Devices = @()

        $Id = 0
        $Type_Id = @{ }
        $Vendor_Id = @{ }
        $Type_Vendor_Id = @{ }

        $Slot = 0
        $Type_Slot = @{ }
        $Vendor_Slot = @{ }
        $Type_Vendor_Slot = @{ }

        $Index = 0
        $Type_Index = @{ }
        $Vendor_Index = @{ }
        $Type_Vendor_Index = @{ }
        $PlatformId = 0
        $PlatformId_Index = @{ }
        $Type_PlatformId_Index = @{ }

        #Get WDDM data
        try { 
            Get-CimInstance CIM_Processor | ForEach-Object { 
                $Device_CIM = $_ | ConvertTo-Json | ConvertFrom-Json

                #Add normalised values
                $Global:Devices += $Device = [PSCustomObject]@{ 
                    Name   = $null
                    Model  = $Device_CIM.Name
                    Type   = "CPU"
                    Bus    = $null
                    Vendor = $(
                        switch -Regex ($Device_CIM.Manufacturer) { 
                            "Advanced Micro Devices" { "AMD" }
                            "Intel" { "INTEL" }
                            "NVIDIA" { "NVIDIA" }
                            "AMD" { "AMD" }
                            default { $Device_CIM.Manufacturer -replace '\(R\)|\(TM\)|\(C\)' -replace '[^A-Z0-9]' }
                        }
                    )
                    Memory = $null
                }

                $Device | Add-Member @{ 
                    Id             = [Int]$Id
                    Type_Id        = [Int]$Type_Id.($Device.Type)
                    Vendor_Id      = [Int]$Vendor_Id.($Device.Vendor)
                    Type_Vendor_Id = [Int]$Type_Vendor_Id.($Device.Type).($Device.Vendor)
                }

                $Device.Name = "$($Device.Type)#$('{0:D2}' -f $Device.Type_Id)"
                $Device.Model = (($Device.Model -split ' ' -replace 'Processor', 'CPU' -replace 'Graphics', 'GPU') -notmatch $Device.Type -notmatch $Device.Vendor) -join ' ' -replace '\(R\)|\(TM\)|\(C\)' -replace '[^A-Z0-9]'

                if (-not $Type_Vendor_Id.($Device.Type)) { 
                    $Type_Vendor_Id.($Device.Type) = @{ }
                }

                $Id++
                $Vendor_Id.($Device.Vendor)++
                $Type_Vendor_Id.($Device.Type).($Device.Vendor)++
                $Type_Id.($Device.Type)++

                #Read CPU features
                $Device | Add-member CpuFeatures ((Get-CpuId).Features | Sort-Object)

                #Add raw data
                $Device | Add-Member @{ 
                    CIM = $Device_CIM
                }
            }

            Get-CimInstance CIM_VideoController | ForEach-Object { 
                $Device_CIM = $_ | ConvertTo-Json | ConvertFrom-Json

                $Device_PNP = [PSCustomObject]@{ }
                Get-PnpDevice $Device_CIM.PNPDeviceID | Get-PnpDeviceProperty | ForEach-Object { $Device_PNP | Add-Member $_.KeyName $_.Data }
                $Device_PNP = $Device_PNP | ConvertTo-Json | ConvertFrom-Json

                $Device_Reg = Get-ItemProperty "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\$($Device_PNP.DEVPKEY_Device_Driver)" | ConvertTo-Json | ConvertFrom-Json

                #Add normalised values
                $Global:Devices += $Device = [PSCustomObject]@{ 
                    Name   = $null
                    Model  = $Device_CIM.Name
                    Type   = "GPU"
                    Bus    = $(
                        if ($Device_PNP.DEVPKEY_Device_BusNumber -is [Int64] -or $Device_PNP.DEVPKEY_Device_BusNumber -is [Int32]) { 
                            [Int64]$Device_PNP.DEVPKEY_Device_BusNumber
                        }
                    )
                    Vendor = $(
                        switch -Regex ([String]$Device_CIM.AdapterCompatibility) { 
                            "Advanced Micro Devices" { "AMD" }
                            "Intel" { "INTEL" }
                            "NVIDIA" { "NVIDIA" }
                            "AMD" { "AMD" }
                            default { $Device_CIM.AdapterCompatibility -replace '\(R\)|\(TM\)|\(C\)' -replace '[^A-Z0-9]' }
                        }
                    )
                    Memory = [Math]::Max(([UInt64]$Device_CIM.AdapterRAM), ([uInt64]$Device_Reg.'HardwareInformation.qwMemorySize'))
                }

                $Device | Add-Member @{ 
                    Id             = [Int]$Id
                    Type_Id        = [Int]$Type_Id.($Device.Type)
                    Vendor_Id      = [Int]$Vendor_Id.($Device.Vendor)
                    Type_Vendor_Id = [Int]$Type_Vendor_Id.($Device.Type).($Device.Vendor)
                }

                $Device.Name = "$($Device.Type)#$('{0:D2}' -f $Device.Type_Id)"
                $Device.Model = ((($Device.Model -split ' ' -replace 'Processor', 'CPU' -replace 'Graphics', 'GPU') -notmatch $Device.Type -notmatch $Device.Vendor -notmatch "$([UInt64]($Device.Memory/1GB))GB") + "$([UInt64]($Device.Memory/1GB))GB") -join ' ' -replace '\(R\)|\(TM\)|\(C\)' -replace '[^A-Z0-9]'

                if (-not $Type_Vendor_Id.($Device.Type)) { 
                    $Type_Vendor_Id.($Device.Type) = @{ }
                }

                $Id++
                $Vendor_Id.($Device.Vendor)++
                $Type_Vendor_Id.($Device.Type).($Device.Vendor)++
                $Type_Id.($Device.Type)++

                #Add raw data
                $Device | Add-Member @{ 
                    CIM = $Device_CIM
                    PNP = $Device_PNP
                    Reg = $Device_Reg
                }
            }
        }
        catch { 
            Write-Log -Level Warn "WDDM device detection has failed. "
        }

        #Get OpenCL data
        try { 
            [OpenCl.Platform]::GetPlatformIDs() | ForEach-Object { 
                [OpenCl.Device]::GetDeviceIDs($_, [OpenCl.DeviceType]::All) | ForEach-Object { 
                    $Device_OpenCL = $_ | ConvertTo-Json | ConvertFrom-Json

                    #Add normalised values
                    $Device = [PSCustomObject]@{ 
                        Name   = $null
                        Model  = $Device_OpenCL.Name
                        Type   = $(
                            switch -Regex ([String]$Device_OpenCL.Type) { 
                                "CPU" { "CPU" }
                                "GPU" { "GPU" }
                                default { [String]$Device_OpenCL.Type -replace '\(R\)|\(TM\)|\(C\)' -replace '[^A-Z0-9]' }
                            }
                        )
                        Bus    = $(
                            if ($Device_OpenCL.PCIBus -is [Int64] -or $Device_OpenCL.PCIBus -is [Int32]) { 
                                [Int64]$Device_OpenCL.PCIBus
                            }
                        )
                        Vendor = $(
                            switch -Regex ([String]$Device_OpenCL.Vendor) { 
                                "Advanced Micro Devices" { "AMD" }
                                "Intel" { "INTEL" }
                                "NVIDIA" { "NVIDIA" }
                                "AMD" { "AMD" }
                                default { [String]$Device_OpenCL.Vendor -replace '\(R\)|\(TM\)|\(C\)' -replace '[^A-Z0-9]' }
                            }
                        )
                        Memory = [UInt64]$Device_OpenCL.GlobalMemSize
                    }

                    $Device | Add-Member @{ 
                        Id             = [Int]$Id
                        Type_Id        = [Int]$Type_Id.($Device.Type)
                        Vendor_Id      = [Int]$Vendor_Id.($Device.Vendor)
                        Type_Vendor_Id = [Int]$Type_Vendor_Id.($Device.Type).($Device.Vendor)
                    }

                    $Device.Name = "$($Device.Type)#$('{0:D2}' -f $Device.Type_Id)"
                    $Device.Model = ((($Device.Model -split ' ' -replace 'Processor', 'CPU' -replace 'Graphics', 'GPU') -notmatch $Device.Type -notmatch $Device.Vendor -notmatch "$([UInt64]($Device.Memory/1GB))GB") + "$([UInt64]($Device.Memory/1GB))GB") -join ' ' -replace '\(R\)|\(TM\)|\(C\)' -replace '[^A-Z0-9]'

                    if ($Global:Devices | Where-Object Type -EQ $Device.Type | Where-Object Bus -EQ $Device.Bus) { 
                        $Device = $Global:Devices | Where-Object Type -EQ $Device.Type | Where-Object Bus -EQ $Device.Bus
                    }
                    elseif ($Device.Type -eq "GPU" -and ($Device.Vendor -eq "AMD" -or $Device.Vendor -eq "NVIDIA")) { 
                        $Global:Devices += $Device

                        if (-not $Type_Vendor_Id.($Device.Type)) { 
                            $Type_Vendor_Id.($Device.Type) = @{ }
                        }

                        $Id++
                        $Vendor_Id.($Device.Vendor)++
                        $Type_Vendor_Id.($Device.Type).($Device.Vendor)++
                        $Type_Id.($Device.Type)++
                    }

                    #Add OpenCL specific data
                    $Device | Add-Member @{ 
                        Index                 = [Int]$Index
                        Type_Index            = [Int]$Type_Index.($Device.Type)
                        Vendor_Index          = [Int]$Vendor_Index.($Device.Vendor)
                        Type_Vendor_Index     = [Int]$Type_Vendor_Index.($Device.Type).($Device.Vendor)
                        PlatformId            = [Int]$PlatformId
                        PlatformId_Index      = [Int]$PlatformId_Index.($PlatformId)
                        Type_PlatformId_Index = [Int]$Type_PlatformId_Index.($Device.Type).($PlatformId)
                    }

                    #Add raw data
                    $Device | Add-Member @{ 
                        OpenCL = $Device_OpenCL
                    }

                    if (-not $Type_Vendor_Index.($Device.Type)) { 
                        $Type_Vendor_Index.($Device.Type) = @{ }
                    }
                    if (-not $Type_PlatformId_Index.($Device.Type)) { 
                        $Type_PlatformId_Index.($Device.Type) = @{ }
                    }

                    $Index++
                    $Type_Index.($Device.Type)++
                    $Vendor_Index.($Device.Vendor)++
                    $Type_Vendor_Index.($Device.Type).($Device.Vendor)++
                    $PlatformId_Index.($PlatformId)++
                    $Type_PlatformId_Index.($Device.Type).($PlatformId)++
                }

                $PlatformId++
            }

            $Global:Devices | Where-Object Bus -Is [Int64] | Sort-Object Bus | ForEach-Object { 
                $_ | Add-Member @{ 
                    Slot             = [Int]$Slot
                    Type_Slot        = [Int]$Type_Slot.($_.Type)
                    Vendor_Slot      = [Int]$Vendor_Slot.($_.Vendor)
                    Type_Vendor_Slot = [Int]$Type_Vendor_Slot.($_.Type).($_.Vendor)
                }

                if (-not $Type_Vendor_Slot.($_.Type)) { 
                    $Type_Vendor_Slot.($_.Type) = @{ }
                }

                $Slot++
                $Type_Slot.($_.Type)++
                $Vendor_Slot.($_.Vendor)++
                $Type_Vendor_Slot.($_.Type).($_.Vendor)++
            }
        }
        catch { 
            Write-Log -Level Warn "OpenCL device detection has failed. "
        }
    }

    $Global:Devices | ForEach-Object { 
        $Device = $_
        if (-not $Name -or ($Name_Devices | Where-Object { ($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -like ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) })) { 
            if (-not $ExcludeName -or -not ($ExcludeName_Devices | Where-Object { ($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -like ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) })) { 
                $Device
            }
        }
    }
}

function Get-Algorithm { 
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Algorithm = ""
    )

    if (-not (Test-Path Variable:Script:Algorithms -ErrorAction SilentlyContinue)) { 
        $Script:Algorithms = Get-Content "Algorithms.txt" | ConvertFrom-Json
    }

    $Algorithm = (Get-Culture).TextInfo.ToTitleCase(($Algorithm.ToLower() -replace "-", " " -replace "_", " " -replace "/", " ")) -replace " "

    if ($Script:Algorithms.$Algorithm) { $Script:Algorithms.$Algorithm }
    else { $Algorithm }
}

function Test-Prime { 
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Double]$Number
    )

    for ([Int64]$i = 2; $i -lt [Int64][Math]::Pow($Number, 0.5); $i++) { if ($Number % $i -eq 0) { return $false } }

    return $true
}

function Get-EthashSize { 
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Double]$Block
    )

    $DATASET_BYTES_INIT = [Math]::Pow(2, 30)
    $DATASET_BYTES_GROWTH = [Math]::Pow(2, 23)
    $EPOCH_LENGTH = 30000
    $MIX_BYTES = 128

    $Size = $DATASET_BYTES_INIT + $DATASET_BYTES_GROWTH * [Math]::Floor($Block / $EPOCH_LENGTH)
    $Size -= $MIX_BYTES
    while (-not (Test-Prime ($Size / $MIX_BYTES))) { $Size -= 2 * $MIX_BYTES }

    return $Size
}

function Get-CoinName { 
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [String]$CoinName = ""
    )

    if (-not (Test-Path Variable:Script:CoinNames -ErrorAction SilentlyContinue)) { 
        $Script:CoinNames = Get-Content "CoinNames.txt" | ConvertFrom-Json
    }

    $CoinName = (Get-Culture).TextInfo.ToTitleCase(($CoinName.ToLower() -replace "-", " " -replace "_", " ")) -replace " "

    if ($Script:CoinNames.$CoinName) { $Script:CoinNames.$CoinName }
    else { $CoinName -replace "coin", "Coin" -replace "cash", "Cash" }
}

function Get-Region { 
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Region = ""
    )

    if (-not (Test-Path Variable:Script:Regions -ErrorAction SilentlyContinue)) { 
        $Script:Regions = Get-Content "Regions.txt" | ConvertFrom-Json
    }

    $Region = (Get-Culture).TextInfo.ToTitleCase(($Region -replace "-", " " -replace "_", " ")) -replace " "

    if ($Script:Regions.$Region) { $Script:Regions.$Region }
    else { $Region }
}

function Get-AlgoCoinPers { 
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm = "", 
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [String]$CoinName = "", 
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [String]$Default = ""
    )

    if (-not (Test-Path Variable:Script:AlgoCoinPers -ErrorAction SilentlyContinue)) { 
        $Script:AlgoCoinPers = Get-Content "AlgoCoinPers.txt" | ConvertFrom-Json
    }

    if ($Script:AlgoCoinPers.$Algorithm.$CoinName) { $Script:AlgoCoinPers.$Algorithm.$CoinName }
    else { $Default }
}

function Add-Object { 
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Object[]]$ReferenceObject, #Original Array
        [Parameter(Mandatory = $true)]
        [Object[]]$DifferenceObject, #New Array
        [Parameter(Mandatory = $true)]
        [Object[]]$Property, #Primary Key(s)
        [Parameter(Mandatory = $false)]
        [Switch]$Force = $false #Update Existing Object
    )

    if ($Force) { 
        $DifferenceObject | ForEach-Object { 
            [Object]$Object_Temp = $_
            [Object[]]$Object_Old = $ReferenceObject
            [Object]$Object = $null

            $Property | ForEach-Object { 
                $Object_Old = $Object_Old | Where-Object -Property $_ -EQ -Value ($Object_Temp | Select-Object -ExpandProperty $_)
            }

            $Object = $Object_Old | Select-Object -Index 0

            if ($Object) { 
                $Object | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name | ForEach-Object { 
                    $Object.$_ = $Object_Temp.$_
                }
            }
        }
    }

    Compare-Object -ReferenceObject @($ReferenceObject | Select-Object -Property $Property -Unique) -DifferenceObject @($DifferenceObject | Select-Object -Property $Property -Unique) -Property $Property | Where-Object SideIndicator -EQ "=>" | ForEach-Object { 
        [Object]$Object_Temp = $_
        [Object[]]$Object_New = $DifferenceObject
        [Object]$Object = $null

        $Property | ForEach-Object { 
            $Object_New = $Object_New | Where-Object -Property $_ -EQ -Value ($Object_Temp | Select-Object -ExpandProperty $_)
        }

        $Object = $Object_New | Select-Object -Index 0

        if ($Object) { $ReferenceObject += $Object }
    }

    $ReferenceObject
}

class Pool { 
    [String]$Name
    [String]$Algorithm
    [String]$CoinName
    [Uri]$Uri
    [String]$User
    [String]$Pass
    [String]$Region
    [Boolean]$SSL
    [String]$PayoutScheme
    [Double]$Fee
    [Double]$Price
    [Double]$Price_Bias
    [Double]$Price_Unbias
    [Double]$StablePrice
    [Double]$ActualPrice
    [Double]$MarginOfError
    [DateTime]$Updated
    [DateTime]$Cached
    [Boolean]$Enabled

    #Under review
    [String]$CurrencySymbol
    [Double]$EstimateCorrection
    [Double]$PricePenaltyFactor
    [Int]$Workers
}

class Worker {
    [Pool]$Pool
    [Double]$Fee
    [Double]$Speed
    [Boolean]$Benchmark
    [Double]$Profit
    [Double]$Profit_Comparison
    [Double]$Profit_Accuracy
    [Double]$Profit_Bias
    [Double]$Profit_Unbias
}

enum MinerStatus { 
    Running
    Idle
    Failed
}

class Miner { 
    static [Pool[]]$Pools = @()
    [Worker[]]$Workers = @()

    [String]$Name
    [String]$Path
    [String]$Arguments
    [UInt16]$Port
    [String[]]$DeviceName = @()
    [String[]]$Algorithm = @() #derived from pool
    [String[]]$Algorithm_Base = @() #derived from pool
    [String[]]$PoolName = @() #derived from pool
    [String[]]$PoolName_Base = @() #derived from pool
    [Double]$Profit #derived from pool and stats
    [Double]$Profit_Comparison #derived from pool and stats
    [Double]$Profit_Accuracy #derived from pool and stats
    [Double]$Profit_Bias #derived from pool and stats
    [Double]$Profit_Unbias #derived from pool and stats
    [Double[]]$PoolFee = @() #derived from pool
    [Double[]]$PoolPrice = @() #derived from pool
    [Double[]]$Fee = @()
    [Double[]]$Speed = @() #derived from stats
    [Double[]]$Speed_Live = @()
    [Boolean]$Benchmark = $false #derived from stats
    [Boolean]$Fastest = $false
    [Boolean]$Best = $false
    [Boolean]$Best_Comparison = $false
    [Boolean]$New = $false
    [Boolean]$Cached = $false
    [Boolean]$Enabled = $false
    hidden [System.Management.Automation.Job]$Process = $null
    hidden [TimeSpan]$Active = [TimeSpan]::Zero
    hidden [Int]$Activated = 0
    hidden [MinerStatus]$Status = [MinerStatus]::Idle
    [TimeSpan[]]$Intervals = @()
    [String]$LogFile
    hidden [Array]$Data = @()
    [Boolean]$ShowMinerWindow = $false
    [Double]$IntervalMultiplier = 1
    [String[]]$Environment = @()

    #Under review
    [Int]$AllowedBadShareRatio
    $API
    [String]$BaseName
    $BeginTime
    $Benchmarked
    $Device = @()
    [Double]$Earning #derived from pool and stats
    [Double]$Earning_Bias #derived from pool and stats
    [Double]$Earning_Comparison #derived from pool and stats
    [Double]$Earning_MarginOfError #derived from pool and stats
    [Double]$Earning_Unbias #derived from pool and stats
    $EndTime
    $PowerCost
    $PowerUsage
    $ProcessId
    [String]$StatusMessage
    [String]$Version
    [Int]$WarmupTime

    [String[]]GetProcessNames() { 
        return @(([IO.FileInfo]($this.Path | Split-Path -Leaf -ErrorAction Ignore)).BaseName)
    }

    [String]GetCommandLineParameters() { 
        return $this.Arguments
    }

    [String]GetCommandLine() { 
        return "$($this.Path) $($this.GetCommandLineParameters())"
    }

    [Int32]GetProcessId() { 
        return Get-CimInstance CIM_Process | Where-Object CommandLine -EQ $this.GetCommandLine() | Select-Object -ExpandProperty ProcessId
    }

    hidden StartMining() { 
        $this.Status = [MinerStatus]::Failed

        $this.New = $true
        $this.Activated++
        $this.Intervals = @()
        $this.StatusMessage = ""

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
            if ($this.ShowMinerWindow -and ($this.API -ne "Wrapper")) { 
                if (Test-Path ".\CreateProcess.cs" -PathType Leaf) { 
                    $this.Process = Start-SubProcessWithoutStealingFocus -FilePath $this.Path -ArgumentList $this.GetCommandLineParameters() -WorkingDirectory (Split-Path $this.Path) -Priority ($this.DeviceName | ForEach-Object { if ($_ -like "CPU#*") { -2 } else { -1 } } | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -EnvBlock $this.Environment
                }
                else { 
                    $EnvCmd = ($this.Environment | Select-Object | ForEach-Object { "```$env:$($_)" }) -join "; "
                    $this.Process = Start-Job ([ScriptBlock]::Create("Start-Process $(@{desktop = "powershell"; core = "pwsh"}.$Global:PSEdition) `"-command $EnvCmd```$Process = (Start-Process '$($this.Path)' '$($this.GetCommandLineParameters())' -WorkingDirectory '$(Split-Path $this.Path)' -WindowStyle Minimized -PassThru).Id; Wait-Process -Id `$PID; Stop-Process -Id ```$Process`" -WindowStyle Hidden -Wait"))
                }
            }
            else { 
                $this.LogFile = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Logs\$($this.Name)-$($this.Port)_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt")
                $this.Process = Start-SubProcess -FilePath $this.Path -ArgumentList $this.GetCommandLineParameters() -LogPath $this.LogFile -WorkingDirectory (Split-Path $this.Path) -Priority ($this.DeviceName | ForEach-Object { if ($_ -like "CPU#*") { -2 } else { -1 } } | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -EnvBlock $this.Environment
            }

            if ($this.Process | Get-Job -ErrorAction SilentlyContinue) { 
                for ($WaitForPID = 0; $WaitForPID -le 20; $WaitForPID++) { 
                    if ($this.ProcessId = (Get-CIMInstance CIM_Process | Where-Object { $_.ExecutablePath -eq $this.Path -and $_.CommandLine -like "*$($this.Path)*$($this.GetCommandLineParameters())*" }).ProcessId) { 
                        $this.Status = [MinerStatus]::Running
                        $this.BeginTime = (Get-Date).ToUniversalTime()
                        break
                    }
                    Start-Sleep -Milliseconds 100
                }
            }
        }
    }

    hidden StopMining() { 
        $this.Status = [MinerStatus]::Failed
        $this.EndTime = (Get-Date).ToUniversalTime()
        if ($this.ProcessId) { 
            if (Get-Process -Id $this.ProcessId -ErrorAction SilentlyContinue) { 
                Stop-Process -Id $this.ProcessId -Force -ErrorAction Ignore
            }
            $this.ProcessId = $null
        }

        if ($this.Process) { 
            if ($this.Process | Get-Job -ErrorAction SilentlyContinue) { 
                $this.Process | Remove-Job -Force
            }

            if (-not ($this.Process | Get-Job -ErrorAction SilentlyContinue)) { 
                $this.Active += $this.Process.PSEndTime - $this.Process.PSBeginTime
                $this.Process = $null
                $this.Status = [MinerStatus]::Idle
            }
        }
    }

    [DateTime]GetActiveLast() { 
        if ($this.Process.PSBeginTime -and $this.Process.PSEndTime) { 
            return $this.Process.PSEndTime.ToUniversalTime()
        }
        elseif ($this.Process.PSBeginTime) { 
            return [DateTime]::Now.ToUniversalTime()
        }
        else { 
            return [DateTime]::MinValue.ToUniversalTime()
        }
    }

    [TimeSpan]GetActiveTime() { 
        if ($this.Process.PSBeginTime -and $this.Process.PSEndTime) { 
            return $this.Active + ($this.Process.PSEndTime - $this.Process.PSBeginTime)
        }
        elseif ($this.Process.PSBeginTime) { 
            return $this.Active + ((Get-Date) - $this.Process.PSBeginTime)
        }
        else { 
            return $this.Active
        }
    }

    [Int]GetActivateCount() { 
        return $this.Activated
    }

    [MinerStatus]GetStatus() { 
        if ($this.Process.State -eq "Running" -and $this.ProcessId -and (Get-Process -Id $this.ProcessId -ErrorAction SilentlyContinue).ProcessName) { 
            #Use ProcessName, some crashed miners are dead, but may still be found by their processId
            return [MinerStatus]::Running
        }
        elseif ($this.Status -eq "Running") { 
            $this.ProcessId = $null
            $this.Status = [MinerStatus]::Failed
            return $this.Status
        }
        else { 
            return $this.Status
        }
    }

    SetStatus([MinerStatus]$Status) { 
        if ($Status -eq $this.GetStatus()) { return }

        switch ($Status) { 
            "Running" { 
                $this.StartMining()
            }
            "Idle" { 
                $this.StopMining()
            }
            Default { 
                $this.StopMining()
                $this.Status = $Status
            }
        }
    }

    [String[]]UpdateMinerData () { 
        $Lines = @()

        if ($this.Process.HasMoreData) { 
            $Date = (Get-Date).ToUniversalTime()

            $this.Process | Receive-Job | ForEach-Object { 
                $Line = $_ -replace "`n|`r", ""
                $Line_Simple = $Line -replace "\x1B\[[0-?]*[ -/]*[@-~]", ""

                if ($Line_Simple) { 
                    $HashRates = @()
                    $Devices = @()

                    if ($Line_Simple -match "/s") { 
                        $Words = $Line_Simple -split " "

                        $Words -match "/s$" | ForEach-Object { 
                            if (($Words | Select-Object -Index $Words.IndexOf($_)) -match "^((?:\d*\.)?\d+)(.*)$") { 
                                $HashRate = ($matches | Select-Object -Index 1) -as [Decimal]
                                $HashRate_Unit = ($matches | Select-Object -Index 2)
                            }
                            else { 
                                $HashRate = ($Words | Select-Object -Index ($Words.IndexOf($_) - 1)) -as [Decimal]
                                $HashRate_Unit = ($Words | Select-Object -Index $Words.IndexOf($_))
                            }

                            switch -wildcard ($HashRate_Unit) { 
                                "kh/s*" { $HashRate *= [Math]::Pow(1000, 1) }
                                "mh/s*" { $HashRate *= [Math]::Pow(1000, 2) }
                                "gh/s*" { $HashRate *= [Math]::Pow(1000, 3) }
                                "th/s*" { $HashRate *= [Math]::Pow(1000, 4) }
                                "ph/s*" { $HashRate *= [Math]::Pow(1000, 5) }
                            }

                            $HashRates += $HashRate
                        }
                    }

                    if ($Line_Simple -match "gpu|cpu|device") { 
                        $Words = $Line_Simple -replace "#", "" -replace ":", "" -split " "

                        $Words -match "^gpu|^cpu|^device" | ForEach-Object { 
                            if (($Words | Select-Object -Index $Words.IndexOf($_)) -match "^(.*)((?:\d*\.)?\d+)$") { 
                                $Device = ($matches | Select-Object -Index 2) -as [Int]
                                $Device_Type = ($matches | Select-Object -Index 1)
                            }
                            else { 
                                $Device = ($Words | Select-Object -Index ($Words.IndexOf($_) + 1)) -as [Int]
                                $Device_Type = ($Words | Select-Object -Index $Words.IndexOf($_))
                            }

                            $Devices += "{0}#{1:d2}" -f $Device_Type, $Device
                        }
                    }

                    $Lines += $Line

                    if ($HashRates) { 
                        $this.Data += [PSCustomObject]@{ 
                            Date       = $Date
                            Raw        = $Line_Simple
                            HashRate   = [PSCustomObject]@{[String]$this.Algorithm = [Double]($HashRates | Measure-Object -Sum).Sum }
                            PowerUsage = (Get-PowerUsage $this.DeviceName)
                            Device     = $Devices
                        }
                    }
                }
            }

            $this.Data = @($this.Data | Select-Object -Last 10000)
        }

        return $Lines
    }

    [Double]GetHashRate([String]$Algorithm = [String]$this.Algorithm, [Boolean]$Safe = $this.New) { 
        $HashRates_Devices = @($this.Data | Where-Object Device | Select-Object -ExpandProperty Device -Unique)
        if (-not $HashRates_Devices) { $HashRates_Devices = @("Device") }

        $HashRates_Counts = @{ }
        $HashRates_Averages = @{ }
        $HashRates_Variances = @{ }

        $Hashrates_Samples = @($this.Data | Where-Object { $_.HashRate.$Algorithm } | Sort-Object { $_.HashRate.$Algorithm }) #Do not use 0 valued samples

        #During benchmarking strip some of the lowest and highest sample values
        if ($Safe) { 
            if ($this.IntervalMultiplier -gt 1) { $Hashrates_Samples = $Hashrates_Samples | Where-Object { $_.Date -ge $this.BeginTime.AddSeconds($this.WarmupTime) } }
            $SkipSamples = [math]::Floor($HashRates_Samples.Count) * 0.1
        }
        else { $SkipSamples = 0 }

        $Hashrates_Samples | Select-Object -Skip $SkipSamples | Select-Object -SkipLast $SkipSamples | ForEach-Object { 
            $Data_Devices = $_.Device
            if (-not $Data_Devices) { $Data_Devices = $HashRates_Devices }

            $Data_HashRates = $_.HashRate.$Algorithm

            $Data_Devices | ForEach-Object { $HashRates_Counts.$_++ }
            $Data_Devices | ForEach-Object { $HashRates_Averages.$_ += @(($Data_HashRates | Measure-Object -Sum | Select-Object -ExpandProperty Sum) / $Data_Devices.Count) }
            $HashRates_Variances."$($Data_Devices | ConvertTo-Json)" += @($Data_HashRates | Measure-Object -Sum | Select-Object -ExpandProperty Sum)
        }

        $HashRates_Count = $HashRates_Counts.Values | ForEach-Object { $_ } | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
        $HashRates_Average = ($HashRates_Averages.Values | ForEach-Object { $_ } | Measure-Object -Average | Select-Object -ExpandProperty Average) * $HashRates_Averages.Keys.Count
        $HashRates_Variance = $HashRates_Variances.Keys | ForEach-Object { $_ } | ForEach-Object { $HashRates_Variances.$_ | Measure-Object -Average -Minimum -Maximum } | ForEach-Object { if ($_.Average) { ($_.Maximum - $_.Minimum) / $_.Average } } | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

        if ($Safe) { 
            if ($HashRates_Count -lt 3 -or $HashRates_Variance -gt 0.05) { 
                return 0
            }
            else { 
                return $HashRates_Average * (1 + ($HashRates_Variance / 2))
            }
        }
        else { 
            return $HashRates_Average
        }
    }

    [Double]GetPowerUsage([Boolean]$Safe = $this.New) { 
        $PowerUsages_Devices = @($this.Data | Where-Object Device | Select-Object -ExpandProperty Device -Unique)
        if (-not $PowerUsages_Devices) { $PowerUsages_Devices = @("Device") }

        $PowerUsages_Counts = @{ }
        $PowerUsages_Averages = @{ }
        $PowerUsages_Variances = @{ }

        $PowerUsages_Samples = @($this.Data | Where-Object PowerUsage) #Do not use 0 valued samples

        #During power measuring strip some of the lowest and highest sample values
        if ($Safe) { 
            if ($this.IntervalMultiplier -le 1) { $SkipSamples = [math]::Round($PowerUsages_Samples.Count * 0.2) }
            else { $SkipSamples = [math]::Round($PowerUsages_Samples.Count * 0.3) }
        }
        else { $SkipSamples = 0 }

        $PowerUsages_Samples | Sort-Object PowerUsage | Select-Object -Skip $SkipSamples | Select-Object -SkipLast $SkipSamples | ForEach-Object { 
            $Data_Devices = $_.Device
            if (-not $Data_Devices) { $Data_Devices = $PowerUsages_Devices }

            $Data_PowerUsages = $_.PowerUsage

            $Data_Devices | ForEach-Object { $PowerUsages_Counts.$_++ }
            $Data_Devices | ForEach-Object { $PowerUsages_Averages.$_ += @(($Data_PowerUsages | Measure-Object -Sum | Select-Object -ExpandProperty Sum) / $Data_Devices.Count) }
            $PowerUsages_Variances."$($Data_Devices | ConvertTo-Json)" += @($Data_PowerUsages | Measure-Object -Sum | Select-Object -ExpandProperty Sum)
        }

        $PowerUsages_Count = $PowerUsages_Counts.Values | ForEach-Object { $_ } | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
        $PowerUsages_Average = ($PowerUsages_Averages.Values | ForEach-Object { $_ } | Measure-Object -Average | Select-Object -ExpandProperty Average) * $PowerUsages_Averages.Keys.Count
        $PowerUsages_Variance = $PowerUsages_Variances.Keys | ForEach-Object { $_ } | ForEach-Object { $PowerUsages_Variances.$_ | Measure-Object -Average -Minimum -Maximum } | ForEach-Object { if ($_.Average) { ($_.Maximum - $_.Minimum) / $_.Average } } | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

        if ($Safe) { 
            if ($PowerUsages_Count -lt 3 -or $PowerUsages_Variance -gt 0.1) { 
                return 0
            }
            else { 
                return $PowerUsages_Average * (1 + ($PowerUsages_Variance / 2))
            }
        }
        else { 
            return $PowerUsages_Average
        }
    }

    Refresh() { 
        $this.Workers | ForEach-Object { 
            $_.Profit = $_.Pool.Price * (($_.Speed * ([Double]1 - $_.Fee)) * (1 - $_.Pool.Fee))
            $_.Profit_Comparison = $_.Pool.StablePrice * (($_.Speed * ([Double]1 - $_.Fee)) * (1 - $_.Pool.Fee))
            $_.Profit_Accuracy = ([Double]1 - $_.Pool.MarginOfError)
            $_.Profit_Bias = $_.Pool.Price_Bias * (($_.Speed * ([Double]1 - $_.Fee)) * (1 - $_.Pool.Fee))
            $_.Profit_Unbias = $_.Pool.Price_Unbias * (($_.Speed * ([Double]1 - $_.Fee)) * (1 - $_.Pool.Fee))
        }

        $this.Algorithm = $this.Workers.Pool | Select-Object -ExpandProperty Algorithm
        $this.Algorithm_Base = $this.Algorithm -replace '-.+'
        $this.PoolName = $this.Workers.Pool | Select-Object -ExpandProperty Name
        $this.PoolName_Base = $this.PoolName -replace '-.+'
        $this.PoolFee = $this.Workers.Pool | Select-Object -ExpandProperty Fee
        $this.PoolPrice = $this.Workers.Pool | Select-Object -ExpandProperty Price
        $this.Fee = $this.Workers | Select-Object -ExpandProperty Fee
        $this.Speed = $this.Workers | Select-Object -ExpandProperty Speed
        $this.Benchmark = $this.Workers | Sort-Object Benchmark -Descending | Select-Object -ExpandProperty Benchmark -First 1

        $this.Profit = 0
        $this.Profit_Comparison = 0
        $this.Profit_Accuracy = 0
        $this.Profit_Bias = 0
        $this.Profit_Unbias = 0

        $this.Workers | ForEach-Object { 
            $this.Profit += $_.Profit
            $this.Profit_Comparison += $_.Profit_Comparison
            $this.Profit_Accuracy += $_.Profit_Accuracy * $_.Profit
            $this.Profit_Bias += $_.Profit_Bias
            $this.Profit_Unbias += $_.Profit_Unbias
        }

        if ($this.Profit -eq 0) { 
            $this.Profit_Accuracy = 1
        }
        else { 
            $this.Profit_Accuracy /= $this.Profit
        }
    }
}

enum DownloadStatus { 
    Idle
    Downloading
    Complete
    Failed
}

class Download { 
    hidden [DownloadStatus]$Status = [DownloadStatus]::Idle

    hidden static $TorrentEngine
    hidden static $TorrentEngine_DHT
    hidden static $TorrentEngine_DHT_Listener

    hidden $TorrentEngine_Manager
    hidden [System.Management.Automation.Job]$HttpJob

    hidden [System.Uri]$Uri
    hidden [System.Uri]$DownloadFilePath

    Download($Uri, $DownloadFilePath) { 
        $this.Uri = $Uri
        $this.DownloadFilePath = $DownloadFilePath
    }

    hidden Start_TorrentEngine() { 
        if ($this.TorrentEngine_Manager) { 
            $this.TorrentEngine_Manager.Stop()
            [Download]::TorrentEngine.Unregister($this.TorrentEngine_Manager)
            $this.TorrentEngine_Manager.Dispose()
            $this.TorrentEngine_Manager = $null
        }

        $Address = [System.Net.IPAddress]::Any
        $Port = Get-Random -Minimum ([System.Net.IPEndPoint]::MinPort) -Maximum ([System.Net.IPEndPoint]::MaxPort)

        if (-not [Download]::TorrentEngine_DHT) { 
            [Download]::TorrentEngine_DHT_Listener = New-Object "MonoTorrent.Dht.Listeners.DhtListener" ([System.Net.IPEndPoint]::new($Address, $Port))
            [Download]::TorrentEngine_DHT = New-Object "MonoTorrent.Dht.DhtEngine" ([Download]::TorrentEngine_DHT_Listener)
            [Download]::TorrentEngine_DHT.Start()

            for ($i = 0; $i -lt 60 * 2 -and [Download]::TorrentEngine_DHT.State -ne "Ready"; $i += 10) { 
                Start-Sleep 10
            }

            if ([Download]::TorrentEngine_DHT.State -ne "Ready") { 
                [Download]::TorrentEngine_DHT.Dispose()
                [Download]::TorrentEngine_DHT = $null
                $this.Status = [DownloadStatus]::Failed
                return
            }
        }

        if (-not [Download]::TorrentEngine) { 
            $TorrentEngine_Settings = New-Object "MonoTorrent.Client.EngineSettings"
            [Download]::TorrentEngine = New-Object "MonoTorrent.Client.ClientEngine" $TorrentEngine_Settings
            [Download]::TorrentEngine.ChangeListenEndpoint([System.Net.IPEndPoint]::new($Address, $Port))
            [Download]::TorrentEngine.RegisterDht([Download]::TorrentEngine_DHT)
        }

        if (-not $this.TorrentEngine_Manager) { 
            $Magnet = New-Object "MonoTorrent.Common.MagnetLink" $this.Uri
            $TorrentEngine_Manager_Settings = New-Object "MonoTorrent.Client.TorrentSettings"
            $this.TorrentEngine_Manager = New-Object "MonoTorrent.Client.TorrentManager" $Magnet, $this.DownloadFilePath.AbsolutePath, $TorrentEngine_Manager_Settings, (Join-Path $this.DownloadFilePath.AbsolutePath "$($Magnet.InfoHash).torrent")
            [Download]::TorrentEngine.Register($this.TorrentEngine_Manager)
        }

        $this.TorrentEngine_Manager.Start()
        $this.Status = [DownloadStatus]::Downloading
    }

    hidden Start_HttpJob() { 
        if ($this.HttpJob) { 
            Remove-Job $this.HttpJob -Force
            $this.HttpJob = $null
        }

        $this.HttpJob = Start-Job { 
            param($Uri, $DownloadFilePath)
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $Download = Invoke-WebRequest $Uri
            $Download_FileName = [String]($Download.Headers["Content-Disposition"] -split '; ' | ForEach-Object { [PSCustomObject]@{($_ -split '=')[0] = ($_ -split '=')[1] } } | Where-Object filename | Select-Object -Index 0 -ExpandProperty filename)
            [System.IO.File]::WriteAllBytes((Join-Path $DownloadFilePath $Download_FileName), $Download.Content)
        } -ArgumentList $this.Uri.AbsoluteUri, $this.DownloadFilePath.AbsolutePath

        $this.Status = [DownloadStatus]::Downloading

        return
    }

    Start() { 
        if ($this.GetStatus() -eq "Downloading") { return }

        if ($this.Uri.Scheme -eq "magnet") { 
            $this.Start_TorrentEngine()
        }
        elseif ($this.Uri.Scheme -eq "https" -and $this.Uri.Host -eq "mega.nz") { 
            #To-do: add support for 'https://mega.nz'
        }
        else { 
            $this.Start_HttpJob()
        }
    }

    Stop() { 
        if ($this.Uri.Scheme -eq "magnet") { 
            $this.TorrentEngine_Manager.Stop()
        }
        elseif ($this.Uri.Scheme -eq "https" -and $this.Uri.Host -eq "mega.nz") { 
            #To-do: add support for 'https://mega.nz'
        }
        else { 
            Stop-Job $this.HttpJob
        }

        $this.Status = [DownloadStatus]::Idle
    }

    hidden GetStatus_TorrentEngine() { 
        if (-not $this.TorrentEngine_Manager) { 
            if ($this.Status -ne "Idle") { 
                $this.Status = [DownloadStatus]::Failed
            }
            return
        }

        $TorrentEngine_Manager_State = $this.TorrentEngine_Manager.State

        if ($TorrentEngine_Manager_State -eq "Error") { 
            $this.Status = [DownloadStatus]::Failed
        }

        switch ($this.Status) { 
            "Idle" { 
                if ($TorrentEngine_Manager_State -ne "Stopped" -and $TorrentEngine_Manager_State -ne "Paused" -and $TorrentEngine_Manager_State -ne "Stopping") { 
                    $this.Status = [DownloadStatus]::Failed
                }
            }
            "Downloading" { 
                if ($TorrentEngine_Manager_State -eq "Seeding") { 
                    $this.Status = [DownloadStatus]::Complete
                }
                elseif ($TorrentEngine_Manager_State -ne "Downloading" -and $TorrentEngine_Manager_State -ne "Hashing" -and $TorrentEngine_Manager_State -ne "Metadata") { 
                    $this.Status = [DownloadStatus]::Failed
                }
            }
            "Complete" { 
                if ($TorrentEngine_Manager_State -ne "Seeding") { 
                    $this.Status = [DownloadStatus]::Failed
                }
            }
        }
    }

    hidden GetStatus_HttpJob() { 
        if (-not $this.HttpJob) { 
            if ($this.Status -ne "Idle") { 
                $this.Status = [DownloadStatus]::Failed
            }
            return
        }

        $HttpJob_State = $this.HttpJob.State

        if ($HttpJob_State -eq "Failed") { 
            $this.Status = [DownloadStatus]::Failed
        }

        switch ($this.Status) { 
            "Idle" { 
                if ($HttpJob_State -ne "Stopped" -and $HttpJob_State -ne "Suspended" -and $HttpJob_State -ne "Stopping") { 
                    $this.Status = [DownloadStatus]::Failed
                }
            }
            "Downloading" { 
                if ($HttpJob_State -eq "Completed") { 
                    $this.Status = [DownloadStatus]::Complete
                }
                elseif ($HttpJob_State -ne "Running") { 
                    $this.Status = [DownloadStatus]::Failed
                }
            }
            "Complete" { 
                if ($HttpJob_State -ne "Completed") { 
                    $this.Status = [DownloadStatus]::Failed
                }
            }
        }
    }

    [DownloadStatus]GetStatus() { 
        if ($this.Uri.Scheme -eq "magnet") { 
            $this.GetStatus_TorrentEngine()
        }
        elseif ($this.Uri.Scheme -eq "https" -and $this.Uri.Host -eq "mega.nz") { 
            #To-do: add support for 'https://mega.nz'
        }
        else { 
            $this.GetStatus_HttpJob()
        }

        return $this.Status
    }
}
