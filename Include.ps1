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
    $SmallestValue = 1E-20

    if(Test-Path $Path)
    {
        $Stat = Get-Content $Path | ConvertFrom-Json
        $Stat = [PSCustomObject]@{
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
            Updated = [DateTime]$Stat.Updated
        }
    }
    else
    {
        $Stat = [PSCustomObject]@{
            Live = $Value
            Minute = $Value
            Minute_Fluctuation = 0.5
            Minute_5 = $Value
            Minute_5_Fluctuation = 0.5
            Minute_10 = $Value
            Minute_10_Fluctuation = 0.5
            Hour = $Value
            Hour_Fluctuation = 0.5
            Day = $Value
            Day_Fluctuation = 0.5
            Week = $Value
            Week_Fluctuation = 0.5
            Updated = $Date
        }
    }
    
    $Span_Minute = [Math]::Min(($Date-$Stat.Updated).TotalMinutes,1)
    $Span_Minute_5 = [Math]::Min((($Date-$Stat.Updated).TotalMinutes/5),1)
    $Span_Minute_10 = [Math]::Min((($Date-$Stat.Updated).TotalMinutes/10),1)
    $Span_Hour = [Math]::Min(($Date-$Stat.Updated).TotalHours,1)
    $Span_Day = [Math]::Min(($Date-$Stat.Updated).TotalDays,1)
    $Span_Week = [Math]::Min((($Date-$Stat.Updated).TotalDays/7),1)

    $Stat = [PSCustomObject]@{
        Live = $Value
        Minute = ((1-$Span_Minute)*$Stat.Minute)+($Span_Minute*$Value)
        Minute_Fluctuation = ((1-$Span_Minute)*$Stat.Minute_Fluctuation)+
            ($Span_Minute*([Math]::Abs($Value-$Stat.Minute)/[Math]::Max([Math]::Abs($Stat.Minute),$SmallestValue)))
        Minute_5 = ((1-$Span_Minute_5)*$Stat.Minute_5)+($Span_Minute_5*$Value)
        Minute_5_Fluctuation = ((1-$Span_Minute_5)*$Stat.Minute_5_Fluctuation)+
            ($Span_Minute_5*([Math]::Abs($Value-$Stat.Minute_5)/[Math]::Max([Math]::Abs($Stat.Minute_5),$SmallestValue)))
        Minute_10 = ((1-$Span_Minute_10)*$Stat.Minute_10)+($Span_Minute_10*$Value)
        Minute_10_Fluctuation = ((1-$Span_Minute_10)*$Stat.Minute_10_Fluctuation)+
            ($Span_Minute_10*([Math]::Abs($Value-$Stat.Minute_10)/[Math]::Max([Math]::Abs($Stat.Minute_10),$SmallestValue)))
        Hour = ((1-$Span_Hour)*$Stat.Hour)+($Span_Hour*$Value)
        Hour_Fluctuation = ((1-$Span_Hour)*$Stat.Hour_Fluctuation)+
            ($Span_Hour*([Math]::Abs($Value-$Stat.Hour)/[Math]::Max([Math]::Abs($Stat.Hour),$SmallestValue)))
        Day = ((1-$Span_Day)*$Stat.Day)+($Span_Day*$Value)
        Day_Fluctuation = ((1-$Span_Day)*$Stat.Day_Fluctuation)+
            ($Span_Day*([Math]::Abs($Value-$Stat.Day)/[Math]::Max([Math]::Abs($Stat.Day),$SmallestValue)))
        Week = ((1-$Span_Week)*$Stat.Week)+($Span_Week*$Value)
        Week_Fluctuation = ((1-$Span_Week)*$Stat.Week_Fluctuation)+
            ($Span_Week*([Math]::Abs($Value-$Stat.Week)/[Math]::Max([Math]::Abs($Stat.Week),$SmallestValue)))
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
        $API, 
        [Parameter(Mandatory=$true)]
        $Port
    )
    
    $Server = "localhost"

    $Multiplier = 1000

    switch($API)
    {
        "xgminer"
        {
            $Message = @{command="summary"; parameter=""} | ConvertTo-Json

            $Client = New-Object System.Net.Sockets.TcpClient $server, $port
            $Stream = $Client.GetStream()

            $Writer = New-Object System.IO.StreamWriter $Stream
            $Writer.Write($Message)
            $Writer.Flush()

            $Reader = New-Object System.IO.StreamReader $Stream

            $Request = $Reader.ReadToEnd()
            $Data = ($Request.Substring($Request.IndexOf("{"),$Request.LastIndexOf("}")-$Request.IndexOf("{")+1) | ConvertFrom-Json).SUMMARY
            if($Data[0].'MHS 5s' -ne $null){[Decimal]$Data[0].'MHS 5s'*$Multiplier*$Multiplier}
            elseif($Data[0].'KHS 5s' -ne $null){[Decimal]$Data[0].'KHS 5s'*$Multiplier}
        }
        "ccminer"
        {
            $Message = "summary"

            $Client = New-Object System.Net.Sockets.TcpClient $server, $port
            $Stream = $Client.GetStream()

            $Writer = New-Object System.IO.StreamWriter $Stream
            $Writer.Write($Message)
            $Writer.Flush()

            $Reader = New-Object System.IO.StreamReader $Stream

            $Request = $Reader.ReadToEnd()
            $Data = $Request -split "[;=]"
            if($Data[13] -ne 0)
            {
                [Decimal]$Data[11]*$Multiplier
            }
        }
        "claymore"
        {
            $Request = Invoke-WebRequest "http://$($Server):$Port" -UseBasicParsing
            $Data = ($Request.Content.Substring($Request.Content.IndexOf("{"),$Request.Content.LastIndexOf("}")-$Request.Content.IndexOf("{")+1) | ConvertFrom-Json).result
            if($Request.Content.Contains("ETH:"))
            {
                [Decimal]$Data[2].Split(";")[0]*$Multiplier
            }
            else
            {
                [Decimal]$Data[2].Split(";")[0]
            }

            [Decimal]$Data[4].Split(";")[0]*$Multiplier
        }
        "nheqminer"
        {
            $Message = "status"

            $Client = New-Object System.Net.Sockets.TcpClient $server, $port
            $Stream = $Client.GetStream()

            $Writer = New-Object System.IO.StreamWriter $Stream
            $Writer.WriteLine($Message)
            $Writer.Flush()

            $Reader = New-Object System.IO.StreamReader $Stream
            $Request = $Reader.ReadLine()
            $Data = ($Request | ConvertFrom-Json).result
            [Decimal]$Data.speed_sps
        }
    }
}

