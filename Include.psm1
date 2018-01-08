Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1" -ErrorAction Ignore
Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1" -ErrorAction Ignore

Set-Location (Split-Path $MyInvocation.MyCommand.Path)

Add-Type -Path .\OpenCL\*.cs

Function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)][ValidateNotNullOrEmpty()][Alias("LogContent")][string]$Message,
        [Parameter(Mandatory=$false)][ValidateSet("Error","Warn","Info","Verbose","Debug")][string]$Level = "Info"
    )

    Begin { }
    Process {
        $filename = ".\Logs\MultiPoolMiner-$(Get-Date -Format "yyyy-MM-dd").txt"
        $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        if (-not (Test-Path "Stats")) {New-Item "Stats" -ItemType "directory" | Out-Null}
        
        switch($Level) {
            'Error' {
                $LevelText = 'ERROR:'
                if($ErrorActionPreference -ne 'SilentlyContinue') {
                    Write-Host -ForegroundColor Red -Object "$date $LevelText $Message"
                }
            }
            'Warn' {
                $LevelText = 'WARNING:'
                if($WarningPreference -ne 'SilentlyContinue') {
                    Write-Host -ForegroundColor Yellow -Object "$date $LevelText $Message"
                }
            }
            'Info' {
                $LevelText = 'INFO:'
                Write-Host -ForegroundColor DarkCyan -Object "$date $LevelText $Message"
            }
            'Verbose' {
                $LevelText = 'VERBOSE:'
                if($VerbosePreference -ne 'SilentlyContinue') {
                    Write-Host -ForegroundColor Cyan -Object "$date $LevelText $Message"
                }
            }
            'Debug' {
                $LevelText = 'DEBUG:'
                if($DebugPreference -ne 'SilentlyContinue') {
                    Write-Host -ForegroundColor Gray -Object "$date $LevelText $Message"
                }
            }
        }
        "$date $LevelText $Message" | Out-File -FilePath $filename -Append
    }
    End {}
}

Function Get-BittrexMarkets {
    # Get a list of markets. This list includes both the long and short names of each currency.
    $filename = 'Cache\BittrexMarkets.json'

    # Use cached data if it's less than 1 day old
    if(Test-Path $filename) {
        $lastupdated = (Get-Item $filename).LastWriteTime
        $timespan = New-TimeSpan -Days 1

        if(((Get-Date) - $lastupdated) -lt $timespan) {
            Write-Log 'Using cached market list...'
            $markets = Get-Content $filename | ConvertFrom-Json
            return $markets
        }
    } 

    Write-Log 'Updating markets from API...'
    try {
        $Request = Invoke-RestMethod "https://bittrex.com/api/v1.1/public/getmarkets" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    } catch {
        Write-Log -Level Warn "Bittrex exchange API has failed. "
        Return 0
    }
    
    $markets = $Request.result | Where-Object {$_.BaseCurrency -eq 'BTC'}
    Write-Log "$($markets.count) markets loaded"
    $markets | ConvertTo-Json | Set-Content $filename

    return $markets
}

function Get-BTCValue {
    param (
        [Parameter(Mandatory=$true)][string]$altcoin,
        [Parameter(Mandatory=$true)][double]$amount

    )
    # This gets the exchange rate from bittrex.com for various altcoins, and returns an equivelent BTC value
    # Exchange rates are cached to avoid abusing their API.  If the cached rates are more than 1 hour old, they will be refreshed.
    $VerbosePreference = 'continue'
    $filename = 'Cache\ExchangeRates.json'
    
    # Cache for up to 2 hours
    $timespan = New-TimeSpan -Hour 2 
    
    $ExchangeRates = @{}
    if(Test-Path $filename) {
        $ExchangeRateData = Get-Content $filename | ConvertFrom-Json
        # ConvertFrom-Json gives a PSObject, this turns it back into a hashtable. https://stackoverflow.com/questions/3740128/pscustomobject-to-hashtable
        $ExchangeRateData.psobject.properties | Foreach {$ExchangeRates[$_.Name] = $_.Value}
    }

    # Try to return a cached exchange rate
    if($ExchangeRates[$altcoin].LastUpdated -and ((Get-Date) - $ExchangeRates[$altcoin].LastUpdated) -lt $timespan) {
        Return $amount * $ExchangeRates[$altcoin].rate
    }

    # Find the market for the coin
    $markets = Get-BittrexMarkets | Where-Object {$_.MarketCurrencyLong -eq $altcoin}
    if($markets.count -eq 0) {
        Write-Log -Level Info "No market found for $altcoin, unable to get exchange rate"
        Return 0
    }

    # Get the exchange rate
    Write-Log "Updating exchange rate for $altcoin"
    try {
        $Request = Invoke-RestMethod "https://bittrex.com/api/v1.1/public/getticker?market=$($markets[0].MarketName)" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    } catch {
        Write-Log -Level Warn "Bittrex exchange API has failed."
        Return 0
    }
    
    # Write the exchange rate to the cache
    $ExchangeRates[$altcoin] = @{'rate' = $Request.result.Last; 'lastupdated' = (Get-Date).ToUniversalTime()}
    $ExchangeRates | ConvertTo-Json | Set-Content $filename

    Return $ExchangeRates[$altcoin].rate * $amount
}


