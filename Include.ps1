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

    if(Test-Path $Path){$Stat = Get-Content $Path | ConvertFrom-Json}

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
        $Content = @()
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

function Get-HashRate {
    param(
        [Parameter(Mandatory=$true)]
        [String]$API, 
        [Parameter(Mandatory=$true)]
        [Int]$Port, 
        [Parameter(Mandatory=$false)]
        [Bool]$Safe = $false
    )
    
    $Server = "localhost"
    $Multiplier = 1000
    $Delta = 0.05
    $Interval = 5
    $HashRates = @()
    $HashRates_Dual = @()

    try
    {
        switch($API)
        {
            "xgminer"
            {
                $Message = @{command="summary"; parameter=""} | ConvertTo-Json
            
                do
                {
                    $Client = New-Object System.Net.Sockets.TcpClient $server, $port
                    $Writer = New-Object System.IO.StreamWriter $Client.GetStream()
                    $Reader = New-Object System.IO.StreamReader $Client.GetStream()
                    $Writer.AutoFlush = $true

                    $Writer.WriteLine($Message)
                    $Request = $Reader.ReadLine()

                    $Data = $Request.Substring($Request.IndexOf("{"),$Request.LastIndexOf("}")-$Request.IndexOf("{")+1) -replace " ","_" | ConvertFrom-Json

                    $HashRate = if($Data.SUMMARY.HS_5s -ne $null){[Decimal]$Data.SUMMARY.HS_5s*[Math]::Pow($Multiplier,0)}
                        elseif($Data.SUMMARY.KHS_5s -ne $null){[Decimal]$Data.SUMMARY.KHS_5s*[Math]::Pow($Multiplier,1)}
                        elseif($Data.SUMMARY.MHS_5s -ne $null){[Decimal]$Data.SUMMARY.MHS_5s*[Math]::Pow($Multiplier,2)}
                        elseif($Data.SUMMARY.GHS_5s -ne $null){[Decimal]$Data.SUMMARY.GHS_5s*[Math]::Pow($Multiplier,3)}
                        elseif($Data.SUMMARY.THS_5s -ne $null){[Decimal]$Data.SUMMARY.THS_5s*[Math]::Pow($Multiplier,4)}
                        elseif($Data.SUMMARY.PHS_5s -ne $null){[Decimal]$Data.SUMMARY.PHS_5s*[Math]::Pow($Multiplier,5)}

                    if($HashRate -eq $null){$HashRates = @(); break}

                    $HashRates += $HashRate

                    if(-not $Safe){break}

                    $HashRate = if($Data.SUMMARY.HS_av -ne $null){[Decimal]$Data.SUMMARY.HS_av*[Math]::Pow($Multiplier,0)}
                        elseif($Data.SUMMARY.KHS_av -ne $null){[Decimal]$Data.SUMMARY.KHS_av*[Math]::Pow($Multiplier,1)}
                        elseif($Data.SUMMARY.MHS_av -ne $null){[Decimal]$Data.SUMMARY.MHS_av*[Math]::Pow($Multiplier,2)}
                        elseif($Data.SUMMARY.GHS_av -ne $null){[Decimal]$Data.SUMMARY.GHS_av*[Math]::Pow($Multiplier,3)}
                        elseif($Data.SUMMARY.THS_av -ne $null){[Decimal]$Data.SUMMARY.THS_av*[Math]::Pow($Multiplier,4)}
                        elseif($Data.SUMMARY.PHS_av -ne $null){[Decimal]$Data.SUMMARY.PHS_av*[Math]::Pow($Multiplier,5)}

                    if($HashRate -eq $null){$HashRates = @(); break}

                    $HashRates += $HashRate

                    sleep $Interval
                } while($HashRates.Count -lt 6)
            }
            "ccminer"
            {
                $Message = "summary"

                do
                {
                    $Client = New-Object System.Net.Sockets.TcpClient $server, $port
                    $Writer = New-Object System.IO.StreamWriter $Client.GetStream()
                    $Reader = New-Object System.IO.StreamReader $Client.GetStream()
                    $Writer.AutoFlush = $true

                    $Writer.WriteLine($Message)
                    $Request = $Reader.ReadLine()

                    $Data = $Request -split ";" | ConvertFrom-StringData

                    $HashRate = if([Decimal]$Data.KHS -ne 0 -or [Decimal]$Data.ACC -ne 0){$Data.KHS}

                    if($HashRate -eq $null){$HashRates = @(); break}

                    $HashRates += [Decimal]$HashRate*$Multiplier

                    if(-not $Safe){break}

                    sleep $Interval
                } while($HashRates.Count -lt 6)
            }
            "nheqminer"
            {
                $Message = "status"

                $Client = New-Object System.Net.Sockets.TcpClient $server, $port
                $Writer = New-Object System.IO.StreamWriter $Client.GetStream()
                $Reader = New-Object System.IO.StreamReader $Client.GetStream()
                $Writer.AutoFlush = $true

                do
                {
                    $Writer.WriteLine($Message)
                    $Request = $Reader.ReadLine()

                    $Data = $Request | ConvertFrom-Json
                
                    $HashRate = $Data.result.speed_sps

                    if($HashRate -eq $null){$HashRates = @(); break}

                    $HashRates += [Decimal]$HashRate

                    if(-not $Safe){break}

                    sleep $Interval
                } while($HashRates.Count -lt 6)
            }
            "claymore"
            {
                do
                {
                    $Request = Invoke-WebRequest "http://$($Server):$Port" -UseBasicParsing
                    
                    $Data = $Request.Content.Substring($Request.Content.IndexOf("{"),$Request.Content.LastIndexOf("}")-$Request.Content.IndexOf("{")+1) | ConvertFrom-Json
                    
                    $HashRate = $Data.result[2].Split(";")[0]
                    $HashRate_Dual = $Data.result[4].Split(";")[0]

                    if($HashRate -eq $null -or $HashRate_Dual -eq $null){$HashRates = @(); $HashRate_Dual = @(); break}

                    if($Request.Content.Contains("ETH:")){$HashRates += [Decimal]$HashRate*$Multiplier; $HashRates_Dual += [Decimal]$HashRate_Dual*$Multiplier}
                    else{$HashRates += [Decimal]$HashRate; $HashRates_Dual += [Decimal]$HashRate_Dual}

                    if(-not $Safe){break}

                    sleep $Interval
                } while($HashRates.Count -lt 6)
            }
            "FireIce"
            {
                do
                {
                    $Request = Invoke-WebRequest "http://$($Server):$Port/h" -UseBasicParsing
                    
                    $Data = (((([System.Text.Encoding]::ASCII.GetString($Request.Content)) -split "`n") -match 'Total:*') -split " ")[3,4,5,6]
                    
                    $HashRate = $Data[0]
                    if($HashRate -eq "(na)"){$HashRate = $Data[1]}
                    if($HashRate -eq "(na)"){$HashRate = $Data[2]}

                    if($HashRate -eq $null){$HashRates = @(); break}

                    $HashRates += [Decimal]$HashRate

                    if(-not $Safe){break}

                    sleep $Interval
                } while($HashRates.Count -lt 6)
            }
            "wrapper"
            {
                do
                {
                    $HashRate = Get-Content ".\Wrapper_$Port.txt"
                
                    if($HashRate -eq $null){sleep $Interval; $HashRate = Get-Content ".\Wrapper_$Port.txt"}

                    if($HashRate -eq $null){$HashRates = @(); break}

                    $HashRates += [Decimal]$HashRate

                    if(-not $Safe){break}

                    sleep $Interval
                } while($HashRates.Count -lt 6)
            }
        }

        $HashRates_Info = $HashRates | Measure -Maximum -Minimum -Average
        if($HashRates_Info.Maximum-$HashRates_Info.Minimum -le $HashRates_Info.Average*$Delta){$HashRates_Info.Maximum}

        $HashRates_Info_Dual = $HashRates_Dual | Measure -Maximum -Minimum -Average
        if($HashRates_Info_Dual.Maximum-$HashRates_Info_Dual.Minimum -le $HashRates_Info_Dual.Average*$Delta){$HashRates_Info_Dual.Maximum}
    }
    catch
    {
    }
}

