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
        $Stat = Get-Content $Path -ErrorAction Stop | ConvertFrom-Json
        $Stat = [PSCustomObject]@{
            Live = [decimal]$Stat.Live
            Minute = [decimal]$Stat.Minute
            Minute_Fluctuation = [decimal]$Stat.Minute_Fluctuation
            Minute_5 = [decimal]$Stat.Minute_5
            Minute_5_Fluctuation = [decimal]$Stat.Minute_5_Fluctuation
            Minute_10 = [decimal]$Stat.Minute_10
            Minute_10_Fluctuation = [decimal]$Stat.Minute_10_Fluctuation
            Hour = [decimal]$Stat.Hour
            Hour_Fluctuation = [decimal]$Stat.Hour_Fluctuation
            Day = [decimal]$Stat.Day
            Day_Fluctuation = [decimal]$Stat.Day_Fluctuation
            Week = [decimal]$Stat.Week
            Week_Fluctuation = [decimal]$Stat.Week_Fluctuation
            Updated = [DateTime]0 
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

    if($Value -is [ValueType])
    {
        $Stat = [PSCustomObject]@{
            Live = $Value
            Minute = ((1-[math]::Min(($Date-$Stat.Updated).TotalMinutes,1))*$Stat.Minute)+([math]::Min(($Date-$Stat.Updated).TotalMinutes,1)*$Value)
            Minute_Fluctuation = ((1-[math]::Min(($Date-$Stat.Updated).TotalMinutes,1))*$Stat.Minute_Fluctuation)+([math]::Min(($Date-$Stat.Updated).TotalMinutes,1)*([math]::Abs($Value-$Stat.Minute)/[math]::Max([math]::Abs($Stat.Minute),$SmallestValue)))
            Minute_5 = ((1-[math]::Min((($Date-$Stat.Updated).TotalMinutes/5),1))*$Stat.Minute_5)+([math]::Min((($Date-$Stat.Updated).TotalMinutes/5),1)*$Value)
            Minute_5_Fluctuation = ((1-[math]::Min((($Date-$Stat.Updated).TotalMinutes/5),1))*$Stat.Minute_5_Fluctuation)+([math]::Min((($Date-$Stat.Updated).TotalMinutes/5),1)*([math]::Abs($Value-$Stat.Minute_5)/[math]::Max([math]::Abs($Stat.Minute_5),$SmallestValue)))
            Minute_10 = ((1-[math]::Min((($Date-$Stat.Updated).TotalMinutes/10),1))*$Stat.Minute_10)+([math]::Min((($Date-$Stat.Updated).TotalMinutes/10),1)*$Value)
            Minute_10_Fluctuation = ((1-[math]::Min((($Date-$Stat.Updated).TotalMinutes/10),1))*$Stat.Minute_10_Fluctuation)+([math]::Min((($Date-$Stat.Updated).TotalMinutes/10),1)*([math]::Abs($Value-$Stat.Minute_10)/[math]::Max([math]::Abs($Stat.Minute_10),$SmallestValue)))
            Hour = ((1-[math]::Min(($Date-$Stat.Updated).TotalHours,1))*$Stat.Hour)+([math]::Min(($Date-$Stat.Updated).TotalHours,1)*$Value)
            Hour_Fluctuation = ((1-[math]::Min(($Date-$Stat.Updated).TotalHours,1))*$Stat.Hour_Fluctuation)+([math]::Min(($Date-$Stat.Updated).TotalHours,1)*([math]::Abs($Value-$Stat.Hour)/[math]::Max([math]::Abs($Stat.Hour),$SmallestValue)))
            Day = ((1-[math]::Min(($Date-$Stat.Updated).TotalDays,1))*$Stat.Day)+([math]::Min(($Date-$Stat.Updated).TotalDays,1)*$Value)
            Day_Fluctuation = ((1-[math]::Min(($Date-$Stat.Updated).TotalDays,1))*$Stat.Day_Fluctuation)+([math]::Min(($Date-$Stat.Updated).TotalDays,1)*([math]::Abs($Value-$Stat.Day)/[math]::Max([math]::Abs($Stat.Day),$SmallestValue)))
            Week = ((1-[math]::Min((($Date-$Stat.Updated).TotalDays/7),1))*$Stat.Week)+([math]::Min((($Date-$Stat.Updated).TotalDays/7),1)*$Value)
            Week_Fluctuation = ((1-[math]::Min((($Date-$Stat.Updated).TotalDays/7),1))*$Stat.Week_Fluctuation)+([math]::Min((($Date-$Stat.Updated).TotalDays/7),1)*([math]::Abs($Value-$Stat.Week)/[math]::Max([math]::Abs($Stat.Week),$SmallestValue)))
            Updated = $Date
        }
        
        Set-Content $Path ($Stat | ConvertTo-Json)
    }

    $Stat
}

function Get-Stat {
    param(
        [Parameter(Mandatory=$true)]
        [String]$Name
    )
    
    Get-ChildItem "Stats" | Where Extension -NE ".ps1" | Where BaseName -EQ $Name | Get-Content | ConvertFrom-Json
}

function Get-ChildItemContent {
    param(
        [Parameter(Mandatory=$false)]
        [String]$Path
    )
    
    $ChildItems =  Get-ChildItem $Path | ForEach {
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
            elseif($Item.Content.$_ -is [HashTable])
            {
                $Property = $Item.Content.$_
                $PropertyKeys = $Property.Keys.Clone()
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
    $Multiplier = 1000

    try
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

        $Request = $reader.ReadToEnd().Trim(' ')
        $Data = ($Request.Substring($Request.IndexOf("{"),$Request.LastIndexOf("}")-$Request.IndexOf("{")+1) | ConvertFrom-Json).SUMMARY
        [PSCustomObject]@([Decimal]$Data[0].'KHS 5s' * $Multiplier)
    }
    catch
    {
        try
        {
            $Request = Invoke-WebRequest "http://localhost:3333" -UseBasicParsing
            $Data = ($Request.Content.Substring($Request.Content.IndexOf("{"),$Request.Content.LastIndexOf("}")-$Request.Content.IndexOf("{")+1) | ConvertFrom-Json).result
            if($Request.Content.Contains("ZEC:")){$Multiplier = 1}
            [PSCustomObject]@(
                [Decimal]$Data[2].Split(";")[0] * $Multiplier
                [Decimal]$Data[4].Split(";")[0] * $Multiplier
            )
        }
        catch
        {
        }
    }
}