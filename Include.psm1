Set-Location (Split-Path $MyInvocation.MyCommand.Path)

Add-Type -Path .\OpenCL\*.cs

try {
    Add-Type -Path (".\MonoTorrent\*.cs" | Get-ChildItem -Recurse).FullName -IgnoreWarnings -ReferencedAssemblies "System.Xml" -ErrorAction Stop
}
catch {
    Add-Type -Path (".\MonoTorrent\*.cs" | Get-ChildItem -Recurse).FullName -IgnoreWarnings
}

function Get-CommandPerDevice {

# rewrites the command parameters
# if a parameter has multiple values, only the values for the available devices are returned
# parameters with a single value are valid for all devices and remain untouched
# supported parameter syntax:
#$Command = ",c=BTC -9 1  -y  2 -a 00,11,22,33,44,55  -b=00,11,22,33,44,55 --c==00,11,22,33,44,55 --d --e=00,11,22,33,44,55 -f -g 00 11 22 33 44 55 ,c=LTC  -h 00 11 22 33 44 55 -i=,11,,33,,55 --j=00,11,,,44,55 --k==00,,,33,44,55 -l -zzz=0123,1234,2345,3456,4567,5678,6789 -u 0  --p all ,something=withcomma blah *blah *blah"
#$Devices = @(0;1;4)
# Result: ",c=BTC -9 1  -y  2 -a 00,11,44  -b=00,11,44 --c==00,11,44 --d --e=00,11,44 -f -g 00 11 44 ,c=LTC  -h 00 11 44 -i=,11 --j=00,11,44 --k==00,,44 -l -zzz=0123,1234,4567 -u 0  --p all ,something=withcomma blah *blah *blah"
#$Devices = @(1)
# Result: ",c=BTC -9 1  -y  2 -a 11  -b=11 --c==11 --d --e=11 -f -g 11 ,c=LTC  -h 11 -i=11 --j=11 --k== -l -zzz=1234 -u 0  --p all ,something=withcomma blah *blah *blah"
#$Devices = @(0;2;9)
# Result: ",c=BTC -9 1  -y  2 -a 00,22  -b=00,22 --c==00,22 --d --e=00,22 -f -g 00 22 ,c=LTC  -h 00 22 -i= --j=00 --k==00 -l -zzz=0123,2345 -u 0  --p all ,something=withcomma blah *blah *blah"

[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [String]$Command,
        [Parameter(Mandatory = $false)]
        [Int[]]$Devices
    )

    $CommandPerDevice = ""

    $Command -split "(?=\s{1,}--|\s{1,}-| ,|^,)" | ForEach-Object {
        $Token = $_
        $Prefix = $null
        $ParameterValueSeparator = $null
        $ValueSeparator = $null
        $Values = $null

        if ($Token.TrimStart() -match "(?:^[-=]{1,})") { # supported prefix characters are listed in brackets: [-=]{1,}

            $Prefix = "$($Token -split $Matches[0] | Select -Index 0)$($Matches[0])"
            $Token = $Token -split $Matches[0] | Select -Last 1

            if ($Token -match "(?:[ =]{1,})") { # supported separators are listed in brackets: [ =]{1,}
                $ParameterValueSeparator = $Matches[0]
                $Parameter = $Token -split $ParameterValueSeparator | Select -Index 0
                $Values = $Token.Substring(("$($Parameter)$($ParameterValueSeparator)").length)

                if ($Values -match "(?:[,; ]{1})") { # supported separators are listed in brackets: [,; ]{1}
                    $ValueSeparator = $Matches[0]
                    $RelevantValues = @()
                    $Devices | Foreach-Object {
                        if ($Values.Split($ValueSeparator) | Select -Index $_) {$RelevantValues += ($Values.Split($ValueSeparator) | Select -Index $_)}
                        else {$RelevantValues += ""}
                    }                    
                    $CommandPerDevice += "$($Prefix)$($Parameter)$($ParameterValueSeparator)$(($RelevantValues -join $ValueSeparator).TrimEnd($ValueSeparator))"
                }
                else {$CommandPerDevice += "$($Prefix)$($Parameter)$($ParameterValueSeparator)$($Values)"}
            }
            else {$CommandPerDevice += "$($Prefix)$($Token)"}
        }
        else {$CommandPerDevice += $Token}
    }
    $CommandPerDevice
}

