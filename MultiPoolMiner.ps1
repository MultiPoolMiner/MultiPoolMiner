param(
    [Parameter(Mandatory=$true)]
    [String]$UserName, 
    [Parameter(Mandatory=$false)]
    [String]$WorkerName = "MultiPoolMiner", 
    [Parameter(Mandatory=$false)]
    [String]$Wallet
)

Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)

. .\Include.ps1

$Interval = 60 #seconds
$Delta = 0.10 #decimal percentage

$CurrentMiner = $null

while($true)
{
    #Load the Stats
    $Stats = @{}
    Get-ChildItemContent "Stats" | ForEach {
        $Stats.Add($_.Name, $_.Content)
    }

    #Load information about the Pools
    $AllPools = Get-ChildItemContent "Pools" | ForEach {
        $_.Content | Add-Member @{Name = $_.Name} -PassThru
    }
    $Pools = @{}
    $AllPools.Algorithm | Get-Unique | ForEach {
        $Pools.Add($_, ($AllPools | Where Algorithm -EQ $_ | Sort Price -Descending | Select -First 1))
    }
    
    #Load information about the Miners
    $Miners = Get-ChildItemContent "Miners" | ForEach {
        $_.Content | Add-Member @{Name = $_.Name} -PassThru
    }
    $Miners | ForEach {
        $Miner = $_
        $Miner_Algorithms = $Miner.HashRates.Keys.Clone()
        $Miner_Pools = @{}
        $Miner_Profits = @{}
        $Miner_Profit = $null

        $Miner_Algorithms | ForEach {
            $Miner_Pools.Add($_, $Pools.$_)
        }

        $Miner_Algorithms | ForEach {
            $Miner_Profits.Add($_, [Decimal]$Miner.HashRates.$_*$Pools.$_.Price)
        }
        
        $Miner_Profit = ($Miner_Profits.Values | Measure -Sum).Sum
        
        $Miner_Algorithms | ForEach {
            if($Miner.HashRates.$_ -eq "")
            {
                $Miner.HashRates.$_ = $null
                $Miner_Profits.$_ = $null
                $Miner_Profit = $null
            }
            else
            {
                $Miner.HashRates.$_ = [Decimal]$Miner.HashRates.$_
                $Miner_Profits.$_ = [Decimal]$Miner_Profits.$_
            }
        }

        $Miner | Add-Member @{Pools = $Miner_Pools}
        $Miner | Add-Member @{Profits = $Miner_Profits}
        $Miner | Add-Member @{Profit = $Miner_Profit}
    }
    
    #Display mining information
    #Clear-Host
    $Miners | Sort -Descending Profit | Format-Table (
        @{Label = "Miner"; Expression={$_.Name}}, 
        @{Label = "Algorithm"; Expression={$_.HashRates.Keys}}, 
        @{Label = "Hash Rate"; Expression={$_.HashRates.Values | ForEach {if($_ -ne $null){$_.ToString("0,0.")}else{"Benchmarking"}}}; Align='right'}, 
        @{Label = "BTC/Day"; Expression={$_.Profits.Values | ForEach {if($_ -ne $null){$_.ToString("0.00000")}else{"Benchmarking"}}}; Align='right'}, 
        @{Label = "Pool"; Expression={$_.Pools.Values.Name}}, 
        @{Label = "BTC/GH/Day"; Expression={$_.Pools.Values.Price | ForEach {($_*1000000000).ToString("0.00000")}}; Align='right'}
    ) | Out-Host

    #Store most profitable miner
    if($CurrentMiner -ne $null){($Miners | Where Path -EQ $CurrentMiner.Path | Where Arguments -EQ $CurrentMiner.Arguments).Profit *= 1+$Delta}
    $NewMiner = $Miners | Sort -Descending {$_.Profit -isnot [ValueType]},Profit | Select -First 1
    
    $HashRateBoost = 1

    #If the new miner is already running then do nothing
    if
    (
        $CurrentMiner -eq $null -or 
        $CurrentMiner.Path -ne $NewMiner.Path -or 
        $CurrentMiner.Arguments -ne $NewMiner.Arguments -or
        (Get-Process | Where Id -eq $CurrentMiner.Process.Id) -eq $null
    )
    {
        #Stop the previous miner (if there is one)
        if($CurrentMiner -ne $null) {
            Stop-Process $CurrentMiner.Process
        }

        #Start the new miner and store the process id
        Add-Member -InputObject $NewMiner -MemberType NoteProperty -Name Process -Value (
            Start-Process $NewMiner.Path -ArgumentList $NewMiner.Arguments -PassThru -WorkingDirectory (Split-Path $NewMiner.Path)
        )

        #Force stop the previous miner if still running (if there is one)
        if($CurrentMiner -ne $null) {
            if((Get-Process | Where Id -eq $CurrentMiner.Process.Id) -ne $null)
            {
                Stop-Process $CurrentMiner.Process -Force
            }
        }

        #Set the new miner as the current miner
        $CurrentMiner = $NewMiner
        $HashRateBoost = 1+$Delta
    }
    
    #Do nothing for a few seconds as to not overload the APIs
    Sleep $Interval

    #Get the current hashrate
    $HashRates = Get-HashRate
    if($HashRates -ne $null)
    {
        $CurrentMiner.HashRates.Keys | ForEach {
            $HashRate = $HashRates[0] * $HashRateBoost
            $HashRates = $HashRates | Select -Skip 1
            $Stat = Set-Stat -Name "$($CurrentMiner.Name)_$($_)_HashRate" -Value $HashRate
        }
    }
    elseif($Stats.ContainsKey("$($CurrentMiner.Name)_$($_)_HashRate") -eq $false)
    {
        $CurrentMiner.HashRates.Keys | ForEach {
            $Stat = Set-Stat -Name "$($CurrentMiner.Name)_$($_)_HashRate" -Value 0
        }
    }
}