filter ConvertTo-Hash { 
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

function Get-Permutation {
    param(
        [Parameter(Mandatory=$true)]
        [Array]$Value, 
        [Parameter(Mandatory=$false)]
        [Int]$Size = $Value.Count
    )
    for($i = 0; $i -lt $Size; $i++)
    {
        Get-Permutation $Value ($Size - 1)
        if($Size -eq 2){[PSCustomObject]@{Permutation = $Value.Clone()}}
        $z = 0
        $position = ($Value.Count - $Size)
        $temp = $Value[$position]           
        for($z=($position+1);$z -lt $Value.Count; $z++)
        {
            $Value[($z-1)] = $Value[$z]               
        }
        $Value[($z-1)] = $temp
    }
}

function Get-Combination {
    param(
        [Parameter(Mandatory=$true)]
        [Array]$Value
    )

    $Permutations = Get-Permutation ($Value | ForEach {$Value.IndexOf($_)})

    for($i = $Value.Count; $i -gt 0; $i--)
    {
        $Permutations | ForEach {[PSCustomObject]@{Combination = ($_.Permutation | Select -First $i | Sort {$_})}} | Sort Combination -Unique | ForEach {[PSCustomObject]@{Combination = ($_.Combination | ForEach {$Value.GetValue($_)})}}
    }
}