function Get-Balance {
    [CmdletBinding()]
    param($Config, $NewRates)

    $Data = [PSCustomObject]@{}

    $Balances = @(Get-ChildItem "Balances" -File | Where-Object {$Config.Pools.$($_.BaseName) -and ($Config.ExcludePoolName -inotcontains $_.BaseName -or $Config.ShowPoolBalancesExcludedPools)} | ForEach-Object {
            Get-ChildItemContent "Balances\$($_.Name)" -Parameters @{Config = $Config}
        } | Foreach-Object {$_.Content | Add-Member Name $_.Name -PassThru -Force} | Sort-Object Name)

    #Get exchgange rates for all payout currencies
    $CurrenciesWithBalances = @($Balances.currency | Sort-Object -Unique)
    try {
        $Rates = Invoke-RestMethod "https://min-api.cryptocompare.com/data/pricemulti?fsyms=$($CurrenciesWithBalances -join ",")&tsyms=$($Config.Currency -join ",")&extraParams=http://multipoolminer.io" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    }
    catch {
        Write-Log -Level Warn "Pool API (CryptoCompare) has failed - cannot convert balances to other currencies. "
        Return $Balances
    }

    #Add total of totals
    $Totals = [PSCustomObject]@{
        Name = "*Total*"
    }
    #Add Balance (in currency)
    $Rates.PSObject.Properties.Name | ForEach-Object {
        $Currency = $_.ToUpper()
        $Balances | Foreach-Object {
            if ($NewRates.$Currency -ne $null) {$Digits = ($($NewRates.$Currency).ToString().Split(".")[1]).length}else {$Digits = 8}
            $_.Total = ("{0:N$($Digits)}" -f ([Float]$($_.Total)))
            if ($Currency -eq $_.Currency) {
                $_ | Add-Member "Balance ($Currency)" $_.Total
            }
        }
        if (($Balances."Balance ($Currency)" | Measure-Object -Sum).sum) {$Totals | Add-Member "Balance ($Currency)" ("{0:N$($Digits)}" -f ([Float]$($Balances."Balance ($Currency)" | Measure-Object -Sum).sum))}
    }

    #Add converted values
    $Config.Currency | ForEach-Object {
        $Currency = $_.ToUpper()
        #Get number of digits from $NewRates
        if ($NewRates.$Currency -ne $null) {$Digits = ($($NewRates.$Currency).ToString().Split(".")[1]).length}else {$Digits = 8}
        $Balances | Foreach-Object {
            $_ | Add-Member "Value in $Currency" $(if ($Rates.$($_.Currency).$Currency) {("{0:N$($Digits)}" -f ([Float]$_.Total * [Float]$Rates.$($_.Currency).$Currency))}else {"unknown"}) -Force
        }
        if (($Balances."Value in $Currency" | Measure-Object -Sum -ErrorAction Ignore).sum) {$Totals | Add-Member "Value in $Currency" ("{0:N$($Digits)}" -f ([Float]$($Balances."Value in $Currency" | Measure-Object -Sum -ErrorAction Ignore).sum)) -Force}
    }
    $Balances += $Totals

    $Data | Add-Member Balances $Balances
    $Data | Add-Member Rates $Rates

    Return $Data
}

