function Set-Stat {
    param(
        [Parameter(Mandatory=$true)]
        [String]$Name, 
        [Parameter(Mandatory=$true)]
        [Decimal]$Value, 
        [Parameter(Mandatory=$false)]
        [DateTime]$Date = (Get-Date)
    )

    $Path = "Stats\$Name.txt"
    $Date = $Date.ToUniversalTime()
    $SmallestValue = 1E-09

    if(Test-Path $Path)
    {
        $Stat = Get-Content $Path | ConvertFrom-Json
        $Stat = [PSCustomObject]@{
            Live = [Decimal]$Stat.Live
            Minute = [Decimal]$Stat.Minute
            Minute_Fluctuation = [Decimal]$Stat.Minute_Fluctuation
            Minute_5 = [Decimal]$Stat.Minute_5
            Minute_5_Fluctuation = [Decimal]$Stat.Minute_5_Fluctuation
            Minute_10 = [Decimal]$Stat.Minute_10
            Minute_10_Fluctuation = [Decimal]$Stat.Minute_10_Fluctuation
            Hour = [Decimal]$Stat.Hour
            Hour_Fluctuation = [Decimal]$Stat.Hour_Fluctuation
            Day = [Decimal]$Stat.Day
            Day_Fluctuation = [Decimal]$Stat.Day_Fluctuation
            Week = [Decimal]$Stat.Week
            Week_Fluctuation = [Decimal]$Stat.Week_Fluctuation
            Updated = [DateTime]$Stat.Updated
        }
    }
    else
    {
        $Stat = [PSCustomObject]@{
            Live = $Value
            Minute = $Value
            Minute_5 = $Value
            Minute_10 = $Value
            Hour = $Value
            Day = $Value
            Week = $Value
            Updated = [DateTime]0
        }
    }

    $Stat = [PSCustomObject]@{
        Live = $Value
        Minute = ((1-[Math]::Min(($Date-$Stat.Updated).TotalMinutes,1))*$Stat.Minute)+([Math]::Min(($Date-$Stat.Updated).TotalMinutes,1)*$Value)
        Minute_Fluctuation = ((1-[Math]::Min(($Date-$Stat.Updated).TotalMinutes,1))*$Stat.Minute_Fluctuation)+([Math]::Min(($Date-$Stat.Updated).TotalMinutes,1)*([Math]::Abs($Value-$Stat.Minute)/[Math]::Max([Math]::Abs($Stat.Minute),$SmallestValue)))
        Minute_5 = ((1-[Math]::Min((($Date-$Stat.Updated).TotalMinutes/5),1))*$Stat.Minute_5)+([Math]::Min((($Date-$Stat.Updated).TotalMinutes/5),1)*$Value)
        Minute_5_Fluctuation = ((1-[Math]::Min((($Date-$Stat.Updated).TotalMinutes/5),1))*$Stat.Minute_5_Fluctuation)+([Math]::Min((($Date-$Stat.Updated).TotalMinutes/5),1)*([Math]::Abs($Value-$Stat.Minute_5)/[Math]::Max([Math]::Abs($Stat.Minute_5),$SmallestValue)))
        Minute_10 = ((1-[Math]::Min((($Date-$Stat.Updated).TotalMinutes/10),1))*$Stat.Minute_10)+([Math]::Min((($Date-$Stat.Updated).TotalMinutes/10),1)*$Value)
        Minute_10_Fluctuation = ((1-[Math]::Min((($Date-$Stat.Updated).TotalMinutes/10),1))*$Stat.Minute_10_Fluctuation)+([Math]::Min((($Date-$Stat.Updated).TotalMinutes/10),1)*([Math]::Abs($Value-$Stat.Minute_10)/[Math]::Max([Math]::Abs($Stat.Minute_10),$SmallestValue)))
        Hour = ((1-[Math]::Min(($Date-$Stat.Updated).TotalHours,1))*$Stat.Hour)+([Math]::Min(($Date-$Stat.Updated).TotalHours,1)*$Value)
        Hour_Fluctuation = ((1-[Math]::Min(($Date-$Stat.Updated).TotalHours,1))*$Stat.Hour_Fluctuation)+([Math]::Min(($Date-$Stat.Updated).TotalHours,1)*([Math]::Abs($Value-$Stat.Hour)/[Math]::Max([Math]::Abs($Stat.Hour),$SmallestValue)))
        Day = ((1-[Math]::Min(($Date-$Stat.Updated).TotalDays,1))*$Stat.Day)+([Math]::Min(($Date-$Stat.Updated).TotalDays,1)*$Value)
        Day_Fluctuation = ((1-[Math]::Min(($Date-$Stat.Updated).TotalDays,1))*$Stat.Day_Fluctuation)+([Math]::Min(($Date-$Stat.Updated).TotalDays,1)*([Math]::Abs($Value-$Stat.Day)/[Math]::Max([Math]::Abs($Stat.Day),$SmallestValue)))
        Week = ((1-[Math]::Min((($Date-$Stat.Updated).TotalDays/7),1))*$Stat.Week)+([Math]::Min((($Date-$Stat.Updated).TotalDays/7),1)*$Value)
        Week_Fluctuation = ((1-[Math]::Min((($Date-$Stat.Updated).TotalDays/7),1))*$Stat.Week_Fluctuation)+([Math]::Min((($Date-$Stat.Updated).TotalDays/7),1)*([Math]::Abs($Value-$Stat.Week)/[Math]::Max([Math]::Abs($Stat.Week),$SmallestValue)))
        Updated = $Date
    }

    if(-not (Test-Path "Stats")){New-Item "Stats" -ItemType "directory"}
    Set-Content $Path ($Stat | ConvertTo-Json)

    $Stat
}

