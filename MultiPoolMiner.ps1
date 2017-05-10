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
    [Array]$Type = $null, #AMD/NVIDIA/CPU
    [Parameter(Mandatory=$false)]
    [Array]$Algorithm = $null, #i.e. Ethash,Equihash,Cryptonight ect.
    [Parameter(Mandatory=$false)]
    [Array]$MinerName = $null, 
    [Parameter(Mandatory=$false)]
    [Array]$PoolName = $null, 
    [Parameter(Mandatory=$false)]
    [Array]$Currency = ("BTC","USD"), #i.e. GBP,EUR,ZEC,ETH ect.
    [Parameter(Mandatory=$false)]
    [Int]$Donate = 10 #Minutes per Day
)

Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)

Get-ChildItem . -Recurse | Unblock-File
if((Get-MpPreference).ExclusionPath -notcontains (Convert-Path .)){Start-Process powershell -Verb runAs -ArgumentList "Add-MpPreference -ExclusionPath '$(Convert-Path .)'"}

. .\Include.ps1

$DeltaMax = 0.05 #decimal percentage
$DeltaDecay = 0.01 #decimal percentage
$Delta = 0 #decimal percentage

$ActiveMinerPrograms = @()

#Start the log
Start-Transcript ".\Logs\$(Get-Date -Format "yyyy-MM-dd_hh-mm-ss").txt"

#Update stats with missing data and set to today's date/time
if(Test-Path "Stats"){Get-ChildItemContent "Stats" | ForEach {$Stat = Set-Stat $_.Name $_.Content.Week}}

#Set donation parameters
$LastDonated = (Get-Date).AddDays(-1).AddHours(1)
$WalletDonate = "1Q24z7gHPDbedkaWDTFqhMF8g7iHMehsCb"
$UserNameDonate = "aaronsace"
$WorkerNameDonate = "multipoolminer"
$WalletBackup = $Wallet
$UserNameBackup = $UserName
$WorkerNameBackup = $WorkerName