function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)][ValidateNotNullOrEmpty()][Alias("LogContent")][string]$Message,
        [Parameter(Mandatory = $false)][ValidateSet("Error", "Warn", "Info", "Verbose", "Debug")][string]$Level = "Info"
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

        if (-not (Test-Path "Stats" -PathType Container)) {New-Item "Stats" -ItemType "directory" | Out-Null}

        switch ($Level) {
            'Error' {
                $LevelText = 'ERROR:'
                Write-Error -Message $Message
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

    $Stat = Get-Content $Path -ErrorAction SilentlyContinue

    try {
        $Stat = $Stat | ConvertFrom-Json -ErrorAction Stop
        $Stat = [PSCustomObject]@{
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

        $ToleranceMin = $Value
        $ToleranceMax = $Value

        if ($FaultDetection) {
            $ToleranceMin = $Stat.Week * (1 - [Math]::Min([Math]::Max($Stat.Week_Fluctuation * 2, 0.1), 0.9))
            $ToleranceMax = $Stat.Week * (1 + [Math]::Min([Math]::Max($Stat.Week_Fluctuation * 2, 0.1), 0.9))
        }

        if ($ChangeDetection -and [Decimal]$Value -eq [Decimal]$Stat.Live) {$Updated = $Stat.updated}

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

            $Stat = [PSCustomObject]@{
                Live                  = $Value
                Minute                = ((1 - $Span_Minute) * $Stat.Minute) + ($Span_Minute * $Value)
                Minute_Fluctuation    = ((1 - $Span_Minute) * $Stat.Minute_Fluctuation) + 
                ($Span_Minute * ([Math]::Abs($Value - $Stat.Minute) / [Math]::Max([Math]::Abs($Stat.Minute), $SmallestValue)))
                Minute_5              = ((1 - $Span_Minute_5) * $Stat.Minute_5) + ($Span_Minute_5 * $Value)
                Minute_5_Fluctuation  = ((1 - $Span_Minute_5) * $Stat.Minute_5_Fluctuation) + 
                ($Span_Minute_5 * ([Math]::Abs($Value - $Stat.Minute_5) / [Math]::Max([Math]::Abs($Stat.Minute_5), $SmallestValue)))
                Minute_10             = ((1 - $Span_Minute_10) * $Stat.Minute_10) + ($Span_Minute_10 * $Value)
                Minute_10_Fluctuation = ((1 - $Span_Minute_10) * $Stat.Minute_10_Fluctuation) + 
                ($Span_Minute_10 * ([Math]::Abs($Value - $Stat.Minute_10) / [Math]::Max([Math]::Abs($Stat.Minute_10), $SmallestValue)))
                Hour                  = ((1 - $Span_Hour) * $Stat.Hour) + ($Span_Hour * $Value)
                Hour_Fluctuation      = ((1 - $Span_Hour) * $Stat.Hour_Fluctuation) + 
                ($Span_Hour * ([Math]::Abs($Value - $Stat.Hour) / [Math]::Max([Math]::Abs($Stat.Hour), $SmallestValue)))
                Day                   = ((1 - $Span_Day) * $Stat.Day) + ($Span_Day * $Value)
                Day_Fluctuation       = ((1 - $Span_Day) * $Stat.Day_Fluctuation) + 
                ($Span_Day * ([Math]::Abs($Value - $Stat.Day) / [Math]::Max([Math]::Abs($Stat.Day), $SmallestValue)))
                Week                  = ((1 - $Span_Week) * $Stat.Week) + ($Span_Week * $Value)
                Week_Fluctuation      = ((1 - $Span_Week) * $Stat.Week_Fluctuation) + 
                ($Span_Week * ([Math]::Abs($Value - $Stat.Week) / [Math]::Max([Math]::Abs($Stat.Week), $SmallestValue)))
                Duration              = $Stat.Duration + $Duration
                Updated               = $Updated
            }
        }
    }
    catch {
        if (Test-Path $Path -PathType Leaf) {Write-Log -Level Warn "Stat file ($Name) is corrupt and will be reset. "}

        $Stat = [PSCustomObject]@{
            Live                  = $Value
            Minute                = $Value
            Minute_Fluctuation    = 0
            Minute_5              = $Value
            Minute_5_Fluctuation  = 0
            Minute_10             = $Value
            Minute_10_Fluctuation = 0
            Hour                  = $Value
            Hour_Fluctuation      = 0
            Day                   = $Value
            Day_Fluctuation       = 0
            Week                  = $Value
            Week_Fluctuation      = 0
            Duration              = $Duration
            Updated               = $Updated
        }
    }

    if (-not (Test-Path "Stats" -PathType Container)) {New-Item "Stats" -ItemType "directory" | Out-Null}
    [PSCustomObject]@{
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
        [String]$Name
    )

    if (-not (Test-Path "Stats" -PathType Container)) {New-Item "Stats" -ItemType "directory" | Out-Null}

    if ($Name) {
        # Return single requested stat
        Get-ChildItem "Stats" -File | Where-Object BaseName -EQ $Name | Get-Content | ConvertFrom-Json
    }
    else {
        # Return all stats
        $Stats = [PSCustomObject]@{}
        Get-ChildItem "Stats" -File | ForEach-Object {
            $BaseName = $_.BaseName
            $FullName = $_.FullName
            try {
                $_ | Get-Content -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop | ForEach-Object {
                    $Stats | Add-Member $BaseName $_
                }
            }
            catch {
                #Remove broken stat file
                Write-Log -Level Warn "Stat file ($BaseName) is corrupt and will be reset. "
                Remove-Item -Path  $FullName -Force -Confirm:$false
            }
        }
        Return $Stats
    }
}

function Get-ChildItemContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Path, 
        [Parameter(Mandatory = $false)]
        [Hashtable]$Parameters = @{}
    )

    function Invoke-ExpressionRecursive ($Expression) {
        if ($Expression -is [String]) {
            if ($Expression -match '(\$|")') {
                try {$Expression = Invoke-Expression $Expression}
                catch {$Expression = Invoke-Expression "`"$Expression`""}
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
                $Parameters.Keys | ForEach-Object {Set-Variable $_ $Parameters.$_}
                & $_.FullName @Parameters
            }
        }
        else {
            $Content = & {
                $Parameters.Keys | ForEach-Object {Set-Variable $_ $Parameters.$_}
                try {
                    ($_ | Get-Content | ConvertFrom-Json) | ForEach-Object {Invoke-ExpressionRecursive $_}
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

function ConvertTo-LocalCurrency { 
    [CmdletBinding()]
    # To get same numbering scheme regardless of value BTC value (size) to determine formatting
    # Use $Offset to add/remove decimal places

    param(
        [Parameter(Mandatory = $true)]
        [Double]$Value, 
        [Parameter(Mandatory = $true)]
        [Double]$BTCRate,
        [Parameter(Mandatory = $false)]
        [Int]$Offset        
    )

    $Digits = ([math]::truncate(10 - $Offset - [math]::log($BTCRate, 10)))
    if ($Digits -lt 0) {$Digits = 0}
    if ($Digits -gt 10) {$Digits = 10}

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
        [String]$LogPath = "", 
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = "", 
        [ValidateRange(-2, 3)]
        [Parameter(Mandatory = $false)]
        [Int]$Priority = 0
    )

    $ScriptBlock = "Set-Location '$WorkingDirectory'; (Get-Process -Id `$PID).PriorityClass = '$(@{-2 = "Idle"; -1 = "BelowNormal"; 0 = "Normal"; 1 = "AboveNormal"; 2 = "High"; 3 = "RealTime"}[$Priority])'; "
    $ScriptBlock += "& '$FilePath'"
    if ($ArgumentList) {$ScriptBlock += " $ArgumentList"}
    $ScriptBlock += " *>&1"
    $ScriptBlock += " | Write-Output"
    if ($LogPath) {$ScriptBlock += " | Tee-Object '$LogPath'"}

    Start-Job ([ScriptBlock]::Create($ScriptBlock))
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

    if (-not $Path) {$Path = Join-Path ".\Downloads" ([IO.FileInfo](Split-Path $Uri -Leaf)).BaseName}
    if (-not (Test-Path ".\Downloads" -PathType Container)) {New-Item "Downloads" -ItemType "directory" | Out-Null}
    $FileName = Join-Path ".\Downloads" (Split-Path $Uri -Leaf)

    if (Test-Path $FileName -PathType Leaf) {Remove-Item $FileName}
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest $Uri -OutFile $FileName -UseBasicParsing

    if (".msi", ".exe" -contains ([IO.FileInfo](Split-Path $Uri -Leaf)).Extension) {
        Start-Process $FileName "-qb" -Wait
    }
    else {
        $Path_Old = (Join-Path (Split-Path (Split-Path $Path)) ([IO.FileInfo](Split-Path $Uri -Leaf)).BaseName)
        $Path_New = Split-Path $Path

        if (Test-Path $Path_Old -PathType Container) {Remove-Item $Path_Old -Recurse -Force}
        Start-Process "7z" "x `"$([IO.Path]::GetFullPath($FileName))`" -o`"$([IO.Path]::GetFullPath($Path_Old))`" -y -spe" -Wait -WindowStyle Hidden

        if (Test-Path $Path_New -PathType Container) {Remove-Item $Path_New -Recurse -Force}

        #use first (topmost) directory in case, e.g. ClaymoreDual_v11.9, contain multiple miner binaries for different driver versions in various sub dirs
        $Path_Old = (Get-ChildItem $Path_Old -File -Recurse | Where-Object {$_.Name -EQ $(Split-Path $Path -Leaf)}).Directory | Select-Object -First 1

        if ($Path_Old) {
            Move-Item $Path_Old $Path_New -PassThru | ForEach-Object -Process {$_.LastWritetime = Get-Date}
            $Path_Old = (Join-Path (Split-Path (Split-Path $Path)) ([IO.FileInfo](Split-Path $Uri -Leaf)).BaseName)
            if (Test-Path $Path_Old -PathType Container) {Remove-Item $Path_Old -Recurse -Force}
        }
        else {
            Throw "Error: Cannot find $($Path). "
        }
    }
}

function Get-TCPResponse {
    [cmdletbinding()]
    Param (        
        [Parameter(Mandatory = $true)]
        $Server = "localhost", 
        [Parameter(Mandatory = $true)]
        $Port,
        [Parameter(Mandatory = $true)]
        $Timeout = 100
    )

    try {
        $Response = ""
        $Client = New-Object System.Net.Sockets.TCPClient $Server, $Port
        Start-Sleep -Milliseconds $TimeOut
        if ([int64]$Client.Available -gt 0) {
            $Stream = $Client.GetStream()
            $BindResponseBuffer = New-Object Byte[] -ArgumentList $Client.Available
            $Read = $Stream.Read($BindResponseBuffer, 0, $BindResponseBuffer.count)  
            $Response = ($BindResponseBuffer | ForEach {[char][int]$_}) -join ''
        }
    }
    finally {
        if ($Client) {$Client.Close()}
    }

    $Response
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
            $Name_Split = @($Name_Split | Select-Object -First 1) + @($Name_Split | Select-Object -Skip 1 | ForEach-Object {[Int]$_})
            $Name_Split += @("*") * (100 - $Name_Split.Count)

            $Name_Device = $DeviceList.("{0}" -f $Name_Split) | Select-Object *
            $Name_Device | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Name_Device.$_ = $Name_Device.$_ -f $Name_Split}

            $Name_Device
        }
    }

    if ($ExcludeName) {
        if (-not $DeviceList) {$DeviceList = Get-Content "Devices.txt" | ConvertFrom-Json}
        $ExcludeName_Devices = $ExcludeName | ForEach-Object {
            $ExcludeName_Split = $_ -split '#'
            $ExcludeName_Split = @($ExcludeName_Split | Select-Object -First 1) + @($ExcludeName_Split | Select-Object -Skip 1 | ForEach-Object {[Int]$_})
            $ExcludeName_Split += @("*") * (100 - $ExcludeName_Split.Count)

            $ExcludeName_Device = $DeviceList.("{0}" -f $ExcludeName_Split) | Select-Object *
            $ExcludeName_Device | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$ExcludeName_Device.$_ = $ExcludeName_Device.$_ -f $ExcludeName_Split}

            $ExcludeName_Device
        }
    }

    # Try to get cached devices first to improve performance
    if ((Test-Path Variable:Script:CachedDevices) -and -not $Refresh) {
        $Devices = $CachedDevices
        $Devices | Foreach-Object {
            $Device = $_
            if ((-not $Name) -or ($Name_Devices | Where-Object {($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -like ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name))})) {
                if ((-not $ExcludeNameName) -or ($ExcludeName_Devices | Where-Object {($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -notlike ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name))})) {
                    $Device
                }
            }
        }
        return
    }

    $Devices = @()
    $PlatformId = 0
    $Index = 0
    $PlatformId_Index = @{}
    $Type_PlatformId_Index = @{}
    $Vendor_Index = @{}
    $Type_Vendor_Index = @{}
    $Type_Index = @{}

        try {
        [OpenCl.Platform]::GetPlatformIDs() | ForEach-Object {
            [OpenCl.Device]::GetDeviceIDs($_, [OpenCl.DeviceType]::All) | ForEach-Object {
                $Device_OpenCL = $_ | ConvertTo-Json | ConvertFrom-Json
                $Device = [PSCustomObject]@{
                    Index = [Int]$Index
                    PlatformId = [Int]$PlatformId
                    PlatformId_Index = [Int]$PlatformId_Index."$($PlatformId)"
                    Type_PlatformId_Index = [Int]$Type_PlatformId_Index."$($Device_OpenCL.Type)"."$($PlatformId)"
                    Vendor = [String]$Device_OpenCL.Vendor
                    Vendor_ShortName = $(Switch ([String]$Device_OpenCL.Vendor)
                        {
                        "Advanced Micro Devices, Inc." {"AMD"}
                        "Intel(R) Corporation" {"INTEL"}
                        "NVIDIA Corporation" {"NVIDIA"}
                        default {[String]$Device_OpenCL.Vendor}
                        }
                    )
                    Vendor_Index = [Int]$Vendor_Index."$($Device_OpenCL.Vendor)"
                    Type_Vendor_Index = [Int]$Type_Vendor_Index."$($Device_OpenCL.Type)"."$($Device_OpenCL.Vendor)"
                    Type = [String]$Device_OpenCL.Type
                    Type_Index = [Int]$Type_Index."$($Device_OpenCL.Type)"
                    OpenCL = $Device_OpenCL
                    Model = "$($Device_OpenCL.Name)$(if ($Device_OpenCL.Vendor -eq "Advanced Micro Devices, Inc.") {"$($Device_OpenCL.GlobalMemSize / 1GB)GB"})"
                    Model_Norm = "$($Device_OpenCL.Name -replace '[^A-Z0-9]' -replace 'GeForce')$(if ($Device_OpenCL.Vendor -eq "Advanced Micro Devices, Inc.") {"$($Device_OpenCL.GlobalMemSize / 1GB)GB"})"
                }

                if ((-not $Name) -or ($Name_Devices | Where-Object {($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -like ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name))})) {
                    if ((-not $ExcludeName) -or ($ExcludeName_Devices | Where-Object {($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -notlike ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name))})) {
                        $Devices += $Device | Add-Member Name ("{0}#{1:d2}" -f $Device.Type, $Device.Type_Index).ToUpper() -PassThru
                    }
                }

                if (-not $Type_PlatformId_Index."$($Device_OpenCL.Type)") {
                    $Type_PlatformId_Index."$($Device_OpenCL.Type)" = @{}
                }
                if (-not $Type_Vendor_Index."$($Device_OpenCL.Type)") {
                    $Type_Vendor_Index."$($Device_OpenCL.Type)" = @{}
                }

                $Index++
                $PlatformId_Index."$($PlatformId)"++
                $Type_PlatformId_Index."$($Device_OpenCL.Type)"."$($PlatformId)"++
                $Vendor_Index."$($Device_OpenCL.Vendor)"++
                $Type_Vendor_Index."$($Device_OpenCL.Type)"."$($Device_OpenCL.Vendor)"++
                $Type_Index."$($Device_OpenCL.Type)"++
            }

            $PlatformId++
        }
    }
    catch {
        Write-Log -Level Warn "OpenCL device detection has failed. "
    }

    # CPU detection in OpenCL does not work well, sometimes not being included, sometimes being included twice for each processor - remove any CPUs from the OpenCL devices and generate more accurate ones
    # Remove them instead of not generating them in the first place, because skipping them would affect the indexes
    [array]$Devices = $Devices | Where-Object {$_.Type -ne "Cpu"}

    $CPUIndex = 0
    Get-CimInstance -ClassName CIM_Processor | Foreach-Object {
        # Vendor and type the same for all CPUs, so there is no need to actually track the extra indexes.  Include them only for compatibility.
        $CPUInfo = $_ | ConvertTo-Json | ConvertFrom-Json
        $Device = [PSCustomObject]@{
            Index = [Int]$Index
            Vendor = $CPUInfo.Manufacturer
            Vendor_ShortName = $(if ($CPUInfo.Manufacturer -eq "GenuineIntel") {"INTEL"} else {"AMD"})
            Type_Vendor_Index = $CPUIndex
            Type = "Cpu"
            Type_Index = $CPUIndex
            CIM = $CPUInfo
            Model = $CPUInfo.Name
            Model_Norm = "$($CPUInfo.Manufacturer)$($CPUInfo.NumberOfCores)CoreCPU"
        }

        if ((-not $Name) -or ($Name_Devices | Where-Object {($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -like ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name))})) {
            if ((-not $ExcludeName) -or ($ExcludeName_Devices | Where-Object {($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -notlike ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name))})) {
                $Devices += $Device | Add-Member Name ("{0}#{1:d2}" -f $Device.Type, $Device.Type_Index).ToUpper() -PassThru
            }
        }

        $CPUIndex++
        $Index++
    }
    $Script:CachedDevices = $Devices
    $Devices
}