function Get-Stat {
    param(
        [Parameter(Mandatory=$true)]
        [String]$Name
    )
    
    if(-not (Test-Path "Stats")){New-Item "Stats" -ItemType "directory"}
    Get-ChildItem "Stats" | Where Extension -NE ".ps1" | Where BaseName -EQ $Name | Get-Content | ConvertFrom-Json
}

function Get-ChildItemContent {
    param(
        [Parameter(Mandatory=$true)]
        [String]$Path
    )

    $ChildItems = Get-ChildItem $Path | ForEach {
        $Name = $_.BaseName
        if($_.Extension -eq ".ps1")
        {
           $Content = &$_.FullName
        }
        else
        {
           $Content = $_ | Get-Content | ConvertFrom-Json
        }
        $Content | ForEach {
            [PSCustomObject]@{Name = $Name; Content = $_}
        }
    }
    
    $ChildItems | ForEach {
        $Item = $_
        $ItemKeys = $Item.Content.PSObject.Properties.Name.Clone()
        $ItemKeys | ForEach {
            if($Item.Content.$_ -is [String])
            {
                $Item.Content.$_ = Invoke-Expression "`"$($Item.Content.$_)`""
            }
            elseif($Item.Content.$_ -is [PSCustomObject])
            {
                $Property = $Item.Content.$_
                $PropertyKeys = $Property.PSObject.Properties.Name
                $PropertyKeys | ForEach {
                    if($Property.$_ -is [String])
                    {
                        $Property.$_ = Invoke-Expression "`"$($Property.$_)`""
                    }
                }
            }
        }
    }
    
    $ChildItems
}

