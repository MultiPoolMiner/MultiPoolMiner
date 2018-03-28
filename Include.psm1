Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1" -ErrorAction Ignore
Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1" -ErrorAction Ignore

Set-Location (Split-Path $MyInvocation.MyCommand.Path)

Add-Type -Path .\OpenCL\*.cs

function Get-Devices {
    [CmdletBinding()]
	
    $Devices = [PSCustomObject]@{}
    $DeviceID = 0
    
    $OpenGlDevices = [OpenCl.Platform]::GetPlatformIDs() | ForEach-Object {[OpenCl.Device]::GetDeviceIDs($_, [OpenCl.DeviceType]::All)}
    $OpenGlDevices | ForEach-Object {

        $Name_Norm = (Get-Culture).TextInfo.ToTitleCase(($_.Name)) -replace "[^A-Z0-9]"

        if ($_.Type -eq "Cpu") {
            $Type = "CPU"
        }
        else {
            Switch ($_.Vendor) {
                "Advanced Micro Devices, Inc." {$Type = "AMD"}
                "Intel(R) Corporation"         {$Type = "INTEL"}
                "NVIDIA Corporation"           {$Type = "NVIDIA"}
            }
        }        

        $Device = @([PSCustomObject]$_)

        if (-not $Devices.$Type) { # New hardware platform, start counting deviceIDs from 0
            $DeviceID = 0
            $Device | Add-Member Name_Norm $Name_Norm
            $Device | Add-Member DeviceIDs @($DeviceID)
            $Devices | Add-Member $Type $Device
        }
        else {
            if ($Devices.$Type.Name_Norm -inotcontains $Name_Norm) { # New card model
                $Device | Add-Member Name_Norm $Name_Norm
                $Device | Add-Member DeviceIDs @($DeviceID)
                $Devices.$Type += $Device
            }
            else { # Existing card model
                $Devices.$Type | Where-Object {$_.Name_Norm -eq $Name_Norm} | ForEach-Object {$_.DeviceIDs += $DeviceID}
            }
        }
        $DeviceID++
    }
    $Devices
}

function Get-CommandPerDevice {
    # rewrites the command parameters
    # if a parameter has multiple values, only the values for the available devices are returned
    # parameters without values are valid for all devices an are left untouched
    # supported parameter syntax:
    #$Command = ",c=BTC -9 1  -y  2 -a 00,11,22,33,44,55  -b=00,11,22,33,44,55 --c==00,11,22,33,44,55 --d --e=00,11,22,33,44,55 -f -g 00 11 22 33 44 55 ,c=LTC  -h 00 11 22 33 44 55 -i=,11,,33,,55 --j=00,11,,,44,55 --k==00,,,33,44,55 -l -zzz=0123,1234,2345,3456,4567,5678,6789 -u 0  --p all ,something=withcomma blah *blah *blah"
    #$Devices = @(0;1;4)
    # Result: ",c=BTC -9 1  -y  2 -a 00,11,44  -b=00,11,44 --c==00,11,44 --d --e=00,11,44 -f -g 00 11 44 ,c=LTC  -h 00 11 44 -i=,11 --j=00,11,44 --k==00,,44 -l -zzz=0123,1234,4567 -u 0  --p all ,something=withcomma blah *blah *blah"
    #$Devices = @(1)
    # Result: ",c=BTC -9 1  -y  2 -a 11  -b=11 --c==11 --d --e=11 -f -g 11 ,c=LTC  -h 11 -i=11 --j=11 --k== -l -zzz=1234 -u 0  --p all ,something=withcomma blah *blah *blah"
    #$Devices = @(0;2;9)
    # Result: ",c=BTC -9 1  -y  2 -a 00,22  -b=00,22 --c==00,22 --d --e=00,22 -f -g 00 22 ,c=LTC  -h 00 22 -i= --j=00 --k==00 -l -zzz=0123,2345 -u 0  --p all ,something=withcomma blah *blah *blah"

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

Function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)][ValidateNotNullOrEmpty()][Alias("LogContent")][string]$Message,
        [Parameter(Mandatory = $false)][ValidateSet("Error", "Warn", "Info", "Verbose", "Debug")][string]$Level = "Info"
    )

    Begin { }
    Process {
        $filename = ".\Logs\MultiPoolMiner-$(Get-Date -Format "yyyy-MM-dd").txt"
        $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        if (-not (Test-Path "Stats")) {New-Item "Stats" -ItemType "directory" | Out-Null}

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
        "$date $LevelText $Message" | Out-File -FilePath $filename -Append
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

    function Invoke-ExpressionRecursive ($Expression) {
        if ($Expression -is [String]) {
            if ((Invoke-Expression "`"$Expression`"") -ne $Expression) {
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

    Get-ChildItem $Path | ForEach-Object {
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
    switch ([math]::truncate(10 - $Offset - [math]::log($BTCRate, [Math]::Pow(10, 1)))) {
        0 {$Number.ToString("N0")}
        1 {$Number.ToString("N1")}
        2 {$Number.ToString("N2")}
        3 {$Number.ToString("N3")}
        4 {$Number.ToString("N4")}
        5 {$Number.ToString("N5")}
        6 {$Number.ToString("N6")}
        7 {$Number.ToString("N7")}
        8 {$Number.ToString("N8")}
        Default {$Number.ToString("N9")}
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

    $Job = Start-Job -ArgumentList $PID, $FilePath, $ArgumentList, $WorkingDirectory {
        param($ControllerProcessID, $FilePath, $ArgumentList, $WorkingDirectory)

        $ControllerProcess = Get-Process -Id $ControllerProcessID
        if ($ControllerProcess -eq $null) {return}

        $ProcessParam = @{}
        $ProcessParam.Add("FilePath", $FilePath)
        $ProcessParam.Add("WindowStyle", 'Minimized')
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
        if ($this.Process -eq $null) {$this.Status = "Failed"}
        else {$this.Status = "Running"}
    }

    StopMining() {
        $this.Process.CloseMainWindow() | Out-Null
        $this.Status = "Idle"
    }
}
