param(
    [Parameter(Mandatory=$false)]
    [String]$Wallet, 
    [Parameter(Mandatory=$true)]
    [String]$UserName, 
    [Parameter(Mandatory=$false)]
    [String]$WorkerName = "multipoolminer", 
    [Parameter(Mandatory=$false)]
    [Int]$API_ID = 0, 
    [Parameter(Mandatory=$false)]
    [String]$API_Key = "", 
    [Parameter(Mandatory=$false)]
    [Int]$Interval = 60, #seconds
    [Parameter(Mandatory=$false)]
    [String]$Location = "europe", #europe/us/asia
    [Parameter(Mandatory=$false)]
    [Switch]$SSL = $false, 
    [Parameter(Mandatory=$false)]
    [Array]$Type = $null #AMD/NVIDIA/CPU
)

Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)

. .\Include.ps1

$Delta = 0.05 #decimal percentage

$ActiveMinerPrograms = @()

#Start the log
Start-Transcript ".\Logs\$(Get-Date -Format "yyyy-MM-dd_hh-mm-ss").txt"

while($true)
{
    #Load the Stats
    $Stats = [PSCustomObject]@{}
    if(Test-Path "Stats"){Get-ChildItemContent "Stats" | ForEach {$Stats | Add-Member $_.Name $_.Content}}

    #Load information about the Pools
    $AllPools = if(Test-Path "Pools"){Get-ChildItemContent "Pools" | ForEach {$_.Content | Add-Member @{Name = $_.Name} -PassThru} | Where Location -EQ $Location | Where SSL -EQ $SSL}
    if($AllPools.Count -eq 0){"No Pools!" | Out-Host; continue}
    $Pools = [PSCustomObject]@{}
    $AllPools.Algorithm | Select -Unique | ForEach {$Pools | Add-Member $_ ($AllPools | Where Algorithm -EQ $_ | Sort Price -Descending | Select -First 1)}
    
    #Load information about the Miners
    #Messy...?
    $Miners = if(Test-Path "Miners"){Get-ChildItemContent "Miners" | ForEach {$_.Content | Add-Member @{Name = $_.Name} -PassThru} | Where {$Type.Count -eq 0 -or (Compare $Type $_.Type -IncludeEqual -ExcludeDifferent | Measure).Count -gt 0}}
    if($Miners.Count -eq 0){"No Miners!" | Out-Host; continue}
    $Miners | ForEach {
        $Miner = $_

        $Miner_HashRates = [PSCustomObject]@{}
        $Miner_Pools = [PSCustomObject]@{}
        $Miner_Profits = [PSCustomObject]@{}

        $Miner.HashRates.PSObject.Properties.Name | ForEach {
            $Miner_HashRates | Add-Member $_ ([Decimal]$Miner.HashRates.$_)
            $Miner_Pools | Add-Member $_ ([PSCustomObject]$Pools.$_)
            $Miner_Profits | Add-Member $_ ([Decimal]$Miner.HashRates.$_*$Pools.$_.Price)
        }

        $Miner_Profit = [Decimal]($Miner_Profits.PSObject.Properties.Value | Measure -Sum).Sum
        
        $Miner.HashRates.PSObject.Properties | Where Value -EQ "" | Select -ExpandProperty Name | ForEach {
            $Miner_HashRates.$_ = $null
            $Miner_Profits.$_ = $null
            $Miner_Profit = $null
        }
        
        $Miner.HashRates = $Miner_HashRates
        $Miner | Add-Member Pools $Miner_Pools
        $Miner | Add-Member Profits $Miner_Profits
        $Miner | Add-Member Profit $Miner_Profit
        $Miner.Path = Convert-Path $Miner.Path
    }
    
    #Display mining information
    Clear-Host
    $Miners | Where {$_.Profit -ge 1E-5 -or $_.Profit -eq $null} | Sort -Descending Type,Profit | Format-Table -GroupBy Type (
        @{Label = "Miner"; Expression={$_.Name}}, 
        @{Label = "Algorithm"; Expression={$_.HashRates.PSObject.Properties.Name}}, 
        @{Label = "Speed"; Expression={$_.HashRates.PSObject.Properties.Value | ForEach {if($_ -ne $null){"$($_ | ConvertTo-Hash)/s"}else{"Benchmarking"}}}; Align='right'}, 
        @{Label = "BTC/Day"; Expression={$_.Profits.PSObject.Properties.Value | ForEach {if($_ -ne $null){$_.ToString("N5")}else{"Benchmarking"}}}; Align='right'}, 
        @{Label = "BTC/GH/Day"; Expression={$_.Pools.PSObject.Properties.Value.Price | ForEach {($_*1000000000).ToString("N5")}}; Align='right'}, 
        @{Label = "Pool"; Expression={$_.Pools.PSObject.Properties.Value.Name}}
    ) | Out-Host

    #Apply delta to miners to avoid needless switching
    $ActiveMinerPrograms | ForEach {$Miners | Where Path -EQ $_.Path | Where Arguments -EQ $_.Arguments | ForEach {$_.Profit *= 1+$Delta}}

    #Get most profitable miner combination i.e. AMD+NVIDIA+CPU
    $BestMiners = $Miners | Select Type -Unique | ForEach {$Miner_Type = $_.Type; ($Miners | Where {(Compare $Miner_Type $_.Type | Measure).Count -eq 0} | Sort -Descending {($_ | Where Profit -EQ $null | Measure).Count},{($_ | Measure Profit -Sum).Sum},{($_ | Where Profit -NE 0 | Measure).Count} | Select -First 1)}
    $MinerCombos = [System.Collections.ArrayList]@()
    for($i = 0; $i -lt $BestMiners.Count; $i++)
    {
        $MinerCombo = @()
        for($x = 0; $x -lt $BestMiners.Count; $x++){
            $MinerCombo += $BestMiners[(($x+$i)%$BestMiners.Count)]
            if($MinerCombo.Type.Count -eq ($MinerCombo.Type | Select -Unique).Count)
            {
                $MinerCombos.Add($MinerCombo.Clone()) | Out-Null
            }
        }
    }
    $BestMinerCombo = $MinerCombos | Sort -Descending {($_ | Where Profit -EQ $null | Measure).Count},{($_ | Measure Profit -Sum).Sum},{($_ | Where Profit -NE 0 | Measure).Count} | Select -First 1

    #Stop or start existing active miners depending on if they are the most profitable
    $ActiveMinerPrograms | ForEach {
        if(($BestMinerCombo | Where Path -EQ $_.Path | Where Arguments -EQ $_.Arguments).Count -eq 0)
        {
            if(-not $_.Process.HasExited)
            {
                Stop-Process $_.Process
                $_.Status = "Idle"
            }
        }
        else
        {
            if($_.Process.HasExited)
            {
                $_.New = $true
                $_.Active += $_.Process.ExitTime-$_.Process.StartTime
                $_.Activated += 1
                if($_.Process.Start())
                {
                    $_.Status = "Running"
                }
                else
                {
                    $_.Status = "Failed"
                }
            }
        }
    }

    #Start the most profitable miners that are not already active
    $BestMinerCombo | ForEach {
        if(($ActiveMinerPrograms | Where Path -EQ $_.Path | Where Arguments -EQ $_.Arguments).Count -eq 0)
        {
            $ActiveMinerPrograms += [PSCustomObject]@{
                Name = $_.Name
                Path = $_.Path
                Arguments = $_.Arguments
                Process = Start-Process $_.Path $_.Arguments -WorkingDirectory (Split-Path $_.Path) -PassThru
                API = $_.API
                Algorithms = $_.HashRates.PSObject.Properties.Name
                New = $true
                Active = [TimeSpan]0
                Activated = 1
                Status = "Running"
                HashRate = 0
            }
        }
    }
    
    #Display active miners
    $ActiveMinerPrograms | Sort -Descending Status,Active | Select -First 10 | Format-Table -Wrap -GroupBy Status (
        @{Label = "Speed"; Expression={$_.HashRate | ForEach {"$($_ | ConvertTo-Hash)/s"}}; Align='right'}, 
        @{Label = "Active"; Expression={if($_.Process.ExitTime -gt $_.Process.StartTime){($_.Active+($_.Process.ExitTime-$_.Process.StartTime)).ToString("hh\:mm")}else{($_.Active+((Get-Date)-$_.Process.StartTime)).ToString("hh\:mm")}}}, 
        @{Label = "Activated"; Expression={"$($_.Activated) Time(s)"}}, 
        @{Label = "Command"; Expression={"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
    ) | Out-Host
    
    #Do nothing for a few seconds as to not overload the APIs
    Sleep $Interval

    #Save current hash rates
    $ActiveMinerPrograms | ForEach {
        $Miner_HashRates = $null
        $_.HashRate = 0
        $New = $false
        
        if($_.Process.HasExited)
        {
            $_.Status = "Failed"

            for($i = [Math]::Min($_.Algorithms.Count, $Miner_HashRates.Count); $i -lt $_.Algorithms.Count; $i++)
            {
                if((Get-Stat "$($_.Name)_$($_.Algorithms | Select -Index $i)_HashRate") -eq $null)
                {
                    $Stat = Set-Stat -Name "$($_.Name)_$($_.Algorithms | Select -Index $i)_HashRate" -Value 0
                }
            }
        }
        else
        {
            $Miner_HashRates = Get-HashRate $_.API
        }

        if($Miner_HashRates -ne $null)
        {
            $_.HashRate = $Miner_HashRates | Select -First $_.Algorithms.Count

            $Miner_HashRates_Check = $Miner_HashRates
            if($_.New)
            {
                sleep 10
                $Miner_HashRates_Check = Get-HashRate $_.API
            }
            
            for($i = 0; $i -lt [Math]::Min($_.Algorithms.Count, $Miner_HashRates.Count); $i++)
            {
                if([Math]::Abs(($Miner_HashRates | Select -Index $i)-($Miner_HashRates_Check | Select -Index $i)) -le ($Miner_HashRates | Select -Index $i)*$Delta)
                {
                    $Stat = Set-Stat -Name "$($_.Name)_$($_.Algorithms | Select -Index $i)_HashRate" -Value ((($Miner_HashRates | Select -Index $i),($Miner_HashRates_Check | Select -Index $i) | Measure -Maximum).Maximum)
                }
                else
                {
                    $New = $true
                }
            }

            $_.New = $New
        }
    }
}

#Stop the log
Stop-Transcript