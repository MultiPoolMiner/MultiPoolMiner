#Load information about the miners
Write-Log "Getting legacy miner information. "
if (Test-Path "MinersLegacy" -PathType Container -ErrorAction Ignore) { 
    #Strip Model information from devices -> will create only one miner instance
    if ($Config.DisableDeviceDetection) { $DevicesTmp = $Devices | ConvertTo-Json -Depth 10 | ConvertFrom-Json; $DevicesTmp | ForEach-Object { $_.Model = $_.Vendor } } else { $DevicesTmp = $Devices }

    Get-ChildItemContent "MinersLegacy" -Parameters @{Pools = $LegacyPools; Stats = $Stats; Config = $Config; Devices = $DevicesTmp; JobName = "MinersLegacy" } -Priority $(if ($RunningMiners | Where-Object { $_.DeviceName -like "CPU#*" }) { "Normal" }) | ForEach-Object { 
        $LegacyMiner_Fees = $_.Content.Fees

        @{ 
            Pool               = $_.Content.HashRates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { $LegacyPools.$_ }

            Name               = $(
                if ($_.Content.Name -isnot [String]) { 
                    $_.Name
                }
                else { 
                    $_.Content.Name
                }
            )
            Path               = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($_.Content.Path)
            Arguments          = $(
                if ($_.Content.Arguments -isnot [String]) { 
                    $_.Content.Arguments | ConvertTo-Json -Depth 10 -Compress
                }
                else { 
                    $_.Content.Arguments
                }
            )
            Port               = $_.Content.Port
            DeviceName         = $_.Content.DeviceName

            Fee                = $_.Content.HashRates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { $LegacyMiner_Fees.$_ }

            ShowMinerWindow    = $_.Content.ShowMinerWindow
            IntervalMultiplier = $(
                if ($_.Content.IntervalMultiplier -ge 1) { 
                    $_.Content.IntervalMultiplier
                }
                else { 
                    1
                }
            )
            WarmupTime         = $_.Content.WarmupTime

            #HashSHA256
            #URI
            #PrerequisitePath
            #PrerequisiteURI
        } -as $_.Content.API
    }

    Remove-Variable DevicesTmp
}