function Get-HashRate
{
    param(
        [Parameter(Mandatory=$true)]
        $API
    )

    $Multiplier = 1000

    switch($API)
    {
        "xgminer"
        {
            $server = "localhost"
            $port = 4028
            $message = @{command="summary"; parameter=""} | ConvertTo-Json

            $client = New-Object System.Net.Sockets.TcpClient $server, $port
            $stream = $client.GetStream()

            $writer = New-Object System.IO.StreamWriter $stream
            $writer.Write($message)
            $writer.Flush()

            $reader = New-Object System.IO.StreamReader $stream

            $Request = $reader.ReadToEnd()
            $Data = ($Request.Substring($Request.IndexOf("{"),$Request.LastIndexOf("}")-$Request.IndexOf("{")+1) | ConvertFrom-Json).SUMMARY
            [Decimal]$Data[0].'KHS 5s'*$Multiplier
        }
        "ccminer"
        {
            $server = "localhost"
            $port = 4068
            $message = "summary"

            $client = New-Object System.Net.Sockets.TcpClient $server, $port
            $stream = $client.GetStream()

            $writer = New-Object System.IO.StreamWriter $stream
            $writer.Write($message)
            $writer.Flush()

            $reader = New-Object System.IO.StreamReader $stream

            $Request = $reader.ReadToEnd()
            $Data = $Request -split "[;=]"
            [Decimal]$Data[11]*$Multiplier
        }
        "cpuminer"
        {
            $server = "localhost"
            $port = 4048
            $message = "summary"

            $client = New-Object System.Net.Sockets.TcpClient $server, $port
            $stream = $client.GetStream()

            $writer = New-Object System.IO.StreamWriter $stream
            $writer.Write($message)
            $writer.Flush()

            $reader = New-Object System.IO.StreamReader $stream

            $Request = $reader.ReadToEnd()
            $Data = $Request -split "[;=]"
            [Decimal]$Data[11]*$Multiplier
        }
        "claymore"
        {
            $Request = Invoke-WebRequest "http://localhost:3333" -UseBasicParsing
            $Data = ($Request.Content.Substring($Request.Content.IndexOf("{"),$Request.Content.LastIndexOf("}")-$Request.Content.IndexOf("{")+1) | ConvertFrom-Json).result
            if($Request.Content.Contains("ZEC:"))
            {
                [Decimal]$Data[2].Split(";")[0]
            }
            else
            {
                [Decimal]$Data[2].Split(";")[0]*$Multiplier
            }

            [Decimal]$Data[4].Split(";")[0]*$Multiplier
        }
        "nheqminer_3334"
        {
            $server = "localhost"
            $port = 3334
            $message = "status"

            $client = New-Object System.Net.Sockets.TcpClient $server, $port
            $stream = $client.GetStream()

            $writer = New-Object System.IO.StreamWriter $stream
            $writer.WriteLine($message)
            $writer.Flush()

            $reader = New-Object System.IO.StreamReader $stream
            $Request = $reader.ReadLine()
            $Data = ($Request | ConvertFrom-Json).result
            [Decimal]$Data.speed_sps
        }
        "nheqminer_3335"
        {
            $server = "localhost"
            $port = 3335
            $message = "status"

            $client = New-Object System.Net.Sockets.TcpClient $server, $port
            $stream = $client.GetStream()

            $writer = New-Object System.IO.StreamWriter $stream
            $writer.WriteLine($message)
            $writer.Flush()

            $reader = New-Object System.IO.StreamReader $stream
            $Request = $reader.ReadLine()
            $Data = ($Request | ConvertFrom-Json).result
            [Decimal]$Data.speed_sps
        }
        "nheqminer_3336"
        {
            $server = "localhost"
            $port = 3336
            $message = "status"

            $client = New-Object System.Net.Sockets.TcpClient $server, $port
            $stream = $client.GetStream()

            $writer = New-Object System.IO.StreamWriter $stream
            $writer.WriteLine($message)
            $writer.Flush()

            $reader = New-Object System.IO.StreamReader $stream
            $Request = $reader.ReadLine()
            $Data = ($Request | ConvertFrom-Json).result
            [Decimal]$Data.speed_sps
        }
    }
}

Filter ConvertTo-Hash { 
    $Hash = $_
    switch ([math]::truncate([math]::log($Hash,[Math]::Pow(1000,1)))) {
        0 {"{0:n0}  H" -f ($Hash / [Math]::Pow(1000,0))}
        1 {"{0:n0} KH" -f ($Hash / [Math]::Pow(1000,1))}
        2 {"{0:n0} MH" -f ($Hash / [Math]::Pow(1000,2))}
        3 {"{0:n0} GH" -f ($Hash / [Math]::Pow(1000,3))}
        4 {"{0:n0} TH" -f ($Hash / [Math]::Pow(1000,4))}
        Default {"{0:n0} PH" -f ($Hash / [Math]::Pow(1000,5))}
    }
}