while($true)
{
    #Activate or deactivate donation
    if((Get-Date).AddDays(-1).AddMinutes($Donate) -ge $LastDonated)
    {
        $Wallet = $WalletDonate
        $UserName = $UserNameDonate
        $WorkerName = $WorkerNameDonate
    }
    if((Get-Date).AddDays(-1) -ge $LastDonated)
    {
        $Wallet = $WalletBackup
        $UserName = $UserNameBackup
        $WorkerName = $WorkerNameBackup
        $LastDonated = Get-Date
    }

    $Rates = [PSCustomObject]@{}
    $Currency | ForEach {$Rates | Add-Member $_ (Invoke-WebRequest "https://api.cryptonator.com/api/ticker/btc-$_" -UseBasicParsing | ConvertFrom-Json).ticker.price}

    #Load the Stats
    $Stats = [PSCustomObject]@{}
    if(Test-Path "Stats"){Get-ChildItemContent "Stats" | ForEach {$Stats | Add-Member $_.Name $_.Content}}

    #Load information about the Pools
    $AllPools = if(Test-Path "Pools"){Get-ChildItemContent "Pools" | ForEach {$_.Content | Add-Member @{Name = $_.Name} -PassThru} | 
        Where Location -EQ $Location | 
        Where SSL -EQ $SSL | 
        Where {$PoolName.Count -eq 0 -or (Compare $PoolName $_.Name -IncludeEqual -ExcludeDifferent | Measure).Count -gt 0}}
    if($AllPools.Count -eq 0){"No Pools!" | Out-Host; continue}
    $Pools = [PSCustomObject]@{}
    $Pools_Comparison = [PSCustomObject]@{}
    $AllPools.Algorithm | Select -Unique | ForEach {$Pools | Add-Member $_ ($AllPools | Where Algorithm -EQ $_ | Sort Price -Descending | Select -First 1)}
    $AllPools.Algorithm | Select -Unique | ForEach {$Pools_Comparison | Add-Member $_ ($AllPools | Where Algorithm -EQ $_ | Sort StablePrice -Descending | Select -First 1)}

    #Load information about the Miners
    #Messy...?
    $Miners = if(Test-Path "Miners"){Get-ChildItemContent "Miners" | ForEach {$_.Content | Add-Member @{Name = $_.Name} -PassThru} | 
        Where {$Type.Count -eq 0 -or (Compare $Type $_.Type -IncludeEqual -ExcludeDifferent | Measure).Count -gt 0} | 
        Where {$Algorithm.Count -eq 0 -or (Compare $Algorithm $_.HashRates.PSObject.Properties.Name -IncludeEqual -ExcludeDifferent | Measure).Count -gt 0} | 
        Where {$MinerName.Count -eq 0 -or (Compare $MinerName $_.Name -IncludeEqual -ExcludeDifferent | Measure).Count -gt 0}}
    if($Miners.Count -eq 0){"No Miners!" | Out-Host; continue}
    $Miners | ForEach {
        if((Test-Path $_.Path) -eq $false)
        {
            if((Split-Path $_.URI -Leaf) -eq (Split-Path $_.Path -Leaf))
            {
                New-Item (Split-Path $_.Path) -ItemType "Directory" | Out-Null
                Invoke-WebRequest $_.URI -OutFile $_.Path -UseBasicParsing
            }
            else
            {
                Expand-WebRequest $_.URI (Split-Path $_.Path)
            }
        }
    }
    $Miners | ForEach {
        $Miner = $_

        $Miner_HashRates = [PSCustomObject]@{}
        $Miner_Pools = [PSCustomObject]@{}
        $Miner_Pools_Comparison = [PSCustomObject]@{}
        $Miner_Profits = [PSCustomObject]@{}
        $Miner_Profits_Comparison = [PSCustomObject]@{}

        $Miner_Types = $Miner.Type | Select -Unique
        $Miner_Indexes = $Miner.Index | Select -Unique
        $Miner_IDs = @()

        $Miner.HashRates.PSObject.Properties.Name | ForEach {
            $Miner_HashRates | Add-Member $_ ([Decimal]$Miner.HashRates.$_)
            $Miner_Pools | Add-Member $_ ([PSCustomObject]$Pools.$_)
            $Miner_Pools_Comparison | Add-Member $_ ([PSCustomObject]$Pools_Comparison.$_)
            $Miner_Profits | Add-Member $_ ([Decimal]$Miner.HashRates.$_*$Pools.$_.Price)
            $Miner_Profits_Comparison | Add-Member $_ ([Decimal]$Miner.HashRates.$_*$Pools_Comparison.$_.Price)
        }
        
        $Miner_Profit = [Decimal]($Miner_Profits.PSObject.Properties.Value | Measure -Sum).Sum
        $Miner_Profit_Comparison = [Decimal]($Miner_Profits_Comparison.PSObject.Properties.Value | Measure -Sum).Sum
        
        $Miner.HashRates.PSObject.Properties | Where Value -EQ "" | Select -ExpandProperty Name | ForEach {
            $Miner_HashRates.$_ = $null
            $Miner_Profits.$_ = $null
            $Miner_Profits_Comparison.$_ = $null
            $Miner_Profit = $null
            $Miner_Profit_Comparison = $null
        }

        if($Miner_Types -eq $null){$Miner_Types = $Miners.Type | Select -Unique}
        if($Miner_Indexes -eq $null){$Miner_Indexes = $Miners.Index | Select -Unique}
        
        if($Miner_Types -eq $null){$Miner_Types = ""}
        if($Miner_Indexes -eq $null){$Miner_Indexes = 0}

        #$Miner_IDs = $Miner_Types | Select -Unique | ForEach {$Miner_Type = $_; $Miner_Indexes | Select -Unique | ForEach {[PSCustomObject]@{Type = $Miner_Type; Index = $_}}}
        
        $Miner.HashRates = $Miner_HashRates

        $Miner | Add-Member Pools $Miner_Pools
        $Miner | Add-Member Profits $Miner_Profits
        $Miner | Add-Member Profits_Comparison $Miner_Profits_Comparison
        $Miner | Add-Member Profit $Miner_Profit
        $Miner | Add-Member Profit_Comparison $Miner_Profit_Comparison
        $Miner | Add-Member Profit_Bias $Miner_Profit
        
        $Miner | Add-Member Type $Miner_Types -Force
        $Miner | Add-Member Index $Miner_Indexes -Force
        #$Miner | Add-Member ID $Miner_Ids -Force

        $Miner.Path = Convert-Path $Miner.Path
    }

    #Apply delta to miners to avoid needless switching
    $ActiveMinerPrograms | ForEach {$Miners | Where Path -EQ $_.Path | Where Arguments -EQ $_.Arguments | ForEach {$_.Profit_Bias *= 1+$Delta}}

    #Get most profitable miner combination i.e. AMD+NVIDIA+CPU
    $BestMiners = $Miners | Select Type,Index -Unique | ForEach {$Miner_GPU = $_; ($Miners | Where {(Compare $Miner_GPU.Type $_.Type | Measure).Count + (Compare $Miner_GPU.Index $_.Index | Measure).Count -eq 0} | Sort -Descending {($_ | Where Profit -EQ $null | Measure).Count},{($_ | Measure Profit_Bias -Sum).Sum},{($_ | Where Profit -NE 0 | Measure).Count} | Select -First 1)}
    $BestMiners_Comparison = $Miners | Select Type,Index -Unique | ForEach {$Miner_GPU = $_; ($Miners | Where {(Compare $Miner_GPU.Type $_.Type | Measure).Count + (Compare $Miner_GPU.Index $_.Index | Measure).Count -eq 0} | Sort -Descending {($_ | Where Profit -EQ $null | Measure).Count},{($_ | Measure Profit_Comparison -Sum).Sum},{($_ | Where Profit -NE 0 | Measure).Count} | Select -First 1)}
    $Miners_Type_Combos = @([PSCustomObject]@{Combination = @()}) + (Get-Combination ($Miners | Select Type -Unique) | Where{(Compare ($_.Combination | Select -ExpandProperty Type -Unique) ($_.Combination | Select -ExpandProperty Type) | Measure).Count -eq 0})
    $Miners_Index_Combos = @([PSCustomObject]@{Combination = @()}) + (Get-Combination ($Miners | Select Index -Unique) | Where{(Compare ($_.Combination | Select -ExpandProperty Index -Unique) ($_.Combination | Select -ExpandProperty Index) | Measure).Count -eq 0})
    $BestMiners_Combos = $Miners_Type_Combos | ForEach {$Miner_Type_Combo = $_.Combination; $Miners_Index_Combos | ForEach {$Miner_Index_Combo = $_.Combination; [PSCustomObject]@{Combination = $Miner_Type_Combo | ForEach {$Miner_Type_Count = $_.Type.Count; [Regex]$Miner_Type_Regex = ‘^(‘ + (($_.Type | ForEach {[Regex]::Escape($_)}) -join “|”) + ‘)$’; $Miner_Index_Combo | ForEach {$Miner_Index_Count = $_.Index.Count; [Regex]$Miner_Index_Regex = ‘^(‘ + (($_.Index | ForEach {[Regex]::Escape($_)}) –join “|”) + ‘)$’; $BestMiners | Where {([Array]$_.Type -notmatch $Miner_Type_Regex).Count -eq 0 -and ([Array]$_.Index -notmatch $Miner_Index_Regex).Count -eq 0 -and ([Array]$_.Type -match $Miner_Type_Regex).Count -eq $Miner_Type_Count -and ([Array]$_.Index -match $Miner_Index_Regex).Count -eq $Miner_Index_Count}}}}}}
    $BestMiners_Combos_Comparison = $Miners_Type_Combos | ForEach {$Miner_Type_Combo = $_.Combination; $Miners_Index_Combos | ForEach {$Miner_Index_Combo = $_.Combination; [PSCustomObject]@{Combination = $Miner_Type_Combo | ForEach {$Miner_Type_Count = $_.Type.Count; [Regex]$Miner_Type_Regex = ‘^(‘ + (($_.Type | ForEach {[Regex]::Escape($_)}) -join “|”) + ‘)$’; $Miner_Index_Combo | ForEach {$Miner_Index_Count = $_.Index.Count; [Regex]$Miner_Index_Regex = ‘^(‘ + (($_.Index | ForEach {[Regex]::Escape($_)}) –join “|”) + ‘)$’; $BestMiners_Comparison | Where {([Array]$_.Type -notmatch $Miner_Type_Regex).Count -eq 0 -and ([Array]$_.Index -notmatch $Miner_Index_Regex).Count -eq 0 -and ([Array]$_.Type -match $Miner_Type_Regex).Count -eq $Miner_Type_Count -and ([Array]$_.Index -match $Miner_Index_Regex).Count -eq $Miner_Index_Count}}}}}}
    $BestMiners_Combo = $BestMiners_Combos | Sort -Descending {($_.Combination | Where Profit -EQ $null | Measure).Count},{($_.Combination | Measure Profit_Bias -Sum).Sum},{($_.Combination | Where Profit -NE 0 | Measure).Count} | Select -First 1 | Select -ExpandProperty Combination
    $BestMiners_Combo_Comparison = $BestMiners_Combos_Comparison | Sort -Descending {($_.Combination | Where Profit -EQ $null | Measure).Count},{($_.Combination | Measure Profit_Comparison -Sum).Sum},{($_.Combination | Where Profit -NE 0 | Measure).Count} | Select -First 1 | Select -ExpandProperty Combination

    #Add the most profitable miners to the active list
    $BestMiners_Combo | ForEach {
        if(($ActiveMinerPrograms | Where Path -EQ $_.Path | Where Arguments -EQ $_.Arguments).Count -eq 0)
        {
            $ActiveMinerPrograms += [PSCustomObject]@{
                Name = $_.Name
                Path = $_.Path
                Arguments = $_.Arguments
                Wrap = $_.Wrap
                Process = $null
                API = $_.API
                Port = $_.Port
                Algorithms = $_.HashRates.PSObject.Properties.Name
                New = $false
                Active = [TimeSpan]0
                Activated = 0
                Status = "Idle"
                HashRate = 0
                Benchmarked = 0
            }
        }
    }

    #Stop or start miners in the active list depending on if they are the most profitable
    $Delta *= 1-$DeltaDecay
    $ActiveMinerPrograms | ForEach {
        if(($BestMiners_Combo | Where Path -EQ $_.Path | Where Arguments -EQ $_.Arguments).Count -eq 0)
        {
            if($_.Process -eq $null)
            {
                $_.Status = "Failed"
            }
            elseif($_.Process.HasExited -eq $false)
            {
                $_.Process.CloseMainWindow() | Out-Null
                $_.Status = "Idle"
            }
        }
        else
        {
            if($_.Process -eq $null -or $_.Process.HasExited -ne $false)
            {
                $Delta = $DeltaMax
                $_.New = $true
                $_.Activated++
                if($_.Process -ne $null){$_.Active += $_.Process.ExitTime-$_.Process.StartTime}
                if($_.Wrap){$_.Process = Start-Process -FilePath "PowerShell" -ArgumentList "-executionpolicy bypass -command . '$(Convert-Path ".\Wrapper.ps1")' -ControllerProcessID $PID -Id '$($_.Port)' -FilePath '$($_.Path)' -ArgumentList '$($_.Arguments)' -WorkingDirectory '$(Split-Path $_.Path)'" -PassThru}
                else{$_.Process = Start-SubProcess -FilePath $_.Path -ArgumentList $_.Arguments -WorkingDirectory (Split-Path $_.Path)}
                if($_.Process -eq $null){$_.Status = "Failed"}
                else{$_.Status = "Running"}
            }
        }
    }
    
    #Display mining information
    Clear-Host
    $Miners | Where {$_.Profit -ge 1E-5 -or $_.Profit -eq $null} | Sort -Descending Type,Profit | Format-Table -GroupBy Type (
        @{Label = "Miner"; Expression={$_.Name}}, 
        @{Label = "Algorithm"; Expression={$_.HashRates.PSObject.Properties.Name}}, 
        @{Label = "Speed"; Expression={$_.HashRates.PSObject.Properties.Value | ForEach {if($_ -ne $null){"$($_ | ConvertTo-Hash)/s"}else{"Benchmarking"}}}; Align='right'}, 
        @{Label = "BTC/Day"; Expression={$_.Profits.PSObject.Properties.Value | ForEach {if($_ -ne $null){$_.ToString("N5")}else{"Benchmarking"}}}; Align='right'}, 
        @{Label = "BTC/GH/Day"; Expression={$_.Pools.PSObject.Properties.Value.Price | ForEach {($_*1000000000).ToString("N5")}}; Align='right'}, 
        @{Label = "Pool"; Expression={$_.Pools.PSObject.Properties.Value | ForEach {"$($_.Name)-$($_.Info)"}}}
    ) | Out-Host
    
    #Display active miners list
    $ActiveMinerPrograms | Sort -Descending Status,{if($_.Process -eq $null){[DateTime]0}else{$_.Process.StartTime}} | Select -First (1+6+6) | Format-Table -Wrap -GroupBy Status (
        @{Label = "Speed"; Expression={$_.HashRate | ForEach {"$($_ | ConvertTo-Hash)/s"}}; Align='right'}, 
        @{Label = "Active"; Expression={"{0:dd} Days {0:hh} Hours {0:mm} Minutes" -f $(if($_.Process -eq $null){$_.Active}else{if($_.Process.ExitTime -gt $_.Process.StartTime){($_.Active+($_.Process.ExitTime-$_.Process.StartTime))}else{($_.Active+((Get-Date)-$_.Process.StartTime))}})}}, 
        @{Label = "Launched"; Expression={Switch($_.Activated){0 {"Never"} 1 {"Once"} Default {"$_ Times"}}}}, 
        @{Label = "Command"; Expression={"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
    ) | Out-Host

    #Display profit comparison
    if(($BestMiners_Combo | Where Profit -EQ $null | Measure).Count -eq 0)
    {
        $MinerComparisons = 
            [PSCustomObject]@{"Miner" = "MultiPoolMiner"}, 
            [PSCustomObject]@{"Miner" = $BestMiners_Combo_Comparison | ForEach {"$($_.Name)-$($_.HashRates.PSObject.Properties.Name -join "/")"}}
            
        $MinerComparisons_Profit = 
            (Set-Stat -Name "Profit" -Value ($BestMiners_Combo | Measure Profit -Sum).Sum).Week, 
            ($BestMiners_Combo_Comparison | Measure Profit_Comparison -Sum).Sum

        $Currency | Foreach {
            $MinerComparisons[0] | Add-Member $_ ("{0:N5}" -f ($MinerComparisons_Profit[0]*$Rates.$_))
            $MinerComparisons[1] | Add-Member $_ ("{0:N5}" -f ($MinerComparisons_Profit[1]*$Rates.$_))
        }

        if($MinerComparisons_Profit[0] -gt $MinerComparisons_Profit[1])
        {
            Write-Host -BackgroundColor Yellow -ForegroundColor Black "MultiPoolMiner is $([Math]::Round((($MinerComparisons_Profit[0]-$MinerComparisons_Profit[1])/$MinerComparisons_Profit[1])*100))% more profitable than conventional mining! "
        }

        $MinerComparisons | Out-Host
    }
    
    #Do nothing for a few seconds as to not overload the APIs
    Sleep $Interval

    #Save current hash rates
    $ActiveMinerPrograms | ForEach {
        $_.HashRate = 0
        $Miner_HashRates = $null

        if($_.New){$_.Benchmarked++}

        if($_.Process -eq $null -or $_.Process.HasExited)
        {
            if($_.Status -eq "Running"){$_.Status = "Failed"}
        }
        else
        {
            $Miner_HashRates = Get-HashRate $_.API $_.Port ($_.New -and $_.Benchmarked -lt 3)

            $_.HashRate = $Miner_HashRates | Select -First $_.Algorithms.Count
            
            if($Miner_HashRates.Count -ge $_.Algorithms.Count)
            {
                for($i = 0; $i -lt $_.Algorithms.Count; $i++)
                {
                    $Stat = Set-Stat -Name "$($_.Name)_$($_.Algorithms | Select -Index $i)_HashRate" -Value ($Miner_HashRates | Select -Index $i)
                }

                $_.New = $false
            }
        }

        #Benchmark timeout
        if($_.Benchmarked -ge 6 -or ($_.Benchmarked -ge 2 -and $_.Activated -ge 2))
        {
            for($i = $Miner_HashRates.Count; $i -lt $_.Algorithms.Count; $i++)
            {
                if((Get-Stat "$($_.Name)_$($_.Algorithms | Select -Index $i)_HashRate") -eq $null)
                {
                    $Stat = Set-Stat -Name "$($_.Name)_$($_.Algorithms | Select -Index $i)_HashRate" -Value 0
                }
            }
        }
    }
}

#Stop the log
Stop-Transcript