function Get-Balances {
    [CmdletBinding()]
    param(
        [String]$Wallet,
        [String]$API_Key, # for miningpoolhub
        $Rates
    )
    Write-Log 'Getting balances...'
    $balances = Get-ChildItemContent Balances -Parameters @{Wallet = $Wallet; API_Key = $API_Key}
    
    # Add the local currency rates if available
    if($Rates) {
        $balances | Where-Object {
            if($_.Content.currency -eq 'BTC') {
                ForEach($Rate in ($Rates.PSObject.Properties)) {
                    $_.Content | Add-Member "Total_$($Rate.Name)" ([Double]$Rate.Value * $_.Content.total)
                }
            } else {
                # Try to get exchange rate to BTC
                $btcvalue = Get-BTCValue -altcoin $_.Content.currency -amount $_.Content.total
                ForEach($Rate in ($Rates.PSObject.Properties)) {
                    $_.Content | Add-Member "Total_$($Rate.Name)" ([Double]$Rate.Value * $btcvalue)
                }
            }
        }
    }

    $balances
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
            Write-Log -Level Warn "Stat file ($Name) was not updated because the value ($([Decimal]$Value)) is outside fault tolerance ($([Int]$ToleranceMin) ... $([Int]$ToleranceMax)). "
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
        if (Test-Path $Path) {Write-Log -Level Warn "Stat file ($Name) is corrupt and will be reset. "}

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

    Get-ChildItem $Path | ForEach-Object {
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
            [PSCustomObject]@{Name = $Name; Content = $_}
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
    # To get same numbering scheme reagardless of value BTC value (size) to dermine formatting
    # Use $Offset to add/remove decimal places

    param(
        [Parameter(Mandatory = $true)]
        [Double]$Number, 
        [Parameter(Mandatory = $true)]
        [Double]$BTCRate,
        [Parameter(Mandatory = $false)]
        [Int]$Offset        
    )

    $Number = $Number * $BTCRate
    
    switch ([math]::truncate([math]::log($BTCRate, [Math]::Pow(10, 1))) -2 + $Offset) {
        default {$Number.ToString("N0")}
        0 {$Number.ToString("N5")}
        1 {$Number.ToString("N4")}
        2 {$Number.ToString("N3")}
        3 {$Number.ToString("N2")}
        4 {$Number.ToString("N1")}
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
        [Int]$Priority = 0
    )

    $PriorityNames = [PSCustomObject]@{-2 = "Idle"; -1 = "BelowNormal"; 0 = "Normal"; 1 = "AboveNormal"; 2 = "High"; 3 = "RealTime"}

    $Job = Start-Job -ArgumentList $PID, (Resolve-Path ".\CreateProcess.cs"), $FilePath, $ArgumentList, $WorkingDirectory {
        param($ControllerProcessID, $CreateProcessPath, $FilePath, $ArgumentList, $WorkingDirectory)

        $ControllerProcess = Get-Process -Id $ControllerProcessID
        if ($ControllerProcess -eq $null) {return}

        #CreateProcess won't be usable inside this job if Add-Type is run outside the job
        Add-Type -Path $CreateProcessPath
		
        $lpApplicationName = $FilePath;
		
        $lpCommandLine = ""
        #$lpCommandLine = '"' + $FilePath + '"' #Windows paths cannot contain ", so there is no need to escape
        if ($ArgumentList -ne "") {$lpCommandLine += " " + $ArgumentList}
		
        $lpProcessAttributes = New-Object SECURITY_ATTRIBUTES
        $lpProcessAttributes.Length = [System.Runtime.InteropServices.Marshal]::SizeOf($lpProcessAttributes)
		
        $lpThreadAttributes = New-Object SECURITY_ATTRIBUTES
        $lpThreadAttributes.Length = [System.Runtime.InteropServices.Marshal]::SizeOf($lpThreadAttributes)
		
        $bInheritHandles = $false
		
        $dwCreationFlags = [CreationFlags]::CREATE_NEW_CONSOLE
		
        $lpEnvironment = [IntPtr]::Zero
		
        if ($WorkingDirectory -ne "") {$lpCurrentDirectory = $WorkingDirectory} else {$lpCurrentDirectory = [IntPtr]::Zero}

        $lpStartupInfo = New-Object STARTUPINFO
        $lpStartupInfo.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($lpStartupInfo)
        $lpStartupInfo.wShowWindow = [ShowWindow]::SW_SHOWMINNOACTIVE
        $lpStartupInfo.dwFlags = [STARTF]::STARTF_USESHOWWINDOW
		
        $lpProcessInformation = New-Object PROCESS_INFORMATION

        [Kernel32]::CreateProcess($lpApplicationName, $lpCommandLine, [ref] $lpProcessAttributes, [ref] $lpThreadAttributes, $bInheritHandles, $dwCreationFlags, $lpEnvironment, $lpCurrentDirectory, [ref] $lpStartupInfo, [ref] $lpProcessInformation)
        if($lpProcessInformation.dwProcessId -eq 0) {
            Write-Error "Failed to launch process $FilePath $ArgumentList"
            [PSCustomObject]@{ProcessId = $null}
            return
        }

        $Process = Get-Process -Id $lpProcessInformation.dwProcessId

        if ($Process -eq $null -or $Process -eq 0) {
			Write-Error "Did not get a process handle when starting miner"
			Write-Error "Trying to find process " $lpProcessInformation.dwProcessId
            [PSCustomObject]@{ProcessId = $null}
            return        
        }

        [PSCustomObject]@{ProcessId = $Process.Id; ProcessHandle = $Process.Handle}

        $ControllerProcess.Handle | Out-Null
        $Process.Handle | Out-Null

        do {if ($ControllerProcess.WaitForExit(1000)) {$Process.CloseMainWindow() | Out-Null}}
        while ($Process.HasExited -eq $false)
    }

    do {Start-Sleep 5; $JobOutput = Receive-Job $Job}
    while ($JobOutput -eq $null)

    $Process = Get-Process | Where-Object Id -EQ $JobOutput.ProcessId
    $Process.Handle | Out-Null
    $Process

    if ($Process) {$Process.PriorityClass = $PriorityNames.$Priority}
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

    StartMining() {
        $this.New = $true
        $this.Activated++
        if ($this.Process -ne $null) {$this.Active += $this.Process.ExitTime - $this.Process.StartTime}
        $this.Process = Start-SubProcess -FilePath $this.Path -ArgumentList $this.Arguments -WorkingDirectory (Split-Path $this.Path) -Priority ($this.Type | ForEach-Object {if ($this -eq "CPU") {-2}else {-1}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum)
        if ($this.Process -eq $null) {
            $this.Status = "Failed"
            Write-Log -Level Warning "$($this.Type) miner $($this.Name) failed to start."
        } else {
            $this.Status = "Running"
            Write-Log "$($this.Type) miner $($this.Name) started with PID $($this.Process.Id)"
        }
    }

    StopMining() {
        $this.Process.CloseMainWindow() | Out-Null
        # Wait up to 10 seconds for the miner to close gracefully
        $closedgracefully = $this.Process.WaitForExit(10000)
        if($closedgracefully) { 
            Write-Log "$($this.Type) miner $($this.Name) closed gracefully" 
        } else {
            Write-Log -Level Error "$($this.Type) miner $($this.Name) failed to close within 10 seconds"
            if(!$this.Process.HasExited) {
                Write-Log -Level Error "Attempting to kill $($this.Type) miner $($this.Name) PID $($this.Process.Id)"
                $this.Process.Kill()
            }
        }
        $this.Status = "Idle"
    }
}