function Get-Algorithm {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Algorithm = ""
    )

    if (-not (Test-Path Variable:Script:Algorithms)) {
        $Script:Algorithms = Get-Content "Algorithms.txt" | ConvertFrom-Json
    }

    $Algorithm = (Get-Culture).TextInfo.ToTitleCase(($Algorithm -replace "-", " " -replace "_", " ")) -replace " "

    if ($Script:Algorithms.$Algorithm) {$Script:Algorithms.$Algorithm}
    else {$Algorithm}
}

function Get-Region {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Region = ""
    )

    if (-not (Test-Path Variable:Script:Regions)) {
        $Script:Regions = Get-Content "Regions.txt" | ConvertFrom-Json
    }

    $Region = (Get-Culture).TextInfo.ToTitleCase(($Region -replace "-", " " -replace "_", " ")) -replace " "

    if ($Script:Regions.$Region) {$Script:Regions.$Region}
    else {$Region}
}

enum MinerStatus {
    Running
    Idle
    Failed
}

class Miner {
    $Name
    $Path
    $Arguments
    $Wrap
    $API
    $Port
    [string[]]$Algorithm = @()
    $DeviceName
    $Profit
    $Profit_Comparison
    $Profit_MarginOfError
    $Profit_Bias
    $Profit_Unbias
    $Speed
    $Speed_Live
    $Best
    $Best_Comparison
    hidden [System.Management.Automation.Job]$Process = $null
    $New
    hidden [TimeSpan]$Active = [TimeSpan]::Zero
    hidden [Int]$Activated = 0
    hidden [MinerStatus]$Status = [MinerStatus]::Idle
    $Benchmarked
    $LogFile
    $Pool
    hidden [Array]$Data = @()
    $ShowMinerWindow
    $BenchmarkIntervals
    $ProcessId