filter ConvertTo-Hash { 
    $Hash = $_
    switch([math]::truncate([math]::log($Hash,[Math]::Pow(1000,1))))
    {
        0 {"{0:n2}  H" -f ($Hash / [Math]::Pow(1000,0))}
        1 {"{0:n2} KH" -f ($Hash / [Math]::Pow(1000,1))}
        2 {"{0:n2} MH" -f ($Hash / [Math]::Pow(1000,2))}
        3 {"{0:n2} GH" -f ($Hash / [Math]::Pow(1000,3))}
        4 {"{0:n2} TH" -f ($Hash / [Math]::Pow(1000,4))}
        Default {"{0:n2} PH" -f ($Hash / [Math]::Pow(1000,5))}
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
        if($Size -eq 1){[PSCustomObject]@{Permutation = $Value.Clone()}}
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

function Start-SubProcess {
    param(
        [Parameter(Mandatory=$true)]
        [String]$FilePath, 
        [Parameter(Mandatory=$false)]
        [String]$ArgumentList = "", 
        [Parameter(Mandatory=$false)]
        [String]$WorkingDirectory = ""
    )

    $Job = Start-Job -ArgumentList $PID, $FilePath, $ArgumentList, $WorkingDirectory {
        param($ControllerProcessID, $FilePath, $ArgumentList, $WorkingDirectory)

        $ControllerProcess = Get-Process -Id $ControllerProcessID
        if($ControllerProcess -eq $null){return}

        $ProcessParam = @{}
        $ProcessParam.Add("FilePath", $FilePath)
        if($ArgumentList -ne ""){$ProcessParam.Add("ArgumentList", $ArgumentList)}
        if($WorkingDirectory -ne ""){$ProcessParam.Add("WorkingDirectory", $WorkingDirectory)}
        $Process = Start-Process @ProcessParam -PassThru
        if($Process -eq $null){[PSCustomObject]@{ProcessId = $null}; return}

        [PSCustomObject]@{ProcessId = $Process.Id; ProcessHandle = $Process.Handle}
        
        $ControllerProcess.Handle | Out-Null
        $Process.Handle | Out-Null

        do{if($ControllerProcess.WaitForExit(1000)){$Process.CloseMainWindow() | Out-Null}}
        while($Process.HasExited -eq $false)
    }

    do{sleep 1; $JobOutput = Receive-Job $Job}
    while($JobOutput -eq $null)

    $Process = Get-Process | Where Id -EQ $JobOutput.ProcessId
    $Process.Handle | Out-Null
    $Process
}

function Expand-WebRequest {
    param(
        [Parameter(Mandatory=$true)]
        [String]$Uri, 
        [Parameter(Mandatory=$true)]
        [String]$Path
    )
    $FolderName_Old = ([IO.FileInfo](Split-Path $Uri -Leaf)).BaseName
    $FolderName_New = Split-Path $Path -Leaf
    $FileName = "$FolderName_New$(([IO.FileInfo](Split-Path $Uri -Leaf)).Extension)"

    if(Test-Path $FileName){Remove-Item $FileName}
    if(Test-Path "$(Split-Path $Path)\$FolderName_New"){Remove-Item "$(Split-Path $Path)\$FolderName_New" -Recurse}
    if(Test-Path "$(Split-Path $Path)\$FolderName_Old"){Remove-Item "$(Split-Path $Path)\$FolderName_Old" -Recurse}

    Invoke-WebRequest $Uri -OutFile $FileName -UseBasicParsing
    Start-Process "7z" "x $FileName -o$(Split-Path $Path)\$FolderName_Old -y -spe" -Wait
    Rename-Item "$(Split-Path $Path)\$FolderName_Old" "$FolderName_New"
}