    [String[]]GetProcessNames() {
        return @(([IO.FileInfo]($this.Path | Split-Path -Leaf -ErrorAction Ignore)).BaseName)
    }

    [String]GetCommandLineParameters() {
        return $this.Arguments
    }
    
    [String]GetCommandLine() {
        return "$($this.Path) $($this.GetCommandLineParameters())"
    }

    hidden StartMining() {
        $this.Status = [MinerStatus]::Failed

        $this.New = $true
        $this.Activated++

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
                $this.Process = Start-Job ([ScriptBlock]::Create("Start-Process $(@{desktop = "powershell"; core = "pwsh"}.$Global:PSEdition) `"-command ```$Process = (Start-Process '$($this.Path)' '$($this.Arguments)' -WorkingDirectory '$(Split-Path $this.Path)' -WindowStyle Minimized -PassThru).Id; Wait-Process -Id `$PID; Stop-Process -Id ```$Process`" -WindowStyle Hidden -Wait"))
            }
            else {
                $this.LogFile = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Logs\$($this.Name)-$($this.Port)_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt")
                $this.Process = Start-SubProcess -FilePath $this.Path -ArgumentList $this.Arguments -LogPath $this.LogFile -WorkingDirectory (Split-Path $this.Path) -Priority ($this.Device.Type | ForEach-Object {if ($_ -eq "CPU") {-2}else {-1}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum)
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

    hidden StopMining() {
        $this.Status = [MinerStatus]::Failed

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
            return $this.Process.PSEndTime
        }
        elseif ($this.Process.PSBeginTime) {
            return Get-Date
        }
        else {
            return [DateTime]::MinValue
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
        if ($this.Process.State -eq "Running" -and $this.ProcessId -and (Get-Process -Id $this.ProcessId -ErrorAction SilentlyContinue)) {
            return [MinerStatus]::Running
        }
        elseif ($this.Status -eq "Running") {
            $this.ProcessId = $null
            $this.Status = [MinerStatus]::Failed
            return [MinerStatus]::Failed
        }
        else {
            return $this.Status
        }
    }

    SetStatus([MinerStatus]$Status) {
        if ($Status -eq $this.GetStatus()) {return}

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
                                "kh/s*" {$HashRate *= [Math]::Pow(1000, 1)}
                                "mh/s*" {$HashRate *= [Math]::Pow(1000, 2)}
                                "gh/s*" {$HashRate *= [Math]::Pow(1000, 3)}
                                "th/s*" {$HashRate *= [Math]::Pow(1000, 4)}
                                "ph/s*" {$HashRate *= [Math]::Pow(1000, 5)}
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

                    $this.Data += [PSCustomObject]@{
                        Date = $Date
                        Raw = $Line_Simple
                        HashRate = [PSCustomObject]@{[String]$this.Algorithm = [Int64]$HashRates}
                        Device = $Devices
                    }
                }
            }

            $this.Data = @($this.Data | Select-Object -Last 10000)
        }

        return $Lines
    }

    [Int64]GetHashRate([String]$Algorithm = [String]$this.Algorithm, [Int]$Seconds = 60, [Boolean]$Safe = $this.New) {
        $HashRates_Devices = @($this.Data | Where-Object Device | Select-Object -ExpandProperty Device -Unique)
        if (-not $HashRates_Devices) {$HashRates_Devices = @("Device")}

        $HashRates_Counts = @{}
        $HashRates_Averages = @{}
        $HashRates_Variances = @{}
        $Hashrates_Samples = @{}

        #strip lower 10% and upper 10% of all values for better hashrate stability
        $Hashrates_Samples = @($this.Data | Where-Object {$_.HashRate.$Algorithm} | Where-Object {$_.Date -GE (Get-Date).ToUniversalTime().AddSeconds( - $Seconds)})
        $Hashrates_Samples | Sort-Object {$_.HashRate.$Algorithm} | Select-Object -Skip ([Int]($HashRates_Samples.Count * 0.1)) | Select-Object -SkipLast ([Int]($HashRates_Samples.Count * 0.1)) | ForEach-Object {

            $Data_Devices = $_.Device
            if (-not $Data_Devices) {$Data_Devices = $HashRates_Devices}

            $Data_HashRates = $_.HashRate.$Algorithm

            $Data_Devices | ForEach-Object {$HashRates_Counts.$_++}
            $Data_Devices | ForEach-Object {$HashRates_Averages.$_ += @(($Data_HashRates | Measure-Object -Sum | Select-Object -ExpandProperty Sum) / $Data_Devices.Count)}
            $HashRates_Variances."$($Data_Devices | ConvertTo-Json)" += @($Data_HashRates | Measure-Object -Sum | Select-Object -ExpandProperty Sum)
        }

        $HashRates_Count = $HashRates_Counts.Values | ForEach-Object {$_} | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
        $HashRates_Average = ($HashRates_Averages.Values | ForEach-Object {$_} | Measure-Object -Average | Select-Object -ExpandProperty Average) * $HashRates_Averages.Keys.Count
        $HashRates_Variance = $HashRates_Variances.Keys | ForEach-Object {$_} | ForEach-Object {$HashRates_Variances.$_ | Measure-Object -Average -Minimum -Maximum} | ForEach-Object {if ($_.Average) {($_.Maximum - $_.Minimum) / $_.Average}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

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
}
